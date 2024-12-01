entries: std.ArrayListUnmanaged(Entry) = .empty,
buffer: std.ArrayListUnmanaged(u8) = .empty,

pub const Entry = struct {
    offset: u64,
    segment_id: u8,

    pub fn lessThan(ctx: void, entry: Entry, other: Entry) bool {
        _ = ctx;
        if (entry.segment_id == other.segment_id) {
            return entry.offset < other.offset;
        }
        return entry.segment_id < other.segment_id;
    }
};

pub fn deinit(rebase: *Rebase, gpa: Allocator) void {
    rebase.entries.deinit(gpa);
    rebase.buffer.deinit(gpa);
}

pub fn updateSize(rebase: *Rebase, macho_file: *MachO) !void {
    const tracy = trace(@src());
    defer tracy.end();

    const gpa = macho_file.base.comp.gpa;

    var objects = try std.ArrayList(File.Index).initCapacity(gpa, macho_file.objects.items.len + 2);
    defer objects.deinit();
    objects.appendSliceAssumeCapacity(macho_file.objects.items);
    if (macho_file.getZigObject()) |obj| objects.appendAssumeCapacity(obj.index);
    if (macho_file.getInternalObject()) |obj| objects.appendAssumeCapacity(obj.index);

    for (objects.items) |index| {
        const file = macho_file.getFile(index).?;
        for (file.getAtoms()) |atom_index| {
            const atom = file.getAtom(atom_index) orelse continue;
            if (!atom.isAlive()) continue;
            if (atom.getInputSection(macho_file).isZerofill()) continue;
            const atom_addr = atom.getAddress(macho_file);
            const seg_id = macho_file.sections.items(.segment_id)[atom.out_n_sect];
            const seg = macho_file.segments.items[seg_id];
            for (atom.getRelocs(macho_file)) |rel| {
                if (rel.type != .unsigned or rel.meta.length != 3) continue;
                if (rel.tag == .@"extern") {
                    const sym = rel.getTargetSymbol(atom.*, macho_file);
                    if (sym.isTlvInit(macho_file)) continue;
                    if (sym.flags.import) continue;
                }
                const rel_offset = rel.offset - atom.off;
                try rebase.entries.append(gpa, .{
                    .offset = atom_addr + rel_offset - seg.vmaddr,
                    .segment_id = seg_id,
                });
            }
        }
    }

    if (macho_file.got_sect_index) |sid| {
        const seg_id = macho_file.sections.items(.segment_id)[sid];
        const seg = macho_file.segments.items[seg_id];
        for (macho_file.got.symbols.items, 0..) |ref, idx| {
            const sym = ref.getSymbol(macho_file).?;
            const addr = macho_file.got.getAddress(@intCast(idx), macho_file);
            if (!sym.flags.import) {
                try rebase.entries.append(gpa, .{
                    .offset = addr - seg.vmaddr,
                    .segment_id = seg_id,
                });
            }
        }
    }

    if (macho_file.la_symbol_ptr_sect_index) |sid| {
        const sect = macho_file.sections.items(.header)[sid];
        const seg_id = macho_file.sections.items(.segment_id)[sid];
        const seg = macho_file.segments.items[seg_id];
        for (macho_file.stubs.symbols.items, 0..) |ref, idx| {
            const sym = ref.getSymbol(macho_file).?;
            const addr = sect.addr + idx * @sizeOf(u64);
            const rebase_entry = Rebase.Entry{
                .offset = addr - seg.vmaddr,
                .segment_id = seg_id,
            };
            if ((sym.flags.import and !sym.flags.weak) or !sym.flags.import) {
                try rebase.entries.append(gpa, rebase_entry);
            }
        }
    }

    if (macho_file.tlv_ptr_sect_index) |sid| {
        const seg_id = macho_file.sections.items(.segment_id)[sid];
        const seg = macho_file.segments.items[seg_id];
        for (macho_file.tlv_ptr.symbols.items, 0..) |ref, idx| {
            const sym = ref.getSymbol(macho_file).?;
            const addr = macho_file.tlv_ptr.getAddress(@intCast(idx), macho_file);
            if (!sym.flags.import) {
                try rebase.entries.append(gpa, .{
                    .offset = addr - seg.vmaddr,
                    .segment_id = seg_id,
                });
            }
        }
    }

    try rebase.finalize(gpa);
    macho_file.dyld_info_cmd.rebase_size = mem.alignForward(u32, @intCast(rebase.buffer.items.len), @alignOf(u64));
}

