import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart'; // PAQUETE NUEVO
import '../../config/themes/app_theme.dart';

/// Un widget nativo impresionante que dibuja olas de agua matemáticamente
/// y reacciona a la gravedad/acelerómetro del dispositivo.
class WaterWaveWidget extends StatefulWidget {
  final String modo;

  const WaterWaveWidget({super.key, required this.modo});

  @override
  State<WaterWaveWidget> createState() => _WaterWaveWidgetState();
}

class _WaterWaveWidgetState extends State<WaterWaveWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;

  // Variables para guardar la inclinación del teléfono
  double _tiltX = 0.0; // Inclinación lateral
  double _tiltY = 0.0; // Inclinación hacia adelante/atrás

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    // Escuchar el acelerómetro
    _accelerometerSubscription = accelerometerEventStream().listen((
      AccelerometerEvent event,
    ) {
      // Usamos un pequeño factor de suavizado para que el agua no tiemble bruscamente
      setState(() {
        // En un teléfono, X es el eje lateral, Y es el eje vertical
        // Los valores van de aprox -9.8 a 9.8
        _tiltX = _tiltX + (event.x - _tiltX) * 0.2;
        _tiltY = _tiltY + (event.y - _tiltY) * 0.2;
      });
    });
  }

  @override
  void didUpdateWidget(covariant WaterWaveWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
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
    _accelerometerSubscription
        ?.cancel(); // Importante para no dejar fugas de memoria
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
            tiltX: _tiltX,
            tiltY: _tiltY,
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
  final double tiltX;
  final double tiltY;

  WavePainter({
    required this.animationValue,
    required this.modo,
    required this.tiltX,
    required this.tiltY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    double baseFillPercentage;
    Color waveColor;
    double amplitude;

    if (modo == 'Fuga') {
      baseFillPercentage = 0.85;
      waveColor = AppTheme.criticalColor.withOpacity(0.7);
      amplitude = 12.0;
    } else if (modo == 'Anomalia') {
      baseFillPercentage = 0.55;
      waveColor = AppTheme.warningColor.withOpacity(0.8);
      amplitude = 7.0;
    } else {
      baseFillPercentage = 0.25;
      waveColor = AppTheme.primaryColor.withOpacity(0.6);
      amplitude = 4.0;
    }

    // Efecto de inclinación hacia adelante/atrás (eje Y del teléfono)
    // Si el teléfono se acuesta, el agua "sube" o "baja" ligeramente visualmente
    double dynamicFill = baseFillPercentage + (tiltY * 0.015);
    dynamicFill = dynamicFill.clamp(
      0.0,
      1.0,
    ); // Evitar que se salga de 0% a 100%

    final waterHeight = size.height * (1 - dynamicFill);

    // --- ROTACIÓN DEL CANVAS (FÍSICAS DEL AGUA) ---
    // Calculamos el ángulo de inclinación basado en el eje X
    // El multiplicador 0.08 controla qué tan extremo es el ángulo
    double rotationAngle = -tiltX * 0.08;

    canvas.save(); // Guardamos el estado original del canvas

    // Movemos el eje de rotación al centro de la superficie del agua
    canvas.translate(size.width / 2, waterHeight);
    canvas.rotate(rotationAngle);
    canvas.translate(-size.width / 2, -waterHeight);

    // Al rotar el canvas, las esquinas pueden quedar vacías.
    // Solución: Dibujamos el agua mucho más ancha que la pantalla
    // (desde -ancho hasta el doble del ancho)
    double extraWidth = size.width * 1.5;
    double startX = -extraWidth;
    double endX = size.width + extraWidth;

    // --- DIBUJAR OLA FRONTAL ---
    final path = Path();
    path.moveTo(
      startX,
      size.height + extraWidth,
    ); // Abajo a la izquierda (con margen)
    path.lineTo(startX, waterHeight);

    for (double i = startX; i <= endX; i++) {
      double waveY =
          math.sin(
            (i / size.width * 2 * math.pi) + (animationValue * 2 * math.pi),
          ) *
          amplitude;
      path.lineTo(i, waterHeight + waveY);
    }

    path.lineTo(
      endX,
      size.height + extraWidth,
    ); // Abajo a la derecha (con margen)
    path.close();
    canvas.drawPath(path, Paint()..color = waveColor);

    // --- DIBUJAR OLA TRASERA (efecto 3D) ---
    final path2 = Path();
    path2.moveTo(startX, size.height + extraWidth);
    path2.lineTo(startX, waterHeight);

    for (double i = startX; i <= endX; i++) {
      double waveY2 =
          math.sin(
            (i / size.width * 2 * math.pi) +
                ((animationValue + 0.5) * 2 * math.pi),
          ) *
          (amplitude * 0.8);
      path2.lineTo(i, waterHeight + waveY2);
    }
    path2.lineTo(endX, size.height + extraWidth);
    path2.close();
    canvas.drawPath(path2, Paint()..color = waveColor.withOpacity(0.4));

    canvas.restore(); // Restauramos el canvas para no afectar a otros widgets
  }

  @override
  bool shouldRepaint(covariant WavePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.modo != modo ||
        oldDelegate.tiltX != tiltX || // Repintar si el teléfono se mueve
        oldDelegate.tiltY != tiltY;
  }
}
