const builtin = @import("builtin");
const native_arch = builtin.cpu.arch;
const native_endian = native_arch.endian();

const std = @import("std");
const leb = std.leb;
const OP = std.dwarf.OP;
const abi = std.debug.Dwarf.abi;
const mem = std.mem;
const assert = std.debug.assert;

/// Expressions can be evaluated in different contexts, each requiring its own set of inputs.
/// Callers should specify all the fields relevant to their context. If a field is required
/// by the expression and it isn't in the context, error.IncompleteExpressionContext is returned.
pub const Context = struct {
    /// The dwarf format of the section this expression is in
    format: std.dwarf.Format = .@"32",
    /// If specified, any addresses will pass through before being accessed
    memory_accessor: ?*std.debug.MemoryAccessor = null,
    /// The compilation unit this expression relates to, if any
    compile_unit: ?*const std.debug.Dwarf.CompileUnit = null,
    /// When evaluating a user-presented expression, this is the address of the object being evaluated
    object_address: ?*const anyopaque = null,
    /// .debug_addr section
    debug_addr: ?[]const u8 = null,
    /// Thread context
    thread_context: ?*std.debug.ThreadContext = null,
    reg_context: ?abi.RegisterContext = null,
    /// Call frame address, if in a CFI context
    cfa: ?usize = null,
    /// This expression is a sub-expression from an OP.entry_value instruction
    entry_value_context: bool = false,
};

pub const Options = struct {
    /// The address size of the target architecture
    addr_size: u8 = @sizeOf(usize),
    /// Endianness of the target architecture
    endian: std.builtin.Endian = native_endian,
    /// Restrict the stack machine to a subset of opcodes used in call frame instructions
    call_frame_context: bool = false,
};

// Explicitly defined to support executing sub-expressions
pub const Error = error{
    UnimplementedExpressionCall,
    UnimplementedOpcode,
    UnimplementedUserOpcode,
    UnimplementedTypedComparison,
    UnimplementedTypeConversion,

    UnknownExpressionOpcode,

    IncompleteExpressionContext,

    InvalidCFAOpcode,
    InvalidExpression,
    InvalidFrameBase,
    InvalidIntegralTypeSize,
    InvalidRegister,
    InvalidSubExpression,
    InvalidTypeLength,

    TruncatedIntegralType,
} || abi.RegBytesError || error{ EndOfStream, Overflow, OutOfMemory, DivisionByZero };

