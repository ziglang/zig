//! Compilation of all Zig source code is represented by one `Module`.
//! Each `Compilation` has exactly one or zero `Module`, depending on whether
//! there is or is not any zig source code, respectively.

const std = @import("std");
const builtin = @import("builtin");
const mem = std.mem;
const Allocator = std.mem.Allocator;
const ArrayListUnmanaged = std.ArrayListUnmanaged;
const assert = std.debug.assert;
const log = std.log.scoped(.module);
const BigIntConst = std.math.big.int.Const;
const BigIntMutable = std.math.big.int.Mutable;
const Target = std.Target;
const Ast = std.zig.Ast;
const LazySrcLoc = std.zig.LazySrcLoc;

/// Deprecated, use `Zcu`.
const Module = Zcu;
const Zcu = @This();
const Compilation = @import("Compilation.zig");
const Cache = std.Build.Cache;
const Value = @import("Value.zig");
const Type = @import("type.zig").Type;
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
const BuiltinFn = std.zig.BuiltinFn;
const LlvmObject = @import("codegen/llvm.zig").Object;

comptime {
    @setEvalBranchQuota(4000);
    for (
        @typeInfo(Zir.Inst.Ref).Enum.fields,
        @typeInfo(Air.Inst.Ref).Enum.fields,
        @typeInfo(InternPool.Index).Enum.fields,
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
llvm_object: ?*LlvmObject,

/// Pointer to externally managed resource.
root_mod: *Package.Module,
/// Normally, `main_mod` and `root_mod` are the same. The exception is `zig test`, in which
/// `root_mod` is the test runner, and `main_mod` is the user's source file which has the tests.
main_mod: *Package.Module,
std_mod: *Package.Module,
sema_prog_node: std.Progress.Node = undefined,

/// Used by AstGen worker to load and store ZIR cache.
global_zir_cache: Compilation.Directory,
/// Used by AstGen worker to load and store ZIR cache.
local_zir_cache: Compilation.Directory,
/// It's rare for a decl to be exported, so we save memory by having a sparse
/// map of Decl indexes to details about them being exported.
/// The Export memory is owned by the `export_owners` table; the slice itself
/// is owned by this table. The slice is guaranteed to not be empty.
decl_exports: std.AutoArrayHashMapUnmanaged(Decl.Index, ArrayListUnmanaged(*Export)) = .{},
/// Same as `decl_exports` but for exported constant values.
value_exports: std.AutoArrayHashMapUnmanaged(InternPool.Index, ArrayListUnmanaged(*Export)) = .{},
/// This models the Decls that perform exports, so that `decl_exports` can be updated when a Decl
/// is modified. Note that the key of this table is not the Decl being exported, but the Decl that
/// is performing the export of another Decl.
/// This table owns the Export memory.
export_owners: std.AutoArrayHashMapUnmanaged(Decl.Index, ArrayListUnmanaged(*Export)) = .{},
/// The set of all the Zig source files in the Module. We keep track of this in order
/// to iterate over it and check which source files have been modified on the file system when
/// an update is requested, as well as to cache `@import` results.
/// Keys are fully resolved file paths. This table owns the keys and values.
import_table: std.StringArrayHashMapUnmanaged(*File) = .{},
/// The set of all the files which have been loaded with `@embedFile` in the Module.
/// We keep track of this in order to iterate over it and check which files have been
/// modified on the file system when an update is requested, as well as to cache
/// `@embedFile` results.
/// Keys are fully resolved file paths. This table owns the keys and values.
embed_table: std.StringArrayHashMapUnmanaged(*EmbedFile) = .{},

/// Stores all Type and Value objects.
/// The idea is that this will be periodically garbage-collected, but such logic
/// is not yet implemented.
intern_pool: InternPool = .{},

/// We optimize memory usage for a compilation with no compile errors by storing the
/// error messages and mapping outside of `Decl`.
/// The ErrorMsg memory is owned by the decl, using Module's general purpose allocator.
/// Note that a Decl can succeed but the Fn it represents can fail. In this case,
/// a Decl can have a failed_decls entry but have analysis status of success.
failed_decls: std.AutoArrayHashMapUnmanaged(Decl.Index, *ErrorMsg) = .{},
/// Keep track of one `@compileLog` callsite per owner Decl.
/// The value is the AST node index offset from the Decl.
compile_log_decls: std.AutoArrayHashMapUnmanaged(Decl.Index, i32) = .{},
/// Using a map here for consistency with the other fields here.
/// The ErrorMsg memory is owned by the `File`, using Module's general purpose allocator.
failed_files: std.AutoArrayHashMapUnmanaged(*File, ?*ErrorMsg) = .{},
/// The ErrorMsg memory is owned by the `EmbedFile`, using Module's general purpose allocator.
failed_embed_files: std.AutoArrayHashMapUnmanaged(*EmbedFile, *ErrorMsg) = .{},
/// Using a map here for consistency with the other fields here.
/// The ErrorMsg memory is owned by the `Export`, using Module's general purpose allocator.
failed_exports: std.AutoArrayHashMapUnmanaged(*Export, *ErrorMsg) = .{},
/// If a decl failed due to a cimport error, the corresponding Clang errors
/// are stored here.
cimport_errors: std.AutoArrayHashMapUnmanaged(Decl.Index, std.zig.ErrorBundle) = .{},

/// Key is the error name, index is the error tag value. Index 0 has a length-0 string.
global_error_set: GlobalErrorSet = .{},

/// Maximum amount of distinct error values, set by --error-limit
error_limit: ErrorInt,

/// Value is the number of PO or outdated Decls which this Depender depends on.
potentially_outdated: std.AutoArrayHashMapUnmanaged(InternPool.Depender, u32) = .{},
/// Value is the number of PO or outdated Decls which this Depender depends on.
/// Once this value drops to 0, the Depender is a candidate for re-analysis.
outdated: std.AutoArrayHashMapUnmanaged(InternPool.Depender, u32) = .{},
/// This contains all `Depender`s in `outdated` whose PO dependency count is 0.
/// Such `Depender`s are ready for immediate re-analysis.
/// See `findOutdatedToAnalyze` for details.
outdated_ready: std.AutoArrayHashMapUnmanaged(InternPool.Depender, void) = .{},
/// This contains a set of Decls which may not be in `outdated`, but are the
/// root Decls of files which have updated source and thus must be re-analyzed.
/// If such a Decl is only in this set, the struct type index may be preserved
/// (only the namespace might change). If such a Decl is also `outdated`, the
/// struct type index must be recreated.
outdated_file_root: std.AutoArrayHashMapUnmanaged(Decl.Index, void) = .{},
/// This contains a list of Dependers whose analysis or codegen failed, but the
/// failure was something like running out of disk space, and trying again may
/// succeed. On the next update, we will flush this list, marking all members of
/// it as outdated.
retryable_failures: std.ArrayListUnmanaged(InternPool.Depender) = .{},

stage1_flags: packed struct {
    have_winmain: bool = false,
    have_wwinmain: bool = false,
    have_winmain_crt_startup: bool = false,
    have_wwinmain_crt_startup: bool = false,
    have_dllmain_crt_startup: bool = false,
    have_c_main: bool = false,
    reserved: u2 = 0,
} = .{},

compile_log_text: ArrayListUnmanaged(u8) = .{},

emit_h: ?*GlobalEmitH,

test_functions: std.AutoArrayHashMapUnmanaged(Decl.Index, void) = .{},

global_assembly: std.AutoArrayHashMapUnmanaged(Decl.Index, []u8) = .{},

reference_table: std.AutoHashMapUnmanaged(Decl.Index, struct {
    referencer: Decl.Index,
    src: LazySrcLoc,
}) = .{},

panic_messages: [PanicId.len]Decl.OptionalIndex = .{.none} ** PanicId.len,
/// The panic function body.
panic_func_index: InternPool.Index = .none,
null_stack_trace: InternPool.Index = .none,

pub const PanicId = enum {
    unreach,
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
    inactive_union_field,
    integer_part_out_of_bounds,
    corrupt_switch,
    shift_rhs_too_big,
    invalid_enum_value,
    sentinel_mismatch,
    unwrap_error,
    index_out_of_bounds,
    start_index_greater_than_end,
    for_len_mismatch,
    memcpy_len_mismatch,
    memcpy_alias,
    noreturn_returned,

    pub const len = @typeInfo(PanicId).Enum.fields.len;
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

/// A `Module` has zero or one of these depending on whether `-femit-h` is enabled.
pub const GlobalEmitH = struct {
    /// Where to put the output.
    loc: Compilation.EmitLoc,
    /// When emit_h is non-null, each Decl gets one more compile error slot for
    /// emit-h failing for that Decl. This table is also how we tell if a Decl has
    /// failed emit-h or succeeded.
    failed_decls: std.AutoArrayHashMapUnmanaged(Decl.Index, *ErrorMsg) = .{},
    /// Tracks all decls in order to iterate over them and emit .h code for them.
    decl_table: std.AutoArrayHashMapUnmanaged(Decl.Index, void) = .{},
    /// Similar to the allocated_decls field of Module, this is where `EmitH` objects
    /// are allocated. There will be exactly one EmitH object per Decl object, with
    /// identical indexes.
    allocated_emit_h: std.SegmentedList(EmitH, 0) = .{},

    pub fn declPtr(global_emit_h: *GlobalEmitH, decl_index: Decl.Index) *EmitH {
        return global_emit_h.allocated_emit_h.at(@intFromEnum(decl_index));
    }
};

pub const ErrorInt = u32;

pub const Exported = union(enum) {
    /// The Decl being exported. Note this is *not* the Decl performing the export.
    decl_index: Decl.Index,
    /// Constant value being exported.
    value: InternPool.Index,
};

pub const Export = struct {
    opts: Options,
    src: LazySrcLoc,
    /// The Decl that performs the export. Note that this is *not* the Decl being exported.
    owner_decl: Decl.Index,
    /// The Decl containing the export statement.  Inline function calls
    /// may cause this to be different from the owner_decl.
    src_decl: Decl.Index,
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

    pub fn getSrcLoc(exp: Export, mod: *Module) SrcLoc {
        const src_decl = mod.declPtr(exp.src_decl);
        return .{
            .file_scope = src_decl.getFileScope(mod),
            .parent_decl_node = src_decl.src_node,
            .lazy = exp.src,
        };
    }
};

const ValueArena = struct {
    state: std.heap.ArenaAllocator.State,
    state_acquired: ?*std.heap.ArenaAllocator.State = null,

    /// If this ValueArena replaced an existing one during re-analysis, this is the previous instance
    prev: ?*ValueArena = null,

    /// Returns an allocator backed by either promoting `state`, or by the existing ArenaAllocator
    /// that has already promoted `state`. `out_arena_allocator` provides storage for the initial promotion,
    /// and must live until the matching call to release().
    pub fn acquire(self: *ValueArena, child_allocator: Allocator, out_arena_allocator: *std.heap.ArenaAllocator) Allocator {
        if (self.state_acquired) |state_acquired| {
            return @as(*std.heap.ArenaAllocator, @fieldParentPtr("state", state_acquired)).allocator();
        }

        out_arena_allocator.* = self.state.promote(child_allocator);
        self.state_acquired = &out_arena_allocator.state;
        return out_arena_allocator.allocator();
    }

    /// Releases the allocator acquired by `acquire. `arena_allocator` must match the one passed to `acquire`.
    pub fn release(self: *ValueArena, arena_allocator: *std.heap.ArenaAllocator) void {
        if (@as(*std.heap.ArenaAllocator, @fieldParentPtr("state", self.state_acquired.?)) == arena_allocator) {
            self.state = self.state_acquired.?.*;
            self.state_acquired = null;
        }
    }

    pub fn deinit(self: ValueArena, child_allocator: Allocator) void {
        assert(self.state_acquired == null);

        const prev = self.prev;
        self.state.promote(child_allocator).deinit();

        if (prev) |p| {
            p.deinit(child_allocator);
        }
    }
};

pub const Decl = struct {
    name: InternPool.NullTerminatedString,
    /// The most recent Value of the Decl after a successful semantic analysis.
    /// Populated when `has_tv`.
    val: Value,
    /// Populated when `has_tv`.
    @"linksection": InternPool.OptionalNullTerminatedString,
    /// Populated when `has_tv`.
    alignment: Alignment,
    /// Populated when `has_tv`.
    @"addrspace": std.builtin.AddressSpace,
    /// The direct parent namespace of the Decl. In the case of the Decl
    /// corresponding to a file, this is the namespace of the struct, since
    /// there is no parent.
    src_namespace: Namespace.Index,

    /// The AST node index of this declaration.
    /// Must be recomputed when the corresponding source file is modified.
    src_node: Ast.Node.Index,
    /// Line number corresponding to `src_node`. Stored separately so that source files
    /// do not need to be loaded into memory in order to compute debug line numbers.
    /// This value is absolute.
    src_line: u32,
    /// Index of the ZIR `declaration` instruction from which this `Decl` was created.
    /// For the root `Decl` of a `File` and legacy anonymous decls, this is `.none`.
    zir_decl_index: InternPool.TrackedInst.Index.Optional,

    /// Represents the "shallow" analysis status. For example, for decls that are functions,
    /// the function type is analyzed with this set to `in_progress`, however, the semantic
    /// analysis of the function body is performed with this value set to `success`. Functions
    /// have their own analysis status field.
    analysis: enum {
        /// This Decl corresponds to an AST Node that has not been referenced yet, and therefore
        /// because of Zig's lazy declaration analysis, it will remain unanalyzed until referenced.
        unreferenced,
        /// Semantic analysis for this Decl is running right now.
        /// This state detects dependency loops.
        in_progress,
        /// The file corresponding to this Decl had a parse error or ZIR error.
        /// There will be a corresponding ErrorMsg in Zcu.failed_files.
        file_failure,
        /// This Decl might be OK but it depends on another one which did not
        /// successfully complete semantic analysis.
        dependency_failure,
        /// Semantic analysis failure.
        /// There will be a corresponding ErrorMsg in Zcu.failed_decls.
        sema_failure,
        /// There will be a corresponding ErrorMsg in Zcu.failed_decls.
        codegen_failure,
        /// Sematic analysis and constant value codegen of this Decl has
        /// succeeded. However, the Decl may be outdated due to an in-progress
        /// update. Note that for a function, this does not mean codegen of the
        /// function body succeded: that state is indicated by the function's
        /// `analysis` field.
        complete,
    },
    /// Whether `typed_value`, `align`, `linksection` and `addrspace` are populated.
    has_tv: bool,
    /// If `true` it means the `Decl` is the resource owner of the type/value associated
    /// with it. That means when `Decl` is destroyed, the cleanup code should additionally
    /// check if the value owns a `Namespace`, and destroy that too.
    owns_tv: bool,
    /// Whether the corresponding AST decl has a `pub` keyword.
    is_pub: bool,
    /// Whether the corresponding AST decl has a `export` keyword.
    is_exported: bool,
    /// If true `name` is already fully qualified.
    name_fully_qualified: bool = false,
    /// What kind of a declaration is this.
    kind: Kind,

    pub const Kind = enum {
        @"usingnamespace",
        @"test",
        @"comptime",
        named,
        anon,
    };

    const Index = InternPool.DeclIndex;
    const OptionalIndex = InternPool.OptionalDeclIndex;

    pub fn zirBodies(decl: Decl, zcu: *Zcu) Zir.Inst.Declaration.Bodies {
        const zir = decl.getFileScope(zcu).zir;
        const zir_index = decl.zir_decl_index.unwrap().?.resolve(&zcu.intern_pool);
        const pl_node = zir.instructions.items(.data)[@intFromEnum(zir_index)].pl_node;
        const extra = zir.extraData(Zir.Inst.Declaration, pl_node.payload_index);
        return extra.data.getBodies(@intCast(extra.end), zir);
    }

    pub fn relativeToNodeIndex(decl: Decl, offset: i32) Ast.Node.Index {
        return @bitCast(offset + @as(i32, @bitCast(decl.src_node)));
    }

    pub fn nodeIndexToRelative(decl: Decl, node_index: Ast.Node.Index) i32 {
        return @as(i32, @bitCast(node_index)) - @as(i32, @bitCast(decl.src_node));
    }

    pub fn srcLoc(decl: Decl, zcu: *Zcu) SrcLoc {
        return decl.nodeOffsetSrcLoc(0, zcu);
    }

    pub fn nodeOffsetSrcLoc(decl: Decl, node_offset: i32, zcu: *Zcu) SrcLoc {
        return .{
            .file_scope = decl.getFileScope(zcu),
            .parent_decl_node = decl.src_node,
            .lazy = LazySrcLoc.nodeOffset(node_offset),
        };
    }

    pub fn renderFullyQualifiedName(decl: Decl, zcu: *Zcu, writer: anytype) !void {
        if (decl.name_fully_qualified) {
            try writer.print("{}", .{decl.name.fmt(&zcu.intern_pool)});
        } else {
            try zcu.namespacePtr(decl.src_namespace).renderFullyQualifiedName(zcu, decl.name, writer);
        }
    }

    pub fn renderFullyQualifiedDebugName(decl: Decl, zcu: *Zcu, writer: anytype) !void {
        return zcu.namespacePtr(decl.src_namespace).renderFullyQualifiedDebugName(zcu, decl.name, writer);
    }

    pub fn fullyQualifiedName(decl: Decl, zcu: *Zcu) !InternPool.NullTerminatedString {
        return if (decl.name_fully_qualified)
            decl.name
        else
            zcu.namespacePtr(decl.src_namespace).fullyQualifiedName(zcu, decl.name);
    }

    pub fn typeOf(decl: Decl, zcu: *const Zcu) Type {
        assert(decl.has_tv);
        return decl.val.typeOf(zcu);
    }

    /// Small wrapper for Sema to use over direct access to the `val` field.
    /// If the value is not populated, instead returns `error.AnalysisFail`.
    pub fn valueOrFail(decl: Decl) error{AnalysisFail}!Value {
        if (!decl.has_tv) return error.AnalysisFail;
        return decl.val;
    }

    pub fn getOwnedFunction(decl: Decl, zcu: *Zcu) ?InternPool.Key.Func {
        const i = decl.getOwnedFunctionIndex();
        if (i == .none) return null;
        return switch (zcu.intern_pool.indexToKey(i)) {
            .func => |func| func,
            else => null,
        };
    }

    /// This returns an InternPool.Index even when the value is not a function.
    pub fn getOwnedFunctionIndex(decl: Decl) InternPool.Index {
        return if (decl.owns_tv) decl.val.toIntern() else .none;
    }

    /// If the Decl owns its value and it is an extern function, returns it,
    /// otherwise null.
    pub fn getOwnedExternFunc(decl: Decl, zcu: *Zcu) ?InternPool.Key.ExternFunc {
        return if (decl.owns_tv) decl.val.getExternFunc(zcu) else null;
    }

    /// If the Decl owns its value and it is a variable, returns it,
    /// otherwise null.
    pub fn getOwnedVariable(decl: Decl, zcu: *Zcu) ?InternPool.Key.Variable {
        return if (decl.owns_tv) decl.val.getVariable(zcu) else null;
    }

    /// Gets the namespace that this Decl creates by being a struct, union,
    /// enum, or opaque.
    pub fn getInnerNamespaceIndex(decl: Decl, zcu: *Zcu) Namespace.OptionalIndex {
        if (!decl.has_tv) return .none;
        const ip = &zcu.intern_pool;
        return switch (decl.val.ip_index) {
            .empty_struct_type => .none,
            .none => .none,
            else => switch (ip.indexToKey(decl.val.toIntern())) {
                .opaque_type => ip.loadOpaqueType(decl.val.toIntern()).namespace,
                .struct_type => ip.loadStructType(decl.val.toIntern()).namespace,
                .union_type => ip.loadUnionType(decl.val.toIntern()).namespace,
                .enum_type => ip.loadEnumType(decl.val.toIntern()).namespace,
                else => .none,
            },
        };
    }

    /// Like `getInnerNamespaceIndex`, but only returns it if the Decl is the owner.
    pub fn getOwnedInnerNamespaceIndex(decl: Decl, zcu: *Zcu) Namespace.OptionalIndex {
        if (!decl.owns_tv) return .none;
        return decl.getInnerNamespaceIndex(zcu);
    }

    /// Same as `getOwnedInnerNamespaceIndex` but additionally obtains the pointer.
    pub fn getOwnedInnerNamespace(decl: Decl, zcu: *Zcu) ?*Namespace {
        return zcu.namespacePtrUnwrap(decl.getOwnedInnerNamespaceIndex(zcu));
    }

    /// Same as `getInnerNamespaceIndex` but additionally obtains the pointer.
    pub fn getInnerNamespace(decl: Decl, zcu: *Zcu) ?*Namespace {
        return zcu.namespacePtrUnwrap(decl.getInnerNamespaceIndex(zcu));
    }

    pub fn getFileScope(decl: Decl, zcu: *Zcu) *File {
        return zcu.namespacePtr(decl.src_namespace).file_scope;
    }

    pub fn getExternDecl(decl: Decl, zcu: *Zcu) OptionalIndex {
        assert(decl.has_tv);
        return switch (zcu.intern_pool.indexToKey(decl.val.toIntern())) {
            .variable => |variable| if (variable.is_extern) variable.decl.toOptional() else .none,
            .extern_func => |extern_func| extern_func.decl.toOptional(),
            else => .none,
        };
    }

    pub fn isExtern(decl: Decl, zcu: *Zcu) bool {
        return decl.getExternDecl(zcu) != .none;
    }

    pub fn getAlignment(decl: Decl, zcu: *Zcu) Alignment {
        assert(decl.has_tv);
        if (decl.alignment != .none) return decl.alignment;
        return decl.typeOf(zcu).abiAlignment(zcu);
    }

    /// Upgrade a `LazySrcLoc` to a `SrcLoc` based on the `Decl` provided.
    pub fn toSrcLoc(decl: *Decl, lazy: LazySrcLoc, mod: *Module) SrcLoc {
        return switch (lazy) {
            .unneeded,
            .entire_file,
            .byte_abs,
            .token_abs,
            .node_abs,
            => .{
                .file_scope = decl.getFileScope(mod),
                .parent_decl_node = 0,
                .lazy = lazy,
            },

            .byte_offset,
            .token_offset,
            .node_offset,
            .node_offset_main_token,
            .node_offset_initializer,
            .node_offset_var_decl_ty,
            .node_offset_var_decl_align,
            .node_offset_var_decl_section,
            .node_offset_var_decl_addrspace,
            .node_offset_var_decl_init,
            .node_offset_builtin_call_arg0,
            .node_offset_builtin_call_arg1,
            .node_offset_builtin_call_arg2,
            .node_offset_builtin_call_arg3,
            .node_offset_builtin_call_arg4,
            .node_offset_builtin_call_arg5,
            .node_offset_ptrcast_operand,
            .node_offset_array_access_index,
            .node_offset_slice_ptr,
            .node_offset_slice_start,
            .node_offset_slice_end,
            .node_offset_slice_sentinel,
            .node_offset_call_func,
            .node_offset_field_name,
            .node_offset_field_name_init,
            .node_offset_deref_ptr,
            .node_offset_asm_source,
            .node_offset_asm_ret_ty,
            .node_offset_if_cond,
            .node_offset_bin_op,
            .node_offset_bin_lhs,
            .node_offset_bin_rhs,
            .node_offset_switch_operand,
            .node_offset_switch_special_prong,
            .node_offset_switch_range,
            .node_offset_switch_prong_capture,
            .node_offset_switch_prong_tag_capture,
            .node_offset_fn_type_align,
            .node_offset_fn_type_addrspace,
            .node_offset_fn_type_section,
            .node_offset_fn_type_cc,
            .node_offset_fn_type_ret_ty,
            .node_offset_param,
            .token_offset_param,
            .node_offset_anyframe_type,
            .node_offset_lib_name,
            .node_offset_array_type_len,
            .node_offset_array_type_sentinel,
            .node_offset_array_type_elem,
            .node_offset_un_op,
            .node_offset_ptr_elem,
            .node_offset_ptr_sentinel,
            .node_offset_ptr_align,
            .node_offset_ptr_addrspace,
            .node_offset_ptr_bitoffset,
            .node_offset_ptr_hostsize,
            .node_offset_container_tag,
            .node_offset_field_default,
            .node_offset_init_ty,
            .node_offset_store_ptr,
            .node_offset_store_operand,
            .node_offset_return_operand,
            .for_input,
            .for_capture_from_input,
            .array_cat_lhs,
            .array_cat_rhs,
            => .{
                .file_scope = decl.getFileScope(mod),
                .parent_decl_node = decl.src_node,
                .lazy = lazy,
            },
            inline .call_arg,
            .fn_proto_param,
            => |x| .{
                .file_scope = decl.getFileScope(mod),
                .parent_decl_node = mod.declPtr(x.decl).src_node,
                .lazy = lazy,
            },
        };
    }

    pub fn declPtrType(decl: Decl, zcu: *Zcu) !Type {
        assert(decl.has_tv);
        const decl_ty = decl.typeOf(zcu);
        return zcu.ptrType(.{
            .child = decl_ty.toIntern(),
            .flags = .{
                .alignment = if (decl.alignment == decl_ty.abiAlignment(zcu))
                    .none
                else
                    decl.alignment,
                .address_space = decl.@"addrspace",
                .is_const = decl.getOwnedVariable(zcu) == null,
            },
        });
    }
};

/// This state is attached to every Decl when Module emit_h is non-null.
pub const EmitH = struct {
    fwd_decl: ArrayListUnmanaged(u8) = .{},
};

pub const DeclAdapter = struct {
    zcu: *Zcu,

    pub fn hash(self: @This(), s: InternPool.NullTerminatedString) u32 {
        _ = self;
        return std.hash.uint32(@intFromEnum(s));
    }

    pub fn eql(self: @This(), a: InternPool.NullTerminatedString, b_decl_index: Decl.Index, b_index: usize) bool {
        _ = b_index;
        return a == self.zcu.declPtr(b_decl_index).name;
    }
};

/// The container that structs, enums, unions, and opaques have.
pub const Namespace = struct {
    parent: OptionalIndex,
    file_scope: *File,
    /// Will be a struct, enum, union, or opaque.
    decl_index: Decl.Index,
    /// Direct children of the namespace.
    /// Declaration order is preserved via entry order.
    /// These are only declarations named directly by the AST; anonymous
    /// declarations are not stored here.
    decls: std.ArrayHashMapUnmanaged(Decl.Index, void, DeclContext, true) = .{},
    /// Key is usingnamespace Decl itself. To find the namespace being included,
    /// the Decl Value has to be resolved as a Type which has a Namespace.
    /// Value is whether the usingnamespace decl is marked `pub`.
    usingnamespace_set: std.AutoHashMapUnmanaged(Decl.Index, bool) = .{},

    const Index = InternPool.NamespaceIndex;
    const OptionalIndex = InternPool.OptionalNamespaceIndex;

    const DeclContext = struct {
        zcu: *Zcu,

        pub fn hash(ctx: @This(), decl_index: Decl.Index) u32 {
            const decl = ctx.zcu.declPtr(decl_index);
            return std.hash.uint32(@intFromEnum(decl.name));
        }

        pub fn eql(ctx: @This(), a_decl_index: Decl.Index, b_decl_index: Decl.Index, b_index: usize) bool {
            _ = b_index;
            const a_decl = ctx.zcu.declPtr(a_decl_index);
            const b_decl = ctx.zcu.declPtr(b_decl_index);
            return a_decl.name == b_decl.name;
        }
    };

    // This renders e.g. "std.fs.Dir.OpenOptions"
    pub fn renderFullyQualifiedName(
        ns: Namespace,
        zcu: *Zcu,
        name: InternPool.NullTerminatedString,
        writer: anytype,
    ) @TypeOf(writer).Error!void {
        if (ns.parent.unwrap()) |parent| {
            try zcu.namespacePtr(parent).renderFullyQualifiedName(
                zcu,
                zcu.declPtr(ns.decl_index).name,
                writer,
            );
        } else {
            try ns.file_scope.renderFullyQualifiedName(writer);
        }
        if (name != .empty) try writer.print(".{}", .{name.fmt(&zcu.intern_pool)});
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
            try ns.file_scope.renderFullyQualifiedDebugName(writer);
            break :sep ':';
        };
        if (name != .empty) try writer.print("{c}{}", .{ sep, name.fmt(&zcu.intern_pool) });
    }

    pub fn fullyQualifiedName(
        ns: Namespace,
        zcu: *Zcu,
        name: InternPool.NullTerminatedString,
    ) !InternPool.NullTerminatedString {
        const ip = &zcu.intern_pool;
        const count = count: {
            var count: usize = name.length(ip) + 1;
            var cur_ns = &ns;
            while (true) {
                const decl = zcu.declPtr(cur_ns.decl_index);
                count += decl.name.length(ip) + 1;
                cur_ns = zcu.namespacePtr(cur_ns.parent.unwrap() orelse {
                    count += ns.file_scope.sub_file_path.len;
                    break :count count;
                });
            }
        };

        const gpa = zcu.gpa;
        const start = ip.string_bytes.items.len;
        // Protects reads of interned strings from being reallocated during the call to
        // renderFullyQualifiedName.
        try ip.string_bytes.ensureUnusedCapacity(gpa, count);
        ns.renderFullyQualifiedName(zcu, name, ip.string_bytes.writer(gpa)) catch unreachable;

        // Sanitize the name for nvptx which is more restrictive.
        // TODO This should be handled by the backend, not the frontend. Have a
        // look at how the C backend does it for inspiration.
        const cpu_arch = zcu.root_mod.resolved_target.result.cpu.arch;
        if (cpu_arch.isNvptx()) {
            for (ip.string_bytes.items[start..]) |*byte| switch (byte.*) {
                '{', '}', '*', '[', ']', '(', ')', ',', ' ', '\'' => byte.* = '_',
                else => {},
            };
        }

        return ip.getOrPutTrailingString(gpa, ip.string_bytes.items.len - start, .no_embedded_nulls);
    }

    pub fn getType(ns: Namespace, zcu: *Zcu) Type {
        const decl = zcu.declPtr(ns.decl_index);
        assert(decl.has_tv);
        return decl.val.toType();
    }
};

pub const File = struct {
    /// The Decl of the struct that represents this File.
    root_decl: Decl.OptionalIndex,
    status: enum {
        never_loaded,
        retryable_failure,
        parse_failure,
        astgen_failure,
        success_zir,
    },
    source_loaded: bool,
    tree_loaded: bool,
    zir_loaded: bool,
    /// Relative to the owning package's root_src_dir.
    /// Memory is stored in gpa, owned by File.
    sub_file_path: []const u8,
    /// Whether this is populated depends on `source_loaded`.
    source: [:0]const u8,
    /// Whether this is populated depends on `status`.
    stat: Cache.File.Stat,
    /// Whether this is populated or not depends on `tree_loaded`.
    tree: Ast,
    /// Whether this is populated or not depends on `zir_loaded`.
    zir: Zir,
    /// Module that this file is a part of, managed externally.
    mod: *Package.Module,
    /// Whether this file is a part of multiple packages. This is an error condition which will be reported after AstGen.
    multi_pkg: bool = false,
    /// List of references to this file, used for multi-package errors.
    references: std.ArrayListUnmanaged(Reference) = .{},
    /// The hash of the path to this file, used to store `InternPool.TrackedInst`.
    /// undefined until `zir_loaded == true`.
    path_digest: Cache.BinDigest = undefined,

    /// The most recent successful ZIR for this file, with no errors.
    /// This is only populated when a previously successful ZIR
    /// newly introduces compile errors during an update. When ZIR is
    /// successful, this field is unloaded.
    prev_zir: ?*Zir = null,

    /// A single reference to a file.
    pub const Reference = union(enum) {
        /// The file is imported directly (i.e. not as a package) with @import.
        import: SrcLoc,
        /// The file is the root of a module.
        root: *Package.Module,
    };

    pub fn unload(file: *File, gpa: Allocator) void {
        file.unloadTree(gpa);
        file.unloadSource(gpa);
        file.unloadZir(gpa);
    }

    pub fn unloadTree(file: *File, gpa: Allocator) void {
        if (file.tree_loaded) {
            file.tree_loaded = false;
            file.tree.deinit(gpa);
        }
    }

    pub fn unloadSource(file: *File, gpa: Allocator) void {
        if (file.source_loaded) {
            file.source_loaded = false;
            gpa.free(file.source);
        }
    }

    pub fn unloadZir(file: *File, gpa: Allocator) void {
        if (file.zir_loaded) {
            file.zir_loaded = false;
            file.zir.deinit(gpa);
        }
    }

    pub fn deinit(file: *File, mod: *Module) void {
        const gpa = mod.gpa;
        const is_builtin = file.mod.isBuiltin();
        log.debug("deinit File {s}", .{file.sub_file_path});
        if (is_builtin) {
            file.unloadTree(gpa);
            file.unloadZir(gpa);
        } else {
            gpa.free(file.sub_file_path);
            file.unload(gpa);
        }
        file.references.deinit(gpa);
        if (file.root_decl.unwrap()) |root_decl| {
            mod.destroyDecl(root_decl);
        }
        if (file.prev_zir) |prev_zir| {
            prev_zir.deinit(gpa);
            gpa.destroy(prev_zir);
        }
        file.* = undefined;
    }

    pub const Source = struct {
        bytes: [:0]const u8,
        stat: Cache.File.Stat,
    };

    pub fn getSource(file: *File, gpa: Allocator) !Source {
        if (file.source_loaded) return Source{
            .bytes = file.source,
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
        defer if (!file.source_loaded) gpa.free(source);
        const amt = try f.readAll(source);
        if (amt != stat.size)
            return error.UnexpectedEndOfFile;

        // Here we do not modify stat fields because this function is the one
        // used for error reporting. We need to keep the stat fields stale so that
        // astGenFile can know to regenerate ZIR.

        file.source = source;
        file.source_loaded = true;
        return Source{
            .bytes = source,
            .stat = .{
                .size = stat.size,
                .inode = stat.inode,
                .mtime = stat.mtime,
            },
        };
    }

    pub fn getTree(file: *File, gpa: Allocator) !*const Ast {
        if (file.tree_loaded) return &file.tree;

        const source = try file.getSource(gpa);
        file.tree = try Ast.parse(gpa, source.bytes, .zig);
        file.tree_loaded = true;
        return &file.tree;
    }

    pub fn destroy(file: *File, mod: *Module) void {
        const gpa = mod.gpa;
        const is_builtin = file.mod.isBuiltin();
        file.deinit(mod);
        if (!is_builtin) gpa.destroy(file);
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

    pub fn fullyQualifiedName(file: File, mod: *Module) !InternPool.NullTerminatedString {
        const ip = &mod.intern_pool;
        const start = ip.string_bytes.items.len;
        try file.renderFullyQualifiedName(ip.string_bytes.writer(mod.gpa));
        return ip.getOrPutTrailingString(mod.gpa, ip.string_bytes.items.len - start, .no_embedded_nulls);
    }

    pub fn fullPath(file: File, ally: Allocator) ![]u8 {
        return file.mod.root.joinString(ally, file.sub_file_path);
    }

    pub fn dumpSrc(file: *File, src: LazySrcLoc) void {
        const loc = std.zig.findLineColumn(file.source.bytes, src);
        std.debug.print("{s}:{d}:{d}\n", .{ file.sub_file_path, loc.line + 1, loc.column + 1 });
    }

    pub fn okToReportErrors(file: File) bool {
        return switch (file.status) {
            .parse_failure, .astgen_failure => false,
            else => true,
        };
    }

    /// Add a reference to this file during AstGen.
    pub fn addReference(file: *File, mod: Module, ref: Reference) !void {
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
            .root => try file.references.insert(mod.gpa, 0, ref),

            // Other references we'll just put at the end.
            else => try file.references.append(mod.gpa, ref),
        }

        const pkg = switch (ref) {
            .import => |loc| loc.file_scope.mod,
            .root => |pkg| pkg,
        };
        if (pkg != file.mod) file.multi_pkg = true;
    }

    /// Mark this file and every file referenced by it as multi_pkg and report an
    /// astgen_failure error for them. AstGen must have completed in its entirety.
    pub fn recursiveMarkMultiPkg(file: *File, mod: *Module) void {
        file.multi_pkg = true;
        file.status = .astgen_failure;

        // We can only mark children as failed if the ZIR is loaded, which may not
        // be the case if there were other astgen failures in this file
        if (!file.zir_loaded) return;

        const imports_index = file.zir.extra[@intFromEnum(Zir.ExtraIndex.imports)];
        if (imports_index == 0) return;
        const extra = file.zir.extraData(Zir.Inst.Imports, imports_index);

        var extra_index = extra.end;
        for (0..extra.data.imports_len) |_| {
            const item = file.zir.extraData(Zir.Inst.Imports.Item, extra_index);
            extra_index = item.end;

            const import_path = file.zir.nullTerminatedString(item.data.name);
            if (mem.eql(u8, import_path, "builtin")) continue;

            const res = mod.importFile(file, import_path) catch continue;
            if (!res.is_pkg and !res.file.multi_pkg) {
                res.file.recursiveMarkMultiPkg(mod);
            }
        }
    }
};

pub const EmbedFile = struct {
    /// Relative to the owning module's root directory.
    sub_file_path: InternPool.NullTerminatedString,
    /// Module that this file is a part of, managed externally.
    owner: *Package.Module,
    stat: Cache.File.Stat,
    val: InternPool.Index,
    src_loc: SrcLoc,
};

/// This struct holds data necessary to construct API-facing `AllErrors.Message`.
/// Its memory is managed with the general purpose allocator so that they
/// can be created and destroyed in response to incremental updates.
/// In some cases, the File could have been inferred from where the ErrorMsg
/// is stored. For example, if it is stored in Module.failed_decls, then the File
/// would be determined by the Decl Scope. However, the data structure contains the field
/// anyway so that `ErrorMsg` can be reused for error notes, which may be in a different
/// file than the parent error message. It also simplifies processing of error messages.
pub const ErrorMsg = struct {
    src_loc: SrcLoc,
    msg: []const u8,
    notes: []ErrorMsg = &.{},
    reference_trace: []Trace = &.{},
    hidden_references: u32 = 0,

    pub const Trace = struct {
        decl: InternPool.NullTerminatedString,
        src_loc: SrcLoc,
    };

    pub fn create(
        gpa: Allocator,
        src_loc: SrcLoc,
        comptime format: []const u8,
        args: anytype,
    ) !*ErrorMsg {
        assert(src_loc.lazy != .unneeded);
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
        src_loc: SrcLoc,
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
        gpa.free(err_msg.reference_trace);
        err_msg.* = undefined;
    }
};

/// Canonical reference to a position within a source file.
pub const SrcLoc = struct {
    file_scope: *File,
    /// Might be 0 depending on tag of `lazy`.
    parent_decl_node: Ast.Node.Index,
    /// Relative to `parent_decl_node`.
    lazy: LazySrcLoc,

    pub fn declSrcToken(src_loc: SrcLoc) Ast.TokenIndex {
        const tree = src_loc.file_scope.tree;
        return tree.firstToken(src_loc.parent_decl_node);
    }

    pub fn declRelativeToNodeIndex(src_loc: SrcLoc, offset: i32) Ast.Node.Index {
        return @bitCast(offset + @as(i32, @bitCast(src_loc.parent_decl_node)));
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
                const tok_index = src_loc.declSrcToken();
                const start = tree.tokens.items(.start)[tok_index] + byte_off;
                const end = start + @as(u32, @intCast(tree.tokenSlice(tok_index).len));
                return Span{ .start = start, .end = end, .main = start };
            },
            .token_offset => |tok_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const tok_index = src_loc.declSrcToken() + tok_off;
                const start = tree.tokens.items(.start)[tok_index];
                const end = start + @as(u32, @intCast(tree.tokenSlice(tok_index).len));
                return Span{ .start = start, .end = end, .main = start };
            },
            .node_offset => |traced_off| {
                const node_off = traced_off.x;
                const tree = try src_loc.file_scope.getTree(gpa);
                const node = src_loc.declRelativeToNodeIndex(node_off);
                assert(src_loc.file_scope.tree_loaded);
                return tree.nodeToSpan(node);
            },
            .node_offset_main_token => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const node = src_loc.declRelativeToNodeIndex(node_off);
                const main_token = tree.nodes.items(.main_token)[node];
                return tree.tokensToSpan(main_token, main_token, main_token);
            },
            .node_offset_bin_op => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const node = src_loc.declRelativeToNodeIndex(node_off);
                assert(src_loc.file_scope.tree_loaded);
                return tree.nodeToSpan(node);
            },
            .node_offset_initializer => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const node = src_loc.declRelativeToNodeIndex(node_off);
                return tree.tokensToSpan(
                    tree.firstToken(node) - 3,
                    tree.lastToken(node),
                    tree.nodes.items(.main_token)[node] - 2,
                );
            },
            .node_offset_var_decl_ty => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const node = src_loc.declRelativeToNodeIndex(node_off);
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
                const node = src_loc.declRelativeToNodeIndex(node_off);
                const full = tree.fullVarDecl(node).?;
                return tree.nodeToSpan(full.ast.align_node);
            },
            .node_offset_var_decl_section => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const node = src_loc.declRelativeToNodeIndex(node_off);
                const full = tree.fullVarDecl(node).?;
                return tree.nodeToSpan(full.ast.section_node);
            },
            .node_offset_var_decl_addrspace => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const node = src_loc.declRelativeToNodeIndex(node_off);
                const full = tree.fullVarDecl(node).?;
                return tree.nodeToSpan(full.ast.addrspace_node);
            },
            .node_offset_var_decl_init => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const node = src_loc.declRelativeToNodeIndex(node_off);
                const full = tree.fullVarDecl(node).?;
                return tree.nodeToSpan(full.ast.init_node);
            },
            .node_offset_builtin_call_arg0 => |n| return src_loc.byteOffsetBuiltinCallArg(gpa, n, 0),
            .node_offset_builtin_call_arg1 => |n| return src_loc.byteOffsetBuiltinCallArg(gpa, n, 1),
            .node_offset_builtin_call_arg2 => |n| return src_loc.byteOffsetBuiltinCallArg(gpa, n, 2),
            .node_offset_builtin_call_arg3 => |n| return src_loc.byteOffsetBuiltinCallArg(gpa, n, 3),
            .node_offset_builtin_call_arg4 => |n| return src_loc.byteOffsetBuiltinCallArg(gpa, n, 4),
            .node_offset_builtin_call_arg5 => |n| return src_loc.byteOffsetBuiltinCallArg(gpa, n, 5),
            .node_offset_ptrcast_operand => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const main_tokens = tree.nodes.items(.main_token);
                const node_datas = tree.nodes.items(.data);
                const node_tags = tree.nodes.items(.tag);

                var node = src_loc.declRelativeToNodeIndex(node_off);
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
                const node = src_loc.declRelativeToNodeIndex(node_off);
                return tree.nodeToSpan(node_datas[node].rhs);
            },
            .node_offset_slice_ptr,
            .node_offset_slice_start,
            .node_offset_slice_end,
            .node_offset_slice_sentinel,
            => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const node = src_loc.declRelativeToNodeIndex(node_off);
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
                const node = src_loc.declRelativeToNodeIndex(node_off);
                var buf: [1]Ast.Node.Index = undefined;
                const full = tree.fullCall(&buf, node).?;
                return tree.nodeToSpan(full.ast.fn_expr);
            },
            .node_offset_field_name => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const node_datas = tree.nodes.items(.data);
                const node_tags = tree.nodes.items(.tag);
                const node = src_loc.declRelativeToNodeIndex(node_off);
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
                const node = src_loc.declRelativeToNodeIndex(node_off);
                const tok_index = tree.firstToken(node) - 2;
                const start = tree.tokens.items(.start)[tok_index];
                const end = start + @as(u32, @intCast(tree.tokenSlice(tok_index).len));
                return Span{ .start = start, .end = end, .main = start };
            },
            .node_offset_deref_ptr => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const node = src_loc.declRelativeToNodeIndex(node_off);
                return tree.nodeToSpan(node);
            },
            .node_offset_asm_source => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const node = src_loc.declRelativeToNodeIndex(node_off);
                const full = tree.fullAsm(node).?;
                return tree.nodeToSpan(full.ast.template);
            },
            .node_offset_asm_ret_ty => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const node = src_loc.declRelativeToNodeIndex(node_off);
                const full = tree.fullAsm(node).?;
                const asm_output = full.outputs[0];
                const node_datas = tree.nodes.items(.data);
                return tree.nodeToSpan(node_datas[asm_output].lhs);
            },

            .node_offset_if_cond => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const node = src_loc.declRelativeToNodeIndex(node_off);
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
                const node = src_loc.declRelativeToNodeIndex(for_input.for_node_offset);
                const for_full = tree.fullFor(node).?;
                const src_node = for_full.ast.inputs[for_input.input_index];
                return tree.nodeToSpan(src_node);
            },
            .for_capture_from_input => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const token_tags = tree.tokens.items(.tag);
                const input_node = src_loc.declRelativeToNodeIndex(node_off);
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
                const node = src_loc.declRelativeToNodeIndex(call_arg.call_node_offset);
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
            .fn_proto_param => |fn_proto_param| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const node = src_loc.declRelativeToNodeIndex(fn_proto_param.fn_proto_node_offset);
                var buf: [1]Ast.Node.Index = undefined;
                const full = tree.fullFnProto(&buf, node).?;
                var it = full.iterate(tree);
                var i: usize = 0;
                while (it.next()) |param| : (i += 1) {
                    if (i == fn_proto_param.param_index) {
                        if (param.anytype_ellipsis3) |token| return tree.tokenToSpan(token);
                        const first_token = param.comptime_noalias orelse
                            param.name_token orelse
                            tree.firstToken(param.type_expr);
                        return tree.tokensToSpan(
                            first_token,
                            tree.lastToken(param.type_expr),
                            first_token,
                        );
                    }
                }
                unreachable;
            },
            .node_offset_bin_lhs => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const node = src_loc.declRelativeToNodeIndex(node_off);
                const node_datas = tree.nodes.items(.data);
                return tree.nodeToSpan(node_datas[node].lhs);
            },
            .node_offset_bin_rhs => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const node = src_loc.declRelativeToNodeIndex(node_off);
                const node_datas = tree.nodes.items(.data);
                return tree.nodeToSpan(node_datas[node].rhs);
            },
            .array_cat_lhs, .array_cat_rhs => |cat| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const node = src_loc.declRelativeToNodeIndex(cat.array_cat_offset);
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
                const node = src_loc.declRelativeToNodeIndex(node_off);
                const node_datas = tree.nodes.items(.data);
                return tree.nodeToSpan(node_datas[node].lhs);
            },

            .node_offset_switch_special_prong => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const switch_node = src_loc.declRelativeToNodeIndex(node_off);
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
                const switch_node = src_loc.declRelativeToNodeIndex(node_off);
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
            .node_offset_switch_prong_capture,
            .node_offset_switch_prong_tag_capture,
            => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const case_node = src_loc.declRelativeToNodeIndex(node_off);
                const case = tree.fullSwitchCase(case_node).?;
                const token_tags = tree.tokens.items(.tag);
                const start_tok = switch (src_loc.lazy) {
                    .node_offset_switch_prong_capture => case.payload_token.?,
                    .node_offset_switch_prong_tag_capture => blk: {
                        var tok = case.payload_token.?;
                        if (token_tags[tok] == .asterisk) tok += 1;
                        tok += 2; // skip over comma
                        break :blk tok;
                    },
                    else => unreachable,
                };
                const end_tok = switch (token_tags[start_tok]) {
                    .asterisk => start_tok + 1,
                    else => start_tok,
                };
                const start = tree.tokens.items(.start)[start_tok];
                const end_start = tree.tokens.items(.start)[end_tok];
                const end = end_start + @as(u32, @intCast(tree.tokenSlice(end_tok).len));
                return Span{ .start = start, .end = end, .main = start };
            },
            .node_offset_fn_type_align => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const node = src_loc.declRelativeToNodeIndex(node_off);
                var buf: [1]Ast.Node.Index = undefined;
                const full = tree.fullFnProto(&buf, node).?;
                return tree.nodeToSpan(full.ast.align_expr);
            },
            .node_offset_fn_type_addrspace => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const node = src_loc.declRelativeToNodeIndex(node_off);
                var buf: [1]Ast.Node.Index = undefined;
                const full = tree.fullFnProto(&buf, node).?;
                return tree.nodeToSpan(full.ast.addrspace_expr);
            },
            .node_offset_fn_type_section => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const node = src_loc.declRelativeToNodeIndex(node_off);
                var buf: [1]Ast.Node.Index = undefined;
                const full = tree.fullFnProto(&buf, node).?;
                return tree.nodeToSpan(full.ast.section_expr);
            },
            .node_offset_fn_type_cc => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const node = src_loc.declRelativeToNodeIndex(node_off);
                var buf: [1]Ast.Node.Index = undefined;
                const full = tree.fullFnProto(&buf, node).?;
                return tree.nodeToSpan(full.ast.callconv_expr);
            },

            .node_offset_fn_type_ret_ty => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const node = src_loc.declRelativeToNodeIndex(node_off);
                var buf: [1]Ast.Node.Index = undefined;
                const full = tree.fullFnProto(&buf, node).?;
                return tree.nodeToSpan(full.ast.return_type);
            },
            .node_offset_param => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const token_tags = tree.tokens.items(.tag);
                const node = src_loc.declRelativeToNodeIndex(node_off);

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
                const main_token = tree.nodes.items(.main_token)[src_loc.parent_decl_node];
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
                const parent_node = src_loc.declRelativeToNodeIndex(node_off);
                return tree.nodeToSpan(node_datas[parent_node].rhs);
            },

            .node_offset_lib_name => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const parent_node = src_loc.declRelativeToNodeIndex(node_off);
                var buf: [1]Ast.Node.Index = undefined;
                const full = tree.fullFnProto(&buf, parent_node).?;
                const tok_index = full.lib_name.?;
                const start = tree.tokens.items(.start)[tok_index];
                const end = start + @as(u32, @intCast(tree.tokenSlice(tok_index).len));
                return Span{ .start = start, .end = end, .main = start };
            },

            .node_offset_array_type_len => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const parent_node = src_loc.declRelativeToNodeIndex(node_off);

                const full = tree.fullArrayType(parent_node).?;
                return tree.nodeToSpan(full.ast.elem_count);
            },
            .node_offset_array_type_sentinel => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const parent_node = src_loc.declRelativeToNodeIndex(node_off);

                const full = tree.fullArrayType(parent_node).?;
                return tree.nodeToSpan(full.ast.sentinel);
            },
            .node_offset_array_type_elem => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const parent_node = src_loc.declRelativeToNodeIndex(node_off);

                const full = tree.fullArrayType(parent_node).?;
                return tree.nodeToSpan(full.ast.elem_type);
            },
            .node_offset_un_op => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const node_datas = tree.nodes.items(.data);
                const node = src_loc.declRelativeToNodeIndex(node_off);

                return tree.nodeToSpan(node_datas[node].lhs);
            },
            .node_offset_ptr_elem => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const parent_node = src_loc.declRelativeToNodeIndex(node_off);

                const full = tree.fullPtrType(parent_node).?;
                return tree.nodeToSpan(full.ast.child_type);
            },
            .node_offset_ptr_sentinel => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const parent_node = src_loc.declRelativeToNodeIndex(node_off);

                const full = tree.fullPtrType(parent_node).?;
                return tree.nodeToSpan(full.ast.sentinel);
            },
            .node_offset_ptr_align => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const parent_node = src_loc.declRelativeToNodeIndex(node_off);

                const full = tree.fullPtrType(parent_node).?;
                return tree.nodeToSpan(full.ast.align_node);
            },
            .node_offset_ptr_addrspace => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const parent_node = src_loc.declRelativeToNodeIndex(node_off);

                const full = tree.fullPtrType(parent_node).?;
                return tree.nodeToSpan(full.ast.addrspace_node);
            },
            .node_offset_ptr_bitoffset => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const parent_node = src_loc.declRelativeToNodeIndex(node_off);

                const full = tree.fullPtrType(parent_node).?;
                return tree.nodeToSpan(full.ast.bit_range_start);
            },
            .node_offset_ptr_hostsize => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const parent_node = src_loc.declRelativeToNodeIndex(node_off);

                const full = tree.fullPtrType(parent_node).?;
                return tree.nodeToSpan(full.ast.bit_range_end);
            },
            .node_offset_container_tag => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const node_tags = tree.nodes.items(.tag);
                const parent_node = src_loc.declRelativeToNodeIndex(node_off);

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
                const parent_node = src_loc.declRelativeToNodeIndex(node_off);

                const full: Ast.full.ContainerField = switch (node_tags[parent_node]) {
                    .container_field => tree.containerField(parent_node),
                    .container_field_init => tree.containerFieldInit(parent_node),
                    else => unreachable,
                };
                return tree.nodeToSpan(full.ast.value_expr);
            },
            .node_offset_init_ty => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const parent_node = src_loc.declRelativeToNodeIndex(node_off);

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
                const node = src_loc.declRelativeToNodeIndex(node_off);

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
                const node = src_loc.declRelativeToNodeIndex(node_off);

                switch (node_tags[node]) {
                    .assign => {
                        return tree.nodeToSpan(node_datas[node].rhs);
                    },
                    else => return tree.nodeToSpan(node),
                }
            },
            .node_offset_return_operand => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const node = src_loc.declRelativeToNodeIndex(node_off);
                const node_tags = tree.nodes.items(.tag);
                const node_datas = tree.nodes.items(.data);
                if (node_tags[node] == .@"return" and node_datas[node].lhs != 0) {
                    return tree.nodeToSpan(node_datas[node].lhs);
                }
                return tree.nodeToSpan(node);
            },
        }
    }

    pub fn byteOffsetBuiltinCallArg(
        src_loc: SrcLoc,
        gpa: Allocator,
        node_off: i32,
        arg_index: u32,
    ) !Span {
        const tree = try src_loc.file_scope.getTree(gpa);
        const node_datas = tree.nodes.items(.data);
        const node_tags = tree.nodes.items(.tag);
        const node = src_loc.declRelativeToNodeIndex(node_off);
        const param = switch (node_tags[node]) {
            .builtin_call_two, .builtin_call_two_comma => switch (arg_index) {
                0 => node_datas[node].lhs,
                1 => node_datas[node].rhs,
                else => unreachable,
            },
            .builtin_call, .builtin_call_comma => tree.extra_data[node_datas[node].lhs + arg_index],
            else => unreachable,
        };
        return tree.nodeToSpan(param);
    }
};

