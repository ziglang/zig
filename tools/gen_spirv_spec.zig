const std = @import("std");
const Allocator = std.mem.Allocator;
const g = @import("spirv/grammar.zig");
const CoreRegistry = g.CoreRegistry;
const ExtensionRegistry = g.ExtensionRegistry;
const Instruction = g.Instruction;
const OperandKind = g.OperandKind;
const Enumerant = g.Enumerant;
const Operand = g.Operand;

const ExtendedStructSet = std.StringHashMap(void);

const Extension = struct {
    name: []const u8,
    spec: ExtensionRegistry,
};

const CmpInst = struct {
    fn lt(_: CmpInst, a: Instruction, b: Instruction) bool {
        return a.opcode < b.opcode;
    }
};

const StringPair = struct { []const u8, []const u8 };

const StringPairContext = struct {
    pub fn hash(_: @This(), a: StringPair) u32 {
        var hasher = std.hash.Wyhash.init(0);
        const x, const y = a;
        hasher.update(x);
        hasher.update(y);
        return @truncate(hasher.final());
    }

    pub fn eql(_: @This(), a: StringPair, b: StringPair, b_index: usize) bool {
        _ = b_index;
        const a_x, const a_y = a;
        const b_x, const b_y = b;
        return std.mem.eql(u8, a_x, b_x) and std.mem.eql(u8, a_y, b_y);
    }
};

const OperandKindMap = std.ArrayHashMap(StringPair, OperandKind, StringPairContext, true);

/// Khronos made it so that these names are not defined explicitly, so
/// we need to hardcode it (like they did).
/// See https://github.com/KhronosGroup/SPIRV-Registry/
const set_names = std.StaticStringMap([]const u8).initComptime(.{
    .{ "opencl.std.100", "OpenCL.std" },
    .{ "glsl.std.450", "GLSL.std.450" },
    .{ "opencl.debuginfo.100", "OpenCL.DebugInfo.100" },
    .{ "spv-amd-shader-ballot", "SPV_AMD_shader_ballot" },
    .{ "nonsemantic.shader.debuginfo.100", "NonSemantic.Shader.DebugInfo.100" },
    .{ "nonsemantic.vkspreflection", "NonSemantic.VkspReflection" },
    .{ "nonsemantic.clspvreflection", "NonSemantic.ClspvReflection.6" }, // This version needs to be handled manually
    .{ "spv-amd-gcn-shader", "SPV_AMD_gcn_shader" },
    .{ "spv-amd-shader-trinary-minmax", "SPV_AMD_shader_trinary_minmax" },
    .{ "debuginfo", "DebugInfo" },
    .{ "nonsemantic.debugprintf", "NonSemantic.DebugPrintf" },
    .{ "spv-amd-shader-explicit-vertex-parameter", "SPV_AMD_shader_explicit_vertex_parameter" },
    .{ "nonsemantic.debugbreak", "NonSemantic.DebugBreak" },
    .{ "tosa.001000.1", "SPV_EXT_INST_TYPE_TOSA_001000_1" },
    .{ "zig", "zig" },
});

var arena = std.heap.ArenaAllocator.init(std.heap.smp_allocator);
const allocator = arena.allocator();

