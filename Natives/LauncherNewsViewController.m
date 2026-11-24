#import <WebKit/WebKit.h>
#import "LauncherMenuViewController.h"
#import "LauncherNewsViewController.h"
#import "LauncherPreferences.h"
#import "utils.h"

@interface LauncherNewsViewController()<WKNavigationDelegate>
@end

@implementation LauncherNewsViewController
WKWebView *webView;
UIEdgeInsets insets;

- (id)init {
    self = [super init];
    self.title = localize(@"News", nil);
    return self;
}

- (NSString *)imageName {
    return @"MenuNews";
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    CGSize size = CGSizeMake(self.view.frame.size.width, self.view.frame.size.height);
    insets = UIApplication.sharedApplication.windows.firstObject.safeAreaInsets;
    
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:@"https://wiki.angelauramc.dev/patchnotes/changelogs/IOS.html"]];

    WKWebViewConfiguration *webConfig = [[WKWebViewConfiguration alloc] init];
    webView = [[WKWebView alloc] initWithFrame:self.view.frame configuration:webConfig];
    webView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    webView.translatesAutoresizingMaskIntoConstraints = NO;
    webView.navigationDelegate = self;
    webView.opaque = NO;
    [self adjustWebViewForSize:size];
    webView.scrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    NSString *javascript = @"var meta = document.createElement('meta');meta.setAttribute('name', 'viewport');meta.setAttribute('content', 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no');document.getElementsByTagName('head')[0].appendChild(meta);";
    WKUserScript *nozoom = [[WKUserScript alloc] initWithSource:javascript injectionTime:WKUserScriptInjectionTimeAtDocumentEnd forMainFrameOnly:YES];
    [webView.configuration.userContentController addUserScript:nozoom];
    [webView.scrollView setShowsHorizontalScrollIndicator:NO];
    [webView loadRequest:request];
    [self.view addSubview:webView];

    if(!isJailbroken && getPrefBool(@"warnings.limited_ram_warn") && (roundf(NSProcessInfo.processInfo.physicalMemory / 0x1000000) < 3900)) {
        // "This device has a limited amount of memory available."
        [self showWarningAlert:@"limited_ram" hasPreference:YES exitWhenCompleted:NO];
    }

    self.navigationItem.leftBarButtonItem = self.splitViewController.displayModeButtonItem;
    self.navigationItem.rightBarButtonItem = [sidebarViewController drawAccountButton];
    self.navigationItem.leftItemsSupplementBackButton = true;
}

-(void)showWarningAlert:(NSString *)key hasPreference:(BOOL)isPreferenced exitWhenCompleted:(BOOL)shouldExit {
    UIAlertController *warning = [UIAlertController
                                      alertControllerWithTitle:localize([NSString stringWithFormat:@"login.warn.title.%@", key], nil)
                                      message:localize([NSString stringWithFormat:@"login.warn.message.%@", key], nil)
                                      preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *action;
    if(isPreferenced) {
        action = [UIAlertAction actionWithTitle:localize(@"OK", nil) style:UIAlertActionStyleDestructive handler:^(UIAlertAction * action) {
            setPrefBool([NSString stringWithFormat:@"warnings.%@_warn", key], NO);
        }];
    } else if(shouldExit) {
        action = [UIAlertAction actionWithTitle:localize(@"OK", nil) style:UIAlertActionStyleDestructive handler:^(UIAlertAction * action) {
            [UIApplication.sharedApplication performSelector:@selector(suspend)];
            usleep(100*1000);
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

-(void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    if (scrollView.contentOffset.x > 0)
        scrollView.contentOffset = CGPointMake(0, scrollView.contentOffset.y);
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    [self adjustWebViewForSize:size];
}

- (void)adjustWebViewForSize:(CGSize)size {
    BOOL isPortrait = size.height > size.width;
    if (isPortrait) {
        webView.scrollView.contentInset = UIEdgeInsetsMake(self.navigationController.navigationBar.frame.size.height + insets.top, 0, self.navigationController.navigationBar.frame.size.height + insets.bottom, 0);
    } else {
        webView.scrollView.contentInset = UIEdgeInsetsMake(self.navigationController.navigationBar.frame.size.height, 0, self.navigationController.navigationBar.frame.size.height, 0);
    }
}

- (void)webView:(WKWebView *)webView 
decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction 
decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
     if (navigationAction.navigationType == WKNavigationTypeLinkActivated) {
        openLink(self, navigationAction.request.URL);
        decisionHandler(WKNavigationActionPolicyCancel);
        return;
    }
    decisionHandler(WKNavigationActionPolicyAllow);
}

@end


@interface LauncherChangelogViewController () <WKNavigationDelegate>
@property(nonatomic) WKWebView *changelogWebView;
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

@implementation LauncherChangelogViewController

- (instancetype)init {
    self = [super init];
    self.title = localize(@"launcher.menu.changelog", nil);
    return self;
}

- (NSString *)imageName {
    return @"doc.text";
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.changelogWebView = [[WKWebView alloc] initWithFrame:self.view.bounds];
    self.changelogWebView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.changelogWebView.navigationDelegate = self;
    self.changelogWebView.opaque = NO;
    self.changelogWebView.backgroundColor = UIColor.systemBackgroundColor;
    self.changelogWebView.scrollView.backgroundColor = UIColor.systemBackgroundColor;
    self.changelogWebView.scrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    [self.view addSubview:self.changelogWebView];

    NSString *path = [NSBundle.mainBundle pathForResource:@"Changelog" ofType:@"md"];
    NSError *error = nil;
    NSString *markdown = path ? [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error] : nil;
    if (!markdown) {
        markdown = @"# Changelog\n\nThe changelog is unavailable in this build.";
        NSLog(@"[Changelog] Could not load Changelog.md: %@", error.localizedDescription);
    }
    [self.changelogWebView loadHTMLString:AMEChangelogHTML(markdown) baseURL:nil];

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

@end
