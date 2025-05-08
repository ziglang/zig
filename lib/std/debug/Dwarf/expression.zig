const builtin = @import("builtin");
const native_arch = builtin.cpu.arch;
const native_endian = native_arch.endian();

const std = @import("std");
const leb = std.leb;
const OP = std.dwarf.OP;
const abi = std.debug.Dwarf.abi;
const mem = std.mem;
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;

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

pub const RunError = error{
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

    OutOfMemory,
    EndOfStream,
    Overflow,
    DivisionByZero,
} || abi.RegBytesError;

/// A stack machine that can decode and run DWARF expressions.
/// Expressions can be decoded for non-native address size and endianness,
/// but can only be executed if the current target matches the configuration.
pub fn StackMachine(comptime options: Options) type {
    const Address = switch (options.addr_size) {
        2 => u16,
        4 => u32,
        8 => u64,
        else => @compileError("Unsupported address size of " ++ options.addr_size),
    };
    const SignedAddress = switch (options.addr_size) {
        2 => i16,
        4 => i32,
        8 => i64,
        else => @compileError("Unsupported address size of " ++ options.addr_size),
    };
    return struct {
        stack: std.ArrayListUnmanaged(Value) = .empty,

        const Self = @This();

        const Value = union(enum) {
            generic: Address,

            // Typed value with a maximum size of a register
            regval_type: struct {
                // Offset of DW_TAG_base_type DIE
                type_offset: Address,
                type_size: u8,
                value: Address,
            },

            // Typed value specified directly in the instruction stream
            const_type: struct {
                // Offset of DW_TAG_base_type DIE
                type_offset: Address,
                // Backed by the instruction stream
                value_bytes: []const u8,
            },

            fn asIntegral(self: Value) !Address {
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

                        return std.math.cast(Address, value) orelse error.TruncatedIntegralType;
                    },
                };
            }

            fn fromInt(int: anytype) Value {
                const info = @typeInfo(@TypeOf(int)).int;
                if (@sizeOf(@TypeOf(int)) > options.addr_size) {
                    return .{ .generic = switch (info.signedness) {
                        .signed => @bitCast(@as(SignedAddress, @truncate(int))),
                        .unsigned => @truncate(int),
                    } };
                } else {
                    return .{ .generic = switch (info.signedness) {
                        .signed => @bitCast(@as(SignedAddress, @intCast(int))),
                        .unsigned => @intCast(int),
                    } };
                }
            }
        };

        pub fn reset(self: *Self) void {
            self.stack.clearRetainingCapacity();
        }

        pub fn deinit(self: *Self, allocator: Allocator) void {
            self.stack.deinit(allocator);
        }

        pub fn run(
            self: *Self,
            expression: []const u8,
            gpa: Allocator,
            context: Context,
            initial_value: ?usize,
        ) RunError!?Value {
            if (@sizeOf(usize) != @sizeOf(Address) or options.endian != native_endian) {
                // This restriction can be removed when the `@ptrFromInt` calls are removed.
                @compileError("Execution of non-native address sizes / endianness is not supported");
            }

            const stack = &self.stack;
            if (initial_value) |i| try stack.append(gpa, .{ .generic = i });

            var i: usize = 0;
            // TODO: https://github.com/ziglang/zig/issues/15556
            op: switch (nextOpcode(expression, &i)) {
                // 2.5.1.1: Literal Encodings
                @intFromEnum(OP.lit0)...@intFromEnum(OP.lit31) => |n| {
                    try stack.append(gpa, .{ .generic = n - @intFromEnum(OP.lit0) });
                    continue :op nextOpcode(expression, &i);
                },
                @intFromEnum(OP.addr) => {
                    try stack.append(gpa, .fromInt(try nextInt(expression, &i, Address)));
                    continue :op nextOpcode(expression, &i);
                },
                @intFromEnum(OP.const1u) => {
                    try stack.append(gpa, .fromInt(try nextInt(expression, &i, u8)));
                    continue :op nextOpcode(expression, &i);
                },
                @intFromEnum(OP.const2u) => {
                    try stack.append(gpa, .fromInt(try nextInt(expression, &i, u16)));
                    continue :op nextOpcode(expression, &i);
                },
                @intFromEnum(OP.const4u) => {
                    try stack.append(gpa, .fromInt(try nextInt(expression, &i, u32)));
                    continue :op nextOpcode(expression, &i);
                },
                @intFromEnum(OP.const8u) => {
                    try stack.append(gpa, .fromInt(try nextInt(expression, &i, u64)));
                    continue :op nextOpcode(expression, &i);
                },
                @intFromEnum(OP.const1s) => {
                    try stack.append(gpa, .fromInt(try nextInt(expression, &i, i8)));
                    continue :op nextOpcode(expression, &i);
                },
                @intFromEnum(OP.const2s) => {
                    try stack.append(gpa, .fromInt(try nextInt(expression, &i, i16)));
                    continue :op nextOpcode(expression, &i);
                },
                @intFromEnum(OP.const4s) => {
                    try stack.append(gpa, .fromInt(try nextInt(expression, &i, i32)));
                    continue :op nextOpcode(expression, &i);
                },
                @intFromEnum(OP.const8s) => {
                    try stack.append(gpa, .fromInt(try nextInt(expression, &i, i64)));
                    continue :op nextOpcode(expression, &i);
                },
                @intFromEnum(OP.constu) => {
                    try stack.append(gpa, .fromInt(try nextLeb128(expression, &i, u64)));
                    continue :op nextOpcode(expression, &i);
                },
                @intFromEnum(OP.consts) => {
                    try stack.append(gpa, .fromInt(try nextLeb128(expression, &i, i64)));
                    continue :op nextOpcode(expression, &i);
                },

                @intFromEnum(OP.const_type) => {
                    if (options.call_frame_context) return error.InvalidCFAOpcode;
                    try stack.append(gpa, .{ .const_type = .{
                        .type_offset = try nextLeb128(expression, &i, Address),
                        .value_bytes = try nextSlice(expression, &i, try nextInt(expression, &i, u8)),
                    } });
                    continue :op nextOpcode(expression, &i);
                },

                @intFromEnum(OP.addrx),
                @intFromEnum(OP.constx),
                => {
                    if (options.call_frame_context) return error.InvalidCFAOpcode;
                    const compile_unit = context.compile_unit orelse return error.IncompleteExpressionContext;
                    const debug_addr = context.debug_addr orelse return error.IncompleteExpressionContext;
                    const debug_addr_index = try nextLeb128(expression, &i, u64);
                    const offset = compile_unit.addr_base + debug_addr_index;
                    if (offset >= debug_addr.len) return error.InvalidExpression;
                    const value = mem.readInt(Address, debug_addr[offset..][0..@sizeOf(Address)], options.endian);
                    try stack.append(gpa, .fromInt(value));
                    continue :op nextOpcode(expression, &i);
                },

                // 2.5.1.2: Register Values
                @intFromEnum(OP.fbreg) => {
                    const compile_unit = context.compile_unit orelse return error.IncompleteExpressionContext;
                    const frame_base = compile_unit.frame_base orelse return error.IncompleteExpressionContext;

                    const offset = try nextLeb128(expression, &i, i64);
                    _ = offset;

                    switch (frame_base.*) {
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
                @intFromEnum(OP.breg0)...@intFromEnum(OP.breg31) => |n| {
                    const thread_context = context.thread_context orelse return error.IncompleteExpressionContext;
                    const base_register = n - @intFromEnum(OP.breg0);
                    const offset = try nextLeb128(expression, &i, i64);
                    const reg_bytes = try abi.regBytes(thread_context, base_register, context.reg_context);
                    const start_addr = mem.readInt(Address, reg_bytes[0..@sizeOf(Address)], options.endian);
                    try stack.append(gpa, .{
                        .generic = std.math.addAny(Address, start_addr, offset) orelse
                            return error.InvalidExpression,
                    });
                    continue :op nextOpcode(expression, &i);
                },
                @intFromEnum(OP.bregx) => {
                    const thread_context = context.thread_context orelse return error.IncompleteExpressionContext;
                    const base_register = try nextLeb128(expression, &i, u8);
                    const offset = try nextLeb128(expression, &i, i64);
                    const reg_bytes = try abi.regBytes(thread_context, base_register, context.reg_context);
                    const start_addr = mem.readInt(Address, reg_bytes[0..@sizeOf(Address)], options.endian);
                    try stack.append(gpa, .{
                        .generic = std.math.addAny(Address, start_addr, offset) orelse
                            return error.InvalidExpression,
                    });
                    continue :op nextOpcode(expression, &i);
                },
                @intFromEnum(OP.regval_type) => {
                    if (options.call_frame_context) return error.InvalidCFAOpcode;
                    const thread_context = context.thread_context orelse return error.IncompleteExpressionContext;
                    const register = try nextLeb128(expression, &i, u8);
                    const type_offset = try nextLeb128(expression, &i, Address);
                    const reg_bytes = try abi.regBytes(thread_context, register, context.reg_context);
                    const value = mem.readInt(Address, reg_bytes[0..@sizeOf(Address)], options.endian);
                    try stack.append(gpa, .{
                        .regval_type = .{
                            .type_offset = type_offset,
                            .type_size = @sizeOf(Address),
                            .value = value,
                        },
                    });
                    continue :op nextOpcode(expression, &i);
                },

                // 2.5.1.3: Stack Operations
                @intFromEnum(OP.dup) => {
                    if (stack.items.len == 0) return error.InvalidExpression;
                    try stack.append(gpa, stack.items[stack.items.len - 1]);
                    continue :op nextOpcode(expression, &i);
                },
                @intFromEnum(OP.drop) => {
                    _ = stack.pop();
                    continue :op nextOpcode(expression, &i);
                },
                @intFromEnum(OP.pick) => {
                    const stack_index = try nextInt(expression, &i, u8);
                    if (stack_index >= stack.items.len) return error.InvalidExpression;
                    try stack.append(gpa, stack.items[stack.items.len - 1 - stack_index]);
                    continue :op nextOpcode(expression, &i);
                },
                @intFromEnum(OP.over) => {
                    if (stack.items.len < 2) return error.InvalidExpression;
                    try stack.append(gpa, stack.items[stack.items.len - 2]);
                    continue :op nextOpcode(expression, &i);
                },
                @intFromEnum(OP.swap) => {
                    if (stack.items.len < 2) return error.InvalidExpression;
                    mem.swap(Value, &stack.items[stack.items.len - 1], &stack.items[stack.items.len - 2]);
                    continue :op nextOpcode(expression, &i);
                },
                @intFromEnum(OP.rot) => {
                    if (stack.items.len < 3) return error.InvalidExpression;
                    const first = stack.items[stack.items.len - 1];
                    stack.items[stack.items.len - 1] = stack.items[stack.items.len - 2];
                    stack.items[stack.items.len - 2] = stack.items[stack.items.len - 3];
                    stack.items[stack.items.len - 3] = first;
                    continue :op nextOpcode(expression, &i);
                },

                @intFromEnum(OP.deref_type) => {
                    if (options.call_frame_context) return error.InvalidCFAOpcode;
                    if (stack.items.len == 0) return error.InvalidExpression;
                    const size = try nextInt(expression, &i, u8);
                    const type_offset = try nextLeb128(expression, &i, Address);
                    const addr = try stack.items[stack.items.len - 1].asIntegral();
                    const loaded = try accessAddress(size, addr, context.memory_accessor);
                    stack.items[stack.items.len - 1] = .{
                        .regval_type = .{
                            .type_offset = type_offset,
                            .type_size = size,
                            .value = loaded,
                        },
                    };
                    continue :op nextOpcode(expression, &i);
                },
                @intFromEnum(OP.deref_size) => {
                    if (stack.items.len == 0) return error.InvalidExpression;
                    const addr = try stack.items[stack.items.len - 1].asIntegral();
                    const type_size = try nextInt(expression, &i, u8);
                    const loaded = try accessAddress(type_size, addr, context.memory_accessor);
                    stack.items[stack.items.len - 1] = .{ .generic = loaded };
                    continue :op nextOpcode(expression, &i);
                },
                @intFromEnum(OP.xderef_size) => {
                    if (stack.items.len < 2) return error.InvalidExpression;
                    const type_size = try nextInt(expression, &i, u8);
                    const addr = try stack.pop().?.asIntegral();
                    const addr_space_identifier = try stack.items[stack.items.len - 1].asIntegral();
                    // Usage of addr_space_identifier in the address calculation is implementation defined.
                    // This code will need to be updated to handle any architectures that utilize this.
                    _ = addr_space_identifier;
                    const loaded = try accessAddress(type_size, addr, context.memory_accessor);
                    stack.items[stack.items.len - 1] = .{ .generic = loaded };
                    continue :op nextOpcode(expression, &i);
                },
                @intFromEnum(OP.deref) => {
                    if (stack.items.len == 0) return error.InvalidExpression;
                    const addr = try stack.items[stack.items.len - 1].asIntegral();
                    const loaded = try accessAddress(@sizeOf(Address), addr, context.memory_accessor);
                    stack.items[stack.items.len - 1] = .{ .generic = loaded };
                    continue :op nextOpcode(expression, &i);
                },
                @intFromEnum(OP.xderef) => {
                    if (stack.items.len < 2) return error.InvalidExpression;
                    const addr = try stack.pop().?.asIntegral();
                    const addr_space_identifier = try stack.items[stack.items.len - 1].asIntegral();
                    // Usage of addr_space_identifier in the address calculation is implementation defined.
                    // This code will need to be updated to handle any architectures that utilize this.
                    _ = addr_space_identifier;
                    const loaded = try accessAddress(@sizeOf(Address), addr, context.memory_accessor);
                    stack.items[stack.items.len - 1] = .{ .generic = loaded };
                    continue :op nextOpcode(expression, &i);
                },

                @intFromEnum(OP.xderef_type),
                => {
                    if (stack.items.len < 2) return error.InvalidExpression;
                    const addr = try stack.pop().?.asIntegral();
                    const addr_space_identifier = try stack.items[stack.items.len - 1].asIntegral();
                    // Usage of addr_space_identifier in the address calculation is implementation defined.
                    // This code will need to be updated to handle any architectures that utilize this.
                    _ = addr_space_identifier;
                    const size = try nextInt(expression, &i, u8);
                    const type_offset = try nextLeb128(expression, &i, Address);
                    const loaded = try accessAddress(size, addr, context.memory_accessor);
                    stack.items[stack.items.len - 1] = .{
                        .regval_type = .{
                            .type_offset = type_offset,
                            .type_size = size,
                            .value = loaded,
                        },
                    };
                    continue :op nextOpcode(expression, &i);
                },
                @intFromEnum(OP.push_object_address) => {
                    if (options.call_frame_context) return error.InvalidCFAOpcode;
                    // In sub-expressions, `push_object_address` is not meaningful (as per the
                    // spec), so treat it like a nop
                    if (!context.entry_value_context) {
                        if (context.object_address == null) return error.IncompleteExpressionContext;
                        try stack.append(gpa, .{ .generic = @intFromPtr(context.object_address.?) });
                    }
                },
                @intFromEnum(OP.form_tls_address) => {
                    return error.UnimplementedOpcode;
                },
                @intFromEnum(OP.call_frame_cfa) => {
                    if (options.call_frame_context) return error.InvalidCFAOpcode;
                    if (context.cfa) |cfa| {
                        try stack.append(gpa, .{ .generic = cfa });
                    } else return error.IncompleteExpressionContext;
                    continue :op nextOpcode(expression, &i);
                },

                // 2.5.1.4: Arithmetic and Logical Operations
                @intFromEnum(OP.abs) => {
                    if (stack.items.len == 0) return error.InvalidExpression;
                    const value: isize = @bitCast(try stack.items[stack.items.len - 1].asIntegral());
                    stack.items[stack.items.len - 1] = .{
                        .generic = @abs(value),
                    };
                    continue :op nextOpcode(expression, &i);
                },
                @intFromEnum(OP.@"and") => {
                    if (stack.items.len < 2) return error.InvalidExpression;
                    const a = try stack.pop().?.asIntegral();
                    stack.items[stack.items.len - 1] = .{
                        .generic = a & try stack.items[stack.items.len - 1].asIntegral(),
                    };
                    continue :op nextOpcode(expression, &i);
                },
                @intFromEnum(OP.div) => {
                    if (stack.items.len < 2) return error.InvalidExpression;
                    const a: isize = @bitCast(try stack.pop().?.asIntegral());
                    const b: isize = @bitCast(try stack.items[stack.items.len - 1].asIntegral());
                    stack.items[stack.items.len - 1] = .{
                        .generic = @bitCast(try std.math.divTrunc(isize, b, a)),
                    };
                    continue :op nextOpcode(expression, &i);
                },
                @intFromEnum(OP.minus) => {
                    if (stack.items.len < 2) return error.InvalidExpression;
                    const b = try stack.pop().?.asIntegral();
                    stack.items[stack.items.len - 1] = .{
                        .generic = try std.math.sub(Address, try stack.items[stack.items.len - 1].asIntegral(), b),
                    };
                    continue :op nextOpcode(expression, &i);
                },
                @intFromEnum(OP.mod) => {
                    if (stack.items.len < 2) return error.InvalidExpression;
                    const a: isize = @bitCast(try stack.pop().?.asIntegral());
                    const b: isize = @bitCast(try stack.items[stack.items.len - 1].asIntegral());
                    stack.items[stack.items.len - 1] = .{
                        .generic = @bitCast(@mod(b, a)),
                    };
                    continue :op nextOpcode(expression, &i);
                },
                @intFromEnum(OP.mul) => {
                    if (stack.items.len < 2) return error.InvalidExpression;
                    const a: isize = @bitCast(try stack.pop().?.asIntegral());
                    const b: isize = @bitCast(try stack.items[stack.items.len - 1].asIntegral());
                    stack.items[stack.items.len - 1] = .{
                        .generic = @bitCast(@mulWithOverflow(a, b)[0]),
                    };
                    continue :op nextOpcode(expression, &i);
                },
                @intFromEnum(OP.neg) => {
                    if (stack.items.len == 0) return error.InvalidExpression;
                    stack.items[stack.items.len - 1] = .{
                        .generic = @bitCast(
                            try std.math.negate(
                                @as(isize, @bitCast(try stack.items[stack.items.len - 1].asIntegral())),
                            ),
                        ),
                    };
                    continue :op nextOpcode(expression, &i);
                },
                @intFromEnum(OP.not) => {
                    if (stack.items.len == 0) return error.InvalidExpression;
                    stack.items[stack.items.len - 1] = .{
                        .generic = ~try stack.items[stack.items.len - 1].asIntegral(),
                    };
                    continue :op nextOpcode(expression, &i);
                },
                @intFromEnum(OP.@"or") => {
                    if (stack.items.len < 2) return error.InvalidExpression;
                    const a = try stack.pop().?.asIntegral();
                    stack.items[stack.items.len - 1] = .{
                        .generic = a | try stack.items[stack.items.len - 1].asIntegral(),
                    };
                    continue :op nextOpcode(expression, &i);
                },
                @intFromEnum(OP.plus) => {
                    if (stack.items.len < 2) return error.InvalidExpression;
                    const b = try stack.pop().?.asIntegral();
                    stack.items[stack.items.len - 1] = .{
                        .generic = try std.math.add(Address, try stack.items[stack.items.len - 1].asIntegral(), b),
                    };
                    continue :op nextOpcode(expression, &i);
                },
                @intFromEnum(OP.plus_uconst) => {
                    if (stack.items.len == 0) return error.InvalidExpression;
                    stack.items[stack.items.len - 1] = .{ .generic = std.math.addAny(
                        Address,
                        try nextLeb128(expression, &i, u64),
                        try stack.items[stack.items.len - 1].asIntegral(),
                    ) orelse return error.Overflow };
                    continue :op nextOpcode(expression, &i);
                },
                @intFromEnum(OP.shl) => {
                    if (stack.items.len < 2) return error.InvalidExpression;
                    const a = try stack.pop().?.asIntegral();
                    const b = try stack.items[stack.items.len - 1].asIntegral();
                    stack.items[stack.items.len - 1] = .{
                        .generic = std.math.shl(usize, b, a),
                    };
                    continue :op nextOpcode(expression, &i);
                },
                @intFromEnum(OP.shr) => {
                    if (stack.items.len < 2) return error.InvalidExpression;
                    const a = try stack.pop().?.asIntegral();
                    const b = try stack.items[stack.items.len - 1].asIntegral();
                    stack.items[stack.items.len - 1] = .{
                        .generic = std.math.shr(usize, b, a),
                    };
                    continue :op nextOpcode(expression, &i);
                },
                @intFromEnum(OP.shra) => {
                    if (stack.items.len < 2) return error.InvalidExpression;
                    const a = try stack.pop().?.asIntegral();
                    const b: isize = @bitCast(try stack.items[stack.items.len - 1].asIntegral());
                    stack.items[stack.items.len - 1] = .{
                        .generic = @bitCast(std.math.shr(isize, b, a)),
                    };
                    continue :op nextOpcode(expression, &i);
                },
                @intFromEnum(OP.xor) => {
                    if (stack.items.len < 2) return error.InvalidExpression;
                    const a = try stack.pop().?.asIntegral();
                    stack.items[stack.items.len - 1] = .{
                        .generic = a ^ try stack.items[stack.items.len - 1].asIntegral(),
                    };
                    continue :op nextOpcode(expression, &i);
                },

                // 2.5.1.5: Control Flow Operations
                @intFromEnum(OP.le) => {
                    try cmpOp(stack, .lte);
                    continue :op nextOpcode(expression, &i);
                },
                @intFromEnum(OP.ge) => {
                    try cmpOp(stack, .gte);
                    continue :op nextOpcode(expression, &i);
                },
                @intFromEnum(OP.eq) => {
                    try cmpOp(stack, .eq);
                    continue :op nextOpcode(expression, &i);
                },
                @intFromEnum(OP.lt) => {
                    try cmpOp(stack, .lt);
                    continue :op nextOpcode(expression, &i);
                },
                @intFromEnum(OP.gt) => {
                    try cmpOp(stack, .gt);
                    continue :op nextOpcode(expression, &i);
                },
                @intFromEnum(OP.ne) => {
                    try cmpOp(stack, .neq);
                    continue :op nextOpcode(expression, &i);
                },

                @intFromEnum(OP.skip) => {
                    const branch_offset = try nextInt(expression, &i, i16);
                    i = std.math.addAny(usize, i, branch_offset) orelse return error.InvalidExpression;
                    continue :op nextOpcode(expression, &i);
                },
                @intFromEnum(OP.bra) => {
                    const branch_offset = try nextInt(expression, &i, i16);
                    const condition = try (stack.pop() orelse return error.InvalidExpression).asIntegral();
                    if (condition != 0) {
                        i = std.math.addAny(usize, i, branch_offset) orelse return error.InvalidExpression;
                    }
                    continue :op nextOpcode(expression, &i);
                },
                @intFromEnum(OP.call2) => {
                    if (options.call_frame_context) return error.InvalidCFAOpcode;
                    const debug_info_offset = nextInt(expression, &i, u16);
                    _ = debug_info_offset;
                    // TODO: Load a DIE entry at debug_info_offset in a .debug_info section (the spec says that it
                    //       can be in a separate exe / shared object from the one containing this expression).
                    //       Transfer control to the DW_AT_location attribute, with the current stack as input.
                    return error.UnimplementedExpressionCall;
                },
                @intFromEnum(OP.call4) => {
                    if (options.call_frame_context) return error.InvalidCFAOpcode;
                    const debug_info_offset = nextInt(expression, &i, u32);
                    _ = debug_info_offset;
                    // TODO: Load a DIE entry at debug_info_offset in a .debug_info section (the spec says that it
                    //       can be in a separate exe / shared object from the one containing this expression).
                    //       Transfer control to the DW_AT_location attribute, with the current stack as input.
                    return error.UnimplementedExpressionCall;
                },
                @intFromEnum(OP.call_ref) => {
                    if (options.call_frame_context) return error.InvalidCFAOpcode;
                    const debug_info_offset: u64 = switch (context.format) {
                        .@"32" => nextInt(expression, &i, u32),
                        .@"64" => nextInt(expression, &i, u64),
                    };
                    _ = debug_info_offset;
                    // TODO: Load a DIE entry at debug_info_offset in a .debug_info section (the spec says that it
                    //       can be in a separate exe / shared object from the one containing this expression).
                    //       Transfer control to the DW_AT_location attribute, with the current stack as input.
                    return error.UnimplementedExpressionCall;
                },

                // 2.5.1.6: Type Conversions
                @intFromEnum(OP.convert) => {
                    if (options.call_frame_context) return error.InvalidCFAOpcode;

                    if (stack.items.len == 0) return error.InvalidExpression;
                    const type_offset = try nextLeb128(expression, &i, u64);

                    // TODO: Load the DW_TAG_base_type entries in context.compile_unit and verify both types are the same size
                    const value = stack.items[stack.items.len - 1];
                    if (type_offset == 0) {
                        stack.items[stack.items.len - 1] = .{ .generic = try value.asIntegral() };
                    } else {
                        // TODO: Load the DW_TAG_base_type entry in context.compile_unit, find a conversion operator
                        //       from the old type to the new type, run it.
                        return error.UnimplementedTypeConversion;
                    }
                    continue :op nextOpcode(expression, &i);
                },
                @intFromEnum(OP.reinterpret) => {
                    if (options.call_frame_context) return error.InvalidCFAOpcode;
                    if (stack.items.len == 0) return error.InvalidExpression;
                    const type_offset = try nextLeb128(expression, &i, u64);

                    // TODO: Load the DW_TAG_base_type entries in context.compile_unit and verify both types are the same size
                    const value = stack.items[stack.items.len - 1];
                    if (type_offset == 0) {
                        stack.items[stack.items.len - 1] = .{ .generic = try value.asIntegral() };
                    } else {
                        stack.items[stack.items.len - 1] = switch (value) {
                            .generic => |v| .{
                                .regval_type = .{
                                    .type_offset = type_offset,
                                    .type_size = @sizeOf(Address),
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
                    continue :op nextOpcode(expression, &i);
                },

                // 2.5.1.7: Special Operations
                @intFromEnum(OP.nop) => continue :op nextOpcode(expression, &i),
                @intFromEnum(OP.entry_value) => {
                    const block_len = try nextLeb128(expression, &i, usize);
                    if (block_len == 0) return error.InvalidSubExpression;
                    const block = try nextSlice(expression, &i, block_len);

                    // TODO: The spec states that this sub-expression needs to observe the state (ie. registers)
                    //       as it was upon entering the current subprogram. If this isn't being called at the
                    //       end of a frame unwind operation, an additional ThreadContext with this state will be needed.

                    switch (block[0]) {
                        @intFromEnum(OP.reg0)...@intFromEnum(OP.reg31) => |n| {
                            const thread_context = context.thread_context orelse
                                return error.IncompleteExpressionContext;
                            const register = n - @intFromEnum(OP.reg0);
                            const reg_bytes = try abi.regBytes(thread_context, register, context.reg_context);
                            const value = mem.readInt(usize, reg_bytes[0..@sizeOf(usize)], options.endian);
                            try stack.append(gpa, .{ .generic = value });
                            continue :op nextOpcode(expression, &i);
                        },
                        @intFromEnum(OP.regx) => {
                            const thread_context = context.thread_context orelse
                                return error.IncompleteExpressionContext;
                            const register = try nextLeb128(expression, &i, u8);
                            const reg_bytes = try abi.regBytes(thread_context, register, context.reg_context);
                            const value = mem.readInt(usize, reg_bytes[0..@sizeOf(usize)], options.endian);
                            try stack.append(gpa, .{ .generic = value });
                            continue :op nextOpcode(expression, &i);
                        },
                        else => {
                            var stack_machine: Self = .{};
                            defer stack_machine.deinit(gpa);

                            var sub_context = context;
                            sub_context.entry_value_context = true;
                            const result = try stack_machine.run(block, gpa, sub_context, null);
                            try stack.append(gpa, result orelse return error.InvalidSubExpression);
                            continue :op nextOpcode(expression, &i);
                        },
                    }
                },

                @intFromEnum(OP.lo_user)...@intFromEnum(OP.hi_user) - 1 => return error.UnimplementedUserOpcode,

                // Repurposed for exiting the loop.
                @intFromEnum(OP.hi_user) => {
                    if (stack.items.len == 0) return null;
                    return stack.items[stack.items.len - 1];
                },

                else => {
                    //std.debug.print("Unknown DWARF expression opcode: {x}\n", .{opcode});
                    return error.UnknownExpressionOpcode;
                },
            }
            comptime unreachable;
        }

        fn nextOpcode(expression: []const u8, i: *usize) u8 {
            const index = i.*;
            if (expression.len - index == 0) return @intFromEnum(OP.hi_user); // repurposed to indicate end
            i.* = index + 1;
            return expression[index];
        }

        fn nextInt(expression: []const u8, i: *usize, comptime I: type) !I {
            const n = @divExact(@bitSizeOf(I), 8);
            const slice = try nextSlice(expression, i, n);
            return mem.readInt(I, slice[0..n], options.endian);
        }

        fn nextSlice(expression: []const u8, i: *usize, len: usize) ![]const u8 {
            const index = i.*;
            if (expression.len - index < len) return error.EndOfStream;
            i.* = index + len;
            return expression[index..][0..len];
        }

        fn nextLeb128(expression: []const u8, i: *usize, comptime I: type) !I {
            var br: std.io.BufferedReader = undefined;
            br.initFixed(@constCast(expression));
            br.seek = i.*;
            assert(br.seek <= br.end);
            const result = br.takeLeb128(I) catch |err| switch (err) {
                error.ReadFailed => unreachable,
                else => |e| return e,
            };
            i.* = br.seek;
            return result;
        }

        fn accessAddress(size: u8, addr: Address, accessor: ?*std.debug.MemoryAccessor) !Address {
            if (accessor) |memory_accessor| {
                switch (size) {
                    1 => if (memory_accessor.load(u8, addr) == null) return error.InvalidExpression,
                    2 => if (memory_accessor.load(u16, addr) == null) return error.InvalidExpression,
                    4 => if (memory_accessor.load(u32, addr) == null) return error.InvalidExpression,
                    8 => if (memory_accessor.load(u64, addr) == null) return error.InvalidExpression,
                    else => return error.InvalidExpression,
                }
            }
            return switch (size) {
                1 => std.math.cast(Address, @as(*const u8, @ptrFromInt(addr)).*),
                2 => std.math.cast(Address, @as(*const u16, @ptrFromInt(addr)).*),
                4 => std.math.cast(Address, @as(*const u32, @ptrFromInt(addr)).*),
                8 => std.math.cast(Address, @as(*const u64, @ptrFromInt(addr)).*),
                else => return error.InvalidExpression,
            } orelse return error.InvalidExpression;
        }

        fn cmpOp(stack: *std.ArrayListUnmanaged(Value), op: std.math.CompareOperator) !void {
            if (stack.items.len < 2) return error.InvalidExpression;
            const a = stack.pop().?;
            const b = stack.items[stack.items.len - 1];

            const a_int = try a.asIntegral();
            const b_int = try b.asIntegral();
            stack.items[stack.items.len - 1] = .{ .generic = @intFromBool(std.math.compare(a_int, op, b_int)) };
        }
    };
}

pub fn Builder(comptime options: Options) type {
    const Address = switch (options.addr_size) {
        2 => u16,
        4 => u32,
        8 => u64,
        else => @compileError("Unsupported address size of " ++ options.addr_size),
    };

    return struct {
        /// Zero-operand instructions
        pub fn writeOpcode(writer: *std.io.BufferedWriter, comptime opcode: u8) !void {
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
        pub fn writeLiteral(writer: *std.io.BufferedWriter, literal: u8) !void {
            switch (literal) {
                0...31 => |n| try writer.writeByte(n + OP.lit0),
                else => return error.InvalidLiteral,
            }
        }

        pub fn writeConst(writer: *std.io.BufferedWriter, comptime T: type, value: T) !void {
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

        pub fn writeConstx(writer: *std.io.BufferedWriter, debug_addr_offset: anytype) !void {
            try writer.writeByte(OP.constx);
            try leb.writeUleb128(writer, debug_addr_offset);
        }

        pub fn writeConstType(writer: *std.io.BufferedWriter, die_offset: anytype, value_bytes: []const u8) !void {
            if (options.call_frame_context) return error.InvalidCFAOpcode;
            if (value_bytes.len > 0xff) return error.InvalidTypeLength;
            try writer.writeByte(OP.const_type);
            try leb.writeUleb128(writer, die_offset);
            try writer.writeByte(@intCast(value_bytes.len));
            try writer.writeAll(value_bytes);
        }

        pub fn writeAddr(writer: *std.io.BufferedWriter, value: Address) !void {
            try writer.writeByte(OP.addr);
            try writer.writeInt(Address, value, options.endian);
        }

        pub fn writeAddrx(writer: *std.io.BufferedWriter, debug_addr_offset: anytype) !void {
            if (options.call_frame_context) return error.InvalidCFAOpcode;
            try writer.writeByte(OP.addrx);
            try leb.writeUleb128(writer, debug_addr_offset);
        }

        // 2.5.1.2: Register Values
        pub fn writeFbreg(writer: *std.io.BufferedWriter, offset: anytype) !void {
            try writer.writeByte(OP.fbreg);
            try leb.writeIleb128(writer, offset);
        }

        pub fn writeBreg(writer: *std.io.BufferedWriter, register: u8, offset: anytype) !void {
            if (register > 31) return error.InvalidRegister;
            try writer.writeByte(OP.breg0 + register);
            try leb.writeIleb128(writer, offset);
        }

        pub fn writeBregx(writer: *std.io.BufferedWriter, register: anytype, offset: anytype) !void {
            try writer.writeByte(OP.bregx);
            try leb.writeUleb128(writer, register);
            try leb.writeIleb128(writer, offset);
        }

        pub fn writeRegvalType(writer: *std.io.BufferedWriter, register: anytype, offset: anytype) !void {
            if (options.call_frame_context) return error.InvalidCFAOpcode;
            try writer.writeByte(OP.regval_type);
            try leb.writeUleb128(writer, register);
            try leb.writeUleb128(writer, offset);
        }

        // 2.5.1.3: Stack Operations
        pub fn writePick(writer: *std.io.BufferedWriter, index: u8) !void {
            try writer.writeByte(OP.pick);
            try writer.writeByte(index);
        }

        pub fn writeDerefSize(writer: *std.io.BufferedWriter, size: u8) !void {
            try writer.writeByte(OP.deref_size);
            try writer.writeByte(size);
        }

        pub fn writeXDerefSize(writer: *std.io.BufferedWriter, size: u8) !void {
            try writer.writeByte(OP.xderef_size);
            try writer.writeByte(size);
        }

        pub fn writeDerefType(writer: *std.io.BufferedWriter, size: u8, die_offset: anytype) !void {
            if (options.call_frame_context) return error.InvalidCFAOpcode;
            try writer.writeByte(OP.deref_type);
            try writer.writeByte(size);
            try leb.writeUleb128(writer, die_offset);
        }

        pub fn writeXDerefType(writer: *std.io.BufferedWriter, size: u8, die_offset: anytype) !void {
            try writer.writeByte(OP.xderef_type);
            try writer.writeByte(size);
            try leb.writeUleb128(writer, die_offset);
        }

        // 2.5.1.4: Arithmetic and Logical Operations

        pub fn writePlusUconst(writer: *std.io.BufferedWriter, uint_value: anytype) !void {
            try writer.writeByte(OP.plus_uconst);
            try leb.writeUleb128(writer, uint_value);
        }

        // 2.5.1.5: Control Flow Operations

        pub fn writeSkip(writer: *std.io.BufferedWriter, offset: i16) !void {
            try writer.writeByte(OP.skip);
            try writer.writeInt(i16, offset, options.endian);
        }

        pub fn writeBra(writer: *std.io.BufferedWriter, offset: i16) !void {
            try writer.writeByte(OP.bra);
            try writer.writeInt(i16, offset, options.endian);
        }

        pub fn writeCall(writer: *std.io.BufferedWriter, comptime T: type, offset: T) !void {
            if (options.call_frame_context) return error.InvalidCFAOpcode;
            switch (T) {
                u16 => try writer.writeByte(OP.call2),
                u32 => try writer.writeByte(OP.call4),
                else => @compileError("Call operand must be a 2 or 4 byte offset"),
            }

            try writer.writeInt(T, offset, options.endian);
        }

        pub fn writeCallRef(writer: *std.io.BufferedWriter, comptime is_64: bool, value: if (is_64) u64 else u32) !void {
            if (options.call_frame_context) return error.InvalidCFAOpcode;
            try writer.writeByte(OP.call_ref);
            try writer.writeInt(if (is_64) u64 else u32, value, options.endian);
        }

        pub fn writeConvert(writer: *std.io.BufferedWriter, die_offset: anytype) !void {
            if (options.call_frame_context) return error.InvalidCFAOpcode;
            try writer.writeByte(OP.convert);
            try leb.writeUleb128(writer, die_offset);
        }

        pub fn writeReinterpret(writer: *std.io.BufferedWriter, die_offset: anytype) !void {
            if (options.call_frame_context) return error.InvalidCFAOpcode;
            try writer.writeByte(OP.reinterpret);
            try leb.writeUleb128(writer, die_offset);
        }

        // 2.5.1.7: Special Operations

        pub fn writeEntryValue(writer: *std.io.BufferedWriter, expression: []const u8) !void {
            try writer.writeByte(OP.entry_value);
            try leb.writeUleb128(writer, expression.len);
            try writer.writeAll(expression);
        }

        // 2.6: Location Descriptions
        pub fn writeReg(writer: *std.io.BufferedWriter, register: u8) !void {
            try writer.writeByte(OP.reg0 + register);
        }

        pub fn writeRegx(writer: *std.io.BufferedWriter, register: anytype) !void {
            try writer.writeByte(OP.regx);
            try leb.writeUleb128(writer, register);
        }

        pub fn writeImplicitValue(writer: *std.io.BufferedWriter, value_bytes: []const u8) !void {
            try writer.writeByte(OP.implicit_value);
            try leb.writeUleb128(writer, value_bytes.len);
            try writer.writeAll(value_bytes);
        }
    };
}

/// Certain opcodes are not allowed in a CFA context, see 6.4.2
fn isOpcodeValidInCFA(opcode: OP) bool {
    return switch (opcode) {
        .addrx,
        .call2,
        .call4,
        .call_ref,
        .const_type,
        .constx,
        .convert,
        .deref_type,
        .regval_type,
        .reinterpret,
        .push_object_address,
        .call_frame_cfa,
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
            try testing.expectEqual(expected, stack_machine.stack.pop().?.generic);
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

        const const_type = stack_machine.stack.pop().?.const_type;
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
            try testing.expectEqual(@as(e[0], e[1]), @as(e[2], @bitCast(stack_machine.stack.pop().?.generic)));
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

            const regval_type = stack_machine.stack.pop().?.regval_type;
            try testing.expectEqual(@as(usize, 400), regval_type.type_offset);
            try testing.expectEqual(@as(u8, @sizeOf(usize)), regval_type.type_size);
            try testing.expectEqual(@as(usize, 0xee), regval_type.value);

            try testing.expectEqual(@as(usize, 303), stack_machine.stack.pop().?.generic);
            try testing.expectEqual(@as(usize, 202), stack_machine.stack.pop().?.generic);
            try testing.expectEqual(@as(usize, 101), stack_machine.stack.pop().?.generic);
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
        try testing.expectEqual(@as(usize, 1), stack_machine.stack.pop().?.generic);
        try testing.expectEqual(@as(usize, 1), stack_machine.stack.pop().?.generic);

        stack_machine.reset();
        program.clearRetainingCapacity();
        try b.writeConst(writer, u8, 1);
        try b.writeOpcode(writer, OP.drop);
        _ = try stack_machine.run(program.items, allocator, context, null);
        try testing.expect(stack_machine.stack.pop() == null);

        stack_machine.reset();
        program.clearRetainingCapacity();
        try b.writeConst(writer, u8, 4);
        try b.writeConst(writer, u8, 5);
        try b.writeConst(writer, u8, 6);
        try b.writePick(writer, 2);
        _ = try stack_machine.run(program.items, allocator, context, null);
        try testing.expectEqual(@as(usize, 4), stack_machine.stack.pop().?.generic);

        stack_machine.reset();
        program.clearRetainingCapacity();
        try b.writeConst(writer, u8, 4);
        try b.writeConst(writer, u8, 5);
        try b.writeConst(writer, u8, 6);
        try b.writeOpcode(writer, OP.over);
        _ = try stack_machine.run(program.items, allocator, context, null);
        try testing.expectEqual(@as(usize, 5), stack_machine.stack.pop().?.generic);

        stack_machine.reset();
        program.clearRetainingCapacity();
        try b.writeConst(writer, u8, 5);
        try b.writeConst(writer, u8, 6);
        try b.writeOpcode(writer, OP.swap);
        _ = try stack_machine.run(program.items, allocator, context, null);
        try testing.expectEqual(@as(usize, 5), stack_machine.stack.pop().?.generic);
        try testing.expectEqual(@as(usize, 6), stack_machine.stack.pop().?.generic);

        stack_machine.reset();
        program.clearRetainingCapacity();
        try b.writeConst(writer, u8, 4);
        try b.writeConst(writer, u8, 5);
        try b.writeConst(writer, u8, 6);
        try b.writeOpcode(writer, OP.rot);
        _ = try stack_machine.run(program.items, allocator, context, null);
        try testing.expectEqual(@as(usize, 5), stack_machine.stack.pop().?.generic);
        try testing.expectEqual(@as(usize, 4), stack_machine.stack.pop().?.generic);
        try testing.expectEqual(@as(usize, 6), stack_machine.stack.pop().?.generic);

        const deref_target: usize = @truncate(0xffeeffee_ffeeffee);

        stack_machine.reset();
        program.clearRetainingCapacity();
        try b.writeAddr(writer, @intFromPtr(&deref_target));
        try b.writeOpcode(writer, OP.deref);
        _ = try stack_machine.run(program.items, allocator, context, null);
        try testing.expectEqual(deref_target, stack_machine.stack.pop().?.generic);

        stack_machine.reset();
        program.clearRetainingCapacity();
        try b.writeLiteral(writer, 0);
        try b.writeAddr(writer, @intFromPtr(&deref_target));
        try b.writeOpcode(writer, OP.xderef);
        _ = try stack_machine.run(program.items, allocator, context, null);
        try testing.expectEqual(deref_target, stack_machine.stack.pop().?.generic);

        stack_machine.reset();
        program.clearRetainingCapacity();
        try b.writeAddr(writer, @intFromPtr(&deref_target));
        try b.writeDerefSize(writer, 1);
        _ = try stack_machine.run(program.items, allocator, context, null);
        try testing.expectEqual(@as(usize, @as(*const u8, @ptrCast(&deref_target)).*), stack_machine.stack.pop().?.generic);

        stack_machine.reset();
        program.clearRetainingCapacity();
        try b.writeLiteral(writer, 0);
        try b.writeAddr(writer, @intFromPtr(&deref_target));
        try b.writeXDerefSize(writer, 1);
        _ = try stack_machine.run(program.items, allocator, context, null);
        try testing.expectEqual(@as(usize, @as(*const u8, @ptrCast(&deref_target)).*), stack_machine.stack.pop().?.generic);

        const type_offset: usize = @truncate(0xaabbaabb_aabbaabb);

        stack_machine.reset();
        program.clearRetainingCapacity();
        try b.writeAddr(writer, @intFromPtr(&deref_target));
        try b.writeDerefType(writer, 1, type_offset);
        _ = try stack_machine.run(program.items, allocator, context, null);
        const deref_type = stack_machine.stack.pop().?.regval_type;
        try testing.expectEqual(type_offset, deref_type.type_offset);
        try testing.expectEqual(@as(u8, 1), deref_type.type_size);
        try testing.expectEqual(@as(usize, @as(*const u8, @ptrCast(&deref_target)).*), deref_type.value);

        stack_machine.reset();
        program.clearRetainingCapacity();
        try b.writeLiteral(writer, 0);
        try b.writeAddr(writer, @intFromPtr(&deref_target));
        try b.writeXDerefType(writer, 1, type_offset);
        _ = try stack_machine.run(program.items, allocator, context, null);
        const xderef_type = stack_machine.stack.pop().?.regval_type;
        try testing.expectEqual(type_offset, xderef_type.type_offset);
        try testing.expectEqual(@as(u8, 1), xderef_type.type_size);
        try testing.expectEqual(@as(usize, @as(*const u8, @ptrCast(&deref_target)).*), xderef_type.value);

        context.object_address = &deref_target;

        stack_machine.reset();
        program.clearRetainingCapacity();
        try b.writeOpcode(writer, OP.push_object_address);
        _ = try stack_machine.run(program.items, allocator, context, null);
        try testing.expectEqual(@as(usize, @intFromPtr(context.object_address.?)), stack_machine.stack.pop().?.generic);

        // TODO: Test OP.form_tls_address

        context.cfa = @truncate(0xccddccdd_ccddccdd);

        stack_machine.reset();
        program.clearRetainingCapacity();
        try b.writeOpcode(writer, OP.call_frame_cfa);
        _ = try stack_machine.run(program.items, allocator, context, null);
        try testing.expectEqual(context.cfa.?, stack_machine.stack.pop().?.generic);
    }

    // Arithmetic and Logical Operations
    {
        const context = Context{};

        stack_machine.reset();
        program.clearRetainingCapacity();
        try b.writeConst(writer, i16, -4096);
        try b.writeOpcode(writer, OP.abs);
        _ = try stack_machine.run(program.items, allocator, context, null);
        try testing.expectEqual(@as(usize, 4096), stack_machine.stack.pop().?.generic);

        stack_machine.reset();
        program.clearRetainingCapacity();
        try b.writeConst(writer, u16, 0xff0f);
        try b.writeConst(writer, u16, 0xf0ff);
        try b.writeOpcode(writer, OP.@"and");
        _ = try stack_machine.run(program.items, allocator, context, null);
        try testing.expectEqual(@as(usize, 0xf00f), stack_machine.stack.pop().?.generic);

        stack_machine.reset();
        program.clearRetainingCapacity();
        try b.writeConst(writer, i16, -404);
        try b.writeConst(writer, i16, 100);
        try b.writeOpcode(writer, OP.div);
        _ = try stack_machine.run(program.items, allocator, context, null);
        try testing.expectEqual(@as(isize, -404 / 100), @as(isize, @bitCast(stack_machine.stack.pop().?.generic)));

        stack_machine.reset();
        program.clearRetainingCapacity();
        try b.writeConst(writer, u16, 200);
        try b.writeConst(writer, u16, 50);
        try b.writeOpcode(writer, OP.minus);
        _ = try stack_machine.run(program.items, allocator, context, null);
        try testing.expectEqual(@as(usize, 150), stack_machine.stack.pop().?.generic);

        stack_machine.reset();
        program.clearRetainingCapacity();
        try b.writeConst(writer, u16, 123);
        try b.writeConst(writer, u16, 100);
        try b.writeOpcode(writer, OP.mod);
        _ = try stack_machine.run(program.items, allocator, context, null);
        try testing.expectEqual(@as(usize, 23), stack_machine.stack.pop().?.generic);

        stack_machine.reset();
        program.clearRetainingCapacity();
        try b.writeConst(writer, u16, 0xff);
        try b.writeConst(writer, u16, 0xee);
        try b.writeOpcode(writer, OP.mul);
        _ = try stack_machine.run(program.items, allocator, context, null);
        try testing.expectEqual(@as(usize, 0xed12), stack_machine.stack.pop().?.generic);

        stack_machine.reset();
        program.clearRetainingCapacity();
        try b.writeConst(writer, u16, 5);
        try b.writeOpcode(writer, OP.neg);
        try b.writeConst(writer, i16, -6);
        try b.writeOpcode(writer, OP.neg);
        _ = try stack_machine.run(program.items, allocator, context, null);
        try testing.expectEqual(@as(usize, 6), stack_machine.stack.pop().?.generic);
        try testing.expectEqual(@as(isize, -5), @as(isize, @bitCast(stack_machine.stack.pop().?.generic)));

        stack_machine.reset();
        program.clearRetainingCapacity();
        try b.writeConst(writer, u16, 0xff0f);
        try b.writeOpcode(writer, OP.not);
        _ = try stack_machine.run(program.items, allocator, context, null);
        try testing.expectEqual(~@as(usize, 0xff0f), stack_machine.stack.pop().?.generic);

        stack_machine.reset();
        program.clearRetainingCapacity();
        try b.writeConst(writer, u16, 0xff0f);
        try b.writeConst(writer, u16, 0xf0ff);
        try b.writeOpcode(writer, OP.@"or");
        _ = try stack_machine.run(program.items, allocator, context, null);
        try testing.expectEqual(@as(usize, 0xffff), stack_machine.stack.pop().?.generic);

        stack_machine.reset();
        program.clearRetainingCapacity();
        try b.writeConst(writer, i16, 402);
        try b.writeConst(writer, i16, 100);
        try b.writeOpcode(writer, OP.plus);
        _ = try stack_machine.run(program.items, allocator, context, null);
        try testing.expectEqual(@as(usize, 502), stack_machine.stack.pop().?.generic);

        stack_machine.reset();
        program.clearRetainingCapacity();
        try b.writeConst(writer, u16, 4096);
        try b.writePlusUconst(writer, @as(usize, 8192));
        _ = try stack_machine.run(program.items, allocator, context, null);
        try testing.expectEqual(@as(usize, 4096 + 8192), stack_machine.stack.pop().?.generic);

        stack_machine.reset();
        program.clearRetainingCapacity();
        try b.writeConst(writer, u16, 0xfff);
        try b.writeConst(writer, u16, 1);
        try b.writeOpcode(writer, OP.shl);
        _ = try stack_machine.run(program.items, allocator, context, null);
        try testing.expectEqual(@as(usize, 0xfff << 1), stack_machine.stack.pop().?.generic);

        stack_machine.reset();
        program.clearRetainingCapacity();
        try b.writeConst(writer, u16, 0xfff);
        try b.writeConst(writer, u16, 1);
        try b.writeOpcode(writer, OP.shr);
        _ = try stack_machine.run(program.items, allocator, context, null);
        try testing.expectEqual(@as(usize, 0xfff >> 1), stack_machine.stack.pop().?.generic);

        stack_machine.reset();
        program.clearRetainingCapacity();
        try b.writeConst(writer, u16, 0xfff);
        try b.writeConst(writer, u16, 1);
        try b.writeOpcode(writer, OP.shr);
        _ = try stack_machine.run(program.items, allocator, context, null);
        try testing.expectEqual(@as(usize, @bitCast(@as(isize, 0xfff) >> 1)), stack_machine.stack.pop().?.generic);

        stack_machine.reset();
        program.clearRetainingCapacity();
        try b.writeConst(writer, u16, 0xf0ff);
        try b.writeConst(writer, u16, 0xff0f);
        try b.writeOpcode(writer, OP.xor);
        _ = try stack_machine.run(program.items, allocator, context, null);
        try testing.expectEqual(@as(usize, 0x0ff0), stack_machine.stack.pop().?.generic);
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
            try testing.expectEqual(@as(usize, e[3]), stack_machine.stack.pop().?.generic);
            try testing.expectEqual(@as(usize, e[2]), stack_machine.stack.pop().?.generic);
            try testing.expectEqual(@as(usize, e[1]), stack_machine.stack.pop().?.generic);
        }

        stack_machine.reset();
        program.clearRetainingCapacity();
        try b.writeLiteral(writer, 2);
        try b.writeSkip(writer, 1);
        try b.writeLiteral(writer, 3);
        _ = try stack_machine.run(program.items, allocator, context, null);
        try testing.expectEqual(@as(usize, 2), stack_machine.stack.pop().?.generic);

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
        try testing.expectEqual(@as(usize, 5), stack_machine.stack.pop().?.generic);
        try testing.expectEqual(@as(usize, 4), stack_machine.stack.pop().?.generic);
        try testing.expect(stack_machine.stack.pop() == null);

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
        try testing.expectEqual(value, stack_machine.stack.pop().?.generic);

        // Reinterpret to generic type
        stack_machine.reset();
        program.clearRetainingCapacity();
        try b.writeConstType(writer, @as(usize, 0), &value_bytes);
        try b.writeReinterpret(writer, @as(usize, 0));
        _ = try stack_machine.run(program.items, allocator, context, null);
        try testing.expectEqual(value, stack_machine.stack.pop().?.generic);

        // Reinterpret to new type
        const die_offset: usize = 0xffee;

        stack_machine.reset();
        program.clearRetainingCapacity();
        try b.writeConstType(writer, @as(usize, 0), &value_bytes);
        try b.writeReinterpret(writer, die_offset);
        _ = try stack_machine.run(program.items, allocator, context, null);
        const const_type = stack_machine.stack.pop().?.const_type;
        try testing.expectEqual(die_offset, const_type.type_offset);

        stack_machine.reset();
        program.clearRetainingCapacity();
        try b.writeLiteral(writer, 0);
        try b.writeReinterpret(writer, die_offset);
        _ = try stack_machine.run(program.items, allocator, context, null);
        const regval_type = stack_machine.stack.pop().?.regval_type;
        try testing.expectEqual(die_offset, regval_type.type_offset);
    }

    // Special operations
    {
        var context = Context{};

        stack_machine.reset();
        program.clearRetainingCapacity();
        try b.writeOpcode(writer, OP.nop);
        _ = try stack_machine.run(program.items, allocator, context, null);
        try testing.expect(stack_machine.stack.pop() == null);

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
            try testing.expectEqual(@as(usize, 3), stack_machine.stack.pop().?.generic);
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
            try testing.expectEqual(@as(usize, 0xee), stack_machine.stack.pop().?.generic);
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
