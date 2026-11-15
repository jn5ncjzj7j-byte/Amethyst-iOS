#import <Foundation/Foundation.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <PhotosUI/PhotosUI.h>

#import "DBNumberedSlider.h"
#import "HostManagerBridge.h"
#import "LauncherNavigationController.h"
#import "LauncherMenuViewController.h"
#import "LauncherPreferences.h"
#import "LauncherPreferencesViewController.h"
#import "LauncherPrefContCfgViewController.h"
#import "LauncherPrefManageJREViewController.h"
#import "UIKit+hook.h"

#import "config.h"
#import "ios_uikit_bridge.h"
#import "utils.h"
#import "installer/modpack/CurseForgeAPI.h"

@interface LauncherPreferencesViewController()<UIDocumentPickerDelegate, UIColorPickerViewControllerDelegate, PHPickerViewControllerDelegate>
@property(nonatomic) NSArray<NSString*> *rendererKeys, *rendererList;
@property(nonatomic, weak) UIImageView *cursorPreviewImageView;
@property(nonatomic, weak) UIViewController *cursorPreviewController;
@property(nonatomic) BOOL importingLauncherConfiguration;
@end

@implementation LauncherPreferencesViewController

- (UIColor *)colorFromPreferenceValue:(NSString *)value {
    NSDictionary *namedColors = @{
        @"white": UIColor.whiteColor,
        @"black": UIColor.blackColor,
        @"red": UIColor.systemRedColor,
        @"blue": UIColor.systemBlueColor,
        @"green": UIColor.systemGreenColor,
        @"yellow": UIColor.systemYellowColor,
        @"orange": UIColor.systemOrangeColor,
        @"purple": UIColor.systemPurpleColor,
        @"pink": UIColor.systemPinkColor,
        @"cyan": UIColor.cyanColor,
        @"magenta": UIColor.magentaColor
    };
    UIColor *named = namedColors[value];
    if (named) return named;
    NSString *hex = [value stringByReplacingOccurrencesOfString:@"#" withString:@""];
    unsigned int rgb = 0;
    NSScanner *scanner = [NSScanner scannerWithString:hex];
    if (hex.length == 6 && [scanner scanHexInt:&rgb] && scanner.isAtEnd) {
        return [UIColor colorWithRed:((rgb >> 16) & 0xFF) / 255.0 green:((rgb >> 8) & 0xFF) / 255.0 blue:(rgb & 0xFF) / 255.0 alpha:1.0];
    }
    return UIColor.whiteColor;
}

- (void)chooseMouseCursorColor {
    UIColorPickerViewController *picker = [UIColorPickerViewController new];
    picker.delegate = self;
    picker.supportsAlpha = NO;
    picker.selectedColor = [self colorFromPreferenceValue:getPrefObject(@"control.mouse_cursor_color")];
    [self presentViewController:picker animated:YES completion:nil];
}

- (UIImage *)cursorPreviewCrosshairImage {
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(16, 16), NO, 1.0);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(context, UIColor.blackColor.CGColor);
    CGContextFillRect(context, CGRectMake(5, 0, 6, 7));
    CGContextFillRect(context, CGRectMake(5, 9, 6, 7));
    CGContextFillRect(context, CGRectMake(0, 5, 7, 6));
    CGContextFillRect(context, CGRectMake(9, 5, 7, 6));
    CGContextSetFillColorWithColor(context, [self colorFromPreferenceValue:getPrefObject(@"control.mouse_cursor_color")].CGColor);
    CGContextFillRect(context, CGRectMake(7, 0, 2, 6));
    CGContextFillRect(context, CGRectMake(7, 10, 2, 6));
    CGContextFillRect(context, CGRectMake(0, 7, 6, 2));
    CGContextFillRect(context, CGRectMake(10, 7, 6, 2));
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

