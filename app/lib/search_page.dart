// 대여소 검색: 검색어 없으면 지금 시간 공백률 높은 대여소
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import 'data.dart';
import 'detail_page.dart';
import 'style.dart';

class SearchPage extends StatefulWidget {
  final AppData data;
  const SearchPage({super.key, required this.data});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  String _query = '';
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // 화면을 켜 둔 동안 시간대가 바뀌면 현재 시각 기준으로 다시 계산
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final day = DayType.of(now);
    final hour = now.hour;
    final searching = _query.trim().isNotEmpty;
    final results = searching ? widget.data.search(_query) : widget.data.emptiest(day, hour);

    return Scaffold(
      appBar: AppBar(title: const Text('따릉이 공백률')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: '대여소 이름·번호 또는 자치구',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                searching ? '검색 결과 ${results.length}곳' : '${day.label} $hour시 공백률 높은 대여소',
                style: const TextStyle(fontWeight: FontWeight.bold, color: navy),
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: min(results.length, 100),
              separatorBuilder: (context, i) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final s = results[i];
                return ListTile(
                  title: Text(s.name),
                  subtitle: Text(s.gu),
                  trailing: RateText(widget.data.rateAt(s.id, day, hour)),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => DetailPage(data: widget.data, station: s)),
                  ),
                );
              },
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              '서울시 공공자전거 대여가능 수량 2025년 기록 기준\n공백률: 같은 요일 구분·시간대 기록 중 자전거 0대 비율',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: gray),
            ),
          ),
        ],
      ),
    );
  }
}
