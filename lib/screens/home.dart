import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ona_net/navigation/screen_ids.dart';
import 'package:ona_net/screens/profile.dart';
import 'package:ona_net/screens/provider_detail.dart';
import 'package:ona_net/screens/saved.dart';
import 'package:ona_net/screens/search.dart';
import 'package:ona_net/screens/sign_up.dart';
import 'package:ona_net/themes/app_theme.dart';
import 'package:ona_net/themes/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:ona_net/utils/location.dart';

class OnaNet extends StatelessWidget {
  const OnaNet({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    return MaterialApp(
      title: 'Ona Net',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeProvider.themeMode,
      home: const MainWrapper(),
    );
  }
}

class MainWrapper extends StatefulWidget {
  const MainWrapper({super.key});

  @override
  State<MainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends State<MainWrapper> {
  ScreenId _currentScreen = ScreenId.home;

  late final Map<ScreenId, Widget> _screens = {
    ScreenId.home: const HomeScreen(),
    ScreenId.search: const SearchScreen(),
    ScreenId.saved: const SavedScreen(),
    ScreenId.profile: const Profile(),

  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: IndexedStack(
        index: _currentScreen.tabIndex,
        children: ScreenIds.tabs.map((id) => _screens[id]!).toList(),
      ),
      bottomNavigationBar: _BottomNav(
        current: _currentScreen,
        onTap: (screenId) {
          if (screenId == _currentScreen) return;
          setState(() => _currentScreen = screenId);
        },
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _area;
  bool _loadingLocation = true;

  @override
  void initState() {
    super.initState();
    _fetchLocation();
  }

  Future<void> _fetchLocation() async {
    setState(() => _loadingLocation = true);
    final area = await Location.getCurrentArea().timeout(
      Duration(seconds: 10),
      onTimeout: () => null,
    );
    if (mounted) {
      setState(() {
        _area = area ?? _area;
        _loadingLocation = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              SizedBox(height: 20),

              // _TopBar(
              //   area: _area,
              //   isLoading: _loadingLocation,
              //   onLocationTap: _showLocation,
              // ),
              _HomeHeader(area: _area),
              SizedBox(height: 20),

              _LocationBar(
                label: _area ?? "Select Location",
                onLocationTap: _showLocation,
                isLoading: _loadingLocation,
              ),
              SizedBox(height: 20),

              _SearchBar(),
              SizedBox(height: 20),

              _FilterChips(),
              SizedBox(height: 20),

              Row(
                children: [
                  Text(
                    "Top Providers",
                    style: GoogleFonts.plusJakartaSans(
                      color: isDark ? AppTheme.white : AppTheme.navy,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),
              _ProviderCard(
                provider: {
                  'name': 'Zuku Fiber',
                  'initials': 'ZF',
                  'color': 0xFF1B4F8A,
                  'rating': 4.7,
                  'reviews': '1,248',
                  'price': '2,499',
                  'speed': 25,
                  'distance': 1.2,
                  'verified': true,
                },
              ),
              _ProviderCard(
                provider: {
                  'name': 'Faiba Home',
                  'initials': 'FH',
                  'color': 0xFF16A34A,
                  'rating': 4.5,
                  'reviews': '892',
                  'price': '1,899',
                  'speed': 20,
                  'distance': 1.6,
                  'verified': false,
                },
              ),
              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _showLocation() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return _LocationPickerSheet(
          isDark: isDark,
          currentArea: _area,
          onUseCurrent: () {
            Navigator.pop(sheetContext);
            _fetchLocation();
          },
          onSelect: (area) {
            Navigator.pop(sheetContext);
            setState(() => _area = area);
          },
        );
      },
    );
  }
}

class _LocationPickerSheet extends StatefulWidget {
  final bool isDark;
  final String? currentArea;
  final VoidCallback onUseCurrent;
  final ValueChanged<String> onSelect;

  const _LocationPickerSheet({
    required this.isDark,
    required this.currentArea,
    required this.onUseCurrent,
    required this.onSelect,
  });

  @override
  State<_LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<_LocationPickerSheet> {
  final _controller = TextEditingController();
  Timer? _debounce;
  bool _isSearching = false;
  List<LocationSuggestion> _suggestions = [];

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
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
    _debounce = Timer(Duration(milliseconds: 450), () async {
      final results = await Location.searchAreas(query);
      if (!mounted || _controller.text.trim() != query) return;
      setState(() {
        _suggestions = results;
        _isSearching = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Container(
          margin: EdgeInsets.all(16),
          padding: EdgeInsets.fromLTRB(16, 10, 16, 16),
          decoration: BoxDecoration(
            color: widget.isDark ? AppTheme.navyMid : AppTheme.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: widget.isDark ? AppTheme.navyLight : AppTheme.lightGray,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.gray.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              SizedBox(height: 14),
              TextField(
                controller: _controller,
                onChanged: _onQueryChanged,
                autofocus: true,
                style: GoogleFonts.plusJakartaSans(
                  color: widget.isDark ? AppTheme.white : AppTheme.navy,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  hintText: "Type your area or estate",
                  hintStyle: GoogleFonts.plusJakartaSans(
                    color: AppTheme.gray,
                    fontSize: 13,
                  ),
                  prefixIcon: Icon(Icons.search_rounded, color: AppTheme.amber),
                  filled: true,
                  fillColor: widget.isDark ? AppTheme.navy : AppTheme.offWhite,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: widget.isDark
                          ? AppTheme.navyLight
                          : AppTheme.lightGray,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: widget.isDark
                          ? AppTheme.navyLight
                          : AppTheme.lightGray,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppTheme.amber),
                  ),
                ),
              ),
              SizedBox(height: 10),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.my_location_rounded, color: AppTheme.amber),
                title: Text(
                  "Use current location",
                  style: GoogleFonts.plusJakartaSans(
                    color: widget.isDark ? AppTheme.white : AppTheme.navy,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  widget.currentArea ?? "Find providers near you",
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.gray,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onTap: widget.onUseCurrent,
              ),
              if (_isSearching)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.amber,
                  ),
                )
              else if (_controller.text.trim().length >= 2 &&
                  _suggestions.isEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    "No locations found",
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.gray,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              else
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: 260),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _suggestions.length,
                    separatorBuilder: (_, _) => Divider(
                      height: 1,
                      color: widget.isDark
                          ? AppTheme.navyLight
                          : AppTheme.lightGray,
                    ),
                    itemBuilder: (context, index) {
                      final suggestion = _suggestions[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          Icons.location_on_outlined,
                          color: AppTheme.gray,
                        ),
                        title: Text(
                          suggestion.title,
                          style: GoogleFonts.plusJakartaSans(
                            color: widget.isDark
                                ? AppTheme.white
                                : AppTheme.navy,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: suggestion.subtitle.isEmpty
                            ? null
                            : Text(
                                suggestion.subtitle,
                                style: GoogleFonts.plusJakartaSans(
                                  color: AppTheme.gray,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                        onTap: () => widget.onSelect(suggestion.displayName),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  final String? area;
  const _HomeHeader({required this.area});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Stack(
                  alignment: Alignment.topCenter,
                  clipBehavior: Clip.none,
                  children: [
                    RichText(
                      text: TextSpan(
                        text: "O",
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 24,
                          color: isDark ? AppTheme.offWhite : AppTheme.navy,
                          letterSpacing: -.5,
                          fontWeight: FontWeight.bold,
                          height: 1,
                        ),
                      ),
                    ),
                    Positioned(
                      top: -35,
                      bottom: -1,
                      child: Icon(
                        Icons.wifi_rounded,
                        color: AppTheme.amber,
                        size: 30,
                      ),
                    ),
                  ],
                ),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: "na",
                        style: GoogleFonts.urbanist(
                          fontSize: 24,
                          color: isDark ? AppTheme.offWhite : AppTheme.navy,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -.5,
                          height: 1,
                        ),
                      ),
                      TextSpan(
                        text: "Net",
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.amber,
                          letterSpacing: -.5,
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _LocationBar extends StatelessWidget {
  final String label;
  final VoidCallback onLocationTap;
  final bool isLoading;
  const _LocationBar({
    required this.label,
    required this.onLocationTap,
    required this.isLoading,
  });
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onLocationTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.navyMid : AppTheme.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? AppTheme.navyLight : AppTheme.lightGray,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.location_on_outlined, color: AppTheme.amber, size: 18),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                isLoading ? "Finding location..." : label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  color: isDark ? AppTheme.white : AppTheme.navy,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (isLoading) ...[
              SizedBox(width: 8),
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.amber,
                ),
              ),
            ],
            Spacer(),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              color: isDark ? AppTheme.lightGray : AppTheme.navy,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    TextEditingController locationController = TextEditingController();
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.navyMid : AppTheme.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppTheme.navyLight : AppTheme.lightGray,
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: AppTheme.navy.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
      ),
      child: Row(
        children: [
          Icon(
            Icons.search_rounded,
            color: isDark ? AppTheme.lightGray : AppTheme.navy,
            size: 20,
          ),
          SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: locationController,
              decoration: InputDecoration(
                hintText: "Search providers near you...",
                hintStyle: GoogleFonts.plusJakartaSans(
                  color: isDark
                      ? AppTheme.lightGray.withValues(alpha: 0.7)
                      : AppTheme.navy.withValues(alpha: 0.5),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChips extends StatefulWidget {
  const _FilterChips();

  @override
  State<_FilterChips> createState() => _FilterChipsState();
}

class _FilterChipsState extends State<_FilterChips> {
  int _selected = 0;
  final _filters = ["All", "Budget", "Fast", "Verified", "Fiber"];
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(_filters.length, (i) {
          final isSelected = _selected == i;
          return GestureDetector(
            onTap: () => setState(() => _selected = i),
            child: Container(
              margin: EdgeInsets.only(right: 8),
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.amber
                    : Theme.of(context).brightness == Brightness.dark
                    ? AppTheme.navyMid
                    : AppTheme.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? AppTheme.amber : AppTheme.lightGray,
                ),
              ),
              child: Text(
                _filters[i],
                style: GoogleFonts.plusJakartaSans(
                  color: isSelected
                      ? AppTheme.navy
                      : Theme.of(context).brightness == Brightness.dark
                      ? AppTheme.white
                      : AppTheme.navy,
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _ProviderCard extends StatelessWidget {
  final Map<String, dynamic> provider;
  const _ProviderCard({required this.provider});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.navyMid : AppTheme.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppTheme.navyLight : AppTheme.lightGray,
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              color: Color(provider['color']),
              borderRadius: BorderRadius.circular(40),
            ),
            child: Center(
              child: Text(
                provider['initials'],
                style: TextStyle(
                  color: AppTheme.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        provider['name'],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    if (provider['verified']) ...[
                      SizedBox(width: 5),
                      Container(
                        padding: EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: AppTheme.green,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.check,
                          color: AppTheme.white,
                          size: 9,
                        ),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.star_rounded, color: AppTheme.amber, size: 14),
                    SizedBox(width: 3),
                    Text(
                      '${provider['rating']}',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        '(${provider['reviews']} reviews)',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(
                          context,
                        ).textTheme.labelMedium?.copyWith(color: AppTheme.gray),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 11),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            flex: 6,
                            child: _metaItem(
                              context,
                              label: 'From',
                              value: 'KES ${provider['price']}/mo',
                            ),
                          ),
                          SizedBox(width: 4),
                          Expanded(
                            flex: 4,
                            child: _metaItem(
                              context,
                              label: 'Up to',
                              value: '${provider['speed']}Mbps',
                            ),
                          ),
                          SizedBox(width: 4),
                          Expanded(flex: 5, child: _distanceItem(context)),
                        ],
                      ),
                    ),
                    SizedBox(width: 6),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ProviderDetailScreen(provider: provider),
                          ),
                        );
                      },
                      child: Container(
                        height: 30,
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.amber,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          "View Deal",
                          maxLines: 1,
                          style: TextStyle(
                            color: AppTheme.navy,
                            fontWeight: FontWeight.w800,
                            fontSize: 9,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _metaItem(
    BuildContext context, {
    required String label,
    required String value,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: AppTheme.gray, fontSize: 7),
        ),
        SizedBox(height: 2),
        Text(
          value,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 9,
            color: isDark ? AppTheme.offWhite : AppTheme.navy,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _distanceItem(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Distance',
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: AppTheme.gray, fontSize: 7),
        ),
        SizedBox(height: 2),
        Row(
          children: [
            Icon(Icons.location_on_outlined, color: AppTheme.gray, size: 10),
            SizedBox(width: 2),
            Expanded(
              child: Text(
                "${provider['distance']}km away",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppTheme.gray,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _BottomNav extends StatelessWidget {
  final ScreenId current;
  final ValueChanged<ScreenId> onTap;
  const _BottomNav({required this.current, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Theme(
      data: Theme.of(context).copyWith(
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        splashFactory: NoSplash.splashFactory,
      ),
      child: BottomNavigationBar(
        currentIndex: current.tabIndex,
        onTap: (index) => onTap(ScreenIds.fromIndex(index)),
        type: BottomNavigationBarType.fixed,
        backgroundColor: isDark ? AppTheme.navyMid : AppTheme.white,
        elevation: 0,
        enableFeedback: false,
        selectedItemColor: AppTheme.amber,
        unselectedItemColor: AppTheme.gray,
        selectedLabelStyle: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        items: ScreenIds.tabs
            .map(
              (screenId) => BottomNavigationBarItem(
                icon: Icon(screenId.icon),
                label: screenId.label,
              ),
            )
            .toList(),
      ),
    );
  }
}
