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
    gBufferPosition!: GPUTexture;
    gBufferPositionView!: GPUTextureView;
    gBufferDepth!: GPUTexture;
    gBufferDepthView!: GPUTextureView;

    gBufferBindGroupLayout!: GPUBindGroupLayout;
    gBufferBindGroup!: GPUBindGroup;
    gBufferSampler!: GPUSampler;

    depthTexture!: GPUTexture;
    depthTextureView!: GPUTextureView;

    geometryPassPipeline!: GPURenderPipeline;
    cameraBindGroupLayout!: GPUBindGroupLayout;
    cameraBindGroup!: GPUBindGroup;

    fullscreenPassPipeline!: GPURenderPipeline;
    sceneBindGroupLayout!: GPUBindGroupLayout;
    sceneBindGroup!: GPUBindGroup;

    constructor(stage: Stage) {
        super(stage);

        this.setupGBuffer();

        this.setupClusteringInfrastructure();

        this.setupGeometryPass();

        this.setupFullscreenPass();
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

        this.gBufferPosition = renderer.device.createTexture({
            label: "G-Buffer Position",
            size: [width, height],
            format: "rgba16float",
            usage: GPUTextureUsage.RENDER_ATTACHMENT | GPUTextureUsage.TEXTURE_BINDING
        });
        this.gBufferPositionView = this.gBufferPosition.createView();

        this.gBufferDepth = renderer.device.createTexture({
            label: "G-Buffer Depth",
            size: [width, height],
            format: "r32float",
            usage: GPUTextureUsage.RENDER_ATTACHMENT | GPUTextureUsage.TEXTURE_BINDING
        });
        this.gBufferDepthView = this.gBufferDepth.createView();

        this.depthTexture = renderer.device.createTexture({
            label: "Depth Texture",
            size: [width, height],
            format: "depth24plus",
            usage: GPUTextureUsage.RENDER_ATTACHMENT
        });
        this.depthTextureView = this.depthTexture.createView();

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
                    texture: { sampleType: "float" }
                },
                {
                    binding: 3,
                    visibility: GPUShaderStage.FRAGMENT,
                    texture: { sampleType: "unfilterable-float" }
                },
                {
                    binding: 4,
                    visibility: GPUShaderStage.FRAGMENT,
                    sampler: { type: "non-filtering" }
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
                    resource: this.gBufferPositionView
                },
                {
                    binding: 3,
                    resource: this.gBufferDepthView
                },
                {
                    binding: 4,
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
                    visibility: GPUShaderStage.VERTEX | GPUShaderStage.FRAGMENT,
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
                        // Albedo
                        format: "rgba8unorm"
                    },
                    {
                        // Normal
                        format: "rgba16float"
                    },
                    {
                        // Position
                        format: "rgba16float"
                    },
                    {
                        // Depth
                        format: "r32float"
                    }
                ]
            },
            depthStencil: {
                format: "depth24plus",
                depthWriteEnabled: true,
                depthCompare: "less"
            }
        });
    }

    private setupFullscreenPass() {
        this.sceneBindGroupLayout = renderer.device.createBindGroupLayout({
            label: "fullscreen scene bind group layout",
            entries: [
                {
                    binding: 0,
                    visibility: GPUShaderStage.FRAGMENT,
                    buffer: { type: "uniform" }
                },
                {
                    binding: 1,
                    visibility: GPUShaderStage.FRAGMENT,
                    buffer: { type: "read-only-storage" }
                },
                {
                    binding: 2,
                    visibility: GPUShaderStage.FRAGMENT,
                    buffer: { type: "read-only-storage" }
                },
                {
                    binding: 3,
                    visibility: GPUShaderStage.FRAGMENT,
                    buffer: { type: "read-only-storage" }
                }
            ]
        });

        this.sceneBindGroup = renderer.device.createBindGroup({
            label: "fullscreen scene bind group",
            layout: this.sceneBindGroupLayout,
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

        this.fullscreenPassPipeline = renderer.device.createRenderPipeline({
            label: "clustered deferred fullscreen pass pipeline",
            layout: renderer.device.createPipelineLayout({
                label: "clustered deferred fullscreen pass pipeline layout",
                bindGroupLayouts: [
                    this.sceneBindGroupLayout,
                    this.gBufferBindGroupLayout
                ]
            }),
            vertex: {
                module: renderer.device.createShaderModule({
                    label: "clustered deferred fullscreen vert shader",
                    code: shaders.clusteredDeferredFullscreenVertSrc
                }),
                entryPoint: "main"
            },
            fragment: {
                module: renderer.device.createShaderModule({
                    label: "clustered deferred fullscreen frag shader",
                    code: shaders.clusteredDeferredFullscreenFragSrc
                }),
                targets: [
                    {
                        format: renderer.canvasFormat
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
        const encoder = renderer.device.createCommandEncoder();

        const computePass = encoder.beginComputePass();
        computePass.setPipeline(this.clusteringComputePipeline);
        computePass.setBindGroup(0, this.clusteringBindGroup);

        const numClusters = shaders.constants.clusterSizeX * shaders.constants.clusterSizeY * shaders.constants.clusterSizeZ;
        const workgroupCount = Math.ceil(numClusters / shaders.constants.clusteringWorkgroupSize);
        computePass.dispatchWorkgroups(workgroupCount);
        computePass.end();

        const geometryPass = encoder.beginRenderPass({
            label: "clustered deferred geometry pass",
            colorAttachments: [
                {
                    view: this.gBufferAlbedoView,
                    clearValue: [0, 0, 0, 0],
                    loadOp: "clear",
                    storeOp: "store"
                },
                {
                    view: this.gBufferNormalView,
                    clearValue: [0, 0, 0, 0],
                    loadOp: "clear",
                    storeOp: "store"
                },
                {
                    view: this.gBufferPositionView,
                    clearValue: [0, 0, 0, 0],
                    loadOp: "clear",
                    storeOp: "store"
                },
                {
                    view: this.gBufferDepthView,
                    clearValue: [1000, 0, 0, 0],
                    loadOp: "clear",
                    storeOp: "store"
                }
            ],
            depthStencilAttachment: {
                view: this.depthTextureView,
                depthClearValue: 1.0,
                depthLoadOp: "clear",
                depthStoreOp: "store"
            }
        });

        geometryPass.setPipeline(this.geometryPassPipeline);
        geometryPass.setBindGroup(shaders.constants.bindGroup_scene, this.cameraBindGroup);

        this.scene.iterate(node => {
            geometryPass.setBindGroup(shaders.constants.bindGroup_model, node.modelBindGroup);
        }, material => {
            geometryPass.setBindGroup(shaders.constants.bindGroup_material, material.materialBindGroup);
        }, primitive => {
            geometryPass.setVertexBuffer(0, primitive.vertexBuffer);
            geometryPass.setIndexBuffer(primitive.indexBuffer, 'uint32');
            geometryPass.drawIndexed(primitive.numIndices);
        });

        geometryPass.end();

        const canvasTextureView = renderer.context.getCurrentTexture().createView();
        const fullscreenPass = encoder.beginRenderPass({
            label: "clustered deferred fullscreen pass",
            colorAttachments: [
                {
                    view: canvasTextureView,
                    clearValue: [0, 0, 0, 0],
                    loadOp: "clear",
                    storeOp: "store"
                }
            ]
        });

        fullscreenPass.setPipeline(this.fullscreenPassPipeline);
        fullscreenPass.setBindGroup(0, this.sceneBindGroup);
        fullscreenPass.setBindGroup(1, this.gBufferBindGroup);

        fullscreenPass.draw(3, 1, 0, 0);

        fullscreenPass.end();

        renderer.device.queue.submit([encoder.finish()]);
    }
}
