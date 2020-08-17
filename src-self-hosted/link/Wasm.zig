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
    funcidx: u32,
};

base: link.File,

types: Types,
funcs: Funcs,
exports: Exports,

/// Array over the section structs used in the various sections above to
/// allow iteration when shifting sections to make space.
/// TODO: this should eventually be size 11 when we use all the sections.
sections: [4]*Section,

pub fn openPath(allocator: *Allocator, dir: fs.Dir, sub_path: []const u8, options: link.Options) !*link.File {
    assert(options.object_format == .wasm);

    // TODO: read the file and keep vaild parts instead of truncating
    const file = try dir.createFile(sub_path, .{ .truncate = true, .read = true });
    errdefer file.close();

    const wasm = try allocator.create(Wasm);
    errdefer allocator.destroy(wasm);

    try file.writeAll(&(spec.magic ++ spec.version));

    // TODO: this should vary depending on the section and be less arbitrary
    const size = 1024;
    const offset = @sizeOf(@TypeOf(spec.magic ++ spec.version));

    wasm.* = .{
        .base = .{
            .tag = .wasm,
            .options = options,
            .file = file,
            .allocator = allocator,
        },

        .types = try Types.init(file, offset, size),
        .funcs = try Funcs.init(file, offset + size, size, offset + 3 * size, size),
        .exports = try Exports.init(file, offset + 2 * size, size),

        // These must be ordered as they will appear in the output file
        .sections = [_]*Section{
            &wasm.types.typesec.section,
            &wasm.funcs.funcsec,
            &wasm.exports.exportsec,
            &wasm.funcs.codesec.section,
        },
    };

    try file.setEndPos(offset + 4 * size);

    return &wasm.base;
}

pub fn deinit(self: *Wasm) void {
    self.types.deinit();
    self.funcs.deinit();
}

pub fn updateDecl(self: *Wasm, module: *Module, decl: *Module.Decl) !void {
    if (decl.typed_value.most_recent.typed_value.ty.zigTypeTag() != .Fn)
        return error.TODOImplementNonFnDeclsForWasm;

    if (decl.fn_link.wasm) |fn_data| {
        self.funcs.free(fn_data.funcidx);
    }

    var buf = std.ArrayList(u8).init(self.base.allocator);
    defer buf.deinit();

    try codegen.genFunctype(&buf, decl);
    const typeidx = try self.types.new(buf.items);
    buf.items.len = 0;

    try codegen.genCode(&buf, decl);
    const funcidx = try self.funcs.new(typeidx, buf.items);

    decl.fn_link.wasm = .{ .funcidx = funcidx };

    // TODO: we should be more smart and set this only when needed
    self.exports.dirty = true;
}

pub fn updateDeclExports(
    self: *Wasm,
    module: *Module,
    decl: *const Module.Decl,
    exports: []const *Module.Export,
) !void {
    self.exports.dirty = true;
}

pub fn freeDecl(self: *Wasm, decl: *Module.Decl) void {
    // TODO: remove this assert when non-function Decls are implemented
    assert(decl.typed_value.most_recent.typed_value.ty.zigTypeTag() == .Fn);
    if (decl.fn_link.wasm) |fn_data| {
        self.funcs.free(fn_data.funcidx);
        decl.fn_link.wasm = null;
    }
}

pub fn flush(self: *Wasm, module: *Module) !void {
    if (self.exports.dirty) try self.exports.writeAll(module);
}

