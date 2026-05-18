import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ona_net/themes/app_theme.dart';
import 'package:ona_net/themes/theme_provider.dart';
import 'package:provider/provider.dart';

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
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              SizedBox(height: 20),

              _HomeHeader(),
              SizedBox(height: 20),

              _LocationBar(),
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
              SizedBox(height: 20,),
              _ProviderCard(provider: {
                'name': 'Zuku Fiber',
                'initials': 'ZF',
                'color': 0xFF1B4F8A,
                'rating': 4.7,
                'reviews': '1,248',
                'price': '2,499',
                'speed': 25,
                'distance': 1.2,
                'verified': true,
              },),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          RichText(
            text: TextSpan(
              style: GoogleFonts.plusJakartaSans(
                fontSize: 34,
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
                color: AppTheme.navy,
                decoration: TextDecoration.none,
              ),
              children: [
                TextSpan(text: "Ona"),
                TextSpan(
                  text: "Net",
                  style: TextStyle(color: AppTheme.amber),
                ),
              ],
            ),
          ),
          SizedBox(height: 2),
          Text(
            "Find Better Internet near you",
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.navy,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }
}
class _LocationBar extends StatelessWidget {
  const _LocationBar({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14,vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.navyMid : AppTheme.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppTheme.navyLight : AppTheme.lightGray,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.location_on_outlined,
            color: AppTheme.amber,
            size: 18,
          ),
          SizedBox(width: 8,),
          Text(
            "Select Location",
            style: GoogleFonts.plusJakartaSans(
              color: isDark ? AppTheme.white : AppTheme.navy,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          Spacer(),
          Icon(
            Icons.keyboard_arrow_down_rounded,
            color: isDark ? AppTheme.lightGray : AppTheme.navy,
            size: 20,
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    TextEditingController locationController = TextEditingController();
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14,vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.navyMid : AppTheme.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppTheme.navyLight : AppTheme.lightGray,
        ),
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
                  color: isDark ? AppTheme.lightGray.withValues(alpha: 0.7) : AppTheme.navy.withValues(alpha: 0.5),
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
  const _FilterChips({super.key});

  @override
  State<_FilterChips> createState() => _FilterChipsState();
}

class _FilterChipsState extends State<_FilterChips> {
  int _selected = 0;
  final _filters = ["All","Budget","Fast","Verified","Fiber"];
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(_filters.length, (i) {
          final isSelected = _selected == i;
          return GestureDetector(
            onTap: () => setState(()=> _selected = i),
            child: Container(
              margin: EdgeInsets.only(right: 8),
              padding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.amber
                    : Theme.of(context).brightness == Brightness.dark
                    ? AppTheme.navyMid : AppTheme.white,
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
                      : Theme.of(context).brightness == Brightness.dark ? AppTheme.white : AppTheme.navy,
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
  final Map<String,dynamic> provider;
  const _ProviderCard({required this.provider});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(14),
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
        children: [
          Container(
            height: 52,
            width: 52,
            decoration: BoxDecoration(
              color: Color(provider['color']),
              borderRadius: BorderRadius.circular(40),
            ),
            child: Center(
              child: Text(
                provider['initials'],
                style: TextStyle(
                  color: AppTheme.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  provider['name'],
                  style:Theme.of(context).textTheme.titleSmall,
                ),
                if (provider['verified'])...[
                  SizedBox(width: 4,),
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
                SizedBox(height: 3,),
                Column(
                  children: [
                    Text('${provider['rating']}')
                    
                  ],

                )
              ],
            ),

          ),
        ],
      ),
    );
  }
}