pub const SemaError = error{ OutOfMemory, AnalysisFail };
pub const CompileError = error{
    OutOfMemory,
    /// When this is returned, the compile error for the failure has already been recorded.
    AnalysisFail,
    /// Returned when a compile error needed to be reported but a provided LazySrcLoc was set
    /// to the `unneeded` tag. The source location was, in fact, needed. It is expected that
    /// somewhere up the call stack, the operation will be retried after doing expensive work
    /// to compute a source location.
    NeededSourceLocation,
    /// A Type or Value was needed to be used during semantic analysis, but it was not available
    /// because the function is generic. This is only seen when analyzing the body of a param
    /// instruction.
    GenericPoison,
    /// In a comptime scope, a return instruction was encountered. This error is only seen when
    /// doing a comptime function call.
    ComptimeReturn,
    /// In a comptime scope, a break instruction was encountered. This error is only seen when
    /// evaluating a comptime block.
    ComptimeBreak,
};

pub fn init(mod: *Module) !void {
    const gpa = mod.gpa;
    try mod.intern_pool.init(gpa);
    try mod.global_error_set.put(gpa, .empty, {});
}

pub fn deinit(zcu: *Zcu) void {
    const gpa = zcu.gpa;

    if (zcu.llvm_object) |llvm_object| {
        if (build_options.only_c) unreachable;
        llvm_object.deinit();
    }

    for (zcu.import_table.keys()) |key| {
        gpa.free(key);
    }
    var failed_decls = zcu.failed_decls;
    zcu.failed_decls = .{};
    for (zcu.import_table.values()) |value| {
        value.destroy(zcu);
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

    for (failed_decls.values()) |value| {
        value.destroy(gpa);
    }
    failed_decls.deinit(gpa);

    if (zcu.emit_h) |emit_h| {
        for (emit_h.failed_decls.values()) |value| {
            value.destroy(gpa);
        }
        emit_h.failed_decls.deinit(gpa);
        emit_h.decl_table.deinit(gpa);
        emit_h.allocated_emit_h.deinit(gpa);
    }

    for (zcu.failed_files.values()) |value| {
        if (value) |msg| msg.destroy(gpa);
    }
    zcu.failed_files.deinit(gpa);

    for (zcu.failed_embed_files.values()) |msg| {
        msg.destroy(gpa);
    }
    zcu.failed_embed_files.deinit(gpa);

    for (zcu.failed_exports.values()) |value| {
        value.destroy(gpa);
    }
    zcu.failed_exports.deinit(gpa);

    for (zcu.cimport_errors.values()) |*errs| {
        errs.deinit(gpa);
    }
    zcu.cimport_errors.deinit(gpa);

    zcu.compile_log_decls.deinit(gpa);

    for (zcu.decl_exports.values()) |*export_list| {
        export_list.deinit(gpa);
    }
    zcu.decl_exports.deinit(gpa);

    for (zcu.value_exports.values()) |*export_list| {
        export_list.deinit(gpa);
    }
    zcu.value_exports.deinit(gpa);

    for (zcu.export_owners.values()) |*value| {
        freeExportList(gpa, value);
    }
    zcu.export_owners.deinit(gpa);

    zcu.global_error_set.deinit(gpa);

    zcu.potentially_outdated.deinit(gpa);
    zcu.outdated.deinit(gpa);
    zcu.outdated_ready.deinit(gpa);
    zcu.outdated_file_root.deinit(gpa);
    zcu.retryable_failures.deinit(gpa);

    zcu.test_functions.deinit(gpa);

    for (zcu.global_assembly.values()) |s| {
        gpa.free(s);
    }
    zcu.global_assembly.deinit(gpa);

    zcu.reference_table.deinit(gpa);

    {
        var it = zcu.intern_pool.allocated_namespaces.iterator(0);
        while (it.next()) |namespace| {
            namespace.decls.deinit(gpa);
            namespace.usingnamespace_set.deinit(gpa);
        }
    }

    zcu.intern_pool.deinit(gpa);
}

pub fn destroyDecl(mod: *Module, decl_index: Decl.Index) void {
    const gpa = mod.gpa;
    const ip = &mod.intern_pool;

    {
        _ = mod.test_functions.swapRemove(decl_index);
        if (mod.global_assembly.fetchSwapRemove(decl_index)) |kv| {
            gpa.free(kv.value);
        }
    }

    ip.destroyDecl(gpa, decl_index);

    if (mod.emit_h) |mod_emit_h| {
        const decl_emit_h = mod_emit_h.declPtr(decl_index);
        decl_emit_h.fwd_decl.deinit(gpa);
        decl_emit_h.* = undefined;
    }
}

pub fn declPtr(mod: *Module, index: Decl.Index) *Decl {
    return mod.intern_pool.declPtr(index);
}

pub fn namespacePtr(mod: *Module, index: Namespace.Index) *Namespace {
    return mod.intern_pool.namespacePtr(index);
}

pub fn namespacePtrUnwrap(mod: *Module, index: Namespace.OptionalIndex) ?*Namespace {
    return mod.namespacePtr(index.unwrap() orelse return null);
}

/// Returns true if and only if the Decl is the top level struct associated with a File.
pub fn declIsRoot(mod: *Module, decl_index: Decl.Index) bool {
    const decl = mod.declPtr(decl_index);
    const namespace = mod.namespacePtr(decl.src_namespace);
    if (namespace.parent != .none) return false;
    return decl_index == namespace.decl_index;
}

fn freeExportList(gpa: Allocator, export_list: *ArrayListUnmanaged(*Export)) void {
    for (export_list.items) |exp| gpa.destroy(exp);
    export_list.deinit(gpa);
}

// TODO https://github.com/ziglang/zig/issues/8643
const data_has_safety_tag = @sizeOf(Zir.Inst.Data) != 8;
const HackDataLayout = extern struct {
    data: [8]u8 align(@alignOf(Zir.Inst.Data)),
    safety_tag: u8,
};
comptime {
    if (data_has_safety_tag) {
        assert(@sizeOf(HackDataLayout) == @sizeOf(Zir.Inst.Data));
    }
}

pub fn astGenFile(mod: *Module, file: *File) !void {
    assert(!file.mod.isBuiltin());

    const tracy = trace(@src());
    defer tracy.end();

    const comp = mod.comp;
    const gpa = mod.gpa;

    // In any case we need to examine the stat of the file to determine the course of action.
    var source_file = try file.mod.root.openFile(file.sub_file_path, .{});
    defer source_file.close();

    const stat = try source_file.stat();

    const want_local_cache = file.mod == mod.main_mod;
    const bin_digest = hash: {
        var path_hash: Cache.HashHelper = .{};
        path_hash.addBytes(build_options.version);
        path_hash.add(builtin.zig_backend);
        if (!want_local_cache) {
            path_hash.addOptionalBytes(file.mod.root.root_dir.path);
            path_hash.addBytes(file.mod.root.sub_path);
        }
        path_hash.addBytes(file.sub_file_path);
        var bin: Cache.BinDigest = undefined;
        path_hash.hasher.final(&bin);
        break :hash bin;
    };
    file.path_digest = bin_digest;
    const hex_digest = hex: {
        var hex: Cache.HexDigest = undefined;
        _ = std.fmt.bufPrint(
            &hex,
            "{s}",
            .{std.fmt.fmtSliceHexLower(&bin_digest)},
        ) catch unreachable;
        break :hex hex;
    };
    const cache_directory = if (want_local_cache) mod.local_zir_cache else mod.global_zir_cache;
    const zir_dir = cache_directory.handle;

    // Determine whether we need to reload the file from disk and redo parsing and AstGen.
    var lock: std.fs.File.Lock = switch (file.status) {
        .never_loaded, .retryable_failure => lock: {
            // First, load the cached ZIR code, if any.
            log.debug("AstGen checking cache: {s} (local={}, digest={s})", .{
                file.sub_file_path, want_local_cache, &hex_digest,
            });

            break :lock .shared;
        },
        .parse_failure, .astgen_failure, .success_zir => lock: {
            const unchanged_metadata =
                stat.size == file.stat.size and
                stat.mtime == file.stat.mtime and
                stat.inode == file.stat.inode;

            if (unchanged_metadata) {
                log.debug("unmodified metadata of file: {s}", .{file.sub_file_path});
                return;
            }

            log.debug("metadata changed: {s}", .{file.sub_file_path});

            break :lock .exclusive;
        },
    };

    // We ask for a lock in order to coordinate with other zig processes.
    // If another process is already working on this file, we will get the cached
    // version. Likewise if we're working on AstGen and another process asks for
    // the cached file, they'll get it.
    const cache_file = while (true) {
        break zir_dir.createFile(&hex_digest, .{
            .read = true,
            .truncate = false,
            .lock = lock,
        }) catch |err| switch (err) {
            error.NotDir => unreachable, // no dir components
            error.InvalidUtf8 => unreachable, // it's a hex encoded name
            error.InvalidWtf8 => unreachable, // it's a hex encoded name
            error.BadPathName => unreachable, // it's a hex encoded name
            error.NameTooLong => unreachable, // it's a fixed size name
            error.PipeBusy => unreachable, // it's not a pipe
            error.WouldBlock => unreachable, // not asking for non-blocking I/O
            // There are no dir components, so you would think that this was
            // unreachable, however we have observed on macOS two processes racing
            // to do openat() with O_CREAT manifest in ENOENT.
            error.FileNotFound => continue,

            else => |e| return e, // Retryable errors are handled at callsite.
        };
    };
    defer cache_file.close();

    while (true) {
        update: {
            // First we read the header to determine the lengths of arrays.
            const header = cache_file.reader().readStruct(Zir.Header) catch |err| switch (err) {
                // This can happen if Zig bails out of this function between creating
                // the cached file and writing it.
                error.EndOfStream => break :update,
                else => |e| return e,
            };
            const unchanged_metadata =
                stat.size == header.stat_size and
                stat.mtime == header.stat_mtime and
                stat.inode == header.stat_inode;

            if (!unchanged_metadata) {
                log.debug("AstGen cache stale: {s}", .{file.sub_file_path});
                break :update;
            }
            log.debug("AstGen cache hit: {s} instructions_len={d}", .{
                file.sub_file_path, header.instructions_len,
            });

            file.zir = loadZirCacheBody(gpa, header, cache_file) catch |err| switch (err) {
                error.UnexpectedFileSize => {
                    log.warn("unexpected EOF reading cached ZIR for {s}", .{file.sub_file_path});
                    break :update;
                },
                else => |e| return e,
            };
            file.zir_loaded = true;
            file.stat = .{
                .size = header.stat_size,
                .inode = header.stat_inode,
                .mtime = header.stat_mtime,
            };
            file.status = .success_zir;
            log.debug("AstGen cached success: {s}", .{file.sub_file_path});

            // TODO don't report compile errors until Sema @importFile
            if (file.zir.hasCompileErrors()) {
                {
                    comp.mutex.lock();
                    defer comp.mutex.unlock();
                    try mod.failed_files.putNoClobber(gpa, file, null);
                }
                file.status = .astgen_failure;
                return error.AnalysisFail;
            }
            return;
        }

        // If we already have the exclusive lock then it is our job to update.
        if (builtin.os.tag == .wasi or lock == .exclusive) break;
        // Otherwise, unlock to give someone a chance to get the exclusive lock
        // and then upgrade to an exclusive lock.
        cache_file.unlock();
        lock = .exclusive;
        try cache_file.lock(lock);
    }

    // The cache is definitely stale so delete the contents to avoid an underwrite later.
    cache_file.setEndPos(0) catch |err| switch (err) {
        error.FileTooBig => unreachable, // 0 is not too big

        else => |e| return e,
    };

    mod.lockAndClearFileCompileError(file);

    // If the previous ZIR does not have compile errors, keep it around
    // in case parsing or new ZIR fails. In case of successful ZIR update
    // at the end of this function we will free it.
    // We keep the previous ZIR loaded so that we can use it
    // for the update next time it does not have any compile errors. This avoids
    // needlessly tossing out semantic analysis work when an error is
    // temporarily introduced.
    if (file.zir_loaded and !file.zir.hasCompileErrors()) {
        assert(file.prev_zir == null);
        const prev_zir_ptr = try gpa.create(Zir);
        file.prev_zir = prev_zir_ptr;
        prev_zir_ptr.* = file.zir;
        file.zir = undefined;
        file.zir_loaded = false;
    }
    file.unload(gpa);

    if (stat.size > std.math.maxInt(u32))
        return error.FileTooBig;

    const source = try gpa.allocSentinel(u8, @as(usize, @intCast(stat.size)), 0);
    defer if (!file.source_loaded) gpa.free(source);
    const amt = try source_file.readAll(source);
    if (amt != stat.size)
        return error.UnexpectedEndOfFile;

    file.stat = .{
        .size = stat.size,
        .inode = stat.inode,
        .mtime = stat.mtime,
    };
    file.source = source;
    file.source_loaded = true;

    file.tree = try Ast.parse(gpa, source, .zig);
    file.tree_loaded = true;

    // Any potential AST errors are converted to ZIR errors here.
    file.zir = try AstGen.generate(gpa, file.tree);
    file.zir_loaded = true;
    file.status = .success_zir;
    log.debug("AstGen fresh success: {s}", .{file.sub_file_path});

    const safety_buffer = if (data_has_safety_tag)
        try gpa.alloc([8]u8, file.zir.instructions.len)
    else
        undefined;
    defer if (data_has_safety_tag) gpa.free(safety_buffer);
    const data_ptr = if (data_has_safety_tag)
        if (file.zir.instructions.len == 0)
            @as([*]const u8, undefined)
        else
            @as([*]const u8, @ptrCast(safety_buffer.ptr))
    else
        @as([*]const u8, @ptrCast(file.zir.instructions.items(.data).ptr));
    if (data_has_safety_tag) {
        // The `Data` union has a safety tag but in the file format we store it without.
        for (file.zir.instructions.items(.data), 0..) |*data, i| {
            const as_struct = @as(*const HackDataLayout, @ptrCast(data));
            safety_buffer[i] = as_struct.data;
        }
    }

    const header: Zir.Header = .{
        .instructions_len = @as(u32, @intCast(file.zir.instructions.len)),
        .string_bytes_len = @as(u32, @intCast(file.zir.string_bytes.len)),
        .extra_len = @as(u32, @intCast(file.zir.extra.len)),

        .stat_size = stat.size,
        .stat_inode = stat.inode,
        .stat_mtime = stat.mtime,
    };
    var iovecs = [_]std.posix.iovec_const{
        .{
            .base = @as([*]const u8, @ptrCast(&header)),
            .len = @sizeOf(Zir.Header),
        },
        .{
            .base = @as([*]const u8, @ptrCast(file.zir.instructions.items(.tag).ptr)),
            .len = file.zir.instructions.len,
        },
        .{
            .base = data_ptr,
            .len = file.zir.instructions.len * 8,
        },
        .{
            .base = file.zir.string_bytes.ptr,
            .len = file.zir.string_bytes.len,
        },
        .{
            .base = @as([*]const u8, @ptrCast(file.zir.extra.ptr)),
            .len = file.zir.extra.len * 4,
        },
    };
    cache_file.writevAll(&iovecs) catch |err| {
        log.warn("unable to write cached ZIR code for {}{s} to {}{s}: {s}", .{
            file.mod.root, file.sub_file_path, cache_directory, &hex_digest, @errorName(err),
        });
    };

    if (file.zir.hasCompileErrors()) {
        {
            comp.mutex.lock();
            defer comp.mutex.unlock();
            try mod.failed_files.putNoClobber(gpa, file, null);
        }
        file.status = .astgen_failure;
        return error.AnalysisFail;
    }

    if (file.prev_zir) |prev_zir| {
        try updateZirRefs(mod, file, prev_zir.*);
        // No need to keep previous ZIR.
        prev_zir.deinit(gpa);
        gpa.destroy(prev_zir);
        file.prev_zir = null;
    }

    if (file.root_decl.unwrap()) |root_decl| {
        // The root of this file must be re-analyzed, since the file has changed.
        comp.mutex.lock();
        defer comp.mutex.unlock();

        log.debug("outdated root Decl: {}", .{root_decl});
        try mod.outdated_file_root.put(gpa, root_decl, {});
    }
}

pub fn loadZirCache(gpa: Allocator, cache_file: std.fs.File) !Zir {
    return loadZirCacheBody(gpa, try cache_file.reader().readStruct(Zir.Header), cache_file);
}

fn loadZirCacheBody(gpa: Allocator, header: Zir.Header, cache_file: std.fs.File) !Zir {
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

/// This is called from the AstGen thread pool, so must acquire
/// the Compilation mutex when acting on shared state.
fn updateZirRefs(zcu: *Module, file: *File, old_zir: Zir) !void {
    const gpa = zcu.gpa;
    const new_zir = file.zir;

    var inst_map: std.AutoHashMapUnmanaged(Zir.Inst.Index, Zir.Inst.Index) = .{};
    defer inst_map.deinit(gpa);

    try mapOldZirToNew(gpa, old_zir, new_zir, &inst_map);

    const old_tag = old_zir.instructions.items(.tag);
    const old_data = old_zir.instructions.items(.data);

    // TODO: this should be done after all AstGen workers complete, to avoid
    // iterating over this full set for every updated file.
    for (zcu.intern_pool.tracked_insts.keys(), 0..) |*ti, idx_raw| {
        const ti_idx: InternPool.TrackedInst.Index = @enumFromInt(idx_raw);
        if (!std.mem.eql(u8, &ti.path_digest, &file.path_digest)) continue;
        const old_inst = ti.inst;
        ti.inst = inst_map.get(ti.inst) orelse {
            // Tracking failed for this instruction. Invalidate associated `src_hash` deps.
            zcu.comp.mutex.lock();
            defer zcu.comp.mutex.unlock();
            log.debug("tracking failed for %{d}", .{old_inst});
            try zcu.markDependeeOutdated(.{ .src_hash = ti_idx });
            continue;
        };

        if (old_zir.getAssociatedSrcHash(old_inst)) |old_hash| hash_changed: {
            if (new_zir.getAssociatedSrcHash(ti.inst)) |new_hash| {
                if (std.zig.srcHashEql(old_hash, new_hash)) {
                    break :hash_changed;
                }
                log.debug("hash for (%{d} -> %{d}) changed: {} -> {}", .{
                    old_inst,
                    ti.inst,
                    std.fmt.fmtSliceHexLower(&old_hash),
                    std.fmt.fmtSliceHexLower(&new_hash),
                });
            }
            // The source hash associated with this instruction changed - invalidate relevant dependencies.
            zcu.comp.mutex.lock();
            defer zcu.comp.mutex.unlock();
            try zcu.markDependeeOutdated(.{ .src_hash = ti_idx });
        }

        // If this is a `struct_decl` etc, we must invalidate any outdated namespace dependencies.
        const has_namespace = switch (old_tag[@intFromEnum(old_inst)]) {
            .extended => switch (old_data[@intFromEnum(old_inst)].extended.opcode) {
                .struct_decl, .union_decl, .opaque_decl, .enum_decl => true,
                else => false,
            },
            else => false,
        };
        if (!has_namespace) continue;

        var old_names: std.AutoArrayHashMapUnmanaged(InternPool.NullTerminatedString, void) = .{};
        defer old_names.deinit(zcu.gpa);
        {
            var it = old_zir.declIterator(old_inst);
            while (it.next()) |decl_inst| {
                const decl_name = old_zir.getDeclaration(decl_inst)[0].name;
                switch (decl_name) {
                    .@"comptime", .@"usingnamespace", .unnamed_test, .decltest => continue,
                    _ => if (decl_name.isNamedTest(old_zir)) continue,
                }
                const name_zir = decl_name.toString(old_zir).?;
                const name_ip = try zcu.intern_pool.getOrPutString(
                    zcu.gpa,
                    old_zir.nullTerminatedString(name_zir),
                    .no_embedded_nulls,
                );
                try old_names.put(zcu.gpa, name_ip, {});
            }
        }
        var any_change = false;
        {
            var it = new_zir.declIterator(ti.inst);
            while (it.next()) |decl_inst| {
                const decl_name = old_zir.getDeclaration(decl_inst)[0].name;
                switch (decl_name) {
                    .@"comptime", .@"usingnamespace", .unnamed_test, .decltest => continue,
                    _ => if (decl_name.isNamedTest(old_zir)) continue,
                }
                const name_zir = decl_name.toString(old_zir).?;
                const name_ip = try zcu.intern_pool.getOrPutString(
                    zcu.gpa,
                    old_zir.nullTerminatedString(name_zir),
                    .no_embedded_nulls,
                );
                if (!old_names.swapRemove(name_ip)) continue;
                // Name added
                any_change = true;
                zcu.comp.mutex.lock();
                defer zcu.comp.mutex.unlock();
                try zcu.markDependeeOutdated(.{ .namespace_name = .{
                    .namespace = ti_idx,
                    .name = name_ip,
                } });
            }
        }
        // The only elements remaining in `old_names` now are any names which were removed.
        for (old_names.keys()) |name_ip| {
            any_change = true;
            zcu.comp.mutex.lock();
            defer zcu.comp.mutex.unlock();
            try zcu.markDependeeOutdated(.{ .namespace_name = .{
                .namespace = ti_idx,
                .name = name_ip,
            } });
        }

        if (any_change) {
            zcu.comp.mutex.lock();
            defer zcu.comp.mutex.unlock();
            try zcu.markDependeeOutdated(.{ .namespace = ti_idx });
        }
    }
}

pub fn markDependeeOutdated(zcu: *Zcu, dependee: InternPool.Dependee) !void {
    log.debug("outdated dependee: {}", .{dependee});
    var it = zcu.intern_pool.dependencyIterator(dependee);
    while (it.next()) |depender| {
        if (zcu.outdated.contains(depender)) {
            // We do not need to increment the PO dep count, as if the outdated
            // dependee is a Decl, we had already marked this as PO.
            continue;
        }
        const opt_po_entry = zcu.potentially_outdated.fetchSwapRemove(depender);
        try zcu.outdated.putNoClobber(
            zcu.gpa,
            depender,
            // We do not need to increment this count for the same reason as above.
            if (opt_po_entry) |e| e.value else 0,
        );
        log.debug("outdated: {}", .{depender});
        if (opt_po_entry == null) {
            // This is a new entry with no PO dependencies.
            try zcu.outdated_ready.put(zcu.gpa, depender, {});
        }
        // If this is a Decl and was not previously PO, we must recursively
        // mark dependencies on its tyval as PO.
        if (opt_po_entry == null) {
            try zcu.markTransitiveDependersPotentiallyOutdated(depender);
        }
    }
}

fn markPoDependeeUpToDate(zcu: *Zcu, dependee: InternPool.Dependee) !void {
    var it = zcu.intern_pool.dependencyIterator(dependee);
    while (it.next()) |depender| {
        if (zcu.outdated.getPtr(depender)) |po_dep_count| {
            // This depender is already outdated, but it now has one
            // less PO dependency!
            po_dep_count.* -= 1;
            if (po_dep_count.* == 0) {
                try zcu.outdated_ready.put(zcu.gpa, depender, {});
            }
            continue;
        }
        // This depender is definitely at least PO, because this Decl was just analyzed
        // due to being outdated.
        const ptr = zcu.potentially_outdated.getPtr(depender).?;
        if (ptr.* > 1) {
            ptr.* -= 1;
            continue;
        }

        // This dependency is no longer PO, i.e. is known to be up-to-date.
        assert(zcu.potentially_outdated.swapRemove(depender));
        // If this is a Decl, we must recursively mark dependencies on its tyval
        // as no longer PO.
        switch (depender.unwrap()) {
            .decl => |decl_index| try zcu.markPoDependeeUpToDate(.{ .decl_val = decl_index }),
            .func => |func_index| try zcu.markPoDependeeUpToDate(.{ .func_ies = func_index }),
        }
    }
}

/// Given a Depender which is newly outdated or PO, mark all Dependers which may
/// in turn be PO, due to a dependency on the original Depender's tyval or IES.
fn markTransitiveDependersPotentiallyOutdated(zcu: *Zcu, maybe_outdated: InternPool.Depender) !void {
    var it = zcu.intern_pool.dependencyIterator(switch (maybe_outdated.unwrap()) {
        .decl => |decl_index| .{ .decl_val = decl_index }, // TODO: also `decl_ref` deps when introduced
        .func => |func_index| .{ .func_ies = func_index },
    });

    while (it.next()) |po| {
        if (zcu.outdated.getPtr(po)) |po_dep_count| {
            // This dependency is already outdated, but it now has one more PO
            // dependency.
            if (po_dep_count.* == 0) {
                _ = zcu.outdated_ready.swapRemove(po);
            }
            po_dep_count.* += 1;
            continue;
        }
        if (zcu.potentially_outdated.getPtr(po)) |n| {
            // There is now one more PO dependency.
            n.* += 1;
            continue;
        }
        try zcu.potentially_outdated.putNoClobber(zcu.gpa, po, 1);
        // This Depender was not already PO, so we must recursively mark its dependers as also PO.
        try zcu.markTransitiveDependersPotentiallyOutdated(po);
    }
}

pub fn findOutdatedToAnalyze(zcu: *Zcu) Allocator.Error!?InternPool.Depender {
    if (!zcu.comp.debug_incremental) return null;

    if (zcu.outdated.count() == 0 and zcu.potentially_outdated.count() == 0) {
        log.debug("findOutdatedToAnalyze: no outdated depender", .{});
        return null;
    }

    // Our goal is to find an outdated Depender which itself has no outdated or
    // PO dependencies. Most of the time, such a Depender will exist - we track
    // them in the `outdated_ready` set for efficiency. However, this is not
    // necessarily the case, since the Decl dependency graph may contain loops
    // via mutually recursive definitions:
    //   pub const A = struct { b: *B };
    //   pub const B = struct { b: *A };
    // In this case, we must defer to more complex logic below.

    if (zcu.outdated_ready.count() > 0) {
        log.debug("findOutdatedToAnalyze: trivial '{s} {d}'", .{
            @tagName(zcu.outdated_ready.keys()[0].unwrap()),
            switch (zcu.outdated_ready.keys()[0].unwrap()) {
                inline else => |x| @intFromEnum(x),
            },
        });
        return zcu.outdated_ready.keys()[0];
    }

    // Next, we will see if there is any outdated file root which was not in
    // `outdated`. This set will be small (number of files changed in this
    // update), so it's alright for us to just iterate here.
    for (zcu.outdated_file_root.keys()) |file_decl| {
        const decl_depender = InternPool.Depender.wrap(.{ .decl = file_decl });
        if (zcu.outdated.contains(decl_depender)) {
            // Since we didn't hit this in the first loop, this Decl must have
            // pending dependencies, so is ineligible.
            continue;
        }
        if (zcu.potentially_outdated.contains(decl_depender)) {
            // This Decl's struct may or may not need to be recreated depending
            // on whether it is outdated. If we analyzed it now, we would have
            // to assume it was outdated and recreate it!
            continue;
        }
        log.debug("findOutdatedToAnalyze: outdated file root decl '{d}'", .{file_decl});
        return decl_depender;
    }

    // There is no single Depender which is ready for re-analysis. Instead, we
    // must assume that some Decl with PO dependencies is outdated - e.g. in the
    // above example we arbitrarily pick one of A or B. We should select a Decl,
    // since a Decl is definitely responsible for the loop in the dependency
    // graph (since you can't depend on a runtime function analysis!).

    // The choice of this Decl could have a big impact on how much total
    // analysis we perform, since if analysis concludes its tyval is unchanged,
    // then other PO Dependers may be resolved as up-to-date. To hopefully avoid
    // doing too much work, let's find a Decl which the most things depend on -
    // the idea is that this will resolve a lot of loops (but this is only a
    // heuristic).

    log.debug("findOutdatedToAnalyze: no trivial ready, using heuristic; {d} outdated, {d} PO", .{
        zcu.outdated.count(),
        zcu.potentially_outdated.count(),
    });

    var chosen_decl_idx: ?Decl.Index = null;
    var chosen_decl_dependers: u32 = undefined;

    for (zcu.outdated.keys()) |depender| {
        const decl_index = switch (depender.unwrap()) {
            .decl => |d| d,
            .func => continue,
        };

        var n: u32 = 0;
        var it = zcu.intern_pool.dependencyIterator(.{ .decl_val = decl_index });
        while (it.next()) |_| n += 1;

        if (chosen_decl_idx == null or n > chosen_decl_dependers) {
            chosen_decl_idx = decl_index;
            chosen_decl_dependers = n;
        }
    }

    for (zcu.potentially_outdated.keys()) |depender| {
        const decl_index = switch (depender.unwrap()) {
            .decl => |d| d,
            .func => continue,
        };

        var n: u32 = 0;
        var it = zcu.intern_pool.dependencyIterator(.{ .decl_val = decl_index });
        while (it.next()) |_| n += 1;

        if (chosen_decl_idx == null or n > chosen_decl_dependers) {
            chosen_decl_idx = decl_index;
            chosen_decl_dependers = n;
        }
    }

    log.debug("findOutdatedToAnalyze: heuristic returned Decl {d} ({d} dependers)", .{
        chosen_decl_idx.?,
        chosen_decl_dependers,
    });

    return InternPool.Depender.wrap(.{ .decl = chosen_decl_idx.? });
}

/// During an incremental update, before semantic analysis, call this to flush all values from
/// `retryable_failures` and mark them as outdated so they get re-analyzed.
pub fn flushRetryableFailures(zcu: *Zcu) !void {
    const gpa = zcu.gpa;
    for (zcu.retryable_failures.items) |depender| {
        if (zcu.outdated.contains(depender)) continue;
        if (zcu.potentially_outdated.fetchSwapRemove(depender)) |kv| {
            // This Depender was already PO, but we now consider it outdated.
            // Any transitive dependencies are already marked PO.
            try zcu.outdated.put(gpa, depender, kv.value);
            continue;
        }
        // This Depender was not marked PO, but is now outdated. Mark it as
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
    var match_stack: ArrayListUnmanaged(MatchedZirDecl) = .{};
    defer match_stack.deinit(gpa);

    // Main struct inst is always matched
    try match_stack.append(gpa, .{
        .old_inst = .main_struct_inst,
        .new_inst = .main_struct_inst,
    });

    // Used as temporary buffers for namespace declaration instructions
    var old_decls = std.ArrayList(Zir.Inst.Index).init(gpa);
    defer old_decls.deinit();
    var new_decls = std.ArrayList(Zir.Inst.Index).init(gpa);
    defer new_decls.deinit();

    while (match_stack.popOrNull()) |match_item| {
        // Match the namespace declaration itself
        try inst_map.put(gpa, match_item.old_inst, match_item.new_inst);

        // Maps decl name to `declaration` instruction.
        var named_decls: std.StringHashMapUnmanaged(Zir.Inst.Index) = .{};
        defer named_decls.deinit(gpa);
        // Maps test name to `declaration` instruction.
        var named_tests: std.StringHashMapUnmanaged(Zir.Inst.Index) = .{};
        defer named_tests.deinit(gpa);
        // All unnamed tests, in order, for a best-effort match.
        var unnamed_tests: std.ArrayListUnmanaged(Zir.Inst.Index) = .{};
        defer unnamed_tests.deinit(gpa);
        // All comptime declarations, in order, for a best-effort match.
        var comptime_decls: std.ArrayListUnmanaged(Zir.Inst.Index) = .{};
        defer comptime_decls.deinit(gpa);
        // All usingnamespace declarations, in order, for a best-effort match.
        var usingnamespace_decls: std.ArrayListUnmanaged(Zir.Inst.Index) = .{};
        defer usingnamespace_decls.deinit(gpa);

        {
            var old_decl_it = old_zir.declIterator(match_item.old_inst);
            while (old_decl_it.next()) |old_decl_inst| {
                const old_decl, _ = old_zir.getDeclaration(old_decl_inst);
                switch (old_decl.name) {
                    .@"comptime" => try comptime_decls.append(gpa, old_decl_inst),
                    .@"usingnamespace" => try usingnamespace_decls.append(gpa, old_decl_inst),
                    .unnamed_test, .decltest => try unnamed_tests.append(gpa, old_decl_inst),
                    _ => {
                        const name_nts = old_decl.name.toString(old_zir).?;
                        const name = old_zir.nullTerminatedString(name_nts);
                        if (old_decl.name.isNamedTest(old_zir)) {
                            try named_tests.put(gpa, name, old_decl_inst);
                        } else {
                            try named_decls.put(gpa, name, old_decl_inst);
                        }
                    },
                }
            }
        }

        var unnamed_test_idx: u32 = 0;
        var comptime_decl_idx: u32 = 0;
        var usingnamespace_decl_idx: u32 = 0;

        var new_decl_it = new_zir.declIterator(match_item.new_inst);
        while (new_decl_it.next()) |new_decl_inst| {
            const new_decl, _ = new_zir.getDeclaration(new_decl_inst);
            // Attempt to match this to a declaration in the old ZIR:
            // * For named declarations (`const`/`var`/`fn`), we match based on name.
            // * For named tests (`test "foo"`), we also match based on name.
            // * For unnamed tests and decltests, we match based on order.
            // * For comptime blocks, we match based on order.
            // * For usingnamespace decls, we match based on order.
            // If we cannot match this declaration, we can't match anything nested inside of it either, so we just `continue`.
            const old_decl_inst = switch (new_decl.name) {
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
                .unnamed_test, .decltest => inst: {
                    if (unnamed_test_idx == unnamed_tests.items.len) continue;
                    defer unnamed_test_idx += 1;
                    break :inst unnamed_tests.items[unnamed_test_idx];
                },
                _ => inst: {
                    const name_nts = new_decl.name.toString(old_zir).?;
                    const name = new_zir.nullTerminatedString(name_nts);
                    if (new_decl.name.isNamedTest(new_zir)) {
                        break :inst named_tests.get(name) orelse continue;
                    } else {
                        break :inst named_decls.get(name) orelse continue;
                    }
                },
            };

            // Match the `declaration` instruction
            try inst_map.put(gpa, old_decl_inst, new_decl_inst);

            // Find namespace declarations within this declaration
            try old_zir.findDecls(&old_decls, old_decl_inst);
            try new_zir.findDecls(&new_decls, new_decl_inst);

            // We don't have any smart way of matching up these namespace declarations, so we always
            // correlate them based on source order.
            const n = @min(old_decls.items.len, new_decls.items.len);
            try match_stack.ensureUnusedCapacity(gpa, n);
            for (old_decls.items[0..n], new_decls.items[0..n]) |old_inst, new_inst| {
                match_stack.appendAssumeCapacity(.{ .old_inst = old_inst, .new_inst = new_inst });
            }
        }
    }
}

/// Like `ensureDeclAnalyzed`, but the Decl is a file's root Decl.
pub fn ensureFileAnalyzed(zcu: *Zcu, file: *File) SemaError!void {
    if (file.root_decl.unwrap()) |existing_root| {
        return zcu.ensureDeclAnalyzed(existing_root);
    } else {
        return zcu.semaFile(file);
    }
}

/// This ensures that the Decl will have an up-to-date Type and Value populated.
/// However the resolution status of the Type may not be fully resolved.
/// For example an inferred error set is not resolved until after `analyzeFnBody`.
/// is called.
pub fn ensureDeclAnalyzed(mod: *Module, decl_index: Decl.Index) SemaError!void {
    const tracy = trace(@src());
    defer tracy.end();

    const decl = mod.declPtr(decl_index);

    log.debug("ensureDeclAnalyzed '{d}' (name '{}')", .{
        @intFromEnum(decl_index),
        decl.name.fmt(&mod.intern_pool),
    });

    // Determine whether or not this Decl is outdated, i.e. requires re-analysis
    // even if `complete`. If a Decl is PO, we pessismistically assume that it
    // *does* require re-analysis, to ensure that the Decl is definitely
    // up-to-date when this function returns.

    // If analysis occurs in a poor order, this could result in over-analysis.
    // We do our best to avoid this by the other dependency logic in this file
    // which tries to limit re-analysis to Decls whose previously listed
    // dependencies are all up-to-date.

    const decl_as_depender = InternPool.Depender.wrap(.{ .decl = decl_index });
    const decl_was_outdated = mod.outdated.swapRemove(decl_as_depender) or
        mod.potentially_outdated.swapRemove(decl_as_depender);

    if (decl_was_outdated) {
        _ = mod.outdated_ready.swapRemove(decl_as_depender);
    }

    const was_outdated = mod.outdated_file_root.swapRemove(decl_index) or decl_was_outdated;

    switch (decl.analysis) {
        .in_progress => unreachable,

        .file_failure => return error.AnalysisFail,

        .sema_failure,
        .dependency_failure,
        .codegen_failure,
        => if (!was_outdated) return error.AnalysisFail,

        .complete => if (!was_outdated) return,

        .unreferenced => {},
    }

    if (was_outdated) {
        // The exports this Decl performs will be re-discovered, so we remove them here
        // prior to re-analysis.
        if (build_options.only_c) unreachable;
        try mod.deleteDeclExports(decl_index);
    }

    var decl_prog_node = mod.sema_prog_node.start("", 0);
    decl_prog_node.activate();
    defer decl_prog_node.end();

    const sema_result: SemaDeclResult = blk: {
        if (decl.zir_decl_index == .none and !mod.declIsRoot(decl_index)) {
            // Anonymous decl. We don't semantically analyze these.
            break :blk .{
                .invalidate_decl_val = false,
                .invalidate_decl_ref = false,
            };
        }

        if (mod.declIsRoot(decl_index)) {
            const changed = try mod.semaFileUpdate(decl.getFileScope(mod), decl_was_outdated);
            break :blk .{
                .invalidate_decl_val = changed,
                .invalidate_decl_ref = changed,
            };
        }

        break :blk mod.semaDecl(decl_index) catch |err| switch (err) {
            error.AnalysisFail => {
                if (decl.analysis == .in_progress) {
                    // If this decl caused the compile error, the analysis field would
                    // be changed to indicate it was this Decl's fault. Because this
                    // did not happen, we infer here that it was a dependency failure.
                    decl.analysis = .dependency_failure;
                }
                return error.AnalysisFail;
            },
            error.NeededSourceLocation => unreachable,
            error.GenericPoison => unreachable,
            else => |e| {
                decl.analysis = .sema_failure;
                try mod.failed_decls.ensureUnusedCapacity(mod.gpa, 1);
                try mod.retryable_failures.append(mod.gpa, InternPool.Depender.wrap(.{ .decl = decl_index }));
                mod.failed_decls.putAssumeCapacityNoClobber(decl_index, try ErrorMsg.create(
                    mod.gpa,
                    decl.srcLoc(mod),
                    "unable to analyze: {s}",
                    .{@errorName(e)},
                ));
                return error.AnalysisFail;
            },
        };
    };

    // TODO: we do not yet have separate dependencies for decl values vs types.
    if (decl_was_outdated) {
        if (sema_result.invalidate_decl_val or sema_result.invalidate_decl_ref) {
            log.debug("Decl tv invalidated ('{d}')", .{@intFromEnum(decl_index)});
            // This dependency was marked as PO, meaning dependees were waiting
            // on its analysis result, and it has turned out to be outdated.
            // Update dependees accordingly.
            try mod.markDependeeOutdated(.{ .decl_val = decl_index });
        } else {
            log.debug("Decl tv up-to-date ('{d}')", .{@intFromEnum(decl_index)});
            // This dependency was previously PO, but turned out to be up-to-date.
            // We do not need to queue successive analysis.
            try mod.markPoDependeeUpToDate(.{ .decl_val = decl_index });
        }
    }
}

pub fn ensureFuncBodyAnalyzed(zcu: *Zcu, maybe_coerced_func_index: InternPool.Index) SemaError!void {
    const tracy = trace(@src());
    defer tracy.end();

    const gpa = zcu.gpa;
    const ip = &zcu.intern_pool;

    // We only care about the uncoerced function.
    // We need to do this for the "orphaned function" check below to be valid.
    const func_index = ip.unwrapCoercedFunc(maybe_coerced_func_index);

    const func = zcu.funcInfo(maybe_coerced_func_index);
    const decl_index = func.owner_decl;
    const decl = zcu.declPtr(decl_index);

    log.debug("ensureFuncBodyAnalyzed '{d}' (instance of '{}')", .{
        @intFromEnum(func_index),
        decl.name.fmt(ip),
    });

    // First, our owner decl must be up-to-date. This will always be the case
    // during the first update, but may not on successive updates if we happen
    // to get analyzed before our parent decl.
    try zcu.ensureDeclAnalyzed(decl_index);

    // On an update, it's possible this function changed such that our owner
    // decl now refers to a different function, making this one orphaned. If
    // that's the case, we should remove this function from the binary.
    if (decl.val.ip_index != func_index) {
        try zcu.markDependeeOutdated(.{ .func_ies = func_index });
        ip.removeDependenciesForDepender(gpa, InternPool.Depender.wrap(.{ .func = func_index }));
        ip.remove(func_index);
        @panic("TODO: remove orphaned function from binary");
    }

    // We'll want to remember what the IES used to be before the update for
    // dependency invalidation purposes.
    const old_resolved_ies = if (func.analysis(ip).inferred_error_set)
        func.resolvedErrorSet(ip).*
    else
        .none;

    switch (decl.analysis) {
        .unreferenced => unreachable,
        .in_progress => unreachable,

        .codegen_failure => unreachable, // functions do not perform constant value generation

        .file_failure,
        .sema_failure,
        .dependency_failure,
        => return error.AnalysisFail,

        .complete => {},
    }

    const func_as_depender = InternPool.Depender.wrap(.{ .func = func_index });
    const was_outdated = zcu.outdated.swapRemove(func_as_depender) or
        zcu.potentially_outdated.swapRemove(func_as_depender);

    if (was_outdated) {
        _ = zcu.outdated_ready.swapRemove(func_as_depender);
    }

    switch (func.analysis(ip).state) {
        .success => if (!was_outdated) return,
        .sema_failure,
        .dependency_failure,
        .codegen_failure,
        => if (!was_outdated) return error.AnalysisFail,
        .none, .queued => {},
        .in_progress => unreachable,
        .inline_only => unreachable, // don't queue work for this
    }

    log.debug("analyze and generate fn body '{d}'; reason='{s}'", .{
        @intFromEnum(func_index),
        if (was_outdated) "outdated" else "never analyzed",
    });

    var tmp_arena = std.heap.ArenaAllocator.init(gpa);
    defer tmp_arena.deinit();
    const sema_arena = tmp_arena.allocator();

    var air = zcu.analyzeFnBody(func_index, sema_arena) catch |err| switch (err) {
        error.AnalysisFail => {
            if (func.analysis(ip).state == .in_progress) {
                // If this decl caused the compile error, the analysis field would
                // be changed to indicate it was this Decl's fault. Because this
                // did not happen, we infer here that it was a dependency failure.
                func.analysis(ip).state = .dependency_failure;
            }
            return error.AnalysisFail;
        },
        error.OutOfMemory => return error.OutOfMemory,
    };
    defer air.deinit(gpa);

    const invalidate_ies_deps = i: {
        if (!was_outdated) break :i false;
        if (!func.analysis(ip).inferred_error_set) break :i true;
        const new_resolved_ies = func.resolvedErrorSet(ip).*;
        break :i new_resolved_ies != old_resolved_ies;
    };
    if (invalidate_ies_deps) {
        log.debug("func IES invalidated ('{d}')", .{@intFromEnum(func_index)});
        try zcu.markDependeeOutdated(.{ .func_ies = func_index });
    } else if (was_outdated) {
        log.debug("func IES up-to-date ('{d}')", .{@intFromEnum(func_index)});
        try zcu.markPoDependeeUpToDate(.{ .func_ies = func_index });
    }

    const comp = zcu.comp;

    const dump_air = build_options.enable_debug_extensions and comp.verbose_air;
    const dump_llvm_ir = build_options.enable_debug_extensions and (comp.verbose_llvm_ir != null or comp.verbose_llvm_bc != null);

    if (comp.bin_file == null and zcu.llvm_object == null and !dump_air and !dump_llvm_ir) {
        return;
    }

    var liveness = try Liveness.analyze(gpa, air, ip);
    defer liveness.deinit(gpa);

    if (dump_air) {
        const fqn = try decl.fullyQualifiedName(zcu);
        std.debug.print("# Begin Function AIR: {}:\n", .{fqn.fmt(ip)});
        @import("print_air.zig").dump(zcu, air, liveness);
        std.debug.print("# End Function AIR: {}\n\n", .{fqn.fmt(ip)});
    }

    if (std.debug.runtime_safety) {
        var verify = Liveness.Verify{
            .gpa = gpa,
            .air = air,
            .liveness = liveness,
            .intern_pool = ip,
        };
        defer verify.deinit();

        verify.verify() catch |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            else => {
                try zcu.failed_decls.ensureUnusedCapacity(gpa, 1);
                zcu.failed_decls.putAssumeCapacityNoClobber(
                    decl_index,
                    try Module.ErrorMsg.create(
                        gpa,
                        decl.srcLoc(zcu),
                        "invalid liveness: {s}",
                        .{@errorName(err)},
                    ),
                );
                func.analysis(ip).state = .codegen_failure;
                return;
            },
        };
    }

    if (comp.bin_file) |lf| {
        lf.updateFunc(zcu, func_index, air, liveness) catch |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            error.AnalysisFail => {
                func.analysis(ip).state = .codegen_failure;
            },
            else => {
                try zcu.failed_decls.ensureUnusedCapacity(gpa, 1);
                zcu.failed_decls.putAssumeCapacityNoClobber(decl_index, try Module.ErrorMsg.create(
                    gpa,
                    decl.srcLoc(zcu),
                    "unable to codegen: {s}",
                    .{@errorName(err)},
                ));
                func.analysis(ip).state = .codegen_failure;
                try zcu.retryable_failures.append(zcu.gpa, InternPool.Depender.wrap(.{ .func = func_index }));
            },
        };
    } else if (zcu.llvm_object) |llvm_object| {
        if (build_options.only_c) unreachable;
        llvm_object.updateFunc(zcu, func_index, air, liveness) catch |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            error.AnalysisFail => {
                func.analysis(ip).state = .codegen_failure;
            },
        };
    }
}

