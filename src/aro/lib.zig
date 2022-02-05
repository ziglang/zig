pub const Codegen = @import("Codegen.zig");
pub const Compilation = @import("Compilation.zig");
pub const Diagnostics = @import("Diagnostics.zig");
pub const Parser = @import("Parser.zig");
pub const Preprocessor = @import("Preprocessor.zig");
pub const Source = @import("Source.zig");
pub const Tokenizer = @import("Tokenizer.zig");
pub const Tree = @import("Tree.zig");
pub const Type = @import("Type.zig");
pub const Value = @import("Value.zig");

pub const version_str = "0.0.0-dev";
pub const version = @import("std").SemanticVersion.parse(version_str) catch unreachable;
