Shader "Water shader" {
	Properties{
		//inputs in inspector
		//Refelction cubeMap
		_Cube("Reflection Map", Cube) = "" {}
		_color("Colour", Color) = (1,1,1,1)
		_SpecColor("Specular Material Color", Color) = (1,1,1,1)
		_Shininess("Shininess", Float) = 10
		//Wave makers
		_Strenght("Strength", Range(0,2)) = 0.2
		_Speed("Speed", Range(-100,100)) = 46

		[HideInInspector]_k("K", Float) = 1 //k from wave equation

		//Displacement map and max displacement
		_DisplacementTex("Displacement Texture", 2D) = "white" {}
		_MaxDisplacement("Max Displacement", Range(0,0.001)) = 0.0001
	}
		SubShader{
			Tags{ "RenderType" = "transparent"}
			Pass {
				Tags{ "LightMode" = "ForwardBase" }
				CGPROGRAM

				#pragma vertex vertex  
				#pragma fragment fragment

				#include "UnityCG.cginc"
				uniform float4 _LightColor0;
				//color of light source

				// User-specified uniforms
				uniform samplerCUBE _Cube;	//Reflection CubeMap
				float4 _color;
				float4 _SpecColor;
				uniform float _Shininess;
				// Floats for water waves
				float _Strenght;
				float _Speed;
				float _k;
				//Displacements
				uniform sampler2D _DisplacementTex;
				float _MaxDisplacement;

				struct vertexInput {
					float4 vertex : POSITION;
					float3 normal : NORMAL;
					float4 texcoord : TEXCOORD2;  //used for displacement
				};
				struct vertexOutput {
					float4 pos : SV_POSITION;
					float3 normalDir : TEXCOORD0;
					float3 viewDir : TEXCOORD1;
					float4 texcoord : TEXCOORD2;  //used for displacement
					float4 col : COLOR;
				};

				vertexOutput vertex(vertexInput input){
					vertexOutput output;
					//Displacement
					float4 dispTexColor = tex2Dlod(_DisplacementTex, float4(input.texcoord.xy, 0.0, 0.0));
					float displacement2 = dot(float3(0.21, 0.72, 0.07), dispTexColor.rgb) * _MaxDisplacement;
					float4 newVertexPos = input.vertex + float4(input.normal * displacement2, 0.0);

					//Making waves and reflect
					float4x4 modelMatrix = unity_ObjectToWorld;
					float4x4 modelMatrixInverse = unity_WorldToObject;

					float4 worldPos = mul(unity_ObjectToWorld, newVertexPos);
					float4 displacement = 2 * (pow((sin(worldPos.x) + 1) / 2, _k)) + 2 * (pow((sin(worldPos.x + (_Speed * _Time)) + 1) / 2, _k));
					worldPos.y = worldPos.y + (displacement * _Strenght);

					float3 normalDirection = normalize(mul(input.normal, modelMatrixInverse));
					float3 viewDirection = normalize(_WorldSpaceCameraPos
						- mul(modelMatrix, input.vertex).xyz);
					float3 lightDirection;
					float attenuation;

					if (0.0 == _WorldSpaceLightPos0.w) // directional light?
					{
						attenuation = 1.0; // no attenuation
						lightDirection = normalize(_WorldSpaceLightPos0.xyz);
					}
					else // point or spot light
					{
						float3 vertexToLightSource = _WorldSpaceLightPos0.xyz
							- mul(modelMatrix, input.vertex).xyz;
						float distance = length(vertexToLightSource);
						attenuation = 1.0 / distance; // linear attenuation 
						lightDirection = normalize(vertexToLightSource);
					}

					float3 ambientLighting =
						UNITY_LIGHTMODEL_AMBIENT.rgb * _color.rgb;

					float3 diffuseReflection =
						attenuation * _LightColor0.rgb * _color.rgb
						* max(0.0, dot(normalDirection, lightDirection));

					float3 specularReflection;
					if (dot(normalDirection, lightDirection) < 0.0)// light source on the wrong side?
					{
						specularReflection = float3(0.0, 0.0, 0.0);
						// no specular reflection
					}
					else // light source on the right side
					{
						specularReflection = attenuation * _LightColor0.rgb
							* _SpecColor.rgb * pow(max(0.0, dot(
								reflect(-lightDirection, normalDirection),
								viewDirection)), _Shininess);
					}

					output.col = float4(ambientLighting + diffuseReflection + specularReflection, 1.0);

					output.viewDir = mul(modelMatrix, input.vertex).xyz - _WorldSpaceCameraPos;
					output.normalDir = normalize(mul(float4(input.normal, 0.0), modelMatrixInverse).xyz);

					output.pos = mul(UNITY_MATRIX_VP, worldPos);
	
					return output;
				}
	
				float4 fragment(vertexOutput input) : COLOR
				{
					float3 reflectedDir =
					reflect(input.viewDir, normalize(input.normalDir));

					float4 reflectColor = texCUBE(_Cube, reflectedDir);

					return reflectColor * _color * input.col;
				}

				ENDCG
			}


			Pass{
				Tags { "LightMode" = "ForwardAdd" }
					// pass for additional light sources
				Blend One One // additive blending 
				CGPROGRAM

				#pragma vertex vert  
				#pragma fragment frag 

				#include "UnityCG.cginc"
				uniform float4 _LightColor0;
				// color of light source (from "Lighting.cginc")

				// User-specified properties
				uniform samplerCUBE _Cube;	//Reflection CubeMap
				uniform float4 _Color;
				uniform float4 _SpecColor;
				uniform float _Shininess;
				// Floats for water waves
				float _Strenght;
				float _Speed;
				float _k;
				//DisplacementMap
				uniform sampler2D _DisplacementTex;
				float _MaxDisplacement;


				struct vertexInput {
					float4 vertex : POSITION;
					float3 normal : NORMAL;
					float4 texcoord : TEXCOORD2;
				};

				struct vertexOutput {
					float4 pos : SV_POSITION;
					float4 col : COLOR;
					float3 normalDir : TEXCOORD0;
					float3 viewDir : TEXCOORD1;
					float4 texcoord : TEXCOORD2;
				};

				vertexOutput vert(vertexInput input)
				{
					vertexOutput output;
					//Displacement
					float4 dispTexColor = tex2Dlod(_DisplacementTex, float4(input.texcoord.xy, 0.0, 0.0));
					float displacement2 = dot(float3(0.21, 0.72, 0.07), dispTexColor.rgb) * _MaxDisplacement;
					float4 newVertexPos = input.vertex + float4(input.normal * displacement2, 0.0);

					float4x4 modelMatrix = unity_ObjectToWorld;
					float4x4 modelMatrixInverse = unity_WorldToObject;


					float4 worldPos = mul(unity_ObjectToWorld, newVertexPos);
					float4 displacement = 2 * (pow((sin(worldPos.x) + 1) / 2, _k)) + 2 * (pow((sin(worldPos.x + (_Speed * _Time)) + 1) / 2, _k));
					worldPos.y = worldPos.y + (displacement * _Strenght);


					float3 normalDirection = normalize(
						mul(input.normal, modelMatrixInverse));
					float3 viewDirection = normalize(_WorldSpaceCameraPos
						- mul(modelMatrix, input.vertex).xyz);
					float3 lightDirection;
					float attenuation;

					if (0.0 == _WorldSpaceLightPos0.w) // directional light?
					{
						attenuation = 1.0; // no attenuation
						lightDirection = normalize(_WorldSpaceLightPos0.xyz);
					}
					else // point or spot light
					{
						float3 vertexToLightSource = _WorldSpaceLightPos0.xyz
						- mul(modelMatrix, input.vertex).xyz;
						float distance = length(vertexToLightSource);
						attenuation = 1.0 / distance; // linear attenuation 
						lightDirection = normalize(vertexToLightSource);
					}

					float3 diffuseReflection =
					attenuation * _LightColor0.rgb * _Color.rgb
					* max(0.0, dot(normalDirection, lightDirection));

					float3 specularReflection;
					if (dot(normalDirection, lightDirection) < 0.0)
					// light source on the wrong side?
					{
						specularReflection = float3(0.0, 0.0, 0.0);
						// no specular reflection
					}
					else // light source on the right side
					{
						specularReflection = attenuation * _LightColor0.rgb
						* _SpecColor.rgb * pow(max(0.0, dot(
						reflect(-lightDirection, normalDirection),
						viewDirection)), _Shininess);
					}

					output.col = float4(diffuseReflection
					+ specularReflection, 1.0);
					// no ambient contribution in this pass
					
					//output.pos = UnityObjectToClipPos(input.vertex);
					output.pos = mul(UNITY_MATRIX_VP, worldPos);
					return output;
				}

			float4 frag(vertexOutput input) : COLOR
			{
			   return input.col;
			}

			ENDCG
			}
		}
	Fallback "Specular"
}