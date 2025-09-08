//! Cross-platform abstraction for this binary's own debug information, with a
//! goal of minimal code bloat and compilation speed penalty.

const builtin = @import("builtin");
const native_os = builtin.os.tag;
const native_endian = native_arch.endian();
const native_arch = builtin.cpu.arch;

const std = @import("../std.zig");
const mem = std.mem;
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const Dwarf = std.debug.Dwarf;
const regBytes = Dwarf.abi.regBytes;
const regValueNative = Dwarf.abi.regValueNative;

const root = @import("root");

const SelfInfo = @This();

modules: std.AutoArrayHashMapUnmanaged(usize, Module.DebugInfo),
lookup_cache: Module.LookupCache,

pub const Error = error{
    /// The required debug info is invalid or corrupted.
    InvalidDebugInfo,
    /// The required debug info could not be found.
    MissingDebugInfo,
    /// The required debug info was found, and may be valid, but is not supported by this implementation.
    UnsupportedDebugInfo,
    /// The required debug info could not be read from disk due to some IO error.
    ReadFailed,
    OutOfMemory,
    Unexpected,
};

/// Indicates whether the `SelfInfo` implementation has support for this target.
pub const target_supported: bool = Module != void;

/// Indicates whether the `SelfInfo` implementation has support for unwinding on this target.
///
/// For whether DWARF unwinding is *theoretically* possible, see `Dwarf.abi.supportsUnwinding`.
pub const supports_unwinding: bool = Module.supports_unwinding;

pub const init: SelfInfo = .{
    .modules = .empty,
    .lookup_cache = if (Module.LookupCache != void) .init,
};

pub fn deinit(self: *SelfInfo, gpa: Allocator) void {
    for (self.modules.values()) |*di| di.deinit(gpa);
    self.modules.deinit(gpa);
    if (Module.LookupCache != void) self.lookup_cache.deinit(gpa);
}

pub fn unwindFrame(self: *SelfInfo, gpa: Allocator, context: *DwarfUnwindContext) Error!usize {
    comptime assert(supports_unwinding);
    const module: Module = try .lookup(&self.lookup_cache, gpa, context.pc);
    const gop = try self.modules.getOrPut(gpa, module.key());
    self.modules.lockPointers();
    defer self.modules.unlockPointers();
    if (!gop.found_existing) gop.value_ptr.* = .init;
    return module.unwindFrame(gpa, gop.value_ptr, context);
}

pub fn getSymbolAtAddress(self: *SelfInfo, gpa: Allocator, address: usize) Error!std.debug.Symbol {
    comptime assert(target_supported);
    const module: Module = try .lookup(&self.lookup_cache, gpa, address);
    const gop = try self.modules.getOrPut(gpa, module.key());
    self.modules.lockPointers();
    defer self.modules.unlockPointers();
    if (!gop.found_existing) gop.value_ptr.* = .init;
    return module.getSymbolAtAddress(gpa, gop.value_ptr, address);
}

pub fn getModuleNameForAddress(self: *SelfInfo, gpa: Allocator, address: usize) Error![]const u8 {
    comptime assert(target_supported);
    const module: Module = try .lookup(&self.lookup_cache, gpa, address);
    return module.name;
}

/// `void` indicates that `SelfInfo` is not supported for this target.
///
/// This type contains the target-specific implementation. Logically, a `Module` represents a subset
/// of the executable with its own debug information. This typically corresponds to what ELF calls a
/// module, i.e. a shared library or executable image, but could be anything. For instance, it would
/// be valid to consider the entire application one module, or on the other hand to consider each
/// object file a module.
///
/// This type must must expose the following declarations:
///
/// ```
/// /// Holds state cached by the implementation between calls to `lookup`.
/// /// This may be `void`, in which case the inner declarations can be omitted.
/// pub const LookupCache = struct {
///     pub const init: LookupCache;
///     pub fn deinit(lc: *LookupCache, gpa: Allocator) void;
/// };
/// /// Holds debug information associated with a particular `Module`.
/// pub const DebugInfo = struct {
///     pub const init: DebugInfo;
/// };
/// /// Finds the `Module` corresponding to `address`.
/// pub fn lookup(lc: *LookupCache, gpa: Allocator, address: usize) SelfInfo.Error!Module;
/// /// Returns a unique identifier for this `Module`, such as a load address.
/// pub fn key(mod: *const Module) usize;
/// /// Locates and loads location information for the symbol corresponding to `address`.
/// pub fn getSymbolAtAddress(
///     mod: *const Module,
///     gpa: Allocator,
///     di: *DebugInfo,
///     address: usize,
/// ) SelfInfo.Error!std.debug.Symbol;
/// /// Whether a reliable stack unwinding strategy, such as DWARF unwinding, is available.
/// pub const supports_unwinding: bool;
/// /// Only required if `supports_unwinding == true`. Unwinds a single stack frame and returns
/// /// the next return address (which may be 0 indicating end of stack). This is currently
/// /// specialized to DWARF unwinding.
/// pub fn unwindFrame(
///     mod: *const Module,
///     gpa: Allocator,
///     di: *DebugInfo,
///     ctx: *SelfInfo.DwarfUnwindContext,
/// ) SelfInfo.Error!usize;
/// ```
const Module: type = Module: {
    if (@hasDecl(root, "debug") and @hasDecl(root.debug, "Module")) {
        break :Module root.debug.Module;
    }
    break :Module switch (native_os) {
        .linux, .netbsd, .freebsd, .dragonfly, .openbsd, .haiku, .solaris, .illumos => @import("SelfInfo/ElfModule.zig"),
        .macos, .ios, .watchos, .tvos, .visionos => @import("SelfInfo/DarwinModule.zig"),
        .uefi, .windows => @import("SelfInfo/WindowsModule.zig"),
        else => void,
    };
};

