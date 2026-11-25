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
@property(nonatomic) UILabel *versionValueLabel;
@property(nonatomic) UILabel *runtimeValueLabel;
@property(nonatomic) UILabel *rendererValueLabel;
@property(nonatomic) UILabel *ramValueLabel;
@property(nonatomic) UIStackView *contentStack;
@property(nonatomic) UIButton *versionButton;
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

- (UIColor *)nexaColorRed:(CGFloat)red green:(CGFloat)green blue:(CGFloat)blue {
    return [UIColor colorWithRed:red / 255.0 green:green / 255.0 blue:blue / 255.0 alpha:1.0];
}

- (UILabel *)labelWithText:(NSString *)text size:(CGFloat)size weight:(UIFontWeight)weight color:(UIColor *)color {
    UILabel *label = [UILabel new];
    label.text = text;
    label.font = [UIFont systemFontOfSize:size weight:weight];
    label.textColor = color;
    label.numberOfLines = 1;
    return label;
}

- (void)styleFlatPanel:(UIView *)view radius:(CGFloat)radius {
    view.backgroundColor = [self nexaColorRed:15 green:15 blue:31];
    view.layer.cornerRadius = radius;
    view.layer.borderWidth = 1;
    view.layer.borderColor = [self nexaColorRed:54 green:43 blue:91].CGColor;
    view.layer.masksToBounds = YES;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [self nexaColorRed:5 green:6 blue:16];
    self.navigationItem.title = @"";
    self.navigationItem.rightBarButtonItem = [sidebarViewController drawAccountButton];

    UIScrollView *scrollView = [UIScrollView new];
    scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    scrollView.alwaysBounceVertical = YES;
    [self.view addSubview:scrollView];

    self.contentStack = [UIStackView new];
    self.contentStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.contentStack.axis = UILayoutConstraintAxisVertical;
    self.contentStack.spacing = 16;
    [scrollView addSubview:self.contentStack];

    [NSLayoutConstraint activateConstraints:@[
        [scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [scrollView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [self.contentStack.leadingAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.leadingAnchor constant:24],
        [self.contentStack.trailingAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.trailingAnchor constant:-24],
        [self.contentStack.topAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.topAnchor constant:18],
        [self.contentStack.bottomAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.bottomAnchor constant:-24],
        [self.contentStack.widthAnchor constraintEqualToAnchor:scrollView.frameLayoutGuide.widthAnchor constant:-48]
    ]];

    [self buildHero];
    [self buildLaunchControls];
    [self buildMetadata];
    [self buildFeatureSection];
    [self buildNewsCard];
    [self refreshProfileInformation];
}

- (UIView *)makeCosmicHero {
    UIView *hero = [UIView new];
    hero.translatesAutoresizingMaskIntoConstraints = NO;
    hero.backgroundColor = [self nexaColorRed:5 green:7 blue:21];
    hero.layer.cornerRadius = 24;
    hero.layer.borderWidth = 1;
    hero.layer.borderColor = [self nexaColorRed:69 green:56 blue:124].CGColor;
    hero.clipsToBounds = YES;

    CAGradientLayer *sky = [CAGradientLayer layer];
    sky.frame = CGRectMake(0, 0, 1200, 270);
    sky.colors = @[
        (id)[self nexaColorRed:3 green:5 blue:17].CGColor,
        (id)[self nexaColorRed:18 green:14 blue:46].CGColor,
        (id)[self nexaColorRed:44 green:24 blue:77].CGColor
    ];
    sky.locations = @[@0.0, @0.65, @1.0];
    [hero.layer addSublayer:sky];

    for (NSUInteger i = 0; i < 42; i++) {
        CGFloat x = (CGFloat)((i * 137 + 29) % 997) / 997.0;
        CGFloat y = (CGFloat)((i * 83 + 17) % 211) / 270.0;
        CGFloat diameter = (i % 7 == 0) ? 2.4 : 1.3;
        UIView *star = [[UIView alloc] initWithFrame:CGRectMake(x * 1200, y * 270, diameter, diameter)];
        star.backgroundColor = [UIColor colorWithWhite:1 alpha:(i % 5 == 0) ? 0.95 : 0.55];
        star.layer.cornerRadius = diameter / 2.0;
        [hero addSubview:star];
    }

    UIView *planet = [UIView new];
    planet.translatesAutoresizingMaskIntoConstraints = NO;
    planet.backgroundColor = [self nexaColorRed:16 green:19 blue:49];
    planet.layer.cornerRadius = 150;
    planet.layer.borderWidth = 2;
    planet.layer.borderColor = [self nexaColorRed:129 green:151 blue:255].CGColor;
    planet.layer.shadowColor = [self nexaColorRed:115 green:91 blue:255].CGColor;
    planet.layer.shadowOpacity = 0.9;
    planet.layer.shadowRadius = 32;
    planet.layer.shadowOffset = CGSizeZero;

    CAGradientLayer *planetShade = [CAGradientLayer layer];
    planetShade.frame = CGRectMake(0, 0, 300, 300);
    planetShade.cornerRadius = 150;
    planetShade.colors = @[
        (id)[self nexaColorRed:94 green:117 blue:188].CGColor,
        (id)[self nexaColorRed:35 green:39 blue:84].CGColor,
        (id)[self nexaColorRed:7 green:8 blue:24].CGColor
    ];
    planetShade.startPoint = CGPointMake(0.35, 0);
    planetShade.endPoint = CGPointMake(0.68, 1);
    [planet.layer addSublayer:planetShade];

    UIView *horizon = [UIView new];
    horizon.translatesAutoresizingMaskIntoConstraints = NO;
    CAGradientLayer *horizonGlow = [CAGradientLayer layer];
    horizonGlow.colors = @[
        (id)[UIColor colorWithRed:0.31 green:0.19 blue:0.75 alpha:0.0].CGColor,
        (id)[UIColor colorWithRed:0.62 green:0.34 blue:1.0 alpha:0.72].CGColor,
        (id)[UIColor colorWithRed:0.86 green:0.55 blue:1.0 alpha:0.0].CGColor
    ];
    horizonGlow.startPoint = CGPointMake(0, 0.5);
    horizonGlow.endPoint = CGPointMake(1, 0.5);
    [horizon.layer addSublayer:horizonGlow];
    [hero addSubview:planet];
    [hero addSubview:horizon];
    [NSLayoutConstraint activateConstraints:@[
        [planet.widthAnchor constraintEqualToConstant:300],
        [planet.heightAnchor constraintEqualToConstant:300],
        [planet.centerXAnchor constraintEqualToAnchor:hero.centerXAnchor constant:110],
        [planet.centerYAnchor constraintEqualToAnchor:hero.bottomAnchor constant:18],
        [horizon.leadingAnchor constraintEqualToAnchor:hero.leadingAnchor],
        [horizon.trailingAnchor constraintEqualToAnchor:hero.trailingAnchor],
        [horizon.bottomAnchor constraintEqualToAnchor:hero.bottomAnchor constant:-42],
        [horizon.heightAnchor constraintEqualToConstant:34]
    ]];
    [hero bringSubviewToFront:horizon];

    UILabel *edition = [self labelWithText:@"NEXA  /  MINECRAFT JAVA EDITION" size:12 weight:UIFontWeightBold color:[self nexaColorRed:196 green:171 blue:255]];
    UILabel *title = [self labelWithText:@"Your next world starts here." size:27 weight:UIFontWeightBold color:UIColor.whiteColor];
    UILabel *subtitle = [self labelWithText:@"A launcher built around your Minecraft experience." size:14 weight:UIFontWeightMedium color:[self nexaColorRed:197 green:190 blue:222]];
    edition.translatesAutoresizingMaskIntoConstraints = NO;
    title.translatesAutoresizingMaskIntoConstraints = NO;
    subtitle.translatesAutoresizingMaskIntoConstraints = NO;
    [hero addSubview:edition];
    [hero addSubview:title];
    [hero addSubview:subtitle];
    [NSLayoutConstraint activateConstraints:@[
        [edition.leadingAnchor constraintEqualToAnchor:hero.leadingAnchor constant:26],
        [edition.topAnchor constraintEqualToAnchor:hero.topAnchor constant:28],
        [title.leadingAnchor constraintEqualToAnchor:edition.leadingAnchor],
        [title.topAnchor constraintEqualToAnchor:edition.bottomAnchor constant:10],
        [title.trailingAnchor constraintLessThanOrEqualToAnchor:hero.trailingAnchor constant:-24],
        [subtitle.leadingAnchor constraintEqualToAnchor:edition.leadingAnchor],
        [subtitle.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:8],
        [subtitle.trailingAnchor constraintLessThanOrEqualToAnchor:hero.trailingAnchor constant:-24]
    ]];
    return hero;
}

- (void)buildHero {
    UIView *hero = [self makeCosmicHero];
    [self.contentStack addArrangedSubview:hero];
    [hero.heightAnchor constraintEqualToConstant:218].active = YES;
}

- (void)buildLaunchControls {
    UIStackView *row = [UIStackView new];
    row.translatesAutoresizingMaskIntoConstraints = NO;
    row.axis = UILayoutConstraintAxisHorizontal;
    row.spacing = 14;
    row.alignment = UIStackViewAlignmentFill;
    row.distribution = UIStackViewDistributionFill;

    self.versionButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.versionButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.versionButton.backgroundColor = [self nexaColorRed:20 green:18 blue:39];
    self.versionButton.layer.cornerRadius = 14;
    self.versionButton.layer.borderWidth = 1;
    self.versionButton.layer.borderColor = [self nexaColorRed:80 green:62 blue:132].CGColor;
    self.versionButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    [self.versionButton setTitle:@"  Select version" forState:UIControlStateNormal];
    [self.versionButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    self.versionButton.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    UIImage *versionIcon = [UIImage systemImageNamed:@"cube.fill"];
    [self.versionButton setImage:versionIcon forState:UIControlStateNormal];
    self.versionButton.tintColor = [self nexaColorRed:175 green:119 blue:255];
    self.versionButton.imageEdgeInsets = UIEdgeInsetsMake(0, 14, 0, 10);
    self.versionButton.titleEdgeInsets = UIEdgeInsetsMake(0, 20, 0, 0);
    [self.versionButton addTarget:self action:@selector(selectVersion) forControlEvents:UIControlEventTouchUpInside];

    UIButton *play = [UIButton buttonWithType:UIButtonTypeCustom];
    play.translatesAutoresizingMaskIntoConstraints = NO;
    play.backgroundColor = [self nexaColorRed:117 green:49 blue:232];
    play.layer.cornerRadius = 14;
    play.layer.borderWidth = 1;
    play.layer.borderColor = [self nexaColorRed:174 green:117 blue:255].CGColor;
    [play setTitle:@"Play" forState:UIControlStateNormal];
    [play setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    play.titleLabel.font = [UIFont systemFontOfSize:20 weight:UIFontWeightBold];
    [play setImage:[UIImage systemImageNamed:@"play.fill"] forState:UIControlStateNormal];
    play.tintColor = UIColor.whiteColor;
    play.imageEdgeInsets = UIEdgeInsetsMake(0, -8, 0, 8);
    [play addTarget:self action:@selector(playSelectedVersion:) forControlEvents:UIControlEventTouchUpInside];

    [row addArrangedSubview:self.versionButton];
    [row addArrangedSubview:play];
    [self.contentStack addArrangedSubview:row];
    [self.versionButton.widthAnchor constraintGreaterThanOrEqualToAnchor:row.widthAnchor multiplier:0.52].active = YES;
    [play.heightAnchor constraintEqualToConstant:62].active = YES;
    [self.versionButton.heightAnchor constraintEqualToConstant:62].active = YES;
}

- (void)selectVersion {
    LauncherNavigationController *navigation = (LauncherNavigationController *)self.splitViewController.viewControllers.lastObject;
    [navigation showVersionPicker];
}

- (void)playSelectedVersion:(UIButton *)sender {
    LauncherNavigationController *navigation = (LauncherNavigationController *)self.splitViewController.viewControllers.lastObject;
    [navigation launchSelectedVersionFromHome:sender];
}

- (UIView *)metadataCardWithTitle:(NSString *)title valueLabel:(UILabel **)valueLabel symbol:(NSString *)symbol {
    UIView *card = [UIView new];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    [self styleFlatPanel:card radius:13];

    UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:symbol]];
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    icon.tintColor = [self nexaColorRed:170 green:105 blue:255];
    icon.contentMode = UIViewContentModeScaleAspectFit;

    UILabel *caption = [self labelWithText:title.uppercaseString size:10 weight:UIFontWeightBold color:[self nexaColorRed:139 green:133 blue:160]];
    caption.translatesAutoresizingMaskIntoConstraints = NO;
    UILabel *value = [self labelWithText:@"—" size:14 weight:UIFontWeightSemibold color:UIColor.whiteColor];
    value.translatesAutoresizingMaskIntoConstraints = NO;
    value.adjustsFontSizeToFitWidth = YES;
    value.minimumScaleFactor = 0.72;
    *valueLabel = value;

    [card addSubview:icon];
    [card addSubview:caption];
    [card addSubview:value];
    [NSLayoutConstraint activateConstraints:@[
        [icon.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:12],
        [icon.centerYAnchor constraintEqualToAnchor:card.centerYAnchor],
        [icon.widthAnchor constraintEqualToConstant:23],
        [icon.heightAnchor constraintEqualToConstant:23],
        [caption.leadingAnchor constraintEqualToAnchor:icon.trailingAnchor constant:10],
        [caption.topAnchor constraintEqualToAnchor:card.topAnchor constant:11],
        [caption.trailingAnchor constraintLessThanOrEqualToAnchor:card.trailingAnchor constant:-8],
        [value.leadingAnchor constraintEqualToAnchor:caption.leadingAnchor],
        [value.topAnchor constraintEqualToAnchor:caption.bottomAnchor constant:4],
        [value.trailingAnchor constraintLessThanOrEqualToAnchor:card.trailingAnchor constant:-8],
        [value.bottomAnchor constraintLessThanOrEqualToAnchor:card.bottomAnchor constant:-8],
        [card.heightAnchor constraintEqualToConstant:64]
    ]];
    return card;
}

- (void)buildMetadata {
    UIStackView *row = [UIStackView new];
    row.axis = UILayoutConstraintAxisHorizontal;
    row.spacing = 10;
    row.distribution = UIStackViewDistributionFillEqually;
    [row addArrangedSubview:[self metadataCardWithTitle:@"Java" valueLabel:&_runtimeValueLabel symbol:@"cup.and.saucer.fill"]];
    [row addArrangedSubview:[self metadataCardWithTitle:@"Renderer" valueLabel:&_rendererValueLabel symbol:@"display"]];
    [row addArrangedSubview:[self metadataCardWithTitle:@"Memory" valueLabel:&_ramValueLabel symbol:@"memorychip"]];
    [self.contentStack addArrangedSubview:row];
}

- (UIView *)makeFeatureCard:(NSString *)title subtitle:(NSString *)subtitle symbol:(NSString *)symbol index:(NSUInteger)index {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.backgroundColor = [self nexaColorRed:15 green:15 blue:31];
    button.layer.cornerRadius = 16;
    button.layer.borderWidth = 1;
    button.layer.borderColor = [self nexaColorRed:54 green:43 blue:91].CGColor;
    button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;

    UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:symbol]];
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    icon.tintColor = [self nexaColorRed:174 green:105 blue:255];
    icon.contentMode = UIViewContentModeScaleAspectFit;

    UILabel *name = [self labelWithText:title size:16 weight:UIFontWeightSemibold color:UIColor.whiteColor];
    name.translatesAutoresizingMaskIntoConstraints = NO;
    UILabel *detail = [self labelWithText:subtitle size:12 weight:UIFontWeightMedium color:[self nexaColorRed:160 green:151 blue:185]];
    detail.translatesAutoresizingMaskIntoConstraints = NO;

    [button addSubview:icon];
    [button addSubview:name];
    [button addSubview:detail];
    [NSLayoutConstraint activateConstraints:@[
        [icon.leadingAnchor constraintEqualToAnchor:button.leadingAnchor constant:16],
        [icon.centerYAnchor constraintEqualToAnchor:button.centerYAnchor],
        [icon.widthAnchor constraintEqualToConstant:31],
        [icon.heightAnchor constraintEqualToConstant:31],
        [name.leadingAnchor constraintEqualToAnchor:icon.trailingAnchor constant:12],
        [name.topAnchor constraintEqualToAnchor:button.topAnchor constant:20],
        [name.trailingAnchor constraintLessThanOrEqualToAnchor:button.trailingAnchor constant:-10],
        [detail.leadingAnchor constraintEqualToAnchor:name.leadingAnchor],
        [detail.topAnchor constraintEqualToAnchor:name.bottomAnchor constant:5],
        [detail.trailingAnchor constraintLessThanOrEqualToAnchor:button.trailingAnchor constant:-8]
    ]];
    [button.heightAnchor constraintEqualToConstant:94].active = YES;
    [button addAction:[UIAction actionWithHandler:^(__kindof UIAction *action) {
        [sidebarViewController openOptionAtIndex:index];
    }] forControlEvents:UIControlEventPrimaryActionTriggered];
    return button;
}

