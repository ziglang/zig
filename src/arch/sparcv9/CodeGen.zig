//! SPARCv9 codegen.
//! This lowers AIR into MIR.
const std = @import("std");
const builtin = @import("builtin");
const link = @import("../../link.zig");
const Module = @import("../../Module.zig");
const Air = @import("../../Air.zig");
const Mir = @import("Mir.zig");
const Emit = @import("Emit.zig");
const Liveness = @import("../../Liveness.zig");

const GenerateSymbolError = @import("../../codegen.zig").GenerateSymbolError;
const FnResult = @import("../../codegen.zig").FnResult;
const DebugInfoOutput = @import("../../codegen.zig").DebugInfoOutput;

const bits = @import("bits.zig");
const abi = @import("abi.zig");

const Self = @This();

pub fn generate(
    bin_file: *link.File,
    src_loc: Module.SrcLoc,
    module_fn: *Module.Fn,
    air: Air,
    liveness: Liveness,
    code: *std.ArrayList(u8),
    debug_output: DebugInfoOutput,
) GenerateSymbolError!FnResult {
    _ = bin_file;
    _ = src_loc;
    _ = module_fn;
    _ = air;
    _ = liveness;
    _ = code;
    _ = debug_output;

    @panic("TODO implement SPARCv9 codegen");
}
