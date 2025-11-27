// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:as_instapicker/as_instapicker.dart';
import 'package:as_instapicker/src/widget/insta_asset_picker_delegate.dart';

const _kGridCount = 4;
const _kInitializeDelayDuration = Duration(milliseconds: 250);
const kDefaultInstaCropRatios = [1.0, 4 / 5];

/// Configuration delegate for crop behavior and output quality.
/// 
/// Controls how images are cropped and the quality of the exported images.
/// The [preferredSize] determines the resolution of cropped images,
/// while [cropRatios] defines the available aspect ratios for cropping.
class InstaCropDelegate {
  const InstaCropDelegate({
    this.preferredSize = 1080,
    this.cropRatios = kDefaultInstaCropRatios,
  });

  /// The param [preferredSize] is used to produce higher quality cropped image.
  /// Keep in mind that the higher this value is, the heavier the cropped image will be.
  ///
  /// This value while be used as such
  /// ```dart
  /// preferredSize = (preferredSize / scale).round()
  /// ```
  ///
  /// Defaults to `1080`, like instagram.
  final double preferredSize;

  /// The param [cropRatios] provided the list of crop ratios that can be set
  /// from the crop view.
  ///
  /// Defaults to `[1/1, 4/5]` like instagram.
  final List<double> cropRatios;
}

/// Configurations for the [InstaAssetPickerBuilder].
/// 
/// This class provides comprehensive configuration options for customizing
/// the Instagram-like asset picker, including:
/// - Grid layout and appearance
/// - Theme customization
/// - Special item positioning
/// - Crop settings via [cropDelegate]
/// - Picker behavior (close on complete, skip crop)
/// 
/// Example:
/// ```dart
/// InstaAssetPickerConfig(
///   title: 'Select Photos',
///   gridCount: 4,
///   cropDelegate: InstaCropDelegate(
///     preferredSize: 1080,
///     cropRatios: [1.0, 4/5],
///   ),
/// )
/// ```
class InstaAssetPickerConfig {
  const InstaAssetPickerConfig({
    /// [DefaultAssetPickerBuilderDelegate] config

    this.gridCount = _kGridCount,
    this.pickerTheme,
    this.specialItemPosition,
    this.specialItemBuilder,
    this.loadingIndicatorBuilder,
    this.selectPredicate,
    this.limitedPermissionOverlayPredicate,
    this.themeColor,
    this.textDelegate,
    this.gridThumbnailSize = defaultAssetGridPreviewSize,
    this.previewThumbnailSize,
    this.pathNameBuilder,

    /// [InstaAssetPickerBuilder] config

    this.title,
    this.cropDelegate = const InstaCropDelegate(),
    this.closeOnComplete = false,
    this.skipCropOnComplete = false,
    this.actionsBuilder,
  });

  /* [DefaultAssetPickerBuilderDelegate] config */

  /// Specifies the number of assets in the cross axis.
  ///
  /// Defaults to [_kGridCount], like instagram.
  final int gridCount;

  /// Specifies the theme to apply to the picker.
  /// It is by default initialized with the `primaryColor` of the context theme.
  final ThemeData? pickerTheme;

  /// Set a special item in the picker with several positions.
  /// Since the grid view is reversed, [SpecialItemPosition.prepend]
  /// will be at the top and [SpecialItemPosition.append] at the bottom.
  ///
  /// Defaults to [SpecialItemPosition.none].
  final SpecialItemPosition? specialItemPosition;

  /// Specifies [Widget] for the the special item.
  final SpecialItemBuilder<AssetPathEntity>? specialItemBuilder;

  /// The loader indicator to display in the picker.
  final LoadingIndicatorBuilder? loadingIndicatorBuilder;

  /// Predicate whether an asset can be selected or unselected.
  final AssetSelectPredicate<AssetEntity>? selectPredicate;

  /// Specifies if the limited permission overlay should be displayed.
  final LimitedPermissionOverlayPredicate? limitedPermissionOverlayPredicate;

  /// Main color for the picker.
  final Color? themeColor;

  /// Specifies the language to apply to the picker.
  ///
  /// Default is the locale language from the context.
  final AssetPickerTextDelegate? textDelegate;