/// Ensure this function's body is or will be analyzed and emitted. This should
/// be called whenever a potential runtime call of a function is seen.
///
/// The caller is responsible for ensuring the function decl itself is already
/// analyzed, and for ensuring it can exist at runtime (see
/// `sema.fnHasRuntimeBits`). This function does *not* guarantee that the body
/// will be analyzed when it returns: for that, see `ensureFuncBodyAnalyzed`.
pub fn ensureFuncBodyAnalysisQueued(mod: *Module, func_index: InternPool.Index) !void {
    const ip = &mod.intern_pool;
    const func = mod.funcInfo(func_index);
    const decl_index = func.owner_decl;
    const decl = mod.declPtr(decl_index);

    switch (decl.analysis) {
        .unreferenced => unreachable,
        .in_progress => unreachable,

        .file_failure,
        .sema_failure,
        .codegen_failure,
        .dependency_failure,
        // Analysis of the function Decl itself failed, but we've already
        // emitted an error for that. The callee doesn't need the function to be
        // analyzed right now, so its analysis can safely continue.
        => return,

        .complete => {},
    }

    assert(decl.has_tv);

    const func_as_depender = InternPool.Depender.wrap(.{ .func = func_index });
    const is_outdated = mod.outdated.contains(func_as_depender) or
        mod.potentially_outdated.contains(func_as_depender);

    switch (func.analysis(ip).state) {
        .none => {},
        .queued => return,
        // As above, we don't need to forward errors here.
        .sema_failure,
        .dependency_failure,
        .codegen_failure,
        .success,
        => if (!is_outdated) return,
        .in_progress => return,
        .inline_only => unreachable, // don't queue work for this
    }

    // Decl itself is safely analyzed, and body analysis is not yet queued

    try mod.comp.work_queue.writeItem(.{ .codegen_func = func_index });
    if (mod.emit_h != null) {
        // TODO: we ideally only want to do this if the function's type changed
        // since the last update
        try mod.comp.work_queue.writeItem(.{ .emit_h_decl = decl_index });
    }
    func.analysis(ip).state = .queued;
}

