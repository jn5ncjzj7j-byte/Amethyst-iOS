#import <WebKit/WebKit.h>
#import <math.h>
#include <unistd.h>
#import "LauncherMenuViewController.h"
#import "LauncherNewsViewController.h"
#import "LauncherPreferences.h"
#import "utils.h"

@interface LauncherNewsViewController () <WKNavigationDelegate>
@property(nonatomic) WKWebView *newsWebView;

@end

static NSString *AMEscapeChangelogHTML(NSString *value) {
    NSString *escaped = [value stringByReplacingOccurrencesOfString:@"&" withString:@"&amp;"];
    escaped = [escaped stringByReplacingOccurrencesOfString:@"<" withString:@"&lt;"];
    escaped = [escaped stringByReplacingOccurrencesOfString:@">" withString:@"&gt;"];
    escaped = [escaped stringByReplacingOccurrencesOfString:@"\"" withString:@"&quot;"];
    return escaped;
}

static NSString *AMEInlineChangelogHTML(NSString *value) {
    NSString *html = AMEscapeChangelogHTML(value);
    NSArray<NSArray<NSString *> *> *rules = @[
        @[@"\\[([^\\]]+)\\]\\((https?://[^)]+)\\)", @"<a href=\"$2\">$1</a>"],
        @[@"\\*\\*(.+?)\\*\\*", @"<strong>$1</strong>"],
        @[@"\\*(.+?)\\*", @"<em>$1</em>"],
        @[@"`([^`]+)`", @"<code>$1</code>"]
    ];
    for (NSArray<NSString *> *rule in rules) {
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:rule[0] options:0 error:nil];
        html = [regex stringByReplacingMatchesInString:html options:0 range:NSMakeRange(0, html.length) withTemplate:rule[1]];
    }
    return html;
}

static NSString *AMEChangelogHTML(NSString *markdown) {
    NSMutableString *body = [NSMutableString string];
    BOOL inList = NO;
    for (NSString *rawLine in [markdown componentsSeparatedByCharactersInSet:NSCharacterSet.newlineCharacterSet]) {
        NSString *line = [rawLine stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
        if (!line.length) {
            if (inList) {
                [body appendString:@"</ul>"];
                inList = NO;
            }
            continue;
        }
        if ([line hasPrefix:@"### "]) {
            if (inList) { [body appendString:@"</ul>"]; inList = NO; }
            [body appendFormat:@"<h3>%@</h3>", AMEInlineChangelogHTML([line substringFromIndex:4])];
        } else if ([line hasPrefix:@"## "]) {
            if (inList) { [body appendString:@"</ul>"]; inList = NO; }
            [body appendFormat:@"<h2>%@</h2>", AMEInlineChangelogHTML([line substringFromIndex:3])];
        } else if ([line hasPrefix:@"# "]) {
            if (inList) { [body appendString:@"</ul>"]; inList = NO; }
            [body appendFormat:@"<h1>%@</h1>", AMEInlineChangelogHTML([line substringFromIndex:2])];
        } else if ([line hasPrefix:@"- "] || [line hasPrefix:@"* "]) {
            if (!inList) {
                [body appendString:@"<ul>"];
                inList = YES;
            }
            [body appendFormat:@"<li>%@</li>", AMEInlineChangelogHTML([line substringFromIndex:2])];
        } else if ([line isEqualToString:@"---"]) {
            if (inList) { [body appendString:@"</ul>"]; inList = NO; }
            [body appendString:@"<hr>"];
        } else {
            if (inList) { [body appendString:@"</ul>"]; inList = NO; }
            [body appendFormat:@"<p>%@</p>", AMEInlineChangelogHTML(line)];
        }
    }
    if (inList) [body appendString:@"</ul>"];
    return [NSString stringWithFormat:
        @"<!doctype html><html><head><meta name=\"viewport\" content=\"width=device-width,initial-scale=1,maximum-scale=1\"><style>body{font-family:-apple-system,BlinkMacSystemFont,sans-serif;font-size:16px;line-height:1.55;padding:18px 20px 32px;color:CanvasText;background:transparent;color-scheme:light dark}h1{font-size:27px;margin:0 0 18px}h2{font-size:23px;margin:26px 0 10px}h3{font-size:18px;margin:20px 0 8px}p{margin:8px 0 14px}ul{padding-left:24px;margin:8px 0 18px}li{margin:6px 0}a{color:LinkText}code{font-family:ui-monospace,monospace}</style></head><body>%@</body></html>",
        body];
}

@implementation LauncherNewsViewController

- (instancetype)init {
    self = [super init];
    self.title = localize(@"News", nil);
    return self;
}

- (NSString *)imageName {
    return @"MenuNews";
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.newsWebView = [[WKWebView alloc] initWithFrame:self.view.bounds];
    self.newsWebView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.newsWebView.navigationDelegate = self;
    self.newsWebView.opaque = NO;
    self.newsWebView.backgroundColor = UIColor.systemBackgroundColor;
    self.newsWebView.scrollView.backgroundColor = UIColor.systemBackgroundColor;
    self.newsWebView.scrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    [self.view addSubview:self.newsWebView];

    NSString *path = [NSBundle.mainBundle pathForResource:@"Changelog" ofType:@"md"];
    NSError *error = nil;
    NSString *markdown = path ? [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error] : nil;
    if (!markdown) {
        markdown = @"# Changelog\n\nThe changelog is unavailable in this build.";
        NSLog(@"[Changelog] Could not load Changelog.md: %@", error.localizedDescription);
    }
    [self.newsWebView loadHTMLString:AMEChangelogHTML(markdown) baseURL:nil];
    if (!isJailbroken && getPrefBool(@"warnings.limited_ram_warn") && (roundf(NSProcessInfo.processInfo.physicalMemory / 0x1000000) < 3900)) {
        [self showWarningAlert:@"limited_ram" hasPreference:YES exitWhenCompleted:NO];
    }

    self.navigationItem.leftBarButtonItem = self.splitViewController.displayModeButtonItem;
    self.navigationItem.rightBarButtonItem = [sidebarViewController drawAccountButton];
    self.navigationItem.leftItemsSupplementBackButton = YES;
}

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    if (navigationAction.navigationType == WKNavigationTypeLinkActivated) {
        openLink(self, navigationAction.request.URL);
        decisionHandler(WKNavigationActionPolicyCancel);
        return;
    }
    decisionHandler(WKNavigationActionPolicyAllow);
}


