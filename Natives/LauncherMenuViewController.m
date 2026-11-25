#import "authenticator/BaseAuthenticator.h"
#import "AccountListViewController.h"
#import "AFNetworking.h"
#import "ALTServerConnection.h"
#import "HostManagerBridge.h"
#import "LauncherNavigationController.h"
#import "LauncherMenuViewController.h"
#import "LauncherNewsViewController.h"
#import "LauncherPreferences.h"
#import "LauncherPreferencesViewController.h"
#import "LauncherProfilesViewController.h"
#import "installer/ModrinthModsViewController.h"
#import "PLProfiles.h"
#import "UIButton+AFNetworking.h"
#import "UIImageView+AFNetworking.h"
#import "UIKit+hook.h"
#import "ios_uikit_bridge.h"
#import "utils.h"

#include "config.h"
#include <dlfcn.h>

@implementation LauncherMenuCustomItem

+ (LauncherMenuCustomItem *)title:(NSString *)title imageName:(NSString *)imageName action:(id)action {
    LauncherMenuCustomItem *item = [[LauncherMenuCustomItem alloc] init];
    item.title = title;
    item.imageName = imageName;
    item.action = action;
    return item;
}

+ (LauncherMenuCustomItem *)vcClass:(Class)class {
    id vc = [class new];
    LauncherMenuCustomItem *item = [[LauncherMenuCustomItem alloc] init];
    item.title = [vc title];
    item.imageName = [vc imageName];
    // View controllers are put into an array to keep its state
    item.vcArray = @[vc];
    return item;
}

@end


@interface LauncherHomeViewController ()
@property(nonatomic) UILabel *profileLabel;
@property(nonatomic) UILabel *versionLabel;
@property(nonatomic) UIStackView *contentStack;
@end

@implementation LauncherHomeViewController

- (NSString *)imageName {
    return @"house.fill";
}

- (instancetype)init {
    self = [super init];
    self.title = @"Home";
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithRed:10.0/255.0 green:12.0/255.0 blue:22.0/255.0 alpha:1.0];
    self.navigationItem.title = @"NEXA";
    self.navigationItem.rightBarButtonItem = [sidebarViewController drawAccountButton];

    UIScrollView *scrollView = [UIScrollView new];
    scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:scrollView];

    self.contentStack = [[UIStackView alloc] init];
    self.contentStack.axis = UILayoutConstraintAxisVertical;
    self.contentStack.spacing = 20;
    self.contentStack.translatesAutoresizingMaskIntoConstraints = NO;
    [scrollView addSubview:self.contentStack];

    [NSLayoutConstraint activateConstraints:@[
        [scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [scrollView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [self.contentStack.leadingAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.leadingAnchor constant:28],
        [self.contentStack.trailingAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.trailingAnchor constant:-28],
        [self.contentStack.topAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.topAnchor constant:26],
        [self.contentStack.bottomAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.bottomAnchor constant:-28],
        [self.contentStack.widthAnchor constraintEqualToAnchor:scrollView.frameLayoutGuide.widthAnchor constant:-56]
    ]];

    [self buildHero];
    [self buildFeatureSection];
    [self buildNewsCard];
    [self refreshProfileInformation];
}

- (UIView *)makeCardWithTitle:(NSString *)title subtitle:(NSString *)subtitle symbol:(NSString *)symbol action:(NSUInteger)index {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.backgroundColor = [UIColor colorWithRed:24.0/255.0 green:27.0/255.0 blue:43.0/255.0 alpha:1.0];
    button.layer.cornerRadius = 18;
    button.layer.borderWidth = 1;
    button.layer.borderColor = [UIColor colorWithRed:91.0/255.0 green:76.0/255.0 blue:145.0/255.0 alpha:0.35].CGColor;
    button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    button.titleLabel.numberOfLines = 2;
    button.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    [button setTitle:[NSString stringWithFormat:@"%@\n%@", title, subtitle] forState:UIControlStateNormal];
    [button setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    button.titleEdgeInsets = UIEdgeInsetsMake(62, 16, 12, 10);
    UIImageView *iconView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:symbol]];
    iconView.tintColor = [UIColor colorWithRed:174.0/255.0 green:133.0/255.0 blue:255.0/255.0 alpha:1.0];
    iconView.contentMode = UIViewContentModeScaleAspectFit;
    iconView.frame = CGRectMake(16, 17, 30, 30);
    [button addSubview:iconView];
    [button addAction:[UIAction actionWithHandler:^(__kindof UIAction *action) {
        [sidebarViewController openOptionAtIndex:index];
    }] forControlEvents:UIControlEventPrimaryActionTriggered];
    [button.heightAnchor constraintGreaterThanOrEqualToConstant:142].active = YES;
    return button;
}

