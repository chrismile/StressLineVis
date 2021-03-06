-- Programmable.Vertex

#version 430 core

struct LinePointData {
    vec3 vertexPosition;
    float vertexAttribute;
    vec3 vertexTangent;
    uint vertexPrincipalStressIndex;
};

layout (std430, binding = 2) buffer LinePoints {
    LinePointData linePoints[];
};
#ifdef USE_LINE_HIERARCHY_LEVEL
layout (std430, binding = 3) buffer LineHierarchyLevels {
    float lineHierarchyLevels[];
};
#endif

out vec3 fragmentPositionWorld;
#ifdef USE_SCREEN_SPACE_POSITION
out vec3 screenSpacePosition;
#endif
out float fragmentAttribute;
out float fragmentNormalFloat; // Between -1 and 1
out vec3 normal0;
out vec3 normal1;
#if defined(USE_PRINCIPAL_STRESS_DIRECTION_INDEX) || defined(USE_LINE_HIERARCHY_LEVEL)
flat out uint fragmentPrincipalStressIndex;
#endif
#ifdef USE_LINE_HIERARCHY_LEVEL
flat out float fragmentLineHierarchyLevel;
#endif
#ifdef VISUALIZE_SEEDING_PROCESS
flat out uint fragmentLineAppearanceOrder;
#endif

uniform vec3 cameraPosition;
uniform float lineWidth;

void main() {
    uint pointIndex = gl_VertexID/2;
    LinePointData linePointData = linePoints[pointIndex];
    vec3 linePoint = (mMatrix * vec4(linePointData.vertexPosition, 1.0)).xyz;
    vec3 tangent = normalize(linePointData.vertexTangent);

    vec3 viewDirection = normalize(cameraPosition - linePoint);
    vec3 offsetDirection = normalize(cross(viewDirection, tangent));
    vec3 vertexPosition;
    float shiftSign = 1.0f;
    if (gl_VertexID % 2 == 0) {
        shiftSign = -1.0;
    }
    vertexPosition = linePoint + shiftSign * lineWidth * 0.5 * offsetDirection;
    fragmentNormalFloat = shiftSign;
    normal0 = normalize(cross(tangent, offsetDirection));
    normal1 = offsetDirection;
#if defined(USE_PRINCIPAL_STRESS_DIRECTION_INDEX) || defined(USE_LINE_HIERARCHY_LEVEL)
    fragmentPrincipalStressIndex = linePointData.vertexPrincipalStressIndex;
#endif

#ifdef USE_LINE_HIERARCHY_LEVEL
    float lineHierarchyLevel = lineHierarchyLevels[pointIndex];
    fragmentLineHierarchyLevel = lineHierarchyLevel;
#endif
#ifdef VISUALIZE_SEEDING_PROCESS
    // Unsupported for now.
    fragmentLineAppearanceOrder = 0;
#endif

    fragmentPositionWorld = vertexPosition;
#ifdef USE_SCREEN_SPACE_POSITION
    screenSpacePosition = (vMatrix * vec4(vertexPosition, 1.0)).xyz;
#endif
    fragmentAttribute = linePointData.vertexAttribute;
    gl_Position = pMatrix * vMatrix * vec4(vertexPosition, 1.0);
}

-- VBO.Vertex

#version 430 core

layout(location = 0) in vec3 vertexPosition;
layout(location = 1) in float vertexAttribute;
layout(location = 2) in vec3 vertexTangent;
#if defined(USE_PRINCIPAL_STRESS_DIRECTION_INDEX) || defined(USE_LINE_HIERARCHY_LEVEL)
layout(location = 4) in uint vertexPrincipalStressIndex;
#endif
#ifdef USE_LINE_HIERARCHY_LEVEL
layout(location = 5) in float vertexLineHierarchyLevel;
#endif
#ifdef VISUALIZE_SEEDING_PROCESS
layout(location = 6) in uint vertexLineAppearanceOrder;
#endif

out VertexData {
    vec3 linePosition;
    float lineAttribute;
    vec3 lineTangent;
#if defined(USE_PRINCIPAL_STRESS_DIRECTION_INDEX) || defined(USE_LINE_HIERARCHY_LEVEL)
    uint linePrincipalStressIndex;
#endif
#ifdef USE_LINE_HIERARCHY_LEVEL
    float lineLineHierarchyLevel;
#endif
#ifdef VISUALIZE_SEEDING_PROCESS
    uint lineLineAppearanceOrder;
#endif
};

