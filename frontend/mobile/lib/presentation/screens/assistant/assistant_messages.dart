import '../../../data/ai/ai_gateway.dart';
import '../../../domain/entities/course_models.dart';

/// Un élément de la conversation.
///
/// Le plan et le cours ne sont pas du texte : ce sont des cartes avec des
/// boutons (« Construire le cours », « Télécharger »). Le type
/// porte donc la donnée, pas une chaîne déjà mise en forme.
sealed class AssistantMessage {
  const AssistantMessage();
}

class UserMessage extends AssistantMessage {
  const UserMessage(this.text);
  final String text;
}

class AssistantText extends AssistantMessage {
  const AssistantText(this.text, {this.isError = false});
  final String text;
  final bool isError;
}

/// Le plan proposé, avant dépense.
class OutlineMessage extends AssistantMessage {
  const OutlineMessage({required this.brief, required this.outline});
  final CourseBrief brief;
  final CourseOutline outline;
}

/// Le cours construit, téléchargeable.
class CourseMessage extends AssistantMessage {
  const CourseMessage(this.course);
  final SavedCourse course;
}

/// L'assistant travaille.
class PendingMessage extends AssistantMessage {
  const PendingMessage(this.label);
  final String label;
}
