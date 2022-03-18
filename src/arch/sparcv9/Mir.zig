//! Machine Intermediate Representation.
//! This data is produced by SPARCv9 Codegen or SPARCv9 assembly parsing
//! These instructions have a 1:1 correspondence with machine code instructions
//! for the target. MIR can be lowered to source-annotated textual assembly code
//! instructions, or it can be lowered to machine code.
//! The main purpose of MIR is to postpone the assignment of offsets until Isel,
//! so that, for example, the smaller encodings of jump instructions can be used.

const Mir = @This();
const bits = @import("bits.zig");
const Register = bits.Register;
