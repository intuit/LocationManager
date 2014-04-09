//
//  INTULocationManager.m
//
//  Copyright (c) 2014 Intuit Inc.
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
#import "INTULocationRequest.h"


#ifndef INTU_ENABLE_LOGGING
    #ifdef DEBUG
        #define INTU_ENABLE_LOGGING 1
    #else
        #define INTU_ENABLE_LOGGING 0
    #endif /* DEBUG */
#endif /* INTU_ENABLE_LOGGING */

#if INTU_ENABLE_LOGGING
    #define INTULMLog(...)          NSLog(@"INTULocationManager: %@", [NSString stringWithFormat:__VA_ARGS__]);
#else
    #define INTULMLog(...)
#endif /* INTU_ENABLE_LOGGING */


@interface INTULocationManager () <CLLocationManagerDelegate, INTULocationRequestDelegate>

// The instance of CLLocationManager encapsulated by this class.
@property (nonatomic, strong) CLLocationManager *locationManager;
// The most recent current location, or nil if the current location is unknown, invalid, or stale.
@property (nonatomic, strong) CLLocation *currentLocation;
// Whether or not the CLLocationManager is currently sending location updates.
@property (nonatomic, assign) BOOL isUpdatingLocation;
// Whether an error occurred during the last location update.
@property (nonatomic, assign) BOOL updateFailed;

// An array of pending location requests in the form:
// @[ INTULocationRequest *locationRequest1, INTULocationRequest *locationRequest2, ... ]
@property (nonatomic, strong) NSMutableArray *locationRequests;

@end


@implementation INTULocationManager

static id _sharedInstance;

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
 Returns YES if location services are enabled in the system settings, and the app has NOT been denied/restricted access. Returns NO otherwise.
 Note that this method will return YES even if the authorization status has not yet been determined.
 */
- (BOOL)locationServicesAvailable
{
	if ([CLLocationManager locationServicesEnabled] == NO) {
		return NO;
	} else if ([CLLocationManager authorizationStatus] == kCLAuthorizationStatusDenied) {
        return NO;
    } else if ([CLLocationManager authorizationStatus] == kCLAuthorizationStatusRestricted) {
        return NO;
    }
    return YES;
}

/**
 Asynchronously requests the current location of the device using location services.
 
 @param desiredAccuracy The desired accuracy for this request, which if achieved will trigger the successful completion.
 @param timeout The maximum number of seconds to wait while attempting to achieve the desired accuracy.
                If this value is 0.0, no timeout will be set (will wait indefinitely for success, unless request is force completed or cancelled).
 @param deferFirstRequestTimeout The flag specifying whether the timeout timer is started until the user decides to permit location services
 @param block The block to be executed when the request succeeds, fails, or times out. Three parameters are passed into the block:
                    - The current location (the most recent one acquired, regardless of accuracy level), or nil if no valid location was acquired
                    - The achieved accuracy for the current location (may be less than the desired accuracy if the request failed)
                    - The request status (if it succeeded, or if not, why it failed)
 
 @return An NSInteger representing the location request's unique ID, which can be used to force early completion or cancel the request while it is in progress.
 */
- (NSInteger)requestLocationWithDesiredAccuracy:(INTULocationAccuracy)desiredAccuracy timeout:(NSTimeInterval)timeout deferFirstRequestTimeout:(BOOL)deferFirstRequestTimeout block:(INTULocationRequestBlock)block
{
    NSAssert(desiredAccuracy != INTULocationAccuracyNone, @"INTULocationAccuracyNone is not a valid desired accuracy.");

    BOOL deferredTimeout = deferFirstRequestTimeout && ([CLLocationManager authorizationStatus] == kCLAuthorizationStatusNotDetermined);
    
    INTULocationRequest *locationRequest = [[INTULocationRequest alloc] init];
    locationRequest.delegate = self;
    locationRequest.desiredAccuracy = desiredAccuracy;
    locationRequest.timeout = timeout;
    locationRequest.deferredTimeout = deferredTimeout;
    locationRequest.block = block;
    
    if (!deferredTimeout) {
        [locationRequest startLocationRequestTimer];
    }
    
    [self addLocationRequest:locationRequest];
    
    return locationRequest.requestID;
}

/**
 Immediately forces completion of the location request with the given requestID (if it exists), and executes the original request block with the results.
 This is effectively a manual timeout, and will result in the request completing with status INTULocationStatusTimedOut.
 */
