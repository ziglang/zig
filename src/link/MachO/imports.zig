const std = @import("std");
const leb = std.leb;
const macho = std.macho;
const mem = std.mem;

const assert = std.debug.assert;
const Allocator = mem.Allocator;

/// Table of binding info entries used to tell the dyld which
/// symbols to bind at loading time.
pub const BindingInfoTable = struct {
    /// Id of the dynamic library where the specified entries can be found.
    dylib_ordinal: i64 = 0,

    /// Binding type; defaults to pointer type.
    binding_type: u8 = macho.BIND_TYPE_POINTER,

    symbols: std.ArrayListUnmanaged(Symbol) = .{},

    pub const Symbol = struct {
        /// Symbol name.
        name: ?[]u8 = null,

        /// Id of the segment where to bind this symbol to.
        segment: u8,

        /// Offset of this symbol wrt to the segment id encoded in `segment`.
        offset: i64,

        /// Addend value (if any).
        addend: ?i64 = null,
    };

    pub fn deinit(self: *BindingInfoTable, allocator: *Allocator) void {
        for (self.symbols.items) |*symbol| {
            if (symbol.name) |name| {
                allocator.free(name);
            }
        }
        self.symbols.deinit(allocator);
    }

    /// Parse the binding info table from byte stream.
    pub fn read(self: *BindingInfoTable, reader: anytype, allocator: *Allocator) !void {
        var symbol: Symbol = .{
            .segment = 0,
            .offset = 0,
        };

        var dylib_ordinal_set = false;
        var done = false;
        while (true) {
            const inst = reader.readByte() catch |err| switch (err) {
                error.EndOfStream => break,
                else => return err,
            };
            const imm: u8 = inst & macho.BIND_IMMEDIATE_MASK;
            const opcode: u8 = inst & macho.BIND_OPCODE_MASK;

            switch (opcode) {
                macho.BIND_OPCODE_DO_BIND => {
                    try self.symbols.append(allocator, symbol);
                    symbol = .{
                        .segment = 0,
                        .offset = 0,
                    };
                },
                macho.BIND_OPCODE_DONE => {
                    done = true;
                    break;
                },
                macho.BIND_OPCODE_SET_SYMBOL_TRAILING_FLAGS_IMM => {
                    var name = std.ArrayList(u8).init(allocator);
                    var next = try reader.readByte();
                    while (next != @as(u8, 0)) {
                        try name.append(next);
                        next = try reader.readByte();
                    }
                    symbol.name = name.toOwnedSlice();
                },
                macho.BIND_OPCODE_SET_SEGMENT_AND_OFFSET_ULEB => {
                    symbol.segment = imm;
                    symbol.offset = try leb.readILEB128(i64, reader);
                },
                macho.BIND_OPCODE_SET_DYLIB_SPECIAL_IMM, macho.BIND_OPCODE_SET_DYLIB_ORDINAL_IMM => {
                    assert(!dylib_ordinal_set);
                    self.dylib_ordinal = imm;
                },
                macho.BIND_OPCODE_SET_DYLIB_ORDINAL_ULEB => {
                    assert(!dylib_ordinal_set);
                    self.dylib_ordinal = try leb.readILEB128(i64, reader);
                },
                macho.BIND_OPCODE_SET_TYPE_IMM => {
                    self.binding_type = imm;
                },
                macho.BIND_OPCODE_SET_ADDEND_SLEB => {
                    symbol.addend = try leb.readILEB128(i64, reader);
                },
                else => {
                    std.log.warn("unhandled BIND_OPCODE_: 0x{x}", .{opcode});
                },
            }
        }
        assert(done);
    }

    /// Write the binding info table to byte stream.
    pub fn write(self: BindingInfoTable, writer: anytype) !void {
        if (self.dylib_ordinal > 15) {
            try writer.writeByte(macho.BIND_OPCODE_SET_DYLIB_ORDINAL_ULEB);
            try leb.writeULEB128(writer, @bitCast(u64, self.dylib_ordinal));
        } else if (self.dylib_ordinal > 0) {
            try writer.writeByte(macho.BIND_OPCODE_SET_DYLIB_ORDINAL_IMM | @truncate(u4, @bitCast(u64, self.dylib_ordinal)));
        } else {
            try writer.writeByte(macho.BIND_OPCODE_SET_DYLIB_SPECIAL_IMM | @truncate(u4, @bitCast(u64, self.dylib_ordinal)));
        }
        try writer.writeByte(macho.BIND_OPCODE_SET_TYPE_IMM | @truncate(u4, self.binding_type));

        for (self.symbols.items) |symbol| {
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
        }

        try writer.writeByte(macho.BIND_OPCODE_DONE);
    }

    /// Calculate size in bytes of this binding info table.
    pub fn calcSize(self: *BindingInfoTable) !usize {
        var stream = std.io.countingWriter(std.io.null_writer);
        var writer = stream.writer();
        var size: usize = 1;

        if (self.dylib_ordinal > 15) {
            try leb.writeULEB128(writer, @bitCast(u64, self.dylib_ordinal));
        }

        size += 1;

        for (self.symbols.items) |symbol| {
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

            size += 1;
        }

        size += 1 + stream.bytes_written;
        return size;
    }
};

