import 'package:flutter/material.dart';
import 'create.dart';
import 'work_items.dart';
import 'tasks.dart';
import 'theme.dart';
import 'storage.dart';

/// args example:
/// Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false,
///   arguments: {'tab': 1, 'workTab': 'completed'}
/// );
class HomeShell extends StatefulWidget {
  final int initialTab;
  final String? workTab; // 'active' or 'completed'

  const HomeShell({
    super.key,
    this.initialTab = 0,
    this.workTab,
  });

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late int index;
  // TODO: Replace these with real values from DB/ state management
  int pendingTasksCount = 0;
  int activeWorkItemsCount = 0;

  @override
  void initState() {
    super.initState();
    index = widget.initialTab;
    _loadCounts();
  }

  Future<void> _loadCounts() async {
    await AppDb.instance.seedTasksIfEmpty();
    final tasks = await AppDb.instance.listTasks();
    final work = await AppDb.instance.listWorkItemsByStatus('active');
    final today = DateTime.now();
    bool isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
    if (!mounted) return;
    setState(() {
      pendingTasksCount = tasks.where((t) => isSameDay(t.scheduledAt, today)).length;
      activeWorkItemsCount = work.length;
    });
  }
 // Floating action Button FAB per TAB 
 Widget? _buildFab(){
  // if(index==1){
  //   // Work Items Tab
  //   return FloatingActionButton(
  //     heroTag: null,
  //     onPressed: (){
  //       //TODO : navigate to add work item screen
  //       // do nothing for now
  //     },
  //     child: const Icon(Icons.add),
  //   );
  // } 
 if (index == 2) {
  return FloatingActionButton(
    heroTag: null,
    onPressed: () async {
      final created = await Navigator.pushNamed(context, '/task_create');
      // created == true means task saved → refresh UI
      if (created == true && mounted) setState(() {});
    },
    child: const Icon(Icons.add_task),
  );
}

return null;  
  }

// ----badge widget for bottom nav bar items
 Widget _badgeIcon({required IconData icon, required int count}){
  if(count <=0)
    return Icon(icon);

    return Stack(clipBehavior: Clip.none, children: [
      Icon(icon),
      Positioned(
        right: -6,
        top: -6,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(12),
          ),
          constraints: const BoxConstraints(
            minWidth: 18,
            minHeight: 16,
          ),
          child: Text(
            count>99 ? '99+' : '$count',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold
            
          ),
          ),
        ),
      ),
    ],
    );
  }
  

  @override
  Widget build(BuildContext context) {
    final pages = [
      const CreateWorkItemPage(),
      WorkItemsPage(initialTab: widget.workTab),
      const TasksPage(),
    ];
      return PopScope<Object>(
        canPop: index == 0, // only allow "exit/back" if already on first tab
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return; // already popped
          if (index != 0) {
            setState(() => index = 0); // go to first tab
          }
        },
        child: Scaffold(
    
      body: IndexedStack(index: index, children: pages
      ),
      floatingActionButton: _buildFab(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: index,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: Colors.grey,
        onTap: (i) => setState(() => index = i),
        items:  [
          const BottomNavigationBarItem(icon: Icon(Icons.add), label: "Create"), 
          BottomNavigationBarItem(icon: _badgeIcon(icon: Icons.description_outlined, count: activeWorkItemsCount,),
          //example)
           label: "Work Items",),
          BottomNavigationBarItem(icon: _badgeIcon(icon: Icons.check_box_outlined, count: pendingTasksCount,), label: "Tasks"
          ),
        ],
      ),    
      ),
      );

  }
}
 
