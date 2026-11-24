import 'package:flutter/material.dart';
import 'store.dart';

class TabDef {
  final String id, label;
  final IconData icon;
  const TabDef(this.id, this.label, this.icon);
}

const allTabs = [
  TabDef('today', 'Today', Icons.check_circle_outline),
  TabDef('journal', 'Journal', Icons.edit_note),
  TabDef('connect', 'Connect', Icons.forum_outlined),
  TabDef('fitness', 'Fitness', Icons.fitness_center),
];

TabDef tabDef(String id) => allTabs.firstWhere((t) => t.id == id);

/// Which tabs are shown, in what order, and which one opens first.
class TabConfig {
  final List<String> order;
  final Set<String> off;
  final String start;
  TabConfig(this.order, this.off, this.start);

  List<String> get visible => order.where((i) => !off.contains(i)).toList();

  static TabConfig load(Store s) {
    final ids = allTabs.map((t) => t.id).toList();
    final order = <String>[for (final i in (s.getStringList('tab_order') ?? const <String>[])) if (ids.contains(i)) i];
    for (final i in ids) {
      if (!order.contains(i)) order.add(i);
    }
    final off = <String>{for (final i in (s.getStringList('tab_off') ?? const <String>[])) if (ids.contains(i)) i};
    if (off.length >= ids.length) off.clear();
    final vis = order.where((i) => !off.contains(i)).toList();
    var start = s.getString('tab_default') ?? vis.first;
    if (!vis.contains(start)) start = vis.first;
    return TabConfig(order, off, start);
  }

  Future<void> save(Store s) async {
    await s.setStringList('tab_order', order);
    await s.setStringList('tab_off', off.toList());
    await s.setString('tab_default', start);
  }
}

/// Switch tabs on or off, drag to reorder, and pick which one opens first.
class TabsEditor extends StatefulWidget {
  final Store prefs;
  final VoidCallback? onChanged;
  const TabsEditor({super.key, required this.prefs, this.onChanged});
  @override
  State<TabsEditor> createState() => _TabsEditorState();
}

class _TabsEditorState extends State<TabsEditor> {
  late TabConfig cfg = TabConfig.load(widget.prefs);

  Future<void> _save() async {
    final vis = cfg.visible;
    final c = TabConfig(cfg.order, cfg.off, vis.contains(cfg.start) ? cfg.start : vis.first);
    cfg = c;
    await c.save(widget.prefs);
    if (mounted) setState(() {});
    widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final vis = cfg.visible;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ReorderableListView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        buildDefaultDragHandles: false,
        onReorder: (o, n) {
          if (n > o) n -= 1;
          final id = cfg.order.removeAt(o);
          cfg.order.insert(n, id);
          _save();
        },
        children: [
          for (var i = 0; i < cfg.order.length; i++)
            ListTile(
              key: ValueKey(cfg.order[i]),
              contentPadding: EdgeInsets.zero,
              leading: Icon(tabDef(cfg.order[i]).icon),
              title: Text(tabDef(cfg.order[i]).label),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                Switch(
                  value: !cfg.off.contains(cfg.order[i]),
                  onChanged: (on) {
                    if (on) {
                      cfg.off.remove(cfg.order[i]);
                    } else {
                      if (vis.length <= 1) return; // keep at least one tab
                      cfg.off.add(cfg.order[i]);
                    }
                    _save();
                  },
                ),
                ReorderableDragStartListener(index: i, child: const Padding(padding: EdgeInsets.all(8), child: Icon(Icons.drag_handle))),
              ]),
            ),
        ],
      ),
      const SizedBox(height: 4),
      const Text('Hold and drag the handle to reorder. At least one tab stays on. Settings is always in the top-right menu.', style: TextStyle(fontSize: 12, color: Colors.grey)),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        decoration: const InputDecoration(labelText: 'Open the app on', border: OutlineInputBorder()),
        value: cfg.start,
        items: [for (final id in vis) DropdownMenuItem(value: id, child: Text(tabDef(id).label))],
        onChanged: (v) {
          if (v == null) return;
          cfg = TabConfig(cfg.order, cfg.off, v);
          _save();
        },
      ),
    ]);
  }
}
