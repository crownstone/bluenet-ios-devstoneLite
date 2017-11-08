//
//  ViewController.swift
//  DevStoneLite
//
//  Created by Alex de Mulder on 07/11/2017.
//  Copyright © 2016 Alex de Mulder. All rights reserved.
//

import UIKit
import BluenetLib
import SwiftyJSON
import CoreBluetooth
import PromiseKit
import BluenetShared

class ViewController: UIViewController {
    var targetHandle = ""
    
    var advertisementUpdate : Double = 0
    var lastValidatedStone = Date().timeIntervalSince1970
    
    var nearestType   : String = ""
    var nearestHandle : String = ""
    var nearestName   : String = ""
    var nearestRssi   : Int = -1000
    var nearestVerified : Bool = false
    
    var bluenet : Bluenet!
    var bluenetLocalization : BluenetLocalization!

    @IBOutlet weak var progressBox: UITextView!
    @IBOutlet weak var selectedLabel: UILabel!
    @IBOutlet weak var nearestLabel: UILabel!
    @IBOutlet weak var setupView: UIView!
    @IBOutlet weak var normalView: UIView!
    @IBOutlet weak var DFUview: UIView!
    @IBOutlet weak var normalViewNoVerified: UIView!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var relaySwitch: UISwitch!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Give the viewcontroller and the appname in to Bluenet so we can trigger
        // alerts for bluetooth and navigation usage.
        BluenetLib.setBluenetGlobals(viewController: self, appName: "Example")
        
        // if you'd like to use Bluenet in the background, set the boolean to true. It is up to you to set the background capabilities
        // of your app to match. Also make sure the proper info.plist descriptions have been set:
        //      - NSBluetoothPeripheralUsageDescription
        //      - NSLocationAlwaysAndWhenInUseUsageDescription
        //      - NSLocationWhenInUseUsageDescription
        //      - NSLocationAlwaysUsageDescription)
        // Keep in mind, you NEED "Always" permissions to be able to use monitoring and ranging of iBeacons which is essential for Crownstones.
        // Background Modes: Locations updates (for iBeacon ranging in the background) Uses Bluetooth LE accessories to talk to Crownstones in the background.
        // Scanning in the background for BLE advertisements is unreliable. We use the iBeacon updates for distance estimation.
        self.bluenet = Bluenet(backgroundEnabled: false);
        self.bluenetLocalization = BluenetLocalization(backgroundEnabled: false);
        
        // set the encryption keys in bluenet. These are used to decypher advertisements. Without these, you can't talk to Crownstones when they are not in setup mode.
        self.bluenet.setSettings(
            encryptionEnabled: true,
            adminKey:  "adminKeyFor12345",
            memberKey: "memberKeyFor1234",
            guestKey:  "guestKeyFor12345",
            referenceId: "test"
        )
        
        // Scan for BLE responses from Crownstones
        _ = self.bluenet.isReady()
            .then{_ in self.bluenet.startScanningForCrownstones()}
        
