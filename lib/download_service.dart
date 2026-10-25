import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yt_downloader/yt_downloader.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class DownloadState {
  final bool isLoading;
  final String? errorMessage;
  final String? videoTitle;
  final List<VideoQuality>? availableQualities; // تم التعديل هنا
  final double? progress;
  final bool isCompleted;

  DownloadState({
    this.isLoading = false,
    this.errorMessage,
    this.videoTitle,
    this.availableQualities,
    this.progress,
    this.isCompleted = false,
  });

  DownloadState copyWith({
    bool? isLoading,
    String? errorMessage,
    String? videoTitle,
    List<VideoQuality>? availableQualities,
    double? progress,
    bool? isCompleted,
  }) {
    return DownloadState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      videoTitle: videoTitle ?? this.videoTitle,
      availableQualities: availableQualities ?? this.availableQualities,
      progress: progress ?? this.progress,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}

final downloadProvider = StateNotifierProvider<DownloadNotifier, DownloadState>((ref) {
  return DownloadNotifier();
});

class DownloadNotifier extends StateNotifier<DownloadState> {
  DownloadNotifier() : super(DownloadState());
  final YtDownloader _yt = YtDownloader();

  Future<void> fetchInfo(String url) async {
    if (url.isEmpty) {
      state = state.copyWith(errorMessage: 'الرجاء إدخال رابط صحيح', isLoading: false);
      return;
    }
    state = DownloadState(isLoading: true);

    try {
      final info = await _yt.getInfo(url);
      
      // جلب الجودات المتاحة من المكتبة
      final qualities = info.formats.videoWithAudio
          .map((format) => format.quality)
          .whereType<VideoQuality>()
          .toSet()
          .toList();

      state = state.copyWith(
        isLoading: false,
        videoTitle: info.title,
        availableQualities: qualities,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'تعذر جلب الفيديو، تأكد من الرابط');
    }
  }

  Future<void> downloadVideo(String url, VideoQuality quality) async {
    state = state.copyWith(isLoading: true, progress: 0.0, isCompleted: false);

    try {
      final info = await _yt.getInfo(url);
      final dir = await getApplicationDocumentsDirectory();
      final safeTitle = info.title.replaceAll(RegExp(r'[^\w\s]+'), '');
      final outputPath = p.join(dir.path, '$safeTitle.mp4');

      final format = info.formats.forQuality(quality);
      if (format == null) {
        state = state.copyWith(isLoading: false, errorMessage: 'الجودة المطلوبة غير متوفرة');
        return;
      }

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