#import "RNAdMobInterstitial.h"
#import "RNAdMobUtils.h"

#if __has_include(<React/RCTUtils.h>)
#import <React/RCTUtils.h>
#else
#import "RCTUtils.h"
#endif

static NSString *const kEventAdLoaded = @"interstitialAdLoaded";
static NSString *const kEventAdFailedToLoad = @"interstitialAdFailedToLoad";
static NSString *const kEventAdOpened = @"interstitialAdOpened";
static NSString *const kEventAdFailedToOpen = @"interstitialAdFailedToOpen";
static NSString *const kEventAdClosed = @"interstitialAdClosed";
static NSString *const kEventAdLeftApplication = @"interstitialAdLeftApplication";

@implementation RNAdMobInterstitial
{
    GADInterstitial  *_interstitial;
    NSString *_adUnitID;
    NSArray *_testDevices;
	BOOL _npa;
	NSDictionary *_targets;
	
    RCTPromiseResolveBlock _requestAdResolve;
    RCTPromiseRejectBlock _requestAdReject;
    BOOL hasListeners;
}

- (dispatch_queue_t)methodQueue
{
    return dispatch_get_main_queue();
}

+ (BOOL)requiresMainQueueSetup
{
    return NO;
}

RCT_EXPORT_MODULE();

- (NSArray<NSString *> *)supportedEvents
{
    return @[
             kEventAdLoaded,
             kEventAdFailedToLoad,
             kEventAdOpened,
             kEventAdFailedToOpen,
             kEventAdClosed,
             kEventAdLeftApplication ];
}

#pragma mark exported methods

RCT_EXPORT_METHOD(setAdUnitID:(NSString *)adUnitID)
{
    _adUnitID = adUnitID;
}
RCT_EXPORT_METHOD(setNPA:(BOOL)npa)
{
	_npa = npa;
}
RCT_EXPORT_METHOD(setTargets:(NSDictionary *)targets)
{
	_targets = targets;
}

RCT_EXPORT_METHOD(setTestDevices:(NSArray *)testDevices)
{
    _testDevices = RNAdMobProcessTestDevices(testDevices, kGADSimulatorID);
}

RCT_EXPORT_METHOD(requestAd:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
{
    _requestAdResolve = nil;
    _requestAdReject = nil;

    if ([_interstitial hasBeenUsed] || _interstitial == nil) {
        _requestAdResolve = resolve;
        _requestAdReject = reject;

        _interstitial = [[GADInterstitial alloc] initWithAdUnitID:_adUnitID];
        _interstitial.delegate = self;

        DFPRequest *request = [DFPRequest request];
        request.testDevices = _testDevices;
		
		NSLog(@"npa interstitial: %@", _npa ? @"yes" : @"no");
		if (_npa == YES){
			//https://developers.google.com/admob/ios/eu-consent#objective-c_7
			GADExtras *extras = [[GADExtras alloc] init];
			extras.additionalParameters = @{@"npa": @"1"};
			[request registerAdNetworkExtras:extras];
		}
		if (_targets!=nil){
			[request setCustomTargeting:_targets];
		}
		
        [_interstitial loadRequest:request];
    } else {
        reject(@"E_AD_ALREADY_LOADED", @"Ad is already loaded.", nil);
		_interstitial = nil;
		
    }
}

RCT_EXPORT_METHOD(showAd:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
{
    if ([_interstitial isReady]) {
        [_interstitial presentFromRootViewController:[UIApplication sharedApplication].delegate.window.rootViewController];
        resolve(nil);
    }
    else {
        reject(@"E_AD_NOT_READY", @"Ad is not ready.", nil);
    }
}

RCT_EXPORT_METHOD(isReady:(RCTResponseSenderBlock)callback)
{
    callback(@[[NSNumber numberWithBool:[_interstitial isReady]]]);
}

- (void)startObserving
{
    hasListeners = YES;
}

- (void)stopObserving
{
    hasListeners = NO;
}

#pragma mark GADInterstitialDelegate

- (void)interstitialDidReceiveAd:(__unused GADInterstitial *)ad
{
    if (hasListeners) {
        [self sendEventWithName:kEventAdLoaded body:nil];
    }
	if (_requestAdResolve != nil){
		_requestAdResolve(nil);
	}
    
}

- (void)interstitial:(__unused GADInterstitial *)interstitial didFailToReceiveAdWithError:(GADRequestError *)error
{
    if (hasListeners) {
        NSDictionary *jsError = RCTJSErrorFromCodeMessageAndNSError(@"E_AD_REQUEST_FAILED", error.localizedDescription, error);
        [self sendEventWithName:kEventAdFailedToLoad body:jsError];
    }
	if (_requestAdReject != nil){
		_requestAdReject(@"E_AD_REQUEST_FAILED", error.localizedDescription, error);
		
		_interstitial = nil;
	}
}

- (void)interstitialWillPresentScreen:(__unused GADInterstitial *)ad
{
    if (hasListeners){
        [self sendEventWithName:kEventAdOpened body:nil];
    }
}

- (void)interstitialDidFailToPresentScreen:(__unused GADInterstitial *)ad
{
    if (hasListeners){
        [self sendEventWithName:kEventAdFailedToOpen body:nil];
    }
}

- (void)interstitialWillDismissScreen:(__unused GADInterstitial *)ad
{
    if (hasListeners) {
        [self sendEventWithName:kEventAdClosed body:nil];
    }
}

- (void)interstitialWillLeaveApplication:(__unused GADInterstitial *)ad
{
    if (hasListeners) {
        [self sendEventWithName:kEventAdLeftApplication body:nil];
    }
}

@end
