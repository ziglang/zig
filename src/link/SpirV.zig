const SpirV = @This();

const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

const Module = @import("../Module.zig");
const Compilation = @import("../Compilation.zig");
const link = @import("../link.zig");
const codegen = @import("../codegen/spirv.zig");
const trace = @import("../tracy.zig").trace;
const build_options = @import("build_options");
const spec = @import("../codegen/spirv/spec.zig");

//! SPIR-V Spec documentation: https://www.khronos.org/registry/spir-v/specs/unified1/SPIRV.html
//! According to above documentation, a SPIR-V module has the following logical layout:
//! Header.
//! OpCapability instructions.
//! OpExtension instructions.
//! OpExtInstImport instructions.
//! A single OpMemoryModel instruction.
//! All entry points, declared with OpEntryPoint instructions.
//! All execution-mode declarators; OpExecutionMode and OpExecutionModeId instructions.
//! Debug instructions:
//! - First, OpString, OpSourceExtension, OpSource, OpSourceContinued (no forward references).
//! - OpName and OpMemberName instructions.
//! - OpModuleProcessed instructions.
//! All annotation (decoration) instructions.
//! All type declaration instructions, constant instructions, global variable declarations, (preferrably) OpUndef instructions.
//! All function declarations without a body (extern functions presumably).
//! All regular functions.

pub const FnData = struct {
    id: ?u32 = null,
    code: std.ArrayListUnmanaged(u32) = .{},
};

base: link.File,

// TODO: Does this file need to support multiple independent modules?
spirv_module: codegen.SPIRVModule,

pub fn createEmpty(gpa: *Allocator, options: link.Options) !*SpirV {
    const spirv = try gpa.create(SpirV);
    spirv.* = .{
        .base = .{
            .tag = .spirv,
            .options = options,
            .file = null,
            .allocator = gpa,
        },
        .spirv_module = codegen.SPIRVModule.init(gpa),
    };

    // TODO: Figure out where to put all of these
    switch (options.target.cpu.arch) {
        .spirv32, .spirv64 => {},
        else => return error.TODOArchNotSupported,
    }

    switch (options.target.os.tag) {
        .opencl, .glsl450, .vulkan => {},
        else => return error.TODOOsNotSupported,
    }

    if (options.target.abi != .none) {
        return error.TODOAbiNotSupported;
    }

    return spirv;
}

pub fn openPath(allocator: *Allocator, sub_path: []const u8, options: link.Options) !*SpirV {
    assert(options.object_format == .spirv);

    if (options.use_llvm) return error.LLVM_BackendIsTODO_ForSpirV; // TODO: LLVM Doesn't support SpirV at all.
    if (options.use_lld) return error.LLD_LinkingIsTODO_ForSpirV; // TODO: LLD Doesn't support SpirV at all.

    // TODO: read the file and keep vaild parts instead of truncating
    const file = try options.emit.?.directory.handle.createFile(sub_path, .{ .truncate = true, .read = true });
    errdefer file.close();

    const spirv = try createEmpty(allocator, options);
    errdefer spirv.base.destroy();

    spirv.base.file = file;
    return spirv;
}

pub fn deinit(self: *SpirV) void {
    self.spirv_module.deinit();
}

pub fn updateDecl(self: *SpirV, module: *Module, decl: *Module.Decl) !void {
    const tracy = trace(@src());
    defer tracy.end();

    const fn_data = &decl.fn_link.spirv;
    if (fn_data.id == null) {
        fn_data.id = self.spirv_module.allocId();
    }

    var managed_code = fn_data.code.toManaged(self.base.allocator);
    managed_code.items.len = 0;

    try self.spirv_module.genDecl(fn_data.id.?, &managed_code, decl);
    fn_data.code = managed_code.toUnmanaged();

    // Free excess allocated memory for this Decl.
    fn_data.code.shrinkAndFree(self.base.allocator, fn_data.code.items.len);
}

pub fn updateDeclExports(
    self: *SpirV,
    module: *Module,
    decl: *const Module.Decl,
    exports: []const *Module.Export,
) !void {}

