import 'package:flutter/material.dart';

import 'data.dart';
import 'search_page.dart';
import 'style.dart';

void main() => runApp(const App());

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  final Future<AppData> _data = AppData.load();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '따릉이 공백률',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: navy, fontFamily: 'Pretendard'),
      home: FutureBuilder<AppData>(
        future: _data,
        builder: (context, snap) {
          if (snap.hasError) {
            return Scaffold(body: Center(child: Text('데이터를 불러오지 못했습니다: ${snap.error}')));
          }
          if (!snap.hasData) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          return SearchPage(data: snap.data!);
        },
      ),
    );
  }
}
