import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:flowplan/features/todo/application/todo_controller.dart';
import 'package:flowplan/features/todo/data/datasources/todo_database.dart';
import 'package:flowplan/features/todo/data/repositories/todo_repository_impl.dart';
import 'package:flowplan/features/todo/domain/models/todo.dart';

/// 应用层测试：验证 Controller 的业务逻辑
///
/// 测试思路：
/// - 用一个"内存版 SQLite"作为真实数据源（sqflite_common_ffi）
/// - 通过 Riverpod 的 ProviderContainer 手动创建 Controller
///   （不启动整个 App，只测 Controller 这一层）
///
/// 💡 类比 Python：pytest 里直接测 service 层，不启动 Web 服务。
void main() {
  // 初始化 FFI 数据库（同数据层测试）
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  // Riverpod 的"测试容器"：手动管理 Provider 的创建与销毁
  late ProviderContainer container;

  setUp(() async {
    // 每个测试独立的内存数据库（互不污染）
    // 注意：这里通过 Provider override 注入"测试专用仓库"，
    // 避免使用 App 默认的磁盘数据库。
    final db = TodoDatabase(
      databasePath: inMemoryDatabasePath,
      singleInstance: false, // 每次打开全新连接，测试之间数据隔离
    );
    await db.database;

    // 创建 Provider 容器（等价于 App 里的 ProviderScope）
    container = ProviderContainer(overrides: [
      // 覆盖"仓库 Provider"：用测试的内存仓库替代默认实现
      // 这就是依赖注入的好处：换实现，不动 Controller 代码
      todoRepositoryProvider.overrideWithValue(TodoRepositoryImpl(db)),
    ]);
    addTearDown(container.dispose);
  });

  /// 从容器里取控制器
  TodoController controller() => container.read(todoControllerProvider.notifier);

  /// 等待异步操作完成（Riverpod 的异步状态需要 pump 一下）
  Future<void> pump() async {
    // 让所有 pending 的异步任务执行完
    await Future<void>.delayed(Duration.zero);
    // 额外多等几轮（数据库操作可能分多个微任务）
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }

  group('TodoController 业务逻辑', () {
    test('初始状态是加载中', () {
      final state = container.read(todoControllerProvider);
      expect(state.isLoading, isTrue);
      expect(state.todos, isEmpty);
    });

    test('加载后拿到空列表（首次打开）', () async {
      // 触发首次加载（Provider 创建时自动调用 loadTodos）
      container.read(todoControllerProvider);
      await pump();

      final state = container.read(todoControllerProvider);
      expect(state.isLoading, isFalse);
      expect(state.todos, isEmpty);
      expect(state.error, isNull);
    });

    test('添加任务后列表出现该任务', () async {
      container.read(todoControllerProvider);
      await pump();

      final c = controller();
      await c.addTodo(title: '买牛奶', priority: TodoPriority.high);
      await pump();

      final state = container.read(todoControllerProvider);
      expect(state.todos.length, 1);
      expect(state.todos.first.title, '买牛奶');
      expect(state.todos.first.priority, TodoPriority.high);
    });

    test('切换完成状态（toggle）', () async {
      container.read(todoControllerProvider);
      await pump();

      final c = controller();
      await c.addTodo(title: '写作业');
      await pump();

      final id = container.read(todoControllerProvider).todos.first.id;

      // 切换为完成
      await c.toggleTodo(id);
      await pump();
      expect(
        container.read(todoControllerProvider).todos.first.isCompleted,
        isTrue,
      );

      // 再切换回未完成
      await c.toggleTodo(id);
      await pump();
      expect(
        container.read(todoControllerProvider).todos.first.isCompleted,
        isFalse,
      );
    });

    test('删除任务', () async {
      container.read(todoControllerProvider);
      await pump();

      final c = controller();
      await c.addTodo(title: '待删除');
      await pump();

      final id = container.read(todoControllerProvider).todos.first.id;
      await c.deleteTodo(id);
      await pump();

      expect(container.read(todoControllerProvider).todos, isEmpty);
    });

    test('编辑任务（update）', () async {
      container.read(todoControllerProvider);
      await pump();

      final c = controller();
      await c.addTodo(title: '旧标题');
      await pump();

      final todo = container.read(todoControllerProvider).todos.first;
      await c.updateTodo(todo.copyWith(title: '新标题'));
      await pump();

      expect(
        container.read(todoControllerProvider).todos.first.title,
        '新标题',
      );
    });

    test('清空已完成任务（clearCompleted）', () async {
      container.read(todoControllerProvider);
      await pump();

      final c = controller();
      await c.addTodo(title: '任务A');
      await c.addTodo(title: '任务B');
      await pump();

      // 把任务A标记为完成（注意：列表按创建时间倒序，first 是"任务B"，
      // 所以按标题精确查找任务A，不能依赖列表顺序）
      final todoA = container
          .read(todoControllerProvider)
          .todos
          .firstWhere((t) => t.title == '任务A');
      await c.toggleTodo(todoA.id);
      await pump();

      await c.clearCompleted();
      await pump();

      final todos = container.read(todoControllerProvider).todos;
      expect(todos.length, 1);
      expect(todos.first.title, '任务B');
    });

    test('统计信息正确（totalCount / completedCount）', () async {
      container.read(todoControllerProvider);
      await pump();

      final c = controller();
      await c.addTodo(title: '任务A');
      await c.addTodo(title: '任务B');
      await c.addTodo(title: '任务C');
      await pump();

      // 完成任务A（按标题查找，不依赖列表顺序）
      final todoA = container
          .read(todoControllerProvider)
          .todos
          .firstWhere((t) => t.title == '任务A');
      await c.toggleTodo(todoA.id);
      await pump();

      final state = container.read(todoControllerProvider);
      expect(state.totalCount, 3);
      expect(state.completedCount, 1);
    });
  });

  group('TodoController 筛选逻辑', () {
    test('filteredTodos 按筛选条件过滤', () async {
      container.read(todoControllerProvider);
      await pump();

      final c = controller();
      await c.addTodo(title: '未完成1');
      await c.addTodo(title: '未完成2');
      await pump();

      // 完成任务"未完成1"（列表按创建时间倒序，先加的在后面）
      // 为稳妥：找到标题为"未完成1"的任务
      final todo1 = container
          .read(todoControllerProvider)
          .todos
          .firstWhere((t) => t.title == '未完成1');
      await c.toggleTodo(todo1.id);
      await pump();

      // 全部
      c.setFilter(TodoFilter.all);
      expect(c.filteredTodos.length, 2);

      // 未完成
      c.setFilter(TodoFilter.active);
      expect(c.filteredTodos.length, 1);
      expect(c.filteredTodos.first.title, '未完成2');

      // 已完成
      c.setFilter(TodoFilter.completed);
      expect(c.filteredTodos.length, 1);
      expect(c.filteredTodos.first.title, '未完成1');
    });
  });
}