/// https://github.com/ziglang/zig/issues/14307
pub fn semaPkg(mod: *Module, pkg: *Package.Module) !void {
    const file = (try mod.importPkg(pkg)).file;
    if (file.root_decl == .none) {
        return mod.semaFile(file);
    }
}

fn getFileRootStruct(zcu: *Zcu, decl_index: Decl.Index, namespace_index: Namespace.Index, file: *File) Allocator.Error!InternPool.Index {
    const gpa = zcu.gpa;
    const ip = &zcu.intern_pool;
    const extended = file.zir.instructions.items(.data)[@intFromEnum(Zir.Inst.Index.main_struct_inst)].extended;
    assert(extended.opcode == .struct_decl);
    const small: Zir.Inst.StructDecl.Small = @bitCast(extended.small);
    assert(!small.has_captures_len);
    assert(!small.has_backing_int);
    assert(small.layout == .auto);
    var extra_index: usize = extended.operand + @typeInfo(Zir.Inst.StructDecl).Struct.fields.len;
    const fields_len = if (small.has_fields_len) blk: {
        const fields_len = file.zir.extra[extra_index];
        extra_index += 1;
        break :blk fields_len;
    } else 0;
    const decls_len = if (small.has_decls_len) blk: {
        const decls_len = file.zir.extra[extra_index];
        extra_index += 1;
        break :blk decls_len;
    } else 0;
    const decls = file.zir.bodySlice(extra_index, decls_len);
    extra_index += decls_len;

    const tracked_inst = try ip.trackZir(gpa, file, .main_struct_inst);
    const wip_ty = switch (try ip.getStructType(gpa, .{
        .layout = .auto,
        .fields_len = fields_len,
        .known_non_opv = small.known_non_opv,
        .requires_comptime = if (small.known_comptime_only) .yes else .unknown,
        .is_tuple = small.is_tuple,
        .any_comptime_fields = small.any_comptime_fields,
        .any_default_inits = small.any_default_inits,
        .inits_resolved = false,
        .any_aligned_fields = small.any_aligned_fields,
        .has_namespace = true,
        .key = .{ .declared = .{
            .zir_index = tracked_inst,
            .captures = &.{},
        } },
    })) {
        .existing => unreachable, // we wouldn't be analysing the file root if this type existed
        .wip => |wip| wip,
    };
    errdefer wip_ty.cancel(ip);

    if (zcu.comp.debug_incremental) {
        try ip.addDependency(
            gpa,
            InternPool.Depender.wrap(.{ .decl = decl_index }),
            .{ .src_hash = tracked_inst },
        );
    }

    const decl = zcu.declPtr(decl_index);
    decl.val = Value.fromInterned(wip_ty.index);
    decl.has_tv = true;
    decl.owns_tv = true;
    decl.analysis = .complete;

    try zcu.scanNamespace(namespace_index, decls, decl);

    return wip_ty.finish(ip, decl_index, namespace_index.toOptional());
}

