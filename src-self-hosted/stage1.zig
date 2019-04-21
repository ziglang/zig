// This is Zig code that is used by both stage1 and stage2.
// The prototypes in src/userland.h must match these definitions.

const std = @import("std");

// ABI warning
export fn stage2_zen(ptr: *[*]const u8, len: *usize) void {
    const info_zen = @import("main.zig").info_zen;
    ptr.* = &info_zen;
    len.* = info_zen.len;
}

// ABI warning
export fn stage2_panic(ptr: [*]const u8, len: usize) void {
    @panic(ptr[0..len]);
}

// ABI warning
const TranslateMode = extern enum {
    import,
    translate,
};

// ABI warning
const Error = extern enum {
    None,
    OutOfMemory,
    InvalidFormat,
    SemanticAnalyzeFail,
    AccessDenied,
    Interrupted,
    SystemResources,
    FileNotFound,
    FileSystem,
    FileTooBig,
    DivByZero,
    Overflow,
    PathAlreadyExists,
    Unexpected,
    ExactDivRemainder,
    NegativeDenominator,
    ShiftedOutOneBits,
    CCompileErrors,
    EndOfFile,
    IsDir,
    NotDir,
    UnsupportedOperatingSystem,
    SharingViolation,
    PipeBusy,
    PrimitiveTypeNotFound,
    CacheUnavailable,
    PathTooLong,
    CCompilerCannotFindFile,
    ReadingDepFile,
    InvalidDepFile,
    MissingArchitecture,
    MissingOperatingSystem,
    UnknownArchitecture,
    UnknownOperatingSystem,
    UnknownABI,
    InvalidFilename,
    DiskQuota,
    DiskSpace,
    UnexpectedWriteFailure,
    UnexpectedSeekFailure,
    UnexpectedFileTruncationFailure,
    Unimplemented,
    OperationAborted,
    BrokenPipe,
    NoSpaceLeft,
};

const FILE = std.c.FILE;
const ast = std.zig.ast;
const translate_c = @import("translate_c.zig");

/// Args should have a null terminating last arg.
export fn stage2_translate_c(
    out_ast: **ast.Tree,
    out_errors_ptr: *[*]translate_c.ClangErrMsg,
    out_errors_len: *usize,
    args_begin: [*]?[*]const u8,
    args_end: [*]?[*]const u8,
    mode: TranslateMode,
    resources_path: [*]const u8,
) Error {
    var errors: []translate_c.ClangErrMsg = undefined;
    out_ast.* = translate_c.translate(args_begin, args_end, switch (mode) {
        .import => translate_c.Mode.import,
        .translate => translate_c.Mode.translate,
    }, &errors) catch |err| switch (err) {
        error.Unimplemented => return Error.Unimplemented,
    };

    return Error.None;
}

export fn stage2_free_clang_errors(errors_ptr: [*]translate_c.ClangErrMsg, errors_len: usize) void {
    translate_c.freeErrors(errors_ptr[0..errors_len]);
}

export fn stage2_render_ast(tree: *ast.Tree, output_file: *FILE) Error {
    const c_out_stream = &std.io.COutStream.init(output_file).stream;
    _ = std.zig.render(std.heap.c_allocator, c_out_stream, tree) catch |e| switch (e) {
        error.SystemResources => return Error.SystemResources,
        error.OperationAborted => return Error.OperationAborted,
        error.BrokenPipe => return Error.BrokenPipe,
        error.DiskQuota => return Error.DiskQuota,
        error.FileTooBig => return Error.FileTooBig,
        error.NoSpaceLeft => return Error.NoSpaceLeft,
        error.AccessDenied => return Error.AccessDenied,
        error.OutOfMemory => return Error.OutOfMemory,
        error.Unexpected => return Error.Unexpected,
        error.InputOutput => return Error.FileSystem,
    };
    return Error.None;
}
