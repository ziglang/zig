//! Inline assembly parser for LoongArch.
//!
//! Global MIR refers to the MIR of the whole function.
//! Local MIR refers to the MIR of the current assembly block.
//! All MIR references, such as that in branch pseudo MIRs, are global
//! MIR indexes.

const std = @import("std");
const assert = std.debug.assert;
const log = std.log.scoped(.loongarch_asm);
const mem = std.mem;
const ascii = std.ascii;
const Allocator = mem.Allocator;
const Writer = std.Io.Writer;

const codegen = @import("../../codegen.zig");
const Zcu = @import("../../Zcu.zig");

const Mir = @import("Mir.zig");
const abi = @import("abi.zig");
const bits = @import("bits.zig");
const encoding = @import("encoding.zig");
const utils = @import("./utils.zig");
const Register = bits.Register;
const RegisterManager = abi.RegisterManager;
const RegisterLock = RegisterManager.RegisterLock;

const AsmParser = @This();

pt: Zcu.PerThread,
target: *const std.Target,
gpa: std.mem.Allocator,
register_manager: *RegisterManager,

err_msg: ?*Zcu.ErrorMsg = null,
src_loc: Zcu.LazySrcLoc,
/// The piece of assembly that is being parsed.
/// Setter must clear this field when the value is invalid.
asm_loc: ?[]const u8 = null,

output_len: usize,
input_len: usize,
clobber_len: usize,

/// All arguments, from outputs to inputs.
args: std.ArrayListUnmanaged(MCArg) = .empty,
/// Named arguments. Mapping from arg name to index.
arg_map: std.StringHashMapUnmanaged(usize) = .empty,
/// Register locks for clobbers.
clobber_locks: std.ArrayListUnmanaged(RegisterLock) = .empty,

/// Global MIR index of the first local MIR instruction.
mir_offset: Mir.Inst.Index,
/// Generated MIR instructions.
mir_insts: std.ArrayListUnmanaged(Mir.Inst) = .empty,

/// Labels in this assembly block.
labels: std.StringHashMapUnmanaged(Label) = .empty,

const InnerError = codegen.CodeGenError || error{ OutOfRegisters, AsmParseFail };

pub fn init(parser: *AsmParser) !void {
    try parser.args.ensureTotalCapacity(parser.gpa, parser.output_len + parser.input_len);
    try parser.arg_map.ensureTotalCapacity(parser.gpa, @intCast(parser.output_len + parser.input_len));
    try parser.clobber_locks.ensureTotalCapacity(parser.gpa, parser.clobber_len);
    // pre-allocate space for MIR instructions.
    // 32 is a randomly chosen number.
    try parser.mir_insts.ensureTotalCapacity(parser.gpa, 32);
}

pub fn deinit(parser: *AsmParser) void {
    parser.args.deinit(parser.gpa);
    parser.arg_map.deinit(parser.gpa);
    parser.clobber_locks.deinit(parser.gpa);
    parser.mir_insts.deinit(parser.gpa);

    var label_it = parser.labels.valueIterator();
    while (label_it.next()) |label| label.pending_relocs.deinit(parser.gpa);
    parser.labels.deinit(parser.gpa);

    parser.* = undefined;
}

/// Finalizes MC generation.
pub fn finalizeCodeGen(parser: *AsmParser) !void {
    for (parser.args.items) |*arg| {
        if (arg.reg_lock) |lock| {
            parser.register_manager.unlockReg(lock);
            arg.reg_lock = null;
        }
    }
    for (parser.clobber_locks.items) |lock| {
        parser.register_manager.unlockReg(lock);
    }
    parser.clobber_locks.clearAndFree(parser.gpa);

    var label_it = parser.labels.iterator();
    while (label_it.next()) |entry| {
        const label_name = entry.key_ptr.*;
        const label = entry.value_ptr;
        if (label.pending_relocs.items.len != 0)
            return parser.fail("label undefined: '{s}'", .{label_name});
    }
}

pub const MCValue = union(enum) {
    none,
    reg: Register,
    imm: i32,

    pub fn format(mcv: MCValue, writer: *Writer) Writer.Error!void {
        switch (mcv) {
            .none => try writer.print("(none)", .{}),
            .reg => |reg| try writer.print("{s}", .{@tagName(reg)}),
            .imm => |imm| try writer.print("imm:{}", .{imm}),
        }
    }
};

