#import "LauncherSplitViewController.h"
#import "LauncherMenuViewController.h"
#import "LauncherProfilesViewController.h"
#import "LauncherNavigationController.h"
#import "LauncherPreferences.h"
#import "utils.h"
#import <GameController/GameController.h>

extern NSMutableDictionary *prefDict;

@interface LauncherSplitViewController ()<UISplitViewControllerDelegate>{
}
@end

@implementation LauncherSplitViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.systemBackgroundColor;
    if ([getPrefObject(@"control.control_safe_area") length] == 0) {
        setPrefObject(@"control.control_safe_area", NSStringFromUIEdgeInsets(getDefaultSafeArea()));
    }

    self.delegate = self;

    UINavigationController *masterVc = [[UINavigationController alloc] initWithRootViewController:[[LauncherMenuViewController alloc] init]];
    LauncherNavigationController *detailVc = [[LauncherNavigationController alloc] initWithRootViewController:[[LauncherProfilesViewController alloc] init]];
    detailVc.toolbarHidden = NO;

    self.viewControllers = @[masterVc, detailVc];
    [self changeDisplayModeForSize:self.view.frame.size];

    self.maximumPrimaryColumnWidth = self.view.bounds.size.width * 0.95;
    self.launcherMousePointerView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 22, 22)];
    self.launcherMousePointerView.userInteractionEnabled = NO;
    self.launcherMousePointerView.hidden = YES;
    [self.view addSubview:self.launcherMousePointerView];
    self.launcherMouseHoverGesture = [[UIHoverGestureRecognizer alloc] initWithTarget:self action:@selector(updateLauncherMousePointer:)];
    self.launcherMouseHoverGesture.cancelsTouchesInView = NO;
    [self.view addGestureRecognizer:self.launcherMouseHoverGesture];
    self.launcherMouseConnectObserver = [NSNotificationCenter.defaultCenter addObserverForName:GCMouseDidConnectNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) {
        self.launcherMousePointerView.hidden = NO;
    }];
    self.launcherMouseDisconnectObserver = [NSNotificationCenter.defaultCenter addObserverForName:GCMouseDidDisconnectNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) {
        self.launcherMousePointerView.hidden = GCMouse.mice.count == 0;
    }];
    self.launcherMousePointerView.hidden = GCMouse.mice.count == 0;
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(refreshLauncherMousePointerAppearance) name:@"AmethystMouseCursorAppearanceDidChange" object:nil];
    [self refreshLauncherMousePointerAppearance];
}

- (void)splitViewController:(UISplitViewController *)svc willChangeToDisplayMode:(UISplitViewControllerDisplayMode)displayMode {
    if (self.preferredDisplayMode != displayMode && self.displayMode != UISplitViewControllerDisplayModeSecondaryOnly) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.preferredDisplayMode = UISplitViewControllerDisplayModeSecondaryOnly;
        });
    }
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
    if ([style isEqualToString:@"minecraft"]) {
        image = [UIImage imageNamed:@"MousePointer"];
    } else if ([shape isEqualToString:@"image"]) {
        NSString *path = getPrefObject(@"control.mouse_cursor_image");
        image = path.length ? [UIImage imageWithContentsOfFile:path] : nil;
    } else if ([shape isEqualToString:@"crosshair"]) {
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(16, 16), NO, 1.0);
        CGFloat radius = MIN(4.0, MAX(0.0, [getPrefObject(@"control.mouse_cursor_corner_radius") doubleValue]));
        CGContextRef context = UIGraphicsGetCurrentContext();
        CGContextSetFillColorWithColor(context, UIColor.blackColor.CGColor);
        [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(4, 0, 8, 16) cornerRadius:radius] fill];
        [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 4, 16, 8) cornerRadius:radius] fill];
        CGContextSetFillColorWithColor(context, tint.CGColor);
        [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(6, 0, 4, 16) cornerRadius:radius] fill];
        [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 6, 16, 4) cornerRadius:radius] fill];
        image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    } else {
        NSString *symbol = @"arrow.up.left";
        if ([shape isEqualToString:@"circle"]) symbol = @"circle.fill";
        else if ([shape isEqualToString:@"hand"]) symbol = @"hand.point.up.left.fill";
        image = [[UIImage systemImageNamed:symbol] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    }
    self.launcherMousePointerView.image = image;
    self.launcherMousePointerView.tintColor = ([shape isEqualToString:@"crosshair"] || [shape isEqualToString:@"image"] || [style isEqualToString:@"minecraft"]) ? nil : tint;
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    [self changeDisplayModeForSize:size];
}

- (void)changeDisplayModeForSize:(CGSize)size {
    BOOL isPortrait = size.height > size.width;
    if (self.preferredDisplayMode == 0 || self.displayMode != UISplitViewControllerDisplayModeSecondaryOnly) {
        if(!getPrefBool(@"general.hidden_sidebar")) {
            self.preferredDisplayMode = isPortrait ?
                UISplitViewControllerDisplayModeOneOverSecondary :
                UISplitViewControllerDisplayModeOneBesideSecondary;
        } else {
            self.preferredDisplayMode = UISplitViewControllerDisplayModeSecondaryOnly;
        }
    }
    self.preferredSplitBehavior = isPortrait ?
        UISplitViewControllerSplitBehaviorOverlay :
        UISplitViewControllerSplitBehaviorTile;
}

- (void)dismissViewController {
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
