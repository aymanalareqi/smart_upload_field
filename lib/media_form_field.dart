import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart' as fp;
import 'package:image_picker/image_picker.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:dio/dio.dart' as dio;

/// Defines the type of content picked by the [MediaFormField].
enum MediaFieldType { image, file, youtubeUrl, url, video }

/// Defines the layout style for displaying picked media.
enum MediaFieldViewType { list, grid }

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

/// Translations for all text in [MediaFormField].
class MediaFormFieldTranslations {
  final String uploadContent;
  final String selectContentType;
  final String image;
  final String file;
  final String video;
  final String youtube;
  final String url;
  final String pickImageSource;
  final String pickVideoSource;
  final String camera;
  final String gallery;
  final String enterYoutubeUrl;
  final String enterUrl;
  final String pleaseEnterUrl;
  final String pleaseEnterValidUrl;
  final String pleaseEnterValidYoutubeUrl;
  final String cancel;
  final String add;
  final String addMore;
  final String uploaded;
  final String errorPrefix;
  final String tapToUploadMultiple;
  final String tapToPick;
  final String Function(int)? selectAtLeastItems;
  final String Function(int)? selectAtMostItems;
  final String Function(int)? maximumItemsAllowed;

  const MediaFormFieldTranslations({
    this.uploadContent = 'Upload Content',
    this.selectContentType = 'Select the type of content you want to upload',
    this.image = 'Image',
    this.file = 'File',
    this.video = 'Video',
    this.youtube = 'YouTube',
    this.url = 'URL',
    this.pickImageSource = 'Pick Image Source',
    this.pickVideoSource = 'Pick Video Source',
    this.camera = 'Camera',
    this.gallery = 'Gallery',
    this.enterYoutubeUrl = 'Enter YouTube URL',
    this.enterUrl = 'Enter URL',
    this.pleaseEnterUrl = 'Please enter a URL',
    this.pleaseEnterValidUrl = 'Please enter a valid URL',
    this.pleaseEnterValidYoutubeUrl = 'Please enter a valid YouTube URL',
    this.cancel = 'Cancel',
    this.add = 'Add',
    this.addMore = 'Add More',
    this.uploaded = 'Uploaded',
    this.errorPrefix = 'Error',
    this.tapToUploadMultiple = 'Tap to upload multiple items',
    this.tapToPick = 'Tap to pick image, file or URL',
    this.selectAtLeastItems,
    this.selectAtMostItems,
    this.maximumItemsAllowed,
  });

  String getSelectAtLeastItems(int count) =>
      selectAtLeastItems?.call(count) ?? 'Select at least $count items';
  String getSelectAtMostItems(int count) =>
      selectAtMostItems?.call(count) ?? 'Select at most $count items';
  String getMaximumItemsAllowed(int count) =>
      maximumItemsAllowed?.call(count) ?? 'Maximum of $count items allowed';
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
  final void Function(bool isUploading)? onUploadingStateChanged;
  final MediaFormFieldTranslations translations;
  final MediaFieldViewType viewType;
  final List<MediaFieldType> allowedTypes;

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
    this.onUploadingStateChanged,
    this.translations = const MediaFormFieldTranslations(),
    this.viewType = MediaFieldViewType.list,
    this.allowedTypes = MediaFieldType.values,
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
             return translations.getSelectAtLeastItems(minItems);
           }
           if (multiple &&
               maxItems != null &&
               (value?.length ?? 0) > maxItems) {
             return translations.getSelectAtMostItems(maxItems);
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
                 onUploadingStateChanged: onUploadingStateChanged,
                 translations: translations,
                 viewType: viewType,
                 allowedTypes: allowedTypes,
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
  final void Function(bool isUploading)? onUploadingStateChanged;
  final MediaFormFieldTranslations translations;
  final MediaFieldViewType viewType;
  final List<MediaFieldType> allowedTypes;

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
    this.onUploadingStateChanged,
    required this.translations,
    required this.viewType,
    required this.allowedTypes,
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
    final wasUploading = _values.any((v) => v.isUploading);

    // 1. Update local state immediately for smooth progress redraws.
    setState(() {
      final localIdx = _values.indexWhere(
        (v) => v.value == oldVal.value && v.file?.path == oldVal.file?.path,
      );
      if (localIdx != -1) _values[localIdx] = newVal;
    });

    final isUploadingNow = _values.any((v) => v.isUploading);
    if (wasUploading != isUploadingNow) {
      widget.onUploadingStateChanged?.call(isUploadingNow);
    }

    // 2. Propagate to the parent FormField so the form value is also updated.
    final newValues = [..._values];
    widget.onChanged(newValues);
  }

  void _handleTap() async {
    if (!widget.enabled) return;
    if (widget.maxItems != null && _values.length >= widget.maxItems!) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.translations.getMaximumItemsAllowed(widget.maxItems!),
          ),
        ),
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
        translations: widget.translations,
        allowedTypes: widget.allowedTypes,
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
          if (widget.viewType == MediaFieldViewType.grid)
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _values.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1,
              ),
              itemBuilder: (context, index) {
                return _buildGridItemCard(_values[index], index, isDark);
              },
            )
          else
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
                  '${widget.translations.errorPrefix}: ${val.error}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            if (val.remoteId != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      color: Colors.green,
                      size: 14,
                    ),
                    SizedBox(width: 4),
                    Text(
                      widget.translations.uploaded,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
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
              widget.translations.addMore,
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
                    ? widget.translations.tapToUploadMultiple
                    : widget.translations.tapToPick),
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
                Row(
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      color: Colors.green,
                      size: 14,
                    ),
                    SizedBox(width: 4),
                    Text(
                      widget.translations.uploaded,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGridItemCard(MediaValue val, int index, bool isDark) {
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
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Center(child: _buildLeadingIcon(val, isGrid: true)),
                ),
                const SizedBox(height: 8),
                Text(
                  val.name ?? val.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                if (val.isUploading)
                  Column(
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
                          fontSize: 10,
                        ),
                      ),
                    ],
                  )
                else if (val.error != null)
                  Text(
                    '${widget.translations.errorPrefix}: ${val.error}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.error,
                      fontSize: 10,
                    ),
                  )
                else if (val.remoteId != null)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        color: Colors.green,
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        widget.translations.uploaded,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.green,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  )
                else
                  Text(
                    _getTypeLabel(val.type),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: widget.primaryColor,
                      fontSize: 10,
                    ),
                  ),
              ],
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: widget.enabled
                ? IconButton(
                    onPressed: () => _removeItem(index),
                    icon: const Icon(Icons.close_rounded, size: 16),
                    visualDensity: VisualDensity.compact,
                    color: theme.hintColor,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildLeadingIcon(MediaValue val, {bool isGrid = false}) {
    dynamic icon;
    Color iconColor;

    switch (val.type) {
      case MediaFieldType.image:
        icon = Icons.image_rounded;
        iconColor = Colors.blue;
        break;
      case MediaFieldType.video:
        icon = Icons.videocam_rounded;
        iconColor = Colors.purple;
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
          width: isGrid ? double.infinity : 40,
          height: isGrid ? double.infinity : 40,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              _buildIconContainer(icon, iconColor, isGrid: isGrid),
        ),
      );
    }
    return _buildIconContainer(icon, iconColor, isGrid: isGrid);
  }

  Widget _buildIconContainer(dynamic icon, Color color, {bool isGrid = false}) {
    return Container(
      width: isGrid ? double.infinity : 40,
      height: isGrid ? double.infinity : 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: icon is IconData
            ? Icon(icon, color: color, size: isGrid ? 32 : 20)
            : FaIcon(icon, color: color, size: isGrid ? 32 : 20),
      ),
    );
  }

  String _getTypeLabel(MediaFieldType type) {
    switch (type) {
      case MediaFieldType.image:
        return widget.translations.image.toUpperCase();
      case MediaFieldType.video:
        return widget.translations.video.toUpperCase();
      case MediaFieldType.file:
        return widget.translations.file.toUpperCase();
      case MediaFieldType.youtubeUrl:
        return widget.translations.youtube.toUpperCase();
      case MediaFieldType.url:
        return widget.translations.url.toUpperCase();
    }
  }
}

