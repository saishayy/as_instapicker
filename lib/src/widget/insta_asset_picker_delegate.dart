// ignore_for_file: implementation_imports

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:as_instapicker/as_instapicker.dart';
import 'package:as_instapicker/src/instacrop_controller.dart';
import 'package:as_instapicker/src/widget/crop_viewer.dart';
import 'package:provider/provider.dart';

import 'package:wechat_picker_library/wechat_picker_library.dart';

/// The reduced height of the crop view
const _kReducedCropViewHeight = kToolbarHeight;

/// The position of the crop view when extended
const _kExtendedCropViewPosition = 0.0;

/// Scroll offset multiplier to start viewer position animation
const _kScrollMultiplier = 1.5;

const _kIndicatorSize = 20.0;
const _kPathSelectorRowHeight = 50.0;
const _kActionsPadding = EdgeInsets.symmetric(horizontal: 8, vertical: 8);

typedef InstaPickerActionsBuilder = List<Widget> Function(
  BuildContext context,
  ThemeData? pickerTheme,
  double height,
  VoidCallback unselectAll,
);

class InstaAssetPickerBuilder extends DefaultAssetPickerBuilderDelegate {
  InstaAssetPickerBuilder({
    this.confirmIcon,
    this.indicatorColor,
    this.indicatorTextStyle,
    this.actionTextColor,
    required this.restrictVideoDurationMax,
    required this.restrictVideoDuration,
    required super.initialPermission,
    required super.provider,
    required this.onCompleted,
    required InstaAssetPickerConfig config,
    this.showSelectedCount = false,
    this.fontFamily,
    super.keepScrollOffset,
    super.locale,
    this.onAssetsUpdated,
    this.fit,
    required this.canCrop,
    this.minVideoDuration,
  })  : _cropController =
            InstaCropController(keepScrollOffset, config.cropDelegate),
        title = config.title,
        closeOnComplete = config.closeOnComplete,
        skipCropOnComplete = config.skipCropOnComplete,
        actionsBuilder = config.actionsBuilder,
        super(
          gridCount: config.gridCount,
          pickerTheme: config.pickerTheme,
          specialItemPosition:
              config.specialItemPosition ?? SpecialItemPosition.none,
          specialItemBuilder: config.specialItemBuilder,
          loadingIndicatorBuilder: config.loadingIndicatorBuilder,
          selectPredicate: config.selectPredicate,
          limitedPermissionOverlayPredicate:
              config.limitedPermissionOverlayPredicate,
          themeColor: config.themeColor,
          textDelegate: config.textDelegate,
          gridThumbnailSize: config.gridThumbnailSize,
          previewThumbnailSize: config.previewThumbnailSize,
          // pathNameBuilder: config.pathNameBuilder,
          shouldRevertGrid: false,
        );

  /// The minimum duration of the video in seconds
  final int? minVideoDuration;

  /// Whether to restrict video selection to videos 60 seconds or shorter
  final int restrictVideoDurationMax;

  /// Whether to restrict video selection to videos 60 seconds or shorter
  final bool restrictVideoDuration;

  /// to decide whether the user can crop the asset or not.
  final bool canCrop;

  /// The [BoxFit] to be used in the crop view for the selected asset to fit
  final BoxFit? fit;

  /// Callback triggered when assets are selected or deselected
  final ValueChanged<List<AssetEntity>>? onAssetsUpdated;

  /// Customized FontFamily
  final String? fontFamily;

  /// The color of the selected assets action color
  final Color? actionTextColor;

  /// This will show the selected assets count in the picker[Actions]
  final bool showSelectedCount;

  /// Add a textStyle to the selected assets indicator
  final TextStyle? indicatorTextStyle;

  /// The color of the selected assets indicator
  final Color? indicatorColor;

  /// this will be the icon in [AppBar] actions instead of the default confirm text
  final Widget? confirmIcon;

  /// The text title in the picker [AppBar].
  final String? title;

  /// Callback called when the assets selection is confirmed.
  /// It will as argument a [Stream] with exportation details [InstaAssetsExportDetails].
  final Function(Stream<InstaExportDetails>) onCompleted;

  /// The [Widget] to display on top of the assets grid view.
  /// Default is unselect all assets button.
  final InstaPickerActionsBuilder? actionsBuilder;

