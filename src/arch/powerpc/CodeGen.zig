const builtin = @import("builtin");
const std = @import("std");

const Air = @import("../../Air.zig");
const codegen = @import("../../codegen.zig");
const InternPool = @import("../../InternPool.zig");
const link = @import("../../link.zig");
const Liveness = @import("../../Liveness.zig");
const Zcu = @import("../../Zcu.zig");

const assert = std.debug.assert;
const log = std.log.scoped(.codegen);

pub fn generate(
    bin_file: *link.File,
    pt: Zcu.PerThread,
    src_loc: Zcu.LazySrcLoc,
    func_index: InternPool.Index,
    air: Air,
    liveness: Liveness,
    code: *std.ArrayListUnmanaged(u8),
    debug_output: link.File.DebugInfoOutput,
) codegen.CodeGenError!void {
    _ = bin_file;
    _ = pt;
    _ = src_loc;
    _ = func_index;
    _ = air;
    _ = liveness;
    _ = code;
    _ = debug_output;

    unreachable;
}

pub fn generateLazy(
    bin_file: *link.File,
    pt: Zcu.PerThread,
    src_loc: Zcu.LazySrcLoc,
    lazy_sym: link.File.LazySymbol,
    code: *std.ArrayListUnmanaged(u8),
    debug_output: link.File.DebugInfoOutput,
) codegen.CodeGenError!void {
    _ = bin_file;
    _ = pt;
    _ = src_loc;
    _ = lazy_sym;
    _ = code;
    _ = debug_output;

    unreachable;
}
