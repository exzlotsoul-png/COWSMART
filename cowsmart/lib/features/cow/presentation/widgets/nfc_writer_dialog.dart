import 'package:flutter/material.dart';
import 'package:cowsmart/core/services/nfc_service.dart';
import 'package:cowsmart/core/theme/app_colors.dart';
import 'package:cowsmart/features/cow/domain/cow.dart';
import 'package:cowsmart/core/utils/app_toast.dart';

class NfcWriterDialog extends StatefulWidget {
  final Cow cow;

  const NfcWriterDialog({super.key, required this.cow});

  @override
  State<NfcWriterDialog> createState() => _NfcWriterDialogState();
}

class _NfcWriterDialogState extends State<NfcWriterDialog> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  String _statusMessage = 'กรุณานำเหรียญ NFC\nมาแตะที่ด้านหลังโทรศัพท์ของคุณ';
  bool _isSuccess = false;
  bool _isWriting = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    
    _startNfcWrite();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    NfcService.stopSession();
    super.dispose();
  }

  Future<void> _startNfcWrite() async {
    setState(() {
      _isWriting = true;
      _statusMessage = 'กำลังรอรับสัญญาณ NFC...';
    });

    // We format the payload as a URI so it can be easily parsed later or trigger deep links
    final payload = 'cowsmart://cow/${widget.cow.id}';

    await NfcService.writeTag(
      data: payload,
      onSuccess: () {
        if (!mounted) return;
        setState(() {
          _isSuccess = true;
          _isWriting = false;
          _statusMessage = 'เขียนข้อมูลลงเหรียญสำเร็จ!';
        });
        _pulseController.stop();
        
        AppFeedback.showSuccess(context, 'ฝังรหัส ${widget.cow.tagNumber} ลงเหรียญ NFC เรียบร้อยแล้ว');
        
        // Auto close after success
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.of(context).pop(true);
          }
        });
      },
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _isWriting = false;
          _statusMessage = 'เกิดข้อผิดพลาด:\n$error';
        });
        _pulseController.stop();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title
            const Text(
              'ฝังข้อมูลลงเหรียญ NFC',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'วัว: ${widget.cow.name} (${widget.cow.tagNumber})',
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 32),
            
            // Animation / Icon
            SizedBox(
              height: 120,
              width: 120,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (_isWriting && !_isSuccess)
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        return Container(
                          width: 100 + (_pulseController.value * 20),
                          height: 100 + (_pulseController.value * 20),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primary.withOpacity(0.2 - (_pulseController.value * 0.1)),
                          ),
                        );
                      },
                    ),
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: _isSuccess ? AppColors.success.withOpacity(0.1) : AppColors.primaryLight.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isSuccess ? Icons.check_circle_outline : Icons.nfc_rounded,
                      size: 40,
                      color: _isSuccess ? AppColors.success : AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Status Text
            Text(
              _statusMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: _isSuccess ? FontWeight.bold : FontWeight.normal,
                color: _isSuccess ? AppColors.success : AppColors.textPrimary,
                height: 1.5,
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Cancel / Close Button
            SizedBox(
              width: double.infinity,
              child: _isSuccess
                  ? ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('เสร็จสิ้น', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    )
                  : OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        side: const BorderSide(color: AppColors.border),
                      ),
                      child: const Text('ยกเลิก', style: TextStyle(fontSize: 16, color: AppColors.textSecondary)),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
