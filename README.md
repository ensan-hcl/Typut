# What is this?

This is a sample implementation of IMKit App with Swift/SwiftUI.

## Working Environment

* macOS 11.5
* Swift 5.5
* Xcode13 (beta)

## Procedure to make project

* Create new project. Bundle Identifier must contain `.inputmethod.` part in the String.
* Run.

* Add Swift files `AppDelegate.swift` and `IMKitSampleInputController.swift`.

  ```swift
  // AppDelegate.swift
  import Cocoa
  import InputMethodKit
  
  class AppDelegate: NSObject, NSApplicationDelegate {
      var server = IMKServer()
      var candidatesWindow = IMKCandidates()
  
      func applicationDidFinishLaunching(_ notification: Notification) {
          // Insert code here to initialize your application
          server = IMKServer(name: Bundle.main.infoDictionary?["InputMethodConnectionName"] as? String, bundleIdentifier: Bundle.main.bundleIdentifier)
          candidatesWindow = IMKCandidates(server: server, panelType: kIMKSingleRowSteppingCandidatePanel, styleType: kIMKMain)
          NSLog("tried connection")
      }
  
      func applicationWillTerminate(_ notification: Notification) {
          // Insert code here to tear down your application
      }
  }
  ```

  ```swift
  // IMKitSampleInputController.swift
  import Cocoa
  import InputMethodKit
  
  @objc(IMKitSampleInputController)
  class IMKitSampleInputController: IMKInputController {
      override func inputText(_ string: String!, client sender: Any!) -> Bool {
          NSLog(string)
          // get client to insert
          guard let client = sender as? IMKTextInput else {
              return false
          }
          client.insertText(string+string, replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
          return true
      }
  }
  ```

* Modify `IMKitSampleApp`.

  ```swift
  // IMKitSampleApp.swift
  import SwiftUI
  
  @main
  struct IMKitSampleApp: App {
      @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
      var body: some Scene {
          WindowGroup {
              ContentView()
          }
      }
  }
  ```

* Add icon file `main.tiff`.

* Modify Info.plist

  ```
  key: NSPrincipalClass  type: _  value: NSApplication
  key: InputMethodConnectionName  type: String  value: $(PRODUCT_BUNDLE_IDENTIFIER)_Connection
  key: InputMethodServerControllerClass  type: String  value: $(PRODUCT_MODULE_NAME).IMKitSampleInputController
  key: Application is background only  type: Boolean  value: YES
  key: tsInputMethodCharacterRepertoireKey  type: Array  value: [item0: String = Latn]
  key: tsInputMethodIconFileKey  type: String  value: main.tiff
  ```

* Add entitlements

  * Go **Signing & Capabilities** → **+Capability** → **App Sandbox**

  * Go IMKitSample.entitlements, add 

    ```
    key: com.apple.security.temporary-exception.mach-register.global-name
    type: String
    value: $(PRODUCT_BUNDLE_IDENTIFIER)_Connection
    ```

* Do `sudo chmod -R 777 /Library/Input\ Methods` on terminal.
* Modify build settings.
  * Go **Build Locations** → **Build Products Path** of debug → value ``/Library/Input Methods`
  * Go **+** → **Add User-Defined Setting** → Set key `CONFIGURATION_BUILD_DIR`, value `/Library/Input Methods`.
  * !!! DO NOT edit thinklessly, this setting is really fragile.

* Try Run.

## Trouble Shooting

*I'm not expert of macOS. Please don't ask too much, I don't know either. It's just my experience.*

* InputMethods says **connection \*\*Failed\*\*** all though there are no diff!
  * Open 'Activity Monitor' app, search the name of your InputMethods, and kill the process. Then try again.

* `print()` doesn't work!
  * Use `NSLog()`.

* App doesn't run!
  * Check the path of build product file. If it isn't at `/Library/Input Methods/...`, some thing went wrong.
  * Maybe build setting went wrong. Check the settings. Especially, if `CONFIGURATION_BUILD_DIR="";` found, remove the line.

## Reference

Thanks to authors!!

* https://mzp.hatenablog.com/entry/2017/09/17/220320
* https://www.logcg.com/en/archives/2078.html
* https://stackoverflow.com/questions/27813151/how-to-develop-a-simple-input-method-for-mac-os-x-in-swift