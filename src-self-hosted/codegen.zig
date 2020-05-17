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

pub const Result = union(enum) {
    /// The `code` parameter passed to `generateSymbol` has the value appended.
    appended: void,
    /// The value is available externally, `code` is unused.
    externally_managed: []const u8,
    fail: *Module.ErrorMsg,
};

pub fn generateSymbol(
    bin_file: *link.ElfFile,
    src: usize,
    typed_value: TypedValue,
    code: *std.ArrayList(u8),
) error{
    OutOfMemory,
    /// A Decl that this symbol depends on had a semantic analysis failure.
    AnalysisFail,
}!Result {
    switch (typed_value.ty.zigTypeTag()) {
        .Fn => {
            const module_fn = typed_value.val.cast(Value.Payload.Function).?.func;

            var function = Function{
                .target = &bin_file.options.target,
                .bin_file = bin_file,
                .mod_fn = module_fn,
                .code = code,
                .inst_table = std.AutoHashMap(*ir.Inst, Function.MCValue).init(bin_file.allocator),
                .err_msg = null,
            };
            defer function.inst_table.deinit();

            for (module_fn.analysis.success.instructions) |inst| {
                const new_inst = function.genFuncInst(inst) catch |err| switch (err) {
                    error.CodegenFail => return Result{ .fail = function.err_msg.? },
                    else => |e| return e,
                };
                try function.inst_table.putNoClobber(inst, new_inst);
            }

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

const Function = struct {
    bin_file: *link.ElfFile,
    target: *const std.Target,
    mod_fn: *const Module.Fn,
    code: *std.ArrayList(u8),
    inst_table: std.AutoHashMap(*ir.Inst, MCValue),
    err_msg: ?*ErrorMsg,

    const MCValue = union(enum) {
        none,
        unreach,
        /// A pointer-sized integer that fits in a register.
        immediate: u64,
        /// The constant was emitted into the code, at this offset.
        embedded_in_code: usize,
        /// The value is in a target-specific register. The value can
        /// be @intToEnum casted to the respective Reg enum.
        register: usize,
        /// The value is in memory at a hard-coded address.
        memory: u64,
    };

    fn genFuncInst(self: *Function, inst: *ir.Inst) !MCValue {
        switch (inst.tag) {
            .breakpoint => return self.genBreakpoint(inst.src),
            .call => return self.genCall(inst.cast(ir.Inst.Call).?),
            .unreach => return MCValue{ .unreach = {} },
            .constant => unreachable, // excluded from function bodies
            .assembly => return self.genAsm(inst.cast(ir.Inst.Assembly).?),
            .ptrtoint => return self.genPtrToInt(inst.cast(ir.Inst.PtrToInt).?),
            .bitcast => return self.genBitCast(inst.cast(ir.Inst.BitCast).?),
            .ret => return self.genRet(inst.cast(ir.Inst.Ret).?),
            .cmp => return self.genCmp(inst.cast(ir.Inst.Cmp).?),
            .condbr => return self.genCondBr(inst.cast(ir.Inst.CondBr).?),
            .isnull => return self.genIsNull(inst.cast(ir.Inst.IsNull).?),
            .isnonnull => return self.genIsNonNull(inst.cast(ir.Inst.IsNonNull).?),
        }
    }

    fn genBreakpoint(self: *Function, src: usize) !MCValue {
        switch (self.target.cpu.arch) {
            .i386, .x86_64 => {
                try self.code.append(0xcc); // int3
            },
            else => return self.fail(src, "TODO implement @breakpoint() for {}", .{self.target.cpu.arch}),
        }
        return .none;
    }

    fn genCall(self: *Function, inst: *ir.Inst.Call) !MCValue {
        if (inst.args.func.cast(ir.Inst.Constant)) |func_inst| {
            if (inst.args.args.len != 0) {
                return self.fail(inst.base.src, "TODO implement call with more than 0 parameters", .{});
            }

            if (func_inst.val.cast(Value.Payload.Function)) |func_val| {
                const func = func_val.func;
                return self.fail(inst.base.src, "TODO implement calling function", .{});
            } else {
                return self.fail(inst.base.src, "TODO implement calling weird function values", .{});
            }
        } else {
            return self.fail(inst.base.src, "TODO implement calling runtime known function pointer", .{});
        }

        switch (self.target.cpu.arch) {
            else => return self.fail(inst.base.src, "TODO implement call for {}", .{self.target.cpu.arch}),
        }
    }

    fn genRet(self: *Function, inst: *ir.Inst.Ret) !MCValue {
        switch (self.target.cpu.arch) {
            .i386, .x86_64 => {
                try self.code.append(0xc3); // ret
            },
            else => return self.fail(inst.base.src, "TODO implement return for {}", .{self.target.cpu.arch}),
        }
        return .unreach;
    }

    fn genCmp(self: *Function, inst: *ir.Inst.Cmp) !MCValue {
        switch (self.target.cpu.arch) {
            else => return self.fail(inst.base.src, "TODO implement cmp for {}", .{self.target.cpu.arch}),
        }
    }

    fn genCondBr(self: *Function, inst: *ir.Inst.CondBr) !MCValue {
        switch (self.target.cpu.arch) {
            else => return self.fail(inst.base.src, "TODO implement condbr for {}", .{self.target.cpu.arch}),
        }
    }

    fn genIsNull(self: *Function, inst: *ir.Inst.IsNull) !MCValue {
        switch (self.target.cpu.arch) {
            else => return self.fail(inst.base.src, "TODO implement isnull for {}", .{self.target.cpu.arch}),
        }
    }

    fn genIsNonNull(self: *Function, inst: *ir.Inst.IsNonNull) !MCValue {
        // Here you can specialize this instruction if it makes sense to, otherwise the default
        // will call genIsNull and invert the result.
        switch (self.target.cpu.arch) {
            else => return self.fail(inst.base.src, "TODO call genIsNull and invert the result ", .{}),
        }
    }

    fn genRelativeFwdJump(self: *Function, src: usize, amount: u32) !void {
        switch (self.target.cpu.arch) {
            .i386, .x86_64 => {
                // TODO x86 treats the operands as signed
                if (amount <= std.math.maxInt(u8)) {
                    try self.code.resize(self.code.items.len + 2);
                    self.code.items[self.code.items.len - 2] = 0xeb;
                    self.code.items[self.code.items.len - 1] = @intCast(u8, amount);
                } else {
                    try self.code.resize(self.code.items.len + 5);
                    self.code.items[self.code.items.len - 5] = 0xe9; // jmp rel32
                    const imm_ptr = self.code.items[self.code.items.len - 4 ..][0..4];
                    mem.writeIntLittle(u32, imm_ptr, amount);
                }
            },
            else => return self.fail(src, "TODO implement relative forward jump for {}", .{self.target.cpu.arch}),
        }
    }

    fn genAsm(self: *Function, inst: *ir.Inst.Assembly) !MCValue {
        // TODO convert to inline function
        switch (self.target.cpu.arch) {
            .arm => return self.genAsmArch(.arm, inst),
            .armeb => return self.genAsmArch(.armeb, inst),
            .aarch64 => return self.genAsmArch(.aarch64, inst),
            .aarch64_be => return self.genAsmArch(.aarch64_be, inst),
            .aarch64_32 => return self.genAsmArch(.aarch64_32, inst),
            .arc => return self.genAsmArch(.arc, inst),
            .avr => return self.genAsmArch(.avr, inst),
            .bpfel => return self.genAsmArch(.bpfel, inst),
            .bpfeb => return self.genAsmArch(.bpfeb, inst),
            .hexagon => return self.genAsmArch(.hexagon, inst),
            .mips => return self.genAsmArch(.mips, inst),
            .mipsel => return self.genAsmArch(.mipsel, inst),
            .mips64 => return self.genAsmArch(.mips64, inst),
            .mips64el => return self.genAsmArch(.mips64el, inst),
            .msp430 => return self.genAsmArch(.msp430, inst),
            .powerpc => return self.genAsmArch(.powerpc, inst),
            .powerpc64 => return self.genAsmArch(.powerpc64, inst),
            .powerpc64le => return self.genAsmArch(.powerpc64le, inst),
            .r600 => return self.genAsmArch(.r600, inst),
            .amdgcn => return self.genAsmArch(.amdgcn, inst),
            .riscv32 => return self.genAsmArch(.riscv32, inst),
            .riscv64 => return self.genAsmArch(.riscv64, inst),
            .sparc => return self.genAsmArch(.sparc, inst),
            .sparcv9 => return self.genAsmArch(.sparcv9, inst),
            .sparcel => return self.genAsmArch(.sparcel, inst),
            .s390x => return self.genAsmArch(.s390x, inst),
            .tce => return self.genAsmArch(.tce, inst),
            .tcele => return self.genAsmArch(.tcele, inst),
            .thumb => return self.genAsmArch(.thumb, inst),
            .thumbeb => return self.genAsmArch(.thumbeb, inst),
            .i386 => return self.genAsmArch(.i386, inst),
            .x86_64 => return self.genAsmArch(.x86_64, inst),
            .xcore => return self.genAsmArch(.xcore, inst),
            .nvptx => return self.genAsmArch(.nvptx, inst),
            .nvptx64 => return self.genAsmArch(.nvptx64, inst),
            .le32 => return self.genAsmArch(.le32, inst),
            .le64 => return self.genAsmArch(.le64, inst),
            .amdil => return self.genAsmArch(.amdil, inst),
            .amdil64 => return self.genAsmArch(.amdil64, inst),
            .hsail => return self.genAsmArch(.hsail, inst),
            .hsail64 => return self.genAsmArch(.hsail64, inst),
            .spir => return self.genAsmArch(.spir, inst),
            .spir64 => return self.genAsmArch(.spir64, inst),
            .kalimba => return self.genAsmArch(.kalimba, inst),
            .shave => return self.genAsmArch(.shave, inst),
            .lanai => return self.genAsmArch(.lanai, inst),
            .wasm32 => return self.genAsmArch(.wasm32, inst),
            .wasm64 => return self.genAsmArch(.wasm64, inst),
            .renderscript32 => return self.genAsmArch(.renderscript32, inst),
            .renderscript64 => return self.genAsmArch(.renderscript64, inst),
            .ve => return self.genAsmArch(.ve, inst),
        }
    }

    fn genAsmArch(self: *Function, comptime arch: Target.Cpu.Arch, inst: *ir.Inst.Assembly) !MCValue {
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

    fn genSetReg(self: *Function, src: usize, comptime arch: Target.Cpu.Arch, reg: Reg(arch), mcv: MCValue) error{ CodegenFail, OutOfMemory }!void {
        switch (arch) {
            .x86_64 => switch (mcv) {
                .none, .unreach => unreachable,
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
                        if (reg.isExtended()) {
                            // If we're accessing e.g. r8d, we need to use a REX prefix before the actual operation. Since
                            // this is a 32-bit operation, the W flag is set to zero. X is also zero, as we're not using a SIB.
                            // Both R and B are set, as we're extending, in effect, the register bits *and* the operand.
                            //
                            // From section 2.2.1.2 of the manual, REX is encoded as b0100WRXB. In this case, that's
                            // b01000101, or 0x45.
                            return self.code.appendSlice(&[_]u8{
                                0x45,
                                0x31,
                                0xC0 | (@as(u8, reg.id() & 0b111) << 3) | @truncate(u3, reg.id()),
                            });
                        } else {
                            return self.code.appendSlice(&[_]u8{
                                0x31,
                                0xC0 | (@as(u8, reg.id()) << 3) | reg.id(),
                            });
                        }
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
                    const REX = 0x48 | (if (reg.isExtended()) @as(u8, 0x01) else 0);
                    try self.code.resize(self.code.items.len + 10);
                    self.code.items[self.code.items.len - 10] = REX;
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
                    //
                    // 64-bit LEA is encoded as REX.W 8D /r. If the register is extended, the REX byte is modified,
                    // but the operation size is unchanged. Since we're using a disp32, we want mode 0 and lower three
                    // bits as five.
                    // REX 0x8D 0b00RRR101, where RRR is the lower three bits of the id.
                    try self.code.resize(self.code.items.len + 7);
                    const REX = 0x48 | if (reg.isExtended()) @as(u8, 1) else 0;
                    const rip = self.code.items.len;
                    const big_offset = @intCast(i64, code_offset) - @intCast(i64, rip);
                    const offset = @intCast(i32, big_offset);
                    self.code.items[self.code.items.len - 7] = REX;
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
                    // This is a varient of 8B /r. Since we're using 64-bit moves, we require a REX.
                    // This is thus three bytes: REX 0x8B R/M.
                    // If the destination is extended, the R field must be 1.
                    // If the *source* is extended, the B field must be 1.
                    // Since the register is being accessed directly, the R/M mode is three. The reg field (the middle
                    // three bits) contain the destination, and the R/M field (the lower three bits) contain the source.
                    const REX = 0x48 | (if (reg.isExtended()) @as(u8, 4) else 0) | (if (src_reg.isExtended()) @as(u8, 1) else 0);
                    const R = 0xC0 | (@as(u8, reg.id() & 0b111) << 3) | @truncate(u3, src_reg.id());
                    try self.code.appendSlice(&[_]u8{ REX, 0x8B, R });
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
                        try self.code.resize(self.code.items.len + 8);
                        const REX = 0x48 | if (reg.isExtended()) @as(u8, 1) else 0;
                        const r = 0x04 | (@as(u8, reg.id() & 0b111) << 3);
                        self.code.items[self.code.items.len - 8] = REX;
                        self.code.items[self.code.items.len - 7] = 0x8B;
                        self.code.items[self.code.items.len - 6] = r;
                        self.code.items[self.code.items.len - 5] = 0x25;
                        const imm_ptr = self.code.items[self.code.items.len - 4 ..][0..4];
                        mem.writeIntLittle(u32, imm_ptr, @intCast(u32, x));
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
                            //
                            // For this operation, we want R/M mode *zero* (use register indirectly), and the two register
                            // values must match. Thus, it's 00ABCABC where ABC is the lower three bits of the register ID.
                            //
                            // Furthermore, if this is an extended register, both B and R must be set in the REX byte, as *both*
                            // register operands need to be marked as extended.
                            const REX = 0x48 | if (reg.isExtended()) @as(u8, 0b0101) else 0;
                            const RM = (@as(u8, reg.id() & 0b111) << 3) | @truncate(u3, reg.id());
                            try self.code.appendSlice(&[_]u8{ REX, 0x8B, RM });
                        }
                    }
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
        if (self.inst_table.getValue(inst)) |mcv| {
            return mcv;
        }
        if (inst.cast(ir.Inst.Constant)) |const_inst| {
            const mcvalue = try self.genTypedValue(inst.src, .{ .ty = inst.ty, .val = const_inst.val });
            try self.inst_table.putNoClobber(inst, mcvalue);
            return mcvalue;
        } else {
            return self.inst_table.getValue(inst).?;
        }
    }

    fn genTypedValue(self: *Function, src: usize, typed_value: TypedValue) !MCValue {
        const ptr_bits = self.target.cpu.arch.ptrBitWidth();
        const ptr_bytes: u64 = @divExact(ptr_bits, 8);
        const allocator = self.code.allocator;
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
            .ComptimeInt => unreachable, // semantic analysis prevents this
            .ComptimeFloat => unreachable, // semantic analysis prevents this
            else => return self.fail(src, "TODO implement const of type '{}'", .{typed_value.ty}),
        }
    }

    fn fail(self: *Function, src: usize, comptime format: []const u8, args: var) error{ CodegenFail, OutOfMemory } {
        @setCold(true);
        assert(self.err_msg == null);
        self.err_msg = try ErrorMsg.create(self.code.allocator, src, format, args);
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
