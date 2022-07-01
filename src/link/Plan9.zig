//! This implementation does all the linking work in flush(). A future improvement
//! would be to add incremental linking in a similar way as ELF does.

const Plan9 = @This();
const link = @import("../link.zig");
const Module = @import("../Module.zig");
const Compilation = @import("../Compilation.zig");
const aout = @import("Plan9/aout.zig");
const codegen = @import("../codegen.zig");
const trace = @import("../tracy.zig").trace;
const File = link.File;
const build_options = @import("build_options");
const Air = @import("../Air.zig");
const Liveness = @import("../Liveness.zig");
const TypedValue = @import("../TypedValue.zig");

const std = @import("std");
const builtin = @import("builtin");
const mem = std.mem;
const Allocator = std.mem.Allocator;
const log = std.log.scoped(.link);
const assert = std.debug.assert;

const FnDeclOutput = struct {
    code: []const u8,
    /// this might have to be modified in the linker, so thats why its mutable
    lineinfo: []u8,
    start_line: u32,
    end_line: u32,
};

base: link.File,
sixtyfour_bit: bool,
error_flags: File.ErrorFlags = File.ErrorFlags{},
bases: Bases,

/// A symbol's value is just casted down when compiling
/// for a 32 bit target.
/// Does not represent the order or amount of symbols in the file
/// it is just useful for storing symbols. Some other symbols are in
/// file_segments.
syms: std.ArrayListUnmanaged(aout.Sym) = .{},

/// The plan9 a.out format requires segments of
/// filenames to be deduplicated, so we use this map to
/// de duplicate it. The value is the value of the path
/// component
file_segments: std.StringArrayHashMapUnmanaged(u16) = .{},
/// The value of a 'f' symbol increments by 1 every time, so that no 2 'f'
/// symbols have the same value.
file_segments_i: u16 = 1,

path_arena: std.heap.ArenaAllocator,

/// maps a file scope to a hash map of decl to codegen output
/// this is useful for line debuginfo, since it makes sense to sort by file
/// The debugger looks for the first file (aout.Sym.Type.z) preceeding the text symbol
/// of the function to know what file it came from.
/// If we group the decls by file, it makes it really easy to do this (put the symbol in the correct place)
fn_decl_table: std.AutoArrayHashMapUnmanaged(
    *Module.File,
    struct { sym_index: u32, functions: std.AutoArrayHashMapUnmanaged(Module.Decl.Index, FnDeclOutput) = .{} },
) = .{},
data_decl_table: std.AutoArrayHashMapUnmanaged(Module.Decl.Index, []const u8) = .{},

hdr: aout.ExecHdr = undefined,

magic: u32,

entry_val: ?u64 = null,

got_len: usize = 0,
// A list of all the free got indexes, so when making a new decl
// don't make a new one, just use one from here.
got_index_free_list: std.ArrayListUnmanaged(usize) = .{},

syms_index_free_list: std.ArrayListUnmanaged(usize) = .{},

const Bases = struct {
    text: u64,
    /// the Global Offset Table starts at the beginning of the data section
    data: u64,
};

fn getAddr(self: Plan9, addr: u64, t: aout.Sym.Type) u64 {
    return addr + switch (t) {
        .T, .t, .l, .L => self.bases.text,
        .D, .d, .B, .b => self.bases.data,
        else => unreachable,
    };
}

fn getSymAddr(self: Plan9, s: aout.Sym) u64 {
    return self.getAddr(s.value, s.type);
}

pub const DeclBlock = struct {
    type: aout.Sym.Type,
    /// offset in the text or data sects
    offset: ?u64,
    /// offset into syms
    sym_index: ?usize,
    /// offset into got
    got_index: ?usize,
    pub const empty = DeclBlock{
        .type = .t,
        .offset = null,
        .sym_index = null,
        .got_index = null,
    };
};

pub fn defaultBaseAddrs(arch: std.Target.Cpu.Arch) Bases {
    return switch (arch) {
        .x86_64 => .{
            // header size => 40 => 0x28
            .text = 0x200028,
            .data = 0x400000,
        },
        .i386 => .{
            // header size => 32 => 0x20
            .text = 0x200020,
            .data = 0x400000,
        },
        .aarch64 => .{
            // header size => 40 => 0x28
            .text = 0x10028,
            .data = 0x20000,
        },
        else => std.debug.panic("find default base address for {}", .{arch}),
    };
}

