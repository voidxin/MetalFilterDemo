//
//  FilterShaders.metal
//  3DCamera
//
//  Created by zhangxin on 2020/11/5.
//  Copyright © 2020 Zy. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;
#import "FilterShaderTypes.h"

struct FilterLayerData{
    float4 position [[position]];
    float2 textureCoordinate [[user(texturecoord)]];
    float2 textureCoordinate2 [[user(texturecoord2)]];
    float2 textureCoordinate3 [[user(texturecoord3)]];
};
//透明度控制
typedef struct
{
    float intensity;
} IntensityUniform;

//是否有噪点图控制，vagueValue为1.0的时候表示有噪点图
typedef struct
{
    float vagueValue;
} VagueLogicUniform;

//混合模式控制 1.0:OverlayBlend,2.0:HardLightBlend,其他，没有融合模式
typedef struct
{
    float mixValue;
} MixLogicUniform;

//静态和RGB分离的顺序 1.0表示先静态图再rgb分离，其他，表示先rgb分离再加静态图
typedef struct
{
    float mixOrderValue;
} Mix_RGBOrderLogicUniform;

vertex FilterLayerData filterLayerVertexShader(uint vertexID [[ vertex_id ]],
                                  constant FilterLayerVertex *vertexData [[ buffer(0) ]]) {
    FilterLayerData out;
    out.position = vertexData[vertexID].position;
    out.textureCoordinate = vertexData[vertexID].textureCoordinate;
    out.textureCoordinate2 = vertexData[vertexID].textureCoordinate2;
   // out.textureCoordinate3 = vertexData[vertexID].textureCoordinate3;
    return out;
}
//MARK: - 内部调用函数 ----------以下函数只能在内部使用，外部不能调用------------------------
//MARK:  没有混合模式
half4 noFilter_noOverBlend_fragmentShader(FilterLayerData fragmentInput [[stage_in]],
                                       half uniform,
                                       half4 c2,
                                       texture2d<half> inputTexture2 [[texture(1)]])
{
//    constexpr sampler quadSampler;
//    half4 c2 = inputTexture.sample(quadSampler, fragmentInput.textureCoordinate);
    constexpr sampler quadSampler2;
    half4 c1 = inputTexture2.sample(quadSampler2, fragmentInput.textureCoordinate2);

    //1.加动态图
    half4 outputColor1;
    outputColor1.r = c1.r + c2.r * c2.a * (1.0 - c1.a);
    outputColor1.g = c1.g + c2.g * c2.a * (1.0 - c1.a);
    outputColor1.b = c1.b + c2.b * c2.a * (1.0 - c1.a);
    outputColor1.a = c1.a + c2.a * (1.0 - c1.a);
    half4 resultColor = mix(c2, half4(outputColor1.rgb, c2.w), uniform);
    return resultColor;
}
//MARK:  OverlayBlend混合
half4 onlyOverlayBlendfilterfragmentShader(FilterLayerData in [[stage_in]],
                                           half uniform,
                                           half4 base,
                                           texture2d<half> inputTexture2 [[texture(1)]]){
    constexpr sampler quadSampler2;
    half4 overlay = inputTexture2.sample(quadSampler2, in.textureCoordinate2);
    //2.混合
    half ra;
    if (2.0h * base.r < base.a) {
        ra = 2.0h * overlay.r * base.r + overlay.r * (1.0h - base.a) + base.r * (1.0h - overlay.a);
    } else {
        ra = overlay.a * base.a - 2.0h * (base.a - base.r) * (overlay.a - overlay.r) + overlay.r * (1.0h - base.a) + base.r * (1.0h - overlay.a);
    }
    
    half ga;
    if (2.0h * base.g < base.a) {
        ga = 2.0h * overlay.g * base.g + overlay.g * (1.0h - base.a) + base.g * (1.0h - overlay.a);
    } else {
        ga = overlay.a * base.a - 2.0h * (base.a - base.g) * (overlay.a - overlay.g) + overlay.g * (1.0h - base.a) + base.g * (1.0h - overlay.a);
    }
    
    half ba;
    if (2.0h * base.b < base.a) {
        ba = 2.0h * overlay.b * base.b + overlay.b * (1.0h - base.a) + base.b * (1.0h - overlay.a);
    } else {
        ba = overlay.a * base.a - 2.0h * (base.a - base.b) * (overlay.a - overlay.b) + overlay.b * (1.0h - base.a) + base.b * (1.0h - overlay.a);
    }
    half4 colorT = mix(base, half4(ra, ga, ba, 1.0), uniform);
    return colorT;
}
//MARK:  HardLightBlend混合
half4 onlyHardLightBlendfilterfragmentShader(FilterLayerData in [[stage_in]],
                                             half uniform,
                                             half4 base,
                                             texture2d<half> inputTexture2 [[texture(1)]]) {
    constexpr sampler quadSampler2;
    half4 overlay = inputTexture2.sample(quadSampler2, in.textureCoordinate2);
    
    half ra;
    if (2.0h * overlay.r < overlay.a) {
        ra = 2.0h * overlay.r * base.r + overlay.r * (1.0h - base.a) + base.r * (1.0h - overlay.a);
    } else {
        ra = overlay.a * base.a - 2.0h * (base.a - base.r) * (overlay.a - overlay.r) + overlay.r * (1.0h - base.a) + base.r * (1.0h - overlay.a);
    }
    
    half ga;
    if (2.0h * overlay.g < overlay.a) {
        ga = 2.0h * overlay.g * base.g + overlay.g * (1.0h - base.a) + base.g * (1.0h - overlay.a);
    } else {
        ga = overlay.a * base.a - 2.0h * (base.a - base.g) * (overlay.a - overlay.g) + overlay.g * (1.0h - base.a) + base.g * (1.0h - overlay.a);
    }
    
    half ba;
    if (2.0h * overlay.b < overlay.a) {
        ba = 2.0h * overlay.b * base.b + overlay.b * (1.0h - base.a) + base.b * (1.0h - overlay.a);
    } else {
        ba = overlay.a * base.a - 2.0h * (base.a - base.b) * (overlay.a - overlay.b) + overlay.b * (1.0h - base.a) + base.b * (1.0h - overlay.a);
    }
    half4 colorT = mix(base, half4(ra, ga, ba, 1.0), uniform);
    return colorT;
}