class _PickerSheet extends StatelessWidget {
  final Color primaryColor;
  final bool multiple;
  final MediaFormFieldTranslations translations;
  final List<MediaFieldType> allowedTypes;

  const _PickerSheet({
    required this.primaryColor,
    required this.multiple,
    required this.translations,
    required this.allowedTypes,
  });

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
            translations.uploadContent,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            translations.selectContentType,
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
        if (allowedTypes.contains(MediaFieldType.image))
          _PickerOption(
            icon: Icons.image_rounded,
            label: translations.image,
            color: Colors.blue,
            onTap: () => _pickImage(context),
          ),
        if (allowedTypes.contains(MediaFieldType.video))
          _PickerOption(
            icon: Icons.videocam_rounded,
            label: translations.video,
            color: Colors.purple,
            onTap: () => _pickVideo(context),
          ),
        if (allowedTypes.contains(MediaFieldType.file))
          _PickerOption(
            icon: Icons.insert_drive_file_rounded,
            label: translations.file,
            color: Colors.orange,
            onTap: () => _pickFile(context),
          ),
        if (allowedTypes.contains(MediaFieldType.youtubeUrl))
          _PickerOption(
            icon: FontAwesomeIcons.youtube,
            label: translations.youtube,
            color: Colors.red,
            onTap: () => _pickUrl(context, isYoutube: true),
          ),
        if (allowedTypes.contains(MediaFieldType.url))
          _PickerOption(
            icon: Icons.link_rounded,
            label: translations.url,
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
        title: Text(translations.pickImageSource),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pop(context, ImageSource.camera),
            icon: const Icon(Icons.camera_alt_rounded),
            label: Text(translations.camera),
          ),
          TextButton.icon(
            onPressed: () => Navigator.pop(context, ImageSource.gallery),
            icon: const Icon(Icons.photo_library_rounded),
            label: Text(translations.gallery),
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

  void _pickVideo(BuildContext context) async {
    final picker = ImagePicker();
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(translations.pickVideoSource),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pop(context, ImageSource.camera),
            icon: const Icon(Icons.videocam_rounded),
            label: Text(translations.camera),
          ),
          TextButton.icon(
            onPressed: () => Navigator.pop(context, ImageSource.gallery),
            icon: const Icon(Icons.video_library_rounded),
            label: Text(translations.gallery),
          ),
        ],
      ),
    );

    if (source != null) {
      final video = await picker.pickVideo(source: source);
      if (!context.mounted) return;
      if (video != null) {
        Navigator.pop(context, [
          MediaValue(
            type: MediaFieldType.video,
            value: video.path,
            name: p.basename(video.path),
            file: File(video.path),
          ),
        ]);
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
        title: Text(
          isYoutube ? translations.enterYoutubeUrl : translations.enterUrl,
        ),
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
              if (value == null || value.isEmpty) {
                return translations.pleaseEnterUrl;
              }
              if (!Uri.parse(value).isAbsolute) {
                return translations.pleaseEnterValidUrl;
              }
              if (isYoutube &&
                  !value.contains('youtube.com') &&
                  !value.contains('youtu.be')) {
                return translations.pleaseEnterValidYoutubeUrl;
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(translations.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(context, controller.text);
              }
            },
            child: Text(translations.add),
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
