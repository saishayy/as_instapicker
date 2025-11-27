<p align="center">
  <h1 align="center">Instagram Like Assets Picker</h1>
</p>

An image (also with videos) picker based on Instagram picker UI. It is using the powerful [flutter_wechat_assets_picker](https://pub.dev/packages/wechat_assets_picker)
package to handle the picker and a custom version of [image_crop](https://pub.dev/packages/image_crop) for crop and a fork of [insta_assets_picker](https://pub.dev/packages/insta_assets_picker).

## 🚀 Features

- ✅ Instagram layout
  - Scroll behaviors, animation
  - Preview, select, unselect action logic
- ✅ Image and Video ([but not video processing](#video)) support
- ✅ Theme and language customization
- ✅ Multiple assets pick (with maximum limit)
- ✅ Single asset pick mode
- ✅ Restore state of picker after pop
- ✅ Select aspect ratios to crop all assets with (default to 1:1 & 4:5)
- ✅ Crop all image assets at once and receive a stream with a progress value
- ✅ Prepend or append a custom item in the assets list
- ✅ Add custom action buttons

## 📸 Screenshots

| Layout and scroll                                                                                          | Crop                                                                                                            |
| ---------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------- |
| ![](https://raw.githubusercontent.com/LeGoffMael/insta_assets_picker/main/example/screenshots/scroll.webp) | ![](https://raw.githubusercontent.com/LeGoffMael/insta_assets_picker/main/example/screenshots/crop-export.webp) |

## 📖 Installation

Add this package to the `pubspec.yaml`

```yaml
as_instapicker: ^1.0.4
```

Then run:
```bash
flutter pub get
```

### ‼️ DO NOT SKIP THIS PART

Since this package is a custom delegate of `flutter_wechat_assets_picker` you **MUST** follow this package setup recommendation : [installation guide](https://pub.dev/packages/wechat_assets_picker#preparing-for-use-).

**Required Setup:**
1. **iOS**: Add photo library usage descriptions to `Info.plist`
2. **Android**: Add storage permissions to `AndroidManifest.xml`
3. **Android**: Set `minSdkVersion` to at least 21 in `build.gradle`

See the [complete setup guide](https://pub.dev/packages/wechat_assets_picker#preparing-for-use-) for detailed instructions.

## 👀 Usage

For more details check out the [example](https://github.com/AyeshaIftikhar/as_instapicker/blob/main/example/lib/main.dart).

### Basic Example

```dart
Future<List<AssetEntity>?> callPicker() => InstaAssetPicker.pickAssets(
    context,
    canCrop: true,
    restrictVideoDuration: true,
    restrictVideoDurationMax: 60, // seconds
    pickerConfig: InstaAssetPickerConfig(
      title: 'Select assets',
      cropDelegate: InstaCropDelegate(
        preferredSize: 1080,
        cropRatios: [1.0, 4/5], // 1:1 and 4:5 aspect ratios
      ),
    ),
    maxAssets: 10,
    onCompleted: (Stream<InstaExportDetails> stream) {
        // TODO : handle crop stream result
        // i.e : display it using a StreamBuilder
        // - in the same page (closeOnComplete=true)
        // - send it to another page (closeOnComplete=false)
        // or use `stream.listen` to handle the data manually in your state manager
        stream.listen((details) {
          print('Progress: ${details.progress * 100}%');
          if (details.progress == 1.0) {
            // Export complete!
            for (var data in details.data) {
              print('Cropped file: ${data.croppedFile?.path}');
            }
          }
        });
    },
);
```

### Export Stream Details

### Export Stream Details

Fields in `InstaExportDetails`:

| Name           | Type                          | Description                                                           |
| -------------- | ----------------------------- | --------------------------------------------------------------------- |
| data           | `List<InstaExportData>` | Contains the selected assets, crop parameters and possible crop file. |
| selectedAssets | `List<AssetEntity>`           | Selected assets without crop                                          |
| aspectRatio    | `double`                      | Selected aspect ratio (1 or 4/5)                                      |
| progress       | `double`                      | Progress indicator of the exportation (between 0 and 1)               |

Fields in `InstaExportData`:

| Name         | Type                  | Description                                                        |
| ------------ | --------------------- | ------------------------------------------------------------------ |
| croppedFile  | `File?`               | The cropped file. Can be null if video or if choose to skip crop.  |
| selectedData | `InstaCropData` | The selected asset and it's crop parameter (area, scale, ratio...) |

### Advanced Features

#### Custom Action Buttons
```dart
InstaAssetPickerConfig(
  actionsBuilder: (context, theme, height, unselectAll) => [
    IconButton(
      icon: Icon(Icons.clear_all),
      onPressed: unselectAll,
    ),
    // Add your custom buttons here
  ],
)
```

#### Video Duration Restrictions
```dart
InstaAssetPicker.pickAssets(
  context,
  canCrop: true,
  restrictVideoDuration: true,
  minVideoDuration: 3, // minimum 3 seconds
  restrictVideoDurationMax: 60, // maximum 60 seconds
  onCompleted: (_) {},
)
```

#### Disable Cropping
```dart
InstaAssetPicker.pickAssets(
  context,
  canCrop: false, // disable zoom and crop
  fit: BoxFit.contain, // show entire asset
  onCompleted: (_) {},
)
```

### Picker configuration

Please follow `flutter_wechat_assets_picker` documentation : [AssetPickerConfig](https://pub.dev/packages/wechat_assets_picker#usage-)

### Localizations

Please follow `flutter_wechat_assets_picker` documentation : [Localizations](https://pub.dev/packages/wechat_assets_picker#localizations)

### Theme customization

Most of the components of the picker can be customized using theme.

```dart
// set picker theme based on app theme primary color
final theme = InstaAssetPicker.themeData(Theme.of(context).primaryColor);
InstaAssetPicker.pickAssets(
    context,
    pickerConfig: InstaAssetPickerConfig(
      pickerTheme: theme.copyWith(
        canvasColor: Colors.black, // body background color
        splashColor: Color.grey, // ontap splash color
        colorScheme: theme.colorScheme.copyWith(
          background: Colors.black87, // albums list background color
        ),
        appBarTheme: theme.appBarTheme.copyWith(
          backgroundColor: Colors.black, // app bar background color
          titleTextStyle: Theme.of(context)
              .appBarTheme
              .titleTextStyle
              ?.copyWith(color: Colors.white), // change app bar title text style to be like app theme
        ),
        // edit `confirm` button style
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: Colors.blue,
            disabledForegroundColor: Colors.red,
          ),
        ),
      ),
    ),
    onCompleted: (_) {},
);
```

### Crop customization

You can set the list of crop aspect ratios available.
You can also set the preferred size, for the cropped assets.

```dart
InstaAssetPicker.pickAssets(
    context,
    pickerConfig: InstaAssetPickerConfig(
      cropDelegate: InstaAssetCropDelegate(
        // allows you to set the preferred size used when cropping the asset.
        // the final size will depends on the scale used when cropping.
        preferredSize: 1080,
        cropRatios: [
        // - allow you to set the list of aspect ratios selectable,
        // the default values are [1/1, 4/5] like instagram.
        // - if you want to disable cropping, you can set only one parameter,
        // in this case, the "crop" button will not be displayed (#10).
        // - if the value of cropRatios is different than the default value,
        // the "crop" button will display the selected ratio value (i.e.: 1:1)
        // instead of unfold arrows.
      ]),
    ),
    onCompleted: (_) {},
);
```

### Camera

Many people requested the ability to take picture from the picker.
The main aspect of this package is selection and uniform crop selection.
Consequently, camera-related operations have no place in this package.
However, since version `2.0.0`, it is now possible to trigger this action using either `specialItemBuilder` and/or `actionsBuilder`.

The ability to take a photo from the camera must be handled on your side, but the picker is now able to refresh the list and select the new photo.
New [examples](https://github.com/AyeshaIftikhar/as_instapicker/tree/main/example/lib/pages/camera) have been written to show how to manage this process with the [camera](https://pub.dev/packages/camera) or [wechat_camera_picker](https://pub.dev/packages/wechat_camera_picker) package.

### Video

Video are now supported on version `3.0.0`. You can pick a video asset and select the crop area directly in the picker.
However, as video processing is a heavy operation it is not handled by this package.
Which means you must handle it yourself. If you want to preview the video result, you can use the `InstaAssetCropTransform` which will transform the Image or VideoPlayer to fit the selected crop area.

The example app has been updated to support videos (+ camera recording) and shows [how to process the video](https://github.com/AyeshaIftikhar/as_instapicker/tree/main/example/lib/post_provider.dart#L84) using [ffmpeg_kit_flutter](https://pub.dev/packages/ffmpeg_kit_flutter).

#### FFmpeg Helper Methods

The `InstaCropData` class provides helper methods for FFmpeg video processing:

```dart
stream.listen((details) {
  for (var data in details.data) {
    if (data.selectedData.asset.type == AssetType.video) {
      // Get FFmpeg crop filter: "out_w:out_h:x:y"
      String? cropFilter = data.selectedData.ffmpegCrop;
      
      // Get FFmpeg scale filter: "iw*scale:ih*scale"
      String? scaleFilter = data.selectedData.ffmpegScale;
      
      // Use with ffmpeg_kit_flutter to process video
      // See example/lib/post_provider.dart for complete implementation
    }
  }
});
```

## 📚 API Documentation

For comprehensive API documentation, see:
- [InstaAssetPicker](lib/src/assets_picker.dart) - Main picker API
- [InstaCropController](lib/src/instacrop_controller.dart) - Crop controller and export
- [InstaAssetPickerConfig](lib/src/assets_picker.dart) - Configuration options
- [Example app](example/lib/) - Multiple usage examples

## 🐛 Issues & Contributions

Found a bug or want to contribute? Visit our [issue tracker](https://github.com/AyeshaIftikhar/as_instapicker/issues).

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## ✨ Credit

This package is based on [flutter_wechat_assets_picker](https://pub.dev/packages/wechat_assets_picker) and a fork of [insta_assets_picker](https://pub.dev/packages/insta_assets_picker) by [Ayesha Iftikhar](https://github.com/AyeshaIftikhar/as_instapicker) and [image_crop](https://pub.dev/packages/image_crop) by [lykhonis](https://github.com/lykhonis).
