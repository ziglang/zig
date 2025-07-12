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
const Writer = std.io.Writer;

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
/// If the ZCU is emitting an LLVM object (i.e. we are using the LLVM backend), then this is the
/// `LlvmObject` we are emitting to.
llvm_object: ?LlvmObject.Ptr,

/// Pointer to externally managed resource.
root_mod: *Package.Module,
/// Normally, `main_mod` and `root_mod` are the same. The exception is `zig test`, in which
/// `root_mod` is the test runner, and `main_mod` is the user's source file which has the tests.
main_mod: *Package.Module,
std_mod: *Package.Module,
sema_prog_node: std.Progress.Node = .none,
codegen_prog_node: std.Progress.Node = .none,
/// The number of codegen jobs which are pending or in-progress. Whichever thread drops this value
/// to 0 is responsible for ending `codegen_prog_node`. While semantic analysis is happening, this
/// value bottoms out at 1 instead of 0, to ensure that it can only drop to 0 after analysis is
/// completed (since semantic analysis could trigger more codegen work).
pending_codegen_jobs: std.atomic.Value(u32) = .init(0),

/// This is the progress node *under* `sema_prog_node` which is currently running.
/// When we have to pause to analyze something else, we just temporarily rename this node.
/// Eventually, when we thread semantic analysis, we will want one of these per thread.
cur_sema_prog_node: std.Progress.Node = .none,

/// Used by AstGen worker to load and store ZIR cache.
global_zir_cache: Cache.Directory,
/// Used by AstGen worker to load and store ZIR cache.
local_zir_cache: Cache.Directory,

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

/// Key is the digest returned by `Builtin.hash`; value is the corresponding module.
builtin_modules: std.AutoArrayHashMapUnmanaged(Cache.BinDigest, *Package.Module) = .empty,

/// Populated as soon as the `Compilation` is created. Guaranteed to contain all modules, even builtin ones.
/// Modules whose root file is not a Zig or ZON file have the value `.none`.
module_roots: std.AutoArrayHashMapUnmanaged(*Package.Module, File.Index.Optional) = .empty,

/// The set of all the Zig source files in the Zig Compilation Unit. Tracked in
/// order to iterate over it and check which source files have been modified on
/// the file system when an update is requested, as well as to cache `@import`
/// results.
///
/// Always accessed through `ImportTableAdapter`, where keys are fully resolved
/// file paths in order to ensure files are properly deduplicated. This table owns
/// the keys and values.
///
/// Protected by Compilation's mutex.
///
/// Not serialized. This state is reconstructed during the first call to
/// `Compilation.update` of the process for a given `Compilation`.
import_table: std.ArrayHashMapUnmanaged(
    File.Index,
    void,
    struct {
        pub const hash = @compileError("all accesses should be through ImportTableAdapter");
        pub const eql = @compileError("all accesses should be through ImportTableAdapter");
    },
    true, // This is necessary! Without it, the map tries to use its Context to rehash. #21918
) = .empty,

/// The set of all files in `import_table` which are "alive" this update, meaning
/// they are reachable by traversing imports starting from an analysis root. This
/// is usually all files in `import_table`, but some could be omitted if an incremental
/// update removes an import, or if a module specified on the CLI is never imported.
/// Reconstructed on every update, after AstGen and before Sema.
/// Value is why the file is alive.
alive_files: std.AutoArrayHashMapUnmanaged(File.Index, File.Reference) = .empty,

/// If this is populated, a "file exists in multiple modules" error should be emitted.
/// This causes file errors to not be shown, because we don't really know which files
/// should be alive (because the user has messed up their imports somewhere!).
/// Cleared and recomputed every update, after AstGen and before Sema.
multi_module_err: ?struct {
    file: File.Index,
    modules: [2]*Package.Module,
    refs: [2]File.Reference,
} = null,

/// The set of all the files which have been loaded with `@embedFile` in the Module.
/// We keep track of this in order to iterate over it and check which files have been
/// modified on the file system when an update is requested, as well as to cache
/// `@embedFile` results.
///
/// Like `import_table`, this is accessed through `EmbedTableAdapter`, so that it is keyed
/// on the `Compilation.Path` of the `EmbedFile`.
///
/// This table owns all of the `*EmbedFile` memory, which is allocated into gpa.
embed_table: std.ArrayHashMapUnmanaged(
    *EmbedFile,
    void,
    struct {
        pub const hash = @compileError("all accesses should be through EmbedTableAdapter");
        pub const eql = @compileError("all accesses should be through EmbedTableAdapter");
    },
    true, // This is necessary! Without it, the map tries to use its Context to rehash. #21918
) = .empty,

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
/// While multiple threads are active (most of the time!), this is guarded by `zcu.comp.mutex`, as
/// codegen and linking run on a separate thread.
failed_codegen: std.AutoArrayHashMapUnmanaged(InternPool.Nav.Index, *ErrorMsg) = .empty,
failed_types: std.AutoArrayHashMapUnmanaged(InternPool.Index, *ErrorMsg) = .empty,
/// Keep track of `@compileLog`s per `AnalUnit`.
/// We track the source location of the first `@compileLog` call, and all logged lines as a linked list.
/// The list is singly linked, but we do track its tail for fast appends (optimizing many logs in one unit).
compile_logs: std.AutoArrayHashMapUnmanaged(AnalUnit, extern struct {
    base_node_inst: InternPool.TrackedInst.Index,
    node_offset: Ast.Node.Offset,
    first_line: CompileLogLine.Index,
    last_line: CompileLogLine.Index,
    pub fn src(self: @This()) LazySrcLoc {
        return .{
            .base_node_inst = self.base_node_inst,
            .offset = LazySrcLoc.Offset.nodeOffset(self.node_offset),
        };
    }
}) = .empty,
compile_log_lines: std.ArrayListUnmanaged(CompileLogLine) = .empty,
free_compile_log_lines: std.ArrayListUnmanaged(CompileLogLine.Index) = .empty,
/// This tracks files which triggered errors when generating AST/ZIR/ZOIR.
/// If not `null`, the value is a retryable error (the file status is guaranteed
/// to be `.retryable_failure`). Otherwise, the file status is `.astgen_failure`
/// or `.success`, and there are ZIR/ZOIR errors which should be printed.
/// We just store a `[]u8` instead of a full `*ErrorMsg`, because the source
/// location is always the entire file. The `[]u8` memory is owned by the map
/// and allocated into `gpa`.
failed_files: std.AutoArrayHashMapUnmanaged(File.Index, ?[]u8) = .empty,
/// AstGen is not aware of modules, and so cannot determine whether an import
/// string makes sense. That is the job of a traversal after AstGen.
///
/// There are several ways in which an import can fail:
///
/// * It is an import of a file which does not exist. This case is not handled
///   by this field, but with a `failed_files` entry on the *imported* file.
/// * It is an import of a module which does not exist in the current module's
///   dependency table. This happens at `Sema` time, so is not tracked by this
///   field.
/// * It is an import which reaches outside of the current module's root
///   directory. This is tracked by this field.
/// * It is an import which reaches into an "illegal import directory". Right now,
///   the only such directory is 'global_cache/b/', but in general, these are
///   directories the compiler treats specially. This is tracked by this field.
///
/// This is a flat array containing all of the relevant errors. It is cleared and
/// recomputed on every update. The errors here are fatal, i.e. they block any
/// semantic analysis this update.
///
/// Allocated into gpa.
failed_imports: std.ArrayListUnmanaged(struct {
    file_index: File.Index,
    import_string: Zir.NullTerminatedString,
    import_token: Ast.TokenIndex,
    kind: enum { file_outside_module_root, illegal_zig_import },
}) = .empty,
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
analysis_roots: std.BoundedArray(*Package.Module, 4) = .{},
/// This is the cached result of `Zcu.resolveReferences`. It is computed on-demand, and
/// reset to `null` when any semantic analysis occurs (since this invalidates the data).
/// Allocated into `gpa`.
resolved_references: ?std.AutoHashMapUnmanaged(AnalUnit, ?ResolvedReference) = null,

/// If `true`, then semantic analysis must not occur on this update due to AstGen errors.
/// Essentially the entire pipeline after AstGen, including Sema, codegen, and link, is skipped.
/// Reset to `false` at the start of each update in `Compilation.update`.
skip_analysis_this_update: bool = false,

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

inline_reference_frames: std.ArrayListUnmanaged(InlineReferenceFrame) = .empty,
free_inline_reference_frames: std.ArrayListUnmanaged(InlineReferenceFrame.Index) = .empty,

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

incremental_debug_state: if (build_options.enable_debug_extensions) IncrementalDebugState else void =
    if (build_options.enable_debug_extensions) .init else {},

generation: u32 = 0,

pub const IncrementalDebugState = struct {
    /// All container types in the ZCU, even dead ones.
    /// Value is the generation the type was created on.
    types: std.AutoArrayHashMapUnmanaged(InternPool.Index, u32),
    /// All `Nav`s in the ZCU, even dead ones.
    /// Value is the generation the `Nav` was created on.
    navs: std.AutoArrayHashMapUnmanaged(InternPool.Nav.Index, u32),
    /// All `AnalUnit`s in the ZCU, even dead ones.
    units: std.AutoArrayHashMapUnmanaged(AnalUnit, UnitInfo),

    pub const init: IncrementalDebugState = .{
        .types = .empty,
        .navs = .empty,
        .units = .empty,
    };
    pub fn deinit(ids: *IncrementalDebugState, gpa: Allocator) void {
        for (ids.units.values()) |*unit_info| {
            unit_info.deps.deinit(gpa);
        }
        ids.types.deinit(gpa);
        ids.navs.deinit(gpa);
        ids.units.deinit(gpa);
    }

    pub const UnitInfo = struct {
        last_update_gen: u32,
        /// This information isn't easily recoverable from `InternPool`'s dependency storage format.
        deps: std.ArrayListUnmanaged(InternPool.Dependee),
    };
    pub fn getUnitInfo(ids: *IncrementalDebugState, gpa: Allocator, unit: AnalUnit) Allocator.Error!*UnitInfo {
        const gop = try ids.units.getOrPut(gpa, unit);
        if (!gop.found_existing) gop.value_ptr.* = .{
            .last_update_gen = std.math.maxInt(u32),
            .deps = .empty,
        };
        return gop.value_ptr;
    }
    pub fn newType(ids: *IncrementalDebugState, zcu: *Zcu, ty: InternPool.Index) Allocator.Error!void {
        try ids.types.putNoClobber(zcu.gpa, ty, zcu.generation);
    }
    pub fn newNav(ids: *IncrementalDebugState, zcu: *Zcu, nav: InternPool.Nav.Index) Allocator.Error!void {
        try ids.navs.putNoClobber(zcu.gpa, nav, zcu.generation);
    }
};

pub const PerThread = @import("Zcu/PerThread.zig");

pub const ImportTableAdapter = struct {
    zcu: *const Zcu,
    pub fn hash(ctx: ImportTableAdapter, path: Compilation.Path) u32 {
        _ = ctx;
        return @truncate(std.hash.Wyhash.hash(@intFromEnum(path.root), path.sub_path));
    }
    pub fn eql(ctx: ImportTableAdapter, a_path: Compilation.Path, b_file: File.Index, b_index: usize) bool {
        _ = b_index;
        const b_path = ctx.zcu.fileByIndex(b_file).path;
        return a_path.root == b_path.root and mem.eql(u8, a_path.sub_path, b_path.sub_path);
    }
};

pub const EmbedTableAdapter = struct {
    pub fn hash(ctx: EmbedTableAdapter, path: Compilation.Path) u32 {
        _ = ctx;
        return @truncate(std.hash.Wyhash.hash(@intFromEnum(path.root), path.sub_path));
    }
    pub fn eql(ctx: EmbedTableAdapter, a_path: Compilation.Path, b_file: *EmbedFile, b_index: usize) bool {
        _ = ctx;
        _ = b_index;
        const b_path = b_file.path;
        return a_path.root == b_path.root and mem.eql(u8, a_path.sub_path, b_path.sub_path);
    }
};

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
    @"panic.sliceCastLenRemainder",
    @"panic.reachedUnreachable",
    @"panic.unwrapNull",
    @"panic.castToNull",
    @"panic.incorrectAlignment",
    @"panic.invalidErrorCode",
    @"panic.integerOutOfBounds",
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
    @"panic.copyLenMismatch",
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
            .@"panic.sliceCastLenRemainder",
            .@"panic.reachedUnreachable",
            .@"panic.unwrapNull",
            .@"panic.castToNull",
            .@"panic.incorrectAlignment",
            .@"panic.invalidErrorCode",
            .@"panic.integerOutOfBounds",
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
            .@"panic.copyLenMismatch",
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
    integer_out_of_bounds,
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
    copy_len_mismatch,
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
            .integer_out_of_bounds      => .@"panic.integerOutOfBounds",
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
            .copy_len_mismatch          => .@"panic.copyLenMismatch",
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

