//
//  INTUViewController.m
//  LocationManagerExample
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

#import "INTUViewController.h"
#import <INTULocationManager/INTULocationManager.h>

@interface INTUViewController ()

@property (weak, nonatomic) IBOutlet UILabel *statusLabel;
@property (weak, nonatomic) IBOutlet UISwitch *subscriptionForAllChangesSwitch;
@property (weak, nonatomic) IBOutlet UISwitch *subscriptionForSignificantChangesSwitch;
@property (weak, nonatomic) IBOutlet UISwitch *subscriptionForAllHeadingChangesSwitch;
@property (weak, nonatomic) IBOutlet UILabel *timeoutLabel;
@property (weak, nonatomic) IBOutlet UILabel *desiredAccuracyLabel;
@property (weak, nonatomic) IBOutlet UISegmentedControl *desiredAccuracyControl;
@property (weak, nonatomic) IBOutlet UISlider *timeoutSlider;
@property (weak, nonatomic) IBOutlet UIButton *requestCurrentLocationButton;
@property (weak, nonatomic) IBOutlet UIButton *cancelRequestButton;
@property (weak, nonatomic) IBOutlet UIButton *forceCompleteRequestButton;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *activityIndicator;

@property (assign, nonatomic) INTULocationAccuracy desiredAccuracy;
@property (assign, nonatomic) NSTimeInterval timeout;

@property (assign, nonatomic) INTULocationRequestID locationRequestID;
@property (assign, nonatomic) INTUHeadingRequestID headingRequestID;

@end

@implementation INTUViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	
    self.subscriptionForAllChangesSwitch.on = NO;
    self.subscriptionForSignificantChangesSwitch.on = NO;
    self.subscriptionForAllHeadingChangesSwitch.on = NO;
    self.desiredAccuracyControl.selectedSegmentIndex = 0;
    self.desiredAccuracy = INTULocationAccuracyCity;
    self.timeoutSlider.value = 10.0;
    self.timeout = 10.0;
    
    self.locationRequestID = NSNotFound;
    self.headingRequestID = NSNotFound;
    self.statusLabel.text = @"Tap the button below to start a new location or heading request.";
}

#pragma mark - Locations

- (NSString *)getLocationErrorDescription:(INTULocationStatus)status
{
    if (status == INTULocationStatusServicesNotDetermined) {
        return @"Error: User has not responded to the permissions alert.";
    }
    if (status == INTULocationStatusServicesDenied) {
        return @"Error: User has denied this app permissions to access device location.";
    }
    if (status == INTULocationStatusServicesRestricted) {
        return @"Error: User is restricted from using location services by a usage policy.";
    }
    if (status == INTULocationStatusServicesDisabled) {
        return @"Error: Location services are turned off for all apps on this device.";
    }
    return @"An unknown error occurred.\n(Are you using iOS Simulator with location set to 'None'?)";
}

/**
 Starts a new subscription for location updates.
 */
- (void)startLocationUpdateSubscription
{
    __weak __typeof(self) weakSelf = self;
    INTULocationManager *locMgr = [INTULocationManager sharedInstance];
    self.locationRequestID = [locMgr subscribeToLocationUpdatesWithBlock:^(CLLocation *currentLocation, INTULocationAccuracy achievedAccuracy, INTULocationStatus status) {
        __typeof(weakSelf) strongSelf = weakSelf;
        
        if (status == INTULocationStatusSuccess) {
            // A new updated location is available in currentLocation, and achievedAccuracy indicates how accurate this particular location is
            strongSelf.statusLabel.text = [NSString stringWithFormat:@"'Location updates' subscription block called with Current Location:\n%@", currentLocation];
        }
        else {
            // An error occurred
            strongSelf.statusLabel.text = [strongSelf getErrorDescription:status];
        }
    }];
}

/**
 Starts a new subscription for significant location changes.
 */
- (void)startMonitoringSignificantLocationChanges
{
    __weak __typeof(self) weakSelf = self;
    INTULocationManager *locMgr = [INTULocationManager sharedInstance];
    self.locationRequestID = [locMgr subscribeToSignificantLocationChangesWithBlock:^(CLLocation *currentLocation, INTULocationAccuracy achievedAccuracy, INTULocationStatus status) {
        __typeof(weakSelf) strongSelf = weakSelf;
        
        if (status == INTULocationStatusSuccess) {
            // A new updated location is available in currentLocation, and achievedAccuracy indicates how accurate this particular location is
            strongSelf.statusLabel.text = [NSString stringWithFormat:@"'Significant changes' subscription block called with Current Location:\n%@", currentLocation];
        }
        else {
            // An error occurred
            strongSelf.statusLabel.text = [strongSelf getErrorDescription:status];
        }
    }];
}