- (void)showWarningAlert:(NSString *)key hasPreference:(BOOL)isPreferenced exitWhenCompleted:(BOOL)shouldExit {
    UIAlertController *warning = [UIAlertController alertControllerWithTitle:localize([NSString stringWithFormat:@"login.warn.title.%@", key], nil) message:localize([NSString stringWithFormat:@"login.warn.message.%@", key], nil) preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *action;
    if (isPreferenced) {
        action = [UIAlertAction actionWithTitle:localize(@"OK", nil) style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
            setPrefBool([NSString stringWithFormat:@"warnings.%@_warn", key], NO);
        }];
    } else if (shouldExit) {
        action = [UIAlertAction actionWithTitle:localize(@"OK", nil) style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
            [UIApplication.sharedApplication performSelector:@selector(suspend)];
            usleep(100 * 1000);
            exit(0);
        }];
    } else {
        action = [UIAlertAction actionWithTitle:localize(@"OK", nil) style:UIAlertActionStyleCancel handler:nil];
    }
    warning.popoverPresentationController.sourceView = self.view;
    warning.popoverPresentationController.sourceRect = self.view.bounds;
    [warning addAction:action];
    [self presentViewController:warning animated:YES completion:nil];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (scrollView.contentOffset.x > 0) {
        scrollView.contentOffset = CGPointMake(0, scrollView.contentOffset.y);
    }
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];

    UIViewController *primaryController = self.splitViewController.viewControllers.firstObject;
    UIView *primaryView = primaryController.view;
    CGFloat sidebarInset = 0;

    if (primaryView && primaryView.window == self.newsWebView.window) {
        CGRect primaryRect = [self.newsWebView convertRect:primaryView.bounds fromView:primaryView];
        CGRect overlap = CGRectIntersection(self.newsWebView.bounds, primaryRect);
        if (!CGRectIsNull(overlap) && CGRectGetMinX(overlap) <= CGRectGetMinX(self.newsWebView.bounds)) {
            sidebarInset = CGRectGetMaxX(overlap) - CGRectGetMinX(self.newsWebView.bounds);
        }
    }

    UIScrollView *scrollView = self.newsWebView.scrollView;
    if (fabs(scrollView.contentInset.left - sidebarInset) > 0.5) {
        UIEdgeInsets insets = scrollView.contentInset;
        insets.left = sidebarInset;
        scrollView.contentInset = insets;

        UIEdgeInsets indicatorInsets = scrollView.scrollIndicatorInsets;
        indicatorInsets.left = sidebarInset;
        scrollView.scrollIndicatorInsets = indicatorInsets;
    }

    CGPoint offset = scrollView.contentOffset;
    if (fabs(offset.x + sidebarInset) > 0.5) {
        offset.x = -sidebarInset;
        scrollView.contentOffset = offset;
    }
}

@end
