//! ABI related stuff for LoongArch64.
const std = @import("std");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const Writer = std.Io.Writer;

const bits = @import("bits.zig");
const Register = bits.Register;
const RegisterManagerFn = @import("../../register_manager.zig").RegisterManager;
const Type = @import("../../Type.zig");
const Zcu = @import("../../Zcu.zig");
const Air = @import("../../Air.zig");
const InternPool = @import("../../InternPool.zig");

const log = std.log.scoped(.loongarch_abi);

pub const RegisterClass = enum {
    /// Basic integer registers
    int,
    /// FP/LSX/LASX registers
    floating,
};

pub const CallInfo = struct {
    /// Parameters.
    params: []CCValue,
    /// Return value.
    return_value: CCValue,

    /// Size of the call frame in bytes.
    frame_size: u32,
    /// Alignment of the call frame.
    frame_align: InternPool.Alignment,
    /// Register containing pointer to the error return trace struct.
    err_ret_trace_reg: ?Register,

    pub fn deinit(self: *CallInfo, allocator: Allocator) void {
        allocator.free(self.params);
        self.* = undefined;
    }
};

pub const CCValue = union(enum) {
    /// No runtime bits.
    none,
    /// A value stored in a register.
    register: Register,
    /// A value stored in two registers.
    register_pair: [2]Register,
    /// A value stored in three registers.
    register_triple: [3]Register,
    /// A value stored in four registers.
    register_quadruple: [4]Register,
    /// A value stored in the call frame with given offset.
    frame: i32,
    /// A value whose lower-ordered bits are in a register and the others are in the call frame.
    split: struct { reg: Register, frame_off: i32 },
    /// A value passed as a pointer in a register.
    /// Caller allocates memory and sets the register to the pointer.
    ref_register: Register,
    /// A value passed as a pointer in the call frame.
    /// Caller allocates memory and sets the frame address to the pointer.
    ref_frame: i32,

    pub fn getRegs(ccv: *const CCValue) []const Register {
        return switch (ccv.*) {
            inline .register, .ref_register => |*reg| reg[0..1],
            inline .register_pair, .register_triple, .register_quadruple => |*regs| regs,
            .split => |*split| (&split.reg)[0..1],
            else => &.{},
        };
    }

    pub fn format(ccv: CCValue, writer: *Writer) Writer.Error!void {
        switch (ccv) {
            .none => try writer.print("({s})", .{@tagName(ccv)}),
            .register => |pl| try writer.print("{s}", .{@tagName(pl)}),
            .register_pair => |pl| try writer.print("{s}:{s}", .{ @tagName(pl[1]), @tagName(pl[0]) }),
            .register_triple => |pl| try writer.print("{s}:{s}:{s}", .{ @tagName(pl[2]), @tagName(pl[1]), @tagName(pl[0]) }),
            .register_quadruple => |pl| try writer.print("{s}:{s}:{s}:{s}", .{ @tagName(pl[3]), @tagName(pl[2]), @tagName(pl[1]), @tagName(pl[0]) }),
            .frame => |pl| try writer.print("[frame + 0x{x}]", .{pl}),
            .split => |pl| try writer.print("{{{s}, (frame + 0x{x})}}", .{ @tagName(pl.reg), pl.frame_off }),
            .ref_register => |pl| try writer.print("byref:{s}", .{@tagName(pl)}),
            .ref_frame => |pl| try writer.print("byref:[frame + 0x{x}]", .{pl}),
        }
    }

    pub fn prependReg(ccv: CCValue, reg: Register) ?CCValue {
        return switch (ccv) {
            .none => .{ .register = reg },
            .register => |pl| .{ .register_pair = .{ reg, pl } },
            .register_pair => |pl| .{ .register_triple = .{ reg, pl[0], pl[1] } },
            .register_triple => |pl| .{ .register_quadruple = .{ reg, pl[0], pl[1], pl[2] } },
            .register_quadruple => null,
            .frame => |pl| .{ .split = .{ .reg = reg, .frame_off = pl } },
            .ref_register, .ref_frame, .split => null,
        };
    }
};