//MARK:  滤镜（只有滤镜）
half4 filterfragmentShader(FilterLayerData in [[stage_in]],
                               half uniform,
                               texture2d<half> inputTexture [[texture(0)]],
                               texture2d<half> inputTexture2 [[texture(1)]],
                               texture2d<half> inputTexture3 [[texture(2)]]){
    //滤镜
    constexpr sampler quadSampler;
    half4 base = inputTexture.sample(quadSampler, in.textureCoordinate);
    
    half blueColor = base.b * 63.0h;
    
    half2 quad1;
    quad1.y = floor(floor(blueColor) / 8.0h);
    quad1.x = floor(blueColor) - (quad1.y * 8.0h);
    
    half2 quad2;
    quad2.y = floor(ceil(blueColor) / 8.0h);
    quad2.x = ceil(blueColor) - (quad2.y * 8.0h);
    
    float2 texPos1;
    texPos1.x = (quad1.x * 0.125) + 0.5/512.0 + ((0.125 - 1.0/512.0) * base.r);
    texPos1.y = (quad1.y * 0.125) + 0.5/512.0 + ((0.125 - 1.0/512.0) * base.g);
    
    float2 texPos2;
    texPos2.x = (quad2.x * 0.125) + 0.5/512.0 + ((0.125 - 1.0/512.0) * base.r);
    texPos2.y = (quad2.y * 0.125) + 0.5/512.0 + ((0.125 - 1.0/512.0) * base.g);
    ////1.滤镜(inputTexture3)参数是色卡纹理
    constexpr sampler quadSampler3;
    half4 newColor1 = inputTexture3.sample(quadSampler3, texPos1);
    constexpr sampler quadSampler4;
    half4 newColor2 = inputTexture3.sample(quadSampler4, texPos2);
    
    half4 newColor = mix(newColor1, newColor2, fract(blueColor));
    
    half4 resultColor = mix(base, half4(newColor.rgb, base.w), uniform);
    return resultColor;

}
//MARK:  rgb
struct RGBSeparateFilterData
{
    float4 position [[position]];
    float2 textureCoordinate [[user(texturecoord)]];
    float2 textureCoordinate2 [[user(texturecoord2)]];
};
half4 getFilterOffsetCoordsRGB(texture2d<half> inputTexture, FilterLayerData fragmentInput, sampler quadSampler, half4 mask, RGBSeparateDistance2 ensureSeparateDistance) {
    
    half3 offsetCoordsRGB = half3(ensureSeparateDistance.rgbDistance);
    half4 maskR = inputTexture.sample(quadSampler, fragmentInput.textureCoordinate + float2(offsetCoordsRGB.r,0.0));
    half4 maskG = inputTexture.sample(quadSampler, fragmentInput.textureCoordinate + float2(offsetCoordsRGB.g,0.0));
    half4 maskB = inputTexture.sample(quadSampler, fragmentInput.textureCoordinate + float2(offsetCoordsRGB.b,0.0));
    return half4(maskR.r, maskG.g, maskB.b, mask.a);
}
//MARK: rgb 只有rgb分离
half4 separate_FilterFragmentShader(        FilterLayerData fragmentInput [[stage_in]],
                                            texture2d<half> inputTexture [[texture(0)]],
                                            half4 resultFilter,
                                            constant RGBSeparateDistance2 & separateDistance1 [[buffer(1)]],
                                            constant RGBSeparateDistance2 & separateDistance2 [[buffer(2)]],
                                            constant RGBSeparateDistance2 & separateDistance3 [[buffer(3)]],
                                            constant RGBSeparateDistance2 & separateDistance4 [[buffer(4)]],
                                            constant RGBSeparateDistance2 & separateDistance5 [[buffer(5)]],
                                            constant RGBSeparateDistance2 & separateDistance6 [[buffer(6)]],
                                            constant RGBSeparateDistance2 & separateDistance7 [[buffer(7)]],
                                            constant RGBSeparateDistance2 & separateDistance8 [[buffer(8)]],
                                            constant RGBSeparateDistance2 & separateDistance9 [[buffer(9)]])
{
    /*
    constexpr sampler quadSampler;
    half4 mask = resultFilter;
    if (resultFilter.y >= separateDistance1.textureCoordinateRange.x && resultFilter.y <= separateDistance1.textureCoordinateRange.y) {
        mask = getFilterOffsetCoordsRGB(inputTexture, fragmentInput, quadSampler, mask, separateDistance1);
    } else if (resultFilter.y > separateDistance2.textureCoordinateRange.x && resultFilter.y <= separateDistance2.textureCoordinateRange.y) {
        mask = getFilterOffsetCoordsRGB(inputTexture, fragmentInput, quadSampler, mask, separateDistance2);
    } else if (resultFilter.y > separateDistance3.textureCoordinateRange.x && resultFilter.y <= separateDistance3.textureCoordinateRange.y) {
        mask = getFilterOffsetCoordsRGB(inputTexture, fragmentInput, quadSampler, mask, separateDistance3);
    } else if (resultFilter.y > separateDistance4.textureCoordinateRange.x && resultFilter.y <= separateDistance4.textureCoordinateRange.y) {
        mask = getFilterOffsetCoordsRGB(inputTexture, fragmentInput, quadSampler, mask, separateDistance4);
    } else if (resultFilter.y > separateDistance5.textureCoordinateRange.x && resultFilter.y <= separateDistance5.textureCoordinateRange.y) {
        return getFilterOffsetCoordsRGB(inputTexture, fragmentInput, quadSampler, mask, separateDistance5);
    } else if (resultFilter.y > separateDistance6.textureCoordinateRange.x && resultFilter.y <= separateDistance6.textureCoordinateRange.y) {
        mask = getFilterOffsetCoordsRGB(inputTexture, fragmentInput, quadSampler, mask, separateDistance6);
    } else if (resultFilter.y > separateDistance7.textureCoordinateRange.x && resultFilter.y <= separateDistance7.textureCoordinateRange.y) {
        mask = getFilterOffsetCoordsRGB(inputTexture, fragmentInput, quadSampler, mask, separateDistance7);
    } else if (resultFilter.y > separateDistance8.textureCoordinateRange.x && resultFilter.y <= separateDistance8.textureCoordinateRange.y) {
        mask = getFilterOffsetCoordsRGB(inputTexture, fragmentInput, quadSampler, mask, separateDistance8);
    } else if (resultFilter.y > separateDistance9.textureCoordinateRange.x && resultFilter.y <= separateDistance9.textureCoordinateRange.y) {
        mask = getFilterOffsetCoordsRGB(inputTexture, fragmentInput, quadSampler, mask, separateDistance9);
    }
    return mask;
     */
    constexpr sampler quadSampler;
    half4 mask = resultFilter;
    if (fragmentInput.textureCoordinate.y >= separateDistance1.textureCoordinateRange.x && fragmentInput.textureCoordinate.y <= separateDistance1.textureCoordinateRange.y) {
        mask = getFilterOffsetCoordsRGB(inputTexture, fragmentInput, quadSampler, mask, separateDistance1);
    } else if (fragmentInput.textureCoordinate.y > separateDistance2.textureCoordinateRange.x && fragmentInput.textureCoordinate.y <= separateDistance2.textureCoordinateRange.y) {
        mask = getFilterOffsetCoordsRGB(inputTexture, fragmentInput, quadSampler, mask, separateDistance2);
    } else if (fragmentInput.textureCoordinate.y > separateDistance3.textureCoordinateRange.x && fragmentInput.textureCoordinate.y <= separateDistance3.textureCoordinateRange.y) {
        mask = getFilterOffsetCoordsRGB(inputTexture, fragmentInput, quadSampler, mask, separateDistance3);
    } else if (fragmentInput.textureCoordinate.y > separateDistance4.textureCoordinateRange.x && fragmentInput.textureCoordinate.y <= separateDistance4.textureCoordinateRange.y) {
        mask = getFilterOffsetCoordsRGB(inputTexture, fragmentInput, quadSampler, mask, separateDistance4);
    } else if (fragmentInput.textureCoordinate.y > separateDistance5.textureCoordinateRange.x && fragmentInput.textureCoordinate.y <= separateDistance5.textureCoordinateRange.y) {
        return getFilterOffsetCoordsRGB(inputTexture, fragmentInput, quadSampler, mask, separateDistance5);
    } else if (fragmentInput.textureCoordinate.y > separateDistance6.textureCoordinateRange.x && fragmentInput.textureCoordinate.y <= separateDistance6.textureCoordinateRange.y) {
        mask = getFilterOffsetCoordsRGB(inputTexture, fragmentInput, quadSampler, mask, separateDistance6);
    } else if (fragmentInput.textureCoordinate.y > separateDistance7.textureCoordinateRange.x && fragmentInput.textureCoordinate.y <= separateDistance7.textureCoordinateRange.y) {
        mask = getFilterOffsetCoordsRGB(inputTexture, fragmentInput, quadSampler, mask, separateDistance7);
    } else if (fragmentInput.textureCoordinate.y > separateDistance8.textureCoordinateRange.x && fragmentInput.textureCoordinate.y <= separateDistance8.textureCoordinateRange.y) {
        mask = getFilterOffsetCoordsRGB(inputTexture, fragmentInput, quadSampler, mask, separateDistance8);
    } else if (fragmentInput.textureCoordinate.y > separateDistance9.textureCoordinateRange.x && fragmentInput.textureCoordinate.y <= separateDistance9.textureCoordinateRange.y) {
        mask = getFilterOffsetCoordsRGB(inputTexture, fragmentInput, quadSampler, mask, separateDistance9);
    }
    return mask;
    
}

