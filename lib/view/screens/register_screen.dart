import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // ¡Importante para leer el .env!
import '../../controllers/auth_controller.dart';
import '../../config/themes/app_theme.dart';

class RegisterScreen extends StatefulWidget {
  final AuthController authController;
  const RegisterScreen({super.key, required this.authController});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nombreController = TextEditingController();
  final _correoController = TextEditingController();
  final _passController = TextEditingController();
  final _codigoAdminController =
      TextEditingController(); // 🟢 Nuevo controlador para el código

  bool _ocultarPass = true;

  Widget _buildCheck(String text, bool isValid) {
    return Row(
      children: [
        Icon(
          isValid ? Icons.check_circle : Icons.cancel,
          color: isValid ? AppTheme.normalColor : Colors.grey,
          size: 20,
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(color: isValid ? AppTheme.normalColor : Colors.grey),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crear Cuenta Nueva')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(30.0),
        child: ListenableBuilder(
          listenable: widget.authController,
          builder: (context, _) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.authController.errorMessage.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 20),
                    color: AppTheme.criticalColor.withOpacity(0.1),
                    child: Text(
                      widget.authController.errorMessage,
                      style: const TextStyle(color: AppTheme.criticalColor),
                      textAlign: TextAlign.center,
                    ),
                  ),

                TextField(
                  controller: _nombreController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre Completo',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 20),

                TextField(
                  controller: _correoController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Correo Electrónico',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                ),
                const SizedBox(height: 20),

                TextField(
                  controller: _passController,
                  obscureText: _ocultarPass,
                  onChanged: (val) =>
                      widget.authController.validatePassword(val),
                  decoration: InputDecoration(
                    labelText: 'Crear Contraseña',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _ocultarPass ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          _ocultarPass = !_ocultarPass;
                        });
                      },
                    ),
                  ),
                ),

                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () {
                      final claveSegura = widget.authController
                          .generarContrasenaSegura();
                      _passController.text = claveSegura;
                      setState(() {
                        _ocultarPass = false;
                      });
                    },
                    icon: const Icon(
                      Icons.auto_awesome,
                      color: AppTheme.primaryColor,
                    ),
                    label: const Text(
                      'Sugerir contraseña fuerte',
                      style: TextStyle(color: AppTheme.primaryColor),
                    ),
                  ),
                ),
                const SizedBox(height: 5),

                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Requisitos de seguridad:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      _buildCheck(
                        'Mínimo 8 caracteres',
                        widget.authController.hasMinLength,
                      ),
                      const SizedBox(height: 5),
                      _buildCheck(
                        'Al menos 1 mayúscula',
                        widget.authController.hasUppercase,
                      ),
                      const SizedBox(height: 5),
                      _buildCheck(
                        'Al menos 1 número',
                        widget.authController.hasNumber,
                      ),
                      const SizedBox(height: 5),
                      _buildCheck(
                        'Al menos 1 carácter especial (!@#\$&*~)',
                        widget.authController.hasSpecialChar,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 🟢 Campo de Código Admin Opcional
                TextField(
                  controller: _codigoAdminController,
                  decoration: const InputDecoration(
                    labelText: 'Código Admin (Opcional)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.security),
                  ),
                ),
                const SizedBox(height: 30),

                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.authController.isPasswordValid
                        ? AppTheme.primaryColor
                        : Colors.grey,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  onPressed:
                      (!widget.authController.isPasswordValid ||
                          widget.authController.isLoading)
                      ? null
                      : () async {
                          // 🟢 Verificación de la variable de entorno
                          String rolAsignado = 'operador';
                          final secretCode = dotenv.env['SECRET_ADMIN_CODE'];

                          if (secretCode != null &&
                              _codigoAdminController.text.trim() ==
                                  secretCode) {
                            rolAsignado = 'admin';
                          }

                          final exito = await widget.authController.register(
                            _nombreController.text.trim(),
                            _correoController.text.trim(),
                            _passController.text.trim(),
                            rol:
                                rolAsignado, // Pasamos el rol que acabamos de evaluar
                          );

                          if (exito && context.mounted) {
                            final mensaje = rolAsignado == 'admin'
                                ? 'Cuenta ADMIN creada con éxito. Inicia sesión.'
                                : 'Cuenta creada con éxito. Inicia sesión.';
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(mensaje),
                                backgroundColor: AppTheme.normalColor,
                              ),
                            );
                            Navigator.pop(context);
                          }
                        },
                  child: widget.authController.isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'REGISTRARSE',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
