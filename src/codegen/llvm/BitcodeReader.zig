allocator: std.mem.Allocator,
record_arena: std.heap.ArenaAllocator.State,
reader: std.io.AnyReader,
keep_names: bool,
bit_buffer: u32,
bit_offset: u5,
stack: std.ArrayListUnmanaged(State),
block_info: std.AutoHashMapUnmanaged(u32, Block.Info),

pub const Item = union(enum) {
    start_block: Block,
    record: Record,
    end_block: Block,
};

pub const Block = struct {
    name: []const u8,
    id: u32,
    len: u32,

    const block_info: u32 = 0;
    const first_reserved: u32 = 1;
    const last_standard: u32 = 7;

    const Info = struct {
        block_name: []const u8,
        record_names: std.AutoHashMapUnmanaged(u32, []const u8),
        abbrevs: Abbrev.Store,

        const default: Info = .{
            .block_name = &.{},
            .record_names = .{},
            .abbrevs = .{ .abbrevs = .{} },
        };

        const set_bid: u32 = 1;
        const block_name: u32 = 2;
        const set_record_name: u32 = 3;

        fn deinit(info: *Info, allocator: std.mem.Allocator) void {
            allocator.free(info.block_name);
            var record_names_it = info.record_names.valueIterator();
            while (record_names_it.next()) |record_name| allocator.free(record_name.*);
            info.record_names.deinit(allocator);
            info.abbrevs.deinit(allocator);
            info.* = undefined;
        }
    };
};

pub const Record = struct {
    name: []const u8,
    id: u32,
    operands: []const u64,
    blob: []const u8,

    fn toOwnedAbbrev(record: Record, allocator: std.mem.Allocator) !Abbrev {
        var operands = std.ArrayList(Abbrev.Operand).init(allocator);
        defer operands.deinit();

        assert(record.id == Abbrev.Builtin.define_abbrev.toRecordId());
        var i: usize = 0;
        while (i < record.operands.len) switch (record.operands[i]) {
            Abbrev.Operand.literal => {
                try operands.append(.{ .literal = record.operands[i + 1] });
                i += 2;
            },
            @intFromEnum(Abbrev.Operand.Encoding.fixed) => {
                try operands.append(.{ .encoding = .{ .fixed = @intCast(record.operands[i + 1]) } });
                i += 2;
            },
            @intFromEnum(Abbrev.Operand.Encoding.vbr) => {
                try operands.append(.{ .encoding = .{ .vbr = @intCast(record.operands[i + 1]) } });
                i += 2;
            },
            @intFromEnum(Abbrev.Operand.Encoding.array) => {
                try operands.append(.{ .encoding = .{ .array = 6 } });
                i += 1;
            },
            @intFromEnum(Abbrev.Operand.Encoding.char6) => {
                try operands.append(.{ .encoding = .char6 });
                i += 1;
            },
            @intFromEnum(Abbrev.Operand.Encoding.blob) => {
                try operands.append(.{ .encoding = .{ .blob = 6 } });
                i += 1;
            },
            else => unreachable,
        };

        return .{ .operands = try operands.toOwnedSlice() };
    }
};

pub const InitOptions = struct {
    reader: std.io.AnyReader,
    keep_names: bool = false,
};
pub fn init(allocator: std.mem.Allocator, options: InitOptions) BitcodeReader {
    return .{
        .allocator = allocator,
        .record_arena = .{},
        .reader = options.reader,
        .keep_names = options.keep_names,
        .bit_buffer = 0,
        .bit_offset = 0,
        .stack = .{},
        .block_info = .{},
    };
}

pub fn deinit(bc: *BitcodeReader) void {
    var block_info_it = bc.block_info.valueIterator();
    while (block_info_it.next()) |block_info| block_info.deinit(bc.allocator);
    bc.block_info.deinit(bc.allocator);
    for (bc.stack.items) |*state| state.deinit(bc.allocator);
    bc.stack.deinit(bc.allocator);
    bc.record_arena.promote(bc.allocator).deinit();
    bc.* = undefined;
}

