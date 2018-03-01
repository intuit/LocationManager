//
//  Copyright (c) 2015 MyCompany. All rights reserved.
//

import UIKit

import Foundation
import INTULocationManager


class ViewController: UIViewController {

    @IBOutlet var statusLabel:UILabel!
    @IBOutlet var subscriptionForAllChangesSwitch:UISwitch!
    @IBOutlet var subscriptionForSignificantChangesSwitch:UISwitch!
    @IBOutlet var subscriptionForAllHeadingChangesSwitch:UISwitch!
    @IBOutlet var timeoutLabel:UILabel!
    @IBOutlet var desiredAccuracyLabel:UILabel!
    @IBOutlet var desiredAccuracyControl:UISegmentedControl!
    @IBOutlet var timeoutSlider:UISlider!
    @IBOutlet var requestCurrentLocationButton:UIButton!
    @IBOutlet var cancelRequestButton:UIButton!
    @IBOutlet var forceCompleteRequestButton:UIButton!
    @IBOutlet var activityIndicator:UIActivityIndicatorView!
    
    var desiredAccuracy:INTULocationAccuracy!
    var timeout:NSTimeInterval = 0.0
    
    var locationRequestID:INTULocationRequestID!
    var headingRequestID:INTUHeadingRequestID!

    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.subscriptionForAllChangesSwitch!.on = false
        self.subscriptionForSignificantChangesSwitch!.on = false
        self.subscriptionForAllHeadingChangesSwitch!.on = false
        self.desiredAccuracyControl!.selectedSegmentIndex = 0
        self.desiredAccuracy = INTULocationAccuracy.Room
        self.timeoutSlider!.value = 10.0
        self.timeout = 10.0
        