pub fn main() !void {
    defer arena.deinit();

    const args = try std.process.argsAlloc(allocator);
    if (args.len != 3) {
        usageAndExit(args[0], 1);
    }

    const json_path = try std.fs.path.join(allocator, &.{ args[1], "include/spirv/unified1/" });
    const dir = try std.fs.cwd().openDir(json_path, .{ .iterate = true });

    const core_spec = try readRegistry(CoreRegistry, dir, "spirv.core.grammar.json");
    std.sort.block(Instruction, core_spec.instructions, CmpInst{}, CmpInst.lt);

    var exts = std.ArrayList(Extension).init(allocator);

    var it = dir.iterate();
    while (try it.next()) |entry| {
        if (entry.kind != .file) {
            continue;
        }

        try readExtRegistry(&exts, dir, entry.name);
    }

    try readExtRegistry(&exts, std.fs.cwd(), args[2]);

    const output_buf = try allocator.alloc(u8, 1024 * 1024);
    var fbs = std.io.fixedBufferStream(output_buf);
    var adapter = fbs.writer().adaptToNewApi();
    const w = &adapter.new_interface;
    try render(w, core_spec, exts.items);
    var output: [:0]u8 = @ptrCast(fbs.getWritten());
    output[output.len] = 0;

    var tree = try std.zig.Ast.parse(allocator, output, .zig);
    var color: std.zig.Color = .on;

    if (tree.errors.len != 0) {
        try std.zig.printAstErrorsToStderr(allocator, tree, "", color);
        return;
    }

    var zir = try std.zig.AstGen.generate(allocator, tree);
    if (zir.hasCompileErrors()) {
        var wip_errors: std.zig.ErrorBundle.Wip = undefined;
        try wip_errors.init(allocator);
        defer wip_errors.deinit();
        try wip_errors.addZirErrorMessages(zir, tree, output, "");
        var error_bundle = try wip_errors.toOwnedBundle("");
        defer error_bundle.deinit(allocator);
        error_bundle.renderToStdErr(color.renderOptions());
    }

    const formatted_output = try tree.render(allocator);
    _ = try std.fs.File.stdout().write(formatted_output);
}

fn readExtRegistry(exts: *std.ArrayList(Extension), dir: std.fs.Dir, sub_path: []const u8) !void {
    const filename = std.fs.path.basename(sub_path);
    if (!std.mem.startsWith(u8, filename, "extinst.")) {
        return;
    }

    std.debug.assert(std.mem.endsWith(u8, filename, ".grammar.json"));
    const name = filename["extinst.".len .. filename.len - ".grammar.json".len];
    const spec = try readRegistry(ExtensionRegistry, dir, sub_path);

    std.sort.block(Instruction, spec.instructions, CmpInst{}, CmpInst.lt);

    try exts.append(.{ .name = set_names.get(name).?, .spec = spec });
}

fn readRegistry(comptime RegistryType: type, dir: std.fs.Dir, path: []const u8) !RegistryType {
    const spec = try dir.readFileAlloc(allocator, path, std.math.maxInt(usize));
    // Required for json parsing.
    @setEvalBranchQuota(10000);

    var scanner = std.json.Scanner.initCompleteInput(allocator, spec);
    var diagnostics = std.json.Diagnostics{};
    scanner.enableDiagnostics(&diagnostics);
    const parsed = std.json.parseFromTokenSource(RegistryType, allocator, &scanner, .{}) catch |err| {
        std.debug.print("{s}:{}:{}:\n", .{ path, diagnostics.getLine(), diagnostics.getColumn() });
        return err;
    };
    return parsed.value;
}

/// Returns a set with types that require an extra struct for the `Instruction` interface
/// to the spir-v spec, or whether the original type can be used.
fn extendedStructs(kinds: []const OperandKind) !ExtendedStructSet {
    var map = ExtendedStructSet.init(allocator);
    try map.ensureTotalCapacity(@as(u32, @intCast(kinds.len)));

    for (kinds) |kind| {
        const enumerants = kind.enumerants orelse continue;

        for (enumerants) |enumerant| {
            if (enumerant.parameters.len > 0) {
                break;
            }
        } else continue;

        map.putAssumeCapacity(kind.kind, {});
    }

    return map;
}

// Return a score for a particular priority. Duplicate instruction/operand enum values are
// removed by picking the tag with the lowest score to keep, and by making an alias for the
// other. Note that the tag does not need to be just a tag at this point, in which case it
// gets the lowest score automatically anyway.
fn tagPriorityScore(tag: []const u8) usize {
    if (tag.len == 0) {
        return 1;
    } else if (std.mem.eql(u8, tag, "EXT")) {
        return 2;
    } else if (std.mem.eql(u8, tag, "KHR")) {
        return 3;
    } else {
        return 4;
    }
}

