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

            // Render State
            Cull Back
            Blend SrcAlpha OneMinusSrcAlpha, One OneMinusSrcAlpha
            ZTest LEqual
            ZWrite Off

            // --------------------------------------------------
            // Pass

            HLSLPROGRAM

            // Pragmas
            #pragma target 2.0
            #pragma multi_compile_instancing
            #pragma multi_compile_fog
            #pragma instancing_options renderinglayer
            #pragma vertex vert
            #pragma fragment frag

            // Keywords
            #pragma multi_compile_fragment _ _SCREEN_SPACE_OCCLUSION
            #pragma multi_compile _ LIGHTMAP_ON
            #pragma multi_compile _ DYNAMICLIGHTMAP_ON
            #pragma multi_compile _ DIRLIGHTMAP_COMBINED
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BLENDING
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BOX_PROJECTION
            #pragma multi_compile_fragment _ _SHADOWS_SOFT _SHADOWS_SOFT_LOW _SHADOWS_SOFT_MEDIUM _SHADOWS_SOFT_HIGH
            #pragma multi_compile _ LIGHTMAP_SHADOW_MIXING
            #pragma multi_compile _ SHADOWS_SHADOWMASK
            #pragma multi_compile_fragment _ _DBUFFER_MRT1 _DBUFFER_MRT2 _DBUFFER_MRT3
            #pragma multi_compile_fragment _ _LIGHT_LAYERS
            #pragma multi_compile_fragment _ DEBUG_DISPLAY
            #pragma multi_compile_fragment _ _LIGHT_COOKIES
            #pragma multi_compile _ _FORWARD_PLUS
            #pragma multi_compile _ EVALUATE_SH_MIXED EVALUATE_SH_VERTEX

            // Defines
            #define _NORMALMAP 1
            #define _NORMAL_DROPOFF_TS 1
            #define ATTRIBUTES_NEED_NORMAL
            #define ATTRIBUTES_NEED_TANGENT
            #define ATTRIBUTES_NEED_TEXCOORD0
            #define ATTRIBUTES_NEED_TEXCOORD1
            #define ATTRIBUTES_NEED_TEXCOORD2
            #define VARYINGS_NEED_POSITION_WS
            #define VARYINGS_NEED_NORMAL_WS
            #define VARYINGS_NEED_TANGENT_WS
            #define VARYINGS_NEED_TEXCOORD0
            #define VARYINGS_NEED_FOG_AND_VERTEX_LIGHT
            #define VARYINGS_NEED_SHADOW_COORD
            #define FEATURES_GRAPH_VERTEX
            #define SHADERPASS SHADERPASS_FORWARD
            #define _FOG_FRAGMENT 1
            #define _SURFACE_TYPE_TRANSPARENT 1
            #define REQUIRE_OPAQUE_TEXTURE

            // Includes
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/RenderingLayers.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Texture.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Input.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/TextureStack.hlsl"
            #include_with_pragmas "Packages/com.unity.render-pipelines.core/ShaderLibrary/FoveatedRenderingKeywords.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/FoveatedRendering.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ShaderGraphFunctions.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DBuffer.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Editor/ShaderGraph/Includes/ShaderPass.hlsl"

            // Structs and Packing
            struct Attributes
            {
                float3 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float4 tangentOS : TANGENT;
                float4 uv0 : TEXCOORD0;
                float4 uv1 : TEXCOORD1;
                float4 uv2 : TEXCOORD2;

#if UNITY_ANY_INSTANCING_ENABLED
                uint instanceID : INSTANCEID_SEMANTIC;
#endif

            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float3 positionWS;
                float3 normalWS;
                float4 tangentWS;
                float4 texCoord0;

#if defined(LIGHTMAP_ON)
                float2 staticLightmapUV;
#endif

#if defined(DYNAMICLIGHTMAP_ON)
                float2 dynamicLightmapUV;
#endif

#if !defined(LIGHTMAP_ON)
                float3 sh;
#endif

                float4 fogFactorAndVertexLight;

#if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
                float4 shadowCoord;
#endif

#if UNITY_ANY_INSTANCING_ENABLED
                uint instanceID : CUSTOM_INSTANCE_ID;
#endif

#if (defined(UNITY_STEREO_MULTIVIEW_ENABLED)) || (defined(UNITY_STEREO_INSTANCING_ENABLED) && (defined(SHADER_API_GLES3) || defined(SHADER_API_GLCORE)))
                uint stereoTargetEyeIndexAsBlendIdx0 : BLENDINDICES0;
#endif

#if (defined(UNITY_STEREO_INSTANCING_ENABLED))
                uint stereoTargetEyeIndexAsRTArrayIdx : SV_RenderTargetArrayIndex;
#endif

#if defined(SHADER_STAGE_FRAGMENT) && defined(VARYINGS_NEED_CULLFACE)
                FRONT_FACE_TYPE cullFace : FRONT_FACE_SEMANTIC;
#endif

            };

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

            struct VertexDescriptionInputs
            {
                float3 ObjectSpaceNormal;
                float3 ObjectSpaceTangent;
                float3 ObjectSpacePosition;
            };

            struct PackedVaryings
            {
                float4 positionCS : SV_POSITION;

#if defined(LIGHTMAP_ON)
                float2 staticLightmapUV : INTERP0;
#endif

#if defined(DYNAMICLIGHTMAP_ON)
                float2 dynamicLightmapUV : INTERP1;
#endif

#if !defined(LIGHTMAP_ON)
                float3 sh : INTERP2;
#endif

#if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
                float4 shadowCoord : INTERP3;
#endif

                float4 tangentWS : INTERP4;
                float4 texCoord0 : INTERP5;
                float4 fogFactorAndVertexLight : INTERP6;
                float3 positionWS : INTERP7;
                float3 normalWS : INTERP8;

#if UNITY_ANY_INSTANCING_ENABLED
                uint instanceID : CUSTOM_INSTANCE_ID;
#endif

#if (defined(UNITY_STEREO_MULTIVIEW_ENABLED)) || (defined(UNITY_STEREO_INSTANCING_ENABLED) && (defined(SHADER_API_GLES3) || defined(SHADER_API_GLCORE)))
                uint stereoTargetEyeIndexAsBlendIdx0 : BLENDINDICES0;
#endif

#if (defined(UNITY_STEREO_INSTANCING_ENABLED))
                uint stereoTargetEyeIndexAsRTArrayIdx : SV_RenderTargetArrayIndex;
#endif

#if defined(SHADER_STAGE_FRAGMENT) && defined(VARYINGS_NEED_CULLFACE)
                FRONT_FACE_TYPE cullFace : FRONT_FACE_SEMANTIC;
#endif

            };

            PackedVaryings PackVaryings (Varyings input)
            {
                PackedVaryings output;
                ZERO_INITIALIZE(PackedVaryings, output);

                output.positionCS = input.positionCS;

#if defined(LIGHTMAP_ON)
                output.staticLightmapUV = input.staticLightmapUV;
#endif

#if defined(DYNAMICLIGHTMAP_ON)
                output.dynamicLightmapUV = input.dynamicLightmapUV;
#endif

#if !defined(LIGHTMAP_ON)
                output.sh = input.sh;
#endif

#if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
                output.shadowCoord = input.shadowCoord;
#endif

                output.tangentWS.xyzw = input.tangentWS;
                output.texCoord0.xyzw = input.texCoord0;
                output.fogFactorAndVertexLight.xyzw = input.fogFactorAndVertexLight;
                output.positionWS.xyz = input.positionWS;
                output.normalWS.xyz = input.normalWS;

#if UNITY_ANY_INSTANCING_ENABLED
                output.instanceID = input.instanceID;
#endif

#if (defined(UNITY_STEREO_MULTIVIEW_ENABLED)) || (defined(UNITY_STEREO_INSTANCING_ENABLED) && (defined(SHADER_API_GLES3) || defined(SHADER_API_GLCORE)))
                output.stereoTargetEyeIndexAsBlendIdx0 = input.stereoTargetEyeIndexAsBlendIdx0;
#endif

#if (defined(UNITY_STEREO_INSTANCING_ENABLED))
                output.stereoTargetEyeIndexAsRTArrayIdx = input.stereoTargetEyeIndexAsRTArrayIdx;
#endif

#if defined(SHADER_STAGE_FRAGMENT) && defined(VARYINGS_NEED_CULLFACE)
                output.cullFace = input.cullFace;
#endif

                return output;
            }

            Varyings UnpackVaryings (PackedVaryings input)
            {
                Varyings output;
                output.positionCS = input.positionCS;

#if defined(LIGHTMAP_ON)
                output.staticLightmapUV = input.staticLightmapUV;
#endif

#if defined(DYNAMICLIGHTMAP_ON)
                output.dynamicLightmapUV = input.dynamicLightmapUV;
#endif

#if !defined(LIGHTMAP_ON)
                output.sh = input.sh;
#endif

#if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
                output.shadowCoord = input.shadowCoord;
#endif

                output.tangentWS = input.tangentWS.xyzw;
                output.texCoord0 = input.texCoord0.xyzw;
                output.fogFactorAndVertexLight = input.fogFactorAndVertexLight.xyzw;
                output.positionWS = input.positionWS.xyz;
                output.normalWS = input.normalWS.xyz;

#if UNITY_ANY_INSTANCING_ENABLED
                output.instanceID = input.instanceID;
#endif

#if (defined(UNITY_STEREO_MULTIVIEW_ENABLED)) || (defined(UNITY_STEREO_INSTANCING_ENABLED) && (defined(SHADER_API_GLES3) || defined(SHADER_API_GLCORE)))
                output.stereoTargetEyeIndexAsBlendIdx0 = input.stereoTargetEyeIndexAsBlendIdx0;
#endif

#if (defined(UNITY_STEREO_INSTANCING_ENABLED))
                output.stereoTargetEyeIndexAsRTArrayIdx = input.stereoTargetEyeIndexAsRTArrayIdx;
#endif

#if defined(SHADER_STAGE_FRAGMENT) && defined(VARYINGS_NEED_CULLFACE)
                output.cullFace = input.cullFace;
#endif

                return output;
            }

            // --------------------------------------------------
            // Graph

            // Graph Properties
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

            // Object and Global properties
            SAMPLER(SamplerState_Linear_Repeat);
            TEXTURE2D(_TintTexture);
            SAMPLER(sampler_TintTexture);

            // Graph Includes
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Hashes.hlsl"

            // -- Property used by ScenePickingPass
