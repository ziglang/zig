//! Cross-platform abstraction for this binary's own debug information, with a
//! goal of minimal code bloat and compilation speed penalty.

const builtin = @import("builtin");
const native_endian = native_arch.endian();
const native_arch = builtin.cpu.arch;

const std = @import("../std.zig");
const mem = std.mem;
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const Dwarf = std.debug.Dwarf;
const CpuContext = std.debug.cpu_context.Native;

const stripInstructionPtrAuthCode = std.debug.stripInstructionPtrAuthCode;

const root = @import("root");

const SelfInfo = @This();

/// Locks access to `modules`. However, does *not* lock the `Module.DebugInfo`, nor `lookup_cache`
/// the implementation is responsible for locking as needed in its exposed methods.
///
/// TODO: to allow `SelfInfo` to work on freestanding, we currently just don't use this mutex there.
/// That's a bad solution, but a better one depends on the standard library's general support for
/// "bring your own OS" being improved.
modules_mutex: switch (builtin.os.tag) {
    else => std.Thread.Mutex,
    .freestanding, .other => struct {
        fn lock(_: @This()) void {}
        fn unlock(_: @This()) void {}
    },
},
/// Value is allocated into gpa to give it a stable pointer.
modules: if (target_supported) std.AutoArrayHashMapUnmanaged(usize, *Module.DebugInfo) else void,
lookup_cache: if (target_supported) Module.LookupCache else void,

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
pub const supports_unwinding: bool = target_supported and Module.supports_unwinding;

pub const UnwindContext = if (supports_unwinding) Module.UnwindContext;

pub const init: SelfInfo = .{
    .modules_mutex = .{},
    .modules = .empty,
    .lookup_cache = if (Module.LookupCache != void) .init,
};

pub fn deinit(self: *SelfInfo, gpa: Allocator) void {
    for (self.modules.values()) |di| {
        di.deinit(gpa);
        gpa.destroy(di);
    }
    self.modules.deinit(gpa);
    if (Module.LookupCache != void) self.lookup_cache.deinit(gpa);
}

pub fn unwindFrame(self: *SelfInfo, gpa: Allocator, context: *UnwindContext) Error!usize {
    comptime assert(supports_unwinding);
    const module: Module = try .lookup(&self.lookup_cache, gpa, context.pc);
    const di: *Module.DebugInfo = di: {
        self.modules_mutex.lock();
        defer self.modules_mutex.unlock();
        const gop = try self.modules.getOrPut(gpa, module.key());
        if (gop.found_existing) break :di gop.value_ptr.*;
        errdefer _ = self.modules.pop().?;
        const di = try gpa.create(Module.DebugInfo);
        di.* = .init;
        gop.value_ptr.* = di;
        break :di di;
    };
    return module.unwindFrame(gpa, di, context);
}

pub fn getSymbolAtAddress(self: *SelfInfo, gpa: Allocator, address: usize) Error!std.debug.Symbol {
    comptime assert(target_supported);
    const module: Module = try .lookup(&self.lookup_cache, gpa, address);
    const di: *Module.DebugInfo = di: {
        self.modules_mutex.lock();
        defer self.modules_mutex.unlock();
        const gop = try self.modules.getOrPut(gpa, module.key());
        if (gop.found_existing) break :di gop.value_ptr.*;
        errdefer _ = self.modules.pop().?;
        const di = try gpa.create(Module.DebugInfo);
        di.* = .init;
        gop.value_ptr.* = di;
        break :di di;
    };
    return module.getSymbolAtAddress(gpa, di, address);
}