/// Re-analyze the root Decl of a file on an incremental update.
/// If `type_outdated`, the struct type itself is considered outdated and is
/// reconstructed at a new InternPool index. Otherwise, the namespace is just
/// re-analyzed. Returns whether the decl's tyval was invalidated.
fn semaFileUpdate(zcu: *Zcu, file: *File, type_outdated: bool) SemaError!bool {
    const decl = zcu.declPtr(file.root_decl.unwrap().?);

    log.debug("semaFileUpdate mod={s} sub_file_path={s} type_outdated={}", .{
        file.mod.fully_qualified_name,
        file.sub_file_path,
        type_outdated,
    });

    if (file.status != .success_zir) {
        if (decl.analysis == .file_failure) {
            return false;
        } else {
            decl.analysis = .file_failure;
            return true;
        }
    }

    if (decl.analysis == .file_failure) {
        // No struct type currently exists. Create one!
        _ = try zcu.getFileRootStruct(file.root_decl.unwrap().?, decl.src_namespace, file);
        return true;
    }

    assert(decl.has_tv);
    assert(decl.owns_tv);

    if (type_outdated) {
        // Invalidate the existing type, reusing the decl and namespace.
        zcu.intern_pool.removeDependenciesForDepender(zcu.gpa, InternPool.Depender.wrap(.{ .decl = file.root_decl.unwrap().? }));
        zcu.intern_pool.remove(decl.val.toIntern());
        decl.val = undefined;
        _ = try zcu.getFileRootStruct(file.root_decl.unwrap().?, decl.src_namespace, file);
        return true;
    }

    // Only the struct's namespace is outdated.
    // Preserve the type - just scan the namespace again.

    const extended = file.zir.instructions.items(.data)[@intFromEnum(Zir.Inst.Index.main_struct_inst)].extended;
    const small: Zir.Inst.StructDecl.Small = @bitCast(extended.small);

    var extra_index: usize = extended.operand + @typeInfo(Zir.Inst.StructDecl).Struct.fields.len;
    extra_index += @intFromBool(small.has_fields_len);
    const decls_len = if (small.has_decls_len) blk: {
        const decls_len = file.zir.extra[extra_index];
        extra_index += 1;
        break :blk decls_len;
    } else 0;
    const decls = file.zir.bodySlice(extra_index, decls_len);

    if (!type_outdated) {
        try zcu.scanNamespace(decl.src_namespace, decls, decl);
    }

    return false;
}

/// Regardless of the file status, will create a `Decl` if none exists so that we can track
/// dependencies and re-analyze when the file becomes outdated.
fn semaFile(mod: *Module, file: *File) SemaError!void {
    const tracy = trace(@src());
    defer tracy.end();

    assert(file.root_decl == .none);

    const gpa = mod.gpa;
    log.debug("semaFile mod={s} sub_file_path={s}", .{
        file.mod.fully_qualified_name, file.sub_file_path,
    });

    // Because these three things each reference each other, `undefined`
    // placeholders are used before being set after the struct type gains an
    // InternPool index.
    const new_namespace_index = try mod.createNamespace(.{
        .parent = .none,
        .decl_index = undefined,
        .file_scope = file,
    });
    errdefer mod.destroyNamespace(new_namespace_index);

    const new_decl_index = try mod.allocateNewDecl(new_namespace_index, 0);
    const new_decl = mod.declPtr(new_decl_index);
    errdefer @panic("TODO error handling");

    file.root_decl = new_decl_index.toOptional();
    mod.namespacePtr(new_namespace_index).decl_index = new_decl_index;

    new_decl.name = try file.fullyQualifiedName(mod);
    new_decl.name_fully_qualified = true;
    new_decl.src_line = 0;
    new_decl.is_pub = true;
    new_decl.is_exported = false;
    new_decl.alignment = .none;
    new_decl.@"linksection" = .none;
    new_decl.analysis = .in_progress;

    if (file.status != .success_zir) {
        new_decl.analysis = .file_failure;
        return;
    }
    assert(file.zir_loaded);

    const struct_ty = try mod.getFileRootStruct(new_decl_index, new_namespace_index, file);
    errdefer mod.intern_pool.remove(struct_ty);

    switch (mod.comp.cache_use) {
        .whole => |whole| if (whole.cache_manifest) |man| {
            const source = file.getSource(gpa) catch |err| {
                try reportRetryableFileError(mod, file, "unable to load source: {s}", .{@errorName(err)});
                return error.AnalysisFail;
            };

            const resolved_path = std.fs.path.resolve(gpa, &.{
                file.mod.root.root_dir.path orelse ".",
                file.mod.root.sub_path,
                file.sub_file_path,
            }) catch |err| {
                try reportRetryableFileError(mod, file, "unable to resolve path: {s}", .{@errorName(err)});
                return error.AnalysisFail;
            };
            errdefer gpa.free(resolved_path);

            whole.cache_manifest_mutex.lock();
            defer whole.cache_manifest_mutex.unlock();
            try man.addFilePostContents(resolved_path, source.bytes, source.stat);
        },
        .incremental => {},
    }
}

const SemaDeclResult = packed struct {
    /// Whether the value of a `decl_val` of this Decl changed.
    invalidate_decl_val: bool,
    /// Whether the type of a `decl_ref` of this Decl changed.
    invalidate_decl_ref: bool,
};

fn semaDecl(mod: *Module, decl_index: Decl.Index) !SemaDeclResult {
    const tracy = trace(@src());
    defer tracy.end();

    const decl = mod.declPtr(decl_index);
    const ip = &mod.intern_pool;

    if (decl.getFileScope(mod).status != .success_zir) {
        return error.AnalysisFail;
    }

    assert(!mod.declIsRoot(decl_index));

    if (decl.zir_decl_index == .none and decl.owns_tv) {
        // We are re-analyzing an anonymous owner Decl (for a function or a namespace type).
        return mod.semaAnonOwnerDecl(decl_index);
    }

    log.debug("semaDecl '{d}'", .{@intFromEnum(decl_index)});
    log.debug("decl name '{}'", .{(try decl.fullyQualifiedName(mod)).fmt(ip)});
    defer blk: {
        log.debug("finish decl name '{}'", .{(decl.fullyQualifiedName(mod) catch break :blk).fmt(ip)});
    }

    const old_has_tv = decl.has_tv;
    // The following values are ignored if `!old_has_tv`
    const old_ty = if (old_has_tv) decl.typeOf(mod) else undefined;
    const old_val = decl.val;
    const old_align = decl.alignment;
    const old_linksection = decl.@"linksection";
    const old_addrspace = decl.@"addrspace";
    const old_is_inline = if (decl.getOwnedFunction(mod)) |prev_func|
        prev_func.analysis(ip).state == .inline_only
    else
        false;

    const decl_inst = decl.zir_decl_index.unwrap().?.resolve(ip);

    const gpa = mod.gpa;
    const zir = decl.getFileScope(mod).zir;

    const builtin_type_target_index: InternPool.Index = ip_index: {
        const std_mod = mod.std_mod;
        if (decl.getFileScope(mod).mod != std_mod) break :ip_index .none;
        // We're in the std module.
        const std_file = (try mod.importPkg(std_mod)).file;
        const std_decl = mod.declPtr(std_file.root_decl.unwrap().?);
        const std_namespace = std_decl.getInnerNamespace(mod).?;
        const builtin_str = try ip.getOrPutString(gpa, "builtin", .no_embedded_nulls);
        const builtin_decl = mod.declPtr(std_namespace.decls.getKeyAdapted(builtin_str, DeclAdapter{ .zcu = mod }) orelse break :ip_index .none);
        const builtin_namespace = builtin_decl.getInnerNamespaceIndex(mod).unwrap() orelse break :ip_index .none;
        if (decl.src_namespace != builtin_namespace) break :ip_index .none;
        // We're in builtin.zig. This could be a builtin we need to add to a specific InternPool index.
        for ([_][]const u8{
            "AtomicOrder",
            "AtomicRmwOp",
            "CallingConvention",
            "AddressSpace",
            "FloatMode",
            "ReduceOp",
            "CallModifier",
            "PrefetchOptions",
            "ExportOptions",
            "ExternOptions",
            "Type",
        }, [_]InternPool.Index{
            .atomic_order_type,
            .atomic_rmw_op_type,
            .calling_convention_type,
            .address_space_type,
            .float_mode_type,
            .reduce_op_type,
            .call_modifier_type,
            .prefetch_options_type,
            .export_options_type,
            .extern_options_type,
            .type_info_type,
        }) |type_name, type_ip| {
            if (decl.name.eqlSlice(type_name, ip)) break :ip_index type_ip;
        }
        break :ip_index .none;
    };

    mod.intern_pool.removeDependenciesForDepender(gpa, InternPool.Depender.wrap(.{ .decl = decl_index }));

    decl.analysis = .in_progress;

    var analysis_arena = std.heap.ArenaAllocator.init(gpa);
    defer analysis_arena.deinit();

    var comptime_err_ret_trace = std.ArrayList(SrcLoc).init(gpa);
    defer comptime_err_ret_trace.deinit();

    var sema: Sema = .{
        .mod = mod,
        .gpa = gpa,
        .arena = analysis_arena.allocator(),
        .code = zir,
        .owner_decl = decl,
        .owner_decl_index = decl_index,
        .func_index = .none,
        .func_is_naked = false,
        .fn_ret_ty = Type.void,
        .fn_ret_ty_ies = null,
        .owner_func_index = .none,
        .comptime_err_ret_trace = &comptime_err_ret_trace,
        .builtin_type_target_index = builtin_type_target_index,
    };
    defer sema.deinit();

    // Every Decl (other than file root Decls, which do not have a ZIR index) has a dependency on its own source.
    try sema.declareDependency(.{ .src_hash = try ip.trackZir(
        sema.gpa,
        decl.getFileScope(mod),
        decl_inst,
    ) });

    var block_scope: Sema.Block = .{
        .parent = null,
        .sema = &sema,
        .src_decl = decl_index,
        .namespace = decl.src_namespace,
        .instructions = .{},
        .inlining = null,
        .is_comptime = true,
    };
    defer block_scope.instructions.deinit(gpa);

    const decl_bodies = decl.zirBodies(mod);

    const result_ref = try sema.resolveInlineBody(&block_scope, decl_bodies.value_body, decl_inst);
    // We'll do some other bits with the Sema. Clear the type target index just
    // in case they analyze any type.
    sema.builtin_type_target_index = .none;
    const align_src: LazySrcLoc = .{ .node_offset_var_decl_align = 0 };
    const section_src: LazySrcLoc = .{ .node_offset_var_decl_section = 0 };
    const address_space_src: LazySrcLoc = .{ .node_offset_var_decl_addrspace = 0 };
    const ty_src: LazySrcLoc = .{ .node_offset_var_decl_ty = 0 };
    const init_src: LazySrcLoc = .{ .node_offset_var_decl_init = 0 };
    const decl_val = try sema.resolveFinalDeclValue(&block_scope, init_src, result_ref);
    const decl_ty = decl_val.typeOf(mod);

    // Note this resolves the type of the Decl, not the value; if this Decl
    // is a struct, for example, this resolves `type` (which needs no resolution),
    // not the struct itself.
    try sema.resolveTypeLayout(decl_ty);

    if (decl.kind == .@"usingnamespace") {
        if (!decl_ty.eql(Type.type, mod)) {
            return sema.fail(&block_scope, ty_src, "expected type, found {}", .{
                decl_ty.fmt(mod),
            });
        }
        const ty = decl_val.toType();
        if (ty.getNamespace(mod) == null) {
            return sema.fail(&block_scope, ty_src, "type {} has no namespace", .{ty.fmt(mod)});
        }

        decl.val = ty.toValue();
        decl.alignment = .none;
        decl.@"linksection" = .none;
        decl.has_tv = true;
        decl.owns_tv = false;
        decl.analysis = .complete;

        // TODO: usingnamespace cannot currently participate in incremental compilation
        return .{
            .invalidate_decl_val = true,
            .invalidate_decl_ref = true,
        };
    }

    var queue_linker_work = true;
    var is_func = false;
    var is_inline = false;
    switch (decl_val.toIntern()) {
        .generic_poison => unreachable,
        .unreachable_value => unreachable,
        else => switch (ip.indexToKey(decl_val.toIntern())) {
            .variable => |variable| {
                decl.owns_tv = variable.decl == decl_index;
                queue_linker_work = decl.owns_tv;
            },

            .extern_func => |extern_func| {
                decl.owns_tv = extern_func.decl == decl_index;
                queue_linker_work = decl.owns_tv;
                is_func = decl.owns_tv;
            },

            .func => |func| {
                decl.owns_tv = func.owner_decl == decl_index;
                queue_linker_work = false;
                is_inline = decl.owns_tv and decl_ty.fnCallingConvention(mod) == .Inline;
                is_func = decl.owns_tv;
            },

            else => {},
        },
    }

    decl.val = decl_val;
    // Function linksection, align, and addrspace were already set by Sema
    if (!is_func) {
        decl.alignment = blk: {
            const align_body = decl_bodies.align_body orelse break :blk .none;
            const align_ref = try sema.resolveInlineBody(&block_scope, align_body, decl_inst);
            break :blk try sema.analyzeAsAlign(&block_scope, align_src, align_ref);
        };
        decl.@"linksection" = blk: {
            const linksection_body = decl_bodies.linksection_body orelse break :blk .none;
            const linksection_ref = try sema.resolveInlineBody(&block_scope, linksection_body, decl_inst);
            const bytes = try sema.toConstString(&block_scope, section_src, linksection_ref, .{
                .needed_comptime_reason = "linksection must be comptime-known",
            });
            if (mem.indexOfScalar(u8, bytes, 0) != null) {
                return sema.fail(&block_scope, section_src, "linksection cannot contain null bytes", .{});
            } else if (bytes.len == 0) {
                return sema.fail(&block_scope, section_src, "linksection cannot be empty", .{});
            }
            break :blk try ip.getOrPutStringOpt(gpa, bytes, .no_embedded_nulls);
        };
        decl.@"addrspace" = blk: {
            const addrspace_ctx: Sema.AddressSpaceContext = switch (ip.indexToKey(decl_val.toIntern())) {
                .variable => .variable,
                .extern_func, .func => .function,
                else => .constant,
            };

            const target = sema.mod.getTarget();

            const addrspace_body = decl_bodies.addrspace_body orelse break :blk switch (addrspace_ctx) {
                .function => target_util.defaultAddressSpace(target, .function),
                .variable => target_util.defaultAddressSpace(target, .global_mutable),
                .constant => target_util.defaultAddressSpace(target, .global_constant),
                else => unreachable,
            };
            const addrspace_ref = try sema.resolveInlineBody(&block_scope, addrspace_body, decl_inst);
            break :blk try sema.analyzeAsAddressSpace(&block_scope, address_space_src, addrspace_ref, addrspace_ctx);
        };
    }
    decl.has_tv = true;
    decl.analysis = .complete;

    const result: SemaDeclResult = if (old_has_tv) .{
        .invalidate_decl_val = !decl_ty.eql(old_ty, mod) or
            !decl.val.eql(old_val, decl_ty, mod) or
            is_inline != old_is_inline,
        .invalidate_decl_ref = !decl_ty.eql(old_ty, mod) or
            decl.alignment != old_align or
            decl.@"linksection" != old_linksection or
            decl.@"addrspace" != old_addrspace or
            is_inline != old_is_inline,
    } else .{
        .invalidate_decl_val = true,
        .invalidate_decl_ref = true,
    };

    const has_runtime_bits = queue_linker_work and (is_func or try sema.typeHasRuntimeBits(decl_ty));
    if (has_runtime_bits) {
        // Needed for codegen_decl which will call updateDecl and then the
        // codegen backend wants full access to the Decl Type.
        try sema.resolveTypeFully(decl_ty);

        try mod.comp.work_queue.writeItem(.{ .codegen_decl = decl_index });

        if (result.invalidate_decl_ref and mod.emit_h != null) {
            try mod.comp.work_queue.writeItem(.{ .emit_h_decl = decl_index });
        }
    }

    if (decl.is_exported) {
        const export_src: LazySrcLoc = .{ .token_offset = @intFromBool(decl.is_pub) };
        if (is_inline) return sema.fail(&block_scope, export_src, "export of inline function", .{});
        // The scope needs to have the decl in it.
        try sema.analyzeExport(&block_scope, export_src, .{ .name = decl.name }, decl_index);
    }

    return result;
}

fn semaAnonOwnerDecl(zcu: *Zcu, decl_index: Decl.Index) !SemaDeclResult {
    const decl = zcu.declPtr(decl_index);

    assert(decl.has_tv);
    assert(decl.owns_tv);

    log.debug("semaAnonOwnerDecl '{d}'", .{@intFromEnum(decl_index)});

    switch (decl.typeOf(zcu).zigTypeTag(zcu)) {
        .Fn => @panic("TODO: update fn instance"),
        .Type => {},
        else => unreachable,
    }

    // We are the owner Decl of a type, and we were marked as outdated. That means the *structure*
    // of this type changed; not just its namespace. Therefore, we need a new InternPool index.
    //
    // However, as soon as we make that, the context that created us will require re-analysis anyway
    // (as it depends on this Decl's value), meaning the `struct_decl` (or equivalent) instruction
    // will be analyzed again. Since Sema already needs to be able to reconstruct types like this,
    // why should we bother implementing it here too when the Sema logic will be hit right after?
    //
    // So instead, let's just mark this Decl as failed - so that any remaining Decls which genuinely
    // reference it (via `@This`) end up silently erroring too - and we'll let Sema make a new type
    // with a new Decl.
    //
    // Yes, this does mean that any type owner Decl has a constant value for its entire lifetime.
    zcu.intern_pool.removeDependenciesForDepender(zcu.gpa, InternPool.Depender.wrap(.{ .decl = decl_index }));
    zcu.intern_pool.remove(decl.val.toIntern());
    decl.analysis = .dependency_failure;
    return .{
        .invalidate_decl_val = true,
        .invalidate_decl_ref = true,
    };
}

pub const ImportFileResult = struct {
    file: *File,
    is_new: bool,
    is_pkg: bool,
};

pub fn importPkg(zcu: *Zcu, mod: *Package.Module) !ImportFileResult {
    const gpa = zcu.gpa;

    // The resolved path is used as the key in the import table, to detect if
    // an import refers to the same as another, despite different relative paths
    // or differently mapped package names.
    const resolved_path = try std.fs.path.resolve(gpa, &.{
        mod.root.root_dir.path orelse ".",
        mod.root.sub_path,
        mod.root_src_path,
    });
    var keep_resolved_path = false;
    defer if (!keep_resolved_path) gpa.free(resolved_path);

    const gop = try zcu.import_table.getOrPut(gpa, resolved_path);
    errdefer _ = zcu.import_table.pop();
    if (gop.found_existing) {
        try gop.value_ptr.*.addReference(zcu.*, .{ .root = mod });
        return ImportFileResult{
            .file = gop.value_ptr.*,
            .is_new = false,
            .is_pkg = true,
        };
    }

    if (mod.builtin_file) |builtin_file| {
        keep_resolved_path = true; // It's now owned by import_table.
        gop.value_ptr.* = builtin_file;
        try builtin_file.addReference(zcu.*, .{ .root = mod });
        return .{
            .file = builtin_file,
            .is_new = false,
            .is_pkg = true,
        };
    }

    const sub_file_path = try gpa.dupe(u8, mod.root_src_path);
    errdefer gpa.free(sub_file_path);

    const new_file = try gpa.create(File);
    errdefer gpa.destroy(new_file);

    keep_resolved_path = true; // It's now owned by import_table.
    gop.value_ptr.* = new_file;
    new_file.* = .{
        .sub_file_path = sub_file_path,
        .source = undefined,
        .source_loaded = false,
        .tree_loaded = false,
        .zir_loaded = false,
        .stat = undefined,
        .tree = undefined,
        .zir = undefined,
        .status = .never_loaded,
        .mod = mod,
        .root_decl = .none,
    };
    try new_file.addReference(zcu.*, .{ .root = mod });
    return ImportFileResult{
        .file = new_file,
        .is_new = true,
        .is_pkg = true,
    };
}

pub fn importFile(
    mod: *Module,
    cur_file: *File,
    import_string: []const u8,
) !ImportFileResult {
    if (std.mem.eql(u8, import_string, "std")) {
        return mod.importPkg(mod.std_mod);
    }
    if (std.mem.eql(u8, import_string, "root")) {
        return mod.importPkg(mod.root_mod);
    }
    if (cur_file.mod.deps.get(import_string)) |pkg| {
        return mod.importPkg(pkg);
    }
    if (!mem.endsWith(u8, import_string, ".zig")) {
        return error.ModuleNotFound;
    }
    const gpa = mod.gpa;

    // The resolved path is used as the key in the import table, to detect if
    // an import refers to the same as another, despite different relative paths
    // or differently mapped package names.
    const resolved_path = try std.fs.path.resolve(gpa, &.{
        cur_file.mod.root.root_dir.path orelse ".",
        cur_file.mod.root.sub_path,
        cur_file.sub_file_path,
        "..",
        import_string,
    });

    var keep_resolved_path = false;
    defer if (!keep_resolved_path) gpa.free(resolved_path);

    const gop = try mod.import_table.getOrPut(gpa, resolved_path);
    errdefer _ = mod.import_table.pop();
    if (gop.found_existing) return ImportFileResult{
        .file = gop.value_ptr.*,
        .is_new = false,
        .is_pkg = false,
    };

    const new_file = try gpa.create(File);
    errdefer gpa.destroy(new_file);

    const resolved_root_path = try std.fs.path.resolve(gpa, &.{
        cur_file.mod.root.root_dir.path orelse ".",
        cur_file.mod.root.sub_path,
    });
    defer gpa.free(resolved_root_path);

    const sub_file_path = p: {
        const relative = try std.fs.path.relative(gpa, resolved_root_path, resolved_path);
        errdefer gpa.free(relative);

        if (!isUpDir(relative) and !std.fs.path.isAbsolute(relative)) {
            break :p relative;
        }
        return error.ImportOutsideModulePath;
    };
    errdefer gpa.free(sub_file_path);

    log.debug("new importFile. resolved_root_path={s}, resolved_path={s}, sub_file_path={s}, import_string={s}", .{
        resolved_root_path, resolved_path, sub_file_path, import_string,
    });

    keep_resolved_path = true; // It's now owned by import_table.
    gop.value_ptr.* = new_file;
    new_file.* = .{
        .sub_file_path = sub_file_path,
        .source = undefined,
        .source_loaded = false,
        .tree_loaded = false,
        .zir_loaded = false,
        .stat = undefined,
        .tree = undefined,
        .zir = undefined,
        .status = .never_loaded,
        .mod = cur_file.mod,
        .root_decl = .none,
    };
    return ImportFileResult{
        .file = new_file,
        .is_new = true,
        .is_pkg = false,
    };
}

pub fn embedFile(
    mod: *Module,
    cur_file: *File,
    import_string: []const u8,
    src_loc: SrcLoc,
) !InternPool.Index {
    const gpa = mod.gpa;

    if (cur_file.mod.deps.get(import_string)) |pkg| {
        const resolved_path = try std.fs.path.resolve(gpa, &.{
            pkg.root.root_dir.path orelse ".",
            pkg.root.sub_path,
            pkg.root_src_path,
        });
        var keep_resolved_path = false;
        defer if (!keep_resolved_path) gpa.free(resolved_path);

        const gop = try mod.embed_table.getOrPut(gpa, resolved_path);
        errdefer {
            assert(std.mem.eql(u8, mod.embed_table.pop().key, resolved_path));
            keep_resolved_path = false;
        }
        if (gop.found_existing) return gop.value_ptr.*.val;
        keep_resolved_path = true;

        const sub_file_path = try gpa.dupe(u8, pkg.root_src_path);
        errdefer gpa.free(sub_file_path);

        return newEmbedFile(mod, pkg, sub_file_path, resolved_path, gop.value_ptr, src_loc);
    }

    // The resolved path is used as the key in the table, to detect if a file
    // refers to the same as another, despite different relative paths.
    const resolved_path = try std.fs.path.resolve(gpa, &.{
        cur_file.mod.root.root_dir.path orelse ".",
        cur_file.mod.root.sub_path,
        cur_file.sub_file_path,
        "..",
        import_string,
    });

    var keep_resolved_path = false;
    defer if (!keep_resolved_path) gpa.free(resolved_path);

    const gop = try mod.embed_table.getOrPut(gpa, resolved_path);
    errdefer {
        assert(std.mem.eql(u8, mod.embed_table.pop().key, resolved_path));
        keep_resolved_path = false;
    }
    if (gop.found_existing) return gop.value_ptr.*.val;
    keep_resolved_path = true;

    const resolved_root_path = try std.fs.path.resolve(gpa, &.{
        cur_file.mod.root.root_dir.path orelse ".",
        cur_file.mod.root.sub_path,
    });
    defer gpa.free(resolved_root_path);

    const sub_file_path = p: {
        const relative = try std.fs.path.relative(gpa, resolved_root_path, resolved_path);
        errdefer gpa.free(relative);

        if (!isUpDir(relative) and !std.fs.path.isAbsolute(relative)) {
            break :p relative;
        }
        return error.ImportOutsideModulePath;
    };
    defer gpa.free(sub_file_path);

    return newEmbedFile(mod, cur_file.mod, sub_file_path, resolved_path, gop.value_ptr, src_loc);
}

/// https://github.com/ziglang/zig/issues/14307
fn newEmbedFile(
    mod: *Module,
    pkg: *Package.Module,
    sub_file_path: []const u8,
    resolved_path: []const u8,
    result: **EmbedFile,
    src_loc: SrcLoc,
) !InternPool.Index {
    const gpa = mod.gpa;
    const ip = &mod.intern_pool;

    const new_file = try gpa.create(EmbedFile);
    errdefer gpa.destroy(new_file);

    var file = try pkg.root.openFile(sub_file_path, .{});
    defer file.close();

    const actual_stat = try file.stat();
    const stat: Cache.File.Stat = .{
        .size = actual_stat.size,
        .inode = actual_stat.inode,
        .mtime = actual_stat.mtime,
    };
    const size = std.math.cast(usize, actual_stat.size) orelse return error.Overflow;

    const bytes = try ip.string_bytes.addManyAsSlice(gpa, try std.math.add(usize, size, 1));
    const actual_read = try file.readAll(bytes[0..size]);
    if (actual_read != size) return error.UnexpectedEndOfFile;
    bytes[size] = 0;

    const comp = mod.comp;
    switch (comp.cache_use) {
        .whole => |whole| if (whole.cache_manifest) |man| {
            const copied_resolved_path = try gpa.dupe(u8, resolved_path);
            errdefer gpa.free(copied_resolved_path);
            whole.cache_manifest_mutex.lock();
            defer whole.cache_manifest_mutex.unlock();
            try man.addFilePostContents(copied_resolved_path, bytes[0..size], stat);
        },
        .incremental => {},
    }

    const array_ty = try ip.get(gpa, .{ .array_type = .{
        .len = size,
        .sentinel = .zero_u8,
        .child = .u8_type,
    } });
    const array_val = try ip.get(gpa, .{ .aggregate = .{
        .ty = array_ty,
        .storage = .{ .bytes = try ip.getOrPutTrailingString(gpa, bytes.len, .maybe_embedded_nulls) },
    } });

    const ptr_ty = (try mod.ptrType(.{
        .child = array_ty,
        .flags = .{
            .alignment = .none,
            .is_const = true,
            .address_space = .generic,
        },
    })).toIntern();
    const ptr_val = try ip.get(gpa, .{ .ptr = .{
        .ty = ptr_ty,
        .base_addr = .{ .anon_decl = .{
            .val = array_val,
            .orig_ty = ptr_ty,
        } },
        .byte_offset = 0,
    } });

    result.* = new_file;
    new_file.* = .{
        .sub_file_path = try ip.getOrPutString(gpa, sub_file_path, .no_embedded_nulls),
        .owner = pkg,
        .stat = stat,
        .val = ptr_val,
        .src_loc = src_loc,
    };
    return ptr_val;
}

