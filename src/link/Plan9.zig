const Plan9 = @This();

const std = @import("std");
const link = @import("../link.zig");
const Module = @import("../Module.zig");
const Compilation = @import("../Compilation.zig");
const aout = @import("plan9/a.out.zig");
const codegen = @import("../codegen.zig");
const trace = @import("../tracy.zig").trace;
const mem = std.mem;
const File = link.File;
const Allocator = std.mem.Allocator;

const log = std.log.scoped(.link);
const assert = std.debug.assert;

// TODO use incremental compilation

base: link.File,
ptr_width: PtrWidth,
error_flags: File.ErrorFlags = File.ErrorFlags{},

decl_table: std.AutoArrayHashMapUnmanaged(*Module.Decl, void) = .{},
/// is just casted down when 32 bit
syms: std.ArrayListUnmanaged(aout.Sym64) = .{},
call_relocs: std.ArrayListUnmanaged(CallReloc) = .{},
text_buf: std.ArrayListUnmanaged(u8) = .{},
data_buf: std.ArrayListUnmanaged(u8) = .{},

cur_decl: *Module.Decl = undefined,
hdr: aout.ExecHdr = undefined,

fn headerSize(self: Plan9) u32 {
    // fat header (currently unused)
    const fat: u8 = if (self.ptr_width == .p64) 8 else 0;
    return @sizeOf(aout.ExecHdr) + fat;
}
pub const DeclBlock = struct {
    type: enum { text, data },
    // offset in the text or data sects
    offset: u32,
    // offset into syms
    sym_index: ?usize,
    pub const empty = DeclBlock{
        .type = .text,
        .offset = 0,
        .sym_index = null,
    };
};

// TODO change base addr based on target (right now it just works on amd64)
const default_base_addr = 0x00200000;

pub const CallReloc = struct {
    caller: *Module.Decl,
    callee: *Module.Decl,
    offset_in_caller: usize,
};

pub const PtrWidth = enum { p32, p64 };

pub fn createEmpty(gpa: *Allocator, options: link.Options) !*Plan9 {
    if (options.use_llvm)
        return error.LLVMBackendDoesNotSupportPlan9;
    const ptr_width: PtrWidth = switch (options.target.cpu.arch.ptrBitWidth()) {
        0...32 => .p32,
        33...64 => .p64,
        else => return error.UnsupportedP9Architecture,
    };
    const self = try gpa.create(Plan9);
    self.* = .{
        .base = .{
            .tag = .plan9,
            .options = options,
            .allocator = gpa,
            .file = null,
        },
        .ptr_width = ptr_width,
    };
    return self;
}

pub fn updateDecl(self: *Plan9, module: *Module, decl: *Module.Decl) !void {
    _ = try self.decl_table.getOrPut(self.base.allocator, decl);
}

pub fn flush(self: *Plan9, comp: *Compilation) !void {
    assert(!self.base.options.use_lld);

    switch (self.base.options.effectiveOutputMode()) {
        .Exe => {},
        // plan9 object files are totally different
        .Obj => return error.TODOImplementPlan9Objs,
        .Lib => return error.TODOImplementWritingLibFiles,
    }
    return self.flushModule(comp);
}
pub fn flushModule(self: *Plan9, comp: *Compilation) !void {
    const tracy = trace(@src());
    defer tracy.end();

    defer assert(self.hdr.entry != 0x0);

    const module = self.base.options.module orelse return error.LinkingWithoutZigSourceUnimplemented;

    self.text_buf.items.len = 0;
    self.data_buf.items.len = 0;
    self.call_relocs.items.len = 0;
    // temporary buffer
    var code_buffer = std.ArrayList(u8).init(self.base.allocator);
    defer code_buffer.deinit();
    {
        for (self.decl_table.keys()) |decl| {
            if (!decl.has_tv) continue;
            self.cur_decl = decl;
            const is_fn = (decl.ty.zigTypeTag() == .Fn);
            decl.link.plan9 = if (is_fn) .{
                .offset = @intCast(u32, self.text_buf.items.len),
                .type = .text,
                .sym_index = decl.link.plan9.sym_index,
            } else .{
                .offset = @intCast(u32, self.data_buf.items.len),
                .type = .data,
                .sym_index = decl.link.plan9.sym_index,
            };
            if (decl.link.plan9.sym_index == null) {
                try self.syms.append(self.base.allocator, .{
                    .value = decl.link.plan9.offset,
                    .type = switch (decl.link.plan9.type) {
                        .text => .t,
                        .data => .d,
                    },
                    .name = mem.span(decl.name),
                });
                decl.link.plan9.sym_index = self.syms.items.len - 1;
            } else {
                self.syms.items[decl.link.plan9.sym_index.?] = .{
                    .value = decl.link.plan9.offset,
                    .type = switch (decl.link.plan9.type) {
                        .text => .t,
                        .data => .d,
                    },
                    .name = mem.span(decl.name),
                };
            }
            const res = try codegen.generateSymbol(&self.base, decl.srcLoc(), .{
                .ty = decl.ty,
                .val = decl.val,
            }, &code_buffer, .{ .none = {} });
            const code = switch (res) {
                .externally_managed => |x| x,
                .appended => code_buffer.items,
                .fail => |em| {
                    decl.analysis = .codegen_failure;
                    try module.failed_decls.put(module.gpa, decl, em);
                    // TODO try to do more decls
                    return;
                },
            };
            if (is_fn)
                try self.text_buf.appendSlice(self.base.allocator, code)
            else
                try self.data_buf.appendSlice(self.base.allocator, code);
            code_buffer.items.len = 0;
        }
    }

    // Do relocations.
    {
        for (self.call_relocs.items) |reloc| {
            const l: DeclBlock = reloc.caller.link.plan9;
            assert(l.sym_index != null); // we didn't process it already
            const endian = self.base.options.target.cpu.arch.endian();
            if (self.ptr_width == .p32) {
                const callee_offset = @truncate(u32, reloc.callee.link.plan9.offset + default_base_addr); // TODO this is different if its data
                const off = reloc.offset_in_caller + l.offset;
                std.mem.writeInt(u32, self.text_buf.items[off - 4 ..][0..4], callee_offset, endian);
            } else {
                // what we are writing
                const callee_offset = reloc.callee.link.plan9.offset + default_base_addr; // TODO this is different if its data
                const off = reloc.offset_in_caller + l.offset;
                std.mem.writeInt(u64, self.text_buf.items[off - 8 ..][0..8], callee_offset, endian);
            }
        }
    }

    var sym_buf = std.ArrayList(u8).init(self.base.allocator);
    defer sym_buf.deinit();
    try self.writeSyms(&sym_buf);

    // generate the header
    self.hdr = .{
        .magic = try aout.magicFromArch(self.base.options.target.cpu.arch),
        .text = @intCast(u32, self.text_buf.items.len),
        .data = @intCast(u32, self.data_buf.items.len),
        .syms = @intCast(u32, sym_buf.items.len),
        .bss = 0,
        .pcsz = 0,
        .spsz = 0,
        .entry = self.hdr.entry,
    };

    const file = self.base.file.?;

    const hdr_buf = self.hdr.toU8s();
    const hdr_slice: []const u8 = &hdr_buf;
    // account for the fat header
    const hdr_size: u8 = if (self.ptr_width == .p32) 32 else 40;
    // write it all!
    var vectors: [4]std.os.iovec_const = .{
        .{ .iov_base = hdr_slice.ptr, .iov_len = hdr_size },
        .{ .iov_base = self.text_buf.items.ptr, .iov_len = self.text_buf.items.len },
        .{ .iov_base = self.data_buf.items.ptr, .iov_len = self.data_buf.items.len },
        .{ .iov_base = sym_buf.items.ptr, .iov_len = sym_buf.items.len },
        // TODO spsz, pcsz
    };
    try file.pwritevAll(&vectors, 0);
}
pub fn freeDecl(self: *Plan9, decl: *Module.Decl) void {
    assert(self.decl_table.swapRemove(decl));
}

