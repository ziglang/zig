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

const Module = @This();
const Compilation = @import("Compilation.zig");
const Cache = std.Build.Cache;
const Value = @import("value.zig").Value;
const Type = @import("type.zig").Type;
const TypedValue = @import("TypedValue.zig");
const Package = @import("Package.zig");
const link = @import("link.zig");
const Air = @import("Air.zig");
const Zir = @import("Zir.zig");
const trace = @import("tracy.zig").trace;
const AstGen = @import("AstGen.zig");
const Sema = @import("Sema.zig");
const target_util = @import("target.zig");
const build_options = @import("build_options");
const Liveness = @import("Liveness.zig");
const isUpDir = @import("introspect.zig").isUpDir;
const clang = @import("clang.zig");
const InternPool = @import("InternPool.zig");
const Alignment = InternPool.Alignment;
const BuiltinFn = @import("BuiltinFn.zig");

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

/// Where build artifacts and incremental compilation metadata serialization go.
zig_cache_artifact_directory: Compilation.Directory,
/// Pointer to externally managed resource.
root_mod: *Package.Module,
/// Normally, `main_mod` and `root_mod` are the same. The exception is `zig test`, in which
/// `root_mod` is the test runner, and `main_mod` is the user's source file which has the tests.
main_mod: *Package.Module,
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
embed_table: std.StringHashMapUnmanaged(*EmbedFile) = .{},

/// Stores all Type and Value objects.
/// The idea is that this will be periodically garbage-collected, but such logic
/// is not yet implemented.
intern_pool: InternPool = .{},

/// The index type for this array is `CaptureScope.Index` and the elements here are
/// the indexes of the parent capture scopes.
/// Memory is owned by gpa; garbage collected.
capture_scope_parents: std.ArrayListUnmanaged(CaptureScope.Index) = .{},
/// Value is index of type
/// Memory is owned by gpa; garbage collected.
runtime_capture_scopes: std.AutoArrayHashMapUnmanaged(CaptureScope.Key, InternPool.Index) = .{},
/// Value is index of value
/// Memory is owned by gpa; garbage collected.
comptime_capture_scopes: std.AutoArrayHashMapUnmanaged(CaptureScope.Key, InternPool.Index) = .{},

/// To be eliminated in a future commit by moving more data into InternPool.
/// Current uses that must be eliminated:
/// * comptime pointer mutation
/// This memory lives until the Module is destroyed.
tmp_hack_arena: std.heap.ArenaAllocator,

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

/// Candidates for deletion. After a semantic analysis update completes, this list
/// contains Decls that need to be deleted if they end up having no references to them.
deletion_set: std.AutoArrayHashMapUnmanaged(Decl.Index, void) = .{},

/// Key is the error name, index is the error tag value. Index 0 has a length-0 string.
global_error_set: GlobalErrorSet = .{},

/// Maximum amount of distinct error values, set by --error-limit
error_limit: ErrorInt,

/// Incrementing integer used to compare against the corresponding Decl
/// field to determine whether a Decl's status applies to an ongoing update, or a
/// previous analysis.
generation: u32 = 0,

stage1_flags: packed struct {
    have_winmain: bool = false,
    have_wwinmain: bool = false,
    have_winmain_crt_startup: bool = false,
    have_wwinmain_crt_startup: bool = false,
    have_dllmain_crt_startup: bool = false,
    have_c_main: bool = false,
    reserved: u2 = 0,
} = .{},

job_queued_update_builtin_zig: bool = true,

compile_log_text: ArrayListUnmanaged(u8) = .{},

emit_h: ?*GlobalEmitH,

test_functions: std.AutoArrayHashMapUnmanaged(Decl.Index, void) = .{},

global_assembly: std.AutoHashMapUnmanaged(Decl.Index, []u8) = .{},

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
        linkage: std.builtin.GlobalLinkage = .Strong,
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

pub const CaptureScope = struct {
    pub const Key = extern struct {
        zir_index: Zir.Inst.Index,
        index: Index,
    };

    /// Index into `capture_scope_parents` which uniquely identifies a capture scope.
    pub const Index = enum(u32) {
        none = std.math.maxInt(u32),
        _,

        pub fn parent(i: Index, mod: *Module) Index {
            return mod.capture_scope_parents.items[@intFromEnum(i)];
        }
    };
};

