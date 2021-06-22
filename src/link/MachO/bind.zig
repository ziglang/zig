const std = @import("std");
const leb = std.leb;
const macho = std.macho;

pub const Pointer = struct {
    offset: u64,
    segment_id: u16,
    dylib_ordinal: ?i64 = null,
    name: ?[]const u8 = null,
};

pub fn pointerCmp(context: void, a: Pointer, b: Pointer) bool {
    _ = context;
    if (a.segment_id < b.segment_id) return true;
    if (a.segment_id == b.segment_id) {
        return a.offset < b.offset;
    }
    return false;
}

pub fn rebaseInfoSize(pointers: []const Pointer) !u64 {
    var stream = std.io.countingWriter(std.io.null_writer);
    var writer = stream.writer();
    var size: u64 = 0;

    for (pointers) |pointer| {
        size += 2;
        try leb.writeILEB128(writer, pointer.offset);
        size += 1;
    }

    size += 1 + stream.bytes_written;
    return size;
}

pub fn writeRebaseInfo(pointers: []const Pointer, writer: anytype) !void {
    for (pointers) |pointer| {
        try writer.writeByte(macho.REBASE_OPCODE_SET_TYPE_IMM | @truncate(u4, macho.REBASE_TYPE_POINTER));
        try writer.writeByte(macho.REBASE_OPCODE_SET_SEGMENT_AND_OFFSET_ULEB | @truncate(u4, pointer.segment_id));

        try leb.writeILEB128(writer, pointer.offset);
        try writer.writeByte(macho.REBASE_OPCODE_DO_REBASE_IMM_TIMES | @truncate(u4, 1));
    }
    try writer.writeByte(macho.REBASE_OPCODE_DONE);
}

pub fn bindInfoSize(pointers: []const Pointer) !u64 {
    var stream = std.io.countingWriter(std.io.null_writer);
    var writer = stream.writer();
    var size: u64 = 0;

    for (pointers) |pointer| {
        size += 1;
        if (pointer.dylib_ordinal.? > 15) {
            try leb.writeULEB128(writer, @bitCast(u64, pointer.dylib_ordinal.?));
        }
        size += 1;

        size += 1;
        size += pointer.name.?.len;
        size += 1;

        size += 1;

        try leb.writeILEB128(writer, pointer.offset);
        size += 1;
    }

    size += stream.bytes_written + 1;
    return size;
}

pub fn writeBindInfo(pointers: []const Pointer, writer: anytype) !void {
    for (pointers) |pointer| {
        if (pointer.dylib_ordinal.? > 15) {
            try writer.writeByte(macho.BIND_OPCODE_SET_DYLIB_ORDINAL_ULEB);
            try leb.writeULEB128(writer, @bitCast(u64, pointer.dylib_ordinal.?));
        } else if (pointer.dylib_ordinal.? > 0) {
            try writer.writeByte(macho.BIND_OPCODE_SET_DYLIB_ORDINAL_IMM | @truncate(u4, @bitCast(u64, pointer.dylib_ordinal.?)));
        } else {
            try writer.writeByte(macho.BIND_OPCODE_SET_DYLIB_SPECIAL_IMM | @truncate(u4, @bitCast(u64, pointer.dylib_ordinal.?)));
        }
        try writer.writeByte(macho.BIND_OPCODE_SET_TYPE_IMM | @truncate(u4, macho.BIND_TYPE_POINTER));

        try writer.writeByte(macho.BIND_OPCODE_SET_SYMBOL_TRAILING_FLAGS_IMM); // TODO Sometimes we might want to add flags.
        try writer.writeAll(pointer.name.?);
        try writer.writeByte(0);

        try writer.writeByte(macho.BIND_OPCODE_SET_SEGMENT_AND_OFFSET_ULEB | @truncate(u4, pointer.segment_id));

        try leb.writeILEB128(writer, pointer.offset);
        try writer.writeByte(macho.BIND_OPCODE_DO_BIND);
    }

    try writer.writeByte(macho.BIND_OPCODE_DONE);
}

pub fn lazyBindInfoSize(pointers: []const Pointer) !u64 {
    var stream = std.io.countingWriter(std.io.null_writer);
    var writer = stream.writer();
    var size: u64 = 0;

    for (pointers) |pointer| {
        size += 1;

        try leb.writeILEB128(writer, pointer.offset);

        size += 1;
        if (pointer.dylib_ordinal.? > 15) {
            try leb.writeULEB128(writer, @bitCast(u64, pointer.dylib_ordinal.?));
        }

        size += 1;
        size += pointer.name.?.len;
        size += 1;

        size += 2;
    }

    size += stream.bytes_written;
    return size;
}

pub fn writeLazyBindInfo(pointers: []const Pointer, writer: anytype) !void {
    for (pointers) |pointer| {
        try writer.writeByte(macho.BIND_OPCODE_SET_SEGMENT_AND_OFFSET_ULEB | @truncate(u4, pointer.segment_id));

        try leb.writeILEB128(writer, pointer.offset);

        if (pointer.dylib_ordinal.? > 15) {
            try writer.writeByte(macho.BIND_OPCODE_SET_DYLIB_ORDINAL_ULEB);
            try leb.writeULEB128(writer, @bitCast(u64, pointer.dylib_ordinal.?));
        } else if (pointer.dylib_ordinal.? > 0) {
            try writer.writeByte(macho.BIND_OPCODE_SET_DYLIB_ORDINAL_IMM | @truncate(u4, @bitCast(u64, pointer.dylib_ordinal.?)));
        } else {
            try writer.writeByte(macho.BIND_OPCODE_SET_DYLIB_SPECIAL_IMM | @truncate(u4, @bitCast(u64, pointer.dylib_ordinal.?)));
        }

        try writer.writeByte(macho.BIND_OPCODE_SET_SYMBOL_TRAILING_FLAGS_IMM); // TODO Sometimes we might want to add flags.
        try writer.writeAll(pointer.name.?);
        try writer.writeByte(0);

        try writer.writeByte(macho.BIND_OPCODE_DO_BIND);
        try writer.writeByte(macho.BIND_OPCODE_DONE);
    }
}
