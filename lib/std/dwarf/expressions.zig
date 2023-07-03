const std = @import("std");
const builtin = @import("builtin");
const OP = @import("OP.zig");
const leb = @import("../leb128.zig");
const dwarf = @import("../dwarf.zig");
const abi = dwarf.abi;
const mem = std.mem;

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
        const Self = @This();

        const Operand = union(enum) {
            generic: addr_type,
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
            register_type: struct {
                register: u8,
                type_offset: u64,
            },
            const_type: struct {
                type_offset: u64,
                value_bytes: []const u8,
            },
            deref_type: struct {
                size: u8,
                offset: u64,
            },
        };

        const Value = union(enum) {
            generic: addr_type,
            regval_type: struct {
                // Offset of DW_TAG_base_type DIE
                type_offset: u64,
                value: addr_type,
            },
            const_type: struct {
                // Offset of DW_TAG_base_type DIE
                type_offset: u64,
                value_bytes: []const u8,
            },
        };

        stack: std.ArrayListUnmanaged(Value) = .{},

        pub fn reset(self: *Self) void {
            self.stack.clearRetainingCapacity();
        }

        pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
            self.stack.deinit(allocator);
        }

        fn generic(value: anytype) Operand {
            const int_info = @typeInfo(@TypeOf(value)).Int;
            if (@sizeOf(@TypeOf(value)) > options.addr_size) {
                return .{ .generic = switch (int_info.signedness) {
                    .signed => @bitCast(@as(addr_type_signed, @truncate(value))),
                    .unsigned => @truncate(value),
                } };
            } else {
                return .{ .generic = switch (int_info.signedness) {
                    .signed => @bitCast(@as(addr_type_signed, @intCast(value))),
                    .unsigned => @intCast(value),
                } };
            }
        }

        pub fn readOperand(stream: *std.io.FixedBufferStream([]const u8), opcode: u8) !?Operand {
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
                => generic(try reader.readInt(u16, options.endian)),
                OP.call4 => generic(try reader.readInt(u32, options.endian)),
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
                OP.bregx => blk: {
                    const base_register = try leb.readULEB128(u8, reader);
                    const offset = try leb.readILEB128(i64, reader);
                    break :blk .{ .base_register = .{
                        .base_register = base_register,
                        .offset = offset,
                    } };
                },
                OP.regval_type => blk: {
                    const register = try leb.readULEB128(u8, reader);
                    const type_offset = try leb.readULEB128(u64, reader);
                    break :blk .{ .register_type = .{
                        .register = register,
                        .type_offset = type_offset,
                    } };
                },
                OP.piece => .{
                    .composite_location = .{
                        .size = try leb.readULEB128(u8, reader),
                        .offset = 0,
                    },
                },
                OP.bit_piece => blk: {
                    const size = try leb.readULEB128(u8, reader);
                    const offset = try leb.readILEB128(i64, reader);
                    break :blk .{ .composite_location = .{
                        .size = size,
                        .offset = offset,
                    } };
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
                    break :blk .{ .const_type = .{
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

        pub fn run(
            self: *Self,
            expression: []const u8,
            allocator: std.mem.Allocator,
            compile_unit: ?*const dwarf.CompileUnit,
            ucontext: *const std.os.ucontext_t,
            reg_ctx: abi.RegisterContext,
            initial_value: usize,
        ) !Value {
            try self.stack.append(allocator, .{ .generic = initial_value });
            var stream = std.io.fixedBufferStream(expression);
            while (try self.step(&stream, allocator, compile_unit, ucontext, reg_ctx)) {}
            if (self.stack.items.len == 0) return error.InvalidExpression;
            return self.stack.items[self.stack.items.len - 1];
        }

        /// Reads an opcode and its operands from the stream and executes it
        pub fn step(
            self: *Self,
            stream: *std.io.FixedBufferStream([]const u8),
            allocator: std.mem.Allocator,
            compile_unit: ?*const dwarf.CompileUnit,
            ucontext: *const std.os.ucontext_t,
            reg_ctx: dwarf.abi.RegisterContext,
        ) !bool {
            if (@sizeOf(usize) != @sizeOf(addr_type) or options.endian != comptime builtin.target.cpu.arch.endian())
                @compileError("Execution of non-native address sizees / endianness is not supported");

            const opcode = try stream.reader().readByte();
            if (options.call_frame_mode) {
                // Certain opcodes are not allowed in a CFA context, see 6.4.2
                switch (opcode) {
                    OP.addrx,
                    OP.call2,
                    OP.call4,
                    OP.call_ref,
                    OP.const_type,
                    OP.constx,
                    OP.convert,
                    OP.deref_type,
                    OP.regval_type,
                    OP.reinterpret,
                    OP.push_object_address,
                    OP.call_frame_cfa,
                    => return error.InvalidCFAExpression,
                    else => {},
                }
            }

            switch (opcode) {

                // 2.5.1.1: Literal Encodings
                OP.lit0...OP.lit31,
                OP.addr,
                OP.const1u,
                OP.const2u,
                OP.const4u,
                OP.const8u,
                OP.const1s,
                OP.const2s,
                OP.const4s,
                OP.const8s,
                OP.constu,
                OP.consts,
                => try self.stack.append(allocator, .{ .generic = (try readOperand(stream, opcode)).?.generic }),

                OP.const_type => {
                    const const_type = (try readOperand(stream, opcode)).?.const_type;
                    try self.stack.append(allocator, .{ .const_type = .{
                        .type_offset = const_type.type_offset,
                        .value_bytes = const_type.value_bytes,
                    } });
                },

                OP.addrx, OP.constx => {
                    const debug_addr_index = (try readOperand(stream, opcode)).?.generic;

                    // TODO: Read item from .debug_addr, this requires need DW_AT_addr_base of the compile unit, push onto stack as generic

                    _ = debug_addr_index;
                    unreachable;
                },

                // 2.5.1.2: Register Values
                OP.fbreg => {
                    if (compile_unit == null) return error.ExpressionRequiresCompileUnit;
                    if (compile_unit.?.frame_base == null) return error.ExpressionRequiresFrameBase;

                    const offset: i64 = @intCast((try readOperand(stream, opcode)).?.generic);
                    _ = offset;

                    switch (compile_unit.?.frame_base.?.*) {
                        .ExprLoc => {
                            // TODO: Run this expression in a nested stack machine
                            return error.UnimplementedOpcode;
                        },
                        .LocListOffset => {
                            // TODO: Read value from .debug_loclists
                            return error.UnimplementedOpcode;
                        },
                        .SecOffset => {
                            // TODO: Read value from .debug_loclists
                            return error.UnimplementedOpcode;
                        },
                        else => return error.InvalidFrameBase,
                    }
                },
                OP.breg0...OP.breg31, OP.bregx => {
                    const base_register = (try readOperand(stream, opcode)).?.base_register;
                    var value: i64 = @intCast(mem.readIntSliceNative(usize, try abi.regBytes(ucontext, base_register.base_register, reg_ctx)));
                    value += base_register.offset;
                    try self.stack.append(allocator, .{ .generic = @intCast(value) });
                },
                OP.regval_type => {
                    const register_type = (try readOperand(stream, opcode)).?.register_type;
                    const value = mem.readIntSliceNative(usize, try abi.regBytes(ucontext, register_type.register, reg_ctx));
                    try self.stack.append(allocator, .{
                        .regval_type = .{
                            .value = value,
                            .type_offset = register_type.type_offset,
                        },
                    });
                },

                // 2.5.1.3: Stack Operations

                OP.dup => {},

                else => {
                    std.debug.print("Unimplemented DWARF expression opcode: {x}\n", .{opcode});
                    unreachable;
                },

                // These have already been handled by readOperand
                OP.lo_user...OP.hi_user => unreachable,
            }

            return stream.pos < stream.buffer.len;
        }
    };
}
