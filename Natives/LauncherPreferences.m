#import "config.h"
#import "renderer_info.h"
#import "utils.h"
#import "LauncherPreferences.h"
#import "PLPreferences.h"
#import "UIKit+hook.h"
#import <CoreFoundation/CoreFoundation.h>

static PLPreferences* pref;

void loadPreferences(BOOL reset) {
    assert(getenv("AME_HOME"));
    if (reset) {
        [pref reset];
    } else {
        pref = [[PLPreferences alloc] initWithAutomaticMigrator];
    }
}

void toggleIsolatedPref(BOOL forceEnable) {
    if (!pref.instancePath) {
        pref.instancePath = [NSString stringWithFormat:@"%s/launcher_preferences.plist", getenv("GAME_DIR")];
    }
    [pref toggleIsolationForced:forceEnable];
}

id getPrefObject(NSString *key) {
    return [pref getObject:key];
}
BOOL getPrefBool(NSString *key) {
    return [getPrefObject(key) boolValue];
}
float getPrefFloat(NSString *key) {
    return [getPrefObject(key) floatValue];
}
NSInteger getPrefInt(NSString *key) {
    return [getPrefObject(key) intValue];
}

void setPrefObject(NSString *key, id value) {
    [pref setObject:key value:value];
}
void setPrefBool(NSString *key, BOOL value) {
    setPrefObject(key, @(value));
}
void setPrefFloat(NSString *key, float value) {
    setPrefObject(key, @(value));
}
void setPrefInt(NSString *key, NSInteger value) {
    setPrefObject(key, @(value));
}

void importLauncherConfigFromDictionary(NSDictionary *config) {
    if (![config[@"format"] isEqualToString:@"Amethyst Launcher Configuration"] || [config[@"format_version"] integerValue] != 1) return;
    NSDictionary *globalPreferences = config[@"global_preferences"];
    if ([globalPreferences isKindOfClass:NSDictionary.class]) {
        pref.globalPref = [globalPreferences mutableCopy];
        [pref saveGlobalPref];
    }
    NSDictionary *profilePreferences = config[@"active_profile_preferences"];
    if ([profilePreferences isKindOfClass:NSDictionary.class]) {
        if (!pref.instancePath) pref.instancePath = [NSString stringWithFormat:@"%s/launcher_preferences.plist", getenv("GAME_DIR")];
        pref.instancePref = [profilePreferences mutableCopy];
        [pref saveInstancePref];
    }
    NSDictionary *cursorImage = config[@"custom_cursor_image"];
    NSString *encodedImage = cursorImage[@"base64"];
    if ([encodedImage isKindOfClass:NSString.class] && encodedImage.length) {
        NSData *imageData = [[NSData alloc] initWithBase64EncodedString:encodedImage options:0];
        NSString *extension = [cursorImage[@"filename"] pathExtension].lowercaseString;
        NSSet *allowedExtensions = [NSSet setWithArray:@[@"png", @"jpg", @"jpeg", @"heic", @"webp"]];
        if (![allowedExtensions containsObject:extension]) extension = @"png";
        if (imageData.length) {
            NSString *imagePath = [NSString stringWithFormat:@"%s/custom_mouse_cursor.%@", getenv("AME_HOME"), extension];
            if ([imageData writeToFile:imagePath options:NSDataWritingAtomic error:nil]) setPrefObject(@"control.mouse_cursor_image", imagePath);
        }
    }
    NSDictionary *touchControls = config[@"touch_controls"];
    if ([touchControls isKindOfClass:NSDictionary.class]) {
        NSString *controlMapPath = [@(getenv("AME_HOME")) stringByAppendingPathComponent:@"controlmap"];
        [NSFileManager.defaultManager createDirectoryAtPath:controlMapPath withIntermediateDirectories:YES attributes:nil error:nil];
        [touchControls enumerateKeysAndObjectsUsingBlock:^(id filename, id layout, BOOL *stop) {
            if (![filename isKindOfClass:NSString.class] || ![[filename pathExtension].lowercaseString isEqualToString:@"json"] || ![[filename lastPathComponent] isEqualToString:filename] || ![layout isKindOfClass:NSDictionary.class]) return;
            NSData *data = [NSJSONSerialization dataWithJSONObject:layout options:NSJSONWritingPrettyPrinted error:nil];
            if (data) [data writeToFile:[controlMapPath stringByAppendingPathComponent:filename] options:NSDataWritingAtomic error:nil];
        }];
    }
}

NSDictionary *getLauncherConfigForExport(void) {
    NSMutableDictionary *config = [@{
        @"format": @"Amethyst Launcher Configuration",
        @"format_version": @1,
        @"exported_at": [[NSISO8601DateFormatter new] stringFromDate:NSDate.date],
        @"global_preferences": pref.globalPref ?: @{}
    } mutableCopy];
    if (pref.instancePref) {
        config[@"active_profile_preferences"] = pref.instancePref;
    }
    NSString *imagePath = getPrefObject(@"control.mouse_cursor_image");
    NSData *imageData = imagePath.length ? [NSData dataWithContentsOfFile:imagePath] : nil;
    if (imageData) {
        config[@"custom_cursor_image"] = @{
            @"filename": imagePath.lastPathComponent,
            @"base64": [imageData base64EncodedStringWithOptions:0]
        };
    }
    NSString *controlMapPath = [@(getenv("AME_HOME")) stringByAppendingPathComponent:@"controlmap"];
    NSArray *controlFiles = [NSFileManager.defaultManager contentsOfDirectoryAtPath:controlMapPath error:nil];
    NSMutableDictionary *touchControls = [NSMutableDictionary new];
    for (NSString *filename in controlFiles) {
        if (![filename.pathExtension.lowercaseString isEqualToString:@"json"]) continue;
        NSData *controlData = [NSData dataWithContentsOfFile:[controlMapPath stringByAppendingPathComponent:filename]];
        id controlLayout = controlData ? [NSJSONSerialization JSONObjectWithData:controlData options:NSJSONReadingMutableContainers error:nil] : nil;
        if ([controlLayout isKindOfClass:NSDictionary.class]) touchControls[filename] = controlLayout;
    }
    config[@"touch_controls"] = touchControls;
    return config;
}