pub const zigcc = struct {
    pub const all_allocatable_regs = Integer.all_allocatable_regs ++ Floating.all_allocatable_regs;
    pub const all_static = Integer.static_regs ++ Floating.static_regs;
    pub const all_temporary = Integer.temporary_regs ++ Floating.temporary_regs;

    pub const Integer = struct {
        pub const all_allocatable_regs = function_arg_regs ++ temporary_regs ++ static_regs ++ [_]Register{.ra};

        pub const function_arg_regs = [_]Register{ .r4, .r5, .r6, .r7, .r8, .r9, .r10, .r11 };
        pub const function_ret_regs = function_arg_regs;
        pub const temporary_regs = [_]Register{ .r12, .r13, .r14, .r15, .r16, .r17, .r18, .r19, .r20 };
        pub const static_regs = [_]Register{ .r22, .r23, .r24, .r25, .r26, .r27, .r28, .r29, .r30, .r31 };
    };

    pub const Floating = struct {
        pub const all_allocatable_regs = function_arg_regs ++ temporary_regs ++ static_regs;

        pub const function_arg_regs = [_]Register{ .x0, .x1, .x2, .x3, .x4, .x5, .x6, .x7 };
        pub const function_ret_regs = function_arg_regs;
        // zig fmt: off
        pub const temporary_regs = [_]Register{
            .x8, .x9, .x10, .x11, .x12, .x13, .x14, .x15,
            .x16, .x17, .x18, .x19, .x20, .x21, .x22, .x23,
        };
        // zig fmt: on
        pub const static_regs = [_]Register{ .x24, .x25, .x26, .x27, .x28, .x29, .x30, .x31 };
    };
};

pub const c_abi = struct {
    pub const all_allocatable_regs = Integer.all_allocatable_regs ++ Floating.all_allocatable_regs;
    pub const all_static = Integer.static_regs ++ Floating.static_regs;

    pub const Integer = struct {
        pub const all_allocatable_regs = function_arg_regs ++ temporary_regs ++ static_regs;

        pub const function_arg_regs = [_]Register{ .r4, .r5, .r6, .r7, .r8, .r9, .r10, .r11 };
        pub const function_ret_regs = [_]Register{ .r4, .r5 };
        pub const temporary_regs = [_]Register{ .r12, .r13, .r14, .r15, .r16, .r17, .r18, .r19, .r20 };
        pub const static_regs = [_]Register{ .r22, .r23, .r24, .r25, .r26, .r27, .r28, .r29, .r30, .r31 };
    };

    pub const Floating = struct {
        pub const all_allocatable_regs = function_arg_regs ++ temporary_regs ++ static_regs;

        pub const function_arg_regs = [_]Register{ .x0, .x1, .x2, .x3, .x4, .x5, .x6, .x7 };
        pub const function_ret_regs = [_]Register{ .x0, .x1 };
        // zig fmt: off
        pub const temporary_regs = [_]Register{
            .x8, .x9, .x10, .x11, .x12, .x13, .x14, .x15,
            .x16, .x17, .x18, .x19, .x20, .x21, .x22, .x23,
        };
        // zig fmt: on
        pub const static_regs = [_]Register{ .x24, .x25, .x26, .x27, .x28, .x29, .x30, .x31 };
    };
};

pub fn getAbiInfo(comptime cc: std.builtin.CallingConvention.Tag) type {
    return switch (cc) {
        .auto => zigcc,
        .loongarch64_lp64 => c_abi,
        else => unreachable,
    };
}

pub const RegisterManager = RegisterManagerFn(@import("CodeGen.zig"), Register, &zigcc.all_allocatable_regs);
const RegisterBitSet = RegisterManager.RegisterBitSet;

pub fn getAllocatableRegSet(rc: Register.Class) RegisterBitSet {
    return switch (rc) {
        .int => RegisterSets.gp,
        .float, .lsx, .lasx => RegisterSets.fp,
        .fcc => unreachable, // TODO: CFR ABI?
    };
}

pub const RegisterSets = struct {
    pub const gp: RegisterBitSet = blk: {
        var set = RegisterBitSet.initEmpty();
        for (zigcc.all_allocatable_regs, 0..) |reg, index| if (reg.class() == .int) set.set(index);
        break :blk set;
    };
    pub const fp: RegisterBitSet = blk: {
        var set = RegisterBitSet.initEmpty();
        for (zigcc.all_allocatable_regs, 0..) |reg, index| if (reg.class() == .float) set.set(index);
        break :blk set;
    };
};

