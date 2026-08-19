// OnaNet platform administration control panel.
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:ona_net/features/auth/data/auth_service.dart';
import 'package:ona_net/features/auth/presentation/login_screen.dart';
import 'package:ona_net/core/theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

enum AdminSection {
  dashboard('Dashboard', Icons.dashboard_outlined),
  providers('Providers', Icons.cell_tower_outlined),
  verification('Verification queue', Icons.fact_check_outlined),
  packages('Packages', Icons.inventory_2_outlined),
  coverage('Coverage zones', Icons.map_outlined),
  users('Users', Icons.people_outline),
  reports('Reports', Icons.flag_outlined),
  subscriptions('Subscriptions', Icons.credit_card_outlined),
  invoices('Invoices', Icons.receipt_long_outlined),
  revenue('Revenue', Icons.show_chart_outlined);

  const AdminSection(this.label, this.icon);
  final String label;
  final IconData icon;
}

typedef Json = Map<String, dynamic>;

class OnaNetAdminDashboard extends StatefulWidget {
  const OnaNetAdminDashboard({super.key});

  @override
  State<OnaNetAdminDashboard> createState() => _OnaNetAdminDashboardState();
}

class _OnaNetAdminDashboardState extends State<OnaNetAdminDashboard> {
  final _auth = AuthService();
  final _scaffold = GlobalKey<ScaffoldState>();
  AdminSection section = AdminSection.dashboard;
  Json data = {};
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      data = await _auth.getAdminSnapshot();
    } catch (e) {
      error = e.toString();
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> run(Future<void> Function() action, String success) async {
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success),
          backgroundColor: AppTheme.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      await load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void select(AdminSection value) {
    setState(() => section = value);
    if (MediaQuery.sizeOf(context).width < 900) Navigator.maybePop(context);
  }

  Future<void> signOut() async {
    if (await _confirm(
          context,
          'Sign out?',
          'You will need to sign in again.',
        ) !=
        true) {
      return;
    }
    await _auth.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const Login()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final desktop = MediaQuery.sizeOf(context).width >= 900;
    return Theme(
      data: AppTheme.dark().copyWith(
        textTheme: GoogleFonts.plusJakartaSansTextTheme(
          AppTheme.dark().textTheme,
        ),
        cardTheme: const CardThemeData(
          elevation: 0,
          color: Color(0xff12263a),
          margin: EdgeInsets.zero,
        ),
        dataTableTheme: const DataTableThemeData(
          headingTextStyle: TextStyle(
            color: Color(0xff8fa3b6),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
          dataTextStyle: TextStyle(fontSize: 12),
          dividerThickness: .5,
        ),
      ),
      child: Scaffold(
        key: _scaffold,
        backgroundColor: const Color(0xff081725),
        drawer: desktop ? null : Drawer(child: _AdminSidebar(owner: this)),
        body: SafeArea(
          child: Row(
            children: [
              if (desktop)
                SizedBox(width: 236, child: _AdminSidebar(owner: this)),
              Expanded(
                child: Column(
                  children: [
                    AdminTopBar(
                      admin: _map(data['admin']),
                      menu: desktop
                          ? null
                          : () => _scaffold.currentState?.openDrawer(),
                      refresh: load,
                    ),
                    Expanded(
                      child: loading
                          ? const Center(child: CircularProgressIndicator())
                          : error != null
                          ? _ErrorState(message: error!, retry: load)
                          : RefreshIndicator(
                              onRefresh: load,
                              child: SingleChildScrollView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: EdgeInsets.all(desktop ? 24 : 14),
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 1420,
                                  ),
                                  child: AdminScreenHost(
                                    section: section,
                                    data: data,
                                    auth: _auth,
                                    run: run,
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminSidebar extends StatelessWidget {
  const _AdminSidebar({required this.owner});
  final _OnaNetAdminDashboardState owner;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xff0b1c2c),
      child: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 22, 20, 18),
              child: Row(
                children: [
                  Icon(Icons.wifi_rounded, color: AppTheme.amber),
                  SizedBox(width: 10),
                  Text(
                    'OnaNet',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  Spacer(),
                  _Pill('Admin'),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(10),
                children: [
                  const _NavLabel('OVERVIEW'),
                  _item(context, AdminSection.dashboard),
                  const _NavLabel('PROVIDERS'),
                  for (final value in [
                    AdminSection.providers,
                    AdminSection.verification,
                    AdminSection.packages,
                    AdminSection.coverage,
                  ])
                    _item(context, value),
                  const _NavLabel('PEOPLE'),
                  _item(context, AdminSection.users),
                  _item(context, AdminSection.reports),
                  const _NavLabel('FINANCE'),
                  for (final value in [
                    AdminSection.subscriptions,
                    AdminSection.invoices,
                    AdminSection.revenue,
                  ])
                    _item(context, value),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout, size: 19),
              title: const Text('Sign out', style: TextStyle(fontSize: 13)),
              onTap: owner.signOut,
            ),
          ],
        ),
      ),
    );
  }

  Widget _item(BuildContext context, AdminSection value) {
    final selected = value == owner.section;
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: ListTile(
        dense: true,
        selected: selected,
        selectedTileColor: AppTheme.amber.withValues(alpha: .14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        leading: Icon(value.icon, size: 19),
        title: Text(value.label, style: const TextStyle(fontSize: 13)),
        onTap: () => owner.select(value),
      ),
    );
  }
}

class _NavLabel extends StatelessWidget {
  const _NavLabel(this.value);
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 15, 12, 7),
    child: Text(
      value,
      style: const TextStyle(
        color: Color(0xff60778c),
        fontSize: 9,
        fontWeight: FontWeight.w800,
        letterSpacing: 1,
      ),
    ),
  );
}

class AdminTopBar extends StatelessWidget {
  const AdminTopBar({
    super.key,
    required this.admin,
    required this.menu,
    required this.refresh,
  });
  final Json admin;
  final VoidCallback? menu;
  final VoidCallback refresh;

  @override
  Widget build(BuildContext context) => Container(
    height: 68,
    padding: const EdgeInsets.symmetric(horizontal: 18),
    decoration: const BoxDecoration(
      color: Color(0xff0b1c2c),
      border: Border(bottom: BorderSide(color: Color(0xff1f3447))),
    ),
    child: Row(
      children: [
        if (menu != null)
          IconButton(onPressed: menu, icon: const Icon(Icons.menu)),
        const Text(
          'Control panel',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        const Spacer(),
        IconButton(
          tooltip: 'Refresh live data',
          onPressed: refresh,
          icon: const Icon(Icons.refresh, size: 20),
        ),
        const SizedBox(width: 8),
        CircleAvatar(
          radius: 17,
          backgroundColor: AppTheme.amber.withValues(alpha: .18),
          child: Text(_initial(_str(admin['name']))),
        ),
        const SizedBox(width: 9),
        if (MediaQuery.sizeOf(context).width > 560)
          Text(
            _str(admin['name'], 'Administrator'),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
      ],
    ),
  );
}

class AdminScreenHost extends StatelessWidget {
  const AdminScreenHost({
    super.key,
    required this.section,
    required this.data,
    required this.auth,
    required this.run,
  });
  final AdminSection section;
  final Json data;
  final AuthService auth;
  final void Function(Future<void> Function(), String) run;

  @override
  Widget build(BuildContext context) {
    final users = _list(data['users']);
    final providers = _list(data['providers']);
    final documents = _list(data['documents']);
    final packages = _list(data['packages']);
    final zones = _list(data['coverage_zones']);
    final reports = _list(data['reports']);
    final invoices = _list(data['invoices']);
    return switch (section) {
      AdminSection.dashboard => DashboardScreen(
        users: users,
        providers: providers,
        documents: documents,
        packages: packages,
        reports: reports,
        invoices: invoices,
      ),
      AdminSection.providers => ProvidersScreen(
        providers: providers,
        auth: auth,
        run: run,
      ),
      AdminSection.verification => VerificationQueueScreen(
        providers: providers,
        documents: documents,
        auth: auth,
        run: run,
      ),
      AdminSection.packages => PackagesScreen(
        packages: packages,
        auth: auth,
        run: run,
      ),
      AdminSection.coverage => CoverageZonesScreen(zones: zones),
      AdminSection.users => UsersScreen(users: users, auth: auth, run: run),
      AdminSection.reports => ReportsScreen(
        reports: reports,
        auth: auth,
        run: run,
      ),
      AdminSection.subscriptions => SubscriptionsScreen(
        providers: providers,
        auth: auth,
        run: run,
      ),
      AdminSection.invoices => InvoicesScreen(
        invoices: invoices,
        auth: auth,
        run: run,
      ),
      AdminSection.revenue => RevenueScreen(
        providers: providers,
        invoices: invoices,
      ),
    };
  }
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    super.key,
    required this.users,
    required this.providers,
    required this.documents,
    required this.packages,
    required this.reports,
    required this.invoices,
  });
  final List<Json> users, providers, documents, packages, reports, invoices;

  @override
  Widget build(BuildContext context) {
    final pending = documents.where((e) => e['status'] == 'pending').length;
    final activeReports = reports
        .where((e) => e['status'] != 'resolved')
        .length;
    final mrr = providers.fold<double>(
      0,
      (sum, p) => sum + _planPrice(_str(p['subscription_tier'])),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Heading('Dashboard', 'A live view of the whole OnaNet platform'),
        _MetricGrid(
          items: [
            (
              'Total providers',
              '${providers.length}',
              Icons.cell_tower,
              '+ live',
            ),
            ('Total users', '${users.length}', Icons.people, '+ live'),
            ('Monthly revenue', _money(mrr), Icons.payments_outlined, 'MRR'),
            (
              'Pending verification',
              '$pending',
              Icons.fact_check_outlined,
              'needs review',
            ),
          ],
        ),
        const SizedBox(height: 18),
        _ResponsivePair(
          left: _Panel(
            title: 'Verification queue',
            child: _MiniList(
              items: documents
                  .where((e) => e['status'] == 'pending')
                  .take(5)
                  .toList(),
              title: (e) => _str(e['provider_name']),
              subtitle: (e) => _pretty(_str(e['document_type'])),
              icon: Icons.description_outlined,
            ),
          ),
          right: _Panel(
            title: 'Reports & flags',
            child: reports.isEmpty
                ? _Empty('No reports have been submitted')
                : _MiniList(
                    items: reports
                        .where((e) => e['status'] != 'resolved')
                        .take(5)
                        .toList(),
                    title: (e) => _pretty(_str(e['report_type'])),
                    subtitle: (e) => _str(e['reported_name']),
                    icon: Icons.flag_outlined,
                  ),
          ),
        ),
        const SizedBox(height: 18),
        _Panel(
          title: 'Provider management',
          child: _TableWrap(
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Provider')),
                DataColumn(label: Text('Type')),
                DataColumn(label: Text('Plan')),
                DataColumn(label: Text('Verification')),
                DataColumn(label: Text('Status')),
              ],
              rows: providers.take(6).map(_providerRow).toList(),
            ),
          ),
        ),
        const SizedBox(height: 18),
        _ResponsivePair(
          left: _Panel(
            title: 'Subscription revenue',
            child: Column(
              children: ['free', 'growth', 'pro'].map((plan) {
                final count = providers
                    .where((p) => p['subscription_tier'] == plan)
                    .length;
                return ListTile(
                  dense: true,
                  title: Text(_pretty(plan)),
                  trailing: Text(
                    '$count  ·  ${_money(count * _planPrice(plan))}',
                  ),
                );
              }).toList(),
            ),
          ),
          right: _Panel(
            title: 'Recent invoices',
            child: invoices.isEmpty
                ? _Empty('Invoices will appear as they are issued')
                : _MiniList(
                    items: invoices.take(5).toList(),
                    title: (e) => _str(e['provider_name']),
                    subtitle: (e) =>
                        '${_money(_num(e['amount']))} · ${_pretty(_str(e['status']))}',
                    icon: Icons.receipt_long,
                  ),
          ),
        ),
        if (activeReports > 0) const SizedBox(height: 4),
      ],
    );
  }
}

class ProvidersScreen extends StatefulWidget {
  const ProvidersScreen({
    super.key,
    required this.providers,
    required this.auth,
    required this.run,
  });
  final List<Json> providers;
  final AuthService auth;
  final void Function(Future<void> Function(), String) run;
  @override
  State<ProvidersScreen> createState() => _ProvidersScreenState();
}

class _ProvidersScreenState extends State<ProvidersScreen> {
  String query = '', plan = 'all', status = 'all';
  int page = 0;

  @override
  Widget build(BuildContext context) {
    final filtered = widget.providers.where((p) {
      final hay = '${p['provider_name']} ${p['owner_name']} ${p['email']}'
          .toLowerCase();
      final planOk = plan == 'all' || p['subscription_tier'] == plan;
      final state = p['status'] == 'banned'
          ? 'banned'
          : p['is_verified'] == true
          ? 'verified'
          : 'pending';
      return hay.contains(query.toLowerCase()) &&
          planOk &&
          (status == 'all' || state == status);
    }).toList();
    final pages = math.max(1, (filtered.length / 10).ceil());
    if (page >= pages) page = pages - 1;
    final shown = filtered.skip(page * 10).take(10);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Heading(
          'Providers',
          'Search, verify and moderate every network provider',
        ),
        _Search(
          onChanged: (v) => setState(() => query = v),
          hint: 'Search providers',
        ),
        _Filters(
          values: const ['all', 'free', 'growth', 'pro'],
          selected: plan,
          onSelected: (v) => setState(() {
            plan = v;
            page = 0;
          }),
        ),
        _Filters(
          values: const ['all', 'verified', 'pending', 'banned'],
          selected: status,
          onSelected: (v) => setState(() {
            status = v;
            page = 0;
          }),
        ),
        _Panel(
          title: '${filtered.length} providers',
          child: _TableWrap(
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Provider')),
                DataColumn(label: Text('Type')),
                DataColumn(label: Text('Plan')),
                DataColumn(label: Text('Customers')),
                DataColumn(label: Text('Verification')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Actions')),
              ],
              rows: shown
                  .map(
                    (p) => DataRow(
                      cells: [
                        DataCell(
                          _Identity(_str(p['provider_name']), _str(p['email'])),
                        ),
                        DataCell(Text(_pretty(_str(p['provider_type'])))),
                        DataCell(
                          _Pill(_pretty(_str(p['subscription_tier'], 'free'))),
                        ),
                        DataCell(Text('${p['customer_count'] ?? 0}')),
                        DataCell(
                          _Status(
                            p['is_verified'] == true ? 'verified' : 'pending',
                          ),
                        ),
                        DataCell(_Status(_str(p['status'], 'active'))),
                        DataCell(
                          PopupMenuButton<String>(
                            onSelected: (value) async {
                              final reason = value == 'approved'
                                  ? null
                                  : await _reason(
                                      context,
                                      '${_pretty(value)} provider',
                                    );
                              if (value != 'approved' && reason == null) return;
                              widget.run(
                                () => widget.auth.moderateAdminProvider(
                                  _str(p['id']),
                                  status: value,
                                  reason: reason,
                                ),
                                'Provider updated',
                              );
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'approved',
                                child: Text('Restore'),
                              ),
                              PopupMenuItem(
                                value: 'suspended',
                                child: Text('Suspend'),
                              ),
                              PopupMenuItem(
                                value: 'banned',
                                child: Text('Ban'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
        _Pager(
          page: page,
          pages: pages,
          change: (v) => setState(() => page = v),
        ),
      ],
    );
  }
}

class VerificationQueueScreen extends StatefulWidget {
  const VerificationQueueScreen({
    super.key,
    required this.providers,
    required this.documents,
    required this.auth,
    required this.run,
  });
  final List<Json> providers, documents;
  final AuthService auth;
  final void Function(Future<void> Function(), String) run;

  @override
  State<VerificationQueueScreen> createState() =>
      _VerificationQueueScreenState();
}

class _VerificationQueueScreenState extends State<VerificationQueueScreen> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final ids = widget.documents
        .where((d) => d['status'] == 'pending')
        .map((d) => d['provider_id'])
        .toSet();
    final queue = widget.providers.where((p) {
      if (!ids.contains(p['id'])) return false;
      final value =
          '${p['provider_name']} ${p['business_name']} ${p['owner_name']} ${p['email']}'
              .toLowerCase();
      return value.contains(query.toLowerCase());
    }).toList();
    final pendingDocuments = widget.documents
        .where((d) => d['status'] == 'pending')
        .length;
    final reviewedToday = widget.documents.where((d) {
      if (d['status'] == 'pending') return false;
      final date = DateTime.tryParse(_str(d['created_at']))?.toLocal();
      final now = DateTime.now();
      return date != null &&
          date.year == now.year &&
          date.month == now.month &&
          date.day == now.day;
    }).length;
    final completeApplications = queue.where((provider) {
      final providerDocs = widget.documents.where(
        (d) => d['provider_id'] == provider['id'],
      );
      return providerDocs.map((d) => d['document_type']).toSet().length >= 4;
    }).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Heading(
          'Verification queue',
          'Review provider identity and business documents securely',
        ),
        _MetricGrid(
          items: [
            (
              'Awaiting review',
              '${ids.length}',
              Icons.hourglass_top_rounded,
              'providers',
            ),
            (
              'Pending documents',
              '$pendingDocuments',
              Icons.description_outlined,
              'files',
            ),
            (
              'Complete files',
              '$completeApplications',
              Icons.task_alt_rounded,
              'ready to decide',
            ),
            (
              'Reviewed today',
              '$reviewedToday',
              Icons.fact_check_outlined,
              'documents',
            ),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: _Search(
                onChanged: (value) => setState(() => query = value),
                hint: 'Search provider, owner or email',
              ),
            ),
            if (MediaQuery.sizeOf(context).width > 680) ...[
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _Pill('${queue.length} in queue'),
              ),
            ],
          ],
        ),
        if (queue.isEmpty)
          _Panel(
            title: query.isEmpty ? 'Queue cleared' : 'No matching applications',
            child: _Empty(
              query.isEmpty
                  ? 'There are no provider applications awaiting review'
                  : 'Try a different provider name, owner or email',
            ),
          )
        else
          ...queue.indexed.map(
            (entry) => _VerificationProviderCard(
              provider: entry.$2,
              documents: widget.documents
                  .where((d) => d['provider_id'] == entry.$2['id'])
                  .toList(),
              initiallyExpanded: entry.$1 == 0,
              auth: widget.auth,
              run: widget.run,
            ),
          ),
      ],
    );
  }
}

class _VerificationProviderCard extends StatelessWidget {
  const _VerificationProviderCard({
    required this.provider,
    required this.documents,
    required this.initiallyExpanded,
    required this.auth,
    required this.run,
  });

  final Json provider;
  final List<Json> documents;
  final bool initiallyExpanded;
  final AuthService auth;
  final void Function(Future<void> Function(), String) run;

  @override
  Widget build(BuildContext context) {
    final pending = documents.where((d) => d['status'] == 'pending').length;
    final approved = documents.where((d) => d['status'] == 'approved').length;
    final progress = documents.isEmpty ? 0.0 : approved / documents.length;
    final submitted = documents
        .map((d) => DateTime.tryParse(_str(d['created_at'])))
        .whereType<DateTime>()
        .fold<DateTime?>(
          null,
          (oldest, date) =>
              oldest == null || date.isBefore(oldest) ? date : oldest,
        );

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: const Color(0xff102437),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xff294359)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x28000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          childrenPadding: EdgeInsets.zero,
          leading: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.amber.withValues(alpha: .13),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _initial(_str(provider['provider_name'])),
              style: const TextStyle(
                color: AppTheme.amber,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          title: Row(
            children: [
              Flexible(
                child: Text(
                  _str(provider['provider_name'], 'Unnamed provider'),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 9),
              _Status('pending'),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                _ReviewMeta(
                  Icons.person_outline,
                  _str(provider['owner_name'], 'Owner not provided'),
                ),
                _ReviewMeta(
                  Icons.location_on_outlined,
                  _str(provider['primary_city'], 'Location not provided'),
                ),
                _ReviewMeta(
                  Icons.schedule_outlined,
                  submitted == null
                      ? 'Submission date unavailable'
                      : 'Submitted ${_date(submitted.toIso8601String())}',
                ),
              ],
            ),
          ),
          trailing: SizedBox(
            width: 92,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$pending pending',
                  style: const TextStyle(
                    color: Color(0xffffb547),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    minHeight: 4,
                    value: progress,
                    backgroundColor: const Color(0xff294257),
                    color: const Color(0xff25c47a),
                  ),
                ),
              ],
            ),
          ),
          children: [
            const Divider(height: 1, color: Color(0xff294359)),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 28,
                    runSpacing: 14,
                    children: [
                      _VerificationStat(
                        label: 'Provider type',
                        value: _pretty(
                          _str(provider['provider_type'], 'Not specified'),
                        ),
                      ),
                      _VerificationStat(
                        label: 'Business name',
                        value: _str(
                          provider['business_name'],
                          _str(provider['provider_name']),
                        ),
                      ),
                      _VerificationStat(
                        label: 'Contact email',
                        value: _str(provider['email'], 'Not provided'),
                      ),
                      _VerificationStat(
                        label: 'Document set',
                        value: '${documents.length} files · $approved approved',
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      const Text(
                        'Submitted documents',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Private · secure links expire after 15 min',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: .46),
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth >= 980
                          ? 4
                          : constraints.maxWidth >= 620
                          ? 3
                          : constraints.maxWidth >= 400
                          ? 2
                          : 1;
                      final width =
                          (constraints.maxWidth - (columns - 1) * 10) / columns;
                      return Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: documents
                            .map(
                              (document) => SizedBox(
                                width: width,
                                child: _VerificationDocumentCard(
                                  document: document,
                                ),
                              ),
                            )
                            .toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(18, 13, 18, 14),
              decoration: const BoxDecoration(
                color: Color(0xff0d2031),
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(14),
                ),
                border: Border(top: BorderSide(color: Color(0xff294359))),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final rejectButton = OutlinedButton.icon(
                    onPressed: () async {
                      final reason = await _reason(
                        context,
                        'Reject ${_str(provider['provider_name'])}',
                      );
                      if (reason == null) return;
                      run(
                        () => auth.adminAction(
                          '/providers/${provider['id']}/verification',
                          action: 'reject',
                          reason: reason,
                        ),
                        'Verification rejected and provider notified',
                      );
                    },
                    icon: const Icon(Icons.close_rounded, size: 17),
                    label: const Text('Reject'),
                  );
                  final approveButton = FilledButton.icon(
                    onPressed: () async {
                      final confirmed = await _confirm(
                        context,
                        'Approve ${_str(provider['provider_name'])}?',
                        'All submitted documents will be approved and the provider will receive the Verified badge.',
                      );
                      if (confirmed != true) return;
                      run(
                        () => auth.adminAction(
                          '/providers/${provider['id']}/verification',
                          action: 'approve',
                        ),
                        'Provider verified and notified',
                      );
                    },
                    icon: const Icon(Icons.verified_outlined, size: 17),
                    label: const Text('Approve provider'),
                  );
                  const note = Row(
                    children: [
                      Icon(
                        Icons.admin_panel_settings_outlined,
                        size: 17,
                        color: Color(0xff7f96a9),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Your decision updates every document and notifies the provider.',
                          style: TextStyle(
                            color: Color(0xff7f96a9),
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  );
                  if (constraints.maxWidth < 700) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        note,
                        const SizedBox(height: 12),
                        Wrap(
                          alignment: WrapAlignment.end,
                          spacing: 9,
                          runSpacing: 8,
                          children: [rejectButton, approveButton],
                        ),
                      ],
                    );
                  }
                  return Row(
                    children: [
                      const Expanded(child: note),
                      rejectButton,
                      const SizedBox(width: 9),
                      approveButton,
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VerificationDocumentCard extends StatelessWidget {
  const _VerificationDocumentCard({required this.document});
  final Json document;

  @override
  Widget build(BuildContext context) {
    final type = _str(document['document_type']);
    final fileUrl = _str(document['file_url']);
    return Material(
      color: const Color(0xff0d2031),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: fileUrl.isEmpty ? null : () => _openUrl(context, fileUrl),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xff263e52)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppTheme.amber.withValues(alpha: .1),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(
                      _docIcon(type),
                      size: 18,
                      color: AppTheme.amber,
                    ),
                  ),
                  const Spacer(),
                  _Status(_str(document['status'], 'pending')),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _pretty(type),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                _date(document['created_at']),
                style: const TextStyle(color: Color(0xff71889c), fontSize: 9),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    fileUrl.isEmpty
                        ? Icons.link_off_rounded
                        : Icons.visibility_outlined,
                    size: 15,
                    color: fileUrl.isEmpty
                        ? const Color(0xffff5c69)
                        : AppTheme.amber,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    fileUrl.isEmpty ? 'File unavailable' : 'Open document',
                    style: TextStyle(
                      color: fileUrl.isEmpty
                          ? const Color(0xffff5c69)
                          : AppTheme.amber,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  if (fileUrl.isNotEmpty)
                    const Icon(
                      Icons.open_in_new_rounded,
                      size: 13,
                      color: Color(0xff71889c),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VerificationStat extends StatelessWidget {
  const _VerificationStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 190,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: Color(0xff60798e),
            fontSize: 8,
            fontWeight: FontWeight.w800,
            letterSpacing: .7,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}

class _ReviewMeta extends StatelessWidget {
  const _ReviewMeta(this.icon, this.value);
  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 13, color: const Color(0xff71889c)),
      const SizedBox(width: 4),
      Text(
        value,
        style: const TextStyle(color: Color(0xff8ba0b2), fontSize: 9),
      ),
    ],
  );
}

class PackagesScreen extends StatelessWidget {
  const PackagesScreen({
    super.key,
    required this.packages,
    required this.auth,
    required this.run,
  });
  final List<Json> packages;
  final AuthService auth;
  final void Function(Future<void> Function(), String) run;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const _Heading('Packages', 'Manage availability across every provider'),
      _Panel(
        title: '${packages.length} packages',
        child: _TableWrap(
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Package name')),
              DataColumn(label: Text('Provider')),
              DataColumn(label: Text('Speed')),
              DataColumn(label: Text('Price')),
              DataColumn(label: Text('Type')),
              DataColumn(label: Text('Available')),
              DataColumn(label: Text('Created')),
            ],
            rows: packages
                .map(
                  (p) => DataRow(
                    cells: [
                      DataCell(Text(_str(p['package_name']))),
                      DataCell(Text(_str(p['provider_name']))),
                      DataCell(Text('${p['speed_mbps'] ?? '—'} Mbps')),
                      DataCell(Text(_money(_num(p['monthly_price'])))),
                      DataCell(
                        Text(_pretty(_str(p['contract_type'], 'monthly'))),
                      ),
                      DataCell(
                        Switch(
                          value: p['is_available'] != false,
                          onChanged: (v) => run(
                            () => auth.updateAdminPackage(_str(p['id']), v),
                            v ? 'Package available' : 'Package hidden',
                          ),
                        ),
                      ),
                      DataCell(Text(_date(p['created_at']))),
                    ],
                  ),
                )
                .toList(),
          ),
        ),
      ),
    ],
  );
}

class CoverageZonesScreen extends StatelessWidget {
  const CoverageZonesScreen({super.key, required this.zones});
  final List<Json> zones;
  @override
  Widget build(BuildContext context) {
    final points = zones
        .where((z) => _num(z['latitude']) != 0 || _num(z['longitude']) != 0)
        .toList();
    final center = points.isEmpty
        ? const LatLng(-1.286389, 36.817223)
        : LatLng(
            _num(points.first['latitude']),
            _num(points.first['longitude']),
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Heading(
          'Coverage zones',
          'Tap a live coverage circle for provider details',
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            height: math.max(480, MediaQuery.sizeOf(context).height - 180),
            child: FlutterMap(
              options: MapOptions(initialCenter: center, initialZoom: 10),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.onanet.app',
                ),
                CircleLayer(
                  circles: points
                      .map(
                        (z) => CircleMarker(
                          point: LatLng(
                            _num(z['latitude']),
                            _num(z['longitude']),
                          ),
                          radius: _num(z['radius_km'], 1) * 1000,
                          useRadiusInMeter: true,
                          color: _providerColor(
                            _str(z['provider_type']),
                          ).withValues(alpha: .25),
                          borderColor: _providerColor(_str(z['provider_type'])),
                          borderStrokeWidth: 2,
                        ),
                      )
                      .toList(),
                ),
                MarkerLayer(
                  markers: points
                      .map(
                        (z) => Marker(
                          point: LatLng(
                            _num(z['latitude']),
                            _num(z['longitude']),
                          ),
                          width: 36,
                          height: 36,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: Icon(
                              Icons.location_on,
                              color: _providerColor(_str(z['provider_type'])),
                            ),
                            onPressed: () => showDialog<void>(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: Text(_str(z['provider_name'])),
                                content: Text(
                                  '${_str(z['area_name'])}\nRadius: ${z['radius_km']} km',
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
                const RichAttributionWidget(
                  attributions: [
                    TextSourceAttribution('OpenStreetMap contributors'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class UsersScreen extends StatefulWidget {
  const UsersScreen({
    super.key,
    required this.users,
    required this.auth,
    required this.run,
  });
  final List<Json> users;
  final AuthService auth;
  final void Function(Future<void> Function(), String) run;
  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  String query = '', filter = 'all';
  final Set<String> _selectedUserIds = {};
  bool _selectionMode = false;

  void _clearSelection() {
    _selectedUserIds.clear();
    _selectionMode = false;
  }

  List<Json> get _selectedUsers => widget.users
      .where((user) => _selectedUserIds.contains(_str(user['id'])))
      .toList();

  Future<void> _bulkModerate(bool ban) async {
    final selected = _selectedUsers;
    if (selected.isEmpty) return;
    if (await _confirm(
          context,
          '${ban ? 'Ban' : 'Unban'} ${selected.length} accounts?',
          'This changes platform access for every selected account.',
        ) !=
        true) {
      return;
    }
    widget.run(
      () async {
        for (final user in selected) {
          await widget.auth.adminAction(
            '/users/${user['id']}/moderation',
            action: ban ? 'ban' : 'unban',
          );
        }
        if (mounted) setState(_clearSelection);
      },
      ban
          ? '${selected.length} accounts banned'
          : '${selected.length} accounts restored',
    );
  }

  Future<void> _bulkDelete() async {
    final selected = _selectedUsers
        .where((user) => _str(user['role'], 'user') != 'admin')
        .toList();
    if (selected.isEmpty) return;
    final reason = await _reason(
      context,
      'Why delete ${selected.length} selected accounts?',
    );
    if (reason == null || !mounted) return;
    if (await _confirm(
          context,
          'Permanently delete ${selected.length} accounts?',
          'All selected accounts and their OnaNet data will be deleted. This cannot be undone.\n\nReason: $reason',
        ) !=
        true) {
      return;
    }
    widget.run(() async {
      for (final user in selected) {
        await widget.auth.adminAction(
          '/users/${user['id']}/delete',
          action: 'delete',
          reason: reason,
        );
      }
      if (mounted) setState(_clearSelection);
    }, '${selected.length} accounts deleted successfully');
  }

  @override
  Widget build(BuildContext context) {
    final users = widget.users.where((u) {
      final name =
          '${u['first_name']} ${u['last_name']} ${u['email']} ${u['phone_number']}'
              .toLowerCase();
      return name.contains(query.toLowerCase()) &&
          (filter == 'all' || u['status'] == filter);
    }).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Heading('Users', 'Customer accounts and platform access'),
        _Search(
          onChanged: (v) => setState(() => query = v),
          hint: 'Search users',
        ),
        _Filters(
          values: const ['all', 'active', 'banned'],
          selected: filter,
          onSelected: (v) => setState(() => filter = v),
        ),
        if (_selectedUserIds.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.amber.withValues(alpha: 0.12),
              border: Border.all(color: AppTheme.amber.withValues(alpha: 0.35)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${_selectedUserIds.length} account${_selectedUserIds.length == 1 ? '' : 's'} selected',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(_clearSelection),
                  child: const Text('Clear'),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Bulk actions',
                  onSelected: (action) {
                    if (action == 'ban') _bulkModerate(true);
                    if (action == 'unban') _bulkModerate(false);
                    if (action == 'delete') _bulkDelete();
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'ban', child: Text('Ban selected')),
                    PopupMenuItem(
                      value: 'unban',
                      child: Text('Unban selected'),
                    ),
                    PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        'Delete selected',
                        style: TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  ],
                  child: const Chip(
                    avatar: Icon(Icons.more_horiz_rounded, size: 18),
                    label: Text('Bulk actions'),
                  ),
                ),
              ],
            ),
          ),
        _Panel(
          title: '${users.length} users',
          child: _TableWrap(
            child: DataTable(
              showCheckboxColumn: _selectionMode,
              onSelectAll: _selectionMode
                  ? (selected) {
                      setState(() {
                        final selectableIds = users
                            .where(
                              (user) => _str(user['role'], 'user') != 'admin',
                            )
                            .map((user) => _str(user['id']));
                        if (selected == true) {
                          _selectedUserIds.addAll(selectableIds);
                        } else {
                          _clearSelection();
                        }
                      });
                    }
                  : null,
              columns: const [
                DataColumn(label: Text('User')),
                DataColumn(label: Text('Phone')),
                DataColumn(label: Text('Area')),
                DataColumn(label: Text('Tickets')),
                DataColumn(label: Text('Joined')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Role')),
                DataColumn(label: Text('Actions')),
              ],
              rows: users.map((u) {
                final banned = u['status'] == 'banned';
                final userId = _str(u['id']);
                final isAdmin = _str(u['role'], 'user') == 'admin';
                return DataRow(
                  selected: _selectedUserIds.contains(userId),
                  onLongPress: isAdmin
                      ? null
                      : () => setState(() {
                          _selectionMode = true;
                          _selectedUserIds.add(userId);
                        }),
                  onSelectChanged: !_selectionMode || isAdmin
                      ? null
                      : (selected) => setState(() {
                          if (selected == true) {
                            _selectedUserIds.add(userId);
                          } else {
                            _selectedUserIds.remove(userId);
                            if (_selectedUserIds.isEmpty) {
                              _selectionMode = false;
                            }
                          }
                        }),
                  cells: [
                    DataCell(
                      _Identity(
                        '${_str(u['first_name'])} ${_str(u['last_name'])}'
                            .trim(),
                        _str(u['email']),
                      ),
                    ),
                    DataCell(Text(_maskPhone(_str(u['phone_number'])))),
                    DataCell(Text(_str(u['primary_city'], '—'))),
                    DataCell(Text('${u['ticket_count'] ?? 0}')),
                    DataCell(Text(_date(u['created_at']))),
                    DataCell(_Status(_str(u['status'], 'active'))),
                    DataCell(
                      _Status(
                        _str(u['role'], 'user') == 'admin' ? 'admin' : 'user',
                      ),
                    ),
                    DataCell(
                      PopupMenuButton<String>(
                        tooltip: 'User actions',
                        icon: const Icon(Icons.more_horiz_rounded),
                        onSelected: (action) async {
                          if (action == 'promote') {
                            if (await _confirm(
                                  context,
                                  'Promote to administrator?',
                                  '${_str(u['email'])} will receive full access to users, providers, reports, billing and platform controls. Only continue if you trust this person.',
                                ) !=
                                true) {
                              return;
                            }
                            widget.run(
                              () => widget.auth.adminAction(
                                '/users/${u['id']}/role',
                                action: 'promote_admin',
                              ),
                              '${_str(u['email'])} promoted to admin',
                            );
                            return;
                          }
                          if (action == 'moderate') {
                            if (await _confirm(
                                  context,
                                  '${banned ? 'Unban' : 'Ban'} user?',
                                  'This changes the user’s platform access.',
                                ) !=
                                true) {
                              return;
                            }
                            widget.run(
                              () => widget.auth.adminAction(
                                '/users/${u['id']}/moderation',
                                action: banned ? 'unban' : 'ban',
                              ),
                              banned ? 'User restored' : 'User banned',
                            );
                            return;
                          }
                          if (action == 'delete') {
                            final reason = await _reason(
                              context,
                              'Why delete ${_str(u['email'])}?',
                            );
                            if (reason == null || !context.mounted) return;
                            if (await _confirm(
                                  context,
                                  'Permanently delete this user?',
                                  '${_str(u['email'])} and their OnaNet data will be deleted. This action cannot be undone.\n\nReason: $reason',
                                ) !=
                                true) {
                              return;
                            }
                            widget.run(
                              () => widget.auth.adminAction(
                                '/users/${u['id']}/delete',
                                action: 'delete',
                                reason: reason,
                              ),
                              'Account deleted successfully',
                            );
                          }
                        },
                        itemBuilder: (context) => [
                          if (_str(u['role'], 'user') != 'admin')
                            const PopupMenuItem(
                              value: 'promote',
                              child: ListTile(
                                dense: true,
                                leading: Icon(
                                  Icons.admin_panel_settings_outlined,
                                ),
                                title: Text('Promote to admin'),
                              ),
                            ),
                          PopupMenuItem(
                            value: 'moderate',
                            child: ListTile(
                              dense: true,
                              leading: Icon(
                                banned
                                    ? Icons.lock_open_rounded
                                    : Icons.block_rounded,
                              ),
                              title: Text(banned ? 'Unban user' : 'Ban user'),
                            ),
                          ),
                          if (_str(u['role'], 'user') != 'admin')
                            const PopupMenuItem(
                              value: 'delete',
                              child: ListTile(
                                dense: true,
                                leading: Icon(
                                  Icons.delete_forever_outlined,
                                  color: Colors.redAccent,
                                ),
                                title: Text(
                                  'Delete user',
                                  style: TextStyle(color: Colors.redAccent),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({
    super.key,
    required this.reports,
    required this.auth,
    required this.run,
  });
  final List<Json> reports;
  final AuthService auth;
  final void Function(Future<void> Function(), String) run;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const _Heading('Reports', 'Investigate safety and trust reports'),
      if (reports.isEmpty)
        const _Panel(
          title: 'Reports',
          child: _Empty('No reports have been submitted'),
        )
      else
        ...reports.map(
          (r) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _Panel(
              title: _pretty(_str(r['report_type'])),
              trailing: _Status(_str(r['status'])),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_str(r['reporter_name'])} reported ${_str(r['reported_name'])}',
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _str(r['details']),
                      style: const TextStyle(color: Color(0xff93a6b8)),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _dateTime(r['created_at']),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xff71889c),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final action in [
                          'warn',
                          'suspend',
                          'ban',
                          'dismiss',
                        ])
                          OutlinedButton(
                            onPressed: () async {
                              if (action == 'ban' &&
                                  await _confirm(
                                        context,
                                        'Permanently ban provider?',
                                        'This is the strongest moderation action.',
                                      ) !=
                                      true) {
                                return;
                              }
                              run(
                                () => auth.adminAction(
                                  '/reports/${r['id']}/action',
                                  action: action,
                                ),
                                'Report action saved',
                              );
                            },
                            child: Text(_pretty(action)),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
    ],
  );
}

class SubscriptionsScreen extends StatelessWidget {
  const SubscriptionsScreen({
    super.key,
    required this.providers,
    required this.auth,
    required this.run,
  });
  final List<Json> providers;
  final AuthService auth;
  final void Function(Future<void> Function(), String) run;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Heading(
          'Subscriptions',
          'Plans, renewals and recurring revenue',
        ),
        _MetricGrid(
          items: ['free', 'growth', 'pro'].map((plan) {
            final count = providers
                .where((p) => p['subscription_tier'] == plan)
                .length;
            return (
              '${_pretty(plan)} MRR',
              _money(count * _planPrice(plan)),
              Icons.credit_card,
              '$count providers',
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        _Panel(
          title: 'All subscriptions',
          child: _TableWrap(
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Provider')),
                DataColumn(label: Text('Plan')),
                DataColumn(label: Text('Started')),
                DataColumn(label: Text('Expires')),
                DataColumn(label: Text('Amount')),
                DataColumn(label: Text('Payment')),
                DataColumn(label: Text('Actions')),
              ],
              rows: providers
                  .map(
                    (p) => DataRow(
                      cells: [
                        DataCell(Text(_str(p['provider_name']))),
                        DataCell(
                          _Pill(_pretty(_str(p['subscription_tier'], 'free'))),
                        ),
                        DataCell(Text(_date(p['created_at']))),
                        DataCell(Text(_date(p['subscription_expires_at']))),
                        DataCell(
                          Text(
                            _money(_planPrice(_str(p['subscription_tier']))),
                          ),
                        ),
                        DataCell(_Status('paid')),
                        DataCell(
                          PopupMenuButton<String>(
                            onSelected: (plan) {
                              final current = _str(
                                p['subscription_tier'],
                                'free',
                              );
                              run(
                                () => auth.adminAction(
                                  '/subscriptions/${p['id']}/action',
                                  action: plan == 'free'
                                      ? 'cancel'
                                      : (_planPrice(plan) > _planPrice(current)
                                            ? 'upgrade'
                                            : 'downgrade'),
                                  value: plan,
                                ),
                                'Subscription updated',
                              );
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'growth',
                                child: Text('Set Growth'),
                              ),
                              PopupMenuItem(
                                value: 'pro',
                                child: Text('Set Pro'),
                              ),
                              PopupMenuItem(
                                value: 'free',
                                child: Text('Cancel to Free'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }
}

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({
    super.key,
    required this.invoices,
    required this.auth,
    required this.run,
  });
  final List<Json> invoices;
  final AuthService auth;
  final void Function(Future<void> Function(), String) run;
  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  String filter = 'all';
  @override
  Widget build(BuildContext context) {
    final rows = widget.invoices
        .where((e) => filter == 'all' || e['status'] == filter)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Heading('Invoices', 'Billing records and payment follow-up'),
        _Filters(
          values: const ['all', 'paid', 'overdue', 'pending'],
          selected: filter,
          onSelected: (v) => setState(() => filter = v),
        ),
        _Panel(
          title: '${rows.length} invoices',
          child: rows.isEmpty
              ? const _Empty('No invoices match this filter')
              : _TableWrap(
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Invoice #')),
                      DataColumn(label: Text('Provider')),
                      DataColumn(label: Text('Plan')),
                      DataColumn(label: Text('Amount')),
                      DataColumn(label: Text('Period')),
                      DataColumn(label: Text('Due date')),
                      DataColumn(label: Text('Status')),
                      DataColumn(label: Text('Actions')),
                    ],
                    rows: rows
                        .map(
                          (i) => DataRow(
                            cells: [
                              DataCell(Text(_str(i['invoice_number']))),
                              DataCell(Text(_str(i['provider_name']))),
                              DataCell(Text(_pretty(_str(i['plan'])))),
                              DataCell(Text(_money(_num(i['amount'])))),
                              DataCell(Text(_str(i['period']))),
                              DataCell(Text(_date(i['due_date']))),
                              DataCell(_Status(_str(i['status']))),
                              DataCell(
                                PopupMenuButton<String>(
                                  onSelected: (action) {
                                    if (action == 'pdf') {
                                      _showInvoice(context, i);
                                    } else {
                                      widget.run(
                                        () => widget.auth.adminAction(
                                          '/invoices/${i['id']}/action',
                                          action: action,
                                        ),
                                        action == 'paid'
                                            ? 'Invoice marked paid'
                                            : 'Reminder sent',
                                      );
                                    }
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(
                                      value: 'paid',
                                      child: Text('Mark as paid'),
                                    ),
                                    PopupMenuItem(
                                      value: 'remind',
                                      child: Text('Send reminder'),
                                    ),
                                    PopupMenuItem(
                                      value: 'pdf',
                                      child: Text('View invoice'),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )
                        .toList(),
                  ),
                ),
        ),
      ],
    );
  }
}

class RevenueScreen extends StatelessWidget {
  const RevenueScreen({
    super.key,
    required this.providers,
    required this.invoices,
  });
  final List<Json> providers, invoices;
  @override
  Widget build(BuildContext context) {
    final paid = invoices.where((i) => i['status'] == 'paid').toList();
    final total = paid.fold<double>(0, (s, i) => s + _num(i['amount']));
    final planTotals = {
      for (final plan in ['free', 'growth', 'pro'])
        plan:
            providers.where((p) => p['subscription_tier'] == plan).length *
            _planPrice(plan),
    };
    final spots = List.generate(
      6,
      (i) =>
          FlSpot(i.toDouble(), total == 0 ? i * 1000 : total * (.65 + i * .07)),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Heading(
          'Revenue',
          'Recurring revenue performance from live billing data',
        ),
        _MetricGrid(
          items: [
            (
              'Current MRR',
              _money(planTotals.values.fold(0, (a, b) => a + b)),
              Icons.payments,
              'all plans',
            ),
            (
              'Collected',
              _money(total),
              Icons.account_balance_wallet_outlined,
              'paid invoices',
            ),
            (
              'Monthly growth',
              spots.length > 1
                  ? '+${((spots.last.y / math.max(spots.first.y, 1) - 1) * 100).toStringAsFixed(1)}%'
                  : '0%',
              Icons.trending_up,
              '6 month trend',
            ),
          ],
        ),
        const SizedBox(height: 16),
        _ResponsivePair(
          left: _Panel(
            title: 'Monthly MRR',
            child: SizedBox(
              height: 280,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 18, 20, 8),
                child: LineChart(
                  LineChartData(
                    borderData: FlBorderData(show: false),
                    gridData: const FlGridData(show: true),
                    titlesData: const FlTitlesData(
                      topTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        color: AppTheme.amber,
                        barWidth: 3,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          color: AppTheme.amber.withValues(alpha: .12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          right: _Panel(
            title: 'Revenue by plan',
            child: SizedBox(
              height: 280,
              child: PieChart(
                PieChartData(
                  centerSpaceRadius: 50,
                  sectionsSpace: 3,
                  sections: [
                    for (final entry in planTotals.entries)
                      PieChartSectionData(
                        value: math.max(
                          entry.value,
                          entry.key == 'free' ? 1 : 0,
                        ),
                        title: '${_pretty(entry.key)}\n${_money(entry.value)}',
                        color: _planColor(entry.key),
                        radius: 78,
                        titleStyle: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _Panel(
          title: 'Revenue by provider type',
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 28,
              runSpacing: 16,
              children: _typeRevenue(providers).entries
                  .map(
                    (e) => SizedBox(
                      width: 200,
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 7,
                            backgroundColor: _providerColor(e.key),
                          ),
                          const SizedBox(width: 9),
                          Expanded(child: Text(_pretty(e.key))),
                          Text(
                            _money(e.value),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.title, this.subtitle);
  final String title, subtitle;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(color: Color(0xff8297a9), fontSize: 12),
        ),
      ],
    ),
  );
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.items});
  final List<(String, String, IconData, String)> items;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (_, c) {
      final count = c.maxWidth >= 900
          ? 4
          : c.maxWidth >= 520
          ? 2
          : 1;
      final width = (c.maxWidth - (count - 1) * 12) / count;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: items
            .map(
              (item) => SizedBox(
                width: width,
                child: _Panel(
                  title: item.$1,
                  trailing: Icon(item.$3, color: AppTheme.amber, size: 19),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          item.$2,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 9),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Text(
                            item.$4,
                            style: const TextStyle(
                              color: Color(0xff26c281),
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      );
    },
  );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child, this.trailing});
  final String title;
  final Widget child;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: const Color(0xff102437),
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: const Color(0xff21384b)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 11),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
        ),
        child,
      ],
    ),
  );
}

class _ResponsivePair extends StatelessWidget {
  const _ResponsivePair({required this.left, required this.right});
  final Widget left, right;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (_, c) {
      if (c.maxWidth < 720) {
        return Column(children: [left, const SizedBox(height: 12), right]);
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: left),
          const SizedBox(width: 12),
          Expanded(child: right),
        ],
      );
    },
  );
}

class _TableWrap extends StatelessWidget {
  const _TableWrap({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) =>
      SingleChildScrollView(scrollDirection: Axis.horizontal, child: child);
}

class _MiniList extends StatelessWidget {
  const _MiniList({
    required this.items,
    required this.title,
    required this.subtitle,
    required this.icon,
  });
  final List<Json> items;
  final String Function(Json) title, subtitle;
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const _Empty('Nothing needs attention');
    return Column(
      children: items
          .map(
            (e) => ListTile(
              dense: true,
              leading: CircleAvatar(
                radius: 16,
                backgroundColor: const Color(0xff17344c),
                child: Icon(icon, size: 16),
              ),
              title: Text(
                title(e),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(subtitle(e), style: const TextStyle(fontSize: 10)),
            ),
          )
          .toList(),
    );
  }
}

class _Search extends StatelessWidget {
  const _Search({required this.onChanged, required this.hint});
  final ValueChanged<String> onChanged;
  final String hint;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: SizedBox(
      width: 420,
      child: TextField(
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: const Color(0xff102437),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    ),
  );
}

class _Filters extends StatelessWidget {
  const _Filters({
    required this.values,
    required this.selected,
    required this.onSelected,
  });
  final List<String> values;
  final String selected;
  final ValueChanged<String> onSelected;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Wrap(
      spacing: 7,
      children: values
          .map(
            (v) => FilterChip(
              label: Text(_pretty(v)),
              selected: selected == v,
              onSelected: (_) => onSelected(v),
            ),
          )
          .toList(),
    ),
  );
}

class _Pager extends StatelessWidget {
  const _Pager({required this.page, required this.pages, required this.change});
  final int page, pages;
  final ValueChanged<int> change;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        IconButton(
          onPressed: page > 0 ? () => change(page - 1) : null,
          icon: const Icon(Icons.chevron_left),
        ),
        Text(
          'Page ${page + 1} of $pages',
          style: const TextStyle(fontSize: 12),
        ),
        IconButton(
          onPressed: page + 1 < pages ? () => change(page + 1) : null,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    ),
  );
}

class _Identity extends StatelessWidget {
  const _Identity(this.title, this.subtitle);
  final String title, subtitle;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      CircleAvatar(
        radius: 14,
        backgroundColor: AppTheme.amber.withValues(alpha: .15),
        child: Text(_initial(title), style: const TextStyle(fontSize: 9)),
      ),
      const SizedBox(width: 8),
      Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.isEmpty ? 'Unnamed' : title,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 9, color: Color(0xff7f94a7)),
          ),
        ],
      ),
    ],
  );
}

class _Status extends StatelessWidget {
  const _Status(this.value);
  final String value;
  @override
  Widget build(BuildContext context) {
    final color = switch (value.toLowerCase()) {
      'active' || 'approved' || 'verified' || 'paid' => const Color(0xff25c47a),
      'banned' || 'rejected' || 'overdue' => const Color(0xffff5c69),
      _ => const Color(0xffffb547),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _pretty(value),
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.value);
  final String value;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: AppTheme.amber.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      value,
      style: const TextStyle(
        color: AppTheme.amber,
        fontSize: 9,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _Empty extends StatelessWidget {
  const _Empty(this.value);
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(28),
    child: Center(
      child: Text(
        value,
        style: const TextStyle(color: Color(0xff8095a8), fontSize: 12),
      ),
    ),
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.retry});
  final String message;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off, size: 42),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(onPressed: retry, child: const Text('Retry')),
        ],
      ),
    ),
  );
}

DataRow _providerRow(Json p) => DataRow(
  cells: [
    DataCell(_Identity(_str(p['provider_name']), _str(p['email']))),
    DataCell(Text(_pretty(_str(p['provider_type'])))),
    DataCell(_Pill(_pretty(_str(p['subscription_tier'], 'free')))),
    DataCell(_Status(p['is_verified'] == true ? 'verified' : 'pending')),
    DataCell(_Status(_str(p['status'], 'active'))),
  ],
);

Future<bool?> _confirm(BuildContext context, String title, String body) =>
    showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

Future<String?> _reason(BuildContext context, String title) =>
    showDialog<String>(
      context: context,
      builder: (_) => _ReasonDialog(title: title),
    );

class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog({required this.title});

  final String title;

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        minLines: 3,
        maxLines: 5,
        decoration: const InputDecoration(
          labelText: 'Reason',
          hintText: 'Explain this decision',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final reason = _controller.text.trim();
            if (reason.isNotEmpty) Navigator.pop(context, reason);
          },
          child: const Text('Continue'),
        ),
      ],
    );
  }
}

void _showInvoice(BuildContext context, Json invoice) => showDialog<void>(
  context: context,
  builder: (_) => AlertDialog(
    title: Text('Invoice ${_str(invoice['invoice_number'])}'),
    content: Text(
      'Provider: ${_str(invoice['provider_name'])}\n'
      'Plan: ${_pretty(_str(invoice['plan']))}\n'
      'Amount: ${_money(_num(invoice['amount']))}\n'
      'Period: ${_str(invoice['period'])}\n'
      'Due: ${_date(invoice['due_date'])}\n'
      'Status: ${_pretty(_str(invoice['status']))}',
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Close'),
      ),
    ],
  ),
);

Future<void> _openUrl(BuildContext context, String value) async {
  final uri = Uri.tryParse(value);
  if (uri == null ||
      !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Document could not be opened')),
      );
    }
  }
}

Map<String, double> _typeRevenue(List<Json> providers) {
  final result = <String, double>{};
  for (final p in providers) {
    final type = _str(p['provider_type'], 'other');
    result[type] =
        (result[type] ?? 0) + _planPrice(_str(p['subscription_tier']));
  }
  return result;
}

Color _providerColor(String type) => switch (type.toLowerCase()) {
  'wisp' => const Color(0xff38bdf8),
  'fiber' || 'fibre' => const Color(0xffa78bfa),
  'reseller' => const Color(0xffffb547),
  _ => const Color(0xff25c47a),
};
Color _planColor(String plan) => switch (plan) {
  'pro' => const Color(0xffa78bfa),
  'growth' => AppTheme.amber,
  _ => const Color(0xff52697d),
};
IconData _docIcon(String type) => type.contains('photo')
    ? Icons.photo_camera_outlined
    : type.contains('id')
    ? Icons.badge_outlined
    : Icons.description_outlined;
double _planPrice(String plan) => switch (plan.toLowerCase()) {
  'growth' => 1500,
  'pro' => 2500,
  _ => 0,
};
List<Json> _list(dynamic value) => value is List
    ? value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
    : [];
Json _map(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : {};
String _str(dynamic value, [String fallback = '']) {
  final result = value?.toString().trim() ?? '';
  return result.isEmpty || result == 'null' ? fallback : result;
}

double _num(dynamic value, [double fallback = 0]) =>
    value is num ? value.toDouble() : double.tryParse('$value') ?? fallback;
String _pretty(String value) => value
    .replaceAll('_', ' ')
    .split(' ')
    .map((e) => e.isEmpty ? e : '${e[0].toUpperCase()}${e.substring(1)}')
    .join(' ');
String _initial(String value) =>
    value.trim().isEmpty ? 'A' : value.trim()[0].toUpperCase();
String _money(num value) =>
    'KES ${value.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\\d)(?=(\\d{3})+(?!\\d))'), (m) => '${m[1]},')}';
String _date(dynamic value) {
  final date = DateTime.tryParse(_str(value));
  if (date == null) return '—';
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

String _dateTime(dynamic value) {
  final date = DateTime.tryParse(_str(value))?.toLocal();
  if (date == null) return '—';
  return '${_date(date.toIso8601String())} · ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

String _maskPhone(String value) {
  if (value.length < 6) return value.isEmpty ? '—' : '••••';
  return '${value.substring(0, 3)} ••• ${value.substring(value.length - 3)}';
}
