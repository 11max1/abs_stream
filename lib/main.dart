import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:clipboard/clipboard.dart';
import 'package:yt_downloader/yt_downloader.dart';
import 'theme.dart';
import 'download_service.dart';

void main() {
  runApp(const ProviderScope(child: AbsStreamApp()));
}

class AbsStreamApp extends StatelessWidget {
  const AbsStreamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AbsStream',
      theme: AppTheme.darkTheme,
      builder: (context, child) {
        return Directionality(textDirection: TextDirection.rtl, child: child!);
      },
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final TextEditingController _urlController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    // مراقبة حالة التحميل
    final state = ref.watch(downloadProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('AbsStream', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.green),
            ),
            child: const Center(child: Text('جاهز', style: TextStyle(color: Colors.green, fontSize: 12))),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // البطاقة العلوية (تصميم)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2A1E4A), Color(0xFF181824)],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  const Text('منزل الفيديوهات والصوتيات الذكي ✨', 
                    textAlign: TextAlign.center, 
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Text('انسخ رابط الفيديو وسيتكفل AbsStream بجلبه لك.', 
                    textAlign: TextAlign.center, 
                    style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                  const SizedBox(height: 15),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(FontAwesomeIcons.youtube, color: Colors.red, size: 20),
                      const SizedBox(width: 15),
                      const Icon(FontAwesomeIcons.tiktok, color: Colors.white, size: 20),
                      const SizedBox(width: 15),
                      const Icon(FontAwesomeIcons.instagram, color: Colors.pink, size: 20),
                    ],
                  )
                ],
              ),
            ),
            const SizedBox(height: 30),

            // حقل إدخال الرابط
            TextField(
              controller: _urlController,
              decoration: InputDecoration(
                hintText: 'www.youtube.com/watch?v=...',
                filled: true,
                fillColor: AppTheme.cardBg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.link, color: AppTheme.secondary),
                  onPressed: () async {
                    final data = await FlutterClipboard.paste();
                    _urlController.text = data;
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            // زر التحليل أو التحميل
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: state.isLoading 
                  ? null 
                  : () {
                      ref.read(downloadProvider.notifier).fetchInfo(_urlController.text);
                    },
                child: state.isLoading && state.progress == null
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('تحليل الرابط ⚡', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),

            const SizedBox(height: 20),

            // عرض الخطأ إن وجد
            if (state.errorMessage != null)
              Text(state.errorMessage!, style: const TextStyle(color: Colors.red)),

            // عرض نتائج التحليل والجودات
            if (state.videoTitle != null) ...[
              Text('الفيديو: ${state.videoTitle}', 
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), 
                textAlign: TextAlign.center),
              const SizedBox(height: 15),
              
              // عرض شريط التحميل أثناء التحميل
              if (state.progress != null)
                Column(
                  children: [
                    LinearProgressIndicator(value: state.progress, color: AppTheme.secondary, minHeight: 8),
                    const SizedBox(height: 10),
                    Text('جاري التحميل: ${(state.progress! * 100).toStringAsFixed(0)}%', 
                      style: const TextStyle(color: AppTheme.secondary)),
                  ],
                ),

              if (state.isCompleted)
                const Text('✅ تم التحميل بنجاح!', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),

              // عرض أزرار الجودات المتاحة
              if (!state.isLoading && !state.isCompleted && state.availableFormats != null)
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: state.availableFormats!.map((format) {
                    return ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.cardBg),
                      onPressed: () {
                        ref.read(downloadProvider.notifier).downloadVideo(_urlController.text, format);
                      },
                      child: Text(format.qualityLabel ?? 'جودة غير معروفة', style: const TextStyle(color: AppTheme.secondary)),
                    );
                  }).toList(),
                ),
            ],
          ],
        ),
      ),
    );
  }
}