- (void)buildFeatureSection {
    UIStackView *row = [UIStackView new];
    row.axis = UILayoutConstraintAxisHorizontal;
    row.spacing = 12;
    row.distribution = UIStackViewDistributionFillEqually;
    [row addArrangedSubview:[self makeFeatureCard:@"Mods" subtitle:@"Manage mods" symbol:@"puzzlepiece.extension.fill" index:4]];
    [row addArrangedSubview:[self makeFeatureCard:@"Resource Packs" subtitle:@"Customize visuals" symbol:@"folder.fill" index:5]];
    [row addArrangedSubview:[self makeFeatureCard:@"Shaders" subtitle:@"Graphics settings" symbol:@"sparkles" index:6]];
    [self.contentStack addArrangedSubview:row];
}

- (void)buildNewsCard {
    UIView *panel = [UIView new];
    panel.translatesAutoresizingMaskIntoConstraints = NO;
    [self styleFlatPanel:panel radius:16];

    UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"megaphone.fill"]];
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    icon.tintColor = [self nexaColorRed:174 green:105 blue:255];
    UILabel *title = [self labelWithText:@"News & Updates" size:18 weight:UIFontWeightBold color:UIColor.whiteColor];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    UILabel *detail = [self labelWithText:@"Your latest NEXA launcher updates" size:13 weight:UIFontWeightMedium color:[self nexaColorRed:169 green:159 blue:194]];
    detail.translatesAutoresizingMaskIntoConstraints = NO;
    UIButton *open = [UIButton buttonWithType:UIButtonTypeSystem];
    open.translatesAutoresizingMaskIntoConstraints = NO;
    [open setTitle:@"View all  →" forState:UIControlStateNormal];
    [open setTitleColor:[self nexaColorRed:190 green:135 blue:255] forState:UIControlStateNormal];
    open.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    [open addTarget:self action:@selector(openNews) forControlEvents:UIControlEventTouchUpInside];

    [panel addSubview:icon];
    [panel addSubview:title];
    [panel addSubview:detail];
    [panel addSubview:open];
    [NSLayoutConstraint activateConstraints:@[
        [icon.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:18],
        [icon.topAnchor constraintEqualToAnchor:panel.topAnchor constant:18],
        [icon.widthAnchor constraintEqualToConstant:23],
        [icon.heightAnchor constraintEqualToConstant:23],
        [title.leadingAnchor constraintEqualToAnchor:icon.trailingAnchor constant:12],
        [title.centerYAnchor constraintEqualToAnchor:icon.centerYAnchor],
        [open.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-16],
        [open.centerYAnchor constraintEqualToAnchor:title.centerYAnchor],
        [detail.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [detail.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:7],
        [detail.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-18],
        [detail.bottomAnchor constraintEqualToAnchor:panel.bottomAnchor constant:-18],
        [panel.heightAnchor constraintEqualToConstant:92]
    ]];
    [open setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [self.contentStack addArrangedSubview:panel];
}

- (void)openNews {
    [sidebarViewController openOptionAtIndex:3];
}

- (void)refreshProfileInformation {
    NSString *profileName = PLProfiles.current.selectedProfileName ?: @"Default";
    NSDictionary *profile = PLProfiles.current.profiles[profileName];
    NSString *version = profile[@"lastVersionId"] ?: @"Choose a version";
    NSString *javaVersion = [PLProfiles resolveKeyForCurrentProfile:@"javaVersion"] ?: @"0";
    NSString *runtime = [javaVersion isEqualToString:@"0"] ? @"Auto" : [NSString stringWithFormat:@"Java %@", javaVersion];
    NSString *renderer = [PLProfiles resolveKeyForCurrentProfile:@"renderer"] ?: @"Default";
    NSString *ram = getPrefBool(@"java.auto_ram") ? @"Auto" : [NSString stringWithFormat:@"%ld MB", (long)getPrefInt(@"java.allocated_memory")];
    self.versionButton.accessibilityLabel = [NSString stringWithFormat:@"Selected Minecraft version: %@", version];
    [self.versionButton setTitle:[NSString stringWithFormat:@"  %@", version] forState:UIControlStateNormal];
    self.runtimeValueLabel.text = runtime;
    self.rendererValueLabel.text = renderer;
    self.ramValueLabel.text = ram;
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
@property(nonatomic) NSUInteger activeOptionIndex;
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
        if (activityVC.popoverPresentationController) {
            activityVC.popoverPresentationController.sourceView = self.view;
            activityVC.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 1, 1);
        }
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
    [self.navigationController.view addSubview:self.nexaFooterView];
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
    CGFloat footerBottom = self.navigationController.isToolbarHidden ? self.navigationController.view.bounds.size.height : CGRectGetMinY(self.navigationController.toolbar.frame);
    self.nexaFooterView.frame = CGRectMake(0, footerBottom - footerHeight, self.navigationController.view.bounds.size.width, footerHeight);
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
    if (index < 3) {
        NSIndexPath *path = [NSIndexPath indexPathForRow:index inSection:0];
        [self.tableView selectRowAtIndexPath:path animated:NO scrollPosition:UITableViewScrollPositionNone];
    }
    LauncherMenuCustomItem *selected = self.options[index];
    if (selected.action) {
        selected.action();
        return;
    }
    if (self.isInitialVc) {
        self.isInitialVc = NO;
    } else {
        self.options[self.activeOptionIndex].vcArray = contentNavigationController.viewControllers;
    }
    [contentNavigationController setViewControllers:selected.vcArray animated:NO];
    self.activeOptionIndex = index;
    if (index < 3) self.lastSelectedIndex = (int)index;
    contentNavigationController.toolbarHidden = index != 1;
    selected.vcArray[0].navigationItem.rightBarButtonItem = self.accountBtnItem;
    if ([selected.vcArray[0] respondsToSelector:@selector(importLocalFile)]) {
        UIImage *sourceImage = [UIImage imageNamed:@"ImportContent"];
        UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(24, 24)];
        UIImage *smallImage = [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
            CGFloat scale = MIN(24 / sourceImage.size.width, 24 / sourceImage.size.height);
            CGSize size = CGSizeMake(sourceImage.size.width * scale, sourceImage.size.height * scale);
            [sourceImage drawInRect:CGRectMake((24 - size.width) / 2, (24 - size.height) / 2, size.width, size.height)];
        }];
        UIBarButtonItem *importItem = [[UIBarButtonItem alloc] initWithImage:[smallImage imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] style:UIBarButtonItemStylePlain target:selected.vcArray[0] action:@selector(importLocalFile)];
        importItem.tintColor = UIColor.labelColor;
        importItem.accessibilityLabel = localize(@"preference.title.import_content", nil);
        selected.vcArray[0].navigationItem.leftBarButtonItems = @[self.splitViewController.displayModeButtonItem, importItem];
    } else {
        selected.vcArray[0].navigationItem.leftBarButtonItems = @[self.splitViewController.displayModeButtonItem];
    }
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
