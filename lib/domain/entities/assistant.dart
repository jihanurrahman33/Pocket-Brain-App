import 'package:equatable/equatable.dart';

/// A function Ask Brain's model may call, described as a JSON schema.
class AssistantTool extends Equatable {
  const AssistantTool({required this.name, required this.description, required this.parameters});

  final String name;
  final String description;
  final Map<String, Object?> parameters;

  @override
  List<Object?> get props => [name, description];
}

/// Things Ask Brain can propose doing. Nothing that changes data happens
/// until the user confirms it.
enum AssistantActionType { createTask, saveMemory }

enum AssistantActionStatus { proposed, done, dismissed }

/// A proposed change, shown as a confirmation card under an answer.
class AssistantAction extends Equatable {
  const AssistantAction({
    required this.id,
    required this.type,
    required this.args,
    this.status = AssistantActionStatus.proposed,
  });

  final String id;
  final AssistantActionType type;

  /// Validated, string-valued arguments (e.g. `title`, `due`, `remind`).
  final Map<String, String> args;
  final AssistantActionStatus status;

  bool get isPending => status == AssistantActionStatus.proposed;

  AssistantAction withStatus(AssistantActionStatus status) =>
      AssistantAction(id: id, type: type, args: args, status: status);

  @override
  List<Object?> get props => [id, type, args, status];
}
