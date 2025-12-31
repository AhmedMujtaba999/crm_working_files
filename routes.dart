import 'package:flutter/material.dart';
import 'task_create.dart';
import 'splash.dart';
import 'home_shell.dart';
import 'invoice.dart';

class AppRoutes {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/':
        return MaterialPageRoute(
          builder: (_) => const SplashScreen(),
          settings: settings,
        );

      case '/home':
        // Accept arguments: {'tab': 1, 'workTab': 'active'|'completed'}
        int tab = 0;
        String? workTab;

        final args = settings.arguments;
        if (args is Map) {
          final t = args['tab'];
          if (t is int) tab = t;

          final wt = args['workTab'];
          if (wt is String && wt.trim().isNotEmpty) workTab = wt.trim();
        }

        return MaterialPageRoute(
          builder: (_) => HomeShell(
            initialTab: tab,
            workTab: workTab,
          ),
          settings: settings,
        );

      case '/invoice':
        // Accept String directly OR {'id': '...'}
        String? workItemId;
        final args = settings.arguments;

        if (args is String && args.trim().isNotEmpty) {
          workItemId = args.trim();
        } else if (args is Map && args['id'] is String) {
          final id = (args['id'] as String).trim();
          if (id.isNotEmpty) workItemId = id;
        }

        if (workItemId == null) {
          // Safe fallback screen if someone navigates incorrectly
          return MaterialPageRoute(
            builder: (_) => const Scaffold(
              body: Center(child: Text("Missing Work Item ID for invoice.")),
            ),
            settings: settings,
          );
        }

        // Pass the ID via RouteSettings so InvoicePage can read it
        return MaterialPageRoute(
          builder: (_) => const InvoicePage(),
          settings: RouteSettings(name: '/invoice', arguments: workItemId),
        );

      case '/task_create':
        // Create a new task. We return 'true' on save so caller can refresh.
        return MaterialPageRoute(
          builder: (_) => const CreateTaskPage(),
          settings: settings,
        );

      default:
        // Unknown route fallback
        return MaterialPageRoute(
          builder: (_) => const SplashScreen(),
          settings: settings,
        );
    }
  }
}
