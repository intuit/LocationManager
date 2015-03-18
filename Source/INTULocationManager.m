//
//  INTULocationManager.m
//
//  Copyright (c) 2014-2015 Intuit Inc.
//
//  Permission is hereby granted, free of charge, to any person obtaining
//  a copy of this software and associated documentation files (the
//  "Software"), to deal in the Software without restriction, including
//  without limitation the rights to use, copy, modify, merge, publish,
//  distribute, sublicense, and/or sell copies of the Software, and to
//  permit persons to whom the Software is furnished to do so, subject to
//  the following conditions:
//
//  The above copyright notice and this permission notice shall be
//  included in all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
//  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
//  MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
//  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
//  LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
//  OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
//  WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

#import "INTULocationManager.h"
#import "INTULocationManager+Internal.h"
#import "INTULocationRequest.h"


#ifndef INTU_ENABLE_LOGGING
#   ifdef DEBUG
#       define INTU_ENABLE_LOGGING 1
#   else
#       define INTU_ENABLE_LOGGING 0
#   endif /* DEBUG */
#endif /* INTU_ENABLE_LOGGING */

#if INTU_ENABLE_LOGGING
#   define INTULMLog(...)          NSLog(@"INTULocationManager: %@", [NSString stringWithFormat:__VA_ARGS__]);
#else
#   define INTULMLog(...)
#endif /* INTU_ENABLE_LOGGING */


@interface INTULocationManager () <CLLocationManagerDelegate, INTULocationRequestDelegate>

/** The instance of CLLocationManager encapsulated by this class. */
@property (nonatomic, strong) CLLocationManager *locationManager;
/** The most recent current location, or nil if the current location is unknown, invalid, or stale. */
@property (nonatomic, strong) CLLocation *currentLocation;
/** Whether or not the CLLocationManager is currently sending location updates. */
@property (nonatomic, assign) BOOL isUpdatingLocation;
/** Whether an error occurred during the last location update. */
@property (nonatomic, assign) BOOL updateFailed;

// An array of pending location requests in the form:
// @[ INTULocationRequest *locationRequest1, INTULocationRequest *locationRequest2, ... ]
@property (nonatomic, strong) NSMutableArray *locationRequests;

@end


@implementation INTULocationManager

static id _sharedInstance;

/**
 Returns the current state of location services for this app, based on the system settings and user authorization status.
 */
+ (INTULocationServicesState)locationServicesState
{
    if ([CLLocationManager locationServicesEnabled] == NO) {
        return INTULocationServicesStateDisabled;
    }
    else if ([CLLocationManager authorizationStatus] == kCLAuthorizationStatusNotDetermined) {
        return INTULocationServicesStateNotDetermined;
    }
    else if ([CLLocationManager authorizationStatus] == kCLAuthorizationStatusDenied) {
        return INTULocationServicesStateDenied;
    }
    else if ([CLLocationManager authorizationStatus] == kCLAuthorizationStatusRestricted) {
        return INTULocationServicesStateRestricted;
    }
    
    return INTULocationServicesStateAvailable;
}

/**
 Returns the singleton instance of this class.
 */
+ (instancetype)sharedInstance
{
    static dispatch_once_t _onceToken;
    dispatch_once(&_onceToken, ^{
        _sharedInstance = [[self alloc] init];
    });
    return _sharedInstance;
}

- (instancetype)init
{
    NSAssert(_sharedInstance == nil, @"Only one instance of INTULocationManager should be created. Use +[INTULocationManager sharedInstance] instead.");
    self = [super init];
    if (self) {
        _locationManager = [[CLLocationManager alloc] init];
        _locationManager.delegate = self;
        _locationRequests = [NSMutableArray array];
    }
    return self;
}

