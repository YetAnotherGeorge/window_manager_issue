import 'dart:io';
import 'package:flutter/material.dart';
import 'package:test_ui_windows/custom_wnd_base.dart';
import 'package:window_manager/window_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!Platform.isWindows) throw Exception("Platform not supported: ${Platform.operatingSystem}");

  await windowManager.ensureInitialized();
  const windowOptions = WindowOptions(
    size: Size(1024, 720),
    center: true,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
    title: 'Demo',
  );
  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.center();
    await windowManager.focus();
  });


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
    return CustomTitleBarWindowsApp(
      windowTitle: "Cancom VeraPrint", 
      titleBarWidgetBuilder: (ctx) => Placeholder(),
      appContentWidgetBuilder: (ctx) => Placeholder(), 
      themeModeNotifier: ValueNotifier(ThemeMode.light), 
      localeNotifier: ValueNotifier(Locale("ro")),
      darkTheme: Theme.of(context), 
      lightTheme: Theme.of(context),
      confirmOnClose: true,
      shutdownAction: () async {}, 
    );
  }
}
