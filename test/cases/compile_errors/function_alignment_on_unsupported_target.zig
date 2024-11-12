export fn entry() align(0) void {}

// error
// backend=stage2
// target=nvptx-cuda,nvptx64-cuda,spirv-vulkan,spirv32-opencl,spirv64-opencl,wasm32-freestanding,wasm64-freestanding
//
// :1:25: error: target does not support function alignment
