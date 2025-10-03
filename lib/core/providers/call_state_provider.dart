import 'package:flutter/material.dart';
import '../services/agora_service.dart';

class CallStateProvider extends ChangeNotifier {
  final AgoraService _agoraService = AgoraService.instance;
  bool _isMinimized = false;
  bool _showFloatingWidget = false;

  bool get isMinimized => _isMinimized;
  bool get showFloatingWidget => _showFloatingWidget;
  bool get isCallActive => _agoraService.isCallActive;
  bool get isScreenSharing => _agoraService.isScreenSharing;
  int? get remoteUid => _agoraService.remoteUid;
  AgoraService get agoraService => _agoraService;

  void toggleMinimize() {
    _isMinimized = !_isMinimized;
    notifyListeners();
  }

  void setMinimized(bool value) {
    _isMinimized = value;
    notifyListeners();
  }

  void setShowFloatingWidget(bool value) {
    _showFloatingWidget = value;
    notifyListeners();
  }

  void updateCallState() {
    // Check if we should show floating widget
    _showFloatingWidget = _agoraService.isCallActive;
    notifyListeners();
  }

  void hideFloatingWidget() {
    _showFloatingWidget = false;
    _isMinimized = false;
    notifyListeners();
  }

  void showFloatingWidgetIfCallActive() {
    if (_agoraService.isCallActive) {
      _showFloatingWidget = true;
      notifyListeners();
    }
  }
}
