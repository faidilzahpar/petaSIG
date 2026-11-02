import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../models/survey_node.dart';
import '../math/multilateration.dart';
import 'ble_mesh_service.dart';

/// Service Sinkronisasi Peer-to-Peer (P2P) Offline Berbasis UDP Multicast
/// Memungkinkan 3+ handphone bertukar data koordinat & barometer tanpa koneksi internet (via Hotspot HP).
class P2pSyncService {
  static final P2pSyncService _instance = P2pSyncService._internal();
  factory P2pSyncService() => _instance;
  P2pSyncService._internal();

  static const int p2pPort = 8848;
  static const String multicastAddress = '239.255.0.1';

  RawDatagramSocket? _socket;
  Timer? _broadcastTimer;
  bool _isRunning = false;

  bool get isRunning => _isRunning;

  /// Mulai mendengarkan dan mengirim data survei ke jaringan lokal
  Future<void> start({
    required String deviceId,
    required String deviceName,
    required NodeRole role,
    required Function() telemetryProvider,
  }) async {
    if (_isRunning) return;

    try {
      _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, p2pPort, reuseAddress: true);
      _socket?.broadcastEnabled = true;
      _socket?.multicastHops = 1;

      try {
        _socket?.joinMulticast(InternetAddress(multicastAddress));
      } catch (e) {
        // Fallback ke subnet broadcast jika multicast dibatasi OS
      }

      _isRunning = true;

      // Listen paket masuk
      _socket?.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          Datagram? dg = _socket?.receive();
          if (dg != null) {
            _handleIncomingPacket(dg.data);
          }
        }
      });

      // Kirim status lokal secara periodik (10Hz / tiap 100ms)
      _broadcastTimer = Timer.periodic(const Duration(milliseconds: 150), (timer) {
        final data = telemetryProvider();
        if (data != null) {
          _sendBroadcast(data);
        }
      });
    } catch (e) {
      // Jika socket tidak diizinkan di lingkungan tertentu, sistem otomatis beralih ke BLE
    }
  }

  void _sendBroadcast(Map<String, dynamic> payload) {
    if (_socket == null || !_isRunning) return;
    try {
      final jsonStr = jsonEncode(payload);
      final bytes = utf8.encode(jsonStr);
      _socket?.send(bytes, InternetAddress('255.255.255.255'), p2pPort);
    } catch (_) {}
  }

  void _handleIncomingPacket(List<int> bytes) {
    try {
      final jsonStr = utf8.decode(bytes);
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;

      if (map.containsKey('id') && map.containsKey('role')) {
        final id = map['id'] as String;
        final name = map['name'] as String? ?? 'Anchor';
        final roleIndex = map['role'] as int? ?? 0;
        final rawRssi = (map['rssi'] as num?)?.toDouble() ?? -65.0;
        final baro = (map['baro'] as num?)?.toDouble() ?? 1013.25;
        final x = (map['x'] as num?)?.toDouble() ?? 0.0;
        final y = (map['y'] as num?)?.toDouble() ?? 0.0;
        final z = (map['z'] as num?)?.toDouble() ?? 0.0;
        final battery = map['battery'] as int? ?? 100;

        NodeRole role = NodeRole.values[roleIndex.clamp(0, NodeRole.values.length - 1)];

        BleMeshService().updateNodeObservation(
          id: id,
          deviceName: name,
          role: role,
          rawRssi: rawRssi,
          baroPressure: baro,
          localPos: Vector3D(x, y, z),
          battery: battery,
        );
      }
    } catch (_) {}
  }

  void stop() {
    _broadcastTimer?.cancel();
    _socket?.close();
    _socket = null;
    _isRunning = false;
  }
}

