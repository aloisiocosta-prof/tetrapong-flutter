import 'remote_socket_contract.dart';

class BrowserRemoteSocket implements RemoteSocketAdapter {
  @override
  bool connected = false;
  @override
  void connect(
    String url,
    RemotePaddleCallback onPaddle,
    RemoteStatusCallback onStatus,
  ) {
    connected = false;
    onStatus(false);
  }

  @override
  void sendPaddle(double y) {}
  @override
  void dispose() {}
}
