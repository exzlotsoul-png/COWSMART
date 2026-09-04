import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:cowsmart/core/theme/app_colors.dart';
import 'package:cowsmart/core/utils/app_toast.dart';
import 'package:cowsmart/core/network/api_client.dart';
import 'package:cowsmart/features/auth/providers/auth_provider.dart';
import 'package:cowsmart/core/services/image_upload_service.dart';
import 'package:cowsmart/features/settings/providers/report_topic_provider.dart';

class ReportIssueScreen extends ConsumerStatefulWidget {
  const ReportIssueScreen({super.key});

  @override
  ConsumerState<ReportIssueScreen> createState() => _ReportIssueScreenState();
}

class _ReportIssueScreenState extends ConsumerState<ReportIssueScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  
  String _selectedTopic = 'ปัญหาการใช้งานแอปพลิเคชัน';
  XFile? _selectedImage;
  bool _isSubmitting = false;

  // History state
  List<dynamic> _historyReports = [];
  bool _isLoadingHistory = false;
  String? _historyError;

  final List<String> _topics = [
    'ปัญหาการใช้งานแอปพลิเคชัน',
    'ข้อเสนอแนะ / ติชม',
    'ปัญหาการคำนวณ / ข้อมูลวัว',
    'ปัญหาบัญชีผู้ใช้ / ฟาร์ม',
    'สอบถามการใช้งานทั่วไป',
    'อื่นๆ',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchHistory();
    Future.microtask(() {
      ref.read(reportTopicProvider.notifier).fetchReportTopics();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _fetchHistory() async {
    setState(() {
      _isLoadingHistory = true;
      _historyError = null;
    });

    try {
      final user = ref.read(authProvider).user;
      final userEmail = user?['email']?.toString() ?? '';
      
      final api = ref.read(apiClientProvider);
      final response = await api.get('/issue_reports');
      final list = response.data is List ? response.data as List : [];
      
      // Filter by current user email (if email is present)
      final filtered = list.where((item) {
        if (userEmail.isEmpty) return true;
        final itemEmail = item['email']?.toString() ?? item['user_id']?.toString() ?? '';
        return itemEmail.toLowerCase() == userEmail.toLowerCase();
      }).toList();

      // Sort newest first
      filtered.sort((a, b) {
        final dateA = a['created_at']?.toString() ?? '';
        final dateB = b['created_at']?.toString() ?? '';
        return dateB.compareTo(dateA);
      });

      if (mounted) {
        setState(() {
          _historyReports = filtered;
          _isLoadingHistory = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _historyError = e.toString();
          _isLoadingHistory = false;
        });
      }
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 80,
    );
    if (picked != null) {
      setState(() => _selectedImage = picked);
    }
  }

  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final user = ref.read(authProvider).user;
      final email = user?['email']?.toString() ?? 'anonymous@cowsmart.com';
      String? imageUrl;

      // Upload image if selected
      if (_selectedImage != null) {
        try {
          final uploadService = ref.read(imageUploadServiceProvider);
          final res = await uploadService.uploadImage(
            type: 'issue',
            entityId: 'issue_${DateTime.now().millisecondsSinceEpoch}',
            imageFile: _selectedImage!,
          );
          imageUrl = res['url'] ?? res['path'];
        } catch (_) {
          // Upload error handled
        }
      }

      final api = ref.read(apiClientProvider);
      final payload = {
        'email': email,
        'topic': _selectedTopic,
        'description': _descriptionController.text.trim(),
        'image_url': imageUrl,
        'status': 0,
      };

      await api.post('/issue_reports', data: payload);

      if (!mounted) return;

      // Reset form
      _descriptionController.clear();
      setState(() {
        _selectedImage = null;
        _selectedTopic = _topics[0];
      });

      // Refresh history & switch tab
      await _fetchHistory();

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: const [
              Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 28),
              SizedBox(width: 10),
              Text('แจ้งรายงานสำเร็จ', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text(
            'ขอบคุณสำหรับข้อมูลรายงานการใช้งาน ทีมงานจะดำเนินการตรวจสอบและปรับปรุงแก้ไขโดยเร็วที่สุดครับ',
            style: TextStyle(fontSize: 15),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _tabController.animateTo(1); // Switch to History tab
              },
              child: const Text('ดูประวัติการแจ้ง'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาดในการส่งรายงาน: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _deleteReport(dynamic id) async {
    if (id == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.delete_forever_rounded, color: Colors.red, size: 26),
            SizedBox(width: 8),
            Text('ยืนยันการลบรายงาน', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          ],
        ),
        content: Text(
          'คุณต้องการลบประวัติการแจ้งรายงาน ID: $id ใช่หรือไม่?\n(ข้อมูลจะถูกลบออกจากระบบอย่างถาวร)',
          style: const TextStyle(fontSize: 14.5, height: 1.4),
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('ยกเลิก'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  child: const Text('ลบรายงาน'),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final api = ref.read(apiClientProvider);
      await api.delete('/issue_reports/$id');
      setState(() {
        _historyReports.removeWhere((r) => (r['id'] ?? r['report_id']).toString() == id.toString());
      });
      if (mounted) {
        AppFeedback.showSuccess(context, 'ลบประวัติรายงานเรียบร้อยแล้ว');
      }
    } catch (e) {
      if (mounted) {
        AppFeedback.showError(context, 'ลบรายงานไม่สำเร็จ: $e');
      }
    }
  }

  String _formatDate(String? rawDate) {
    if (rawDate == null || rawDate.isEmpty) return '-';
    try {
      final dt = DateTime.parse(rawDate).toLocal();
      return DateFormat('dd/MM/yyyy HH:mm').format(dt);
    } catch (_) {
      return rawDate;
    }
  }

  String _formatImageUrl(String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    return 'http://127.0.0.1:8000/api/storage/${url.replaceAll(RegExp(r'^/?storage/'), '')}';
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final dbTopics = ref.watch(reportTopicProvider);
    final availableTopics = dbTopics.isNotEmpty
        ? dbTopics.map((t) => t.name).toList()
        : _topics;

    final currentSelectedTopic = availableTopics.contains(_selectedTopic)
        ? _selectedTopic
        : (availableTopics.isNotEmpty ? availableTopics.first : _selectedTopic);

    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        title: const Text(
          'รายงานการใช้งาน',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withValues(alpha: 0.65),
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          unselectedLabelStyle: const TextStyle(fontSize: 15),
          tabs: const [
            Tab(text: 'แจ้งเรื่องใหม่', icon: Icon(Icons.add_comment_outlined, size: 20)),
            Tab(text: 'ประวัติการแจ้ง', icon: Icon(Icons.history_rounded, size: 20)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ── TAB 1: New Report Form ──
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User Info Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: AppColors.primary,
                          radius: 20,
                          child: const Icon(Icons.person, color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user != null
                                    ? (user['name'] ?? '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'.trim())
                                    : 'ผู้ใช้งาน',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.text(context),
                                ),
                              ),
                              Text(
                                user?['email']?.toString() ?? 'ไม่ระบุอีเมล',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.subText(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Topic Dropdown
                  Text(
                    'หัวข้อรายงาน / ปัญหา',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: currentSelectedTopic,
                    isExpanded: true,
                    dropdownColor: AppColors.cardBg(context),
                    style: TextStyle(fontSize: 15, color: AppColors.text(context)),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.report_problem_outlined, color: AppColors.primary, size: 22),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    ),
                    items: availableTopics.map((t) {
                      return DropdownMenuItem(
                        value: t,
                        child: Text(t, overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedTopic = val);
                    },
                  ),

                  const SizedBox(height: 20),

                  // Description Text Area
                  Text(
                    'รายละเอียดปัญหา / ข้อเสนอแนะ',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 5,
                    style: TextStyle(fontSize: 15, color: AppColors.text(context)),
                    decoration: InputDecoration(
                      hintText: 'อธิบายรายละเอียดปัญหา ข้อผิดพลาด หรือสิ่งที่ต้องการให้ทีมงานปรับปรุงพัฒนา...',
                      hintStyle: TextStyle(fontSize: 14, color: AppColors.hint(context)),
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.all(14),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'กรุณากรอกรายละเอียดปัญหาหรือข้อเสนอแนะ';
                      }
                      if (val.trim().length < 5) {
                        return 'กรุณากรอกรายละเอียดอย่างน้อย 5 ตัวอักษร';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 20),

                  // Image Attachment
                  const Text(
                    'แนบรูปภาพประกอบ (ถ้ามี)',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_selectedImage != null) ...[
                    Stack(
                      children: [
                        Container(
                          width: double.infinity,
                          height: 180,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: FutureBuilder<Uint8List>(
                              future: _selectedImage!.readAsBytes(),
                              builder: (context, snapshot) {
                                if (snapshot.hasData) {
                                  return Image.memory(snapshot.data!, fit: BoxFit.cover);
                                }
                                return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                              },
                            ),
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedImage = null),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close, size: 18, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    InkWell(
                      onTap: _pickImage,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border, style: BorderStyle.solid),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.add_a_photo_outlined, color: AppColors.primary, size: 32),
                            SizedBox(height: 6),
                            Text(
                              'แตะเพื่อแนบรูปภาพหน้าจอที่มีปัญหา',
                              style: TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 32),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isSubmitting ? null : _submitReport,
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.send_rounded, size: 20),
                      label: Text(_isSubmitting ? 'กำลังส่งรายงาน...' : 'ส่งรายงานการใช้งาน'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // ── TAB 2: Report History ──
          RefreshIndicator(
            onRefresh: _fetchHistory,
            child: _isLoadingHistory
                ? const Center(child: CircularProgressIndicator())
                : _historyError != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, color: AppColors.error, size: 48),
                            const SizedBox(height: 12),
                            Text('เกิดข้อผิดพลาดในการดึงประวัติ: $_historyError'),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: _fetchHistory,
                              child: const Text('ลองใหม่'),
                            ),
                          ],
                        ),
                      )
                    : _historyReports.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              const SizedBox(height: 100),
                              Center(
                                child: Column(
                                  children: [
                                    Icon(Icons.assignment_outlined, size: 64, color: AppColors.hint(context)),
                                    const SizedBox(height: 12),
                                    Text(
                                      'ยังไม่มีประวัติการแจ้งรายงานการใช้งาน',
                                      style: TextStyle(fontSize: 16, color: AppColors.subText(context)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            physics: const AlwaysScrollableScrollPhysics(),
                            itemCount: _historyReports.length,
                            itemBuilder: (context, index) {
                              final item = _historyReports[index];
                              final status = item['status'];
                              final isResolved = status == 1 || status == '1' || status == 'resolved';
                              final topic = item['topic'] ?? item['issue_type'] ?? 'รายงานการใช้งาน';
                              final desc = item['description'] ?? '';
                              final dateStr = _formatDate(item['created_at']);
                              final imageUrl = item['image_url'] != null ? _formatImageUrl(item['image_url'].toString()) : null;

                              final reportId = item['id'] ?? item['report_id'] ?? '';

                              return Card(
                                margin: const EdgeInsets.only(bottom: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(color: AppColors.brd(context).withValues(alpha: 0.6)),
                                ),
                                elevation: 1.5,
                                shadowColor: Colors.black.withValues(alpha: 0.05),
                                color: AppColors.cardBg(context),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              topic,
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.text(context),
                                                height: 1.2,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: isResolved ? const Color(0xFFE8F2E6) : const Color(0xFFFFF7ED),
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(
                                                color: isResolved
                                                    ? AppColors.primary.withValues(alpha: 0.35)
                                                    : const Color(0xFFFDBA74).withValues(alpha: 0.6),
                                                width: 1,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  isResolved ? Icons.check_circle_rounded : Icons.hourglass_top_rounded,
                                                  size: 13,
                                                  color: isResolved ? const Color(0xFF334A2E) : const Color(0xFFC2410C),
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  isResolved ? 'แก้ไขแล้ว' : 'รอดำเนินการ',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFF334A2E),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          InkWell(
                                            onTap: () => _deleteReport(reportId),
                                            borderRadius: BorderRadius.circular(8),
                                            child: Padding(
                                              padding: const EdgeInsets.all(4),
                                              child: Icon(
                                                Icons.delete_outline_rounded,
                                                size: 20,
                                                color: Colors.red[400],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Icon(Icons.access_time, size: 14, color: AppColors.hint(context)),
                                          const SizedBox(width: 4),
                                          Text(
                                            dateStr,
                                            style: TextStyle(fontSize: 12, color: AppColors.hint(context)),
                                          ),
                                          const SizedBox(width: 10),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: AppColors.surfaceAlt,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              'ID: $reportId',
                                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Divider(height: 20),
                                      Text(
                                        desc,
                                        style: const TextStyle(fontSize: 14, color: AppColors.textPrimary, height: 1.45),
                                      ),
                                      if (imageUrl != null) ...[
                                        const SizedBox(height: 12),
                                        GestureDetector(
                                          onTap: () {
                                            showDialog(
                                              context: context,
                                              builder: (ctx) => Dialog(
                                                child: ClipRRect(
                                                  borderRadius: BorderRadius.circular(12),
                                                  child: Image.network(
                                                    imageUrl,
                                                    fit: BoxFit.contain,
                                                    errorBuilder: (_, __, ___) => const Padding(
                                                      padding: EdgeInsets.all(20),
                                                      child: Text('ไม่สามารถโหลดรูปภาพได้'),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(8),
                                            child: Image.network(
                                              imageUrl,
                                              height: 100,
                                              width: double.infinity,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) => const SizedBox(),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