pub const CompileLogLine = struct {
    next: Index.Optional,
    /// Does *not* include the trailing newline.
    data: InternPool.NullTerminatedString,
    pub const Index = enum(u32) {
        _,
        pub fn get(idx: Index, zcu: *Zcu) *CompileLogLine {
            return &zcu.compile_log_lines.items[@intFromEnum(idx)];
        }
        pub fn toOptional(idx: Index) Optional {
            return @enumFromInt(@intFromEnum(idx));
        }
        pub const Optional = enum(u32) {
            none = std.math.maxInt(u32),
            _,
            pub fn unwrap(opt: Optional) ?Index {
                return switch (opt) {
                    .none => null,
                    _ => @enumFromInt(@intFromEnum(opt)),
                };
            }
        };
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
    /// If not `.none`, this is the index of the `InlineReferenceFrame` which should appear
    /// between the referencer and `referenced` in the reference trace. These frames represent
    /// inline calls, which do not create actual references (since they happen in the caller's
    /// `AnalUnit`), but do show in the reference trace.
    inline_frame: InlineReferenceFrame.Index.Optional,
};

pub const InlineReferenceFrame = struct {
    /// The inline *callee*; that is, the function which was called inline.
    /// The *caller* is either `parent`, or else the unit causing the original `Reference`.
    callee: InternPool.Index,
    /// The source location of the inline call, in the *caller*.
    call_src: LazySrcLoc,
    /// If not `.none`, a frame which should appear directly below this one.
    /// This will be the "parent" inline call; this frame's `callee` is our caller.
    parent: InlineReferenceFrame.Index.Optional,

    pub const Index = enum(u32) {
        _,
        pub fn ptr(idx: Index, zcu: *Zcu) *InlineReferenceFrame {
            return &zcu.inline_reference_frames.items[@intFromEnum(idx)];
        }
        pub fn toOptional(idx: Index) Optional {
            return @enumFromInt(@intFromEnum(idx));
        }
        pub const Optional = enum(u32) {
            none = std.math.maxInt(u32),
            _,
            pub fn unwrap(opt: Optional) ?Index {
                return switch (opt) {
                    .none => null,
                    _ => @enumFromInt(@intFromEnum(opt)),
                };
            }
        };
    };
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
            return std.hash.int(@intFromEnum(name));
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
            return std.hash.int(@intFromEnum(s));
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
        if (name != .empty) try writer.print("{c}{f}", .{ sep, name.fmt(&zcu.intern_pool) });
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
        return ip.getOrPutStringFmt(gpa, tid, "{f}.{f}", .{ ns_name.fmt(ip), name.fmt(ip) }, .no_embedded_nulls);
    }
};

