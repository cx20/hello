struct PSInput
{
    float4 position : SV_POSITION;
    float2 texcoord : TEXCOORD0;
};

Texture2D tex0 : register(t0);
SamplerState samp0 : register(s0);

PSInput VSMain(float4 position : POSITION, float2 texcoord : TEXCOORD0)
{
    PSInput result;
    result.position = position;
    result.texcoord = texcoord;
    return result;
}

float4 PSMain(PSInput input) : SV_TARGET
{
    return tex0.Sample(samp0, input.texcoord);
}
