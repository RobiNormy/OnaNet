# OnaNet

Ona Net wifi discovery

## Production API

Flutter builds use the Railway API by default:

```text
https://onanet-production.up.railway.app
```

Railway forwards that public HTTPS address to the backend's internal port.
Do not add `:8080` to the public URL.

## Running With A Local API On A Physical Phone

Start FastAPI so other devices on your Wi-Fi can reach it:

```sh
python -m uvicorn main:app --host 0.0.0.0 --port 8000
```

Find your computer's LAN IP address:

```sh
hostname -I
```

Then run Flutter with that IP address. Do not use `localhost` or `127.0.0.1`
on a physical phone, because those point back to the phone itself:

```sh
flutter run --dart-define=ONA_NET_API_BASE_URL=http://192.168.1.23:8000
```

Replace `192.168.1.23` with your computer's actual Wi-Fi IP. The phone and
computer must be on the same network, and your firewall must allow port `8000`.
This command overrides the production Railway URL for local development.

## Getting Started

This is a wifi discovery market place where you can find better internet around you and compare packages to find the best deals it uses fastapi for the backend supabase for database and flutter for ui
