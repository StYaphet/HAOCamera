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


}

