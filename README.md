# TrackLines Plugin for KOReader

A simple plugin that displays horizontal reading guide lines to help maintain your place while reading.

![TrackLines Example](images/tracklines_example.jpg)

## Overview

TrackLines adds horizontal guide lines to your KOReader display, helping you keep track of where you are on the page. This can be particularly useful for:

- Readers with focus or attention difficulties
- Reading on devices with larger screens
- Maintaining your place in dense text
- Reducing eye strain during extended reading sessions

## Features

- Adjustable line thickness
- Configurable color intensity
- Position adjustment via gestures or menu
- Automatic line advancement as you read
- Full screen width coverage
- Works in both portrait and landscape modes

## Installation

1. Download the plugin files from this repository
2. Create a folder named `tracklines.koplugin` in your KOReader plugins directory:
   - For Android: `/sdcard/koreader/plugins/`
   - For other devices: [KOReader data directory]/plugins/
3. Copy the contents of this repository to that folder
4. Restart KOReader

## Usage

### Enabling the Plugin

1. Open KOReader
2. Go to the reader menu (tap the center of the screen)
3. Navigate to `More tools` → `Plugins` → `horizontal lines`
4. Toggle the `Enable` option

### Moving the Line

You can move the guide line up or down on the screen:

- Use the `Move up` and `Move down` actions if you've assigned them to gestures
- Alternatively, you can toggle the plugin off and on to reset the line position

### Configuration

Access settings by going to the reader menu → `More tools` → `Plugins` → `horizontal lines` → `Settings`

Available settings:

- **Line thickness**: Set how thick the guide line should be (in pixels)
- **Margin from edges**: Adjusts the position of the line (not currently used)
- **Line color intensity**: Controls how dark the line appears (1-10, where 10 is darkest)
- **Increase margin after pages**: Automatically shifts the line's position after reading a specified number of pages (set to 0 to disable)

## Automatic Line Advancement

If enabled, the plugin can automatically adjust the line position as you read:

1. Set "Increase margin after pages" to your desired interval (e.g., 100 pages)
2. As you read, the plugin tracks page turns
3. After reaching the specified number of pages, the line will automatically shift downward
4. This continues until the line reaches near the center of the screen

## Troubleshooting

- If the plugin doesn't appear in your plugins menu, ensure it's installed in the correct location and has the correct name (`tracklines.koplugin`)
- If the guide line disappears after changing settings, try toggling the plugin off and on
- If you experience display issues, try restarting KOReader

## License

This plugin is licensed under the GNU Affero General Public License v3 (AGPL-3.0). 