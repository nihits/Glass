Shader "Nihit/GlassURP"
{
    Properties
    {
        _TintTexture("TintTexture", 2D) = "white" {}
        _DistortionOnTexture("DistortionOnTexture", Range(0, 1)) = 0
        _TintColor("TintColor", Color) = (0, 1, 0.8042793, 0)
        _Metallic("Metallic", Range(0, 1)) = 0.1
        _Smoothness("Smoothness", Range(0, 1)) = 1
        _NormalStrength("NormalStrength", Range(0.01, 10)) = 0.1
        _ReflectionStrength("ReflectionStrength", Range(0, 5)) = 0.1
        _DisortStrength("DisortStrength", Range(0.01, 10)) = 1
        _Tiling("Tiling", Range(0.01, 1000)) = 400
        _Offset("Offset", Vector) = (0, 0, 0, 0)
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

            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Texture.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Hashes.hlsl"

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Input.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareOpaqueTexture.hlsl"

            CBUFFER_START(UnityPerMaterial)
                float _DisortStrength;
                float _NormalStrength;
                float4 _TintColor;
                float2 _Offset;
                float _Tiling;
                float _Metallic;
                float _Smoothness;
                float _ReflectionStrength;
                float4 _TintTexture_TexelSize;
                float4 _TintTexture_ST;
                float _DistortionOnTexture;
            CBUFFER_END

            SAMPLER(SamplerState_Linear_Repeat);
            TEXTURE2D(_TintTexture);
            SAMPLER(sampler_TintTexture);

#if (SHADERPASS == SHADERPASS_SHADOWCASTER)
            float3 _LightDirection;
            float3 _LightPosition;
#endif

            ////////////////////////////////////////////////////////////////////

            // Vert

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

            Varyings BuildVaryings(Attributes input)
            {
                Varyings output = (Varyings)0;

                UNITY_SETUP_INSTANCE_ID(input);

                UNITY_TRANSFER_INSTANCE_ID(input, output);

                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);

                float3 positionWS = TransformObjectToWorld(input.positionOS);

#ifdef ATTRIBUTES_NEED_NORMAL
                float3 normalWS = TransformObjectToWorldNormal(input.normalOS);
#endif

#ifdef ATTRIBUTES_NEED_TANGENT
                float4 tangentWS = float4(TransformObjectToWorldDir(input.tangentOS.xyz), input.tangentOS.w);
#endif

#ifdef VARYINGS_NEED_POSITION_WS
                output.positionWS = positionWS;
#endif

#ifdef VARYINGS_NEED_NORMAL_WS
                output.normalWS = normalWS;
#endif

#ifdef VARYINGS_NEED_TANGENT_WS
                output.tangentWS = tangentWS;
#endif

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

#if defined(VARYINGS_NEED_TEXCOORD0) || defined(VARYINGS_DS_NEED_TEXCOORD0)
                output.texCoord0 = input.uv0;
#endif

#if (SHADERPASS == SHADERPASS_FORWARD) || (SHADERPASS == SHADERPASS_GBUFFER)
                OUTPUT_LIGHTMAP_UV(input.uv1, unity_LightmapST, output.staticLightmapUV);
                OUTPUT_SH(normalWS, output.sh);
#endif

                return output;
            }

            Varyings vert(Attributes input)
            {
                Varyings output = (Varyings)0;
                output = BuildVaryings(input);
                return output;
            }

            ////////////////////////////////////////////////////////////////////

            // Frag

            struct SurfaceDescriptionInputs
            {
                float3 WorldSpaceNormal;
                float3 TangentSpaceNormal;
                float3 WorldSpaceTangent;
                float3 WorldSpaceBiTangent;
                float3 WorldSpaceViewDirection;
                float3 WorldSpacePosition;
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

                float crossSign = (input.tangentWS.w > 0.0 ? 1.0 : -1.0)* GetOddNegativeScale();
                float3 bitang = crossSign * cross(input.normalWS.xyz, input.tangentWS.xyz);

                output.WorldSpaceNormal = renormFactor * input.normalWS.xyz;
                output.TangentSpaceNormal = float3(0.0f, 0.0f, 1.0f);

                output.WorldSpaceTangent = renormFactor * input.tangentWS.xyz;
                output.WorldSpaceBiTangent = renormFactor * bitang;

                output.WorldSpaceViewDirection = GetWorldSpaceNormalizeViewDir(input.positionWS);
                output.WorldSpacePosition = input.positionWS;

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

            void Unity_TilingAndOffset_float(float2 UV, float2 Tiling, float2 Offset, out float2 Out)
            {
                Out = UV * Tiling + Offset;
            }

            float Unity_SimpleNoise_ValueNoise_LegacySine_float (float2 uv)
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

            void Unity_SimpleNoise_LegacySine_float(float2 UV, float Scale, out float Out)
            {
                float freq, amp;
                Out = 0.0f;
                freq = pow(2.0, float(0));
                amp = pow(0.5, float(3-0));
                Out += Unity_SimpleNoise_ValueNoise_LegacySine_float(float2(UV.xy*(Scale/freq)))*amp;
                freq = pow(2.0, float(1));
                amp = pow(0.5, float(3-1));
                Out += Unity_SimpleNoise_ValueNoise_LegacySine_float(float2(UV.xy*(Scale/freq)))*amp;
                freq = pow(2.0, float(2));
                amp = pow(0.5, float(3-2));
                Out += Unity_SimpleNoise_ValueNoise_LegacySine_float(float2(UV.xy*(Scale/freq)))*amp;
            }

            void Unity_Divide_float(float A, float B, out float Out)
            {
                Out = A / B;
            }

            void Unity_NormalFromHeight_Tangent_float(float In, float Strength, float3 Position, float3x3 TangentMatrix, out float3 Out)
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
                Out = SafeNormalize(TangentMatrix[2].xyz - (Strength * surfGrad));
                Out = TransformWorldToTangent(Out, TangentMatrix);
            }

            void Unity_Multiply_float3_float3(float3 A, float3 B, out float3 Out)
            {
                Out = A * B;
            }

            void Unity_Add_float2(float2 A, float2 B, out float2 Out)
            {
                Out = A + B;
            }

            void Unity_Multiply_float4_float4(float4 A, float4 B, out float4 Out)
            {
                Out = A * B;
            }

            void Unity_Add_float3(float3 A, float3 B, out float3 Out)
            {
                Out = A + B;
            }

            void Unity_SceneColor_float(float4 UV, out float3 Out)
            {
                Out = SampleSceneColor(UV.xy);
            }

            float3 SampleReflectionProbe(float3 viewDir, float3 normalOS, float lod)
            {
                float3 reflectVec = reflect(-viewDir, normalOS);
                return DecodeHDREnvironment(SAMPLE_TEXTURECUBE_LOD(unity_SpecCube0, samplerunity_SpecCube0, reflectVec, lod), unity_SpecCube0_HDR);
            }

            void Unity_ReflectionProbe_float(float3 ViewDir, float3 Normal, float LOD, out float3 Out)
            {
                Out = SampleReflectionProbe(ViewDir, Normal, LOD);
            }

            void Unity_Add_float(float A, float B, out float Out)
            {
                Out = A + B;
            }

            SurfaceDescription SurfaceDescriptionFunction(SurfaceDescriptionInputs IN)
            {
                SurfaceDescription surface = (SurfaceDescription)0;
                UnityTexture2D _Property_dc6c2478bbb5487fa8eff149ec023db3_Out_0_Texture2D = UnityBuildTexture2DStruct(_TintTexture);
                float2 _TilingAndOffset_8b5cd719d0e545bd9e192522091944a8_Out_3_Vector2;
                Unity_TilingAndOffset_float(IN.uv0.xy, float2 (1, 1), float2 (0, 0), _TilingAndOffset_8b5cd719d0e545bd9e192522091944a8_Out_3_Vector2);
                float _Property_107356499d074cbcad086455cc0213c2_Out_0_Float = _Tiling;
                float _SimpleNoise_faef7298f78a4bd7be0fd0b3e0e985c7_Out_2_Float;
                Unity_SimpleNoise_LegacySine_float(IN.uv0.xy, _Property_107356499d074cbcad086455cc0213c2_Out_0_Float, _SimpleNoise_faef7298f78a4bd7be0fd0b3e0e985c7_Out_2_Float);
                float _Property_9a5ef5ab85b146ffb090385f355f66b3_Out_0_Float = _DisortStrength;
                float _Float_3d86622c672e40ab88bfc2d901f75ca1_Out_0_Float = float(5000);
                float _Divide_e8b69b3456df4714a5ef1b2e33bfa756_Out_2_Float;
                Unity_Divide_float(_Property_9a5ef5ab85b146ffb090385f355f66b3_Out_0_Float, _Float_3d86622c672e40ab88bfc2d901f75ca1_Out_0_Float, _Divide_e8b69b3456df4714a5ef1b2e33bfa756_Out_2_Float);
                float3 _NormalFromHeight_dc2bb47511c542f68e101b341d374c66_Out_1_Vector3;
                float3x3 _NormalFromHeight_dc2bb47511c542f68e101b341d374c66_TangentMatrix = float3x3(IN.WorldSpaceTangent, IN.WorldSpaceBiTangent, IN.WorldSpaceNormal);
                float3 _NormalFromHeight_dc2bb47511c542f68e101b341d374c66_Position = IN.WorldSpacePosition;
                Unity_NormalFromHeight_Tangent_float(_SimpleNoise_faef7298f78a4bd7be0fd0b3e0e985c7_Out_2_Float,_Divide_e8b69b3456df4714a5ef1b2e33bfa756_Out_2_Float,_NormalFromHeight_dc2bb47511c542f68e101b341d374c66_Position,_NormalFromHeight_dc2bb47511c542f68e101b341d374c66_TangentMatrix, _NormalFromHeight_dc2bb47511c542f68e101b341d374c66_Out_1_Vector3);
                float _Property_89b6fed717774b2fbd2e81afa27779a4_Out_0_Float = _DistortionOnTexture;
                float3 _Multiply_898a08a202564434a56217d56b2f5204_Out_2_Vector3;
                Unity_Multiply_float3_float3(_NormalFromHeight_dc2bb47511c542f68e101b341d374c66_Out_1_Vector3, (_Property_89b6fed717774b2fbd2e81afa27779a4_Out_0_Float.xxx), _Multiply_898a08a202564434a56217d56b2f5204_Out_2_Vector3);
                float2 _Add_60a7bc1dbc3c456596a102286630badb_Out_2_Vector2;
                Unity_Add_float2(_TilingAndOffset_8b5cd719d0e545bd9e192522091944a8_Out_3_Vector2, (_Multiply_898a08a202564434a56217d56b2f5204_Out_2_Vector3.xy), _Add_60a7bc1dbc3c456596a102286630badb_Out_2_Vector2);
                float4 _SampleTexture2D_750406f2fa5240c6aff7031e42315dc2_RGBA_0_Vector4 = SAMPLE_TEXTURE2D(_Property_dc6c2478bbb5487fa8eff149ec023db3_Out_0_Texture2D.tex, _Property_dc6c2478bbb5487fa8eff149ec023db3_Out_0_Texture2D.samplerstate, _Property_dc6c2478bbb5487fa8eff149ec023db3_Out_0_Texture2D.GetTransformedUV(_Add_60a7bc1dbc3c456596a102286630badb_Out_2_Vector2) );
                float _SampleTexture2D_750406f2fa5240c6aff7031e42315dc2_R_4_Float = _SampleTexture2D_750406f2fa5240c6aff7031e42315dc2_RGBA_0_Vector4.r;
                float _SampleTexture2D_750406f2fa5240c6aff7031e42315dc2_G_5_Float = _SampleTexture2D_750406f2fa5240c6aff7031e42315dc2_RGBA_0_Vector4.g;
                float _SampleTexture2D_750406f2fa5240c6aff7031e42315dc2_B_6_Float = _SampleTexture2D_750406f2fa5240c6aff7031e42315dc2_RGBA_0_Vector4.b;
                float _SampleTexture2D_750406f2fa5240c6aff7031e42315dc2_A_7_Float = _SampleTexture2D_750406f2fa5240c6aff7031e42315dc2_RGBA_0_Vector4.a;
                float4 _Property_b8e8e5f084794e50b52d1ffdc6564e22_Out_0_Vector4 = _TintColor;
                float4 _Multiply_b5dd62df831f4c628973ed03f2ab4b7b_Out_2_Vector4;
                Unity_Multiply_float4_float4(_SampleTexture2D_750406f2fa5240c6aff7031e42315dc2_RGBA_0_Vector4, _Property_b8e8e5f084794e50b52d1ffdc6564e22_Out_0_Vector4, _Multiply_b5dd62df831f4c628973ed03f2ab4b7b_Out_2_Vector4);
                float4 _ScreenPosition_8242386b1fa44aeb8af32254385506de_Out_0_Vector4 = float4(IN.NDCPosition.xy, 0, 0);
                float3 _Add_36da67eeb2fd4548b509db5e335d7d07_Out_2_Vector3;
                Unity_Add_float3((_ScreenPosition_8242386b1fa44aeb8af32254385506de_Out_0_Vector4.xyz), _NormalFromHeight_dc2bb47511c542f68e101b341d374c66_Out_1_Vector3, _Add_36da67eeb2fd4548b509db5e335d7d07_Out_2_Vector3);
                float3 _SceneColor_89d4c8d659ff47599eb79a94c27e629b_Out_1_Vector3;
                Unity_SceneColor_float((float4(_Add_36da67eeb2fd4548b509db5e335d7d07_Out_2_Vector3, 1.0)), _SceneColor_89d4c8d659ff47599eb79a94c27e629b_Out_1_Vector3);
                float3 _Multiply_678b73ca07b04a1e9a9692d04b3fc639_Out_2_Vector3;
                Unity_Multiply_float3_float3((_Multiply_b5dd62df831f4c628973ed03f2ab4b7b_Out_2_Vector4.xyz), _SceneColor_89d4c8d659ff47599eb79a94c27e629b_Out_1_Vector3, _Multiply_678b73ca07b04a1e9a9692d04b3fc639_Out_2_Vector3);
                float _Property_ec26aba5479041fda654388085e977bb_Out_0_Float = _NormalStrength;
                float _Divide_e18bacaf6a6f4e07b6aa33ff5ccfae84_Out_2_Float;
                Unity_Divide_float(_Property_ec26aba5479041fda654388085e977bb_Out_0_Float, _Float_3d86622c672e40ab88bfc2d901f75ca1_Out_0_Float, _Divide_e18bacaf6a6f4e07b6aa33ff5ccfae84_Out_2_Float);
                float3 _NormalFromHeight_9f640bda1a044138a9b6c17d4d5c1abf_Out_1_Vector3;
                float3x3 _NormalFromHeight_9f640bda1a044138a9b6c17d4d5c1abf_TangentMatrix = float3x3(IN.WorldSpaceTangent, IN.WorldSpaceBiTangent, IN.WorldSpaceNormal);
                float3 _NormalFromHeight_9f640bda1a044138a9b6c17d4d5c1abf_Position = IN.WorldSpacePosition;
                Unity_NormalFromHeight_Tangent_float(_SimpleNoise_faef7298f78a4bd7be0fd0b3e0e985c7_Out_2_Float,_Divide_e18bacaf6a6f4e07b6aa33ff5ccfae84_Out_2_Float,_NormalFromHeight_9f640bda1a044138a9b6c17d4d5c1abf_Position,_NormalFromHeight_9f640bda1a044138a9b6c17d4d5c1abf_TangentMatrix, _NormalFromHeight_9f640bda1a044138a9b6c17d4d5c1abf_Out_1_Vector3);
                float3 _ReflectionProbe_fb0acd6ddb83442ba34fb83d8e488e7d_Out_3_Vector3;
                Unity_ReflectionProbe_float(IN.WorldSpaceViewDirection, IN.WorldSpaceNormal, float(0), _ReflectionProbe_fb0acd6ddb83442ba34fb83d8e488e7d_Out_3_Vector3);
                float _Property_79b583e67fe34a6db4e67ce0e046bfef_Out_0_Float = _ReflectionStrength;
                float3 _Multiply_b8c89a38f20846ae9725969f191c6c06_Out_2_Vector3;
                Unity_Multiply_float3_float3(_ReflectionProbe_fb0acd6ddb83442ba34fb83d8e488e7d_Out_3_Vector3, (_Property_79b583e67fe34a6db4e67ce0e046bfef_Out_0_Float.xxx), _Multiply_b8c89a38f20846ae9725969f191c6c06_Out_2_Vector3);
                float _Property_2b2c87bb0bf145c989aa43c49cd84996_Out_0_Float = _Metallic;
                float _Property_baf4990a6db1453f841cedfb66e36f30_Out_0_Float = _Smoothness;
                float _Split_fff5dfcd84a04adfb51280fd40e2e913_R_1_Float = _Multiply_b5dd62df831f4c628973ed03f2ab4b7b_Out_2_Vector4[0];
                float _Split_fff5dfcd84a04adfb51280fd40e2e913_G_2_Float = _Multiply_b5dd62df831f4c628973ed03f2ab4b7b_Out_2_Vector4[1];
                float _Split_fff5dfcd84a04adfb51280fd40e2e913_B_3_Float = _Multiply_b5dd62df831f4c628973ed03f2ab4b7b_Out_2_Vector4[2];
                float _Split_fff5dfcd84a04adfb51280fd40e2e913_A_4_Float = _Multiply_b5dd62df831f4c628973ed03f2ab4b7b_Out_2_Vector4[3];
                float _Split_5fd4a7cdd1424ae18a5b9053c4d3bb05_R_1_Float = _Property_b8e8e5f084794e50b52d1ffdc6564e22_Out_0_Vector4[0];
                float _Split_5fd4a7cdd1424ae18a5b9053c4d3bb05_G_2_Float = _Property_b8e8e5f084794e50b52d1ffdc6564e22_Out_0_Vector4[1];
                float _Split_5fd4a7cdd1424ae18a5b9053c4d3bb05_B_3_Float = _Property_b8e8e5f084794e50b52d1ffdc6564e22_Out_0_Vector4[2];
                float _Split_5fd4a7cdd1424ae18a5b9053c4d3bb05_A_4_Float = _Property_b8e8e5f084794e50b52d1ffdc6564e22_Out_0_Vector4[3];
                float _Add_583b291ee8324c84a8c62ae59876013a_Out_2_Float;
                Unity_Add_float(_Split_fff5dfcd84a04adfb51280fd40e2e913_A_4_Float, _Split_5fd4a7cdd1424ae18a5b9053c4d3bb05_A_4_Float, _Add_583b291ee8324c84a8c62ae59876013a_Out_2_Float);
                surface.BaseColor = _Multiply_678b73ca07b04a1e9a9692d04b3fc639_Out_2_Vector3;
                surface.NormalTS = _NormalFromHeight_9f640bda1a044138a9b6c17d4d5c1abf_Out_1_Vector3;
                surface.Emission = _Multiply_b8c89a38f20846ae9725969f191c6c06_Out_2_Vector3;
                surface.Metallic = _Property_2b2c87bb0bf145c989aa43c49cd84996_Out_0_Float;
                surface.Smoothness = _Property_baf4990a6db1453f841cedfb66e36f30_Out_0_Float;
                surface.Occlusion = float(1);
                surface.Alpha = _Add_583b291ee8324c84a8c62ae59876013a_Out_2_Float;
                return surface;
            }

            SurfaceDescription BuildSurfaceDescription(Varyings varyings)
            {
                SurfaceDescriptionInputs surfaceDescriptionInputs = BuildSurfaceDescriptionInputs(varyings);
                SurfaceDescription surfaceDescription = SurfaceDescriptionFunction(surfaceDescriptionInputs);
                return surfaceDescription;
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
    #elif _NORMAL_DROPOFF_OS
                inputData.normalWS = TransformObjectToWorldNormal(surfaceDescription.NormalOS);
    #elif _NORMAL_DROPOFF_WS
                inputData.normalWS = surfaceDescription.NormalWS;
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
                SurfaceDescription surfaceDescription = BuildSurfaceDescription(input);

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
}
