const Assembler = @This();

const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

const spec = @import("spec.zig");
const Opcode = spec.Opcode;
const Word = spec.Word;
const IdRef = spec.IdRef;
const IdResult = spec.IdResult;

const SpvModule = @import("Module.zig");
const SpvType = @import("type.zig").Type;

/// Represents a token in the assembly template.
const Token = struct {
    tag: Tag,
    start: u32,
    end: u32,

    const Tag = enum {
        /// Returned when there was no more input to match.
        eof,
        /// %identifier
        result_id,
        /// %identifier when appearing on the LHS of an equals sign.
        /// While not technically a token, its relatively easy to resolve
        /// this during lexical analysis and relieves a bunch of headaches
        /// during parsing.
        result_id_assign,
        /// Mask, int, or float. These are grouped together as some
        /// SPIR-V enumerants look a bit like integers as well (for example
        /// "3D"), and so it is easier to just interpret them as the expected
        /// type when resolving an instruction's operands.
        value,
        /// An enumerant that looks like an opcode, that is, OpXxxx.
        /// Not necessarily a *valid* opcode.
        opcode,
        /// String literals.
        /// Note, this token is also returned for unterminated
        /// strings. In this case the closing " is not present.
        string,
        /// |.
        pipe,
        /// =.
        equals,

        fn name(self: Tag) []const u8 {
            return switch (self) {
                .eof => "<end of input>",
                .result_id => "<result-id>",
                .result_id_assign => "<assigned result-id>",
                .value => "<value>",
                .opcode => "<opcode>",
                .string => "<string literal>",
                .pipe => "'|'",
                .equals => "'='",
            };
        }
    };
};

/// This union represents utility information for a decoded operand.
/// Note that this union only needs to maintain a minimal amount of
/// bookkeeping: these values are enough to either decode the operands
/// into a spec type, or emit it directly into its binary form.
const Operand = union(enum) {
    /// Any 'simple' 32-bit value. This could be a mask or
    /// enumerant, etc, depending on the operands.
    value: u32,

    /// An int- or float literal encoded as 1 word. This may be
    /// a 32-bit literal or smaller, already in the proper format:
    /// the opper bits are 0 for floats and unsigned ints, and sign-extended
    /// for signed ints.
    literal32: u32,

    /// An int- or float literal encoded as 2 words. This may be a 33-bit
    /// to 64 bit literal, already in the proper format:
    /// the opper bits are 0 for floats and unsigned ints, and sign-extended
    /// for signed ints.
    literal64: u64,

    /// A result-id which is assigned to in this instruction. If present,
    /// this is the first operand of the instruction.
    result_id: AsmValue.Ref,

    /// A result-id which referred to (not assigned to) in this instruction.
    ref_id: AsmValue.Ref,

    /// Offset into `inst.string_bytes`. The string ends at the next zero-terminator.
    string: u32,
};

/// A structure representing an error message that the assembler may return, when
/// the assembly source is not syntactically or semantically correct.
const ErrorMsg = struct {
    /// The offset in bytes from the start of `src` that this error occured.
    byte_offset: u32,
    /// An explanatory error message.
    /// Memory is owned by `self.gpa`. TODO: Maybe allocate this with an arena
    /// allocator if it is needed elsewhere?
    msg: []const u8,
};

/// Possible errors the `assemble` function may return.
const Error = error{ AssembleFail, OutOfMemory };

/// This union is used to keep track of results of spir-v instructions. This can either be just a plain
/// result-id, in the case of most instructions, or for example a type that is constructed from
/// an OpTypeXxx instruction.
const AsmValue = union(enum) {
    /// The results are stored in an array hash map, and can be referred to either by name (without the %),
    /// or by values of this index type.
    pub const Ref = u32;

    /// This result-value is the RHS of the current instruction.
    just_declared,

    /// This is used as placeholder for ref-ids of which the result-id is not yet known.
    /// It will be further resolved at a later stage to a more concrete forward reference.
    unresolved_forward_reference,

    /// This result-value is a normal result produced by a different instruction.
    value: IdRef,

    /// This result-value represents a type registered into the module's type system.
    ty: SpvType.Ref,

    /// Retrieve the result-id of this AsmValue. Asserts that this AsmValue
    /// is of a variant that allows the result to be obtained (not an unresolved
    /// forward declaration, not in the process of being declared, etc).
    pub fn resultId(self: AsmValue, spv: *const SpvModule) IdRef {
        return switch (self) {
            .just_declared, .unresolved_forward_reference => unreachable,
            .value => |result| result,
            .ty => |ref| spv.typeId(ref),
        };
    }
};

