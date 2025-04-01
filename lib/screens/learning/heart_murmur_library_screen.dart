import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../utils/learning_center_models.dart';
import '../../utils/learning_center_service.dart';
import 'heart_murmur_detail_screen.dart';
import 'package:logging/logging.dart' as logging;

final _logger = logging.Logger('HeartMurmurLibraryScreen');

// Use the same theme configuration as the detail screen
class MurmurLibraryTheme {
  // Main color palette
  static const Color primaryColor = Color(0xFF1D557E);  // Main blue
  static const Color secondaryColor = Color(0xFFE6EDF7); // Light blue background
  static const Color accentColor = Color(0xFF2E86C1);   // Medium blue for accents
  
  // Timing colors
  static const Color systolicColor = Color(0xFFF44336);  // Red for systolic
  static const Color diastolicColor = Color(0xFF2196F3); // Blue for diastolic
  static const Color continuousColor = Color(0xFF9C27B0); // Purple for continuous
  
  // Text colors
  static const Color textPrimary = Color(0xFF263238);
  static const Color textSecondary = Color(0xFF546E7A);
  static const Color textLight = Color(0xFF78909C);
  
  // Shadows
  static final cardShadow = BoxShadow(
    color: Colors.black.withAlpha(18),
    blurRadius: 12,
    spreadRadius: 0,
    offset: const Offset(0, 3),
  );
  
  static final subtleShadow = BoxShadow(
    color: Colors.black.withAlpha(10),
    blurRadius: 6,
    spreadRadius: 0,
    offset: const Offset(0, 2),
  );
  
  // Text styles
  static final TextStyle headingStyle = GoogleFonts.inter(
    fontSize: 22,
    fontWeight: FontWeight.bold,
    color: textPrimary,
    letterSpacing: -0.3,
    height: 1.3,
  );
  
  static final TextStyle subheadingStyle = GoogleFonts.inter(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    letterSpacing: -0.2,
    height: 1.4,
  );
  
  static final TextStyle cardTitleStyle = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    letterSpacing: -0.2,
    height: 1.3,
  );
  
  static final TextStyle bodyStyle = GoogleFonts.inter(
    fontSize: 15,
    fontWeight: FontWeight.normal,
    color: textPrimary,
    letterSpacing: -0.1,
    height: 1.5,
  );
  
  static final TextStyle emphasisStyle = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: textPrimary,
    height: 1.5,
  );
  
  static final TextStyle captionStyle = GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: textSecondary,
    height: 1.5,
  );
  
  static final TextStyle chipTextStyle = GoogleFonts.inter(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: primaryColor,
    height: 1.3,
  );
  
  // Border radius
  static final BorderRadius borderRadius = BorderRadius.circular(16);
  static final BorderRadius chipRadius = BorderRadius.circular(12);
  static final BorderRadius searchRadius = BorderRadius.circular(12);
  
  // Get color for timing
  static Color getTimingColor(String timing) {
    final lowerTiming = timing.toLowerCase();
    
    if (lowerTiming.contains('systolic')) {
      return systolicColor;
    } else if (lowerTiming.contains('diastolic')) {
      return diastolicColor;
    } else if (lowerTiming.contains('continuous')) {
      return continuousColor;
    } else {
      return textSecondary;
    }
  }
}

class HeartMurmurLibraryScreen extends StatefulWidget {
  const HeartMurmurLibraryScreen({super.key});

  @override
  State<HeartMurmurLibraryScreen> createState() => _HeartMurmurLibraryScreenState();
}

