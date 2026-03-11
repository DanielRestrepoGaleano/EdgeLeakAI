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
  UsuarioModel? usuarioActual; 

  // --- VALIDACIONES ORIGINALES ---
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

  // --- LÓGICA DE SESIÓN Y REGISTRO ---

  Future<UsuarioModel?> login(String correo, String password) async {
    isLoading = true;
    errorMessage = '';
    notifyListeners();

    final usuario = await _dbService.loginUsuario(correo, password);
    if (usuario == null) {
      errorMessage = 'Correo o contraseña incorrectos';
    } else {
      usuarioActual = usuario; 
    }

    isLoading = false;
    notifyListeners();
    return usuario;
  }

  Future<bool> register(String nombre, String correo, String password, {String rol = 'operador'}) async {
    if (!isPasswordValid) return false;

    isLoading = true;
    errorMessage = '';
    notifyListeners();

    // Ahora incluimos el rol en el registro
    final nuevoUsuario = UsuarioModel(nombre: nombre, correo: correo, password: password, rol: rol);
    final exito = await _dbService.registrarUsuario(nuevoUsuario);

    if (!exito) errorMessage = 'El correo ya está registrado';

    isLoading = false;
    notifyListeners();
    return exito;
  }

  // --- RECUPERACIÓN Y CAMBIO OBLIGATORIO ---

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
    await _dbService.actualizarPassword(usuario.id!, tempPass, true);
    final correoEnviado = await _emailService.enviarCorreoRecuperacion(correo, tempPass);

    if (!correoEnviado) {
      errorMessage = 'Error al enviar el correo. Revisa tu conexión o configuración.';
    }

    isLoading = false;
    notifyListeners();
    return correoEnviado;
  }

  Future<bool> cambiarPasswordObligatorio(String nuevaPassword) async {
    if (!isPasswordValid || usuarioActual == null) return false;

    isLoading = true;
    notifyListeners();

    await _dbService.actualizarPassword(usuarioActual!.id!, nuevaPassword, false);
    
    usuarioActual = UsuarioModel(
      id: usuarioActual!.id,
      nombre: usuarioActual!.nombre,
      correo: usuarioActual!.correo,
      password: nuevaPassword,
      esTemporal: 0,
      rol: usuarioActual!.rol, // Mantenemos el rol al actualizar sesión
    );

    isLoading = false;
    notifyListeners();
    return true;
  }

  // ✨ NUEVOS MÉTODOS PARA EL CRUD (Requerimiento Daniel)
  
  List<UsuarioModel> _listaUsuarios = [];
  List<UsuarioModel> get listaUsuarios => _listaUsuarios;

  Future<void> obtenerTodosLosUsuarios() async {
    isLoading = true;
    notifyListeners();
    _listaUsuarios = await _dbService.obtenerTodosLosUsuarios();
    isLoading = false;
    notifyListeners();
  }

  Future<bool> eliminarUsuario(int id) async {
    // Seguridad básica: No permitir que el usuario logueado se borre a sí mismo
    if (usuarioActual?.id == id) {
      errorMessage = 'No puedes eliminar tu propia cuenta.';
      notifyListeners();
      return false;
    }

    final filasAfectadas = await _dbService.eliminarUsuario(id);
    if (filasAfectadas > 0) {
      await obtenerTodosLosUsuarios(); // Refrescar lista automáticamente
      return true;
    }
    return false;
  }

  Future<bool> actualizarDatosUsuario(UsuarioModel usuario) async {
    final filasAfectadas = await _dbService.actualizarUsuario(usuario);
    if (filasAfectadas > 0) {
      await obtenerTodosLosUsuarios();
      return true;
    }
    return false;
  }
}