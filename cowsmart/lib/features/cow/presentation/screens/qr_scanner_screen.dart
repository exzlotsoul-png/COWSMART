import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image/image.dart' as img_lib;
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:zxing2/qrcode.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_toast.dart';
import '../../providers/cow_provider.dart';

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
  void dispose() {
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

  void _processScannedValue(String rawValue) {
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

    // Search by exact ID, or tag number, or cow name
    final matchedCow = allCows.cast<dynamic>().firstWhere(
          (cow) =>
              cow.id == cowIdOrTag ||
              cow.tagNumber.toLowerCase() == cowIdOrTag.toLowerCase() ||
              cow.name.toLowerCase() == cowIdOrTag.toLowerCase(),
          orElse: () => null,
        );

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
        'ไม่พบข้อมูลวัวจาก QR Code นี้ ($cowIdOrTag)',
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
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 28),
                        onPressed: () => context.pop(),
                      ),
                      const Text(
                        'สแกน QR Code วัว',
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
                const Spacer(),

                // Bottom Controls (Gallery Picker & Manual Search)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Colors.black87, Colors.black54, Colors.transparent],
                    ),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'วาง QR Code วัวให้อยู่ในกรอบ หรือเลือกรูปจากคลังภาพ',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _pickImageFromGallery,
                          icon: const Icon(Icons.photo_library_rounded, size: 20),
                          label: const Text(
                            'เลือกรูปจากคลังภาพ',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
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
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