pub const PtrWidth = enum { p32, p64 };

pub fn createEmpty(gpa: Allocator, options: link.Options) !*Plan9 {
    if (options.use_llvm)
        return error.LLVMBackendDoesNotSupportPlan9;
    const sixtyfour_bit: bool = switch (options.target.cpu.arch.ptrBitWidth()) {
        0...32 => false,
        33...64 => true,
        else => return error.UnsupportedP9Architecture,
    };

    var arena_allocator = std.heap.ArenaAllocator.init(gpa);

    const self = try gpa.create(Plan9);
    self.* = .{
        .path_arena = arena_allocator,
        .base = .{
            .tag = .plan9,
            .options = options,
            .allocator = gpa,
            .file = null,
        },
        .sixtyfour_bit = sixtyfour_bit,
        .bases = undefined,
        .magic = try aout.magicFromArch(self.base.options.target.cpu.arch),
    };
    // a / will always be in a file path
    try self.file_segments.put(self.base.allocator, "/", 1);
    return self;
}

fn putFn(self: *Plan9, decl_index: Module.Decl.Index, out: FnDeclOutput) !void {
    const gpa = self.base.allocator;
    const mod = self.base.options.module.?;
    const decl = mod.declPtr(decl_index);
    const fn_map_res = try self.fn_decl_table.getOrPut(gpa, decl.getFileScope());
    if (fn_map_res.found_existing) {
        try fn_map_res.value_ptr.functions.put(gpa, decl_index, out);
    } else {
        const file = decl.getFileScope();
        const arena = self.path_arena.allocator();
        // each file gets a symbol
        fn_map_res.value_ptr.* = .{
            .sym_index = blk: {
                try self.syms.append(gpa, undefined);
                try self.syms.append(gpa, undefined);
                break :blk @intCast(u32, self.syms.items.len - 1);
            },
        };
        try fn_map_res.value_ptr.functions.put(gpa, decl_index, out);

        var a = std.ArrayList(u8).init(arena);
        errdefer a.deinit();
        // every 'z' starts with 0
        try a.append(0);
        // path component value of '/'
        try a.writer().writeIntBig(u16, 1);

        // getting the full file path
        var buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
        const dir = file.pkg.root_src_directory.path orelse try std.os.getcwd(&buf);
        const sub_path = try std.fs.path.join(arena, &.{ dir, file.sub_file_path });
        try self.addPathComponents(sub_path, &a);

        // null terminate
        try a.append(0);
        const final = a.toOwnedSlice();
        self.syms.items[fn_map_res.value_ptr.sym_index - 1] = .{
            .type = .z,
            .value = 1,
            .name = final,
        };
        self.syms.items[fn_map_res.value_ptr.sym_index] = .{
            .type = .z,
            // just put a giant number, no source file will have this many newlines
            .value = std.math.maxInt(u31),
            .name = &.{ 0, 0 },
        };
    }
}

fn addPathComponents(self: *Plan9, path: []const u8, a: *std.ArrayList(u8)) !void {
    const sep = std.fs.path.sep;
    var it = std.mem.tokenize(u8, path, &.{sep});
    while (it.next()) |component| {
        if (self.file_segments.get(component)) |num| {
            try a.writer().writeIntBig(u16, num);
        } else {
            self.file_segments_i += 1;
            try self.file_segments.put(self.base.allocator, component, self.file_segments_i);
            try a.writer().writeIntBig(u16, self.file_segments_i);
        }
    }
}

