struct VSOutput
{
    float4 position : SV_Position;
};

struct PSInput
{
    float4 position : SV_Position;
    float4 color    : COLOR;
};

// The vertex shader outputs one point at the center.
// The geometry shader will expand this point into a triangle.
VSOutput VSMain(uint vertexID : SV_VertexID)
{
    VSOutput output;
    output.position = float4(0.0f, 0.0f, 0.0f, 1.0f);
    return output;
}

// The geometry shader takes one point and emits one triangle.
[maxvertexcount(3)]
void GSMain(point VSOutput input[1], inout TriangleStream<PSInput> triStream)
{
    PSInput v0;
    PSInput v1;
    PSInput v2;

    v0.position = float4( 0.0f,  0.5f, 0.0f, 1.0f);
    v0.color    = float4( 1.0f,  0.0f, 0.0f, 1.0f);

    v1.position = float4( 0.5f, -0.5f, 0.0f, 1.0f);
    v1.color    = float4( 0.0f,  1.0f, 0.0f, 1.0f);

    v2.position = float4(-0.5f, -0.5f, 0.0f, 1.0f);
    v2.color    = float4( 0.0f,  0.0f, 1.0f, 1.0f);

    triStream.Append(v0);
    triStream.Append(v1);
    triStream.Append(v2);
    triStream.RestartStrip();
}

float4 PSMain(PSInput input) : SV_Target
{
    return input.color;
}