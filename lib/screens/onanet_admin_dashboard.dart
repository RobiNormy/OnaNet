import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ona_net/auth/auth_service.dart';
import 'package:ona_net/screens/login.dart';
import 'package:ona_net/themes/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

enum _AdminSection { dashboard, documents, users, providers }

class OnaNetAdminDashboard extends StatefulWidget {
  const OnaNetAdminDashboard({super.key});

  @override
  State<OnaNetAdminDashboard> createState() => _OnaNetAdminDashboardState();
}

class _OnaNetAdminDashboardState extends State<OnaNetAdminDashboard> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _searchController = TextEditingController();
  final _auth = AuthService();
  _AdminSection _section = _AdminSection.dashboard;
  Map<String, dynamic>? _snapshot;
  Map<String, dynamic>? _selected;
  bool _loading = true;
  bool _signingOut = false;
  String? _error;
  String _statusFilter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _users => _mapList(_snapshot?['users']);
  List<Map<String, dynamic>> get _providers =>
      _mapList(_snapshot?['providers']);
  List<Map<String, dynamic>> get _documents =>
      _mapList(_snapshot?['documents']);
  Map<String, dynamic> get _admin => _map(_snapshot?['admin']);

  Future<void> _load({bool keepSelection = false}) async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final data = await _auth.getAdminSnapshot();
      if (!mounted) return;
      setState(() {
        _snapshot = data;
        _loading = false;
        if (!keepSelection) _selected = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  void _selectSection(_AdminSection value) {
    setState(() {
      _section = value;
      _selected = null;
      _statusFilter = 'all';
      _searchController.clear();
    });
    if (MediaQuery.sizeOf(context).width < 840) Navigator.maybePop(context);
  }

  Future<void> _signOut() async {
    if (_signingOut) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Theme(
        data: AppTheme.dark(),
        child: AlertDialog(
          title: const Text('Sign out of OnaNet Admin?'),
          content: const Text(
            'You will need to sign in again to access the OnaNet admin console.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Sign out'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _signingOut = true);
    try {
      await _auth.signOut();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const Login()),
        (_) => false,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _signingOut = false);
      _message('Could not sign out: $error', error: true);
    }
  }

  void _message(String value, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(value),
        backgroundColor: error ? Colors.red.shade700 : AppTheme.navy,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _reviewDocument(String status) async {
    final document = _selected;
    final id = document?['id']?.toString();
    if (id == null) return;
    try {
      await _auth.reviewAdminDocument(id, status: status);
      _message(
        status == 'approved' ? 'Document approved.' : 'Document rejected.',
      );
      await _load();
    } catch (error) {
      _message('Could not update document: $error', error: true);
    }
  }

  Future<void> _moderateProvider() async {
    final provider = _selected;
    final id = provider?['id']?.toString();
    if (id == null) return;
    final suspended = provider?['status']?.toString() == 'suspended';
    String reason = '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Theme(
        data: AppTheme.dark(),
        child: AlertDialog(
          title: Text(suspended ? 'Restore provider?' : 'Suspend provider?'),
          content: suspended
              ? Text(
                  '${_display(provider?['provider_name'])} will return to the public provider directory.',
                )
              : TextField(
                  minLines: 3,
                  maxLines: 5,
                  onChanged: (value) => reason = value.trim(),
                  decoration: const InputDecoration(
                    labelText: 'Investigation reason',
                    hintText: 'Record why this provider is being suspended',
                  ),
                ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: suspended
                  ? null
                  : FilledButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                    ),
              onPressed: () {
                if (!suspended && reason.isEmpty) return;
                Navigator.pop(dialogContext, true);
              },
              child: Text(suspended ? 'Restore' : 'Suspend'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    try {
      await _auth.moderateAdminProvider(
        id,
        status: suspended ? 'approved' : 'suspended',
        reason: suspended ? null : reason,
      );
      _message(suspended ? 'Provider restored.' : 'Provider suspended.');
      await _load();
    } catch (error) {
      _message('Could not update provider: $error', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final desktop = MediaQuery.sizeOf(context).width >= 840;
    return Theme(
      data: AppTheme.dark(),
      child: Builder(
        builder: (darkContext) => Scaffold(
          key: _scaffoldKey,
          backgroundColor: _adminBackground(darkContext),
          drawer: desktop
              ? null
              : Drawer(
                  backgroundColor: AppTheme.navy,
                  child: SafeArea(child: _SidebarBody(owner: this)),
                ),
          body: SafeArea(
            child: Row(
              children: [
                if (desktop)
                  SizedBox(width: 224, child: _SidebarBody(owner: this)),
                Expanded(
                  child: Column(
                    children: [
                      _TopBar(
                        admin: _admin,
                        showMenu: !desktop,
                        onMenu: () => _scaffoldKey.currentState?.openDrawer(),
                        onRefresh: _load,
                      ),
                      Expanded(child: _buildBody(desktop)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(bool desktop) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _LoadError(message: _error!, onRetry: _load);
    }
    final page = _AdminPage(
      section: _section,
      users: _users,
      providers: _providers,
      documents: _documents,
      selected: _selected,
      searchController: _searchController,
      statusFilter: _statusFilter,
      onSearch: (_) => setState(() {}),
      onFilter: (value) => setState(() => _statusFilter = value),
      onSelected: (item) => setState(() => _selected = item),
      onReviewDocument: _reviewDocument,
      onModerateProvider: _moderateProvider,
    );
    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(desktop ? 24 : 14),
        child: page,
      ),
    );
  }
}

class _SidebarBody extends StatelessWidget {
  const _SidebarBody({required this.owner});

  final _OnaNetAdminDashboardState owner;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.navy,
      padding: const EdgeInsets.fromLTRB(14, 20, 14, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppTheme.amber.withValues(alpha: .16),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.wifi_rounded,
                    color: AppTheme.amber,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'OnaNet Admin',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          for (final item in const [
            (_AdminSection.dashboard, 'Dashboard', Icons.dashboard_outlined),
            (_AdminSection.documents, 'Documents', Icons.description_outlined),
            (_AdminSection.users, 'Users', Icons.people_outline_rounded),
            (_AdminSection.providers, 'Providers', Icons.cell_tower_outlined),
          ])
            _SideNavItem(
              label: item.$2,
              icon: item.$3,
              selected: owner._section == item.$1,
              onTap: () => owner._selectSection(item.$1),
            ),
          const Spacer(),
          const Divider(color: Color(0xFF243747)),
          _SideNavItem(
            label: owner._signingOut ? 'Signing out' : 'Sign out',
            icon: Icons.logout_rounded,
            selected: false,
            onTap: owner._signingOut ? null : owner._signOut,
          ),
        ],
      ),
    );
  }
}

class _SideNavItem extends StatelessWidget {
  const _SideNavItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: selected
            ? AppTheme.amber.withValues(alpha: .18)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(9),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: selected ? AppTheme.amber : const Color(0xFFB6C1CA),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    softWrap: true,
                    style: TextStyle(
                      color: selected
                          ? AppTheme.amber
                          : const Color(0xFFB6C1CA),
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.admin,
    required this.showMenu,
    required this.onMenu,
    required this.onRefresh,
  });

  final Map<String, dynamic> admin;
  final bool showMenu;
  final VoidCallback onMenu;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final name = _display(admin['name'], fallback: 'OnaNet Admin');
    final email = _display(admin['email']);
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: _adminBackground(context),
        border: Border(bottom: BorderSide(color: _adminBorder(context))),
      ),
      child: Row(
        children: [
          if (showMenu) ...[
            IconButton(onPressed: onMenu, icon: const Icon(Icons.menu_rounded)),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppTheme.amber.withValues(alpha: .14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.wifi_rounded,
                    color: AppTheme.amber,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'OnaNet Admin',
                    softWrap: true,
                    style: TextStyle(
                      color: _adminText(context),
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Refresh real data',
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 6),
          CircleAvatar(
            radius: 18,
            backgroundColor: AppTheme.amber.withValues(alpha: .16),
            child: Text(
              _initial(name),
              style: const TextStyle(
                color: AppTheme.amberDark,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 9),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  softWrap: true,
                  style: TextStyle(
                    color: _adminText(context),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  email,
                  softWrap: true,
                  style: TextStyle(
                    color: _adminMutedText(context),
                    fontSize: 9,
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

class _AdminPage extends StatelessWidget {
  const _AdminPage({
    required this.section,
    required this.users,
    required this.providers,
    required this.documents,
    required this.selected,
    required this.searchController,
    required this.statusFilter,
    required this.onSearch,
    required this.onFilter,
    required this.onSelected,
    required this.onReviewDocument,
    required this.onModerateProvider,
  });

  final _AdminSection section;
  final List<Map<String, dynamic>> users;
  final List<Map<String, dynamic>> providers;
  final List<Map<String, dynamic>> documents;
  final Map<String, dynamic>? selected;
  final TextEditingController searchController;
  final String statusFilter;
  final ValueChanged<String> onSearch;
  final ValueChanged<String> onFilter;
  final ValueChanged<Map<String, dynamic>> onSelected;
  final ValueChanged<String> onReviewDocument;
  final VoidCallback onModerateProvider;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final showPanel = selected != null && width >= 1120;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _sectionTitle(section),
          style: GoogleFonts.plusJakartaSans(
            color: _adminText(context),
            fontSize: width < 500 ? 24 : 29,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 18),
        if (section == _AdminSection.dashboard)
          _DashboardContent(
            users: users,
            providers: providers,
            documents: documents,
            onSelected: onSelected,
          )
        else
          _DirectoryContent(
            section: section,
            users: users,
            providers: providers,
            documents: documents,
            searchController: searchController,
            statusFilter: statusFilter,
            onSearch: onSearch,
            onFilter: onFilter,
            onSelected: (item) {
              onSelected(item);
              if (width < 1120) {
                showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => _MobileDetailSheet(
                    child: _DetailPanel(
                      section: section,
                      item: item,
                      onReviewDocument: onReviewDocument,
                      onModerateProvider: onModerateProvider,
                    ),
                  ),
                );
              }
            },
          ),
      ],
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: content),
        if (showPanel) ...[
          const SizedBox(width: 16),
          SizedBox(
            width: 292,
            child: _DetailPanel(
              section: section,
              item: selected!,
              onReviewDocument: onReviewDocument,
              onModerateProvider: onModerateProvider,
            ),
          ),
        ],
      ],
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({
    required this.users,
    required this.providers,
    required this.documents,
    required this.onSelected,
  });

  final List<Map<String, dynamic>> users;
  final List<Map<String, dynamic>> providers;
  final List<Map<String, dynamic>> documents;
  final ValueChanged<Map<String, dynamic>> onSelected;

  @override
  Widget build(BuildContext context) {
    final pending = documents
        .where((item) => item['status']?.toString() == 'pending')
        .length;
    final verified = providers
        .where((item) => item['is_verified'] == true)
        .length;
    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = constraints.maxWidth >= 760
                ? (constraints.maxWidth - 36) / 4
                : constraints.maxWidth >= 480
                ? (constraints.maxWidth - 12) / 2
                : constraints.maxWidth;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _Metric(
                  width: cardWidth,
                  label: 'All users',
                  value: '${users.length}',
                  icon: Icons.people_outline_rounded,
                ),
                _Metric(
                  width: cardWidth,
                  label: 'Providers',
                  value: '${providers.length}',
                  icon: Icons.cell_tower_outlined,
                ),
                _Metric(
                  width: cardWidth,
                  label: 'Pending documents',
                  value: '$pending',
                  icon: Icons.pending_actions_outlined,
                ),
                _Metric(
                  width: cardWidth,
                  label: 'Verified providers',
                  value: '$verified',
                  icon: Icons.verified_outlined,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        _Panel(
          title: 'Latest document submissions',
          child: documents.isEmpty
              ? const _EmptyRow(message: 'No documents have been submitted.')
              : Column(
                  children: documents
                      .take(7)
                      .map(
                        (item) => _CompactRow(
                          leading: _Avatar(
                            name: _display(item['provider_name']),
                            imageUrl: item['logo_url']?.toString(),
                          ),
                          title: _display(item['provider_name']),
                          subtitle:
                              '${_humanize(item['document_type'])} · ${_date(item['created_at'])}',
                          status: _display(item['status']),
                          onTap: () => onSelected(item),
                        ),
                      )
                      .toList(),
                ),
        ),
      ],
    );
  }
}

class _DirectoryContent extends StatelessWidget {
  const _DirectoryContent({
    required this.section,
    required this.users,
    required this.providers,
    required this.documents,
    required this.searchController,
    required this.statusFilter,
    required this.onSearch,
    required this.onFilter,
    required this.onSelected,
  });

  final _AdminSection section;
  final List<Map<String, dynamic>> users;
  final List<Map<String, dynamic>> providers;
  final List<Map<String, dynamic>> documents;
  final TextEditingController searchController;
  final String statusFilter;
  final ValueChanged<String> onSearch;
  final ValueChanged<String> onFilter;
  final ValueChanged<Map<String, dynamic>> onSelected;

  List<Map<String, dynamic>> get _source => switch (section) {
    _AdminSection.documents => documents,
    _AdminSection.users => users,
    _AdminSection.providers => providers,
    _AdminSection.dashboard => const [],
  };

  @override
  Widget build(BuildContext context) {
    final query = searchController.text.trim().toLowerCase();
    final rows = _source.where((item) {
      final haystack = item.values.join(' ').toLowerCase();
      final status = _rowStatus(section, item).toLowerCase();
      return haystack.contains(query) &&
          (statusFilter == 'all' || status == statusFilter);
    }).toList();
    final filters = <String>{
      'all',
      ..._source.map((item) => _rowStatus(section, item).toLowerCase()),
    }.where((item) => item.isNotEmpty).toList();

    return _Panel(
      child: Column(
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.spaceBetween,
            children: [
              SizedBox(
                width: 270,
                child: TextField(
                  controller: searchController,
                  onChanged: onSearch,
                  decoration: InputDecoration(
                    hintText: 'Search real OnaNet records',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    isDense: true,
                    filled: true,
                    fillColor: _adminSurface(context),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(9),
                      borderSide: BorderSide(color: _adminBorder(context)),
                    ),
                  ),
                ),
              ),
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: filters.contains(statusFilter) ? statusFilter : 'all',
                  borderRadius: BorderRadius.circular(10),
                  items: filters
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(
                            value == 'all' ? 'Any status' : _humanize(value),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) onFilter(value);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (rows.isEmpty)
            const _EmptyRow(message: 'No OnaNet records match this view.')
          else
            _ResponsiveAdminTable(
              section: section,
              rows: rows,
              onSelected: onSelected,
            ),
        ],
      ),
    );
  }
}

class _ResponsiveAdminTable extends StatelessWidget {
  const _ResponsiveAdminTable({
    required this.section,
    required this.rows,
    required this.onSelected,
  });

  final _AdminSection section;
  final List<Map<String, dynamic>> rows;
  final ValueChanged<Map<String, dynamic>> onSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 650) {
          return Column(
            children: rows
                .map(
                  (item) => _CompactRow(
                    leading: _Avatar(
                      name: _primaryText(section, item),
                      imageUrl: _imageUrl(section, item),
                    ),
                    title: _primaryText(section, item),
                    subtitle: _secondaryText(section, item),
                    status: _rowStatus(section, item),
                    onTap: () => onSelected(item),
                  ),
                )
                .toList(),
          );
        }
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: DataTable(
              headingRowHeight: 42,
              dataRowMinHeight: 57,
              dataRowMaxHeight: 72,
              horizontalMargin: 8,
              columnSpacing: 28,
              headingTextStyle: TextStyle(
                color: _adminMutedText(context),
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
              columns: _columns(
                section,
              ).map((label) => DataColumn(label: Text(label))).toList(),
              rows: rows
                  .map(
                    (item) => DataRow(
                      onSelectChanged: (_) => onSelected(item),
                      cells: _cells(section, item),
                    ),
                  )
                  .toList(),
            ),
          ),
        );
      },
    );
  }
}

class _DetailPanel extends StatelessWidget {
  const _DetailPanel({
    required this.section,
    required this.item,
    required this.onReviewDocument,
    required this.onModerateProvider,
  });

  final _AdminSection section;
  final Map<String, dynamic> item;
  final ValueChanged<String> onReviewDocument;
  final VoidCallback onModerateProvider;

  @override
  Widget build(BuildContext context) {
    final title = _primaryText(section, item);
    return Container(
      decoration: BoxDecoration(
        color: _adminSurface(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _adminBorder(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: Theme.of(context).brightness == Brightness.dark
                  ? .18
                  : .05,
            ),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                _Avatar(
                  name: title,
                  imageUrl: _imageUrl(section, item),
                  radius: 34,
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  softWrap: true,
                  style: TextStyle(
                    color: _adminText(context),
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _secondaryText(section, item),
                  textAlign: TextAlign.center,
                  softWrap: true,
                  style: TextStyle(
                    color: _adminMutedText(context),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 9),
                _StatusBadge(value: _rowStatus(section, item)),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: _detailRows(section, item)
                  .map(
                    (row) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _DetailRow(label: row.$1, value: row.$2),
                    ),
                  )
                  .toList(),
            ),
          ),
          if (section == _AdminSection.documents) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _openDocument(context, item['file_url']),
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: const Text('Open submitted file'),
                  ),
                  if (item['status']?.toString() == 'pending') ...[
                    const SizedBox(height: 9),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton(
                            onPressed: () => onReviewDocument('approved'),
                            child: const Text('Approve'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => onReviewDocument('rejected'),
                            child: const Text('Reject'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
          if (section == _AdminSection.providers) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton.icon(
                style: item['status']?.toString() == 'suspended'
                    ? null
                    : FilledButton.styleFrom(
                        backgroundColor: Colors.red.shade700,
                      ),
                onPressed: onModerateProvider,
                icon: Icon(
                  item['status']?.toString() == 'suspended'
                      ? Icons.restore_rounded
                      : Icons.block_rounded,
                ),
                label: Text(
                  item['status']?.toString() == 'suspended'
                      ? 'Restore provider'
                      : 'Suspend provider',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openDocument(BuildContext context, dynamic rawUrl) async {
    final url = Uri.tryParse(rawUrl?.toString() ?? '');
    if (url == null ||
        !await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the submitted file.')),
      );
    }
  }
}

class _MobileDetailSheet extends StatelessWidget {
  const _MobileDetailSheet({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: .82,
      minChildSize: .5,
      maxChildSize: .94,
      builder: (context, controller) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _adminBackground(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: ListView(controller: controller, children: [child]),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.title});

  final Widget child;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _adminSurface(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _adminBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Text(
              title!,
              softWrap: true,
              style: TextStyle(
                color: _adminText(context),
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
          ],
          child,
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.width,
    required this.label,
    required this.value,
    required this.icon,
  });

  final double width;
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: _Panel(
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppTheme.amber.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppTheme.amberDark),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      color: _adminText(context),
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    label,
                    softWrap: true,
                    style: TextStyle(
                      color: _adminMutedText(context),
                      fontSize: 11,
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
}

class _CompactRow extends StatelessWidget {
  const _CompactRow({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.onTap,
  });

  final Widget leading;
  final String title;
  final String subtitle;
  final String status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            leading,
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    softWrap: true,
                    style: TextStyle(
                      color: _adminText(context),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    softWrap: true,
                    style: TextStyle(
                      color: _adminMutedText(context),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _StatusBadge(value: status),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, this.imageUrl, this.radius = 18});

  final String name;
  final String? imageUrl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.trim().isNotEmpty;
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppTheme.amber.withValues(alpha: .14),
      backgroundImage: hasImage ? NetworkImage(imageUrl!) : null,
      child: hasImage
          ? null
          : Text(
              _initial(name),
              style: TextStyle(
                color: AppTheme.amberDark,
                fontSize: radius * .75,
                fontWeight: FontWeight.w900,
              ),
            ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(value);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        _humanize(value),
        softWrap: true,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 88,
          child: Text(
            label,
            style: TextStyle(color: _adminMutedText(context), fontSize: 11),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            softWrap: true,
            style: TextStyle(
              color: _adminText(context),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyRow extends StatelessWidget {
  const _EmptyRow({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 42),
      child: Column(
        children: [
          const Icon(Icons.inbox_outlined, color: AppTheme.amber, size: 38),
          const SizedBox(height: 9),
          Text(message, textAlign: TextAlign.center, softWrap: true),
        ],
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, color: Colors.red, size: 42),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, softWrap: true),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

List<String> _columns(_AdminSection section) => switch (section) {
  _AdminSection.documents => const [
    'Provider',
    'Document',
    'Status',
    'Submitted',
  ],
  _AdminSection.users => const ['User', 'Role', 'Phone', 'Joined'],
  _AdminSection.providers => const [
    'Provider',
    'Plan',
    'Status',
    'Coverage',
    'Customers',
  ],
  _AdminSection.dashboard => const [],
};

List<DataCell> _cells(_AdminSection section, Map<String, dynamic> item) =>
    switch (section) {
      _AdminSection.documents => [
        _identityCell(
          _display(item['provider_name']),
          _display(item['owner_email']),
          item['logo_url']?.toString(),
        ),
        DataCell(Text(_humanize(item['document_type']), softWrap: true)),
        DataCell(_StatusBadge(value: _display(item['status']))),
        DataCell(Text(_date(item['created_at']))),
      ],
      _AdminSection.users => [
        _identityCell(
          _userName(item),
          _display(item['email']),
          item['profile_image_url']?.toString(),
        ),
        DataCell(_StatusBadge(value: _display(item['role']))),
        DataCell(Text(_display(item['phone_number']))),
        DataCell(Text(_date(item['created_at']))),
      ],
      _AdminSection.providers => [
        _identityCell(
          _display(item['provider_name']),
          _display(item['primary_city']),
          item['logo_url']?.toString(),
        ),
        DataCell(_StatusBadge(value: _display(item['subscription_tier']))),
        DataCell(_StatusBadge(value: _display(item['status']))),
        DataCell(Text('${item['coverage_count'] ?? 0} areas')),
        DataCell(Text('${item['customer_count'] ?? 0}')),
      ],
      _AdminSection.dashboard => const [],
    };

DataCell _identityCell(String title, String subtitle, String? imageUrl) {
  return DataCell(
    Row(
      children: [
        _Avatar(name: title, imageUrl: imageUrl),
        const SizedBox(width: 9),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 190),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                softWrap: true,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                subtitle,
                softWrap: true,
                style: const TextStyle(fontSize: 9),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

List<(String, String)> _detailRows(
  _AdminSection section,
  Map<String, dynamic> item,
) => switch (section) {
  _AdminSection.documents => [
    ('Type', _humanize(item['document_type'])),
    ('Owner email', _display(item['owner_email'])),
    ('Submitted', _date(item['created_at'])),
    ('Document ID', _display(item['id'])),
  ],
  _AdminSection.users => [
    ('Email', _display(item['email'])),
    ('Phone', _display(item['phone_number'])),
    ('Role', _humanize(item['role'])),
    ('Joined', _date(item['created_at'])),
    ('Phone verified', item['is_phone_verified'] == true ? 'Yes' : 'No'),
    ('Profile complete', item['is_profile_complete'] == true ? 'Yes' : 'No'),
  ],
  _AdminSection.providers => [
    ('Owner', _display(item['owner_name'])),
    ('Email', _display(item['email'])),
    ('City', _display(item['primary_city'])),
    ('Plan', _humanize(item['subscription_tier'])),
    ('Packages', '${item['package_count'] ?? 0}'),
    ('Coverage', '${item['coverage_count'] ?? 0} areas'),
    ('Customers', '${item['customer_count'] ?? 0}'),
    ('Joined', _date(item['created_at'])),
    ('Verified', item['is_verified'] == true ? 'Yes' : 'No'),
  ],
  _AdminSection.dashboard => const [],
};

String _primaryText(_AdminSection section, Map<String, dynamic> item) {
  return switch (section) {
    _AdminSection.documents => _display(item['provider_name']),
    _AdminSection.users => _userName(item),
    _AdminSection.providers => _display(item['provider_name']),
    _AdminSection.dashboard => '',
  };
}

String _secondaryText(_AdminSection section, Map<String, dynamic> item) {
  return switch (section) {
    _AdminSection.documents =>
      '${_humanize(item['document_type'])} · ${_date(item['created_at'])}',
    _AdminSection.users => _display(item['email']),
    _AdminSection.providers =>
      '${_display(item['primary_city'])} · ${_humanize(item['subscription_tier'])}',
    _AdminSection.dashboard => '',
  };
}

String? _imageUrl(_AdminSection section, Map<String, dynamic> item) {
  return switch (section) {
    _AdminSection.documents ||
    _AdminSection.providers => item['logo_url']?.toString(),
    _AdminSection.users => item['profile_image_url']?.toString(),
    _AdminSection.dashboard => null,
  };
}

String _rowStatus(_AdminSection section, Map<String, dynamic> item) {
  return switch (section) {
    _AdminSection.documents ||
    _AdminSection.providers => _display(item['status']),
    _AdminSection.users => _display(item['role']),
    _AdminSection.dashboard => '',
  };
}

String _sectionTitle(_AdminSection value) => switch (value) {
  _AdminSection.dashboard => 'Dashboard',
  _AdminSection.documents => 'Document review',
  _AdminSection.users => 'All users',
  _AdminSection.providers => 'Provider management',
};

String _userName(Map<String, dynamic> item) {
  final value = [
    item['first_name'],
    item['last_name'],
  ].where((part) => part?.toString().trim().isNotEmpty == true).join(' ');
  return value.isEmpty ? _display(item['email']) : value;
}

Color _statusColor(String value) {
  switch (value.toLowerCase()) {
    case 'approved':
    case 'active':
    case 'verified':
    case 'pro':
      return const Color(0xFF16864B);
    case 'pending':
    case 'pending review':
    case 'pending_review':
    case 'growth':
      return const Color(0xFFC08200);
    case 'rejected':
    case 'suspended':
      return const Color(0xFFC13A3A);
    default:
      return AppTheme.amberDark;
  }
}

String _humanize(dynamic value) {
  final raw = _display(value);
  if (raw == 'Not provided') return raw;
  final spaced = raw.replaceAll('_', ' ');
  return spaced
      .split(' ')
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}

String _display(dynamic value, {String fallback = 'Not provided'}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

String _initial(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? 'O' : trimmed.substring(0, 1).toUpperCase();
}

String _date(dynamic raw) {
  final value = DateTime.tryParse(raw?.toString() ?? '')?.toLocal();
  if (value == null) return 'Not provided';
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

Map<String, dynamic> _map(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

List<Map<String, dynamic>> _mapList(dynamic value) {
  if (value is! List) return const [];
  return value.whereType<Map>().map(Map<String, dynamic>.from).toList();
}

Color _adminBackground(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? AppTheme.navy
      : AppTheme.offWhite;
}

Color _adminSurface(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? AppTheme.navyMid
      : AppTheme.white;
}

Color _adminBorder(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? AppTheme.navyLight
      : AppTheme.lightGray;
}

Color _adminText(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? AppTheme.offWhite
      : AppTheme.navy;
}

Color _adminMutedText(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? AppTheme.gray
      : AppTheme.darkGray;
}
