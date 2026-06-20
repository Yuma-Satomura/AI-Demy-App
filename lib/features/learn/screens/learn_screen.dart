import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';

class LearnScreen extends StatefulWidget {
  final String courseId;
  final String unitId;
  const LearnScreen({super.key, required this.courseId, required this.unitId});

  @override
  State<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends State<LearnScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  Map<String, dynamic>? _unit;
  final List<Map<String, dynamic>> _messages = [];
  final _chatCtrl = TextEditingController();
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _chatCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final unit = await Supabase.instance.client
        .from('curriculum_units')
        .select('title, difficulty')
        .eq('id', widget.unitId)
        .single();

    final msgs = await Supabase.instance.client
        .from('chat_messages')
        .select('role, content, created_at')
        .eq('unit_id', widget.unitId)
        .order('created_at')
        .limit(50);

    if (mounted) {
      setState(() {
        _unit = unit;
        _messages.addAll(List<Map<String, dynamic>>.from(msgs));
        _loading = false;
      });
    }
  }

  Future<void> _sendMessage() async {
    if (_chatCtrl.text.trim().isEmpty) return;
    final text = _chatCtrl.text.trim();
    _chatCtrl.clear();
    setState(() {
      _messages.add({'role': 'user', 'content': text});
      _sending = true;
    });

    try {
      final res = await Supabase.instance.client.functions.invoke(
        'ai-chat',
        body: {'courseId': widget.courseId, 'unitId': widget.unitId, 'message': text},
      );
      final reply = res.data?['content'] as String? ?? '応答を取得できませんでした';
      if (mounted) setState(() => _messages.add({'role': 'assistant', 'content': reply}));
    } catch (_) {
      if (mounted) setState(() => _messages.add({'role': 'assistant', 'content': 'エラーが発生しました。再度お試しください。'}));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.green)));

    return Scaffold(
      appBar: AppBar(
        title: Text(_unit?['title'] ?? '', style: const TextStyle(fontSize: 15)),
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: AppColors.green,
          labelColor: AppColors.green,
          unselectedLabelColor: AppColors.muted,
          tabs: const [
            Tab(text: 'コンテンツ'),
            Tab(text: 'AIチャット'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _contentTab(),
          _chatTab(),
        ],
      ),
    );
  }

  Widget _contentTab() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.video_library_outlined, size: 64, color: AppColors.muted),
            SizedBox(height: 16),
            Text('コンテンツを選択してください', style: TextStyle(color: AppColors.muted)),
          ],
        ),
      ),
    );
  }

  Widget _chatTab() {
    return Column(
      children: [
        Expanded(
          child: _messages.isEmpty
              ? Center(child: Text('AIに質問してみましょう', style: TextStyle(color: AppColors.muted)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length,
                  itemBuilder: (_, i) => _messageItem(_messages[i]),
                ),
        ),
        if (_sending)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.green)),
                const SizedBox(width: 8),
                Text('AI が回答中...', style: TextStyle(color: AppColors.muted, fontSize: 12)),
              ],
            ),
          ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _chatCtrl,
                  decoration: const InputDecoration(hintText: 'メッセージを入力...', isDense: true),
                  maxLines: null,
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.send, color: AppColors.green),
                onPressed: _sending ? null : _sendMessage,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _messageItem(Map<String, dynamic> msg) {
    final isUser = msg['role'] == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isUser ? AppColors.green : AppColors.surface2,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          msg['content'] ?? '',
          style: TextStyle(color: isUser ? AppColors.bg : AppColors.text, fontSize: 14),
        ),
      ),
    );
  }
}