/// This struct describes the location of a named section + custom section
/// padding in the output file. This is all the data we need to allow for
/// shifting sections around when padding runs out.
const Section = struct {
    /// The size of a section header: 1 byte section id + 5 bytes
    /// for the fixed-width ULEB128 encoded contents size.
    const header_size = 1 + 5;
    /// Offset of the section id byte from the start of the file.
    offset: u64,
    /// Size of the section, including the header and directly
    /// following custom section used for padding if any.
    size: u64,

    /// Resize the usable part of the section, handling the following custom
    /// section used for padding. If there is not enough padding left, shift
    /// all following sections to make space. Takes the current and target
    /// contents sizes of the section as arguments.
    fn resize(self: *Section, file: fs.File, current: u32, target: u32) !void {
        // Section header + target contents size + custom section header
        // + custom section name + empty custom section > owned chunk of the file
        if (header_size + target + header_size + 1 + 0 > self.size)
            return error.TODOImplementSectionShifting;

        const new_custom_start = self.offset + header_size + target;
        const new_custom_contents_size = self.size - target - 2 * header_size;
        assert(new_custom_contents_size >= 1);
        // +1 for the name of the custom section, which we set to an empty string
        var custom_header: [header_size + 1]u8 = undefined;
        custom_header[0] = spec.custom_id;
        leb.writeUnsignedFixed(5, custom_header[1..header_size], @intCast(u32, new_custom_contents_size));
        custom_header[header_size] = 0;
        try file.pwriteAll(&custom_header, new_custom_start);
    }
};

/// This can be used to manage the contents of any section which uses a vector
/// of contents. This interface maintains index stability while allowing for
/// reuse of "dead" indexes.
const VecSection = struct {
    /// Represents a single entry in the vector (e.g. a type in the type section)
    const Entry = struct {
        /// Offset from the start of the section contents in bytes
        offset: u32,
        /// Size in bytes of the entry
        size: u32,
    };
    section: Section,
    /// Size in bytes of the contents of the section. Does not include
    /// the "header" containing the section id and this value.
    contents_size: u32,
    /// List of all entries in the contents of the section.
    entries: std.ArrayListUnmanaged(Entry) = std.ArrayListUnmanaged(Entry){},
    /// List of indexes of unreferenced entries which may be
    /// overwritten and reused.
    dead_list: std.ArrayListUnmanaged(u32) = std.ArrayListUnmanaged(u32){},

    /// Write the headers of the section and custom padding section
    fn init(comptime section_id: u8, file: fs.File, offset: u64, initial_size: u64) !VecSection {
        // section id, section size, empty vector, custom section id,
        // custom section size, empty custom section name
        var initial_data: [1 + 5 + 5 + 1 + 5 + 1]u8 = undefined;

        assert(initial_size >= initial_data.len);

        comptime var i = 0;
        initial_data[i] = section_id;
        i += 1;
        leb.writeUnsignedFixed(5, initial_data[i..(i + 5)], 5);
        i += 5;
        leb.writeUnsignedFixed(5, initial_data[i..(i + 5)], 0);
        i += 5;
        initial_data[i] = spec.custom_id;
        i += 1;
        leb.writeUnsignedFixed(5, initial_data[i..(i + 5)], @intCast(u32, initial_size - @sizeOf(@TypeOf(initial_data))));
        i += 5;
        initial_data[i] = 0;

        try file.pwriteAll(&initial_data, offset);

        return VecSection{
            .section = .{
                .offset = offset,
                .size = initial_size,
            },
            .contents_size = 5,
        };
    }

    fn deinit(self: *VecSection, allocator: *Allocator) void {
        self.entries.deinit(allocator);
        self.dead_list.deinit(allocator);
    }

    /// Write a new entry into the file, returning the index used.
    fn addEntry(self: *VecSection, file: fs.File, allocator: *Allocator, data: []const u8) !u32 {
        // First look for a dead entry we can reuse
        for (self.dead_list.items) |dead_idx, i| {
            const dead_entry = &self.entries.items[dead_idx];
            if (dead_entry.size == data.len) {
                // Found a dead entry of the right length, overwrite it
                try file.pwriteAll(data, self.section.offset + Section.header_size + dead_entry.offset);
                _ = self.dead_list.swapRemove(i);
                return dead_idx;
            }
        }

        // TODO: We can be more efficient if we special-case one or
        // more consecutive dead entries at the end of the vector.

        // We failed to find a dead entry to reuse, so write the new
        // entry to the end of the section.
        try self.section.resize(file, self.contents_size, self.contents_size + @intCast(u32, data.len));
        try file.pwriteAll(data, self.section.offset + Section.header_size + self.contents_size);
        try self.entries.append(allocator, .{
            .offset = self.contents_size,
            .size = @intCast(u32, data.len),
        });
        self.contents_size += @intCast(u32, data.len);
        // Make sure the dead list always has enough space to store all free'd
        // entries. This makes it so that delEntry() cannot fail.
        // TODO: figure out a better way that doesn't waste as much memory
        try self.dead_list.ensureCapacity(allocator, self.entries.items.len);

        // Update the size in the section header and the item count of
        // the contents vector.
        var size_and_count: [10]u8 = undefined;
        leb.writeUnsignedFixed(5, size_and_count[0..5], self.contents_size);
        leb.writeUnsignedFixed(5, size_and_count[5..], @intCast(u32, self.entries.items.len));
        try file.pwriteAll(&size_and_count, self.section.offset + 1);

        return @intCast(u32, self.entries.items.len - 1);
    }

    /// Mark the type referenced by the given index as dead.
    fn delEntry(self: *VecSection, index: u32) void {
        self.dead_list.appendAssumeCapacity(index);
    }
};

