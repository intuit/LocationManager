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
#import <OCMock/OCMock.h>

#import "INTULocationRequest.h"

SpecBegin(LocationRequest)

describe(@"INTULocationRequest", ^{
    __block INTULocationRequest *request;

    before(^{
        request = [[INTULocationRequest alloc] init];
    });

    it(@"generates a unique request id for each request", ^{
        INTULocationRequest *request1 = [[INTULocationRequest alloc] init];
        INTULocationRequest *request2 = [[INTULocationRequest alloc] init];
        expect(request1.requestID).notTo.equal(request2.requestID);
    });

    describe(@"setting accuracy", ^{
        it(@"should return the appropriate horizontal accuracy", ^{
            request.desiredAccuracy = INTULocationAccuracyCity;
            expect(request.horizontalAccuracyThreshold).to.equal(kINTUHorizontalAccuracyThresholdCity);
            request.desiredAccuracy = INTULocationAccuracyNeighborhood;
            expect(request.horizontalAccuracyThreshold).to.equal(kINTUHorizontalAccuracyThresholdNeighborhood);
            request.desiredAccuracy = INTULocationAccuracyBlock;
            expect(request.horizontalAccuracyThreshold).to.equal(kINTUHorizontalAccuracyThresholdBlock);
            request.desiredAccuracy = INTULocationAccuracyHouse;
            expect(request.horizontalAccuracyThreshold).to.equal(kINTUHorizontalAccuracyThresholdHouse);
            request.desiredAccuracy = INTULocationAccuracyRoom;
            expect(request.horizontalAccuracyThreshold).to.equal(kINTUHorizontalAccuracyThresholdRoom);
        });

        it(@"should return the appropriate recency threshold", ^{
            request.desiredAccuracy = INTULocationAccuracyCity;
            expect(request.updateTimeStaleThreshold).to.equal(kINTUUpdateTimeStaleThresholdCity);
            request.desiredAccuracy = INTULocationAccuracyNeighborhood;
            expect(request.updateTimeStaleThreshold).to.equal(kINTUUpdateTimeStaleThresholdNeighborhood);
            request.desiredAccuracy = INTULocationAccuracyBlock;
            expect(request.updateTimeStaleThreshold).to.equal(kINTUUpdateTimeStaleThresholdBlock);
            request.desiredAccuracy = INTULocationAccuracyHouse;
            expect(request.updateTimeStaleThreshold).to.equal(kINTUUpdateTimeStaleThresholdHouse);
            request.desiredAccuracy = INTULocationAccuracyRoom;
            expect(request.updateTimeStaleThreshold).to.equal(kINTUUpdateTimeStaleThresholdRoom);
        });

        context(@"when the desired accuracy is none", ^{
            it(@"should be a subscription", ^{
                request.desiredAccuracy = INTULocationAccuracyNone;
                expect(request.isSubscription).to.beTruthy();
            });
        });

        context(@"when the desired accuracy is not none", ^{
            it(@"should not be a subscription", ^{
                request.desiredAccuracy = INTULocationAccuracyRoom;
                expect(request.isSubscription).to.beFalsy();
            });
        });

    });

    describe(@"timing out a request", ^{
        context(@"when the desired accuracy is not none", ^{
            before(^{
                request.desiredAccuracy = INTULocationAccuracyRoom;
            });

            it(@"ignores a timeout if its 0", ^{
                request.timeout = 0;
                [request startTimeoutTimerIfNeeded];
                expect(request.timeAlive).to.equal(0);
            });

            it(@"can force a timeout", ^{
                request.timeout = 10;
                [request startTimeoutTimerIfNeeded];
                expect(request.hasTimedOut).to.beFalsy();

                [request forceTimeout];

                expect(request.hasTimedOut).to.beTruthy();
            });

            describe(@"timed out", ^{
                it(@"say its timed out", ^{
                    request.timeout = 0.001;
                    [request startTimeoutTimerIfNeeded];
                    expect(request.hasTimedOut).will.beTruthy();
                });

                it(@"notifies the delegate it has timed out", ^{
                    id protocolMock = OCMProtocolMock(@protocol(INTULocationRequestDelegate));
                    request.delegate = protocolMock;

                    OCMExpect([protocolMock locationRequestDidTimeout:[OCMArg any]]);

                    request.timeout = 0.001;
                    [request startTimeoutTimerIfNeeded];

                    // This will block the timeout
                    expect(request.hasTimedOut).will.beTruthy();
                    OCMVerifyAll(protocolMock);
                });

                it(@"does not say timed out before the specified timeout", ^{
                    request.timeout = 10.001;
                    [request startTimeoutTimerIfNeeded];
                    expect(request.hasTimedOut).to.beFalsy();
                    
                    // cleanup
                    [request forceTimeout];
                });
            });
        });
    });
    
    describe(@"cancelling a request", ^{
        it(@"should have a zero time alive", ^{
            request.timeout = 10;
            [request startTimeoutTimerIfNeeded];

            expect(request.timeAlive).to.beGreaterThan(0);
            [request cancel];
            expect(request.timeAlive).to.equal(0);
        });
    });

    describe(@"completing a request", ^{
        it(@"should have a zero alive time", ^{
            request.timeout = 10;
            [request startTimeoutTimerIfNeeded];

            expect(request.timeAlive).to.beGreaterThan(0);
            [request complete];
            expect(request.timeAlive).to.equal(0);
        });
    });
});


SpecEnd