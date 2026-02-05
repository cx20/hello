struct VS_OUTPUT
{
    float4 position : SV_POSITION;
    float4 color : COLOR0;
};

VS_OUTPUT VS(float4 position : POSITION, float4 color : COLOR)
{
    VS_OUTPUT output = (VS_OUTPUT)0;

    output.position = position;
    output.color = color;

    return output;
}

float4 PS( VS_OUTPUT input ) : SV_Target
{
    return input.color;
}