  /// Should the picker be closed when the selection is confirmed
  ///
  /// Defaults to `false`, like instagram
  final bool closeOnComplete;

  /// Should the picker automatically crop when the selection is confirmed
  ///
  /// Defaults to `false`.
  final bool skipCropOnComplete;

  // LOCAL PARAMETERS

  /// Save last position of the grid view scroll controller
  double _lastScrollOffset = 0.0;
  double _lastEndScrollOffset = 0.0;

  /// Scroll offset position to jump to after crop view is expanded
  double? _scrollTargetOffset;

  final ValueNotifier<double> _cropViewPosition = ValueNotifier<double>(0);
  final _cropViewerKey = GlobalKey<CropViewerState>();

  /// Controller handling the state of asset crop values and the exportation
  final InstaCropController _cropController;

  /// Whether the picker is mounted. Set to `false` if disposed.
  bool _mounted = true;

  @override
  void dispose() {
    _mounted = false;
    if (!keepScrollOffset) {
      _cropController.dispose();
      _cropViewPosition.dispose();
    }
    super.dispose();
  }

  /// Called when the confirmation [TextButton] is tapped
  void onConfirm(BuildContext context) {
    if (closeOnComplete) {
      Navigator.of(context).pop(provider.selectedAssets);
    }
    _cropViewerKey.currentState?.saveCurrentCropChanges();
    onCompleted(
      _cropController.exportCropFiles(
        provider.selectedAssets,
        skipCrop: skipCropOnComplete,
      ),
    );
  }

  /// The responsive height of the crop view
  /// setup to not be bigger than half the screen height
  double cropViewHeight(BuildContext context) => math.min(
        MediaQuery.of(context).size.width,
        MediaQuery.of(context).size.height * 0.5,
      );

  /// Returns thumbnail [index] position in scroll view
  double indexPosition(BuildContext context, int index) {
    final row = (index / gridCount).floor();
    final size =
        (MediaQuery.of(context).size.width - itemSpacing * (gridCount - 1)) /
            gridCount;
    return row * size + (row * itemSpacing);
  }

  /// Expand the crop view size to the maximum
  void _expandCropView([double? lockOffset]) {
    _scrollTargetOffset = lockOffset;
    _cropViewPosition.value = _kExtendedCropViewPosition;
  }

  /// Unselect all the selected assets
  void unSelectAll() {
    provider.selectedAssets = [];
    _cropController.clear();
  }