fn finalize(rebase: *Rebase, gpa: Allocator) !void {
    if (rebase.entries.items.len == 0) return;

    const writer = rebase.buffer.writer(gpa);

    log.debug("rebase opcodes", .{});

    std.mem.sort(Entry, rebase.entries.items, {}, Entry.lessThan);

    try setTypePointer(writer);

    var start: usize = 0;
    var seg_id: ?u8 = null;
    for (rebase.entries.items, 0..) |entry, i| {
        if (seg_id != null and seg_id.? == entry.segment_id) continue;
        try finalizeSegment(rebase.entries.items[start..i], writer);
        seg_id = entry.segment_id;
        start = i;
    }

    try finalizeSegment(rebase.entries.items[start..], writer);
    try done(writer);
}

fn finalizeSegment(entries: []const Entry, writer: anytype) !void {
    if (entries.len == 0) return;

    const segment_id = entries[0].segment_id;
    var offset = entries[0].offset;
    try setSegmentOffset(segment_id, offset, writer);

    var count: usize = 0;
    var skip: u64 = 0;
    var state: enum {
        start,
        times,
        times_skip,
    } = .times;

    var i: usize = 0;
    while (i < entries.len) : (i += 1) {
        log.debug("{x}, {d}, {x}, {s}", .{ offset, count, skip, @tagName(state) });
        const current_offset = entries[i].offset;
        log.debug("  => {x}", .{current_offset});
        switch (state) {
            .start => {
                if (offset < current_offset) {
                    const delta = current_offset - offset;
                    try addAddr(delta, writer);
                    offset += delta;
                }
                state = .times;
                offset += @sizeOf(u64);
                count = 1;
            },
            .times => {
                const delta = current_offset - offset;
                if (delta == 0) {
                    count += 1;
                    offset += @sizeOf(u64);
                    continue;
                }
                if (count == 1) {
                    state = .times_skip;
                    skip = delta;
                    offset += skip;
                    i -= 1;
                } else {
                    try rebaseTimes(count, writer);
                    state = .start;
                    i -= 1;
                }
            },
            .times_skip => {
                if (current_offset < offset) {
                    count -= 1;
                    if (count == 1) {
                        try rebaseAddAddr(skip, writer);
                    } else {
                        try rebaseTimesSkip(count, skip, writer);
                    }
                    state = .start;
                    offset = offset - (@sizeOf(u64) + skip);
                    i -= 2;
                    continue;
                }

                const delta = current_offset - offset;
                if (delta == 0) {
                    count += 1;
                    offset += @sizeOf(u64) + skip;
                } else {
                    try rebaseTimesSkip(count, skip, writer);
                    state = .start;
                    i -= 1;
                }
            },
        }
    }

    switch (state) {
        .start => unreachable,
        .times => {
            try rebaseTimes(count, writer);
        },
        .times_skip => {
            try rebaseTimesSkip(count, skip, writer);
        },
    }
}

fn setTypePointer(writer: anytype) !void {
    log.debug(">>> set type: {d}", .{macho.REBASE_TYPE_POINTER});
    try writer.writeByte(macho.REBASE_OPCODE_SET_TYPE_IMM | @as(u4, @truncate(macho.REBASE_TYPE_POINTER)));
}

