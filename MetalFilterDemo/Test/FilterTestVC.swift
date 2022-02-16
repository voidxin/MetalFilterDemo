//
//  FilterTestVC.swift
//  3DCamera
//
//  Created by zhangxin on 2020/11/5.
//  Copyright © 2020 Zy. All rights reserved.
//

import UIKit

class FilterTestVC: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let rect = CGRect(x: (Device.screenWidth - 425) * 0.5, y: (Device.screenHeight - 386) * 0.5, width: 425, height: 386)
//        let imageView = UIImageView()
//        imageView.frame = rect
//        self.view.addSubview(imageView)
        

        let filterModel = FilterAndFixModel()
        filterModel.method = "1_0" //"2_0"
        filterModel.mixmode = "OverlayBlend"
        filterModel.image = UIImage.init(named: "light_leak")
        filterModel.filter = UIImage.init(named: "zx_test")
        let testView = FilterContentView.init(frame:rect , UIImage.init(named: "FilterTargetImage")!, filterModel)
//        testView.completeCallBack = {
//            [weak self,weak imageView] (resultImage) in
//            DispatchQueue.main.async {
//                imageView?.image = resultImage
//
//            }
//        }
        testView.isHidden = false
        self.view.addSubview(testView)
        
        
//                let image = UIImage.init(named: "FilterTargetImage")!
//                let width = view.bounds.size.width
//                let height = image.size.height *  view.bounds.size.width / image.size.width
//                let rect = CGRect.init(x: 0, y: (view.bounds.height - height) / 2, width: width, height: height)
//                let v = RGBSeparateFilterView.init(frame: rect, originalImage: image)
//                self.view.addSubview(v)
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
