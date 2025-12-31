class ServiceItem {
  final String id;
  final String workItemId;
  final String name;
  final double amount;

  ServiceItem({
    required this.id,
    required this.workItemId,
    required this.name,
    required this.amount,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'workItemId': workItemId,
        'name': name,
        'amount': amount,
      };

  static ServiceItem fromMap(Map<String, dynamic> m) => ServiceItem(
        id: m['id'],
        workItemId: m['workItemId'],
        name: m['name'],
        amount: (m['amount'] ?? 0).toDouble(),
      );
}

class WorkItem {
  final String id;
  final String status; // active | completed
  final DateTime createdAt;

  final String customerName;
  final String phone;
  final String email;
  final String address;
  final String notes;

  final double total;

  final String? beforePhotoPath;
  final String? afterPhotoPath;

  WorkItem({
    required this.id,
    required this.status,
    required this.createdAt,
    required this.customerName,
    required this.phone,
    required this.email,
    required this.address,
    required this.notes,
    required this.total,
    this.beforePhotoPath,
    this.afterPhotoPath,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'status': status,
        'createdAt': createdAt.toIso8601String(),
        'customerName': customerName,
        'phone': phone,
        'email': email,
        'address': address,
        'notes': notes,
        'total': total,
        'beforePhotoPath': beforePhotoPath,
        'afterPhotoPath': afterPhotoPath,
      };

  static WorkItem fromMap(Map<String, dynamic> m) => WorkItem(
        id: m['id'],
        status: m['status'],
        createdAt: DateTime.parse(m['createdAt']),
        customerName: m['customerName'] ?? '',
        phone: m['phone'] ?? '',
        email: m['email'] ?? '',
        address: m['address'] ?? '',
        notes: m['notes'] ?? '',
        total: (m['total'] ?? 0).toDouble(),
        beforePhotoPath: m['beforePhotoPath'],
        afterPhotoPath: m['afterPhotoPath'],
      );
}

class TaskItem {
  final String id;
  final String title;
  final String customerName;
  final String phone;
  final String email;
  final String address;
  final DateTime createdAt;
  final DateTime scheduledAt; // when the task is scheduled for

  TaskItem({
    required this.id,
    required this.title,
    required this.customerName,
    required this.phone,
    required this.email,
    required this.address,
    required this.createdAt,
    required this.scheduledAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'customerName': customerName,
        'phone': phone,
        'email': email,
        'address': address,
        'createdAt': createdAt.toIso8601String(),
        'scheduledAt': scheduledAt.toIso8601String(),
      };

  static TaskItem fromMap(Map<String, dynamic> m) => TaskItem(
        id: m['id'],
        title: m['title'],
        customerName: m['customerName'],
        phone: m['phone'],
        email: m['email'],
        address: m['address'],
        createdAt: DateTime.parse(m['createdAt']),
        scheduledAt: m['scheduledAt'] != null ? DateTime.parse(m['scheduledAt']) : DateTime.parse(m['createdAt']),
      );
}
