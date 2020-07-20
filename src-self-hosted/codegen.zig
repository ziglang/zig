const std = @import("std");
const mem = std.mem;
const assert = std.debug.assert;
const ir = @import("ir.zig");
const Type = @import("type.zig").Type;
const Value = @import("value.zig").Value;
const TypedValue = @import("TypedValue.zig");
const link = @import("link.zig");
const Module = @import("Module.zig");
const ErrorMsg = Module.ErrorMsg;
const Target = std.Target;
const Allocator = mem.Allocator;
const trace = @import("tracy.zig").trace;

/// The codegen-related data that is stored in `ir.Inst.Block` instructions.
pub const BlockData = struct {
    relocs: std.ArrayListUnmanaged(Reloc) = .{},
};

pub const Reloc = union(enum) {
    /// The value is an offset into the `Function` `code` from the beginning.
    /// To perform the reloc, write 32-bit signed little-endian integer
    /// which is a relative jump, based on the address following the reloc.
    rel32: usize,
};

pub const Result = union(enum) {
    /// The `code` parameter passed to `generateSymbol` has the value appended.
    appended: void,
    /// The value is available externally, `code` is unused.
    externally_managed: []const u8,
    fail: *Module.ErrorMsg,
};

pub fn generateSymbol(
    bin_file: *link.File.Elf,
    src: usize,
    typed_value: TypedValue,
    code: *std.ArrayList(u8),
) error{
    OutOfMemory,
    /// A Decl that this symbol depends on had a semantic analysis failure.
    AnalysisFail,
}!Result {
    const tracy = trace(@src());
    defer tracy.end();

    switch (typed_value.ty.zigTypeTag()) {
        .Fn => {
            const module_fn = typed_value.val.cast(Value.Payload.Function).?.func;

            const fn_type = module_fn.owner_decl.typed_value.most_recent.typed_value.ty;
            const param_types = try bin_file.allocator.alloc(Type, fn_type.fnParamLen());
            defer bin_file.allocator.free(param_types);
            fn_type.fnParamTypes(param_types);
            var mc_args = try bin_file.allocator.alloc(MCValue, param_types.len);
            defer bin_file.allocator.free(mc_args);

            var branch_stack = std.ArrayList(Function.Branch).init(bin_file.allocator);
            defer {
                assert(branch_stack.items.len == 1);
                branch_stack.items[0].deinit(bin_file.allocator);
                branch_stack.deinit();
            }
            const branch = try branch_stack.addOne();
            branch.* = .{};

            var function = Function{
                .gpa = bin_file.allocator,
                .target = &bin_file.options.target,
                .bin_file = bin_file,
                .mod_fn = module_fn,
                .code = code,
                .err_msg = null,
                .args = mc_args,
                .arg_index = 0,
                .branch_stack = &branch_stack,
                .src = src,
            };

            const cc = fn_type.fnCallingConvention();
            branch.max_end_stack = function.resolveParameters(src, cc, param_types, mc_args) catch |err| switch (err) {
                error.CodegenFail => return Result{ .fail = function.err_msg.? },
                else => |e| return e,
            };

            function.gen() catch |err| switch (err) {
                error.CodegenFail => return Result{ .fail = function.err_msg.? },
                else => |e| return e,
            };

            if (function.err_msg) |em| {
                return Result{ .fail = em };
            } else {
                return Result{ .appended = {} };
            }
        },
        .Array => {
            if (typed_value.val.cast(Value.Payload.Bytes)) |payload| {
                if (typed_value.ty.arraySentinel()) |sentinel| {
                    try code.ensureCapacity(code.items.len + payload.data.len + 1);
                    code.appendSliceAssumeCapacity(payload.data);
                    const prev_len = code.items.len;
                    switch (try generateSymbol(bin_file, src, .{
                        .ty = typed_value.ty.elemType(),
                        .val = sentinel,
                    }, code)) {
                        .appended => return Result{ .appended = {} },
                        .externally_managed => |slice| {
                            code.appendSliceAssumeCapacity(slice);
                            return Result{ .appended = {} };
                        },
                        .fail => |em| return Result{ .fail = em },
                    }
                } else {
                    return Result{ .externally_managed = payload.data };
                }
            }
            return Result{
                .fail = try ErrorMsg.create(
                    bin_file.allocator,
                    src,
                    "TODO implement generateSymbol for more kinds of arrays",
                    .{},
                ),
            };
        },
        .Pointer => {
            if (typed_value.val.cast(Value.Payload.DeclRef)) |payload| {
                const decl = payload.decl;
                if (decl.analysis != .complete) return error.AnalysisFail;
                assert(decl.link.local_sym_index != 0);
                // TODO handle the dependency of this symbol on the decl's vaddr.
                // If the decl changes vaddr, then this symbol needs to get regenerated.
                const vaddr = bin_file.local_symbols.items[decl.link.local_sym_index].st_value;
                const endian = bin_file.options.target.cpu.arch.endian();
                switch (bin_file.ptr_width) {
                    .p32 => {
                        try code.resize(4);
                        mem.writeInt(u32, code.items[0..4], @intCast(u32, vaddr), endian);
                    },
                    .p64 => {
                        try code.resize(8);
                        mem.writeInt(u64, code.items[0..8], vaddr, endian);
                    },
                }
                return Result{ .appended = {} };
            }
            return Result{
                .fail = try ErrorMsg.create(
                    bin_file.allocator,
                    src,
                    "TODO implement generateSymbol for pointer {}",
                    .{typed_value.val},
                ),
            };
        },
        .Int => {
            const info = typed_value.ty.intInfo(bin_file.options.target);
            if (info.bits == 8 and !info.signed) {
                const x = typed_value.val.toUnsignedInt();
                try code.append(@intCast(u8, x));
                return Result{ .appended = {} };
            }
            return Result{
                .fail = try ErrorMsg.create(
                    bin_file.allocator,
                    src,
                    "TODO implement generateSymbol for int type '{}'",
                    .{typed_value.ty},
                ),
            };
        },
        else => |t| {
            return Result{
                .fail = try ErrorMsg.create(
                    bin_file.allocator,
                    src,
                    "TODO implement generateSymbol for type '{}'",
                    .{@tagName(t)},
                ),
            };
        },
    }
}

const InnerError = error{
    OutOfMemory,
    CodegenFail,
};

