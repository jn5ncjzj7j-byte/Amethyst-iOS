#import "LauncherSplitViewController.h"
#import "LauncherMenuViewController.h"
#import "LauncherProfilesViewController.h"
#import "LauncherNavigationController.h"
#import "LauncherPreferences.h"
#import "utils.h"
#import <GameController/GameController.h>

extern NSMutableDictionary *prefDict;

static UIImage *AMOutlinedCursorImage(UIImage *image, UIColor *tintColor, CGFloat borderWidth) {
    if (!image || borderWidth <= 0.0) return image;
    UIImage *foreground = image;
    if (image.renderingMode == UIImageRenderingModeAlwaysTemplate && tintColor) {
        foreground = [image imageWithTintColor:tintColor renderingMode:UIImageRenderingModeAlwaysOriginal];
    }
    UIImage *outline = [foreground imageWithTintColor:UIColor.blackColor renderingMode:UIImageRenderingModeAlwaysOriginal];
    CGFloat scale = foreground.scale > 0.0 ? foreground.scale : UIScreen.mainScreen.scale;
    CGSize outputSize = CGSizeMake(foreground.size.width + borderWidth * 2.0, foreground.size.height + borderWidth * 2.0);
    UIGraphicsBeginImageContextWithOptions(outputSize, NO, scale);
    for (NSInteger x = -1; x <= 1; x++) {
        for (NSInteger y = -1; y <= 1; y++) {
            if (x == 0 && y == 0) continue;
            [outline drawAtPoint:CGPointMake(borderWidth + x * borderWidth, borderWidth + y * borderWidth)];
        }
    }
    [foreground drawAtPoint:CGPointMake(borderWidth, borderWidth)];
    UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return [result imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
}
@interface LauncherSplitViewController ()<UISplitViewControllerDelegate, UIPointerInteractionDelegate>{
}
@property(nonatomic) BOOL hasConfiguredInitialLayout;
@end

@implementation LauncherSplitViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithRed:5.0/255.0 green:6.0/255.0 blue:16.0/255.0 alpha:1.0];
    self.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;

    UINavigationBarAppearance *navigationAppearance = [UINavigationBarAppearance new];
    navigationAppearance.backgroundEffect = nil;
    navigationAppearance.backgroundColor = [UIColor colorWithRed:7.0/255.0 green:8.0/255.0 blue:19.0/255.0 alpha:1.0];
    navigationAppearance.shadowColor = [UIColor colorWithRed:48.0/255.0 green:37.0/255.0 blue:79.0/255.0 alpha:1.0];
    navigationAppearance.titleTextAttributes = @{NSForegroundColorAttributeName: UIColor.whiteColor};
    navigationAppearance.largeTitleTextAttributes = @{NSForegroundColorAttributeName: UIColor.whiteColor};
    UINavigationBar *navigationBar = UINavigationBar.appearance;
    navigationBar.standardAppearance = navigationAppearance;
    navigationBar.scrollEdgeAppearance = navigationAppearance;
    navigationBar.compactAppearance = navigationAppearance;
    navigationBar.translucent = NO;
    navigationBar.tintColor = [UIColor colorWithRed:190.0/255.0 green:145.0/255.0 blue:255.0/255.0 alpha:1.0];

    UIToolbarAppearance *toolbarAppearance = [UIToolbarAppearance new];
    toolbarAppearance.backgroundEffect = nil;
    toolbarAppearance.backgroundColor = [UIColor colorWithRed:7.0/255.0 green:8.0/255.0 blue:19.0/255.0 alpha:1.0];
    toolbarAppearance.shadowColor = [UIColor colorWithRed:48.0/255.0 green:37.0/255.0 blue:79.0/255.0 alpha:1.0];
    UIToolbar *toolbar = UIToolbar.appearance;
    toolbar.standardAppearance = toolbarAppearance;
    toolbar.compactAppearance = toolbarAppearance;
    toolbar.scrollEdgeAppearance = toolbarAppearance;
    toolbar.translucent = NO;
    toolbar.tintColor = [UIColor colorWithRed:190.0/255.0 green:145.0/255.0 blue:255.0/255.0 alpha:1.0];

    UITableView *tableAppearance = UITableView.appearance;
    tableAppearance.backgroundColor = [UIColor colorWithRed:8.0/255.0 green:9.0/255.0 blue:21.0/255.0 alpha:1.0];
    tableAppearance.separatorColor = [UIColor colorWithRed:43.0/255.0 green:37.0/255.0 blue:65.0/255.0 alpha:1.0];
    UITableViewCell.appearance.backgroundColor = [UIColor colorWithRed:8.0/255.0 green:9.0/255.0 blue:21.0/255.0 alpha:1.0];
    UISearchBar.appearance.barTintColor = [UIColor colorWithRed:8.0/255.0 green:9.0/255.0 blue:21.0/255.0 alpha:1.0];
    UISearchBar.appearance.tintColor = [UIColor colorWithRed:190.0/255.0 green:145.0/255.0 blue:255.0/255.0 alpha:1.0];
    if ([getPrefObject(@"control.control_safe_area") length] == 0) {
        setPrefObject(@"control.control_safe_area", NSStringFromUIEdgeInsets(getDefaultSafeArea()));
    }

    self.delegate = self;
    UIPointerInteraction *systemPointerInteraction = [[UIPointerInteraction alloc] initWithDelegate:self];
    [self.view addInteraction:systemPointerInteraction];

    UINavigationController *masterVc = [[UINavigationController alloc] initWithRootViewController:[[LauncherMenuViewController alloc] init]];
    LauncherNavigationController *detailVc = [[LauncherNavigationController alloc] initWithRootViewController:[[LauncherProfilesViewController alloc] init]];
    detailVc.toolbarHidden = NO;

    self.viewControllers = @[masterVc, detailVc];
    self.minimumPrimaryColumnWidth = 250;
    self.maximumPrimaryColumnWidth = 330;
    self.preferredPrimaryColumnWidth = 290;
    self.launcherMousePointerView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 22, 22)];
    self.launcherMousePointerView.userInteractionEnabled = NO;
    self.launcherMousePointerView.hidden = YES;
    [self.view addSubview:self.launcherMousePointerView];
    self.launcherMouseHoverGesture = [[UIHoverGestureRecognizer alloc] initWithTarget:self action:@selector(updateLauncherMousePointer:)];
    self.launcherMouseHoverGesture.cancelsTouchesInView = NO;
    [self.view addGestureRecognizer:self.launcherMouseHoverGesture];
    self.launcherMouseConnectObserver = [NSNotificationCenter.defaultCenter addObserverForName:GCMouseDidConnectNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) {
        self.launcherMousePointerView.hidden = YES;
    }];
    self.launcherMouseDisconnectObserver = [NSNotificationCenter.defaultCenter addObserverForName:GCMouseDidDisconnectNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) {
        self.launcherMousePointerView.hidden = GCMouse.mice.count == 0;
    }];
    self.launcherMousePointerView.hidden = YES;
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(refreshLauncherMousePointerAppearance) name:@"AmethystMouseCursorAppearanceDidChange" object:nil];
    [self refreshLauncherMousePointerAppearance];
}

