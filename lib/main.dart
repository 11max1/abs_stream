import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:clipboard/clipboard.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart'; // ضروري لقراءة نوع الجودة
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
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(downloadProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('AbsStream',
            style: TextStyle(fontWeight: FontWeight.bold)),
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
            child: const Center(
                child: Text('جاهز',
                    style: TextStyle(color: Colors.green, fontSize: 12))),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // البطاقة العلوية
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
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Text('انسخ رابط الفيديو وسيتكفل AbsStream بجلبه لك.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                  const SizedBox(height: 15),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FaIcon(FontAwesomeIcons.youtube,
                          color: Colors.red, size: 20),
                      SizedBox(width: 15),
                      FaIcon(FontAwesomeIcons.tiktok,
                          color: Colors.white, size: 20),
                      SizedBox(width: 15),
                      FaIcon(FontAwesomeIcons.instagram,
                          color: Colors.pink, size: 20),
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
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
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

            // زر التحليل
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
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
              
              // شريط التحميل
              if (state.progress != null && !state.isCompleted)
                Column(
                  children: [
                    LinearProgressIndicator(value: state.progress, color: AppTheme.secondary, minHeight: 8),
                    const SizedBox(height: 10),
                    Text('جاري التحميل: ${(state.progress! * 100).toStringAsFixed(0)}%', 
                      style: const TextStyle(color: AppTheme.secondary)),
                  ],
                ),

              // رسالة النجاح
              if (state.isCompleted)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Text('✅ تم الحفظ في الاستوديو بنجاح!', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                ),

              // ----------------------------------------------------
              // تعديل هام: التفرقة بين يوتيوب (جودات) وباقي المنصات (زر واحد)
              // ----------------------------------------------------
              if (!state.isLoading && !state.isCompleted) ...[
                
                // 1. يوتيوب: عرض أزرار الجودات
                if (state.availableQualities != null && state.availableQualities!.isNotEmpty)
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    alignment: WrapAlignment.center,
                    children: state.availableQualities!.map((quality) {
                      return ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.cardBg),
                        onPressed: () {
                          // تم تعديل اسم الدالة إلى downloadMedia
                          ref.read(downloadProvider.notifier).downloadMedia(quality: quality);
                        },
                        child: Text(quality.name, style: const TextStyle(color: AppTheme.secondary)),
                      );
                    }).toList(),
                  )
                
                // 2. المنصات الأخرى (تيك توك/إنستغرام): عرض زر تحميل مباشر
                else if (state.directDownloadUrl != null)
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.secondary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        ref.read(downloadProvider.notifier).downloadMedia();
                      },
                      icon: const Icon(Icons.download, color: Colors.black),
                      label: const Text('تحميل الفيديو الآن', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                    ),
                  ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}