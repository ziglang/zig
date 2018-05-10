const tokenizer = @import("tokenizer.zig");
pub const Token = tokenizer.Token;
pub const Tokenizer = tokenizer.Tokenizer;
pub const parse = @import("parse.zig").parse;
pub const render = @import("render.zig").render;
pub const ast = @import("ast.zig");

test "std.zig tests" {
    _ = @import("ast.zig");
    _ = @import("parse.zig");
    _ = @import("render.zig");
    _ = @import("tokenizer.zig");
}
