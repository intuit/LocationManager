//
//  INTULocationRequest.m
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

#import "INTULocationRequest.h"


@interface INTULocationRequest ()

// Redeclare this property as readwrite for internal use.
@property (nonatomic, assign, readwrite) BOOL hasTimedOut;

// The NSDate representing the time when the request started. Set when the |timeout| property is set.
@property (nonatomic, strong) NSDate *requestStartTime;
// The timer that will fire to notify this request that it has timed out. Started when the |timeout| property is set.
@property (nonatomic, strong) NSTimer *timeoutTimer;

@end


@implementation INTULocationRequest

static NSInteger _nextRequestID = 0;

/**
 Returns a unique request ID (within the lifetime of the application).
 */
+ (NSInteger)getUniqueRequestID
{
    _nextRequestID++;
    return _nextRequestID;
}

/**
 Calls the designated initializer with an autogenerated unique requestID.
 */
- (id)init
{
    return [self initWithRequestID:[INTULocationRequest getUniqueRequestID]];
}

/**
 Designated initializer.
 Use regular init method to autogenerate a unique requestID.
 */
- (id)initWithRequestID:(NSInteger)requestID
{
    self = [super init];
    if (self) {
        _requestID = requestID;
        _hasTimedOut = NO;
    }
    return self;
}

/**
 Returns the associated recency threshold (in seconds) for the location request's desired accuracy level.
 */
- (NSTimeInterval)updateTimeStaleThreshold
{
    switch (self.desiredAccuracy) {
        case INTULocationAccuracyRoom:
            return kINTUUpdateTimeStaleThresholdRoom;
            break;
        case INTULocationAccuracyHouse:
            return kINTUUpdateTimeStaleThresholdHouse;
            break;
        case INTULocationAccuracyBlock:
            return kINTUUpdateTimeStaleThresholdBlock;
            break;
        case INTULocationAccuracyNeighborhood:
            return kINTUUpdateTimeStaleThresholdNeighborhood;
            break;
        case INTULocationAccuracyCity:
            return kINTUUpdateTimeStaleThresholdCity;
            break;
        default:
            NSAssert(NO, @"Unknown desired accuracy.");
            return 0.0;
            break;
    }
}

/**
 Returns the associated horizontal accuracy threshold (in meters) for the location request's desired accuracy level.
 */
- (CLLocationAccuracy)horizontalAccuracyThreshold
{
    switch (self.desiredAccuracy) {
        case INTULocationAccuracyRoom:
            return kINTUHorizontalAccuracyThresholdRoom;
            break;
        case INTULocationAccuracyHouse:
            return kINTUHorizontalAccuracyThresholdHouse;
            break;
        case INTULocationAccuracyBlock:
            return kINTUHorizontalAccuracyThresholdBlock;
            break;
        case INTULocationAccuracyNeighborhood:
            return kINTUHorizontalAccuracyThresholdNeighborhood;
            break;
        case INTULocationAccuracyCity:
            return kINTUHorizontalAccuracyThresholdCity;
            break;
        default:
            NSAssert(NO, @"Unknown desired accuracy.");
            return 0.0;
            break;
    }
}

/**
 Completes the location request.
 */
- (void)completeLocationRequest
{
    self.hasTimedOut = YES;
    [self.timeoutTimer invalidate];
    self.requestStartTime = nil;
}

/**
 Cancels the location request.
 */
- (void)cancelLocationRequest
{
    [self.timeoutTimer invalidate];
    self.requestStartTime = nil;
}

/**
 Sets the timeout value for this request, also triggering a timer to start which will fire at the timeout time.
 If the given timeout value is exactly 0.0, it will be ignored (the request will never timeout by itself).
 */
- (void)setTimeout:(NSTimeInterval)timeout
{
    self.requestStartTime = [NSDate date];
    _timeout = timeout;
    [self.timeoutTimer invalidate];
    if (timeout > 0.0) {
        self.timeoutTimer = [NSTimer scheduledTimerWithTimeInterval:timeout target:self selector:@selector(timeoutTimerFired:) userInfo:nil repeats:NO];
    }
}

/**
 Dynamic property that returns how long the request has been alive (since the timeout value was set).
 */
- (NSTimeInterval)timeAlive
{
    if (self.requestStartTime == nil) {
        return 0.0;
    }
    return fabs([self.requestStartTime timeIntervalSinceNow]);
}

/**
 Returns whether the location request has timed out or not.
 Once this becomes YES, it will not automatically reset to NO even if a new timeout value is set.
 */
- (BOOL)hasTimedOut
{
    if (self.timeout > 0.0 && self.timeAlive > self.timeout) {
        _hasTimedOut = YES;
    }
    return _hasTimedOut;
}

/**
 Callback when the timeout timer fires. Notifies the delegate that this event has occurred.
 */
- (void)timeoutTimerFired:(NSTimer *)timer
{
    self.hasTimedOut = YES;
    [self.delegate locationRequestDidTimeout:self];
}

/**
 Two location requests are considered equal if their request IDs match.
 */
- (BOOL)isEqual:(id)object
{
    if (object == self) {
        return YES;
    }
    if (!object || ![object isKindOfClass:[self class]]) {
        return NO;
    }
    if (((INTULocationRequest *)object).requestID == self.requestID) {
        return YES;
    }
    return NO;
}

/**
 Return a hash based on the string representation of the request ID.
 */
- (NSUInteger)hash
{
    return [[NSString stringWithFormat:@"%ld", (long) self.requestID] hash];
}

- (void)dealloc
{
    [_timeoutTimer invalidate];
}

@end