import 'package:flutter/material.dart';
import '../../utils/learning_center_models.dart';
import '../../utils/learning_center_service.dart';
import 'heart_murmur_detail_screen.dart';
import 'package:logging/logging.dart' as logging;

final _logger = logging.Logger('HeartMurmurLibraryScreen');

class HeartMurmurLibraryScreen extends StatefulWidget {
  const HeartMurmurLibraryScreen({Key? key}) : super(key: key);

  @override
  State<HeartMurmurLibraryScreen> createState() => _HeartMurmurLibraryScreenState();
}

class _HeartMurmurLibraryScreenState extends State<HeartMurmurLibraryScreen> {
  final LearningCenterService _learningService = LearningCenterService();
  late Future<List<HeartMurmur>> _murmursFuture;
  String _searchQuery = '';
  List<String> _selectedTimingFilters = ['All'];
  
  final TextEditingController _searchController = TextEditingController();
  
  // Define all possible timing filter categories
  final List<Map<String, String>> _timingFilters = [
    {'display': 'All', 'value': 'All'},
    {'display': 'Syst.', 'value': 'Systolic'},
    {'display': 'Early Syst.', 'value': 'Early Systolic'},
    {'display': 'Mid Syst.', 'value': 'Mid Systolic'},
    {'display': 'Late Syst.', 'value': 'Late Systolic'},
    {'display': 'Holosyst.', 'value': 'Holosystolic'},
    {'display': 'Diast.', 'value': 'Diastolic'},
    {'display': 'Early Diast.', 'value': 'Early Diastolic'},
    {'display': 'Mid Diast.', 'value': 'Mid Diastolic'},
    {'display': 'Late Diast.', 'value': 'Late Diastolic'},
    {'display': 'Cont.', 'value': 'Continuous'},
  ];
  
