const builtin = @import("builtin");

/// `explicit_subsystem` is missing when the subsystem is automatically detected,
/// so Zig standard library has the subsystem detection logic here. This should generally be
/// used rather than `explicit_subsystem`.
/// On non-Windows targets, this is `null`.
pub const subsystem: ?std.Target.SubSystem = blk: {
    if (@hasDecl(builtin, "explicit_subsystem")) break :blk builtin.explicit_subsystem;
    switch (builtin.os.tag) {
        .windows => {
            if (builtin.is_test) {
                break :blk std.Target.SubSystem.Console;
            }
            if (@hasDecl(root, "main") or
                @hasDecl(root, "WinMain") or
                @hasDecl(root, "wWinMain") or
                @hasDecl(root, "WinMainCRTStartup") or
                @hasDecl(root, "wWinMainCRTStartup"))
            {
                break :blk std.Target.SubSystem.Windows;
            } else {
                break :blk std.Target.SubSystem.Console;
            }
        },
        else => break :blk null,
    }
};

/// This data structure is used by the Zig language code generation and
/// therefore must be kept in sync with the compiler implementation.
pub const StackTrace = struct {
    index: usize,
    instruction_addresses: []usize,

    pub fn format(
        self: StackTrace,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        // TODO: re-evaluate whether to use format() methods at all.
        // Until then, avoid an error when using GeneralPurposeAllocator with WebAssembly
        // where it tries to call detectTTYConfig here.
        if (builtin.os.tag == .freestanding) return;

        _ = fmt;
        _ = options;
        var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        defer arena.deinit();
        const debug_info = std.debug.getSelfDebugInfo() catch |err| {
            return writer.print("\nUnable to print stack trace: Unable to open debug info: {s}\n", .{@errorName(err)});
        };
        const tty_config = std.debug.detectTTYConfig();
        try writer.writeAll("\n");
        std.debug.writeStackTrace(self, writer, arena.allocator(), debug_info, tty_config) catch |err| {
            try writer.print("Unable to print stack trace: {s}\n", .{@errorName(err)});
        };
        try writer.writeAll("\n");
    }
};

/// This data structure is used by the Zig language code generation and
/// therefore must be kept in sync with the compiler implementation.
pub const GlobalLinkage = enum {
    Internal,
    Strong,
    Weak,
    LinkOnce,
};

/// This data structure is used by the Zig language code generation and
/// therefore must be kept in sync with the compiler implementation.
pub const SymbolVisibility = enum {
    default,
    hidden,
    protected,
};

/// This data structure is used by the Zig language code generation and
/// therefore must be kept in sync with the compiler implementation.
pub const AtomicOrder = enum {
    Unordered,
    Monotonic,
    Acquire,
    Release,
    AcqRel,
    SeqCst,
};

/// This data structure is used by the Zig language code generation and
/// therefore must be kept in sync with the compiler implementation.
pub const ReduceOp = enum {
    And,
    Or,
    Xor,
    Min,
    Max,
    Add,
    Mul,
};

/// This data structure is used by the Zig language code generation and
/// therefore must be kept in sync with the compiler implementation.
pub const AtomicRmwOp = enum {
    Xchg,
    Add,
    Sub,
    And,
    Nand,
    Or,
    Xor,
    Max,
    Min,
};

/// The code model puts constraints on the location of symbols and the size of code and data.
/// The selection of a code model is a trade off on speed and restrictions that needs to be selected on a per application basis to meet its requirements.
/// A slightly more detailed explanation can be found in (for example) the [System V Application Binary Interface (x86_64)](https://github.com/hjl-tools/x86-psABI/wiki/x86-64-psABI-1.0.pdf) 3.5.1.
///
/// This data structure is used by the Zig language code generation and
/// therefore must be kept in sync with the compiler implementation.
pub const CodeModel = enum {
    default,
    tiny,
    small,
    kernel,
    medium,
    large,
};

