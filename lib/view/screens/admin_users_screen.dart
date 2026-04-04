import 'package:flutter/material.dart';
import '../../controllers/auth_controller.dart';
import '../../data/models/usuario_model.dart';

class AdminUsersScreen extends StatefulWidget {
  final AuthController authController;
  const AdminUsersScreen({super.key, required this.authController});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _filter = '';

  @override
  void initState() {
    super.initState();
    // Requerimiento: Cargar usuarios al iniciar la pantalla
    widget.authController.obtenerTodosLosUsuarios();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Buscar usuario...',
                  hintStyle: TextStyle(color: Colors.white70),
                  border: InputBorder.none,
                ),
                onChanged: (value) {
                  setState(() {
                    _filter = value.toLowerCase();
                  });
                },
              )
            : const Text('Gestión de Usuarios'),
        backgroundColor: const Color(0xFF2196F3),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  _filter = '';
                }
              });
            },
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: widget.authController,
        builder: (context, child) {
          if (widget.authController.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final usuarios = widget.authController.listaUsuarios.where((u) {
            return u.nombre.toLowerCase().contains(_filter) ||
                u.correo.toLowerCase().contains(_filter);
          }).toList();

          if (usuarios.isEmpty) {
            return Center(
              child: Text(
                _filter.isEmpty
                    ? 'No hay usuarios registrados.'
                    : 'No se encontraron coincidencias para "$_filter".',
                textAlign: TextAlign.center,
              ),
            );
          }

          return ListView.builder(
            itemCount: usuarios.length,
            itemBuilder: (context, index) {
              final user = usuarios[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: user.rol == 'admin'
                      ? Colors.red
                      : Colors.blue,
                  child: Text(
                    user.nombre.isNotEmpty ? user.nombre[0].toUpperCase() : '?',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                title: Text(user.nombre),
                subtitle: Text("${user.correo} - Rol: ${user.rol}"),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ✏️ BOTÓN DE EDITAR
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => _mostrarDialogoEditar(user),
                      tooltip: 'Editar Usuario',
                    ),
                    // 🗑️ BOTÓN DE ELIMINAR
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _confirmarEliminacion(user),
                      tooltip: 'Eliminar Usuario',
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  // ✨ NUEVO: DIÁLOGO PARA EDITAR USUARIO
  // ✨ NUEVO: DIÁLOGO PARA EDITAR USUARIO CON SEGURIDAD
  void _mostrarDialogoEditar(UsuarioModel usuario) {
    final primerNombreController = TextEditingController(text: usuario.primerNombre);
    final segundoNombreController = TextEditingController(text: usuario.segundoNombre);
    final primerApellidoController = TextEditingController(text: usuario.primerApellido);
    final segundoApellidoController = TextEditingController(text: usuario.segundoApellido);
    final passController =
        TextEditingController(); // 🟢 Controlador de contraseña
    String rolSeleccionado = usuario.rol;
    bool ocultarPass = true; // 🟢 Control del ojito

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Editar Usuario'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: primerNombreController,
                      decoration: const InputDecoration(
                        labelText: 'Primer Nombre *',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: segundoNombreController,
                      decoration: const InputDecoration(
                        labelText: 'Segundo Nombre',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: primerApellidoController,
                      decoration: const InputDecoration(
                        labelText: 'Primer Apellido *',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: segundoApellidoController,
                      decoration: const InputDecoration(
                        labelText: 'Segundo Apellido',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 15),
                    DropdownButtonFormField<String>(
                      value: rolSeleccionado,
                      decoration: const InputDecoration(
                        labelText: 'Rol del Sistema',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'operador',
                          child: Text('Operador'),
                        ),
                        DropdownMenuItem(
                          value: 'admin',
                          child: Text('Administrador'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null)
                          setStateDialog(() => rolSeleccionado = val);
                      },
                    ),
                    const SizedBox(height: 15),
                    // 🛡️ Campo de confirmación de contraseña
                    TextField(
                      controller: passController,
                      obscureText: ocultarPass,
                      decoration: InputDecoration(
                        labelText: 'Tu contraseña (Seguridad)',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.security),
                        suffixIcon: IconButton(
                          icon: Icon(
                            ocultarPass ? Icons.visibility_off : Icons.visibility,
                          ),
                          onPressed: () {
                            setStateDialog(() {
                              ocultarPass = !ocultarPass;
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    // 🛡️ VALIDACIÓN DE SEGURIDAD PARA EDICIÓN
                    if (passController.text !=
                        widget.authController.usuarioActual?.password) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Contraseña incorrecta. Operación cancelada.',
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return; // Detiene la edición si no coincide
                    }

                    // Construimos el usuario actualizado
                    final usuarioActualizado = UsuarioModel(
                      id: usuario.id,
                      primerNombre: primerNombreController.text.trim(),
                      segundoNombre: segundoNombreController.text.trim(),
                      primerApellido: primerApellidoController.text.trim(),
                      segundoApellido: segundoApellidoController.text.trim(),
                      correo: usuario.correo,
                      password: usuario.password,
                      esTemporal: usuario.esTemporal,
                      rol: rolSeleccionado,
                    );

                    final exito = await widget.authController
                        .actualizarDatosUsuario(usuarioActualizado);
                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            exito
                                ? 'Usuario actualizado exitosamente'
                                : 'Error al actualizar',
                          ),
                          backgroundColor: exito ? Colors.green : Colors.red,
                        ),
                      );
                    }
                  },
                  child: const Text('Guardar Cambios'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // 🛡️ ACTUALIZADO: DIÁLOGO DE ELIMINAR CON CONFIRMACIÓN DE CLAVE
  void _confirmarEliminacion(UsuarioModel usuario) {
    final passController = TextEditingController();
    bool ocultarPass = true;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('¿Eliminar usuario?'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Estás a punto de borrar a ${usuario.nombre}. Por seguridad, ingresa TU contraseña de administrador:',
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: passController,
                    obscureText: ocultarPass,
                    decoration: InputDecoration(
                      labelText: 'Tu contraseña',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.security),
                      suffixIcon: IconButton(
                        icon: Icon(
                          ocultarPass ? Icons.visibility_off : Icons.visibility,
                        ),
                        onPressed: () {
                          setStateDialog(() {
                            ocultarPass = !ocultarPass;
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: () async {
                    // 🛡️ VALIDACIÓN DE SEGURIDAD
                    if (passController.text !=
                        widget.authController.usuarioActual?.password) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Contraseña incorrecta. Operación cancelada.',
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return; // No se elimina
                    }

                    final id = usuario.id;
                    if (id == null) return;

                    final exito = await widget.authController.eliminarUsuario(
                      id,
                    );
                    if (mounted) {
                      Navigator.pop(context);
                      if (!exito &&
                          widget.authController.errorMessage.isNotEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(widget.authController.errorMessage),
                            backgroundColor: Colors.red,
                          ),
                        );
                      } else if (exito) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Usuario eliminado con éxito.'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    }
                  },
                  child: const Text(
                    'Eliminar Definitivamente',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
