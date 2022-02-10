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
const lldMain = @import("../main.zig").lldMain;
const trace = @import("../tracy.zig").trace;
const build_options = @import("build_options");
const wasi_libc = @import("../wasi_libc.zig");
const Cache = @import("../Cache.zig");
const Type = @import("../type.zig").Type;
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
        return createEmpty(allocator, options);
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
    const self = try gpa.create(Wasm);
    errdefer gpa.destroy(self);
    self.* = .{
        .base = .{
            .tag = .wasm,
            .options = options,
            .file = null,
            .allocator = gpa,
        },
    };
    const use_llvm = build_options.have_llvm and options.use_llvm;
    const use_stage1 = build_options.is_stage1 and options.use_stage1;
    if (use_llvm and !use_stage1) {
        self.llvm_object = try LlvmObject.create(gpa, options);
    }
    return self;
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
        .module = module,
    };
    defer codegen.deinit();

    // generate the 'code' section for the function declaration
    codegen.genFunc() catch |err| switch (err) {
        error.CodegenFail => {
            decl.analysis = .codegen_failure;
            try module.failed_decls.put(module.gpa, decl, codegen.err_msg);
            return;
        },
        else => |e| return e,
    };
    return self.finishUpdateDecl(decl, codegen.code.items);
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

    var code_writer = std.ArrayList(u8).init(self.base.allocator);
    defer code_writer.deinit();
    var decl_gen: CodeGen.DeclGen = .{
        .gpa = self.base.allocator,
        .decl = decl,
        .symbol_index = decl.link.wasm.sym_index,
        .bin_file = self,
        .err_msg = undefined,
        .code = &code_writer,
        .module = module,
    };

    // generate the 'code' section for the function declaration
    const result = decl_gen.genDecl() catch |err| switch (err) {
        error.CodegenFail => {
            decl.analysis = .codegen_failure;
            try module.failed_decls.put(module.gpa, decl, decl_gen.err_msg);
            return;
        },
        else => |e| return e,
    };

    const code = switch (result) {
        .externally_managed => |data| data,
        .appended => code_writer.items,
    };

    return self.finishUpdateDecl(decl, code);
}

fn finishUpdateDecl(self: *Wasm, decl: *Module.Decl, code: []const u8) !void {
    if (decl.isExtern()) {
        return self.addOrUpdateImport(decl);
    }

    if (code.len == 0) return;
    const atom: *Atom = &decl.link.wasm;
    atom.size = @intCast(u32, code.len);
    atom.alignment = decl.ty.abiAlignment(self.base.options.target);
    self.symbols.items[atom.sym_index].name = decl.name;
    try atom.code.appendSlice(self.base.allocator, code);
}

/// Creates a new local symbol for a given type (and its bytes it's represented by)
/// and then append it as a 'contained' atom onto the Decl.
pub fn createLocalSymbol(self: *Wasm, decl: *Module.Decl, ty: Type) !u32 {
    assert(ty.zigTypeTag() != .Fn); // cannot create local symbols for functions
    var symbol: Symbol = .{
        .name = "unnamed_local",
        .flags = 0,
        .tag = .data,
        .index = undefined,
    };
    symbol.setFlag(.WASM_SYM_BINDING_LOCAL);
    symbol.setFlag(.WASM_SYM_VISIBILITY_HIDDEN);

    var atom = Atom.empty;
    atom.alignment = ty.abiAlignment(self.base.options.target);
    try self.symbols.ensureUnusedCapacity(self.base.allocator, 1);

    if (self.symbols_free_list.popOrNull()) |index| {
        atom.sym_index = index;
        self.symbols.items[index] = symbol;
    } else {
        atom.sym_index = @intCast(u32, self.symbols.items.len);
        self.symbols.appendAssumeCapacity(symbol);
    }

    try decl.link.wasm.locals.append(self.base.allocator, atom);
    return atom.sym_index;
}

pub fn updateLocalSymbolCode(self: *Wasm, decl: *Module.Decl, symbol_index: u32, code: []const u8) !void {
    const atom = decl.link.wasm.symbolAtom(symbol_index);
    atom.size = @intCast(u32, code.len);
    try atom.code.appendSlice(self.base.allocator, code);
}

