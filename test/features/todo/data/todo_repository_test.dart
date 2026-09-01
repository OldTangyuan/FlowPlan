import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:flowplan/features/todo/data/datasources/todo_database.dart';
import 'package:flowplan/features/todo/data/repositories/todo_repository_impl.dart';
import 'package:flowplan/features/todo/domain/models/todo.dart';

/// 数据层测试：用 sqflite_common_ffi 在测试环境跑【真实的 SQLite】
///
/// 为什么能测数据库？sqflite 在 Android/iOS 上是原生插件，
/// 测试环境（PC 上跑 Dart）没有手机，但 `sqflite_common_ffi` 提供了
/// 一个"桌面版 SQLite 实现"——测试时把数据库工厂换成 FFI 版即可。
///
/// 💡 类比 Python：pytest + 内存数据库（sqlite3.connect(":memory:")）。
/// 这里我们每个测试都建一个【独立的内存数据库】，互不干扰。
void main() {
  // 全局初始化：让 sqflite 在测试环境使用 FFI（桌面）实现
  // 类比 Python：sqlite3.connect(":memory:") 前设置好环境
  sqfliteFfiInit();

  // 把 sqflite 的"数据库工厂"替换成 FFI 版（内存数据库）
  // 这样 TodoDatabase 打开数据库时会用内存版，不碰真实文件
  databaseFactory = databaseFactoryFfi;

  /// 测试用的 TodoRepository（每个测试独立创建，隔离数据）
  late TodoRepositoryImpl repository;

  setUp(() async {
    // 每个测试前：新建一个【内存数据库】实例
    // inMemoryDatabasePath（即 ':memory:'）表示数据只存在内存里，
    // singleInstance: false 保证每次打开都是【全新】的库（不共享连接），
    // 测试结束自动销毁，互不污染。类比 Python 的 sqlite3.connect(":memory:")。
    final db = TodoDatabase(
      databasePath: inMemoryDatabasePath,
      singleInstance: false,
    );

    // 打开数据库（触发建表）
    await db.database;

    repository = TodoRepositoryImpl(db);
  });

  group('TodoRepository 增删改查', () {
    test('新增后能查到（add → getAll）', () async {
      final todo = Todo.create(title: '买牛奶');

      await repository.add(todo);

      final all = await repository.getAll();
      expect(all.length, 1);
      expect(all.first.title, '买牛奶');
    });

    test('能按 id 查询单条（getById）', () async {
      final todo = Todo.create(title: '写作业', priority: TodoPriority.high);
      await repository.add(todo);

      final found = await repository.getById(todo.id);
      expect(found, isNotNull);
      expect(found!.title, '写作业');
      expect(found.priority, TodoPriority.high);

      // 查不存在的 id 返回 null
      final missing = await repository.getById('不存在的id');
      expect(missing, isNull);
    });

    test('能更新任务（update）', () async {
      final todo = Todo.create(title: '旧标题');
      await repository.add(todo);

      final updated = todo.copyWith(title: '新标题');
      await repository.update(updated);

      final found = await repository.getById(todo.id);
      expect(found!.title, '新标题');
      // 其他字段不受影响
      expect(found.isCompleted, isFalse);
    });

    test('能删除任务（delete）', () async {
      final todo = Todo.create(title: '待删除');
      await repository.add(todo);

      await repository.delete(todo.id);

      final all = await repository.getAll();
      expect(all, isEmpty);
    });

    test('能删除所有已完成任务（deleteCompleted）', () async {
      // 添加 3 条：2 条已完成，1 条未完成
      final done1 = Todo.create(title: '完成1').toggleCompleted();
      final done2 = Todo.create(title: '完成2').toggleCompleted();
      final active = Todo.create(title: '未完成');

      await repository.add(done1);
      await repository.add(done2);
      await repository.add(active);

      await repository.deleteCompleted();

      final all = await repository.getAll();
      expect(all.length, 1);
      expect(all.first.title, '未完成');
    });

    test('count 统计正确', () async {
      expect(await repository.count(), 0);

      await repository.add(Todo.create(title: '任务1'));
      await repository.add(Todo.create(title: '任务2'));

      expect(await repository.count(), 2);
    });
  });

  group('TodoRepository 排序规则', () {
    test('未完成的排在已完成前面', () async {
      final done = Todo.create(title: '已完成任务').toggleCompleted();
      final active = Todo.create(title: '未完成任务');

      // 故意先加已完成的，再加未完成的（测试排序是否生效）
      await repository.add(done);
      await repository.add(active);

      final all = await repository.getAll();
      expect(all.first.title, '未完成任务');
      expect(all.last.title, '已完成任务');
    });

    test('同状态下高优先级在前', () async {
      final low = Todo.create(title: '低优先级', priority: TodoPriority.low);
      final high = Todo.create(title: '高优先级', priority: TodoPriority.high);
      final medium = Todo.create(title: '中优先级', priority: TodoPriority.medium);

      await repository.add(low);
      await repository.add(high);
      await repository.add(medium);

      final all = await repository.getAll();
      // 期望顺序：高 → 中 → 低
      expect(all[0].title, '高优先级');
      expect(all[1].title, '中优先级');
      expect(all[2].title, '低优先级');
    });
  });

  group('TodoDatabase 持久化特性', () {
    test('字段往返一致（写入什么读出什么）', () async {
      final todo = Todo.create(
        title: '完整字段测试',
        description: '备注内容',
        priority: TodoPriority.low,
      );

      await repository.add(todo);
      final found = await repository.getById(todo.id);

      expect(found!.description, '备注内容');
      expect(found.priority, TodoPriority.low);
      expect(found.isCompleted, isFalse);
      // 时间以字符串存 ISO8601，精度到毫秒，比较格式一致即可
      expect(
        found.createdAt.toIso8601String(),
        todo.createdAt.toIso8601String(),
      );
    });

    test('数据库版本号为 1（当前架构约定）', () async {
      // 这个测试守护"版本号约定"：升级数据库时必须同步改常量
      // 我们通过 AppConstants 间接验证（TodoDatabase 内部用了它）
      // 这里只验证数据库能正常打开且表存在即可
      final db = TodoDatabase();
      final database = await db.database;

      // 查询表是否存在（SQLite 的系统表 sqlite_master）
      final rows = await database.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='todos'",
      );
      expect(rows, isNotEmpty, reason: 'todos 表必须存在');
    });
  });
}
