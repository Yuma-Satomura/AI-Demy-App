import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';

class InstructorDashboardScreen extends StatefulWidget {
  const InstructorDashboardScreen({super.key});

  @override
  State<InstructorDashboardScreen> createState() => _InstructorDashboardScreenState();
}

class _InstructorDashboardScreenState extends State<InstructorDashboardScreen> {
  List<Map<String, dynamic>> _courses = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final courses = await Supabase.instance.client
        .from('courses')
        .select('id, title, is_published, price_monthly, price_one_time, price_type')
        .eq('instructor_id', user.id)
        .order('created_at', ascending: false);

    if (mounted) {
      setState(() {
        _courses = List<Map<String, dynamic>>.from(courses);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('講師ダッシュボード')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.green))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _statsRow(),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('マイコース', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    TextButton(onPressed: () {}, child: Text('+ 新規作成', style: TextStyle(color: AppColors.green))),
                  ],
                ),
                const SizedBox(height: 12),
                ..._courses.map(_courseCard),
                if (_courses.isEmpty)
                  Center(child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text('まだコースがありません', style: TextStyle(color: AppColors.muted)),
                  )),
              ],
            ),
    );
  }

  Widget _statsRow() {
    return Row(
      children: [
        _statCard('コース数', '${_courses.length}', Icons.library_books_outlined),
        const SizedBox(width: 12),
        _statCard('公開中', '${_courses.where((c) => c['is_published'] == true).length}', Icons.public),
      ],
    );
  }

  Widget _statCard(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.green, size: 20),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                Text(label, style: TextStyle(fontSize: 11, color: AppColors.muted)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _courseCard(Map<String, dynamic> course) {
    final published = course['is_published'] == true;
    final priceType = course['price_type'] as String?;
    final price = priceType == 'subscription'
        ? '¥${course['price_monthly']}/月'
        : '¥${course['price_one_time']}';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(course['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(price, style: TextStyle(color: AppColors.green, fontSize: 12)),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: published ? AppColors.green.withValues(alpha:0.1) : AppColors.muted.withValues(alpha:0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            published ? '公開中' : '非公開',
            style: TextStyle(fontSize: 10, color: published ? AppColors.green : AppColors.muted),
          ),
        ),
      ),
    );
  }
}