/// This data structure is used by the Zig language code generation and
/// therefore must be kept in sync with the compiler implementation.
pub const Mode = enum {
    Debug,
    ReleaseSafe,
    ReleaseFast,
    ReleaseSmall,
};

/// This data structure is used by the Zig language code generation and
/// therefore must be kept in sync with the compiler implementation.
pub const CallingConvention = enum {
    Unspecified,
    C,
    Naked,
    Async,
    Inline,
    Interrupt,
    Signal,
    Stdcall,
    Fastcall,
    Vectorcall,
    Thiscall,
    APCS,
    AAPCS,
    AAPCSVFP,
    SysV,
    Win64,
    PtxKernel,
};

/// This data structure is used by the Zig language code generation and
/// therefore must be kept in sync with the compiler implementation.
pub const AddressSpace = enum {
    generic,
    gs,
    fs,
    ss,
    // GPU address spaces
    global,
    constant,
    param,
    shared,
    local,
};

/// This data structure is used by the Zig language code generation and
/// therefore must be kept in sync with the compiler implementation.
pub const SourceLocation = struct {
    file: [:0]const u8,
    fn_name: [:0]const u8,
    line: u32,
    column: u32,
};

pub const TypeId = std.meta.Tag(Type);

/// TODO deprecated, use `Type`
pub const TypeInfo = Type;