        self.locationRequestID = NSNotFound
        self.headingRequestID = NSNotFound
        self.statusLabel!.text = "Tap the button below to start a new location or heading request."
        
    }
    
    func getLocationErrorDescription(status:INTULocationStatus) -> String {
        if (status == INTULocationStatus.ServicesNotDetermined) {
            return "Error: User has not responded to the permissions alert."
        }
        if (status == INTULocationStatus.ServicesDenied) {
            return "Error: User has denied this app permissions to access device location."
        }
        if (status == INTULocationStatus.ServicesRestricted) {
            return "Error: User is restricted from using location services by a usage policy."
        }
        if (status == INTULocationStatus.ServicesDisabled) {
            return "Error: Location services are turned off for all apps on this device."
        }
        return "An unknown error occurred.\n(Are you using iOS Simulator with location set to 'None'?)"
    }
    
    func startLocationUpdateSubscription() {
        weak var weakSelf = self
        let locMgr:INTULocationManager = INTULocationManager.sharedInstance()
        
        self.locationRequestID = locMgr.subscribeToLocationUpdatesWithBlock({ (currentLocation:CLLocation!, locationAccuracy:INTULocationAccuracy, locationStatus:INTULocationStatus) in
            
            weak var strongSelf = weakSelf
            
            if (locationStatus == INTULocationStatus.Success) {
            // A new updated location is available in currentLocation, and achievedAccuracy indicates how accurate this particular location is
            strongSelf!.statusLabel.text = "'Location updates' subscription block called with Current Location:\(currentLocation)"
            }
            else {
                // An error occurred
                strongSelf!.statusLabel.text = strongSelf?.getLocationErrorDescription(locationStatus)
            }
        })
    }
    
    func startMonitoringSignificantLocationChanges() {
        
        let locMgr:INTULocationManager = INTULocationManager.sharedInstance()
        
        self.locationRequestID = locMgr.subscribeToSignificantLocationChangesWithBlock({ (currentLocation:CLLocation!, locationAccuracy:INTULocationAccuracy, locationStatus:INTULocationStatus) in
            
            weak var strongSelf = self
            
            if (locationStatus == INTULocationStatus.Success) {
                // A new updated location is available in currentLocation, and achievedAccuracy indicates how accurate this particular location is
                strongSelf!.statusLabel.text = "'Significant changes' subscription block called with Current Location:\(currentLocation)"
            }
            else {
                // An error occurred
                strongSelf!.statusLabel.text = strongSelf!.getLocationErrorDescription(locationStatus)
            }
        })
    }
    
    func startSingleLocationRequest() {
        
        let locMgr:INTULocationManager = INTULocationManager.sharedInstance()
        
        self.locationRequestID = locMgr.requestLocationWithDesiredAccuracy(self.desiredAccuracy, timeout: self.timeout, delayUntilAuthorized: true, block: { (currentLocation:CLLocation!, locationAccuracy:INTULocationAccuracy, locationStatus:INTULocationStatus) in
            
            
            weak var strongSelf = self
            
            if (locationStatus == INTULocationStatus.Success) {
                // achievedAccuracy is at least the desired accuracy (potentially better)
                strongSelf!.statusLabel.text = "Location request successful! Current Location:\(currentLocation)"
            }
            else if (locationStatus == INTULocationStatus.TimedOut) {
                // You may wish to inspect achievedAccuracy here to see if it is acceptable, if you plan to use currentLocation
                strongSelf!.statusLabel.text = "Location request timed out. Current Location:\(currentLocation)"
            }
            else {
                // An error occurred
                strongSelf!.statusLabel.text = strongSelf!.getLocationErrorDescription(locationStatus)
            }
            
            strongSelf!.locationRequestID = NSNotFound

        })
        
    }
    
    @IBAction func startButtonTapped(sender: UIButton) {
        if (self.subscriptionForAllChangesSwitch.on) {
            self.startLocationUpdateSubscription()
        } else if (self.subscriptionForSignificantChangesSwitch.on) {
            self.startMonitoringSignificantLocationChanges()
        } else {
            self.startSingleLocationRequest()
        }
    }
    
    @IBAction func forceCompleteRequest(sender: UIButton) {
        if (self.subscriptionForAllChangesSwitch.on || self.subscriptionForSignificantChangesSwitch.on) {
            // Clear the location request ID, since this will not be handled inside the subscription block
            // (This is not necessary for regular one-time location requests, since they will handle this inside the completion block.)
            self.locationRequestID = NSNotFound
            self.statusLabel.text = "Subscription canceled."
        }
    }
    
    @IBAction func cancelRequest(sender: UIButton) {
        let locMgr:INTULocationManager = INTULocationManager.sharedInstance()
        
        locMgr.cancelLocationRequest(self.locationRequestID)
        
        self.locationRequestID = NSNotFound
        
        self.statusLabel.text = self.subscriptionForAllChangesSwitch.on || self.subscriptionForSignificantChangesSwitch.on ? "Subscription canceled." : "Location request canceled."
        
    }
    
    @IBAction func subscriptionSwitchChanged(sender: UISwitch) {
        if (sender.on) {
            if (sender.isEqual(self.subscriptionForAllChangesSwitch)) {
                self.subscriptionForSignificantChangesSwitch.setOn(false, animated: true)
            } else if (sender.isEqual(self.subscriptionForSignificantChangesSwitch)) {
                self.subscriptionForAllChangesSwitch.setOn(false, animated: true)
            }
        }
        
        self.desiredAccuracyControl!.userInteractionEnabled = !sender.on
        self.timeoutSlider!.userInteractionEnabled = !sender.on
        
        let alpha:CGFloat = sender.on ? 0.2 : 1.0
        
        UIView.animateWithDuration(0.3) {
            self.desiredAccuracyLabel!.alpha = alpha
            self.desiredAccuracyControl!.alpha = alpha
            self.timeoutLabel!.alpha = alpha
            self.timeoutSlider!.alpha = alpha
        }
        
        
        let requestLocationButtonTitle = sender.on ? "Start Subscription" : "Request Current Location"
        self.requestCurrentLocationButton!.setTitle(requestLocationButtonTitle, forState:UIControlState.Normal)
        
        
    }
    
    @IBAction func desiredAccuracyControlChanged(sender: UISegmentedControl) {
        switch (sender.selectedSegmentIndex) {
        case 0:
            self.desiredAccuracy = INTULocationAccuracy.City
            break
        case 1:
            self.desiredAccuracy = INTULocationAccuracy.Neighborhood
            break
        case 2:
            self.desiredAccuracy = INTULocationAccuracy.Block
            break
        case 3:
            self.desiredAccuracy = INTULocationAccuracy.House
            break
        case 4:
            self.desiredAccuracy = INTULocationAccuracy.Room
            break
        default:
            break
        }
        
    }
    
    @IBAction func timeoutSliderChanged(sender: UISlider) {
        self.timeout = round(Double(sender.value));
        if (self.timeout == 0) {
            self.timeoutLabel!.text = "Timeout: 0 seconds (no limit)"
        } else if (self.timeout == 1) {
            self.timeoutLabel!.text = "Timeout: 1 second"
        } else {
            self.timeoutLabel!.text = "Timeout: \(self.timeout) seconds"
        }
        
    }
    
    func setLocationRequestID(locationRequestID: INTULocationRequestID) {
        self.locationRequestID = locationRequestID
        
        let isProcessingLocationRequest = (locationRequestID != NSNotFound);
        
        self.subscriptionForAllChangesSwitch.enabled = !isProcessingLocationRequest;
        self.subscriptionForSignificantChangesSwitch.enabled = !isProcessingLocationRequest;
        self.desiredAccuracyControl!.enabled = !isProcessingLocationRequest;
        self.timeoutSlider!.enabled = !isProcessingLocationRequest;
        self.requestCurrentLocationButton!.enabled = !isProcessingLocationRequest;
        self.forceCompleteRequestButton!.enabled = isProcessingLocationRequest && !self.subscriptionForAllChangesSwitch.on && !self.subscriptionForSignificantChangesSwitch.on;
        self.cancelRequestButton!.enabled = isProcessingLocationRequest;
        
        if (isProcessingLocationRequest) {
            self.activityIndicator!.startAnimating()
            self.statusLabel.text = "Location request in progress..."
        } else {
            self.activityIndicator!.stopAnimating()
        }
    }
    
    func getHeadingErrorDescription(status: INTUHeadingStatus) -> String {
        if (status == INTUHeadingStatus.Unavailable) {
            return "Error: Heading services are not available on this device."
        }
        
        return "An unknown error occurred.\n(Are you using iOS Simulator with location set to 'None'?)"
    }
    
    func startHeadingRequest() {
        self.statusLabel!.text = "Heading subscription in progress..."
        
        let locMgr:INTULocationManager = INTULocationManager.sharedInstance()
        
        
        self.headingRequestID = locMgr.subscribeToHeadingUpdatesWithBlock({ (heading: CLHeading!, status:INTUHeadingStatus) in
            
            weak var strongSelf = self
            if (status == INTUHeadingStatus.Success) {
                // An updated heading is available
                strongSelf!.statusLabel.text = "'Heading updates' subscription block called with Current Heading:\(heading)"
            } else {
                strongSelf!.statusLabel.text = self.getHeadingErrorDescription(status)
            }
        })
        
    }
    
    func cancelHeadingRequest() {
        
        let locMgr:INTULocationManager = INTULocationManager.sharedInstance()
        
        locMgr.cancelHeadingRequest(self.headingRequestID!)
        self.headingRequestID = NSNotFound;
        self.statusLabel.text = "Heading subscription canceled."
    }
    
    func headingSubscriptionSwitchChanged(sender: UISwitch) {
        
        if (sender.on) {
            self.startHeadingRequest()
        } else {
            self.cancelHeadingRequest()
        }
    }
}