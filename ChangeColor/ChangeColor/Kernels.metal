//
//  Kernels.metal
//  ChangeColor
//
//  Created by dely on 2018. 10. 18..
//  Copyright © 2018년 dely. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

kernel void pixelate(texture2d<float, access::read> inTexture [[texture(0)]],
                      texture2d<float, access::write> outTexture [[texture(1)]],
                      device unsigned int *pixelSize [[buffer(0)]],
                      uint2 gid [[thread_position_in_grid]]){
    const float4 colorAtPixel = inTexture.read(gid);
    const float4 outputColor = float4(colorAtPixel.r-0.1, 0.5, 0.7, 1);
    outTexture.write(outputColor, gid);
}
