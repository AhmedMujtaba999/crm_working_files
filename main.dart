import 'package:flutter/material.dart';
import 'theme.dart';
import 'routes.dart';
import 'storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  setupSystemUI(); 
  await AppDb.instance.init(); // it will initialize the database and makes sure it's ready before running the app
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: appTheme,
      onGenerateRoute: AppRoutes.onGenerateRoute,
      
      initialRoute: '/',
    
    );
  }
}
