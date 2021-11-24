const Wasm = @This();

const std = @import("std");
const builtin = @import("builtin");
const mem = std.mem;
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const fs = std.fs;
const leb = std.leb;
const log = std.log.scoped(.link);
const wasm = std.wasm;

const Atom = @import("Wasm/Atom.zig");
const Module = @import("../Module.zig");
const Compilation = @import("../Compilation.zig");
const CodeGen = @import("../arch/wasm/CodeGen.zig");
const link = @import("../link.zig");
const trace = @import("../tracy.zig").trace;
const build_options = @import("build_options");
const wasi_libc = @import("../wasi_libc.zig");
const Cache = @import("../Cache.zig");
const TypedValue = @import("../TypedValue.zig");
const LlvmObject = @import("../codegen/llvm.zig").Object;
const Air = @import("../Air.zig");
const Liveness = @import("../Liveness.zig");
const Symbol = @import("Wasm/Symbol.zig");
const types = @import("Wasm/types.zig");

pub const base_tag = link.File.Tag.wasm;

/// deprecated: Use `@import("Wasm/Atom.zig");`
pub const DeclBlock = Atom;

base: link.File,
/// If this is not null, an object file is created by LLVM and linked with LLD afterwards.
llvm_object: ?*LlvmObject = null,
/// When importing objects from the host environment, a name must be supplied.
/// LLVM uses "env" by default when none is given. This would be a good default for Zig
/// to support existing code.
/// TODO: Allow setting this through a flag?
host_name: []const u8 = "env",
/// The last `DeclBlock` that was initialized will be saved here.
last_atom: ?*Atom = null,
/// List of all `Decl` that are currently alive.
/// This is ment for bookkeeping so we can safely cleanup all codegen memory
/// when calling `deinit`
decls: std.AutoHashMapUnmanaged(*Module.Decl, void) = .{},
/// List of all symbols.
symbols: std.ArrayListUnmanaged(Symbol) = .{},
/// List of symbol indexes which are free to be used.
symbols_free_list: std.ArrayListUnmanaged(u32) = .{},
/// Maps atoms to their segment index
atoms: std.AutoHashMapUnmanaged(u32, *Atom) = .{},
/// Represents the index into `segments` where the 'code' section
/// lives.
code_section_index: ?u32 = null,
/// The count of imported functions. This number will be appended
/// to the function indexes as their index starts at the lowest non-extern function.
imported_functions_count: u32 = 0,
/// List of all 'extern' declarations
imports: std.ArrayListUnmanaged(wasm.Import) = .{},
/// List of indexes of symbols representing extern declarations.
import_symbols: std.ArrayListUnmanaged(u32) = .{},
/// Represents non-synthetic section entries.
/// Used for code, data and custom sections.
segments: std.ArrayListUnmanaged(Segment) = .{},
/// Maps a data segment key (such as .rodata) to the index into `segments`.
data_segments: std.StringArrayHashMapUnmanaged(u32) = .{},
/// A list of `types.Segment` which provide meta data
/// about a data symbol such as its name
segment_info: std.ArrayListUnmanaged(types.Segment) = .{},

// Output sections
/// Output type section
func_types: std.ArrayListUnmanaged(wasm.Type) = .{},
/// Output function section
functions: std.ArrayListUnmanaged(wasm.Func) = .{},
/// Output global section
globals: std.ArrayListUnmanaged(wasm.Global) = .{},

/// Indirect function table, used to call function pointers
/// When this is non-zero, we must emit a table entry,
/// as well as an 'elements' section.
function_table: std.ArrayListUnmanaged(Symbol) = .{},

pub const Segment = struct {
    alignment: u32,
    size: u32,
    offset: u32,
};

pub const FnData = struct {
    type_index: u32,

    pub const empty: FnData = .{
        .type_index = undefined,
    };
};

pub fn openPath(allocator: *Allocator, sub_path: []const u8, options: link.Options) !*Wasm {
    assert(options.object_format == .wasm);

    if (build_options.have_llvm and options.use_llvm) {
        const self = try createEmpty(allocator, options);
        errdefer self.base.destroy();

        self.llvm_object = try LlvmObject.create(allocator, sub_path, options);
        return self;
    }

    // TODO: read the file and keep valid parts instead of truncating
    const file = try options.emit.?.directory.handle.createFile(sub_path, .{ .truncate = true, .read = true });
    errdefer file.close();

    const wasm_bin = try createEmpty(allocator, options);
    errdefer wasm_bin.base.destroy();

    wasm_bin.base.file = file;

    try file.writeAll(&(wasm.magic ++ wasm.version));

    // As sym_index '0' is reserved, we use it for our stack pointer symbol
    const global = try wasm_bin.globals.addOne(allocator);
    global.* = .{
        .global_type = .{
            .valtype = .i32,
            .mutable = true,
        },
        .init = .{ .i32_const = 0 },
    };
    const symbol = try wasm_bin.symbols.addOne(allocator);
    symbol.* = .{
        .name = "__stack_pointer",
        .tag = .global,
        .flags = 0,
        .index = 0,
    };
    return wasm_bin;
}

