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

/// Returns an Atom which is the target node of this relocation edge (if any).
pub fn getTargetAtom(self: Relocation, coff_file: *Coff) ?*Atom {
    switch (self.type) {
        .got,
        .got_page,
        .got_pageoff,
        => return coff_file.getGotAtomForSymbol(self.target),

        .direct,
        .page,
        .pageoff,
        => return coff_file.getAtomForSymbol(self.target),

        .import,
        .import_page,
        .import_pageoff,
        => return coff_file.getImportAtomForSymbol(self.target),
    }
}

pub fn resolve(self: *Relocation, atom: *Atom, coff_file: *Coff) !void {
    const source_sym = atom.getSymbol(coff_file);
    const source_section = coff_file.sections.get(@enumToInt(source_sym.section_number) - 1).header;
    const source_vaddr = source_sym.value + self.offset;

    const file_offset = source_section.pointer_to_raw_data + source_sym.value - source_section.virtual_address;

    const target_atom = self.getTargetAtom(coff_file) orelse return;
    const target_vaddr = target_atom.getSymbol(coff_file).value;
    const target_vaddr_with_addend = target_vaddr + self.addend;

    log.debug("  ({x}: [() => 0x{x} ({s})) ({s}) (in file at 0x{x})", .{
        source_vaddr,
        target_vaddr_with_addend,
        coff_file.getSymbolName(self.target),
        @tagName(self.type),
        file_offset + self.offset,
    });

    const ctx: Context = .{
        .source_vaddr = source_vaddr,
        .target_vaddr = target_vaddr_with_addend,
        .file_offset = file_offset,
        .image_base = coff_file.getImageBase(),
    };

    switch (coff_file.base.options.target.cpu.arch) {
        .aarch64 => try self.resolveAarch64(ctx, coff_file),
        .x86, .x86_64 => try self.resolveX86(ctx, coff_file),
        else => unreachable, // unhandled target architecture
    }

    self.dirty = false;
}

const Context = struct {
    source_vaddr: u32,
    target_vaddr: u32,
    file_offset: u32,
    image_base: u64,
};

fn resolveAarch64(self: *Relocation, ctx: Context, coff_file: *Coff) !void {
    var buffer: [@sizeOf(u64)]u8 = undefined;
    switch (self.length) {
        2 => {
            const amt = try coff_file.base.file.?.preadAll(buffer[0..4], ctx.file_offset + self.offset);
            if (amt != 4) return error.InputOutput;
        },
        3 => {
            const amt = try coff_file.base.file.?.preadAll(&buffer, ctx.file_offset + self.offset);
            if (amt != 8) return error.InputOutput;
        },
        else => unreachable,
    }

    switch (self.type) {
        .got_page, .import_page, .page => {
            const source_page = @intCast(i32, ctx.source_vaddr >> 12);
            const target_page = @intCast(i32, ctx.target_vaddr >> 12);
            const pages = @bitCast(u21, @intCast(i21, target_page - source_page));
            var inst = aarch64.Instruction{
                .pc_relative_address = mem.bytesToValue(meta.TagPayload(
                    aarch64.Instruction,
                    aarch64.Instruction.pc_relative_address,
                ), buffer[0..4]),
            };
            inst.pc_relative_address.immhi = @truncate(u19, pages >> 2);
            inst.pc_relative_address.immlo = @truncate(u2, pages);
            mem.writeIntLittle(u32, buffer[0..4], inst.toU32());
        },
        .got_pageoff, .import_pageoff, .pageoff => {
            assert(!self.pcrel);

            const narrowed = @truncate(u12, @intCast(u64, ctx.target_vaddr));
            if (isArithmeticOp(buffer[0..4])) {
                var inst = aarch64.Instruction{
                    .add_subtract_immediate = mem.bytesToValue(meta.TagPayload(
                        aarch64.Instruction,
                        aarch64.Instruction.add_subtract_immediate,
                    ), buffer[0..4]),
                };
                inst.add_subtract_immediate.imm12 = narrowed;
                mem.writeIntLittle(u32, buffer[0..4], inst.toU32());
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
                mem.writeIntLittle(u32, buffer[0..4], inst.toU32());
            }
        },
        .direct => {
            assert(!self.pcrel);
            switch (self.length) {
                2 => mem.writeIntLittle(
                    u32,
                    buffer[0..4],
                    @truncate(u32, ctx.target_vaddr + ctx.image_base),
                ),
                3 => mem.writeIntLittle(u64, &buffer, ctx.target_vaddr + ctx.image_base),
                else => unreachable,
            }
        },

        .got => unreachable,
        .import => unreachable,
    }

    switch (self.length) {
        2 => try coff_file.base.file.?.pwriteAll(buffer[0..4], ctx.file_offset + self.offset),
        3 => try coff_file.base.file.?.pwriteAll(&buffer, ctx.file_offset + self.offset),
        else => unreachable,
    }
}

fn resolveX86(self: *Relocation, ctx: Context, coff_file: *Coff) !void {
    switch (self.type) {
        .got_page => unreachable,
        .got_pageoff => unreachable,
        .page => unreachable,
        .pageoff => unreachable,
        .import_page => unreachable,
        .import_pageoff => unreachable,

        .got, .import => {
            assert(self.pcrel);
            const disp = @intCast(i32, ctx.target_vaddr) - @intCast(i32, ctx.source_vaddr) - 4;
            try coff_file.base.file.?.pwriteAll(mem.asBytes(&disp), ctx.file_offset + self.offset);
        },
        .direct => {
            if (self.pcrel) {
                const disp = @intCast(i32, ctx.target_vaddr) - @intCast(i32, ctx.source_vaddr) - 4;
                try coff_file.base.file.?.pwriteAll(mem.asBytes(&disp), ctx.file_offset + self.offset);
            } else switch (coff_file.ptr_width) {
                .p32 => try coff_file.base.file.?.pwriteAll(
                    mem.asBytes(&@intCast(u32, ctx.target_vaddr + ctx.image_base)),
                    ctx.file_offset + self.offset,
                ),
                .p64 => switch (self.length) {
                    2 => try coff_file.base.file.?.pwriteAll(
                        mem.asBytes(&@truncate(u32, ctx.target_vaddr + ctx.image_base)),
                        ctx.file_offset + self.offset,
                    ),
                    3 => try coff_file.base.file.?.pwriteAll(
                        mem.asBytes(&(ctx.target_vaddr + ctx.image_base)),
                        ctx.file_offset + self.offset,
                    ),
                    else => unreachable,
                },
            }
        },
    }
}

inline fn isArithmeticOp(inst: *const [4]u8) bool {
    const group_decode = @truncate(u5, inst[3]);
    return ((group_decode >> 2) == 4);
}
