import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ona_net/auth/auth_service.dart';
import 'package:ona_net/onanet_provider_dash/blueprint_components.dart';
import 'package:ona_net/themes/app_theme.dart';
import 'package:ona_net/utils/platform_file_reader.dart';
import 'package:ona_net/utils/provider_filters.dart';

class ProviderDocumentsPage extends StatefulWidget {
  const ProviderDocumentsPage({
    super.key,
    required this.providerId,
    required this.providerName,
    required this.isVerified,
    required this.onBackPressed,
    required this.showMenuButton,
    required this.onMenuPressed,
    required this.onChanged,
  });

  final String providerId;
  final String providerName;
  final bool isVerified;
  final VoidCallback onBackPressed;
  final bool showMenuButton;
  final VoidCallback onMenuPressed;
  final VoidCallback onChanged;

  @override
  State<ProviderDocumentsPage> createState() => _ProviderDocumentsPageState();
}

class _ProviderDocumentsPageState extends State<ProviderDocumentsPage> {
  static const _maxFileSize = 5 * 1024 * 1024;
  static const _requirements = [
    _DocumentRequirement(
      type: 'national_id_front',
      title: 'National ID front',
      category: 'Identity',
      icon: Icons.badge_outlined,
    ),
    _DocumentRequirement(
      type: 'national_id_back',
      title: 'National ID back',
      category: 'Identity',
      icon: Icons.article_outlined,
    ),
    _DocumentRequirement(
      type: 'selfie',
      title: 'Selfie verification',
      category: 'Identity',
      icon: Icons.face_outlined,
      imagesOnly: true,
    ),
    _DocumentRequirement(
      type: 'business_registration',
      title: 'Business registration',
      category: 'Business',
      icon: Icons.description_outlined,
    ),
    _DocumentRequirement(
      type: 'kra_pin',
      title: 'KRA PIN certificate',
      category: 'Business',
      icon: Icons.receipt_long_outlined,
    ),
    _DocumentRequirement(
      type: 'business_permit',
      title: 'Business permit',
      category: 'Business',
      icon: Icons.assignment_outlined,
    ),
    _DocumentRequirement(
      type: 'premises_photo',
      title: 'Premises photo',
      category: 'Business',
      icon: Icons.storefront_outlined,
      imagesOnly: true,
    ),
  ];

  final _service = AuthService();
  final Set<String> _uploading = {};
  late Future<List<Map<String, dynamic>>> _documents = _load();

  Future<List<Map<String, dynamic>>> _load() {
    if (widget.providerId.isEmpty) return Future.value(const []);
    return _service.getProviderDocuments();
  }

  void _reload() {
    if (!mounted) return;
    setState(() {
      _documents = _load();
    });
    widget.onChanged();
  }

  String _statusFor(String type, List<Map<String, dynamic>> documents) {
    final statuses = documents
        .where((document) => document['document_type'] == type)
        .map((document) => document['status']?.toString().toLowerCase() ?? '')
        .toSet();
    if (statuses.contains('approved') || statuses.contains('verified')) {
      return 'approved';
    }
    if (statuses.contains('pending')) return 'pending';
    if (statuses.contains('rejected')) return 'rejected';
    return 'missing';
  }

  Future<void> _pickAndUpload(_DocumentRequirement requirement) async {
    if (_uploading.contains(requirement.type)) return;
    final extensions = requirement.imagesOnly
        ? const ['jpg', 'jpeg', 'png']
        : const ['jpg', 'jpeg', 'png', 'pdf'];
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: extensions,
    );
    if (file == null || !mounted) return;
    if (file.size > _maxFileSize) {
      _showMessage('Choose a file that is 5 MB or smaller.');
      return;
    }
    final bytes = await readPlatformFileBytes(file);
    if (bytes == null) {
      _showMessage('Could not read the selected file.');
      return;
    }

