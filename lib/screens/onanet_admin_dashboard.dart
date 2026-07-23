import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ona_net/auth/auth_service.dart';
import 'package:ona_net/themes/app_theme.dart';
import 'package:ona_net/utils/provider_filters.dart';

enum _AdminView { overview, documents, users, providers }

class OnaNetAdminDashboard extends StatefulWidget {
  const OnaNetAdminDashboard({super.key});

  @override
  State<OnaNetAdminDashboard> createState() => _OnaNetAdminDashboardState();
}

class _OnaNetAdminDashboardState extends State<OnaNetAdminDashboard> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  _AdminView _view = _AdminView.overview;
  late Future<List<Map<String, dynamic>>> _providers = _loadProviders();
  final Set<String> _removedProviderIds = {};
  final Set<String> _bannedProviderIds = {};
  final List<_DocumentSubmission> _documents = [
    _DocumentSubmission(
      id: 'doc-001',
      provider: 'MetroLink Fibre',
      type: 'Business registration',
      submitted: DateTime(2026, 7, 23, 9, 42),
      fileName: 'business_registration.pdf',
    ),
    _DocumentSubmission(
      id: 'doc-002',
      provider: 'SwiftWave Networks',
      type: 'CAK licence',
      submitted: DateTime(2026, 7, 22, 16, 18),
      fileName: 'cak_licence.pdf',
    ),
    _DocumentSubmission(
      id: 'doc-003',
      provider: 'HomeGrid Internet',
      type: 'National ID',
      submitted: DateTime(2026, 7, 22, 11, 7),
      fileName: 'national_id_front.jpg',
    ),
  ];
  final List<_AdminUser> _users = const [
    _AdminUser(
      name: 'Amina Kamau',
      email: 'amina@example.com',
      role: 'Customer',
      status: 'Active',
      joined: '23 Jul 2026',
    ),
    _AdminUser(
      name: 'Brian Otieno',
      email: 'brian@example.com',
      role: 'Customer',
      status: 'Active',
      joined: '22 Jul 2026',
    ),
    _AdminUser(
      name: 'MetroLink Fibre',
      email: 'admin@metrolink.example',
      role: 'Provider',
      status: 'Pending review',
      joined: '21 Jul 2026',
    ),
    _AdminUser(
      name: 'SwiftWave Networks',
      email: 'owner@swiftwave.example',
      role: 'Provider',
      status: 'Active',
      joined: '18 Jul 2026',
    ),
  ];

  Future<List<Map<String, dynamic>>> _loadProviders() {
    return AuthService().getPublicProviders(forceRefresh: true);
  }

  Future<void> _refreshProviders() async {
    final request = _loadProviders();
    setState(() {
      _providers = request;
    });
    await request;
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 920;
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      drawer: wide
          ? null
          : Drawer(
              child: SafeArea(
                child: _AdminNavigation(
                  selected: _view,
                  onSelected: (view) {
                    Navigator.pop(context);
                    setState(() => _view = view);
                  },
                ),
              ),
            ),
      body: SafeArea(
        child: Row(
          children: [
            if (wide)
              SizedBox(
                width: 250,
                child: _AdminNavigation(
                  selected: _view,
                  onSelected: (view) => setState(() => _view = view),
                ),
              ),
            Expanded(
              child: Column(
                children: [
                  _AdminTopBar(
                    title: _viewTitle(_view),
                    showMenu: !wide,
                    onMenu: () => _scaffoldKey.currentState?.openDrawer(),
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _refreshProviders,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(
                          wide ? 28 : 18,
                          10,
                          wide ? 28 : 18,
                          36,
                        ),
                        children: [
                          const _PreviewBanner(),
                          const SizedBox(height: 18),
                          switch (_view) {
                            _AdminView.overview => _OverviewView(
                              documents: _documents,
                              users: _users,
                              providers: _providers,
                              onOpenDocuments: () =>
                                  setState(() => _view = _AdminView.documents),
                              onOpenProviders: () =>
                                  setState(() => _view = _AdminView.providers),
                            ),
                            _AdminView.documents => _DocumentsView(
                              documents: _documents,
                              onReview: _reviewDocument,
                            ),
                            _AdminView.users => _UsersView(users: _users),
                            _AdminView.providers => _ProvidersView(
                              providers: _providers,
                              removedIds: _removedProviderIds,
                              bannedIds: _bannedProviderIds,
                              onInvestigate: _investigateProvider,
                            ),
                          },
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _reviewDocument(_DocumentSubmission document) async {
    final result = await showModalBottomSheet<_DocumentStatus>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _DocumentReviewSheet(document: document),
    );
    if (result == null || !mounted) return;
    setState(() => document.status = result);
    _previewMessage(
      result == _DocumentStatus.approved
          ? '${document.provider} would receive the Verified badge.'
          : '${document.provider} would be asked to resubmit this document.',
    );
  }

  Future<void> _investigateProvider(Map<String, dynamic> provider) async {
    final action = await showModalBottomSheet<_ProviderAction>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ProviderInvestigationSheet(
        provider: provider,
        isBanned: _bannedProviderIds.contains(provider['id']?.toString()),
      ),
    );
    if (action == null || !mounted) return;
    final id = provider['id']?.toString() ?? providerName(provider);
    if (action == _ProviderAction.ban) {
      final reason = await _banReason(providerName(provider));
      if (reason == null || !mounted) return;
      setState(() => _bannedProviderIds.add(id));
      _previewMessage(
        '${providerName(provider)} is shown as banned in this UI preview. Reason: $reason',
      );
    } else if (action == _ProviderAction.restore) {
      setState(() => _bannedProviderIds.remove(id));
      _previewMessage(
        '${providerName(provider)} is shown as restored in this UI preview.',
      );
    } else {
      final confirmed = await _confirmDelete(providerName(provider));
      if (confirmed != true || !mounted) return;
      setState(() => _removedProviderIds.add(id));
      _previewMessage(
        '${providerName(provider)} was removed from this UI preview only.',
      );
    }
  }

  Future<String?> _banReason(String provider) async {
    var reason = '';
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Ban $provider?'),
        content: TextField(
          onChanged: (value) => reason = value.trim(),
          maxLines: 3,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Justified reason',
            hintText: 'Summarize the investigated evidence',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (reason.isNotEmpty) Navigator.pop(dialogContext, reason);
            },
            child: const Text('Confirm ban'),
          ),
        ],
      ),
    );
  }

  Future<bool?> _confirmDelete(String provider) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, color: Colors.red),
        title: const Text('Delete provider permanently?'),
        content: Text(
          'This preview will remove $provider from the directory. The future backend action must require a completed investigation and a second confirmation.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete provider'),
          ),
        ],
      ),
    );
  }

  void _previewMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }
}

