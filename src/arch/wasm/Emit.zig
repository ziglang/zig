//! Contains all logic to lower wasm MIR into its binary
//! or textual representation.

const Emit = @This();
const std = @import("std");
const Mir = @import("Mir.zig");
const link = @import("../../link.zig");
const Module = @import("../../Module.zig");
const ErrorMsg = Module.ErrorMsg;
const leb128 = std.leb;

/// Contains our list of instructions
mir: Mir,
/// Reference to the file handler
bin_file: *link.File,
/// Possible error message. When set, the value is allocated and
/// must be freed manually.
error_msg: ?*ErrorMsg = null,
/// The binary representation that will be emit by this module.
code: *std.ArrayList(u8),

const InnerError = error{
    OutOfMemory,
    EmitFail,
};

pub fn emitMir(emit: *Emit) InnerError!void {
    const mir_tags = emit.mir.instructions.items(.tag);

    for (mir_tags) |tag, index| {
        const inst = @intCast(u32, index);
        switch (tag) {}
    }
}

fn fail(emit: *Emit, comptime format: []const u8, args: anytype) InnerError {
    @setCold(true);
    std.debug.assert(emit.error_msg == null);
    // TODO: Determine the source location.
    emit.error_msg = try ErrorMsg.create(emit.bin_file.allocator, 0, format, args);
    return error.EmitFail;
}
