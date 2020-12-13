const std = @import("std");
const leb = std.leb;
const macho = std.macho;
const mem = std.mem;

const assert = std.debug.assert;
const Allocator = mem.Allocator;

pub const BindingInfoTable = struct {
    dylib_ordinal: i64 = 0,
    binding_type: u8 = macho.BIND_TYPE_POINTER,
    entries: std.ArrayListUnmanaged(Entry) = .{},

    pub const Entry = struct {
        /// Id of the symbol in the undef symbol table.
        /// Can be null.
        symbol: ?u16 = null,

        /// Id of the segment where to bind this symbol to.
        segment: u8,

        /// Offset of this symbol wrt to the segment id encoded in `segment`.
        offset: i64,
    };

    pub fn deinit(self: *BindingInfoTable, allocator: *Allocator) void {
        self.entries.deinit(allocator);
    }

    pub fn read(self: *BindingInfoTable, allocator: *Allocator, symbols_by_name: anytype, reader: anytype) !void {
        var name = std.ArrayList(u8).init(allocator);
        defer name.deinit();

        var entry: Entry = .{
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
                    try self.entries.append(allocator, entry);
                    entry = .{
                        .segment = 0,
                        .offset = 0,
                    };
                },
                macho.BIND_OPCODE_DONE => {
                    done = true;
                    break;
                },
                macho.BIND_OPCODE_SET_SYMBOL_TRAILING_FLAGS_IMM => {
                    name.shrinkRetainingCapacity(0);
                    var next = try reader.readByte();
                    while (next != @as(u8, 0)) {
                        try name.append(next);
                        next = try reader.readByte();
                    }
                    entry.symbol = symbols_by_name.get(name.items[0..]);
                },
                macho.BIND_OPCODE_SET_SEGMENT_AND_OFFSET_ULEB => {
                    entry.segment = imm;
                    entry.offset = try leb.readILEB128(i64, reader);
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
                else => {
                    std.log.warn("unhandled BIND_OPCODE_: 0x{x}", .{opcode});
                },
            }
        }
        assert(done);
    }

    pub fn write(self: BindingInfoTable, writer: anytype) !void {}
};

pub const LazyBindingInfoTable = struct {
    entries: std.ArrayListUnmanaged(Entry) = .{},

    pub const Entry = struct {
        /// Id of the symbol in the undef symbol table.
        symbol: u16,

        /// Offset of this symbol wrt to the segment id encoded in `segment`.
        offset: i64,

        /// Id of the dylib where this symbol is expected to reside.
        /// Positive ordinals point at dylibs imported with LC_LOAD_DYLIB,
        /// 0 means this binary, -1 the main executable, and -2 flat lookup.
        dylib_ordinal: i64,

        /// Id of the segment where to bind this symbol to.
        segment: u8,
    };

    pub fn deinit(self: *LazyBindingInfoTable, allocator: *Allocator) void {
        self.entries.deinit(allocator);
    }

    pub fn read(self: *LazyBindingInfoTable, allocator: *Allocator, symbols_by_name: anytype, reader: anytype) !void {
        var name = std.ArrayList(u8).init(allocator);
        defer name.deinit();

        var entry: Entry = .{
            .symbol = 0,
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
                    try self.entries.append(allocator, entry);
                },
                macho.BIND_OPCODE_DONE => {
                    done = true;
                    entry = .{
                        .symbol = 0,
                        .offset = 0,
                        .segment = 0,
                        .dylib_ordinal = 0,
                    };
                },
                macho.BIND_OPCODE_SET_SYMBOL_TRAILING_FLAGS_IMM => {
                    name.shrinkRetainingCapacity(0);
                    var next = try reader.readByte();
                    while (next != @as(u8, 0)) {
                        try name.append(next);
                        next = try reader.readByte();
                    }
                    entry.symbol = symbols_by_name.get(name.items[0..]) orelse unreachable;
                },
                macho.BIND_OPCODE_SET_SEGMENT_AND_OFFSET_ULEB => {
                    entry.segment = imm;
                    entry.offset = try leb.readILEB128(i64, reader);
                },
                macho.BIND_OPCODE_SET_DYLIB_SPECIAL_IMM, macho.BIND_OPCODE_SET_DYLIB_ORDINAL_IMM => {
                    entry.dylib_ordinal = imm;
                },
                macho.BIND_OPCODE_SET_DYLIB_ORDINAL_ULEB => {
                    entry.dylib_ordinal = try leb.readILEB128(i64, reader);
                },
                else => {
                    std.log.warn("unhandled BIND_OPCODE_: 0x{x}", .{opcode});
                },
            }
        }
        assert(done);
    }

    pub fn write(self: LazyBindingInfoTable, writer: anytype) !void {}
};