fn setSegmentOffset(segment_id: u8, offset: u64, writer: anytype) !void {
    log.debug(">>> set segment: {d} and offset: {x}", .{ segment_id, offset });
    try writer.writeByte(macho.REBASE_OPCODE_SET_SEGMENT_AND_OFFSET_ULEB | @as(u4, @truncate(segment_id)));
    try std.leb.writeUleb128(writer, offset);
}

fn rebaseAddAddr(addr: u64, writer: anytype) !void {
    log.debug(">>> rebase with add: {x}", .{addr});
    try writer.writeByte(macho.REBASE_OPCODE_DO_REBASE_ADD_ADDR_ULEB);
    try std.leb.writeUleb128(writer, addr);
}

fn rebaseTimes(count: usize, writer: anytype) !void {
    log.debug(">>> rebase with count: {d}", .{count});
    if (count <= 0xf) {
        try writer.writeByte(macho.REBASE_OPCODE_DO_REBASE_IMM_TIMES | @as(u4, @truncate(count)));
    } else {
        try writer.writeByte(macho.REBASE_OPCODE_DO_REBASE_ULEB_TIMES);
        try std.leb.writeUleb128(writer, count);
    }
}

fn rebaseTimesSkip(count: usize, skip: u64, writer: anytype) !void {
    log.debug(">>> rebase with count: {d} and skip: {x}", .{ count, skip });
    try writer.writeByte(macho.REBASE_OPCODE_DO_REBASE_ULEB_TIMES_SKIPPING_ULEB);
    try std.leb.writeUleb128(writer, count);
    try std.leb.writeUleb128(writer, skip);
}

fn addAddr(addr: u64, writer: anytype) !void {
    log.debug(">>> add: {x}", .{addr});
    if (std.mem.isAlignedGeneric(u64, addr, @sizeOf(u64))) {
        const imm = @divExact(addr, @sizeOf(u64));
        if (imm <= 0xf) {
            try writer.writeByte(macho.REBASE_OPCODE_ADD_ADDR_IMM_SCALED | @as(u4, @truncate(imm)));
            return;
        }
    }
    try writer.writeByte(macho.REBASE_OPCODE_ADD_ADDR_ULEB);
    try std.leb.writeUleb128(writer, addr);
}

fn done(writer: anytype) !void {
    log.debug(">>> done", .{});
    try writer.writeByte(macho.REBASE_OPCODE_DONE);
}

pub fn write(rebase: Rebase, writer: anytype) !void {
    try writer.writeAll(rebase.buffer.items);
}

test "rebase - no entries" {
    const gpa = testing.allocator;

    var rebase = Rebase{};
    defer rebase.deinit(gpa);

    try rebase.finalize(gpa);
    try testing.expectEqual(@as(u64, 0), rebase.size());
}

test "rebase - single entry" {
    const gpa = testing.allocator;

    var rebase = Rebase{};
    defer rebase.deinit(gpa);
    try rebase.entries.append(gpa, .{
        .segment_id = 1,
        .offset = 0x10,
    });
    try rebase.finalize(gpa);
    try testing.expectEqualSlices(u8, &[_]u8{
        macho.REBASE_OPCODE_SET_TYPE_IMM | macho.REBASE_TYPE_POINTER,
        macho.REBASE_OPCODE_SET_SEGMENT_AND_OFFSET_ULEB | 1,
        0x10,
        macho.REBASE_OPCODE_DO_REBASE_IMM_TIMES | 1,
        macho.REBASE_OPCODE_DONE,
    }, rebase.buffer.items);
}

test "rebase - emitTimes - IMM" {
    const gpa = testing.allocator;

    var rebase = Rebase{};
    defer rebase.deinit(gpa);

    var i: u64 = 0;
    while (i < 10) : (i += 1) {
        try rebase.entries.append(gpa, .{
            .segment_id = 1,
            .offset = i * @sizeOf(u64),
        });
    }

    try rebase.finalize(gpa);

    try testing.expectEqualSlices(u8, &[_]u8{
        macho.REBASE_OPCODE_SET_TYPE_IMM | macho.REBASE_TYPE_POINTER,
        macho.REBASE_OPCODE_SET_SEGMENT_AND_OFFSET_ULEB | 1,
        0x0,
        macho.REBASE_OPCODE_DO_REBASE_IMM_TIMES | 10,
        macho.REBASE_OPCODE_DONE,
    }, rebase.buffer.items);
}