class _HeartMurmurLibraryScreenState extends State<HeartMurmurLibraryScreen> {
  final LearningCenterService _learningService = LearningCenterService(); 
  late Future<List<HeartMurmur>> _murmursFuture;
  String _searchQuery = '';
  List<String> _selectedTimingFilters = ['All'];
  
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
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
    _scrollController.dispose();
    super.dispose();
  }

  void _clearSearch() {
    setState(() {
      _searchQuery = '';
      _searchController.clear();
    });
  }

  void _clearAllFilters() {
    setState(() {
      _searchQuery = '';
      _searchController.clear();
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
          backgroundColor: Colors.yellow.withAlpha(77),
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

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: Colors.white,
          ),
        ),
        backgroundColor: MurmurLibraryTheme.primaryColor,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MurmurLibraryTheme.secondaryColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: MurmurLibraryTheme.textPrimary,
        elevation: 0,
        centerTitle: false,
        title: Text(
          'Heart Murmur Library',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: MurmurLibraryTheme.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          if (_searchQuery.isNotEmpty || !_selectedTimingFilters.contains('All') || _selectedTimingFilters.length > 1)
            Container(
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: MurmurLibraryTheme.primaryColor.withAlpha(20),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: const Icon(Icons.filter_alt_off_rounded),
                tooltip: 'Clear all filters',
                color: MurmurLibraryTheme.primaryColor,
                onPressed: _clearAllFilters,
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Search and filter container
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search heart murmurs',
                    hintStyle: GoogleFonts.inter(
                      fontSize: 14,
                      color: MurmurLibraryTheme.textLight,
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      size: 20,
                      color: MurmurLibraryTheme.textLight,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty 
                        ? IconButton(
                            icon: const Icon(
                              Icons.clear_rounded,
                              size: 18,
                            ),
                            color: MurmurLibraryTheme.textLight,
                            onPressed: _clearSearch,
                          ) 
                        : null,
                    filled: true,
                    fillColor: MurmurLibraryTheme.secondaryColor,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                    border: OutlineInputBorder(
                      borderRadius: MurmurLibraryTheme.searchRadius,
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: MurmurLibraryTheme.searchRadius,
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: MurmurLibraryTheme.searchRadius,
                      borderSide: BorderSide(
                        color: MurmurLibraryTheme.primaryColor.withAlpha(100),
                        width: 1.5,
                      ),
                    ),
                  ),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: MurmurLibraryTheme.textPrimary,
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.trim().toLowerCase();
                    });
                  },
                ),
                
                // Filter label
                Padding(
                  padding: const EdgeInsets.only(top: 16, bottom: 8, left: 4),
                  child: Text(
                    'Filter by Timing',
                    style: MurmurLibraryTheme.emphasisStyle,
                  ),
                ),
                
                // Filter chips
                SizedBox(
                  height: 36,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _timingFilters.length,
                    itemBuilder: (context, index) => _buildFilterChip(_timingFilters[index]),
                  ),
                ),
              ],
            ),
          ),
          
          // Results area
          Expanded(
            child: _buildMurmurList(),
          ),
        ],
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
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: visuallySelected ? FontWeight.w600 : FontWeight.normal,
            color: visuallySelected 
                ? MurmurLibraryTheme.primaryColor 
                : MurmurLibraryTheme.textSecondary,
          ),
        ),
        selected: visuallySelected,
        backgroundColor: Colors.white,
        selectedColor: MurmurLibraryTheme.primaryColor.withAlpha(20),
        checkmarkColor: MurmurLibraryTheme.primaryColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: visuallySelected 
                ? MurmurLibraryTheme.primaryColor.withAlpha(60) 
                : Colors.grey.withAlpha(40),
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
          return Center(
            child: CircularProgressIndicator(
              color: MurmurLibraryTheme.primaryColor,
            ),
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
                    Icons.error_outline_rounded,
                    size: 48,
                    color: Colors.red.withAlpha(200),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading heart murmurs',
                    style: MurmurLibraryTheme.cardTitleStyle,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.red[700],
                      height: 1.5,
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
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: MurmurLibraryTheme.primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: MurmurLibraryTheme.chipRadius,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.healing_rounded,
                  size: 64,
                  color: Colors.grey.withAlpha(150),
                ),
                const SizedBox(height: 16),
                Text(
                  'No heart murmurs available',
                  style: MurmurLibraryTheme.cardTitleStyle,
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
                  Icon(
                    Icons.search_off_rounded,
                    size: 64,
                    color: Colors.grey.withAlpha(150),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No heart murmurs match your criteria',
                    style: MurmurLibraryTheme.cardTitleStyle,
                    textAlign: TextAlign.center,
                  ),
                  if (_searchQuery.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      '"$_searchQuery"',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: MurmurLibraryTheme.textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: _clearAllFilters,
                    icon: const Icon(Icons.filter_alt_off_rounded),
                    label: const Text('Clear All Filters'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: MurmurLibraryTheme.primaryColor,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      side: BorderSide(
                        color: MurmurLibraryTheme.primaryColor.withAlpha(100),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: MurmurLibraryTheme.chipRadius,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        
        // Sort the filtered results by name for consistent ordering
        filteredMurmurs.sort((a, b) => a.name.compareTo(b.name));
        
        return RefreshIndicator(
          onRefresh: () async {
            setState(() {
              _murmursFuture = _learningService.getHeartMurmurs();
            });
          },
          color: MurmurLibraryTheme.primaryColor,
          child: ListView.builder(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            itemCount: filteredMurmurs.length,
            itemBuilder: (context, index) {
              final murmur = filteredMurmurs[index];
              return _buildMurmurCard(murmur, index);
            },
          ),
        );
      },
    );
  }

  Widget _buildMurmurCard(HeartMurmur murmur, int index) {
    // Create a color based on the murmur timing
    final Color cardColor = MurmurLibraryTheme.getTimingColor(murmur.timing);
    
    // Get shortened timing
    final String shortenedTiming = _getShortenedTiming(murmur.timing);
    
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: MurmurLibraryTheme.borderRadius,
      ),
      color: Colors.white,
      child: InkWell(
        borderRadius: MurmurLibraryTheme.borderRadius,
        onTap: () => _navigateToMurmurDetail(murmur),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left color indicator
              Container(
                width: 4,
                height: 80,
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              const SizedBox(width: 16),
              
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
                            style: MurmurLibraryTheme.cardTitleStyle,
                            maxLines: 1,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: cardColor.withAlpha(26),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            shortenedTiming,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: cardColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Brief description
                    _highlightSearchMatches(
                      murmur.description,
                      style: MurmurLibraryTheme.bodyStyle.copyWith(
                        color: MurmurLibraryTheme.textSecondary,
                      ),
                      maxLines: 2,
                    ),
                    
                    const SizedBox(height: 10),
                    
                    // View details link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          'View Details',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: MurmurLibraryTheme.primaryColor,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 16,
                          color: MurmurLibraryTheme.primaryColor,
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
    ).animate().fadeIn(
      duration: 400.ms,
      delay: Duration(milliseconds: 50 * index),
    ).slideY(begin: 0.1, end: 0);
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