pub usingnamespace @import("builtin");

/// Deprecated: use `std.Target`.
pub const Target = std.Target;

/// Deprecated: use `std.Target.Os`.
pub const Os = std.Target.Os;

/// Deprecated: use `std.Target.Cpu.Arch`.
pub const Arch = std.Target.Cpu.Arch;

/// Deprecated: use `std.Target.Abi`.
pub const Abi = std.Target.Abi;

/// Deprecated: use `std.Target.ObjectFormat`.
pub const ObjectFormat = std.Target.ObjectFormat;

/// Deprecated: use `std.Target.SubSystem`.
pub const SubSystem = std.Target.SubSystem;

/// Deprecated: use `std.Target.Cpu`.
pub const Cpu = std.Target.Cpu;

/// `explicit_subsystem` is missing when the subsystem is automatically
/// detected, so Zig standard library has the subsystem detection logic
/// here. This should generally be used rather than `explicit_subsystem`.  On
/// non-Windows targets, this is `null`.
pub const subsystem: ?SubSystem = blk: {
    if (@hasDecl(@This(), "explicit_subsystem")) break :blk explicit_subsystem;
    switch (os.tag) {
        .windows => {
            if (is_test) {
                break :blk SubSystem.Console;
            }
            if (@hasDecl(root, "main") or
                @hasDecl(root, "WinMain") or
                @hasDecl(root, "wWinMain") or
                @hasDecl(root, "WinMainCRTStartup") or
                @hasDecl(root, "wWinMainCRTStartup"))
            {
                break :blk SubSystem.Windows;
            } else {
                break :blk SubSystem.Console;
            }
        },
        else => break :blk null,
    }
};

pub const StackTrace = struct {
    // This data structure is used by the Zig language code generation and
    // therefore must be kept in sync with the compiler implementation.
    index: usize,
    instruction_addresses: []usize,
};

pub const GlobalLinkage = enum {
    // This data structure is used by the Zig language code generation and
    // therefore must be kept in sync with the compiler implementation.
    Internal,
    Strong,
    Weak,
    LinkOnce,
};

pub const AtomicOrder = enum {
    // This data structure is used by the Zig language code generation and
    // therefore must be kept in sync with the compiler implementation.
    Unordered,
    Monotonic,
    Acquire,
    Release,
    AcqRel,
    SeqCst,
};