#include "TransferFunction.glsl"

void main() {
    linePosition = (mMatrix * vec4(vertexPosition, 1.0)).xyz;
    lineAttribute = vertexAttribute;
    lineTangent = vertexTangent;
#if defined(USE_PRINCIPAL_STRESS_DIRECTION_INDEX) || defined(USE_LINE_HIERARCHY_LEVEL)
    linePrincipalStressIndex = vertexPrincipalStressIndex;
#endif
#ifdef USE_LINE_HIERARCHY_LEVEL
    lineLineHierarchyLevel = vertexLineHierarchyLevel;
#endif
#ifdef VISUALIZE_SEEDING_PROCESS
    lineLineAppearanceOrder = vertexLineAppearanceOrder;
#endif
    gl_Position = mvpMatrix * vec4(vertexPosition, 1.0);
}

-- VBO.Geometry

#version 430 core

layout(lines) in;
layout(triangle_strip, max_vertices = 4) out;

uniform vec3 cameraPosition;
uniform float lineWidth;

out vec3 fragmentPositionWorld;
#ifdef USE_SCREEN_SPACE_POSITION
out vec3 screenSpacePosition;
#endif
out float fragmentAttribute;
out float fragmentNormalFloat; // Between -1 and 1
out vec3 normal0;
out vec3 normal1;
#if defined(USE_PRINCIPAL_STRESS_DIRECTION_INDEX) || defined(USE_LINE_HIERARCHY_LEVEL)
flat out uint fragmentPrincipalStressIndex;
#endif
#ifdef USE_LINE_HIERARCHY_LEVEL
flat out float fragmentLineHierarchyLevel;
#endif
#ifdef VISUALIZE_SEEDING_PROCESS
flat out uint fragmentLineAppearanceOrder;
#endif

in VertexData {
    vec3 linePosition;
    float lineAttribute;
    vec3 lineTangent;
#if defined(USE_PRINCIPAL_STRESS_DIRECTION_INDEX) || defined(USE_LINE_HIERARCHY_LEVEL)
    uint linePrincipalStressIndex;
#endif
#ifdef USE_LINE_HIERARCHY_LEVEL
    float lineLineHierarchyLevel;
#endif
#ifdef VISUALIZE_SEEDING_PROCESS
    uint lineLineAppearanceOrder;
#endif
} v_in[];