pub fn createCaptureScope(mod: *Module, parent: CaptureScope.Index) error{OutOfMemory}!CaptureScope.Index {
    try mod.capture_scope_parents.append(mod.gpa, parent);
    return @enumFromInt(mod.capture_scope_parents.items.len - 1);
}

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
            return @fieldParentPtr(std.heap.ArenaAllocator, "state", state_acquired).allocator();
        }

        out_arena_allocator.* = self.state.promote(child_allocator);
        self.state_acquired = &out_arena_allocator.state;
        return out_arena_allocator.allocator();
    }

    /// Releases the allocator acquired by `acquire. `arena_allocator` must match the one passed to `acquire`.
    pub fn release(self: *ValueArena, arena_allocator: *std.heap.ArenaAllocator) void {
        if (@fieldParentPtr(std.heap.ArenaAllocator, "state", self.state_acquired.?) == arena_allocator) {
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
    /// The most recent Type of the Decl after a successful semantic analysis.
    /// Populated when `has_tv`.
    ty: Type,
    /// The most recent Value of the Decl after a successful semantic analysis.
    /// Populated when `has_tv`.
    val: Value,
    /// Populated when `has_tv`.
    @"linksection": InternPool.OptionalNullTerminatedString,
    /// Populated when `has_tv`.
    alignment: Alignment,
    /// Populated when `has_tv`.
    @"addrspace": std.builtin.AddressSpace,
    /// The direct parent namespace of the Decl.
    /// Reference to externally owned memory.
    /// In the case of the Decl corresponding to a file, this is
    /// the namespace of the struct, since there is no parent.
    src_namespace: Namespace.Index,

    /// The scope which lexically contains this decl.  A decl must depend
    /// on its lexical parent, in order to ensure that this pointer is valid.
    /// This scope is allocated out of the arena of the parent decl.
    src_scope: CaptureScope.Index,

    /// An integer that can be checked against the corresponding incrementing
    /// generation field of Module. This is used to determine whether `complete` status
    /// represents pre- or post- re-analysis.
    generation: u32,
    /// The AST node index of this declaration.
    /// Must be recomputed when the corresponding source file is modified.
    src_node: Ast.Node.Index,
    /// Line number corresponding to `src_node`. Stored separately so that source files
    /// do not need to be loaded into memory in order to compute debug line numbers.
    /// This value is absolute.
    src_line: u32,
    /// Index to ZIR `extra` array to the entry in the parent's decl structure
    /// (the part that says "for every decls_len"). The first item at this index is
    /// the contents hash, followed by line, name, etc.
    /// For anonymous decls and also the root Decl for a File, this is `none`.
    zir_decl_index: Zir.OptionalExtraIndex,

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
        /// There will be a corresponding ErrorMsg in Module.failed_files.
        file_failure,
        /// This Decl might be OK but it depends on another one which did not successfully complete
        /// semantic analysis.
        dependency_failure,
        /// Semantic analysis failure.
        /// There will be a corresponding ErrorMsg in Module.failed_decls.
        sema_failure,
        /// There will be a corresponding ErrorMsg in Module.failed_decls.
        /// This indicates the failure was something like running out of disk space,
        /// and attempting semantic analysis again may succeed.
        sema_failure_retryable,
        /// There will be a corresponding ErrorMsg in Module.failed_decls.
        liveness_failure,
        /// There will be a corresponding ErrorMsg in Module.failed_decls.
        codegen_failure,
        /// There will be a corresponding ErrorMsg in Module.failed_decls.
        /// This indicates the failure was something like running out of disk space,
        /// and attempting codegen again may succeed.
        codegen_failure_retryable,
        /// Everything is done. During an update, this Decl may be out of date, depending
        /// on its dependencies. The `generation` field can be used to determine if this
        /// completion status occurred before or after a given update.
        complete,
        /// A Module update is in progress, and this Decl has been flagged as being known
        /// to require re-analysis.
        outdated,
    },
    /// Whether `typed_value`, `align`, `linksection` and `addrspace` are populated.
    has_tv: bool,
    /// If `true` it means the `Decl` is the resource owner of the type/value associated
    /// with it. That means when `Decl` is destroyed, the cleanup code should additionally
    /// check if the value owns a `Namespace`, and destroy that too.
    owns_tv: bool,
    /// This flag is set when this Decl is added to `Module.deletion_set`, and cleared
    /// when removed.
    deletion_flag: bool,
    /// Whether the corresponding AST decl has a `pub` keyword.
    is_pub: bool,
    /// Whether the corresponding AST decl has a `export` keyword.
    is_exported: bool,
    /// Whether the ZIR code provides an align instruction.
    has_align: bool,
    /// Whether the ZIR code provides a linksection and address space instruction.
    has_linksection_or_addrspace: bool,
    /// Flag used by garbage collection to mark and sweep.
    /// Decls which correspond to an AST node always have this field set to `true`.
    /// Anonymous Decls are initialized with this field set to `false` and then it
    /// is the responsibility of machine code backends to mark it `true` whenever
    /// a `decl_ref` Value is encountered that points to this Decl.
    /// When the `codegen_decl` job is encountered in the main work queue, if the
    /// Decl is marked alive, then it sends the Decl to the linker. Otherwise it
    /// deletes the Decl on the spot.
    alive: bool,
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

    pub const Index = enum(u32) {
        _,

        pub fn toOptional(i: Index) OptionalIndex {
            return @as(OptionalIndex, @enumFromInt(@intFromEnum(i)));
        }
    };

    pub const OptionalIndex = enum(u32) {
        none = std.math.maxInt(u32),
        _,

        pub fn init(oi: ?Index) OptionalIndex {
            return @as(OptionalIndex, @enumFromInt(@intFromEnum(oi orelse return .none)));
        }

        pub fn unwrap(oi: OptionalIndex) ?Index {
            if (oi == .none) return null;
            return @as(Index, @enumFromInt(@intFromEnum(oi)));
        }
    };

    pub const DepsTable = std.AutoArrayHashMapUnmanaged(Decl.Index, DepType);

    /// Later types take priority; e.g. if a dependent decl has both `normal`
    /// and `function_body` dependencies on another decl, it will be marked as
    /// having a `function_body` dependency.
    pub const DepType = enum {
        /// The dependent references or uses the dependency's value, so must be
        /// updated whenever it is changed. However, if the dependency is a
        /// function and its type is unchanged, the dependent does not need to
        /// be updated.
        normal,
        /// The dependent performs an inline or comptime call to the dependency,
        /// or is a generic instantiation of it. It must therefore be updated
        /// whenever the dependency is updated, even if the function type
        /// remained the same.
        function_body,
    };

    /// This name is relative to the containing namespace of the decl.
    /// The memory is owned by the containing File ZIR.
    pub fn getName(decl: Decl, mod: *Module) ?[:0]const u8 {
        const zir = decl.getFileScope(mod).zir;
        return decl.getNameZir(zir);
    }

    pub fn getNameZir(decl: Decl, zir: Zir) ?[:0]const u8 {
        assert(decl.zir_decl_index != .none);
        const name_index = zir.extra[@intFromEnum(decl.zir_decl_index) + 5];
        if (name_index <= 1) return null;
        return zir.nullTerminatedString(name_index);
    }

    pub fn contentsHash(decl: Decl, mod: *Module) std.zig.SrcHash {
        const zir = decl.getFileScope(mod).zir;
        return decl.contentsHashZir(zir);
    }

    pub fn contentsHashZir(decl: Decl, zir: Zir) std.zig.SrcHash {
        assert(decl.zir_decl_index != .none);
        const hash_u32s = zir.extra[@intFromEnum(decl.zir_decl_index)..][0..4];
        const contents_hash = @as(std.zig.SrcHash, @bitCast(hash_u32s.*));
        return contents_hash;
    }

    pub fn zirBlockIndex(decl: *const Decl, mod: *Module) Zir.Inst.Index {
        assert(decl.zir_decl_index != .none);
        const zir = decl.getFileScope(mod).zir;
        return @enumFromInt(zir.extra[@intFromEnum(decl.zir_decl_index) + 6]);
    }

    pub fn zirAlignRef(decl: Decl, mod: *Module) Zir.Inst.Ref {
        if (!decl.has_align) return .none;
        assert(decl.zir_decl_index != .none);
        const zir = decl.getFileScope(mod).zir;
        return @enumFromInt(zir.extra[@intFromEnum(decl.zir_decl_index) + 8]);
    }

    pub fn zirLinksectionRef(decl: Decl, mod: *Module) Zir.Inst.Ref {
        if (!decl.has_linksection_or_addrspace) return .none;
        assert(decl.zir_decl_index != .none);
        const zir = decl.getFileScope(mod).zir;
        const extra_index = @intFromEnum(decl.zir_decl_index) + 8 + @intFromBool(decl.has_align);
        return @enumFromInt(zir.extra[extra_index]);
    }

    pub fn zirAddrspaceRef(decl: Decl, mod: *Module) Zir.Inst.Ref {
        if (!decl.has_linksection_or_addrspace) return .none;
        assert(decl.zir_decl_index != .none);
        const zir = decl.getFileScope(mod).zir;
        const extra_index = @intFromEnum(decl.zir_decl_index) + 8 + @intFromBool(decl.has_align) + 1;
        return @enumFromInt(zir.extra[extra_index]);
    }

    pub fn relativeToLine(decl: Decl, offset: u32) u32 {
        return decl.src_line + offset;
    }

    pub fn relativeToNodeIndex(decl: Decl, offset: i32) Ast.Node.Index {
        return @bitCast(offset + @as(i32, @bitCast(decl.src_node)));
    }

    pub fn nodeIndexToRelative(decl: Decl, node_index: Ast.Node.Index) i32 {
        return @as(i32, @bitCast(node_index)) - @as(i32, @bitCast(decl.src_node));
    }

    pub fn tokSrcLoc(decl: Decl, token_index: Ast.TokenIndex) LazySrcLoc {
        return .{ .token_offset = token_index - decl.srcToken() };
    }

    pub fn nodeSrcLoc(decl: Decl, node_index: Ast.Node.Index) LazySrcLoc {
        return LazySrcLoc.nodeOffset(decl.nodeIndexToRelative(node_index));
    }

    pub fn srcLoc(decl: Decl, mod: *Module) SrcLoc {
        return decl.nodeOffsetSrcLoc(0, mod);
    }

    pub fn nodeOffsetSrcLoc(decl: Decl, node_offset: i32, mod: *Module) SrcLoc {
        return .{
            .file_scope = decl.getFileScope(mod),
            .parent_decl_node = decl.src_node,
            .lazy = LazySrcLoc.nodeOffset(node_offset),
        };
    }

    pub fn srcToken(decl: Decl, mod: *Module) Ast.TokenIndex {
        const tree = &decl.getFileScope(mod).tree;
        return tree.firstToken(decl.src_node);
    }

    pub fn srcByteOffset(decl: Decl, mod: *Module) u32 {
        const tree = &decl.getFileScope(mod).tree;
        return tree.tokens.items(.start)[decl.srcToken()];
    }

    pub fn renderFullyQualifiedName(decl: Decl, mod: *Module, writer: anytype) !void {
        if (decl.name_fully_qualified) {
            try writer.print("{}", .{decl.name.fmt(&mod.intern_pool)});
        } else {
            try mod.namespacePtr(decl.src_namespace).renderFullyQualifiedName(mod, decl.name, writer);
        }
    }

    pub fn renderFullyQualifiedDebugName(decl: Decl, mod: *Module, writer: anytype) !void {
        return mod.namespacePtr(decl.src_namespace).renderFullyQualifiedDebugName(mod, decl.name, writer);
    }

    pub fn getFullyQualifiedName(decl: Decl, mod: *Module) !InternPool.NullTerminatedString {
        if (decl.name_fully_qualified) return decl.name;

        const ip = &mod.intern_pool;
        const count = count: {
            var count: usize = ip.stringToSlice(decl.name).len + 1;
            var ns: Namespace.Index = decl.src_namespace;
            while (true) {
                const namespace = mod.namespacePtr(ns);
                const ns_decl = mod.declPtr(namespace.getDeclIndex(mod));
                count += ip.stringToSlice(ns_decl.name).len + 1;
                ns = namespace.parent.unwrap() orelse {
                    count += namespace.file_scope.sub_file_path.len;
                    break :count count;
                };
            }
        };

        const gpa = mod.gpa;
        const start = ip.string_bytes.items.len;
        // Protects reads of interned strings from being reallocated during the call to
        // renderFullyQualifiedName.
        try ip.string_bytes.ensureUnusedCapacity(gpa, count);
        decl.renderFullyQualifiedName(mod, ip.string_bytes.writer(gpa)) catch unreachable;

        // Sanitize the name for nvptx which is more restrictive.
        // TODO This should be handled by the backend, not the frontend. Have a
        // look at how the C backend does it for inspiration.
        if (mod.comp.bin_file.options.target.cpu.arch.isNvptx()) {
            for (ip.string_bytes.items[start..]) |*byte| switch (byte.*) {
                '{', '}', '*', '[', ']', '(', ')', ',', ' ', '\'' => byte.* = '_',
                else => {},
            };
        }

        return ip.getOrPutTrailingString(gpa, ip.string_bytes.items.len - start);
    }

    pub fn typedValue(decl: Decl) error{AnalysisFail}!TypedValue {
        if (!decl.has_tv) return error.AnalysisFail;
        return TypedValue{ .ty = decl.ty, .val = decl.val };
    }

    pub fn internValue(decl: *Decl, mod: *Module) Allocator.Error!InternPool.Index {
        assert(decl.has_tv);
        const ip_index = try decl.val.intern(decl.ty, mod);
        decl.val = ip_index.toValue();
        return ip_index;
    }

    pub fn isFunction(decl: Decl, mod: *const Module) !bool {
        const tv = try decl.typedValue();
        return tv.ty.zigTypeTag(mod) == .Fn;
    }

    /// If the Decl owns its value and it is a struct, return it,
    /// otherwise null.
    pub fn getOwnedStruct(decl: Decl, mod: *Module) ?InternPool.Key.StructType {
        if (!decl.owns_tv) return null;
        if (decl.val.ip_index == .none) return null;
        return mod.typeToStruct(decl.val.toType());
    }

    /// If the Decl owns its value and it is a union, return it,
    /// otherwise null.
    pub fn getOwnedUnion(decl: Decl, mod: *Module) ?InternPool.UnionType {
        if (!decl.owns_tv) return null;
        if (decl.val.ip_index == .none) return null;
        return mod.typeToUnion(decl.val.toType());
    }

    pub fn getOwnedFunction(decl: Decl, mod: *Module) ?InternPool.Key.Func {
        const i = decl.getOwnedFunctionIndex();
        if (i == .none) return null;
        return switch (mod.intern_pool.indexToKey(i)) {
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
    pub fn getOwnedExternFunc(decl: Decl, mod: *Module) ?InternPool.Key.ExternFunc {
        return if (decl.owns_tv) decl.val.getExternFunc(mod) else null;
    }

    /// If the Decl owns its value and it is a variable, returns it,
    /// otherwise null.
    pub fn getOwnedVariable(decl: Decl, mod: *Module) ?InternPool.Key.Variable {
        return if (decl.owns_tv) decl.val.getVariable(mod) else null;
    }

    /// Gets the namespace that this Decl creates by being a struct, union,
    /// enum, or opaque.
    pub fn getInnerNamespaceIndex(decl: Decl, mod: *Module) Namespace.OptionalIndex {
        if (!decl.has_tv) return .none;
        return switch (decl.val.ip_index) {
            .empty_struct_type => .none,
            .none => .none,
            else => switch (mod.intern_pool.indexToKey(decl.val.toIntern())) {
                .opaque_type => |opaque_type| opaque_type.namespace.toOptional(),
                .struct_type => |struct_type| struct_type.namespace,
                .union_type => |union_type| union_type.namespace.toOptional(),
                .enum_type => |enum_type| enum_type.namespace,
                else => .none,
            },
        };
    }

    /// Like `getInnerNamespaceIndex`, but only returns it if the Decl is the owner.
    pub fn getOwnedInnerNamespaceIndex(decl: Decl, mod: *Module) Namespace.OptionalIndex {
        if (!decl.owns_tv) return .none;
        return decl.getInnerNamespaceIndex(mod);
    }

    /// Same as `getOwnedInnerNamespaceIndex` but additionally obtains the pointer.
    pub fn getOwnedInnerNamespace(decl: Decl, mod: *Module) ?*Namespace {
        return mod.namespacePtrUnwrap(decl.getOwnedInnerNamespaceIndex(mod));
    }

    /// Same as `getInnerNamespaceIndex` but additionally obtains the pointer.
    pub fn getInnerNamespace(decl: Decl, mod: *Module) ?*Namespace {
        return mod.namespacePtrUnwrap(decl.getInnerNamespaceIndex(mod));
    }

    pub fn dump(decl: *Decl) void {
        const loc = std.zig.findLineColumn(decl.scope.source.bytes, decl.src);
        std.debug.print("{s}:{d}:{d} name={d} status={s}", .{
            decl.scope.sub_file_path,
            loc.line + 1,
            loc.column + 1,
            @intFromEnum(decl.name),
            @tagName(decl.analysis),
        });
        if (decl.has_tv) {
            std.debug.print(" ty={} val={}", .{ decl.ty, decl.val });
        }
        std.debug.print("\n", .{});
    }

    pub fn getFileScope(decl: Decl, mod: *Module) *File {
        return mod.namespacePtr(decl.src_namespace).file_scope;
    }

    pub fn removeDependant(decl: *Decl, other: Decl.Index) void {
        assert(decl.dependants.swapRemove(other));
    }

    pub fn removeDependency(decl: *Decl, other: Decl.Index) void {
        assert(decl.dependencies.swapRemove(other));
    }

    pub fn getExternDecl(decl: Decl, mod: *Module) OptionalIndex {
        assert(decl.has_tv);
        return switch (mod.intern_pool.indexToKey(decl.val.toIntern())) {
            .variable => |variable| if (variable.is_extern) variable.decl.toOptional() else .none,
            .extern_func => |extern_func| extern_func.decl.toOptional(),
            else => .none,
        };
    }

    pub fn isExtern(decl: Decl, mod: *Module) bool {
        return decl.getExternDecl(mod) != .none;
    }

    pub fn getAlignment(decl: Decl, mod: *Module) Alignment {
        assert(decl.has_tv);
        if (decl.alignment != .none) return decl.alignment;
        return decl.ty.abiAlignment(mod);
    }
};

/// This state is attached to every Decl when Module emit_h is non-null.
pub const EmitH = struct {
    fwd_decl: ArrayListUnmanaged(u8) = .{},
};

pub const DeclAdapter = struct {
    mod: *Module,

    pub fn hash(self: @This(), s: InternPool.NullTerminatedString) u32 {
        _ = self;
        return std.hash.uint32(@intFromEnum(s));
    }

    pub fn eql(self: @This(), a: InternPool.NullTerminatedString, b_decl_index: Decl.Index, b_index: usize) bool {
        _ = b_index;
        const b_decl = self.mod.declPtr(b_decl_index);
        return a == b_decl.name;
    }
};

/// The container that structs, enums, unions, and opaques have.
pub const Namespace = struct {
    parent: OptionalIndex,
    file_scope: *File,
    /// Will be a struct, enum, union, or opaque.
    ty: Type,
    /// Direct children of the namespace. Used during an update to detect
    /// which decls have been added/removed from source.
    /// Declaration order is preserved via entry order.
    /// These are only declarations named directly by the AST; anonymous
    /// declarations are not stored here.
    decls: std.ArrayHashMapUnmanaged(Decl.Index, void, DeclContext, true) = .{},

    /// Key is usingnamespace Decl itself. To find the namespace being included,
    /// the Decl Value has to be resolved as a Type which has a Namespace.
    /// Value is whether the usingnamespace decl is marked `pub`.
    usingnamespace_set: std.AutoHashMapUnmanaged(Decl.Index, bool) = .{},

    pub const Index = enum(u32) {
        _,

        pub fn toOptional(i: Index) OptionalIndex {
            return @as(OptionalIndex, @enumFromInt(@intFromEnum(i)));
        }
    };

    pub const OptionalIndex = enum(u32) {
        none = std.math.maxInt(u32),
        _,

        pub fn init(oi: ?Index) OptionalIndex {
            return @as(OptionalIndex, @enumFromInt(@intFromEnum(oi orelse return .none)));
        }

        pub fn unwrap(oi: OptionalIndex) ?Index {
            if (oi == .none) return null;
            return @as(Index, @enumFromInt(@intFromEnum(oi)));
        }
    };

    const DeclContext = struct {
        module: *Module,

        pub fn hash(ctx: @This(), decl_index: Decl.Index) u32 {
            const decl = ctx.module.declPtr(decl_index);
            return std.hash.uint32(@intFromEnum(decl.name));
        }

        pub fn eql(ctx: @This(), a_decl_index: Decl.Index, b_decl_index: Decl.Index, b_index: usize) bool {
            _ = b_index;
            const a_decl = ctx.module.declPtr(a_decl_index);
            const b_decl = ctx.module.declPtr(b_decl_index);
            return a_decl.name == b_decl.name;
        }
    };

    pub fn deinit(ns: *Namespace, mod: *Module) void {
        ns.destroyDecls(mod);
        ns.* = undefined;
    }

    pub fn destroyDecls(ns: *Namespace, mod: *Module) void {
        const gpa = mod.gpa;

        var decls = ns.decls;
        ns.decls = .{};

        for (decls.keys()) |decl_index| {
            mod.destroyDecl(decl_index);
        }
        decls.deinit(gpa);

        ns.usingnamespace_set.deinit(gpa);
    }

    pub fn deleteAllDecls(
        ns: *Namespace,
        mod: *Module,
        outdated_decls: ?*std.AutoArrayHashMap(Decl.Index, void),
    ) !void {
        const gpa = mod.gpa;

        var decls = ns.decls;
        ns.decls = .{};

        // TODO rework this code to not panic on OOM.
        // (might want to coordinate with the clearDecl function)

        for (decls.keys()) |child_decl| {
            mod.clearDecl(child_decl, outdated_decls) catch @panic("out of memory");
            mod.destroyDecl(child_decl);
        }
        decls.deinit(gpa);

        ns.usingnamespace_set.deinit(gpa);
    }

    // This renders e.g. "std.fs.Dir.OpenOptions"
    pub fn renderFullyQualifiedName(
        ns: Namespace,
        mod: *Module,
        name: InternPool.NullTerminatedString,
        writer: anytype,
    ) @TypeOf(writer).Error!void {
        if (ns.parent.unwrap()) |parent| {
            const decl = mod.declPtr(ns.getDeclIndex(mod));
            try mod.namespacePtr(parent).renderFullyQualifiedName(mod, decl.name, writer);
        } else {
            try ns.file_scope.renderFullyQualifiedName(writer);
        }
        if (name != .empty) try writer.print(".{}", .{name.fmt(&mod.intern_pool)});
    }

    /// This renders e.g. "std/fs.zig:Dir.OpenOptions"
    pub fn renderFullyQualifiedDebugName(
        ns: Namespace,
        mod: *Module,
        name: InternPool.NullTerminatedString,
        writer: anytype,
    ) @TypeOf(writer).Error!void {
        const separator_char: u8 = if (ns.parent.unwrap()) |parent| sep: {
            const decl = mod.declPtr(ns.getDeclIndex(mod));
            try mod.namespacePtr(parent).renderFullyQualifiedDebugName(mod, decl.name, writer);
            break :sep '.';
        } else sep: {
            try ns.file_scope.renderFullyQualifiedDebugName(writer);
            break :sep ':';
        };
        if (name != .empty) try writer.print("{c}{}", .{ separator_char, name.fmt(&mod.intern_pool) });
    }

    pub fn getDeclIndex(ns: Namespace, mod: *Module) Decl.Index {
        return ns.ty.getOwnerDecl(mod);
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

    /// Used by change detection algorithm, after astgen, contains the
    /// set of decls that existed in the previous ZIR but not in the new one.
    deleted_decls: ArrayListUnmanaged(Decl.Index) = .{},
    /// Used by change detection algorithm, after astgen, contains the
    /// set of decls that existed both in the previous ZIR and in the new one,
    /// but their source code has been modified.
    outdated_decls: ArrayListUnmanaged(Decl.Index) = .{},

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
        log.debug("deinit File {s}", .{file.sub_file_path});
        file.deleted_decls.deinit(gpa);
        file.outdated_decls.deinit(gpa);
        file.references.deinit(gpa);
        if (file.root_decl.unwrap()) |root_decl| {
            mod.destroyDecl(root_decl);
        }
        gpa.free(file.sub_file_path);
        file.unload(gpa);
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
        file.deinit(mod);
        gpa.destroy(file);
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
        return ip.getOrPutTrailingString(mod.gpa, ip.string_bytes.items.len - start);
    }

    pub fn fullPath(file: File, ally: Allocator) ![]u8 {
        return file.mod.root.joinString(ally, file.sub_file_path);
    }

    pub fn fullPathZ(file: File, ally: Allocator) ![:0]u8 {
        return file.mod.root.joinStringZ(ally, file.sub_file_path);
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

    pub const Span = struct {
        start: u32,
        end: u32,
        main: u32,
    };

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
                return nodeToSpan(tree, node);
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
                return nodeToSpan(tree, node);
            },
            .node_offset_main_token => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const node = src_loc.declRelativeToNodeIndex(node_off);
                const main_token = tree.nodes.items(.main_token)[node];
                return tokensToSpan(tree, main_token, main_token, main_token);
            },
            .node_offset_bin_op => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const node = src_loc.declRelativeToNodeIndex(node_off);
                assert(src_loc.file_scope.tree_loaded);
                return nodeToSpan(tree, node);
            },
            .node_offset_initializer => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const node = src_loc.declRelativeToNodeIndex(node_off);
                return tokensToSpan(
                    tree,
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
                        return nodeToSpan(tree, node_data[node].lhs);
                    },
                    else => unreachable,
                };
                if (full.ast.type_node != 0) {
                    return nodeToSpan(tree, full.ast.type_node);
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
                return nodeToSpan(tree, full.ast.align_node);
            },
            .node_offset_var_decl_section => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const node = src_loc.declRelativeToNodeIndex(node_off);
                const full = tree.fullVarDecl(node).?;
                return nodeToSpan(tree, full.ast.section_node);
            },
            .node_offset_var_decl_addrspace => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const node = src_loc.declRelativeToNodeIndex(node_off);
                const full = tree.fullVarDecl(node).?;
                return nodeToSpan(tree, full.ast.addrspace_node);
            },
            .node_offset_var_decl_init => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const node = src_loc.declRelativeToNodeIndex(node_off);
                const full = tree.fullVarDecl(node).?;
                return nodeToSpan(tree, full.ast.init_node);
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

                return nodeToSpan(tree, node);
            },
            .node_offset_array_access_index => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const node_datas = tree.nodes.items(.data);
                const node = src_loc.declRelativeToNodeIndex(node_off);
                return nodeToSpan(tree, node_datas[node].rhs);
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
                return nodeToSpan(tree, part_node);
            },
            .node_offset_call_func => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const node = src_loc.declRelativeToNodeIndex(node_off);
                var buf: [1]Ast.Node.Index = undefined;
                const full = tree.fullCall(&buf, node).?;
                return nodeToSpan(tree, full.ast.fn_expr);
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
            .node_offset_deref_ptr => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const node = src_loc.declRelativeToNodeIndex(node_off);
                return nodeToSpan(tree, node);
            },
            .node_offset_asm_source => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const node = src_loc.declRelativeToNodeIndex(node_off);
                const full = tree.fullAsm(node).?;
                return nodeToSpan(tree, full.ast.template);
            },
            .node_offset_asm_ret_ty => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const node = src_loc.declRelativeToNodeIndex(node_off);
                const full = tree.fullAsm(node).?;
                const asm_output = full.outputs[0];
                const node_datas = tree.nodes.items(.data);
                return nodeToSpan(tree, node_datas[asm_output].lhs);
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
                        return tokensToSpan(tree, start, end, start);
                    },

                    .@"orelse" => node,
                    .@"catch" => node,
                    else => unreachable,
                };
                return nodeToSpan(tree, src_node);
            },
            .for_input => |for_input| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const node = src_loc.declRelativeToNodeIndex(for_input.for_node_offset);
                const for_full = tree.fullFor(node).?;
                const src_node = for_full.ast.inputs[for_input.input_index];
                return nodeToSpan(tree, src_node);
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
                                                    return tokensToSpan(tree, tok, tok + 1, tok);
                                                tok += 1;
                                            },
                                            .asterisk => {
                                                if (count == 0)
                                                    return tokensToSpan(tree, tok, tok + 2, tok);
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
                            return nodeToSpan(tree, full[call_arg.arg_index]);
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
                            return nodeToSpan(tree, full[call_arg.arg_index]);
                        },
                        else => return nodeToSpan(tree, call_args_node),
                    }
                };
                return nodeToSpan(tree, call_full.ast.params[call_arg.arg_index]);
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
                        if (param.anytype_ellipsis3) |token| return tokenToSpan(tree, token);
                        const first_token = param.comptime_noalias orelse
                            param.name_token orelse
                            tree.firstToken(param.type_expr);
                        return tokensToSpan(
                            tree,
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
                return nodeToSpan(tree, node_datas[node].lhs);
            },
            .node_offset_bin_rhs => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const node = src_loc.declRelativeToNodeIndex(node_off);
                const node_datas = tree.nodes.items(.data);
                return nodeToSpan(tree, node_datas[node].rhs);
            },

            .node_offset_switch_operand => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const node = src_loc.declRelativeToNodeIndex(node_off);
                const node_datas = tree.nodes.items(.data);
                return nodeToSpan(tree, node_datas[node].lhs);
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

                    return nodeToSpan(tree, case_node);
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
                            return nodeToSpan(tree, item_node);
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
                return nodeToSpan(tree, full.ast.align_expr);
            },
            .node_offset_fn_type_addrspace => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const node = src_loc.declRelativeToNodeIndex(node_off);
                var buf: [1]Ast.Node.Index = undefined;
                const full = tree.fullFnProto(&buf, node).?;
                return nodeToSpan(tree, full.ast.addrspace_expr);
            },
            .node_offset_fn_type_section => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const node = src_loc.declRelativeToNodeIndex(node_off);
                var buf: [1]Ast.Node.Index = undefined;
                const full = tree.fullFnProto(&buf, node).?;
                return nodeToSpan(tree, full.ast.section_expr);
            },
            .node_offset_fn_type_cc => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const node = src_loc.declRelativeToNodeIndex(node_off);
                var buf: [1]Ast.Node.Index = undefined;
                const full = tree.fullFnProto(&buf, node).?;
                return nodeToSpan(tree, full.ast.callconv_expr);
            },

            .node_offset_fn_type_ret_ty => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const node = src_loc.declRelativeToNodeIndex(node_off);
                var buf: [1]Ast.Node.Index = undefined;
                const full = tree.fullFnProto(&buf, node).?;
                return nodeToSpan(tree, full.ast.return_type);
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
                return tokensToSpan(
                    tree,
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
                return tokensToSpan(
                    tree,
                    first_tok,
                    tok_index,
                    first_tok,
                );
            },

            .node_offset_anyframe_type => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const node_datas = tree.nodes.items(.data);
                const parent_node = src_loc.declRelativeToNodeIndex(node_off);
                return nodeToSpan(tree, node_datas[parent_node].rhs);
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
                return nodeToSpan(tree, full.ast.elem_count);
            },
            .node_offset_array_type_sentinel => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const parent_node = src_loc.declRelativeToNodeIndex(node_off);

                const full = tree.fullArrayType(parent_node).?;
                return nodeToSpan(tree, full.ast.sentinel);
            },
            .node_offset_array_type_elem => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const parent_node = src_loc.declRelativeToNodeIndex(node_off);

                const full = tree.fullArrayType(parent_node).?;
                return nodeToSpan(tree, full.ast.elem_type);
            },
            .node_offset_un_op => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const node_datas = tree.nodes.items(.data);
                const node = src_loc.declRelativeToNodeIndex(node_off);

                return nodeToSpan(tree, node_datas[node].lhs);
            },
            .node_offset_ptr_elem => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const parent_node = src_loc.declRelativeToNodeIndex(node_off);

                const full = tree.fullPtrType(parent_node).?;
                return nodeToSpan(tree, full.ast.child_type);
            },
            .node_offset_ptr_sentinel => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const parent_node = src_loc.declRelativeToNodeIndex(node_off);

                const full = tree.fullPtrType(parent_node).?;
                return nodeToSpan(tree, full.ast.sentinel);
            },
            .node_offset_ptr_align => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const parent_node = src_loc.declRelativeToNodeIndex(node_off);

                const full = tree.fullPtrType(parent_node).?;
                return nodeToSpan(tree, full.ast.align_node);
            },
            .node_offset_ptr_addrspace => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const parent_node = src_loc.declRelativeToNodeIndex(node_off);

                const full = tree.fullPtrType(parent_node).?;
                return nodeToSpan(tree, full.ast.addrspace_node);
            },
            .node_offset_ptr_bitoffset => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const parent_node = src_loc.declRelativeToNodeIndex(node_off);

                const full = tree.fullPtrType(parent_node).?;
                return nodeToSpan(tree, full.ast.bit_range_start);
            },
            .node_offset_ptr_hostsize => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const parent_node = src_loc.declRelativeToNodeIndex(node_off);

                const full = tree.fullPtrType(parent_node).?;
                return nodeToSpan(tree, full.ast.bit_range_end);
            },
            .node_offset_container_tag => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const node_tags = tree.nodes.items(.tag);
                const parent_node = src_loc.declRelativeToNodeIndex(node_off);

                switch (node_tags[parent_node]) {
                    .container_decl_arg, .container_decl_arg_trailing => {
                        const full = tree.containerDeclArg(parent_node);
                        return nodeToSpan(tree, full.ast.arg);
                    },
                    .tagged_union_enum_tag, .tagged_union_enum_tag_trailing => {
                        const full = tree.taggedUnionEnumTag(parent_node);

                        return tokensToSpan(
                            tree,
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
                return nodeToSpan(tree, full.ast.value_expr);
            },
            .node_offset_init_ty => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const parent_node = src_loc.declRelativeToNodeIndex(node_off);

                var buf: [2]Ast.Node.Index = undefined;
                const full = tree.fullArrayInit(&buf, parent_node).?;
                return nodeToSpan(tree, full.ast.type_expr);
            },
            .node_offset_store_ptr => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const node_tags = tree.nodes.items(.tag);
                const node_datas = tree.nodes.items(.data);
                const node = src_loc.declRelativeToNodeIndex(node_off);

                switch (node_tags[node]) {
                    .assign => {
                        return nodeToSpan(tree, node_datas[node].lhs);
                    },
                    else => return nodeToSpan(tree, node),
                }
            },
            .node_offset_store_operand => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const node_tags = tree.nodes.items(.tag);
                const node_datas = tree.nodes.items(.data);
                const node = src_loc.declRelativeToNodeIndex(node_off);

                switch (node_tags[node]) {
                    .assign => {
                        return nodeToSpan(tree, node_datas[node].rhs);
                    },
                    else => return nodeToSpan(tree, node),
                }
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
        return nodeToSpan(tree, param);
    }

    pub fn nodeToSpan(tree: *const Ast, node: u32) Span {
        return tokensToSpan(
            tree,
            tree.firstToken(node),
            tree.lastToken(node),
            tree.nodes.items(.main_token)[node],
        );
    }

    fn tokenToSpan(tree: *const Ast, token: Ast.TokenIndex) Span {
        return tokensToSpan(tree, token, token, token);
    }

    fn tokensToSpan(tree: *const Ast, start: Ast.TokenIndex, end: Ast.TokenIndex, main: Ast.TokenIndex) Span {
        const token_starts = tree.tokens.items(.start);
        var start_tok = start;
        var end_tok = end;

        if (tree.tokensOnSameLine(start, end)) {
            // do nothing
        } else if (tree.tokensOnSameLine(start, main)) {
            end_tok = main;
        } else if (tree.tokensOnSameLine(main, end)) {
            start_tok = main;
        } else {
            start_tok = main;
            end_tok = main;
        }
        const start_off = token_starts[start_tok];
        const end_off = token_starts[end_tok] + @as(u32, @intCast(tree.tokenSlice(end_tok).len));
        return Span{ .start = start_off, .end = end_off, .main = token_starts[main] };
    }
};