/**
 Starts a new one-time request for the current location.
 */
- (void)startSingleLocationRequest
{
    __weak __typeof(self) weakSelf = self;
    INTULocationManager *locMgr = [INTULocationManager sharedInstance];
    self.locationRequestID = [locMgr requestLocationWithDesiredAccuracy:self.desiredAccuracy
                                                                timeout:self.timeout
                                                   delayUntilAuthorized:YES
                                                                  block:
                              ^(CLLocation *currentLocation, INTULocationAccuracy achievedAccuracy, INTULocationStatus status) {
                                  __typeof(weakSelf) strongSelf = weakSelf;
                                  
                                  if (status == INTULocationStatusSuccess) {
                                      // achievedAccuracy is at least the desired accuracy (potentially better)
                                      strongSelf.statusLabel.text = [NSString stringWithFormat:@"Location request successful! Current Location:\n%@", currentLocation];
                                  }
                                  else if (status == INTULocationStatusTimedOut) {
                                      // You may wish to inspect achievedAccuracy here to see if it is acceptable, if you plan to use currentLocation
                                      strongSelf.statusLabel.text = [NSString stringWithFormat:@"Location request timed out. Current Location:\n%@", currentLocation];
                                  }
                                  else {
                                      // An error occurred
                                      strongSelf.statusLabel.text = [strongSelf getLocationErrorDescription:status];
                                  }
                                  
                                  strongSelf.locationRequestID = NSNotFound;
                              }];
}

/**
 Callback when the "Request Current Location" or "Start Subscription" button is tapped.
 */
- (IBAction)startButtonTapped:(id)sender
{
    if (self.subscriptionForAllChangesSwitch.on) {
        [self startLocationUpdateSubscription];
    } else if (self.subscriptionForSignificantChangesSwitch.on) {
        [self startMonitoringSignificantLocationChanges];
    } else {
        [self startSingleLocationRequest];
    }
}

/**
 Callback when the "Force Complete Request" button is tapped.
 */
- (IBAction)forceCompleteRequest:(id)sender
{
    [[INTULocationManager sharedInstance] forceCompleteLocationRequest:self.locationRequestID];
    if (self.subscriptionForAllChangesSwitch.on || self.subscriptionForSignificantChangesSwitch.on) {
        // Clear the location request ID, since this will not be handled inside the subscription block
        // (This is not necessary for regular one-time location requests, since they will handle this inside the completion block.)
        self.locationRequestID = NSNotFound;
        self.statusLabel.text = @"Subscription canceled.";
    }
}

/**
 Callback when the "Cancel Request" button is tapped.
 */
- (IBAction)cancelRequest:(id)sender
{
    [[INTULocationManager sharedInstance] cancelLocationRequest:self.locationRequestID];
    self.locationRequestID = NSNotFound;
    self.statusLabel.text = self.subscriptionForAllChangesSwitch.on || self.subscriptionForSignificantChangesSwitch.on ? @"Subscription canceled." : @"Location request canceled.";
}

- (IBAction)subscriptionSwitchChanged:(UISwitch *)sender
{
    if (sender.on) {
        if ([sender isEqual:self.subscriptionForAllChangesSwitch]) {
            [self.subscriptionForSignificantChangesSwitch setOn:NO animated:YES];
        } else if ([sender isEqual:self.subscriptionForSignificantChangesSwitch]) {
            [self.subscriptionForAllChangesSwitch setOn:NO animated:YES];
        }
    }
    
    self.desiredAccuracyControl.userInteractionEnabled = !sender.on;
    self.timeoutSlider.userInteractionEnabled = !sender.on;
    
    CGFloat alpha = sender.on ? 0.2 : 1.0;
    [UIView animateWithDuration:0.3 animations:^{
        self.desiredAccuracyLabel.alpha = alpha;
        self.desiredAccuracyControl.alpha = alpha;
        self.timeoutLabel.alpha = alpha;
        self.timeoutSlider.alpha = alpha;
    }];
    
    NSString *requestLocationButtonTitle = sender.on ? @"Start Subscription" : @"Request Current Location";
    [self.requestCurrentLocationButton setTitle:requestLocationButtonTitle forState:UIControlStateNormal];
}

