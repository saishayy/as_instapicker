import 'dart:io';

import 'package:flutter/material.dart';
import 'package:fraction/fraction.dart';
import 'package:instacrop/instacrop.dart';
import 'package:as_instapicker/as_instapicker.dart';

/// Uses [InstaCropSingleton] to keep crop parameters in memory until the picker is disposed
/// Similar to [Singleton] class from `wechat_assets_picker` package
/// used only when [keepScrollOffset] is set to `true`
class InstaCropSingleton {
  const InstaCropSingleton._();

  static List<InstaCropData> cropParameters = [];
}

/// Contains the export result for a single asset.
/// 
/// Includes both the cropped file (if applicable) and the crop parameters
/// used during the export process.
class InstaExportData {
  const InstaExportData({
    required this.croppedFile,
    required this.selectedData,
  });

  /// The cropped file, can be null if the asset is not an image or if the
  /// exportation was skipped ([skipCropOnComplete]=true)
  final File? croppedFile;

  /// The selected data, contains the asset and it's crop values
  final InstaCropData selectedData;
}

/// Contains all the parameters and results of the export operation.
/// 
/// This class provides:
/// - [data]: List of exported assets with crop information
/// - [selectedAssets]: Original selected assets for reference
/// - [aspectRatio]: The aspect ratio used for cropping
/// - [progress]: Export progress from 0.0 (started) to 1.0 (completed)
/// 
/// Typically received as a stream during the export process:
/// ```dart
/// stream.listen((details) {
///   print('Exported ${details.data.length} assets');
///   print('Progress: ${(details.progress * 100).toInt()}%');
/// });
/// ```
class InstaExportDetails {
  /// The export result, containing the selected assets, crop parameters
  /// and possible crop file.
  final List<InstaExportData> data;

  /// The selected thumbnails, can be provided to the picker to preselect those assets
  final List<AssetEntity> selectedAssets;

  /// The selected [aspectRatio]
  final double aspectRatio;

  /// The [progress] param represents progress indicator between `0.0` and `1.0`.
  final double progress;

  const InstaExportDetails({
    required this.data,
    required this.selectedAssets,
    required this.aspectRatio,
    required this.progress,
  });
}

/// The crop parameters state, used during exportation or when loading the crop view.
/// 
/// Contains the complete crop state for an asset including:
/// - The [asset] being cropped
/// - [cropParam]: Internal crop parameters from instacrop library
/// - [scale]: The zoom/scale factor applied
/// - [area]: The visible crop area as a rectangle
/// 
/// This class also provides FFmpeg-compatible filter strings via
/// [ffmpegCrop] and [ffmpegScale] for video processing.
class InstaCropData {
  final AssetEntity asset;
  final CropInternal? cropParam;

  // export crop params
  final double scale;
  final Rect? area;

  /// Returns crop filter for ffmpeg in "out_w:out_h:x:y" format
  String? get ffmpegCrop {
    final area = this.area;
    if (area == null) return null;

    final w = area.width * asset.orientatedWidth;
    final h = area.height * asset.orientatedHeight;
    final x = area.left * asset.orientatedWidth;
    final y = area.top * asset.orientatedHeight;

    return '$w:$h:$x:$y';
  }

  /// Returns scale filter for ffmpeg in "iw*[scale]:ih*[scale]" format
  String? get ffmpegScale {
    final scale = cropParam?.scale;
    if (scale == null) return null;

    return 'iw*$scale:ih*$scale';
  }

  const InstaCropData({
    required this.asset,
    required this.cropParam,
    this.scale = 1.0,
    this.area,
  });

  static InstaCropData fromState({
    required AssetEntity asset,
    required CropState? cropState,
  }) {
    return InstaCropData(
      asset: asset,
      cropParam: cropState?.internalParameters,
      scale: cropState?.scale ?? 1.0,
      area: cropState?.area,
    );
  }
}

/// The controller that handles the exportation and saves the state of selected assets crop parameters.
/// 
/// This controller manages:
/// - Crop ratio selection and switching
/// - Crop parameters storage (in memory or cached)
/// - Asset preview state
/// - Export stream generation with progress tracking
/// 
/// The [keepMemory] parameter determines whether crop parameters persist
/// across picker sessions using [InstaCropSingleton].
/// 
/// Example:
/// ```dart
/// final controller = InstaCropController(
///   true, // keepMemory
///   InstaCropDelegate(cropRatios: [1.0, 4/5]),
/// );
/// 
/// // Export cropped files with progress tracking
/// controller.exportCropFiles(selectedAssets).listen((details) {
///   print('Progress: ${details.progress}');
/// });
/// ```
class InstaCropController {
  InstaCropController(this.keepMemory, this.cropDelegate)
      : cropRatioIndex = ValueNotifier<int>(0);

  /// The index of the selected aspectRatio among the possibilities
  final ValueNotifier<int> cropRatioIndex;

  /// Whether the asset in the crop view is loaded
  final ValueNotifier<bool> isCropViewReady = ValueNotifier<bool>(false);

  /// The asset [AssetEntity] currently displayed in the crop view
  final ValueNotifier<AssetEntity?> previewAsset =
      ValueNotifier<AssetEntity?>(null);

  /// Options related to crop
  final InstaCropDelegate cropDelegate;