       self.subscribeToEvents()
    }
    
    func startLoop() {
        delay(0.5, { _ in
            self.evalLabel()
        })
    }
    
    func evalLabel() {
        let now = Date().timeIntervalSince1970
        if (now - self.advertisementUpdate > 4) {
            self.nearestType   = ""
            self.nearestHandle = ""
            self.nearestName   = ""
            self.nearestRssi   = -1000
        }
        if (self.nearestHandle == "") {
            self.nearestLabel.text = "None found"
        }
    }

    func subscribeToEvents() {
        // update the labels
        self.startLoop()
        
        // The advertisement data event is used to read the data broadcasted by the Crownstone scan response.
        // If the data is not decrypted, it can appear random.
        // Decryption success is based off the keys you set during setSettings and those that are stored in the Crownstone during setup.
        _ = bluenet.on("advertisementData", {data -> Void in
            if let castData = data as? Advertisement {
                let dict = castData.getDictionary()
                if (self.targetHandle == dict["handle"] as? String) {
                    if let serviceData = dict["serviceData"] as? NSDictionary {
                        let state = serviceData["switchState"] as! Int
                        
                        if (self.progressBox.text != "Start switching") {
                            if (state > 100 && self.relaySwitch.isOn == false) {
                                self.relaySwitch.isOn = true
                            }
                            else if (state < 100 && self.relaySwitch.isOn == true) {
                                self.relaySwitch.isOn = false
                            }
                        }
                    }
                }
            }
        })
        
        // these events will give you the nearest Crownstones in normal (verified or not), DFU and setup mode.
        _ = bluenet.on("nearestCrownstone",      {data -> Void in self.parseEvent(type: "nearestCrownstone",      data: data) })
        _ = bluenet.on("nearestDFUCrownstone",   {data -> Void in self.parseEvent(type: "nearestDFUCrownstone",   data: data) })
        _ = bluenet.on("nearestSetupCrownstone", {data -> Void in self.parseEvent(type: "nearestSetupCrownstone", data: data) })
        
        // the setupProgress event is used to keep track of the setup progress
        _ = bluenet.on("setupProgress", {data -> Void in
            if let castData = data as? Int {
                self.progressBox.text = "setupProgress \(castData)"
            }
        })
    }
    
    
    /**
     * Update the views based on the mode of the selected Crownstone. This is based off which nearest
     **/
    func _updateViews(type: String, verified: Bool) {
        self.scrollView.isHidden = false
        if (type == "nearestCrownstone") {
            self.setupView.isHidden = true
            self.DFUview.isHidden   = true
            if (verified) {
                
                self.normalView.isHidden           = false
                self.normalViewNoVerified.isHidden = true
            }
            else {
                self.normalView.isHidden           = true
                self.normalViewNoVerified.isHidden = false
            }
        }
        else if (type == "nearestSetupCrownstone") {
            self.setupView.isHidden            = false
            self.DFUview.isHidden              = true
            self.normalView.isHidden           = true
            self.normalViewNoVerified.isHidden = true
        }
        else if (type == "nearestDFUCrownstone") {
            self.setupView.isHidden            = true
            self.DFUview.isHidden              = false
            self.normalView.isHidden           = true
            self.normalViewNoVerified.isHidden = true
        }
    }
    
    
    /**
     * Handle all the nearest events.
     **/
    func parseEvent(type: String, data: Any) {
        if let castData = data as? NearestItem {
            self.advertisementUpdate = Date().timeIntervalSince1970
            let dict = castData.getDictionary()
            if (self.targetHandle == dict["handle"] as? String) {
                self.selectedLabel.text = "\(dict["name"]!), rssi:\(dict["rssi"]!)"
                self._updateViews(type: type, verified: dict["verified"] as! Bool)
            }
            
            if (self.nearestHandle != dict["handle"] as? String) {
                if (self.nearestRssi < dict["rssi"] as! Int) {
                    self.nearestType       = type
                    self.nearestHandle     = dict["handle"] as! String
                    self.nearestName       = dict["name"] as! String
                    self.nearestRssi       = dict["rssi"] as! Int
                    self.nearestVerified   = dict["verified"] as! Bool
                    self.nearestLabel.text = "\(dict["name"]!) : \(dict["rssi"]!)"
                }
            }
            else {
                self.nearestLabel.text = "\(dict["name"]!) : \(dict["rssi"]!)"
            }
        }
    }
    
    /**
     * Select the handle that was shown in the nearest slot.
     **/
    @IBAction func selectCrownstone(_ sender: Any) {
        if (self.nearestHandle != "") {
            self.targetHandle = self.nearestHandle
            self._updateViews(type: self.nearestType, verified: self.nearestVerified)
        }
    }
    
    /**
     * Crownstone recovery can only be done 20 seconds after the Crownstone has powered on. This is used to reset the encryption keys of a Crownstone.
     * This will put the Crownstone back in setup mode.
     **/
    @IBAction func recoverCrownstone(_ sender: Any) {
        bluenet.control.recoverByFactoryReset(self.targetHandle)
            .then{_    in self.progressBox.text = "done"}
            .catch{err in self.progressBox.text = "\(err)"}
        progressBox.text = "start recovery. This can only be done 20 seconds after the CS powered on."
    }
    
    /**
     * This is used to reset the encryption keys of a Crownstone, when you are currently the owner and have the keys.
     * This will put the Crownstone back in setup mode.
     **/
    @IBAction func factoryResetCrownstone(_ sender: Any) {
        self.bluenet.isReady() // first check if the bluenet lib is ready before using it.
            .then{_ in self.bluenet.connect(self.targetHandle)} // connect
            .then{_ in self.bluenet.control.commandFactoryReset()} // switch
            .then{_ in self.bluenet.control.disconnect()} // disconnect
            .then{_ in self.progressBox.text = "DONE RESET"}
            .catch{err in
                _ = self.bluenet.disconnect()
                self.progressBox.text = "\(err)"
        } // catch errors
        progressBox.text = "PERFORMING RESET"
    }

    /**
     * Switch the relay on and off.
     **/
    @IBAction func switchRelay(_ sender: Any) {
        if let mySwitch = sender as? UISwitch {
            var newState : Float = 1
            if (!mySwitch.isOn) {
                newState = 0
            }
            // we return the promises so we can chain the then() calls.
            bluenet.isReady() // first check if the bluenet lib is ready before using it.
                .then{_ in self.bluenet.connect(self.targetHandle)} // connect
                .then{_ in self.bluenet.control.setSwitchState(newState)} // switch
                .then{_ in self.bluenet.control.disconnect()} // disconnect
                .then{_ in self.progressBox.text = "DONE switching relay \(newState)"}
                .catch{err in
                    _ = self.bluenet.disconnect()
                    self.progressBox.text = "\(err)"
            } // catch errors
            progressBox.text = "Start switching"
        }
    }
    
    /**
     * Perform the Setup procedure on a Crownstone that is new, recovered or factory reset.
     * The setup phase sets all data required for secure usage of the Crownstone.
     **/
    @IBAction func setupCrownstone(_ sender: Any) {
        self.bluenet.isReady() // first check if the bluenet lib is ready before using it for BLE things.
            .then{_ in self.bluenet.connect(self.targetHandle)} // once the lib is ready, connect
            .then{_ in self.bluenet.setup.setup(
                crownstoneId: 1,               // ID of Crownstone used to correlate iBeacon message and advertisements
                adminKey:  "adminKeyFor12345", // Admin key used for the encryption
                memberKey: "memberKeyFor1234", // Member key used for the encryption
                guestKey:  "guestKeyFor12345", // Guest key used for the encryption
                meshAccessAddress: "4f745905", // Mesh address that filters out the mesh messages of your Crownstones from other possible groups of Crownstones
                ibeaconUUID: "1843423e-e175-4af0-a2e4-31e32f729a8a", // UUID for iBeacon broadcasts
                ibeaconMajor: 123,
                ibeaconMinor: 456
            )}
            .then{_ -> Void in
                self.progressBox.text = "SETUP COMPLETE"
            }
            .catch{err in
                self.progressBox.text = "error during setup \(err)"
                _ = self.bluenet.disconnect()
        }
    }
}
