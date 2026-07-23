import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ona_net/auth/auth_service.dart';
import 'package:ona_net/onanet_provider_dash/blueprint_components.dart';
import 'package:ona_net/themes/app_theme.dart';

const _sections = <(String, String, IconData)>[
  ('dashboard', 'Dashboard', Icons.dashboard_outlined),
  ('packages', 'Packages', Icons.router_outlined),
  ('coverage', 'Coverage areas', Icons.map_outlined),
  ('documents', 'Documents', Icons.verified_user_outlined),
  ('installation_requests', 'Installation requests', Icons.add_task_rounded),
  ('customers', 'Customers', Icons.people_outline_rounded),
  ('reviews', 'Reviews', Icons.star_border_rounded),
  ('messages', 'Messages', Icons.mail_outline_rounded),
  ('analytics', 'Analytics', Icons.auto_graph_rounded),
];

class ProviderTeamAccountsPage extends StatefulWidget {
  const ProviderTeamAccountsPage({
    super.key,
    required this.providerName,
    required this.onBackPressed,
    required this.showMenuButton,
    required this.onMenuPressed,
  });

  final String providerName;
  final VoidCallback onBackPressed;
  final bool showMenuButton;
  final VoidCallback onMenuPressed;

  @override
  State<ProviderTeamAccountsPage> createState() =>
      _ProviderTeamAccountsPageState();
}

class _ProviderTeamAccountsPageState extends State<ProviderTeamAccountsPage> {
  final _service = AuthService();
  late Future<Map<String, dynamic>> _accounts = _load();
  bool _saving = false;

  Future<Map<String, dynamic>> _load() => _service.getProviderStaffAccounts();

  void _reload() {
    if (!mounted) return;
    setState(() => _accounts = _load());
  }

