/// Deprecated
pub const Codegen = @import("Codegen_legacy.zig");
pub const CodeGen = @import("CodeGen.zig");
pub const Compilation = @import("Compilation.zig");
pub const Diagnostics = @import("Diagnostics.zig");
pub const Driver = @import("Driver.zig");
pub const Interner = @import("Interner.zig");
pub const Ir = @import("Ir.zig");
pub const Object = @import("Object.zig");
pub const Parser = @import("Parser.zig");
pub const Preprocessor = @import("Preprocessor.zig");
pub const Source = @import("Source.zig");
pub const Tokenizer = @import("Tokenizer.zig");
pub const Tree = @import("Tree.zig");
pub const Type = @import("Type.zig");
pub const TypeMapper = @import("StringInterner.zig").TypeMapper;
pub const target_util = @import("target.zig");

pub const version_str = "0.0.0-dev";
pub const version = @import("std").SemanticVersion.parse(version_str) catch unreachable;

pub const CallingConvention = enum {
    C,
    stdcall,
    thiscall,
    vectorcall,
};
