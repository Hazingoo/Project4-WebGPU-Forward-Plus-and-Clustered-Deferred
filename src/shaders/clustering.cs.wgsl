// TODO-2: implement the light clustering compute shader

// ------------------------------------
// Calculating cluster bounds:
// ------------------------------------
// For each cluster (X, Y, Z):
//     - Calculate the screen-space bounds for this cluster in 2D (XY).
//     - Calculate the depth bounds for this cluster in Z (near and far planes).
//     - Convert these screen and depth bounds into view-space coordinates.
//     - Store the computed bounding box (AABB) for the cluster.

// ------------------------------------
// Assigning lights to clusters:
// ------------------------------------
// For each cluster:
//     - Initialize a counter for the number of lights in this cluster.

//     For each light:
//         - Check if the light intersects with the cluster's bounding box (AABB).
//         - If it does, add the light to the cluster's light list.
//         - Stop adding lights if the maximum number of lights is reached.

//     - Store the number of lights assigned to this cluster.

@group(0) @binding(0) var<uniform> cameraUniforms: CameraUniforms;
@group(0) @binding(1) var<storage, read> lightSet: LightSet;
@group(0) @binding(2) var<storage, read_write> clusterSet: ClusterSet;
@group(0) @binding(3) var<storage, read_write> clusterLightIndices: ClusterLightIndices;

fn getClusterIndex(clusterX: u32, clusterY: u32, clusterZ: u32) -> u32 {
    return clusterZ * u32(cameraUniforms.clusterSizeX) * u32(cameraUniforms.clusterSizeY) + 
           clusterY * u32(cameraUniforms.clusterSizeX) + clusterX;
}

fn screenToCluster(screenX: f32, screenY: f32, depth: f32) -> vec3u {
    let clusterX = u32(screenX * cameraUniforms.clusterSizeX);
    let clusterY = u32(screenY * cameraUniforms.clusterSizeY);
    
    let logDepth = log(depth / cameraUniforms.nearPlane) / log(cameraUniforms.farPlane / cameraUniforms.nearPlane);
    let clusterZ = u32(logDepth * cameraUniforms.clusterSizeZ);
    
    return vec3u(clusterX, clusterY, clusterZ);
}

fn lightIntersectsCluster(light: Light, clusterX: u32, clusterY: u32, clusterZ: u32) -> bool {
    let clusterScreenX = f32(clusterX) / cameraUniforms.clusterSizeX;
    let clusterScreenY = f32(clusterY) / cameraUniforms.clusterSizeY;
    
    let clusterDepthNear = cameraUniforms.nearPlane * pow(cameraUniforms.farPlane / cameraUniforms.nearPlane, f32(clusterZ) / cameraUniforms.clusterSizeZ);
    let clusterDepthFar = cameraUniforms.nearPlane * pow(cameraUniforms.farPlane / cameraUniforms.nearPlane, f32(clusterZ + 1) / cameraUniforms.clusterSizeZ);
    
    let lightRadius = ${lightRadius};
    
    return true; 
}

@compute @workgroup_size(${clusteringWorkgroupSize})
fn main(@builtin(global_invocation_id) globalId: vec3u) {
    let clusterIndex = globalId.x;
    
    if (clusterIndex >= u32(cameraUniforms.clusterSizeX) * u32(cameraUniforms.clusterSizeY) * u32(cameraUniforms.clusterSizeZ)) {
        return;
    }
    
    let clusterZ = clusterIndex / (u32(cameraUniforms.clusterSizeX) * u32(cameraUniforms.clusterSizeY));
    let clusterY = (clusterIndex % (u32(cameraUniforms.clusterSizeX) * u32(cameraUniforms.clusterSizeY))) / u32(cameraUniforms.clusterSizeX);
    let clusterX = clusterIndex % u32(cameraUniforms.clusterSizeX);
    
    var lightCount: u32 = 0;
    var lightOffset: u32 = clusterIndex * ${maxLightsPerCluster};
    
    for (var lightIdx: u32 = 0; lightIdx < lightSet.numLights; lightIdx++) {
        if (lightCount >= ${maxLightsPerCluster}) {
            break;
        }
        
        let light = lightSet.lights[lightIdx];
        
        if (lightIntersectsCluster(light, clusterX, clusterY, clusterZ)) {
            clusterLightIndices.lightIndices[lightOffset + lightCount] = lightIdx;
            lightCount++;
        }
    }
    
    clusterSet.clusterLightInfos[clusterIndex] = ClusterLightInfo(
        lightCount,
        lightOffset,
        0, 
        0  
    );
}
