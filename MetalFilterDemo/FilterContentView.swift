//
//  FilterContentView.swift
//  3DCamera
//
//  Created by zhangxin on 2020/11/5.
//  Copyright © 2020 Zy. All rights reserved.
//

import UIKit
import MetalKit
import simd
import Accelerate

class FilterContentView: UIView ,MTKViewDelegate{
    //用来渲染的设备 又名GPU
    var device: MTLDevice? = MTLCreateSystemDefaultDevice()
    var mtkView : MTKView!
    //渲染管道有定点着色器和片元着色器  它们存储在.metal shader中
    var pipelineState: MTLRenderPipelineState!
    
    //命令队列 从命令缓冲区获取
    var commandQueue: MTLCommandQueue!
    
    //metal纹理对象
    var outputTexture: MTLTexture!
    var textTexture: MTLTexture!
    //metal纹理对象
    var textTexture2: MTLTexture!
    //metal纹理对象
    var textTexture3: MTLTexture!
    //第二层叠加图纹理
    var textTexture4: MTLTexture!

    //存储在Metal Buffer顶点数据
    var vertexBuffer: MTLBuffer!
    //索引缓存区
    var indexs : MTLBuffer!
    var uniformBuffer: MTLBuffer?
    //用于控制是否需要设置噪点图
    var vagueLogicBuffer : MTLBuffer?
    //用于控制混合模式的参数
    var mixLogicBuffer : MTLBuffer?
    //1.0表示先静态图再rgb分离，其他，表示先rgb分离再加静态图
    var mixRgbOrderLogicBuffer : MTLBuffer?
    //顶点个数
    var numVertices: NSInteger!
    //当前视图大小
    var viewportSize: vector_uint2?
    var filterModel:FilterAndFixModel?
    var originImage : UIImage!
    var filterResultImage : UIImage?
    var separateDistances:Array<MTLBuffer?> = Array()
    var parts : [[String:CGFloat]]?
    //未裁剪和翻转的图片（最后返回到视图时需要裁剪并翻转）
    var resultImageT : UIImage?
    
    deinit {
        print("FilterContentView被释放")
    }
        
    init(frame: CGRect, _ originalImage: UIImage,_ filterModel:FilterAndFixModel) {
        //frame+0.5取整。保证结果图没有白边
        let frameT = CGRect(x: Int(frame.origin.x + 0.5), y: Int(frame.origin.y + 0.5), width: Int(frame.size.width + 0.5), height: Int(frame.size.height + 0.5))
        super.init(frame: frameT)
        self.mtkView = MTKView.init(frame:self.bounds)
        self.mtkView.device = self.device
        self.addSubview(self.mtkView)
        self.mtkView.delegate = self
        self.viewportSize = vector_uint2.init(UInt32(self.mtkView.bounds.size.width), UInt32(self.mtkView.bounds.size.height))
        self.mtkView.presentsWithTransaction = false
        self.mtkView.framebufferOnly = false
        self.updateRander(originalImage, filterModel)
        
    }
    //非初始化时外部调用(重新渲染）
    public func updateRander(_ originalImage: UIImage,_ filterModel:FilterAndFixModel) {
        self.separateDistances.removeAll()
        self.uniformBuffer = nil
        self.viewportSize = nil
        self.filterModel = nil
        self.parts = nil
        self.resultImageT = nil
        self.outputTexture = nil
        self.vagueLogicBuffer = nil
        self.mixLogicBuffer = nil
        self.mixRgbOrderLogicBuffer = nil
        
        
        device = MTLCreateSystemDefaultDevice()
        //图片要进行裁剪，不然太大会crash
        let sizeT = frame.size
        self.filterModel = filterModel
        self.originImage = originalImage.imageWithResetSize(sizeT)
        self.parts = filterModel.parts
        self.filterHander()
    }
    