- (void)refreshCursorPreview {
    NSString *shape = getPrefObject(@"control.mouse_cursor_shape");
    NSString *style = getPrefObject(@"control.mouse_cursor_style");
    UIImage *image = nil;
    if ([shape isEqualToString:@"image"]) {
        NSString *path = getPrefObject(@"control.mouse_cursor_image");
        image = path.length ? [UIImage imageWithContentsOfFile:path] : nil;
    }
    if (!image && [style isEqualToString:@"minecraft"]) image = [UIImage imageNamed:@"MousePointer"];
    if (!image && [shape isEqualToString:@"crosshair"]) image = [self cursorPreviewCrosshairImage];
    if (!image) {
        NSString *symbol = @"arrow.up.left";
        if ([shape isEqualToString:@"crosshair"]) symbol = @"plus";
        else if ([shape isEqualToString:@"circle"]) symbol = @"circle.fill";
        else if ([shape isEqualToString:@"hand"]) symbol = @"hand.point.up.left.fill";
        image = [[UIImage systemImageNamed:symbol] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    }
    self.cursorPreviewImageView.image = image;
    self.cursorPreviewImageView.tintColor = ([style isEqualToString:@"minecraft"] || [shape isEqualToString:@"crosshair"] || [shape isEqualToString:@"image"]) ? nil : [self colorFromPreferenceValue:getPrefObject(@"control.mouse_cursor_color")];
}

- (void)showCursorPreview {
    UIViewController *preview = [UIViewController new];
    preview.title = localize(@"preference.title.mouse_cursor_preview", nil);
    preview.view.backgroundColor = UIColor.systemBackgroundColor;
    UIImageView *imageView = [UIImageView new];
    imageView.translatesAutoresizingMaskIntoConstraints = NO;
    imageView.contentMode = UIViewContentModeScaleAspectFit;
    imageView.backgroundColor = UIColor.blackColor;
    imageView.layer.cornerRadius = 18;
    imageView.clipsToBounds = YES;
    [preview.view addSubview:imageView];
    UIButton *colorButton = [UIButton buttonWithType:UIButtonTypeSystem];
    colorButton.translatesAutoresizingMaskIntoConstraints = NO;
    [colorButton setTitle:localize(@"preference.title.mouse_cursor_custom_color", nil) forState:UIControlStateNormal];
    [colorButton addTarget:self action:@selector(chooseMouseCursorColor) forControlEvents:UIControlEventTouchUpInside];
    [preview.view addSubview:colorButton];
    [NSLayoutConstraint activateConstraints:@[
        [imageView.centerXAnchor constraintEqualToAnchor:preview.view.centerXAnchor],
        [imageView.centerYAnchor constraintEqualToAnchor:preview.view.centerYAnchor constant:-24],
        [imageView.widthAnchor constraintEqualToConstant:180],
        [imageView.heightAnchor constraintEqualToConstant:180],
        [colorButton.topAnchor constraintEqualToAnchor:imageView.bottomAnchor constant:24],
        [colorButton.centerXAnchor constraintEqualToAnchor:preview.view.centerXAnchor]
    ]];
    self.cursorPreviewImageView = imageView;
    self.cursorPreviewController = preview;
    [self refreshCursorPreview];
    preview.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(closeCursorPreview)];
    UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:preview];
    navigation.modalPresentationStyle = UIModalPresentationFormSheet;
    [self presentViewController:navigation animated:YES completion:nil];
}

- (void)closeCursorPreview {
    [self.cursorPreviewController.navigationController dismissViewControllerAnimated:YES completion:nil];
}

- (void)colorPickerViewControllerDidSelectColor:(UIColorPickerViewController *)viewController {
    CGFloat red, green, blue, alpha;
    if (![viewController.selectedColor getRed:&red green:&green blue:&blue alpha:&alpha]) return;
    NSString *hex = [NSString stringWithFormat:@"#%02X%02X%02X", (int)round(red * 255), (int)round(green * 255), (int)round(blue * 255)];
    setPrefObject(@"control.mouse_cursor_color", hex);
    setPrefObject(@"control.mouse_cursor_style", @"custom");
    [[NSNotificationCenter defaultCenter] postNotificationName:@"AmethystMouseCursorAppearanceDidChange" object:nil];
    [self refreshCursorPreview];
}

- (void)exportLauncherConfiguration {
    NSDictionary *config = getLauncherConfigForExport();
    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:config options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys error:&error];
    if (!data) {
        showDialog(localize(@"Error", nil), error.localizedDescription ?: @"Could not export launcher configuration.");
        return;
    }
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:@"Amethyst-Launcher-Backup.json"];
    if (![data writeToFile:path options:NSDataWritingAtomic error:&error]) {
        showDialog(localize(@"Error", nil), error.localizedDescription ?: @"Could not save launcher configuration.");
        return;
    }
    UIActivityViewController *activity = [[UIActivityViewController alloc] initWithActivityItems:@[[NSURL fileURLWithPath:path]] applicationActivities:nil];
    activity.popoverPresentationController.sourceView = self.view;
    activity.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 1, 1);
    [self presentViewController:activity animated:YES completion:nil];
}

