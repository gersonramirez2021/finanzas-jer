import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'auth_service.dart';

class MiMinisterio {
  final int id;
  final String nombre;
  final bool esPrivado;
  final String cargo;

  MiMinisterio({
    required this.id,
    required this.nombre,
    required this.esPrivado,
    required this.cargo,
  });

  factory MiMinisterio.fromJson(Map<String, dynamic> json) => MiMinisterio(
        id: json['id_ministerio'],
        nombre: json['nombre'],
        esPrivado: json['es_privado'] ?? false,
        cargo: json['cargo'],
      );
}

class Categoria {
  final int id;
  final String nombre;
  final String tipo;

  Categoria({required this.id, required this.nombre, required this.tipo});

  factory Categoria.fromJson(Map<String, dynamic> json) => Categoria(
        id: json['id_categoria'],
        nombre: json['nombre'],
        tipo: json['tipo'],
      );
}

class Movimiento {
  final int id;
  final String tipo;
  final double monto;
  final String? descripcion;
  final String fecha;
  final String estado;
  final String categoria;
  final String registradoPor;

  Movimiento({
    required this.id,
    required this.tipo,
    required this.monto,
    this.descripcion,
    required this.fecha,
    required this.estado,
    required this.categoria,
    required this.registradoPor,
  });

  factory Movimiento.fromJson(Map<String, dynamic> json) => Movimiento(
        id: json['id_movimiento'],
        tipo: json['tipo'],
        monto: double.parse(json['monto'].toString()),
        descripcion: json['descripcion'],
        fecha: json['fecha'],
        estado: json['estado'],
        categoria: json['categoria'],
        registradoPor: json['registrado_por'],
      );
}

class MovimientosService {
  Future<Map<String, String>> _cabeceras() async {
    final token = await AuthService().obtenerToken();
    return {
      'Content-Type': 'application/json; charset=utf-8',
      'Authorization': 'Bearer $token',
    };
  }

  dynamic _json(http.Response r) => jsonDecode(utf8.decode(r.bodyBytes));

  Future<List<MiMinisterio>> misMinisterios() async {
    final r = await http
        .get(Uri.parse('${ApiConfig.baseUrl}/mis-ministerios'),
            headers: await _cabeceras())
        .timeout(const Duration(seconds: 10));
    if (r.statusCode != 200) throw Exception('No se pudo cargar');
    return (_json(r) as List).map((e) => MiMinisterio.fromJson(e)).toList();
  }

  Future<List<Movimiento>> listar(int idMinisterio) async {
    final r = await http
        .get(Uri.parse('${ApiConfig.baseUrl}/movimientos?idMinisterio=$idMinisterio'),
            headers: await _cabeceras())
        .timeout(const Duration(seconds: 10));
    if (r.statusCode != 200) {
      throw Exception(_json(r)['error'] ?? 'No se pudo cargar');
    }
    return (_json(r) as List).map((e) => Movimiento.fromJson(e)).toList();
  }

  Future<List<Categoria>> categorias(String tipo, int idMinisterio) async {
    final r = await http
        .get(
            Uri.parse(
                '${ApiConfig.baseUrl}/categorias?tipo=$tipo&idMinisterio=$idMinisterio'),
            headers: await _cabeceras())
        .timeout(const Duration(seconds: 10));
    if (r.statusCode != 200) throw Exception('No se pudo cargar');
    return (_json(r) as List).map((e) => Categoria.fromJson(e)).toList();
  }

  /// Devuelve null si se registró, o el mensaje de error.
  Future<String?> registrar({
    required int idMinisterio,
    required int idCategoria,
    required String tipo,
    required double monto,
    String? descripcion,
  }) async {
    final r = await http
        .post(
          Uri.parse('${ApiConfig.baseUrl}/movimientos'),
          headers: await _cabeceras(),
          body: jsonEncode({
            'idMinisterio': idMinisterio,
            'idCategoria': idCategoria,
            'tipo': tipo,
            'monto': monto,
            if (descripcion != null && descripcion.isNotEmpty)
              'descripcion': descripcion,
          }),
        )
        .timeout(const Duration(seconds: 10));
    if (r.statusCode == 201) return null;
    return _json(r)['error'] ?? 'No se pudo registrar';
  }

  /// decision: 'aprobado' o 'rechazado'. Devuelve null si salió bien.
  Future<String?> decidir(int idMovimiento, String decision) async {
    final r = await http
        .post(
          Uri.parse('${ApiConfig.baseUrl}/movimientos/$idMovimiento/decision'),
          headers: await _cabeceras(),
          body: jsonEncode({'decision': decision}),
        )
        .timeout(const Duration(seconds: 10));
    if (r.statusCode == 200) return null;
    return _json(r)['error'] ?? 'No se pudo completar la acción';
  }
}
