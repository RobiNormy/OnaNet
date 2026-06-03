import 'package:camera/camera.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ona_net/provider/provider_flow_widgets.dart';
import 'package:ona_net/provider/provider_registration_data.dart';
import 'package:ona_net/provider/services_offered.dart';
import 'package:ona_net/themes/app_theme.dart';

class ProviderInfoScreen extends StatefulWidget {
  const ProviderInfoScreen({
    super.key,
    required this.providerKind,
    required this.draft,
  });

  final ProviderKind providerKind;
  final ProviderRegistrationDraft draft;

  @override
  State<ProviderInfoScreen> createState() => _ProviderInfoScreenState();
}

class _ProviderInfoScreenState extends State<ProviderInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _providerNameController = TextEditingController();
  final _businessNameController = TextEditingController();
  final _yearStartedController = TextEditingController();
  final _upstreamProviderController = TextEditingController();
  final _cityController = TextEditingController();
  final _descriptionController = TextEditingController();
  PlatformFile? _logoFile;
  double _logoDisplaySize = 1.0;
  Offset _logoOffset = Offset.zero;

  @override
  void dispose() {
    _providerNameController.dispose();
    _businessNameController.dispose();
    _yearStartedController.dispose();
    _upstreamProviderController.dispose();
    _cityController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ProviderFlowShell(
      title: widget.providerKind.registrationTitle,
      icon: widget.providerKind.icon,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const StepProgressHeader(currentStep: 2),
            const SizedBox(height: 28),
            const ProviderSectionTitle(
              title: 'Provider Info',
              subtitle:
                  'Add the business details customers and OnaNet will use to identify your provider account.',
            ),
            const SizedBox(height: 22),
            ..._providerFields(),
            const SizedBox(height: 42),
            ProviderPrimaryButton(label: 'Continue', onPressed: _continue),
            const SizedBox(height: 24),
            const SecureFooter(),
          ],
        ),
      ),
    );
  }

  String? _requiredField(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    return null;
  }

  String? _optionalYearValidator(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return null;

    final year = int.tryParse(trimmed);
    if (year == null) return 'Enter a valid year';
    if (year < 1900) return 'Enter a year after 1900';
    return null;
  }

  Future<void> _pickLogo() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png'],
      allowMultiple: false,
      withData: true,
    );

    final file = result?.files.single;
    if (file == null) return;
    if (!_isValidLogoSize(file.size)) return;

    setState(() {
      _logoFile = file;
      _logoDisplaySize = 1.0;
      _logoOffset = Offset.zero;
    });
    await _editLogo();
  }

  Future<void> _captureLogo() async {
    try {
      final image = await Navigator.push<XFile>(
        context,
        MaterialPageRoute(builder: (context) => const _LogoCameraScreen()),
      );
      if (image == null) return;

      final size = await image.length();
      if (!_isValidLogoSize(size)) return;

      final bytes = await image.readAsBytes();
      setState(() {
        _logoFile = PlatformFile(
          name: image.name,
          size: size,
          path: image.path,
          bytes: bytes,
        );
        _logoDisplaySize = 1.0;
        _logoOffset = Offset.zero;
      });
      await _editLogo();
    } on CameraException catch (error) {
      _showSnackBar(error.description ?? 'Could not open camera.');
    } catch (_) {
      _showSnackBar('Could not open camera.');
    }
  }

  bool _isValidLogoSize(int size) {
    if (size <= 2 * 1024 * 1024) return true;
    _showSnackBar('Logo must be 2 MB or smaller.');
    return false;
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _editLogo() async {
    final file = _logoFile;
    if (file?.bytes == null) return;

    final edit = await Navigator.push<_LogoEdit>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => _LogoEditorScreen(
          file: file!,
          initialScale: _logoDisplaySize,
          initialOffset: _logoOffset,
        ),
      ),
    );
    if (edit == null || !mounted) return;

    setState(() {
      _logoDisplaySize = edit.scale;
      _logoOffset = edit.offset;
    });
  }

  List<Widget> _providerFields() {
    return [
      ProviderTextField(
        controller: _providerNameController,
        label: 'Provider Name',
        textInputAction: TextInputAction.next,
        validator: _requiredField,
      ),
      const SizedBox(height: 16),
      ProviderTextField(
        controller: _businessNameController,
        label: 'Business Name (Optional)',
        textInputAction: TextInputAction.next,
      ),
      const SizedBox(height: 16),
      _LogoPicker(
        file: _logoFile,
        displaySize: _logoDisplaySize,
        offset: _logoOffset,
        onPick: _pickLogo,
        onCapture: _captureLogo,
        onEdit: _editLogo,
        onRemove: () => setState(() {
          _logoFile = null;
          _logoDisplaySize = 1.0;
          _logoOffset = Offset.zero;
        }),
      ),
      const SizedBox(height: 16),
      ProviderTextField(
        controller: _yearStartedController,
        label: 'Year Started (Optional)',
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.next,
        validator: _optionalYearValidator,
      ),
      const SizedBox(height: 16),
      ProviderTextField(
        controller: _upstreamProviderController,
        label: 'ISP Provider / Upstream Internet Provider',
        textInputAction: TextInputAction.next,
      ),
      const SizedBox(height: 16),
      ProviderTextField(
        controller: _cityController,
        label: 'Primary City / Town',
        textInputAction: TextInputAction.next,
        validator: _requiredField,
      ),
      const SizedBox(height: 16),
      ProviderTextField(
        controller: _descriptionController,
        label: 'Description (Optional)',
        keyboardType: TextInputType.multiline,
        textInputAction: TextInputAction.done,
        maxLines: 4,
      ),
    ];
  }

  void _continue() {
    if (!_formKey.currentState!.validate()) return;

    final draft = widget.draft.copyWith(
      providerName: _providerNameController.text.trim(),
      businessName: _optionalText(_businessNameController.text),
      logoFile: _logoFile,
      logoDisplaySize: _logoDisplaySize,
      logoOffsetX: _logoOffset.dx,
      logoOffsetY: _logoOffset.dy,
      yearStarted: _optionalInt(_yearStartedController.text),
      upstreamProvider: _optionalText(_upstreamProviderController.text),
      primaryCity: _cityController.text.trim(),
      description: _optionalText(_descriptionController.text),
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ServicesOfferedScreen(
          providerKind: widget.providerKind,
          draft: draft,
        ),
      ),
    );
  }

  String? _optionalText(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  int? _optionalInt(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return int.tryParse(trimmed);
  }
}

