import * as renderer from '../renderer';
import * as shaders from '../shaders/shaders';
import { Stage } from '../stage/stage';

export class ClusteredDeferredRenderer extends renderer.Renderer {
    // TODO-3: add layouts, pipelines, textures, etc. needed for Forward+ here
    // you may need extra uniforms such as the camera view matrix and the canvas resolution
    clusterSetBuffer!: GPUBuffer;
    clusterLightIndicesBuffer!: GPUBuffer;
    clusteringBindGroupLayout!: GPUBindGroupLayout;
    clusteringBindGroup!: GPUBindGroup;
    clusteringComputePipeline!: GPUComputePipeline;

    gBufferAlbedo!: GPUTexture;
    gBufferAlbedoView!: GPUTextureView;
    gBufferNormal!: GPUTexture;
    gBufferNormalView!: GPUTextureView;
    gBufferDepth!: GPUTexture;
    gBufferDepthView!: GPUTextureView;

    gBufferBindGroupLayout!: GPUBindGroupLayout;
    gBufferBindGroup!: GPUBindGroup;
    gBufferSampler!: GPUSampler;

    geometryPassPipeline!: GPURenderPipeline;
    cameraBindGroupLayout!: GPUBindGroupLayout;
    cameraBindGroup!: GPUBindGroup;

    constructor(stage: Stage) {
        super(stage);

        this.setupGBuffer();

        this.setupClusteringInfrastructure();

        this.setupGeometryPass();

    }

    private setupGBuffer() {
        const width = renderer.canvas.width;
        const height = renderer.canvas.height;

        this.gBufferAlbedo = renderer.device.createTexture({
            label: "G-Buffer Albedo",
            size: [width, height],
            format: "rgba8unorm",
            usage: GPUTextureUsage.RENDER_ATTACHMENT | GPUTextureUsage.TEXTURE_BINDING
        });
        this.gBufferAlbedoView = this.gBufferAlbedo.createView();

        this.gBufferNormal = renderer.device.createTexture({
            label: "G-Buffer Normal",
            size: [width, height],
            format: "rgba16float",
            usage: GPUTextureUsage.RENDER_ATTACHMENT | GPUTextureUsage.TEXTURE_BINDING
        });
        this.gBufferNormalView = this.gBufferNormal.createView();

        this.gBufferDepth = renderer.device.createTexture({
            label: "G-Buffer Depth",
            size: [width, height],
            format: "depth24plus",
            usage: GPUTextureUsage.RENDER_ATTACHMENT | GPUTextureUsage.TEXTURE_BINDING
        });
        this.gBufferDepthView = this.gBufferDepth.createView();

        this.gBufferSampler = renderer.device.createSampler({
            label: "G-Buffer Sampler",
            magFilter: "nearest",
            minFilter: "nearest"
        });

        this.gBufferBindGroupLayout = renderer.device.createBindGroupLayout({
            label: "G-Buffer bind group layout",
            entries: [
                {
                    binding: 0,
                    visibility: GPUShaderStage.FRAGMENT,
                    texture: { sampleType: "float" }
                },
                {
                    binding: 1,
                    visibility: GPUShaderStage.FRAGMENT,
                    texture: { sampleType: "float" }
                },
                {
                    binding: 2,
                    visibility: GPUShaderStage.FRAGMENT,
                    texture: { sampleType: "depth" }
                },
                {
                    binding: 3,
                    visibility: GPUShaderStage.FRAGMENT,
                    sampler: {}
                }
            ]
        });

        this.gBufferBindGroup = renderer.device.createBindGroup({
            label: "G-Buffer bind group",
            layout: this.gBufferBindGroupLayout,
            entries: [
                {
                    binding: 0,
                    resource: this.gBufferAlbedoView
                },
                {
                    binding: 1,
                    resource: this.gBufferNormalView
                },
                {
                    binding: 2,
                    resource: this.gBufferDepthView
                },
                {
                    binding: 3,
                    resource: this.gBufferSampler
                }
            ]
        });
    }

