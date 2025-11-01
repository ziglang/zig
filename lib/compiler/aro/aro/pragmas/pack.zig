const std = @import("std");
const mem = std.mem;

const Compilation = @import("../Compilation.zig");
const Diagnostics = @import("../Diagnostics.zig");
const Parser = @import("../Parser.zig");
const Pragma = @import("../Pragma.zig");
const Preprocessor = @import("../Preprocessor.zig");
const Tree = @import("../Tree.zig");
const TokenIndex = Tree.TokenIndex;

const Pack = @This();

pragma: Pragma = .{
    .deinit = deinit,
    .parserHandler = parserHandler,
},
stack: std.ArrayList(struct { label: []const u8, val: u8 }) = .empty,

pub fn init(allocator: mem.Allocator) !*Pragma {
    var pack = try allocator.create(Pack);
    pack.* = .{};
    return &pack.pragma;
}

fn deinit(pragma: *Pragma, comp: *Compilation) void {
    var self: *Pack = @fieldParentPtr("pragma", pragma);
    self.stack.deinit(comp.gpa);
    comp.gpa.destroy(self);
}

fn parserHandler(pragma: *Pragma, p: *Parser, start_idx: TokenIndex) Compilation.Error!void {
    var pack: *Pack = @fieldParentPtr("pragma", pragma);
    var idx = start_idx + 1;
    const l_paren = p.pp.tokens.get(idx);
    if (l_paren.id != .l_paren) {
        return Pragma.err(p.pp, idx, .pragma_pack_lparen, .{});
    }
    idx += 1;

    // TODO -fapple-pragma-pack -fxl-pragma-pack
    const apple_or_xl = false;
    const tok_ids = p.pp.tokens.items(.id);
    const arg = idx;
    switch (tok_ids[arg]) {
        .identifier => {
            idx += 1;
            const Action = enum {
                show,
                push,
                pop,
            };
            const action = std.meta.stringToEnum(Action, p.tokSlice(arg)) orelse {
                return Pragma.err(p.pp, arg, .pragma_pack_unknown_action, .{});
            };
            switch (action) {
                .show => {
                    return Pragma.err(p.pp, arg, .pragma_pack_show, .{p.pragma_pack orelse 8});
                },
                .push, .pop => {
                    var new_val: ?u8 = null;
                    var label: ?[]const u8 = null;
                    if (tok_ids[idx] == .comma) {
                        idx += 1;
                        const next = idx;
                        idx += 1;
                        switch (tok_ids[next]) {
                            .pp_num => new_val = (try packInt(p, next)) orelse return,
                            .identifier => {
                                label = p.tokSlice(next);
                                if (tok_ids[idx] == .comma) {
                                    idx += 1;
                                    const int = idx;
                                    idx += 1;
                                    if (tok_ids[int] != .pp_num) {
                                        return Pragma.err(p.pp, int, .pragma_pack_int_ident, .{});
                                    }
                                    new_val = (try packInt(p, int)) orelse return;
                                }
                            },
                            else => return Pragma.err(p.pp, next, .pragma_pack_int_ident, .{}),
                        }
                    }
                    if (action == .push) {
                        try pack.stack.append(p.comp.gpa, .{ .label = label orelse "", .val = p.pragma_pack orelse 8 });
                    } else {
                        const pop_success = pack.pop(p, label);
                        if (new_val != null) {
                            try Pragma.err(p.pp, arg, .pragma_pack_undefined_pop, .{});
                        } else if (!pop_success) {
                            try Pragma.err(p.pp, arg, .pragma_pack_empty_stack, .{});
                        }
                    }
                    if (new_val) |some| {
                        p.pragma_pack = some;
                    }
                },
            }
        },
        .r_paren => if (apple_or_xl) {
            pack.pop(p, null);
        } else {
            p.pragma_pack = null;
        },
        .pp_num => {
            const new_val = (try packInt(p, arg)) orelse return;
            idx += 1;
            if (apple_or_xl) {
                try pack.stack.append(p.gpa, .{ .label = "", .val = p.pragma_pack });
            }
            p.pragma_pack = new_val;
        },
        else => {},
    }

    if (tok_ids[idx] != .r_paren) {
        return Pragma.err(p.pp, idx, .pragma_pack_rparen, .{});
    }
}

fn packInt(p: *Parser, tok_i: TokenIndex) Compilation.Error!?u8 {
    const res = p.parseNumberToken(tok_i) catch |err| switch (err) {
        error.ParsingFailed => {
            try Pragma.err(p.pp, tok_i, .pragma_pack_int, .{});
            return null;
        },
        else => |e| return e,
    };
    const int = res.val.toInt(u64, p.comp) orelse 99;
    switch (int) {
        1, 2, 4, 8, 16 => return @intCast(int),
        else => {
            try Pragma.err(p.pp, tok_i, .pragma_pack_int, .{});
            return null;
        },
    }
}

/// Returns true if an item was successfully popped.
fn pop(pack: *Pack, p: *Parser, maybe_label: ?[]const u8) bool {
    if (maybe_label) |label| {
        var i = pack.stack.items.len;
        while (i > 0) {
            i -= 1;
            if (std.mem.eql(u8, pack.stack.items[i].label, label)) {
                p.pragma_pack = pack.stack.items[i].val;
                pack.stack.items.len = i;
                return true;
            }
        }
        return false;
    } else {
        const prev = pack.stack.pop() orelse {
            p.pragma_pack = 2;
            return false;
        };
        p.pragma_pack = prev.val;
        return true;
    }
}