pub fn checkMagic(bc: *BitcodeReader, magic: *const [4]u8) !void {
    var buffer: [4]u8 = undefined;
    try bc.readBytes(&buffer);
    if (!std.mem.eql(u8, &buffer, magic)) return error.InvalidMagic;

    try bc.startBlock(null, 2);
    try bc.block_info.put(bc.allocator, Block.block_info, Block.Info.default);
}

pub fn next(bc: *BitcodeReader) !?Item {
    while (true) {
        const record = (try bc.nextRecord()) orelse
            return if (bc.stack.items.len > 1) error.EndOfStream else null;
        switch (record.id) {
            else => return .{ .record = record },
            Abbrev.Builtin.end_block.toRecordId() => {
                const block_id = bc.stack.items[bc.stack.items.len - 1].block_id.?;
                try bc.endBlock();
                return .{ .end_block = .{
                    .name = if (bc.block_info.get(block_id)) |block_info|
                        block_info.block_name
                    else
                        &.{},
                    .id = block_id,
                    .len = 0,
                } };
            },
            Abbrev.Builtin.enter_subblock.toRecordId() => {
                const block_id: u32 = @intCast(record.operands[0]);
                switch (block_id) {
                    Block.block_info => try bc.parseBlockInfoBlock(),
                    Block.first_reserved...Block.last_standard => return error.UnsupportedBlockId,
                    else => {
                        try bc.startBlock(block_id, @intCast(record.operands[1]));
                        return .{ .start_block = .{
                            .name = if (bc.block_info.get(block_id)) |block_info|
                                block_info.block_name
                            else
                                &.{},
                            .id = block_id,
                            .len = @intCast(record.operands[2]),
                        } };
                    },
                }
            },
            Abbrev.Builtin.define_abbrev.toRecordId() => try bc.stack.items[bc.stack.items.len - 1]
                .abbrevs.addOwnedAbbrev(bc.allocator, try record.toOwnedAbbrev(bc.allocator)),
        }
    }
}

pub fn skipBlock(bc: *BitcodeReader, block: Block) !void {
    assert(bc.bit_offset == 0);
    try bc.reader.skipBytes(@as(u34, block.len) * 4, .{});
    try bc.endBlock();
}

