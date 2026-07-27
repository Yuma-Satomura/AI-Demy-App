import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';

class CourseProgressScreen extends StatefulWidget {
  final String courseId;
  const CourseProgressScreen({super.key, required this.courseId});

  @override
  State<CourseProgressScreen> createState() => _CourseProgressScreenState();
}

class _CourseProgressScreenState extends State<CourseProgressScreen> {
  Map<String, dynamic>? _course;
  List<Map<String, dynamic>> _units = [];
  Set<String> _completedUnitIds = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final course = await Supabase.instance.client
        .from('courses')
        .select('id, title')
        .eq('id', widget.courseId)
        .single();

    final units = await Supabase.instance.client
        .from('curriculum_units')
        .select('id, title, order_index')
        .eq('course_id', widget.courseId)
        .order('order_index');

    // unit_progress に status 列はない。完了は boolean の completed
    // （ウェブ版も .eq('completed', true) で判定している）
    final progress = await Supabase.instance.client
        .from('unit_progress')
        .select('unit_id')
        .eq('user_id', user.id)
        .eq('course_id', widget.courseId)
        .eq('completed', true);

    if (mounted) {
      setState(() {
        _course = course;
        _units = List<Map<String, dynamic>>.from(units);
        _completedUnitIds = Set<String>.from(
          (progress as List).map((p) => p['unit_id'] as String),
        );
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.green)));

    final total = _units.length;
    final completed = _completedUnitIds.length;
    final pct = total > 0 ? completed / total : 0.0;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
        title: Text(_course?['title'] ?? '', style: const TextStyle(fontSize: 15)),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _progressHeader(completed, total, pct),
            const SizedBox(height: 24),
            const Text('ユニット進捗', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            ..._units.asMap().entries.map((e) => _unitTile(e.key + 1, e.value)),
          ],
        ),
      ),
    );
  }

  Widget _progressHeader(int completed, int total, double pct) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('進捗率', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              Text('$completed / $total', style: const TextStyle(fontSize: 13, color: AppColors.green)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 8,
              backgroundColor: AppColors.surface2,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.green),
            ),
          ),
          const SizedBox(height: 8),
          Text('${(pct * 100).round()}% 完了', style: TextStyle(fontSize: 12, color: AppColors.muted)),
          if (pct == 1.0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.green.withAlpha(20),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.workspace_premium, color: AppColors.amber, size: 16),
                  SizedBox(width: 4),
                  Text('修了', style: TextStyle(color: AppColors.green, fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _unitTile(int index, Map<String, dynamic> unit) {
    final done = _completedUnitIds.contains(unit['id'] as String?);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: done ? AppColors.green.withAlpha(30) : AppColors.surface2,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: done ? AppColors.green : AppColors.border),
        ),
        child: Center(
          child: done
              ? const Icon(Icons.check, color: AppColors.green, size: 18)
              : Text('$index', style: const TextStyle(fontSize: 12)),
        ),
      ),
      title: Text(
        unit['title'] ?? '',
        style: TextStyle(
          fontSize: 14,
          color: done ? AppColors.muted : null,
          decoration: done ? TextDecoration.lineThrough : null,
        ),
      ),
      trailing: done
          ? null
          : IconButton(
              icon: const Icon(Icons.play_arrow, color: AppColors.green),
              onPressed: () => context.go('/courses/${widget.courseId}/learn/${unit['id']}'),
            ),
    );
  }
}
