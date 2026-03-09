import 'dart:math';
import 'package:flutter/material.dart';
import '../data/models/usuario_model.dart';
import '../data/services/database_service.dart';
import '../data/services/email_service.dart';

class AuthController extends ChangeNotifier {
  final DatabaseService _dbService = DatabaseService();
  final EmailService _emailService = EmailService();
  
  bool isLoading = false;
  String errorMessage = '';
  UsuarioModel? usuarioActual; // Mantiene la sesión

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

  String generarContrasenaSegura() {
    const length = 12;
    const uppercase = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    const lowercase = 'abcdefghijklmnopqrstuvwxyz';
    const numbers = '0123456789';
    const specials = '!@#\$&*~';
    
    final rnd = Random();
    String pass = '';
    
    pass += uppercase[rnd.nextInt(uppercase.length)];
    pass += lowercase[rnd.nextInt(lowercase.length)];
    pass += numbers[rnd.nextInt(numbers.length)];
    pass += specials[rnd.nextInt(specials.length)];

    const allChars = uppercase + lowercase + numbers + specials;
    for (int i = 4; i < length; i++) pass += allChars[rnd.nextInt(allChars.length)];

    List<String> passList = pass.split('')..shuffle(rnd);
    final finalPass = passList.join('');
    
    validatePassword(finalPass);
    return finalPass;
  }

  Future<UsuarioModel?> login(String correo, String password) async {
    isLoading = true;
    errorMessage = '';
    notifyListeners();

    final usuario = await _dbService.loginUsuario(correo, password);
    if (usuario == null) {
      errorMessage = 'Correo o contraseña incorrectos';
    } else {
      usuarioActual = usuario; // Guardamos la sesión
    }

    isLoading = false;
    notifyListeners();
    return usuario;
  }

  Future<bool> register(String nombre, String correo, String password) async {
    if (!isPasswordValid) return false;

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

  // 📧 NUEVO: Lógica de Recuperación de Contraseña
  Future<bool> enviarCorreoRecuperacion(String correo) async {
    isLoading = true;
    errorMessage = '';
    notifyListeners();

    final usuario = await _dbService.obtenerUsuarioPorCorreo(correo);
    
    if (usuario == null) {
      errorMessage = 'No hay ninguna cuenta asociada a este correo.';
      isLoading = false;
      notifyListeners();
      return false;
    }

    String tempPass = generarContrasenaSegura();
    
    // 1. Guardar en Base de Datos (Marcando como temporal = true)
    await _dbService.actualizarPassword(usuario.id!, tempPass, true);

    // 2. Enviar Correo
    final correoEnviado = await _emailService.enviarCorreoRecuperacion(correo, tempPass);

    if (!correoEnviado) {
      errorMessage = 'Error al enviar el correo. Revisa tu conexión o configuración.';
    }

    isLoading = false;
    notifyListeners();
    return correoEnviado;
  }

  // 🔐 NUEVO: Lógica para el Cambio Obligatorio
  Future<bool> cambiarPasswordObligatorio(String nuevaPassword) async {
    if (!isPasswordValid || usuarioActual == null) return false;

    isLoading = true;
    notifyListeners();

    // Actualizamos en BD (Marcando temporal = false)
    await _dbService.actualizarPassword(usuarioActual!.id!, nuevaPassword, false);
    
    // Actualizamos la sesión en memoria
    usuarioActual = UsuarioModel(
      id: usuarioActual!.id,
      nombre: usuarioActual!.nombre,
      correo: usuarioActual!.correo,
      password: nuevaPassword,
      esTemporal: 0,
    );

    isLoading = false;
    notifyListeners();
    return true;
  }
}
