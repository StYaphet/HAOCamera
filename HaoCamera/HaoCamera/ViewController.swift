//
//  ViewController.swift
//  HaoCamera
//
//  Created by Me55a on 2020/10/19.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        let label = UILabel(frame: .zero)
        label.text = "Hello, HAOCamera!"
        label.sizeToFit()
        label.center = self.view.center
        self.view.addSubview(label)
    }

    override func viewDidAppear(_ animated: Bool) {
        HAOAuthorizationUtils.requestCameraAuthorization { (granted) in
            print("Camera \(granted ? "granted" : "not granted")")
        }
        
        HAOAuthorizationUtils.requestMicphoneAuthorization { (granted) in
            print("Micphone \(granted ? "granted" : "not granted")")
        }
    }
}

