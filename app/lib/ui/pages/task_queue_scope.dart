import 'package:flutter/widgets.dart';

import '../../core/app_state.dart';

/// يوفّر حالة التطبيق لكل الشجرة بلا حزم إدارة حالة خارجية.
class AppStateScope extends InheritedNotifier<AppState> {
  const AppStateScope({
    super.key,
    required AppState state,
    required super.child,
  }) : super(notifier: state);

  static AppState of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<AppStateScope>();
    assert(scope?.notifier != null, 'AppStateScope غير موجود في الشجرة');
    return scope!.notifier!;
  }

  /// قراءة بلا اشتراك (للأزرار).
  static AppState read(BuildContext context) {
    final element = context.getElementForInheritedWidgetOfExactType<AppStateScope>();
    final widget = element?.widget;
    assert(widget is AppStateScope, 'AppStateScope غير موجود في الشجرة');
    return (widget! as AppStateScope).notifier!;
  }
}