/// This data structure is used by the Zig language code generation and
/// therefore must be kept in sync with the compiler implementation.
pub const Type = union(enum) {
    Type: void,
    Void: void,
    Bool: void,
    NoReturn: void,
    Int: Int,
    Float: Float,
    Pointer: Pointer,
    Array: Array,
    Struct: Struct,
    ComptimeFloat: void,
    ComptimeInt: void,
    Undefined: void,
    Null: void,
    Optional: Optional,
    ErrorUnion: ErrorUnion,
    ErrorSet: ErrorSet,
    Enum: Enum,
    Union: Union,
    Fn: Fn,
    BoundFn: Fn,
    Opaque: Opaque,
    Frame: Frame,
    AnyFrame: AnyFrame,
    Vector: Vector,
    EnumLiteral: void,

    /// This data structure is used by the Zig language code generation and
    /// therefore must be kept in sync with the compiler implementation.
    pub const Int = struct {
        signedness: Signedness,
        /// TODO make this u16 instead of comptime_int
        bits: comptime_int,
    };

    /// This data structure is used by the Zig language code generation and
    /// therefore must be kept in sync with the compiler implementation.
    pub const Float = struct {
        /// TODO make this u16 instead of comptime_int
        bits: comptime_int,
    };

    /// This data structure is used by the Zig language code generation and
    /// therefore must be kept in sync with the compiler implementation.
    pub const Pointer = struct {
        size: Size,
        is_const: bool,
        is_volatile: bool,
        /// TODO make this u16 instead of comptime_int
        alignment: comptime_int,
        address_space: AddressSpace,
        child: type,
        is_allowzero: bool,

        /// The type of the sentinel is the element type of the pointer, which is
        /// the value of the `child` field in this struct. However there is no way
        /// to refer to that type here, so we use pointer to `anyopaque`.
        sentinel: ?*const anyopaque,

        /// This data structure is used by the Zig language code generation and
        /// therefore must be kept in sync with the compiler implementation.
        pub const Size = enum {
            One,
            Many,
            Slice,
            C,
        };
    };

    /// This data structure is used by the Zig language code generation and
    /// therefore must be kept in sync with the compiler implementation.
    pub const Array = struct {
        len: comptime_int,
        child: type,

        /// The type of the sentinel is the element type of the array, which is
        /// the value of the `child` field in this struct. However there is no way
        /// to refer to that type here, so we use pointer to `anyopaque`.
        sentinel: ?*const anyopaque,
    };

    /// This data structure is used by the Zig language code generation and
    /// therefore must be kept in sync with the compiler implementation.
    pub const ContainerLayout = enum(u2) {
        Auto,
        Extern,
        Packed,
    };

    /// This data structure is used by the Zig language code generation and
    /// therefore must be kept in sync with the compiler implementation.
    pub const StructField = struct {
        name: []const u8,
        /// TODO rename to `type`
        field_type: type,
        default_value: ?*const anyopaque,
        is_comptime: bool,
        alignment: comptime_int,
    };

    /// This data structure is used by the Zig language code generation and
    /// therefore must be kept in sync with the compiler implementation.
    pub const Struct = struct {
        layout: ContainerLayout,
        fields: []const StructField,
        decls: []const Declaration,
        is_tuple: bool,
    };

    /// This data structure is used by the Zig language code generation and
    /// therefore must be kept in sync with the compiler implementation.
    pub const Optional = struct {
        child: type,
    };

    /// This data structure is used by the Zig language code generation and
    /// therefore must be kept in sync with the compiler implementation.
    pub const ErrorUnion = struct {
        error_set: type,
        payload: type,
    };

    /// This data structure is used by the Zig language code generation and
    /// therefore must be kept in sync with the compiler implementation.
    pub const Error = struct {
        name: []const u8,
    };

    /// This data structure is used by the Zig language code generation and
    /// therefore must be kept in sync with the compiler implementation.
    pub const ErrorSet = ?[]const Error;

    /// This data structure is used by the Zig language code generation and
    /// therefore must be kept in sync with the compiler implementation.
    pub const EnumField = struct {
        name: []const u8,
        value: comptime_int,
    };

    /// This data structure is used by the Zig language code generation and
    /// therefore must be kept in sync with the compiler implementation.
    pub const Enum = struct {
        /// TODO enums should no longer have this field in type info.
        layout: ContainerLayout,
        tag_type: type,
        fields: []const EnumField,
        decls: []const Declaration,
        is_exhaustive: bool,
    };

    /// This data structure is used by the Zig language code generation and
    /// therefore must be kept in sync with the compiler implementation.
    pub const UnionField = struct {
        name: []const u8,
        field_type: type,
        alignment: comptime_int,
    };

    /// This data structure is used by the Zig language code generation and
    /// therefore must be kept in sync with the compiler implementation.
    pub const Union = struct {
        layout: ContainerLayout,
        tag_type: ?type,
        fields: []const UnionField,
        decls: []const Declaration,
    };

    /// TODO deprecated use Fn.Param
    pub const FnArg = Fn.Param;

    /// This data structure is used by the Zig language code generation and
    /// therefore must be kept in sync with the compiler implementation.
    pub const Fn = struct {
        calling_convention: CallingConvention,
        alignment: comptime_int,
        is_generic: bool,
        is_var_args: bool,
        /// TODO change the language spec to make this not optional.
        return_type: ?type,
        args: []const Param,

        /// This data structure is used by the Zig language code generation and
        /// therefore must be kept in sync with the compiler implementation.
        pub const Param = struct {
            is_generic: bool,
            is_noalias: bool,
            arg_type: ?type,
        };
    };

    /// This data structure is used by the Zig language code generation and
    /// therefore must be kept in sync with the compiler implementation.
    pub const Opaque = struct {
        decls: []const Declaration,
    };

    /// This data structure is used by the Zig language code generation and
    /// therefore must be kept in sync with the compiler implementation.
    pub const Frame = struct {
        function: *const anyopaque,
    };

    /// This data structure is used by the Zig language code generation and
    /// therefore must be kept in sync with the compiler implementation.
    pub const AnyFrame = struct {
        child: ?type,
    };

    /// This data structure is used by the Zig language code generation and
    /// therefore must be kept in sync with the compiler implementation.
    pub const Vector = struct {
        len: comptime_int,
        child: type,
    };

    /// This data structure is used by the Zig language code generation and
    /// therefore must be kept in sync with the compiler implementation.
    pub const Declaration = struct {
        name: []const u8,
        is_pub: bool,
    };
};

/// This data structure is used by the Zig language code generation and
/// therefore must be kept in sync with the compiler implementation.
pub const FloatMode = enum {
    Strict,
    Optimized,
};