/// This map type maps results to values. Results can be addressed either by name (without the %), or by
/// AsmValue.Ref in AsmValueMap.keys/.values.
const AsmValueMap = std.StringArrayHashMapUnmanaged(AsmValue);

/// An allocator used for common allocations.
gpa: Allocator,

/// A list of errors that occured during processing the assembly.
errors: std.ArrayListUnmanaged(ErrorMsg) = .{},

/// The source code that is being assembled.
src: []const u8,

/// The module that this assembly is associated to.
/// Instructions like OpType*, OpDecorate, etc are emitted into this module.
spv: *SpvModule,

/// The function that the function-specific instructions should be emitted to.
func: *SpvModule.Fn,

/// `self.src` tokenized.
tokens: std.ArrayListUnmanaged(Token) = .{},

/// The token that is next during parsing.
current_token: u32 = 0,

/// This field groups the properties of the instruction that is currently
/// being parsed or has just been parsed.
inst: struct {
    /// The opcode of the current instruction.
    opcode: Opcode = undefined,
    /// Operands of the current instruction.
    operands: std.ArrayListUnmanaged(Operand) = .{},
    /// This is where string data resides. Strings are zero-terminated.
    string_bytes: std.ArrayListUnmanaged(u8) = .{},

    /// Return a reference to the result of this instruction, if any.
    fn result(self: @This()) ?AsmValue.Ref {
        // The result, if present, is either the first or second
        // operand of an instruction.
        for (self.operands.items[0..@min(self.operands.items.len, 2)]) |op| {
            switch (op) {
                .result_id => |index| return index,
                else => {},
            }
        }
        return null;
    }
} = .{},

/// This map maps results to their tracked values.
value_map: AsmValueMap = .{},

/// Free the resources owned by this assembler.
pub fn deinit(self: *Assembler) void {
    for (self.errors.items) |err| {
        self.gpa.free(err.msg);
    }
    self.tokens.deinit(self.gpa);
    self.errors.deinit(self.gpa);
    self.inst.operands.deinit(self.gpa);
    self.inst.string_bytes.deinit(self.gpa);
    self.value_map.deinit(self.gpa);
}

pub fn assemble(self: *Assembler) Error!void {
    try self.tokenize();
    while (!self.testToken(.eof)) {
        try self.parseInstruction();
        try self.processInstruction();
    }
    if (self.errors.items.len > 0)
        return error.AssembleFail;
}

fn addError(self: *Assembler, offset: u32, comptime fmt: []const u8, args: anytype) !void {
    const msg = try std.fmt.allocPrint(self.gpa, fmt, args);
    errdefer self.gpa.free(msg);
    try self.errors.append(self.gpa, .{
        .byte_offset = offset,
        .msg = msg,
    });
}

fn fail(self: *Assembler, offset: u32, comptime fmt: []const u8, args: anytype) Error {
    try self.addError(offset, fmt, args);
    return error.AssembleFail;
}

fn todo(self: *Assembler, comptime fmt: []const u8, args: anytype) Error {
    return self.fail(0, "todo: " ++ fmt, args);
}

/// Attempt to process the instruction currently in `self.inst`.
/// This for example emits the instruction in the module or function, or
/// records type definitions.
/// If this function returns `error.AssembleFail`, an explanatory
/// error message has already been emitted into `self.errors`.
fn processInstruction(self: *Assembler) !void {
    const result = switch (self.inst.opcode) {
        .OpEntryPoint => {
            return self.fail(0, "cannot export entry points via OpEntryPoint, export the kernel using callconv(.Kernel)", .{});
        },
        else => switch (self.inst.opcode.class()) {
            .TypeDeclaration => try self.processTypeInstruction(),
            else => if (try self.processGenericInstruction()) |result|
                result
            else
                return,
        },
    };

    const result_ref = self.inst.result().?;
    switch (self.value_map.values()[result_ref]) {
        .just_declared => self.value_map.values()[result_ref] = result,
        else => {
            // TODO: Improve source location.
            const name = self.value_map.keys()[result_ref];
            return self.fail(0, "duplicate definition of %{s}", .{name});
        },
    }
}

