//
//  ViewController.swift
//  AcapellaBot BLE Dispatcher
//
//  Created by Sean Zhang on 30/07/2017.
//  Copyright © 2017 Sean Zhang. All rights reserved.
//

import Cocoa
import CoreBluetooth
import CocoaAsyncSocket

class ViewController: NSViewController, NSWindowDelegate, CBCentralManagerDelegate, CBPeripheralDelegate, GCDAsyncUdpSocketDelegate {
    
    var manager:CBCentralManager!
    var peripheral:CBPeripheral!
    
    var udpClient:GCDAsyncUdpSocket!
    
    let BEAN_NAME = "AcapellaBot Baton"
    let BEAN_SCRATCH_UUID =
        CBUUID(string: "123c")
    let BEAN_SERVICE_UUID =
        CBUUID(string: "123c")
    
    @IBOutlet weak var statusLabel: NSTextField!
    @IBOutlet weak var bleDeviceList: NSPopUpButton!
    @IBOutlet weak var ipTextField: NSTextField!
    @IBOutlet weak var portTextField: NSTextField!
    @IBOutlet weak var connectButton: NSButton!
    @IBOutlet weak var destinationTableView: NSTableView!
    
    var peripherals = [String: CBPeripheral]()
    
    var addrs = ["192.168.3.100"]
    var ports = [12345]

    override func viewDidLoad() {
        super.viewDidLoad()

        manager = CBCentralManager(delegate: self, queue: nil)
        statusLabel.stringValue = "Scanning for devices..."
        udpClient = GCDAsyncUdpSocket()
        udpClient.setDelegate(self)
        
        destinationTableView.delegate = self
        destinationTableView.dataSource = self
    }
    
    override func viewDidAppear() {
        self.view.window?.delegate = self
    }
    
    func windowShouldClose(_ sender: Any) -> Bool {
        NSApplication.shared().terminate(self)
        return true
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }

    @IBAction func connectButtonClicked(_ sender: Any) {
        self.manager.stopScan()
        if (bleDeviceList.selectedItem != nil) {
            let peripheralName = bleDeviceList.selectedItem!.title
            self.peripheral = peripherals[peripheralName]
            self.peripheral.delegate = self
            manager.connect(self.peripheral, options: nil)
            print("connect")
            statusLabel.stringValue = "Connecting to " + peripheralName + "..."
        }
        
        
    }
    
    @IBAction func addButtonClicked(_ sender: Any) {
        if (ipTextField.stringValue != "" && portTextField.stringValue != "") {
            addrs.append(ipTextField.stringValue)
            ports.append(Int.init(portTextField.stringValue)!)
        }
        
        destinationTableView.reloadData()
        
    }
    
    
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == CBCentralManagerState.poweredOn {
            
            print("update")
            central.scanForPeripherals(withServices: nil, options: nil)
        } else {
            print("Bluetooth not available.")
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        print("discover")
        let device = (advertisementData as NSDictionary)
            .object(forKey: CBAdvertisementDataLocalNameKey)
            as? NSString
        if (device != nil) {
            print(device!)
            bleDeviceList.addItem(withTitle: device! as String)
            peripherals[device! as String] = peripheral
        }
        
        if device?.contains(BEAN_NAME) == true {
            self.manager.stopScan()
            self.peripheral = peripheral
            self.peripheral.delegate = self
            manager.connect(peripheral, options: nil)
            print("connect")
        }
        
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        statusLabel.stringValue = "Connected. Discovering services..."
        peripheral.discoverServices(nil)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        for service in peripheral.services! {
            let thisService = service as CBService
            print(service.uuid)
            if service.uuid == BEAN_SERVICE_UUID {
                print("discovered service")
                statusLabel.stringValue = "Discovered services. Discovering characteristics..."
                peripheral.discoverCharacteristics(nil, for: thisService)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        for characteristic in service.characteristics! {
            let thisCharacteristic = characteristic as CBCharacteristic
            
            if thisCharacteristic.uuid == BEAN_SCRATCH_UUID {
                statusLabel.stringValue = "Done. Ready to receive notifications."
                connectButton.title = "Connected"
                connectButton.isEnabled = false
                self.peripheral.setNotifyValue(true, for: thisCharacteristic)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        //var count:UInt32 = 0;
        
        if characteristic.uuid == BEAN_SCRATCH_UUID {
            statusLabel.stringValue = "Received value: " + String(characteristic.value![0])
            print(characteristic.value![0])
            if (addrs.count > 0) {
                for index in 0...addrs.count - 1 {
                    udpClient.send(characteristic.value!, toHost: addrs[index], port: UInt16(ports[index]), withTimeout: -1, tag: 0);
                }
            }
        }
    }
}

extension ViewController: NSTableViewDataSource {
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return addrs.count
    }
    
}

extension ViewController: NSTableViewDelegate {
    
    fileprivate enum CellIdentifiers {
        static let AddressCell = "AddressCellID"
        static let PortCell = "PortCellID"
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        
        var image: NSImage?
        var text: String = ""
        var cellIdentifier: String = ""
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .long
        
        
        if tableColumn == tableView.tableColumns[0] {
            text = addrs[row]
            cellIdentifier = CellIdentifiers.AddressCell
        } else if tableColumn == tableView.tableColumns[1] {
            text = String(ports[row])
            cellIdentifier = CellIdentifiers.PortCell
        }
        
        if let cell = tableView.make(withIdentifier: cellIdentifier, owner: nil) as? NSTableCellView {
            cell.textField?.stringValue = text
            return cell
        }
        return nil
    }
    
}
