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
    
    // Rotating torus
    float angle = pc.iTime * 0.5;
    vec3 torusPos = p - vec3(0.0, 0.5, 0.0);
    torusPos.xz = mat2(cos(angle), -sin(angle), sin(angle), cos(angle)) * torusPos.xz;
    torusPos.xy = mat2(cos(angle * 0.7), -sin(angle * 0.7), sin(angle * 0.7), cos(angle * 0.7)) * torusPos.xy;
    float torus = sdTorus(torusPos, vec2(0.6, 0.2));
    
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

// Soft shadow
float GetShadow(vec3 ro, vec3 rd, float mint, float maxt, float k) {
    float res = 1.0;
    float t = mint;
    for (int i = 0; i < 32; i++) {
        float h = GetDist(ro + rd * t);
        res = min(res, k * h / t);
        if (res < 0.001 || t > maxt) break;
        t += clamp(h, 0.01, 0.2);
    }
    return clamp(res, 0.0, 1.0);
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

// Get material color based on position - matching OpenGL version (blue color)
vec3 GetMaterial(vec3 p) {
    // Ground - checkerboard pattern
    if (p.y < -0.49) {
        float check = mod(floor(p.x) + floor(p.z), 2.0);
        return mix(vec3(0.2, 0.2, 0.25), vec3(0.5, 0.5, 0.55), check);
    }
    
    // Objects - blue color like OpenGL version
    return vec3(0.4, 0.6, 0.8);
}

void main() {
    // Normalized coordinates
    vec2 uv = fragCoord;
    uv = uv * 2.0 - 1.0;
    uv.x *= pc.iResolution.x / pc.iResolution.y;
    
    // Camera setup - fixed position (no rotation)
    float camDist = 2.5;
    float camHeight = 0.8;
    
    vec3 ro = vec3(0.0, camHeight, camDist);  // Fixed camera position
    vec3 target = vec3(0.0, 0.2, 0.0);
    
    // Camera matrix
    vec3 forward = normalize(target - ro);
    vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), forward));
    vec3 up = cross(forward, right);
    
    vec3 rd = normalize(forward + uv.x * right + uv.y * up);
    
    // Raymarching
    float d = RayMarch(ro, rd);
    
    vec3 col = vec3(0.0);
    
    if (d < MAX_DIST) {
        vec3 p = ro + rd * d;
        vec3 n = GetNormal(p);
        vec3 matCol = GetMaterial(p);
        
        // Lighting
        vec3 lightPos = vec3(3.0, 5.0, 2.0);
        vec3 l = normalize(lightPos - p);
        vec3 v = normalize(ro - p);
        vec3 r = reflect(-l, n);
        
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
        // Background gradient
        col = mix(vec3(0.1, 0.1, 0.15), vec3(0.02, 0.02, 0.05), fragCoord.y);
    }
    
    // Gamma correction
    col = pow(col, vec3(0.4545));
    
    outColor = vec4(col, 1.0);
}