/// Record `self.inst` into the module's type system, and return the AsmValue that
/// refers to the result.
fn processTypeInstruction(self: *Assembler) !AsmValue {
    const operands = self.inst.operands.items;
    const ty = switch (self.inst.opcode) {
        .OpTypeVoid => SpvType.initTag(.void),
        .OpTypeBool => SpvType.initTag(.bool),
        .OpTypeInt => blk: {
            const signedness: std.builtin.Signedness = switch (operands[2].literal32) {
                0 => .unsigned,
                1 => .signed,
                else => {
                    // TODO: Improve source location.
                    return self.fail(0, "{} is not a valid signedness (expected 0 or 1)", .{operands[2].literal32});
                },
            };
            const width = std.math.cast(u16, operands[1].literal32) orelse {
                return self.fail(0, "int type of {} bits is too large", .{operands[1].literal32});
            };
            break :blk try SpvType.int(self.spv.arena, signedness, width);
        },
        .OpTypeFloat => blk: {
            const bits = operands[1].literal32;
            switch (bits) {
                16, 32, 64 => {},
                else => {
                    return self.fail(0, "{} is not a valid bit count for floats (expected 16, 32 or 64)", .{bits});
                },
            }
            break :blk SpvType.float(@intCast(u16, bits));
        },
        .OpTypeVector => blk: {
            const payload = try self.spv.arena.create(SpvType.Payload.Vector);
            payload.* = .{
                .component_type = try self.resolveTypeRef(operands[1].ref_id),
                .component_count = operands[2].literal32,
            };
            break :blk SpvType.initPayload(&payload.base);
        },
        .OpTypeMatrix => blk: {
            const payload = try self.spv.arena.create(SpvType.Payload.Matrix);
            payload.* = .{
                .column_type = try self.resolveTypeRef(operands[1].ref_id),
                .column_count = operands[2].literal32,
            };
            break :blk SpvType.initPayload(&payload.base);
        },
        .OpTypeImage => blk: {
            const payload = try self.spv.arena.create(SpvType.Payload.Image);
            payload.* = .{
                .sampled_type = try self.resolveTypeRef(operands[1].ref_id),
                .dim = @intToEnum(spec.Dim, operands[2].value),
                .depth = switch (operands[3].literal32) {
                    0 => .no,
                    1 => .yes,
                    2 => .maybe,
                    else => {
                        return self.fail(0, "'{}' is not a valid image depth (expected 0, 1 or 2)", .{operands[3].literal32});
                    },
                },
                .arrayed = switch (operands[4].literal32) {
                    0 => false,
                    1 => true,
                    else => {
                        return self.fail(0, "'{}' is not a valid image arrayed-ness (expected 0 or 1)", .{operands[4].literal32});
                    },
                },
                .multisampled = switch (operands[5].literal32) {
                    0 => false,
                    1 => true,
                    else => {
                        return self.fail(0, "'{}' is not a valid image multisampled-ness (expected 0 or 1)", .{operands[5].literal32});
                    },
                },
                .sampled = switch (operands[6].literal32) {
                    0 => .known_at_runtime,
                    1 => .with_sampler,
                    2 => .without_sampler,
                    else => {
                        return self.fail(0, "'{}' is not a valid image sampled-ness (expected 0, 1 or 2)", .{operands[6].literal32});
                    },
                },
                .format = @intToEnum(spec.ImageFormat, operands[7].value),
                .access_qualifier = if (operands.len > 8)
                    @intToEnum(spec.AccessQualifier, operands[8].value)
                else
                    null,
            };
            break :blk SpvType.initPayload(&payload.base);
        },
        .OpTypeSampler => SpvType.initTag(.sampler),
        .OpTypeSampledImage => blk: {
            const payload = try self.spv.arena.create(SpvType.Payload.SampledImage);
            payload.* = .{
                .image_type = try self.resolveTypeRef(operands[1].ref_id),
            };
            break :blk SpvType.initPayload(&payload.base);
        },
        .OpTypeArray => {
            // TODO: The length of an OpTypeArray is determined by a constant (which may be a spec constant),
            // and so some consideration must be taken when entering this in the type system.
            return self.todo("process OpTypeArray", .{});
        },
        .OpTypeRuntimeArray => blk: {
            const payload = try self.spv.arena.create(SpvType.Payload.RuntimeArray);
            payload.* = .{
                .element_type = try self.resolveTypeRef(operands[1].ref_id),
                // TODO: Fetch array stride from decorations.
                .array_stride = 0,
            };
            break :blk SpvType.initPayload(&payload.base);
        },
        .OpTypeOpaque => blk: {
            const payload = try self.spv.arena.create(SpvType.Payload.Opaque);
            const name_offset = operands[1].string;
            payload.* = .{
                .name = std.mem.sliceTo(self.inst.string_bytes.items[name_offset..], 0),
            };
            break :blk SpvType.initPayload(&payload.base);
        },
        .OpTypePointer => blk: {
            const payload = try self.spv.arena.create(SpvType.Payload.Pointer);
            payload.* = .{
                .storage_class = @intToEnum(spec.StorageClass, operands[1].value),
                .child_type = try self.resolveTypeRef(operands[2].ref_id),
                // TODO: Fetch decorations
            };
            break :blk SpvType.initPayload(&payload.base);
        },
        .OpTypeFunction => blk: {
            const param_operands = operands[2..];
            const param_types = try self.spv.arena.alloc(SpvType.Ref, param_operands.len);
            for (param_types, 0..) |*param, i| {
                param.* = try self.resolveTypeRef(param_operands[i].ref_id);
            }
            const payload = try self.spv.arena.create(SpvType.Payload.Function);
            payload.* = .{
                .return_type = try self.resolveTypeRef(operands[1].ref_id),
                .parameters = param_types,
            };
            break :blk SpvType.initPayload(&payload.base);
        },
        .OpTypeEvent => SpvType.initTag(.event),
        .OpTypeDeviceEvent => SpvType.initTag(.device_event),
        .OpTypeReserveId => SpvType.initTag(.reserve_id),
        .OpTypeQueue => SpvType.initTag(.queue),
        .OpTypePipe => blk: {
            const payload = try self.spv.arena.create(SpvType.Payload.Pipe);
            payload.* = .{
                .qualifier = @intToEnum(spec.AccessQualifier, operands[1].value),
            };
            break :blk SpvType.initPayload(&payload.base);
        },
        .OpTypePipeStorage => SpvType.initTag(.pipe_storage),
        .OpTypeNamedBarrier => SpvType.initTag(.named_barrier),
        else => return self.todo("process type instruction {s}", .{@tagName(self.inst.opcode)}),
    };

    const ref = try self.spv.resolveType(ty);
    return AsmValue{ .ty = ref };
}