#ifdef SCENEPICKINGPASS
            float4 _SelectionID;
#endif

            // -- Properties used by SceneSelectionPass
#ifdef SCENESELECTIONPASS
            int _ObjectId;
            int _PassValue;
#endif

            // Graph Functions

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

#if defined(SHADER_STAGE_RAY_TRACING) && defined(RAYTRACING_SHADER_GRAPH_DEFAULT)
                #error 'Normal From Height' node is not supported in ray tracing, please provide an alternate implementation, relying for instance on the 'Raytracing Quality' keyword
#endif

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
                Out = SHADERGRAPH_SAMPLE_SCENE_COLOR(UV.xy);
            }

            void Unity_ReflectionProbe_float(float3 ViewDir, float3 Normal, float LOD, out float3 Out)
            {
                Out = SHADERGRAPH_REFLECTION_PROBE(ViewDir, Normal, LOD);
            }

            void Unity_Add_float(float A, float B, out float Out)
            {
                Out = A + B;
            }

            // Graph Vertex
            struct VertexDescription
            {
                float3 Position;
                float3 Normal;
                float3 Tangent;
            };

            VertexDescription VertexDescriptionFunction(VertexDescriptionInputs IN)
            {
                VertexDescription description = (VertexDescription)0;
                description.Position = IN.ObjectSpacePosition;
                description.Normal = IN.ObjectSpaceNormal;
                description.Tangent = IN.ObjectSpaceTangent;
                return description;
            }

            // Custom interpolators, pre surface