pub fn scanNamespace(
    zcu: *Zcu,
    namespace_index: Namespace.Index,
    decls: []const Zir.Inst.Index,
    parent_decl: *Decl,
) Allocator.Error!void {
    const tracy = trace(@src());
    defer tracy.end();

    const gpa = zcu.gpa;
    const namespace = zcu.namespacePtr(namespace_index);

    // For incremental updates, `scanDecl` wants to look up existing decls by their ZIR index rather
    // than their name. We'll build an efficient mapping now, then discard the current `decls`.
    var existing_by_inst: std.AutoHashMapUnmanaged(InternPool.TrackedInst.Index, Decl.Index) = .{};
    defer existing_by_inst.deinit(gpa);

    try existing_by_inst.ensureTotalCapacity(gpa, @intCast(namespace.decls.count()));

    for (namespace.decls.keys()) |decl_index| {
        const decl = zcu.declPtr(decl_index);
        existing_by_inst.putAssumeCapacityNoClobber(decl.zir_decl_index.unwrap().?, decl_index);
    }

    var seen_decls: std.AutoHashMapUnmanaged(InternPool.NullTerminatedString, void) = .{};
    defer seen_decls.deinit(gpa);

    try zcu.comp.work_queue.ensureUnusedCapacity(decls.len);

    namespace.decls.clearRetainingCapacity();
    try namespace.decls.ensureTotalCapacity(gpa, decls.len);

    namespace.usingnamespace_set.clearRetainingCapacity();

    var scan_decl_iter: ScanDeclIter = .{
        .zcu = zcu,
        .namespace_index = namespace_index,
        .parent_decl = parent_decl,
        .seen_decls = &seen_decls,
        .existing_by_inst = &existing_by_inst,
        .pass = .named,
    };
    for (decls) |decl_inst| {
        try scanDecl(&scan_decl_iter, decl_inst);
    }
    scan_decl_iter.pass = .unnamed;
    for (decls) |decl_inst| {
        try scanDecl(&scan_decl_iter, decl_inst);
    }

    if (seen_decls.count() != namespace.decls.count()) {
        // Do a pass over the namespace contents and remove any decls from the last update
        // which were removed in this one.
        var i: usize = 0;
        while (i < namespace.decls.count()) {
            const decl_index = namespace.decls.keys()[i];
            const decl = zcu.declPtr(decl_index);
            if (!seen_decls.contains(decl.name)) {
                // We must preserve namespace ordering for @typeInfo.
                namespace.decls.orderedRemoveAt(i);
                i -= 1;
            }
        }
    }
}

const ScanDeclIter = struct {
    zcu: *Zcu,
    namespace_index: Namespace.Index,
    parent_decl: *Decl,
    seen_decls: *std.AutoHashMapUnmanaged(InternPool.NullTerminatedString, void),
    existing_by_inst: *const std.AutoHashMapUnmanaged(InternPool.TrackedInst.Index, Decl.Index),
    /// Decl scanning is run in two passes, so that we can detect when a generated
    /// name would clash with an explicit name and use a different one.
    pass: enum { named, unnamed },
    usingnamespace_index: usize = 0,
    comptime_index: usize = 0,
    unnamed_test_index: usize = 0,

    fn avoidNameConflict(iter: *ScanDeclIter, comptime fmt: []const u8, args: anytype) !InternPool.NullTerminatedString {
        const zcu = iter.zcu;
        const gpa = zcu.gpa;
        const ip = &zcu.intern_pool;
        var name = try ip.getOrPutStringFmt(gpa, fmt, args, .no_embedded_nulls);
        var gop = try iter.seen_decls.getOrPut(gpa, name);
        var next_suffix: u32 = 0;
        while (gop.found_existing) {
            name = try ip.getOrPutStringFmt(gpa, "{}_{d}", .{ name.fmt(ip), next_suffix }, .no_embedded_nulls);
            gop = try iter.seen_decls.getOrPut(gpa, name);
            next_suffix += 1;
        }
        return name;
    }
};

fn scanDecl(iter: *ScanDeclIter, decl_inst: Zir.Inst.Index) Allocator.Error!void {
    const tracy = trace(@src());
    defer tracy.end();

    const zcu = iter.zcu;
    const namespace_index = iter.namespace_index;
    const namespace = zcu.namespacePtr(namespace_index);
    const gpa = zcu.gpa;
    const zir = namespace.file_scope.zir;
    const ip = &zcu.intern_pool;

    const pl_node = zir.instructions.items(.data)[@intFromEnum(decl_inst)].pl_node;
    const extra = zir.extraData(Zir.Inst.Declaration, pl_node.payload_index);
    const declaration = extra.data;

    const line = iter.parent_decl.src_line + declaration.line_offset;
    const decl_node = iter.parent_decl.relativeToNodeIndex(pl_node.src_node);

    // Every Decl needs a name.
    const decl_name: InternPool.NullTerminatedString, const kind: Decl.Kind, const is_named_test: bool = switch (declaration.name) {
        .@"comptime" => info: {
            if (iter.pass != .unnamed) return;
            const i = iter.comptime_index;
            iter.comptime_index += 1;
            break :info .{
                try iter.avoidNameConflict("comptime_{d}", .{i}),
                .@"comptime",
                false,
            };
        },
        .@"usingnamespace" => info: {
            // TODO: this isn't right! These should be considered unnamed. Name conflicts can happen here.
            // The problem is, we need to preserve the decl ordering for `@typeInfo`.
            // I'm not bothering to fix this now, since some upcoming changes will change this code significantly anyway.
            if (iter.pass != .named) return;
            const i = iter.usingnamespace_index;
            iter.usingnamespace_index += 1;
            break :info .{
                try iter.avoidNameConflict("usingnamespace_{d}", .{i}),
                .@"usingnamespace",
                false,
            };
        },
        .unnamed_test => info: {
            if (iter.pass != .unnamed) return;
            const i = iter.unnamed_test_index;
            iter.unnamed_test_index += 1;
            break :info .{
                try iter.avoidNameConflict("test_{d}", .{i}),
                .@"test",
                false,
            };
        },
        .decltest => info: {
            // We consider these to be unnamed since the decl name can be adjusted to avoid conflicts if necessary.
            if (iter.pass != .unnamed) return;
            assert(declaration.flags.has_doc_comment);
            const name = zir.nullTerminatedString(@enumFromInt(zir.extra[extra.end]));
            break :info .{
                try iter.avoidNameConflict("decltest.{s}", .{name}),
                .@"test",
                true,
            };
        },
        _ => if (declaration.name.isNamedTest(zir)) info: {
            // We consider these to be unnamed since the decl name can be adjusted to avoid conflicts if necessary.
            if (iter.pass != .unnamed) return;
            break :info .{
                try iter.avoidNameConflict("test.{s}", .{zir.nullTerminatedString(declaration.name.toString(zir).?)}),
                .@"test",
                true,
            };
        } else info: {
            if (iter.pass != .named) return;
            const name = try ip.getOrPutString(
                gpa,
                zir.nullTerminatedString(declaration.name.toString(zir).?),
                .no_embedded_nulls,
            );
            try iter.seen_decls.putNoClobber(gpa, name, {});
            break :info .{
                name,
                .named,
                false,
            };
        },
    };

    switch (kind) {
        .@"usingnamespace" => try namespace.usingnamespace_set.ensureUnusedCapacity(gpa, 1),
        .@"test" => try zcu.test_functions.ensureUnusedCapacity(gpa, 1),
        else => {},
    }

    const tracked_inst = try ip.trackZir(gpa, iter.parent_decl.getFileScope(zcu), decl_inst);

    // We create a Decl for it regardless of analysis status.

    const prev_exported, const decl_index = if (iter.existing_by_inst.get(tracked_inst)) |decl_index| decl_index: {
        // We need only update this existing Decl.
        const decl = zcu.declPtr(decl_index);
        const was_exported = decl.is_exported;
        assert(decl.kind == kind); // ZIR tracking should preserve this
        decl.name = decl_name;
        decl.src_node = decl_node;
        decl.src_line = line;
        decl.is_pub = declaration.flags.is_pub;
        decl.is_exported = declaration.flags.is_export;
        break :decl_index .{ was_exported, decl_index };
    } else decl_index: {
        // Create and set up a new Decl.
        const new_decl_index = try zcu.allocateNewDecl(namespace_index, decl_node);
        const new_decl = zcu.declPtr(new_decl_index);
        new_decl.kind = kind;
        new_decl.name = decl_name;
        new_decl.src_line = line;
        new_decl.is_pub = declaration.flags.is_pub;
        new_decl.is_exported = declaration.flags.is_export;
        new_decl.zir_decl_index = tracked_inst.toOptional();
        break :decl_index .{ false, new_decl_index };
    };

    const decl = zcu.declPtr(decl_index);

    namespace.decls.putAssumeCapacityNoClobberContext(decl_index, {}, .{ .zcu = zcu });

    const comp = zcu.comp;
    const decl_mod = namespace.file_scope.mod;
    const want_analysis = declaration.flags.is_export or switch (kind) {
        .anon => unreachable,
        .@"comptime" => true,
        .@"usingnamespace" => a: {
            namespace.usingnamespace_set.putAssumeCapacityNoClobber(decl_index, declaration.flags.is_pub);
            break :a true;
        },
        .named => false,
        .@"test" => a: {
            if (!comp.config.is_test) break :a false;
            if (decl_mod != zcu.main_mod) break :a false;
            if (is_named_test and comp.test_filters.len > 0) {
                const decl_fqn = try namespace.fullyQualifiedName(zcu, decl_name);
                const decl_fqn_slice = decl_fqn.toSlice(ip);
                for (comp.test_filters) |test_filter| {
                    if (mem.indexOf(u8, decl_fqn_slice, test_filter)) |_| break;
                } else break :a false;
            }
            zcu.test_functions.putAssumeCapacity(decl_index, {}); // may clobber on incremental update
            break :a true;
        },
    };

    if (want_analysis) {
        // We will not queue analysis if the decl has been analyzed on a previous update and
        // `is_export` is unchanged. In this case, the incremental update mechanism will handle
        // re-analysis for us if necessary.
        if (prev_exported != declaration.flags.is_export or decl.analysis == .unreferenced) {
            log.debug("scanDecl queue analyze_decl file='{s}' decl_name='{}' decl_index={d}", .{
                namespace.file_scope.sub_file_path, decl_name.fmt(ip), decl_index,
            });
            comp.work_queue.writeItemAssumeCapacity(.{ .analyze_decl = decl_index });
        }
    }

    if (decl.getOwnedFunction(zcu) != null) {
        // TODO this logic is insufficient; namespaces we don't re-scan may still require
        // updated line numbers. Look into this!
        // TODO Look into detecting when this would be unnecessary by storing enough state
        // in `Decl` to notice that the line number did not change.
        comp.work_queue.writeItemAssumeCapacity(.{ .update_line_number = decl_index });
    }
}

/// Cancel the creation of an anon decl and delete any references to it.
/// If other decls depend on this decl, they must be aborted first.
pub fn abortAnonDecl(mod: *Module, decl_index: Decl.Index) void {
    assert(!mod.declIsRoot(decl_index));
    mod.destroyDecl(decl_index);
}

/// Finalize the creation of an anon decl.
pub fn finalizeAnonDecl(mod: *Module, decl_index: Decl.Index) Allocator.Error!void {
    if (mod.declPtr(decl_index).typeOf(mod).isFnOrHasRuntimeBits(mod)) {
        try mod.comp.work_queue.writeItem(.{ .codegen_decl = decl_index });
    }
}

/// Delete all the Export objects that are caused by this Decl. Re-analysis of
/// this Decl will cause them to be re-created (or not).
fn deleteDeclExports(mod: *Module, decl_index: Decl.Index) Allocator.Error!void {
    var export_owners = (mod.export_owners.fetchSwapRemove(decl_index) orelse return).value;

    for (export_owners.items) |exp| {
        switch (exp.exported) {
            .decl_index => |exported_decl_index| {
                if (mod.decl_exports.getPtr(exported_decl_index)) |export_list| {
                    // Remove exports with owner_decl matching the regenerating decl.
                    const list = export_list.items;
                    var i: usize = 0;
                    var new_len = list.len;
                    while (i < new_len) {
                        if (list[i].owner_decl == decl_index) {
                            mem.copyBackwards(*Export, list[i..], list[i + 1 .. new_len]);
                            new_len -= 1;
                        } else {
                            i += 1;
                        }
                    }
                    export_list.shrinkAndFree(mod.gpa, new_len);
                    if (new_len == 0) {
                        assert(mod.decl_exports.swapRemove(exported_decl_index));
                    }
                }
            },
            .value => |value| {
                if (mod.value_exports.getPtr(value)) |export_list| {
                    // Remove exports with owner_decl matching the regenerating decl.
                    const list = export_list.items;
                    var i: usize = 0;
                    var new_len = list.len;
                    while (i < new_len) {
                        if (list[i].owner_decl == decl_index) {
                            mem.copyBackwards(*Export, list[i..], list[i + 1 .. new_len]);
                            new_len -= 1;
                        } else {
                            i += 1;
                        }
                    }
                    export_list.shrinkAndFree(mod.gpa, new_len);
                    if (new_len == 0) {
                        assert(mod.value_exports.swapRemove(value));
                    }
                }
            },
        }
        if (mod.comp.bin_file) |lf| {
            try lf.deleteDeclExport(decl_index, exp.opts.name);
        }
        if (mod.failed_exports.fetchSwapRemove(exp)) |failed_kv| {
            failed_kv.value.destroy(mod.gpa);
        }
        mod.gpa.destroy(exp);
    }
    export_owners.deinit(mod.gpa);
}

pub fn analyzeFnBody(mod: *Module, func_index: InternPool.Index, arena: Allocator) SemaError!Air {
    const tracy = trace(@src());
    defer tracy.end();

    const gpa = mod.gpa;
    const ip = &mod.intern_pool;
    const func = mod.funcInfo(func_index);
    const decl_index = func.owner_decl;
    const decl = mod.declPtr(decl_index);

    log.debug("func name '{}'", .{(try decl.fullyQualifiedName(mod)).fmt(ip)});
    defer blk: {
        log.debug("finish func name '{}'", .{(decl.fullyQualifiedName(mod) catch break :blk).fmt(ip)});
    }

    mod.intern_pool.removeDependenciesForDepender(gpa, InternPool.Depender.wrap(.{ .func = func_index }));

    var comptime_err_ret_trace = std.ArrayList(SrcLoc).init(gpa);
    defer comptime_err_ret_trace.deinit();

    // In the case of a generic function instance, this is the type of the
    // instance, which has comptime parameters elided. In other words, it is
    // the runtime-known parameters only, not to be confused with the
    // generic_owner function type, which potentially has more parameters,
    // including comptime parameters.
    const fn_ty = decl.typeOf(mod);
    const fn_ty_info = mod.typeToFunc(fn_ty).?;

    var sema: Sema = .{
        .mod = mod,
        .gpa = gpa,
        .arena = arena,
        .code = decl.getFileScope(mod).zir,
        .owner_decl = decl,
        .owner_decl_index = decl_index,
        .func_index = func_index,
        .func_is_naked = fn_ty_info.cc == .Naked,
        .fn_ret_ty = Type.fromInterned(fn_ty_info.return_type),
        .fn_ret_ty_ies = null,
        .owner_func_index = func_index,
        .branch_quota = @max(func.branchQuota(ip).*, Sema.default_branch_quota),
        .comptime_err_ret_trace = &comptime_err_ret_trace,
    };
    defer sema.deinit();

    // Every runtime function has a dependency on the source of the Decl it originates from.
    // It also depends on the value of its owner Decl.
    try sema.declareDependency(.{ .src_hash = decl.zir_decl_index.unwrap().? });
    try sema.declareDependency(.{ .decl_val = decl_index });

    if (func.analysis(ip).inferred_error_set) {
        const ies = try arena.create(Sema.InferredErrorSet);
        ies.* = .{ .func = func_index };
        sema.fn_ret_ty_ies = ies;
    }

    // reset in case calls to errorable functions are removed.
    func.analysis(ip).calls_or_awaits_errorable_fn = false;

    // First few indexes of extra are reserved and set at the end.
    const reserved_count = @typeInfo(Air.ExtraIndex).Enum.fields.len;
    try sema.air_extra.ensureTotalCapacity(gpa, reserved_count);
    sema.air_extra.items.len += reserved_count;

    var inner_block: Sema.Block = .{
        .parent = null,
        .sema = &sema,
        .src_decl = decl_index,
        .namespace = decl.src_namespace,
        .instructions = .{},
        .inlining = null,
        .is_comptime = false,
    };
    defer inner_block.instructions.deinit(gpa);

    const fn_info = sema.code.getFnInfo(func.zirBodyInst(ip).resolve(ip));

    // Here we are performing "runtime semantic analysis" for a function body, which means
    // we must map the parameter ZIR instructions to `arg` AIR instructions.
    // AIR requires the `arg` parameters to be the first N instructions.
    // This could be a generic function instantiation, however, in which case we need to
    // map the comptime parameters to constant values and only emit arg AIR instructions
    // for the runtime ones.
    const runtime_params_len = fn_ty_info.param_types.len;
    try inner_block.instructions.ensureTotalCapacityPrecise(gpa, runtime_params_len);
    try sema.air_instructions.ensureUnusedCapacity(gpa, fn_info.total_params_len);
    try sema.inst_map.ensureSpaceForInstructions(gpa, fn_info.param_body);

    // In the case of a generic function instance, pre-populate all the comptime args.
    if (func.comptime_args.len != 0) {
        for (
            fn_info.param_body[0..func.comptime_args.len],
            func.comptime_args.get(ip),
        ) |inst, comptime_arg| {
            if (comptime_arg == .none) continue;
            sema.inst_map.putAssumeCapacityNoClobber(inst, Air.internedToRef(comptime_arg));
        }
    }

    const src_params_len = if (func.comptime_args.len != 0)
        func.comptime_args.len
    else
        runtime_params_len;

    var runtime_param_index: usize = 0;
    for (fn_info.param_body[0..src_params_len], 0..) |inst, src_param_index| {
        const gop = sema.inst_map.getOrPutAssumeCapacity(inst);
        if (gop.found_existing) continue; // provided above by comptime arg

        const param_ty = fn_ty_info.param_types.get(ip)[runtime_param_index];
        runtime_param_index += 1;

        const opt_opv = sema.typeHasOnePossibleValue(Type.fromInterned(param_ty)) catch |err| switch (err) {
            error.NeededSourceLocation => unreachable,
            error.GenericPoison => unreachable,
            error.ComptimeReturn => unreachable,
            error.ComptimeBreak => unreachable,
            else => |e| return e,
        };
        if (opt_opv) |opv| {
            gop.value_ptr.* = Air.internedToRef(opv.toIntern());
            continue;
        }
        const arg_index: Air.Inst.Index = @enumFromInt(sema.air_instructions.len);
        gop.value_ptr.* = arg_index.toRef();
        inner_block.instructions.appendAssumeCapacity(arg_index);
        sema.air_instructions.appendAssumeCapacity(.{
            .tag = .arg,
            .data = .{ .arg = .{
                .ty = Air.internedToRef(param_ty),
                .src_index = @intCast(src_param_index),
            } },
        });
    }

    func.analysis(ip).state = .in_progress;

    const last_arg_index = inner_block.instructions.items.len;

    // Save the error trace as our first action in the function.
    // If this is unnecessary after all, Liveness will clean it up for us.
    const error_return_trace_index = try sema.analyzeSaveErrRetIndex(&inner_block);
    sema.error_return_trace_index_on_fn_entry = error_return_trace_index;
    inner_block.error_return_trace_index = error_return_trace_index;

    sema.analyzeFnBody(&inner_block, fn_info.body) catch |err| switch (err) {
        // TODO make these unreachable instead of @panic
        error.NeededSourceLocation => @panic("zig compiler bug: NeededSourceLocation"),
        error.GenericPoison => @panic("zig compiler bug: GenericPoison"),
        error.ComptimeReturn => @panic("zig compiler bug: ComptimeReturn"),
        else => |e| return e,
    };

    for (sema.unresolved_inferred_allocs.keys()) |ptr_inst| {
        // The lack of a resolve_inferred_alloc means that this instruction
        // is unused so it just has to be a no-op.
        sema.air_instructions.set(@intFromEnum(ptr_inst), .{
            .tag = .alloc,
            .data = .{ .ty = Type.single_const_pointer_to_comptime_int },
        });
    }

    // If we don't get an error return trace from a caller, create our own.
    if (func.analysis(ip).calls_or_awaits_errorable_fn and
        mod.comp.config.any_error_tracing and
        !sema.fn_ret_ty.isError(mod))
    {
        sema.setupErrorReturnTrace(&inner_block, last_arg_index) catch |err| switch (err) {
            // TODO make these unreachable instead of @panic
            error.NeededSourceLocation => @panic("zig compiler bug: NeededSourceLocation"),
            error.GenericPoison => @panic("zig compiler bug: GenericPoison"),
            error.ComptimeReturn => @panic("zig compiler bug: ComptimeReturn"),
            error.ComptimeBreak => @panic("zig compiler bug: ComptimeBreak"),
            else => |e| return e,
        };
    }

    // Copy the block into place and mark that as the main block.
    try sema.air_extra.ensureUnusedCapacity(gpa, @typeInfo(Air.Block).Struct.fields.len +
        inner_block.instructions.items.len);
    const main_block_index = sema.addExtraAssumeCapacity(Air.Block{
        .body_len = @intCast(inner_block.instructions.items.len),
    });
    sema.air_extra.appendSliceAssumeCapacity(@ptrCast(inner_block.instructions.items));
    sema.air_extra.items[@intFromEnum(Air.ExtraIndex.main_block)] = main_block_index;

    // Resolving inferred error sets is done *before* setting the function
    // state to success, so that "unable to resolve inferred error set" errors
    // can be emitted here.
    if (sema.fn_ret_ty_ies) |ies| {
        sema.resolveInferredErrorSetPtr(&inner_block, LazySrcLoc.nodeOffset(0), ies) catch |err| switch (err) {
            error.NeededSourceLocation => unreachable,
            error.GenericPoison => unreachable,
            error.ComptimeReturn => unreachable,
            error.ComptimeBreak => unreachable,
            error.AnalysisFail => {
                // In this case our function depends on a type that had a compile error.
                // We should not try to lower this function.
                decl.analysis = .dependency_failure;
                return error.AnalysisFail;
            },
            else => |e| return e,
        };
        assert(ies.resolved != .none);
        ip.funcIesResolved(func_index).* = ies.resolved;
    }

    func.analysis(ip).state = .success;

    // Finally we must resolve the return type and parameter types so that backends
    // have full access to type information.
    // Crucially, this happens *after* we set the function state to success above,
    // so that dependencies on the function body will now be satisfied rather than
    // result in circular dependency errors.
    sema.resolveFnTypes(fn_ty) catch |err| switch (err) {
        error.NeededSourceLocation => unreachable,
        error.GenericPoison => unreachable,
        error.ComptimeReturn => unreachable,
        error.ComptimeBreak => unreachable,
        error.AnalysisFail => {
            // In this case our function depends on a type that had a compile error.
            // We should not try to lower this function.
            decl.analysis = .dependency_failure;
            return error.AnalysisFail;
        },
        else => |e| return e,
    };

    // Similarly, resolve any queued up types that were requested to be resolved for
    // the backends.
    for (sema.types_to_resolve.keys()) |ty| {
        sema.resolveTypeFully(Type.fromInterned(ty)) catch |err| switch (err) {
            error.NeededSourceLocation => unreachable,
            error.GenericPoison => unreachable,
            error.ComptimeReturn => unreachable,
            error.ComptimeBreak => unreachable,
            error.AnalysisFail => {
                // In this case our function depends on a type that had a compile error.
                // We should not try to lower this function.
                decl.analysis = .dependency_failure;
                return error.AnalysisFail;
            },
            else => |e| return e,
        };
    }

    return .{
        .instructions = sema.air_instructions.toOwnedSlice(),
        .extra = try sema.air_extra.toOwnedSlice(gpa),
    };
}

pub fn createNamespace(mod: *Module, initialization: Namespace) !Namespace.Index {
    return mod.intern_pool.createNamespace(mod.gpa, initialization);
}

pub fn destroyNamespace(mod: *Module, index: Namespace.Index) void {
    return mod.intern_pool.destroyNamespace(mod.gpa, index);
}

pub fn allocateNewDecl(
    mod: *Module,
    namespace: Namespace.Index,
    src_node: Ast.Node.Index,
) !Decl.Index {
    const ip = &mod.intern_pool;
    const gpa = mod.gpa;
    const decl_index = try ip.createDecl(gpa, .{
        .name = undefined,
        .src_namespace = namespace,
        .src_node = src_node,
        .src_line = undefined,
        .has_tv = false,
        .owns_tv = false,
        .val = undefined,
        .alignment = undefined,
        .@"linksection" = .none,
        .@"addrspace" = .generic,
        .analysis = .unreferenced,
        .zir_decl_index = .none,
        .is_pub = false,
        .is_exported = false,
        .kind = .anon,
    });

    if (mod.emit_h) |mod_emit_h| {
        if (@intFromEnum(decl_index) >= mod_emit_h.allocated_emit_h.len) {
            try mod_emit_h.allocated_emit_h.append(gpa, .{});
            assert(@intFromEnum(decl_index) == mod_emit_h.allocated_emit_h.len);
        }
    }

    return decl_index;
}

pub fn getErrorValue(
    mod: *Module,
    name: InternPool.NullTerminatedString,
) Allocator.Error!ErrorInt {
    const gop = try mod.global_error_set.getOrPut(mod.gpa, name);
    return @as(ErrorInt, @intCast(gop.index));
}

pub fn getErrorValueFromSlice(
    mod: *Module,
    name: []const u8,
) Allocator.Error!ErrorInt {
    const interned_name = try mod.intern_pool.getOrPutString(mod.gpa, name);
    return getErrorValue(mod, interned_name);
}