fn nextRecord(bc: *BitcodeReader) !?Record {
    const state = &bc.stack.items[bc.stack.items.len - 1];
    const abbrev_id = bc.readFixed(u32, state.abbrev_id_width) catch |err| switch (err) {
        error.EndOfStream => return null,
        else => |e| return e,
    };
    if (abbrev_id >= state.abbrevs.abbrevs.items.len) return error.InvalidAbbrevId;
    const abbrev = state.abbrevs.abbrevs.items[abbrev_id];

    var record_arena = bc.record_arena.promote(bc.allocator);
    defer bc.record_arena = record_arena.state;
    _ = record_arena.reset(.retain_capacity);

    var operands = try std.ArrayList(u64).initCapacity(record_arena.allocator(), abbrev.operands.len);
    var blob = std.ArrayList(u8).init(record_arena.allocator());
    for (abbrev.operands, 0..) |abbrev_operand, abbrev_operand_i| switch (abbrev_operand) {
        .literal => |value| operands.appendAssumeCapacity(value),
        .encoding => |abbrev_encoding| switch (abbrev_encoding) {
            .fixed => |width| operands.appendAssumeCapacity(try bc.readFixed(u64, width)),
            .vbr => |width| operands.appendAssumeCapacity(try bc.readVbr(u64, width)),
            .array => |len_width| {
                assert(abbrev_operand_i + 2 == abbrev.operands.len);
                const len: usize = @intCast(try bc.readVbr(u32, len_width));
                try operands.ensureUnusedCapacity(len);
                for (0..len) |_| switch (abbrev.operands[abbrev.operands.len - 1]) {
                    .literal => |elem_value| operands.appendAssumeCapacity(elem_value),
                    .encoding => |elem_encoding| switch (elem_encoding) {
                        .fixed => |elem_width| operands.appendAssumeCapacity(try bc.readFixed(u64, elem_width)),
                        .vbr => |elem_width| operands.appendAssumeCapacity(try bc.readVbr(u64, elem_width)),
                        .array, .blob => return error.InvalidArrayElement,
                        .char6 => operands.appendAssumeCapacity(try bc.readChar6()),
                    },
                    .align_32_bits, .block_len => return error.UnsupportedArrayElement,
                    .abbrev_op => switch (try bc.readFixed(u1, 1)) {
                        1 => try operands.appendSlice(&.{
                            Abbrev.Operand.literal,
                            try bc.readVbr(u64, 8),
                        }),
                        0 => {
                            const encoding: Abbrev.Operand.Encoding =
                                @enumFromInt(try bc.readFixed(u3, 3));
                            try operands.append(@intFromEnum(encoding));
                            switch (encoding) {
                                .fixed, .vbr => try operands.append(try bc.readVbr(u7, 5)),
                                .array, .char6, .blob => {},
                                _ => return error.UnsuportedAbbrevEncoding,
                            }
                        },
                    },
                };
                break;
            },
            .char6 => operands.appendAssumeCapacity(try bc.readChar6()),
            .blob => |len_width| {
                assert(abbrev_operand_i + 1 == abbrev.operands.len);
                const len = std.math.cast(usize, try bc.readVbr(u32, len_width)) orelse
                    return error.Overflow;
                bc.align32Bits();
                try bc.readBytes(try blob.addManyAsSlice(len));
                bc.align32Bits();
            },
        },
        .align_32_bits => bc.align32Bits(),
        .block_len => operands.appendAssumeCapacity(try bc.read32Bits()),
        .abbrev_op => unreachable,
    };
    return .{
        .name = name: {
            if (operands.items.len < 1) break :name &.{};
            const record_id = std.math.cast(u32, operands.items[0]) orelse break :name &.{};
            if (state.block_id) |block_id| {
                if (bc.block_info.get(block_id)) |block_info| {
                    break :name block_info.record_names.get(record_id) orelse break :name &.{};
                }
            }
            break :name &.{};
        },
        .id = std.math.cast(u32, operands.items[0]) orelse return error.InvalidRecordId,
        .operands = operands.items[1..],
        .blob = blob.items,
    };
}

fn startBlock(bc: *BitcodeReader, block_id: ?u32, new_abbrev_len: u6) !void {
    const abbrevs = if (block_id) |id|
        if (bc.block_info.get(id)) |block_info| block_info.abbrevs.abbrevs.items else &.{}
    else
        &.{};

    const state = try bc.stack.addOne(bc.allocator);
    state.* = .{
        .block_id = block_id,
        .abbrev_id_width = new_abbrev_len,
        .abbrevs = .{ .abbrevs = .{} },
    };
    try state.abbrevs.abbrevs.ensureTotalCapacity(
        bc.allocator,
        @typeInfo(Abbrev.Builtin).Enum.fields.len + abbrevs.len,
    );

    assert(state.abbrevs.abbrevs.items.len == @intFromEnum(Abbrev.Builtin.end_block));
    try state.abbrevs.addAbbrevAssumeCapacity(bc.allocator, .{
        .operands = &.{
            .{ .literal = Abbrev.Builtin.end_block.toRecordId() },
            .align_32_bits,
        },
    });
    assert(state.abbrevs.abbrevs.items.len == @intFromEnum(Abbrev.Builtin.enter_subblock));
    try state.abbrevs.addAbbrevAssumeCapacity(bc.allocator, .{
        .operands = &.{
            .{ .literal = Abbrev.Builtin.enter_subblock.toRecordId() },
            .{ .encoding = .{ .vbr = 8 } }, // blockid
            .{ .encoding = .{ .vbr = 4 } }, // newabbrevlen
            .align_32_bits,
            .block_len,
        },
    });
    assert(state.abbrevs.abbrevs.items.len == @intFromEnum(Abbrev.Builtin.define_abbrev));
    try state.abbrevs.addAbbrevAssumeCapacity(bc.allocator, .{
        .operands = &.{
            .{ .literal = Abbrev.Builtin.define_abbrev.toRecordId() },
            .{ .encoding = .{ .array = 5 } }, // numabbrevops
            .abbrev_op,
        },
    });
    assert(state.abbrevs.abbrevs.items.len == @intFromEnum(Abbrev.Builtin.unabbrev_record));
    try state.abbrevs.addAbbrevAssumeCapacity(bc.allocator, .{
        .operands = &.{
            .{ .encoding = .{ .vbr = 6 } }, // code
            .{ .encoding = .{ .array = 6 } }, // numops
            .{ .encoding = .{ .vbr = 6 } }, // ops
        },
    });
    assert(state.abbrevs.abbrevs.items.len == @typeInfo(Abbrev.Builtin).Enum.fields.len);
    for (abbrevs) |abbrev| try state.abbrevs.addAbbrevAssumeCapacity(bc.allocator, abbrev);
}

