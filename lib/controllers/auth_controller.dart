import 'dart:math';
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
