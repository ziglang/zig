//! Machine Intermediate Representation.
//! This representation is produced by wasm Codegen.
//! Each of these instructions have a 1:1 mapping to a wasm opcode,
//! but may contain metadata for a specific opcode such as an immediate.
//! MIR can be lowered to both textual code (wat) and binary format (wasm).
//! The main benefits of MIR is optimization passes, pre-allocated locals,
//! and known jump labels for blocks.

const Mir = @This();

const std = @import("std");

/// A struct of array that represents each individual wasm 
instructions: std.MultiArrayList(Inst).Slice,
/// A slice of indexes where the meaning of the data is determined by the
/// `Inst.Tag` value.
extra: []const u32,

pub const Inst = struct {
    /// The opcode that represents this instruction
    tag: Tag,
    /// Data is determined by the set `tag`.
    /// For example, `data` will be an i32 for when `tag` is 'i32_const'.
    data: Data,

    /// The position of a given MIR isntruction with the instruction list.
    pub const Index = u32;

    /// Contains all possible wasm opcodes the Zig compiler may emit
    /// Rather than re-using std.wasm.Opcode, we only declare the opcodes
    /// we need, and also use this possibility to document how to access
    /// their payload.
    ///
    /// Note: Uses its actual opcode value representation to easily convert
    /// to and from its binary representation.
    pub const Tag = enum(u8) {
        /// Uses `nop`
        @"unreachable" = 0x00,
        /// Creates a new block that can be jump from.
        ///
        /// Type of the block is given in data `block_type`
        block = 0x02,
        /// Creates a new loop.
        ///
        /// Type of the loop is given in data `block_type`
        loop = 0x03,
        /// Represents the end of a function body or an initialization expression
        ///
        /// Payload is `nop`
        end = 0x0B,
        /// Breaks from the current block to a label
        ///
        /// Data is `label` where index represents the label to jump to
        br = 0x0C,
        /// Breaks from the current block if the stack value is non-zero
        ///
        /// Data is `label` where index represents the label to jump to
        br_if = 0x0D,
        /// Jump table that takes the stack value as an index where each value
        /// represents the label to jump to.
        ///
        /// Data is extra of which the Payload's type is `JumpTable`
        br_table = 0x0E,
        /// Returns from the function
        ///
        /// Uses `nop`
        @"return" = 0x0F,
        /// Calls a function by its index
        ///
        /// Uses `label`
        call = 0x10,
        /// Calls a function pointer by its function signature
        /// and index into the function table.
        ///
        /// Uses `label`
        call_indirect = 0x11,
        /// Loads a local at given index onto the stack.
        ///
        /// Uses `label`
        local_get = 0x20,
        /// Pops a value from the stack into the local at given index.
        /// Stack value must be of the same type as the local.
        ///
        /// Uses `label`
        local_set = 0x21,
        /// Sets a local at given index using the value at the top of the stack without popping the value.
        /// Stack value must have the same type as the local.
        ///
        /// Uses `label`
        local_tee = 0x22,
        /// Loads a (mutable) global at given index onto the stack
        ///
        /// Uses `label`
        global_get = 0x23,
        /// Pops a value from the stack and sets the global at given index.
        /// Note: Both types must be equal and global must be marked mutable.
        ///
        /// Uses `label`.
        global_set = 0x24,
        /// Loads a 32-bit integer from memory (data section) onto the stack
        /// Pops the value from the stack which represents the offset into memory.
        ///
        /// Uses `payload` of type `MemArg`.
        i32_load = 0x28,
        /// Loads a value from memory onto the stack, based on the signedness
        /// and bitsize of the type.
        ///
        /// Uses `payload` with type `MemArg`
        i64_load = 0x29,
        /// Loads a value from memory onto the stack, based on the signedness
        /// and bitsize of the type.
        ///
        /// Uses `payload` with type `MemArg`
        f32_load = 0x2A,
        /// Loads a value from memory onto the stack, based on the signedness
        /// and bitsize of the type.
        ///
        /// Uses `payload` with type `MemArg`
        f64_load = 0x2B,
        /// Loads a value from memory onto the stack, based on the signedness
        /// and bitsize of the type.
        ///
        /// Uses `payload` with type `MemArg`
        i32_load8_s = 0x2C,
        /// Loads a value from memory onto the stack, based on the signedness
        /// and bitsize of the type.
        ///
        /// Uses `payload` with type `MemArg`
        i32_load8_u = 0x2D,
        /// Loads a value from memory onto the stack, based on the signedness
        /// and bitsize of the type.
        ///
        /// Uses `payload` with type `MemArg`
        i32_load16_s = 0x2E,
        /// Loads a value from memory onto the stack, based on the signedness
        /// and bitsize of the type.
        ///
        /// Uses `payload` with type `MemArg`
        i32_load16_u = 0x2F,
        /// Loads a value from memory onto the stack, based on the signedness
        /// and bitsize of the type.
        ///
        /// Uses `payload` with type `MemArg`
        i64_load8_s = 0x30,
        /// Loads a value from memory onto the stack, based on the signedness
        /// and bitsize of the type.
        ///
        /// Uses `payload` with type `MemArg`
        i64_load8_u = 0x31,
        /// Loads a value from memory onto the stack, based on the signedness
        /// and bitsize of the type.
        ///
        /// Uses `payload` with type `MemArg`
        i64_load16_s = 0x32,
        /// Loads a value from memory onto the stack, based on the signedness
        /// and bitsize of the type.
        ///
        /// Uses `payload` with type `MemArg`
        i64_load16_u = 0x33,
        /// Loads a value from memory onto the stack, based on the signedness
        /// and bitsize of the type.
        ///
        /// Uses `payload` with type `MemArg`
        i64_load32_s = 0x34,
        /// Loads a value from memory onto the stack, based on the signedness
        /// and bitsize of the type.
        ///
        /// Uses `payload` with type `MemArg`
        i64_load32_u = 0x35,
        /// Pops 2 values from the stack, where the first value represents the value to write into memory
        /// and the second value represents the offset into memory where the value must be written to.
        /// This opcode is typed and expects the stack value's type to be equal to this opcode's type.
        ///
        /// Uses `payload` of type `MemArg`.
        i32_store = 0x36,
        /// Pops 2 values from the stack, where the first value represents the value to write into memory
        /// and the second value represents the offset into memory where the value must be written to.
        /// This opcode is typed and expects the stack value's type to be equal to this opcode's type.
        ///
        /// Uses `Payload` with type `MemArg`
        i64_store = 0x37,
        /// Pops 2 values from the stack, where the first value represents the value to write into memory
        /// and the second value represents the offset into memory where the value must be written to.
        /// This opcode is typed and expects the stack value's type to be equal to this opcode's type.
        ///
        /// Uses `Payload` with type `MemArg`
        f32_store = 0x38,
        /// Pops 2 values from the stack, where the first value represents the value to write into memory
        /// and the second value represents the offset into memory where the value must be written to.
        /// This opcode is typed and expects the stack value's type to be equal to this opcode's type.
        ///
        /// Uses `Payload` with type `MemArg`
        f64_store = 0x39,
        /// Pops 2 values from the stack, where the first value represents the value to write into memory
        /// and the second value represents the offset into memory where the value must be written to.
        /// This opcode is typed and expects the stack value's type to be equal to this opcode's type.
        ///
        /// Uses `Payload` with type `MemArg`
        i32_store8 = 0x3A,
        /// Pops 2 values from the stack, where the first value represents the value to write into memory
        /// and the second value represents the offset into memory where the value must be written to.
        /// This opcode is typed and expects the stack value's type to be equal to this opcode's type.
        ///
        /// Uses `Payload` with type `MemArg`
        i32_store16 = 0x3B,
        /// Pops 2 values from the stack, where the first value represents the value to write into memory
        /// and the second value represents the offset into memory where the value must be written to.
        /// This opcode is typed and expects the stack value's type to be equal to this opcode's type.
        ///
        /// Uses `Payload` with type `MemArg`
        i64_store8 = 0x3C,
        /// Pops 2 values from the stack, where the first value represents the value to write into memory
        /// and the second value represents the offset into memory where the value must be written to.
        /// This opcode is typed and expects the stack value's type to be equal to this opcode's type.
        ///
        /// Uses `Payload` with type `MemArg`
        i64_store16 = 0x3D,
        /// Pops 2 values from the stack, where the first value represents the value to write into memory
        /// and the second value represents the offset into memory where the value must be written to.
        /// This opcode is typed and expects the stack value's type to be equal to this opcode's type.
        ///
        /// Uses `Payload` with type `MemArg`
        i64_store32 = 0x3E,
        /// Returns the memory size in amount of pages.
        ///
        /// Uses `nop`
        memory_size = 0x3F,
        /// Increases the memory at by given number of pages.
        ///
        /// Uses `label`
        memory_grow = 0x40,
        /// Loads a 32-bit signed immediate value onto the stack
        ///
        /// Uses `imm32`
        i32_const = 0x41,
        /// Loads a i64-bit signed immediate value onto the stack
        ///
        /// uses `payload` of type `Imm64`
        i64_const = 0x42,
        /// Loads a 32-bit float value onto the stack.
        ///
        /// Uses `float32`
        f32_const = 0x43,
        /// Loads a 64-bit float value onto the stack.
        ///
        /// Uses `payload` of type `Float64`
        f64_const = 0x44,
        /// Uses `tag`
        i32_eqz = 0x45,
        /// Uses `tag`
        i32_eq = 0x46,
        /// Uses `tag`
        i32_ne = 0x47,
        /// Uses `tag`
        i32_lt_s = 0x48,
        /// Uses `tag`
        i32_lt_u = 0x49,
        /// Uses `tag`
        i32_gt_s = 0x4A,
        /// Uses `tag`
        i32_gt_u = 0x4B,
        /// Uses `tag`
        i32_le_s = 0x4C,
        /// Uses `tag`
        i32_le_u = 0x4D,
        /// Uses `tag`
        i32_ge_s = 0x4E,
        /// Uses `tag`
        i32_ge_u = 0x4F,
        /// Uses `tag`
        i64_eqz = 0x50,
        /// Uses `tag`
        i64_eq = 0x51,
        /// Uses `tag`
        i64_ne = 0x52,
        /// Uses `tag`
        i64_lt_s = 0x53,
        /// Uses `tag`
        i64_lt_u = 0x54,
        /// Uses `tag`
        i64_gt_s = 0x55,
        /// Uses `tag`
        i64_gt_u = 0x56,
        /// Uses `tag`
        i64_le_s = 0x57,
        /// Uses `tag`
        i64_le_u = 0x58,
        /// Uses `tag`
        i64_ge_s = 0x59,
        /// Uses `tag`
        i64_ge_u = 0x5A,
        /// Uses `tag`
        f32_eq = 0x5B,
        /// Uses `tag`
        f32_ne = 0x5C,
        /// Uses `tag`
        f32_lt = 0x5D,
        /// Uses `tag`
        f32_gt = 0x5E,
        /// Uses `tag`
        f32_le = 0x5F,
        /// Uses `tag`
        f32_ge = 0x60,
        /// Uses `tag`
        f64_eq = 0x61,
        /// Uses `tag`
        f64_ne = 0x62,
        /// Uses `tag`
        f64_lt = 0x63,
        /// Uses `tag`
        f64_gt = 0x64,
        /// Uses `tag`
        f64_le = 0x65,
        /// Uses `tag`
        f64_ge = 0x66,
        /// Uses `tag`
        i32_add = 0x6A,
        /// Uses `tag`
        i32_sub = 0x6B,
        /// Uses `tag`
        i32_mul = 0x6C,
        /// Uses `tag`
        i32_div_s = 0x6D,
        /// Uses `tag`
        i32_div_u = 0x6E,
        /// Uses `tag`
        i32_and = 0x71,
        /// Uses `tag`
        i32_or = 0x72,
        /// Uses `tag`
        i32_xor = 0x73,
        /// Uses `tag`
        i32_shl = 0x74,
        /// Uses `tag`
        i32_shr_s = 0x75,
        /// Uses `tag`
        i32_shr_u = 0x76,
        /// Uses `tag`
        i64_add = 0x7C,
        /// Uses `tag`
        i64_sub = 0x7D,
        /// Uses `tag`
        i64_mul = 0x7E,
        /// Uses `tag`
        i64_div_s = 0x7F,
        /// Uses `tag`
        i64_div_u = 0x80,
        /// Uses `tag`
        i64_and = 0x83,
        /// Uses `tag`
        i64_or = 0x84,
        /// Uses `tag`
        i64_xor = 0x85,
        /// Uses `tag`
        i64_shl = 0x86,
        /// Uses `tag`
        i64_shr_s = 0x87,
        /// Uses `tag`
        i64_shr_u = 0x88,
        /// Uses `tag`
        i32_wrap_i64 = 0xA7,
        /// Uses `tag`
        i64_extend_i32_s = 0xAC,
        /// Uses `tag`
        i64_extend_i32_u = 0xAD,
        /// Uses `tag`
        i32_extend8_s = 0xC0,
        /// Uses `tag`
        i32_extend16_s = 0xC1,
        /// Uses `tag`
        i64_extend8_s = 0xC2,
        /// Uses `tag`
        i64_extend16_s = 0xC3,
        /// Uses `tag`
        i64_extend32_s = 0xC4,
        /// Contains a symbol to a function pointer
        /// uses `label`
        ///
        /// Note: This uses `0xFE` as value as it is unused and not reserved
        /// by the wasm specification, making it safe to use.
        function_index = 0xFE,
        /// Contains a symbol to a memory address
        /// Uses `label`
        ///
        /// Note: This uses `0xFF` as value as it is unused and not reserved
        /// by the wasm specification, making it safe to use.
        memory_address = 0xFF,

        /// From a given wasm opcode, returns a MIR tag.
        pub fn fromOpcode(opcode: std.wasm.Opcode) Tag {
            return @intToEnum(Tag, @enumToInt(opcode)); // Given `Opcode` is not present as a tag for MIR yet
        }

        /// Returns a wasm opcode from a given MIR tag.
        pub fn toOpcode(self: Tag) std.wasm.Opcode {
            return @intToEnum(std.wasm.Opcode, @enumToInt(self));
        }
    };

    /// All instructions contain a 4-byte payload, which is contained within
    /// this union. `Tag` determines which union tag is active, as well as
    /// how to interpret the data within.
    pub const Data = union {
        /// Uses no additional data
        tag: void,
        /// Contains the result type of a block
        ///
        /// Used by `block` and `loop`
        block_type: u8,
        /// Contains an u32 index into a wasm section entry, such as a local.
        /// Note: This is not an index to another instruction.
        ///
        /// Used by e.g. `local_get`, `local_set`, etc. 
        label: u32,
        /// A 32-bit immediate value.
        ///
        /// Used by `i32_const`
        imm32: i32,
        /// A 32-bit float value
        ///
        /// Used by `f32_float`
        float32: f32,
        /// Index into `extra`. Meaning of what can be found there is context-dependent.
        ///
        /// Used by e.g. `br_table`
        payload: u32,
    };
};