pub fn updateFunc(self: *Plan9, module: *Module, func: *Module.Fn, air: Air, liveness: Liveness) !void {
    if (build_options.skip_non_native and builtin.object_format != .plan9) {
        @panic("Attempted to compile for object format that was disabled by build configuration");
    }

    const decl_index = func.owner_decl;
    const decl = module.declPtr(decl_index);

    try self.seeDecl(decl_index);
    log.debug("codegen decl {*} ({s})", .{ decl, decl.name });

    var code_buffer = std.ArrayList(u8).init(self.base.allocator);
    defer code_buffer.deinit();
    var dbg_line_buffer = std.ArrayList(u8).init(self.base.allocator);
    defer dbg_line_buffer.deinit();
    var start_line: ?u32 = null;
    var end_line: u32 = undefined;
    var pcop_change_index: ?u32 = null;

    const res = try codegen.generateFunction(
        &self.base,
        decl.srcLoc(),
        func,
        air,
        liveness,
        &code_buffer,
        .{
            .plan9 = .{
                .dbg_line = &dbg_line_buffer,
                .end_line = &end_line,
                .start_line = &start_line,
                .pcop_change_index = &pcop_change_index,
            },
        },
    );
    const code = switch (res) {
        .appended => code_buffer.toOwnedSlice(),
        .fail => |em| {
            decl.analysis = .codegen_failure;
            try module.failed_decls.put(module.gpa, decl_index, em);
            return;
        },
    };
    const out: FnDeclOutput = .{
        .code = code,
        .lineinfo = dbg_line_buffer.toOwnedSlice(),
        .start_line = start_line.?,
        .end_line = end_line,
    };
    try self.putFn(decl_index, out);
    return self.updateFinish(decl);
}

pub fn lowerUnnamedConst(self: *Plan9, tv: TypedValue, decl_index: Module.Decl.Index) !u32 {
    _ = self;
    _ = tv;
    _ = decl_index;
    log.debug("TODO lowerUnnamedConst for Plan9", .{});
    return error.AnalysisFail;
}

pub fn updateDecl(self: *Plan9, module: *Module, decl_index: Module.Decl.Index) !void {
    const decl = module.declPtr(decl_index);

    if (decl.val.tag() == .extern_fn) {
        return; // TODO Should we do more when front-end analyzed extern decl?
    }
    if (decl.val.castTag(.variable)) |payload| {
        const variable = payload.data;
        if (variable.is_extern) {
            return; // TODO Should we do more when front-end analyzed extern decl?
        }
    }

    try self.seeDecl(decl_index);

    log.debug("codegen decl {*} ({s})", .{ decl, decl.name });

    var code_buffer = std.ArrayList(u8).init(self.base.allocator);
    defer code_buffer.deinit();
    const decl_val = if (decl.val.castTag(.variable)) |payload| payload.data.init else decl.val;
    // TODO we need the symbol index for symbol in the table of locals for the containing atom
    const sym_index = decl.link.plan9.sym_index orelse 0;
    const res = try codegen.generateSymbol(&self.base, decl.srcLoc(), .{
        .ty = decl.ty,
        .val = decl_val,
    }, &code_buffer, .{ .none = {} }, .{
        .parent_atom_index = @intCast(u32, sym_index),
    });
    const code = switch (res) {
        .externally_managed => |x| x,
        .appended => code_buffer.items,
        .fail => |em| {
            decl.analysis = .codegen_failure;
            try module.failed_decls.put(module.gpa, decl_index, em);
            return;
        },
    };
    var duped_code = try self.base.allocator.dupe(u8, code);
    errdefer self.base.allocator.free(duped_code);
    try self.data_decl_table.put(self.base.allocator, decl_index, duped_code);
    return self.updateFinish(decl);
}
/// called at the end of update{Decl,Func}
fn updateFinish(self: *Plan9, decl: *Module.Decl) !void {
    const is_fn = (decl.ty.zigTypeTag() == .Fn);
    log.debug("update the symbol table and got for decl {*} ({s})", .{ decl, decl.name });
    const sym_t: aout.Sym.Type = if (is_fn) .t else .d;
    // write the internal linker metadata
    decl.link.plan9.type = sym_t;
    // write the symbol
    // we already have the got index because that got allocated in allocateDeclIndexes
    const sym: aout.Sym = .{
        .value = undefined, // the value of stuff gets filled in in flushModule
        .type = decl.link.plan9.type,
        .name = mem.span(decl.name),
    };

    if (decl.link.plan9.sym_index) |s| {
        self.syms.items[s] = sym;
    } else {
        if (self.syms_index_free_list.popOrNull()) |i| {
            decl.link.plan9.sym_index = i;
        } else {
            try self.syms.append(self.base.allocator, sym);
            decl.link.plan9.sym_index = self.syms.items.len - 1;
        }
    }
}

pub fn flush(self: *Plan9, comp: *Compilation, prog_node: *std.Progress.Node) !void {
    assert(!self.base.options.use_lld);

    switch (self.base.options.effectiveOutputMode()) {
        .Exe => {},
        // plan9 object files are totally different
        .Obj => return error.TODOImplementPlan9Objs,
        .Lib => return error.TODOImplementWritingLibFiles,
    }
    return self.flushModule(comp, prog_node);
}

