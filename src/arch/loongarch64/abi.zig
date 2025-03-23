/// ABI related stuff for LoongArch64.
const std = @import("std");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;

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
    /// A value stored in the call frame with given offset.
    frame: i32,
    /// A value whose lower-ordered bits are in a register and the others are in the call frame.
    split: struct { reg: Register, frame_off: i32 },
    /// A value passed as a pointer in a register.
    ref_register: Register,
    /// A value passed as a pointer in the call frame.
    ref_frame: i32,

    pub fn getRegs(ccv: *const CCValue) []const Register {
        return switch (ccv.*) {
            inline .register, .ref_register => |*reg| reg[0..1],
            .register_pair => |*regs| regs,
            .split => |*split| (&split.reg)[0..1],
            else => &.{},
        };
    }

    pub fn format(
        ccv: CCValue,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) @TypeOf(writer).Error!void {
        switch (ccv) {
            .none => try writer.print("({s})", .{@tagName(ccv)}),
            .register => |pl| try writer.print("{s}", .{@tagName(pl)}),
            .register_pair => |pl| try writer.print("{s}:{s}", .{ @tagName(pl[1]), @tagName(pl[0]) }),
            .frame => |pl| try writer.print("[frame + 0x{x}]", .{pl}),
            .split => |pl| try writer.print("{{{s}, (frame + 0x{x})}}", .{ @tagName(pl.reg), pl.frame_off }),
            .ref_register => |pl| try writer.print("byref:{s}", .{@tagName(pl)}),
            .ref_frame => |pl| try writer.print("byref:[frame + 0x{x}]", .{pl}),
        }
    }
};

