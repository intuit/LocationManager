//
//  INTULocationRequest.h
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

@class CLLocation;
@class INTULocationRequest;

/**
 Protocol for the INTULocationRequest to notify the its delegate that a request has timed out.
 */
@protocol INTULocationRequestDelegate

/**
 Notification that a location request has timed out.
 
 @param locationRequest The location request that timed out.
 */
- (void)locationRequestDidTimeout:(INTULocationRequest *)locationRequest;

@end


/**
 Represents a geolocation request that is created and managed by INTULocationManager.
 */
@interface INTULocationRequest : NSObject

// The delegate for this location request.
@property (nonatomic, weak) id<INTULocationRequestDelegate> delegate;
// The request ID for this location request (set during initialization).
@property (nonatomic, readonly) NSInteger requestID;
// The desired accuracy for this location request.
@property (nonatomic, assign) INTULocationAccuracy desiredAccuracy;
// The maximum amount of time the location request should be allowed to live before completing.
@property (nonatomic, assign) NSTimeInterval timeout;
// The flag specifying whether the timeout timer is deferred by INTULocationManager
@property (nonatomic, assign) BOOL deferredTimeout;
// How long the location request has been alive since the timeout value was last set.
@property (nonatomic, readonly) NSTimeInterval timeAlive;
// Whether this location request has timed out (will also be YES if it has been completed).
@property (nonatomic, readonly) BOOL hasTimedOut;
// The block to execute when the location request completes.
@property (nonatomic, copy) INTULocationRequestBlock block;

/** Completes the location request. */
- (void)completeLocationRequest;

/** Cancels the location request. */
- (void)cancelLocationRequest;

/** Start location request timer */
- (void)startLocationRequestTimer;

/** Returns the associated recency threshold (in seconds) for the location request's desired accuracy level. */
- (NSTimeInterval)updateTimeStaleThreshold;

/** Returns the associated horizontal accuracy threshold (in meters) for the location request's desired accuracy level. */
- (CLLocationAccuracy)horizontalAccuracyThreshold;

@end
