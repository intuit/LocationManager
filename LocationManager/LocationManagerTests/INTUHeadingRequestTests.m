//
//  INTUHaedingRequestTests.m
//  LocationManagerTests
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

#import "INTUHeadingRequest.h"

SpecBegin(HeadingRequest)

describe(@"INTUHeadingRequest", ^{
    __block INTUHeadingRequest *request;

    before(^{
        request = [[INTUHeadingRequest alloc] init];
    });

    it(@"generates a unique request id for each request", ^{
        INTUHeadingRequest *request1 = [[INTUHeadingRequest alloc] init];
        INTUHeadingRequest *request2 = [[INTUHeadingRequest alloc] init];
        expect(request1.requestID).notTo.equal(request2.requestID);
    });
    
    describe(@"is a subscription", ^{
        it(@"should be recurring", ^{
            expect(request.isRecurring).to.beTruthy();
        });
    });

});


SpecEnd