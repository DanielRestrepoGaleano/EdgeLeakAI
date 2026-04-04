import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // ¡Importante para leer el .env!
import '../../controllers/auth_controller.dart';
import '../../config/themes/app_theme.dart';
import '../../config/routes/app_routes.dart';

class RegisterScreen extends StatefulWidget {
  final AuthController authController;
  const RegisterScreen({super.key, required this.authController});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _primerNombreController = TextEditingController();
  final _segundoNombreController = TextEditingController();
  final _primerApellidoController = TextEditingController();
  final _segundoApellidoController = TextEditingController();
  final _correoController = TextEditingController();
  final _passController = TextEditingController();
  final _codigoAdminController = TextEditingController();

  bool _ocultarPass = true;
  String _correoError = '';

  static final _emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$',
  );

  bool _validarCorreo(String correo) {
    return _emailRegex.hasMatch(correo);
  }

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

                // Primer Nombre (obligatorio)
                TextField(
                  controller: _primerNombreController,
                  decoration: const InputDecoration(
                    labelText: 'Primer Nombre *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 15),

                // Segundo Nombre (opcional)
                TextField(
                  controller: _segundoNombreController,
                  decoration: const InputDecoration(
                    labelText: 'Segundo Nombre',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 15),

                // Primer Apellido (obligatorio)
                TextField(
                  controller: _primerApellidoController,
                  decoration: const InputDecoration(
                    labelText: 'Primer Apellido *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.badge),
                  ),
                ),
                const SizedBox(height: 15),

                // Segundo Apellido (opcional)
                TextField(
                  controller: _segundoApellidoController,
                  decoration: const InputDecoration(
                    labelText: 'Segundo Apellido',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                ),
                const SizedBox(height: 15),

                // Correo electrónico con validación
                TextField(
                  controller: _correoController,
                  keyboardType: TextInputType.emailAddress,
                  onChanged: (val) {
                    setState(() {
                      _correoError = val.isNotEmpty && !_validarCorreo(val)
                          ? 'Ingresa un correo electrónico válido (ejemplo@dominio.com)'
                          : '';
                    });
                  },
                  decoration: InputDecoration(
                    labelText: 'Correo Electrónico *',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.email),
                    errorText: _correoError.isNotEmpty ? _correoError : null,
                  ),
                ),
                const SizedBox(height: 20),

                TextField(
                  controller: _passController,
                  obscureText: _ocultarPass,
                  onChanged: (val) =>
                      widget.authController.validatePassword(val),
                  decoration: InputDecoration(
                    labelText: 'Crear Contraseña *',
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

                // Campo de Código Admin Opcional
                TextField(
                  controller: _codigoAdminController,
                  decoration: const InputDecoration(
                    labelText: 'Código Admin (Opcional)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.security),
                  ),
                ),
                const SizedBox(height: 10),

                Text(
                  '* Campos obligatorios',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
                const SizedBox(height: 20),

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
                          final primerNombre = _primerNombreController.text.trim();
                          final primerApellido = _primerApellidoController.text.trim();
                          final correo = _correoController.text.trim();

                          // Validar campos obligatorios de nombre
                          if (primerNombre.isEmpty || primerApellido.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Primer nombre y primer apellido son obligatorios.'),
                                backgroundColor: AppTheme.criticalColor,
                              ),
                            );
                            return;
                          }

                          // Validar correo con regex
                          if (!_validarCorreo(correo)) {
                            setState(() {
                              _correoError = correo.isEmpty
                                  ? 'El correo es obligatorio.'
                                  : 'Ingresa un correo electrónico válido (ejemplo@dominio.com)';
                            });
                            return;
                          }

                          String rolAsignado = 'operador';
                          final secretCode = dotenv.env['SECRET_ADMIN_CODE'];

                          if (secretCode != null &&
                              _codigoAdminController.text.trim() == secretCode) {
                            rolAsignado = 'admin';
                          }

                          final exito = await widget.authController.register(
                            primerNombre,
                            _segundoNombreController.text.trim(),
                            primerApellido,
                            _segundoApellidoController.text.trim(),
                            correo,
                            _passController.text.trim(),
                            rol: rolAsignado,
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
                            Navigator.pushNamedAndRemoveUntil(
                              context,
                              AppRoutes.loginScreen,
                              (route) => false,
                            );
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
