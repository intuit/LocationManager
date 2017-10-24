//
//  INTURequestIDGeneratorTests.m
//  LocationManagerTests
//
//  Copyright (c) 2014-2017 Intuit Inc.
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

#import "INTUHeadingRequest.h"
#import "INTULocationRequest.h"

SpecBegin(RequestIDGenerator)

describe(@"RequestIDGenerator", ^{
    __block INTUHeadingRequest *headingRequest;
    __block INTULocationRequest *locationRequest;
    
    before(^{
        headingRequest = [[INTUHeadingRequest alloc] init];
        locationRequest = [[INTULocationRequest alloc] initWithType:INTULocationRequestTypeSingle];
    });
    
    it(@"generates a unique request id for each request regardless of type (no dupes)", ^{
        expect(headingRequest.requestID).notTo.equal(locationRequest.requestID);
    });

    describe(@"heading request is a subscription", ^{
        it(@"should be recurring", ^{
            expect(headingRequest.isRecurring).to.beTruthy();
        });
    });
    
    describe(@"location request is a subscription", ^{
        context(@"when the type is INTULocationRequestTypeSingle", ^{
            it(@"should not be recurring", ^{
                expect(locationRequest.isRecurring).to.beFalsy();
            });
        });
    });
});

SpecEnd 
