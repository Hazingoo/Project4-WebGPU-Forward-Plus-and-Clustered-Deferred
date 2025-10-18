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

struct ClusterUniforms {
    screenWidth: u32,
    screenHeight: u32,
    clusterSizeX: u32,
    clusterSizeY: u32,
    clusterSizeZ: u32,
    nearPlane: f32,
    farPlane: f32,
    _padding: f32
}

@group(0) @binding(0) var<uniform> clusterUniforms: ClusterUniforms;
@group(0) @binding(1) var<storage, read> lightSet: LightSet;
@group(0) @binding(2) var<storage, read_write> clusterSet: ClusterSet;

fn getClusterIndex(clusterX: u32, clusterY: u32, clusterZ: u32) -> u32 {
    return clusterZ * clusterUniforms.clusterSizeX * clusterUniforms.clusterSizeY + 
           clusterY * clusterUniforms.clusterSizeX + clusterX;
}

fn screenToCluster(screenX: f32, screenY: f32, depth: f32) -> vec3u {
    let clusterX = u32(screenX * f32(clusterUniforms.clusterSizeX));
    let clusterY = u32(screenY * f32(clusterUniforms.clusterSizeY));
    
    let logDepth = log(depth / clusterUniforms.nearPlane) / log(clusterUniforms.farPlane / clusterUniforms.nearPlane);
    let clusterZ = u32(logDepth * f32(clusterUniforms.clusterSizeZ));
    
    return vec3u(clusterX, clusterY, clusterZ);
}

fn lightIntersectsCluster(light: Light, clusterX: u32, clusterY: u32, clusterZ: u32) -> bool {
    // Convert cluster coordinates to screen space
    let clusterScreenX = f32(clusterX) / f32(clusterUniforms.clusterSizeX);
    let clusterScreenY = f32(clusterY) / f32(clusterUniforms.clusterSizeY);
    
    let clusterDepthNear = clusterUniforms.nearPlane * pow(clusterUniforms.farPlane / clusterUniforms.nearPlane, f32(clusterZ) / f32(clusterUniforms.clusterSizeZ));
    let clusterDepthFar = clusterUniforms.nearPlane * pow(clusterUniforms.farPlane / clusterUniforms.nearPlane, f32(clusterZ + 1) / f32(clusterUniforms.clusterSizeZ));
    
    let lightRadius = ${lightRadius};
    
    return true; // For now, assume all lights affect all clusters (will be optimized later)
}

@compute @workgroup_size(${clusteringWorkgroupSize})
fn main(@builtin(global_invocation_id) globalId: vec3u) {
    let clusterIndex = globalId.x;
    
    if (clusterIndex >= clusterUniforms.clusterSizeX * clusterUniforms.clusterSizeY * clusterUniforms.clusterSizeZ) {
        return;
    }
    
    let clusterZ = clusterIndex / (clusterUniforms.clusterSizeX * clusterUniforms.clusterSizeY);
    let clusterY = (clusterIndex % (clusterUniforms.clusterSizeX * clusterUniforms.clusterSizeY)) / clusterUniforms.clusterSizeX;
    let clusterX = clusterIndex % clusterUniforms.clusterSizeX;
    
    var lightCount: u32 = 0;
    var lightOffset: u32 = clusterIndex * ${maxLightsPerCluster};
    
    for (var lightIdx: u32 = 0; lightIdx < lightSet.numLights; lightIdx++) {
        if (lightCount >= ${maxLightsPerCluster}) {
            break;
        }
        
        let light = lightSet.lights[lightIdx];
        
        if (lightIntersectsCluster(light, clusterX, clusterY, clusterZ)) {
            clusterSet.lightIndices[lightOffset + lightCount] = lightIdx;
            lightCount++;
        }
    }
    
    // Store cluster info
    clusterSet.clusterLightInfos[clusterIndex] = ClusterLightInfo(
        lightCount,
        lightOffset,
        0, 
        0  
    );
}
