import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yt_downloader/yt_downloader.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

// تعريف الحالة التي ستقرأها الواجهة
class DownloadState {
  final bool isLoading;
  final String? errorMessage;
  final String? videoTitle;
  final List<Format>? availableFormats;
  final double? progress;
  final bool isCompleted;

  DownloadState({
    this.isLoading = false,
    this.errorMessage,
    this.videoTitle,
    this.availableFormats,
    this.progress,
    this.isCompleted = false,
  });

  DownloadState copyWith({
    bool? isLoading,
    String? errorMessage,
    String? videoTitle,
    List<Format>? availableFormats,
    double? progress,
    bool? isCompleted,
  }) {
    return DownloadState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      videoTitle: videoTitle ?? this.videoTitle,
      availableFormats: availableFormats ?? this.availableFormats,
      progress: progress ?? this.progress,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}

// مزود الخدمة لربطه بالواجهة
final downloadProvider = StateNotifierProvider<DownloadNotifier, DownloadState>((ref) {
  return DownloadNotifier();
});

class DownloadNotifier extends StateNotifier<DownloadState> {
  DownloadNotifier() : super(DownloadState());
  final YtDownloader _yt = YtDownloader();

  // 1. دالة جلب معلومات الفيديو
  Future<void> fetchInfo(String url) async {
    if (url.isEmpty) {
      state = state.copyWith(errorMessage: 'الرجاء إدخال رابط صحيح', isLoading: false);
      return;
    }
    
    // تصفير الحالة قبل البدء
    state = DownloadState(isLoading: true);

    try {
      final info = await _yt.getInfo(url);
      state = state.copyWith(
        isLoading: false,
        videoTitle: info.title,
        availableFormats: info.formats.videoWithAudio, // جلب الجودات التي تحتوي على صوت وصورة
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'تعذر جلب الفيديو، تأكد من الرابط');
    }
  }

  // 2. دالة التحميل
  Future<void> downloadVideo(String url, Format format) async {
    state = state.copyWith(isLoading: true, progress: 0.0, isCompleted: false);

    try {
      final info = await _yt.getInfo(url);
      final dir = await getApplicationDocumentsDirectory();
      // تنظيف اسم الملف من الرموز الغريبة
      final safeTitle = info.title.replaceAll(RegExp(r'[^\w\s]+'), '');
      final outputPath = p.join(dir.path, '$safeTitle.mp4');

      await info.download(
        format: format,
        outputPath: outputPath,
        onProgress: (progress) {
          state = state.copyWith(progress: progress);
        },
      );

      state = state.copyWith(isLoading: false, isCompleted: true, progress: 1.0);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'حدث خطأ أثناء التحميل: $e');
    }
  }
}