#import "RNGADBannerView.h"
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

@implementation RNGADBannerView
{
    DFPBannerView *_bannerView;
}

- (void)dealloc
{
    [_bannerView removeFromSuperview];
    _bannerView.delegate = nil;
    _bannerView.adSizeDelegate = nil;
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
        _bannerView.rootViewController = rootViewController;
        [self addSubview:_bannerView];
    }
    return self;
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-missing-super-calls"
- (void)insertReactSubview:(UIView *)subview atIndex:(NSInteger)atIndex
{
    RCTLogError(@"RNGADBannerView cannot have subviews");
}
#pragma clang diagnostic pop

- (void)loadBanner
{
    if(self.onSizeChange) {
        CGSize size = CGSizeFromGADAdSize(_bannerView.adSize);
        if(!CGSizeEqualToSize(size, self.bounds.size)) {
            self.onSizeChange(@{
                                @"width": @(size.width),
                                @"height": @(size.height)
                                });
        }
    }
    DFPRequest *request = [DFPRequest request];
    request.testDevices = _testDevices;
    
	NSLog(@"npa gad banner: %@", _npa ? @"yes" : @"no");
	if (_npa == YES){
		//https://developers.google.com/admob/ios/eu-consent#objective-c_7
		GADExtras *extras = [[GADExtras alloc] init];
		extras.additionalParameters = @{@"npa": @"1"};
		[request registerAdNetworkExtras:extras];
	}
	if (_targets!=nil){
		[request setCustomTargeting:_targets];
	}
	
	NSMutableArray *x = [[NSMutableArray alloc] init];
			
	[x addObject:NSValueFromGADAdSize(kGADAdSizeFluid)];
	for (int i=0; i< _validAdSizes.count; i++){
		NSString *item=_validAdSizes[i];
		NSValue *s = nil;
		
		if ( [item containsString:@"x"] ){
			NSArray *wh = [item componentsSeparatedByString:@"x"];
			int w = [wh[0] intValue];
			int h = [wh[1] intValue];
			
			CGSize size=CGSizeMake(w, h);
			s = NSValueFromGADAdSize( GADAdSizeFromCGSize( size ) );
			
		} else if ( [item isEqualToString:@"banner"]){
			s=NSValueFromGADAdSize(kGADAdSizeBanner);
			
		} else if ([item isEqualToString:@"largeBanner"]){
			s=NSValueFromGADAdSize(kGADAdSizeLargeBanner);
		}
		if (s != nil){
			[x addObject: s ];
		}
	}

	_bannerView.validAdSizes = x;
	[_bannerView loadRequest:request];
}

- (void)setTestDevices:(NSArray *)testDevices
{
    _testDevices = RNAdMobProcessTestDevices(testDevices, kGADSimulatorID);
}
- (void)validAdSizes:(NSArray *)validAdSizes
{
	_validAdSizes = validAdSizes;
}


-(void)layoutSubviews
{
    [super layoutSubviews];
    _bannerView.frame = self.bounds;
}

# pragma mark GADBannerViewDelegate

/// Tells the delegate an ad request loaded an ad.
- (void)adViewDidReceiveAd:(__unused GADBannerView *)adView
{
   if (self.onAdLoaded) {
       self.onAdLoaded(@{});
   }
}

/// Tells the delegate an ad request failed.
- (void)adView:(__unused GADBannerView *)adView
didFailToReceiveAdWithError:(GADRequestError *)error
{
    if (self.onAdFailedToLoad) {
        self.onAdFailedToLoad(@{ @"error": @{ @"message": [error localizedDescription] } });
    }
}

/// Tells the delegate that a full screen view will be presented in response
/// to the user clicking on an ad.
- (void)adViewWillPresentScreen:(__unused GADBannerView *)adView
{
    if (self.onAdOpened) {
        self.onAdOpened(@{});
    }
}

/// Tells the delegate that the full screen view will be dismissed.
- (void)adViewWillDismissScreen:(__unused GADBannerView *)adView
{
    if (self.onAdClosed) {
        self.onAdClosed(@{});
    }
}

/// Tells the delegate that a user click will open another app (such as
/// the App Store), backgrounding the current app.
- (void)adViewWillLeaveApplication:(__unused GADBannerView *)adView
{
    if (self.onAdLeftApplication) {
        self.onAdLeftApplication(@{});
    }
}

# pragma mark GADAdSizeDelegate

- (void)adView:(__unused GADBannerView *)bannerView willChangeAdSizeTo:(GADAdSize)size
{
    CGSize adSize = CGSizeFromGADAdSize(size);
    self.onSizeChange(@{
                              @"width": @(adSize.width),
                              @"height": @(adSize.height) });
}

@end
