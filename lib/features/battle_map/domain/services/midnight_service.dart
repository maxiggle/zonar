import 'dart:async';
import 'dart:convert';
import 'package:webview_flutter/webview_flutter.dart';

class MidnightService {
  late final WebViewController _webViewController;
  final StreamController<Map<String, dynamic>> _zkResponseController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get onZKPayloadReceived =>
      _zkResponseController.stream;

  void initializeEngine() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'MidnightBridgeChannel',
        onMessageReceived: (JavaScriptMessage message) {
          final Map<String, dynamic> payload =
              jsonDecode(message.message) as Map<String, dynamic>;
          _zkResponseController.add(payload);
        },
      )
      ..loadFlutterAsset('assets/midnight_runtime.html');
  }

  Future<void> evaluateMoveOnChain(int index) async {
    await _webViewController.runJavaScript('window.executeAttackProof($index);');
  }

  void dispose() {
    _zkResponseController.close();
  }
}