const Types = struct {
    typesec: VecSection,

    fn init(file: fs.File, offset: u64, initial_size: u64) !Types {
        return Types{ .typesec = try VecSection.init(spec.types_id, file, offset, initial_size) };
    }

    fn deinit(self: *Types) void {
        const wasm = @fieldParentPtr(Wasm, "types", self);
        self.typesec.deinit(wasm.base.allocator);
    }

    fn new(self: *Types, data: []const u8) !u32 {
        const wasm = @fieldParentPtr(Wasm, "types", self);
        return self.typesec.addEntry(wasm.base.file.?, wasm.base.allocator, data);
    }

    fn free(self: *Types, typeidx: u32) void {
        self.typesec.delEntry(typeidx);
    }
};

const Funcs = struct {
    /// This section needs special handling to keep the indexes matching with
    /// the codesec, so we cant just use a VecSection.
    funcsec: Section,
    /// The typeidx stored for each function, indexed by funcidx.
    func_types: std.ArrayListUnmanaged(u32) = std.ArrayListUnmanaged(u32){},
    codesec: VecSection,

    fn init(file: fs.File, funcs_offset: u64, funcs_size: u64, code_offset: u64, code_size: u64) !Funcs {
        return Funcs{
            .funcsec = (try VecSection.init(spec.funcs_id, file, funcs_offset, funcs_size)).section,
            .codesec = try VecSection.init(spec.code_id, file, code_offset, code_size),
        };
    }

    fn deinit(self: *Funcs) void {
        const wasm = @fieldParentPtr(Wasm, "funcs", self);
        self.func_types.deinit(wasm.base.allocator);
        self.codesec.deinit(wasm.base.allocator);
    }

    /// Add a new function to the binary, first finding space for and writing
    /// the code then writing the typeidx to the corresponding index in the
    /// funcsec. Returns the function index used.
    fn new(self: *Funcs, typeidx: u32, code: []const u8) !u32 {
        const wasm = @fieldParentPtr(Wasm, "funcs", self);
        const file = wasm.base.file.?;
        const allocator = wasm.base.allocator;

        assert(self.func_types.items.len == self.codesec.entries.items.len);

        // TODO: consider nop-padding the code if there is a close but not perfect fit
        const funcidx = try self.codesec.addEntry(file, allocator, code);

        if (self.func_types.items.len < self.codesec.entries.items.len) {
            // u32 vector length + funcs_count u32s in the vector
            const current = 5 + @intCast(u32, self.func_types.items.len) * 5;
            try self.funcsec.resize(file, current, current + 5);
            try self.func_types.append(allocator, typeidx);

            // Update the size in the section header and the item count of
            // the contents vector.
            const count = @intCast(u32, self.func_types.items.len);
            var size_and_count: [10]u8 = undefined;
            leb.writeUnsignedFixed(5, size_and_count[0..5], 5 + count * 5);
            leb.writeUnsignedFixed(5, size_and_count[5..], count);
            try file.pwriteAll(&size_and_count, self.funcsec.offset + 1);
        } else {
            // We are overwriting a dead function and may now free the type
            wasm.types.free(self.func_types.items[funcidx]);
        }

        assert(self.func_types.items.len == self.codesec.entries.items.len);

        var typeidx_leb: [5]u8 = undefined;
        leb.writeUnsignedFixed(5, &typeidx_leb, typeidx);
        try file.pwriteAll(&typeidx_leb, self.funcsec.offset + Section.header_size + 5 + funcidx * 5);

        return funcidx;
    }

    fn free(self: *Funcs, funcidx: u32) void {
        self.codesec.delEntry(funcidx);
    }
};