- (void)buildHero {
    UIView *hero = [UIView new];
    hero.translatesAutoresizingMaskIntoConstraints = NO;
    hero.backgroundColor = [UIColor colorWithRed:25.0/255.0 green:20.0/255.0 blue:48.0/255.0 alpha:1.0];
    hero.layer.cornerRadius = 26;
    hero.layer.borderWidth = 1;
    hero.layer.borderColor = [UIColor colorWithRed:117.0/255.0 green:83.0/255.0 blue:194.0/255.0 alpha:0.55].CGColor;

    UIView *orb = [UIView new];
    orb.translatesAutoresizingMaskIntoConstraints = NO;
    orb.layer.cornerRadius = 27;
    orb.backgroundColor = [UIColor colorWithRed:133.0/255.0 green:83.0/255.0 blue:220.0/255.0 alpha:1.0];
    orb.layer.shadowColor = [UIColor colorWithRed:125.0/255.0 green:82.0/255.0 blue:240.0/255.0 alpha:1.0].CGColor;
    orb.layer.shadowOpacity = 0.55;
    orb.layer.shadowRadius = 22;
    orb.layer.shadowOffset = CGSizeZero;

    UILabel *brand = [UILabel new];
    brand.text = @"NEXA";
    brand.textColor = UIColor.whiteColor;
    brand.font = [UIFont systemFontOfSize:15 weight:UIFontWeightBold];
    brand.attributedText = [[NSAttributedString alloc] initWithString:@"NEXA" attributes:@{NSKernAttributeName: @3}];

    UILabel *eyebrow = [UILabel new];
    eyebrow.text = @"MINECRAFT JAVA EDITION";
    eyebrow.textColor = [UIColor colorWithRed:185.0/255.0 green:165.0/255.0 blue:231.0/255.0 alpha:1.0];
    eyebrow.font = [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold];

    UILabel *heading = [UILabel new];
    heading.text = @"Your world. Your rules.";
    heading.textColor = UIColor.whiteColor;
    heading.font = [UIFont systemFontOfSize:30 weight:UIFontWeightBold];
    heading.numberOfLines = 2;

    self.profileLabel = [UILabel new];
    self.profileLabel.textColor = [UIColor colorWithWhite:0.88 alpha:1.0];
    self.profileLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];

    self.versionLabel = [UILabel new];
    self.versionLabel.textColor = [UIColor colorWithWhite:0.68 alpha:1.0];
    self.versionLabel.font = [UIFont systemFontOfSize:13];

    UIButton *versionButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [versionButton setTitle:@"Change version" forState:UIControlStateNormal];
    [versionButton setTitleColor:[UIColor colorWithRed:198.0/255.0 green:169.0/255.0 blue:255.0/255.0 alpha:1.0] forState:UIControlStateNormal];
    versionButton.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    [versionButton addAction:[UIAction actionWithHandler:^(__kindof UIAction *action) {
        [(LauncherNavigationController *)self.splitViewController.viewControllers[1] showVersionPicker];
    }] forControlEvents:UIControlEventPrimaryActionTriggered];

    UIButton *play = [UIButton buttonWithType:UIButtonTypeSystem];
    play.translatesAutoresizingMaskIntoConstraints = NO;
    play.backgroundColor = [UIColor colorWithRed:137.0/255.0 green:86.0/255.0 blue:224.0/255.0 alpha:1.0];
    play.layer.cornerRadius = 15;
    [play setTitle:@"Play" forState:UIControlStateNormal];
    [play setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    play.titleLabel.font = [UIFont systemFontOfSize:19 weight:UIFontWeightBold];
    [play addAction:[UIAction actionWithHandler:^(__kindof UIAction *action) {
        [(LauncherNavigationController *)self.splitViewController.viewControllers[1] launchSelectedVersionFromHome:play];
    }] forControlEvents:UIControlEventPrimaryActionTriggered];

    UIStackView *brandRow = [[UIStackView alloc] initWithArrangedSubviews:@[orb, brand]];
    brandRow.axis = UILayoutConstraintAxisHorizontal;
    brandRow.alignment = UIStackViewAlignmentCenter;
    brandRow.spacing = 12;

    UIStackView *details = [[UIStackView alloc] initWithArrangedSubviews:@[eyebrow, heading, self.profileLabel, self.versionLabel, versionButton, play]];
    details.axis = UILayoutConstraintAxisVertical;
    details.spacing = 11;

    UIStackView *heroStack = [[UIStackView alloc] initWithArrangedSubviews:@[brandRow, details]];
    heroStack.axis = UILayoutConstraintAxisVertical;
    heroStack.spacing = 20;
    heroStack.translatesAutoresizingMaskIntoConstraints = NO;
    UIImageView *minecraftBanner = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"MenuProfiles"]];
    minecraftBanner.translatesAutoresizingMaskIntoConstraints = NO;
    minecraftBanner.contentMode = UIViewContentModeScaleAspectFit;
    minecraftBanner.alpha = 0.24;
    [hero addSubview:minecraftBanner];
    [hero addSubview:heroStack];
    [NSLayoutConstraint activateConstraints:@[
        [minecraftBanner.trailingAnchor constraintEqualToAnchor:hero.trailingAnchor constant:-22],
        [minecraftBanner.topAnchor constraintEqualToAnchor:hero.topAnchor constant:18],
        [minecraftBanner.widthAnchor constraintEqualToConstant:118],
        [minecraftBanner.heightAnchor constraintEqualToConstant:118]
    ]];

    [NSLayoutConstraint activateConstraints:@[
        [orb.widthAnchor constraintEqualToConstant:54],
        [orb.heightAnchor constraintEqualToConstant:54],
        [play.heightAnchor constraintEqualToConstant:54],
        [heroStack.leadingAnchor constraintEqualToAnchor:hero.leadingAnchor constant:24],
        [heroStack.trailingAnchor constraintEqualToAnchor:hero.trailingAnchor constant:-24],
        [heroStack.topAnchor constraintEqualToAnchor:hero.topAnchor constant:22],
        [heroStack.bottomAnchor constraintEqualToAnchor:hero.bottomAnchor constant:-22]
    ]];

    [self.contentStack addArrangedSubview:hero];
}