/**
 Asynchronously requests the current location of the device using location services.
 
 @param desiredAccuracy The accuracy level desired (refers to the accuracy and recency of the location).
 @param timeout         The maximum amount of time (in seconds) to wait for a location with the desired accuracy before completing.
                            If this value is 0.0, no timeout will be set (will wait indefinitely for success, unless request is force completed or canceled).
 @param block           The block to be executed when the request succeeds, fails, or times out. Three parameters are passed into the block:
                            - The current location (the most recent one acquired, regardless of accuracy level), or nil if no valid location was acquired
                            - The achieved accuracy for the current location (may be less than the desired accuracy if the request failed)
                            - The request status (if it succeeded, or if not, why it failed)
 
 @return The location request ID, which can be used to force early completion or cancel the request while it is in progress.
 */
- (INTULocationRequestID)requestLocationWithDesiredAccuracy:(INTULocationAccuracy)desiredAccuracy
                                                    timeout:(NSTimeInterval)timeout
                                                      block:(INTULocationRequestBlock)block
{
    return [self requestLocationWithDesiredAccuracy:desiredAccuracy
                                            timeout:timeout
                               delayUntilAuthorized:NO
                                              block:block];
}

/**
 Asynchronously requests the current location of the device using location services, optionally waiting until the user grants the app permission
 to access location services before starting the timeout countdown.
 
 @param desiredAccuracy      The accuracy level desired (refers to the accuracy and recency of the location).
 @param timeout              The maximum amount of time (in seconds) to wait for a location with the desired accuracy before completing. If
                             this value is 0.0, no timeout will be set (will wait indefinitely for success, unless request is force completed or canceled).
 @param delayUntilAuthorized A flag specifying whether the timeout should only take effect after the user responds to the system prompt requesting
                             permission for this app to access location services. If YES, the timeout countdown will not begin until after the
                             app receives location services permissions. If NO, the timeout countdown begins immediately when calling this method.
 @param block                The block to be executed when the request succeeds, fails, or times out. Three parameters are passed into the block:
                                 - The current location (the most recent one acquired, regardless of accuracy level), or nil if no valid location was acquired
                                 - The achieved accuracy for the current location (may be less than the desired accuracy if the request failed)
                                 - The request status (if it succeeded, or if not, why it failed)
 
 @return The location request ID, which can be used to force early completion or cancel the request while it is in progress.
 */
- (INTULocationRequestID)requestLocationWithDesiredAccuracy:(INTULocationAccuracy)desiredAccuracy
                                                    timeout:(NSTimeInterval)timeout
                                       delayUntilAuthorized:(BOOL)delayUntilAuthorized
                                                      block:(INTULocationRequestBlock)block
{
    if (desiredAccuracy == INTULocationAccuracyNone) {
        NSAssert(desiredAccuracy != INTULocationAccuracyNone, @"INTULocationAccuracyNone is not a valid desired accuracy.");
        desiredAccuracy = INTULocationAccuracyCity; // default to the lowest valid desired accuracy
    }
    
    INTULocationRequest *locationRequest = [[INTULocationRequest alloc] init];
    locationRequest.delegate = self;
    locationRequest.desiredAccuracy = desiredAccuracy;
    locationRequest.timeout = timeout;
    locationRequest.block = block;
    
    BOOL deferTimeout = delayUntilAuthorized && ([CLLocationManager authorizationStatus] == kCLAuthorizationStatusNotDetermined);
    if (!deferTimeout) {
        [locationRequest startTimeoutTimerIfNeeded];
    }
    
    [self addLocationRequest:locationRequest];
    
    return locationRequest.requestID;
}

/**
 Creates a subscription for location updates that will execute the block once per update indefinitely (until canceled), regardless of the accuracy of each location.
 If an error occurs, the block will execute with a status other than INTULocationStatusSuccess, and the subscription will be canceled automatically.
 
 @param block The block to execute every time an updated location is available.
              The status will be INTULocationStatusSuccess unless an error occurred; it will never be INTULocationStatusTimedOut.
 
 @return The location request ID, which can be used to cancel the subscription of location updates to this block.
 */
