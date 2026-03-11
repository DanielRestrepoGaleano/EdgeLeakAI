import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class EmailService {
  Future<bool> enviarCorreoRecuperacion(String destinatario, String tempPass) async {
    String username = dotenv.env['SMTP_EMAIL'] ?? '';
    String password = dotenv.env['SMTP_PASSWORD'] ?? '';

    if (username.isEmpty || password.isEmpty) return false;

    // Conexión segura con Gmail
    final smtpServer = gmail(username, password);

    // Plantilla HTML Profesional
    final htmlBody = '''
    <div style="font-family: Arial, sans-serif; max-width: 600px; margin: auto; border: 1px solid #ddd; border-radius: 10px; overflow: hidden;">
      <div style="background-color: #2196F3; padding: 20px; text-align: center;">
        <h1 style="color: white; margin: 0;">EdgeLeak AI</h1>
      </div>
      <div style="padding: 30px; background-color: #f9f9f9;">
        <h2 style="color: #333;">Recuperación de Contraseña</h2>
        <p style="color: #555; font-size: 16px;">Hola,</p>
        <p style="color: #555; font-size: 16px;">Has solicitado restablecer tu contraseña. Hemos generado una clave temporal y segura para que puedas ingresar al sistema:</p>
        
        <div style="background-color: #fff; border-left: 4px solid #4CAF50; padding: 15px; margin: 20px 0; font-size: 24px; font-weight: bold; text-align: center; letter-spacing: 2px;">
          $tempPass
        </div>
        
        <p style="color: #F44336; font-size: 14px;"><strong>⚠️ Acción Requerida:</strong> Por políticas de ciberseguridad, el sistema te obligará a cambiar esta contraseña inmediatamente después de iniciar sesión.</p>
      </div>
      <div style="background-color: #eee; padding: 10px; text-align: center; color: #888; font-size: 12px;">
        Este es un correo automático del sistema EdgeLeak AI (Proyecto PICUR Uniremington). No respondas a este mensaje.
      </div>
    </div>
    ''';

    final message = Message()
      ..from = Address(username, 'Soporte EdgeLeak AI')
      ..recipients.add(destinatario)
      ..subject = '🔐 Recuperación de Contraseña - EdgeLeak AI'
      ..html = htmlBody;

    try {
      await send(message, smtpServer);
      return true;
    } catch (e) {
      print('Error al enviar correo: $e');
      return false;
    }
  }
}