    func setUniformBuffer(_ partArray: [Dictionary<String, CGFloat>]?) {
        if partArray == nil {
            for _ in 1 ... 9 {
                var defaultUniformOrder = RGBSeparateDistance.init(rgbDistance: vector_float3.init(x: 0.0, y: 0.0, z: 0.0), textureCoordinateRange: vector_float2.init(x: 0.0, y: 0.0));
                let defaultUniformBuffer = mtkView.device?.makeBuffer(bytes: &defaultUniformOrder, length: MemoryLayout<(RGBSeparateDistance)>.size, options: .storageModeShared)
                separateDistances.append(defaultUniformBuffer)
            }
            return
        }
        for info in partArray! {
            //默认效果百分比0.8
            let r_distance = (info["r_distance"] ?? 0.0) * 0.8
            let g_distance = (info["g_distance"] ?? 0.0) * 0.8
            let b_distance = (info["b_distance"] ?? 0.0) * 0.8
           
            let minY = info["minY"]  ?? 0.0
            let maxY = info["maxY"]  ?? 0.0
            //设置纹理对象
            var uniformOrder1 = RGBSeparateDistance.init(rgbDistance: vector_float3.init(x: Float(r_distance), y: Float(g_distance), z: Float(b_distance)), textureCoordinateRange: vector_float2.init(x: Float(minY), y: Float(maxY)));
            let uniformBuffer1 = mtkView.device?.makeBuffer(bytes: &uniformOrder1, length: MemoryLayout<(RGBSeparateDistance)>.size, options: .storageModeShared)
            separateDistances.append(uniformBuffer1)
        }
 
        for index in 0..<(9 - separateDistances.count) {
            var defaultUniformOrder = RGBSeparateDistance.init(rgbDistance: vector_float3.init(x: 0.0, y: 0.0, z: 0.0), textureCoordinateRange: vector_float2.init(x: 0.0, y: 0.0));
            let defaultUniformBuffer = mtkView.device?.makeBuffer(bytes: &defaultUniformOrder, length: MemoryLayout<(RGBSeparateDistance)>.size, options: .storageModeShared)
            separateDistances.append(defaultUniformBuffer)
        }
    }
    //滤镜和融合处理
    private func filterHander() {
        self.setupVertex()
        self.setupPipeLine()
        //原图
        self.setupTexture(originImage)
        //融合的图
        if let coverImage = self.filterModel?.image {
            self.setupTexture2(coverImage)
        }else {
            print("------模型image为空")
        }
        
        if let coverImage2 = self.filterModel?.vagueImage {
            var cropSize = self.originImage.size
            var redioW = coverImage2.size.width / cropSize.width
            let redioH = coverImage2.size.height / cropSize.height
            if redioW < redioH {
                redioW = redioH
            }
            cropSize = CGSize.init(width: cropSize.width * redioW, height: cropSize.height * redioW)
            let im = coverImage2.effectScaled(to: cropSize)
            self.setupTexture4(im)
        }
        
        //滤镜色卡
        if let filterCardImage =  self.filterModel?.filter {
            self.setupTexture3(filterCardImage)
        } else {
            print("------模型滤镜色卡为空")
        }
        //有rgb分离时，设置距离参数
        if self.filterModel?.method?.contains("2") == true  {
            setUniformBuffer(self.parts)
        }
    }
    