pub fn errorSetBits(mod: *Module) u16 {
    if (mod.error_limit == 0) return 0;
    return std.math.log2_int_ceil(ErrorInt, mod.error_limit + 1); // +1 for no error
}

pub fn initNewAnonDecl(
    mod: *Module,
    new_decl_index: Decl.Index,
    src_line: u32,
    val: Value,
    name: InternPool.NullTerminatedString,
) Allocator.Error!void {
    const new_decl = mod.declPtr(new_decl_index);

    new_decl.name = name;
    new_decl.src_line = src_line;
    new_decl.val = val;
    new_decl.alignment = .none;
    new_decl.@"linksection" = .none;
    new_decl.has_tv = true;
    new_decl.analysis = .complete;
}

pub fn errNoteNonLazy(
    mod: *Module,
    src_loc: SrcLoc,
    parent: *ErrorMsg,
    comptime format: []const u8,
    args: anytype,
) error{OutOfMemory}!void {
    if (src_loc.lazy == .unneeded) {
        assert(parent.src_loc.lazy == .unneeded);
        return;
    }
    const msg = try std.fmt.allocPrint(mod.gpa, format, args);
    errdefer mod.gpa.free(msg);

    parent.notes = try mod.gpa.realloc(parent.notes, parent.notes.len + 1);
    parent.notes[parent.notes.len - 1] = .{
        .src_loc = src_loc,
        .msg = msg,
    };
}

/// Deprecated. There is no global target for a Zig Compilation Unit. Instead,
/// look up the target based on the Module that contains the source code being
/// analyzed.
pub fn getTarget(zcu: Module) Target {
    return zcu.root_mod.resolved_target.result;
}

/// Deprecated. There is no global optimization mode for a Zig Compilation
/// Unit. Instead, look up the optimization mode based on the Module that
/// contains the source code being analyzed.
pub fn optimizeMode(zcu: Module) std.builtin.OptimizeMode {
    return zcu.root_mod.optimize_mode;
}

fn lockAndClearFileCompileError(mod: *Module, file: *File) void {
    switch (file.status) {
        .success_zir, .retryable_failure => {},
        .never_loaded, .parse_failure, .astgen_failure => {
            mod.comp.mutex.lock();
            defer mod.comp.mutex.unlock();
            if (mod.failed_files.fetchSwapRemove(file)) |kv| {
                if (kv.value) |msg| msg.destroy(mod.gpa); // Delete previous error message.
            }
        },
    }
}

pub const SwitchProngSrc = union(enum) {
    /// The item for a scalar prong.
    scalar: u32,
    /// A given single item for a multi prong.
    multi: Multi,
    /// A given range item for a multi prong.
    range: Multi,
    /// The item for the special prong.
    special,
    /// The main capture for a scalar prong.
    scalar_capture: u32,
    /// The main capture for a multi prong.
    multi_capture: u32,
    /// The main capture for the special prong.
    special_capture,
    /// The tag capture for a scalar prong.
    scalar_tag_capture: u32,
    /// The tag capture for a multi prong.
    multi_tag_capture: u32,
    /// The tag capture for the special prong.
    special_tag_capture,

    pub const Multi = struct {
        prong: u32,
        item: u32,
    };

    pub const RangeExpand = enum { none, first, last };

    /// This function is intended to be called only when it is certain that we need
    /// the LazySrcLoc in order to emit a compile error.
    pub fn resolve(
        prong_src: SwitchProngSrc,
        mod: *Module,
        decl: *Decl,
        switch_node_offset: i32,
        /// Ignored if `prong_src` is not `.range`
        range_expand: RangeExpand,
    ) LazySrcLoc {
        @setCold(true);
        const gpa = mod.gpa;
        const tree = decl.getFileScope(mod).getTree(gpa) catch |err| {
            // In this case we emit a warning + a less precise source location.
            log.warn("unable to load {s}: {s}", .{
                decl.getFileScope(mod).sub_file_path, @errorName(err),
            });
            return LazySrcLoc.nodeOffset(0);
        };
        const switch_node = decl.relativeToNodeIndex(switch_node_offset);
        const main_tokens = tree.nodes.items(.main_token);
        const node_datas = tree.nodes.items(.data);
        const node_tags = tree.nodes.items(.tag);
        const extra = tree.extraData(node_datas[switch_node].rhs, Ast.Node.SubRange);
        const case_nodes = tree.extra_data[extra.start..extra.end];

        var multi_i: u32 = 0;
        var scalar_i: u32 = 0;
        const case_node = for (case_nodes) |case_node| {
            const case = tree.fullSwitchCase(case_node).?;

            const is_special = special: {
                if (case.ast.values.len == 0) break :special true;
                if (case.ast.values.len == 1 and node_tags[case.ast.values[0]] == .identifier) {
                    break :special mem.eql(u8, tree.tokenSlice(main_tokens[case.ast.values[0]]), "_");
                }
                break :special false;
            };

            if (is_special) {
                switch (prong_src) {
                    .special, .special_capture, .special_tag_capture => break case_node,
                    else => continue,
                }
            }

            const is_multi = case.ast.values.len != 1 or
                node_tags[case.ast.values[0]] == .switch_range;

            switch (prong_src) {
                .scalar,
                .scalar_capture,
                .scalar_tag_capture,
                => |i| if (!is_multi and i == scalar_i) break case_node,

                .multi_capture,
                .multi_tag_capture,
                => |i| if (is_multi and i == multi_i) break case_node,

                .multi,
                .range,
                => |m| if (is_multi and m.prong == multi_i) break case_node,

                .special,
                .special_capture,
                .special_tag_capture,
                => {},
            }

            if (is_multi) {
                multi_i += 1;
            } else {
                scalar_i += 1;
            }
        } else unreachable;

        const case = tree.fullSwitchCase(case_node).?;

        switch (prong_src) {
            .scalar, .special => return LazySrcLoc.nodeOffset(
                decl.nodeIndexToRelative(case.ast.values[0]),
            ),
            .multi => |m| {
                var item_i: u32 = 0;
                for (case.ast.values) |item_node| {
                    if (node_tags[item_node] == .switch_range) continue;
                    if (item_i == m.item) return LazySrcLoc.nodeOffset(
                        decl.nodeIndexToRelative(item_node),
                    );
                    item_i += 1;
                }
                unreachable;
            },
            .range => |m| {
                var range_i: u32 = 0;
                for (case.ast.values) |range| {
                    if (node_tags[range] != .switch_range) continue;
                    if (range_i == m.item) switch (range_expand) {
                        .none => return LazySrcLoc.nodeOffset(
                            decl.nodeIndexToRelative(range),
                        ),
                        .first => return LazySrcLoc.nodeOffset(
                            decl.nodeIndexToRelative(node_datas[range].lhs),
                        ),
                        .last => return LazySrcLoc.nodeOffset(
                            decl.nodeIndexToRelative(node_datas[range].rhs),
                        ),
                    };
                    range_i += 1;
                }
                unreachable;
            },
            .scalar_capture, .multi_capture, .special_capture => {
                return .{ .node_offset_switch_prong_capture = decl.nodeIndexToRelative(case_node) };
            },
            .scalar_tag_capture, .multi_tag_capture, .special_tag_capture => {
                return .{ .node_offset_switch_prong_tag_capture = decl.nodeIndexToRelative(case_node) };
            },
        }
    }
};

pub const PeerTypeCandidateSrc = union(enum) {
    /// Do not print out error notes for candidate sources
    none: void,
    /// When we want to know the the src of candidate i, look up at
    /// index i in this slice
    override: []const ?LazySrcLoc,
    /// resolvePeerTypes originates from a @TypeOf(...) call
    typeof_builtin_call_node_offset: i32,

    pub fn resolve(
        self: PeerTypeCandidateSrc,
        mod: *Module,
        decl: *Decl,
        candidate_i: usize,
    ) ?LazySrcLoc {
        @setCold(true);
        const gpa = mod.gpa;

        switch (self) {
            .none => {
                return null;
            },
            .override => |candidate_srcs| {
                if (candidate_i >= candidate_srcs.len)
                    return null;
                return candidate_srcs[candidate_i];
            },
            .typeof_builtin_call_node_offset => |node_offset| {
                switch (candidate_i) {
                    0 => return LazySrcLoc{ .node_offset_builtin_call_arg0 = node_offset },
                    1 => return LazySrcLoc{ .node_offset_builtin_call_arg1 = node_offset },
                    2 => return LazySrcLoc{ .node_offset_builtin_call_arg2 = node_offset },
                    3 => return LazySrcLoc{ .node_offset_builtin_call_arg3 = node_offset },
                    4 => return LazySrcLoc{ .node_offset_builtin_call_arg4 = node_offset },
                    5 => return LazySrcLoc{ .node_offset_builtin_call_arg5 = node_offset },
                    else => {},
                }

                const tree = decl.getFileScope(mod).getTree(gpa) catch |err| {
                    // In this case we emit a warning + a less precise source location.
                    log.warn("unable to load {s}: {s}", .{
                        decl.getFileScope(mod).sub_file_path, @errorName(err),
                    });
                    return LazySrcLoc.nodeOffset(0);
                };
                const node = decl.relativeToNodeIndex(node_offset);
                const node_datas = tree.nodes.items(.data);
                const params = tree.extra_data[node_datas[node].lhs..node_datas[node].rhs];

                return LazySrcLoc{ .node_abs = params[candidate_i] };
            },
        }
    }
};

const FieldSrcQuery = struct {
    index: usize,
    range: enum { name, type, value, alignment } = .name,
};

fn queryFieldSrc(
    tree: Ast,
    query: FieldSrcQuery,
    file_scope: *File,
    container_decl: Ast.full.ContainerDecl,
) SrcLoc {
    var field_index: usize = 0;
    for (container_decl.ast.members) |member_node| {
        const field = tree.fullContainerField(member_node) orelse continue;
        if (field_index == query.index) {
            return switch (query.range) {
                .name => .{
                    .file_scope = file_scope,
                    .parent_decl_node = 0,
                    .lazy = .{ .token_abs = field.ast.main_token },
                },
                .type => .{
                    .file_scope = file_scope,
                    .parent_decl_node = 0,
                    .lazy = .{ .node_abs = field.ast.type_expr },
                },
                .value => .{
                    .file_scope = file_scope,
                    .parent_decl_node = 0,
                    .lazy = .{ .node_abs = field.ast.value_expr },
                },
                .alignment => .{
                    .file_scope = file_scope,
                    .parent_decl_node = 0,
                    .lazy = .{ .node_abs = field.ast.align_expr },
                },
            };
        }
        field_index += 1;
    }
    unreachable;
}

pub fn paramSrc(
    func_node_offset: i32,
    mod: *Module,
    decl: *Decl,
    param_i: usize,
) LazySrcLoc {
    @setCold(true);
    const gpa = mod.gpa;
    const tree = decl.getFileScope(mod).getTree(gpa) catch |err| {
        // In this case we emit a warning + a less precise source location.
        log.warn("unable to load {s}: {s}", .{
            decl.getFileScope(mod).sub_file_path, @errorName(err),
        });
        return LazySrcLoc.nodeOffset(0);
    };
    const node = decl.relativeToNodeIndex(func_node_offset);
    var buf: [1]Ast.Node.Index = undefined;
    const full = tree.fullFnProto(&buf, node).?;
    var it = full.iterate(tree);
    var i: usize = 0;
    while (it.next()) |param| : (i += 1) {
        if (i == param_i) {
            if (param.anytype_ellipsis3) |some| {
                const main_token = tree.nodes.items(.main_token)[decl.src_node];
                return .{ .token_offset_param = @as(i32, @bitCast(some)) - @as(i32, @bitCast(main_token)) };
            }
            return .{ .node_offset_param = decl.nodeIndexToRelative(param.type_expr) };
        }
    }
    unreachable;
}

pub fn initSrc(
    mod: *Module,
    init_node_offset: i32,
    decl: *Decl,
    init_index: usize,
) LazySrcLoc {
    @setCold(true);
    const gpa = mod.gpa;
    const tree = decl.getFileScope(mod).getTree(gpa) catch |err| {
        // In this case we emit a warning + a less precise source location.
        log.warn("unable to load {s}: {s}", .{
            decl.getFileScope(mod).sub_file_path, @errorName(err),
        });
        return LazySrcLoc.nodeOffset(0);
    };
    const node_tags = tree.nodes.items(.tag);
    const node = decl.relativeToNodeIndex(init_node_offset);
    var buf: [2]Ast.Node.Index = undefined;
    switch (node_tags[node]) {
        .array_init_one,
        .array_init_one_comma,
        .array_init_dot_two,
        .array_init_dot_two_comma,
        .array_init_dot,
        .array_init_dot_comma,
        .array_init,
        .array_init_comma,
        => {
            const full = tree.fullArrayInit(&buf, node).?.ast.elements;
            return LazySrcLoc.nodeOffset(decl.nodeIndexToRelative(full[init_index]));
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
            const full = tree.fullStructInit(&buf, node).?.ast.fields;
            return LazySrcLoc{ .node_offset_initializer = decl.nodeIndexToRelative(full[init_index]) };
        },
        else => return LazySrcLoc.nodeOffset(init_node_offset),
    }
}

pub fn optionsSrc(mod: *Module, decl: *Decl, base_src: LazySrcLoc, wanted: []const u8) LazySrcLoc {
    @setCold(true);
    const gpa = mod.gpa;
    const tree = decl.getFileScope(mod).getTree(gpa) catch |err| {
        // In this case we emit a warning + a less precise source location.
        log.warn("unable to load {s}: {s}", .{
            decl.getFileScope(mod).sub_file_path, @errorName(err),
        });
        return LazySrcLoc.nodeOffset(0);
    };

    const o_i: struct { off: i32, i: u8 } = switch (base_src) {
        .node_offset_builtin_call_arg0 => |n| .{ .off = n, .i = 0 },
        .node_offset_builtin_call_arg1 => |n| .{ .off = n, .i = 1 },
        else => unreachable,
    };

    const node = decl.relativeToNodeIndex(o_i.off);
    const node_datas = tree.nodes.items(.data);
    const node_tags = tree.nodes.items(.tag);
    const arg_node = switch (node_tags[node]) {
        .builtin_call_two, .builtin_call_two_comma => switch (o_i.i) {
            0 => node_datas[node].lhs,
            1 => node_datas[node].rhs,
            else => unreachable,
        },
        .builtin_call, .builtin_call_comma => tree.extra_data[node_datas[node].lhs + o_i.i],
        else => unreachable,
    };
    var buf: [2]std.zig.Ast.Node.Index = undefined;
    const init_nodes = if (tree.fullStructInit(&buf, arg_node)) |struct_init| struct_init.ast.fields else return base_src;
    for (init_nodes) |init_node| {
        // . IDENTIFIER = init_node
        const name_token = tree.firstToken(init_node) - 2;
        const name = tree.tokenSlice(name_token);
        if (std.mem.eql(u8, name, wanted)) {
            return LazySrcLoc{ .node_offset_initializer = decl.nodeIndexToRelative(init_node) };
        }
    }
    return base_src;
}

/// Called from `Compilation.update`, after everything is done, just before
/// reporting compile errors. In this function we emit exported symbol collision
/// errors and communicate exported symbols to the linker backend.
pub fn processExports(mod: *Module) !void {
    // Map symbol names to `Export` for name collision detection.
    var symbol_exports: SymbolExports = .{};
    defer symbol_exports.deinit(mod.gpa);

    for (mod.decl_exports.keys(), mod.decl_exports.values()) |exported_decl, exports_list| {
        const exported: Exported = .{ .decl_index = exported_decl };
        try processExportsInner(mod, &symbol_exports, exported, exports_list.items);
    }

    for (mod.value_exports.keys(), mod.value_exports.values()) |exported_value, exports_list| {
        const exported: Exported = .{ .value = exported_value };
        try processExportsInner(mod, &symbol_exports, exported, exports_list.items);
    }
}

const SymbolExports = std.AutoArrayHashMapUnmanaged(InternPool.NullTerminatedString, *Export);

fn processExportsInner(
    zcu: *Zcu,
    symbol_exports: *SymbolExports,
    exported: Exported,
    exports: []const *Export,
) error{OutOfMemory}!void {
    const gpa = zcu.gpa;

    for (exports) |new_export| {
        const gop = try symbol_exports.getOrPut(gpa, new_export.opts.name);
        if (gop.found_existing) {
            new_export.status = .failed_retryable;
            try zcu.failed_exports.ensureUnusedCapacity(gpa, 1);
            const src_loc = new_export.getSrcLoc(zcu);
            const msg = try ErrorMsg.create(gpa, src_loc, "exported symbol collision: {}", .{
                new_export.opts.name.fmt(&zcu.intern_pool),
            });
            errdefer msg.destroy(gpa);
            const other_export = gop.value_ptr.*;
            const other_src_loc = other_export.getSrcLoc(zcu);
            try zcu.errNoteNonLazy(other_src_loc, msg, "other symbol here", .{});
            zcu.failed_exports.putAssumeCapacityNoClobber(new_export, msg);
            new_export.status = .failed;
        } else {
            gop.value_ptr.* = new_export;
        }
    }
    if (zcu.comp.bin_file) |lf| {
        try handleUpdateExports(zcu, exports, lf.updateExports(zcu, exported, exports));
    } else if (zcu.llvm_object) |llvm_object| {
        if (build_options.only_c) unreachable;
        try handleUpdateExports(zcu, exports, llvm_object.updateExports(zcu, exported, exports));
    }
}

fn handleUpdateExports(
    zcu: *Zcu,
    exports: []const *Export,
    result: link.File.UpdateExportsError!void,
) Allocator.Error!void {
    const gpa = zcu.gpa;
    result catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        error.AnalysisFail => {
            const new_export = exports[0];
            new_export.status = .failed_retryable;
            try zcu.failed_exports.ensureUnusedCapacity(gpa, 1);
            const src_loc = new_export.getSrcLoc(zcu);
            const msg = try ErrorMsg.create(gpa, src_loc, "unable to export: {s}", .{
                @errorName(err),
            });
            zcu.failed_exports.putAssumeCapacityNoClobber(new_export, msg);
        },
    };
}

pub fn populateTestFunctions(
    mod: *Module,
    main_progress_node: *std.Progress.Node,
) !void {
    const gpa = mod.gpa;
    const ip = &mod.intern_pool;
    const builtin_mod = mod.root_mod.getBuiltinDependency();
    const builtin_file = (mod.importPkg(builtin_mod) catch unreachable).file;
    const root_decl = mod.declPtr(builtin_file.root_decl.unwrap().?);
    const builtin_namespace = mod.namespacePtr(root_decl.src_namespace);
    const test_functions_str = try ip.getOrPutString(gpa, "test_functions", .no_embedded_nulls);
    const decl_index = builtin_namespace.decls.getKeyAdapted(
        test_functions_str,
        DeclAdapter{ .zcu = mod },
    ).?;
    {
        // We have to call `ensureDeclAnalyzed` here in case `builtin.test_functions`
        // was not referenced by start code.
        mod.sema_prog_node = main_progress_node.start("Semantic Analysis", 0);
        mod.sema_prog_node.activate();
        defer {
            mod.sema_prog_node.end();
            mod.sema_prog_node = undefined;
        }
        try mod.ensureDeclAnalyzed(decl_index);
    }
    const decl = mod.declPtr(decl_index);
    const test_fn_ty = decl.typeOf(mod).slicePtrFieldType(mod).childType(mod);

    const array_anon_decl: InternPool.Key.Ptr.BaseAddr.AnonDecl = array: {
        // Add mod.test_functions to an array decl then make the test_functions
        // decl reference it as a slice.
        const test_fn_vals = try gpa.alloc(InternPool.Index, mod.test_functions.count());
        defer gpa.free(test_fn_vals);

        for (test_fn_vals, mod.test_functions.keys()) |*test_fn_val, test_decl_index| {
            const test_decl = mod.declPtr(test_decl_index);
            const test_decl_name = try test_decl.fullyQualifiedName(mod);
            const test_decl_name_len = test_decl_name.length(ip);
            const test_name_anon_decl: InternPool.Key.Ptr.BaseAddr.AnonDecl = n: {
                const test_name_ty = try mod.arrayType(.{
                    .len = test_decl_name_len,
                    .child = .u8_type,
                });
                const test_name_val = try mod.intern(.{ .aggregate = .{
                    .ty = test_name_ty.toIntern(),
                    .storage = .{ .bytes = test_decl_name.toString() },
                } });
                break :n .{
                    .orig_ty = (try mod.singleConstPtrType(test_name_ty)).toIntern(),
                    .val = test_name_val,
                };
            };

            const test_fn_fields = .{
                // name
                try mod.intern(.{ .slice = .{
                    .ty = .slice_const_u8_type,
                    .ptr = try mod.intern(.{ .ptr = .{
                        .ty = .manyptr_const_u8_type,
                        .base_addr = .{ .anon_decl = test_name_anon_decl },
                        .byte_offset = 0,
                    } }),
                    .len = try mod.intern(.{ .int = .{
                        .ty = .usize_type,
                        .storage = .{ .u64 = test_decl_name_len },
                    } }),
                } }),
                // func
                try mod.intern(.{ .ptr = .{
                    .ty = try mod.intern(.{ .ptr_type = .{
                        .child = test_decl.typeOf(mod).toIntern(),
                        .flags = .{
                            .is_const = true,
                        },
                    } }),
                    .base_addr = .{ .decl = test_decl_index },
                    .byte_offset = 0,
                } }),
            };
            test_fn_val.* = try mod.intern(.{ .aggregate = .{
                .ty = test_fn_ty.toIntern(),
                .storage = .{ .elems = &test_fn_fields },
            } });
        }

        const array_ty = try mod.arrayType(.{
            .len = test_fn_vals.len,
            .child = test_fn_ty.toIntern(),
            .sentinel = .none,
        });
        const array_val = try mod.intern(.{ .aggregate = .{
            .ty = array_ty.toIntern(),
            .storage = .{ .elems = test_fn_vals },
        } });
        break :array .{
            .orig_ty = (try mod.singleConstPtrType(array_ty)).toIntern(),
            .val = array_val,
        };
    };

    {
        const new_ty = try mod.ptrType(.{
            .child = test_fn_ty.toIntern(),
            .flags = .{
                .is_const = true,
                .size = .Slice,
            },
        });
        const new_val = decl.val;
        const new_init = try mod.intern(.{ .slice = .{
            .ty = new_ty.toIntern(),
            .ptr = try mod.intern(.{ .ptr = .{
                .ty = new_ty.slicePtrFieldType(mod).toIntern(),
                .base_addr = .{ .anon_decl = array_anon_decl },
                .byte_offset = 0,
            } }),
            .len = (try mod.intValue(Type.usize, mod.test_functions.count())).toIntern(),
        } });
        ip.mutateVarInit(decl.val.toIntern(), new_init);

        // Since we are replacing the Decl's value we must perform cleanup on the
        // previous value.
        decl.val = new_val;
        decl.has_tv = true;
    }
    try mod.linkerUpdateDecl(decl_index);
}

pub fn linkerUpdateDecl(zcu: *Zcu, decl_index: Decl.Index) !void {
    const comp = zcu.comp;

    if (comp.bin_file) |lf| {
        lf.updateDecl(zcu, decl_index) catch |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            error.AnalysisFail => {
                const decl = zcu.declPtr(decl_index);
                decl.analysis = .codegen_failure;
            },
            else => {
                const decl = zcu.declPtr(decl_index);
                const gpa = zcu.gpa;
                try zcu.failed_decls.ensureUnusedCapacity(gpa, 1);
                zcu.failed_decls.putAssumeCapacityNoClobber(decl_index, try ErrorMsg.create(
                    gpa,
                    decl.srcLoc(zcu),
                    "unable to codegen: {s}",
                    .{@errorName(err)},
                ));
                decl.analysis = .codegen_failure;
                try zcu.retryable_failures.append(zcu.gpa, InternPool.Depender.wrap(.{ .decl = decl_index }));
            },
        };
    } else if (zcu.llvm_object) |llvm_object| {
        if (build_options.only_c) unreachable;
        llvm_object.updateDecl(zcu, decl_index) catch |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            error.AnalysisFail => {
                const decl = zcu.declPtr(decl_index);
                decl.analysis = .codegen_failure;
            },
        };
    }
}

fn reportRetryableFileError(
    mod: *Module,
    file: *File,
    comptime format: []const u8,
    args: anytype,
) error{OutOfMemory}!void {
    file.status = .retryable_failure;

    const err_msg = try ErrorMsg.create(
        mod.gpa,
        .{
            .file_scope = file,
            .parent_decl_node = 0,
            .lazy = .entire_file,
        },
        format,
        args,
    );
    errdefer err_msg.destroy(mod.gpa);

    mod.comp.mutex.lock();
    defer mod.comp.mutex.unlock();

    const gop = try mod.failed_files.getOrPut(mod.gpa, file);
    if (gop.found_existing) {
        if (gop.value_ptr.*) |old_err_msg| {
            old_err_msg.destroy(mod.gpa);
        }
    }
    gop.value_ptr.* = err_msg;
}

pub fn addGlobalAssembly(mod: *Module, decl_index: Decl.Index, source: []const u8) !void {
    const gop = try mod.global_assembly.getOrPut(mod.gpa, decl_index);
    if (gop.found_existing) {
        const new_value = try std.fmt.allocPrint(mod.gpa, "{s}\n{s}", .{ gop.value_ptr.*, source });
        mod.gpa.free(gop.value_ptr.*);
        gop.value_ptr.* = new_value;
    } else {
        gop.value_ptr.* = try mod.gpa.dupe(u8, source);
    }
}

pub fn getDeclExports(mod: Module, decl_index: Decl.Index) []const *Export {
    if (mod.decl_exports.get(decl_index)) |l| {
        return l.items;
    } else {
        return &[0]*Export{};
    }
}

pub const Feature = enum {
    panic_fn,
    panic_unwrap_error,
    safety_check_formatted,
    error_return_trace,
    is_named_enum_value,
    error_set_has_value,
    field_reordering,
    /// When this feature is supported, the backend supports the following AIR instructions:
    /// * `Air.Inst.Tag.add_safe`
    /// * `Air.Inst.Tag.sub_safe`
    /// * `Air.Inst.Tag.mul_safe`
    /// The motivation for this feature is that it makes AIR smaller, and makes it easier
    /// to generate better machine code in the backends. All backends should migrate to
    /// enabling this feature.
    safety_checked_instructions,
};

pub fn backendSupportsFeature(zcu: Module, feature: Feature) bool {
    const cpu_arch = zcu.root_mod.resolved_target.result.cpu.arch;
    const ofmt = zcu.root_mod.resolved_target.result.ofmt;
    const use_llvm = zcu.comp.config.use_llvm;
    return target_util.backendSupportsFeature(cpu_arch, ofmt, use_llvm, feature);
}