  @override
  void initState() {
    super.initState();
    _murmursFuture = _learningService.getHeartMurmurs();
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _clearSearch() {
    setState(() {
      _searchQuery = '';
      _searchController.clear();
    });
  }

  void _clearFilters() {
    setState(() {
      _selectedTimingFilters = ['All'];
    });
  }

  // Helper function to shorten timing tags
  String _getShortenedTiming(String timing) {
    // Map of long timing phrases to shorter versions
    final Map<String, String> timingMap = {
      'mid to late diastolic, often with presystolic accentuation': 'Late Diast.',
      'mid to late diastolic': 'Mid-Late Diast.',
      'early to mid-systolic': 'Early-Mid Syst.',
      'mid to late systolic': 'Mid-Late Syst.',
      'late systolic': 'Late Syst.',
      'early diastolic': 'Early Diast.',
      'mid diastolic': 'Mid Diast.',
      'late diastolic': 'Late Diast.',
      'holosystolic': 'Holosyst.',
      'early systolic': 'Early Syst.',
      'mid systolic': 'Mid Syst.',
      'continuous': 'Cont.',
      'systolic': 'Syst.',
      'diastolic': 'Diast.',
    };
    
    // Search for matches (case insensitive)
    String lowerTiming = timing.toLowerCase();
    for (var entry in timingMap.entries) {
      if (lowerTiming.contains(entry.key.toLowerCase())) {
        return entry.value;
      }
    }
    
    // Default: if the timing is already short (<=8 chars), keep it
    // Otherwise abbreviate it (first 6 chars + ...)
    if (timing.length <= 8) {
      return timing;
    } else {
      return '${timing.substring(0, 6)}...';
    }
  }

  // Helper function to check if a murmur matches the timing filter
  bool _matchesTimingFilter(HeartMurmur murmur) {
    // If 'All' is selected, show everything
    if (_selectedTimingFilters.contains('All')) {
      return true;
    }
    
    String lowerTiming = murmur.timing.toLowerCase();
    
    // Check if any selected filter matches the murmur timing
    for (String filter in _selectedTimingFilters) {
      if (filter == 'All') continue;
      
      // Handle special cases for better matching
      if (filter == 'Systolic' && 
          (lowerTiming.contains('systolic') && !lowerTiming.contains('holosystolic'))) {
        return true;
      }
      else if (filter == 'Early Systolic' && 
              (lowerTiming.contains('early') && lowerTiming.contains('systolic'))) {
        return true;
      }
      else if (filter == 'Mid Systolic' && 
              (lowerTiming.contains('mid') && lowerTiming.contains('systolic'))) {
        return true;
      }
      else if (filter == 'Late Systolic' && 
              (lowerTiming.contains('late') && lowerTiming.contains('systolic'))) {
        return true;
      }
      else if (filter == 'Holosystolic' && lowerTiming.contains('holosystolic')) {
        return true;
      }
      else if (filter == 'Diastolic' && 
              (lowerTiming.contains('diastolic'))) {
        return true;
      }
      else if (filter == 'Early Diastolic' && 
              (lowerTiming.contains('early') && lowerTiming.contains('diastolic'))) {
        return true;
      }
      else if (filter == 'Mid Diastolic' && 
              (lowerTiming.contains('mid') && lowerTiming.contains('diastolic'))) {
        return true;
      }
      else if (filter == 'Late Diastolic' && 
              (lowerTiming.contains('late') && lowerTiming.contains('diastolic'))) {
        return true;
      }
      else if (filter == 'Continuous' && lowerTiming.contains('continuous')) {
        return true;
      }
    }
    
    return false;
  }

  // Helper function to highlight search matches in text
  Widget _highlightSearchMatches(String text, {TextStyle? style, int maxLines = 1, bool truncate = true}) {
    if (_searchQuery.isEmpty) {
      return Text(
        text,
        style: style,
        maxLines: maxLines,
        overflow: truncate ? TextOverflow.ellipsis : TextOverflow.clip,
      );
    }
    
    // Case insensitive search
    final List<InlineSpan> spans = [];
    final String lowerText = text.toLowerCase();
    final String lowerQuery = _searchQuery.toLowerCase();
    
    int lastMatchEnd = 0;
    
    // Find all occurrences of the search query
    int startIndex = 0;
    while (true) {
      final int index = lowerText.indexOf(lowerQuery, startIndex);
      if (index == -1) break;
      
      // Add text before match
      if (index > lastMatchEnd) {
        spans.add(TextSpan(
          text: text.substring(lastMatchEnd, index),
          style: style,
        ));
      }
      
      // Add highlighted match
      spans.add(TextSpan(
        text: text.substring(index, index + lowerQuery.length),
        style: style?.copyWith(
          backgroundColor: Colors.yellow.withOpacity(0.3),
          fontWeight: FontWeight.bold,
        ),
      ));
      
      lastMatchEnd = index + lowerQuery.length;
      startIndex = lastMatchEnd;
    }
    
    // Add remaining text
    if (lastMatchEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastMatchEnd),
        style: style,
      ));
    }
    
    return RichText(
      text: TextSpan(children: spans),
      maxLines: maxLines,
      overflow: truncate ? TextOverflow.ellipsis : TextOverflow.clip,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Heart Murmur Library',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
        actions: [
          if (_searchQuery.isNotEmpty || !_selectedTimingFilters.contains('All') || _selectedTimingFilters.length > 1)
            IconButton(
              icon: const Icon(Icons.filter_alt_off),
              tooltip: 'Clear all filters',
              onPressed: () {
                setState(() {
                  _searchQuery = '';
                  _searchController.clear();
                  _selectedTimingFilters = ['All'];
                });
              },
            ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildFilterChips(),
          Expanded(
            child: _buildMurmurList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      color: Theme.of(context).appBarTheme.backgroundColor,
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search heart murmurs',
          prefixIcon: const Icon(Icons.search, size: 22),
          suffixIcon: _searchQuery.isNotEmpty 
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 20),
                  onPressed: _clearSearch,
                ) 
              : null,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
          isDense: true,
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value.trim().toLowerCase();
          });
        },
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      color: Theme.of(context).appBarTheme.backgroundColor,
      width: double.infinity,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _timingFilters.map((filter) => _buildFilterChip(filter)).toList(),
        ),
      ),
    );
  }

  Widget _buildFilterChip(Map<String, String> filter) {
    final isSelected = _selectedTimingFilters.contains(filter['value']);
    
    // If we have a multi-selection that includes 'All', we want to show only 'All'
    // as selected for visual clarity
    final bool visuallySelected = isSelected && 
        (filter['value'] == 'All' ? true : !_selectedTimingFilters.contains('All'));
    
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(
          filter['display']!,
          style: TextStyle(
            fontWeight: visuallySelected ? FontWeight.w500 : FontWeight.normal,
            fontSize: 13,
          ),
        ),
        selected: visuallySelected,
        backgroundColor: Colors.white,
        selectedColor: Theme.of(context).primaryColor.withAlpha(40),
        checkmarkColor: Theme.of(context).primaryColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: visuallySelected 
                ? Theme.of(context).primaryColor.withAlpha(60) 
                : Colors.grey.withAlpha(30),
            width: 1,
          ),
        ),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        onSelected: (selected) {
          setState(() {
            // Multi-select logic with "All" handling
            if (filter['value'] == 'All') {
              // If "All" is selected, clear all other selections
              _selectedTimingFilters = ['All'];
            } else {
              // If a specific filter is selected
              if (selected) {
                // Remove "All" if it was previously selected
                if (_selectedTimingFilters.contains('All')) {
                  _selectedTimingFilters.remove('All');
                }
                // Add the new filter
                _selectedTimingFilters.add(filter['value']!);
              } else {
                // Remove filter if unselected
                _selectedTimingFilters.remove(filter['value']);
                // If no filters remain, select "All"
                if (_selectedTimingFilters.isEmpty) {
                  _selectedTimingFilters = ['All'];
                }
              }
            }
          });
        },
      ),
    );
  }

  Widget _buildMurmurList() {
    return FutureBuilder<List<HeartMurmur>>(
      future: _murmursFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }
        
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: Colors.red[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading heart murmurs',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    style: TextStyle(
                      color: Colors.red[700],
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _murmursFuture = _learningService.getHeartMurmurs();
                      });
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.medical_information_outlined,
                  size: 64,
                  color: Colors.grey,
                ),
                SizedBox(height: 16),
                Text(
                  'No heart murmurs available',
                  style: TextStyle(fontSize: 16),
                ),
              ],
            ),
          );
        }
        
        // Apply both search and filter
        var murmurs = snapshot.data!;
        List<HeartMurmur> filteredMurmurs = [];
        
        for (var murmur in murmurs) {
          // First check if it matches the timing filter
          if (!_matchesTimingFilter(murmur)) {
            continue;
          }
          
          // Then check if it matches the search query
          if (_searchQuery.isNotEmpty) {
            String lowerName = murmur.name.toLowerCase();
            String lowerDescription = murmur.description.toLowerCase();
            String lowerPosition = murmur.position.toLowerCase();
            String lowerQuality = murmur.quality.toLowerCase();
            String lowerGrade = murmur.grade.toLowerCase();
            
            if (lowerName.contains(_searchQuery) ||
                lowerDescription.contains(_searchQuery) ||
                lowerPosition.contains(_searchQuery) ||
                lowerQuality.contains(_searchQuery) ||
                lowerGrade.contains(_searchQuery)) {
              filteredMurmurs.add(murmur);
            }
          } else {
            // If no search query, just add the filtered murmur
            filteredMurmurs.add(murmur);
          }
        }
        
        if (filteredMurmurs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.search_off,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No heart murmurs match your criteria',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (_searchQuery.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      '"$_searchQuery"',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _searchQuery = '';
                        _searchController.clear();
                        _selectedTimingFilters = ['All'];
                      });
                    },
                    icon: const Icon(Icons.filter_alt_off),
                    label: const Text('Clear All Filters'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        
        // Sort the filtered results by name for consistent ordering
        filteredMurmurs.sort((a, b) => a.name.compareTo(b.name));
        
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filteredMurmurs.length,
          itemBuilder: (context, index) {
            final murmur = filteredMurmurs[index];
            return _buildPolishedMurmurCard(murmur, context);
          },
        );
      },
    );
  }

  Widget _buildPolishedMurmurCard(HeartMurmur murmur, BuildContext context) {
    // Create a color based on the murmur timing
    Color cardColor;
    if (murmur.timing.toLowerCase().contains('systolic')) {
      cardColor = Colors.redAccent;
    } else if (murmur.timing.toLowerCase().contains('diastolic')) {
      cardColor = Colors.blueAccent;
    } else if (murmur.timing.toLowerCase().contains('continuous')) {
      cardColor = Colors.purpleAccent;
    } else {
      cardColor = Colors.grey;
    }
    
    // Get shortened timing
    String shortenedTiming = _getShortenedTiming(murmur.timing);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.withAlpha(30), width: 0.5),
      ),
      elevation: 0.5,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _navigateToMurmurDetail(murmur),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left color indicator
              Container(
                width: 4,
                height: 60,
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              const SizedBox(width: 12),
              
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Murmur name with timing badge
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _highlightSearchMatches(
                            murmur.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: cardColor.withAlpha(30),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            shortenedTiming,
                            style: TextStyle(
                              color: cardColor,
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 6),
                    
                    // Brief description
                    _highlightSearchMatches(
                      murmur.description,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                        height: 1.3,
                      ),
                      maxLines: 2,
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Tap for more indicator
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Icon(
                          Icons.arrow_forward,
                          size: 16,
                          color: Theme.of(context).primaryColor.withAlpha(150),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Details',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).primaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
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

  void _navigateToMurmurDetail(HeartMurmur murmur) {
    _logger.info('Navigating to detail screen for murmur: ${murmur.name}');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HeartMurmurDetailScreen(murmur: murmur),
      ),
    );
  }
}