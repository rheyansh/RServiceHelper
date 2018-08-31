//
//  RServiceHelper.swift
//  RServiceHelper
//
//  Created by rajkumar.sharma on 02/08/18.
//  Copyright © 2018 R World. All rights reserved.
//

import UIKit

import UIKit
import MobileCoreServices


let unknownHTTPCode: Int = 9999
let internetConnErrorCode: Int = 1002

struct RMultiPartKey {
    
    static let data = "data"
    static let fileType = "fileType"
    static let field = "keyAtServerSide"
    static let filePath = "filePath"
    static let typeVideo = "video"
    static let typeAudio = "audio"
    static let typeImage = "image"
}

enum loadingIndicatorType: CGFloat {
    
    case iLoader  = 0 // interactive loader => showing indicator + user interaction on UI will be enable
    case withoutLoader  = 1 // Actually no loader will be loaded => hiding indicator + user interaction on UI will be disable
}

enum MethodType: CGFloat {
    case get  = 0
    case post  = 1
    case put  = 2
    case delete  = 3
    case patch  = 4
}

struct RServiceResult {
    
    var error: Error?
    var data: Any?
    var httpURLResponse: HTTPURLResponse?
    var httpCode: Int!
}

class RServiceHelper: NSObject {
    
    //MARK:- Public Functions >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
    
    class func config(configModal: RServiceConfigModal) {
        RServiceConfig.instance.config = configModal
    }
    
    private class func getBaseRequest(params: [String: Any],
                              method: MethodType,
                              apiName: String,
                              headers: [String: String]) -> URLRequest {
        let url = requestURL(method, apiName: apiName, parameterDict: params)
        var request = URLRequest(url: url)
        request.httpMethod = methodName(method)
        
        request.addBasicAuth()

        headers.forEach { (pair) in
            request.setValue(pair.value, forHTTPHeaderField: pair.key)
        }
        
        let serviceConfig = RServiceConfig.instance.config
        
        if let globalHeaders = serviceConfig?.globalHeaders {
            globalHeaders.forEach { (pair) in
                request.setValue(pair.value, forHTTPHeaderField: pair.key)
            }
        }
        
        Debug.log("\n\n Request URL  >>>>>>\(url)")
        Debug.log("\n\n Request Header >>>>>> \n\(request.allHTTPHeaderFields.debugDescription)")
        Debug.log("\n\n Request Parameters >>>>>>\n\(params.toJsonString())")
        //Debug.log("\n\n Request Body  >>>>>>\(request.HTTPBody)")
    
        return request
    }
    
    class func request(params: [String: Any] = [:],
                       method: MethodType,
                       apiName: String,
                       headers: [String: String] = [:],
                       hudType: loadingIndicatorType = .iLoader,
                       callBack: ((RServiceResult)->())?) {
        
        var request = getBaseRequest(params: params, method: method, apiName: apiName, headers: headers)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = RServiceConfig.instance.config.timeoutInterval

        let jsonData = body(method, parameterDict: params)
        Debug.log("Content-Length >>> \(String (jsonData.count))")

        request.httpBody = jsonData
        request.perform(hudType: hudType, callBack: callBack)
    }
    
    //@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@//
    
    class func multiPartRequest(params: [String: Any],
                                method: MethodType,
                                apiName: String,
                                headers: [String: String] = [:],
                                hudType: loadingIndicatorType = .iLoader,
                                mediaArray: Array<Dictionary<String, AnyObject>>,
                                isUsingFilePathUpload: Bool,
                                callBack: ((RServiceResult)->())?) {
        
        var request = getBaseRequest(params: params, method: method, apiName: apiName, headers: headers)
        
        let boundary = self.generateBoundaryString()
        let contentType = "multipart/form-data; boundary=\(boundary)"
        
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        
        if (isUsingFilePathUpload) {
            request.httpBody = RServiceHelper.createBodyWithBoundary(boundary: boundary, parameters: params, paths: mediaArray)
        } else {
            request.httpBody = RServiceHelper.createBodyWithBoundary(boundary: boundary, parameters: params, mediaArray: mediaArray)
        }
        request.perform(hudType: hudType, callBack: callBack)
    }
    
    /// Create boundary string for multipart/form-data request
    ///
    /// - returns:            The boundary string that consists of "Boundary-" followed by a UUID string.
    