pub fn changeLine(l: *std.ArrayList(u8), delta_line: i32) !void {
    if (delta_line > 0 and delta_line < 65) {
        const toappend = @intCast(u8, delta_line);
        try l.append(toappend);
    } else if (delta_line < 0 and delta_line > -65) {
        const toadd: u8 = @intCast(u8, -delta_line + 64);
        try l.append(toadd);
    } else if (delta_line != 0) {
        try l.append(0);
        try l.writer().writeIntBig(i32, delta_line);
    }
}

fn declCount(self: *Plan9) usize {
    var fn_decl_count: usize = 0;
    var itf_files = self.fn_decl_table.iterator();
    while (itf_files.next()) |ent| {
        // get the submap
        var submap = ent.value_ptr.functions;
        fn_decl_count += submap.count();
    }
    return self.data_decl_table.count() + fn_decl_count;
}

pub fn flushModule(self: *Plan9, comp: *Compilation, prog_node: *std.Progress.Node) !void {
    if (build_options.skip_non_native and builtin.object_format != .plan9) {
        @panic("Attempted to compile for object format that was disabled by build configuration");
    }

    _ = comp;
    const tracy = trace(@src());
    defer tracy.end();

    var sub_prog_node = prog_node.start("Flush Module", 0);
    sub_prog_node.activate();
    defer sub_prog_node.end();

    log.debug("flushModule", .{});

    defer assert(self.hdr.entry != 0x0);

    const mod = self.base.options.module orelse return error.LinkingWithoutZigSourceUnimplemented;

    assert(self.got_len == self.declCount() + self.got_index_free_list.items.len);
    const got_size = self.got_len * if (!self.sixtyfour_bit) @as(u32, 4) else 8;
    var got_table = try self.base.allocator.alloc(u8, got_size);
    defer self.base.allocator.free(got_table);

    // + 4 for header, got, symbols, linecountinfo
    var iovecs = try self.base.allocator.alloc(std.os.iovec_const, self.declCount() + 4);
    defer self.base.allocator.free(iovecs);

    const file = self.base.file.?;

    var hdr_buf: [40]u8 = undefined;
    // account for the fat header
    const hdr_size = if (self.sixtyfour_bit) @as(usize, 40) else 32;
    const hdr_slice: []u8 = hdr_buf[0..hdr_size];
    var foff = hdr_size;
    iovecs[0] = .{ .iov_base = hdr_slice.ptr, .iov_len = hdr_slice.len };
    var iovecs_i: usize = 1;
    var text_i: u64 = 0;

    var linecountinfo = std.ArrayList(u8).init(self.base.allocator);
    defer linecountinfo.deinit();
    // text
    {
        var linecount: i64 = -1;
        var it_file = self.fn_decl_table.iterator();
        while (it_file.next()) |fentry| {
            var it = fentry.value_ptr.functions.iterator();
            while (it.next()) |entry| {
                const decl_index = entry.key_ptr.*;
                const decl = mod.declPtr(decl_index);
                const out = entry.value_ptr.*;
                log.debug("write text decl {*} ({s}), lines {d} to {d}", .{ decl, decl.name, out.start_line + 1, out.end_line });
                {
                    // connect the previous decl to the next
                    const delta_line = @intCast(i32, out.start_line) - @intCast(i32, linecount);

                    try changeLine(&linecountinfo, delta_line);
                    // TODO change the pc too (maybe?)

                    // write out the actual info that was generated in codegen now
                    try linecountinfo.appendSlice(out.lineinfo);
                    linecount = out.end_line;
                }
                foff += out.code.len;
                iovecs[iovecs_i] = .{ .iov_base = out.code.ptr, .iov_len = out.code.len };
                iovecs_i += 1;
                const off = self.getAddr(text_i, .t);
                text_i += out.code.len;
                decl.link.plan9.offset = off;
                if (!self.sixtyfour_bit) {
                    mem.writeIntNative(u32, got_table[decl.link.plan9.got_index.? * 4 ..][0..4], @intCast(u32, off));
                    mem.writeInt(u32, got_table[decl.link.plan9.got_index.? * 4 ..][0..4], @intCast(u32, off), self.base.options.target.cpu.arch.endian());
                } else {
                    mem.writeInt(u64, got_table[decl.link.plan9.got_index.? * 8 ..][0..8], off, self.base.options.target.cpu.arch.endian());
                }
                self.syms.items[decl.link.plan9.sym_index.?].value = off;
                if (mod.decl_exports.get(decl_index)) |exports| {
                    try self.addDeclExports(mod, decl, exports);
                }
            }
        }
        if (linecountinfo.items.len & 1 == 1) {
            // just a nop to make it even, the plan9 linker does this
            try linecountinfo.append(129);
        }
        // etext symbol
        self.syms.items[2].value = self.getAddr(text_i, .t);
    }
    // global offset table is in data
    iovecs[iovecs_i] = .{ .iov_base = got_table.ptr, .iov_len = got_table.len };
    iovecs_i += 1;
    // data
    var data_i: u64 = got_size;
    {
        var it = self.data_decl_table.iterator();
        while (it.next()) |entry| {
            const decl_index = entry.key_ptr.*;
            const decl = mod.declPtr(decl_index);
            const code = entry.value_ptr.*;
            log.debug("write data decl {*} ({s})", .{ decl, decl.name });

            foff += code.len;
            iovecs[iovecs_i] = .{ .iov_base = code.ptr, .iov_len = code.len };
            iovecs_i += 1;
            const off = self.getAddr(data_i, .d);
            data_i += code.len;
            decl.link.plan9.offset = off;
            if (!self.sixtyfour_bit) {
                mem.writeInt(u32, got_table[decl.link.plan9.got_index.? * 4 ..][0..4], @intCast(u32, off), self.base.options.target.cpu.arch.endian());
            } else {
                mem.writeInt(u64, got_table[decl.link.plan9.got_index.? * 8 ..][0..8], off, self.base.options.target.cpu.arch.endian());
            }
            self.syms.items[decl.link.plan9.sym_index.?].value = off;
            if (mod.decl_exports.get(decl_index)) |exports| {
                try self.addDeclExports(mod, decl, exports);
            }
        }
        // edata symbol
        self.syms.items[0].value = self.getAddr(data_i, .b);
    }
    // edata
    self.syms.items[1].value = self.getAddr(0x0, .b);
    var sym_buf = std.ArrayList(u8).init(self.base.allocator);
    try self.writeSyms(&sym_buf);
    const syms = sym_buf.toOwnedSlice();
    defer self.base.allocator.free(syms);
    assert(2 + self.declCount() == iovecs_i); // we didn't write all the decls
    iovecs[iovecs_i] = .{ .iov_base = syms.ptr, .iov_len = syms.len };
    iovecs_i += 1;
    iovecs[iovecs_i] = .{ .iov_base = linecountinfo.items.ptr, .iov_len = linecountinfo.items.len };
    iovecs_i += 1;
    // generate the header
    self.hdr = .{
        .magic = self.magic,
        .text = @intCast(u32, text_i),
        .data = @intCast(u32, data_i),
        .syms = @intCast(u32, syms.len),
        .bss = 0,
        .spsz = 0,
        .pcsz = @intCast(u32, linecountinfo.items.len),
        .entry = @intCast(u32, self.entry_val.?),
    };
    std.mem.copy(u8, hdr_slice, self.hdr.toU8s()[0..hdr_size]);
    // write the fat header for 64 bit entry points
    if (self.sixtyfour_bit) {
        mem.writeIntSliceBig(u64, hdr_buf[32..40], self.entry_val.?);
    }
    // write it all!
    try file.pwritevAll(iovecs, 0);
}
fn addDeclExports(
    self: *Plan9,
    module: *Module,
    decl: *Module.Decl,
    exports: []const *Module.Export,
) !void {
    for (exports) |exp| {
        // plan9 does not support custom sections
        if (exp.options.section) |section_name| {
            if (!mem.eql(u8, section_name, ".text") or !mem.eql(u8, section_name, ".data")) {
                try module.failed_exports.put(module.gpa, exp, try Module.ErrorMsg.create(self.base.allocator, decl.srcLoc(), "plan9 does not support extra sections", .{}));
                break;
            }
        }
        const sym = .{
            .value = decl.link.plan9.offset.?,
            .type = decl.link.plan9.type.toGlobal(),
            .name = exp.options.name,
        };

        if (exp.link.plan9) |i| {
            self.syms.items[i] = sym;
        } else {
            try self.syms.append(self.base.allocator, sym);
            exp.link.plan9 = self.syms.items.len - 1;
        }
    }
}