/// This data structure is used by the Zig language code generation and
/// therefore must be kept in sync with the compiler implementation.
pub const Endian = enum {
    Big,
    Little,
};

/// This data structure is used by the Zig language code generation and
/// therefore must be kept in sync with the compiler implementation.
pub const Signedness = enum {
    signed,
    unsigned,
};

/// This data structure is used by the Zig language code generation and
/// therefore must be kept in sync with the compiler implementation.
pub const OutputMode = enum {
    Exe,
    Lib,
    Obj,
};

/// This data structure is used by the Zig language code generation and
/// therefore must be kept in sync with the compiler implementation.
pub const LinkMode = enum {
    Static,
    Dynamic,
};

/// This data structure is used by the Zig language code generation and
/// therefore must be kept in sync with the compiler implementation.
pub const WasiExecModel = enum {
    command,
    reactor,
};

/// This data structure is used by the Zig language code generation and
/// therefore must be kept in sync with the compiler implementation.
pub const Version = struct {
    major: u32,
    minor: u32,
    patch: u32 = 0,

    pub const Range = struct {
        min: Version,
        max: Version,

        pub fn includesVersion(self: Range, ver: Version) bool {
            if (self.min.order(ver) == .gt) return false;
            if (self.max.order(ver) == .lt) return false;
            return true;
        }

        /// Checks if system is guaranteed to be at least `version` or older than `version`.
        /// Returns `null` if a runtime check is required.
        pub fn isAtLeast(self: Range, ver: Version) ?bool {
            if (self.min.order(ver) != .lt) return true;
            if (self.max.order(ver) == .lt) return false;
            return null;
        }
    };

    pub fn order(lhs: Version, rhs: Version) std.math.Order {
        if (lhs.major < rhs.major) return .lt;
        if (lhs.major > rhs.major) return .gt;
        if (lhs.minor < rhs.minor) return .lt;
        if (lhs.minor > rhs.minor) return .gt;
        if (lhs.patch < rhs.patch) return .lt;
        if (lhs.patch > rhs.patch) return .gt;
        return .eq;
    }

    pub fn parse(text: []const u8) !Version {
        var end: usize = 0;
        while (end < text.len) : (end += 1) {
            const c = text[end];
            if (!std.ascii.isDigit(c) and c != '.') break;
        }
        // found no digits or '.' before unexpected character
        if (end == 0) return error.InvalidVersion;

        var it = std.mem.split(u8, text[0..end], ".");
        // substring is not empty, first call will succeed
        const major = it.next().?;
        if (major.len == 0) return error.InvalidVersion;
        const minor = it.next() orelse "0";
        // ignore 'patch' if 'minor' is invalid
        const patch = if (minor.len == 0) "0" else (it.next() orelse "0");

        return Version{
            .major = try std.fmt.parseUnsigned(u32, major, 10),
            .minor = try std.fmt.parseUnsigned(u32, if (minor.len == 0) "0" else minor, 10),
            .patch = try std.fmt.parseUnsigned(u32, if (patch.len == 0) "0" else patch, 10),
        };
    }

    pub fn format(
        self: Version,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        out_stream: anytype,
    ) !void {
        _ = options;
        if (fmt.len == 0) {
            if (self.patch == 0) {
                if (self.minor == 0) {
                    return std.fmt.format(out_stream, "{d}", .{self.major});
                } else {
                    return std.fmt.format(out_stream, "{d}.{d}", .{ self.major, self.minor });
                }
            } else {
                return std.fmt.format(out_stream, "{d}.{d}.{d}", .{ self.major, self.minor, self.patch });
            }
        } else {
            @compileError("Unknown format string: '" ++ fmt ++ "'");
        }
    }
};

test "Version.parse" {
    @setEvalBranchQuota(3000);
    try testVersionParse();
    comptime (try testVersionParse());
}

