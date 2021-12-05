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
/// Map of symbol indexes, represented by its `wasm.Import`
imports: std.AutoHashMapUnmanaged(u32, wasm.Import) = .{},
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
/// Memory section
memories: wasm.Memory = .{ .limits = .{ .min = 0, .max = null } },

/// Indirect function table, used to call function pointers
/// When this is non-zero, we must emit a table entry,
/// as well as an 'elements' section.
///
/// Note: Key is symbol index, value represents the index into the table
function_table: std.AutoHashMapUnmanaged(u32, u32) = .{},

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

pub fn openPath(allocator: Allocator, sub_path: []const u8, options: link.Options) !*Wasm {
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

pub fn createEmpty(gpa: Allocator, options: link.Options) !*Wasm {
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

    for (self.func_types.items) |*func_type| {
        func_type.deinit(self.base.allocator);
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

    decl.link.wasm.clear();

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

    decl.link.wasm.clear();

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
    const result = codegen.genDecl() catch |err| switch (err) {
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

    if (decl.isExtern()) {
        try self.addOrUpdateImport(decl);
        return;
    }

    if (code.len == 0) return;
    const atom: *Atom = &decl.link.wasm;
    atom.size = @intCast(u32, code.len);
    try atom.code.appendSlice(self.base.allocator, code);
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
    self.symbols_free_list.append(self.base.allocator, atom.sym_index) catch {};
    atom.deinit(self.base.allocator);
    _ = self.decls.remove(decl);

    if (decl.isExtern()) {
        const import = self.imports.fetchRemove(decl.link.wasm.sym_index).?.value;
        switch (import.kind) {
            .function => self.imported_functions_count -= 1,
            else => unreachable,
        }
    }

    // maybe remove from function table if needed
    if (decl.ty.zigTypeTag() == .Fn) {
        _ = self.function_table.remove(atom.sym_index);
    }
}

/// Appends a new entry to the indirect function table
pub fn addTableFunction(self: *Wasm, symbol_index: u32) !void {
    const index = @intCast(u32, self.function_table.count());
    try self.function_table.put(self.base.allocator, symbol_index, index);
}

fn mapFunctionTable(self: *Wasm) void {
    var it = self.function_table.valueIterator();
    var index: u32 = 0;
    while (it.next()) |value_ptr| : (index += 1) {
        value_ptr.* = index;
    }
}

fn addOrUpdateImport(self: *Wasm, decl: *Module.Decl) !void {
    const symbol_index = decl.link.wasm.sym_index;
    const symbol: *Symbol = &self.symbols.items[symbol_index];
    symbol.name = decl.name;
    symbol.setUndefined(true);
    switch (decl.ty.zigTypeTag()) {
        .Fn => {
            const gop = try self.imports.getOrPut(self.base.allocator, symbol_index);
            if (!gop.found_existing) {
                self.imported_functions_count += 1;
                gop.value_ptr.* = .{
                    .module_name = self.host_name,
                    .name = std.mem.span(symbol.name),
                    .kind = .{ .function = decl.fn_link.wasm.type_index },
                };
            }
        },
        else => @panic("TODO: Implement undefined symbols for non-function declarations"),
    }
}

fn parseDeclIntoAtom(self: *Wasm, decl: *Module.Decl) !void {
    const atom: *Atom = &decl.link.wasm;
    const symbol: *Symbol = &self.symbols.items[atom.sym_index];
    symbol.name = decl.name;
    atom.alignment = decl.ty.abiAlignment(self.base.options.target);
    const final_index: u32 = switch (decl.ty.zigTypeTag()) {
        .Fn => result: {
            const fn_data = decl.fn_link.wasm;
            const type_index = fn_data.type_index;
            const index = @intCast(u32, self.functions.items.len + self.imported_functions_count);
            try self.functions.append(self.base.allocator, .{ .type_index = type_index });
            symbol.tag = .function;
            symbol.index = index;

            if (self.code_section_index == null) {
                self.code_section_index = @intCast(u32, self.segments.items.len);
                try self.segments.append(self.base.allocator, .{
                    .alignment = atom.alignment,
                    .size = atom.size,
                    .offset = 0,
                });
            }

            break :result self.code_section_index.?;
        },
        else => result: {
            const gop = try self.data_segments.getOrPut(self.base.allocator, ".rodata");
            const atom_index = if (gop.found_existing) blk: {
                self.segments.items[gop.value_ptr.*].size += atom.size;
                break :blk gop.value_ptr.*;
            } else blk: {
                const index = @intCast(u32, self.segments.items.len);
                try self.segments.append(self.base.allocator, .{
                    .alignment = atom.alignment,
                    .size = 0,
                    .offset = 0,
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

    const segment: *Segment = &self.segments.items[final_index];
    segment.alignment = std.math.max(segment.alignment, atom.alignment);
    segment.size = std.mem.alignForwardGeneric(
        u32,
        std.mem.alignForwardGeneric(u32, segment.size, atom.alignment) + atom.size,
        segment.alignment,
    );

    if (self.atoms.getPtr(final_index)) |last| {
        last.*.next = atom;
        atom.prev = last.*;
        last.* = atom;
    } else {
        try self.atoms.putNoClobber(self.base.allocator, final_index, atom);
    }
}

fn allocateAtoms(self: *Wasm) !void {
    var it = self.atoms.iterator();
    while (it.next()) |entry| {
        var atom: *Atom = entry.value_ptr.*.getFirst();
        var offset: u32 = 0;
        while (true) {
            offset = std.mem.alignForwardGeneric(u32, offset, atom.alignment);
            atom.offset = offset;
            log.debug("Atom '{s}' allocated from 0x{x:0>8} to 0x{x:0>8} size={d}", .{
                self.symbols.items[atom.sym_index].name,
                offset,
                offset + atom.size,
                atom.size,
            });
            offset += atom.size;
            atom = atom.next orelse break;
        }
    }
}

fn setupImports(self: *Wasm) void {
    var function_index: u32 = 0;
    var it = self.imports.iterator();
    while (it.next()) |entry| {
        const symbol = &self.symbols.items[entry.key_ptr.*];
        const import: wasm.Import = entry.value_ptr.*;
        switch (import.kind) {
            .function => {
                symbol.index = function_index;
                function_index += 1;
            },
            else => unreachable,
        }
    }
}

/// Sets up the memory section of the wasm module, as well as the stack.
fn setupMemory(self: *Wasm) !void {
    log.debug("Setting up memory layout", .{});
    const page_size = 64 * 1024;
    const stack_size = self.base.options.stack_size_override orelse page_size * 1;
    const stack_alignment = 16;
    var memory_ptr: u64 = self.base.options.global_base orelse 1024;
    memory_ptr = std.mem.alignForwardGeneric(u64, memory_ptr, stack_alignment);

    var offset: u32 = @intCast(u32, memory_ptr);
    for (self.segments.items) |*segment, i| {
        // skip 'code' segments
        if (self.code_section_index) |index| {
            if (index == i) continue;
        }
        memory_ptr = std.mem.alignForwardGeneric(u64, memory_ptr, segment.alignment);
        memory_ptr += segment.size;
        segment.offset = offset;
        offset += segment.size;
    }

    memory_ptr = std.mem.alignForwardGeneric(u64, memory_ptr, stack_alignment);
    memory_ptr += stack_size;

    // Setup the max amount of pages
    // For now we only support wasm32 by setting the maximum allowed memory size 2^32-1
    const max_memory_allowed: u64 = (1 << 32) - 1;

    if (self.base.options.initial_memory) |initial_memory| {
        if (!std.mem.isAlignedGeneric(u64, initial_memory, page_size)) {
            log.err("Initial memory must be {d}-byte aligned", .{page_size});
            return error.MissAlignment;
        }
        if (memory_ptr > initial_memory) {
            log.err("Initial memory too small, must be at least {d} bytes", .{memory_ptr});
            return error.MemoryTooSmall;
        }
        if (initial_memory > max_memory_allowed) {
            log.err("Initial memory exceeds maximum memory {d}", .{max_memory_allowed});
            return error.MemoryTooBig;
        }
        memory_ptr = initial_memory;
    }

    // In case we do not import memory, but define it ourselves,
    // set the minimum amount of pages on the memory section.
    self.memories.limits.min = @intCast(u32, std.mem.alignForwardGeneric(u64, memory_ptr, page_size) / page_size);
    log.debug("Total memory pages: {d}", .{self.memories.limits.min});

    if (self.base.options.max_memory) |max_memory| {
        if (!std.mem.isAlignedGeneric(u64, max_memory, page_size)) {
            log.err("Maximum memory must be {d}-byte aligned", .{page_size});
            return error.MissAlignment;
        }
        if (memory_ptr > max_memory) {
            log.err("Maxmimum memory too small, must be at least {d} bytes", .{memory_ptr});
            return error.MemoryTooSmall;
        }
        if (max_memory > max_memory_allowed) {
            log.err("Maximum memory exceeds maxmium amount {d}", .{max_memory_allowed});
            return error.MemoryTooBig;
        }
        self.memories.limits.max = @intCast(u32, max_memory / page_size);
        log.debug("Maximum memory pages: {d}", .{self.memories.limits.max});
    }

    // We always put the stack pointer global at index 0
    self.globals.items[0].init.i32_const = @bitCast(i32, @intCast(u32, memory_ptr));
}

fn resetState(self: *Wasm) void {
    for (self.segment_info.items) |*segment_info| {
        self.base.allocator.free(segment_info.name);
    }
    var decl_it = self.decls.keyIterator();
    while (decl_it.next()) |decl| {
        const atom = &decl.*.link.wasm;
        atom.next = null;
        atom.prev = null;
    }
    self.functions.clearRetainingCapacity();
    self.segments.clearRetainingCapacity();
    self.segment_info.clearRetainingCapacity();
    self.data_segments.clearRetainingCapacity();
    self.atoms.clearRetainingCapacity();
    self.code_section_index = null;
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

    // When we finish/error we reset the state of the linker
    // So we can rebuild the binary file on each incremental update
    defer self.resetState();
    self.setupImports();
    var decl_it = self.decls.keyIterator();
    while (decl_it.next()) |decl| {
        if (decl.*.isExtern()) continue;
        try self.parseDeclIntoAtom(decl.*);
    }

    try self.setupMemory();
    try self.allocateAtoms();
    self.mapFunctionTable();

    const file = self.base.file.?;
    const header_size = 5 + 1;

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
    const import_mem = self.base.options.import_memory;
    if (self.imports.count() != 0 or import_mem) {
        const header_offset = try reserveVecSectionHeader(file);
        const writer = file.writer();

        var it = self.imports.iterator();
        while (it.next()) |entry| {
            const import_symbol = self.symbols.items[entry.key_ptr.*];
            std.debug.assert(import_symbol.isUndefined());
            const import = entry.value_ptr.*;
            try emitImport(writer, import);
        }

        if (import_mem) {
            const mem_imp: wasm.Import = .{
                .module_name = self.host_name,
                .name = "memory",
                .kind = .{ .memory = self.memories.limits },
            };
            try emitImport(writer, mem_imp);
        }

        try writeVecSectionHeader(
            file,
            header_offset,
            .import,
            @intCast(u32, (try file.getPos()) - header_offset - header_size),
            @intCast(u32, self.imports.count() + @boolToInt(import_mem)),
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

    // Table section
    if (self.function_table.count() > 0) {
        const header_offset = try reserveVecSectionHeader(file);
        const writer = file.writer();

        try leb.writeULEB128(writer, wasm.reftype(.funcref));
        try emitLimits(writer, .{
            .min = @intCast(u32, self.function_table.count()),
            .max = null,
        });

        try writeVecSectionHeader(
            file,
            header_offset,
            .table,
            @intCast(u32, (try file.getPos()) - header_offset - header_size),
            @as(u32, 1),
        );
    }

    // Memory section
    if (!self.base.options.import_memory) {
        const header_offset = try reserveVecSectionHeader(file);
        const writer = file.writer();

        try emitLimits(writer, self.memories.limits);
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
        for (module.decl_exports.values()) |exports| {
            for (exports) |exprt| {
                // Export name length + name
                try leb.writeULEB128(writer, @intCast(u32, exprt.options.name.len));
                try writer.writeAll(exprt.options.name);

                switch (exprt.exported_decl.ty.zigTypeTag()) {
                    .Fn => {
                        const target = exprt.exported_decl.link.wasm.sym_index;
                        const target_symbol = self.symbols.items[target];
                        std.debug.assert(target_symbol.tag == .function);
                        // Type of the export
                        try writer.writeByte(wasm.externalKind(.function));
                        // Exported function index
                        try leb.writeULEB128(writer, target_symbol.index);
                    },
                    else => return error.TODOImplementNonFnDeclsForWasm,
                }

                count += 1;
            }
        }

        // export memory if size is not 0
        if (!self.base.options.import_memory) {
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

    // element section (function table)
    if (self.function_table.count() > 0) {
        const header_offset = try reserveVecSectionHeader(file);
        const writer = file.writer();

        var flags: u32 = 0x2; // Yes we have a table
        try leb.writeULEB128(writer, flags);
        try leb.writeULEB128(writer, @as(u32, 0)); // index of that table. TODO: Store synthetic symbols
        try emitInit(writer, .{ .i32_const = 0 });
        try leb.writeULEB128(writer, @as(u8, 0));
        try leb.writeULEB128(writer, @intCast(u32, self.function_table.count()));
        var symbol_it = self.function_table.keyIterator();
        while (symbol_it.next()) |symbol_index_ptr| {
            try leb.writeULEB128(writer, self.symbols.items[symbol_index_ptr.*].index);
        }

        try writeVecSectionHeader(
            file,
            header_offset,
            .element,
            @intCast(u32, (try file.getPos()) - header_offset - header_size),
            @as(u32, 1),
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
        var segment_count: u32 = 0;
        while (it.next()) |entry| {
            // do not output 'bss' section
            if (std.mem.eql(u8, entry.key_ptr.*, ".bss")) continue;
            segment_count += 1;
            const atom_index = entry.value_ptr.*;
            var atom: *Atom = self.atoms.getPtr(atom_index).?.*.getFirst();
            var segment = self.segments.items[atom_index];

            // flag and index to memory section (currently, there can only be 1 memory section in wasm)
            try leb.writeULEB128(writer, @as(u32, 0));
            // offset into data section
            try emitInit(writer, .{ .i32_const = @bitCast(i32, segment.offset) });
            try leb.writeULEB128(writer, segment.size);

            // fill in the offset table and the data segments
            var current_offset: u32 = 0;
            while (true) {
                try atom.resolveRelocs(self);

                // Pad with zeroes to ensure all segments are aligned
                if (current_offset != atom.offset) {
                    const diff = atom.offset - current_offset;
                    try writer.writeByteNTimes(0, diff);
                    current_offset += diff;
                }
                std.debug.assert(current_offset == atom.offset);
                std.debug.assert(atom.code.items.len == atom.size);
                try writer.writeAll(atom.code.items);

                current_offset += atom.size;
                if (atom.next) |next| {
                    atom = next;
                } else {
                    // also pad with zeroes when last atom to ensure
                    // segments are aligned.
                    if (current_offset != segment.size) {
                        try writer.writeByteNTimes(0, segment.size - current_offset);
                    }
                    break;
                }
            }
        }

        try writeVecSectionHeader(
            file,
            header_offset,
            .data,
            @intCast(u32, (try file.getPos()) - header_offset - header_size),
            @intCast(u32, segment_count),
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

fn emitImport(writer: anytype, import: wasm.Import) !void {
    try leb.writeULEB128(writer, @intCast(u32, import.module_name.len));
    try writer.writeAll(import.module_name);

    try leb.writeULEB128(writer, @intCast(u32, import.name.len));
    try writer.writeAll(import.name);

    try writer.writeByte(@enumToInt(import.kind));
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

fn linkWithLLD(self: *Wasm, comp: *Compilation) !void {
    const tracy = trace(@src());
    defer tracy.end();

    var arena_allocator = std.heap.ArenaAllocator.init(self.base.allocator);
    defer arena_allocator.deinit();
    const arena = arena_allocator.allocator();

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
