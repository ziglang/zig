const std = @import("std.zig");

/// Will make `ptr` contain the location of the current invocation within the
/// global workgroup. Each component is equal to the index of the local workgroup
/// multiplied by the size of the local workgroup plus `localInvocationId`.
/// `ptr` must be a reference to variable or struct field.
pub fn globalInvocationId(comptime ptr: *addrspace(.input) @Vector(3, u32)) void {
    asm volatile (
        \\OpDecorate %ptr BuiltIn GlobalInvocationId
        :
        : [ptr] "" (ptr),
    );
}

/// Will make that variable contain the location of the current cluster
/// culling, task, mesh, or compute shader invocation within the local
/// workgroup. Each component ranges from zero through to the size of the
/// workgroup in that dimension minus one.
/// `ptr` must be a reference to variable or struct field.
pub fn localInvocationId(comptime ptr: *addrspace(.input) @Vector(3, u32)) void {
    asm volatile (
        \\OpDecorate %ptr BuiltIn LocalInvocationId
        :
        : [ptr] "" (ptr),
    );
}

/// Output vertex position from a `Vertex` entrypoint
/// `ptr` must be a reference to variable or struct field.
pub fn position(comptime ptr: *addrspace(.output) @Vector(4, f32)) void {
    asm volatile (
        \\OpDecorate %ptr BuiltIn Position
        :
        : [ptr] "" (ptr),
    );
}

/// Will make `ptr` contain the index of the vertex that is
/// being processed by the current vertex shader invocation.
/// `ptr` must be a reference to variable or struct field.
pub fn vertexIndex(comptime ptr: *addrspace(.input) u32) void {
    asm volatile (
        \\OpDecorate %ptr BuiltIn VertexIndex
        :
        : [ptr] "" (ptr),
    );
}

/// Will make `ptr` contain the index of the instance that is
/// being processed by the current vertex shader invocation.
/// `ptr` must be a reference to variable or struct field.
pub fn instanceIndex(comptime ptr: *addrspace(.input) u32) void {
    asm volatile (
        \\OpDecorate %ptr BuiltIn InstanceIndex
        :
        : [ptr] "" (ptr),
    );
}

/// Output fragment depth from a `Fragment` entrypoint
/// `ptr` must be a reference to variable or struct field.
pub fn fragmentCoord(comptime ptr: *addrspace(.input) @Vector(4, f32)) void {
    asm volatile (
        \\OpDecorate %ptr BuiltIn FragCoord
        :
        : [ptr] "" (ptr),
    );
}

/// Output fragment depth from a `Fragment` entrypoint
/// `ptr` must be a reference to variable or struct field.
pub fn fragmentDepth(comptime ptr: *addrspace(.output) f32) void {
    asm volatile (
        \\OpDecorate %ptr BuiltIn FragDepth
        :
        : [ptr] "" (ptr),
    );
}

/// Forms the main linkage for `input` and `output` address spaces.
/// `ptr` must be a reference to variable or struct field.
pub fn location(comptime ptr: anytype, comptime loc: u32) void {
    asm volatile ("OpDecorate %ptr Location $loc"
        :
        : [ptr] "" (ptr),
          [loc] "c" (loc),
    );
}

/// Forms the main linkage for `input` and `output` address spaces.
/// `ptr` must be a reference to variable or struct field.
pub fn binding(comptime ptr: anytype, comptime set: u32, comptime bind: u32) void {
    asm volatile (
        \\OpDecorate %ptr DescriptorSet $set
        \\OpDecorate %ptr Binding $bind
        :
        : [ptr] "" (ptr),
          [set] "c" (set),
          [bind] "c" (bind),
    );
}

pub const Origin = enum(u32) {
    /// Increase toward the right and downward
    upper_left = 7,
    /// Increase toward the right and upward
    lower_left = 8,
};

/// The coordinates appear to originate in the specified `origin`.
/// Only valid with the `Fragment` calling convention.
pub fn fragmentOrigin(comptime entry_point: anytype, comptime origin: Origin) void {
    asm volatile ("OpExecutionMode %entry_point $origin"
        :
        : [entry_point] "" (entry_point),
          [origin] "c" (@intFromEnum(origin)),
    );
}

pub const DepthMode = enum(u32) {
    /// Declares that this entry point dynamically writes the
    /// `fragmentDepth` built in-decorated variable.
    replacing = 12,
    /// Indicates that per-fragment tests may assume that
    /// any `fragmentDepth` built in-decorated value written by the shader is
    /// greater-than-or-equal to the fragment’s interpolated depth value
    greater = 14,
    /// Indicates that per-fragment tests may assume that
    /// any `fragmentDepth` built in-decorated value written by the shader is
    /// less-than-or-equal to the fragment’s interpolated depth value
    less = 15,
    /// Indicates that per-fragment tests may assume that
    /// any `fragmentDepth` built in-decorated value written by the shader is
    /// the same as the fragment’s interpolated depth value
    unchanged = 16,
};

/// Only valid with the `Fragment` calling convention.
pub fn depthMode(comptime entry_point: anytype, comptime mode: DepthMode) void {
    asm volatile ("OpExecutionMode %entry_point $mode"
        :
        : [entry_point] "" (entry_point),
          [mode] "c" (mode),
    );
}

/// Indicates the workgroup size in the `x`, `y`, and `z` dimensions.
/// Only valid with the `GLCompute` or `Kernel` calling conventions.
pub fn workgroupSize(comptime entry_point: anytype, comptime size: @Vector(3, u32)) void {
    asm volatile ("OpExecutionMode %entry_point LocalSize %x %y %z"
        :
        : [entry_point] "" (entry_point),
          [x] "c" (size[0]),
          [y] "c" (size[1]),
          [z] "c" (size[2]),
    );
}

/// A hint to the client, which indicates the workgroup size in the `x`, `y`, and `z` dimensions.
/// Only valid with the `GLCompute` or `Kernel` calling conventions.
pub fn workgroupSizeHint(comptime entry_point: anytype, comptime size: @Vector(3, u32)) void {
    asm volatile ("OpExecutionMode %entry_point LocalSizeHint %x %y %z"
        :
        : [entry_point] "" (entry_point),
          [x] "c" (size[0]),
          [y] "c" (size[1]),
          [z] "c" (size[2]),
    );
}