/// Table of lazy binding info entries used to tell the dyld which
/// symbols to lazily bind at first load of a dylib.
pub const LazyBindingInfoTable = struct {
    symbols: std.ArrayListUnmanaged(Symbol) = .{},

    pub const Symbol = struct {
        /// Symbol name.
        name: ?[]u8 = null,

        /// Offset of this symbol wrt to the segment id encoded in `segment`.
        offset: i64,

        /// Id of the dylib where this symbol is expected to reside.
        /// Positive ordinals point at dylibs imported with LC_LOAD_DYLIB,
        /// 0 means this binary, -1 the main executable, and -2 flat lookup.
        dylib_ordinal: i64,

        /// Id of the segment where to bind this symbol to.
        segment: u8,

        /// Addend value (if any).
        addend: ?i64 = null,
    };

    pub fn deinit(self: *LazyBindingInfoTable, allocator: *Allocator) void {
        for (self.symbols.items) |*symbol| {
            if (symbol.name) |name| {
                allocator.free(name);
            }
        }
        self.symbols.deinit(allocator);
    }

    /// Parse the binding info table from byte stream.
    pub fn read(self: *LazyBindingInfoTable, reader: anytype, allocator: *Allocator) !void {
        var symbol: Symbol = .{
            .offset = 0,
            .segment = 0,
            .dylib_ordinal = 0,
        };

        var done = false;
        while (true) {
            const inst = reader.readByte() catch |err| switch (err) {
                error.EndOfStream => break,
                else => return err,
            };
            const imm: u8 = inst & macho.BIND_IMMEDIATE_MASK;
            const opcode: u8 = inst & macho.BIND_OPCODE_MASK;

            switch (opcode) {
                macho.BIND_OPCODE_DO_BIND => {
                    try self.symbols.append(allocator, symbol);
                },
                macho.BIND_OPCODE_DONE => {
                    done = true;
                    symbol = .{
                        .offset = 0,
                        .segment = 0,
                        .dylib_ordinal = 0,
                    };
                },
                macho.BIND_OPCODE_SET_SYMBOL_TRAILING_FLAGS_IMM => {
                    var name = std.ArrayList(u8).init(allocator);
                    var next = try reader.readByte();
                    while (next != @as(u8, 0)) {
                        try name.append(next);
                        next = try reader.readByte();
                    }
                    symbol.name = name.toOwnedSlice();
                },
                macho.BIND_OPCODE_SET_SEGMENT_AND_OFFSET_ULEB => {
                    symbol.segment = imm;
                    symbol.offset = try leb.readILEB128(i64, reader);
                },
                macho.BIND_OPCODE_SET_DYLIB_SPECIAL_IMM, macho.BIND_OPCODE_SET_DYLIB_ORDINAL_IMM => {
                    symbol.dylib_ordinal = imm;
                },
                macho.BIND_OPCODE_SET_DYLIB_ORDINAL_ULEB => {
                    symbol.dylib_ordinal = try leb.readILEB128(i64, reader);
                },
                macho.BIND_OPCODE_SET_ADDEND_SLEB => {
                    symbol.addend = try leb.readILEB128(i64, reader);
                },
                else => {
                    std.log.warn("unhandled BIND_OPCODE_: 0x{x}", .{opcode});
                },
            }
        }
        assert(done);
    }

    /// Write the binding info table to byte stream.
    pub fn write(self: LazyBindingInfoTable, writer: anytype) !void {
        for (self.symbols.items) |symbol| {
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

    /// Calculate size in bytes of this binding info table.
    pub fn calcSize(self: *LazyBindingInfoTable) !usize {
        var stream = std.io.countingWriter(std.io.null_writer);
        var writer = stream.writer();
        var size: usize = 0;

        for (self.symbols.items) |symbol| {
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
};