void resetWarnings() {
    for (int i = 0; i < pref.globalPref[@"warnings"].count; i++) {
        NSString *key = pref.globalPref[@"warnings"].allKeys[i];
        pref.globalPref[@"warnings"][key] = @YES;
    }
}

#pragma mark Safe area

CGRect getSafeArea(CGRect screenBounds) {
    UIEdgeInsets safeArea = UIEdgeInsetsFromString(getPrefObject(@"control.control_safe_area"));
    if (screenBounds.size.width < screenBounds.size.height) {
        safeArea = UIEdgeInsetsMake(safeArea.right, safeArea.top, safeArea.left, safeArea.bottom);
    }
    return UIEdgeInsetsInsetRect(screenBounds, safeArea);
}

void setSafeArea(CGSize screenSize, CGRect frame) {
    UIEdgeInsets safeArea;
    // TODO: make safe area consistent across opposite orientations?
    if (screenSize.width < screenSize.height) {
        safeArea = UIEdgeInsetsMake(
            frame.origin.x,
            screenSize.height - CGRectGetMaxY(frame),
            screenSize.width - CGRectGetMaxX(frame),
            frame.origin.y);
    } else {
        safeArea = UIEdgeInsetsMake(
            frame.origin.y,
            frame.origin.x,
            screenSize.height - CGRectGetMaxY(frame),
            screenSize.width - CGRectGetMaxX(frame));
    }
    setPrefObject(@"control.control_safe_area", NSStringFromUIEdgeInsets(safeArea));
}

UIEdgeInsets getDefaultSafeArea() {
    UIEdgeInsets safeArea = UIApplication.sharedApplication.windows.firstObject.safeAreaInsets;
    CGSize screenSize = UIScreen.mainScreen.bounds.size;
    if (screenSize.width < screenSize.height) {
        safeArea.left = safeArea.top;
        safeArea.right = safeArea.bottom;
    }
    safeArea.top = safeArea.bottom = 0;
    return safeArea;
}

#pragma mark Java runtime

NSString* getSelectedJavaHome(NSString* defaultJRETag, int minVersion) {
    NSDictionary *pref = getPrefObject(@"java.java_homes");
    NSDictionary<NSString *, NSString *> *selected = pref[@"0"];
    NSString *selectedVer = selected[defaultJRETag];
    if (minVersion > selectedVer.intValue) {
        NSArray *sortedVersions = [pref.allKeys valueForKeyPath:@"self.integerValue"];
        sortedVersions = [sortedVersions sortedArrayUsingSelector:@selector(compare:)];
        for (NSNumber *version in sortedVersions) {
            if (version.intValue >= minVersion) {
                selectedVer = version.stringValue;
                break;
            }
        }
        if (!selectedVer) {
            NSLog(@"Error: requested Java >= %d was not installed!", minVersion);
            return nil;
        }
    }

    id selectedDir = pref[selectedVer];
    if ([selectedDir isEqualToString:@"internal"]) {
        selectedDir = [NSString stringWithFormat:@"%@/java_runtimes/java-%@-openjdk", NSBundle.mainBundle.bundlePath, selectedVer];
    } else {
        selectedDir = [NSString stringWithFormat:@"%s/java_runtimes/%@", getenv("AME_HOME"), selectedDir];
    }

    if ([NSFileManager.defaultManager fileExistsAtPath:selectedDir]) {
        return selectedDir;
    } else {
        NSLog(@"Error: selected runtime for %@ does not exist: %@", defaultJRETag, selectedDir);
        return nil;
    }
}

#pragma mark Renderer
NSArray* getRendererKeys(BOOL containsDefault) {
    NSMutableArray *array = @[
        @"auto",
        @"misg-rendered",
        @ RENDERER_NAME_GL4ES,
        @ RENDERER_NAME_MTL_ANGLE,
        @ RENDERER_NAME_MOBILEGLUES,
        @ RENDERER_NAME_MOBILEGL,
        @ RENDERER_NAME_VK_ZINK,
        @ RENDERER_NAME_MOLTENVK,
        @ RENDERER_NAME_KOSMICKRISP
    ].mutableCopy;

    if (containsDefault) {
        [array insertObject:@"(default)" atIndex:0];
    }
    
    return array;
}

NSArray* getRendererNames(BOOL containsDefault) {
    NSMutableArray *array;

    array = @[
        localize(@"preference.title.renderer.debug.auto", nil),
        @"Misg Rendered",
        localize(@"preference.title.renderer.debug.gl4es", nil),
        localize(@"preference.title.renderer.debug.angle", nil),
        localize(@"preference.title.renderer.debug.mg", nil),
        localize(@"preference.title.renderer.debug.mobilegl", nil),
        localize(@"preference.title.renderer.debug.zink", nil),
        localize(@"preference.title.renderer.debug.moltenvk", nil),
        localize(@"preference.title.renderer.debug.kosmickrisp", nil)
    ].mutableCopy;

    if (containsDefault) {
        [array insertObject:@"(default)" atIndex:0];
    }

    return array;
}