/// For a given decl, find the given symbol index's atom, and create a relocation for the type.
/// Returns the given pointer address
pub fn getDeclVAddr(
    self: *Wasm,
    decl: *Module.Decl,
    ty: Type,
    symbol_index: u32,
    target_symbol_index: u32,
    offset: u32,
    addend: u32,
) !u32 {
    const atom = decl.link.wasm.symbolAtom(symbol_index);
    const is_wasm32 = self.base.options.target.cpu.arch == .wasm32;
    if (ty.zigTypeTag() == .Fn) {
        std.debug.assert(addend == 0); // addend not allowed for function relocations
        // We found a function pointer, so add it to our table,
        // as function pointers are not allowed to be stored inside the data section.
        // They are instead stored in a function table which are called by index.
        try self.addTableFunction(target_symbol_index);
        try atom.relocs.append(self.base.allocator, .{
            .index = target_symbol_index,
            .offset = offset,
            .relocation_type = if (is_wasm32) .R_WASM_TABLE_INDEX_I32 else .R_WASM_TABLE_INDEX_I64,
        });
    } else {
        try atom.relocs.append(self.base.allocator, .{
            .index = target_symbol_index,
            .offset = offset,
            .relocation_type = if (is_wasm32) .R_WASM_MEMORY_ADDR_I32 else .R_WASM_MEMORY_ADDR_I64,
            .addend = addend,
        });
    }
    // we do not know the final address at this point,
    // as atom allocation will determine the address and relocations
    // will calculate and rewrite this. Therefore, we simply return the symbol index
    // that was targeted.
    return target_symbol_index;
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
    _ = self.decls.remove(decl);
    self.symbols.items[atom.sym_index].tag = .dead; // to ensure it does not end in the names section
    for (atom.locals.items) |local_atom| {
        self.symbols.items[local_atom.sym_index].tag = .dead; // also for any local symbol
        self.symbols_free_list.append(self.base.allocator, local_atom.sym_index) catch {};
    }

    if (decl.isExtern()) {
        const import = self.imports.fetchRemove(atom.sym_index).?.value;
        switch (import.kind) {
            .function => self.imported_functions_count -= 1,
            else => unreachable,
        }
    }

    atom.deinit(self.base.allocator);
}

/// Appends a new entry to the indirect function table
pub fn addTableFunction(self: *Wasm, symbol_index: u32) !void {
    const index = @intCast(u32, self.function_table.count());
    try self.function_table.put(self.base.allocator, symbol_index, index);
}

fn mapFunctionTable(self: *Wasm) void {
    var it = self.function_table.valueIterator();
    var index: u32 = 1;
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
            const module_name = if (decl.getExternFn().?.lib_name) |lib_name| blk: {
                break :blk std.mem.sliceTo(lib_name, 0);
            } else self.host_name;
            if (!gop.found_existing) {
                self.imported_functions_count += 1;
                gop.value_ptr.* = .{
                    .module_name = module_name,
                    .name = std.mem.span(symbol.name),
                    .kind = .{ .function = decl.fn_link.wasm.type_index },
                };
            }
        },
        else => @panic("TODO: Implement undefined symbols for non-function declarations"),
    }
}

const Kind = union(enum) {
    data: void,
    function: FnData,
};