/// Emit `self.inst` into `self.spv` and `self.func`, and return the AsmValue
/// that this produces (if any). This function processes common instructions:
/// - No forward references are allowed in operands.
/// - Target section is determined from instruction type.
/// - Function-local instructions are emitted in `self.func`.
fn processGenericInstruction(self: *Assembler) !?AsmValue {
    const operands = self.inst.operands.items;
    const section = switch (self.inst.opcode.class()) {
        .ConstantCreation => &self.spv.sections.types_globals_constants,
        .Annotation => &self.spv.sections.annotations,
        .TypeDeclaration => unreachable, // Handled elsewhere.
        else => switch (self.inst.opcode) {
            .OpEntryPoint => unreachable,
            .OpExecutionMode, .OpExecutionModeId => &self.spv.sections.execution_modes,
            .OpVariable => switch (@intToEnum(spec.StorageClass, operands[2].value)) {
                .Function => &self.func.prologue,
                else => {
                    // This is currently disabled because global variables are required to be
                    // emitted in the proper order, and this should be honored in inline assembly
                    // as well.
                    return self.todo("global variables", .{});
                },
            },
            // Default case - to be worked out further.
            else => &self.func.body,
        },
    };

    var maybe_result_id: ?IdResult = null;
    const first_word = section.instructions.items.len;
    // At this point we're not quite sure how many operands this instruction is going to have,
    // so insert 0 and patch up the actual opcode word later.
    try section.ensureUnusedCapacity(self.spv.gpa, 1);
    section.writeWord(0);

    for (operands) |operand| {
        switch (operand) {
            .value, .literal32 => |word| {
                try section.ensureUnusedCapacity(self.spv.gpa, 1);
                section.writeWord(word);
            },
            .literal64 => |dword| {
                try section.ensureUnusedCapacity(self.spv.gpa, 2);
                section.writeDoubleWord(dword);
            },
            .result_id => {
                maybe_result_id = self.spv.allocId();
                try section.ensureUnusedCapacity(self.spv.gpa, 1);
                section.writeOperand(IdResult, maybe_result_id.?);
            },
            .ref_id => |index| {
                const result = try self.resolveRef(index);
                try section.ensureUnusedCapacity(self.spv.gpa, 1);
                section.writeOperand(spec.IdRef, result.resultId(self.spv));
            },
            .string => |offset| {
                const text = std.mem.sliceTo(self.inst.string_bytes.items[offset..], 0);
                const size = std.math.divCeil(usize, text.len + 1, @sizeOf(Word)) catch unreachable;
                try section.ensureUnusedCapacity(self.spv.gpa, size);
                section.writeOperand(spec.LiteralString, text);
            },
        }
    }

    const actual_word_count = section.instructions.items.len - first_word;
    section.instructions.items[first_word] |= @as(u32, @intCast(u16, actual_word_count)) << 16 | @enumToInt(self.inst.opcode);

    if (maybe_result_id) |result| {
        return AsmValue{ .value = result };
    }
    return null;
}

