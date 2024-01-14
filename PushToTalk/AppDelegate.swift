//
//  AppDelegate.swift
//  PushToTalk
//
//  Created by Ahmy Yulrizka on 17/03/15.
//  Copyright (c) 2015 yulrizka. All rights reserved.
//

import Cocoa
import AudioToolbox
import AVKit

@NSApplicationMain

class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var window: NSWindow!
    @IBOutlet weak var statusMenu: NSMenu!
    @IBOutlet weak var menuItemToggle: NSMenuItem!
    @IBOutlet weak var deviceMenu: NSMenu!
    @IBOutlet weak var hotkeyMenuItem: NSMenuItem!
    
    var microphone = Microphone()
    var hotkey: HotKey?
    var deviceWatcher: AudioObjectPropertyListenerProc?
    
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    
    func deviceNotification(device: AudioObjectID, address: UInt32, propertyAddress: UnsafePointer<AudioObjectPropertyAddress>, clientData: UnsafeMutableRawPointer?){
        guard let newDevices = try? microphone.getInputDevices() else {
            return
        }
        for newDevice in newDevices {
            if newDevice.uid == microphone.selectedInput?.uid {
                microphone.selectedInput = newDevice
            }
        }
    }

    fileprivate func setupDeviceWatcher() {
        // closure for callback
        let listener: AudioObjectPropertyListenerProc = { ( inObjectID, inNumberAddresses, inAddresses, inClientData ) in
            // convert back to appdelegate instance
            let appDelegate = Unmanaged<AppDelegate>.fromOpaque(inClientData!).takeUnretainedValue()
            // call method with data
            appDelegate.deviceNotification(device: inObjectID, address: inNumberAddresses, propertyAddress: inAddresses, clientData: inClientData)
            return 1
        }
        
        var address = AudioObjectPropertyAddress( mSelector: kAudioHardwarePropertyDevices, mScope: kAudioObjectPropertyScopeGlobal, mElement:  kAudioObjectPropertyElementMaster)
        
        let status = AudioObjectAddPropertyListener( AudioObjectID(kAudioObjectSystemObject), &address, listener, UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()) )
        
        if status != 0 {
            print("Couldn't add listener: \(status)")
        } else {
            print("Device watcher set up")
            self.deviceWatcher = listener
        }
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        
        setupDeviceWatcher()
    
        self.hotkey = HotKey(microphone: microphone, menuItem: hotkeyMenuItem)
        
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
            case .notDetermined: // The user has not yet been asked for camera access.
                AVCaptureDevice.requestAccess(for: .audio) { granted in
                    if !granted {
                        NSLog("Can't get access to the mic.")
                        exit(1)
                    }
                }
            
            case .denied: // The user has previously denied access.
                fallthrough
            case .restricted: // The user can't grant access due to restrictions.
                NSLog("Can't get access to the mic.")
                exit(1)
            default:
                print("Already has permission");
        }

        statusItem.menu = statusMenu
        self.microphone.statusUpdated = { (status) in
            self.menuItemToggle.title = status.title()
            self.statusItem.button?.image = status.image()
        }
        self.microphone.status = .Muted
        self.refreshDevices(nil);
    }
    
    
    func applicationWillTerminate(_ notification: Notification) {
        
       // This mosst likely won't ever work because background apps are immediately killed
        guard let deviceWatcher else {
            return
        }
        
        print("Cleaning up listener")
        var address = AudioObjectPropertyAddress(
                    mSelector: kAudioHardwarePropertyDevices,
                    mScope: kAudioObjectPropertyScopeGlobal,
                    mElement: kAudioObjectPropertyElementMaster
                )
        AudioObjectRemovePropertyListener(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            deviceWatcher,
            nil
        )
    }
    
    // MARK: Menu item Actions
    @IBAction func toggleAction(_ sender: NSMenuItem) {
        self.hotkey!.toggle()
    }
    
    @IBAction func menuItemQuitAction(_ sender: NSMenuItem) {
        self.microphone.status = .Speaking
        exit(0)
    }
    
    @IBAction func refreshDevices(_ sender: NSMenuItem?) {
        do {
            try self.microphone.setupDeviceMenu(menu: deviceMenu)
        } catch {
            print("Unexpected Error: \(error).")
            exit(1)
        }
    }
    
    @IBAction func recordNewHotKey(_ sender: NSMenuItem) {
        self.hotkey!.recordNewHotKey()
    }
}