- (INTULocationRequestID)subscribeToLocationUpdatesWithBlock:(INTULocationRequestBlock)block
{
    INTULocationRequest *locationRequest = [[INTULocationRequest alloc] init];
    locationRequest.desiredAccuracy = INTULocationAccuracyNone; // This makes the location request a subscription
    locationRequest.block = block;
    
    [self addLocationRequest:locationRequest];
    
    return locationRequest.requestID;
}

/**
 Immediately forces completion of the location request with the given requestID (if it exists), and executes the original request block with the results.
 This is effectively a manual timeout, and will result in the request completing with status INTULocationStatusTimedOut.
 */
- (void)forceCompleteLocationRequest:(INTULocationRequestID)requestID
{
    INTULocationRequest *locationRequestToComplete = nil;
    for (INTULocationRequest *locationRequest in self.locationRequests) {
        if (locationRequest.requestID == requestID) {
            locationRequestToComplete = locationRequest;
            break;
        }
    }
    if (locationRequestToComplete) {
        if (locationRequestToComplete.isSubscription) {
            // Subscription requests can only be canceled
            [self cancelLocationRequest:requestID];
        } else {
            [locationRequestToComplete forceTimeout];
            [self completeLocationRequest:locationRequestToComplete];
        }
    }
}

/**
 Immediately cancels the location request with the given requestID (if it exists), without executing the original request block.
 */
- (void)cancelLocationRequest:(INTULocationRequestID)requestID
{
    INTULocationRequest *locationRequestToCancel = nil;
    for (INTULocationRequest *locationRequest in self.locationRequests) {
        if (locationRequest.requestID == requestID) {
            locationRequestToCancel = locationRequest;
            break;
        }
    }
    if (locationRequestToCancel) {
        [self.locationRequests removeObject:locationRequestToCancel];
        [locationRequestToCancel cancel];
        INTULMLog(@"Location Request canceled with ID: %ld", (long)locationRequestToCancel.requestID);
        [self stopUpdatingLocationIfPossible];
    }
}

#pragma mark Internal methods

/**
 Adds the given location request to the array of requests, and starts location updates if needed.
 */
- (void)addLocationRequest:(INTULocationRequest *)locationRequest
{
    INTULocationServicesState locationServicesState = [INTULocationManager locationServicesState];
    if (locationServicesState == INTULocationServicesStateDisabled ||
        locationServicesState == INTULocationServicesStateDenied ||
        locationServicesState == INTULocationServicesStateRestricted) {
        // No need to add this location request, because location services are turned off device-wide, or the user has denied this app permissions to use them
        [self completeLocationRequest:locationRequest];
        return;
    }
    
    [self startUpdatingLocationIfNeeded];
    [self.locationRequests addObject:locationRequest];
    INTULMLog(@"Location Request added with ID: %ld", (long)locationRequest.requestID);
}

/**
 Returns the most recent current location, or nil if the current location is unknown, invalid, or stale.
 */
- (CLLocation *)currentLocation
{    
    if (_currentLocation) {
        // Location isn't nil, so test to see if it is valid
        if (_currentLocation.coordinate.latitude == 0.0 && _currentLocation.coordinate.longitude == 0.0) {
            // The current location is invalid; discard it and return nil
            _currentLocation = nil;
        }
    }
    
    // Location is either nil or valid at this point, return it
    return _currentLocation;
}

/**
 Inform CLLocationManager to start sending us updates to our location.
 */
- (void)startUpdatingLocationIfNeeded
{
#if __IPHONE_OS_VERSION_MAX_ALLOWED > __IPHONE_7_1
    // As of iOS 8, apps must explicitly request location services permissions. INTULocationManager supports both levels, "Always" and "When In Use".
    // INTULocationManager determines which level of permissions to request based on which description key is present in your app's Info.plist
    // If you provide values for both description keys, the more permissive "Always" level is requested.
    if (floor(NSFoundationVersionNumber) > NSFoundationVersionNumber_iOS_7_1 && [CLLocationManager authorizationStatus] == kCLAuthorizationStatusNotDetermined) {
        BOOL hasAlwaysKey = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"NSLocationAlwaysUsageDescription"] != nil;
        BOOL hasWhenInUseKey = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"NSLocationWhenInUseUsageDescription"] != nil;
        if (hasAlwaysKey) {
            [self.locationManager requestAlwaysAuthorization];
        } else if (hasWhenInUseKey) {
            [self.locationManager requestWhenInUseAuthorization];
        } else {
            // At least one of the keys NSLocationAlwaysUsageDescription or NSLocationWhenInUseUsageDescription MUST be present in the Info.plist file to use location services on iOS 8+.
            NSAssert(hasAlwaysKey || hasWhenInUseKey, @"To use location services in iOS 8+, your Info.plist must provide a value for either NSLocationWhenInUseUsageDescription or NSLocationAlwaysUsageDescription.");
        }
    }
