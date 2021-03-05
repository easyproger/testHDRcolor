//
//  TestMetal.metal
//  testHDR
//
//  Created by Дмитрий Савичев on 05.03.2021.
//
#include <metal_stdlib>
#include <metal_texture>
using namespace metal;

typedef enum VertexInputIndex
{
    VertexInputIndexVertices = 0,
    VertexInputIndexPosition = 1,
    VertexInputIndexSecondPosition = 2,
} VertexInputIndex;

struct VertexIn {
    float2 position [[ attribute(VertexInputIndexVertices) ]];
    float2 texCoord [[ attribute(VertexInputIndexPosition) ]];
};

struct VertexOut {
    float4 position [[ position ]];
    float2 texCoord;
};

vertex VertexOut vertexDefault(const VertexIn in [[ stage_in ]]) {
    VertexOut out {
        .position = float4(in.position.x, in.position.y, 0.0, 1.0),
        .texCoord = in.texCoord
    };
    return out;
}

fragment float4 fragmentDefault(VertexIn in [[stage_in]]) {
    return float4(1.0,0.0,0.0,1.0);
}

constexpr sampler layerSampler(coord::normalized,
                               address::clamp_to_edge,
                               mip_filter::linear,
                               mag_filter::linear,
                               min_filter::linear);
fragment float4 layerFragment(VertexIn vert [[stage_in]],
                              texture2d<float, access::sample> in [[texture(0)]]) {
    return in.sample(layerSampler, vert.texCoord);
}

fragment float4 capturedImageFragmentShader(VertexIn in [[stage_in]],
                                            metal::texture2d<float, metal::access::sample> capturedImageTextureY [[ texture(0) ]],
                                            metal::texture2d<float, metal::access::sample> capturedImageTextureCbCr [[ texture(1) ]]) {
    
    constexpr metal::sampler colorSampler(metal::mip_filter::linear,
                                          metal::mag_filter::linear,
                                          metal::min_filter::linear);
    
    const metal::float4x4 ycbcrToRGBTransform = float4x4(
        float4(+1.0000f, +1.0000f, +1.0000f, +0.0000f),
        float4(+0.0000f, -0.3441f, +1.7720f, +0.0000f),
        float4(+1.4020f, -0.7141f, +0.0000f, +0.0000f),
        float4(-0.7010f, +0.5291f, -0.8860f, +1.0000f)
    );
    
    // Sample Y and CbCr textures to get the YCbCr color at the given texture coordinate
    float4 ycbcr = float4(capturedImageTextureY.sample(colorSampler, in.texCoord).r,
                          capturedImageTextureCbCr.sample(colorSampler, in.texCoord).rg, 1.0);
    
    // Return converted RGB color
    return ycbcrToRGBTransform * ycbcr;
}
