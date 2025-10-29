import 'package:socket_io_client/socket_io_client.dart' as IO;

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  late IO.Socket socket;
  bool _isConnected = false;
  int? _usuarioId;
  String? _tipoUsuario;

  // ==============================
  // 🔌 Conectar Socket
  // ==============================
  void connect() {
    if (_isConnected) return;

    socket = IO.io(
      'http://186.123.85.22:3000',
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .enableReconnection()
          .setReconnectionDelay(500)
          .setReconnectionAttempts(10)
          .build(),
    );

    socket.onConnect((_) {
      _isConnected = true;
      print('🟢 Conectado al servidor Socket.IO');

      // Si ya hay usuario autenticado, reemitir su conexión al reconectar
      if (_usuarioId != null && _tipoUsuario != null) {
        emitirConexionUsuario(_usuarioId!, _tipoUsuario!);
      }
    });

    socket.onDisconnect((_) {
      _isConnected = false;
      print('🔴 Desconectado del servidor Socket.IO');
    });

    _registerGlobalListeners();
  }

  // ==============================
  // 🎧 Listeners globales
  // ==============================
  void _registerGlobalListeners() {
    // 🔹 Usuarios
    socket.on('usuario_creado', (data) => print('👤 Usuario creado: $data'));
    socket.on('usuario_actualizado', (data) => print('✏️ Usuario actualizado: $data'));
    socket.on('usuario_eliminado', (data) => print('🗑 Usuario eliminado: $data'));
    socket.on('usuario_login', (data) => print('🔐 Usuario logueado: $data'));
    socket.on('usuario_estado', (data) => print('🧍 Estado usuario: $data'));

    // 🔹 Viajes
    socket.on('viaje_creado', (data) => print('🆕 Nuevo viaje: $data'));
    socket.on('viaje_asignado', (data) => print('🚕 Viaje asignado: $data'));
    socket.on('viaje_en_curso', (data) => print('▶️ Viaje en curso: $data'));
    socket.on('viaje_finalizado', (data) => print('🏁 Viaje finalizado: $data'));
    socket.on('viaje_cancelado', (data) => print('❌ Viaje cancelado: $data'));

    // 🔹 Otros
    socket.on('rol_actualizado', (data) => print('🔑 Rol actualizado: $data'));
    socket.on('genero_actualizado', (data) => print('🧩 Género actualizado: $data'));
  }

  // ==============================
  // 📤 Emitir eventos genéricos
  // ==============================
  void send(String event, dynamic data) {
    if (!_isConnected) {
      print('⚠️ No conectado al socket, no se puede emitir "$event"');
      return;
    }
    socket.emit(event, data);
    print('📤 Emitido $event: $data');
  }

  // ==============================
  // 🟢 Usuario Conectado
  // ==============================
  void emitirConexionUsuario(int idUsuario, String tipo) {
    _usuarioId = idUsuario;
    _tipoUsuario = tipo;

    if (!_isConnected) {
      print('⚠️ Intentando conectar antes de emitir usuario_conectado...');
      connect();
    }

    socket.emit('usuario_conectado', {
      'id_usuario': idUsuario,
      'tipo': tipo,
    });

    print('🟢 Emitido usuario_conectado: {id_usuario: $idUsuario, tipo: $tipo}');
  }

  // ==============================
  // 🔴 Usuario Desconectado
  // ==============================
  void emitirDesconexionUsuario() {
    if (_usuarioId == null || _tipoUsuario == null) {
      print('⚠️ No hay usuario registrado para desconectar.');
      return;
    }

    socket.emit('usuario_desconectado', {
      'id_usuario': _usuarioId,
      'tipo': _tipoUsuario,
    });

    print('🔴 Emitido usuario_desconectado: {id_usuario: $_usuarioId, tipo: $_tipoUsuario}');

    _usuarioId = null;
    _tipoUsuario = null;
  }

  // ==============================
  // 🔌 Desconectar socket
  // ==============================
  void disconnect() {
    emitirDesconexionUsuario();
    socket.disconnect();
    _isConnected = false;
    print('🔴 Socket desconectado manualmente');
  }

  bool get isConnected => _isConnected;
}