pub const MCArg = struct {
    value: MCValue,
    /// Register lock.
    /// For non-register values, this is always null.
    /// For outputs, null means the output does not require early-clobber and can be reused.
    /// For inputs, null means that it reuses an output register.
    reg_lock: ?RegisterManager.RegisterLock,

    pub fn format(mca: MCArg, writer: *Writer) Writer.Error!void {
        try writer.print("{f}", .{mca.value});
        if (mca.reg_lock != null)
            try writer.writeAll(" (locked)");
    }
};

fn fail(parser: *AsmParser, comptime format: []const u8, args: anytype) error{ OutOfMemory, AsmParseFail } {
    @branchHint(.cold);
    assert(parser.err_msg == null);
    parser.err_msg = try Zcu.ErrorMsg.create(parser.gpa, parser.src_loc, format, args);
    if (parser.asm_loc) |asm_loc| {
        const asm_str = mem.trim(u8, asm_loc, " \t\n");
        try parser.pt.zcu.errNote(parser.src_loc, parser.err_msg.?, "at '{s}'", .{asm_str});
    }
    return error.AsmParseFail;
}

inline fn hasFeature(parser: *AsmParser, feature: std.Target.loongarch.Feature) bool {
    return std.Target.loongarch.featureSetHas(parser.target.cpu.features, feature);
}

fn parseRegister(parser: *AsmParser, orig_name: []const u8) !?Register {
    if (orig_name.len < 2) return null;
    if (orig_name[0] == '$') return parseRegister(parser, orig_name[1..]);

    const name = try ascii.allocLowerString(parser.gpa, orig_name);
    defer parser.gpa.free(name);

    if (mem.eql(u8, name, "zero")) return .r0;
    if (mem.eql(u8, name, "ra")) return .r1;
    if (mem.eql(u8, name, "tp")) return .r2;
    if (mem.eql(u8, name, "sp")) return .r3;
    if (mem.eql(u8, name, "ert")) return .r21;
    if (mem.eql(u8, name, "fp")) return .r22;
    if (mem.eql(u8, name, "s9")) return .r22;

    if (name[0] == 'v' and !parser.hasFeature(.lsx)) return null;
    if (name[0] == 'x' and !parser.hasFeature(.lasx)) return null;

    const min_reg: Register, const max_reg: Register, const num_str: []const u8 = switch (name[0]) {
        'r' => .{ .r0, .r31, name[1..] },
        'f' => if (mem.startsWith(u8, name, "fcc"))
            .{ .fcc0, .fcc7, name[3..] }
        else if (mem.startsWith(u8, name, "fa"))
            .{ .f0, .f7, name[2..] }
        else if (mem.startsWith(u8, name, "ft"))
            .{ .f8, .f23, name[2..] }
        else if (mem.startsWith(u8, name, "fs"))
            .{ .f24, .f31, name[2..] }
        else
            .{ .f0, .f31, name[1..] },
        'v' => .{ .v0, .v31, name[1..] },
        'x' => .{ .x0, .x31, name[1..] },
        'a' => .{ .r4, .r11, name[1..] },
        't' => .{ .r12, .r20, name[1..] },
        's' => .{ .r23, .r31, name[1..] },
        else => return null,
    };
    const num = std.fmt.parseUnsigned(usize, num_str, 10) catch return null;
    const count: usize = @intCast(@intFromEnum(max_reg) - @intFromEnum(min_reg) + 1);
    if (num >= count) return null;
    return @enumFromInt(@intFromEnum(min_reg) + num);
}

