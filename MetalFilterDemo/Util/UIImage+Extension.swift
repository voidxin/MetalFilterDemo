//
//  UIImage+Extension.swift
//  3DCamera
//
//  Created by Zy on 2020/8/26.
//  Copyright © 2020 Zy. All rights reserved.
//

import UIKit

public extension UIImage {
    
    /// 根据颜色创建图片
    ///
    /// - Parameters:
    ///   - color: 图片颜色
    ///   - size: 图片尺寸
    class func image(color: UIColor, size: CGSize) -> UIImage {
        
        UIGraphicsBeginImageContext(size)
        let context = UIGraphicsGetCurrentContext()
        context?.setFillColor(color.cgColor)
        context?.fill(CGRect(origin: CGPoint.zero, size: size))
        
        guard let image = UIGraphicsGetImageFromCurrentImageContext()
            else {
                fatalError("Can not make a image by color")
        }
        UIGraphicsEndImageContext()
        return image
    }
    
    /// 重新绘制图像
    ///
    /// - Parameters:
    /// - imageSize: 图片尺寸
    /// - Returns: 绘制后的图像
    func imageWithResetSize(_ imageSize: CGSize) -> UIImage{
        //开启上下文
        UIGraphicsBeginImageContextWithOptions(imageSize, true, 0.0)
        self.draw(in: CGRect(origin: .zero, size: imageSize))
        
        guard let image = UIGraphicsGetImageFromCurrentImageContext() else {
            return self
        }
        //结束上下文
        UIGraphicsEndImageContext()
        return image
    }    
    
    /// 返回于屏幕同宽的等比例图片
    ///
    /// - Returns: 绘制后的图片
    func screenWidthImage() -> UIImage {
        let aHeight = size.height * Screen.width / size.width
        let aSize = CGSize(width: Screen.width, height: aHeight)
        return imageWithResetSize(aSize)
    }
    
    
    /// 图片大小不变的情况下，绘制对应Size的图片，填充黑色的
    /// - Parameter size: size
    /// - Returns: image
    func drawImageToSize(_ toSize:CGSize, fillColor:CGColor) -> UIImage {
        
        guard let imageRef = cgImage,
            let colorSpace = imageRef.colorSpace else {
            return self
        }
        let rect = CGRect(x: 0, y: 0, width: toSize.width, height: toSize.height)
        let imageRect = CGRect(x: (toSize.width - size.width)/2.0, y: (toSize.height - size.height)/2.0, width: size.width, height: size.height)
        
        
        
        guard let bitmap = CGContext(data: nil,
                                     width: Int(rect.width),
                                     height: Int(rect.height),
                                     bitsPerComponent: imageRef.bitsPerComponent,
                                     bytesPerRow: 0,
                                     space: colorSpace,
                                     bitmapInfo: imageRef.bitmapInfo.rawValue)
            else {
                return self
        }

        bitmap.interpolationQuality = .default
        //填充背景色为白色
        bitmap.setFillColor(fillColor)
        bitmap.fill(rect)
        
        //绘制图片
        bitmap.draw(imageRef, in: imageRect)
        guard let newImageRef = bitmap.makeImage() else {
            bitmap.flush()
            return self
        }
        
        let image = UIImage(cgImage: newImageRef)
        bitmap.flush()
        
        return image;
    }
    
