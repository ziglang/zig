//! Zig Compilation Unit
//!
//! Compilation of all Zig source code is represented by one `Zcu`.
//!
//! Each `Compilation` has exactly one or zero `Zcu`, depending on whether
//! there is or is not any zig source code, respectively.

const std = @import("std");
const builtin = @import("builtin");
const mem = std.mem;
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const log = std.log.scoped(.zcu);
const BigIntConst = std.math.big.int.Const;
const BigIntMutable = std.math.big.int.Mutable;
const Target = std.Target;
const Ast = std.zig.Ast;

const Zcu = @This();
const Compilation = @import("Compilation.zig");
const Cache = std.Build.Cache;
pub const Value = @import("Value.zig");
pub const Type = @import("Type.zig");
const Package = @import("Package.zig");
const link = @import("link.zig");
const Air = @import("Air.zig");
const Zir = std.zig.Zir;
const trace = @import("tracy.zig").trace;
const AstGen = std.zig.AstGen;
const Sema = @import("Sema.zig");
const target_util = @import("target.zig");
const build_options = @import("build_options");
const Liveness = @import("Liveness.zig");
const isUpDir = @import("introspect.zig").isUpDir;
const clang = @import("clang.zig");
const InternPool = @import("InternPool.zig");
const Alignment = InternPool.Alignment;
const AnalUnit = InternPool.AnalUnit;
const BuiltinFn = std.zig.BuiltinFn;
const LlvmObject = @import("codegen/llvm.zig").Object;
const dev = @import("dev.zig");
const Zoir = std.zig.Zoir;
const ZonGen = std.zig.ZonGen;

comptime {
    @setEvalBranchQuota(4000);
    for (
        @typeInfo(Zir.Inst.Ref).@"enum".fields,
        @typeInfo(Air.Inst.Ref).@"enum".fields,
        @typeInfo(InternPool.Index).@"enum".fields,
    ) |zir_field, air_field, ip_field| {
        assert(mem.eql(u8, zir_field.name, ip_field.name));
        assert(mem.eql(u8, air_field.name, ip_field.name));
    }
}

/// General-purpose allocator. Used for both temporary and long-term storage.
gpa: Allocator,
comp: *Compilation,
/// Usually, the LlvmObject is managed by linker code, however, in the case
/// that -fno-emit-bin is specified, the linker code never executes, so we
/// store the LlvmObject here.
llvm_object: ?LlvmObject.Ptr,

/// Pointer to externally managed resource.
root_mod: *Package.Module,
/// Normally, `main_mod` and `root_mod` are the same. The exception is `zig test`, in which
/// `root_mod` is the test runner, and `main_mod` is the user's source file which has the tests.
main_mod: *Package.Module,
std_mod: *Package.Module,
sema_prog_node: std.Progress.Node = std.Progress.Node.none,
codegen_prog_node: std.Progress.Node = std.Progress.Node.none,

/// Used by AstGen worker to load and store ZIR cache.
global_zir_cache: Compilation.Directory,
/// Used by AstGen worker to load and store ZIR cache.
local_zir_cache: Compilation.Directory,

/// This is where all `Export` values are stored. Not all values here are necessarily valid exports;
/// to enumerate all exports, `single_exports` and `multi_exports` must be consulted.
all_exports: std.ArrayListUnmanaged(Export) = .empty,
/// This is a list of free indices in `all_exports`. These indices may be reused by exports from
/// future semantic analysis.
free_exports: std.ArrayListUnmanaged(Export.Index) = .empty,
/// Maps from an `AnalUnit` which performs a single export, to the index into `all_exports` of
/// the export it performs. Note that the key is not the `Decl` being exported, but the `AnalUnit`
/// whose analysis triggered the export.
single_exports: std.AutoArrayHashMapUnmanaged(AnalUnit, Export.Index) = .empty,
/// Like `single_exports`, but for `AnalUnit`s which perform multiple exports.
/// The exports are `all_exports.items[index..][0..len]`.
multi_exports: std.AutoArrayHashMapUnmanaged(AnalUnit, extern struct {
    index: u32,
    len: u32,
}) = .{},

/// The set of all the Zig source files in the Zig Compilation Unit. Tracked in
/// order to iterate over it and check which source files have been modified on
/// the file system when an update is requested, as well as to cache `@import`
/// results.
///
/// Keys are fully resolved file paths. This table owns the keys and values.
///
/// Protected by Compilation's mutex.
///
/// Not serialized. This state is reconstructed during the first call to
/// `Compilation.update` of the process for a given `Compilation`.
///
/// Indexes correspond 1:1 to `files`.
import_table: std.StringArrayHashMapUnmanaged(File.Index) = .empty,

/// The set of all the files which have been loaded with `@embedFile` in the Module.
/// We keep track of this in order to iterate over it and check which files have been
/// modified on the file system when an update is requested, as well as to cache
/// `@embedFile` results.
/// Keys are fully resolved file paths. This table owns the keys and values.
embed_table: std.StringArrayHashMapUnmanaged(*EmbedFile) = .empty,

/// Stores all Type and Value objects.
/// The idea is that this will be periodically garbage-collected, but such logic
/// is not yet implemented.
intern_pool: InternPool = .empty,

analysis_in_progress: std.AutoArrayHashMapUnmanaged(AnalUnit, void) = .empty,
/// The ErrorMsg memory is owned by the `AnalUnit`, using Module's general purpose allocator.
failed_analysis: std.AutoArrayHashMapUnmanaged(AnalUnit, *ErrorMsg) = .empty,
/// This `AnalUnit` failed semantic analysis because it required analysis of another `AnalUnit` which itself failed.
transitive_failed_analysis: std.AutoArrayHashMapUnmanaged(AnalUnit, void) = .empty,
/// This `Nav` succeeded analysis, but failed codegen.
/// This may be a simple "value" `Nav`, or it may be a function.
/// The ErrorMsg memory is owned by the `AnalUnit`, using Module's general purpose allocator.
failed_codegen: std.AutoArrayHashMapUnmanaged(InternPool.Nav.Index, *ErrorMsg) = .empty,
failed_types: std.AutoArrayHashMapUnmanaged(InternPool.Index, *ErrorMsg) = .empty,
/// Keep track of one `@compileLog` callsite per `AnalUnit`.
/// The value is the source location of the `@compileLog` call, convertible to a `LazySrcLoc`.
compile_log_sources: std.AutoArrayHashMapUnmanaged(AnalUnit, extern struct {
    base_node_inst: InternPool.TrackedInst.Index,
    node_offset: i32,
    pub fn src(self: @This()) LazySrcLoc {
        return .{
            .base_node_inst = self.base_node_inst,
            .offset = LazySrcLoc.Offset.nodeOffset(self.node_offset),
        };
    }
}) = .{},
/// Using a map here for consistency with the other fields here.
/// The ErrorMsg memory is owned by the `File`, using Module's general purpose allocator.
failed_files: std.AutoArrayHashMapUnmanaged(*File, ?*ErrorMsg) = .empty,
failed_exports: std.AutoArrayHashMapUnmanaged(Export.Index, *ErrorMsg) = .empty,
/// If analysis failed due to a cimport error, the corresponding Clang errors
/// are stored here.
cimport_errors: std.AutoArrayHashMapUnmanaged(AnalUnit, std.zig.ErrorBundle) = .empty,

/// Maximum amount of distinct error values, set by --error-limit
error_limit: ErrorInt,

/// Value is the number of PO dependencies of this AnalUnit.
/// This value will decrease as we perform semantic analysis to learn what is outdated.
/// If any of these PO deps is outdated, this value will be moved to `outdated`.
potentially_outdated: std.AutoArrayHashMapUnmanaged(AnalUnit, u32) = .empty,
/// Value is the number of PO dependencies of this AnalUnit.
/// Once this value drops to 0, the AnalUnit is a candidate for re-analysis.
outdated: std.AutoArrayHashMapUnmanaged(AnalUnit, u32) = .empty,
/// This contains all `AnalUnit`s in `outdated` whose PO dependency count is 0.
/// Such `AnalUnit`s are ready for immediate re-analysis.
/// See `findOutdatedToAnalyze` for details.
outdated_ready: std.AutoArrayHashMapUnmanaged(AnalUnit, void) = .empty,
/// This contains a list of AnalUnit whose analysis or codegen failed, but the
/// failure was something like running out of disk space, and trying again may
/// succeed. On the next update, we will flush this list, marking all members of
/// it as outdated.
retryable_failures: std.ArrayListUnmanaged(AnalUnit) = .empty,

func_body_analysis_queued: std.AutoArrayHashMapUnmanaged(InternPool.Index, void) = .empty,
nav_val_analysis_queued: std.AutoArrayHashMapUnmanaged(InternPool.Nav.Index, void) = .empty,

/// These are the modules which we initially queue for analysis in `Compilation.update`.
/// `resolveReferences` will use these as the root of its reachability traversal.
analysis_roots: std.BoundedArray(*Package.Module, 3) = .{},
/// This is the cached result of `Zcu.resolveReferences`. It is computed on-demand, and
/// reset to `null` when any semantic analysis occurs (since this invalidates the data).
/// Allocated into `gpa`.
resolved_references: ?std.AutoHashMapUnmanaged(AnalUnit, ?ResolvedReference) = null,

skip_analysis_errors: bool = false,

stage1_flags: packed struct {
    have_winmain: bool = false,
    have_wwinmain: bool = false,
    have_winmain_crt_startup: bool = false,
    have_wwinmain_crt_startup: bool = false,
    have_dllmain_crt_startup: bool = false,
    have_c_main: bool = false,
    reserved: u2 = 0,
} = .{},

compile_log_text: std.ArrayListUnmanaged(u8) = .empty,

test_functions: std.AutoArrayHashMapUnmanaged(InternPool.Nav.Index, void) = .empty,

global_assembly: std.AutoArrayHashMapUnmanaged(AnalUnit, []u8) = .empty,

/// Key is the `AnalUnit` *performing* the reference. This representation allows
/// incremental updates to quickly delete references caused by a specific `AnalUnit`.
/// Value is index into `all_references` of the first reference triggered by the unit.
/// The `next` field on the `Reference` forms a linked list of all references
/// triggered by the key `AnalUnit`.
reference_table: std.AutoArrayHashMapUnmanaged(AnalUnit, u32) = .empty,
all_references: std.ArrayListUnmanaged(Reference) = .empty,
/// Freelist of indices in `all_references`.
free_references: std.ArrayListUnmanaged(u32) = .empty,

/// Key is the `AnalUnit` *performing* the reference. This representation allows
/// incremental updates to quickly delete references caused by a specific `AnalUnit`.
/// Value is index into `all_type_reference` of the first reference triggered by the unit.
/// The `next` field on the `TypeReference` forms a linked list of all type references
/// triggered by the key `AnalUnit`.
type_reference_table: std.AutoArrayHashMapUnmanaged(AnalUnit, u32) = .empty,
all_type_references: std.ArrayListUnmanaged(TypeReference) = .empty,
/// Freelist of indices in `all_type_references`.
free_type_references: std.ArrayListUnmanaged(u32) = .empty,

/// Populated by analysis of `AnalUnit.wrap(.{ .memoized_state = s })`, where `s` depends on the element.
builtin_decl_values: BuiltinDecl.Memoized = .initFill(.none),

generation: u32 = 0,

pub const PerThread = @import("Zcu/PerThread.zig");

/// Names of declarations in `std.builtin` whose values are memoized in a `BuiltinDecl.Memoized`.
/// The name must exactly match the declaration name, as comptime logic is used to compute the namespace accesses.
/// Parent namespaces must be before their children in this enum. For instance, `.Type` must be before `.@"Type.Fn"`.
/// Additionally, parent namespaces must be resolved in the same stage as their children; see `BuiltinDecl.stage`.
pub const BuiltinDecl = enum {
    Signedness,
    AddressSpace,
    CallingConvention,
    returnError,
    StackTrace,
    SourceLocation,
    CallModifier,
    AtomicOrder,
    AtomicRmwOp,
    ReduceOp,
    FloatMode,
    PrefetchOptions,
    ExportOptions,
    ExternOptions,
    BranchHint,

    Type,
    @"Type.Fn",
    @"Type.Fn.Param",
    @"Type.Int",
    @"Type.Float",
    @"Type.Pointer",
    @"Type.Pointer.Size",
    @"Type.Array",
    @"Type.Vector",
    @"Type.Optional",
    @"Type.Error",
    @"Type.ErrorUnion",
    @"Type.EnumField",
    @"Type.Enum",
    @"Type.Union",
    @"Type.UnionField",
    @"Type.Struct",
    @"Type.StructField",
    @"Type.ContainerLayout",
    @"Type.Opaque",
    @"Type.Declaration",

    panic,
    @"panic.call",
    @"panic.sentinelMismatch",
    @"panic.unwrapError",
    @"panic.outOfBounds",
    @"panic.startGreaterThanEnd",
    @"panic.inactiveUnionField",
    @"panic.reachedUnreachable",
    @"panic.unwrapNull",
    @"panic.castToNull",
    @"panic.incorrectAlignment",
    @"panic.invalidErrorCode",
    @"panic.castTruncatedData",
    @"panic.negativeToUnsigned",
    @"panic.integerOverflow",
    @"panic.shlOverflow",
    @"panic.shrOverflow",
    @"panic.divideByZero",
    @"panic.exactDivisionRemainder",
    @"panic.integerPartOutOfBounds",
    @"panic.corruptSwitch",
    @"panic.shiftRhsTooBig",
    @"panic.invalidEnumValue",
    @"panic.forLenMismatch",
    @"panic.memcpyLenMismatch",
    @"panic.memcpyAlias",
    @"panic.noreturnReturned",

    VaList,

    /// Determines what kind of validation will be done to the decl's value.
    pub fn kind(decl: BuiltinDecl) enum { type, func, string } {
        return switch (decl) {
            .returnError => .func,

            .StackTrace,
            .CallingConvention,
            .SourceLocation,
            .Signedness,
            .AddressSpace,
            .VaList,
            .CallModifier,
            .AtomicOrder,
            .AtomicRmwOp,
            .ReduceOp,
            .FloatMode,
            .PrefetchOptions,
            .ExportOptions,
            .ExternOptions,
            .BranchHint,
            => .type,

            .Type,
            .@"Type.Fn",
            .@"Type.Fn.Param",
            .@"Type.Int",
            .@"Type.Float",
            .@"Type.Pointer",
            .@"Type.Pointer.Size",
            .@"Type.Array",
            .@"Type.Vector",
            .@"Type.Optional",
            .@"Type.Error",
            .@"Type.ErrorUnion",
            .@"Type.EnumField",
            .@"Type.Enum",
            .@"Type.Union",
            .@"Type.UnionField",
            .@"Type.Struct",
            .@"Type.StructField",
            .@"Type.ContainerLayout",
            .@"Type.Opaque",
            .@"Type.Declaration",
            => .type,

            .panic => .type,

            .@"panic.call",
            .@"panic.sentinelMismatch",
            .@"panic.unwrapError",
            .@"panic.outOfBounds",
            .@"panic.startGreaterThanEnd",
            .@"panic.inactiveUnionField",
            .@"panic.reachedUnreachable",
            .@"panic.unwrapNull",
            .@"panic.castToNull",
            .@"panic.incorrectAlignment",
            .@"panic.invalidErrorCode",
            .@"panic.castTruncatedData",
            .@"panic.negativeToUnsigned",
            .@"panic.integerOverflow",
            .@"panic.shlOverflow",
            .@"panic.shrOverflow",
            .@"panic.divideByZero",
            .@"panic.exactDivisionRemainder",
            .@"panic.integerPartOutOfBounds",
            .@"panic.corruptSwitch",
            .@"panic.shiftRhsTooBig",
            .@"panic.invalidEnumValue",
            .@"panic.forLenMismatch",
            .@"panic.memcpyLenMismatch",
            .@"panic.memcpyAlias",
            .@"panic.noreturnReturned",
            => .func,
        };
    }

    /// Resolution of these values is done in three distinct stages:
    /// * Resolution of `std.builtin.Panic` and everything under it
    /// * Resolution of `VaList`
    /// * Everything else
    ///
    /// Panics are separated because they are provided by the user, so must be able to use
    /// things like reification.
    ///
    /// `VaList` is separate because its value depends on the target, so it needs some reflection
    /// machinery to work; additionally, it is `@compileError` on some targets, so must be referenced
    /// by itself.
    pub fn stage(decl: BuiltinDecl) InternPool.MemoizedStateStage {
        if (decl == .VaList) return .va_list;

        if (@intFromEnum(decl) <= @intFromEnum(BuiltinDecl.@"Type.Declaration")) {
            return .main;
        } else {
            return .panic;
        }
    }

    /// Based on the tag name, determines how to access this decl; either as a direct child of the
    /// `std.builtin` namespace, or as a child of some preceding `BuiltinDecl` value.
    pub fn access(decl: BuiltinDecl) union(enum) {
        direct: []const u8,
        nested: struct { BuiltinDecl, []const u8 },
    } {
        @setEvalBranchQuota(2000);
        return switch (decl) {
            inline else => |tag| {
                const name = @tagName(tag);
                const split = (comptime std.mem.lastIndexOfScalar(u8, name, '.')) orelse return .{ .direct = name };
                const parent = @field(BuiltinDecl, name[0..split]);
                comptime assert(@intFromEnum(parent) < @intFromEnum(tag)); // dependencies ordered correctly
                return .{ .nested = .{ parent, name[split + 1 ..] } };
            },
        };
    }

    const Memoized = std.enums.EnumArray(BuiltinDecl, InternPool.Index);
};

pub const SimplePanicId = enum {
    reached_unreachable,
    unwrap_null,
    cast_to_null,
    incorrect_alignment,
    invalid_error_code,
    cast_truncated_data,
    negative_to_unsigned,
    integer_overflow,
    shl_overflow,
    shr_overflow,
    divide_by_zero,
    exact_division_remainder,
    integer_part_out_of_bounds,
    corrupt_switch,
    shift_rhs_too_big,
    invalid_enum_value,
    for_len_mismatch,
    memcpy_len_mismatch,
    memcpy_alias,
    noreturn_returned,

    pub fn toBuiltin(id: SimplePanicId) BuiltinDecl {
        return switch (id) {
            // zig fmt: off
            .reached_unreachable        => .@"panic.reachedUnreachable",
            .unwrap_null                => .@"panic.unwrapNull",
            .cast_to_null               => .@"panic.castToNull",
            .incorrect_alignment        => .@"panic.incorrectAlignment",
            .invalid_error_code         => .@"panic.invalidErrorCode",
            .cast_truncated_data        => .@"panic.castTruncatedData",
            .negative_to_unsigned       => .@"panic.negativeToUnsigned",
            .integer_overflow           => .@"panic.integerOverflow",
            .shl_overflow               => .@"panic.shlOverflow",
            .shr_overflow               => .@"panic.shrOverflow",
            .divide_by_zero             => .@"panic.divideByZero",
            .exact_division_remainder   => .@"panic.exactDivisionRemainder",
            .integer_part_out_of_bounds => .@"panic.integerPartOutOfBounds",
            .corrupt_switch             => .@"panic.corruptSwitch",
            .shift_rhs_too_big          => .@"panic.shiftRhsTooBig",
            .invalid_enum_value         => .@"panic.invalidEnumValue",
            .for_len_mismatch           => .@"panic.forLenMismatch",
            .memcpy_len_mismatch        => .@"panic.memcpyLenMismatch",
            .memcpy_alias               => .@"panic.memcpyAlias",
            .noreturn_returned          => .@"panic.noreturnReturned",
            // zig fmt: on
        };
    }
};

pub const GlobalErrorSet = std.AutoArrayHashMapUnmanaged(InternPool.NullTerminatedString, void);

pub const CImportError = struct {
    offset: u32,
    line: u32,
    column: u32,
    path: ?[*:0]u8,
    source_line: ?[*:0]u8,
    msg: [*:0]u8,

    pub fn deinit(err: CImportError, gpa: Allocator) void {
        if (err.path) |some| gpa.free(std.mem.span(some));
        if (err.source_line) |some| gpa.free(std.mem.span(some));
        gpa.free(std.mem.span(err.msg));
    }
};

pub const ErrorInt = u32;

pub const Exported = union(enum) {
    /// The Nav being exported. Note this is *not* the Nav corresponding to the AnalUnit performing the export.
    nav: InternPool.Nav.Index,
    /// Constant value being exported.
    uav: InternPool.Index,

    pub fn getValue(exported: Exported, zcu: *Zcu) Value {
        return switch (exported) {
            .nav => |nav| zcu.navValue(nav),
            .uav => |uav| Value.fromInterned(uav),
        };
    }

    pub fn getAlign(exported: Exported, zcu: *Zcu) Alignment {
        return switch (exported) {
            .nav => |nav| switch (zcu.intern_pool.getNav(nav).status) {
                .unresolved => unreachable,
                .type_resolved => |r| r.alignment,
                .fully_resolved => |r| r.alignment,
            },
            .uav => .none,
        };
    }
};

pub const Export = struct {
    opts: Options,
    src: LazySrcLoc,
    exported: Exported,
    status: enum {
        in_progress,
        failed,
        /// Indicates that the failure was due to a temporary issue, such as an I/O error
        /// when writing to the output file. Retrying the export may succeed.
        failed_retryable,
        complete,
    },

    pub const Options = struct {
        name: InternPool.NullTerminatedString,
        linkage: std.builtin.GlobalLinkage = .strong,
        section: InternPool.OptionalNullTerminatedString = .none,
        visibility: std.builtin.SymbolVisibility = .default,
    };

    /// Index into `all_exports`.
    pub const Index = enum(u32) {
        _,

        pub fn ptr(i: Index, zcu: *const Zcu) *Export {
            return &zcu.all_exports.items[@intFromEnum(i)];
        }
    };
};

