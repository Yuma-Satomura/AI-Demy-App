import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// ボトムナビの各タブに対応するルート。インデックスは表示順と一致する。
const navRoutes = ['/dashboard', '/courses', '/instructor', '/btob'];

/// 現在のロケーションから、選択中のボトムナビのインデックスを求める。
/// どのタブにも該当しない場合はホーム（0）にフォールバックする。
int navIndexForLocation(String location) {
  if (location.startsWith('/courses')) return 1;
  if (location.startsWith('/instructor')) return 2;
  if (location.startsWith('/btob')) return 3;
  return 0;
}

class MainShell extends StatelessWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: navIndexForLocation(
          GoRouterState.of(context).matchedLocation,
        ),
        onTap: (i) => context.go(navRoutes[i]),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'ホーム'),
          BottomNavigationBarItem(icon: Icon(Icons.play_circle_outline), activeIcon: Icon(Icons.play_circle), label: 'コース'),
          BottomNavigationBarItem(icon: Icon(Icons.school_outlined), activeIcon: Icon(Icons.school), label: '講師'),
          BottomNavigationBarItem(icon: Icon(Icons.business_outlined), activeIcon: Icon(Icons.business), label: 'BtoB'),
        ],
      ),
    );
  }
}
