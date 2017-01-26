//
//  ViewController.swift
//  DevStoneLite
//
//  Created by Alex de Mulder on 24/11/2016.
//  Copyright © 2016 Alex de Mulder. All rights reserved.
//

import UIKit
import BluenetLib

class ViewController: UIViewController {
    var target : String? = nil
    var targetValidatedStoneHandle : String? = nil
    
    var lastValidatedStone = Date().timeIntervalSince1970
    
    var bluenet : Bluenet!
    var bluenetLocalization : BluenetLocalization!
    
    
    @IBOutlet weak var selected: UILabel!
    @IBOutlet weak var nearLabel: UILabel!
    @IBAction func selectNearest(_ sender: Any) {
        if (targetValidatedStoneHandle != nil) {
            target = targetValidatedStoneHandle!
            progress.text = "target set to nearest"
        }
        else {
            progress.text = "no target"
        }
    }
    @IBAction func toggleRelay(_ sender: Any) {
        if let mySwitch = sender as? UISwitch {
            print("HERE \(mySwitch.isOn)")
            if (mySwitch.isOn) {
                switchRelayOn()
            }
            else {
                switchRelayOff()
            }
        }

    }

    
    func switchRelayOn() {
        if (target != nil) {
            // we return the promises so we can chain the then() calls.
            self.bluenet.isReady() // first check if the bluenet lib is ready before using it.
                .then{_ in return self.bluenet.connect(self.target!)} // connect
                .then{_ in return self.bluenet.control.switchRelay(1)} // switch
                .then{_ in return self.bluenet.control.disconnect()} // disconnect
                .then{_ in self.progress.text = "DONE switching relay on"}
                .catch{err in
                    _ = self.bluenet.disconnect()
                    self.progress.text = "\(err)"
            } // catch errors
            progress.text = "switchRelayOn"
        }
        else {
            progress.text = "no target"
        }
    }
    func switchRelayOff() {
        if (target != nil) {
            // we return the promises so we can chain the then() calls.
            self.bluenet.isReady() // first check if the bluenet lib is ready before using it.
                .then{_ in return self.bluenet.connect(self.target!)} // connect
                .then{_ in return self.bluenet.control.switchRelay(0)} // switch
                .then{_ in return self.bluenet.control.disconnect()} // disconnect
                .then{_ in self.progress.text = "DONE switching relay off"}
                .catch{err in
                    _ = self.bluenet.disconnect()
                    self.progress.text = "\(err)"
            } // catch errors
            progress.text = "switchRelayOff"
        }
        else {
            progress.text = "no target"
        }
    }
    
    @IBOutlet weak var RelaySwitch: UISwitch!
    @IBOutlet weak var progress: UITextView!

    
    
    func _evalLabels() {
        let now = Date().timeIntervalSince1970
        if (now - lastValidatedStone > 4) {
            targetValidatedStoneHandle = nil
            nearLabel.text = "None found"
        }
    }
    
    func startLoop() {
        delay(0.5, { _ in
            self._evalLabels()
            self.startLoop()
        })
    }
    

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        self.startLoop()
        // important, set the viewcontroller and the appname in the library so we can trigger
        // alerts for bluetooth and navigation usage.
        BluenetLib.setBluenetGlobals(viewController: self, appName: "Crownstone")
        self.bluenet = Bluenet();
        self.bluenetLocalization = BluenetLocalization();
        
        // default
        self.bluenet.setSettings(encryptionEnabled: true,
                                 adminKey: "adminKeyForCrown",
                                 memberKey: "memberKeyForHome",
                                 guestKey: "guestKeyForGirls",
                                 referenceId: "test")
        
       
        _ = self.bluenet.on("nearestVerifiedCrownstone", {data -> Void in
            if let castData = data as? NearestItem {
                self.lastValidatedStone = Date().timeIntervalSince1970
                
                let dict = castData.getDictionary()
                self.targetValidatedStoneHandle = dict["handle"] as? String
                self.nearLabel.text = "\(dict["name"]!) : \(dict["rssi"]!)"
                self._evalLabels()
            }
        })
        
        _ = self.bluenet.on("advertisementData", {data -> Void in
            if let castData = data as? Advertisement {
                let dict = castData.getDictionary()
                
                if (self.target == dict["handle"] as? String) {
                    self.selected.text = "\(dict["name"]!) : \(dict["rssi"]!)"
                    
                    let serviceData = dict["serviceData"] as! NSDictionary
                    let state = serviceData["switchState"] as! Int
                    
                    if (state > 100 && self.RelaySwitch.isOn == false) {
                        self.RelaySwitch.isOn = true
                    }
                    else if (state < 100 && self.RelaySwitch.isOn == true) {
                        self.RelaySwitch.isOn = false
                    }
                    
                }
            }
        })
        
        self.bluenetLocalization.clearTrackedBeacons()
        _ = self.bluenet.isReady()
            .then{_ in self.bluenet.startScanningForCrownstones()}
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