//MARK: - 对外调用函数 ----------以上情况两两组合------------------------
//MARK:  滤镜+图层融合
/*
   vagueLogic=1.0表示需要加噪点图，噪点图纹理是inputTexture4，加载滤镜之后的结果上不需要融合模式
   mixLogic = 1.0表示OverlayBlend，mixLogic = 2.0表示HardLightBlend，其他表示没有融合模式
 */
fragment half4 filter_overlayBlendMix(FilterLayerData fragmentInput [[stage_in]],
                                      constant IntensityUniform &uniform [[buffer(1)]],
                                      constant VagueLogicUniform &vagueLogic [[buffer(25)]],
                                      constant MixLogicUniform &mixLogic[[buffer(26)]],
                                      texture2d<half> inputTexture [[texture(0)]],
                                      texture2d<half> inputTexture2 [[texture(1)]],
                                      texture2d<half> inputTexture3 [[texture(2)]],
                                      texture2d<half> inputTexture4 [[texture(3)]]) {
    //tips:uniform透明度只用在最后的结果上,所以前面的结果透明度都的得传1
    half temple_uniform = 1.0;
    //滤镜
    half4 filterResult = filterfragmentShader(fragmentInput,temple_uniform,inputTexture,inputTexture2,inputTexture3);
    //噪点图
    if (half(vagueLogic.vagueValue) == 1.0) {
        filterResult = noFilter_noOverBlend_fragmentShader(fragmentInput,temple_uniform,filterResult,inputTexture4);
    }
    //融合
    half4 mixResult = filterResult;
    if (mixLogic.mixValue == 1.0) {
        //OverlayBlend
        mixResult = onlyOverlayBlendfilterfragmentShader(fragmentInput,temple_uniform,filterResult,inputTexture2);
    } else if (mixLogic.mixValue == 2.0) {
        //HardLightBlend
        mixResult = onlyHardLightBlendfilterfragmentShader(fragmentInput,temple_uniform,filterResult,inputTexture2);
    } else {
        //没有融合模式
        mixResult = noFilter_noOverBlend_fragmentShader(fragmentInput,temple_uniform,filterResult,inputTexture4);
    }
    constexpr sampler quadSampler1;
    half4 originColor = inputTexture.sample(quadSampler1, fragmentInput.textureCoordinate);
    return  mix(originColor, mixResult, uniform.intensity);
   
}