/// A stack machine that can decode and run DWARF expressions.
/// Expressions can be decoded for non-native address size and endianness,
/// but can only be executed if the current target matches the configuration.
pub fn StackMachine(comptime options: Options) type {
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
            type_size: u8,
            branch_offset: i16,
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
                type_offset: addr_type,
            },
            const_type: struct {
                type_offset: addr_type,
                value_bytes: []const u8,
            },
            deref_type: struct {
                size: u8,
                type_offset: addr_type,
            },
        };

        const Value = union(enum) {
            generic: addr_type,

            // Typed value with a maximum size of a register
            regval_type: struct {
                // Offset of DW_TAG_base_type DIE
                type_offset: addr_type,
                type_size: u8,
                value: addr_type,
            },

            // Typed value specified directly in the instruction stream
            const_type: struct {
                // Offset of DW_TAG_base_type DIE
                type_offset: addr_type,
                // Backed by the instruction stream
                value_bytes: []const u8,
            },

            pub fn asIntegral(self: Value) !addr_type {
                return switch (self) {
                    .generic => |v| v,

                    // TODO: For these two prongs, look up the type and assert it's integral?
                    .regval_type => |regval_type| regval_type.value,
                    .const_type => |const_type| {
                        const value: u64 = switch (const_type.value_bytes.len) {
                            1 => mem.readInt(u8, const_type.value_bytes[0..1], native_endian),
                            2 => mem.readInt(u16, const_type.value_bytes[0..2], native_endian),
                            4 => mem.readInt(u32, const_type.value_bytes[0..4], native_endian),
                            8 => mem.readInt(u64, const_type.value_bytes[0..8], native_endian),
                            else => return error.InvalidIntegralTypeSize,
                        };

                        return std.math.cast(addr_type, value) orelse error.TruncatedIntegralType;
                    },
                };
            }
        };

        stack: std.ArrayListUnmanaged(Value) = .empty,

        pub fn reset(self: *Self) void {
            self.stack.clearRetainingCapacity();
        }

        pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
            self.stack.deinit(allocator);
        }

        fn generic(value: anytype) Operand {
            const int_info = @typeInfo(@TypeOf(value)).int;
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

        pub fn readOperand(stream: *std.io.FixedBufferStream([]const u8), opcode: u8, context: Context) !?Operand {
            const reader = stream.reader();
            return switch (opcode) {
                OP.addr => generic(try reader.readInt(addr_type, options.endian)),
                OP.call_ref => switch (context.format) {
                    .@"32" => generic(try reader.readInt(u32, options.endian)),
                    .@"64" => generic(try reader.readInt(u64, options.endian)),
                },
                OP.const1u,
                OP.pick,
                => generic(try reader.readByte()),
                OP.deref_size,
                OP.xderef_size,
                => .{ .type_size = try reader.readByte() },
                OP.const1s => generic(try reader.readByteSigned()),
                OP.const2u,
                OP.call2,
                => generic(try reader.readInt(u16, options.endian)),
                OP.call4 => generic(try reader.readInt(u32, options.endian)),
                OP.const2s => generic(try reader.readInt(i16, options.endian)),
                OP.bra,
                OP.skip,
                => .{ .branch_offset = try reader.readInt(i16, options.endian) },
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
                => generic(try leb.readUleb128(u64, reader)),
                OP.consts,
                OP.fbreg,
                => generic(try leb.readIleb128(i64, reader)),
                OP.lit0...OP.lit31 => |n| generic(n - OP.lit0),
                OP.reg0...OP.reg31 => |n| .{ .register = n - OP.reg0 },
                OP.breg0...OP.breg31 => |n| .{ .base_register = .{
                    .base_register = n - OP.breg0,
                    .offset = try leb.readIleb128(i64, reader),
                } },
                OP.regx => .{ .register = try leb.readUleb128(u8, reader) },
                OP.bregx => blk: {
                    const base_register = try leb.readUleb128(u8, reader);
                    const offset = try leb.readIleb128(i64, reader);
                    break :blk .{ .base_register = .{
                        .base_register = base_register,
                        .offset = offset,
                    } };
                },
                OP.regval_type => blk: {
                    const register = try leb.readUleb128(u8, reader);
                    const type_offset = try leb.readUleb128(addr_type, reader);
                    break :blk .{ .register_type = .{
                        .register = register,
                        .type_offset = type_offset,
                    } };
                },
                OP.piece => .{
                    .composite_location = .{
                        .size = try leb.readUleb128(u8, reader),
                        .offset = 0,
                    },
                },
                OP.bit_piece => blk: {
                    const size = try leb.readUleb128(u8, reader);
                    const offset = try leb.readIleb128(i64, reader);
                    break :blk .{ .composite_location = .{
                        .size = size,
                        .offset = offset,
                    } };
                },
                OP.implicit_value, OP.entry_value => blk: {
                    const size = try leb.readUleb128(u8, reader);
                    if (stream.pos + size > stream.buffer.len) return error.InvalidExpression;
                    const block = stream.buffer[stream.pos..][0..size];
                    stream.pos += size;
                    break :blk .{
                        .block = block,
                    };
                },
                OP.const_type => blk: {
                    const type_offset = try leb.readUleb128(addr_type, reader);
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
                        .type_offset = try leb.readUleb128(addr_type, reader),
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
            context: Context,
            initial_value: ?usize,
        ) Error!?Value {
            if (initial_value) |i| try self.stack.append(allocator, .{ .generic = i });
            var stream = std.io.fixedBufferStream(expression);
            while (try self.step(&stream, allocator, context)) {}
            if (self.stack.items.len == 0) return null;
            return self.stack.items[self.stack.items.len - 1];
        }

        /// Reads an opcode and its operands from `stream`, then executes it
        pub fn step(
            self: *Self,
            stream: *std.io.FixedBufferStream([]const u8),
            allocator: std.mem.Allocator,
            context: Context,
        ) Error!bool {
            if (@sizeOf(usize) != @sizeOf(addr_type) or options.endian != native_endian)
                @compileError("Execution of non-native address sizes / endianness is not supported");

            const opcode = try stream.reader().readByte();
            if (options.call_frame_context and !isOpcodeValidInCFA(opcode)) return error.InvalidCFAOpcode;
            const operand = try readOperand(stream, opcode, context);
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
                => try self.stack.append(allocator, .{ .generic = operand.?.generic }),

                OP.const_type => {
                    const const_type = operand.?.const_type;
                    try self.stack.append(allocator, .{ .const_type = .{
                        .type_offset = const_type.type_offset,
                        .value_bytes = const_type.value_bytes,
                    } });
                },

                OP.addrx,
                OP.constx,
                => {
                    if (context.compile_unit == null) return error.IncompleteExpressionContext;
                    if (context.debug_addr == null) return error.IncompleteExpressionContext;
                    const debug_addr_index = operand.?.generic;
                    const offset = context.compile_unit.?.addr_base + debug_addr_index;
                    if (offset >= context.debug_addr.?.len) return error.InvalidExpression;
                    const value = mem.readInt(usize, context.debug_addr.?[offset..][0..@sizeOf(usize)], native_endian);
                    try self.stack.append(allocator, .{ .generic = value });
                },

                // 2.5.1.2: Register Values
                OP.fbreg => {
                    if (context.compile_unit == null) return error.IncompleteExpressionContext;
                    if (context.compile_unit.?.frame_base == null) return error.IncompleteExpressionContext;

                    const offset: i64 = @intCast(operand.?.generic);
                    _ = offset;

                    switch (context.compile_unit.?.frame_base.?.*) {
                        .exprloc => {
                            // TODO: Run this expression in a nested stack machine
                            return error.UnimplementedOpcode;
                        },
                        .loclistx => {
                            // TODO: Read value from .debug_loclists
                            return error.UnimplementedOpcode;
                        },
                        .sec_offset => {
                            // TODO: Read value from .debug_loclists
                            return error.UnimplementedOpcode;
                        },
                        else => return error.InvalidFrameBase,
                    }
                },
                OP.breg0...OP.breg31,
                OP.bregx,
                => {
                    if (context.thread_context == null) return error.IncompleteExpressionContext;

                    const base_register = operand.?.base_register;
                    var value: i64 = @intCast(mem.readInt(usize, (try abi.regBytes(
                        context.thread_context.?,
                        base_register.base_register,
                        context.reg_context,
                    ))[0..@sizeOf(usize)], native_endian));
                    value += base_register.offset;
                    try self.stack.append(allocator, .{ .generic = @intCast(value) });
                },
                OP.regval_type => {
                    const register_type = operand.?.register_type;
                    const value = mem.readInt(usize, (try abi.regBytes(
                        context.thread_context.?,
                        register_type.register,
                        context.reg_context,
                    ))[0..@sizeOf(usize)], native_endian);
                    try self.stack.append(allocator, .{
                        .regval_type = .{
                            .type_offset = register_type.type_offset,
                            .type_size = @sizeOf(addr_type),
                            .value = value,
                        },
                    });
                },

                // 2.5.1.3: Stack Operations
                OP.dup => {
                    if (self.stack.items.len == 0) return error.InvalidExpression;
                    try self.stack.append(allocator, self.stack.items[self.stack.items.len - 1]);
                },
                OP.drop => {
                    _ = self.stack.pop();
                },
                OP.pick, OP.over => {
                    const stack_index = if (opcode == OP.over) 1 else operand.?.generic;
                    if (stack_index >= self.stack.items.len) return error.InvalidExpression;
                    try self.stack.append(allocator, self.stack.items[self.stack.items.len - 1 - stack_index]);
                },
                OP.swap => {
                    if (self.stack.items.len < 2) return error.InvalidExpression;
                    mem.swap(Value, &self.stack.items[self.stack.items.len - 1], &self.stack.items[self.stack.items.len - 2]);
                },
                OP.rot => {
                    if (self.stack.items.len < 3) return error.InvalidExpression;
                    const first = self.stack.items[self.stack.items.len - 1];
                    self.stack.items[self.stack.items.len - 1] = self.stack.items[self.stack.items.len - 2];
                    self.stack.items[self.stack.items.len - 2] = self.stack.items[self.stack.items.len - 3];
                    self.stack.items[self.stack.items.len - 3] = first;
                },
                OP.deref,
                OP.xderef,
                OP.deref_size,
                OP.xderef_size,
                OP.deref_type,
                OP.xderef_type,
                => {
                    if (self.stack.items.len == 0) return error.InvalidExpression;
                    const addr = try self.stack.items[self.stack.items.len - 1].asIntegral();
                    const addr_space_identifier: ?usize = switch (opcode) {
                        OP.xderef,
                        OP.xderef_size,
                        OP.xderef_type,
                        => blk: {
                            _ = self.stack.pop();
                            if (self.stack.items.len == 0) return error.InvalidExpression;
                            break :blk try self.stack.items[self.stack.items.len - 1].asIntegral();
                        },
                        else => null,
                    };

                    // Usage of addr_space_identifier in the address calculation is implementation defined.
                    // This code will need to be updated to handle any architectures that utilize this.
                    _ = addr_space_identifier;

                    const size = switch (opcode) {
                        OP.deref,
                        OP.xderef,
                        => @sizeOf(addr_type),
                        OP.deref_size,
                        OP.xderef_size,
                        => operand.?.type_size,
                        OP.deref_type,
                        OP.xderef_type,
                        => operand.?.deref_type.size,
                        else => unreachable,
                    };

                    if (context.memory_accessor) |memory_accessor| {
                        if (!switch (size) {
                            1 => memory_accessor.load(u8, addr) != null,
                            2 => memory_accessor.load(u16, addr) != null,
                            4 => memory_accessor.load(u32, addr) != null,
                            8 => memory_accessor.load(u64, addr) != null,
                            else => return error.InvalidExpression,
                        }) return error.InvalidExpression;
                    }

                    const value: addr_type = std.math.cast(addr_type, @as(u64, switch (size) {
                        1 => @as(*const u8, @ptrFromInt(addr)).*,
                        2 => @as(*const u16, @ptrFromInt(addr)).*,
                        4 => @as(*const u32, @ptrFromInt(addr)).*,
                        8 => @as(*const u64, @ptrFromInt(addr)).*,
                        else => return error.InvalidExpression,
                    })) orelse return error.InvalidExpression;

                    switch (opcode) {
                        OP.deref_type,
                        OP.xderef_type,
                        => {
                            self.stack.items[self.stack.items.len - 1] = .{
                                .regval_type = .{
                                    .type_offset = operand.?.deref_type.type_offset,
                                    .type_size = operand.?.deref_type.size,
                                    .value = value,
                                },
                            };
                        },
                        else => {
                            self.stack.items[self.stack.items.len - 1] = .{ .generic = value };
                        },
                    }
                },
                OP.push_object_address => {
                    // In sub-expressions, `push_object_address` is not meaningful (as per the
                    // spec), so treat it like a nop
                    if (!context.entry_value_context) {
                        if (context.object_address == null) return error.IncompleteExpressionContext;
                        try self.stack.append(allocator, .{ .generic = @intFromPtr(context.object_address.?) });
                    }
                },
                OP.form_tls_address => {
                    return error.UnimplementedOpcode;
                },
                OP.call_frame_cfa => {
                    if (context.cfa) |cfa| {
                        try self.stack.append(allocator, .{ .generic = cfa });
                    } else return error.IncompleteExpressionContext;
                },

                // 2.5.1.4: Arithmetic and Logical Operations
                OP.abs => {
                    if (self.stack.items.len == 0) return error.InvalidExpression;
                    const value: isize = @bitCast(try self.stack.items[self.stack.items.len - 1].asIntegral());
                    self.stack.items[self.stack.items.len - 1] = .{
                        .generic = @abs(value),
                    };
                },
                OP.@"and" => {
                    if (self.stack.items.len < 2) return error.InvalidExpression;
                    const a = try self.stack.pop().asIntegral();
                    self.stack.items[self.stack.items.len - 1] = .{
                        .generic = a & try self.stack.items[self.stack.items.len - 1].asIntegral(),
                    };
                },
                OP.div => {
                    if (self.stack.items.len < 2) return error.InvalidExpression;
                    const a: isize = @bitCast(try self.stack.pop().asIntegral());
                    const b: isize = @bitCast(try self.stack.items[self.stack.items.len - 1].asIntegral());
                    self.stack.items[self.stack.items.len - 1] = .{
                        .generic = @bitCast(try std.math.divTrunc(isize, b, a)),
                    };
                },
                OP.minus => {
                    if (self.stack.items.len < 2) return error.InvalidExpression;
                    const b = try self.stack.pop().asIntegral();
                    self.stack.items[self.stack.items.len - 1] = .{
                        .generic = try std.math.sub(addr_type, try self.stack.items[self.stack.items.len - 1].asIntegral(), b),
                    };
                },
                OP.mod => {
                    if (self.stack.items.len < 2) return error.InvalidExpression;
                    const a: isize = @bitCast(try self.stack.pop().asIntegral());
                    const b: isize = @bitCast(try self.stack.items[self.stack.items.len - 1].asIntegral());
                    self.stack.items[self.stack.items.len - 1] = .{
                        .generic = @bitCast(@mod(b, a)),
                    };
                },
                OP.mul => {
                    if (self.stack.items.len < 2) return error.InvalidExpression;
                    const a: isize = @bitCast(try self.stack.pop().asIntegral());
                    const b: isize = @bitCast(try self.stack.items[self.stack.items.len - 1].asIntegral());
                    self.stack.items[self.stack.items.len - 1] = .{
                        .generic = @bitCast(@mulWithOverflow(a, b)[0]),
                    };
                },
                OP.neg => {
                    if (self.stack.items.len == 0) return error.InvalidExpression;
                    self.stack.items[self.stack.items.len - 1] = .{
                        .generic = @bitCast(
                            try std.math.negate(
                                @as(isize, @bitCast(try self.stack.items[self.stack.items.len - 1].asIntegral())),
                            ),
                        ),
                    };
                },
                OP.not => {
                    if (self.stack.items.len == 0) return error.InvalidExpression;
                    self.stack.items[self.stack.items.len - 1] = .{
                        .generic = ~try self.stack.items[self.stack.items.len - 1].asIntegral(),
                    };
                },
                OP.@"or" => {
                    if (self.stack.items.len < 2) return error.InvalidExpression;
                    const a = try self.stack.pop().asIntegral();
                    self.stack.items[self.stack.items.len - 1] = .{
                        .generic = a | try self.stack.items[self.stack.items.len - 1].asIntegral(),
                    };
                },
                OP.plus => {
                    if (self.stack.items.len < 2) return error.InvalidExpression;
                    const b = try self.stack.pop().asIntegral();
                    self.stack.items[self.stack.items.len - 1] = .{
                        .generic = try std.math.add(addr_type, try self.stack.items[self.stack.items.len - 1].asIntegral(), b),
                    };
                },
                OP.plus_uconst => {
                    if (self.stack.items.len == 0) return error.InvalidExpression;
                    const constant = operand.?.generic;
                    self.stack.items[self.stack.items.len - 1] = .{
                        .generic = try std.math.add(addr_type, try self.stack.items[self.stack.items.len - 1].asIntegral(), constant),
                    };
                },
                OP.shl => {
                    if (self.stack.items.len < 2) return error.InvalidExpression;
                    const a = try self.stack.pop().asIntegral();
                    const b = try self.stack.items[self.stack.items.len - 1].asIntegral();
                    self.stack.items[self.stack.items.len - 1] = .{
                        .generic = std.math.shl(usize, b, a),
                    };
                },
                OP.shr => {
                    if (self.stack.items.len < 2) return error.InvalidExpression;
                    const a = try self.stack.pop().asIntegral();
                    const b = try self.stack.items[self.stack.items.len - 1].asIntegral();
                    self.stack.items[self.stack.items.len - 1] = .{
                        .generic = std.math.shr(usize, b, a),
                    };
                },
                OP.shra => {
                    if (self.stack.items.len < 2) return error.InvalidExpression;
                    const a = try self.stack.pop().asIntegral();
                    const b: isize = @bitCast(try self.stack.items[self.stack.items.len - 1].asIntegral());
                    self.stack.items[self.stack.items.len - 1] = .{
                        .generic = @bitCast(std.math.shr(isize, b, a)),
                    };
                },
                OP.xor => {
                    if (self.stack.items.len < 2) return error.InvalidExpression;
                    const a = try self.stack.pop().asIntegral();
                    self.stack.items[self.stack.items.len - 1] = .{
                        .generic = a ^ try self.stack.items[self.stack.items.len - 1].asIntegral(),
                    };
                },

                // 2.5.1.5: Control Flow Operations
                OP.le,
                OP.ge,
                OP.eq,
                OP.lt,
                OP.gt,
                OP.ne,
                => {
                    if (self.stack.items.len < 2) return error.InvalidExpression;
                    const a = self.stack.pop();
                    const b = self.stack.items[self.stack.items.len - 1];

                    if (a == .generic and b == .generic) {
                        const a_int: isize = @bitCast(a.asIntegral() catch unreachable);
                        const b_int: isize = @bitCast(b.asIntegral() catch unreachable);
                        const result = @intFromBool(switch (opcode) {
                            OP.le => b_int <= a_int,
                            OP.ge => b_int >= a_int,
                            OP.eq => b_int == a_int,
                            OP.lt => b_int < a_int,
                            OP.gt => b_int > a_int,
                            OP.ne => b_int != a_int,
                            else => unreachable,
                        });

                        self.stack.items[self.stack.items.len - 1] = .{ .generic = result };
                    } else {
                        // TODO: Load the types referenced by these values, find their comparison operator, and run it
                        return error.UnimplementedTypedComparison;
                    }
                },
                OP.skip, OP.bra => {
                    const branch_offset = operand.?.branch_offset;
                    const condition = if (opcode == OP.bra) blk: {
                        if (self.stack.items.len == 0) return error.InvalidExpression;
                        break :blk try self.stack.pop().asIntegral() != 0;
                    } else true;

                    if (condition) {
                        const new_pos = std.math.cast(
                            usize,
                            try std.math.add(isize, @as(isize, @intCast(stream.pos)), branch_offset),
                        ) orelse return error.InvalidExpression;

                        if (new_pos < 0 or new_pos > stream.buffer.len) return error.InvalidExpression;
                        stream.pos = new_pos;
                    }
                },
                OP.call2,
                OP.call4,
                OP.call_ref,
                => {
                    const debug_info_offset = operand.?.generic;
                    _ = debug_info_offset;

                    // TODO: Load a DIE entry at debug_info_offset in a .debug_info section (the spec says that it
                    //       can be in a separate exe / shared object from the one containing this expression).
                    //       Transfer control to the DW_AT_location attribute, with the current stack as input.

                    return error.UnimplementedExpressionCall;
                },

                // 2.5.1.6: Type Conversions
                OP.convert => {
                    if (self.stack.items.len == 0) return error.InvalidExpression;
                    const type_offset = operand.?.generic;

                    // TODO: Load the DW_TAG_base_type entries in context.compile_unit and verify both types are the same size
                    const value = self.stack.items[self.stack.items.len - 1];
                    if (type_offset == 0) {
                        self.stack.items[self.stack.items.len - 1] = .{ .generic = try value.asIntegral() };
                    } else {
                        // TODO: Load the DW_TAG_base_type entry in context.compile_unit, find a conversion operator
                        //       from the old type to the new type, run it.
                        return error.UnimplementedTypeConversion;
                    }
                },
                OP.reinterpret => {
                    if (self.stack.items.len == 0) return error.InvalidExpression;
                    const type_offset = operand.?.generic;

                    // TODO: Load the DW_TAG_base_type entries in context.compile_unit and verify both types are the same size
                    const value = self.stack.items[self.stack.items.len - 1];
                    if (type_offset == 0) {
                        self.stack.items[self.stack.items.len - 1] = .{ .generic = try value.asIntegral() };
                    } else {
                        self.stack.items[self.stack.items.len - 1] = switch (value) {
                            .generic => |v| .{
                                .regval_type = .{
                                    .type_offset = type_offset,
                                    .type_size = @sizeOf(addr_type),
                                    .value = v,
                                },
                            },
                            .regval_type => |r| .{
                                .regval_type = .{
                                    .type_offset = type_offset,
                                    .type_size = r.type_size,
                                    .value = r.value,
                                },
                            },
                            .const_type => |c| .{
                                .const_type = .{
                                    .type_offset = type_offset,
                                    .value_bytes = c.value_bytes,
                                },
                            },
                        };
                    }
                },

                // 2.5.1.7: Special Operations
                OP.nop => {},
                OP.entry_value => {
                    const block = operand.?.block;
                    if (block.len == 0) return error.InvalidSubExpression;

                    // TODO: The spec states that this sub-expression needs to observe the state (ie. registers)
                    //       as it was upon entering the current subprogram. If this isn't being called at the
                    //       end of a frame unwind operation, an additional ThreadContext with this state will be needed.

                    if (isOpcodeRegisterLocation(block[0])) {
                        if (context.thread_context == null) return error.IncompleteExpressionContext;

                        var block_stream = std.io.fixedBufferStream(block);
                        const register = (try readOperand(&block_stream, block[0], context)).?.register;
                        const value = mem.readInt(usize, (try abi.regBytes(context.thread_context.?, register, context.reg_context))[0..@sizeOf(usize)], native_endian);
                        try self.stack.append(allocator, .{ .generic = value });
                    } else {
                        var stack_machine: Self = .{};
                        defer stack_machine.deinit(allocator);

                        var sub_context = context;
                        sub_context.entry_value_context = true;
                        const result = try stack_machine.run(block, allocator, sub_context, null);
                        try self.stack.append(allocator, result orelse return error.InvalidSubExpression);
                    }
                },

                // These have already been handled by readOperand
                OP.lo_user...OP.hi_user => unreachable,
                else => {
                    //std.debug.print("Unknown DWARF expression opcode: {x}\n", .{opcode});
                    return error.UnknownExpressionOpcode;
                },
            }

            return stream.pos < stream.buffer.len;
        }
    };
}