fn render(writer: *std.io.Writer, registry: CoreRegistry, extensions: []const Extension) !void {
    try writer.writeAll(
        \\//! This file is auto-generated by tools/gen_spirv_spec.zig.
        \\
        \\const std = @import("std");
        \\
        \\pub const Version = packed struct(Word) {
        \\    padding: u8 = 0,
        \\    minor: u8,
        \\    major: u8,
        \\    padding0: u8 = 0,
        \\
        \\    pub fn toWord(self: @This()) Word {
        \\        return @bitCast(self);
        \\    }
        \\};
        \\
        \\pub const Word = u32;
        \\pub const Id = enum(Word) {
        \\    none,
        \\    _,
        \\
        \\    pub fn format(self: Id, writer: *std.io.Writer) std.io.Writer.Error!void {
        \\        switch (self) {
        \\            .none => try writer.writeAll("(none)"),
        \\            else => try writer.print("%{d}", .{@intFromEnum(self)}),
        \\        }
        \\    }
        \\};
        \\
        \\pub const LiteralInteger = Word;
        \\pub const LiteralFloat = Word;
        \\pub const LiteralString = []const u8;
        \\pub const LiteralContextDependentNumber = union(enum) {
        \\    int32: i32,
        \\    uint32: u32,
        \\    int64: i64,
        \\    uint64: u64,
        \\    float32: f32,
        \\    float64: f64,
        \\};
        \\pub const LiteralExtInstInteger = struct{ inst: Word };
        \\pub const LiteralSpecConstantOpInteger = struct { opcode: Opcode };
        \\pub const PairLiteralIntegerIdRef = struct { value: LiteralInteger, label: Id };
        \\pub const PairIdRefLiteralInteger = struct { target: Id, member: LiteralInteger };
        \\pub const PairIdRefIdRef = [2]Id;
        \\
        \\pub const Quantifier = enum {
        \\    required,
        \\    optional,
        \\    variadic,
        \\};
        \\
        \\pub const Operand = struct {
        \\    kind: OperandKind,
        \\    quantifier: Quantifier,
        \\};
        \\
        \\pub const OperandCategory = enum {
        \\    bit_enum,
        \\    value_enum,
        \\    id,
        \\    literal,
        \\    composite,
        \\};
        \\
        \\pub const Enumerant = struct {
        \\    name: []const u8,
        \\    value: Word,
        \\    parameters: []const OperandKind,
        \\};
        \\
        \\pub const Instruction = struct {
        \\    name: []const u8,
        \\    opcode: Word,
        \\    operands: []const Operand,
        \\};
        \\
        \\pub const zig_generator_id: Word = 41;
        \\
    );

    try writer.print(
        \\pub const version: Version = .{{ .major = {}, .minor = {}, .patch = {} }};
        \\pub const magic_number: Word = {s};
        \\
        \\
    ,
        .{ registry.major_version, registry.minor_version, registry.revision, registry.magic_number },
    );

    // Merge the operand kinds from all extensions together.
    // var all_operand_kinds = std.ArrayList(OperandKind).init(a);
    // try all_operand_kinds.appendSlice(registry.operand_kinds);
    var all_operand_kinds = OperandKindMap.init(allocator);
    for (registry.operand_kinds) |kind| {
        try all_operand_kinds.putNoClobber(.{ "core", kind.kind }, kind);
    }
    for (extensions) |ext| {
        // Note: extensions may define the same operand kind, with different
        // parameters. Instead of trying to merge them, just discriminate them
        // using the name of the extension. This is similar to what
        // the official headers do.

        try all_operand_kinds.ensureUnusedCapacity(ext.spec.operand_kinds.len);
        for (ext.spec.operand_kinds) |kind| {
            var new_kind = kind;
            new_kind.kind = try std.mem.join(allocator, ".", &.{ ext.name, kind.kind });
            try all_operand_kinds.putNoClobber(.{ ext.name, kind.kind }, new_kind);
        }
    }

    const extended_structs = try extendedStructs(all_operand_kinds.values());
    // Note: extensions don't seem to have class.
    try renderClass(writer, registry.instructions);
    try renderOperandKind(writer, all_operand_kinds.values());
    try renderOpcodes(writer, registry.instructions, extended_structs);
    try renderOperandKinds(writer, all_operand_kinds.values(), extended_structs);
    try renderInstructionSet(writer, registry, extensions, all_operand_kinds);
}

