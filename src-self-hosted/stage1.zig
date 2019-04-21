// This is Zig code that is used by both stage1 and stage2.
// The prototypes in src/userland.h must match these definitions.

const std = @import("std");

pub const info_zen =
    \\
    \\ * Communicate intent precisely.
    \\ * Edge cases matter.
    \\ * Favor reading code over writing code.
    \\ * Only one obvious way to do things.
    \\ * Runtime crashes are better than bugs.
    \\ * Compile errors are better than runtime crashes.
    \\ * Incremental improvements.
    \\ * Avoid local maximums.
    \\ * Reduce the amount one must remember.
    \\ * Minimize energy spent on coding style.
    \\ * Together we serve end users.
    \\
    \\
;

export fn stage2_zen(ptr: *[*]const u8, len: *usize) void {
    ptr.* = &info_zen;
    len.* = info_zen.len;
}

export fn stage2_panic(ptr: [*]const u8, len: usize) void {
    @panic(ptr[0..len]);
}

const TranslateMode = extern enum {
    import,
    translate,
};

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

/// Args should have a null terminating last arg.
export fn stage2_translate_c(
    out_ast: **ast.Tree,
    args_begin: [*]?[*]const u8,
    args_end: [*]?[*]const u8,
    mode: TranslateMode,
) Error {
    const translate_c = @import("translate_c.zig");
    out_ast.* = translate_c.translate(args_begin, args_end, switch (mode) {
        .import => translate_c.Mode.import,
        .translate => translate_c.Mode.translate,
    }) catch |err| switch (err) {
        error.Unimplemented => return Error.Unimplemented,
    };
    return Error.None;
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
