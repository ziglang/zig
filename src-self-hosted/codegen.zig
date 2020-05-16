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
        return .unreach;
    }

    fn genCall(self: *Function, inst: *ir.Inst.Call) !MCValue {
        switch (self.target.cpu.arch) {
            else => return self.fail(inst.base.src, "TODO implement call for {}", .{self.target.cpu.arch}),
        }
        return .unreach;
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

    fn genSetReg(self: *Function, src: usize, comptime arch: Target.Cpu.Arch, reg: Reg(arch), mcv: MCValue) !void {
        switch (arch) {
            .x86_64 => switch (reg) {
                .rax => switch (mcv) {
                    .none, .unreach => unreachable,
                    .immediate => |x| {
                        // Setting the eax register zeroes the upper part of rax, so if the number is small
                        // enough, that is preferable.
                        // Best case: zero
                        // 31 c0     xor    eax,eax
                        if (x == 0) {
                            return self.code.appendSlice(&[_]u8{ 0x31, 0xc0 });
                        }
                        // Next best case: set eax with 4 bytes
                        // b8 04 03 02 01           mov    eax,0x01020304
                        if (x <= std.math.maxInt(u32)) {
                            try self.code.resize(self.code.items.len + 5);
                            self.code.items[self.code.items.len - 5] = 0xb8;
                            const imm_ptr = self.code.items[self.code.items.len - 4 ..][0..4];
                            mem.writeIntLittle(u32, imm_ptr, @intCast(u32, x));
                            return;
                        }
                        // Worst case: set rax with 8 bytes
                        // 48 b8 08 07 06 05 04 03 02 01    movabs rax,0x0102030405060708
                        try self.code.resize(self.code.items.len + 10);
                        self.code.items[self.code.items.len - 10] = 0x48;
                        self.code.items[self.code.items.len - 9] = 0xb8;
                        const imm_ptr = self.code.items[self.code.items.len - 8 ..][0..8];
                        mem.writeIntLittle(u64, imm_ptr, x);
                        return;
                    },
                    .embedded_in_code => return self.fail(src, "TODO implement x86_64 genSetReg %rax = embedded_in_code", .{}),
                    .register => return self.fail(src, "TODO implement x86_64 genSetReg %rax = register", .{}),
                    .memory => return self.fail(src, "TODO implement x86_64 genSetReg %rax = memory", .{}),
                },
                .rdx => switch (mcv) {
                    .none, .unreach => unreachable,
                    .immediate => |x| {
                        // Setting the edx register zeroes the upper part of rdx, so if the number is small
                        // enough, that is preferable.
                        // Best case: zero
                        // 31 d2                    xor    edx,edx
                        if (x == 0) {
                            return self.code.appendSlice(&[_]u8{ 0x31, 0xd2 });
                        }
                        // Next best case: set edx with 4 bytes
                        // ba 04 03 02 01           mov    edx,0x1020304
                        if (x <= std.math.maxInt(u32)) {
                            try self.code.resize(self.code.items.len + 5);
                            self.code.items[self.code.items.len - 5] = 0xba;
                            const imm_ptr = self.code.items[self.code.items.len - 4 ..][0..4];
                            mem.writeIntLittle(u32, imm_ptr, @intCast(u32, x));
                            return;
                        }
                        // Worst case: set rdx with 8 bytes
                        // 48 ba 08 07 06 05 04 03 02 01    movabs rdx,0x0102030405060708
                        try self.code.resize(self.code.items.len + 10);
                        self.code.items[self.code.items.len - 10] = 0x48;
                        self.code.items[self.code.items.len - 9] = 0xba;
                        const imm_ptr = self.code.items[self.code.items.len - 8 ..][0..8];
                        mem.writeIntLittle(u64, imm_ptr, x);
                        return;
                    },
                    .embedded_in_code => return self.fail(src, "TODO implement x86_64 genSetReg %rdx = embedded_in_code", .{}),
                    .register => return self.fail(src, "TODO implement x86_64 genSetReg %rdx = register", .{}),
                    .memory => return self.fail(src, "TODO implement x86_64 genSetReg %rdx = memory", .{}),
                },
                .rdi => switch (mcv) {
                    .none, .unreach => unreachable,
                    .immediate => |x| {
                        // Setting the edi register zeroes the upper part of rdi, so if the number is small
                        // enough, that is preferable.
                        // Best case: zero
                        // 31 ff                    xor    edi,edi
                        if (x == 0) {
                            return self.code.appendSlice(&[_]u8{ 0x31, 0xff });
                        }
                        // Next best case: set edi with 4 bytes
                        // bf 04 03 02 01           mov    edi,0x1020304
                        if (x <= std.math.maxInt(u32)) {
                            try self.code.resize(self.code.items.len + 5);
                            self.code.items[self.code.items.len - 5] = 0xbf;
                            const imm_ptr = self.code.items[self.code.items.len - 4 ..][0..4];
                            mem.writeIntLittle(u32, imm_ptr, @intCast(u32, x));
                            return;
                        }
                        // Worst case: set rdi with 8 bytes
                        // 48 bf 08 07 06 05 04 03 02 01    movabs rax,0x0102030405060708
                        try self.code.resize(self.code.items.len + 10);
                        self.code.items[self.code.items.len - 10] = 0x48;
                        self.code.items[self.code.items.len - 9] = 0xbf;
                        const imm_ptr = self.code.items[self.code.items.len - 8 ..][0..8];
                        mem.writeIntLittle(u64, imm_ptr, x);
                        return;
                    },
                    .embedded_in_code => return self.fail(src, "TODO implement x86_64 genSetReg %rdi = embedded_in_code", .{}),
                    .register => return self.fail(src, "TODO implement x86_64 genSetReg %rdi = register", .{}),
                    .memory => return self.fail(src, "TODO implement x86_64 genSetReg %rdi = memory", .{}),
                },
                .rsi => switch (mcv) {
                    .none, .unreach => unreachable,
                    .immediate => |x| {
                        // Setting the edi register zeroes the upper part of rdi, so if the number is small
                        // enough, that is preferable.
                        // Best case: zero
                        // 31 f6                    xor    esi,esi
                        if (x == 0) {
                            return self.code.appendSlice(&[_]u8{ 0x31, 0xf6 });
                        }
                        // Next best case: set esi with 4 bytes
                        // be 40 30 20 10           mov    esi,0x10203040
                        if (x <= std.math.maxInt(u32)) {
                            try self.code.resize(self.code.items.len + 5);
                            self.code.items[self.code.items.len - 5] = 0xbe;
                            const imm_ptr = self.code.items[self.code.items.len - 4 ..][0..4];
                            mem.writeIntLittle(u32, imm_ptr, @intCast(u32, x));
                            return;
                        }
                        // Worst case: set rsi with 8 bytes
                        // 48 be 80 70 60 50 40 30 20 10   movabs rsi,0x1020304050607080

                        try self.code.resize(self.code.items.len + 10);
                        self.code.items[self.code.items.len - 10] = 0x48;
                        self.code.items[self.code.items.len - 9] = 0xbe;
                        const imm_ptr = self.code.items[self.code.items.len - 8 ..][0..8];
                        mem.writeIntLittle(u64, imm_ptr, x);
                        return;
                    },
                    .embedded_in_code => |code_offset| {
                        // Examples:
                        // lea rsi, [rip + 0x01020304]
                        // lea rsi, [rip - 7]
                        //  f: 48 8d 35 04 03 02 01  lea    rsi,[rip+0x1020304]        # 102031a <_start+0x102031a>
                        // 16: 48 8d 35 f9 ff ff ff  lea    rsi,[rip+0xfffffffffffffff9]        # 16 <_start+0x16>
                        //
                        // We need the offset from RIP in a signed i32 twos complement.
                        // The instruction is 7 bytes long and RIP points to the next instruction.
                        try self.code.resize(self.code.items.len + 7);
                        const rip = self.code.items.len;
                        const big_offset = @intCast(i64, code_offset) - @intCast(i64, rip);
                        const offset = @intCast(i32, big_offset);
                        self.code.items[self.code.items.len - 7] = 0x48;
                        self.code.items[self.code.items.len - 6] = 0x8d;
                        self.code.items[self.code.items.len - 5] = 0x35;
                        const imm_ptr = self.code.items[self.code.items.len - 4 ..][0..4];
                        mem.writeIntLittle(i32, imm_ptr, offset);
                        return;
                    },
                    .register => return self.fail(src, "TODO implement x86_64 genSetReg %rsi = register", .{}),
                    .memory => |x| {
                        if (x <= std.math.maxInt(u32)) {
                            // 48 8b 34 25 40 30 20 10    mov    rsi,QWORD PTR ds:0x10203040
                            try self.code.resize(self.code.items.len + 8);
                            self.code.items[self.code.items.len - 8] = 0x48;
                            self.code.items[self.code.items.len - 7] = 0x8b;
                            self.code.items[self.code.items.len - 6] = 0x34;
                            self.code.items[self.code.items.len - 5] = 0x25;
                            const imm_ptr = self.code.items[self.code.items.len - 4 ..][0..4];
                            mem.writeIntLittle(u32, imm_ptr, @intCast(u32, x));
                            return;
                        } else {
                            return self.fail(src, "TODO implement genSetReg for x86_64 setting rsi to 64-bit memory", .{});
                        }
                    },
                },
                else => return self.fail(src, "TODO implement genSetReg for x86_64 '{}'", .{@tagName(reg)}),
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

fn Reg(comptime arch: Target.Cpu.Arch) type {
    return switch (arch) {
        .i386 => enum {
            eax,
            ebx,
            ecx,
            edx,
            ebp,
            esp,
            esi,
            edi,

            ax,
            bx,
            cx,
            dx,
            bp,
            sp,
            si,
            di,

            ah,
            bh,
            ch,
            dh,

            al,
            bl,
            cl,
            dl,
        },
        .x86_64 => enum {
            rax,
            rbx,
            rcx,
            rdx,
            rbp,
            rsp,
            rsi,
            rdi,
            r8,
            r9,
            r10,
            r11,
            r12,
            r13,
            r14,
            r15,

            eax,
            ebx,
            ecx,
            edx,
            ebp,
            esp,
            esi,
            edi,
            r8d,
            r9d,
            r10d,
            r11d,
            r12d,
            r13d,
            r14d,
            r15d,

            ax,
            bx,
            cx,
            dx,
            bp,
            sp,
            si,
            di,
            r8w,
            r9w,
            r10w,
            r11w,
            r12w,
            r13w,
            r14w,
            r15w,

            ah,
            bh,
            ch,
            dh,
            bph,
            sph,
            sih,
            dih,

            al,
            bl,
            cl,
            dl,
            bpl,
            spl,
            sil,
            dil,
            r8b,
            r9b,
            r10b,
            r11b,
            r12b,
            r13b,
            r14b,
            r15b,
        },
        else => @compileError("TODO add more register enums"),
    };
}

fn parseRegName(comptime arch: Target.Cpu.Arch, name: []const u8) ?Reg(arch) {
    return std.meta.stringToEnum(Reg(arch), name);
}
