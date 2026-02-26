import 'package:flutter/material.dart';
import '../../config/themes/app_theme.dart';

class StatusIndicatorWidget extends StatelessWidget {
  final bool conectado;

  const StatusIndicatorWidget({super.key, required this.conectado});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children:[
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: conectado ? AppTheme.normalColor : AppTheme.criticalColor,
          ),
        ),
        const SizedBox(width: 8),
        Text(conectado ? 'Conectado al nodo sensor' : 'Desconectado', style: const TextStyle(fontWeight: FontWeight.w500)),
      ],
    );
  }
}
