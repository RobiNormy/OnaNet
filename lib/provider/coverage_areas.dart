import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:ona_net/provider/contact_details.dart';
import 'package:ona_net/provider/provider_flow_widgets.dart';
import 'package:ona_net/provider/provider_registration_data.dart';
import 'package:ona_net/themes/app_theme.dart';
import 'package:ona_net/utils/search.dart';

class CoverageAreasScreen extends StatefulWidget {
  const CoverageAreasScreen({
    super.key,
    required this.providerKind,
    required this.draft,
  });

  final ProviderKind providerKind;
  final ProviderRegistrationDraft draft;

  @override
  State<CoverageAreasScreen> createState() => _CoverageAreasScreenState();
}

class _CoverageAreasScreenState extends State<CoverageAreasScreen> {
  static const _defaultCenter = LatLng(-1.286389, 36.817223);

  final _searchController = TextEditingController();
  final _mapController = MapController();
  final _distance = const Distance();

  Timer? _debounce;
  LatLng _coverageCenter = _defaultCenter;
  double _radiusKm = 3;
  String? _coverageName = 'Nairobi';
  bool _isSearching = false;
  bool _isLocating = false;
  bool _hasDraftCoverage = true;
  List<NominatimPlace> _suggestions = [];
  final List<CoverageArea> _savedCoverageAreas = [];

  CoverageArea get _coverageArea => CoverageArea(
    name: _coverageName ?? 'Coverage area ${_savedCoverageAreas.length + 1}',
    latitude: _coverageCenter.latitude,
    longitude: _coverageCenter.longitude,
    radiusKm: _radiusKm,
  );

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    final query = value.trim();
    if (query.length < 2) {
      setState(() {
        _isSearching = false;
        _suggestions = [];
      });
      return;
    }