    func fixOrientation() -> UIImage {
        
        guard let cgImage = cgImage else {
            return self
        }
        
        var transform = CGAffineTransform.identity
        
        switch self.imageOrientation {
        case .down , .downMirrored:
            transform = CGAffineTransform.identity.translatedBy(x: self.size.width, y: self.size.height)
            transform = CGAffineTransform.identity.rotated(by: CGFloat.pi)
            break
            
        case .left, .leftMirrored:
            transform = CGAffineTransform.identity.translatedBy(x: self.size.width, y: 0)
            transform = CGAffineTransform.identity.rotated(by: CGFloat.pi / 2)
            break
            
        case .right, .rightMirrored:
            transform = CGAffineTransform.identity.translatedBy(x:0 ,y: self.size.height)
            transform = CGAffineTransform.identity.rotated(by: -CGFloat.pi / 2)
            break
        default:
            break
        }
        
        switch (self.imageOrientation) {
        case .upMirrored, .downMirrored:
            transform = CGAffineTransform.identity.translatedBy(x: self.size.width, y: 0)
            transform = CGAffineTransform.identity.scaledBy(x: -1, y: 1)
            break;
            
        case .leftMirrored, .rightMirrored:
            transform = CGAffineTransform.identity.translatedBy(x:self.size.height,y: 0);
            transform = CGAffineTransform.identity.scaledBy(x: -1, y: 1)
            break;
        default:
            break
        }
        
        guard let colorSpace = cgImage.colorSpace else {
            return self
        }
        
        
        let context = CGContext(data: nil, width: Int(self.size.width), height: Int(self.size.height), bitsPerComponent: cgImage.bitsPerComponent, bytesPerRow: 0, space:colorSpace, bitmapInfo: cgImage.bitmapInfo.rawValue)
        
        context?.concatenate(transform)
        switch self.imageOrientation {
        case .left, .leftMirrored, .right, .rightMirrored:
            context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: self.size.height, height: self.size.width))
        default:
            context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: self.size.width, height: self.size.height))

        }
        
        guard let newCGImage = context?.makeImage() else {
            return self
        }
        
        let image = UIImage(cgImage: newCGImage)
        context?.flush()
        
        return image
    }
    
    /// 裁剪图像
    ///
    /// - Parameters:
    /// - imageSize: 图片尺寸
    /// - Returns: 绘制后的图像
    func imageWithClipSize(_ imageSize: CGSize) -> UIImage{
        //开启上下文
        UIGraphicsBeginImageContextWithOptions(imageSize, true, 0.0)
        
        let imgW = size.width
        let imgH = size.height
        let height = imageSize.height
        let width = imageSize.width
        let newH = (imgH * width / imgW).intF
        let newW = (imgW * height / imgH).intF
        
        var imgSize:CGSize
        if newH < height {
            imgSize = CGSize(width: newW, height: height)
        }else{
            imgSize = CGSize(width: width, height: newH)
        }
        
        let x = (width - imgSize.width) / 2.0
        let y = (height - imgSize.height) / 2.0

        self.draw(in: CGRect(origin: CGPoint(x: x, y: y), size: imgSize))
        
        guard let image = UIGraphicsGetImageFromCurrentImageContext() else {
            UIGraphicsEndImageContext()
            return self
        }
        //结束上下文
        UIGraphicsEndImageContext()
        return image
    }
    
    func imageWithClipRect(_ imageRect: CGRect) -> UIImage{
        UIGraphicsBeginImageContextWithOptions(imageRect.size, true, 0.0)
        
        self.draw(in:CGRect(origin: CGPoint(x: -imageRect.x, y: -imageRect.y), size: size))
        
        guard let image = UIGraphicsGetImageFromCurrentImageContext() else {
            return self
        }
        //结束上下文
        UIGraphicsEndImageContext()
        return image
    }
    
    func resetImageSize(_ reSize:CGSize) -> UIImage {
        
        let width = reSize.width
        let height = reSize.height
        
        let imgW = size.width
        let imgH = size.height
        
        let isWidth = (imgH / height <= imgW / width)
        
        var imgSize:CGSize
        if isWidth {
            let newH = (imgH * width / imgW).intF
            imgSize = CGSize(width: width, height: newH)
        }else{
            let newW = (imgW * height / imgH).intF
            imgSize = CGSize(width: newW, height: height)
        }
        let newImage = imageWithResetSize(imgSize)
        return newImage
    }
    
    func imageByApplying(alpha:CGFloat) -> UIImage {
        
        UIGraphicsBeginImageContextWithOptions(self.size, false, 0)
        guard let ctx = UIGraphicsGetCurrentContext(),
            let cgImg = self.cgImage else {
            return self
        }
        
        let area = CGRect(origin: CGPoint.zero, size: self.size)
        
        ctx.scaleBy(x: 1, y: -1)
        ctx.translateBy(x: 0, y: -area.size.height)
        ctx.setBlendMode(CGBlendMode.multiply)
        ctx.setAlpha(alpha)
        ctx.draw(cgImg, in: area)
        
        guard let newImage = UIGraphicsGetImageFromCurrentImageContext() else {
            return self
        }
        return newImage
    }
    
    
    /// 根据Rect重新生成图片，原图片尺寸不变
    /// - Parameter rect:
    func reset(in rect:CGRect)->UIImage{
        UIGraphicsBeginImageContext(rect.size)
        guard UIGraphicsGetCurrentContext() != nil else {
            UIGraphicsEndImageContext()
            return self
        }
        self.draw(in: CGRect(origin: rect.origin, size: size))
        guard let image = UIGraphicsGetImageFromCurrentImageContext() else{
            UIGraphicsEndImageContext()
            return self
        }
        UIGraphicsEndImageContext()
        return image
    }
    
    static func gradualImage(with startColor:CGColor,_ startPoint:CGPoint, _ endColor:CGColor,_ endPoint:CGPoint, _ size:CGSize)-> UIImage{
        UIGraphicsBeginImageContext(size)
        guard let context = UIGraphicsGetCurrentContext() else {
            return UIImage()
        }
        context.saveGState()
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let colors:CFArray = [startColor,endColor] as CFArray
        guard let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: nil) else {
            return UIImage()
        }
        
        let start = CGPoint(x: startPoint.x * size.width, y: startPoint.y * size.height)
        
        let end = CGPoint(x: endPoint.x * size.width, y: endPoint.y * size.height)
        context.drawLinearGradient(gradient, start: start, end: end, options: [.drawsBeforeStartLocation,.drawsAfterEndLocation])
        guard let image = UIGraphicsGetImageFromCurrentImageContext() else {
            return UIImage()
        }
        
        return image
    }
    