pub const Reference = struct {
    /// The `AnalUnit` whose semantic analysis was triggered by this reference.
    referenced: AnalUnit,
    /// Index into `all_references` of the next `Reference` triggered by the same `AnalUnit`.
    /// `std.math.maxInt(u32)` is the sentinel.
    next: u32,
    /// The source location of the reference.
    src: LazySrcLoc,
};

pub const TypeReference = struct {
    /// The container type which was referenced.
    referenced: InternPool.Index,
    /// Index into `all_type_references` of the next `TypeReference` triggered by the same `AnalUnit`.
    /// `std.math.maxInt(u32)` is the sentinel.
    next: u32,
    /// The source location of the reference.
    src: LazySrcLoc,
};

/// The container that structs, enums, unions, and opaques have.
pub const Namespace = struct {
    parent: OptionalIndex,
    file_scope: File.Index,
    generation: u32,
    /// Will be a struct, enum, union, or opaque.
    owner_type: InternPool.Index,
    /// Members of the namespace which are marked `pub`.
    pub_decls: std.ArrayHashMapUnmanaged(InternPool.Nav.Index, void, NavNameContext, true) = .empty,
    /// Members of the namespace which are *not* marked `pub`.
    priv_decls: std.ArrayHashMapUnmanaged(InternPool.Nav.Index, void, NavNameContext, true) = .empty,
    /// All `usingnamespace` declarations in this namespace which are marked `pub`.
    pub_usingnamespace: std.ArrayListUnmanaged(InternPool.Nav.Index) = .empty,
    /// All `usingnamespace` declarations in this namespace which are *not* marked `pub`.
    priv_usingnamespace: std.ArrayListUnmanaged(InternPool.Nav.Index) = .empty,
    /// All `comptime` declarations in this namespace. We store these purely so that incremental
    /// compilation can re-use the existing `ComptimeUnit`s when a namespace changes.
    comptime_decls: std.ArrayListUnmanaged(InternPool.ComptimeUnit.Id) = .empty,
    /// All `test` declarations in this namespace. We store these purely so that incremental
    /// compilation can re-use the existing `Nav`s when a namespace changes.
    test_decls: std.ArrayListUnmanaged(InternPool.Nav.Index) = .empty,

    pub const Index = InternPool.NamespaceIndex;
    pub const OptionalIndex = InternPool.OptionalNamespaceIndex;

    const NavNameContext = struct {
        zcu: *Zcu,

        pub fn hash(ctx: NavNameContext, nav: InternPool.Nav.Index) u32 {
            const name = ctx.zcu.intern_pool.getNav(nav).name;
            return std.hash.uint32(@intFromEnum(name));
        }

        pub fn eql(ctx: NavNameContext, a_nav: InternPool.Nav.Index, b_nav: InternPool.Nav.Index, b_index: usize) bool {
            _ = b_index;
            const a_name = ctx.zcu.intern_pool.getNav(a_nav).name;
            const b_name = ctx.zcu.intern_pool.getNav(b_nav).name;
            return a_name == b_name;
        }
    };

    pub const NameAdapter = struct {
        zcu: *Zcu,

        pub fn hash(ctx: NameAdapter, s: InternPool.NullTerminatedString) u32 {
            _ = ctx;
            return std.hash.uint32(@intFromEnum(s));
        }

        pub fn eql(ctx: NameAdapter, a: InternPool.NullTerminatedString, b_nav: InternPool.Nav.Index, b_index: usize) bool {
            _ = b_index;
            return a == ctx.zcu.intern_pool.getNav(b_nav).name;
        }
    };

    pub fn fileScope(ns: Namespace, zcu: *Zcu) *File {
        return zcu.fileByIndex(ns.file_scope);
    }

    pub fn fileScopeIp(ns: Namespace, ip: *InternPool) *File {
        return ip.filePtr(ns.file_scope);
    }

    /// This renders e.g. "std/fs.zig:Dir.OpenOptions"
    pub fn renderFullyQualifiedDebugName(
        ns: Namespace,
        zcu: *Zcu,
        name: InternPool.NullTerminatedString,
        writer: anytype,
    ) @TypeOf(writer).Error!void {
        const sep: u8 = if (ns.parent.unwrap()) |parent| sep: {
            try zcu.namespacePtr(parent).renderFullyQualifiedDebugName(
                zcu,
                zcu.declPtr(ns.decl_index).name,
                writer,
            );
            break :sep '.';
        } else sep: {
            try ns.fileScope(zcu).renderFullyQualifiedDebugName(writer);
            break :sep ':';
        };
        if (name != .empty) try writer.print("{c}{}", .{ sep, name.fmt(&zcu.intern_pool) });
    }

    pub fn internFullyQualifiedName(
        ns: Namespace,
        ip: *InternPool,
        gpa: Allocator,
        tid: Zcu.PerThread.Id,
        name: InternPool.NullTerminatedString,
    ) !InternPool.NullTerminatedString {
        const ns_name = Type.fromInterned(ns.owner_type).containerTypeName(ip);
        if (name == .empty) return ns_name;
        return ip.getOrPutStringFmt(gpa, tid, "{}.{}", .{ ns_name.fmt(ip), name.fmt(ip) }, .no_embedded_nulls);
    }
};

pub const File = struct {
    /// Relative to the owning package's root source directory.
    /// Memory is stored in gpa, owned by File.
    sub_file_path: []const u8,

    status: enum {
        /// We have not yet attempted to load this file.
        /// `stat` is not populated and may be `undefined`.
        never_loaded,
        /// A filesystem access failed. It should be retried on the next update.
        /// There is a `failed_files` entry containing a non-`null` message.
        /// `stat` is not populated and may be `undefined`.
        retryable_failure,
        /// Parsing/AstGen/ZonGen of this file has failed.
        /// There is an error in `zir` or `zoir`.
        /// There is a `failed_files` entry (with a `null` message).
        /// `stat` is populated.
        astgen_failure,
        /// Parsing and AstGen/ZonGen of this file has succeeded.
        /// `stat` is populated.
        success,
    },
    /// Whether this is populated depends on `status`.
    stat: Cache.File.Stat,

    source: ?[:0]const u8,
    tree: ?Ast,
    zir: ?Zir,
    zoir: ?Zoir,

    /// Module that this file is a part of, managed externally.
    mod: *Package.Module,
    /// Whether this file is a part of multiple packages. This is an error condition which will be reported after AstGen.
    multi_pkg: bool = false,
    /// List of references to this file, used for multi-package errors.
    references: std.ArrayListUnmanaged(File.Reference) = .empty,

    /// The ZIR for this file from the last update with no file failures. As such, this ZIR is never
    /// failed (although it may have compile errors).
    ///
    /// Because updates with file failures do not perform ZIR mapping or semantic analysis, we keep
    /// this around so we have the "old" ZIR to map when an update is ready to do so. Once such an
    /// update occurs, this field is unloaded, since it is no longer necessary.
    ///
    /// In other words, if `TrackedInst`s are tied to ZIR other than what's in the `zir` field, this
    /// field is populated with that old ZIR.
    prev_zir: ?*Zir = null,

    /// This field serves a similar purpose to `prev_zir`, but for ZOIR. However, since we do not
    /// need to map old ZOIR to new ZOIR -- instead only invalidating dependencies if the ZOIR
    /// changed -- this field is just a simple boolean.
    ///
    /// When `zoir` is updated, this field is set to `true`. In `updateZirRefs`, if this is `true`,
    /// we invalidate the corresponding `zon_file` dependency, and reset it to `false`.
    zoir_invalidated: bool = false,

    /// A single reference to a file.
    pub const Reference = union(enum) {
        /// The file is imported directly (i.e. not as a package) with @import.
        import: struct {
            file: File.Index,
            token: Ast.TokenIndex,
        },
        /// The file is the root of a module.
        root: *Package.Module,
    };

    pub fn getMode(self: File) Ast.Mode {
        if (std.mem.endsWith(u8, self.sub_file_path, ".zon")) {
            return .zon;
        } else if (std.mem.endsWith(u8, self.sub_file_path, ".zig")) {
            return .zig;
        } else {
            // `Module.importFile` rejects all other extensions
            unreachable;
        }
    }

    pub fn unload(file: *File, gpa: Allocator) void {
        if (file.zoir) |zoir| zoir.deinit(gpa);
        file.unloadTree(gpa);
        file.unloadSource(gpa);
        file.unloadZir(gpa);
    }

    pub fn unloadTree(file: *File, gpa: Allocator) void {
        if (file.tree) |*tree| {
            tree.deinit(gpa);
            file.tree = null;
        }
    }

    pub fn unloadSource(file: *File, gpa: Allocator) void {
        if (file.source) |source| {
            gpa.free(source);
            file.source = null;
        }
    }

    pub fn unloadZir(file: *File, gpa: Allocator) void {
        if (file.zir) |*zir| {
            zir.deinit(gpa);
            file.zir = null;
        }
    }

    pub const Source = struct {
        bytes: [:0]const u8,
        stat: Cache.File.Stat,
    };

    pub fn getSource(file: *File, gpa: Allocator) !Source {
        if (file.source) |source| return .{
            .bytes = source,
            .stat = file.stat,
        };

        // Keep track of inode, file size, mtime, hash so we can detect which files
        // have been modified when an incremental update is requested.
        var f = try file.mod.root.openFile(file.sub_file_path, .{});
        defer f.close();

        const stat = try f.stat();

        if (stat.size > std.math.maxInt(u32))
            return error.FileTooBig;

        const source = try gpa.allocSentinel(u8, @as(usize, @intCast(stat.size)), 0);
        errdefer gpa.free(source);

        const amt = try f.readAll(source);
        if (amt != stat.size)
            return error.UnexpectedEndOfFile;

        // Here we do not modify stat fields because this function is the one
        // used for error reporting. We need to keep the stat fields stale so that
        // updateFile can know to regenerate ZIR.

        file.source = source;
        errdefer comptime unreachable; // don't error after populating `source`

        return .{
            .bytes = source,
            .stat = .{
                .size = stat.size,
                .inode = stat.inode,
                .mtime = stat.mtime,
            },
        };
    }

    pub fn getTree(file: *File, gpa: Allocator) !*const Ast {
        if (file.tree) |*tree| return tree;

        const source = try file.getSource(gpa);
        file.tree = try .parse(gpa, source.bytes, file.getMode());
        return &file.tree.?;
    }

    pub fn getZoir(file: *File, zcu: *Zcu) !*const Zoir {
        if (file.zoir) |*zoir| return zoir;

        const tree = file.tree.?;
        assert(tree.mode == .zon);

        file.zoir = try ZonGen.generate(zcu.gpa, tree, .{});
        if (file.zoir.?.hasCompileErrors()) {
            try zcu.failed_files.putNoClobber(zcu.gpa, file, null);
            return error.AnalysisFail;
        }
        return &file.zoir.?;
    }

    pub fn fullyQualifiedNameLen(file: File) usize {
        const ext = std.fs.path.extension(file.sub_file_path);
        return file.sub_file_path.len - ext.len;
    }

    pub fn renderFullyQualifiedName(file: File, writer: anytype) !void {
        // Convert all the slashes into dots and truncate the extension.
        const ext = std.fs.path.extension(file.sub_file_path);
        const noext = file.sub_file_path[0 .. file.sub_file_path.len - ext.len];
        for (noext) |byte| switch (byte) {
            '/', '\\' => try writer.writeByte('.'),
            else => try writer.writeByte(byte),
        };
    }

    pub fn renderFullyQualifiedDebugName(file: File, writer: anytype) !void {
        for (file.sub_file_path) |byte| switch (byte) {
            '/', '\\' => try writer.writeByte('/'),
            else => try writer.writeByte(byte),
        };
    }

    pub fn internFullyQualifiedName(file: File, pt: Zcu.PerThread) !InternPool.NullTerminatedString {
        const gpa = pt.zcu.gpa;
        const ip = &pt.zcu.intern_pool;
        const strings = ip.getLocal(pt.tid).getMutableStrings(gpa);
        const slice = try strings.addManyAsSlice(file.fullyQualifiedNameLen());
        var fbs = std.io.fixedBufferStream(slice[0]);
        file.renderFullyQualifiedName(fbs.writer()) catch unreachable;
        assert(fbs.pos == slice[0].len);
        return ip.getOrPutTrailingString(gpa, pt.tid, @intCast(slice[0].len), .no_embedded_nulls);
    }

    pub fn fullPath(file: File, ally: Allocator) ![]u8 {
        return file.mod.root.joinString(ally, file.sub_file_path);
    }

    pub fn dumpSrc(file: *File, src: LazySrcLoc) void {
        const loc = std.zig.findLineColumn(file.source.bytes, src);
        std.debug.print("{s}:{d}:{d}\n", .{ file.sub_file_path, loc.line + 1, loc.column + 1 });
    }

    /// Add a reference to this file during AstGen.
    pub fn addReference(file: *File, zcu: *Zcu, ref: File.Reference) !void {
        // Don't add the same module root twice. Note that since we always add module roots at the
        // front of the references array (see below), this loop is actually O(1) on valid code.
        if (ref == .root) {
            for (file.references.items) |other| {
                switch (other) {
                    .root => |r| if (ref.root == r) return,
                    else => break, // reached the end of the "is-root" references
                }
            }
        }

        switch (ref) {
            // We put root references at the front of the list both to make the above loop fast and
            // to make multi-module errors more helpful (since "root-of" notes are generally more
            // informative than "imported-from" notes). This path is hit very rarely, so the speed
            // of the insert operation doesn't matter too much.
            .root => try file.references.insert(zcu.gpa, 0, ref),

            // Other references we'll just put at the end.
            else => try file.references.append(zcu.gpa, ref),
        }

        const mod = switch (ref) {
            .import => |import| zcu.fileByIndex(import.file).mod,
            .root => |mod| mod,
        };
        if (mod != file.mod) file.multi_pkg = true;
    }

    /// Mark this file and every file referenced by it as multi_pkg and report an
    /// astgen_failure error for them. AstGen must have completed in its entirety.
    pub fn recursiveMarkMultiPkg(file: *File, pt: Zcu.PerThread) void {
        file.multi_pkg = true;
        file.status = .astgen_failure;

        // We can only mark children as failed if the ZIR is loaded, which may not
        // be the case if there were other astgen failures in this file
        if (file.zir == null) return;

        const imports_index = file.zir.?.extra[@intFromEnum(Zir.ExtraIndex.imports)];
        if (imports_index == 0) return;
        const extra = file.zir.?.extraData(Zir.Inst.Imports, imports_index);

        var extra_index = extra.end;
        for (0..extra.data.imports_len) |_| {
            const item = file.zir.?.extraData(Zir.Inst.Imports.Item, extra_index);
            extra_index = item.end;

            const import_path = file.zir.?.nullTerminatedString(item.data.name);
            if (mem.eql(u8, import_path, "builtin")) continue;

            const res = pt.importFile(file, import_path) catch continue;
            if (!res.is_pkg and !res.file.multi_pkg) {
                res.file.recursiveMarkMultiPkg(pt);
            }
        }
    }

    pub const Index = InternPool.FileIndex;
};

/// Represents the contents of a file loaded with `@embedFile`.
pub const EmbedFile = struct {
    /// Module that this file is a part of, managed externally.
    owner: *Package.Module,
    /// Relative to the owning module's root directory.
    sub_file_path: InternPool.NullTerminatedString,

    /// `.none` means the file was not loaded, so `stat` is undefined.
    val: InternPool.Index,
    /// If this is `null` and `val` is `.none`, the file has never been loaded.
    err: ?(std.fs.File.OpenError || std.fs.File.StatError || std.fs.File.ReadError || error{UnexpectedEof}),
    stat: Cache.File.Stat,

    pub const Index = enum(u32) {
        _,
        pub fn get(idx: Index, zcu: *const Zcu) *EmbedFile {
            return zcu.embed_table.values()[@intFromEnum(idx)];
        }
    };
};

/// This struct holds data necessary to construct API-facing `AllErrors.Message`.
/// Its memory is managed with the general purpose allocator so that they
/// can be created and destroyed in response to incremental updates.
pub const ErrorMsg = struct {
    src_loc: LazySrcLoc,
    msg: []const u8,
    notes: []ErrorMsg = &.{},
    reference_trace_root: AnalUnit.Optional = .none,

    pub fn create(
        gpa: Allocator,
        src_loc: LazySrcLoc,
        comptime format: []const u8,
        args: anytype,
    ) !*ErrorMsg {
        assert(src_loc.offset != .unneeded);
        const err_msg = try gpa.create(ErrorMsg);
        errdefer gpa.destroy(err_msg);
        err_msg.* = try ErrorMsg.init(gpa, src_loc, format, args);
        return err_msg;
    }

    /// Assumes the ErrorMsg struct and msg were both allocated with `gpa`,
    /// as well as all notes.
    pub fn destroy(err_msg: *ErrorMsg, gpa: Allocator) void {
        err_msg.deinit(gpa);
        gpa.destroy(err_msg);
    }

    pub fn init(
        gpa: Allocator,
        src_loc: LazySrcLoc,
        comptime format: []const u8,
        args: anytype,
    ) !ErrorMsg {
        return ErrorMsg{
            .src_loc = src_loc,
            .msg = try std.fmt.allocPrint(gpa, format, args),
        };
    }

    pub fn deinit(err_msg: *ErrorMsg, gpa: Allocator) void {
        for (err_msg.notes) |*note| {
            note.deinit(gpa);
        }
        gpa.free(err_msg.notes);
        gpa.free(err_msg.msg);
        err_msg.* = undefined;
    }
};

pub const AstGenSrc = union(enum) {
    root,
    import: struct {
        importing_file: Zcu.File.Index,
        import_tok: std.zig.Ast.TokenIndex,
    },
};