  /// Thumbnail size in the grid.
  final ThumbnailSize gridThumbnailSize;

  /// Preview thumbnail size in the crop viewer.
  final ThumbnailSize? previewThumbnailSize;

  /// {@macro wechat_assets_picker.PathNameBuilder}
  final PathNameBuilder<AssetPathEntity>? pathNameBuilder;

  /* [InstaAssetPickerBuilder] config */

  /// Specifies the text title in the picker [AppBar].
  final String? title;

  /// Customize the display and export options of crops
  final InstaCropDelegate cropDelegate;

  /// Specifies if the picker should be closed after assets selection confirmation.
  ///
  /// Defaults to `false`.
  final bool closeOnComplete;

  /// Specifies if the assets should be cropped when the picker is closed.
  /// Set to `true` if you want to perform the crop yourself.
  ///
  /// Defaults to `false`.
  final bool skipCropOnComplete;

  /// The [Widget] to display on top of the assets grid view.
  ///
  /// Default is unselect all assets button.
  final InstaPickerActionsBuilder? actionsBuilder;
}

class InstaAssetPicker {
  InstaAssetPickerBuilder? builder;

  void dispose() {
    builder?.dispose();
    builder = null;
  }

  static AssetPickerTextDelegate defaultTextDelegate(BuildContext context) {
    final locale = Localizations.maybeLocaleOf(context);
    return assetPickerTextDelegateFromLocale(locale);
  }

  static Future<void> refreshAndSelectEntity(
    BuildContext context,
    AssetEntity? entity,
  ) async {
    if (entity == null) {
      return;
    }
    final AssetPicker<AssetEntity, AssetPathEntity> picker =
        context.findAncestorWidgetOfExactType()!;
    final DefaultAssetPickerBuilderDelegate builder =
        picker.builder as DefaultAssetPickerBuilderDelegate;
    final DefaultAssetPickerProvider p = builder.provider;
    await p.switchPath(
      PathWrapper<AssetPathEntity>(
        path: await p.currentPath!.path.obtainForNewProperties(),
      ),
    );
    builder.viewAsset(context, 0, entity);
  }

  /// Request the current [PermissionState] of required permissions.
  ///
  /// Throw an error if permissions are unauthorized.
  /// Since the exception is thrown from the MethodChannel it cannot be caught by a try/catch
  ///
  /// check `AssetPickerDelegate.permissionCheck()` from flutter_wechat_assets_picker package for more information.
  static Future<PermissionState> _permissionCheck(RequestType? requestType) =>
      AssetPicker.permissionCheck(
        requestOption: PermissionRequestOption(
          androidPermission: AndroidPermission(
            type: requestType ?? RequestType.common,
            mediaLocation: false,
          ),
        ),
      );

