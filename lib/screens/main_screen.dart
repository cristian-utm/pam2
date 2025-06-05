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
  DateTime? _lastClickedDay;
  DateTime? _lastClickTime;

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
            final rangeStartOnly = DateTime(_rangeStart!.year, _rangeStart!.month, _rangeStart!.day);
            final rangeEndOnly = DateTime(_rangeEnd!.year, _rangeEnd!.month, _rangeEnd!.day);
            matchesDate = assignmentDateOnly.isAtSameMomentAs(rangeStartOnly) ||
                         assignmentDateOnly.isAtSameMomentAs(rangeEndOnly) ||
                         (assignmentDateOnly.isAfter(rangeStartOnly) && assignmentDateOnly.isBefore(rangeEndOnly));
          } else {
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
      
      _filteredAssignments.sort((a, b) => b.deadline.compareTo(a.deadline));
    });
  }

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

  void _clearRangeSelection() {
    setState(() {
      _rangeStart = null;
      _rangeEnd = null;
      _lastClickedDay = null;
      _lastClickTime = null;
    });
    _filterAssignments();
  }



  String _getHeaderText() {
    if (_showAllAssignments) {
      return 'All Assignments';
    } else if (_rangeStart != null && _rangeEnd != null) {
      if (isSameDay(_rangeStart!, _rangeEnd!)) {
        return 'Assignments for ${DateFormat('EEEE, MMMM d, y').format(_rangeStart!)}';
      } else {
        final startDate = DateFormat('MMM d').format(_rangeStart!);
        final endDate = DateFormat('MMM d, y').format(_rangeEnd!);
        return 'Assignments: $startDate - $endDate';
      }
    } else if (_rangeStart != null) {
      return 'Select end date (started: ${DateFormat('MMM d').format(_rangeStart!)})';
    } else {
      return 'Select dates on calendar to filter assignments';
    }
  }

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

  Future<void> _deleteAssignment(AssignmentItem assignment) async {
    try {
      if (assignment.notificationId != null) {
        await AssignmentNotificationService.cancelNotification(assignment.notificationId);
      }
      
      _allAssignments.removeWhere((item) => item.id == assignment.id);
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

  Future<void> _toggleCompletion(AssignmentItem assignment) async {
    try {
      final updatedAssignment = assignment.copyWith(isCompleted: !assignment.isCompleted);
      
      if (updatedAssignment.isCompleted && assignment.notificationId != null) {
        await AssignmentNotificationService.cancelNotification(assignment.notificationId);
      }
      
      final index = _allAssignments.indexWhere((item) => item.id == assignment.id);
      if (index != -1) {
        _allAssignments[index] = updatedAssignment;
      }
      
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
        actions: [
          // Quick stats in app bar
          if (_filteredAssignments.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  color: Theme.of(context).colorScheme.surface,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 8.0),
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            labelText: 'Search assignments...',
                            prefixIcon: const Icon(Icons.search),
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            isDense: true,
                          ),
                        ),
                      ),
                      
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _toggleShowAll,
                                icon: Icon(_showAllAssignments ? Icons.calendar_today : Icons.view_list, size: 18),
                                label: Text(_showAllAssignments ? 'Show Calendar' : 'Show All'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _showAllAssignments 
                                      ? Theme.of(context).colorScheme.primary 
                                      : Theme.of(context).colorScheme.surface,
                                  foregroundColor: _showAllAssignments 
                                      ? Theme.of(context).colorScheme.onPrimary 
                                      : Theme.of(context).colorScheme.onSurface,
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _clearRangeSelection,
                                icon: const Icon(Icons.clear, size: 18),
                                label: const Text('Clear Selection'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: (_rangeStart != null || _rangeEnd != null)
                                      ? Theme.of(context).colorScheme.errorContainer
                                      : Theme.of(context).colorScheme.surface,
                                  foregroundColor: (_rangeStart != null || _rangeEnd != null)
                                      ? Theme.of(context).colorScheme.onErrorContainer
                                      : Theme.of(context).colorScheme.onSurface,
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Calendar - only show when not in "Show All" mode
                if (!_showAllAssignments) ...[
                  Container(
                    color: Theme.of(context).colorScheme.surface,
                    child: TableCalendar<AssignmentItem>(
                      firstDay: DateTime.utc(2020, 1, 1),
                      lastDay: DateTime.utc(2030, 12, 31),
                      focusedDay: _focusedDate,
                      selectedDayPredicate: (day) => isSameDay(_selectedDate, day),
                      rangeStartDay: _rangeStart,
                      rangeEndDay: _rangeEnd,
                      rangeSelectionMode: RangeSelectionMode.toggledOn,
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
                        final now = DateTime.now();
                        final isDoubleClick = _lastClickedDay != null &&
                            isSameDay(_lastClickedDay!, selectedDay) &&
                            _lastClickTime != null &&
                            now.difference(_lastClickTime!).inMilliseconds < 500;

                        setState(() {
                          _showAllAssignments = false;
                          _selectedDate = selectedDay;
                          _focusedDate = focusedDay;
                        });

                        if (isDoubleClick) {
                          setState(() {
                            _rangeStart = selectedDay;
                            _rangeEnd = selectedDay;
                          });
                          _filterAssignments();
                        } else if (_rangeStart == null) {
                          setState(() {
                            _rangeStart = selectedDay;
                            _rangeEnd = null;
                          });
                        } else if (_rangeEnd == null) {
                          final start = _rangeStart!;
                          final end = selectedDay;
                          setState(() {
                            _rangeStart = start.isBefore(end) ? start : end;
                            _rangeEnd = start.isBefore(end) ? end : start;
                          });
                          _filterAssignments();
                        } else {
                          setState(() {
                            _rangeStart = selectedDay;
                            _rangeEnd = null;
                          });
                        }

                        _lastClickedDay = selectedDay;
                        _lastClickTime = now;
                      },
                      onRangeSelected: null,
                    ),
                  ),
                  
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Text(
                      _rangeStart == null 
                          ? 'Tap a date to start selecting • Double-tap for single day'
                          : _rangeEnd == null
                              ? 'Tap another date to complete range • Double-tap to select single day'
                              : 'Range selected • Tap new date to start over',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
                
                Container(
                  padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 8.0),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                    border: Border(
                      bottom: BorderSide(
                        color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.assignment,
                        size: 20,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _getHeaderText(),
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                Expanded(
                  child: _filteredAssignments.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.assignment_outlined,
                                size: 80,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 24),
                              Text(
                                _showAllAssignments 
                                    ? 'No assignments found' 
                                    : 'No assignments for this period',
                                style: TextStyle(
                                  fontSize: 18, 
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Tap the + button to add your first assignment',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[500],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: () async {
                            await _loadAssignments();
                          },
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
                            physics: const BouncingScrollPhysics(),
                            itemCount: _filteredAssignments.length,
                            itemBuilder: (context, index) {
                              final assignment = _filteredAssignments[index];
                              final isOverdue = assignment.deadline.isBefore(DateTime.now()) && !assignment.isCompleted;
                              final isDueToday = DateTime.now().difference(assignment.deadline).inDays == 0;
                              
                              return Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 4.0,
                                  vertical: 4.0,
                                ),
                                child: Card(
                                  elevation: assignment.isCompleted ? 2 : 4,
                                  shadowColor: Theme.of(context).colorScheme.shadow.withOpacity(0.2),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    side: BorderSide(
                                      color: isOverdue 
                                          ? Colors.red.withOpacity(0.4)
                                          : isDueToday 
                                              ? Colors.orange.withOpacity(0.4)
                                              : assignment.isCompleted
                                                  ? Colors.green.withOpacity(0.3)
                                                  : Colors.transparent,
                                      width: isOverdue || isDueToday || assignment.isCompleted ? 2 : 0,
                                    ),
                                  ),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(16),
                                    onTap: () => _navigateToAddEditScreen(assignment),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Container(
                                                margin: const EdgeInsets.only(top: 2),
                                                child: Transform.scale(
                                                  scale: 1.2,
                                                  child: Checkbox(
                                                    value: assignment.isCompleted,
                                                    onChanged: (_) => _toggleCompletion(assignment),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    activeColor: Colors.green,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      assignment.title,
                                                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                                        decoration: assignment.isCompleted
                                                            ? TextDecoration.lineThrough
                                                            : null,
                                                        color: assignment.isCompleted
                                                            ? Colors.grey[600]
                                                            : Theme.of(context).colorScheme.onSurface,
                                                        fontWeight: FontWeight.w600,
                                                        fontSize: 18,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 4,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: Theme.of(context).colorScheme.secondaryContainer,
                                                        borderRadius: BorderRadius.circular(12),
                                                      ),
                                                      child: Text(
                                                        assignment.subject,
                                                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                                          color: Theme.of(context).colorScheme.onSecondaryContainer,
                                                          fontWeight: FontWeight.w600,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Container(
                                                margin: const EdgeInsets.only(left: 8),
                                                child: IconButton(
                                                  icon: const Icon(Icons.delete_outline),
                                                  color: Colors.red[400],
                                                  onPressed: () => _showDeleteConfirmation(assignment),
                                                  tooltip: 'Delete assignment',
                                                  iconSize: 22,
                                                ),
                                              ),
                                            ],
                                        ),
                                        if (assignment.description.isNotEmpty) ...[
                                          const SizedBox(height: 8),
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              assignment.description,
                                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                height: 1.4,
                                              ),
                                              maxLines: 3,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                        
                                        const SizedBox(height: 8),
                                        
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: isOverdue 
                                                ? Colors.red.withOpacity(0.1)
                                                : isDueToday 
                                                    ? Colors.orange.withOpacity(0.1)
                                                    : assignment.isCompleted
                                                        ? Colors.green.withOpacity(0.1)
                                                        : Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: isOverdue 
                                                  ? Colors.red.withOpacity(0.3)
                                                  : isDueToday 
                                                      ? Colors.orange.withOpacity(0.3)
                                                      : assignment.isCompleted
                                                          ? Colors.green.withOpacity(0.3)
                                                          : Colors.transparent,
                                              width: 1,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                assignment.isCompleted 
                                                    ? Icons.check_circle
                                                    : Icons.schedule,
                                                size: 18,
                                                color: isOverdue 
                                                    ? Colors.red 
                                                    : isDueToday 
                                                        ? Colors.orange 
                                                        : assignment.isCompleted
                                                            ? Colors.green
                                                            : Theme.of(context).colorScheme.primary,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  assignment.isCompleted
                                                      ? 'Completed • ${DateFormat('MMM d, h:mm a').format(assignment.deadline)}'
                                                      : 'Due ${DateFormat('MMM d, h:mm a').format(assignment.deadline)}',
                                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                    color: isOverdue 
                                                        ? Colors.red 
                                                        : isDueToday 
                                                            ? Colors.orange 
                                                            : assignment.isCompleted
                                                                ? Colors.green
                                                                : Theme.of(context).colorScheme.onSurface,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                              if (isOverdue)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.red,
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: Text(
                                                    'OVERDUE',
                                                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                                      color: Colors.white,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 10,
                                                    ),
                                                  ),
                                                ),
                                              if (isDueToday && !isOverdue)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.orange,
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: Text(
                                                    'TODAY',
                                                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                                      color: Colors.white,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 10,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
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