    class private func generateBoundaryString() -> String {
        let boundary = "Boundary-" + UUID().uuidString
        return boundary
    }
    
    /// Create body of the multipart/form-data request
    ///
    /// - parameter parameters:   The optional dictionary containing keys and values to be passed to web service
    /// - parameter filePathKey:  The optional field name to be used when uploading files. If you supply paths, you must supply filePathKey, too.
    /// - parameter paths:        The optional array of file paths of the files to be uploaded
    /// - parameter boundary:     The multipart/form-data boundary
    ///
    /// - returns:                The NSData of the body of the request
    
    class private func createBodyWithBoundary(boundary: String, parameters: [String: Any], paths: Array<Dictionary<String, AnyObject>>) -> Data {
        
        var httpBody = Data()
        
        for (parameterKey, parameterValue) in parameters.enumerated() {
            
            // add params (all params are strings)
            
            httpBody.append("--\(boundary)\r\n")
            httpBody.append("Content-Disposition: form-data; name=\"\(parameterKey)\"\r\n\r\n")
            httpBody.append("\(parameterValue)\r\n")
        }
        
        // add file data
        
        for pathInfo in paths {
            
            guard let filePath = pathInfo[RMultiPartKey.filePath] as? String,
                let fieldName = pathInfo[RMultiPartKey.field] as? String else {
                    return httpBody
            }
            
            let url = URL(fileURLWithPath: filePath)
            let filename = url.lastPathComponent
            let mimetype = mimeTypeForPath(for: filePath)
            
            httpBody.append("--\(boundary)\r\n")
            httpBody.append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(filename)\"\r\n")
            httpBody.append("Content-Type: \(mimetype)\r\n\r\n")
            
            do {
                let data = try Data(contentsOf: url)
                httpBody.append(data)

            } catch {
                print(error)
            }
            
            httpBody.append("\r\n")
        }
        
        httpBody.append("--\(boundary)--\r\n")
        
        //Debug.log("\(httpBody.count)")
        
