import 'package:flutter/material.dart';

import 'data.dart';
import 'diagnosis.dart';
import 'shell.dart';
import 'style.dart';

void main() => runApp(const App());

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  final Future<(AppData, DiagnosisData)> _data = (AppData.load(), DiagnosisData.load()).wait;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '서울 공공자전거 사용 분석 프로그램',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: navy, fontFamily: 'Pretendard'),
      home: FutureBuilder<(AppData, DiagnosisData)>(
        future: _data,
        builder: (context, snap) {
          if (snap.hasError) {
            return Scaffold(body: Center(child: Text('데이터 불러오기 실패: ${snap.error}')));
          }
          if (!snap.hasData) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          final (data, diag) = snap.data!;
          return Shell(data: data, diag: diag);
        },
      ),
    );
  }
}