pub fn createEmpty(gpa: *Allocator, options: link.Options) !*Wasm {
    const wasm_bin = try gpa.create(Wasm);
    wasm_bin.* = .{
        .base = .{
            .tag = .wasm,
            .options = options,
            .file = null,
            .allocator = gpa,
        },
    };
    return wasm_bin;
}

pub fn deinit(self: *Wasm) void {
    if (build_options.have_llvm) {
        if (self.llvm_object) |llvm_object| llvm_object.destroy(self.base.allocator);
    }

    var decl_it = self.decls.keyIterator();
    while (decl_it.next()) |decl_ptr| {
        const decl = decl_ptr.*;
        decl.link.wasm.deinit(self.base.allocator);
    }

    for (self.func_types.items) |func_type| {
        self.base.allocator.free(func_type.params);
        self.base.allocator.free(func_type.returns);
    }
    for (self.segment_info.items) |segment_info| {
        self.base.allocator.free(segment_info.name);
    }

    self.decls.deinit(self.base.allocator);
    self.symbols.deinit(self.base.allocator);
    self.symbols_free_list.deinit(self.base.allocator);
    self.atoms.deinit(self.base.allocator);
    self.segments.deinit(self.base.allocator);
    self.data_segments.deinit(self.base.allocator);
    self.segment_info.deinit(self.base.allocator);

    // free output sections
    self.imports.deinit(self.base.allocator);
    self.import_symbols.deinit(self.base.allocator);
    self.func_types.deinit(self.base.allocator);
    self.functions.deinit(self.base.allocator);
    self.globals.deinit(self.base.allocator);
    self.function_table.deinit(self.base.allocator);
}

pub fn allocateDeclIndexes(self: *Wasm, decl: *Module.Decl) !void {
    if (decl.link.wasm.sym_index != 0) return;

    try self.symbols.ensureUnusedCapacity(self.base.allocator, 1);
    try self.decls.putNoClobber(self.base.allocator, decl, {});

    const atom = &decl.link.wasm;

    var symbol: Symbol = .{
        .name = undefined, // will be set after updateDecl
        .flags = 0,
        .tag = undefined, // will be set after updateDecl
        .index = undefined, // will be set after updateDecl
    };

    if (self.symbols_free_list.popOrNull()) |index| {
        atom.sym_index = index;
        self.symbols.items[index] = symbol;
    } else {
        atom.sym_index = @intCast(u32, self.symbols.items.len);
        self.symbols.appendAssumeCapacity(symbol);
    }
}

pub fn updateFunc(self: *Wasm, module: *Module, func: *Module.Fn, air: Air, liveness: Liveness) !void {
    if (build_options.skip_non_native and builtin.object_format != .wasm) {
        @panic("Attempted to compile for object format that was disabled by build configuration");
    }
    if (build_options.have_llvm) {
        if (self.llvm_object) |llvm_object| return llvm_object.updateFunc(module, func, air, liveness);
    }
    const decl = func.owner_decl;
    assert(decl.link.wasm.sym_index != 0); // Must call allocateDeclIndexes()

    var codegen: CodeGen = .{
        .gpa = self.base.allocator,
        .air = air,
        .liveness = liveness,
        .values = .{},
        .code = std.ArrayList(u8).init(self.base.allocator),
        .decl = decl,
        .err_msg = undefined,
        .locals = .{},
        .target = self.base.options.target,
        .bin_file = self,
        .global_error_set = self.base.options.module.?.global_error_set,
    };
    defer codegen.deinit();

    // generate the 'code' section for the function declaration
    const result = codegen.genFunc() catch |err| switch (err) {
        error.CodegenFail => {
            decl.analysis = .codegen_failure;
            try module.failed_decls.put(module.gpa, decl, codegen.err_msg);
            return;
        },
        else => |e| return e,
    };
    return self.finishUpdateDecl(decl, result, &codegen);
}

// Generate code for the Decl, storing it in memory to be later written to
// the file on flush().
pub fn updateDecl(self: *Wasm, module: *Module, decl: *Module.Decl) !void {
    if (build_options.skip_non_native and builtin.object_format != .wasm) {
        @panic("Attempted to compile for object format that was disabled by build configuration");
    }
    if (build_options.have_llvm) {
        if (self.llvm_object) |llvm_object| return llvm_object.updateDecl(module, decl);
    }
    assert(decl.link.wasm.sym_index != 0); // Must call allocateDeclIndexes()

    var codegen: CodeGen = .{
        .gpa = self.base.allocator,
        .air = undefined,
        .liveness = undefined,
        .values = .{},
        .code = std.ArrayList(u8).init(self.base.allocator),
        .decl = decl,
        .err_msg = undefined,
        .locals = .{},
        .target = self.base.options.target,
        .bin_file = self,
        .global_error_set = self.base.options.module.?.global_error_set,
    };
    defer codegen.deinit();

    // generate the 'code' section for the function declaration
    const result = codegen.gen(decl.ty, decl.val) catch |err| switch (err) {
        error.CodegenFail => {
            decl.analysis = .codegen_failure;
            try module.failed_decls.put(module.gpa, decl, codegen.err_msg);
            return;
        },
        else => |e| return e,
    };

    return self.finishUpdateDecl(decl, result, &codegen);
}

