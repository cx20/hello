struct VS_OUTPUT
{
    float4 position : SV_POSITION;
    float2 texcoord : TEXCOORD0;
};

Texture2D tex0 : register(t0);
SamplerState samp0 : register(s0);

VS_OUTPUT VS(float4 position : POSITION, float2 texcoord : TEXCOORD)
{
    VS_OUTPUT output = (VS_OUTPUT)0;

    output.position = position;
    output.texcoord = texcoord;

    return output;
}

float4 PS( VS_OUTPUT input ) : SV_Target
{
    return tex0.Sample(samp0, input.texcoord);
}