/// Canonical reference to a position within a source file.
pub const SrcLoc = struct {
    file_scope: *File,
    base_node: Ast.Node.Index,
    /// Relative to `base_node`.
    lazy: LazySrcLoc.Offset,

    pub fn baseSrcToken(src_loc: SrcLoc) Ast.TokenIndex {
        const tree = src_loc.file_scope.tree.?;
        return tree.firstToken(src_loc.base_node);
    }

    pub fn relativeToNodeIndex(src_loc: SrcLoc, offset: i32) Ast.Node.Index {
        return @bitCast(offset + @as(i32, @bitCast(src_loc.base_node)));
    }

    pub const Span = Ast.Span;

    pub fn span(src_loc: SrcLoc, gpa: Allocator) !Span {
        switch (src_loc.lazy) {
            .unneeded => unreachable,
            .entire_file => return Span{ .start = 0, .end = 1, .main = 0 },

            .byte_abs => |byte_index| return Span{ .start = byte_index, .end = byte_index + 1, .main = byte_index },

            .token_abs => |tok_index| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const start = tree.tokens.items(.start)[tok_index];
                const end = start + @as(u32, @intCast(tree.tokenSlice(tok_index).len));
                return Span{ .start = start, .end = end, .main = start };
            },
            .node_abs => |node| {
                const tree = try src_loc.file_scope.getTree(gpa);
                return tree.nodeToSpan(node);
            },
            .byte_offset => |byte_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const tok_index = src_loc.baseSrcToken();
                const start = tree.tokens.items(.start)[tok_index] + byte_off;
                const end = start + @as(u32, @intCast(tree.tokenSlice(tok_index).len));
                return Span{ .start = start, .end = end, .main = start };
            },
            .token_offset => |tok_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const tok_index = src_loc.baseSrcToken() + tok_off;
                const start = tree.tokens.items(.start)[tok_index];
                const end = start + @as(u32, @intCast(tree.tokenSlice(tok_index).len));
                return Span{ .start = start, .end = end, .main = start };
            },
            .node_offset => |traced_off| {
                const node_off = traced_off.x;
                const tree = try src_loc.file_scope.getTree(gpa);
                const node = src_loc.relativeToNodeIndex(node_off);
                return tree.nodeToSpan(node);
            },
            .node_offset_main_token => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const node = src_loc.relativeToNodeIndex(node_off);
                const main_token = tree.nodes.items(.main_token)[node];
                return tree.tokensToSpan(main_token, main_token, main_token);
            },
            .node_offset_bin_op => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const node = src_loc.relativeToNodeIndex(node_off);
                return tree.nodeToSpan(node);
            },
            .node_offset_initializer => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const node = src_loc.relativeToNodeIndex(node_off);
                return tree.tokensToSpan(
                    tree.firstToken(node) - 3,
                    tree.lastToken(node),
                    tree.nodes.items(.main_token)[node] - 2,
                );
            },
            .node_offset_var_decl_ty => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const node = src_loc.relativeToNodeIndex(node_off);
                const node_tags = tree.nodes.items(.tag);
                const full = switch (node_tags[node]) {
                    .global_var_decl,
                    .local_var_decl,
                    .simple_var_decl,
                    .aligned_var_decl,
                    => tree.fullVarDecl(node).?,
                    .@"usingnamespace" => {
                        const node_data = tree.nodes.items(.data);
                        return tree.nodeToSpan(node_data[node].lhs);
                    },
                    else => unreachable,
                };
                if (full.ast.type_node != 0) {
                    return tree.nodeToSpan(full.ast.type_node);
                }
                const tok_index = full.ast.mut_token + 1; // the name token
                const start = tree.tokens.items(.start)[tok_index];
                const end = start + @as(u32, @intCast(tree.tokenSlice(tok_index).len));
                return Span{ .start = start, .end = end, .main = start };
            },
            .node_offset_var_decl_align => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const node = src_loc.relativeToNodeIndex(node_off);
                var buf: [1]Ast.Node.Index = undefined;
                const align_node = if (tree.fullVarDecl(node)) |v|
                    v.ast.align_node
                else if (tree.fullFnProto(&buf, node)) |f|
                    f.ast.align_expr
                else
                    unreachable;
                return tree.nodeToSpan(align_node);
            },
            .node_offset_var_decl_section => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const node = src_loc.relativeToNodeIndex(node_off);
                var buf: [1]Ast.Node.Index = undefined;
                const section_node = if (tree.fullVarDecl(node)) |v|
                    v.ast.section_node
                else if (tree.fullFnProto(&buf, node)) |f|
                    f.ast.section_expr
                else
                    unreachable;
                return tree.nodeToSpan(section_node);
            },
            .node_offset_var_decl_addrspace => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const node = src_loc.relativeToNodeIndex(node_off);
                var buf: [1]Ast.Node.Index = undefined;
                const addrspace_node = if (tree.fullVarDecl(node)) |v|
                    v.ast.addrspace_node
                else if (tree.fullFnProto(&buf, node)) |f|
                    f.ast.addrspace_expr
                else
                    unreachable;
                return tree.nodeToSpan(addrspace_node);
            },
            .node_offset_var_decl_init => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const node = src_loc.relativeToNodeIndex(node_off);
                const full = tree.fullVarDecl(node).?;
                return tree.nodeToSpan(full.ast.init_node);
            },
            .node_offset_builtin_call_arg => |builtin_arg| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const node_datas = tree.nodes.items(.data);
                const node_tags = tree.nodes.items(.tag);
                const node = src_loc.relativeToNodeIndex(builtin_arg.builtin_call_node);
                const param = switch (node_tags[node]) {
                    .builtin_call_two, .builtin_call_two_comma => switch (builtin_arg.arg_index) {
                        0 => node_datas[node].lhs,
                        1 => node_datas[node].rhs,
                        else => unreachable,
                    },
                    .builtin_call, .builtin_call_comma => tree.extra_data[node_datas[node].lhs + builtin_arg.arg_index],
                    else => unreachable,
                };
                return tree.nodeToSpan(param);
            },
            .node_offset_ptrcast_operand => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const main_tokens = tree.nodes.items(.main_token);
                const node_datas = tree.nodes.items(.data);
                const node_tags = tree.nodes.items(.tag);

                var node = src_loc.relativeToNodeIndex(node_off);
                while (true) {
                    switch (node_tags[node]) {
                        .builtin_call_two, .builtin_call_two_comma => {},
                        else => break,
                    }

                    if (node_datas[node].lhs == 0) break; // 0 args
                    if (node_datas[node].rhs != 0) break; // 2 args

                    const builtin_token = main_tokens[node];
                    const builtin_name = tree.tokenSlice(builtin_token);
                    const info = BuiltinFn.list.get(builtin_name) orelse break;

                    switch (info.tag) {
                        else => break,
                        .ptr_cast,
                        .align_cast,
                        .addrspace_cast,
                        .const_cast,
                        .volatile_cast,
                        => {},
                    }

                    node = node_datas[node].lhs;
                }

                return tree.nodeToSpan(node);
            },
            .node_offset_array_access_index => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const node_datas = tree.nodes.items(.data);
                const node = src_loc.relativeToNodeIndex(node_off);
                return tree.nodeToSpan(node_datas[node].rhs);
            },
            .node_offset_slice_ptr,
            .node_offset_slice_start,
            .node_offset_slice_end,
            .node_offset_slice_sentinel,
            => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const node = src_loc.relativeToNodeIndex(node_off);
                const full = tree.fullSlice(node).?;
                const part_node = switch (src_loc.lazy) {
                    .node_offset_slice_ptr => full.ast.sliced,
                    .node_offset_slice_start => full.ast.start,
                    .node_offset_slice_end => full.ast.end,
                    .node_offset_slice_sentinel => full.ast.sentinel,
                    else => unreachable,
                };
                return tree.nodeToSpan(part_node);
            },
            .node_offset_call_func => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const node = src_loc.relativeToNodeIndex(node_off);
                var buf: [1]Ast.Node.Index = undefined;
                const full = tree.fullCall(&buf, node).?;
                return tree.nodeToSpan(full.ast.fn_expr);
            },
            .node_offset_field_name => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const node_datas = tree.nodes.items(.data);
                const node_tags = tree.nodes.items(.tag);
                const node = src_loc.relativeToNodeIndex(node_off);
                var buf: [1]Ast.Node.Index = undefined;
                const tok_index = switch (node_tags[node]) {
                    .field_access => node_datas[node].rhs,
                    .call_one,
                    .call_one_comma,
                    .async_call_one,
                    .async_call_one_comma,
                    .call,
                    .call_comma,
                    .async_call,
                    .async_call_comma,
                    => blk: {
                        const full = tree.fullCall(&buf, node).?;
                        break :blk tree.lastToken(full.ast.fn_expr);
                    },
                    else => tree.firstToken(node) - 2,
                };
                const start = tree.tokens.items(.start)[tok_index];
                const end = start + @as(u32, @intCast(tree.tokenSlice(tok_index).len));
                return Span{ .start = start, .end = end, .main = start };
            },
            .node_offset_field_name_init => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const node = src_loc.relativeToNodeIndex(node_off);
                const tok_index = tree.firstToken(node) - 2;
                const start = tree.tokens.items(.start)[tok_index];
                const end = start + @as(u32, @intCast(tree.tokenSlice(tok_index).len));
                return Span{ .start = start, .end = end, .main = start };
            },
            .node_offset_deref_ptr => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const node = src_loc.relativeToNodeIndex(node_off);
                return tree.nodeToSpan(node);
            },
            .node_offset_asm_source => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const node = src_loc.relativeToNodeIndex(node_off);
                const full = tree.fullAsm(node).?;
                return tree.nodeToSpan(full.ast.template);
            },
            .node_offset_asm_ret_ty => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const node = src_loc.relativeToNodeIndex(node_off);
                const full = tree.fullAsm(node).?;
                const asm_output = full.outputs[0];
                const node_datas = tree.nodes.items(.data);
                return tree.nodeToSpan(node_datas[asm_output].lhs);
            },

            .node_offset_if_cond => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const node = src_loc.relativeToNodeIndex(node_off);
                const node_tags = tree.nodes.items(.tag);
                const src_node = switch (node_tags[node]) {
                    .if_simple,
                    .@"if",
                    => tree.fullIf(node).?.ast.cond_expr,

                    .while_simple,
                    .while_cont,
                    .@"while",
                    => tree.fullWhile(node).?.ast.cond_expr,

                    .for_simple,
                    .@"for",
                    => {
                        const inputs = tree.fullFor(node).?.ast.inputs;
                        const start = tree.firstToken(inputs[0]);
                        const end = tree.lastToken(inputs[inputs.len - 1]);
                        return tree.tokensToSpan(start, end, start);
                    },

                    .@"orelse" => node,
                    .@"catch" => node,
                    else => unreachable,
                };
                return tree.nodeToSpan(src_node);
            },
            .for_input => |for_input| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const node = src_loc.relativeToNodeIndex(for_input.for_node_offset);
                const for_full = tree.fullFor(node).?;
                const src_node = for_full.ast.inputs[for_input.input_index];
                return tree.nodeToSpan(src_node);
            },
            .for_capture_from_input => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const token_tags = tree.tokens.items(.tag);
                const input_node = src_loc.relativeToNodeIndex(node_off);
                // We have to actually linear scan the whole AST to find the for loop
                // that contains this input.
                const node_tags = tree.nodes.items(.tag);
                for (node_tags, 0..) |node_tag, node_usize| {
                    const node = @as(Ast.Node.Index, @intCast(node_usize));
                    switch (node_tag) {
                        .for_simple, .@"for" => {
                            const for_full = tree.fullFor(node).?;
                            for (for_full.ast.inputs, 0..) |input, input_index| {
                                if (input_node == input) {
                                    var count = input_index;
                                    var tok = for_full.payload_token;
                                    while (true) {
                                        switch (token_tags[tok]) {
                                            .comma => {
                                                count -= 1;
                                                tok += 1;
                                            },
                                            .identifier => {
                                                if (count == 0)
                                                    return tree.tokensToSpan(tok, tok + 1, tok);
                                                tok += 1;
                                            },
                                            .asterisk => {
                                                if (count == 0)
                                                    return tree.tokensToSpan(tok, tok + 2, tok);
                                                tok += 1;
                                            },
                                            else => unreachable,
                                        }
                                    }
                                }
                            }
                        },
                        else => continue,
                    }
                } else unreachable;
            },
            .call_arg => |call_arg| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const node = src_loc.relativeToNodeIndex(call_arg.call_node_offset);
                var buf: [2]Ast.Node.Index = undefined;
                const call_full = tree.fullCall(buf[0..1], node) orelse {
                    const node_tags = tree.nodes.items(.tag);
                    assert(node_tags[node] == .builtin_call);
                    const call_args_node = tree.extra_data[tree.nodes.items(.data)[node].rhs - 1];
                    switch (node_tags[call_args_node]) {
                        .array_init_one,
                        .array_init_one_comma,
                        .array_init_dot_two,
                        .array_init_dot_two_comma,
                        .array_init_dot,
                        .array_init_dot_comma,
                        .array_init,
                        .array_init_comma,
                        => {
                            const full = tree.fullArrayInit(&buf, call_args_node).?.ast.elements;
                            return tree.nodeToSpan(full[call_arg.arg_index]);
                        },
                        .struct_init_one,
                        .struct_init_one_comma,
                        .struct_init_dot_two,
                        .struct_init_dot_two_comma,
                        .struct_init_dot,
                        .struct_init_dot_comma,
                        .struct_init,
                        .struct_init_comma,
                        => {
                            const full = tree.fullStructInit(&buf, call_args_node).?.ast.fields;
                            return tree.nodeToSpan(full[call_arg.arg_index]);
                        },
                        else => return tree.nodeToSpan(call_args_node),
                    }
                };
                return tree.nodeToSpan(call_full.ast.params[call_arg.arg_index]);
            },
            .fn_proto_param, .fn_proto_param_type => |fn_proto_param| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const node = src_loc.relativeToNodeIndex(fn_proto_param.fn_proto_node_offset);
                var buf: [1]Ast.Node.Index = undefined;
                const full = tree.fullFnProto(&buf, node).?;
                var it = full.iterate(tree);
                var i: usize = 0;
                while (it.next()) |param| : (i += 1) {
                    if (i != fn_proto_param.param_index) continue;

                    switch (src_loc.lazy) {
                        .fn_proto_param_type => if (param.anytype_ellipsis3) |tok| {
                            return tree.tokenToSpan(tok);
                        } else {
                            return tree.nodeToSpan(param.type_expr);
                        },
                        .fn_proto_param => if (param.anytype_ellipsis3) |tok| {
                            const first = param.comptime_noalias orelse param.name_token orelse tok;
                            return tree.tokensToSpan(first, tok, first);
                        } else {
                            const first = param.comptime_noalias orelse param.name_token orelse tree.firstToken(param.type_expr);
                            return tree.tokensToSpan(first, tree.lastToken(param.type_expr), first);
                        },
                        else => unreachable,
                    }
                }
                unreachable;
            },
            .node_offset_bin_lhs => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const node = src_loc.relativeToNodeIndex(node_off);
                const node_datas = tree.nodes.items(.data);
                return tree.nodeToSpan(node_datas[node].lhs);
            },
            .node_offset_bin_rhs => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const node = src_loc.relativeToNodeIndex(node_off);
                const node_datas = tree.nodes.items(.data);
                return tree.nodeToSpan(node_datas[node].rhs);
            },
            .array_cat_lhs, .array_cat_rhs => |cat| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const node = src_loc.relativeToNodeIndex(cat.array_cat_offset);
                const node_datas = tree.nodes.items(.data);
                const arr_node = if (src_loc.lazy == .array_cat_lhs)
                    node_datas[node].lhs
                else
                    node_datas[node].rhs;

                const node_tags = tree.nodes.items(.tag);
                var buf: [2]Ast.Node.Index = undefined;
                switch (node_tags[arr_node]) {
                    .array_init_one,
                    .array_init_one_comma,
                    .array_init_dot_two,
                    .array_init_dot_two_comma,
                    .array_init_dot,
                    .array_init_dot_comma,
                    .array_init,
                    .array_init_comma,
                    => {
                        const full = tree.fullArrayInit(&buf, arr_node).?.ast.elements;
                        return tree.nodeToSpan(full[cat.elem_index]);
                    },
                    else => return tree.nodeToSpan(arr_node),
                }
            },

            .node_offset_switch_operand => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const node = src_loc.relativeToNodeIndex(node_off);
                const node_datas = tree.nodes.items(.data);
                return tree.nodeToSpan(node_datas[node].lhs);
            },

            .node_offset_switch_special_prong => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const switch_node = src_loc.relativeToNodeIndex(node_off);
                const node_datas = tree.nodes.items(.data);
                const node_tags = tree.nodes.items(.tag);
                const main_tokens = tree.nodes.items(.main_token);
                const extra = tree.extraData(node_datas[switch_node].rhs, Ast.Node.SubRange);
                const case_nodes = tree.extra_data[extra.start..extra.end];
                for (case_nodes) |case_node| {
                    const case = tree.fullSwitchCase(case_node).?;
                    const is_special = (case.ast.values.len == 0) or
                        (case.ast.values.len == 1 and
                        node_tags[case.ast.values[0]] == .identifier and
                        mem.eql(u8, tree.tokenSlice(main_tokens[case.ast.values[0]]), "_"));
                    if (!is_special) continue;

                    return tree.nodeToSpan(case_node);
                } else unreachable;
            },

            .node_offset_switch_range => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const switch_node = src_loc.relativeToNodeIndex(node_off);
                const node_datas = tree.nodes.items(.data);
                const node_tags = tree.nodes.items(.tag);
                const main_tokens = tree.nodes.items(.main_token);
                const extra = tree.extraData(node_datas[switch_node].rhs, Ast.Node.SubRange);
                const case_nodes = tree.extra_data[extra.start..extra.end];
                for (case_nodes) |case_node| {
                    const case = tree.fullSwitchCase(case_node).?;
                    const is_special = (case.ast.values.len == 0) or
                        (case.ast.values.len == 1 and
                        node_tags[case.ast.values[0]] == .identifier and
                        mem.eql(u8, tree.tokenSlice(main_tokens[case.ast.values[0]]), "_"));
                    if (is_special) continue;

                    for (case.ast.values) |item_node| {
                        if (node_tags[item_node] == .switch_range) {
                            return tree.nodeToSpan(item_node);
                        }
                    }
                } else unreachable;
            },
            .node_offset_fn_type_align => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const node = src_loc.relativeToNodeIndex(node_off);
                var buf: [1]Ast.Node.Index = undefined;
                const full = tree.fullFnProto(&buf, node).?;
                return tree.nodeToSpan(full.ast.align_expr);
            },
            .node_offset_fn_type_addrspace => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const node = src_loc.relativeToNodeIndex(node_off);
                var buf: [1]Ast.Node.Index = undefined;
                const full = tree.fullFnProto(&buf, node).?;
                return tree.nodeToSpan(full.ast.addrspace_expr);
            },
            .node_offset_fn_type_section => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const node = src_loc.relativeToNodeIndex(node_off);
                var buf: [1]Ast.Node.Index = undefined;
                const full = tree.fullFnProto(&buf, node).?;
                return tree.nodeToSpan(full.ast.section_expr);
            },
            .node_offset_fn_type_cc => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const node = src_loc.relativeToNodeIndex(node_off);
                var buf: [1]Ast.Node.Index = undefined;
                const full = tree.fullFnProto(&buf, node).?;
                return tree.nodeToSpan(full.ast.callconv_expr);
            },

            .node_offset_fn_type_ret_ty => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const node = src_loc.relativeToNodeIndex(node_off);
                var buf: [1]Ast.Node.Index = undefined;
                const full = tree.fullFnProto(&buf, node).?;
                return tree.nodeToSpan(full.ast.return_type);
            },
            .node_offset_param => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const token_tags = tree.tokens.items(.tag);
                const node = src_loc.relativeToNodeIndex(node_off);

                var first_tok = tree.firstToken(node);
                while (true) switch (token_tags[first_tok - 1]) {
                    .colon, .identifier, .keyword_comptime, .keyword_noalias => first_tok -= 1,
                    else => break,
                };
                return tree.tokensToSpan(
                    first_tok,
                    tree.lastToken(node),
                    first_tok,
                );
            },
            .token_offset_param => |token_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const token_tags = tree.tokens.items(.tag);
                const main_token = tree.nodes.items(.main_token)[src_loc.base_node];
                const tok_index = @as(Ast.TokenIndex, @bitCast(token_off + @as(i32, @bitCast(main_token))));

                var first_tok = tok_index;
                while (true) switch (token_tags[first_tok - 1]) {
                    .colon, .identifier, .keyword_comptime, .keyword_noalias => first_tok -= 1,
                    else => break,
                };
                return tree.tokensToSpan(
                    first_tok,
                    tok_index,
                    first_tok,
                );
            },

            .node_offset_anyframe_type => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const node_datas = tree.nodes.items(.data);
                const parent_node = src_loc.relativeToNodeIndex(node_off);
                return tree.nodeToSpan(node_datas[parent_node].rhs);
            },

            .node_offset_lib_name => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const parent_node = src_loc.relativeToNodeIndex(node_off);
                var buf: [1]Ast.Node.Index = undefined;
                const full = tree.fullFnProto(&buf, parent_node).?;
                const tok_index = full.lib_name.?;
                const start = tree.tokens.items(.start)[tok_index];
                const end = start + @as(u32, @intCast(tree.tokenSlice(tok_index).len));
                return Span{ .start = start, .end = end, .main = start };
            },

            .node_offset_array_type_len => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const parent_node = src_loc.relativeToNodeIndex(node_off);

                const full = tree.fullArrayType(parent_node).?;
                return tree.nodeToSpan(full.ast.elem_count);
            },
            .node_offset_array_type_sentinel => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const parent_node = src_loc.relativeToNodeIndex(node_off);

                const full = tree.fullArrayType(parent_node).?;
                return tree.nodeToSpan(full.ast.sentinel);
            },
            .node_offset_array_type_elem => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const parent_node = src_loc.relativeToNodeIndex(node_off);

                const full = tree.fullArrayType(parent_node).?;
                return tree.nodeToSpan(full.ast.elem_type);
            },
            .node_offset_un_op => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const node_datas = tree.nodes.items(.data);
                const node = src_loc.relativeToNodeIndex(node_off);

                return tree.nodeToSpan(node_datas[node].lhs);
            },
            .node_offset_ptr_elem => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const parent_node = src_loc.relativeToNodeIndex(node_off);

                const full = tree.fullPtrType(parent_node).?;
                return tree.nodeToSpan(full.ast.child_type);
            },
            .node_offset_ptr_sentinel => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const parent_node = src_loc.relativeToNodeIndex(node_off);

                const full = tree.fullPtrType(parent_node).?;
                return tree.nodeToSpan(full.ast.sentinel);
            },
            .node_offset_ptr_align => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const parent_node = src_loc.relativeToNodeIndex(node_off);

                const full = tree.fullPtrType(parent_node).?;
                return tree.nodeToSpan(full.ast.align_node);
            },
            .node_offset_ptr_addrspace => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const parent_node = src_loc.relativeToNodeIndex(node_off);

                const full = tree.fullPtrType(parent_node).?;
                return tree.nodeToSpan(full.ast.addrspace_node);
            },
            .node_offset_ptr_bitoffset => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const parent_node = src_loc.relativeToNodeIndex(node_off);

                const full = tree.fullPtrType(parent_node).?;
                return tree.nodeToSpan(full.ast.bit_range_start);
            },
            .node_offset_ptr_hostsize => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const parent_node = src_loc.relativeToNodeIndex(node_off);

                const full = tree.fullPtrType(parent_node).?;
                return tree.nodeToSpan(full.ast.bit_range_end);
            },
            .node_offset_container_tag => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const node_tags = tree.nodes.items(.tag);
                const parent_node = src_loc.relativeToNodeIndex(node_off);

                switch (node_tags[parent_node]) {
                    .container_decl_arg, .container_decl_arg_trailing => {
                        const full = tree.containerDeclArg(parent_node);
                        return tree.nodeToSpan(full.ast.arg);
                    },
                    .tagged_union_enum_tag, .tagged_union_enum_tag_trailing => {
                        const full = tree.taggedUnionEnumTag(parent_node);

                        return tree.tokensToSpan(
                            tree.firstToken(full.ast.arg) - 2,
                            tree.lastToken(full.ast.arg) + 1,
                            tree.nodes.items(.main_token)[full.ast.arg],
                        );
                    },
                    else => unreachable,
                }
            },
            .node_offset_field_default => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const node_tags = tree.nodes.items(.tag);
                const parent_node = src_loc.relativeToNodeIndex(node_off);

                const full: Ast.full.ContainerField = switch (node_tags[parent_node]) {
                    .container_field => tree.containerField(parent_node),
                    .container_field_init => tree.containerFieldInit(parent_node),
                    else => unreachable,
                };
                return tree.nodeToSpan(full.ast.value_expr);
            },
            .node_offset_init_ty => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const parent_node = src_loc.relativeToNodeIndex(node_off);

                var buf: [2]Ast.Node.Index = undefined;
                const type_expr = if (tree.fullArrayInit(&buf, parent_node)) |array_init|
                    array_init.ast.type_expr
                else
                    tree.fullStructInit(&buf, parent_node).?.ast.type_expr;
                return tree.nodeToSpan(type_expr);
            },
            .node_offset_store_ptr => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const node_tags = tree.nodes.items(.tag);
                const node_datas = tree.nodes.items(.data);
                const node = src_loc.relativeToNodeIndex(node_off);

                switch (node_tags[node]) {
                    .assign => {
                        return tree.nodeToSpan(node_datas[node].lhs);
                    },
                    else => return tree.nodeToSpan(node),
                }
            },
            .node_offset_store_operand => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const node_tags = tree.nodes.items(.tag);
                const node_datas = tree.nodes.items(.data);
                const node = src_loc.relativeToNodeIndex(node_off);

                switch (node_tags[node]) {
                    .assign => {
                        return tree.nodeToSpan(node_datas[node].rhs);
                    },
                    else => return tree.nodeToSpan(node),
                }
            },
            .node_offset_return_operand => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const node = src_loc.relativeToNodeIndex(node_off);
                const node_tags = tree.nodes.items(.tag);
                const node_datas = tree.nodes.items(.data);
                if (node_tags[node] == .@"return" and node_datas[node].lhs != 0) {
                    return tree.nodeToSpan(node_datas[node].lhs);
                }
                return tree.nodeToSpan(node);
            },
            .container_field_name,
            .container_field_value,
            .container_field_type,
            .container_field_align,
            => |field_idx| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const node = src_loc.relativeToNodeIndex(0);
                var buf: [2]Ast.Node.Index = undefined;
                const container_decl = tree.fullContainerDecl(&buf, node) orelse
                    return tree.nodeToSpan(node);

                var cur_field_idx: usize = 0;
                for (container_decl.ast.members) |member_node| {
                    const field = tree.fullContainerField(member_node) orelse continue;
                    if (cur_field_idx < field_idx) {
                        cur_field_idx += 1;
                        continue;
                    }
                    const field_component_node = switch (src_loc.lazy) {
                        .container_field_name => 0,
                        .container_field_value => field.ast.value_expr,
                        .container_field_type => field.ast.type_expr,
                        .container_field_align => field.ast.align_expr,
                        else => unreachable,
                    };
                    if (field_component_node == 0) {
                        return tree.tokenToSpan(field.ast.main_token);
                    } else {
                        return tree.nodeToSpan(field_component_node);
                    }
                } else unreachable;
            },
            .tuple_field_type, .tuple_field_init => |field_info| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const node = src_loc.relativeToNodeIndex(0);
                var buf: [2]Ast.Node.Index = undefined;
                const container_decl = tree.fullContainerDecl(&buf, node) orelse
                    return tree.nodeToSpan(node);

                const field = tree.fullContainerField(container_decl.ast.members[field_info.elem_index]).?;
                return tree.nodeToSpan(switch (src_loc.lazy) {
                    .tuple_field_type => field.ast.type_expr,
                    .tuple_field_init => field.ast.value_expr,
                    else => unreachable,
                });
            },
            .init_elem => |init_elem| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const init_node = src_loc.relativeToNodeIndex(init_elem.init_node_offset);
                var buf: [2]Ast.Node.Index = undefined;
                if (tree.fullArrayInit(&buf, init_node)) |full| {
                    const elem_node = full.ast.elements[init_elem.elem_index];
                    return tree.nodeToSpan(elem_node);
                } else if (tree.fullStructInit(&buf, init_node)) |full| {
                    const field_node = full.ast.fields[init_elem.elem_index];
                    return tree.tokensToSpan(
                        tree.firstToken(field_node) - 3,
                        tree.lastToken(field_node),
                        tree.nodes.items(.main_token)[field_node] - 2,
                    );
                } else unreachable;
            },
            .init_field_name,
            .init_field_linkage,
            .init_field_section,
            .init_field_visibility,
            .init_field_rw,
            .init_field_locality,
            .init_field_cache,
            .init_field_library,
            .init_field_thread_local,
            .init_field_dll_import,
            => |builtin_call_node| {
                const wanted = switch (src_loc.lazy) {
                    .init_field_name => "name",
                    .init_field_linkage => "linkage",
                    .init_field_section => "section",
                    .init_field_visibility => "visibility",
                    .init_field_rw => "rw",
                    .init_field_locality => "locality",
                    .init_field_cache => "cache",
                    .init_field_library => "library",
                    .init_field_thread_local => "thread_local",
                    .init_field_dll_import => "dll_import",
                    else => unreachable,
                };
                const tree = try src_loc.file_scope.getTree(gpa);
                const node_datas = tree.nodes.items(.data);
                const node_tags = tree.nodes.items(.tag);
                const node = src_loc.relativeToNodeIndex(builtin_call_node);
                const arg_node = switch (node_tags[node]) {
                    .builtin_call_two, .builtin_call_two_comma => node_datas[node].rhs,
                    .builtin_call, .builtin_call_comma => tree.extra_data[node_datas[node].lhs + 1],
                    else => unreachable,
                };
                var buf: [2]Ast.Node.Index = undefined;
                const full = tree.fullStructInit(&buf, arg_node) orelse
                    return tree.nodeToSpan(arg_node);
                for (full.ast.fields) |field_node| {
                    // . IDENTIFIER = field_node
                    const name_token = tree.firstToken(field_node) - 2;
                    const name = tree.tokenSlice(name_token);
                    if (std.mem.eql(u8, name, wanted)) {
                        return tree.tokensToSpan(
                            name_token - 1,
                            tree.lastToken(field_node),
                            tree.nodes.items(.main_token)[field_node] - 2,
                        );
                    }
                }
                return tree.nodeToSpan(arg_node);
            },
            .switch_case_item,
            .switch_case_item_range_first,
            .switch_case_item_range_last,
            .switch_capture,
            .switch_tag_capture,
            => {
                const switch_node_offset, const want_case_idx = switch (src_loc.lazy) {
                    .switch_case_item,
                    .switch_case_item_range_first,
                    .switch_case_item_range_last,
                    => |x| .{ x.switch_node_offset, x.case_idx },
                    .switch_capture,
                    .switch_tag_capture,
                    => |x| .{ x.switch_node_offset, x.case_idx },
                    else => unreachable,
                };

                const tree = try src_loc.file_scope.getTree(gpa);
                const node_datas = tree.nodes.items(.data);
                const node_tags = tree.nodes.items(.tag);
                const main_tokens = tree.nodes.items(.main_token);
                const switch_node = src_loc.relativeToNodeIndex(switch_node_offset);
                const extra = tree.extraData(node_datas[switch_node].rhs, Ast.Node.SubRange);
                const case_nodes = tree.extra_data[extra.start..extra.end];

                var multi_i: u32 = 0;
                var scalar_i: u32 = 0;
                const case = for (case_nodes) |case_node| {
                    const case = tree.fullSwitchCase(case_node).?;
                    const is_special = special: {
                        if (case.ast.values.len == 0) break :special true;
                        if (case.ast.values.len == 1 and node_tags[case.ast.values[0]] == .identifier) {
                            break :special mem.eql(u8, tree.tokenSlice(main_tokens[case.ast.values[0]]), "_");
                        }
                        break :special false;
                    };
                    if (is_special) {
                        if (want_case_idx.isSpecial()) {
                            break case;
                        }
                        continue;
                    }

                    const is_multi = case.ast.values.len != 1 or
                        node_tags[case.ast.values[0]] == .switch_range;

                    switch (want_case_idx.kind) {
                        .scalar => if (!is_multi and want_case_idx.index == scalar_i) break case,
                        .multi => if (is_multi and want_case_idx.index == multi_i) break case,
                    }

                    if (is_multi) {
                        multi_i += 1;
                    } else {
                        scalar_i += 1;
                    }
                } else unreachable;

                const want_item = switch (src_loc.lazy) {
                    .switch_case_item,
                    .switch_case_item_range_first,
                    .switch_case_item_range_last,
                    => |x| x.item_idx,
                    .switch_capture, .switch_tag_capture => {
                        const token_tags = tree.tokens.items(.tag);
                        const start = switch (src_loc.lazy) {
                            .switch_capture => case.payload_token.?,
                            .switch_tag_capture => tok: {
                                var tok = case.payload_token.?;
                                if (token_tags[tok] == .asterisk) tok += 1;
                                tok += 2; // skip over comma
                                break :tok tok;
                            },
                            else => unreachable,
                        };
                        const end = switch (token_tags[start]) {
                            .asterisk => start + 1,
                            else => start,
                        };
                        return tree.tokensToSpan(start, end, start);
                    },
                    else => unreachable,
                };

                switch (want_item.kind) {
                    .single => {
                        var item_i: u32 = 0;
                        for (case.ast.values) |item_node| {
                            if (node_tags[item_node] == .switch_range) continue;
                            if (item_i != want_item.index) {
                                item_i += 1;
                                continue;
                            }
                            return tree.nodeToSpan(item_node);
                        } else unreachable;
                    },
                    .range => {
                        var range_i: u32 = 0;
                        for (case.ast.values) |item_node| {
                            if (node_tags[item_node] != .switch_range) continue;
                            if (range_i != want_item.index) {
                                range_i += 1;
                                continue;
                            }
                            return switch (src_loc.lazy) {
                                .switch_case_item => tree.nodeToSpan(item_node),
                                .switch_case_item_range_first => tree.nodeToSpan(node_datas[item_node].lhs),
                                .switch_case_item_range_last => tree.nodeToSpan(node_datas[item_node].rhs),
                                else => unreachable,
                            };
                        } else unreachable;
                    },
                }
            },
            .func_decl_param_comptime => |param_idx| {
                const tree = try src_loc.file_scope.getTree(gpa);
                var buf: [1]Ast.Node.Index = undefined;
                const full = tree.fullFnProto(&buf, src_loc.base_node).?;
                var param_it = full.iterate(tree);
                for (0..param_idx) |_| assert(param_it.next() != null);
                const param = param_it.next().?;
                return tree.tokenToSpan(param.comptime_noalias.?);
            },
            .func_decl_param_ty => |param_idx| {
                const tree = try src_loc.file_scope.getTree(gpa);
                var buf: [1]Ast.Node.Index = undefined;
                const full = tree.fullFnProto(&buf, src_loc.base_node).?;
                var param_it = full.iterate(tree);
                for (0..param_idx) |_| assert(param_it.next() != null);
                const param = param_it.next().?;
                return tree.nodeToSpan(param.type_expr);
            },
        }
    }
};

