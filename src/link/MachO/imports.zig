const std = @import("std");
const leb = std.leb;
const macho = std.macho;
const mem = std.mem;

const assert = std.debug.assert;
const Allocator = mem.Allocator;

pub const ExternSymbol = struct {
    /// Symbol name.
    /// We own the memory, therefore we'll need to free it by calling `deinit`.
    /// In self-hosted, we don't expect it to be null ever.
    /// However, this is for backwards compatibility with LLD when
    /// we'll be patching things up post mortem.
    name: ?[]u8 = null,

    /// Id of the dynamic library where the specified entries can be found.
    /// Id of 0 means self.
    /// TODO this should really be an id into the table of all defined
    /// dylibs.
    dylib_ordinal: i64 = 0,

    segment: u16 = 0,
    offset: u32 = 0,
    addend: ?i32 = null,
    index: u32,

    pub fn deinit(self: *ExternSymbol, allocator: *Allocator) void {
        if (self.name) |*name| {
            allocator.free(name);
        }
    }
};

pub fn rebaseInfoSize(symbols: []*const ExternSymbol) !u64 {
    var stream = std.io.countingWriter(std.io.null_writer);
    var writer = stream.writer();
    var size: u64 = 0;

    for (symbols) |symbol| {
        size += 2;
        try leb.writeILEB128(writer, symbol.offset);
        size += 1;
    }

    size += 1 + stream.bytes_written;
    return size;
}

pub fn writeRebaseInfo(symbols: []*const ExternSymbol, writer: anytype) !void {
    for (symbols) |symbol| {
        try writer.writeByte(macho.REBASE_OPCODE_SET_TYPE_IMM | @truncate(u4, macho.REBASE_TYPE_POINTER));
        try writer.writeByte(macho.REBASE_OPCODE_SET_SEGMENT_AND_OFFSET_ULEB | @truncate(u4, symbol.segment));
        try leb.writeILEB128(writer, symbol.offset);
        try writer.writeByte(macho.REBASE_OPCODE_DO_REBASE_IMM_TIMES | @truncate(u4, 1));
    }
    try writer.writeByte(macho.REBASE_OPCODE_DONE);
}

pub fn bindInfoSize(symbols: []*const ExternSymbol) !u64 {
    var stream = std.io.countingWriter(std.io.null_writer);
    var writer = stream.writer();
    var size: u64 = 0;

    for (symbols) |symbol| {
        size += 1;
        if (symbol.dylib_ordinal > 15) {
            try leb.writeULEB128(writer, @bitCast(u64, symbol.dylib_ordinal));
        }
        size += 1;

        if (symbol.name) |name| {
            size += 1;
            size += name.len;
            size += 1;
        }

        size += 1;
        try leb.writeILEB128(writer, symbol.offset);

        if (symbol.addend) |addend| {
            size += 1;
            try leb.writeILEB128(writer, addend);
        }

        size += 2;
    }

    size += stream.bytes_written;
    return size;
}

pub fn writeBindInfo(symbols: []*const ExternSymbol, writer: anytype) !void {
    for (symbols) |symbol| {
        if (symbol.dylib_ordinal > 15) {
            try writer.writeByte(macho.BIND_OPCODE_SET_DYLIB_ORDINAL_ULEB);
            try leb.writeULEB128(writer, @bitCast(u64, symbol.dylib_ordinal));
        } else if (symbol.dylib_ordinal > 0) {
            try writer.writeByte(macho.BIND_OPCODE_SET_DYLIB_ORDINAL_IMM | @truncate(u4, @bitCast(u64, symbol.dylib_ordinal)));
        } else {
            try writer.writeByte(macho.BIND_OPCODE_SET_DYLIB_SPECIAL_IMM | @truncate(u4, @bitCast(u64, symbol.dylib_ordinal)));
        }
        try writer.writeByte(macho.BIND_OPCODE_SET_TYPE_IMM | @truncate(u4, macho.BIND_TYPE_POINTER));

        if (symbol.name) |name| {
            try writer.writeByte(macho.BIND_OPCODE_SET_SYMBOL_TRAILING_FLAGS_IMM); // TODO Sometimes we might want to add flags.
            try writer.writeAll(name);
            try writer.writeByte(0);
        }

        try writer.writeByte(macho.BIND_OPCODE_SET_SEGMENT_AND_OFFSET_ULEB | @truncate(u4, symbol.segment));
        try leb.writeILEB128(writer, symbol.offset);

        if (symbol.addend) |addend| {
            try writer.writeByte(macho.BIND_OPCODE_SET_ADDEND_SLEB);
            try leb.writeILEB128(writer, addend);
        }

        try writer.writeByte(macho.BIND_OPCODE_DO_BIND);
        try writer.writeByte(macho.BIND_OPCODE_DONE);
    }
}

pub fn lazyBindInfoSize(symbols: []*const ExternSymbol) !u64 {
    var stream = std.io.countingWriter(std.io.null_writer);
    var writer = stream.writer();
    var size: u64 = 0;

    for (symbols) |symbol| {
        size += 1;
        try leb.writeILEB128(writer, symbol.offset);

        if (symbol.addend) |addend| {
            size += 1;
            try leb.writeILEB128(writer, addend);
        }

        size += 1;
        if (symbol.dylib_ordinal > 15) {
            try leb.writeULEB128(writer, @bitCast(u64, symbol.dylib_ordinal));
        }
        if (symbol.name) |name| {
            size += 1;
            size += name.len;
            size += 1;
        }
        size += 2;
    }

    size += stream.bytes_written;
    return size;
}

pub fn writeLazyBindInfo(symbols: []*const ExternSymbol, writer: anytype) !void {
    for (symbols) |symbol| {
        try writer.writeByte(macho.BIND_OPCODE_SET_SEGMENT_AND_OFFSET_ULEB | @truncate(u4, symbol.segment));
        try leb.writeILEB128(writer, symbol.offset);

        if (symbol.addend) |addend| {
            try writer.writeByte(macho.BIND_OPCODE_SET_ADDEND_SLEB);
            try leb.writeILEB128(writer, addend);
        }

        if (symbol.dylib_ordinal > 15) {
            try writer.writeByte(macho.BIND_OPCODE_SET_DYLIB_ORDINAL_ULEB);
            try leb.writeULEB128(writer, @bitCast(u64, symbol.dylib_ordinal));
        } else if (symbol.dylib_ordinal > 0) {
            try writer.writeByte(macho.BIND_OPCODE_SET_DYLIB_ORDINAL_IMM | @truncate(u4, @bitCast(u64, symbol.dylib_ordinal)));
        } else {
            try writer.writeByte(macho.BIND_OPCODE_SET_DYLIB_SPECIAL_IMM | @truncate(u4, @bitCast(u64, symbol.dylib_ordinal)));
        }

        if (symbol.name) |name| {
            try writer.writeByte(macho.BIND_OPCODE_SET_SYMBOL_TRAILING_FLAGS_IMM); // TODO Sometimes we might want to add flags.
            try writer.writeAll(name);
            try writer.writeByte(0);
        }

        try writer.writeByte(macho.BIND_OPCODE_DO_BIND);
        try writer.writeByte(macho.BIND_OPCODE_DONE);
    }
}