- (void)forceCompleteLocationRequest:(NSInteger)requestID
{
    INTULocationRequest *locationRequestToComplete = nil;
    for (INTULocationRequest *locationRequest in self.locationRequests) {
        if (locationRequest.requestID == requestID) {
            locationRequestToComplete = locationRequest;
            break;
        }
    }
    [locationRequestToComplete completeLocationRequest];
    [self completeLocationRequest:locationRequestToComplete];
}

/**
 Immediately cancels the location request with the given requestID (if it exists), without executing the original request block.
 */
- (void)cancelLocationRequest:(NSInteger)requestID
{
    INTULocationRequest *locationRequestToCancel = nil;
    for (INTULocationRequest *locationRequest in self.locationRequests) {
        if (locationRequest.requestID == requestID) {
            locationRequestToCancel = locationRequest;
            break;
        }
    }
    [self.locationRequests removeObject:locationRequestToCancel];
    [locationRequestToCancel cancelLocationRequest];
    INTULMLog(@"Location Request cancelled with ID: %ld", (long)locationRequestToCancel.requestID);
    [self stopUpdatingLocationIfPossible];
}

#pragma mark Internal methods

/**
 Adds the given location request to the array of requests, and starts location updates if needed.
 */
- (void)addLocationRequest:(INTULocationRequest *)locationRequest
{
    if ([self locationServicesAvailable] == NO) {
        // Don't even bother trying to do anything since location services are off or the user has
        // explcitly denied us permission to use them
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
 Iterates over the array of pending location requests and shedule deferred timers
 */
- (void)startLocationRequestsDeferredTimers {
    for (INTULocationRequest *locationRequest in self.locationRequests) {
        if (locationRequest.deferredTimeout) {
            [locationRequest startLocationRequestTimer];
        }
    }
}

/**
 Iterates over the array of pending location requests to check and see if the most recent current location
 successfully satisfies any of their criteria.
 */
- (void)processLocationRequests
{
    CLLocation *mostRecentLocation = self.currentLocation;
    
    // Keep a separate array of location requests to complete to avoid modifying the locationRequests property
    // while iterating over it at the same time
    NSMutableArray *locationRequestsToComplete = [NSMutableArray array];
    
    for (INTULocationRequest *locationRequest in self.locationRequests) {
        if (locationRequest.hasTimedOut) {
            // Request has timed out, complete it
            [locationRequestsToComplete addObject:locationRequest];
            continue;
        }
        
        if (mostRecentLocation != nil) {
            NSTimeInterval currentLocationTimeSinceUpdate = fabs([mostRecentLocation.timestamp timeIntervalSinceNow]);
            CLLocationAccuracy currentLocationHorizontalAccuracy = mostRecentLocation.horizontalAccuracy;
            NSTimeInterval staleThreshold = [locationRequest updateTimeStaleThreshold];
            CLLocationAccuracy horizontalAccuracyThreshold =  [locationRequest horizontalAccuracyThreshold];
            if (currentLocationTimeSinceUpdate <= staleThreshold &&
                currentLocationHorizontalAccuracy <= horizontalAccuracyThreshold) {
                // The request's desired accuracy has been reached, complete it
                [locationRequestsToComplete addObject:locationRequest];
                continue;
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
    
    INTULocationStatus status = [self statusForLocationRequest:locationRequest];
    CLLocation *currentLocation = self.currentLocation;
    INTULocationAccuracy achievedAccuracy = [self achievedAccuracyForLocation:currentLocation];
    
    [self.locationRequests removeObject:locationRequest];
    [locationRequest completeLocationRequest];
    [self stopUpdatingLocationIfPossible];
    
    if (locationRequest.block) {
        locationRequest.block(currentLocation, achievedAccuracy, status);
    }
    INTULMLog(@"Location Request completed with ID: %ld, currentLocation: %@, achievedAccuracy: %lu, status: %lu", (long)locationRequest.requestID, currentLocation, (unsigned long) achievedAccuracy, (unsigned long)status);
}

/**
 Returns the location manager status for the given location request.
 */
- (INTULocationStatus)statusForLocationRequest:(INTULocationRequest *)locationRequest
{
    if ([CLLocationManager authorizationStatus] == kCLAuthorizationStatusNotDetermined) {
        return INTULocationStatusServicesNotDetermined;
    }
    else if ([CLLocationManager authorizationStatus] == kCLAuthorizationStatusDenied) {
        return INTULocationStatusServicesDenied;
    }
    else if ([CLLocationManager authorizationStatus] == kCLAuthorizationStatusRestricted) {
        return INTULocationStatusServicesRestricted;
    }
    else if ([CLLocationManager locationServicesEnabled] == NO) {
        return INTULocationStatusServicesDisabled;
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
    // Start deferred location requests timers
    [self startLocationRequestsDeferredTimers];
    
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
}

@end
