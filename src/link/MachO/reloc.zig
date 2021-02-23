const std = @import("std");
const log = std.log.scoped(.reloc);

pub const Arm64 = union(enum) {
    Branch: packed struct {
        disp: u26,
        fixed: u5 = 0b00101,
        link: u1,
    },
    BranchRegister: packed struct {
        _1: u5 = 0b0000_0,
        reg: u5,
        _2: u11 = 0b1111_1000_000,
        link: u1,
        _3: u10 = 0b1101_0110_00,
    },
    Address: packed struct {
        reg: u5,
        immhi: u19,
        _1: u5 = 0b10000,
        immlo: u2,
        page: u1,
    },
    LoadRegister: packed struct {
        rt: u5,
        rn: u5,
        offset: u12,
        _1: u8 = 0b111_0_01_01,
        size: u1,
        _2: u1 = 0b1,
    },
    LoadLiteral: packed struct {
        reg: u5,
        literal: u19,
        _1: u6 = 0b011_0_00,
        size: u1,
        _2: u1 = 0b0,
    },
    Add: packed struct {
        rt: u5,
        rn: u5,
        offset: u12,
        _1: u9 = 0b0_0_100010_0,
        size: u1,
    },

    pub fn toU32(self: Arm64) u32 {
        const as_u32 = switch (self) {
            .Branch => |x| @bitCast(u32, x),
            .BranchRegister => |x| @bitCast(u32, x),
            .Address => |x| @bitCast(u32, x),
            .LoadRegister => |x| @bitCast(u32, x),
            .LoadLiteral => |x| @bitCast(u32, x),
            .Add => |x| @bitCast(u32, x),
        };
        return as_u32;
    }

    pub fn b(disp: i28) Arm64 {
        return Arm64{
            .Branch = .{
                .disp = @truncate(u26, @bitCast(u28, disp) >> 2),
                .link = 0,
            },
        };
    }

    pub fn bl(disp: i28) Arm64 {
        return Arm64{
            .Branch = .{
                .disp = @truncate(u26, @bitCast(u28, disp) >> 2),
                .link = 1,
            },
        };
    }

    pub fn br(reg: u5) Arm64 {
        return Arm64{
            .BranchRegister = .{
                .reg = reg,
                .link = 0,
            },
        };
    }

    pub fn blr(reg: u5) Arm64 {
        return Arm64{
            .BranchRegister = .{
                .reg = reg,
                .link = 1,
            },
        };
    }

    pub fn adr(reg: u5, disp: u21) Arm64 {
        return Arm64{
            .Address = .{
                .reg = reg,
                .immhi = @truncate(u19, disp >> 2),
                .immlo = @truncate(u2, disp),
                .page = 0,
            },
        };
    }

    pub fn adrp(reg: u5, disp: u21) Arm64 {
        return Arm64{
            .Address = .{
                .reg = reg,
                .immhi = @truncate(u19, disp >> 2),
                .immlo = @truncate(u2, disp),
                .page = 1,
            },
        };
    }

    pub fn ldr(reg: u5, literal: u19, size: u1) Arm64 {
        return Arm64{
            .LoadLiteral = .{
                .reg = reg,
                .literal = literal,
                .size = size,
            },
        };
    }

    pub fn add(rt: u5, rn: u5, offset: u12, size: u1) Arm64 {
        return Arm64{
            .Add = .{
                .rt = rt,
                .rn = rn,
                .offset = offset,
                .size = size,
            },
        };
    }

    pub fn ldrr(rt: u5, rn: u5, offset: u12, size: u1) Arm64 {
        return Arm64{
            .LoadRegister = .{
                .rt = rt,
                .rn = rn,
                .offset = offset,
                .size = size,
            },
        };
    }

    pub fn isArithmetic(inst: *const [4]u8) bool {
        const group_decode = @truncate(u5, inst[3]);
        log.debug("{b}", .{group_decode});
        return ((group_decode >> 2) == 4);
        // if ((group_decode >> 2) == 4) {
        //     log.debug("Arithmetic imm", .{});
        // } else if (((group_decode & 0b01010) >> 3) == 1) {
        //     log.debug("Load/store", .{});
        // }
    }
};
