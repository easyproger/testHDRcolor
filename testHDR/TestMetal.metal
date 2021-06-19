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



constant float BT2020_8bit_full_rgb_to_yuv[] = {
    0.262700f, 0.678000f, 0.059300f, 0.000000f, 0.000000f,  -0.139630f, -0.360370f,
    0.500000f, 0.000000f, 0.501961f, 0.500000f, -0.459786f, -0.040214f, 0.000000f,
    0.501961f, 0.000000f, 0.000000f, 0.000000f, 1.000000f,  0.000000f,
};
constant float BT2020_8bit_full_yuv_to_rgb[] = {
    1.000000f,  -0.000000f, 1.474600f, 0.000000f, -0.740191f, 1.000000f,  -0.164553f,
    -0.571353f, 0.000000f,  0.369396f, 1.000000f, 1.881400f,  -0.000000f, 0.000000f,
    -0.944389f, 0.000000f,  0.000000f, 0.000000f, 1.000000f,  0.000000f,
};
constant float BT2020_8bit_limited_rgb_to_yuv[] = {
    0.225613f, 0.582282f, 0.050928f, 0.000000f, 0.062745f,  -0.122655f, -0.316560f,
    0.439216f, 0.000000f, 0.501961f, 0.439216f, -0.403890f, -0.035326f, 0.000000f,
    0.501961f, 0.000000f, 0.000000f, 0.000000f, 1.000000f,  0.000000f,
};
constant float BT2020_8bit_limited_yuv_to_rgb[] = {
    1.164384f,  -0.000000f, 1.678674f, 0.000000f, -0.915688f, 1.164384f,  -0.187326f,
    -0.650424f, 0.000000f,  0.347458f, 1.164384f, 2.141772f,  -0.000000f, 0.000000f,
    -1.148145f, 0.000000f,  0.000000f, 0.000000f, 1.000000f,  0.000000f,
};
constant float BT2020_10bit_full_rgb_to_yuv[] = {
    0.262700f, 0.678000f, 0.059300f, 0.000000f, 0.000000f,  -0.139630f, -0.360370f,
    0.500000f, 0.000000f, 0.500489f, 0.500000f, -0.459786f, -0.040214f, 0.000000f,
    0.500489f, 0.000000f, 0.000000f, 0.000000f, 1.000000f,  0.000000f,
};
constant float BT2020_10bit_full_yuv_to_rgb[] = {
    1.000000f,  -0.000000f, 1.474600f, 0.000000f, -0.738021f, 1.000000f,  -0.164553f,
    -0.571353f, 0.000000f,  0.368313f, 1.000000f, 1.881400f,  -0.000000f, 0.000000f,
    -0.941620f, 0.000000f,  0.000000f, 0.000000f, 1.000000f,  0.000000f,
};
constant float BT2020_10bit_limited_rgb_to_yuv[] = {
    0.224951f, 0.580575f, 0.050779f, 0.000000f, 0.062561f,  -0.122296f, -0.315632f,
    0.437928f, 0.000000f, 0.500489f, 0.437928f, -0.402706f, -0.035222f, 0.000000f,
    0.500489f, 0.000000f, 0.000000f, 0.000000f, 1.000000f,  0.000000f,
};
constant float BT2020_10bit_limited_yuv_to_rgb[] = {
    1.167808f,  -0.000000f, 1.683611f, 0.000000f, -0.915688f, 1.167808f,  -0.187877f,
    -0.652337f, 0.000000f,  0.347458f, 1.167808f, 2.148072f,  -0.000000f, 0.000000f,
    -1.148145f, 0.000000f,  0.000000f, 0.000000f, 1.000000f,  0.000000f,
};

