import 'package:flutter/material.dart';
import '../services/movimientos_service.dart';
import 'movimientos_screen.dart';

class MisMinisteriosScreen extends StatefulWidget {
  const MisMinisteriosScreen({super.key});

  @override
  State<MisMinisteriosScreen> createState() => _MisMinisteriosScreenState();
}

class _MisMinisteriosScreenState extends State<MisMinisteriosScreen> {
  final _servicio = MovimientosService();
  late Future<List<MiMinisterio>> _futuro;

  @override
  void initState() {
    super.initState();
    _futuro = _servicio.misMinisterios();
  }

  void _recargar() {
    setState(() {
      _futuro = _servicio.misMinisterios();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mis ministerios')),
      body: FutureBuilder<List<MiMinisterio>>(
        future: _futuro,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('No se pudo cargar la lista'),
                  const SizedBox(height: 8),
                  FilledButton(
                      onPressed: _recargar, child: const Text('Reintentar')),
                ],
              ),
            );
          }
          final lista = snapshot.data!;
          if (lista.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Aún no tienes un cargo en ningún ministerio. '
                  'Pídele al administrador que te asigne uno.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => _recargar(),
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: lista.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final m = lista[i];
                return ListTile(
                  leading: Icon(m.esPrivado ? Icons.lock : Icons.groups),
                  title: Text(m.nombre),
                  subtitle: Text('Cargo: ${m.cargo}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => MovimientosScreen(ministerio: m),
                      ),
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}
