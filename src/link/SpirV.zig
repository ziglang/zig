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

pub const FnData = struct {
    id: ?u32 = null,
    code: std.ArrayListUnmanaged(u32) = .{},
};

base: link.File,

// TODO: Does this file need to support multiple independent modules?
spirv_module: codegen.SPIRVModule = .{},

pub fn createEmpty(gpa: *Allocator, options: link.Options) !*SpirV {
    const spirv = try gpa.create(SpirV);
    spirv.* = .{
        .base = .{
            .tag = .spirv,
            .options = options,
            .file = null,
            .allocator = gpa,
        },
    };
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
    decl.fn_link.spirv.code.deinit(self.base.allocator);
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

    const file = self.base.file.?;
    var bw = std.io.bufferedWriter(file.writer());
    const writer = bw.writer();

    // Header
    // SPIR-V files support both little and big endian words. The actual format is disambiguated by
    // the magic number. This backend uses little endian.
    try writer.writeIntLittle(u32, spec.magic_number);
    try writer.writeIntLittle(u32, (spec.version.major << 16) | (spec.version.minor) << 8);
    try writer.writeIntLittle(u32, 0); // TODO: Register Zig compiler magic number.
    try writer.writeIntLittle(u32, self.spirv_module.idBound());
    try writer.writeIntLittle(u32, 0); // Schema.

    // Declarations
    for (module.decl_table.items()) |entry| {
        const decl = entry.value;
        switch (decl.typed_value) {
            .most_recent => |tvm| {
                const fn_data = &decl.fn_link.spirv;
                for (fn_data.code.items) |word| {
                    try writer.writeIntLittle(u32, word);
                }
            },
            .never_succeeded => continue,
        }
    }

    try bw.flush();
}
