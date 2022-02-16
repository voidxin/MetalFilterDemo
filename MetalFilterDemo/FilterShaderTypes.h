//
//  FilterShaderTypes.h
//  3DCamera
//
//  Created by zhangxin on 2020/11/5.
//  Copyright © 2020 Zy. All rights reserved.
//

#ifndef FilterShaderTypes_h
#define FilterShaderTypes_h
#include <simd/simd.h>

typedef struct {
    //顶点
    vector_float4 position;
    //2D纹理
    vector_float2 textureCoordinate;
    vector_float2 textureCoordinate2;
  //  vector_float2 textureCoordinate3;
} FilterLayerVertex;

//textureCoordinateRange代表偏移的纹理坐标Y的范围, rgbDistance三维向量分别代表r偏移值, g偏移值, b偏移值
struct RGBSeparateDistance2
{
    vector_float3 rgbDistance;
    vector_float2 textureCoordinateRange;
};
typedef struct {
   vector_float4 position;//顶点
   vector_float2 textureCoordinate;//纹理坐标
} RGBSeparateFilterVertex;

//textureCoordinateRange代表偏移的纹理坐标Y的范围, rgbDistance三维向量分别代表r偏移值, g偏移值, b偏移值
struct RGBSeparateDistance
{
    vector_float3 rgbDistance;
    vector_float2 textureCoordinateRange;
};


#endif /* FilterShaderTypes_h */
