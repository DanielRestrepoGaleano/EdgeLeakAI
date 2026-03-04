import 'package:flutter/material.dart';
import '../data/models/usuario_model.dart';
import '../data/services/database_service.dart';

class AuthController extends ChangeNotifier {
  final DatabaseService _dbService = DatabaseService();
  
  bool isLoading = false;
  String errorMessage = '';

  // Validadores dinámicos de contraseña
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

  Future<UsuarioModel?> login(String correo, String password) async {
    isLoading = true;
    errorMessage = '';
    notifyListeners();

    final usuario = await _dbService.loginUsuario(correo, password);
    
    if (usuario == null) {
      errorMessage = 'Correo o contraseña incorrectos';
    }

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

    if (!exito) {
      errorMessage = 'El correo ya está registrado';
    }

    isLoading = false;
    notifyListeners();
    return exito;
  }
}
