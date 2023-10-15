comptime {
    if (@import("build_options").only_core_functionality) {
        @compileError("resinator included in only_core_functionality build");
    }
}

pub const ani = @import("resinator/ani.zig");
pub const ast = @import("resinator/ast.zig");
pub const bmp = @import("resinator/bmp.zig");
pub const cli = @import("resinator/cli.zig");
pub const code_pages = @import("resinator/code_pages.zig");
pub const comments = @import("resinator/comments.zig");
pub const compile = @import("resinator/compile.zig");
pub const errors = @import("resinator/errors.zig");
pub const ico = @import("resinator/ico.zig");
pub const lang = @import("resinator/lang.zig");
pub const lex = @import("resinator/lex.zig");
pub const literals = @import("resinator/literals.zig");
pub const parse = @import("resinator/parse.zig");
pub const preprocess = @import("resinator/preprocess.zig");
pub const rc = @import("resinator/rc.zig");
pub const res = @import("resinator/res.zig");
pub const source_mapping = @import("resinator/source_mapping.zig");
pub const utils = @import("resinator/utils.zig");
pub const windows1252 = @import("resinator/windows1252.zig");
