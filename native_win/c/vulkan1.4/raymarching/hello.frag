#version 450
#extension GL_ARB_separate_shader_objects : enable

layout(location = 0) in vec2 fragCoord;
layout(location = 0) out vec4 outColor;

// Push constants for time and resolution
layout(push_constant) uniform PushConstants {
    float iTime;
    float padding;
    vec2 iResolution;
} pc;

const int MAX_STEPS = 100;
const float MAX_DIST = 100.0;
const float SURF_DIST = 0.001;

// Signed Distance Functions
float sdSphere(vec3 p, float r) {
    return length(p) - r;
}

float sdBox(vec3 p, vec3 b) {
    vec3 q = abs(p) - b;
    return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0);
}

float sdTorus(vec3 p, vec2 t) {
    vec2 q = vec2(length(p.xz) - t.x, p.y);
    return length(q) - t.y;
}

// Smooth minimum for blending shapes
float smin(float a, float b, float k) {
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}

// Scene distance function
float GetDist(vec3 p) {
    // Animated sphere
    float sphere = sdSphere(p - vec3(sin(pc.iTime) * 1.5, 0.5 + sin(pc.iTime * 2.0) * 0.3, 0.0), 0.5);
    
    // Rotating torus - match HLSL rotation method
    float angle = pc.iTime * 0.5;
    vec3 torusPos = p - vec3(0.0, 0.5, 0.0);
    float cosA = cos(angle);
    float sinA = sin(angle);
    vec2 rotatedXZ = vec2(cosA * torusPos.x - sinA * torusPos.z, sinA * torusPos.x + cosA * torusPos.z);
    torusPos.x = rotatedXZ.x;
    torusPos.z = rotatedXZ.y;
    
    float angle2 = angle * 0.7;
    float cosA2 = cos(angle2);
    float sinA2 = sin(angle2);
    vec2 rotatedXY = vec2(cosA2 * torusPos.x - sinA2 * torusPos.y, sinA2 * torusPos.x + cosA2 * torusPos.y);
    torusPos.x = rotatedXY.x;
    torusPos.y = rotatedXY.y;
    
    float torus = sdTorus(torusPos, vec2(0.8, 0.2));  // radius 0.8 (was 0.6)
    
    // Ground plane
    float plane = p.y + 0.5;
    
    // Combine with smooth min
    float d = smin(sphere, torus, 0.3);
    d = min(d, plane);
    
    return d;
}

// Raymarching
float RayMarch(vec3 ro, vec3 rd) {
    float d = 0.0;
    for (int i = 0; i < MAX_STEPS; i++) {
        vec3 p = ro + rd * d;
        float ds = GetDist(p);
        d += ds;
        if (d > MAX_DIST || ds < SURF_DIST) break;
    }
    return d;
}

// Calculate normal
vec3 GetNormal(vec3 p) {
    float d = GetDist(p);
    vec2 e = vec2(0.001, 0.0);
    vec3 n = d - vec3(
        GetDist(p - e.xyy),
        GetDist(p - e.yxy),
        GetDist(p - e.yyx)
    );
    return normalize(n);
}

// Soft shadow - 64 iterations (was 32)
float GetShadow(vec3 ro, vec3 rd, float mint, float maxt, float k) {
    float res = 1.0;
    float t = mint;
    for (int i = 0; i < 64; i++) {
        if (t >= maxt) break;
        float h = GetDist(ro + rd * t);
        if (h < 0.001) return 0.0;
        res = min(res, k * h / t);
        t += h;
    }
    return res;
}

// Ambient occlusion
float GetAO(vec3 p, vec3 n) {
    float occ = 0.0;
    float sca = 1.0;
    for (int i = 0; i < 5; i++) {
        float h = 0.01 + 0.12 * float(i) / 4.0;
        float d = GetDist(p + h * n);
        occ += (h - d) * sca;
        sca *= 0.95;
    }
    return clamp(1.0 - 3.0 * occ, 0.0, 1.0);
}

void main() {
    // UV: match HLSL range [-0.5, 0.5] (was [-1, 1])
    vec2 uv = fragCoord - 0.5;
    uv.x *= pc.iResolution.x / pc.iResolution.y;
    
    // Camera setup - match HLSL exactly
    vec3 ro = vec3(0.0, 1.5, -4.0);
    vec3 rd = normalize(vec3(uv.x, uv.y, 1.0));
    
    // Light position - match HLSL (z = -2.0, was +2.0)
    vec3 lightPos = vec3(3.0, 5.0, -2.0);
    
    // Raymarching
    float d = RayMarch(ro, rd);
    
    vec3 col = vec3(0.0);
    
    if (d < MAX_DIST) {
        vec3 p = ro + rd * d;
        vec3 n = GetNormal(p);
        vec3 l = normalize(lightPos - p);
        vec3 v = normalize(ro - p);
        vec3 r = reflect(-l, n);
        
        // Material color - match HLSL (was 0.4, 0.6, 0.8)
        vec3 matCol = vec3(0.4, 0.6, 0.9);
        if (p.y < -0.49) {
            // Checkerboard floor - match HLSL colors
            float check = mod(floor(p.x) + floor(p.z), 2.0);
            matCol = mix(vec3(0.2, 0.2, 0.2), vec3(0.8, 0.8, 0.8), check);
        }
        
        // Lighting
        float diff = max(dot(n, l), 0.0);
        float spec = pow(max(dot(r, v), 0.0), 32.0);
        float ao = GetAO(p, n);
        float shadow = GetShadow(p + n * 0.01, l, 0.01, length(lightPos - p), 16.0);
        
        // Ambient
        vec3 ambient = vec3(0.1, 0.12, 0.15);
        
        col = matCol * (ambient * ao + diff * shadow) + vec3(1.0) * spec * shadow * 0.5;
        
        // Fog
        col = mix(col, vec3(0.05, 0.05, 0.1), 1.0 - exp(-0.02 * d * d));
    } else {
        // Background gradient - match HLSL
        col = mix(vec3(0.1, 0.1, 0.15), vec3(0.02, 0.02, 0.05), fragCoord.y);
    }
    
    // Gamma correction
    col = pow(col, vec3(0.4545));
    
    outColor = vec4(col, 1.0);
}
