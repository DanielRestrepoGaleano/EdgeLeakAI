import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../config/themes/app_theme.dart';

/// Un widget nativo impresionante que dibuja olas de agua matemáticamente
class WaterWaveWidget extends StatefulWidget {
  final String modo;
  
  const WaterWaveWidget({super.key, required this.modo});

  @override
  State<WaterWaveWidget> createState() => _WaterWaveWidgetState();
}

class _WaterWaveWidgetState extends State<WaterWaveWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this, 
      duration: const Duration(milliseconds: 1500)
    )..repeat();
  }

  @override
  void didUpdateWidget(covariant WaterWaveWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Si hay fuga, el agua se mueve el doble de rápido
    if (widget.modo == 'Fuga') {
      _controller.duration = const Duration(milliseconds: 700);
      _controller.repeat();
    } else if (widget.modo == 'Anomalia') {
      _controller.duration = const Duration(milliseconds: 1000);
      _controller.repeat();
    } else {
      _controller.duration = const Duration(milliseconds: 2000);
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: WavePainter(
            animationValue: _controller.value,
            modo: widget.modo,
          ),
          child: const SizedBox(
            height: 120, // Altura de la "cajita" de agua
            width: double.infinity,
          ),
        );
      },
    );
  }
}

class WavePainter extends CustomPainter {
  final double animationValue;
  final String modo;

  WavePainter({required this.animationValue, required this.modo});

  @override
  void paint(Canvas canvas, Size size) {
    // Configuraciones dinámicas según la falla
    double fillPercentage;
    Color waveColor;
    double amplitude;

    if (modo == 'Fuga') {
      fillPercentage = 0.85; // Casi lleno
      waveColor = AppTheme.criticalColor.withOpacity(0.7);
      amplitude = 12.0; // Olas muy agresivas
    } else if (modo == 'Anomalia') {
      fillPercentage = 0.55; // Medio lleno
      waveColor = AppTheme.warningColor.withOpacity(0.8);
      amplitude = 7.0; // Olas medias
    } else {
      fillPercentage = 0.25; // Nivel bajo normal
      waveColor = AppTheme.primaryColor.withOpacity(0.6); // Azul agüita
      amplitude = 4.0; // Olas calmadas
    }

    final path = Path();
    final waterHeight = size.height * (1 - fillPercentage);

    path.moveTo(0, size.height);
    path.lineTo(0, waterHeight);

    // Dibuja la onda Senoidal matemáticamente
    for (double i = 0; i <= size.width; i++) {
      double waveY = math.sin((i / size.width * 2 * math.pi) + (animationValue * 2 * math.pi)) * amplitude;
      path.lineTo(i, waterHeight + waveY);
    }

    path.lineTo(size.width, size.height);
    path.close();

    // Dibujamos el agua
    canvas.drawPath(path, Paint()..color = waveColor);
    
    // Una segunda ola más clara por detrás para dar efecto 3D
    final path2 = Path();
    path2.moveTo(0, size.height);
    path2.lineTo(0, waterHeight);

    for (double i = 0; i <= size.width; i++) {
      double waveY2 = math.sin((i / size.width * 2 * math.pi) + ((animationValue + 0.5) * 2 * math.pi)) * (amplitude * 0.8);
      path2.lineTo(i, waterHeight + waveY2);
    }
    path2.lineTo(size.width, size.height);
    path2.close();

    canvas.drawPath(path2, Paint()..color = waveColor.withOpacity(0.4));
  }

  @override
  bool shouldRepaint(covariant WavePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue || oldDelegate.modo != modo;
  }
}
