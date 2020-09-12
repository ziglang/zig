//! We do this instead of @cImport because the self-hosted compiler is easier
//! to bootstrap if it does not depend on translate-c.

pub extern fn ZigLLDLink(
    oformat: ZigLLVM_ObjectFormatType,
    args: [*:null]const ?[*:0]const u8,
    arg_count: usize,
    append_diagnostic: fn (context: usize, ptr: [*]const u8, len: usize) callconv(.C) void,
    context_stdout: usize,
    context_stderr: usize,
) bool;

pub const ZigLLVM_ObjectFormatType = extern enum(c_int) {
    Unknown,
    COFF,
    ELF,
    MachO,
    Wasm,
    XCOFF,
};