fn renderInstructionSet(
    writer: anytype,
    core: CoreRegistry,
    extensions: []const Extension,
    all_operand_kinds: OperandKindMap,
) !void {
    try writer.writeAll(
        \\pub const InstructionSet = enum {
        \\    core,
    );

    for (extensions) |ext| {
        try writer.print("{f},\n", .{formatId(ext.name)});
    }

    try writer.writeAll(
        \\
        \\    pub fn instructions(self: InstructionSet) []const Instruction {
        \\        return switch (self) {
        \\
    );

    try renderInstructionsCase(writer, "core", core.instructions, all_operand_kinds);
    for (extensions) |ext| {
        try renderInstructionsCase(writer, ext.name, ext.spec.instructions, all_operand_kinds);
    }

    try writer.writeAll(
        \\        };
        \\    }
        \\};
        \\
    );
}

fn renderInstructionsCase(
    writer: anytype,
    set_name: []const u8,
    instructions: []const Instruction,
    all_operand_kinds: OperandKindMap,
) !void {
    // Note: theoretically we could dedup from tags and give every instruction a list of aliases,
    // but there aren't so many total aliases and that would add more overhead in total. We will
    // just filter those out when needed.

    try writer.print(".{f} => &.{{\n", .{formatId(set_name)});

    for (instructions) |inst| {
        try writer.print(
            \\.{{
            \\    .name = "{s}",
            \\    .opcode = {},
            \\    .operands = &.{{
            \\
        , .{ inst.opname, inst.opcode });

        for (inst.operands) |operand| {
            const quantifier = if (operand.quantifier) |q|
                switch (q) {
                    .@"?" => "optional",
                    .@"*" => "variadic",
                }
            else
                "required";

            const kind = all_operand_kinds.get(.{ set_name, operand.kind }) orelse
                all_operand_kinds.get(.{ "core", operand.kind }).?;
            try writer.print(".{{.kind = .{f}, .quantifier = .{s}}},\n", .{ formatId(kind.kind), quantifier });
        }

        try writer.writeAll(
            \\    },
            \\},
            \\
        );
    }

    try writer.writeAll(
        \\},
        \\
    );
}

fn renderClass(writer: anytype, instructions: []const Instruction) !void {
    var class_map = std.StringArrayHashMap(void).init(allocator);

    for (instructions) |inst| {
        if (std.mem.eql(u8, inst.class.?, "@exclude")) continue;
        try class_map.put(inst.class.?, {});
    }

    try writer.writeAll("pub const Class = enum {\n");
    for (class_map.keys()) |class| {
        try writer.print("{f},\n", .{formatId(class)});
    }
    try writer.writeAll("};\n\n");
}

const Formatter = struct {
    data: []const u8,

    fn format(f: Formatter, writer: *std.io.Writer) std.io.Writer.Error!void {
        var id_buf: [128]u8 = undefined;
        var fbs = std.io.fixedBufferStream(&id_buf);
        const fw = fbs.writer();
        for (f.data, 0..) |c, i| {
            switch (c) {
                '-', '_', '.', '~', ' ' => fw.writeByte('_') catch return error.WriteFailed,
                'a'...'z', '0'...'9' => fw.writeByte(c) catch return error.WriteFailed,
                'A'...'Z' => {
                    if ((i > 0 and std.ascii.isLower(f.data[i - 1])) or
                        (i > 0 and std.ascii.isUpper(f.data[i - 1]) and
                            i + 1 < f.data.len and std.ascii.isLower(f.data[i + 1])))
                    {
                        _ = fw.write(&.{ '_', std.ascii.toLower(c) }) catch return error.WriteFailed;
                    } else {
                        fw.writeByte(std.ascii.toLower(c)) catch return error.WriteFailed;
                    }
                },
                else => unreachable,
            }
        }

        // make sure that this won't clobber with zig keywords
        try writer.print("{f}", .{std.zig.fmtId(fbs.getWritten())});
    }
};

fn formatId(identifier: []const u8) std.fmt.Alt(Formatter, Formatter.format) {
    return .{ .data = .{ .data = identifier } };
}

fn renderOperandKind(writer: anytype, operands: []const OperandKind) !void {
    try writer.writeAll(
        \\pub const OperandKind = enum {
        \\    opcode,
        \\
    );
    for (operands) |operand| {
        try writer.print("{f},\n", .{formatId(operand.kind)});
    }
    try writer.writeAll(
        \\
        \\pub fn category(self: OperandKind) OperandCategory {
        \\    return switch (self) {
        \\        .opcode => .literal,
        \\
    );
    for (operands) |operand| {
        const cat = switch (operand.category) {
            .BitEnum => "bit_enum",
            .ValueEnum => "value_enum",
            .Id => "id",
            .Literal => "literal",
            .Composite => "composite",
        };
        try writer.print(".{f} => .{s},\n", .{ formatId(operand.kind), cat });
    }
    try writer.writeAll(
        \\    };
        \\}
        \\pub fn enumerants(self: OperandKind) []const Enumerant {
        \\    return switch (self) {
        \\        .opcode => unreachable,
        \\
    );
    for (operands) |operand| {
        switch (operand.category) {
            .BitEnum, .ValueEnum => {},
            else => {
                try writer.print(".{f} => unreachable,\n", .{formatId(operand.kind)});
                continue;
            },
        }

        try writer.print(".{f} => &.{{", .{formatId(operand.kind)});
        for (operand.enumerants.?) |enumerant| {
            if (enumerant.value == .bitflag and std.mem.eql(u8, enumerant.enumerant, "None")) {
                continue;
            }
            try renderEnumerant(writer, enumerant);
            try writer.writeAll(",");
        }
        try writer.writeAll("},\n");
    }
    try writer.writeAll("};\n}\n};\n");
}

fn renderEnumerant(writer: anytype, enumerant: Enumerant) !void {
    try writer.print(".{{.name = \"{s}\", .value = ", .{enumerant.enumerant});
    switch (enumerant.value) {
        .bitflag => |flag| try writer.writeAll(flag),
        .int => |int| try writer.print("{}", .{int}),
    }
    try writer.writeAll(", .parameters = &.{");
    for (enumerant.parameters, 0..) |param, i| {
        if (i != 0)
            try writer.writeAll(", ");
        // Note, param.quantifier will always be one.
        try writer.print(".{f}", .{formatId(param.kind)});
    }
    try writer.writeAll("}}");
}

fn renderOpcodes(
    writer: anytype,
    instructions: []const Instruction,
    extended_structs: ExtendedStructSet,
) !void {
    var inst_map = std.AutoArrayHashMap(u32, usize).init(allocator);
    try inst_map.ensureTotalCapacity(instructions.len);

    var aliases = std.ArrayList(struct { inst: usize, alias: usize }).init(allocator);
    try aliases.ensureTotalCapacity(instructions.len);

    for (instructions, 0..) |inst, i| {
        if (std.mem.eql(u8, inst.class.?, "@exclude")) continue;

        const result = inst_map.getOrPutAssumeCapacity(inst.opcode);
        if (!result.found_existing) {
            result.value_ptr.* = i;
            continue;
        }

        const existing = instructions[result.value_ptr.*];

        const tag_index = std.mem.indexOfDiff(u8, inst.opname, existing.opname).?;
        const inst_priority = tagPriorityScore(inst.opname[tag_index..]);
        const existing_priority = tagPriorityScore(existing.opname[tag_index..]);

        if (inst_priority < existing_priority) {
            aliases.appendAssumeCapacity(.{ .inst = result.value_ptr.*, .alias = i });
            result.value_ptr.* = i;
        } else {
            aliases.appendAssumeCapacity(.{ .inst = i, .alias = result.value_ptr.* });
        }
    }

    const instructions_indices = inst_map.values();

    try writer.writeAll("pub const Opcode = enum(u16) {\n");
    for (instructions_indices) |i| {
        const inst = instructions[i];
        try writer.print("{f} = {},\n", .{ std.zig.fmtId(inst.opname), inst.opcode });
    }

    try writer.writeAll(
        \\
    );

    for (aliases.items) |alias| {
        try writer.print("pub const {f} = Opcode.{f};\n", .{
            formatId(instructions[alias.inst].opname),
            formatId(instructions[alias.alias].opname),
        });
    }

    try writer.writeAll(
        \\
        \\pub fn Operands(comptime self: Opcode) type {
        \\    return switch (self) {
        \\
    );

    for (instructions_indices) |i| {
        const inst = instructions[i];
        try renderOperand(writer, .instruction, inst.opname, inst.operands, extended_structs, false);
    }

    try writer.writeAll(
        \\    };
        \\}
        \\pub fn class(self: Opcode) Class {
        \\    return switch (self) {
        \\
    );

    for (instructions_indices) |i| {
        const inst = instructions[i];
        try writer.print(".{f} => .{f},\n", .{ std.zig.fmtId(inst.opname), formatId(inst.class.?) });
    }

    try writer.writeAll(
        \\   };
        \\}
        \\};
        \\
    );
}

fn renderOperandKinds(
    writer: anytype,
    kinds: []const OperandKind,
    extended_structs: ExtendedStructSet,
) !void {
    for (kinds) |kind| {
        switch (kind.category) {
            .ValueEnum => try renderValueEnum(writer, kind, extended_structs),
            .BitEnum => try renderBitEnum(writer, kind, extended_structs),
            else => {},
        }
    }
}

fn renderValueEnum(
    writer: anytype,
    enumeration: OperandKind,
    extended_structs: ExtendedStructSet,
) !void {
    const enumerants = enumeration.enumerants orelse return error.InvalidRegistry;

    var enum_map = std.AutoArrayHashMap(u32, usize).init(allocator);
    try enum_map.ensureTotalCapacity(enumerants.len);

    var aliases = std.ArrayList(struct { enumerant: usize, alias: usize }).init(allocator);
    try aliases.ensureTotalCapacity(enumerants.len);

    for (enumerants, 0..) |enumerant, i| {
        const value: u31 = switch (enumerant.value) {
            .int => |value| value,
            // Some extensions declare ints as string
            .bitflag => |value| try std.fmt.parseInt(u31, value, 10),
        };
        const result = enum_map.getOrPutAssumeCapacity(value);
        if (!result.found_existing) {
            result.value_ptr.* = i;
            continue;
        }

        const existing = enumerants[result.value_ptr.*];

        const tag_index = std.mem.indexOfDiff(u8, enumerant.enumerant, existing.enumerant).?;
        const enum_priority = tagPriorityScore(enumerant.enumerant[tag_index..]);
        const existing_priority = tagPriorityScore(existing.enumerant[tag_index..]);

        if (enum_priority < existing_priority) {
            aliases.appendAssumeCapacity(.{ .enumerant = result.value_ptr.*, .alias = i });
            result.value_ptr.* = i;
        } else {
            aliases.appendAssumeCapacity(.{ .enumerant = i, .alias = result.value_ptr.* });
        }
    }

    const enum_indices = enum_map.values();

    try writer.print("pub const {f} = enum(u32) {{\n", .{std.zig.fmtId(enumeration.kind)});

    for (enum_indices) |i| {
        const enumerant = enumerants[i];
        // if (enumerant.value != .int) return error.InvalidRegistry;

        switch (enumerant.value) {
            .int => |value| try writer.print("{f} = {},\n", .{ formatId(enumerant.enumerant), value }),
            .bitflag => |value| try writer.print("{f} = {s},\n", .{ formatId(enumerant.enumerant), value }),
        }
    }

    try writer.writeByte('\n');

    for (aliases.items) |alias| {
        try writer.print("pub const {f} = {f}.{f};\n", .{
            formatId(enumerants[alias.enumerant].enumerant),
            std.zig.fmtId(enumeration.kind),
            formatId(enumerants[alias.alias].enumerant),
        });
    }

    if (!extended_structs.contains(enumeration.kind)) {
        try writer.writeAll("};\n");
        return;
    }

    try writer.print("\npub const Extended = union({f}) {{\n", .{std.zig.fmtId(enumeration.kind)});

    for (enum_indices) |i| {
        const enumerant = enumerants[i];
        try renderOperand(writer, .@"union", enumerant.enumerant, enumerant.parameters, extended_structs, true);
    }

    try writer.writeAll("};\n};\n");
}

fn renderBitEnum(
    writer: anytype,
    enumeration: OperandKind,
    extended_structs: ExtendedStructSet,
) !void {
    try writer.print("pub const {f} = packed struct {{\n", .{std.zig.fmtId(enumeration.kind)});

    var flags_by_bitpos = [_]?usize{null} ** 32;
    const enumerants = enumeration.enumerants orelse return error.InvalidRegistry;

    var aliases = std.ArrayList(struct { flag: usize, alias: u5 }).init(allocator);
    try aliases.ensureTotalCapacity(enumerants.len);

    for (enumerants, 0..) |enumerant, i| {
        if (enumerant.value != .bitflag) return error.InvalidRegistry;
        const value = try parseHexInt(enumerant.value.bitflag);
        if (value == 0) {
            continue; // Skip 'none' items
        } else if (std.mem.eql(u8, enumerant.enumerant, "FlagIsPublic")) {
            // This flag is special and poorly defined in the json files.
            // Just skip it for now
            continue;
        }

        std.debug.assert(@popCount(value) == 1);

        const bitpos = std.math.log2_int(u32, value);
        if (flags_by_bitpos[bitpos]) |*existing| {
            const tag_index = std.mem.indexOfDiff(u8, enumerant.enumerant, enumerants[existing.*].enumerant).?;
            const enum_priority = tagPriorityScore(enumerant.enumerant[tag_index..]);
            const existing_priority = tagPriorityScore(enumerants[existing.*].enumerant[tag_index..]);

            if (enum_priority < existing_priority) {
                aliases.appendAssumeCapacity(.{ .flag = existing.*, .alias = bitpos });
                existing.* = i;
            } else {
                aliases.appendAssumeCapacity(.{ .flag = i, .alias = bitpos });
            }
        } else {
            flags_by_bitpos[bitpos] = i;
        }
    }

    for (flags_by_bitpos, 0..) |maybe_flag_index, bitpos| {
        if (maybe_flag_index) |flag_index| {
            try writer.print("{f}", .{formatId(enumerants[flag_index].enumerant)});
        } else {
            try writer.print("_reserved_bit_{}", .{bitpos});
        }

        try writer.writeAll(": bool = false,\n");
    }

    try writer.writeByte('\n');

    for (aliases.items) |alias| {
        try writer.print("pub const {f}: {f} = .{{.{f} = true}};\n", .{
            formatId(enumerants[alias.flag].enumerant),
            std.zig.fmtId(enumeration.kind),
            formatId(enumerants[flags_by_bitpos[alias.alias].?].enumerant),
        });
    }

    if (!extended_structs.contains(enumeration.kind)) {
        try writer.writeAll("};\n");
        return;
    }

    try writer.print("\npub const Extended = struct {{\n", .{});

    for (flags_by_bitpos, 0..) |maybe_flag_index, bitpos| {
        const flag_index = maybe_flag_index orelse {
            try writer.print("_reserved_bit_{}: bool = false,\n", .{bitpos});
            continue;
        };
        const enumerant = enumerants[flag_index];

        try renderOperand(writer, .mask, enumerant.enumerant, enumerant.parameters, extended_structs, true);
    }

    try writer.writeAll("};\n};\n");
}

fn renderOperand(
    writer: anytype,
    kind: enum {
        @"union",
        instruction,
        mask,
    },
    field_name: []const u8,
    parameters: []const Operand,
    extended_structs: ExtendedStructSet,
    snake_case: bool,
) !void {
    if (kind == .instruction) {
        try writer.writeByte('.');
    }

    if (snake_case) {
        try writer.print("{f}", .{formatId(field_name)});
    } else {
        try writer.print("{f}", .{std.zig.fmtId(field_name)});
    }

    if (parameters.len == 0) {
        switch (kind) {
            .@"union" => try writer.writeAll(",\n"),
            .instruction => try writer.writeAll(" => void,\n"),
            .mask => try writer.writeAll(": bool = false,\n"),
        }
        return;
    }

    if (kind == .instruction) {
        try writer.writeAll(" => ");
    } else {
        try writer.writeAll(": ");
    }

    if (kind == .mask) {
        try writer.writeByte('?');
    }

    try writer.writeAll("struct {");

    for (parameters, 0..) |param, j| {
        if (j != 0) {
            try writer.writeAll(", ");
        }

        try renderFieldName(writer, parameters, j);
        try writer.writeAll(": ");

        if (param.quantifier) |q| {
            switch (q) {
                .@"?" => try writer.writeByte('?'),
                .@"*" => try writer.writeAll("[]const "),
            }
        }

        if (std.mem.startsWith(u8, param.kind, "Id")) {
            _ = try writer.write("Id");
        } else {
            try writer.print("{f}", .{std.zig.fmtId(param.kind)});
        }

        if (extended_structs.contains(param.kind)) {
            try writer.writeAll(".Extended");
        }

        if (param.quantifier) |q| {
            switch (q) {
                .@"?" => try writer.writeAll(" = null"),
                .@"*" => try writer.writeAll(" = &.{}"),
            }
        }
    }

    try writer.writeAll("}");

    if (kind == .mask) {
        try writer.writeAll(" = null");
    }

    try writer.writeAll(",\n");
}

fn renderFieldName(writer: anytype, operands: []const Operand, field_index: usize) !void {
    const operand = operands[field_index];

    derive_from_kind: {
        // Operand names are often in the json encoded as "'Name'" (with two sets of quotes).
        // Additionally, some operands have ~ in them at the end (D~ref~).
        const name = std.mem.trim(u8, operand.name, "'~");
        if (name.len == 0) break :derive_from_kind;

        for (name) |c| {
            switch (c) {
                'a'...'z', '0'...'9', 'A'...'Z', ' ', '~' => continue,
                else => break :derive_from_kind,
            }
        }

        try writer.print("{f}", .{formatId(name)});
        return;
    }

    try writer.print("{f}", .{formatId(operand.kind)});

    // For fields derived from type name, there could be any amount.
    // Simply check against all other fields, and if another similar one exists, add a number.
    const need_extra_index = for (operands, 0..) |other_operand, i| {
        if (i != field_index and std.mem.eql(u8, operand.kind, other_operand.kind)) {
            break true;
        }
    } else false;

    if (need_extra_index) {
        try writer.print("_{}", .{field_index});
    }
}

fn parseHexInt(text: []const u8) !u31 {
    const prefix = "0x";
    if (!std.mem.startsWith(u8, text, prefix))
        return error.InvalidHexInt;
    return try std.fmt.parseInt(u31, text[prefix.len..], 16);
}

fn usageAndExit(arg0: []const u8, code: u8) noreturn {
    const stderr = std.debug.lockStderrWriter(&.{});
    stderr.print(
        \\Usage: {s} <SPIRV-Headers repository path> <path/to/zig/src/codegen/spirv/extinst.zig.grammar.json>
        \\
        \\Generates Zig bindings for SPIR-V specifications found in the SPIRV-Headers
        \\repository. The result, printed to stdout, should be used to update
        \\files in src/codegen/spirv. Don't forget to format the output.
        \\
        \\<SPIRV-Headers repository path> should point to a clone of
        \\https://github.com/KhronosGroup/SPIRV-Headers/
        \\
    , .{arg0}) catch std.process.exit(1);
    std.process.exit(code);
}
