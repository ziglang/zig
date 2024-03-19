const std = @import("std");
const mem = std.mem;
const Compilation = @import("../Compilation.zig");
const Pragma = @import("../Pragma.zig");
const Diagnostics = @import("../Diagnostics.zig");
const Preprocessor = @import("../Preprocessor.zig");
const Parser = @import("../Parser.zig");
const TokenIndex = @import("../Tree.zig").TokenIndex;
const Source = @import("../Source.zig");

const Once = @This();

pragma: Pragma = .{
    .afterParse = afterParse,
    .deinit = deinit,
    .preprocessorHandler = preprocessorHandler,
},
pragma_once: std.AutoHashMap(Source.Id, void),
preprocess_count: u32 = 0,

pub fn init(allocator: mem.Allocator) !*Pragma {
    var once = try allocator.create(Once);
    once.* = .{
        .pragma_once = std.AutoHashMap(Source.Id, void).init(allocator),
    };
    return &once.pragma;
}

fn afterParse(pragma: *Pragma, _: *Compilation) void {
    var self: *Once = @fieldParentPtr("pragma", pragma);
    self.pragma_once.clearRetainingCapacity();
}

fn deinit(pragma: *Pragma, comp: *Compilation) void {
    var self: *Once = @fieldParentPtr("pragma", pragma);
    self.pragma_once.deinit();
    comp.gpa.destroy(self);
}

fn preprocessorHandler(pragma: *Pragma, pp: *Preprocessor, start_idx: TokenIndex) Pragma.Error!void {
    var self: *Once = @fieldParentPtr("pragma", pragma);
    const name_tok = pp.tokens.get(start_idx);
    const next = pp.tokens.get(start_idx + 1);
    if (next.id != .nl) {
        try pp.comp.addDiagnostic(.{
            .tag = .extra_tokens_directive_end,
            .loc = name_tok.loc,
        }, pp.expansionSlice(start_idx + 1));
    }
    const seen = self.preprocess_count == pp.preprocess_count;
    const prev = try self.pragma_once.fetchPut(name_tok.loc.id, {});
    if (prev != null and !seen) {
        return error.StopPreprocessing;
    }
    self.preprocess_count = pp.preprocess_count;
}