pub fn Builder(comptime options: Options) type {
    const addr_type = switch (options.addr_size) {
        2 => u16,
        4 => u32,
        8 => u64,
        else => @compileError("Unsupported address size of " ++ options.addr_size),
    };

    return struct {
        /// Zero-operand instructions
        pub fn writeOpcode(writer: anytype, comptime opcode: u8) !void {
            if (options.call_frame_context and !comptime isOpcodeValidInCFA(opcode)) return error.InvalidCFAOpcode;
            switch (opcode) {
                OP.dup,
                OP.drop,
                OP.over,
                OP.swap,
                OP.rot,
                OP.deref,
                OP.xderef,
                OP.push_object_address,
                OP.form_tls_address,
                OP.call_frame_cfa,
                OP.abs,
                OP.@"and",
                OP.div,
                OP.minus,
                OP.mod,
                OP.mul,
                OP.neg,
                OP.not,
                OP.@"or",
                OP.plus,
                OP.shl,
                OP.shr,
                OP.shra,
                OP.xor,
                OP.le,
                OP.ge,
                OP.eq,
                OP.lt,
                OP.gt,
                OP.ne,
                OP.nop,
                OP.stack_value,
                => try writer.writeByte(opcode),
                else => @compileError("This opcode requires operands, use `write<Opcode>()` instead"),
            }
        }

        // 2.5.1.1: Literal Encodings
        pub fn writeLiteral(writer: anytype, literal: u8) !void {
            switch (literal) {
                0...31 => |n| try writer.writeByte(n + OP.lit0),
                else => return error.InvalidLiteral,
            }
        }

        pub fn writeConst(writer: anytype, comptime T: type, value: T) !void {
            if (@typeInfo(T) != .int) @compileError("Constants must be integers");

            switch (T) {
                u8, i8, u16, i16, u32, i32, u64, i64 => {
                    try writer.writeByte(switch (T) {
                        u8 => OP.const1u,
                        i8 => OP.const1s,
                        u16 => OP.const2u,
                        i16 => OP.const2s,
                        u32 => OP.const4u,
                        i32 => OP.const4s,
                        u64 => OP.const8u,
                        i64 => OP.const8s,
                        else => unreachable,
                    });

                    try writer.writeInt(T, value, options.endian);
                },
                else => switch (@typeInfo(T).int.signedness) {
                    .unsigned => {
                        try writer.writeByte(OP.constu);
                        try leb.writeUleb128(writer, value);
                    },
                    .signed => {
                        try writer.writeByte(OP.consts);
                        try leb.writeIleb128(writer, value);
                    },
                },
            }
        }

        pub fn writeConstx(writer: anytype, debug_addr_offset: anytype) !void {
            try writer.writeByte(OP.constx);
            try leb.writeUleb128(writer, debug_addr_offset);
        }

        pub fn writeConstType(writer: anytype, die_offset: anytype, value_bytes: []const u8) !void {
            if (options.call_frame_context) return error.InvalidCFAOpcode;
            if (value_bytes.len > 0xff) return error.InvalidTypeLength;
            try writer.writeByte(OP.const_type);
            try leb.writeUleb128(writer, die_offset);
            try writer.writeByte(@intCast(value_bytes.len));
            try writer.writeAll(value_bytes);
        }

        pub fn writeAddr(writer: anytype, value: addr_type) !void {
            try writer.writeByte(OP.addr);
            try writer.writeInt(addr_type, value, options.endian);
        }

        pub fn writeAddrx(writer: anytype, debug_addr_offset: anytype) !void {
            if (options.call_frame_context) return error.InvalidCFAOpcode;
            try writer.writeByte(OP.addrx);
            try leb.writeUleb128(writer, debug_addr_offset);
        }

        // 2.5.1.2: Register Values
        pub fn writeFbreg(writer: anytype, offset: anytype) !void {
            try writer.writeByte(OP.fbreg);
            try leb.writeIleb128(writer, offset);
        }

        pub fn writeBreg(writer: anytype, register: u8, offset: anytype) !void {
            if (register > 31) return error.InvalidRegister;
            try writer.writeByte(OP.breg0 + register);
            try leb.writeIleb128(writer, offset);
        }

        pub fn writeBregx(writer: anytype, register: anytype, offset: anytype) !void {
            try writer.writeByte(OP.bregx);
            try leb.writeUleb128(writer, register);
            try leb.writeIleb128(writer, offset);
        }

        pub fn writeRegvalType(writer: anytype, register: anytype, offset: anytype) !void {
            if (options.call_frame_context) return error.InvalidCFAOpcode;
            try writer.writeByte(OP.regval_type);
            try leb.writeUleb128(writer, register);
            try leb.writeUleb128(writer, offset);
        }

        // 2.5.1.3: Stack Operations
        pub fn writePick(writer: anytype, index: u8) !void {
            try writer.writeByte(OP.pick);
            try writer.writeByte(index);
        }

        pub fn writeDerefSize(writer: anytype, size: u8) !void {
            try writer.writeByte(OP.deref_size);
            try writer.writeByte(size);
        }

        pub fn writeXDerefSize(writer: anytype, size: u8) !void {
            try writer.writeByte(OP.xderef_size);
            try writer.writeByte(size);
        }

        pub fn writeDerefType(writer: anytype, size: u8, die_offset: anytype) !void {
            if (options.call_frame_context) return error.InvalidCFAOpcode;
            try writer.writeByte(OP.deref_type);
            try writer.writeByte(size);
            try leb.writeUleb128(writer, die_offset);
        }

        pub fn writeXDerefType(writer: anytype, size: u8, die_offset: anytype) !void {
            try writer.writeByte(OP.xderef_type);
            try writer.writeByte(size);
            try leb.writeUleb128(writer, die_offset);
        }

        // 2.5.1.4: Arithmetic and Logical Operations

        pub fn writePlusUconst(writer: anytype, uint_value: anytype) !void {
            try writer.writeByte(OP.plus_uconst);
            try leb.writeUleb128(writer, uint_value);
        }

        // 2.5.1.5: Control Flow Operations

        pub fn writeSkip(writer: anytype, offset: i16) !void {
            try writer.writeByte(OP.skip);
            try writer.writeInt(i16, offset, options.endian);
        }

        pub fn writeBra(writer: anytype, offset: i16) !void {
            try writer.writeByte(OP.bra);
            try writer.writeInt(i16, offset, options.endian);
        }

        pub fn writeCall(writer: anytype, comptime T: type, offset: T) !void {
            if (options.call_frame_context) return error.InvalidCFAOpcode;
            switch (T) {
                u16 => try writer.writeByte(OP.call2),
                u32 => try writer.writeByte(OP.call4),
                else => @compileError("Call operand must be a 2 or 4 byte offset"),
            }

            try writer.writeInt(T, offset, options.endian);
        }

        pub fn writeCallRef(writer: anytype, comptime is_64: bool, value: if (is_64) u64 else u32) !void {
            if (options.call_frame_context) return error.InvalidCFAOpcode;
            try writer.writeByte(OP.call_ref);
            try writer.writeInt(if (is_64) u64 else u32, value, options.endian);
        }

        pub fn writeConvert(writer: anytype, die_offset: anytype) !void {
            if (options.call_frame_context) return error.InvalidCFAOpcode;
            try writer.writeByte(OP.convert);
            try leb.writeUleb128(writer, die_offset);
        }

        pub fn writeReinterpret(writer: anytype, die_offset: anytype) !void {
            if (options.call_frame_context) return error.InvalidCFAOpcode;
            try writer.writeByte(OP.reinterpret);
            try leb.writeUleb128(writer, die_offset);
        }

        // 2.5.1.7: Special Operations

        pub fn writeEntryValue(writer: anytype, expression: []const u8) !void {
            try writer.writeByte(OP.entry_value);
            try leb.writeUleb128(writer, expression.len);
            try writer.writeAll(expression);
        }

        // 2.6: Location Descriptions
        pub fn writeReg(writer: anytype, register: u8) !void {
            try writer.writeByte(OP.reg0 + register);
        }

        pub fn writeRegx(writer: anytype, register: anytype) !void {
            try writer.writeByte(OP.regx);
            try leb.writeUleb128(writer, register);
        }

        pub fn writeImplicitValue(writer: anytype, value_bytes: []const u8) !void {
            try writer.writeByte(OP.implicit_value);
            try leb.writeUleb128(writer, value_bytes.len);
            try writer.writeAll(value_bytes);
        }
    };
}