pub fn freeDecl(self: *Plan9, decl_index: Module.Decl.Index) void {
    // TODO audit the lifetimes of decls table entries. It's possible to get
    // allocateDeclIndexes and then freeDecl without any updateDecl in between.
    // However that is planned to change, see the TODO comment in Module.zig
    // in the deleteUnusedDecl function.
    const mod = self.base.options.module.?;
    const decl = mod.declPtr(decl_index);
    const is_fn = (decl.val.tag() == .function);
    if (is_fn) {
        var symidx_and_submap = self.fn_decl_table.get(decl.getFileScope()).?;
        var submap = symidx_and_submap.functions;
        _ = submap.swapRemove(decl_index);
        if (submap.count() == 0) {
            self.syms.items[symidx_and_submap.sym_index] = aout.Sym.undefined_symbol;
            self.syms_index_free_list.append(self.base.allocator, symidx_and_submap.sym_index) catch {};
            submap.deinit(self.base.allocator);
        }
    } else {
        _ = self.data_decl_table.swapRemove(decl_index);
    }
    if (decl.link.plan9.got_index) |i| {
        // TODO: if this catch {} is triggered, an assertion in flushModule will be triggered, because got_index_free_list will have the wrong length
        self.got_index_free_list.append(self.base.allocator, i) catch {};
    }
    if (decl.link.plan9.sym_index) |i| {
        self.syms_index_free_list.append(self.base.allocator, i) catch {};
        self.syms.items[i] = aout.Sym.undefined_symbol;
    }
}

