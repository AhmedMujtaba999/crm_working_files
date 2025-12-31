import 'package:flutter/material.dart';
import 'storage.dart';
import 'models.dart';
import 'widgets.dart';
import 'theme.dart';

class WorkItemsPage extends StatefulWidget {
  final String? initialTab; // 'active' or 'completed'
  const WorkItemsPage({super.key, this.initialTab});

  @override
  State<WorkItemsPage> createState() => _WorkItemsPageState();
}

class _WorkItemsPageState extends State<WorkItemsPage> {
  bool activeSelected = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialTab == 'completed') activeSelected = false;
    if (widget.initialTab == 'active') activeSelected = true;
  }

  Future<List<WorkItem>> _load() async {
    final status = activeSelected ? 'active' : 'completed';
    return AppDb.instance.listWorkItemsByStatus(status);
  }

  Future<void> _openInvoice(WorkItem it) async {
    // Open invoice screen
    await Navigator.pushNamed(context, '/invoice', arguments: it.id);

    // When user returns, refresh list (maybe status changed to completed)
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          GradientHeader(
            title: "Work Items",
            child: PillSwitch(
              leftSelected: activeSelected,
              leftText: "Active",
              rightText: "Completed",
              onLeft: () => setState(() => activeSelected = true),
              onRight: () => setState(() => activeSelected = false),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<WorkItem>>(
              future: _load(),
              builder: (context, snap) {
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());

                final list = snap.data!;
                if (list.isEmpty) {
                  return EmptyState(
                    text: activeSelected ? "No active work items" : "No completed work items",
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    setState(() {});
                    await Future.delayed(const Duration(milliseconds: 200));
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => _workCard(list[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _workCard(WorkItem it) {
    return InkWell(
      onTap: () => _openInvoice(it),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(color: Color(0x11000000), blurRadius: 12, offset: Offset(0, 6)),
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  it.customerName,
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: activeSelected ? AppColors.primary.withOpacity(0.10) : Colors.green.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(
                      activeSelected ? Icons.timelapse : Icons.check_circle,
                      size: 16,
                      color: activeSelected ? AppColors.primary : Colors.green.shade700,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      activeSelected ? "Active" : "Completed",
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: activeSelected ? AppColors.primary : Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (it.phone.trim().isNotEmpty) Text(it.phone, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Total",
                style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w700),
              ),
              Text(
                "\$${it.total.toStringAsFixed(2)}",
                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ]),
      ),
    );
  }
}