class _LogoPicker extends StatelessWidget {
  const _LogoPicker({
    required this.file,
    required this.displaySize,
    required this.offset,
    required this.onPick,
    required this.onCapture,
    required this.onEdit,
    required this.onRemove,
  });

  final PlatformFile? file;
  final double displaySize;
  final Offset offset;
  final VoidCallback onPick;
  final VoidCallback onCapture;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.offWhite : AppTheme.navy;
    final borderColor = isDark ? AppTheme.navyLight : AppTheme.lightGray;
    final selectedFile = file;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.navyMid : AppTheme.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: selectedFile == null ? onPick : onEdit,
                child: _LogoPreview(
                  file: selectedFile,
                  scale: displaySize,
                  offset: offset,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Provider Logo',
                      style: GoogleFonts.plusJakartaSans(
                        color: textColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      selectedFile?.name ?? 'JPG or PNG, max 2 MB',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.urbanist(
                        color: isDark ? AppTheme.gray : AppTheme.darkGray,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onPick,
                  icon: const Icon(Icons.photo_library_outlined, size: 18),
                  label: Text(selectedFile == null ? 'Gallery' : 'Replace'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onCapture,
                  icon: const Icon(Icons.photo_camera_outlined, size: 18),
                  label: const Text('Camera'),
                ),
              ),
              if (selectedFile != null) ...[
                const SizedBox(width: 10),
                IconButton(
                  onPressed: onEdit,
                  icon: const Icon(Icons.crop_free_rounded),
                  tooltip: 'Edit logo',
                ),
                IconButton(
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline_rounded),
                  color: Colors.red,
                  tooltip: 'Remove logo',
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _LogoPreview extends StatelessWidget {
  const _LogoPreview({
    required this.file,
    required this.scale,
    required this.offset,
  });

  final PlatformFile? file;
  final double scale;
  final Offset offset;

  @override
  Widget build(BuildContext context) {
    final bytes = file?.bytes;
    const frameSize = 72.0;
    final imageSize = frameSize * scale;
    final displayOffset = Offset(
      offset.dx * frameSize / 280,
      offset.dy * frameSize / 280,
    );

    return Container(
      width: frameSize,
      height: frameSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppTheme.amber.withValues(alpha: 0.12),
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.amber.withValues(alpha: 0.35)),
      ),
      clipBehavior: Clip.antiAlias,
      child: bytes == null
          ? const Icon(Icons.image_outlined, color: AppTheme.amber, size: 28)
          : Transform.translate(
              offset: displayOffset,
              child: Image.memory(
                bytes,
                width: imageSize,
                height: imageSize,
                fit: BoxFit.cover,
              ),
            ),
    );
  }
}

class _LogoEdit {
  const _LogoEdit({required this.scale, required this.offset});

  final double scale;
  final Offset offset;
}

class _LogoEditorScreen extends StatefulWidget {
  const _LogoEditorScreen({
    required this.file,
    required this.initialScale,
    required this.initialOffset,
  });

  final PlatformFile file;
  final double initialScale;
  final Offset initialOffset;

  @override
  State<_LogoEditorScreen> createState() => _LogoEditorScreenState();
}

class _LogoEditorScreenState extends State<_LogoEditorScreen> {
  late double _scale = widget.initialScale.clamp(0.75, 3.0);
  late Offset _offset = widget.initialOffset;
  double _startScale = 1.0;
  Offset _startOffset = Offset.zero;
  Offset _startFocalPoint = Offset.zero;

  @override
  Widget build(BuildContext context) {
    final bytes = widget.file.bytes;
    const frameSize = 280.0;
    final imageSize = frameSize * _scale;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                  Expanded(
                    child: Text(
                      'Edit Logo',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(
                      context,
                      _LogoEdit(scale: _scale, offset: _offset),
                    ),
                    child: const Text('Save'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: GestureDetector(
                  onScaleStart: (details) {
                    _startScale = _scale;
                    _startOffset = _offset;
                    _startFocalPoint = details.focalPoint;
                  },
                  onScaleUpdate: (details) {
                    setState(() {
                      _scale = (_startScale * details.scale).clamp(0.75, 3.0);
                      _offset = _clampOffset(
                        _startOffset + (details.focalPoint - _startFocalPoint),
                        frameSize,
                      );
                    });
                  },
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: frameSize,
                        height: frameSize,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.55),
                            width: 2,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: bytes == null
                            ? const Icon(
                                Icons.image_outlined,
                                color: Colors.white,
                                size: 52,
                              )
                            : Transform.translate(
                                offset: _offset,
                                child: Image.memory(
                                  bytes,
                                  width: imageSize,
                                  height: imageSize,
                                  fit: BoxFit.cover,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 30),
              child: Text(
                'Drag to reposition. Pinch to zoom.',
                textAlign: TextAlign.center,
                style: GoogleFonts.urbanist(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Offset _clampOffset(Offset offset, double frameSize) {
    final limit = frameSize * 0.32 * _scale;
    return Offset(
      offset.dx.clamp(-limit, limit),
      offset.dy.clamp(-limit, limit),
    );
  }
}

class _LogoCameraScreen extends StatefulWidget {
  const _LogoCameraScreen();

  @override
  State<_LogoCameraScreen> createState() => _LogoCameraScreenState();
}

class _LogoCameraScreenState extends State<_LogoCameraScreen> {
  CameraController? _controller;
  Object? _error;
  bool _isCapturing = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _error = 'No camera found.');
        return;
      }

      final controller = CameraController(
        cameras.first,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) return;
      setState(() => _controller = controller);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    }
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || _isCapturing) return;

    setState(() => _isCapturing = true);
    try {
      final image = await controller.takePicture();
      if (!mounted) return;
      Navigator.pop(context, image);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _isCapturing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: _error != null
                  ? Text(
                      'Could not open camera.',
                      style: GoogleFonts.plusJakartaSans(color: Colors.white),
                    )
                  : controller == null || !controller.value.isInitialized
                  ? const CircularProgressIndicator(color: AppTheme.amber)
                  : CameraPreview(controller),
            ),
            Positioned(
              top: 12,
              left: 12,
              child: IconButton.filledTonal(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 24,
              child: Center(
                child: FilledButton.icon(
                  onPressed: _isCapturing ? null : _capture,
                  icon: const Icon(Icons.photo_camera_rounded),
                  label: Text(_isCapturing ? 'Capturing...' : 'Capture Logo'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