/// Parses a constraint code.
/// This allocates needed registers and spills them, but does not lock them.
/// When is_input is set, 'r' constraints will prefer non-locked outputs.
fn parseConstraintCode(parser: *AsmParser, constraint: []u8, is_input: bool) !MCValue {
    // known registers
    if (constraint[0] == '{') {
        if (mem.indexOfScalar(u8, constraint, '}')) |end| {
            if (end != constraint.len - 1)
                return parser.fail("alternatives in assembly constraint code are not supported in Zig", .{});
        } else {
            return parser.fail("invalid register constraint: '{s}'", .{constraint});
        }
        const reg_name = constraint["{".len .. constraint.len - "}".len];
        if (try parser.parseRegister(reg_name)) |reg| {
            return .{ .reg = reg };
        } else {
            return parser.fail("invalid register: '{s}'", .{reg_name});
        }
    }
    // single-letter constraints
    if (constraint[0] == '^')
        return parser.fail("'^XX' assembly constraint code is a LLVM dialect and is not supported in Zig", .{});
    if (constraint.len != 1)
        return parser.fail("alternatives in assembly constraint code are not supported in Zig", .{});
    switch (constraint[0]) {
        'r' => {
            if (is_input) {
                for (parser.args.items[0..parser.output_len]) |*arg| {
                    switch (arg.value) {
                        .reg => |reg| {
                            if (arg.reg_lock == null) {
                                arg.reg_lock = parser.register_manager.lockReg(reg) orelse unreachable;
                            }
                        },
                        else => {},
                    }
                }
            }
            const reg = try parser.register_manager.allocReg(null, abi.getAllocatableRegSet(.int));
            return .{ .reg = reg };
        },
        'm' => return parser.fail("memory operand in assembly is not allowed in LoongArch", .{}),
        'i', 'n', 's' => return .{ .imm = 0 },
        'X' => return parser.fail("'X' constraints in assembly are not supported", .{}),
        else => return parser.fail("invalid constraint: '{s}'", .{constraint}),
    }
}

/// Parses a output constraint.
/// Locks the register if early clobber is required.
pub fn parseOutputConstraint(parser: *AsmParser, name: []u8, constraint: []u8) !void {
    if (constraint[0] == '=') return parser.parseOutputConstraint(name, constraint[1..]);
    parser.asm_loc = constraint;
    defer parser.asm_loc = null;

    const is_early_clobber = constraint[1] == '&';
    const constraint_code = constraint[@intFromBool(is_early_clobber)..];
    const mcv = try parser.parseConstraintCode(constraint_code, false);

    const reg_lock: ?RegisterManager.RegisterLock = lock: {
        if (is_early_clobber) {
            switch (mcv) {
                .reg => |reg| break :lock parser.register_manager.lockRegAssumeUnused(reg),
                else => {},
            }
        }
        break :lock null;
    };

    switch (mcv) {
        .none => unreachable,
        .imm => return parser.fail("immediate constraint cannot be used in output: '{s}'", .{constraint}),
        else => {},
    }

    if (!mem.eql(u8, name, "_"))
        parser.arg_map.putAssumeCapacityNoClobber(name, @intCast(parser.args.items.len));
    parser.args.appendAssumeCapacity(.{
        .value = mcv,
        .reg_lock = reg_lock,
    });
}

/// Parses a input constraint.
/// Locks the register immediately.
pub fn parseInputConstraint(parser: *AsmParser, name: []u8, constraint: []u8) !void {
    parser.asm_loc = constraint;
    defer parser.asm_loc = null;

    const mcv = mcv: {
        // output alias
        if (std.fmt.parseUnsigned(usize, constraint, 10)) |arg_i| {
            if (arg_i >= parser.args.items.len)
                return parser.fail("invalid output alias intput constraint: '{s}'", .{constraint});
            break :mcv parser.args.items[arg_i].value;
        }
        // constraint code
        break :mcv try parser.parseConstraintCode(constraint, true);
    };

    const reg_lock: ?RegisterManager.RegisterLock = switch (mcv) {
        .reg => |reg| parser.register_manager.lockReg(reg),
        else => null,
    };

    if (!mem.eql(u8, name, "_"))
        parser.arg_map.putAssumeCapacityNoClobber(name, @intCast(parser.args.items.len));
    parser.args.appendAssumeCapacity(.{
        .value = mcv,
        .reg_lock = reg_lock,
    });
}

/// Parses a clobber constraint and locks the register.
pub fn parseClobberConstraint(parser: *AsmParser, clobber: []u8) !void {
    parser.asm_loc = clobber;
    defer parser.asm_loc = null;

    if (std.mem.eql(u8, clobber, "")) return;
    if (std.mem.eql(u8, clobber, "cc")) return;
    if (std.mem.eql(u8, clobber, "memory")) return;
    if (std.mem.eql(u8, clobber, "redzone")) return;
    if (try parser.parseRegister(clobber)) |reg| {
        try parser.register_manager.getReg(reg, null);
        if (parser.register_manager.lockReg(reg)) |lock| {
            parser.clobber_locks.appendAssumeCapacity(lock);
        }
        return;
    }

    return parser.fail("invalid clobber: '{s}'", .{clobber});
}