#endif /* __IPHONE_OS_VERSION_MAX_ALLOWED > __IPHONE_7_1 */
    
    // We only enable location updates while there are open location requests, so power usage isn't a concern.
    // As a result, we use the Best accuracy on CLLocationManager so that we can quickly get a fix on the location,
    // clear out the pending location requests, and then power down the location services.
    if ([self.locationRequests count] == 0) {
        self.locationManager.desiredAccuracy = kCLLocationAccuracyBest;
        [self.locationManager startUpdatingLocation];
        if (self.isUpdatingLocation == NO) {
            INTULMLog(@"Location services started.");
        }
        self.isUpdatingLocation = YES;
    }
}

/**
 Checks to see if there are any outstanding locationRequests, and if there are none, informs CLLocationManager to stop sending
 location updates. This is done as soon as location updates are no longer needed in order to conserve the device's battery.
 */
- (void)stopUpdatingLocationIfPossible
{
    if ([self.locationRequests count] == 0) {
        [self.locationManager stopUpdatingLocation];
        if (self.isUpdatingLocation) {
            INTULMLog(@"Location services stopped.");
        }
        self.isUpdatingLocation = NO;
    }
}

/**
 Iterates over the array of pending location requests to check and see if the most recent current location
 successfully satisfies any of their criteria.
 */
- (void)processLocationRequests
{
    CLLocation *mostRecentLocation = self.currentLocation;
    
    // Keep a separate array of location requests to complete to avoid modifying the locationRequests property while iterating over it
    NSMutableArray *locationRequestsToComplete = [NSMutableArray array];
    
    for (INTULocationRequest *locationRequest in self.locationRequests) {
        if (locationRequest.hasTimedOut) {
            // Request has timed out, complete it
            [locationRequestsToComplete addObject:locationRequest];
            continue;
        }
        
        if (mostRecentLocation != nil) {
            if (locationRequest.isSubscription) {
                // This is a subscription request, which lives indefinitely (unless manually canceled) and receives every location update we get
                [self processSubscriptionRequest:locationRequest];
                continue;
            } else {
                // This is a regular one-time location request
                NSTimeInterval currentLocationTimeSinceUpdate = fabs([mostRecentLocation.timestamp timeIntervalSinceNow]);
                CLLocationAccuracy currentLocationHorizontalAccuracy = mostRecentLocation.horizontalAccuracy;
                NSTimeInterval staleThreshold = [locationRequest updateTimeStaleThreshold];
                CLLocationAccuracy horizontalAccuracyThreshold = [locationRequest horizontalAccuracyThreshold];
                if (currentLocationTimeSinceUpdate <= staleThreshold &&
                    currentLocationHorizontalAccuracy <= horizontalAccuracyThreshold) {
                    // The request's desired accuracy has been reached, complete it
                    [locationRequestsToComplete addObject:locationRequest];
                    continue;
                }
            }
        }
    }
    
    for (INTULocationRequest *locationRequest in locationRequestsToComplete) {
        [self completeLocationRequest:locationRequest];
    }
}

/**
 Immediately completes all pending location requests.
 Used in cases such as when the location services authorization status changes to Denied or Restricted.
 */