/// Shortcut for calling `intern_pool.get`.
pub fn intern(mod: *Module, key: InternPool.Key) Allocator.Error!InternPool.Index {
    return mod.intern_pool.get(mod.gpa, key);
}

/// Shortcut for calling `intern_pool.getCoerced`.
pub fn getCoerced(mod: *Module, val: Value, new_ty: Type) Allocator.Error!Value {
    return Value.fromInterned((try mod.intern_pool.getCoerced(mod.gpa, val.toIntern(), new_ty.toIntern())));
}

pub fn intType(mod: *Module, signedness: std.builtin.Signedness, bits: u16) Allocator.Error!Type {
    return Type.fromInterned((try intern(mod, .{ .int_type = .{
        .signedness = signedness,
        .bits = bits,
    } })));
}

pub fn errorIntType(mod: *Module) std.mem.Allocator.Error!Type {
    return mod.intType(.unsigned, mod.errorSetBits());
}

pub fn arrayType(mod: *Module, info: InternPool.Key.ArrayType) Allocator.Error!Type {
    const i = try intern(mod, .{ .array_type = info });
    return Type.fromInterned(i);
}

pub fn vectorType(mod: *Module, info: InternPool.Key.VectorType) Allocator.Error!Type {
    const i = try intern(mod, .{ .vector_type = info });
    return Type.fromInterned(i);
}

pub fn optionalType(mod: *Module, child_type: InternPool.Index) Allocator.Error!Type {
    const i = try intern(mod, .{ .opt_type = child_type });
    return Type.fromInterned(i);
}

pub fn ptrType(mod: *Module, info: InternPool.Key.PtrType) Allocator.Error!Type {
    var canon_info = info;

    if (info.flags.size == .C) canon_info.flags.is_allowzero = true;

    // Canonicalize non-zero alignment. If it matches the ABI alignment of the pointee
    // type, we change it to 0 here. If this causes an assertion trip because the
    // pointee type needs to be resolved more, that needs to be done before calling
    // this ptr() function.
    if (info.flags.alignment != .none and
        info.flags.alignment == Type.fromInterned(info.child).abiAlignment(mod))
    {
        canon_info.flags.alignment = .none;
    }

    switch (info.flags.vector_index) {
        // Canonicalize host_size. If it matches the bit size of the pointee type,
        // we change it to 0 here. If this causes an assertion trip, the pointee type
        // needs to be resolved before calling this ptr() function.
        .none => if (info.packed_offset.host_size != 0) {
            const elem_bit_size = Type.fromInterned(info.child).bitSize(mod);
            assert(info.packed_offset.bit_offset + elem_bit_size <= info.packed_offset.host_size * 8);
            if (info.packed_offset.host_size * 8 == elem_bit_size) {
                canon_info.packed_offset.host_size = 0;
            }
        },
        .runtime => {},
        _ => assert(@intFromEnum(info.flags.vector_index) < info.packed_offset.host_size),
    }

    return Type.fromInterned((try intern(mod, .{ .ptr_type = canon_info })));
}

pub fn singleMutPtrType(mod: *Module, child_type: Type) Allocator.Error!Type {
    return ptrType(mod, .{ .child = child_type.toIntern() });
}

pub fn singleConstPtrType(mod: *Module, child_type: Type) Allocator.Error!Type {
    return ptrType(mod, .{
        .child = child_type.toIntern(),
        .flags = .{
            .is_const = true,
        },
    });
}

pub fn manyConstPtrType(mod: *Module, child_type: Type) Allocator.Error!Type {
    return ptrType(mod, .{
        .child = child_type.toIntern(),
        .flags = .{
            .size = .Many,
            .is_const = true,
        },
    });
}

pub fn adjustPtrTypeChild(mod: *Module, ptr_ty: Type, new_child: Type) Allocator.Error!Type {
    var info = ptr_ty.ptrInfo(mod);
    info.child = new_child.toIntern();
    return mod.ptrType(info);
}

pub fn funcType(mod: *Module, key: InternPool.GetFuncTypeKey) Allocator.Error!Type {
    return Type.fromInterned((try mod.intern_pool.getFuncType(mod.gpa, key)));
}

/// Use this for `anyframe->T` only.
/// For `anyframe`, use the `InternPool.Index.anyframe` tag directly.
pub fn anyframeType(mod: *Module, payload_ty: Type) Allocator.Error!Type {
    return Type.fromInterned((try intern(mod, .{ .anyframe_type = payload_ty.toIntern() })));
}

pub fn errorUnionType(mod: *Module, error_set_ty: Type, payload_ty: Type) Allocator.Error!Type {
    return Type.fromInterned((try intern(mod, .{ .error_union_type = .{
        .error_set_type = error_set_ty.toIntern(),
        .payload_type = payload_ty.toIntern(),
    } })));
}

pub fn singleErrorSetType(mod: *Module, name: InternPool.NullTerminatedString) Allocator.Error!Type {
    const names: *const [1]InternPool.NullTerminatedString = &name;
    const new_ty = try mod.intern_pool.getErrorSetType(mod.gpa, names);
    return Type.fromInterned(new_ty);
}

/// Sorts `names` in place.
pub fn errorSetFromUnsortedNames(
    mod: *Module,
    names: []InternPool.NullTerminatedString,
) Allocator.Error!Type {
    std.mem.sort(
        InternPool.NullTerminatedString,
        names,
        {},
        InternPool.NullTerminatedString.indexLessThan,
    );
    const new_ty = try mod.intern_pool.getErrorSetType(mod.gpa, names);
    return Type.fromInterned(new_ty);
}

/// Supports only pointers, not pointer-like optionals.
pub fn ptrIntValue(mod: *Module, ty: Type, x: u64) Allocator.Error!Value {
    assert(ty.zigTypeTag(mod) == .Pointer and !ty.isSlice(mod));
    assert(x != 0 or ty.isAllowzeroPtr(mod));
    const i = try intern(mod, .{ .ptr = .{
        .ty = ty.toIntern(),
        .base_addr = .int,
        .byte_offset = x,
    } });
    return Value.fromInterned(i);
}

/// Creates an enum tag value based on the integer tag value.
pub fn enumValue(mod: *Module, ty: Type, tag_int: InternPool.Index) Allocator.Error!Value {
    if (std.debug.runtime_safety) {
        const tag = ty.zigTypeTag(mod);
        assert(tag == .Enum);
    }
    const i = try intern(mod, .{ .enum_tag = .{
        .ty = ty.toIntern(),
        .int = tag_int,
    } });
    return Value.fromInterned(i);
}

/// Creates an enum tag value based on the field index according to source code
/// declaration order.
pub fn enumValueFieldIndex(mod: *Module, ty: Type, field_index: u32) Allocator.Error!Value {
    const ip = &mod.intern_pool;
    const gpa = mod.gpa;
    const enum_type = ip.loadEnumType(ty.toIntern());

    if (enum_type.values.len == 0) {
        // Auto-numbered fields.
        return Value.fromInterned((try ip.get(gpa, .{ .enum_tag = .{
            .ty = ty.toIntern(),
            .int = try ip.get(gpa, .{ .int = .{
                .ty = enum_type.tag_ty,
                .storage = .{ .u64 = field_index },
            } }),
        } })));
    }

    return Value.fromInterned((try ip.get(gpa, .{ .enum_tag = .{
        .ty = ty.toIntern(),
        .int = enum_type.values.get(ip)[field_index],
    } })));
}

pub fn undefValue(mod: *Module, ty: Type) Allocator.Error!Value {
    return Value.fromInterned((try mod.intern(.{ .undef = ty.toIntern() })));
}

pub fn undefRef(mod: *Module, ty: Type) Allocator.Error!Air.Inst.Ref {
    return Air.internedToRef((try mod.undefValue(ty)).toIntern());
}

pub fn intValue(mod: *Module, ty: Type, x: anytype) Allocator.Error!Value {
    if (std.math.cast(u64, x)) |casted| return intValue_u64(mod, ty, casted);
    if (std.math.cast(i64, x)) |casted| return intValue_i64(mod, ty, casted);
    var limbs_buffer: [4]usize = undefined;
    var big_int = BigIntMutable.init(&limbs_buffer, x);
    return intValue_big(mod, ty, big_int.toConst());
}

pub fn intRef(mod: *Module, ty: Type, x: anytype) Allocator.Error!Air.Inst.Ref {
    return Air.internedToRef((try mod.intValue(ty, x)).toIntern());
}

pub fn intValue_big(mod: *Module, ty: Type, x: BigIntConst) Allocator.Error!Value {
    const i = try intern(mod, .{ .int = .{
        .ty = ty.toIntern(),
        .storage = .{ .big_int = x },
    } });
    return Value.fromInterned(i);
}

pub fn intValue_u64(mod: *Module, ty: Type, x: u64) Allocator.Error!Value {
    const i = try intern(mod, .{ .int = .{
        .ty = ty.toIntern(),
        .storage = .{ .u64 = x },
    } });
    return Value.fromInterned(i);
}

pub fn intValue_i64(mod: *Module, ty: Type, x: i64) Allocator.Error!Value {
    const i = try intern(mod, .{ .int = .{
        .ty = ty.toIntern(),
        .storage = .{ .i64 = x },
    } });
    return Value.fromInterned(i);
}

pub fn unionValue(mod: *Module, union_ty: Type, tag: Value, val: Value) Allocator.Error!Value {
    const i = try intern(mod, .{ .un = .{
        .ty = union_ty.toIntern(),
        .tag = tag.toIntern(),
        .val = val.toIntern(),
    } });
    return Value.fromInterned(i);
}

/// This function casts the float representation down to the representation of the type, potentially
/// losing data if the representation wasn't correct.
pub fn floatValue(mod: *Module, ty: Type, x: anytype) Allocator.Error!Value {
    const storage: InternPool.Key.Float.Storage = switch (ty.floatBits(mod.getTarget())) {
        16 => .{ .f16 = @as(f16, @floatCast(x)) },
        32 => .{ .f32 = @as(f32, @floatCast(x)) },
        64 => .{ .f64 = @as(f64, @floatCast(x)) },
        80 => .{ .f80 = @as(f80, @floatCast(x)) },
        128 => .{ .f128 = @as(f128, @floatCast(x)) },
        else => unreachable,
    };
    const i = try intern(mod, .{ .float = .{
        .ty = ty.toIntern(),
        .storage = storage,
    } });
    return Value.fromInterned(i);
}

pub fn nullValue(mod: *Module, opt_ty: Type) Allocator.Error!Value {
    const ip = &mod.intern_pool;
    assert(ip.isOptionalType(opt_ty.toIntern()));
    const result = try ip.get(mod.gpa, .{ .opt = .{
        .ty = opt_ty.toIntern(),
        .val = .none,
    } });
    return Value.fromInterned(result);
}

pub fn smallestUnsignedInt(mod: *Module, max: u64) Allocator.Error!Type {
    return intType(mod, .unsigned, Type.smallestUnsignedBits(max));
}

/// Returns the smallest possible integer type containing both `min` and
/// `max`. Asserts that neither value is undef.
/// TODO: if #3806 is implemented, this becomes trivial
pub fn intFittingRange(mod: *Module, min: Value, max: Value) !Type {
    assert(!min.isUndef(mod));
    assert(!max.isUndef(mod));

    if (std.debug.runtime_safety) {
        assert(Value.order(min, max, mod).compare(.lte));
    }

    const sign = min.orderAgainstZero(mod) == .lt;

    const min_val_bits = intBitsForValue(mod, min, sign);
    const max_val_bits = intBitsForValue(mod, max, sign);

    return mod.intType(
        if (sign) .signed else .unsigned,
        @max(min_val_bits, max_val_bits),
    );
}

/// Given a value representing an integer, returns the number of bits necessary to represent
/// this value in an integer. If `sign` is true, returns the number of bits necessary in a
/// twos-complement integer; otherwise in an unsigned integer.
/// Asserts that `val` is not undef. If `val` is negative, asserts that `sign` is true.
pub fn intBitsForValue(mod: *Module, val: Value, sign: bool) u16 {
    assert(!val.isUndef(mod));

    const key = mod.intern_pool.indexToKey(val.toIntern());
    switch (key.int.storage) {
        .i64 => |x| {
            if (std.math.cast(u64, x)) |casted| return Type.smallestUnsignedBits(casted) + @intFromBool(sign);
            assert(sign);
            // Protect against overflow in the following negation.
            if (x == std.math.minInt(i64)) return 64;
            return Type.smallestUnsignedBits(@as(u64, @intCast(-(x + 1)))) + 1;
        },
        .u64 => |x| {
            return Type.smallestUnsignedBits(x) + @intFromBool(sign);
        },
        .big_int => |big| {
            if (big.positive) return @as(u16, @intCast(big.bitCountAbs() + @intFromBool(sign)));

            // Zero is still a possibility, in which case unsigned is fine
            if (big.eqlZero()) return 0;

            return @as(u16, @intCast(big.bitCountTwosComp()));
        },
        .lazy_align => |lazy_ty| {
            return Type.smallestUnsignedBits(Type.fromInterned(lazy_ty).abiAlignment(mod).toByteUnits() orelse 0) + @intFromBool(sign);
        },
        .lazy_size => |lazy_ty| {
            return Type.smallestUnsignedBits(Type.fromInterned(lazy_ty).abiSize(mod)) + @intFromBool(sign);
        },
    }
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
    mod: *Module,
    ty: Type,
    diags: *AtomicPtrAlignmentDiagnostics,
) AtomicPtrAlignmentError!Alignment {
    const target = mod.getTarget();
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
        .le32,
        .mips,
        .mipsel,
        .nvptx,
        .powerpc,
        .powerpcle,
        .r600,
        .riscv32,
        .sparc,
        .sparcel,
        .tce,
        .tcele,
        .thumb,
        .thumbeb,
        .x86,
        .xcore,
        .amdil,
        .hsail,
        .spir,
        .kalimba,
        .lanai,
        .shave,
        .wasm32,
        .renderscript32,
        .csky,
        .spirv32,
        .dxil,
        .loongarch32,
        .xtensa,
        => 32,

        .amdgcn,
        .bpfel,
        .bpfeb,
        .le64,
        .mips64,
        .mips64el,
        .nvptx64,
        .powerpc64,
        .powerpc64le,
        .riscv64,
        .sparc64,
        .s390x,
        .amdil64,
        .hsail64,
        .spir64,
        .wasm64,
        .renderscript64,
        .ve,
        .spirv64,
        .loongarch64,
        => 64,

        .aarch64,
        .aarch64_be,
        .aarch64_32,
        => 128,

        .x86_64 => if (std.Target.x86.featureSetHas(target.cpu.features, .cx16)) 128 else 64,
    };

    const int_ty = switch (ty.zigTypeTag(mod)) {
        .Int => ty,
        .Enum => ty.intTagType(mod),
        .Float => {
            const bit_count = ty.floatBits(target);
            if (bit_count > max_atomic_bits) {
                diags.* = .{
                    .bits = bit_count,
                    .max_bits = max_atomic_bits,
                };
                return error.FloatTooBig;
            }
            return .none;
        },
        .Bool => return .none,
        else => {
            if (ty.isPtrAtRuntime(mod)) return .none;
            return error.BadType;
        },
    };

    const bit_count = int_ty.intInfo(mod).bits;
    if (bit_count > max_atomic_bits) {
        diags.* = .{
            .bits = bit_count,
            .max_bits = max_atomic_bits,
        };
        return error.IntTooBig;
    }

    return .none;
}

pub fn declFileScope(mod: *Module, decl_index: Decl.Index) *File {
    return mod.declPtr(decl_index).getFileScope(mod);
}

/// Returns null in the following cases:
/// * `@TypeOf(.{})`
/// * A struct which has no fields (`struct {}`).
/// * Not a struct.
pub fn typeToStruct(mod: *Module, ty: Type) ?InternPool.LoadedStructType {
    if (ty.ip_index == .none) return null;
    const ip = &mod.intern_pool;
    return switch (ip.indexToKey(ty.ip_index)) {
        .struct_type => ip.loadStructType(ty.ip_index),
        else => null,
    };
}

pub fn typeToPackedStruct(mod: *Module, ty: Type) ?InternPool.LoadedStructType {
    const s = mod.typeToStruct(ty) orelse return null;
    if (s.layout != .@"packed") return null;
    return s;
}

pub fn typeToUnion(mod: *Module, ty: Type) ?InternPool.LoadedUnionType {
    if (ty.ip_index == .none) return null;
    const ip = &mod.intern_pool;
    return switch (ip.indexToKey(ty.ip_index)) {
        .union_type => ip.loadUnionType(ty.ip_index),
        else => null,
    };
}

pub fn typeToFunc(mod: *Module, ty: Type) ?InternPool.Key.FuncType {
    if (ty.ip_index == .none) return null;
    return mod.intern_pool.indexToFuncType(ty.toIntern());
}

pub fn funcOwnerDeclPtr(mod: *Module, func_index: InternPool.Index) *Decl {
    return mod.declPtr(mod.funcOwnerDeclIndex(func_index));
}

pub fn funcOwnerDeclIndex(mod: *Module, func_index: InternPool.Index) Decl.Index {
    return mod.funcInfo(func_index).owner_decl;
}

pub fn iesFuncIndex(mod: *const Module, ies_index: InternPool.Index) InternPool.Index {
    return mod.intern_pool.iesFuncIndex(ies_index);
}

pub fn funcInfo(mod: *Module, func_index: InternPool.Index) InternPool.Key.Func {
    return mod.intern_pool.indexToKey(func_index).func;
}

pub fn fieldSrcLoc(mod: *Module, owner_decl_index: Decl.Index, query: FieldSrcQuery) SrcLoc {
    @setCold(true);
    const owner_decl = mod.declPtr(owner_decl_index);
    const file = owner_decl.getFileScope(mod);
    const tree = file.getTree(mod.gpa) catch |err| {
        // In this case we emit a warning + a less precise source location.
        log.warn("unable to load {s}: {s}", .{
            file.sub_file_path, @errorName(err),
        });
        return owner_decl.srcLoc(mod);
    };
    const node = owner_decl.relativeToNodeIndex(0);
    var buf: [2]Ast.Node.Index = undefined;
    if (tree.fullContainerDecl(&buf, node)) |container_decl| {
        return queryFieldSrc(tree.*, query, file, container_decl);
    } else {
        // This type was generated using @Type
        return owner_decl.srcLoc(mod);
    }
}

pub fn toEnum(mod: *Module, comptime E: type, val: Value) E {
    return mod.intern_pool.toEnum(E, val.toIntern());
}

pub fn isAnytypeParam(mod: *Module, func: InternPool.Index, index: u32) bool {
    const file = mod.declPtr(func.owner_decl).getFileScope(mod);

    const tags = file.zir.instructions.items(.tag);

    const param_body = file.zir.getParamBody(func.zir_body_inst);
    const param = param_body[index];

    return switch (tags[param]) {
        .param, .param_comptime => false,
        .param_anytype, .param_anytype_comptime => true,
        else => unreachable,
    };
}

pub fn getParamName(mod: *Module, func_index: InternPool.Index, index: u32) [:0]const u8 {
    const func = mod.funcInfo(func_index);
    const file = mod.declPtr(func.owner_decl).getFileScope(mod);

    const tags = file.zir.instructions.items(.tag);
    const data = file.zir.instructions.items(.data);

    const param_body = file.zir.getParamBody(func.zir_body_inst.resolve(&mod.intern_pool));
    const param = param_body[index];

    return switch (tags[@intFromEnum(param)]) {
        .param, .param_comptime => blk: {
            const extra = file.zir.extraData(Zir.Inst.Param, data[@intFromEnum(param)].pl_tok.payload_index);
            break :blk file.zir.nullTerminatedString(extra.data.name);
        },
        .param_anytype, .param_anytype_comptime => blk: {
            const param_data = data[@intFromEnum(param)].str_tok;
            break :blk param_data.get(file.zir);
        },
        else => unreachable,
    };
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
};

pub fn getUnionLayout(mod: *Module, loaded_union: InternPool.LoadedUnionType) UnionLayout {
    const ip = &mod.intern_pool;
    assert(loaded_union.haveLayout(ip));
    var most_aligned_field: u32 = undefined;
    var most_aligned_field_size: u64 = undefined;
    var biggest_field: u32 = undefined;
    var payload_size: u64 = 0;
    var payload_align: Alignment = .@"1";
    for (loaded_union.field_types.get(ip), 0..) |field_ty, field_index| {
        if (!Type.fromInterned(field_ty).hasRuntimeBitsIgnoreComptime(mod)) continue;

        const explicit_align = loaded_union.fieldAlign(ip, field_index);
        const field_align = if (explicit_align != .none)
            explicit_align
        else
            Type.fromInterned(field_ty).abiAlignment(mod);
        const field_size = Type.fromInterned(field_ty).abiSize(mod);
        if (field_size > payload_size) {
            payload_size = field_size;
            biggest_field = @intCast(field_index);
        }
        if (field_align.compare(.gte, payload_align)) {
            payload_align = field_align;
            most_aligned_field = @intCast(field_index);
            most_aligned_field_size = field_size;
        }
    }
    const have_tag = loaded_union.flagsPtr(ip).runtime_tag.hasTag();
    if (!have_tag or !Type.fromInterned(loaded_union.enum_tag_ty).hasRuntimeBits(mod)) {
        return .{
            .abi_size = payload_align.forward(payload_size),
            .abi_align = payload_align,
            .most_aligned_field = most_aligned_field,
            .most_aligned_field_size = most_aligned_field_size,
            .biggest_field = biggest_field,
            .payload_size = payload_size,
            .payload_align = payload_align,
            .tag_align = .none,
            .tag_size = 0,
            .padding = 0,
        };
    }

    const tag_size = Type.fromInterned(loaded_union.enum_tag_ty).abiSize(mod);
    const tag_align = Type.fromInterned(loaded_union.enum_tag_ty).abiAlignment(mod).max(.@"1");
    return .{
        .abi_size = loaded_union.size(ip).*,
        .abi_align = tag_align.max(payload_align),
        .most_aligned_field = most_aligned_field,
        .most_aligned_field_size = most_aligned_field_size,
        .biggest_field = biggest_field,
        .payload_size = payload_size,
        .payload_align = payload_align,
        .tag_align = tag_align,
        .tag_size = tag_size,
        .padding = loaded_union.padding(ip).*,
    };
}

pub fn unionAbiSize(mod: *Module, loaded_union: InternPool.LoadedUnionType) u64 {
    return mod.getUnionLayout(loaded_union).abi_size;
}

/// Returns 0 if the union is represented with 0 bits at runtime.
pub fn unionAbiAlignment(mod: *Module, loaded_union: InternPool.LoadedUnionType) Alignment {
    const ip = &mod.intern_pool;
    const have_tag = loaded_union.flagsPtr(ip).runtime_tag.hasTag();
    var max_align: Alignment = .none;
    if (have_tag) max_align = Type.fromInterned(loaded_union.enum_tag_ty).abiAlignment(mod);
    for (loaded_union.field_types.get(ip), 0..) |field_ty, field_index| {
        if (!Type.fromInterned(field_ty).hasRuntimeBits(mod)) continue;

        const field_align = mod.unionFieldNormalAlignment(loaded_union, @intCast(field_index));
        max_align = max_align.max(field_align);
    }
    return max_align;
}

/// Returns the field alignment, assuming the union is not packed.
/// Keep implementation in sync with `Sema.unionFieldAlignment`.
/// Prefer to call that function instead of this one during Sema.
pub fn unionFieldNormalAlignment(mod: *Module, loaded_union: InternPool.LoadedUnionType, field_index: u32) Alignment {
    const ip = &mod.intern_pool;
    const field_align = loaded_union.fieldAlign(ip, field_index);
    if (field_align != .none) return field_align;
    const field_ty = Type.fromInterned(loaded_union.field_types.get(ip)[field_index]);
    return field_ty.abiAlignment(mod);
}

/// Returns the index of the active field, given the current tag value
pub fn unionTagFieldIndex(mod: *Module, loaded_union: InternPool.LoadedUnionType, enum_tag: Value) ?u32 {
    const ip = &mod.intern_pool;
    if (enum_tag.toIntern() == .none) return null;
    assert(ip.typeOf(enum_tag.toIntern()) == loaded_union.enum_tag_ty);
    return loaded_union.loadTagType(ip).tagValueIndex(ip, enum_tag.toIntern());
}

/// Returns the field alignment of a non-packed struct in byte units.
/// Keep implementation in sync with `Sema.structFieldAlignment`.
/// asserts the layout is not packed.
pub fn structFieldAlignment(
    mod: *Module,
    explicit_alignment: InternPool.Alignment,
    field_ty: Type,
    layout: std.builtin.Type.ContainerLayout,
) Alignment {
    assert(layout != .@"packed");
    if (explicit_alignment != .none) return explicit_alignment;
    switch (layout) {
        .@"packed" => unreachable,
        .auto => {
            if (mod.getTarget().ofmt == .c) {
                return structFieldAlignmentExtern(mod, field_ty);
            } else {
                return field_ty.abiAlignment(mod);
            }
        },
        .@"extern" => return structFieldAlignmentExtern(mod, field_ty),
    }
}

/// Returns the field alignment of an extern struct in byte units.
/// This logic is duplicated in Type.abiAlignmentAdvanced.
pub fn structFieldAlignmentExtern(mod: *Module, field_ty: Type) Alignment {
    const ty_abi_align = field_ty.abiAlignment(mod);

    if (field_ty.isAbiInt(mod) and field_ty.intInfo(mod).bits >= 128) {
        // The C ABI requires 128 bit integer fields of structs
        // to be 16-bytes aligned.
        return ty_abi_align.max(.@"16");
    }

    return ty_abi_align;
}

/// https://github.com/ziglang/zig/issues/17178 explored storing these bit offsets
/// into the packed struct InternPool data rather than computing this on the
/// fly, however it was found to perform worse when measured on real world
/// projects.
pub fn structPackedFieldBitOffset(
    mod: *Module,
    struct_type: InternPool.LoadedStructType,
    field_index: u32,
) u16 {
    const ip = &mod.intern_pool;
    assert(struct_type.layout == .@"packed");
    assert(struct_type.haveLayout(ip));
    var bit_sum: u64 = 0;
    for (0..struct_type.field_types.len) |i| {
        if (i == field_index) {
            return @intCast(bit_sum);
        }
        const field_ty = Type.fromInterned(struct_type.field_types.get(ip)[i]);
        bit_sum += field_ty.bitSize(mod);
    }
    unreachable; // index out of bounds
}
