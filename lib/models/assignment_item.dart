import 'package:xml/xml.dart';

class AssignmentItem {
  final String id;
  final String title;
  final String subject;
  final String description;
  final DateTime deadline;
  final bool isCompleted;
  final int? notificationId;

  AssignmentItem({
    required this.id,
    required this.title,
    required this.subject,
    required this.description,
    required this.deadline,
    this.isCompleted = false,
    this.notificationId,
  });

  // Create a copy of the assignment with updated fields
  AssignmentItem copyWith({
    String? id,
    String? title,
    String? subject,
    String? description,
    DateTime? deadline,
    bool? isCompleted,
    int? notificationId,
  }) {
    return AssignmentItem(
      id: id ?? this.id,
      title: title ?? this.title,
      subject: subject ?? this.subject,
      description: description ?? this.description,
      deadline: deadline ?? this.deadline,
      isCompleted: isCompleted ?? this.isCompleted,
      notificationId: notificationId ?? this.notificationId,
    );
  }

  // Convert AssignmentItem to XML element
  XmlElement toXml() {
    final builder = XmlBuilder();
    builder.element('assignment', nest: () {
      builder.element('id', nest: id);
      builder.element('title', nest: title);
      builder.element('subject', nest: subject);
      builder.element('description', nest: description);
      builder.element('deadline', nest: deadline.toIso8601String());
      builder.element('isCompleted', nest: isCompleted.toString());
      if (notificationId != null) {
        builder.element('notificationId', nest: notificationId.toString());
      }
    });
    return builder.buildDocument().rootElement;
  }

  // Create AssignmentItem from XML element
  factory AssignmentItem.fromXml(XmlElement element) {
    return AssignmentItem(
      id: element.findElements('id').first.innerText,
      title: element.findElements('title').first.innerText,
      subject: element.findElements('subject').first.innerText,
      description: element.findElements('description').first.innerText,
      deadline: DateTime.parse(element.findElements('deadline').first.innerText),
      isCompleted: element.findElements('isCompleted').first.innerText == 'true',
      notificationId: element.findElements('notificationId').isNotEmpty
          ? int.parse(element.findElements('notificationId').first.innerText)
          : null,
    );
  }

  @override
  String toString() {
    return 'AssignmentItem(id: $id, title: $title, subject: $subject, deadline: $deadline, isCompleted: $isCompleted)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AssignmentItem && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}