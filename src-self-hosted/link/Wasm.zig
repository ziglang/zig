const Wasm = @This();

const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const fs = std.fs;
const leb = std.debug.leb;

const Module = @import("../Module.zig");
const codegen = @import("../codegen/wasm.zig");
const link = @import("../link.zig");

/// Various magic numbers defined by the wasm spec
const spec = struct {
    const magic = [_]u8{ 0x00, 0x61, 0x73, 0x6D }; // \0asm
    const version = [_]u8{ 0x01, 0x00, 0x00, 0x00 }; // version 1

    const custom_id = 0;
    const types_id = 1;
    const imports_id = 2;
    const funcs_id = 3;
    const tables_id = 4;
    const memories_id = 5;
    const globals_id = 6;
    const exports_id = 7;
    const start_id = 8;
    const elements_id = 9;
    const code_id = 10;
    const data_id = 11;
};

pub const base_tag = link.File.Tag.wasm;

pub const FnData = struct {
    /// Generated code for the type of the function
    functype: std.ArrayListUnmanaged(u8) = .{},
    /// Generated code for the body of the function
    code: std.ArrayListUnmanaged(u8) = .{},
    /// Locations in the generated code where function indexes must be filled in.
    /// This must be kept ordered by offset.
    idx_refs: std.ArrayListUnmanaged(struct { offset: u32, decl: *Module.Decl }) = .{},
};

base: link.File,

/// List of all function Decls to be written to the output file. The index of
/// each Decl in this list at the time of writing the binary is used as the
/// function index.
/// TODO: can/should we access some data structure in Module directly?
funcs: std.ArrayListUnmanaged(*Module.Decl) = .{},

pub fn openPath(allocator: *Allocator, dir: fs.Dir, sub_path: []const u8, options: link.Options) !*link.File {
    assert(options.object_format == .wasm);

    // TODO: read the file and keep vaild parts instead of truncating
    const file = try dir.createFile(sub_path, .{ .truncate = true, .read = true });
    errdefer file.close();

    const wasm = try allocator.create(Wasm);
    errdefer allocator.destroy(wasm);

    try file.writeAll(&(spec.magic ++ spec.version));

    wasm.* = .{
        .base = .{
            .tag = .wasm,
            .options = options,
            .file = file,
            .allocator = allocator,
        },
    };

    return &wasm.base;
}

pub fn deinit(self: *Wasm) void {
    for (self.funcs.items) |decl| {
        decl.fn_link.wasm.?.functype.deinit(self.base.allocator);
        decl.fn_link.wasm.?.code.deinit(self.base.allocator);
        decl.fn_link.wasm.?.idx_refs.deinit(self.base.allocator);
    }
    self.funcs.deinit(self.base.allocator);
}

// Generate code for the Decl, storing it in memory to be later written to
// the file on flush().
pub fn updateDecl(self: *Wasm, module: *Module, decl: *Module.Decl) !void {
    if (decl.typed_value.most_recent.typed_value.ty.zigTypeTag() != .Fn)
        return error.TODOImplementNonFnDeclsForWasm;

    if (decl.fn_link.wasm) |*fn_data| {
        fn_data.functype.items.len = 0;
        fn_data.code.items.len = 0;
        fn_data.idx_refs.items.len = 0;
    } else {
        decl.fn_link.wasm = .{};
        try self.funcs.append(self.base.allocator, decl);
    }
    const fn_data = &decl.fn_link.wasm.?;

    var managed_functype = fn_data.functype.toManaged(self.base.allocator);
    var managed_code = fn_data.code.toManaged(self.base.allocator);
    try codegen.genFunctype(&managed_functype, decl);
    try codegen.genCode(&managed_code, decl);
    fn_data.functype = managed_functype.toUnmanaged();
    fn_data.code = managed_code.toUnmanaged();
}

pub fn updateDeclExports(
    self: *Wasm,
    module: *Module,
    decl: *const Module.Decl,
    exports: []const *Module.Export,
) !void {}

pub fn freeDecl(self: *Wasm, decl: *Module.Decl) void {
    // TODO: remove this assert when non-function Decls are implemented
    assert(decl.typed_value.most_recent.typed_value.ty.zigTypeTag() == .Fn);
    _ = self.funcs.swapRemove(self.getFuncidx(decl).?);
    decl.fn_link.wasm.?.functype.deinit(self.base.allocator);
    decl.fn_link.wasm.?.code.deinit(self.base.allocator);
    decl.fn_link.wasm.?.idx_refs.deinit(self.base.allocator);
    decl.fn_link.wasm = null;
}

