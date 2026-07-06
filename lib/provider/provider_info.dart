import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ona_net/provider/provider_flow_widgets.dart';
import 'package:ona_net/provider/provider_registration_data.dart';
import 'package:ona_net/provider/services_offered.dart';
import 'package:ona_net/themes/app_theme.dart';
import 'package:permission_handler/permission_handler.dart';

Future<Uint8List?> _readPlatformFileBytes(PlatformFile file) async {
  try {
    return await file.readAsBytes();
  } catch (_) {
    return null;
  }
}

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
    final hasPermission = await _requestPhotoAccessPermission();
    if (!hasPermission) return;

    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png'],
    );
    if (file == null) return;
    if (!_isValidLogoSize(file.size)) return;

    final bytes = await _readPlatformFileBytes(file);
    if (bytes == null) {
      _showSnackBar('Could not read the selected image.');
      return;
    }

    setState(() {
      _logoFile = PlatformFile(
        name: file.name,
        size: file.size,
        path: file.path,
        bytes: bytes,
      );
      _logoDisplaySize = 1.0;
      _logoOffset = Offset.zero;
    });
    await _editLogo();
  }

  Future<bool> _requestPhotoAccessPermission() async {
    final current = await Permission.photos.status;
    if (_isAllowedPermission(current)) return true;

    final requested = await Permission.photos.request();
    if (_isAllowedPermission(requested)) return true;

    if (Platform.isAndroid) {
      final storage = await Permission.storage.request();
      if (_isAllowedPermission(storage)) return true;
    }

    if (requested.isPermanentlyDenied || requested.isRestricted) {
      _showSnackBar('Allow photo access in settings to choose a logo.');
      await openAppSettings();
      return false;
    }

    _showSnackBar('Photo access permission is needed to choose a logo.');
    return false;
  }

  bool _isAllowedPermission(PermissionStatus status) {
    return status.isGranted || status.isLimited;
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
    if (file == null) return;

    final edit = await Navigator.push<_LogoEdit>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => _LogoEditorScreen(
          file: file,
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
                child: _LogoActionButton(
                  onPressed: onPick,
                  icon: const Icon(Icons.photo_library_outlined, size: 18),
                  label: selectedFile == null ? 'Gallery' : 'Replace',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _LogoActionButton(
                  onPressed: onCapture,
                  icon: const Icon(Icons.photo_camera_outlined, size: 18),
                  label: 'Open Camera',
                ),
              ),
            ],
          ),
          if (selectedFile != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.crop_free_rounded, size: 18),
                    label: const Text('Edit Logo'),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filledTonal(
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline_rounded),
                  color: Colors.red,
                  tooltip: 'Remove logo',
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _LogoActionButton extends StatelessWidget {
  const _LogoActionButton({
    required this.onPressed,
    required this.icon,
    required this.label,
  });

  final VoidCallback onPressed;
  final Widget icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              softWrap: false,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
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
    const frameSize = 72.0;
    final displayScale = scale.clamp(1.0, 3.0);
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
      child: file == null
          ? const Icon(Icons.image_outlined, color: AppTheme.amber, size: 28)
          : FutureBuilder<Uint8List?>(
              future: _readPlatformFileBytes(file!),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  );
                }

                final bytes = snapshot.data;
                if (bytes == null) {
                  return const Icon(
                    Icons.image_outlined,
                    color: AppTheme.amber,
                    size: 28,
                  );
                }

                return Transform(
                  transform: Matrix4.identity()
                    ..translate(displayOffset.dx, displayOffset.dy, 0.0)
                    ..scale(displayScale, displayScale, 1.0),
                  child: Image.memory(
                    bytes,
                    width: frameSize,
                    height: frameSize,
                    fit: BoxFit.cover,
                  ),
                );
              },
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
  static const double _frameSize = 280.0;

  late double _scale = widget.initialScale.clamp(1.0, 3.0);
  late Offset _offset = widget.initialOffset;
  late final TransformationController _transformController;
  bool _isApplyingTransform = false;

  @override
  void initState() {
    super.initState();
    _offset = _clampOffset(_offset, _frameSize);
    _transformController = TransformationController(
      _matrixFor(scale: _scale, offset: _offset),
    )..addListener(_syncFromTransform);
  }

  @override
  void dispose() {
    _transformController.removeListener(_syncFromTransform);
    _transformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const frameSize = _frameSize;

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
                child: Container(
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
                  child: FutureBuilder<Uint8List?>(
                    future: _readPlatformFileBytes(widget.file),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        );
                      }

                      final bytes = snapshot.data;
                      if (bytes == null) {
                        return const Icon(
                          Icons.image_outlined,
                          color: Colors.white,
                          size: 52,
                        );
                      }

                      return InteractiveViewer(
                        transformationController: _transformController,
                        minScale: 1.0,
                        maxScale: 3.0,
                        boundaryMargin: const EdgeInsets.all(frameSize),
                        clipBehavior: Clip.none,
                        panEnabled: true,
                        scaleEnabled: true,
                        onInteractionEnd: (_) => _setTransform(
                          scale: _scale,
                          offset: _clampOffset(_offset, frameSize),
                        ),
                        child: Image.memory(
                          bytes,
                          width: frameSize,
                          height: frameSize,
                          fit: BoxFit.cover,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 12),
              child: Row(
                children: [
                  IconButton.filledTonal(
                    onPressed: () => _setScale(_scale - 0.15, frameSize),
                    icon: const Icon(Icons.remove_rounded),
                  ),
                  Expanded(
                    child: Slider(
                      value: _scale,
                      min: 1.0,
                      max: 3.0,
                      divisions: 20,
                      activeColor: AppTheme.amber,
                      onChanged: (value) =>
                          _setTransform(scale: value, offset: _offset),
                    ),
                  ),
                  IconButton.filledTonal(
                    onPressed: () => _setScale(_scale + 0.15, frameSize),
                    icon: const Icon(Icons.add_rounded),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 30),
              child: Text(
                'Drag to reposition. Pinch or use the slider to zoom.',
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

  void _setScale(double value, double frameSize) {
    _setTransform(scale: value, offset: _offset);
  }

  void _setTransform({required double scale, required Offset offset}) {
    final nextScale = scale.clamp(1.0, 3.0);
    final nextOffset = _clampOffset(offset, _frameSize);
    _isApplyingTransform = true;
    setState(() {
      _scale = nextScale;
      _offset = nextOffset;
      _transformController.value = _matrixFor(
        scale: nextScale,
        offset: nextOffset,
      );
    });
    _isApplyingTransform = false;
  }

  void _syncFromTransform() {
    if (_isApplyingTransform || !mounted) return;
    final matrix = _transformController.value;
    final translation = matrix.getTranslation();
    setState(() {
      _scale = matrix.getMaxScaleOnAxis().clamp(1.0, 3.0);
      _offset = Offset(translation.x, translation.y);
    });
  }

  Matrix4 _matrixFor({required double scale, required Offset offset}) {
    return Matrix4.identity()
      ..translate(offset.dx, offset.dy, 0.0)
      ..scale(scale, scale, 1.0);
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
