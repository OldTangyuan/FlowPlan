import 'package:flutter_test/flutter_test.dart';
import 'package:flowplan/features/todo/domain/models/todo.dart';

/// Todo 模型单元测试
///
/// 测试是真实项目的"安全网"：改了代码后跑一遍测试，
/// 如果全绿说明没改坏东西。
///
/// 💡 **和 Python 的类比**：
/// ```python
/// # pytest 风格
/// def test_todo_create():
///     todo = Todo.create(title="买牛奶")
///     assert todo.title == "买牛奶"
///     assert todo.is_completed == False
/// ```
///
/// Dart 用 `test()` + `expect(实际值, 期望值)`，和 pytest 的 assert 类似。
void main() {
  group('Todo.create（创建任务）', () {
    test('新任务自动生成 id 和时间戳', () {
      final todo = Todo.create(title: '买牛奶');

      // id 是 UUID 字符串，非空
      expect(todo.id, isNotEmpty);
      // 默认未完成
      expect(todo.isCompleted, isFalse);
      // 默认优先级是中
      expect(todo.priority, TodoPriority.medium);
      // 默认备注为空
      expect(todo.description, isEmpty);
      // 创建时间已生成
      expect(todo.createdAt, isNotNull);
      expect(todo.updatedAt, isNotNull);
    });

    test('可以指定优先级和备注', () {
      final todo = Todo.create(
        title: '写代码',
        description: '完成 TODO 功能',
        priority: TodoPriority.high,
      );

      expect(todo.priority, TodoPriority.high);
      expect(todo.description, '完成 TODO 功能');
    });
  });

  group('Todo.copyWith（复制修改）', () {
    test('只修改指定字段，其余不变', () {
      final todo = Todo.create(title: '原始标题');
      final updated = todo.copyWith(title: '新标题');

      expect(updated.title, '新标题');
      expect(updated.id, todo.id); // id 不变
      expect(updated.priority, todo.priority); // 优先级不变
      expect(updated.isCompleted, todo.isCompleted);
    });

    test('修改会刷新 updatedAt', () {
      // 构造一个 updatedAt 是过去固定时间的任务
      final past = DateTime(2020, 1, 1);
      final todo = Todo(
        id: 'fixed-id',
        title: '任务',
        createdAt: past,
        updatedAt: past,
      );

      final updated = todo.copyWith(title: '改了标题');
      // updatedAt 应该被刷新为"现在"（晚于过去时间）
      expect(updated.updatedAt.isAfter(past), isTrue);
    });
  });

  group('Todo.toggleCompleted（切换完成状态）', () {
    test('未完成 → 已完成', () {
      final todo = Todo.create(title: '任务');
      final toggled = todo.toggleCompleted();
      expect(toggled.isCompleted, isTrue);
      // 原对象不受影响（不可变性）
      expect(todo.isCompleted, isFalse);
    });

    test('已完成 → 未完成', () {
      final done = Todo.create(title: '任务').toggleCompleted();
      expect(done.toggleCompleted().isCompleted, isFalse);
    });
  });

  group('Todo 序列化（toMap / fromMap）', () {
    test('toMap 后 fromMap 能还原（往返一致）', () {
      final todo = Todo.create(
        title: '写文档',
        description: '写详细讲解',
        priority: TodoPriority.low,
      );

      final restored = Todo.fromMap(todo.toMap());

      expect(restored.id, todo.id);
      expect(restored.title, todo.title);
      expect(restored.description, todo.description);
      expect(restored.priority, todo.priority);
      expect(restored.isCompleted, todo.isCompleted);
      // 时间精度：DateTime.parse 会丢失微秒，比较到秒即可
      expect(restored.createdAt.toIso8601String(), todo.createdAt.toIso8601String());
    });

    test('fromMap 能处理 null 的可选字段', () {
      final map = {
        'id': 'abc',
        'title': '任务',
        'description': '',
        'priority': 'medium',
        'is_completed': 1,
        'created_at': '2026-09-01T10:00:00.000',
        'updated_at': '2026-09-01T10:00:00.000',
        'due_date': null,
      };

      final todo = Todo.fromMap(map);
      expect(todo.id, 'abc');
      expect(todo.isCompleted, isTrue);
      expect(todo.dueDate, isNull);
    });
  });

  group('TodoPriority（优先级枚举）', () {
    test('fromValue 解析合法值', () {
      expect(TodoPriority.fromValue('high'), TodoPriority.high);
      expect(TodoPriority.fromValue('medium'), TodoPriority.medium);
      expect(TodoPriority.fromValue('low'), TodoPriority.low);
    });

    test('fromValue 对未知值回退到 medium', () {
      expect(TodoPriority.fromValue(null), TodoPriority.medium);
      expect(TodoPriority.fromValue('unknown'), TodoPriority.medium);
    });

    test('排序权重正确（高>中>低）', () {
      expect(TodoPriority.high.sortOrder, greaterThan(TodoPriority.medium.sortOrder));
      expect(TodoPriority.medium.sortOrder, greaterThan(TodoPriority.low.sortOrder));
    });
  });
}
