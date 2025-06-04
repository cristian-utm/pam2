import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../models/assignment_item.dart';
import '../services/xml_storage_service.dart';
import '../services/assignment_notification_service.dart';
import 'add_edit_assignment_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  List<AssignmentItem> _allAssignments = [];
  List<AssignmentItem> _filteredAssignments = [];
  DateTime _selectedDate = DateTime.now();
  DateTime _focusedDate = DateTime.now();
  DateTime? _rangeStart;
  DateTime? _rangeEnd;
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;
  bool _showAllAssignments = false;
  RangeSelectionMode _rangeSelectionMode = RangeSelectionMode.toggledOff;

  @override
  void initState() {
    super.initState();
    _loadAssignments();
    _searchController.addListener(_filterAssignments);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Load assignments from XML storage
  Future<void> _loadAssignments() async {
    try {
      setState(() {
        _isLoading = true;
      });
      
      final assignments = await XmlStorageService.loadAssignmentsFromXml();
      setState(() {
        _allAssignments = assignments;
        _isLoading = false;
      });
      _filterAssignments();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading assignments: $e')),
        );
      }
    }
  }

  // Filter assignments based on selected date/range and search term
  void _filterAssignments() {
    final searchTerm = _searchController.text.toLowerCase();
    
    setState(() {
      _filteredAssignments = _allAssignments.where((assignment) {
        final assignmentDateOnly = DateTime(
          assignment.deadline.year,
          assignment.deadline.month,
          assignment.deadline.day,
        );
        
        bool matchesDate = true;
        
        if (!_showAllAssignments) {
          if (_rangeStart != null && _rangeEnd != null) {
            // Range selection mode
            final rangeStartOnly = DateTime(_rangeStart!.year, _rangeStart!.month, _rangeStart!.day);
            final rangeEndOnly = DateTime(_rangeEnd!.year, _rangeEnd!.month, _rangeEnd!.day);
            matchesDate = assignmentDateOnly.isAtSameMomentAs(rangeStartOnly) ||
                         assignmentDateOnly.isAtSameMomentAs(rangeEndOnly) ||
                         (assignmentDateOnly.isAfter(rangeStartOnly) && assignmentDateOnly.isBefore(rangeEndOnly));
          } else {
            // Single date selection mode
            final selectedDateOnly = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
            matchesDate = assignmentDateOnly.isAtSameMomentAs(selectedDateOnly);
          }
        }
        
        final matchesSearch = searchTerm.isEmpty ||
            assignment.title.toLowerCase().contains(searchTerm) ||
            assignment.subject.toLowerCase().contains(searchTerm) ||
            assignment.description.toLowerCase().contains(searchTerm);
        
        return matchesDate && matchesSearch;
      }).toList();
      
      // Sort by deadline time in descending order (latest first)
      _filteredAssignments.sort((a, b) => b.deadline.compareTo(a.deadline));
    });
  }

  // Get assignments for a specific date (for calendar markers)
  List<AssignmentItem> _getAssignmentsForDate(DateTime date) {
    final dateOnly = DateTime(date.year, date.month, date.day);
    return _allAssignments.where((assignment) {
      final assignmentDateOnly = DateTime(
        assignment.deadline.year,
        assignment.deadline.month,
        assignment.deadline.day,
      );
      return assignmentDateOnly.isAtSameMomentAs(dateOnly);
    }).toList();
  }

  // Toggle show all assignments mode
  void _toggleShowAll() {
    setState(() {
      _showAllAssignments = !_showAllAssignments;
      if (_showAllAssignments) {
        _clearRangeSelection();
      }
    });
    _filterAssignments();
  }

  // Clear range selection
  void _clearRangeSelection() {
    setState(() {
      _rangeStart = null;
      _rangeEnd = null;
      _rangeSelectionMode = RangeSelectionMode.toggledOff;
    });
  }

  // Toggle range selection mode
  void _toggleRangeSelection() {
    setState(() {
      if (_rangeSelectionMode == RangeSelectionMode.toggledOff) {
        _rangeSelectionMode = RangeSelectionMode.toggledOn;
        _showAllAssignments = false;
        _clearRangeSelection();
      } else {
        _rangeSelectionMode = RangeSelectionMode.toggledOff;
        _clearRangeSelection();
      }
    });
    _filterAssignments();
  }

  // Navigate to add/edit assignment screen
  Future<void> _navigateToAddEditScreen([AssignmentItem? assignment]) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditAssignmentScreen(assignment: assignment),
      ),
    );
    
    if (result == true) {
      _loadAssignments();
    }
  }

  // Delete an assignment
  Future<void> _deleteAssignment(AssignmentItem assignment) async {
    try {
      // Cancel notification if exists
      if (assignment.notificationId != null) {
        await AssignmentNotificationService.cancelNotification(assignment.notificationId);
      }
      
      // Remove from list
      _allAssignments.removeWhere((item) => item.id == assignment.id);
      
      // Save to XML
      await XmlStorageService.saveAssignmentsToXml(_allAssignments);
      
      _filterAssignments();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Assignment deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting assignment: $e')),
        );
      }
    }
  }

  // Toggle assignment completion status
  Future<void> _toggleCompletion(AssignmentItem assignment) async {
    try {
      final updatedAssignment = assignment.copyWith(isCompleted: !assignment.isCompleted);
      
      // Cancel notification if marking as completed
      if (updatedAssignment.isCompleted && assignment.notificationId != null) {
        await AssignmentNotificationService.cancelNotification(assignment.notificationId);
      }
      
      // Update in list
      final index = _allAssignments.indexWhere((item) => item.id == assignment.id);
      if (index != -1) {
        _allAssignments[index] = updatedAssignment;
      }
      
      // Save to XML
      await XmlStorageService.saveAssignmentsToXml(_allAssignments);
      
      _filterAssignments();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating assignment: $e')),
        );
      }
    }
  }

  // Show delete confirmation dialog
  Future<void> _showDeleteConfirmation(AssignmentItem assignment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Assignment'),
        content: Text('Are you sure you want to delete "${assignment.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      await _deleteAssignment(assignment);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Assignment Planner'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Search bar
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: 'Search assignments...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                
                // Calendar
                TableCalendar<AssignmentItem>(
                  firstDay: DateTime.utc(2020, 1, 1),
                  lastDay: DateTime.utc(2030, 12, 31),
                  focusedDay: _focusedDate,
                  selectedDayPredicate: (day) => isSameDay(_selectedDate, day),
                  rangeStartDay: _rangeStart,
                  rangeEndDay: _rangeEnd,
                  rangeSelectionMode: _rangeSelectionMode,
                  eventLoader: _getAssignmentsForDate,
                  startingDayOfWeek: StartingDayOfWeek.monday,
                  calendarStyle: CalendarStyle(
                    outsideDaysVisible: false,
                    markerDecoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    rangeHighlightColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                    rangeStartDecoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    rangeEndDecoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  headerStyle: const HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                  ),
                  onDaySelected: (selectedDay, focusedDay) {
                    if (_rangeSelectionMode == RangeSelectionMode.toggledOff) {
                      setState(() {
                        _selectedDate = selectedDay;
                        _focusedDate = focusedDay;
                        _showAllAssignments = false;
                      });
                      _filterAssignments();
                    }
                  },
                  onRangeSelected: (start, end, focusedDay) {
                    setState(() {
                      _selectedDate = focusedDay;
                      _focusedDate = focusedDay;
                      _rangeStart = start;
                      _rangeEnd = end;
                      _showAllAssignments = false;
                    });
                    _filterAssignments();
                  },
                ),
                
                // Control buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _toggleShowAll,
                          icon: Icon(_showAllAssignments ? Icons.calendar_today : Icons.view_list),
                          label: Text(_showAllAssignments ? 'Show Calendar' : 'Show All'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _showAllAssignments 
                                ? Theme.of(context).colorScheme.primary 
                                : Theme.of(context).colorScheme.surface,
                            foregroundColor: _showAllAssignments 
                                ? Theme.of(context).colorScheme.onPrimary 
                                : Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _toggleRangeSelection,
                          icon: Icon(_rangeSelectionMode == RangeSelectionMode.toggledOn 
                              ? Icons.date_range 
                              : Icons.calendar_view_day),
                          label: Text(_rangeSelectionMode == RangeSelectionMode.toggledOn 
                              ? 'Single Day' 
                              : 'Date Range'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _rangeSelectionMode == RangeSelectionMode.toggledOn 
                                ? Theme.of(context).colorScheme.secondary 
                                : Theme.of(context).colorScheme.surface,
                            foregroundColor: _rangeSelectionMode == RangeSelectionMode.toggledOn 
                                ? Theme.of(context).colorScheme.onSecondary 
                                : Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const Divider(),
                
                // Dynamic header based on current view mode
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _getHeaderText(),
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (_filteredAssignments.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${_filteredAssignments.length}',
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                
                // Assignments list
                Expanded(
                  child: _filteredAssignments.isEmpty
                      ? const Center(
                          child: Text(
                            'No assignments for this date',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _filteredAssignments.length,
                          itemBuilder: (context, index) {
                            final assignment = _filteredAssignments[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                                vertical: 4.0,
                              ),
                              child: ListTile(
                                leading: Checkbox(
                                  value: assignment.isCompleted,
                                  onChanged: (_) => _toggleCompletion(assignment),
                                ),
                                title: Text(
                                  assignment.title,
                                  style: TextStyle(
                                    decoration: assignment.isCompleted
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Subject: ${assignment.subject}'),
                                    Text(
                                      'Due: ${DateFormat('h:mm a').format(assignment.deadline)}',
                                      style: TextStyle(
                                        color: assignment.deadline.isBefore(DateTime.now())
                                            ? Colors.red
                                            : null,
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _showDeleteConfirmation(assignment),
                                ),
                                onTap: () => _navigateToAddEditScreen(assignment),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToAddEditScreen(),
        child: const Icon(Icons.add),
      ),
    );
  }
}