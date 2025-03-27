Shader "Nihit/Glass"
{
    Properties
    {
        _IOR("IOR", Range(1, 5)) = 1.5
        _ChromaticAberration("ChromaticAberration", Range(0, 0.2)) = 0
        _TintColor("TintColor", Color) = (0, 1, 0.8, 0)
        _TintTexture("TintTexture", 2D) = "white" {}
        _TintTextureDistortion("TintTextureDistortion", Range(0, 1)) = 0
        [Normal][NoScaleOffset]_NormalMap("NormalMap", 2D) = "bump" {}
        _NormalStrength("NormalStrength", Range(0.01, 10)) = 0.1
        _DistortionStrength("DistortionStrength", Range(0.01, 10)) = 1
        _DistortionTiling("DistortionTiling", Range(0.01, 1000)) = 400
        _Metallic("Metallic", Range(0, 1)) = 0.1
        _Smoothness("Smoothness", Range(0, 1)) = 1
        _ReflectionStrength("ReflectionStrength", Range(0, 5)) = 0.1
        [ToggleUI]_Emission("Emission", Float) = 0
    }
    SubShader
    {
        Tags
        {
            "RenderPipeline"="UniversalPipeline"
            "RenderType"="Transparent"
            "UniversalMaterialType" = "Lit"
            "Queue"="Transparent"
        }

        Pass
        {
            Name "Universal Forward"
            Tags
            {
                "LightMode" = "UniversalForward"
            }

            Cull Back
            Blend SrcAlpha OneMinusSrcAlpha, One OneMinusSrcAlpha
            ZTest LEqual
            ZWrite Off

            HLSLPROGRAM

            #pragma target 2.0
            #pragma multi_compile_instancing
            #pragma multi_compile_fog
            #pragma vertex vert
            #pragma fragment frag

            #define _NORMALMAP 1
            #define _NORMAL_DROPOFF_TS 1
            #define ATTRIBUTES_NEED_NORMAL
            #define ATTRIBUTES_NEED_TANGENT
            #define VARYINGS_NEED_POSITION_WS
            #define VARYINGS_NEED_NORMAL_WS
            #define VARYINGS_NEED_TANGENT_WS
            #define VARYINGS_NEED_TEXCOORD0
            #define VARYINGS_NEED_SHADOW_COORD
            #define REQUIRE_OPAQUE_TEXTURE

            #define SHADERPASS_SHADOWCASTER (3)
            #define SHADERPASS_META (4)

            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Texture.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Hashes.hlsl"

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Input.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareOpaqueTexture.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ShaderVariablesFunctions.deprecated.hlsl"

            CBUFFER_START(UnityPerMaterial)
                float _IOR;
                float _ChromaticAberration;
                float _Emission;
                float _DistortionStrength;
                float _NormalStrength;
                float4 _TintColor;
                float _DistortionTiling;
                float _Metallic;
                float _Smoothness;
                float _ReflectionStrength;
                float4 _TintTexture_TexelSize;
                float4 _TintTexture_ST;
                float _TintTextureDistortion;
                float4 _NormalMap_TexelSize;
            CBUFFER_END

            SAMPLER(SamplerState_Linear_Repeat);
            TEXTURE2D(_TintTexture);
            SAMPLER(sampler_TintTexture);
            TEXTURE2D(_NormalMap);
            SAMPLER(sampler_NormalMap);

#if (SHADERPASS == SHADERPASS_SHADOWCASTER)
            float3 _LightDirection;
            float3 _LightPosition;
#endif

            struct Attributes
            {
                float3 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float4 tangentOS : TANGENT;
                float4 uv0 : TEXCOORD0;
                float4 uv1 : TEXCOORD1;
                float4 uv2 : TEXCOORD2;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;
                float3 normalWS : TEXCOORD1;
                float4 tangentWS : TEXCOORD2;
                float4 texCoord0 : TEXCOORD3;
                float3 sh : TEXCOORD4;
                float4 fogFactorAndVertexLight : TEXCOORD5;
            };

            Varyings vert(Attributes input)
            {
                Varyings output = (Varyings)0;

                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);

                float3 positionWS = TransformObjectToWorld(input.positionOS);
                float3 normalWS = TransformObjectToWorldNormal(input.normalOS);
                float4 tangentWS = float4(TransformObjectToWorldDir(input.tangentOS.xyz), input.tangentOS.w);

                output.positionWS = positionWS;
                output.normalWS = normalWS;
                output.tangentWS = tangentWS;

#if (SHADERPASS == SHADERPASS_SHADOWCASTER)
    #if _CASTING_PUNCTUAL_LIGHT_SHADOW
                float3 lightDirectionWS = normalize(_LightPosition - positionWS);
    #else
                float3 lightDirectionWS = _LightDirection;
    #endif
                output.positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, lightDirectionWS));
    #if UNITY_REVERSED_Z
                output.positionCS.z = min(output.positionCS.z, UNITY_NEAR_CLIP_VALUE);
    #else
                output.positionCS.z = max(output.positionCS.z, UNITY_NEAR_CLIP_VALUE);
    #endif
#elif (SHADERPASS == SHADERPASS_META)
                output.positionCS = UnityMetaVertexPosition(input.positionOS, input.uv1.xy, input.uv2.xy, unity_LightmapST, unity_DynamicLightmapST);
#else
                output.positionCS = TransformWorldToHClip(positionWS);
#endif

                output.texCoord0 = input.uv0;

#if (SHADERPASS == SHADERPASS_FORWARD) || (SHADERPASS == SHADERPASS_GBUFFER)
                OUTPUT_LIGHTMAP_UV(input.uv1, unity_LightmapST, output.staticLightmapUV);
                OUTPUT_SH(normalWS, output.sh);
#endif

                return output;
            }

            struct SurfaceDescriptionInputs
            {
                float3 WorldSpaceNormal;
                float3 TangentSpaceNormal;
                float3 WorldSpaceTangent;
                float3 WorldSpaceBiTangent;
                float3 WorldSpaceViewDirection;
                float3 WorldSpacePosition;
                float3 AbsoluteWorldSpacePosition;
                float2 NDCPosition;
                float2 PixelPosition;
                float4 uv0;
            };

            SurfaceDescriptionInputs BuildSurfaceDescriptionInputs(Varyings input)
            {
                SurfaceDescriptionInputs output;
                ZERO_INITIALIZE(SurfaceDescriptionInputs, output);

                float3 unnormalizedNormalWS = input.normalWS;
                const float renormFactor = 1.0 / length(unnormalizedNormalWS);

                float crossSign = (input.tangentWS.w > 0.0 ? 1.0 : -1.0) * GetOddNegativeScale();
                float3 bitang = crossSign * cross(input.normalWS.xyz, input.tangentWS.xyz);

                output.WorldSpaceNormal = renormFactor * input.normalWS.xyz;
                output.TangentSpaceNormal = float3(0.0f, 0.0f, 1.0f);

                output.WorldSpaceTangent = renormFactor * input.tangentWS.xyz;
                output.WorldSpaceBiTangent = renormFactor * bitang;

                output.WorldSpaceViewDirection = GetWorldSpaceNormalizeViewDir(input.positionWS);
                output.WorldSpacePosition = input.positionWS;

                output.AbsoluteWorldSpacePosition = GetAbsolutePositionWS(input.positionWS);

#if UNITY_UV_STARTS_AT_TOP
                output.PixelPosition = float2(input.positionCS.x, (_ProjectionParams.x < 0) ? (_ScaledScreenParams.y - input.positionCS.y) : input.positionCS.y);
#else
                output.PixelPosition = float2(input.positionCS.x, (_ProjectionParams.x > 0) ? (_ScaledScreenParams.y - input.positionCS.y) : input.positionCS.y);
#endif

                output.NDCPosition = output.PixelPosition.xy / _ScaledScreenParams.xy;
                output.NDCPosition.y = 1.0f - output.NDCPosition.y;

                output.uv0 = input.texCoord0;

                return output;
            }

            struct SurfaceDescription
            {
                float3 BaseColor;
                float3 NormalTS;
                float3 Emission;
                float Metallic;
                float Smoothness;
                float Occlusion;
                float Alpha;
            };

            inline float ValueNoise(float2 uv)
            {
                float2 i = floor(uv);
                float2 f = frac(uv);

                f = f * f * (3.0 - 2.0 * f);
                uv = abs(frac(uv) - 0.5);

                float2 c0 = i + float2(0.0, 0.0);
                float2 c1 = i + float2(1.0, 0.0);
                float2 c2 = i + float2(0.0, 1.0);
                float2 c3 = i + float2(1.0, 1.0);

                float r0; Hash_LegacySine_2_1_float(c0, r0);
                float r1; Hash_LegacySine_2_1_float(c1, r1);
                float r2; Hash_LegacySine_2_1_float(c2, r2);
                float r3; Hash_LegacySine_2_1_float(c3, r3);

                float bottomOfGrid = lerp(r0, r1, f.x);
                float topOfGrid = lerp(r2, r3, f.x);
                float t = lerp(bottomOfGrid, topOfGrid, f.y);
                return t;
            }

            float SimpleNoise(float2 UV, float Scale)
            {
                float t = 0.0;

                float freq = pow(2.0, float(0));
                float amp = pow(0.5, float(3-0));
                t += ValueNoise(float2(UV.x*Scale/freq, UV.y*Scale/freq))*amp;

                freq = pow(2.0, float(1));
                amp = pow(0.5, float(3-1));
                t += ValueNoise(float2(UV.x*Scale/freq, UV.y*Scale/freq))*amp;

                freq = pow(2.0, float(2));
                amp = pow(0.5, float(3-2));
                t += ValueNoise(float2(UV.x*Scale/freq, UV.y*Scale/freq))*amp;

                return t;
            }

            float3 NormalFromHeight(float In, float Strength, float3 Position, float3x3 TangentMatrix)
            {
                float3 worldDerivativeX = ddx(Position);
                float3 worldDerivativeY = ddy(Position);

                float3 crossX = cross(TangentMatrix[2].xyz, worldDerivativeX);
                float3 crossY = cross(worldDerivativeY, TangentMatrix[2].xyz);

                float d = dot(worldDerivativeX, crossY);
                float sgn = d < 0.0 ? (-1.0f) : 1.0f;
                float surface = sgn / max(0.000000000000001192093f, abs(d));

                float dHdx = ddx(In);
                float dHdy = ddy(In);

                float3 surfGrad = surface * (dHdx*crossY + dHdy*crossX);

                float3 Out;
                Out = SafeNormalize(TangentMatrix[2].xyz - (Strength * surfGrad));
                Out = TransformWorldToTangent(Out, TangentMatrix);

                return Out;
            }

            float2 RefractUV(float _Refractive_Index_Target, float _Refractive_Index_Origin, float3 _NormalMapVector, float3 WorldSpaceNormal, float3 AbsoluteWorldSpacePosition)
            {
                float3 normalBlend = SafeNormalize(float3(WorldSpaceNormal.rg + _NormalMapVector.rg, WorldSpaceNormal.b * _NormalMapVector.b));
                float ETA = _Refractive_Index_Origin / _Refractive_Index_Target;
                float3 refractedVector = refract(
                    normalize(-1 * mul((float3x3)UNITY_MATRIX_M, transpose(mul(UNITY_MATRIX_I_M, UNITY_MATRIX_I_V)) [2].xyz)),
                    normalize(normalBlend),
                    ETA);

                float3 positionRefracted = AbsoluteWorldSpacePosition + normalize(refractedVector);
                float4 positionRefractedProjected = mul(UNITY_MATRIX_VP, float4(positionRefracted, 1.0));
                float4 screenPos = ComputeScreenPos(positionRefractedProjected);
                float2 sceneUV = screenPos.xy / screenPos.ww;
                return sceneUV;
            }

            SurfaceDescription SurfaceDescriptionFunction(SurfaceDescriptionInputs IN)
            {
                SurfaceDescription surface = (SurfaceDescription)0;
                UnityTexture2D unityTexture2D = UnityBuildTexture2DStruct(_TintTexture);

                float3x3 tbnMatrix = float3x3(IN.WorldSpaceTangent, IN.WorldSpaceBiTangent, IN.WorldSpaceNormal);
                float tiledNoise = SimpleNoise(IN.uv0.xy, _DistortionTiling);

                float3 noiseDistortion = NormalFromHeight(tiledNoise, _DistortionStrength/5000.0, IN.WorldSpacePosition, tbnMatrix);

                float3 noiseTintTextureDistortion = noiseDistortion * _TintTextureDistortion.xxx;
                float2 distortedUV = IN.uv0.xy + noiseTintTextureDistortion.xy;
                float4 texColor = SAMPLE_TEXTURE2D(unityTexture2D.tex, unityTexture2D.samplerstate, unityTexture2D.GetTransformedUV(distortedUV));
                float4 tintedTexColor = texColor * _TintColor;

                UnityTexture2D unityTexture2DNormal = UnityBuildTexture2DStructNoScale(_NormalMap);
                float4 texNormal = SAMPLE_TEXTURE2D(unityTexture2DNormal.tex, unityTexture2DNormal.samplerstate, unityTexture2D.GetTransformedUV(distortedUV));
                texNormal.xyz = UnpackNormal(texNormal);
                float3 texNormalStrength = float3(texNormal.xy * _NormalStrength, lerp(1, texNormal.z, saturate(_NormalStrength)));;

                float2 refractUV0 = RefractUV(_IOR, 1.0, texNormalStrength, IN.WorldSpaceNormal, IN.AbsoluteWorldSpacePosition);
                float3 sceenPos0 = float3(refractUV0, 0) + noiseDistortion;
                float3 sceneColor0 = SampleSceneColor(sceenPos0.xy);

                float2 refractUV1 = RefractUV(_IOR * (1.0 + _ChromaticAberration), 1.0, texNormalStrength, IN.WorldSpaceNormal, IN.AbsoluteWorldSpacePosition);
                float3 sceenPos1 = float3(refractUV1, 0) + noiseDistortion;
                float3 sceneColor1 = SampleSceneColor(sceenPos1.xy);

                float2 refractUV2 = RefractUV(_IOR * (1.0 + _ChromaticAberration * 2.0), 1.0, texNormalStrength, IN.WorldSpaceNormal, IN.AbsoluteWorldSpacePosition);
                float3 sceenPos2 = float3(refractUV2, 0) + noiseDistortion;
                float3 sceneColor2 = SampleSceneColor(sceenPos2.xy);

                float3 sceneColor = float3(sceneColor0.r, sceneColor1.g, sceneColor1.b);

                float3 tintedTexSceneColor = tintedTexColor.xyz * sceneColor;

                float3 reflectVec = reflect(-IN.WorldSpaceViewDirection, IN.WorldSpaceNormal);
                float3 refProbeColor = DecodeHDREnvironment(SAMPLE_TEXTURECUBE_LOD(unity_SpecCube0, samplerunity_SpecCube0, reflectVec, 0), unity_SpecCube0_HDR);

                float3 refProbeColorWithStrength = refProbeColor * _ReflectionStrength.xxx;

                float3 tintedTexSceneColorEmission = _Emission ? tintedTexSceneColor : float3(0, 0, 0);

                surface.BaseColor = tintedTexSceneColor;
                surface.NormalTS = noiseDistortion + texNormalStrength;
                surface.Emission = lerp(tintedTexSceneColorEmission, refProbeColorWithStrength, _ReflectionStrength/5.0);
                surface.Metallic = _Metallic;
                surface.Smoothness = _Smoothness;
                surface.Occlusion = 1.0;
                surface.Alpha = tintedTexColor.a + _TintColor.a;

                return surface;
            }

            void InitializeInputData(Varyings input, SurfaceDescription surfaceDescription, out InputData inputData)
            {
                inputData = (InputData)0;

                inputData.positionWS = input.positionWS;

#ifdef _NORMALMAP
                float crossSign = (input.tangentWS.w > 0.0 ? 1.0 : -1.0) * GetOddNegativeScale();
                float3 bitangent = crossSign * cross(input.normalWS.xyz, input.tangentWS.xyz);

                inputData.tangentToWorld = half3x3(input.tangentWS.xyz, bitangent.xyz, input.normalWS.xyz);

    #if _NORMAL_DROPOFF_TS
                inputData.normalWS = TransformTangentToWorld(surfaceDescription.NormalTS, inputData.tangentToWorld);
    #endif

#else
                inputData.normalWS = input.normalWS;
#endif

                inputData.normalWS = NormalizeNormalPerPixel(inputData.normalWS);
                inputData.viewDirectionWS = GetWorldSpaceNormalizeViewDir(input.positionWS);

                inputData.shadowCoord = float4(0, 0, 0, 0);

                inputData.fogCoord = InitializeInputDataFog(float4(input.positionWS, 1.0), input.fogFactorAndVertexLight.x);
                inputData.vertexLighting = input.fogFactorAndVertexLight.yzw;

                inputData.bakedGI = SAMPLE_GI(input.staticLightmapUV, input.sh, inputData.normalWS);

                inputData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(input.positionCS);
                inputData.shadowMask = SAMPLE_SHADOWMASK(input.staticLightmapUV);
            }

            half4 frag(Varyings input) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                SurfaceDescriptionInputs surfaceDescriptionInputs = BuildSurfaceDescriptionInputs(input);
                SurfaceDescription surfaceDescription = SurfaceDescriptionFunction(surfaceDescriptionInputs);

                bool isTransparent = false;
                half alpha = half(1.0);

                InputData inputData;
                InitializeInputData(input, surfaceDescription, inputData);

                float3 specular = 0;
                float metallic = surfaceDescription.Metallic;

                half3 normalTS = half3(0, 0, 0);

#if defined(_NORMALMAP) && defined(_NORMAL_DROPOFF_TS)
                normalTS = surfaceDescription.NormalTS;
#endif

                SurfaceData surface;
                surface.albedo              = surfaceDescription.BaseColor;
                surface.metallic            = saturate(metallic);
                surface.specular            = specular;
                surface.smoothness          = saturate(surfaceDescription.Smoothness),
                surface.occlusion           = surfaceDescription.Occlusion,
                surface.emission            = surfaceDescription.Emission,
                surface.alpha               = saturate(alpha);
                surface.normalTS            = normalTS;
                surface.clearCoatMask       = 0;
                surface.clearCoatSmoothness = 1;

                surface.albedo = AlphaModulate(surface.albedo, surface.alpha);

                half4 color = UniversalFragmentPBR(inputData, surface);
                color.rgb = MixFog(color.rgb, inputData.fogCoord);

                color.a = OutputAlpha(color.a, isTransparent);

                return color;
            }

            ENDHLSL
        }
    }
} // Copyright Nihit Saxena 2025