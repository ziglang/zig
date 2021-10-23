const std = @import("std");
const builtin = @import("builtin");
const expect = std.testing.expect;
const native_endian = builtin.target.cpu.arch.endian();
