import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class AuthService {
  static const _storage = FlutterSecureStorage();

  /// Devuelve null si el login fue correcto, o el mensaje de error.
  Future<String?> login(String correo, String password) async {
    try {
      final respuesta = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/auth/login'),
            headers: {'Content-Type': 'application/json; charset=utf-8'},
            body: jsonEncode({'correo': correo, 'password': password}),
          )
          .timeout(const Duration(seconds: 10));

      final datos = jsonDecode(utf8.decode(respuesta.bodyBytes));

      if (respuesta.statusCode == 200) {
        await _storage.write(key: 'token', value: datos['token']);
        await _storage.write(key: 'rol', value: datos['usuario']['rol']);
        await _storage.write(
          key: 'nombre',
          value: '${datos['usuario']['nombre']} ${datos['usuario']['apellido']}',
        );
        return null;
      }
      return datos['error'] ?? 'No se pudo iniciar sesión';
    } catch (_) {
      return 'No se pudo conectar con el servidor';
    }
  }

  Future<String?> obtenerToken() => _storage.read(key: 'token');

  Future<void> cerrarSesion() => _storage.deleteAll();
}