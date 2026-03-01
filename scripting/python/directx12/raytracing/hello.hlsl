RWTexture2D<float4> gOutput : register(u0);
RaytracingAccelerationStructure gScene : register(t0);

struct RayPayload
{
    float4 color;
};

struct TriAttributes
{
    float2 barycentrics;
};

[shader("raygeneration")]
void RayGen()
{
    uint2 index = DispatchRaysIndex().xy;
    float2 dim = float2(DispatchRaysDimensions().xy);
    float2 ndc = ((float2(index) + 0.5f) / dim) * 2.0f - 1.0f;

    RayDesc ray;
    ray.Origin = float3(0.0f, 0.0f, -2.0f);
    ray.Direction = normalize(float3(ndc.x, -ndc.y, 1.5f));
    ray.TMin = 0.001f;
    ray.TMax = 10000.0f;

    RayPayload payload;
    payload.color = float4(0.392f, 0.584f, 0.929f, 1.0f);

    TraceRay(gScene, RAY_FLAG_NONE, 0xFF, 0, 0, 0, ray, payload);
    gOutput[index] = payload.color;
}

[shader("closesthit")]
void ClosestHit(inout RayPayload payload, in TriAttributes attribs)
{
    float3 bary = float3(
        1.0f - attribs.barycentrics.x - attribs.barycentrics.y,
        attribs.barycentrics.x,
        attribs.barycentrics.y);
    payload.color = float4(bary, 1.0f);
}

[shader("miss")]
void Miss(inout RayPayload payload)
{
    payload.color = float4(0.10f, 0.12f, 0.18f, 1.0f);
}