pub fn getModuleNameForAddress(self: *SelfInfo, gpa: Allocator, address: usize) Error![]const u8 {
    comptime assert(target_supported);
    const module: Module = try .lookup(&self.lookup_cache, gpa, address);
    if (module.name.len == 0) return error.MissingDebugInfo;
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
/// Because different threads can collect stack traces concurrently, the implementation must be able
/// to tolerate concurrent calls to any method it implements.
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
/// /// Only required if `supports_unwinding == true`.
/// pub const UnwindContext = struct {
///     /// A PC value representing the location in the last frame.
///     pc: usize,
///     pub fn init(ctx: *std.debug.cpu_context.Native, gpa: Allocator) Allocator.Error!UnwindContext;
///     pub fn deinit(uc: *UnwindContext, gpa: Allocator) void;
///     /// Returns the frame pointer associated with the last unwound stack frame. If the frame
///     /// pointer is unknown, 0 may be returned instead.
///     pub fn getFp(uc: *UnwindContext) usize;
/// };
/// /// Only required if `supports_unwinding == true`. Unwinds a single stack frame, and returns
/// /// the frame's return address.
/// pub fn unwindFrame(
///     mod: *const Module,
///     gpa: Allocator,
///     di: *DebugInfo,
///     ctx: *UnwindContext,
/// ) SelfInfo.Error!usize;
/// ```
const Module: type = Module: {
    // Allow overriding the target-specific `SelfInfo` implementation by exposing `root.debug.Module`.
    if (@hasDecl(root, "debug") and @hasDecl(root.debug, "Module")) {
        break :Module root.debug.Module;
    }
    break :Module switch (builtin.os.tag) {
        .linux,
        .netbsd,
        .freebsd,
        .dragonfly,
        .openbsd,
        .solaris,
        .illumos,
        => @import("SelfInfo/ElfModule.zig"),

        .macos,
        .ios,
        .watchos,
        .tvos,
        .visionos,
        => @import("SelfInfo/DarwinModule.zig"),

        .uefi,
        .windows,
        => @import("SelfInfo/WindowsModule.zig"),

        else => void,
    };
};

/// An implementation of `UnwindContext` useful for DWARF-based unwinders. The `Module.unwindFrame`
/// implementation should wrap `DwarfUnwindContext.unwindFrame`.
pub const DwarfUnwindContext = struct {
    cfa: ?usize,
    pc: usize,
    cpu_context: CpuContext,
    vm: Dwarf.Unwind.VirtualMachine,
    stack_machine: Dwarf.expression.StackMachine(.{ .call_frame_context = true }),

    pub const Cache = struct {
        /// TODO: to allow `DwarfUnwindContext` to work on freestanding, we currently just don't use
        /// this mutex there. That's a bad solution, but a better one depends on the standard
        /// library's general support for "bring your own OS" being improved.
        mutex: switch (builtin.os.tag) {
            else => std.Thread.Mutex,
            .freestanding, .other => struct {
                fn lock(_: @This()) void {}
                fn unlock(_: @This()) void {}
            },
        },
        buf: [num_slots]Slot,
        const num_slots = 2048;
        const Slot = struct {
            const max_regs = 32;
            pc: usize,
            cie: *const Dwarf.Unwind.CommonInformationEntry,
            cfa_rule: Dwarf.Unwind.VirtualMachine.CfaRule,
            rules_regs: [max_regs]u16,
            rules: [max_regs]Dwarf.Unwind.VirtualMachine.RegisterRule,
            num_rules: u8,
        };
        /// This is a function rather than a declaration to avoid lowering a very large struct value
        /// into the binary when most of it is `undefined`.
        pub fn init(c: *Cache) void {
            c.mutex = .{};
            for (&c.buf) |*slot| slot.pc = 0;
        }
    };

    pub fn init(cpu_context: *const CpuContext) DwarfUnwindContext {
        comptime assert(supports_unwinding);

        // `@constCast` is safe because we aren't going to store to the resulting pointer.
        const raw_pc_ptr = regNative(@constCast(cpu_context), ip_reg_num) catch |err| switch (err) {
            error.InvalidRegister => unreachable, // `ip_reg_num` is definitely valid
            error.UnsupportedRegister => unreachable, // the implementation needs to support ip
            error.IncompatibleRegisterSize => unreachable, // ip is definitely `usize`-sized
        };
        const pc = stripInstructionPtrAuthCode(raw_pc_ptr.*);

        return .{
            .cfa = null,
            .pc = pc,
            .cpu_context = cpu_context.*,
            .vm = .{},
            .stack_machine = .{},
        };
    }

    pub fn deinit(self: *DwarfUnwindContext, gpa: Allocator) void {
        self.vm.deinit(gpa);
        self.stack_machine.deinit(gpa);
        self.* = undefined;
    }

    pub fn getFp(self: *const DwarfUnwindContext) usize {
        // `@constCast` is safe because we aren't going to store to the resulting pointer.
        const ptr = regNative(@constCast(&self.cpu_context), fp_reg_num) catch |err| switch (err) {
            error.InvalidRegister => unreachable, // `fp_reg_num` is definitely valid
            error.UnsupportedRegister => unreachable, // the implementation needs to support fp
            error.IncompatibleRegisterSize => unreachable, // fp is a pointer so is `usize`-sized
        };
        return ptr.*;
    }

    /// Unwind a stack frame using DWARF unwinding info, updating the register context.
    ///
    /// If `.eh_frame_hdr` is available and complete, it will be used to binary search for the FDE.
    /// Otherwise, a linear scan of `.eh_frame` and `.debug_frame` is done to find the FDE. The latter
    /// may require lazily loading the data in those sections.
    ///
    /// `explicit_fde_offset` is for cases where the FDE offset is known, such as when using macOS'
    /// `__unwind_info` section.
    pub fn unwindFrame(
        context: *DwarfUnwindContext,
        cache: *Cache,
        gpa: Allocator,
        unwind: *const Dwarf.Unwind,
        load_offset: usize,
        explicit_fde_offset: ?usize,
    ) Error!usize {
        return unwindFrameInner(context, cache, gpa, unwind, load_offset, explicit_fde_offset) catch |err| switch (err) {
            error.InvalidDebugInfo,
            error.MissingDebugInfo,
            error.UnsupportedDebugInfo,
            error.OutOfMemory,
            => |e| return e,

            error.UnsupportedAddrSize,
            error.UnimplementedUserOpcode,
            error.UnimplementedExpressionCall,
            error.UnimplementedOpcode,
            error.UnimplementedTypedComparison,
            error.UnimplementedTypeConversion,
            error.UnknownExpressionOpcode,
            error.UnsupportedRegister,
            => return error.UnsupportedDebugInfo,

            error.InvalidRegister,
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
            => return error.InvalidDebugInfo,
        };
    }
    fn unwindFrameInner(
        context: *DwarfUnwindContext,
        cache: *Cache,
        gpa: Allocator,
        unwind: *const Dwarf.Unwind,
        load_offset: usize,
        explicit_fde_offset: ?usize,
    ) !usize {
        comptime assert(supports_unwinding);

        if (context.pc == 0) return 0;

        const pc_vaddr = context.pc - load_offset;

        const cache_slot: Cache.Slot = slot: {
            const slot_idx = std.hash.int(pc_vaddr) % Cache.num_slots;

            {
                cache.mutex.lock();
                defer cache.mutex.unlock();
                if (cache.buf[slot_idx].pc == pc_vaddr) break :slot cache.buf[slot_idx];
            }

            const fde_offset = explicit_fde_offset orelse try unwind.lookupPc(
                pc_vaddr,
                @sizeOf(usize),
                native_endian,
            ) orelse return error.MissingDebugInfo;
            const cie, const fde = try unwind.getFde(fde_offset, native_endian);

            // Check if the FDE *actually* includes the pc (`lookupPc` can return false positives).
            if (pc_vaddr < fde.pc_begin or pc_vaddr >= fde.pc_begin + fde.pc_range) {
                return error.MissingDebugInfo;
            }

            context.vm.reset();

            const row = try context.vm.runTo(gpa, pc_vaddr, cie, &fde, @sizeOf(usize), native_endian);

            if (row.columns.len > Cache.Slot.max_regs) return error.UnsupportedDebugInfo;

            var slot: Cache.Slot = .{
                .pc = pc_vaddr,
                .cie = cie,
                .cfa_rule = row.cfa,
                .rules_regs = undefined,
                .rules = undefined,
                .num_rules = 0,
            };
            for (context.vm.rowColumns(&row)) |col| {
                const i = slot.num_rules;
                slot.rules_regs[i] = col.register;
                slot.rules[i] = col.rule;
                slot.num_rules += 1;
            }

            {
                cache.mutex.lock();
                defer cache.mutex.unlock();
                cache.buf[slot_idx] = slot;
            }

            break :slot slot;
        };

        const format = cache_slot.cie.format;
        const return_address_register = cache_slot.cie.return_address_register;

        context.cfa = switch (cache_slot.cfa_rule) {
            .none => return error.InvalidCFARule,
            .reg_off => |ro| cfa: {
                const ptr = try regNative(&context.cpu_context, ro.register);
                break :cfa try applyOffset(ptr.*, ro.offset);
            },
            .expression => |expr| cfa: {
                context.stack_machine.reset();
                const value = try context.stack_machine.run(expr, gpa, .{
                    .format = format,
                    .cpu_context = &context.cpu_context,
                }, context.cfa) orelse return error.NoExpressionValue;
                switch (value) {
                    .generic => |g| break :cfa g,
                    else => return error.InvalidExpressionValue,
                }
            },
        };

        // If unspecified, we'll use the default rule for the return address register, which is
        // typically equivalent to `.undefined` (meaning there is no return address), but may be
        // overriden by ABIs.
        var has_return_address: bool = builtin.cpu.arch.isAARCH64() and
            return_address_register >= 19 and
            return_address_register <= 28;

        // Create a copy of the CPU context, to which we will apply the new rules.
        var new_cpu_context = context.cpu_context;

        // On all implemented architectures, the CFA is defined as being the previous frame's SP
        (try regNative(&new_cpu_context, sp_reg_num)).* = context.cfa.?;

        const rules_len = cache_slot.num_rules;
        for (cache_slot.rules_regs[0..rules_len], cache_slot.rules[0..rules_len]) |register, rule| {
            const new_val: union(enum) {
                same,
                undefined,
                val: usize,
                bytes: []const u8,
            } = switch (rule) {
                .default => val: {
                    // The default rule is typically equivalent to `.undefined`, but ABIs may override it.
                    if (builtin.cpu.arch.isAARCH64() and register >= 19 and register <= 28) {
                        break :val .same;
                    }
                    break :val .undefined;
                },
                .undefined => .undefined,
                .same_value => .same,
                .offset => |offset| val: {
                    const ptr: *const usize = @ptrFromInt(try applyOffset(context.cfa.?, offset));
                    break :val .{ .val = ptr.* };
                },
                .val_offset => |offset| .{ .val = try applyOffset(context.cfa.?, offset) },
                .register => |r| .{ .bytes = try context.cpu_context.dwarfRegisterBytes(r) },
                .expression => |expr| val: {
                    context.stack_machine.reset();
                    const value = try context.stack_machine.run(expr, gpa, .{
                        .format = format,
                        .cpu_context = &context.cpu_context,
                    }, context.cfa.?) orelse return error.NoExpressionValue;
                    const ptr: *const usize = switch (value) {
                        .generic => |addr| @ptrFromInt(addr),
                        else => return error.InvalidExpressionValue,
                    };
                    break :val .{ .val = ptr.* };
                },
                .val_expression => |expr| val: {
                    context.stack_machine.reset();
                    const value = try context.stack_machine.run(expr, gpa, .{
                        .format = format,
                        .cpu_context = &context.cpu_context,
                    }, context.cfa.?) orelse return error.NoExpressionValue;
                    switch (value) {
                        .generic => |val| break :val .{ .val = val },
                        else => return error.InvalidExpressionValue,
                    }
                },
            };
            switch (new_val) {
                .same => {},
                .undefined => {
                    const dest = try new_cpu_context.dwarfRegisterBytes(@intCast(register));
                    @memset(dest, undefined);
                },
                .val => |val| {
                    const dest = try new_cpu_context.dwarfRegisterBytes(@intCast(register));
                    if (dest.len != @sizeOf(usize)) return error.RegisterSizeMismatch;
                    const dest_ptr: *align(1) usize = @ptrCast(dest);
                    dest_ptr.* = val;
                },
                .bytes => |src| {
                    const dest = try new_cpu_context.dwarfRegisterBytes(@intCast(register));
                    if (dest.len != src.len) return error.RegisterSizeMismatch;
                    @memcpy(dest, src);
                },
            }
            if (register == return_address_register) {
                has_return_address = new_val != .undefined;
            }
        }

        const return_address: usize = if (has_return_address) pc: {
            const raw_ptr = try regNative(&new_cpu_context, return_address_register);
            break :pc stripInstructionPtrAuthCode(raw_ptr.*);
        } else 0;

        (try regNative(&new_cpu_context, ip_reg_num)).* = return_address;

        // The new CPU context is complete; flush changes.
        context.cpu_context = new_cpu_context;

        // The caller will subtract 1 from the return address to get an address corresponding to the
        // function call. However, if this is a signal frame, that's actually incorrect, because the
        // "return address" we have is the instruction which triggered the signal (if the signal
        // handler returned, the instruction would be re-run). Compensate for this by incrementing
        // the address in that case.
        const adjusted_ret_addr = if (cache_slot.cie.is_signal_frame) return_address +| 1 else return_address;

        // We also want to do that same subtraction here to get the PC for the next frame's FDE.
        // This is because if the callee was noreturn, then the function call might be the caller's
        // last instruction, so `return_address` might actually point outside of it!
        context.pc = adjusted_ret_addr -| 1;

        return adjusted_ret_addr;
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

    pub fn regNative(ctx: *CpuContext, num: u16) error{
        InvalidRegister,
        UnsupportedRegister,
        IncompatibleRegisterSize,
    }!*align(1) usize {
        const bytes = try ctx.dwarfRegisterBytes(num);
        if (bytes.len != @sizeOf(usize)) return error.IncompatibleRegisterSize;
        return @ptrCast(bytes);
    }

    const ip_reg_num = Dwarf.ipRegNum(native_arch).?;
    const fp_reg_num = Dwarf.fpRegNum(native_arch);
    const sp_reg_num = Dwarf.spRegNum(native_arch);
};
