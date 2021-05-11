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

float linear_to_srgb(float channel) {
    if(channel <= 0.0031308)
        return 12.92 * channel;
    else
        return (1.0 + 0.055) * pow(channel, 1.0/2.4) - 0.055;
}
float srgb_to_linear(float channel) {
    if (channel <= 0.04045)
        return channel / 12.92;
    else
        return pow((channel + 0.055) / (1.0 + 0.055), 1.4);
}

float3 rgb_to_hcv(float3 rgb)
{
    // Based on work by Sam Hocevar and Emil Persson
    float4 P = (rgb.g < rgb.b) ? float4(rgb.bg, -1.0, 2.0/3.0) : float4(rgb.gb, 0.0, -1.0/3.0);
    float4 Q = (rgb.r < P.x) ? float4(P.xyw, rgb.r) : float4(rgb.r, P.yzx);
    float C = Q.x - min(Q.w, Q.y);
    float H = abs((Q.w - Q.y) / (6 * C + 1e-10) + Q.z);
    return float3(H, C, Q.x);
}
float3 rgb_to_hsl(float3 rgb)
{
    float3 HCV = rgb_to_hcv(rgb);
    float L = HCV.z - HCV.y * 0.5;
    float S = HCV.y / (1 - abs(L * 2 - 1) + 1e-10);
    return float3(HCV.x, S, L);
}
float3 hue_to_rgb(float hue)
{
    float R = abs(hue * 6 - 3) - 1;
    float G = 2 - abs(hue * 6 - 2);
    float B = 2 - abs(hue * 6 - 4);
    return saturate(float3(R,G,B));
}

float3 rgb_to_hcy(float3 rgb)
{
    const float3 HCYwts = float3(0.299, 0.587, 0.114);
    // Corrected by David Schaeffer
    float3 HCV = rgb_to_hcv(rgb);
    float Y = dot(rgb, HCYwts);
    float Z = dot(hue_to_rgb(HCV.x), HCYwts);
    if (Y < Z) {
      HCV.y *= Z / (1e-10 + Y);
    } else {
      HCV.y *= (1 - Z) / (1e-10 + 1 - Y);
    }
    return float3(HCV.x, HCV.y, Y);
}
float3 rgb_to_srgb(float3 rgb) {
    return float3(
        linear_to_srgb(rgb.r),
        linear_to_srgb(rgb.g),
        linear_to_srgb(rgb.b)
    );
}

float3 srgb_to_rgb(float3 srgb) {
    return float3(
        srgb_to_linear(srgb.r),
        srgb_to_linear(srgb.g),
        srgb_to_linear(srgb.b)
    );
}

constexpr sampler layerSampler(coord::normalized,
                               address::clamp_to_edge,
                               mip_filter::linear,
                               mag_filter::linear,
                               min_filter::linear);
fragment float4 layerFragment(VertexIn vert [[stage_in]],
                              texture2d<float, access::sample> in [[texture(0)]],
                              texture2d<float> lutTexture [[texture(1)]]) {
    
    float4 textureColor = in.sample(layerSampler, vert.texCoord);
    float blueColor = textureColor.b * 63.0; // 蓝色部分 [0, 63] 共 64 种;
    
    float2 quad1; // 第一个正方形的位置, 假如 blueColor = 22.5，则 y = 22 / 8 = 2，x = 22 - 8 * 2 = 6，即是第 2 行，第 6 个正方形；（因为 y 是纵坐标）;
    quad1.y = floor(floor(blueColor) * 0.125);
    quad1.x = floor(blueColor) - (quad1.y * 8.0);
    
    float2 quad2; // 第二个正方形的位置，同上。注意 x、y 坐标的计算，还有这里用 int 值也可以，但是为了效率使用 float;
    quad2.y = floor(ceil(blueColor) * 0.125);
    quad2.x = ceil(blueColor) - (quad2.y * 8.0);
    
    float2 texPos1; // 计算颜色 (r, b, g) 在第一个正方形中对应位置;
    texPos1.x = ((quad1.x * 64) +  textureColor.r * 63 + 0.5) / 512.0;
    texPos1.y = ((quad1.y * 64) +  textureColor.g * 63 + 0.5) / 512.0;
    
    float2 texPos2; // 同上;
    texPos2.x = ((quad2.x * 64) +  textureColor.r * 63 + 0.5) / 512.0;
    texPos2.y = ((quad2.y * 64) +  textureColor.g * 63 + 0.5) / 512.0;
    
    float4 newColor1 = lutTexture.sample(layerSampler, texPos1); // 正方形 1 的颜色值;
    float4 newColor2 = lutTexture.sample(layerSampler, texPos2); // 正方形 2 的颜色值;
    
    float4 newColor = mix(newColor1, newColor2, fract(blueColor)); // 根据小数点的部分进行 mix;
    
    return newColor; // 不修改alpha值;
    
}




fragment float4 capturedImageFragmentShader(VertexIn in [[stage_in]],
                                            metal::texture2d<float, metal::access::sample> capturedImageTextureY [[ texture(0) ]],
                                            metal::texture2d<float, metal::access::sample> capturedImageTextureCbCr [[ texture(1) ]],
                                            texture2d<float> lutTexture [[texture(2)]]) {
    
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
    float4 textureColor = ycbcrToRGBTransform * ycbcr;
    
    // Return converted RGB color
    float blueColor = textureColor.b * 63.0; // 蓝色部分 [0, 63] 共 64 种;
    
    float2 quad1; // 第一个正方形的位置, 假如 blueColor = 22.5，则 y = 22 / 8 = 2，x = 22 - 8 * 2 = 6，即是第 2 行，第 6 个正方形；（因为 y 是纵坐标）;
    quad1.y = floor(floor(blueColor) * 0.125);
    quad1.x = floor(blueColor) - (quad1.y * 8.0);
    
    float2 quad2; // 第二个正方形的位置，同上。注意 x、y 坐标的计算，还有这里用 int 值也可以，但是为了效率使用 float;
    quad2.y = floor(ceil(blueColor) * 0.125);
    quad2.x = ceil(blueColor) - (quad2.y * 8.0);
    
    float2 texPos1; // 计算颜色 (r, b, g) 在第一个正方形中对应位置;
    texPos1.x = ((quad1.x * 64) +  textureColor.r * 63 + 0.5) / 512.0;
    texPos1.y = ((quad1.y * 64) +  textureColor.g * 63 + 0.5) / 512.0;
    
    float2 texPos2; // 同上;
    texPos2.x = ((quad2.x * 64) +  textureColor.r * 63 + 0.5) / 512.0;
    texPos2.y = ((quad2.y * 64) +  textureColor.g * 63 + 0.5) / 512.0;
    
    float4 newColor1 = lutTexture.sample(layerSampler, texPos1); // 正方形 1 的颜色值;
    float4 newColor2 = lutTexture.sample(layerSampler, texPos2); // 正方形 2 的颜色值;
    
    float4 newColor = mix(newColor1, newColor2, fract(blueColor)); // 根据小数点的部分进行 mix;
    
    return newColor; // 不修改alpha值;
}