fn finishUpdateDecl(self: *Wasm, decl: *Module.Decl, result: CodeGen.Result, codegen: *CodeGen) !void {
    const code: []const u8 = switch (result) {
        .appended => @as([]const u8, codegen.code.items),
        .externally_managed => |payload| payload,
    };

    const atom: *Atom = &decl.link.wasm;
    atom.size = @intCast(u32, code.len);
    try atom.code.appendSlice(self.base.allocator, code);

    // If we're updating an existing decl, unplug it first
    // to avoid infinite loops due to earlier links
    atom.unplug();

    if (decl.isExtern()) {
        try self.createUndefinedSymbol(decl, atom.sym_index);
    } else {
        try self.createDefinedSymbol(decl, atom.sym_index, atom);
    }
}

pub fn updateDeclExports(
    self: *Wasm,
    module: *Module,
    decl: *const Module.Decl,
    exports: []const *Module.Export,
) !void {
    if (build_options.skip_non_native and builtin.object_format != .wasm) {
        @panic("Attempted to compile for object format that was disabled by build configuration");
    }
    if (build_options.have_llvm) {
        if (self.llvm_object) |llvm_object| return llvm_object.updateDeclExports(module, decl, exports);
    }
}

pub fn freeDecl(self: *Wasm, decl: *Module.Decl) void {
    if (build_options.have_llvm) {
        if (self.llvm_object) |llvm_object| return llvm_object.freeDecl(decl);
    }

    const atom = &decl.link.wasm;

    if (self.last_atom == atom) {
        self.last_atom = atom.prev;
    }

    atom.unplug();
    self.symbols_free_list.append(self.base.allocator, atom.sym_index) catch {};
    atom.deinit(self.base.allocator);
    _ = self.decls.remove(decl);
}

fn createUndefinedSymbol(self: *Wasm, decl: *Module.Decl, symbol_index: u32) !void {
    var symbol: *Symbol = &self.symbols.items[symbol_index];
    symbol.name = decl.name;
    symbol.setUndefined(true);
    switch (decl.ty.zigTypeTag()) {
        .Fn => {
            symbol.index = self.imported_functions_count;
            self.imported_functions_count += 1;
            try self.import_symbols.append(self.base.allocator, symbol_index);
            try self.imports.append(self.base.allocator, .{
                .module_name = self.host_name,
                .name = std.mem.span(decl.name),
                .kind = .{ .function = decl.fn_link.wasm.type_index },
            });
        },
        else => @panic("TODO: Implement undefined symbols for non-function declarations"),
    }
}

/// Creates a defined symbol, as well as inserts the given `atom` into the chain
fn createDefinedSymbol(self: *Wasm, decl: *Module.Decl, symbol_index: u32, atom: *Atom) !void {
    const symbol: *Symbol = &self.symbols.items[symbol_index];
    symbol.name = decl.name;
    const final_index = switch (decl.ty.zigTypeTag()) {
        .Fn => result: {
            const type_index = decl.fn_link.wasm.type_index;
            const index = @intCast(u32, self.functions.items.len);
            try self.functions.append(self.base.allocator, .{ .type_index = type_index });
            symbol.tag = .function;
            symbol.index = index;
            atom.alignment = 1;

            if (self.code_section_index == null) {
                self.code_section_index = @intCast(u32, self.segments.items.len);
                try self.segments.append(self.base.allocator, .{
                    .alignment = atom.alignment,
                    .size = atom.size,
                    .offset = atom.offset,
                });
            } else {
                self.segments.items[self.code_section_index.?].size += atom.size;
            }

            break :result self.code_section_index.?;
        },
        else => result: {
            const gop = try self.data_segments.getOrPut(self.base.allocator, ".rodata");
            const atom_index = if (gop.found_existing) blk: {
                self.segments.items[gop.value_ptr.*].size += atom.size;
                break :blk gop.value_ptr.*;
            } else blk: {
                const index = @intCast(u32, self.segments.items.len) - @boolToInt(self.code_section_index != null);
                try self.segments.append(self.base.allocator, .{
                    .alignment = atom.alignment,
                    .size = atom.size,
                    .offset = atom.offset,
                });
                gop.value_ptr.* = index;
                break :blk index;
            };
            const info_index = @intCast(u32, self.segment_info.items.len);
            const segment_name = try std.mem.concat(self.base.allocator, u8, &.{
                ".rodata.",
                std.mem.span(symbol.name),
            });
            errdefer self.base.allocator.free(segment_name);
            try self.segment_info.append(self.base.allocator, .{
                .name = segment_name,
                .alignment = atom.alignment,
                .flags = 0,
            });
            symbol.tag = .data;
            symbol.index = info_index;
            atom.alignment = decl.ty.abiAlignment(self.base.options.target);
            break :result atom_index;
        },
    };

    if (self.atoms.getPtr(final_index)) |last| {
        last.*.next = atom;
        atom.prev = last.*;
        atom.offset = last.*.offset + last.*.size;
        last.* = atom;
    } else {
        try self.atoms.putNoClobber(self.base.allocator, final_index, atom);
    }
}