pub fn updateDeclExports(
    self: *Plan9,
    module: *Module,
    decl: *Module.Decl,
    exports: []const *Module.Export,
) !void {
    for (exports) |exp| {
        if (exp.options.section) |section_name| {
            if (!mem.eql(u8, section_name, ".text")) {
                try module.failed_exports.ensureCapacity(module.gpa, module.failed_exports.count() + 1);
                module.failed_exports.putAssumeCapacityNoClobber(
                    exp,
                    try Module.ErrorMsg.create(self.base.allocator, decl.srcLoc(), "plan9 does not support extra sections", .{}),
                );
                continue;
            }
        }
        if (std.mem.eql(u8, exp.options.name, "_start")) {
            std.debug.assert(decl.link.plan9.type == .text); // we tried to link a non-function as _start
            self.hdr.entry = Plan9.default_base_addr + self.headerSize() + decl.link.plan9.offset;
        }
        if (exp.link.plan9) |i| {
            self.syms.items[i] = .{
                .value = decl.link.plan9.offset,
                .type = switch (decl.link.plan9.type) {
                    .text => .T,
                    .data => .D,
                },
                .name = exp.options.name,
            };
        } else {
            try self.syms.append(self.base.allocator, .{
                .value = decl.link.plan9.offset,
                .type = switch (decl.link.plan9.type) {
                    .text => .T,
                    .data => .D,
                },
                .name = exp.options.name,
            });
            exp.link.plan9 = self.syms.items.len - 1;
        }
    }
}
pub fn deinit(self: *Plan9) void {
    self.decl_table.deinit(self.base.allocator);
    self.call_relocs.deinit(self.base.allocator);
    self.syms.deinit(self.base.allocator);
    self.text_buf.deinit(self.base.allocator);
    self.data_buf.deinit(self.base.allocator);
}

pub const Export = ?usize;
pub const base_tag = .plan9;
pub fn openPath(allocator: *Allocator, sub_path: []const u8, options: link.Options) !*Plan9 {
    if (options.use_llvm)
        return error.LLVMBackendDoesNotSupportPlan9;
    assert(options.object_format == .plan9);
    const file = try options.emit.?.directory.handle.createFile(sub_path, .{
        .truncate = false,
        .read = true,
        .mode = link.determineMode(options),
    });
    errdefer file.close();

    const self = try createEmpty(allocator, options);
    errdefer self.base.destroy();

    if (std.builtin.mode == .Debug or std.builtin.mode == .ReleaseSafe)
        self.hdr.entry = 0x0;

    self.base.file = file;
    return self;
}

// tells its future self to write the addr of the callee decl into offset_in_caller.
// writes it to the {4, 8} bytes before offset_in_caller
pub fn addCallReloc(self: *Plan9, code: *std.ArrayList(u8), reloc: CallReloc) !void {
    try self.call_relocs.append(self.base.allocator, reloc);
}

pub fn writeSyms(self: *Plan9, buf: *std.ArrayList(u8)) !void {
    const writer = buf.writer();
    for (self.syms.items) |sym| {
        if (self.ptr_width == .p32) {
            try writer.writeIntBig(u32, @intCast(u32, sym.value) + default_base_addr);
        } else {
            try writer.writeIntBig(u64, sym.value + default_base_addr);
        }
        try writer.writeByte(@enumToInt(sym.type));
        try writer.writeAll(std.mem.span(sym.name));
        try writer.writeByte(0);
    }
}
