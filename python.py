import os

BASE_DIR = r"C:\Users\danie\OneDrive\Escritorio\edgeleak\lib"

FILE_CONTENT = r"""import 'package:flutter/material.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/dashboard_controller.dart';
import '../../config/themes/app_theme.dart';
import '../../config/routes/app_routes.dart';

class ChangePasswordScreen extends StatefulWidget {
  final AuthController authController;
  final DashboardController dashboardController;
  const ChangePasswordScreen({super.key, required this.authController, required this.dashboardController});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _passController = TextEditingController();
  bool _ocultarPass = true; 

  Widget _buildCheck(String text, bool isValid) {
    return Row(
      children:[
        Icon(isValid ? Icons.check_circle : Icons.cancel, color: isValid ? AppTheme.normalColor : Colors.grey, size: 20),
        const SizedBox(width: 8),
        Text(text, style: TextStyle(color: isValid ? AppTheme.normalColor : Colors.grey)),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    // 🛠️ SOLUCIÓN AL CRASH: Esperamos a que termine el primer frame antes de resetear
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.authController.resetValidators();
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, 
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Cambio Obligatorio'),
          automaticallyImplyLeading: false, 
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(30.0),
          child: ListenableBuilder(
            listenable: widget.authController,
            builder: (context, _) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children:[
                  const Icon(Icons.security, size: 60, color: AppTheme.warningColor),
                  const SizedBox(height: 20),
                  const Text('¡Por tu seguridad!', textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  const Text('Has iniciado sesión con una clave temporal. Debes crear una nueva contraseña para continuar al panel de control.', textAlign: TextAlign.center),
                  const SizedBox(height: 30),

                  TextField(
                    controller: _passController,
                    obscureText: _ocultarPass,
                    onChanged: (val) => widget.authController.validatePassword(val),
                    decoration: InputDecoration(
                      labelText: 'Nueva Contraseña Segura', 
                      border: const OutlineInputBorder(), 
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(icon: Icon(_ocultarPass ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _ocultarPass = !_ocultarPass))
                    ),
                  ),
                  
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () {
                        final clave = widget.authController.generarContrasenaSegura();
                        _passController.text = clave;
                        setState(() => _ocultarPass = false);
                      },
                      icon: const Icon(Icons.auto_awesome),
                      label: const Text('Generar clave fuerte'),
                    ),
                  ),
                  const SizedBox(height: 5),

                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade300)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children:[
                        const Text('Requisitos:', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        _buildCheck('Mínimo 8 caracteres', widget.authController.hasMinLength),
                        const SizedBox(height: 5),
                        _buildCheck('Al menos 1 mayúscula', widget.authController.hasUppercase),
                        const SizedBox(height: 5),
                        _buildCheck('Al menos 1 número', widget.authController.hasNumber),
                        const SizedBox(height: 5),
                        _buildCheck('Al menos 1 carácter especial', widget.authController.hasSpecialChar),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),

                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.authController.isPasswordValid ? AppTheme.primaryColor : Colors.grey,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15)
                    ),
                    onPressed: (!widget.authController.isPasswordValid || widget.authController.isLoading) ? null : () async {
                      final exito = await widget.authController.cambiarPasswordObligatorio(_passController.text.trim());
                      
                      if (exito && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Contraseña actualizada con éxito.'), backgroundColor: AppTheme.normalColor));
                        Navigator.pushReplacementNamed(context, AppRoutes.dashboardScreen);
                      }
                    },
                    child: widget.authController.isLoading 
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('GUARDAR Y CONTINUAR', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              );
            }
          ),
        ),
      ),
    );
  }
}
"""

def parchar_error():
    full_path = os.path.join(BASE_DIR, r"view\screens\change_password_screen.dart")
    with open(full_path, 'w', encoding='utf-8') as f:
        f.write(FILE_CONTENT)
    print("✅ ¡Crash parchado con éxito!")
    print("Haz un 'Hot Restart' (reiniciar la app, no solo reload) y vuelve a iniciar sesión con la clave temporal.")

if __name__ == "__main__":
    parchar_error()