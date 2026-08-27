import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'remote_socket_contract.dart';

class BrowserRemoteSocket implements RemoteSocketAdapter {
  web.WebSocket? _socket;
  @override
  bool connected = false;

  @override
  void connect(
    String url,
    RemotePaddleCallback onPaddle,
    RemoteStatusCallback onStatus,
  ) {
    dispose();
    try {
      final socket = web.WebSocket(url);
      _socket = socket;
      socket.onopen = ((web.Event _) {
        connected = true;
        onStatus(true);
      }).toJS;
      socket.onclose = ((web.CloseEvent _) {
        connected = false;
        onStatus(false);
      }).toJS;
      socket.onerror = ((web.Event _) {
        connected = false;
        onStatus(false);
      }).toJS;
      socket.onmessage = ((web.MessageEvent event) {
        final data = event.data?.dartify();
        if (data is String) {
          try {
            final decoded = jsonDecode(data);
            if (decoded is Map && decoded['type'] == 'paddle') {
              onPaddle((decoded['y'] as num).toDouble().clamp(.15, .85));
            }
          } catch (_) {}
        }
      }).toJS;
    } catch (_) {
      connected = false;
      onStatus(false);
    }
  }

  @override
  void sendPaddle(double y) {
    final socket = _socket;
    if (socket != null && connected) {
      socket.send(jsonEncode({'type': 'paddle', 'player': 2, 'y': y}).toJS);
    }
  }

  @override
  void dispose() {
    _socket?.close();
    _socket = null;
    connected = false;
  }
}
