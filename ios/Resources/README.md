# PencilKit Background Image

Place your background image file here with the name:

**`pencilkit_background.png`**

## Requirements:
- **Filename:** `pencilkit_background.png` (exact name required)
- **Format:** PNG
- **Dimensions:** 10000 x 10000 pixels (to match the canvas contentSize)
- **Location:** Place in this directory: `ios/Resources/`

## Example Structure:
```
ios/
├── Resources/
│   ├── pencilkit_background.png  ← Your background image here
│   └── README.md
├── RNPencilKit.h
├── RNPencilKit.mm
└── ...
```

## Usage:

Enable the background image by setting the `showLinedPaper` prop:

```tsx
<PencilKitView
  showLinedPaper={true}  // Set to false to hide the background
  // ... other props
/>
```

## Features:
- ✅ **Toggleable via prop**: Control with `showLinedPaper` boolean prop
- ✅ **Automatic scrolling**: Background moves as you scroll the canvas
- ✅ **Zoom support**: Background scales in/out when you zoom the canvas
- ✅ **Dynamic updates**: Toggle on/off in real-time

After placing the image, rebuild your iOS app for the changes to take effect.