- (void)completeAllLocationRequests
{
    // Iterate through a copy of the locationRequests array to avoid modifying the same array we are removing elements from
    NSArray *locationRequests = [self.locationRequests copy];
    for (INTULocationRequest *locationRequest in locationRequests) {
        [self completeLocationRequest:locationRequest];
    }
    INTULMLog(@"Finished completing all location requests.");
}

/**
 Completes the given location request by removing it from the array of locationRequests and executing its completion block.
 If this was the last pending location request, this method also turns off location updating.
 */
- (void)completeLocationRequest:(INTULocationRequest *)locationRequest
{
    if (locationRequest == nil) {
        return;
    }
    
    [locationRequest complete];
    [self.locationRequests removeObject:locationRequest];
    [self stopUpdatingLocationIfPossible];
    
    INTULocationStatus status = [self statusForLocationRequest:locationRequest];
    CLLocation *currentLocation = self.currentLocation;
    INTULocationAccuracy achievedAccuracy = [self achievedAccuracyForLocation:currentLocation];
    
    // INTULocationManager is not thread safe and should only be called from the main thread, so we should already be executing on the main thread now.
    // dispatch_async is used to ensure that the completion block for a request is not executed before the request ID is returned, for example in the
    // case where the user has denied permission to access location services and the request is immediately completed with the appropriate error.
    dispatch_async(dispatch_get_main_queue(), ^{
        if (locationRequest.block) {
            locationRequest.block(currentLocation, achievedAccuracy, status);
        }
    });
    
    INTULMLog(@"Location Request completed with ID: %ld, currentLocation: %@, achievedAccuracy: %lu, status: %lu", (long)locationRequest.requestID, currentLocation, (unsigned long) achievedAccuracy, (unsigned long)status);
}

/**
 Handles calling a subscription location request's block with the current location.
 */
- (void)processSubscriptionRequest:(INTULocationRequest *)locationRequest
{
    NSAssert(locationRequest.isSubscription, @"This method should only be called for subscription location requests.");
    
    INTULocationStatus status = [self statusForLocationRequest:locationRequest];
    CLLocation *currentLocation = self.currentLocation;
    INTULocationAccuracy achievedAccuracy = [self achievedAccuracyForLocation:currentLocation];
    
    // No need for dispatch_async when calling this block, since this method is only called from a CLLocationManager callback
    if (locationRequest.block) {
        locationRequest.block(currentLocation, achievedAccuracy, status);
    }
}

/**
 Returns the location manager status for the given location request.
 */
- (INTULocationStatus)statusForLocationRequest:(INTULocationRequest *)locationRequest
{
    INTULocationServicesState locationServicesState = [INTULocationManager locationServicesState];
    
    if (locationServicesState == INTULocationServicesStateDisabled) {
        return INTULocationStatusServicesDisabled;
    }
    else if (locationServicesState == INTULocationServicesStateNotDetermined) {
        return INTULocationStatusServicesNotDetermined;
    }
    else if (locationServicesState == INTULocationServicesStateDenied) {
        return INTULocationStatusServicesDenied;
    }
    else if (locationServicesState == INTULocationServicesStateRestricted) {
        return INTULocationStatusServicesRestricted;
    }
    else if (self.updateFailed) {
        return INTULocationStatusError;
    }
    else if (locationRequest.hasTimedOut) {
        return INTULocationStatusTimedOut;
    }
    
    return INTULocationStatusSuccess;
}

/**
 Returns the associated INTULocationAccuracy level that has been achieved for a given location,
 based on that location's horizontal accuracy and recency.
 */
