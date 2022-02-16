//
//  FilterAndFixModel.swift
//  3DCamera
//
//  Created by zhangxin on 2020/11/6.
//  Copyright © 2020 Zy. All rights reserved.
//

import UIKit

class FilterAndFixModel: NSObject {
    var image : UIImage? //静态图名称
    var vagueImage : UIImage? //噪点图
    var filter : UIImage? //色卡名称
    var control : Int = 0  //控制方式：1为先加滤镜后加静态图，2位先静态图后滤镜
    var mixmode : String? //混合模式，若无则配null
    var method : String? //0_1 实现方式，0为滤镜色卡，1为静态图，2为rgb分离，支持多种实现方式
    var parts : [[String:CGFloat]]?
    
    //当前rgb分离的百分比
    var currentPercent : CGFloat? = 0
}
