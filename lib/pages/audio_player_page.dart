import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:io';
import '../models/audio_waveform.dart';
import '../widgets/waveform_visualizer.dart';
import '../widgets/saved_regions_panel.dart';
import '../models/saved_regions.dart';

class AudioPlayerPage extends StatefulWidget {
  const AudioPlayerPage({super.key});

  @override
  State<AudioPlayerPage> createState() => _AudioPlayerPageState();
}

class _AudioPlayerPageState extends State<AudioPlayerPage> with TickerProviderStateMixin {
  final AudioPlayer _player = AudioPlayer();
  List<double> amplitudes = [];
  String? _fileName;
  String? _filePath;
  Duration _currentPosition = Duration.zero;
  Duration _audioDuration = Duration.zero;
  double? _loopStartFraction;
  double? _loopEndFraction;
  final TextEditingController _startController = TextEditingController();
  final TextEditingController _endController = TextEditingController();
  final FocusNode _startFocusNode = FocusNode();
  final FocusNode _endFocusNode = FocusNode();
  bool _loading = false;
  final List<SavedRegion> _savedRegions = [];

  late final AnimationController _scaleController;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );

    _startFocusNode.addListener(() {
      if (!_startFocusNode.hasFocus) _updateLoopFromTextFields();
    });
    _endFocusNode.addListener(() {
      if (!_endFocusNode.hasFocus) _updateLoopFromTextFields();
    });

    _player.durationStream.listen((duration) {
      if (duration != null) {
        setState(() {
          _audioDuration = duration;
        });
      }
    });

    _player.positionStream.listen((position) {
      setState(() {
        _currentPosition = position;

        if (_shouldLoop) {
          final startMs = (_audioDuration.inMilliseconds * _realStart).toInt();
          final endMs = (_audioDuration.inMilliseconds * _realEnd).toInt();

          if (_currentPosition.inMilliseconds >= endMs) {
            _player.seek(Duration(milliseconds: startMs));
          }
        }
      });
    });
  }

  bool get _shouldLoop =>
      _loopStartFraction != null &&
      _loopEndFraction != null &&
      _loopStartFraction != _loopEndFraction &&
      _audioDuration.inMilliseconds > 0;

  double get _realStart =>
      (_loopStartFraction! < _loopEndFraction!) ? _loopStartFraction! : _loopEndFraction!;

  double get _realEnd =>
      (_loopStartFraction! > _loopEndFraction!) ? _loopStartFraction! : _loopEndFraction!;

  double get _currentProgress => (_audioDuration.inMilliseconds == 0)
      ? 0.0
      : _currentPosition.inMilliseconds / _audioDuration.inMilliseconds;

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return '${twoDigits(duration.inMinutes.remainder(60))}:${twoDigits(duration.inSeconds.remainder(60))}';
  }

  String _formatFractionAsMMSS(double fraction) {
    if (_audioDuration.inMilliseconds == 0) return '00:00';
    final milliseconds = (_audioDuration.inMilliseconds * fraction).toInt();
    return _formatDuration(Duration(milliseconds: milliseconds));
  }

  void _updateLoopFromTextFields() {
    if (_audioDuration.inMilliseconds == 0) return;

    try {
      final parseTime = (String text) {
        final parts = text.trim().split(':');
        if (parts.length != 2) throw FormatException('Invalid time format');
        final minutes = int.parse(parts[0]);
        final seconds = int.parse(parts[1]);
        return Duration(minutes: minutes, seconds: seconds).inMilliseconds;
      };

      final startText = _startController.text;
      final endText = _endController.text;

      final startMs = parseTime(startText);
      final endMs = (endText.isEmpty) ? startMs : parseTime(endText);

      setState(() {
        _loopStartFraction = (startMs / _audioDuration.inMilliseconds).clamp(0.0, 1.0);
        _loopEndFraction = (endMs / _audioDuration.inMilliseconds).clamp(0.0, 1.0);
      });

      _updateBreathing();
    } catch (e) {
      debugPrint('Invalid time format: $e');
    }
  }

  void _updateBreathing() {
    if (_shouldLoop) {
      if (!_scaleController.isAnimating) {
        _scaleController.repeat(reverse: true);
      }
    } else {
      if (_scaleController.isAnimating) {
        _scaleController.stop();
      }
    }
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _startFocusNode.dispose();
    _endFocusNode.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _pickAndLoadAudio() async {
    setState(() {
      _loading = true;
    });

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['wav', 'mp3'],
      );

      if (result != null && result.files.single.path != null) {
        String path = result.files.single.path!;
        
        // Clear previous selections and saved regions
        setState(() {
          _loopStartFraction = null;
          _loopEndFraction = null;
          _startController.clear();
          _endController.clear();
          _savedRegions.clear();
        });

        amplitudes.clear();
        amplitudes = await compute(readWaveformInIsolate, path);
        debugPrint("Amplitude samples: ${amplitudes.length}");

        await _player.setFilePath(path);

        setState(() {
          _filePath = path;
          _fileName = File(path).uri.pathSegments.last;
          _currentPosition = Duration.zero; // <- optional, resets displayed time
        });

        // Load regions AFTER setting file name
        final loadedRegions = await SavedRegion.loadRegions(_fileName!);
        setState(() {
          _savedRegions.addAll(loadedRegions);
        });
      }
    } catch (e) {
      debugPrint('Error loading audio: $e');
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  void _playPause() {
    if (_player.playing) {
      _player.pause();
    } else {
      _player.play();
    }
  }

  void _restart() {
    _player.seek(Duration.zero);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.library_music_outlined, size: 28),
                      label: const Text('Load Audio File', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w300)),
                      onPressed: _pickAndLoadAudio,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0095F2),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    StreamBuilder<bool>(
                      stream: _player.playingStream,
                      builder: (context, snapshot) {
                        bool isPlaying = snapshot.data ?? false;
                        return ElevatedButton.icon(
                          label: Text("Play/Pause", style: TextStyle(fontSize: 16, color: const Color(0xFF0095F2), fontWeight: FontWeight.w300)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color.fromARGB(255, 239, 239, 239),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: Icon(
                            isPlaying ? Icons.pause : Icons.play_arrow,
                            size: 30,
                            color: const Color(0xFFFAA336), // You could darken this slightly if you want (#F2932B)
                          ),
                          onPressed: _playPause,
                        );
                      },
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      label: Text("Restart", style: TextStyle(fontSize: 16, color: const Color(0xFF0095F2), fontWeight: FontWeight.w300)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 239, 239, 239),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.replay, size: 30, color: Color(0xFF0095F2)),
                      onPressed: _restart,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  _fileName != null ? 'Loaded: $_fileName' : 'No audio file loaded',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),
                const SizedBox(height: 10),
                if (_loading)
                  const SizedBox(
                    height: 150,
                    child: Center(child: CircularProgressIndicator()),
                  )
                else
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1F29),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
                    height: 140,
                    child: amplitudes.isNotEmpty
                      ? AnimatedBuilder(
                          animation: _scaleAnimation,
                          builder: (context, child) {
                            return Transform.scale(
                              scaleX: 1.0,
                              scaleY: _scaleAnimation.value,
                              child: child,
                            );
                          },
                          child: WaveformVisualizer(
                            amplitudes: amplitudes,
                            loopStartFraction: _loopStartFraction,
                            loopEndFraction: _loopEndFraction,
                            progress: _currentProgress,
                            currentTimeLabel: _formatDuration(_currentPosition),
                            onSeek: (fraction) {
                              final newPosition = Duration(
                                milliseconds: (_audioDuration.inMilliseconds * fraction).toInt(),
                              );
                              _player.seek(newPosition);
                            },
                            onSelectStart: (value) {
                              setState(() {
                                _loopStartFraction = value;
                                _loopEndFraction = value;
                                _startController.text = _formatFractionAsMMSS(value);
                                _endController.text = _formatFractionAsMMSS(value);
                              });
                              _updateBreathing();
                            },
                            onSelectEnd: (value) {
                              setState(() {
                                _loopEndFraction = value;
                                _endController.text = _formatFractionAsMMSS(value);
                              });
                              _updateBreathing();
                            },
                            onClearLoop: () {
                              setState(() {
                                _loopStartFraction = null;
                                _loopEndFraction = null;
                                _startController.clear();
                                _endController.clear();
                              });
                              _updateBreathing();
                            },
                          ),
                        )
                      : const Center(
                          child: Text(
                            ' ',
                            style: TextStyle(color: Colors.white54, fontSize: 14),
                          ),
                        ),
                  ),
                const SizedBox(height: 12),
                (_audioDuration.inMilliseconds > 0)
                  ? Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_formatDuration(_currentPosition), style: const TextStyle(fontSize: 12)),
                      Text(_formatDuration(_audioDuration), style: const TextStyle(fontSize: 12)),
                    ],
                  )
                  : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("0:00", style: const TextStyle(fontSize: 12)),
                      Text("0:00", style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Column(
                        children: [
                          Text(
                            'PLAYBACK SPEED',
                            style: TextStyle(
                              color: const Color(0xFFFAA336),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 1.5,
                            ),
                          ),
                          Slider(
                            min: 0.5,
                            max: 1.5,
                            divisions: 10,
                            value: _player.speed,
                            label: '${_player.speed.toStringAsFixed(2)}x',
                            onChanged: (value) {
                              _player.setSpeed(value);
                              setState(() {});
                            },
                            activeColor: const Color(0xFF0095F2),
                            inactiveColor: Colors.grey.shade300,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 1,
                      child: TextField(
                        controller: _startController,
                        focusNode: _startFocusNode,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w300),
                        decoration: InputDecoration(
                          floatingLabelStyle: const TextStyle(color: Color(0xFF0095F2)),
                          labelText: ' Start (MM:SS) ',
                          labelStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w300),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF0095F2), width: 2),
                          ),
                        ),
                        onSubmitted: (_) => _updateLoopFromTextFields(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 1,
                      child: TextField(
                        controller: _endController,
                        focusNode: _endFocusNode,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w300),
                        decoration: InputDecoration(
                          floatingLabelStyle: const TextStyle(color: Color(0xFF0095F2)),
                          labelText: ' End (MM:SS) ',
                          labelStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w300),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF0095F2), width: 2),
                          ),
                        ),
                        onSubmitted: (_) => _updateLoopFromTextFields(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                Divider(thickness: 1),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Saved Selections",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(8),
                    child: SavedRegionsPanel(
                      audioFileName: _fileName.toString(),
                      regions: _savedRegions,
                      onSave: (name) {
                        if (_loopStartFraction != null && _loopEndFraction != null) {
                          setState(() {
                            _savedRegions.add(SavedRegion(
                              name: name,
                              startFraction: _loopStartFraction!,
                              endFraction: _loopEndFraction!,
                            ));
                          });
                        }
                      },
                      onSelect: (region) {
                        setState(() {
                          _loopStartFraction = region.startFraction;
                          _loopEndFraction = region.endFraction;
                          _startController.text = _formatFractionAsMMSS(region.startFraction);
                          _endController.text = _formatFractionAsMMSS(region.endFraction);
                        });
                        _updateBreathing();
                        final startMs = (_audioDuration.inMilliseconds * region.startFraction).toInt();
                        _player.seek(Duration(milliseconds: startMs));
                      },
                    ),       
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}