void main() {
    vec3 linePosition0 = (mMatrix * vec4(v_in[0].linePosition, 1.0)).xyz;
    vec3 linePosition1 = (mMatrix * vec4(v_in[1].linePosition, 1.0)).xyz;
    vec3 tangent0 = normalize(v_in[0].lineTangent);
    vec3 tangent1 = normalize(v_in[1].lineTangent);

    vec3 viewDirection0 = normalize(cameraPosition - linePosition0);
    vec3 viewDirection1 = normalize(cameraPosition - linePosition1);
    vec3 offsetDirection0 = normalize(cross(tangent0, viewDirection0));
    vec3 offsetDirection1 = normalize(cross(tangent1, viewDirection1));
    vec3 vertexPosition;

    const float lineRadius = lineWidth * 0.5;
    const mat4 pvMatrix = pMatrix * vMatrix;

    // Vertex 0
    fragmentAttribute = v_in[0].lineAttribute;
    normal0 = normalize(cross(tangent0, offsetDirection0));
    normal1 = offsetDirection0;
#if defined(USE_PRINCIPAL_STRESS_DIRECTION_INDEX) || defined(USE_LINE_HIERARCHY_LEVEL)
    fragmentPrincipalStressIndex = v_in[0].linePrincipalStressIndex;
#endif
#ifdef USE_LINE_HIERARCHY_LEVEL
    fragmentLineHierarchyLevel = v_in[0].lineLineHierarchyLevel;
#endif
#ifdef VISUALIZE_SEEDING_PROCESS
    fragmentLineAppearanceOrder = v_in[0].lineLineAppearanceOrder;
#endif

    vertexPosition = linePosition0 - lineRadius * offsetDirection0;
    fragmentPositionWorld = vertexPosition;
#ifdef USE_SCREEN_SPACE_POSITION
    screenSpacePosition = (vMatrix * vec4(vertexPosition, 1.0)).xyz;
#endif
    fragmentNormalFloat = -1.0;
    gl_Position = pvMatrix * vec4(vertexPosition, 1.0);
    EmitVertex();

    vertexPosition = linePosition0 + lineRadius * offsetDirection0;
    fragmentPositionWorld = vertexPosition;
#ifdef USE_SCREEN_SPACE_POSITION
    screenSpacePosition = (vMatrix * vec4(vertexPosition, 1.0)).xyz;
#endif
    fragmentNormalFloat = 1.0;
    gl_Position = pvMatrix * vec4(vertexPosition, 1.0);
    EmitVertex();

    // Vertex 1
    fragmentAttribute = v_in[1].lineAttribute;
    normal0 = normalize(cross(tangent1, offsetDirection1));
    normal1 = offsetDirection1;
#if defined(USE_PRINCIPAL_STRESS_DIRECTION_INDEX) || defined(USE_LINE_HIERARCHY_LEVEL)
    fragmentPrincipalStressIndex = v_in[1].linePrincipalStressIndex;
#endif
#ifdef USE_LINE_HIERARCHY_LEVEL
    fragmentLineHierarchyLevel = v_in[1].lineLineHierarchyLevel;
#endif
#ifdef VISUALIZE_SEEDING_PROCESS
    fragmentLineAppearanceOrder = v_in[1].lineLineAppearanceOrder;
#endif

    vertexPosition = linePosition1 - lineRadius * offsetDirection1;
#ifdef USE_SCREEN_SPACE_POSITION
    screenSpacePosition = (vMatrix * vec4(vertexPosition, 1.0)).xyz;
#endif
    fragmentPositionWorld = vertexPosition;
    fragmentNormalFloat = -1.0;
    gl_Position = pvMatrix * vec4(vertexPosition, 1.0);
    EmitVertex();

    vertexPosition = linePosition1 + lineRadius * offsetDirection1;
#ifdef USE_SCREEN_SPACE_POSITION
    screenSpacePosition = (vMatrix * vec4(vertexPosition, 1.0)).xyz;
#endif
    fragmentPositionWorld = vertexPosition;
    fragmentNormalFloat = 1.0;
    gl_Position = pvMatrix * vec4(vertexPosition, 1.0);
    EmitVertex();

    EndPrimitive();
}

-- Fragment

#version 450 core

in vec3 fragmentPositionWorld;
#ifdef USE_SCREEN_SPACE_POSITION
in vec3 screenSpacePosition;
#endif
in float fragmentAttribute;
in float fragmentNormalFloat;
in vec3 normal0;
in vec3 normal1;
#if defined(USE_PRINCIPAL_STRESS_DIRECTION_INDEX) || defined(USE_LINE_HIERARCHY_LEVEL)
flat in uint fragmentPrincipalStressIndex;
#endif
#ifdef USE_LINE_HIERARCHY_LEVEL
flat in float fragmentLineHierarchyLevel;
#ifdef USE_TRANSPARENCY
//uniform vec3 lineHierarchySliderLower;
//uniform vec3 lineHierarchySliderUpper;
uniform sampler1DArray lineHierarchyImportanceMap;
#else
uniform vec3 lineHierarchySlider;
#endif
#endif
#ifdef VISUALIZE_SEEDING_PROCESS
flat in uint fragmentLineAppearanceOrder;
uniform int currentSeedIdx;
#endif

#if defined(DIRECT_BLIT_GATHER)
out vec4 fragColor;
#endif

uniform vec3 cameraPosition;
uniform float lineWidth;
uniform vec3 backgroundColor;
uniform vec3 foregroundColor;

#define M_PI 3.14159265358979323846

#include "TransferFunction.glsl"

#if !defined(DIRECT_BLIT_GATHER)
#include OIT_GATHER_HEADER
#endif

#define DEPTH_HELPER_USE_PROJECTION_MATRIX
#include "DepthHelper.glsl"
#include "Lighting.glsl"

