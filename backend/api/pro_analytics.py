from __future__ import annotations

from datetime import date
from typing import Any
from uuid import UUID

from fastapi import APIRouter, Header, HTTPException, status
from pydantic import BaseModel, Field

from backend.api.auth import _get_current_firebase_user
from backend.db.session import get_db_connection
from backend.services.subscription_services import get_provider_tier

router = APIRouter(tags=["pro-analytics"])


async def ensure_pro_analytics_schema() -> None:
    async with get_db_connection() as conn:
        await conn.execute(
            """
            CREATE EXTENSION IF NOT EXISTS pgcrypto;
            CREATE TABLE IF NOT EXISTS provider_views (
                id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
                provider_id uuid REFERENCES providers(id) ON DELETE CASCADE,
                view_type text NOT NULL CHECK (view_type IN ('search', 'profile', 'package')),
                area_name text,
                latitude double precision,
                longitude double precision,
                speed_filter_mbps integer,
                created_at timestamptz NOT NULL DEFAULT now()
            );
            CREATE INDEX IF NOT EXISTS provider_views_provider_date_idx
                ON provider_views(provider_id, created_at DESC);
            CREATE INDEX IF NOT EXISTS provider_views_area_date_idx
                ON provider_views(area_name, created_at DESC);

            CREATE TABLE IF NOT EXISTS search_logs (
                id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
                search_id uuid NOT NULL,
                provider_id uuid NOT NULL REFERENCES providers(id) ON DELETE CASCADE,
                result_position integer NOT NULL CHECK (result_position > 0),
                area_name text,
                latitude double precision,
                longitude double precision,
                speed_filter_mbps integer,
                created_at timestamptz NOT NULL DEFAULT now()
            );
            CREATE INDEX IF NOT EXISTS search_logs_provider_date_idx
                ON search_logs(provider_id, created_at DESC);

            CREATE TABLE IF NOT EXISTS customer_searches (
                id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
                query_text text,
                area_name text,
                latitude double precision,
                longitude double precision,
                speed_filter_mbps integer,
                filter_name text,
                results_count integer NOT NULL DEFAULT 0 CHECK (results_count >= 0),
                created_at timestamptz NOT NULL DEFAULT now()
            );
            CREATE INDEX IF NOT EXISTS customer_searches_date_idx
                ON customer_searches(created_at DESC);
            CREATE INDEX IF NOT EXISTS customer_searches_area_date_idx
                ON customer_searches(area_name, created_at DESC);

            ALTER TABLE installation_requests
                ADD COLUMN IF NOT EXISTS installation_area text,
                ADD COLUMN IF NOT EXISTS installation_latitude double precision,
                ADD COLUMN IF NOT EXISTS installation_longitude double precision,
                ADD COLUMN IF NOT EXISTS installer_name text,
                ADD COLUMN IF NOT EXISTS commission_amount numeric(12,2) NOT NULL DEFAULT 0,
                ADD COLUMN IF NOT EXISTS installed_at timestamptz;
            """
        )


class SearchResultLog(BaseModel):
    provider_id: UUID
    position: int = Field(gt=0)


class SearchLogCreate(BaseModel):
    query_text: str | None = Field(default=None, max_length=200)
    area_name: str | None = Field(default=None, max_length=200)
    latitude: float | None = None
    longitude: float | None = None
    speed_filter_mbps: int | None = Field(default=None, gt=0)
    filter_name: str | None = Field(default=None, max_length=50)
    results: list[SearchResultLog] = Field(default_factory=list, max_length=100)


class ViewLogCreate(BaseModel):
    provider_id: UUID
    view_type: str = Field(pattern="^(profile|package)$")
    area_name: str | None = Field(default=None, max_length=200)
    latitude: float | None = None
    longitude: float | None = None
    speed_filter_mbps: int | None = Field(default=None, gt=0)