- (UIPointerStyle *)pointerInteraction:(UIPointerInteraction *)interaction styleForRegion:(UIPointerRegion *)region {
    return [UIPointerStyle hiddenPointerStyle];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (!self.hasConfiguredInitialLayout) {
        self.hasConfiguredInitialLayout = YES;
        [self applyLayoutForSize:self.view.bounds.size initial:YES];
    }
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self.view bringSubviewToFront:self.launcherMousePointerView];
}

- (void)updateLauncherMousePointer:(UIHoverGestureRecognizer *)gesture {
    if (GCMouse.mice.count == 0) {
        self.launcherMousePointerView.hidden = YES;
        return;
    }
    if (gesture.state == UIGestureRecognizerStateBegan || gesture.state == UIGestureRecognizerStateChanged) {
        CGPoint point = [gesture locationInView:self.view];
        self.launcherMousePointerView.frame = CGRectMake(point.x, point.y, self.launcherMousePointerView.frame.size.width, self.launcherMousePointerView.frame.size.height);
        self.launcherMousePointerView.hidden = NO;
    } else if (gesture.state == UIGestureRecognizerStateEnded || gesture.state == UIGestureRecognizerStateCancelled) {
        self.launcherMousePointerView.hidden = YES;
    }
}

- (void)refreshLauncherMousePointerAppearance {
    NSString *style = getPrefObject(@"control.mouse_cursor_style");
    NSString *shape = getPrefObject(@"control.mouse_cursor_shape");
    NSString *color = getPrefObject(@"control.mouse_cursor_color");
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
    UIColor *tint = namedColors[color] ?: UIColor.whiteColor;
    UIImage *image = nil;
    id radiusPreference = getPrefObject(@"control.mouse_cursor_corner_radius");
    CGFloat outlineWidth = radiusPreference && [radiusPreference doubleValue] > 0.0 ? 1.0 : 0.0;
    if ([style isEqualToString:@"minecraft"]) {
        image = [UIImage imageNamed:@"MousePointer"];
        image = AMOutlinedCursorImage(image, nil, outlineWidth);
    } else if ([shape isEqualToString:@"image"]) {
        NSString *path = getPrefObject(@"control.mouse_cursor_image");
        image = path.length ? [UIImage imageWithContentsOfFile:path] : nil;
    } else if ([shape isEqualToString:@"crosshair"]) {
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(24, 24), NO, 1.0);
        id radiusPreference = getPrefObject(@"control.mouse_cursor_corner_radius");
        CGFloat radius = MIN(4.0, MAX(0.0, radiusPreference ? [radiusPreference doubleValue] : 2.0));
        CGContextRef context = UIGraphicsGetCurrentContext();
        if (radius > 0.0) {
            CGFloat outlineRadius = MIN(5.0, radius + 1.0);
            CGContextSetFillColorWithColor(context, UIColor.blackColor.CGColor);
            [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(9, 1, 6, 22) cornerRadius:outlineRadius] fill];
            [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(1, 9, 22, 6) cornerRadius:outlineRadius] fill];
        }
        CGContextSetFillColorWithColor(context, tint.CGColor);
        [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(10, 2, 4, 20) cornerRadius:radius] fill];
        [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(2, 10, 20, 4) cornerRadius:radius] fill];
        image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    } else {
        NSString *symbol = @"arrow.up.left";
        if ([shape isEqualToString:@"circle"]) symbol = @"circle.fill";
        else if ([shape isEqualToString:@"hand"]) symbol = @"hand.point.up.left.fill";
        image = [[UIImage systemImageNamed:symbol] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    }
    if (![shape isEqualToString:@"crosshair"] && ![style isEqualToString:@"minecraft"]) {
        image = AMOutlinedCursorImage(image, [shape isEqualToString:@"image"] ? nil : tint, outlineWidth);
    }
    self.launcherMousePointerView.image = image;
    self.launcherMousePointerView.tintColor = nil;
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    [coordinator animateAlongsideTransition:nil completion:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        [self applyLayoutForSize:size initial:NO];
    }];
}

- (void)applyLayoutForSize:(CGSize)size initial:(BOOL)initial {
    if (size.width <= 0 || size.height <= 0) return;
    BOOL isPortrait = size.height > size.width;
    BOOL hideSidebar = getPrefBool(@"general.hidden_sidebar");
    UISplitViewControllerSplitBehavior behavior = isPortrait ?
        UISplitViewControllerSplitBehaviorOverlay :
        UISplitViewControllerSplitBehaviorTile;
    if (self.preferredSplitBehavior != behavior) {
        self.preferredSplitBehavior = behavior;
    }
    if (hideSidebar) {
        if (self.preferredDisplayMode != UISplitViewControllerDisplayModeSecondaryOnly) {
            self.preferredDisplayMode = UISplitViewControllerDisplayModeSecondaryOnly;
        }
    } else if (initial) {
        UISplitViewControllerDisplayMode mode = isPortrait ?
            UISplitViewControllerDisplayModeOneOverSecondary :
            UISplitViewControllerDisplayModeOneBesideSecondary;
        if (self.preferredDisplayMode != mode) {
            self.preferredDisplayMode = mode;
        }
    }
}

- (void)dismissViewController {
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
