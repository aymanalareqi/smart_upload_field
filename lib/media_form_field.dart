import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart' as fp;
import 'package:image_picker/image_picker.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:dio/dio.dart' as dio;

/// Defines the type of content picked by the [MediaFormField].
enum MediaFieldType { image, file, youtubeUrl, url }

/// Represents the value of a [MediaFormField].
class MediaValue {
  final MediaFieldType type;
  final String value;
  final String? name;
  final File? file;
  final String? remoteId;
  final bool isUploading;
  final double progress;
  final String? error;

  MediaValue({
    required this.type,
    required this.value,
    this.name,
    this.file,
    this.remoteId,
    this.isUploading = false,
    this.progress = 0.0,
    this.error,
  });

  MediaValue copyWith({
    MediaFieldType? type,
    String? value,
    String? name,
    File? file,
    String? remoteId,
    bool? isUploading,
    double? progress,
    String? error,
  }) {
    return MediaValue(
      type: type ?? this.type,
      value: value ?? this.value,
      name: name ?? this.name,
      file: file ?? this.file,
      remoteId: remoteId ?? this.remoteId,
      isUploading: isUploading ?? this.isUploading,
      progress: progress ?? this.progress,
      error: error ?? this.error,
    );
  }

  @override
  String toString() =>
      'MediaValue(type: $type, value: $value, name: $name, remoteId: $remoteId, isUploading: $isUploading)';
}

/// A premium, all-in-one form field for picking images, files, or URLs.
class MediaFormField extends FormField<List<MediaValue>> {
  final String? label;
  final String? hint;
  final bool multiple;
  final int? minItems;
  final int? maxItems;
  final ValueChanged<List<MediaValue>>? onChanged;
  final Color? primaryColor;
  final bool autoUpload;
  final String? uploadUrl;
  final Map<String, String>? headers;
  final void Function(MediaValue)? onUploadSuccess;
  final void Function(String)? onUploadError;

  MediaFormField({
    super.key,
    this.label,
    this.hint,
    this.multiple = false,
    this.minItems,
    this.maxItems,
    this.onChanged,
    this.primaryColor,
    this.autoUpload = false,
    this.uploadUrl,
    this.headers,
    this.onUploadSuccess,
    this.onUploadError,
    List<MediaValue>? initialValue,
    super.onSaved,
    FormFieldValidator<List<MediaValue>>? validator,
    super.enabled = true,
    super.autovalidateMode = AutovalidateMode.onUserInteraction,
  }) : super(
         initialValue: initialValue ?? [],
         validator: (value) {
           if (validator != null) {
             return validator(value);
           }
           if (multiple &&
               minItems != null &&
               (value?.length ?? 0) < minItems) {
             return 'Select at least $minItems items';
           }
           if (multiple &&
               maxItems != null &&
               (value?.length ?? 0) > maxItems) {
             return 'Select at most $maxItems items';
           }
           return null;
         },
         builder: (FormFieldState<List<MediaValue>> state) {
           final context = state.context;
           final theme = Theme.of(context);
           final effectivePrimaryColor = primaryColor ?? theme.primaryColor;
           final hasError = state.hasError;

           return Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               if (label != null) ...[
                 Text(
                   label,
                   style: theme.textTheme.titleSmall?.copyWith(
                     fontWeight: FontWeight.bold,
                     color: hasError
                         ? theme.colorScheme.error
                         : theme.textTheme.titleSmall?.color,
                   ),
                 ),
                 const SizedBox(height: 8),
               ],
               _MediaFormFieldInternal(
                 values: state.value ?? [],
                 hint: hint,
                 multiple: multiple,
                 minItems: minItems,
                 maxItems: maxItems,
                 primaryColor: effectivePrimaryColor,
                 hasError: hasError,
                 enabled: enabled,
                 autoUpload: autoUpload,
                 uploadUrl: uploadUrl,
                 headers: headers,
                 onUploadSuccess: onUploadSuccess,
                 onUploadError: onUploadError,
                 onChanged: (val) {
                   state.didChange(val);
                   onChanged?.call(val);
                 },
               ),
               if (hasError) ...[
                 const SizedBox(height: 6),
                 Padding(
                   padding: const EdgeInsets.only(left: 12),
                   child: Text(
                     state.errorText!,
                     style: theme.textTheme.bodySmall?.copyWith(
                       color: theme.colorScheme.error,
                     ),
                   ),
                 ),
               ],
             ],
           );
         },
       );
}

class _MediaFormFieldInternal extends StatefulWidget {
  final List<MediaValue> values;
  final String? hint;
  final bool multiple;
  final int? minItems;
  final int? maxItems;
  final Color primaryColor;
  final bool hasError;
  final bool enabled;
  final ValueChanged<List<MediaValue>> onChanged;
  final bool autoUpload;
  final String? uploadUrl;
  final Map<String, String>? headers;
  final void Function(MediaValue)? onUploadSuccess;
  final void Function(String)? onUploadError;

