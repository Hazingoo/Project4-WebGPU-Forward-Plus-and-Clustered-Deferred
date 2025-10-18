// TODO-3: implement the Clustered Deferred fullscreen fragment shader

// Similar to the Forward+ fragment shader, but with vertex information coming from the G-buffer instead.

@group(${bindGroup_scene}) @binding(0) var<uniform> cameraUniforms: CameraUniforms;
@group(${bindGroup_scene}) @binding(1) var<storage, read> lightSet: LightSet;
@group(${bindGroup_scene}) @binding(2) var<storage, read> clusterSet: ClusterSet;
@group(${bindGroup_scene}) @binding(3) var<storage, read> clusterLightIndices: ClusterLightIndices;

@group(1) @binding(0) var gBufferAlbedo: texture_2d<f32>;
@group(1) @binding(1) var gBufferNormal: texture_2d<f32>;
@group(1) @binding(2) var gBufferPosition: texture_2d<f32>;
@group(1) @binding(3) var gBufferDepth: texture_2d<f32>;
@group(1) @binding(4) var gBufferSampler: sampler;

struct FragmentInput
{
    @builtin(position) fragCoord: vec4f,
    @location(0) uv: vec2f
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
fn main(in: FragmentInput) -> @location(0) vec4f
{
    let pixelCoord = vec2i(in.fragCoord.xy);
    
    let albedo = textureLoad(gBufferAlbedo, pixelCoord, 0);
    let normalPacked = textureLoad(gBufferNormal, pixelCoord, 0);
    let worldPos = textureLoad(gBufferPosition, pixelCoord, 0).xyz;
    let linearDepth = textureLoad(gBufferDepth, pixelCoord, 0).r;
    
    let worldNormal = normalize(normalPacked.xyz * 2.0 - 1.0);
    
    let debugMode = 0;
    
    if (debugMode == 1) {
        return vec4f(albedo.rgb, 1.0);
    } else if (debugMode == 2) {
        // Show normals 
        return vec4f(worldNormal * 0.5 + 0.5, 1.0);
    } else if (debugMode == 3) {
        // Show position
        let posVisualized = fract(worldPos * 0.2);
        return vec4f(posVisualized, 1.0);
    } else if (debugMode == 4) {
    // Show depth
    let depthNormalized = clamp(linearDepth / cameraUniforms.farPlane, 0.0, 1.0);
        return vec4f(vec3f(depthNormalized), 1.0);
    }
    

    

    let screenX = in.fragCoord.x / cameraUniforms.screenWidth;
    let screenY = in.fragCoord.y / cameraUniforms.screenHeight;
    
    let clusterCoords = screenToCluster(screenX, screenY, linearDepth);
    let clusterIndex = getClusterIndex(clusterCoords.x, clusterCoords.y, clusterCoords.z);
    
    let clusterInfo = clusterSet.clusterLightInfos[clusterIndex];
    
    var totalLightContrib = vec3f(0.1, 0.1, 0.1);
    
    for (var i = 0u; i < clusterInfo.lightCount; i++) {
        let lightIdx = clusterLightIndices.lightIndices[clusterInfo.lightOffset + i];
        let light = lightSet.lights[lightIdx];
        
        let vecToLight = light.pos - worldPos;
        let distToLight = length(vecToLight);
        let lightRadius = f32(${lightRadius});
        
        let attenuation = clamp(1.0 - pow(distToLight / lightRadius, 4.0), 0.0, 1.0) / (distToLight * distToLight);
        
        let lambert = max(dot(worldNormal, normalize(vecToLight)), 0.0);
        
        totalLightContrib += light.color * lambert * attenuation;
    }
    
    let finalColor = albedo.rgb * totalLightContrib;
    return vec4f(finalColor, 1.0);
}
