pub const CodeGen = @import("aro/CodeGen.zig");
pub const Compilation = @import("aro/Compilation.zig");
pub const Diagnostics = @import("aro/Diagnostics.zig");
pub const Driver = @import("aro/Driver.zig");
pub const Parser = @import("aro/Parser.zig");
pub const Preprocessor = @import("aro/Preprocessor.zig");
pub const Source = @import("aro/Source.zig");
pub const Tokenizer = @import("aro/Tokenizer.zig");
pub const Toolchain = @import("aro/Toolchain.zig");
pub const Tree = @import("aro/Tree.zig");
pub const Type = @import("aro/Type.zig");
pub const TypeMapper = @import("aro/StringInterner.zig").TypeMapper;
pub const target_util = @import("aro/target.zig");
pub const Value = @import("aro/Value.zig");

const backend = @import("backend.zig");
pub const Interner = backend.Interner;
pub const Ir = backend.Ir;
pub const Object = backend.Object;
pub const CallingConvention = backend.CallingConvention;

pub const version_str = backend.version_str;
pub const version = backend.version;

test {
    _ = @import("aro/Builtins.zig");
    _ = @import("aro/char_info.zig");
    _ = @import("aro/Compilation.zig");
    _ = @import("aro/Driver/Distro.zig");
    _ = @import("aro/Driver/Filesystem.zig");
    _ = @import("aro/Driver/GCCVersion.zig");
    _ = @import("aro/InitList.zig");
    _ = @import("aro/Preprocessor.zig");
    _ = @import("aro/target.zig");
    _ = @import("aro/Tokenizer.zig");
    _ = @import("aro/toolchains/Linux.zig");
    _ = @import("aro/Value.zig");
}
