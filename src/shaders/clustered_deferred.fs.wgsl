// TODO-3: implement the Clustered Deferred G-buffer fragment shader

// This shader should only store G-buffer information and should not do any shading.
@group(${bindGroup_material}) @binding(0) var diffuseTex: texture_2d<f32>;
@group(${bindGroup_material}) @binding(1) var diffuseTexSampler: sampler;

struct FragmentInput
{
    @builtin(position) fragCoord: vec4f,
    @location(0) pos: vec3f,
    @location(1) nor: vec3f,
    @location(2) uv: vec2f
}

struct GBufferOutput
{
    @location(0) albedo: vec4f,
    @location(1) normal: vec4f,
    @location(2) position: vec4f,
    @location(3) depth: vec4f
}

@group(${bindGroup_scene}) @binding(0) var<uniform> cameraUniforms: CameraUniforms;

@fragment
fn main(in: FragmentInput) -> GBufferOutput
{
    let diffuseColor = textureSample(diffuseTex, diffuseTexSampler, in.uv);
    
    if (diffuseColor.a < 0.5f) {
        discard;
    }

    var output: GBufferOutput;
    
    output.albedo = vec4f(diffuseColor.rgb, 1.0);
    
    let normalNormalized = normalize(in.nor);
    output.normal = vec4f(normalNormalized * 0.5 + 0.5, 1.0);
    
    output.position = vec4f(in.pos, 1.0);
    
    let posView = (cameraUniforms.viewMat * vec4f(in.pos, 1.0)).xyz;
    let linearDepth = -posView.z;
    output.depth = vec4f(linearDepth, 0.0, 0.0, 1.0);
    
    return output;
}
