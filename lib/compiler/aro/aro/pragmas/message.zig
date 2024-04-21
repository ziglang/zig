const std = @import("std");
const mem = std.mem;
const Compilation = @import("../Compilation.zig");
const Pragma = @import("../Pragma.zig");
const Diagnostics = @import("../Diagnostics.zig");
const Preprocessor = @import("../Preprocessor.zig");
const Parser = @import("../Parser.zig");
const TokenIndex = @import("../Tree.zig").TokenIndex;
const Source = @import("../Source.zig");

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
    const message_tok = pp.tokens.get(start_idx);
    const message_expansion_locs = pp.expansionSlice(start_idx);

    const str = Pragma.pasteTokens(pp, start_idx + 1) catch |err| switch (err) {
        error.ExpectedStringLiteral => {
            return pp.comp.addDiagnostic(.{
                .tag = .pragma_requires_string_literal,
                .loc = message_tok.loc,
                .extra = .{ .str = "message" },
            }, message_expansion_locs);
        },
        else => |e| return e,
    };

    const loc = if (message_expansion_locs.len != 0)
        message_expansion_locs[message_expansion_locs.len - 1]
    else
        message_tok.loc;
    const extra = Diagnostics.Message.Extra{ .str = try pp.comp.diagnostics.arena.allocator().dupe(u8, str) };
    return pp.comp.addDiagnostic(.{ .tag = .pragma_message, .loc = loc, .extra = extra }, &.{});
}
