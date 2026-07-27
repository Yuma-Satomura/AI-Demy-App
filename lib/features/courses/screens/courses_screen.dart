import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/price_format.dart';

class CoursesScreen extends StatefulWidget {
  const CoursesScreen({super.key});

  @override
  State<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends State<CoursesScreen> {
  List<Map<String, dynamic>> _courses = [];
  bool _loading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    var q = Supabase.instance.client
        .from('courses')
        .select('id, title, description, thumbnail_url, price_type, price_monthly, price_one_time, users!instructor_id(display_name)')
        .eq('is_published', true);

    if (_query.isNotEmpty) {
      q = q.ilike('title', '%$_query%');
    }

    final data = await q.limit(30);
    if (mounted) {
      setState(() {
        _courses = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('コース一覧')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'コースを検索...',
                prefixIcon: Icon(Icons.search, color: AppColors.muted),
              ),
              onChanged: (v) {
                setState(() => _query = v);
                _load();
              },
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.green))
                : _courses.isEmpty
                    ? Center(child: Text('コースが見つかりません', style: TextStyle(color: AppColors.muted)))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _courses.length,
                        itemBuilder: (_, i) => _courseCard(_courses[i]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _courseCard(Map<String, dynamic> course) {
    final instructor = course['users'] as Map<String, dynamic>?;
    final price = formatCoursePriceFromRow(course);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => context.go('/courses/${course['id']}'),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.play_circle, color: AppColors.green, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(course['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    const SizedBox(height: 4),
                    Text(instructor?['display_name'] ?? '', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                    const SizedBox(height: 8),
                    Text(price, style: TextStyle(fontSize: 13, color: AppColors.green, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}
