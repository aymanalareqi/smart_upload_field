import 'dart:io';
import 'package:flutter/material.dart';
import 'package:smart_media_form_field/media_form_field.dart';

/// Bypass SSL certificate verification for development.
/// [WARNING] Do not use this in production apps.
class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

void main() {
  // Use overrides to allow self-signed or incomplete certificate chains during testing.
  HttpOverrides.global = MyHttpOverrides();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Media Form Field Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final _formKey = GlobalKey<FormState>();
  List<MediaValue> _mediaValues = [];
  bool _isUploading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Media Form Field'),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Modern Upload Experience',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'A single field to handle all your upload needs: images, files, or links.',
                style: TextStyle(color: Theme.of(context).hintColor),
              ),
              const SizedBox(height: 40),
              MediaFormField(
                label: 'Single Upload',
                hint: 'Pick an image, file or enter a URL',
                multiple: false,
                onChanged: (values) {
                  setState(() {
                    _mediaValues = values;
                  });
                },
                validator: (values) {
                  if (values == null || values.isEmpty) {
                    return 'Please select or enter something';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              MediaFormField(
                label: 'Multiple Uploads (Max 5)',
                hint: 'ارفاق عدة ملفات',
                multiple: true,
                maxItems: 5,
                viewType: MediaFieldViewType.grid,
                translations: const MediaFormFieldTranslations(
                  uploadContent: 'رفع المحتوى',
                  selectContentType: 'اختر نوع المحتوى الذي تريد رفعه',
                  image: 'صورة',
                  file: 'ملف',
                  youtube: 'يوتيوب',
                  url: 'رابط',
                  pickImageSource: 'اختر مصدر الصورة',
                  camera: 'الكاميرا',
                  gallery: 'المعرض',
                  enterYoutubeUrl: 'أدخل رابط يوتيوب',
                  enterUrl: 'أدخل الرابط',
                  pleaseEnterUrl: 'الرجاء إدخال الرابط',
                  pleaseEnterValidUrl: 'الرجاء إدخال رابط صحيح',
                  pleaseEnterValidYoutubeUrl: 'الرجاء إدخال رابط يوتيوب صحيح',
                  cancel: 'إلغاء',
                  add: 'إضافة',
                  addMore: 'إضافة المزيد',
                  uploaded: 'تم الرفع',
                  errorPrefix: 'خطأ',
                  tapToUploadMultiple: 'اضغط لرفع عدة ملفات',
                  tapToPick: 'اضغط لاختيار صورة، ملف أو رابط',
                ),
                onChanged: (values) {
                  print('Selected: ${values.length} items');
                },
              ),
              const SizedBox(height: 24),
              MediaFormField(
                label: 'Laravel Integration (Auto-Upload)',
                hint: 'Files will be uploaded immediately to Laravel backend',
                multiple: true,
                autoUpload: true,
                viewType: MediaFieldViewType.grid,
                // Replace with your actual Laravel API endpoint
                uploadUrl: 'https://app.rawdaljinan.com/api/upload-file',
                onUploadSuccess: (value) {
                  print(
                    'File uploaded successfully! Remote UUID: ${value.remoteId}',
                  );
                },
                onUploadingStateChanged: (isUploading) {
                  setState(() {
                    _isUploading = isUploading;
                  });
                },
                onUploadError: (error) {
                  print('Upload failed: $error');
                },
              ),
              const SizedBox(height: 40),
              if (_mediaValues.isNotEmpty) ...[
                const Text(
                  'Last Selection:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _mediaValues
                        .map((v) => Text(v.toString()))
                        .toList(),
                  ),
                ),
                const SizedBox(height: 24),
              ],
              ElevatedButton(
                onPressed: _isUploading
                    ? null
                    : () {
                        if (_formKey.currentState!.validate()) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Form Validated!')),
                          );
                        }
                      },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(_isUploading ? 'Uploading...' : 'Submit Form'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
