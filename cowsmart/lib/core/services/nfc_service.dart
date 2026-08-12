import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/ndef_record.dart';
import 'package:nfc_manager_ndef/nfc_manager_ndef.dart';

class NfcService {
  /// Check if the device has NFC hardware and it is enabled
  static Future<bool> isNfcAvailable() async {
    final availability = await NfcManager.instance.checkAvailability();
    return availability == NfcAvailability.enabled;
  }

  /// Start a session to read an NFC tag.
  /// If [onDiscovered] is provided, it will be called with the tag's text payload (if any).
  static Future<void> startReadSession({
    required Function(String payload) onDiscovered,
    required Function(String error) onError,
  }) async {
    bool isAvailable = await isNfcAvailable();
    if (!isAvailable) {
      onError('อุปกรณ์นี้ไม่รองรับหรือไม่ได้เปิดใช้งาน NFC');
      return;
    }

    try {
      NfcManager.instance.startSession(
        pollingOptions: {NfcPollingOption.iso14443, NfcPollingOption.iso15693, NfcPollingOption.iso18092},
        onDiscovered: (NfcTag tag) async {
          try {
            final ndef = Ndef.from(tag);
            if (ndef == null) {
              onError('เหรียญนี้ไม่รองรับรูปแบบ NDEF');
              await stopSession();
              return;
            }

            final cachedMessage = ndef.cachedMessage;
            if (cachedMessage == null || cachedMessage.records.isEmpty) {
              onError('ไม่พบข้อมูลในเหรียญ NFC นี้');
              await stopSession();
              return;
            }

            // We'll read the first record's payload (assuming Text or URI)
            final record = cachedMessage.records.first;
            
            String payloadString = '';
            if (record.typeNameFormat == TypeNameFormat.wellKnown) {
              if (record.type.length == 1 && record.type[0] == 0x54) { // 'T' = Text
                // First byte is status (language code length), followed by language code, then text
                int languageCodeLength = record.payload[0] & 0x3F;
                payloadString = utf8.decode(record.payload.sublist(1 + languageCodeLength));
              } else if (record.type.length == 1 && record.type[0] == 0x55) { // 'U' = URI
                // First byte is URI identifier code
                payloadString = utf8.decode(record.payload.sublist(1));
              } else {
                payloadString = utf8.decode(record.payload);
              }
            } else {
              payloadString = utf8.decode(record.payload);
            }

            onDiscovered(payloadString);
            await stopSession();
          } catch (e) {
            onError('เกิดข้อผิดพลาดในการอ่านเหรียญ: $e');
            await stopSession();
          }
        },
      );
    } catch (e) {
      onError('ไม่สามารถเริ่มการอ่าน NFC ได้: $e');
    }
  }

  /// Write text data to an NFC tag
  static Future<void> writeTag({
    required String data,
    required VoidCallback onSuccess,
    required Function(String error) onError,
  }) async {
    bool isAvailable = await isNfcAvailable();
    if (!isAvailable) {
      onError('อุปกรณ์นี้ไม่รองรับหรือไม่ได้เปิดใช้งาน NFC');
      return;
    }

    try {
      NfcManager.instance.startSession(
        pollingOptions: {NfcPollingOption.iso14443, NfcPollingOption.iso15693, NfcPollingOption.iso18092},
        onDiscovered: (NfcTag tag) async {
          try {
            var ndef = Ndef.from(tag);
            if (ndef == null) {
              onError('เหรียญนี้ไม่รองรับการเขียนข้อมูล NDEF');
              await stopSession();
              return;
            }

            if (!ndef.isWritable) {
              onError('เหรียญนี้ถูกล็อค ไม่สามารถเขียนข้อมูลทับได้');
              await stopSession();
              return;
            }

            // Create a URI record
            final uriBytes = utf8.encode(data);
            final payload = Uint8List(1 + uriBytes.length);
            payload[0] = 0x00; // No prefix
            payload.setRange(1, payload.length, uriBytes);
            
            final record = NdefRecord(
              typeNameFormat: TypeNameFormat.wellKnown,
              type: Uint8List.fromList([0x55]), // 'U'
              identifier: Uint8List(0),
              payload: payload,
            );

            NdefMessage message = NdefMessage(records: [record]);

            try {
              await ndef.write(message: message);
              onSuccess();
            } catch (e) {
              onError('เขียนข้อมูลล้มเหลว: $e');
            }
            await stopSession();
          } catch (e) {
            onError('เกิดข้อผิดพลาดขณะเขียน NFC: $e');
            await stopSession();
          }
        },
      );
    } catch (e) {
      onError('ไม่สามารถเริ่มการเขียน NFC ได้: $e');
    }
  }

  static Future<void> stopSession() async {
    try {
      await NfcManager.instance.stopSession();
    } catch (e) {
      debugPrint('Error stopping NFC session: $e');
    }
  }
}
