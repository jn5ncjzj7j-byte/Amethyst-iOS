#import <UIKit/UIKit.h>

@interface LauncherSplitViewController : UISplitViewController

@property(nonatomic, strong) UIImageView *launcherMousePointerView;
@property(nonatomic, strong) UIHoverGestureRecognizer *launcherMouseHoverGesture;
@property(nonatomic, strong) id launcherMouseConnectObserver;
@property(nonatomic, strong) id launcherMouseDisconnectObserver;

@end