pub fn flush(self: *Wasm, comp: *Compilation) !void {
    if (build_options.have_llvm and self.base.options.use_lld) {
        return self.linkWithLLD(comp);
    } else {
        return self.flushModule(comp);
    }
}

pub fn flushModule(self: *Wasm, comp: *Compilation) !void {
    _ = comp;
    const tracy = trace(@src());
    defer tracy.end();

    const file = self.base.file.?;
    const header_size = 5 + 1;
    // The size of the emulated stack
    const stack_size = @intCast(u32, self.base.options.stack_size_override orelse std.wasm.page_size);

    var data_size: u32 = 0;
    for (self.segments.items) |segment, index| {
        // skip 'code' segments as they do not count towards data section size
        if (self.code_section_index) |code_index| {
            if (index == code_index) continue;
        }
        data_size += segment.size;
    }

    // set the stack size on the global
    self.globals.items[0].init.i32_const = @bitCast(i32, data_size + stack_size);

    // No need to rewrite the magic/version header
    try file.setEndPos(@sizeOf(@TypeOf(wasm.magic ++ wasm.version)));
    try file.seekTo(@sizeOf(@TypeOf(wasm.magic ++ wasm.version)));

    // Type section
    {
        const header_offset = try reserveVecSectionHeader(file);
        const writer = file.writer();

        for (self.func_types.items) |func_type| {
            try leb.writeULEB128(writer, wasm.function_type);
            try leb.writeULEB128(writer, @intCast(u32, func_type.params.len));
            for (func_type.params) |param_ty| try leb.writeULEB128(writer, wasm.valtype(param_ty));
            try leb.writeULEB128(writer, @intCast(u32, func_type.returns.len));
            for (func_type.returns) |ret_ty| try leb.writeULEB128(writer, wasm.valtype(ret_ty));
        }

        try writeVecSectionHeader(
            file,
            header_offset,
            .type,
            @intCast(u32, (try file.getPos()) - header_offset - header_size),
            @intCast(u32, self.func_types.items.len),
        );
    }

    // Import section
    if (self.import_symbols.items.len > 0) {
        const header_offset = try reserveVecSectionHeader(file);
        const writer = file.writer();
        for (self.import_symbols.items) |symbol_index| {
            const import_symbol = self.symbols.items[symbol_index];
            std.debug.assert(import_symbol.isUndefined());
            try leb.writeULEB128(writer, @intCast(u32, self.host_name.len));
            try writer.writeAll(self.host_name);

            const name = std.mem.span(import_symbol.name);
            try leb.writeULEB128(writer, @intCast(u32, name.len));
            try writer.writeAll(name);

            try writer.writeByte(wasm.externalKind(import_symbol.tag.externalType()));
            const import = self.findImport(import_symbol.index, import_symbol.tag.externalType()).?;
            switch (import.kind) {
                .function => |type_index| try leb.writeULEB128(writer, type_index),
                .global => |global_type| {
                    try leb.writeULEB128(writer, wasm.valtype(global_type.valtype));
                    try writer.writeByte(@boolToInt(global_type.mutable));
                },
                .table => |table| {
                    try leb.writeULEB128(writer, wasm.reftype(table.reftype));
                    try emitLimits(writer, table.limits);
                },
                .memory => |limits| {
                    try emitLimits(writer, limits);
                },
            }
        }
        try writeVecSectionHeader(
            file,
            header_offset,
            .import,
            @intCast(u32, (try file.getPos()) - header_offset - header_size),
            @intCast(u32, self.imports.items.len),
        );
    }

    // Function section
    {
        const header_offset = try reserveVecSectionHeader(file);
        const writer = file.writer();
        for (self.functions.items) |function| {
            try leb.writeULEB128(writer, function.type_index);
        }

        try writeVecSectionHeader(
            file,
            header_offset,
            .function,
            @intCast(u32, (try file.getPos()) - header_offset - header_size),
            @intCast(u32, self.functions.items.len),
        );
    }

    // Memory section
    {
        const header_offset = try reserveVecSectionHeader(file);
        const writer = file.writer();

        try leb.writeULEB128(writer, @as(u32, 0));
        // Calculate the amount of memory pages are required and write them.
        // Wasm uses 64kB page sizes. Round up to ensure the data segments fit into the memory
        try leb.writeULEB128(
            writer,
            try std.math.divCeil(
                u32,
                data_size + stack_size,
                std.wasm.page_size,
            ),
        );
        try writeVecSectionHeader(
            file,
            header_offset,
            .memory,
            @intCast(u32, (try file.getPos()) - header_offset - header_size),
            @as(u32, 1), // wasm currently only supports 1 linear memory segment
        );
    }

    // Global section (used to emit stack pointer)
    {
        const header_offset = try reserveVecSectionHeader(file);
        const writer = file.writer();

        for (self.globals.items) |global| {
            try writer.writeByte(wasm.valtype(global.global_type.valtype));
            try writer.writeByte(@boolToInt(global.global_type.mutable));
            try emitInit(writer, global.init);
        }

        try writeVecSectionHeader(
            file,
            header_offset,
            .global,
            @intCast(u32, (try file.getPos()) - header_offset - header_size),
            @intCast(u32, self.globals.items.len),
        );
    }

    // Export section
    if (self.base.options.module) |module| {
        const header_offset = try reserveVecSectionHeader(file);
        const writer = file.writer();
        var count: u32 = 0;
        var func_index: u32 = self.imported_functions_count;
        for (module.decl_exports.values()) |exports| {
            for (exports) |exprt| {
                // Export name length + name
                try leb.writeULEB128(writer, @intCast(u32, exprt.options.name.len));
                try writer.writeAll(exprt.options.name);

                switch (exprt.exported_decl.ty.zigTypeTag()) {
                    .Fn => {
                        // Type of the export
                        try writer.writeByte(wasm.externalKind(.function));
                        // Exported function index
                        try leb.writeULEB128(writer, func_index);
                        func_index += 1;
                    },
                    else => return error.TODOImplementNonFnDeclsForWasm,
                }

                count += 1;
            }
        }

        // export memory if size is not 0
        if (data_size != 0) {
            try leb.writeULEB128(writer, @intCast(u32, "memory".len));
            try writer.writeAll("memory");
            try writer.writeByte(wasm.externalKind(.memory));
            try leb.writeULEB128(writer, @as(u32, 0)); // only 1 memory 'object' can exist
            count += 1;
        }

        try writeVecSectionHeader(
            file,
            header_offset,
            .@"export",
            @intCast(u32, (try file.getPos()) - header_offset - header_size),
            count,
        );
    }

    // Code section
    if (self.code_section_index) |code_index| {
        const header_offset = try reserveVecSectionHeader(file);
        const writer = file.writer();
        var atom: *Atom = self.atoms.get(code_index).?.getFirst();
        while (true) {
            try atom.resolveRelocs(self);
            try leb.writeULEB128(writer, atom.size);
            try writer.writeAll(atom.code.items);

            atom = atom.next orelse break;
        }
        try writeVecSectionHeader(
            file,
            header_offset,
            .code,
            @intCast(u32, (try file.getPos()) - header_offset - header_size),
            @intCast(u32, self.functions.items.len),
        );
    }

    // Data section
    if (self.data_segments.count() != 0) {
        const header_offset = try reserveVecSectionHeader(file);
        const writer = file.writer();

        var it = self.data_segments.iterator();
        while (it.next()) |entry| {
            // do not output 'bss' section
            if (std.mem.eql(u8, entry.key_ptr.*, ".bss")) continue;
            const atom_index = entry.value_ptr.*;
            var atom = self.atoms.getPtr(atom_index).?.*.getFirst();
            var segment = self.segments.items[atom_index];

            // flag and index to memory section (currently, there can only be 1 memory section in wasm)
            try leb.writeULEB128(writer, @as(u32, 0));

            // offset into data section
            try writer.writeByte(wasm.opcode(.i32_const));
            try leb.writeILEB128(writer, @as(i32, 0));
            try writer.writeByte(wasm.opcode(.end));

            // offset table + data size
            try leb.writeULEB128(writer, segment.size);

            // fill in the offset table and the data segments
            var current_offset: u32 = 0;
            while (true) {
                try atom.resolveRelocs(self);
                std.debug.assert(current_offset == atom.offset);
                std.debug.assert(atom.code.items.len == atom.size);

                try writer.writeAll(atom.code.items);

                current_offset += atom.size;
                if (atom.next) |next| {
                    atom = next;
                } else break;
            }
        }

        try writeVecSectionHeader(
            file,
            header_offset,
            .data,
            @intCast(u32, (try file.getPos()) - header_offset - header_size),
            @intCast(u32, 1), // only 1 data section
        );
    }
}

