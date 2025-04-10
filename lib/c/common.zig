const builtin = @import("builtin");
const std = @import("std");

pub const linkage: std.builtin.GlobalLinkage = if (builtin.is_test)
    .internal
else
    .strong;

/// Determines the symbol's visibility to other objects.
/// For WebAssembly this allows the symbol to be resolved to other modules, but will not
/// export it to the host runtime.
pub const visibility: std.builtin.SymbolVisibility = if (builtin.cpu.arch.isWasm() and linkage != .internal)
    .hidden
else
    .default;
