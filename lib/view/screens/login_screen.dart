import 'package:flutter/material.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/dashboard_controller.dart';
import '../../config/themes/app_theme.dart';
import '../../config/routes/app_routes.dart';

class LoginScreen extends StatefulWidget {
  final AuthController authController;
  final DashboardController dashboardController;

  const LoginScreen({super.key, required this.authController, required this.dashboardController});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _correoController = TextEditingController();
  final _passController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(30.0),
            child: ListenableBuilder(
              listenable: widget.authController,
              builder: (context, _) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children:[
                    const Icon(Icons.water_drop, size: 80, color: AppTheme.primaryColor),
                    const SizedBox(height: 20),
                    const Text('EdgeLeak AI', textAlign: TextAlign.center, style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                    const Text('Detección Inteligente de Fugas', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 40),

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
                      decoration: const InputDecoration(labelText: 'Correo Electrónico', border: OutlineInputBorder(), prefixIcon: Icon(Icons.email)),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _passController,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Contraseña', border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock)),
                    ),
                    const SizedBox(height: 30),

                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15)
                      ),
                      onPressed: widget.authController.isLoading ? null : () async {
                        final usuario = await widget.authController.login(
                          _correoController.text.trim(), 
                          _passController.text.trim()
                        );

                        if (usuario != null && context.mounted) {
                          // Pasamos el nombre al Dashboard y navegamos
                          widget.dashboardController.setUsuarioLogueado(usuario.nombre);
                          Navigator.pushReplacementNamed(context, AppRoutes.dashboardScreen);
                        }
                      },
                      child: widget.authController.isLoading 
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('INICIAR SESIÓN', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    
                    TextButton(
                      onPressed: () {
                        widget.authController.resetValidators();
                        Navigator.pushNamed(context, AppRoutes.registerScreen);
                      },
                      child: const Text('¿No tienes cuenta? Regístrate aquí'),
                    )
                  ],
                );
              }
            ),
          ),
        ),
      ),
    );
  }
}
