//
//  OznerEasyLink.swift
//  OznerLibrarySwiftyDemo
//
//  Created by 赵兵 on 2017/2/15.
//  Copyright © 2017年 net.ozner. All rights reserved.
//
//
import UIKit

class OznerEasyLink_V1: NSObject,EasyLinkFTCDelegate {
    
    var deviceInfo:OznerDeviceInfo!
    private var easylink_config:EASYLINK!
    private static var _instance: OznerEasyLink_V1! = nil
    static var instance: OznerEasyLink_V1! {
        get {
            if _instance == nil {
                
                _instance = OznerEasyLink_V1()
            }
            return _instance
        }
        set {
            _instance = newValue
        }
    }
    required override init() {
        super.init()
        if( easylink_config == nil){
            easylink_config = EASYLINK(delegate: self)
        }
        
        //wifiReachability = Reachability.forLocalWiFi()  //监测Wi-Fi连接状态
    }
    //自定义方法
    private var deviceType=OZDeviceClass.AirPurifier_Wifi
    private var pairOutTime=0
    private var SuccessBlock:((OznerDeviceInfo)->Void)!
    private var FailedBlock:((Error)->Void)!
    func starPair(deviceClass:OZDeviceClass,ssid:String?,password:String?,timeOut:Int,successBlock:((OznerDeviceInfo)->Void)!,failedBlock:((Error)->Void)!) {//开始配对
        deviceInfo=OznerDeviceInfo()
        deviceInfo.wifiVersion=1
        SuccessBlock=successBlock
        FailedBlock=failedBlock
        pairOutTime=timeOut
        deviceType=deviceClass
        if( easylink_config == nil){
            easylink_config = EASYLINK(delegate: self)
        }
            var wlanConfig = [String:Any]()
            wlanConfig[KEY_SSID]=ssid!.data(using: String.Encoding.utf8)
            wlanConfig[KEY_PASSWORD]=password!
            wlanConfig[KEY_DHCP]=1
            wlanConfig[KEY_IP]=EASYLINK.getIPAddress()
            wlanConfig[KEY_NETMASK]=EASYLINK.getNetMask()
            wlanConfig[KEY_GATEWAY]=EASYLINK.getGatewayAddress()
            wlanConfig[KEY_DNS1]=EASYLINK.getGatewayAddress()
            easylink_config.prepareEasyLink_(withFTC: wlanConfig, info: "".data(using: String.Encoding.utf8), mode: EASYLINK_V2_PLUS)
            easylink_config.transmitSettings()
            print("开始进行WIFI配对，配对信息如下")
    }
    
    func canclePair() {//取消配对
        if (easylink_config != nil&&easylink_config.responds(to: Selector.init(("stopTransmitting:")))) {
            easylink_config.stopTransmitting()
        }
    }
    @objc private func pairFailed() {
        canclePair()
        FailedBlock(NSError(domain: "未找到设备，配对超时", code: 2, userInfo: nil))
    }
    @objc private func pairSuccessed() {
        canclePair()
        SuccessBlock(deviceInfo)
    }
    private func pairSuccessed(configDict: [AnyHashable : Any]!) {
        print(configDict)        
        easylink_config.stopTransmitting()//停止扫描
        let tmpStr = ((configDict["C"] as AnyObject).objectAt(2).object(forKey: "C") as AnyObject).objectAt(3).object(forKey: "C") as! String
        if tmpStr.contains("/") {
            let strArr = tmpStr.components(separatedBy: "/")
            let tmpIdent=strArr[1].uppercased()  as NSString
            var identifier = tmpIdent.substring(to: 2)
            
            for i in 1...5 {
                let tmpstr = tmpIdent.substring(from: i*2) as NSString
                identifier=identifier+":"+tmpstr.substring(to: 2)
            }
            deviceInfo.deviceID=identifier
            deviceInfo.deviceMac=identifier
            deviceInfo.deviceType=strArr[0]
            pairSuccessed()            
        }
        else{
            activateDevice(configDict: configDict)
        }
        
    }
    var oznerBonjourDetail:OznerBonjourDetail!
    func activateDevice(configDict: [AnyHashable : Any]!) {
        let IPAddress = ((configDict["C"] as AnyObject).objectAt(1).object(forKey: "C") as AnyObject).objectAt(3).object(forKey: "C") as! String
        easylink_config.unInit()
        easylink_config = nil
        oznerBonjourDetail=nil
        sleep(5)
        let weakself = self
        
        oznerBonjourDetail=OznerBonjourDetail.init(IPAddress, block: { (deviceid) in
            if (deviceid?.contains("/"))! {
                let strArr = deviceid!.components(separatedBy: "/")
                let tmpIdent=strArr[1].uppercased()  as NSString
                var identifier = tmpIdent.substring(to: 2)
                for i in 1...5 {
                    let tmpstr = tmpIdent.substring(from: i*2) as NSString
                    identifier=identifier+":"+tmpstr.substring(to: 2)
                }
                weakself.deviceInfo.deviceID=identifier
                weakself.deviceInfo.deviceMac=identifier
                weakself.deviceInfo.deviceType=strArr[0]
                weakself.pairSuccessed()
            }
        })
        
    }
    //EasyLinkFTCDelegate 代理方法
    func onFound(_ client: NSNumber!, withName name: String!, mataData mataDataDict: [AnyHashable : Any]!) {
        print("=====onFoundwithName=====")
        print(mataDataDict)
        if let tmptype =  mataDataDict["FW"] as? String
        {
            switch deviceType {
            case OZDeviceClass.AirPurifier_Wifi:
                if tmptype=="FOG_HAOZE_AIR@" {
                    deviceInfo.productID="FOG_HAOZE_AIR"
                    self.pairSuccessed(configDict: mataDataDict)
                }
            case OZDeviceClass.WaterPurifier_Wifi:
                if tmptype=="MXCHIP_HAOZE_Water@" {
                    deviceInfo.productID="MXCHIP_HAOZE_Water"
                    self.pairSuccessed(configDict: mataDataDict)
                }
            default:
                break
            }
        }
        
        
    }
    func onFound(byFTC client: NSNumber!, withConfiguration configDict: [AnyHashable : Any]!) {
        print("=====onFoundwithConfiguration=====")
        print(configDict)
        if let tmptype =  configDict["FW"] as? String
        {
            switch deviceType {
            case OZDeviceClass.AirPurifier_Wifi:
                if tmptype=="FOG_HAOZE_AIR@" {
                    deviceInfo.productID="FOG_HAOZE_AIR"
                    self.pairSuccessed(configDict: configDict)
                }
            case OZDeviceClass.WaterPurifier_Wifi:
                if tmptype=="MXCHIP_HAOZE_Water@" {
                    deviceInfo.productID="MXCHIP_HAOZE_Water"
                    self.pairSuccessed(configDict: configDict)
                }
            default:
                break
            }
        }
        
    }
    func onDisconnect(fromFTC client: NSNumber!, withError err: Bool) {
        print("=====onDisconnect fromFTC=====")
    }
    
}