        return httpBody
    }
    
    class private func createBodyWithBoundary(boundary: String, parameters: [String: Any], mediaArray: Array<Dictionary<String, AnyObject>>) -> Data {
        
        var httpBody = Data()
        
        for (parameterKey, parameterValue) in parameters.enumerated() {
            
            // add params (all params are strings)
            
            httpBody.append("--\(boundary)\r\n")
            httpBody.append("Content-Disposition: form-data; name=\"\(parameterKey)\"\r\n\r\n")
            httpBody.append("\(parameterValue)\r\n")
        }
        
        // add media data
        
        for mediaInfo in mediaArray {
            
            guard let fieldName = mediaInfo[RMultiPartKey.field] as? String,
                let data = mediaInfo[RMultiPartKey.data] as? Data else {
                    return httpBody
            }
            
            var fileType = ""
            var mimetype = data.mimeType
            
            if let type = mediaInfo[RMultiPartKey.fileType] as? String {
                fileType = type
            }
            
            // Get the Unix timestamp
            let timestamp = NSDate().timeIntervalSince1970
            var filename = "\(timestamp)"
            
            if fileType == RMultiPartKey.typeVideo {
                filename  = filename + "_video.mp4"
                mimetype = "video/mp4";
            } else if fileType == RMultiPartKey.typeAudio {
                filename  = filename + "_audio.m4a"
                mimetype = "audio/m4a";
            } else {
                filename  = filename + "_image.png"
            }
            
            httpBody.append("--\(boundary)\r\n")
            httpBody.append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(filename)\"\r\n")
            httpBody.append("Content-Type: \(mimetype)\r\n\r\n")
            httpBody.append(data)
            httpBody.append("\r\n")
        }
        
        httpBody.append("--\(boundary)--\r\n")
        
        //Debug.log("\(httpBody.count)")
        
        return httpBody
    }
    
    /// Determine mime type on the basis of extension of a file.
    ///
    /// This requires MobileCoreServices framework.
    ///
    /// - parameter path:         The path of the file for which we are going to determine the mime type.
    ///
    /// - returns:                Returns the mime type if successful. Returns application/octet-stream if unable to determine mime type.
    
    class private func mimeTypeForPath(for path: String) -> String {
        
        let url = NSURL(fileURLWithPath: path)
        let pathExtension = url.pathExtension
        
        if let uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, pathExtension! as NSString, nil)?.takeRetainedValue() {
            if let mimetype = UTTypeCopyPreferredTagWithClass(uti, kUTTagClassMIMEType)?.takeRetainedValue() {
                return mimetype as String
            }
        }
        return "application/octet-stream";
    }
    
    //MARK:- Private Functions >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
    
    class fileprivate func methodName(_ method: MethodType)-> String {
        
        switch method {
        case .get: return "GET"
        case .post: return "POST"
        case .delete: return "DELETE"
        case .put: return "PUT"
        case .patch: return "PATCH"
            
        }
    }
    
    class fileprivate func body(_ method: MethodType, parameterDict: [String: Any]) -> Data {
        
        // Create json with your parameters
        switch method {
        case .post: fallthrough
        case .patch: fallthrough
        case .put: return parameterDict.toData()
        case .get: fallthrough
            
        default: return Data()
        }
    }
    
    class fileprivate func requestURL(_ method: MethodType, apiName: String, parameterDict: [String: Any]) -> URL {
        let urlString = RServiceConfig.instance.config.baseUrl + apiName
        
        switch method {
        case .get:
            return getURL(apiName, parameterDict: parameterDict)
            
        case .post: fallthrough
        case .put: fallthrough
        case .patch: fallthrough
            
        default: return URL(string: urlString)!
        }
    }
    
    class fileprivate func getURL(_ apiName: String, parameterDict: [String: Any]) -> URL {
        
        var urlString = RServiceConfig.instance.config.baseUrl + apiName
        var isFirst = true
        
        for key in parameterDict.keys {
            
            let object = parameterDict[key]
            
            if object is NSArray {
                
                let array = object as! NSArray
                for eachObject in array {
                    var appendedStr = "&"
                    if (isFirst == true) {
                        appendedStr = "?"
                    }
                    urlString += appendedStr + (key) + "=" + (eachObject as! String)
                    isFirst = false
                }
                
            } else {
                var appendedStr = "&"
                if (isFirst == true) {
                    appendedStr = "?"
                }
                let parameterStr = parameterDict[key] as! String
                urlString += appendedStr + (key) + "=" + parameterStr
            }
            
            isFirst = false
        }
        
        let strUrl = urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        
        //let strUrl = urlString.addingPercentEscapes(using: String.Encoding.utf8)
        
        return URL(string:strUrl!)!
    }
    
    class func hideAllHuds(_ status: Bool, type: loadingIndicatorType) {
        //UIApplication.sharedApplication().networkActivityIndicatorVisible = !status
        
        if (type == .withoutLoader) {
            return
        }
        
        DispatchQueue.main.async(execute: {
            var hud = MBProgressHUD(for: APPDELEGATE.window!)
            if hud == nil {
                hud = MBProgressHUD.showAdded(to: APPDELEGATE.window!, animated: true)
            }
            hud?.bezelView.layer.cornerRadius = 8.0
            hud?.bezelView.color = UIColor(red: 222/225.0, green: 222/225.0, blue: 222/225.0, alpha: 222/225.0)
            hud?.margin = 12
            //hud?.activityIndicatorColor = UIColor.white
            
            if (status == false) {
                if (type  == .withoutLoader) {
                    // do nothing
                } else {
                    hud?.show(animated: true)
                }
            } else {
                hud?.hide(animated: true, afterDelay: 0.3)
            }
        })
    }
}

extension URLRequest  {
    
    mutating func addBasicAuth() {
        
        let serviceConfig = RServiceConfig.instance.config
        guard let basicAuthUserName = serviceConfig?.basicAuthUserName,
            let basicAuthPassword = serviceConfig?.basicAuthPassword else {return}

        let authStr = basicAuthUserName + ":" + basicAuthPassword
        let authData = authStr.data(using: .ascii)
        let authValue = "Basic " + (authData?.base64EncodedString(options: .lineLength64Characters))!
        self.setValue(authValue, forHTTPHeaderField: "Authorization")
    }
    