@router.post("/telemetry/search", status_code=status.HTTP_204_NO_CONTENT)
async def log_search(body: SearchLogCreate) -> None:
    async with get_db_connection() as conn:
        async with conn.transaction():
            search_id = await conn.fetchval(
                """
                INSERT INTO customer_searches(
                    query_text, area_name, latitude, longitude,
                    speed_filter_mbps, filter_name, results_count
                )
                VALUES ($1,$2,$3,$4,$5,$6,$7)
                RETURNING id
                """,
                (body.query_text or "").strip() or None,
                (body.area_name or "").strip() or None,
                body.latitude,
                body.longitude,
                body.speed_filter_mbps,
                (body.filter_name or "").strip() or None,
                len(body.results),
            )
            for result in body.results:
                await conn.execute(
                    """
                    INSERT INTO search_logs(search_id, provider_id, result_position,
                        area_name, latitude, longitude, speed_filter_mbps)
                    VALUES ($1,$2,$3,$4,$5,$6,$7)
                    """,
                    search_id, result.provider_id, result.position,
                    body.area_name, body.latitude, body.longitude,
                    body.speed_filter_mbps,
                )
                await conn.execute(
                    """
                    INSERT INTO provider_views(provider_id, view_type, area_name,
                        latitude, longitude, speed_filter_mbps)
                    VALUES ($1,'search',$2,$3,$4,$5)
                    """,
                    result.provider_id, body.area_name, body.latitude,
                    body.longitude, body.speed_filter_mbps,
                )


@router.post("/telemetry/view", status_code=status.HTTP_204_NO_CONTENT)
async def log_view(body: ViewLogCreate) -> None:
    async with get_db_connection() as conn:
        await conn.execute(
            """
            INSERT INTO provider_views(provider_id, view_type, area_name,
                latitude, longitude, speed_filter_mbps)
            VALUES ($1,$2,$3,$4,$5,$6)
            """,
            body.provider_id, body.view_type, body.area_name,
            body.latitude, body.longitude, body.speed_filter_mbps,
        )


async def _owned_pro_provider(firebase_uid: str) -> tuple[UUID, str]:
    async with get_db_connection() as conn:
        row = await conn.fetchrow(
            """
            SELECT p.id, p.provider_name FROM providers p
            JOIN users u ON u.id = p.user_id WHERE u.firebase_uid = $1
            ORDER BY p.created_at DESC LIMIT 1
            """,
            firebase_uid,
        )
    if row is None:
        raise HTTPException(403, "No provider profile linked to this account.")
    tier, _ = await get_provider_tier(row["id"])
    if tier != "pro":
        raise HTTPException(403, "Pro Analytics requires an active Pro plan.")
    return row["id"], row["provider_name"]