/// Resolve a value reference. This function makes sure that the reference is
/// not self-referential, but it does allow the result to be forward declared.
fn resolveMaybeForwardRef(self: *Assembler, ref: AsmValue.Ref) !AsmValue {
    const value = self.value_map.values()[ref];
    switch (value) {
        .just_declared => {
            const name = self.value_map.keys()[ref];
            // TODO: Improve source location.
            return self.fail(0, "self-referential parameter %{s}", .{name});
        },
        else => return value,
    }
}

/// Resolve a value reference. This function
/// makes sure that the result is not self-referential, nor that it is forward declared.
fn resolveRef(self: *Assembler, ref: AsmValue.Ref) !AsmValue {
    const value = try self.resolveMaybeForwardRef(ref);
    switch (value) {
        .just_declared => unreachable,
        .unresolved_forward_reference => {
            const name = self.value_map.keys()[ref];
            // TODO: Improve source location.
            return self.fail(0, "reference to undeclared result-id %{s}", .{name});
        },
        else => return value,
    }
}

/// Resolve a value reference as type.
fn resolveTypeRef(self: *Assembler, ref: AsmValue.Ref) !SpvType.Ref {
    const value = try self.resolveRef(ref);
    switch (value) {
        .just_declared, .unresolved_forward_reference => unreachable,
        .ty => |ty_ref| return ty_ref,
        else => {
            const name = self.value_map.keys()[ref];
            // TODO: Improve source location.
            return self.fail(0, "expected operand %{s} to refer to a type", .{name});
        },
    }
}

/// Attempt to parse an instruction into `self.inst`.
/// If this function returns `error.AssembleFail`, an explanatory
/// error message has been emitted into `self.errors`.
fn parseInstruction(self: *Assembler) !void {
    self.inst.opcode = undefined;
    self.inst.operands.shrinkRetainingCapacity(0);
    self.inst.string_bytes.shrinkRetainingCapacity(0);

    const lhs_result_tok = self.currentToken();
    const maybe_lhs_result = if (self.eatToken(.result_id_assign)) blk: {
        const name = self.tokenText(lhs_result_tok)[1..];
        const entry = try self.value_map.getOrPut(self.gpa, name);
        try self.expectToken(.equals);
        if (!entry.found_existing) {
            entry.value_ptr.* = .just_declared;
        }
        break :blk @intCast(AsmValue.Ref, entry.index);
    } else null;

    const opcode_tok = self.currentToken();
    if (maybe_lhs_result != null) {
        try self.expectToken(.opcode);
    } else if (!self.eatToken(.opcode)) {
        return self.fail(opcode_tok.start, "expected start of instruction, found {s}", .{opcode_tok.tag.name()});
    }

    const opcode_text = self.tokenText(opcode_tok);
    @setEvalBranchQuota(10000);
    self.inst.opcode = std.meta.stringToEnum(Opcode, opcode_text) orelse {
        return self.fail(opcode_tok.start, "invalid opcode '{s}'", .{opcode_text});
    };

    const expected_operands = self.inst.opcode.operands();
    // This is a loop because the result-id is not always the first operand.
    const requires_lhs_result = for (expected_operands) |op| {
        if (op.kind == .IdResult) break true;
    } else false;

    if (requires_lhs_result and maybe_lhs_result == null) {
        return self.fail(opcode_tok.start, "opcode '{s}' expects result on left-hand side", .{@tagName(self.inst.opcode)});
    } else if (!requires_lhs_result and maybe_lhs_result != null) {
        return self.fail(
            lhs_result_tok.start,
            "opcode '{s}' does not expect a result-id on the left-hand side",
            .{@tagName(self.inst.opcode)},
        );
    }

    for (expected_operands) |operand| {
        if (operand.kind == .IdResult) {
            try self.inst.operands.append(self.gpa, .{ .result_id = maybe_lhs_result.? });
            continue;
        }

        switch (operand.quantifier) {
            .required => if (self.isAtInstructionBoundary()) {
                return self.fail(
                    self.currentToken().start,
                    "missing required operand", // TODO: Operand name?
                    .{},
                );
            } else {
                try self.parseOperand(operand.kind);
            },
            .optional => if (!self.isAtInstructionBoundary()) {
                try self.parseOperand(operand.kind);
            },
            .variadic => while (!self.isAtInstructionBoundary()) {
                try self.parseOperand(operand.kind);
            },
        }
    }
}