/// Finalizes the constraint parsing phase.
/// This locks all unlocked regs in outputs and inputs.
pub fn finalizeConstraints(parser: *AsmParser) !void {
    log.debug("{f}", .{parser.fmtArgsAndClobbers()});
    // lock remaining output register
    // input registers are locked immediately after being parsed.
    for (parser.args.items[0..parser.output_len]) |*arg| {
        switch (arg.value) {
            .reg => |reg| {
                if (arg.reg_lock == null) {
                    arg.reg_lock = parser.register_manager.lockReg(reg) orelse unreachable;
                }
            },
            else => {},
        }
    }
}

fn formatArgs(parser: *AsmParser, writer: *Writer) Writer.Error!void {
    try writer.writeAll("Args:");
    for (parser.args.items, 0..) |*arg, arg_i| {
        try writer.print("\n  {} = {f}", .{ arg_i, arg });
        if (arg.reg_lock != null) try writer.writeAll(" (locked)");
    }
    var it = parser.arg_map.iterator();
    while (it.next()) |entry| try writer.print("\n  {s} = {}", .{ entry.key_ptr.*, entry.value_ptr.* });

    try writer.writeAll("\nClobber locks:");
    for (parser.clobber_locks.items) |*arg| {
        try writer.print(" {s}", .{@tagName(RegisterManager.regAtTrackedIndex(arg.tracked_index))});
    }
}
fn fmtArgsAndClobbers(parser: *AsmParser) std.fmt.Formatter(*AsmParser, formatArgs) {
    return .{ .data = parser };
}

const Label = struct {
    /// Local MIR index of the label.
    /// For anonymous labels, it refers to the backwards label.
    target: ?Mir.Inst.Index = null,
    /// Pending relocations, local MIR index.
    pending_relocs: std.ArrayListUnmanaged(Mir.Inst.Index) = .empty,

    const Kind = enum { definition, reference };

    fn isValid(kind: Kind, name: []const u8) bool {
        if (name.len == 0) return false;
        if (kind == .reference and Label.isAnonymousRef(name)) return true;
        if (kind == .definition and ascii.isDigit(name[0])) return Label.isAnonymousDef(name);
        for (name, 0..) |c, i| switch (c) {
            else => return false,
            '$' => if (i == 0) return false,
            '.', '0'...'9', '@', 'A'...'Z', '_', 'a'...'z' => {},
        };
        return true;
    }

    fn isAnonymousDef(name: []const u8) bool {
        if (name.len == 0) return false;
        for (name) |ch|
            if (!ascii.isDigit(ch)) return false;
        return true;
    }

    fn isAnonymousRef(name: []const u8) bool {
        if (name.len == 0) return false;
        for (name[0 .. name.len - 1]) |ch|
            if (!ascii.isDigit(ch)) return false;
        return switch (name[name.len - 1]) {
            else => false,
            'B', 'F', 'b', 'f' => true,
        };
    }
};

fn getLabel(parser: *AsmParser, label_name: []const u8) !*Label {
    const label_gop = try parser.labels.getOrPut(parser.gpa, label_name);
    if (!label_gop.found_existing) label_gop.value_ptr.* = .{};
    return label_gop.value_ptr;
}

pub fn parseSource(parser: *AsmParser, source: []const u8) !void {
    var line_it = mem.tokenizeAny(u8, source, "\n\r;");
    while (line_it.next()) |line| try parser.parseLine(line);
}

pub fn parseLine(parser: *AsmParser, line: []const u8) !void {
    parser.asm_loc = line;
    defer parser.asm_loc = null;

    var line_it = mem.tokenizeAny(u8, line, " \t");
    const mnemonic: []const u8 = while (line_it.next()) |mnemonic_str| {
        if (mem.startsWith(u8, mnemonic_str, "#")) return;
        if (mem.startsWith(u8, mnemonic_str, "//")) return;
        if (mem.endsWith(u8, mnemonic_str, ":")) {
            try parser.parseLabel(mnemonic_str[0 .. mnemonic_str.len - ":".len]);
            continue;
        }
        break mnemonic_str;
    } else return;
    var op_it = OperandIterator.init(parser, line_it.rest());
    const inst = try parser.parseInst(mnemonic, &op_it);

    if (!op_it.isEnd())
        return parser.fail("excessive operand: '{s}'", .{op_it.iter.next().?});

    log.debug("  | {}: {f}", .{ parser.mir_insts.items.len, inst });
    try parser.mir_insts.append(parser.gpa, inst);
}

