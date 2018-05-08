const tokenizer = @import("tokenizer.zig");
pub const Token = tokenizer.Token;
pub const Tokenizer = tokenizer.Tokenizer;
pub const parse = @import("parser.zig").parse;
pub const render = @import("parser.zig").renderSource;
pub const ast = @import("ast.zig");

test "std.zig tests" {
    _ = @import("tokenizer.zig");
    _ = @import("parser.zig");
    _ = @import("ast.zig");
}
