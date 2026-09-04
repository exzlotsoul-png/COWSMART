import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/cow_icon.dart';
import '../../../cow/domain/cow.dart';
import '../../../cow/providers/cow_provider.dart';
import '../../data/ai_chat_repository.dart';
import '../../domain/chat_message.dart';

class AiVetChatScreen extends ConsumerStatefulWidget {
  final String? initialCowId;

  const AiVetChatScreen({super.key, this.initialCowId});

  @override
  ConsumerState<AiVetChatScreen> createState() => _AiVetChatScreenState();
}

class _AiVetChatScreenState extends ConsumerState<AiVetChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];

  bool _isLoading = false;
  List<SuggestedTopicCategory> _suggestedCategories = [];
  Cow? _selectedCow;

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
      cowName: _selectedCow?.name,
      cowTag: _selectedCow?.tagNumber,
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
        cowId: _selectedCow?.id,
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
    final cowState = ref.watch(cowProvider);
    final allCows = cowState.allCows;

    // Set initial cow if passed in widget
    if (widget.initialCowId != null && _selectedCow == null && allCows.isNotEmpty) {
      _selectedCow = allCows.firstWhere(
        (c) => c.id == widget.initialCowId,
        orElse: () => allCows.first,
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        backgroundColor: AppColors.cardBg(context),
        elevation: 0.5,
        titleSpacing: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: AppColors.text(context)),
          onPressed: () => context.pop(),
        ),
        title: Row(
          children: [
            Stack(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(Icons.health_and_safety_rounded, color: AppColors.primary, size: 22),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: const Color(0xFF22C55E),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'หมอวัว CowSmart',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text(context),
                  ),
                ),
                const Text(
                  'AI ผู้ช่วยสัตวแพทย์ 24 ชม.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF16A34A),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textSecondary),
            tooltip: 'เริ่มสนทนาใหม่',
            onPressed: _clearChat,
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Cow Selector Banner Card
          _buildCowSelectorBar(allCows),

          // 2. Chat Feed
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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

          // 3. Quick Suggested Topics Horizontal Bar
          if (_suggestedCategories.isNotEmpty)
            _buildSuggestedChipsBar(),

          // 4. Input Area
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildCowSelectorBar(List<Cow> allCows) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.cardBg(context),
        border: Border(bottom: BorderSide(color: AppColors.div(context))),
      ),
      child: Row(
        children: [
          const CowIcon(size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(
            'ปรึกษาสำหรับ:',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.subText(context)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: AppColors.surfAlt(context),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  dropdownColor: AppColors.cardBg(context),
                  value: _selectedCow?.id,
                  hint: Text('ถามทั่วไป / ไม่เจาะจงวัว', style: TextStyle(fontSize: 12.5, color: AppColors.hint(context))),
                  icon: Icon(Icons.arrow_drop_down_rounded, color: AppColors.subText(context)),
                  items: [
                    DropdownMenuItem<String>(
                      value: null,
                      child: Text('ถามทั่วไป / ทั้งฟาร์ม', style: TextStyle(fontSize: 12.5, color: AppColors.text(context))),
                    ),
                    ...allCows.map(
                      (cow) => DropdownMenuItem<String>(
                        value: cow.id,
                        child: Text(
                          '${cow.tagNumber} - ${cow.name} (${cow.breed})',
                          style: TextStyle(fontSize: 12.5, color: AppColors.text(context), fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (selectedId) {
                    setState(() {
                      if (selectedId == null) {
                        _selectedCow = null;
                      } else {
                        _selectedCow = allCows.firstWhere((c) => c.id == selectedId);
                      }
                    });
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageItem(ChatMessage message) {
    if (message.isUser) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(18),
                    bottomLeft: Radius.circular(18),
                    bottomRight: Radius.circular(4),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (message.cowName != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${message.cowTag != null ? "[${message.cowTag}] " : ""}${message.cowName}',
                          style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                    Text(
                      message.text,
                      style: const TextStyle(
                        fontSize: 14.5,
                        color: Colors.white,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            const CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primaryLight,
              child: Icon(Icons.person, size: 18, color: AppColors.primaryDark),
            ),
          ],
        ),
      );
    }

    // AI Doctor Message Bubble
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(Icons.health_and_safety_rounded, color: AppColors.primary, size: 18),
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
                      topRight: Radius.circular(18),
                      bottomLeft: Radius.circular(18),
                      bottomRight: Radius.circular(18),
                    ),
                    border: Border.all(color: AppColors.brd(context)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    message.text,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.text(context),
                      height: 1.5,
                    ),
                  ),
                ),

                // Suggested Action Buttons (e.g. Create Appointment / Record Health)
                if (message.actions != null && message.actions!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: message.actions!.map((action) {
                      return InkWell(
                        onTap: () => _handleSuggestedAction(action),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFF86EFAC)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                action.label,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF166534),
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.arrow_forward_ios_rounded, size: 10, color: Color(0xFF166534)),
                            ],
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
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(Icons.health_and_safety_rounded, color: AppColors.primary, size: 18),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                ),
                SizedBox(width: 10),
                Text(
                  'หมอวัวกำลังวิเคราะห์อาการ...',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestedChipsBar() {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.cardBg(context),
        border: Border(top: BorderSide(color: AppColors.div(context))),
      ),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        scrollDirection: Axis.horizontal,
        itemCount: _suggestedCategories.expand((c) => c.items).length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final allItems = _suggestedCategories.expand((c) => c.items).toList();
          final item = allItems[index];
          return ActionChip(
            label: Text(
              item.title,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.text(context)),
            ),
            backgroundColor: AppColors.surfAlt(context),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: AppColors.brd(context))),
            onPressed: () => _sendMessage(item.prompt),
          );
        },
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).padding.bottom + 8),
      decoration: BoxDecoration(
        color: AppColors.cardBg(context),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: AppColors.surfAlt(context),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.brd(context)),
              ),
              child: TextField(
                controller: _textController,
                style: TextStyle(color: AppColors.text(context)),
                textInputAction: TextInputAction.send,
                onSubmitted: _sendMessage,
                decoration: InputDecoration(
                  hintText: 'พิมพ์เล่าอาการ หรือถามคำถามที่นี่...',
                  hintStyle: TextStyle(fontSize: 13.5, color: AppColors.hint(context)),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
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
