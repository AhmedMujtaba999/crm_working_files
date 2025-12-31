import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'models.dart';

class AppDb {
  AppDb._();
  static final instance = AppDb._();

  Database? _db;

  Database get db {
    if (_db == null) throw Exception('DB not initialized');
    return _db!;
  }

  Future<void> init() async {
    final path = join(await getDatabasesPath(), 'poolpro_crm.db');
    _db = await openDatabase(
      path,
      version: 2,
      onCreate: (db, _) async {
        await _createTables(db);
      },
      onUpgrade: (db, oldV, newV) async {
        // Simple reset upgrade for dev phase
        await db.execute('DROP TABLE IF EXISTS work_items');
        await db.execute('DROP TABLE IF EXISTS services');
        await db.execute('DROP TABLE IF EXISTS tasks');
        await _createTables(db);
      },
    );
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE work_items (
        id TEXT PRIMARY KEY,
        status TEXT,
        createdAt TEXT,
        customerName TEXT,
        phone TEXT,
        email TEXT,
        address TEXT,
        notes TEXT,
        total REAL,
        beforePhotoPath TEXT,
        afterPhotoPath TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE services (
        id TEXT PRIMARY KEY,
        workItemId TEXT,
        name TEXT,
        amount REAL
      )
    ''');

    await db.execute('''
      CREATE TABLE tasks (
        id TEXT PRIMARY KEY,
        title TEXT,
        customerName TEXT,
        phone TEXT,
        email TEXT,
        address TEXT,
        createdAt TEXT,
        scheduledAt TEXT
      )
    ''');
  }

  // ---------------- Customer exists check ----------------
  Future<bool> customerExists({required String phone, required String email}) async {
    final rows = await db.query(
      'work_items',
      columns: ['id'],
      where: '(phone = ? AND phone != "") OR (email = ? AND email != "")',
      whereArgs: [phone, email],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  /// If a customer already exists, check if there's an active work item for them.
  /// Returns the work item id if found, otherwise null.
  Future<String?> findLatestActiveWorkItemId({required String phone, required String email}) async {
    final rows = await db.query(
      'work_items',
      columns: ['id'],
      where: 'status = ? AND ((phone = ? AND phone != "") OR (email = ? AND email != ""))',
      whereArgs: ['active', phone, email],
      orderBy: 'createdAt DESC',
      limit: 1,
    );

    if (rows.isEmpty) return null;
    return rows.first['id'] as String?;
  }

  /// Returns the most recent work item for the given customer (by phone or email), or null if none.
  Future<WorkItem?> findLatestWorkItemByCustomer({required String phone, required String email}) async {
    final rows = await db.query(
      'work_items',
      where: '((phone = ? AND phone != "") OR (email = ? AND email != ""))',
      whereArgs: [phone, email],
      orderBy: 'createdAt DESC',
      limit: 1,
    );

    if (rows.isEmpty) return null;
    return WorkItem.fromMap(rows.first);
  }

  // ---------------- Work Items ----------------
  Future<void> insertWorkItem(WorkItem item, List<ServiceItem> services) async {
    final d = db;

    await d.insert('work_items', item.toMap());
    for (final s in services) {
      await d.insert('services', s.toMap());
    }

    // TODO BACKEND (Node.js):
    // POST /work-items  (item + services)
  }

  Future<List<WorkItem>> listWorkItemsByStatus(String status) async {
    final rows = await db.query(
      'work_items',
      where: 'status = ?',
      whereArgs: [status],
      orderBy: 'createdAt DESC', // ✅ latest first
    );
    return rows.map(WorkItem.fromMap).toList();
  }

  Future<WorkItem?> getWorkItem(String id) async {
    final rows = await db.query('work_items', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return WorkItem.fromMap(rows.first);
  }

  Future<List<ServiceItem>> listServices(String workItemId) async {
    final rows = await db.query('services', where: 'workItemId = ?', whereArgs: [workItemId]);
    return rows.map(ServiceItem.fromMap).toList();
  }

  Future<void> markCompleted(String workItemId) async {
    await db.update('work_items', {'status': 'completed'}, where: 'id = ?', whereArgs: [workItemId]);

    // TODO BACKEND (Node.js):
    // PATCH /work-items/:id {status:"completed"}
  }

  Future<void> updatePhotos({
    required String workItemId,
    String? beforePath,
    String? afterPath,
  }) async {
    final data = <String, dynamic>{};
    if (beforePath != null) data['beforePhotoPath'] = beforePath;
    if (afterPath != null) data['afterPhotoPath'] = afterPath;

    await db.update('work_items', data, where: 'id = ?', whereArgs: [workItemId]);

    // TODO BACKEND (Node.js):
    // POST /work-items/:id/photos
  }

  // ---------------- Tasks ----------------
  Future<void> seedTasksIfEmpty() async {
    final c = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM tasks')) ?? 0;
    if (c > 0) return;

    final now = DateTime.now();

    final t1 = TaskItem(
      id: 't1',
      title: 'Pool Maintenance - Ahmed',
      customerName: 'Ahmed Hassan',
      phone: '9876543210',
      email: 'ahmed@email.com',
      address: '123 Main Street, Dubai',
      createdAt: DateTime(2024, 1, 15),
      scheduledAt: DateTime(now.year, now.month, now.day), // one task scheduled for today
    );

    final t2 = TaskItem(
      id: 't2',
      title: 'Filter Service - Sameer',
      customerName: 'Sameer Khan',
      phone: '9123456780',
      email: 'sameer@email.com',
      address: '456 Beach Road, Abu Dhabi',
      createdAt: DateTime(2024, 1, 16),
      scheduledAt: DateTime(2024, 1, 16),
    );

    await db.insert('tasks', t1.toMap());
    await db.insert('tasks', t2.toMap());
  }

  Future<List<TaskItem>> listTasks({DateTime? forDate}) async {
    final rows = await db.query('tasks', orderBy: 'createdAt DESC');
    var list = rows.map(TaskItem.fromMap).toList();

    bool isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

    if (forDate != null) {
      final fd = DateTime(forDate.year, forDate.month, forDate.day);
      return list.where((t) => isSameDay(t.scheduledAt, fd)).toList();
    }

    // default: sort so that tasks scheduled for today appear first
    final today = DateTime.now();
    list.sort((a, b) {
      final aToday = isSameDay(a.scheduledAt, today);
      final bToday = isSameDay(b.scheduledAt, today);
      if (aToday && !bToday) return -1;
      if (bToday && !aToday) return 1;
      // otherwise sort by scheduledAt desc then createdAt desc
      final cmp = b.scheduledAt.compareTo(a.scheduledAt);
      if (cmp != 0) return cmp;
      return b.createdAt.compareTo(a.createdAt);
    });

    return list;
  }

  Future<void> insertTask(TaskItem task) async {
    await db.insert('tasks', task.toMap());
  }

  Future<void> deleteTask(String id) async {
    await db.delete('tasks', where: 'id = ?', whereArgs: [id]);

    // TODO BACKEND (Node.js):
    // DELETE /tasks/:id
  }
}