const MCValue = union(enum) {
    /// No runtime bits. `void` types, empty structs, u0, enums with 1 tag, etc.
    none,
    /// Control flow will not allow this value to be observed.
    unreach,
    /// No more references to this value remain.
    dead,
    /// A pointer-sized integer that fits in a register.
    immediate: u64,
    /// The constant was emitted into the code, at this offset.
    embedded_in_code: usize,
    /// The value is in a target-specific register. The value can
    /// be @intToEnum casted to the respective Reg enum.
    register: usize,
    /// The value is in memory at a hard-coded address.
    memory: u64,
    /// The value is one of the stack variables.
    stack_offset: u64,
    /// The value is in the compare flags assuming an unsigned operation,
    /// with this operator applied on top of it.
    compare_flags_unsigned: std.math.CompareOperator,
    /// The value is in the compare flags assuming a signed operation,
    /// with this operator applied on top of it.
    compare_flags_signed: std.math.CompareOperator,

    fn isMemory(mcv: MCValue) bool {
        return switch (mcv) {
            .embedded_in_code, .memory, .stack_offset => true,
            else => false,
        };
    }

    fn isImmediate(mcv: MCValue) bool {
        return switch (mcv) {
            .immediate => true,
            else => false,
        };
    }

    fn isMutable(mcv: MCValue) bool {
        return switch (mcv) {
            .none => unreachable,
            .unreach => unreachable,
            .dead => unreachable,

            .immediate,
            .embedded_in_code,
            .memory,
            .compare_flags_unsigned,
            .compare_flags_signed,
            => false,

            .register,
            .stack_offset,
            => true,
        };
    }
};