//MARK:  滤镜 + RGB分离
fragment half4 filter_rgbSepreate(FilterLayerData fragmentInput [[stage_in]],
                                      texture2d<half> inputTexture [[texture(0)]],
                                      texture2d<half> inputTexture2 [[texture(1)]],
                                      texture2d<half> inputTexture3 [[texture(2)]],
                                      constant RGBSeparateDistance2 & separateDistance1 [[buffer(1)]],
                                      constant RGBSeparateDistance2 & separateDistance2 [[buffer(2)]],
                                      constant RGBSeparateDistance2 & separateDistance3 [[buffer(3)]],
                                      constant RGBSeparateDistance2 & separateDistance4 [[buffer(4)]],
                                      constant RGBSeparateDistance2 & separateDistance5 [[buffer(5)]],
                                      constant RGBSeparateDistance2 & separateDistance6 [[buffer(6)]],
                                      constant RGBSeparateDistance2 & separateDistance7 [[buffer(7)]],
                                      constant RGBSeparateDistance2 & separateDistance8 [[buffer(8)]],
                                      constant RGBSeparateDistance2 & separateDistance9 [[buffer(9)]],
                                      constant IntensityUniform &uniform [[buffer(10)]]){
    //tips:uniform透明度只用在最后的结果上,所以前面的结果透明度都的得传1
    half temple_uniform = 1.0;
    //滤镜
    half4 filterResult = filterfragmentShader(fragmentInput,temple_uniform,inputTexture,inputTexture2,inputTexture3);
    //RGB分离
    half4 maskResult = separate_FilterFragmentShader(fragmentInput,inputTexture,filterResult,separateDistance1,separateDistance2,separateDistance3,separateDistance4,separateDistance5,separateDistance6,separateDistance7,separateDistance8,separateDistance9);
    constexpr sampler quadSampler1;
    half4 originColor = inputTexture.sample(quadSampler1, fragmentInput.textureCoordinate);
    return  mix(originColor, maskResult, uniform.intensity);
   
}

