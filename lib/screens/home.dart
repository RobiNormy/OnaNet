import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ona_net/auth/auth_service.dart';
import 'package:ona_net/navigation/screen_ids.dart';
import 'package:ona_net/screens/profile.dart';
import 'package:ona_net/screens/provider_detail.dart';
import 'package:ona_net/screens/saved.dart';
import 'package:ona_net/screens/search.dart';
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
  bool _loadingProviders = true;
  String? _providersError;
  List<Map<String, dynamic>> _providers = [];

  @override
  void initState() {
    super.initState();
    _fetchLocation();
    _fetchProviders();
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

  Future<void> _fetchProviders({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _loadingProviders = true;
        _providersError = null;
      });
    }

    try {
      final providers = await AuthService().getPublicProviders();
      if (!mounted) return;
      setState(() {
        _providers = providers;
        _providersError = null;
        _loadingProviders = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _providersError = error.toString();
        _loadingProviders = false;
      });
    }
  }

  Future<void> _refreshHome() async {
    await Future.wait([_fetchLocation(), _fetchProviders(showLoading: false)]);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppTheme.amber,
          backgroundColor: isDark ? AppTheme.navyMid : AppTheme.white,
          onRefresh: _refreshHome,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                SizedBox(height: 20),
                HomeHeader(area: _area),
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
                SizedBox(height: 12),
                _ProvidersList(
                  providers: _providers,
                  isLoading: _loadingProviders,
                  error: _providersError,
                  onRetry: _fetchProviders,
                ),
                SizedBox(height: 110),
              ],
            ),
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

class _ProvidersList extends StatelessWidget {
  const _ProvidersList({
    required this.providers,
    required this.isLoading,
    required this.error,
    required this.onRetry,
  });

  final List<Map<String, dynamic>> providers;
  final bool isLoading;
  final String? error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 28),
        child: Center(child: CircularProgressIndicator(color: AppTheme.amber)),
      );
    }

    if (error != null) {
      return _ProviderStateMessage(
        icon: Icons.cloud_off_rounded,
        title: 'Could not load providers',
        message: error!,
        actionLabel: 'Try Again',
        onAction: onRetry,
      );
    }

    if (providers.isEmpty) {
      return const _ProviderStateMessage(
        icon: Icons.wifi_find_rounded,
        title: 'No providers yet',
        message: 'Pull down to check again after adding a network.',
      );
    }

    return Column(
      children: providers
          .map((provider) => _ProviderCard(provider: provider))
          .toList(),
    );
  }
}

class _ProviderStateMessage extends StatelessWidget {
  const _ProviderStateMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.navyMid : AppTheme.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppTheme.navyLight : AppTheme.lightGray,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppTheme.amber, size: 28),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              color: isDark ? AppTheme.white : AppTheme.navy,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.gray,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: onAction,
              child: Text(
                actionLabel!,
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.amber,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ],
      ),
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
              Material(
                color: Colors.transparent,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.my_location_rounded,
                    color: AppTheme.amber,
                  ),
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

class HomeHeader extends StatelessWidget {
  final String? area;
  const HomeHeader({super.key, required this.area});

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

class _SearchBar extends StatefulWidget {
  const _SearchBar();

  @override
  State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
              controller: _searchController,
              onSubmitted: (value) {
                print("Searching for: $value");
              },
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
          _ProviderLogoAvatar(provider: provider, size: 44),
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
                            builder: (context) =>
                                ProviderDetailScreen(provider: provider),
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

class _ProviderLogoAvatar extends StatelessWidget {
  const _ProviderLogoAvatar({required this.provider, required this.size});

  final Map<String, dynamic> provider;
  final double size;

  @override
  Widget build(BuildContext context) {
    final logoUrl = (provider['logoUrl'] ?? provider['logo_url'])?.toString();
    final logoScale =
        _asDouble(provider['logoScale'] ?? provider['logo_display_size']) ??
        1.0;
    final logoOffset = Offset(
      _asDouble(provider['logoOffsetX'] ?? provider['logo_offset_x']) ?? 0,
      _asDouble(provider['logoOffsetY'] ?? provider['logo_offset_y']) ?? 0,
    );
    final displayScale = logoScale.clamp(1.0, 3.0);
    final displayOffset = Offset(
      logoOffset.dx * size / 280,
      logoOffset.dy * size / 280,
    );
    final fallbackColor = Color(provider['color'] as int);
    final initials = provider['initials']?.toString() ?? '';
    final hasLogo = logoUrl != null && logoUrl.trim().isNotEmpty;

    return Container(
      height: size,
      width: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: fallbackColor, shape: BoxShape.circle),
      clipBehavior: Clip.antiAlias,
      child: hasLogo
          ? Transform(
              transform: Matrix4.identity()
                ..translate(displayOffset.dx, displayOffset.dy)
                ..scale(displayScale),
              child: Image.network(
                logoUrl,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    _ProviderInitials(initials: initials, size: size),
              ),
            )
          : _ProviderInitials(initials: initials, size: size),
    );
  }

  double? _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }
}

class _ProviderInitials extends StatelessWidget {
  const _ProviderInitials({required this.initials, required this.size});

  final String initials;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Text(
      initials,
      style: TextStyle(
        color: AppTheme.white,
        fontSize: size * 0.36,
        fontWeight: FontWeight.w800,
      ),
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