pub fn freeDecl(self: *SpirV, decl: *Module.Decl) void {
    var fn_data = decl.fn_link.spirv;
    fn_data.code.deinit(self.base.allocator);
    if (fn_data.id) |id| self.spirv_module.freeId(id);
    decl.fn_link.spirv = undefined;
}

pub fn flush(self: *SpirV, comp: *Compilation) !void {
    if (build_options.have_llvm and self.base.options.use_lld) {
        return error.LLD_LinkingIsTODO_ForSpirV; // TODO: LLD Doesn't support SpirV at all.
    } else {
        return self.flushModule(comp);
    }
}

pub fn flushModule(self: *SpirV, comp: *Compilation) !void {
    const tracy = trace(@src());
    defer tracy.end();

    const module = self.base.options.module.?;
    const target = comp.getTarget();

    var binary = std.ArrayList(u32).init(self.base.allocator);
    defer binary.deinit();

    // Note: The order of adding sections to the final binary
    // follows the SPIR-V logical module format!

    try binary.appendSlice(&[_]u32{
        spec.magic_number,
        (spec.version.major << 16) | (spec.version.minor << 8),
        0, // TODO: Register Zig compiler magic number.
        self.spirv_module.idBound(),
        0, // Schema (currently reserved for future use in the SPIR-V spec).
    });

    try writeCapabilities(&binary, target);
    try writeMemoryModel(&binary, target);

    // Collect list of buffers to write.
    // SPIR-V files support both little and big endian words. The actual format is
    // disambiguated by the magic number, and so theoretically we don't need to worry
    // about endian-ness when writing the final binary.
    var all_buffers = std.ArrayList(std.os.iovec_const).init(self.base.allocator);
    defer all_buffers.deinit();

    // Pre-allocate enough for the binary info + all functions
    try all_buffers.ensureCapacity(module.decl_table.count() + 1);

    all_buffers.appendAssumeCapacity(wordsToIovConst(binary.items));

    for (module.decl_table.items()) |entry| {
        const decl = entry.value;
        switch (decl.typed_value) {
            .most_recent => |tvm| {
                const fn_data = &decl.fn_link.spirv;
                all_buffers.appendAssumeCapacity(wordsToIovConst(fn_data.code.items));
            },
            .never_succeeded => continue,
        }
    }

    var file_size: u64 = 0;
    for (all_buffers.items) |iov| {
        file_size += iov.iov_len;
    }

    const file = self.base.file.?;
    try file.seekTo(0);
    try file.setEndPos(file_size);
    try file.pwritevAll(all_buffers.items, 0);
}

fn writeCapabilities(binary: *std.ArrayList(u32), target: std.Target) !void {
    // TODO: Integrate with a hypothetical feature system
    const cap: spec.Capability = switch (target.os.tag) {
        .opencl => .Kernel,
        .glsl450 => .Shader,
        .vulkan => .VulkanMemoryModel,
        else => unreachable, // TODO
    };

    try codegen.writeInstruction(binary, .OpCapability, &[_]u32{ @enumToInt(cap) });
}

fn writeMemoryModel(binary: *std.ArrayList(u32), target: std.Target) !void {
    const addressing_model = switch (target.os.tag) {
        .opencl => switch (target.cpu.arch) {
            .spirv32 => spec.AddressingModel.Physical32,
            .spirv64 => spec.AddressingModel.Physical64,
            else => unreachable, // TODO
        },
        .glsl450, .vulkan => spec.AddressingModel.Logical,
        else => unreachable, // TODO
    };

    const memory_model: spec.MemoryModel = switch (target.os.tag) {
        .opencl => .OpenCL,
        .glsl450 => .GLSL450,
        .vulkan => .Vulkan,
        else => unreachable,
    };

    try codegen.writeInstruction(binary, .OpMemoryModel, &[_]u32{
        @enumToInt(addressing_model), @enumToInt(memory_model)
    });
}

fn wordsToIovConst(words: []const u32) std.os.iovec_const {
    const bytes = std.mem.sliceAsBytes(words);
    return .{
        .iov_base = bytes.ptr,
        .iov_len = bytes.len,
    };
}