// Certain opcodes are not allowed in a CFA context, see 6.4.2
fn isOpcodeValidInCFA(opcode: u8) bool {
    return switch (opcode) {
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
        => false,
        else => true,
    };
}

fn isOpcodeRegisterLocation(opcode: u8) bool {
    return switch (opcode) {
        OP.reg0...OP.reg31, OP.regx => true,
        else => false,
    };
}

const testing = std.testing;
test "DWARF expressions" {
    const allocator = std.testing.allocator;

    const options = Options{};
    var stack_machine = StackMachine(options){};
    defer stack_machine.deinit(allocator);

    const b = Builder(options);

    var program = std.ArrayList(u8).init(allocator);
    defer program.deinit();

    const writer = program.writer();

    // Literals
    {
        const context = Context{};
        for (0..32) |i| {
            try b.writeLiteral(writer, @intCast(i));
        }

        _ = try stack_machine.run(program.items, allocator, context, 0);

        for (0..32) |i| {
            const expected = 31 - i;
            try testing.expectEqual(expected, stack_machine.stack.popOrNull().?.generic);
        }
    }

    // Constants
    {
        stack_machine.reset();
        program.clearRetainingCapacity();

        const input = [_]comptime_int{
            1,
            -1,
            @as(usize, @truncate(0x0fff)),
            @as(isize, @truncate(-0x0fff)),
            @as(usize, @truncate(0x0fffffff)),
            @as(isize, @truncate(-0x0fffffff)),
            @as(usize, @truncate(0x0fffffffffffffff)),
            @as(isize, @truncate(-0x0fffffffffffffff)),
            @as(usize, @truncate(0x8000000)),
            @as(isize, @truncate(-0x8000000)),
            @as(usize, @truncate(0x12345678_12345678)),
            @as(usize, @truncate(0xffffffff_ffffffff)),
            @as(usize, @truncate(0xeeeeeeee_eeeeeeee)),
        };

        try b.writeConst(writer, u8, input[0]);
        try b.writeConst(writer, i8, input[1]);
        try b.writeConst(writer, u16, input[2]);
        try b.writeConst(writer, i16, input[3]);
        try b.writeConst(writer, u32, input[4]);
        try b.writeConst(writer, i32, input[5]);
        try b.writeConst(writer, u64, input[6]);
        try b.writeConst(writer, i64, input[7]);
        try b.writeConst(writer, u28, input[8]);
        try b.writeConst(writer, i28, input[9]);
        try b.writeAddr(writer, input[10]);

        var mock_compile_unit: std.debug.Dwarf.CompileUnit = undefined;
        mock_compile_unit.addr_base = 1;

        var mock_debug_addr = std.ArrayList(u8).init(allocator);
        defer mock_debug_addr.deinit();

        try mock_debug_addr.writer().writeInt(u16, 0, native_endian);
        try mock_debug_addr.writer().writeInt(usize, input[11], native_endian);
        try mock_debug_addr.writer().writeInt(usize, input[12], native_endian);

        const context = Context{
            .compile_unit = &mock_compile_unit,
            .debug_addr = mock_debug_addr.items,
        };

        try b.writeConstx(writer, @as(usize, 1));
        try b.writeAddrx(writer, @as(usize, 1 + @sizeOf(usize)));

        const die_offset: usize = @truncate(0xaabbccdd);
        const type_bytes: []const u8 = &.{ 1, 2, 3, 4 };
        try b.writeConstType(writer, die_offset, type_bytes);

        _ = try stack_machine.run(program.items, allocator, context, 0);

        const const_type = stack_machine.stack.popOrNull().?.const_type;
        try testing.expectEqual(die_offset, const_type.type_offset);
        try testing.expectEqualSlices(u8, type_bytes, const_type.value_bytes);

        const expected = .{
            .{ usize, input[12], usize },
            .{ usize, input[11], usize },
            .{ usize, input[10], usize },
            .{ isize, input[9], isize },
            .{ usize, input[8], usize },
            .{ isize, input[7], isize },
            .{ usize, input[6], usize },
            .{ isize, input[5], isize },
            .{ usize, input[4], usize },
            .{ isize, input[3], isize },
            .{ usize, input[2], usize },
            .{ isize, input[1], isize },
            .{ usize, input[0], usize },
        };

        inline for (expected) |e| {
            try testing.expectEqual(@as(e[0], e[1]), @as(e[2], @bitCast(stack_machine.stack.popOrNull().?.generic)));
        }
    }

    // Register values
    if (@sizeOf(std.debug.ThreadContext) != 0) {
        stack_machine.reset();
        program.clearRetainingCapacity();

        const reg_context = abi.RegisterContext{
            .eh_frame = true,
            .is_macho = builtin.os.tag == .macos,
        };
        var thread_context: std.debug.ThreadContext = undefined;
        std.debug.relocateContext(&thread_context);
        const context = Context{
            .thread_context = &thread_context,
            .reg_context = reg_context,
        };

        // Only test register operations on arch / os that have them implemented
        if (abi.regBytes(&thread_context, 0, reg_context)) |reg_bytes| {

            // TODO: Test fbreg (once implemented): mock a DIE and point compile_unit.frame_base at it

            mem.writeInt(usize, reg_bytes[0..@sizeOf(usize)], 0xee, native_endian);
            (try abi.regValueNative(&thread_context, abi.fpRegNum(native_arch, reg_context), reg_context)).* = 1;
            (try abi.regValueNative(&thread_context, abi.spRegNum(native_arch, reg_context), reg_context)).* = 2;
            (try abi.regValueNative(&thread_context, abi.ipRegNum(native_arch).?, reg_context)).* = 3;

            try b.writeBreg(writer, abi.fpRegNum(native_arch, reg_context), @as(usize, 100));
            try b.writeBreg(writer, abi.spRegNum(native_arch, reg_context), @as(usize, 200));
            try b.writeBregx(writer, abi.ipRegNum(native_arch).?, @as(usize, 300));
            try b.writeRegvalType(writer, @as(u8, 0), @as(usize, 400));

            _ = try stack_machine.run(program.items, allocator, context, 0);

            const regval_type = stack_machine.stack.popOrNull().?.regval_type;
            try testing.expectEqual(@as(usize, 400), regval_type.type_offset);
            try testing.expectEqual(@as(u8, @sizeOf(usize)), regval_type.type_size);
            try testing.expectEqual(@as(usize, 0xee), regval_type.value);

            try testing.expectEqual(@as(usize, 303), stack_machine.stack.popOrNull().?.generic);
            try testing.expectEqual(@as(usize, 202), stack_machine.stack.popOrNull().?.generic);
            try testing.expectEqual(@as(usize, 101), stack_machine.stack.popOrNull().?.generic);
        } else |err| {
            switch (err) {
                error.UnimplementedArch,
                error.UnimplementedOs,
                error.ThreadContextNotSupported,
                => {},
                else => return err,
            }
        }
    }

    // Stack operations
    {
        var context = Context{};

        stack_machine.reset();
        program.clearRetainingCapacity();
        try b.writeConst(writer, u8, 1);
        try b.writeOpcode(writer, OP.dup);
        _ = try stack_machine.run(program.items, allocator, context, null);
        try testing.expectEqual(@as(usize, 1), stack_machine.stack.popOrNull().?.generic);
        try testing.expectEqual(@as(usize, 1), stack_machine.stack.popOrNull().?.generic);

        stack_machine.reset();
        program.clearRetainingCapacity();
        try b.writeConst(writer, u8, 1);
        try b.writeOpcode(writer, OP.drop);
        _ = try stack_machine.run(program.items, allocator, context, null);
        try testing.expect(stack_machine.stack.popOrNull() == null);

        stack_machine.reset();
        program.clearRetainingCapacity();
        try b.writeConst(writer, u8, 4);
        try b.writeConst(writer, u8, 5);
        try b.writeConst(writer, u8, 6);
        try b.writePick(writer, 2);
        _ = try stack_machine.run(program.items, allocator, context, null);
        try testing.expectEqual(@as(usize, 4), stack_machine.stack.popOrNull().?.generic);

        stack_machine.reset();
        program.clearRetainingCapacity();
        try b.writeConst(writer, u8, 4);
        try b.writeConst(writer, u8, 5);
        try b.writeConst(writer, u8, 6);
        try b.writeOpcode(writer, OP.over);
        _ = try stack_machine.run(program.items, allocator, context, null);
        try testing.expectEqual(@as(usize, 5), stack_machine.stack.popOrNull().?.generic);

        stack_machine.reset();
        program.clearRetainingCapacity();
        try b.writeConst(writer, u8, 5);
        try b.writeConst(writer, u8, 6);
        try b.writeOpcode(writer, OP.swap);
        _ = try stack_machine.run(program.items, allocator, context, null);
        try testing.expectEqual(@as(usize, 5), stack_machine.stack.popOrNull().?.generic);
        try testing.expectEqual(@as(usize, 6), stack_machine.stack.popOrNull().?.generic);

        stack_machine.reset();
        program.clearRetainingCapacity();
        try b.writeConst(writer, u8, 4);
        try b.writeConst(writer, u8, 5);
        try b.writeConst(writer, u8, 6);
        try b.writeOpcode(writer, OP.rot);
        _ = try stack_machine.run(program.items, allocator, context, null);
        try testing.expectEqual(@as(usize, 5), stack_machine.stack.popOrNull().?.generic);
        try testing.expectEqual(@as(usize, 4), stack_machine.stack.popOrNull().?.generic);
        try testing.expectEqual(@as(usize, 6), stack_machine.stack.popOrNull().?.generic);

        const deref_target: usize = @truncate(0xffeeffee_ffeeffee);

        stack_machine.reset();
        program.clearRetainingCapacity();
        try b.writeAddr(writer, @intFromPtr(&deref_target));
        try b.writeOpcode(writer, OP.deref);
        _ = try stack_machine.run(program.items, allocator, context, null);
        try testing.expectEqual(deref_target, stack_machine.stack.popOrNull().?.generic);

        stack_machine.reset();
        program.clearRetainingCapacity();
        try b.writeLiteral(writer, 0);
        try b.writeAddr(writer, @intFromPtr(&deref_target));
        try b.writeOpcode(writer, OP.xderef);
        _ = try stack_machine.run(program.items, allocator, context, null);
        try testing.expectEqual(deref_target, stack_machine.stack.popOrNull().?.generic);

        stack_machine.reset();
        program.clearRetainingCapacity();
        try b.writeAddr(writer, @intFromPtr(&deref_target));
        try b.writeDerefSize(writer, 1);
        _ = try stack_machine.run(program.items, allocator, context, null);
        try testing.expectEqual(@as(usize, @as(*const u8, @ptrCast(&deref_target)).*), stack_machine.stack.popOrNull().?.generic);

        stack_machine.reset();
        program.clearRetainingCapacity();
        try b.writeLiteral(writer, 0);
        try b.writeAddr(writer, @intFromPtr(&deref_target));
        try b.writeXDerefSize(writer, 1);
        _ = try stack_machine.run(program.items, allocator, context, null);
        try testing.expectEqual(@as(usize, @as(*const u8, @ptrCast(&deref_target)).*), stack_machine.stack.popOrNull().?.generic);

        const type_offset: usize = @truncate(0xaabbaabb_aabbaabb);

        stack_machine.reset();
        program.clearRetainingCapacity();
        try b.writeAddr(writer, @intFromPtr(&deref_target));
        try b.writeDerefType(writer, 1, type_offset);
        _ = try stack_machine.run(program.items, allocator, context, null);
        const deref_type = stack_machine.stack.popOrNull().?.regval_type;
        try testing.expectEqual(type_offset, deref_type.type_offset);
        try testing.expectEqual(@as(u8, 1), deref_type.type_size);
        try testing.expectEqual(@as(usize, @as(*const u8, @ptrCast(&deref_target)).*), deref_type.value);

        stack_machine.reset();
        program.clearRetainingCapacity();
        try b.writeLiteral(writer, 0);
        try b.writeAddr(writer, @intFromPtr(&deref_target));
        try b.writeXDerefType(writer, 1, type_offset);
        _ = try stack_machine.run(program.items, allocator, context, null);
        const xderef_type = stack_machine.stack.popOrNull().?.regval_type;
        try testing.expectEqual(type_offset, xderef_type.type_offset);
        try testing.expectEqual(@as(u8, 1), xderef_type.type_size);
        try testing.expectEqual(@as(usize, @as(*const u8, @ptrCast(&deref_target)).*), xderef_type.value);

        context.object_address = &deref_target;

        stack_machine.reset();
        program.clearRetainingCapacity();
        try b.writeOpcode(writer, OP.push_object_address);
        _ = try stack_machine.run(program.items, allocator, context, null);
        try testing.expectEqual(@as(usize, @intFromPtr(context.object_address.?)), stack_machine.stack.popOrNull().?.generic);

        // TODO: Test OP.form_tls_address

        context.cfa = @truncate(0xccddccdd_ccddccdd);

        stack_machine.reset();
        program.clearRetainingCapacity();
        try b.writeOpcode(writer, OP.call_frame_cfa);
        _ = try stack_machine.run(program.items, allocator, context, null);
        try testing.expectEqual(context.cfa.?, stack_machine.stack.popOrNull().?.generic);
    }

    // Arithmetic and Logical Operations
    {
        const context = Context{};

        stack_machine.reset();
        program.clearRetainingCapacity();
        try b.writeConst(writer, i16, -4096);
        try b.writeOpcode(writer, OP.abs);
        _ = try stack_machine.run(program.items, allocator, context, null);
        try testing.expectEqual(@as(usize, 4096), stack_machine.stack.popOrNull().?.generic);

        stack_machine.reset();
        program.clearRetainingCapacity();
        try b.writeConst(writer, u16, 0xff0f);
        try b.writeConst(writer, u16, 0xf0ff);
        try b.writeOpcode(writer, OP.@"and");
        _ = try stack_machine.run(program.items, allocator, context, null);
        try testing.expectEqual(@as(usize, 0xf00f), stack_machine.stack.popOrNull().?.generic);

        stack_machine.reset();
        program.clearRetainingCapacity();
        try b.writeConst(writer, i16, -404);
        try b.writeConst(writer, i16, 100);
        try b.writeOpcode(writer, OP.div);
        _ = try stack_machine.run(program.items, allocator, context, null);
        try testing.expectEqual(@as(isize, -404 / 100), @as(isize, @bitCast(stack_machine.stack.popOrNull().?.generic)));

        stack_machine.reset();
        program.clearRetainingCapacity();
        try b.writeConst(writer, u16, 200);
        try b.writeConst(writer, u16, 50);
        try b.writeOpcode(writer, OP.minus);
        _ = try stack_machine.run(program.items, allocator, context, null);
        try testing.expectEqual(@as(usize, 150), stack_machine.stack.popOrNull().?.generic);

        stack_machine.reset();
        program.clearRetainingCapacity();
        try b.writeConst(writer, u16, 123);
        try b.writeConst(writer, u16, 100);
        try b.writeOpcode(writer, OP.mod);
        _ = try stack_machine.run(program.items, allocator, context, null);
        try testing.expectEqual(@as(usize, 23), stack_machine.stack.popOrNull().?.generic);

        stack_machine.reset();
        program.clearRetainingCapacity();
        try b.writeConst(writer, u16, 0xff);
        try b.writeConst(writer, u16, 0xee);
        try b.writeOpcode(writer, OP.mul);
        _ = try stack_machine.run(program.items, allocator, context, null);
        try testing.expectEqual(@as(usize, 0xed12), stack_machine.stack.popOrNull().?.generic);

        stack_machine.reset();
        program.clearRetainingCapacity();
        try b.writeConst(writer, u16, 5);
        try b.writeOpcode(writer, OP.neg);
        try b.writeConst(writer, i16, -6);
        try b.writeOpcode(writer, OP.neg);
        _ = try stack_machine.run(program.items, allocator, context, null);
        try testing.expectEqual(@as(usize, 6), stack_machine.stack.popOrNull().?.generic);
        try testing.expectEqual(@as(isize, -5), @as(isize, @bitCast(stack_machine.stack.popOrNull().?.generic)));

        stack_machine.reset();
        program.clearRetainingCapacity();
        try b.writeConst(writer, u16, 0xff0f);
        try b.writeOpcode(writer, OP.not);
        _ = try stack_machine.run(program.items, allocator, context, null);
        try testing.expectEqual(~@as(usize, 0xff0f), stack_machine.stack.popOrNull().?.generic);

        stack_machine.reset();
        program.clearRetainingCapacity();
        try b.writeConst(writer, u16, 0xff0f);
        try b.writeConst(writer, u16, 0xf0ff);
        try b.writeOpcode(writer, OP.@"or");
        _ = try stack_machine.run(program.items, allocator, context, null);
        try testing.expectEqual(@as(usize, 0xffff), stack_machine.stack.popOrNull().?.generic);

        stack_machine.reset();
        program.clearRetainingCapacity();
        try b.writeConst(writer, i16, 402);
        try b.writeConst(writer, i16, 100);
        try b.writeOpcode(writer, OP.plus);
        _ = try stack_machine.run(program.items, allocator, context, null);
        try testing.expectEqual(@as(usize, 502), stack_machine.stack.popOrNull().?.generic);

        stack_machine.reset();
        program.clearRetainingCapacity();
        try b.writeConst(writer, u16, 4096);
        try b.writePlusUconst(writer, @as(usize, 8192));
        _ = try stack_machine.run(program.items, allocator, context, null);
        try testing.expectEqual(@as(usize, 4096 + 8192), stack_machine.stack.popOrNull().?.generic);

        stack_machine.reset();
        program.clearRetainingCapacity();
        try b.writeConst(writer, u16, 0xfff);
        try b.writeConst(writer, u16, 1);
        try b.writeOpcode(writer, OP.shl);
        _ = try stack_machine.run(program.items, allocator, context, null);
        try testing.expectEqual(@as(usize, 0xfff << 1), stack_machine.stack.popOrNull().?.generic);

        stack_machine.reset();
        program.clearRetainingCapacity();
        try b.writeConst(writer, u16, 0xfff);
        try b.writeConst(writer, u16, 1);
        try b.writeOpcode(writer, OP.shr);
        _ = try stack_machine.run(program.items, allocator, context, null);
        try testing.expectEqual(@as(usize, 0xfff >> 1), stack_machine.stack.popOrNull().?.generic);

        stack_machine.reset();
        program.clearRetainingCapacity();
        try b.writeConst(writer, u16, 0xfff);
        try b.writeConst(writer, u16, 1);
        try b.writeOpcode(writer, OP.shr);
        _ = try stack_machine.run(program.items, allocator, context, null);
        try testing.expectEqual(@as(usize, @bitCast(@as(isize, 0xfff) >> 1)), stack_machine.stack.popOrNull().?.generic);

        stack_machine.reset();
        program.clearRetainingCapacity();
        try b.writeConst(writer, u16, 0xf0ff);
        try b.writeConst(writer, u16, 0xff0f);
        try b.writeOpcode(writer, OP.xor);
        _ = try stack_machine.run(program.items, allocator, context, null);
        try testing.expectEqual(@as(usize, 0x0ff0), stack_machine.stack.popOrNull().?.generic);
    }

    // Control Flow Operations
    {
        const context = Context{};
        const expected = .{
            .{ OP.le, 1, 1, 0 },
            .{ OP.ge, 1, 0, 1 },
            .{ OP.eq, 1, 0, 0 },
            .{ OP.lt, 0, 1, 0 },
            .{ OP.gt, 0, 0, 1 },
            .{ OP.ne, 0, 1, 1 },
        };

        inline for (expected) |e| {
            stack_machine.reset();
            program.clearRetainingCapacity();

            try b.writeConst(writer, u16, 0);
            try b.writeConst(writer, u16, 0);
            try b.writeOpcode(writer, e[0]);
            try b.writeConst(writer, u16, 0);
            try b.writeConst(writer, u16, 1);
            try b.writeOpcode(writer, e[0]);
            try b.writeConst(writer, u16, 1);
            try b.writeConst(writer, u16, 0);
            try b.writeOpcode(writer, e[0]);
            _ = try stack_machine.run(program.items, allocator, context, null);
            try testing.expectEqual(@as(usize, e[3]), stack_machine.stack.popOrNull().?.generic);
            try testing.expectEqual(@as(usize, e[2]), stack_machine.stack.popOrNull().?.generic);
            try testing.expectEqual(@as(usize, e[1]), stack_machine.stack.popOrNull().?.generic);
        }

        stack_machine.reset();
        program.clearRetainingCapacity();
        try b.writeLiteral(writer, 2);
        try b.writeSkip(writer, 1);
        try b.writeLiteral(writer, 3);
        _ = try stack_machine.run(program.items, allocator, context, null);
        try testing.expectEqual(@as(usize, 2), stack_machine.stack.popOrNull().?.generic);

        stack_machine.reset();
        program.clearRetainingCapacity();
        try b.writeLiteral(writer, 2);
        try b.writeBra(writer, 1);
        try b.writeLiteral(writer, 3);
        try b.writeLiteral(writer, 0);
        try b.writeBra(writer, 1);
        try b.writeLiteral(writer, 4);
        try b.writeLiteral(writer, 5);
        _ = try stack_machine.run(program.items, allocator, context, null);
        try testing.expectEqual(@as(usize, 5), stack_machine.stack.popOrNull().?.generic);
        try testing.expectEqual(@as(usize, 4), stack_machine.stack.popOrNull().?.generic);
        try testing.expect(stack_machine.stack.popOrNull() == null);

        // TODO: Test call2, call4, call_ref once implemented

    }

    // Type conversions
    {
        const context = Context{};
        stack_machine.reset();
        program.clearRetainingCapacity();

        // TODO: Test typed OP.convert once implemented

        const value: usize = @truncate(0xffeeffee_ffeeffee);
        var value_bytes: [options.addr_size]u8 = undefined;
        mem.writeInt(usize, &value_bytes, value, native_endian);

        // Convert to generic type
        stack_machine.reset();
        program.clearRetainingCapacity();
        try b.writeConstType(writer, @as(usize, 0), &value_bytes);
        try b.writeConvert(writer, @as(usize, 0));
        _ = try stack_machine.run(program.items, allocator, context, null);
        try testing.expectEqual(value, stack_machine.stack.popOrNull().?.generic);

        // Reinterpret to generic type
        stack_machine.reset();
        program.clearRetainingCapacity();
        try b.writeConstType(writer, @as(usize, 0), &value_bytes);
        try b.writeReinterpret(writer, @as(usize, 0));
        _ = try stack_machine.run(program.items, allocator, context, null);
        try testing.expectEqual(value, stack_machine.stack.popOrNull().?.generic);

        // Reinterpret to new type
        const die_offset: usize = 0xffee;

        stack_machine.reset();
        program.clearRetainingCapacity();
        try b.writeConstType(writer, @as(usize, 0), &value_bytes);
        try b.writeReinterpret(writer, die_offset);
        _ = try stack_machine.run(program.items, allocator, context, null);
        const const_type = stack_machine.stack.popOrNull().?.const_type;
        try testing.expectEqual(die_offset, const_type.type_offset);

        stack_machine.reset();
        program.clearRetainingCapacity();
        try b.writeLiteral(writer, 0);
        try b.writeReinterpret(writer, die_offset);
        _ = try stack_machine.run(program.items, allocator, context, null);
        const regval_type = stack_machine.stack.popOrNull().?.regval_type;
        try testing.expectEqual(die_offset, regval_type.type_offset);
    }

    // Special operations
    {
        var context = Context{};

        stack_machine.reset();
        program.clearRetainingCapacity();
        try b.writeOpcode(writer, OP.nop);
        _ = try stack_machine.run(program.items, allocator, context, null);
        try testing.expect(stack_machine.stack.popOrNull() == null);

        // Sub-expression
        {
            var sub_program = std.ArrayList(u8).init(allocator);
            defer sub_program.deinit();
            const sub_writer = sub_program.writer();
            try b.writeLiteral(sub_writer, 3);

            stack_machine.reset();
            program.clearRetainingCapacity();
            try b.writeEntryValue(writer, sub_program.items);
            _ = try stack_machine.run(program.items, allocator, context, null);
            try testing.expectEqual(@as(usize, 3), stack_machine.stack.popOrNull().?.generic);
        }

        // Register location description
        const reg_context = abi.RegisterContext{
            .eh_frame = true,
            .is_macho = builtin.os.tag == .macos,
        };
        var thread_context: std.debug.ThreadContext = undefined;
        std.debug.relocateContext(&thread_context);
        context = Context{
            .thread_context = &thread_context,
            .reg_context = reg_context,
        };

        if (abi.regBytes(&thread_context, 0, reg_context)) |reg_bytes| {
            mem.writeInt(usize, reg_bytes[0..@sizeOf(usize)], 0xee, native_endian);

            var sub_program = std.ArrayList(u8).init(allocator);
            defer sub_program.deinit();
            const sub_writer = sub_program.writer();
            try b.writeReg(sub_writer, 0);

            stack_machine.reset();
            program.clearRetainingCapacity();
            try b.writeEntryValue(writer, sub_program.items);
            _ = try stack_machine.run(program.items, allocator, context, null);
            try testing.expectEqual(@as(usize, 0xee), stack_machine.stack.popOrNull().?.generic);
        } else |err| {
            switch (err) {
                error.UnimplementedArch,
                error.UnimplementedOs,
                error.ThreadContextNotSupported,
                => {},
                else => return err,
            }
        }
    }
}
