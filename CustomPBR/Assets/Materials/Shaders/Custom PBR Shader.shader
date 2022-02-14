Shader "Unlit/Custom PBR Shader"
{
    Properties
    {
        _AlbedoTex ("Albedo Texture", 2D) = "white" {}
        _Albedo ("Albedo", Color) = (1,1,1,1)
        _MetallicTex ("Metallic Texture", 2D) = "white" {}
        _Metallic ("Metallic", float) = 0
        _RoughnessTex ("Roughness Texture", 2D) = "white" {}
        _Roughness ("Roughness", float) = 0
        _AOTex ("Ambient Occlusion Texture", 2D) = "white" {}
        _AmbientOcclusion ("Ambient Occlusion", float) = 1
        _LightColor ("LightColor", Color) = (1,1,1,1)
    }
    SubShader
    {
        Tags
        {
            "RenderType"="Opaque"
        }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog

            #include "UnityCG.cginc"
            //#include "Lighting.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
            };

            struct v2f
            {
                UNITY_FOG_COORDS(2)
                float4 vertex : SV_POSITION;
                float3 normal : TEXCOORD1;
                float2 uv : TEXCOORD0;
            };
            
            sampler2D _AlbedoTex;
            float4 _Albedo;
            sampler2D _MetallicTex;
            float _Metallic;
            sampler2D _RoughnessTex;
            float _Roughness;
            sampler2D _AOTex;
            float _AmbientOcclusion;
            float4 _LightColor;


            float DistributionGGX(float3 N, float3 H, float roughness);
            float GeometrySchlickGGX(float NdotV, float roughness);
            float GeometrySmith(float3 N, float3 V, float3 L, float roughness);
            float3 fresnelSchlick(float cosTheta, float3 F0);

            v2f vert(appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.normal = v.normal;
                o.uv = v.uv;
                UNITY_TRANSFER_FOG(o, o.vertex);
                return o;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                /*float3 direction, lightColor;
                float distAtten, shadowAtten;*/
                //CalculateMainLight(i.vertex, direction, lightColor, distAtten, shadowAtten);
                float3 N = normalize(i.normal);
                float3 V = normalize(UnityWorldSpaceViewDir(i.vertex));

                _Albedo *=  pow(tex2D(_AlbedoTex, i.uv), 2.2);
                _Metallic *= tex2D(_MetallicTex, i.uv).r;
                //_Roughness *= tex2D(_RoughnessTex, i.uv);
                _AmbientOcclusion *= tex2D(_AOTex, i.uv).r;

                float3 F0 = 0.08;
                F0 = lerp(F0, _Albedo, _Metallic);

                // reflectance equation
                float3 Lo = 0.0;
                {
                    // calculate per-light radiance
                    float3 L = normalize(UnityWorldSpaceLightDir(i.vertex));
                    float3 H = normalize(V + L);
                    //float distance = length(_WorldSpaceLightPos0 - i.vertex);
                    //float3 radiance = _LightColor * attenuation;

                    // cook-torrance brdf
                    float NDF = DistributionGGX(N, H, _Roughness);
                    float G = GeometrySmith(N, V, L, _Roughness);
                    float3 F = fresnelSchlick(max(dot(H, V), 0.0), F0);

                    float3 kS = F;
                    float3 kD = 1.0 - kS;
                    kD *= 1.0 - _Metallic;

                    float3 numerator = NDF * G * F;
                    float denominator = 4.0 * max(dot(N, V), 0.0) * max(dot(N, L), 0.0);
                    float3 specular = numerator / max(denominator, 0.001);

                    // add to outgoing radiance Lo
                    float NdotL = max(dot(N, L), 0.0);
                    Lo += _LightColor * (kD * pow(_Albedo, 2.2) / UNITY_PI + specular) * NdotL;
                }

                // sample the texture
                float4 ambient = 0.03 * _Albedo * _AmbientOcclusion;
                fixed4 col = ambient + float4(Lo, 1);
                col = col / (col + 1.0);
                col = pow(col, 1.0/2.2);
                // apply fog
                UNITY_APPLY_FOG(i.fogCoord, col);
                return col;
            }

            float3 fresnelSchlick(float cosTheta, float3 F0)
            {
                return F0 + (1.0 - F0) * pow(clamp(1.0 - cosTheta, 0.0, 1.0), 5.0);
            }

            float DistributionGGX(float3 N, float3 H, float roughness)
            {
                float a = roughness * roughness;
                float a2 = a * a;
                float NdotH = max(dot(N, H), 0.0);
                float NdotH2 = NdotH * NdotH;

                float num = a2;
                float denom = (NdotH2 * (a2 - 1.0) + 1.0);
                denom = UNITY_PI * denom * denom;

                return num / denom;
            }

            float GeometrySchlickGGX(float NdotV, float roughness)
            {
                float r = (roughness + 1.0);
                float k = (r * r) / 8.0;

                float num = NdotV;
                float denom = NdotV * (1.0 - k) + k;

                return num / denom;
            }

            float GeometrySmith(float3 N, float3 V, float3 L, float roughness)
            {
                float NdotL = max(dot(N, L), 0.0);
                float NdotV = max(dot(N, V), 0.0);
                float ggx1 = GeometrySchlickGGX(NdotL, roughness);
                float ggx2 = GeometrySchlickGGX(NdotV, roughness);

                return ggx1 * ggx2;
            }
            ENDCG
        }
    }
}