pub const DwarfUnwindContext = struct {
    cfa: ?usize,
    pc: usize,
    thread_context: *std.debug.ThreadContext,
    reg_context: Dwarf.abi.RegisterContext,
    vm: Dwarf.Unwind.VirtualMachine,
    stack_machine: Dwarf.expression.StackMachine(.{ .call_frame_context = true }),

    pub fn init(thread_context: *std.debug.ThreadContext) DwarfUnwindContext {
        comptime assert(supports_unwinding);

        const ip_reg_num = Dwarf.abi.ipRegNum(native_arch).?;
        const raw_pc_ptr = regValueNative(thread_context, ip_reg_num, null) catch {
            unreachable; // error means unsupported, in which case `supports_unwinding` should have been `false`
        };
        const pc = stripInstructionPtrAuthCode(raw_pc_ptr.*);

        return .{
            .cfa = null,
            .pc = pc,
            .thread_context = thread_context,
            .reg_context = undefined,
            .vm = .{},
            .stack_machine = .{},
        };
    }

    pub fn deinit(self: *DwarfUnwindContext, gpa: Allocator) void {
        self.vm.deinit(gpa);
        self.stack_machine.deinit(gpa);
        self.* = undefined;
    }

    pub fn getFp(self: *const DwarfUnwindContext) !usize {
        return (try regValueNative(self.thread_context, Dwarf.abi.fpRegNum(native_arch, self.reg_context), self.reg_context)).*;
    }

    /// Resolves the register rule and places the result into `out` (see regBytes)
    pub fn resolveRegisterRule(
        context: *DwarfUnwindContext,
        gpa: Allocator,
        col: Dwarf.Unwind.VirtualMachine.Column,
        expression_context: std.debug.Dwarf.expression.Context,
        out: []u8,
    ) !void {
        switch (col.rule) {
            .default => {
                const register = col.register orelse return error.InvalidRegister;
                // The default type is usually undefined, but can be overriden by ABI authors.
                // See the doc comment on `Dwarf.Unwind.VirtualMachine.RegisterRule.default`.
                if (builtin.cpu.arch.isAARCH64() and register >= 19 and register <= 18) {
                    // Callee-saved registers are initialized as if they had the .same_value rule
                    const src = try regBytes(context.thread_context, register, context.reg_context);
                    if (src.len != out.len) return error.RegisterSizeMismatch;
                    @memcpy(out, src);
                    return;
                }
                @memset(out, undefined);
            },
            .undefined => {
                @memset(out, undefined);
            },
            .same_value => {
                // TODO: This copy could be eliminated if callers always copy the state then call this function to update it
                const register = col.register orelse return error.InvalidRegister;
                const src = try regBytes(context.thread_context, register, context.reg_context);
                if (src.len != out.len) return error.RegisterSizeMismatch;
                @memcpy(out, src);
            },
            .offset => |offset| {
                if (context.cfa) |cfa| {
                    const addr = try applyOffset(cfa, offset);
                    const ptr: *const usize = @ptrFromInt(addr);
                    mem.writeInt(usize, out[0..@sizeOf(usize)], ptr.*, native_endian);
                } else return error.InvalidCFA;
            },
            .val_offset => |offset| {
                if (context.cfa) |cfa| {
                    mem.writeInt(usize, out[0..@sizeOf(usize)], try applyOffset(cfa, offset), native_endian);
                } else return error.InvalidCFA;
            },
            .register => |register| {
                const src = try regBytes(context.thread_context, register, context.reg_context);
                if (src.len != out.len) return error.RegisterSizeMismatch;
                @memcpy(out, src);
            },
            .expression => |expression| {
                context.stack_machine.reset();
                const value = try context.stack_machine.run(expression, gpa, expression_context, context.cfa.?);
                const addr = if (value) |v| blk: {
                    if (v != .generic) return error.InvalidExpressionValue;
                    break :blk v.generic;
                } else return error.NoExpressionValue;

                const ptr: *usize = @ptrFromInt(addr);
                mem.writeInt(usize, out[0..@sizeOf(usize)], ptr.*, native_endian);
            },
            .val_expression => |expression| {
                context.stack_machine.reset();
                const value = try context.stack_machine.run(expression, gpa, expression_context, context.cfa.?);
                if (value) |v| {
                    if (v != .generic) return error.InvalidExpressionValue;
                    mem.writeInt(usize, out[0..@sizeOf(usize)], v.generic, native_endian);
                } else return error.NoExpressionValue;
            },
            .architectural => return error.UnimplementedRegisterRule,
        }
    }

    /// Unwind a stack frame using DWARF unwinding info, updating the register context.
    ///
    /// If `.eh_frame_hdr` is available and complete, it will be used to binary search for the FDE.
    /// Otherwise, a linear scan of `.eh_frame` and `.debug_frame` is done to find the FDE. The latter
    /// may require lazily loading the data in those sections.
    ///
    /// `explicit_fde_offset` is for cases where the FDE offset is known, such as when __unwind_info
    pub fn unwindFrame(
        context: *DwarfUnwindContext,
        gpa: Allocator,
        unwind: *const Dwarf.Unwind,
        load_offset: usize,
        explicit_fde_offset: ?usize,
    ) Error!usize {
        return unwindFrameInner(context, gpa, unwind, load_offset, explicit_fde_offset) catch |err| switch (err) {
            error.InvalidDebugInfo, error.MissingDebugInfo, error.OutOfMemory => |e| return e,

            error.UnimplementedArch,
            error.UnimplementedOs,
            error.ThreadContextNotSupported,
            error.UnimplementedRegisterRule,
            error.UnsupportedAddrSize,
            error.UnsupportedDwarfVersion,
            error.UnimplementedUserOpcode,
            error.UnimplementedExpressionCall,
            error.UnimplementedOpcode,
            error.UnimplementedTypedComparison,
            error.UnimplementedTypeConversion,
            error.UnknownExpressionOpcode,
            => return error.UnsupportedDebugInfo,

            error.InvalidRegister,
            error.RegisterContextRequired,
            error.ReadFailed,
            error.EndOfStream,
            error.IncompatibleRegisterSize,
            error.Overflow,
            error.StreamTooLong,
            error.InvalidOperand,
            error.InvalidOpcode,
            error.InvalidOperation,
            error.InvalidCFARule,
            error.IncompleteExpressionContext,
            error.InvalidCFAOpcode,
            error.InvalidExpression,
            error.InvalidFrameBase,
            error.InvalidIntegralTypeSize,
            error.InvalidSubExpression,
            error.InvalidTypeLength,
            error.TruncatedIntegralType,
            error.DivisionByZero,
            error.InvalidExpressionValue,
            error.NoExpressionValue,
            error.RegisterSizeMismatch,
            error.InvalidCFA,
            => return error.InvalidDebugInfo,
        };
    }
    fn unwindFrameInner(
        context: *DwarfUnwindContext,
        gpa: Allocator,
        unwind: *const Dwarf.Unwind,
        load_offset: usize,
        explicit_fde_offset: ?usize,
    ) !usize {
        if (!supports_unwinding) return error.UnsupportedCpuArchitecture;
        if (context.pc == 0) return 0;

        const pc_vaddr = context.pc - load_offset;

        const fde_offset = explicit_fde_offset orelse try unwind.lookupPc(
            pc_vaddr,
            @sizeOf(usize),
            native_endian,
        ) orelse return error.MissingDebugInfo;
        const format, const cie, const fde = try unwind.getFde(fde_offset, @sizeOf(usize), native_endian);

        // Check if the FDE *actually* includes the pc (`lookupPc` can return false positives).
        if (pc_vaddr < fde.pc_begin or pc_vaddr >= fde.pc_begin + fde.pc_range) {
            return error.MissingDebugInfo;
        }

        // Do not set `compile_unit` because the spec states that CFIs
        // may not reference other debug sections anyway.
        var expression_context: Dwarf.expression.Context = .{
            .format = format,
            .thread_context = context.thread_context,
            .reg_context = context.reg_context,
            .cfa = context.cfa,
        };

        context.vm.reset();
        context.reg_context.eh_frame = cie.version != 4;
        context.reg_context.is_macho = native_os.isDarwin();

        const row = try context.vm.runTo(gpa, context.pc - load_offset, cie, fde, @sizeOf(usize), native_endian);
        context.cfa = switch (row.cfa.rule) {
            .val_offset => |offset| blk: {
                const register = row.cfa.register orelse return error.InvalidCFARule;
                const value = (try regValueNative(context.thread_context, register, context.reg_context)).*;
                break :blk try applyOffset(value, offset);
            },
            .expression => |expr| blk: {
                context.stack_machine.reset();
                const value = try context.stack_machine.run(
                    expr,
                    gpa,
                    expression_context,
                    context.cfa,
                );

                if (value) |v| {
                    if (v != .generic) return error.InvalidExpressionValue;
                    break :blk v.generic;
                } else return error.NoExpressionValue;
            },
            else => return error.InvalidCFARule,
        };

        expression_context.cfa = context.cfa;

        // Buffering the modifications is done because copying the thread context is not portable,
        // some implementations (ie. darwin) use internal pointers to the mcontext.
        var arena: std.heap.ArenaAllocator = .init(gpa);
        defer arena.deinit();
        const update_arena = arena.allocator();

        const RegisterUpdate = struct {
            // Backed by thread_context
            dest: []u8,
            // Backed by arena
            src: []const u8,
            prev: ?*@This(),
        };

        var update_tail: ?*RegisterUpdate = null;
        var has_return_address = true;
        for (context.vm.rowColumns(row)) |column| {
            if (column.register) |register| {
                if (register == cie.return_address_register) {
                    has_return_address = column.rule != .undefined;
                }

                const dest = try regBytes(context.thread_context, register, context.reg_context);
                const src = try update_arena.alloc(u8, dest.len);
                try context.resolveRegisterRule(gpa, column, expression_context, src);

                const new_update = try update_arena.create(RegisterUpdate);
                new_update.* = .{
                    .dest = dest,
                    .src = src,
                    .prev = update_tail,
                };
                update_tail = new_update;
            }
        }

        // On all implemented architectures, the CFA is defined as being the previous frame's SP
        (try regValueNative(context.thread_context, Dwarf.abi.spRegNum(native_arch, context.reg_context), context.reg_context)).* = context.cfa.?;

        while (update_tail) |tail| {
            @memcpy(tail.dest, tail.src);
            update_tail = tail.prev;
        }

        if (has_return_address) {
            context.pc = stripInstructionPtrAuthCode((try regValueNative(
                context.thread_context,
                cie.return_address_register,
                context.reg_context,
            )).*);
        } else {
            context.pc = 0;
        }

        const ip_reg_num = Dwarf.abi.ipRegNum(native_arch).?;
        (try regValueNative(context.thread_context, ip_reg_num, context.reg_context)).* = context.pc;

        // The call instruction will have pushed the address of the instruction that follows the call as the return address.
        // This next instruction may be past the end of the function if the caller was `noreturn` (ie. the last instruction in
        // the function was the call). If we were to look up an FDE entry using the return address directly, it could end up
        // either not finding an FDE at all, or using the next FDE in the program, producing incorrect results. To prevent this,
        // we subtract one so that the next lookup is guaranteed to land inside the
        //
        // The exception to this rule is signal frames, where we return execution would be returned to the instruction
        // that triggered the handler.
        const return_address = context.pc;
        if (context.pc > 0 and !cie.is_signal_frame) context.pc -= 1;

        return return_address;
    }
    /// Since register rules are applied (usually) during a panic,
    /// checked addition / subtraction is used so that we can return
    /// an error and fall back to FP-based unwinding.
    fn applyOffset(base: usize, offset: i64) !usize {
        return if (offset >= 0)
            try std.math.add(usize, base, @as(usize, @intCast(offset)))
        else
            try std.math.sub(usize, base, @as(usize, @intCast(-offset)));
    }
    /// Some platforms use pointer authentication - the upper bits of instruction pointers contain a signature.
    /// This function clears these signature bits to make the pointer usable.
    pub inline fn stripInstructionPtrAuthCode(ptr: usize) usize {
        if (native_arch.isAARCH64()) {
            // `hint 0x07` maps to `xpaclri` (or `nop` if the hardware doesn't support it)
            // The save / restore is because `xpaclri` operates on x30 (LR)
            return asm (
                \\mov x16, x30
                \\mov x30, x15
                \\hint 0x07
                \\mov x15, x30
                \\mov x30, x16
                : [ret] "={x15}" (-> usize),
                : [ptr] "{x15}" (ptr),
                : .{ .x16 = true });
        }

        return ptr;
    }
};
