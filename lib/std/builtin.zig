pub usingnamespace @import("builtin");

/// Deprecated: use `std.Target.Os`.
pub const Os = std.Target.Os;

/// Deprecated: use `std.Target.Arch`.
pub const Arch = std.Target.Arch;

/// Deprecated: use `std.Target.Abi`.
pub const Abi = std.Target.Abi;

/// Deprecated: use `std.Target.ObjectFormat`.
pub const ObjectFormat = std.Target.ObjectFormat;

/// Deprecated: use `std.Target.SubSystem`.
pub const SubSystem = std.Target.SubSystem;

/// `explicit_subsystem` is missing when the subsystem is automatically detected,
/// so Zig standard library has the subsystem detection logic here. This should generally be
/// used rather than `explicit_subsystem`.
/// On non-Windows targets, this is `null`.
pub const subsystem: ?SubSystem = blk: {
    if (@hasDecl(@This(), "explicit_subsystem")) break :blk explicit_subsystem;
    switch (os) {
        .windows => {
            if (is_test) {
                break :blk SubSystem.Console;
            }
            if (@hasDecl(root, "WinMain") or
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

/// This data structure is used by the Zig language code generation and
/// therefore must be kept in sync with the compiler implementation.
pub const StackTrace = struct {
    index: usize,
    instruction_addresses: []usize,
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

/// This data structure is used by the Zig language code generation and
/// therefore must be kept in sync with the compiler implementation.
pub const Mode = enum {
    Debug,
    ReleaseSafe,
    ReleaseFast,
    ReleaseSmall,
};

pub const TypeId = @TagType(TypeInfo);

/// This data structure is used by the Zig language code generation and
/// therefore must be kept in sync with the compiler implementation.
pub const TypeInfo = union(enum) {
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
    ArgTuple: void,
    Opaque: void,
    Frame: void,
    AnyFrame: AnyFrame,
    Vector: Vector,
    EnumLiteral: void,

    /// This data structure is used by the Zig language code generation and
    /// therefore must be kept in sync with the compiler implementation.
    pub const Int = struct {
        is_signed: bool,
        bits: comptime_int,
    };

    /// This data structure is used by the Zig language code generation and
    /// therefore must be kept in sync with the compiler implementation.
    pub const Float = struct {
        bits: comptime_int,
    };

    /// This data structure is used by the Zig language code generation and
    /// therefore must be kept in sync with the compiler implementation.
    pub const Pointer = struct {
        size: Size,
        is_const: bool,
        is_volatile: bool,
        alignment: comptime_int,
        child: type,
        is_allowzero: bool,

        /// The type of the sentinel is the element type of the pointer, which is
        /// the value of the `child` field in this struct. However there is no way
        /// to refer to that type here, so we use `var`.
        sentinel: var,

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
        /// to refer to that type here, so we use `var`.
        sentinel: var,
    };

    /// This data structure is used by the Zig language code generation and
    /// therefore must be kept in sync with the compiler implementation.
    pub const ContainerLayout = enum {
        Auto,
        Extern,
        Packed,
    };

    /// This data structure is used by the Zig language code generation and
    /// therefore must be kept in sync with the compiler implementation.
    pub const StructField = struct {
        name: []const u8,
        offset: ?comptime_int,
        field_type: type,
    };

    /// This data structure is used by the Zig language code generation and
    /// therefore must be kept in sync with the compiler implementation.
    pub const Struct = struct {
        layout: ContainerLayout,
        fields: []StructField,
        decls: []Declaration,
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
        value: comptime_int,
    };

    /// This data structure is used by the Zig language code generation and
    /// therefore must be kept in sync with the compiler implementation.
    pub const ErrorSet = ?[]Error;

    /// This data structure is used by the Zig language code generation and
    /// therefore must be kept in sync with the compiler implementation.
    pub const EnumField = struct {
        name: []const u8,
        value: comptime_int,
    };

    /// This data structure is used by the Zig language code generation and
    /// therefore must be kept in sync with the compiler implementation.
    pub const Enum = struct {
        layout: ContainerLayout,
        tag_type: type,
        fields: []EnumField,
        decls: []Declaration,
    };

    /// This data structure is used by the Zig language code generation and
    /// therefore must be kept in sync with the compiler implementation.
    pub const UnionField = struct {
        name: []const u8,
        enum_field: ?EnumField,
        field_type: type,
    };

    /// This data structure is used by the Zig language code generation and
    /// therefore must be kept in sync with the compiler implementation.
    pub const Union = struct {
        layout: ContainerLayout,
        tag_type: ?type,
        fields: []UnionField,
        decls: []Declaration,
    };

    /// This data structure is used by the Zig language code generation and
    /// therefore must be kept in sync with the compiler implementation.
    pub const CallingConvention = enum {
        Unspecified,
        C,
        Cold,
        Naked,
        Stdcall,
        Async,
    };

    /// This data structure is used by the Zig language code generation and
    /// therefore must be kept in sync with the compiler implementation.
    pub const FnArg = struct {
        is_generic: bool,
        is_noalias: bool,
        arg_type: ?type,
    };

    /// This data structure is used by the Zig language code generation and
    /// therefore must be kept in sync with the compiler implementation.
    pub const Fn = struct {
        calling_convention: CallingConvention,
        is_generic: bool,
        is_var_args: bool,
        return_type: ?type,
        args: []FnArg,
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
        data: Data,

        /// This data structure is used by the Zig language code generation and
        /// therefore must be kept in sync with the compiler implementation.
        pub const Data = union(enum) {
            Type: type,
            Var: type,
            Fn: FnDecl,

            /// This data structure is used by the Zig language code generation and
            /// therefore must be kept in sync with the compiler implementation.
            pub const FnDecl = struct {
                fn_type: type,
                inline_type: Inline,
                calling_convention: CallingConvention,
                is_var_args: bool,
                is_extern: bool,
                is_export: bool,
                lib_name: ?[]const u8,
                return_type: type,
                arg_names: [][]const u8,

                /// This data structure is used by the Zig language code generation and
                /// therefore must be kept in sync with the compiler implementation.
                pub const Inline = enum {
                    Auto,
                    Always,
                    Never,
                };
            };
        };
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
pub const OutType = enum {
    Unknown,
    Exe,
    Lib,
    Obj,
};

/// This data structure is used by the Zig language code generation and
/// therefore must be kept in sync with the compiler implementation.
pub const LinkType = enum {
    Static,
    Dynamic,
};

/// This data structure is used by the Zig language code generation and
/// therefore must be kept in sync with the compiler implementation.
pub const Version = struct {
    major: u32,
    minor: u32,
    patch: u32,
};

/// This function type is used by the Zig language code generation and
/// therefore must be kept in sync with the compiler implementation.
pub const PanicFn = fn ([]const u8, ?*StackTrace) noreturn;

/// This function is used by the Zig language code generation and
/// therefore must be kept in sync with the compiler implementation.
pub const panic: PanicFn = if (@hasDecl(root, "panic")) root.panic else default_panic;

/// This function is used by the Zig language code generation and
/// therefore must be kept in sync with the compiler implementation.
pub fn default_panic(msg: []const u8, error_return_trace: ?*StackTrace) noreturn {
    @setCold(true);
    switch (os) {
        .freestanding => {
            while (true) {
                @breakpoint();
            }
        },
        .wasi => {
            std.debug.warn("{}", msg);
            _ = std.os.wasi.proc_raise(std.os.wasi.SIGABRT);
            unreachable;
        },
        .uefi => {
            // TODO look into using the debug info and logging helpful messages
            std.os.abort();
        },
        else => {
            const first_trace_addr = @returnAddress();
            std.debug.panicExtra(error_return_trace, first_trace_addr, "{}", msg);
        },
    }
}

const std = @import("std.zig");
const root = @import("root");
