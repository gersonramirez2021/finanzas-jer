import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'auth_service.dart';

class Ministerio {
  final int id;
  final String nombre;
  final String? descripcion;
  final bool activo;

  Ministerio({
    required this.id,
    required this.nombre,
    this.descripcion,
    required this.activo,
  });

  factory Ministerio.fromJson(Map<String, dynamic> json) => Ministerio(
        id: json['id_ministerio'],
        nombre: json['nombre'],
        descripcion: json['descripcion'],
        activo: json['activo'],
      );
}

class MinisteriosService {
  Future<Map<String, String>> _cabeceras() async {
    final token = await AuthService().obtenerToken();
    return {
      'Content-Type': 'application/json; charset=utf-8',
      'Authorization': 'Bearer $token',
    };
  }

  Future<List<Ministerio>> listar() async {
    final r = await http
        .get(Uri.parse('${ApiConfig.baseUrl}/ministerios'),
            headers: await _cabeceras())
        .timeout(const Duration(seconds: 10));
    if (r.statusCode != 200) {
      throw Exception('No se pudo cargar la lista');
    }
    final lista = jsonDecode(utf8.decode(r.bodyBytes)) as List;
    return lista.map((e) => Ministerio.fromJson(e)).toList();
  }

  /// Devuelve null si se creó, o el mensaje de error.
  Future<String?> crear(String nombre, String descripcion) async {
    final r = await http
        .post(
          Uri.parse('${ApiConfig.baseUrl}/ministerios'),
          headers: await _cabeceras(),
          body: jsonEncode({
            'nombre': nombre,
            if (descripcion.isNotEmpty) 'descripcion': descripcion,
          }),
        )
        .timeout(const Duration(seconds: 10));
    if (r.statusCode == 201) return null;
    final datos = jsonDecode(utf8.decode(r.bodyBytes));
    return datos['error'] ?? 'No se pudo crear el ministerio';
  }
}