pub const LazySrcLoc = struct {
    /// This instruction provides the source node locations are resolved relative to.
    /// It is a `declaration`, `struct_decl`, `union_decl`, `enum_decl`, or `opaque_decl`.
    /// This must be valid even if `relative` is an absolute value, since it is required to
    /// determine the file which the `LazySrcLoc` refers to.
    base_node_inst: InternPool.TrackedInst.Index,
    /// This field determines the source location relative to `base_node_inst`.
    offset: Offset,

    pub const Offset = union(enum) {
        /// When this tag is set, the code that constructed this `LazySrcLoc` is asserting
        /// that all code paths which would need to resolve the source location are
        /// unreachable. If you are debugging this tag incorrectly being this value,
        /// look into using reverse-continue with a memory watchpoint to see where the
        /// value is being set to this tag.
        /// `base_node_inst` is unused.
        unneeded,
        /// Means the source location points to an entire file; not any particular
        /// location within the file. `file_scope` union field will be active.
        entire_file,
        /// The source location points to a byte offset within a source file,
        /// offset from 0. The source file is determined contextually.
        byte_abs: u32,
        /// The source location points to a token within a source file,
        /// offset from 0. The source file is determined contextually.
        token_abs: u32,
        /// The source location points to an AST node within a source file,
        /// offset from 0. The source file is determined contextually.
        node_abs: u32,
        /// The source location points to a byte offset within a source file,
        /// offset from the byte offset of the base node within the file.
        byte_offset: u32,
        /// This data is the offset into the token list from the base node's first token.
        token_offset: u32,
        /// The source location points to an AST node, which is this value offset
        /// from its containing base node AST index.
        node_offset: TracedOffset,
        /// The source location points to the main token of an AST node, found
        /// by taking this AST node index offset from the containing base node.
        node_offset_main_token: i32,
        /// The source location points to the beginning of a struct initializer.
        node_offset_initializer: i32,
        /// The source location points to a variable declaration type expression,
        /// found by taking this AST node index offset from the containing
        /// base node, which points to a variable declaration AST node. Next, navigate
        /// to the type expression.
        node_offset_var_decl_ty: i32,
        /// The source location points to the alignment expression of a var decl.
        node_offset_var_decl_align: i32,
        /// The source location points to the linksection expression of a var decl.
        node_offset_var_decl_section: i32,
        /// The source location points to the addrspace expression of a var decl.
        node_offset_var_decl_addrspace: i32,
        /// The source location points to the initializer of a var decl.
        node_offset_var_decl_init: i32,
        /// The source location points to the given argument of a builtin function call.
        /// `builtin_call_node` points to the builtin call.
        /// `arg_index` is the index of the argument which hte source location refers to.
        node_offset_builtin_call_arg: struct {
            builtin_call_node: i32,
            arg_index: u32,
        },
        /// Like `node_offset_builtin_call_arg` but recurses through arbitrarily many calls
        /// to pointer cast builtins (taking the first argument of the most nested).
        node_offset_ptrcast_operand: i32,
        /// The source location points to the index expression of an array access
        /// expression, found by taking this AST node index offset from the containing
        /// base node, which points to an array access AST node. Next, navigate
        /// to the index expression.
        node_offset_array_access_index: i32,
        /// The source location points to the LHS of a slice expression
        /// expression, found by taking this AST node index offset from the containing
        /// base node, which points to a slice AST node. Next, navigate
        /// to the sentinel expression.
        node_offset_slice_ptr: i32,
        /// The source location points to start expression of a slice expression
        /// expression, found by taking this AST node index offset from the containing
        /// base node, which points to a slice AST node. Next, navigate
        /// to the sentinel expression.
        node_offset_slice_start: i32,
        /// The source location points to the end expression of a slice
        /// expression, found by taking this AST node index offset from the containing
        /// base node, which points to a slice AST node. Next, navigate
        /// to the sentinel expression.
        node_offset_slice_end: i32,
        /// The source location points to the sentinel expression of a slice
        /// expression, found by taking this AST node index offset from the containing
        /// base node, which points to a slice AST node. Next, navigate
        /// to the sentinel expression.
        node_offset_slice_sentinel: i32,
        /// The source location points to the callee expression of a function
        /// call expression, found by taking this AST node index offset from the containing
        /// base node, which points to a function call AST node. Next, navigate
        /// to the callee expression.
        node_offset_call_func: i32,
        /// The payload is offset from the containing base node.
        /// The source location points to the field name of:
        ///  * a field access expression (`a.b`), or
        ///  * the callee of a method call (`a.b()`)
        node_offset_field_name: i32,
        /// The payload is offset from the containing base node.
        /// The source location points to the field name of the operand ("b" node)
        /// of a field initialization expression (`.a = b`)
        node_offset_field_name_init: i32,
        /// The source location points to the pointer of a pointer deref expression,
        /// found by taking this AST node index offset from the containing
        /// base node, which points to a pointer deref AST node. Next, navigate
        /// to the pointer expression.
        node_offset_deref_ptr: i32,
        /// The source location points to the assembly source code of an inline assembly
        /// expression, found by taking this AST node index offset from the containing
        /// base node, which points to inline assembly AST node. Next, navigate
        /// to the asm template source code.
        node_offset_asm_source: i32,
        /// The source location points to the return type of an inline assembly
        /// expression, found by taking this AST node index offset from the containing
        /// base node, which points to inline assembly AST node. Next, navigate
        /// to the return type expression.
        node_offset_asm_ret_ty: i32,
        /// The source location points to the condition expression of an if
        /// expression, found by taking this AST node index offset from the containing
        /// base node, which points to an if expression AST node. Next, navigate
        /// to the condition expression.
        node_offset_if_cond: i32,
        /// The source location points to a binary expression, such as `a + b`, found
        /// by taking this AST node index offset from the containing base node.
        node_offset_bin_op: i32,
        /// The source location points to the LHS of a binary expression, found
        /// by taking this AST node index offset from the containing base node,
        /// which points to a binary expression AST node. Next, navigate to the LHS.
        node_offset_bin_lhs: i32,
        /// The source location points to the RHS of a binary expression, found
        /// by taking this AST node index offset from the containing base node,
        /// which points to a binary expression AST node. Next, navigate to the RHS.
        node_offset_bin_rhs: i32,
        /// The source location points to the operand of a switch expression, found
        /// by taking this AST node index offset from the containing base node,
        /// which points to a switch expression AST node. Next, navigate to the operand.
        node_offset_switch_operand: i32,
        /// The source location points to the else/`_` prong of a switch expression, found
        /// by taking this AST node index offset from the containing base node,
        /// which points to a switch expression AST node. Next, navigate to the else/`_` prong.
        node_offset_switch_special_prong: i32,
        /// The source location points to all the ranges of a switch expression, found
        /// by taking this AST node index offset from the containing base node,
        /// which points to a switch expression AST node. Next, navigate to any of the
        /// range nodes. The error applies to all of them.
        node_offset_switch_range: i32,
        /// The source location points to the align expr of a function type
        /// expression, found by taking this AST node index offset from the containing
        /// base node, which points to a function type AST node. Next, navigate to
        /// the calling convention node.
        node_offset_fn_type_align: i32,
        /// The source location points to the addrspace expr of a function type
        /// expression, found by taking this AST node index offset from the containing
        /// base node, which points to a function type AST node. Next, navigate to
        /// the calling convention node.
        node_offset_fn_type_addrspace: i32,
        /// The source location points to the linksection expr of a function type
        /// expression, found by taking this AST node index offset from the containing
        /// base node, which points to a function type AST node. Next, navigate to
        /// the calling convention node.
        node_offset_fn_type_section: i32,
        /// The source location points to the calling convention of a function type
        /// expression, found by taking this AST node index offset from the containing
        /// base node, which points to a function type AST node. Next, navigate to
        /// the calling convention node.
        node_offset_fn_type_cc: i32,
        /// The source location points to the return type of a function type
        /// expression, found by taking this AST node index offset from the containing
        /// base node, which points to a function type AST node. Next, navigate to
        /// the return type node.
        node_offset_fn_type_ret_ty: i32,
        node_offset_param: i32,
        token_offset_param: i32,
        /// The source location points to the type expression of an `anyframe->T`
        /// expression, found by taking this AST node index offset from the containing
        /// base node, which points to a `anyframe->T` expression AST node. Next, navigate
        /// to the type expression.
        node_offset_anyframe_type: i32,
        /// The source location points to the string literal of `extern "foo"`, found
        /// by taking this AST node index offset from the containing
        /// base node, which points to a function prototype or variable declaration
        /// expression AST node. Next, navigate to the string literal of the `extern "foo"`.
        node_offset_lib_name: i32,
        /// The source location points to the len expression of an `[N:S]T`
        /// expression, found by taking this AST node index offset from the containing
        /// base node, which points to an `[N:S]T` expression AST node. Next, navigate
        /// to the len expression.
        node_offset_array_type_len: i32,
        /// The source location points to the sentinel expression of an `[N:S]T`
        /// expression, found by taking this AST node index offset from the containing
        /// base node, which points to an `[N:S]T` expression AST node. Next, navigate
        /// to the sentinel expression.
        node_offset_array_type_sentinel: i32,
        /// The source location points to the elem expression of an `[N:S]T`
        /// expression, found by taking this AST node index offset from the containing
        /// base node, which points to an `[N:S]T` expression AST node. Next, navigate
        /// to the elem expression.
        node_offset_array_type_elem: i32,
        /// The source location points to the operand of an unary expression.
        node_offset_un_op: i32,
        /// The source location points to the elem type of a pointer.
        node_offset_ptr_elem: i32,
        /// The source location points to the sentinel of a pointer.
        node_offset_ptr_sentinel: i32,
        /// The source location points to the align expr of a pointer.
        node_offset_ptr_align: i32,
        /// The source location points to the addrspace expr of a pointer.
        node_offset_ptr_addrspace: i32,
        /// The source location points to the bit-offset of a pointer.
        node_offset_ptr_bitoffset: i32,
        /// The source location points to the host size of a pointer.
        node_offset_ptr_hostsize: i32,
        /// The source location points to the tag type of an union or an enum.
        node_offset_container_tag: i32,
        /// The source location points to the default value of a field.
        node_offset_field_default: i32,
        /// The source location points to the type of an array or struct initializer.
        node_offset_init_ty: i32,
        /// The source location points to the LHS of an assignment.
        node_offset_store_ptr: i32,
        /// The source location points to the RHS of an assignment.
        node_offset_store_operand: i32,
        /// The source location points to the operand of a `return` statement, or
        /// the `return` itself if there is no explicit operand.
        node_offset_return_operand: i32,
        /// The source location points to a for loop input.
        for_input: struct {
            /// Points to the for loop AST node.
            for_node_offset: i32,
            /// Picks one of the inputs from the condition.
            input_index: u32,
        },
        /// The source location points to one of the captures of a for loop, found
        /// by taking this AST node index offset from the containing
        /// base node, which points to one of the input nodes of a for loop.
        /// Next, navigate to the corresponding capture.
        for_capture_from_input: i32,
        /// The source location points to the argument node of a function call.
        call_arg: struct {
            /// Points to the function call AST node.
            call_node_offset: i32,
            /// The index of the argument the source location points to.
            arg_index: u32,
        },
        fn_proto_param: FnProtoParam,
        fn_proto_param_type: FnProtoParam,
        array_cat_lhs: ArrayCat,
        array_cat_rhs: ArrayCat,
        /// The source location points to the name of the field at the given index
        /// of the container type declaration at the base node.
        container_field_name: u32,
        /// Like `continer_field_name`, but points at the field's default value.
        container_field_value: u32,
        /// Like `continer_field_name`, but points at the field's type.
        container_field_type: u32,
        /// Like `continer_field_name`, but points at the field's alignment.
        container_field_align: u32,
        /// The source location points to the type of the field at the given index
        /// of the tuple type declaration at `tuple_decl_node_offset`.
        tuple_field_type: TupleField,
        /// The source location points to the default init of the field at the given index
        /// of the tuple type declaration at `tuple_decl_node_offset`.
        tuple_field_init: TupleField,
        /// The source location points to the given element/field of a struct or
        /// array initialization expression.
        init_elem: struct {
            /// Points to the AST node of the initialization expression.
            init_node_offset: i32,
            /// The index of the field/element the source location points to.
            elem_index: u32,
        },
        // The following source locations are like `init_elem`, but refer to a
        // field with a specific name. If such a field is not given, the entire
        // initialization expression is used instead.
        // The `i32` points to the AST node of a builtin call, whose *second*
        // argument is the init expression.
        init_field_name: i32,
        init_field_linkage: i32,
        init_field_section: i32,
        init_field_visibility: i32,
        init_field_rw: i32,
        init_field_locality: i32,
        init_field_cache: i32,
        init_field_library: i32,
        init_field_thread_local: i32,
        init_field_dll_import: i32,
        /// The source location points to the value of an item in a specific
        /// case of a `switch`.
        switch_case_item: SwitchItem,
        /// The source location points to the "first" value of a range item in
        /// a specific case of a `switch`.
        switch_case_item_range_first: SwitchItem,
        /// The source location points to the "last" value of a range item in
        /// a specific case of a `switch`.
        switch_case_item_range_last: SwitchItem,
        /// The source location points to the main capture of a specific case of
        /// a `switch`.
        switch_capture: SwitchCapture,
        /// The source location points to the "tag" capture (second capture) of
        /// a specific case of a `switch`.
        switch_tag_capture: SwitchCapture,
        /// The source location points to the `comptime` token on the given comptime parameter,
        /// where the base node is a function declaration. The value is the parameter index.
        func_decl_param_comptime: u32,
        /// The source location points to the type annotation on the given function parameter,
        /// where the base node is a function declaration. The value is the parameter index.
        func_decl_param_ty: u32,

        pub const FnProtoParam = struct {
            /// The offset of the function prototype AST node.
            fn_proto_node_offset: i32,
            /// The index of the parameter the source location points to.
            param_index: u32,
        };

        pub const SwitchItem = struct {
            /// The offset of the switch AST node.
            switch_node_offset: i32,
            /// The index of the case to point to within this switch.
            case_idx: SwitchCaseIndex,
            /// The index of the item to point to within this case.
            item_idx: SwitchItemIndex,
        };

        pub const SwitchCapture = struct {
            /// The offset of the switch AST node.
            switch_node_offset: i32,
            /// The index of the case whose capture to point to.
            case_idx: SwitchCaseIndex,
        };

        pub const SwitchCaseIndex = packed struct(u32) {
            kind: enum(u1) { scalar, multi },
            index: u31,

            pub const special: SwitchCaseIndex = @bitCast(@as(u32, std.math.maxInt(u32)));
            pub fn isSpecial(idx: SwitchCaseIndex) bool {
                return @as(u32, @bitCast(idx)) == @as(u32, @bitCast(special));
            }
        };

        pub const SwitchItemIndex = packed struct(u32) {
            kind: enum(u1) { single, range },
            index: u31,
        };

        pub const ArrayCat = struct {
            /// Points to the array concat AST node.
            array_cat_offset: i32,
            /// The index of the element the source location points to.
            elem_index: u32,
        };

        pub const TupleField = struct {
            /// Points to the AST node of the tuple type decaration.
            tuple_decl_node_offset: i32,
            /// The index of the tuple field the source location points to.
            elem_index: u32,
        };

        pub const nodeOffset = if (TracedOffset.want_tracing) nodeOffsetDebug else nodeOffsetRelease;

        noinline fn nodeOffsetDebug(node_offset: i32) Offset {
            var result: LazySrcLoc = .{ .node_offset = .{ .x = node_offset } };
            result.node_offset.trace.addAddr(@returnAddress(), "init");
            return result;
        }

        fn nodeOffsetRelease(node_offset: i32) Offset {
            return .{ .node_offset = .{ .x = node_offset } };
        }

        /// This wraps a simple integer in debug builds so that later on we can find out
        /// where in semantic analysis the value got set.
        pub const TracedOffset = struct {
            x: i32,
            trace: std.debug.Trace = std.debug.Trace.init,

            const want_tracing = false;
        };
    };

    pub const unneeded: LazySrcLoc = .{
        .base_node_inst = undefined,
        .offset = .unneeded,
    };

    /// Returns `null` if the ZIR instruction has been lost across incremental updates.
    pub fn resolveBaseNode(base_node_inst: InternPool.TrackedInst.Index, zcu: *Zcu) ?struct { *File, Ast.Node.Index } {
        comptime assert(Zir.inst_tracking_version == 0);

        const ip = &zcu.intern_pool;
        const file_index, const zir_inst = inst: {
            const info = base_node_inst.resolveFull(ip) orelse return null;
            break :inst .{ info.file, info.inst };
        };
        const file = zcu.fileByIndex(file_index);

        // If we're relative to .main_struct_inst, we know the ast node is the root and don't need to resolve the ZIR,
        // which may not exist e.g. in the case of errors in ZON files.
        if (zir_inst == .main_struct_inst) return .{ file, 0 };

        // Otherwise, make sure ZIR is loaded.
        const zir = file.zir.?;

        const inst = zir.instructions.get(@intFromEnum(zir_inst));
        const base_node: Ast.Node.Index = switch (inst.tag) {
            .declaration => inst.data.declaration.src_node,
            .struct_init, .struct_init_ref => zir.extraData(Zir.Inst.StructInit, inst.data.pl_node.payload_index).data.abs_node,
            .struct_init_anon => zir.extraData(Zir.Inst.StructInitAnon, inst.data.pl_node.payload_index).data.abs_node,
            .extended => switch (inst.data.extended.opcode) {
                .struct_decl => zir.extraData(Zir.Inst.StructDecl, inst.data.extended.operand).data.src_node,
                .union_decl => zir.extraData(Zir.Inst.UnionDecl, inst.data.extended.operand).data.src_node,
                .enum_decl => zir.extraData(Zir.Inst.EnumDecl, inst.data.extended.operand).data.src_node,
                .opaque_decl => zir.extraData(Zir.Inst.OpaqueDecl, inst.data.extended.operand).data.src_node,
                .reify => zir.extraData(Zir.Inst.Reify, inst.data.extended.operand).data.node,
                else => unreachable,
            },
            else => unreachable,
        };
        return .{ file, base_node };
    }

    /// Resolve the file and AST node of `base_node_inst` to get a resolved `SrcLoc`.
    /// The resulting `SrcLoc` should only be used ephemerally, as it is not correct across incremental updates.
    pub fn upgrade(lazy: LazySrcLoc, zcu: *Zcu) SrcLoc {
        return lazy.upgradeOrLost(zcu).?;
    }

    /// Like `upgrade`, but returns `null` if the source location has been lost across incremental updates.
    pub fn upgradeOrLost(lazy: LazySrcLoc, zcu: *Zcu) ?SrcLoc {
        const file, const base_node: Ast.Node.Index = if (lazy.offset == .entire_file) .{
            zcu.fileByIndex(lazy.base_node_inst.resolveFile(&zcu.intern_pool)),
            0,
        } else resolveBaseNode(lazy.base_node_inst, zcu) orelse return null;
        return .{
            .file_scope = file,
            .base_node = base_node,
            .lazy = lazy.offset,
        };
    }
};