pub fn seeDecl(self: *Plan9, decl_index: Module.Decl.Index) !void {
    const mod = self.base.options.module.?;
    const decl = mod.declPtr(decl_index);
    if (decl.link.plan9.got_index == null) {
        if (self.got_index_free_list.popOrNull()) |i| {
            decl.link.plan9.got_index = i;
        } else {
            self.got_len += 1;
            decl.link.plan9.got_index = self.got_len - 1;
        }
    }
}

pub fn updateDeclExports(
    self: *Plan9,
    module: *Module,
    decl_index: Module.Decl.Index,
    exports: []const *Module.Export,
) !void {
    try self.seeDecl(decl_index);
    // we do all the things in flush
    _ = self;
    _ = module;
    _ = exports;
}
pub fn deinit(self: *Plan9) void {
    const gpa = self.base.allocator;
    var itf_files = self.fn_decl_table.iterator();
    while (itf_files.next()) |ent| {
        // get the submap
        var submap = ent.value_ptr.functions;
        defer submap.deinit(gpa);
        var itf = submap.iterator();
        while (itf.next()) |entry| {
            gpa.free(entry.value_ptr.code);
            gpa.free(entry.value_ptr.lineinfo);
        }
    }
    self.fn_decl_table.deinit(gpa);
    var itd = self.data_decl_table.iterator();
    while (itd.next()) |entry| {
        gpa.free(entry.value_ptr.*);
    }
    self.data_decl_table.deinit(gpa);
    self.syms.deinit(gpa);
    self.got_index_free_list.deinit(gpa);
    self.syms_index_free_list.deinit(gpa);
    self.file_segments.deinit(gpa);
    self.path_arena.deinit();
}

pub const Export = ?usize;
pub const base_tag = .plan9;
pub fn openPath(allocator: Allocator, sub_path: []const u8, options: link.Options) !*Plan9 {
    if (options.use_llvm)
        return error.LLVMBackendDoesNotSupportPlan9;
    assert(options.object_format == .plan9);

    const self = try createEmpty(allocator, options);
    errdefer self.base.destroy();

    const file = try options.emit.?.directory.handle.createFile(sub_path, .{
        .read = true,
        .mode = link.determineMode(options),
    });
    errdefer file.close();
    self.base.file = file;

    self.bases = defaultBaseAddrs(options.target.cpu.arch);

    // first 3 symbols in our table are edata, end, etext
    try self.syms.appendSlice(self.base.allocator, &.{
        .{
            .value = 0xcafebabe,
            .type = .B,
            .name = "edata",
        },
        .{
            .value = 0xcafebabe,
            .type = .B,
            .name = "end",
        },
        .{
            .value = 0xcafebabe,
            .type = .T,
            .name = "etext",
        },
    });

    return self;
}

