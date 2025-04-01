import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../utils/learning_center_models.dart';
import '../../utils/learning_center_service.dart';
import 'package:logging/logging.dart' as logging;

final _logger = logging.Logger('HeartMurmurDetailScreen');

// Design constants to maintain consistency with other screens
class MurmurTheme {
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
  
  static final TextStyle labelStyle = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: textSecondary,
    letterSpacing: -0.1,
    height: 1.4,
  );
  
  static final TextStyle captionStyle = GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: textSecondary,
    height: 1.5,
  );
  
  // Border radius
  static final BorderRadius borderRadius = BorderRadius.circular(16);
  static final BorderRadius chipRadius = BorderRadius.circular(12);
  static final BorderRadius buttonRadius = BorderRadius.circular(12);
  
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
        _showSnackBar(
          'Error loading audio: $e',
          isError: true,
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
        _showSnackBar(
          'Error loading image: $e',
          isWarning: true,
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

  void _showSnackBar(String message, {bool isError = false, bool isWarning = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: Colors.white,
          ),
        ),
        backgroundColor: isError
            ? Colors.red[700]
            : isWarning
                ? Colors.orange[700]
                : MurmurTheme.primaryColor,
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
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Get color based on the murmur timing
    final timingColor = MurmurTheme.getTimingColor(widget.murmur.timing);
    
    return Scaffold(
      backgroundColor: MurmurTheme.secondaryColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: MurmurTheme.textPrimary,
        elevation: 0,
        centerTitle: false,
        title: Text(
          widget.murmur.name,
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: MurmurTheme.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header section with timing badge
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [MurmurTheme.subtleShadow],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Timing badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: timingColor.withAlpha(26),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      widget.murmur.timing,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: timingColor,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Description
                  Text(
                    widget.murmur.description,
                    style: MurmurTheme.bodyStyle,
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 500.ms, delay: 100.ms),
            
            // Main content with padding
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Audio player
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: MurmurTheme.borderRadius,
                    ),
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Listen to Heart Murmur',
                            style: MurmurTheme.cardTitleStyle,
                          ),
                          const SizedBox(height: 20),
                          if (_isAudioLoading)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 40),
                                child: CircularProgressIndicator(),
                              ),
                            )
                          else if (_audioUrl == null)
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 30),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.music_off_rounded,
                                      size: 48,
                                      color: Colors.grey.withAlpha(150),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Audio not available',
                                      style: MurmurTheme.labelStyle.copyWith(
                                        color: MurmurTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            Column(
                              children: [
                                // Playback controls
                                Center(
                                  child: Container(
                                    width: 72,
                                    height: 72,
                                    decoration: BoxDecoration(
                                      color: MurmurTheme.primaryColor.withAlpha(10),
                                      shape: BoxShape.circle,
                                      boxShadow: [MurmurTheme.subtleShadow],
                                    ),
                                    child: IconButton(
                                      iconSize: 40,
                                      icon: Icon(
                                        _isPlaying 
                                            ? Icons.pause_rounded 
                                            : Icons.play_arrow_rounded,
                                        color: MurmurTheme.primaryColor,
                                      ),
                                      onPressed: _playPause,
                                    ),
                                  ),
                                ),
                                
                                const SizedBox(height: 20),
                                
                                // Progress bar
                                SliderTheme(
                                  data: SliderThemeData(
                                    trackHeight: 4,
                                    thumbShape: const RoundSliderThumbShape(
                                      enabledThumbRadius: 6,
                                    ),
                                    overlayShape: const RoundSliderOverlayShape(
                                      overlayRadius: 14,
                                    ),
                                    activeTrackColor: MurmurTheme.primaryColor,
                                    inactiveTrackColor: Colors.grey.withAlpha(40),
                                    thumbColor: MurmurTheme.primaryColor,
                                    overlayColor: MurmurTheme.primaryColor.withAlpha(30),
                                  ),
                                  child: Slider(
                                    min: 0,
                                    max: _duration.inSeconds.toDouble(),
                                    value: _position.inSeconds.toDouble().clamp(
                                      0, 
                                      _duration.inSeconds.toDouble() > 0 
                                          ? _duration.inSeconds.toDouble() 
                                          : 0,
                                    ),
                                    onChanged: (value) async {
                                      final position = Duration(seconds: value.toInt());
                                      await _audioPlayer.seek(position);
                                    },
                                  ),
                                ),
                                
                                // Duration display
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        _formatDuration(_position),
                                        style: MurmurTheme.captionStyle,
                                      ),
                                      Text(
                                        _formatDuration(_duration),
                                        style: MurmurTheme.captionStyle,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(duration: 500.ms, delay: 200.ms),
                  
                  const SizedBox(height: 24),
                  
                  // Murmur characteristics
                  Text(
                    'Characteristics',
                    style: MurmurTheme.subheadingStyle,
                  ).animate().fadeIn(duration: 500.ms, delay: 300.ms),
                  
                  const SizedBox(height: 16),
                  
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: MurmurTheme.borderRadius,
                    ),
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildCharacteristicRow(
                            'Position', 
                            widget.murmur.position, 
                            Icons.location_on_rounded,
                            MurmurTheme.accentColor,
                          ),
                          _buildCharacteristicRow(
                            'Timing', 
                            widget.murmur.timing, 
                            Icons.access_time_rounded,
                            timingColor,
                          ),
                          _buildCharacteristicRow(
                            'Quality', 
                            widget.murmur.quality, 
                            Icons.waves_rounded,
                            MurmurTheme.accentColor,
                          ),
                          _buildCharacteristicRow(
                            'Grade', 
                            widget.murmur.grade, 
                            Icons.graphic_eq_rounded,
                            MurmurTheme.accentColor,
                            showDivider: false,
                          ),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(duration: 500.ms, delay: 400.ms),
                  
                  const SizedBox(height: 24),
                  
                  // Clinical implications
                  Text(
                    'Clinical Implications',
                    style: MurmurTheme.subheadingStyle,
                  ).animate().fadeIn(duration: 500.ms, delay: 500.ms),
                  
                  const SizedBox(height: 16),
                  
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: MurmurTheme.borderRadius,
                    ),
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: widget.murmur.clinicalImplications.map((implication) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    color: MurmurTheme.primaryColor.withAlpha(20),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.arrow_right_alt_rounded,
                                    color: MurmurTheme.primaryColor,
                                    size: 16,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    implication,
                                    style: MurmurTheme.bodyStyle,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ).animate().fadeIn(duration: 500.ms, delay: 600.ms),
                  
                  // Image if available
                  if (widget.murmur.imageUrl != null) ...[
                    const SizedBox(height: 24),
                    
                    Text(
                      'Illustration',
                      style: MurmurTheme.subheadingStyle,
                    ).animate().fadeIn(duration: 500.ms, delay: 700.ms),
                    
                    const SizedBox(height: 16),
                    
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: MurmurTheme.borderRadius,
                      ),
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: _isImageLoading 
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 40),
                                child: CircularProgressIndicator(),
                              ),
                            )
                          : _imageUrl != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  _imageUrl!,
                                  fit: BoxFit.contain,
                                  loadingBuilder: (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Center(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 40),
                                        child: CircularProgressIndicator(
                                          value: loadingProgress.expectedTotalBytes != null
                                              ? loadingProgress.cumulativeBytesLoaded / 
                                                  loadingProgress.expectedTotalBytes!
                                              : null,
                                          color: MurmurTheme.primaryColor,
                                        ),
                                      ),
                                    );
                                  },
                                  errorBuilder: (context, error, stackTrace) {
                                    _logger.severe('Error loading image: $error');
                                    return Container(
                                      height: 200,
                                      decoration: BoxDecoration(
                                        color: Colors.grey.withAlpha(30),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Center(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.broken_image_rounded,
                                              size: 48,
                                              color: Colors.grey.withAlpha(150),
                                            ),
                                            const SizedBox(height: 12),
                                            Text(
                                              'Image not available',
                                              style: MurmurTheme.labelStyle.copyWith(
                                                color: MurmurTheme.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              )
                            : Container(
                                height: 200,
                                decoration: BoxDecoration(
                                  color: Colors.grey.withAlpha(30),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.image_not_supported_rounded,
                                        size: 48,
                                        color: Colors.grey.withAlpha(150),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'Image not available',
                                        style: MurmurTheme.labelStyle.copyWith(
                                          color: MurmurTheme.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                      ),
                    ).animate().fadeIn(duration: 500.ms, delay: 800.ms),
                  ],
                  
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCharacteristicRow(
    String label, 
    String value, 
    IconData icon,
    Color iconColor, {
    bool showDivider = true,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconColor.withAlpha(20),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: iconColor,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: MurmurTheme.labelStyle,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: MurmurTheme.bodyStyle.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          const Divider(height: 1),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
}