//    func newLinearBorderImage(size:CGSize) ->UIImage {
//        let image = self
//        let topPadding = CGFloat(Int((size.height - image.size.height) / 2.0))
//        let bottomPadding = size.height - topPadding - image.size.height
//        let leftPadding = CGFloat(Int((size.width - image.size.width) / 2.0))
//        let rightPadding = size.width - image.size.width - leftPadding
//        //调整顶部图片
//        let edgeInsets = UIEdgeInsets(top: topPadding, left: leftPadding, bottom:bottomPadding, right: rightPadding)
//        return SpecialEffectsImageRepairManager.copyImageBorder(image, edgInsets: edgeInsets)
//    }
    
    ///强制旋转，不判断方向
    func rotate(radians: CGFloat) -> UIImage {
        let rotatedSize = CGRect(origin: .zero, size: size)
            .applying(CGAffineTransform(rotationAngle: CGFloat(radians)))
            .integral.size
        UIGraphicsBeginImageContext(rotatedSize)
        if let context = UIGraphicsGetCurrentContext() {
            let origin = CGPoint(x: rotatedSize.width / 2.0,
                                 y: rotatedSize.height / 2.0)
            context.translateBy(x: origin.x, y: origin.y)
            context.rotate(by: radians)
            draw(in: CGRect(x: -origin.y, y: -origin.x,
                            width: size.width, height: size.height))
            let rotatedImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()

            return rotatedImage ?? self
        }

        return self
    }
}
extension UIImage {

    func geteffectScaledImage(cropSize: CGSize) -> UIImage{
        var redioW = self.size.width / cropSize.width
        let redioH = self.size.height / cropSize.height
        if redioW < redioH {
            redioW = redioH
        }
        let newCropSize = CGSize.init(width: cropSize.width * redioW, height: cropSize.height * redioW)
        return self.effectScaled(to: newCropSize)
    }
    //将图片缩放成指定尺寸（多余部分自动删除）
    func effectScaled(to newSize: CGSize) -> UIImage {
        //计算比例
        let aspectWidth  = newSize.width/size.width
        let aspectHeight = newSize.height/size.height
        let aspectRatio = max(aspectWidth, aspectHeight)
        
        //图片绘制区域
        var scaledImageRect = CGRect.zero
        scaledImageRect.size.width  = size.width * aspectRatio
        scaledImageRect.size.height = size.height * aspectRatio
        scaledImageRect.origin.x    = (newSize.width - size.width * aspectRatio) / 2.0
        scaledImageRect.origin.y    = (newSize.height - size.height * aspectRatio) / 2.0
        
        //绘制并获取最终图片
        UIGraphicsBeginImageContext(newSize)
        draw(in: scaledImageRect)
        let scaledImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return scaledImage!
    }
    
}