pub fn flush(self: *Wasm, module: *Module) !void {
    const file = self.base.file.?;
    const header_size = 5 + 1;

    // No need to rewrite the magic/version header
    try file.setEndPos(@sizeOf(@TypeOf(spec.magic ++ spec.version)));
    try file.seekTo(@sizeOf(@TypeOf(spec.magic ++ spec.version)));

    // Type section
    {
        const header_offset = try reserveVecSectionHeader(file);
        for (self.funcs.items) |decl| {
            try file.writeAll(decl.fn_link.wasm.?.functype.items);
        }
        try writeVecSectionHeader(
            file,
            header_offset,
            spec.types_id,
            @intCast(u32, (try file.getPos()) - header_offset - header_size),
            @intCast(u32, self.funcs.items.len),
        );
    }

    // Function section
    {
        const header_offset = try reserveVecSectionHeader(file);
        const writer = file.writer();
        for (self.funcs.items) |_, typeidx| try leb.writeULEB128(writer, @intCast(u32, typeidx));
        try writeVecSectionHeader(
            file,
            header_offset,
            spec.funcs_id,
            @intCast(u32, (try file.getPos()) - header_offset - header_size),
            @intCast(u32, self.funcs.items.len),
        );
    }

    // Export section
    {
        const header_offset = try reserveVecSectionHeader(file);
        const writer = file.writer();
        var count: u32 = 0;
        for (module.decl_exports.entries.items) |entry| {
            for (entry.value) |exprt| {
                // Export name length + name
                try leb.writeULEB128(writer, @intCast(u32, exprt.options.name.len));
                try writer.writeAll(exprt.options.name);

                switch (exprt.exported_decl.typed_value.most_recent.typed_value.ty.zigTypeTag()) {
                    .Fn => {
                        // Type of the export
                        try writer.writeByte(0x00);
                        // Exported function index
                        try leb.writeULEB128(writer, self.getFuncidx(exprt.exported_decl).?);
                    },
                    else => return error.TODOImplementNonFnDeclsForWasm,
                }

                count += 1;
            }
        }
        try writeVecSectionHeader(
            file,
            header_offset,
            spec.exports_id,
            @intCast(u32, (try file.getPos()) - header_offset - header_size),
            count,
        );
    }

    // Code section
    {
        const header_offset = try reserveVecSectionHeader(file);
        const writer = file.writer();
        for (self.funcs.items) |decl| {
            const fn_data = &decl.fn_link.wasm.?;

            // Write the already generated code to the file, inserting
            // function indexes where required.
            var current: u32 = 0;
            for (fn_data.idx_refs.items) |idx_ref| {
                try writer.writeAll(fn_data.code.items[current..idx_ref.offset]);
                current = idx_ref.offset;
                // Use a fixed width here to make calculating the code size
                // in codegen.wasm.genCode() simpler.
                var buf: [5]u8 = undefined;
                leb.writeUnsignedFixed(5, &buf, self.getFuncidx(idx_ref.decl).?);
                try writer.writeAll(&buf);
            }

            try writer.writeAll(fn_data.code.items[current..]);
        }
        try writeVecSectionHeader(
            file,
            header_offset,
            spec.code_id,
            @intCast(u32, (try file.getPos()) - header_offset - header_size),
            @intCast(u32, self.funcs.items.len),
        );
    }
}

/// Get the current index of a given Decl in the function list
/// TODO: we could maintain a hash map to potentially make this
fn getFuncidx(self: Wasm, decl: *Module.Decl) ?u32 {
    return for (self.funcs.items) |func, idx| {
        if (func == decl) break @intCast(u32, idx);
    } else null;
}

fn reserveVecSectionHeader(file: fs.File) !u64 {
    // section id + fixed leb contents size + fixed leb vector length
    const header_size = 1 + 5 + 5;
    // TODO: this should be a single lseek(2) call, but fs.File does not
    // currently provide a way to do this.
    try file.seekBy(header_size);
    return (try file.getPos()) - header_size;
}

fn writeVecSectionHeader(file: fs.File, offset: u64, section: u8, size: u32, items: u32) !void {
    var buf: [1 + 5 + 5]u8 = undefined;
    buf[0] = section;
    leb.writeUnsignedFixed(5, buf[1..6], size);
    leb.writeUnsignedFixed(5, buf[6..], items);
    try file.pwriteAll(&buf, offset);
}
