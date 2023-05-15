const builtin = @import("builtin");
const std = @import("../std.zig");
const os = std.os;
const mem = std.mem;

/// Maps register names to their DWARF register number.
/// `bp`, `ip`, and `sp` are provided as aliases.
pub const Register = switch (builtin.cpu.arch) {
    .x86 => {

        //pub const ip = Register.eip;
        //pub const sp = Register.
    },
   .x86_64 => enum(u8) {
        rax,
        rdx,
        rcx,
        rbx,
        rsi,
        rdi,
        rbp,
        rsp,
        r8,
        r9,
        r10,
        r11,
        r12,
        r13,
        r14,
        r15,
        rip,
        xmm0,
        xmm1,
        xmm2,
        xmm3,
        xmm4,
        xmm5,
        xmm6,
        xmm7,
        xmm8,
        xmm9,
        xmm10,
        xmm11,
        xmm12,
        xmm13,
        xmm14,
        xmm15,

       pub const fp = Register.rbp;
       pub const ip = Register.rip;
       pub const sp = Register.rsp;
    },
    else => enum {},
};

fn RegBytesReturnType(comptime ContextPtrType: type) type {
    const info = @typeInfo(ContextPtrType);
    if (info != .Pointer or info.Pointer.child != os.ucontext_t) {
        @compileError("Expected a pointer to ucontext_t, got " ++ @typeName(@TypeOf(ContextPtrType)));
    }

    return if (info.Pointer.is_const) return []const u8 else []u8;
}

/// Returns a slice containing the backing storage for `reg_number`
pub fn regBytes(ucontext_ptr: anytype, reg_number: u8) !RegBytesReturnType(@TypeOf(ucontext_ptr)) {
    var m = &ucontext_ptr.mcontext;

    return switch (builtin.cpu.arch) {
        .x86_64 => switch (builtin.os.tag) {
            .linux, .netbsd, .solaris => switch (reg_number) {
                0 => mem.asBytes(&m.gregs[os.REG.RAX]),
                1 => mem.asBytes(&m.gregs[os.REG.RDX]),
                2 => mem.asBytes(&m.gregs[os.REG.RCX]),
                3 => mem.asBytes(&m.gregs[os.REG.RBX]),
                4 => mem.asBytes(&m.gregs[os.REG.RSI]),
                5 => mem.asBytes(&m.gregs[os.REG.RDI]),
                6 => mem.asBytes(&m.gregs[os.REG.RBP]),
                7 => mem.asBytes(&m.gregs[os.REG.RSP]),
                8 => mem.asBytes(&m.gregs[os.REG.R8]),
                9 => mem.asBytes(&m.gregs[os.REG.R9]),
                10 => mem.asBytes(&m.gregs[os.REG.R10]),
                11 => mem.asBytes(&m.gregs[os.REG.R11]),
                12 => mem.asBytes(&m.gregs[os.REG.R12]),
                13 => mem.asBytes(&m.gregs[os.REG.R13]),
                14 => mem.asBytes(&m.gregs[os.REG.R14]),
                15 => mem.asBytes(&m.gregs[os.REG.R15]),
                16 => mem.asBytes(&m.gregs[os.REG.RIP]),
                17...32 => |i| mem.asBytes(&m.fpregs.xmm[i - 17]),
                else => error.InvalidRegister,
            },
            //.freebsd => @intCast(usize, ctx.mcontext.rip),
            //.openbsd => @intCast(usize, ctx.sc_rip),
            //.macos => @intCast(usize, ctx.mcontext.ss.rip),
            else => error.UnimplementedOs,
        },
        else => error.UnimplementedArch,
    };
}

/// Returns the ABI-defined default value this register has in the unwinding table
/// before running any of the CIE instructions.
pub fn getRegDefaultValue(reg_number: u8, out: []u8) void {
    // TODO: Implement any ABI-specific rules for the default value for registers
    _ = reg_number;
    @memset(out, undefined);
}

fn writeUnknownReg(writer: anytype, reg_number: u8) !void {
    try writer.print("reg{}", .{reg_number});
}

pub fn writeRegisterName(writer: anytype, arch: ?std.Target.Cpu.Arch, reg_number: u8) !void {
    if (arch) |a| {
        switch (a) {
            .x86_64 => {
                switch (reg_number) {
                    0 => try writer.writeAll("RAX"),
                    1 => try writer.writeAll("RDX"),
                    2 => try writer.writeAll("RCX"),
                    3 => try writer.writeAll("RBX"),
                    4 => try writer.writeAll("RSI"),
                    5 => try writer.writeAll("RDI"),
                    6 => try writer.writeAll("RBP"),
                    7 => try writer.writeAll("RSP"),
                    8...15 => try writer.print("R{}", .{reg_number}),
                    16 => try writer.writeAll("RIP"),
                    17...32 => try writer.print("XMM{}", .{reg_number - 17}),
                    33...40 => try writer.print("ST{}", .{reg_number - 33}),
                    41...48 => try writer.print("MM{}", .{reg_number - 41}),
                    49 => try writer.writeAll("RFLAGS"),
                    50 => try writer.writeAll("ES"),
                    51 => try writer.writeAll("CS"),
                    52 => try writer.writeAll("SS"),
                    53 => try writer.writeAll("DS"),
                    54 => try writer.writeAll("FS"),
                    55 => try writer.writeAll("GS"),
                    // 56-57 Reserved
                    58 => try writer.writeAll("FS.BASE"),
                    59 => try writer.writeAll("GS.BASE"),
                    // 60-61 Reserved
                    62 => try writer.writeAll("TR"),
                    63 => try writer.writeAll("LDTR"),
                    64 => try writer.writeAll("MXCSR"),
                    65 => try writer.writeAll("FCW"),
                    66 => try writer.writeAll("FSW"),
                    67...82 => try writer.print("XMM{}", .{reg_number - 51}),
                    // 83-117 Reserved
                    118...125 => try writer.print("K{}", .{reg_number - 118}),
                    // 126-129 Reserved
                    else => try writeUnknownReg(writer, reg_number),
                }
            },

            // TODO: Add x86, aarch64

            else => try writeUnknownReg(writer, reg_number),
        }
    } else try writeUnknownReg(writer, reg_number);
}

const FormatRegisterData = struct {
    reg_number: u8,
    arch: ?std.Target.Cpu.Arch,
};

pub fn formatRegister(
    data: FormatRegisterData,
    comptime fmt: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) !void {
    _ = fmt;
    _ = options;
    try writeRegisterName(writer, data.arch, data.reg_number);
}

pub fn fmtRegister(reg_number: u8, arch: ?std.Target.Cpu.Arch) std.fmt.Formatter(formatRegister) {
    return .{ .data = .{ .reg_number = reg_number, .arch = arch } };
}