    private func setupVertex() {
        var quadVertices:Array<FilterLayerVertex> = []
        let imageVertices:[vector_float4] = [
            vector_float4.init(-1.0 , 1.0, 0.0, 1.0),//左上
            vector_float4.init(1.0 , 1.0, 0.0, 1.0),//右上
            vector_float4.init(-1.0 , -1.0, 0.0, 1.0),//左下
            vector_float4.init(1.0 , -1.0, 0.0, 1.0)]//右下
        let textureCoordinates:[vector_float2] = [
            vector_float2.init(0.0 , 0.0),
            vector_float2.init(1.0 , 0.0),
            vector_float2.init(0.0 , 1.0),
            vector_float2.init(1.0 , 1.0)]
        for i in 0...imageVertices.count - 1 {
            let vertex = FilterLayerVertex.init(position: imageVertices[i], textureCoordinate: textureCoordinates[i], textureCoordinate2: textureCoordinates[i])
            quadVertices.append(vertex)

        }

        let verticeIndex:[UInt32] = [0,1,2,2,3,1]
        vertexBuffer = device!.makeBuffer(bytes: quadVertices,length: quadVertices.count * MemoryLayout<FilterLayerVertex>.size,options: .storageModeShared)
        indexs = mtkView.device?.makeBuffer(bytes: verticeIndex, length: MemoryLayout<(UInt32)>.size * verticeIndex.count, options: .storageModeShared)
        numVertices = verticeIndex.count
        
        //传入片源函数的参数，用来控制透明度
        //默认的透明度是0.8
        let uniformOrder:[Float] = [0.8]
        uniformBuffer = mtkView.device?.makeBuffer(bytes: uniformOrder, length: MemoryLayout<(Float)>.size * uniformOrder.count, options: .storageModeShared)
        //判断是否使用噪点图
        if self.filterModel?.method?.contains("1") == true && self.filterModel?.vagueImage != nil {
            let vagueLogicfrom:[Float] = [1.0]
            self.vagueLogicBuffer = mtkView.device?.makeBuffer(bytes: vagueLogicfrom, length: MemoryLayout<(Float)>.size * vagueLogicfrom.count, options: .storageModeShared)
        } else {
            let vagueLogicfrom:[Float] = [2.0]
            self.vagueLogicBuffer = mtkView.device?.makeBuffer(bytes: vagueLogicfrom, length: MemoryLayout<(Float)>.size * vagueLogicfrom.count, options: .storageModeShared)
        }
        //设置使用哪种融合模式
        if self.filterModel?.method?.contains("1") == true && self.filterModel?.image != nil {
            if self.filterModel?.mixmode == "HardLightBlend" {
                let mixUniform:[Float] = [2.0]
                self.mixLogicBuffer = mtkView.device?.makeBuffer(bytes: mixUniform, length: MemoryLayout<(Float)>.size * mixUniform.count, options: .storageModeShared)
            } else if self.filterModel?.mixmode == "OverlayBlend" && self.filterModel?.image != nil{
                let mixUniform:[Float] = [1.0]
                self.mixLogicBuffer = mtkView.device?.makeBuffer(bytes: mixUniform, length: MemoryLayout<(Float)>.size * mixUniform.count, options: .storageModeShared)
            } else {
                let mixUniform:[Float] = [0.0]
                self.mixLogicBuffer = mtkView.device?.makeBuffer(bytes: mixUniform, length: MemoryLayout<(Float)>.size * mixUniform.count, options: .storageModeShared)
            }
        }
        if self.filterModel?.method == "1_2" {
            let mixRgbform : [Float] = [1.0]
            self.mixRgbOrderLogicBuffer = mtkView.device?.makeBuffer(bytes: mixRgbform, length: MemoryLayout<(Float)>.size * mixRgbform.count, options: .storageModeShared)
        } else {
            let mixRgbform : [Float] = [2.0]
            self.mixRgbOrderLogicBuffer = mtkView.device?.makeBuffer(bytes: mixRgbform, length: MemoryLayout<(Float)>.size * mixRgbform.count, options: .storageModeShared)
        }
        
        
        
        
    }
    private func setupPipeLine() {
         //1.创建我们的渲染通道
         let defaultLibiary = device?.makeDefaultLibrary()
         let vertexFunction = defaultLibiary?.makeFunction(name: "filterLayerVertexShader")
         let fragmentFunction = defaultLibiary?.makeFunction(name: self.returnFunctionNameForModel())
         
         //2.配置用于创建管道状态的管道
         let pipelineStateDescriptor = MTLRenderPipelineDescriptor()
         pipelineStateDescriptor.label = "Texturing Pipeline"
         pipelineStateDescriptor.vertexFunction = vertexFunction
         pipelineStateDescriptor.fragmentFunction = fragmentFunction
         pipelineStateDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat
         pipelineStateDescriptor.colorAttachments[0].isBlendingEnabled = true
         pipelineStateDescriptor.colorAttachments[0].rgbBlendOperation = .add
         pipelineStateDescriptor.colorAttachments[0].alphaBlendOperation = .add
         pipelineStateDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
         pipelineStateDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
         pipelineStateDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
         pipelineStateDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
         //3.同步创建并返回渲染管线对象
         pipelineState = try! device?.makeRenderPipelineState(descriptor: pipelineStateDescriptor)
         
         //4.使用_device创建commandQueue
         commandQueue = device?.makeCommandQueue()
    }
    