//MARK:  静态图 + RGB分离
//mixLogic = 1.0表示OverlayBlend，mixLogic = 2.0表示HardLightBlend，其他表示没有融合模式
//mixRgbOrderLogic: 1.0表示先静态图再rgb分离，其他，表示先rgb分离再加静态图
fragment half4 miximage_rgbSepreate(FilterLayerData fragmentInput [[stage_in]],
                                      texture2d<half> inputTexture [[texture(0)]],
                                      texture2d<half> inputTexture2 [[texture(1)]],
                                      texture2d<half> inputTexture3 [[texture(2)]],
                                      texture2d<half> inputTexture4 [[texture(3)]],
                                      constant MixLogicUniform &mixLogic[[buffer(26)]],
                                      constant Mix_RGBOrderLogicUniform &mixRgbOrderLogic[[buffer(27)]],
                                      constant RGBSeparateDistance2 & separateDistance1 [[buffer(1)]],
                                      constant RGBSeparateDistance2 & separateDistance2 [[buffer(2)]],
                                      constant RGBSeparateDistance2 & separateDistance3 [[buffer(3)]],
                                      constant RGBSeparateDistance2 & separateDistance4 [[buffer(4)]],
                                      constant RGBSeparateDistance2 & separateDistance5 [[buffer(5)]],
                                      constant RGBSeparateDistance2 & separateDistance6 [[buffer(6)]],
                                      constant RGBSeparateDistance2 & separateDistance7 [[buffer(7)]],
                                      constant RGBSeparateDistance2 & separateDistance8 [[buffer(8)]],
                                      constant RGBSeparateDistance2 & separateDistance9 [[buffer(9)]],
                                      constant IntensityUniform &uniform [[buffer(10)]]){
    //tips:uniform透明度只用在最后的结果上,所以前面的结果透明度都的得传1
    half temple_uniform = 1.0;
    
    constexpr sampler quadSampler;
    half4 baseColor = inputTexture.sample(quadSampler, fragmentInput.textureCoordinate);
    if (mixRgbOrderLogic.mixOrderValue == 1.0) {
        //融合
        half4 mixResult = baseColor;
        if (mixLogic.mixValue == 1.0) {
            //OverlayBlend
            mixResult = onlyOverlayBlendfilterfragmentShader(fragmentInput,temple_uniform,baseColor,inputTexture2);
        } else if (mixLogic.mixValue == 2.0) {
            //HardLightBlend
            mixResult = onlyHardLightBlendfilterfragmentShader(fragmentInput,temple_uniform,baseColor,inputTexture2);
        } else {
            //没有融合模式
            mixResult = noFilter_noOverBlend_fragmentShader(fragmentInput,temple_uniform,baseColor,inputTexture4);
        }
        
        
        //RGB分离
        half4 maskResult = separate_FilterFragmentShader(fragmentInput,inputTexture,mixResult,separateDistance1,separateDistance2,separateDistance3,separateDistance4,separateDistance5,separateDistance6,separateDistance7,separateDistance8,separateDistance9);
        constexpr sampler quadSampler1;
        half4 originColor = inputTexture.sample(quadSampler1, fragmentInput.textureCoordinate);
        return  mix(originColor, maskResult, uniform.intensity);
    } else {
        //RGB分离
        half4 maskResult = separate_FilterFragmentShader(fragmentInput,inputTexture,baseColor,separateDistance1,separateDistance2,separateDistance3,separateDistance4,separateDistance5,separateDistance6,separateDistance7,separateDistance8,separateDistance9);
        //图片融合
        half4 mixResult = maskResult;
        if (mixLogic.mixValue == 1.0) {
            //OverlayBlend
            mixResult = onlyOverlayBlendfilterfragmentShader(fragmentInput,temple_uniform,baseColor,inputTexture2);
        } else if (mixLogic.mixValue == 2.0) {
            //HardLightBlend
            mixResult = onlyHardLightBlendfilterfragmentShader(fragmentInput,temple_uniform,baseColor,inputTexture2);
        } else {
            //没有融合模式
            mixResult = noFilter_noOverBlend_fragmentShader(fragmentInput,temple_uniform,baseColor,inputTexture4);
        }
        constexpr sampler quadSampler1;
        half4 originColor = inputTexture.sample(quadSampler1, fragmentInput.textureCoordinate);
        return  mix(originColor, mixResult, uniform.intensity);
    }
}


