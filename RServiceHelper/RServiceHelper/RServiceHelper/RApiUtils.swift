//
//  RApiUtils.swift
//  RServiceHelper
//
//  Created by rajkumar.sharma on 02/08/18.
//  Copyright © 2018 R World. All rights reserved.
//

import UIKit

//Public constants

let APPDELEGATE = UIApplication.shared.delegate as! AppDelegate

class RApiUtils: NSObject {

}

class RNetworkConfig: NSObject {
    
    static let instance = RNetworkConfig()
    var isReachable = false

    class func config() {
        
    }
}

// Logger for debug

final class Debug {
    
    static var isEnabled = true

    static func log(_ msg: @autoclosure () -> String = "", _ file: @autoclosure () -> String = #file, _ line: @autoclosure () -> Int = #line, _ function: @autoclosure () -> String = #function) {
        if isEnabled {
            let fileName = file().components(separatedBy: "/").last ?? ""
            print("\n<======================[Debug]======================>\n")
            print("[File: \(fileName)] [line: \(line())]\n[Function: \(function())]\n\(msg())")
            //print(["\(fileName):\(line())]🍀🍀🍀: \(function()) \(msg())")
        }
    }
}

class RConstants: NSObject {
    
    class var netError: OurErrorProtocol {
        return CustomError(title: "Connection Error!", description: "Internet connection appears to be offline. Please check your internet connection.", code: 9999)
    }
}

extension UIApplication {
    
    class func setupReachability() {
        // Allocate a reachability object
        let reach = Reachability.forInternetConnection()
        RNetworkConfig.instance.isReachable = reach!.isReachable()
        
        // Set the blocks
        reach?.reachableBlock = { (reachability) in
            
            DispatchQueue.main.async(execute: {
                RNetworkConfig.instance.isReachable = true
            })
        }
        reach?.unreachableBlock = { (reachability) in
            DispatchQueue.main.async(execute: {
                RNetworkConfig.instance.isReachable = false
            })
        }
        reach?.startNotifier()
    }
}