- (void)importLauncherConfiguration {
    self.importingLauncherConfiguration = YES;
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[[UTType typeWithIdentifier:@"public.json"]] asCopy:YES];
    picker.delegate = self;
    picker.allowsMultipleSelection = NO;
    picker.modalPresentationStyle = UIModalPresentationFormSheet;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)importMouseCursorImage {
    UIAlertController *sourcePicker = [UIAlertController alertControllerWithTitle:localize(@"preference.title.mouse_cursor_image", nil) message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    [sourcePicker addAction:[UIAlertAction actionWithTitle:localize(@"preference.title.import_photo_library", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        PHPickerConfiguration *configuration = [PHPickerConfiguration new];
        configuration.filter = PHPickerFilter.imagesFilter;
        configuration.selectionLimit = 1;
        PHPickerViewController *picker = [[PHPickerViewController alloc] initWithConfiguration:configuration];
        picker.delegate = self;
        [self presentViewController:picker animated:YES completion:nil];
    }]];
    [sourcePicker addAction:[UIAlertAction actionWithTitle:localize(@"preference.title.import_files", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[[UTType typeWithIdentifier:@"public.image"]] asCopy:YES];
        picker.delegate = self;
        picker.allowsMultipleSelection = NO;
        picker.modalPresentationStyle = UIModalPresentationFormSheet;
        [self presentViewController:picker animated:YES completion:nil];
    }]];
    [sourcePicker addAction:[UIAlertAction actionWithTitle:localize(@"Cancel", nil) style:UIAlertActionStyleCancel handler:nil]];
    sourcePicker.popoverPresentationController.sourceView = self.view;
    sourcePicker.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 1, 1);
    [self presentViewController:sourcePicker animated:YES completion:nil];
}

- (void)saveCursorImageData:(NSData *)data extension:(NSString *)extension {
    const char *home = getenv("AME_HOME");
    if (!home || !data.length) {
        showDialog(localize(@"Error", nil), @"Could not access the Amethyst data directory or selected image.");
        return;
    }
    NSString *destination = [NSString stringWithFormat:@"%s/custom_mouse_cursor.%@", home, extension];
    NSError *error = nil;
    NSString *oldPath = getPrefObject(@"control.mouse_cursor_image");
    if (oldPath.length && [NSFileManager.defaultManager fileExistsAtPath:oldPath]) [NSFileManager.defaultManager removeItemAtPath:oldPath error:nil];
    if (![data writeToFile:destination options:NSDataWritingAtomic error:&error]) {
        showDialog(localize(@"Error", nil), error.localizedDescription ?: @"Could not save the selected image.");
        return;
    }
    setPrefObject(@"control.mouse_cursor_image", destination);
    setPrefObject(@"control.mouse_cursor_style", @"custom");
    setPrefObject(@"control.mouse_cursor_shape", @"image");
    [[NSNotificationCenter defaultCenter] postNotificationName:@"AmethystMouseCursorAppearanceDidChange" object:nil];
    [self refreshCursorPreview];
    showDialog(@"Cursor image imported", @"Your image will be used as the custom mouse cursor.");
    [self.tableView reloadData];
}