const Function = struct {
    gpa: *Allocator,
    bin_file: *link.File.Elf,
    target: *const std.Target,
    mod_fn: *const Module.Fn,
    code: *std.ArrayList(u8),
    err_msg: ?*ErrorMsg,
    args: []MCValue,
    arg_index: usize,
    src: usize,

    /// Whenever there is a runtime branch, we push a Branch onto this stack,
    /// and pop it off when the runtime branch joins. This provides an "overlay"
    /// of the table of mappings from instructions to `MCValue` from within the branch.
    /// This way we can modify the `MCValue` for an instruction in different ways
    /// within different branches. Special consideration is needed when a branch
    /// joins with its parent, to make sure all instructions have the same MCValue
    /// across each runtime branch upon joining.
    branch_stack: *std.ArrayList(Branch),

    const Branch = struct {
        inst_table: std.AutoHashMapUnmanaged(*ir.Inst, MCValue) = .{},

        /// The key is an enum value of an arch-specific register.
        registers: std.AutoHashMapUnmanaged(usize, RegisterAllocation) = .{},

        /// Maps offset to what is stored there.
        stack: std.AutoHashMapUnmanaged(usize, StackAllocation) = .{},
        /// Offset from the stack base, representing the end of the stack frame.
        max_end_stack: u32 = 0,
        /// Represents the current end stack offset. If there is no existing slot
        /// to place a new stack allocation, it goes here, and then bumps `max_end_stack`.
        next_stack_offset: u32 = 0,

        fn deinit(self: *Branch, gpa: *Allocator) void {
            self.inst_table.deinit(gpa);
            self.registers.deinit(gpa);
            self.stack.deinit(gpa);
            self.* = undefined;
        }
    };

    const RegisterAllocation = struct {
        inst: *ir.Inst,
    };

    const StackAllocation = struct {
        inst: *ir.Inst,
        size: u32,
    };

    fn gen(self: *Function) !void {
        switch (self.target.cpu.arch) {
            .arm => return self.genArch(.arm),
            .armeb => return self.genArch(.armeb),
            .aarch64 => return self.genArch(.aarch64),
            .aarch64_be => return self.genArch(.aarch64_be),
            .aarch64_32 => return self.genArch(.aarch64_32),
            .arc => return self.genArch(.arc),
            .avr => return self.genArch(.avr),
            .bpfel => return self.genArch(.bpfel),
            .bpfeb => return self.genArch(.bpfeb),
            .hexagon => return self.genArch(.hexagon),
            .mips => return self.genArch(.mips),
            .mipsel => return self.genArch(.mipsel),
            .mips64 => return self.genArch(.mips64),
            .mips64el => return self.genArch(.mips64el),
            .msp430 => return self.genArch(.msp430),
            .powerpc => return self.genArch(.powerpc),
            .powerpc64 => return self.genArch(.powerpc64),
            .powerpc64le => return self.genArch(.powerpc64le),
            .r600 => return self.genArch(.r600),
            .amdgcn => return self.genArch(.amdgcn),
            .riscv32 => return self.genArch(.riscv32),
            .riscv64 => return self.genArch(.riscv64),
            .sparc => return self.genArch(.sparc),
            .sparcv9 => return self.genArch(.sparcv9),
            .sparcel => return self.genArch(.sparcel),
            .s390x => return self.genArch(.s390x),
            .tce => return self.genArch(.tce),
            .tcele => return self.genArch(.tcele),
            .thumb => return self.genArch(.thumb),
            .thumbeb => return self.genArch(.thumbeb),
            .i386 => return self.genArch(.i386),
            .x86_64 => return self.genArch(.x86_64),
            .xcore => return self.genArch(.xcore),
            .nvptx => return self.genArch(.nvptx),
            .nvptx64 => return self.genArch(.nvptx64),
            .le32 => return self.genArch(.le32),
            .le64 => return self.genArch(.le64),
            .amdil => return self.genArch(.amdil),
            .amdil64 => return self.genArch(.amdil64),
            .hsail => return self.genArch(.hsail),
            .hsail64 => return self.genArch(.hsail64),
            .spir => return self.genArch(.spir),
            .spir64 => return self.genArch(.spir64),
            .kalimba => return self.genArch(.kalimba),
            .shave => return self.genArch(.shave),
            .lanai => return self.genArch(.lanai),
            .wasm32 => return self.genArch(.wasm32),
            .wasm64 => return self.genArch(.wasm64),
            .renderscript32 => return self.genArch(.renderscript32),
            .renderscript64 => return self.genArch(.renderscript64),
            .ve => return self.genArch(.ve),
        }
    }

    fn genArch(self: *Function, comptime arch: std.Target.Cpu.Arch) !void {
        try self.code.ensureCapacity(self.code.items.len + 11);

        // push rbp
        // mov rbp, rsp
        self.code.appendSliceAssumeCapacity(&[_]u8{ 0x55, 0x48, 0x89, 0xe5 });

        // sub rsp, x
        const stack_end = self.branch_stack.items[0].max_end_stack;
        if (stack_end > std.math.maxInt(i32)) {
            return self.fail(self.src, "too much stack used in call parameters", .{});
        } else if (stack_end > std.math.maxInt(i8)) {
            // 48 83 ec xx    sub rsp,0x10
            self.code.appendSliceAssumeCapacity(&[_]u8{ 0x48, 0x81, 0xec });
            const x = @intCast(u32, stack_end);
            mem.writeIntLittle(u32, self.code.addManyAsArrayAssumeCapacity(4), x);
        } else if (stack_end != 0) {
            // 48 81 ec xx xx xx xx   sub rsp,0x80
            const x = @intCast(u8, stack_end);
            self.code.appendSliceAssumeCapacity(&[_]u8{ 0x48, 0x83, 0xec, x });
        }

        try self.genBody(self.mod_fn.analysis.success, arch);
    }

    fn genBody(self: *Function, body: ir.Body, comptime arch: std.Target.Cpu.Arch) InnerError!void {
        const inst_table = &self.branch_stack.items[0].inst_table;
        for (body.instructions) |inst| {
            const new_inst = try self.genFuncInst(inst, arch);
            try inst_table.putNoClobber(self.gpa, inst, new_inst);
        }
    }

    fn genFuncInst(self: *Function, inst: *ir.Inst, comptime arch: std.Target.Cpu.Arch) !MCValue {
        switch (inst.tag) {
            .add => return self.genAdd(inst.cast(ir.Inst.Add).?, arch),
            .arg => return self.genArg(inst.cast(ir.Inst.Arg).?),
            .assembly => return self.genAsm(inst.cast(ir.Inst.Assembly).?, arch),
            .bitcast => return self.genBitCast(inst.cast(ir.Inst.BitCast).?),
            .block => return self.genBlock(inst.cast(ir.Inst.Block).?, arch),
            .br => return self.genBr(inst.cast(ir.Inst.Br).?, arch),
            .breakpoint => return self.genBreakpoint(inst.src, arch),
            .brvoid => return self.genBrVoid(inst.cast(ir.Inst.BrVoid).?, arch),
            .call => return self.genCall(inst.cast(ir.Inst.Call).?, arch),
            .cmp => return self.genCmp(inst.cast(ir.Inst.Cmp).?, arch),
            .condbr => return self.genCondBr(inst.cast(ir.Inst.CondBr).?, arch),
            .constant => unreachable, // excluded from function bodies
            .isnonnull => return self.genIsNonNull(inst.cast(ir.Inst.IsNonNull).?, arch),
            .isnull => return self.genIsNull(inst.cast(ir.Inst.IsNull).?, arch),
            .ptrtoint => return self.genPtrToInt(inst.cast(ir.Inst.PtrToInt).?),
            .ret => return self.genRet(inst.cast(ir.Inst.Ret).?, arch),
            .retvoid => return self.genRetVoid(inst.cast(ir.Inst.RetVoid).?, arch),
            .sub => return self.genSub(inst.cast(ir.Inst.Sub).?, arch),
            .unreach => return MCValue{ .unreach = {} },
            .not => return self.genNot(inst.cast(ir.Inst.Not).?, arch),
        }
    }

    fn genNot(self: *Function, inst: *ir.Inst.Not, comptime arch: std.Target.Cpu.Arch) !MCValue {
        // No side effects, so if it's unreferenced, do nothing.
        if (inst.base.isUnused())
            return MCValue.dead;
        const operand = try self.resolveInst(inst.args.operand);
        switch (operand) {
            .dead => unreachable,
            .unreach => unreachable,
            .compare_flags_unsigned => |op| return MCValue{
                .compare_flags_unsigned = switch (op) {
                    .gte => .lt,
                    .gt => .lte,
                    .neq => .eq,
                    .lt => .gte,
                    .lte => .gt,
                    .eq => .neq,
                },
            },
            .compare_flags_signed => |op| return MCValue{
                .compare_flags_signed = switch (op) {
                    .gte => .lt,
                    .gt => .lte,
                    .neq => .eq,
                    .lt => .gte,
                    .lte => .gt,
                    .eq => .neq,
                },
            },
            else => {},
        }

        switch (arch) {
            .x86_64 => {
                var imm = ir.Inst.Constant{
                    .base = .{
                        .tag = .constant,
                        .deaths = 0,
                        .ty = inst.args.operand.ty,
                        .src = inst.args.operand.src,
                    },
                    .val = Value.initTag(.bool_true),
                };
                return try self.genX8664BinMath(&inst.base, inst.args.operand, &imm.base, 6, 0x30);
            },
            else => return self.fail(inst.base.src, "TODO implement NOT for {}", .{self.target.cpu.arch}),
        }
    }

    fn genAdd(self: *Function, inst: *ir.Inst.Add, comptime arch: std.Target.Cpu.Arch) !MCValue {
        // No side effects, so if it's unreferenced, do nothing.
        if (inst.base.isUnused())
            return MCValue.dead;
        switch (arch) {
            .x86_64 => {
                return try self.genX8664BinMath(&inst.base, inst.args.lhs, inst.args.rhs, 0, 0x00);
            },
            else => return self.fail(inst.base.src, "TODO implement add for {}", .{self.target.cpu.arch}),
        }
    }

    fn genSub(self: *Function, inst: *ir.Inst.Sub, comptime arch: std.Target.Cpu.Arch) !MCValue {
        // No side effects, so if it's unreferenced, do nothing.
        if (inst.base.isUnused())
            return MCValue.dead;
        switch (arch) {
            .x86_64 => {
                return try self.genX8664BinMath(&inst.base, inst.args.lhs, inst.args.rhs, 5, 0x28);
            },
            else => return self.fail(inst.base.src, "TODO implement sub for {}", .{self.target.cpu.arch}),
        }
    }

    /// ADD, SUB, XOR, OR, AND
    fn genX8664BinMath(self: *Function, inst: *ir.Inst, op_lhs: *ir.Inst, op_rhs: *ir.Inst, opx: u8, mr: u8) !MCValue {
        try self.code.ensureCapacity(self.code.items.len + 8);

        const lhs = try self.resolveInst(op_lhs);
        const rhs = try self.resolveInst(op_rhs);

        // There are 2 operands, destination and source.
        // Either one, but not both, can be a memory operand.
        // Source operand can be an immediate, 8 bits or 32 bits.
        // So, if either one of the operands dies with this instruction, we can use it
        // as the result MCValue.
        var dst_mcv: MCValue = undefined;
        var src_mcv: MCValue = undefined;
        var src_inst: *ir.Inst = undefined;
        if (inst.operandDies(0) and lhs.isMutable()) {
            // LHS dies; use it as the destination.
            // Both operands cannot be memory.
            src_inst = op_rhs;
            if (lhs.isMemory() and rhs.isMemory()) {
                dst_mcv = try self.copyToNewRegister(op_lhs);
                src_mcv = rhs;
            } else {
                dst_mcv = lhs;
                src_mcv = rhs;
            }
        } else if (inst.operandDies(1) and rhs.isMutable()) {
            // RHS dies; use it as the destination.
            // Both operands cannot be memory.
            src_inst = op_lhs;
            if (lhs.isMemory() and rhs.isMemory()) {
                dst_mcv = try self.copyToNewRegister(op_rhs);
                src_mcv = lhs;
            } else {
                dst_mcv = rhs;
                src_mcv = lhs;
            }
        } else {
            if (lhs.isMemory()) {
                dst_mcv = try self.copyToNewRegister(op_lhs);
                src_mcv = rhs;
                src_inst = op_rhs;
            } else {
                dst_mcv = try self.copyToNewRegister(op_rhs);
                src_mcv = lhs;
                src_inst = op_lhs;
            }
        }
        // This instruction supports only signed 32-bit immediates at most. If the immediate
        // value is larger than this, we put it in a register.
        // A potential opportunity for future optimization here would be keeping track
        // of the fact that the instruction is available both as an immediate
        // and as a register.
        switch (src_mcv) {
            .immediate => |imm| {
                if (imm > std.math.maxInt(u31)) {
                    src_mcv = try self.copyToNewRegister(src_inst);
                }
            },
            else => {},
        }

        try self.genX8664BinMathCode(inst.src, dst_mcv, src_mcv, opx, mr);

        return dst_mcv;
    }

    fn genX8664BinMathCode(self: *Function, src: usize, dst_mcv: MCValue, src_mcv: MCValue, opx: u8, mr: u8) !void {
        switch (dst_mcv) {
            .none => unreachable,
            .dead, .unreach, .immediate => unreachable,
            .compare_flags_unsigned => unreachable,
            .compare_flags_signed => unreachable,
            .register => |dst_reg_usize| {
                const dst_reg = @intToEnum(Reg(.x86_64), @intCast(u8, dst_reg_usize));
                switch (src_mcv) {
                    .none => unreachable,
                    .dead, .unreach => unreachable,
                    .register => |src_reg_usize| {
                        const src_reg = @intToEnum(Reg(.x86_64), @intCast(u8, src_reg_usize));
                        self.rex(.{ .b = dst_reg.isExtended(), .r = src_reg.isExtended(), .w = dst_reg.size() == 64 });
                        self.code.appendSliceAssumeCapacity(&[_]u8{ mr + 0x1, 0xC0 | (@as(u8, src_reg.id() & 0b111) << 3) | @as(u8, dst_reg.id() & 0b111) });
                    },
                    .immediate => |imm| {
                        const imm32 = @intCast(u31, imm); // This case must be handled before calling genX8664BinMathCode.
                        // 81 /opx id
                        if (imm32 <= std.math.maxInt(u7)) {
                            self.rex(.{ .b = dst_reg.isExtended(), .w = dst_reg.size() == 64 });
                            self.code.appendSliceAssumeCapacity(&[_]u8{
                                0x83,
                                0xC0 | (opx << 3) | @truncate(u3, dst_reg.id()),
                                @intCast(u8, imm32),
                            });
                        } else {
                            self.rex(.{ .r = dst_reg.isExtended(), .w = dst_reg.size() == 64 });
                            self.code.appendSliceAssumeCapacity(&[_]u8{
                                0x81,
                                0xC0 | (opx << 3) | @truncate(u3, dst_reg.id()),
                            });
                            std.mem.writeIntLittle(u32, self.code.addManyAsArrayAssumeCapacity(4), imm32);
                        }
                    },
                    .embedded_in_code, .memory, .stack_offset => {
                        return self.fail(src, "TODO implement x86 ADD/SUB/CMP source memory", .{});
                    },
                    .compare_flags_unsigned => {
                        return self.fail(src, "TODO implement x86 ADD/SUB/CMP source compare flag (unsigned)", .{});
                    },
                    .compare_flags_signed => {
                        return self.fail(src, "TODO implement x86 ADD/SUB/CMP source compare flag (signed)", .{});
                    },
                }
            },
            .embedded_in_code, .memory, .stack_offset => {
                return self.fail(src, "TODO implement x86 ADD/SUB/CMP destination memory", .{});
            },
        }
    }

    fn genArg(self: *Function, inst: *ir.Inst.Arg) !MCValue {
        const i = self.arg_index;
        self.arg_index += 1;
        return self.args[i];
    }

    fn genBreakpoint(self: *Function, src: usize, comptime arch: std.Target.Cpu.Arch) !MCValue {
        switch (arch) {
            .i386, .x86_64 => {
                try self.code.append(0xcc); // int3
            },
            else => return self.fail(src, "TODO implement @breakpoint() for {}", .{self.target.cpu.arch}),
        }
        return .none;
    }

    fn genCall(self: *Function, inst: *ir.Inst.Call, comptime arch: std.Target.Cpu.Arch) !MCValue {
        const fn_ty = inst.args.func.ty;
        const cc = fn_ty.fnCallingConvention();
        const param_types = try self.gpa.alloc(Type, fn_ty.fnParamLen());
        defer self.gpa.free(param_types);
        fn_ty.fnParamTypes(param_types);
        var mc_args = try self.gpa.alloc(MCValue, param_types.len);
        defer self.gpa.free(mc_args);
        const stack_byte_count = try self.resolveParameters(inst.base.src, cc, param_types, mc_args);

        switch (arch) {
            .x86_64 => {
                for (mc_args) |mc_arg, arg_i| {
                    const arg = inst.args.args[arg_i];
                    const arg_mcv = try self.resolveInst(inst.args.args[arg_i]);
                    switch (mc_arg) {
                        .none => continue,
                        .register => |reg| {
                            try self.genSetReg(arg.src, arch, @intToEnum(Reg(arch), @intCast(u8, reg)), arg_mcv);
                            // TODO interact with the register allocator to mark the instruction as moved.
                        },
                        .stack_offset => {
                            // Here we need to emit instructions like this:
                            // mov     qword ptr [rsp + stack_offset], x
                            return self.fail(inst.base.src, "TODO implement calling with parameters in memory", .{});
                        },
                        .immediate => unreachable,
                        .unreach => unreachable,
                        .dead => unreachable,
                        .embedded_in_code => unreachable,
                        .memory => unreachable,
                        .compare_flags_signed => unreachable,
                        .compare_flags_unsigned => unreachable,
                    }
                }

                if (inst.args.func.cast(ir.Inst.Constant)) |func_inst| {
                    if (func_inst.val.cast(Value.Payload.Function)) |func_val| {
                        const func = func_val.func;
                        const got = &self.bin_file.program_headers.items[self.bin_file.phdr_got_index.?];
                        const ptr_bits = self.target.cpu.arch.ptrBitWidth();
                        const ptr_bytes: u64 = @divExact(ptr_bits, 8);
                        const got_addr = @intCast(u32, got.p_vaddr + func.owner_decl.link.offset_table_index * ptr_bytes);
                        // ff 14 25 xx xx xx xx    call [addr]
                        try self.code.ensureCapacity(self.code.items.len + 7);
                        self.code.appendSliceAssumeCapacity(&[3]u8{ 0xff, 0x14, 0x25 });
                        mem.writeIntLittle(u32, self.code.addManyAsArrayAssumeCapacity(4), got_addr);
                    } else {
                        return self.fail(inst.base.src, "TODO implement calling bitcasted functions", .{});
                    }
                } else {
                    return self.fail(inst.base.src, "TODO implement calling runtime known function pointer", .{});
                }
            },
            else => return self.fail(inst.base.src, "TODO implement call for {}", .{self.target.cpu.arch}),
        }

        const return_type = fn_ty.fnReturnType();
        switch (return_type.zigTypeTag()) {
            .Void => return MCValue{ .none = {} },
            .NoReturn => return MCValue{ .unreach = {} },
            else => return self.fail(inst.base.src, "TODO implement fn call with non-void return value", .{}),
        }
    }

    fn ret(self: *Function, src: usize, comptime arch: std.Target.Cpu.Arch, mcv: MCValue) !MCValue {
        if (mcv != .none) {
            return self.fail(src, "TODO implement return with non-void operand", .{});
        }
        switch (arch) {
            .i386 => {
                try self.code.append(0xc3); // ret
            },
            .x86_64 => {
                try self.code.appendSlice(&[_]u8{
                    0x5d, // pop rbp
                    0xc3, // ret
                });
            },
            else => return self.fail(src, "TODO implement return for {}", .{self.target.cpu.arch}),
        }
        return .unreach;
    }

    fn genRet(self: *Function, inst: *ir.Inst.Ret, comptime arch: std.Target.Cpu.Arch) !MCValue {
        const operand = try self.resolveInst(inst.args.operand);
        return self.ret(inst.base.src, arch, operand);
    }

    fn genRetVoid(self: *Function, inst: *ir.Inst.RetVoid, comptime arch: std.Target.Cpu.Arch) !MCValue {
        return self.ret(inst.base.src, arch, .none);
    }

    fn genCmp(self: *Function, inst: *ir.Inst.Cmp, comptime arch: std.Target.Cpu.Arch) !MCValue {
        // No side effects, so if it's unreferenced, do nothing.
        if (inst.base.isUnused())
            return MCValue.dead;
        switch (arch) {
            .x86_64 => {
                try self.code.ensureCapacity(self.code.items.len + 8);

                const lhs = try self.resolveInst(inst.args.lhs);
                const rhs = try self.resolveInst(inst.args.rhs);

                // There are 2 operands, destination and source.
                // Either one, but not both, can be a memory operand.
                // Source operand can be an immediate, 8 bits or 32 bits.
                const dst_mcv = if (lhs.isImmediate() or (lhs.isMemory() and rhs.isMemory()))
                    try self.copyToNewRegister(inst.args.lhs)
                else
                    lhs;
                // This instruction supports only signed 32-bit immediates at most.
                const src_mcv = try self.limitImmediateType(inst.args.rhs, i32);

                try self.genX8664BinMathCode(inst.base.src, dst_mcv, src_mcv, 7, 0x38);
                const info = inst.args.lhs.ty.intInfo(self.target.*);
                if (info.signed) {
                    return MCValue{ .compare_flags_signed = inst.args.op };
                } else {
                    return MCValue{ .compare_flags_unsigned = inst.args.op };
                }
            },
            else => return self.fail(inst.base.src, "TODO implement cmp for {}", .{self.target.cpu.arch}),
        }
    }

    fn genCondBr(self: *Function, inst: *ir.Inst.CondBr, comptime arch: std.Target.Cpu.Arch) !MCValue {
        switch (arch) {
            .x86_64 => {
                try self.code.ensureCapacity(self.code.items.len + 6);

                const cond = try self.resolveInst(inst.args.condition);
                switch (cond) {
                    .compare_flags_signed => |cmp_op| {
                        // Here we map to the opposite opcode because the jump is to the false branch.
                        const opcode: u8 = switch (cmp_op) {
                            .gte => 0x8c,
                            .gt => 0x8e,
                            .neq => 0x84,
                            .lt => 0x8d,
                            .lte => 0x8f,
                            .eq => 0x85,
                        };
                        return self.genX86CondBr(inst, opcode, arch);
                    },
                    .compare_flags_unsigned => |cmp_op| {
                        // Here we map to the opposite opcode because the jump is to the false branch.
                        const opcode: u8 = switch (cmp_op) {
                            .gte => 0x82,
                            .gt => 0x86,
                            .neq => 0x84,
                            .lt => 0x83,
                            .lte => 0x87,
                            .eq => 0x85,
                        };
                        return self.genX86CondBr(inst, opcode, arch);
                    },
                    .register => |reg_usize| {
                        const reg = @intToEnum(Reg(arch), @intCast(u8, reg_usize));
                        // test reg, 1
                        // TODO detect al, ax, eax
                        try self.code.ensureCapacity(self.code.items.len + 4);
                        self.rex(.{ .b = reg.isExtended(), .w = reg.size() == 64 });
                        self.code.appendSliceAssumeCapacity(&[_]u8{
                            0xf6,
                            @as(u8, 0xC0) | (0 << 3) | @truncate(u3, reg.id()),
                            0x01,
                        });
                        return self.genX86CondBr(inst, 0x84, arch);
                    },
                    else => return self.fail(inst.base.src, "TODO implement condbr {} when condition is {}", .{ self.target.cpu.arch, @tagName(cond) }),
                }
            },
            else => return self.fail(inst.base.src, "TODO implement condbr for {}", .{self.target.cpu.arch}),
        }
    }

    fn genX86CondBr(self: *Function, inst: *ir.Inst.CondBr, opcode: u8, comptime arch: std.Target.Cpu.Arch) !MCValue {
        self.code.appendSliceAssumeCapacity(&[_]u8{ 0x0f, opcode });
        const reloc = Reloc{ .rel32 = self.code.items.len };
        self.code.items.len += 4;
        try self.genBody(inst.args.true_body, arch);
        try self.performReloc(inst.base.src, reloc);
        try self.genBody(inst.args.false_body, arch);
        return MCValue.unreach;
    }

    fn genIsNull(self: *Function, inst: *ir.Inst.IsNull, comptime arch: std.Target.Cpu.Arch) !MCValue {
        switch (arch) {
            else => return self.fail(inst.base.src, "TODO implement isnull for {}", .{self.target.cpu.arch}),
        }
    }

    fn genIsNonNull(self: *Function, inst: *ir.Inst.IsNonNull, comptime arch: std.Target.Cpu.Arch) !MCValue {
        // Here you can specialize this instruction if it makes sense to, otherwise the default
        // will call genIsNull and invert the result.
        switch (arch) {
            else => return self.fail(inst.base.src, "TODO call genIsNull and invert the result ", .{}),
        }
    }

    fn genBlock(self: *Function, inst: *ir.Inst.Block, comptime arch: std.Target.Cpu.Arch) !MCValue {
        if (inst.base.ty.hasCodeGenBits()) {
            return self.fail(inst.base.src, "TODO codegen Block with non-void type", .{});
        }
        // A block is nothing but a setup to be able to jump to the end.
        defer inst.codegen.relocs.deinit(self.gpa);
        try self.genBody(inst.args.body, arch);

        for (inst.codegen.relocs.items) |reloc| try self.performReloc(inst.base.src, reloc);

        return MCValue.none;
    }

    fn performReloc(self: *Function, src: usize, reloc: Reloc) !void {
        switch (reloc) {
            .rel32 => |pos| {
                const amt = self.code.items.len - (pos + 4);
                const s32_amt = std.math.cast(i32, amt) catch
                    return self.fail(src, "unable to perform relocation: jump too far", .{});
                mem.writeIntLittle(i32, self.code.items[pos..][0..4], s32_amt);
            },
        }
    }

    fn genBr(self: *Function, inst: *ir.Inst.Br, comptime arch: std.Target.Cpu.Arch) !MCValue {
        if (!inst.args.operand.ty.hasCodeGenBits())
            return self.brVoid(inst.base.src, inst.args.block, arch);

        const operand = try self.resolveInst(inst.args.operand);
        switch (arch) {
            else => return self.fail(inst.base.src, "TODO implement br for {}", .{self.target.cpu.arch}),
        }
    }

    fn genBrVoid(self: *Function, inst: *ir.Inst.BrVoid, comptime arch: std.Target.Cpu.Arch) !MCValue {
        return self.brVoid(inst.base.src, inst.args.block, arch);
    }

    fn brVoid(self: *Function, src: usize, block: *ir.Inst.Block, comptime arch: std.Target.Cpu.Arch) !MCValue {
        // Emit a jump with a relocation. It will be patched up after the block ends.
        try block.codegen.relocs.ensureCapacity(self.gpa, block.codegen.relocs.items.len + 1);

        switch (arch) {
            .i386, .x86_64 => {
                // TODO optimization opportunity: figure out when we can emit this as a 2 byte instruction
                // which is available if the jump is 127 bytes or less forward.
                try self.code.resize(self.code.items.len + 5);
                self.code.items[self.code.items.len - 5] = 0xe9; // jmp rel32
                // Leave the jump offset undefined
                block.codegen.relocs.appendAssumeCapacity(.{ .rel32 = self.code.items.len - 4 });
            },
            else => return self.fail(src, "TODO implement brvoid for {}", .{self.target.cpu.arch}),
        }
        return .none;
    }

    fn genAsm(self: *Function, inst: *ir.Inst.Assembly, comptime arch: Target.Cpu.Arch) !MCValue {
        if (!inst.args.is_volatile and inst.base.isUnused())
            return MCValue.dead;
        if (arch != .x86_64 and arch != .i386) {
            return self.fail(inst.base.src, "TODO implement inline asm support for more architectures", .{});
        }
        for (inst.args.inputs) |input, i| {
            if (input.len < 3 or input[0] != '{' or input[input.len - 1] != '}') {
                return self.fail(inst.base.src, "unrecognized asm input constraint: '{}'", .{input});
            }
            const reg_name = input[1 .. input.len - 1];
            const reg = parseRegName(arch, reg_name) orelse
                return self.fail(inst.base.src, "unrecognized register: '{}'", .{reg_name});
            const arg = try self.resolveInst(inst.args.args[i]);
            try self.genSetReg(inst.base.src, arch, reg, arg);
        }

        if (mem.eql(u8, inst.args.asm_source, "syscall")) {
            try self.code.appendSlice(&[_]u8{ 0x0f, 0x05 });
        } else {
            return self.fail(inst.base.src, "TODO implement support for more x86 assembly instructions", .{});
        }

        if (inst.args.output) |output| {
            if (output.len < 4 or output[0] != '=' or output[1] != '{' or output[output.len - 1] != '}') {
                return self.fail(inst.base.src, "unrecognized asm output constraint: '{}'", .{output});
            }
            const reg_name = output[2 .. output.len - 1];
            const reg = parseRegName(arch, reg_name) orelse
                return self.fail(inst.base.src, "unrecognized register: '{}'", .{reg_name});
            return MCValue{ .register = @enumToInt(reg) };
        } else {
            return MCValue.none;
        }
    }

    /// Encodes a REX prefix as specified, and appends it to the instruction
    /// stream. This only modifies the instruction stream if at least one bit
    /// is set true, which has a few implications:
    ///
    /// * The length of the instruction buffer will be modified *if* the
    /// resulting REX is meaningful, but will remain the same if it is not.
    /// * Deliberately inserting a "meaningless REX" requires explicit usage of
    /// 0x40, and cannot be done via this function.
    fn rex(self: *Function, arg: struct { b: bool = false, w: bool = false, x: bool = false, r: bool = false }) void {
        //  From section 2.2.1.2 of the manual, REX is encoded as b0100WRXB.
        var value: u8 = 0x40;
        if (arg.b) {
            value |= 0x1;
        }
        if (arg.x) {
            value |= 0x2;
        }
        if (arg.r) {
            value |= 0x4;
        }
        if (arg.w) {
            value |= 0x8;
        }
        if (value != 0x40) {
            self.code.appendAssumeCapacity(value);
        }
    }

    fn genSetReg(self: *Function, src: usize, comptime arch: Target.Cpu.Arch, reg: Reg(arch), mcv: MCValue) error{ CodegenFail, OutOfMemory }!void {
        switch (arch) {
            .x86_64 => switch (mcv) {
                .dead => unreachable,
                .none => unreachable,
                .unreach => unreachable,
                .compare_flags_unsigned => |op| {
                    try self.code.ensureCapacity(self.code.items.len + 3);
                    self.rex(.{ .b = reg.isExtended(), .w = reg.size() == 64 });
                    const opcode: u8 = switch (op) {
                        .gte => 0x93,
                        .gt => 0x97,
                        .neq => 0x95,
                        .lt => 0x92,
                        .lte => 0x96,
                        .eq => 0x94,
                    };
                    const id = @as(u8, reg.id() & 0b111);
                    self.code.appendSliceAssumeCapacity(&[_]u8{ 0x0f, opcode, 0xC0 | id });
                },
                .compare_flags_signed => |op| {
                    return self.fail(src, "TODO set register with compare flags value (signed)", .{});
                },
                .immediate => |x| {
                    if (reg.size() != 64) {
                        return self.fail(src, "TODO decide whether to implement non-64-bit loads", .{});
                    }
                    // 32-bit moves zero-extend to 64-bit, so xoring the 32-bit
                    // register is the fastest way to zero a register.
                    if (x == 0) {
                        // The encoding for `xor r32, r32` is `0x31 /r`.
                        // Section 3.1.1.1 of the Intel x64 Manual states that "/r indicates that the
                        // ModR/M byte of the instruction contains a register operand and an r/m operand."
                        //
                        // R/M bytes are composed of two bits for the mode, then three bits for the register,
                        // then three bits for the operand. Since we're zeroing a register, the two three-bit
                        // values will be identical, and the mode is three (the raw register value).
                        //
                        // If we're accessing e.g. r8d, we need to use a REX prefix before the actual operation. Since
                        // this is a 32-bit operation, the W flag is set to zero. X is also zero, as we're not using a SIB.
                        // Both R and B are set, as we're extending, in effect, the register bits *and* the operand.
                        try self.code.ensureCapacity(self.code.items.len + 3);
                        self.rex(.{ .r = reg.isExtended(), .b = reg.isExtended() });
                        const id = @as(u8, reg.id() & 0b111);
                        self.code.appendSliceAssumeCapacity(&[_]u8{ 0x31, 0xC0 | id << 3 | id });
                        return;
                    }
                    if (x <= std.math.maxInt(u32)) {
                        // Next best case: if we set the lower four bytes, the upper four will be zeroed.
                        //
                        // The encoding for `mov IMM32 -> REG` is (0xB8 + R) IMM.
                        if (reg.isExtended()) {
                            // Just as with XORing, we need a REX prefix. This time though, we only
                            // need the B bit set, as we're extending the opcode's register field,
                            // and there is no Mod R/M byte.
                            //
                            // Thus, we need b01000001, or 0x41.
                            try self.code.resize(self.code.items.len + 6);
                            self.code.items[self.code.items.len - 6] = 0x41;
                        } else {
                            try self.code.resize(self.code.items.len + 5);
                        }
                        self.code.items[self.code.items.len - 5] = 0xB8 | @as(u8, reg.id() & 0b111);
                        const imm_ptr = self.code.items[self.code.items.len - 4 ..][0..4];
                        mem.writeIntLittle(u32, imm_ptr, @intCast(u32, x));
                        return;
                    }
                    // Worst case: we need to load the 64-bit register with the IMM. GNU's assemblers calls
                    // this `movabs`, though this is officially just a different variant of the plain `mov`
                    // instruction.
                    //
                    // This encoding is, in fact, the *same* as the one used for 32-bit loads. The only
                    // difference is that we set REX.W before the instruction, which extends the load to
                    // 64-bit and uses the full bit-width of the register.
                    //
                    // Since we always need a REX here, let's just check if we also need to set REX.B.
                    //
                    // In this case, the encoding of the REX byte is 0b0100100B
                    try self.code.ensureCapacity(self.code.items.len + 10);
                    self.rex(.{ .w = true, .b = reg.isExtended() });
                    self.code.items.len += 9;
                    self.code.items[self.code.items.len - 9] = 0xB8 | @as(u8, reg.id() & 0b111);
                    const imm_ptr = self.code.items[self.code.items.len - 8 ..][0..8];
                    mem.writeIntLittle(u64, imm_ptr, x);
                },
                .embedded_in_code => |code_offset| {
                    if (reg.size() != 64) {
                        return self.fail(src, "TODO decide whether to implement non-64-bit loads", .{});
                    }
                    // We need the offset from RIP in a signed i32 twos complement.
                    // The instruction is 7 bytes long and RIP points to the next instruction.
                    try self.code.ensureCapacity(self.code.items.len + 7);
                    // 64-bit LEA is encoded as REX.W 8D /r. If the register is extended, the REX byte is modified,
                    // but the operation size is unchanged. Since we're using a disp32, we want mode 0 and lower three
                    // bits as five.
                    // REX 0x8D 0b00RRR101, where RRR is the lower three bits of the id.
                    self.rex(.{ .w = true, .b = reg.isExtended() });
                    self.code.items.len += 6;
                    const rip = self.code.items.len;
                    const big_offset = @intCast(i64, code_offset) - @intCast(i64, rip);
                    const offset = @intCast(i32, big_offset);
                    self.code.items[self.code.items.len - 6] = 0x8D;
                    self.code.items[self.code.items.len - 5] = 0b101 | (@as(u8, reg.id() & 0b111) << 3);
                    const imm_ptr = self.code.items[self.code.items.len - 4 ..][0..4];
                    mem.writeIntLittle(i32, imm_ptr, offset);
                },
                .register => |r| {
                    if (reg.size() != 64) {
                        return self.fail(src, "TODO decide whether to implement non-64-bit loads", .{});
                    }
                    const src_reg = @intToEnum(Reg(arch), @intCast(u8, r));
                    // This is a variant of 8B /r. Since we're using 64-bit moves, we require a REX.
                    // This is thus three bytes: REX 0x8B R/M.
                    // If the destination is extended, the R field must be 1.
                    // If the *source* is extended, the B field must be 1.
                    // Since the register is being accessed directly, the R/M mode is three. The reg field (the middle
                    // three bits) contain the destination, and the R/M field (the lower three bits) contain the source.
                    try self.code.ensureCapacity(self.code.items.len + 3);
                    self.rex(.{ .w = true, .r = reg.isExtended(), .b = src_reg.isExtended() });
                    const R = 0xC0 | (@as(u8, reg.id() & 0b111) << 3) | @as(u8, src_reg.id() & 0b111);
                    self.code.appendSliceAssumeCapacity(&[_]u8{ 0x8B, R });
                },
                .memory => |x| {
                    if (reg.size() != 64) {
                        return self.fail(src, "TODO decide whether to implement non-64-bit loads", .{});
                    }
                    if (x <= std.math.maxInt(u32)) {
                        // Moving from memory to a register is a variant of `8B /r`.
                        // Since we're using 64-bit moves, we require a REX.
                        // This variant also requires a SIB, as it would otherwise be RIP-relative.
                        // We want mode zero with the lower three bits set to four to indicate an SIB with no other displacement.
                        // The SIB must be 0x25, to indicate a disp32 with no scaled index.
                        // 0b00RRR100, where RRR is the lower three bits of the register ID.
                        // The instruction is thus eight bytes; REX 0x8B 0b00RRR100 0x25 followed by a four-byte disp32.
                        try self.code.ensureCapacity(self.code.items.len + 8);
                        self.rex(.{ .w = true, .b = reg.isExtended() });
                        self.code.appendSliceAssumeCapacity(&[_]u8{
                            0x8B,
                            0x04 | (@as(u8, reg.id() & 0b111) << 3), // R
                            0x25,
                        });
                        mem.writeIntLittle(u32, self.code.addManyAsArrayAssumeCapacity(4), @intCast(u32, x));
                    } else {
                        // If this is RAX, we can use a direct load; otherwise, we need to load the address, then indirectly load
                        // the value.
                        if (reg.id() == 0) {
                            // REX.W 0xA1 moffs64*
                            // moffs64* is a 64-bit offset "relative to segment base", which really just means the
                            // absolute address for all practical purposes.
                            try self.code.resize(self.code.items.len + 10);
                            // REX.W == 0x48
                            self.code.items[self.code.items.len - 10] = 0x48;
                            self.code.items[self.code.items.len - 9] = 0xA1;
                            const imm_ptr = self.code.items[self.code.items.len - 8 ..][0..8];
                            mem.writeIntLittle(u64, imm_ptr, x);
                        } else {
                            // This requires two instructions; a move imm as used above, followed by an indirect load using the register
                            // as the address and the register as the destination.
                            //
                            // This cannot be used if the lower three bits of the id are equal to four or five, as there
                            // is no way to possibly encode it. This means that RSP, RBP, R12, and R13 cannot be used with
                            // this instruction.
                            const id3 = @truncate(u3, reg.id());
                            std.debug.assert(id3 != 4 and id3 != 5);

                            // Rather than duplicate the logic used for the move, we just use a self-call with a new MCValue.
                            try self.genSetReg(src, arch, reg, MCValue{ .immediate = x });

                            // Now, the register contains the address of the value to load into it
                            // Currently, we're only allowing 64-bit registers, so we need the `REX.W 8B /r` variant.
                            // TODO: determine whether to allow other sized registers, and if so, handle them properly.
                            // This operation requires three bytes: REX 0x8B R/M
                            try self.code.ensureCapacity(self.code.items.len + 3);
                            // For this operation, we want R/M mode *zero* (use register indirectly), and the two register
                            // values must match. Thus, it's 00ABCABC where ABC is the lower three bits of the register ID.
                            //
                            // Furthermore, if this is an extended register, both B and R must be set in the REX byte, as *both*
                            // register operands need to be marked as extended.
                            self.rex(.{ .w = true, .b = reg.isExtended(), .r = reg.isExtended() });
                            const RM = (@as(u8, reg.id() & 0b111) << 3) | @truncate(u3, reg.id());
                            self.code.appendSliceAssumeCapacity(&[_]u8{ 0x8B, RM });
                        }
                    }
                },
                .stack_offset => |off| {
                    return self.fail(src, "TODO implement genSetReg for stack variables", .{});
                },
            },
            else => return self.fail(src, "TODO implement genSetReg for more architectures", .{}),
        }
    }

    fn genPtrToInt(self: *Function, inst: *ir.Inst.PtrToInt) !MCValue {
        // no-op
        return self.resolveInst(inst.args.ptr);
    }

    fn genBitCast(self: *Function, inst: *ir.Inst.BitCast) !MCValue {
        const operand = try self.resolveInst(inst.args.operand);
        return operand;
    }

    fn resolveInst(self: *Function, inst: *ir.Inst) !MCValue {
        // Constants have static lifetimes, so they are always memoized in the outer most table.
        if (inst.cast(ir.Inst.Constant)) |const_inst| {
            const branch = &self.branch_stack.items[0];
            const gop = try branch.inst_table.getOrPut(self.gpa, inst);
            if (!gop.found_existing) {
                gop.entry.value = try self.genTypedValue(inst.src, .{ .ty = inst.ty, .val = const_inst.val });
            }
            return gop.entry.value;
        }

        // Treat each stack item as a "layer" on top of the previous one.
        var i: usize = self.branch_stack.items.len;
        while (true) {
            i -= 1;
            if (self.branch_stack.items[i].inst_table.get(inst)) |mcv| {
                return mcv;
            }
        }
    }

    fn copyToNewRegister(self: *Function, inst: *ir.Inst) !MCValue {
        return self.fail(inst.src, "TODO implement copyToNewRegister", .{});
    }

    /// If the MCValue is an immediate, and it does not fit within this type,
    /// we put it in a register.
    /// A potential opportunity for future optimization here would be keeping track
    /// of the fact that the instruction is available both as an immediate
    /// and as a register.
    fn limitImmediateType(self: *Function, inst: *ir.Inst, comptime T: type) !MCValue {
        const mcv = try self.resolveInst(inst);
        const ti = @typeInfo(T).Int;
        switch (mcv) {
            .immediate => |imm| {
                // This immediate is unsigned.
                const U = @Type(.{
                    .Int = .{
                        .bits = ti.bits - @boolToInt(ti.is_signed),
                        .is_signed = false,
                    },
                });
                if (imm >= std.math.maxInt(U)) {
                    return self.copyToNewRegister(inst);
                }
            },
            else => {},
        }
        return mcv;
    }

    fn genTypedValue(self: *Function, src: usize, typed_value: TypedValue) !MCValue {
        const ptr_bits = self.target.cpu.arch.ptrBitWidth();
        const ptr_bytes: u64 = @divExact(ptr_bits, 8);
        switch (typed_value.ty.zigTypeTag()) {
            .Pointer => {
                if (typed_value.val.cast(Value.Payload.DeclRef)) |payload| {
                    const got = &self.bin_file.program_headers.items[self.bin_file.phdr_got_index.?];
                    const decl = payload.decl;
                    const got_addr = got.p_vaddr + decl.link.offset_table_index * ptr_bytes;
                    return MCValue{ .memory = got_addr };
                }
                return self.fail(src, "TODO codegen more kinds of const pointers", .{});
            },
            .Int => {
                const info = typed_value.ty.intInfo(self.target.*);
                if (info.bits > ptr_bits or info.signed) {
                    return self.fail(src, "TODO const int bigger than ptr and signed int", .{});
                }
                return MCValue{ .immediate = typed_value.val.toUnsignedInt() };
            },
            .Bool => {
                return MCValue{ .immediate = @boolToInt(typed_value.val.toBool()) };
            },
            .ComptimeInt => unreachable, // semantic analysis prevents this
            .ComptimeFloat => unreachable, // semantic analysis prevents this
            else => return self.fail(src, "TODO implement const of type '{}'", .{typed_value.ty}),
        }
    }

    fn resolveParameters(
        self: *Function,
        src: usize,
        cc: std.builtin.CallingConvention,
        param_types: []const Type,
        results: []MCValue,
    ) !u32 {
        switch (self.target.cpu.arch) {
            .x86_64 => {
                switch (cc) {
                    .Naked => {
                        assert(results.len == 0);
                        return 0;
                    },
                    .Unspecified, .C => {
                        var next_int_reg: usize = 0;
                        var next_stack_offset: u32 = 0;

                        const integer_registers = [_]Reg(.x86_64){ .rdi, .rsi, .rdx, .rcx, .r8, .r9 };
                        for (param_types) |ty, i| {
                            switch (ty.zigTypeTag()) {
                                .Bool, .Int => {
                                    if (next_int_reg >= integer_registers.len) {
                                        results[i] = .{ .stack_offset = next_stack_offset };
                                        next_stack_offset += @intCast(u32, ty.abiSize(self.target.*));
                                    } else {
                                        results[i] = .{ .register = @enumToInt(integer_registers[next_int_reg]) };
                                        next_int_reg += 1;
                                    }
                                },
                                else => return self.fail(src, "TODO implement function parameters of type {}", .{@tagName(ty.zigTypeTag())}),
                            }
                        }
                        return next_stack_offset;
                    },
                    else => return self.fail(src, "TODO implement function parameters for {}", .{cc}),
                }
            },
            else => return self.fail(src, "TODO implement C ABI support for {}", .{self.target.cpu.arch}),
        }
    }

    fn fail(self: *Function, src: usize, comptime format: []const u8, args: anytype) error{ CodegenFail, OutOfMemory } {
        @setCold(true);
        assert(self.err_msg == null);
        self.err_msg = try ErrorMsg.create(self.bin_file.allocator, src, format, args);
        return error.CodegenFail;
    }
};

const x86_64 = @import("codegen/x86_64.zig");
const x86 = @import("codegen/x86.zig");

fn Reg(comptime arch: Target.Cpu.Arch) type {
    return switch (arch) {
        .i386 => x86.Register,
        .x86_64 => x86_64.Register,
        else => @compileError("TODO add more register enums"),
    };
}

fn parseRegName(comptime arch: Target.Cpu.Arch, name: []const u8) ?Reg(arch) {
    return std.meta.stringToEnum(Reg(arch), name);
}
