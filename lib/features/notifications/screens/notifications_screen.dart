import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> _notifications = [];
  bool _loading = true;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _load();
    _subscribe();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  Future<void> _load() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final data = await Supabase.instance.client
        .from('notifications')
        .select('id, type, title, body, link, is_read, created_at')
        .eq('user_id', user.id)
        .order('created_at', ascending: false)
        .limit(50);

    if (mounted) {
      setState(() {
        _notifications = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    }

    // Mark all as read
    await Supabase.instance.client
        .from('notifications')
        .update({'is_read': true})
        .eq('user_id', user.id)
        .eq('is_read', false);
  }

  void _subscribe() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    _channel = Supabase.instance.client
        .channel('notifications:${user.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: user.id,
          ),
          callback: (payload) {
            if (mounted) {
              setState(() {
                _notifications.insert(0, Map<String, dynamic>.from(payload.newRecord));
              });
            }
          },
        )
        .subscribe();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('通知')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.green))
          : _notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.notifications_none, size: 64, color: AppColors.muted),
                      const SizedBox(height: 16),
                      Text('通知はありません', style: TextStyle(color: AppColors.muted)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    itemCount: _notifications.length,
                    separatorBuilder: (_, _) => Divider(height: 1, color: AppColors.border),
                    itemBuilder: (context, i) => _tile(_notifications[i]),
                  ),
                ),
    );
  }

  Widget _tile(Map<String, dynamic> n) {
    final type = n['type'] as String? ?? '';
    final isRead = n['is_read'] as bool? ?? true;
    return Container(
      color: isRead ? Colors.transparent : AppColors.green.withAlpha(10),
      child: ListTile(
        leading: Text(_typeIcon(type), style: const TextStyle(fontSize: 24)),
        title: Text(
          n['title'] ?? '',
          style: TextStyle(
            fontWeight: isRead ? FontWeight.normal : FontWeight.w600,
            fontSize: 13,
          ),
        ),
        subtitle: n['body'] != null
            ? Text(n['body'], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11))
            : null,
        trailing: Text(_timeAgo(n['created_at'] ?? ''), style: TextStyle(fontSize: 10, color: AppColors.muted)),
      ),
    );
  }

  String _typeIcon(String type) {
    switch (type) {
      case 'thread_reply': return '💬';
      case 'thread_like': return '❤️';
      case 'ojt_approved': return '✅';
      case 'ojt_rejected': return '❌';
      case 'cert_issued': return '🎓';
      default: return '🔔';
    }
  }

  String _timeAgo(String iso) {
    try {
      final diff = DateTime.now().difference(DateTime.parse(iso));
      if (diff.inMinutes < 1) return 'たった今';
      if (diff.inHours < 1) return '${diff.inMinutes}分前';
      if (diff.inDays < 1) return '${diff.inHours}時間前';
      return '${diff.inDays}日前';
    } catch (_) {
      return '';
    }
  }
}
