import 'package:flutter/material.dart';
import 'package:ona_net/provider/account_details.dart';
import 'package:ona_net/provider/provider_registration_data.dart';
import 'package:ona_net/themes/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

class ProviderReg extends StatefulWidget {
  const ProviderReg({super.key});

  @override
  State<ProviderReg> createState() => _ProviderRegState();
}

class _ProviderRegState extends State<ProviderReg> {
  ProviderKind? selectedKind;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(vertical: 24.0),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 430),
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: 24),
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.navy.withValues(alpha: 0.5) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow:[
                    BoxShadow(
                        color:Colors.black.withValues(alpha: isDark? 0.25:0.08),
                      blurRadius: 28,
                      offset: Offset(0, 12)
                    ),

                  ],
                  border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
                ),
                child: Column(
                children: [
                  const HomeHeader(),
                  const SizedBox(height: 20),
                  Text(
                    "Provider Registration",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppTheme.offWhite : AppTheme.navy,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Fill in the details below to get started",
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  SizedBox(height: 20,),
                  ...providerKinds.map((kind){
                    return ProviderType(
                      key: ValueKey(kind),
                      isSelected: selectedKind == kind,
                      title: kind.title,
                      icon: kind.icon,
                      subtitle: kind.subtitle,
                      onTap: () {
                        setState(() {
                          selectedKind = kind;
                        });
                        Navigator.push(context, MaterialPageRoute(
                          builder: (context) => ProviderAccountDetails(providerKind: kind),
                        ));
                      },
                    );
                  }),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HomeHeader extends StatelessWidget {
  const HomeHeader({super.key});

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

class ProviderType extends StatelessWidget {
  const ProviderType({
    super.key,
    required this.isSelected,
    required this.title,
    this.onTap,
    required this.icon,
    required this.subtitle
  });

  final bool isSelected;
  final String title;
  final VoidCallback? onTap;
  final IconData icon;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
          duration: Duration(milliseconds: 180),
        margin: EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: isSelected ?
          AppTheme.amber.withValues(alpha: isDark ? 0.16:0.12)
              : isDark ? AppTheme.navyMid : AppTheme.white,

          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.amber : isDark ? AppTheme.navyLight : AppTheme.lightGray,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isDark ? [] : [
            BoxShadow(
              color: AppTheme.navy.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected ? AppTheme.amber : (isDark ? AppTheme.offWhite : AppTheme.navy),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: isDark ? AppTheme.offWhite : AppTheme.navy,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.urbanist(
                        fontSize: 12.5,
                        color: isDark ? Colors.white70 : Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                isSelected ? Icons.check_circle_rounded : Icons.chevron_right_rounded,
                color: isSelected ? AppTheme.amber : (isDark ? Colors.white24 : Colors.grey[400]),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}