void main() {
#if defined(USE_LINE_HIERARCHY_LEVEL) && !defined(USE_TRANSPARENCY)
    float slider = lineHierarchySlider[fragmentPrincipalStressIndex];
    if (slider > fragmentLineHierarchyLevel) {
        discard;
    }
#endif
#ifdef VISUALIZE_SEEDING_PROCESS
    if (int(fragmentLineAppearanceOrder) > currentSeedIdx) {
        discard;
    }
#endif

    // Compute the normal of the billboard tube for shading.
    vec3 fragmentNormal;
    float interpolationFactor = fragmentNormalFloat;
    vec3 normalCos = normalize(normal0);
    vec3 normalSin = normalize(normal1);
    if (interpolationFactor < 0.0) {
        normalSin = -normalSin;
        interpolationFactor = -interpolationFactor;
    }
    float angle = interpolationFactor * M_PI * 0.5;
    fragmentNormal = cos(angle) * normalCos + sin(angle) * normalSin;

#ifdef USE_PRINCIPAL_STRESS_DIRECTION_INDEX
    vec4 fragmentColor = transferFunction(fragmentAttribute, fragmentPrincipalStressIndex);
#else
    vec4 fragmentColor = transferFunction(fragmentAttribute);
#endif

#if defined(USE_LINE_HIERARCHY_LEVEL) && defined(USE_TRANSPARENCY)
    //float lower = lineHierarchySliderLower[fragmentPrincipalStressIndex];
    //float upper = lineHierarchySliderUpper[fragmentPrincipalStressIndex];
    //fragmentColor.a *= (upper - lower) * fragmentLineHierarchyLevel + lower;
    fragmentColor.a *= texture(
            lineHierarchyImportanceMap, vec2(fragmentLineHierarchyLevel, float(fragmentPrincipalStressIndex))).r;
#endif

    fragmentColor = blinnPhongShading(fragmentColor, fragmentNormal);

    float absCoords = abs(fragmentNormalFloat);
    float fragmentDepth = length(fragmentPositionWorld - cameraPosition);
    const float WHITE_THRESHOLD = 0.7;
    float EPSILON = clamp(fragmentDepth * 0.0005 / lineWidth, 0.0, 0.49);
    float EPSILON_WHITE = fwidth(absCoords);
    float coverage = 1.0 - smoothstep(1.0 - EPSILON, 1.0, absCoords);
    //float coverage = 1.0 - smoothstep(1.0, 1.0, abs(fragmentNormalFloat));
    vec4 colorOut = vec4(mix(fragmentColor.rgb, foregroundColor,
            smoothstep(WHITE_THRESHOLD - EPSILON_WHITE, WHITE_THRESHOLD + EPSILON_WHITE, absCoords)),
            fragmentColor.a * coverage);

#if defined(DIRECT_BLIT_GATHER)
    // To counteract depth fighting with overlay wireframe.
    float depthOffset = -0.00001;
    if (absCoords >= WHITE_THRESHOLD - EPSILON_WHITE) {
        depthOffset = 0.002;
    }
    //gl_FragDepth = clamp(gl_FragCoord.z + depthOffset, 0.0, 0.999);
    gl_FragDepth = convertLinearDepthToDepthBufferValue(
            convertDepthBufferValueToLinearDepth(gl_FragCoord.z) + fragmentDepth
            - length(fragmentPositionWorld - cameraPosition) - 0.0001);
    if (colorOut.a < 0.01) {
        discard;
    }
    colorOut.a = 1.0;
    fragColor = colorOut;
#elif defined(USE_SYNC_FRAGMENT_SHADER_INTERLOCK)
    // Area of mutual exclusion for fragments mapping to the same pixel
    beginInvocationInterlockARB();
    gatherFragment(colorOut);
    endInvocationInterlockARB();
#elif defined(USE_SYNC_SPINLOCK)
    uint x = uint(gl_FragCoord.x);
    uint y = uint(gl_FragCoord.y);
    uint pixelIndex = addrGen(uvec2(x,y));
    /**
     * Spinlock code below based on code in:
     * Brüll, Felix. (2018). Order-Independent Transparency Acceleration. 10.13140/RG.2.2.17568.84485.
     */
    if (!gl_HelperInvocation) {
        bool keepWaiting = true;
        while (keepWaiting) {
            if (atomicCompSwap(spinlockViewportBuffer[pixelIndex], 0, 1) == 0) {
                gatherFragment(colorOut);
                memoryBarrier();
                atomicExchange(spinlockViewportBuffer[pixelIndex], 0);
                keepWaiting = false;
            }
        }
    }
#else
    gatherFragment(colorOut);
#endif
}
