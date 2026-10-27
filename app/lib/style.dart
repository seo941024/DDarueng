// 색·공통 위젯: 조치별 색은 장표·Power BI와 동일
import 'package:flutter/material.dart';

const navy = Color(0xFF1E3A5F);
const gray = Color(0xFF6C757D);
const lightGray = Color(0xFFADB5BD);
const line = Color(0xFFDEE2E6);
const panel = Color(0xFFF5F7FA);
const ink = Color(0xFF212529);
const barIdle = Color(0xFFC5CEDB);

String n1(double? v) => v == null ? '-' : v.toStringAsFixed(1);

String comma(num v) {
  final s = v.round().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0 && s[i - 1] != '-') b.write(',');
    b.write(s[i]);
  }
  return b.toString();
}

/// 화면 제목 + 설명 한 줄
class PageHeader extends StatelessWidget {
  final String title;
  final String sub;
  final Widget? leading;
  const PageHeader(this.title, this.sub, {super.key, this.leading});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(32, 26, 32, 14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          if (leading != null) ...[leading!, const SizedBox(width: 8)],
          Flexible(
            child: Text(title,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: navy)),
          ),
          const SizedBox(width: 14),
          Flexible(child: Text(sub, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: gray))),
        ]),
      );
}

/// 구역 소제목
class SectionTitle extends StatelessWidget {
  final String text;
  final String? note;
  const SectionTitle(this.text, {super.key, this.note});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: navy)),
          if (note != null) ...[
            const SizedBox(width: 10),
            Flexible(child: Text(note!, style: const TextStyle(fontSize: 12, color: gray))),
          ],
        ]),
      );
}

/// 조치 이름 표시: 색 점 + 이름
class ActionBadge extends StatelessWidget {
  final String label;
  final Color color;
  final double size;
  const ActionBadge(this.label, this.color, {super.key, this.size = 13});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: size, fontWeight: FontWeight.w600, color: ink)),
        ]),
      );
}

/// 흰 바탕 테두리 상자, accent 지정 시 왼쪽 색 띠
class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color? accent;
  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(20), this.accent});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: line),
        ),
        clipBehavior: Clip.antiAlias,
        child: accent == null
            ? Padding(padding: padding, child: child)
            : IntrinsicHeight(
                child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Container(width: 6, color: accent),
                  Expanded(child: Padding(padding: padding, child: child)),
                ]),
              ),
      );
}

/// 표 한 줄: 열 너비 비율 지정
class TableRowCells extends StatelessWidget {
  final List<Widget> cells;
  final List<int> flex;
  final bool head;
  const TableRowCells(this.cells, this.flex, {super.key, this.head = false});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          color: head ? panel : null,
          border: Border(bottom: BorderSide(color: head ? navy.withValues(alpha: 0.4) : line)),
        ),
        child: Row(children: [
          for (var i = 0; i < cells.length; i++)
            Expanded(flex: flex[i], child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: cells[i])),
        ]),
      );
}

Text headText(String s, {bool active = false, TextAlign align = TextAlign.left, int lines = 1}) => Text(
      s,
      textAlign: align,
      maxLines: lines,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: active ? navy : gray),
    );

Text cellText(String s, {bool bold = false, TextAlign align = TextAlign.left, Color color = ink}) => Text(
      s,
      textAlign: align,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: 13.5, fontWeight: bold ? FontWeight.bold : FontWeight.normal, color: color),
    );

/// 선택 상자: 자치구·조치·정렬 공통
class Picker<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<(T, String)> items;
  final ValueChanged<T> onChanged;
  const Picker(this.label, this.value, this.items, this.onChanged, {super.key});

  @override
  Widget build(BuildContext context) => Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: line),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label, style: const TextStyle(fontSize: 12.5, color: gray)),
          const SizedBox(width: 10),
          DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              style: const TextStyle(fontSize: 13.5, color: ink, fontFamily: 'Pretendard'),
              items: [for (final (v, t) in items) DropdownMenuItem(value: v, child: Text(t))],
              onChanged: (v) => v == null ? null : onChanged(v),
            ),
          ),
        ]),
      );
}

/// 검색 입력 칸
class SearchBox extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onChanged;
  const SearchBox(this.hint, this.onChanged, {super.key});

  @override
  Widget build(BuildContext context) => Container(
        height: 42,
        constraints: const BoxConstraints(maxWidth: 300, minWidth: 180),
        child: TextField(
          onChanged: onChanged,
          style: const TextStyle(fontSize: 13.5),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 13.5, color: lightGray),
            prefixIcon: const Icon(Icons.search, size: 20, color: gray),
            filled: true,
            fillColor: Colors.white,
            contentPadding: EdgeInsets.zero,
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: line)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: navy)),
          ),
        ),
      );
}
