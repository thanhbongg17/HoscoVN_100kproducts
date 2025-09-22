import 'package:flutter/material.dart';
import 'task3/task3_demo_page.dart';

void main() => runApp(const Task3App());

class Task3App extends StatelessWidget {
  const Task3App({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Task3 Demo',
      theme: ThemeData(useMaterial3: true),
      home: const Task3DemoPage(), // màn bạn vừa tạo
    );
  }
}
