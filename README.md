# Media Form Field

A premium, all-in-one Flutter form field for picking images, files, or capturing URLs (including YouTube support). 

This package provides a unified UI for various media types, making it easy to integrate file selection and URL inputs into your Flutter forms.

## Features

- **Unified Interface**: Pick images, files, or enter URLs from a single component.
- **Multiple Selection**: Support for selecting multiple items with `minItems` and `maxItems` constraints.
- **Premium UI**: Modern design with glassmorphism effects, smooth animations, and tailored color palettes.
- **Form Integration**: Built as a `FormField`, it integrates seamlessly with Flutter's `Form` widget and validation logic.
- **Platform Support**: Optimized for mobile (iOS/Android) using `image_picker` and `file_picker`.

## Usage

```dart
MediaFormField(
  label: 'Upload Media',
  hint: 'Pick an image, file or enter a URL',
  multiple: true,
  maxItems: 5,
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

## Additional information

This package is a rename of the original `SmartUploadField` to better reflect its purpose as a comprehensive media form component.
