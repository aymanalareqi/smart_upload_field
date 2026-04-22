# Smart Upload Field (MediaFormField)

A premium, all-in-one Flutter form field for picking images, files, or capturing URLs (including YouTube support), with built-in auto-uploading to backend servers (e.g., Laravel) and comprehensive localization support.

This package provides a unified UI for various media types, making it easy to integrate file selection, URL inputs, and progress-tracking uploads into your Flutter forms.

## Features

- **Unified Interface**: Pick images, videos, files, or enter URLs (YouTube or generic) from a single beautiful component.
- **Auto-Upload & Progress Tracking**: Built-in support for uploading files to a remote server (like Laravel) immediately upon selection, complete with real-time progress bars and error handling using `Dio`.
- **Multiple Selection**: Support for selecting multiple items with `minItems` and `maxItems` constraints.
- **Grid or List Views**: Display selected media as a sleek horizontal list or a responsive grid view.
- **Full Localization Support**: Customize every single text, label, and validation message via `MediaFormFieldTranslations`.
- **Form Integration**: Built as a `FormField`, integrating seamlessly with Flutter's `Form` widget and validation logic.
- **Upload State Synchronization**: Exposes `onUploadingStateChanged` to let you disable form submit buttons while background uploads are processing.
- **Premium UI**: Modern design with glassmorphism effects, smooth animations, and tailored color palettes.

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  smart_media_form_field: ^1.0.0
```

## Setup

Because this package uses `image_picker` and `file_picker` under the hood, you need to configure your native platforms.

### iOS
Add the following keys to your `ios/Runner/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>We need access to your camera to upload photos.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>We need access to your photo library to select photos.</string>
```

### Android
No specific setup is strictly required for modern Android versions, but ensure you have internet permissions if you intend to use the Auto-Upload feature:

```xml
<uses-permission android:name="android.permission.INTERNET" />
```

## Usage

### 1. Basic Single Upload (Restricted Types)

You can restrict the picker to only allow certain media types (e.g., only images and files, no URLs):

```dart
import 'package:smart_media_form_field/media_form_field.dart';

MediaFormField(
  label: 'Image or File Only',
  hint: 'Pick an image or a file',
  multiple: false,
  allowedTypes: const [MediaFieldType.image, MediaFieldType.file],
  onChanged: (values) {
    print('Selected media: ${values.first.value}');
  },
)
```

### 2. Multiple Uploads in a Grid View

```dart
MediaFormField(
  label: 'Multiple Uploads (Max 5)',
  hint: 'Attach multiple items',
  multiple: true,
  maxItems: 5,
  viewType: MediaFieldViewType.grid, // Displays selected items in a grid
  onChanged: (values) {
    print('Selected ${values.length} items');
  },
  validator: (values) {
    if (values == null || values.isEmpty) {
      return 'Please select at least one item';
    }
    return null;
  },
)
```

### 3. Auto-Uploading to Backend (e.g., Laravel)

The field can automatically upload picked files to your server and replace the local file reference with the remote UUID/URL.

```dart
MediaFormField(
  label: 'Laravel Integration (Auto-Upload)',
  hint: 'Files will be uploaded immediately',
  multiple: true,
  autoUpload: true,
  uploadUrl: 'https://your-laravel-app.com/api/upload-file',
  
  // You can pass headers (e.g., Authorization)
  uploadHeaders: {
    'Authorization': 'Bearer YOUR_TOKEN',
  },
  
  // Track when uploads start and finish to disable your Submit button
  onUploadingStateChanged: (isUploading) {
    setState(() {
      _isSubmitButtonDisabled = isUploading;
    });
  },
  
  // Callbacks for success/failure
  onUploadSuccess: (value) {
    print('File uploaded! Remote UUID: ${value.remoteId}');
  },
  onUploadError: (error) {
    print('Upload failed: $error');
  },
)
```

### 4. Localization / Custom Text

You can translate every single string inside the widget by passing a `MediaFormFieldTranslations` object. Here is an example in Arabic:

```dart
MediaFormField(
  multiple: true,
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
  onChanged: (values) {},
)
```

## Extracting the Results

When a user submits your form, the `MediaFormField` returns a `List<MediaValue>`.
The `MediaValue` class provides useful getters to know exactly what the user picked:

```dart
for (var media in values) {
  if (media.type == MediaFieldType.image) {
    print('Local File Path: ${media.value}');
    print('Remote Upload ID: ${media.remoteId}'); // If autoUpload was used
  } else if (media.type == MediaFieldType.youtubeUrl) {
    print('YouTube URL: ${media.value}');
  }
}
```

## Customization Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `label` | `String` | The main label displayed above the field. |
| `hint` | `String` | The placeholder text inside the field. |
| `multiple` | `bool` | Whether the user can select multiple files/links. |
| `maxItems` | `int?` | Maximum allowed items (only applicable if `multiple: true`). |
| `viewType` | `MediaFieldViewType` | Display picked items in a `list` or a `grid`. |
| `allowedTypes` | `List<MediaFieldType>` | Restrict the options shown in the picker (e.g., only images/files). |
| `autoUpload` | `bool` | Automatically uploads files to the server after picking. |
| `uploadUrl` | `String?` | The API endpoint for file uploads. Required if `autoUpload` is true. |
| `uploadHeaders` | `Map<String, String>?` | HTTP headers sent with the upload request. |
| `primaryColor` | `Color` | Main color used for buttons, borders, and icons. |
| `translations` | `MediaFormFieldTranslations` | Object to override all hardcoded text strings for localization. |
| `onUploadingStateChanged` | `Function(bool)` | Fired when any file starts or finishes uploading. |

## License

MIT License.