  /// List of all the crop parameters set by the user
  List<InstaCropData> _cropParameters = [];

  /// Whether if [_cropParameters] should be saved in the cache to use when the picker
  /// is open with [InstaAssetPicker.restorableAssetsPicker]
  final bool keepMemory;

  void dispose() {
    clear();
    isCropViewReady.dispose();
    cropRatioIndex.dispose();
    previewAsset.dispose();
  }

  double get aspectRatio {
    assert(cropDelegate.cropRatios.isNotEmpty,
        'The list of supported crop ratios cannot be empty.');
    return cropDelegate.cropRatios[cropRatioIndex.value];
  }

  String get aspectRatioString {
    final r = aspectRatio;
    if (r == 1) return '1:1';
    return Fraction.fromDouble(r).reduce().toString().replaceFirst('/', ':');
  }

  /// Set the next available index as the selected crop ratio
  void nextCropRatio() {
    if (cropRatioIndex.value < cropDelegate.cropRatios.length - 1) {
      cropRatioIndex.value = cropRatioIndex.value + 1;
    } else {
      cropRatioIndex.value = 0;
    }
  }

  /// Use [_cropParameters] when [keepMemory] is `false`, otherwise use [InstaCropSingleton.cropParameters]
  List<InstaCropData> get cropParameters =>
      keepMemory ? InstaCropSingleton.cropParameters : _cropParameters;

  /// Save the list of crop parameters
  /// if [keepMemory] save list memory or simply in the controller
  void updateStoreCropParam(List<InstaCropData> list) {
    if (keepMemory) {
      InstaCropSingleton.cropParameters = list;
    } else {
      _cropParameters = list;
    }
  }

  /// Clear all the saved crop parameters
  void clear() {
    updateStoreCropParam([]);
    previewAsset.value = null;
  }

  /// When the preview asset is changed, save the crop parameters of the previous asset
  void onChange(
    AssetEntity? saveAsset,
    CropState? saveCropState,
    List<AssetEntity> selectedAssets,
  ) {
    final List<InstaCropData> newList = [];

    for (final asset in selectedAssets) {
      // get the already saved crop parameters if exists
      final savedCropAsset = get(asset);

      // if it is the asseet to save & the crop parameters exists
      if (asset == saveAsset && saveAsset != null) {
        // add the new parameters
        newList.add(InstaCropData.fromState(
          asset: saveAsset,
          cropState: saveCropState,
        ));
        // if it is not the asset to save and no crop parameter exists
      } else if (savedCropAsset == null) {
        // set empty crop parameters
        newList.add(InstaCropData.fromState(asset: asset, cropState: null));
      } else {
        // keep existing crop parameters
        newList.add(savedCropAsset);
      }
    }

    // overwrite the crop parameters list
    updateStoreCropParam(newList);
  }

  /// Returns the crop parametes [InstaCropData] of the given asset
  InstaCropData? get(AssetEntity asset) {
    if (cropParameters.isEmpty) return null;
    final index = cropParameters.indexWhere((e) => e.asset == asset);
    if (index == -1) return null;
    return cropParameters[index];
  }

  /// Apply all the crop parameters to the list of [selectedAssets]
  /// and returns the exportation as a [Stream].
  /// 
  /// The [skipCrop] parameter allows skipping the crop operation for all assets.
  /// This is useful when you want to handle cropping manually or skip it entirely.
  /// 
  /// Returns a [Stream] of [InstaExportDetails] with progress updates from 0.0 to 1.0.
  Stream<InstaExportDetails> exportCropFiles(
    List<AssetEntity> selectedAssets, {
    bool skipCrop = false,
  }) async* {
    final List<InstaExportData> data = [];

    /// Returns the [InstaExportDetails] with given progress value [p]
    InstaExportDetails makeDetail(double p) => InstaExportDetails(
          data: data,
          selectedAssets: selectedAssets,
          aspectRatio: aspectRatio,
          progress: p,
        );

    // start progress
    yield makeDetail(0);
    final List<InstaCropData> list = cropParameters;

    final double step = 1 / list.length;

    for (int i = 0; i < list.length; i++) {
      final asset = list[i].asset;

      if (skipCrop || asset.type != AssetType.image) {
        data.add(InstaExportData(croppedFile: null, selectedData: list[i]));
      } else {
        final file = await asset.originFile;

        final scale = list[i].scale;
        final area = list[i].area;

        if (file == null) {
          throw 'error file is null';
        }

        // makes the sample file to not be too small
        final sampledFile = await InstaCrop.sampleImage(
          file: file,
          preferredSize: (cropDelegate.preferredSize / scale).round(),
        );

        if (area == null) {
          data.add(
              InstaExportData(croppedFile: sampledFile, selectedData: list[i]));
        } else {
          // crop the file with the area selected
          final croppedFile =
              await InstaCrop.cropImage(file: sampledFile, area: area);
          // delete the not needed sample file
          sampledFile.delete();

          data.add(
              InstaExportData(croppedFile: croppedFile, selectedData: list[i]));
        }
      }

      // increase progress
      final progress = (i + 1) * step;
      if (progress < 1) {
        yield makeDetail(progress);
      }
    }
    // complete progress
    yield makeDetail(1);
  }
}
