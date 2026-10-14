import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'ministerios_screen.dart';
import 'mis_ministerios_screen.dart';
import 'usuarios_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _storage = FlutterSecureStorage();
  String _nombre = '';
  String _rol = '';

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    final nombre = await _storage.read(key: 'nombre');
    final rol = await _storage.read(key: 'rol');
    if (!mounted) return;
    setState(() {
      _nombre = nombre ?? '';
      _rol = rol ?? '';
    });
  }

  Future<void> _cerrarSesion() async {
    await AuthService().cerrarSesion();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  void _abrir(Widget pantalla) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => pantalla));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Finanzas JER'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: _cerrarSesion,
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, size: 64, color: Colors.green),
            const SizedBox(height: 16),
            Text('Bienvenido, $_nombre',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('Rol: $_rol'),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: const Icon(Icons.account_balance_wallet),
              label: const Text('Finanzas'),
              onPressed: () => _abrir(const MisMinisteriosScreen()),
            ),
            if (_rol == 'admin' || _rol == 'pastor') ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                icon: const Icon(Icons.groups),
                label: const Text('Ministerios'),
                onPressed: () =>
                    _abrir(MinisteriosScreen(puedeCrear: _rol == 'admin')),
              ),
            ],
            if (_rol == 'admin') ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                icon: const Icon(Icons.people),
                label: const Text('Usuarios'),
                onPressed: () => _abrir(const UsuariosScreen()),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