pub const SemaError = error{ OutOfMemory, AnalysisFail };
pub const CompileError = error{
    OutOfMemory,
    /// When this is returned, the compile error for the failure has already been recorded.
    AnalysisFail,
    /// In a comptime scope, a return instruction was encountered. This error is only seen when
    /// doing a comptime function call.
    ComptimeReturn,
    /// In a comptime scope, a break instruction was encountered. This error is only seen when
    /// evaluating a comptime block.
    ComptimeBreak,
};

pub fn init(zcu: *Zcu, thread_count: usize) !void {
    const gpa = zcu.gpa;
    try zcu.intern_pool.init(gpa, thread_count);
}

pub fn deinit(zcu: *Zcu) void {
    const gpa = zcu.gpa;
    {
        const pt: Zcu.PerThread = .activate(zcu, .main);
        defer pt.deactivate();

        if (zcu.llvm_object) |llvm_object| llvm_object.deinit();

        for (zcu.import_table.keys()) |key| {
            gpa.free(key);
        }
        for (zcu.import_table.values()) |file_index| {
            pt.destroyFile(file_index);
        }
        zcu.import_table.deinit(gpa);

        for (zcu.embed_table.keys(), zcu.embed_table.values()) |path, embed_file| {
            gpa.free(path);
            gpa.destroy(embed_file);
        }
        zcu.embed_table.deinit(gpa);

        zcu.compile_log_text.deinit(gpa);

        zcu.local_zir_cache.handle.close();
        zcu.global_zir_cache.handle.close();

        for (zcu.failed_analysis.values()) |value| value.destroy(gpa);
        for (zcu.failed_codegen.values()) |value| value.destroy(gpa);
        for (zcu.failed_types.values()) |value| value.destroy(gpa);
        zcu.analysis_in_progress.deinit(gpa);
        zcu.failed_analysis.deinit(gpa);
        zcu.transitive_failed_analysis.deinit(gpa);
        zcu.failed_codegen.deinit(gpa);
        zcu.failed_types.deinit(gpa);

        for (zcu.failed_files.values()) |value| {
            if (value) |msg| msg.destroy(gpa);
        }
        zcu.failed_files.deinit(gpa);

        for (zcu.failed_exports.values()) |value| {
            value.destroy(gpa);
        }
        zcu.failed_exports.deinit(gpa);

        for (zcu.cimport_errors.values()) |*errs| {
            errs.deinit(gpa);
        }
        zcu.cimport_errors.deinit(gpa);

        zcu.compile_log_sources.deinit(gpa);

        zcu.all_exports.deinit(gpa);
        zcu.free_exports.deinit(gpa);
        zcu.single_exports.deinit(gpa);
        zcu.multi_exports.deinit(gpa);

        zcu.potentially_outdated.deinit(gpa);
        zcu.outdated.deinit(gpa);
        zcu.outdated_ready.deinit(gpa);
        zcu.retryable_failures.deinit(gpa);

        zcu.func_body_analysis_queued.deinit(gpa);
        zcu.nav_val_analysis_queued.deinit(gpa);

        zcu.test_functions.deinit(gpa);

        for (zcu.global_assembly.values()) |s| {
            gpa.free(s);
        }
        zcu.global_assembly.deinit(gpa);

        zcu.reference_table.deinit(gpa);
        zcu.all_references.deinit(gpa);
        zcu.free_references.deinit(gpa);

        zcu.type_reference_table.deinit(gpa);
        zcu.all_type_references.deinit(gpa);
        zcu.free_type_references.deinit(gpa);

        if (zcu.resolved_references) |*r| r.deinit(gpa);
    }
    zcu.intern_pool.deinit(gpa);
}

pub fn namespacePtr(zcu: *Zcu, index: Namespace.Index) *Namespace {
    return zcu.intern_pool.namespacePtr(index);
}

pub fn namespacePtrUnwrap(zcu: *Zcu, index: Namespace.OptionalIndex) ?*Namespace {
    return zcu.namespacePtr(index.unwrap() orelse return null);
}

// TODO https://github.com/ziglang/zig/issues/8643
pub const data_has_safety_tag = @sizeOf(Zir.Inst.Data) != 8;
pub const HackDataLayout = extern struct {
    data: [8]u8 align(@alignOf(Zir.Inst.Data)),
    safety_tag: u8,
};
comptime {
    if (data_has_safety_tag) {
        assert(@sizeOf(HackDataLayout) == @sizeOf(Zir.Inst.Data));
    }
}

pub fn loadZirCache(gpa: Allocator, cache_file: std.fs.File) !Zir {
    return loadZirCacheBody(gpa, try cache_file.reader().readStruct(Zir.Header), cache_file);
}

pub fn loadZirCacheBody(gpa: Allocator, header: Zir.Header, cache_file: std.fs.File) !Zir {
    var instructions: std.MultiArrayList(Zir.Inst) = .{};
    errdefer instructions.deinit(gpa);

    try instructions.setCapacity(gpa, header.instructions_len);
    instructions.len = header.instructions_len;

    var zir: Zir = .{
        .instructions = instructions.toOwnedSlice(),
        .string_bytes = &.{},
        .extra = &.{},
    };
    errdefer zir.deinit(gpa);

    zir.string_bytes = try gpa.alloc(u8, header.string_bytes_len);
    zir.extra = try gpa.alloc(u32, header.extra_len);

    const safety_buffer = if (data_has_safety_tag)
        try gpa.alloc([8]u8, header.instructions_len)
    else
        undefined;
    defer if (data_has_safety_tag) gpa.free(safety_buffer);

    const data_ptr = if (data_has_safety_tag)
        @as([*]u8, @ptrCast(safety_buffer.ptr))
    else
        @as([*]u8, @ptrCast(zir.instructions.items(.data).ptr));

    var iovecs = [_]std.posix.iovec{
        .{
            .base = @as([*]u8, @ptrCast(zir.instructions.items(.tag).ptr)),
            .len = header.instructions_len,
        },
        .{
            .base = data_ptr,
            .len = header.instructions_len * 8,
        },
        .{
            .base = zir.string_bytes.ptr,
            .len = header.string_bytes_len,
        },
        .{
            .base = @as([*]u8, @ptrCast(zir.extra.ptr)),
            .len = header.extra_len * 4,
        },
    };
    const amt_read = try cache_file.readvAll(&iovecs);
    const amt_expected = zir.instructions.len * 9 +
        zir.string_bytes.len +
        zir.extra.len * 4;
    if (amt_read != amt_expected) return error.UnexpectedFileSize;
    if (data_has_safety_tag) {
        const tags = zir.instructions.items(.tag);
        for (zir.instructions.items(.data), 0..) |*data, i| {
            const union_tag = Zir.Inst.Tag.data_tags[@intFromEnum(tags[i])];
            const as_struct = @as(*HackDataLayout, @ptrCast(data));
            as_struct.* = .{
                .safety_tag = @intFromEnum(union_tag),
                .data = safety_buffer[i],
            };
        }
    }

    return zir;
}

pub fn saveZirCache(gpa: Allocator, cache_file: std.fs.File, stat: std.fs.File.Stat, zir: Zir) (std.fs.File.WriteError || Allocator.Error)!void {
    const safety_buffer = if (data_has_safety_tag)
        try gpa.alloc([8]u8, zir.instructions.len)
    else
        undefined;
    defer if (data_has_safety_tag) gpa.free(safety_buffer);

    const data_ptr: [*]const u8 = if (data_has_safety_tag)
        if (zir.instructions.len == 0)
            undefined
        else
            @ptrCast(safety_buffer.ptr)
    else
        @ptrCast(zir.instructions.items(.data).ptr);

    if (data_has_safety_tag) {
        // The `Data` union has a safety tag but in the file format we store it without.
        for (zir.instructions.items(.data), 0..) |*data, i| {
            const as_struct: *const HackDataLayout = @ptrCast(data);
            safety_buffer[i] = as_struct.data;
        }
    }

    const header: Zir.Header = .{
        .instructions_len = @intCast(zir.instructions.len),
        .string_bytes_len = @intCast(zir.string_bytes.len),
        .extra_len = @intCast(zir.extra.len),

        .stat_size = stat.size,
        .stat_inode = stat.inode,
        .stat_mtime = stat.mtime,
    };
    var iovecs: [5]std.posix.iovec_const = .{
        .{
            .base = @ptrCast(&header),
            .len = @sizeOf(Zir.Header),
        },
        .{
            .base = @ptrCast(zir.instructions.items(.tag).ptr),
            .len = zir.instructions.len,
        },
        .{
            .base = data_ptr,
            .len = zir.instructions.len * 8,
        },
        .{
            .base = zir.string_bytes.ptr,
            .len = zir.string_bytes.len,
        },
        .{
            .base = @ptrCast(zir.extra.ptr),
            .len = zir.extra.len * 4,
        },
    };
    try cache_file.writevAll(&iovecs);
}

pub fn saveZoirCache(cache_file: std.fs.File, stat: std.fs.File.Stat, zoir: Zoir) std.fs.File.WriteError!void {
    const header: Zoir.Header = .{
        .nodes_len = @intCast(zoir.nodes.len),
        .extra_len = @intCast(zoir.extra.len),
        .limbs_len = @intCast(zoir.limbs.len),
        .string_bytes_len = @intCast(zoir.string_bytes.len),
        .compile_errors_len = @intCast(zoir.compile_errors.len),
        .error_notes_len = @intCast(zoir.error_notes.len),

        .stat_size = stat.size,
        .stat_inode = stat.inode,
        .stat_mtime = stat.mtime,
    };
    var iovecs: [9]std.posix.iovec_const = .{
        .{
            .base = @ptrCast(&header),
            .len = @sizeOf(Zoir.Header),
        },
        .{
            .base = @ptrCast(zoir.nodes.items(.tag)),
            .len = zoir.nodes.len * @sizeOf(Zoir.Node.Repr.Tag),
        },
        .{
            .base = @ptrCast(zoir.nodes.items(.data)),
            .len = zoir.nodes.len * 4,
        },
        .{
            .base = @ptrCast(zoir.nodes.items(.ast_node)),
            .len = zoir.nodes.len * 4,
        },
        .{
            .base = @ptrCast(zoir.extra),
            .len = zoir.extra.len * 4,
        },
        .{
            .base = @ptrCast(zoir.limbs),
            .len = zoir.limbs.len * 4,
        },
        .{
            .base = zoir.string_bytes.ptr,
            .len = zoir.string_bytes.len,
        },
        .{
            .base = @ptrCast(zoir.compile_errors),
            .len = zoir.compile_errors.len * @sizeOf(Zoir.CompileError),
        },
        .{
            .base = @ptrCast(zoir.error_notes),
            .len = zoir.error_notes.len * @sizeOf(Zoir.CompileError.Note),
        },
    };
    try cache_file.writevAll(&iovecs);
}

pub fn loadZoirCacheBody(gpa: Allocator, header: Zoir.Header, cache_file: std.fs.File) !Zoir {
    var zoir: Zoir = .{
        .nodes = .empty,
        .extra = &.{},
        .limbs = &.{},
        .string_bytes = &.{},
        .compile_errors = &.{},
        .error_notes = &.{},
    };
    errdefer zoir.deinit(gpa);

    zoir.nodes = nodes: {
        var nodes: std.MultiArrayList(Zoir.Node.Repr) = .empty;
        defer nodes.deinit(gpa);
        try nodes.setCapacity(gpa, header.nodes_len);
        nodes.len = header.nodes_len;
        break :nodes nodes.toOwnedSlice();
    };

    zoir.extra = try gpa.alloc(u32, header.extra_len);
    zoir.limbs = try gpa.alloc(std.math.big.Limb, header.limbs_len);
    zoir.string_bytes = try gpa.alloc(u8, header.string_bytes_len);

    zoir.compile_errors = try gpa.alloc(Zoir.CompileError, header.compile_errors_len);
    zoir.error_notes = try gpa.alloc(Zoir.CompileError.Note, header.error_notes_len);

    var iovecs: [8]std.posix.iovec = .{
        .{
            .base = @ptrCast(zoir.nodes.items(.tag)),
            .len = header.nodes_len * @sizeOf(Zoir.Node.Repr.Tag),
        },
        .{
            .base = @ptrCast(zoir.nodes.items(.data)),
            .len = header.nodes_len * 4,
        },
        .{
            .base = @ptrCast(zoir.nodes.items(.ast_node)),
            .len = header.nodes_len * 4,
        },
        .{
            .base = @ptrCast(zoir.extra),
            .len = header.extra_len * 4,
        },
        .{
            .base = @ptrCast(zoir.limbs),
            .len = header.limbs_len * @sizeOf(std.math.big.Limb),
        },
        .{
            .base = zoir.string_bytes.ptr,
            .len = header.string_bytes_len,
        },
        .{
            .base = @ptrCast(zoir.compile_errors),
            .len = header.compile_errors_len * @sizeOf(Zoir.CompileError),
        },
        .{
            .base = @ptrCast(zoir.error_notes),
            .len = header.error_notes_len * @sizeOf(Zoir.CompileError.Note),
        },
    };

    const bytes_expected = expected: {
        var n: usize = 0;
        for (iovecs) |v| n += v.len;
        break :expected n;
    };

    const bytes_read = try cache_file.readvAll(&iovecs);
    if (bytes_read != bytes_expected) return error.UnexpectedFileSize;
    return zoir;
}

