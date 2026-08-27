typedef RemotePaddleCallback = void Function(double y);
typedef RemoteStatusCallback = void Function(bool connected);

abstract interface class RemoteSocketAdapter {
  bool get connected;
  void connect(
    String url,
    RemotePaddleCallback onPaddle,
    RemoteStatusCallback onStatus,
  );
  void sendPaddle(double y);
  void dispose();
}
