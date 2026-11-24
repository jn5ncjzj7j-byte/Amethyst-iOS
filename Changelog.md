# Angel Aura Amethyst (iOS)

## 1.0

You're helping to shape our future while we work to build a release.

### Changes
- Added customizable touch controls and an FPS display control.
- Added custom mouse cursor styles, shapes, colors, and cursor image support.
- Added local importing for mods, resource packs, and shader packs.
- Added Misg Rendered renderer selection for supported Minecraft versions.
- Added installed Resource Packs and Shader Packs views with search, refresh, and removal.
- Added an in-app changelog that reads this file from the app bundle.
- Improved two-finger scrolling so each gesture update sends its movement delta.

### Fixes
- Improved Fabric and derived-profile library handling.
- Improved skin profile loading for Minecraft 26.3 and newer.
- Improved Modrinth installation and manual update checks.
- Added a fallback for invalid renderer preferences to prevent startup from continuing with an uninitialized renderer.
- Improved native Vulkan FPS frame accounting by resolving the host frame callback once.

### Known Issues
- Native Vulkan FPS reporting still needs on-device verification.
- MetalFX frame generation is currently at the capability-probe stage; frame interpolation and x2–x4 controls are not implemented yet.
- MobileGlues and Sodium can still freeze the displayed frame on some devices.
- Zink shader stability remains under investigation.