pub fn markDependeeOutdated(
    zcu: *Zcu,
    /// When we are diffing ZIR and marking things as outdated, we won't yet have marked the dependencies as PO.
    /// However, when we discover during analysis that something was outdated, the `Dependee` was already
    /// marked as PO, so we need to decrement the PO dep count for each depender.
    marked_po: enum { not_marked_po, marked_po },
    dependee: InternPool.Dependee,
) !void {
    log.debug("outdated dependee: {}", .{zcu.fmtDependee(dependee)});
    var it = zcu.intern_pool.dependencyIterator(dependee);
    while (it.next()) |depender| {
        if (zcu.outdated.getPtr(depender)) |po_dep_count| {
            switch (marked_po) {
                .not_marked_po => {},
                .marked_po => {
                    po_dep_count.* -= 1;
                    log.debug("outdated {} => already outdated {} po_deps={}", .{ zcu.fmtDependee(dependee), zcu.fmtAnalUnit(depender), po_dep_count.* });
                    if (po_dep_count.* == 0) {
                        log.debug("outdated ready: {}", .{zcu.fmtAnalUnit(depender)});
                        try zcu.outdated_ready.put(zcu.gpa, depender, {});
                    }
                },
            }
            continue;
        }
        const opt_po_entry = zcu.potentially_outdated.fetchSwapRemove(depender);
        const new_po_dep_count = switch (marked_po) {
            .not_marked_po => if (opt_po_entry) |e| e.value else 0,
            .marked_po => if (opt_po_entry) |e| e.value - 1 else {
                // This `AnalUnit` has already been re-analyzed this update, and registered a dependency
                // on this thing, but already has sufficiently up-to-date information. Nothing to do.
                continue;
            },
        };
        try zcu.outdated.putNoClobber(
            zcu.gpa,
            depender,
            new_po_dep_count,
        );
        log.debug("outdated {} => new outdated {} po_deps={}", .{ zcu.fmtDependee(dependee), zcu.fmtAnalUnit(depender), new_po_dep_count });
        if (new_po_dep_count == 0) {
            log.debug("outdated ready: {}", .{zcu.fmtAnalUnit(depender)});
            try zcu.outdated_ready.put(zcu.gpa, depender, {});
        }
        // If this is a Decl and was not previously PO, we must recursively
        // mark dependencies on its tyval as PO.
        if (opt_po_entry == null) {
            assert(marked_po == .not_marked_po);
            try zcu.markTransitiveDependersPotentiallyOutdated(depender);
        }
    }
}

pub fn markPoDependeeUpToDate(zcu: *Zcu, dependee: InternPool.Dependee) !void {
    log.debug("up-to-date dependee: {}", .{zcu.fmtDependee(dependee)});
    var it = zcu.intern_pool.dependencyIterator(dependee);
    while (it.next()) |depender| {
        if (zcu.outdated.getPtr(depender)) |po_dep_count| {
            // This depender is already outdated, but it now has one
            // less PO dependency!
            po_dep_count.* -= 1;
            log.debug("up-to-date {} => {} po_deps={}", .{ zcu.fmtDependee(dependee), zcu.fmtAnalUnit(depender), po_dep_count.* });
            if (po_dep_count.* == 0) {
                log.debug("outdated ready: {}", .{zcu.fmtAnalUnit(depender)});
                try zcu.outdated_ready.put(zcu.gpa, depender, {});
            }
            continue;
        }
        // This depender is definitely at least PO, because this Decl was just analyzed
        // due to being outdated.
        const ptr = zcu.potentially_outdated.getPtr(depender) orelse {
            // This dependency has been registered during in-progress analysis, but the unit is
            // not in `potentially_outdated` because analysis is in-progress. Nothing to do.
            continue;
        };
        if (ptr.* > 1) {
            ptr.* -= 1;
            log.debug("up-to-date {} => {} po_deps={}", .{ zcu.fmtDependee(dependee), zcu.fmtAnalUnit(depender), ptr.* });
            continue;
        }

        log.debug("up-to-date {} => {} po_deps=0 (up-to-date)", .{ zcu.fmtDependee(dependee), zcu.fmtAnalUnit(depender) });

        // This dependency is no longer PO, i.e. is known to be up-to-date.
        assert(zcu.potentially_outdated.swapRemove(depender));
        // If this is a Decl, we must recursively mark dependencies on its tyval
        // as no longer PO.
        switch (depender.unwrap()) {
            .@"comptime" => {},
            .nav_val => |nav| try zcu.markPoDependeeUpToDate(.{ .nav_val = nav }),
            .nav_ty => |nav| try zcu.markPoDependeeUpToDate(.{ .nav_ty = nav }),
            .type => |ty| try zcu.markPoDependeeUpToDate(.{ .interned = ty }),
            .func => |func| try zcu.markPoDependeeUpToDate(.{ .interned = func }),
            .memoized_state => |stage| try zcu.markPoDependeeUpToDate(.{ .memoized_state = stage }),
        }
    }
}

/// Given a AnalUnit which is newly outdated or PO, mark all AnalUnits which may
/// in turn be PO, due to a dependency on the original AnalUnit's tyval or IES.
fn markTransitiveDependersPotentiallyOutdated(zcu: *Zcu, maybe_outdated: AnalUnit) !void {
    const ip = &zcu.intern_pool;
    const dependee: InternPool.Dependee = switch (maybe_outdated.unwrap()) {
        .@"comptime" => return, // analysis of a comptime decl can't outdate any dependencies
        .nav_val => |nav| .{ .nav_val = nav },
        .nav_ty => |nav| .{ .nav_ty = nav },
        .type => |ty| .{ .interned = ty },
        .func => |func_index| .{ .interned = func_index }, // IES
        .memoized_state => |stage| .{ .memoized_state = stage },
    };
    log.debug("potentially outdated dependee: {}", .{zcu.fmtDependee(dependee)});
    var it = ip.dependencyIterator(dependee);
    while (it.next()) |po| {
        if (zcu.outdated.getPtr(po)) |po_dep_count| {
            // This dependency is already outdated, but it now has one more PO
            // dependency.
            if (po_dep_count.* == 0) {
                _ = zcu.outdated_ready.swapRemove(po);
            }
            po_dep_count.* += 1;
            log.debug("po {} => {} [outdated] po_deps={}", .{ zcu.fmtDependee(dependee), zcu.fmtAnalUnit(po), po_dep_count.* });
            continue;
        }
        if (zcu.potentially_outdated.getPtr(po)) |n| {
            // There is now one more PO dependency.
            n.* += 1;
            log.debug("po {} => {} po_deps={}", .{ zcu.fmtDependee(dependee), zcu.fmtAnalUnit(po), n.* });
            continue;
        }
        try zcu.potentially_outdated.putNoClobber(zcu.gpa, po, 1);
        log.debug("po {} => {} po_deps=1", .{ zcu.fmtDependee(dependee), zcu.fmtAnalUnit(po) });
        // This AnalUnit was not already PO, so we must recursively mark its dependers as also PO.
        try zcu.markTransitiveDependersPotentiallyOutdated(po);
    }
}

pub fn findOutdatedToAnalyze(zcu: *Zcu) Allocator.Error!?AnalUnit {
    if (!zcu.comp.incremental) return null;

    if (zcu.outdated.count() == 0) {
        // Any units in `potentially_outdated` must just be stuck in loops with one another: none of those
        // units have had any outdated dependencies so far, and all of their remaining PO deps are triggered
        // by other units in `potentially_outdated`. So, we can safety assume those units up-to-date.
        zcu.potentially_outdated.clearRetainingCapacity();
        log.debug("findOutdatedToAnalyze: no outdated depender", .{});
        return null;
    }

    // Our goal is to find an outdated AnalUnit which itself has no outdated or
    // PO dependencies. Most of the time, such an AnalUnit will exist - we track
    // them in the `outdated_ready` set for efficiency. However, this is not
    // necessarily the case, since the Decl dependency graph may contain loops
    // via mutually recursive definitions:
    //   pub const A = struct { b: *B };
    //   pub const B = struct { b: *A };
    // In this case, we must defer to more complex logic below.

    if (zcu.outdated_ready.count() > 0) {
        const unit = zcu.outdated_ready.keys()[0];
        log.debug("findOutdatedToAnalyze: trivial {}", .{zcu.fmtAnalUnit(unit)});
        return unit;
    }

    // There is no single AnalUnit which is ready for re-analysis. Instead, we must assume that some
    // AnalUnit with PO dependencies is outdated -- e.g. in the above example we arbitrarily pick one of
    // A or B. We should definitely not select a function, since a function can't be responsible for the
    // loop (IES dependencies can't have loops). We should also, of course, not select a `comptime`
    // declaration, since you can't depend on those!

    // The choice of this unit could have a big impact on how much total analysis we perform, since
    // if analysis concludes any dependencies on its result are up-to-date, then other PO AnalUnit
    // may be resolved as up-to-date. To hopefully avoid doing too much work, let's find a unit
    // which the most things depend on - the idea is that this will resolve a lot of loops (but this
    // is only a heuristic).

    log.debug("findOutdatedToAnalyze: no trivial ready, using heuristic; {d} outdated, {d} PO", .{
        zcu.outdated.count(),
        zcu.potentially_outdated.count(),
    });

    const ip = &zcu.intern_pool;

    var chosen_unit: ?AnalUnit = null;
    var chosen_unit_dependers: u32 = undefined;

    inline for (.{ zcu.outdated.keys(), zcu.potentially_outdated.keys() }) |outdated_units| {
        for (outdated_units) |unit| {
            var n: u32 = 0;
            var it = ip.dependencyIterator(switch (unit.unwrap()) {
                .func => continue, // a `func` definitely can't be causing the loop so it is a bad choice
                .@"comptime" => continue, // a `comptime` block can't even be depended on so it is a terrible choice
                .type => |ty| .{ .interned = ty },
                .nav_val => |nav| .{ .nav_val = nav },
                .nav_ty => |nav| .{ .nav_ty = nav },
                .memoized_state => {
                    // If we've hit a loop and some `.memoized_state` is outdated, we should make that choice eagerly.
                    // In general, it's good to resolve this early on, since -- for instance -- almost every function
                    // references the panic handler.
                    return unit;
                },
            });
            while (it.next()) |_| n += 1;

            if (chosen_unit == null or n > chosen_unit_dependers) {
                chosen_unit = unit;
                chosen_unit_dependers = n;
            }
        }
    }

    log.debug("findOutdatedToAnalyze: heuristic returned '{}' ({d} dependers)", .{
        zcu.fmtAnalUnit(chosen_unit.?),
        chosen_unit_dependers,
    });

    return chosen_unit.?;
}

/// During an incremental update, before semantic analysis, call this to flush all values from
/// `retryable_failures` and mark them as outdated so they get re-analyzed.
pub fn flushRetryableFailures(zcu: *Zcu) !void {
    const gpa = zcu.gpa;
    for (zcu.retryable_failures.items) |depender| {
        if (zcu.outdated.contains(depender)) continue;
        if (zcu.potentially_outdated.fetchSwapRemove(depender)) |kv| {
            // This AnalUnit was already PO, but we now consider it outdated.
            // Any transitive dependencies are already marked PO.
            try zcu.outdated.put(gpa, depender, kv.value);
            continue;
        }
        // This AnalUnit was not marked PO, but is now outdated. Mark it as
        // such, then recursively mark transitive dependencies as PO.
        try zcu.outdated.put(gpa, depender, 0);
        try zcu.markTransitiveDependersPotentiallyOutdated(depender);
    }
    zcu.retryable_failures.clearRetainingCapacity();
}

pub fn mapOldZirToNew(
    gpa: Allocator,
    old_zir: Zir,
    new_zir: Zir,
    inst_map: *std.AutoHashMapUnmanaged(Zir.Inst.Index, Zir.Inst.Index),
) Allocator.Error!void {
    // Contain ZIR indexes of namespace declaration instructions, e.g. struct_decl, union_decl, etc.
    // Not `declaration`, as this does not create a namespace.
    const MatchedZirDecl = struct {
        old_inst: Zir.Inst.Index,
        new_inst: Zir.Inst.Index,
    };
    var match_stack: std.ArrayListUnmanaged(MatchedZirDecl) = .empty;
    defer match_stack.deinit(gpa);

    // Used as temporary buffers for namespace declaration instructions
    var old_contents: Zir.DeclContents = .init;
    defer old_contents.deinit(gpa);
    var new_contents: Zir.DeclContents = .init;
    defer new_contents.deinit(gpa);

    // Map the main struct inst (and anything in its fields)
    {
        try old_zir.findTrackableRoot(gpa, &old_contents);
        try new_zir.findTrackableRoot(gpa, &new_contents);

        assert(old_contents.explicit_types.items[0] == .main_struct_inst);
        assert(new_contents.explicit_types.items[0] == .main_struct_inst);

        assert(old_contents.func_decl == null);
        assert(new_contents.func_decl == null);

        // We don't have any smart way of matching up these instructions, so we correlate them based on source order
        // in their respective arrays.

        const num_explicit_types = @min(old_contents.explicit_types.items.len, new_contents.explicit_types.items.len);
        try match_stack.ensureUnusedCapacity(gpa, @intCast(num_explicit_types));
        for (
            old_contents.explicit_types.items[0..num_explicit_types],
            new_contents.explicit_types.items[0..num_explicit_types],
        ) |old_inst, new_inst| {
            // Here we use `match_stack`, so that we will recursively consider declarations on these types.
            match_stack.appendAssumeCapacity(.{ .old_inst = old_inst, .new_inst = new_inst });
        }

        const num_other = @min(old_contents.other.items.len, new_contents.other.items.len);
        try inst_map.ensureUnusedCapacity(gpa, @intCast(num_other));
        for (
            old_contents.other.items[0..num_other],
            new_contents.other.items[0..num_other],
        ) |old_inst, new_inst| {
            // These instructions don't have declarations, so we just modify `inst_map` directly.
            inst_map.putAssumeCapacity(old_inst, new_inst);
        }
    }

    while (match_stack.pop()) |match_item| {
        // First, a check: if the number of captures of this type has changed, we can't map it, because
        // we wouldn't know how to correlate type information with the last update.
        // Synchronizes with logic in `Zcu.PerThread.recreateStructType` etc.
        if (old_zir.typeCapturesLen(match_item.old_inst) != new_zir.typeCapturesLen(match_item.new_inst)) {
            // Don't map this type or anything within it.
            continue;
        }

        // Match the namespace declaration itself
        try inst_map.put(gpa, match_item.old_inst, match_item.new_inst);

        // Maps decl name to `declaration` instruction.
        var named_decls: std.StringHashMapUnmanaged(Zir.Inst.Index) = .empty;
        defer named_decls.deinit(gpa);
        // Maps test name to `declaration` instruction.
        var named_tests: std.StringHashMapUnmanaged(Zir.Inst.Index) = .empty;
        defer named_tests.deinit(gpa);
        // Maps test name to `declaration` instruction.
        var named_decltests: std.StringHashMapUnmanaged(Zir.Inst.Index) = .empty;
        defer named_decltests.deinit(gpa);
        // All unnamed tests, in order, for a best-effort match.
        var unnamed_tests: std.ArrayListUnmanaged(Zir.Inst.Index) = .empty;
        defer unnamed_tests.deinit(gpa);
        // All comptime declarations, in order, for a best-effort match.
        var comptime_decls: std.ArrayListUnmanaged(Zir.Inst.Index) = .empty;
        defer comptime_decls.deinit(gpa);
        // All usingnamespace declarations, in order, for a best-effort match.
        var usingnamespace_decls: std.ArrayListUnmanaged(Zir.Inst.Index) = .empty;
        defer usingnamespace_decls.deinit(gpa);

        {
            var old_decl_it = old_zir.declIterator(match_item.old_inst);
            while (old_decl_it.next()) |old_decl_inst| {
                const old_decl = old_zir.getDeclaration(old_decl_inst);
                switch (old_decl.kind) {
                    .@"comptime" => try comptime_decls.append(gpa, old_decl_inst),
                    .@"usingnamespace" => try usingnamespace_decls.append(gpa, old_decl_inst),
                    .unnamed_test => try unnamed_tests.append(gpa, old_decl_inst),
                    .@"test" => try named_tests.put(gpa, old_zir.nullTerminatedString(old_decl.name), old_decl_inst),
                    .decltest => try named_decltests.put(gpa, old_zir.nullTerminatedString(old_decl.name), old_decl_inst),
                    .@"const", .@"var" => try named_decls.put(gpa, old_zir.nullTerminatedString(old_decl.name), old_decl_inst),
                }
            }
        }

        var unnamed_test_idx: u32 = 0;
        var comptime_decl_idx: u32 = 0;
        var usingnamespace_decl_idx: u32 = 0;

        var new_decl_it = new_zir.declIterator(match_item.new_inst);
        while (new_decl_it.next()) |new_decl_inst| {
            const new_decl = new_zir.getDeclaration(new_decl_inst);
            // Attempt to match this to a declaration in the old ZIR:
            // * For named declarations (`const`/`var`/`fn`), we match based on name.
            // * For named tests (`test "foo"`) and decltests (`test foo`), we also match based on name.
            // * For unnamed tests, we match based on order.
            // * For comptime blocks, we match based on order.
            // * For usingnamespace decls, we match based on order.
            // If we cannot match this declaration, we can't match anything nested inside of it either, so we just `continue`.
            const old_decl_inst = switch (new_decl.kind) {
                .@"comptime" => inst: {
                    if (comptime_decl_idx == comptime_decls.items.len) continue;
                    defer comptime_decl_idx += 1;
                    break :inst comptime_decls.items[comptime_decl_idx];
                },
                .@"usingnamespace" => inst: {
                    if (usingnamespace_decl_idx == usingnamespace_decls.items.len) continue;
                    defer usingnamespace_decl_idx += 1;
                    break :inst usingnamespace_decls.items[usingnamespace_decl_idx];
                },
                .unnamed_test => inst: {
                    if (unnamed_test_idx == unnamed_tests.items.len) continue;
                    defer unnamed_test_idx += 1;
                    break :inst unnamed_tests.items[unnamed_test_idx];
                },
                .@"test" => inst: {
                    const name = new_zir.nullTerminatedString(new_decl.name);
                    break :inst named_tests.get(name) orelse continue;
                },
                .decltest => inst: {
                    const name = new_zir.nullTerminatedString(new_decl.name);
                    break :inst named_decltests.get(name) orelse continue;
                },
                .@"const", .@"var" => inst: {
                    const name = new_zir.nullTerminatedString(new_decl.name);
                    break :inst named_decls.get(name) orelse continue;
                },
            };

            // Match the `declaration` instruction
            try inst_map.put(gpa, old_decl_inst, new_decl_inst);

            // Find trackable instructions within this declaration
            try old_zir.findTrackable(gpa, &old_contents, old_decl_inst);
            try new_zir.findTrackable(gpa, &new_contents, new_decl_inst);

            // We don't have any smart way of matching up these instructions, so we correlate them based on source order
            // in their respective arrays.

            const num_explicit_types = @min(old_contents.explicit_types.items.len, new_contents.explicit_types.items.len);
            try match_stack.ensureUnusedCapacity(gpa, @intCast(num_explicit_types));
            for (
                old_contents.explicit_types.items[0..num_explicit_types],
                new_contents.explicit_types.items[0..num_explicit_types],
            ) |old_inst, new_inst| {
                // Here we use `match_stack`, so that we will recursively consider declarations on these types.
                match_stack.appendAssumeCapacity(.{ .old_inst = old_inst, .new_inst = new_inst });
            }

            const num_other = @min(old_contents.other.items.len, new_contents.other.items.len);
            try inst_map.ensureUnusedCapacity(gpa, @intCast(num_other));
            for (
                old_contents.other.items[0..num_other],
                new_contents.other.items[0..num_other],
            ) |old_inst, new_inst| {
                // These instructions don't have declarations, so we just modify `inst_map` directly.
                inst_map.putAssumeCapacity(old_inst, new_inst);
            }

            if (old_contents.func_decl) |old_func_inst| {
                if (new_contents.func_decl) |new_func_inst| {
                    // There are no declarations on a function either, so again, we just directly add it to `inst_map`.
                    try inst_map.put(gpa, old_func_inst, new_func_inst);
                }
            }
        }
    }
}

/// Ensure this function's body is or will be analyzed and emitted. This should
/// be called whenever a potential runtime call of a function is seen.
///
/// The caller is responsible for ensuring the function decl itself is already
/// analyzed, and for ensuring it can exist at runtime (see
/// `Type.fnHasRuntimeBitsSema`). This function does *not* guarantee that the body
/// will be analyzed when it returns: for that, see `ensureFuncBodyAnalyzed`.
pub fn ensureFuncBodyAnalysisQueued(zcu: *Zcu, func_index: InternPool.Index) !void {
    const ip = &zcu.intern_pool;
    const func = zcu.funcInfo(func_index);

    if (zcu.func_body_analysis_queued.contains(func_index)) return;

    if (func.analysisUnordered(ip).is_analyzed) {
        if (!zcu.outdated.contains(.wrap(.{ .func = func_index })) and
            !zcu.potentially_outdated.contains(.wrap(.{ .func = func_index })))
        {
            // This function has been analyzed before and is definitely up-to-date.
            return;
        }
    }

    try zcu.func_body_analysis_queued.ensureUnusedCapacity(zcu.gpa, 1);
    try zcu.comp.queueJob(.{ .analyze_func = func_index });
    zcu.func_body_analysis_queued.putAssumeCapacityNoClobber(func_index, {});
}

