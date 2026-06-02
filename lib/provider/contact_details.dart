import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ona_net/provider/provider_flow_widgets.dart';
import 'package:ona_net/provider/provider_registration_data.dart';
import 'package:ona_net/provider/verification.dart';
import 'package:ona_net/themes/app_theme.dart';

class ContactDetailsScreen extends StatefulWidget {
  const ContactDetailsScreen({
    super.key,
    required this.providerKind,
    required this.draft,
  });

  final ProviderKind providerKind;
  final ProviderRegistrationDraft draft;

  @override
  State<ContactDetailsScreen> createState() => _ContactDetailsScreenState();
}

class _ContactDetailsScreenState extends State<ContactDetailsScreen> {
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _websiteController = TextEditingController();
  final _socialUrlController = TextEditingController();

  String _socialPlatform = _socialPlatforms.first;
  late final List<ProviderContactDraft> _contacts = [...widget.draft.contacts];

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    _websiteController.dispose();
    _socialUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.offWhite : AppTheme.navy;
    final borderColor = isDark ? AppTheme.navyLight : AppTheme.lightGray;

    return ProviderFlowShell(
      title: widget.providerKind.registrationTitle,
      icon: widget.providerKind.icon,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const StepProgressHeader(currentStep: 5),
          const SizedBox(height: 28),
          const ProviderSectionTitle(
            title: 'Contacts',
            subtitle:
                'Add the support channels customers can use to reach your team.',
          ),
          const SizedBox(height: 22),
          _ContactInputRow(
            controller: _emailController,
            label: 'Support Email',
            keyboardType: TextInputType.emailAddress,
            onAdd: () => _addContact('email', _emailController),
          ),
          const SizedBox(height: 16),
          _ContactInputRow(
            controller: _phoneController,
            label: 'Support Phone Number',
            keyboardType: TextInputType.phone,
            onAdd: () => _addContact('phone', _phoneController),
          ),
          const SizedBox(height: 16),
          _ContactInputRow(
            controller: _websiteController,
            label: 'Website',
            keyboardType: TextInputType.url,
            onAdd: () => _addContact('website', _websiteController),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _socialPlatform,
            decoration: InputDecoration(
              labelText: 'Social Platform',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            items: _socialPlatforms.map((platform) {
              return DropdownMenuItem<String>(
                value: platform,
                child: Text(platform),
              );
            }).toList(),
            onChanged: (value) {
              setState(() => _socialPlatform = value ?? _socialPlatforms.first);
            },
          ),
          const SizedBox(height: 12),
          _ContactInputRow(
            controller: _socialUrlController,
            label: 'Social Link',
            keyboardType: TextInputType.url,
            onAdd: () => _addContact(
              'social',
              _socialUrlController,
              socialPlatform: _socialPlatform,
            ),
          ),
          if (_contacts.isNotEmpty) ...[
            const SizedBox(height: 22),
            DecoratedBox(
              decoration: BoxDecoration(
                color: isDark ? AppTheme.navyMid : AppTheme.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                children: _contacts.indexed.map((entry) {
                  final index = entry.$1;
                  final contact = entry.$2;
                  return ListTile(
                    dense: true,
                    leading: Icon(
                      _iconForContact(contact.contactType),
                      color: AppTheme.amber,
                    ),
                    title: Text(
                      contact.socialPlatform ?? _labelFor(contact.contactType),
                      style: GoogleFonts.plusJakartaSans(
                        color: textColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    subtitle: Text(
                      contact.contactValue,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.urbanist(
                        color: isDark ? AppTheme.gray : AppTheme.darkGray,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    trailing: IconButton(
                      onPressed: () =>
                          setState(() => _contacts.removeAt(index)),
                      icon: const Icon(Icons.delete_outline_rounded),
                      tooltip: 'Remove contact',
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
          const SizedBox(height: 42),
          ProviderPrimaryButton(
            label: 'Continue',
            onPressed: () {
              final draft = widget.draft.copyWith(contacts: [..._contacts]);

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => VerificationScreen(
                    providerKind: widget.providerKind,
                    draft: draft,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          const SecureFooter(),
        ],
      ),
    );
  }

  void _addContact(
    String contactType,
    TextEditingController controller, {
    String? socialPlatform,
  }) {
    final value = controller.text.trim();
    if (value.isEmpty) return;

    setState(() {
      _contacts.add(
        ProviderContactDraft(
          contactType: contactType,
          contactValue: value,
          socialPlatform: socialPlatform,
        ),
      );
      controller.clear();
    });
  }

  IconData _iconForContact(String type) {
    switch (type) {
      case 'email':
        return Icons.email_outlined;
      case 'phone':
        return Icons.phone_outlined;
      case 'website':
        return Icons.language_rounded;
      case 'social':
        return Icons.alternate_email_rounded;
      default:
        return Icons.support_agent_rounded;
    }
  }

  String _labelFor(String type) {
    switch (type) {
      case 'email':
        return 'Email';
      case 'phone':
        return 'Phone';
      case 'website':
        return 'Website';
      case 'social':
        return 'Social';
      default:
        return 'Contact';
    }
  }
}

class _ContactInputRow extends StatelessWidget {
  const _ContactInputRow({
    required this.controller,
    required this.label,
    required this.keyboardType,
    required this.onAdd,
  });

  final TextEditingController controller;
  final String label;
  final TextInputType keyboardType;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: ProviderTextField(
            controller: controller,
            label: label,
            keyboardType: keyboardType,
            textInputAction: TextInputAction.next,
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          height: 56,
          width: 56,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.amber,
              foregroundColor: AppTheme.white,
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: onAdd,
            child: const Icon(Icons.add_rounded),
          ),
        ),
      ],
    );
  }
}

const _socialPlatforms = [
  'WhatsApp',
  'Facebook',
  'Instagram',
  'X',
  'TikTok',
  'LinkedIn',
  'Telegram',
  'YouTube',
  'Other',
];