#ifdef FEATURES_GRAPH_VERTEX
            Varyings CustomInterpolatorPassThroughFunc(inout Varyings output, VertexDescription input)
            {
                return output;
            }

            #define CUSTOMINTERPOLATOR_VARYPASSTHROUGH_FUNC
#endif

            // Graph Pixel
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

            // --------------------------------------------------
            // Build Graph Inputs
#ifdef HAVE_VFX_MODIFICATION
            #define VFX_SRP_ATTRIBUTES Attributes
            #define VFX_SRP_VARYINGS Varyings
            #define VFX_SRP_SURFACE_INPUTS SurfaceDescriptionInputs
#endif

            VertexDescriptionInputs BuildVertexDescriptionInputs(Attributes input)
            {
                VertexDescriptionInputs output;
                ZERO_INITIALIZE(VertexDescriptionInputs, output);

                output.ObjectSpaceNormal = input.normalOS;
                output.ObjectSpaceTangent = input.tangentOS.xyz;
                output.ObjectSpacePosition = input.positionOS;

                return output;
            }

            SurfaceDescriptionInputs BuildSurfaceDescriptionInputs(Varyings input)
            {
                SurfaceDescriptionInputs output;
                ZERO_INITIALIZE(SurfaceDescriptionInputs, output);

#ifdef HAVE_VFX_MODIFICATION
    #if VFX_USE_GRAPH_VALUES
                uint instanceActiveIndex = asuint(UNITY_ACCESS_INSTANCED_PROP(PerInstance, _InstanceActiveIndex));
    #endif
#endif

                // must use interpolated tangent, bitangent and normal before they are normalized in the pixel shader.
                float3 unnormalizedNormalWS = input.normalWS;
                const float renormFactor = 1.0 / length(unnormalizedNormalWS);

                // use bitangent on the fly like in hdrp
                // IMPORTANT! If we ever support Flip on double sided materials ensure bitangent and tangent are NOT flipped.
                float crossSign = (input.tangentWS.w > 0.0 ? 1.0 : -1.0)* GetOddNegativeScale();
                float3 bitang = crossSign * cross(input.normalWS.xyz, input.tangentWS.xyz);

                output.WorldSpaceNormal = renormFactor * input.normalWS.xyz;      // we want a unit length Normal Vector node in shader graph
                output.TangentSpaceNormal = float3(0.0f, 0.0f, 1.0f);

                // to preserve mikktspace compliance we use same scale renormFactor as was used on the normal.
                // This is explained in section 2.2 in "surface gradient based bump mapping framework"
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

#if defined(SHADER_STAGE_FRAGMENT) && defined(VARYINGS_NEED_CULLFACE)
                #define BUILD_SURFACE_DESCRIPTION_INPUTS_OUTPUT_FACESIGN output.FaceSign =                    IS_FRONT_VFACE(input.cullFace, true, false);
#else
                #define BUILD_SURFACE_DESCRIPTION_INPUTS_OUTPUT_FACESIGN
#endif

                #undef BUILD_SURFACE_DESCRIPTION_INPUTS_OUTPUT_FACESIGN

                return output;
            }

            // --------------------------------------------------
            // Main

            #include "Packages/com.unity.render-pipelines.universal/Editor/ShaderGraph/Includes/Varyings.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Editor/ShaderGraph/Includes/PBRForwardPass.hlsl"

            // --------------------------------------------------
            // Visual Effect Vertex Invocations
#ifdef HAVE_VFX_MODIFICATION
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/VisualEffectVertex.hlsl"
#endif

            ENDHLSL
        }
    }
}