pub fn writeSym(self: *Plan9, w: anytype, sym: aout.Sym) !void {
    log.debug("write sym{{name: {s}, value: {x}}}", .{ sym.name, sym.value });
    if (sym.type == .bad) return; // we don't want to write free'd symbols
    if (!self.sixtyfour_bit) {
        try w.writeIntBig(u32, @intCast(u32, sym.value));
    } else {
        try w.writeIntBig(u64, sym.value);
    }
    try w.writeByte(@enumToInt(sym.type));
    try w.writeAll(sym.name);
    try w.writeByte(0);
}
pub fn writeSyms(self: *Plan9, buf: *std.ArrayList(u8)) !void {
    const writer = buf.writer();
    // write the f symbols
    {
        var it = self.file_segments.iterator();
        while (it.next()) |entry| {
            try self.writeSym(writer, .{
                .type = .f,
                .value = entry.value_ptr.*,
                .name = entry.key_ptr.*,
            });
        }
    }

    const mod = self.base.options.module.?;

    // write the data symbols
    {
        var it = self.data_decl_table.iterator();
        while (it.next()) |entry| {
            const decl_index = entry.key_ptr.*;
            const decl = mod.declPtr(decl_index);
            const sym = self.syms.items[decl.link.plan9.sym_index.?];
            try self.writeSym(writer, sym);
            if (self.base.options.module.?.decl_exports.get(decl_index)) |exports| {
                for (exports) |e| {
                    try self.writeSym(writer, self.syms.items[e.link.plan9.?]);
                }
            }
        }
    }
    // text symbols are the hardest:
    // the file of a text symbol is the .z symbol before it
    // so we have to write everything in the right order
    {
        var it_file = self.fn_decl_table.iterator();
        while (it_file.next()) |fentry| {
            var symidx_and_submap = fentry.value_ptr;
            // write the z symbols
            try self.writeSym(writer, self.syms.items[symidx_and_submap.sym_index - 1]);
            try self.writeSym(writer, self.syms.items[symidx_and_submap.sym_index]);

            // write all the decls come from the file of the z symbol
            var submap_it = symidx_and_submap.functions.iterator();
            while (submap_it.next()) |entry| {
                const decl_index = entry.key_ptr.*;
                const decl = mod.declPtr(decl_index);
                const sym = self.syms.items[decl.link.plan9.sym_index.?];
                try self.writeSym(writer, sym);
                if (self.base.options.module.?.decl_exports.get(decl_index)) |exports| {
                    for (exports) |e| {
                        const s = self.syms.items[e.link.plan9.?];
                        if (mem.eql(u8, s.name, "_start"))
                            self.entry_val = s.value;
                        try self.writeSym(writer, s);
                    }
                }
            }
        }
    }
}

/// this will be removed, moved to updateFinish
pub fn allocateDeclIndexes(self: *Plan9, decl_index: Module.Decl.Index) !void {
    _ = self;
    _ = decl_index;
}
pub fn getDeclVAddr(
    self: *Plan9,
    decl_index: Module.Decl.Index,
    reloc_info: link.File.RelocInfo,
) !u64 {
    _ = reloc_info;
    const mod = self.base.options.module.?;
    const decl = mod.declPtr(decl_index);
    if (decl.ty.zigTypeTag() == .Fn) {
        var start = self.bases.text;
        var it_file = self.fn_decl_table.iterator();
        while (it_file.next()) |fentry| {
            var symidx_and_submap = fentry.value_ptr;
            var submap_it = symidx_and_submap.functions.iterator();
            while (submap_it.next()) |entry| {
                if (entry.key_ptr.* == decl_index) return start;
                start += entry.value_ptr.code.len;
            }
        }
        unreachable;
    } else {
        var start = self.bases.data + self.got_len * if (!self.sixtyfour_bit) @as(u32, 4) else 8;
        var it = self.data_decl_table.iterator();
        while (it.next()) |kv| {
            if (decl_index == kv.key_ptr.*) return start;
            start += kv.value_ptr.len;
        }
        unreachable;
    }
}
