const tokenizer = @import("zig/tokenizer.zig");
pub const Token = tokenizer.Token;
pub const Tokenizer = tokenizer.Tokenizer;
pub const parse = @import("zig/parse.zig").parse;
pub const parseStringLiteral = @import("zig/parse_string_literal.zig").parseStringLiteral;
pub const render = @import("zig/render.zig").render;
pub const ast = @import("zig/ast.zig");
pub const system = @import("zig/system.zig");

test "std.zig tests" {
    _ = @import("zig/ast.zig");
    _ = @import("zig/parse.zig");
    _ = @import("zig/render.zig");
    _ = @import("zig/tokenizer.zig");
    _ = @import("zig/parse_string_literal.zig");
}
