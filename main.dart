import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'login_screen.dart';
import 'register_screen.dart';
import 'register_seller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize locale data
  await initializeDateFormatting('th_TH', null);
  await initializeDateFormatting('en_US', null);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FoodLoop',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/registerSeller': (context) => const RegisterSellerScreen(),
      },
    );
  }
}