pub const CCResolver = struct {
    pt: Zcu.PerThread,
    cc: std.builtin.CallingConvention,

    state: struct {
        frame_size: u32 = 0,
        frame_align: InternPool.Alignment = .@"16",

        reg_count: struct {
            param_gpr: u8 = 0,
            ret_gpr: u8 = 0,
            param_fpr: u8 = 0,
            ret_fpr: u8 = 0,
        } = .{},
    } = .{},

    pub fn resolve(pt: Zcu.PerThread, gpa: Allocator, target: *const std.Target, func: *const InternPool.Key.FuncType) !CallInfo {
        _ = target;
        var resolver: CCResolver = .{ .pt = pt, .cc = func.cc };
        const return_value = try resolver.resolveType(.fromInterned(func.return_type), .ret, 4);

        const params = try gpa.alloc(CCValue, func.param_types.len);
        for (func.param_types.get(&pt.zcu.intern_pool), 0..) |param, i| {
            const param_ccv = try resolver.resolveType(.fromInterned(param), .param, 4);
            params[i] = param_ccv;
        }

        const ci: CallInfo = .{
            .params = params,
            .return_value = return_value,
            .frame_size = resolver.state.frame_size,
            .frame_align = resolver.state.frame_align,
            .err_ret_trace_reg = null,
        };
        log.debug("{f}", .{fmtCallInfo(&resolver, &ci, func)});
        return ci;
    }

    const Context = enum { param, ret };

    fn allocRegs(self: *CCResolver, class: RegisterClass, ctx: Context, count: comptime_int) ?[count]Register {
        const count_ptr: *u8, const first_reg: Register, const last_reg: Register = switch (class) {
            .int => switch (ctx) {
                .param => .{ &self.state.reg_count.param_gpr, .r4, .r11 },
                .ret => .{ &self.state.reg_count.ret_gpr, .r4, .r5 },
            },
            .floating => switch (ctx) {
                .param => .{ &self.state.reg_count.param_fpr, .x0, .x7 },
                .ret => .{ &self.state.reg_count.ret_fpr, .x0, .x1 },
            },
        };
        if (count_ptr.* + count <= (@intFromEnum(last_reg) - @intFromEnum(first_reg) + 1)) {
            var ret: [count]Register = undefined;
            for (0..count, count_ptr.*..) |i, off| {
                ret[i] = @enumFromInt(@intFromEnum(first_reg) + off);
            }
            count_ptr.* += count;
            return ret;
        } else {
            return null;
        }
    }

    fn allocReg(self: *CCResolver, class: RegisterClass, ctx: Context) ?Register {
        return if (self.allocRegs(class, ctx, 1)) |regs|
            regs[0]
        else
            null;
    }

    /// Allocates a value on stack, returning offset to the args frame
    fn allocStackType(self: *CCResolver, ty: Type) i32 {
        const zcu = self.pt.zcu;
        const alignment = ty.abiAlignment(zcu);
        const size = ty.abiSize(zcu);
        return self.allocStack(alignment, size);
    }

    /// Allocates a value on stack, returning offset to the args frame
    fn allocStack(self: *CCResolver, alignment: InternPool.Alignment, size: u64) i32 {
        self.state.frame_align = self.state.frame_align.max(alignment);
        const off = alignment.forward(self.state.frame_size);
        self.state.frame_size = @intCast(off + size);
        return @intCast(off);
    }

    fn allocPtr(self: *CCResolver, ctx: Context, use_reg: bool) CCValue {
        if (use_reg) if (self.allocReg(.int, ctx)) |reg| {
            return .{ .register = reg };
        };
        return .{ .frame = self.allocStackType(Type.usize) };
    }

    fn resolveType(self: *CCResolver, ty: Type, ctx: Context, max_regs: u8) error{CCSelectFailed}!CCValue {
        const zcu = self.pt.zcu;
        // TODO: implement vector calling convention
        // TODO: implement FP calling convention
        switch (ty.zigTypeTag(zcu)) {
            .pointer => switch (ty.ptrSize(zcu)) {
                .one, .many, .c => return self.allocPtr(ctx, max_regs >= 1),
                .slice => {
                    if (max_regs >= 2) if (self.allocRegs(.int, ctx, 2)) |regs| {
                        return .{ .register_pair = regs };
                    };
                    return .{ .frame = self.allocStack(.@"8", 8 * 2) };
                },
            },
            .int, .@"enum", .bool => {
                const ty_size = ty.abiSize(zcu);
                switch (ty_size) {
                    1...8 => return self.allocPtr(ctx, max_regs >= 1),
                    9...16 => {
                        if (max_regs >= 2) if (self.allocRegs(.int, ctx, 2)) |regs| {
                            return .{ .register_pair = regs };
                        };
                        if (max_regs >= 1)
                            if (self.allocReg(.int, ctx)) |reg| {
                                return .{ .split = .{ .reg = reg, .frame_off = self.allocStackType(Type.usize) } };
                            };
                    },
                    17...24 => if (max_regs >= 3) {
                        if (self.allocRegs(.int, ctx, 3)) |regs| {
                            return .{ .register_triple = regs };
                        }
                    },
                    25...32 => if (max_regs >= 4) {
                        if (self.allocRegs(.int, ctx, 4)) |regs| {
                            return .{ .register_quadruple = regs };
                        }
                    },
                    else => {},
                }
                return .{ .frame = self.allocStackType(ty) };
            },
            .void, .noreturn => return .none,
            .type => unreachable,
            .@"struct", .@"union" => {
                // TODO: struct flattening
                log.warn("Structure flattenning is not implemented yet. The compiled code may misbehave.", .{});

                const ty_size = ty.bitSize(zcu);

                if (zcu.typeToStruct(ty)) |struct_ty| {
                    // Structures with floating-point members
                    const ip = &zcu.intern_pool;
                    if (struct_ty.field_types.len == 1) {
                        const member_ty = Type.fromInterned(struct_ty.field_types.get(ip)[0]);
                        if (member_ty.isRuntimeFloat() and max_regs >= 1) {
                            if (self.allocReg(.floating, ctx)) |reg| {
                                return .{ .register = reg };
                            }
                        }
                    } else if (struct_ty.field_types.len == 2 and max_regs >= 2) {
                        const member_ty1 = Type.fromInterned(struct_ty.field_types.get(ip)[0]);
                        const member_ty2 = Type.fromInterned(struct_ty.field_types.get(ip)[1]);

                        if (member_ty1.isRuntimeFloat() and member_ty2.isRuntimeFloat()) {
                            if (self.allocRegs(.floating, ctx, 2)) |regs| {
                                return .{ .register_pair = regs };
                            }
                        } else if (member_ty1.isRuntimeFloat() and member_ty2.isInt(zcu)) {
                            const state = self.state;
                            if (self.allocReg(.floating, ctx)) |reg1| {
                                if (self.allocReg(.int, ctx)) |reg2| {
                                    return .{ .register_pair = .{ reg1, reg2 } };
                                }
                            }
                            self.state = state;
                        } else if (member_ty1.isInt(zcu) and member_ty2.isRuntimeFloat()) {
                            const state = self.state;
                            if (self.allocReg(.int, ctx)) |reg1| {
                                if (self.allocReg(.floating, ctx)) |reg2| {
                                    return .{ .register_pair = .{ reg1, reg2 } };
                                }
                            }
                            self.state = state;
                        }
                    }
                }

                // Structures without floating-point members and unions
                switch (ty_size) {
                    0 => return .none,
                    1...64 => return self.allocPtr(ctx, max_regs >= 1),
                    65...128 => {
                        if (max_regs >= 2) if (self.allocRegs(.int, ctx, 2)) |regs| {
                            return .{ .register_pair = regs };
                        };
                        if (max_regs >= 1) if (self.allocReg(.int, ctx)) |reg| {
                            return .{ .split = .{ .reg = reg, .frame_off = self.allocStackType(Type.usize) } };
                        };
                        return .{ .frame = self.allocStackType(Type.usize) };
                    },
                    else => if (max_regs >= 1) {
                        if (self.allocReg(.int, .param)) |reg| {
                            return .{ .ref_register = reg };
                        }
                    } else return .{ .ref_frame = self.allocStackType(Type.usize) },
                }
            },
            .array => {
                const ty_size = ty.abiSize(zcu);
                switch (ty_size) {
                    0 => return .none,
                    1...8 => return self.allocPtr(ctx, max_regs >= 1),
                    9...16 => {
                        if (max_regs >= 2) if (self.allocRegs(.int, ctx, 2)) |regs| {
                            return .{ .register_pair = regs };
                        };
                        if (max_regs >= 1) if (self.allocReg(.int, ctx)) |reg| {
                            return .{ .split = .{ .reg = reg, .frame_off = self.allocStackType(Type.usize) } };
                        };
                    },
                    17...24 => if (max_regs >= 3) {
                        if (self.allocRegs(.int, ctx, 3)) |regs| {
                            return .{ .register_triple = regs };
                        }
                    },
                    25...32 => if (max_regs >= 4) {
                        if (self.allocRegs(.int, ctx, 4)) |regs| {
                            return .{ .register_quadruple = regs };
                        }
                    },
                    else => {},
                }
                return .{ .frame = self.allocStackType(ty) };
            },
            .error_set => return self.allocPtr(ctx, max_regs >= 1),
            .error_union => {
                const payload_ty = ty.errorUnionPayload(zcu);
                const payload_bits = payload_ty.bitSize(zcu);
                if (payload_bits == 0) return self.allocPtr(ctx, max_regs >= 1);
            },
            .optional => {
                const child_ty = ty.optionalChild(zcu);
                if (child_ty.isPtrAtRuntime(zcu)) return self.allocPtr(ctx, max_regs >= 1);
                if (ty.optionalReprIsPayload(zcu)) return self.resolveType(child_ty, ctx, max_regs);

                // try allocate reg / reg + frame
                if (max_regs >= 1) {
                    if (child_ty.isAbiInt(zcu) and ty.abiSize(zcu) <= 8) {
                        if (self.allocReg(.int, ctx)) |reg|
                            return .{ .register = reg };
                    }

                    const state = self.state;
                    if (self.allocReg(.int, ctx)) |reg| {
                        const child_ccv = try self.resolveType(child_ty, ctx, max_regs - 1);
                        if (child_ccv.prependReg(reg)) |ccv| {
                            return ccv;
                        } else {
                            self.state = state;
                        }
                    }
                }

                // fallback to frame
                if (child_ty.abiSize(zcu) > 8 * 2) {
                    const frame_off = self.allocStack(.@"8", 8);
                    return .{ .ref_frame = frame_off };
                } else {
                    const frame_off = self.allocStack(.@"1", 1);
                    _ = self.allocStackType(child_ty);
                    return .{ .frame = frame_off };
                }
            },
            else => {},
        }
        log.err("Failed to select CC location of {f} as {s}", .{ ty.fmt(self.pt), @tagName(ctx) });
        return error.CCSelectFailed;
    }
};

