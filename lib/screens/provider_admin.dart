import 'package:flutter/material.dart';
import 'package:ona_net/themes/app_theme.dart';

class ProviderAdminScreen extends StatelessWidget {
  const ProviderAdminScreen({super.key});

  static String id = "main";

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final headerTextColor = colorScheme.onPrimary;
    final logoAccentColor = isDark ? AppTheme.navy : colorScheme.secondary;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(30),
                    bottomRight: Radius.circular(30),
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -40,
                      top: -40,
                      child: _HeaderRing(size: 140),
                    ),
                    Positioned(
                      right: 10,
                      top: 30,
                      child: _HeaderRing(size: 70),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Icon(Icons.wifi, color: logoAccentColor, size: 12),
                            const SizedBox(width: 6),
                            RichText(
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: "Ona",
                                    style: theme.textTheme.headlineMedium
                                        ?.copyWith(
                                          color: headerTextColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 20,
                                        ),
                                  ),
                                  TextSpan(
                                    text: 'Net',
                                    style: TextStyle(
                                      color: logoAccentColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 20,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 28),
                        Text(
                          "What brings you\nto OnaNet",
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: headerTextColor,
                            fontWeight: FontWeight.bold,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 28),
                        Text(
                          "Join us today and be part of our journey",
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: headerTextColor.withValues(alpha: 0.8),
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderRing extends StatelessWidget {
  const _HeaderRing({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.white.withValues(alpha: 0.08)),
      ),
    );
  }
}