  /// Initialize [previewAsset] with [p.selectedAssets] if not empty
  /// otherwise if the first item of the album
  Future<void> _initializePreviewAsset(
    DefaultAssetPickerProvider p,
    bool shouldDisplayAssets,
  ) async {
    if (!_mounted || _cropController.previewAsset.value != null) return;

    if (p.selectedAssets.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_mounted) {
          _cropController.previewAsset.value = p.selectedAssets.last;
        }
      });
    }

    if (shouldDisplayAssets && p.selectedAssets.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final list =
            await p.currentPath?.path.getAssetListRange(start: 0, end: 1);
        if (_mounted && (list?.isNotEmpty ?? false)) {
          _cropController.previewAsset.value = list!.first;
        }
      });
    }
  }

  /// Called when the asset thumbnail is tapped
  @override
  Future<void> viewAsset(
    BuildContext context,
    int? index,
    AssetEntity currentAsset,
  ) async {
    if (index == null) return;

    // Check if the video duration is less than the minimum required
    if (minVideoDuration != null &&
        currentAsset.type == AssetType.video &&
        currentAsset.videoDuration.inSeconds < minVideoDuration!) {
      return; // Prevent preview
    }
    // Check if the asset is a video and its duration exceeds 60 seconds
    if (currentAsset.type == AssetType.video &&
        restrictVideoDuration &&
        currentAsset.videoDuration.inSeconds > 60) {
      return; // Prevent interaction
    }

    if (canCrop && _cropController.isCropViewReady.value != true) return;

    // If the asset is already the preview asset, unselect it
    if (provider.selectedAssets.isNotEmpty &&
        _cropController.previewAsset.value == currentAsset) {
      selectAsset(context, currentAsset, index, true);
      _cropController.previewAsset.value = provider.selectedAssets.isEmpty
          ? currentAsset
          : provider.selectedAssets.last;
      return;
    }

    _cropController.previewAsset.value = currentAsset;
    selectAsset(context, currentAsset, index, false);
  }

  /// Called when an asset is selected
  @override
  Future<void> selectAsset(
    BuildContext context,
    AssetEntity asset,
    int index,
    bool selected,
  ) async {
    // Restrict by minimum duration
    if (minVideoDuration != null &&
        asset.type == AssetType.video &&
        asset.videoDuration.inSeconds < minVideoDuration!) {
      return; // Prevent selection
    }

    // Check if the asset is a video and its duration exceeds 60 seconds
    if (asset.type == AssetType.video &&
        restrictVideoDuration &&
        asset.videoDuration.inSeconds > 60) {
      return; // Prevent selection
    }
    if (canCrop && _cropController.isCropViewReady.value != true) return;

    final thumbnailPosition = indexPosition(context, index);
    final prevCount = provider.selectedAssets.length;
    await super.selectAsset(context, asset, index, selected);

    // Update preview asset with selected
    final selectedAssets = provider.selectedAssets;
    if (prevCount < selectedAssets.length) {
      _cropController.previewAsset.value = asset;
    } else if (selected &&
        asset == _cropController.previewAsset.value &&
        selectedAssets.isNotEmpty) {
      _cropController.previewAsset.value = selectedAssets.last;
    }

    if (onAssetsUpdated != null) {
      onAssetsUpdated!(provider.selectedAssets);
    }

    _expandCropView(thumbnailPosition);
  }

  /// Handle scroll on grid view to hide/expand the crop view
  bool _handleScroll(
    BuildContext context,
    ScrollNotification notification,
    double position,
    double reducedPosition,
  ) {
    final isScrollUp = gridScrollController.position.userScrollDirection ==
        ScrollDirection.reverse;
    final isScrollDown = gridScrollController.position.userScrollDirection ==
        ScrollDirection.forward;

    if (notification is ScrollEndNotification) {
      _lastEndScrollOffset = gridScrollController.offset;
      // reduce crop view
      if (position > reducedPosition && position < _kExtendedCropViewPosition) {
        _cropViewPosition.value = reducedPosition;
        return true;
      }
    }

    // expand crop view
    if (isScrollDown &&
        gridScrollController.offset <= 0 &&
        position < _kExtendedCropViewPosition) {
      // if scroll at edge, compute position based on scroll
      if (_lastScrollOffset > gridScrollController.offset) {
        _cropViewPosition.value -=
            (_lastScrollOffset.abs() - gridScrollController.offset.abs()) * 6;
      } else {
        // otherwise just expand it
        _expandCropView();
      }
    } else if (isScrollUp &&
        (gridScrollController.offset - _lastEndScrollOffset) *
                _kScrollMultiplier >
            cropViewHeight(context) - position &&
        position > reducedPosition) {
      // reduce crop view
      _cropViewPosition.value = cropViewHeight(context) -
          (gridScrollController.offset - _lastEndScrollOffset) *
              _kScrollMultiplier;
    }

    _lastScrollOffset = gridScrollController.offset;

    return true;
  }

  /// Returns a loader [Widget] to show in crop view and instead of confirm button
  Widget _buildLoader(BuildContext context, double radius) {
    if (super.loadingIndicatorBuilder != null) {
      return super.loadingIndicatorBuilder!(context, provider.isAssetsEmpty);
    }
    return PlatformProgressIndicator(
      radius: radius,
      size: radius * 2,
      color: theme.iconTheme.color,
    );
  }

  /// Returns the [TextButton] that open album list
  @override
  Widget pathEntitySelector(BuildContext context) {
    Widget selector(BuildContext context) {
      return TextButton(
        style: TextButton.styleFrom(
          foregroundColor: theme.splashColor,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.all(4),
        ),
        onPressed: () {
          Feedback.forTap(context);
          isSwitchingPath.value = !isSwitchingPath.value;
        },
        child:
            Selector<DefaultAssetPickerProvider, PathWrapper<AssetPathEntity>?>(
          selector: (_, DefaultAssetPickerProvider p) => p.currentPath,
          builder: (_, PathWrapper<AssetPathEntity>? p, Widget? w) => Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (p != null)
                Flexible(
                  child: Text(
                    isPermissionLimited && p.path.isAll
                        ? textDelegate.accessiblePathName
                        : pathNameBuilder?.call(p.path) ?? p.path.name,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: actionTextColor,
                      fontFamily: fontFamily,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              w!,
            ],
          ),
          child: ValueListenableBuilder<bool>(
            valueListenable: isSwitchingPath,
            builder: (_, bool isSwitchingPath, Widget? w) => Transform.rotate(
              angle: isSwitchingPath ? math.pi : 0,
              child: w,
            ),
            child: Icon(
              Icons.keyboard_arrow_down,
              size: 20,
              color: actionTextColor ?? theme.iconTheme.color,
            ),
          ),
        ),
      );
    }

    return ChangeNotifierProvider<DefaultAssetPickerProvider>.value(
      value: provider,
      builder: (BuildContext c, _) => selector(c),
    );
  }

  /// Returns the list ofactions that are displayed on top of the assets grid view
  Widget _buildActions(BuildContext context, int selectedItemCount) {
    final double height = _kPathSelectorRowHeight - _kActionsPadding.vertical;
    final ThemeData? theme = pickerTheme?.copyWith(
      buttonTheme: const ButtonThemeData(padding: EdgeInsets.all(8)),
    );

    return SizedBox(
      height: _kPathSelectorRowHeight,
      width: MediaQuery.of(context).size.width,
      child: Padding(
        // decrease left padding because the path selector button has a padding
        padding: _kActionsPadding.copyWith(left: _kActionsPadding.left - 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            pathEntitySelector(context),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showSelectedCount &&
                    selectedItemCount > 0 &&
                    provider.maxAssets > 1)
                  Chip(
                    label: Text(
                      '$selectedItemCount/${provider.maxAssets} Selected',
                    ),
                  ),
                actionsBuilder != null
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: actionsBuilder!(
                          context,
                          theme,
                          height,
                          unSelectAll,
                        ),
                      )
                    : InstaPickerCircleIconButton.unselectAll(
                        onTap: unSelectAll,
                        theme: theme,
                        size: height,
                      ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Returns the top right selection confirmation [TextButton]
  /// Calls [onConfirm]
  @override
  Widget confirmButton(BuildContext context) {
    final ValueNotifier<bool> isCropViewReadyNotifier =
        canCrop ? _cropController.isCropViewReady : ValueNotifier<bool>(true);
    final Widget button = ValueListenableBuilder<bool>(
      valueListenable: isCropViewReadyNotifier,
      builder: (_, isLoaded, __) => Consumer<DefaultAssetPickerProvider>(
        builder: (_, DefaultAssetPickerProvider p, __) {
          return TextButton(
            style: pickerTheme?.textButtonTheme.style ??
                TextButton.styleFrom(
                  foregroundColor: themeColor,
                  disabledForegroundColor: theme.dividerColor,
                  textStyle: TextStyle(fontFamily: fontFamily),
                ),
            onPressed: isLoaded && p.isSelectedNotEmpty
                ? () => onConfirm(context)
                : null,
            child: isLoaded
                ? confirmIcon ??
                    Text(
                      p.isSelectedNotEmpty && !isSingleAssetMode
                          ? '${textDelegate.confirm}'
                              ' (${p.selectedAssets.length}/${p.maxAssets})'
                          : textDelegate.confirm,
                    )
                : _buildLoader(context, 10),
          );
        },
      ),
    );
    return ChangeNotifierProvider<DefaultAssetPickerProvider>.value(
      value: provider,
      builder: (_, __) => button,
    );
  }

  /// Returns most of the widgets of the layout, the app bar, the crop view and the grid view
  @override
  Widget androidLayout(BuildContext context) {
    // height of appbar + cropview + path selector row
    final topWidgetHeight = cropViewHeight(context) +
        kToolbarHeight +
        _kPathSelectorRowHeight +
        MediaQuery.of(context).padding.top;

    return ChangeNotifierProvider<DefaultAssetPickerProvider>.value(
      value: provider,
      builder: (context, _) => ValueListenableBuilder<double>(
        valueListenable: _cropViewPosition,
        builder: (context, position, child) {
          // the top position when the crop view is reduced
          final topReducedPosition = -(cropViewHeight(context) -
              _kReducedCropViewHeight +
              kToolbarHeight);
          position =
              position.clamp(topReducedPosition, _kExtendedCropViewPosition);
          // the height of the crop view visible on screen
          final cropViewVisibleHeight = (topWidgetHeight +
                  position -
                  MediaQuery.of(context).padding.top -
                  kToolbarHeight -
                  _kPathSelectorRowHeight)
              .clamp(_kReducedCropViewHeight, topWidgetHeight);
          // opacity is calculated based on the position of the crop view
          final opacity =
              ((position / -topReducedPosition) + 1).clamp(0.4, 1.0);
          final animationDuration = position == topReducedPosition ||
                  position == _kExtendedCropViewPosition
              ? const Duration(milliseconds: 250)
              : Duration.zero;

          double gridHeight = MediaQuery.of(context).size.height -
              kToolbarHeight -
              _kReducedCropViewHeight;
          // when not assets are displayed, compute the exact height to show the loader
          if (!provider.hasAssetsToDisplay) {
            gridHeight -= cropViewHeight(context) - -_cropViewPosition.value;
          }
          final topPadding = topWidgetHeight + position;
          if (gridScrollController.hasClients && _scrollTargetOffset != null) {
            gridScrollController.jumpTo(_scrollTargetOffset!);
          }
          _scrollTargetOffset = null;

          return Stack(
            children: [
              AnimatedPadding(
                padding: EdgeInsets.only(top: topPadding),
                duration: animationDuration,
                child: SizedBox(
                  height: gridHeight,
                  width: MediaQuery.of(context).size.width,
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (notification) => _handleScroll(
                      context,
                      notification,
                      position,
                      topReducedPosition,
                    ),
                    child: _buildGrid(context),
                  ),
                ),
              ),
              AnimatedPositioned(
                top: position,
                duration: animationDuration,
                child: SizedBox(
                  width: MediaQuery.of(context).size.width,
                  height: topWidgetHeight,
                  child: AssetPickerAppBarWrapper(
                    appBar: AssetPickerAppBar(
                      backgroundColor: theme.appBarTheme.backgroundColor,
                      title: title != null
                          ? Text(
                              title!,
                              style: theme.appBarTheme.titleTextStyle!.copyWith(
                                fontFamily: fontFamily,
                              ),
                            )
                          : null,
                      leading: backButton(context),
                      actions: <Widget>[confirmButton(context)],
                    ),
                    body: DecoratedBox(
                      decoration: BoxDecoration(
                        color: pickerTheme?.canvasColor,
                      ),
                      child: Column(
                        children: [
                          Listener(
                            onPointerDown: (_) {
                              _expandCropView();
                              // stop scroll event
                              if (gridScrollController.hasClients) {
                                gridScrollController
                                    .jumpTo(gridScrollController.offset);
                              }
                            },
                            child: CropViewer(
                              canCrop: canCrop,
                              key: _cropViewerKey,
                              controller: _cropController,
                              textDelegate: textDelegate,
                              provider: provider,
                              opacity: opacity,
                              fit: fit,
                              height: cropViewHeight(context),
                              // center the loader in the visible viewport of the crop view
                              loaderWidget: Align(
                                alignment: Alignment.bottomCenter,
                                child: SizedBox(
                                  height: cropViewVisibleHeight,
                                  child: Center(
                                    child: _buildLoader(context, 16),
                                  ),
                                ),
                              ),
                              theme: pickerTheme,
                            ),
                          ),
                          Consumer<DefaultAssetPickerProvider>(
                            builder: (context, provider, child) {
                              final selectedItemCount =
                                  provider.selectedAssets.length;
                              return _buildActions(context, selectedItemCount);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              pathEntityListBackdrop(context),
              _buildListAlbums(context),
            ],
          );
        },
      ),
    );
  }

  /// Since the layout is the same on all platform, it simply call [androidLayout]
  @override
  Widget appleOSLayout(BuildContext context) => androidLayout(context);

  /// Returns the [ListView] containing the albums
  Widget _buildListAlbums(BuildContext context) {
    return Consumer<DefaultAssetPickerProvider>(
      builder: (BuildContext context, provider, __) {
        if (isAppleOS(context)) pathEntityListWidget(context);

        // NOTE: fix position on android, quite hacky could be optimized
        return ValueListenableBuilder<bool>(
          valueListenable: isSwitchingPath,
          builder: (_, bool isSwitchingPath, Widget? child) =>
              Transform.translate(
            offset: isSwitchingPath
                ? Offset(0, kToolbarHeight + MediaQuery.of(context).padding.top)
                : Offset.zero,
            child: Stack(
              children: [pathEntityListWidget(context)],
            ),
          ),
        );
      },
    );
  }

  /// Returns the [GridView] displaying the assets
  Widget _buildGrid(BuildContext context) {
    return Consumer<DefaultAssetPickerProvider>(
      builder: (BuildContext context, DefaultAssetPickerProvider p, __) {
        final bool shouldDisplayAssets =
            p.hasAssetsToDisplay || shouldBuildSpecialItem;
        _initializePreviewAsset(p, shouldDisplayAssets);

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: shouldDisplayAssets
              ? MediaQuery(
                  // fix: https://github.com/fluttercandies/flutter_wechat_assets_picker/issues/395
                  data: MediaQuery.of(context).copyWith(
                    padding: const EdgeInsets.only(top: -kToolbarHeight),
                  ),
                  child: RepaintBoundary(child: assetsGridBuilder(context)),
                )
              : loadingIndicator(context),
        );
      },
    );
  }

  /// To show selected assets indicator and preview asset overlay
  @override
  Widget selectIndicator(BuildContext context, int index, AssetEntity asset) {
    final selectedAssets = provider.selectedAssets;
    final Duration duration = switchingPathDuration * 0.75;

    final int indexSelected = selectedAssets.indexOf(asset);
    final bool isSelected = indexSelected != -1;

    final bool isMinDisabled = minVideoDuration != null &&
        asset.type == AssetType.video &&
        asset.videoDuration.inSeconds < minVideoDuration!;
    // Check if the asset is a video and its duration exceeds 60 seconds
    final bool isDisabled = asset.type == AssetType.video &&
        restrictVideoDuration &&
        asset.videoDuration.inSeconds > 60;

    final Widget innerSelector = AnimatedContainer(
      duration: duration,
      width: _kIndicatorSize,
      height: _kIndicatorSize,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        border: Border.all(color: theme.unselectedWidgetColor, width: 1),
        color: isSelected
            ? indicatorColor ?? themeColor
            : isDisabled
                ? Colors.black
                : theme.unselectedWidgetColor.withOpacity(.2),
        shape: BoxShape.circle,
      ),
      child: FittedBox(
        child: AnimatedSwitcher(
          duration: duration,
          reverseDuration: duration,
          child: isSelected
              ? Text(
                  (indexSelected + 1).toString(),
                  style:
                      indicatorTextStyle ?? TextStyle(fontFamily: fontFamily),
                )
              : const SizedBox.shrink(),
        ),
      ),
    );

    return ValueListenableBuilder<AssetEntity?>(
      valueListenable: _cropController.previewAsset,
      builder: (context, previewAsset, child) {
        final bool isPreview = asset == _cropController.previewAsset.value;

        return Positioned.fill(
          child: GestureDetector(
            onTap: isMinDisabled || isDisabled
                ? null // Disable tap for long videos
                : isPreviewEnabled
                    ? () => viewAsset(context, index, asset)
                    : null,
            child: AnimatedContainer(
              duration: switchingPathDuration,
              padding: const EdgeInsets.all(4),
              color: isMinDisabled || isDisabled
                  ? Colors.black.withOpacity(0.3)
                  : isPreview
                      ? theme.unselectedWidgetColor.withOpacity(.5)
                      : theme.colorScheme.surface.withOpacity(.1),
              child: isMinDisabled || isDisabled
                  ? null
                  : Align(
                      alignment: AlignmentDirectional.topEnd,
                      child: isSelected && !isSingleAssetMode
                          ? GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => selectAsset(
                                  context, asset, index, isSelected),
                              child: innerSelector,
                            )
                          : innerSelector,
                    ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget selectedBackdrop(BuildContext context, int index, AssetEntity asset) =>
      const SizedBox.shrink();

  /// Disable item banned indicator in single mode (#26) so that
  /// the new selected asset replace the old one
  @override
  Widget itemBannedIndicator(BuildContext context, AssetEntity asset) =>
      isSingleAssetMode
          ? const SizedBox.shrink()
          : super.itemBannedIndicator(context, asset);
}
