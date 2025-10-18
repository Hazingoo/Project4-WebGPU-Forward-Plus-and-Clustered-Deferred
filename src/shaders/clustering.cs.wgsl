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
    let clusterX = u32(clamp(screenX * cameraUniforms.clusterSizeX, 0.0, cameraUniforms.clusterSizeX - 1.0));
    let clusterY = u32(clamp(screenY * cameraUniforms.clusterSizeY, 0.0, cameraUniforms.clusterSizeY - 1.0));
    
    let clampedDepth = clamp(depth, cameraUniforms.nearPlane, cameraUniforms.farPlane);
    let logDepth = log(clampedDepth / cameraUniforms.nearPlane) / log(cameraUniforms.farPlane / cameraUniforms.nearPlane);
    let clusterZ = u32(clamp(logDepth * cameraUniforms.clusterSizeZ, 0.0, cameraUniforms.clusterSizeZ - 1.0));
    
    return vec3u(clusterX, clusterY, clusterZ);
}


fn screenToView(screenCoord: vec2f, depth: f32) -> vec3f {
    let ndc = vec2f(
        screenCoord.x * 2.0 - 1.0,
        (1.0 - screenCoord.y) * 2.0 - 1.0  
    );
    
    let aspectRatio = cameraUniforms.screenWidth / cameraUniforms.screenHeight;
    let tanHalfFovY = 0.4142135623730951; 
    let tanHalfFovX = tanHalfFovY * aspectRatio;
    
    return vec3f(
        ndc.x * tanHalfFovX * depth,
        ndc.y * tanHalfFovY * depth,
        -depth
    );
}

fn lightIntersectsCluster(light: Light, clusterX: u32, clusterY: u32, clusterZ: u32) -> bool {
    let lightRadius = f32(${lightRadius});
    
    let lightPosView = (cameraUniforms.viewMat * vec4f(light.pos, 1.0)).xyz;
    
    let clusterDepthNear = cameraUniforms.nearPlane * pow(cameraUniforms.farPlane / cameraUniforms.nearPlane, f32(clusterZ) / cameraUniforms.clusterSizeZ);
    let clusterDepthFar = cameraUniforms.nearPlane * pow(cameraUniforms.farPlane / cameraUniforms.nearPlane, f32(clusterZ + 1) / cameraUniforms.clusterSizeZ);
    
    let clusterMinScreen = vec2f(f32(clusterX) / cameraUniforms.clusterSizeX, 
                                   f32(clusterY) / cameraUniforms.clusterSizeY);
    let clusterMaxScreen = vec2f(f32(clusterX + 1) / cameraUniforms.clusterSizeX, 
                                   f32(clusterY + 1) / cameraUniforms.clusterSizeY);
    
    let v1 = screenToView(clusterMinScreen, clusterDepthNear);
    let v2 = screenToView(vec2f(clusterMaxScreen.x, clusterMinScreen.y), clusterDepthNear);
    let v3 = screenToView(vec2f(clusterMinScreen.x, clusterMaxScreen.y), clusterDepthNear);
    let v4 = screenToView(clusterMaxScreen, clusterDepthNear);
    let v5 = screenToView(clusterMinScreen, clusterDepthFar);
    let v6 = screenToView(vec2f(clusterMaxScreen.x, clusterMinScreen.y), clusterDepthFar);
    let v7 = screenToView(vec2f(clusterMinScreen.x, clusterMaxScreen.y), clusterDepthFar);
    let v8 = screenToView(clusterMaxScreen, clusterDepthFar);
    
    var minBounds = min(min(min(v1, v2), min(v3, v4)), min(min(v5, v6), min(v7, v8)));
    var maxBounds = max(max(max(v1, v2), max(v3, v4)), max(max(v5, v6), max(v7, v8)));
    
    let closestPoint = clamp(lightPosView, minBounds, maxBounds);
    let distanceSquared = dot(lightPosView - closestPoint, lightPosView - closestPoint);
    
    return distanceSquared <= (lightRadius * lightRadius);
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
