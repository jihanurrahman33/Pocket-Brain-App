import 'package:flutter/material.dart';

import '../../../domain/entities/memory.dart';

extension MemorySourceIcon on MemorySource {
  IconData get icon => switch (this) {
    MemorySource.note => Icons.notes_rounded,
    MemorySource.link => Icons.link_rounded,
    MemorySource.clipboard => Icons.content_paste_rounded,
    MemorySource.voice => Icons.mic_rounded,
    MemorySource.image => Icons.image_outlined,
    MemorySource.pdf => Icons.picture_as_pdf_outlined,
  };
}
