import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:gal/gal.dart';

class DownloadState {
  final bool isLoading;
  final String? errorMessage;
  final String? videoTitle;
  final String? originalUrl;
  final String? directDownloadUrl;
  final List<VideoQuality>? availableQualities;
  final double? progress;
  final bool isCompleted;
  final String? platform;

  DownloadState({
    this.isLoading = false,
    this.errorMessage,
    this.videoTitle,
    this.originalUrl,
    this.directDownloadUrl,
    this.availableQualities,
    this.progress,
    this.isCompleted = false,
    this.platform,
  });

  DownloadState copyWith({
    bool? isLoading,
    String? errorMessage,
    String? videoTitle,
    String? originalUrl,
    String? directDownloadUrl,
    List<VideoQuality>? availableQualities,
    double? progress,
    bool? isCompleted,
    String? platform,
  }) {
    return DownloadState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      videoTitle: videoTitle ?? this.videoTitle,
      originalUrl: originalUrl ?? this.originalUrl,
      directDownloadUrl: directDownloadUrl ?? this.directDownloadUrl,
      availableQualities: availableQualities ?? this.availableQualities,
      progress: progress ?? this.progress,
      isCompleted: isCompleted ?? this.isCompleted,
      platform: platform ?? this.platform,
    );
  }
}

final downloadProvider = StateNotifierProvider<DownloadNotifier, DownloadState>((ref) {
  return DownloadNotifier();
});

class DownloadNotifier extends StateNotifier<DownloadState> {
  DownloadNotifier() : super(DownloadState());
  final YoutubeExplode _yt = YoutubeExplode();
  final Dio _dio = Dio();

  String _getPlatform(String url) {
    if (url.contains('youtu')) return 'youtube';
    if (url.contains('tiktok')) return 'tiktok';
    if (url.contains('instagram')) return 'instagram';
    if (url.contains('facebook') || url.contains('fb.watch')) return 'facebook';
    if (url.contains('twitter.com') || url.contains('x.com')) return 'twitter';
    return 'other';
  }

  Future<void> fetchInfo(String url) async {
    if (url.isEmpty) {
      state = state.copyWith(errorMessage: 'الرجاء إدخال رابط صحيح', isLoading: false);
      return;
    }
    state = DownloadState(isLoading: true, originalUrl: url);
    final platform = _getPlatform(url);

    try {
      if (platform == 'youtube') {
        await _fetchYoutubeInfo(url);
      } else if (platform == 'tiktok') {
        await _fetchTikTokInfo(url);
      } else {
        await _fetchCobaltInfo(url);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'تعذر جلب الفيديو: $e');
    }
  }

  Future<void> _fetchYoutubeInfo(String url) async {
    final video = await _yt.videos.get(url);
    final manifest = await _yt.videos.streamsClient.getManifest(url);
    
    final muxedStreams = manifest.muxed;
    final qualities = muxedStreams
        .map((e) => e.videoQuality)
        .whereType<VideoQuality>()
        .toSet()
        .toList();
    qualities.sort((a, b) => b.index.compareTo(a.index));

    state = state.copyWith(
      isLoading: false,
      videoTitle: video.title,
      availableQualities: qualities,
      platform: 'youtube',
    );
  }

  Future<void> _fetchTikTokInfo(String url) async {
    final response = await _dio.get(
      'https://www.tikwm.com/api/',
      queryParameters: {'url': url, 'hd': 1},
    );

    if (response.data['code'] == 0) {
      final data = response.data['data'];
      state = state.copyWith(
        isLoading: false,
        videoTitle: data['title'] ?? 'فيديو تيك توك',
        directDownloadUrl: data['play'],
        platform: 'tiktok',
      );
    } else {
      throw Exception('فشل جلب فيديو تيك توك');
    }
  }

  Future<void> _fetchCobaltInfo(String url) async {
    final response = await _dio.post(
      'https://api.cobalt.tools/',
      options: Options(headers: {'Accept': 'application/json', 'Content-Type': 'application/json'}),
      data: jsonEncode({'url': url}),
    );

    if (response.statusCode == 200 && response.data['status'] == 'stream') {
      state = state.copyWith(
        isLoading: false,
        videoTitle: 'فيديو من ${_getPlatform(url)}',
        directDownloadUrl: response.data['url'],
        platform: _getPlatform(url),
      );
    } else {
      throw Exception('المنصة غير مدعومة أو حدث خطأ في الخادم');
    }
  }

  Future<void> downloadMedia({VideoQuality? quality}) async {
    state = state.copyWith(isLoading: true, progress: 0.0, isCompleted: false);

    try {
      final dir = await getTemporaryDirectory();
      final safeTitle = (state.videoTitle ?? 'video').replaceAll(RegExp(r'[^\w\s]+'), '');
      final fileName = '${safeTitle}_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final tempFile = File(p.join(dir.path, fileName));

      if (state.platform == 'youtube') {
        if (quality == null) throw Exception('الرجاء اختيار الجودة');
        
        final manifest = await _yt.videos.streamsClient.getManifest(state.originalUrl!);
        
        final streamInfo = manifest.muxed.firstWhere(
          (e) => e.videoQuality == quality,
          orElse: () => manifest.muxed.first, 
        );

        final stream = _yt.videos.streamsClient.get(streamInfo);
        final fileSink = tempFile.openWrite();
        
        var receivedBytes = 0;
        final totalBytes = streamInfo.size.totalBytes;

        await for (final chunk in stream) {
          fileSink.add(chunk);
          receivedBytes += chunk.length;
          if (totalBytes > 0) {
            state = state.copyWith(progress: receivedBytes / totalBytes);
          }
        }
        await fileSink.close();
        
      } else {
        if (state.directDownloadUrl == null) throw Exception('لا يوجد رابط تحميل');
        
        await _dio.download(
          state.directDownloadUrl!,
          tempFile.path,
          onReceiveProgress: (received, total) {
            if (total != -1) {
              state = state.copyWith(progress: received / total);
            }
          },
        );
      }

      await Gal.putVideo(tempFile.path, album: 'AbsStream');
      
      if (await tempFile.exists()) {
        await tempFile.delete();
      }

      state = state.copyWith(isLoading: false, isCompleted: true, progress: 1.0);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'فشل التحميل: $e');
    }
  }
}