import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'auth_service.dart';

class Cargo {
  final int idMinisterio;
  final String ministerio;
  final String cargo;

  Cargo({
    required this.idMinisterio,
    required this.ministerio,
    required this.cargo,
  });

  String get etiqueta => '$cargo en $ministerio';

  factory Cargo.fromJson(Map<String, dynamic> json) => Cargo(
        idMinisterio: json['id_ministerio'],
        ministerio: json['ministerio'],
        cargo: json['cargo'],
      );
}

class Usuario {
  final int id;
  final String nombre;
  final String apellido;
  final String correo;
  final String? celular;
  final String rol;
  final bool activo;
  final List<Cargo> cargos;

  Usuario({
    required this.id,
    required this.nombre,
    required this.apellido,
    required this.correo,
    this.celular,
    required this.rol,
    required this.activo,
    this.cargos = const [],
  });

  String get nombreCompleto => '$nombre $apellido';

  factory Usuario.fromJson(Map<String, dynamic> json) => Usuario(
        id: json['id_usuario'],
        nombre: json['nombre'],
        apellido: json['apellido'],
        correo: json['correo'],
        celular: json['celular'],
        rol: json['rol'],
        activo: json['activo'],
        cargos: [
          for (final c in (json['cargos'] as List? ?? []))
            Cargo.fromJson(c as Map<String, dynamic>),
        ],
      );
}

class UsuariosService {
  Future<Map<String, String>> _cabeceras() async {
    final token = await AuthService().obtenerToken();
    return {
      'Content-Type': 'application/json; charset=utf-8',
      'Authorization': 'Bearer $token',
    };
  }

  Future<List<Usuario>> listar() async {
    final r = await http
        .get(Uri.parse('${ApiConfig.baseUrl}/usuarios'),
            headers: await _cabeceras())
        .timeout(const Duration(seconds: 10));
    if (r.statusCode != 200) {
      throw Exception('No se pudo cargar la lista');
    }
    final lista = jsonDecode(utf8.decode(r.bodyBytes)) as List;
    return lista.map((e) => Usuario.fromJson(e)).toList();
  }

  /// Devuelve null si se creó, o el mensaje de error.
  Future<String?> crear({
    required String nombre,
    required String apellido,
    required String correo,
    required String password,
    required String rol,
    String? celular,
  }) async {
    final r = await http
        .post(
          Uri.parse('${ApiConfig.baseUrl}/usuarios'),
          headers: await _cabeceras(),
          body: jsonEncode({
            'nombre': nombre,
            'apellido': apellido,
            'correo': correo,
            'password': password,
            'rol': rol,
            if (celular != null && celular.isNotEmpty) 'celular': celular,
          }),
        )
        .timeout(const Duration(seconds: 10));
    if (r.statusCode == 201) return null;
    final datos = jsonDecode(utf8.decode(r.bodyBytes));
    return datos['error'] ?? 'No se pudo crear el usuario';
  }

  /// Asigna o cambia el cargo del usuario en un ministerio.
  Future<String?> asignarCargo(int idUsuario, int idMinisterio, String rol) async {
    final r = await http
        .post(
          Uri.parse('${ApiConfig.baseUrl}/usuarios/$idUsuario/membresias'),
          headers: await _cabeceras(),
          body: jsonEncode({'idMinisterio': idMinisterio, 'rol': rol}),
        )
        .timeout(const Duration(seconds: 10));
    if (r.statusCode == 201) return null;
    final datos = jsonDecode(utf8.decode(r.bodyBytes));
    return datos['error'] ?? 'No se pudo asignar el cargo';
  }

  /// Revoca el cargo del usuario en un ministerio. Devuelve null si salió bien.
  Future<String?> revocarCargo(int idUsuario, int idMinisterio) async {
    final r = await http
        .delete(
          Uri.parse(
              '${ApiConfig.baseUrl}/usuarios/$idUsuario/membresias/$idMinisterio'),
          headers: await _cabeceras(),
        )
        .timeout(const Duration(seconds: 10));
    if (r.statusCode == 200) return null;
    final datos = jsonDecode(utf8.decode(r.bodyBytes));
    return datos['error'] ?? 'No se pudo revocar el cargo';
  }

  /// Devuelve null si se cambió, o el mensaje de error.
  Future<String?> cambiarPassword(int idUsuario, String password) async {
    final r = await http
        .put(
          Uri.parse('${ApiConfig.baseUrl}/usuarios/$idUsuario/password'),
          headers: await _cabeceras(),
          body: jsonEncode({'password': password}),
        )
        .timeout(const Duration(seconds: 10));
    if (r.statusCode == 200) return null;
    final datos = jsonDecode(utf8.decode(r.bodyBytes));
    return datos['error'] ?? 'No se pudo cambiar la contraseña';
  }
}