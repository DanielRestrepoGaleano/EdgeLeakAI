import 'package:flutter/material.dart';
import '../../controllers/auth_controller.dart';
import '../../config/themes/app_theme.dart';

class ForgotPasswordScreen extends StatefulWidget {
  final AuthController authController;
  const ForgotPasswordScreen({super.key, required this.authController});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _correoController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recuperar Contraseña')),
      body: Padding(
        padding: const EdgeInsets.all(30.0),
        child: ListenableBuilder(
          listenable: widget.authController,
          builder: (context, _) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children:[
                const Icon(Icons.mark_email_read, size: 80, color: AppTheme.primaryColor),
                const SizedBox(height: 20),
                const Text('¿Problemas para entrar?', textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                const Text('Ingresa tu correo y te enviaremos una contraseña temporal segura.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 30),

                if (widget.authController.errorMessage.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 20),
                    color: AppTheme.criticalColor.withOpacity(0.1),
                    child: Text(widget.authController.errorMessage, style: const TextStyle(color: AppTheme.criticalColor), textAlign: TextAlign.center),
                  ),

                TextField(
                  controller: _correoController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Tu Correo Electrónico', border: OutlineInputBorder(), prefixIcon: Icon(Icons.email)),
                ),
                const SizedBox(height: 30),

                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 15)),
                  onPressed: widget.authController.isLoading ? null : () async {
                    if (_correoController.text.isEmpty) return;
                    
                    final exito = await widget.authController.enviarCorreoRecuperacion(_correoController.text.trim());

                    if (exito && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('¡Correo enviado! Revisa tu bandeja de entrada.'), backgroundColor: AppTheme.normalColor));
                      Navigator.pop(context); // Volver al login
                    }
                  },
                  child: widget.authController.isLoading 
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('ENVIAR ENLACE', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          }
        ),
      ),
    );
  }
}
