#include <flutter/runtime_effect.glsl>

// Float uniform slots (setFloat index order):
//   0..3   uData0  size.xy (logical), physicalOrigin.xy (device px)
//   4..7   uData1  glassTint rgba
//   8..11  uData2  refractionStrength, fresnelPower, backdropLuma, blurRadius
//   12..15 uData3  bgRelative.xy (logical), bgSize.xy (logical)
//   16..17 uData4  scale.xy (device pixel ratio per axis)

precision highp float;

uniform vec4 uData0;
uniform vec4 uData1;
uniform vec4 uData2;
uniform vec4 uData3;
uniform vec4 uData4;
uniform sampler2D uBackground;

float gaussianWeight(float x, float sigma) {
  return exp(-0.5 * (x * x) / (sigma * sigma));
}

vec3 sampleBackgroundBlur(vec2 uv, vec2 texel, float radius) {
  if (radius < 0.5) {
    return texture(uBackground, uv).rgb;
  }

  const int kRadius = 4;
  float sigma = max(radius * 0.5, 1.0);
  vec3 accum = vec3(0.0);
  float weightSum = 0.0;

  for (int i = -kRadius; i <= kRadius; i++) {
    float w = gaussianWeight(float(i), sigma);
    vec2 offset = vec2(float(i) * texel.x, 0.0);
    accum += texture(uBackground, uv + offset).rgb * w;
    weightSum += w;
  }
  for (int j = -kRadius; j <= kRadius; j++) {
    float w = gaussianWeight(float(j), sigma);
    vec2 offset = vec2(0.0, float(j) * texel.y);
    accum += texture(uBackground, uv + offset).rgb * w;
    weightSum += w;
  }

  return accum / max(weightSum, 0.0001);
}

vec2 refractOffset(vec2 uv, vec2 center, float strength) {
  vec2 toCenter = center - uv;
  float dist = length(toCenter);
  vec2 dir = dist > 0.0001 ? toCenter / dist : vec2(0.0);
  float lens = smoothstep(0.85, 0.0, dist);
  return dir * lens * strength * 0.035;
}

float fresnelRim(vec2 uv, vec2 center, float power) {
  float dist = distance(uv, center);
  return pow(clamp(dist * 1.35, 0.0, 1.0), power);
}

out vec4 fragColor;

void main() {
  vec2 uSize = uData0.xy;
  vec2 uPhysicalOrigin = uData0.zw;
  vec4 tint = uData1;
  float refractionStrength = uData2.x;
  float fresnelPower = max(uData2.y, 0.5);
  float backdropLuma = clamp(uData2.z, 0.0, 1.0);
  float blurRadius = uData2.w;

  vec2 uBgRelative = uData3.xy;
  vec2 uBgSize = max(uData3.zw, vec2(1.0));
  vec2 uScale = max(uData4.xy, vec2(0.0001));

  // Match liquid_glass_widgets: physical frag coord → logical local space.
  vec2 pixelCoord = FlutterFragCoord().xy;
  vec2 localLogical = (pixelCoord - uPhysicalOrigin) / uScale;
  vec2 uvPanel = localLogical / max(uSize, vec2(1.0));
  vec2 center = vec2(0.5);

  if (any(lessThan(uvPanel, vec2(0.0))) || any(greaterThan(uvPanel, vec2(1.0)))) {
    fragColor = vec4(0.0);
    return;
  }

  vec2 posInBg = uBgRelative + localLogical;
  vec2 bgUv = posInBg / uBgSize;
  vec2 texel = 1.0 / max(uBgSize, vec2(1.0));

  vec2 refractedUv = bgUv + refractOffset(uvPanel, center, refractionStrength);
  refractedUv = clamp(refractedUv, vec2(0.0), vec2(1.0));

  vec3 backdrop = sampleBackgroundBlur(refractedUv, texel, blurRadius);

  float lumaMix = mix(0.65, 1.0, backdropLuma);
  vec3 body = mix(backdrop, backdrop * tint.rgb + tint.rgb * 0.15, tint.a * lumaMix);

  float rim = fresnelRim(uvPanel, center, fresnelPower);
  float rimStrength = mix(0.35, 0.75, backdropLuma);
  vec3 rimColor = mix(vec3(1.0), tint.rgb + vec3(0.2), 0.35);
  vec3 color = body + rimColor * rim * rimStrength * 0.45;

  float alpha = clamp(tint.a * 0.85 + rim * 0.25, 0.0, 1.0);
  fragColor = vec4(color, alpha);
}
