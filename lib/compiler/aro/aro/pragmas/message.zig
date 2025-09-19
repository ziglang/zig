const std = @import("std");
const mem = std.mem;

const Compilation = @import("../Compilation.zig");
const Diagnostics = @import("../Diagnostics.zig");
const Parser = @import("../Parser.zig");
const Pragma = @import("../Pragma.zig");
const Preprocessor = @import("../Preprocessor.zig");
const Source = @import("../Source.zig");
const TokenIndex = @import("../Tree.zig").TokenIndex;

const Message = @This();

pragma: Pragma = .{
    .deinit = deinit,
    .preprocessorHandler = preprocessorHandler,
},

pub fn init(allocator: mem.Allocator) !*Pragma {
    var once = try allocator.create(Message);
    once.* = .{};
    return &once.pragma;
}

fn deinit(pragma: *Pragma, comp: *Compilation) void {
    const self: *Message = @fieldParentPtr("pragma", pragma);
    comp.gpa.destroy(self);
}

fn preprocessorHandler(_: *Pragma, pp: *Preprocessor, start_idx: TokenIndex) Pragma.Error!void {
    const str = Pragma.pasteTokens(pp, start_idx + 1) catch |err| switch (err) {
        error.ExpectedStringLiteral => {
            return Pragma.err(pp, start_idx, .pragma_requires_string_literal, .{"message"});
        },
        else => |e| return e,
    };

    const message_tok = pp.tokens.get(start_idx);
    const message_expansion_locs = pp.expansionSlice(start_idx);
    const loc = if (message_expansion_locs.len != 0)
        message_expansion_locs[message_expansion_locs.len - 1]
    else
        message_tok.loc;

    const diagnostic: Pragma.Diagnostic = .pragma_message;

    var sf = std.heap.stackFallback(1024, pp.comp.gpa);
    var allocating: std.Io.Writer.Allocating = .init(sf.get());
    defer allocating.deinit();

    Diagnostics.formatArgs(&allocating.writer, diagnostic.fmt, .{str}) catch return error.OutOfMemory;

    try pp.diagnostics.add(.{
        .text = allocating.written(),
        .kind = diagnostic.kind,
        .opt = diagnostic.opt,
        .location = loc.expand(pp.comp),
    });
}