    setState(() => _isSearching = true);
    _debounce = Timer(const Duration(milliseconds: 450), () async {
      final results = await CoverageSearch.searchPlaces(query);
      if (!mounted || _searchController.text.trim() != query) return;
      setState(() {
        _suggestions = results;
        _isSearching = false;
      });
    });
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _isLocating = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 50,
        ),
      );
      _setCoverageCenter(
        LatLng(position.latitude, position.longitude),
        label: 'Current location',
      );
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  void _selectSuggestion(NominatimPlace place) {
    _searchController.text = place.shortName;
    setState(() => _suggestions = []);
    _setCoverageCenter(LatLng(place.lat, place.lng), label: place.shortName);
  }

  void _setCoverageCenter(LatLng point, {String? label}) {
    setState(() {
      _coverageCenter = point;
      _coverageName = label ?? 'Dropped pin';
      _hasDraftCoverage = true;
    });
    _mapController.move(point, _zoomForRadius(_radiusKm));
  }

  double _zoomForRadius(double radiusKm) {
    if (radiusKm <= 2) return 14;
    if (radiusKm <= 5) return 13;
    if (radiusKm <= 12) return 12;
    if (radiusKm <= 25) return 11;
    return 10;
  }

  String _distanceFromCenter(LatLng point) {
    final km = _distance.as(LengthUnit.Kilometer, _coverageCenter, point);
    return '${km.toStringAsFixed(1)} km from center';
  }

  void _saveCoverageArea() {
    final area = _coverageArea;
    setState(() {
      _savedCoverageAreas.add(area);
      _coverageName = null;
      _hasDraftCoverage = false;
      _radiusKm = 3;
      _searchController.clear();
      _suggestions = [];
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${area.name} saved. Add another area or continue.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _removeCoverageArea(int index) {
    setState(() => _savedCoverageAreas.removeAt(index));
  }

  void _continue() {
    final coverageAreas = _savedCoverageAreas.isEmpty
        ? _hasDraftCoverage
              ? [_coverageArea]
              : <CoverageArea>[]
        : _savedCoverageAreas;
    if (coverageAreas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Save at least one coverage area before continuing.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final draft = widget.draft.copyWith(coverageAreas: coverageAreas);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ContactDetailsScreen(
          providerKind: widget.providerKind,
          draft: draft,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final panelColor = isDark ? AppTheme.navyMid : AppTheme.white;
    final borderColor = isDark ? AppTheme.navyLight : AppTheme.lightGray;
    final textColor = isDark ? AppTheme.offWhite : AppTheme.navy;

    return ProviderFlowShell(
      title: widget.providerKind.registrationTitle,
      icon: widget.providerKind.icon,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const StepProgressHeader(currentStep: 4),
          const SizedBox(height: 28),
          const ProviderSectionTitle(
            title: 'Coverage Areas',
            subtitle:
                'Pick your service center and set the radius customers can find you within.',
          ),
          const SizedBox(height: 22),
          TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            textInputAction: TextInputAction.search,
            style: GoogleFonts.urbanist(
              color: textColor,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              labelText: 'Search area, town, estate, or landmark',
              labelStyle: GoogleFonts.urbanist(
                color: isDark ? AppTheme.gray : AppTheme.darkGray,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _isSearching
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : null,
              filled: true,
              fillColor: panelColor,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 16,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppTheme.amber, width: 1.4),
              ),
            ),
          ),
          if (_suggestions.isNotEmpty) ...[
            const SizedBox(height: 10),
            DecoratedBox(
              decoration: BoxDecoration(
                color: panelColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                children: _suggestions.map((place) {
                  final point = LatLng(place.lat, place.lng);
                  return ListTile(
                    dense: true,
                    leading: const Icon(
                      Icons.location_on_outlined,
                      color: AppTheme.amber,
                    ),
                    title: Text(
                      place.shortName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        color: textColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    subtitle: Text(
                      '${_distanceFromCenter(point)} - ${place.displayName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.urbanist(
                        color: isDark ? AppTheme.gray : AppTheme.darkGray,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: () => _selectSuggestion(place),
                  );
                }).toList(),
              ),
            ),
          ],
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              height: 310,
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _coverageCenter,
                  initialZoom: _zoomForRadius(_radiusKm),
                  onTap: (_, point) =>
                      _setCoverageCenter(point, label: 'Dropped pin'),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.robinson.ona_net',
                  ),
                  CircleLayer(
                    circles: [
                      ..._savedCoverageAreas.map(
                        (area) => CircleMarker(
                          point: area.center,
                          radius: area.radiusKm * 1000,
                          useRadiusInMeter: true,
                          color: AppTheme.navy.withValues(alpha: 0.08),
                          borderColor: AppTheme.navy.withValues(alpha: 0.35),
                          borderStrokeWidth: 1.2,
                        ),
                      ),
                      if (_hasDraftCoverage)
                        CircleMarker(
                          point: _coverageCenter,
                          radius: _radiusKm * 1000,
                          useRadiusInMeter: true,
                          color: AppTheme.amber.withValues(alpha: 0.16),
                          borderColor: AppTheme.amber,
                          borderStrokeWidth: 2,
                        ),
                    ],
                  ),
                  MarkerLayer(
                    markers: [
                      ..._savedCoverageAreas.map(
                        (area) => Marker(
                          point: area.center,
                          width: 34,
                          height: 34,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppTheme.navy,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppTheme.white,
                                width: 2,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                '${_savedCoverageAreas.indexOf(area) + 1}',
                                style: GoogleFonts.plusJakartaSans(
                                  color: AppTheme.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (_hasDraftCoverage)
                        Marker(
                          point: _coverageCenter,
                          width: 48,
                          height: 48,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppTheme.amber,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppTheme.white,
                                width: 3,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.navy.withValues(alpha: 0.25),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.wifi_rounded,
                              color: AppTheme.white,
                              size: 24,
                            ),
                          ),
                        ),
                    ],
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: panelColor,
                        foregroundColor: textColor,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: _isLocating ? null : _useCurrentLocation,
                      icon: _isLocating
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.my_location_rounded, size: 18),
                      label: Text(
                        'Use current',
                        style: GoogleFonts.urbanist(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          DecoratedBox(
            decoration: BoxDecoration(
              color: panelColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderColor),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _coverageName ?? 'Pick another coverage area',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            color: textColor,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${_radiusKm.toStringAsFixed(0)} km',
                        style: GoogleFonts.plusJakartaSans(
                          color: AppTheme.amber,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Slider(
                    value: _radiusKm,
                    min: 1,
                    max: 50,
                    divisions: 49,
                    activeColor: AppTheme.amber,
                    label: '${_radiusKm.toStringAsFixed(0)} km',
                    onChanged: (value) {
                      setState(() {
                        _radiusKm = value;
                        _hasDraftCoverage = true;
                        _coverageName ??=
                            'Coverage area ${_savedCoverageAreas.length + 1}';
                      });
                      _mapController.move(
                        _coverageCenter,
                        _zoomForRadius(value),
                      );
                    },
                  ),
                  Text(
                    'Save this circle, then search or tap the map again to add another coverage area.',
                    style: GoogleFonts.urbanist(
                      color: isDark ? AppTheme.gray : AppTheme.darkGray,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.amber,
              side: const BorderSide(color: AppTheme.amber, width: 1.2),
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              textStyle: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            onPressed: _hasDraftCoverage ? _saveCoverageArea : null,
            icon: const Icon(Icons.add_location_alt_rounded, size: 20),
            label: const Text('Save This Area'),
          ),
          if (_savedCoverageAreas.isNotEmpty) ...[
            const SizedBox(height: 18),
            DecoratedBox(
              decoration: BoxDecoration(
                color: panelColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderColor),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Saved Areas (${_savedCoverageAreas.length})',
                      style: GoogleFonts.plusJakartaSans(
                        color: textColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ..._savedCoverageAreas.indexed.map((entry) {
                      final index = entry.$1;
                      final area = entry.$2;
                      return Padding(
                        padding: EdgeInsets.only(
                          bottom: index == _savedCoverageAreas.length - 1
                              ? 0
                              : 8,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: AppTheme.amber.withValues(alpha: 0.14),
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '${index + 1}',
                                style: GoogleFonts.plusJakartaSans(
                                  color: AppTheme.amber,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    area.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.plusJakartaSans(
                                      color: textColor,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${area.radiusKm.toStringAsFixed(0)} km radius',
                                    style: GoogleFonts.urbanist(
                                      color: isDark
                                          ? AppTheme.gray
                                          : AppTheme.darkGray,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => _removeCoverageArea(index),
                              icon: const Icon(Icons.delete_outline_rounded),
                              color: isDark ? AppTheme.gray : AppTheme.darkGray,
                              tooltip: 'Remove area',
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 42),
          ProviderPrimaryButton(label: 'Continue', onPressed: _continue),
          const SizedBox(height: 24),
          const SecureFooter(),
        ],
      ),
    );
  }
}