fn parseLabel(parser: *AsmParser, label_name: []const u8) !void {
    if (!Label.isValid(.definition, label_name))
        return parser.fail("invalid label: '{s}'", .{label_name});

    const anon = Label.isAnonymousDef(label_name);
    if (anon)
        log.debug("  | label {s} (anonymous):", .{label_name})
    else
        log.debug("  | label {s}:", .{label_name});

    const label_gop = try parser.labels.getOrPut(parser.gpa, label_name);
    if (!label_gop.found_existing) label_gop.value_ptr.* = .{} else {
        const label = label_gop.value_ptr;

        if (!anon and label.target != null)
            return parser.fail("redefined label: '{s}'", .{label_name});

        for (label.pending_relocs.items) |pending_reloc|
            parser.performReloc(pending_reloc);

        if (anon)
            label.pending_relocs.clearRetainingCapacity()
        else
            label.pending_relocs.clearAndFree(parser.gpa);
    }
    label_gop.value_ptr.target = @intCast(parser.mir_insts.items.len);
}

fn performReloc(parser: *AsmParser, reloc: Mir.Inst.Index) void {
    log.debug("  | <-- reloc {}", .{reloc});

    const next_inst: u32 = @intCast(parser.mir_insts.items.len);
    const inst = &parser.mir_insts.items[reloc];
    switch (inst.tag.unwrap()) {
        .inst => unreachable,
        .pseudo => |tag| {
            switch (tag) {
                .branch => inst.data.br.inst = parser.mir_offset + next_inst,
                else => unreachable,
            }
        },
    }
}

const OperandIterator = struct {
    parser: *AsmParser,
    iter: mem.SplitIterator(u8, .any),

    fn init(parser: *AsmParser, ops: []const u8) OperandIterator {
        return .{
            .parser = parser,
            .iter = mem.splitAny(u8, ops, ",("),
        };
    }

    fn isEnd(it: *OperandIterator) bool {
        return it.iter.peek() == null;
    }

    fn next(it: *OperandIterator) ?[]const u8 {
        if (it.iter.next()) |op| {
            return std.mem.trim(u8, op, " \t");
        } else {
            return null;
        }
    }

    fn resolveArg(it: *OperandIterator, tmpl: []const u8) !?*MCValue {
        if (tmpl.len < 2)
            return null;
        if (tmpl[0] == '%') {
            if (tmpl[1] == '[' and tmpl[tmpl.len - 1] == ']') {
                const arg_name = tmpl[2..][0 .. tmpl.len - 3];
                if (it.parser.arg_map.get(arg_name)) |arg_i| {
                    return &it.parser.args.items[arg_i].value;
                } else {
                    return it.parser.fail("undefined named assembly argument: '{s}'", .{tmpl});
                }
            } else if (std.fmt.parseInt(usize, tmpl[1..], 10) catch null) |arg_i| {
                if (arg_i < it.parser.args.items.len) {
                    return &it.parser.args.items[arg_i].value;
                } else {
                    return it.parser.fail("undefined assembly argument: '{s}'", .{tmpl});
                }
            }
        }
        return null;
    }

    fn nextReg(it: *OperandIterator) !Register {
        if (it.next()) |name| {
            if (try it.resolveArg(name)) |mcv| {
                switch (mcv.*) {
                    .reg => |reg| return reg,
                    else => return it.parser.fail("argument is not a register: '{s}'", .{name}),
                }
            } else if (try it.parser.parseRegister(name)) |reg| {
                return reg;
            } else {
                return it.parser.fail("invalid register operand: '{s}'", .{name});
            }
        } else return it.parser.fail("missing register operand", .{});
    }

    fn tryNextReg(it: *OperandIterator) !?Register {
        return if (it.next()) |name| {
            if (try it.resolveArg(name)) |mcv| {
                switch (mcv.*) {
                    .reg => |reg| reg,
                    else => null,
                }
            } else try it.parser.parseRegister(name);
        } else null;
    }

    fn nextImm(it: *OperandIterator, T: type) !T {
        if (it.next()) |imm_str| {
            if (try it.resolveArg(imm_str)) |mcv| {
                switch (mcv.*) {
                    .imm => |imm| {
                        if (std.math.cast(T, imm)) |imm_cast| {
                            return imm_cast;
                        } else {
                            return it.parser.fail("immediate argument cannot fit into " ++ @typeName(T) ++ ": '{s}'", .{imm_str});
                        }
                    },
                    else => return it.parser.fail("argument is not an immediate: '{s}'", .{imm_str}),
                }
            } else return std.fmt.parseInt(T, imm_str, 0) catch |err| switch (err) {
                error.Overflow => return it.parser.fail("immediate operand cannot fit into " ++ @typeName(T) ++ ": '{s}'", .{imm_str}),
                error.InvalidCharacter => return it.parser.fail("invalid " ++ @typeName(T) ++ " operand: '{s}'", .{imm_str}),
            };
        } else return it.parser.fail("missing " ++ @typeName(T) ++ " operand", .{});
    }

    fn tryNextImm(it: *OperandIterator, T: type) ?T {
        if (it.next()) |imm_str| {
            if (try it.resolveArg(imm_str)) |mcv| {
                return switch (mcv.*) {
                    .imm => |imm| {
                        if (std.math.cast(T, imm)) |imm_cast|
                            imm_cast
                        else
                            null;
                    },
                    else => null,
                };
            } else return std.fmt.parseInt(T, imm_str, 0) catch null;
        } else return null;
    }
};