//MARK:只有rgb分离
fragment half4 onlyRgbSeparateShader(        FilterLayerData fragmentInput [[stage_in]],
                            texture2d<half> inputTexture [[texture(0)]],
                            half4 resultFilter,
                            constant RGBSeparateDistance2 & separateDistance1 [[buffer(1)]],
                            constant RGBSeparateDistance2 & separateDistance2 [[buffer(2)]],
                            constant RGBSeparateDistance2 & separateDistance3 [[buffer(3)]],
                            constant RGBSeparateDistance2 & separateDistance4 [[buffer(4)]],
                            constant RGBSeparateDistance2 & separateDistance5 [[buffer(5)]],
                            constant RGBSeparateDistance2 & separateDistance6 [[buffer(6)]],
                            constant RGBSeparateDistance2 & separateDistance7 [[buffer(7)]],
                            constant RGBSeparateDistance2 & separateDistance8 [[buffer(8)]],
                            constant RGBSeparateDistance2 & separateDistance9 [[buffer(9)]]){
    constexpr sampler quadSampler;
    half4 baseColor = inputTexture.sample(quadSampler, fragmentInput.textureCoordinate);
    
    half4 maskResult = separate_FilterFragmentShader(fragmentInput,inputTexture,baseColor,separateDistance1,separateDistance2,separateDistance3,separateDistance4,separateDistance5,separateDistance6,separateDistance7,separateDistance8,separateDistance9);
    return  maskResult;
}
//MARK:只有滤镜
fragment half4 onlyfilterShader(FilterLayerData fragmentInput [[stage_in]],
                               constant IntensityUniform& uniform [[buffer(1)]],
                               texture2d<half> inputTexture [[texture(0)]],
                               texture2d<half> inputTexture2 [[texture(1)]],
                               texture2d<half> inputTexture3 [[texture(2)]]){
    
    //tips:uniform透明度只用在最后的结果上,所以前面的结果透明度都的得传1
    half temple_uniform = 1.0;
    //滤镜
    half4 filterResult = filterfragmentShader(fragmentInput,temple_uniform,inputTexture,inputTexture2,inputTexture3);
    constexpr sampler quadSampler1;
    half4 originColor = inputTexture.sample(quadSampler1, fragmentInput.textureCoordinate);
    return  mix(originColor, filterResult, uniform.intensity);
   // return filterResult;
}
//MARK:只有图片混合
fragment half4 onlyImageMixShader(FilterLayerData fragmentInput [[stage_in]],
                                  texture2d<half> inputTexture [[texture(0)]],
                                  texture2d<half> inputTexture2 [[texture(1)]],
                                  texture2d<half> inputTexture3 [[texture(2)]],
                                  texture2d<half> inputTexture4 [[texture(3)]],
                                  constant IntensityUniform& uniform [[buffer(1)]],
                                  constant VagueLogicUniform &vagueLogic [[buffer(25)]],
                                  constant MixLogicUniform &mixLogic[[buffer(26)]]){
    
    constexpr sampler quadSampler;
    half4 baseColor = inputTexture.sample(quadSampler, fragmentInput.textureCoordinate);
    //tips:uniform透明度只用在最后的结果上,所以前面的结果透明度都的得传1
    half temple_uniform = 1.0;
    //噪点图
    half4 colorT = inputTexture.sample(quadSampler, fragmentInput.textureCoordinate);
    half4 vagurResult = colorT;
    if (half(vagueLogic.vagueValue) == 1.0) {
        vagurResult = noFilter_noOverBlend_fragmentShader(fragmentInput,temple_uniform,colorT,inputTexture4);
    }
    
    half4 mixResult = baseColor;
    if (half(vagueLogic.vagueValue) == 1.0) {
        mixResult = vagurResult;
    }
    if (mixLogic.mixValue == 1.0) {
        //OverlayBlend
        mixResult = onlyOverlayBlendfilterfragmentShader(fragmentInput,temple_uniform,baseColor,inputTexture2);
    } else if (mixLogic.mixValue == 2.0) {
        //HardLightBlend
        mixResult = onlyHardLightBlendfilterfragmentShader(fragmentInput,temple_uniform,baseColor,inputTexture2);
    } else {
        //没有融合模式
        mixResult = noFilter_noOverBlend_fragmentShader(fragmentInput,temple_uniform,baseColor,inputTexture4);
    }
    constexpr sampler quadSampler1;
    half4 originColor = inputTexture.sample(quadSampler1, fragmentInput.textureCoordinate);
    return  mix(originColor, mixResult, uniform.intensity);
}




