import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'app_colors.dart';

class CompassPainter extends CustomPainter {
  final double heading;
  final double needleAngle;

  const CompassPainter({required this.heading, required this.needleAngle});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;

    canvas.drawCircle(Offset(cx, cy), r, Paint()..color = AppColors.background);
    canvas.drawCircle(
      Offset(cx, cy),
      r - 1,
      Paint()
        ..color = AppColors.border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    for (int i = 0; i < 72; i++) {
      final angle = (i * 5 - heading) * math.pi / 180;
      final isMain = i % 18 == 0;
      final isMid = i % 9 == 0;
      final inner = isMain ? r - 28 : (isMid ? r - 20 : r - 14);
      canvas.drawLine(
        Offset(cx + inner * math.sin(angle), cy - inner * math.cos(angle)),
        Offset(cx + (r - 8) * math.sin(angle), cy - (r - 8) * math.cos(angle)),
        Paint()
          ..color = isMain ? AppColors.textSecondary : AppColors.border
          ..strokeWidth = isMain ? 2 : 1,
      );
    }

    final dirs = ['U', 'T', 'S', 'B'];
    final dirDeg = [0.0, 90.0, 180.0, 270.0];
    for (int i = 0; i < dirs.length; i++) {
      final angle = (dirDeg[i] - heading) * math.pi / 180;
      final dx = cx + (r - 22) * math.sin(angle);
      final dy = cy - (r - 22) * math.cos(angle);
      final tp = TextPainter(
        text: TextSpan(
          text: dirs[i],
          style: TextStyle(
            color: i == 0 ? AppColors.danger : AppColors.textSecondary,
            fontSize: i == 0 ? 14 : 11,
            fontWeight: i == 0 ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(dx - tp.width / 2, dy - tp.height / 2));
    }

    canvas.drawCircle(Offset(cx, cy), r * 0.55, Paint()..color = Colors.white);
    canvas.drawCircle(
      Offset(cx, cy),
      r * 0.55,
      Paint()
        ..color = AppColors.border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    _drawNeedle(canvas, cx, cy, r);

    canvas.drawCircle(Offset(cx, cy), 9, Paint()..color = AppColors.qiblaGold);
    canvas.drawCircle(
      Offset(cx, cy),
      9,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  void _drawNeedle(Canvas canvas, double cx, double cy, double r) {
    final needleLen = r * 0.46;
    const halfW = 9.0;
    final perp = needleAngle + math.pi / 2;

    final tipX = cx + needleLen * math.sin(needleAngle);
    final tipY = cy - needleLen * math.cos(needleAngle);
    final tailX = cx - needleLen * 0.32 * math.sin(needleAngle);
    final tailY = cy + needleLen * 0.32 * math.cos(needleAngle);
    final lx = cx + halfW * math.sin(perp);
    final ly = cy - halfW * math.cos(perp);
    final rx = cx - halfW * math.sin(perp);
    final ry = cy + halfW * math.cos(perp);

    canvas.drawPath(
      Path()
        ..moveTo(tipX, tipY)
        ..lineTo(lx, ly)
        ..lineTo(rx, ry)
        ..close(),
      Paint()..color = AppColors.qiblaGold,
    );
    canvas.drawPath(
      Path()
        ..moveTo(tailX, tailY)
        ..lineTo(lx, ly)
        ..lineTo(rx, ry)
        ..close(),
      Paint()..color = const Color(0xFFCBD5E1),
    );

    final outline = Paint()
      ..color = Colors.white.withOpacity(0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawPath(
      Path()
        ..moveTo(tipX, tipY)
        ..lineTo(lx, ly)
        ..lineTo(rx, ry)
        ..close(),
      outline,
    );
    canvas.drawPath(
      Path()
        ..moveTo(tailX, tailY)
        ..lineTo(lx, ly)
        ..lineTo(rx, ry)
        ..close(),
      outline,
    );

    final tp = TextPainter(
      text: const TextSpan(text: '🕋', style: TextStyle(fontSize: 13)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(tipX - tp.width / 2, tipY - tp.height / 2 - 4));
  }

  @override
  bool shouldRepaint(CompassPainter old) =>
      old.heading != heading || old.needleAngle != needleAngle;
}