test "rebase - emitTimes - ULEB" {
    const gpa = testing.allocator;

    var rebase = Rebase{};
    defer rebase.deinit(gpa);

    var i: u64 = 0;
    while (i < 100) : (i += 1) {
        try rebase.entries.append(gpa, .{
            .segment_id = 1,
            .offset = i * @sizeOf(u64),
        });
    }

    try rebase.finalize(gpa);

    try testing.expectEqualSlices(u8, &[_]u8{
        macho.REBASE_OPCODE_SET_TYPE_IMM | macho.REBASE_TYPE_POINTER,
        macho.REBASE_OPCODE_SET_SEGMENT_AND_OFFSET_ULEB | 1,
        0x0,
        macho.REBASE_OPCODE_DO_REBASE_ULEB_TIMES,
        0x64,
        macho.REBASE_OPCODE_DONE,
    }, rebase.buffer.items);
}

test "rebase - emitTimes followed by addAddr followed by emitTimes" {
    const gpa = testing.allocator;

    var rebase = Rebase{};
    defer rebase.deinit(gpa);

    var offset: u64 = 0;
    var i: u64 = 0;
    while (i < 15) : (i += 1) {
        try rebase.entries.append(gpa, .{
            .segment_id = 1,
            .offset = offset,
        });
        offset += @sizeOf(u64);
    }

    offset += @sizeOf(u64);

    try rebase.entries.append(gpa, .{
        .segment_id = 1,
        .offset = offset,
    });

    try rebase.finalize(gpa);

    try testing.expectEqualSlices(u8, &[_]u8{
        macho.REBASE_OPCODE_SET_TYPE_IMM | macho.REBASE_TYPE_POINTER,
        macho.REBASE_OPCODE_SET_SEGMENT_AND_OFFSET_ULEB | 1,
        0x0,
        macho.REBASE_OPCODE_DO_REBASE_IMM_TIMES | 15,
        macho.REBASE_OPCODE_ADD_ADDR_IMM_SCALED | 1,
        macho.REBASE_OPCODE_DO_REBASE_IMM_TIMES | 1,
        macho.REBASE_OPCODE_DONE,
    }, rebase.buffer.items);
}

test "rebase - emitTimesSkip" {
    const gpa = testing.allocator;

    var rebase = Rebase{};
    defer rebase.deinit(gpa);

    var offset: u64 = 0;
    var i: u64 = 0;
    while (i < 15) : (i += 1) {
        try rebase.entries.append(gpa, .{
            .segment_id = 1,
            .offset = offset,
        });
        offset += 2 * @sizeOf(u64);
    }

    try rebase.finalize(gpa);

    try testing.expectEqualSlices(u8, &[_]u8{
        macho.REBASE_OPCODE_SET_TYPE_IMM | macho.REBASE_TYPE_POINTER,
        macho.REBASE_OPCODE_SET_SEGMENT_AND_OFFSET_ULEB | 1,
        0x0,
        macho.REBASE_OPCODE_DO_REBASE_ULEB_TIMES_SKIPPING_ULEB,
        0xf,
        0x8,
        macho.REBASE_OPCODE_DONE,
    }, rebase.buffer.items);
}

