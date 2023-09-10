target: Symbol.Index,
offset: u64,
addend: u32,

const std = @import("std");

const Symbol = @import("Symbol.zig");
const Relocation = @This();