/// Parse a single operand of a particular type.
fn parseOperand(self: *Assembler, kind: spec.OperandKind) Error!void {
    switch (kind.category()) {
        .bit_enum => try self.parseBitEnum(kind),
        .value_enum => try self.parseValueEnum(kind),
        .id => try self.parseRefId(),
        else => switch (kind) {
            .LiteralInteger => try self.parseLiteralInteger(),
            .LiteralString => try self.parseString(),
            .LiteralContextDependentNumber => try self.parseContextDependentNumber(),
            .PairIdRefIdRef => try self.parsePhiSource(),
            else => return self.todo("parse operand of type {s}", .{@tagName(kind)}),
        },
    }
}

/// Also handles parsing any required extra operands.
fn parseBitEnum(self: *Assembler, kind: spec.OperandKind) !void {
    var tok = self.currentToken();
    try self.expectToken(.value);

    var text = self.tokenText(tok);
    if (std.mem.eql(u8, text, "None")) {
        try self.inst.operands.append(self.gpa, .{ .value = 0 });
        return;
    }

    const enumerants = kind.enumerants();
    var mask: u32 = 0;
    while (true) {
        const enumerant = for (enumerants) |enumerant| {
            if (std.mem.eql(u8, enumerant.name, text))
                break enumerant;
        } else {
            return self.fail(tok.start, "'{s}' is not a valid flag for bitmask {s}", .{ text, @tagName(kind) });
        };
        mask |= enumerant.value;
        if (!self.eatToken(.pipe))
            break;

        tok = self.currentToken();
        try self.expectToken(.value);
        text = self.tokenText(tok);
    }

    try self.inst.operands.append(self.gpa, .{ .value = mask });

    // Assume values are sorted.
    // TODO: ensure in generator.
    for (enumerants) |enumerant| {
        if ((mask & enumerant.value) == 0)
            continue;

        for (enumerant.parameters) |param_kind| {
            if (self.isAtInstructionBoundary()) {
                return self.fail(self.currentToken().start, "missing required parameter for bit flag '{s}'", .{enumerant.name});
            }

            try self.parseOperand(param_kind);
        }
    }
}

/// Also handles parsing any required extra operands.
fn parseValueEnum(self: *Assembler, kind: spec.OperandKind) !void {
    const tok = self.currentToken();
    try self.expectToken(.value);

    const text = self.tokenText(tok);
    const enumerant = for (kind.enumerants()) |enumerant| {
        if (std.mem.eql(u8, enumerant.name, text))
            break enumerant;
    } else {
        return self.fail(tok.start, "'{s}' is not a valid value for enumeration {s}", .{ text, @tagName(kind) });
    };

    try self.inst.operands.append(self.gpa, .{ .value = enumerant.value });

    for (enumerant.parameters) |param_kind| {
        if (self.isAtInstructionBoundary()) {
            return self.fail(self.currentToken().start, "missing required parameter for enum variant '{s}'", .{enumerant.name});
        }

        try self.parseOperand(param_kind);
    }
}

fn parseRefId(self: *Assembler) !void {
    const tok = self.currentToken();
    try self.expectToken(.result_id);

    const name = self.tokenText(tok)[1..];
    const entry = try self.value_map.getOrPut(self.gpa, name);
    if (!entry.found_existing) {
        entry.value_ptr.* = .unresolved_forward_reference;
    }

    const index = @intCast(AsmValue.Ref, entry.index);
    try self.inst.operands.append(self.gpa, .{ .ref_id = index });
}

fn parseLiteralInteger(self: *Assembler) !void {
    const tok = self.currentToken();
    try self.expectToken(.value);
    // According to the SPIR-V machine readable grammar, a LiteralInteger
    // may consist of one or more words. From the SPIR-V docs it seems like there
    // only one instruction where multiple words are allowed, the literals that make up the
    // switch cases of OpSwitch. This case is handled separately, and so we just assume
    // everything is a 32-bit integer in this function.
    const text = self.tokenText(tok);
    const value = std.fmt.parseInt(u32, text, 0) catch {
        return self.fail(tok.start, "'{s}' is not a valid 32-bit integer literal", .{text});
    };
    try self.inst.operands.append(self.gpa, .{ .literal32 = value });
}

fn parseString(self: *Assembler) !void {
    const tok = self.currentToken();
    try self.expectToken(.string);
    // Note, the string might not have a closing quote. In this case,
    // an error is already emitted but we are trying to continue processing
    // anyway, so in this function we have to deal with that situation.
    const text = self.tokenText(tok);
    assert(text.len > 0 and text[0] == '"');
    const literal = if (text.len != 1 and text[text.len - 1] == '"')
        text[1 .. text.len - 1]
    else
        text[1..];

    const string_offset = @intCast(u32, self.inst.string_bytes.items.len);
    try self.inst.string_bytes.ensureUnusedCapacity(self.gpa, literal.len + 1);
    self.inst.string_bytes.appendSliceAssumeCapacity(literal);
    self.inst.string_bytes.appendAssumeCapacity(0);

    try self.inst.operands.append(self.gpa, .{ .string = string_offset });
}