- (void)picker:(PHPickerViewController *)picker didFinishPicking:(NSArray<PHPickerResult *> *)results {
    [picker dismissViewControllerAnimated:YES completion:nil];
    NSItemProvider *provider = results.firstObject.itemProvider;
    if (![provider canLoadObjectOfClass:UIImage.class]) return;
    [provider loadObjectOfClass:UIImage.class completionHandler:^(UIImage *image, NSError *error) {
        NSData *data = image ? UIImagePNGRepresentation(image) : nil;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error || !data) {
                showDialog(localize(@"Error", nil), error.localizedDescription ?: @"Could not load the selected photo.");
                return;
            }
            [self saveCursorImageData:data extension:@"png"];
        });
    }];
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller {
    self.importingLauncherConfiguration = NO;
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSURL *source = urls.firstObject;
    if (self.importingLauncherConfiguration) {
        self.importingLauncherConfiguration = NO;
        if (!source) return;
        NSData *backupData = [NSData dataWithContentsOfURL:source];
        NSDictionary *backup = backupData ? [NSJSONSerialization JSONObjectWithData:backupData options:NSJSONReadingMutableContainers error:nil] : nil;
        if (![backup isKindOfClass:NSDictionary.class] || ![backup[@"format"] isEqualToString:@"Amethyst Launcher Configuration"] || [backup[@"format_version"] integerValue] != 1) {
            showDialog(localize(@"Error", nil), @"This is not a valid Amethyst launcher backup.");
            return;
        }
        importLauncherConfigFromDictionary(backup);
        [[NSNotificationCenter defaultCenter] postNotificationName:@"AmethystMouseCursorAppearanceDidChange" object:nil];
        [self.tableView reloadData];
        showDialog(localize(@"preference.title.import_launcher_config", nil), @"Launcher settings and touch-control layouts were imported.");
        return;
    }
    if (!source) return;

    NSString *extension = source.pathExtension.lowercaseString;
    NSSet *supportedExtensions = [NSSet setWithArray:@[@"png", @"jpg", @"jpeg", @"heic", @"webp"]];
    if (![supportedExtensions containsObject:extension]) {
        showDialog(localize(@"Error", nil), @"Choose a PNG, JPG, JPEG, HEIC, or WebP image.");
        return;
    }

    NSData *imageData = [NSData dataWithContentsOfURL:source];
    if (!imageData) {
        showDialog(localize(@"Error", nil), @"Could not read the selected image.");
        return;
    }
    [self saveCursorImageData:imageData extension:extension];
}

- (id)init {
    self = [super init];
    self.title = localize(@"Settings", nil);
    return self;
}

- (NSString *)imageName {
    return @"MenuSettings";
}

