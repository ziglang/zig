const std = @import("std");
const mem = std.mem;
const assert = std.debug.assert;
const ir = @import("ir.zig");
const Type = @import("type.zig").Type;
const Value = @import("value.zig").Value;
const Target = std.Target;

pub const ErrorMsg = struct {
    byte_offset: usize,
    msg: []const u8,
};

pub const Symbol = struct {
    errors: []ErrorMsg,

    pub fn deinit(self: *Symbol, allocator: *mem.Allocator) void {
        for (self.errors) |err| {
            allocator.free(err.msg);
        }
        allocator.free(self.errors);
        self.* = undefined;
    }
};

pub fn generateSymbol(typed_value: ir.TypedValue, module: ir.Module, code: *std.ArrayList(u8)) !Symbol {
    switch (typed_value.ty.zigTypeTag()) {
        .Fn => {
            const index = typed_value.val.cast(Value.Payload.Function).?.index;
            const module_fn = module.fns[index];

            var function = Function{
                .module = &module,
                .mod_fn = &module_fn,
                .code = code,
                .inst_table = std.AutoHashMap(*ir.Inst, Function.MCValue).init(code.allocator),
                .errors = std.ArrayList(ErrorMsg).init(code.allocator),
            };
            defer function.inst_table.deinit();
            defer function.errors.deinit();

            for (module_fn.body) |inst| {
                const new_inst = function.genFuncInst(inst) catch |err| switch (err) {
                    error.CodegenFail => {
                        assert(function.errors.items.len != 0);
                        break;
                    },
                    else => |e| return e,
                };
                try function.inst_table.putNoClobber(inst, new_inst);
            }

            return Symbol{ .errors = function.errors.toOwnedSlice() };
        },
        else => @panic("TODO implement generateSymbol for non-function types"),
    }
}

const Function = struct {
    module: *const ir.Module,
    mod_fn: *const ir.Module.Fn,
    code: *std.ArrayList(u8),
    inst_table: std.AutoHashMap(*ir.Inst, MCValue),
    errors: std.ArrayList(ErrorMsg),

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
    };

    fn genFuncInst(self: *Function, inst: *ir.Inst) !MCValue {
        switch (inst.tag) {
            .unreach => return self.genPanic(inst.src),
            .constant => unreachable, // excluded from function bodies
            .assembly => return self.genAsm(inst.cast(ir.Inst.Assembly).?),
            .ptrtoint => return self.genPtrToInt(inst.cast(ir.Inst.PtrToInt).?),
            .bitcast => return self.genBitCast(inst.cast(ir.Inst.BitCast).?),
        }
    }

    fn genPanic(self: *Function, src: usize) !MCValue {
        // TODO change this to call the panic function
        switch (self.module.target.cpu.arch) {
            .i386, .x86_64 => {
                try self.code.append(0xcc); // int3
            },
            else => return self.fail(src, "TODO implement panic for {}", .{self.module.target.cpu.arch}),
        }
        return .unreach;
    }

    fn genRet(self: *Function, src: usize) !void {
        // TODO change this to call the panic function
        switch (self.module.target.cpu.arch) {
            .i386, .x86_64 => {
                try self.code.append(0xc3); // ret
            },
            else => return self.fail(src, "TODO implement ret for {}", .{self.module.target.cpu.arch}),
        }
    }

    fn genRelativeFwdJump(self: *Function, src: usize, amount: u32) !void {
        switch (self.module.target.cpu.arch) {
            .i386, .x86_64 => {
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
            else => return self.fail(src, "TODO implement relative forward jump for {}", .{self.module.target.cpu.arch}),
        }
    }

    fn genAsm(self: *Function, inst: *ir.Inst.Assembly) !MCValue {
        // TODO convert to inline function
        switch (self.module.target.cpu.arch) {
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
                },
                .rsi => switch (mcv) {
                    .none, .unreach => unreachable,
                    .immediate => return self.fail(src, "TODO implement x86_64 genSetReg %rsi = immediate", .{}),
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

    fn genTypedValue(self: *Function, src: usize, typed_value: ir.TypedValue) !MCValue {
        switch (typed_value.ty.zigTypeTag()) {
            .Pointer => {
                const ptr_elem_type = typed_value.ty.elemType();
                switch (ptr_elem_type.zigTypeTag()) {
                    .Array => {
                        // TODO more checks to make sure this can be emitted as a string literal
                        const bytes = try typed_value.val.toAllocatedBytes(self.code.allocator);
                        defer self.code.allocator.free(bytes);
                        const smaller_len = std.math.cast(u32, bytes.len) catch
                            return self.fail(src, "TODO handle a larger string constant", .{});

                        // Emit the string literal directly into the code; jump over it.
                        try self.genRelativeFwdJump(src, smaller_len);
                        const offset = self.code.items.len;
                        try self.code.appendSlice(bytes);
                        return MCValue{ .embedded_in_code = offset };
                    },
                    else => |t| return self.fail(src, "TODO implement emitTypedValue for pointer to '{}'", .{@tagName(t)}),
                }
            },
            .Int => {
                const info = typed_value.ty.intInfo(self.module.target);
                const ptr_bits = self.module.target.cpu.arch.ptrBitWidth();
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
        const msg = try std.fmt.allocPrint(self.errors.allocator, format, args);
        {
            errdefer self.errors.allocator.free(msg);
            (try self.errors.addOne()).* = .{
                .byte_offset = src,
                .msg = msg,
            };
        }
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

            al,
            bl,
            cl,
            dl,
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
