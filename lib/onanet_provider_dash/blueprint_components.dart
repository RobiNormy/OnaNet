import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ona_net/themes/app_theme.dart';

class OnaDashboardBrandHeader extends StatelessWidget {
  const OnaDashboardBrandHeader({
    super.key,
    required this.onMenu,
    required this.onNotifications,
    this.notificationCount = 0,
  });

  final VoidCallback onMenu;
  final VoidCallback onNotifications;
  final int notificationCount;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _HeaderCircle(
          tooltip: 'Open sidebar',
          icon: Icons.menu_rounded,
          onTap: onMenu,
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppTheme.amber,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.amber.withValues(alpha: .22),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.wifi_rounded,
                    color: AppTheme.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 9),
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(
                        text: TextSpan(
                          style: GoogleFonts.plusJakartaSans(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                          children: const [
                            TextSpan(text: 'Ona'),
                            TextSpan(
                              text: 'Net',
                              style: TextStyle(color: AppTheme.amber),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        'Provider dashboard',
                        softWrap: true,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Stack(
          clipBehavior: Clip.none,
          children: [
            _HeaderCircle(
              tooltip: 'Installation requests',
              icon: Icons.notifications_none_rounded,
              onTap: onNotifications,
            ),
            if (notificationCount > 0)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 18),
                  height: 18,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppTheme.amber,
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: AppTheme.white, width: 2),
                  ),
                  child: Text(
                    notificationCount > 9 ? '9+' : '$notificationCount',
                    style: const TextStyle(
                      color: AppTheme.white,
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    ),
  );
}

class OnaBlueprintHeader extends StatelessWidget {
  const OnaBlueprintHeader({
    super.key,
    required this.title,
    required this.onBack,
    required this.onMenu,
  });

  final String title;
  final VoidCallback onBack;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _HeaderCircle(
          tooltip: 'Back',
          icon: Icons.arrow_back_rounded,
          onTap: onBack,
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 12, 10, 0),
            child: Text(
              title,
              textAlign: TextAlign.center,
              softWrap: true,
              style: GoogleFonts.plusJakartaSans(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        _HeaderCircle(tooltip: 'Menu', icon: Icons.menu_rounded, onTap: onMenu),
      ],
    ),
  );
}

class _HeaderCircle extends StatelessWidget {
  const _HeaderCircle({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => IconButton(
    onPressed: onTap,
    tooltip: tooltip,
    icon: Icon(icon, size: 20),
    style: IconButton.styleFrom(
      fixedSize: const Size.square(44),
      foregroundColor: Theme.of(context).colorScheme.onSurface,
      backgroundColor: Theme.of(context).colorScheme.surface,
      side: BorderSide(color: Theme.of(context).colorScheme.outline),
      shape: const CircleBorder(),
    ),
  );
}

class OnaBlueprintCard extends StatelessWidget {
  const OnaBlueprintCard({
    super.key,
    required this.child,
    this.title,
    this.action,
    this.padding = const EdgeInsets.all(14),
  });

  final String? title;
  final Widget? action;
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: dark ? AppTheme.navyMid : AppTheme.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: dark ? AppTheme.navyLight : AppTheme.lightGray,
        ),
        boxShadow: [
          BoxShadow(
            color: (dark ? Colors.black : AppTheme.navy).withValues(
              alpha: dark ? .15 : .045,
            ),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    title!,
                    softWrap: true,
                    style: GoogleFonts.plusJakartaSans(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (action != null) ...[const SizedBox(width: 8), action!],
              ],
            ),
            const SizedBox(height: 12),
          ],
          child,
        ],
      ),
    );
  }
}

class OnaSegmentedTabs extends StatelessWidget {
  const OnaSegmentedTabs({
    super.key,
    required this.labels,
    required this.selected,
    required this.onSelected,
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => Row(
    children: labels.indexed.map((entry) {
      final active = entry.$1 == selected;
      return Expanded(
        child: InkWell(
          onTap: () => onSelected(entry.$1),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 9),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  width: 2,
                  color: active ? AppTheme.amber : Colors.transparent,
                ),
              ),
            ),
            child: Text(
              entry.$2,
              textAlign: TextAlign.center,
              softWrap: true,
              style: TextStyle(
                color: active
                    ? Theme.of(context).colorScheme.onSurface
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 11,
                fontWeight: active ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
        ),
      );
    }).toList(),
  );
}

