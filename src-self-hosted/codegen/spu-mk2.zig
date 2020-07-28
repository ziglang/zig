const std = @import("std");

pub usingnamespace @import("std").spu;

pub const Register = enum {
    dummy,

    pub fn allocIndex(self: Register) ?u4 {
        return null;
    }
};

pub const callee_preserved_regs = [_]Register{};