- (void)buildFeatureSection {
    UILabel *heading = [UILabel new];
    heading.text = @"Your launcher";
    heading.textColor = UIColor.whiteColor;
    heading.font = [UIFont systemFontOfSize:22 weight:UIFontWeightBold];
    [self.contentStack addArrangedSubview:heading];

    UIStackView *row = [[UIStackView alloc] initWithArrangedSubviews:@[
        [self makeCardWithTitle:@"Mods" subtitle:@"Discover and manage" symbol:@"puzzlepiece.extension" action:4],
        [self makeCardWithTitle:@"Resource Packs" subtitle:@"Installed packs" symbol:@"square.stack.3d.up" action:5],
        [self makeCardWithTitle:@"Shaders" subtitle:@"Visual settings" symbol:@"sun.max" action:6]
    ]];
    row.axis = UILayoutConstraintAxisHorizontal;
    row.spacing = 14;
    row.distribution = UIStackViewDistributionFillEqually;
    [self.contentStack addArrangedSubview:row];
}

- (void)buildNewsCard {
    UIButton *news = [UIButton buttonWithType:UIButtonTypeCustom];
    news.backgroundColor = [UIColor colorWithRed:20.0/255.0 green:23.0/255.0 blue:36.0/255.0 alpha:1.0];
    news.layer.cornerRadius = 18;
    news.layer.borderWidth = 1;
    news.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.08].CGColor;
    news.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    [news setTitle:@"News & Updates\nRead the latest NEXA and launcher updates" forState:UIControlStateNormal];
    [news setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    news.titleLabel.numberOfLines = 2;
    news.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    news.titleEdgeInsets = UIEdgeInsetsMake(12, 20, 12, 20);
    [news addAction:[UIAction actionWithHandler:^(__kindof UIAction *action) {
        [sidebarViewController openOptionAtIndex:3];
    }] forControlEvents:UIControlEventPrimaryActionTriggered];
    [news.heightAnchor constraintEqualToConstant:82].active = YES;
    [self.contentStack addArrangedSubview:news];
}

- (void)refreshProfileInformation {
    NSString *profileName = PLProfiles.current.selectedProfileName ?: @"Default";
    NSDictionary *profile = PLProfiles.current.profiles[profileName];
    NSString *version = profile[@"lastVersionId"] ?: @"Choose a version";
    NSString *renderer = [PLProfiles resolveKeyForCurrentProfile:@"renderer"] ?: @"Default";
    self.profileLabel.text = [NSString stringWithFormat:@"Profile  %@     Renderer  %@", profileName, renderer];
    NSString *javaVersion = [PLProfiles resolveKeyForCurrentProfile:@"javaVersion"] ?: @"0";
    NSString *runtime = [javaVersion isEqualToString:@"0"] ? @"Auto" : [NSString stringWithFormat:@"Java %@", javaVersion];
    NSString *ram = getPrefBool(@"java.auto_ram") ? @"Auto" : [NSString stringWithFormat:@"%ld MB", (long)getPrefInt(@"java.allocated_memory")];
    self.versionLabel.text = [NSString stringWithFormat:@"Version  %@     Java  %@     RAM  %@", version, runtime, ram];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.navigationItem.rightBarButtonItem = [sidebarViewController drawAccountButton];
    [self refreshProfileInformation];
}

@end

@interface LauncherMenuViewController()
@property(nonatomic) NSMutableArray<LauncherMenuCustomItem*> *options;
@property(nonatomic) UILabel *statusLabel;
@property(nonatomic) int lastSelectedIndex;
@property(nonatomic) UIView *nexaFooterView;
@property(nonatomic) UILabel *clockLabel;
@property(nonatomic) UILabel *dateLabel;
@property(nonatomic) NSTimer *clockTimer;
@end

