//! We do this instead of @cImport because the self-hosted compiler is easier
//! to bootstrap if it does not depend on translate-c.

pub const Link = ZigLLDLink;
pub extern fn ZigLLDLink(
    oformat: ObjectFormatType,
    args: [*:null]const ?[*:0]const u8,
    arg_count: usize,
    append_diagnostic: fn (context: usize, ptr: [*]const u8, len: usize) callconv(.C) void,
    context_stdout: usize,
    context_stderr: usize,
) bool;

pub const ObjectFormatType = extern enum(c_int) {
    Unknown,
    COFF,
    ELF,
    MachO,
    Wasm,
    XCOFF,
};

pub const GetHostCPUName = LLVMGetHostCPUName;
extern fn LLVMGetHostCPUName() ?[*:0]u8;

pub const GetNativeFeatures = ZigLLVMGetNativeFeatures;
extern fn ZigLLVMGetNativeFeatures() ?[*:0]u8;