test "rebase - complex" {
    const gpa = testing.allocator;

    var rebase = Rebase{};
    defer rebase.deinit(gpa);

    try rebase.entries.append(gpa, .{
        .segment_id = 1,
        .offset = 0,
    });
    try rebase.entries.append(gpa, .{
        .segment_id = 1,
        .offset = 0x10,
    });
    try rebase.entries.append(gpa, .{
        .segment_id = 1,
        .offset = 0x40,
    });
    try rebase.entries.append(gpa, .{
        .segment_id = 1,
        .offset = 0x48,
    });
    try rebase.entries.append(gpa, .{
        .segment_id = 1,
        .offset = 0x50,
    });
    try rebase.entries.append(gpa, .{
        .segment_id = 1,
        .offset = 0x58,
    });
    try rebase.entries.append(gpa, .{
        .segment_id = 1,
        .offset = 0x70,
    });
    try rebase.finalize(gpa);

    try testing.expectEqualSlices(u8, &[_]u8{
        macho.REBASE_OPCODE_SET_TYPE_IMM | macho.REBASE_TYPE_POINTER,
        macho.REBASE_OPCODE_SET_SEGMENT_AND_OFFSET_ULEB | 1,
        0x0,
        macho.REBASE_OPCODE_DO_REBASE_ULEB_TIMES_SKIPPING_ULEB,
        0x2,
        0x8,
        macho.REBASE_OPCODE_ADD_ADDR_IMM_SCALED | 4,
        macho.REBASE_OPCODE_DO_REBASE_IMM_TIMES | 4,
        macho.REBASE_OPCODE_ADD_ADDR_IMM_SCALED | 2,
        macho.REBASE_OPCODE_DO_REBASE_IMM_TIMES | 1,
        macho.REBASE_OPCODE_DONE,
    }, rebase.buffer.items);
}

test "rebase - complex 2" {
    const gpa = testing.allocator;

    var rebase = Rebase{};
    defer rebase.deinit(gpa);

    try rebase.entries.append(gpa, .{
        .segment_id = 1,
        .offset = 0,
    });
    try rebase.entries.append(gpa, .{
        .segment_id = 1,
        .offset = 0x10,
    });
    try rebase.entries.append(gpa, .{
        .segment_id = 1,
        .offset = 0x28,
    });
    try rebase.entries.append(gpa, .{
        .segment_id = 1,
        .offset = 0x48,
    });
    try rebase.entries.append(gpa, .{
        .segment_id = 1,
        .offset = 0x78,
    });
    try rebase.entries.append(gpa, .{
        .segment_id = 1,
        .offset = 0xb8,
    });
    try rebase.entries.append(gpa, .{
        .segment_id = 2,
        .offset = 0x0,
    });
    try rebase.entries.append(gpa, .{
        .segment_id = 2,
        .offset = 0x8,
    });
    try rebase.entries.append(gpa, .{
        .segment_id = 2,
        .offset = 0x10,
    });
    try rebase.entries.append(gpa, .{
        .segment_id = 2,
        .offset = 0x18,
    });
    try rebase.entries.append(gpa, .{
        .segment_id = 3,
        .offset = 0x0,
    });
    try rebase.entries.append(gpa, .{
        .segment_id = 3,
        .offset = 0x20,
    });
    try rebase.entries.append(gpa, .{
        .segment_id = 3,
        .offset = 0x40,
    });
    try rebase.entries.append(gpa, .{
        .segment_id = 3,
        .offset = 0x60,
    });
    try rebase.entries.append(gpa, .{
        .segment_id = 3,
        .offset = 0x68,
    });
    try rebase.finalize(gpa);

    try testing.expectEqualSlices(u8, &[_]u8{
        macho.REBASE_OPCODE_SET_TYPE_IMM | macho.REBASE_TYPE_POINTER,
        macho.REBASE_OPCODE_SET_SEGMENT_AND_OFFSET_ULEB | 1,
        0x0,
        macho.REBASE_OPCODE_DO_REBASE_ULEB_TIMES_SKIPPING_ULEB,
        0x2,
        0x8,
        macho.REBASE_OPCODE_ADD_ADDR_IMM_SCALED | 1,
        macho.REBASE_OPCODE_DO_REBASE_ULEB_TIMES_SKIPPING_ULEB,
        0x2,
        0x18,
        macho.REBASE_OPCODE_ADD_ADDR_IMM_SCALED | 2,
        macho.REBASE_OPCODE_DO_REBASE_ULEB_TIMES_SKIPPING_ULEB,
        0x2,
        0x38,
        macho.REBASE_OPCODE_SET_SEGMENT_AND_OFFSET_ULEB | 2,
        0x0,
        macho.REBASE_OPCODE_DO_REBASE_IMM_TIMES | 4,
        macho.REBASE_OPCODE_SET_SEGMENT_AND_OFFSET_ULEB | 3,
        0x0,
        macho.REBASE_OPCODE_DO_REBASE_ULEB_TIMES_SKIPPING_ULEB,
        0x3,
        0x18,
        macho.REBASE_OPCODE_DO_REBASE_IMM_TIMES | 2,
        macho.REBASE_OPCODE_DONE,
    }, rebase.buffer.items);
}

