const std = @import("std");
const builtin = @import("builtin");
const OP = @import("OP.zig");
const leb = @import("../leb128.zig");

pub const StackMachineOptions = struct {
    /// The address size of the target architecture
    addr_size: u8 = @sizeOf(usize),

    /// Endianess of the target architecture
    endian: std.builtin.Endian = .Little,

    /// Restrict the stack machine to a subset of opcodes used in call frame instructions
    call_frame_mode: bool = false,
};

/// A stack machine that can decode and run DWARF expressions.
/// Expressions can be decoded for non-native address size and endianness,
/// but can only be executed if the current target matches the configuration.
pub fn StackMachine(comptime options: StackMachineOptions) type {
    const addr_type = switch (options.addr_size) {
        2 => u16,
        4 => u32,
        8 => u64,
        else => @compileError("Unsupported address size of " ++ options.addr_size),
    };

    const addr_type_signed = switch (options.addr_size) {
        2 => i16,
        4 => i32,
        8 => i64,
        else => @compileError("Unsupported address size of " ++ options.addr_size),
    };

    return struct {
        const Value = union(enum) {
            generic: addr_type,
            const_type: []const u8,
            register: u8,
            base_register: struct {
                base_register: u8,
                offset: i64,
            },
            composite_location: struct {
                size: u64,
                offset: i64,
            },
            block: []const u8,
            base_type: struct {
                type_offset: u64,
                value_bytes: []const u8,
            },
            deref_type: struct {
                size: u8,
                offset: u64,
            },
        };

        stack: std.ArrayListUnmanaged(Value) = .{},

        fn generic(value: anytype) Value {
            const int_info = @typeInfo(@TypeOf(value)).Int;
            if (@sizeOf(@TypeOf(value)) > options.addr_size) {
                return .{ .generic = switch (int_info.signedness) {
                    .signed => @bitCast(addr_type, @truncate(addr_type_signed, value)),
                    .unsigned => @truncate(addr_type, value),
                } };
            } else {
                return .{ .generic = switch (int_info.signedness) {
                    .signed => @bitCast(addr_type, @intCast(addr_type_signed, value)),
                    .unsigned => @intCast(addr_type, value),
                } };
            }
        }

        pub fn readOperand(stream: *std.io.FixedBufferStream([]const u8), opcode: u8) !?Value {
            const reader = stream.reader();
            return switch (opcode) {
                OP.addr,
                OP.call_ref,
                => generic(try reader.readInt(addr_type, options.endian)),
                OP.const1u,
                OP.pick,
                OP.deref_size,
                OP.xderef_size,
                => generic(try reader.readByte()),
                OP.const1s => generic(try reader.readByteSigned()),
                OP.const2u,
                OP.call2,
                OP.call4,
                => generic(try reader.readInt(u16, options.endian)),
                OP.const2s,
                OP.bra,
                OP.skip,
                => generic(try reader.readInt(i16, options.endian)),
                OP.const4u => generic(try reader.readInt(u32, options.endian)),
                OP.const4s => generic(try reader.readInt(i32, options.endian)),
                OP.const8u => generic(try reader.readInt(u64, options.endian)),
                OP.const8s => generic(try reader.readInt(i64, options.endian)),
                OP.constu,
                OP.plus_uconst,
                OP.addrx,
                OP.constx,
                OP.convert,
                OP.reinterpret,
                => generic(try leb.readULEB128(u64, reader)),
                OP.consts,
                OP.fbreg,
                => generic(try leb.readILEB128(i64, reader)),
                OP.lit0...OP.lit31 => |n| generic(n - OP.lit0),
                OP.reg0...OP.reg31 => |n| .{ .register = n - OP.reg0 },
                OP.breg0...OP.breg31 => |n| .{ .base_register = .{
                    .base_register = n - OP.breg0,
                    .offset = try leb.readILEB128(i64, reader),
                } },
                OP.regx => .{ .register = try leb.readULEB128(u8, reader) },
                OP.bregx, OP.regval_type => .{ .base_register = .{
                    .base_register = try leb.readULEB128(u8, reader),
                    .offset = try leb.readILEB128(i64, reader),
                } },
                OP.piece => .{
                    .composite_location = .{
                        .size = try leb.readULEB128(u8, reader),
                        .offset = 0,
                    },
                },
                OP.bit_piece => .{
                    .composite_location = .{
                        .size = try leb.readULEB128(u8, reader),
                        .offset = try leb.readILEB128(i64, reader),
                    },
                },
                OP.implicit_value, OP.entry_value => blk: {
                    const size = try leb.readULEB128(u8, reader);
                    if (stream.pos + size > stream.buffer.len) return error.InvalidExpression;
                    const block = stream.buffer[stream.pos..][0..size];
                    stream.pos += size;
                    break :blk .{
                        .block = block,
                    };
                },
                OP.const_type => blk: {
                    const type_offset = try leb.readULEB128(u8, reader);
                    const size = try reader.readByte();
                    if (stream.pos + size > stream.buffer.len) return error.InvalidExpression;
                    const value_bytes = stream.buffer[stream.pos..][0..size];
                    stream.pos += size;
                    break :blk .{ .base_type = .{
                        .type_offset = type_offset,
                        .value_bytes = value_bytes,
                    } };
                },
                OP.deref_type,
                OP.xderef_type,
                => .{
                    .deref_type = .{
                        .size = try reader.readByte(),
                        .offset = try leb.readULEB128(u64, reader),
                    },
                },
                OP.lo_user...OP.hi_user => return error.UnimplementedUserOpcode,
                else => null,
            };
        }

        pub fn step(
            self: *StackMachine,
            stream: std.io.FixedBufferStream([]const u8),
            allocator: std.mem.Allocator,
        ) !void {
            if (@sizeOf(usize) != addr_type or options.endian != builtin.target.cpu.arch.endian())
                @compileError("Execution of non-native address sizees / endianness is not supported");

            const opcode = try stream.reader.readByte();
            _ = opcode;
            _ = self;
            _ = allocator;

            // switch (opcode) {
            //     OP.addr => try self.stack.append(allocator, try readOperand(stream, opcode)),
            // }
        }
    };
}