- (IBAction)desiredAccuracyControlChanged:(UISegmentedControl *)sender
{
    switch (sender.selectedSegmentIndex) {
        case 0:
            self.desiredAccuracy = INTULocationAccuracyCity;
            break;
        case 1:
            self.desiredAccuracy = INTULocationAccuracyNeighborhood;
            break;
        case 2:
            self.desiredAccuracy = INTULocationAccuracyBlock;
            break;
        case 3:
            self.desiredAccuracy = INTULocationAccuracyHouse;
            break;
        case 4:
            self.desiredAccuracy = INTULocationAccuracyRoom;
            break;
        default:
            break;
    }
}

- (IBAction)timeoutSliderChanged:(UISlider *)sender
{
    self.timeout = round(sender.value);
    if (self.timeout == 0) {
        self.timeoutLabel.text = [NSString stringWithFormat:@"Timeout: 0 seconds (no limit)"];
    } else if (self.timeout == 1) {
        self.timeoutLabel.text = [NSString stringWithFormat:@"Timeout: 1 second"];
    } else {
        self.timeoutLabel.text = [NSString stringWithFormat:@"Timeout: %ld seconds", (long)self.timeout];
    }
}

/**
 Implement the setter for locationRequestID in order to update the UI as needed.
 */
- (void)setLocationRequestID:(INTULocationRequestID)locationRequestID
{
    _locationRequestID = locationRequestID;
    
    BOOL isProcessingLocationRequest = (locationRequestID != NSNotFound);
    
    self.subscriptionForAllChangesSwitch.enabled = !isProcessingLocationRequest;
    self.subscriptionForSignificantChangesSwitch.enabled = !isProcessingLocationRequest;
    self.desiredAccuracyControl.enabled = !isProcessingLocationRequest;
    self.timeoutSlider.enabled = !isProcessingLocationRequest;
    self.requestCurrentLocationButton.enabled = !isProcessingLocationRequest;
    self.forceCompleteRequestButton.enabled = isProcessingLocationRequest && !self.subscriptionForAllChangesSwitch.on && !self.subscriptionForSignificantChangesSwitch.on;
    self.cancelRequestButton.enabled = isProcessingLocationRequest;
    
    if (isProcessingLocationRequest) {
        [self.activityIndicator startAnimating];
        self.statusLabel.text = @"Location request in progress...";
    } else {
        [self.activityIndicator stopAnimating];
    }
}

#pragma mark - Heading

- (NSString *)getHeadingErrorDescription:(INTUHeadingStatus)status
{
    if (status == INTUHeadingStatusUnavailable) {
        return @"Error: Heading services are not available on this device.";
    }
    return @"An unknown error occurred.\n(Are you using iOS Simulator with location set to 'None'?)";
}

- (void)startHeadingRequest
{
    __weak __typeof(self) weakSelf = self;
    self.headingRequestID = [[INTULocationManager sharedInstance] subscribeToHeadingUpdatesWithBlock:^(CLHeading *heading, INTUHeadingStatus status) {
        __typeof(weakSelf) strongSelf = weakSelf;
        if (status == INTUHeadingStatusSuccess) {
            // An updated heading is available
            strongSelf.statusLabel.text = [NSString stringWithFormat:@"'Heading updates' subscription block called with Current Heading:\n%@", heading];
        } else {

        }
    }];
}

- (void)cancelHeadingRequest
{
    [[INTULocationManager sharedInstance] cancelHeadingRequest:self.headingRequestID];
    self.headingRequestID = NSNotFound;
    self.statusLabel.text = @"Heading subscription canceled.";
}

- (IBAction)headingSubscriptionSwitchChanged:(UISwitch *)sender
{
    if (sender.on) {
        [self startHeadingRequest];
    } else {
        [self cancelHeadingRequest];
    }
}

/**
 Implement the setter for headingRequestID in order to update the UI as needed.
 */
- (void)setHeadingRequestID:(INTUHeadingRequestID)headingRequestID
{
    _headingRequestID = headingRequestID;

    BOOL isProcessingHeadingRequest = (headingRequestID != NSNotFound);
    if (isProcessingHeadingRequest) {
        self.statusLabel.text = @"Heading subscription in progress...";
    }
}

@end