pub const AtomicRmwOp = enum {
    // This data structure is used by the Zig language code generation and
    // therefore must be kept in sync with the compiler implementation.
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

/// The code model puts constraints on the location of symbols and the size of
/// code and data.  The selection of a code model is a trade off on speed and
/// restrictions that needs to be selected on a per application basis to meet
/// its requirements.  A slightly more detailed explanation can be found in
/// (for example) the
/// [System V Application Binary Interface (x86_64)](https://github.com/hjl-tools/x86-psABI/wiki/x86-64-psABI-1.0.pdf)
/// 3.5.1.
pub const CodeModel = enum {
    // This data structure is used by the Zig language code generation and
    // therefore must be kept in sync with the compiler implementation.
    default,
    tiny,
    small,
    kernel,
    medium,
    large,
};

pub const Mode = enum {
    // This data structure is used by the Zig language code generation and
    // therefore must be kept in sync with the compiler implementation.
    Debug,
    ReleaseSafe,
    ReleaseFast,
    ReleaseSmall,
};

pub const CallingConvention = enum {
    // This data structure is used by the Zig language code generation and
    // therefore must be kept in sync with the compiler implementation.
    Unspecified,
    C,
    Cold,
    Naked,
    Async,
    Interrupt,
    Signal,
    Stdcall,
    Fastcall,
    Vectorcall,
    Thiscall,
    APCS,
    AAPCS,
    AAPCSVFP,
};

pub const SourceLocation = struct {
    // This data structure is used by the Zig language code generation and
    // therefore must be kept in sync with the compiler implementation.
    file: [:0]const u8,
    fn_name: [:0]const u8,
    line: u32,
    column: u32,
};

pub const TypeId = @TagType(TypeInfo);

pub const TypeInfo = union(enum) {
    // This data structure is used by the Zig language code generation and
    // therefore must be kept in sync with the compiler implementation.
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
    Opaque: void,
    Frame: Frame,
    AnyFrame: AnyFrame,
    Vector: Vector,
    EnumLiteral: void,

    pub const Int = struct {
        // This data structure is used by the Zig language code generation and
        // therefore must be kept in sync with the compiler implementation.
        is_signed: bool,
        bits: comptime_int,
    };

    pub const Float = struct {
        // This data structure is used by the Zig language code generation and
        // therefore must be kept in sync with the compiler implementation.
        bits: comptime_int,
    };

    pub const Pointer = struct {
        // This data structure is used by the Zig language code generation and
        // therefore must be kept in sync with the compiler implementation.
        size: Size,
        is_const: bool,
        is_volatile: bool,
        alignment: comptime_int,
        child: type,
        is_allowzero: bool,

        // This field is an optional type.  The type of the sentinel is the
        // element type of the pointer, which is the value of the `child` field
        // in this struct. However there is no way to refer to that type here,
        // so we use `var`.
        sentinel: var,

        pub const Size = enum {
            // This data structure is used by the Zig language code generation
            // and therefore must be kept in sync with the compiler
            // implementation.
            One,
            Many,
            Slice,
            C,
        };
    };

    pub const Array = struct {
        // This data structure is used by the Zig language code generation and
        // therefore must be kept in sync with the compiler implementation.
        len: comptime_int,
        child: type,

        /// This field is an optional type.  The type of the sentinel
        /// is the element type of the array, which is the value of the
        /// `child` field in this struct. However there is no way to
        /// refer to that type here, so we use `var`.
        sentinel: var,
    };

    pub const ContainerLayout = enum {
        // This data structure is used by the Zig language code
        // generation and therefore must be kept in sync with the
        // compiler implementation.
        Auto,
        Extern,
        Packed,
    };

    pub const StructField = struct {
        // This data structure is used by the Zig language code
        // generation and therefore must be kept in sync with the
        // compiler implementation.
        name: []const u8,
        offset: ?comptime_int,
        field_type: type,
        default_value: var,
    };

    pub const Struct = struct {
        // This data structure is used by the Zig language code
        // generation and therefore must be kept in sync with the
        // compiler implementation.
        layout: ContainerLayout,
        fields: []const StructField,
        decls: []const Declaration,
    };

    pub const Optional = struct {
        // This data structure is used by the Zig language code
        // generation and therefore must be kept in sync with the
        // compiler implementation.
        child: type,
    };

    pub const ErrorUnion = struct {
        // This data structure is used by the Zig language code generation and
        // therefore must be kept in sync with the compiler implementation.
        error_set: type,
        payload: type,
    };

    pub const Error = struct {
        // This data structure is used by the Zig language code
        // generation and therefore must be kept in sync with the
        // compiler implementation.
        name: []const u8,
        /// This field is ignored when using @Type().
        value: comptime_int,
    };

    // This data structure is used by the Zig language code generation
    // and therefore must be kept in sync with the compiler
    // implementation.
    pub const ErrorSet = ?[]const Error;

    pub const EnumField = struct {
        // This data structure is used by the Zig language code generation and
        // therefore must be kept in sync with the compiler implementation.
        name: []const u8,
        value: comptime_int,
    };

    pub const Enum = struct {
        // This data structure is used by the Zig language code
        // generation and therefore must be kept in sync with the
        // compiler implementation.
        layout: ContainerLayout,
        tag_type: type,
        fields: []const EnumField,
        decls: []const Declaration,
        is_exhaustive: bool,
    };

    pub const UnionField = struct {
        // This data structure is used by the Zig language code
        // generation and therefore must be kept in sync with the
        // compiler implementation.
        name: []const u8,
        enum_field: ?EnumField,
        field_type: type,
    };

    pub const Union = struct {
        // This data structure is used by the Zig language code
        // generation and therefore must be kept in sync with the
        // compiler implementation.
        layout: ContainerLayout,
        tag_type: ?type,
        fields: []const UnionField,
        decls: []const Declaration,
    };

    pub const FnArg = struct {
        // This data structure is used by the Zig language code
        // generation and therefore must be kept in sync with the
        // compiler implementation.
        is_generic: bool,
        is_noalias: bool,
        arg_type: ?type,
    };

    pub const Fn = struct {
        // This data structure is used by the Zig language code
        // generation and therefore must be kept in sync with the
        // compiler implementation.
        calling_convention: CallingConvention,
        is_generic: bool,
        is_var_args: bool,
        return_type: ?type,
        args: []const FnArg,
    };

    pub const Frame = struct {
        // This data structure is used by the Zig language code
        // generation and therefore must be kept in sync with the
        // compiler implementation.
        function: var,
    };

    pub const AnyFrame = struct {
        // This data structure is used by the Zig language code generation and
        // therefore must be kept in sync with the compiler implementation.
        child: ?type,
    };

    pub const Vector = struct {
        // This data structure is used by the Zig language code generation and
        // therefore must be kept in sync with the compiler implementation.
        len: comptime_int,
        child: type,
    };

    pub const Declaration = struct {
        // This data structure is used by the Zig language code generation and
        // therefore must be kept in sync with the compiler implementation.
        name: []const u8,
        is_pub: bool,
        data: Data,

        pub const Data = union(enum) {
            // This data structure is used by the Zig language code generation
            // and therefore must be kept in sync with the compiler
            // implementation.
            Type: type,
            Var: type,
            Fn: FnDecl,

            pub const FnDecl = struct {
                // This data structure is used by the Zig language code
                // generation and therefore must be kept in sync with the
                // compiler implementation.
                fn_type: type,
                inline_type: Inline,
                is_var_args: bool,
                is_extern: bool,
                is_export: bool,
                lib_name: ?[]const u8,
                return_type: type,
                arg_names: []const []const u8,

                pub const Inline = enum {
                    // This data structure is used by the Zig language code
                    // generation and therefore must be kept in sync with the
                    // compiler implementation.
                    Auto,
                    Always,
                    Never,
                };
            };
        };
    };
};

pub const FloatMode = enum {
    // This data structure is used by the Zig language code generation and
    // therefore must be kept in sync with the compiler implementation.
    Strict,
    Optimized,
};

pub const Endian = enum {
    // This data structure is used by the Zig language code generation and
    // therefore must be kept in sync with the compiler implementation.
    Big,
    Little,
};

pub const OutputMode = enum {
    // This data structure is used by the Zig language code generation and
    // therefore must be kept in sync with the compiler implementation.
    Exe,
    Lib,
    Obj,
};

pub const LinkMode = enum {
    // This data structure is used by the Zig language code generation and
    // therefore must be kept in sync with the compiler implementation.
    Static,
    Dynamic,
};

pub const Version = struct {
    // This data structure is used by the Zig language code generation and
    // therefore must be kept in sync with the compiler implementation.
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
        var it = std.mem.split(text, ".");
        return Version{
            .major = try std.fmt.parseInt(u32, it.next() orelse return error.InvalidVersion, 10),
            .minor = try std.fmt.parseInt(u32, it.next() orelse "0", 10),
            .patch = try std.fmt.parseInt(u32, it.next() orelse "0", 10),
        };
    }

    pub fn format(
        self: Version,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        out_stream: var,
    ) !void {
        if (fmt.len == 0) {
            if (self.patch == 0) {
                if (self.minor == 0) {
                    return std.fmt.format(out_stream, "{}", .{self.major});
                } else {
                    return std.fmt.format(
                        out_stream,
                        "{}.{}",
                        .{ self.major, self.minor },
                    );
                }
            } else {
                return std.fmt.format(
                    out_stream,
                    "{}.{}.{}",
                    .{ self.major, self.minor, self.patch },
                );
            }
        } else {
            @compileError("Unknown format string: '" ++ fmt ++ "'");
        }
    }
};

