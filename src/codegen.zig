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
const Compilation = @import("Compilation.zig");
const ErrorMsg = Compilation.ErrorMsg;
const Target = std.Target;
const Allocator = mem.Allocator;
const trace = @import("tracy.zig").trace;
const DW = std.dwarf;
const leb128 = std.leb;
const log = std.log.scoped(.codegen);
const build_options = @import("build_options");

/// The codegen-related data that is stored in `ir.Inst.Block` instructions.
pub const BlockData = struct {
    relocs: std.ArrayListUnmanaged(Reloc) = undefined,
    /// The first break instruction encounters `null` here and chooses a
    /// machine code value for the block result, populating this field.
    /// Following break instructions encounter that value and use it for
    /// the location to store their block results.
    mcv: AnyMCValue = undefined,
};

/// Architecture-independent MCValue. Here, we have a type that is the same size as
/// the architecture-specific MCValue. Next to the declaration of MCValue is a
/// comptime assert that makes sure we guessed correctly about the size. This only
/// exists so that we can bitcast an arch-independent field to and from the real MCValue.
pub const AnyMCValue = extern struct {
    a: usize,
    b: u64,
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
    fail: *ErrorMsg,
};

pub const GenerateSymbolError = error{
    OutOfMemory,
    /// A Decl that this symbol depends on had a semantic analysis failure.
    AnalysisFail,
};

pub const DebugInfoOutput = union(enum) {
    dwarf: struct {
        dbg_line: *std.ArrayList(u8),
        dbg_info: *std.ArrayList(u8),
        dbg_info_type_relocs: *link.File.DbgInfoTypeRelocsTable,
    },
    none,
};

