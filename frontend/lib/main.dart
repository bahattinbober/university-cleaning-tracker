import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/rooms_screen.dart';
import 'screens/qr_cleaning_screen.dart';
import 'screens/my_cleanings_screen.dart';
import 'screens/admin_all_cleanings_screen.dart';
import 'screens/admin_all_users_screen.dart';
import 'screens/register_screen.dart';
import 'screens/admin_pending_users_screen.dart';
import 'screens/admin_weekly_kpi_screen.dart';
import 'screens/admin_scheduled_task_screen.dart';
import 'screens/my_scheduled_tasks_screen.dart';
import 'screens/change_password_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Temizlik Takip',
      debugShowCheckedModeBanner: false,
      initialRoute: "/login",
      routes: {
        "/login": (context) => const LoginScreen(),
        "/register": (context) => const RegisterScreen(),
        "/home": (context) => const HomeScreen(),
        "/rooms": (context) => const RoomsScreen(),
        "/qr-cleaning": (context) => const QRCleaningScreen(),
        "/my-cleanings": (context) => const MyCleaningsScreen(),
        "/admin-all-cleanings": (context) => const AdminAllCleaningsScreen(),
        "/admin-users": (context) => const AdminAllUsersScreen(),
        "/admin-pending-users": (context) => const AdminPendingUsersScreen(),
        "/admin-weekly-kpi": (context) => const AdminWeeklyKpiScreen(),
        "/admin-scheduled-task": (context) => const AdminScheduledTaskScreen(),
        "/my-scheduled-tasks": (context) => const MyScheduledTasksScreen(),
        "/change-password": (context) => const ChangePasswordScreen(),
      },

      theme: AppTheme.lightTheme,
    );
  }
}
