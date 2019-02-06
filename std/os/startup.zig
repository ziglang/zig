// This file contains global variables that are initialized on startup from
// std/special/bootstrap.zig. There are a few things to be aware of here.
//
// First, when building an object or library, and no entry point is defined
// (such as pub fn main), std/special/bootstrap.zig is not included in the
// compilation. And so these global variables will remain set to the values
// you see here.
//
// Second, when using `zig test` to test the standard library, note that
// `zig test` is self-hosted. This means that it uses std/special/bootstrap.zig
// and an @import("std") from the install directory, which is distinct from
// the standard library files that we are directly testing with `zig test`.
// This means that these global variables would not get set. So the workaround
// here is that references to these globals from the standard library must
// use `@import("std").startup` rather than
// `@import("path/to/std/index.zig").startup` (and rather than the file path of
// this file directly). We also put "std" as a reference to itself in the
// standard library package so that this can work.

const std = @import("../index.zig");

pub var linux_tls_phdr: ?*std.elf.Phdr = null;
pub var linux_tls_img_src: [*]const u8 = undefined; // defined when linux_tls_phdr is non-null
pub var linux_elf_aux_maybe: ?[*]std.elf.Auxv = null;
pub var posix_environ_raw: [][*]u8 = undefined;
pub var posix_argv_raw: [][*]u8 = undefined;
