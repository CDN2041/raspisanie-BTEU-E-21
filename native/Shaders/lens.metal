#include <metal_stdlib>
using namespace metal;

// Изгиб по кромке линзы: чем ближе к краю скруглённого прямоугольника, тем сильнее картинка стягивается к краю, как под выпуклым стеклом
[[ stitchable ]] float2 lensBulge(float2 position, float2 center, float2 hs, float radius, float band, float strength) {
  float2 v = position - center;
  float2 q = abs(v) - hs + radius;
  float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
  float t = clamp(1.0 + d / band, 0.0, 1.0);
  return center + v * (1.0 + strength * t * t * t);
}
