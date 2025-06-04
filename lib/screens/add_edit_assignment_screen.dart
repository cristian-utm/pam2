import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/assignment_item.dart';
import '../services/xml_storage_service.dart';
import '../services/assignment_notification_service.dart';

class AddEditAssignmentScreen extends StatefulWidget {
  final AssignmentItem? assignment;

  const AddEditAssignmentScreen({super.key, this.assignment});

  @override
  State<AddEditAssignmentScreen> createState() => _AddEditAssignmentScreenState();
}

class _AddEditAssignmentScreenState extends State<AddEditAssignmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _subjectController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  bool _isLoading = false;
  
  bool get _isEditMode => widget.assignment != null;

  @override
  void initState() {
    super.initState();
    _initializeFields();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subjectController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // Initialize form fields with existing data if in edit mode
  void _initializeFields() {
    if (_isEditMode) {
      final assignment = widget.assignment!;
      _titleController.text = assignment.title;
      _subjectController.text = assignment.subject;
      _descriptionController.text = assignment.description;
      _selectedDate = DateTime(
        assignment.deadline.year,
        assignment.deadline.month,
        assignment.deadline.day,
      );
      _selectedTime = TimeOfDay(
        hour: assignment.deadline.hour,
        minute: assignment.deadline.minute,
      );
    }
  }

  // Get the combined deadline DateTime
  DateTime get _deadline {
    return DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );
  }

  // Show date picker
  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  // Show time picker
  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  // Generate unique ID for new assignments
  String _generateUniqueId() {
    return 'assignment_${DateTime.now().millisecondsSinceEpoch}';
  }

  // Save assignment
  Future<void> _saveAssignment() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Load existing assignments
      final existingAssignments = await XmlStorageService.loadAssignmentsFromXml();
      
      AssignmentItem newAssignment;
      
      if (_isEditMode) {
        // Update existing assignment
        final oldAssignment = widget.assignment!;
        
        // Cancel old notification if it exists
        if (oldAssignment.notificationId != null) {
          await AssignmentNotificationService.cancelNotification(oldAssignment.notificationId);
        }
        
        newAssignment = oldAssignment.copyWith(
          title: _titleController.text.trim(),
          subject: _subjectController.text.trim(),
          description: _descriptionController.text.trim(),
          deadline: _deadline,
          notificationId: null, // Will be set when scheduling notification
        );
        
        // Update in the list
        final index = existingAssignments.indexWhere((item) => item.id == oldAssignment.id);
        if (index != -1) {
          existingAssignments[index] = newAssignment;
        }
      } else {
        // Create new assignment
        newAssignment = AssignmentItem(
          id: _generateUniqueId(),
          title: _titleController.text.trim(),
          subject: _subjectController.text.trim(),
          description: _descriptionController.text.trim(),
          deadline: _deadline,
          isCompleted: false,
        );
        
        // Add to the list
        existingAssignments.add(newAssignment);
      }
      
      // Schedule notification if deadline is in the future and not completed
      int? notificationId;
      if (!newAssignment.isCompleted && _deadline.isAfter(DateTime.now())) {
        notificationId = await AssignmentNotificationService.scheduleNotification(newAssignment);
        
        // Update assignment with notification ID
        if (notificationId != null) {
          newAssignment = newAssignment.copyWith(notificationId: notificationId);
          
          // Update in the list again with notification ID
          if (_isEditMode) {
            final index = existingAssignments.indexWhere((item) => item.id == newAssignment.id);
            if (index != -1) {
              existingAssignments[index] = newAssignment;
            }
          } else {
            existingAssignments[existingAssignments.length - 1] = newAssignment;
          }
        }
      }
      
      // Save to XML
      await XmlStorageService.saveAssignmentsToXml(existingAssignments);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditMode 
                  ? 'Assignment updated successfully' 
                  : 'Assignment created successfully',
            ),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving assignment: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Assignment' : 'Add Assignment'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Title field
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Assignment Title *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a title';
                        }
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Subject field
                    TextFormField(
                      controller: _subjectController,
                      decoration: const InputDecoration(
                        labelText: 'Subject *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a subject';
                        }
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Description field
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                      maxLines: 4,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a description';
                        }
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Date selection
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.calendar_today),
                        title: const Text('Due Date'),
                        subtitle: Text(DateFormat('EEEE, MMMM d, y').format(_selectedDate)),
                        trailing: const Icon(Icons.arrow_forward_ios),
                        onTap: _selectDate,
                      ),
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Time selection
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.access_time),
                        title: const Text('Due Time'),
                        subtitle: Text(_selectedTime.format(context)),
                        trailing: const Icon(Icons.arrow_forward_ios),
                        onTap: _selectTime,
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _saveAssignment,
                            child: Text(_isEditMode ? 'Update Assignment' : 'Save Assignment'),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Deadline info
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Deadline Summary:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('EEEE, MMMM d, y \'at\' h:mm a').format(_deadline),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _deadline.isBefore(DateTime.now())
                                ? 'This deadline is in the past'
                                : 'A notification will be scheduled 1 hour before the deadline',
                            style: TextStyle(
                              fontSize: 12,
                              color: _deadline.isBefore(DateTime.now())
                                  ? Colors.red
                                  : Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}