/// This wraps a simple integer in debug builds so that later on we can find out
/// where in semantic analysis the value got set.
const TracedOffset = struct {
    x: i32,
    trace: std.debug.Trace = .{},

    const want_tracing = build_options.value_tracing;
};

/// Resolving a source location into a byte offset may require doing work
/// that we would rather not do unless the error actually occurs.
/// Therefore we need a data structure that contains the information necessary
/// to lazily produce a `SrcLoc` as required.
/// Most of the offsets in this data structure are relative to the containing Decl.
/// This makes the source location resolve properly even when a Decl gets
/// shifted up or down in the file, as long as the Decl's contents itself
/// do not change.
pub const LazySrcLoc = union(enum) {
    /// When this tag is set, the code that constructed this `LazySrcLoc` is asserting
    /// that all code paths which would need to resolve the source location are
    /// unreachable. If you are debugging this tag incorrectly being this value,
    /// look into using reverse-continue with a memory watchpoint to see where the
    /// value is being set to this tag.
    unneeded,
    /// Means the source location points to an entire file; not any particular
    /// location within the file. `file_scope` union field will be active.
    entire_file,
    /// The source location points to a byte offset within a source file,
    /// offset from 0. The source file is determined contextually.
    /// Inside a `SrcLoc`, the `file_scope` union field will be active.
    byte_abs: u32,
    /// The source location points to a token within a source file,
    /// offset from 0. The source file is determined contextually.
    /// Inside a `SrcLoc`, the `file_scope` union field will be active.
    token_abs: u32,
    /// The source location points to an AST node within a source file,
    /// offset from 0. The source file is determined contextually.
    /// Inside a `SrcLoc`, the `file_scope` union field will be active.
    node_abs: u32,
    /// The source location points to a byte offset within a source file,
    /// offset from the byte offset of the Decl within the file.
    /// The Decl is determined contextually.
    byte_offset: u32,
    /// This data is the offset into the token list from the Decl token.
    /// The Decl is determined contextually.
    token_offset: u32,
    /// The source location points to an AST node, which is this value offset
    /// from its containing Decl node AST index.
    /// The Decl is determined contextually.
    node_offset: TracedOffset,
    /// The source location points to the main token of an AST node, found
    /// by taking this AST node index offset from the containing Decl AST node.
    /// The Decl is determined contextually.
    node_offset_main_token: i32,
    /// The source location points to the beginning of a struct initializer.
    /// The Decl is determined contextually.
    node_offset_initializer: i32,
    /// The source location points to a variable declaration type expression,
    /// found by taking this AST node index offset from the containing
    /// Decl AST node, which points to a variable declaration AST node. Next, navigate
    /// to the type expression.
    /// The Decl is determined contextually.
    node_offset_var_decl_ty: i32,
    /// The source location points to the alignment expression of a var decl.
    /// The Decl is determined contextually.
    node_offset_var_decl_align: i32,
    /// The source location points to the linksection expression of a var decl.
    /// The Decl is determined contextually.
    node_offset_var_decl_section: i32,
    /// The source location points to the addrspace expression of a var decl.
    /// The Decl is determined contextually.
    node_offset_var_decl_addrspace: i32,
    /// The source location points to the initializer of a var decl.
    /// The Decl is determined contextually.
    node_offset_var_decl_init: i32,
    /// The source location points to the first parameter of a builtin
    /// function call, found by taking this AST node index offset from the containing
    /// Decl AST node, which points to a builtin call AST node. Next, navigate
    /// to the first parameter.
    /// The Decl is determined contextually.
    node_offset_builtin_call_arg0: i32,
    /// Same as `node_offset_builtin_call_arg0` except arg index 1.
    node_offset_builtin_call_arg1: i32,
    node_offset_builtin_call_arg2: i32,
    node_offset_builtin_call_arg3: i32,
    node_offset_builtin_call_arg4: i32,
    node_offset_builtin_call_arg5: i32,
    /// Like `node_offset_builtin_call_arg0` but recurses through arbitrarily many calls
    /// to pointer cast builtins.
    node_offset_ptrcast_operand: i32,
    /// The source location points to the index expression of an array access
    /// expression, found by taking this AST node index offset from the containing
    /// Decl AST node, which points to an array access AST node. Next, navigate
    /// to the index expression.
    /// The Decl is determined contextually.
    node_offset_array_access_index: i32,
    /// The source location points to the LHS of a slice expression
    /// expression, found by taking this AST node index offset from the containing
    /// Decl AST node, which points to a slice AST node. Next, navigate
    /// to the sentinel expression.
    /// The Decl is determined contextually.
    node_offset_slice_ptr: i32,
    /// The source location points to start expression of a slice expression
    /// expression, found by taking this AST node index offset from the containing
    /// Decl AST node, which points to a slice AST node. Next, navigate
    /// to the sentinel expression.
    /// The Decl is determined contextually.
    node_offset_slice_start: i32,
    /// The source location points to the end expression of a slice
    /// expression, found by taking this AST node index offset from the containing
    /// Decl AST node, which points to a slice AST node. Next, navigate
    /// to the sentinel expression.
    /// The Decl is determined contextually.
    node_offset_slice_end: i32,
    /// The source location points to the sentinel expression of a slice
    /// expression, found by taking this AST node index offset from the containing
    /// Decl AST node, which points to a slice AST node. Next, navigate
    /// to the sentinel expression.
    /// The Decl is determined contextually.
    node_offset_slice_sentinel: i32,
    /// The source location points to the callee expression of a function
    /// call expression, found by taking this AST node index offset from the containing
    /// Decl AST node, which points to a function call AST node. Next, navigate
    /// to the callee expression.
    /// The Decl is determined contextually.
    node_offset_call_func: i32,
    /// The payload is offset from the containing Decl AST node.
    /// The source location points to the field name of:
    ///  * a field access expression (`a.b`), or
    ///  * the callee of a method call (`a.b()`), or
    ///  * the operand ("b" node) of a field initialization expression (`.a = b`), or
    /// The Decl is determined contextually.
    node_offset_field_name: i32,
    /// The source location points to the pointer of a pointer deref expression,
    /// found by taking this AST node index offset from the containing
    /// Decl AST node, which points to a pointer deref AST node. Next, navigate
    /// to the pointer expression.
    /// The Decl is determined contextually.
    node_offset_deref_ptr: i32,
    /// The source location points to the assembly source code of an inline assembly
    /// expression, found by taking this AST node index offset from the containing
    /// Decl AST node, which points to inline assembly AST node. Next, navigate
    /// to the asm template source code.
    /// The Decl is determined contextually.
    node_offset_asm_source: i32,
    /// The source location points to the return type of an inline assembly
    /// expression, found by taking this AST node index offset from the containing
    /// Decl AST node, which points to inline assembly AST node. Next, navigate
    /// to the return type expression.
    /// The Decl is determined contextually.
    node_offset_asm_ret_ty: i32,
    /// The source location points to the condition expression of an if
    /// expression, found by taking this AST node index offset from the containing
    /// Decl AST node, which points to an if expression AST node. Next, navigate
    /// to the condition expression.
    /// The Decl is determined contextually.
    node_offset_if_cond: i32,
    /// The source location points to a binary expression, such as `a + b`, found
    /// by taking this AST node index offset from the containing Decl AST node.
    /// The Decl is determined contextually.
    node_offset_bin_op: i32,
    /// The source location points to the LHS of a binary expression, found
    /// by taking this AST node index offset from the containing Decl AST node,
    /// which points to a binary expression AST node. Next, navigate to the LHS.
    /// The Decl is determined contextually.
    node_offset_bin_lhs: i32,
    /// The source location points to the RHS of a binary expression, found
    /// by taking this AST node index offset from the containing Decl AST node,
    /// which points to a binary expression AST node. Next, navigate to the RHS.
    /// The Decl is determined contextually.
    node_offset_bin_rhs: i32,
    /// The source location points to the operand of a switch expression, found
    /// by taking this AST node index offset from the containing Decl AST node,
    /// which points to a switch expression AST node. Next, navigate to the operand.
    /// The Decl is determined contextually.
    node_offset_switch_operand: i32,
    /// The source location points to the else/`_` prong of a switch expression, found
    /// by taking this AST node index offset from the containing Decl AST node,
    /// which points to a switch expression AST node. Next, navigate to the else/`_` prong.
    /// The Decl is determined contextually.
    node_offset_switch_special_prong: i32,
    /// The source location points to all the ranges of a switch expression, found
    /// by taking this AST node index offset from the containing Decl AST node,
    /// which points to a switch expression AST node. Next, navigate to any of the
    /// range nodes. The error applies to all of them.
    /// The Decl is determined contextually.
    node_offset_switch_range: i32,
    /// The source location points to the capture of a switch_prong.
    /// The Decl is determined contextually.
    node_offset_switch_prong_capture: i32,
    /// The source location points to the tag capture of a switch_prong.
    /// The Decl is determined contextually.
    node_offset_switch_prong_tag_capture: i32,
    /// The source location points to the align expr of a function type
    /// expression, found by taking this AST node index offset from the containing
    /// Decl AST node, which points to a function type AST node. Next, navigate to
    /// the calling convention node.
    /// The Decl is determined contextually.
    node_offset_fn_type_align: i32,
    /// The source location points to the addrspace expr of a function type
    /// expression, found by taking this AST node index offset from the containing
    /// Decl AST node, which points to a function type AST node. Next, navigate to
    /// the calling convention node.
    /// The Decl is determined contextually.
    node_offset_fn_type_addrspace: i32,
    /// The source location points to the linksection expr of a function type
    /// expression, found by taking this AST node index offset from the containing
    /// Decl AST node, which points to a function type AST node. Next, navigate to
    /// the calling convention node.
    /// The Decl is determined contextually.
    node_offset_fn_type_section: i32,
    /// The source location points to the calling convention of a function type
    /// expression, found by taking this AST node index offset from the containing
    /// Decl AST node, which points to a function type AST node. Next, navigate to
    /// the calling convention node.
    /// The Decl is determined contextually.
    node_offset_fn_type_cc: i32,
    /// The source location points to the return type of a function type
    /// expression, found by taking this AST node index offset from the containing
    /// Decl AST node, which points to a function type AST node. Next, navigate to
    /// the return type node.
    /// The Decl is determined contextually.
    node_offset_fn_type_ret_ty: i32,
    node_offset_param: i32,
    token_offset_param: i32,
    /// The source location points to the type expression of an `anyframe->T`
    /// expression, found by taking this AST node index offset from the containing
    /// Decl AST node, which points to a `anyframe->T` expression AST node. Next, navigate
    /// to the type expression.
    /// The Decl is determined contextually.
    node_offset_anyframe_type: i32,
    /// The source location points to the string literal of `extern "foo"`, found
    /// by taking this AST node index offset from the containing
    /// Decl AST node, which points to a function prototype or variable declaration
    /// expression AST node. Next, navigate to the string literal of the `extern "foo"`.
    /// The Decl is determined contextually.
    node_offset_lib_name: i32,
    /// The source location points to the len expression of an `[N:S]T`
    /// expression, found by taking this AST node index offset from the containing
    /// Decl AST node, which points to an `[N:S]T` expression AST node. Next, navigate
    /// to the len expression.
    /// The Decl is determined contextually.
    node_offset_array_type_len: i32,
    /// The source location points to the sentinel expression of an `[N:S]T`
    /// expression, found by taking this AST node index offset from the containing
    /// Decl AST node, which points to an `[N:S]T` expression AST node. Next, navigate
    /// to the sentinel expression.
    /// The Decl is determined contextually.
    node_offset_array_type_sentinel: i32,
    /// The source location points to the elem expression of an `[N:S]T`
    /// expression, found by taking this AST node index offset from the containing
    /// Decl AST node, which points to an `[N:S]T` expression AST node. Next, navigate
    /// to the elem expression.
    /// The Decl is determined contextually.
    node_offset_array_type_elem: i32,
    /// The source location points to the operand of an unary expression.
    /// The Decl is determined contextually.
    node_offset_un_op: i32,
    /// The source location points to the elem type of a pointer.
    /// The Decl is determined contextually.
    node_offset_ptr_elem: i32,
    /// The source location points to the sentinel of a pointer.
    /// The Decl is determined contextually.
    node_offset_ptr_sentinel: i32,
    /// The source location points to the align expr of a pointer.
    /// The Decl is determined contextually.
    node_offset_ptr_align: i32,
    /// The source location points to the addrspace expr of a pointer.
    /// The Decl is determined contextually.
    node_offset_ptr_addrspace: i32,
    /// The source location points to the bit-offset of a pointer.
    /// The Decl is determined contextually.
    node_offset_ptr_bitoffset: i32,
    /// The source location points to the host size of a pointer.
    /// The Decl is determined contextually.
    node_offset_ptr_hostsize: i32,
    /// The source location points to the tag type of an union or an enum.
    /// The Decl is determined contextually.
    node_offset_container_tag: i32,
    /// The source location points to the default value of a field.
    /// The Decl is determined contextually.
    node_offset_field_default: i32,
    /// The source location points to the type of an array or struct initializer.
    /// The Decl is determined contextually.
    node_offset_init_ty: i32,
    /// The source location points to the LHS of an assignment.
    /// The Decl is determined contextually.
    node_offset_store_ptr: i32,
    /// The source location points to the RHS of an assignment.
    /// The Decl is determined contextually.
    node_offset_store_operand: i32,
    /// The source location points to a for loop input.
    /// The Decl is determined contextually.
    for_input: struct {
        /// Points to the for loop AST node.
        for_node_offset: i32,
        /// Picks one of the inputs from the condition.
        input_index: u32,
    },
    /// The source location points to one of the captures of a for loop, found
    /// by taking this AST node index offset from the containing
    /// Decl AST node, which points to one of the input nodes of a for loop.
    /// Next, navigate to the corresponding capture.
    /// The Decl is determined contextually.
    for_capture_from_input: i32,
    /// The source location points to the argument node of a function call.
    call_arg: struct {
        decl: Decl.Index,
        /// Points to the function call AST node.
        call_node_offset: i32,
        /// The index of the argument the source location points to.
        arg_index: u32,
    },
    fn_proto_param: struct {
        decl: Decl.Index,
        /// Points to the function prototype AST node.
        fn_proto_node_offset: i32,
        /// The index of the parameter the source location points to.
        param_index: u32,
    },

    pub const nodeOffset = if (TracedOffset.want_tracing) nodeOffsetDebug else nodeOffsetRelease;

    noinline fn nodeOffsetDebug(node_offset: i32) LazySrcLoc {
        var result: LazySrcLoc = .{ .node_offset = .{ .x = node_offset } };
        result.node_offset.trace.addAddr(@returnAddress(), "init");
        return result;
    }

    fn nodeOffsetRelease(node_offset: i32) LazySrcLoc {
        return .{ .node_offset = .{ .x = node_offset } };
    }

    /// Upgrade to a `SrcLoc` based on the `Decl` provided.
    pub fn toSrcLoc(lazy: LazySrcLoc, decl: *Decl, mod: *Module) SrcLoc {
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
            .for_input,
            .for_capture_from_input,
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

pub fn deinit(mod: *Module) void {
    const gpa = mod.gpa;

    for (mod.import_table.keys()) |key| {
        gpa.free(key);
    }
    var failed_decls = mod.failed_decls;
    mod.failed_decls = .{};
    for (mod.import_table.values()) |value| {
        value.destroy(mod);
    }
    mod.import_table.deinit(gpa);

    {
        var it = mod.embed_table.iterator();
        while (it.next()) |entry| {
            gpa.free(entry.key_ptr.*);
            const ef: *EmbedFile = entry.value_ptr.*;
            gpa.destroy(ef);
        }
        mod.embed_table.deinit(gpa);
    }

    mod.deletion_set.deinit(gpa);
    mod.compile_log_text.deinit(gpa);

    mod.zig_cache_artifact_directory.handle.close();
    mod.local_zir_cache.handle.close();
    mod.global_zir_cache.handle.close();

    for (failed_decls.values()) |value| {
        value.destroy(gpa);
    }
    failed_decls.deinit(gpa);

    if (mod.emit_h) |emit_h| {
        for (emit_h.failed_decls.values()) |value| {
            value.destroy(gpa);
        }
        emit_h.failed_decls.deinit(gpa);
        emit_h.decl_table.deinit(gpa);
        emit_h.allocated_emit_h.deinit(gpa);
        gpa.destroy(emit_h);
    }

    for (mod.failed_files.values()) |value| {
        if (value) |msg| msg.destroy(gpa);
    }
    mod.failed_files.deinit(gpa);

    for (mod.failed_embed_files.values()) |msg| {
        msg.destroy(gpa);
    }
    mod.failed_embed_files.deinit(gpa);

    for (mod.failed_exports.values()) |value| {
        value.destroy(gpa);
    }
    mod.failed_exports.deinit(gpa);

    for (mod.cimport_errors.values()) |*errs| {
        errs.deinit(gpa);
    }
    mod.cimport_errors.deinit(gpa);

    mod.compile_log_decls.deinit(gpa);

    for (mod.decl_exports.values()) |*export_list| {
        export_list.deinit(gpa);
    }
    mod.decl_exports.deinit(gpa);

    for (mod.value_exports.values()) |*export_list| {
        export_list.deinit(gpa);
    }
    mod.value_exports.deinit(gpa);

    for (mod.export_owners.values()) |*value| {
        freeExportList(gpa, value);
    }
    mod.export_owners.deinit(gpa);

    mod.global_error_set.deinit(gpa);

    mod.test_functions.deinit(gpa);

    mod.global_assembly.deinit(gpa);
    mod.reference_table.deinit(gpa);

    mod.intern_pool.deinit(gpa);
    mod.tmp_hack_arena.deinit();

    mod.capture_scope_parents.deinit(gpa);
    mod.runtime_capture_scopes.deinit(gpa);
    mod.comptime_capture_scopes.deinit(gpa);
}

pub fn destroyDecl(mod: *Module, decl_index: Decl.Index) void {
    const gpa = mod.gpa;
    const ip = &mod.intern_pool;

    {
        const decl = mod.declPtr(decl_index);
        _ = mod.test_functions.swapRemove(decl_index);
        if (decl.deletion_flag) {
            assert(mod.deletion_set.swapRemove(decl_index));
        }
        if (mod.global_assembly.fetchRemove(decl_index)) |kv| {
            gpa.free(kv.value);
        }
        if (decl.has_tv) {
            if (decl.getOwnedInnerNamespaceIndex(mod).unwrap()) |i| {
                mod.namespacePtr(i).destroyDecls(mod);
                mod.destroyNamespace(i);
            }
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
    if (namespace.parent != .none)
        return false;
    return decl_index == namespace.getDeclIndex(mod);
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
    const tracy = trace(@src());
    defer tracy.end();

    const comp = mod.comp;
    const gpa = mod.gpa;

    // In any case we need to examine the stat of the file to determine the course of action.
    var source_file = try file.mod.root.openFile(file.sub_file_path, .{});
    defer source_file.close();

    const stat = try source_file.stat();

    const want_local_cache = file.mod == mod.main_mod;
    const digest = hash: {
        var path_hash: Cache.HashHelper = .{};
        path_hash.addBytes(build_options.version);
        path_hash.add(builtin.zig_backend);
        if (!want_local_cache) {
            path_hash.addOptionalBytes(file.mod.root.root_dir.path);
            path_hash.addBytes(file.mod.root.sub_path);
        }
        path_hash.addBytes(file.sub_file_path);
        break :hash path_hash.final();
    };
    const cache_directory = if (want_local_cache) mod.local_zir_cache else mod.global_zir_cache;
    const zir_dir = cache_directory.handle;

    // Determine whether we need to reload the file from disk and redo parsing and AstGen.
    var lock: std.fs.File.Lock = switch (file.status) {
        .never_loaded, .retryable_failure => lock: {
            // First, load the cached ZIR code, if any.
            log.debug("AstGen checking cache: {s} (local={}, digest={s})", .{
                file.sub_file_path, want_local_cache, &digest,
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
        break zir_dir.createFile(&digest, .{
            .read = true,
            .truncate = false,
            .lock = lock,
        }) catch |err| switch (err) {
            error.NotDir => unreachable, // no dir components
            error.InvalidUtf8 => unreachable, // it's a hex encoded name
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
    var iovecs = [_]std.os.iovec_const{
        .{
            .iov_base = @as([*]const u8, @ptrCast(&header)),
            .iov_len = @sizeOf(Zir.Header),
        },
        .{
            .iov_base = @as([*]const u8, @ptrCast(file.zir.instructions.items(.tag).ptr)),
            .iov_len = file.zir.instructions.len,
        },
        .{
            .iov_base = data_ptr,
            .iov_len = file.zir.instructions.len * 8,
        },
        .{
            .iov_base = file.zir.string_bytes.ptr,
            .iov_len = file.zir.string_bytes.len,
        },
        .{
            .iov_base = @as([*]const u8, @ptrCast(file.zir.extra.ptr)),
            .iov_len = file.zir.extra.len * 4,
        },
    };
    cache_file.writevAll(&iovecs) catch |err| {
        log.warn("unable to write cached ZIR code for {}{s} to {}{s}: {s}", .{
            file.mod.root, file.sub_file_path, cache_directory, &digest, @errorName(err),
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
        // Iterate over all Namespace objects contained within this File, looking at the
        // previous and new ZIR together and update the references to point
        // to the new one. For example, Decl name, Decl zir_decl_index, and Namespace
        // decl_table keys need to get updated to point to the new memory, even if the
        // underlying source code is unchanged.
        // We do not need to hold any locks at this time because all the Decl and Namespace
        // objects being touched are specific to this File, and the only other concurrent
        // tasks are touching other File objects.
        try updateZirRefs(mod, file, prev_zir.*);
        // At this point, `file.outdated_decls` and `file.deleted_decls` are populated,
        // and semantic analysis will deal with them properly.
        // No need to keep previous ZIR.
        prev_zir.deinit(gpa);
        gpa.destroy(prev_zir);
        file.prev_zir = null;
    } else if (file.root_decl.unwrap()) |root_decl| {
        // This is an update, but it is the first time the File has succeeded
        // ZIR. We must mark it outdated since we have already tried to
        // semantically analyze it.
        try file.outdated_decls.resize(gpa, 1);
        file.outdated_decls.items[0] = root_decl;
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

    var iovecs = [_]std.os.iovec{
        .{
            .iov_base = @as([*]u8, @ptrCast(zir.instructions.items(.tag).ptr)),
            .iov_len = header.instructions_len,
        },
        .{
            .iov_base = data_ptr,
            .iov_len = header.instructions_len * 8,
        },
        .{
            .iov_base = zir.string_bytes.ptr,
            .iov_len = header.string_bytes_len,
        },
        .{
            .iov_base = @as([*]u8, @ptrCast(zir.extra.ptr)),
            .iov_len = header.extra_len * 4,
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

/// Patch ups:
/// * Struct.zir_index
/// * Decl.zir_index
/// * Fn.zir_body_inst
/// * Decl.zir_decl_index
fn updateZirRefs(mod: *Module, file: *File, old_zir: Zir) !void {
    const gpa = mod.gpa;
    const new_zir = file.zir;

    // The root decl will be null if the previous ZIR had AST errors.
    const root_decl = file.root_decl.unwrap() orelse return;

    // Maps from old ZIR to new ZIR, struct_decl, enum_decl, etc. Any instruction which
    // creates a namespace, gets mapped from old to new here.
    var inst_map: std.AutoHashMapUnmanaged(Zir.Inst.Index, Zir.Inst.Index) = .{};
    defer inst_map.deinit(gpa);
    // Maps from old ZIR to new ZIR, the extra data index for the sub-decl item.
    // e.g. the thing that Decl.zir_decl_index points to.
    var extra_map: std.AutoHashMapUnmanaged(Zir.ExtraIndex, Zir.ExtraIndex) = .{};
    defer extra_map.deinit(gpa);

    try mapOldZirToNew(gpa, old_zir, new_zir, &inst_map, &extra_map);

    // Walk the Decl graph, updating ZIR indexes, strings, and populating
    // the deleted and outdated lists.

    var decl_stack: ArrayListUnmanaged(Decl.Index) = .{};
    defer decl_stack.deinit(gpa);

    try decl_stack.append(gpa, root_decl);

    file.deleted_decls.clearRetainingCapacity();
    file.outdated_decls.clearRetainingCapacity();

    // The root decl is always outdated; otherwise we would not have had
    // to re-generate ZIR for the File.
    try file.outdated_decls.append(gpa, root_decl);

    const ip = &mod.intern_pool;

    while (decl_stack.popOrNull()) |decl_index| {
        const decl = mod.declPtr(decl_index);
        // Anonymous decls and the root decl have this set to 0. We still need
        // to walk them but we do not need to modify this value.
        // Anonymous decls should not be marked outdated. They will be re-generated
        // if their owner decl is marked outdated.
        if (decl.zir_decl_index.unwrap()) |old_zir_decl_index| {
            const new_zir_decl_index = extra_map.get(old_zir_decl_index) orelse {
                try file.deleted_decls.append(gpa, decl_index);
                continue;
            };
            const old_hash = decl.contentsHashZir(old_zir);
            decl.zir_decl_index = new_zir_decl_index.toOptional();
            const new_hash = decl.contentsHashZir(new_zir);
            if (!std.zig.srcHashEql(old_hash, new_hash)) {
                try file.outdated_decls.append(gpa, decl_index);
            }
        }

        if (!decl.owns_tv) continue;

        if (decl.getOwnedStruct(mod)) |struct_type| {
            struct_type.setZirIndex(ip, inst_map.get(struct_type.zir_index) orelse {
                try file.deleted_decls.append(gpa, decl_index);
                continue;
            });
        }

        if (decl.getOwnedUnion(mod)) |union_type| {
            union_type.setZirIndex(ip, inst_map.get(union_type.zir_index) orelse {
                try file.deleted_decls.append(gpa, decl_index);
                continue;
            });
        }

        if (decl.getOwnedFunction(mod)) |func| {
            func.zirBodyInst(ip).* = inst_map.get(func.zir_body_inst) orelse {
                try file.deleted_decls.append(gpa, decl_index);
                continue;
            };
        }

        if (decl.getOwnedInnerNamespace(mod)) |namespace| {
            for (namespace.decls.keys()) |sub_decl| {
                try decl_stack.append(gpa, sub_decl);
            }
        }
    }
}

pub fn populateBuiltinFile(mod: *Module) !void {
    const tracy = trace(@src());
    defer tracy.end();

    const comp = mod.comp;
    const builtin_mod, const file = blk: {
        comp.mutex.lock();
        defer comp.mutex.unlock();

        const builtin_mod = mod.main_mod.deps.get("builtin").?;
        const result = try mod.importPkg(builtin_mod);
        break :blk .{ builtin_mod, result.file };
    };
    const gpa = mod.gpa;
    file.source = try comp.generateBuiltinZigSource(gpa);
    file.source_loaded = true;

    if (builtin_mod.root.statFile(builtin_mod.root_src_path)) |stat| {
        if (stat.size != file.source.len) {
            log.warn(
                "the cached file '{}{s}' had the wrong size. Expected {d}, found {d}. " ++
                    "Overwriting with correct file contents now",
                .{ builtin_mod.root, builtin_mod.root_src_path, file.source.len, stat.size },
            );

            try writeBuiltinFile(file, builtin_mod);
        } else {
            file.stat = .{
                .size = stat.size,
                .inode = stat.inode,
                .mtime = stat.mtime,
            };
        }
    } else |err| switch (err) {
        error.BadPathName => unreachable, // it's always "builtin.zig"
        error.NameTooLong => unreachable, // it's always "builtin.zig"
        error.PipeBusy => unreachable, // it's not a pipe
        error.WouldBlock => unreachable, // not asking for non-blocking I/O

        error.FileNotFound => try writeBuiltinFile(file, builtin_mod),

        else => |e| return e,
    }

    file.tree = try Ast.parse(gpa, file.source, .zig);
    file.tree_loaded = true;
    assert(file.tree.errors.len == 0); // builtin.zig must parse

    file.zir = try AstGen.generate(gpa, file.tree);
    file.zir_loaded = true;
    file.status = .success_zir;
}

fn writeBuiltinFile(file: *File, builtin_mod: *Package.Module) !void {
    var af = try builtin_mod.root.atomicFile(builtin_mod.root_src_path, .{});
    defer af.deinit();
    try af.file.writeAll(file.source);
    try af.finish();

    file.stat = .{
        .size = file.source.len,
        .inode = 0, // dummy value
        .mtime = 0, // dummy value
    };
}

pub fn mapOldZirToNew(
    gpa: Allocator,
    old_zir: Zir,
    new_zir: Zir,
    inst_map: *std.AutoHashMapUnmanaged(Zir.Inst.Index, Zir.Inst.Index),
    extra_map: *std.AutoHashMapUnmanaged(Zir.ExtraIndex, Zir.ExtraIndex),
) Allocator.Error!void {
    // Contain ZIR indexes of declaration instructions.
    const MatchedZirDecl = struct {
        old_inst: Zir.Inst.Index,
        new_inst: Zir.Inst.Index,
    };
    var match_stack: ArrayListUnmanaged(MatchedZirDecl) = .{};
    defer match_stack.deinit(gpa);

    // Main struct inst is always the same
    try match_stack.append(gpa, .{
        .old_inst = .main_struct_inst,
        .new_inst = .main_struct_inst,
    });

    var old_decls = std.ArrayList(Zir.Inst.Index).init(gpa);
    defer old_decls.deinit();
    var new_decls = std.ArrayList(Zir.Inst.Index).init(gpa);
    defer new_decls.deinit();

    while (match_stack.popOrNull()) |match_item| {
        try inst_map.put(gpa, match_item.old_inst, match_item.new_inst);

        // Maps name to extra index of decl sub item.
        var decl_map: std.StringHashMapUnmanaged(Zir.ExtraIndex) = .{};
        defer decl_map.deinit(gpa);

        {
            var old_decl_it = old_zir.declIterator(match_item.old_inst);
            while (old_decl_it.next()) |old_decl| {
                try decl_map.put(gpa, old_decl.name, old_decl.sub_index);
            }
        }

        var new_decl_it = new_zir.declIterator(match_item.new_inst);
        while (new_decl_it.next()) |new_decl| {
            const old_extra_index = decl_map.get(new_decl.name) orelse continue;
            const new_extra_index = new_decl.sub_index;
            try extra_map.put(gpa, old_extra_index, new_extra_index);

            try old_zir.findDecls(&old_decls, old_extra_index);
            try new_zir.findDecls(&new_decls, new_extra_index);
            var i: usize = 0;
            while (true) : (i += 1) {
                if (i >= old_decls.items.len) break;
                if (i >= new_decls.items.len) break;
                try match_stack.append(gpa, .{
                    .old_inst = old_decls.items[i],
                    .new_inst = new_decls.items[i],
                });
            }
        }
    }
}

/// This ensures that the Decl will have a Type and Value populated.
/// However the resolution status of the Type may not be fully resolved.
/// For example an inferred error set is not resolved until after `analyzeFnBody`.
/// is called.
pub fn ensureDeclAnalyzed(mod: *Module, decl_index: Decl.Index) SemaError!void {
    const tracy = trace(@src());
    defer tracy.end();

    const decl = mod.declPtr(decl_index);

    const subsequent_analysis = switch (decl.analysis) {
        .in_progress => unreachable,

        .file_failure,
        .sema_failure,
        .sema_failure_retryable,
        .liveness_failure,
        .codegen_failure,
        .dependency_failure,
        .codegen_failure_retryable,
        => return error.AnalysisFail,

        .complete => return,

        .outdated => blk: {
            // The exports this Decl performs will be re-discovered, so we remove them here
            // prior to re-analysis.
            try mod.deleteDeclExports(decl_index);

            break :blk true;
        },

        .unreferenced => false,
    };

    var decl_prog_node = mod.sema_prog_node.start("", 0);
    decl_prog_node.activate();
    defer decl_prog_node.end();

    const type_changed = blk: {
        if (decl.zir_decl_index == .none and !mod.declIsRoot(decl_index)) {
            // Anonymous decl. We don't semantically analyze these.
            break :blk false; // tv unchanged
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
                decl.analysis = .sema_failure_retryable;
                try mod.failed_decls.ensureUnusedCapacity(mod.gpa, 1);
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

    if (subsequent_analysis) {
        _ = type_changed;
        @panic("TODO re-implement incremental compilation");
    }
}

pub fn ensureFuncBodyAnalyzed(mod: *Module, func_index: InternPool.Index) SemaError!void {
    const tracy = trace(@src());
    defer tracy.end();

    const ip = &mod.intern_pool;
    const func = mod.funcInfo(func_index);
    const decl_index = func.owner_decl;
    const decl = mod.declPtr(decl_index);

    switch (decl.analysis) {
        .unreferenced => unreachable,
        .in_progress => unreachable,
        .outdated => unreachable,

        .file_failure,
        .sema_failure,
        .liveness_failure,
        .codegen_failure,
        .dependency_failure,
        .sema_failure_retryable,
        => return error.AnalysisFail,

        .complete, .codegen_failure_retryable => {
            switch (func.analysis(ip).state) {
                .sema_failure, .dependency_failure => return error.AnalysisFail,
                .none, .queued => {},
                .in_progress => unreachable,
                .inline_only => unreachable, // don't queue work for this
                .success => return,
            }

            const gpa = mod.gpa;

            var tmp_arena = std.heap.ArenaAllocator.init(gpa);
            defer tmp_arena.deinit();
            const sema_arena = tmp_arena.allocator();

            var air = mod.analyzeFnBody(func_index, sema_arena) catch |err| switch (err) {
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

            const comp = mod.comp;

            const no_bin_file = (comp.bin_file.options.emit == null and
                comp.emit_asm == null and
                comp.emit_llvm_ir == null and
                comp.emit_llvm_bc == null);

            const dump_air = builtin.mode == .Debug and comp.verbose_air;
            const dump_llvm_ir = builtin.mode == .Debug and (comp.verbose_llvm_ir != null or comp.verbose_llvm_bc != null);

            if (no_bin_file and !dump_air and !dump_llvm_ir) return;

            var liveness = try Liveness.analyze(gpa, air, ip);
            defer liveness.deinit(gpa);

            if (dump_air) {
                const fqn = try decl.getFullyQualifiedName(mod);
                std.debug.print("# Begin Function AIR: {}:\n", .{fqn.fmt(ip)});
                @import("print_air.zig").dump(mod, air, liveness);
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
                        try mod.failed_decls.ensureUnusedCapacity(gpa, 1);
                        mod.failed_decls.putAssumeCapacityNoClobber(
                            decl_index,
                            try Module.ErrorMsg.create(
                                gpa,
                                decl.srcLoc(mod),
                                "invalid liveness: {s}",
                                .{@errorName(err)},
                            ),
                        );
                        decl.analysis = .liveness_failure;
                        return error.AnalysisFail;
                    },
                };
            }

            if (no_bin_file and !dump_llvm_ir) return;

            comp.bin_file.updateFunc(mod, func_index, air, liveness) catch |err| switch (err) {
                error.OutOfMemory => return error.OutOfMemory,
                error.AnalysisFail => {
                    decl.analysis = .codegen_failure;
                    return;
                },
                else => {
                    try mod.failed_decls.ensureUnusedCapacity(gpa, 1);
                    mod.failed_decls.putAssumeCapacityNoClobber(decl_index, try Module.ErrorMsg.create(
                        gpa,
                        decl.srcLoc(mod),
                        "unable to codegen: {s}",
                        .{@errorName(err)},
                    ));
                    decl.analysis = .codegen_failure_retryable;
                    return;
                },
            };
            return;
        },
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
        .outdated => unreachable,

        .file_failure,
        .sema_failure,
        .liveness_failure,
        .codegen_failure,
        .dependency_failure,
        .sema_failure_retryable,
        .codegen_failure_retryable,
        // The function analysis failed, but we've already emitted an error for
        // that. The callee doesn't need the function to be analyzed right now,
        // so its analysis can safely continue.
        => return,

        .complete => {},
    }

    assert(decl.has_tv);

    switch (func.analysis(ip).state) {
        .none => {},
        .queued => return,
        // As above, we don't need to forward errors here.
        .sema_failure, .dependency_failure => return,
        .in_progress => return,
        .inline_only => unreachable, // don't queue work for this
        .success => return,
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
    return mod.semaFile(file);
}

/// Regardless of the file status, will create a `Decl` so that we
/// can track dependencies and re-analyze when the file becomes outdated.
pub fn semaFile(mod: *Module, file: *File) SemaError!void {
    const tracy = trace(@src());
    defer tracy.end();

    if (file.root_decl != .none) return;

    const gpa = mod.gpa;

    // Because these three things each reference each other, `undefined`
    // placeholders are used before being set after the struct type gains an
    // InternPool index.
    const new_namespace_index = try mod.createNamespace(.{
        .parent = .none,
        .ty = undefined,
        .file_scope = file,
    });
    const new_namespace = mod.namespacePtr(new_namespace_index);
    errdefer mod.destroyNamespace(new_namespace_index);

    const new_decl_index = try mod.allocateNewDecl(new_namespace_index, 0, .none);
    const new_decl = mod.declPtr(new_decl_index);
    errdefer @panic("TODO error handling");

    file.root_decl = new_decl_index.toOptional();

    new_decl.name = try file.fullyQualifiedName(mod);
    new_decl.name_fully_qualified = true;
    new_decl.src_line = 0;
    new_decl.is_pub = true;
    new_decl.is_exported = false;
    new_decl.has_align = false;
    new_decl.has_linksection_or_addrspace = false;
    new_decl.ty = Type.type;
    new_decl.alignment = .none;
    new_decl.@"linksection" = .none;
    new_decl.has_tv = true;
    new_decl.owns_tv = true;
    new_decl.alive = true; // This Decl corresponds to a File and is therefore always alive.
    new_decl.analysis = .in_progress;
    new_decl.generation = mod.generation;

    if (file.status != .success_zir) {
        new_decl.analysis = .file_failure;
        return;
    }
    assert(file.zir_loaded);

    var sema_arena = std.heap.ArenaAllocator.init(gpa);
    defer sema_arena.deinit();
    const sema_arena_allocator = sema_arena.allocator();

    var comptime_mutable_decls = std.ArrayList(Decl.Index).init(gpa);
    defer comptime_mutable_decls.deinit();

    var sema: Sema = .{
        .mod = mod,
        .gpa = gpa,
        .arena = sema_arena_allocator,
        .code = file.zir,
        .owner_decl = new_decl,
        .owner_decl_index = new_decl_index,
        .func_index = .none,
        .func_is_naked = false,
        .fn_ret_ty = Type.void,
        .fn_ret_ty_ies = null,
        .owner_func_index = .none,
        .comptime_mutable_decls = &comptime_mutable_decls,
    };
    defer sema.deinit();

    const struct_ty = sema.getStructType(
        new_decl_index,
        new_namespace_index,
        .main_struct_inst,
    ) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
    };
    // TODO: figure out InternPool removals for incremental compilation
    //errdefer ip.remove(struct_ty);
    for (comptime_mutable_decls.items) |decl_index| {
        const decl = mod.declPtr(decl_index);
        _ = try decl.internValue(mod);
    }

    new_namespace.ty = struct_ty.toType();
    new_decl.val = struct_ty.toValue();
    new_decl.analysis = .complete;

    if (mod.comp.whole_cache_manifest) |whole_cache_manifest| {
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

        mod.comp.whole_cache_manifest_mutex.lock();
        defer mod.comp.whole_cache_manifest_mutex.unlock();
        try whole_cache_manifest.addFilePostContents(resolved_path, source.bytes, source.stat);
    }
}

/// Returns `true` if the Decl type changed.
/// Returns `true` if this is the first time analyzing the Decl.
/// Returns `false` otherwise.
fn semaDecl(mod: *Module, decl_index: Decl.Index) !bool {
    const tracy = trace(@src());
    defer tracy.end();

    const decl = mod.declPtr(decl_index);

    if (decl.getFileScope(mod).status != .success_zir) {
        return error.AnalysisFail;
    }

    const gpa = mod.gpa;
    const zir = decl.getFileScope(mod).zir;
    const zir_datas = zir.instructions.items(.data);

    // TODO: figure out how this works under incremental changes to builtin.zig!
    const builtin_type_target_index: InternPool.Index = blk: {
        const std_mod = mod.main_mod.deps.get("std").?;
        if (decl.getFileScope(mod).mod != std_mod) break :blk .none;
        // We're in the std module.
        const std_file = (try mod.importPkg(std_mod)).file;
        const std_decl = mod.declPtr(std_file.root_decl.unwrap().?);
        const std_namespace = std_decl.getInnerNamespace(mod).?;
        const builtin_str = try mod.intern_pool.getOrPutString(gpa, "builtin");
        const builtin_decl = mod.declPtr(std_namespace.decls.getKeyAdapted(builtin_str, DeclAdapter{ .mod = mod }) orelse break :blk .none);
        const builtin_namespace = builtin_decl.getInnerNamespaceIndex(mod).unwrap() orelse break :blk .none;
        if (decl.src_namespace != builtin_namespace) break :blk .none;
        // We're in builtin.zig. This could be a builtin we need to add to a specific InternPool index.
        const decl_name = mod.intern_pool.stringToSlice(decl.name);
        for ([_]struct { []const u8, InternPool.Index }{
            .{ "AtomicOrder", .atomic_order_type },
            .{ "AtomicRmwOp", .atomic_rmw_op_type },
            .{ "CallingConvention", .calling_convention_type },
            .{ "AddressSpace", .address_space_type },
            .{ "FloatMode", .float_mode_type },
            .{ "ReduceOp", .reduce_op_type },
            .{ "CallModifier", .call_modifier_type },
            .{ "PrefetchOptions", .prefetch_options_type },
            .{ "ExportOptions", .export_options_type },
            .{ "ExternOptions", .extern_options_type },
            .{ "Type", .type_info_type },
        }) |pair| {
            if (std.mem.eql(u8, decl_name, pair[0])) {
                break :blk pair[1];
            }
        }
        break :blk .none;
    };

    decl.analysis = .in_progress;

    var analysis_arena = std.heap.ArenaAllocator.init(gpa);
    defer analysis_arena.deinit();

    var comptime_mutable_decls = std.ArrayList(Decl.Index).init(gpa);
    defer comptime_mutable_decls.deinit();

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
        .comptime_mutable_decls = &comptime_mutable_decls,
        .builtin_type_target_index = builtin_type_target_index,
    };
    defer sema.deinit();

    assert(!mod.declIsRoot(decl_index));

    var block_scope: Sema.Block = .{
        .parent = null,
        .sema = &sema,
        .src_decl = decl_index,
        .namespace = decl.src_namespace,
        .wip_capture_scope = try mod.createCaptureScope(decl.src_scope),
        .instructions = .{},
        .inlining = null,
        .is_comptime = true,
    };
    defer block_scope.instructions.deinit(gpa);

    const zir_block_index = decl.zirBlockIndex(mod);
    const inst_data = zir_datas[@intFromEnum(zir_block_index)].pl_node;
    const extra = zir.extraData(Zir.Inst.Block, inst_data.payload_index);
    const body = zir.extra[extra.end..][0..extra.data.body_len];
    const result_ref = (try sema.analyzeBodyBreak(&block_scope, @ptrCast(body))).?.operand;
    // We'll do some other bits with the Sema. Clear the type target index just
    // in case they analyze any type.
    sema.builtin_type_target_index = .none;
    for (comptime_mutable_decls.items) |ct_decl_index| {
        const ct_decl = mod.declPtr(ct_decl_index);
        _ = try ct_decl.internValue(mod);
    }
    const align_src: LazySrcLoc = .{ .node_offset_var_decl_align = 0 };
    const section_src: LazySrcLoc = .{ .node_offset_var_decl_section = 0 };
    const address_space_src: LazySrcLoc = .{ .node_offset_var_decl_addrspace = 0 };
    const ty_src: LazySrcLoc = .{ .node_offset_var_decl_ty = 0 };
    const init_src: LazySrcLoc = .{ .node_offset_var_decl_init = 0 };
    const decl_tv = try sema.resolveInstValueAllowVariables(&block_scope, init_src, result_ref, .{
        .needed_comptime_reason = "global variable initializer must be comptime-known",
    });

    // Note this resolves the type of the Decl, not the value; if this Decl
    // is a struct, for example, this resolves `type` (which needs no resolution),
    // not the struct itself.
    try sema.resolveTypeLayout(decl_tv.ty);

    if (decl.kind == .@"usingnamespace") {
        if (!decl_tv.ty.eql(Type.type, mod)) {
            return sema.fail(&block_scope, ty_src, "expected type, found {}", .{
                decl_tv.ty.fmt(mod),
            });
        }
        const ty = decl_tv.val.toType();
        if (ty.getNamespace(mod) == null) {
            return sema.fail(&block_scope, ty_src, "type {} has no namespace", .{ty.fmt(mod)});
        }

        decl.ty = InternPool.Index.type_type.toType();
        decl.val = ty.toValue();
        decl.alignment = .none;
        decl.@"linksection" = .none;
        decl.has_tv = true;
        decl.owns_tv = false;
        decl.analysis = .complete;
        decl.generation = mod.generation;

        return true;
    }

    const ip = &mod.intern_pool;
    switch (ip.indexToKey(decl_tv.val.toIntern())) {
        .func => |func| {
            const owns_tv = func.owner_decl == decl_index;
            if (owns_tv) {
                var prev_type_has_bits = false;
                var prev_is_inline = false;
                var type_changed = true;

                if (decl.has_tv) {
                    prev_type_has_bits = decl.ty.isFnOrHasRuntimeBits(mod);
                    type_changed = !decl.ty.eql(decl_tv.ty, mod);
                    if (decl.getOwnedFunction(mod)) |prev_func| {
                        prev_is_inline = prev_func.analysis(ip).state == .inline_only;
                    }
                }

                decl.ty = decl_tv.ty;
                decl.val = (try decl_tv.val.intern(decl_tv.ty, mod)).toValue();
                // linksection, align, and addrspace were already set by Sema
                decl.has_tv = true;
                decl.owns_tv = owns_tv;
                decl.analysis = .complete;
                decl.generation = mod.generation;

                const is_inline = decl.ty.fnCallingConvention(mod) == .Inline;
                if (decl.is_exported) {
                    const export_src: LazySrcLoc = .{ .token_offset = @intFromBool(decl.is_pub) };
                    if (is_inline) {
                        return sema.fail(&block_scope, export_src, "export of inline function", .{});
                    }
                    // The scope needs to have the decl in it.
                    try sema.analyzeExport(&block_scope, export_src, .{ .name = decl.name }, decl_index);
                }
                return type_changed or is_inline != prev_is_inline;
            }
        },
        else => {},
    }
    var type_changed = true;
    if (decl.has_tv) {
        type_changed = !decl.ty.eql(decl_tv.ty, mod);
    }

    decl.owns_tv = false;
    var queue_linker_work = false;
    var is_extern = false;
    switch (decl_tv.val.toIntern()) {
        .generic_poison => unreachable,
        .unreachable_value => unreachable,
        else => switch (ip.indexToKey(decl_tv.val.toIntern())) {
            .variable => |variable| if (variable.decl == decl_index) {
                decl.owns_tv = true;
                queue_linker_work = true;
            },

            .extern_func => |extern_fn| if (extern_fn.decl == decl_index) {
                decl.owns_tv = true;
                queue_linker_work = true;
                is_extern = true;
            },

            .func => {},

            else => {
                queue_linker_work = true;
            },
        },
    }

    decl.ty = decl_tv.ty;
    decl.val = (try decl_tv.val.intern(decl_tv.ty, mod)).toValue();
    decl.alignment = blk: {
        const align_ref = decl.zirAlignRef(mod);
        if (align_ref == .none) break :blk .none;
        break :blk try sema.resolveAlign(&block_scope, align_src, align_ref);
    };
    decl.@"linksection" = blk: {
        const linksection_ref = decl.zirLinksectionRef(mod);
        if (linksection_ref == .none) break :blk .none;
        const bytes = try sema.resolveConstString(&block_scope, section_src, linksection_ref, .{
            .needed_comptime_reason = "linksection must be comptime-known",
        });
        if (mem.indexOfScalar(u8, bytes, 0) != null) {
            return sema.fail(&block_scope, section_src, "linksection cannot contain null bytes", .{});
        } else if (bytes.len == 0) {
            return sema.fail(&block_scope, section_src, "linksection cannot be empty", .{});
        }
        const section = try ip.getOrPutString(gpa, bytes);
        break :blk section.toOptional();
    };
    decl.@"addrspace" = blk: {
        const addrspace_ctx: Sema.AddressSpaceContext = switch (ip.indexToKey(decl_tv.val.toIntern())) {
            .variable => .variable,
            .extern_func, .func => .function,
            else => .constant,
        };

        const target = sema.mod.getTarget();
        break :blk switch (decl.zirAddrspaceRef(mod)) {
            .none => switch (addrspace_ctx) {
                .function => target_util.defaultAddressSpace(target, .function),
                .variable => target_util.defaultAddressSpace(target, .global_mutable),
                .constant => target_util.defaultAddressSpace(target, .global_constant),
                else => unreachable,
            },
            else => |addrspace_ref| try sema.analyzeAddressSpace(&block_scope, address_space_src, addrspace_ref, addrspace_ctx),
        };
    };
    decl.has_tv = true;
    decl.analysis = .complete;
    decl.generation = mod.generation;

    const has_runtime_bits = is_extern or
        (queue_linker_work and try sema.typeHasRuntimeBits(decl.ty));

    if (has_runtime_bits) {

        // Needed for codegen_decl which will call updateDecl and then the
        // codegen backend wants full access to the Decl Type.
        try sema.resolveTypeFully(decl.ty);

        try mod.comp.work_queue.writeItem(.{ .codegen_decl = decl_index });

        if (type_changed and mod.emit_h != null) {
            try mod.comp.work_queue.writeItem(.{ .emit_h_decl = decl_index });
        }
    }

    if (decl.is_exported) {
        const export_src: LazySrcLoc = .{ .token_offset = @intFromBool(decl.is_pub) };
        // The scope needs to have the decl in it.
        try sema.analyzeExport(&block_scope, export_src, .{ .name = decl.name }, decl_index);
    }

    return type_changed;
}

pub const ImportFileResult = struct {
    file: *File,
    is_new: bool,
    is_pkg: bool,
};

/// https://github.com/ziglang/zig/issues/14307
pub fn importPkg(mod: *Module, pkg: *Package.Module) !ImportFileResult {
    const gpa = mod.gpa;

    // The resolved path is used as the key in the import table, to detect if
    // an import refers to the same as another, despite different relative paths
    // or differently mapped package names.
    const resolved_path = try std.fs.path.resolve(gpa, &.{
        pkg.root.root_dir.path orelse ".",
        pkg.root.sub_path,
        pkg.root_src_path,
    });
    var keep_resolved_path = false;
    defer if (!keep_resolved_path) gpa.free(resolved_path);

    const gop = try mod.import_table.getOrPut(gpa, resolved_path);
    errdefer _ = mod.import_table.pop();
    if (gop.found_existing) {
        try gop.value_ptr.*.addReference(mod.*, .{ .root = pkg });
        return ImportFileResult{
            .file = gop.value_ptr.*,
            .is_new = false,
            .is_pkg = true,
        };
    }

    const sub_file_path = try gpa.dupe(u8, pkg.root_src_path);
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
        .mod = pkg,
        .root_decl = .none,
    };
    try new_file.addReference(mod.*, .{ .root = pkg });
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
        return mod.importPkg(mod.main_mod.deps.get("std").?);
    }
    if (std.mem.eql(u8, import_string, "builtin")) {
        return mod.importPkg(mod.main_mod.deps.get("builtin").?);
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
        if (mem.startsWith(u8, resolved_path, resolved_root_path)) {
            // +1 for the directory separator here.
            break :p try gpa.dupe(u8, resolved_path[resolved_root_path.len + 1 ..]);
        }
        if (mem.eql(u8, resolved_root_path, ".") and
            !isUpDir(resolved_path) and
            !std.fs.path.isAbsolute(resolved_path))
        {
            break :p try gpa.dupe(u8, resolved_path);
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
            assert(mod.embed_table.remove(resolved_path));
            keep_resolved_path = false;
        }
        if (gop.found_existing) return gop.value_ptr.*.val;
        keep_resolved_path = true;

        const sub_file_path = try gpa.dupe(u8, pkg.root_src_path);
        errdefer gpa.free(sub_file_path);

        return newEmbedFile(mod, pkg, sub_file_path, resolved_path, gop, src_loc);
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
        assert(mod.embed_table.remove(resolved_path));
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
        if (mem.startsWith(u8, resolved_path, resolved_root_path)) {
            // +1 for the directory separator here.
            break :p try gpa.dupe(u8, resolved_path[resolved_root_path.len + 1 ..]);
        }
        if (mem.eql(u8, resolved_root_path, ".") and
            !isUpDir(resolved_path) and
            !std.fs.path.isAbsolute(resolved_path))
        {
            break :p try gpa.dupe(u8, resolved_path);
        }
        return error.ImportOutsideModulePath;
    };
    errdefer gpa.free(sub_file_path);

    return newEmbedFile(mod, cur_file.mod, sub_file_path, resolved_path, gop, src_loc);
}

/// https://github.com/ziglang/zig/issues/14307
fn newEmbedFile(
    mod: *Module,
    pkg: *Package.Module,
    sub_file_path: []const u8,
    resolved_path: []const u8,
    gop: std.StringHashMapUnmanaged(*EmbedFile).GetOrPutResult,
    src_loc: SrcLoc,
) !InternPool.Index {
    const gpa = mod.gpa;

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
    const ip = &mod.intern_pool;

    const ptr = try ip.string_bytes.addManyAsSlice(gpa, size);
    const actual_read = try file.readAll(ptr);
    if (actual_read != size) return error.UnexpectedEndOfFile;

    if (mod.comp.whole_cache_manifest) |whole_cache_manifest| {
        const copied_resolved_path = try gpa.dupe(u8, resolved_path);
        errdefer gpa.free(copied_resolved_path);
        mod.comp.whole_cache_manifest_mutex.lock();
        defer mod.comp.whole_cache_manifest_mutex.unlock();
        try whole_cache_manifest.addFilePostContents(copied_resolved_path, ptr, stat);
    }

    const array_ty = try ip.get(gpa, .{ .array_type = .{
        .len = size,
        .sentinel = .zero_u8,
        .child = .u8_type,
    } });
    const array_val = try ip.getTrailingAggregate(gpa, array_ty, size);

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
        .addr = .{ .anon_decl = .{
            .val = array_val,
            .orig_ty = ptr_ty,
        } },
    } });

    gop.value_ptr.* = new_file;
    new_file.* = .{
        .sub_file_path = try ip.getOrPutString(gpa, sub_file_path),
        .owner = pkg,
        .stat = stat,
        .val = ptr_val,
        .src_loc = src_loc,
    };
    return ptr_val;
}

pub fn scanNamespace(
    mod: *Module,
    namespace_index: Namespace.Index,
    extra_start: usize,
    decls_len: u32,
    parent_decl: *Decl,
) Allocator.Error!usize {
    const tracy = trace(@src());
    defer tracy.end();

    const gpa = mod.gpa;
    const namespace = mod.namespacePtr(namespace_index);
    const zir = namespace.file_scope.zir;

    try mod.comp.work_queue.ensureUnusedCapacity(decls_len);
    try namespace.decls.ensureTotalCapacity(gpa, decls_len);

    const bit_bags_count = std.math.divCeil(usize, decls_len, 8) catch unreachable;
    var extra_index = extra_start + bit_bags_count;
    var bit_bag_index: usize = extra_start;
    var cur_bit_bag: u32 = undefined;
    var decl_i: u32 = 0;
    var scan_decl_iter: ScanDeclIter = .{
        .module = mod,
        .namespace_index = namespace_index,
        .parent_decl = parent_decl,
    };
    while (decl_i < decls_len) : (decl_i += 1) {
        if (decl_i % 8 == 0) {
            cur_bit_bag = zir.extra[bit_bag_index];
            bit_bag_index += 1;
        }
        const flags = @as(u4, @truncate(cur_bit_bag));
        cur_bit_bag >>= 4;

        const decl_sub_index = extra_index;
        extra_index += 8; // src_hash(4) + line(1) + name(1) + value(1) + doc_comment(1)
        extra_index += @as(u1, @truncate(flags >> 2)); // Align
        extra_index += @as(u2, @as(u1, @truncate(flags >> 3))) * 2; // Link section or address space, consists of 2 Refs

        try scanDecl(&scan_decl_iter, decl_sub_index, flags);
    }
    return extra_index;
}

const ScanDeclIter = struct {
    module: *Module,
    namespace_index: Namespace.Index,
    parent_decl: *Decl,
    usingnamespace_index: usize = 0,
    comptime_index: usize = 0,
    unnamed_test_index: usize = 0,
};

fn scanDecl(iter: *ScanDeclIter, decl_sub_index: usize, flags: u4) Allocator.Error!void {
    const tracy = trace(@src());
    defer tracy.end();

    const mod = iter.module;
    const namespace_index = iter.namespace_index;
    const namespace = mod.namespacePtr(namespace_index);
    const gpa = mod.gpa;
    const zir = namespace.file_scope.zir;
    const ip = &mod.intern_pool;

    // zig fmt: off
    const is_pub                       = (flags & 0b0001) != 0;
    const export_bit                   = (flags & 0b0010) != 0;
    const has_align                    = (flags & 0b0100) != 0;
    const has_linksection_or_addrspace = (flags & 0b1000) != 0;
    // zig fmt: on

    const line_off = zir.extra[decl_sub_index + 4];
    const line = iter.parent_decl.relativeToLine(line_off);
    const decl_name_index = zir.extra[decl_sub_index + 5];
    const decl_doccomment_index = zir.extra[decl_sub_index + 7];
    const decl_zir_index = zir.extra[decl_sub_index + 6];
    const decl_block_inst_data = zir.instructions.items(.data)[decl_zir_index].pl_node;
    const decl_node = iter.parent_decl.relativeToNodeIndex(decl_block_inst_data.src_node);

    // Every Decl needs a name.
    var is_named_test = false;
    var kind: Decl.Kind = .named;
    const decl_name: InternPool.NullTerminatedString = switch (decl_name_index) {
        0 => name: {
            if (export_bit) {
                const i = iter.usingnamespace_index;
                iter.usingnamespace_index += 1;
                kind = .@"usingnamespace";
                break :name try ip.getOrPutStringFmt(gpa, "usingnamespace_{d}", .{i});
            } else {
                const i = iter.comptime_index;
                iter.comptime_index += 1;
                kind = .@"comptime";
                break :name try ip.getOrPutStringFmt(gpa, "comptime_{d}", .{i});
            }
        },
        1 => name: {
            const i = iter.unnamed_test_index;
            iter.unnamed_test_index += 1;
            kind = .@"test";
            break :name try ip.getOrPutStringFmt(gpa, "test_{d}", .{i});
        },
        2 => name: {
            is_named_test = true;
            const test_name = zir.nullTerminatedString(decl_doccomment_index);
            kind = .@"test";
            break :name try ip.getOrPutStringFmt(gpa, "decltest.{s}", .{test_name});
        },
        else => name: {
            const raw_name = zir.nullTerminatedString(decl_name_index);
            if (raw_name.len == 0) {
                is_named_test = true;
                const test_name = zir.nullTerminatedString(decl_name_index + 1);
                kind = .@"test";
                break :name try ip.getOrPutStringFmt(gpa, "test.{s}", .{test_name});
            } else {
                break :name try ip.getOrPutString(gpa, raw_name);
            }
        },
    };

    const is_exported = export_bit and decl_name_index != 0;
    if (kind == .@"usingnamespace") try namespace.usingnamespace_set.ensureUnusedCapacity(gpa, 1);

    // We create a Decl for it regardless of analysis status.
    const gop = try namespace.decls.getOrPutContextAdapted(
        gpa,
        decl_name,
        DeclAdapter{ .mod = mod },
        Namespace.DeclContext{ .module = mod },
    );
    const comp = mod.comp;
    if (!gop.found_existing) {
        const new_decl_index = try mod.allocateNewDecl(namespace_index, decl_node, iter.parent_decl.src_scope);
        const new_decl = mod.declPtr(new_decl_index);
        new_decl.kind = kind;
        new_decl.name = decl_name;
        if (kind == .@"usingnamespace") {
            namespace.usingnamespace_set.putAssumeCapacity(new_decl_index, is_pub);
        }
        new_decl.src_line = line;
        gop.key_ptr.* = new_decl_index;
        // Exported decls, comptime decls, usingnamespace decls, and
        // test decls if in test mode, get analyzed.
        const decl_mod = namespace.file_scope.mod;
        const want_analysis = is_exported or switch (decl_name_index) {
            0 => true, // comptime or usingnamespace decl
            1 => blk: {
                // test decl with no name. Skip the part where we check against
                // the test name filter.
                if (!comp.bin_file.options.is_test) break :blk false;
                if (decl_mod != mod.main_mod) break :blk false;
                try mod.test_functions.put(gpa, new_decl_index, {});
                break :blk true;
            },
            else => blk: {
                if (!is_named_test) break :blk false;
                if (!comp.bin_file.options.is_test) break :blk false;
                if (decl_mod != mod.main_mod) break :blk false;
                if (comp.test_filter) |test_filter| {
                    if (mem.indexOf(u8, ip.stringToSlice(decl_name), test_filter) == null) {
                        break :blk false;
                    }
                }
                try mod.test_functions.put(gpa, new_decl_index, {});
                break :blk true;
            },
        };
        if (want_analysis) {
            comp.work_queue.writeItemAssumeCapacity(.{ .analyze_decl = new_decl_index });
        }
        new_decl.is_pub = is_pub;
        new_decl.is_exported = is_exported;
        new_decl.has_align = has_align;
        new_decl.has_linksection_or_addrspace = has_linksection_or_addrspace;
        new_decl.zir_decl_index = @enumFromInt(decl_sub_index);
        new_decl.alive = true; // This Decl corresponds to an AST node and therefore always alive.
        return;
    }
    const decl_index = gop.key_ptr.*;
    const decl = mod.declPtr(decl_index);
    if (kind == .@"test") {
        const src_loc = SrcLoc{
            .file_scope = decl.getFileScope(mod),
            .parent_decl_node = decl.src_node,
            .lazy = .{ .token_offset = 1 },
        };
        const msg = try ErrorMsg.create(gpa, src_loc, "duplicate test name: {}", .{
            decl_name.fmt(&mod.intern_pool),
        });
        errdefer msg.destroy(gpa);
        try mod.failed_decls.putNoClobber(gpa, decl_index, msg);
        const other_src_loc = SrcLoc{
            .file_scope = namespace.file_scope,
            .parent_decl_node = decl_node,
            .lazy = .{ .token_offset = 1 },
        };
        try mod.errNoteNonLazy(other_src_loc, msg, "other test here", .{});
    }
    // Update the AST node of the decl; even if its contents are unchanged, it may
    // have been re-ordered.
    decl.src_node = decl_node;
    decl.src_line = line;

    decl.is_pub = is_pub;
    decl.is_exported = is_exported;
    decl.kind = kind;
    decl.has_align = has_align;
    decl.has_linksection_or_addrspace = has_linksection_or_addrspace;
    decl.zir_decl_index = @enumFromInt(decl_sub_index);
    if (decl.getOwnedFunction(mod) != null) {
        switch (comp.bin_file.tag) {
            .coff, .elf, .macho, .plan9 => {
                // TODO Look into detecting when this would be unnecessary by storing enough state
                // in `Decl` to notice that the line number did not change.
                comp.work_queue.writeItemAssumeCapacity(.{ .update_line_number = decl_index });
            },
            .c, .wasm, .spirv, .nvptx => {},
        }
    }
}

/// Make it as if the semantic analysis for this Decl never happened.
pub fn clearDecl(
    mod: *Module,
    decl_index: Decl.Index,
    outdated_decls: ?*std.AutoArrayHashMap(Decl.Index, void),
) Allocator.Error!void {
    const tracy = trace(@src());
    defer tracy.end();

    const decl = mod.declPtr(decl_index);

    const gpa = mod.gpa;

    if (outdated_decls) |map| {
        _ = map.swapRemove(decl_index);
    }

    if (mod.failed_decls.fetchSwapRemove(decl_index)) |kv| {
        kv.value.destroy(gpa);
    }
    if (mod.cimport_errors.fetchSwapRemove(decl_index)) |kv| {
        var errors = kv.value;
        errors.deinit(gpa);
    }
    if (mod.emit_h) |emit_h| {
        if (emit_h.failed_decls.fetchSwapRemove(decl_index)) |kv| {
            kv.value.destroy(gpa);
        }
        assert(emit_h.decl_table.swapRemove(decl_index));
    }
    _ = mod.compile_log_decls.swapRemove(decl_index);
    try mod.deleteDeclExports(decl_index);

    if (decl.has_tv) {
        if (decl.ty.isFnOrHasRuntimeBits(mod)) {
            mod.comp.bin_file.freeDecl(decl_index);
        }
        if (decl.getOwnedInnerNamespace(mod)) |namespace| {
            try namespace.deleteAllDecls(mod, outdated_decls);
        }
    }

    if (decl.deletion_flag) {
        decl.deletion_flag = false;
        assert(mod.deletion_set.swapRemove(decl_index));
    }

    decl.analysis = .unreferenced;
}

/// This function is exclusively called for anonymous decls.
/// All resources referenced by anonymous decls are owned by InternPool
/// so there is no cleanup to do here.
pub fn deleteUnusedDecl(mod: *Module, decl_index: Decl.Index) void {
    const gpa = mod.gpa;
    const ip = &mod.intern_pool;

    ip.destroyDecl(gpa, decl_index);

    if (mod.emit_h) |mod_emit_h| {
        const decl_emit_h = mod_emit_h.declPtr(decl_index);
        decl_emit_h.fwd_decl.deinit(gpa);
        decl_emit_h.* = undefined;
    }
}

/// We don't perform a deletion here, because this Decl or another one
/// may end up referencing it before the update is complete.
fn markDeclForDeletion(mod: *Module, decl_index: Decl.Index) !void {
    const decl = mod.declPtr(decl_index);
    decl.deletion_flag = true;
    try mod.deletion_set.put(mod.gpa, decl_index, {});
}

/// Cancel the creation of an anon decl and delete any references to it.
/// If other decls depend on this decl, they must be aborted first.
pub fn abortAnonDecl(mod: *Module, decl_index: Decl.Index) void {
    assert(!mod.declIsRoot(decl_index));
    mod.destroyDecl(decl_index);
}

/// Finalize the creation of an anon decl.
pub fn finalizeAnonDecl(mod: *Module, decl_index: Decl.Index) Allocator.Error!void {
    // The Decl starts off with alive=false and the codegen backend will set alive=true
    // if the Decl is referenced by an instruction or another constant. Otherwise,
    // the Decl will be garbage collected by the `codegen_decl` task instead of sent
    // to the linker.
    if (mod.declPtr(decl_index).ty.isFnOrHasRuntimeBits(mod)) {
        try mod.comp.anon_work_queue.writeItem(.{ .codegen_decl = decl_index });
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
        try mod.comp.bin_file.deleteDeclExport(decl_index, exp.opts.name);
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

    var comptime_mutable_decls = std.ArrayList(Decl.Index).init(gpa);
    defer comptime_mutable_decls.deinit();

    // In the case of a generic function instance, this is the type of the
    // instance, which has comptime parameters elided. In other words, it is
    // the runtime-known parameters only, not to be confused with the
    // generic_owner function type, which potentially has more parameters,
    // including comptime parameters.
    const fn_ty = decl.ty;
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
        .fn_ret_ty = fn_ty_info.return_type.toType(),
        .fn_ret_ty_ies = null,
        .owner_func_index = func_index,
        .branch_quota = @max(func.branchQuota(ip).*, Sema.default_branch_quota),
        .comptime_mutable_decls = &comptime_mutable_decls,
    };
    defer sema.deinit();

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
        .wip_capture_scope = try mod.createCaptureScope(decl.src_scope),
        .instructions = .{},
        .inlining = null,
        .is_comptime = false,
    };
    defer inner_block.instructions.deinit(gpa);

    const fn_info = sema.code.getFnInfo(func.zirBodyInst(ip).*);

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

        const opt_opv = sema.typeHasOnePossibleValue(param_ty.toType()) catch |err| switch (err) {
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
        const arg_index: u32 = @intCast(sema.air_instructions.len);
        gop.value_ptr.* = Air.indexToRef(arg_index);
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

    sema.analyzeBody(&inner_block, fn_info.body) catch |err| switch (err) {
        // TODO make these unreachable instead of @panic
        error.NeededSourceLocation => @panic("zig compiler bug: NeededSourceLocation"),
        error.GenericPoison => @panic("zig compiler bug: GenericPoison"),
        error.ComptimeReturn => @panic("zig compiler bug: ComptimeReturn"),
        else => |e| return e,
    };

    {
        var it = sema.unresolved_inferred_allocs.keyIterator();
        while (it.next()) |ptr_inst| {
            // The lack of a resolve_inferred_alloc means that this instruction
            // is unused so it just has to be a no-op.
            sema.air_instructions.set(ptr_inst.*, .{
                .tag = .alloc,
                .data = .{ .ty = Type.single_const_pointer_to_comptime_int },
            });
        }
    }

    // If we don't get an error return trace from a caller, create our own.
    if (func.analysis(ip).calls_or_awaits_errorable_fn and
        mod.comp.bin_file.options.error_return_tracing and
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

    for (comptime_mutable_decls.items) |ct_decl_index| {
        const ct_decl = mod.declPtr(ct_decl_index);
        _ = try ct_decl.internValue(mod);
    }

    // Copy the block into place and mark that as the main block.
    try sema.air_extra.ensureUnusedCapacity(gpa, @typeInfo(Air.Block).Struct.fields.len +
        inner_block.instructions.items.len);
    const main_block_index = sema.addExtraAssumeCapacity(Air.Block{
        .body_len = @intCast(inner_block.instructions.items.len),
    });
    sema.air_extra.appendSliceAssumeCapacity(inner_block.instructions.items);
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
        sema.resolveTypeFully(ty.toType()) catch |err| switch (err) {
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

fn markOutdatedDecl(mod: *Module, decl_index: Decl.Index) !void {
    const decl = mod.declPtr(decl_index);
    try mod.comp.work_queue.writeItem(.{ .analyze_decl = decl_index });
    if (mod.failed_decls.fetchSwapRemove(decl_index)) |kv| {
        kv.value.destroy(mod.gpa);
    }
    if (mod.cimport_errors.fetchSwapRemove(decl_index)) |kv| {
        var errors = kv.value;
        errors.deinit(mod.gpa);
    }
    if (mod.emit_h) |emit_h| {
        if (emit_h.failed_decls.fetchSwapRemove(decl_index)) |kv| {
            kv.value.destroy(mod.gpa);
        }
    }
    _ = mod.compile_log_decls.swapRemove(decl_index);
    decl.analysis = .outdated;
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
    src_scope: CaptureScope.Index,
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
        .ty = undefined,
        .val = undefined,
        .alignment = undefined,
        .@"linksection" = .none,
        .@"addrspace" = .generic,
        .analysis = .unreferenced,
        .deletion_flag = false,
        .zir_decl_index = .none,
        .src_scope = src_scope,
        .generation = 0,
        .is_pub = false,
        .is_exported = false,
        .has_linksection_or_addrspace = false,
        .has_align = false,
        .alive = false,
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

pub fn createAnonymousDecl(mod: *Module, block: *Sema.Block, typed_value: TypedValue) !Decl.Index {
    const src_decl = mod.declPtr(block.src_decl);
    return mod.createAnonymousDeclFromDecl(src_decl, block.namespace, block.wip_capture_scope, typed_value);
}

pub fn createAnonymousDeclFromDecl(
    mod: *Module,
    src_decl: *Decl,
    namespace: Namespace.Index,
    src_scope: CaptureScope.Index,
    tv: TypedValue,
) !Decl.Index {
    const new_decl_index = try mod.allocateNewDecl(namespace, src_decl.src_node, src_scope);
    errdefer mod.destroyDecl(new_decl_index);
    const name = try mod.intern_pool.getOrPutStringFmt(mod.gpa, "{}__anon_{d}", .{
        src_decl.name.fmt(&mod.intern_pool), @intFromEnum(new_decl_index),
    });
    try mod.initNewAnonDecl(new_decl_index, src_decl.src_line, tv, name);
    return new_decl_index;
}

pub fn initNewAnonDecl(
    mod: *Module,
    new_decl_index: Decl.Index,
    src_line: u32,
    typed_value: TypedValue,
    name: InternPool.NullTerminatedString,
) Allocator.Error!void {
    assert(typed_value.ty.toIntern() == mod.intern_pool.typeOf(typed_value.val.toIntern()));

    const new_decl = mod.declPtr(new_decl_index);

    new_decl.name = name;
    new_decl.src_line = src_line;
    new_decl.ty = typed_value.ty;
    new_decl.val = typed_value.val;
    new_decl.alignment = .none;
    new_decl.@"linksection" = .none;
    new_decl.has_tv = true;
    new_decl.analysis = .complete;
    new_decl.generation = mod.generation;
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

pub fn getTarget(mod: Module) Target {
    return mod.comp.bin_file.options.target;
}

pub fn optimizeMode(mod: Module) std.builtin.OptimizeMode {
    return mod.comp.bin_file.options.optimize_mode;
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

/// Called from `performAllTheWork`, after all AstGen workers have finished,
/// and before the main semantic analysis loop begins.
pub fn processOutdatedAndDeletedDecls(mod: *Module) !void {
    // Ultimately, the goal is to queue up `analyze_decl` tasks in the work queue
    // for the outdated decls, but we cannot queue up the tasks until after
    // we find out which ones have been deleted, otherwise there would be
    // deleted Decl pointers in the work queue.
    var outdated_decls = std.AutoArrayHashMap(Decl.Index, void).init(mod.gpa);
    defer outdated_decls.deinit();
    for (mod.import_table.values()) |file| {
        try outdated_decls.ensureUnusedCapacity(file.outdated_decls.items.len);
        for (file.outdated_decls.items) |decl_index| {
            outdated_decls.putAssumeCapacity(decl_index, {});
        }
        file.outdated_decls.clearRetainingCapacity();

        // Handle explicitly deleted decls from the source code. This is one of two
        // places that Decl deletions happen. The other is in `Compilation`, after
        // `performAllTheWork`, where we iterate over `Module.deletion_set` and
        // delete Decls which are no longer referenced.
        // If a Decl is explicitly deleted from source, and also no longer referenced,
        // it may be both in this `deleted_decls` set, as well as in the
        // `Module.deletion_set`. To avoid deleting it twice, we remove it from the
        // deletion set at this time.
        for (file.deleted_decls.items) |decl_index| {
            const decl = mod.declPtr(decl_index);

            // Remove from the namespace it resides in, preserving declaration order.
            assert(decl.zir_decl_index != .none);
            _ = mod.namespacePtr(decl.src_namespace).decls.orderedRemoveAdapted(
                decl.name,
                DeclAdapter{ .mod = mod },
            );

            try mod.clearDecl(decl_index, &outdated_decls);
            mod.destroyDecl(decl_index);
        }
        file.deleted_decls.clearRetainingCapacity();
    }
    // Finally we can queue up re-analysis tasks after we have processed
    // the deleted decls.
    for (outdated_decls.keys()) |key| {
        try mod.markOutdatedDecl(key);
    }
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
    mod: *Module,
    symbol_exports: *SymbolExports,
    exported: Exported,
    exports: []const *Export,
) error{OutOfMemory}!void {
    const gpa = mod.gpa;

    for (exports) |new_export| {
        const gop = try symbol_exports.getOrPut(gpa, new_export.opts.name);
        if (gop.found_existing) {
            new_export.status = .failed_retryable;
            try mod.failed_exports.ensureUnusedCapacity(gpa, 1);
            const src_loc = new_export.getSrcLoc(mod);
            const msg = try ErrorMsg.create(gpa, src_loc, "exported symbol collision: {}", .{
                new_export.opts.name.fmt(&mod.intern_pool),
            });
            errdefer msg.destroy(gpa);
            const other_export = gop.value_ptr.*;
            const other_src_loc = other_export.getSrcLoc(mod);
            try mod.errNoteNonLazy(other_src_loc, msg, "other symbol here", .{});
            mod.failed_exports.putAssumeCapacityNoClobber(new_export, msg);
            new_export.status = .failed;
        } else {
            gop.value_ptr.* = new_export;
        }
    }
    mod.comp.bin_file.updateExports(mod, exported, exports) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => {
            const new_export = exports[0];
            new_export.status = .failed_retryable;
            try mod.failed_exports.ensureUnusedCapacity(gpa, 1);
            const src_loc = new_export.getSrcLoc(mod);
            const msg = try ErrorMsg.create(gpa, src_loc, "unable to export: {s}", .{
                @errorName(err),
            });
            mod.failed_exports.putAssumeCapacityNoClobber(new_export, msg);
        },
    };
}

pub fn populateTestFunctions(
    mod: *Module,
    main_progress_node: *std.Progress.Node,
) !void {
    const gpa = mod.gpa;
    const ip = &mod.intern_pool;
    const builtin_mod = mod.main_mod.deps.get("builtin").?;
    const builtin_file = (mod.importPkg(builtin_mod) catch unreachable).file;
    const root_decl = mod.declPtr(builtin_file.root_decl.unwrap().?);
    const builtin_namespace = mod.namespacePtr(root_decl.src_namespace);
    const test_functions_str = try ip.getOrPutString(gpa, "test_functions");
    const decl_index = builtin_namespace.decls.getKeyAdapted(
        test_functions_str,
        DeclAdapter{ .mod = mod },
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
    const test_fn_ty = decl.ty.slicePtrFieldType(mod).childType(mod);
    const null_usize = try mod.intern(.{ .opt = .{
        .ty = try mod.intern(.{ .opt_type = .usize_type }),
        .val = .none,
    } });

    const array_decl_index = d: {
        // Add mod.test_functions to an array decl then make the test_functions
        // decl reference it as a slice.
        const test_fn_vals = try gpa.alloc(InternPool.Index, mod.test_functions.count());
        defer gpa.free(test_fn_vals);

        // Add a dependency on each test name and function pointer.
        var array_decl_dependencies = std.ArrayListUnmanaged(Decl.Index){};
        defer array_decl_dependencies.deinit(gpa);
        try array_decl_dependencies.ensureUnusedCapacity(gpa, test_fn_vals.len * 2);

        for (test_fn_vals, mod.test_functions.keys()) |*test_fn_val, test_decl_index| {
            const test_decl = mod.declPtr(test_decl_index);
            // TODO: write something like getCoercedInts to avoid needing to dupe
            const test_decl_name = try gpa.dupe(u8, ip.stringToSlice(test_decl.name));
            defer gpa.free(test_decl_name);
            const test_name_decl_index = n: {
                const test_name_decl_ty = try mod.arrayType(.{
                    .len = test_decl_name.len,
                    .child = .u8_type,
                });
                const test_name_decl_index = try mod.createAnonymousDeclFromDecl(decl, decl.src_namespace, .none, .{
                    .ty = test_name_decl_ty,
                    .val = (try mod.intern(.{ .aggregate = .{
                        .ty = test_name_decl_ty.toIntern(),
                        .storage = .{ .bytes = test_decl_name },
                    } })).toValue(),
                });
                break :n test_name_decl_index;
            };
            array_decl_dependencies.appendAssumeCapacity(test_decl_index);
            array_decl_dependencies.appendAssumeCapacity(test_name_decl_index);
            try mod.linkerUpdateDecl(test_name_decl_index);

            const test_fn_fields = .{
                // name
                try mod.intern(.{ .ptr = .{
                    .ty = .slice_const_u8_type,
                    .addr = .{ .decl = test_name_decl_index },
                    .len = try mod.intern(.{ .int = .{
                        .ty = .usize_type,
                        .storage = .{ .u64 = test_decl_name.len },
                    } }),
                } }),
                // func
                try mod.intern(.{ .ptr = .{
                    .ty = try mod.intern(.{ .ptr_type = .{
                        .child = test_decl.ty.toIntern(),
                        .flags = .{
                            .is_const = true,
                        },
                    } }),
                    .addr = .{ .decl = test_decl_index },
                } }),
                // async_frame_size
                null_usize,
            };
            test_fn_val.* = try mod.intern(.{ .aggregate = .{
                .ty = test_fn_ty.toIntern(),
                .storage = .{ .elems = &test_fn_fields },
            } });
        }

        const array_decl_ty = try mod.arrayType(.{
            .len = test_fn_vals.len,
            .child = test_fn_ty.toIntern(),
            .sentinel = .none,
        });
        const array_decl_index = try mod.createAnonymousDeclFromDecl(decl, decl.src_namespace, .none, .{
            .ty = array_decl_ty,
            .val = (try mod.intern(.{ .aggregate = .{
                .ty = array_decl_ty.toIntern(),
                .storage = .{ .elems = test_fn_vals },
            } })).toValue(),
        });

        break :d array_decl_index;
    };
    try mod.linkerUpdateDecl(array_decl_index);

    {
        const new_ty = try mod.ptrType(.{
            .child = test_fn_ty.toIntern(),
            .flags = .{
                .is_const = true,
                .size = .Slice,
            },
        });
        const new_val = decl.val;
        const new_init = try mod.intern(.{ .ptr = .{
            .ty = new_ty.toIntern(),
            .addr = .{ .decl = array_decl_index },
            .len = (try mod.intValue(Type.usize, mod.test_functions.count())).toIntern(),
        } });
        ip.mutateVarInit(decl.val.toIntern(), new_init);

        // Since we are replacing the Decl's value we must perform cleanup on the
        // previous value.
        decl.ty = new_ty;
        decl.val = new_val;
        decl.has_tv = true;
    }
    try mod.linkerUpdateDecl(decl_index);
}

pub fn linkerUpdateDecl(mod: *Module, decl_index: Decl.Index) !void {
    const comp = mod.comp;

    const no_bin_file = (comp.bin_file.options.emit == null and
        comp.emit_asm == null and
        comp.emit_llvm_ir == null and
        comp.emit_llvm_bc == null);

    const dump_llvm_ir = builtin.mode == .Debug and (comp.verbose_llvm_ir != null or comp.verbose_llvm_bc != null);

    if (no_bin_file and !dump_llvm_ir) return;

    const decl = mod.declPtr(decl_index);

    comp.bin_file.updateDecl(mod, decl_index) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        error.AnalysisFail => {
            decl.analysis = .codegen_failure;
            return;
        },
        else => {
            const gpa = mod.gpa;
            try mod.failed_decls.ensureUnusedCapacity(gpa, 1);
            mod.failed_decls.putAssumeCapacityNoClobber(decl_index, try ErrorMsg.create(
                gpa,
                decl.srcLoc(mod),
                "unable to codegen: {s}",
                .{@errorName(err)},
            ));
            decl.analysis = .codegen_failure_retryable;
            return;
        },
    };
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

pub fn markReferencedDeclsAlive(mod: *Module, val: Value) Allocator.Error!void {
    switch (mod.intern_pool.indexToKey(val.toIntern())) {
        .variable => |variable| try mod.markDeclIndexAlive(variable.decl),
        .extern_func => |extern_func| try mod.markDeclIndexAlive(extern_func.decl),
        .func => |func| try mod.markDeclIndexAlive(func.owner_decl),
        .error_union => |error_union| switch (error_union.val) {
            .err_name => {},
            .payload => |payload| try mod.markReferencedDeclsAlive(payload.toValue()),
        },
        .ptr => |ptr| {
            switch (ptr.addr) {
                .decl => |decl| try mod.markDeclIndexAlive(decl),
                .anon_decl => {},
                .mut_decl => |mut_decl| try mod.markDeclIndexAlive(mut_decl.decl),
                .int, .comptime_field => {},
                .eu_payload, .opt_payload => |parent| try mod.markReferencedDeclsAlive(parent.toValue()),
                .elem, .field => |base_index| try mod.markReferencedDeclsAlive(base_index.base.toValue()),
            }
            if (ptr.len != .none) try mod.markReferencedDeclsAlive(ptr.len.toValue());
        },
        .opt => |opt| if (opt.val != .none) try mod.markReferencedDeclsAlive(opt.val.toValue()),
        .aggregate => |aggregate| for (aggregate.storage.values()) |elem|
            try mod.markReferencedDeclsAlive(elem.toValue()),
        .un => |un| {
            if (un.tag != .none) try mod.markReferencedDeclsAlive(un.tag.toValue());
            try mod.markReferencedDeclsAlive(un.val.toValue());
        },
        else => {},
    }
}

pub fn markDeclAlive(mod: *Module, decl: *Decl) Allocator.Error!void {
    if (decl.alive) return;
    decl.alive = true;

    _ = try decl.internValue(mod);

    // This is the first time we are marking this Decl alive. We must
    // therefore recurse into its value and mark any Decl it references
    // as also alive, so that any Decl referenced does not get garbage collected.
    try mod.markReferencedDeclsAlive(decl.val);
}

fn markDeclIndexAlive(mod: *Module, decl_index: Decl.Index) Allocator.Error!void {
    return mod.markDeclAlive(mod.declPtr(decl_index));
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

pub fn wantDllExports(mod: Module) bool {
    return mod.comp.bin_file.options.dll_export_fns and mod.getTarget().os.tag == .windows;
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

pub fn backendSupportsFeature(mod: Module, feature: Feature) bool {
    return switch (feature) {
        .panic_fn => mod.comp.bin_file.options.target.ofmt == .c or
            mod.comp.bin_file.options.use_llvm or
            mod.comp.bin_file.options.target.cpu.arch == .x86_64,
        .panic_unwrap_error => mod.comp.bin_file.options.target.ofmt == .c or
            mod.comp.bin_file.options.use_llvm,
        .safety_check_formatted => mod.comp.bin_file.options.target.ofmt == .c or
            mod.comp.bin_file.options.use_llvm,
        .error_return_trace => mod.comp.bin_file.options.use_llvm,
        .is_named_enum_value => mod.comp.bin_file.options.use_llvm,
        .error_set_has_value => mod.comp.bin_file.options.use_llvm or mod.comp.bin_file.options.target.isWasm(),
        .field_reordering => mod.comp.bin_file.options.use_llvm,
        .safety_checked_instructions => mod.comp.bin_file.options.use_llvm,
    };
}

/// Shortcut for calling `intern_pool.get`.
pub fn intern(mod: *Module, key: InternPool.Key) Allocator.Error!InternPool.Index {
    return mod.intern_pool.get(mod.gpa, key);
}

/// Shortcut for calling `intern_pool.getCoerced`.
pub fn getCoerced(mod: *Module, val: Value, new_ty: Type) Allocator.Error!Value {
    return (try mod.intern_pool.getCoerced(mod.gpa, val.toIntern(), new_ty.toIntern())).toValue();
}

pub fn intType(mod: *Module, signedness: std.builtin.Signedness, bits: u16) Allocator.Error!Type {
    return (try intern(mod, .{ .int_type = .{
        .signedness = signedness,
        .bits = bits,
    } })).toType();
}

pub fn errorIntType(mod: *Module) std.mem.Allocator.Error!Type {
    return mod.intType(.unsigned, mod.errorSetBits());
}

pub fn arrayType(mod: *Module, info: InternPool.Key.ArrayType) Allocator.Error!Type {
    const i = try intern(mod, .{ .array_type = info });
    return i.toType();
}

pub fn vectorType(mod: *Module, info: InternPool.Key.VectorType) Allocator.Error!Type {
    const i = try intern(mod, .{ .vector_type = info });
    return i.toType();
}

pub fn optionalType(mod: *Module, child_type: InternPool.Index) Allocator.Error!Type {
    const i = try intern(mod, .{ .opt_type = child_type });
    return i.toType();
}

pub fn ptrType(mod: *Module, info: InternPool.Key.PtrType) Allocator.Error!Type {
    var canon_info = info;

    if (info.flags.size == .C) canon_info.flags.is_allowzero = true;

    // Canonicalize non-zero alignment. If it matches the ABI alignment of the pointee
    // type, we change it to 0 here. If this causes an assertion trip because the
    // pointee type needs to be resolved more, that needs to be done before calling
    // this ptr() function.
    if (info.flags.alignment != .none and
        info.flags.alignment == info.child.toType().abiAlignment(mod))
    {
        canon_info.flags.alignment = .none;
    }

    switch (info.flags.vector_index) {
        // Canonicalize host_size. If it matches the bit size of the pointee type,
        // we change it to 0 here. If this causes an assertion trip, the pointee type
        // needs to be resolved before calling this ptr() function.
        .none => if (info.packed_offset.host_size != 0) {
            const elem_bit_size = info.child.toType().bitSize(mod);
            assert(info.packed_offset.bit_offset + elem_bit_size <= info.packed_offset.host_size * 8);
            if (info.packed_offset.host_size * 8 == elem_bit_size) {
                canon_info.packed_offset.host_size = 0;
            }
        },
        .runtime => {},
        _ => assert(@intFromEnum(info.flags.vector_index) < info.packed_offset.host_size),
    }

    return (try intern(mod, .{ .ptr_type = canon_info })).toType();
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
    return (try mod.intern_pool.getFuncType(mod.gpa, key)).toType();
}

/// Use this for `anyframe->T` only.
/// For `anyframe`, use the `InternPool.Index.anyframe` tag directly.
pub fn anyframeType(mod: *Module, payload_ty: Type) Allocator.Error!Type {
    return (try intern(mod, .{ .anyframe_type = payload_ty.toIntern() })).toType();
}

pub fn errorUnionType(mod: *Module, error_set_ty: Type, payload_ty: Type) Allocator.Error!Type {
    return (try intern(mod, .{ .error_union_type = .{
        .error_set_type = error_set_ty.toIntern(),
        .payload_type = payload_ty.toIntern(),
    } })).toType();
}

pub fn singleErrorSetType(mod: *Module, name: InternPool.NullTerminatedString) Allocator.Error!Type {
    const names: *const [1]InternPool.NullTerminatedString = &name;
    const new_ty = try mod.intern_pool.getErrorSetType(mod.gpa, names);
    return new_ty.toType();
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
    return new_ty.toType();
}

/// Supports only pointers, not pointer-like optionals.
pub fn ptrIntValue(mod: *Module, ty: Type, x: u64) Allocator.Error!Value {
    assert(ty.zigTypeTag(mod) == .Pointer and !ty.isSlice(mod));
    const i = try intern(mod, .{ .ptr = .{
        .ty = ty.toIntern(),
        .addr = .{ .int = (try mod.intValue_u64(Type.usize, x)).toIntern() },
    } });
    return i.toValue();
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
    return i.toValue();
}

/// Creates an enum tag value based on the field index according to source code
/// declaration order.
pub fn enumValueFieldIndex(mod: *Module, ty: Type, field_index: u32) Allocator.Error!Value {
    const ip = &mod.intern_pool;
    const gpa = mod.gpa;
    const enum_type = ip.indexToKey(ty.toIntern()).enum_type;

    if (enum_type.values.len == 0) {
        // Auto-numbered fields.
        return (try ip.get(gpa, .{ .enum_tag = .{
            .ty = ty.toIntern(),
            .int = try ip.get(gpa, .{ .int = .{
                .ty = enum_type.tag_ty,
                .storage = .{ .u64 = field_index },
            } }),
        } })).toValue();
    }

    return (try ip.get(gpa, .{ .enum_tag = .{
        .ty = ty.toIntern(),
        .int = enum_type.values.get(ip)[field_index],
    } })).toValue();
}

pub fn undefValue(mod: *Module, ty: Type) Allocator.Error!Value {
    return (try mod.intern(.{ .undef = ty.toIntern() })).toValue();
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
    return i.toValue();
}

pub fn intValue_u64(mod: *Module, ty: Type, x: u64) Allocator.Error!Value {
    const i = try intern(mod, .{ .int = .{
        .ty = ty.toIntern(),
        .storage = .{ .u64 = x },
    } });
    return i.toValue();
}

pub fn intValue_i64(mod: *Module, ty: Type, x: i64) Allocator.Error!Value {
    const i = try intern(mod, .{ .int = .{
        .ty = ty.toIntern(),
        .storage = .{ .i64 = x },
    } });
    return i.toValue();
}

pub fn unionValue(mod: *Module, union_ty: Type, tag: Value, val: Value) Allocator.Error!Value {
    const i = try intern(mod, .{ .un = .{
        .ty = union_ty.toIntern(),
        .tag = tag.toIntern(),
        .val = val.toIntern(),
    } });
    return i.toValue();
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
    return i.toValue();
}

pub fn nullValue(mod: *Module, opt_ty: Type) Allocator.Error!Value {
    const ip = &mod.intern_pool;
    assert(ip.isOptionalType(opt_ty.toIntern()));
    const result = try ip.get(mod.gpa, .{ .opt = .{
        .ty = opt_ty.toIntern(),
        .val = .none,
    } });
    return result.toValue();
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
            return Type.smallestUnsignedBits(lazy_ty.toType().abiAlignment(mod).toByteUnits(0)) + @intFromBool(sign);
        },
        .lazy_size => |lazy_ty| {
            return Type.smallestUnsignedBits(lazy_ty.toType().abiSize(mod)) + @intFromBool(sign);
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

pub fn opaqueSrcLoc(mod: *Module, opaque_type: InternPool.Key.OpaqueType) SrcLoc {
    return mod.declPtr(opaque_type.decl).srcLoc(mod);
}

pub fn opaqueFullyQualifiedName(mod: *Module, opaque_type: InternPool.Key.OpaqueType) !InternPool.NullTerminatedString {
    return mod.declPtr(opaque_type.decl).getFullyQualifiedName(mod);
}

pub fn declFileScope(mod: *Module, decl_index: Decl.Index) *File {
    return mod.declPtr(decl_index).getFileScope(mod);
}

pub fn namespaceDeclIndex(mod: *Module, namespace_index: Namespace.Index) Decl.Index {
    return mod.namespacePtr(namespace_index).getDeclIndex(mod);
}

/// Returns null in the following cases:
/// * `@TypeOf(.{})`
/// * A struct which has no fields (`struct {}`).
/// * Not a struct.
pub fn typeToStruct(mod: *Module, ty: Type) ?InternPool.Key.StructType {
    if (ty.ip_index == .none) return null;
    return switch (mod.intern_pool.indexToKey(ty.ip_index)) {
        .struct_type => |t| t,
        else => null,
    };
}

pub fn typeToPackedStruct(mod: *Module, ty: Type) ?InternPool.Key.StructType {
    if (ty.ip_index == .none) return null;
    return switch (mod.intern_pool.indexToKey(ty.ip_index)) {
        .struct_type => |t| if (t.layout == .Packed) t else null,
        else => null,
    };
}

/// This asserts that the union's enum tag type has been resolved.
pub fn typeToUnion(mod: *Module, ty: Type) ?InternPool.UnionType {
    if (ty.ip_index == .none) return null;
    const ip = &mod.intern_pool;
    return switch (ip.indexToKey(ty.ip_index)) {
        .union_type => |k| ip.loadUnionType(k),
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

    const param_body = file.zir.getParamBody(func.zir_body_inst);
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

pub fn getUnionLayout(mod: *Module, u: InternPool.UnionType) UnionLayout {
    const ip = &mod.intern_pool;
    assert(u.haveLayout(ip));
    var most_aligned_field: u32 = undefined;
    var most_aligned_field_size: u64 = undefined;
    var biggest_field: u32 = undefined;
    var payload_size: u64 = 0;
    var payload_align: Alignment = .@"1";
    for (u.field_types.get(ip), 0..) |field_ty, i| {
        if (!field_ty.toType().hasRuntimeBitsIgnoreComptime(mod)) continue;

        const explicit_align = u.fieldAlign(ip, @intCast(i));
        const field_align = if (explicit_align != .none)
            explicit_align
        else
            field_ty.toType().abiAlignment(mod);
        const field_size = field_ty.toType().abiSize(mod);
        if (field_size > payload_size) {
            payload_size = field_size;
            biggest_field = @intCast(i);
        }
        if (field_align.compare(.gte, payload_align)) {
            payload_align = field_align;
            most_aligned_field = @intCast(i);
            most_aligned_field_size = field_size;
        }
    }
    const have_tag = u.flagsPtr(ip).runtime_tag.hasTag();
    if (!have_tag or !u.enum_tag_ty.toType().hasRuntimeBits(mod)) {
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

    const tag_size = u.enum_tag_ty.toType().abiSize(mod);
    const tag_align = u.enum_tag_ty.toType().abiAlignment(mod).max(.@"1");
    return .{
        .abi_size = u.size,
        .abi_align = tag_align.max(payload_align),
        .most_aligned_field = most_aligned_field,
        .most_aligned_field_size = most_aligned_field_size,
        .biggest_field = biggest_field,
        .payload_size = payload_size,
        .payload_align = payload_align,
        .tag_align = tag_align,
        .tag_size = tag_size,
        .padding = u.padding,
    };
}

pub fn unionAbiSize(mod: *Module, u: InternPool.UnionType) u64 {
    return mod.getUnionLayout(u).abi_size;
}

/// Returns 0 if the union is represented with 0 bits at runtime.
pub fn unionAbiAlignment(mod: *Module, u: InternPool.UnionType) Alignment {
    const ip = &mod.intern_pool;
    const have_tag = u.flagsPtr(ip).runtime_tag.hasTag();
    var max_align: Alignment = .none;
    if (have_tag) max_align = u.enum_tag_ty.toType().abiAlignment(mod);
    for (u.field_types.get(ip), 0..) |field_ty, field_index| {
        if (!field_ty.toType().hasRuntimeBits(mod)) continue;

        const field_align = mod.unionFieldNormalAlignment(u, @intCast(field_index));
        max_align = max_align.max(field_align);
    }
    return max_align;
}

/// Returns the field alignment, assuming the union is not packed.
/// Keep implementation in sync with `Sema.unionFieldAlignment`.
/// Prefer to call that function instead of this one during Sema.
pub fn unionFieldNormalAlignment(mod: *Module, u: InternPool.UnionType, field_index: u32) Alignment {
    const ip = &mod.intern_pool;
    const field_align = u.fieldAlign(ip, field_index);
    if (field_align != .none) return field_align;
    const field_ty = u.field_types.get(ip)[field_index].toType();
    return field_ty.abiAlignment(mod);
}

/// Returns the index of the active field, given the current tag value
pub fn unionTagFieldIndex(mod: *Module, u: InternPool.UnionType, enum_tag: Value) ?u32 {
    const ip = &mod.intern_pool;
    if (enum_tag.toIntern() == .none) return null;
    assert(ip.typeOf(enum_tag.toIntern()) == u.enum_tag_ty);
    const enum_type = ip.indexToKey(u.enum_tag_ty).enum_type;
    return enum_type.tagValueIndex(ip, enum_tag.toIntern());
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
    assert(layout != .Packed);
    if (explicit_alignment != .none) return explicit_alignment;
    switch (layout) {
        .Packed => unreachable,
        .Auto => {
            if (mod.getTarget().ofmt == .c) {
                return structFieldAlignmentExtern(mod, field_ty);
            } else {
                return field_ty.abiAlignment(mod);
            }
        },
        .Extern => return structFieldAlignmentExtern(mod, field_ty),
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
    struct_type: InternPool.Key.StructType,
    field_index: u32,
) u16 {
    const ip = &mod.intern_pool;
    assert(struct_type.layout == .Packed);
    assert(struct_type.haveLayout(ip));
    var bit_sum: u64 = 0;
    for (0..struct_type.field_types.len) |i| {
        if (i == field_index) {
            return @intCast(bit_sum);
        }
        const field_ty = struct_type.field_types.get(ip)[i].toType();
        bit_sum += field_ty.bitSize(mod);
    }
    unreachable; // index out of bounds
}
