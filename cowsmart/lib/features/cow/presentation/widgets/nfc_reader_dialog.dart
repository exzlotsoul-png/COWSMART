import 'package:flutter/material.dart';
import 'package:cowsmart/core/services/nfc_service.dart';
import 'package:cowsmart/core/theme/app_colors.dart';
import 'package:cowsmart/core/utils/app_toast.dart';

class NfcReaderDialog extends StatefulWidget {
  const NfcReaderDialog({super.key});

  @override
  State<NfcReaderDialog> createState() => _NfcReaderDialogState();
}

class _NfcReaderDialogState extends State<NfcReaderDialog> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  String _statusMessage = 'กำลังเปิดระบบ NFC...\nกรุณานำเหรียญมาแตะที่ด้านหลังโทรศัพท์';
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _startNfcRead();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    NfcService.stopSession();
    super.dispose();
  }

  Future<void> _startNfcRead() async {
    // Clean start
    await NfcService.stopSession();
    await Future.delayed(const Duration(milliseconds: 100));

    if (!mounted) return;

    setState(() {
      _statusMessage = 'พร้อมสแกน!\nนำเหรียญมาทาบที่ขอบบนของกล้องหลัง';
    });

    await NfcService.startReadSession(
      onDiscovered: (payload) {
        if (!mounted) return;
        setState(() {
          _isSuccess = true;
          _statusMessage = 'อ่านข้อมูลเหรียญสำเร็จ!';
        });
        _pulseController.stop();

        AppFeedback.showSuccess(context, 'อ่านข้อมูลจากเหรียญ NFC สำเร็จ');

        // Auto return with payload
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            Navigator.of(context).pop(payload);
          }
        });
      },
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _statusMessage = error;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 0,
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.nfc_rounded,
                      color: Colors.orange,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'โหมดแตะเหรียญ NFC',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'ค้นหาข้อมูลประวัติวัวอัตโนมัติ',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppColors.textHint),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Animated Visual Graphic
              Center(
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        // Pulse rings
                        if (!_isSuccess) ...[
                          Container(
                            width: 110 + (_pulseController.value * 25),
                            height: 110 + (_pulseController.value * 25),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.orange.withValues(
                                alpha: 0.2 * (1 - _pulseController.value),
                              ),
                            ),
                          ),
                          Container(
                            width: 90 + (_pulseController.value * 15),
                            height: 90 + (_pulseController.value * 15),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.orange.withValues(
                                alpha: 0.3 * (1 - _pulseController.value),
                              ),
                            ),
                          ),
                        ],
                        // Main Icon Container
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isSuccess
                                ? AppColors.success
                                : Colors.orange.shade800,
                            boxShadow: [
                              BoxShadow(
                                color: (_isSuccess ? AppColors.success : Colors.orange).withValues(alpha: 0.4),
                                blurRadius: 15,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Icon(
                            _isSuccess
                                ? Icons.check_rounded
                                : Icons.contactless_rounded,
                            size: 42,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),

              // Status Message
              Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _isSuccess
                      ? AppColors.success
                      : AppColors.textPrimary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '💡 ตำแหน่ง NFC (Huawei Mate 20 Pro):\nอยู่บริเวณ "ขอบบนของกล้องหลัง"',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.3,
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Cancel Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'ปิดหน้าต่าง',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