    func perform(hudType: loadingIndicatorType, callBack: ((RServiceResult)->())?) -> Void {
        
        var result  = RServiceResult()
        
        if (RNetworkConfig.instance.isReachable == false) {
            result.error = RConstants.netError
            result.httpCode = internetConnErrorCode
            callBack?(result)
            return
        }
        
        RServiceHelper.hideAllHuds(false, type: hudType)
        
        let config = URLSessionConfiguration.default // Session Configuration
        let session = URLSession(configuration: config) // Load configuration into Session
        //var session = URLSession(configuration: configuration, delegate: nil, delegateQueue: nil)
        
        let task = session.dataTask(with: self, completionHandler: {
            (data, response, error) in
            
            RServiceHelper.hideAllHuds(true, type: hudType)
            
            result.error = error
            result.httpCode = unknownHTTPCode
            
            if let httpResponse = response as? HTTPURLResponse {
                result.httpCode = httpResponse.statusCode
                result.httpURLResponse = httpResponse
                
                //let responseHeaderDict = httpResponse.allHeaderFields
                //Debug.log("\n\n Response Header >>>>>> \n\(responseHeaderDict.debugDescription)")
                Debug.log("Response Code : \(result.httpCode))")
                
                if let responseString = NSString.init(data: data!, encoding: String.Encoding.utf8.rawValue) {
                    Debug.log("Response String : \n \(responseString)")
                }
                
                /*// 4. Parse the returned information
                let decoder = JSONDecoder()
                
                guard let data = data,
                    let response = try? decoder.decode(PriceResponse.self,
                                                       from: data) else { return }
                
                print("Price returned: \(response.data.amount)")*/
                do {
                    let resultData = try JSONSerialization.jsonObject(with: data!, options: JSONSerialization.ReadingOptions.mutableContainers)
                    //Debug.log("\n\n result  >>>>>>\n\(resultData)")
                    result.data = resultData
                } catch {
                    result.error = error
                    Debug.log("\n\n error in JSONSerialization")
                    Debug.log("\n\n error  >>>>>>\n\(error)")
                }
            }
            
            DispatchQueue.main.async {
                callBack?(result)
            }
        })
        
        task.resume()
    }
}

extension NSDictionary {
    func toData() -> Data {
        return try! JSONSerialization.data(withJSONObject: self, options: [])
    }
    
    func toJsonString() -> String {
        let jsonData = try! JSONSerialization.data(withJSONObject: self, options: JSONSerialization.WritingOptions.prettyPrinted)
        let jsonString = NSString(data: jsonData, encoding: String.Encoding.utf8.rawValue)! as String
        return jsonString
    }
}

extension Dictionary {
    
    func toData() -> Data {
        return try! JSONSerialization.data(withJSONObject: self, options: [])
    }
    
    func toJsonString() -> String {
        let jsonData = try! JSONSerialization.data(withJSONObject: self, options: JSONSerialization.WritingOptions.prettyPrinted)
        let jsonString = NSString(data: jsonData, encoding: String.Encoding.utf8.rawValue)! as String
        return jsonString
    }
}

extension Data {
    
    /// Append string to NSMutableData
    ///
    /// Rather than littering my code with calls to `dataUsingEncoding` to convert strings to NSData, and then add that data to the NSMutableData, this wraps it in a nice convenient little extension to NSMutableData. This converts using UTF-8.
    ///
    /// - parameter string:       The string to be added to the `NSMutableData`.
    
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
    
    private static let mimeTypeSignatures: [UInt8 : String] = [
        0xFF : "image/jpeg",
        0x89 : "image/png",
        0x47 : "image/gif",
        0x49 : "image/tiff",
        0x4D : "image/tiff",
        0x25 : "application/pdf",
        0xD0 : "application/vnd",
        0x46 : "text/plain",
        ]
    
    var mimeType: String {
        var c: UInt8 = 0
        copyBytes(to: &c, count: 1)
        return Data.mimeTypeSignatures[c] ?? "application/octet-stream"
    }
}

func resolutionScale() -> CGFloat {
    return UIScreen.main.scale
}

struct RServiceConfigModal {
    
    var baseUrl: String!
    
    //@@ Basic auth crediantials
    var basicAuthUserName: String?
    var basicAuthPassword: String?
    var timeoutInterval: Double = 45
    
    var globalHeaders: [String: String]?
    
    //@@ Access token
    var accessToken_Key: String?
    var accessToken_Value: String?
}

class RServiceConfig {
    
    static let instance = RServiceConfig()
    var config: RServiceConfigModal!
    
    init() {}
    init (config: RServiceConfigModal) { self.config = config }
    
    private var loaderCount: Int = 0 {
        
        didSet {
            
            if loaderCount < 1 {
                
            }
            
        }
    }
    
    func updateLoaderCount(count: Int) {
        loaderCount = count + loaderCount
    }
}


