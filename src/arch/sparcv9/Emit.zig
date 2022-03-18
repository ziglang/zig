//! This file contains the functionality for lowering SPARCv9 MIR into
//! machine code

const Emit = @This();
const Mir = @import("Mir.zig");
const bits = @import("bits.zig");
