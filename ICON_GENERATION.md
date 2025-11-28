# App Icon Generation Guide

The app name has been updated to **KEDAIREKA** in the Android manifest.

## Current Icon
The app currently uses the default Flutter launcher icon.

## To Create a Custom Icon (matching the splash screen):

### Option 1: Quick Online Tool (Recommended)
1. Go to https://icon.kitchen or https://appicon.co
2. Upload or create an icon with:
   - **Background**: White (#FFFFFF)
   - **Icon**: Map/Location pin in blue (#2196F3)
   - **Style**: Rounded corners (20% radius)
3. Download the icon pack
4. Replace the files in `android/app/src/main/res/mipmap-*` folders

### Option 2: Using flutter_launcher_icons Package

1. Create a 1024x1024 PNG image with:
   - White background with rounded corners
   - Blue map icon in the center (similar to splash screen)
   - Save as `assets/logos/app_icon.png`

2. Update `pubspec.yaml`:
   ```yaml
   flutter_launcher_icons:
     android: true
     ios: false
     image_path: "assets/logos/app_icon.png"
     adaptive_icon_background: "#FFFFFF"
     adaptive_icon_foreground: "assets/logos/app_icon.png"
   ```

3. Run:
   ```bash
   flutter pub get
   flutter pub run flutter_launcher_icons
   ```

### Option 3: Use Design Software
1. Open Figma, Canva, or Photoshop
2. Create 1024x1024 canvas
3. Add white background with rounded corners (180px radius)
4. Add a map/location icon in blue (#2196F3) centered
5. Export as PNG
6. Follow Option 2 steps

## Icon Specifications
- **Size**: 1024x1024 px
- **Background**: White (#FFFFFF)
- **Icon Color**: Blue (#2196F3) - matching AppTheme.primaryColor
- **Shape**: Rounded square (radius ~20%)
- **Icon**: Map/location pin (similar to Icons.map in splash screen)

The icon should visually match the splash screen design which shows a white rounded container with a blue map icon.
