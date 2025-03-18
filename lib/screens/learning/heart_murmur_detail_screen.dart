import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../utils/learning_center_models.dart';
import '../../utils/learning_center_service.dart';
import 'package:logging/logging.dart' as logging;

final _logger = logging.Logger('HeartMurmurDetailScreen');

class HeartMurmurDetailScreen extends StatefulWidget {
  final HeartMurmur murmur;
  
  const HeartMurmurDetailScreen({
    super.key,
    required this.murmur,
  });

  @override
  State<HeartMurmurDetailScreen> createState() => _HeartMurmurDetailScreenState();
}

class _HeartMurmurDetailScreenState extends State<HeartMurmurDetailScreen> {
  final LearningCenterService _learningService = LearningCenterService();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  bool _isAudioLoading = false;
  bool _isImageLoading = false;
  String? _audioUrl;
  String? _imageUrl;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _loadAudioUrl();
    _loadImageUrl();
    _setupAudioPlayer();
  }

  Future<void> _loadAudioUrl() async {
    setState(() {
      _isAudioLoading = true;
    });
    
    try {
      _logger.info('Loading audio URL from: ${widget.murmur.audioUrl}');
      _audioUrl = await _learningService.getAudioUrl(widget.murmur.audioUrl);
      _logger.info('Audio URL loaded successfully: $_audioUrl');
      
      if (mounted) {
        setState(() {
          _isAudioLoading = false;
        });
      }
    } catch (e) {
      _logger.severe('Error loading audio URL: $e');
      
      if (mounted) {
        setState(() {
          _isAudioLoading = false;
        });
        
        // Show error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading audio: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _loadImageUrl() async {
    // Only attempt to load if imageUrl is not null
    if (widget.murmur.imageUrl == null) {
      _logger.info('No image URL provided for this murmur');
      return;
    }
    
    setState(() {
      _isImageLoading = true;
    });
    
    try {
      _logger.info('Loading image URL from: ${widget.murmur.imageUrl}');
      _imageUrl = await _learningService.getAudioUrl(widget.murmur.imageUrl!);
      _logger.info('Image URL loaded successfully: $_imageUrl');
      
      if (mounted) {
        setState(() {
          _isImageLoading = false;
        });
      }
    } catch (e) {
      _logger.severe('Error loading image URL: $e');
      
      if (mounted) {
        setState(() {
          _isImageLoading = false;
        });
        
        // Optional: show error for image loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading image: $e'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _setupAudioPlayer() {
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });

    _audioPlayer.onDurationChanged.listen((newDuration) {
      if (mounted) {
        setState(() {
          _duration = newDuration;
        });
      }
    });

    _audioPlayer.onPositionChanged.listen((newPosition) {
      if (mounted) {
        setState(() {
          _position = newPosition;
        });
      }
    });
  }

  Future<void> _playPause() async {
    if (_audioUrl == null) return;
    
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.play(UrlSource(_audioUrl!));
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Create a color based on the murmur timing
    Color cardColor;
    switch (widget.murmur.timing) {
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
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.murmur.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        elevation: 2,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header section with timing badge
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor.withAlpha(15),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Timing badge
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: cardColor.withAlpha(40),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          widget.murmur.timing,
                          style: TextStyle(
                            color: cardColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Description
                  Text(
                    widget.murmur.description,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            
            // Audio player
            Card(
              margin: const EdgeInsets.all(16),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Listen to Heart Murmur',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_isAudioLoading)
                      const Center(
                        child: CircularProgressIndicator(),
                      )
                    else if (_audioUrl == null)
                      const Center(
                        child: Text('Audio not available'),
                      )
                    else
                      Column(
                        children: [
                          // Playback controls
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                iconSize: 64,
                                icon: Icon(
                                  _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                                  color: Theme.of(context).primaryColor,
                                ),
                                onPressed: _playPause,
                              ),
                            ],
                          ),
                          
                          // Progress bar
                          Slider(
                            min: 0,
                            max: _duration.inSeconds.toDouble(),
                            value: _position.inSeconds.toDouble().clamp(0, _duration.inSeconds.toDouble()),
                            onChanged: (value) async {
                              final position = Duration(seconds: value.toInt());
                              await _audioPlayer.seek(position);
                            },
                          ),
                          
                          // Duration display
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(_formatDuration(_position)),
                                Text(_formatDuration(_duration)),
                              ],
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            
            // Murmur characteristics
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Characteristics',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      _buildCharacteristicRow('Position', widget.murmur.position, Icons.location_on),
                      _buildCharacteristicRow('Timing', widget.murmur.timing, Icons.access_time),
                      _buildCharacteristicRow('Quality', widget.murmur.quality, Icons.waves),
                      _buildCharacteristicRow('Grade', widget.murmur.grade, Icons.graphic_eq),
                    ],
                  ),
                ),
              ),
            ),
            
            // Clinical implications
            Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Clinical Implications',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      ...widget.murmur.clinicalImplications.map((implication) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.arrow_right,
                                color: Theme.of(context).primaryColor,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  implication,
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),
            
            // Image if available
            if (widget.murmur.imageUrl != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Illustration',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        _isImageLoading 
                          ? const Center(
                              child: CircularProgressIndicator(),
                            )
                          : _imageUrl != null
                            ? Image.network(
                                _imageUrl!,
                                fit: BoxFit.contain,
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Center(
                                    child: CircularProgressIndicator(
                                      value: loadingProgress.expectedTotalBytes != null
                                          ? loadingProgress.cumulativeBytesLoaded / 
                                              loadingProgress.expectedTotalBytes!
                                          : null,
                                    ),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) {
                                  _logger.severe('Error loading image: $error');
                                  return Container(
                                    height: 200,
                                    color: Colors.grey[200],
                                    child: const Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.error_outline, size: 48, color: Colors.grey),
                                          SizedBox(height: 8),
                                          Text('Image not available'),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              )
                            : Container(
                                height: 200,
                                color: Colors.grey[200],
                                child: const Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.image_not_supported, size: 48, color: Colors.grey),
                                      SizedBox(height: 8),
                                      Text('Image not available'),
                                    ],
                                  ),
                                ),
                              ),
                      ],
                    ),
                  ),
                ),
              ),
            
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildCharacteristicRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: Colors.grey[600],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
}