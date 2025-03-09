

import 'package:flutter/material.dart';
import '../../utils/learning_center_models.dart';
import '../../utils/learning_center_service.dart';
import 'heart_murmur_detail_screen.dart';

class HeartMurmurLibraryScreen extends StatefulWidget {
  const HeartMurmurLibraryScreen({Key? key}) : super(key: key);

  @override
  State<HeartMurmurLibraryScreen> createState() => _HeartMurmurLibraryScreenState();
}

class _HeartMurmurLibraryScreenState extends State<HeartMurmurLibraryScreen> {
  final LearningCenterService _learningService = LearningCenterService();
  late Future<List<HeartMurmur>> _murmursFuture;
  String _searchQuery = '';
  String _filterTiming = 'All';
  
  @override
  void initState() {
    super.initState();
    _murmursFuture = _learningService.getHeartMurmurs();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Heart Murmur Library',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        elevation: 2,
      ),
      body: Column(
        children: [
          _buildSearchAndFilter(),
          Expanded(
            child: _buildMurmurList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[50],
      child: Column(
        children: [
          // Search bar
          TextField(
            decoration: InputDecoration(
              hintText: 'Search heart murmurs',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value.toLowerCase();
              });
            },
          ),
          
          const SizedBox(height: 12),
          
          // Filter by timing
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('All'),
                _buildFilterChip('Systolic'),
                _buildFilterChip('Diastolic'),
                _buildFilterChip('Continuous'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String timing) {
    final isSelected = _filterTiming == timing;
    
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(timing),
        selected: isSelected,
        backgroundColor: Colors.white,
        selectedColor: Theme.of(context).primaryColor.withAlpha(40),
        checkmarkColor: Theme.of(context).primaryColor,
        onSelected: (selected) {
          setState(() {
            _filterTiming = timing;
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
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Error loading heart murmurs: ${snapshot.error}',
                  style: TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _murmursFuture = _learningService.getHeartMurmurs();
                    });
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }
        
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Text('No heart murmurs available'),
          );
        }
        
        // Filter murmurs based on search and timing filter
        var murmurs = snapshot.data!;
        
        if (_searchQuery.isNotEmpty) {
          murmurs = murmurs.where((murmur) {
            return murmur.name.toLowerCase().contains(_searchQuery) ||
                murmur.description.toLowerCase().contains(_searchQuery) ||
                murmur.position.toLowerCase().contains(_searchQuery);
          }).toList();
        }
        
        if (_filterTiming != 'All') {
          murmurs = murmurs.where((murmur) {
            return murmur.timing.contains(_filterTiming);
          }).toList();
        }
        
        if (murmurs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.search_off,
                  size: 48,
                  color: Colors.grey,
                ),
                const SizedBox(height: 16),
                const Text(
                  'No heart murmurs match your search criteria',
                  style: TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _searchQuery = '';
                      _filterTiming = 'All';
                    });
                  },
                  child: const Text('Clear Filters'),
                ),
              ],
            ),
          );
        }
        
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: murmurs.length,
          itemBuilder: (context, index) {
            final murmur = murmurs[index];
            return _buildMurmurCard(murmur);
          },
        );
      },
    );
  }

  Widget _buildMurmurCard(HeartMurmur murmur) {
    // Create a color based on the murmur timing
    Color cardColor;
    switch (murmur.timing) {
      case 'Systolic':
        cardColor = Colors.redAccent;
        break;
      case 'Diastolic':
        cardColor = Colors.blueAccent;
        break;
      case 'Continuous':
        cardColor = Colors.purpleAccent;
        break;
      default:
        cardColor = Colors.grey;
    }
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _navigateToMurmurDetail(murmur),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Murmur name and timing badge
              Row(
                children: [
                  Expanded(
                    child: Text(
                      murmur.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: cardColor.withAlpha(40),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      murmur.timing,
                      style: TextStyle(
                        color: cardColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 8),
              
              // Description
              Text(
                murmur.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
              ),
              
              const SizedBox(height: 12),
              
              // Murmur details
              Row(
                children: [
                  _buildDetailItem(Icons.location_on, 'Position', murmur.position),
                  const SizedBox(width: 16),
                  _buildDetailItem(Icons.graphic_eq, 'Grade', murmur.grade),
                ],
              ),
              
              const SizedBox(height: 8),
              
              // Quality
              _buildDetailItem(Icons.waves, 'Quality', murmur.quality),
              
              const Divider(height: 24),
              
              // Listen button
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.play_circle_filled),
                    label: const Text('Listen & Learn More'),
                    onPressed: () => _navigateToMurmurDetail(murmur),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 16,
          color: Colors.grey[600],
        ),
        const SizedBox(width: 4),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  void _navigateToMurmurDetail(HeartMurmur murmur) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HeartMurmurDetailScreen(murmur: murmur),
      ),
    );
  }
}