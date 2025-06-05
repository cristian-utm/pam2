import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:xml/xml.dart';
import '../models/assignment_item.dart';

class XmlStorageService {
  static const String _fileName = 'assignments.xml';

  static Future<String> _getFilePath() async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/$_fileName';
  }

  static Future<void> saveAssignmentsToXml(List<AssignmentItem> assignments) async {
    try {
      final filePath = await _getFilePath();
      final file = File(filePath);

      final builder = XmlBuilder();
      builder.processing('xml', 'version="1.0" encoding="UTF-8"');
      builder.element('assignments', nest: () {
        for (final assignment in assignments) {
          builder.element('assignment', nest: () {
            builder.element('id', nest: assignment.id);
            builder.element('title', nest: assignment.title);
            builder.element('subject', nest: assignment.subject);
            builder.element('description', nest: assignment.description);
            builder.element('deadline', nest: assignment.deadline.toIso8601String());
            builder.element('isCompleted', nest: assignment.isCompleted.toString());
            if (assignment.notificationId != null) {
              builder.element('notificationId', nest: assignment.notificationId.toString());
            }
          });
        }
      });

      final document = builder.buildDocument();
      await file.writeAsString(document.toXmlString(pretty: true));
    } catch (e) {
      throw Exception('Failed to save assignments to XML: $e');
    }
  }

  static Future<List<AssignmentItem>> loadAssignmentsFromXml() async {
    try {
      final filePath = await _getFilePath();
      final file = File(filePath);

      // Return empty list if file doesn't exist
      if (!await file.exists()) {
        return [];
      }

      final xmlString = await file.readAsString();
      final document = XmlDocument.parse(xmlString);
      final assignmentElements = document.findAllElements('assignment');

      final assignments = <AssignmentItem>[];
      for (final element in assignmentElements) {
        try {
          final assignment = AssignmentItem(
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
          assignments.add(assignment);
        } catch (e) {
          // Skip malformed assignment entries
          print('Warning: Skipping malformed assignment entry: $e');
        }
      }

      return assignments;
    } catch (e) {
      throw Exception('Failed to load assignments from XML: $e');
    }
  }

  // Delete the XML file (for testing or reset purposes)
  static Future<void> deleteAssignmentsFile() async {
    try {
      final filePath = await _getFilePath();
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      throw Exception('Failed to delete assignments file: $e');
    }
  }

  // Check if assignments file exists
  static Future<bool> fileExists() async {
    try {
      final filePath = await _getFilePath();
      final file = File(filePath);
      return await file.exists();
    } catch (e) {
      return false;
    }
  }
}