/// Parses an Atom and inserts its metadata into the corresponding sections.
fn parseAtom(self: *Wasm, atom: *Atom, kind: Kind) !void {
    const symbol: *Symbol = &self.symbols.items[atom.sym_index];
    const final_index: u32 = switch (kind) {
        .function => |fn_data| result: {
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
        .data => result: {
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
    const stack_alignment = 16; // wasm's stack alignment as specified by tool-convention
    // Always place the stack at the start by default
    // unless the user specified the global-base flag
    var place_stack_first = true;
    var memory_ptr: u64 = if (self.base.options.global_base) |base| blk: {
        place_stack_first = false;
        break :blk base;
    } else 0;

    if (place_stack_first) {
        memory_ptr = std.mem.alignForwardGeneric(u64, memory_ptr, stack_alignment);
        memory_ptr += stack_size;
        // We always put the stack pointer global at index 0
        self.globals.items[0].init.i32_const = @bitCast(i32, @intCast(u32, memory_ptr));
    }

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

    if (!place_stack_first) {
        memory_ptr = std.mem.alignForwardGeneric(u64, memory_ptr, stack_alignment);
        memory_ptr += stack_size;
        self.globals.items[0].init.i32_const = @bitCast(i32, @intCast(u32, memory_ptr));
    }

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
    if (self.base.options.emit == null) {
        if (build_options.have_llvm) {
            if (self.llvm_object) |llvm_object| {
                return try llvm_object.flushModule(comp);
            }
        }
        return;
    }
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
        const atom = &decl.*.link.wasm;
        if (decl.*.ty.zigTypeTag() == .Fn) {
            try self.parseAtom(atom, .{ .function = decl.*.fn_link.wasm });
        } else {
            try self.parseAtom(atom, .data);
        }

        // also parse atoms for a decl's locals
        for (atom.locals.items) |*local_atom| {
            try self.parseAtom(local_atom, .data);
        }
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
    const import_memory = self.base.options.import_memory;
    const import_table = self.base.options.import_table;
    if (self.imports.count() != 0 or import_memory or import_table) {
        const header_offset = try reserveVecSectionHeader(file);
        const writer = file.writer();

        // import table is always first table so emit that first
        if (import_table) {
            const table_imp: wasm.Import = .{
                .module_name = self.host_name,
                .name = "__indirect_function_table",
                .kind = .{
                    .table = .{
                        .limits = .{
                            .min = @intCast(u32, self.function_table.count()),
                            .max = null,
                        },
                        .reftype = .funcref,
                    },
                },
            };
            try emitImport(writer, table_imp);
        }

        var it = self.imports.iterator();
        while (it.next()) |entry| {
            const import_symbol = self.symbols.items[entry.key_ptr.*];
            std.debug.assert(import_symbol.isUndefined());
            const import = entry.value_ptr.*;
            try emitImport(writer, import);
        }

        if (import_memory) {
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
            @intCast(u32, self.imports.count() + @boolToInt(import_memory) + @boolToInt(import_table)),
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
    const export_table = self.base.options.export_table;
    if (!import_table) {
        const header_offset = try reserveVecSectionHeader(file);
        const writer = file.writer();

        try leb.writeULEB128(writer, wasm.reftype(.funcref));
        try emitLimits(writer, .{
            .min = @intCast(u32, self.function_table.count()) + 1,
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
        if (!import_memory) {
            try leb.writeULEB128(writer, @intCast(u32, "memory".len));
            try writer.writeAll("memory");
            try writer.writeByte(wasm.externalKind(.memory));
            try leb.writeULEB128(writer, @as(u32, 0)); // only 1 memory 'object' can exist
            count += 1;
        }

        if (export_table) {
            try leb.writeULEB128(writer, @intCast(u32, "__indirect_function_table".len));
            try writer.writeAll("__indirect_function_table");
            try writer.writeByte(wasm.externalKind(.table));
            try leb.writeULEB128(writer, @as(u32, 0)); // function table is always the first table
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
        try emitInit(writer, .{ .i32_const = 1 }); // We start at index 1, so unresolved function pointers are invalid
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

    // Custom section "name" which contains symbol names
    {
        const Name = struct {
            index: u32,
            name: []const u8,

            fn lessThan(context: void, lhs: @This(), rhs: @This()) bool {
                _ = context;
                return lhs.index < rhs.index;
            }
        };

        var funcs = try std.ArrayList(Name).initCapacity(self.base.allocator, self.functions.items.len + self.imported_functions_count);
        defer funcs.deinit();
        var globals = try std.ArrayList(Name).initCapacity(self.base.allocator, self.globals.items.len);
        defer globals.deinit();
        var segments = try std.ArrayList(Name).initCapacity(self.base.allocator, self.data_segments.count());
        defer segments.deinit();

        for (self.symbols.items) |symbol| {
            switch (symbol.tag) {
                .function => funcs.appendAssumeCapacity(.{ .index = symbol.index, .name = std.mem.sliceTo(symbol.name, 0) }),
                .global => globals.appendAssumeCapacity(.{ .index = symbol.index, .name = std.mem.sliceTo(symbol.name, 0) }),
                else => {},
            }
        }
        // data segments are already 'ordered'
        for (self.data_segments.keys()) |key, index| {
            segments.appendAssumeCapacity(.{ .index = @intCast(u32, index), .name = key });
        }

        std.sort.sort(Name, funcs.items, {}, Name.lessThan);
        std.sort.sort(Name, globals.items, {}, Name.lessThan);

        const header_offset = try reserveCustomSectionHeader(file);
        const writer = file.writer();
        try leb.writeULEB128(writer, @intCast(u32, "name".len));
        try writer.writeAll("name");

        try self.emitNameSubsection(.function, funcs.items, writer);
        try self.emitNameSubsection(.global, globals.items, writer);
        try self.emitNameSubsection(.data_segment, segments.items, writer);

        try writeCustomSectionHeader(
            file,
            header_offset,
            @intCast(u32, (try file.getPos()) - header_offset - header_size),
        );
    }
}

fn emitNameSubsection(self: *Wasm, section_id: std.wasm.NameSubsection, names: anytype, writer: anytype) !void {
    // We must emit subsection size, so first write to a temporary list
    var section_list = std.ArrayList(u8).init(self.base.allocator);
    defer section_list.deinit();
    const sub_writer = section_list.writer();

    try leb.writeULEB128(sub_writer, @intCast(u32, names.len));
    for (names) |name| {
        try leb.writeULEB128(sub_writer, name.index);
        try leb.writeULEB128(sub_writer, @intCast(u32, name.name.len));
        try sub_writer.writeAll(name.name);
    }

    // From now, write to the actual writer
    try leb.writeULEB128(writer, @enumToInt(section_id));
    try leb.writeULEB128(writer, @intCast(u32, section_list.items.len));
    try writer.writeAll(section_list.items);
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
    const full_out_path = try directory.join(arena, &[_][]const u8{self.base.options.emit.?.sub_path});

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
            switch (self.base.options.cache_mode) {
                .incremental => break :blk try module.zig_cache_artifact_directory.join(
                    arena,
                    &[_][]const u8{obj_basename},
                ),
                .whole => break :blk try fs.path.join(arena, &.{
                    fs.path.dirname(full_out_path).?, obj_basename,
                }),
            }
        }

        try self.flushModule(comp);

        if (fs.path.dirname(full_out_path)) |dirname| {
            break :blk try fs.path.join(arena, &.{ dirname, self.base.intermediary_basename.? });
        } else {
            break :blk self.base.intermediary_basename.?;
        }
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

        comptime assert(Compilation.link_hash_implementation_version == 2);

        for (self.base.options.objects) |obj| {
            _ = try man.addFile(obj.path, null);
            man.hash.add(obj.must_link);
        }
        for (comp.c_object_table.keys()) |key| {
            _ = try man.addFile(key.status.success.object_path, null);
        }
        try man.addOptionalFile(module_obj_path);
        try man.addOptionalFile(compiler_rt_path);
        man.hash.addOptionalBytes(self.base.options.entry);
        man.hash.addOptional(self.base.options.stack_size_override);
        man.hash.add(self.base.options.import_memory);
        man.hash.add(self.base.options.import_table);
        man.hash.add(self.base.options.export_table);
        man.hash.addOptional(self.base.options.initial_memory);
        man.hash.addOptional(self.base.options.max_memory);
        man.hash.addOptional(self.base.options.global_base);
        man.hash.add(self.base.options.export_symbol_names.len);
        // strip does not need to go into the linker hash because it is part of the hash namespace
        for (self.base.options.export_symbol_names) |symbol_name| {
            man.hash.addBytes(symbol_name);
        }

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

    if (is_obj) {
        // LLD's WASM driver does not support the equivalent of `-r` so we do a simple file copy
        // here. TODO: think carefully about how we can avoid this redundant operation when doing
        // build-obj. See also the corresponding TODO in linkAsArchive.
        const the_object_path = blk: {
            if (self.base.options.objects.len != 0)
                break :blk self.base.options.objects[0].path;

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

        if (self.base.options.import_table) {
            assert(!self.base.options.export_table);
            try argv.append("--import-table");
        }

        if (self.base.options.export_table) {
            assert(!self.base.options.import_table);
            try argv.append("--export-table");
        }

        if (self.base.options.strip) {
            try argv.append("-s");
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
        } else {
            // We prepend it by default, so when a stack overflow happens the runtime will trap correctly,
            // rather than silently overwrite all global declarations. See https://github.com/ziglang/zig/issues/4496
            //
            // The user can overwrite this behavior by setting the global-base
            try argv.append("--stack-first");
        }

        var auto_export_symbols = true;
        // Users are allowed to specify which symbols they want to export to the wasm host.
        for (self.base.options.export_symbol_names) |symbol_name| {
            const arg = try std.fmt.allocPrint(arena, "--export={s}", .{symbol_name});
            try argv.append(arg);
            auto_export_symbols = false;
        }

        if (self.base.options.rdynamic) {
            try argv.append("--export-dynamic");
            auto_export_symbols = false;
        }

        if (auto_export_symbols) {
            if (self.base.options.module) |module| {
                // when we use stage1, we use the exports that stage1 provided us.
                // For stage2, we can directly retrieve them from the module.
                const use_stage1 = build_options.is_stage1 and self.base.options.use_stage1;
                if (use_stage1) {
                    for (comp.export_symbol_names.items) |symbol_name| {
                        try argv.append(try std.fmt.allocPrint(arena, "--export={s}", .{symbol_name}));
                    }
                } else {
                    const skip_export_non_fn = target.os.tag == .wasi and
                        self.base.options.wasi_exec_model == .command;
                    for (module.decl_exports.values()) |exports| {
                        for (exports) |exprt| {
                            if (skip_export_non_fn and exprt.exported_decl.ty.zigTypeTag() != .Fn) {
                                // skip exporting symbols when we're building a WASI command
                                // and the symbol is not a function
                                continue;
                            }
                            const symbol_name = exprt.exported_decl.name;
                            const arg = try std.fmt.allocPrint(arena, "--export={s}", .{symbol_name});
                            try argv.append(arg);
                        }
                    }
                }
            }
        }

        if (self.base.options.entry) |entry| {
            try argv.append("--entry");
            try argv.append(entry);
        }

        if (self.base.options.output_mode == .Exe) {
            // Increase the default stack size to a more reasonable value of 1MB instead of
            // the default of 1 Wasm page being 64KB, unless overridden by the user.
            try argv.append("-z");
            const stack_size = self.base.options.stack_size_override orelse 1048576;
            const arg = try std.fmt.allocPrint(arena, "stack-size={d}", .{stack_size});
            try argv.append(arg);

            if (self.base.options.wasi_exec_model == .reactor) {
                // Reactor execution model does not have _start so lld doesn't look for it.
                try argv.append("--no-entry");
            }
        } else {
            if (self.base.options.stack_size_override) |stack_size| {
                try argv.append("-z");
                const arg = try std.fmt.allocPrint(arena, "stack-size={d}", .{stack_size});
                try argv.append(arg);
            }
            try argv.append("--no-entry"); // So lld doesn't look for _start.
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
        var whole_archive = false;
        for (self.base.options.objects) |obj| {
            if (obj.must_link and !whole_archive) {
                try argv.append("-whole-archive");
                whole_archive = true;
            } else if (!obj.must_link and whole_archive) {
                try argv.append("-no-whole-archive");
                whole_archive = false;
            }
            try argv.append(obj.path);
        }
        if (whole_archive) {
            try argv.append("-no-whole-archive");
            whole_archive = false;
        }

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

        if (std.process.can_spawn) {
            // If possible, we run LLD as a child process because it does not always
            // behave properly as a library, unfortunately.
            // https://github.com/ziglang/zig/issues/3825
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
                            std.process.exit(code);
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
        } else {
            const exit_code = try lldMain(arena, argv.items, false);
            if (exit_code != 0) {
                if (comp.clang_passthrough_mode) {
                    std.process.exit(exit_code);
                } else {
                    return error.LLDReportedFailure;
                }
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

fn reserveCustomSectionHeader(file: fs.File) !u64 {
    // unlike regular section, we don't emit the count
    const header_size = 1 + 5;
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

fn writeCustomSectionHeader(file: fs.File, offset: u64, size: u32) !void {
    var buf: [1 + 5]u8 = undefined;
    buf[0] = 0; // 0 = 'custom' section
    leb.writeUnsignedFixed(5, buf[1..6], size);
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
