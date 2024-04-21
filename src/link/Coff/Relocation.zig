const Relocation = @This();

const std = @import("std");
const assert = std.debug.assert;
const log = std.log.scoped(.link);
const math = std.math;
const mem = std.mem;
const meta = std.meta;

const aarch64 = @import("../../arch/aarch64/bits.zig");

const Atom = @import("Atom.zig");
const Coff = @import("../Coff.zig");
const SymbolWithLoc = Coff.SymbolWithLoc;

type: enum {
    // x86, x86_64
    /// RIP-relative displacement to a GOT pointer
    got,
    /// RIP-relative displacement to an import pointer
    import,

    // aarch64
    /// PC-relative distance to target page in GOT section
    got_page,
    /// Offset to a GOT pointer relative to the start of a page in GOT section
    got_pageoff,
    /// PC-relative distance to target page in a section (e.g., .rdata)
    page,
    /// Offset to a pointer relative to the start of a page in a section (e.g., .rdata)
    pageoff,
    /// PC-relative distance to target page in a import section
    import_page,
    /// Offset to a pointer relative to the start of a page in an import section (e.g., .rdata)
    import_pageoff,

    // common
    /// Absolute pointer value
    direct,
},
target: SymbolWithLoc,
offset: u32,
addend: u32,
pcrel: bool,
length: u2,
dirty: bool = true,

/// Returns true if and only if the reloc can be resolved.
pub fn isResolvable(self: Relocation, coff_file: *Coff) bool {
    _ = self.getTargetAddress(coff_file) orelse return false;
    return true;
}

pub fn isGotIndirection(self: Relocation) bool {
    return switch (self.type) {
        .got, .got_page, .got_pageoff => true,
        else => false,
    };
}

/// Returns address of the target if any.
pub fn getTargetAddress(self: Relocation, coff_file: *const Coff) ?u32 {
    switch (self.type) {
        .got, .got_page, .got_pageoff => {
            const got_index = coff_file.got_table.lookup.get(self.target) orelse return null;
            const header = coff_file.sections.items(.header)[coff_file.got_section_index.?];
            return header.virtual_address + got_index * coff_file.ptr_width.size();
        },
        .import, .import_page, .import_pageoff => {
            const sym = coff_file.getSymbol(self.target);
            const index = coff_file.import_tables.getIndex(sym.value) orelse return null;
            const itab = coff_file.import_tables.values()[index];
            return itab.getImportAddress(self.target, .{
                .coff_file = coff_file,
                .index = index,
                .name_off = sym.value,
            });
        },
        else => {
            const target_atom_index = coff_file.getAtomIndexForSymbol(self.target) orelse return null;
            const target_atom = coff_file.getAtom(target_atom_index);
            return target_atom.getSymbol(coff_file).value;
        },
    }
}

pub fn resolve(self: Relocation, atom_index: Atom.Index, code: []u8, image_base: u64, coff_file: *Coff) void {
    const atom = coff_file.getAtom(atom_index);
    const source_sym = atom.getSymbol(coff_file);
    const source_vaddr = source_sym.value + self.offset;

    const target_vaddr = self.getTargetAddress(coff_file).?; // Oops, you didn't check if the relocation can be resolved with isResolvable().
    const target_vaddr_with_addend = target_vaddr + self.addend;

    log.debug("  ({x}: [() => 0x{x} ({s})) ({s}) ", .{
        source_vaddr,
        target_vaddr_with_addend,
        coff_file.getSymbolName(self.target),
        @tagName(self.type),
    });

    const ctx: Context = .{
        .source_vaddr = source_vaddr,
        .target_vaddr = target_vaddr_with_addend,
        .image_base = image_base,
        .code = code,
        .ptr_width = coff_file.ptr_width,
    };

    const target = coff_file.base.comp.root_mod.resolved_target.result;
    switch (target.cpu.arch) {
        .aarch64 => self.resolveAarch64(ctx),
        .x86, .x86_64 => self.resolveX86(ctx),
        else => unreachable, // unhandled target architecture
    }
}

const Context = struct {
    source_vaddr: u32,
    target_vaddr: u32,
    image_base: u64,
    code: []u8,
    ptr_width: Coff.PtrWidth,
};