pub fn testVersionParse() !void {
    const f = struct {
        fn eql(text: []const u8, v1: u32, v2: u32, v3: u32) !void {
            const v = try Version.parse(text);
            try std.testing.expect(v.major == v1 and v.minor == v2 and v.patch == v3);
        }

        fn err(text: []const u8, expected_err: anyerror) !void {
            _ = Version.parse(text) catch |actual_err| {
                if (actual_err == expected_err) return;
                return actual_err;
            };
            return error.Unreachable;
        }
    };

    try f.eql("2.6.32.11-svn21605", 2, 6, 32); // Debian PPC
    try f.eql("2.11.2(0.329/5/3)", 2, 11, 2); // MinGW
    try f.eql("5.4.0-1018-raspi", 5, 4, 0); // Ubuntu
    try f.eql("5.7.12_3", 5, 7, 12); // Void
    try f.eql("2.13-DEVELOPMENT", 2, 13, 0); // DragonFly
    try f.eql("2.3-35", 2, 3, 0);
    try f.eql("1a.4", 1, 0, 0);
    try f.eql("3.b1.0", 3, 0, 0);
    try f.eql("1.4beta", 1, 4, 0);
    try f.eql("2.7.pre", 2, 7, 0);
    try f.eql("0..3", 0, 0, 0);
    try f.eql("8.008.", 8, 8, 0);
    try f.eql("01...", 1, 0, 0);
    try f.eql("55", 55, 0, 0);
    try f.eql("4294967295.0.1", 4294967295, 0, 1);
    try f.eql("429496729_6", 429496729, 0, 0);

    try f.err("foobar", error.InvalidVersion);
    try f.err("", error.InvalidVersion);
    try f.err("-1", error.InvalidVersion);
    try f.err("+4", error.InvalidVersion);
    try f.err(".", error.InvalidVersion);
    try f.err("....3", error.InvalidVersion);
    try f.err("4294967296", error.Overflow);
    try f.err("5000877755", error.Overflow);
    // error.InvalidCharacter is not possible anymore
}

/// This data structure is used by the Zig language code generation and
/// therefore must be kept in sync with the compiler implementation.
pub const CallOptions = struct {
    modifier: Modifier = .auto,

    /// Only valid when `Modifier` is `Modifier.async_kw`.
    stack: ?[]align(std.Target.stack_align) u8 = null,

    pub const Modifier = enum {
        /// Equivalent to function call syntax.
        auto,

        /// Equivalent to async keyword used with function call syntax.
        async_kw,

        /// Prevents tail call optimization. This guarantees that the return
        /// address will point to the callsite, as opposed to the callsite's
        /// callsite. If the call is otherwise required to be tail-called
        /// or inlined, a compile error is emitted instead.
        never_tail,

        /// Guarantees that the call will not be inlined. If the call is
        /// otherwise required to be inlined, a compile error is emitted instead.
        never_inline,

        /// Asserts that the function call will not suspend. This allows a
        /// non-async function to call an async function.
        no_async,

        /// Guarantees that the call will be generated with tail call optimization.
        /// If this is not possible, a compile error is emitted instead.
        always_tail,

        /// Guarantees that the call will inlined at the callsite.
        /// If this is not possible, a compile error is emitted instead.
        always_inline,

        /// Evaluates the call at compile-time. If the call cannot be completed at
        /// compile-time, a compile error is emitted instead.
        compile_time,
    };
};

/// This data structure is used by the Zig language code generation and
/// therefore must be kept in sync with the compiler implementation.
pub const PrefetchOptions = struct {
    /// Whether the prefetch should prepare for a read or a write.
    rw: Rw = .read,
    /// 0 means no temporal locality. That is, the data can be immediately
    /// dropped from the cache after it is accessed.
    ///
    /// 3 means high temporal locality. That is, the data should be kept in
    /// the cache as it is likely to be accessed again soon.
    locality: u2 = 3,
    /// The cache that the prefetch should be preformed on.
    cache: Cache = .data,

    pub const Rw = enum(u1) {
        read,
        write,
    };

    pub const Cache = enum(u1) {
        instruction,
        data,
    };
};