@implementation LauncherMenuViewController

#define contentNavigationController ((LauncherNavigationController *)self.splitViewController.viewControllers[1])

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.isInitialVc = YES;
    
    UIView *brandView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 126, 34)];
    UIView *brandOrb = [[UIView alloc] initWithFrame:CGRectMake(0, 5, 24, 24)];
    brandOrb.backgroundColor = [UIColor colorWithRed:145.0/255.0 green:91.0/255.0 blue:230.0/255.0 alpha:1.0];
    brandOrb.layer.cornerRadius = 12;
    brandOrb.layer.shadowColor = brandOrb.backgroundColor.CGColor;
    brandOrb.layer.shadowOpacity = 0.65;
    brandOrb.layer.shadowRadius = 10;
    UILabel *brandTitle = [[UILabel alloc] initWithFrame:CGRectMake(34, 0, 90, 34)];
    brandTitle.text = @"NEXA";
    brandTitle.textColor = UIColor.whiteColor;
    brandTitle.font = [UIFont systemFontOfSize:18 weight:UIFontWeightBold];
    brandTitle.attributedText = [[NSAttributedString alloc] initWithString:@"NEXA" attributes:@{NSKernAttributeName: @2}];
    [brandView addSubview:brandOrb];
    [brandView addSubview:brandTitle];
    self.navigationItem.titleView = brandView;
    
    self.options = @[
        [LauncherMenuCustomItem vcClass:LauncherHomeViewController.class],
        [LauncherMenuCustomItem vcClass:LauncherProfilesViewController.class],
        [LauncherMenuCustomItem vcClass:LauncherPreferencesViewController.class],
        [LauncherMenuCustomItem vcClass:LauncherNewsViewController.class],
        [LauncherMenuCustomItem vcClass:ModrinthModsViewController.class],
        [LauncherMenuCustomItem vcClass:LauncherResourcePacksViewController.class],
        [LauncherMenuCustomItem vcClass:LauncherShaderPacksViewController.class],
    ].mutableCopy;
    if (realUIIdiom != UIUserInterfaceIdiomTV) {
        [self.options addObject:(id)[LauncherMenuCustomItem
                                     title:localize(@"launcher.menu.custom_controls", nil)
                                     imageName:@"MenuCustomControls" action:^{
            [contentNavigationController performSelector:@selector(enterCustomControls)];
        }]];
    }
    [self.options addObject:
     (id)[LauncherMenuCustomItem
          title:localize(@"launcher.menu.execute_jar", nil)
          imageName:@"MenuInstallJar" action:^{
        [contentNavigationController performSelector:@selector(enterModInstaller)];
    }]];
    
    [self.options addObject:
     (id)[LauncherMenuCustomItem
          title:localize(@"login.menu.sendlogs", nil)
          imageName:@"square.and.arrow.up" action:^{
        NSString *latestlogPath = [NSString stringWithFormat:@"file://%s/latestlog.old.txt", getenv("AME_HOME")];
        NSLog(@"Path is %@", latestlogPath);
        UIActivityViewController *activityVC;
        if (realUIIdiom != UIUserInterfaceIdiomTV) {
            activityVC = [[UIActivityViewController alloc]
                          initWithActivityItems:@[[NSURL URLWithString:latestlogPath]]
                          applicationActivities:nil];
        } else {
            dlopen("/System/Library/PrivateFrameworks/SharingUI.framework/SharingUI", RTLD_GLOBAL);
            activityVC =
            [[NSClassFromString(@"SFAirDropSharingViewControllerTV") alloc]
             performSelector:@selector(initWithSharingItems:)
             withObject:@[[NSURL URLWithString:latestlogPath]]];
        }
        activityVC.popoverPresentationController.sourceView = titleView;
        activityVC.popoverPresentationController.sourceRect = titleView.bounds;
        [self presentViewController:activityVC animated:YES completion:nil];
    }]];
    
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.dateFormat = @"MM-dd";
    NSString* date = [dateFormatter stringFromDate:NSDate.date];
    if([date isEqualToString:@"06-29"] || [date isEqualToString:@"06-30"] || [date isEqualToString:@"07-01"]) {
        [self.options addObject:(id)[LauncherMenuCustomItem
                                     title:@"Technoblade never dies!"
                                     imageName:@"" action:^{
            openLink(self, [NSURL URLWithString:@"https://youtu.be/DPMluEVUqS0"]);
        }]];
    }
    
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.backgroundColor = [UIColor colorWithRed:13.0/255.0 green:16.0/255.0 blue:25.0/255.0 alpha:1.0];
    self.tableView.rowHeight = 64;
    self.tableView.contentInset = UIEdgeInsetsMake(0, 0, 164, 0);
    self.tableView.scrollIndicatorInsets = self.tableView.contentInset;

    self.nexaFooterView = [[UIView alloc] init];
    self.nexaFooterView.backgroundColor = [UIColor colorWithRed:13.0/255.0 green:16.0/255.0 blue:25.0/255.0 alpha:1.0];
    self.clockLabel = [UILabel new];
    self.clockLabel.textColor = UIColor.whiteColor;
    self.clockLabel.font = [UIFont monospacedDigitSystemFontOfSize:22 weight:UIFontWeightSemibold];
    self.dateLabel = [UILabel new];
    self.dateLabel.textColor = [UIColor colorWithWhite:0.65 alpha:1.0];
    self.dateLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    [self.nexaFooterView addSubview:self.clockLabel];
    [self.nexaFooterView addSubview:self.dateLabel];

    NSArray *shortcutTitles = @[@"GitHub", @"Discord", @"Changelog"];
    NSArray *shortcutSymbols = @[@"chevron.left.forwardslash.chevron.right", @"bubble.left.and.bubble.right", @"clock.arrow.circlepath"];
    for (NSUInteger i = 0; i < shortcutTitles.count; i++) {
        UIButton *shortcut = [UIButton buttonWithType:UIButtonTypeSystem];
        [shortcut setTitle:shortcutTitles[i] forState:UIControlStateNormal];
        [shortcut setImage:[UIImage systemImageNamed:shortcutSymbols[i]] forState:UIControlStateNormal];
        [shortcut setTitleColor:[UIColor colorWithRed:190.0/255.0 green:164.0/255.0 blue:245.0/255.0 alpha:1.0] forState:UIControlStateNormal];
        shortcut.tintColor = [UIColor colorWithRed:190.0/255.0 green:164.0/255.0 blue:245.0/255.0 alpha:1.0];
        shortcut.titleLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightSemibold];
        shortcut.tag = i;
        [shortcut addTarget:self action:@selector(nexaShortcutTapped:) forControlEvents:UIControlEventPrimaryActionTriggered];
        [self.nexaFooterView addSubview:shortcut];
    }
    [self.tableView addSubview:self.nexaFooterView];
    [self updateNexaClock];
    self.clockTimer = [NSTimer scheduledTimerWithTimeInterval:30 target:self selector:@selector(updateNexaClock) userInfo:nil repeats:YES];

    
    self.navigationController.toolbarHidden = NO;
    UIActivityIndicatorViewStyle indicatorStyle = UIActivityIndicatorViewStyleMedium;
    UIActivityIndicatorView *toolbarIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:indicatorStyle];
    [toolbarIndicator startAnimating];
    self.toolbarItems = @[
        [[UIBarButtonItem alloc] initWithCustomView:toolbarIndicator],
        [[UIBarButtonItem alloc] init]
    ];
    self.toolbarItems[1].tintColor = UIColor.labelColor;
    
    // Setup the account button
    self.accountBtnItem = [self drawAccountButton];
    
    [self updateAccountInfo];
    
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:0 inSection:0];
    [self.tableView selectRowAtIndexPath:indexPath animated:YES scrollPosition:UITableViewScrollPositionNone];
    [self tableView:self.tableView didSelectRowAtIndexPath:indexPath];
    self.lastSelectedIndex = 0;
    
    if (getEntitlementValue(@"get-task-allow")) {
        [self displayProgress:localize(@"login.jit.checking", nil)];
        if (isJITEnabled(false)) {
            [self displayProgress:localize(@"login.jit.enabled", nil)];
            [self displayProgress:nil];
        } else if (@available(iOS 17.0, *)) {
            // enabling JIT for 17.0+ is done when we actually launch the game
        } else {
            [self enableJITWithAltKit];
        }
    } else if (!NSProcessInfo.processInfo.macCatalystApp && !getenv("SIMULATOR_DEVICE_NAME")) {
        [self displayProgress:localize(@"login.jit.fail", nil)];
        [self displayProgress:nil];
        UIAlertController* alert = [UIAlertController alertControllerWithTitle:localize(@"login.jit.fail.title", nil)
            message:localize(@"login.jit.fail.description_unsupported", nil)
            preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction* okAction = [UIAlertAction actionWithTitle:localize(@"OK", nil) style:UIAlertActionStyleDefault handler:^(id action){
            exit(-1);
        }];
        [alert addAction:okAction];
        [self presentViewController:alert animated:YES completion:nil];
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self restoreHighlightedSelection];
}