class _AdminTopBar extends StatelessWidget {
  const _AdminTopBar({
    required this.title,
    required this.showMenu,
    required this.onMenu,
  });

  final String title;
  final bool showMenu;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 18, 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).colorScheme.outline),
        ),
      ),
      child: Row(
        children: [
          if (showMenu)
            IconButton(onPressed: onMenu, icon: const Icon(Icons.menu_rounded)),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: AppTheme.amber.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.admin_panel_settings_rounded,
                  size: 17,
                  color: AppTheme.amber,
                ),
                SizedBox(width: 6),
                Text(
                  'Admin',
                  style: TextStyle(
                    color: AppTheme.amber,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminNavigation extends StatelessWidget {
  const _AdminNavigation({required this.selected, required this.onSelected});

  final _AdminView selected;
  final ValueChanged<_AdminView> onSelected;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: dark ? AppTheme.navyMid : AppTheme.white,
      padding: const EdgeInsets.fromLTRB(14, 20, 14, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _AdminBrand(),
          const SizedBox(height: 28),
          for (final item in const [
            (_AdminView.overview, 'Overview', Icons.dashboard_outlined),
            (
              _AdminView.documents,
              'Document review',
              Icons.fact_check_outlined,
            ),
            (_AdminView.users, 'All users', Icons.people_outline_rounded),
            (_AdminView.providers, 'Providers', Icons.cell_tower_rounded),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: ListTile(
                selected: selected == item.$1,
                selectedColor: AppTheme.amber,
                selectedTileColor: AppTheme.amber.withValues(alpha: .11),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
                leading: Icon(item.$3),
                title: Text(
                  item.$2,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                onTap: () => onSelected(item.$1),
              ),
            ),
          const Spacer(),
          const Divider(),
          const ListTile(
            leading: Icon(Icons.shield_outlined, color: AppTheme.green),
            title: Text(
              'UI preview mode',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text('No destructive API calls'),
          ),
        ],
      ),
    );
  }
}

class _AdminBrand extends StatelessWidget {
  const _AdminBrand();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppTheme.amber,
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Icon(Icons.wifi_rounded, color: AppTheme.white),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'OnaNet',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const Text(
              'Platform control',
              style: TextStyle(color: AppTheme.gray, fontSize: 11),
            ),
          ],
        ),
      ],
    );
  }
}