fn parseInst(parser: *AsmParser, mnemonic: []const u8, ops: *OperandIterator) !Mir.Inst {
    @setEvalBranchQuota(3_000);
    // find override matchers
    inline for (@typeInfo(instToMatcher).@"struct".decls) |decl| {
        if (mnemonicEql(decl.name, mnemonic)) {
            const matcher = @field(instToMatcher, decl.name);
            switch (@typeInfo(@TypeOf(matcher))) {
                .@"fn" => return matcher(decl.name, ops),
                .enum_literal => return InstMatcher.default(ops, @tagName(matcher)),
                else => unreachable,
            }
        }
    }

    // find default matchers
    inline for (@typeInfo(encoding.Inst).@"struct".decls) |decl| {
        // check blocklist
        if (@hasField(defaultMatcherBlocklist, decl.name)) continue;
        // check name
        if (mnemonicEql(decl.name, mnemonic))
            return InstMatcher.default(ops, decl.name);
    }

    return parser.fail("invalid mnemonic: '{s}'", .{mnemonic});
}

fn mnemonicEql(mnemonic: []const u8, src: []const u8) bool {
    if (mnemonic.len != src.len) return false;
    for (mnemonic, 0..) |ch, i| {
        const src_ch = src[i];
        if (ch == '_' and (src_ch == '_' or src_ch == '.')) continue;
        if (ch != ascii.toLower(src_ch)) return false;
    }
    return true;
}

