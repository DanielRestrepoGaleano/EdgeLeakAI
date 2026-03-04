import os

BASE_DIR = r"C:\Users\danie\OneDrive\Escritorio\edgeleak"

FILES = {
    # ---------------- 1. CORRECCIÓN DEL TEST ----------------
    r"test\widget_test.dart": r"""import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/controllers/auth_controller.dart';
import '../lib/controllers/dashboard_controller.dart';
import '../lib/view/screens/login_screen.dart';

void main() {
  testWidgets('Prueba de UI: La pantalla de Login renderiza todos sus elementos clave', (WidgetTester tester) async {
    final authController = AuthController();
    final dashboardController = DashboardController();

    // 🛠️ LA SOLUCIÓN AL ERROR: 
    // Aseguramos que los "Timers" del dashboard se apaguen al terminar el test.
    addTearDown(() {
      dashboardController.dispose();
      authController.dispose();
    });

    await tester.pumpWidget(MaterialApp(
      home: LoginScreen(
        authController: authController,
        dashboardController: dashboardController,
      ),
    ));

    expect(find.text('EdgeLeak AI'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.text('INICIAR SESIÓN'), findsOneWidget);
    expect(find.text('¿No tienes cuenta? Regístrate aquí'), findsOneWidget);
  });
}
""",

    # ---------------- 2. CONTROLADOR (Lógica de Generación Segura) ----------------
    r"lib\controllers\auth_controller.dart": r"""import 'dart:math';
import 'package:flutter/material.dart';
import '../data/models/usuario_model.dart';
import '../data/services/database_service.dart';

class AuthController extends ChangeNotifier {
  final DatabaseService _dbService = DatabaseService();
  
  bool isLoading = false;
  String errorMessage = '';

  bool hasMinLength = false;
  bool hasUppercase = false;
  bool hasNumber = false;
  bool hasSpecialChar = false;

  void validatePassword(String password) {
    hasMinLength = password.length >= 8;
    hasUppercase = password.contains(RegExp(r'[A-Z]'));
    hasNumber = password.contains(RegExp(r'[0-9]'));
    hasSpecialChar = password.contains(RegExp(r'[!@#\$&*~]'));
    notifyListeners();
  }

  bool get isPasswordValid => hasMinLength && hasUppercase && hasNumber && hasSpecialChar;

  void resetValidators() {
    hasMinLength = false;
    hasUppercase = false;
    hasNumber = false;
    hasSpecialChar = false;
    errorMessage = '';
    notifyListeners();
  }

  // 🪄 NUEVO: Función para generar una contraseña infalible
  String generarContrasenaSegura() {
    const length = 12;
    const uppercase = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    const lowercase = 'abcdefghijklmnopqrstuvwxyz';
    const numbers = '0123456789';
    const specials = '!@#\$&*~';
    
    final rnd = Random();
    String pass = '';
    
    // Forzamos que tenga al menos 1 de cada requisito
    pass += uppercase[rnd.nextInt(uppercase.length)];
    pass += lowercase[rnd.nextInt(lowercase.length)];
    pass += numbers[rnd.nextInt(numbers.length)];
    pass += specials[rnd.nextInt(specials.length)];

    // Rellenamos el resto hasta 12 caracteres aleatorios
    const allChars = uppercase + lowercase + numbers + specials;
    for (int i = 4; i < length; i++) {
      pass += allChars[rnd.nextInt(allChars.length)];
    }

    // Mezclamos la cadena para que los obligatorios no queden al principio
    List<String> passList = pass.split('')..shuffle(rnd);
    final finalPass = passList.join('');
    
    // Validamos automáticamente para que los checks verdes se enciendan
    validatePassword(finalPass);
    return finalPass;
  }

  Future<UsuarioModel?> login(String correo, String password) async {
    isLoading = true;
    errorMessage = '';
    notifyListeners();

    final usuario = await _dbService.loginUsuario(correo, password);
    if (usuario == null) errorMessage = 'Correo o contraseña incorrectos';

    isLoading = false;
    notifyListeners();
    return usuario;
  }

  Future<bool> register(String nombre, String correo, String password) async {
    if (!isPasswordValid) {
      errorMessage = 'La contraseña no cumple los requisitos de seguridad';
      notifyListeners();
      return false;
    }

    isLoading = true;
    errorMessage = '';
    notifyListeners();

    final nuevoUsuario = UsuarioModel(nombre: nombre, correo: correo, password: password);
    final exito = await _dbService.registrarUsuario(nuevoUsuario);

    if (!exito) errorMessage = 'El correo ya está registrado';

    isLoading = false;
    notifyListeners();
    return exito;
  }
}
""",

    # ---------------- 3. PANTALLA REGISTRO (UI Mejorada) ----------------
    r"lib\view\screens\register_screen.dart": r"""import 'package:flutter/material.dart';
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
  
  // Variable para controlar el "ojito" de la contraseña
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
              children:[
                if (widget.authController.errorMessage.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 20),
                    color: AppTheme.criticalColor.withOpacity(0.1),
                    child: Text(widget.authController.errorMessage, style: const TextStyle(color: AppTheme.criticalColor), textAlign: TextAlign.center),
                  ),

                TextField(
                  controller: _nombreController,
                  decoration: const InputDecoration(labelText: 'Nombre Completo', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person)),
                ),
                const SizedBox(height: 20),
                
                TextField(
                  controller: _correoController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Correo Electrónico', border: OutlineInputBorder(), prefixIcon: Icon(Icons.email)),
                ),
                const SizedBox(height: 20),

                // Campo de Contraseña Mejorado (con visibilidad)
                TextField(
                  controller: _passController,
                  obscureText: _ocultarPass,
                  onChanged: (val) => widget.authController.validatePassword(val),
                  decoration: InputDecoration(
                    labelText: 'Crear Contraseña', 
                    border: const OutlineInputBorder(), 
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_ocultarPass ? Icons.visibility_off : Icons.visibility),
                      onPressed: () {
                        setState(() {
                          _ocultarPass = !_ocultarPass;
                        });
                      },
                    )
                  ),
                ),

                // 🪄 Botón de Auto-Generar Clave Segura
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () {
                      final claveSegura = widget.authController.generarContrasenaSegura();
                      _passController.text = claveSegura;
                      setState(() {
                        _ocultarPass = false; // Mostramos la clave para que la copie
                      });
                    },
                    icon: const Icon(Icons.auto_awesome, color: AppTheme.primaryColor),
                    label: const Text('Sugerir contraseña fuerte', style: TextStyle(color: AppTheme.primaryColor)),
                  ),
                ),
                const SizedBox(height: 5),

                // Validadores Visuales
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade300)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children:[
                      const Text('Requisitos de seguridad:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      _buildCheck('Mínimo 8 caracteres', widget.authController.hasMinLength),
                      const SizedBox(height: 5),
                      _buildCheck('Al menos 1 mayúscula', widget.authController.hasUppercase),
                      const SizedBox(height: 5),
                      _buildCheck('Al menos 1 número', widget.authController.hasNumber),
                      const SizedBox(height: 5),
                      _buildCheck('Al menos 1 carácter especial (!@#\$&*~)', widget.authController.hasSpecialChar),
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
                    final exito = await widget.authController.register(
                      _nombreController.text.trim(), 
                      _correoController.text.trim(), 
                      _passController.text.trim()
                    );

                    if (exito && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cuenta creada con éxito. Inicia sesión.'), backgroundColor: AppTheme.normalColor));
                      Navigator.pop(context); // Vuelve al login
                    }
                  },
                  child: widget.authController.isLoading 
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('REGISTRARSE', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          }
        ),
      ),
    );
  }
}
"""
}

def reparar_e_inyectar():
    print("🛠️ Reparando Tests e Inyectando Generador de Contraseñas...")
    
    for relative_path, content in FILES.items():
        full_path = os.path.join(BASE_DIR, relative_path)
        with open(full_path, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"✅ Archivo actualizado: {relative_path}")
        
    print("\n🎉 ¡Listo! Ahora corre 'flutter test' de nuevo, y verás que todo sale verde.")

if __name__ == "__main__":
    reparar_e_inyectar()