class _PreviewBanner extends StatelessWidget {
  const _PreviewBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppTheme.amber.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.amber.withValues(alpha: .24)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: AppTheme.amber),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'UI preview: provider directory rows are live when available. Customer and document records are sample data until protected admin endpoints are built. Ban, restore, approve, reject and delete do not change the backend.',
              style: TextStyle(fontWeight: FontWeight.w700, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewView extends StatelessWidget {
  const _OverviewView({
    required this.documents,
    required this.users,
    required this.providers,
    required this.onOpenDocuments,
    required this.onOpenProviders,
  });

  final List<_DocumentSubmission> documents;
  final List<_AdminUser> users;
  final Future<List<Map<String, dynamic>>> providers;
  final VoidCallback onOpenDocuments;
  final VoidCallback onOpenProviders;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: providers,
      builder: (context, snapshot) {
        final providerCount = snapshot.data?.length ?? 0;
        final pending = documents
            .where((item) => item.status == _DocumentStatus.pending)
            .length;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _PageIntro(
              title: 'Platform overview',
              subtitle:
                  'Review trust and safety work, accounts and provider health from one place.',
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _MetricCard(
                  label: 'All users',
                  value: '${users.length}',
                  icon: Icons.people_outline_rounded,
                  color: AppTheme.amber,
                ),
                _MetricCard(
                  label: 'Providers',
                  value: '$providerCount',
                  icon: Icons.cell_tower_rounded,
                  color: const Color(0xFF7C3AED),
                ),
                _MetricCard(
                  label: 'Documents pending',
                  value: '$pending',
                  icon: Icons.pending_actions_rounded,
                  color: const Color(0xFFD97706),
                ),
                const _MetricCard(
                  label: 'Open reports',
                  value: '2',
                  icon: Icons.report_outlined,
                  color: Colors.red,
                ),
              ],
            ),
            const SizedBox(height: 18),
            _AdminCard(
              title: 'Review queue',
              action: TextButton(
                onPressed: onOpenDocuments,
                child: const Text('View all'),
              ),
              child: Column(
                children: documents
                    .where(
                      (document) => document.status == _DocumentStatus.pending,
                    )
                    .take(3)
                    .map(
                      (document) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const CircleAvatar(
                          child: Icon(Icons.description_outlined),
                        ),
                        title: Text(document.provider),
                        subtitle: Text(
                          '${document.type}\nSubmitted ${_shortDate(document.submitted)}',
                        ),
                        isThreeLine: true,
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: onOpenDocuments,
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 14),
            _AdminCard(
              title: 'Trust & safety',
              action: TextButton(
                onPressed: onOpenProviders,
                child: const Text('Investigate'),
              ),
              child: const Column(
                children: [
                  _SafetyRow(
                    icon: Icons.report_gmailerrorred_outlined,
                    title: '2 provider reports need review',
                    subtitle: 'Check evidence before restricting an account.',
                    color: Colors.red,
                  ),
                  Divider(height: 24),
                  _SafetyRow(
                    icon: Icons.verified_user_outlined,
                    title: 'Verification decisions',
                    subtitle:
                        'Document approval is separate from paid plan status.',
                    color: AppTheme.green,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DocumentsView extends StatefulWidget {
  const _DocumentsView({required this.documents, required this.onReview});

  final List<_DocumentSubmission> documents;
  final ValueChanged<_DocumentSubmission> onReview;

  @override
  State<_DocumentsView> createState() => _DocumentsViewState();
}

class _DocumentsViewState extends State<_DocumentsView> {
  String _query = '';
  _DocumentStatus? _filter;

  @override
  Widget build(BuildContext context) {
    final documents = widget.documents.where((document) {
      final matchesFilter = _filter == null || document.status == _filter;
      final searchable =
          '${document.provider} ${document.type} ${document.fileName}'
              .toLowerCase();
      return matchesFilter && searchable.contains(_query.toLowerCase());
    }).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _PageIntro(
          title: 'Document submissions',
          subtitle:
              'Open every file, compare the provider identity and record a clear verification decision.',
        ),
        const SizedBox(height: 14),
        TextField(
          onChanged: (value) => setState(() => _query = value),
          decoration: const InputDecoration(
            hintText: 'Search provider or document',
            prefixIcon: Icon(Icons.search_rounded),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _FilterChip(
              label: 'All',
              selected: _filter == null,
              onTap: () => setState(() => _filter = null),
            ),
            for (final status in _DocumentStatus.values)
              _FilterChip(
                label: _documentStatusLabel(status),
                selected: _filter == status,
                onTap: () => setState(() => _filter = status),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (documents.isEmpty)
          const _EmptyAdminState(
            icon: Icons.find_in_page_outlined,
            text: 'No document submissions match this view.',
          )
        else
          ...documents.map(
            (document) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _DocumentCard(
                document: document,
                onTap: () => widget.onReview(document),
              ),
            ),
          ),
      ],
    );
  }
}

class _UsersView extends StatefulWidget {
  const _UsersView({required this.users});

  final List<_AdminUser> users;

  @override
  State<_UsersView> createState() => _UsersViewState();
}

class _UsersViewState extends State<_UsersView> {
  String _query = '';
  String _role = 'All';

  @override
  Widget build(BuildContext context) {
    final users = widget.users.where((user) {
      final roleMatches = _role == 'All' || user.role == _role;
      final searchMatches = '${user.name} ${user.email} ${user.role}'
          .toLowerCase()
          .contains(_query.toLowerCase());
      return roleMatches && searchMatches;
    }).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _PageIntro(
          title: 'All users',
          subtitle:
              'A single directory for customer accounts, providers and their current account state.',
        ),
        const SizedBox(height: 14),
        TextField(
          onChanged: (value) => setState(() => _query = value),
          decoration: const InputDecoration(
            hintText: 'Search name or email',
            prefixIcon: Icon(Icons.search_rounded),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            for (final role in const ['All', 'Customer', 'Provider'])
              _FilterChip(
                label: role,
                selected: _role == role,
                onTap: () => setState(() => _role = role),
              ),
          ],
        ),
        const SizedBox(height: 16),
        ...users.map(
          (user) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _UserCard(user: user),
          ),
        ),
      ],
    );
  }
}

class _ProvidersView extends StatefulWidget {
  const _ProvidersView({
    required this.providers,
    required this.removedIds,
    required this.bannedIds,
    required this.onInvestigate,
  });

  final Future<List<Map<String, dynamic>>> providers;
  final Set<String> removedIds;
  final Set<String> bannedIds;
  final ValueChanged<Map<String, dynamic>> onInvestigate;

  @override
  State<_ProvidersView> createState() => _ProvidersViewState();
}

class _ProvidersViewState extends State<_ProvidersView> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _PageIntro(
          title: 'Provider management',
          subtitle:
              'Review provider identity, reports and platform history before taking a justified action.',
        ),
        const SizedBox(height: 14),
        TextField(
          onChanged: (value) => setState(() => _query = value),
          decoration: const InputDecoration(
            hintText: 'Search provider, area or tier',
            prefixIcon: Icon(Icons.search_rounded),
          ),
        ),
        const SizedBox(height: 16),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: widget.providers,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(30),
                  child: CircularProgressIndicator(),
                ),
              );
            }
            if (snapshot.hasError) {
              return _EmptyAdminState(
                icon: Icons.cloud_off_outlined,
                text: 'Could not load provider preview: ${snapshot.error}',
              );
            }
            final providers = (snapshot.data ?? const []).where((provider) {
              final id = provider['id']?.toString() ?? providerName(provider);
              if (widget.removedIds.contains(id)) return false;
              final searchable = [
                providerName(provider),
                providerPlanTier(provider),
                ...providerCoverageAreas(provider),
              ].join(' ').toLowerCase();
              return searchable.contains(_query.toLowerCase());
            }).toList();
            if (providers.isEmpty) {
              return const _EmptyAdminState(
                icon: Icons.cell_tower_rounded,
                text: 'No providers match this view.',
              );
            }
            return Column(
              children: providers.map((provider) {
                final id = provider['id']?.toString() ?? providerName(provider);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 11),
                  child: _ProviderAdminCard(
                    provider: provider,
                    banned: widget.bannedIds.contains(id),
                    onTap: () => widget.onInvestigate(provider),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}

class _DocumentReviewSheet extends StatelessWidget {
  const _DocumentReviewSheet({required this.document});

  final _DocumentSubmission document;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Review submission',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${document.provider} · ${document.type}',
              style: const TextStyle(color: AppTheme.gray),
            ),
            const SizedBox(height: 18),
            Container(
              height: 230,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppTheme.navy,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.description_rounded,
                    color: AppTheme.white,
                    size: 54,
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Secure document preview',
                    style: TextStyle(
                      color: AppTheme.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'The protected file viewer will render here.',
                    style: TextStyle(color: AppTheme.gray),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _AdminCard(
              title: 'Review checklist',
              child: const Column(
                children: [
                  _ChecklistRow(text: 'Provider name matches the document'),
                  _ChecklistRow(text: 'Document is readable and complete'),
                  _ChecklistRow(text: 'Registration or licence is valid'),
                  _ChecklistRow(text: 'No signs of editing or impersonation'),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        Navigator.pop(context, _DocumentStatus.rejected),
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () =>
                        Navigator.pop(context, _DocumentStatus.approved),
                    icon: const Icon(Icons.verified_rounded),
                    label: const Text('Approve'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProviderInvestigationSheet extends StatelessWidget {
  const _ProviderInvestigationSheet({
    required this.provider,
    required this.isBanned,
  });

  final Map<String, dynamic> provider;
  final bool isBanned;

  @override
  Widget build(BuildContext context) {
    final areas = providerCoverageAreas(provider);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              providerName(provider),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _StatusPill(
                  text: humanizeBackendValue(providerPlanTier(provider)),
                  color: AppTheme.amber,
                ),
                _StatusPill(
                  text: isVerifiedProvider(provider)
                      ? 'Documents verified'
                      : 'Not verified',
                  color: isVerifiedProvider(provider)
                      ? AppTheme.green
                      : AppTheme.gray,
                ),
                if (isBanned)
                  const _StatusPill(text: 'Banned', color: Colors.red),
              ],
            ),
            const SizedBox(height: 18),
            _AdminCard(
              title: 'Account snapshot',
              child: Column(
                children: [
                  _KeyValue(
                    label: 'Coverage',
                    value: areas.isEmpty ? 'No areas' : areas.join(', '),
                  ),
                  const Divider(height: 22),
                  _KeyValue(
                    label: 'Packages',
                    value: '${providerPackages(provider).length}',
                  ),
                  const Divider(height: 22),
                  _KeyValue(
                    label: 'Customer rating',
                    value:
                        '${provider['rating'] ?? 0} (${provider['reviews'] ?? 0} reviews)',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const _AdminCard(
              title: 'Reports & evidence',
              child: Column(
                children: [
                  _ReportRow(
                    title: 'Misleading coverage claim',
                    status: 'Needs investigation',
                  ),
                  Divider(height: 22),
                  _ReportRow(
                    title: 'Slow response after payment',
                    status: 'Provider response requested',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const _AdminCard(
              title: 'Investigation controls',
              child: Text(
                'Before banning or deleting, compare reports, request evidence from both sides, write an internal finding and record the justification.',
                style: TextStyle(height: 1.4),
              ),
            ),
            const SizedBox(height: 18),
            if (isBanned)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () =>
                      Navigator.pop(context, _ProviderAction.restore),
                  icon: const Icon(Icons.restore_rounded),
                  label: const Text('Restore provider'),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          Navigator.pop(context, _ProviderAction.ban),
                      icon: const Icon(Icons.block_rounded),
                      label: const Text('Ban provider'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      onPressed: () =>
                          Navigator.pop(context, _ProviderAction.delete),
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: const Text('Delete'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 190,
      child: _AdminCard(
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(label, style: const TextStyle(color: AppTheme.gray)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DocumentCard extends StatelessWidget {
  const _DocumentCard({required this.document, required this.onTap});

  final _DocumentSubmission document;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = switch (document.status) {
      _DocumentStatus.pending => const Color(0xFFD97706),
      _DocumentStatus.approved => AppTheme.green,
      _DocumentStatus.rejected => Colors.red,
    };
    return _AdminCard(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.description_outlined, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    document.provider,
                    softWrap: true,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 3),
                  Text('${document.type} · ${document.fileName}'),
                  const SizedBox(height: 7),
                  _StatusPill(
                    text: _documentStatusLabel(document.status),
                    color: color,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({required this.user});

  final _AdminUser user;

  @override
  Widget build(BuildContext context) {
    return _AdminCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: AppTheme.amber.withValues(alpha: .13),
            child: Text(
              user.name.substring(0, 1),
              style: const TextStyle(
                color: AppTheme.amber,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  softWrap: true,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 2),
                Text(user.email, softWrap: true),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    _StatusPill(text: user.role, color: AppTheme.amber),
                    _StatusPill(
                      text: user.status,
                      color: user.status == 'Active'
                          ? AppTheme.green
                          : const Color(0xFFD97706),
                    ),
                    _StatusPill(text: user.joined, color: AppTheme.gray),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProviderAdminCard extends StatelessWidget {
  const _ProviderAdminCard({
    required this.provider,
    required this.banned,
    required this.onTap,
  });

  final Map<String, dynamic> provider;
  final bool banned;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _AdminCard(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: banned
                  ? Colors.red.withValues(alpha: .12)
                  : AppTheme.amber.withValues(alpha: .12),
              child: Icon(
                banned ? Icons.block_rounded : Icons.cell_tower_rounded,
                color: banned ? Colors.red : AppTheme.amber,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    providerName(provider),
                    softWrap: true,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    providerCoverageAreas(provider).isEmpty
                        ? 'No coverage areas'
                        : providerCoverageAreas(provider).join(', '),
                    softWrap: true,
                  ),
                  const SizedBox(height: 7),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      _StatusPill(
                        text: humanizeBackendValue(providerPlanTier(provider)),
                        color: AppTheme.amber,
                      ),
                      _StatusPill(
                        text: isVerifiedProvider(provider)
                            ? 'Verified'
                            : 'Not verified',
                        color: isVerifiedProvider(provider)
                            ? AppTheme.green
                            : AppTheme.gray,
                      ),
                      if (banned)
                        const _StatusPill(text: 'Banned', color: Colors.red),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.manage_accounts_outlined),
          ],
        ),
      ),
    );
  }
}

class _AdminCard extends StatelessWidget {
  const _AdminCard({required this.child, this.title, this.action});

  final Widget child;
  final String? title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: dark ? AppTheme.navyMid : AppTheme.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: dark ? AppTheme.navyLight : AppTheme.lightGray,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    title!,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                ?action,
              ],
            ),
            const SizedBox(height: 12),
          ],
          child,
        ],
      ),
    );
  }
}

class _PageIntro extends StatelessWidget {
  const _PageIntro({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          subtitle,
          style: const TextStyle(color: AppTheme.gray, height: 1.4),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      selected: selected,
      label: Text(label),
      onSelected: (_) => onTap(),
      selectedColor: AppTheme.amber,
      labelStyle: TextStyle(
        color: selected ? AppTheme.navy : null,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .11),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _SafetyRow extends StatelessWidget {
  const _SafetyRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 3),
              Text(subtitle),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline_rounded, color: AppTheme.green),
          const SizedBox(width: 9),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _KeyValue extends StatelessWidget {
  const _KeyValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 115,
          child: Text(label, style: const TextStyle(color: AppTheme.gray)),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            softWrap: true,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

class _ReportRow extends StatelessWidget {
  const _ReportRow({required this.title, required this.status});

  final String title;
  final String status;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.report_outlined, color: Colors.red),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 3),
              Text(status),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyAdminState extends StatelessWidget {
  const _EmptyAdminState({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(30),
      child: Center(
        child: Column(
          children: [
            Icon(icon, size: 44, color: AppTheme.amber),
            const SizedBox(height: 10),
            Text(text, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

enum _DocumentStatus { pending, approved, rejected }

enum _ProviderAction { ban, restore, delete }

class _DocumentSubmission {
  _DocumentSubmission({
    required this.id,
    required this.provider,
    required this.type,
    required this.submitted,
    required this.fileName,
  });

  final String id;
  final String provider;
  final String type;
  final DateTime submitted;
  final String fileName;
  _DocumentStatus status = _DocumentStatus.pending;
}

class _AdminUser {
  const _AdminUser({
    required this.name,
    required this.email,
    required this.role,
    required this.status,
    required this.joined,
  });

  final String name;
  final String email;
  final String role;
  final String status;
  final String joined;
}

String _viewTitle(_AdminView view) {
  return switch (view) {
    _AdminView.overview => 'Admin overview',
    _AdminView.documents => 'Document review',
    _AdminView.users => 'User directory',
    _AdminView.providers => 'Provider management',
  };
}

String _documentStatusLabel(_DocumentStatus status) {
  return switch (status) {
    _DocumentStatus.pending => 'Pending',
    _DocumentStatus.approved => 'Approved',
    _DocumentStatus.rejected => 'Rejected',
  };
}

String _shortDate(DateTime value) {
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
  return '${value.day} ${months[value.month - 1]} ${value.year}';
}
