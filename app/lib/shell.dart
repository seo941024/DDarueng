// 데스크톱 화면 틀: 왼쪽 메뉴 · 오른쪽 기능 화면, 대여소 선택 시 상세 화면
import 'package:flutter/material.dart';

import 'analysis_page.dart';
import 'data.dart';
import 'diagnosis.dart';
import 'overview_page.dart';
import 'recommend_page.dart';
import 'station_detail.dart';
import 'station_list_page.dart';
import 'style.dart';

enum Menu {
  overview('현황', Icons.space_dashboard_outlined),
  analysis('분석', Icons.map_outlined),
  recommend('조치 추천', Icons.assignment_outlined),
  stations('대여소 조회', Icons.search);

  final String label;
  final IconData icon;
  const Menu(this.label, this.icon);
}

class Shell extends StatefulWidget {
  final AppData data;
  final DiagnosisData diag;
  const Shell({super.key, required this.data, required this.diag});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  Menu menu = Menu.overview;
  Act recommendAct = Act.expand;
  Act? stationsAct;
  final List<Diagnosis> _history = []; // 상세 화면 이동 기록: 뒤로 가기용

  void openMenu(Menu m) => setState(() {
        menu = m;
        _history.clear();
      });

  void openAct(Act a) => setState(() {
        _history.clear();
        if (a == Act.keep) {
          menu = Menu.stations;
          stationsAct = a;
        } else {
          menu = Menu.recommend;
          recommendAct = a;
        }
      });

  void openStation(Diagnosis d) => setState(() => _history.add(d));

  void back() => setState(() => _history.removeLast());

  @override
  Widget build(BuildContext context) {
    final diag = widget.diag;
    final Widget body = _history.isNotEmpty
        ? StationDetail(
            key: ValueKey(_history.last.id),
            d: _history.last,
            diag: diag,
            data: widget.data,
            backLabel: _history.length > 1 ? '${_history[_history.length - 2].name} 상세' : '${menu.label} 목록',
            onBack: back,
            onOpen: openStation,
          )
        : switch (menu) {
            Menu.overview => OverviewPage(diag: diag, onAct: openAct),
            Menu.analysis => AnalysisPage(diag: diag, onOpen: openStation),
            Menu.recommend => RecommendPage(
                key: ValueKey(recommendAct),
                diag: diag,
                act: recommendAct,
                onAct: (a) => setState(() => recommendAct = a),
                onOpen: openStation,
              ),
            Menu.stations => StationListPage(
                key: ValueKey(stationsAct),
                diag: diag,
                initialAct: stationsAct,
                onOpen: openStation,
              ),
          };
    return Scaffold(
      backgroundColor: panel,
      body: Row(children: [
        _SideMenu(current: menu, period: diag.period, onSelect: openMenu),
        Expanded(child: body),
      ]),
    );
  }
}

class _SideMenu extends StatelessWidget {
  final Menu current;
  final List<String> period;
  final ValueChanged<Menu> onSelect;
  const _SideMenu({required this.current, required this.period, required this.onSelect});

  @override
  Widget build(BuildContext context) => Container(
        width: 230,
        color: navy,
        padding: const EdgeInsets.fromLTRB(16, 28, 16, 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(
            padding: EdgeInsets.only(left: 8),
            child: Text('서울 공공자전거\n사용 분석 프로그램',
                style: TextStyle(fontSize: 18, height: 1.35, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
          const Padding(
            padding: EdgeInsets.only(left: 8, top: 4, bottom: 28),
            child: Text('대여 기록·대여 가능 수량 분석 기반 대여소별 조치 추천', style: TextStyle(fontSize: 12, height: 1.45, color: Color(0xFFB8C4D6))),
          ),
          for (final m in Menu.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Material(
                color: m == current ? Colors.white.withValues(alpha: 0.14) : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => onSelect(m),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    child: Row(children: [
                      Icon(m.icon, size: 20, color: Colors.white),
                      const SizedBox(width: 12),
                      Text(m.label,
                          style: TextStyle(
                              fontSize: 15,
                              color: Colors.white,
                              fontWeight: m == current ? FontWeight.bold : FontWeight.normal)),
                    ]),
                  ),
                ),
              ),
            ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Text('분석 기간\n${period[0]} ~ ${period[1]}',
                style: const TextStyle(fontSize: 12, height: 1.6, color: Color(0xFFB8C4D6))),
          ),
        ]),
      );
}
