import 'package:flutter/material.dart';
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

              // _LocationBar(),
              SizedBox(height: 20),

              // _SearchBar(),
              SizedBox(height: 20),

              Row(
                children: [
                  Text(
                    "Providers Near You",
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  SizedBox(width: 8),

                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.navy.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      "12",
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppTheme.amber,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: "Ona",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: isDark ? AppTheme.offWhite : AppTheme.navy,
                  letterSpacing: -0.5,
                ),
              ),
              TextSpan(
                text: "Net",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.amber,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
        Text(
          "Better Internet",
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: AppTheme.gray),
        ),
        Stack(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: isDark ? AppTheme.navyMid : AppTheme.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? AppTheme.navyLight : AppTheme.lightGray,
                ),
              ),
              child: Icon(
                Icons.notifications_outlined,
                color: isDark ? AppTheme.offWhite : AppTheme.navy,
                size: 22,
              ),
            ),
            Positioned(
              right: 8,
              left: 8,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: AppTheme.amber),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
