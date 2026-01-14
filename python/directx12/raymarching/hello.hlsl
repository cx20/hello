cbuffer Params : register(b0)
{
    float2 iResolution;
    float  iTime;
    float  _pad;
};

struct VSOut { float4 pos : SV_POSITION; };

VSOut VSMain(uint vid : SV_VertexID)
{
    float2 v[3] = {
        float2(-1.0, -1.0),
        float2(-1.0,  3.0),
        float2( 3.0, -1.0)
    };
    VSOut o;
    o.pos = float4(v[vid], 0.0, 1.0);
    return o;
}

float sdSphere(float3 p, float r) { return length(p) - r; }

float mapScene(float3 p)
{
    float3 c = float3(0, 0, 3);
    float dS = sdSphere(p - c, 1.0);
    return dS;
}

float3 normalAt(float3 p)
{
    float e = 0.001;
    float dx = mapScene(p + float3(e,0,0)) - mapScene(p - float3(e,0,0));
    float dy = mapScene(p + float3(0,e,0)) - mapScene(p - float3(0,e,0));
    float dz = mapScene(p + float3(0,0,e)) - mapScene(p - float3(0,0,e));
    return normalize(float3(dx,dy,dz));
}

float4 PSMain(float4 svpos : SV_POSITION) : SV_TARGET
{
    float2 fragCoord = svpos.xy;
    float2 uv = (fragCoord - 0.5 * iResolution) / iResolution.y;

    float3 ro = float3(0.0, 0.0, -2.5);
    ro.x += 0.4 * sin(iTime * 0.6);
    float3 rd = normalize(float3(uv, 1.3));

    float t = 0.0;
    float3 p = ro;
    bool hit = false;

    [loop]
    for (int i=0; i<128; i++)
    {
        p = ro + rd * t;
        float d = mapScene(p);
        if (d < 0.001) { hit = true; break; }
        if (t > 50.0) break;
        t += d;
    }

    float3 col = float3(0.02, 0.03, 0.05);
    if (hit)
    {
        float3 n = normalAt(p);
        float3 L = normalize(float3(0.4, 0.8, -0.2));
        float diff = saturate(dot(n, L));
        col = float3(0.2, 0.5, 1.0) * diff + 0.05;
    }

    col = pow(col, 1.0/2.2);
    return float4(col, 1.0);
}