const InstMatcher = struct {
    fn default(op_iter: *OperandIterator, comptime decl_name: []const u8) !Mir.Inst {
        const gen_fn = @field(encoding.Inst, decl_name);

        const ops_ty = std.meta.ArgsTuple(@TypeOf(gen_fn));
        var ops: ops_ty = undefined;
        inline for (std.meta.fields(ops_ty)) |op| {
            const op_ty = op.type;
            if (op_ty == Register) {
                @field(ops, op.name) = try op_iter.nextReg();
            } else {
                const op_ty_info = @typeInfo(op_ty);
                switch (op_ty_info) {
                    .int => {
                        @field(ops, op.name) = try op_iter.nextImm(op_ty);
                    },
                    else => unreachable,
                }
            }
        }

        // Workaround https://github.com/ziglang/zig/issues/24127
        const inst: encoding.Inst = @call(.auto, gen_fn, ops);
        return .initInst(inst);
    }

    pub fn bstr_w(decl_name: []const u8, ops: *OperandIterator) !Mir.Inst {
        const op: encoding.OpCode = if (mem.eql(u8, decl_name, "bstrins_w")) .bstrins_w else .bstrpick_w;
        const rd = try ops.nextReg();
        const rj = try ops.nextReg();
        const msbw = try ops.nextImm(u5);
        const lsbw = try ops.nextImm(u5);
        return .initInst(.{
            .opcode = op,
            .data = .{ .DJUk5Um5 = .{ rd, rj, lsbw, msbw } },
        });
    }

    pub fn bstr_d(decl_name: []const u8, ops: *OperandIterator) !Mir.Inst {
        const op: encoding.OpCode = if (mem.eql(u8, decl_name, "bstrins_d")) .bstrins_d else .bstrpick_d;
        const rd = try ops.nextReg();
        const rj = try ops.nextReg();
        const msbw = try ops.nextImm(u6);
        const lsbw = try ops.nextImm(u6);
        return .initInst(.{
            .opcode = op,
            .data = .{ .DJUk6Um6 = .{ rd, rj, lsbw, msbw } },
        });
    }

    pub fn csrxchg(_: []const u8, ops: *OperandIterator) !Mir.Inst {
        const rd = try ops.nextReg();
        const rj = try ops.nextReg();
        const csr_num = try ops.nextImm(u14);
        if (rj == .r0 or rj == .r1)
            return ops.parser.fail("r0 and r1 cannot be used as rj for CSRXCHG", .{});
        return .initInst(.csrxchg(rd, rj, csr_num));
    }

    pub fn cacop(_: []const u8, ops: *OperandIterator) !Mir.Inst {
        const code = try ops.nextImm(u5);
        const rj = try ops.nextReg();
        const si12 = try ops.nextImm(i12);
        return .initInst(.cacop(rj, code, si12));
    }

    pub fn invtlb(_: []const u8, ops: *OperandIterator) !Mir.Inst {
        const op = try ops.nextImm(u5);
        const rj = try ops.nextReg();
        const rk = try ops.nextReg();
        return .initInst(.tlbinv(rj, rk, op));
    }

    pub fn preld(decl_name: []const u8, ops: *OperandIterator) !Mir.Inst {
        const op: encoding.OpCode = if (mem.eql(u8, decl_name, "preld")) .preld else .preldx;
        const hint = try ops.nextImm(u5);
        const rj = try ops.nextReg();
        const si12 = try ops.nextImm(i12);
        return .initInst(.{
            .opcode = op,
            .data = .{ .JUd5Sk12 = .{ rj, hint, si12 } },
        });
    }
};

/// Maps mnemonics to custom matchers.
const instToMatcher = struct {
    pub const bstrins_w = InstMatcher.bstr_w;
    pub const bstrpick_w = InstMatcher.bstr_w;
    pub const bstrins_d = InstMatcher.bstr_d;
    pub const bstrpick_d = InstMatcher.bstr_d;
    pub const csrxchg = InstMatcher.csrxchg;
    pub const cacop = InstMatcher.cacop;
    pub const invtlb = InstMatcher.invtlb;
    pub const tlbinv = InstMatcher.invtlb;
    pub const preld = InstMatcher.preld;
    pub const preldx = InstMatcher.preld;
    // pub const b = InstMatcher.branch;
    // pub const bl = InstMatcher.branch;
    // pub const beqz = InstMatcher.cond_br_zero;
    // pub const bnez = InstMatcher.cond_br_zero;
    // pub const bceqz = InstMatcher.fcc_cond_br;
    // pub const bcnez = InstMatcher.fcc_cond_br;

    pub const dbcl = .dbgcall;
    pub const ertn = .eret;
    pub const pcaddi = .pcaddu2i;

    pub const ext_w_b = .sext_b;
    pub const ext_w_h = .sext_h;

    pub const ldptr_w = .ldox4_w;
    pub const ldptr_d = .ldox4_d;

    pub const stptr_w = .stox4_w;
    pub const stptr_d = .stox4_d;

    pub const bitrev_w = .revbit_w;
    pub const bitrev_d = .revbit_d;
    pub const bitrev_4b = .revbit_4b;
    pub const bitrev_8b = .revbit_8b;

    pub const asrtle_d = .asrtle;
    pub const asrtgt_d = .asrtgt;

    pub const lu32i_d = .cu32i_d;
    pub const lu52i = .cu52i_d;

    pub const alsl_w = .sladd_w;
    pub const alsl_wu = .sladd_wu;
    pub const alsl_d = .sladd_d;

    pub const bytepick_w = .catpick_w;
    pub const bytepick_d = .catpick_d;
};

/// Mnemonics that will not have auto-generated matcher.
const defaultMatcherBlocklist = enum {
    b,
    bl,
    beqz,
    bnez,
    bceqz,
    bcnez,
    bgt,
    bgtu,
    ble,
    bleu,
};