test "rebase - composite" {
    const gpa = testing.allocator;

    var rebase = Rebase{};
    defer rebase.deinit(gpa);

    try rebase.entries.append(gpa, .{
        .segment_id = 1,
        .offset = 0x8,
    });
    try rebase.entries.append(gpa, .{
        .segment_id = 1,
        .offset = 0x38,
    });
    try rebase.entries.append(gpa, .{
        .segment_id = 1,
        .offset = 0xa0,
    });
    try rebase.entries.append(gpa, .{
        .segment_id = 1,
        .offset = 0xa8,
    });
    try rebase.entries.append(gpa, .{
        .segment_id = 1,
        .offset = 0xb0,
    });
    try rebase.entries.append(gpa, .{
        .segment_id = 1,
        .offset = 0xc0,
    });
    try rebase.entries.append(gpa, .{
        .segment_id = 1,
        .offset = 0xc8,
    });
    try rebase.entries.append(gpa, .{
        .segment_id = 1,
        .offset = 0xd0,
    });
    try rebase.entries.append(gpa, .{
        .segment_id = 1,
        .offset = 0xd8,
    });
    try rebase.entries.append(gpa, .{
        .segment_id = 1,
        .offset = 0xe0,
    });
    try rebase.entries.append(gpa, .{
        .segment_id = 1,
        .offset = 0xe8,
    });
    try rebase.entries.append(gpa, .{
        .segment_id = 1,
        .offset = 0xf0,
    });
    try rebase.entries.append(gpa, .{
        .segment_id = 1,
        .offset = 0xf8,
    });
    try rebase.entries.append(gpa, .{
        .segment_id = 1,
        .offset = 0x108,
    });
    try rebase.finalize(gpa);

    try testing.expectEqualSlices(u8, &[_]u8{
        macho.REBASE_OPCODE_SET_TYPE_IMM | macho.REBASE_TYPE_POINTER,
        macho.REBASE_OPCODE_SET_SEGMENT_AND_OFFSET_ULEB | 1,
        0x8,
        macho.REBASE_OPCODE_DO_REBASE_ULEB_TIMES_SKIPPING_ULEB,
        0x2,
        0x28,
        macho.REBASE_OPCODE_ADD_ADDR_IMM_SCALED | 7,
        macho.REBASE_OPCODE_DO_REBASE_IMM_TIMES | 3,
        macho.REBASE_OPCODE_ADD_ADDR_IMM_SCALED | 1,
        macho.REBASE_OPCODE_DO_REBASE_IMM_TIMES | 8,
        macho.REBASE_OPCODE_ADD_ADDR_IMM_SCALED | 1,
        macho.REBASE_OPCODE_DO_REBASE_IMM_TIMES | 1,
        macho.REBASE_OPCODE_DONE,
    }, rebase.buffer.items);
}

const std = @import("std");
const assert = std.debug.assert;
const leb = std.leb;
const log = std.log.scoped(.link_dyld_info);
const macho = std.macho;
const mem = std.mem;
const testing = std.testing;
const trace = @import("../../../tracy.zig").trace;

const Allocator = mem.Allocator;
const File = @import("../file.zig").File;
const MachO = @import("../../MachO.zig");
const Rebase = @This();
