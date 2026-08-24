import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/ndef_record.dart';
import 'package:nfc_manager_ndef/nfc_manager_ndef.dart';

class NfcService {
  /// Check if the device has NFC hardware and it is enabled
  static Future<bool> isNfcAvailable() async {
    try {
      final availability = await NfcManager.instance.checkAvailability();
      return availability == NfcAvailability.enabled;
    } catch (e) {
      debugPrint('NFC checkAvailability error: $e');
      return false;
    }
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
      debugPrint('🚀 Starting NFC Reader Session...');
      NfcManager.instance.startSession(
        pollingOptions: {
          NfcPollingOption.iso14443,
          NfcPollingOption.iso15693,
          NfcPollingOption.iso18092,
        },
        onDiscovered: (NfcTag tag) async {
          try {
            debugPrint('🏷️ NFC Tag detected!');
            String payloadString = '';

            // 1. Try reading NDEF message
            final ndef = Ndef.from(tag);
            if (ndef != null) {
              NdefMessage? message = ndef.cachedMessage;
              if (message == null || message.records.isEmpty) {
                try {
                  message = await ndef.read();
                } catch (e) {
                  debugPrint('Ndef.read() error: $e');
                }
              }

              if (message != null && message.records.isNotEmpty) {
                for (final record in message.records) {
                  final extracted = _extractRecordPayload(record);
                  if (extracted.isNotEmpty) {
                    payloadString = extracted;
                    break;
                  }
                }
              }
            }

            if (payloadString.isEmpty) {
              debugPrint('⚠️ No readable payload found in tag');
              onError('ไม่พบข้อมูลในแท็ก NFC นี้');
              return;
            }

            debugPrint('✅ NFC Decoded Payload: $payloadString');
            onDiscovered(payloadString);
          } catch (e) {
            debugPrint('❌ Error processing NFC tag: $e');
            onError('เกิดข้อผิดพลาดในการอ่านเหรียญ: $e');
          }
        },
      );
    } catch (e) {
      debugPrint('❌ Error starting NFC session: $e');
      onError('ไม่สามารถเริ่มการอ่าน NFC ได้: $e');
    }
  }

  static String _extractRecordPayload(NdefRecord record) {
    try {
      debugPrint('📦 NDEF Record typeNameFormat: ${record.typeNameFormat}, type length: ${record.type.length}, payload length: ${record.payload.length}');

      // Skip Android Application Record (AAR)
      if (record.typeNameFormat == TypeNameFormat.external) {
        return '';
      }

      // 1. Text Record ('T' / 0x54)
      if (record.type.length == 1 && record.type[0] == 0x54) {
        if (record.payload.isNotEmpty) {
          int langLen = record.payload[0] & 0x3F;
          if (record.payload.length > 1 + langLen) {
            final text = utf8.decode(record.payload.sublist(1 + langLen), allowMalformed: true);
            if (text.isNotEmpty && !text.contains('com.example.')) return text;
          }
        }
      }

      // 2. URI Record ('U' / 0x55)
      if (record.type.length == 1 && record.type[0] == 0x55) {
        if (record.payload.isNotEmpty) {
          int prefixCode = record.payload[0];
          String prefix = _getUriPrefix(prefixCode);
          String rest = utf8.decode(record.payload.sublist(1), allowMalformed: true);
          return '$prefix$rest';
        }
      }

      // 3. Fallback direct UTF-8 decode
      if (record.payload.isNotEmpty) {
        String raw = utf8.decode(record.payload, allowMalformed: true);
        raw = raw.replaceAll(RegExp(r'^[\x00-\x1F]+'), '');
        if (raw.isNotEmpty) return raw;
      }
    } catch (e) {
      debugPrint('Error decoding NDEF record: $e');
    }
    return '';
  }

  static String _getUriPrefix(int code) {
    switch (code) {
      case 0x01: return 'http://www.';
      case 0x02: return 'https://www.';
      case 0x03: return 'http://';
      case 0x04: return 'https://';
      case 0x05: return 'tel:';
      case 0x06: return 'mailto:';
      default: return '';
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
      debugPrint('🚀 Starting NFC Writer Session for: $data');
      NfcManager.instance.startSession(
        pollingOptions: {
          NfcPollingOption.iso14443,
          NfcPollingOption.iso15693,
          NfcPollingOption.iso18092,
        },
        onDiscovered: (NfcTag tag) async {
          try {
            debugPrint('🏷️ NFC Tag detected for writing');
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

            // Create both a Text Record and URI Record for maximum compatibility
            final langBytes = utf8.encode('en');
            final textBytes = utf8.encode(data);
            final textPayload = Uint8List(1 + langBytes.length + textBytes.length);
            textPayload[0] = langBytes.length; // status byte
            textPayload.setRange(1, 1 + langBytes.length, langBytes);
            textPayload.setRange(1 + langBytes.length, textPayload.length, textBytes);

            final textRecord = NdefRecord(
              typeNameFormat: TypeNameFormat.wellKnown,
              type: Uint8List.fromList([0x54]), // 'T'
              identifier: Uint8List(0),
              payload: textPayload,
            );

            final uriBytes = utf8.encode(data);
            final uriPayload = Uint8List(1 + uriBytes.length);
            uriPayload[0] = 0x00; // No prefix
            uriPayload.setRange(1, uriPayload.length, uriBytes);

            final uriRecord = NdefRecord(
              typeNameFormat: TypeNameFormat.wellKnown,
              type: Uint8List.fromList([0x55]), // 'U'
              identifier: Uint8List(0),
              payload: uriPayload,
            );

            // Android Application Record (AAR) forces Android to launch Cowsmart directly
            final aarPayload = utf8.encode('com.example.beef_farm');
            final aarRecord = NdefRecord(
              typeNameFormat: TypeNameFormat.external,
              type: Uint8List.fromList(utf8.encode('android.com:pkg')),
              identifier: Uint8List(0),
              payload: Uint8List.fromList(aarPayload),
            );

            final message = NdefMessage(records: [textRecord, uriRecord, aarRecord]);

            try {
              await ndef.write(message: message);
              debugPrint('✅ Successfully wrote to NFC tag: $data');
              onSuccess();
            } catch (e) {
              debugPrint('❌ Error writing NDEF message: $e');
              onError('เขียนข้อมูลล้มเหลว: $e');
            }
            await stopSession();
          } catch (e) {
            debugPrint('❌ Error during write callback: $e');
            onError('เกิดข้อผิดพลาดขณะเขียน NFC: $e');
            await stopSession();
          }
        },
      );
    } catch (e) {
      debugPrint('❌ Error starting write session: $e');
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
