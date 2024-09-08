// from #8146 - the error used to reference 'd', of all things

const Compilation = @import("This file must not exist.zig");

d: Compilation.Directory,

test "thing" {}

// error
// target=native
//
// This file must not exist.zig': FileNotFound