    setState(() {
      _uploading.add(requirement.type);
    });
    try {
      await _service.uploadProviderDocument(
        providerId: widget.providerId,
        documentType: requirement.type,
        file: PlatformFile(
          name: file.name,
          size: file.size,
          path: file.path,
          bytes: bytes,
        ),
      );
      if (!mounted) return;
      _showMessage('${requirement.title} submitted for review.');
      _reload();
    } catch (error) {
      if (mounted) _showMessage(error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _uploading.remove(requirement.type);
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(behavior: SnackBarBehavior.floating, content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.offWhite : AppTheme.navy;
    final mutedColor = isDark ? AppTheme.gray : AppTheme.darkGray;
    final surface = isDark ? const Color(0xFF0D2231) : AppTheme.white;
    final border = isDark ? AppTheme.navyLight : AppTheme.lightGray;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OnaBlueprintHeader(
          title: 'Documents and verification',
          onBack: widget.onBackPressed,
          onMenu: widget.onMenuPressed,
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                widget.isVerified
                    ? Icons.verified_rounded
                    : Icons.fact_check_outlined,
                color: widget.isVerified
                    ? const Color(0xFF2563EB)
                    : AppTheme.amber,
                size: 30,
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.isVerified
                          ? 'Your provider is verified'
                          : 'Complete verification at any time',
                      style: GoogleFonts.plusJakartaSans(
                        color: textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      widget.isVerified
                          ? 'Your Verified badge is separate from your subscription plan badge.'
                          : 'Upload the documents you skipped during registration. Each file is reviewed before a Verified badge is granted.',
                      style: GoogleFonts.urbanist(
                        color: mutedColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: _documents,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _DocumentsError(
                message: snapshot.error.toString(),
                onRetry: _reload,
              );
            }
            final documents = snapshot.data ?? const [];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final category in const ['Identity', 'Business']) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      '$category documents',
                      style: GoogleFonts.plusJakartaSans(
                        color: textColor,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  for (final requirement in _requirements.where(
                    (item) => item.category == category,
                  ))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _DocumentCard(
                        requirement: requirement,
                        status: _statusFor(requirement.type, documents),
                        uploading: _uploading.contains(requirement.type),
                        onUpload: () => _pickAndUpload(requirement),
                      ),
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

class _DocumentRequirement {
  const _DocumentRequirement({
    required this.type,
    required this.title,
    required this.category,
    required this.icon,
    this.imagesOnly = false,
  });

  final String type;
  final String title;
  final String category;
  final IconData icon;
  final bool imagesOnly;
}

class _DocumentCard extends StatelessWidget {
  const _DocumentCard({
    required this.requirement,
    required this.status,
    required this.uploading,
    required this.onUpload,
  });

  final _DocumentRequirement requirement;
  final String status;
  final bool uploading;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.offWhite : AppTheme.navy;
    final mutedColor = isDark ? AppTheme.gray : AppTheme.darkGray;
    final surface = isDark ? const Color(0xFF0D2231) : AppTheme.white;
    final border = isDark ? AppTheme.navyLight : AppTheme.lightGray;
    final statusColor = switch (status) {
      'approved' => const Color(0xFF2563EB),
      'pending' => AppTheme.amberDark,
      'rejected' => Colors.red,
      _ => AppTheme.gray,
    };
    final canUpload = status == 'missing' || status == 'rejected';
    final actionLabel = status == 'rejected' ? 'Resubmit' : 'Upload';

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppTheme.amber.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(requirement.icon, color: AppTheme.amber),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  requirement.title,
                  style: GoogleFonts.plusJakartaSans(
                    color: textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${humanizeBackendValue(status)} · ${requirement.imagesOnly ? 'JPG or PNG' : 'JPG, PNG or PDF'} · Maximum 5 MB',
                  style: GoogleFonts.urbanist(
                    color: mutedColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (canUpload)
            FilledButton.tonalIcon(
              onPressed: uploading ? null : onUpload,
              icon: uploading
                  ? const SizedBox.square(
                      dimension: 15,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.upload_file_rounded, size: 18),
              label: Text(uploading ? 'Uploading' : actionLabel),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                humanizeBackendValue(status),
                style: GoogleFonts.plusJakartaSans(
                  color: statusColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DocumentsError extends StatelessWidget {
  const _DocumentsError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}