metal::float4x4 colormatrix_to_matrix44() {
    const constant float* src = BT2020_10bit_full_yuv_to_rgb;
    return float4x4(
                    src[0], src[5], src[10], 0,
                    src[1], src[6], src[11], 0,
                    src[2], src[7], src[12], 0,
                    src[4], src[9], src[14], 1);
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



template <typename T, typename _E = typename enable_if<is_floating_point<T>::value>::type>
METAL_FUNC T linearToSRGB(T c) {
    return (c < 0.0031308f) ? (12.92f * c) : (1.055f * powr(c, 1.f/2.4f) - 0.055f);
}

METAL_FUNC float3 linearToSRGB(float3 c) {
    return float3(linearToSRGB(c.r), linearToSRGB(c.g), linearToSRGB(c.b));
}

template <typename T, typename _E = typename enable_if<is_floating_point<T>::value>::type>
METAL_FUNC T ITUR709ToLinear(T c) {
    #if __METAL_IOS__
    return powr(c, 1.961);
    #else
    return c < 0.081 ? 0.222 * c : powr(0.91 * c + 0.09, 2.222);
    #endif
}

METAL_FUNC float3 ITUR709ToLinear(float3 c) {
    return float3(ITUR709ToLinear(c.r), ITUR709ToLinear(c.g), ITUR709ToLinear(c.b));
}

float4 convertITUR709RGBToSRGB(float4 textureColor) {
   textureColor.rgb = ITUR709ToLinear(textureColor.rgb);
   textureColor.rgb = linearToSRGB(textureColor.rgb);
   return textureColor;
}

template <typename T, typename _E = typename enable_if<is_floating_point<T>::value>::type>
METAL_FUNC T sRGBToLinear(T c) {
    return (c <= 0.04045f) ? c / 12.92f : powr((c + 0.055f) / 1.055f, 2.4f);
}

METAL_FUNC float3 sRGBToLinear(float3 c) {
    return float3(sRGBToLinear(c.r), sRGBToLinear(c.g), sRGBToLinear(c.b));
}

template <typename T, typename _E = typename enable_if<is_floating_point<T>::value>::type>
METAL_FUNC T linearToITUR709(T c) {
    #if __METAL_IOS__
    return powr(c, 1.0/1.961);
    #else
    return c < 0.018 ? (4.5 * c) : (1.099 * powr(c, 1.0/2.222) - 0.099);
    #endif
}

METAL_FUNC float3 linearToITUR709(float3 c) {
    return float3(linearToITUR709(c.r), linearToITUR709(c.g), linearToITUR709(c.b));
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
//    textureColor.rgb = sRGBToLinear(textureColor.rgb);
//    textureColor.rgb = linearToITUR709(textureColor.rgb);
    return textureColor;
    
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
    
//    newColor.rgb = ITUR709ToLinear(newColor.rgb);
//    newColor.rgb = linearToSRGB(newColor.rgb);

    return newColor; // 不修改alpha值;
    
}

fragment float4 capturedImageFragmentShader(VertexIn in [[stage_in]],
                                            metal::texture2d<float, metal::access::sample> capturedImageTextureY [[ texture(0) ]],
                                            metal::texture2d<float, metal::access::sample> capturedImageTextureCbCr [[ texture(1) ]],
                                            texture2d<float> lutTexture [[texture(2)]]) {
    
    constexpr metal::sampler colorSampler(metal::mip_filter::linear,
                                          metal::mag_filter::linear,
                                          metal::min_filter::linear);
    
    const metal::float4x4 transformMatrix = colormatrix_to_matrix44();
    
    // Sample Y and CbCr textures to get the YCbCr color at the given texture coordinate
    float4 ycbcr = float4(capturedImageTextureY.sample(colorSampler, in.texCoord).r,
                          capturedImageTextureCbCr.sample(colorSampler, in.texCoord).rg, 1.0);
    
    
     float y = ycbcr.r;
     float u = ycbcr.g - 0.5;
     float v = ycbcr.b - 0.5;
    
     float r = y + 1.402 * v;
     float g = y - 0.344 * u - 0.714 * v;
     float b = y + 1.772 * u;
    
    return float4(r,g,b,1.0);
    if (ycbcr.r > 1.0 || ycbcr.g > 1.0 || ycbcr.b > 1.0) {
        return float4(1.0,0.0,0.0,1.0);
    }
    
    float4 textureColor = transformMatrix * ycbcr;
    
    if (textureColor.r > 1.0 || textureColor.g > 1.0 || textureColor.b > 1.0) {
        return float4(0.0,1.0,0.0,1.0);
    }
    
    return textureColor;
    
//    // Return converted RGB color
//    float blueColor = textureColor.b * 63.0; // 蓝色部分 [0, 63] 共 64 种;
//
//    float2 quad1; // 第一个正方形的位置, 假如 blueColor = 22.5，则 y = 22 / 8 = 2，x = 22 - 8 * 2 = 6，即是第 2 行，第 6 个正方形；（因为 y 是纵坐标）;
//    quad1.y = floor(floor(blueColor) * 0.125);
//    quad1.x = floor(blueColor) - (quad1.y * 8.0);
//
//    float2 quad2; // 第二个正方形的位置，同上。注意 x、y 坐标的计算，还有这里用 int 值也可以，但是为了效率使用 float;
//    quad2.y = floor(ceil(blueColor) * 0.125);
//    quad2.x = ceil(blueColor) - (quad2.y * 8.0);
//
//    float2 texPos1; // 计算颜色 (r, b, g) 在第一个正方形中对应位置;
//    texPos1.x = ((quad1.x * 64) +  textureColor.r * 63 + 0.5) / 512.0;
//    texPos1.y = ((quad1.y * 64) +  textureColor.g * 63 + 0.5) / 512.0;
//
//    float2 texPos2; // 同上;
//    texPos2.x = ((quad2.x * 64) +  textureColor.r * 63 + 0.5) / 512.0;
//    texPos2.y = ((quad2.y * 64) +  textureColor.g * 63 + 0.5) / 512.0;
//
//    float4 newColor1 = lutTexture.sample(layerSampler, texPos1); // 正方形 1 的颜色值;
//    float4 newColor2 = lutTexture.sample(layerSampler, texPos2); // 正方形 2 的颜色值;
//
//    float4 newColor = mix(newColor1, newColor2, fract(blueColor)); // 根据小数点的部分进行 mix;
//
//    return newColor; // 不修改alpha值;
}
