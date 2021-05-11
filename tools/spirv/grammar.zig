//! See https://www.khronos.org/registry/spir-v/specs/unified1/MachineReadableGrammar.html
//! and the files in https://github.com/KhronosGroup/SPIRV-Headers/blob/master/include/spirv/unified1/
//! Note: Non-canonical casing in these structs used to match SPIR-V spec json.
pub const Registry = union(enum) {
    core: CoreRegistry,
    extension: ExtensionRegistry,
};

pub const CoreRegistry = struct {
    copyright: [][]const u8,
    /// Hexadecimal representation of the magic number
    magic_number: []const u8,
    major_version: u32,
    minor_version: u32,
    revision: u32,
    instruction_printing_class: []InstructionPrintingClass,
    instructions: []Instruction,
    operand_kinds: []OperandKind,
};

pub const ExtensionRegistry = struct {
    copyright: [][]const u8,
    version: u32,
    revision: u32,
    instructions: []Instruction,
    operand_kinds: []OperandKind = &[_]OperandKind{},
};

pub const InstructionPrintingClass = struct {
    tag: []const u8,
    heading: ?[]const u8 = null,
};

pub const Instruction = struct {
    opname: []const u8,
    class: ?[]const u8 = null, // Note: Only available in the core registry.
    opcode: u32,
    operands: []Operand = &[_]Operand{},
    capabilities: [][]const u8 = &[_][]const u8{},
    extensions: [][]const u8 = &[_][]const u8{},
    version: ?[]const u8 = null,

    lastVersion: ?[]const u8 = null,
};

pub const Operand = struct {
    kind: []const u8,
    /// If this field is 'null', the operand is only expected once.
    quantifier: ?Quantifier = null,
    name: []const u8 = "",
};

pub const Quantifier = enum {
    /// zero or once
    @"?",
    /// zero or more
    @"*",
};

pub const OperandCategory = enum {
    BitEnum,
    ValueEnum,
    Id,
    Literal,
    Composite,
};

pub const OperandKind = struct {
    category: OperandCategory,
    /// The name
    kind: []const u8,
    doc: ?[]const u8 = null,
    enumerants: ?[]Enumerant = null,
    bases: ?[]const []const u8 = null,
};

pub const Enumerant = struct {
    enumerant: []const u8,
    value: union(enum) {
        bitflag: []const u8, // Hexadecimal representation of the value
        int: u31,
    },
    capabilities: [][]const u8 = &[_][]const u8{},
    /// Valid for .ValueEnum and .BitEnum
    extensions: [][]const u8 = &[_][]const u8{},
    /// `quantifier` will always be `null`.
    parameters: []Operand = &[_]Operand{},
    version: ?[]const u8 = null,
    lastVersion: ?[]const u8 = null,
};