fn resolveAarch64(self: Relocation, ctx: Context) void {
    var buffer = ctx.code[self.offset..];
    switch (self.type) {
        .got_page, .import_page, .page => {
            const source_page = @as(i32, @intCast(ctx.source_vaddr >> 12));
            const target_page = @as(i32, @intCast(ctx.target_vaddr >> 12));
            const pages = @as(u21, @bitCast(@as(i21, @intCast(target_page - source_page))));
            var inst = aarch64.Instruction{
                .pc_relative_address = mem.bytesToValue(meta.TagPayload(
                    aarch64.Instruction,
                    aarch64.Instruction.pc_relative_address,
                ), buffer[0..4]),
            };
            inst.pc_relative_address.immhi = @as(u19, @truncate(pages >> 2));
            inst.pc_relative_address.immlo = @as(u2, @truncate(pages));
            mem.writeInt(u32, buffer[0..4], inst.toU32(), .little);
        },
        .got_pageoff, .import_pageoff, .pageoff => {
            assert(!self.pcrel);

            const narrowed = @as(u12, @truncate(@as(u64, @intCast(ctx.target_vaddr))));
            if (isArithmeticOp(buffer[0..4])) {
                var inst = aarch64.Instruction{
                    .add_subtract_immediate = mem.bytesToValue(meta.TagPayload(
                        aarch64.Instruction,
                        aarch64.Instruction.add_subtract_immediate,
                    ), buffer[0..4]),
                };
                inst.add_subtract_immediate.imm12 = narrowed;
                mem.writeInt(u32, buffer[0..4], inst.toU32(), .little);
            } else {
                var inst = aarch64.Instruction{
                    .load_store_register = mem.bytesToValue(meta.TagPayload(
                        aarch64.Instruction,
                        aarch64.Instruction.load_store_register,
                    ), buffer[0..4]),
                };
                const offset: u12 = blk: {
                    if (inst.load_store_register.size == 0) {
                        if (inst.load_store_register.v == 1) {
                            // 128-bit SIMD is scaled by 16.
                            break :blk @divExact(narrowed, 16);
                        }
                        // Otherwise, 8-bit SIMD or ldrb.
                        break :blk narrowed;
                    } else {
                        const denom: u4 = math.powi(u4, 2, inst.load_store_register.size) catch unreachable;
                        break :blk @divExact(narrowed, denom);
                    }
                };
                inst.load_store_register.offset = offset;
                mem.writeInt(u32, buffer[0..4], inst.toU32(), .little);
            }
        },
        .direct => {
            assert(!self.pcrel);
            switch (self.length) {
                2 => mem.writeInt(
                    u32,
                    buffer[0..4],
                    @as(u32, @truncate(ctx.target_vaddr + ctx.image_base)),
                    .little,
                ),
                3 => mem.writeInt(u64, buffer[0..8], ctx.target_vaddr + ctx.image_base, .little),
                else => unreachable,
            }
        },

        .got => unreachable,
        .import => unreachable,
    }
}

fn resolveX86(self: Relocation, ctx: Context) void {
    var buffer = ctx.code[self.offset..];
    switch (self.type) {
        .got_page => unreachable,
        .got_pageoff => unreachable,
        .page => unreachable,
        .pageoff => unreachable,
        .import_page => unreachable,
        .import_pageoff => unreachable,

        .got, .import => {
            assert(self.pcrel);
            const disp = @as(i32, @intCast(ctx.target_vaddr)) - @as(i32, @intCast(ctx.source_vaddr)) - 4;
            mem.writeInt(i32, buffer[0..4], disp, .little);
        },
        .direct => {
            if (self.pcrel) {
                const disp = @as(i32, @intCast(ctx.target_vaddr)) - @as(i32, @intCast(ctx.source_vaddr)) - 4;
                mem.writeInt(i32, buffer[0..4], disp, .little);
            } else switch (ctx.ptr_width) {
                .p32 => mem.writeInt(u32, buffer[0..4], @as(u32, @intCast(ctx.target_vaddr + ctx.image_base)), .little),
                .p64 => switch (self.length) {
                    2 => mem.writeInt(u32, buffer[0..4], @as(u32, @truncate(ctx.target_vaddr + ctx.image_base)), .little),
                    3 => mem.writeInt(u64, buffer[0..8], ctx.target_vaddr + ctx.image_base, .little),
                    else => unreachable,
                },
            }
        },
    }
}

inline fn isArithmeticOp(inst: *const [4]u8) bool {
    const group_decode = @as(u5, @truncate(inst[3]));
    return ((group_decode >> 2) == 4);
}
