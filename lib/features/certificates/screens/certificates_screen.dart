import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';

class CertificatesScreen extends StatefulWidget {
  const CertificatesScreen({super.key});

  @override
  State<CertificatesScreen> createState() => _CertificatesScreenState();
}

class _CertificatesScreenState extends State<CertificatesScreen> {
  List<Map<String, dynamic>> _certs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final data = await Supabase.instance.client
        .from('completion_certs')
        .select('id, issued_at, score, courses(title)')
        .eq('user_id', user.id)
        .order('issued_at', ascending: false);

    if (mounted) {
      setState(() {
        _certs = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('修了証明書')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.green))
          : _certs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.workspace_premium_outlined, size: 64, color: AppColors.muted),
                      const SizedBox(height: 16),
                      Text('まだ証明書がありません', style: TextStyle(color: AppColors.muted)),
                      const SizedBox(height: 8),
                      Text('コースを修了すると証明書が発行されます',
                          style: TextStyle(color: AppColors.muted, fontSize: 12)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _certs.length,
                    itemBuilder: (context, i) => _certCard(_certs[i]),
                  ),
                ),
    );
  }

  Widget _certCard(Map<String, dynamic> cert) {
    final course = cert['courses'] as Map<String, dynamic>?;
    final score = cert['score'] as int?;
    final issuedAt = cert['issued_at'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.green.withAlpha(60)),
        boxShadow: [BoxShadow(color: AppColors.green.withAlpha(20), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.workspace_premium, color: AppColors.amber, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  course?['title'] ?? 'コース',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (score != null) ...[
            Row(children: [
              Icon(Icons.star, color: AppColors.amber, size: 16),
              const SizedBox(width: 4),
              Text('スコア: $score点', style: const TextStyle(fontSize: 13)),
            ]),
            const SizedBox(height: 6),
          ],
          Row(children: [
            Icon(Icons.calendar_today, color: AppColors.muted, size: 14),
            const SizedBox(width: 4),
            Text(_formatDate(issuedAt), style: TextStyle(fontSize: 12, color: AppColors.muted)),
          ]),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.green.withAlpha(20),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('修了', style: TextStyle(color: AppColors.green, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.year}年${dt.month}月${dt.day}日';
    } catch (_) {
      return iso;
    }
  }
}
