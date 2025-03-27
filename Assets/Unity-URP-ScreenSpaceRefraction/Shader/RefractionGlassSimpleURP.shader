Shader "Nihit/RefractionGlassSimpleURP"
{
    Properties
    {
        _IOR("IOR", Range(1, 5)) = 1.52
        _Chromatic("Chromatic", Range(0, 0.2)) = 0
        _ColorTint("ColorTint", Color) = (1, 1, 1, 0)
        [ToggleUI]_UseEmissive("UseEmissive", Float) = 0
        _QueueOffset("_QueueOffset", Float) = 0
        _QueueControl("_QueueControl", Float) = -1
        [NoScaleOffset]unity_Lightmaps("unity_Lightmaps", 2DArray) = "" {}
        [NoScaleOffset]unity_LightmapsInd("unity_LightmapsInd", 2DArray) = "" {}
        [NoScaleOffset]unity_ShadowMasks("unity_ShadowMasks", 2DArray) = "" {}
    }
    SubShader
    {
        Tags
        {
            "RenderPipeline"="UniversalPipeline"
            "RenderType"="Transparent"
            "UniversalMaterialType" = "Lit"
            "Queue"="Transparent"
            "DisableBatching"="False"
            "ShaderGraphShader"="true"
            "ShaderGraphTargetId"="UniversalLitSubTarget"
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
                ZTest Less
                ZWrite Off
            
            // Debug
            // <None>
            
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
            // GraphKeywords: <None>
            
            // Defines
            
            #define _NORMALMAP 1
            #define _NORMAL_DROPOFF_TS 1
            #define ATTRIBUTES_NEED_NORMAL
            #define ATTRIBUTES_NEED_TANGENT
            #define ATTRIBUTES_NEED_TEXCOORD1
            #define ATTRIBUTES_NEED_TEXCOORD2
            #define VARYINGS_NEED_POSITION_WS
            #define VARYINGS_NEED_NORMAL_WS
            #define VARYINGS_NEED_TANGENT_WS
            #define VARYINGS_NEED_FOG_AND_VERTEX_LIGHT
            #define VARYINGS_NEED_SHADOW_COORD
            #define FEATURES_GRAPH_VERTEX
            /* WARNING: $splice Could not find named fragment 'PassInstancing' */
            #define SHADERPASS SHADERPASS_FORWARD
                #define _FOG_FRAGMENT 1
                #define _SURFACE_TYPE_TRANSPARENT 1
                #define REQUIRE_OPAQUE_TEXTURE
            
            
            // custom interpolator pre-include
            /* WARNING: $splice Could not find named fragment 'sgci_CustomInterpolatorPreInclude' */
            
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
            
            // --------------------------------------------------
            // Structs and Packing
            
            // custom interpolators pre packing
            /* WARNING: $splice Could not find named fragment 'CustomInterpolatorPrePacking' */
            
            struct Attributes
                {
                     float3 positionOS : POSITION;
                     float3 normalOS : NORMAL;
                     float4 tangentOS : TANGENT;
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
                     float3 AbsoluteWorldSpacePosition;
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
                     float4 fogFactorAndVertexLight : INTERP5;
                     float3 positionWS : INTERP6;
                     float3 normalWS : INTERP7;
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
                float _IOR;
                float _Chromatic;
                float4 _ColorTint;
                float _UseEmissive;
                CBUFFER_END
                
                
                // Object and Global properties
            
            // Graph Includes
            // GraphIncludes: <None>
            
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
            
                void Unity_NormalBlend_float(float3 A, float3 B, out float3 Out)
                {
                    Out = SafeNormalize(float3(A.rg + B.rg, A.b * B.b));
                }
                
                void Unity_Branch_float3(float Predicate, float3 True, float3 False, out float3 Out)
                {
                    Out = Predicate ? True : False;
                }
                
                void Unity_Divide_float(float A, float B, out float Out)
                {
                    Out = A / B;
                }
                
                void RefractionMethod_float(float3 View, float3 Normal, float ETA, out float3 Out){
                Out = refract(normalize(View),normalize(Normal),ETA);
                }
                
                void Unity_Normalize_float3(float3 In, out float3 Out)
                {
                    Out = normalize(In);
                }
                
                void Unity_Add_float3(float3 A, float3 B, out float3 Out)
                {
                    Out = A + B;
                }
                
                void Unity_Multiply_float4x4_float4(float4x4 A, float4 B, out float4 Out)
                {
                Out = mul(A, B);
                }
                
                void screenpos_float(float4 input, out float4 Out){
                Out = ComputeScreenPos(input,_ProjectionParams.x);
                }
                
                void Unity_Divide_float2(float2 A, float2 B, out float2 Out)
                {
                    Out = A / B;
                }
                
                void Unity_SceneColor_float(float4 UV, out float3 Out)
                {
                    Out = SHADERGRAPH_SAMPLE_SCENE_COLOR(UV.xy);
                }
                
                struct Bindings_RefractionFunction_9811543ea6182ea43ac1252406d81f44_float
                {
                float3 WorldSpaceNormal;
                float3 AbsoluteWorldSpacePosition;
                };
                
                void SG_RefractionFunction_9811543ea6182ea43ac1252406d81f44_float(float _Refractive_Index_Target, float _Refractive_Index_Origin, float _UseNormalMap, float3 _NormalMap, Bindings_RefractionFunction_9811543ea6182ea43ac1252406d81f44_float IN, out float4 OutVector4_1)
                {
                float _Property_d8e03ee2aabd44a59fba214061c7266f_Out_0_Boolean = _UseNormalMap;
                float3 _Property_12a66679289b4e1babfd759ec30fb491_Out_0_Vector3 = _NormalMap;
                float3 _NormalBlend_b2d382ac97fc4e00b85b1699e8e30d23_Out_2_Vector3;
                Unity_NormalBlend_float(IN.WorldSpaceNormal, _Property_12a66679289b4e1babfd759ec30fb491_Out_0_Vector3, _NormalBlend_b2d382ac97fc4e00b85b1699e8e30d23_Out_2_Vector3);
                float3 _Branch_88e7b1e72a9e4c228bde3b5b568f08bc_Out_3_Vector3;
                Unity_Branch_float3(_Property_d8e03ee2aabd44a59fba214061c7266f_Out_0_Boolean, _NormalBlend_b2d382ac97fc4e00b85b1699e8e30d23_Out_2_Vector3, IN.WorldSpaceNormal, _Branch_88e7b1e72a9e4c228bde3b5b568f08bc_Out_3_Vector3);
                float _Property_b2c03deb8e09428fb2cbd516b1b86bfd_Out_0_Float = _Refractive_Index_Origin;
                float _Property_06a29155886349a4892108c05fa84fa7_Out_0_Float = _Refractive_Index_Target;
                float _Divide_a72c394a4c12494c8f39d08f60c89d3a_Out_2_Float;
                Unity_Divide_float(_Property_b2c03deb8e09428fb2cbd516b1b86bfd_Out_0_Float, _Property_06a29155886349a4892108c05fa84fa7_Out_0_Float, _Divide_a72c394a4c12494c8f39d08f60c89d3a_Out_2_Float);
                float3 _RefractionMethodCustomFunction_b487162cdd13489d9385578854e5105e_Out_0_Vector3;
                RefractionMethod_float((-1 * mul((float3x3)UNITY_MATRIX_M, transpose(mul(UNITY_MATRIX_I_M, UNITY_MATRIX_I_V)) [2].xyz)), _Branch_88e7b1e72a9e4c228bde3b5b568f08bc_Out_3_Vector3, _Divide_a72c394a4c12494c8f39d08f60c89d3a_Out_2_Float, _RefractionMethodCustomFunction_b487162cdd13489d9385578854e5105e_Out_0_Vector3);
                float3 _Normalize_3ac60773707e42899ccd557d04be34b8_Out_1_Vector3;
                Unity_Normalize_float3(_RefractionMethodCustomFunction_b487162cdd13489d9385578854e5105e_Out_0_Vector3, _Normalize_3ac60773707e42899ccd557d04be34b8_Out_1_Vector3);
                float3 _Add_432b1d36abaf4bd39dc36d8ea99e173b_Out_2_Vector3;
                Unity_Add_float3(IN.AbsoluteWorldSpacePosition, _Normalize_3ac60773707e42899ccd557d04be34b8_Out_1_Vector3, _Add_432b1d36abaf4bd39dc36d8ea99e173b_Out_2_Vector3);
                float _Split_ee6ae167c9e34cbbae5f049dd3321511_R_1_Float = _Add_432b1d36abaf4bd39dc36d8ea99e173b_Out_2_Vector3[0];
                float _Split_ee6ae167c9e34cbbae5f049dd3321511_G_2_Float = _Add_432b1d36abaf4bd39dc36d8ea99e173b_Out_2_Vector3[1];
                float _Split_ee6ae167c9e34cbbae5f049dd3321511_B_3_Float = _Add_432b1d36abaf4bd39dc36d8ea99e173b_Out_2_Vector3[2];
                float _Split_ee6ae167c9e34cbbae5f049dd3321511_A_4_Float = 0;
                float4 _Vector4_aa087ccb94ce4411b67b08273efd9083_Out_0_Vector4 = float4(_Split_ee6ae167c9e34cbbae5f049dd3321511_R_1_Float, _Split_ee6ae167c9e34cbbae5f049dd3321511_G_2_Float, _Split_ee6ae167c9e34cbbae5f049dd3321511_B_3_Float, float(1));
                float4 _Multiply_dfcea45d1b634434b51bbda95d0ba5f7_Out_2_Vector4;
                Unity_Multiply_float4x4_float4(UNITY_MATRIX_VP, _Vector4_aa087ccb94ce4411b67b08273efd9083_Out_0_Vector4, _Multiply_dfcea45d1b634434b51bbda95d0ba5f7_Out_2_Vector4);
                float4 _screenposCustomFunction_6122809cc7064bf28fdb3877e6eb4d19_Out_1_Vector4;
                screenpos_float(_Multiply_dfcea45d1b634434b51bbda95d0ba5f7_Out_2_Vector4, _screenposCustomFunction_6122809cc7064bf28fdb3877e6eb4d19_Out_1_Vector4);
                float _Split_9cf60745662f4a1296e6c1dff52c309d_R_1_Float = _screenposCustomFunction_6122809cc7064bf28fdb3877e6eb4d19_Out_1_Vector4[0];
                float _Split_9cf60745662f4a1296e6c1dff52c309d_G_2_Float = _screenposCustomFunction_6122809cc7064bf28fdb3877e6eb4d19_Out_1_Vector4[1];
                float _Split_9cf60745662f4a1296e6c1dff52c309d_B_3_Float = _screenposCustomFunction_6122809cc7064bf28fdb3877e6eb4d19_Out_1_Vector4[2];
                float _Split_9cf60745662f4a1296e6c1dff52c309d_A_4_Float = _screenposCustomFunction_6122809cc7064bf28fdb3877e6eb4d19_Out_1_Vector4[3];
                float2 _Vector2_d56c09b8fa674c9f9fa9c85efcdb0d3d_Out_0_Vector2 = float2(_Split_9cf60745662f4a1296e6c1dff52c309d_R_1_Float, _Split_9cf60745662f4a1296e6c1dff52c309d_G_2_Float);
                float2 _Divide_52ed6bb71f1d4b409cf6cfb5afdfffb4_Out_2_Vector2;
                Unity_Divide_float2(_Vector2_d56c09b8fa674c9f9fa9c85efcdb0d3d_Out_0_Vector2, (_Split_9cf60745662f4a1296e6c1dff52c309d_A_4_Float.xx), _Divide_52ed6bb71f1d4b409cf6cfb5afdfffb4_Out_2_Vector2);
                float3 _SceneColor_1ac40037f048467da30d3e1d7511d105_Out_1_Vector3;
                Unity_SceneColor_float((float4(_Divide_52ed6bb71f1d4b409cf6cfb5afdfffb4_Out_2_Vector2, 0.0, 1.0)), _SceneColor_1ac40037f048467da30d3e1d7511d105_Out_1_Vector3);
                OutVector4_1 = (float4(_SceneColor_1ac40037f048467da30d3e1d7511d105_Out_1_Vector3, 1.0));
                }
                
                void Unity_Add_float(float A, float B, out float Out)
                {
                    Out = A + B;
                }
                
                void Unity_Multiply_float_float(float A, float B, out float Out)
                {
                    Out = A * B;
                }
                
                void Unity_Multiply_float3_float3(float3 A, float3 B, out float3 Out)
                {
                    Out = A * B;
                }
            
            // Custom interpolators pre vertex
            /* WARNING: $splice Could not find named fragment 'CustomInterpolatorPreVertex' */
            
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
                    float4 _Property_bed37ecbfa734f5b843dec423ca460dc_Out_0_Vector4 = _ColorTint;
                    float _Property_7df86f5defc944769c40cba35ca278a8_Out_0_Float = _IOR;
                    float Boolean_b32bd6d5b96545e491c89ead440163e6 = 0;
                    Bindings_RefractionFunction_9811543ea6182ea43ac1252406d81f44_float _RefractionFunction_278a87041c7844a2be668c7fccfc2623;
                    _RefractionFunction_278a87041c7844a2be668c7fccfc2623.WorldSpaceNormal = IN.WorldSpaceNormal;
                    _RefractionFunction_278a87041c7844a2be668c7fccfc2623.AbsoluteWorldSpacePosition = IN.AbsoluteWorldSpacePosition;
                    float4 _RefractionFunction_278a87041c7844a2be668c7fccfc2623_OutVector4_1_Vector4;
                    SG_RefractionFunction_9811543ea6182ea43ac1252406d81f44_float(_Property_7df86f5defc944769c40cba35ca278a8_Out_0_Float, float(1), Boolean_b32bd6d5b96545e491c89ead440163e6, float3 (0, 0, 0), _RefractionFunction_278a87041c7844a2be668c7fccfc2623, _RefractionFunction_278a87041c7844a2be668c7fccfc2623_OutVector4_1_Vector4);
                    float _Swizzle_547431f9e05a430ba25f6eb4314672a4_Out_1_Float = _RefractionFunction_278a87041c7844a2be668c7fccfc2623_OutVector4_1_Vector4.x;
                    float _Property_bca23bf1f3f443e6bcbcd5e9d64151ca_Out_0_Float = _Chromatic;
                    float _Add_0bb5d04a2c464d659b985e2926bf2b8a_Out_2_Float;
                    Unity_Add_float(_Property_7df86f5defc944769c40cba35ca278a8_Out_0_Float, _Property_bca23bf1f3f443e6bcbcd5e9d64151ca_Out_0_Float, _Add_0bb5d04a2c464d659b985e2926bf2b8a_Out_2_Float);
                    Bindings_RefractionFunction_9811543ea6182ea43ac1252406d81f44_float _RefractionFunction_c6bf2ec9c45d438dbbb48b4333b0bbf0;
                    _RefractionFunction_c6bf2ec9c45d438dbbb48b4333b0bbf0.WorldSpaceNormal = IN.WorldSpaceNormal;
                    _RefractionFunction_c6bf2ec9c45d438dbbb48b4333b0bbf0.AbsoluteWorldSpacePosition = IN.AbsoluteWorldSpacePosition;
                    float4 _RefractionFunction_c6bf2ec9c45d438dbbb48b4333b0bbf0_OutVector4_1_Vector4;
                    SG_RefractionFunction_9811543ea6182ea43ac1252406d81f44_float(_Add_0bb5d04a2c464d659b985e2926bf2b8a_Out_2_Float, float(1), Boolean_b32bd6d5b96545e491c89ead440163e6, float3 (0, 0, 0), _RefractionFunction_c6bf2ec9c45d438dbbb48b4333b0bbf0, _RefractionFunction_c6bf2ec9c45d438dbbb48b4333b0bbf0_OutVector4_1_Vector4);
                    float _Swizzle_4bf7b0731c2442b19b55f1999de0e374_Out_1_Float = _RefractionFunction_c6bf2ec9c45d438dbbb48b4333b0bbf0_OutVector4_1_Vector4.y;
                    float _Property_c165b0ec076f4a79a6fdd85517827ff6_Out_0_Float = _Chromatic;
                    float _Multiply_771992bd26284661b0734d6d3088e319_Out_2_Float;
                    Unity_Multiply_float_float(_Property_c165b0ec076f4a79a6fdd85517827ff6_Out_0_Float, 2, _Multiply_771992bd26284661b0734d6d3088e319_Out_2_Float);
                    float _Add_368a8dbb0607410ab5e19d2508d4a7c5_Out_2_Float;
                    Unity_Add_float(_Property_7df86f5defc944769c40cba35ca278a8_Out_0_Float, _Multiply_771992bd26284661b0734d6d3088e319_Out_2_Float, _Add_368a8dbb0607410ab5e19d2508d4a7c5_Out_2_Float);
                    Bindings_RefractionFunction_9811543ea6182ea43ac1252406d81f44_float _RefractionFunction_a3e633706b6d4258a0849aa615842bfa;
                    _RefractionFunction_a3e633706b6d4258a0849aa615842bfa.WorldSpaceNormal = IN.WorldSpaceNormal;
                    _RefractionFunction_a3e633706b6d4258a0849aa615842bfa.AbsoluteWorldSpacePosition = IN.AbsoluteWorldSpacePosition;
                    float4 _RefractionFunction_a3e633706b6d4258a0849aa615842bfa_OutVector4_1_Vector4;
                    SG_RefractionFunction_9811543ea6182ea43ac1252406d81f44_float(_Add_368a8dbb0607410ab5e19d2508d4a7c5_Out_2_Float, float(1), Boolean_b32bd6d5b96545e491c89ead440163e6, float3 (0, 0, 0), _RefractionFunction_a3e633706b6d4258a0849aa615842bfa, _RefractionFunction_a3e633706b6d4258a0849aa615842bfa_OutVector4_1_Vector4);
                    float _Swizzle_2c46d84cc89f40d4a5dd221ca0747b30_Out_1_Float = _RefractionFunction_a3e633706b6d4258a0849aa615842bfa_OutVector4_1_Vector4.z;
                    float3 _Vector3_87f22b0e4cea49d091c1042330588158_Out_0_Vector3 = float3(_Swizzle_547431f9e05a430ba25f6eb4314672a4_Out_1_Float, _Swizzle_4bf7b0731c2442b19b55f1999de0e374_Out_1_Float, _Swizzle_2c46d84cc89f40d4a5dd221ca0747b30_Out_1_Float);
                    float3 _Multiply_c323434716454bbb80c80155dde90cee_Out_2_Vector3;
                    Unity_Multiply_float3_float3((_Property_bed37ecbfa734f5b843dec423ca460dc_Out_0_Vector4.xyz), _Vector3_87f22b0e4cea49d091c1042330588158_Out_0_Vector3, _Multiply_c323434716454bbb80c80155dde90cee_Out_2_Vector3);
                    float _Property_ed6b29ef58c8405baef5bc8dfd135b7c_Out_0_Boolean = _UseEmissive;
                    float3 _Branch_5e93ebdf3ba24ef29c4739eaaaf20bda_Out_3_Vector3;
                    Unity_Branch_float3(_Property_ed6b29ef58c8405baef5bc8dfd135b7c_Out_0_Boolean, _Multiply_c323434716454bbb80c80155dde90cee_Out_2_Vector3, float3(0, 0, 0), _Branch_5e93ebdf3ba24ef29c4739eaaaf20bda_Out_3_Vector3);
                    surface.BaseColor = _Multiply_c323434716454bbb80c80155dde90cee_Out_2_Vector3;
                    surface.NormalTS = IN.TangentSpaceNormal;
                    surface.Emission = _Branch_5e93ebdf3ba24ef29c4739eaaaf20bda_Out_3_Vector3;
                    surface.Metallic = float(0);
                    surface.Smoothness = float(0.5);
                    surface.Occlusion = float(1);
                    surface.Alpha = float(1);
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
                
                    output.ObjectSpaceNormal =                          input.normalOS;
                    output.ObjectSpaceTangent =                         input.tangentOS.xyz;
                    output.ObjectSpacePosition =                        input.positionOS;
                
                    return output;
                }
                
            SurfaceDescriptionInputs BuildSurfaceDescriptionInputs(Varyings input)
                {
                    SurfaceDescriptionInputs output;
                    ZERO_INITIALIZE(SurfaceDescriptionInputs, output);
                
                #ifdef HAVE_VFX_MODIFICATION
                #if VFX_USE_GRAPH_VALUES
                    uint instanceActiveIndex = asuint(UNITY_ACCESS_INSTANCED_PROP(PerInstance, _InstanceActiveIndex));
                    /* WARNING: $splice Could not find named fragment 'VFXLoadGraphValues' */
                #endif
                    /* WARNING: $splice Could not find named fragment 'VFXSetFragInputs' */
                
                #endif
                
                    
                
                    // must use interpolated tangent, bitangent and normal before they are normalized in the pixel shader.
                    float3 unnormalizedNormalWS = input.normalWS;
                    const float renormFactor = 1.0 / length(unnormalizedNormalWS);
                
                
                    output.WorldSpaceNormal = renormFactor * input.normalWS.xyz;      // we want a unit length Normal Vector node in shader graph
                    output.TangentSpaceNormal = float3(0.0f, 0.0f, 1.0f);
                
                
                    output.AbsoluteWorldSpacePosition = GetAbsolutePositionWS(input.positionWS);
                
                    #if UNITY_UV_STARTS_AT_TOP
                    #else
                    #endif
                
                
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
