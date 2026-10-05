import 'package:flutter/foundation.dart';
import 'package:sip_ua/sip_ua.dart';

/// Registration states exposed to the UI.
enum SipRegistrationState { unregistered, registering, registered, failed }

/// All the info the UI needs about the active call.
class ActiveCall {
  ActiveCall({
    required this.call,
    required this.remoteIdentity,
    this.isOnHold = false,
    this.isMuted = false,
    this.isIncoming = false,
  });

  final Call call;
  final String remoteIdentity;
  bool isOnHold;
  bool isMuted;
  bool isIncoming;
}

/// Central SIP service. One instance kept alive for the app's lifetime.
class SipService with ChangeNotifier implements SipUaHelperListener {
  // ── Balatrix / Kamailio config ──────────────────────────────────────────
  static const String _wsUrl = 'wss://demowlable.balatrix.com:7443';
  static const String _sipDomain = 'demowlable.balatrix.com';
  // ────────────────────────────────────────────────────────────────────────

  final SIPUAHelper _helper = SIPUAHelper();

  SipRegistrationState _regState = SipRegistrationState.unregistered;
  SipRegistrationState get registrationState => _regState;

  ActiveCall? _activeCall;
  ActiveCall? get activeCall => _activeCall;

  bool get isRegistered => _regState == SipRegistrationState.registered;

  String? _extension;
  String? get extension => _extension;

  // ── Lifecycle ────────────────────────────────────────────────────────────

  /// Register with the Balatrix Kamailio server.
  Future<void> register(String extension, String password) async {
    _extension = extension;
    _regState = SipRegistrationState.registering;
    notifyListeners();

    final settings = UaSettings();
    settings.webSocketUrl = _wsUrl;
    settings.webSocketSettings = WebSocketSettings();
    settings.uri = 'sip:$extension@$_sipDomain';
    settings.authorizationUser = extension;
    settings.password = password;
    settings.displayName = extension;
    settings.userAgent = 'Balatrix-Flutter-Softphone/1.0';
    settings.dtmfMode = DtmfMode.RFC2833;

    _helper.addSipUaHelperListener(this);
    await _helper.start(settings);
  }

  /// Unregister and disconnect.
  Future<void> unregister() async {
    if (_activeCall != null) {
      hangup();
    }
    _helper.stop();
    _helper.removeSipUaHelperListener(this);
    _extension = null;
    _regState = SipRegistrationState.unregistered;
    _activeCall = null;
    notifyListeners();
  }

  // ── Call control ─────────────────────────────────────────────────────────

  /// Make an outgoing call.
  void call(String destination) {
    if (!isRegistered) return;
    final target = destination.contains('@')
        ? destination
        : 'sip:$destination@$_sipDomain';
    _helper.call(target, voiceOnly: true);
  }

  /// Answer an incoming call.
  void answer() {
    final call = _activeCall?.call;
    if (call == null) return;
    call.answer(_helper.buildCallOptions());
  }

  /// Hang up / reject the active call.
  void hangup() {
    final call = _activeCall?.call;
    if (call == null) return;
    try {
      call.hangup({'status_code': 603});
    } catch (_) {}
  }

  /// Toggle hold.
  void toggleHold() {
    final ac = _activeCall;
    if (ac == null) return;
    if (ac.isOnHold) {
      ac.call.unhold();
    } else {
      ac.call.hold();
    }
  }

  /// Toggle mute.
  void toggleMute() {
    final ac = _activeCall;
    if (ac == null) return;
    if (ac.isMuted) {
      ac.call.unmute(true, false);
      ac.isMuted = false;
    } else {
      ac.call.mute(true, false);
      ac.isMuted = true;
    }
    notifyListeners();
  }

  /// Send a DTMF digit.
  void sendDtmf(String digit) {
    _activeCall?.call.sendDTMF(digit);
  }

  // ── SipUaHelperListener callbacks ────────────────────────────────────────

  @override
  void registrationStateChanged(RegistrationState state) {
    switch (state.state) {
      case RegistrationStateEnum.REGISTERED:
        _regState = SipRegistrationState.registered;
        break;
      case RegistrationStateEnum.UNREGISTERED:
        _regState = SipRegistrationState.unregistered;
        break;
      case RegistrationStateEnum.REGISTRATION_FAILED:
        _regState = SipRegistrationState.failed;
        break;
      default:
        _regState = SipRegistrationState.registering;
    }
    notifyListeners();
  }

  @override
  void callStateChanged(Call call, CallState state) {
    switch (state.state) {
      case CallStateEnum.CALL_INITIATION:
      case CallStateEnum.PROGRESS:
      case CallStateEnum.CONNECTING:
        if (_activeCall == null) {
          _activeCall = ActiveCall(
            call: call,
            remoteIdentity: _cleanIdentity(call.remote_identity ?? ''),
            isIncoming: false,
          );
        }
        break;

      case CallStateEnum.ACCEPTED:
        if (_activeCall != null) {
          _activeCall = ActiveCall(
            call: call,
            remoteIdentity: _activeCall!.remoteIdentity,
            isIncoming: _activeCall!.isIncoming,
          );
        }
        break;

      case CallStateEnum.HOLD:
        if (_activeCall != null) _activeCall!.isOnHold = true;
        break;

      case CallStateEnum.UNHOLD:
        if (_activeCall != null) _activeCall!.isOnHold = false;
        break;

      case CallStateEnum.MUTED:
        if (_activeCall != null) _activeCall!.isMuted = true;
        break;

      case CallStateEnum.UNMUTED:
        if (_activeCall != null) _activeCall!.isMuted = false;
        break;

      case CallStateEnum.ENDED:
      case CallStateEnum.FAILED:
        _activeCall = null;
        break;

      default:
        break;
    }
    notifyListeners();
  }

  @override
  void onNewMessage(SIPMessageRequest msg) {}
  @override
  void onNewNotify(Notify ntf) {}
  @override
  void onNewReinvite(ReInvite event) {}
  @override
  void transportStateChanged(TransportState state) {}

  // ── Incoming call ─────────────────────────────────────────────────────────

  /// Store an incoming INVITE so the UI can show a ringing dialog.
  void handleIncomingCall(Call call) {
    _activeCall = ActiveCall(
      call: call,
      remoteIdentity: _cleanIdentity(call.remote_identity ?? 'Unknown'),
      isIncoming: true,
    );
    notifyListeners();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _cleanIdentity(String raw) => raw
      .replaceAll(RegExp(r'sip:', caseSensitive: false), '')
      .split('@')
      .first
      .replaceAll(RegExp(r'[<>]'), '')
      .trim();
}