pub const CallOptions = struct {
    // This data structure is used by the Zig language code generation and
    // therefore must be kept in sync with the compiler implementation.
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
        /// callsite. If the call is otherwise required to be tail-called or
        /// inlined, a compile error is emitted instead.
        never_tail,

        /// Guarantees that the call will not be inlined. If the call is
        /// otherwise required to be inlined, a compile error is emitted
        /// instead.
        never_inline,

        /// Asserts that the function call will not suspend. This allows a
        /// non-async function to call an async function.
        no_async,

        /// Guarantees that the call will be generated with tail call
        /// optimization.  If this is not possible, a compile error is emitted
        /// instead.
        always_tail,

        /// Guarantees that the call will inlined at the callsite.  If this is
        /// not possible, a compile error is emitted instead.
        always_inline,

        /// Evaluates the call at compile-time. If the call cannot be completed
        /// at compile-time, a compile error is emitted instead.
        compile_time,
    };
};

pub const ExportOptions = struct {
    // This data structure is used by the Zig language code generation and
    // therefore must be kept in sync with the compiler implementation.
    name: []const u8,
    linkage: GlobalLinkage = .Strong,
    section: ?[]const u8 = null,
};

pub const TestFn = struct {
    // This function type is used by the Zig language code generation and
    // therefore must be kept in sync with the compiler implementation.
    name: []const u8,
    func: fn () anyerror!void,
    async_frame_size: ?usize,
};

// This function type is used by the Zig language code generation and therefore
// must be kept in sync with the compiler implementation.
pub const PanicFn = fn ([]const u8, ?*StackTrace) noreturn;

// This function is used by the Zig language code generation and therefore must
// be kept in sync with the compiler implementation.
pub const panic: PanicFn = if (@hasDecl(root, "panic")) root.panic else default_panic;

pub fn default_panic(msg: []const u8, error_return_trace: ?*StackTrace) noreturn {
    // This function is used by the Zig language code generation and therefore
    // must be kept in sync with the compiler implementation.
    @setCold(true);
    if (@hasDecl(root, "os") and @hasDecl(root.os, "panic")) {
        root.os.panic(msg, error_return_trace);
        unreachable;
    }
    switch (os.tag) {
        .freestanding => {
            while (true) {
                @breakpoint();
            }
        },
        .wasi => {
            std.debug.warn("{}", .{msg});
            std.os.abort();
        },
        .uefi => {
            // TODO look into using the debug info and logging helpful messages
            std.os.abort();
        },
        else => {
            const first_trace_addr = @returnAddress();
            std.debug.panicExtra(error_return_trace, first_trace_addr, "{}", .{msg});
        },
    }
}

const std = @import("std.zig");
const root = @import("root");
