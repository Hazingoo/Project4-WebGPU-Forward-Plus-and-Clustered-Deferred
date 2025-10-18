// TODO-2: implement the Forward+ fragment shader

// See naive.fs.wgsl for basic fragment shader setup; this shader should use light clusters instead of looping over all lights

// ------------------------------------
// Shading process:
// ------------------------------------
// Determine which cluster contains the current fragment.
// Retrieve the number of lights that affect the current fragment from the cluster’s data.
// Initialize a variable to accumulate the total light contribution for the fragment.
// For each light in the cluster:
//     Access the light's properties using its index.
//     Calculate the contribution of the light based on its position, the fragment’s position, and the surface normal.
//     Add the calculated contribution to the total light accumulation.
// Multiply the fragment’s diffuse color by the accumulated light contribution.
// Return the final color, ensuring that the alpha component is set appropriately (typically to 1).

@group(${bindGroup_scene}) @binding(0) var<uniform> cameraUniforms: CameraUniforms;
@group(${bindGroup_scene}) @binding(1) var<storage, read> lightSet: LightSet;
@group(${bindGroup_scene}) @binding(2) var<storage, read> clusterSet: ClusterSet;
@group(${bindGroup_scene}) @binding(3) var<storage, read> clusterLightIndices: ClusterLightIndices;

@group(${bindGroup_material}) @binding(0) var diffuseTex: texture_2d<f32>;
@group(${bindGroup_material}) @binding(1) var diffuseTexSampler: sampler;

struct FragmentInput
{
    @location(0) pos: vec3f,
    @location(1) nor: vec3f,
    @location(2) uv: vec2f
}

fn screenToCluster(screenX: f32, screenY: f32, depth: f32) -> vec3u {
    let clusterX = u32(clamp(screenX * cameraUniforms.clusterSizeX, 0.0, cameraUniforms.clusterSizeX - 1.0));
    let clusterY = u32(clamp(screenY * cameraUniforms.clusterSizeY, 0.0, cameraUniforms.clusterSizeY - 1.0));
    
    let clampedDepth = clamp(depth, cameraUniforms.nearPlane, cameraUniforms.farPlane);
    let logDepth = log(clampedDepth / cameraUniforms.nearPlane) / log(cameraUniforms.farPlane / cameraUniforms.nearPlane);
    let clusterZ = u32(clamp(logDepth * cameraUniforms.clusterSizeZ, 0.0, cameraUniforms.clusterSizeZ - 1.0));
    
    return vec3u(clusterX, clusterY, clusterZ);
}

fn getClusterIndex(clusterX: u32, clusterY: u32, clusterZ: u32) -> u32 {
    return clusterZ * u32(cameraUniforms.clusterSizeX) * u32(cameraUniforms.clusterSizeY) + 
           clusterY * u32(cameraUniforms.clusterSizeX) + clusterX;
}

@fragment
fn main(in: FragmentInput, @builtin(position) fragCoord: vec4f) -> @location(0) vec4f
{
    let diffuseColor = textureSample(diffuseTex, diffuseTexSampler, in.uv);
    if (diffuseColor.a < 0.5f) {
        discard;
    }

    let screenX = fragCoord.x / cameraUniforms.screenWidth;
    let screenY = fragCoord.y / cameraUniforms.screenHeight;
    
    let posView = (cameraUniforms.viewMat * vec4f(in.pos, 1.0)).xyz;
    let depth = -posView.z;  
    
    let clusterCoords = screenToCluster(screenX, screenY, depth);
    let clusterIndex = getClusterIndex(clusterCoords.x, clusterCoords.y, clusterCoords.z);
    
    let clusterInfo = clusterSet.clusterLightInfos[clusterIndex];
    
    var totalLightContrib = vec3f(0.1, 0.1, 0.1);
    
    for (var i = 0u; i < clusterInfo.lightCount; i++) {
        let lightIdx = clusterLightIndices.lightIndices[clusterInfo.lightOffset + i];
        let light = lightSet.lights[lightIdx];
        totalLightContrib += calculateLightContrib(light, in.pos, normalize(in.nor));
    }

    var finalColor = diffuseColor.rgb * totalLightContrib;
    return vec4(finalColor, 1);
}