fn parseContextDependentNumber(self: *Assembler) !void {
    // For context dependent numbers, the actual type to parse is determined by the instruction.
    // Currently, this operand appears in OpConstant and OpSpecConstant, where the too-be-parsed type
    // is determined by the result type. That means that in this instructions we have to resolve the
    // operand type early and look at the result to see how we need to proceed.
    assert(self.inst.opcode == .OpConstant or self.inst.opcode == .OpSpecConstant);

    const tok = self.currentToken();
    const result_type_ref = try self.resolveTypeRef(self.inst.operands.items[0].ref_id);
    const result_type = self.spv.type_cache.keys()[@enumToInt(result_type_ref)];
    if (result_type.isInt()) {
        try self.parseContextDependentInt(result_type.intSignedness(), result_type.intFloatBits());
    } else if (result_type.isFloat()) {
        const width = result_type.intFloatBits();
        switch (width) {
            16 => try self.parseContextDependentFloat(16),
            32 => try self.parseContextDependentFloat(32),
            64 => try self.parseContextDependentFloat(64),
            else => return self.fail(tok.start, "cannot parse {}-bit float literal", .{width}),
        }
    } else {
        return self.fail(tok.start, "cannot parse literal constant {s}", .{@tagName(result_type.tag())});
    }
}

fn parseContextDependentInt(self: *Assembler, signedness: std.builtin.Signedness, width: u32) !void {
    const tok = self.currentToken();
    try self.expectToken(.value);

    if (width == 0 or width > 2 * @bitSizeOf(spec.Word)) {
        return self.fail(tok.start, "cannot parse {}-bit integer literal", .{width});
    }

    const text = self.tokenText(tok);
    invalid: {
        // Just parse the integer as the next larger integer type, and check if it overflows afterwards.
        const int = std.fmt.parseInt(i128, text, 0) catch break :invalid;
        const min = switch (signedness) {
            .unsigned => 0,
            .signed => -(@as(i128, 1) << (@intCast(u7, width) - 1)),
        };
        const max = (@as(i128, 1) << (@intCast(u7, width) - @boolToInt(signedness == .signed))) - 1;
        if (int < min or int > max) {
            break :invalid;
        }

        // Note, we store the sign-extended version here.
        if (width <= @bitSizeOf(spec.Word)) {
            try self.inst.operands.append(self.gpa, .{ .literal32 = @truncate(u32, @bitCast(u128, int)) });
        } else {
            try self.inst.operands.append(self.gpa, .{ .literal64 = @truncate(u64, @bitCast(u128, int)) });
        }
        return;
    }

    return self.fail(tok.start, "'{s}' is not a valid {s} {}-bit int literal", .{ text, @tagName(signedness), width });
}

fn parseContextDependentFloat(self: *Assembler, comptime width: u16) !void {
    const Float = std.meta.Float(width);
    const Int = std.meta.Int(.unsigned, width);

    const tok = self.currentToken();
    try self.expectToken(.value);

    const text = self.tokenText(tok);

    const value = std.fmt.parseFloat(Float, text) catch {
        return self.fail(tok.start, "'{s}' is not a valid {}-bit float literal", .{ text, width });
    };

    const float_bits = @bitCast(Int, value);
    if (width <= @bitSizeOf(spec.Word)) {
        try self.inst.operands.append(self.gpa, .{ .literal32 = float_bits });
    } else {
        assert(width <= 2 * @bitSizeOf(spec.Word));
        try self.inst.operands.append(self.gpa, .{ .literal64 = float_bits });
    }
}

fn parsePhiSource(self: *Assembler) !void {
    try self.parseRefId();
    if (self.isAtInstructionBoundary()) {
        return self.fail(self.currentToken().start, "missing phi block parent", .{});
    }
    try self.parseRefId();
}

/// Returns whether the `current_token` cursor is currently pointing
/// at the start of a new instruction.
fn isAtInstructionBoundary(self: Assembler) bool {
    return switch (self.currentToken().tag) {
        .opcode, .result_id_assign, .eof => true,
        else => false,
    };
}

fn expectToken(self: *Assembler, tag: Token.Tag) !void {
    if (self.eatToken(tag))
        return;

    return self.fail(self.currentToken().start, "unexpected {s}, expected {s}", .{
        self.currentToken().tag.name(),
        tag.name(),
    });
}

fn eatToken(self: *Assembler, tag: Token.Tag) bool {
    if (self.testToken(tag)) {
        self.current_token += 1;
        return true;
    }
    return false;
}

