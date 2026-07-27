import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';

// Unread notification count helper (fetched once on load)
int _unreadCount = 0;

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _userData;
  List<Map<String, dynamic>> _enrollments = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final userData = await Supabase.instance.client
        .from('users')
        .select('display_name, streak_count')
        .eq('id', user.id)
        .maybeSingle();

    final enrollments = await Supabase.instance.client
        .from('enrollments')
        .select('course_id, courses(title, thumbnail_url)')
        .eq('user_id', user.id)
        .eq('status', 'active')
        .limit(5);

    final notifData = await Supabase.instance.client
        .from('notifications')
        .select('id')
        .eq('user_id', user.id)
        .eq('is_read', false);

    if (mounted) {
      setState(() {
        _userData = userData;
        _enrollments = List<Map<String, dynamic>>.from(enrollments);
        _unreadCount = (notifData as List).length;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('AI-Demy', style: TextStyle(color: AppColors.green, fontWeight: FontWeight.w800)),
        actions: [
          Stack(
            alignment: Alignment.topRight,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () => context.push('/notifications'),
              ),
              if (_unreadCount > 0)
                Positioned(
                  top: 8, right: 8,
                  child: Container(
                    width: 16, height: 16,
                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    child: Center(
                      child: Text(
                        _unreadCount > 9 ? '9+' : '$_unreadCount',
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.muted),
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.green))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _greeting(),
                  const SizedBox(height: 24),
                  _streakCard(),
                  const SizedBox(height: 24),
                  _sectionTitle('受講中のコース'),
                  const SizedBox(height: 12),
                  ..._enrollments.map(_enrollmentCard),
                  if (_enrollments.isEmpty)
                    _emptyState('コースをまだ受講していません', Icons.play_circle_outline),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () => context.go('/courses'),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.green),
                      foregroundColor: AppColors.green,
                    ),
                    child: const Text('コース一覧を見る'),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: _quickLinkCard(
                          icon: Icons.workspace_premium_outlined,
                          label: '証明書',
                          color: AppColors.amber,
                          onTap: () => context.push('/certificates'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _quickLinkCard(
                          icon: Icons.bar_chart_outlined,
                          label: '進捗管理',
                          color: AppColors.green,
                          onTap: () => context.push('/certificates'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _greeting() {
    final name = _userData?['display_name'] ?? 'ゲスト';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('こんにちは、$name さん', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text('今日も学習を続けましょう', style: TextStyle(fontSize: 13, color: AppColors.muted)),
      ],
    );
  }

  Widget _streakCard() {
    final streak = _userData?['streak_count'] ?? 0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(Icons.local_fire_department, color: AppColors.amber, size: 36),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$streak日連続', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
              Text('学習ストリーク', style: TextStyle(fontSize: 12, color: AppColors.muted)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700));
  }

  Widget _enrollmentCard(Map<String, dynamic> e) {
    final course = e['courses'] as Map<String, dynamic>?;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 48, height: 48,
          decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(6)),
          child: const Icon(Icons.play_circle, color: AppColors.green),
        ),
        title: Text(course?['title'] ?? 'コース', style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.muted),
        onTap: () => context.go('/courses/${e['course_id']}'),
      ),
    );
  }

  Widget _quickLinkCard({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(String msg, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Icon(icon, size: 48, color: AppColors.muted),
          const SizedBox(height: 12),
          Text(msg, style: TextStyle(color: AppColors.muted, fontSize: 13)),
        ],
      ),
    );
  }
}
