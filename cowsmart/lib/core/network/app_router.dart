import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cowsmart/features/auth/presentation/screens/login_screen.dart';
import 'package:cowsmart/features/auth/presentation/screens/register_screen.dart';
import 'package:cowsmart/features/auth/presentation/screens/otp_screen.dart';
import 'package:cowsmart/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:cowsmart/features/auth/presentation/screens/reset_password_screen.dart';
import '../../features/farm/presentation/screens/create_farm_screen.dart';
import '../../features/farm/presentation/screens/edit_farm_screen.dart';
import '../../features/farm/domain/farm.dart';
import '../../features/farm/presentation/screens/create_zone_screen.dart';
import '../../features/farm/presentation/screens/zone_detail_screen.dart';
import '../../features/farm/presentation/screens/select_farm_screen.dart';
import '../../features/farm/presentation/screens/dashboard/main_layout_screen.dart';
import '../../features/cow/presentation/screens/add_cow_screen.dart';
import '../../features/cow/presentation/screens/cow_detail_screen.dart';
import '../../features/cow/presentation/screens/edit_cow_screen.dart';
import '../../features/cow/presentation/screens/cull_cow_screen.dart';
import '../../features/cow/presentation/screens/culling_history_screen.dart';
import '../../features/finance/presentation/screens/finance_overview_screen.dart';
import '../../features/market/presentation/screens/market_price_screen.dart';
import '../../features/notifications/presentation/screens/notification_screen.dart';
import '../../features/calendar/presentation/screens/calendar_screen.dart';
import '../../features/cow/domain/cow.dart';
import '../../features/farm/domain/zone.dart';
import '../../features/auth/providers/auth_provider.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authNotifier = RouterNotifier(ref);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final isLoggingIn =
          state.matchedLocation == '/login' ||
          state.matchedLocation == '/register' ||
          state.matchedLocation == '/otp' ||
          state.matchedLocation == '/forgot-password' ||
          state.matchedLocation == '/reset-password';

      if (!authState.isAuthenticated) {
        return isLoggingIn ? null : '/login';
      }

      if (isLoggingIn) {
        return '/select-farm';
      }

      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/otp',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          final email = extra['email'] as String? ?? '';
          final isForgotPassword = extra['isForgotPassword'] as bool? ?? false;
          return OtpScreen(email: email, isForgotPassword: isForgotPassword);
        },
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          final email = extra['email'] as String? ?? '';
          final otp = extra['otp'] as String? ?? '';
          return ResetPasswordScreen(email: email, otp: otp);
        },
      ),
      GoRoute(
        path: '/create_farm',
        builder: (context, state) => const CreateFarmScreen(),
      ),
      GoRoute(
        path: '/create_zone',
        builder: (context, state) => const CreateZoneScreen(),
      ),
      GoRoute(
        path: '/zone_detail',
        builder: (context, state) {
          final zone = state.extra as Zone;
          return ZoneDetailScreen(zone: zone);
        },
      ),
      GoRoute(
        path: '/select-farm',
        builder: (context, state) => const SelectFarmScreen(),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const MainLayoutScreen(),
      ),
      GoRoute(
        path: '/finance',
        builder: (context, state) => const FinanceOverviewScreen(),
      ),
      GoRoute(
        path: '/add_cow',
        builder: (context, state) {
          final initData = state.extra as Map<String, dynamic>?;
          return AddCowScreen(initialData: initData);
        },
      ),
      GoRoute(
        path: '/cow_detail',
        builder: (context, state) {
          final cow = state.extra as Cow;
          return CowDetailScreen(cow: cow);
        },
      ),
      GoRoute(
        path: '/edit_cow',
        builder: (context, state) {
          final cow = state.extra as Cow;
          return EditCowScreen(cow: cow);
        },
      ),
      GoRoute(
        path: '/cull_cow',
        builder: (context, state) {
          final cow = state.extra as Cow;
          return CullCowScreen(cow: cow);
        },
      ),
      GoRoute(
        path: '/edit_farm',
        builder: (context, state) {
          final farm = state.extra as Farm;
          return EditFarmScreen(farm: farm);
        },
      ),
      GoRoute(
        path: '/market_price',
        builder: (context, state) => const MarketPriceScreen(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationScreen(),
      ),
      GoRoute(
        path: '/calendar',
        builder: (context, state) => const CalendarScreen(),
      ),
      GoRoute(
        path: '/culling_history',
        builder: (context, state) => const CullingHistoryScreen(),
      ),
    ],
  );
});

class RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  RouterNotifier(this._ref) {
    _ref.listen(authProvider, (_, __) {
      notifyListeners();
    });
  }
}