/// This data structure is used by the Zig language code generation and
/// therefore must be kept in sync with the compiler implementation.
pub const ExportOptions = struct {
    name: []const u8,
    linkage: GlobalLinkage = .Strong,
    section: ?[]const u8 = null,
    visibility: SymbolVisibility = .default,
};

/// This data structure is used by the Zig language code generation and
/// therefore must be kept in sync with the compiler implementation.
pub const ExternOptions = struct {
    name: []const u8,
    library_name: ?[]const u8 = null,
    linkage: GlobalLinkage = .Strong,
    is_thread_local: bool = false,
};

/// This enum is set by the compiler and communicates which compiler backend is
/// used to produce machine code.
/// Think carefully before deciding to observe this value. Nearly all code should
/// be agnostic to the backend that implements the language. The use case
/// to use this value is to **work around problems with compiler implementations.**
///
/// Avoid failing the compilation if the compiler backend does not match a
/// whitelist of backends; rather one should detect that a known problem would
/// occur in a blacklist of backends.
///
/// The enum is nonexhaustive so that alternate Zig language implementations may
/// choose a number as their tag (please use a random number generator rather
/// than a "cute" number) and codebases can interact with these values even if
/// this upstream enum does not have a name for the number. Of course, upstream
/// is happy to accept pull requests to add Zig implementations to this enum.
///
/// This data structure is part of the Zig language specification.
pub const CompilerBackend = enum(u64) {
    /// It is allowed for a compiler implementation to not reveal its identity,
    /// in which case this value is appropriate. Be cool and make sure your
    /// code supports `other` Zig compilers!
    other = 0,
    /// The original Zig compiler created in 2015 by Andrew Kelley.
    /// Implemented in C++. Uses LLVM.
    stage1 = 1,
    /// The reference implementation self-hosted compiler of Zig, using the
    /// LLVM backend.
    stage2_llvm = 2,
    /// The reference implementation self-hosted compiler of Zig, using the
    /// backend that generates C source code.
    /// Note that one can observe whether the compilation will output C code
    /// directly with `object_format` value rather than the `compiler_backend` value.
    stage2_c = 3,
    /// The reference implementation self-hosted compiler of Zig, using the
    /// WebAssembly backend.
    stage2_wasm = 4,
    /// The reference implementation self-hosted compiler of Zig, using the
    /// arm backend.
    stage2_arm = 5,
    /// The reference implementation self-hosted compiler of Zig, using the
    /// x86_64 backend.
    stage2_x86_64 = 6,
    /// The reference implementation self-hosted compiler of Zig, using the
    /// aarch64 backend.
    stage2_aarch64 = 7,
    /// The reference implementation self-hosted compiler of Zig, using the
    /// x86 backend.
    stage2_x86 = 8,
    /// The reference implementation self-hosted compiler of Zig, using the
    /// riscv64 backend.
    stage2_riscv64 = 9,
    /// The reference implementation self-hosted compiler of Zig, using the
    /// sparc64 backend.
    stage2_sparc64 = 10,

    _,
};

/// This function type is used by the Zig language code generation and
/// therefore must be kept in sync with the compiler implementation.
pub const TestFn = struct {
    name: []const u8,
    func: testFnProto,
    async_frame_size: ?usize,
};

/// stage1 is *wrong*. It is not yet updated to support the new function type semantics.
const testFnProto = switch (builtin.zig_backend) {
    .stage1 => fn () anyerror!void, // wrong!
    else => *const fn () anyerror!void,
};

/// This function type is used by the Zig language code generation and
/// therefore must be kept in sync with the compiler implementation.
pub const PanicFn = fn ([]const u8, ?*StackTrace) noreturn;

/// This function is used by the Zig language code generation and
/// therefore must be kept in sync with the compiler implementation.
pub const panic: PanicFn = if (@hasDecl(root, "panic"))
    root.panic