/// Exports are tricky. We can't leave dead entries in the binary as they
/// would obviously be visible from the execution environment. The simplest
/// way to work around this is to re-emit the export section whenever
/// something changes. This also makes it easier to ensure exported function
/// and global indexes are updated as they change.
const Exports = struct {
    exportsec: Section,
    /// Size in bytes of the contents of the section. Does not include
    /// the "header" containing the section id and this value.
    contents_size: u32,
    /// If this is true, then exports will be rewritten on flush()
    dirty: bool,

    fn init(file: fs.File, offset: u64, initial_size: u64) !Exports {
        return Exports{
            .exportsec = (try VecSection.init(spec.exports_id, file, offset, initial_size)).section,
            .contents_size = 5,
            .dirty = false,
        };
    }

    fn writeAll(self: *Exports, module: *Module) !void {
        const wasm = @fieldParentPtr(Wasm, "exports", self);
        const file = wasm.base.file.?;
        var buf: [5]u8 = undefined;

        // First ensure the section is the right size
        var export_count: u32 = 0;
        var new_contents_size: u32 = 5;
        for (module.decl_exports.entries.items) |entry| {
            for (entry.value) |e| {
                export_count += 1;
                new_contents_size += calcSize(e);
            }
        }
        if (new_contents_size != self.contents_size) {
            try self.exportsec.resize(file, self.contents_size, new_contents_size);
            leb.writeUnsignedFixed(5, &buf, new_contents_size);
            try file.pwriteAll(&buf, self.exportsec.offset + 1);
        }

        try file.seekTo(self.exportsec.offset + Section.header_size);
        const writer = file.writer();

        // Length of the exports vec
        leb.writeUnsignedFixed(5, &buf, export_count);
        try writer.writeAll(&buf);

        for (module.decl_exports.entries.items) |entry|
            for (entry.value) |e| try writeExport(writer, e);

        self.dirty = false;
    }

    /// Return the total number of bytes an export will take.
    /// TODO: fixed-width LEB128 is currently used for simplicity, but should
    /// be replaced with proper variable-length LEB128 as it is inefficient.
    fn calcSize(e: *Module.Export) u32 {
        // LEB128 name length + name bytes + export type + LEB128 index
        return 5 + @intCast(u32, e.options.name.len) + 1 + 5;
    }

    /// Write the data for a single export to the given file at a given offset.
    /// TODO: fixed-width LEB128 is currently used for simplicity, but should
    /// be replaced with proper variable-length LEB128 as it is inefficient.
    fn writeExport(writer: anytype, e: *Module.Export) !void {
        var buf: [5]u8 = undefined;

        // Export name length + name
        leb.writeUnsignedFixed(5, &buf, @intCast(u32, e.options.name.len));
        try writer.writeAll(&buf);
        try writer.writeAll(e.options.name);

        switch (e.exported_decl.typed_value.most_recent.typed_value.ty.zigTypeTag()) {
            .Fn => {
                // Type of the export
                try writer.writeByte(0x00);
                // Exported function index
                leb.writeUnsignedFixed(5, &buf, e.exported_decl.fn_link.wasm.?.funcidx);
                try writer.writeAll(&buf);
            },
            else => return error.TODOImplementNonFnDeclsForWasm,
        }
    }
};
