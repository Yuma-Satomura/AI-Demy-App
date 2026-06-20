import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';

class BtobDashboardScreen extends StatefulWidget {
  const BtobDashboardScreen({super.key});

  @override
  State<BtobDashboardScreen> createState() => _BtobDashboardScreenState();
}

class _BtobDashboardScreenState extends State<BtobDashboardScreen> {
  Map<String, dynamic>? _tenant;
  int _employeeCount = 0;
  int _courseCount = 0;
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
        .select('tenant_id, role')
        .eq('id', user.id)
        .single();

    final tenantId = userData['tenant_id'];
    if (tenantId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    final tenant = await Supabase.instance.client
        .from('tenants')
        .select('name, plan, max_seats')
        .eq('id', tenantId)
        .single();

    final employees = await Supabase.instance.client
        .from('employees')
        .select('id')
        .eq('tenant_id', tenantId);

    final assignments = await Supabase.instance.client
        .from('course_assignments')
        .select('id')
        .eq('tenant_id', tenantId);

    if (mounted) {
      setState(() {
        _tenant = tenant;
        _employeeCount = (employees as List).length;
        _courseCount = (assignments as List).length;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.green)));

    if (_tenant == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('BtoB管理')),
        body: Center(child: Text('テナントに所属していません', style: TextStyle(color: AppColors.muted))),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(_tenant!['name'] ?? 'BtoB管理')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _planCard(),
          const SizedBox(height: 20),
          _statsGrid(),
          const SizedBox(height: 24),
          const Text('クイックアクション', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          _actionCard(Icons.people_outline, '社員管理', '社員の追加・編集'),
          _actionCard(Icons.assignment_outlined, 'コース割当', '社員へのコース割当'),
          _actionCard(Icons.bar_chart_outlined, 'レポート', '研修効果レポート'),
          _actionCard(Icons.link, 'HR連携', 'SmartHR / freee 連携'),
        ],
      ),
    );
  }

  Widget _planCard() {
    final plan = _tenant!['plan'] as String? ?? 'small';
    final planLabel = {'small': 'スモール', 'standard': 'スタンダード', 'enterprise': 'エンタープライズ'}[plan] ?? plan;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [AppColors.surface, AppColors.surface2]),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.green.withValues(alpha:0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.business, color: AppColors.green, size: 32),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_tenant!['name'] ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('プラン: $planLabel', style: TextStyle(fontSize: 12, color: AppColors.muted)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statsGrid() {
    final maxSeats = _tenant!['max_seats'] as int? ?? 0;
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.8,
      children: [
        _statTile('社員数', '$_employeeCount / $maxSeats', Icons.people),
        _statTile('割当コース', '$_courseCount', Icons.library_books),
      ],
    );
  }

  Widget _statTile(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppColors.green, size: 18),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          Text(label, style: TextStyle(fontSize: 10, color: AppColors.muted)),
        ],
      ),
    );
  }

  Widget _actionCard(IconData icon, String title, String subtitle) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(icon, color: AppColors.green),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: AppColors.muted)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.muted),
        onTap: () {},
      ),
    );
  }
}
