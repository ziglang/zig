const std = @import("std");
const mem = std.mem;
const math = std.math;
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

pub const GenerateSymbolError = error{
    OutOfMemory,
    /// A Decl that this symbol depends on had a semantic analysis failure.
    AnalysisFail,
};

pub fn generateSymbol(
    bin_file: *link.File.Elf,
    src: usize,
    typed_value: TypedValue,
    code: *std.ArrayList(u8),
) GenerateSymbolError!Result {
    const tracy = trace(@src());
    defer tracy.end();

    switch (typed_value.ty.zigTypeTag()) {
        .Fn => {
            switch (bin_file.base.options.target.cpu.arch) {
                //.arm => return Function(.arm).generateSymbol(bin_file, src, typed_value, code),
                //.armeb => return Function(.armeb).generateSymbol(bin_file, src, typed_value, code),
                //.aarch64 => return Function(.aarch64).generateSymbol(bin_file, src, typed_value, code),
                //.aarch64_be => return Function(.aarch64_be).generateSymbol(bin_file, src, typed_value, code),
                //.aarch64_32 => return Function(.aarch64_32).generateSymbol(bin_file, src, typed_value, code),
                //.arc => return Function(.arc).generateSymbol(bin_file, src, typed_value, code),
                //.avr => return Function(.avr).generateSymbol(bin_file, src, typed_value, code),
                //.bpfel => return Function(.bpfel).generateSymbol(bin_file, src, typed_value, code),
                //.bpfeb => return Function(.bpfeb).generateSymbol(bin_file, src, typed_value, code),
                //.hexagon => return Function(.hexagon).generateSymbol(bin_file, src, typed_value, code),
                //.mips => return Function(.mips).generateSymbol(bin_file, src, typed_value, code),
                //.mipsel => return Function(.mipsel).generateSymbol(bin_file, src, typed_value, code),
                //.mips64 => return Function(.mips64).generateSymbol(bin_file, src, typed_value, code),
                //.mips64el => return Function(.mips64el).generateSymbol(bin_file, src, typed_value, code),
                //.msp430 => return Function(.msp430).generateSymbol(bin_file, src, typed_value, code),
                //.powerpc => return Function(.powerpc).generateSymbol(bin_file, src, typed_value, code),
                //.powerpc64 => return Function(.powerpc64).generateSymbol(bin_file, src, typed_value, code),
                //.powerpc64le => return Function(.powerpc64le).generateSymbol(bin_file, src, typed_value, code),
                //.r600 => return Function(.r600).generateSymbol(bin_file, src, typed_value, code),
                //.amdgcn => return Function(.amdgcn).generateSymbol(bin_file, src, typed_value, code),
                //.riscv32 => return Function(.riscv32).generateSymbol(bin_file, src, typed_value, code),
                //.riscv64 => return Function(.riscv64).generateSymbol(bin_file, src, typed_value, code),
                //.sparc => return Function(.sparc).generateSymbol(bin_file, src, typed_value, code),
                //.sparcv9 => return Function(.sparcv9).generateSymbol(bin_file, src, typed_value, code),
                //.sparcel => return Function(.sparcel).generateSymbol(bin_file, src, typed_value, code),
                //.s390x => return Function(.s390x).generateSymbol(bin_file, src, typed_value, code),
                //.tce => return Function(.tce).generateSymbol(bin_file, src, typed_value, code),
                //.tcele => return Function(.tcele).generateSymbol(bin_file, src, typed_value, code),
                //.thumb => return Function(.thumb).generateSymbol(bin_file, src, typed_value, code),
                //.thumbeb => return Function(.thumbeb).generateSymbol(bin_file, src, typed_value, code),
                //.i386 => return Function(.i386).generateSymbol(bin_file, src, typed_value, code),
                .x86_64 => return Function(.x86_64).generateSymbol(bin_file, src, typed_value, code),
                //.xcore => return Function(.xcore).generateSymbol(bin_file, src, typed_value, code),
                //.nvptx => return Function(.nvptx).generateSymbol(bin_file, src, typed_value, code),
                //.nvptx64 => return Function(.nvptx64).generateSymbol(bin_file, src, typed_value, code),
                //.le32 => return Function(.le32).generateSymbol(bin_file, src, typed_value, code),
                //.le64 => return Function(.le64).generateSymbol(bin_file, src, typed_value, code),
                //.amdil => return Function(.amdil).generateSymbol(bin_file, src, typed_value, code),
                //.amdil64 => return Function(.amdil64).generateSymbol(bin_file, src, typed_value, code),
                //.hsail => return Function(.hsail).generateSymbol(bin_file, src, typed_value, code),
                //.hsail64 => return Function(.hsail64).generateSymbol(bin_file, src, typed_value, code),
                //.spir => return Function(.spir).generateSymbol(bin_file, src, typed_value, code),
                //.spir64 => return Function(.spir64).generateSymbol(bin_file, src, typed_value, code),
                //.kalimba => return Function(.kalimba).generateSymbol(bin_file, src, typed_value, code),
                //.shave => return Function(.shave).generateSymbol(bin_file, src, typed_value, code),
                //.lanai => return Function(.lanai).generateSymbol(bin_file, src, typed_value, code),
                //.wasm32 => return Function(.wasm32).generateSymbol(bin_file, src, typed_value, code),
                //.wasm64 => return Function(.wasm64).generateSymbol(bin_file, src, typed_value, code),
                //.renderscript32 => return Function(.renderscript32).generateSymbol(bin_file, src, typed_value, code),
                //.renderscript64 => return Function(.renderscript64).generateSymbol(bin_file, src, typed_value, code),
                //.ve => return Function(.ve).generateSymbol(bin_file, src, typed_value, code),
                else => @panic("Backend architectures that don't have good support yet are commented out, to improve compilation performance. If you are interested in one of these other backends feel free to uncomment them. Eventually these will be completed, but stage1 is slow and a memory hog."),
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
                const endian = bin_file.base.options.target.cpu.arch.endian();
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
            const info = typed_value.ty.intInfo(bin_file.base.options.target);
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

fn Function(comptime arch: std.Target.Cpu.Arch) type {
    return struct {
        gpa: *Allocator,
        bin_file: *link.File.Elf,
        target: *const std.Target,
        mod_fn: *const Module.Fn,
        code: *std.ArrayList(u8),
        err_msg: ?*ErrorMsg,
        args: []MCValue,
        ret_mcv: MCValue,
        fn_type: Type,
        arg_index: usize,
        src: usize,
        stack_align: u32,

        /// The value is an offset into the `Function` `code` from the beginning.
        /// To perform the reloc, write 32-bit signed little-endian integer
        /// which is a relative jump, based on the address following the reloc.
        exitlude_jump_relocs: std.ArrayListUnmanaged(usize) = .{},

        /// Whenever there is a runtime branch, we push a Branch onto this stack,
        /// and pop it off when the runtime branch joins. This provides an "overlay"
        /// of the table of mappings from instructions to `MCValue` from within the branch.
        /// This way we can modify the `MCValue` for an instruction in different ways
        /// within different branches. Special consideration is needed when a branch
        /// joins with its parent, to make sure all instructions have the same MCValue
        /// across each runtime branch upon joining.
        branch_stack: *std.ArrayList(Branch),

        const MCValue = union(enum) {
            /// No runtime bits. `void` types, empty structs, u0, enums with 1 tag, etc.
            none,
            /// Control flow will not allow this value to be observed.
            unreach,
            /// No more references to this value remain.
            dead,
            /// The value is undefined.
            undef,
            /// A pointer-sized integer that fits in a register.
            /// If the type is a pointer, this is the pointer address in virtual address space.
            immediate: u64,
            /// The constant was emitted into the code, at this offset.
            /// If the type is a pointer, it means the pointer address is embedded in the code.
            embedded_in_code: usize,
            /// The value is a pointer to a constant which was emitted into the code, at this offset.
            ptr_embedded_in_code: usize,
            /// The value is in a target-specific register.
            register: Register,
            /// The value is in memory at a hard-coded address.
            /// If the type is a pointer, it means the pointer address is at this memory location.
            memory: u64,
            /// The value is one of the stack variables.
            /// If the type is a pointer, it means the pointer address is in the stack at this offset.
            stack_offset: u32,
            /// The value is a pointer to one of the stack variables (payload is stack offset).
            ptr_stack_offset: u32,
            /// The value is in the compare flags assuming an unsigned operation,
            /// with this operator applied on top of it.
            compare_flags_unsigned: math.CompareOperator,
            /// The value is in the compare flags assuming a signed operation,
            /// with this operator applied on top of it.
            compare_flags_signed: math.CompareOperator,

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
                    .ptr_stack_offset,
                    .ptr_embedded_in_code,
                    .undef,
                    => false,

                    .register,
                    .stack_offset,
                    => true,
                };
            }
        };

        const Branch = struct {
            inst_table: std.AutoHashMapUnmanaged(*ir.Inst, MCValue) = .{},
            registers: std.AutoHashMapUnmanaged(Register, RegisterAllocation) = .{},
            free_registers: FreeRegInt = math.maxInt(FreeRegInt),

            /// Maps offset to what is stored there.
            stack: std.AutoHashMapUnmanaged(u32, StackAllocation) = .{},
            /// Offset from the stack base, representing the end of the stack frame.
            max_end_stack: u32 = 0,
            /// Represents the current end stack offset. If there is no existing slot
            /// to place a new stack allocation, it goes here, and then bumps `max_end_stack`.
            next_stack_offset: u32 = 0,

            fn markRegUsed(self: *Branch, reg: Register) void {
                if (FreeRegInt == u0) return;
                const index = reg.allocIndex() orelse return;
                const ShiftInt = math.Log2Int(FreeRegInt);
                const shift = @intCast(ShiftInt, index);
                self.free_registers &= ~(@as(FreeRegInt, 1) << shift);
            }

            fn markRegFree(self: *Branch, reg: Register) void {
                if (FreeRegInt == u0) return;
                const index = reg.allocIndex() orelse return;
                const ShiftInt = math.Log2Int(FreeRegInt);
                const shift = @intCast(ShiftInt, index);
                self.free_registers |= @as(FreeRegInt, 1) << shift;
            }

            /// Before calling, must ensureCapacity + 1 on branch.registers.
            /// Returns `null` if all registers are allocated.
            fn allocReg(self: *Branch, inst: *ir.Inst) ?Register {
                const free_index = @ctz(FreeRegInt, self.free_registers);
                if (free_index >= callee_preserved_regs.len) {
                    return null;
                }
                self.free_registers &= ~(@as(FreeRegInt, 1) << free_index);
                const reg = callee_preserved_regs[free_index];
                self.registers.putAssumeCapacityNoClobber(reg, .{ .inst = inst });
                return reg;
            }

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

        const Self = @This();

        fn generateSymbol(
            bin_file: *link.File.Elf,
            src: usize,
            typed_value: TypedValue,
            code: *std.ArrayList(u8),
        ) GenerateSymbolError!Result {
            const module_fn = typed_value.val.cast(Value.Payload.Function).?.func;

            const fn_type = module_fn.owner_decl.typed_value.most_recent.typed_value.ty;

            var branch_stack = std.ArrayList(Branch).init(bin_file.allocator);
            defer {
                assert(branch_stack.items.len == 1);
                branch_stack.items[0].deinit(bin_file.allocator);
                branch_stack.deinit();
            }
            const branch = try branch_stack.addOne();
            branch.* = .{};

            var function = Self{
                .gpa = bin_file.allocator,
                .target = &bin_file.base.options.target,
                .bin_file = bin_file,
                .mod_fn = module_fn,
                .code = code,
                .err_msg = null,
                .args = undefined, // populated after `resolveCallingConventionValues`
                .ret_mcv = undefined, // populated after `resolveCallingConventionValues`
                .fn_type = fn_type,
                .arg_index = 0,
                .branch_stack = &branch_stack,
                .src = src,
                .stack_align = undefined,
            };
            defer function.exitlude_jump_relocs.deinit(bin_file.allocator);

            var call_info = function.resolveCallingConventionValues(src, fn_type) catch |err| switch (err) {
                error.CodegenFail => return Result{ .fail = function.err_msg.? },
                else => |e| return e,
            };
            defer call_info.deinit(&function);

            function.args = call_info.args;
            function.ret_mcv = call_info.return_value;
            function.stack_align = call_info.stack_align;
            branch.max_end_stack = call_info.stack_byte_count;

            function.gen() catch |err| switch (err) {
                error.CodegenFail => return Result{ .fail = function.err_msg.? },
                else => |e| return e,
            };

            if (function.err_msg) |em| {
                return Result{ .fail = em };
            } else {
                return Result{ .appended = {} };
            }
        }

        fn gen(self: *Self) !void {
            switch (arch) {
                .x86_64 => {
                    try self.code.ensureCapacity(self.code.items.len + 11);

                    const cc = self.fn_type.fnCallingConvention();
                    if (cc != .Naked) {
                        // We want to subtract the aligned stack frame size from rsp here, but we don't
                        // yet know how big it will be, so we leave room for a 4-byte stack size.
                        // TODO During semantic analysis, check if there are no function calls. If there
                        // are none, here we can omit the part where we subtract and then add rsp.
                        self.code.appendSliceAssumeCapacity(&[_]u8{
                            // push rbp
                            0x55,
                            // mov rbp, rsp
                            0x48,
                            0x89,
                            0xe5,
                            // sub rsp, imm32 (with reloc)
                            0x48,
                            0x81,
                            0xec,
                        });
                        const reloc_index = self.code.items.len;
                        self.code.items.len += 4;

                        try self.genBody(self.mod_fn.analysis.success);

                        const stack_end = self.branch_stack.items[0].max_end_stack;
                        if (stack_end > math.maxInt(i32))
                            return self.fail(self.src, "too much stack used in call parameters", .{});
                        const aligned_stack_end = mem.alignForward(stack_end, self.stack_align);
                        mem.writeIntLittle(u32, self.code.items[reloc_index..][0..4], @intCast(u32, aligned_stack_end));

                        if (self.code.items.len >= math.maxInt(i32)) {
                            return self.fail(self.src, "unable to perform relocation: jump too far", .{});
                        }
                        for (self.exitlude_jump_relocs.items) |jmp_reloc| {
                            const amt = self.code.items.len - (jmp_reloc + 4);
                            // If it wouldn't jump at all, elide it.
                            if (amt == 0) {
                                self.code.items.len -= 5;
                                continue;
                            }
                            const s32_amt = @intCast(i32, amt);
                            mem.writeIntLittle(i32, self.code.items[jmp_reloc..][0..4], s32_amt);
                        }

                        try self.code.ensureCapacity(self.code.items.len + 9);
                        // add rsp, x
                        if (aligned_stack_end > math.maxInt(i8)) {
                            // example: 48 81 c4 ff ff ff 7f  add    rsp,0x7fffffff
                            self.code.appendSliceAssumeCapacity(&[_]u8{ 0x48, 0x81, 0xc4 });
                            const x = @intCast(u32, aligned_stack_end);
                            mem.writeIntLittle(u32, self.code.addManyAsArrayAssumeCapacity(4), x);
                        } else if (aligned_stack_end != 0) {
                            // example: 48 83 c4 7f           add    rsp,0x7f
                            const x = @intCast(u8, aligned_stack_end);
                            self.code.appendSliceAssumeCapacity(&[_]u8{ 0x48, 0x83, 0xc4, x });
                        }

                        self.code.appendSliceAssumeCapacity(&[_]u8{
                            0x5d, // pop rbp
                            0xc3, // ret
                        });
                    } else {
                        try self.genBody(self.mod_fn.analysis.success);
                    }
                },
                else => {
                    try self.genBody(self.mod_fn.analysis.success);
                },
            }
        }

        fn genBody(self: *Self, body: ir.Body) InnerError!void {
            const inst_table = &self.branch_stack.items[0].inst_table;
            for (body.instructions) |inst| {
                const new_inst = try self.genFuncInst(inst);
                try inst_table.putNoClobber(self.gpa, inst, new_inst);

                var i: ir.Inst.DeathsBitIndex = 0;
                while (inst.getOperand(i)) |operand| : (i += 1) {
                    if (inst.operandDies(i))
                        self.processDeath(operand);
                }
            }
        }

        fn processDeath(self: *Self, inst: *ir.Inst) void {
            const branch = &self.branch_stack.items[self.branch_stack.items.len - 1];
            const entry = branch.inst_table.getEntry(inst) orelse return;
            const prev_value = entry.value;
            entry.value = .dead;
            switch (prev_value) {
                .register => |reg| {
                    const reg64 = reg.to64();
                    _ = branch.registers.remove(reg64);
                    branch.markRegFree(reg64);
                },
                else => {}, // TODO process stack allocation death
            }
        }

        fn genFuncInst(self: *Self, inst: *ir.Inst) !MCValue {
            switch (inst.tag) {
                .add => return self.genAdd(inst.castTag(.add).?),
                .alloc => return self.genAlloc(inst.castTag(.alloc).?),
                .arg => return self.genArg(inst.castTag(.arg).?),
                .assembly => return self.genAsm(inst.castTag(.assembly).?),
                .bitcast => return self.genBitCast(inst.castTag(.bitcast).?),
                .block => return self.genBlock(inst.castTag(.block).?),
                .br => return self.genBr(inst.castTag(.br).?),
                .breakpoint => return self.genBreakpoint(inst.src),
                .brvoid => return self.genBrVoid(inst.castTag(.brvoid).?),
                .call => return self.genCall(inst.castTag(.call).?),
                .cmp_lt => return self.genCmp(inst.castTag(.cmp_lt).?, .lt),
                .cmp_lte => return self.genCmp(inst.castTag(.cmp_lte).?, .lte),
                .cmp_eq => return self.genCmp(inst.castTag(.cmp_eq).?, .eq),
                .cmp_gte => return self.genCmp(inst.castTag(.cmp_gte).?, .gte),
                .cmp_gt => return self.genCmp(inst.castTag(.cmp_gt).?, .gt),
                .cmp_neq => return self.genCmp(inst.castTag(.cmp_neq).?, .neq),
                .condbr => return self.genCondBr(inst.castTag(.condbr).?),
                .constant => unreachable, // excluded from function bodies
                .floatcast => return self.genFloatCast(inst.castTag(.floatcast).?),
                .intcast => return self.genIntCast(inst.castTag(.intcast).?),
                .isnonnull => return self.genIsNonNull(inst.castTag(.isnonnull).?),
                .isnull => return self.genIsNull(inst.castTag(.isnull).?),
                .load => return self.genLoad(inst.castTag(.load).?),
                .not => return self.genNot(inst.castTag(.not).?),
                .ptrtoint => return self.genPtrToInt(inst.castTag(.ptrtoint).?),
                .ref => return self.genRef(inst.castTag(.ref).?),
                .ret => return self.genRet(inst.castTag(.ret).?),
                .retvoid => return self.genRetVoid(inst.castTag(.retvoid).?),
                .store => return self.genStore(inst.castTag(.store).?),
                .sub => return self.genSub(inst.castTag(.sub).?),
                .unreach => return MCValue{ .unreach = {} },
            }
        }

        fn allocMem(self: *Self, inst: *ir.Inst, abi_size: u32, abi_align: u32) !u32 {
            if (abi_align > self.stack_align)
                self.stack_align = abi_align;
            const branch = &self.branch_stack.items[self.branch_stack.items.len - 1];
            // TODO find a free slot instead of always appending
            const offset = mem.alignForwardGeneric(u32, branch.next_stack_offset, abi_align);
            branch.next_stack_offset = offset + abi_size;
            if (branch.next_stack_offset > branch.max_end_stack)
                branch.max_end_stack = branch.next_stack_offset;
            try branch.stack.putNoClobber(self.gpa, offset, .{
                .inst = inst,
                .size = abi_size,
            });
            return offset;
        }

        /// Use a pointer instruction as the basis for allocating stack memory.
        fn allocMemPtr(self: *Self, inst: *ir.Inst) !u32 {
            const elem_ty = inst.ty.elemType();
            const abi_size = math.cast(u32, elem_ty.abiSize(self.target.*)) catch {
                return self.fail(inst.src, "type '{}' too big to fit into stack frame", .{elem_ty});
            };
            // TODO swap this for inst.ty.ptrAlign
            const abi_align = elem_ty.abiAlignment(self.target.*);
            return self.allocMem(inst, abi_size, abi_align);
        }

        fn allocRegOrMem(self: *Self, inst: *ir.Inst) !MCValue {
            const elem_ty = inst.ty;
            const abi_size = math.cast(u32, elem_ty.abiSize(self.target.*)) catch {
                return self.fail(inst.src, "type '{}' too big to fit into stack frame", .{elem_ty});
            };
            const abi_align = elem_ty.abiAlignment(self.target.*);
            if (abi_align > self.stack_align)
                self.stack_align = abi_align;
            const branch = &self.branch_stack.items[self.branch_stack.items.len - 1];

            // Make sure the type can fit in a register before we try to allocate one.
            const ptr_bits = arch.ptrBitWidth();
            const ptr_bytes: u64 = @divExact(ptr_bits, 8);
            if (abi_size <= ptr_bytes) {
                try branch.registers.ensureCapacity(self.gpa, branch.registers.items().len + 1);
                if (branch.allocReg(inst)) |reg| {
                    return MCValue{ .register = registerAlias(reg, abi_size) };
                }
            }
            const stack_offset = try self.allocMem(inst, abi_size, abi_align);
            return MCValue{ .stack_offset = stack_offset };
        }

        /// Does not "move" the instruction.
        fn copyToNewRegister(self: *Self, inst: *ir.Inst) !MCValue {
            const branch = &self.branch_stack.items[self.branch_stack.items.len - 1];
            try branch.registers.ensureCapacity(self.gpa, branch.registers.items().len + 1);

            const reg = branch.allocReg(inst) orelse
                return self.fail(inst.src, "TODO implement spilling register to stack", .{});
            const old_mcv = branch.inst_table.get(inst).?;
            const new_mcv: MCValue = .{ .register = reg };
            try self.genSetReg(inst.src, reg, old_mcv);
            return new_mcv;
        }

        fn genAlloc(self: *Self, inst: *ir.Inst.NoOp) !MCValue {
            const stack_offset = try self.allocMemPtr(&inst.base);
            return MCValue{ .ptr_stack_offset = stack_offset };
        }

        fn genFloatCast(self: *Self, inst: *ir.Inst.UnOp) !MCValue {
            // No side effects, so if it's unreferenced, do nothing.
            if (inst.base.isUnused())
                return MCValue.dead;
            switch (arch) {
                else => return self.fail(inst.base.src, "TODO implement floatCast for {}", .{self.target.cpu.arch}),
            }
        }

        fn genIntCast(self: *Self, inst: *ir.Inst.UnOp) !MCValue {
            // No side effects, so if it's unreferenced, do nothing.
            if (inst.base.isUnused())
                return MCValue.dead;
            switch (arch) {
                else => return self.fail(inst.base.src, "TODO implement intCast for {}", .{self.target.cpu.arch}),
            }
        }

        fn genNot(self: *Self, inst: *ir.Inst.UnOp) !MCValue {
            // No side effects, so if it's unreferenced, do nothing.
            if (inst.base.isUnused())
                return MCValue.dead;
            const operand = try self.resolveInst(inst.operand);
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
                            .ty = inst.operand.ty,
                            .src = inst.operand.src,
                        },
                        .val = Value.initTag(.bool_true),
                    };
                    return try self.genX8664BinMath(&inst.base, inst.operand, &imm.base, 6, 0x30);
                },
                else => return self.fail(inst.base.src, "TODO implement NOT for {}", .{self.target.cpu.arch}),
            }
        }

        fn genAdd(self: *Self, inst: *ir.Inst.BinOp) !MCValue {
            // No side effects, so if it's unreferenced, do nothing.
            if (inst.base.isUnused())
                return MCValue.dead;
            switch (arch) {
                .x86_64 => {
                    return try self.genX8664BinMath(&inst.base, inst.lhs, inst.rhs, 0, 0x00);
                },
                else => return self.fail(inst.base.src, "TODO implement add for {}", .{self.target.cpu.arch}),
            }
        }

        fn genLoad(self: *Self, inst: *ir.Inst.UnOp) !MCValue {
            const elem_ty = inst.base.ty;
            if (!elem_ty.hasCodeGenBits())
                return MCValue.none;
            const ptr = try self.resolveInst(inst.operand);
            const is_volatile = inst.operand.ty.isVolatilePtr();
            if (inst.base.isUnused() and !is_volatile)
                return MCValue.dead;
            const dst_mcv: MCValue = blk: {
                if (inst.base.operandDies(0) and ptr.isMutable()) {
                    // The MCValue that holds the pointer can be re-used as the value.
                    // TODO track this in the register/stack allocation metadata.
                    break :blk ptr;
                } else {
                    break :blk try self.allocRegOrMem(&inst.base);
                }
            };
            switch (ptr) {
                .none => unreachable,
                .undef => unreachable,
                .unreach => unreachable,
                .dead => unreachable,
                .compare_flags_unsigned => unreachable,
                .compare_flags_signed => unreachable,
                .immediate => |imm| try self.setRegOrMem(inst.base.src, elem_ty, dst_mcv, .{ .memory = imm }),
                .ptr_stack_offset => |off| try self.setRegOrMem(inst.base.src, elem_ty, dst_mcv, .{ .stack_offset = off }),
                .ptr_embedded_in_code => |off| {
                    try self.setRegOrMem(inst.base.src, elem_ty, dst_mcv, .{ .embedded_in_code = off });
                },
                .embedded_in_code => {
                    return self.fail(inst.base.src, "TODO implement loading from MCValue.embedded_in_code", .{});
                },
                .register => {
                    return self.fail(inst.base.src, "TODO implement loading from MCValue.register", .{});
                },
                .memory => {
                    return self.fail(inst.base.src, "TODO implement loading from MCValue.memory", .{});
                },
                .stack_offset => {
                    return self.fail(inst.base.src, "TODO implement loading from MCValue.stack_offset", .{});
                },
            }
            return dst_mcv;
        }

        fn genStore(self: *Self, inst: *ir.Inst.BinOp) !MCValue {
            const ptr = try self.resolveInst(inst.lhs);
            const value = try self.resolveInst(inst.rhs);
            const elem_ty = inst.rhs.ty;
            switch (ptr) {
                .none => unreachable,
                .undef => unreachable,
                .unreach => unreachable,
                .dead => unreachable,
                .compare_flags_unsigned => unreachable,
                .compare_flags_signed => unreachable,
                .immediate => |imm| {
                    try self.setRegOrMem(inst.base.src, elem_ty, .{ .memory = imm }, value);
                },
                .ptr_stack_offset => |off| {
                    try self.genSetStack(inst.base.src, elem_ty, off, value);
                },
                .ptr_embedded_in_code => |off| {
                    try self.setRegOrMem(inst.base.src, elem_ty, .{ .embedded_in_code = off }, value);
                },
                .embedded_in_code => {
                    return self.fail(inst.base.src, "TODO implement storing to MCValue.embedded_in_code", .{});
                },
                .register => {
                    return self.fail(inst.base.src, "TODO implement storing to MCValue.register", .{});
                },
                .memory => {
                    return self.fail(inst.base.src, "TODO implement storing to MCValue.memory", .{});
                },
                .stack_offset => {
                    return self.fail(inst.base.src, "TODO implement storing to MCValue.stack_offset", .{});
                },
            }
            return .none;
        }

        fn genSub(self: *Self, inst: *ir.Inst.BinOp) !MCValue {
            // No side effects, so if it's unreferenced, do nothing.
            if (inst.base.isUnused())
                return MCValue.dead;
            switch (arch) {
                .x86_64 => {
                    return try self.genX8664BinMath(&inst.base, inst.lhs, inst.rhs, 5, 0x28);
                },
                else => return self.fail(inst.base.src, "TODO implement sub for {}", .{self.target.cpu.arch}),
            }
        }

        /// ADD, SUB, XOR, OR, AND
        fn genX8664BinMath(self: *Self, inst: *ir.Inst, op_lhs: *ir.Inst, op_rhs: *ir.Inst, opx: u8, mr: u8) !MCValue {
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
                    if (imm > math.maxInt(u31)) {
                        src_mcv = try self.copyToNewRegister(src_inst);
                    }
                },
                else => {},
            }

            try self.genX8664BinMathCode(inst.src, dst_mcv, src_mcv, opx, mr);

            return dst_mcv;
        }

        fn genX8664BinMathCode(self: *Self, src: usize, dst_mcv: MCValue, src_mcv: MCValue, opx: u8, mr: u8) !void {
            switch (dst_mcv) {
                .none => unreachable,
                .undef => unreachable,
                .dead, .unreach, .immediate => unreachable,
                .compare_flags_unsigned => unreachable,
                .compare_flags_signed => unreachable,
                .ptr_stack_offset => unreachable,
                .ptr_embedded_in_code => unreachable,
                .register => |dst_reg| {
                    switch (src_mcv) {
                        .none => unreachable,
                        .undef => try self.genSetReg(src, dst_reg, .undef),
                        .dead, .unreach => unreachable,
                        .ptr_stack_offset => unreachable,
                        .ptr_embedded_in_code => unreachable,
                        .register => |src_reg| {
                            self.rex(.{ .b = dst_reg.isExtended(), .r = src_reg.isExtended(), .w = dst_reg.size() == 64 });
                            self.code.appendSliceAssumeCapacity(&[_]u8{ mr + 0x1, 0xC0 | (@as(u8, src_reg.id() & 0b111) << 3) | @as(u8, dst_reg.id() & 0b111) });
                        },
                        .immediate => |imm| {
                            const imm32 = @intCast(u31, imm); // This case must be handled before calling genX8664BinMathCode.
                            // 81 /opx id
                            if (imm32 <= math.maxInt(u7)) {
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

        fn genArg(self: *Self, inst: *ir.Inst.NoOp) !MCValue {
            if (FreeRegInt == u0) {
                return self.fail(inst.base.src, "TODO implement Register enum for {}", .{self.target.cpu.arch});
            }
            if (inst.base.isUnused())
                return MCValue.dead;

            const branch = &self.branch_stack.items[self.branch_stack.items.len - 1];
            try branch.registers.ensureCapacity(self.gpa, branch.registers.items().len + 1);

            const result = self.args[self.arg_index];
            self.arg_index += 1;

            switch (result) {
                .register => |reg| {
                    branch.registers.putAssumeCapacityNoClobber(reg, .{ .inst = &inst.base });
                    branch.markRegUsed(reg);
                },
                else => {},
            }
            return result;
        }

        fn genBreakpoint(self: *Self, src: usize) !MCValue {
            switch (arch) {
                .i386, .x86_64 => {
                    try self.code.append(0xcc); // int3
                },
                else => return self.fail(src, "TODO implement @breakpoint() for {}", .{self.target.cpu.arch}),
            }
            return .none;
        }

        fn genCall(self: *Self, inst: *ir.Inst.Call) !MCValue {
            var info = try self.resolveCallingConventionValues(inst.base.src, inst.func.ty);
            defer info.deinit(self);

            switch (arch) {
                .x86_64 => {
                    for (info.args) |mc_arg, arg_i| {
                        const arg = inst.args[arg_i];
                        const arg_mcv = try self.resolveInst(inst.args[arg_i]);
                        // Here we do not use setRegOrMem even though the logic is similar, because
                        // the function call will move the stack pointer, so the offsets are different.
                        switch (mc_arg) {
                            .none => continue,
                            .register => |reg| {
                                try self.genSetReg(arg.src, reg, arg_mcv);
                                // TODO interact with the register allocator to mark the instruction as moved.
                            },
                            .stack_offset => {
                                // Here we need to emit instructions like this:
                                // mov     qword ptr [rsp + stack_offset], x
                                return self.fail(inst.base.src, "TODO implement calling with parameters in memory", .{});
                            },
                            .ptr_stack_offset => {
                                return self.fail(inst.base.src, "TODO implement calling with MCValue.ptr_stack_offset arg", .{});
                            },
                            .ptr_embedded_in_code => {
                                return self.fail(inst.base.src, "TODO implement calling with MCValue.ptr_embedded_in_code arg", .{});
                            },
                            .undef => unreachable,
                            .immediate => unreachable,
                            .unreach => unreachable,
                            .dead => unreachable,
                            .embedded_in_code => unreachable,
                            .memory => unreachable,
                            .compare_flags_signed => unreachable,
                            .compare_flags_unsigned => unreachable,
                        }
                    }

                    if (inst.func.cast(ir.Inst.Constant)) |func_inst| {
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

            return info.return_value;
        }

        fn genRef(self: *Self, inst: *ir.Inst.UnOp) !MCValue {
            const operand = try self.resolveInst(inst.operand);
            switch (operand) {
                .unreach => unreachable,
                .dead => unreachable,
                .none => return .none,

                .immediate,
                .register,
                .ptr_stack_offset,
                .ptr_embedded_in_code,
                .compare_flags_unsigned,
                .compare_flags_signed,
                => {
                    const stack_offset = try self.allocMemPtr(&inst.base);
                    try self.genSetStack(inst.base.src, inst.operand.ty, stack_offset, operand);
                    return MCValue{ .ptr_stack_offset = stack_offset };
                },

                .stack_offset => |offset| return MCValue{ .ptr_stack_offset = offset },
                .embedded_in_code => |offset| return MCValue{ .ptr_embedded_in_code = offset },
                .memory => |vaddr| return MCValue{ .immediate = vaddr },

                .undef => return self.fail(inst.base.src, "TODO implement ref on an undefined value", .{}),
            }
        }

        fn ret(self: *Self, src: usize, mcv: MCValue) !MCValue {
            const ret_ty = self.fn_type.fnReturnType();
            try self.setRegOrMem(src, ret_ty, self.ret_mcv, mcv);
            switch (arch) {
                .i386 => {
                    try self.code.append(0xc3); // ret
                },
                .x86_64 => {
                    // TODO when implementing defer, this will need to jump to the appropriate defer expression.
                    // TODO optimization opportunity: figure out when we can emit this as a 2 byte instruction
                    // which is available if the jump is 127 bytes or less forward.
                    try self.code.resize(self.code.items.len + 5);
                    self.code.items[self.code.items.len - 5] = 0xe9; // jmp rel32
                    try self.exitlude_jump_relocs.append(self.gpa, self.code.items.len - 4);
                },
                else => return self.fail(src, "TODO implement return for {}", .{self.target.cpu.arch}),
            }
            return .unreach;
        }

        fn genRet(self: *Self, inst: *ir.Inst.UnOp) !MCValue {
            const operand = try self.resolveInst(inst.operand);
            return self.ret(inst.base.src, operand);
        }

        fn genRetVoid(self: *Self, inst: *ir.Inst.NoOp) !MCValue {
            return self.ret(inst.base.src, .none);
        }

        fn genCmp(self: *Self, inst: *ir.Inst.BinOp, op: math.CompareOperator) !MCValue {
            // No side effects, so if it's unreferenced, do nothing.
            if (inst.base.isUnused())
                return MCValue.dead;
            switch (arch) {
                .x86_64 => {
                    try self.code.ensureCapacity(self.code.items.len + 8);

                    const lhs = try self.resolveInst(inst.lhs);
                    const rhs = try self.resolveInst(inst.rhs);

                    // There are 2 operands, destination and source.
                    // Either one, but not both, can be a memory operand.
                    // Source operand can be an immediate, 8 bits or 32 bits.
                    const dst_mcv = if (lhs.isImmediate() or (lhs.isMemory() and rhs.isMemory()))
                        try self.copyToNewRegister(inst.lhs)
                    else
                        lhs;
                    // This instruction supports only signed 32-bit immediates at most.
                    const src_mcv = try self.limitImmediateType(inst.rhs, i32);

                    try self.genX8664BinMathCode(inst.base.src, dst_mcv, src_mcv, 7, 0x38);
                    const info = inst.lhs.ty.intInfo(self.target.*);
                    if (info.signed) {
                        return MCValue{ .compare_flags_signed = op };
                    } else {
                        return MCValue{ .compare_flags_unsigned = op };
                    }
                },
                else => return self.fail(inst.base.src, "TODO implement cmp for {}", .{self.target.cpu.arch}),
            }
        }

        fn genCondBr(self: *Self, inst: *ir.Inst.CondBr) !MCValue {
            switch (arch) {
                .x86_64 => {
                    try self.code.ensureCapacity(self.code.items.len + 6);

                    const cond = try self.resolveInst(inst.condition);
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
                            return self.genX86CondBr(inst, opcode);
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
                            return self.genX86CondBr(inst, opcode);
                        },
                        .register => |reg| {
                            // test reg, 1
                            // TODO detect al, ax, eax
                            try self.code.ensureCapacity(self.code.items.len + 4);
                            // TODO audit this codegen: we force w = true here to make
                            // the value affect the big register
                            self.rex(.{ .b = reg.isExtended(), .w = true });
                            self.code.appendSliceAssumeCapacity(&[_]u8{
                                0xf6,
                                @as(u8, 0xC0) | (0 << 3) | @truncate(u3, reg.id()),
                                0x01,
                            });
                            return self.genX86CondBr(inst, 0x84);
                        },
                        else => return self.fail(inst.base.src, "TODO implement condbr {} when condition is {}", .{ self.target.cpu.arch, @tagName(cond) }),
                    }
                },
                else => return self.fail(inst.base.src, "TODO implement condbr for {}", .{self.target.cpu.arch}),
            }
        }

        fn genX86CondBr(self: *Self, inst: *ir.Inst.CondBr, opcode: u8) !MCValue {
            self.code.appendSliceAssumeCapacity(&[_]u8{ 0x0f, opcode });
            const reloc = Reloc{ .rel32 = self.code.items.len };
            self.code.items.len += 4;
            try self.genBody(inst.then_body);
            try self.performReloc(inst.base.src, reloc);
            try self.genBody(inst.else_body);
            return MCValue.unreach;
        }

        fn genIsNull(self: *Self, inst: *ir.Inst.UnOp) !MCValue {
            switch (arch) {
                else => return self.fail(inst.base.src, "TODO implement isnull for {}", .{self.target.cpu.arch}),
            }
        }

        fn genIsNonNull(self: *Self, inst: *ir.Inst.UnOp) !MCValue {
            // Here you can specialize this instruction if it makes sense to, otherwise the default
            // will call genIsNull and invert the result.
            switch (arch) {
                else => return self.fail(inst.base.src, "TODO call genIsNull and invert the result ", .{}),
            }
        }

        fn genBlock(self: *Self, inst: *ir.Inst.Block) !MCValue {
            if (inst.base.ty.hasCodeGenBits()) {
                return self.fail(inst.base.src, "TODO codegen Block with non-void type", .{});
            }
            // A block is nothing but a setup to be able to jump to the end.
            defer inst.codegen.relocs.deinit(self.gpa);
            try self.genBody(inst.body);

            for (inst.codegen.relocs.items) |reloc| try self.performReloc(inst.base.src, reloc);

            return MCValue.none;
        }

        fn performReloc(self: *Self, src: usize, reloc: Reloc) !void {
            switch (reloc) {
                .rel32 => |pos| {
                    const amt = self.code.items.len - (pos + 4);
                    // If it wouldn't jump at all, elide it.
                    if (amt == 0) {
                        self.code.items.len -= 5;
                        return;
                    }
                    const s32_amt = math.cast(i32, amt) catch
                        return self.fail(src, "unable to perform relocation: jump too far", .{});
                    mem.writeIntLittle(i32, self.code.items[pos..][0..4], s32_amt);
                },
            }
        }

        fn genBr(self: *Self, inst: *ir.Inst.Br) !MCValue {
            if (!inst.operand.ty.hasCodeGenBits())
                return self.brVoid(inst.base.src, inst.block);

            const operand = try self.resolveInst(inst.operand);
            switch (arch) {
                else => return self.fail(inst.base.src, "TODO implement br for {}", .{self.target.cpu.arch}),
            }
        }

        fn genBrVoid(self: *Self, inst: *ir.Inst.BrVoid) !MCValue {
            return self.brVoid(inst.base.src, inst.block);
        }

        fn brVoid(self: *Self, src: usize, block: *ir.Inst.Block) !MCValue {
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

        fn genAsm(self: *Self, inst: *ir.Inst.Assembly) !MCValue {
            if (!inst.is_volatile and inst.base.isUnused())
                return MCValue.dead;
            if (arch != .x86_64 and arch != .i386) {
                return self.fail(inst.base.src, "TODO implement inline asm support for more architectures", .{});
            }
            for (inst.inputs) |input, i| {
                if (input.len < 3 or input[0] != '{' or input[input.len - 1] != '}') {
                    return self.fail(inst.base.src, "unrecognized asm input constraint: '{}'", .{input});
                }
                const reg_name = input[1 .. input.len - 1];
                const reg = parseRegName(reg_name) orelse
                    return self.fail(inst.base.src, "unrecognized register: '{}'", .{reg_name});
                const arg = try self.resolveInst(inst.args[i]);
                try self.genSetReg(inst.base.src, reg, arg);
            }

            if (mem.eql(u8, inst.asm_source, "syscall")) {
                try self.code.appendSlice(&[_]u8{ 0x0f, 0x05 });
            } else {
                return self.fail(inst.base.src, "TODO implement support for more x86 assembly instructions", .{});
            }

            if (inst.output) |output| {
                if (output.len < 4 or output[0] != '=' or output[1] != '{' or output[output.len - 1] != '}') {
                    return self.fail(inst.base.src, "unrecognized asm output constraint: '{}'", .{output});
                }
                const reg_name = output[2 .. output.len - 1];
                const reg = parseRegName(reg_name) orelse
                    return self.fail(inst.base.src, "unrecognized register: '{}'", .{reg_name});
                return MCValue{ .register = reg };
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
        fn rex(self: *Self, arg: struct { b: bool = false, w: bool = false, x: bool = false, r: bool = false }) void {
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

        /// Sets the value without any modifications to register allocation metadata or stack allocation metadata.
        fn setRegOrMem(self: *Self, src: usize, ty: Type, loc: MCValue, val: MCValue) !void {
            switch (loc) {
                .none => return,
                .register => |reg| return self.genSetReg(src, reg, val),
                .stack_offset => |off| return self.genSetStack(src, ty, off, val),
                .memory => {
                    return self.fail(src, "TODO implement setRegOrMem for memory", .{});
                },
                else => unreachable,
            }
        }

        fn genSetStack(self: *Self, src: usize, ty: Type, stack_offset: u32, mcv: MCValue) InnerError!void {
            switch (arch) {
                .x86_64 => switch (mcv) {
                    .dead => unreachable,
                    .ptr_stack_offset => unreachable,
                    .ptr_embedded_in_code => unreachable,
                    .unreach, .none => return, // Nothing to do.
                    .undef => {
                        if (!self.wantSafety())
                            return; // The already existing value will do just fine.
                        // TODO Upgrade this to a memset call when we have that available.
                        switch (ty.abiSize(self.target.*)) {
                            1 => return self.genSetStack(src, ty, stack_offset, .{ .immediate = 0xaa }),
                            2 => return self.genSetStack(src, ty, stack_offset, .{ .immediate = 0xaaaa }),
                            4 => return self.genSetStack(src, ty, stack_offset, .{ .immediate = 0xaaaaaaaa }),
                            8 => return self.genSetStack(src, ty, stack_offset, .{ .immediate = 0xaaaaaaaaaaaaaaaa }),
                            else => return self.fail(src, "TODO implement memset", .{}),
                        }
                    },
                    .compare_flags_unsigned => |op| {
                        return self.fail(src, "TODO implement set stack variable with compare flags value (unsigned)", .{});
                    },
                    .compare_flags_signed => |op| {
                        return self.fail(src, "TODO implement set stack variable with compare flags value (signed)", .{});
                    },
                    .immediate => |x_big| {
                        const abi_size = ty.abiSize(self.target.*);
                        const adj_off = stack_offset + abi_size;
                        if (adj_off > 128) {
                            return self.fail(src, "TODO implement set stack variable with large stack offset", .{});
                        }
                        try self.code.ensureCapacity(self.code.items.len + 8);
                        switch (abi_size) {
                            1 => {
                                return self.fail(src, "TODO implement set abi_size=1 stack variable with immediate", .{});
                            },
                            2 => {
                                return self.fail(src, "TODO implement set abi_size=2 stack variable with immediate", .{});
                            },
                            4 => {
                                const x = @intCast(u32, x_big);
                                // We have a positive stack offset value but we want a twos complement negative
                                // offset from rbp, which is at the top of the stack frame.
                                const negative_offset = @intCast(i8, -@intCast(i32, adj_off));
                                const twos_comp = @bitCast(u8, negative_offset);
                                // mov    DWORD PTR [rbp+offset], immediate
                                self.code.appendSliceAssumeCapacity(&[_]u8{ 0xc7, 0x45, twos_comp });
                                mem.writeIntLittle(u32, self.code.addManyAsArrayAssumeCapacity(4), x);
                            },
                            8 => {
                                return self.fail(src, "TODO implement set abi_size=8 stack variable with immediate", .{});
                            },
                            else => {
                                return self.fail(src, "TODO implement set abi_size=large stack variable with immediate", .{});
                            },
                        }
                        if (x_big <= math.maxInt(u32)) {} else {
                            return self.fail(src, "TODO implement set stack variable with large immediate", .{});
                        }
                    },
                    .embedded_in_code => |code_offset| {
                        return self.fail(src, "TODO implement set stack variable from embedded_in_code", .{});
                    },
                    .register => |reg| {
                        const abi_size = ty.abiSize(self.target.*);
                        const adj_off = stack_offset + abi_size;
                        try self.code.ensureCapacity(self.code.items.len + 7);
                        self.rex(.{ .w = reg.size() == 64, .b = reg.isExtended() });
                        const reg_id: u8 = @truncate(u3, reg.id());
                        if (adj_off <= 128) {
                            // example: 48 89 55 7f           mov    QWORD PTR [rbp+0x7f],rdx
                            const RM = @as(u8, 0b01_000_101) | (reg_id << 3);
                            const negative_offset = @intCast(i8, -@intCast(i32, adj_off));
                            const twos_comp = @bitCast(u8, negative_offset);
                            self.code.appendSliceAssumeCapacity(&[_]u8{ 0x89, RM, twos_comp });
                        } else if (adj_off <= 2147483648) {
                            // example: 48 89 95 80 00 00 00  mov    QWORD PTR [rbp+0x80],rdx
                            const RM = @as(u8, 0b10_000_101) | (reg_id << 3);
                            const negative_offset = @intCast(i32, -@intCast(i33, adj_off));
                            const twos_comp = @bitCast(u32, negative_offset);
                            self.code.appendSliceAssumeCapacity(&[_]u8{ 0x89, RM });
                            mem.writeIntLittle(u32, self.code.addManyAsArrayAssumeCapacity(4), twos_comp);
                        } else {
                            return self.fail(src, "stack offset too large", .{});
                        }
                    },
                    .memory => |vaddr| {
                        return self.fail(src, "TODO implement set stack variable from memory vaddr", .{});
                    },
                    .stack_offset => |off| {
                        if (stack_offset == off)
                            return; // Copy stack variable to itself; nothing to do.
                        return self.fail(src, "TODO implement copy stack variable to stack variable", .{});
                    },
                },
                else => return self.fail(src, "TODO implement getSetStack for {}", .{self.target.cpu.arch}),
            }
        }

        fn genSetReg(self: *Self, src: usize, reg: Register, mcv: MCValue) InnerError!void {
            switch (arch) {
                .x86_64 => switch (mcv) {
                    .dead => unreachable,
                    .ptr_stack_offset => unreachable,
                    .ptr_embedded_in_code => unreachable,
                    .unreach, .none => return, // Nothing to do.
                    .undef => {
                        if (!self.wantSafety())
                            return; // The already existing value will do just fine.
                        // Write the debug undefined value.
                        switch (reg.size()) {
                            8 => return self.genSetReg(src, reg, .{ .immediate = 0xaa }),
                            16 => return self.genSetReg(src, reg, .{ .immediate = 0xaaaa }),
                            32 => return self.genSetReg(src, reg, .{ .immediate = 0xaaaaaaaa }),
                            64 => return self.genSetReg(src, reg, .{ .immediate = 0xaaaaaaaaaaaaaaaa }),
                            else => unreachable,
                        }
                    },
                    .compare_flags_unsigned => |op| {
                        try self.code.ensureCapacity(self.code.items.len + 3);
                        // TODO audit this codegen: we force w = true here to make
                        // the value affect the big register
                        self.rex(.{ .b = reg.isExtended(), .w = true });
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
                        if (x <= math.maxInt(u32)) {
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
                        self.rex(.{ .w = reg.size() == 64, .b = reg.isExtended() });
                        self.code.items.len += 9;
                        self.code.items[self.code.items.len - 9] = 0xB8 | @as(u8, reg.id() & 0b111);
                        const imm_ptr = self.code.items[self.code.items.len - 8 ..][0..8];
                        mem.writeIntLittle(u64, imm_ptr, x);
                    },
                    .embedded_in_code => |code_offset| {
                        // We need the offset from RIP in a signed i32 twos complement.
                        // The instruction is 7 bytes long and RIP points to the next instruction.
                        try self.code.ensureCapacity(self.code.items.len + 7);
                        // 64-bit LEA is encoded as REX.W 8D /r. If the register is extended, the REX byte is modified,
                        // but the operation size is unchanged. Since we're using a disp32, we want mode 0 and lower three
                        // bits as five.
                        // REX 0x8D 0b00RRR101, where RRR is the lower three bits of the id.
                        self.rex(.{ .w = reg.size() == 64, .b = reg.isExtended() });
                        self.code.items.len += 6;
                        const rip = self.code.items.len;
                        const big_offset = @intCast(i64, code_offset) - @intCast(i64, rip);
                        const offset = @intCast(i32, big_offset);
                        self.code.items[self.code.items.len - 6] = 0x8D;
                        self.code.items[self.code.items.len - 5] = 0b101 | (@as(u8, reg.id() & 0b111) << 3);
                        const imm_ptr = self.code.items[self.code.items.len - 4 ..][0..4];
                        mem.writeIntLittle(i32, imm_ptr, offset);
                    },
                    .register => |src_reg| {
                        // If the registers are the same, nothing to do.
                        if (src_reg.id() == reg.id())
                            return;

                        // This is a variant of 8B /r. Since we're using 64-bit moves, we require a REX.
                        // This is thus three bytes: REX 0x8B R/M.
                        // If the destination is extended, the R field must be 1.
                        // If the *source* is extended, the B field must be 1.
                        // Since the register is being accessed directly, the R/M mode is three. The reg field (the middle
                        // three bits) contain the destination, and the R/M field (the lower three bits) contain the source.
                        try self.code.ensureCapacity(self.code.items.len + 3);
                        self.rex(.{ .w = reg.size() == 64, .r = reg.isExtended(), .b = src_reg.isExtended() });
                        const R = 0xC0 | (@as(u8, reg.id() & 0b111) << 3) | @as(u8, src_reg.id() & 0b111);
                        self.code.appendSliceAssumeCapacity(&[_]u8{ 0x8B, R });
                    },
                    .memory => |x| {
                        if (x <= math.maxInt(u32)) {
                            // Moving from memory to a register is a variant of `8B /r`.
                            // Since we're using 64-bit moves, we require a REX.
                            // This variant also requires a SIB, as it would otherwise be RIP-relative.
                            // We want mode zero with the lower three bits set to four to indicate an SIB with no other displacement.
                            // The SIB must be 0x25, to indicate a disp32 with no scaled index.
                            // 0b00RRR100, where RRR is the lower three bits of the register ID.
                            // The instruction is thus eight bytes; REX 0x8B 0b00RRR100 0x25 followed by a four-byte disp32.
                            try self.code.ensureCapacity(self.code.items.len + 8);
                            self.rex(.{ .w = reg.size() == 64, .b = reg.isExtended() });
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
                                assert(id3 != 4 and id3 != 5);

                                // Rather than duplicate the logic used for the move, we just use a self-call with a new MCValue.
                                try self.genSetReg(src, reg, MCValue{ .immediate = x });

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
                                self.rex(.{ .w = reg.size() == 64, .b = reg.isExtended(), .r = reg.isExtended() });
                                const RM = (@as(u8, reg.id() & 0b111) << 3) | @truncate(u3, reg.id());
                                self.code.appendSliceAssumeCapacity(&[_]u8{ 0x8B, RM });
                            }
                        }
                    },
                    .stack_offset => |unadjusted_off| {
                        try self.code.ensureCapacity(self.code.items.len + 7);
                        const size_bytes = @divExact(reg.size(), 8);
                        const off = unadjusted_off + size_bytes;
                        self.rex(.{ .w = reg.size() == 64, .r = reg.isExtended() });
                        const reg_id: u8 = @truncate(u3, reg.id());
                        if (off <= 128) {
                            // Example: 48 8b 4d 7f           mov    rcx,QWORD PTR [rbp+0x7f]
                            const RM = @as(u8, 0b01_000_101) | (reg_id << 3);
                            const negative_offset = @intCast(i8, -@intCast(i32, off));
                            const twos_comp = @bitCast(u8, negative_offset);
                            self.code.appendSliceAssumeCapacity(&[_]u8{ 0x8b, RM, twos_comp });
                        } else if (off <= 2147483648) {
                            // Example: 48 8b 8d 80 00 00 00  mov    rcx,QWORD PTR [rbp+0x80]
                            const RM = @as(u8, 0b10_000_101) | (reg_id << 3);
                            const negative_offset = @intCast(i32, -@intCast(i33, off));
                            const twos_comp = @bitCast(u32, negative_offset);
                            self.code.appendSliceAssumeCapacity(&[_]u8{ 0x8b, RM });
                            mem.writeIntLittle(u32, self.code.addManyAsArrayAssumeCapacity(4), twos_comp);
                        } else {
                            return self.fail(src, "stack offset too large", .{});
                        }
                    },
                },
                else => return self.fail(src, "TODO implement getSetReg for {}", .{self.target.cpu.arch}),
            }
        }

        fn genPtrToInt(self: *Self, inst: *ir.Inst.UnOp) !MCValue {
            // no-op
            return self.resolveInst(inst.operand);
        }

        fn genBitCast(self: *Self, inst: *ir.Inst.UnOp) !MCValue {
            const operand = try self.resolveInst(inst.operand);
            return operand;
        }

        fn resolveInst(self: *Self, inst: *ir.Inst) !MCValue {
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
                    assert(mcv != .dead);
                    return mcv;
                }
            }
        }

        /// If the MCValue is an immediate, and it does not fit within this type,
        /// we put it in a register.
        /// A potential opportunity for future optimization here would be keeping track
        /// of the fact that the instruction is available both as an immediate
        /// and as a register.
        fn limitImmediateType(self: *Self, inst: *ir.Inst, comptime T: type) !MCValue {
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
                    if (imm >= math.maxInt(U)) {
                        return self.copyToNewRegister(inst);
                    }
                },
                else => {},
            }
            return mcv;
        }

        fn genTypedValue(self: *Self, src: usize, typed_value: TypedValue) !MCValue {
            if (typed_value.val.isUndef())
                return MCValue.undef;
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

        const CallMCValues = struct {
            args: []MCValue,
            return_value: MCValue,
            stack_byte_count: u32,
            stack_align: u32,

            fn deinit(self: *CallMCValues, func: *Self) void {
                func.gpa.free(self.args);
                self.* = undefined;
            }
        };

        /// Caller must call `CallMCValues.deinit`.
        fn resolveCallingConventionValues(self: *Self, src: usize, fn_ty: Type) !CallMCValues {
            const cc = fn_ty.fnCallingConvention();
            const param_types = try self.gpa.alloc(Type, fn_ty.fnParamLen());
            defer self.gpa.free(param_types);
            fn_ty.fnParamTypes(param_types);
            var result: CallMCValues = .{
                .args = try self.gpa.alloc(MCValue, param_types.len),
                // These undefined values must be populated before returning from this function.
                .return_value = undefined,
                .stack_byte_count = undefined,
                .stack_align = undefined,
            };
            errdefer self.gpa.free(result.args);

            const ret_ty = fn_ty.fnReturnType();

            switch (arch) {
                .x86_64 => {
                    switch (cc) {
                        .Naked => {
                            assert(result.args.len == 0);
                            result.return_value = .{ .unreach = {} };
                            result.stack_byte_count = 0;
                            result.stack_align = 1;
                            return result;
                        },
                        .Unspecified, .C => {
                            var next_int_reg: usize = 0;
                            var next_stack_offset: u32 = 0;

                            for (param_types) |ty, i| {
                                switch (ty.zigTypeTag()) {
                                    .Bool, .Int => {
                                        const param_size = @intCast(u32, ty.abiSize(self.target.*));
                                        if (next_int_reg >= c_abi_int_param_regs.len) {
                                            result.args[i] = .{ .stack_offset = next_stack_offset };
                                            next_stack_offset += param_size;
                                        } else {
                                            const aliased_reg = registerAlias(
                                                c_abi_int_param_regs[next_int_reg],
                                                param_size,
                                            );
                                            result.args[i] = .{ .register = aliased_reg };
                                            next_int_reg += 1;
                                        }
                                    },
                                    else => return self.fail(src, "TODO implement function parameters of type {}", .{@tagName(ty.zigTypeTag())}),
                                }
                            }
                            result.stack_byte_count = next_stack_offset;
                            result.stack_align = 16;
                        },
                        else => return self.fail(src, "TODO implement function parameters for {}", .{cc}),
                    }
                },
                else => return self.fail(src, "TODO implement codegen parameters for {}", .{self.target.cpu.arch}),
            }

            if (ret_ty.zigTypeTag() == .NoReturn) {
                result.return_value = .{ .unreach = {} };
            } else if (!ret_ty.hasCodeGenBits()) {
                result.return_value = .{ .none = {} };
            } else switch (arch) {
                .x86_64 => switch (cc) {
                    .Naked => unreachable,
                    .Unspecified, .C => {
                        const ret_ty_size = @intCast(u32, ret_ty.abiSize(self.target.*));
                        const aliased_reg = registerAlias(c_abi_int_return_regs[0], ret_ty_size);
                        result.return_value = .{ .register = aliased_reg };
                    },
                    else => return self.fail(src, "TODO implement function return values for {}", .{cc}),
                },
                else => return self.fail(src, "TODO implement codegen return values for {}", .{self.target.cpu.arch}),
            }
            return result;
        }

        /// TODO support scope overrides. Also note this logic is duplicated with `Module.wantSafety`.
        fn wantSafety(self: *Self) bool {
            return switch (self.bin_file.base.options.optimize_mode) {
                .Debug => true,
                .ReleaseSafe => true,
                .ReleaseFast => false,
                .ReleaseSmall => false,
            };
        }

        fn fail(self: *Self, src: usize, comptime format: []const u8, args: anytype) error{ CodegenFail, OutOfMemory } {
            @setCold(true);
            assert(self.err_msg == null);
            self.err_msg = try ErrorMsg.create(self.bin_file.allocator, src, format, args);
            return error.CodegenFail;
        }

        usingnamespace switch (arch) {
            .i386 => @import("codegen/x86.zig"),
            .x86_64 => @import("codegen/x86_64.zig"),
            else => struct {
                pub const Register = enum {
                    dummy,

                    pub fn allocIndex(self: Register) ?u4 {
                        return null;
                    }
                };
                pub const callee_preserved_regs = [_]Register{};
            },
        };

        /// An integer whose bits represent all the registers and whether they are free.
        const FreeRegInt = @Type(.{ .Int = .{ .is_signed = false, .bits = callee_preserved_regs.len } });

        fn parseRegName(name: []const u8) ?Register {
            return std.meta.stringToEnum(Register, name);
        }

        fn registerAlias(reg: Register, size_bytes: u32) Register {
            switch (arch) {
                // For x86_64 we have to pick a smaller register alias depending on abi size.
                .x86_64 => switch (size_bytes) {
                    1 => return reg.to8(),
                    2 => return reg.to16(),
                    4 => return reg.to32(),
                    8 => return reg.to64(),
                    else => unreachable,
                },
                else => return reg,
            }
        }
    };
}