    private func returnFunctionNameForModel() ->String{
        //默认只有滤镜
        var funcName = "onlyfilterShader"
        //method:"0_1"实现方式，0为滤镜色卡，1为静态图，2为rgb分离，支持多种实
        let method = self.filterModel?.method ?? ""
        if method.count > 0 {
            //滤镜+静态图
            if method == "0_1" || method == "1_0" {
                //滤镜只作用于原图上，所以有0的时候不区分前后顺序
                funcName = "filter_overlayBlendMix";
            }
            //滤镜+rgb分离
            else if method == "0_2" || method == "2_0" {
                //滤镜只作用于原图上，所以有0的时候不区分前后顺序
                funcName = "filter_rgbSepreate"
            }
            //静态图+rgb分离，metal中内部参数mixRgbOrderLogic控制先后顺序，mixLogic控制融合模式
            else if method == "1_2" || method == "2_1" {
                funcName = "miximage_rgbSepreate"
            }
            //只有静态图
            else if method == "1" {
                funcName = "onlyImageMixShader"
            }
            //只有rgb分离
            else if method == "2" {
                funcName = "onlyRgbSeparateShader"
            }
            //只有滤镜
            else if method == "0" {
                funcName = "onlyfilterShader"
            }
        }
        return funcName
    }
    
    
    private func setupTexture(_ originImage:UIImage) {
        let textureLoader = MTKTextureLoader(device: device!)
        textTexture = try! textureLoader.newTexture(cgImage: originImage.cgImage!, options: [MTKTextureLoader.Option.SRGB: false])
    }
//    func setupTexture(_ image: UIImage) {
//        if textTexture == nil {
//            let texureDescriptor = MTLTextureDescriptor()
//            //表示每个像素有蓝色,绿色,红色和alpha通道.其中每个通道都是8位无符号归一化的值.(即0映射成0,255映射成1);
//            texureDescriptor.pixelFormat = .rgba8Unorm;
//            //设置纹理的像素尺寸
//            texureDescriptor.width = Int(image.size.width)
//            texureDescriptor.height = Int(image.size.height)
//            //3.使用描述符从设备中创建纹理
//            textTexture = device!.makeTexture(descriptor: texureDescriptor)
//            textTexture.label = "textTexture"
//        }
//        //4. 创建MTLRegion 结构体  [纹理上传的范围]
//        let region = MTLRegion.init(origin: MTLOrigin.init(x: 0, y: 0, z: 0), size: MTLSize.init(width: Int(image.size.width), height: Int(image.size.height), depth: 1))
//        let bytes = image.loadImage()
//
//        textTexture.replace(region: region, mipmapLevel: 0, withBytes: bytes, bytesPerRow: 4 * Int(image.size.width))
//    }
    private func setupTexture2(_ coverImage:UIImage) {
        let sizeT = self.frame.size
        //图片裁剪
        let imageT = coverImage.imageWithResetSize(sizeT)
        let textureLoader = MTKTextureLoader(device: device!)
        textTexture2 = try! textureLoader.newTexture(cgImage: imageT.cgImage!, options: [MTKTextureLoader.Option.SRGB: false])
    }
    private func setupTexture3(_ filterCardImage:UIImage) {
        let textureLoader = MTKTextureLoader(device: device!)
        textTexture3 = try! textureLoader.newTexture(cgImage: filterCardImage.cgImage!, options: [MTKTextureLoader.Option.SRGB: false])
    }
    private func setupTexture4(_ coverImage2:UIImage) {
        let textureLoader = MTKTextureLoader(device: device!)
        textTexture4 = try! textureLoader.newTexture(cgImage: coverImage2.cgImage!, options: [MTKTextureLoader.Option.SRGB: false])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    //MARK:- MTKView delegate
    func draw(in view: MTKView) {
        //为当前渲染的每个渲染传递创建一个新的命令缓存区
        let commandBuffer = self.commandQueue.makeCommandBuffer()
        commandBuffer?.label = "MyCommand2";
        guard let renderPass = view.currentRenderPassDescriptor else {
            return
        }
        let outputTexture = view.currentDrawable?.texture
        view.framebufferOnly = false
        commandBuffer?.addCompletedHandler({[weak self] (buffer) in
            if outputTexture != nil {
                if let image = self?.makeImage(for: outputTexture!) {
                    self?.resultImageT = UIImage(cgImage: image)
                } else {
                    print("从纹理转换图片失败，图片为空")
                }
            }
        })
        renderPass.colorAttachments[0].clearColor = MTLClearColorMake(1, 1, 1, 1)
        renderPass.colorAttachments[0].storeAction = .store
        renderPass.colorAttachments[0].loadAction = .clear
        //创建渲染编码器 根据渲染描述信息
        let renderEncoder = commandBuffer?.makeRenderCommandEncoder(descriptor: renderPass)
        
        let viewOutputTexture = view.currentDrawable!.texture
        //设置渲染管道
        renderEncoder?.setRenderPipelineState(self.pipelineState)
        //加载数据
        renderEncoder?.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        
        //设置纹理对象
        renderEncoder?.setFragmentTexture(textTexture, index: 0)
        renderEncoder?.setFragmentTexture(textTexture2, index: 1)
        renderEncoder?.setFragmentTexture(textTexture3, index: 2)
        if self.textTexture4 != nil {
            renderEncoder?.setFragmentTexture(textTexture4, index: 3)
        }
        //需要rgb分离的时候
        if separateDistances != nil,separateDistances.count > 0,self.filterModel?.method?.contains("2") == true {
            for i in 1 ... separateDistances.count {
                if i < 10 {
                    //设置rgb分离参数
                    renderEncoder?.setFragmentBuffer(separateDistances[i - 1], offset: 0, index: i)
                }
            }
            //设置透明度参数,index是10
            renderEncoder?.setFragmentBuffer(uniformBuffer, offset: 0, index: 10)
        } else {
            //设置透明度参数
            renderEncoder?.setFragmentBuffer(uniformBuffer, offset: 0, index: 1)
        }
        if self.vagueLogicBuffer != nil {
            renderEncoder?.setFragmentBuffer(vagueLogicBuffer,offset: 0,index: 25)
        }
        if self.mixLogicBuffer != nil {
            renderEncoder?.setFragmentBuffer(mixLogicBuffer,offset: 0,index: 26)
        }
        if self.mixRgbOrderLogicBuffer != nil {
            renderEncoder?.setFragmentBuffer(mixRgbOrderLogicBuffer,offset: 0,index: 27)
        }
        
        //绘制
        renderEncoder?.drawIndexedPrimitives(type: .triangle, indexCount: numVertices, indexType: .uint32, indexBuffer: indexs, indexBufferOffset: 0)
        //编码器已经生成命令都完成, 并且从CommandBuffer分离
        renderEncoder?.endEncoding()
        commandBuffer?.present(view.currentDrawable!)
        //将命令缓冲区推送到GPU
        commandBuffer?.commit()
        view.isPaused = true
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        self.viewportSize = vector_uint2.init(UInt32(UInt(size.width )), UInt32(UInt(size.height)))
    }
    
    
    //根据滑块的值调整rgb的距离比例
    public func adapterRGBDistancePercent(_ percentValue:CGFloat) {
        if self.filterModel?.method?.contains("2") == false {
            //没有RGB分离，只调整透明度
            let uniformOrder:[Float] = [Float(percentValue)]
            uniformBuffer = mtkView.device?.makeBuffer(bytes: uniformOrder, length: MemoryLayout<(Float)>.size * uniformOrder.count, options: .storageModeShared)
            self.mtkView.draw()
            return
        }
        if self.parts == nil {
            return
        }
        separateDistances.removeAll()
        let partArray = self.parts!
        if partArray == nil {
           for _ in 1 ... 9 {
               var defaultUniformOrder = RGBSeparateDistance.init(rgbDistance: vector_float3.init(x: 0.0, y: 0.0, z: 0.0), textureCoordinateRange: vector_float2.init(x: 0.0, y: 0.0));
               let defaultUniformBuffer = mtkView.device?.makeBuffer(bytes: &defaultUniformOrder, length: MemoryLayout<(RGBSeparateDistance)>.size, options: .storageModeShared)
               separateDistances.append(defaultUniformBuffer)
           }
           return
       }
       for info in partArray {
            let r_distance = (info["r_distance"] ?? 0.0) * percentValue
            let g_distance = (info["g_distance"] ?? 0.0) * percentValue
            let b_distance = (info["b_distance"] ?? 0.0) * percentValue
            let minY = info["minY"] ?? 0.0
            let maxY = info["maxY"] ?? 0.0
            //设置纹理对象
            var uniformOrder1 = RGBSeparateDistance.init(rgbDistance: vector_float3.init(x: Float(r_distance), y: Float(g_distance), z: Float(b_distance)), textureCoordinateRange: vector_float2.init(x: Float(minY), y: Float(maxY)));
            let uniformBuffer1 = mtkView.device?.makeBuffer(bytes: &uniformOrder1, length: MemoryLayout<(RGBSeparateDistance)>.size, options: .storageModeShared)
            separateDistances.append(uniformBuffer1)
       }
       for index in 0..<(9 - separateDistances.count) {
           var defaultUniformOrder = RGBSeparateDistance.init(rgbDistance: vector_float3.init(x: 0.0, y: 0.0, z: 0.0), textureCoordinateRange: vector_float2.init(x: 0.0, y: 0.0));
           let defaultUniformBuffer = mtkView.device?.makeBuffer(bytes: &defaultUniformOrder, length: MemoryLayout<(RGBSeparateDistance)>.size, options: .storageModeShared)
           separateDistances.append(defaultUniformBuffer)
       }
        
        let uniformOrder:[Float] = [Float(percentValue)]
        uniformBuffer = mtkView.device?.makeBuffer(bytes: uniformOrder, length: MemoryLayout<(Float)>.size * uniformOrder.count, options: .storageModeShared)
        
       self.mtkView.draw()
        
    }
    
    
    
    //MARK: - 保存图片
    //从纹理保存图片（外部调用）
    public func saveImageFromMTKView(_ convertImageSuccessCallBack: @escaping (_ resultImage:UIImage?)->()) {
        if let image = self.resultImageT {
            //获取纹理转成的图片结果回调
            convertImageSuccessCallBack(image)
            /*
            DispatchQueue.main.async {[weak self] in
                let sizeT = self?.frame.size ?? CGSize(width: Screen.width, height: 304)
                //图片裁剪
                let resultImage = image.imageWithResetSize(sizeT)
                //Quartz重绘图片翻转图片
                let rect = CGRect(x: 0, y: 0, width: sizeT.width, height: sizeT.height);
                //根据size大小创建一个基于位图的图形上下文
                UIGraphicsBeginImageContextWithOptions(rect.size, false, 2)
                let currentContext =  UIGraphicsGetCurrentContext()
                currentContext!.clip(to: rect)
                currentContext?.draw(resultImage.cgImage!, in: rect)
                if let drawImage =  UIGraphicsGetImageFromCurrentImageContext() {
                    let flipImage =  UIImage(cgImage:drawImage.cgImage!,
                                                            scale:resultImage.scale,
                                                            orientation:resultImage.imageOrientation
                                   )
                    convertImageSuccessCallBack(flipImage)
                }
               
            }
             */
        } else {
            //纹理转图片失败，就截图保存
            self.shotViewToImageCallBack(convertImageSuccessCallBack)
        }
    }
    //MARK:纹理转图片
    private func makeImage(for texture: MTLTexture) -> CGImage? {
        assert(texture.pixelFormat == .bgra8Unorm)
        let width = texture.width
        let height = texture.height
        let pixelByteCount = 4 * MemoryLayout<UInt8>.size
        let imageBytesPerRow = width * pixelByteCount
        let imageByteCount = imageBytesPerRow * height
        let imageBytes = UnsafeMutableRawPointer.allocate(byteCount: imageByteCount, alignment: pixelByteCount)
        defer {
            imageBytes.deallocate()
        }

        texture.getBytes(imageBytes,
                         bytesPerRow: imageBytesPerRow,
                         from: MTLRegionMake2D(0, 0, width, height),
                         mipmapLevel: 0)

        swizzleBGRA8toRGBA8(imageBytes, width: width, height: height)

       // guard let colorSpace = CGColorSpace(name: CGColorSpace.linearSRGB) else { return nil }
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let bitmapContext = CGContext(data: nil,
                                            width: width,
                                            height: height,
                                            bitsPerComponent: 8,
                                            bytesPerRow: imageBytesPerRow,
                                            space: colorSpace,
                                            bitmapInfo: bitmapInfo) else { return nil }
        bitmapContext.data?.copyMemory(from: imageBytes, byteCount: imageByteCount)
        let image = bitmapContext.makeImage()
        return image
    }
    
    private func swizzleBGRA8toRGBA8(_ bytes: UnsafeMutableRawPointer, width: Int, height: Int) {
        var sourceBuffer = vImage_Buffer(data: bytes,
                                         height: vImagePixelCount(height),
                                         width: vImagePixelCount(width),
                                         rowBytes: width * 4)
        var destBuffer = vImage_Buffer(data: bytes,
                                       height: vImagePixelCount(height),
                                       width: vImagePixelCount(width),
                                       rowBytes: width * 4)
        var swizzleMask: [UInt8] = [ 2, 1, 0, 3 ] // BGRA -> RGBA
        vImagePermuteChannels_ARGB8888(&sourceBuffer, &destBuffer, &swizzleMask, vImage_Flags(kvImageNoFlags))
    }

    //截图保存
    private func shotViewToImageCallBack(_ convertImageSuccessCallBack: @escaping (_ resultImage:UIImage?)->()) {
        if #available(iOS 10.0, *) {
            UIGraphicsBeginImageContextWithOptions(self.bounds.size, false, UIScreen.main.scale)
            let rect = self.bounds
            self.drawHierarchy(in: rect, afterScreenUpdates: false)
            let image = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            convertImageSuccessCallBack(image)
        }
    }
    
    
}
