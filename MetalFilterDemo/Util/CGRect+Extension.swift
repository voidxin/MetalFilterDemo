//
//  CGRect+Extension.swift
//  3DCamera
//
//  Created by Zy on 2020/8/17.
//  Copyright © 2020 Zy. All rights reserved.
//

import UIKit
public extension CGRect {
    
    var x: CGFloat {
        get {
            return origin.x
        }
        
        set {
            origin.x = newValue
        }
    }
    
    var y: CGFloat {
        get {
            return origin.y
        }
        
        set {
            origin.y = newValue
        }
    }
    
    
    var width: CGFloat {
        get {
            return size.width
        }
        
        set {
            size.width = newValue
        }
    }
    
    
    var height: CGFloat {
        get {
            return size.height
        }
        
        set {
            size.height = newValue
        }
    }
    
    
    var center: CGPoint {
        get {
            return  CGPoint(x: x + width/2, y: y + height/2)
        }
        
        set {
            origin.x = newValue.x - width/2
            origin.y = newValue.y - height/2
        }
    }

    
    var centerX: CGFloat {
        get {
            return  center.x
        }
        
        set {
            origin.x = newValue - width/2
        }
    }
    
    var centerY: CGFloat {
        get {
            return  center.y
        }
        
        set {
            origin.y = newValue - height/2
        }
    }

}
