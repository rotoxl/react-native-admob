#import "RNDFPBannerView.h"
#import "RNAdMobUtils.h"

#if __has_include(<React/RCTBridgeModule.h>)
#import <React/RCTBridgeModule.h>
#import <React/UIView+React.h>
#import <React/RCTLog.h>
#else
#import "RCTBridgeModule.h"
#import "UIView+React.h"
#import "RCTLog.h"
#endif

#include "RCTConvert+GADAdSize.h"

@implementation RNDFPBannerView
{
    DFPBannerView  *_bannerView;
}

- (void)dealloc
{
	[_bannerView removeFromSuperview];
	
    _bannerView.delegate = nil;
    _bannerView.adSizeDelegate = nil;
    _bannerView.appEventDelegate = nil;
	
	_bannerView = nil;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    if ((self = [super initWithFrame:frame])) {
        super.backgroundColor = [UIColor clearColor];

        UIWindow *keyWindow = [[UIApplication sharedApplication] keyWindow];
        UIViewController *rootViewController = [keyWindow rootViewController];

        _bannerView = [[DFPBannerView alloc] initWithAdSize:kGADAdSizeFluid];
        _bannerView.delegate = self;
        _bannerView.adSizeDelegate = self;
        _bannerView.appEventDelegate = self;
        _bannerView.rootViewController = rootViewController;
        //[self addSubview:_bannerView]; // --> wait till adViewDidReceiveAd
    }

    return self;
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-missing-super-calls"
- (void)insertReactSubview:(UIView *)subview atIndex:(NSInteger)atIndex
{
    RCTLogError(@"RNDFPBannerView cannot have subviews");
}
#pragma clang diagnostic pop

- (void)loadBanner {
    DFPRequest *request = [DFPRequest request];
    request.testDevices = _testDevices;
	
	NSLog(@"npa dfpbanner: %@", _npa ? @"yes" : @"no");
	if (_npa == YES){
		//https://developers.google.com/admob/ios/eu-consent#objective-c_7
		GADExtras *extras = [[GADExtras alloc] init];
		extras.additionalParameters = @{@"npa": @"1"};
		[request registerAdNetworkExtras:extras];
	}
	if (_targets!=nil){
		[request setCustomTargeting:_targets];
	}
	
	NSLog(@"cargando _bannerView");
    [_bannerView loadRequest:request];
}

- (void)setValidAdSizes:(NSArray *)adSizes
{
    __block NSMutableArray *validAdSizes = [[NSMutableArray alloc] initWithCapacity:adSizes.count+1];
	[validAdSizes addObject:NSValueFromGADAdSize(kGADAdSizeFluid)];
	
    [adSizes enumerateObjectsUsingBlock:^(id jsonValue, NSUInteger idx, __unused BOOL *stop) {
        GADAdSize adSize = [RCTConvert GADAdSize:jsonValue];
        if (GADAdSizeEqualToSize(adSize, kGADAdSizeInvalid)) {
			if ( [jsonValue containsString:@"x"] ){
				NSArray *wh = [jsonValue componentsSeparatedByString:@"x"];
				int w = [wh[0] intValue];
				int h = [wh[1] intValue];
				
				CGSize size=CGSizeMake(w, h);
				adSize = GADAdSizeFromCGSize( size );
			}
			if (GADAdSizeEqualToSize(adSize, kGADAdSizeInvalid)) {
				RCTLogWarn(@"Invalid adSize %@", jsonValue);
			} else {
				[validAdSizes addObject:NSValueFromGADAdSize(adSize)];
			}
        } else {
            [validAdSizes addObject:NSValueFromGADAdSize(adSize)];
        }
    }];
    _bannerView.validAdSizes = validAdSizes;
}

- (void)setNPA:(BOOL)npa
{
	_npa = npa;
}
- (void)setTargets:(NSDictionary *)targets
{
	_targets = targets;
}

- (void)setTestDevices:(NSArray *)testDevices
{
    _testDevices = RNAdMobProcessTestDevices(testDevices, kDFPSimulatorID);
}

-(void)layoutSubviews
{
    [super layoutSubviews];
    _bannerView.frame = self.bounds;
}

# pragma mark GADBannerViewDelegate

/// Tells the delegate an ad request loaded an ad.
- (void)adViewDidReceiveAd:(DFPBannerView *)adView
{
	NSLog(@"_bannerView adViewDidReceiveAd");
	[self addSubview:_bannerView];

    if (self.onSizeChange) {
        self.onSizeChange(@{
                            @"width": @(adView.frame.size.width),
                            @"height": @(adView.frame.size.height) });
    }
    if (self.onAdLoaded) {
        self.onAdLoaded(@{});
    }
}

/// Tells the delegate an ad request failed.
- (void)adView:(DFPBannerView *)adView
didFailToReceiveAdWithError:(GADRequestError *)error
{
	NSLog(@"_bannerView didFailToReceiveAdWithError");

    if (self.onAdFailedToLoad) {
        self.onAdFailedToLoad(@{ @"error": @{ @"message": [error localizedDescription] } });
    }
}

/// Tells the delegate that a full screen view will be presented in response
/// to the user clicking on an ad.
- (void)adViewWillPresentScreen:(DFPBannerView *)adView
{
	NSLog(@"_bannerView adViewWillPresentScreen");

    if (self.onAdOpened) {
        self.onAdOpened(@{});
    }
}

/// Tells the delegate that the full screen view will be dismissed.
- (void)adViewWillDismissScreen:(__unused DFPBannerView *)adView
{
	NSLog(@"_bannerView adViewWillDismissScreen");

    if (self.onAdClosed) {
        self.onAdClosed(@{});
    }
}

/// Tells the delegate that a user click will open another app (such as
/// the App Store), backgrounding the current app.
- (void)adViewWillLeaveApplication:(DFPBannerView *)adView
{
	NSLog(@"_bannerView adViewWillLeaveApplication");

    if (self.onAdLeftApplication) {
        self.onAdLeftApplication(@{});
    }
}

# pragma mark GADAdSizeDelegate

- (void)adView:(GADBannerView *)bannerView willChangeAdSizeTo:(GADAdSize)size
{
	NSLog(@"_bannerView adViewWillLeaveApplication");
    CGSize adSize = CGSizeFromGADAdSize(size);
    self.onSizeChange(@{
                        @"width": @(adSize.width),
                        @"height": @(adSize.height) });
}

# pragma mark GADAppEventDelegate

- (void)adView:(GADBannerView *)banner didReceiveAppEvent:(NSString *)name withInfo:(NSString *)info
{
    if (self.onAppEvent) {
        self.onAppEvent(@{ @"name": name, @"info": info });
    }
}

@end
