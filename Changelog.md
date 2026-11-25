# Angel Aura Amethyst (iOS)

## 1.2 (Development)

### NEXA Visual Redesign
- Rebuilt the Home dashboard around a dark cosmic theme with a glowing ring-free planet, starfield, and purple horizon.
- Replaced translucent Liquid Glass styling in the launcher navigation and version toolbar with opaque, flat surfaces.
- Moved Minecraft installation selection into its own control beside Play.
- Removed the dropdown arrow from Play so version selection and launching are separate actions.
- Reworked Java, renderer, and memory status cards.
- Rebuilt Mods, Resource Packs, Shaders, and News & Updates cards with consistent spacing.
- Refined the sidebar orb, account control, and icon-only footer shortcuts.
- Return to the Home layout after confirming a version selection.

## 1.1 (Development)

### NEXA Launcher Interface
- Introduced the first NEXA launcher interface while keeping the existing app identity and Minecraft launch systems.
- Reorganized the main navigation into Home, Versions, and Settings.
- Added a Home dashboard with Minecraft branding, profile information, and a prominent Play action.
- Added separate status cards for the selected Minecraft version, Java runtime, renderer, and allocated RAM.
- Added quick access to Mods, Resource Packs, Shaders, and News & Updates.
- Added a sidebar footer with the live clock, date, GitHub, Discord, and Changelog shortcuts.
- Kept the account and profile switcher in the upper-right corner.
- Applied a dark navy theme with restrained purple accents and a simple glowing orb mark.

### Improvements
- Improved News content positioning alongside the sidebar.
- Preserved resource-pack and shader-pack import actions in the navigation.
- Kept the JIT status toolbar visible alongside the sidebar footer.
- Improved sidebar navigation state when switching between Home and feature pages.

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
