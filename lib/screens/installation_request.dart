import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ona_net/themes/app_theme.dart';
import 'package:ona_net/utils/location.dart';
import 'package:ona_net/auth/phone_verification.dart';
import 'package:ona_net/auth/installation_service_request.dart';

class InstallationRequestScreen extends StatefulWidget {
  final Map<String, dynamic> provider;
  final Map<String, dynamic> package;

  const InstallationRequestScreen({
    super.key,
    required this.provider,
    required this.package,
  });

  @override
  State<InstallationRequestScreen> createState() =>
      _InstallationRequestScreenState();
}

class _InstallationRequestScreenState extends State<InstallationRequestScreen> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _estateController = TextEditingController();
  final _houseController = TextEditingController();
  final _landmarkController = TextEditingController();
  final _messageController = TextEditingController();
  final _mapLocationController = TextEditingController();

  bool _otpSent = false;
  bool _phoneVerified = false;
  bool _checkingPhoneStatus = true;
  bool _loadingLocation = false;
  bool _consentAccepted = false;
  bool _otpLoading = false;
  bool _submitting = false;
  String? _otpError;
  String? _submitError;
  final _phoneVerificationService = PhoneVerificationService();
  final _installationRequestService = InstallationServiceRequest();
  Timer? _locationDebounce;
  List<LocationSuggestion> _locationSuggestions = [];
  bool _searchingLocations = false;
  String? _locationLabel;
  double? _locationLatitude;
  double? _locationLongitude;
  DateTime? _installationDate;
  TimeOfDay? _installationTime;

  @override
  void initState() {
    super.initState();
    _loadSavedPhoneVerification();
  }

  Future<void> _loadSavedPhoneVerification() async {
    try {
      final status = await _phoneVerificationService.status();
      if (!mounted) return;
      setState(() {
        _phoneVerified = status.isVerified;
        _checkingPhoneStatus = false;
        if (status.isVerified &&
            status.phoneNumber?.trim().isNotEmpty == true) {
          _phoneController.text = status.phoneNumber!;
        }
      });
    } catch (_) {
      if (!mounted) return;
      // If the status request fails, keep manual OTP verification available.
      setState(() => _checkingPhoneStatus = false);
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _estateController.dispose();
    _houseController.dispose();
    _landmarkController.dispose();
    _messageController.dispose();
    _mapLocationController.dispose();
    _locationDebounce?.cancel();
    super.dispose();
  }

  Future<void> _fetchGpsLocation() async {
    setState(() => _loadingLocation = true);
    final location = await Location.getCurrentLocation().timeout(
      const Duration(seconds: 10),
      onTimeout: () => null,
    );
    if (!mounted) return;
    setState(() {
      if (location != null) {
        _locationLabel =
            location.area ??
            '${location.latitude.toStringAsFixed(6)}, '
                '${location.longitude.toStringAsFixed(6)}';
        _locationLatitude = location.latitude;
        _locationLongitude = location.longitude;
        _mapLocationController.text = _locationLabel!;
        _locationSuggestions = [];
      }
      _loadingLocation = false;
    });
    if (location == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to detect location. Type it manually instead.'),
        ),
      );
    }
  }

  void _onLocationChanged(String value) {
    _locationDebounce?.cancel();
    final query = value.trim();
    setState(() {
      _locationLabel = query.isEmpty ? null : query;
      _locationLatitude = null;
      _locationLongitude = null;
      if (query.length < 2) {
        _locationSuggestions = [];
        _searchingLocations = false;
      } else {
        _searchingLocations = true;
      }
    });
    if (query.length < 2) return;

    _locationDebounce = Timer(const Duration(milliseconds: 450), () async {
      final suggestions = await Location.searchAreas(query);
      if (!mounted || _mapLocationController.text.trim() != query) return;
      setState(() {
        _locationSuggestions = suggestions;
        _searchingLocations = false;
      });
    });
  }

  void _selectLocation(LocationSuggestion suggestion) {
    setState(() {
      _locationLabel = suggestion.displayName;
      _locationLatitude = suggestion.latitude;
      _locationLongitude = suggestion.longitude;
      _mapLocationController.text = suggestion.displayName;
      _mapLocationController.selection = TextSelection.collapsed(
        offset: _mapLocationController.text.length,
      );
      _locationSuggestions = [];
      _searchingLocations = false;
    });
  }

  String? get _googleMapsUrl {
    final label = _locationLabel?.trim();
    if (label == null || label.isEmpty) return null;
    final query = _locationLatitude != null && _locationLongitude != null
        ? '$_locationLatitude,$_locationLongitude'
        : label;
    return Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': query,
    }).toString();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
    );
    if (picked != null) setState(() => _installationDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 10, minute: 0),
    );
    if (picked != null) setState(() => _installationTime = picked);
  }

  Future<void> _sendOtp() async {
    final raw = _phoneController.text.trim();
    if (raw.isEmpty) return;
    final e164 = PhoneVerificationService.normalizeKenyanPhone(raw);
    if (!e164.startsWith('+') || e164.length < 10) {
      setState(() => _otpError = 'Enter a Valid phone number.');
      return;
    }

    setState(() {
      _otpError = null;
      _otpLoading = true;
      // Reveal the input immediately so the user can prepare the code while
      // the SMS provider finishes delivering it.
      _otpSent = true;
    });

    try {
      await _phoneVerificationService.startVerification(phoneE164: e164);
      if (!mounted) return;
      _phoneController.text = e164;
      setState(() {
        _otpSent = true;
        _otpLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _otpError = e.toString();
        _otpLoading = false;
        _otpSent = false;
      });
    }
  }

  Future<void> _verifyOtp() async {
    final raw = _phoneController.text.trim();
    final otp = _otpController.text.trim();

    if (otp.length < 4) return;
    final e164 = PhoneVerificationService.normalizeKenyanPhone(raw);
    setState(() {
      _otpLoading = true;
      _otpError = null;
    });

    try {
      await _phoneVerificationService.verify(phoneE164: e164, otp: otp);
      if (!mounted) return;
      setState(() {
        _phoneVerified = true;
        _otpLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _otpLoading = false;
        _otpError = e.toString();
      });
    }
  }

  bool get _canSubmit =>
      !_submitting &&
      _phoneVerified &&
      _googleMapsUrl != null &&
      _estateController.text.trim().isNotEmpty &&
      _houseController.text.trim().isNotEmpty &&
      _installationDate != null &&
      _installationTime != null &&
      _consentAccepted;

  Future<void> _submitRequest() async {
    final providerId = (widget.provider['id'] ?? '').toString();
    final packageId = (widget.package['id'] ?? '').toString();
    if (providerId.isEmpty || packageId.isEmpty) {
      setState(() {
        _submitError = 'Provider or package information is missing.';
      });
      return;
    }

    setState(() {
      _submitting = true;
      _submitError = null;
    });

    try {
      await _installationRequestService.submit(
        providerId: providerId,
        packageId: packageId,
        phoneE164: PhoneVerificationService.normalizeKenyanPhone(
          _phoneController.text,
        ),
        gpsLocation: _googleMapsUrl,
        estateOrBuilding: _estateController.text.trim(),
        houseOrApartment: _houseController.text.trim(),
        landmark: _landmarkController.text.trim(),
        customerMessage: _messageController.text.trim(),
        preferredDate: _installationDate!,
        preferredTime: _installationTime!,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Installation request submitted.')),
      );
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submitError = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: isDark ? AppTheme.navyMid : AppTheme.white,
        elevation: 0,
        title: Text(
          'Request Installation',
          style: TextStyle(
            color: isDark ? AppTheme.white : AppTheme.navy,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: isDark ? AppTheme.white : AppTheme.navy,
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_submitError != null) ...[
                Text(
                  _submitError!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              ElevatedButton(
                onPressed: _canSubmit ? _submitRequest : null,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  backgroundColor: AppTheme.amber,
                  disabledBackgroundColor: AppTheme.gray.withValues(
                    alpha: 0.35,
                  ),
                  foregroundColor: AppTheme.navy,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        'Submit Request',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PackageSummaryCard(
              provider: widget.provider,
              package: widget.package,
            ),
            const SizedBox(height: 18),
            const _RequestSectionTitle('Verify Phone Number'),
            const SizedBox(height: 10),
            _SectionCard(
              children: [
                _TrustStatusRow(
                  icon: _phoneVerified
                      ? Icons.verified_rounded
                      : Icons.privacy_tip_outlined,
                  title: _phoneVerified
                      ? 'Phone verified'
                      : _checkingPhoneStatus
                      ? 'Checking phone verification...'
                      : 'Phone verification required',
                  subtitle: _phoneVerified
                      ? 'Verified permanently for this OnaNet account.'
                      : _checkingPhoneStatus
                      ? 'Checking your saved account verification.'
                      : 'Verify before submitting an installation request.',
                  color: _phoneVerified ? AppTheme.green : AppTheme.amber,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _phoneController,
                  readOnly: _phoneVerified || _checkingPhoneStatus,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Phone number',
                    hintText: '07xx xxx xxx',
                    suffixIcon: _checkingPhoneStatus
                        ? const Padding(
                            padding: EdgeInsets.all(14),
                            child: SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : _phoneVerified
                        ? const Icon(
                            Icons.verified_rounded,
                            color: AppTheme.green,
                          )
                        : null,
                  ),
                ),
                if (_otpSent && !_phoneVerified) ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: _otpController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'OTP code',
                      hintText: 'Enter 4-6 digit code',
                    ),
                  ),
                ],
                if (_otpError != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    _otpError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed:
                        _phoneVerified || _checkingPhoneStatus || _otpLoading
                        ? null
                        : _otpSent
                        ? _verifyOtp
                        : _sendOtp,
                    child: _otpLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_otpSent ? 'Verify OTP' : 'Send OTP'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const _RequestSectionTitle('Installation Location'),
            const SizedBox(height: 10),
            _SectionCard(
              children: [
                _TrustStatusRow(
                  icon: Icons.my_location_rounded,
                  title: _locationLabel ?? 'Installation map location',
                  subtitle: _loadingLocation
                      ? 'Detecting location...'
                      : 'Use GPS or type an address for the provider to open in Maps.',
                  color: AppTheme.amber,
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _loadingLocation ? null : _fetchGpsLocation,
                  icon: const Icon(Icons.gps_fixed_rounded),
                  label: Text(
                    _locationLabel == null
                        ? 'Use Current GPS Location'
                        : 'Refresh GPS Location',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _mapLocationController,
                  onChanged: _onLocationChanged,
                  decoration: InputDecoration(
                    labelText: 'Search map location',
                    hintText: 'Type an estate, road, building, or landmark',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchingLocations
                        ? const Padding(
                            padding: EdgeInsets.all(14),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : null,
                  ),
                ),
                if (_locationSuggestions.isNotEmpty)
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 220),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _locationSuggestions.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final suggestion = _locationSuggestions[index];
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.location_on_outlined),
                          title: Text(suggestion.title),
                          subtitle: suggestion.subtitle.isEmpty
                              ? null
                              : Text(suggestion.subtitle),
                          onTap: () => _selectLocation(suggestion),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: _estateController,
                  decoration: const InputDecoration(
                    labelText: 'Estate / building',
                    hintText: 'e.g. Pipeline, Court 4, Block B',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _houseController,
                  decoration: const InputDecoration(
                    labelText: 'House / apartment number',
                    hintText: 'e.g. B12, 3rd Floor',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _landmarkController,
                  decoration: const InputDecoration(
                    labelText: 'Landmark',
                    hintText: 'e.g. Near AIC Pipeline Church',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _messageController,
                  minLines: 3,
                  maxLines: 5,
                  maxLength: 1000,
                  decoration: const InputDecoration(
                    labelText:
                        'Message or question for the provider (optional)',
                    hintText:
                        'Ask about installation, equipment, or availability',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const _RequestSectionTitle('Preferred Installation Time'),
            const SizedBox(height: 10),
            _SectionCard(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _PickerTile(
                        icon: Icons.calendar_month_rounded,
                        label: _installationDate == null
                            ? 'Pick date'
                            : _formatDate(_installationDate!),
                        onTap: _pickDate,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _PickerTile(
                        icon: Icons.schedule_rounded,
                        label: _installationTime == null
                            ? 'Pick time'
                            : _installationTime!.format(context),
                        onTap: _pickTime,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 18),
            const _RequestSectionTitle('Trust & Consent'),
            const SizedBox(height: 10),
            _SectionCard(
              children: [
                const _TrustStatusRow(
                  icon: Icons.shield_outlined,
                  title: 'Reliability tracking will be added later',
                  subtitle:
                      'Future checks may flag cancelled requests, ignored provider calls, fake addresses, or repeated spam.',
                  color: AppTheme.gray,
                ),
                const SizedBox(height: 10),
                const _TrustStatusRow(
                  icon: Icons.badge_outlined,
                  title: 'Provider-side trust preview',
                  subtitle:
                      'Later, providers can see phone verified, location verified, or new user status.',
                  color: AppTheme.gray,
                ),
                const SizedBox(height: 10),
                CheckboxListTile(
                  value: _consentAccepted,
                  onChanged: (value) {
                    setState(() => _consentAccepted = value ?? false);
                  },
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text(
                    'I understand providers may contact me for installation and service confirmation.',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _PackageSummaryCard extends StatelessWidget {
  final Map<String, dynamic> provider;
  final Map<String, dynamic> package;

  const _PackageSummaryCard({required this.provider, required this.package});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final logoUrl = (provider['logoUrl'] ?? provider['logo_url'])?.toString();
    final logoScale =
        _asDouble(provider['logoScale'] ?? provider['logo_display_size']) ??
        1.0;
    final logoOffset = Offset(
      _asDouble(provider['logoOffsetX'] ?? provider['logo_offset_x']) ?? 0,
      _asDouble(provider['logoOffsetY'] ?? provider['logo_offset_y']) ?? 0,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.navyMid : AppTheme.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppTheme.navyLight : AppTheme.lightGray,
        ),
      ),
      child: Row(
        children: [
          _ProviderLogoMark(
            logoUrl: logoUrl,
            logoScale: logoScale,
            logoOffset: logoOffset,
            color: Color(provider['color']),
            initials: provider['initials'],
            size: 48,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  provider['name'],
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  '${package['speed']} ${package['name']}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.amber,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'KES ${package['price']}/mo',
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  '${package['contract']} • Installation: KES ${package['installationFee']}',
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: AppTheme.gray),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  double? _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }
}

class _ProviderLogoMark extends StatelessWidget {
  const _ProviderLogoMark({
    required this.logoUrl,
    required this.logoScale,
    required this.logoOffset,
    required this.color,
    required this.initials,
    required this.size,
  });

  final String? logoUrl;
  final double logoScale;
  final Offset logoOffset;
  final Color color;
  final String initials;
  final double size;

  @override
  Widget build(BuildContext context) {
    final url = logoUrl;
    final imageSize = size * logoScale.clamp(0.75, 3.0);
    final displayOffset = Offset(
      logoOffset.dx * size / 280,
      logoOffset.dy * size / 280,
    );

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      clipBehavior: Clip.antiAlias,
      child: url == null || url.isEmpty
          ? Text(
              initials,
              style: TextStyle(
                color: Colors.white,
                fontSize: size * 0.35,
                fontWeight: FontWeight.w800,
              ),
            )
          : Image.network(
              url,
              width: imageSize,
              height: imageSize,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Text(
                initials,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: size * 0.35,
                  fontWeight: FontWeight.w800,
                ),
              ),
              frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                return Transform.translate(offset: displayOffset, child: child);
              },
            ),
    );
  }
}

class _RequestSectionTitle extends StatelessWidget {
  final String title;

  const _RequestSectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final List<Widget> children;

  const _SectionCard({required this.children});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.navyMid : AppTheme.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppTheme.navyLight : AppTheme.lightGray,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _TrustStatusRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  const _TrustStatusRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppTheme.gray),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PickerTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _PickerTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
}
