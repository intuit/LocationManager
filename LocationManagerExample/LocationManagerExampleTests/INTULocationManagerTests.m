//
//  INTULocationRequestTests.m
//  LocationManagerExampleTests
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

#import <Specta/Specta.h>
#import <Expecta/Expecta.h>
#import <FBSnapshotTestCase/FBSnapshotTestCase.h>
#import <Expecta+Snapshots/EXPMatchers+FBSnapshotTest.h>
#import <OCMock/OCMock.h>

#import "INTULocationManager.h"

@interface INTULocationManager (Spec) <CLLocationManagerDelegate>
@property (nonatomic, strong) CLLocationManager *locationManager;
@end

SpecBegin(LocationManager)

__block INTULocationManager *subject;
__block CLLocation *location;

before(^{
    subject = [[INTULocationManager alloc] init];
    subject.locationManager = OCMClassMock(CLLocationManager.class);

    location = [[CLLocation alloc] initWithCoordinate:CLLocationCoordinate2DMake(1, 1)
                                                         altitude:CLLocationDistanceMax
                                               horizontalAccuracy:kCLLocationAccuracyBest
                                                 verticalAccuracy:kCLLocationAccuracyBest
                                                        timestamp:[NSDate date]];
});


describe(@"location services state", ^{
    it(@"should indicate if location services are disabled", ^{
        id classMock = OCMClassMock(CLLocationManager.class);
        OCMStub(ClassMethod([classMock locationServicesEnabled])).andReturn(NO);

        expect([INTULocationManager locationServicesState]).to.equal(INTULocationServicesStateDisabled);

        [classMock stopMocking];
    });

    it(@"should use the appropriate state based on authorization status", ^{
        id classMock = OCMClassMock(CLLocationManager.class);
        OCMStub(ClassMethod([classMock locationServicesEnabled])).andReturn(YES);
        OCMStub(ClassMethod([classMock authorizationStatus])).andReturn(kCLAuthorizationStatusNotDetermined);

        expect([INTULocationManager locationServicesState]).to.equal(INTULocationServicesStateNotDetermined);

        [classMock stopMocking];
    });
});

describe(@"forcing a request to complete", ^{
    it(@"should immediately call the request's completion block", ^{
        __block BOOL called = NO;
        INTULocationRequestID requestID = [subject requestLocationWithDesiredAccuracy:INTULocationAccuracyCity timeout:10 block:^(CLLocation *currentLocation, INTULocationAccuracy achievedAccuracy, INTULocationStatus status) {
            called = YES;
        }];
        [subject forceCompleteLocationRequest:requestID];
        expect(called).will.beTruthy();
    });

});

describe(@"After requesting a location", ^{
    it(@"can be cancelled", ^{
        INTULocationRequestID requestID = [subject requestLocationWithDesiredAccuracy:INTULocationAccuracyRoom timeout:10 block:^(CLLocation *currentLocation, INTULocationAccuracy achievedAccuracy, INTULocationStatus status) {
            failure(@"was not cancelled");
        }];

        [subject cancelLocationRequest:requestID];

        [subject locationManager:subject.locationManager didUpdateLocations:@[location]];
    });
});

describe(@"Timeouts", ^{
    it(@"calls the request callback on location update after a timeout", ^{
        __block NSInteger callbackCount = 0;
        [subject requestLocationWithDesiredAccuracy:INTULocationAccuracyRoom timeout:0.1 block:^(CLLocation *currentLocation, INTULocationAccuracy achievedAccuracy, INTULocationStatus status) {
            callbackCount++;
        }];

        [subject locationManager:subject.locationManager didUpdateLocations:@[location]];
        expect(callbackCount).will.equal(1);
    });

    it(@"does not call the request callback on subsequent updates after timeout", ^{
        __block NSInteger callbackCount = 0;
        [subject requestLocationWithDesiredAccuracy:INTULocationAccuracyRoom timeout:0.1 block:^(CLLocation *currentLocation, INTULocationAccuracy achievedAccuracy, INTULocationStatus status) {
            callbackCount++;
        }];

        [subject locationManager:subject.locationManager didUpdateLocations:@[location]];
        [subject locationManager:subject.locationManager didUpdateLocations:@[location]];

        expect(callbackCount).will.equal(1);
    });

});

describe(@"subscribing with a block", ^{
    it(@"calls the block on location update", ^{
        __block BOOL called = NO;
        [subject subscribeToLocationUpdatesWithBlock:^(CLLocation *currentLocation, INTULocationAccuracy achievedAccuracy, INTULocationStatus status) {
            called = YES;
        }];

        [subject locationManager:subject.locationManager didUpdateLocations:@[location]];

        expect(called).to.beTruthy();
    });

    it(@"passes the location", ^{
        waitUntil(^(DoneCallback done) {
            [subject subscribeToLocationUpdatesWithBlock:^(CLLocation *currentLocation, INTULocationAccuracy achievedAccuracy, INTULocationStatus status) {
                expect(currentLocation).to.equal(location);
                done();
            }];
            [subject locationManager:subject.locationManager didUpdateLocations:@[location]];
        });

    });
});

SpecEnd
