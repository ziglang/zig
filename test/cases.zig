const std = @import("std");
const Cases = @import("src/Cases.zig");

pub const BuildOptions = struct {
    enable_llvm: bool,
    llvm_has_m68k: bool,
    llvm_has_csky: bool,
    llvm_has_arc: bool,
    llvm_has_xtensa: bool,
};

pub fn addCases(cases: *Cases, build_options: BuildOptions, b: *std.Build) !void {
    try @import("compile_errors.zig").addCases(cases, b);
    try @import("llvm_targets.zig").addCases(cases, build_options, b);
    try @import("nvptx.zig").addCases(cases, b);
}
