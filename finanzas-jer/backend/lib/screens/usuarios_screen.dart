import 'package:flutter/material.dart';
import '../services/ministerios_service.dart';
import '../services/usuarios_service.dart';

class UsuariosScreen extends StatefulWidget {
  const UsuariosScreen({super.key});

  @override
  State<UsuariosScreen> createState() => _UsuariosScreenState();
}

class _UsuariosScreenState extends State<UsuariosScreen> {
  final _servicio = UsuariosService();
  late Future<List<Usuario>> _futuro;

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

  void _mensaje(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<void> _dialogoCrear() async {
    final nombreCtrl = TextEditingController();
    final apellidoCtrl = TextEditingController();
    final correoCtrl = TextEditingController();
    final celularCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    String rol = 'miembro';
    String? error;
    bool guardando = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Nuevo usuario'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nombreCtrl,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                ),
                TextField(
                  controller: apellidoCtrl,
                  decoration: const InputDecoration(labelText: 'Apellido'),
                ),
                TextField(
                  controller: correoCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Correo'),
                ),
                TextField(
                  controller: celularCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Celular (opcional)'),
                ),
                TextField(
                  controller: passwordCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Contraseña temporal (mín. 8)',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: rol,
                  decoration: const InputDecoration(labelText: 'Rol del sistema'),
                  items: const [
                    DropdownMenuItem(value: 'miembro', child: Text('Miembro')),
                    DropdownMenuItem(value: 'pastor', child: Text('Pastor')),
                    DropdownMenuItem(value: 'admin', child: Text('Administrador')),
                  ],
                  onChanged: (v) => setD(() => rol = v ?? 'miembro'),
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(error!,
                        style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
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
                      if (nombreCtrl.text.trim().length < 2 ||
                          apellidoCtrl.text.trim().length < 2 ||
                          !correoCtrl.text.contains('@') ||
                          passwordCtrl.text.length < 8) {
                        setD(() => error = 'Revisa los datos (contraseña mín. 8)');
                        return;
                      }
                      setD(() {
                        guardando = true;
                        error = null;
                      });
                      final r = await _servicio.crear(
                        nombre: nombreCtrl.text.trim(),
                        apellido: apellidoCtrl.text.trim(),
                        correo: correoCtrl.text.trim(),
                        password: passwordCtrl.text,
                        rol: rol,
                        celular: celularCtrl.text.trim(),
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
        ),
      ),
    );

    if (mounted) _recargar();
  }

  Future<void> _dialogoCargo(Usuario usuario) async {
    List<Ministerio> ministerios;
    try {
      ministerios = await MinisteriosService().listar();
    } catch (_) {
      if (!mounted) return;
      _mensaje('No se pudieron cargar los ministerios');
      return;
    }
    if (!mounted) return;

    final disponibles = ministerios.where((m) => m.activo).toList();
    if (disponibles.isEmpty) {
      _mensaje('Primero crea un ministerio');
      return;
    }

    int idMinisterio = disponibles.first.id;
    String cargo = 'integrante';
    String? error;
    bool guardando = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text('Cargo de ${usuario.nombreCompleto}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                value: idMinisterio,
                decoration: const InputDecoration(labelText: 'Ministerio'),
                items: [
                  for (final m in disponibles)
                    DropdownMenuItem(value: m.id, child: Text(m.nombre)),
                ],
                onChanged: (v) => setD(() => idMinisterio = v ?? idMinisterio),
              ),
              DropdownButtonFormField<String>(
                value: cargo,
                decoration: const InputDecoration(labelText: 'Cargo'),
                items: const [
                  DropdownMenuItem(value: 'presidente', child: Text('Presidente')),
                  DropdownMenuItem(value: 'secretario', child: Text('Secretario')),
                  DropdownMenuItem(value: 'tesorero', child: Text('Tesorero')),
                  DropdownMenuItem(value: 'integrante', child: Text('Integrante')),
                ],
                onChanged: (v) => setD(() => cargo = v ?? cargo),
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
                      setD(() {
                        guardando = true;
                        error = null;
                      });
                      final r = await _servicio.asignarCargo(
                          usuario.id, idMinisterio, cargo);
                      if (r == null) {
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) _mensaje('Cargo asignado');
                      } else {
                        setD(() {
                          guardando = false;
                          error = r;
                        });
                      }
                    },
              child: const Text('Asignar'),
            ),
          ],
        ),
      ),
    );

    if (mounted) _recargar();
  }

  Future<void> _dialogoRevocar(Usuario usuario) async {
    if (usuario.cargos.isEmpty) {
      _mensaje('${usuario.nombreCompleto} no tiene cargos activos');
      return;
    }

    // 1) Elegir qué cargo revocar
    final elegido = await showDialog<Cargo>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Revocar cargo de ${usuario.nombreCompleto}'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final c in usuario.cargos)
                ListTile(
                  leading: const Icon(Icons.person_remove_outlined),
                  title: Text(c.cargo),
                  subtitle: Text(c.ministerio),
                  onTap: () => Navigator.pop(ctx, c),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
    if (elegido == null || !mounted) return;

    // 2) Confirmar
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Revocar cargo?'),
        content: Text(
          '${usuario.nombreCompleto} dejará de ser ${elegido.cargo} en '
          '${elegido.ministerio} y ya no podrá realizar acciones de ese cargo.\n\n'
          'Los movimientos que ya registró o aprobó se conservan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Revocar'),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;

    // 3) Revocar
    final error = await _servicio.revocarCargo(usuario.id, elegido.idMinisterio);
    if (!mounted) return;
    _mensaje(error ?? 'Cargo revocado');
    _recargar();
  }

  Future<void> _dialogoPassword(Usuario usuario) async {
    final passwordCtrl = TextEditingController();
    String? error;
    bool guardando = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text('Contraseña de ${usuario.nombreCompleto}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: passwordCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nueva contraseña (mín. 8)',
                ),
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
                      if (passwordCtrl.text.length < 8) {
                        setD(() => error = 'Mínimo 8 caracteres');
                        return;
                      }
                      setD(() {
                        guardando = true;
                        error = null;
                      });
                      final r = await _servicio.cambiarPassword(
                          usuario.id, passwordCtrl.text);
                      if (r == null) {
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) _mensaje('Contraseña actualizada');
                      } else {
                        setD(() {
                          guardando = false;
                          error = r;
                        });
                      }
                    },
              child: const Text('Cambiar'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Usuarios')),
      floatingActionButton: FloatingActionButton(
        onPressed: _dialogoCrear,
        child: const Icon(Icons.person_add),
      ),
      body: FutureBuilder<List<Usuario>>(
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
          return RefreshIndicator(
            onRefresh: () async => _recargar(),
            child: ListView.separated(
              itemCount: lista.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final u = lista[i];
                return ListTile(
                  leading: const Icon(Icons.person),
                  title: Text(u.nombreCompleto),
                  subtitle: Text(
                    '${u.correo} • ${u.rol}'
                    '${u.cargos.isEmpty ? '' : '\n${u.cargos.map((c) => c.etiqueta).join('\n')}'}',
                  ),
                  isThreeLine: u.cargos.isNotEmpty,
                  trailing: PopupMenuButton<String>(
                    tooltip: 'Acciones',
                    onSelected: (accion) {
                      switch (accion) {
                        case 'asignar':
                          _dialogoCargo(u);
                        case 'revocar':
                          _dialogoRevocar(u);
                        case 'password':
                          _dialogoPassword(u);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'asignar',
                        child: ListTile(
                          leading: Icon(Icons.badge_outlined),
                          title: Text('Asignar cargo'),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'revocar',
                        child: ListTile(
                          leading: Icon(Icons.person_remove_outlined),
                          title: Text('Revocar cargo'),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'password',
                        child: ListTile(
                          leading: Icon(Icons.key),
                          title: Text('Cambiar contraseña'),
                        ),
                      ),
                    ],
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