- (UIBarButtonItem *)drawAccountButton {
    if (!self.accountBtnItem) {
        self.accountButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [self.accountButton addTarget:self action:@selector(selectAccount:) forControlEvents:UIControlEventPrimaryActionTriggered];
        self.accountButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;

        self.accountButton.titleEdgeInsets = UIEdgeInsetsMake(0, 4, 0, -4);
        self.accountButton.imageView.contentMode = UIViewContentModeScaleAspectFit;
        self.accountButton.titleLabel.lineBreakMode = NSLineBreakByWordWrapping;
        self.accountBtnItem = [[UIBarButtonItem alloc] initWithCustomView:self.accountButton];
    }

    [self updateAccountInfo];
    
    return self.accountBtnItem;
}

- (void)dealloc {
    [self.clockTimer invalidate];
}

- (void)restoreHighlightedSelection {
    // Restore the selected row when the view appears again
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:self.lastSelectedIndex inSection:0];
    [self.tableView selectRowAtIndexPath:indexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 3;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 64;
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat footerHeight = 154;
    self.nexaFooterView.frame = CGRectMake(0, self.tableView.bounds.size.height - footerHeight, self.tableView.bounds.size.width, footerHeight);
    self.clockLabel.frame = CGRectMake(22, 12, self.nexaFooterView.bounds.size.width - 44, 30);
    self.dateLabel.frame = CGRectMake(22, 43, self.nexaFooterView.bounds.size.width - 44, 20);
    CGFloat buttonWidth = (self.nexaFooterView.bounds.size.width - 32) / 3.0;
    for (UIView *view in self.nexaFooterView.subviews) {
        if (![view isKindOfClass:UIButton.class]) continue;
        UIButton *button = (UIButton *)view;
        button.frame = CGRectMake(12 + button.tag * buttonWidth, 82, buttonWidth, 54);
    }
}