pub const zigcc = struct {
    pub const all_allocatable_regs = Integer.all_allocatable_regs ++ Floating.all_allocatable_regs;
    pub const all_static = Integer.static_regs ++ Floating.static_regs;

    pub const Integer = struct {
        pub const all_allocatable_regs = [_]Register{ret_addr_reg} ++ function_arg_regs ++ temporary_regs ++ static_regs;

        pub const ret_addr_reg = .r1;
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

    // TODO: implement zigcc
    pub const CCResolver = c_abi.CCResolver;
};

pub const c_abi = struct {
    pub const all_allocatable_regs = Integer.all_allocatable_regs ++ Floating.all_allocatable_regs;
    pub const all_static = Integer.static_regs ++ Floating.static_regs;

    pub const Integer = struct {
        pub const all_allocatable_regs = [_]Register{ret_addr_reg} ++ function_arg_regs ++ temporary_regs ++ static_regs;

        pub const ret_addr_reg = .r1;
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

    pub const CCResolver = struct {
        pt: *const Zcu.PerThread,

        frame_size: u32 = 0,
        frame_align: InternPool.Alignment = .@"16",

        reg_count: struct {
            param_gpr: u8 = 0,
            ret_gpr: u8 = 0,
            param_fpr: u8 = 0,
            ret_fpr: u8 = 0,
        } = .{},

        pub fn resolve(pt: *const Zcu.PerThread, gpa: Allocator, target: *const std.Target, func: *const InternPool.Key.FuncType) !CallInfo {
            _ = target;
            var resolver: CCResolver = .{ .pt = pt };

            log.debug("C calling convention resolve:", .{});
            const return_value = try resolver.resolveType(.fromInterned(func.return_type), .ret);
            log.debug("  - ret: {}", .{return_value});

            const params = try gpa.alloc(CCValue, func.param_types.len);
            for (func.param_types.get(&pt.zcu.intern_pool), 0..) |param, i| {
                const param_ccv = try resolver.resolveType(.fromInterned(param), .param);
                log.debug("  - param {}: {}", .{ i + 1, param_ccv });
                params[i] = param_ccv;
            }

            log.debug("  - frame: size: {}, align: {}", .{ resolver.frame_size, resolver.frame_align.toByteUnits().? });
            return .{
                .params = params,
                .return_value = return_value,
                .frame_size = resolver.frame_size,
                .frame_align = resolver.frame_align,
                .err_ret_trace_reg = null,
            };
        }

        const Context = enum { param, ret };

        fn allocRegs(self: *CCResolver, class: RegisterClass, ctx: Context, count: comptime_int) ?[count]Register {
            const count_ptr: *u8, const first_reg: Register, const last_reg: Register = switch (class) {
                .int => switch (ctx) {
                    .param => .{ &self.reg_count.param_gpr, .r4, .r11 },
                    .ret => .{ &self.reg_count.ret_gpr, .r4, .r5 },
                },
                .floating => switch (ctx) {
                    .param => .{ &self.reg_count.param_fpr, .x0, .x7 },
                    .ret => .{ &self.reg_count.ret_fpr, .x0, .x1 },
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
        fn allocStack(self: *CCResolver, ty: Type) i32 {
            const zcu = self.pt.zcu;
            const alignment = ty.abiAlignment(zcu);
            const size = ty.abiSize(zcu);
            self.frame_align = self.frame_align.max(alignment);
            const off = alignment.forward(self.frame_size);
            self.frame_size = @intCast(off + size);
            return @intCast(off);
        }

        fn allocPtr(self: *CCResolver, ctx: Context) CCValue {
            if (self.allocReg(.int, ctx)) |reg| {
                return .{ .register = reg };
            } else {
                return .{ .frame = self.allocStack(Type.usize) };
            }
        }

        fn resolveType(self: *CCResolver, ty: Type, ctx: Context) error{CCSelectFailed}!CCValue {
            const zcu = self.pt.zcu;
            // TODO: implement vector calling convention
            // TODO: implement FP calling convention
            switch (ty.zigTypeTag(zcu)) {
                .pointer => switch (ty.ptrSize(zcu)) {
                    .c => return self.allocPtr(ctx),
                    else => {},
                },
                .int, .@"enum", .bool => |ty_tag| {
                    const ty_size: u16 = switch (ty_tag) {
                        .int, .@"enum" => ty.intInfo(zcu).bits,
                        .bool => 1,
                        else => unreachable,
                    };
                    switch (ty_size) {
                        1...64 => return self.allocPtr(ctx),
                        65...128 => {
                            if (self.allocRegs(.int, ctx, 2)) |regs| {
                                return .{ .register_pair = regs };
                            } else if (self.allocReg(.int, ctx)) |reg| {
                                return .{ .split = .{ .reg = reg, .frame_off = self.allocStack(Type.usize) } };
                            } else {
                                return .{ .frame = self.allocStack(Type.usize) };
                            }
                        },
                        else => {},
                    }
                },
                .void, .noreturn => return .none,
                .@"struct", .@"union" => {
                    // TODO: struct flattening
                    log.warn("Structure flattenning is not implemented yet. The compiled code may misbehave.", .{});

                    const ty_size = ty.bitSize(zcu);

                    if (zcu.typeToStruct(ty)) |struct_ty| {
                        // Structures with floating-point members
                        const ip = &zcu.intern_pool;
                        if (struct_ty.field_types.len == 1) {
                            const member_ty = Type.fromInterned(struct_ty.field_types.get(ip)[0]);
                            if (member_ty.isRuntimeFloat()) {
                                if (self.allocReg(.floating, ctx)) |reg| {
                                    return .{ .register = reg };
                                }
                            }
                        } else if (struct_ty.field_types.len == 2) {
                            const member_ty1 = Type.fromInterned(struct_ty.field_types.get(ip)[0]);
                            const member_ty2 = Type.fromInterned(struct_ty.field_types.get(ip)[1]);

                            if (member_ty1.isRuntimeFloat() and member_ty2.isRuntimeFloat()) {
                                if (self.allocRegs(.floating, ctx, 2)) |regs| {
                                    return .{ .register_pair = regs };
                                }
                            } else if (member_ty1.isRuntimeFloat() and member_ty2.isInt(zcu)) {
                                const reg_count = self.reg_count;
                                if (self.allocReg(.floating, ctx)) |reg1| {
                                    if (self.allocReg(.int, ctx)) |reg2| {
                                        return .{ .register_pair = .{ reg1, reg2 } };
                                    }
                                }
                                self.reg_count = reg_count;
                            } else if (member_ty1.isInt(zcu) and member_ty2.isRuntimeFloat()) {
                                const reg_count = self.reg_count;
                                if (self.allocReg(.int, ctx)) |reg1| {
                                    if (self.allocReg(.floating, ctx)) |reg2| {
                                        return .{ .register_pair = .{ reg1, reg2 } };
                                    }
                                }
                                self.reg_count = reg_count;
                            }
                        }
                    }

                    // Structures without floating-point members and unions
                    switch (ty_size) {
                        0 => return .none,
                        1...64 => return self.allocPtr(ctx),
                        65...128 => {
                            if (self.allocRegs(.int, ctx, 2)) |regs| {
                                return .{ .register_pair = regs };
                            } else if (self.allocReg(.int, ctx)) |reg| {
                                return .{ .split = .{ .reg = reg, .frame_off = self.allocStack(Type.usize) } };
                            } else {
                                return .{ .frame = self.allocStack(Type.usize) };
                            }
                        },
                        else => {
                            if (self.allocReg(.int, .param)) |reg| {
                                return .{ .ref_register = reg };
                            } else {
                                return .{ .ref_frame = self.allocStack(Type.usize) };
                            }
                        },
                    }
                },
                .array => return self.allocPtr(ctx),
                else => {},
            }
            log.err("Failed to select C ABI CC location of {} as {s}", .{ ty.fmt(self.pt.*), @tagName(ctx) });
            return error.CCSelectFailed;
        }
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

const RegisterSets = struct {
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