- (INTULocationAccuracy)achievedAccuracyForLocation:(CLLocation *)location
{
    if (!location) {
        return INTULocationAccuracyNone;
    }
    
    NSTimeInterval timeSinceUpdate = fabs([location.timestamp timeIntervalSinceNow]);
    CLLocationAccuracy horizontalAccuracy = location.horizontalAccuracy;
    
    if (horizontalAccuracy <= kINTUHorizontalAccuracyThresholdRoom &&
        timeSinceUpdate <= kINTUUpdateTimeStaleThresholdRoom) {
        return INTULocationAccuracyRoom;
    }
    else if (horizontalAccuracy <= kINTUHorizontalAccuracyThresholdHouse &&
             timeSinceUpdate <= kINTUUpdateTimeStaleThresholdHouse) {
        return INTULocationAccuracyHouse;
    }
    else if (horizontalAccuracy <= kINTUHorizontalAccuracyThresholdBlock &&
             timeSinceUpdate <= kINTUUpdateTimeStaleThresholdBlock) {
        return INTULocationAccuracyBlock;
    }
    else if (horizontalAccuracy <= kINTUHorizontalAccuracyThresholdNeighborhood &&
             timeSinceUpdate <= kINTUUpdateTimeStaleThresholdNeighborhood) {
        return INTULocationAccuracyNeighborhood;
    }
    else if (horizontalAccuracy <= kINTUHorizontalAccuracyThresholdCity &&
             timeSinceUpdate <= kINTUUpdateTimeStaleThresholdCity) {
        return INTULocationAccuracyCity;
    }
    else {
        return INTULocationAccuracyNone;
    }
}

#pragma mark INTULocationRequestDelegate method

- (void)locationRequestDidTimeout:(INTULocationRequest *)locationRequest
{
    // For robustness, only complete the location request if it is still pending (by checking to see that it hasn't been removed from the locationRequests array).
    // Wait to complete it until after exiting the for loop, so we don't modify the array while iterating over it.
    BOOL isRequestStillPending = NO;
    for (INTULocationRequest *pendingLocationRequest in self.locationRequests) {
        if (pendingLocationRequest.requestID == locationRequest.requestID) {
            isRequestStillPending = YES;
            break;
        }
    }
    if (isRequestStillPending) {
        [self completeLocationRequest:locationRequest];
    }
}

#pragma mark CLLocationManagerDelegate methods

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations
{
    // Received update successfully, so clear any previous errors
    self.updateFailed = NO;
    
    CLLocation *mostRecentLocation = [locations lastObject];
    self.currentLocation = mostRecentLocation;
    
    // The updated location may have just satisfied one of the pending location requests, so process them now to check
    [self processLocationRequests];
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
    INTULMLog(@"Location update error: %@", [error localizedDescription]);
    self.updateFailed = YES;
    
    [self completeAllLocationRequests];
}

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status
{
    if (status == kCLAuthorizationStatusDenied || status == kCLAuthorizationStatusRestricted) {
        // Clear out any pending location requests (which will execute the blocks with a status that reflects
        // the unavailability of location services) since we now no longer have location services permissions
        [self completeAllLocationRequests];
    }
#if __IPHONE_OS_VERSION_MAX_ALLOWED > __IPHONE_7_1
    else if (status == kCLAuthorizationStatusAuthorizedAlways || status == kCLAuthorizationStatusAuthorizedWhenInUse) {
#else
    else if (status == kCLAuthorizationStatusAuthorized) {
#endif /* __IPHONE_OS_VERSION_MAX_ALLOWED > __IPHONE_7_1 */
        // Start the timeout timer for location requests that were waiting for authorization
        for (INTULocationRequest *locationRequest in self.locationRequests) {
            [locationRequest startTimeoutTimerIfNeeded];
        }
    }
}
    
#pragma mark Deprecated methods
    
/**
 DEPRECATED, will be removed in a future release. Please use +[INTULocationManager locationServicesState] instead.
 Returns YES if location services are enabled in the system settings, and the app has NOT been denied/restricted access. Returns NO otherwise.
 Note that this method will return YES even if the authorization status has not yet been determined.
 */
- (BOOL)locationServicesAvailable
{
    if ([CLLocationManager locationServicesEnabled] == NO) {
        return NO;
    }
    else if ([CLLocationManager authorizationStatus] == kCLAuthorizationStatusDenied) {
        return NO;
    }
    else if ([CLLocationManager authorizationStatus] == kCLAuthorizationStatusRestricted) {
        return NO;
    }
    
    return YES;
}

@end
