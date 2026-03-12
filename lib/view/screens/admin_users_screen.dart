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
                  _filter = value.toLowerCase(); // Actualiza el filtro dinámico
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
                  _filter = ''; // Limpia el filtro al cerrar la búsqueda
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

          // Filtrado en memoria para máxima velocidad en el celular
          final usuarios = widget.authController.listaUsuarios.where((u) {
            return u.nombre.toLowerCase().contains(_filter) || 
                   u.correo.toLowerCase().contains(_filter);
          }).toList();

          if (usuarios.isEmpty) {
            // SOLUCIÓN AL ERROR: Eliminado el 'const' de Center para permitir texto dinámico
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
                  backgroundColor: user.rol == 'admin' ? Colors.red : Colors.blue,
                  child: Text(
                    user.nombre.isNotEmpty ? user.nombre[0].toUpperCase() : '?', 
                    style: const TextStyle(color: Colors.white)
                  ),
                ),
                title: Text(user.nombre),
                subtitle: Text("${user.correo} - Rol: ${user.rol}"),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _confirmarEliminacion(user),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _confirmarEliminacion(UsuarioModel usuario) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar usuario?'),
        content: Text('Esta acción borrará a ${usuario.nombre} del sistema.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: const Text('Cancelar')
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final id = usuario.id;
              if (id == null) {
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('No se puede eliminar este usuario porque no tiene un ID válido.'),
                    ),
                  );
                }
                return;
              }
              final exito = await widget.authController.eliminarUsuario(id);
              if (mounted) {
                Navigator.pop(context);
                if (!exito && widget.authController.errorMessage.isNotEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(widget.authController.errorMessage)),
                  );
                }
              }
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}