//
//  INTULocationRequestDefines.h
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

#ifndef INTU_LOCATION_REQUEST_DEFINES_H
#define INTU_LOCATION_REQUEST_DEFINES_H

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

static const CGFloat kINTUHorizontalAccuracyThresholdCity =         5000.0;  // in meters
static const CGFloat kINTUHorizontalAccuracyThresholdNeighborhood = 1000.0;  // in meters
static const CGFloat kINTUHorizontalAccuracyThresholdBlock =         100.0;  // in meters
static const CGFloat kINTUHorizontalAccuracyThresholdHouse =          15.0;  // in meters
static const CGFloat kINTUHorizontalAccuracyThresholdRoom =            5.0;  // in meters

static const CGFloat kINTUUpdateTimeStaleThresholdCity =             600.0;  // in seconds
static const CGFloat kINTUUpdateTimeStaleThresholdNeighborhood =     300.0;  // in seconds
static const CGFloat kINTUUpdateTimeStaleThresholdBlock =             60.0;  // in seconds
static const CGFloat kINTUUpdateTimeStaleThresholdHouse =             15.0;  // in seconds
static const CGFloat kINTUUpdateTimeStaleThresholdRoom =               5.0;  // in seconds

/** A unique ID that corresponds to one location request. */
typedef NSInteger INTULocationRequestID;

/** An abstraction of both the horizontal accuracy and recency of location data.
    Room is the highest level of accuracy/recency; City is the lowest level. */
typedef NS_ENUM(NSInteger, INTULocationAccuracy) {
    // 'None' is not valid as a desired accuracy.
    /** Inaccurate (>5000 meters, and/or received >10 minutes ago). */
    INTULocationAccuracyNone = 0,
    
    // The below options are valid desired accuracies.
    /** 5000 meters or better, and received within the last 10 minutes. Lowest accuracy. */
    INTULocationAccuracyCity,
    /** 1000 meters or better, and received within the last 5 minutes. */
    INTULocationAccuracyNeighborhood,
    /** 100 meters or better, and received within the last 1 minute. */
    INTULocationAccuracyBlock,
    /** 15 meters or better, and received within the last 15 seconds. */
    INTULocationAccuracyHouse,
    /** 5 meters or better, and received within the last 5 seconds. Highest accuracy. */
    INTULocationAccuracyRoom,
};

/** Statuses that can be passed to the completion block of a location request. */
typedef NS_ENUM(NSInteger, INTULocationStatus) {
    // These statuses will accompany a valid location.
    /** Got a location and desired accuracy level was achieved successfully. */
    INTULocationStatusSuccess = 0,
    /** Got a location, but the desired accuracy level was not reached before timeout. (Not applicable to subscriptions.) */
    INTULocationStatusTimedOut,
    
    // These statuses indicate some sort of error, and will accompany a nil location.
    /** User has not responded to the permissions dialog. */
    INTULocationStatusServicesNotDetermined,
    /** User has explicitly denied this app permission to access location services. */
    INTULocationStatusServicesDenied,
    /** User does not have ability to enable location services (e.g. parental controls, corporate policy, etc). */
    INTULocationStatusServicesRestricted,
    /** User has turned off device-wide location services from system settings. */
    INTULocationStatusServicesDisabled,
    /** An error occurred while using the system location services. */
    INTULocationStatusError
};

/**
 A block type for a location request, which is executed when the request succeeds, fails, or times out.
 
 @param currentLocation The most recent & accurate current location available when the block executes, or nil if no valid location is available.
 @param achievedAccuracy The accuracy level that was actually achieved (may be better than, equal to, or worse than the desired accuracy).
 @param status The status of the location request - whether it succeeded, timed out, or failed due to some sort of error. This can be used to
               understand what the outcome of the request was, decide if/how to use the associated currentLocation, and determine whether other
               actions are required (such as displaying an error message to the user, retrying with another request, quietly proceeding, etc).
 */
typedef void(^INTULocationRequestBlock)(CLLocation *currentLocation, INTULocationAccuracy achievedAccuracy, INTULocationStatus status);

#endif /* INTU_LOCATION_REQUEST_DEFINES_H */