  Future<void> _addAccount() async {
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) =>
          _StaffAccountDialog(providerName: widget.providerName),
    );
    if (payload == null || !mounted) return;
    setState(() => _saving = true);
    try {
      await _service.createProviderStaffAccount(payload);
      if (!mounted) return;
      _reload();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Provider staff account created.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(error.toString()),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _manageAccount(Map<String, dynamic> account) async {
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _StaffAccountDialog(
        providerName: widget.providerName,
        account: account,
      ),
    );
    if (payload == null || !mounted) return;
    setState(() => _saving = true);
    try {
      await _service.updateProviderStaffAccount(
        account['id'].toString(),
        payload,
      );
      if (!mounted) return;
      _reload();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Staff permissions updated.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(error.toString()),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _setActive(Map<String, dynamic> account, bool active) async {
    try {
      await _service.updateProviderStaffAccount(account['id'].toString(), {
        'is_active': active,
      });
      if (mounted) _reload();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.onSurface;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showMenuButton)
          OnaBlueprintHeader(
            title: 'Team accounts',
            onBack: widget.onBackPressed,
            onMenu: widget.onMenuPressed,
          )
        else
          Row(
            children: [
              IconButton(
                onPressed: widget.onBackPressed,
                tooltip: 'Back to dashboard',
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Team accounts',
                  softWrap: true,
                  style: GoogleFonts.plusJakartaSans(
                    color: textColor,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        const SizedBox(height: 14),
        FutureBuilder<Map<String, dynamic>>(
          future: _accounts,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(36),
                  child: CircularProgressIndicator(),
                ),
              );
            }
            if (snapshot.hasError) {
              return OnaBlueprintCard(
                child: Column(
                  children: [
                    Text(
                      snapshot.error.toString(),
                      textAlign: TextAlign.center,
                      softWrap: true,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _reload,
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              );
            }

            final data = snapshot.data ?? const <String, dynamic>{};
            final tier = data['tier']?.toString() ?? 'free';
            final limit = _asInt(data['account_limit'], 1);
            final used = _asInt(data['accounts_used'], 1);
            final staff = _mapList(data['staff']);
            final canAdd = used < limit;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OnaBlueprintCard(
                  title: '${_title(tier)} plan accounts',
                  action: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.amber.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      limit >= 999
                          ? '$used used · Unlimited'
                          : '$used of $limit',
                      style: const TextStyle(
                        color: AppTheme.amberDark,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'The owner counts as one account. Each team member signs in with their own email and password.',
                        softWrap: true,
                        style: TextStyle(
                          color: muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        onPressed: canAdd && !_saving ? _addAccount : null,
                        icon: const Icon(Icons.person_add_alt_1_rounded),
                        label: Text(
                          canAdd ? 'Add team account' : 'Account limit reached',
                        ),
                      ),
                      if (!canAdd && tier == 'free') ...[
                        const SizedBox(height: 8),
                        Text(
                          'Upgrade to Growth or Pro to add team accounts.',
                          textAlign: TextAlign.center,
                          softWrap: true,
                          style: TextStyle(
                            color: muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (staff.isEmpty)
                  OnaBlueprintCard(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      child: Column(
                        children: [
                          Icon(
                            Icons.group_add_outlined,
                            color: muted,
                            size: 34,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'No team accounts yet',
                            style: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  for (final account in staff) ...[
                    _StaffAccountCard(
                      account: account,
                      onManage: _saving ? null : () => _manageAccount(account),
                      onActiveChanged: _saving
                          ? null
                          : (active) => _setActive(account, active),
                    ),
                    const SizedBox(height: 10),
                  ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _StaffAccountCard extends StatelessWidget {
  const _StaffAccountCard({
    required this.account,
    required this.onManage,
    required this.onActiveChanged,
  });

  final Map<String, dynamic> account;
  final VoidCallback? onManage;
  final ValueChanged<bool>? onActiveChanged;

  @override
  Widget build(BuildContext context) {
    final active = account['is_active'] != false;
    final name = account['display_name']?.toString().trim();
    final displayName = name == null || name.isEmpty ? 'Team member' : name;
    final permissions = _permissionMap(account['permissions']);
    final visible = permissions.values
        .where((permission) => permission['view'] == true)
        .length;
    final editable = permissions.values
        .where((permission) => permission['edit'] == true)
        .length;
    return OnaBlueprintCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: AppTheme.amber.withValues(alpha: .13),
            foregroundColor: AppTheme.amberDark,
            child: Text(
              displayName.substring(0, 1).toUpperCase(),
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  softWrap: true,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  account['email']?.toString() ?? '',
                  softWrap: true,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _Chip(label: account['role']?.toString() ?? 'Staff'),
                    _Chip(label: '$visible sections visible'),
                    _Chip(label: '$editable editable'),
                  ],
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: onManage,
                  icon: const Icon(Icons.tune_rounded, size: 17),
                  label: const Text('Manage role and permissions'),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch.adaptive(value: active, onChanged: onActiveChanged),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: AppTheme.amber.withValues(alpha: .09),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      label,
      softWrap: true,
      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
    ),
  );
}

class _StaffAccountDialog extends StatefulWidget {
  const _StaffAccountDialog({required this.providerName, this.account});

  final String providerName;
  final Map<String, dynamic>? account;

  @override
  State<_StaffAccountDialog> createState() => _StaffAccountDialogState();
}

class _StaffAccountDialogState extends State<_StaffAccountDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _providerController = TextEditingController(
    text: widget.providerName,
  );
  late final _nameController = TextEditingController(
    text: widget.account?['display_name']?.toString() ?? '',
  );
  late final _emailController = TextEditingController(
    text: widget.account?['email']?.toString() ?? '',
  );
  final _staffPasswordController = TextEditingController();
  final _ownerPasswordController = TextEditingController();
  late final _roleController = TextEditingController(
    text: widget.account?['role']?.toString() ?? 'Manager',
  );
  late final Map<String, Map<String, bool>> _permissions =
      _initialPermissions();

  bool get _editing => widget.account != null;

  Map<String, Map<String, bool>> _initialPermissions() {
    final existing = _permissionMap(widget.account?['permissions']);
    return {
      for (final section in _sections)
        section.$1: {
          'view': existing[section.$1]?['view'] ?? true,
          'edit': existing[section.$1]?['edit'] ?? false,
        },
    };
  }

  @override
  void dispose() {
    _providerController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _staffPasswordController.dispose();
    _ownerPasswordController.dispose();
    _roleController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final permissions = {
      for (final entry in _permissions.entries)
        entry.key: {
          'view': entry.value['view'] == true || entry.value['edit'] == true,
          'edit': entry.value['edit'] == true,
        },
    };
    if (_editing) {
      Navigator.pop(context, {
        'role': _roleController.text.trim(),
        'permissions': permissions,
      });
      return;
    }
    Navigator.pop(context, {
      'provider_name': _providerController.text.trim(),
      'owner_password': _ownerPasswordController.text,
      'email': _emailController.text.trim(),
      'password': _staffPasswordController.text,
      'display_name': _nameController.text.trim(),
      'role': _roleController.text.trim(),
      'permissions': permissions,
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_editing ? 'Manage team account' : 'Add team account'),
      content: SizedBox(
        width: 620,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!_editing) ...[
                  TextFormField(
                    controller: _providerController,
                    decoration: const InputDecoration(
                      labelText: 'Provider name',
                      prefixIcon: Icon(Icons.business_outlined),
                    ),
                    validator: _required,
                  ),
                  const SizedBox(height: 10),
                ],
                TextFormField(
                  controller: _nameController,
                  readOnly: _editing,
                  decoration: const InputDecoration(
                    labelText: 'Team member name',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  validator: _required,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _roleController,
                  decoration: const InputDecoration(
                    labelText: 'Role',
                    hintText: 'Manager, Support, Installer…',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  validator: _required,
                ),
                if (!_editing) ...[
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Team member login email',
                      prefixIcon: Icon(Icons.alternate_email_rounded),
                    ),
                    validator: (value) {
                      if (value == null || !value.contains('@')) {
                        return 'Enter a valid email address.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _staffPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Team member password',
                      helperText:
                          'They use this password with their own email.',
                      prefixIcon: Icon(Icons.key_rounded),
                    ),
                    validator: _password,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _ownerPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Provider owner password',
                      helperText:
                          'Used once to confirm this action. It is not stored.',
                      prefixIcon: Icon(Icons.admin_panel_settings_outlined),
                    ),
                    validator: _password,
                  ),
                ],
                const SizedBox(height: 18),
                const Text(
                  'What can this account access?',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  'View controls whether the section appears. Edit controls whether they can change its data.',
                  softWrap: true,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                for (final section in _sections)
                  _PermissionRow(
                    section: section,
                    permission: _permissions[section.$1]!,
                    onChanged: (next) {
                      setState(() => _permissions[section.$1] = next);
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(_editing ? 'Save permissions' : 'Create account'),
        ),
      ],
    );
  }

  static String? _required(String? value) =>
      value == null || value.trim().length < 2
      ? 'This field is required.'
      : null;

  static String? _password(String? value) =>
      value == null || value.length < 6 ? 'Use at least 6 characters.' : null;
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    required this.section,
    required this.permission,
    required this.onChanged,
  });

  final (String, String, IconData) section;
  final Map<String, bool> permission;
  final ValueChanged<Map<String, bool>> onChanged;

  @override
  Widget build(BuildContext context) {
    final canView = permission['view'] == true;
    final canEdit = permission['edit'] == true;
    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.fromLTRB(10, 7, 6, 7),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outline),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(section.$3, color: AppTheme.amber, size: 19),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              section.$2,
              softWrap: true,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          _PermissionToggle(
            label: 'View',
            value: canView,
            onChanged: (value) =>
                onChanged({'view': value, 'edit': value ? canEdit : false}),
          ),
          _PermissionToggle(
            label: 'Edit',
            value: canEdit,
            onChanged: (value) =>
                onChanged({'view': value ? true : canView, 'edit': value}),
          ),
        ],
      ),
    );
  }
}

class _PermissionToggle extends StatelessWidget {
  const _PermissionToggle({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(label, style: const TextStyle(fontSize: 9)),
      SizedBox(
        height: 28,
        child: Checkbox(value: value, onChanged: (next) => onChanged(next!)),
      ),
    ],
  );
}

List<Map<String, dynamic>> _mapList(Object? value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
}

Map<String, Map<String, bool>> _permissionMap(Object? value) {
  if (value is! Map) return {};
  return {
    for (final entry in value.entries)
      entry.key.toString(): entry.value is Map
          ? {
              'view': (entry.value as Map)['view'] == true,
              'edit': (entry.value as Map)['edit'] == true,
            }
          : {'view': false, 'edit': false},
  };
}

int _asInt(Object? value, int fallback) => value is num
    ? value.toInt()
    : int.tryParse(value?.toString() ?? '') ?? fallback;

String _title(String value) {
  final clean = value.trim().isEmpty ? 'free' : value.trim();
  return '${clean[0].toUpperCase()}${clean.substring(1)}';
}