  const _MediaFormFieldInternal({
    required this.values,
    this.hint,
    required this.multiple,
    this.minItems,
    this.maxItems,
    required this.primaryColor,
    required this.hasError,
    required this.enabled,
    required this.onChanged,
    this.autoUpload = false,
    this.uploadUrl,
    this.headers,
    this.onUploadSuccess,
    this.onUploadError,
  });

  @override
  State<_MediaFormFieldInternal> createState() =>
      _MediaFormFieldInternalState();
}

class _MediaFormFieldInternalState extends State<_MediaFormFieldInternal>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  /// Local copy of values — allows setState for fast progress redraws
  /// without waiting for the full FormField → MediaFormField rebuild chain.
  late List<MediaValue> _values;

  @override
  void initState() {
    super.initState();
    _values = List.from(widget.values);
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(_MediaFormFieldInternal oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync local values when the parent pushes new values (e.g. after removal),
    // but only if we're not mid-upload (otherwise we'd overwrite progress).
    final anyUploading = _values.any((v) => v.isUploading);
    if (!anyUploading) {
      _values = List.from(widget.values);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _uploadFile(MediaValue value) async {
    if (widget.uploadUrl == null || value.file == null) return;

    // Mark as uploading with 0 progress
    _updateValue(
      value,
      value.copyWith(isUploading: true, progress: 0.0, error: null),
    );

    try {
      final dioClient = dio.Dio();

      final headers = <String, dynamic>{'Accept': 'application/json'};
      if (widget.headers != null) {
        headers.addAll(widget.headers!);
      }

      final formData = dio.FormData.fromMap({
        'file': await dio.MultipartFile.fromFile(
          value.file!.path,
          filename: value.name ?? p.basename(value.file!.path),
        ),
      });

      final response = await dioClient.post(
        widget.uploadUrl!,
        data: formData,
        options: dio.Options(headers: headers),
        onSendProgress: (sent, total) {
          if (total > 0) {
            final progress = sent / total;
            // Read the current value from widget.values so we always mutate the latest copy
            final current = _values.firstWhere(
              (v) => v.value == value.value && v.file?.path == value.file?.path,
              orElse: () => value,
            );
            _updateValue(current, current.copyWith(progress: progress));
          }
        },
      );

      final remoteId = response.data['uuid'];
      final current = _values.firstWhere(
        (v) => v.value == value.value && v.file?.path == value.file?.path,
        orElse: () => value,
      );
      final updatedValue = current.copyWith(
        isUploading: false,
        progress: 1.0,
        remoteId: remoteId,
      );
      _updateValue(current, updatedValue);
      widget.onUploadSuccess?.call(updatedValue);
    } on dio.DioException catch (e) {
      final msg = e.response?.data?.toString() ?? e.message ?? e.toString();
      final current = _values.firstWhere(
        (v) => v.value == value.value && v.file?.path == value.file?.path,
        orElse: () => value,
      );
      _updateValue(
        current,
        current.copyWith(isUploading: false, progress: 0.0, error: msg),
      );
      widget.onUploadError?.call(msg);
    } catch (e) {
      final current = _values.firstWhere(
        (v) => v.value == value.value && v.file?.path == value.file?.path,
        orElse: () => value,
      );
      _updateValue(
        current,
        current.copyWith(
          isUploading: false,
          progress: 0.0,
          error: e.toString(),
        ),
      );
      widget.onUploadError?.call(e.toString());
    }
  }

  void _updateValue(MediaValue oldVal, MediaValue newVal) {
    // 1. Update local state immediately for smooth progress redraws.
    setState(() {
      final localIdx = _values.indexWhere(
        (v) => v.value == oldVal.value && v.file?.path == oldVal.file?.path,
      );
      if (localIdx != -1) _values[localIdx] = newVal;
    });

    // 2. Propagate to the parent FormField so the form value is also updated.
    final newValues = [..._values];
    widget.onChanged(newValues);
  }

  void _handleTap() async {
    if (!widget.enabled) return;
    if (widget.maxItems != null && _values.length >= widget.maxItems!) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Maximum of ${widget.maxItems} items allowed')),
      );
      return;
    }

    _animationController.forward().then((_) => _animationController.reverse());

    final results = await showModalBottomSheet<List<MediaValue>>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _PickerSheet(
        primaryColor: widget.primaryColor,
        multiple: widget.multiple,
      ),
    );

    if (results != null && results.isNotEmpty) {
      List<MediaValue> finalResults = results;
      if (widget.multiple) {
        final newValues = [..._values, ...results];
        if (widget.maxItems != null && newValues.length > widget.maxItems!) {
          finalResults = results
              .take(widget.maxItems! - _values.length)
              .toList();
        }
        setState(() {
          _values = [..._values, ...finalResults];
        });
      } else {
        finalResults = [results.first];
        setState(() {
          _values = finalResults;
        });
      }
      // Notify parent
      widget.onChanged([..._values]);

      if (widget.autoUpload) {
        for (var val in finalResults) {
          if (val.file != null) {
            _uploadFile(val);
          }
        }
      }
    }
  }

  void _removeItem(int index) {
    setState(() {
      _values = [..._values]..removeAt(index);
    });
    widget.onChanged([..._values]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (widget.multiple && _values.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _values.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              return _buildItemCard(_values[index], index, isDark);
            },
          ),
          const SizedBox(height: 12),
          if (widget.maxItems == null || _values.length < widget.maxItems!)
            _buildAddMoreButton(isDark),
        ],
      );
    }

    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: widget.hasError
                ? theme.colorScheme.error
                : (isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.1)),
            width: 1.5,
          ),
          boxShadow: [
            if (!widget.hasError)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _handleTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: _values.isEmpty
                      ? _buildPlaceholder()
                      : _buildSingleValuePreview(_values.first),
                ),
                if (_values.isNotEmpty && widget.enabled)
                  IconButton(
                    onPressed: () => _removeItem(0),
                    icon: const Icon(Icons.close_rounded, size: 20),
                    visualDensity: VisualDensity.compact,
                    color: theme.hintColor,
                  )
                else if (widget.enabled)
                  Icon(
                    Icons.add_circle_outline_rounded,
                    color: widget.primaryColor,
                    size: 24,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItemCard(MediaValue val, int index, bool isDark) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.1),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: _buildLeadingIcon(val),
        title: Text(
          val.name ?? val.value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _getTypeLabel(val.type),
              style: theme.textTheme.labelSmall?.copyWith(
                color: widget.primaryColor,
              ),
            ),
            if (val.isUploading)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LinearProgressIndicator(value: val.progress, minHeight: 3),
                    const SizedBox(height: 2),
                    Text(
                      '${(val.progress * 100).toStringAsFixed(0)}%',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: widget.primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            if (val.error != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Error: ${val.error}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            if (val.remoteId != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  'ID: ${val.remoteId}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        trailing: widget.enabled
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (val.error != null)
                    IconButton(
                      icon: Icon(
                        Icons.refresh_rounded,
                        color: widget.primaryColor,
                        size: 20,
                      ),
                      onPressed: () => _uploadFile(val),
                    ),
                  IconButton(
                    icon: const Icon(
                      Icons.remove_circle_outline_rounded,
                      color: Colors.redAccent,
                      size: 20,
                    ),
                    onPressed: () => _removeItem(index),
                  ),
                ],
              )
            : null,
      ),
    );
  }

  Widget _buildAddMoreButton(bool isDark) {
    return InkWell(
      onTap: _handleTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: widget.primaryColor.withValues(alpha: 0.3),
            style: BorderStyle.solid,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_rounded, color: widget.primaryColor, size: 20),
            const SizedBox(width: 8),
            Text(
              'Add More',
              style: TextStyle(
                color: widget.primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Row(
      children: [
        Icon(
          Icons.cloud_upload_outlined,
          color: Theme.of(context).hintColor.withValues(alpha: 0.5),
          size: 24,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            widget.hint ??
                (widget.multiple
                    ? 'Tap to upload multiple items'
                    : 'Tap to pick image, file or URL'),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).hintColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildSingleValuePreview(MediaValue val) {
    final theme = Theme.of(context);
    return Row(
      children: [
        _buildLeadingIcon(val),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _getTypeLabel(val.type),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: widget.primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                val.name ?? val.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (val.isUploading)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LinearProgressIndicator(
                        value: val.progress,
                        minHeight: 3,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${(val.progress * 100).toStringAsFixed(0)}%',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: widget.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              if (val.remoteId != null)
                Text(
                  'Uploaded',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLeadingIcon(MediaValue val) {
    dynamic icon;
    Color iconColor;

    switch (val.type) {
      case MediaFieldType.image:
        icon = Icons.image_rounded;
        iconColor = Colors.blue;
        break;
      case MediaFieldType.file:
        icon = Icons.insert_drive_file_rounded;
        iconColor = Colors.orange;
        break;
      case MediaFieldType.youtubeUrl:
        icon = FontAwesomeIcons.youtube;
        iconColor = Colors.red;
        break;
      case MediaFieldType.url:
        icon = Icons.link_rounded;
        iconColor = Colors.teal;
        break;
    }

    if (val.type == MediaFieldType.image && val.file != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          val.file!,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              _buildIconContainer(icon, iconColor),
        ),
      );
    }
    return _buildIconContainer(icon, iconColor);
  }

  Widget _buildIconContainer(dynamic icon, Color color) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: icon is IconData
            ? Icon(icon, color: color, size: 20)
            : FaIcon(icon, color: color, size: 20),
      ),
    );
  }

  String _getTypeLabel(MediaFieldType type) {
    switch (type) {
      case MediaFieldType.image:
        return 'IMAGE';
      case MediaFieldType.file:
        return 'FILE';
      case MediaFieldType.youtubeUrl:
        return 'YOUTUBE';
      case MediaFieldType.url:
        return 'URL';
    }
  }
}

class _PickerSheet extends StatelessWidget {
  final Color primaryColor;
  final bool multiple;

  const _PickerSheet({required this.primaryColor, required this.multiple});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.dividerColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Upload Content',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select the type of content you want to upload',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
          ),
          const SizedBox(height: 32),
          _buildOptionGrid(context),
        ],
      ),
    );
  }

  Widget _buildOptionGrid(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      crossAxisCount: 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _PickerOption(
          icon: Icons.image_rounded,
          label: 'Image',
          color: Colors.blue,
          onTap: () => _pickImage(context),
        ),
        _PickerOption(
          icon: Icons.insert_drive_file_rounded,
          label: 'File',
          color: Colors.orange,
          onTap: () => _pickFile(context),
        ),
        _PickerOption(
          icon: FontAwesomeIcons.youtube,
          label: 'YouTube',
          color: Colors.red,
          onTap: () => _pickUrl(context, isYoutube: true),
        ),
        _PickerOption(
          icon: Icons.link_rounded,
          label: 'URL',
          color: Colors.teal,
          onTap: () => _pickUrl(context, isYoutube: false),
        ),
      ],
    );
  }

  void _pickImage(BuildContext context) async {
    final picker = ImagePicker();
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pick Image Source'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pop(context, ImageSource.camera),
            icon: const Icon(Icons.camera_alt_rounded),
            label: const Text('Camera'),
          ),
          TextButton.icon(
            onPressed: () => Navigator.pop(context, ImageSource.gallery),
            icon: const Icon(Icons.photo_library_rounded),
            label: const Text('Gallery'),
          ),
        ],
      ),
    );

    if (source != null) {
      if (source == ImageSource.gallery && multiple) {
        final images = await picker.pickMultiImage();
        if (!context.mounted) return;
        if (images.isNotEmpty) {
          Navigator.pop(
            context,
            images
                .map(
                  (image) => MediaValue(
                    type: MediaFieldType.image,
                    value: image.path,
                    name: p.basename(image.path),
                    file: File(image.path),
                  ),
                )
                .toList(),
          );
        }
      } else {
        final image = await picker.pickImage(source: source);
        if (!context.mounted) return;
        if (image != null) {
          Navigator.pop(context, [
            MediaValue(
              type: MediaFieldType.image,
              value: image.path,
              name: p.basename(image.path),
              file: File(image.path),
            ),
          ]);
        }
      }
    }
  }

  void _pickFile(BuildContext context) async {
    final result = await fp.FilePicker.pickFiles(allowMultiple: multiple);
    if (!context.mounted) return;
    if (result != null && result.files.isNotEmpty) {
      Navigator.pop(
        context,
        result.files
            .where((f) => f.path != null)
            .map(
              (file) => MediaValue(
                type: MediaFieldType.file,
                value: file.path!,
                name: file.name,
                file: File(file.path!),
              ),
            )
            .toList(),
      );
    }
  }

  void _pickUrl(BuildContext context, {required bool isYoutube}) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final url = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isYoutube ? 'Enter YouTube URL' : 'Enter URL'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: isYoutube
                  ? 'https://youtube.com/watch?v=...'
                  : 'https://example.com',
              prefixIcon: Padding(
                padding: const EdgeInsets.all(12.0),
                child: isYoutube
                    ? const FaIcon(FontAwesomeIcons.youtube, size: 20)
                    : const Icon(Icons.link_rounded, size: 20),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Please enter a URL';
              if (!Uri.parse(value).isAbsolute) {
                return 'Please enter a valid URL';
              }
              if (isYoutube &&
                  !value.contains('youtube.com') &&
                  !value.contains('youtu.be')) {
                return 'Please enter a valid YouTube URL';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(context, controller.text);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (!context.mounted) return;
    if (url != null) {
      Navigator.pop(context, [
        MediaValue(
          type: isYoutube ? MediaFieldType.youtubeUrl : MediaFieldType.url,
          value: url,
          name: url,
        ),
      ]);
    }
  }
}

class _PickerOption extends StatelessWidget {
  final dynamic icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _PickerOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.1 : 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon is IconData
                ? Icon(icon, color: color, size: 28)
                : FaIcon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