fn endBlock(bc: *BitcodeReader) !void {
    if (bc.stack.items.len == 0) return error.InvalidEndBlock;
    bc.stack.items[bc.stack.items.len - 1].deinit(bc.allocator);
    bc.stack.items.len -= 1;
}

fn parseBlockInfoBlock(bc: *BitcodeReader) !void {
    var block_id: ?u32 = null;
    while (true) {
        const record = (try bc.nextRecord()) orelse return error.EndOfStream;
        switch (record.id) {
            Abbrev.Builtin.end_block.toRecordId() => break,
            Abbrev.Builtin.define_abbrev.toRecordId() => {
                const gop = try bc.block_info.getOrPut(bc.allocator, block_id orelse
                    return error.UnspecifiedBlockId);
                if (!gop.found_existing) gop.value_ptr.* = Block.Info.default;
                try gop.value_ptr.abbrevs.addOwnedAbbrev(
                    bc.allocator,
                    try record.toOwnedAbbrev(bc.allocator),
                );
            },
            Block.Info.set_bid => block_id = std.math.cast(u32, record.operands[0]) orelse
                return error.Overflow,
            Block.Info.block_name => if (bc.keep_names) {
                const gop = try bc.block_info.getOrPut(bc.allocator, block_id orelse
                    return error.UnspecifiedBlockId);
                if (!gop.found_existing) gop.value_ptr.* = Block.Info.default;
                const name = try bc.allocator.alloc(u8, record.operands.len);
                errdefer bc.allocator.free(name);
                for (name, record.operands) |*byte, operand|
                    byte.* = std.math.cast(u8, operand) orelse return error.InvalidName;
                gop.value_ptr.block_name = name;
            },
            Block.Info.set_record_name => if (bc.keep_names) {
                const gop = try bc.block_info.getOrPut(bc.allocator, block_id orelse
                    return error.UnspecifiedBlockId);
                if (!gop.found_existing) gop.value_ptr.* = Block.Info.default;
                const name = try bc.allocator.alloc(u8, record.operands.len - 1);
                errdefer bc.allocator.free(name);
                for (name, record.operands[1..]) |*byte, operand|
                    byte.* = std.math.cast(u8, operand) orelse return error.InvalidName;
                try gop.value_ptr.record_names.put(
                    bc.allocator,
                    std.math.cast(u32, record.operands[0]) orelse return error.Overflow,
                    name,
                );
            },
            else => return error.UnsupportedBlockInfoRecord,
        }
    }
}

fn align32Bits(bc: *BitcodeReader) void {
    bc.bit_offset = 0;
}

fn read32Bits(bc: *BitcodeReader) !u32 {
    assert(bc.bit_offset == 0);
    return bc.reader.readInt(u32, .little);
}

fn readBytes(bc: *BitcodeReader, bytes: []u8) !void {
    assert(bc.bit_offset == 0);
    try bc.reader.readNoEof(bytes);

    const trailing_bytes = bytes.len % 4;
    if (trailing_bytes > 0) {
        var bit_buffer = [1]u8{0} ** 4;
        try bc.reader.readNoEof(bit_buffer[trailing_bytes..]);
        bc.bit_buffer = std.mem.readInt(u32, &bit_buffer, .little);
        bc.bit_offset = @intCast(trailing_bytes * 8);
    }
}

