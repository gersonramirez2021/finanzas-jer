import 'package:flutter/material.dart';
import '../services/movimientos_service.dart';

class MovimientosScreen extends StatefulWidget {
  final MiMinisterio ministerio;
  const MovimientosScreen({super.key, required this.ministerio});

  @override
  State<MovimientosScreen> createState() => _MovimientosScreenState();
}

class _MovimientosScreenState extends State<MovimientosScreen> {
  final _servicio = MovimientosService();
  late Future<List<Movimiento>> _futuro;

  MiMinisterio get _m => widget.ministerio;

  // Tesorero registra; en Pastoral (privado) lo hace el pastor
  bool get _puedeRegistrar =>
      _m.cargo == 'tesorero' || (_m.esPrivado && _m.cargo == 'pastor');
  bool get _puedeDecidir =>
      _m.cargo == 'presidente' || (_m.esPrivado && _m.cargo == 'pastor');

  @override
  void initState() {
    super.initState();
    _futuro = _servicio.listar(_m.id);
  }

  void _recargar() {
    setState(() {
      _futuro = _servicio.listar(_m.id);
    });
  }

  void _mensaje(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  Color _colorEstado(String estado) {
    switch (estado) {
      case 'aprobado':
        return Colors.green;
      case 'rechazado':
        return Colors.red;
      case 'anulado':
        return Colors.grey;
      default:
        return Colors.orange;
    }
  }

  double _saldo(List<Movimiento> lista) {
    double total = 0;
    for (final mv in lista) {
      if (mv.estado != 'aprobado') continue;
      total += mv.tipo == 'ingreso' ? mv.monto : -mv.monto;
    }
    return total;
  }

  Future<void> _decidir(Movimiento mv, String decision) async {
    final error = await _servicio.decidir(mv.id, decision);
    if (!mounted) return;
    _mensaje(error ??
        (decision == 'aprobado' ? 'Movimiento aprobado' : 'Movimiento rechazado'));
    _recargar();
  }

  Future<void> _dialogoRegistrar() async {
    List<Categoria> categorias;
    try {
      final ingresos = await _servicio.categorias('ingreso', _m.id);
      final egresos = await _servicio.categorias('egreso', _m.id);
      categorias = [...ingresos, ...egresos];
    } catch (_) {
      if (!mounted) return;
      _mensaje('No se pudieron cargar las categorías');
      return;
    }
    if (!mounted) return;

    final montoCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String tipo = 'ingreso';
    int? idCategoria;
    String? error;
    bool guardando = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) {
          final opciones = categorias.where((c) => c.tipo == tipo).toList();
          if (idCategoria == null || !opciones.any((c) => c.id == idCategoria)) {
            idCategoria = opciones.isEmpty ? null : opciones.first.id;
          }
          return AlertDialog(
            title: const Text('Nuevo movimiento'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: tipo,
                    decoration: const InputDecoration(labelText: 'Tipo'),
                    items: const [
                      DropdownMenuItem(value: 'ingreso', child: Text('Ingreso')),
                      DropdownMenuItem(value: 'egreso', child: Text('Egreso')),
                    ],
                    onChanged: (v) => setD(() => tipo = v ?? tipo),
                  ),
                  DropdownButtonFormField<int>(
                    value: idCategoria,
                    decoration: const InputDecoration(labelText: 'Categoría'),
                    items: [
                      for (final c in opciones)
                        DropdownMenuItem(value: c.id, child: Text(c.nombre)),
                    ],
                    onChanged: (v) => setD(() => idCategoria = v),
                  ),
                  TextField(
                    controller: montoCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Monto (USD)'),
                  ),
                  TextField(
                    controller: descCtrl,
                    decoration: const InputDecoration(labelText: 'Descripción'),
                  ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(error!,
                          style: TextStyle(
                              color: Theme.of(ctx).colorScheme.error)),
                    ),
                ],
              ),
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
                        final monto = double.tryParse(
                            montoCtrl.text.trim().replaceAll(',', '.'));
                        if (monto == null || monto <= 0 || idCategoria == null) {
                          setD(() => error = 'Revisa el monto y la categoría');
                          return;
                        }
                        setD(() {
                          guardando = true;
                          error = null;
                        });
                        final r = await _servicio.registrar(
                          idMinisterio: _m.id,
                          idCategoria: idCategoria!,
                          tipo: tipo,
                          monto: monto,
                          descripcion: descCtrl.text.trim(),
                        );
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
          );
        },
      ),
    );

    if (mounted) _recargar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_m.nombre)),
      floatingActionButton: _puedeRegistrar
          ? FloatingActionButton(
              onPressed: _dialogoRegistrar,
              child: const Icon(Icons.add),
            )
          : null,
      body: FutureBuilder<List<Movimiento>>(
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
          return RefreshIndicator(
            onRefresh: () async => _recargar(),
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: lista.length + 1,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                if (i == 0) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Text('Saldo (solo movimientos aprobados)'),
                        const SizedBox(height: 4),
                        Text(
                          '\$${_saldo(lista).toStringAsFixed(2)}',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 4),
                        Text('Tu cargo: ${_m.cargo}'),
                        if (lista.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 24),
                            child: Text('Aún no hay movimientos'),
                          ),
                      ],
                    ),
                  );
                }
                final mv = lista[i - 1];
                final esIngreso = mv.tipo == 'ingreso';
                return ListTile(
                  leading: Icon(
                    esIngreso ? Icons.arrow_downward : Icons.arrow_upward,
                    color: esIngreso ? Colors.green : Colors.red,
                  ),
                  title: Text(
                      '${esIngreso ? '+' : '-'}\$${mv.monto.toStringAsFixed(2)} • ${mv.categoria}'),
                  subtitle: Text(
                    '${mv.fecha} • ${mv.registradoPor}'
                    '${mv.descripcion == null || mv.descripcion!.isEmpty ? '' : '\n${mv.descripcion}'}',
                  ),
                  isThreeLine:
                      mv.descripcion != null && mv.descripcion!.isNotEmpty,
                  trailing: (_puedeDecidir && mv.estado == 'pendiente')
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.check_circle,
                                  color: Colors.green),
                              tooltip: 'Aprobar',
                              onPressed: () => _decidir(mv, 'aprobado'),
                            ),
                            IconButton(
                              icon: const Icon(Icons.cancel, color: Colors.red),
                              tooltip: 'Rechazar',
                              onPressed: () => _decidir(mv, 'rechazado'),
                            ),
                          ],
                        )
                      : Chip(
                          label: Text(mv.estado),
                          side: BorderSide(color: _colorEstado(mv.estado)),
                        ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