pub fn generateSymbol(
    bin_file: *link.File,
    src: usize,
    typed_value: TypedValue,
    code: *std.ArrayList(u8),
    debug_output: DebugInfoOutput,
) GenerateSymbolError!Result {
    const tracy = trace(@src());
    defer tracy.end();

    switch (typed_value.ty.zigTypeTag()) {
        .Fn => {
            switch (bin_file.options.target.cpu.arch) {
                .wasm32 => unreachable, // has its own code path
                .wasm64 => unreachable, // has its own code path
                .arm => return Function(.arm).generateSymbol(bin_file, src, typed_value, code, debug_output),
                .armeb => return Function(.armeb).generateSymbol(bin_file, src, typed_value, code, debug_output),
                .aarch64 => return Function(.aarch64).generateSymbol(bin_file, src, typed_value, code, debug_output),
                .aarch64_be => return Function(.aarch64_be).generateSymbol(bin_file, src, typed_value, code, debug_output),
                .aarch64_32 => return Function(.aarch64_32).generateSymbol(bin_file, src, typed_value, code, debug_output),
                //.arc => return Function(.arc).generateSymbol(bin_file, src, typed_value, code, debug_output),
                //.avr => return Function(.avr).generateSymbol(bin_file, src, typed_value, code, debug_output),
                //.bpfel => return Function(.bpfel).generateSymbol(bin_file, src, typed_value, code, debug_output),
                //.bpfeb => return Function(.bpfeb).generateSymbol(bin_file, src, typed_value, code, debug_output),
                //.hexagon => return Function(.hexagon).generateSymbol(bin_file, src, typed_value, code, debug_output),
                //.mips => return Function(.mips).generateSymbol(bin_file, src, typed_value, code, debug_output),
                //.mipsel => return Function(.mipsel).generateSymbol(bin_file, src, typed_value, code, debug_output),
                //.mips64 => return Function(.mips64).generateSymbol(bin_file, src, typed_value, code, debug_output),
                //.mips64el => return Function(.mips64el).generateSymbol(bin_file, src, typed_value, code, debug_output),
                //.msp430 => return Function(.msp430).generateSymbol(bin_file, src, typed_value, code, debug_output),
                //.powerpc => return Function(.powerpc).generateSymbol(bin_file, src, typed_value, code, debug_output),
                //.powerpc64 => return Function(.powerpc64).generateSymbol(bin_file, src, typed_value, code, debug_output),
                //.powerpc64le => return Function(.powerpc64le).generateSymbol(bin_file, src, typed_value, code, debug_output),
                //.r600 => return Function(.r600).generateSymbol(bin_file, src, typed_value, code, debug_output),
                //.amdgcn => return Function(.amdgcn).generateSymbol(bin_file, src, typed_value, code, debug_output),
                //.riscv32 => return Function(.riscv32).generateSymbol(bin_file, src, typed_value, code, debug_output),
                .riscv64 => return Function(.riscv64).generateSymbol(bin_file, src, typed_value, code, debug_output),
                //.sparc => return Function(.sparc).generateSymbol(bin_file, src, typed_value, code, debug_output),
                //.sparcv9 => return Function(.sparcv9).generateSymbol(bin_file, src, typed_value, code, debug_output),
                //.sparcel => return Function(.sparcel).generateSymbol(bin_file, src, typed_value, code, debug_output),
                //.s390x => return Function(.s390x).generateSymbol(bin_file, src, typed_value, code, debug_output),
                .spu_2 => return Function(.spu_2).generateSymbol(bin_file, src, typed_value, code, debug_output),
                //.tce => return Function(.tce).generateSymbol(bin_file, src, typed_value, code, debug_output),
                //.tcele => return Function(.tcele).generateSymbol(bin_file, src, typed_value, code, debug_output),
                //.thumb => return Function(.thumb).generateSymbol(bin_file, src, typed_value, code, debug_output),
                //.thumbeb => return Function(.thumbeb).generateSymbol(bin_file, src, typed_value, code, debug_output),
                //.i386 => return Function(.i386).generateSymbol(bin_file, src, typed_value, code, debug_output),
                .x86_64 => return Function(.x86_64).generateSymbol(bin_file, src, typed_value, code, debug_output),
                //.xcore => return Function(.xcore).generateSymbol(bin_file, src, typed_value, code, debug_output),
                //.nvptx => return Function(.nvptx).generateSymbol(bin_file, src, typed_value, code, debug_output),
                //.nvptx64 => return Function(.nvptx64).generateSymbol(bin_file, src, typed_value, code, debug_output),
                //.le32 => return Function(.le32).generateSymbol(bin_file, src, typed_value, code, debug_output),
                //.le64 => return Function(.le64).generateSymbol(bin_file, src, typed_value, code, debug_output),
                //.amdil => return Function(.amdil).generateSymbol(bin_file, src, typed_value, code, debug_output),
                //.amdil64 => return Function(.amdil64).generateSymbol(bin_file, src, typed_value, code, debug_output),
                //.hsail => return Function(.hsail).generateSymbol(bin_file, src, typed_value, code, debug_output),
                //.hsail64 => return Function(.hsail64).generateSymbol(bin_file, src, typed_value, code, debug_output),
                //.spir => return Function(.spir).generateSymbol(bin_file, src, typed_value, code, debug_output),
                //.spir64 => return Function(.spir64).generateSymbol(bin_file, src, typed_value, code, debug_output),
                //.kalimba => return Function(.kalimba).generateSymbol(bin_file, src, typed_value, code, debug_output),
                //.shave => return Function(.shave).generateSymbol(bin_file, src, typed_value, code, debug_output),
                //.lanai => return Function(.lanai).generateSymbol(bin_file, src, typed_value, code, debug_output),
                //.renderscript32 => return Function(.renderscript32).generateSymbol(bin_file, src, typed_value, code, debug_output),
                //.renderscript64 => return Function(.renderscript64).generateSymbol(bin_file, src, typed_value, code, debug_output),
                //.ve => return Function(.ve).generateSymbol(bin_file, src, typed_value, code, debug_output),
                else => @panic("Backend architectures that don't have good support yet are commented out, to improve compilation performance. If you are interested in one of these other backends feel free to uncomment them. Eventually these will be completed, but stage1 is slow and a memory hog."),
            }
        },
        .Array => {
            // TODO populate .debug_info for the array
            if (typed_value.val.cast(Value.Payload.Bytes)) |payload| {
                if (typed_value.ty.sentinel()) |sentinel| {
                    try code.ensureCapacity(code.items.len + payload.data.len + 1);
                    code.appendSliceAssumeCapacity(payload.data);
                    const prev_len = code.items.len;
                    switch (try generateSymbol(bin_file, src, .{
                        .ty = typed_value.ty.elemType(),
                        .val = sentinel,
                    }, code, debug_output)) {
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
            // TODO populate .debug_info for the pointer
            if (typed_value.val.cast(Value.Payload.DeclRef)) |payload| {
                const decl = payload.decl;
                if (decl.analysis != .complete) return error.AnalysisFail;
                // TODO handle the dependency of this symbol on the decl's vaddr.
                // If the decl changes vaddr, then this symbol needs to get regenerated.
                const vaddr = bin_file.getDeclVAddr(decl);
                const endian = bin_file.options.target.cpu.arch.endian();
                switch (bin_file.options.target.cpu.arch.ptrBitWidth()) {
                    16 => {
                        try code.resize(2);
                        mem.writeInt(u16, code.items[0..2], @intCast(u16, vaddr), endian);
                    },
                    32 => {
                        try code.resize(4);
                        mem.writeInt(u32, code.items[0..4], @intCast(u32, vaddr), endian);
                    },
                    64 => {
                        try code.resize(8);
                        mem.writeInt(u64, code.items[0..8], vaddr, endian);
                    },
                    else => unreachable,
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
            // TODO populate .debug_info for the integer
            const info = typed_value.ty.intInfo(bin_file.options.target);
            if (info.bits == 8 and info.signedness == .unsigned) {
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
    const writeInt = switch (arch.endian()) {
        .Little => mem.writeIntLittle,
        .Big => mem.writeIntBig,
    };

    return struct {
        gpa: *Allocator,
        bin_file: *link.File,
        target: *const std.Target,
        mod_fn: *const Module.Fn,
        code: *std.ArrayList(u8),
        debug_output: DebugInfoOutput,
        err_msg: ?*ErrorMsg,
        args: []MCValue,
        ret_mcv: MCValue,
        fn_type: Type,
        arg_index: usize,
        src: usize,
        stack_align: u32,

        /// Byte offset within the source file.
        prev_di_src: usize,
        /// Relative to the beginning of `code`.
        prev_di_pc: usize,
        /// Used to find newlines and count line deltas.
        source: []const u8,
        /// Byte offset within the source file of the ending curly.
        rbrace_src: usize,

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

        /// The key must be canonical register.
        registers: std.AutoHashMapUnmanaged(Register, *ir.Inst) = .{},
        free_registers: FreeRegInt = math.maxInt(FreeRegInt),
        /// Maps offset to what is stored there.
        stack: std.AutoHashMapUnmanaged(u32, StackAllocation) = .{},

        /// Offset from the stack base, representing the end of the stack frame.
        max_end_stack: u32 = 0,
        /// Represents the current end stack offset. If there is no existing slot
        /// to place a new stack allocation, it goes here, and then bumps `max_end_stack`.
        next_stack_offset: u32 = 0,

        const MCValue = union(enum) {
            /// No runtime bits. `void` types, empty structs, u0, enums with 1 tag, etc.
            /// TODO Look into deleting this tag and using `dead` instead, since every use
            /// of MCValue.none should be instead looking at the type and noticing it is 0 bits.
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
            inst_table: std.AutoArrayHashMapUnmanaged(*ir.Inst, MCValue) = .{},

            fn deinit(self: *Branch, gpa: *Allocator) void {
                self.inst_table.deinit(gpa);
                self.* = undefined;
            }
        };

        fn markRegUsed(self: *Self, reg: Register) void {
            if (FreeRegInt == u0) return;
            const index = reg.allocIndex() orelse return;
            const ShiftInt = math.Log2Int(FreeRegInt);
            const shift = @intCast(ShiftInt, index);
            self.free_registers &= ~(@as(FreeRegInt, 1) << shift);
        }

        fn markRegFree(self: *Self, reg: Register) void {
            if (FreeRegInt == u0) return;
            const index = reg.allocIndex() orelse return;
            const ShiftInt = math.Log2Int(FreeRegInt);
            const shift = @intCast(ShiftInt, index);
            self.free_registers |= @as(FreeRegInt, 1) << shift;
        }

        /// Before calling, must ensureCapacity + 1 on self.registers.
        /// Returns `null` if all registers are allocated.
        fn allocReg(self: *Self, inst: *ir.Inst) ?Register {
            const free_index = @ctz(FreeRegInt, self.free_registers);
            if (free_index >= callee_preserved_regs.len) {
                return null;
            }
            self.free_registers &= ~(@as(FreeRegInt, 1) << free_index);
            const reg = callee_preserved_regs[free_index];
            self.registers.putAssumeCapacityNoClobber(reg, inst);
            log.debug("alloc {} => {*}", .{ reg, inst });
            return reg;
        }

        /// Does not track the register.
        fn findUnusedReg(self: *Self) ?Register {
            const free_index = @ctz(FreeRegInt, self.free_registers);
            if (free_index >= callee_preserved_regs.len) {
                return null;
            }
            return callee_preserved_regs[free_index];
        }

        const StackAllocation = struct {
            inst: *ir.Inst,
            /// TODO do we need size? should be determined by inst.ty.abiSize()
            size: u32,
        };

        const Self = @This();

        fn generateSymbol(
            bin_file: *link.File,
            src: usize,
            typed_value: TypedValue,
            code: *std.ArrayList(u8),
            debug_output: DebugInfoOutput,
        ) GenerateSymbolError!Result {
            if (build_options.skip_non_native and std.Target.current.cpu.arch != arch) {
                @panic("Attempted to compile for architecture that was disabled by build configuration");
            }

            const module_fn = typed_value.val.cast(Value.Payload.Function).?.func;

            const fn_type = module_fn.owner_decl.typed_value.most_recent.typed_value.ty;

            var branch_stack = std.ArrayList(Branch).init(bin_file.allocator);
            defer {
                assert(branch_stack.items.len == 1);
                branch_stack.items[0].deinit(bin_file.allocator);
                branch_stack.deinit();
            }
            try branch_stack.append(.{});

            const src_data: struct { lbrace_src: usize, rbrace_src: usize, source: []const u8 } = blk: {
                if (module_fn.owner_decl.scope.cast(Module.Scope.Container)) |container_scope| {
                    const tree = container_scope.file_scope.contents.tree;
                    const fn_proto = tree.root_node.decls()[module_fn.owner_decl.src_index].castTag(.FnProto).?;
                    const block = fn_proto.getBodyNode().?.castTag(.Block).?;
                    const lbrace_src = tree.token_locs[block.lbrace].start;
                    const rbrace_src = tree.token_locs[block.rbrace].start;
                    break :blk .{ .lbrace_src = lbrace_src, .rbrace_src = rbrace_src, .source = tree.source };
                } else if (module_fn.owner_decl.scope.cast(Module.Scope.ZIRModule)) |zir_module| {
                    const byte_off = zir_module.contents.module.decls[module_fn.owner_decl.src_index].inst.src;
                    break :blk .{ .lbrace_src = byte_off, .rbrace_src = byte_off, .source = zir_module.source.bytes };
                } else {
                    unreachable;
                }
            };

            var function = Self{
                .gpa = bin_file.allocator,
                .target = &bin_file.options.target,
                .bin_file = bin_file,
                .mod_fn = module_fn,
                .code = code,
                .debug_output = debug_output,
                .err_msg = null,
                .args = undefined, // populated after `resolveCallingConventionValues`
                .ret_mcv = undefined, // populated after `resolveCallingConventionValues`
                .fn_type = fn_type,
                .arg_index = 0,
                .branch_stack = &branch_stack,
                .src = src,
                .stack_align = undefined,
                .prev_di_pc = 0,
                .prev_di_src = src_data.lbrace_src,
                .rbrace_src = src_data.rbrace_src,
                .source = src_data.source,
            };
            defer function.registers.deinit(bin_file.allocator);
            defer function.stack.deinit(bin_file.allocator);
            defer function.exitlude_jump_relocs.deinit(bin_file.allocator);

            var call_info = function.resolveCallingConventionValues(src, fn_type) catch |err| switch (err) {
                error.CodegenFail => return Result{ .fail = function.err_msg.? },
                else => |e| return e,
            };
            defer call_info.deinit(&function);

            function.args = call_info.args;
            function.ret_mcv = call_info.return_value;
            function.stack_align = call_info.stack_align;
            function.max_end_stack = call_info.stack_byte_count;

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
                            0x55, // push rbp
                            0x48, 0x89, 0xe5, // mov rbp, rsp
                            0x48, 0x81, 0xec, // sub rsp, imm32 (with reloc)
                        });
                        const reloc_index = self.code.items.len;
                        self.code.items.len += 4;

                        try self.dbgSetPrologueEnd();
                        try self.genBody(self.mod_fn.analysis.success);

                        const stack_end = self.max_end_stack;
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

                        // Important to be after the possible self.code.items.len -= 5 above.
                        try self.dbgSetEpilogueBegin();

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
                        try self.dbgSetPrologueEnd();
                        try self.genBody(self.mod_fn.analysis.success);
                        try self.dbgSetEpilogueBegin();
                    }
                },
                .arm, .armeb => {
                    const cc = self.fn_type.fnCallingConvention();
                    if (cc != .Naked) {
                        // push {fp, lr}
                        // mov fp, sp
                        // sub sp, sp, #reloc
                        writeInt(u32, try self.code.addManyAsArray(4), Instruction.push(.al, .{ .fp, .lr }).toU32());
                        writeInt(u32, try self.code.addManyAsArray(4), Instruction.mov(.al, .fp, Instruction.Operand.reg(.sp, Instruction.Operand.Shift.none)).toU32());
                        const backpatch_reloc = self.code.items.len;
                        try self.code.resize(backpatch_reloc + 4);

                        try self.dbgSetPrologueEnd();

                        try self.genBody(self.mod_fn.analysis.success);

                        // Backpatch stack offset
                        const stack_end = self.max_end_stack;
                        const aligned_stack_end = mem.alignForward(stack_end, self.stack_align);
                        if (Instruction.Operand.fromU32(@intCast(u32, aligned_stack_end))) |op| {
                            writeInt(u32, self.code.items[backpatch_reloc..][0..4], Instruction.sub(.al, .sp, .sp, op).toU32());
                        } else {
                            return self.fail(self.src, "TODO ARM: allow larger stacks", .{});
                        }

                        try self.dbgSetEpilogueBegin();

                        // exitlude jumps
                        if (self.exitlude_jump_relocs.items.len == 1) {
                            // There is only one relocation. Hence,
                            // this relocation must be at the end of
                            // the code. Therefore, we can just delete
                            // the space initially reserved for the
                            // jump
                            self.code.items.len -= 4;
                        } else for (self.exitlude_jump_relocs.items) |jmp_reloc| {
                            const amt = self.code.items.len - (jmp_reloc + 4);
                            if (amt == 0) {
                                // This return is at the end of the
                                // code block. We can't just delete
                                // the space because there may be
                                // other jumps we already relocated to
                                // the address. Instead, insert a nop
                                writeInt(u32, self.code.items[jmp_reloc..][0..4], Instruction.nop().toU32());
                            } else {
                                if (math.cast(i26, amt)) |offset| {
                                    writeInt(u32, self.code.items[jmp_reloc..][0..4], Instruction.b(.al, offset).toU32());
                                } else |err| {
                                    return self.fail(self.src, "exitlude jump is too large", .{});
                                }
                            }
                        }

                        // mov sp, fp
                        // pop {fp, pc}
                        writeInt(u32, try self.code.addManyAsArray(4), Instruction.mov(.al, .sp, Instruction.Operand.reg(.fp, Instruction.Operand.Shift.none)).toU32());
                        writeInt(u32, try self.code.addManyAsArray(4), Instruction.pop(.al, .{ .fp, .pc }).toU32());
                    } else {
                        try self.dbgSetPrologueEnd();
                        try self.genBody(self.mod_fn.analysis.success);
                        try self.dbgSetEpilogueBegin();
                    }
                },
                else => {
                    try self.dbgSetPrologueEnd();
                    try self.genBody(self.mod_fn.analysis.success);
                    try self.dbgSetEpilogueBegin();
                },
            }
            // Drop them off at the rbrace.
            try self.dbgAdvancePCAndLine(self.rbrace_src);
        }

        fn genBody(self: *Self, body: ir.Body) InnerError!void {
            for (body.instructions) |inst| {
                try self.ensureProcessDeathCapacity(@popCount(@TypeOf(inst.deaths), inst.deaths));

                const mcv = try self.genFuncInst(inst);
                if (!inst.isUnused()) {
                    log.debug("{*} => {}", .{ inst, mcv });
                    const branch = &self.branch_stack.items[self.branch_stack.items.len - 1];
                    try branch.inst_table.putNoClobber(self.gpa, inst, mcv);
                }

                var i: ir.Inst.DeathsBitIndex = 0;
                while (inst.getOperand(i)) |operand| : (i += 1) {
                    if (inst.operandDies(i))
                        self.processDeath(operand);
                }
            }
        }

        fn dbgSetPrologueEnd(self: *Self) InnerError!void {
            switch (self.debug_output) {
                .dwarf => |dbg_out| {
                    try dbg_out.dbg_line.append(DW.LNS_set_prologue_end);
                    try self.dbgAdvancePCAndLine(self.prev_di_src);
                },
                .none => {},
            }
        }

        fn dbgSetEpilogueBegin(self: *Self) InnerError!void {
            switch (self.debug_output) {
                .dwarf => |dbg_out| {
                    try dbg_out.dbg_line.append(DW.LNS_set_epilogue_begin);
                    try self.dbgAdvancePCAndLine(self.prev_di_src);
                },
                .none => {},
            }
        }

        fn dbgAdvancePCAndLine(self: *Self, src: usize) InnerError!void {
            self.prev_di_src = src;
            self.prev_di_pc = self.code.items.len;
            switch (self.debug_output) {
                .dwarf => |dbg_out| {
                    // TODO Look into improving the performance here by adding a token-index-to-line
                    // lookup table, and changing ir.Inst from storing byte offset to token. Currently
                    // this involves scanning over the source code for newlines
                    // (but only from the previous byte offset to the new one).
                    const delta_line = std.zig.lineDelta(self.source, self.prev_di_src, src);
                    const delta_pc = self.code.items.len - self.prev_di_pc;
                    // TODO Look into using the DWARF special opcodes to compress this data. It lets you emit
                    // single-byte opcodes that add different numbers to both the PC and the line number
                    // at the same time.
                    try dbg_out.dbg_line.ensureCapacity(dbg_out.dbg_line.items.len + 11);
                    dbg_out.dbg_line.appendAssumeCapacity(DW.LNS_advance_pc);
                    leb128.writeULEB128(dbg_out.dbg_line.writer(), delta_pc) catch unreachable;
                    if (delta_line != 0) {
                        dbg_out.dbg_line.appendAssumeCapacity(DW.LNS_advance_line);
                        leb128.writeILEB128(dbg_out.dbg_line.writer(), delta_line) catch unreachable;
                    }
                    dbg_out.dbg_line.appendAssumeCapacity(DW.LNS_copy);
                },
                .none => {},
            }
        }

        /// Asserts there is already capacity to insert into top branch inst_table.
        fn processDeath(self: *Self, inst: *ir.Inst) void {
            if (inst.tag == .constant) return; // Constants are immortal.
            // When editing this function, note that the logic must synchronize with `reuseOperand`.
            const prev_value = self.getResolvedInstValue(inst);
            const branch = &self.branch_stack.items[self.branch_stack.items.len - 1];
            branch.inst_table.putAssumeCapacity(inst, .dead);
            switch (prev_value) {
                .register => |reg| {
                    const canon_reg = toCanonicalReg(reg);
                    _ = self.registers.remove(canon_reg);
                    self.markRegFree(canon_reg);
                },
                else => {}, // TODO process stack allocation death
            }
        }

        fn ensureProcessDeathCapacity(self: *Self, additional_count: usize) !void {
            const table = &self.branch_stack.items[self.branch_stack.items.len - 1].inst_table;
            try table.ensureCapacity(self.gpa, table.items().len + additional_count);
        }

        /// Adds a Type to the .debug_info at the current position. The bytes will be populated later,
        /// after codegen for this symbol is done.
        fn addDbgInfoTypeReloc(self: *Self, ty: Type) !void {
            switch (self.debug_output) {
                .dwarf => |dbg_out| {
                    assert(ty.hasCodeGenBits());
                    const index = dbg_out.dbg_info.items.len;
                    try dbg_out.dbg_info.resize(index + 4); // DW.AT_type,  DW.FORM_ref4

                    const gop = try dbg_out.dbg_info_type_relocs.getOrPut(self.gpa, ty);
                    if (!gop.found_existing) {
                        gop.entry.value = .{
                            .off = undefined,
                            .relocs = .{},
                        };
                    }
                    try gop.entry.value.relocs.append(self.gpa, @intCast(u32, index));
                },
                .none => {},
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
                .booland => return self.genBoolOp(inst.castTag(.booland).?),
                .boolor => return self.genBoolOp(inst.castTag(.boolor).?),
                .call => return self.genCall(inst.castTag(.call).?),
                .cmp_lt => return self.genCmp(inst.castTag(.cmp_lt).?, .lt),
                .cmp_lte => return self.genCmp(inst.castTag(.cmp_lte).?, .lte),
                .cmp_eq => return self.genCmp(inst.castTag(.cmp_eq).?, .eq),
                .cmp_gte => return self.genCmp(inst.castTag(.cmp_gte).?, .gte),
                .cmp_gt => return self.genCmp(inst.castTag(.cmp_gt).?, .gt),
                .cmp_neq => return self.genCmp(inst.castTag(.cmp_neq).?, .neq),
                .condbr => return self.genCondBr(inst.castTag(.condbr).?),
                .constant => unreachable, // excluded from function bodies
                .dbg_stmt => return self.genDbgStmt(inst.castTag(.dbg_stmt).?),
                .floatcast => return self.genFloatCast(inst.castTag(.floatcast).?),
                .intcast => return self.genIntCast(inst.castTag(.intcast).?),
                .isnonnull => return self.genIsNonNull(inst.castTag(.isnonnull).?),
                .isnull => return self.genIsNull(inst.castTag(.isnull).?),
                .iserr => return self.genIsErr(inst.castTag(.iserr).?),
                .load => return self.genLoad(inst.castTag(.load).?),
                .loop => return self.genLoop(inst.castTag(.loop).?),
                .not => return self.genNot(inst.castTag(.not).?),
                .ptrtoint => return self.genPtrToInt(inst.castTag(.ptrtoint).?),
                .ref => return self.genRef(inst.castTag(.ref).?),
                .ret => return self.genRet(inst.castTag(.ret).?),
                .retvoid => return self.genRetVoid(inst.castTag(.retvoid).?),
                .store => return self.genStore(inst.castTag(.store).?),
                .sub => return self.genSub(inst.castTag(.sub).?),
                .switchbr => return self.genSwitch(inst.castTag(.switchbr).?),
                .unreach => return MCValue{ .unreach = {} },
                .unwrap_optional => return self.genUnwrapOptional(inst.castTag(.unwrap_optional).?),
                .wrap_optional => return self.genWrapOptional(inst.castTag(.wrap_optional).?),
                .varptr => return self.genVarPtr(inst.castTag(.varptr).?),
            }
        }

        fn allocMem(self: *Self, inst: *ir.Inst, abi_size: u32, abi_align: u32) !u32 {
            if (abi_align > self.stack_align)
                self.stack_align = abi_align;
            // TODO find a free slot instead of always appending
            const offset = mem.alignForwardGeneric(u32, self.next_stack_offset, abi_align);
            self.next_stack_offset = offset + abi_size;
            if (self.next_stack_offset > self.max_end_stack)
                self.max_end_stack = self.next_stack_offset;
            try self.stack.putNoClobber(self.gpa, offset, .{
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

        fn allocRegOrMem(self: *Self, inst: *ir.Inst, reg_ok: bool) !MCValue {
            const elem_ty = inst.ty;
            const abi_size = math.cast(u32, elem_ty.abiSize(self.target.*)) catch {
                return self.fail(inst.src, "type '{}' too big to fit into stack frame", .{elem_ty});
            };
            const abi_align = elem_ty.abiAlignment(self.target.*);
            if (abi_align > self.stack_align)
                self.stack_align = abi_align;

            if (reg_ok) {
                // Make sure the type can fit in a register before we try to allocate one.
                const ptr_bits = arch.ptrBitWidth();
                const ptr_bytes: u64 = @divExact(ptr_bits, 8);
                if (abi_size <= ptr_bytes) {
                    try self.registers.ensureCapacity(self.gpa, self.registers.count() + 1);
                    if (self.allocReg(inst)) |reg| {
                        return MCValue{ .register = registerAlias(reg, abi_size) };
                    }
                }
            }
            const stack_offset = try self.allocMem(inst, abi_size, abi_align);
            return MCValue{ .stack_offset = stack_offset };
        }

        /// Copies a value to a register without tracking the register. The register is not considered
        /// allocated. A second call to `copyToTmpRegister` may return the same register.
        /// This can have a side effect of spilling instructions to the stack to free up a register.
        fn copyToTmpRegister(self: *Self, src: usize, mcv: MCValue) !Register {
            const reg = self.findUnusedReg() orelse b: {
                // We'll take over the first register. Move the instruction that was previously
                // there to a stack allocation.
                const reg = callee_preserved_regs[0];
                const regs_entry = self.registers.remove(reg).?;
                const spilled_inst = regs_entry.value;

                const stack_mcv = try self.allocRegOrMem(spilled_inst, false);
                const reg_mcv = self.getResolvedInstValue(spilled_inst);
                assert(reg == toCanonicalReg(reg_mcv.register));
                const branch = &self.branch_stack.items[self.branch_stack.items.len - 1];
                try branch.inst_table.put(self.gpa, spilled_inst, stack_mcv);
                try self.genSetStack(src, spilled_inst.ty, stack_mcv.stack_offset, reg_mcv);

                break :b reg;
            };
            try self.genSetReg(src, reg, mcv);
            return reg;
        }

        /// Allocates a new register and copies `mcv` into it.
        /// `reg_owner` is the instruction that gets associated with the register in the register table.
        /// This can have a side effect of spilling instructions to the stack to free up a register.
        fn copyToNewRegister(self: *Self, reg_owner: *ir.Inst, mcv: MCValue) !MCValue {
            try self.registers.ensureCapacity(self.gpa, @intCast(u32, self.registers.count() + 1));

            const reg = self.allocReg(reg_owner) orelse b: {
                // We'll take over the first register. Move the instruction that was previously
                // there to a stack allocation.
                const reg = callee_preserved_regs[0];
                const regs_entry = self.registers.getEntry(reg).?;
                const spilled_inst = regs_entry.value;
                regs_entry.value = reg_owner;

                const stack_mcv = try self.allocRegOrMem(spilled_inst, false);
                const reg_mcv = self.getResolvedInstValue(spilled_inst);
                assert(reg == toCanonicalReg(reg_mcv.register));
                const branch = &self.branch_stack.items[self.branch_stack.items.len - 1];
                try branch.inst_table.put(self.gpa, spilled_inst, stack_mcv);
                try self.genSetStack(reg_owner.src, spilled_inst.ty, stack_mcv.stack_offset, reg_mcv);

                break :b reg;
            };
            try self.genSetReg(reg_owner.src, reg, mcv);
            return MCValue{ .register = reg };
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

            const operand = try self.resolveInst(inst.operand);
            const info_a = inst.operand.ty.intInfo(self.target.*);
            const info_b = inst.base.ty.intInfo(self.target.*);
            if (info_a.signedness != info_b.signedness)
                return self.fail(inst.base.src, "TODO gen intcast sign safety in semantic analysis", .{});

            if (info_a.bits == info_b.bits)
                return operand;

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
                .arm, .armeb => {
                    var imm = ir.Inst.Constant{
                        .base = .{
                            .tag = .constant,
                            .deaths = 0,
                            .ty = inst.operand.ty,
                            .src = inst.operand.src,
                        },
                        .val = Value.initTag(.bool_true),
                    };
                    return try self.genArmBinOp(&inst.base, inst.operand, &imm.base, .not);
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
                .arm, .armeb => return try self.genArmBinOp(&inst.base, inst.lhs, inst.rhs, .add),
                else => return self.fail(inst.base.src, "TODO implement add for {}", .{self.target.cpu.arch}),
            }
        }

        fn genUnwrapOptional(self: *Self, inst: *ir.Inst.UnOp) !MCValue {
            // No side effects, so if it's unreferenced, do nothing.
            if (inst.base.isUnused())
                return MCValue.dead;
            switch (arch) {
                else => return self.fail(inst.base.src, "TODO implement unwrap optional for {}", .{self.target.cpu.arch}),
            }
        }

        fn genWrapOptional(self: *Self, inst: *ir.Inst.UnOp) !MCValue {
            const optional_ty = inst.base.ty;

            // No side effects, so if it's unreferenced, do nothing.
            if (inst.base.isUnused())
                return MCValue.dead;

            // Optional type is just a boolean true
            if (optional_ty.abiSize(self.target.*) == 1)
                return MCValue{ .immediate = 1 };

            switch (arch) {
                else => return self.fail(inst.base.src, "TODO implement wrap optional for {}", .{self.target.cpu.arch}),
            }
        }

        fn genVarPtr(self: *Self, inst: *ir.Inst.VarPtr) !MCValue {
            // No side effects, so if it's unreferenced, do nothing.
            if (inst.base.isUnused())
                return MCValue.dead;

            switch (arch) {
                else => return self.fail(inst.base.src, "TODO implement varptr for {}", .{self.target.cpu.arch}),
            }
        }

        fn reuseOperand(self: *Self, inst: *ir.Inst, op_index: ir.Inst.DeathsBitIndex, mcv: MCValue) bool {
            if (!inst.operandDies(op_index))
                return false;

            switch (mcv) {
                .register => |reg| {
                    // If it's in the registers table, need to associate the register with the
                    // new instruction.
                    if (self.registers.getEntry(toCanonicalReg(reg))) |entry| {
                        entry.value = inst;
                    }
                    log.debug("reusing {} => {*}", .{ reg, inst });
                },
                .stack_offset => |off| {
                    log.debug("reusing stack offset {} => {*}", .{ off, inst });
                    return true;
                },
                else => return false,
            }

            // Prevent the operand deaths processing code from deallocating it.
            inst.clearOperandDeath(op_index);

            // That makes us responsible for doing the rest of the stuff that processDeath would have done.
            const branch = &self.branch_stack.items[self.branch_stack.items.len - 1];
            branch.inst_table.putAssumeCapacity(inst.getOperand(op_index).?, .dead);

            return true;
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
                if (self.reuseOperand(&inst.base, 0, ptr)) {
                    // The MCValue that holds the pointer can be re-used as the value.
                    break :blk ptr;
                } else {
                    break :blk try self.allocRegOrMem(&inst.base, true);
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
                .arm, .armeb => return try self.genArmBinOp(&inst.base, inst.lhs, inst.rhs, .sub),
                else => return self.fail(inst.base.src, "TODO implement sub for {}", .{self.target.cpu.arch}),
            }
        }

        fn genArmBinOp(self: *Self, inst: *ir.Inst, op_lhs: *ir.Inst, op_rhs: *ir.Inst, op: ir.Inst.Tag) !MCValue {
            const lhs = try self.resolveInst(op_lhs);
            const rhs = try self.resolveInst(op_rhs);

            // Destination must be a register
            // Source may be register, memory or an immediate
            //
            // So there are two options: (lhs is src and rhs is dest)
            // or (rhs is src and lhs is dest)
            const lhs_is_dest = blk: {
                if (self.reuseOperand(inst, 0, lhs)) {
                    break :blk true;
                } else if (self.reuseOperand(inst, 1, rhs)) {
                    break :blk false;
                } else {
                    break :blk lhs == .register;
                }
            };

            var dst_mcv: MCValue = undefined;
            var src_mcv: MCValue = undefined;
            var src_inst: *ir.Inst = undefined;
            if (lhs_is_dest) {
                // LHS is the destination
                // RHS is the source
                src_inst = op_rhs;
                src_mcv = rhs;
                dst_mcv = if (lhs != .register) try self.copyToNewRegister(inst, lhs) else lhs;
            } else {
                // RHS is the destination
                // LHS is the source
                src_inst = op_lhs;
                src_mcv = lhs;
                dst_mcv = if (rhs != .register) try self.copyToNewRegister(inst, rhs) else rhs;
            }

            try self.genArmBinOpCode(inst.src, dst_mcv.register, src_mcv, lhs_is_dest, op);
            return dst_mcv;
        }

        fn genArmBinOpCode(
            self: *Self,
            src: usize,
            dst_reg: Register,
            src_mcv: MCValue,
            lhs_is_dest: bool,
            op: ir.Inst.Tag,
        ) !void {
            const operand = switch (src_mcv) {
                .none => unreachable,
                .undef => unreachable,
                .dead, .unreach => unreachable,
                .compare_flags_unsigned => unreachable,
                .compare_flags_signed => unreachable,
                .ptr_stack_offset => unreachable,
                .ptr_embedded_in_code => unreachable,
                .immediate => |imm| blk: {
                    if (imm > std.math.maxInt(u32)) return self.fail(src, "TODO ARM binary arithmetic immediate larger than u32", .{});

                    // Load immediate into register if it doesn't fit
                    // as an operand
                    break :blk Instruction.Operand.fromU32(@intCast(u32, imm)) orelse
                        Instruction.Operand.reg(try self.copyToTmpRegister(src, src_mcv), Instruction.Operand.Shift.none);
                },
                .register => |src_reg| Instruction.Operand.reg(src_reg, Instruction.Operand.Shift.none),
                .stack_offset,
                .embedded_in_code,
                .memory,
                => Instruction.Operand.reg(try self.copyToTmpRegister(src, src_mcv), Instruction.Operand.Shift.none),
            };

            switch (op) {
                .add => {
                    // TODO runtime safety checks (overflow)
                    writeInt(u32, try self.code.addManyAsArray(4), Instruction.add(.al, dst_reg, dst_reg, operand).toU32());
                },
                .sub => {
                    // TODO runtime safety checks (underflow)
                    if (lhs_is_dest) {
                        writeInt(u32, try self.code.addManyAsArray(4), Instruction.sub(.al, dst_reg, dst_reg, operand).toU32());
                    } else {
                        writeInt(u32, try self.code.addManyAsArray(4), Instruction.rsb(.al, dst_reg, dst_reg, operand).toU32());
                    }
                },
                .booland => {
                    writeInt(u32, try self.code.addManyAsArray(4), Instruction.@"and"(.al, dst_reg, dst_reg, operand).toU32());
                },
                .boolor => {
                    writeInt(u32, try self.code.addManyAsArray(4), Instruction.orr(.al, dst_reg, dst_reg, operand).toU32());
                },
                .not => {
                    writeInt(u32, try self.code.addManyAsArray(4), Instruction.eor(.al, dst_reg, dst_reg, operand).toU32());
                },
                else => unreachable, // not a binary instruction
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
            if (self.reuseOperand(inst, 0, lhs)) {
                // LHS dies; use it as the destination.
                // Both operands cannot be memory.
                src_inst = op_rhs;
                if (lhs.isMemory() and rhs.isMemory()) {
                    dst_mcv = try self.copyToNewRegister(inst, lhs);
                    src_mcv = rhs;
                } else {
                    dst_mcv = lhs;
                    src_mcv = rhs;
                }
            } else if (self.reuseOperand(inst, 1, rhs)) {
                // RHS dies; use it as the destination.
                // Both operands cannot be memory.
                src_inst = op_lhs;
                if (lhs.isMemory() and rhs.isMemory()) {
                    dst_mcv = try self.copyToNewRegister(inst, rhs);
                    src_mcv = lhs;
                } else {
                    dst_mcv = rhs;
                    src_mcv = lhs;
                }
            } else {
                if (lhs.isMemory()) {
                    dst_mcv = try self.copyToNewRegister(inst, lhs);
                    src_mcv = rhs;
                    src_inst = op_rhs;
                } else {
                    dst_mcv = try self.copyToNewRegister(inst, rhs);
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
                        src_mcv = MCValue{ .register = try self.copyToTmpRegister(src_inst.src, src_mcv) };
                    }
                },
                else => {},
            }

            try self.genX8664BinMathCode(inst.src, inst.ty, dst_mcv, src_mcv, opx, mr);

            return dst_mcv;
        }

        fn genX8664BinMathCode(
            self: *Self,
            src: usize,
            dst_ty: Type,
            dst_mcv: MCValue,
            src_mcv: MCValue,
            opx: u8,
            mr: u8,
        ) !void {
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
                .stack_offset => |off| {
                    switch (src_mcv) {
                        .none => unreachable,
                        .undef => return self.genSetStack(src, dst_ty, off, .undef),
                        .dead, .unreach => unreachable,
                        .ptr_stack_offset => unreachable,
                        .ptr_embedded_in_code => unreachable,
                        .register => |src_reg| {
                            try self.genX8664ModRMRegToStack(src, dst_ty, off, src_reg, mr + 0x1);
                        },
                        .immediate => |imm| {
                            return self.fail(src, "TODO implement x86 ADD/SUB/CMP source immediate", .{});
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
                .embedded_in_code, .memory => {
                    return self.fail(src, "TODO implement x86 ADD/SUB/CMP destination memory", .{});
                },
            }
        }

        fn genX8664ModRMRegToStack(self: *Self, src: usize, ty: Type, off: u32, reg: Register, opcode: u8) !void {
            const abi_size = ty.abiSize(self.target.*);
            const adj_off = off + abi_size;
            try self.code.ensureCapacity(self.code.items.len + 7);
            self.rex(.{ .w = reg.size() == 64, .r = reg.isExtended() });
            const reg_id: u8 = @truncate(u3, reg.id());
            if (adj_off <= 128) {
                // example: 48 89 55 7f           mov    QWORD PTR [rbp+0x7f],rdx
                const RM = @as(u8, 0b01_000_101) | (reg_id << 3);
                const negative_offset = @intCast(i8, -@intCast(i32, adj_off));
                const twos_comp = @bitCast(u8, negative_offset);
                self.code.appendSliceAssumeCapacity(&[_]u8{ opcode, RM, twos_comp });
            } else if (adj_off <= 2147483648) {
                // example: 48 89 95 80 00 00 00  mov    QWORD PTR [rbp+0x80],rdx
                const RM = @as(u8, 0b10_000_101) | (reg_id << 3);
                const negative_offset = @intCast(i32, -@intCast(i33, adj_off));
                const twos_comp = @bitCast(u32, negative_offset);
                self.code.appendSliceAssumeCapacity(&[_]u8{ opcode, RM });
                mem.writeIntLittle(u32, self.code.addManyAsArrayAssumeCapacity(4), twos_comp);
            } else {
                return self.fail(src, "stack offset too large", .{});
            }
        }

        fn genArg(self: *Self, inst: *ir.Inst.Arg) !MCValue {
            if (FreeRegInt == u0) {
                return self.fail(inst.base.src, "TODO implement Register enum for {}", .{self.target.cpu.arch});
            }
            if (inst.base.isUnused())
                return MCValue.dead;

            try self.registers.ensureCapacity(self.gpa, self.registers.count() + 1);

            const result = self.args[self.arg_index];
            self.arg_index += 1;

            const name_with_null = inst.name[0 .. mem.lenZ(inst.name) + 1];
            switch (result) {
                .register => |reg| {
                    self.registers.putAssumeCapacityNoClobber(toCanonicalReg(reg), &inst.base);
                    self.markRegUsed(reg);

                    switch (self.debug_output) {
                        .dwarf => |dbg_out| {
                            try dbg_out.dbg_info.ensureCapacity(dbg_out.dbg_info.items.len + 8 + name_with_null.len);
                            dbg_out.dbg_info.appendAssumeCapacity(link.File.Elf.abbrev_parameter);
                            dbg_out.dbg_info.appendSliceAssumeCapacity(&[2]u8{ // DW.AT_location, DW.FORM_exprloc
                                1, // ULEB128 dwarf expression length
                                reg.dwarfLocOp(),
                            });
                            try self.addDbgInfoTypeReloc(inst.base.ty); // DW.AT_type,  DW.FORM_ref4
                            dbg_out.dbg_info.appendSliceAssumeCapacity(name_with_null); // DW.AT_name, DW.FORM_string
                        },
                        .none => {},
                    }
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
                .riscv64 => {
                    mem.writeIntLittle(u32, try self.code.addManyAsArray(4), Instruction.ebreak.toU32());
                },
                .spu_2 => {
                    try self.code.resize(self.code.items.len + 2);
                    var instr = Instruction{ .condition = .always, .input0 = .zero, .input1 = .zero, .modify_flags = false, .output = .discard, .command = .undefined1 };
                    mem.writeIntLittle(u16, self.code.items[self.code.items.len - 2 ..][0..2], @bitCast(u16, instr));
                },
                .arm, .armeb => {
                    writeInt(u32, try self.code.addManyAsArray(4), Instruction.bkpt(0).toU32());
                },
                .aarch64 => {
                    mem.writeIntLittle(u32, try self.code.addManyAsArray(4), Instruction.brk(1).toU32());
                },
                else => return self.fail(src, "TODO implement @breakpoint() for {}", .{self.target.cpu.arch}),
            }
            return .none;
        }

        fn genCall(self: *Self, inst: *ir.Inst.Call) !MCValue {
            var info = try self.resolveCallingConventionValues(inst.base.src, inst.func.ty);
            defer info.deinit(self);

            // Due to incremental compilation, how function calls are generated depends
            // on linking.
            if (self.bin_file.tag == link.File.Elf.base_tag or self.bin_file.tag == link.File.Coff.base_tag) {
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

                                const ptr_bits = self.target.cpu.arch.ptrBitWidth();
                                const ptr_bytes: u64 = @divExact(ptr_bits, 8);
                                const got_addr = if (self.bin_file.cast(link.File.Elf)) |elf_file| blk: {
                                    const got = &elf_file.program_headers.items[elf_file.phdr_got_index.?];
                                    break :blk @intCast(u32, got.p_vaddr + func.owner_decl.link.elf.offset_table_index * ptr_bytes);
                                } else if (self.bin_file.cast(link.File.Coff)) |coff_file|
                                    @intCast(u32, coff_file.offset_table_virtual_address + func.owner_decl.link.coff.offset_table_index * ptr_bytes)
                                else
                                    unreachable;

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
                    .riscv64 => {
                        if (info.args.len > 0) return self.fail(inst.base.src, "TODO implement fn args for {}", .{self.target.cpu.arch});

                        if (inst.func.cast(ir.Inst.Constant)) |func_inst| {
                            if (func_inst.val.cast(Value.Payload.Function)) |func_val| {
                                const func = func_val.func;

                                const ptr_bits = self.target.cpu.arch.ptrBitWidth();
                                const ptr_bytes: u64 = @divExact(ptr_bits, 8);
                                const got_addr = if (self.bin_file.cast(link.File.Elf)) |elf_file| blk: {
                                    const got = &elf_file.program_headers.items[elf_file.phdr_got_index.?];
                                    break :blk @intCast(u32, got.p_vaddr + func.owner_decl.link.elf.offset_table_index * ptr_bytes);
                                } else if (self.bin_file.cast(link.File.Coff)) |coff_file|
                                    coff_file.offset_table_virtual_address + func.owner_decl.link.coff.offset_table_index * ptr_bytes
                                else
                                    unreachable;

                                try self.genSetReg(inst.base.src, .ra, .{ .memory = got_addr });
                                mem.writeIntLittle(u32, try self.code.addManyAsArray(4), Instruction.jalr(.ra, 0, .ra).toU32());
                            } else {
                                return self.fail(inst.base.src, "TODO implement calling bitcasted functions", .{});
                            }
                        } else {
                            return self.fail(inst.base.src, "TODO implement calling runtime known function pointer", .{});
                        }
                    },
                    .spu_2 => {
                        if (inst.func.cast(ir.Inst.Constant)) |func_inst| {
                            if (info.args.len != 0) {
                                return self.fail(inst.base.src, "TODO implement call with more than 0 parameters", .{});
                            }
                            if (func_inst.val.cast(Value.Payload.Function)) |func_val| {
                                const func = func_val.func;
                                const got_addr = if (self.bin_file.cast(link.File.Elf)) |elf_file| blk: {
                                    const got = &elf_file.program_headers.items[elf_file.phdr_got_index.?];
                                    break :blk @intCast(u16, got.p_vaddr + func.owner_decl.link.elf.offset_table_index * 2);
                                } else if (self.bin_file.cast(link.File.Coff)) |coff_file|
                                    @intCast(u16, coff_file.offset_table_virtual_address + func.owner_decl.link.coff.offset_table_index * 2)
                                else
                                    unreachable;

                                const return_type = func.owner_decl.typed_value.most_recent.typed_value.ty.fnReturnType();
                                // First, push the return address, then jump; if noreturn, don't bother with the first step
                                // TODO: implement packed struct -> u16 at comptime and move the bitcast here
                                var instr = Instruction{ .condition = .always, .input0 = .immediate, .input1 = .zero, .modify_flags = false, .output = .jump, .command = .load16 };
                                if (return_type.zigTypeTag() == .NoReturn) {
                                    try self.code.resize(self.code.items.len + 4);
                                    mem.writeIntLittle(u16, self.code.items[self.code.items.len - 4 ..][0..2], @bitCast(u16, instr));
                                    mem.writeIntLittle(u16, self.code.items[self.code.items.len - 2 ..][0..2], got_addr);
                                    return MCValue.unreach;
                                } else {
                                    try self.code.resize(self.code.items.len + 8);
                                    var push = Instruction{ .condition = .always, .input0 = .immediate, .input1 = .zero, .modify_flags = false, .output = .push, .command = .ipget };
                                    mem.writeIntLittle(u16, self.code.items[self.code.items.len - 8 ..][0..2], @bitCast(u16, push));
                                    mem.writeIntLittle(u16, self.code.items[self.code.items.len - 6 ..][0..2], @as(u16, 4));
                                    mem.writeIntLittle(u16, self.code.items[self.code.items.len - 4 ..][0..2], @bitCast(u16, instr));
                                    mem.writeIntLittle(u16, self.code.items[self.code.items.len - 2 ..][0..2], got_addr);
                                    switch (return_type.zigTypeTag()) {
                                        .Void => return MCValue{ .none = {} },
                                        .NoReturn => unreachable,
                                        else => return self.fail(inst.base.src, "TODO implement fn call with non-void return value", .{}),
                                    }
                                }
                            } else {
                                return self.fail(inst.base.src, "TODO implement calling bitcasted functions", .{});
                            }
                        } else {
                            return self.fail(inst.base.src, "TODO implement calling runtime known function pointer", .{});
                        }
                    },
                    .arm, .armeb => {
                        for (info.args) |mc_arg, arg_i| {
                            const arg = inst.args[arg_i];
                            const arg_mcv = try self.resolveInst(inst.args[arg_i]);

                            switch (mc_arg) {
                                .none => continue,
                                .undef => unreachable,
                                .immediate => unreachable,
                                .unreach => unreachable,
                                .dead => unreachable,
                                .embedded_in_code => unreachable,
                                .memory => unreachable,
                                .compare_flags_signed => unreachable,
                                .compare_flags_unsigned => unreachable,
                                .register => |reg| {
                                    try self.genSetReg(arg.src, reg, arg_mcv);
                                    // TODO interact with the register allocator to mark the instruction as moved.
                                },
                                .stack_offset => {
                                    return self.fail(inst.base.src, "TODO implement calling with parameters in memory", .{});
                                },
                                .ptr_stack_offset => {
                                    return self.fail(inst.base.src, "TODO implement calling with MCValue.ptr_stack_offset arg", .{});
                                },
                                .ptr_embedded_in_code => {
                                    return self.fail(inst.base.src, "TODO implement calling with MCValue.ptr_embedded_in_code arg", .{});
                                },
                            }
                        }

                        if (inst.func.cast(ir.Inst.Constant)) |func_inst| {
                            if (func_inst.val.cast(Value.Payload.Function)) |func_val| {
                                const func = func_val.func;
                                const ptr_bits = self.target.cpu.arch.ptrBitWidth();
                                const ptr_bytes: u64 = @divExact(ptr_bits, 8);
                                const got_addr = if (self.bin_file.cast(link.File.Elf)) |elf_file| blk: {
                                    const got = &elf_file.program_headers.items[elf_file.phdr_got_index.?];
                                    break :blk @intCast(u32, got.p_vaddr + func.owner_decl.link.elf.offset_table_index * ptr_bytes);
                                } else if (self.bin_file.cast(link.File.Coff)) |coff_file|
                                    coff_file.offset_table_virtual_address + func.owner_decl.link.coff.offset_table_index * ptr_bytes
                                else
                                    unreachable;

                                try self.genSetReg(inst.base.src, .lr, .{ .memory = got_addr });

                                // TODO: add Instruction.supportedOn
                                // function for ARM
                                if (Target.arm.featureSetHas(self.target.cpu.features, .has_v5t)) {
                                    writeInt(u32, try self.code.addManyAsArray(4), Instruction.blx(.al, .lr).toU32());
                                } else {
                                    writeInt(u32, try self.code.addManyAsArray(4), Instruction.mov(.al, .lr, Instruction.Operand.reg(.pc, Instruction.Operand.Shift.none)).toU32());
                                    writeInt(u32, try self.code.addManyAsArray(4), Instruction.bx(.al, .lr).toU32());
                                }
                            } else {
                                return self.fail(inst.base.src, "TODO implement calling bitcasted functions", .{});
                            }
                        } else {
                            return self.fail(inst.base.src, "TODO implement calling runtime known function pointer", .{});
                        }
                    },
                    .aarch64 => {
                        for (info.args) |mc_arg, arg_i| {
                            const arg = inst.args[arg_i];
                            const arg_mcv = try self.resolveInst(inst.args[arg_i]);

                            switch (mc_arg) {
                                .none => continue,
                                .undef => unreachable,
                                .immediate => unreachable,
                                .unreach => unreachable,
                                .dead => unreachable,
                                .embedded_in_code => unreachable,
                                .memory => unreachable,
                                .compare_flags_signed => unreachable,
                                .compare_flags_unsigned => unreachable,
                                .register => |reg| {
                                    try self.genSetReg(arg.src, reg, arg_mcv);
                                    // TODO interact with the register allocator to mark the instruction as moved.
                                },
                                .stack_offset => {
                                    return self.fail(inst.base.src, "TODO implement calling with parameters in memory", .{});
                                },
                                .ptr_stack_offset => {
                                    return self.fail(inst.base.src, "TODO implement calling with MCValue.ptr_stack_offset arg", .{});
                                },
                                .ptr_embedded_in_code => {
                                    return self.fail(inst.base.src, "TODO implement calling with MCValue.ptr_embedded_in_code arg", .{});
                                },
                            }
                        }

                        if (inst.func.cast(ir.Inst.Constant)) |func_inst| {
                            if (func_inst.val.cast(Value.Payload.Function)) |func_val| {
                                const func = func_val.func;
                                const ptr_bits = self.target.cpu.arch.ptrBitWidth();
                                const ptr_bytes: u64 = @divExact(ptr_bits, 8);
                                const got_addr = if (self.bin_file.cast(link.File.Elf)) |elf_file| blk: {
                                    const got = &elf_file.program_headers.items[elf_file.phdr_got_index.?];
                                    break :blk @intCast(u32, got.p_vaddr + func.owner_decl.link.elf.offset_table_index * ptr_bytes);
                                } else if (self.bin_file.cast(link.File.Coff)) |coff_file|
                                    coff_file.offset_table_virtual_address + func.owner_decl.link.coff.offset_table_index * ptr_bytes
                                else
                                    unreachable;

                                try self.genSetReg(inst.base.src, .x30, .{ .memory = got_addr });

                                writeInt(u32, try self.code.addManyAsArray(4), Instruction.blr(.x30).toU32());
                            } else {
                                return self.fail(inst.base.src, "TODO implement calling bitcasted functions", .{});
                            }
                        } else {
                            return self.fail(inst.base.src, "TODO implement calling runtime known function pointer", .{});
                        }
                    },
                    else => return self.fail(inst.base.src, "TODO implement call for {}", .{self.target.cpu.arch}),
                }
            } else if (self.bin_file.cast(link.File.MachO)) |macho_file| {
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
                        const got = &macho_file.sections.items[macho_file.got_section_index.?];
                        const got_addr = got.addr + func.owner_decl.link.macho.offset_table_index * @sizeOf(u64);
                        switch (arch) {
                            .x86_64 => {
                                try self.genSetReg(inst.base.src, .rax, .{ .memory = got_addr });
                                // callq *%rax
                                self.code.appendSliceAssumeCapacity(&[2]u8{ 0xff, 0xd0 });
                            },
                            .aarch64 => {
                                try self.genSetReg(inst.base.src, .x30, .{ .memory = got_addr });
                                // blr x30
                                writeInt(u32, try self.code.addManyAsArray(4), Instruction.blr(.x30).toU32());
                            },
                            else => unreachable, // unsupported architecture on MachO
                        }
                    } else {
                        return self.fail(inst.base.src, "TODO implement calling bitcasted functions", .{});
                    }
                } else {
                    return self.fail(inst.base.src, "TODO implement calling runtime known function pointer", .{});
                }
            } else {
                unreachable;
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
                .riscv64 => {
                    mem.writeIntLittle(u32, try self.code.addManyAsArray(4), Instruction.jalr(.zero, 0, .ra).toU32());
                },
                .arm, .armeb => {
                    // Just add space for an instruction, patch this later
                    try self.code.resize(self.code.items.len + 4);
                    try self.exitlude_jump_relocs.append(self.gpa, self.code.items.len - 4);
                },
                .aarch64 => {
                    // TODO: relocations
                    writeInt(u32, try self.code.addManyAsArray(4), Instruction.ret(null).toU32());
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
                return MCValue{ .dead = {} };
            switch (arch) {
                .x86_64 => {
                    try self.code.ensureCapacity(self.code.items.len + 8);

                    const lhs = try self.resolveInst(inst.lhs);
                    const rhs = try self.resolveInst(inst.rhs);

                    // There are 2 operands, destination and source.
                    // Either one, but not both, can be a memory operand.
                    // Source operand can be an immediate, 8 bits or 32 bits.
                    const dst_mcv = if (lhs.isImmediate() or (lhs.isMemory() and rhs.isMemory()))
                        try self.copyToNewRegister(&inst.base, lhs)
                    else
                        lhs;
                    // This instruction supports only signed 32-bit immediates at most.
                    const src_mcv = try self.limitImmediateType(inst.rhs, i32);

                    try self.genX8664BinMathCode(inst.base.src, inst.base.ty, dst_mcv, src_mcv, 7, 0x38);
                    const info = inst.lhs.ty.intInfo(self.target.*);
                    return switch (info.signedness) {
                        .signed => MCValue{ .compare_flags_signed = op },
                        .unsigned => MCValue{ .compare_flags_unsigned = op },
                    };
                },
                else => return self.fail(inst.base.src, "TODO implement cmp for {}", .{self.target.cpu.arch}),
            }
        }

        fn genDbgStmt(self: *Self, inst: *ir.Inst.NoOp) !MCValue {
            try self.dbgAdvancePCAndLine(inst.base.src);
            assert(inst.base.isUnused());
            return MCValue.dead;
        }

        fn genCondBr(self: *Self, inst: *ir.Inst.CondBr) !MCValue {
            const cond = try self.resolveInst(inst.condition);

            const reloc: Reloc = switch (arch) {
                .i386, .x86_64 => reloc: {
                    try self.code.ensureCapacity(self.code.items.len + 6);

                    const opcode: u8 = switch (cond) {
                        .compare_flags_signed => |cmp_op| blk: {
                            // Here we map to the opposite opcode because the jump is to the false branch.
                            const opcode: u8 = switch (cmp_op) {
                                .gte => 0x8c,
                                .gt => 0x8e,
                                .neq => 0x84,
                                .lt => 0x8d,
                                .lte => 0x8f,
                                .eq => 0x85,
                            };
                            break :blk opcode;
                        },
                        .compare_flags_unsigned => |cmp_op| blk: {
                            // Here we map to the opposite opcode because the jump is to the false branch.
                            const opcode: u8 = switch (cmp_op) {
                                .gte => 0x82,
                                .gt => 0x86,
                                .neq => 0x84,
                                .lt => 0x83,
                                .lte => 0x87,
                                .eq => 0x85,
                            };
                            break :blk opcode;
                        },
                        .register => |reg| blk: {
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
                            break :blk 0x84;
                        },
                        else => return self.fail(inst.base.src, "TODO implement condbr {} when condition is {}", .{ self.target.cpu.arch, @tagName(cond) }),
                    };
                    self.code.appendSliceAssumeCapacity(&[_]u8{ 0x0f, opcode });
                    const reloc = Reloc{ .rel32 = self.code.items.len };
                    self.code.items.len += 4;
                    break :reloc reloc;
                },
                else => return self.fail(inst.base.src, "TODO implement condbr {}", .{self.target.cpu.arch}),
            };

            // Capture the state of register and stack allocation state so that we can revert to it.
            const parent_next_stack_offset = self.next_stack_offset;
            const parent_free_registers = self.free_registers;
            var parent_stack = try self.stack.clone(self.gpa);
            defer parent_stack.deinit(self.gpa);
            var parent_registers = try self.registers.clone(self.gpa);
            defer parent_registers.deinit(self.gpa);

            try self.branch_stack.append(.{});

            const then_deaths = inst.thenDeaths();
            try self.ensureProcessDeathCapacity(then_deaths.len);
            for (then_deaths) |operand| {
                self.processDeath(operand);
            }
            try self.genBody(inst.then_body);

            // Revert to the previous register and stack allocation state.

            var saved_then_branch = self.branch_stack.pop();
            defer saved_then_branch.deinit(self.gpa);

            self.registers.deinit(self.gpa);
            self.registers = parent_registers;
            parent_registers = .{};

            self.stack.deinit(self.gpa);
            self.stack = parent_stack;
            parent_stack = .{};

            self.next_stack_offset = parent_next_stack_offset;
            self.free_registers = parent_free_registers;

            try self.performReloc(inst.base.src, reloc);
            const else_branch = self.branch_stack.addOneAssumeCapacity();
            else_branch.* = .{};

            const else_deaths = inst.elseDeaths();
            try self.ensureProcessDeathCapacity(else_deaths.len);
            for (else_deaths) |operand| {
                self.processDeath(operand);
            }
            try self.genBody(inst.else_body);

            // At this point, each branch will possibly have conflicting values for where
            // each instruction is stored. They agree, however, on which instructions are alive/dead.
            // We use the first ("then") branch as canonical, and here emit
            // instructions into the second ("else") branch to make it conform.
            // We continue respect the data structure semantic guarantees of the else_branch so
            // that we can use all the code emitting abstractions. This is why at the bottom we
            // assert that parent_branch.free_registers equals the saved_then_branch.free_registers
            // rather than assigning it.
            const parent_branch = &self.branch_stack.items[self.branch_stack.items.len - 2];
            try parent_branch.inst_table.ensureCapacity(self.gpa, parent_branch.inst_table.items().len +
                else_branch.inst_table.items().len);
            for (else_branch.inst_table.items()) |else_entry| {
                const canon_mcv = if (saved_then_branch.inst_table.remove(else_entry.key)) |then_entry| blk: {
                    // The instruction's MCValue is overridden in both branches.
                    parent_branch.inst_table.putAssumeCapacity(else_entry.key, then_entry.value);
                    if (else_entry.value == .dead) {
                        assert(then_entry.value == .dead);
                        continue;
                    }
                    break :blk then_entry.value;
                } else blk: {
                    if (else_entry.value == .dead)
                        continue;
                    // The instruction is only overridden in the else branch.
                    var i: usize = self.branch_stack.items.len - 2;
                    while (true) {
                        i -= 1; // If this overflows, the question is: why wasn't the instruction marked dead?
                        if (self.branch_stack.items[i].inst_table.get(else_entry.key)) |mcv| {
                            assert(mcv != .dead);
                            break :blk mcv;
                        }
                    }
                };
                log.debug("consolidating else_entry {*} {}=>{}", .{ else_entry.key, else_entry.value, canon_mcv });
                // TODO make sure the destination stack offset / register does not already have something
                // going on there.
                try self.setRegOrMem(inst.base.src, else_entry.key.ty, canon_mcv, else_entry.value);
                // TODO track the new register / stack allocation
            }
            try parent_branch.inst_table.ensureCapacity(self.gpa, parent_branch.inst_table.items().len +
                saved_then_branch.inst_table.items().len);
            for (saved_then_branch.inst_table.items()) |then_entry| {
                // We already deleted the items from this table that matched the else_branch.
                // So these are all instructions that are only overridden in the then branch.
                parent_branch.inst_table.putAssumeCapacity(then_entry.key, then_entry.value);
                if (then_entry.value == .dead)
                    continue;
                const parent_mcv = blk: {
                    var i: usize = self.branch_stack.items.len - 2;
                    while (true) {
                        i -= 1;
                        if (self.branch_stack.items[i].inst_table.get(then_entry.key)) |mcv| {
                            assert(mcv != .dead);
                            break :blk mcv;
                        }
                    }
                };
                log.debug("consolidating then_entry {*} {}=>{}", .{ then_entry.key, parent_mcv, then_entry.value });
                // TODO make sure the destination stack offset / register does not already have something
                // going on there.
                try self.setRegOrMem(inst.base.src, then_entry.key.ty, parent_mcv, then_entry.value);
                // TODO track the new register / stack allocation
            }

            self.branch_stack.pop().deinit(self.gpa);

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

        fn genIsErr(self: *Self, inst: *ir.Inst.UnOp) !MCValue {
            switch (arch) {
                else => return self.fail(inst.base.src, "TODO implement iserr for {}", .{self.target.cpu.arch}),
            }
        }

        fn genLoop(self: *Self, inst: *ir.Inst.Loop) !MCValue {
            // A loop is a setup to be able to jump back to the beginning.
            const start_index = self.code.items.len;
            try self.genBody(inst.body);
            try self.jump(inst.base.src, start_index);
            return MCValue.unreach;
        }

        /// Send control flow to the `index` of `self.code`.
        fn jump(self: *Self, src: usize, index: usize) !void {
            switch (arch) {
                .i386, .x86_64 => {
                    try self.code.ensureCapacity(self.code.items.len + 5);
                    if (math.cast(i8, @intCast(i32, index) - (@intCast(i32, self.code.items.len + 2)))) |delta| {
                        self.code.appendAssumeCapacity(0xeb); // jmp rel8
                        self.code.appendAssumeCapacity(@bitCast(u8, delta));
                    } else |_| {
                        const delta = @intCast(i32, index) - (@intCast(i32, self.code.items.len + 5));
                        self.code.appendAssumeCapacity(0xe9); // jmp rel32
                        mem.writeIntLittle(i32, self.code.addManyAsArrayAssumeCapacity(4), delta);
                    }
                },
                .arm, .armeb => {
                    if (math.cast(i26, @intCast(i32, index) - @intCast(i32, self.code.items.len))) |delta| {
                        writeInt(u32, try self.code.addManyAsArray(4), Instruction.b(.al, delta).toU32());
                    } else |err| {
                        return self.fail(src, "TODO: enable larger branch offset", .{});
                    }
                },
                else => return self.fail(src, "TODO implement jump for {}", .{self.target.cpu.arch}),
            }
        }

        fn genBlock(self: *Self, inst: *ir.Inst.Block) !MCValue {
            inst.codegen = .{
                // A block is a setup to be able to jump to the end.
                .relocs = .{},
                // It also acts as a receptical for break operands.
                // Here we use `MCValue.none` to represent a null value so that the first
                // break instruction will choose a MCValue for the block result and overwrite
                // this field. Following break instructions will use that MCValue to put their
                // block results.
                .mcv = @bitCast(AnyMCValue, MCValue{ .none = {} }),
            };
            defer inst.codegen.relocs.deinit(self.gpa);

            try self.genBody(inst.body);

            for (inst.codegen.relocs.items) |reloc| try self.performReloc(inst.base.src, reloc);

            return @bitCast(MCValue, inst.codegen.mcv);
        }

        fn genSwitch(self: *Self, inst: *ir.Inst.SwitchBr) !MCValue {
            switch (arch) {
                else => return self.fail(inst.base.src, "TODO genSwitch for {}", .{self.target.cpu.arch}),
            }
        }

        fn performReloc(self: *Self, src: usize, reloc: Reloc) !void {
            switch (reloc) {
                .rel32 => |pos| {
                    const amt = self.code.items.len - (pos + 4);
                    // Here it would be tempting to implement testing for amt == 0 and then elide the
                    // jump. However, that will cause a problem because other jumps may assume that they
                    // can jump to this code. Or maybe I didn't understand something when I was debugging.
                    // It could be worth another look. Anyway, that's why that isn't done here. Probably the
                    // best place to elide jumps will be in semantic analysis, by inlining blocks that only
                    // only have 1 break instruction.
                    const s32_amt = math.cast(i32, amt) catch
                        return self.fail(src, "unable to perform relocation: jump too far", .{});
                    mem.writeIntLittle(i32, self.code.items[pos..][0..4], s32_amt);
                },
            }
        }

        fn genBr(self: *Self, inst: *ir.Inst.Br) !MCValue {
            if (inst.operand.ty.hasCodeGenBits()) {
                const operand = try self.resolveInst(inst.operand);
                const block_mcv = @bitCast(MCValue, inst.block.codegen.mcv);
                if (block_mcv == .none) {
                    inst.block.codegen.mcv = @bitCast(AnyMCValue, operand);
                } else {
                    try self.setRegOrMem(inst.base.src, inst.block.base.ty, block_mcv, operand);
                }
            }
            return self.brVoid(inst.base.src, inst.block);
        }

        fn genBrVoid(self: *Self, inst: *ir.Inst.BrVoid) !MCValue {
            return self.brVoid(inst.base.src, inst.block);
        }

        fn genBoolOp(self: *Self, inst: *ir.Inst.BinOp) !MCValue {
            if (inst.base.isUnused())
                return MCValue.dead;
            switch (arch) {
                .x86_64 => switch (inst.base.tag) {
                    // lhs AND rhs
                    .booland => return try self.genX8664BinMath(&inst.base, inst.lhs, inst.rhs, 4, 0x20),
                    // lhs OR rhs
                    .boolor => return try self.genX8664BinMath(&inst.base, inst.lhs, inst.rhs, 1, 0x08),
                    else => unreachable, // Not a boolean operation
                },
                .arm, .armeb => switch (inst.base.tag) {
                    .booland => return try self.genArmBinOp(&inst.base, inst.lhs, inst.rhs, .booland),
                    .boolor => return try self.genArmBinOp(&inst.base, inst.lhs, inst.rhs, .boolor),
                    else => unreachable, // Not a boolean operation
                },
                else => return self.fail(inst.base.src, "TODO implement boolean operations for {}", .{self.target.cpu.arch}),
            }
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
            switch (arch) {
                .spu_2 => {
                    if (inst.inputs.len > 0 or inst.output != null) {
                        return self.fail(inst.base.src, "TODO implement inline asm inputs / outputs for SPU Mark II", .{});
                    }
                    if (mem.eql(u8, inst.asm_source, "undefined0")) {
                        try self.code.resize(self.code.items.len + 2);
                        var instr = Instruction{ .condition = .always, .input0 = .zero, .input1 = .zero, .modify_flags = false, .output = .discard, .command = .undefined0 };
                        mem.writeIntLittle(u16, self.code.items[self.code.items.len - 2 ..][0..2], @bitCast(u16, instr));
                        return MCValue.none;
                    } else {
                        return self.fail(inst.base.src, "TODO implement support for more SPU II assembly instructions", .{});
                    }
                },
                .arm, .armeb => {
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

                    if (mem.eql(u8, inst.asm_source, "svc #0")) {
                        writeInt(u32, try self.code.addManyAsArray(4), Instruction.svc(.al, 0).toU32());
                    } else {
                        return self.fail(inst.base.src, "TODO implement support for more arm assembly instructions", .{});
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
                },
                .aarch64 => {
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

                    // TODO move this to lib/std/{elf, macho}.zig, etc.
                    const is_syscall_inst = switch (self.bin_file.tag) {
                        .macho => mem.eql(u8, inst.asm_source, "svc #0x80"),
                        .elf => mem.eql(u8, inst.asm_source, "svc #0"),
                        else => |tag| return self.fail(inst.base.src, "TODO implement aarch64 support for other syscall instructions for file format: '{}'", .{tag}),
                    };
                    if (is_syscall_inst) {
                        const imm16: u16 = switch (self.bin_file.tag) {
                            .macho => 0x80,
                            .elf => 0,
                            else => unreachable,
                        };
                        mem.writeIntLittle(u32, try self.code.addManyAsArray(4), Instruction.svc(imm16).toU32());
                    } else {
                        return self.fail(inst.base.src, "TODO implement support for more aarch64 assembly instructions", .{});
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
                },
                .riscv64 => {
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

                    if (mem.eql(u8, inst.asm_source, "ecall")) {
                        mem.writeIntLittle(u32, try self.code.addManyAsArray(4), Instruction.ecall.toU32());
                    } else {
                        return self.fail(inst.base.src, "TODO implement support for more riscv64 assembly instructions", .{});
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
                },
                .x86_64, .i386 => {
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
                    } else if (inst.asm_source.len != 0) {
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
                },
                else => return self.fail(inst.base.src, "TODO implement inline asm support for more architectures", .{}),
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
        /// W => 64 bit mode
        /// R => extension to the MODRM.reg field
        /// X => extension to the SIB.index field
        /// B => extension to the MODRM.rm field or the SIB.base field
        fn rex(self: *Self, arg: struct { b: bool = false, w: bool = false, x: bool = false, r: bool = false }) void {
            comptime assert(arch == .x86_64);
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
                .arm, .armeb => switch (mcv) {
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
                    .immediate => {
                        const reg = try self.copyToTmpRegister(src, mcv);
                        return self.genSetStack(src, ty, stack_offset, MCValue{ .register = reg });
                    },
                    .embedded_in_code => |code_offset| {
                        return self.fail(src, "TODO implement set stack variable from embedded_in_code", .{});
                    },
                    .register => |reg| {
                        // TODO: strh
                        const offset = if (stack_offset <= math.maxInt(u12)) blk: {
                            break :blk Instruction.Offset.imm(@intCast(u12, stack_offset));
                        } else Instruction.Offset.reg(try self.copyToTmpRegister(src, MCValue{ .immediate = stack_offset }), 0);

                        const abi_size = ty.abiSize(self.target.*);
                        switch (abi_size) {
                            1 => writeInt(u32, try self.code.addManyAsArray(4), Instruction.strb(.al, reg, .fp, .{
                                .offset = offset,
                                .positive = false,
                            }).toU32()),
                            2 => return self.fail(src, "TODO implement strh", .{}),
                            4 => writeInt(u32, try self.code.addManyAsArray(4), Instruction.str(.al, reg, .fp, .{
                                .offset = offset,
                                .positive = false,
                            }).toU32()),
                            else => return self.fail(src, "TODO a type of size {} is not allowed in a register", .{abi_size}),
                        }
                    },
                    .memory => |vaddr| {
                        return self.fail(src, "TODO implement set stack variable from memory vaddr", .{});
                    },
                    .stack_offset => |off| {
                        if (stack_offset == off)
                            return; // Copy stack variable to itself; nothing to do.

                        const reg = try self.copyToTmpRegister(src, mcv);
                        return self.genSetStack(src, ty, stack_offset, MCValue{ .register = reg });
                    },
                },
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
                                // We have a positive stack offset value but we want a twos complement negative
                                // offset from rbp, which is at the top of the stack frame.
                                const negative_offset = @intCast(i8, -@intCast(i32, adj_off));
                                const twos_comp = @bitCast(u8, negative_offset);

                                // 64 bit write to memory would take two mov's anyways so we
                                // insted just use two 32 bit writes to avoid register allocation
                                try self.code.ensureCapacity(self.code.items.len + 14);
                                var buf: [8]u8 = undefined;
                                mem.writeIntLittle(u64, &buf, x_big);

                                // mov    DWORD PTR [rbp+offset+4], immediate
                                self.code.appendSliceAssumeCapacity(&[_]u8{ 0xc7, 0x45, twos_comp + 4 });
                                self.code.appendSliceAssumeCapacity(buf[4..8]);

                                // mov    DWORD PTR [rbp+offset], immediate
                                self.code.appendSliceAssumeCapacity(&[_]u8{ 0xc7, 0x45, twos_comp });
                                self.code.appendSliceAssumeCapacity(buf[0..4]);
                            },
                            else => {
                                return self.fail(src, "TODO implement set abi_size=large stack variable with immediate", .{});
                            },
                        }
                    },
                    .embedded_in_code => |code_offset| {
                        return self.fail(src, "TODO implement set stack variable from embedded_in_code", .{});
                    },
                    .register => |reg| {
                        try self.genX8664ModRMRegToStack(src, ty, stack_offset, reg, 0x89);
                    },
                    .memory => |vaddr| {
                        return self.fail(src, "TODO implement set stack variable from memory vaddr", .{});
                    },
                    .stack_offset => |off| {
                        if (stack_offset == off)
                            return; // Copy stack variable to itself; nothing to do.

                        const reg = try self.copyToTmpRegister(src, mcv);
                        return self.genSetStack(src, ty, stack_offset, MCValue{ .register = reg });
                    },
                },
                else => return self.fail(src, "TODO implement getSetStack for {}", .{self.target.cpu.arch}),
            }
        }

        fn genSetReg(self: *Self, src: usize, reg: Register, mcv: MCValue) InnerError!void {
            switch (arch) {
                .arm, .armeb => switch (mcv) {
                    .dead => unreachable,
                    .ptr_stack_offset => unreachable,
                    .ptr_embedded_in_code => unreachable,
                    .unreach, .none => return, // Nothing to do.
                    .undef => {
                        if (!self.wantSafety())
                            return; // The already existing value will do just fine.
                        // Write the debug undefined value.
                        return self.genSetReg(src, reg, .{ .immediate = 0xaaaaaaaa });
                    },
                    .immediate => |x| {
                        if (x > math.maxInt(u32)) return self.fail(src, "ARM registers are 32-bit wide", .{});

                        if (Instruction.Operand.fromU32(@intCast(u32, x))) |op| {
                            writeInt(u32, try self.code.addManyAsArray(4), Instruction.mov(.al, reg, op).toU32());
                        } else if (Instruction.Operand.fromU32(~@intCast(u32, x))) |op| {
                            writeInt(u32, try self.code.addManyAsArray(4), Instruction.mvn(.al, reg, op).toU32());
                        } else if (x <= math.maxInt(u16)) {
                            if (Target.arm.featureSetHas(self.target.cpu.features, .has_v7)) {
                                writeInt(u32, try self.code.addManyAsArray(4), Instruction.movw(.al, reg, @intCast(u16, x)).toU32());
                            } else {
                                writeInt(u32, try self.code.addManyAsArray(4), Instruction.mov(.al, reg, Instruction.Operand.imm(@truncate(u8, x), 0)).toU32());
                                writeInt(u32, try self.code.addManyAsArray(4), Instruction.orr(.al, reg, reg, Instruction.Operand.imm(@truncate(u8, x >> 8), 12)).toU32());
                            }
                        } else {
                            // TODO write constant to code and load
                            // relative to pc
                            if (Target.arm.featureSetHas(self.target.cpu.features, .has_v7)) {
                                // immediate: 0xaaaabbbb
                                // movw reg, #0xbbbb
                                // movt reg, #0xaaaa
                                writeInt(u32, try self.code.addManyAsArray(4), Instruction.movw(.al, reg, @truncate(u16, x)).toU32());
                                writeInt(u32, try self.code.addManyAsArray(4), Instruction.movt(.al, reg, @truncate(u16, x >> 16)).toU32());
                            } else {
                                // immediate: 0xaabbccdd
                                // mov reg, #0xaa
                                // orr reg, reg, #0xbb, 24
                                // orr reg, reg, #0xcc, 16
                                // orr reg, reg, #0xdd, 8
                                writeInt(u32, try self.code.addManyAsArray(4), Instruction.mov(.al, reg, Instruction.Operand.imm(@truncate(u8, x), 0)).toU32());
                                writeInt(u32, try self.code.addManyAsArray(4), Instruction.orr(.al, reg, reg, Instruction.Operand.imm(@truncate(u8, x >> 8), 12)).toU32());
                                writeInt(u32, try self.code.addManyAsArray(4), Instruction.orr(.al, reg, reg, Instruction.Operand.imm(@truncate(u8, x >> 16), 8)).toU32());
                                writeInt(u32, try self.code.addManyAsArray(4), Instruction.orr(.al, reg, reg, Instruction.Operand.imm(@truncate(u8, x >> 24), 4)).toU32());
                            }
                        }
                    },
                    .register => |src_reg| {
                        // If the registers are the same, nothing to do.
                        if (src_reg.id() == reg.id())
                            return;

                        // mov reg, src_reg
                        writeInt(u32, try self.code.addManyAsArray(4), Instruction.mov(.al, reg, Instruction.Operand.reg(src_reg, Instruction.Operand.Shift.none)).toU32());
                    },
                    .memory => |addr| {
                        // The value is in memory at a hard-coded address.
                        // If the type is a pointer, it means the pointer address is at this memory location.
                        try self.genSetReg(src, reg, .{ .immediate = addr });
                        writeInt(u32, try self.code.addManyAsArray(4), Instruction.ldr(.al, reg, reg, .{ .offset = Instruction.Offset.none }).toU32());
                    },
                    .stack_offset => |unadjusted_off| {
                        // TODO: ldrh
                        // TODO: maybe addressing from sp instead of fp
                        const offset = if (unadjusted_off <= math.maxInt(u12)) blk: {
                            break :blk Instruction.Offset.imm(@intCast(u12, unadjusted_off));
                        } else Instruction.Offset.reg(try self.copyToTmpRegister(src, MCValue{ .immediate = unadjusted_off }), 0);

                        // TODO: supply type information to genSetReg as we do to genSetStack
                        // const abi_size = ty.abiSize(self.target.*);
                        const abi_size = 4;
                        switch (abi_size) {
                            1 => writeInt(u32, try self.code.addManyAsArray(4), Instruction.ldrb(.al, reg, .fp, .{
                                .offset = offset,
                                .positive = false,
                            }).toU32()),
                            2 => return self.fail(src, "TODO implement strh", .{}),
                            4 => writeInt(u32, try self.code.addManyAsArray(4), Instruction.ldr(.al, reg, .fp, .{
                                .offset = offset,
                                .positive = false,
                            }).toU32()),
                            else => return self.fail(src, "TODO a type of size {} is not allowed in a register", .{abi_size}),
                        }
                    },
                    else => return self.fail(src, "TODO implement getSetReg for arm {}", .{mcv}),
                },
                .aarch64 => switch (mcv) {
                    .dead => unreachable,
                    .ptr_stack_offset => unreachable,
                    .ptr_embedded_in_code => unreachable,
                    .unreach, .none => return, // Nothing to do.
                    .undef => {
                        if (!self.wantSafety())
                            return; // The already existing value will do just fine.
                        // Write the debug undefined value.
                        switch (reg.size()) {
                            32 => return self.genSetReg(src, reg, .{ .immediate = 0xaaaaaaaa }),
                            64 => return self.genSetReg(src, reg, .{ .immediate = 0xaaaaaaaaaaaaaaaa }),
                            else => unreachable, // unexpected register size
                        }
                    },
                    .immediate => |x| {
                        if (x <= math.maxInt(u16)) {
                            mem.writeIntLittle(u32, try self.code.addManyAsArray(4), Instruction.movz(reg, @intCast(u16, x), 0).toU32());
                        } else if (x <= math.maxInt(u32)) {
                            mem.writeIntLittle(u32, try self.code.addManyAsArray(4), Instruction.movz(reg, @truncate(u16, x), 0).toU32());
                            mem.writeIntLittle(u32, try self.code.addManyAsArray(4), Instruction.movk(reg, @intCast(u16, x >> 16), 16).toU32());
                        } else if (x <= math.maxInt(u32)) {
                            mem.writeIntLittle(u32, try self.code.addManyAsArray(4), Instruction.movz(reg, @truncate(u16, x), 0).toU32());
                            mem.writeIntLittle(u32, try self.code.addManyAsArray(4), Instruction.movk(reg, @truncate(u16, x >> 16), 16).toU32());
                            mem.writeIntLittle(u32, try self.code.addManyAsArray(4), Instruction.movk(reg, @intCast(u16, x >> 32), 32).toU32());
                        } else {
                            mem.writeIntLittle(u32, try self.code.addManyAsArray(4), Instruction.movz(reg, @truncate(u16, x), 0).toU32());
                            mem.writeIntLittle(u32, try self.code.addManyAsArray(4), Instruction.movk(reg, @truncate(u16, x >> 16), 16).toU32());
                            mem.writeIntLittle(u32, try self.code.addManyAsArray(4), Instruction.movk(reg, @truncate(u16, x >> 32), 32).toU32());
                            mem.writeIntLittle(u32, try self.code.addManyAsArray(4), Instruction.movk(reg, @intCast(u16, x >> 48), 48).toU32());
                        }
                    },
                    .register => return self.fail(src, "TODO implement genSetReg for aarch64 {}", .{mcv}),
                    .memory => |addr| {
                        if (self.bin_file.options.pie) {
                            // For MachO, the binary, with the exception of object files, has to be a PIE.
                            // Therefore we cannot load an absolute address.
                            // Instead, we need to make use of PC-relative addressing.
                            // TODO This needs to be optimised in the stack usage (perhaps use a shadow stack
                            // like described here:
                            // https://community.arm.com/developer/ip-products/processors/b/processors-ip-blog/posts/using-the-stack-in-aarch64-implementing-push-and-pop)
                            // TODO As far as branching is concerned, instead of saving the return address
                            // in a register, I'm thinking here of immitating x86_64, and having the address
                            // passed on the stack.
                            if (reg.id() == 0) { // x0 is special-cased
                                // str x28, [sp, #-16]
                                mem.writeIntLittle(u32, try self.code.addManyAsArray(4), Instruction.str(.x28, Register.sp, .{
                                    .offset = Instruction.Offset.imm_pre_index(-16),
                                }).toU32());
                                // adr x28, #8
                                mem.writeIntLittle(u32, try self.code.addManyAsArray(4), Instruction.adr(.x28, 8).toU32());
                                if (self.bin_file.cast(link.File.MachO)) |macho_file| {
                                    try macho_file.pie_fixups.append(self.bin_file.allocator, .{
                                        .address = addr,
                                        .start = self.code.items.len,
                                        .len = 4,
                                    });
                                } else {
                                    return self.fail(src, "TODO implement genSetReg for PIE on this platform", .{});
                                }
                                // b [label]
                                mem.writeIntLittle(u32, try self.code.addManyAsArray(4), Instruction.b(0).toU32());
                                // mov r, x0
                                mem.writeIntLittle(u32, try self.code.addManyAsArray(4), Instruction.orr(reg, .x0, Instruction.RegisterShift.none()).toU32());
                                // ldr x28, [sp], #16
                                mem.writeIntLittle(u32, try self.code.addManyAsArray(4), Instruction.ldr(.x28, .{
                                    .rn = Register.sp,
                                    .offset = Instruction.Offset.imm_post_index(16),
                                }).toU32());
                            } else {
                                // str x28, [sp, #-16]
                                mem.writeIntLittle(u32, try self.code.addManyAsArray(4), Instruction.str(.x28, Register.sp, .{
                                    .offset = Instruction.Offset.imm_pre_index(-16),
                                }).toU32());
                                // str x0, [sp, #-16]
                                mem.writeIntLittle(u32, try self.code.addManyAsArray(4), Instruction.str(.x0, Register.sp, .{
                                    .offset = Instruction.Offset.imm_pre_index(-16),
                                }).toU32());
                                // adr x28, #8
                                mem.writeIntLittle(u32, try self.code.addManyAsArray(4), Instruction.adr(.x28, 8).toU32());
                                if (self.bin_file.cast(link.File.MachO)) |macho_file| {
                                    try macho_file.pie_fixups.append(self.bin_file.allocator, .{
                                        .address = addr,
                                        .start = self.code.items.len,
                                        .len = 4,
                                    });
                                } else {
                                    return self.fail(src, "TODO implement genSetReg for PIE on this platform", .{});
                                }
                                // b [label]
                                mem.writeIntLittle(u32, try self.code.addManyAsArray(4), Instruction.b(0).toU32());
                                // mov r, x0
                                mem.writeIntLittle(u32, try self.code.addManyAsArray(4), Instruction.orr(reg, .x0, Instruction.RegisterShift.none()).toU32());
                                // ldr x0, [sp], #16
                                mem.writeIntLittle(u32, try self.code.addManyAsArray(4), Instruction.ldr(.x0, .{
                                    .rn = Register.sp,
                                    .offset = Instruction.Offset.imm_post_index(16),
                                }).toU32());
                                // ldr x28, [sp], #16
                                mem.writeIntLittle(u32, try self.code.addManyAsArray(4), Instruction.ldr(.x28, .{
                                    .rn = Register.sp,
                                    .offset = Instruction.Offset.imm_post_index(16),
                                }).toU32());
                            }
                        } else {
                            // The value is in memory at a hard-coded address.
                            // If the type is a pointer, it means the pointer address is at this memory location.
                            try self.genSetReg(src, reg, .{ .immediate = addr });
                            mem.writeIntLittle(u32, try self.code.addManyAsArray(4), Instruction.ldr(reg, .{ .rn = reg }).toU32());
                        }
                    },
                    else => return self.fail(src, "TODO implement genSetReg for aarch64 {}", .{mcv}),
                },
                .riscv64 => switch (mcv) {
                    .dead => unreachable,
                    .ptr_stack_offset => unreachable,
                    .ptr_embedded_in_code => unreachable,
                    .unreach, .none => return, // Nothing to do.
                    .undef => {
                        if (!self.wantSafety())
                            return; // The already existing value will do just fine.
                        // Write the debug undefined value.
                        return self.genSetReg(src, reg, .{ .immediate = 0xaaaaaaaaaaaaaaaa });
                    },
                    .immediate => |unsigned_x| {
                        const x = @bitCast(i64, unsigned_x);
                        if (math.minInt(i12) <= x and x <= math.maxInt(i12)) {
                            mem.writeIntLittle(u32, try self.code.addManyAsArray(4), Instruction.addi(reg, .zero, @truncate(i12, x)).toU32());
                            return;
                        }
                        if (math.minInt(i32) <= x and x <= math.maxInt(i32)) {
                            const lo12 = @truncate(i12, x);
                            const carry: i32 = if (lo12 < 0) 1 else 0;
                            const hi20 = @truncate(i20, (x >> 12) +% carry);

                            // TODO: add test case for 32-bit immediate
                            mem.writeIntLittle(u32, try self.code.addManyAsArray(4), Instruction.lui(reg, hi20).toU32());
                            mem.writeIntLittle(u32, try self.code.addManyAsArray(4), Instruction.addi(reg, reg, lo12).toU32());
                            return;
                        }
                        // li rd, immediate
                        // "Myriad sequences"
                        return self.fail(src, "TODO genSetReg 33-64 bit immediates for riscv64", .{}); // glhf
                    },
                    .memory => |addr| {
                        // The value is in memory at a hard-coded address.
                        // If the type is a pointer, it means the pointer address is at this memory location.
                        try self.genSetReg(src, reg, .{ .immediate = addr });

                        mem.writeIntLittle(u32, try self.code.addManyAsArray(4), Instruction.ld(reg, 0, reg).toU32());
                        // LOAD imm=[i12 offset = 0], rs1 =

                        // return self.fail("TODO implement genSetReg memory for riscv64");
                    },
                    else => return self.fail(src, "TODO implement getSetReg for riscv64 {}", .{mcv}),
                },
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
                        if (self.bin_file.options.pie) {
                            // For MachO, the binary, with the exception of object files, has to be a PIE.
                            // Therefore, we cannot load an absolute address.
                            assert(x > math.maxInt(u32)); // 32bit direct addressing is not supported by MachO.
                            // The plan here is to use unconditional relative jump to GOT entry, where we store
                            // pre-calculated and stored effective address to load into the target register.
                            // We leave the actual displacement information empty (0-padded) and fixing it up
                            // later in the linker.
                            if (reg.id() == 0) { // %rax is special-cased
                                try self.code.ensureCapacity(self.code.items.len + 5);
                                if (self.bin_file.cast(link.File.MachO)) |macho_file| {
                                    try macho_file.pie_fixups.append(self.bin_file.allocator, .{
                                        .address = x,
                                        .start = self.code.items.len,
                                        .len = 5,
                                    });
                                } else {
                                    return self.fail(src, "TODO implement genSetReg for PIE on this platform", .{});
                                }
                                // call [label]
                                self.code.appendSliceAssumeCapacity(&[_]u8{
                                    0xE8,
                                    0x0,
                                    0x0,
                                    0x0,
                                    0x0,
                                });
                            } else {
                                try self.code.ensureCapacity(self.code.items.len + 10);
                                // push %rax
                                self.code.appendSliceAssumeCapacity(&[_]u8{0x50});
                                if (self.bin_file.cast(link.File.MachO)) |macho_file| {
                                    try macho_file.pie_fixups.append(self.bin_file.allocator, .{
                                        .address = x,
                                        .start = self.code.items.len,
                                        .len = 5,
                                    });
                                } else {
                                    return self.fail(src, "TODO implement genSetReg for PIE on this platform", .{});
                                }
                                // call [label]
                                self.code.appendSliceAssumeCapacity(&[_]u8{
                                    0xE8,
                                    0x0,
                                    0x0,
                                    0x0,
                                    0x0,
                                });
                                // mov %r, %rax
                                self.code.appendSliceAssumeCapacity(&[_]u8{
                                    0x48,
                                    0x89,
                                    0xC0 | @as(u8, reg.id()),
                                });
                                // pop %rax
                                self.code.appendSliceAssumeCapacity(&[_]u8{0x58});
                            }
                        } else if (x <= math.maxInt(u32)) {
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
            // If the type has no codegen bits, no need to store it.
            if (!inst.ty.hasCodeGenBits())
                return MCValue.none;

            // Constants have static lifetimes, so they are always memoized in the outer most table.
            if (inst.castTag(.constant)) |const_inst| {
                const branch = &self.branch_stack.items[0];
                const gop = try branch.inst_table.getOrPut(self.gpa, inst);
                if (!gop.found_existing) {
                    gop.entry.value = try self.genTypedValue(inst.src, .{ .ty = inst.ty, .val = const_inst.val });
                }
                return gop.entry.value;
            }

            return self.getResolvedInstValue(inst);
        }

        fn getResolvedInstValue(self: *Self, inst: *ir.Inst) MCValue {
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
                    const U = std.meta.Int(.unsigned, ti.bits - @boolToInt(ti.signedness == .signed));
                    if (imm >= math.maxInt(U)) {
                        return MCValue{ .register = try self.copyToTmpRegister(inst.src, mcv) };
                    }
                },
                else => {},
            }
            return mcv;
        }

        fn genTypedValue(self: *Self, src: usize, typed_value: TypedValue) InnerError!MCValue {
            if (typed_value.val.isUndef())
                return MCValue{ .undef = {} };
            const ptr_bits = self.target.cpu.arch.ptrBitWidth();
            const ptr_bytes: u64 = @divExact(ptr_bits, 8);
            switch (typed_value.ty.zigTypeTag()) {
                .Pointer => {
                    if (typed_value.val.cast(Value.Payload.DeclRef)) |payload| {
                        if (self.bin_file.cast(link.File.Elf)) |elf_file| {
                            const decl = payload.decl;
                            const got = &elf_file.program_headers.items[elf_file.phdr_got_index.?];
                            const got_addr = got.p_vaddr + decl.link.elf.offset_table_index * ptr_bytes;
                            return MCValue{ .memory = got_addr };
                        } else if (self.bin_file.cast(link.File.MachO)) |macho_file| {
                            const decl = payload.decl;
                            const got = &macho_file.sections.items[macho_file.got_section_index.?];
                            const got_addr = got.addr + decl.link.macho.offset_table_index * ptr_bytes;
                            return MCValue{ .memory = got_addr };
                        } else if (self.bin_file.cast(link.File.Coff)) |coff_file| {
                            const decl = payload.decl;
                            const got_addr = coff_file.offset_table_virtual_address + decl.link.coff.offset_table_index * ptr_bytes;
                            return MCValue{ .memory = got_addr };
                        } else {
                            return self.fail(src, "TODO codegen non-ELF const Decl pointer", .{});
                        }
                    }
                    return self.fail(src, "TODO codegen more kinds of const pointers", .{});
                },
                .Int => {
                    const info = typed_value.ty.intInfo(self.target.*);
                    if (info.bits > ptr_bits or info.signedness == .signed) {
                        return self.fail(src, "TODO const int bigger than ptr and signed int", .{});
                    }
                    return MCValue{ .immediate = typed_value.val.toUnsignedInt() };
                },
                .Bool => {
                    return MCValue{ .immediate = @boolToInt(typed_value.val.toBool()) };
                },
                .ComptimeInt => unreachable, // semantic analysis prevents this
                .ComptimeFloat => unreachable, // semantic analysis prevents this
                .Optional => {
                    if (typed_value.ty.isPtrLikeOptional()) {
                        if (typed_value.val.isNull())
                            return MCValue{ .immediate = 0 };

                        var buf: Type.Payload.PointerSimple = undefined;
                        return self.genTypedValue(src, .{
                            .ty = typed_value.ty.optionalChild(&buf),
                            .val = typed_value.val,
                        });
                    } else if (typed_value.ty.abiSize(self.target.*) == 1) {
                        return MCValue{ .immediate = @boolToInt(typed_value.val.isNull()) };
                    }
                    return self.fail(src, "TODO non pointer optionals", .{});
                },
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
                        else => return self.fail(src, "TODO implement function parameters for {} on x86_64", .{cc}),
                    }
                },
                .arm, .armeb => {
                    switch (cc) {
                        .Naked => {
                            assert(result.args.len == 0);
                            result.return_value = .{ .unreach = {} };
                            result.stack_byte_count = 0;
                            result.stack_align = 1;
                            return result;
                        },
                        .Unspecified, .C => {
                            // ARM Procedure Call Standard, Chapter 6.5
                            var ncrn: usize = 0; // Next Core Register Number
                            var nsaa: u32 = 0; // Next stacked argument address

                            for (param_types) |ty, i| {
                                if (ty.abiAlignment(self.target.*) == 8) {
                                    // Round up NCRN to the next even number
                                    ncrn += ncrn % 2;
                                }

                                const param_size = @intCast(u32, ty.abiSize(self.target.*));
                                if (std.math.divCeil(u32, param_size, 4) catch unreachable <= 4 - ncrn) {
                                    if (param_size <= 4) {
                                        result.args[i] = .{ .register = c_abi_int_param_regs[ncrn] };
                                        ncrn += 1;
                                    } else {
                                        return self.fail(src, "TODO MCValues with multiple registers", .{});
                                    }
                                } else if (ncrn < 4 and nsaa == 0) {
                                    return self.fail(src, "TODO MCValues split between registers and stack", .{});
                                } else {
                                    ncrn = 4;
                                    if (ty.abiAlignment(self.target.*) == 8) {
                                        if (nsaa % 8 != 0) {
                                            nsaa += 8 - (nsaa % 8);
                                        }
                                    }

                                    result.args[i] = .{ .stack_offset = nsaa };
                                    nsaa += param_size;
                                }
                            }

                            result.stack_byte_count = nsaa;
                            result.stack_align = 4;
                        },
                        else => return self.fail(src, "TODO implement function parameters for {} on arm", .{cc}),
                    }
                },
                else => if (param_types.len != 0)
                    return self.fail(src, "TODO implement codegen parameters for {}", .{self.target.cpu.arch}),
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
                .arm, .armeb => switch (cc) {
                    .Naked => unreachable,
                    .Unspecified, .C => {
                        const ret_ty_size = @intCast(u32, ret_ty.abiSize(self.target.*));
                        if (ret_ty_size <= 4) {
                            result.return_value = .{ .register = c_abi_int_return_regs[0] };
                        } else {
                            return self.fail(src, "TODO support more return types for ARM backend", .{});
                        }
                    },
                    else => return self.fail(src, "TODO implement function return values for {}", .{cc}),
                },
                else => return self.fail(src, "TODO implement codegen return values for {}", .{self.target.cpu.arch}),
            }
            return result;
        }

        /// TODO support scope overrides. Also note this logic is duplicated with `Module.wantSafety`.
        fn wantSafety(self: *Self) bool {
            return switch (self.bin_file.options.optimize_mode) {
                .Debug => true,
                .ReleaseSafe => true,
                .ReleaseFast => false,
                .ReleaseSmall => false,
            };
        }

        fn fail(self: *Self, src: usize, comptime format: []const u8, args: anytype) InnerError {
            @setCold(true);
            assert(self.err_msg == null);
            self.err_msg = try ErrorMsg.create(self.bin_file.allocator, src, format, args);
            return error.CodegenFail;
        }

        usingnamespace switch (arch) {
            .i386 => @import("codegen/x86.zig"),
            .x86_64 => @import("codegen/x86_64.zig"),
            .riscv64 => @import("codegen/riscv64.zig"),
            .spu_2 => @import("codegen/spu-mk2.zig"),
            .arm, .armeb => @import("codegen/arm.zig"),
            .aarch64, .aarch64_be, .aarch64_32 => @import("codegen/aarch64.zig"),
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
        const FreeRegInt = std.meta.Int(.unsigned, callee_preserved_regs.len);

        fn parseRegName(name: []const u8) ?Register {
            if (@hasDecl(Register, "parseRegName")) {
                return Register.parseRegName(name);
            }
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

        /// For most architectures this does nothing. For x86_64 it resolves any aliased registers
        /// to the 64-bit wide ones.
        fn toCanonicalReg(reg: Register) Register {
            return switch (arch) {
                .x86_64 => reg.to64(),
                else => reg,
            };
        }
    };
}