else if (@hasDecl(root, "os") and @hasDecl(root.os, "panic"))
    root.os.panic
else
    default_panic;

/// This function is used by the Zig language code generation and
/// therefore must be kept in sync with the compiler implementation.
pub fn default_panic(msg: []const u8, error_return_trace: ?*StackTrace) noreturn {
    @setCold(true);

    // Until self-hosted catches up with stage1 language features, we have a simpler
    // default panic function:
    if (builtin.zig_backend == .stage2_c or
        builtin.zig_backend == .stage2_wasm or
        builtin.zig_backend == .stage2_arm or
        builtin.zig_backend == .stage2_aarch64 or
        builtin.zig_backend == .stage2_x86_64 or
        builtin.zig_backend == .stage2_x86 or
        builtin.zig_backend == .stage2_riscv64 or
        builtin.zig_backend == .stage2_sparc64)
    {
        while (true) {
            @breakpoint();
        }
    }
    switch (builtin.os.tag) {
        .freestanding => {
            while (true) {
                @breakpoint();
            }
        },
        .wasi => {
            std.debug.print("{s}", .{msg});
            std.os.abort();
        },
        .uefi => {
            const uefi = std.os.uefi;

            const ExitData = struct {
                pub fn create_exit_data(exit_msg: []const u8, exit_size: *usize) ![*:0]u16 {
                    // Need boot services for pool allocation
                    if (uefi.system_table.boot_services == null) {
                        return error.BootServicesUnavailable;
                    }

                    // ExitData buffer must be allocated using boot_services.allocatePool
                    var utf16: []u16 = try uefi.raw_pool_allocator.alloc(u16, 256);
                    errdefer uefi.raw_pool_allocator.free(utf16);

                    if (exit_msg.len > 255) {
                        return error.MessageTooLong;
                    }

                    var fmt: [256]u8 = undefined;
                    var slice = try std.fmt.bufPrint(&fmt, "\r\nerr: {s}\r\n", .{exit_msg});

                    var len = try std.unicode.utf8ToUtf16Le(utf16, slice);

                    utf16[len] = 0;

                    exit_size.* = 256;

                    return @ptrCast([*:0]u16, utf16.ptr);
                }
            };

            var exit_size: usize = 0;
            var exit_data = ExitData.create_exit_data(msg, &exit_size) catch null;

            if (exit_data) |data| {
                if (uefi.system_table.std_err) |out| {
                    _ = out.setAttribute(uefi.protocols.SimpleTextOutputProtocol.red);
                    _ = out.outputString(data);
                    _ = out.setAttribute(uefi.protocols.SimpleTextOutputProtocol.white);
                }
            }

            if (uefi.system_table.boot_services) |bs| {
                _ = bs.exit(uefi.handle, .Aborted, exit_size, exit_data);
            }

            // Didn't have boot_services, just fallback to whatever.
            std.os.abort();
        },
        else => {
            const first_trace_addr = @returnAddress();
            std.debug.panicImpl(error_return_trace, first_trace_addr, msg);
        },
    }
}

pub fn panicUnwrapError(st: ?*StackTrace, err: anyerror) noreturn {
    @setCold(true);
    std.debug.panicExtra(st, "attempt to unwrap error: {s}", .{@errorName(err)});
}

pub fn panicOutOfBounds(index: usize, len: usize) noreturn {
    @setCold(true);
    std.debug.panic("attempt to index out of bound: index {d}, len {d}", .{ index, len });
}

pub noinline fn returnError(maybe_st: ?*StackTrace) void {
    @setCold(true);
    @setRuntimeSafety(false);
    const st = maybe_st orelse return;
    addErrRetTraceAddr(st, @returnAddress());
}

pub inline fn addErrRetTraceAddr(st: *StackTrace, addr: usize) void {
    st.instruction_addresses[st.index & (st.instruction_addresses.len - 1)] = addr;
    st.index +%= 1;
}

const std = @import("std.zig");
const root = @import("root");
