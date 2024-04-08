const std = @import("std.zig");
const builtin = @import("builtin");
const comptimePrint = std.fmt.comptimePrint;

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

/// Establish an struct type as a memory interface block.
pub fn block(comptime T: type) void {
    asm volatile (
        \\OpDecorate %T Block
        :
        : [T] "" (T),
    );
}

/// Apply to an array type to specify the stride.
pub fn arrayStride(comptime T: type, comptime stride: u32) void {
    const code = comptimePrint("OpDecorate %T ArrayStride {}", .{stride});
    asm volatile (code
        :
        : [T] "" (T),
    );
}

/// Dictates the byte offset of an struct field.
pub fn fieldOffset(comptime T: type, comptime field_index: u32, comptime offset: u32) void {
    const code = comptimePrint("OpMemberDecorate %T {} Offset {}", .{ field_index, offset });
    asm volatile (code
        :
        : [T] "" (T),
    );
}

pub fn fieldColumnMajor(comptime T: type, comptime field_index: u32) void {
    const code = comptimePrint("OpMemberDecorate %T {} ColMajor", .{field_index});
    asm volatile (code
        :
        : [T] "" (T),
    );
}

pub fn fieldRowMajor(comptime T: type, comptime field_index: u32) void {
    const code = comptimePrint("OpMemberDecorate %T {} RowMajor", .{field_index});
    asm volatile (code
        :
        : [T] "" (T),
    );
}

/// Apply to a matrix or array type to specify the stride.
pub fn fieldMatrixStride(comptime T: type, comptime field_index: u32, comptime stride: u32) void {
    const code = comptimePrint("OpMemberDecorate %T {} MatrixStride {}", .{ field_index, stride });
    asm volatile (code
        :
        : [T] "" (T),
    );
}

/// Forms the main linkage for `input` and `output` address spaces.
/// `ptr` must be a reference to variable or struct field.
pub fn location(comptime ptr: anytype, comptime loc: u32) void {
    const code = comptimePrint("OpDecorate %ptr Location {}", .{loc});
    asm volatile (code
        :
        : [ptr] "" (ptr),
    );
}

/// Forms the main linkage for `input` and `output` address spaces.
/// `ptr` must be a reference to variable or struct field.
pub fn binding(comptime ptr: anytype, comptime group: u32, comptime bind: u32) void {
    const code = comptimePrint(
        \\OpDecorate %ptr DescriptorSet {}
        \\OpDecorate %ptr Binding {}
    , .{ group, bind });
    asm volatile (code
        :
        : [ptr] "" (ptr),
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
    const origin_enum = switch (origin) {
        .upper_left => .OriginUpperLeft,
        .lower_left => .OriginLowerLeft,
    };
    asm volatile ("OpExecutionMode %entry_point " ++ @tagName(origin_enum)
        :
        : [entry_point] "" (entry_point),
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
    const code = comptimePrint("OpExecutionMode %entry_point {}", .{@intFromEnum(mode)});
    asm volatile (code
        :
        : [entry_point] "" (entry_point),
    );
}

/// Indicates the workgroup size in the `x`, `y`, and `z` dimensions.
/// Only valid with the `GLCompute` or `Kernel` calling conventions.
pub fn workgroupSize(comptime entry_point: anytype, comptime size: @Vector(3, u32)) void {
    const code = comptimePrint("OpExecutionMode %entry_point LocalSize {} {} {}", .{
        size[0],
        size[1],
        size[2],
    });
    asm volatile (code
        :
        : [entry_point] "" (entry_point),
    );
}

/// A hint to the client, which indicates the workgroup size in the `x`, `y`, and `z` dimensions.
/// Only valid with the `GLCompute` or `Kernel` calling conventions.
pub fn workgroupSizeHint(comptime entry_point: anytype, comptime size: @Vector(3, u32)) void {
    const code = comptimePrint("OpExecutionMode %entry_point LocalSizeHint {} {} {}", .{
        size[0],
        size[1],
        size[2],
    });
    asm volatile (code
        :
        : [entry_point] "" (entry_point),
    );
}

pub fn normalize(comptime T: type, value: T) T {
    return switch (builtin.target.os.tag) {
        .vulkan => return asm volatile (
            \\%set = OpExtInstImport "GLSL.std.450"
            \\%id  = OpExtInst %T %set 69 %value
            : [id] "" (-> T),
            : [T] "" (T),
              [value] "" (value),
        ),
        .opencl => unreachable,
        else => unreachable,
    };
}

pub fn pow(comptime T: type, x: T, y: T) T {
    return switch (builtin.target.os.tag) {
        .vulkan => asm volatile (
            \\%set = OpExtInstImport "GLSL.std.450"
            \\%id  = OpExtInst %T %set 26 %x %y
            : [id] "" (-> T),
            : [T] "" (T),
              [x] "" (x),
              [y] "" (y),
        ),
        .opencl => asm volatile (
            \\%set = OpExtInstImport "OpenCL.std"
            \\%id  = OpExtInst %T %set 48 %x %y
            : [id] "" (-> T),
            : [T] "" (T),
              [x] "" (x),
              [y] "" (y),
        ),
        else => unreachable,
    };
}

pub fn mix(comptime T: type, x: T, y: T, z: T) T {
    return switch (builtin.target.os.tag) {
        .vulkan => asm volatile (
            \\%set = OpExtInstImport "GLSL.std.450"
            \\%id  = OpExtInst %T %set 46 %x %y %z
            : [id] "" (-> T),
            : [T] "" (T),
              [x] "" (x),
              [y] "" (y),
              [z] "" (z),
        ),
        .opencl => asm volatile (
            \\%set = OpExtInstImport "OpenCL.std"
            \\%id  = OpExtInst %T %set 99 %x %y %z
            : [id] "" (-> T),
            : [T] "" (T),
              [x] "" (x),
              [y] "" (y),
              [z] "" (z),
        ),
        else => unreachable,
    };
}

pub fn dot(comptime T: type, x: T, y: T) std.meta.Child(T) {
    return asm volatile (
        \\%id = OpDot %T %x %y
        : [id] "" (-> std.meta.Child(T)),
        : [T] "" (std.meta.Child(T)),
          [x] "" (x),
          [y] "" (y),
    );
}
