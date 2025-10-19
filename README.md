WebGL Forward+ and Clustered Deferred Shading
======================

**University of Pennsylvania, CIS 565: GPU Programming and Architecture, Project 4**

* Harry Guan
* Tested on: **Google Chrome 141.07** on
  Macbook Air M2 2022

## Description

This project implements Forward+ and Clustered Deferred shading techniques using WebGPU. It features three different rendering approaches: naive forward rendering, Forward+, and clustered deferred rendering using the Sponza Demo Scene. This was a great opportunity to learn a lot about WebGPU, which is the new trend replacing WebGL. 

### Live Demo

[Live Demo link!!](https://hazingoo.github.io/Project4-WebGPU-Forward-Plus-and-Clustered-Deferred/)

### Demo Video/GIF

[![](img/video.gif)]

### Project Structure

```
Project4-WebGPU-Forward-Plus-and-Clustered-Deferred/
├── src/
│   ├── shaders/          # WGSL shader files for different rendering techniques
│   ├── renderers/        # Implementation files for naive, forward+, and deferred renderers
│   └── stage/           # Scene management, camera, and lighting components
├── scenes/sponza/       # Sponza scene assets and textures
├── package.json         # Project dependencies and scripts
└── vite.config.ts       # Build configuration
```

### How to run Code

1. **Install dependencies:**
   ```bash
   npm install
   ```

2. **Start the development server:**
   ```bash
   npm run dev
   ```

3. **Open your browser:**
   - Navigate to `http://localhost:5173/` (or the port shown in terminal)
   - Make sure you're using a WebGPU-compatible browser like Chrome 

4. **Controls:**
   - Use mouse to look around the scene
   - Use WASD keys to move around
   - Toggle between different rendering techniques using the GUI controls

## Feature Overview

This project uses the famous Sponza scene, a classic test environment in computer graphics that features a complex architectural model with detailed geometry, textures, and lighting conditions. The Sponza scene provides an excellent benchmark for testing different rendering techniques due to its intricate geometry, varied materials, and realistic lighting scenarios. It allows for comprehensive evaluation of rendering performance across different algorithms.


### Naive

The naive forward rendering approach serves as our baseline implementation, where every light in the scene is evaluated for every pixel during the fragment shader stage. This method is straightforward but computationally expensive, especially as the number of lights increases. While this approach provides the foundation for understanding basic lighting calculations, we will explore optimization efforts later on to improve performance and scalability.

### Forward+ 

### Clustered Deferred 

### Performance Analysis

### Credits

- [Vite](https://vitejs.dev/)
- [loaders.gl](https://loaders.gl/)
- [dat.GUI](https://github.com/dataarts/dat.gui)
- [stats.js](https://github.com/mrdoob/stats.js)
- [wgpu-matrix](https://github.com/greggman/wgpu-matrix)
