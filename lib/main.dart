import 'dart:io';
import 'package:logging/logging.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final Logger logger = Logger('test_plugin_ui');

  if (!Platform.isWindows) throw Exception("Platform not supported: ${Platform.operatingSystem}");

  // window_manager setup (native API: set the properties, then show)
  final window = WindowManager.instance.getCurrent()!;
  // window.titleBarStyle = TitleBarStyle.hidden;
  // window.title = 'Cancom VeraPrint';
  // window.setSize(const Size(1024, 720).toNative(), false);
  // // window.backgroundColor = Colors.transparent.toNative();
  // window.isVisibleInTaskbar = true;
  // window.center();
  // window.show();
  // window.focus();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: .fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    return Placeholder();
  }
}