const FormatCallInfoData = struct {
    resolver: *const CCResolver,
    ci: *const CallInfo,
    func: *const InternPool.Key.FuncType,
};
fn formatCallInfo(data: FormatCallInfoData, writer: *Writer) Writer.Error!void {
    const pt = data.resolver.pt;
    const ip = &pt.zcu.intern_pool;

    try writer.writeAll("Calling convention resolve:\n");
    try writer.print("  - CC: {s}\n", .{@tagName(data.resolver.cc)});
    try writer.print("  - ret: {f} ({f})\n", .{ data.ci.return_value, Type.fromInterned(data.func.return_type).fmt(pt) });

    for (data.ci.params, 0..) |param, i| {
        const param_ty = Type.fromInterned(data.func.param_types.get(ip)[i]);
        try writer.print("  - param {}: {f} ({f})\n", .{ i + 1, param, param_ty.fmt(pt) });
    }

    try writer.print("  - frame: size: {}, align: {}", .{ data.resolver.state.frame_size, data.resolver.state.frame_align.toByteUnits().? });
}
fn fmtCallInfo(resolver: *const CCResolver, ci: *const CallInfo, func: *const InternPool.Key.FuncType) std.fmt.Formatter(FormatCallInfoData, formatCallInfo) {
    return .{ .data = .{ .resolver = resolver, .ci = ci, .func = func } };
}
