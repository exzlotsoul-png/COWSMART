import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image/image.dart' as img_lib;
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:zxing2/qrcode.dart';
import '../../domain/cow.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_toast.dart';
import '../../providers/cow_provider.dart';
import '../../../../core/services/nfc_service.dart';
import '../widgets/nfc_reader_dialog.dart';

class QrScannerScreen extends ConsumerStatefulWidget {
  const QrScannerScreen({super.key});

  @override
  ConsumerState<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends ConsumerState<QrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _startNfcScan();
  }

  void _startNfcScan() {
    NfcService.startReadSession(
      onDiscovered: (payload) {
        if (mounted) {
          _processScannedValue(payload);
        }
      },
      onError: (error) {
        // Silently ignore NFC errors or show a small toast, don't interrupt QR
        debugPrint('NFC Scan Error: $error');
      },
    );
  }

  Future<void> _openNfcReaderDialog() async {
    // 1. Pause camera and stop background NFC to give exclusive hardware access
    try {
      await _controller.stop();
    } catch (_) {}
    await NfcService.stopSession();
    await Future.delayed(const Duration(milliseconds: 150));

    if (!mounted) return;

    // 2. Open dedicated NFC reading dialog
    final payload = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (_) => const NfcReaderDialog(),
    );

    // 3. Resume camera when dialog closes
    try {
      if (mounted) {
        await _controller.start();
      }
    } catch (_) {}

    // 4. If tag was read, process the cow data
    if (payload != null && payload.isNotEmpty && mounted) {
      _processScannedValue(payload);
    }
  }

  @override
  void dispose() {
    NfcService.stopSession();
    _controller.dispose();
    super.dispose();
  }

  // Pure Dart QR Decoder using zxing2 for cross-platform image decoding
  Future<String?> _decodeQrWithPureDart(Uint8List bytes) async {
    try {
      final image = img_lib.decodeImage(bytes);
      if (image == null) return null;

      final width = image.width;
      final height = image.height;
      final int32Pixels = Int32List(width * height);
      int index = 0;
      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final pixel = image.getPixel(x, y);
          final r = pixel.r.toInt();
          final g = pixel.g.toInt();
          final b = pixel.b.toInt();
          int32Pixels[index++] = (0xFF << 24) | (r << 16) | (g << 8) | b;
        }
      }

      final source = RGBLuminanceSource(width, height, int32Pixels);
      final bitmap = BinaryBitmap(HybridBinarizer(source));
      final reader = QRCodeReader();
      final result = reader.decode(bitmap);
      return result.text;
    } catch (e) {
      return null;
    }
  }

  void _handleBarcode(BarcodeCapture capture) {
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final String? rawValue = barcode.rawValue;
      if (rawValue != null && rawValue.isNotEmpty) {
        _processScannedValue(rawValue);
        break;
      }
    }
  }

  Future<void> _processScannedValue(String rawValue) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    String cowIdOrTag = rawValue.trim();

    // Parse deep link formats (e.g., https://cowsmart.app/cow/ID_123 or cowsmart://cow/ID_123 or COW:ID_123)
    if (cowIdOrTag.contains('/cow/')) {
      cowIdOrTag = cowIdOrTag.substring(cowIdOrTag.lastIndexOf('/cow/') + 5);
    } else if (cowIdOrTag.startsWith('COW:')) {
      cowIdOrTag = cowIdOrTag.replaceFirst('COW:', '');
    }

    final allCows = ref.read(cowProvider).allCows;

    // Search in local state first
    Cow? matchedCow;
    for (final cow in allCows) {
      if (cow.id.toLowerCase() == cowIdOrTag.toLowerCase() ||
          cow.tagNumber.toLowerCase() == cowIdOrTag.toLowerCase() ||
          cow.name.toLowerCase() == cowIdOrTag.toLowerCase()) {
        matchedCow = cow;
        break;
      }
    }

    // If not found in local state, try querying API
    if (matchedCow == null) {
      try {
        final api = ref.read(apiClientProvider);
        final res = await api.get('/cows/$cowIdOrTag');
        if (res.data != null && res.data is Map<String, dynamic>) {
          matchedCow = Cow.fromJson(res.data);
        }
      } catch (_) {}
    }

    if (!mounted) return;

    if (matchedCow != null) {
      AppFeedback.showSuccess(
        context,
        'พบข้อมูลวัว: ${matchedCow.name.isNotEmpty ? matchedCow.name : matchedCow.tagNumber}',
      );

      // Navigate straight to cow detail screen
      context.pushReplacement('/cow_detail/${matchedCow.id}', extra: matchedCow);
    } else {
      AppFeedback.showError(
        context,
        'ไม่พบข้อมูลวัวจากแท็ก/QR นี้ ($cowIdOrTag)',
      );
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() => _isProcessing = false);
        }
      });
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      String? scannedText;

      // 1. Try mobile_scanner native analyzeImage first
      try {
        final BarcodeCapture? capture = await _controller.analyzeImage(image.path);
        if (capture != null && capture.barcodes.isNotEmpty) {
          scannedText = capture.barcodes.first.rawValue;
        }
      } catch (_) {
        // Fallback silently if native plugin throws MissingPluginException on Desktop/Web
      }

      // 2. Pure Dart fallback if native analyzeImage was null or threw MissingPluginException
      if (scannedText == null || scannedText.isEmpty) {
        final bytes = await image.readAsBytes();
        scannedText = await _decodeQrWithPureDart(bytes);
      }

      if (scannedText != null && scannedText.isNotEmpty) {
        _processScannedValue(scannedText);
      } else {
        if (mounted) {
          AppFeedback.showError(context, 'ไม่พบ QR Code ในรูปภาพที่เลือก');
        }
      }
    } catch (e) {
      if (mounted) {
        AppFeedback.showError(context, 'ไม่สามารถอ่านรูปภาพได้: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Live Camera Stream Scanner
          MobileScanner(
            controller: _controller,
            onDetect: _handleBarcode,
            errorBuilder: (context, error, child) {
              return Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.videocam_off_rounded, size: 64, color: Colors.amber),
                      const SizedBox(height: 16),
                      const Text(
                        'ไม่พบอุปกรณ์กล้อง / Webcam',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'สำหรับโน้ตบุ๊กหรือคอมพิวเตอร์ที่ไม่มีกล้องเว็บแคม ท่านสามารถเลือกรูป QR Code จากไฟล์ภาพ หรือพิมพ์ค้นหาหมายเลขแท็กวัวได้โดยตรง',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _pickImageFromGallery,
                        icon: const Icon(Icons.photo_library_rounded),
                        label: const Text('เลือกรูป QR Code จากคลังภาพ'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // Scanner Overlay Frame
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.primary, width: 3),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          ),

          // Top Header & Controls
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 28),
                      onPressed: () => context.pop(),
                    ),
                    const Text(
                      'สแกน QR / NFC',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.flash_on_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                      onPressed: () => _controller.toggleTorch(),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom Controls (NFC & Gallery Buttons)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black, Colors.black87, Colors.transparent],
                ),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: _openNfcReaderDialog,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.orange.withValues(alpha: 0.8)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.nfc_rounded, color: Colors.orangeAccent, size: 18),
                            SizedBox(width: 6),
                            Text(
                              'ระบบ NFC พร้อมทำงาน (แตะที่นี่เพื่อเปิดโหมดแตะเหรียญ)',
                              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'ส่อง QR Code ในกรอบ หรือ กดปุ่มแตะเหรียญ NFC ด้านล่าง',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _openNfcReaderDialog,
                            icon: const Icon(Icons.contactless_rounded, size: 20),
                            label: const Text(
                              'แตะเหรียญ NFC',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange.shade800,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 3,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _pickImageFromGallery,
                            icon: const Icon(Icons.photo_library_rounded, size: 20),
                            label: const Text(
                              'เลือกรูปภาพ',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