  /// Open a [ScaffoldMessenger] describing the reason why the picker cannot be opened.
  static void _openErrorPermission(
    BuildContext context,
    AssetPickerTextDelegate? textDelegate,
    Function(BuildContext context, String error)? customHandler,
  ) {
    final text = textDelegate ?? defaultTextDelegate(context);

    final defaultDescription =
        '${text.unableToAccessAll}\n${text.goToSystemSettings}';

    if (customHandler != null) {
      customHandler(context, defaultDescription);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(defaultDescription)),
      );
    }
  }

  /// Build a [ThemeData] with the given [themeColor] for the picker.
  /// 
  /// This is a convenience method that wraps [AssetPicker.themeData] from
  /// the underlying flutter_wechat_assets_picker package.
  /// 
  /// **Parameters:**
  /// - [themeColor]: The primary color to use for the theme
  /// - [light]: Whether to generate a light theme (default: false for dark theme)
  /// 
  /// **Example:**
  /// ```dart
  /// final theme = InstaAssetPicker.themeData(
  ///   Theme.of(context).primaryColor,
  ///   light: false,
  /// );
  /// 
  /// InstaAssetPicker.pickAssets(
  ///   context,
  ///   pickerConfig: InstaAssetPickerConfig(
  ///     pickerTheme: theme.copyWith(
  ///       canvasColor: Colors.black,
  ///     ),
  ///   ),
  ///   onCompleted: (_) {},
  /// );
  /// ```
  /// 
  /// For more information, check `AssetPickerDelegate.themeData()` from
  /// flutter_wechat_assets_picker package documentation.
  static ThemeData themeData(Color? themeColor, {bool light = false}) =>
      AssetPicker.themeData(themeColor, light: light);

  static void _assertRequestType(RequestType requestType) {
    assert(
        requestType == RequestType.image ||
            requestType == RequestType.video ||
            requestType == RequestType.common,
        'Only images and videos can be shown in the picker for now');
  }

  /// Opens an asset picker with restorable state - the picker's state is preserved even after pop.
  /// 
  /// This variant is useful when you need to maintain picker state across navigation
  /// or when the user might return to the picker multiple times in a session.
  /// 
  /// **⚠️ Important:** [InstaAssetPicker] instance and [provider] must be disposed manually
  /// when no longer needed to prevent memory leaks.
  /// 
  /// **Key Differences from [pickAssets]:**
  /// - Requires manual provider instantiation via [provider] getter
  /// - Maintains crop parameters and scroll position across sessions
  /// - Caller is responsible for lifecycle management
  /// 
  /// **Parameters:**
  /// - [provider]: Getter function returning a [DefaultAssetPickerProvider] instance.
  ///   Must be a getter to initialize provider after permission checks.
  /// - [onCompleted]: Callback receiving a `Stream<InstaExportDetails>` when selection confirmed
  /// - [pickerConfig]: Configuration for picker appearance and behavior
  /// - All other parameters match those in [pickAssets]
  /// 
  /// **Example:**
  /// ```dart
  /// class MyWidget extends StatefulWidget {
  ///   @override
  ///   State<MyWidget> createState() => _MyWidgetState();
  /// }
  /// 
  /// class _MyWidgetState extends State<MyWidget> {
  ///   late final InstaAssetPicker picker;
  ///   late final DefaultAssetPickerProvider provider;
  ///   
  ///   @override
  ///   void initState() {
  ///     super.initState();
  ///     picker = InstaAssetPicker();
  ///     provider = DefaultAssetPickerProvider(
  ///       maxAssets: 10,
  ///       requestType: RequestType.image,
  ///     );
  ///   }
  ///   
  ///   @override
  ///   void dispose() {
  ///     picker.dispose();
  ///     provider.dispose();
  ///     super.dispose();
  ///   }
  ///   
  ///   Future<void> openPicker() async {
  ///     await picker.restorableAssetsPicker(
  ///       context,
  ///       provider: () => provider,
  ///       canCrop: true,
  ///       restrictVideoDuration: false,
  ///       restrictVideoDurationMax: 60,
  ///       onCompleted: (stream) {
  ///         // Handle export stream
  ///       },
  ///     );
  ///   },
  /// }
  /// ```
  /// 
  /// Returns a `Future<List<AssetEntity>?>` with selected assets, or null if cancelled.
  Future<List<AssetEntity>?> restorableAssetsPicker(
    BuildContext context, {
    Key? key,
    int? minVideoDuration,
    required int restrictVideoDurationMax,
    required bool restrictVideoDuration,
    required bool canCrop,
    BoxFit? fit,
    Color? indicatorColor,
    Color? actionTextColor,
    TextStyle? indicatorTextStyle,
    Widget? confirmIcon,
    bool showSelectedCount = false,
    bool useRootNavigator = true,
    String? fontFamily,
    ValueChanged<List<AssetEntity>>? onAssetsUpdated,
    AssetPickerPageRouteBuilder<List<AssetEntity>>? pageRouteBuilder,
    Function(BuildContext context, String delegateDescription)?
        onPermissionDenied,

    /// InstaAssetPickerBuilder parameters
    required DefaultAssetPickerProvider Function() provider,
    required Function(Stream<InstaExportDetails> exportDetails) onCompleted,
    InstaAssetPickerConfig pickerConfig = const InstaAssetPickerConfig(),
  }) async {
    PermissionState? ps;
    try {
      ps = await _permissionCheck(null);
    } catch (e) {
      _openErrorPermission(
        context,
        pickerConfig.textDelegate,
        onPermissionDenied,
      );
      return [];
    }

    /// Provider must be initialized after permission check or gallery is empty (#43)
    final restoredProvider = provider();
    _assertRequestType(restoredProvider.requestType);

    builder ??= InstaAssetPickerBuilder(
      minVideoDuration: minVideoDuration,
      restrictVideoDurationMax: restrictVideoDurationMax,
      restrictVideoDuration: restrictVideoDuration,
      canCrop: canCrop,
      onAssetsUpdated: onAssetsUpdated,
      fit: fit,
      fontFamily: fontFamily,
      actionTextColor: actionTextColor,
      showSelectedCount: showSelectedCount,
      indicatorTextStyle: indicatorTextStyle,
      indicatorColor: indicatorColor,
      confirmIcon: confirmIcon,
      initialPermission: ps,
      provider: restoredProvider,
      keepScrollOffset: true,
      onCompleted: onCompleted,
      config: pickerConfig,
      locale: Localizations.maybeLocaleOf(context),
    );

    return AssetPicker.pickAssetsWithDelegate(
      context,
      delegate: builder!,
      useRootNavigator: useRootNavigator,
      pageRouteBuilder: pageRouteBuilder,
    );
  }

  /// Pick assets with the given arguments.
  /// 
  /// This is the main entry point for using the Instagram-like asset picker.
  /// 
  /// **Navigation Configuration:**
  /// - [useRootNavigator]: Whether the picker route should use the root Navigator (default: true)
  /// - [pageRouteBuilder]: Custom page route builder for transition animations
  /// - [onPermissionDenied]: Custom handler for permission denial errors
  /// 
  /// **Picker Configuration ([InstaAssetPickerBuilder] parameters):**
  /// - [onCompleted]: Callback invoked when selection is confirmed, receives a `Stream<InstaExportDetails>`
  /// - [pickerConfig]: Configuration object for customizing picker behavior and appearance
  /// - [canCrop]: Enable/disable crop functionality for selected assets
  /// - [minVideoDuration]: Minimum video duration in seconds (optional)
  /// - [restrictVideoDuration]: Whether to enforce video duration restrictions
  /// - [restrictVideoDurationMax]: Maximum video duration in seconds when restrictions enabled
  /// - [fit]: BoxFit for asset preview (e.g., BoxFit.contain, BoxFit.cover)
  /// - [fontFamily]: Custom font family for picker text
  /// - [actionTextColor]: Color for action buttons and text
  /// - [indicatorTextStyle]: TextStyle for selection indicator numbers
  /// - [indicatorColor]: Background color for selection indicators
  /// - [confirmIcon]: Custom widget to replace default confirm button text
  /// - [showSelectedCount]: Display count of selected assets in UI
  /// - [onAssetsUpdated]: Callback triggered when assets are selected/deselected
  /// 
  /// **Provider Configuration ([DefaultAssetPickerProvider] parameters):**
  /// - [selectedAssets]: Pre-selected assets when picker opens
  /// - [maxAssets]: Maximum number of selectable assets (default: 9)
  /// - [pageSize]: Number of assets to load per page (default: 80)
  /// - [pathThumbnailSize]: Thumbnail size for album list
  /// - [sortPathDelegate]: Custom sorting for asset paths/albums
  /// - [sortPathsByModifiedDate]: Use modified date for sorting
  /// - [filterOptions]: PMFilter for including/excluding specific assets
  /// - [initializeDelayDuration]: Delay before loading assets (default: 250ms)
  /// - [requestType]: Asset type to show (RequestType.image, .video, or .common)
  /// 
  /// Returns a `Future<List<AssetEntity>?>` with selected assets, or null if cancelled.
  /// 
  /// **Example:**
  /// ```dart
  /// final assets = await InstaAssetPicker.pickAssets(
  ///   context,
  ///   canCrop: true,
  ///   restrictVideoDuration: true,
  ///   restrictVideoDurationMax: 60,
  ///   maxAssets: 10,
  ///   pickerConfig: InstaAssetPickerConfig(
  ///     title: 'Select Photos',
  ///     cropDelegate: InstaCropDelegate(
  ///       cropRatios: [1.0, 4/5],
  ///     ),
  ///   ),
  ///   onCompleted: (stream) {
  ///     stream.listen((details) {
  ///       print('Progress: ${details.progress}');
  ///       if (details.progress == 1.0) {
  ///         // Export complete
  ///         for (var data in details.data) {
  ///           print('Cropped file: ${data.croppedFile?.path}');
  ///         }
  ///       }
  ///     });
  ///   },
  /// );
  /// ```
  /// 
  /// **Note:** Only [RequestType.image], [RequestType.video], and [RequestType.common]
  /// are supported. Other types will trigger an assertion error.
  static Future<List<AssetEntity>?> pickAssets(
    BuildContext context, {
    Key? key,
    required bool canCrop,
    int? minVideoDuration,
    required bool restrictVideoDuration,
    required int restrictVideoDurationMax,
    BoxFit? fit,
    String? fontFamily,
    Color? actionTextColor,
    TextStyle? indicatorTextStyle,
    Color? indicatorColor,
    Widget? confirmIcon,
    bool showSelectedCount = false,
    bool useRootNavigator = true,
    ValueChanged<List<AssetEntity>>? onAssetsUpdated,
    AssetPickerPageRouteBuilder<List<AssetEntity>>? pageRouteBuilder,
    Function(BuildContext context, String delegateDescription)?
        onPermissionDenied,

    /// InstaAssetPickerBuilder parameters
    required Function(Stream<InstaExportDetails> exportDetails) onCompleted,
    InstaAssetPickerConfig pickerConfig = const InstaAssetPickerConfig(),

    /// DefaultAssetPickerProvider parameters
    List<AssetEntity>? selectedAssets,
    int maxAssets = defaultMaxAssetsCount,
    int pageSize = defaultAssetsPerPage,
    ThumbnailSize pathThumbnailSize = defaultPathThumbnailSize,
    SortPathDelegate<AssetPathEntity>? sortPathDelegate =
        SortPathDelegate.common,
    bool sortPathsByModifiedDate = false,
    PMFilter? filterOptions,
    Duration initializeDelayDuration = _kInitializeDelayDuration,
    RequestType requestType = RequestType.common,
  }) async {
    _assertRequestType(requestType);

    // must be called before initializing any picker provider to avoid `PlatformException(PERMISSION_REQUESTING)` type exception
    PermissionState? ps;
    try {
      ps = await _permissionCheck(requestType);
    } catch (e) {
      _openErrorPermission(
        context,
        pickerConfig.textDelegate,
        onPermissionDenied,
      );
      return [];
    }

    final DefaultAssetPickerProvider provider = DefaultAssetPickerProvider(
      selectedAssets: selectedAssets,
      maxAssets: maxAssets,
      pageSize: pageSize,
      pathThumbnailSize: pathThumbnailSize,
      requestType: requestType,
      sortPathDelegate: sortPathDelegate,
      sortPathsByModifiedDate: sortPathsByModifiedDate,
      filterOptions: filterOptions,
      initializeDelayDuration: initializeDelayDuration,
    );

    final InstaAssetPickerBuilder builder = InstaAssetPickerBuilder(
      restrictVideoDuration: restrictVideoDuration,
      restrictVideoDurationMax: restrictVideoDurationMax,
      minVideoDuration: minVideoDuration,
      fit: fit,
      canCrop: canCrop,
      onAssetsUpdated: onAssetsUpdated,
      fontFamily: fontFamily,
      actionTextColor: actionTextColor,
      showSelectedCount: showSelectedCount,
      indicatorTextStyle: indicatorTextStyle,
      indicatorColor: indicatorColor,
      confirmIcon: confirmIcon,
      initialPermission: ps,
      provider: provider,
      keepScrollOffset: false,
      onCompleted: onCompleted,
      config: pickerConfig,
      locale: Localizations.maybeLocaleOf(context),
    );

    return AssetPicker.pickAssetsWithDelegate(
      context,
      delegate: builder,
      permissionRequestOption: PermissionRequestOption(
        androidPermission: AndroidPermission(
          type: requestType,
          mediaLocation: false,
        ),
      ),
      useRootNavigator: useRootNavigator,
      pageRouteBuilder: pageRouteBuilder,
    );
  }
}
