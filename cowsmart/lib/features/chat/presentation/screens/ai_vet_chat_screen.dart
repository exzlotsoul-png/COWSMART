import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/ai_chat_repository.dart';
import '../../domain/chat_message.dart';

class AiVetChatScreen extends ConsumerStatefulWidget {
  const AiVetChatScreen({super.key});

  @override
  ConsumerState<AiVetChatScreen> createState() => _AiVetChatScreenState();
}

class _AiVetChatScreenState extends ConsumerState<AiVetChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];

  bool _isLoading = false;
  List<SuggestedTopicCategory> _suggestedCategories = [];

  @override
  void initState() {
    super.initState();
    _loadSuggestedTopics();
    _initWelcomeMessage();
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _initWelcomeMessage() {
    _messages.add(
      ChatMessage(
        id: 'welcome',
        text: 'สวัสดีครับ! ผมคือ **หมอวัว CowSmart** ผู้ช่วยสัตวแพทย์ประจำฟาร์มของคุณ\n\n'
            'ท่านสามารถพิมพ์เล่าอาการของวัว หรือเลือกแตะ **"หัวข้ออาการพบบ่อย"** ด้านล่างเพื่อขอคำแนะนำเบื้องต้น การปฐมพยาบาล และการดูแลรักษาได้ทันทีครับ',
        isUser: false,
        timestamp: DateTime.now(),
      ),
    );
  }

  Future<void> _loadSuggestedTopics() async {
    final repo = ref.read(aiChatRepositoryProvider);
    final topics = await repo.getSuggestedTopics();
    if (mounted) {
      setState(() {
        _suggestedCategories = topics;
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _isLoading) return;

    _textController.clear();

    final userMsg = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: trimmed,
      isUser: true,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMsg);
      _isLoading = true;
    });
    _scrollToBottom();

    try {
      final repo = ref.read(aiChatRepositoryProvider);
      final response = await repo.consultAi(
        message: trimmed,
        cowId: null,
      );

      final aiText = response['ai_response'] ?? 'ขออภัยครับ ระบบไม่สามารถประมวลผลคำตอบได้ในขณะนี้';
      final actionsList = (response['suggested_actions'] as List<dynamic>?)
          ?.map((a) => SuggestedAction.fromJson(a))
          .toList();

      final botMsg = ChatMessage(
        id: response['chat_id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
        text: aiText,
        isUser: false,
        timestamp: DateTime.now(),
        actions: actionsList,
      );

      if (mounted) {
        setState(() {
          _messages.add(botMsg);
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(
            ChatMessage(
              id: 'err_${DateTime.now().millisecondsSinceEpoch}',
              text: 'เกิดข้อผิดพลาดในการเชื่อมต่อ: $e\nกรุณาลองใหม่อีกครั้งครับ',
              isUser: false,
              timestamp: DateTime.now(),
            ),
          );
          _isLoading = false;
        });
        _scrollToBottom();
      }
    }
  }

  void _handleSuggestedAction(SuggestedAction action) {
    if (action.action == 'create_appointment') {
      context.push('/group_appointment');
    } else if (action.action == 'record_health') {
      context.push('/group_health');
    }
  }

  void _clearChat() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('ล้างประวัติการสนทนา', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('ต้องการเริ่มการสนทนาใหม่และล้างข้อความทั้งหมดใช่หรือไม่?'),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('ยกเลิก', style: TextStyle(color: AppColors.textSecondary)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _messages.clear();
                      _initWelcomeMessage();
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  child: const Text('เริ่มใหม่'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        backgroundColor: AppColors.cardBg(context),
        elevation: 0,
        scrolledUnderElevation: 1,
        titleSpacing: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: AppColors.text(context)),
          onPressed: () => context.pop(),
        ),
        title: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Center(
                    child: Icon(Icons.health_and_safety_rounded, color: Colors.white, size: 22),
                  ),
                  Positioned(
                    bottom: -1,
                    right: -1,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: const Color(0xFF4CAF50),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'หมอวัว CowSmart',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text(context),
                      letterSpacing: -0.2,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'ผู้ช่วยวินิจฉัยและสัตวแพทย์ 24 ชม.',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.surfAlt(context),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.restart_alt_rounded, size: 20, color: AppColors.subText(context)),
            ),
            tooltip: 'เริ่มการสนทนาใหม่',
            onPressed: _clearChat,
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(
        children: [
          // 1. Chat Feed
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length && _isLoading) {
                  return _buildLoadingBubble();
                }
                final message = _messages[index];
                return _buildMessageItem(message);
              },
            ),
          ),

          // 2. Quick Suggested Topics Horizontal Bar
          if (_suggestedCategories.isNotEmpty)
            _buildSuggestedChipsBar(),

          // 3. Input Area
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildMessageItem(ChatMessage message) {
    if (message.isUser) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(4),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Text(
                  message.text,
                  style: const TextStyle(
                    fontSize: 14.5,
                    color: Colors.white,
                    height: 1.45,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2), width: 1.5),
              ),
              child: const Icon(Icons.person_rounded, size: 18, color: Colors.white),
            ),
          ],
        ),
      );
    }

    // AI Doctor Message Bubble
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
            ),
            child: const Center(
              child: Icon(Icons.health_and_safety_rounded, color: AppColors.primary, size: 19),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.cardBg(context),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(20),
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                    border: Border.all(color: AppColors.brd(context).withValues(alpha: 0.7)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Text(
                    message.text,
                    style: TextStyle(
                      fontSize: 14.5,
                      color: AppColors.text(context),
                      height: 1.55,
                    ),
                  ),
                ),

                // Suggested Action Buttons (e.g. Create Appointment / Record Health)
                if (message.actions != null && message.actions!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: message.actions!.map((action) {
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _handleSuggestedAction(action),
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.06),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.check_circle_outline_rounded, size: 14, color: AppColors.primaryDark),
                                const SizedBox(width: 6),
                                Text(
                                  action.label,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primaryDark,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(Icons.arrow_forward_ios_rounded, size: 10, color: AppColors.primaryDark),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingBubble() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(Icons.health_and_safety_rounded, color: AppColors.primary, size: 19),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.cardBg(context),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.brd(context)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                ),
                const SizedBox(width: 10),
                Text(
                  'หมอวัวกำลังวิเคราะห์อาการ...',
                  style: TextStyle(fontSize: 13.5, color: AppColors.subText(context), fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestedChipsBar() {
    final allItems = _suggestedCategories.expand((c) => c.items).toList();
    if (allItems.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg(context),
        border: Border(top: BorderSide(color: AppColors.div(context).withValues(alpha: 0.6))),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            child: Row(
              children: [
                Icon(Icons.tips_and_updates_outlined, size: 14, color: AppColors.subText(context)),
                const SizedBox(width: 5),
                Text(
                  'หัวข้อคำถามพบบ่อย:',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.subText(context)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 38,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: allItems.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final item = allItems[index];
                return InkWell(
                  onTap: () => _sendMessage(item.prompt),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.surfAlt(context),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.brd(context)),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      item.title,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text(context),
                      ),
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

  Widget _buildInputBar() {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(14, 10, 14, bottomInset > 0 ? bottomInset + 4 : 12),
      decoration: BoxDecoration(
        color: AppColors.cardBg(context),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              style: TextStyle(fontSize: 14.5, color: AppColors.text(context)),
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: _sendMessage,
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.surfAlt(context),
                hintText: 'พิมพ์เล่าอาการ หรือถามคำถามที่นี่...',
                hintStyle: TextStyle(fontSize: 13.5, color: AppColors.hint(context)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: AppColors.brd(context)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: AppColors.brd(context)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
              onPressed: () => _sendMessage(_textController.text),
            ),
          ),
        ],
      ),
    );
  }
}