pub fn ensureNavValAnalysisQueued(zcu: *Zcu, nav_id: InternPool.Nav.Index) !void {
    const ip = &zcu.intern_pool;

    if (zcu.nav_val_analysis_queued.contains(nav_id)) return;

    if (ip.getNav(nav_id).status == .fully_resolved) {
        if (!zcu.outdated.contains(.wrap(.{ .nav_val = nav_id })) and
            !zcu.potentially_outdated.contains(.wrap(.{ .nav_val = nav_id })))
        {
            // This `Nav` has been analyzed before and is definitely up-to-date.
            return;
        }
    }

    try zcu.nav_val_analysis_queued.ensureUnusedCapacity(zcu.gpa, 1);
    try zcu.comp.queueJob(.{ .analyze_comptime_unit = .wrap(.{ .nav_val = nav_id }) });
    zcu.nav_val_analysis_queued.putAssumeCapacityNoClobber(nav_id, {});
}

pub const ImportFileResult = struct {
    file: *File,
    file_index: File.Index,
    is_new: bool,
    is_pkg: bool,
};

pub fn computePathDigest(zcu: *Zcu, mod: *Package.Module, sub_file_path: []const u8) Cache.BinDigest {
    const want_local_cache = mod == zcu.main_mod;
    var path_hash: Cache.HashHelper = .{};
    path_hash.addBytes(build_options.version);
    path_hash.add(builtin.zig_backend);
    if (!want_local_cache) {
        path_hash.addOptionalBytes(mod.root.root_dir.path);
        path_hash.addBytes(mod.root.sub_path);
    }
    path_hash.addBytes(sub_file_path);
    var bin: Cache.BinDigest = undefined;
    path_hash.hasher.final(&bin);
    return bin;
}

/// Delete all the Export objects that are caused by this `AnalUnit`. Re-analysis of
/// this `AnalUnit` will cause them to be re-created (or not).
pub fn deleteUnitExports(zcu: *Zcu, anal_unit: AnalUnit) void {
    const gpa = zcu.gpa;

    const exports_base, const exports_len = if (zcu.single_exports.fetchSwapRemove(anal_unit)) |kv|
        .{ @intFromEnum(kv.value), 1 }
    else if (zcu.multi_exports.fetchSwapRemove(anal_unit)) |info|
        .{ info.value.index, info.value.len }
    else
        return;

    const exports = zcu.all_exports.items[exports_base..][0..exports_len];

    // In an only-c build, we're guaranteed to never use incremental compilation, so there are
    // guaranteed not to be any exports in the output file that need deleting (since we only call
    // `updateExports` on flush).
    // This case is needed because in some rare edge cases, `Sema` wants to add and delete exports
    // within a single update.
    if (dev.env.supports(.incremental)) {
        for (exports, exports_base..) |exp, export_index_usize| {
            const export_idx: Export.Index = @enumFromInt(export_index_usize);
            if (zcu.comp.bin_file) |lf| {
                lf.deleteExport(exp.exported, exp.opts.name);
            }
            if (zcu.failed_exports.fetchSwapRemove(export_idx)) |failed_kv| {
                failed_kv.value.destroy(gpa);
            }
        }
    }

    zcu.free_exports.ensureUnusedCapacity(gpa, exports_len) catch {
        // This space will be reused eventually, so we need not propagate this error.
        // Just leak it for now, and let GC reclaim it later on.
        return;
    };
    for (exports_base..exports_base + exports_len) |export_idx| {
        zcu.free_exports.appendAssumeCapacity(@enumFromInt(export_idx));
    }
}

/// Delete all references in `reference_table` which are caused by this `AnalUnit`.
/// Re-analysis of the `AnalUnit` will cause appropriate references to be recreated.
pub fn deleteUnitReferences(zcu: *Zcu, anal_unit: AnalUnit) void {
    const gpa = zcu.gpa;

    zcu.clearCachedResolvedReferences();

    unit_refs: {
        const kv = zcu.reference_table.fetchSwapRemove(anal_unit) orelse break :unit_refs;
        var idx = kv.value;

        while (idx != std.math.maxInt(u32)) {
            zcu.free_references.append(gpa, idx) catch {
                // This space will be reused eventually, so we need not propagate this error.
                // Just leak it for now, and let GC reclaim it later on.
                break :unit_refs;
            };
            idx = zcu.all_references.items[idx].next;
        }
    }

    type_refs: {
        const kv = zcu.type_reference_table.fetchSwapRemove(anal_unit) orelse break :type_refs;
        var idx = kv.value;

        while (idx != std.math.maxInt(u32)) {
            zcu.free_type_references.append(gpa, idx) catch {
                // This space will be reused eventually, so we need not propagate this error.
                // Just leak it for now, and let GC reclaim it later on.
                break :type_refs;
            };
            idx = zcu.all_type_references.items[idx].next;
        }
    }
}

pub fn addUnitReference(zcu: *Zcu, src_unit: AnalUnit, referenced_unit: AnalUnit, ref_src: LazySrcLoc) Allocator.Error!void {
    const gpa = zcu.gpa;

    zcu.clearCachedResolvedReferences();

    try zcu.reference_table.ensureUnusedCapacity(gpa, 1);

    const ref_idx = zcu.free_references.pop() orelse idx: {
        _ = try zcu.all_references.addOne(gpa);
        break :idx zcu.all_references.items.len - 1;
    };

    errdefer comptime unreachable;

    const gop = zcu.reference_table.getOrPutAssumeCapacity(src_unit);

    zcu.all_references.items[ref_idx] = .{
        .referenced = referenced_unit,
        .next = if (gop.found_existing) gop.value_ptr.* else std.math.maxInt(u32),
        .src = ref_src,
    };

    gop.value_ptr.* = @intCast(ref_idx);
}

pub fn addTypeReference(zcu: *Zcu, src_unit: AnalUnit, referenced_type: InternPool.Index, ref_src: LazySrcLoc) Allocator.Error!void {
    const gpa = zcu.gpa;

    zcu.clearCachedResolvedReferences();

    try zcu.type_reference_table.ensureUnusedCapacity(gpa, 1);

    const ref_idx = zcu.free_type_references.pop() orelse idx: {
        _ = try zcu.all_type_references.addOne(gpa);
        break :idx zcu.all_type_references.items.len - 1;
    };

    errdefer comptime unreachable;

    const gop = zcu.type_reference_table.getOrPutAssumeCapacity(src_unit);

    zcu.all_type_references.items[ref_idx] = .{
        .referenced = referenced_type,
        .next = if (gop.found_existing) gop.value_ptr.* else std.math.maxInt(u32),
        .src = ref_src,
    };

    gop.value_ptr.* = @intCast(ref_idx);
}

fn clearCachedResolvedReferences(zcu: *Zcu) void {
    if (zcu.resolved_references) |*r| r.deinit(zcu.gpa);
    zcu.resolved_references = null;
}

pub fn errorSetBits(zcu: *const Zcu) u16 {
    if (zcu.error_limit == 0) return 0;
    return @as(u16, std.math.log2_int(ErrorInt, zcu.error_limit)) + 1;
}

pub fn errNote(
    zcu: *Zcu,
    src_loc: LazySrcLoc,
    parent: *ErrorMsg,
    comptime format: []const u8,
    args: anytype,
) error{OutOfMemory}!void {
    const msg = try std.fmt.allocPrint(zcu.gpa, format, args);
    errdefer zcu.gpa.free(msg);

    parent.notes = try zcu.gpa.realloc(parent.notes, parent.notes.len + 1);
    parent.notes[parent.notes.len - 1] = .{
        .src_loc = src_loc,
        .msg = msg,
    };
}

/// Deprecated. There is no global target for a Zig Compilation Unit. Instead,
/// look up the target based on the Module that contains the source code being
/// analyzed.
pub fn getTarget(zcu: *const Zcu) Target {
    return zcu.root_mod.resolved_target.result;
}

/// Deprecated. There is no global optimization mode for a Zig Compilation
/// Unit. Instead, look up the optimization mode based on the Module that
/// contains the source code being analyzed.
pub fn optimizeMode(zcu: *const Zcu) std.builtin.OptimizeMode {
    return zcu.root_mod.optimize_mode;
}

pub fn handleUpdateExports(
    zcu: *Zcu,
    export_indices: []const Export.Index,
    result: link.File.UpdateExportsError!void,
) Allocator.Error!void {
    const gpa = zcu.gpa;
    result catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        error.AnalysisFail => {
            const export_idx = export_indices[0];
            const new_export = export_idx.ptr(zcu);
            new_export.status = .failed_retryable;
            try zcu.failed_exports.ensureUnusedCapacity(gpa, 1);
            const msg = try ErrorMsg.create(gpa, new_export.src, "unable to export: {s}", .{@errorName(err)});
            zcu.failed_exports.putAssumeCapacityNoClobber(export_idx, msg);
        },
    };
}

pub fn addGlobalAssembly(zcu: *Zcu, unit: AnalUnit, source: []const u8) !void {
    const gpa = zcu.gpa;
    const gop = try zcu.global_assembly.getOrPut(gpa, unit);
    if (gop.found_existing) {
        const new_value = try std.fmt.allocPrint(gpa, "{s}\n{s}", .{ gop.value_ptr.*, source });
        gpa.free(gop.value_ptr.*);
        gop.value_ptr.* = new_value;
    } else {
        gop.value_ptr.* = try gpa.dupe(u8, source);
    }
}

pub const Feature = enum {
    /// When this feature is enabled, Sema will emit calls to
    /// `std.builtin.panic` functions for things like safety checks and
    /// unreachables. Otherwise traps will be emitted.
    panic_fn,
    /// When this feature is enabled, Sema will insert tracer functions for gathering a stack
    /// trace for error returns.
    error_return_trace,
    /// When this feature is enabled, Sema will emit the `is_named_enum_value` AIR instructions
    /// and use it to check for corrupt switches. Backends currently need to implement their own
    /// logic to determine whether an enum value is in the set of named values.
    is_named_enum_value,
    error_set_has_value,
    field_reordering,
    /// When this feature is supported, the backend supports the following AIR instructions:
    /// * `Air.Inst.Tag.add_safe`
    /// * `Air.Inst.Tag.sub_safe`
    /// * `Air.Inst.Tag.mul_safe`
    /// * `Air.Inst.Tag.intcast_safe`
    /// The motivation for this feature is that it makes AIR smaller, and makes it easier
    /// to generate better machine code in the backends. All backends should migrate to
    /// enabling this feature.
    safety_checked_instructions,
    /// If the backend supports running from another thread.
    separate_thread,
    /// If the backend supports the following AIR instructions with vector types:
    /// * `Air.Inst.Tag.bit_and`
    /// * `Air.Inst.Tag.bit_or`
    /// * `Air.Inst.Tag.bitcast`
    /// * `Air.Inst.Tag.float_from_int`
    /// * `Air.Inst.Tag.fptrunc`
    /// * `Air.Inst.Tag.int_from_float`
    /// If not supported, Sema will scalarize the operation.
    all_vector_instructions,
};

pub fn backendSupportsFeature(zcu: *const Zcu, comptime feature: Feature) bool {
    const backend = target_util.zigBackend(zcu.root_mod.resolved_target.result, zcu.comp.config.use_llvm);
    return target_util.backendSupportsFeature(backend, feature);
}

pub const AtomicPtrAlignmentError = error{
    FloatTooBig,
    IntTooBig,
    BadType,
    OutOfMemory,
};

pub const AtomicPtrAlignmentDiagnostics = struct {
    bits: u16 = undefined,
    max_bits: u16 = undefined,
};

/// If ABI alignment of `ty` is OK for atomic operations, returns 0.
/// Otherwise returns the alignment required on a pointer for the target
/// to perform atomic operations.
// TODO this function does not take into account CPU features, which can affect
// this value. Audit this!
pub fn atomicPtrAlignment(
    zcu: *Zcu,
    ty: Type,
    diags: *AtomicPtrAlignmentDiagnostics,
) AtomicPtrAlignmentError!Alignment {
    const target = zcu.getTarget();
    const max_atomic_bits: u16 = switch (target.cpu.arch) {
        .avr,
        .msp430,
        .spu_2,
        => 16,

        .arc,
        .arm,
        .armeb,
        .hexagon,
        .m68k,
        .mips,
        .mipsel,
        .nvptx,
        .powerpc,
        .powerpcle,
        .riscv32,
        .sparc,
        .thumb,
        .thumbeb,
        .x86,
        .xcore,
        .kalimba,
        .lanai,
        .wasm32,
        .csky,
        .spirv32,
        .loongarch32,
        .xtensa,
        .propeller1,
        .propeller2,
        => 32,

        .amdgcn,
        .bpfel,
        .bpfeb,
        .mips64,
        .mips64el,
        .nvptx64,
        .powerpc64,
        .powerpc64le,
        .riscv64,
        .sparc64,
        .s390x,
        .wasm64,
        .ve,
        .spirv,
        .spirv64,
        .loongarch64,
        => 64,

        .aarch64,
        .aarch64_be,
        => 128,

        .x86_64 => if (std.Target.x86.featureSetHas(target.cpu.features, .cx16)) 128 else 64,
    };

    if (ty.toIntern() == .bool_type) return .none;
    if (ty.isRuntimeFloat()) {
        const bit_count = ty.floatBits(target);
        if (bit_count > max_atomic_bits) {
            diags.* = .{
                .bits = bit_count,
                .max_bits = max_atomic_bits,
            };
            return error.FloatTooBig;
        }
        return .none;
    }
    if (ty.isAbiInt(zcu)) {
        const bit_count = ty.intInfo(zcu).bits;
        if (bit_count > max_atomic_bits) {
            diags.* = .{
                .bits = bit_count,
                .max_bits = max_atomic_bits,
            };
            return error.IntTooBig;
        }
        return .none;
    }
    if (ty.isPtrAtRuntime(zcu)) return .none;
    return error.BadType;
}

/// Returns null in the following cases:
/// * Not a struct.
pub fn typeToStruct(zcu: *const Zcu, ty: Type) ?InternPool.LoadedStructType {
    if (ty.ip_index == .none) return null;
    const ip = &zcu.intern_pool;
    return switch (ip.indexToKey(ty.ip_index)) {
        .struct_type => ip.loadStructType(ty.ip_index),
        else => null,
    };
}

pub fn typeToPackedStruct(zcu: *const Zcu, ty: Type) ?InternPool.LoadedStructType {
    const s = zcu.typeToStruct(ty) orelse return null;
    if (s.layout != .@"packed") return null;
    return s;
}

pub fn typeToUnion(zcu: *const Zcu, ty: Type) ?InternPool.LoadedUnionType {
    if (ty.ip_index == .none) return null;
    const ip = &zcu.intern_pool;
    return switch (ip.indexToKey(ty.ip_index)) {
        .union_type => ip.loadUnionType(ty.ip_index),
        else => null,
    };
}

pub fn typeToFunc(zcu: *const Zcu, ty: Type) ?InternPool.Key.FuncType {
    if (ty.ip_index == .none) return null;
    return zcu.intern_pool.indexToFuncType(ty.toIntern());
}

pub fn iesFuncIndex(zcu: *const Zcu, ies_index: InternPool.Index) InternPool.Index {
    return zcu.intern_pool.iesFuncIndex(ies_index);
}

pub fn funcInfo(zcu: *const Zcu, func_index: InternPool.Index) InternPool.Key.Func {
    return zcu.intern_pool.toFunc(func_index);
}

pub const UnionLayout = struct {
    abi_size: u64,
    abi_align: Alignment,
    most_aligned_field: u32,
    most_aligned_field_size: u64,
    biggest_field: u32,
    payload_size: u64,
    payload_align: Alignment,
    tag_align: Alignment,
    tag_size: u64,
    padding: u32,

    pub fn tagOffset(layout: UnionLayout) u64 {
        return if (layout.tag_align.compare(.lt, layout.payload_align)) layout.payload_size else 0;
    }

    pub fn payloadOffset(layout: UnionLayout) u64 {
        return if (layout.tag_align.compare(.lt, layout.payload_align)) 0 else layout.tag_size;
    }
};

/// Returns the index of the active field, given the current tag value
pub fn unionTagFieldIndex(zcu: *const Zcu, loaded_union: InternPool.LoadedUnionType, enum_tag: Value) ?u32 {
    const ip = &zcu.intern_pool;
    if (enum_tag.toIntern() == .none) return null;
    assert(ip.typeOf(enum_tag.toIntern()) == loaded_union.enum_tag_ty);
    return loaded_union.loadTagType(ip).tagValueIndex(ip, enum_tag.toIntern());
}

pub const ResolvedReference = struct {
    referencer: AnalUnit,
    src: LazySrcLoc,
};

