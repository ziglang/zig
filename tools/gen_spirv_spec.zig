const std = @import("std");
const Writer = std.ArrayList(u8).Writer;

//! See https://www.khronos.org/registry/spir-v/specs/unified1/MachineReadableGrammar.html
//! and the files in https://github.com/KhronosGroup/SPIRV-Headers/blob/master/include/spirv/unified1/
//! Note: Non-canonical casing in these structs used to match SPIR-V spec json.
const Registry = union(enum) {
    core: CoreRegistry,
    extension: ExtensionRegistry,
};

const CoreRegistry = struct {
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

const ExtensionRegistry = struct {
    copyright: [][]const u8,
    version: u32,
    revision: u32,
    instructions: []Instruction,
    operand_kinds: []OperandKind = &[_]OperandKind{},
};

const InstructionPrintingClass = struct {
    tag: []const u8,
    heading: ?[]const u8 = null,
};

const Instruction = struct {
    opname: []const u8,
    class: ?[]const u8 = null, // Note: Only available in the core registry.
    opcode: u32,
    operands: []Operand = &[_]Operand{},
    capabilities: [][]const u8 = &[_][]const u8{},
    extensions: [][]const u8 = &[_][]const u8{},
    version: ?[]const u8 = null,

    lastVersion: ?[]const u8 = null,
};

const Operand = struct {
    kind: []const u8,
    /// If this field is 'null', the operand is only expected once.
    quantifier: ?Quantifier = null,
    name: []const u8 = "",
};

const Quantifier = enum {
    /// zero or once
    @"?",
    /// zero or more
    @"*",
};

const OperandCategory = enum {
    BitEnum,
    ValueEnum,
    Id,
    Literal,
    Composite,
};

const OperandKind = struct {
    category: OperandCategory,
    /// The name
    kind: []const u8,
    doc: ?[]const u8 = null,
    enumerants: ?[]Enumerant = null,
    bases: ?[]const []const u8 = null,
};

const Enumerant = struct {
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

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = &arena.allocator;

    const args = try std.process.argsAlloc(allocator);
    if (args.len != 2) {
        usageAndExit(std.io.getStdErr(), args[0], 1);
    }

    const spec_path = args[1];
    const spec = try std.fs.cwd().readFileAlloc(allocator, spec_path, std.math.maxInt(usize));

    var tokens = std.json.TokenStream.init(spec);
    var registry = try std.json.parse(Registry, &tokens, .{.allocator = allocator});

    var buf = std.ArrayList(u8).init(allocator);
    defer buf.deinit();

    try render(buf.writer(), registry);

    const tree = try std.zig.parse(allocator, buf.items);
    _ = try std.zig.render(allocator, std.io.getStdOut().writer(), tree);
}

fn render(writer: Writer, registry: Registry) !void {
    switch (registry) {
        .core => |core_reg| {
            try renderCopyRight(writer, core_reg.copyright);
            try writer.print(
                \\const Version = @import("builtin").Version;
                \\pub const version = Version{{.major = {}, .minor = {}, .patch = {}}};
                \\pub const magic_number: u32 = {s};
                \\
                , .{ core_reg.major_version, core_reg.minor_version, core_reg.revision, core_reg.magic_number },
            );
            try renderOpcodes(writer, core_reg.instructions);
            try renderOperandKinds(writer, core_reg.operand_kinds);
        },
        .extension => |ext_reg| {
            try renderCopyRight(writer, ext_reg.copyright);
            try writer.print(
                \\const Version = @import("builtin").Version;
                \\pub const version = Version{{.major = {}, .minor = 0, .patch = {}}};
                \\
                , .{ ext_reg.version, ext_reg.revision },
            );
            try renderOpcodes(writer, ext_reg.instructions);
            try renderOperandKinds(writer, ext_reg.operand_kinds);
        }
    }
}

fn renderCopyRight(writer: Writer, copyright: []const []const u8) !void {
    for (copyright) |line| {
        try writer.print("// {s}\n", .{ line });
    }
}

fn renderOpcodes(writer: Writer, instructions: []const Instruction) !void {
    try writer.writeAll("pub const Opcode = extern enum(u16) {\n");
    for (instructions) |instr| {
        try writer.print("{} = {},\n", .{ std.zig.fmtId(instr.opname), instr.opcode });
    }
    try writer.writeAll("_,\n};\n");
}

fn renderOperandKinds(writer: Writer, kinds: []const OperandKind) !void {
    for (kinds) |kind| {
        switch (kind.category) {
            .ValueEnum => try renderValueEnum(writer, kind),
            .BitEnum => try renderBitEnum(writer, kind),
            else => {},
        }
    }
}

fn renderValueEnum(writer: Writer, enumeration: OperandKind) !void {
    try writer.print("pub const {s} = extern enum(u32) {{\n", .{ enumeration.kind });

    const enumerants = enumeration.enumerants orelse return error.InvalidRegistry;
    for (enumerants) |enumerant| {
        if (enumerant.value != .int) return error.InvalidRegistry;

        try writer.print("{} = {},\n", .{ std.zig.fmtId(enumerant.enumerant), enumerant.value.int });
    }

    try writer.writeAll("_,\n};\n");
}

fn renderBitEnum(writer: Writer, enumeration: OperandKind) !void {
    try writer.print("pub const {s} = packed struct {{\n", .{ enumeration.kind });

    var flags_by_bitpos = [_]?[]const u8{null} ** 32;
    const enumerants = enumeration.enumerants orelse return error.InvalidRegistry;
    for (enumerants) |enumerant| {
        if (enumerant.value != .bitflag) return error.InvalidRegistry;
        const value = try parseHexInt(enumerant.value.bitflag);
        if (@popCount(u32, value) != 1) {
            continue; // Skip combinations and 'none' items
        }

        var bitpos = std.math.log2_int(u32, value);
        if (flags_by_bitpos[bitpos]) |*existing|{
            // Keep the shortest
            if (enumerant.enumerant.len < existing.len)
                existing.* = enumerant.enumerant;
        } else {
            flags_by_bitpos[bitpos] = enumerant.enumerant;
        }
    }

    for (flags_by_bitpos) |maybe_flag_name, bitpos| {
        if (maybe_flag_name) |flag_name| {
            try writer.writeAll(flag_name);
        } else {
            try writer.print("_reserved_bit_{}", .{bitpos});
        }

        try writer.writeAll(": bool ");
        if (bitpos == 0) { // Force alignment to integer boundaries
            try writer.writeAll("align(@alignOf(u32)) ");
        }
        try writer.writeAll("= false, ");
    }

    try writer.writeAll("};\n");
}

fn parseHexInt(text: []const u8) !u31 {
    const prefix = "0x";
    if (!std.mem.startsWith(u8, text, prefix))
        return error.InvalidHexInt;
    return try std.fmt.parseInt(u31, text[prefix.len ..], 16);
}

fn usageAndExit(file: std.fs.File, arg0: []const u8, code: u8) noreturn {
    file.writer().print(
        \\Usage: {s} <spirv json spec>
        \\
        \\Generates Zig bindings for a SPIR-V specification .json (either core or
        \\extinst versions). The result, printed to stdout, should be used to update
        \\files in src/codegen/spirv.
        \\
        \\The relevant specifications can be obtained from the SPIR-V registry:
        \\https://github.com/KhronosGroup/SPIRV-Headers/blob/master/include/spirv/unified1/
        \\
        , .{arg0}
    ) catch std.process.exit(1);
    std.process.exit(code);
}