- (void)updateNexaClock {
    NSDateFormatter *timeFormatter = [NSDateFormatter new];
    timeFormatter.dateFormat = @"HH:mm";
    NSDateFormatter *dateFormatter = [NSDateFormatter new];
    dateFormatter.dateFormat = @"EEE, d MMM";
    self.clockLabel.text = [timeFormatter stringFromDate:NSDate.date];
    self.dateLabel.text = [dateFormatter stringFromDate:NSDate.date];
}

- (void)nexaShortcutTapped:(UIButton *)sender {
    if (sender.tag == 0) {
        openLink(self, [NSURL URLWithString:@"https://github.com/jn5ncjzj7j-byte/Amethyst-iOS"]);
    } else if (sender.tag == 1) {
        openLink(self, [NSURL URLWithString:@"https://discord.gg/5ptqkyZxEy"]);
    } else {
        [self openOptionAtIndex:3];
    }
}

- (void)openOptionAtIndex:(NSUInteger)index {
    if (index >= self.options.count) return;
    NSIndexPath *path = [NSIndexPath indexPathForRow:index < 3 ? index : self.lastSelectedIndex inSection:0];
    if (index < 3) {
        [self.tableView selectRowAtIndexPath:path animated:NO scrollPosition:UITableViewScrollPositionNone];
    }
    LauncherMenuCustomItem *selected = self.options[index];
    if (selected.action) {
        selected.action();
        return;
    }
    self.options[self.lastSelectedIndex].vcArray = contentNavigationController.viewControllers;
    [contentNavigationController setViewControllers:selected.vcArray animated:NO];
    if (index < 3) self.lastSelectedIndex = (int)index;
    contentNavigationController.toolbarHidden = index != 1;
    selected.vcArray[0].navigationItem.rightBarButtonItem = self.accountBtnItem;
    selected.vcArray[0].navigationItem.leftBarButtonItems = @[self.splitViewController.displayModeButtonItem];
    selected.vcArray[0].navigationItem.leftItemsSupplementBackButton = YES;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"cell"];
    }

    cell.backgroundColor = UIColor.clearColor;
    cell.textLabel.textColor = UIColor.whiteColor;
    cell.textLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightMedium];
    cell.textLabel.text = @[@"Home", @"Versions", @"Settings"][indexPath.row];
    UIView *selectedBackground = [UIView new];
    selectedBackground.backgroundColor = [UIColor colorWithRed:72.0/255.0 green:48.0/255.0 blue:112.0/255.0 alpha:0.72];
    cell.selectedBackgroundView = selectedBackground;
    cell.imageView.tintColor = [UIColor colorWithRed:177.0/255.0 green:143.0/255.0 blue:245.0/255.0 alpha:1.0];
    NSArray *symbols = @[@"house.fill", @"square.stack.3d.up.fill", @"slider.horizontal.3"];
    cell.imageView.image = [UIImage systemImageNamed:symbols[indexPath.row]];
    
    UIImage *origImage = [UIImage systemImageNamed:[self.options[indexPath.row]
        performSelector:@selector(imageName)]];
    if (origImage) {
        UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(40, 40)];
        UIImage *image = [renderer imageWithActions:^(UIGraphicsImageRendererContext*_Nonnull myContext) {
            CGFloat scaleFactor = 40/origImage.size.height;
            [origImage drawInRect:CGRectMake(20 - origImage.size.width*scaleFactor/2, 0, origImage.size.width*scaleFactor, 40)];
        }];
        cell.imageView.image = [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    }
    
    if (cell.imageView.image == nil) {
        cell.imageView.layer.magnificationFilter = kCAFilterNearest;
        cell.imageView.layer.minificationFilter = kCAFilterNearest;
        cell.imageView.image = [UIImage imageNamed:[self.options[indexPath.row]
            performSelector:@selector(imageName)]];
        cell.imageView.image = [cell.imageView.image _imageWithSize:CGSizeMake(40, 40)];
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [self openOptionAtIndex:indexPath.row];
}