@router.get("/providers/me/pro-analytics")
async def pro_analytics(
    authorization: str | None = Header(default=None),
) -> dict[str, Any]:
    firebase_user = await _get_current_firebase_user(authorization)
    provider_id, provider_name = await _owned_pro_provider(firebase_user["uid"])
    async with get_db_connection() as db:
        funnel = await db.fetchrow(
            """
            WITH mine AS (
              SELECT count(*) FILTER (WHERE view_type='search') impressions,
                     count(*) FILTER (WHERE view_type='profile') profiles,
                     count(*) FILTER (WHERE view_type='package') packages
              FROM provider_views WHERE provider_id=$1 AND created_at>=date_trunc('month',now())
            ), leads AS (
              SELECT count(*) leads,
                     count(*) FILTER (WHERE status IN ('complete','completed')) completed
              FROM installation_requests WHERE provider_id=$1
                AND created_at>=date_trunc('month',now())
            ) SELECT * FROM mine CROSS JOIN leads
            """, provider_id,
        )
        platform = await db.fetchrow(
            """
            WITH v AS (SELECT count(*) FILTER(WHERE view_type='search') i,
                 count(*) FILTER(WHERE view_type='profile') p,
                 count(*) FILTER(WHERE view_type='package') k FROM provider_views
                 WHERE created_at>=date_trunc('month',now())),
            t AS (SELECT count(*) l, count(*) FILTER(WHERE status IN ('complete','completed')) c
                 FROM installation_requests WHERE created_at>=date_trunc('month',now()))
            SELECT * FROM v CROSS JOIN t
            """
        )
        zones = await db.fetch(
            """
            WITH coverage AS (
              SELECT lower(c.area_name) AS area_key,
                min(c.area_name) AS area_name,
                avg(c.latitude)::float AS latitude,
                avg(c.longitude)::float AS longitude,
                max(c.radius_km)::float AS radius_km,
                count(DISTINCT c.provider_id)::int AS providers,
                array_agg(DISTINCT p.provider_name ORDER BY p.provider_name)
                  AS provider_names,
                bool_or(c.provider_id = $1) AS is_listed
              FROM provider_coverage_areas c
              JOIN providers p ON p.id = c.provider_id
              GROUP BY lower(c.area_name)
            ), leads AS (
              SELECT lower(coalesce(installation_area, estate_or_building)) AS area_key,
                count(*)::int AS leads
              FROM installation_requests
              WHERE created_at >= date_trunc('month', now())
              GROUP BY lower(coalesce(installation_area, estate_or_building))
            ), searches AS (
              SELECT lower(area_name) AS area_key,
                count(*)::int AS searches
              FROM customer_searches
              WHERE created_at >= date_trunc('month', now())
                AND area_name IS NOT NULL
              GROUP BY lower(area_name)
            )
            SELECT c.area_name, c.latitude, c.longitude, c.radius_km,
              coalesce(l.leads, 0)::int AS leads,
              coalesce(s.searches, 0)::int AS searches,
              c.providers, c.provider_names, c.is_listed
            FROM coverage c
            LEFT JOIN leads l ON l.area_key = c.area_key
            LEFT JOIN searches s ON s.area_key = c.area_key
            ORDER BY searches DESC, c.area_name
            """, provider_id,
        )
        red_zones = await db.fetch(
            """
            SELECT cs.area_name, avg(cs.latitude)::float latitude,
              avg(cs.longitude)::float longitude, 1::float radius_km,
              0::int leads, count(*)::int searches,
              0::int providers, ARRAY[]::text[] provider_names,
              false AS is_listed
            FROM customer_searches cs
            WHERE cs.created_at>=date_trunc('month',now())
              AND cs.area_name IS NOT NULL AND cs.latitude IS NOT NULL AND cs.longitude IS NOT NULL
              AND NOT EXISTS (SELECT 1 FROM provider_coverage_areas listed
                WHERE lower(listed.area_name)=lower(cs.area_name))
            GROUP BY cs.area_name HAVING count(*) >= 5
            ORDER BY searches DESC LIMIT 10
            """
        )
        growth_areas = await db.fetch(
            """
            WITH weekly AS (
              SELECT lower(area_name) AS area_key,
                min(area_name) AS area_name,
                count(*) FILTER (
                  WHERE created_at >= now() - interval '7 days'
                )::int AS current_searches,
                count(*) FILTER (
                  WHERE created_at >= now() - interval '14 days'
                    AND created_at < now() - interval '7 days'
                )::int AS previous_searches
              FROM customer_searches
              WHERE area_name IS NOT NULL
                AND btrim(area_name) <> ''
                AND created_at >= now() - interval '14 days'
              GROUP BY lower(area_name)
            )
            SELECT area_name, current_searches, previous_searches,
              (current_searches - previous_searches)::int AS search_growth,
              CASE
                WHEN previous_searches = 0 THEN NULL
                ELSE round(
                  ((current_searches - previous_searches)::numeric
                    / previous_searches) * 100,
                  1
                )::float
              END AS growth_percent,
              (previous_searches = 0 AND current_searches > 0) AS is_new_demand
            FROM weekly
            WHERE current_searches > previous_searches
            ORDER BY search_growth DESC, current_searches DESC, area_name
            LIMIT 12
            """
        )
        search_summary = await db.fetchrow(
            """
            SELECT count(*)::int AS total_searches,
              count(*) FILTER (WHERE results_count = 0)::int AS zero_result_searches
            FROM customer_searches
            WHERE created_at >= now() - interval '30 days'
            """
        )
        top_queries = await db.fetch(
            """
            SELECT min(query_text) AS query,
              count(*)::int AS searches,
              round(avg(results_count), 1)::float AS average_results
            FROM customer_searches
            WHERE query_text IS NOT NULL
              AND btrim(query_text) <> ''
              AND created_at >= now() - interval '30 days'
            GROUP BY lower(btrim(query_text))
            ORDER BY searches DESC, query
            LIMIT 10
            """
        )
        top_search_areas = await db.fetch(
            """
            SELECT min(area_name) AS area_name, count(*)::int AS searches
            FROM customer_searches
            WHERE area_name IS NOT NULL
              AND btrim(area_name) <> ''
              AND created_at >= now() - interval '30 days'
            GROUP BY lower(btrim(area_name))
            ORDER BY searches DESC, area_name
            LIMIT 10
            """
        )
        top_speeds = await db.fetch(
            """
            SELECT speed_filter_mbps AS speed_mbps,
              count(*)::int AS searches
            FROM customer_searches
            WHERE speed_filter_mbps IS NOT NULL
              AND created_at >= now() - interval '30 days'
            GROUP BY speed_filter_mbps
            ORDER BY searches DESC, speed_filter_mbps DESC
            LIMIT 10
            """
        )
        gaps = await db.fetch(
            """
            WITH demand AS (SELECT area_name,speed_filter_mbps,count(*)::int searches
              FROM customer_searches WHERE speed_filter_mbps IS NOT NULL
                AND created_at>=date_trunc('month',now()) GROUP BY area_name,speed_filter_mbps),
            offered AS (SELECT coalesce(max(speed_mbps),0)::int max_speed FROM provider_packages WHERE provider_id=$1)
            SELECT d.*,o.max_speed, d.searches::int unmatched_searches
            FROM demand d CROSS JOIN offered o
            JOIN provider_coverage_areas c ON c.provider_id=$1 AND lower(c.area_name)=lower(d.area_name)
            WHERE d.speed_filter_mbps>o.max_speed ORDER BY d.searches DESC LIMIT 10
            """, provider_id,
        )
        prices = await db.fetch(
            """
            WITH market AS (SELECT c.area_name,p.speed_mbps,
                min(p.monthly_price)::float min_price,max(p.monthly_price)::float max_price,
                percentile_cont(.5) within group(order by p.monthly_price)::float median_price
              FROM provider_packages p JOIN provider_coverage_areas c ON c.provider_id=p.provider_id
              GROUP BY c.area_name,p.speed_mbps)
            SELECT m.*,p.monthly_price::float your_price,p.package_name
            FROM provider_packages p JOIN provider_coverage_areas c ON c.provider_id=p.provider_id
            JOIN market m ON lower(m.area_name)=lower(c.area_name) AND m.speed_mbps=p.speed_mbps
            WHERE p.provider_id=$1 ORDER BY c.area_name,p.speed_mbps
            """, provider_id,
        )
        positions = await db.fetch(
            """
            WITH provider_positions AS (
              SELECT date_trunc('month', created_at) AS month_start,
                area_name,
                avg(result_position)::float AS your_position
              FROM search_logs
              WHERE provider_id = $1
                AND created_at >= now() - interval '6 months'
              GROUP BY date_trunc('month', created_at), area_name
            ), platform_positions AS (
              SELECT date_trunc('month', created_at) AS month_start,
                avg(result_position)::float AS platform_position
              FROM search_logs
              WHERE created_at >= now() - interval '6 months'
              GROUP BY date_trunc('month', created_at)
            )
            SELECT to_char(p.month_start, 'YYYY-MM') AS month,
              p.area_name,
              p.your_position,
              coalesce(a.platform_position, 0)::float AS platform_position
            FROM provider_positions p
            LEFT JOIN platform_positions a ON a.month_start = p.month_start
            ORDER BY p.month_start, p.area_name
            """, provider_id,
        )
        revenue = await db.fetch(
            """
            SELECT to_char(date_trunc('month',ir.updated_at),'YYYY-MM') AS month,
              coalesce(sum(pp.monthly_price),0)::float revenue
            FROM installation_requests ir JOIN provider_packages pp ON pp.id=ir.package_id
            WHERE ir.provider_id=$1 AND ir.status IN ('complete','completed')
              AND ir.updated_at>=now()-interval '3 months'
            GROUP BY date_trunc('month',ir.updated_at) ORDER BY 1
            """, provider_id,
        )
        pipeline = await db.fetchval(
            """SELECT coalesce(sum(pp.monthly_price),0)::float FROM installation_requests ir
            JOIN provider_packages pp ON pp.id=ir.package_id WHERE ir.provider_id=$1
            AND ir.status IN ('accepted','scheduled','installed')""", provider_id,
        )
        ltv = await db.fetchrow(
            """
            WITH c AS (SELECT user_id,greatest(1,extract(year from age(max(updated_at),min(created_at)))*12+
              extract(month from age(max(updated_at),min(created_at))))::float months
              FROM installation_requests WHERE provider_id=$1 AND status IN ('complete','completed') GROUP BY user_id)
            SELECT coalesce(avg(c.months),0)::float months,
              coalesce((SELECT avg(monthly_price)::float FROM provider_packages WHERE provider_id=$1),0) avg_price,
              count(*)::int customers FROM c
            """, provider_id,
        )
        shares = await db.fetch(
            """
            SELECT c.area_name,
              count(ir.id) FILTER(WHERE ir.provider_id=$1)::int yours,
              count(ir.id)::int total
            FROM provider_coverage_areas c
            LEFT JOIN installation_requests ir ON lower(coalesce(ir.installation_area,ir.estate_or_building))=lower(c.area_name)
              AND ir.status IN ('complete','completed')
            WHERE c.provider_id=$1 GROUP BY c.area_name ORDER BY 1
            """, provider_id,
        )
        leads = await db.fetch(
            """SELECT ir.created_at,coalesce(ir.installation_area,ir.estate_or_building) area,
              pp.package_name,pp.monthly_price::float package_price,
              ir.commission_amount::float commission_amount,
              (pp.monthly_price-ir.commission_amount)::float net_revenue,
              ir.status,ir.completed_at FROM installation_requests ir
              LEFT JOIN provider_packages pp ON pp.id=ir.package_id WHERE ir.provider_id=$1 ORDER BY ir.created_at DESC""", provider_id,
        )
        installers = await db.fetch(
            """SELECT coalesce(installer_name,'Unassigned') installer,count(*)::int jobs,
              count(*) FILTER(WHERE status IN ('complete','completed'))::int completed,
              avg(extract(epoch from (coalesce(installed_at,completed_at)-created_at))/86400)::float avg_days
              FROM installation_requests WHERE provider_id=$1 GROUP BY installer_name ORDER BY completed DESC""", provider_id,
        )

    f = dict(funnel or {})
    p = dict(platform or {})
    stages = [("Search Impressions",f.get("impressions",0),p.get("i",0)),
              ("Profile Views",f.get("profiles",0),p.get("p",0)),
              ("Package Views",f.get("packages",0),p.get("k",0)),
              ("Lead Requests",f.get("leads",0),p.get("l",0)),
              ("Completed Installs",f.get("completed",0),p.get("c",0))]
    funnel_out=[]
    for i,(label,value,platform_value) in enumerate(stages):
        prev=stages[i-1][1] if i else value
        platform_prev=stages[i-1][2] if i else platform_value
        rate=(value/prev*100) if prev else 0
        avg=(platform_value/platform_prev*100) if platform_prev else 0
        funnel_out.append({"label":label,"value":value,"drop_off":0 if i==0 else 100-rate,
                           "rate":rate,"platform_average":avg,"above_average":rate>=avg})
    rev=[dict(r) for r in revenue]
    trend=rev[-1]["revenue"] if rev else 0
    if len(rev)>=2:
        xs=range(len(rev)); xm=sum(xs)/len(rev); ym=sum(r["revenue"] for r in rev)/len(rev)
        den=sum((x-xm)**2 for x in xs)
        slope=sum((x-xm)*(rev[x]["revenue"]-ym) for x in xs)/den if den else 0
        trend=max(0,ym+slope*(len(rev)-xm))
    zone_out=[]
    for z in zones:
        d=dict(z)
        d["status"] = (
            "green" if d["is_listed"] and d["leads"]
            else "amber" if d["is_listed"]
            else "red"
        )
        zone_out.append(d)
    for z in red_zones:
        d=dict(z); d["status"]="red"; zone_out.append(d)
    l=dict(ltv or {}); ltv_value=(l.get("months") or 0)*(l.get("avg_price") or 0)
    search_totals = dict(search_summary or {})
    share_out=[]
    for s in shares:
        d=dict(s); d["share"]=(d["yours"]/d["total"]*100) if d["total"] else 0; share_out.append(d)
    overall_yours=sum(x["yours"] for x in share_out); overall_total=sum(x["total"] for x in share_out)
    return {"provider_name":provider_name,"period":date.today().strftime("%B %Y"),
      "funnel":funnel_out,"demand_zones":zone_out,
      "growth_areas":[dict(x) for x in growth_areas],
      "search_insights":{
        "total_searches":search_totals.get("total_searches",0),
        "zero_result_searches":search_totals.get("zero_result_searches",0),
        "top_queries":[dict(x) for x in top_queries],
        "top_areas":[dict(x) for x in top_search_areas],
        "top_speeds":[dict(x) for x in top_speeds],
      },
      "package_gaps":[dict(x) for x in gaps],
      "price_benchmarks":[dict(x) for x in prices],"search_positions":[dict(x) for x in positions],
      "revenue":{"history":rev,"pipeline":pipeline or 0,"trend_forecast":trend},
      "ltv":{"months":l.get("months",0),"average_price":l.get("avg_price",0),"value":ltv_value,
             "one_month_annual_lift":(l.get("avg_price",0) or 0)*(l.get("customers",0) or 0)},
      "market_share":{"overall":(overall_yours/overall_total*100) if overall_total else 0,
                      "trend":0,"zones":sorted(share_out,key=lambda x:x["share"],reverse=True)},
      "exports":{"leads":[dict(x) for x in leads],"installers":[dict(x) for x in installers]}}