fn emitLimits(writer: anytype, limits: wasm.Limits) !void {
    try leb.writeULEB128(writer, @boolToInt(limits.max != null));
    try leb.writeULEB128(writer, limits.min);
    if (limits.max) |max| {
        try leb.writeULEB128(writer, max);
    }
}

fn emitInit(writer: anytype, init_expr: wasm.InitExpression) !void {
    switch (init_expr) {
        .i32_const => |val| {
            try writer.writeByte(wasm.opcode(.i32_const));
            try leb.writeILEB128(writer, val);
        },
        .i64_const => |val| {
            try writer.writeByte(wasm.opcode(.i64_const));
            try leb.writeILEB128(writer, val);
        },
        .f32_const => |val| {
            try writer.writeByte(wasm.opcode(.f32_const));
            try writer.writeIntLittle(u32, @bitCast(u32, val));
        },
        .f64_const => |val| {
            try writer.writeByte(wasm.opcode(.f64_const));
            try writer.writeIntLittle(u64, @bitCast(u64, val));
        },
        .global_get => |val| {
            try writer.writeByte(wasm.opcode(.global_get));
            try leb.writeULEB128(writer, val);
        },
    }
    try writer.writeByte(wasm.opcode(.end));
}

fn linkWithLLD(self: *Wasm, comp: *Compilation) !void {
    const tracy = trace(@src());
    defer tracy.end();

    var arena_allocator = std.heap.ArenaAllocator.init(self.base.allocator);
    defer arena_allocator.deinit();
    const arena = &arena_allocator.allocator;

    const directory = self.base.options.emit.?.directory; // Just an alias to make it shorter to type.

    // If there is no Zig code to compile, then we should skip flushing the output file because it
    // will not be part of the linker line anyway.
    const module_obj_path: ?[]const u8 = if (self.base.options.module) |module| blk: {
        const use_stage1 = build_options.is_stage1 and self.base.options.use_stage1;
        if (use_stage1) {
            const obj_basename = try std.zig.binNameAlloc(arena, .{
                .root_name = self.base.options.root_name,
                .target = self.base.options.target,
                .output_mode = .Obj,
            });
            const o_directory = module.zig_cache_artifact_directory;
            const full_obj_path = try o_directory.join(arena, &[_][]const u8{obj_basename});
            break :blk full_obj_path;
        }

        try self.flushModule(comp);
        const obj_basename = self.base.intermediary_basename.?;
        const full_obj_path = try directory.join(arena, &[_][]const u8{obj_basename});
        break :blk full_obj_path;
    } else null;

    const is_obj = self.base.options.output_mode == .Obj;

    const compiler_rt_path: ?[]const u8 = if (self.base.options.include_compiler_rt and !is_obj)
        comp.compiler_rt_static_lib.?.full_object_path
    else
        null;

    const target = self.base.options.target;

    const id_symlink_basename = "lld.id";

    var man: Cache.Manifest = undefined;
    defer if (!self.base.options.disable_lld_caching) man.deinit();

    var digest: [Cache.hex_digest_len]u8 = undefined;

    if (!self.base.options.disable_lld_caching) {
        man = comp.cache_parent.obtain();

        // We are about to obtain this lock, so here we give other processes a chance first.
        self.base.releaseLock();

        try man.addListOfFiles(self.base.options.objects);
        for (comp.c_object_table.keys()) |key| {
            _ = try man.addFile(key.status.success.object_path, null);
        }
        try man.addOptionalFile(module_obj_path);
        try man.addOptionalFile(compiler_rt_path);
        man.hash.addOptional(self.base.options.stack_size_override);
        man.hash.add(self.base.options.import_memory);
        man.hash.addOptional(self.base.options.initial_memory);
        man.hash.addOptional(self.base.options.max_memory);
        man.hash.addOptional(self.base.options.global_base);

        // We don't actually care whether it's a cache hit or miss; we just need the digest and the lock.
        _ = try man.hit();
        digest = man.final();

        var prev_digest_buf: [digest.len]u8 = undefined;
        const prev_digest: []u8 = Cache.readSmallFile(
            directory.handle,
            id_symlink_basename,
            &prev_digest_buf,
        ) catch |err| blk: {
            log.debug("WASM LLD new_digest={s} error: {s}", .{ std.fmt.fmtSliceHexLower(&digest), @errorName(err) });
            // Handle this as a cache miss.
            break :blk prev_digest_buf[0..0];
        };
        if (mem.eql(u8, prev_digest, &digest)) {
            log.debug("WASM LLD digest={s} match - skipping invocation", .{std.fmt.fmtSliceHexLower(&digest)});
            // Hot diggity dog! The output binary is already there.
            self.base.lock = man.toOwnedLock();
            return;
        }
        log.debug("WASM LLD prev_digest={s} new_digest={s}", .{ std.fmt.fmtSliceHexLower(prev_digest), std.fmt.fmtSliceHexLower(&digest) });

        // We are about to change the output file to be different, so we invalidate the build hash now.
        directory.handle.deleteFile(id_symlink_basename) catch |err| switch (err) {
            error.FileNotFound => {},
            else => |e| return e,
        };
    }

    const full_out_path = try directory.join(arena, &[_][]const u8{self.base.options.emit.?.sub_path});

    if (self.base.options.output_mode == .Obj) {
        // LLD's WASM driver does not support the equivalent of `-r` so we do a simple file copy
        // here. TODO: think carefully about how we can avoid this redundant operation when doing
        // build-obj. See also the corresponding TODO in linkAsArchive.
        const the_object_path = blk: {
            if (self.base.options.objects.len != 0)
                break :blk self.base.options.objects[0];

            if (comp.c_object_table.count() != 0)
                break :blk comp.c_object_table.keys()[0].status.success.object_path;

            if (module_obj_path) |p|
                break :blk p;

            // TODO I think this is unreachable. Audit this situation when solving the above TODO
            // regarding eliding redundant object -> object transformations.
            return error.NoObjectsToLink;
        };
        // This can happen when using --enable-cache and using the stage1 backend. In this case
        // we can skip the file copy.
        if (!mem.eql(u8, the_object_path, full_out_path)) {
            try fs.cwd().copyFile(the_object_path, fs.cwd(), full_out_path, .{});
        }
    } else {
        // Create an LLD command line and invoke it.
        var argv = std.ArrayList([]const u8).init(self.base.allocator);
        defer argv.deinit();
        // We will invoke ourselves as a child process to gain access to LLD.
        // This is necessary because LLD does not behave properly as a library -
        // it calls exit() and does not reset all global data between invocations.
        try argv.appendSlice(&[_][]const u8{ comp.self_exe_path.?, "wasm-ld" });
        try argv.append("-error-limit=0");

        if (self.base.options.lto) {
            switch (self.base.options.optimize_mode) {
                .Debug => {},
                .ReleaseSmall => try argv.append("-O2"),
                .ReleaseFast, .ReleaseSafe => try argv.append("-O3"),
            }
        }

        if (self.base.options.import_memory) {
            try argv.append("--import-memory");
        }

        if (self.base.options.initial_memory) |initial_memory| {
            const arg = try std.fmt.allocPrint(arena, "--initial-memory={d}", .{initial_memory});
            try argv.append(arg);
        }

        if (self.base.options.max_memory) |max_memory| {
            const arg = try std.fmt.allocPrint(arena, "--max-memory={d}", .{max_memory});
            try argv.append(arg);
        }

        if (self.base.options.global_base) |global_base| {
            const arg = try std.fmt.allocPrint(arena, "--global-base={d}", .{global_base});
            try argv.append(arg);
        }

        if (self.base.options.output_mode == .Exe) {
            // Increase the default stack size to a more reasonable value of 1MB instead of
            // the default of 1 Wasm page being 64KB, unless overridden by the user.
            try argv.append("-z");
            const stack_size = self.base.options.stack_size_override orelse 1048576;
            const arg = try std.fmt.allocPrint(arena, "stack-size={d}", .{stack_size});
            try argv.append(arg);

            // Put stack before globals so that stack overflow results in segfault immediately
            // before corrupting globals. See https://github.com/ziglang/zig/issues/4496
            try argv.append("--stack-first");

            if (self.base.options.wasi_exec_model == .reactor) {
                // Reactor execution model does not have _start so lld doesn't look for it.
                try argv.append("--no-entry");
                // Make sure "_initialize" and other used-defined functions are exported if this is WASI reactor.
                try argv.append("--export-dynamic");
            }
        } else {
            if (self.base.options.stack_size_override) |stack_size| {
                try argv.append("-z");
                const arg = try std.fmt.allocPrint(arena, "stack-size={d}", .{stack_size});
                try argv.append(arg);
            }
            try argv.append("--no-entry"); // So lld doesn't look for _start.
            try argv.append("--export-all");
        }
        try argv.appendSlice(&[_][]const u8{
            "--allow-undefined",
            "-o",
            full_out_path,
        });

        if (target.os.tag == .wasi) {
            const is_exe_or_dyn_lib = self.base.options.output_mode == .Exe or
                (self.base.options.output_mode == .Lib and self.base.options.link_mode == .Dynamic);
            if (is_exe_or_dyn_lib) {
                const wasi_emulated_libs = self.base.options.wasi_emulated_libs;
                for (wasi_emulated_libs) |crt_file| {
                    try argv.append(try comp.get_libc_crt_file(
                        arena,
                        wasi_libc.emulatedLibCRFileLibName(crt_file),
                    ));
                }

                if (self.base.options.link_libc) {
                    try argv.append(try comp.get_libc_crt_file(
                        arena,
                        wasi_libc.execModelCrtFileFullName(self.base.options.wasi_exec_model),
                    ));
                    try argv.append(try comp.get_libc_crt_file(arena, "libc.a"));
                }

                if (self.base.options.link_libcpp) {
                    try argv.append(comp.libcxx_static_lib.?.full_object_path);
                    try argv.append(comp.libcxxabi_static_lib.?.full_object_path);
                }
            }
        }

        // Positional arguments to the linker such as object files.
        try argv.appendSlice(self.base.options.objects);

        for (comp.c_object_table.keys()) |key| {
            try argv.append(key.status.success.object_path);
        }
        if (module_obj_path) |p| {
            try argv.append(p);
        }

        if (self.base.options.output_mode != .Obj and
            !self.base.options.skip_linker_dependencies and
            !self.base.options.link_libc)
        {
            try argv.append(comp.libc_static_lib.?.full_object_path);
        }

        if (compiler_rt_path) |p| {
            try argv.append(p);
        }

        if (self.base.options.verbose_link) {
            // Skip over our own name so that the LLD linker name is the first argv item.
            Compilation.dump_argv(argv.items[1..]);
        }

        // Sadly, we must run LLD as a child process because it does not behave
        // properly as a library.
        const child = try std.ChildProcess.init(argv.items, arena);
        defer child.deinit();

        if (comp.clang_passthrough_mode) {
            child.stdin_behavior = .Inherit;
            child.stdout_behavior = .Inherit;
            child.stderr_behavior = .Inherit;

            const term = child.spawnAndWait() catch |err| {
                log.err("unable to spawn {s}: {s}", .{ argv.items[0], @errorName(err) });
                return error.UnableToSpawnSelf;
            };
            switch (term) {
                .Exited => |code| {
                    if (code != 0) {
                        // TODO https://github.com/ziglang/zig/issues/6342
                        std.process.exit(1);
                    }
                },
                else => std.process.abort(),
            }
        } else {
            child.stdin_behavior = .Ignore;
            child.stdout_behavior = .Ignore;
            child.stderr_behavior = .Pipe;

            try child.spawn();

            const stderr = try child.stderr.?.reader().readAllAlloc(arena, 10 * 1024 * 1024);

            const term = child.wait() catch |err| {
                log.err("unable to spawn {s}: {s}", .{ argv.items[0], @errorName(err) });
                return error.UnableToSpawnSelf;
            };

            switch (term) {
                .Exited => |code| {
                    if (code != 0) {
                        // TODO parse this output and surface with the Compilation API rather than
                        // directly outputting to stderr here.
                        std.debug.print("{s}", .{stderr});
                        return error.LLDReportedFailure;
                    }
                },
                else => {
                    log.err("{s} terminated with stderr:\n{s}", .{ argv.items[0], stderr });
                    return error.LLDCrashed;
                },
            }

            if (stderr.len != 0) {
                log.warn("unexpected LLD stderr:\n{s}", .{stderr});
            }
        }
    }

    if (!self.base.options.disable_lld_caching) {
        // Update the file with the digest. If it fails we can continue; it only
        // means that the next invocation will have an unnecessary cache miss.
        Cache.writeSmallFile(directory.handle, id_symlink_basename, &digest) catch |err| {
            log.warn("failed to save linking hash digest symlink: {s}", .{@errorName(err)});
        };
        // Again failure here only means an unnecessary cache miss.
        man.writeManifest() catch |err| {
            log.warn("failed to write cache manifest when linking: {s}", .{@errorName(err)});
        };
        // We hang on to this lock so that the output file path can be used without
        // other processes clobbering it.
        self.base.lock = man.toOwnedLock();
    }
}

