//
//  ViewController.swift
//  MetalFilterDemo
//
//  Created by zhangxin on 2020/12/22.
//

import UIKit

class ViewController: UIViewController {

   
    override func viewDidLoad() {
        super.viewDidLoad()
        
    }
    @IBAction func nextPageAction(_ sender: Any) {
        let testVC = FilterTestVC()
        testVC.modalPresentationStyle = .fullScreen
        self.present(testVC, animated: true, completion: nil)
    }


}

