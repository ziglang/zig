const std = @import("std");
const leb = std.leb;
const macho = std.macho;
const mem = std.mem;

const assert = std.debug.assert;
const Allocator = mem.Allocator;

pub const ExternSymbol = struct {
    /// MachO symbol table entry.
    inner: macho.nlist_64,

    /// Id of the dynamic library where the specified entries can be found.
    /// Id of 0 means self.
    /// TODO this should really be an id into the table of all defined
    /// dylibs.
    dylib_ordinal: i64 = 0,

    /// Id of the segment where this symbol is defined (will have its address
    /// resolved).
    segment: u16 = 0,

    /// Offset relative to the start address of the `segment`.
    offset: u32 = 0,
};

pub fn rebaseInfoSize(symbols: anytype) !u64 {
    var stream = std.io.countingWriter(std.io.null_writer);
    var writer = stream.writer();
    var size: u64 = 0;

    for (symbols) |entry| {
        size += 2;
        try leb.writeILEB128(writer, entry.value.offset);
        size += 1;
    }

    size += 1 + stream.bytes_written;
    return size;
}

pub fn writeRebaseInfo(symbols: anytype, writer: anytype) !void {
    for (symbols) |entry| {
        const symbol = entry.value;
        try writer.writeByte(macho.REBASE_OPCODE_SET_TYPE_IMM | @truncate(u4, macho.REBASE_TYPE_POINTER));
        try writer.writeByte(macho.REBASE_OPCODE_SET_SEGMENT_AND_OFFSET_ULEB | @truncate(u4, symbol.segment));
        try leb.writeILEB128(writer, symbol.offset);
        try writer.writeByte(macho.REBASE_OPCODE_DO_REBASE_IMM_TIMES | @truncate(u4, 1));
    }
    try writer.writeByte(macho.REBASE_OPCODE_DONE);
}

pub fn bindInfoSize(symbols: anytype) !u64 {
    var stream = std.io.countingWriter(std.io.null_writer);
    var writer = stream.writer();
    var size: u64 = 0;

    for (symbols) |entry| {
        const symbol = entry.value;

        size += 1;
        if (symbol.dylib_ordinal > 15) {
            try leb.writeULEB128(writer, @bitCast(u64, symbol.dylib_ordinal));
        }
        size += 1;

        size += 1;
        size += entry.key.len;
        size += 1;

        size += 1;
        try leb.writeILEB128(writer, symbol.offset);
        size += 2;
    }

    size += stream.bytes_written;
    return size;
}

pub fn writeBindInfo(symbols: anytype, writer: anytype) !void {
    for (symbols) |entry| {
        const symbol = entry.value;

        if (symbol.dylib_ordinal > 15) {
            try writer.writeByte(macho.BIND_OPCODE_SET_DYLIB_ORDINAL_ULEB);
            try leb.writeULEB128(writer, @bitCast(u64, symbol.dylib_ordinal));
        } else if (symbol.dylib_ordinal > 0) {
            try writer.writeByte(macho.BIND_OPCODE_SET_DYLIB_ORDINAL_IMM | @truncate(u4, @bitCast(u64, symbol.dylib_ordinal)));
        } else {
            try writer.writeByte(macho.BIND_OPCODE_SET_DYLIB_SPECIAL_IMM | @truncate(u4, @bitCast(u64, symbol.dylib_ordinal)));
        }
        try writer.writeByte(macho.BIND_OPCODE_SET_TYPE_IMM | @truncate(u4, macho.BIND_TYPE_POINTER));

        try writer.writeByte(macho.BIND_OPCODE_SET_SYMBOL_TRAILING_FLAGS_IMM); // TODO Sometimes we might want to add flags.
        try writer.writeAll(entry.key);
        try writer.writeByte(0);

        try writer.writeByte(macho.BIND_OPCODE_SET_SEGMENT_AND_OFFSET_ULEB | @truncate(u4, symbol.segment));
        try leb.writeILEB128(writer, symbol.offset);
        try writer.writeByte(macho.BIND_OPCODE_DO_BIND);
        try writer.writeByte(macho.BIND_OPCODE_DONE);
    }
}

pub fn lazyBindInfoSize(symbols: anytype) !u64 {
    var stream = std.io.countingWriter(std.io.null_writer);
    var writer = stream.writer();
    var size: u64 = 0;

    for (symbols) |entry| {
        const symbol = entry.value;
        size += 1;
        try leb.writeILEB128(writer, symbol.offset);
        size += 1;
        if (symbol.dylib_ordinal > 15) {
            try leb.writeULEB128(writer, @bitCast(u64, symbol.dylib_ordinal));
        }

        size += 1;
        size += entry.key.len;
        size += 1;

        size += 2;
    }

    size += stream.bytes_written;
    return size;
}

pub fn writeLazyBindInfo(symbols: anytype, writer: anytype) !void {
    for (symbols) |entry| {
        const symbol = entry.value;
        try writer.writeByte(macho.BIND_OPCODE_SET_SEGMENT_AND_OFFSET_ULEB | @truncate(u4, symbol.segment));
        try leb.writeILEB128(writer, symbol.offset);

        if (symbol.dylib_ordinal > 15) {
            try writer.writeByte(macho.BIND_OPCODE_SET_DYLIB_ORDINAL_ULEB);
            try leb.writeULEB128(writer, @bitCast(u64, symbol.dylib_ordinal));
        } else if (symbol.dylib_ordinal > 0) {
            try writer.writeByte(macho.BIND_OPCODE_SET_DYLIB_ORDINAL_IMM | @truncate(u4, @bitCast(u64, symbol.dylib_ordinal)));
        } else {
            try writer.writeByte(macho.BIND_OPCODE_SET_DYLIB_SPECIAL_IMM | @truncate(u4, @bitCast(u64, symbol.dylib_ordinal)));
        }

        try writer.writeByte(macho.BIND_OPCODE_SET_SYMBOL_TRAILING_FLAGS_IMM); // TODO Sometimes we might want to add flags.
        try writer.writeAll(entry.key);
        try writer.writeByte(0);

        try writer.writeByte(macho.BIND_OPCODE_DO_BIND);
        try writer.writeByte(macho.BIND_OPCODE_DONE);
    }
}