pub const File = struct {
    status: enum {
        /// We have not yet attempted to load this file.
        /// `stat` is not populated and may be `undefined`.
        never_loaded,
        /// A filesystem access failed. It should be retried on the next update.
        /// There is guaranteed to be a `failed_files` entry with at least one message.
        /// ZIR/ZOIR errors should not be emitted as `zir`/`zoir` is not up-to-date.
        /// `stat` is not populated and may be `undefined`.
        retryable_failure,
        /// This file has failed parsing, AstGen, or ZonGen.
        /// There is guaranteed to be a `failed_files` entry, which may or may not have messages.
        /// ZIR/ZOIR errors *should* be emitted as `zir`/`zoir` is up-to-date.
        /// `stat` is populated.
        astgen_failure,
        /// Parsing and AstGen/ZonGen of this file has succeeded.
        /// There may still be a `failed_files` entry, e.g. for non-fatal AstGen errors.
        /// `stat` is populated.
        success,
    },
    /// Whether this is populated depends on `status`.
    stat: Cache.File.Stat,

    /// Whether this file is the generated file of a "builtin" module. This matters because those
    /// files are generated and stored in-nemory rather than being read off-disk. The rest of the
    /// pipeline generally shouldn't care about this.
    is_builtin: bool,

    /// The path of this file. It is important that this path has a "canonical form" because files
    /// are deduplicated based on path; `Compilation.Path` guarantees this. Owned by this `File`,
    /// allocated into `gpa`.
    path: Compilation.Path,

    source: ?[:0]const u8,
    tree: ?Ast,
    zir: ?Zir,
    zoir: ?Zoir,

    /// Module that this file is a part of, managed externally.
    /// This is initially `null`. After AstGen, a pass is run to determine which module each
    /// file belongs to, at which point this field is set. It is never set to `null` again;
    /// this is so that if the file starts belonging to a different module instead, we can
    /// tell, and invalidate dependencies as needed (see `module_changed`).
    /// During semantic analysis, this is always non-`null` for alive files (i.e. those which
    /// have imports targeting them).
    mod: ?*Package.Module,
    /// Relative to the root directory of `mod`. If `mod == null`, this field is `undefined`.
    /// This memory is managed externally and must not be directly freed.
    /// Its lifetime is at least equal to that of this `File`.
    sub_file_path: []const u8,

    /// If this file's module identity changes on an incremental update, this flag is set to signal
    /// to `Zcu.updateZirRefs` that all references to this file must be invalidated. This matters
    /// because changing your module changes things like your optimization mode and codegen flags,
    /// so everything needs to be re-done. `updateZirRefs` is responsible for resetting this flag.
    module_changed: bool,

    /// The ZIR for this file from the last update with no file failures. As such, this ZIR is never
    /// failed (although it may have compile errors).
    ///
    /// Because updates with file failures do not perform ZIR mapping or semantic analysis, we keep
    /// this around so we have the "old" ZIR to map when an update is ready to do so. Once such an
    /// update occurs, this field is unloaded, since it is no longer necessary.
    ///
    /// In other words, if `TrackedInst`s are tied to ZIR other than what's in the `zir` field, this
    /// field is populated with that old ZIR.
    prev_zir: ?*Zir,

    /// This field serves a similar purpose to `prev_zir`, but for ZOIR. However, since we do not
    /// need to map old ZOIR to new ZOIR -- instead only invalidating dependencies if the ZOIR
    /// changed -- this field is just a simple boolean.
    ///
    /// When `zoir` is updated, this field is set to `true`. In `updateZirRefs`, if this is `true`,
    /// we invalidate the corresponding `zon_file` dependency, and reset it to `false`.
    zoir_invalidated: bool,

    pub const Path = struct {
        root: enum {
            cwd,
            fs_root,
            local_cache,
            global_cache,
            lib_dir,
        },
    };

    /// A single reference to a file.
    pub const Reference = union(enum) {
        analysis_root: *Package.Module,
        import: struct {
            importer: Zcu.File.Index,
            tok: Ast.TokenIndex,
            /// If the file is imported as the root of a module, this is that module.
            /// `null` means the file was imported directly by path.
            module: ?*Package.Module,
        },
    };

    pub fn getMode(self: File) Ast.Mode {
        // We never create a `File` whose path doesn't give a mode.
        return modeFromPath(self.path.sub_path).?;
    }

    pub fn modeFromPath(path: []const u8) ?Ast.Mode {
        if (std.mem.endsWith(u8, path, ".zon")) {
            return .zon;
        } else if (std.mem.endsWith(u8, path, ".zig")) {
            return .zig;
        } else {
            return null;
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

    pub fn getSource(file: *File, zcu: *const Zcu) !Source {
        const gpa = zcu.gpa;

        if (file.source) |source| return .{
            .bytes = source,
            .stat = file.stat,
        };

        var f = f: {
            const dir, const sub_path = file.path.openInfo(zcu.comp.dirs);
            break :f try dir.openFile(sub_path, .{});
        };
        defer f.close();

        const stat = try f.stat();

        if (stat.size > std.math.maxInt(u32))
            return error.FileTooBig;

        const source = try gpa.allocSentinel(u8, @intCast(stat.size), 0);
        errdefer gpa.free(source);

        var file_reader = f.reader(&.{});
        file_reader.size = stat.size;
        try file_reader.interface.readSliceAll(source);

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

    pub fn getTree(file: *File, zcu: *const Zcu) !*const Ast {
        if (file.tree) |*tree| return tree;

        const source = try file.getSource(zcu);
        file.tree = try .parse(zcu.gpa, source.bytes, file.getMode());
        return &file.tree.?;
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
        var w: Writer = .fixed((try strings.addManyAsSlice(file.fullyQualifiedNameLen()))[0]);
        file.renderFullyQualifiedName(&w) catch unreachable;
        assert(w.end == w.buffer.len);
        return ip.getOrPutTrailingString(gpa, pt.tid, @intCast(w.end), .no_embedded_nulls);
    }

    pub const Index = InternPool.FileIndex;

    pub fn errorBundleWholeFileSrc(
        file: *File,
        zcu: *const Zcu,
        eb: *std.zig.ErrorBundle.Wip,
    ) !std.zig.ErrorBundle.SourceLocationIndex {
        return eb.addSourceLocation(.{
            .src_path = try eb.printString("{f}", .{file.path.fmt(zcu.comp)}),
            .span_start = 0,
            .span_main = 0,
            .span_end = 0,
            .line = 0,
            .column = 0,
            .source_line = 0,
        });
    }
    pub fn errorBundleTokenSrc(
        file: *File,
        tok: Ast.TokenIndex,
        zcu: *const Zcu,
        eb: *std.zig.ErrorBundle.Wip,
    ) !std.zig.ErrorBundle.SourceLocationIndex {
        const source = try file.getSource(zcu);
        const tree = try file.getTree(zcu);
        const start = tree.tokenStart(tok);
        const end = start + tree.tokenSlice(tok).len;
        const loc = std.zig.findLineColumn(source.bytes, start);
        return eb.addSourceLocation(.{
            .src_path = try eb.printString("{f}", .{file.path.fmt(zcu.comp)}),
            .span_start = start,
            .span_main = start,
            .span_end = @intCast(end),
            .line = @intCast(loc.line),
            .column = @intCast(loc.column),
            .source_line = try eb.addString(loc.source_line),
        });
    }
};

/// Represents the contents of a file loaded with `@embedFile`.
pub const EmbedFile = struct {
    path: Compilation.Path,
    /// `.none` means the file was not loaded, so `stat` is undefined.
    val: InternPool.Index,
    /// If this is `null` and `val` is `.none`, the file has never been loaded.
    err: ?(std.fs.File.OpenError || std.fs.File.StatError || std.fs.File.ReadError || error{UnexpectedEof}),
    stat: Cache.File.Stat,

    pub const Index = enum(u32) {
        _,
        pub fn get(idx: Index, zcu: *const Zcu) *EmbedFile {
            return zcu.embed_table.keys()[@intFromEnum(idx)];
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

    pub fn init(gpa: Allocator, src_loc: LazySrcLoc, comptime format: []const u8, args: anytype) !ErrorMsg {
        return .{
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

    pub const Span = Ast.Span;

    pub fn span(src_loc: SrcLoc, zcu: *const Zcu) !Span {
        switch (src_loc.lazy) {
            .unneeded => unreachable,

            .byte_abs => |byte_index| return Span{ .start = byte_index, .end = byte_index + 1, .main = byte_index },

            .token_abs => |tok_index| {
                const tree = try src_loc.file_scope.getTree(zcu);
                const start = tree.tokenStart(tok_index);
                const end = start + @as(u32, @intCast(tree.tokenSlice(tok_index).len));
                return Span{ .start = start, .end = end, .main = start };
            },
            .node_abs => |node| {
                const tree = try src_loc.file_scope.getTree(zcu);
                return tree.nodeToSpan(node);
            },
            .byte_offset => |byte_off| {
                const tree = try src_loc.file_scope.getTree(zcu);
                const tok_index = src_loc.baseSrcToken();
                const start = tree.tokenStart(tok_index) + byte_off;
                const end = start + @as(u32, @intCast(tree.tokenSlice(tok_index).len));
                return Span{ .start = start, .end = end, .main = start };
            },
            .token_offset => |tok_off| {
                const tree = try src_loc.file_scope.getTree(zcu);
                const tok_index = tok_off.toAbsolute(src_loc.baseSrcToken());
                const start = tree.tokenStart(tok_index);
                const end = start + @as(u32, @intCast(tree.tokenSlice(tok_index).len));
                return Span{ .start = start, .end = end, .main = start };
            },
            .node_offset => |traced_off| {
                const node_off = traced_off.x;
                const tree = try src_loc.file_scope.getTree(zcu);
                const node = node_off.toAbsolute(src_loc.base_node);
                return tree.nodeToSpan(node);
            },
            .node_offset_main_token => |node_off| {
                const tree = try src_loc.file_scope.getTree(zcu);
                const node = node_off.toAbsolute(src_loc.base_node);
                const main_token = tree.nodeMainToken(node);
                return tree.tokensToSpan(main_token, main_token, main_token);
            },
            .node_offset_bin_op => |node_off| {
                const tree = try src_loc.file_scope.getTree(zcu);
                const node = node_off.toAbsolute(src_loc.base_node);
                return tree.nodeToSpan(node);
            },
            .node_offset_initializer => |node_off| {
                const tree = try src_loc.file_scope.getTree(zcu);
                const node = node_off.toAbsolute(src_loc.base_node);
                return tree.tokensToSpan(
                    tree.firstToken(node) - 3,
                    tree.lastToken(node),
                    tree.nodeMainToken(node) - 2,
                );
            },
            .node_offset_var_decl_ty => |node_off| {
                const tree = try src_loc.file_scope.getTree(zcu);
                const node = node_off.toAbsolute(src_loc.base_node);
                const full = switch (tree.nodeTag(node)) {
                    .global_var_decl,
                    .local_var_decl,
                    .simple_var_decl,
                    .aligned_var_decl,
                    => tree.fullVarDecl(node).?,
                    else => unreachable,
                };
                if (full.ast.type_node.unwrap()) |type_node| {
                    return tree.nodeToSpan(type_node);
                }
                const tok_index = full.ast.mut_token + 1; // the name token
                const start = tree.tokenStart(tok_index);
                const end = start + @as(u32, @intCast(tree.tokenSlice(tok_index).len));
                return Span{ .start = start, .end = end, .main = start };
            },
            .node_offset_var_decl_align => |node_off| {
                const tree = try src_loc.file_scope.getTree(zcu);
                const node = node_off.toAbsolute(src_loc.base_node);
                var buf: [1]Ast.Node.Index = undefined;
                const align_node = if (tree.fullVarDecl(node)) |v|
                    v.ast.align_node.unwrap().?
                else if (tree.fullFnProto(&buf, node)) |f|
                    f.ast.align_expr.unwrap().?
                else
                    unreachable;
                return tree.nodeToSpan(align_node);
            },
            .node_offset_var_decl_section => |node_off| {
                const tree = try src_loc.file_scope.getTree(zcu);
                const node = node_off.toAbsolute(src_loc.base_node);
                var buf: [1]Ast.Node.Index = undefined;
                const section_node = if (tree.fullVarDecl(node)) |v|
                    v.ast.section_node.unwrap().?
                else if (tree.fullFnProto(&buf, node)) |f|
                    f.ast.section_expr.unwrap().?
                else
                    unreachable;
                return tree.nodeToSpan(section_node);
            },
            .node_offset_var_decl_addrspace => |node_off| {
                const tree = try src_loc.file_scope.getTree(zcu);
                const node = node_off.toAbsolute(src_loc.base_node);
                var buf: [1]Ast.Node.Index = undefined;
                const addrspace_node = if (tree.fullVarDecl(node)) |v|
                    v.ast.addrspace_node.unwrap().?
                else if (tree.fullFnProto(&buf, node)) |f|
                    f.ast.addrspace_expr.unwrap().?
                else
                    unreachable;
                return tree.nodeToSpan(addrspace_node);
            },
            .node_offset_var_decl_init => |node_off| {
                const tree = try src_loc.file_scope.getTree(zcu);
                const node = node_off.toAbsolute(src_loc.base_node);
                const init_node = switch (tree.nodeTag(node)) {
                    .global_var_decl,
                    .local_var_decl,
                    .aligned_var_decl,
                    .simple_var_decl,
                    => tree.fullVarDecl(node).?.ast.init_node.unwrap().?,
                    .assign_destructure => tree.assignDestructure(node).ast.value_expr,
                    else => unreachable,
                };
                return tree.nodeToSpan(init_node);
            },
            .node_offset_builtin_call_arg => |builtin_arg| {
                const tree = try src_loc.file_scope.getTree(zcu);
                const node = builtin_arg.builtin_call_node.toAbsolute(src_loc.base_node);
                var buf: [2]Ast.Node.Index = undefined;
                const params = tree.builtinCallParams(&buf, node).?;
                return tree.nodeToSpan(params[builtin_arg.arg_index]);
            },
            .node_offset_ptrcast_operand => |node_off| {
                const tree = try src_loc.file_scope.getTree(zcu);

                var node = node_off.toAbsolute(src_loc.base_node);
                while (true) {
                    switch (tree.nodeTag(node)) {
                        .builtin_call_two, .builtin_call_two_comma => {},
                        else => break,
                    }

                    const first_arg, const second_arg = tree.nodeData(node).opt_node_and_opt_node;
                    if (first_arg == .none) break; // 0 args
                    if (second_arg != .none) break; // 2 args

                    const builtin_token = tree.nodeMainToken(node);
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

                    node = first_arg.unwrap().?;
                }

                return tree.nodeToSpan(node);
            },
            .node_offset_array_access_index => |node_off| {
                const tree = try src_loc.file_scope.getTree(zcu);
                const node = node_off.toAbsolute(src_loc.base_node);
                return tree.nodeToSpan(tree.nodeData(node).node_and_node[1]);
            },
            .node_offset_slice_ptr,
            .node_offset_slice_start,
            .node_offset_slice_end,
            .node_offset_slice_sentinel,
            => |node_off| {
                const tree = try src_loc.file_scope.getTree(zcu);
                const node = node_off.toAbsolute(src_loc.base_node);
                const full = tree.fullSlice(node).?;
                const part_node = switch (src_loc.lazy) {
                    .node_offset_slice_ptr => full.ast.sliced,
                    .node_offset_slice_start => full.ast.start,
                    .node_offset_slice_end => full.ast.end.unwrap().?,
                    .node_offset_slice_sentinel => full.ast.sentinel.unwrap().?,
                    else => unreachable,
                };
                return tree.nodeToSpan(part_node);
            },
            .node_offset_call_func => |node_off| {
                const tree = try src_loc.file_scope.getTree(zcu);
                const node = node_off.toAbsolute(src_loc.base_node);
                var buf: [1]Ast.Node.Index = undefined;
                const full = tree.fullCall(&buf, node).?;
                return tree.nodeToSpan(full.ast.fn_expr);
            },
            .node_offset_field_name => |node_off| {
                const tree = try src_loc.file_scope.getTree(zcu);
                const node = node_off.toAbsolute(src_loc.base_node);
                var buf: [1]Ast.Node.Index = undefined;
                const tok_index = switch (tree.nodeTag(node)) {
                    .field_access => tree.nodeData(node).node_and_token[1],
                    .call_one,
                    .call_one_comma,
                    .call,
                    .call_comma,
                    => blk: {
                        const full = tree.fullCall(&buf, node).?;
                        break :blk tree.lastToken(full.ast.fn_expr);
                    },
                    else => tree.firstToken(node) - 2,
                };
                const start = tree.tokenStart(tok_index);
                const end = start + @as(u32, @intCast(tree.tokenSlice(tok_index).len));
                return Span{ .start = start, .end = end, .main = start };
            },
            .node_offset_field_name_init => |node_off| {
                const tree = try src_loc.file_scope.getTree(zcu);
                const node = node_off.toAbsolute(src_loc.base_node);
                const tok_index = tree.firstToken(node) - 2;
                const start = tree.tokenStart(tok_index);
                const end = start + @as(u32, @intCast(tree.tokenSlice(tok_index).len));
                return Span{ .start = start, .end = end, .main = start };
            },
            .node_offset_deref_ptr => |node_off| {
                const tree = try src_loc.file_scope.getTree(zcu);
                const node = node_off.toAbsolute(src_loc.base_node);
                return tree.nodeToSpan(node);
            },
            .node_offset_asm_source => |node_off| {
                const tree = try src_loc.file_scope.getTree(zcu);
                const node = node_off.toAbsolute(src_loc.base_node);
                const full = tree.fullAsm(node).?;
                return tree.nodeToSpan(full.ast.template);
            },
            .node_offset_asm_ret_ty => |node_off| {
                const tree = try src_loc.file_scope.getTree(zcu);
                const node = node_off.toAbsolute(src_loc.base_node);
                const full = tree.fullAsm(node).?;
                const asm_output = full.outputs[0];
                return tree.nodeToSpan(tree.nodeData(asm_output).opt_node_and_token[0].unwrap().?);
            },

            .node_offset_if_cond => |node_off| {
                const tree = try src_loc.file_scope.getTree(zcu);
                const node = node_off.toAbsolute(src_loc.base_node);
                const src_node = switch (tree.nodeTag(node)) {
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
                const tree = try src_loc.file_scope.getTree(zcu);
                const node = for_input.for_node_offset.toAbsolute(src_loc.base_node);
                const for_full = tree.fullFor(node).?;
                const src_node = for_full.ast.inputs[for_input.input_index];
                return tree.nodeToSpan(src_node);
            },
            .for_capture_from_input => |node_off| {
                const tree = try src_loc.file_scope.getTree(zcu);
                const input_node = node_off.toAbsolute(src_loc.base_node);
                // We have to actually linear scan the whole AST to find the for loop
                // that contains this input.
                const node_tags = tree.nodes.items(.tag);
                for (node_tags, 0..) |node_tag, node_usize| {
                    const node: Ast.Node.Index = @enumFromInt(node_usize);
                    switch (node_tag) {
                        .for_simple, .@"for" => {
                            const for_full = tree.fullFor(node).?;
                            for (for_full.ast.inputs, 0..) |input, input_index| {
                                if (input_node == input) {
                                    var count = input_index;
                                    var tok = for_full.payload_token;
                                    while (true) {
                                        switch (tree.tokenTag(tok)) {
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
                const tree = try src_loc.file_scope.getTree(zcu);
                const node = call_arg.call_node_offset.toAbsolute(src_loc.base_node);
                var buf: [2]Ast.Node.Index = undefined;
                const call_full = tree.fullCall(buf[0..1], node) orelse {
                    assert(tree.nodeTag(node) == .builtin_call);
                    const call_args_node: Ast.Node.Index = @enumFromInt(tree.extra_data[@intFromEnum(tree.nodeData(node).extra_range.end) - 1]);
                    switch (tree.nodeTag(call_args_node)) {
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
                const tree = try src_loc.file_scope.getTree(zcu);
                const node = fn_proto_param.fn_proto_node_offset.toAbsolute(src_loc.base_node);
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
                            return tree.nodeToSpan(param.type_expr.?);
                        },
                        .fn_proto_param => if (param.anytype_ellipsis3) |tok| {
                            const first = param.comptime_noalias orelse param.name_token orelse tok;
                            return tree.tokensToSpan(first, tok, first);
                        } else {
                            const first = param.comptime_noalias orelse param.name_token orelse tree.firstToken(param.type_expr.?);
                            return tree.tokensToSpan(first, tree.lastToken(param.type_expr.?), first);
                        },
                        else => unreachable,
                    }
                }
                unreachable;
            },
            .node_offset_bin_lhs => |node_off| {
                const tree = try src_loc.file_scope.getTree(zcu);
                const node = node_off.toAbsolute(src_loc.base_node);
                return tree.nodeToSpan(tree.nodeData(node).node_and_node[0]);
            },
            .node_offset_bin_rhs => |node_off| {
                const tree = try src_loc.file_scope.getTree(zcu);
                const node = node_off.toAbsolute(src_loc.base_node);
                return tree.nodeToSpan(tree.nodeData(node).node_and_node[1]);
            },
            .array_cat_lhs, .array_cat_rhs => |cat| {
                const tree = try src_loc.file_scope.getTree(zcu);
                const node = cat.array_cat_offset.toAbsolute(src_loc.base_node);
                const arr_node = if (src_loc.lazy == .array_cat_lhs)
                    tree.nodeData(node).node_and_node[0]
                else
                    tree.nodeData(node).node_and_node[1];

                var buf: [2]Ast.Node.Index = undefined;
                switch (tree.nodeTag(arr_node)) {
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

            .node_offset_try_operand => |node_off| {
                const tree = try src_loc.file_scope.getTree(zcu);
                const node = node_off.toAbsolute(src_loc.base_node);
                return tree.nodeToSpan(tree.nodeData(node).node);
            },

            .node_offset_switch_operand => |node_off| {
                const tree = try src_loc.file_scope.getTree(zcu);
                const node = node_off.toAbsolute(src_loc.base_node);
                const condition, _ = tree.nodeData(node).node_and_extra;
                return tree.nodeToSpan(condition);
            },

            .node_offset_switch_special_prong => |node_off| {
                const tree = try src_loc.file_scope.getTree(zcu);
                const switch_node = node_off.toAbsolute(src_loc.base_node);
                _, const extra_index = tree.nodeData(switch_node).node_and_extra;
                const case_nodes = tree.extraDataSlice(tree.extraData(extra_index, Ast.Node.SubRange), Ast.Node.Index);
                for (case_nodes) |case_node| {
                    const case = tree.fullSwitchCase(case_node).?;
                    const is_special = (case.ast.values.len == 0) or
                        (case.ast.values.len == 1 and
                            tree.nodeTag(case.ast.values[0]) == .identifier and
                            mem.eql(u8, tree.tokenSlice(tree.nodeMainToken(case.ast.values[0])), "_"));
                    if (!is_special) continue;

                    return tree.nodeToSpan(case_node);
                } else unreachable;
            },

            .node_offset_switch_range => |node_off| {
                const tree = try src_loc.file_scope.getTree(zcu);
                const switch_node = node_off.toAbsolute(src_loc.base_node);
                _, const extra_index = tree.nodeData(switch_node).node_and_extra;
                const case_nodes = tree.extraDataSlice(tree.extraData(extra_index, Ast.Node.SubRange), Ast.Node.Index);
                for (case_nodes) |case_node| {
                    const case = tree.fullSwitchCase(case_node).?;
                    const is_special = (case.ast.values.len == 0) or
                        (case.ast.values.len == 1 and
                            tree.nodeTag(case.ast.values[0]) == .identifier and
                            mem.eql(u8, tree.tokenSlice(tree.nodeMainToken(case.ast.values[0])), "_"));
                    if (is_special) continue;

                    for (case.ast.values) |item_node| {
                        if (tree.nodeTag(item_node) == .switch_range) {
                            return tree.nodeToSpan(item_node);
                        }
                    }
                } else unreachable;
            },
            .node_offset_fn_type_align => |node_off| {
                const tree = try src_loc.file_scope.getTree(zcu);
                const node = node_off.toAbsolute(src_loc.base_node);
                var buf: [1]Ast.Node.Index = undefined;
                const full = tree.fullFnProto(&buf, node).?;
                return tree.nodeToSpan(full.ast.align_expr.unwrap().?);
            },
            .node_offset_fn_type_addrspace => |node_off| {
                const tree = try src_loc.file_scope.getTree(zcu);
                const node = node_off.toAbsolute(src_loc.base_node);
                var buf: [1]Ast.Node.Index = undefined;
                const full = tree.fullFnProto(&buf, node).?;
                return tree.nodeToSpan(full.ast.addrspace_expr.unwrap().?);
            },
            .node_offset_fn_type_section => |node_off| {
                const tree = try src_loc.file_scope.getTree(zcu);
                const node = node_off.toAbsolute(src_loc.base_node);
                var buf: [1]Ast.Node.Index = undefined;
                const full = tree.fullFnProto(&buf, node).?;
                return tree.nodeToSpan(full.ast.section_expr.unwrap().?);
            },
            .node_offset_fn_type_cc => |node_off| {
                const tree = try src_loc.file_scope.getTree(zcu);
                const node = node_off.toAbsolute(src_loc.base_node);
                var buf: [1]Ast.Node.Index = undefined;
                const full = tree.fullFnProto(&buf, node).?;
                return tree.nodeToSpan(full.ast.callconv_expr.unwrap().?);
            },

            .node_offset_fn_type_ret_ty => |node_off| {
                const tree = try src_loc.file_scope.getTree(zcu);
                const node = node_off.toAbsolute(src_loc.base_node);
                var buf: [1]Ast.Node.Index = undefined;
                const full = tree.fullFnProto(&buf, node).?;
                return tree.nodeToSpan(full.ast.return_type.unwrap().?);
            },
            .node_offset_param => |node_off| {
                const tree = try src_loc.file_scope.getTree(zcu);
                const node = node_off.toAbsolute(src_loc.base_node);

                var first_tok = tree.firstToken(node);
                while (true) switch (tree.tokenTag(first_tok - 1)) {
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
                const tree = try src_loc.file_scope.getTree(zcu);
                const main_token = tree.nodeMainToken(src_loc.base_node);
                const tok_index = token_off.toAbsolute(main_token);

                var first_tok = tok_index;
                while (true) switch (tree.tokenTag(first_tok - 1)) {
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
                const tree = try src_loc.file_scope.getTree(zcu);
                const parent_node = node_off.toAbsolute(src_loc.base_node);
                _, const child_type = tree.nodeData(parent_node).token_and_node;
                return tree.nodeToSpan(child_type);
            },

            .node_offset_lib_name => |node_off| {
                const tree = try src_loc.file_scope.getTree(zcu);
                const parent_node = node_off.toAbsolute(src_loc.base_node);
                var buf: [1]Ast.Node.Index = undefined;
                const full = tree.fullFnProto(&buf, parent_node).?;
                const tok_index = full.lib_name.?;
                const start = tree.tokenStart(tok_index);
                const end = start + @as(u32, @intCast(tree.tokenSlice(tok_index).len));
                return Span{ .start = start, .end = end, .main = start };
            },

            .node_offset_array_type_len => |node_off| {
                const tree = try src_loc.file_scope.getTree(zcu);
                const parent_node = node_off.toAbsolute(src_loc.base_node);

                const full = tree.fullArrayType(parent_node).?;
                return tree.nodeToSpan(full.ast.elem_count);
            },
            .node_offset_array_type_sentinel => |node_off| {
                const tree = try src_loc.file_scope.getTree(zcu);
                const parent_node = node_off.toAbsolute(src_loc.base_node);

                const full = tree.fullArrayType(parent_node).?;
                return tree.nodeToSpan(full.ast.sentinel.unwrap().?);
            },
            .node_offset_array_type_elem => |node_off| {
                const tree = try src_loc.file_scope.getTree(zcu);
                const parent_node = node_off.toAbsolute(src_loc.base_node);

                const full = tree.fullArrayType(parent_node).?;
                return tree.nodeToSpan(full.ast.elem_type);
            },
            .node_offset_un_op => |node_off| {
                const tree = try src_loc.file_scope.getTree(zcu);
                const node = node_off.toAbsolute(src_loc.base_node);
                return tree.nodeToSpan(tree.nodeData(node).node);
            },
            .node_offset_ptr_elem => |node_off| {
                const tree = try src_loc.file_scope.getTree(zcu);
                const parent_node = node_off.toAbsolute(src_loc.base_node);

                const full = tree.fullPtrType(parent_node).?;
                return tree.nodeToSpan(full.ast.child_type);
            },
            .node_offset_ptr_sentinel => |node_off| {
                const tree = try src_loc.file_scope.getTree(zcu);
                const parent_node = node_off.toAbsolute(src_loc.base_node);

                const full = tree.fullPtrType(parent_node).?;
                return tree.nodeToSpan(full.ast.sentinel.unwrap().?);
            },
            .node_offset_ptr_align => |node_off| {
                const tree = try src_loc.file_scope.getTree(zcu);
                const parent_node = node_off.toAbsolute(src_loc.base_node);

                const full = tree.fullPtrType(parent_node).?;
                return tree.nodeToSpan(full.ast.align_node.unwrap().?);
            },
            .node_offset_ptr_addrspace => |node_off| {
                const tree = try src_loc.file_scope.getTree(zcu);
                const parent_node = node_off.toAbsolute(src_loc.base_node);

                const full = tree.fullPtrType(parent_node).?;
                return tree.nodeToSpan(full.ast.addrspace_node.unwrap().?);
            },
            .node_offset_ptr_bitoffset => |node_off| {
                const tree = try src_loc.file_scope.getTree(zcu);
                const parent_node = node_off.toAbsolute(src_loc.base_node);

                const full = tree.fullPtrType(parent_node).?;
                return tree.nodeToSpan(full.ast.bit_range_start.unwrap().?);
            },
            .node_offset_ptr_hostsize => |node_off| {
                const tree = try src_loc.file_scope.getTree(zcu);
                const parent_node = node_off.toAbsolute(src_loc.base_node);

                const full = tree.fullPtrType(parent_node).?;
                return tree.nodeToSpan(full.ast.bit_range_end.unwrap().?);
            },
            .node_offset_container_tag => |node_off| {
                const tree = try src_loc.file_scope.getTree(zcu);
                const parent_node = node_off.toAbsolute(src_loc.base_node);

                switch (tree.nodeTag(parent_node)) {
                    .container_decl_arg, .container_decl_arg_trailing => {
                        const full = tree.containerDeclArg(parent_node);
                        const arg_node = full.ast.arg.unwrap().?;
                        return tree.nodeToSpan(arg_node);
                    },
                    .tagged_union_enum_tag, .tagged_union_enum_tag_trailing => {
                        const full = tree.taggedUnionEnumTag(parent_node);
                        const arg_node = full.ast.arg.unwrap().?;

                        return tree.tokensToSpan(
                            tree.firstToken(arg_node) - 2,
                            tree.lastToken(arg_node) + 1,
                            tree.nodeMainToken(arg_node),
                        );
                    },
                    else => unreachable,
                }
            },
            .node_offset_field_default => |node_off| {
                const tree = try src_loc.file_scope.getTree(zcu);
                const parent_node = node_off.toAbsolute(src_loc.base_node);

                const full: Ast.full.ContainerField = switch (tree.nodeTag(parent_node)) {
                    .container_field => tree.containerField(parent_node),
                    .container_field_init => tree.containerFieldInit(parent_node),
                    else => unreachable,
                };
                return tree.nodeToSpan(full.ast.value_expr.unwrap().?);
            },
            .node_offset_init_ty => |node_off| {
                const tree = try src_loc.file_scope.getTree(zcu);
                const parent_node = node_off.toAbsolute(src_loc.base_node);

                var buf: [2]Ast.Node.Index = undefined;
                const type_expr = if (tree.fullArrayInit(&buf, parent_node)) |array_init|
                    array_init.ast.type_expr.unwrap().?
                else
                    tree.fullStructInit(&buf, parent_node).?.ast.type_expr.unwrap().?;
                return tree.nodeToSpan(type_expr);
            },
            .node_offset_store_ptr => |node_off| {
                const tree = try src_loc.file_scope.getTree(zcu);
                const node = node_off.toAbsolute(src_loc.base_node);

                switch (tree.nodeTag(node)) {
                    .assign,
                    .assign_mul,
                    .assign_div,
                    .assign_mod,
                    .assign_add,
                    .assign_sub,
                    .assign_shl,
                    .assign_shl_sat,
                    .assign_shr,
                    .assign_bit_and,
                    .assign_bit_xor,
                    .assign_bit_or,
                    .assign_mul_wrap,
                    .assign_add_wrap,
                    .assign_sub_wrap,
                    .assign_mul_sat,
                    .assign_add_sat,
                    .assign_sub_sat,
                    => return tree.nodeToSpan(tree.nodeData(node).node_and_node[0]),
                    else => return tree.nodeToSpan(node),
                }
            },
            .node_offset_store_operand => |node_off| {
                const tree = try src_loc.file_scope.getTree(zcu);
                const node = node_off.toAbsolute(src_loc.base_node);

                switch (tree.nodeTag(node)) {
                    .assign,
                    .assign_mul,
                    .assign_div,
                    .assign_mod,
                    .assign_add,
                    .assign_sub,
                    .assign_shl,
                    .assign_shl_sat,
                    .assign_shr,
                    .assign_bit_and,
                    .assign_bit_xor,
                    .assign_bit_or,
                    .assign_mul_wrap,
                    .assign_add_wrap,
                    .assign_sub_wrap,
                    .assign_mul_sat,
                    .assign_add_sat,
                    .assign_sub_sat,
                    => return tree.nodeToSpan(tree.nodeData(node).node_and_node[1]),
                    else => return tree.nodeToSpan(node),
                }
            },
            .node_offset_return_operand => |node_off| {
                const tree = try src_loc.file_scope.getTree(zcu);
                const node = node_off.toAbsolute(src_loc.base_node);
                if (tree.nodeTag(node) == .@"return") {
                    if (tree.nodeData(node).opt_node.unwrap()) |lhs| {
                        return tree.nodeToSpan(lhs);
                    }
                }
                return tree.nodeToSpan(node);
            },
            .container_field_name,
            .container_field_value,
            .container_field_type,
            .container_field_align,
            => |field_idx| {
                const tree = try src_loc.file_scope.getTree(zcu);
                const node = src_loc.base_node;
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
                        .container_field_name => .none,
                        .container_field_value => field.ast.value_expr,
                        .container_field_type => field.ast.type_expr,
                        .container_field_align => field.ast.align_expr,
                        else => unreachable,
                    };
                    if (field_component_node.unwrap()) |component_node| {
                        return tree.nodeToSpan(component_node);
                    } else {
                        return tree.tokenToSpan(field.ast.main_token);
                    }
                } else unreachable;
            },
            .tuple_field_type, .tuple_field_init => |field_info| {
                const tree = try src_loc.file_scope.getTree(zcu);
                const node = src_loc.base_node;
                var buf: [2]Ast.Node.Index = undefined;
                const container_decl = tree.fullContainerDecl(&buf, node) orelse
                    return tree.nodeToSpan(node);

                const field = tree.fullContainerField(container_decl.ast.members[field_info.elem_index]).?;
                return tree.nodeToSpan(switch (src_loc.lazy) {
                    .tuple_field_type => field.ast.type_expr.unwrap().?,
                    .tuple_field_init => field.ast.value_expr.unwrap().?,
                    else => unreachable,
                });
            },
            .init_elem => |init_elem| {
                const tree = try src_loc.file_scope.getTree(zcu);
                const init_node = init_elem.init_node_offset.toAbsolute(src_loc.base_node);
                var buf: [2]Ast.Node.Index = undefined;
                if (tree.fullArrayInit(&buf, init_node)) |full| {
                    const elem_node = full.ast.elements[init_elem.elem_index];
                    return tree.nodeToSpan(elem_node);
                } else if (tree.fullStructInit(&buf, init_node)) |full| {
                    const field_node = full.ast.fields[init_elem.elem_index];
                    return tree.tokensToSpan(
                        tree.firstToken(field_node) - 3,
                        tree.lastToken(field_node),
                        tree.nodeMainToken(field_node) - 2,
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
            .init_field_relocation,
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
                    .init_field_relocation => "relocation",
                    else => unreachable,
                };
                const tree = try src_loc.file_scope.getTree(zcu);
                const node = builtin_call_node.toAbsolute(src_loc.base_node);
                var builtin_buf: [2]Ast.Node.Index = undefined;
                const args = tree.builtinCallParams(&builtin_buf, node).?;
                const arg_node = args[1];
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
                            tree.nodeMainToken(field_node) - 2,
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

                const tree = try src_loc.file_scope.getTree(zcu);
                const switch_node = switch_node_offset.toAbsolute(src_loc.base_node);
                _, const extra_index = tree.nodeData(switch_node).node_and_extra;
                const case_nodes = tree.extraDataSlice(tree.extraData(extra_index, Ast.Node.SubRange), Ast.Node.Index);

                var multi_i: u32 = 0;
                var scalar_i: u32 = 0;
                const case = for (case_nodes) |case_node| {
                    const case = tree.fullSwitchCase(case_node).?;
                    const is_special = special: {
                        if (case.ast.values.len == 0) break :special true;
                        if (case.ast.values.len == 1 and tree.nodeTag(case.ast.values[0]) == .identifier) {
                            break :special mem.eql(u8, tree.tokenSlice(tree.nodeMainToken(case.ast.values[0])), "_");
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
                        tree.nodeTag(case.ast.values[0]) == .switch_range;

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
                        const start = switch (src_loc.lazy) {
                            .switch_capture => case.payload_token.?,
                            .switch_tag_capture => tok: {
                                var tok = case.payload_token.?;
                                if (tree.tokenTag(tok) == .asterisk) tok += 1;
                                tok = tok + 2; // skip over comma
                                break :tok tok;
                            },
                            else => unreachable,
                        };
                        const end = switch (tree.tokenTag(start)) {
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
                            if (tree.nodeTag(item_node) == .switch_range) continue;
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
                            if (tree.nodeTag(item_node) != .switch_range) continue;
                            if (range_i != want_item.index) {
                                range_i += 1;
                                continue;
                            }
                            const first, const last = tree.nodeData(item_node).node_and_node;
                            return switch (src_loc.lazy) {
                                .switch_case_item => tree.nodeToSpan(item_node),
                                .switch_case_item_range_first => tree.nodeToSpan(first),
                                .switch_case_item_range_last => tree.nodeToSpan(last),
                                else => unreachable,
                            };
                        } else unreachable;
                    },
                }
            },
            .func_decl_param_comptime => |param_idx| {
                const tree = try src_loc.file_scope.getTree(zcu);
                var buf: [1]Ast.Node.Index = undefined;
                const full = tree.fullFnProto(&buf, src_loc.base_node).?;
                var param_it = full.iterate(tree);
                for (0..param_idx) |_| assert(param_it.next() != null);
                const param = param_it.next().?;
                return tree.tokenToSpan(param.comptime_noalias.?);
            },
            .func_decl_param_ty => |param_idx| {
                const tree = try src_loc.file_scope.getTree(zcu);
                var buf: [1]Ast.Node.Index = undefined;
                const full = tree.fullFnProto(&buf, src_loc.base_node).?;
                var param_it = full.iterate(tree);
                for (0..param_idx) |_| assert(param_it.next() != null);
                const param = param_it.next().?;
                return tree.nodeToSpan(param.type_expr.?);
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
        /// The source location points to a byte offset within a source file,
        /// offset from 0. The source file is determined contextually.
        byte_abs: u32,
        /// The source location points to a token within a source file,
        /// offset from 0. The source file is determined contextually.
        token_abs: Ast.TokenIndex,
        /// The source location points to an AST node within a source file,
        /// offset from 0. The source file is determined contextually.
        node_abs: Ast.Node.Index,
        /// The source location points to a byte offset within a source file,
        /// offset from the byte offset of the base node within the file.
        byte_offset: u32,
        /// This data is the offset into the token list from the base node's first token.
        token_offset: Ast.TokenOffset,
        /// The source location points to an AST node, which is this value offset
        /// from its containing base node AST index.
        node_offset: TracedOffset,
        /// The source location points to the main token of an AST node, found
        /// by taking this AST node index offset from the containing base node.
        node_offset_main_token: Ast.Node.Offset,
        /// The source location points to the beginning of a struct initializer.
        node_offset_initializer: Ast.Node.Offset,
        /// The source location points to a variable declaration type expression,
        /// found by taking this AST node index offset from the containing
        /// base node, which points to a variable declaration AST node. Next, navigate
        /// to the type expression.
        node_offset_var_decl_ty: Ast.Node.Offset,
        /// The source location points to the alignment expression of a var decl.
        node_offset_var_decl_align: Ast.Node.Offset,
        /// The source location points to the linksection expression of a var decl.
        node_offset_var_decl_section: Ast.Node.Offset,
        /// The source location points to the addrspace expression of a var decl.
        node_offset_var_decl_addrspace: Ast.Node.Offset,
        /// The source location points to the initializer of a var decl.
        node_offset_var_decl_init: Ast.Node.Offset,
        /// The source location points to the given argument of a builtin function call.
        /// `builtin_call_node` points to the builtin call.
        /// `arg_index` is the index of the argument which hte source location refers to.
        node_offset_builtin_call_arg: struct {
            builtin_call_node: Ast.Node.Offset,
            arg_index: u32,
        },
        /// Like `node_offset_builtin_call_arg` but recurses through arbitrarily many calls
        /// to pointer cast builtins (taking the first argument of the most nested).
        node_offset_ptrcast_operand: Ast.Node.Offset,
        /// The source location points to the index expression of an array access
        /// expression, found by taking this AST node index offset from the containing
        /// base node, which points to an array access AST node. Next, navigate
        /// to the index expression.
        node_offset_array_access_index: Ast.Node.Offset,
        /// The source location points to the LHS of a slice expression
        /// expression, found by taking this AST node index offset from the containing
        /// base node, which points to a slice AST node. Next, navigate
        /// to the sentinel expression.
        node_offset_slice_ptr: Ast.Node.Offset,
        /// The source location points to start expression of a slice expression
        /// expression, found by taking this AST node index offset from the containing
        /// base node, which points to a slice AST node. Next, navigate
        /// to the sentinel expression.
        node_offset_slice_start: Ast.Node.Offset,
        /// The source location points to the end expression of a slice
        /// expression, found by taking this AST node index offset from the containing
        /// base node, which points to a slice AST node. Next, navigate
        /// to the sentinel expression.
        node_offset_slice_end: Ast.Node.Offset,
        /// The source location points to the sentinel expression of a slice
        /// expression, found by taking this AST node index offset from the containing
        /// base node, which points to a slice AST node. Next, navigate
        /// to the sentinel expression.
        node_offset_slice_sentinel: Ast.Node.Offset,
        /// The source location points to the callee expression of a function
        /// call expression, found by taking this AST node index offset from the containing
        /// base node, which points to a function call AST node. Next, navigate
        /// to the callee expression.
        node_offset_call_func: Ast.Node.Offset,
        /// The payload is offset from the containing base node.
        /// The source location points to the field name of:
        ///  * a field access expression (`a.b`), or
        ///  * the callee of a method call (`a.b()`)
        node_offset_field_name: Ast.Node.Offset,
        /// The payload is offset from the containing base node.
        /// The source location points to the field name of the operand ("b" node)
        /// of a field initialization expression (`.a = b`)
        node_offset_field_name_init: Ast.Node.Offset,
        /// The source location points to the pointer of a pointer deref expression,
        /// found by taking this AST node index offset from the containing
        /// base node, which points to a pointer deref AST node. Next, navigate
        /// to the pointer expression.
        node_offset_deref_ptr: Ast.Node.Offset,
        /// The source location points to the assembly source code of an inline assembly
        /// expression, found by taking this AST node index offset from the containing
        /// base node, which points to inline assembly AST node. Next, navigate
        /// to the asm template source code.
        node_offset_asm_source: Ast.Node.Offset,
        /// The source location points to the return type of an inline assembly
        /// expression, found by taking this AST node index offset from the containing
        /// base node, which points to inline assembly AST node. Next, navigate
        /// to the return type expression.
        node_offset_asm_ret_ty: Ast.Node.Offset,
        /// The source location points to the condition expression of an if
        /// expression, found by taking this AST node index offset from the containing
        /// base node, which points to an if expression AST node. Next, navigate
        /// to the condition expression.
        node_offset_if_cond: Ast.Node.Offset,
        /// The source location points to a binary expression, such as `a + b`, found
        /// by taking this AST node index offset from the containing base node.
        node_offset_bin_op: Ast.Node.Offset,
        /// The source location points to the LHS of a binary expression, found
        /// by taking this AST node index offset from the containing base node,
        /// which points to a binary expression AST node. Next, navigate to the LHS.
        node_offset_bin_lhs: Ast.Node.Offset,
        /// The source location points to the RHS of a binary expression, found
        /// by taking this AST node index offset from the containing base node,
        /// which points to a binary expression AST node. Next, navigate to the RHS.
        node_offset_bin_rhs: Ast.Node.Offset,
        /// The source location points to the operand of a try expression, found
        /// by taking this AST node index offset from the containing base node,
        /// which points to a try expression AST node. Next, navigate to the
        /// operand expression.
        node_offset_try_operand: Ast.Node.Offset,
        /// The source location points to the operand of a switch expression, found
        /// by taking this AST node index offset from the containing base node,
        /// which points to a switch expression AST node. Next, navigate to the operand.
        node_offset_switch_operand: Ast.Node.Offset,
        /// The source location points to the else/`_` prong of a switch expression, found
        /// by taking this AST node index offset from the containing base node,
        /// which points to a switch expression AST node. Next, navigate to the else/`_` prong.
        node_offset_switch_special_prong: Ast.Node.Offset,
        /// The source location points to all the ranges of a switch expression, found
        /// by taking this AST node index offset from the containing base node,
        /// which points to a switch expression AST node. Next, navigate to any of the
        /// range nodes. The error applies to all of them.
        node_offset_switch_range: Ast.Node.Offset,
        /// The source location points to the align expr of a function type
        /// expression, found by taking this AST node index offset from the containing
        /// base node, which points to a function type AST node. Next, navigate to
        /// the calling convention node.
        node_offset_fn_type_align: Ast.Node.Offset,
        /// The source location points to the addrspace expr of a function type
        /// expression, found by taking this AST node index offset from the containing
        /// base node, which points to a function type AST node. Next, navigate to
        /// the calling convention node.
        node_offset_fn_type_addrspace: Ast.Node.Offset,
        /// The source location points to the linksection expr of a function type
        /// expression, found by taking this AST node index offset from the containing
        /// base node, which points to a function type AST node. Next, navigate to
        /// the calling convention node.
        node_offset_fn_type_section: Ast.Node.Offset,
        /// The source location points to the calling convention of a function type
        /// expression, found by taking this AST node index offset from the containing
        /// base node, which points to a function type AST node. Next, navigate to
        /// the calling convention node.
        node_offset_fn_type_cc: Ast.Node.Offset,
        /// The source location points to the return type of a function type
        /// expression, found by taking this AST node index offset from the containing
        /// base node, which points to a function type AST node. Next, navigate to
        /// the return type node.
        node_offset_fn_type_ret_ty: Ast.Node.Offset,
        node_offset_param: Ast.Node.Offset,
        token_offset_param: Ast.TokenOffset,
        /// The source location points to the type expression of an `anyframe->T`
        /// expression, found by taking this AST node index offset from the containing
        /// base node, which points to a `anyframe->T` expression AST node. Next, navigate
        /// to the type expression.
        node_offset_anyframe_type: Ast.Node.Offset,
        /// The source location points to the string literal of `extern "foo"`, found
        /// by taking this AST node index offset from the containing
        /// base node, which points to a function prototype or variable declaration
        /// expression AST node. Next, navigate to the string literal of the `extern "foo"`.
        node_offset_lib_name: Ast.Node.Offset,
        /// The source location points to the len expression of an `[N:S]T`
        /// expression, found by taking this AST node index offset from the containing
        /// base node, which points to an `[N:S]T` expression AST node. Next, navigate
        /// to the len expression.
        node_offset_array_type_len: Ast.Node.Offset,
        /// The source location points to the sentinel expression of an `[N:S]T`
        /// expression, found by taking this AST node index offset from the containing
        /// base node, which points to an `[N:S]T` expression AST node. Next, navigate
        /// to the sentinel expression.
        node_offset_array_type_sentinel: Ast.Node.Offset,
        /// The source location points to the elem expression of an `[N:S]T`
        /// expression, found by taking this AST node index offset from the containing
        /// base node, which points to an `[N:S]T` expression AST node. Next, navigate
        /// to the elem expression.
        node_offset_array_type_elem: Ast.Node.Offset,
        /// The source location points to the operand of an unary expression.
        node_offset_un_op: Ast.Node.Offset,
        /// The source location points to the elem type of a pointer.
        node_offset_ptr_elem: Ast.Node.Offset,
        /// The source location points to the sentinel of a pointer.
        node_offset_ptr_sentinel: Ast.Node.Offset,
        /// The source location points to the align expr of a pointer.
        node_offset_ptr_align: Ast.Node.Offset,
        /// The source location points to the addrspace expr of a pointer.
        node_offset_ptr_addrspace: Ast.Node.Offset,
        /// The source location points to the bit-offset of a pointer.
        node_offset_ptr_bitoffset: Ast.Node.Offset,
        /// The source location points to the host size of a pointer.
        node_offset_ptr_hostsize: Ast.Node.Offset,
        /// The source location points to the tag type of an union or an enum.
        node_offset_container_tag: Ast.Node.Offset,
        /// The source location points to the default value of a field.
        node_offset_field_default: Ast.Node.Offset,
        /// The source location points to the type of an array or struct initializer.
        node_offset_init_ty: Ast.Node.Offset,
        /// The source location points to the LHS of an assignment (or assign-op, e.g. `+=`).
        node_offset_store_ptr: Ast.Node.Offset,
        /// The source location points to the RHS of an assignment (or assign-op, e.g. `+=`).
        node_offset_store_operand: Ast.Node.Offset,
        /// The source location points to the operand of a `return` statement, or
        /// the `return` itself if there is no explicit operand.
        node_offset_return_operand: Ast.Node.Offset,
        /// The source location points to a for loop input.
        for_input: struct {
            /// Points to the for loop AST node.
            for_node_offset: Ast.Node.Offset,
            /// Picks one of the inputs from the condition.
            input_index: u32,
        },
        /// The source location points to one of the captures of a for loop, found
        /// by taking this AST node index offset from the containing
        /// base node, which points to one of the input nodes of a for loop.
        /// Next, navigate to the corresponding capture.
        for_capture_from_input: Ast.Node.Offset,
        /// The source location points to the argument node of a function call.
        call_arg: struct {
            /// Points to the function call AST node.
            call_node_offset: Ast.Node.Offset,
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
            init_node_offset: Ast.Node.Offset,
            /// The index of the field/element the source location points to.
            elem_index: u32,
        },
        // The following source locations are like `init_elem`, but refer to a
        // field with a specific name. If such a field is not given, the entire
        // initialization expression is used instead.
        // The `Ast.Node.Offset` points to the AST node of a builtin call, whose *second*
        // argument is the init expression.
        init_field_name: Ast.Node.Offset,
        init_field_linkage: Ast.Node.Offset,
        init_field_section: Ast.Node.Offset,
        init_field_visibility: Ast.Node.Offset,
        init_field_rw: Ast.Node.Offset,
        init_field_locality: Ast.Node.Offset,
        init_field_cache: Ast.Node.Offset,
        init_field_library: Ast.Node.Offset,
        init_field_thread_local: Ast.Node.Offset,
        init_field_dll_import: Ast.Node.Offset,
        init_field_relocation: Ast.Node.Offset,
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
            fn_proto_node_offset: Ast.Node.Offset,
            /// The index of the parameter the source location points to.
            param_index: u32,
        };

        pub const SwitchItem = struct {
            /// The offset of the switch AST node.
            switch_node_offset: Ast.Node.Offset,
            /// The index of the case to point to within this switch.
            case_idx: SwitchCaseIndex,
            /// The index of the item to point to within this case.
            item_idx: SwitchItemIndex,
        };

        pub const SwitchCapture = struct {
            /// The offset of the switch AST node.
            switch_node_offset: Ast.Node.Offset,
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
            array_cat_offset: Ast.Node.Offset,
            /// The index of the element the source location points to.
            elem_index: u32,
        };

        pub const TupleField = struct {
            /// Points to the AST node of the tuple type decaration.
            tuple_decl_node_offset: Ast.Node.Offset,
            /// The index of the tuple field the source location points to.
            elem_index: u32,
        };

        pub const nodeOffset = if (TracedOffset.want_tracing) nodeOffsetDebug else nodeOffsetRelease;

        noinline fn nodeOffsetDebug(node_offset: Ast.Node.Offset) Offset {
            var result: LazySrcLoc = .{ .node_offset = .{ .x = node_offset } };
            result.node_offset.trace.addAddr(@returnAddress(), "init");
            return result;
        }

        fn nodeOffsetRelease(node_offset: Ast.Node.Offset) Offset {
            return .{ .node_offset = .{ .x = node_offset } };
        }

        /// This wraps a simple integer in debug builds so that later on we can find out
        /// where in semantic analysis the value got set.
        pub const TracedOffset = struct {
            x: Ast.Node.Offset,
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
        if (zir_inst == .main_struct_inst) return .{ file, .root };

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
        const file, const base_node: Ast.Node.Index = resolveBaseNode(lazy.base_node_inst, zcu) orelse return null;
        return .{
            .file_scope = file,
            .base_node = base_node,
            .lazy = lazy.offset,
        };
    }

    /// Used to sort error messages, so that they're printed in a consistent order.
    /// If an error is returned, that error makes sorting impossible.
    pub fn lessThan(lhs_lazy: LazySrcLoc, rhs_lazy: LazySrcLoc, zcu: *Zcu) !bool {
        const lhs_src = lhs_lazy.upgradeOrLost(zcu) orelse {
            // LHS source location lost, so should never be referenced. Just sort it to the end.
            return false;
        };
        const rhs_src = rhs_lazy.upgradeOrLost(zcu) orelse {
            // RHS source location lost, so should never be referenced. Just sort it to the end.
            return true;
        };
        if (lhs_src.file_scope != rhs_src.file_scope) {
            const lhs_path = lhs_src.file_scope.path;
            const rhs_path = rhs_src.file_scope.path;
            if (lhs_path.root != rhs_path.root) {
                return @intFromEnum(lhs_path.root) < @intFromEnum(rhs_path.root);
            }
            return std.mem.order(u8, lhs_path.sub_path, rhs_path.sub_path).compare(.lt);
        }

        const lhs_span = try lhs_src.span(zcu);
        const rhs_span = try rhs_src.span(zcu);
        return lhs_span.main < rhs_span.main;
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

        zcu.builtin_modules.deinit(gpa);
        zcu.module_roots.deinit(gpa);
        for (zcu.import_table.keys()) |file_index| {
            pt.destroyFile(file_index);
        }
        zcu.import_table.deinit(gpa);
        zcu.alive_files.deinit(gpa);

        for (zcu.embed_table.keys()) |embed_file| {
            embed_file.path.deinit(gpa);
            gpa.destroy(embed_file);
        }
        zcu.embed_table.deinit(gpa);

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
            if (value) |msg| gpa.free(msg);
        }
        zcu.failed_files.deinit(gpa);
        zcu.failed_imports.deinit(gpa);

        for (zcu.failed_exports.values()) |value| {
            value.destroy(gpa);
        }
        zcu.failed_exports.deinit(gpa);

        for (zcu.cimport_errors.values()) |*errs| {
            errs.deinit(gpa);
        }
        zcu.cimport_errors.deinit(gpa);

        zcu.compile_logs.deinit(gpa);
        zcu.compile_log_lines.deinit(gpa);
        zcu.free_compile_log_lines.deinit(gpa);

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

        zcu.inline_reference_frames.deinit(gpa);
        zcu.free_inline_reference_frames.deinit(gpa);

        zcu.type_reference_table.deinit(gpa);
        zcu.all_type_references.deinit(gpa);
        zcu.free_type_references.deinit(gpa);

        if (zcu.resolved_references) |*r| r.deinit(gpa);

        if (zcu.comp.debugIncremental()) {
            zcu.incremental_debug_state.deinit(gpa);
        }
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
    var buffer: [2000]u8 = undefined;
    var file_reader = cache_file.reader(&buffer);
    return result: {
        const header = file_reader.interface.takeStruct(Zir.Header) catch |err| break :result err;
        break :result loadZirCacheBody(gpa, header.*, &file_reader.interface);
    } catch |err| switch (err) {
        error.ReadFailed => return file_reader.err.?,
        else => |e| return e,
    };
}

pub fn loadZirCacheBody(gpa: Allocator, header: Zir.Header, cache_br: *std.io.Reader) !Zir {
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

    var vecs = [_][]u8{
        @ptrCast(zir.instructions.items(.tag)),
        if (data_has_safety_tag)
            @ptrCast(safety_buffer)
        else
            @ptrCast(zir.instructions.items(.data)),
        zir.string_bytes,
        @ptrCast(zir.extra),
    };
    try cache_br.readVecAll(&vecs);
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
    var vecs = [_][]const u8{
        @ptrCast((&header)[0..1]),
        @ptrCast(zir.instructions.items(.tag)),
        if (data_has_safety_tag)
            @ptrCast(safety_buffer)
        else
            @ptrCast(zir.instructions.items(.data)),
        zir.string_bytes,
        @ptrCast(zir.extra),
    };
    var cache_fw = cache_file.writer(&.{});
    cache_fw.interface.writeVecAll(&vecs) catch |err| switch (err) {
        error.WriteFailed => return cache_fw.err.?,
    };
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
    var vecs = [_][]const u8{
        @ptrCast((&header)[0..1]),
        @ptrCast(zoir.nodes.items(.tag)),
        @ptrCast(zoir.nodes.items(.data)),
        @ptrCast(zoir.nodes.items(.ast_node)),
        @ptrCast(zoir.extra),
        @ptrCast(zoir.limbs),
        zoir.string_bytes,
        @ptrCast(zoir.compile_errors),
        @ptrCast(zoir.error_notes),
    };
    var cache_fw = cache_file.writer(&.{});
    cache_fw.interface.writeVecAll(&vecs) catch |err| switch (err) {
        error.WriteFailed => return cache_fw.err.?,
    };
}

pub fn loadZoirCacheBody(gpa: Allocator, header: Zoir.Header, cache_br: *std.io.Reader) !Zoir {
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

    var vecs = [_][]u8{
        @ptrCast(zoir.nodes.items(.tag)),
        @ptrCast(zoir.nodes.items(.data)),
        @ptrCast(zoir.nodes.items(.ast_node)),
        @ptrCast(zoir.extra),
        @ptrCast(zoir.limbs),
        zoir.string_bytes,
        @ptrCast(zoir.compile_errors),
        @ptrCast(zoir.error_notes),
    };
    try cache_br.readVecAll(&vecs);
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
    log.debug("outdated dependee: {f}", .{zcu.fmtDependee(dependee)});
    var it = zcu.intern_pool.dependencyIterator(dependee);
    while (it.next()) |depender| {
        if (zcu.outdated.getPtr(depender)) |po_dep_count| {
            switch (marked_po) {
                .not_marked_po => {},
                .marked_po => {
                    po_dep_count.* -= 1;
                    log.debug("outdated {f} => already outdated {f} po_deps={}", .{ zcu.fmtDependee(dependee), zcu.fmtAnalUnit(depender), po_dep_count.* });
                    if (po_dep_count.* == 0) {
                        log.debug("outdated ready: {f}", .{zcu.fmtAnalUnit(depender)});
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
        log.debug("outdated {f} => new outdated {f} po_deps={}", .{ zcu.fmtDependee(dependee), zcu.fmtAnalUnit(depender), new_po_dep_count });
        if (new_po_dep_count == 0) {
            log.debug("outdated ready: {f}", .{zcu.fmtAnalUnit(depender)});
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
    log.debug("up-to-date dependee: {f}", .{zcu.fmtDependee(dependee)});
    var it = zcu.intern_pool.dependencyIterator(dependee);
    while (it.next()) |depender| {
        if (zcu.outdated.getPtr(depender)) |po_dep_count| {
            // This depender is already outdated, but it now has one
            // less PO dependency!
            po_dep_count.* -= 1;
            log.debug("up-to-date {f} => {f} po_deps={}", .{ zcu.fmtDependee(dependee), zcu.fmtAnalUnit(depender), po_dep_count.* });
            if (po_dep_count.* == 0) {
                log.debug("outdated ready: {f}", .{zcu.fmtAnalUnit(depender)});
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
            log.debug("up-to-date {f} => {f} po_deps={}", .{ zcu.fmtDependee(dependee), zcu.fmtAnalUnit(depender), ptr.* });
            continue;
        }

        log.debug("up-to-date {f} => {f} po_deps=0 (up-to-date)", .{ zcu.fmtDependee(dependee), zcu.fmtAnalUnit(depender) });

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
    log.debug("potentially outdated dependee: {f}", .{zcu.fmtDependee(dependee)});
    var it = ip.dependencyIterator(dependee);
    while (it.next()) |po| {
        if (zcu.outdated.getPtr(po)) |po_dep_count| {
            // This dependency is already outdated, but it now has one more PO
            // dependency.
            if (po_dep_count.* == 0) {
                _ = zcu.outdated_ready.swapRemove(po);
            }
            po_dep_count.* += 1;
            log.debug("po {f} => {f} [outdated] po_deps={}", .{ zcu.fmtDependee(dependee), zcu.fmtAnalUnit(po), po_dep_count.* });
            continue;
        }
        if (zcu.potentially_outdated.getPtr(po)) |n| {
            // There is now one more PO dependency.
            n.* += 1;
            log.debug("po {f} => {f} po_deps={}", .{ zcu.fmtDependee(dependee), zcu.fmtAnalUnit(po), n.* });
            continue;
        }
        try zcu.potentially_outdated.putNoClobber(zcu.gpa, po, 1);
        log.debug("po {f} => {f} po_deps=1", .{ zcu.fmtDependee(dependee), zcu.fmtAnalUnit(po) });
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
        log.debug("findOutdatedToAnalyze: trivial {f}", .{zcu.fmtAnalUnit(unit)});
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

    log.debug("findOutdatedToAnalyze: heuristic returned '{f}' ({d} dependers)", .{
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

        {
            var old_decl_it = old_zir.declIterator(match_item.old_inst);
            while (old_decl_it.next()) |old_decl_inst| {
                const old_decl = old_zir.getDeclaration(old_decl_inst);
                switch (old_decl.kind) {
                    .@"comptime" => try comptime_decls.append(gpa, old_decl_inst),
                    .unnamed_test => try unnamed_tests.append(gpa, old_decl_inst),
                    .@"test" => try named_tests.put(gpa, old_zir.nullTerminatedString(old_decl.name), old_decl_inst),
                    .decltest => try named_decltests.put(gpa, old_zir.nullTerminatedString(old_decl.name), old_decl_inst),
                    .@"const", .@"var" => try named_decls.put(gpa, old_zir.nullTerminatedString(old_decl.name), old_decl_inst),
                }
            }
        }

        var unnamed_test_idx: u32 = 0;
        var comptime_decl_idx: u32 = 0;

        var new_decl_it = new_zir.declIterator(match_item.new_inst);
        while (new_decl_it.next()) |new_decl_inst| {
            const new_decl = new_zir.getDeclaration(new_decl_inst);
            // Attempt to match this to a declaration in the old ZIR:
            // * For named declarations (`const`/`var`/`fn`), we match based on name.
            // * For named tests (`test "foo"`) and decltests (`test foo`), we also match based on name.
            // * For unnamed tests, we match based on order.
            // * For comptime blocks, we match based on order.
            // If we cannot match this declaration, we can't match anything nested inside of it either, so we just `continue`.
            const old_decl_inst = switch (new_decl.kind) {
                .@"comptime" => inst: {
                    if (comptime_decl_idx == comptime_decls.items.len) continue;
                    defer comptime_decl_idx += 1;
                    break :inst comptime_decls.items[comptime_decl_idx];
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

pub const ImportResult = struct {
    /// Whether `file` has been newly created; in other words, whether this is the first import of
    /// this file. This should only be `true` when importing files during AstGen. After that, all
    /// files should have already been discovered.
    is_new: bool,

    /// `file.mod` is not populated by this function, so if `is_new`, then it is `undefined`.
    file: *Zcu.File,
    file_index: File.Index,

    /// If this import was a simple file path, this is `null`; the imported file should exist within
    /// the importer's module. Otherwise, it's the module which the import resolved to. This module
    /// could match the module of `cur_file`, since a module can depend on itself.
    module: ?*Package.Module,
};

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
            const ref = zcu.all_references.items[idx];
            zcu.free_references.append(gpa, idx) catch {
                // This space will be reused eventually, so we need not propagate this error.
                // Just leak it for now, and let GC reclaim it later on.
                break :unit_refs;
            };
            idx = ref.next;

            var opt_inline_frame = ref.inline_frame;
            while (opt_inline_frame.unwrap()) |inline_frame| {
                // The same inline frame could be used multiple times by one unit. We need to
                // detect this case to avoid adding it to `free_inline_reference_frames` more
                // than once. We do that by setting `parent` to itself as a marker.
                if (inline_frame.ptr(zcu).parent == inline_frame.toOptional()) break;
                zcu.free_inline_reference_frames.append(gpa, inline_frame) catch {
                    // This space will be reused eventually, so we need not propagate this error.
                    // Just leak it for now, and let GC reclaim it later on.
                    break :unit_refs;
                };
                opt_inline_frame = inline_frame.ptr(zcu).parent;
                inline_frame.ptr(zcu).parent = inline_frame.toOptional(); // signal to code above
            }
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

/// Delete all compile logs performed by this `AnalUnit`.
/// Re-analysis of the `AnalUnit` will cause logs to be rediscovered.
pub fn deleteUnitCompileLogs(zcu: *Zcu, anal_unit: AnalUnit) void {
    const kv = zcu.compile_logs.fetchSwapRemove(anal_unit) orelse return;
    const gpa = zcu.gpa;
    var opt_line_idx = kv.value.first_line.toOptional();
    while (opt_line_idx.unwrap()) |line_idx| {
        zcu.free_compile_log_lines.append(gpa, line_idx) catch {
            // This space will be reused eventually, so we need not propagate this error.
            // Just leak it for now, and let GC reclaim it later on.
            return;
        };
        opt_line_idx = line_idx.get(zcu).next;
    }
}

pub fn addInlineReferenceFrame(zcu: *Zcu, frame: InlineReferenceFrame) Allocator.Error!Zcu.InlineReferenceFrame.Index {
    const frame_idx: InlineReferenceFrame.Index = zcu.free_inline_reference_frames.pop() orelse idx: {
        _ = try zcu.inline_reference_frames.addOne(zcu.gpa);
        break :idx @enumFromInt(zcu.inline_reference_frames.items.len - 1);
    };
    frame_idx.ptr(zcu).* = frame;
    return frame_idx;
}

pub fn addUnitReference(
    zcu: *Zcu,
    src_unit: AnalUnit,
    referenced_unit: AnalUnit,
    ref_src: LazySrcLoc,
    inline_frame: InlineReferenceFrame.Index.Optional,
) Allocator.Error!void {
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
        .inline_frame = inline_frame,
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
    const target = zcu.getTarget();

    if (zcu.error_limit == 0) return 0;
    if (target.cpu.arch.isSpirV()) {
        if (!target.cpu.has(.spirv, .storage_push_constant16)) {
            return 32;
        }
    }

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
pub fn getTarget(zcu: *const Zcu) *const Target {
    return &zcu.root_mod.resolved_target.result;
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
    /// In theory, backends are supposed to work like this:
    ///
    /// * The AIR emitted by `Sema` is converted into MIR by `codegen.generateFunction`. This pass
    ///   is "pure", in that it does not depend on or modify any external mutable state.
    ///
    /// * That MIR is sent to the linker, which calls `codegen.emitFunction` to convert the MIR to
    ///   finalized machine code. This process is permitted to query and modify linker state.
    ///
    /// * The linker stores the resulting machine code in the binary as needed.
    ///
    /// The first stage described above can run in parallel to the rest of the compiler, and even to
    /// other code generation work; we can run as many codegen threads as we want in parallel because
    /// of the fact that this pass is pure. Emit and link must be single-threaded, but are generally
    /// very fast, so that isn't a problem.
    ///
    /// Unfortunately, some code generation implementations currently query and/or mutate linker state
    /// or even (in the case of the LLVM backend) semantic analysis state. Such backends cannot be run
    /// in parallel with each other, with linking, or (potentially) with semantic analysis.
    ///
    /// Additionally, some backends continue to need the AIR in the "emit" stage, despite this pass
    /// operating on MIR. This complicates memory management under the threading model above.
    ///
    /// These are both **bugs** in backend implementations, left over from legacy code. However, they
    /// are difficult to fix. So, this `Feature` currently guards correct threading of code generation:
    ///
    /// * With this feature enabled, the backend is threaded as described above. The "emit" stage does
    ///   not have access to AIR (it will be `undefined`; see `codegen.emitFunction`).
    ///
    /// * With this feature disabled, semantic analysis, code generation, and linking all occur on the
    ///   same thread, and the "emit" stage has access to AIR.
    separate_thread,
};

pub fn backendSupportsFeature(zcu: *const Zcu, comptime feature: Feature) bool {
    const backend = target_util.zigBackend(&zcu.root_mod.resolved_target.result, zcu.comp.config.use_llvm);
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
        => 16,

        .arc,
        .arm,
        .armeb,
        .hexagon,
        .m68k,
        .mips,
        .mipsel,
        .nvptx,
        .or1k,
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
        .propeller,
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
        .spirv64,
        .loongarch64,
        => 64,

        .aarch64,
        .aarch64_be,
        => 128,

        .x86_64 => if (target.cpu.has(.x86, .cx16)) 128 else 64,
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
    /// If `inline_frame` is not `.none`, this is the *deepest* source location in the chain of
    /// inline calls. For source locations further up the inline call stack, consult `inline_frame`.
    src: LazySrcLoc,
    inline_frame: InlineReferenceFrame.Index.Optional,
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
        const file = zcu.module_roots.get(mod).?.unwrap() orelse continue;
        const root_ty = zcu.fileRootType(file);
        if (root_ty == .none) continue;
        type_queue.putAssumeCapacityNoClobber(root_ty, null);
    }

    while (true) {
        if (type_queue.pop()) |kv| {
            const ty = kv.key;
            const referencer = kv.value;
            try checked_types.putNoClobber(gpa, ty, {});

            log.debug("handle type '{f}'", .{Type.fromInterned(ty).containerTypeName(ip).fmt(ip)});

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
                    log.debug("type '{f}': ref comptime %{}", .{
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
                    .@"const", .@"var" => unreachable,
                    .@"comptime" => unreachable,
                    .unnamed_test => true,
                    .@"test", .decltest => a: {
                        const fqn_slice = nav.fqn.toSlice(ip);
                        if (comp.test_filters.len > 0) {
                            for (comp.test_filters) |test_filter| {
                                if (std.mem.indexOf(u8, fqn_slice, test_filter) != null) break;
                            } else break :a false;
                        }
                        break :a true;
                    },
                };
                if (want_analysis) {
                    log.debug("type '{f}': ref test %{}", .{
                        Type.fromInterned(ty).containerTypeName(ip).fmt(ip),
                        @intFromEnum(inst_info.inst),
                    });
                    try unit_queue.put(gpa, .wrap(.{ .nav_val = nav_id }), referencer);
                    // Non-fatal AstGen errors could mean this test decl failed
                    if (nav.status == .fully_resolved) {
                        try unit_queue.put(gpa, .wrap(.{ .func = nav.status.fully_resolved.val }), referencer);
                    }
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
                        log.debug("type '{f}': ref named %{}", .{
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
                        log.debug("type '{f}': ref named %{}", .{
                            Type.fromInterned(ty).containerTypeName(ip).fmt(ip),
                            @intFromEnum(inst_info.inst),
                        });
                        try unit_queue.put(gpa, unit, referencer);
                    }
                }
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

            log.debug("handle unit '{f}'", .{zcu.fmtAnalUnit(unit)});

            if (zcu.reference_table.get(unit)) |first_ref_idx| {
                assert(first_ref_idx != std.math.maxInt(u32));
                var ref_idx = first_ref_idx;
                while (ref_idx != std.math.maxInt(u32)) {
                    const ref = zcu.all_references.items[ref_idx];
                    if (!result.contains(ref.referenced)) {
                        log.debug("unit '{f}': ref unit '{f}'", .{
                            zcu.fmtAnalUnit(unit),
                            zcu.fmtAnalUnit(ref.referenced),
                        });
                        try unit_queue.put(gpa, ref.referenced, .{
                            .referencer = unit,
                            .src = ref.src,
                            .inline_frame = ref.inline_frame,
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
                        log.debug("unit '{f}': ref type '{f}'", .{
                            zcu.fmtAnalUnit(unit),
                            Type.fromInterned(ref.referenced).containerTypeName(ip).fmt(ip),
                        });
                        try type_queue.put(gpa, ref.referenced, .{
                            .referencer = unit,
                            .src = ref.src,
                            .inline_frame = .none,
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

pub fn navSrcLoc(zcu: *const Zcu, nav_index: InternPool.Nav.Index) LazySrcLoc {
    const ip = &zcu.intern_pool;
    return .{
        .base_node_inst = ip.getNav(nav_index).srcInst(ip),
        .offset = LazySrcLoc.Offset.nodeOffset(.zero),
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

pub fn fmtAnalUnit(zcu: *Zcu, unit: AnalUnit) std.fmt.Formatter(FormatAnalUnit, formatAnalUnit) {
    return .{ .data = .{ .unit = unit, .zcu = zcu } };
}
pub fn fmtDependee(zcu: *Zcu, d: InternPool.Dependee) std.fmt.Formatter(FormatDependee, formatDependee) {
    return .{ .data = .{ .dependee = d, .zcu = zcu } };
}

const FormatAnalUnit = struct {
    unit: AnalUnit,
    zcu: *Zcu,
};

fn formatAnalUnit(data: FormatAnalUnit, writer: *std.io.Writer) std.io.Writer.Error!void {
    const zcu = data.zcu;
    const ip = &zcu.intern_pool;
    switch (data.unit.unwrap()) {
        .@"comptime" => |cu_id| {
            const cu = ip.getComptimeUnit(cu_id);
            if (cu.zir_index.resolveFull(ip)) |resolved| {
                const file_path = zcu.fileByIndex(resolved.file).path;
                return writer.print("comptime(inst=('{f}', %{}) [{}])", .{ file_path.fmt(zcu.comp), @intFromEnum(resolved.inst), @intFromEnum(cu_id) });
            } else {
                return writer.print("comptime(inst=<lost> [{}])", .{@intFromEnum(cu_id)});
            }
        },
        .nav_val => |nav| return writer.print("nav_val('{f}' [{}])", .{ ip.getNav(nav).fqn.fmt(ip), @intFromEnum(nav) }),
        .nav_ty => |nav| return writer.print("nav_ty('{f}' [{}])", .{ ip.getNav(nav).fqn.fmt(ip), @intFromEnum(nav) }),
        .type => |ty| return writer.print("ty('{f}' [{}])", .{ Type.fromInterned(ty).containerTypeName(ip).fmt(ip), @intFromEnum(ty) }),
        .func => |func| {
            const nav = zcu.funcInfo(func).owner_nav;
            return writer.print("func('{f}' [{}])", .{ ip.getNav(nav).fqn.fmt(ip), @intFromEnum(func) });
        },
        .memoized_state => return writer.writeAll("memoized_state"),
    }
}

const FormatDependee = struct { dependee: InternPool.Dependee, zcu: *Zcu };

fn formatDependee(data: FormatDependee, writer: *std.io.Writer) std.io.Writer.Error!void {
    const zcu = data.zcu;
    const ip = &zcu.intern_pool;
    switch (data.dependee) {
        .src_hash => |ti| {
            const info = ti.resolveFull(ip) orelse {
                return writer.writeAll("inst(<lost>)");
            };
            const file_path = zcu.fileByIndex(info.file).path;
            return writer.print("inst('{f}', %{d})", .{ file_path.fmt(zcu.comp), @intFromEnum(info.inst) });
        },
        .nav_val => |nav| {
            const fqn = ip.getNav(nav).fqn;
            return writer.print("nav_val('{f}')", .{fqn.fmt(ip)});
        },
        .nav_ty => |nav| {
            const fqn = ip.getNav(nav).fqn;
            return writer.print("nav_ty('{f}')", .{fqn.fmt(ip)});
        },
        .interned => |ip_index| switch (ip.indexToKey(ip_index)) {
            .struct_type, .union_type, .enum_type => return writer.print("type('{f}')", .{Type.fromInterned(ip_index).containerTypeName(ip).fmt(ip)}),
            .func => |f| return writer.print("ies('{f}')", .{ip.getNav(f.owner_nav).fqn.fmt(ip)}),
            else => unreachable,
        },
        .zon_file => |file| {
            const file_path = zcu.fileByIndex(file).path;
            return writer.print("zon_file('{f}')", .{file_path.fmt(zcu.comp)});
        },
        .embed_file => |ef_idx| {
            const ef = ef_idx.get(zcu);
            return writer.print("embed_file('{f}')", .{ef.path.fmt(zcu.comp)});
        },
        .namespace => |ti| {
            const info = ti.resolveFull(ip) orelse {
                return writer.writeAll("namespace(<lost>)");
            };
            const file_path = zcu.fileByIndex(info.file).path;
            return writer.print("namespace('{f}', %{d})", .{ file_path.fmt(zcu.comp), @intFromEnum(info.inst) });
        },
        .namespace_name => |k| {
            const info = k.namespace.resolveFull(ip) orelse {
                return writer.print("namespace(<lost>, '{f}')", .{k.name.fmt(ip)});
            };
            const file_path = zcu.fileByIndex(info.file).path;
            return writer.print("namespace('{f}', %{d}, '{f}')", .{ file_path.fmt(zcu.comp), @intFromEnum(info.inst), k.name.fmt(ip) });
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
        .async => return .{ .bad_backend = backend }, // nothing supports async currently
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
                => |opts| opts.incoming_stack_alignment == null,

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
            .wasm_mvp => |opts| opts.incoming_stack_alignment == null,
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
        .stage2_powerpc => switch (target.cpu.arch) {
            .powerpc, .powerpcle => switch (cc) {
                .powerpc_sysv,
                .powerpc_sysv_altivec,
                .powerpc_aix,
                .powerpc_aix_altivec,
                .naked,
                => true,
                else => false,
            },
            .powerpc64, .powerpc64le => switch (cc) {
                .powerpc64_elf,
                .powerpc64_elf_altivec,
                .powerpc64_elf_v2,
                .naked,
                => true,
                else => false,
            },
            else => unreachable,
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
        .stage2_spirv => switch (cc) {
            .spirv_device, .spirv_kernel => true,
            .spirv_fragment, .spirv_vertex => target.os.tag == .vulkan,
            else => false,
        },
        .stage2_loongarch => switch (cc) {
            .loongarch64_lp64 => true,
            else => false,
        },
    };
    if (!backend_ok) return .{ .bad_backend = backend };
    return .ok;
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
    const msg = try Zcu.ErrorMsg.create(zcu.gpa, zcu.navSrcLoc(nav_index), format, args);
    return zcu.codegenFailMsg(nav_index, msg);
}

/// Takes ownership of `msg`, even on OOM.
pub fn codegenFailMsg(zcu: *Zcu, nav_index: InternPool.Nav.Index, msg: *ErrorMsg) CodegenFailError {
    const gpa = zcu.gpa;
    {
        zcu.comp.mutex.lock();
        defer zcu.comp.mutex.unlock();
        errdefer msg.deinit(gpa);
        try zcu.failed_codegen.putNoClobber(gpa, nav_index, msg);
    }
    return error.CodegenFail;
}

/// Asserts that `zcu.failed_codegen` contains the key `nav`, with the necessary lock held.
pub fn assertCodegenFailed(zcu: *Zcu, nav: InternPool.Nav.Index) void {
    zcu.comp.mutex.lock();
    defer zcu.comp.mutex.unlock();
    assert(zcu.failed_codegen.contains(nav));
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

/// Asserts that `zcu.multi_module_err != null`.
pub fn addFileInMultipleModulesError(
    zcu: *Zcu,
    eb: *std.zig.ErrorBundle.Wip,
) !void {
    const gpa = zcu.gpa;

    const info = zcu.multi_module_err.?;
    const file = info.file;

    // error: file exists in modules 'root.foo' and 'root.bar'
    // note: files must belong to only one module
    // note: file is imported here
    // note: which is imported here
    // note: which is the root of module 'root.foo' imported here
    // note: file is the root of module 'root.bar' imported here

    const file_src = try zcu.fileByIndex(file).errorBundleWholeFileSrc(zcu, eb);
    const root_msg = try eb.printString("file exists in modules '{s}' and '{s}'", .{
        info.modules[0].fully_qualified_name,
        info.modules[1].fully_qualified_name,
    });

    var notes: std.ArrayListUnmanaged(std.zig.ErrorBundle.MessageIndex) = .empty;
    defer notes.deinit(gpa);

    try notes.append(gpa, try eb.addErrorMessage(.{
        .msg = try eb.addString("files must belong to only one module"),
        .src_loc = file_src,
    }));

    try zcu.explainWhyFileIsInModule(eb, &notes, file, info.modules[0], info.refs[0]);
    try zcu.explainWhyFileIsInModule(eb, &notes, file, info.modules[1], info.refs[1]);

    try eb.addRootErrorMessage(.{
        .msg = root_msg,
        .src_loc = file_src,
        .notes_len = @intCast(notes.items.len),
    });
    const notes_start = try eb.reserveNotes(@intCast(notes.items.len));
    const notes_slice: []std.zig.ErrorBundle.MessageIndex = @ptrCast(eb.extra.items[notes_start..]);
    @memcpy(notes_slice, notes.items);
}

fn explainWhyFileIsInModule(
    zcu: *Zcu,
    eb: *std.zig.ErrorBundle.Wip,
    notes_out: *std.ArrayListUnmanaged(std.zig.ErrorBundle.MessageIndex),
    file: File.Index,
    in_module: *Package.Module,
    ref: File.Reference,
) !void {
    const gpa = zcu.gpa;

    // error: file is the root of module 'foo'
    //
    // error: file is imported here by the root of module 'foo'
    //
    // error: file is imported here
    // note: which is imported here
    // note: which is imported here by the root of module 'foo'

    var import = switch (ref) {
        .analysis_root => |mod| {
            assert(mod == in_module);
            try notes_out.append(gpa, try eb.addErrorMessage(.{
                .msg = try eb.printString("file is the root of module '{s}'", .{mod.fully_qualified_name}),
                .src_loc = try zcu.fileByIndex(file).errorBundleWholeFileSrc(zcu, eb),
            }));
            return;
        },
        .import => |import| if (import.module) |mod| {
            assert(mod == in_module);
            try notes_out.append(gpa, try eb.addErrorMessage(.{
                .msg = try eb.printString("file is the root of module '{s}'", .{mod.fully_qualified_name}),
                .src_loc = try zcu.fileByIndex(file).errorBundleWholeFileSrc(zcu, eb),
            }));
            return;
        } else import,
    };

    var is_first = true;
    while (true) {
        const thing: []const u8 = if (is_first) "file" else "which";
        is_first = false;

        const import_src = try zcu.fileByIndex(import.importer).errorBundleTokenSrc(import.tok, zcu, eb);

        const importer_ref = zcu.alive_files.get(import.importer).?;
        const importer_root: ?*Package.Module = switch (importer_ref) {
            .analysis_root => |mod| mod,
            .import => |i| i.module,
        };

        if (importer_root) |m| {
            try notes_out.append(gpa, try eb.addErrorMessage(.{
                .msg = try eb.printString("{s} is imported here by the root of module '{s}'", .{ thing, m.fully_qualified_name }),
                .src_loc = import_src,
            }));
            return;
        }

        try notes_out.append(gpa, try eb.addErrorMessage(.{
            .msg = try eb.printString("{s} is imported here", .{thing}),
            .src_loc = import_src,
        }));

        import = importer_ref.import;
    }
}

const SemaProgNode = struct {
    /// `null` means we created the node, so should end it.
    old_name: ?[std.Progress.Node.max_name_len]u8,
    pub fn end(spn: SemaProgNode, zcu: *Zcu) void {
        if (spn.old_name) |old_name| {
            zcu.sema_prog_node.completeOne(); // we're just renaming, but it's effectively completion
            zcu.cur_sema_prog_node.setName(&old_name);
        } else {
            zcu.cur_sema_prog_node.end();
            zcu.cur_sema_prog_node = .none;
        }
    }
};
pub fn startSemaProgNode(zcu: *Zcu, name: []const u8) SemaProgNode {
    if (zcu.cur_sema_prog_node.index != .none) {
        const old_name = zcu.cur_sema_prog_node.getName();
        zcu.cur_sema_prog_node.setName(name);
        return .{ .old_name = old_name };
    } else {
        zcu.cur_sema_prog_node = zcu.sema_prog_node.start(name, 0);
        return .{ .old_name = null };
    }
}
