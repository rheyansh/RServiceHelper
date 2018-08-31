# Under development

# RServiceHelper
RServiceHelper is an helper class for making client-server communication easy and facilitating various api methods, multipart upload, basic authentication, access parameters and many others.

### Set up RServiceHelper

* Configure RServiceConfigModal as:

        var config = RServiceConfigModal()
        config.baseUrl = "base url of your end point"
        
        // leave if there is no basic authentication -- start
        config.basicAuthUserName = "admin"
        config.basicAuthPassword = "zzzzzzzz"
        // leave if there is no basic authentication -- end
        
        RServiceHelper.config(configModal: config)

### Request an end point

      RServiceHelper.request(method: .get, apiName: "getList") { (result) in
            
            if let error = result.error {
                print("Error on api call: \(error)")
                return
            }
            
            print("Result data: \(result.httpCode)")
            print("Result data: \(String(describing: result.data))")
        }
        
        RServiceHelper.request(params: ["key1" : "value"], method: .post, apiName: "auth") { (result) in
            if let error = result.error {
                print("Error on api call: \(error)")
                return
            }
            
            print("Result data: \(result.httpCode)")
            print("Result data: \(String(describing: result.data))")
        }     
        
        
# Author   

* [Raj Sharma](https://github.com/rheyansh)
* [Web](http://rajsharma.online/)

## Communication

* If you **found a bug**, open an issue.
* If you **want to contribute**, submit a pull request.

# License
RServiceHelper is available under the MIT license. See the LICENSE file for more info.
