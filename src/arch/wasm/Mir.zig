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
        /// Uses `mem_arg`.
        i32_load = 0x28,
        /// Pops 2 values from the stack, where the first value represents the value to write into memory
        /// and the second value represents the offset into memory where the value must be written to.
        ///
        /// Uses `mem_arg`.
        i32_store = 0x36,
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
        /// Uses `imm64`
        i64_const = 0x42,
        /// Loads a 32-bit float value onto the stack.
        ///
        /// Uses `float32`
        f32_const = 0x43,
        /// Loads a 64-bit float value onto the stack.
        ///
        /// Uses `float64`
        f64_const = 0x44,

        /// From a given wasm opcode, returns a MIR tag.
        pub fn fromOpcode(opcode: std.wasm.Opcode) Tag {
            return @intToEnum(Tag, @enumToInt(opcode));
        }

        /// Returns a wasm opcode from a given MIR tag.
        pub fn toOpcode(self: Tag) std.wasm.Opcode {
            return @intToEnum(std.wasm.Opcode, @enumToInt(self));
        }
    };

    /// All instructions contain a 4-byte payload, which is contained within
    /// this union. `Opcode` determines which union tag is active, as well as
    /// how to interpret the data within.
    pub const Data = union {
        /// Uses no additional data
        no_op: void,
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
        /// A 64-bit immediate value.
        ///
        /// Used by `i64_const`
        imm64: i64,
        /// A 32-bit float value
        ///
        /// Used by `f32_float`
        float32: f32,
        /// A 64-bit float value
        ///
        /// Used by `f64_float`
        float64: f64,
        /// Index into `extra`. Meaning of what can be found there is context-dependent.
        ///
        /// Used by e.g. `br_table`
        payload: u32,
        /// Memory arguments to store or load data between the stack and memory section.
        ///
        /// Used by e.g. `i32_store`, `i32_load`
        mem_arg: struct {
            alignment: u32,
            offset: u32,
        },
    };
};

pub fn deinit(self: *Mir, gpa: *std.mem.Allocator) void {
    self.instructions.deinit(gpa);
    gpa.free(self.extra);
    self.* = undefined;
}

pub const JumpTable = struct {
    /// Length of the jump table and the amount of entries it contains
    length: u32,
};

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
