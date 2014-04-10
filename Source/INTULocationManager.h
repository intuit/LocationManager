//
//  INTULocationManager.h
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

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import "INTULocationRequestDefines.h"

/**
 An abstraction around CLLocationManager that provides a block-based asynchronous API for obtaining the device's location.
 
 This class will automatically start and stop location services as needed to conserve battery. As a result, this class should
 not be used in combination with any other code that directly uses the -[CLLocationManager startUpdatingLocation] or
 -[CLLocationManager stopUpdatingLocation] methods.
 */
@interface INTULocationManager : NSObject

/** Returns YES if location services are enabled in the system settings, and the app has NOT been denied/restricted access. Returns NO otherwise. */
@property (nonatomic, readonly) BOOL locationServicesAvailable;

/** Returns the singleton instance of this class. */
+ (instancetype)sharedInstance;

/**
 Asynchronously requests the current location of the device using location services.
 
 @param desiredAccuracy The accuracy level desired (refers to the accuracy and recency of the location).
 @param timeout The maximum amount of time (in seconds) to wait for the desired accuracy before completing.
                If this value is 0.0, no timeout will be set (will wait indefinitely for success, unless request is force completed or cancelled).
 @param block The block to execute upon success, failure, or timeout.
 
 @return The location request ID, which can be used to force early completion or cancel the request while it is in progress.
 */
- (NSInteger)requestLocationWithDesiredAccuracy:(INTULocationAccuracy)desiredAccuracy
                                        timeout:(NSTimeInterval)timeout
                                          block:(INTULocationRequestBlock)block;

/**
 Asynchronously requests the current location of the device using location services, optionally delaying the timeout countdown until the user has
 responded to the dialog requesting permission for this app to access location services.
 
 @param desiredAccuracy The accuracy level desired (refers to the accuracy and recency of the location).
 @param timeout The maximum amount of time (in seconds) to wait for the desired accuracy before completing.
                If this value is 0.0, no timeout will be set (will wait indefinitely for success, unless request is force completed or cancelled).
 @param delayUntilAuthorized A flag specifying whether the timeout should only take effect after the user responds to the system prompt requesting
                             permission for this app to access location services. If YES, the timeout countdown will not begin until after the
                             app receives location services permissions. If NO, the timeout countdown begins immediately when calling this method. 
 @param block The block to execute upon success, failure, or timeout.
 
 @return The location request ID, which can be used to force early completion or cancel the request while it is in progress.
 */
- (NSInteger)requestLocationWithDesiredAccuracy:(INTULocationAccuracy)desiredAccuracy
                                        timeout:(NSTimeInterval)timeout
                           delayUntilAuthorized:(BOOL)delayUntilAuthorized
                                          block:(INTULocationRequestBlock)block;

/** Immediately forces completion of the location request with the given requestID (if it exists), and executes the original request block with the results.
    This is effectively a manual timeout, and will result in the request completing with status INTULocationStatusTimedOut. */
- (void)forceCompleteLocationRequest:(NSInteger)requestID;

/** Immediately cancels the location request with the given requestID (if it exists), without executing the original request block. */
- (void)cancelLocationRequest:(NSInteger)requestID;

@end