pub fn deinit(self: *Mir, gpa: std.mem.Allocator) void {
    self.instructions.deinit(gpa);
    gpa.free(self.extra);
    self.* = undefined;
}

pub fn extraData(self: Mir, comptime T: type, index: usize) struct { data: T, end: usize } {
    const fields = std.meta.fields(T);
    var i: usize = index;
    var result: T = undefined;
    inline for (fields) |field| {
        @field(result, field.name) = switch (field.field_type) {
            u32 => self.extra[i],
            else => |field_type| @compileError("Unsupported field type " ++ @typeName(field_type)),
        };
        i += 1;
    }

    return .{ .data = result, .end = i };
}

pub const JumpTable = struct {
    /// Length of the jump table and the amount of entries it contains (includes default)
    length: u32,
};

/// Stores an unsigned 64bit integer
/// into a 32bit most significant bits field
/// and a 32bit least significant bits field.
///
/// This uses an unsigned integer rather than a signed integer
/// as we can easily store those into `extra`
pub const Imm64 = struct {
    msb: u32,
    lsb: u32,

    pub fn fromU64(imm: u64) Imm64 {
        return .{
            .msb = @truncate(u32, imm >> 32),
            .lsb = @truncate(u32, imm),
        };
    }

    pub fn toU64(self: Imm64) u64 {
        var result: u64 = 0;
        result |= @as(u64, self.msb) << 32;
        result |= @as(u64, self.lsb);
        return result;
    }
};

pub const Float64 = struct {
    msb: u32,
    lsb: u32,

    pub fn fromFloat64(float: f64) Float64 {
        const tmp = @bitCast(u64, float);
        return .{
            .msb = @truncate(u32, tmp >> 32),
            .lsb = @truncate(u32, tmp),
        };
    }

    pub fn toF64(self: Float64) f64 {
        @bitCast(f64, self.toU64());
    }

    pub fn toU64(self: Float64) u64 {
        var result: u64 = 0;
        result |= @as(u64, self.msb) << 32;
        result |= @as(u64, self.lsb);
        return result;
    }
};

pub const MemArg = struct {
    offset: u32,
    alignment: u32,
};
