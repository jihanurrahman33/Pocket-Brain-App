import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../domain/entities/memory.dart';

/// A rounded image from local storage; tap to view it full screen.
class AttachmentImage extends StatelessWidget {
  const AttachmentImage({super.key, required this.path, this.maxHeight = 320});

  final String path;
  final double maxHeight;

  void _openFullScreen(BuildContext context) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
        body: InteractiveViewer(child: Center(child: Image.file(File(path)))),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final file = File(path);
    if (!file.existsSync()) {
      return const _Missing(icon: Icons.broken_image_outlined, label: 'Image not found');
    }
    return Semantics(
      image: true,
      label: 'Attached image. Double tap to view full screen.',
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        onTap: () => _openFullScreen(context),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: Image.file(file, fit: BoxFit.contain, width: double.infinity),
          ),
        ),
      ),
    );
  }
}

/// Shows that a memory has a voice recording, with its length on disk.
class AttachmentAudioChip extends StatelessWidget {
  const AttachmentAudioChip({super.key, required this.attachment});

  final Attachment attachment;

  /// 16 kHz mono 16-bit WAV.
  static const _bytesPerSecond = 32000;

  @override
  Widget build(BuildContext context) {
    final file = File(attachment.path);
    if (!file.existsSync()) {
      return const _Missing(icon: Icons.mic_off_outlined, label: 'Recording not found');
    }
    final seconds = (file.lengthSync() / _bytesPerSecond).round();
    return Chip(
      avatar: const Icon(Icons.graphic_eq_rounded, size: AppSpacing.lg),
      label: Text('Voice note · ${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}'),
    );
  }
}

class _Missing extends StatelessWidget {
  const _Missing({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Chip(avatar: Icon(icon), label: Text(label));
}
