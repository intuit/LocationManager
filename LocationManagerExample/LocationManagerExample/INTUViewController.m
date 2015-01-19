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
#import "INTULocationManager.h"

@interface INTUViewController ()

@property (weak, nonatomic) IBOutlet UILabel *statusLabel;
@property (weak, nonatomic) IBOutlet UISwitch *subscriptionSwitch;
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

@end

@implementation INTUViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	
    self.subscriptionSwitch.on = NO;
    self.desiredAccuracyControl.selectedSegmentIndex = 0;
    self.desiredAccuracy = INTULocationAccuracyCity;
    self.timeoutSlider.value = 10.0;
    self.timeout = 10.0;
    
    self.locationRequestID = NSNotFound;
    self.statusLabel.text = @"Tap the button below to start a new location request.";
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
            strongSelf.statusLabel.text = [NSString stringWithFormat:@"Subscription block called with Current Location:\n%@", currentLocation];
        }
        else {
            // An error occurred, which causes the subscription to cancel automatically (this block will not execute again unless it is used to start a new subscription).
            strongSelf.locationRequestID = NSNotFound;
            
            if (status == INTULocationStatusServicesNotDetermined) {
                strongSelf.statusLabel.text = @"Error: User has not responded to the permissions alert.";
            } else if (status == INTULocationStatusServicesDenied) {
                strongSelf.statusLabel.text = @"Error: User has denied this app permissions to access device location.";
            } else if (status == INTULocationStatusServicesRestricted) {
                strongSelf.statusLabel.text = @"Error: User is restricted from using location services by a usage policy.";
            } else if (status == INTULocationStatusServicesDisabled) {
                strongSelf.statusLabel.text = @"Error: Location services are turned off for all apps on this device.";
            } else {
                strongSelf.statusLabel.text = @"An unknown error occurred.\n(Are you using iOS Simulator with location set to 'None'?)";
            }
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
                                      if (status == INTULocationStatusServicesNotDetermined) {
                                          strongSelf.statusLabel.text = @"Error: User has not responded to the permissions alert.";
                                      } else if (status == INTULocationStatusServicesDenied) {
                                          strongSelf.statusLabel.text = @"Error: User has denied this app permissions to access device location.";
                                      } else if (status == INTULocationStatusServicesRestricted) {
                                          strongSelf.statusLabel.text = @"Error: User is restricted from using location services by a usage policy.";
                                      } else if (status == INTULocationStatusServicesDisabled) {
                                          strongSelf.statusLabel.text = @"Error: Location services are turned off for all apps on this device.";
                                      } else {
                                          strongSelf.statusLabel.text = @"An unknown error occurred.\n(Are you using iOS Simulator with location set to 'None'?)";
                                      }
                                  }
                                  
                                  strongSelf.locationRequestID = NSNotFound;
                              }];
}

/**
 Callback when the "Request Current Location" or "Start Subscription" button is tapped.
 */
- (IBAction)startButtonTapped:(id)sender
{
    if (self.subscriptionSwitch.on) {
        [self startLocationUpdateSubscription];
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
    if (self.subscriptionSwitch.on) {
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
    self.statusLabel.text = self.subscriptionSwitch.on ? @"Subscription canceled." : @"Location request canceled.";
}

- (IBAction)subscriptionSwitchChanged:(UISwitch *)sender
{
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
    
    self.subscriptionSwitch.enabled = !isProcessingLocationRequest;
    self.desiredAccuracyControl.enabled = !isProcessingLocationRequest;
    self.timeoutSlider.enabled = !isProcessingLocationRequest;
    self.requestCurrentLocationButton.enabled = !isProcessingLocationRequest;
    self.forceCompleteRequestButton.enabled = isProcessingLocationRequest && !self.subscriptionSwitch.on;
    self.cancelRequestButton.enabled = isProcessingLocationRequest;
    
    if (isProcessingLocationRequest) {
        [self.activityIndicator startAnimating];
        self.statusLabel.text = @"Location request in progress...";
    } else {
        [self.activityIndicator stopAnimating];
    }
}

@end