- (void)viewDidLoad
{
    self.getPreference = ^id(NSString *section, NSString *key){
        NSString *keyFull = [NSString stringWithFormat:@"%@.%@", section, key];
        return getPrefObject(keyFull);
    };
    self.setPreference = ^(NSString *section, NSString *key, id value){
        NSString *keyFull = [NSString stringWithFormat:@"%@.%@", section, key];
        setPrefObject(keyFull, value);
        if ([section isEqualToString:@"control"] &&
            [@[@"mouse_cursor_style", @"mouse_cursor_shape", @"mouse_cursor_color", @"mouse_cursor_image", @"mouse_cursor_hotspot"] containsObject:key]) {
            [[NSNotificationCenter defaultCenter] postNotificationName:@"AmethystMouseCursorAppearanceDidChange" object:nil];
        }
    };
    
    self.hasDetail = YES;
    self.prefDetailVisible = self.navigationController == nil;
    
    self.prefSections = @[@"general", @"video", @"control", @"java", @"debug"];

    self.rendererKeys = getRendererKeys(NO);
    self.rendererList = getRendererNames(NO);
    
    BOOL(^whenNotInGame)() = ^BOOL(){
        return self.navigationController != nil;
    };
    self.prefContents = @[
        @[
            // General settings
            @{@"icon": @"cube"},
            @{@"key": @"curseforge_api_key", @"icon": @"key", @"type": self.typeButton,
              @"enableCondition": whenNotInGame, @"action": ^void(){ [self editCurseForgeKey]; }},
            @{@"key": @"check_sha",
              @"hasDetail": @YES,
              @"icon": @"lock.shield",
              @"type": self.typeSwitch,
              @"enableCondition": whenNotInGame
            },
            @{@"key": @"cosmetica",
              @"hasDetail": @YES,
              @"icon": @"eyeglasses",
              @"type": self.typeSwitch,
              @"enableCondition": whenNotInGame
            },
            @{@"key": @"debug_logging",
              @"hasDetail": @YES,
              @"icon": @"doc.badge.gearshape",
              @"type": self.typeSwitch,
              @"action": ^(BOOL enabled){
                  debugLogEnabled = enabled;
                  NSLog(@"[Debugging] Debug log enabled: %@", enabled ? @"YES" : @"NO");
              }
            },
            @{@"key": @"appicon",
              @"hasDetail": @YES,
              @"icon": @"paintbrush",
              @"type": self.typePickField,
              @"enableCondition": ^BOOL(){
                  return UIApplication.sharedApplication.supportsAlternateIcons;
              },
              @"action": ^void(NSString *iconName) {
                  if ([iconName isEqualToString:@"AppIcon-Light"]) {
                      iconName = nil;
                  }
                  [UIApplication.sharedApplication setAlternateIconName:iconName completionHandler:^(NSError * _Nullable error) {
                      if (error == nil) return;
                      NSLog(@"Error in appicon: %@", error);
                      showDialog(localize(@"Error", nil), error.localizedDescription);
                  }];
              },
              @"pickKeys": @[
                  @"AppIcon-Light",
              ],
              @"pickList": @[
                  localize(@"preference.title.appicon-default", nil)
              ]
            },
            @{@"key": @"hidden_sidebar",
              @"hasDetail": @YES,
              @"icon": @"sidebar.leading",
              @"type": self.typeSwitch,
              @"enableCondition": whenNotInGame
            },
            @{@"key": @"export_launcher_config",
              @"icon": @"square.and.arrow.up",
              @"type": self.typeButton,
              @"suppressDoneAlert": @YES,
              @"enableCondition": whenNotInGame,
              @"action": ^void(){ [self exportLauncherConfiguration]; }
            },
            @{@"key": @"import_launcher_config",
              @"icon": @"square.and.arrow.down",
              @"type": self.typeButton,
              @"suppressDoneAlert": @YES,
              @"enableCondition": whenNotInGame,
              @"action": ^void(){ [self importLauncherConfiguration]; }
            },
            @{@"key": @"reset_warnings",
              @"icon": @"exclamationmark.triangle",
              @"type": self.typeButton,
              @"enableCondition": whenNotInGame,
              @"action": ^void(){
                  resetWarnings();
              }
            },
            @{@"key": @"reset_settings",
              @"icon": @"trash",
              @"type": self.typeButton,
              @"enableCondition": whenNotInGame,
              @"requestReload": @YES,
              @"showConfirmPrompt": @YES,
              @"destructive": @YES,
              @"action": ^void(){
                  loadPreferences(YES);
                  [self.tableView reloadData];
              }
            },
            @{@"key": @"erase_demo_data",
              @"icon": @"trash",
              @"type": self.typeButton,
              @"enableCondition": ^BOOL(){
                  NSString *demoPath = [NSString stringWithFormat:@"%s/.demo", getenv("AME_HOME")];
                  int count = [NSFileManager.defaultManager contentsOfDirectoryAtPath:demoPath error:nil].count;
                  return whenNotInGame() && count > 0;
              },
              @"showConfirmPrompt": @YES,
              @"destructive": @YES,
              @"action": ^void(){
                  NSString *demoPath = [NSString stringWithFormat:@"%s/.demo", getenv("AME_HOME")];
                  NSError *error;
                  if([NSFileManager.defaultManager removeItemAtPath:demoPath error:&error]) {
                      [NSFileManager.defaultManager createDirectoryAtPath:demoPath
                                              withIntermediateDirectories:YES attributes:nil error:nil];
                      [NSFileManager.defaultManager changeCurrentDirectoryPath:demoPath];
                      if (getenv("DEMO_LOCK")) {
                          [(LauncherNavigationController *)self.navigationController fetchLocalVersionList];
                      }
                  } else {
                      NSLog(@"Error in erase_demo_data: %@", error);
                      showDialog(localize(@"Error", nil), error.localizedDescription);
                  }
              }
            }
        ], @[
            // Video and renderer settings
            @{@"icon": @"video"},
            @{@"key": @"renderer",
              @"hasDetail": @YES,
              @"icon": @"cpu",
              @"type": self.typePickField,
              @"enableCondition": whenNotInGame,
              @"pickKeys": self.rendererKeys,
              @"pickList": self.rendererList
            },
            @{@"key": @"resolution",
              @"hasDetail": @YES,
              @"icon": @"viewfinder",
              @"type": self.typeSlider,
              @"min": @(25),
              @"max": @(150)
            },
            @{@"key": @"max_framerate",
              @"hasDetail": @YES,
              @"icon": @"timelapse",
              @"type": self.typeSwitch,
              @"enableCondition": ^BOOL(){
                  return whenNotInGame() && (UIScreen.mainScreen.maximumFramesPerSecond > 60);
              }
            },
            @{@"key": @"performance_hud",
              @"hasDetail": @YES,
              @"icon": @"waveform.path.ecg",
              @"type": self.typeSwitch,
              @"enableCondition": ^BOOL(){
                  return [CAMetalLayer instancesRespondToSelector:@selector(developerHUDProperties)];
              }
            },
            @{@"key": @"mobilegl_fast_shader_load",
              @"hasDetail": @YES,
              @"icon": @"hare",
              @"type": self.typeSwitch,
              @"enableCondition": whenNotInGame
            },
            @{@"key": @"mobilegl_buffer_compat",
              @"hasDetail": @YES,
              @"icon": @"square.stack.3d.up",
              @"type": self.typeSwitch,
              @"enableCondition": whenNotInGame
            },
            @{@"key": @"mobilegl_relaxed",
              @"hasDetail": @YES,
              @"icon": @"slider.horizontal.3",
              @"type": self.typeSwitch,
              @"enableCondition": whenNotInGame
            },
            @{@"key": @"moltenvk_fast_math",
              @"hasDetail": @YES,
              @"icon": @"bolt",
              @"type": self.typeSwitch,
              @"enableCondition": whenNotInGame
            },
            @{@"key": @"moltenvk_argument_buffers",
              @"hasDetail": @YES,
              @"icon": @"square.grid.3x3",
              @"type": self.typeSwitch,
              @"enableCondition": whenNotInGame
            },
            @{@"key": @"moltenvk_smooth_scaling",
              @"hasDetail": @YES,
              @"icon": @"arrow.up.left.and.arrow.down.right",
              @"type": self.typeSwitch,
              @"enableCondition": whenNotInGame
            },
            @{@"key": @"fullscreen_airplay",
              @"hasDetail": @YES,
              @"icon": @"airplayvideo",
              @"type": self.typeSwitch,
              @"action": ^(BOOL enabled){
                  if (self.navigationController != nil) return;
                  if (UIApplication.sharedApplication.connectedScenes.count < 2) return;
                  if (enabled) {
                      [self.presentingViewController performSelector:@selector(switchToExternalDisplay)];
                  } else {
                      [self.presentingViewController performSelector:@selector(switchToInternalDisplay)];
                  }
              }
            },
            @{@"key": @"silence_other_audio",
              @"hasDetail": @YES,
              @"icon": @"speaker.slash",
              @"type": self.typeSwitch
            },
            @{@"key": @"silence_with_switch",
              @"hasDetail": @YES,
              @"icon": @"speaker.zzz",
              @"type": self.typeSwitch
            },
            @{@"key": @"allow_microphone",
              @"hasDetail": @YES,
              @"icon": @"mic",
              @"type": self.typeSwitch
            },
        ], @[
            // Control settings
            @{@"icon": @"gamecontroller"},
            @{@"key": @"default_gamepad_ctrl",
                @"icon": @"hammer",
                @"type": self.typeChildPane,
                @"enableCondition": whenNotInGame,
                @"canDismissWithSwipe": @NO,
                @"class": LauncherPrefContCfgViewController.class
            },
            @{@"key": @"hardware_hide",
                @"icon": @"eye.slash",
                @"hasDetail": @YES,
                @"type": self.typeSwitch,
            },
            @{@"key": @"recording_hide",
                @"icon": @"eye.slash",
                @"hasDetail": @YES,
                @"type": self.typeSwitch,
            },
            @{@"key": @"gesture_mouse",
                @"icon": @"cursorarrow.click",
                @"hasDetail": @YES,
                @"type": self.typeSwitch,
            },
            @{@"key": @"gesture_hotbar",
                @"icon": @"hand.tap",
                @"hasDetail": @YES,
                @"type": self.typeSwitch,
            },
            @{@"key": @"disable_haptics",
                @"icon": @"wave.3.left",
                @"hasDetail": @NO,
                @"type": self.typeSwitch,
            },
            @{@"key": @"slideable_hotbar",
                @"hasDetail": @YES,
                @"icon": @"slider.horizontal.below.rectangle",
                @"type": self.typeSwitch
            },
            @{@"key": @"press_duration",
                @"hasDetail": @YES,
                @"icon": @"cursorarrow.click.badge.clock",
                @"type": self.typeSlider,
                @"min": @(100),
                @"max": @(1000),
            },
            @{@"key": @"button_scale",
                @"hasDetail": @YES,
                @"icon": @"aspectratio",
                @"type": self.typeSlider,
                @"min": @(50), // 80?
                @"max": @(500)
            },
            @{@"key": @"mouse_scale",
                @"hasDetail": @YES,
                @"icon": @"arrow.up.left.and.arrow.down.right.circle",
                @"type": self.typeSlider,
                @"min": @(25),
                @"max": @(300)
            },
            @{@"key": @"mouse_speed",
                @"hasDetail": @YES,
                @"icon": @"cursorarrow.motionlines",
                @"type": self.typeSlider,
                @"min": @(25),
                @"max": @(300)
            },
            @{@"key": @"virtmouse_enable",
                @"hasDetail": @YES,
                @"icon": @"cursorarrow.rays",
                @"type": self.typeSwitch
            },
            @{@"key": @"mouse_cursor_style",
                @"hasDetail": @YES,
                @"icon": @"cursorarrow",
                @"type": self.typePickField,
                @"pickKeys": @[@"minecraft", @"custom"],
                @"pickList": @[@"Minecraft-style arrow", @"Custom pointer"]
            },
            @{@"key": @"mouse_cursor_image",
                @"icon": @"photo.badge.plus",
                @"type": self.typeButton,
                @"action": ^void(){
                    [self importMouseCursorImage];
                }
            },
            @{@"key": @"mouse_cursor_shape",
                @"hasDetail": @YES,
                @"icon": @"cursorarrow.motionlines",
                @"type": self.typePickField,
                @"pickKeys": @[@"arrow", @"crosshair", @"circle", @"hand", @"image"],
                @"pickList": @[@"Arrow", @"Crosshair", @"Circle", @"Hand", @"Imported image"],
                @"action": ^void(NSString *shape) {
                    self.setPreference(@"control", @"mouse_cursor_style", @"custom");
                }
            },
            @{@"key": @"mouse_cursor_color",
                @"icon": @"paintpalette",
                @"type": self.typeButton,
                @"suppressDoneAlert": @YES,
                @"action": ^void(){ [self chooseMouseCursorColor]; }
            },
            @{@"key": @"mouse_cursor_preview",
                @"icon": @"eye",
                @"type": self.typeButton,
                @"suppressDoneAlert": @YES,
                @"action": ^void(){ [self showCursorPreview]; }
            },
            @{@"key": @"mouse_cursor_hotspot",
                @"hasDetail": @YES,
                @"icon": @"scope",
                @"type": self.typePickField,
                @"pickKeys": @[@"top_left", @"center", @"bottom_right"],
                @"pickList": @[@"Top-left", @"Center", @"Bottom-right"]
            },
            @{@"key": @"gyroscope_enable",
                @"hasDetail": @YES,
                @"icon": @"gyroscope",
                @"type": self.typeSwitch,
                @"enableCondition": ^BOOL(){
                    return realUIIdiom != UIUserInterfaceIdiomTV;
                }
            },
            @{@"key": @"gyroscope_invert_x_axis",
                @"hasDetail": @YES,
                @"icon": @"arrow.left.and.right",
                @"type": self.typeSwitch,
                @"enableCondition": ^BOOL(){
                    return realUIIdiom != UIUserInterfaceIdiomTV;
                }
            },
            @{@"key": @"gyroscope_sensitivity",
                @"hasDetail": @YES,
                @"icon": @"move.3d",
                @"type": self.typeSlider,
                @"min": @(50),
                @"max": @(300),
                @"enableCondition": ^BOOL(){
                    return realUIIdiom != UIUserInterfaceIdiomTV;
                }
            }
        ], @[
        // Java tweaks
            @{@"icon": @"sparkles"},
            @{@"key": @"manage_runtime",
                @"hasDetail": @YES,
                @"icon": @"cube",
                @"type": self.typeChildPane,
                @"canDismissWithSwipe": @YES,
                @"class": LauncherPrefManageJREViewController.class,
                @"enableCondition": whenNotInGame
            },
            @{@"key": @"java_args",
                @"hasDetail": @YES,
                @"icon": @"slider.vertical.3",
                @"type": self.typeTextField,
                @"enableCondition": whenNotInGame
            },
            @{@"key": @"env_variables",
                @"hasDetail": @YES,
                @"icon": @"terminal",
                @"type": self.typeTextField,
                @"enableCondition": whenNotInGame
            },
            @{@"key": @"auto_ram",
                @"hasDetail": @YES,
                @"icon": @"slider.horizontal.3",
                @"type": self.typeSwitch,
                @"enableCondition": whenNotInGame,
                @"warnCondition": ^BOOL(){
                    return !isJailbroken;
                },
                @"warnKey": @"auto_ram_warn",
                @"requestReload": @YES
            },
            @{@"key": @"allocated_memory",
                @"hasDetail": @YES,
                @"icon": @"memorychip",
                @"type": self.typeSlider,
                @"min": @(250),
                @"max": @((NSProcessInfo.processInfo.physicalMemory / 1048576) * 0.85),
                @"enableCondition": ^BOOL(){
                    return !getPrefBool(@"java.auto_ram") && whenNotInGame();
                },
                @"warnCondition": ^BOOL(DBNumberedSlider *view){
                    return view.value >= NSProcessInfo.processInfo.physicalMemory / 1048576 * 0.37;
                },
                @"warnKey": @"mem_warn"
            }
        ], @[
            // Debug settings - only recommended for developer use
            @{@"icon": @"ladybug"},
            @{@"key": @"debug_always_attached_jit",
                @"hasDetail": @YES,
                @"icon": @"app.connected.to.app.below.fill",
                @"type": self.typeSwitch,
                @"enableCondition": ^BOOL(){
                    return DeviceHasJITFlags(JIT_FLAG_FORCE_MIRRORED | JIT_FLAG_HAS_TXM) && whenNotInGame();
                },
            },
            @{@"key": @"debug_skip_wait_jit",
                @"hasDetail": @YES,
                @"icon": @"forward",
                @"type": self.typeSwitch,
                @"enableCondition": whenNotInGame
            },
            @{@"key": @"debug_hide_home_indicator",
                @"hasDetail": @YES,
                @"icon": @"iphone.and.arrow.forward",
                @"type": self.typeSwitch,
                @"enableCondition": ^BOOL(){
                    return
                        self.splitViewController.view.safeAreaInsets.bottom > 0 ||
                        self.view.safeAreaInsets.bottom > 0;
                }
            },
            @{@"key": @"debug_ipad_ui",
                @"hasDetail": @YES,
                @"icon": @"ipad",
                @"type": self.typeSwitch,
                @"enableCondition": whenNotInGame
            },
            @{@"key": @"debug_auto_correction",
                @"hasDetail": @YES,
                @"icon": @"textformat.abc.dottedunderline",
                @"type": self.typeSwitch
            }
        ]
    ];

    [super viewDidLoad];
    if (self.navigationController == nil) {
        self.tableView.alpha = 0.9;
    }
    if (NSProcessInfo.processInfo.isMacCatalystApp) {
        UIButton *closeButton = [UIButton buttonWithType:UIButtonTypeClose];
        closeButton.frame = CGRectOffset(closeButton.frame, 10, 10);
        [closeButton addTarget:self action:@selector(actionClose) forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:closeButton];
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    if (self.navigationController == nil) {
        [self.presentingViewController performSelector:@selector(updatePreferenceChanges)];
    }
}

- (void)actionClose {
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark UITableView

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 0) { // Add to general section
        return [NSString stringWithFormat:@"Angel Aura Amethyst %@-%s (%s/%s)\n%@ on %@ (%s)\nPID: %d",
            NSBundle.mainBundle.infoDictionary[@"CFBundleShortVersionString"],
            CONFIG_TYPE, CONFIG_BRANCH, CONFIG_COMMIT,
            UIDevice.currentDevice.completeOSVersion, [HostManager GetModelName], getenv("AME_DETECTEDINST"), getpid()];
    }

    NSString *footer = NSLocalizedStringWithDefaultValue(([NSString stringWithFormat:@"preference.section.footer.%@", self.prefSections[section]]), @"Localizable", NSBundle.mainBundle, @" ", nil);
    if ([footer isEqualToString:@" "]) {
        return nil;
    }
    return footer;
}

- (void)editCurseForgeKey {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:localize(@"preference.title.curseforge_api_key", nil) message:localize(@"preference.description.curseforge_api_key", nil) preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.secureTextEntry = YES; field.autocorrectionType = UITextAutocorrectionTypeNo;
        field.autocapitalizationType = UITextAutocapitalizationTypeNone;
        field.textContentType = @"";
        field.placeholder = [CurseForgeAPI isConfigured] ? localize(@"content.curseforge.key_present", nil) : localize(@"content.curseforge.key_placeholder", nil);
    }];
    [alert addAction:[UIAlertAction actionWithTitle:localize(@"Cancel", nil) style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:localize(@"Save", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *key = alert.textFields.firstObject.text;
        if (!key.length) return;
        NSError *error;
        if (![CurseForgeAPI setAPIKey:key error:&error]) showDialog(localize(@"Error", nil), error.localizedDescription);
    }]];
    if ([CurseForgeAPI isConfigured]) [alert addAction:[UIAlertAction actionWithTitle:localize(@"content.curseforge.remove_key", nil) style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        NSError *error;
        if (![CurseForgeAPI setAPIKey:@"" error:&error]) showDialog(localize(@"Error", nil), error.localizedDescription);
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