    private setupClusteringInfrastructure() {
        const numClusters = shaders.constants.clusterSizeX * shaders.constants.clusterSizeY * shaders.constants.clusterSizeZ;
        const clusterLightInfoSize = 16;
        const maxLightIndices = numClusters * shaders.constants.maxLightsPerCluster;

        this.clusterSetBuffer = renderer.device.createBuffer({
            label: "cluster set buffer",
            size: 4 + (numClusters * clusterLightInfoSize),
            usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST
        });

        this.clusterLightIndicesBuffer = renderer.device.createBuffer({
            label: "cluster light indices buffer",
            size: maxLightIndices * 4,
            usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST
        });

        this.clusteringBindGroupLayout = renderer.device.createBindGroupLayout({
            label: "clustering bind group layout",
            entries: [
                {
                    binding: 0,
                    visibility: GPUShaderStage.COMPUTE,
                    buffer: { type: "uniform" }
                },
                {
                    binding: 1,
                    visibility: GPUShaderStage.COMPUTE,
                    buffer: { type: "read-only-storage" }
                },
                {
                    binding: 2,
                    visibility: GPUShaderStage.COMPUTE,
                    buffer: { type: "storage" }
                },
                {
                    binding: 3,
                    visibility: GPUShaderStage.COMPUTE,
                    buffer: { type: "storage" }
                }
            ]
        });

        this.clusteringBindGroup = renderer.device.createBindGroup({
            label: "clustering bind group",
            layout: this.clusteringBindGroupLayout,
            entries: [
                {
                    binding: 0,
                    resource: { buffer: this.camera.uniformsBuffer }
                },
                {
                    binding: 1,
                    resource: { buffer: this.lights.lightSetStorageBuffer }
                },
                {
                    binding: 2,
                    resource: { buffer: this.clusterSetBuffer }
                },
                {
                    binding: 3,
                    resource: { buffer: this.clusterLightIndicesBuffer }
                }
            ]
        });

        this.clusteringComputePipeline = renderer.device.createComputePipeline({
            label: "clustering compute pipeline",
            layout: renderer.device.createPipelineLayout({
                label: "clustering compute pipeline layout",
                bindGroupLayouts: [this.clusteringBindGroupLayout]
            }),
            compute: {
                module: renderer.device.createShaderModule({
                    label: "clustering compute shader",
                    code: shaders.clusteringComputeSrc
                }),
                entryPoint: "main"
            }
        });
    }

    private setupGeometryPass() {
        this.cameraBindGroupLayout = renderer.device.createBindGroupLayout({
            label: "camera bind group layout",
            entries: [
                {
                    binding: 0,
                    visibility: GPUShaderStage.VERTEX,
                    buffer: { type: "uniform" }
                }
            ]
        });

        this.cameraBindGroup = renderer.device.createBindGroup({
            label: "camera bind group",
            layout: this.cameraBindGroupLayout,
            entries: [
                {
                    binding: 0,
                    resource: { buffer: this.camera.uniformsBuffer }
                }
            ]
        });

        this.geometryPassPipeline = renderer.device.createRenderPipeline({
            label: "clustered deferred geometry pass pipeline",
            layout: renderer.device.createPipelineLayout({
                label: "clustered deferred geometry pass pipeline layout",
                bindGroupLayouts: [
                    this.cameraBindGroupLayout,
                    renderer.modelBindGroupLayout,
                    renderer.materialBindGroupLayout
                ]
            }),
            depthStencil: {
                depthWriteEnabled: true,
                depthCompare: "less",
                format: "depth24plus"
            },
            vertex: {
                module: renderer.device.createShaderModule({
                    label: "clustered deferred vert shader",
                    code: shaders.naiveVertSrc
                }),
                buffers: [renderer.vertexBufferLayout]
            },
            fragment: {
                module: renderer.device.createShaderModule({
                    label: "clustered deferred frag shader",
                    code: shaders.clusteredDeferredFragSrc
                }),
                targets: [
                    {
                        format: "rgba8unorm"
                    },
                    {
                        format: "rgba16float"
                    }
                ]
            }
        });
    }

    override draw() {
        // TODO-3: run the Forward+ rendering pass:
        // - run the clustering compute shader
        // - run the G-buffer pass, outputting position, albedo, and normals
        // - run the fullscreen pass, which reads from the G-buffer and performs lighting calculations
    }
}
