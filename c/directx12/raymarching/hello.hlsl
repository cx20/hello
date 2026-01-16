// Raymarching shader for DirectX 12

cbuffer ConstantBuffer : register(b0)
{
    float iTime;
    float2 iResolution;
    float padding;
};

struct PSInput
{
    float4 position : SV_POSITION;
    float2 uv : TEXCOORD0;
};

PSInput VSMain(float2 position : POSITION)
{
    PSInput result;
    result.position = float4(position, 0.0, 1.0);
    result.uv = position * 0.5 + 0.5;
    return result;
}

// Raymarching constants
static const int MAX_STEPS = 100;
static const float MAX_DIST = 100.0;
static const float SURF_DIST = 0.001;

// Signed Distance Functions
float sdSphere(float3 p, float r)
{
    return length(p) - r;
}

float sdBox(float3 p, float3 b)
{
    float3 q = abs(p) - b;
    return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0);
}

float sdTorus(float3 p, float2 t)
{
    float2 q = float2(length(p.xz) - t.x, p.y);
    return length(q) - t.y;
}

// Smooth minimum for blending shapes
float smin(float a, float b, float k)
{
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return lerp(b, a, h) - k * h * (1.0 - h);
}

// Scene distance function
float GetDist(float3 p)
{
    // Animated sphere
    float sphere = sdSphere(p - float3(sin(iTime) * 1.5, 0.5 + sin(iTime * 2.0) * 0.3, 0.0), 0.5);
    
    // Rotating torus
    float angle = iTime * 0.5;
    float3 torusPos = p - float3(0.0, 0.5, 0.0);
    float cosA = cos(angle);
    float sinA = sin(angle);
    float2 rotatedXZ = float2(cosA * torusPos.x - sinA * torusPos.z, sinA * torusPos.x + cosA * torusPos.z);
    torusPos.x = rotatedXZ.x;
    torusPos.z = rotatedXZ.y;
    
    float angle2 = angle * 0.7;
    float cosA2 = cos(angle2);
    float sinA2 = sin(angle2);
    float2 rotatedXY = float2(cosA2 * torusPos.x - sinA2 * torusPos.y, sinA2 * torusPos.x + cosA2 * torusPos.y);
    torusPos.x = rotatedXY.x;
    torusPos.y = rotatedXY.y;
    
    float torus = sdTorus(torusPos, float2(0.8, 0.2));
    
    // Ground plane
    float plane = p.y + 0.5;
    
    // Combine with smooth blending
    float d = smin(sphere, torus, 0.3);
    d = min(d, plane);
    
    return d;
}

// Calculate normal using gradient
float3 GetNormal(float3 p)
{
    float d = GetDist(p);
    float2 e = float2(0.001, 0.0);
    float3 n = d - float3(
        GetDist(p - e.xyy),
        GetDist(p - e.yxy),
        GetDist(p - e.yyx)
    );
    return normalize(n);
}

// Raymarching
float RayMarch(float3 ro, float3 rd)
{
    float dO = 0.0;
    for (int i = 0; i < MAX_STEPS; i++)
    {
        float3 p = ro + rd * dO;
        float dS = GetDist(p);
        dO += dS;
        if (dO > MAX_DIST || dS < SURF_DIST) break;
    }
    return dO;
}

// Soft shadows
float GetShadow(float3 ro, float3 rd, float mint, float maxt, float k)
{
    float res = 1.0;
    float t = mint;
    for (int i = 0; i < 64 && t < maxt; i++)
    {
        float h = GetDist(ro + rd * t);
        if (h < 0.001)
            return 0.0;
        res = min(res, k * h / t);
        t += h;
    }
    return res;
}

// Ambient occlusion
float GetAO(float3 p, float3 n)
{
    float occ = 0.0;
    float sca = 1.0;
    for (int i = 0; i < 5; i++)
    {
        float h = 0.01 + 0.12 * float(i) / 4.0;
        float d = GetDist(p + h * n);
        occ += (h - d) * sca;
        sca *= 0.95;
    }
    return clamp(1.0 - 3.0 * occ, 0.0, 1.0);
}

float4 PSMain(PSInput input) : SV_TARGET
{
    float2 uv = input.uv - 0.5;
    uv.x *= iResolution.x / iResolution.y;
    
    // Camera setup
    float3 ro = float3(0.0, 1.5, -4.0);
    float3 rd = normalize(float3(uv.x, uv.y, 1.0));
    
    // Light position
    float3 lightPos = float3(3.0, 5.0, -2.0);
    
    // Raymarching
    float d = RayMarch(ro, rd);
    
    float3 col = float3(0.0, 0.0, 0.0);
    
    if (d < MAX_DIST)
    {
        float3 p = ro + rd * d;
        float3 n = GetNormal(p);
        float3 l = normalize(lightPos - p);
        float3 v = normalize(ro - p);
        float3 r = reflect(-l, n);
        
        // Material color based on position
        float3 matCol = float3(0.4, 0.6, 0.9);
        if (p.y < -0.49)
        {
            // Checkerboard floor
            float checker = fmod(floor(p.x) + floor(p.z), 2.0);
            matCol = lerp(float3(0.2, 0.2, 0.2), float3(0.8, 0.8, 0.8), checker);
        }
        
        // Lighting
        float diff = max(dot(n, l), 0.0);
        float spec = pow(max(dot(r, v), 0.0), 32.0);
        float ao = GetAO(p, n);
        float shadow = GetShadow(p + n * 0.01, l, 0.01, length(lightPos - p), 16.0);
        
        // Ambient
        float3 ambient = float3(0.1, 0.12, 0.15);
        
        col = matCol * (ambient * ao + diff * shadow) + float3(1.0, 1.0, 1.0) * spec * shadow * 0.5;
        
        // Fog
        col = lerp(col, float3(0.05, 0.05, 0.1), 1.0 - exp(-0.02 * d * d));
    }
    else
    {
        // Background gradient
        col = lerp(float3(0.1, 0.1, 0.15), float3(0.02, 0.02, 0.05), input.uv.y);
    }
    
    // Gamma correction
    col = pow(col, float3(0.4545, 0.4545, 0.4545));
    
    return float4(col, 1.0);
}