fn testToken(self: Assembler, tag: Token.Tag) bool {
    return self.currentToken().tag == tag;
}

fn currentToken(self: Assembler) Token {
    return self.tokens.items[self.current_token];
}

fn tokenText(self: Assembler, tok: Token) []const u8 {
    return self.src[tok.start..tok.end];
}

/// Tokenize `self.src` and put the tokens in `self.tokens`.
/// Any errors encountered are appended to `self.errors`.
fn tokenize(self: *Assembler) !void {
    var offset: u32 = 0;
    while (true) {
        const tok = try self.nextToken(offset);
        // Resolve result-id assignment now.
        // Note: If the previous token wasn't a result-id, just ignore it,
        // we will catch it while parsing.
        if (tok.tag == .equals and self.tokens.items[self.tokens.items.len - 1].tag == .result_id) {
            self.tokens.items[self.tokens.items.len - 1].tag = .result_id_assign;
        }
        try self.tokens.append(self.gpa, tok);
        if (tok.tag == .eof)
            break;
        offset = tok.end;
    }
}

/// Retrieve the next token from the input. This function will assert
/// that the token is surrounded by whitespace if required, but will not
/// interpret the token yet.
/// Note: This function doesn't handle .result_id_assign - this is handled in
/// tokenize().
fn nextToken(self: *Assembler, start_offset: u32) !Token {
    // We generally separate the input into the following types:
    // - Whitespace. Generally ignored, but also used as delimiter for some
    //   tokens.
    // - Values. This entails integers, floats, enums - anything that
    //   consists of alphanumeric characters, delimited by whitespace.
    // - Result-IDs. This entails anything that consists of alphanumeric characters and _, and
    //   starts with a %. In contrast to values, this entity can be checked for complete correctness
    //   relatively easily here.
    // - Strings. This entails quote-delimited text such as "abc".
    //   SPIR-V strings have only two escapes, \" and \\.
    // - Sigils, = and |. In this assembler, these are not required to have whitespace
    //   around them (they act as delimiters) as they do in SPIRV-Tools.

    var state: enum {
        start,
        value,
        result_id,
        string,
        string_end,
        escape,
    } = .start;
    var token_start = start_offset;
    var offset = start_offset;
    var tag = Token.Tag.eof;
    while (offset < self.src.len) : (offset += 1) {
        const c = self.src[offset];
        switch (state) {
            .start => switch (c) {
                ' ', '\t', '\r', '\n' => token_start = offset + 1,
                '"' => {
                    state = .string;
                    tag = .string;
                },
                '%' => {
                    state = .result_id;
                    tag = .result_id;
                },
                '|' => {
                    tag = .pipe;
                    offset += 1;
                    break;
                },
                '=' => {
                    tag = .equals;
                    offset += 1;
                    break;
                },
                else => {
                    state = .value;
                    tag = .value;
                },
            },
            .value => switch (c) {
                '"' => {
                    try self.addError(offset, "unexpected string literal", .{});
                    // The user most likely just forgot a delimiter here - keep
                    // the tag as value.
                    break;
                },
                ' ', '\t', '\r', '\n', '=', '|' => break,
                else => {},
            },
            .result_id => switch (c) {
                '_', 'a'...'z', 'A'...'Z', '0'...'9' => {},
                ' ', '\t', '\r', '\n', '=', '|' => break,
                else => {
                    try self.addError(offset, "illegal character in result-id", .{});
                    // Again, probably a forgotten delimiter here.
                    break;
                },
            },
            .string => switch (c) {
                '\\' => state = .escape,
                '"' => state = .string_end,
                else => {}, // Note, strings may include newlines
            },
            .string_end => switch (c) {
                ' ', '\t', '\r', '\n', '=', '|' => break,
                else => {
                    try self.addError(offset, "unexpected character after string literal", .{});
                    // The token is still unmistakibly a string.
                    break;
                },
            },
            // Escapes simply skip the next char.
            .escape => state = .string,
        }
    }

    var tok = Token{
        .tag = tag,
        .start = token_start,
        .end = offset,
    };

    switch (state) {
        .string, .escape => {
            try self.addError(token_start, "unterminated string", .{});
        },
        .result_id => if (offset - token_start == 1) {
            try self.addError(token_start, "result-id must have at least one name character", .{});
        },
        .value => {
            const text = self.tokenText(tok);
            const prefix = "Op";
            const looks_like_opcode = text.len > prefix.len and
                std.mem.startsWith(u8, text, prefix) and
                std.ascii.isUpper(text[prefix.len]);
            if (looks_like_opcode)
                tok.tag = .opcode;
        },
        else => {},
    }

    return tok;
}