fn readFixed(bc: *BitcodeReader, comptime T: type, bits: u7) !T {
    var result: T = 0;
    var shift: std.math.Log2IntCeil(T) = 0;
    var remaining = bits;
    while (remaining > 0) {
        if (bc.bit_offset == 0) bc.bit_buffer = try bc.read32Bits();
        const chunk_len = @min(@as(u6, 32) - bc.bit_offset, remaining);
        const chunk_mask = @as(u32, std.math.maxInt(u32)) >> @intCast(32 - chunk_len);
        result |= @as(T, @intCast(bc.bit_buffer >> bc.bit_offset & chunk_mask)) << @intCast(shift);
        shift += @intCast(chunk_len);
        remaining -= chunk_len;
        bc.bit_offset = @truncate(bc.bit_offset + chunk_len);
    }
    return result;
}

fn readVbr(bc: *BitcodeReader, comptime T: type, bits: u7) !T {
    const chunk_bits: u6 = @intCast(bits - 1);
    const chunk_msb = @as(u64, 1) << chunk_bits;

    var result: u64 = 0;
    var shift: u6 = 0;
    while (true) {
        const chunk = try bc.readFixed(u64, bits);
        result |= (chunk & (chunk_msb - 1)) << shift;
        if (chunk & chunk_msb == 0) break;
        shift += chunk_bits;
    }
    return @intCast(result);
}

fn readChar6(bc: *BitcodeReader) !u8 {
    return switch (try bc.readFixed(u6, 6)) {
        0...25 => |c| @as(u8, c - 0) + 'a',
        26...51 => |c| @as(u8, c - 26) + 'A',
        52...61 => |c| @as(u8, c - 52) + '0',
        62 => '.',
        63 => '_',
    };
}

const State = struct {
    block_id: ?u32,
    abbrev_id_width: u6,
    abbrevs: Abbrev.Store,

    fn deinit(state: *State, allocator: std.mem.Allocator) void {
        state.abbrevs.deinit(allocator);
        state.* = undefined;
    }
};

const Abbrev = struct {
    operands: []const Operand,

    const Builtin = enum(u2) {
        end_block,
        enter_subblock,
        define_abbrev,
        unabbrev_record,

        const first_record_id: u32 = std.math.maxInt(u32) - @typeInfo(Builtin).Enum.fields.len + 1;
        fn toRecordId(builtin: Builtin) u32 {
            return first_record_id + @intFromEnum(builtin);
        }
    };

    const Operand = union(enum) {
        literal: u64,
        encoding: union(Encoding) {
            fixed: u7,
            vbr: u6,
            array: u3,
            char6,
            blob: u3,
        },
        align_32_bits,
        block_len,
        abbrev_op,

        const literal = std.math.maxInt(u64);
        const Encoding = enum(u3) {
            fixed = 1,
            vbr = 2,
            array = 3,
            char6 = 4,
            blob = 5,
            _,
        };
    };

    const Store = struct {
        abbrevs: std.ArrayListUnmanaged(Abbrev),

        fn deinit(store: *Store, allocator: std.mem.Allocator) void {
            for (store.abbrevs.items) |abbrev| allocator.free(abbrev.operands);
            store.abbrevs.deinit(allocator);
            store.* = undefined;
        }

        fn addAbbrev(store: *Store, allocator: std.mem.Allocator, abbrev: Abbrev) !void {
            try store.ensureUnusedCapacity(allocator, 1);
            store.addAbbrevAssumeCapacity(abbrev);
        }

        fn addAbbrevAssumeCapacity(store: *Store, allocator: std.mem.Allocator, abbrev: Abbrev) !void {
            store.abbrevs.appendAssumeCapacity(.{
                .operands = try allocator.dupe(Abbrev.Operand, abbrev.operands),
            });
        }

        fn addOwnedAbbrev(store: *Store, allocator: std.mem.Allocator, abbrev: Abbrev) !void {
            try store.abbrevs.ensureUnusedCapacity(allocator, 1);
            store.addOwnedAbbrevAssumeCapacity(abbrev);
        }

        fn addOwnedAbbrevAssumeCapacity(store: *Store, abbrev: Abbrev) void {
            store.abbrevs.appendAssumeCapacity(abbrev);
        }
    };
};

const assert = std.debug.assert;
const std = @import("std");

const BitcodeReader = @This();