//------
//MARK: - 测试代码，0_1有两层图融合（第一次使用混合模式，第二次没有混合模式融合)
//inputTexture4第二个静态图纹理
fragment half4 test_fragmentShader(FilterLayerData in [[stage_in]],
                                constant IntensityUniform& uniform [[buffer(1)]],
                                texture2d<half> inputTexture [[texture(0)]],
                                texture2d<half> inputTexture2 [[texture(1)]],
                                texture2d<half> inputTexture3 [[texture(2)]],
                                texture2d<half> inputTexture4 [[texture(3)]]) {
      //1:滤镜
      constexpr sampler quadSampler;
      half4 originColor = inputTexture.sample(quadSampler, in.textureCoordinate);
      constexpr sampler quadSampler10;
      half4 normalColor = inputTexture.sample(quadSampler10, in.textureCoordinate);
      
      half blueColor = originColor.b * 63.0h;
      
      half2 quad1;
      quad1.y = floor(floor(blueColor) / 8.0h);
      quad1.x = floor(blueColor) - (quad1.y * 8.0h);
      
      half2 quad2;
      quad2.y = floor(ceil(blueColor) / 8.0h);
      quad2.x = ceil(blueColor) - (quad2.y * 8.0h);
      
      float2 texPos1;
      texPos1.x = (quad1.x * 0.125) + 0.5/512.0 + ((0.125 - 1.0/512.0) * originColor.r);
      texPos1.y = (quad1.y * 0.125) + 0.5/512.0 + ((0.125 - 1.0/512.0) * originColor.g);
      
      float2 texPos2;
      texPos2.x = (quad2.x * 0.125) + 0.5/512.0 + ((0.125 - 1.0/512.0) * originColor.r);
      texPos2.y = (quad2.y * 0.125) + 0.5/512.0 + ((0.125 - 1.0/512.0) * originColor.g);
      ////1.滤镜(inputTexture3)参数是色卡纹理
      constexpr sampler quadSampler3;
      half4 newColor1 = inputTexture3.sample(quadSampler3, texPos1);
      constexpr sampler quadSampler4;
      half4 newColor2 = inputTexture3.sample(quadSampler4, texPos2);
      
      half4 newColor = mix(newColor1, newColor2, fract(blueColor));
      
       half4 resultColor = mix(originColor, half4(newColor.rgb, originColor.w), 1.0);
    
    
        //2躁点图不需要融合模式叠加
        half4 c2 = resultColor;
        constexpr sampler quadSampler5;
        half4 c1 = inputTexture4.sample(quadSampler5, in.textureCoordinate);
        half4 outputColor1;
        outputColor1.r = c1.r + c2.r * c2.a * (1.0 - c1.a);
        outputColor1.g = c1.g + c2.g * c2.a * (1.0 - c1.a);
        outputColor1.b = c1.b + c2.b * c2.a * (1.0 - c1.a);
        outputColor1.a = c1.a + c2.a * (1.0 - c1.a);
        half4 filterResult = outputColor1;
        
    
        //3.光图，HardLightBlend混合
        half4 base = half4(filterResult);
        constexpr sampler quadSampler2;
        half4 overlay = inputTexture2.sample(quadSampler2, in.textureCoordinate2);
        half ra;
        if (2.0h * overlay.r < overlay.a) {
            ra = 2.0h * overlay.r * base.r + overlay.r * (1.0h - base.a) + base.r * (1.0h - overlay.a);
        } else {
            ra = overlay.a * base.a - 2.0h * (base.a - base.r) * (overlay.a - overlay.r) + overlay.r * (1.0h - base.a) + base.r * (1.0h - overlay.a);
        }
        
        half ga;
        if (2.0h * overlay.g < overlay.a) {
            ga = 2.0h * overlay.g * base.g + overlay.g * (1.0h - base.a) + base.g * (1.0h - overlay.a);
        } else {
            ga = overlay.a * base.a - 2.0h * (base.a - base.g) * (overlay.a - overlay.g) + overlay.g * (1.0h - base.a) + base.g * (1.0h - overlay.a);
        }
        
        half ba;
        if (2.0h * overlay.b < overlay.a) {
            ba = 2.0h * overlay.b * base.b + overlay.b * (1.0h - base.a) + base.b * (1.0h - overlay.a);
        } else {
            ba = overlay.a * base.a - 2.0h * (base.a - base.b) * (overlay.a - overlay.b) + overlay.b * (1.0h - base.a) + base.b * (1.0h - overlay.a);
        }
    
        
    
        constexpr sampler quadSampler6;
        half4 baseColor = inputTexture.sample(quadSampler6, in.textureCoordinate);

        return mix(baseColor, half4(ra, ga, ba, 1.0h), uniform.intensity);
}
//---------测试代码 rgb分离原始方法---------------------
fragment half4 separate_FilterFragmentShader(
                                             FilterLayerData fragmentInput [[stage_in]],
                                            texture2d<half> inputTexture [[texture(0)]],
                                            texture2d<half> inputTexture2 [[texture(1)]],
                                            texture2d<half> inputTexture3 [[texture(2)]],
                                            constant RGBSeparateDistance2 & separateDistance1 [[buffer(1)]],
                                            constant RGBSeparateDistance2 & separateDistance2 [[buffer(2)]],
                                            constant RGBSeparateDistance2 & separateDistance3 [[buffer(3)]],
                                            constant RGBSeparateDistance2 & separateDistance4 [[buffer(4)]],
                                            constant RGBSeparateDistance2 & separateDistance5 [[buffer(5)]],
                                            constant RGBSeparateDistance2 & separateDistance6 [[buffer(6)]],
                                            constant RGBSeparateDistance2 & separateDistance7 [[buffer(7)]],
                                            constant RGBSeparateDistance2 & separateDistance8 [[buffer(8)]],
                                            constant RGBSeparateDistance2 & separateDistance9 [[buffer(9)]])
{
    
    constexpr sampler quadSampler;
    half4 mask = inputTexture.sample(quadSampler, fragmentInput.textureCoordinate);
    if (fragmentInput.textureCoordinate.y >= separateDistance1.textureCoordinateRange.x && fragmentInput.textureCoordinate.y <= separateDistance1.textureCoordinateRange.y) {
        mask = getFilterOffsetCoordsRGB(inputTexture, fragmentInput, quadSampler, mask, separateDistance1);
    } else if (fragmentInput.textureCoordinate.y > separateDistance2.textureCoordinateRange.x && fragmentInput.textureCoordinate.y <= separateDistance2.textureCoordinateRange.y) {
        mask = getFilterOffsetCoordsRGB(inputTexture, fragmentInput, quadSampler, mask, separateDistance2);
    } else if (fragmentInput.textureCoordinate.y > separateDistance3.textureCoordinateRange.x && fragmentInput.textureCoordinate.y <= separateDistance3.textureCoordinateRange.y) {
        mask = getFilterOffsetCoordsRGB(inputTexture, fragmentInput, quadSampler, mask, separateDistance3);
    } else if (fragmentInput.textureCoordinate.y > separateDistance4.textureCoordinateRange.x && fragmentInput.textureCoordinate.y <= separateDistance4.textureCoordinateRange.y) {
        mask = getFilterOffsetCoordsRGB(inputTexture, fragmentInput, quadSampler, mask, separateDistance4);
    } else if (fragmentInput.textureCoordinate.y > separateDistance5.textureCoordinateRange.x && fragmentInput.textureCoordinate.y <= separateDistance5.textureCoordinateRange.y) {
        return getFilterOffsetCoordsRGB(inputTexture, fragmentInput, quadSampler, mask, separateDistance5);
    } else if (fragmentInput.textureCoordinate.y > separateDistance6.textureCoordinateRange.x && fragmentInput.textureCoordinate.y <= separateDistance6.textureCoordinateRange.y) {
        mask = getFilterOffsetCoordsRGB(inputTexture, fragmentInput, quadSampler, mask, separateDistance6);
    } else if (fragmentInput.textureCoordinate.y > separateDistance7.textureCoordinateRange.x && fragmentInput.textureCoordinate.y <= separateDistance7.textureCoordinateRange.y) {
        mask = getFilterOffsetCoordsRGB(inputTexture, fragmentInput, quadSampler, mask, separateDistance7);
    } else if (fragmentInput.textureCoordinate.y > separateDistance8.textureCoordinateRange.x && fragmentInput.textureCoordinate.y <= separateDistance8.textureCoordinateRange.y) {
        mask = getFilterOffsetCoordsRGB(inputTexture, fragmentInput, quadSampler, mask, separateDistance8);
    } else if (fragmentInput.textureCoordinate.y > separateDistance9.textureCoordinateRange.x && fragmentInput.textureCoordinate.y <= separateDistance9.textureCoordinateRange.y) {
        mask = getFilterOffsetCoordsRGB(inputTexture, fragmentInput, quadSampler, mask, separateDistance9);
    }
    return mask;

}
//----------------------------------------
