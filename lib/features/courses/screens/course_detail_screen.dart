import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/config/api_config.dart';
import '../../../core/network/app_http_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/price_format.dart';

class CourseDetailScreen extends StatefulWidget {
  final String courseId;
  const CourseDetailScreen({super.key, required this.courseId});

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  Map<String, dynamic>? _course;
  List<Map<String, dynamic>> _units = [];
  bool _enrolled = false;
  bool _loading = true;
  bool _purchasing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = Supabase.instance.client.auth.currentUser;

    final course = await Supabase.instance.client
        .from('courses')
        .select('*, users!instructor_id(display_name, avatar_url)')
        .eq('id', widget.courseId)
        .single();

    final units = await Supabase.instance.client
        .from('curriculum_units')
        .select('id, title, order_index, difficulty')
        .eq('course_id', widget.courseId)
        .order('order_index');

    bool enrolled = false;
    if (user != null) {
      final enr = await Supabase.instance.client
          .from('enrollments')
          .select('id')
          .eq('user_id', user.id)
          .eq('course_id', widget.courseId)
          .eq('status', 'active')
          .maybeSingle();
      enrolled = enr != null;
    }

    if (mounted) {
      setState(() {
        _course = course;
        _units = List<Map<String, dynamic>>.from(units);
        _enrolled = enrolled;
        _loading = false;
      });
    }
  }

  Future<void> _handlePurchase() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return;

    setState(() => _purchasing = true);

    try {
      final res = await appHttpClient.post(
        Uri.parse('$kApiBaseUrl/api/mobile/payment-intent'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.accessToken}',
        },
        body: jsonEncode({'courseId': widget.courseId}),
      );

      if (res.statusCode != 200) {
        _showError('受講登録に失敗しました (${res.statusCode})');
        return;
      }

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final type = data['type'] as String?;

      if (type == 'free' || type == 'enrolled') {
        if (mounted) setState(() => _enrolled = true);
        return;
      }

      if (type == 'subscription') {
        // 空文字は Uri.tryParse が空の Uri を返して null にならないため先に弾く
        final rawUrl = data['url'] as String? ?? '';
        final url = rawUrl.isEmpty ? null : Uri.tryParse(rawUrl);
        if (url != null && await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        }
        return;
      }

      if (type == 'one_time') {
        final clientSecret = data['clientSecret'] as String;
        final ephemeralKey = data['ephemeralKey'] as String;
        final customerId = data['customerId'] as String;

        await Stripe.instance.initPaymentSheet(
          paymentSheetParameters: SetupPaymentSheetParameters(
            merchantDisplayName: 'AI-Demy',
            customerId: customerId,
            customerEphemeralKeySecret: ephemeralKey,
            paymentIntentClientSecret: clientSecret,
            style: ThemeMode.dark,
          ),
        );

        await Stripe.instance.presentPaymentSheet();

        // Confirm enrollment server-side
        final paymentIntentId = clientSecret.split('_secret_').first;
        final confirmRes = await appHttpClient.post(
          Uri.parse('$kApiBaseUrl/api/mobile/complete-payment'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${session.accessToken}',
          },
          body: jsonEncode({
            'paymentIntentId': paymentIntentId,
            'courseId': widget.courseId,
          }),
        );

        if (confirmRes.statusCode == 200 && mounted) {
          setState(() => _enrolled = true);
        }
      }
    } on StripeException catch (e) {
      if (e.error.code != FailureCode.Canceled) {
        _showError(e.error.localizedMessage ?? '支払いに失敗しました');
      }
    } catch (_) {
      _showError('エラーが発生しました');
    } finally {
      if (mounted) setState(() => _purchasing = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red[700]),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.green)));

    final course = _course!;
    final instructor = course['users'] as Map<String, dynamic>?;
    final price = formatCoursePriceFromRow(course);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
        title: Text(course['title'] ?? '', style: const TextStyle(fontSize: 16)),
      ),
      body: ListView(
        children: [
          Container(
            height: 200,
            color: AppColors.surface2,
            child: const Center(child: Icon(Icons.play_circle, size: 64, color: AppColors.green)),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(course['title'] ?? '', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const CircleAvatar(radius: 14, backgroundColor: AppColors.surface2, child: Icon(Icons.person, size: 16)),
                    const SizedBox(width: 8),
                    Text(instructor?['display_name'] ?? '', style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 16),
                if (course['description'] != null)
                  Text(course['description'], style: const TextStyle(fontSize: 14, height: 1.7)),
                const SizedBox(height: 24),
                _unitList(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _bottomBar(price),
    );
  }

  Widget _unitList() {
    if (_units.isEmpty) return const SizedBox();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('カリキュラム', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        ..._units.asMap().entries.map((e) {
          final unit = e.value;
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              width: 32, height: 32,
              decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(4)),
              child: Center(child: Text('${e.key + 1}', style: const TextStyle(fontSize: 12))),
            ),
            title: Text(unit['title'] ?? '', style: const TextStyle(fontSize: 14)),
            trailing: _enrolled
                ? IconButton(
                    icon: const Icon(Icons.play_arrow, color: AppColors.green),
                    onPressed: () => context.go('/courses/${widget.courseId}/learn/${unit['id']}'),
                  )
                : const Icon(Icons.lock_outline, size: 16, color: AppColors.muted),
          );
        }),
      ],
    );
  }

  Widget _bottomBar(String price) {
    return Container(
      padding: const EdgeInsets.all(16).copyWith(bottom: 32),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: _enrolled
          ? Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _units.isNotEmpty ? () => context.go('/courses/${widget.courseId}/learn/${_units.first['id']}') : null,
                    child: const Text('学習を続ける'),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => context.push('/courses/${widget.courseId}/progress'),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.green),
                    foregroundColor: AppColors.green,
                  ),
                  child: const Text('進捗'),
                ),
              ],
            )
          : Row(
              children: [
                Text(price, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.green)),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _purchasing ? null : _handlePurchase,
                    child: _purchasing
                        ? const SizedBox(
                            height: 18, width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('受講する'),
                  ),
                ),
              ],
            ),
    );
  }
}
