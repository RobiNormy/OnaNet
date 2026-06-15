import 'package:camera/camera.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ona_net/provider/packages.dart';
import 'package:ona_net/provider/provider_flow_widgets.dart';
import 'package:ona_net/provider/provider_registration_data.dart';
import 'package:ona_net/themes/app_theme.dart';

class VerificationScreen extends StatefulWidget {
  const VerificationScreen({
    super.key,
    required this.providerKind,
    required this.draft,
  });

  final ProviderKind providerKind;
  final ProviderRegistrationDraft draft;

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  static const int _maxFileSizeBytes = 5 * 1024 * 1024;

  final Map<String, PlatformFile> _selectedFiles = {};
  static const Map<String, String> _documentTypes = {
    'nationalIdFront': 'national_id_front',
    'nationalIdBack': 'national_id_back',
    'selfie': 'selfie',
    'businessRegistration': 'business_registration',
    'kraPin': 'kra_pin',
    'businessPermit': 'business_permit',
    'premisesPhoto': 'premises_photo',
  };

  Future<void> _pickFile(
    String id, {
    List<String> allowedExtensions = const ['jpg', 'jpeg', 'png', 'pdf'],
  }) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
      allowMultiple: false,
      withData: true,
    );

    final file = result?.files.single;
    if (file == null) {
      return;
    }

    if (file.size > _maxFileSizeBytes) {
      _showSnackBar('File must be 5 MB or smaller.');
      return;
    }

    setState(() => _selectedFiles[id] = file);
  }

  Future<void> _capturePhoto(String id) async {
    try {
      final image = await Navigator.push<XFile>(
        context,
        MaterialPageRoute(builder: (context) => const _CameraCaptureScreen()),
      );

      if (image == null) {
        return;
      }

      final size = await image.length();
      if (size > _maxFileSizeBytes) {
        _showSnackBar('Photo must be 5 MB or smaller.');
        return;
      }

      final bytes = await image.readAsBytes();
      setState(() {
        _selectedFiles[id] = PlatformFile(
          name: image.name,
          size: size,
          path: image.path,
          bytes: bytes,
        );
      });
    } on CameraException catch (error) {
      _showSnackBar(error.description ?? 'Could not open camera.');
    } catch (_) {
      _showSnackBar('Could not open camera.');
    }
  }

  void _continue() {
    final hasBusinessDocs =
        _selectedFiles.containsKey('businessRegistration') ||
        _selectedFiles.containsKey('kraPin') ||
        _selectedFiles.containsKey('businessPermit') ||
        _selectedFiles.containsKey('premisesPhoto');
    final hasIdentityDocs =
        _selectedFiles.containsKey('nationalIdFront') ||
        _selectedFiles.containsKey('nationalIdBack') ||
        _selectedFiles.containsKey('selfie');

    final draft = widget.draft.copyWith(
      hasBusinessDocs: hasBusinessDocs,
      hasLicense: hasIdentityDocs,
      documents: _selectedFiles.entries
          .map(
            (entry) => ProviderDocumentDraft(
              documentType: _documentTypes[entry.key]!,
              file: entry.value,
            ),
          )
          .toList(),
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            PackagesScreen(providerKind: widget.providerKind, draft: draft),
      ),
    );
  }

  void _removeFile(String id) {
    setState(() => _selectedFiles.remove(id));
  }

  void _previewFile(PlatformFile file) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.offWhite : AppTheme.navy;
    final isImage = _isImageFile(file);

    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            file.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              color: textColor,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420, maxHeight: 520),
            child: isImage && file.bytes != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(file.bytes!, fit: BoxFit.contain),
                  )
                : _FilePreviewPlaceholder(file: file),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  bool _isImageFile(PlatformFile file) {
    final name = file.name.toLowerCase();
    return name.endsWith('.jpg') ||
        name.endsWith('.jpeg') ||
        name.endsWith('.png');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subtitleColor = isDark ? AppTheme.gray : AppTheme.darkGray;

    return ProviderFlowShell(
      title: widget.providerKind.registrationTitle,
      icon: widget.providerKind.icon,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const StepProgressHeader(currentStep: 6),
          const SizedBox(height: 28),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SoftIcon(
                icon: Icons.verified_user_outlined,
                color: AppTheme.amber,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Help customers trust your business. Your documents are private and will only be used for verification purposes.',
                  style: GoogleFonts.urbanist(
                    color: subtitleColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          _VerificationSection(
            icon: Icons.person_outline_rounded,
            title: 'Identity Verification',
            badge: 'Optional',
            subtitle: 'Verify your identity to secure your provider account.',
            children: [
              _UploadTile(
                title: 'National ID Front',
                icon: Icons.badge_outlined,
                buttonLabel: 'Upload Document',
                helperText: 'JPG, PNG, PDF (Max 5MB)',
                selectedFile: _selectedFiles['nationalIdFront'],
                onTap: () => _pickFile('nationalIdFront'),
                onCameraTap: () => _capturePhoto('nationalIdFront'),
                onPreview: _selectedFiles['nationalIdFront'] == null
                    ? null
                    : () => _previewFile(_selectedFiles['nationalIdFront']!),
                onDelete: () => _removeFile('nationalIdFront'),
              ),
              _UploadTile(
                title: 'National ID Back',
                icon: Icons.article_outlined,
                buttonLabel: 'Upload Document',
                helperText: 'JPG, PNG, PDF (Max 5MB)',
                selectedFile: _selectedFiles['nationalIdBack'],
                onTap: () => _pickFile('nationalIdBack'),
                onCameraTap: () => _capturePhoto('nationalIdBack'),
                onPreview: _selectedFiles['nationalIdBack'] == null
                    ? null
                    : () => _previewFile(_selectedFiles['nationalIdBack']!),
                onDelete: () => _removeFile('nationalIdBack'),
              ),
              _UploadTile(
                title: 'Selfie Verification',
                icon: Icons.face_outlined,
                buttonLabel: 'Choose Selfie',
                helperText: 'JPG, PNG (Max 5MB)',
                selectedFile: _selectedFiles['selfie'],
                onTap: () => _pickFile(
                  'selfie',
                  allowedExtensions: const ['jpg', 'jpeg', 'png'],
                ),
                onCameraTap: () => _capturePhoto('selfie'),
                onPreview: _selectedFiles['selfie'] == null
                    ? null
                    : () => _previewFile(_selectedFiles['selfie']!),
                onDelete: () => _removeFile('selfie'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _VerificationSection(
            icon: Icons.business_center_outlined,
            title: 'Business Verification',
            badge: 'Optional',
            subtitle: 'Add business documents to help customers trust you.',
            children: [
              _UploadTile(
                title: 'Business Registration',
                icon: Icons.description_outlined,
                buttonLabel: 'Upload Document',
                helperText: 'JPG, PNG, PDF (Max 5MB)',
                selectedFile: _selectedFiles['businessRegistration'],
                onTap: () => _pickFile('businessRegistration'),
                onCameraTap: () => _capturePhoto('businessRegistration'),
                onPreview: _selectedFiles['businessRegistration'] == null
                    ? null
                    : () =>
                          _previewFile(_selectedFiles['businessRegistration']!),
                onDelete: () => _removeFile('businessRegistration'),
              ),
              _UploadTile(
                title: 'KRA PIN Certificate',
                icon: Icons.receipt_long_outlined,
                buttonLabel: 'Upload Document',
                helperText: 'JPG, PNG, PDF (Max 5MB)',
                selectedFile: _selectedFiles['kraPin'],
                onTap: () => _pickFile('kraPin'),
                onCameraTap: () => _capturePhoto('kraPin'),
                onPreview: _selectedFiles['kraPin'] == null
                    ? null
                    : () => _previewFile(_selectedFiles['kraPin']!),
                onDelete: () => _removeFile('kraPin'),
              ),
              _UploadTile(
                title: 'Business Permit',
                icon: Icons.assignment_outlined,
                buttonLabel: 'Upload Document',
                helperText: 'JPG, PNG, PDF (Max 5MB)',
                selectedFile: _selectedFiles['businessPermit'],
                onTap: () => _pickFile('businessPermit'),
                onCameraTap: () => _capturePhoto('businessPermit'),
                onPreview: _selectedFiles['businessPermit'] == null
                    ? null
                    : () => _previewFile(_selectedFiles['businessPermit']!),
                onDelete: () => _removeFile('businessPermit'),
              ),
              _UploadTile(
                title: 'Premises Photo',
                icon: Icons.storefront_outlined,
                buttonLabel: 'Choose Photo',
                helperText: 'JPG, PNG (Max 5MB)',
                selectedFile: _selectedFiles['premisesPhoto'],
                onTap: () => _pickFile(
                  'premisesPhoto',
                  allowedExtensions: const ['jpg', 'jpeg', 'png'],
                ),
                onCameraTap: () => _capturePhoto('premisesPhoto'),
                onPreview: _selectedFiles['premisesPhoto'] == null
                    ? null
                    : () => _previewFile(_selectedFiles['premisesPhoto']!),
                onDelete: () => _removeFile('premisesPhoto'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const _BenefitsPanel(),
          const SizedBox(height: 18),
          _StatusPanel(hasSelections: _selectedFiles.isNotEmpty),
          const SizedBox(height: 26),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_rounded, size: 19),
                  label: const Text('Back'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                    foregroundColor: isDark ? AppTheme.offWhite : AppTheme.navy,
                    side: BorderSide(
                      color: isDark ? AppTheme.navyLight : AppTheme.darkGray,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    textStyle: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ProviderPrimaryButton(
                  label: 'Continue',
                  onPressed: _continue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const SecureFooter(),
        ],
      ),
    );
  }
}

class _VerificationSection extends StatelessWidget {
  const _VerificationSection({
    required this.icon,
    required this.title,
    required this.badge,
    required this.subtitle,
    required this.children,
  });

  final IconData icon;
  final String title;
  final String badge;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppTheme.navyMid : AppTheme.white;
    final borderColor = isDark ? AppTheme.navyLight : AppTheme.lightGray;
    final textColor = isDark ? AppTheme.offWhite : AppTheme.navy;
    final subtitleColor = isDark ? AppTheme.gray : AppTheme.darkGray;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: AppTheme.amber, size: 30),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.plusJakartaSans(
                            color: textColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        _Badge(label: badge),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      style: GoogleFonts.urbanist(
                        color: subtitleColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 460 ? 2 : 1;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: children.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: columns == 1 ? 0.98 : 0.68,
                ),
                itemBuilder: (context, index) => children[index],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _UploadTile extends StatelessWidget {
  const _UploadTile({
    required this.title,
    required this.icon,
    required this.buttonLabel,
    required this.helperText,
    required this.selectedFile,
    required this.onTap,
    required this.onCameraTap,
    required this.onDelete,
    this.onPreview,
  });

  final String title;
  final IconData icon;
  final String buttonLabel;
  final String helperText;
  final PlatformFile? selectedFile;
  final VoidCallback onTap;
  final VoidCallback onCameraTap;
  final VoidCallback onDelete;
  final VoidCallback? onPreview;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tileColor = isDark ? AppTheme.navy : AppTheme.white;
    final buttonColor = isDark ? AppTheme.navyMid : AppTheme.offWhite;
    final borderColor = isDark ? AppTheme.navyLight : AppTheme.lightGray;
    final textColor = isDark ? AppTheme.offWhite : AppTheme.navy;
    final subtitleColor = isDark ? AppTheme.gray : AppTheme.darkGray;
    final file = selectedFile;
    final fileName = file?.name;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tileColor,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              color: textColor,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              height: 1.2,
            ),
          ),
          _SelectedFilePreview(
            fallbackIcon: icon,
            file: file,
            borderColor: borderColor,
            textColor: textColor,
          ),
          Column(
            children: [
              _TileActionButton(
                icon: file == null
                    ? Icons.cloud_upload_outlined
                    : Icons.check_circle_rounded,
                label: file == null ? buttonLabel : 'Replace',
                color: file == null ? textColor : AppTheme.green,
                backgroundColor: buttonColor,
                borderColor: borderColor,
                onTap: onTap,
              ),
              const SizedBox(height: 8),
              _TileActionButton(
                icon: Icons.photo_camera_outlined,
                label: 'Open Camera',
                color: textColor,
                backgroundColor: buttonColor,
                borderColor: borderColor,
                onTap: onCameraTap,
              ),
              if (file != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _TileIconButton(
                        icon: Icons.visibility_outlined,
                        label: 'Preview',
                        color: textColor,
                        backgroundColor: buttonColor,
                        borderColor: borderColor,
                        onTap: onPreview ?? () {},
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _TileIconButton(
                        icon: Icons.delete_outline_rounded,
                        label: 'Delete',
                        color: Colors.red,
                        backgroundColor: buttonColor,
                        borderColor: borderColor,
                        onTap: onDelete,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
          Text(
            fileName ?? helperText,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.urbanist(
              color: fileName == null ? subtitleColor : AppTheme.green,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectedFilePreview extends StatelessWidget {
  const _SelectedFilePreview({
    required this.fallbackIcon,
    required this.file,
    required this.borderColor,
    required this.textColor,
  });

  final IconData fallbackIcon;
  final PlatformFile? file;
  final Color borderColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final selectedFile = file;
    final isImage = selectedFile != null && _isImageFile(selectedFile);

    return Container(
      width: double.infinity,
      height: 72,
      decoration: BoxDecoration(
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: selectedFile == null
          ? Center(child: Icon(fallbackIcon, color: AppTheme.amber, size: 42))
          : isImage && selectedFile.bytes != null
          ? Image.memory(selectedFile.bytes!, fit: BoxFit.cover)
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  selectedFile.name.toLowerCase().endsWith('.pdf')
                      ? Icons.picture_as_pdf_outlined
                      : Icons.insert_drive_file_outlined,
                  color: AppTheme.amber,
                  size: 30,
                ),
                const SizedBox(height: 4),
                Text(
                  selectedFile.name.toLowerCase().endsWith('.pdf')
                      ? 'PDF'
                      : 'File',
                  style: GoogleFonts.plusJakartaSans(
                    color: textColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
    );
  }

  static bool _isImageFile(PlatformFile file) {
    final name = file.name.toLowerCase();
    return name.endsWith('.jpg') ||
        name.endsWith('.jpeg') ||
        name.endsWith('.png');
  }
}

class _FilePreviewPlaceholder extends StatelessWidget {
  const _FilePreviewPlaceholder({required this.file});

  final PlatformFile file;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.offWhite : AppTheme.navy;
    final subtitleColor = isDark ? AppTheme.gray : AppTheme.darkGray;

    return SizedBox(
      width: 320,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            file.name.toLowerCase().endsWith('.pdf')
                ? Icons.picture_as_pdf_outlined
                : Icons.insert_drive_file_outlined,
            color: AppTheme.amber,
            size: 58,
          ),
          const SizedBox(height: 12),
          Text(
            file.name.toLowerCase().endsWith('.pdf')
                ? 'PDF selected'
                : 'File selected',
            style: GoogleFonts.plusJakartaSans(
              color: textColor,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _formatFileSize(file.size),
            style: GoogleFonts.urbanist(
              color: subtitleColor,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

String _formatFileSize(int bytes) {
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  if (bytes >= 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }

  return '$bytes B';
}

class _BenefitsPanel extends StatelessWidget {
  const _BenefitsPanel();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final panelColor = isDark
        ? AppTheme.amber.withValues(alpha: 0.08)
        : AppTheme.amber.withValues(alpha: 0.08);
    final borderColor = AppTheme.amber.withValues(alpha: isDark ? 0.25 : 0.22);
    final textColor = isDark ? AppTheme.offWhite : AppTheme.navy;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: panelColor,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.workspace_premium_outlined,
                color: AppTheme.amber,
                size: 34,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Business Verified Benefits',
                  style: GoogleFonts.plusJakartaSans(
                    color: textColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: const [
              _BenefitItem(
                icon: Icons.leaderboard_outlined,
                label: 'Higher search ranking',
              ),
              _BenefitItem(
                icon: Icons.verified_user_outlined,
                label: 'Trusted badge on your profile',
              ),
              _BenefitItem(
                icon: Icons.groups_outlined,
                label: 'More customer confidence',
              ),
              _BenefitItem(
                icon: Icons.support_agent_rounded,
                label: 'Priority support',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TileActionButton extends StatelessWidget {
  const _TileActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.backgroundColor,
    required this.borderColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color backgroundColor;
  final Color borderColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: double.infinity,
        height: 42,
        decoration: BoxDecoration(
          color: backgroundColor,
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 17),
            const SizedBox(width: 7),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  softWrap: false,
                  style: GoogleFonts.plusJakartaSans(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TileIconButton extends StatelessWidget {
  const _TileIconButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.backgroundColor,
    required this.borderColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color backgroundColor;
  final Color borderColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          color: backgroundColor,
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CameraCaptureScreen extends StatefulWidget {
  const _CameraCaptureScreen();

  @override
  State<_CameraCaptureScreen> createState() => _CameraCaptureScreenState();
}

class _CameraCaptureScreenState extends State<_CameraCaptureScreen>
    with WidgetsBindingObserver {
  final List<FlashMode> _flashModes = const [
    FlashMode.off,
    FlashMode.torch,
    FlashMode.auto,
  ];

  List<CameraDescription> _cameras = [];
  CameraController? _controller;
  FlashMode _flashMode = FlashMode.off;
  bool _isLoading = true;
  bool _isTakingPhoto = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadCameras();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      controller.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera(controller.description);
    }
  }

  Future<void> _loadCameras() async {
    try {
      final cameras = await availableCameras();
      if (!mounted) {
        return;
      }

      if (cameras.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      _cameras = cameras;
      final backCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      await _initializeCamera(backCamera);
    } on CameraException {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _initializeCamera(CameraDescription camera) async {
    setState(() => _isLoading = true);
    await _controller?.dispose();

    final controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
    );

    _controller = controller;

    try {
      await controller.initialize();
      await _applyFlashMode(_flashMode);
    } on CameraException {
      if (!mounted) {
        return;
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleCamera() async {
    final current = _controller?.description;
    if (current == null || _cameras.length < 2) {
      return;
    }

    final nextDirection = current.lensDirection == CameraLensDirection.back
        ? CameraLensDirection.front
        : CameraLensDirection.back;
    final nextCamera = _cameras.firstWhere(
      (camera) => camera.lensDirection == nextDirection,
      orElse: () => _cameras.firstWhere(
        (camera) => camera.name != current.name,
        orElse: () => current,
      ),
    );

    await _initializeCamera(nextCamera);
  }

  Future<void> _cycleFlashMode() async {
    final currentIndex = _flashModes.indexOf(_flashMode);
    final nextMode = _flashModes[(currentIndex + 1) % _flashModes.length];
    await _applyFlashMode(nextMode);
    if (mounted) {
      setState(() => _flashMode = nextMode);
    }
  }

  Future<void> _applyFlashMode(FlashMode mode) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    try {
      await controller.setFlashMode(mode);
    } on CameraException {
      await controller.setFlashMode(FlashMode.off);
      if (mounted) {
        setState(() => _flashMode = FlashMode.off);
      }
    }
  }

  Future<void> _takePhoto() async {
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        _isTakingPhoto) {
      return;
    }

    setState(() => _isTakingPhoto = true);
    try {
      final image = await controller.takePicture();
      if (mounted) {
        Navigator.pop(context, image);
      }
    } on CameraException {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Could not take photo.')));
      }
    } finally {
      if (mounted) {
        setState(() => _isTakingPhoto = false);
      }
    }
  }

  IconData get _flashIcon {
    return switch (_flashMode) {
      FlashMode.torch => Icons.flash_on_rounded,
      FlashMode.auto => Icons.flash_auto_rounded,
      _ => Icons.flash_off_rounded,
    };
  }

  String get _flashLabel {
    return switch (_flashMode) {
      FlashMode.torch => 'On',
      FlashMode.auto => 'Auto',
      _ => 'Off',
    };
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final isReady =
        controller != null && controller.value.isInitialized && !_isLoading;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: isReady
                  ? _CameraPreviewFrame(controller: controller)
                  : const Center(
                      child: CircularProgressIndicator(color: AppTheme.amber),
                    ),
            ),
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Row(
                children: [
                  _CameraIconButton(
                    icon: Icons.close_rounded,
                    label: 'Close',
                    onTap: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  _CameraIconButton(
                    icon: _flashIcon,
                    label: _flashLabel,
                    onTap: _cycleFlashMode,
                  ),
                  const SizedBox(width: 10),
                  _CameraIconButton(
                    icon: Icons.cameraswitch_rounded,
                    label: 'Flip',
                    onTap: _toggleCamera,
                  ),
                ],
              ),
            ),
            Positioned(
              left: 24,
              right: 24,
              bottom: 28,
              child: Column(
                children: [
                  Text(
                    'Frame the document clearly, then capture.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.urbanist(
                      color: AppTheme.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 18),
                  GestureDetector(
                    onTap: isReady ? _takePhoto : null,
                    child: Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.white, width: 4),
                      ),
                      padding: const EdgeInsets.all(7),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: _isTakingPhoto
                              ? AppTheme.gray
                              : AppTheme.amber,
                          shape: BoxShape.circle,
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
    );
  }
}

class _CameraPreviewFrame extends StatelessWidget {
  const _CameraPreviewFrame({required this.controller});

  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final containerRatio = constraints.maxWidth / constraints.maxHeight;
        var previewRatio = controller.value.aspectRatio;

        if (constraints.maxHeight > constraints.maxWidth && previewRatio > 1) {
          previewRatio = 1 / previewRatio;
        } else if (constraints.maxWidth > constraints.maxHeight &&
            previewRatio < 1) {
          previewRatio = 1 / previewRatio;
        }

        final previewSize = containerRatio > previewRatio
            ? Size(constraints.maxWidth, constraints.maxWidth / previewRatio)
            : Size(constraints.maxHeight * previewRatio, constraints.maxHeight);

        return ClipRect(
          child: Center(
            child: SizedBox(
              width: previewSize.width,
              height: previewSize.height,
              child: CameraPreview(controller),
            ),
          ),
        );
      },
    );
  }
}

class _CameraIconButton extends StatelessWidget {
  const _CameraIconButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.white.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.white, size: 20),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.white,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BenefitItem extends StatelessWidget {
  const _BenefitItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.offWhite : AppTheme.navy;

    return SizedBox(
      width: 110,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: textColor, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.urbanist(
                color: textColor,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({required this.hasSelections});

  final bool hasSelections;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppTheme.navyMid : AppTheme.white;
    final borderColor = isDark ? AppTheme.navyLight : AppTheme.lightGray;
    final textColor = isDark ? AppTheme.offWhite : AppTheme.navy;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Verification Status',
            style: GoogleFonts.plusJakartaSans(
              color: textColor,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          _StatusRow(
            icon: Icons.phone_outlined,
            label: 'Phone Verified',
            status: 'Verified',
            color: AppTheme.green,
          ),
          _StatusRow(
            icon: Icons.person_outline_rounded,
            label: 'Identity Verified',
            status: hasSelections ? 'Pending' : 'Optional',
            color: hasSelections ? AppTheme.amber : AppTheme.gray,
          ),
          _StatusRow(
            icon: Icons.business_center_outlined,
            label: 'Business Verified',
            status: hasSelections ? 'Pending' : 'Not Submitted',
            color: hasSelections ? AppTheme.amber : AppTheme.gray,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark
                  ? AppTheme.navy.withValues(alpha: 0.75)
                  : const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  color: isDark ? AppTheme.amber : AppTheme.navyLight,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Your documents are safe and secure. We do not share your documents with third parties.',
                    style: GoogleFonts.urbanist(
                      color: textColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
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

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.icon,
    required this.label,
    required this.status,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String status;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.offWhite : AppTheme.navy;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            icon,
            color: isDark ? AppTheme.gray : AppTheme.darkGray,
            size: 21,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.urbanist(
                color: textColor,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              status,
              style: GoogleFonts.plusJakartaSans(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: isDark
            ? AppTheme.offWhite.withValues(alpha: 0.08)
            : AppTheme.lightGray.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          color: isDark ? AppTheme.gray : AppTheme.darkGray,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _SoftIcon extends StatelessWidget {
  const _SoftIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }
}