/// Returns a mapping from an `AnalUnit` to where it is referenced.
/// If the value is `null`, the `AnalUnit` is a root of analysis.
/// If an `AnalUnit` is not in the returned map, it is unreferenced.
/// The returned hashmap is owned by the `Zcu`, so should not be freed by the caller.
/// This hashmap is cached, so repeated calls to this function are cheap.
pub fn resolveReferences(zcu: *Zcu) !*const std.AutoHashMapUnmanaged(AnalUnit, ?ResolvedReference) {
    if (zcu.resolved_references == null) {
        zcu.resolved_references = try zcu.resolveReferencesInner();
    }
    return &zcu.resolved_references.?;
}
fn resolveReferencesInner(zcu: *Zcu) !std.AutoHashMapUnmanaged(AnalUnit, ?ResolvedReference) {
    const gpa = zcu.gpa;
    const comp = zcu.comp;
    const ip = &zcu.intern_pool;

    var result: std.AutoHashMapUnmanaged(AnalUnit, ?ResolvedReference) = .empty;
    errdefer result.deinit(gpa);

    var checked_types: std.AutoArrayHashMapUnmanaged(InternPool.Index, void) = .empty;
    var type_queue: std.AutoArrayHashMapUnmanaged(InternPool.Index, ?ResolvedReference) = .empty;
    var unit_queue: std.AutoArrayHashMapUnmanaged(AnalUnit, ?ResolvedReference) = .empty;
    defer {
        checked_types.deinit(gpa);
        type_queue.deinit(gpa);
        unit_queue.deinit(gpa);
    }

    // This is not a sufficient size, but a lower bound.
    try result.ensureTotalCapacity(gpa, @intCast(zcu.reference_table.count()));

    try type_queue.ensureTotalCapacity(gpa, zcu.analysis_roots.len);
    for (zcu.analysis_roots.slice()) |mod| {
        // Logic ripped from `Zcu.PerThread.importPkg`.
        // TODO: this is silly, `Module` should just store a reference to its root `File`.
        const resolved_path = try std.fs.path.resolve(gpa, &.{
            mod.root.root_dir.path orelse ".",
            mod.root.sub_path,
            mod.root_src_path,
        });
        defer gpa.free(resolved_path);
        const file = zcu.import_table.get(resolved_path).?;
        const root_ty = zcu.fileRootType(file);
        if (root_ty == .none) continue;
        type_queue.putAssumeCapacityNoClobber(root_ty, null);
    }

    while (true) {
        if (type_queue.pop()) |kv| {
            const ty = kv.key;
            const referencer = kv.value;
            try checked_types.putNoClobber(gpa, ty, {});

            log.debug("handle type '{}'", .{Type.fromInterned(ty).containerTypeName(ip).fmt(ip)});

            // If this type undergoes type resolution, the corresponding `AnalUnit` is automatically referenced.
            const has_resolution: bool = switch (ip.indexToKey(ty)) {
                .struct_type, .union_type => true,
                .enum_type => |k| k != .generated_tag,
                .opaque_type => false,
                else => unreachable,
            };
            if (has_resolution) {
                // this should only be referenced by the type
                const unit: AnalUnit = .wrap(.{ .type = ty });
                assert(!result.contains(unit));
                try unit_queue.putNoClobber(gpa, unit, referencer);
            }

            // If this is a union with a generated tag, its tag type is automatically referenced.
            // We don't add this reference for non-generated tags, as those will already be referenced via the union's type resolution, with a better source location.
            if (zcu.typeToUnion(Type.fromInterned(ty))) |union_obj| {
                const tag_ty = union_obj.enum_tag_ty;
                if (tag_ty != .none) {
                    if (ip.indexToKey(tag_ty).enum_type == .generated_tag) {
                        if (!checked_types.contains(tag_ty)) {
                            try type_queue.put(gpa, tag_ty, referencer);
                        }
                    }
                }
            }

            // Queue any decls within this type which would be automatically analyzed.
            // Keep in sync with analysis queueing logic in `Zcu.PerThread.ScanDeclIter.scanDecl`.
            const ns = Type.fromInterned(ty).getNamespace(zcu).unwrap().?;
            for (zcu.namespacePtr(ns).comptime_decls.items) |cu| {
                // `comptime` decls are always analyzed.
                const unit: AnalUnit = .wrap(.{ .@"comptime" = cu });
                if (!result.contains(unit)) {
                    log.debug("type '{}': ref comptime %{}", .{
                        Type.fromInterned(ty).containerTypeName(ip).fmt(ip),
                        @intFromEnum(ip.getComptimeUnit(cu).zir_index.resolve(ip) orelse continue),
                    });
                    try unit_queue.put(gpa, unit, referencer);
                }
            }
            for (zcu.namespacePtr(ns).test_decls.items) |nav_id| {
                const nav = ip.getNav(nav_id);
                // `test` declarations are analyzed depending on the test filter.
                const inst_info = nav.analysis.?.zir_index.resolveFull(ip) orelse continue;
                const file = zcu.fileByIndex(inst_info.file);
                const decl = file.zir.?.getDeclaration(inst_info.inst);

                if (!comp.config.is_test or file.mod != zcu.main_mod) continue;

                const want_analysis = switch (decl.kind) {
                    .@"usingnamespace" => unreachable,
                    .@"const", .@"var" => unreachable,
                    .@"comptime" => unreachable,
                    .unnamed_test => true,
                    .@"test", .decltest => a: {
                        const fqn_slice = nav.fqn.toSlice(ip);
                        for (comp.test_filters) |test_filter| {
                            if (std.mem.indexOf(u8, fqn_slice, test_filter) != null) break;
                        } else break :a false;
                        break :a true;
                    },
                };
                if (want_analysis) {
                    log.debug("type '{}': ref test %{}", .{
                        Type.fromInterned(ty).containerTypeName(ip).fmt(ip),
                        @intFromEnum(inst_info.inst),
                    });
                    const unit: AnalUnit = .wrap(.{ .nav_val = nav_id });
                    try unit_queue.put(gpa, unit, referencer);
                }
            }
            for (zcu.namespacePtr(ns).pub_decls.keys()) |nav| {
                // These are named declarations. They are analyzed only if marked `export`.
                const inst_info = ip.getNav(nav).analysis.?.zir_index.resolveFull(ip) orelse continue;
                const file = zcu.fileByIndex(inst_info.file);
                const decl = file.zir.?.getDeclaration(inst_info.inst);
                if (decl.linkage == .@"export") {
                    const unit: AnalUnit = .wrap(.{ .nav_val = nav });
                    if (!result.contains(unit)) {
                        log.debug("type '{}': ref named %{}", .{
                            Type.fromInterned(ty).containerTypeName(ip).fmt(ip),
                            @intFromEnum(inst_info.inst),
                        });
                        try unit_queue.put(gpa, unit, referencer);
                    }
                }
            }
            for (zcu.namespacePtr(ns).priv_decls.keys()) |nav| {
                // These are named declarations. They are analyzed only if marked `export`.
                const inst_info = ip.getNav(nav).analysis.?.zir_index.resolveFull(ip) orelse continue;
                const file = zcu.fileByIndex(inst_info.file);
                const decl = file.zir.?.getDeclaration(inst_info.inst);
                if (decl.linkage == .@"export") {
                    const unit: AnalUnit = .wrap(.{ .nav_val = nav });
                    if (!result.contains(unit)) {
                        log.debug("type '{}': ref named %{}", .{
                            Type.fromInterned(ty).containerTypeName(ip).fmt(ip),
                            @intFromEnum(inst_info.inst),
                        });
                        try unit_queue.put(gpa, unit, referencer);
                    }
                }
            }
            // Incremental compilation does not support `usingnamespace`.
            // These are only included to keep good reference traces in non-incremental updates.
            for (zcu.namespacePtr(ns).pub_usingnamespace.items) |nav| {
                const unit: AnalUnit = .wrap(.{ .nav_val = nav });
                if (!result.contains(unit)) try unit_queue.put(gpa, unit, referencer);
            }
            for (zcu.namespacePtr(ns).priv_usingnamespace.items) |nav| {
                const unit: AnalUnit = .wrap(.{ .nav_val = nav });
                if (!result.contains(unit)) try unit_queue.put(gpa, unit, referencer);
            }
            continue;
        }
        if (unit_queue.pop()) |kv| {
            const unit = kv.key;
            try result.putNoClobber(gpa, unit, kv.value);

            // `nav_val` and `nav_ty` reference each other *implicitly* to save memory.
            queue_paired: {
                const other: AnalUnit = .wrap(switch (unit.unwrap()) {
                    .nav_val => |n| .{ .nav_ty = n },
                    .nav_ty => |n| .{ .nav_val = n },
                    .@"comptime", .type, .func, .memoized_state => break :queue_paired,
                });
                if (result.contains(other)) break :queue_paired;
                try unit_queue.put(gpa, other, kv.value); // same reference location
            }

            log.debug("handle unit '{}'", .{zcu.fmtAnalUnit(unit)});

            if (zcu.reference_table.get(unit)) |first_ref_idx| {
                assert(first_ref_idx != std.math.maxInt(u32));
                var ref_idx = first_ref_idx;
                while (ref_idx != std.math.maxInt(u32)) {
                    const ref = zcu.all_references.items[ref_idx];
                    if (!result.contains(ref.referenced)) {
                        log.debug("unit '{}': ref unit '{}'", .{
                            zcu.fmtAnalUnit(unit),
                            zcu.fmtAnalUnit(ref.referenced),
                        });
                        try unit_queue.put(gpa, ref.referenced, .{
                            .referencer = unit,
                            .src = ref.src,
                        });
                    }
                    ref_idx = ref.next;
                }
            }
            if (zcu.type_reference_table.get(unit)) |first_ref_idx| {
                assert(first_ref_idx != std.math.maxInt(u32));
                var ref_idx = first_ref_idx;
                while (ref_idx != std.math.maxInt(u32)) {
                    const ref = zcu.all_type_references.items[ref_idx];
                    if (!checked_types.contains(ref.referenced)) {
                        log.debug("unit '{}': ref type '{}'", .{
                            zcu.fmtAnalUnit(unit),
                            Type.fromInterned(ref.referenced).containerTypeName(ip).fmt(ip),
                        });
                        try type_queue.put(gpa, ref.referenced, .{
                            .referencer = unit,
                            .src = ref.src,
                        });
                    }
                    ref_idx = ref.next;
                }
            }
            continue;
        }
        break;
    }

    return result;
}

pub fn fileByIndex(zcu: *const Zcu, file_index: File.Index) *File {
    return zcu.intern_pool.filePtr(file_index);
}

/// Returns the struct that represents this `File`.
/// If the struct has not been created, returns `.none`.
pub fn fileRootType(zcu: *const Zcu, file_index: File.Index) InternPool.Index {
    const ip = &zcu.intern_pool;
    const file_index_unwrapped = file_index.unwrap(ip);
    const files = ip.getLocalShared(file_index_unwrapped.tid).files.acquire();
    return files.view().items(.root_type)[file_index_unwrapped.index];
}

pub fn setFileRootType(zcu: *Zcu, file_index: File.Index, root_type: InternPool.Index) void {
    const ip = &zcu.intern_pool;
    const file_index_unwrapped = file_index.unwrap(ip);
    const files = ip.getLocalShared(file_index_unwrapped.tid).files.acquire();
    files.view().items(.root_type)[file_index_unwrapped.index] = root_type;
}

pub fn filePathDigest(zcu: *const Zcu, file_index: File.Index) Cache.BinDigest {
    const ip = &zcu.intern_pool;
    const file_index_unwrapped = file_index.unwrap(ip);
    const files = ip.getLocalShared(file_index_unwrapped.tid).files.acquire();
    return files.view().items(.bin_digest)[file_index_unwrapped.index];
}

pub fn navSrcLoc(zcu: *const Zcu, nav_index: InternPool.Nav.Index) LazySrcLoc {
    const ip = &zcu.intern_pool;
    return .{
        .base_node_inst = ip.getNav(nav_index).srcInst(ip),
        .offset = LazySrcLoc.Offset.nodeOffset(0),
    };
}

pub fn typeSrcLoc(zcu: *const Zcu, ty_index: InternPool.Index) LazySrcLoc {
    _ = zcu;
    _ = ty_index;
    @panic("TODO");
}

pub fn typeFileScope(zcu: *Zcu, ty_index: InternPool.Index) *File {
    _ = zcu;
    _ = ty_index;
    @panic("TODO");
}

pub fn navSrcLine(zcu: *Zcu, nav_index: InternPool.Nav.Index) u32 {
    const ip = &zcu.intern_pool;
    const inst_info = ip.getNav(nav_index).srcInst(ip).resolveFull(ip).?;
    const zir = zcu.fileByIndex(inst_info.file).zir;
    return zir.?.getDeclaration(inst_info.inst).src_line;
}

pub fn navValue(zcu: *const Zcu, nav_index: InternPool.Nav.Index) Value {
    return Value.fromInterned(zcu.intern_pool.getNav(nav_index).status.fully_resolved.val);
}

pub fn navFileScopeIndex(zcu: *Zcu, nav: InternPool.Nav.Index) File.Index {
    const ip = &zcu.intern_pool;
    return ip.getNav(nav).srcInst(ip).resolveFile(ip);
}

pub fn navFileScope(zcu: *Zcu, nav: InternPool.Nav.Index) *File {
    return zcu.fileByIndex(zcu.navFileScopeIndex(nav));
}

pub fn fmtAnalUnit(zcu: *Zcu, unit: AnalUnit) std.fmt.Formatter(formatAnalUnit) {
    return .{ .data = .{ .unit = unit, .zcu = zcu } };
}
pub fn fmtDependee(zcu: *Zcu, d: InternPool.Dependee) std.fmt.Formatter(formatDependee) {
    return .{ .data = .{ .dependee = d, .zcu = zcu } };
}

fn formatAnalUnit(data: struct { unit: AnalUnit, zcu: *Zcu }, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
    _ = .{ fmt, options };
    const zcu = data.zcu;
    const ip = &zcu.intern_pool;
    switch (data.unit.unwrap()) {
        .@"comptime" => |cu_id| {
            const cu = ip.getComptimeUnit(cu_id);
            if (cu.zir_index.resolveFull(ip)) |resolved| {
                const file_path = zcu.fileByIndex(resolved.file).sub_file_path;
                return writer.print("comptime(inst=('{s}', %{}) [{}])", .{ file_path, @intFromEnum(resolved.inst), @intFromEnum(cu_id) });
            } else {
                return writer.print("comptime(inst=<lost> [{}])", .{@intFromEnum(cu_id)});
            }
        },
        .nav_val => |nav| return writer.print("nav_val('{}' [{}])", .{ ip.getNav(nav).fqn.fmt(ip), @intFromEnum(nav) }),
        .nav_ty => |nav| return writer.print("nav_ty('{}' [{}])", .{ ip.getNav(nav).fqn.fmt(ip), @intFromEnum(nav) }),
        .type => |ty| return writer.print("ty('{}' [{}])", .{ Type.fromInterned(ty).containerTypeName(ip).fmt(ip), @intFromEnum(ty) }),
        .func => |func| {
            const nav = zcu.funcInfo(func).owner_nav;
            return writer.print("func('{}' [{}])", .{ ip.getNav(nav).fqn.fmt(ip), @intFromEnum(func) });
        },
        .memoized_state => return writer.writeAll("memoized_state"),
    }
}
fn formatDependee(data: struct { dependee: InternPool.Dependee, zcu: *Zcu }, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
    _ = .{ fmt, options };
    const zcu = data.zcu;
    const ip = &zcu.intern_pool;
    switch (data.dependee) {
        .src_hash => |ti| {
            const info = ti.resolveFull(ip) orelse {
                return writer.writeAll("inst(<lost>)");
            };
            const file_path = zcu.fileByIndex(info.file).sub_file_path;
            return writer.print("inst('{s}', %{d})", .{ file_path, @intFromEnum(info.inst) });
        },
        .nav_val => |nav| {
            const fqn = ip.getNav(nav).fqn;
            return writer.print("nav_val('{}')", .{fqn.fmt(ip)});
        },
        .nav_ty => |nav| {
            const fqn = ip.getNav(nav).fqn;
            return writer.print("nav_ty('{}')", .{fqn.fmt(ip)});
        },
        .interned => |ip_index| switch (ip.indexToKey(ip_index)) {
            .struct_type, .union_type, .enum_type => return writer.print("type('{}')", .{Type.fromInterned(ip_index).containerTypeName(ip).fmt(ip)}),
            .func => |f| return writer.print("ies('{}')", .{ip.getNav(f.owner_nav).fqn.fmt(ip)}),
            else => unreachable,
        },
        .zon_file => |file| {
            const file_path = zcu.fileByIndex(file).sub_file_path;
            return writer.print("zon_file('{s}')", .{file_path});
        },
        .embed_file => |ef_idx| {
            const ef = ef_idx.get(zcu);
            return writer.print("embed_file('{s}')", .{std.fs.path.fmtJoin(&.{
                ef.owner.root.root_dir.path orelse "",
                ef.owner.root.sub_path,
                ef.sub_file_path.toSlice(ip),
            })});
        },
        .namespace => |ti| {
            const info = ti.resolveFull(ip) orelse {
                return writer.writeAll("namespace(<lost>)");
            };
            const file_path = zcu.fileByIndex(info.file).sub_file_path;
            return writer.print("namespace('{s}', %{d})", .{ file_path, @intFromEnum(info.inst) });
        },
        .namespace_name => |k| {
            const info = k.namespace.resolveFull(ip) orelse {
                return writer.print("namespace(<lost>, '{}')", .{k.name.fmt(ip)});
            };
            const file_path = zcu.fileByIndex(info.file).sub_file_path;
            return writer.print("namespace('{s}', %{d}, '{}')", .{ file_path, @intFromEnum(info.inst), k.name.fmt(ip) });
        },
        .memoized_state => return writer.writeAll("memoized_state"),
    }
}

/// Given the `InternPool.Index` of a function, set its resolved IES to `.none` if it
/// may be outdated. `Sema` should do this before ever loading a resolved IES.
pub fn maybeUnresolveIes(zcu: *Zcu, func_index: InternPool.Index) !void {
    const unit = AnalUnit.wrap(.{ .func = func_index });
    if (zcu.outdated.contains(unit) or zcu.potentially_outdated.contains(unit)) {
        // We're consulting the resolved IES now, but the function is outdated, so its
        // IES may have changed. We have to assume the IES is outdated and set the resolved
        // set back to `.none`.
        //
        // This will cause `PerThread.analyzeFnBody` to mark the IES as outdated when it's
        // eventually hit.
        //
        // Since the IES needs to be resolved, the function body will now definitely need
        // re-analysis (even if the IES turns out to be the same!), so mark it as
        // definitely-outdated if it's only PO.
        if (zcu.potentially_outdated.fetchSwapRemove(unit)) |kv| {
            const gpa = zcu.gpa;
            try zcu.outdated.putNoClobber(gpa, unit, kv.value);
            if (kv.value == 0) {
                try zcu.outdated_ready.put(gpa, unit, {});
            }
        }
        zcu.intern_pool.funcSetIesResolved(func_index, .none);
    }
}

pub fn callconvSupported(zcu: *Zcu, cc: std.builtin.CallingConvention) union(enum) {
    ok,
    bad_arch: []const std.Target.Cpu.Arch, // value is allowed archs for cc
    bad_backend: std.builtin.CompilerBackend, // value is current backend
} {
    const target = zcu.getTarget();
    const backend = target_util.zigBackend(target, zcu.comp.config.use_llvm);
    switch (cc) {
        .auto, .@"inline" => return .ok,
        .@"async" => return .{ .bad_backend = backend }, // nothing supports async currently
        .naked => {}, // depends only on backend
        else => for (cc.archs()) |allowed_arch| {
            if (allowed_arch == target.cpu.arch) break;
        } else return .{ .bad_arch = cc.archs() },
    }
    const backend_ok = switch (backend) {
        .stage1 => unreachable,
        .other => unreachable,
        _ => unreachable,

        .stage2_llvm => @import("codegen/llvm.zig").toLlvmCallConv(cc, target) != null,
        .stage2_c => ok: {
            if (target.cCallingConvention()) |default_c| {
                if (cc.eql(default_c)) {
                    break :ok true;
                }
            }
            break :ok switch (cc) {
                .x86_64_sysv,
                .x86_64_win,
                .x86_64_vectorcall,
                .x86_64_regcall_v3_sysv,
                .x86_64_regcall_v4_win,
                .x86_64_interrupt,
                .x86_fastcall,
                .x86_thiscall,
                .x86_vectorcall,
                .x86_regcall_v3,
                .x86_regcall_v4_win,
                .x86_interrupt,
                .aarch64_vfabi,
                .aarch64_vfabi_sve,
                .arm_aapcs,
                .csky_interrupt,
                .riscv64_lp64_v,
                .riscv32_ilp32_v,
                .m68k_rtd,
                .m68k_interrupt,
                => |opts| opts.incoming_stack_alignment == null,

                .arm_aapcs_vfp,
                => |opts| opts.incoming_stack_alignment == null and target.os.tag != .watchos,
                .arm_aapcs16_vfp,
                => |opts| opts.incoming_stack_alignment == null and target.os.tag == .watchos,

                .arm_interrupt,
                => |opts| opts.incoming_stack_alignment == null,

                .mips_interrupt,
                .mips64_interrupt,
                => |opts| opts.incoming_stack_alignment == null,

                .riscv32_interrupt,
                .riscv64_interrupt,
                => |opts| opts.incoming_stack_alignment == null,

                .x86_sysv,
                .x86_win,
                .x86_stdcall,
                => |opts| opts.incoming_stack_alignment == null and opts.register_params == 0,

                .avr_interrupt,
                .avr_signal,
                => true,

                .naked => true,

                else => false,
            };
        },
        .stage2_wasm => switch (cc) {
            .wasm_watc => |opts| opts.incoming_stack_alignment == null,
            else => false,
        },
        .stage2_arm => switch (cc) {
            .arm_aapcs => |opts| opts.incoming_stack_alignment == null,
            .naked => true,
            else => false,
        },
        .stage2_x86_64 => switch (cc) {
            .x86_64_sysv, .x86_64_win, .naked => true, // incoming stack alignment supported
            else => false,
        },
        .stage2_aarch64 => switch (cc) {
            .aarch64_aapcs,
            .aarch64_aapcs_darwin,
            .aarch64_aapcs_win,
            => |opts| opts.incoming_stack_alignment == null,
            .naked => true,
            else => false,
        },
        .stage2_x86 => switch (cc) {
            .x86_sysv,
            .x86_win,
            => |opts| opts.incoming_stack_alignment == null and opts.register_params == 0,
            .naked => true,
            else => false,
        },
        .stage2_riscv64 => switch (cc) {
            .riscv64_lp64 => |opts| opts.incoming_stack_alignment == null,
            .naked => true,
            else => false,
        },
        .stage2_sparc64 => switch (cc) {
            .sparc64_sysv => |opts| opts.incoming_stack_alignment == null,
            .naked => true,
            else => false,
        },
        .stage2_spirv64 => switch (cc) {
            .spirv_device, .spirv_kernel => true,
            .spirv_fragment, .spirv_vertex => target.os.tag == .vulkan,
            else => false,
        },
    };
    if (!backend_ok) return .{ .bad_backend = backend };
    return .ok;
}

/// Given that a `Nav` has value `val`, determine if a ref of that `Nav` gives a `const` pointer.
pub fn navValIsConst(zcu: *const Zcu, val: InternPool.Index) bool {
    return switch (zcu.intern_pool.indexToKey(val)) {
        .variable => false,
        .@"extern" => |e| e.is_const,
        else => true,
    };
}

pub const CodegenFailError = error{
    /// Indicates the error message has been already stored at `Zcu.failed_codegen`.
    CodegenFail,
    OutOfMemory,
};

pub fn codegenFail(
    zcu: *Zcu,
    nav_index: InternPool.Nav.Index,
    comptime format: []const u8,
    args: anytype,
) CodegenFailError {
    const gpa = zcu.gpa;
    try zcu.failed_codegen.ensureUnusedCapacity(gpa, 1);
    const msg = try Zcu.ErrorMsg.create(gpa, zcu.navSrcLoc(nav_index), format, args);
    zcu.failed_codegen.putAssumeCapacityNoClobber(nav_index, msg);
    return error.CodegenFail;
}

pub fn codegenFailMsg(zcu: *Zcu, nav_index: InternPool.Nav.Index, msg: *ErrorMsg) CodegenFailError {
    const gpa = zcu.gpa;
    {
        errdefer msg.deinit(gpa);
        try zcu.failed_codegen.putNoClobber(gpa, nav_index, msg);
    }
    return error.CodegenFail;
}

pub fn codegenFailType(
    zcu: *Zcu,
    ty_index: InternPool.Index,
    comptime format: []const u8,
    args: anytype,
) CodegenFailError {
    const gpa = zcu.gpa;
    try zcu.failed_types.ensureUnusedCapacity(gpa, 1);
    const msg = try Zcu.ErrorMsg.create(gpa, zcu.typeSrcLoc(ty_index), format, args);
    zcu.failed_types.putAssumeCapacityNoClobber(ty_index, msg);
    return error.CodegenFail;
}

pub fn codegenFailTypeMsg(zcu: *Zcu, ty_index: InternPool.Index, msg: *ErrorMsg) CodegenFailError {
    const gpa = zcu.gpa;
    {
        errdefer msg.deinit(gpa);
        try zcu.failed_types.ensureUnusedCapacity(gpa, 1);
    }
    zcu.failed_types.putAssumeCapacityNoClobber(ty_index, msg);
    return error.CodegenFail;
}
