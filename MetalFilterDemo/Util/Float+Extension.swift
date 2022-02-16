//
//  Float+Extension.swift
//  3DCamera
//
//  Created by Zy on 2020/8/18.
//  Copyright © 2020 Zy. All rights reserved.
//

import UIKit

extension CGFloat {
    
    /// 屏幕宽度适配
    var dpW: CGFloat {
       return self * (Screen.width / 375.0)
    }
    
    
    /// 屏幕高度适配
    var dpH: CGFloat {
        return self * (Screen.height / 667.0)
    }
    
    var f: Float {
        return Float(self)
    }
    
    var intF: CGFloat {
        return CGFloat(Int64(self))
    }
    
    var to2f:CGFloat{
        return String(format: "%.2f", self).toCGFloat()
    }
}

extension Float {
    var cgF: CGFloat {
        return CGFloat(self)
    }
}
extension String {
    func toCGFloat() -> CGFloat {
        var cf : CGFloat = 0.0
        if let doubleValue = Double(self) {
            cf = CGFloat(doubleValue)
        }
        return cf
        
    }
    
    func toInt() -> Int {
        var cf : Int = 1
        if let doubleValue = Double(self) {
            cf = Int(doubleValue)
        }
        return cf
        
    }
}