- (void)selectAccount:(UIButton *)sender {
    AccountListViewController *vc = [[AccountListViewController alloc] init];
    vc.whenDelete = ^void(NSString* name) {
        if ([name isEqualToString:getPrefObject(@"internal.selected_account")]) {
            BaseAuthenticator.current = nil;
            setPrefObject(@"internal.selected_account", @"");
            [self updateAccountInfo];
        }
    };
    vc.whenItemSelected = ^void() {
        setPrefObject(@"internal.selected_account", BaseAuthenticator.current.authData[@"username"]);
        [self updateAccountInfo];
        if (sender != self.accountButton) {
            // Called from the play button, so call back to continue
            [sender sendActionsForControlEvents:UIControlEventPrimaryActionTriggered];
        }
    };
    vc.modalPresentationStyle = UIModalPresentationPopover;
    vc.preferredContentSize = CGSizeMake(350, 250);

    UIPopoverPresentationController *popoverController = vc.popoverPresentationController;
    popoverController.sourceView = sender;
    popoverController.sourceRect = sender.bounds;
    popoverController.permittedArrowDirections = UIPopoverArrowDirectionAny;
    popoverController.delegate = vc;
    [self presentViewController:vc animated:YES completion:nil];
}

- (void)updateAccountInfo {
    NSDictionary *selected = BaseAuthenticator.current.authData;
    CGSize size = CGSizeMake(contentNavigationController.view.frame.size.width, contentNavigationController.view.frame.size.height);
    
    if (selected == nil) {
        if((size.width / 3) > 200) {
            [self.accountButton setAttributedTitle:[[NSAttributedString alloc] initWithString:localize(@"login.option.select", nil)] forState:UIControlStateNormal];
        } else {
            [self.accountButton setAttributedTitle:(NSAttributedString *)@"" forState:UIControlStateNormal];
        }
        [self.accountButton setImage:[UIImage imageNamed:@"DefaultAccount"] forState:UIControlStateNormal];
        [self.accountButton sizeToFit];
        return;
    }

    // Remove the prefix "Demo." if there is
    BOOL isDemo = [selected[@"username"] hasPrefix:@"Demo."];
    NSMutableAttributedString *title = [[NSMutableAttributedString alloc] initWithString:[selected[@"username"] substringFromIndex:(isDemo?5:0)]];

    // Check if we're switching between demo and full mode
    BOOL shouldUpdateProfiles = (getenv("DEMO_LOCK")!=NULL) != isDemo;

    // Reset states
    unsetenv("DEMO_LOCK");
    setenv("GAME_DIR", [NSString stringWithFormat:@"%s/Library/Application Support/minecraft", getenv("AME_HOME")].UTF8String, 1);

    id subtitle;
    if (isDemo) {
        subtitle = localize(@"login.option.demo", nil);
        setenv("DEMO_LOCK", "1", 1);
        setenv("GAME_DIR", [NSString stringWithFormat:@"%s/.demo", getenv("AME_HOME")].UTF8String, 1);
    } else if (selected[@"xboxGamertag"] == nil) {
        subtitle = localize(@"login.option.local", nil);
    } else {
        // Display the Xbox gamertag for online accounts
        subtitle = selected[@"xboxGamertag"];
    }

    subtitle = [[NSAttributedString alloc] initWithString:subtitle attributes:@{NSFontAttributeName: [UIFont systemFontOfSize:12]}];
    [title appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n" attributes:nil]];
    [title appendAttributedString:subtitle];
    
    if((size.width / 3) > 200) {
        [self.accountButton setAttributedTitle:title forState:UIControlStateNormal];
    } else {
        [self.accountButton setAttributedTitle:(NSAttributedString *)@"" forState:UIControlStateNormal];
    }
    
    // TODO: Add caching mechanism for profile pictures
    NSURL *url = [NSURL URLWithString:[selected[@"profilePicURL"] stringByReplacingOccurrencesOfString:@"\\/" withString:@"/"]];
    UIImage *placeholder = [UIImage imageNamed:@"DefaultAccount"];
    [self.accountButton setImageForState:UIControlStateNormal withURL:url placeholderImage:placeholder];
    [self.accountButton.imageView setImageWithURL:url placeholderImage:placeholder];
    [self.accountButton sizeToFit];

    // Update profiles and local version list if needed
    if (shouldUpdateProfiles) {
        [contentNavigationController fetchLocalVersionList];
        [contentNavigationController performSelector:@selector(reloadProfileList)];
    }

    // Update tableView whenever we have
    UITableViewController *tableVC = contentNavigationController.viewControllers.lastObject;
    if ([tableVC isKindOfClass:UITableViewController.class]) {
        [tableVC.tableView reloadData];
    }
}

- (void)displayProgress:(NSString *)status {
    if (status == nil) {
        [(UIActivityIndicatorView *)self.toolbarItems[0].customView stopAnimating];
    } else {
        self.toolbarItems[1].title = status;
    }
}

- (void)enableJITWithAltKit {
    [ALTServerManager.sharedManager startDiscovering];
    [ALTServerManager.sharedManager autoconnectWithCompletionHandler:^(ALTServerConnection *connection, NSError *error) {
        if (error) {
            NSLog(@"[AltKit] Could not auto-connect to server. %@", error.localizedRecoverySuggestion);
            [self displayProgress:localize(@"login.jit.fail", nil)];
            [self displayProgress:nil];
        }
        [connection enableUnsignedCodeExecutionWithCompletionHandler:^(BOOL success, NSError *error) {
            if (success) {
                NSLog(@"[AltKit] Successfully enabled JIT compilation!");
                [ALTServerManager.sharedManager stopDiscovering];
                [self displayProgress:localize(@"login.jit.enabled", nil)];
                [self displayProgress:nil];
            } else {
                NSLog(@"[AltKit] Error enabling JIT: %@", error.localizedRecoverySuggestion);
                [self displayProgress:localize(@"login.jit.fail", nil)];
                [self displayProgress:nil];
            }
            [connection disconnect];
        }];
    }];
}

- (NSArray<NSURL *> *)collectDiagnosticReportItems {
    NSFileManager *fm = NSFileManager.defaultManager;
    const char *homeEnv = getenv("AME_HOME");
    if (!homeEnv || !*homeEnv) return @[];
    NSString *home = @(homeEnv);
    NSMutableArray<NSURL *> *items = [NSMutableArray array];

    for (NSString *name in @[@"latestlog.txt", @"latestlog.old.txt", @"mobilegl.log"]) {
        NSString *path = [home stringByAppendingPathComponent:name];
        if ([fm fileExistsAtPath:path]) {
            [items addObject:[NSURL fileURLWithPath:path]];
        }
    }

    NSDirectoryEnumerator *enumerator =
        [fm enumeratorAtURL:[NSURL fileURLWithPath:home]
  includingPropertiesForKeys:@[NSURLIsDirectoryKey]
                     options:NSDirectoryEnumerationSkipsHiddenFiles
                errorHandler:nil];
    NSUInteger hsErrFound = 0;
    static NSSet<NSString *> *skipDirNames;
    if (!skipDirNames) {
        skipDirNames = [NSSet setWithArray:@[@"versions", @"libraries", @"assets", @"java_runtimes"]];
    }
    for (NSURL *url in enumerator) {
        NSNumber *isDir = nil;
        [url getResourceValue:&isDir forKey:NSURLIsDirectoryKey error:nil];
        NSString *name = url.lastPathComponent;
        if (isDir.boolValue && [skipDirNames containsObject:name]) {
            [enumerator skipDescendants];
            continue;
        }
        if (!isDir.boolValue && [name hasPrefix:@"hs_err_pid"] && [url.pathExtension isEqualToString:@"log"]) {
            [items addObject:url];
            hsErrFound++;
            if (hsErrFound >= 3) break; // don't attach an unbounded number
        }
    }

    NSMutableString *info = [NSMutableString string];
    [info appendFormat:@"Amethyst version: %@-%s\n", NSBundle.mainBundle.infoDictionary[@"CFBundleShortVersionString"], CONFIG_TYPE];
    [info appendFormat:@"Commit: %s (%s)\n", CONFIG_COMMIT, CONFIG_BRANCH];
    [info appendFormat:@"Device: %@\n", [HostManager GetModelName]];
    [info appendFormat:@"OS: %@\n", UIDevice.currentDevice.completeOSVersion];
    const char *installType = getenv("AME_DETECTEDINST");
    [info appendFormat:@"Install type: %s\n", installType ? installType : "unknown"];
    [info appendFormat:@"Renderer: %@\n", [PLProfiles resolveKeyForCurrentProfile:@"renderer"]];

    NSString *infoPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"amethyst_diagnostic_info.txt"];
    NSError *writeError = nil;
    if ([info writeToFile:infoPath atomically:YES encoding:NSUTF8StringEncoding error:&writeError]) {
        [items addObject:[NSURL fileURLWithPath:infoPath]];
    } else {
        NSLog(@"[LauncherMenuViewController] Failed to write diagnostic info file: %@", writeError);
    }

    return items;
}

@end
