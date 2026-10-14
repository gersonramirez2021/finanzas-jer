import 'package:flutter/material.dart';
import '../services/ministerios_service.dart';

class MinisteriosScreen extends StatefulWidget {
  final bool puedeCrear;
  const MinisteriosScreen({super.key, required this.puedeCrear});

  @override
  State<MinisteriosScreen> createState() => _MinisteriosScreenState();
}

class _MinisteriosScreenState extends State<MinisteriosScreen> {
  final _servicio = MinisteriosService();
  late Future<List<Ministerio>> _futuro;

  @override
  void initState() {
    super.initState();
    _futuro = _servicio.listar();
  }

  void _recargar() {
    setState(() {
      _futuro = _servicio.listar();
    });
  }

  Future<void> _dialogoCrear() async {
    final nombreCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String? error;
    bool guardando = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Nuevo ministerio'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombreCtrl,
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(labelText: 'Descripción'),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(error!,
                      style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: guardando
                  ? null
                  : () async {
                      final nombre = nombreCtrl.text.trim();
                      if (nombre.length < 2) {
                        setD(() => error = 'El nombre es muy corto');
                        return;
                      }
                      setD(() {
                        guardando = true;
                        error = null;
                      });
                      final r = await _servicio.crear(nombre, descCtrl.text.trim());
                      if (r == null) {
                        if (ctx.mounted) Navigator.pop(ctx);
                      } else {
                        setD(() {
                          guardando = false;
                          error = r;
                        });
                      }
                    },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );

    if (mounted) _recargar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ministerios')),
      floatingActionButton: widget.puedeCrear
          ? FloatingActionButton(
              onPressed: _dialogoCrear,
              child: const Icon(Icons.add),
            )
          : null,
      body: FutureBuilder<List<Ministerio>>(
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
                  FilledButton(onPressed: _recargar, child: const Text('Reintentar')),
                ],
              ),
            );
          }
          final lista = snapshot.data!;
          if (lista.isEmpty) {
            return const Center(child: Text('No hay ministerios'));
          }
          return RefreshIndicator(
            onRefresh: () async => _recargar(),
            child: ListView.separated(
              itemCount: lista.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final m = lista[i];
                return ListTile(
                  leading: const Icon(Icons.groups),
                  title: Text(m.nombre),
                  subtitle: m.descripcion != null ? Text(m.descripcion!) : null,
                  trailing: m.activo ? null : const Chip(label: Text('Inactivo')),
                );
              },
            ),
          );
        },
      ),
    );
  }
}