class OnaKpiTile extends StatelessWidget {
  const OnaKpiTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.helper,
  });

  final String label;
  final String value;
  final IconData icon;
  final String? helper;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppTheme.amber),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              label,
              softWrap: true,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Text(
        value,
        softWrap: true,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 23,
          fontWeight: FontWeight.w800,
        ),
      ),
      if (helper != null) ...[
        const SizedBox(height: 3),
        Text(
          helper!,
          softWrap: true,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 10,
          ),
        ),
      ],
    ],
  );
}

class OnaRankedBar extends StatelessWidget {
  const OnaRankedBar({
    super.key,
    required this.label,
    required this.valueLabel,
    required this.fraction,
    this.icon,
    this.color = AppTheme.amber,
  });

  final String label;
  final String valueLabel;
  final double fraction;
  final IconData? icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      label,
                      softWrap: true,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    valueLabel,
                    softWrap: true,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: fraction.clamp(0, 1),
                  minHeight: 5,
                  backgroundColor: color.withValues(alpha: .10),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class OnaSemiGauge extends StatelessWidget {
  const OnaSemiGauge({
    super.key,
    required this.value,
    required this.centerLabel,
    required this.centerValue,
  });

  final double value;
  final String centerLabel;
  final String centerValue;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 118,
    child: CustomPaint(
      painter: _SemiGaugePainter(value),
      child: Align(
        alignment: const Alignment(0, .72),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(centerLabel, style: const TextStyle(fontSize: 10)),
            Text(
              centerValue,
              softWrap: true,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    ),
  );
}

class _SemiGaugePainter extends CustomPainter {
  const _SemiGaugePainter(this.value);
  final double value;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height - 10);
    final radius = math.min(size.width / 2 - 8, size.height - 18);
    final rect = Rect.fromCircle(center: center, radius: radius);
    final track = Paint()
      ..color = AppTheme.lightGray
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 12;
    final progress = Paint()
      ..shader = const LinearGradient(
        colors: [AppTheme.amberDark, AppTheme.amber, AppTheme.navyLight],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 12;
    canvas.drawArc(rect, math.pi, math.pi, false, track);
    canvas.drawArc(rect, math.pi, math.pi * value.clamp(0, 1), false, progress);
  }

  @override
  bool shouldRepaint(covariant _SemiGaugePainter oldDelegate) =>
      oldDelegate.value != value;
}

class OnaGroupedBarChart extends StatelessWidget {
  const OnaGroupedBarChart({
    super.key,
    required this.values,
    required this.labels,
    this.secondaryValues = const [],
  });

  final List<double> values;
  final List<double> secondaryValues;
  final List<String> labels;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 190,
    child: CustomPaint(
      painter: _GroupedBarPainter(values, secondaryValues, labels),
      child: const SizedBox.expand(),
    ),
  );
}

class _GroupedBarPainter extends CustomPainter {
  const _GroupedBarPainter(this.values, this.secondaryValues, this.labels);

  final List<double> values;
  final List<double> secondaryValues;
  final List<String> labels;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    const bottom = 24.0;
    const top = 12.0;
    final chartHeight = size.height - bottom - top;
    final maxValue = [...values, ...secondaryValues].fold<double>(1, math.max);
    final groupWidth = size.width / values.length;
    final barWidth = math.min(20.0, groupWidth * .27);
    final grid = Paint()
      ..color = AppTheme.lightGray
      ..strokeWidth = 1;
    for (var i = 0; i < 4; i++) {
      final y = top + (chartHeight * i / 3);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    for (var i = 0; i < values.length; i++) {
      final x = groupWidth * i + groupWidth / 2;
      _bar(
        canvas,
        x - (secondaryValues.isEmpty ? barWidth / 2 : barWidth),
        size.height - bottom,
        barWidth,
        chartHeight * values[i] / maxValue,
        AppTheme.amber,
      );
      if (i < secondaryValues.length) {
        _bar(
          canvas,
          x + 2,
          size.height - bottom,
          barWidth,
          chartHeight * secondaryValues[i] / maxValue,
          AppTheme.navyLight,
        );
      }
      if (i < labels.length) {
        final painter = TextPainter(
          text: TextSpan(
            text: labels[i],
            style: const TextStyle(color: AppTheme.gray, fontSize: 9),
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: groupWidth - 3);
        painter.paint(
          canvas,
          Offset(x - painter.width / 2, size.height - bottom + 7),
        );
      }
    }
  }

  void _bar(
    Canvas canvas,
    double x,
    double bottom,
    double width,
    double height,
    Color color,
  ) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x, bottom - height, width, height),
        const Radius.circular(6),
      ),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _GroupedBarPainter oldDelegate) =>
      oldDelegate.values != values ||
      oldDelegate.secondaryValues != secondaryValues ||
      oldDelegate.labels != labels;
}
