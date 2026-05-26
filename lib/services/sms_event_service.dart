import 'dart:async';

import 'package:flutter/services.dart';

typedef SmsEventHandler = FutureOr<void> Function(SmsEvent event);

class SmsEvent {
  final String id;
  final String sender;
  final String body;
  final int receivedAt;

  const SmsEvent({
    required this.id,
    required this.sender,
    required this.body,
    required this.receivedAt,
  });

  factory SmsEvent.fromMap(Map<dynamic, dynamic> map) {
    return SmsEvent(
      id: _readString(map['id']),
      sender: _readString(map['sender']),
      body: _readString(map['body']),
      receivedAt: _readInt(map['receivedAt']),
    );
  }

  static String _readString(Object? value) {
    return value?.toString() ?? '';
  }

  static int _readInt(Object? value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class SmsEventService {
  static const String channelName = 'com.example.first/sms_events';
  static const MethodChannel _channel = MethodChannel(channelName);
  static const int _maxRememberedEventIds = 100;

  static SmsEventHandler? _handler;
  static bool _isListening = false;
  static final Set<String> _handledOrProcessingEventIds = <String>{};

  static Future<void> startListening(SmsEventHandler handler) async {
    _handler = handler;

    if (!_isListening) {
      _channel.setMethodCallHandler(_handleNativeCall);
      _isListening = true;
    }

    await replayPendingEvents();
  }

  static Future<void> replayPendingEvents() async {
    final pendingEvents =
        await _channel.invokeMethod<List<dynamic>>('getPendingSmsEvents') ?? [];

    for (final rawEvent in pendingEvents) {
      if (rawEvent is Map) {
        await _handleEvent(SmsEvent.fromMap(rawEvent));
      }
    }
  }

  static Future<void> ackEvent(String id) async {
    await _channel.invokeMethod<void>('ackSmsEvent', {'id': id});
  }

  static Future<dynamic> _handleNativeCall(MethodCall call) async {
    if (call.method != 'smsReceived') return null;

    final arguments = call.arguments;
    if (arguments is Map) {
      await _handleEvent(SmsEvent.fromMap(arguments));
    }

    return null;
  }

  static Future<void> _handleEvent(SmsEvent event) async {
    final handler = _handler;
    if (handler == null) return;
    if (!_rememberEventId(event.id)) return;

    try {
      await handler(event);
      await ackEvent(event.id);
    } catch (_) {
      _handledOrProcessingEventIds.remove(event.id);
      rethrow;
    }
  }

  static bool _rememberEventId(String id) {
    if (id.isEmpty) return true;
    if (_handledOrProcessingEventIds.contains(id)) return false;

    _handledOrProcessingEventIds.add(id);
    if (_handledOrProcessingEventIds.length > _maxRememberedEventIds) {
      _handledOrProcessingEventIds.remove(_handledOrProcessingEventIds.first);
    }
    return true;
  }

  static void stopListeningForTest() {
    _handler = null;
    _isListening = false;
    _handledOrProcessingEventIds.clear();
    _channel.setMethodCallHandler(null);
  }
}