fn reserveVecSectionHeader(file: fs.File) !u64 {
    // section id + fixed leb contents size + fixed leb vector length
    const header_size = 1 + 5 + 5;
    // TODO: this should be a single lseek(2) call, but fs.File does not
    // currently provide a way to do this.
    try file.seekBy(header_size);
    return (try file.getPos()) - header_size;
}

fn writeVecSectionHeader(file: fs.File, offset: u64, section: wasm.Section, size: u32, items: u32) !void {
    var buf: [1 + 5 + 5]u8 = undefined;
    buf[0] = @enumToInt(section);
    leb.writeUnsignedFixed(5, buf[1..6], size);
    leb.writeUnsignedFixed(5, buf[6..], items);
    try file.pwriteAll(&buf, offset);
}

/// Searches for an a matching function signature, when not found
/// a new entry will be made. The index of the existing/new signature will be returned.
pub fn putOrGetFuncType(self: *Wasm, func_type: wasm.Type) !u32 {
    var index: u32 = 0;
    while (index < self.func_types.items.len) : (index += 1) {
        if (self.func_types.items[index].eql(func_type)) return index;
    }

    // functype does not exist.
    const params = try self.base.allocator.dupe(wasm.Valtype, func_type.params);
    errdefer self.base.allocator.free(params);
    const returns = try self.base.allocator.dupe(wasm.Valtype, func_type.returns);
    errdefer self.base.allocator.free(returns);
    try self.func_types.append(self.base.allocator, .{
        .params = params,
        .returns = returns,
    });
    return index;
}

/// From a given index and an `ExternalKind`, finds the corresponding Import.
/// This is due to indexes for imports being unique per type, rather than across all imports.
fn findImport(self: Wasm, index: u32, external_type: wasm.ExternalKind) ?*wasm.Import {
    var current_index: u32 = 0;
    for (self.imports.items) |*import| {
        if (import.kind == external_type) {
            if (current_index == index) return import;
            current_index += 1;
        }
    }
    return null;
}
