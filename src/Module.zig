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
const Cache = @import("Cache.zig");
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

/// General-purpose allocator. Used for both temporary and long-term storage.
gpa: Allocator,
comp: *Compilation,

/// Where build artifacts and incremental compilation metadata serialization go.
zig_cache_artifact_directory: Compilation.Directory,
/// Pointer to externally managed resource.
root_pkg: *Package,
/// Normally, `main_pkg` and `root_pkg` are the same. The exception is `zig test`, in which
/// `root_pkg` is the test runner, and `main_pkg` is the user's source file which has the tests.
main_pkg: *Package,
sema_prog_node: std.Progress.Node = undefined,

/// Used by AstGen worker to load and store ZIR cache.
global_zir_cache: Compilation.Directory,
/// Used by AstGen worker to load and store ZIR cache.
local_zir_cache: Compilation.Directory,
/// It's rare for a decl to be exported, so we save memory by having a sparse
/// map of Decl indexes to details about them being exported.
/// The Export memory is owned by the `export_owners` table; the slice itself
/// is owned by this table. The slice is guaranteed to not be empty.
decl_exports: std.AutoArrayHashMapUnmanaged(Decl.Index, []*Export) = .{},
/// This models the Decls that perform exports, so that `decl_exports` can be updated when a Decl
/// is modified. Note that the key of this table is not the Decl being exported, but the Decl that
/// is performing the export of another Decl.
/// This table owns the Export memory.
export_owners: std.AutoArrayHashMapUnmanaged(Decl.Index, []*Export) = .{},
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

/// This is a temporary addition to stage2 in order to match stage1 behavior,
/// however the end-game once the lang spec is settled will be to use a global
/// InternPool for comptime memoized objects, making this behavior consistent across all types,
/// not only string literals. Or, we might decide to not guarantee string literals
/// to have equal comptime pointers, in which case this field can be deleted (perhaps
/// the commit that introduced it can simply be reverted).
/// This table uses an optional index so that when a Decl is destroyed, the string literal
/// is still reclaimable by a future Decl.
string_literal_table: std.HashMapUnmanaged(StringLiteralContext.Key, Decl.OptionalIndex, StringLiteralContext, std.hash_map.default_max_load_percentage) = .{},
string_literal_bytes: std.ArrayListUnmanaged(u8) = .{},

/// The set of all the generic function instantiations. This is used so that when a generic
/// function is called twice with the same comptime parameter arguments, both calls dispatch
/// to the same function.
/// TODO: remove functions from this set when they are destroyed.
monomorphed_funcs: MonomorphedFuncsSet = .{},
/// The set of all comptime function calls that have been cached so that future calls
/// with the same parameters will get the same return value.
memoized_calls: MemoizedCallSet = .{},
/// Contains the values from `@setAlignStack`. A sparse table is used here
/// instead of a field of `Fn` because usage of `@setAlignStack` is rare, while
/// functions are many.
/// TODO: remove functions from this set when they are destroyed.
align_stack_fns: std.AutoHashMapUnmanaged(*const Fn, SetAlignStack) = .{},

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

/// Candidates for deletion. After a semantic analysis update completes, this list
/// contains Decls that need to be deleted if they end up having no references to them.
deletion_set: std.AutoArrayHashMapUnmanaged(Decl.Index, void) = .{},

/// Error tags and their values, tag names are duped with mod.gpa.
/// Corresponds with `error_name_list`.
global_error_set: std.StringHashMapUnmanaged(ErrorInt) = .{},

/// ErrorInt -> []const u8 for fast lookups for @intToError at comptime
/// Corresponds with `global_error_set`.
error_name_list: ArrayListUnmanaged([]const u8),

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
/// This makes it so that we can run `zig test` on the standard library.
/// Otherwise, the logic for scanning test decls skips all of them because
/// `main_pkg != std_pkg`.
main_pkg_in_std: bool,

compile_log_text: ArrayListUnmanaged(u8) = .{},

emit_h: ?*GlobalEmitH,

test_functions: std.AutoArrayHashMapUnmanaged(Decl.Index, void) = .{},

/// Rather than allocating Decl objects with an Allocator, we instead allocate
/// them with this SegmentedList. This provides four advantages:
///  * Stable memory so that one thread can access a Decl object while another
///    thread allocates additional Decl objects from this list.
///  * It allows us to use u32 indexes to reference Decl objects rather than
///    pointers, saving memory in Type, Value, and dependency sets.
///  * Using integers to reference Decl objects rather than pointers makes
///    serialization trivial.
///  * It provides a unique integer to be used for anonymous symbol names, avoiding
///    multi-threaded contention on an atomic counter.
allocated_decls: std.SegmentedList(Decl, 0) = .{},
/// When a Decl object is freed from `allocated_decls`, it is pushed into this stack.
decls_free_list: std.ArrayListUnmanaged(Decl.Index) = .{},

global_assembly: std.AutoHashMapUnmanaged(Decl.Index, []u8) = .{},

pub const StringLiteralContext = struct {
    bytes: *std.ArrayListUnmanaged(u8),

    pub const Key = struct {
        index: u32,
        len: u32,
    };

    pub fn eql(self: @This(), a: Key, b: Key) bool {
        _ = self;
        return a.index == b.index and a.len == b.len;
    }

    pub fn hash(self: @This(), x: Key) u64 {
        const x_slice = self.bytes.items[x.index..][0..x.len];
        return std.hash_map.hashString(x_slice);
    }
};

pub const StringLiteralAdapter = struct {
    bytes: *std.ArrayListUnmanaged(u8),

    pub fn eql(self: @This(), a_slice: []const u8, b: StringLiteralContext.Key) bool {
        const b_slice = self.bytes.items[b.index..][0..b.len];
        return mem.eql(u8, a_slice, b_slice);
    }

    pub fn hash(self: @This(), adapted_key: []const u8) u64 {
        _ = self;
        return std.hash_map.hashString(adapted_key);
    }
};

const MonomorphedFuncsSet = std.HashMapUnmanaged(
    *Fn,
    void,
    MonomorphedFuncsContext,
    std.hash_map.default_max_load_percentage,
);

const MonomorphedFuncsContext = struct {
    pub fn eql(ctx: @This(), a: *Fn, b: *Fn) bool {
        _ = ctx;
        return a == b;
    }

    /// Must match `Sema.GenericCallAdapter.hash`.
    pub fn hash(ctx: @This(), key: *Fn) u64 {
        _ = ctx;
        return key.hash;
    }
};

pub const WipAnalysis = struct {
    sema: *Sema,
    block: *Sema.Block,
    src: Module.LazySrcLoc,
};

pub const MemoizedCallSet = std.HashMapUnmanaged(
    MemoizedCall.Key,
    MemoizedCall.Result,
    MemoizedCall,
    std.hash_map.default_max_load_percentage,
);

pub const MemoizedCall = struct {
    module: *Module,

    pub const Key = struct {
        func: *Fn,
        args: []TypedValue,
    };

    pub const Result = struct {
        val: Value,
        arena: std.heap.ArenaAllocator.State,
    };

    pub fn eql(ctx: @This(), a: Key, b: Key) bool {
        if (a.func != b.func) return false;

        assert(a.args.len == b.args.len);
        for (a.args) |a_arg, arg_i| {
            const b_arg = b.args[arg_i];
            if (!a_arg.eql(b_arg, ctx.module)) {
                return false;
            }
        }

        return true;
    }

    /// Must match `Sema.GenericCallAdapter.hash`.
    pub fn hash(ctx: @This(), key: Key) u64 {
        var hasher = std.hash.Wyhash.init(0);

        // The generic function Decl is guaranteed to be the first dependency
        // of each of its instantiations.
        std.hash.autoHash(&hasher, key.func);

        // This logic must be kept in sync with the logic in `analyzeCall` that
        // computes the hash.
        for (key.args) |arg| {
            arg.hash(&hasher, ctx.module);
        }

        return hasher.final();
    }
};

pub const SetAlignStack = struct {
    alignment: u32,
    /// TODO: This needs to store a non-lazy source location for the case of an inline function
    /// which does `@setAlignStack` (applying it to the caller).
    src: LazySrcLoc,
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
        return global_emit_h.allocated_emit_h.at(@enumToInt(decl_index));
    }
};

pub const ErrorInt = u32;

pub const Export = struct {
    options: std.builtin.ExportOptions,
    src: LazySrcLoc,
    /// Represents the position of the export, if any, in the output file.
    link: link.File.Export,
    /// The Decl that performs the export. Note that this is *not* the Decl being exported.
    owner_decl: Decl.Index,
    /// The Decl containing the export statement.  Inline function calls
    /// may cause this to be different from the owner_decl.
    src_decl: Decl.Index,
    /// The Decl being exported. Note this is *not* the Decl performing the export.
    exported_decl: Decl.Index,
    status: enum {
        in_progress,
        failed,
        /// Indicates that the failure was due to a temporary issue, such as an I/O error
        /// when writing to the output file. Retrying the export may succeed.
        failed_retryable,
        complete,
    },

    pub fn getSrcLoc(exp: Export, mod: *Module) SrcLoc {
        const src_decl = mod.declPtr(exp.src_decl);
        return .{
            .file_scope = src_decl.getFileScope(),
            .parent_decl_node = src_decl.src_node,
            .lazy = exp.src,
        };
    }
};

pub const CaptureScope = struct {
    parent: ?*CaptureScope,

    /// Values from this decl's evaluation that will be closed over in
    /// child decls. Values stored in the value_arena of the linked decl.
    /// During sema, this map is backed by the gpa.  Once sema completes,
    /// it is reallocated using the value_arena.
    captures: std.AutoHashMapUnmanaged(Zir.Inst.Index, TypedValue) = .{},
};

pub const WipCaptureScope = struct {
    scope: *CaptureScope,
    finalized: bool,
    gpa: Allocator,
    perm_arena: Allocator,

    pub fn init(gpa: Allocator, perm_arena: Allocator, parent: ?*CaptureScope) !@This() {
        const scope = try perm_arena.create(CaptureScope);
        scope.* = .{ .parent = parent };
        return @This(){
            .scope = scope,
            .finalized = false,
            .gpa = gpa,
            .perm_arena = perm_arena,
        };
    }

    pub fn finalize(noalias self: *@This()) !void {
        assert(!self.finalized);
        // use a temp to avoid unintentional aliasing due to RLS
        const tmp = try self.scope.captures.clone(self.perm_arena);
        self.scope.captures.deinit(self.gpa);
        self.scope.captures = tmp;
        self.finalized = true;
    }

    pub fn reset(noalias self: *@This(), parent: ?*CaptureScope) !void {
        if (!self.finalized) try self.finalize();
        self.scope = try self.perm_arena.create(CaptureScope);
        self.scope.* = .{ .parent = parent };
        self.finalized = false;
    }

    pub fn deinit(noalias self: *@This()) void {
        if (!self.finalized) {
            self.scope.captures.deinit(self.gpa);
        }
        self.* = undefined;
    }
};

pub const Decl = struct {
    /// Allocated with Module's allocator; outlives the ZIR code.
    name: [*:0]const u8,
    /// The most recent Type of the Decl after a successful semantic analysis.
    /// Populated when `has_tv`.
    ty: Type,
    /// The most recent Value of the Decl after a successful semantic analysis.
    /// Populated when `has_tv`.
    val: Value,
    /// Populated when `has_tv`.
    /// Points to memory inside value_arena.
    @"linksection": ?[*:0]const u8,
    /// Populated when `has_tv`.
    @"align": u32,
    /// Populated when `has_tv`.
    @"addrspace": std.builtin.AddressSpace,
    /// The memory for ty, val, align, linksection, and captures.
    /// If this is `null` then there is no memory management needed.
    value_arena: ?*std.heap.ArenaAllocator.State = null,
    /// The direct parent namespace of the Decl.
    /// Reference to externally owned memory.
    /// In the case of the Decl corresponding to a file, this is
    /// the namespace of the struct, since there is no parent.
    src_namespace: *Namespace,

    /// The scope which lexically contains this decl.  A decl must depend
    /// on its lexical parent, in order to ensure that this pointer is valid.
    /// This scope is allocated out of the arena of the parent decl.
    src_scope: ?*CaptureScope,

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
    /// For anonymous decls and also the root Decl for a File, this is 0.
    zir_decl_index: Zir.Inst.Index,

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
    /// Whether the Decl is a `usingnamespace` declaration.
    is_usingnamespace: bool,
    /// If true `name` is already fully qualified.
    name_fully_qualified: bool = false,

    /// Represents the position of the code in the output file.
    /// This is populated regardless of semantic analysis and code generation.
    link: link.File.LinkBlock,

    /// Represents the function in the linked output file, if the `Decl` is a function.
    /// This is stored here and not in `Fn` because `Decl` survives across updates but
    /// `Fn` does not.
    /// TODO Look into making `Fn` a longer lived structure and moving this field there
    /// to save on memory usage.
    fn_link: link.File.LinkFn,

    /// The shallow set of other decls whose typed_value could possibly change if this Decl's
    /// typed_value is modified.
    dependants: DepsTable = .{},
    /// The shallow set of other decls whose typed_value changing indicates that this Decl's
    /// typed_value may need to be regenerated.
    dependencies: DepsTable = .{},

    pub const Index = enum(u32) {
        _,

        pub fn toOptional(i: Index) OptionalIndex {
            return @intToEnum(OptionalIndex, @enumToInt(i));
        }
    };

    pub const OptionalIndex = enum(u32) {
        none = std.math.maxInt(u32),
        _,

        pub fn init(oi: ?Index) OptionalIndex {
            return oi orelse .none;
        }

        pub fn unwrap(oi: OptionalIndex) ?Index {
            if (oi == .none) return null;
            return @intToEnum(Index, @enumToInt(oi));
        }
    };

    pub const DepsTable = std.AutoArrayHashMapUnmanaged(Decl.Index, void);

    pub fn clearName(decl: *Decl, gpa: Allocator) void {
        gpa.free(mem.sliceTo(decl.name, 0));
        decl.name = undefined;
    }

    pub fn clearValues(decl: *Decl, mod: *Module) void {
        const gpa = mod.gpa;
        if (decl.getExternFn()) |extern_fn| {
            extern_fn.deinit(gpa);
            gpa.destroy(extern_fn);
        }
        if (decl.getFunction()) |func| {
            func.deinit(gpa);
            gpa.destroy(func);
        }
        if (decl.getVariable()) |variable| {
            variable.deinit(gpa);
            gpa.destroy(variable);
        }
        if (decl.value_arena) |arena_state| {
            if (decl.owns_tv) {
                if (decl.val.castTag(.str_lit)) |str_lit| {
                    mod.string_literal_table.getPtrContext(str_lit.data, .{
                        .bytes = &mod.string_literal_bytes,
                    }).?.* = .none;
                }
            }
            arena_state.promote(gpa).deinit();
            decl.value_arena = null;
            decl.has_tv = false;
            decl.owns_tv = false;
        }
    }

    pub fn finalizeNewArena(decl: *Decl, arena: *std.heap.ArenaAllocator) !void {
        assert(decl.value_arena == null);
        const arena_state = try arena.allocator().create(std.heap.ArenaAllocator.State);
        arena_state.* = arena.state;
        decl.value_arena = arena_state;
    }

    /// This name is relative to the containing namespace of the decl.
    /// The memory is owned by the containing File ZIR.
    pub fn getName(decl: Decl) ?[:0]const u8 {
        const zir = decl.getFileScope().zir;
        return decl.getNameZir(zir);
    }

    pub fn getNameZir(decl: Decl, zir: Zir) ?[:0]const u8 {
        assert(decl.zir_decl_index != 0);
        const name_index = zir.extra[decl.zir_decl_index + 5];
        if (name_index <= 1) return null;
        return zir.nullTerminatedString(name_index);
    }

    pub fn contentsHash(decl: Decl) std.zig.SrcHash {
        const zir = decl.getFileScope().zir;
        return decl.contentsHashZir(zir);
    }

    pub fn contentsHashZir(decl: Decl, zir: Zir) std.zig.SrcHash {
        assert(decl.zir_decl_index != 0);
        const hash_u32s = zir.extra[decl.zir_decl_index..][0..4];
        const contents_hash = @bitCast(std.zig.SrcHash, hash_u32s.*);
        return contents_hash;
    }

    pub fn zirBlockIndex(decl: *const Decl) Zir.Inst.Index {
        assert(decl.zir_decl_index != 0);
        const zir = decl.getFileScope().zir;
        return zir.extra[decl.zir_decl_index + 6];
    }

    pub fn zirAlignRef(decl: Decl) Zir.Inst.Ref {
        if (!decl.has_align) return .none;
        assert(decl.zir_decl_index != 0);
        const zir = decl.getFileScope().zir;
        return @intToEnum(Zir.Inst.Ref, zir.extra[decl.zir_decl_index + 8]);
    }

    pub fn zirLinksectionRef(decl: Decl) Zir.Inst.Ref {
        if (!decl.has_linksection_or_addrspace) return .none;
        assert(decl.zir_decl_index != 0);
        const zir = decl.getFileScope().zir;
        const extra_index = decl.zir_decl_index + 8 + @boolToInt(decl.has_align);
        return @intToEnum(Zir.Inst.Ref, zir.extra[extra_index]);
    }

    pub fn zirAddrspaceRef(decl: Decl) Zir.Inst.Ref {
        if (!decl.has_linksection_or_addrspace) return .none;
        assert(decl.zir_decl_index != 0);
        const zir = decl.getFileScope().zir;
        const extra_index = decl.zir_decl_index + 8 + @boolToInt(decl.has_align) + 1;
        return @intToEnum(Zir.Inst.Ref, zir.extra[extra_index]);
    }

    pub fn relativeToLine(decl: Decl, offset: u32) u32 {
        return decl.src_line + offset;
    }

    pub fn relativeToNodeIndex(decl: Decl, offset: i32) Ast.Node.Index {
        return @bitCast(Ast.Node.Index, offset + @bitCast(i32, decl.src_node));
    }

    pub fn nodeIndexToRelative(decl: Decl, node_index: Ast.Node.Index) i32 {
        return @bitCast(i32, node_index) - @bitCast(i32, decl.src_node);
    }

    pub fn tokSrcLoc(decl: Decl, token_index: Ast.TokenIndex) LazySrcLoc {
        return .{ .token_offset = token_index - decl.srcToken() };
    }

    pub fn nodeSrcLoc(decl: Decl, node_index: Ast.Node.Index) LazySrcLoc {
        return LazySrcLoc.nodeOffset(decl.nodeIndexToRelative(node_index));
    }

    pub fn srcLoc(decl: Decl) SrcLoc {
        return decl.nodeOffsetSrcLoc(0);
    }

    pub fn nodeOffsetSrcLoc(decl: Decl, node_offset: i32) SrcLoc {
        return .{
            .file_scope = decl.getFileScope(),
            .parent_decl_node = decl.src_node,
            .lazy = LazySrcLoc.nodeOffset(node_offset),
        };
    }

    pub fn srcToken(decl: Decl) Ast.TokenIndex {
        const tree = &decl.getFileScope().tree;
        return tree.firstToken(decl.src_node);
    }

    pub fn srcByteOffset(decl: Decl) u32 {
        const tree = &decl.getFileScope().tree;
        return tree.tokens.items(.start)[decl.srcToken()];
    }

    pub fn renderFullyQualifiedName(decl: Decl, mod: *Module, writer: anytype) !void {
        const unqualified_name = mem.sliceTo(decl.name, 0);
        if (decl.name_fully_qualified) {
            return writer.writeAll(unqualified_name);
        }
        return decl.src_namespace.renderFullyQualifiedName(mod, unqualified_name, writer);
    }

    pub fn renderFullyQualifiedDebugName(decl: Decl, mod: *Module, writer: anytype) !void {
        const unqualified_name = mem.sliceTo(decl.name, 0);
        return decl.src_namespace.renderFullyQualifiedDebugName(mod, unqualified_name, writer);
    }

    pub fn getFullyQualifiedName(decl: Decl, mod: *Module) ![:0]u8 {
        var buffer = std.ArrayList(u8).init(mod.gpa);
        defer buffer.deinit();
        try decl.renderFullyQualifiedName(mod, buffer.writer());
        return buffer.toOwnedSliceSentinel(0);
    }

    pub fn typedValue(decl: Decl) error{AnalysisFail}!TypedValue {
        if (!decl.has_tv) return error.AnalysisFail;
        return TypedValue{
            .ty = decl.ty,
            .val = decl.val,
        };
    }

    pub fn value(decl: *Decl) error{AnalysisFail}!Value {
        return (try decl.typedValue()).val;
    }

    pub fn isFunction(decl: Decl) !bool {
        const tv = try decl.typedValue();
        return tv.ty.zigTypeTag() == .Fn;
    }

    /// If the Decl has a value and it is a struct, return it,
    /// otherwise null.
    pub fn getStruct(decl: *Decl) ?*Struct {
        if (!decl.owns_tv) return null;
        const ty = (decl.val.castTag(.ty) orelse return null).data;
        const struct_obj = (ty.castTag(.@"struct") orelse return null).data;
        return struct_obj;
    }

    /// If the Decl has a value and it is a union, return it,
    /// otherwise null.
    pub fn getUnion(decl: *Decl) ?*Union {
        if (!decl.owns_tv) return null;
        const ty = (decl.val.castTag(.ty) orelse return null).data;
        const union_obj = (ty.cast(Type.Payload.Union) orelse return null).data;
        return union_obj;
    }

    /// If the Decl has a value and it is a function, return it,
    /// otherwise null.
    pub fn getFunction(decl: *const Decl) ?*Fn {
        if (!decl.owns_tv) return null;
        const func = (decl.val.castTag(.function) orelse return null).data;
        return func;
    }

    /// If the Decl has a value and it is an extern function, returns it,
    /// otherwise null.
    pub fn getExternFn(decl: *const Decl) ?*ExternFn {
        if (!decl.owns_tv) return null;
        const extern_fn = (decl.val.castTag(.extern_fn) orelse return null).data;
        return extern_fn;
    }

    /// If the Decl has a value and it is a variable, returns it,
    /// otherwise null.
    pub fn getVariable(decl: *const Decl) ?*Var {
        if (!decl.owns_tv) return null;
        const variable = (decl.val.castTag(.variable) orelse return null).data;
        return variable;
    }

    /// Gets the namespace that this Decl creates by being a struct, union,
    /// enum, or opaque.
    /// Only returns it if the Decl is the owner.
    pub fn getInnerNamespace(decl: *Decl) ?*Namespace {
        if (!decl.owns_tv) return null;
        const ty = (decl.val.castTag(.ty) orelse return null).data;
        switch (ty.tag()) {
            .@"struct" => {
                const struct_obj = ty.castTag(.@"struct").?.data;
                return &struct_obj.namespace;
            },
            .enum_full, .enum_nonexhaustive => {
                const enum_obj = ty.cast(Type.Payload.EnumFull).?.data;
                return &enum_obj.namespace;
            },
            .empty_struct => {
                return ty.castTag(.empty_struct).?.data;
            },
            .@"opaque" => {
                const opaque_obj = ty.cast(Type.Payload.Opaque).?.data;
                return &opaque_obj.namespace;
            },
            .@"union", .union_tagged => {
                const union_obj = ty.cast(Type.Payload.Union).?.data;
                return &union_obj.namespace;
            },

            else => return null,
        }
    }

    pub fn dump(decl: *Decl) void {
        const loc = std.zig.findLineColumn(decl.scope.source.bytes, decl.src);
        std.debug.print("{s}:{d}:{d} name={s} status={s}", .{
            decl.scope.sub_file_path,
            loc.line + 1,
            loc.column + 1,
            mem.sliceTo(decl.name, 0),
            @tagName(decl.analysis),
        });
        if (decl.has_tv) {
            std.debug.print(" ty={} val={}", .{ decl.ty, decl.val });
        }
        std.debug.print("\n", .{});
    }

    pub fn getFileScope(decl: Decl) *File {
        return decl.src_namespace.file_scope;
    }

    pub fn removeDependant(decl: *Decl, other: Decl.Index) void {
        assert(decl.dependants.swapRemove(other));
    }

    pub fn removeDependency(decl: *Decl, other: Decl.Index) void {
        assert(decl.dependencies.swapRemove(other));
    }

    pub fn isExtern(decl: Decl) bool {
        assert(decl.has_tv);
        return switch (decl.val.tag()) {
            .extern_fn => true,
            .variable => decl.val.castTag(.variable).?.data.init.tag() == .unreachable_value,
            else => false,
        };
    }

    pub fn getAlignment(decl: Decl, target: Target) u32 {
        assert(decl.has_tv);
        if (decl.@"align" != 0) {
            // Explicit alignment.
            return decl.@"align";
        } else {
            // Natural alignment.
            return decl.ty.abiAlignment(target);
        }
    }
};

/// This state is attached to every Decl when Module emit_h is non-null.
pub const EmitH = struct {
    fwd_decl: ArrayListUnmanaged(u8) = .{},
};

/// Represents the data that an explicit error set syntax provides.
pub const ErrorSet = struct {
    /// The Decl that corresponds to the error set itself.
    owner_decl: Decl.Index,
    /// Offset from Decl node index, points to the error set AST node.
    node_offset: i32,
    /// The string bytes are stored in the owner Decl arena.
    /// These must be in sorted order. See sortNames.
    names: NameMap,

    pub const NameMap = std.StringArrayHashMapUnmanaged(void);

    pub fn srcLoc(self: ErrorSet, mod: *Module) SrcLoc {
        const owner_decl = mod.declPtr(self.owner_decl);
        return .{
            .file_scope = owner_decl.getFileScope(),
            .parent_decl_node = owner_decl.src_node,
            .lazy = LazySrcLoc.nodeOffset(self.node_offset),
        };
    }

    /// sort the NameMap. This should be called whenever the map is modified.
    /// alloc should be the allocator used for the NameMap data.
    pub fn sortNames(names: *NameMap) void {
        const Context = struct {
            keys: [][]const u8,
            pub fn lessThan(ctx: @This(), a_index: usize, b_index: usize) bool {
                return std.mem.lessThan(u8, ctx.keys[a_index], ctx.keys[b_index]);
            }
        };
        names.sort(Context{ .keys = names.keys() });
    }
};

pub const PropertyBoolean = enum { no, yes, unknown, wip };

/// Represents the data that a struct declaration provides.
pub const Struct = struct {
    /// Set of field names in declaration order.
    fields: Fields,
    /// Represents the declarations inside this struct.
    namespace: Namespace,
    /// The Decl that corresponds to the struct itself.
    owner_decl: Decl.Index,
    /// Offset from `owner_decl`, points to the struct AST node.
    node_offset: i32,
    /// Index of the struct_decl ZIR instruction.
    zir_index: Zir.Inst.Index,

    layout: std.builtin.Type.ContainerLayout,
    status: enum {
        none,
        field_types_wip,
        have_field_types,
        layout_wip,
        have_layout,
        fully_resolved_wip,
        // The types and all its fields have had their layout resolved. Even through pointer,
        // which `have_layout` does not ensure.
        fully_resolved,
    },
    /// If true, has more than one possible value. However it may still be non-runtime type
    /// if it is a comptime-only type.
    /// If false, resolving the fields is necessary to determine whether the type has only
    /// one possible value.
    known_non_opv: bool,
    requires_comptime: PropertyBoolean = .unknown,
    have_field_inits: bool = false,

    pub const Fields = std.StringArrayHashMapUnmanaged(Field);

    /// The `Type` and `Value` memory is owned by the arena of the Struct's owner_decl.
    pub const Field = struct {
        /// Uses `noreturn` to indicate `anytype`.
        /// undefined until `status` is >= `have_field_types`.
        ty: Type,
        /// Uses `unreachable_value` to indicate no default.
        default_val: Value,
        /// Zero means to use the ABI alignment of the type.
        abi_align: u32,
        /// undefined until `status` is `have_layout`.
        offset: u32,
        /// If true then `default_val` is the comptime field value.
        is_comptime: bool,

        /// Returns the field alignment, assuming the struct is not packed.
        pub fn normalAlignment(field: Field, target: Target) u32 {
            if (field.abi_align == 0) {
                return field.ty.abiAlignment(target);
            } else {
                return field.abi_align;
            }
        }
    };

    pub fn getFullyQualifiedName(s: *Struct, mod: *Module) ![:0]u8 {
        return mod.declPtr(s.owner_decl).getFullyQualifiedName(mod);
    }

    pub fn srcLoc(s: Struct, mod: *Module) SrcLoc {
        const owner_decl = mod.declPtr(s.owner_decl);
        return .{
            .file_scope = owner_decl.getFileScope(),
            .parent_decl_node = owner_decl.src_node,
            .lazy = LazySrcLoc.nodeOffset(s.node_offset),
        };
    }

    pub fn fieldSrcLoc(s: Struct, mod: *Module, query: FieldSrcQuery) SrcLoc {
        @setCold(true);
        const owner_decl = mod.declPtr(s.owner_decl);
        const file = owner_decl.getFileScope();
        const tree = file.getTree(mod.gpa) catch |err| {
            // In this case we emit a warning + a less precise source location.
            log.warn("unable to load {s}: {s}", .{
                file.sub_file_path, @errorName(err),
            });
            return s.srcLoc(mod);
        };
        const node = owner_decl.relativeToNodeIndex(s.node_offset);
        const node_tags = tree.nodes.items(.tag);
        switch (node_tags[node]) {
            .container_decl,
            .container_decl_trailing,
            => return queryFieldSrc(tree.*, query, file, tree.containerDecl(node)),
            .container_decl_two, .container_decl_two_trailing => {
                var buffer: [2]Ast.Node.Index = undefined;
                return queryFieldSrc(tree.*, query, file, tree.containerDeclTwo(&buffer, node));
            },
            .container_decl_arg,
            .container_decl_arg_trailing,
            => return queryFieldSrc(tree.*, query, file, tree.containerDeclArg(node)),

            .tagged_union,
            .tagged_union_trailing,
            => return queryFieldSrc(tree.*, query, file, tree.taggedUnion(node)),
            .tagged_union_two, .tagged_union_two_trailing => {
                var buffer: [2]Ast.Node.Index = undefined;
                return queryFieldSrc(tree.*, query, file, tree.taggedUnionTwo(&buffer, node));
            },
            .tagged_union_enum_tag,
            .tagged_union_enum_tag_trailing,
            => return queryFieldSrc(tree.*, query, file, tree.taggedUnionEnumTag(node)),

            .root => return queryFieldSrc(tree.*, query, file, tree.containerDeclRoot()),

            else => unreachable,
        }
    }

    pub fn haveFieldTypes(s: Struct) bool {
        return switch (s.status) {
            .none,
            .field_types_wip,
            => false,
            .have_field_types,
            .layout_wip,
            .have_layout,
            .fully_resolved_wip,
            .fully_resolved,
            => true,
        };
    }

    pub fn haveLayout(s: Struct) bool {
        return switch (s.status) {
            .none,
            .field_types_wip,
            .have_field_types,
            .layout_wip,
            => false,
            .have_layout,
            .fully_resolved_wip,
            .fully_resolved,
            => true,
        };
    }

    pub fn packedFieldBitOffset(s: Struct, target: Target, index: usize) u16 {
        assert(s.layout == .Packed);
        assert(s.haveFieldTypes());
        var bit_sum: u64 = 0;
        for (s.fields.values()) |field, i| {
            if (i == index) {
                return @intCast(u16, bit_sum);
            }
            bit_sum += field.ty.bitSize(target);
        }
        return @intCast(u16, bit_sum);
    }

    pub fn packedIntegerBits(s: Struct, target: Target) u16 {
        return s.packedFieldBitOffset(target, s.fields.count());
    }

    pub fn packedIntegerType(s: Struct, target: Target, buf: *Type.Payload.Bits) Type {
        buf.* = .{
            .base = .{ .tag = .int_unsigned },
            .data = s.packedIntegerBits(target),
        };
        return Type.initPayload(&buf.base);
    }
};

/// Represents the data that an enum declaration provides, when the fields
/// are auto-numbered, and there are no declarations. The integer tag type
/// is inferred to be the smallest power of two unsigned int that fits
/// the number of fields.
pub const EnumSimple = struct {
    /// The Decl that corresponds to the enum itself.
    owner_decl: Decl.Index,
    /// Offset from `owner_decl`, points to the enum decl AST node.
    node_offset: i32,
    /// Set of field names in declaration order.
    fields: NameMap,

    pub const NameMap = EnumFull.NameMap;

    pub fn srcLoc(self: EnumSimple, mod: *Module) SrcLoc {
        const owner_decl = mod.declPtr(self.owner_decl);
        return .{
            .file_scope = owner_decl.getFileScope(),
            .parent_decl_node = owner_decl.src_node,
            .lazy = LazySrcLoc.nodeOffset(self.node_offset),
        };
    }
};

/// Represents the data that an enum declaration provides, when there are no
/// declarations. However an integer tag type is provided, and the enum tag values
/// are explicitly provided.
pub const EnumNumbered = struct {
    /// The Decl that corresponds to the enum itself.
    owner_decl: Decl.Index,
    /// Offset from `owner_decl`, points to the enum decl AST node.
    node_offset: i32,
    /// An integer type which is used for the numerical value of the enum.
    /// Whether zig chooses this type or the user specifies it, it is stored here.
    tag_ty: Type,
    /// Set of field names in declaration order.
    fields: NameMap,
    /// Maps integer tag value to field index.
    /// Entries are in declaration order, same as `fields`.
    /// If this hash map is empty, it means the enum tags are auto-numbered.
    values: ValueMap,

    pub const NameMap = EnumFull.NameMap;
    pub const ValueMap = EnumFull.ValueMap;

    pub fn srcLoc(self: EnumNumbered, mod: *Module) SrcLoc {
        const owner_decl = mod.declPtr(self.owner_decl);
        return .{
            .file_scope = owner_decl.getFileScope(),
            .parent_decl_node = owner_decl.src_node,
            .lazy = LazySrcLoc.nodeOffset(self.node_offset),
        };
    }
};

/// Represents the data that an enum declaration provides, when there is
/// at least one tag value explicitly specified, or at least one declaration.
pub const EnumFull = struct {
    /// The Decl that corresponds to the enum itself.
    owner_decl: Decl.Index,
    /// Offset from `owner_decl`, points to the enum decl AST node.
    node_offset: i32,
    /// An integer type which is used for the numerical value of the enum.
    /// Whether zig chooses this type or the user specifies it, it is stored here.
    tag_ty: Type,
    /// Set of field names in declaration order.
    fields: NameMap,
    /// Maps integer tag value to field index.
    /// Entries are in declaration order, same as `fields`.
    /// If this hash map is empty, it means the enum tags are auto-numbered.
    values: ValueMap,
    /// Represents the declarations inside this enum.
    namespace: Namespace,
    /// true if zig inferred this tag type, false if user specified it
    tag_ty_inferred: bool,

    pub const NameMap = std.StringArrayHashMapUnmanaged(void);
    pub const ValueMap = std.ArrayHashMapUnmanaged(Value, void, Value.ArrayHashContext, false);

    pub fn srcLoc(self: EnumFull, mod: *Module) SrcLoc {
        const owner_decl = mod.declPtr(self.owner_decl);
        return .{
            .file_scope = owner_decl.getFileScope(),
            .parent_decl_node = owner_decl.src_node,
            .lazy = LazySrcLoc.nodeOffset(self.node_offset),
        };
    }
};

pub const Union = struct {
    /// An enum type which is used for the tag of the union.
    /// This type is created even for untagged unions, even when the memory
    /// layout does not store the tag.
    /// Whether zig chooses this type or the user specifies it, it is stored here.
    /// This will be set to the null type until status is `have_field_types`.
    tag_ty: Type,
    /// Set of field names in declaration order.
    fields: Fields,
    /// Represents the declarations inside this union.
    namespace: Namespace,
    /// The Decl that corresponds to the union itself.
    owner_decl: Decl.Index,
    /// Offset from `owner_decl`, points to the union decl AST node.
    node_offset: i32,
    /// Index of the union_decl ZIR instruction.
    zir_index: Zir.Inst.Index,

    layout: std.builtin.Type.ContainerLayout,
    status: enum {
        none,
        field_types_wip,
        have_field_types,
        layout_wip,
        have_layout,
        fully_resolved_wip,
        // The types and all its fields have had their layout resolved. Even through pointer,
        // which `have_layout` does not ensure.
        fully_resolved,
    },
    requires_comptime: PropertyBoolean = .unknown,

    pub const Field = struct {
        /// undefined until `status` is `have_field_types` or `have_layout`.
        ty: Type,
        /// 0 means the ABI alignment of the type.
        abi_align: u32,

        /// Returns the field alignment, assuming the union is not packed.
        /// Keep implementation in sync with `Sema.unionFieldAlignment`.
        /// Prefer to call that function instead of this one during Sema.
        pub fn normalAlignment(field: Field, target: Target) u32 {
            if (field.abi_align == 0) {
                return field.ty.abiAlignment(target);
            } else {
                return field.abi_align;
            }
        }
    };

    pub const Fields = std.StringArrayHashMapUnmanaged(Field);

    pub fn getFullyQualifiedName(s: *Union, mod: *Module) ![:0]u8 {
        return mod.declPtr(s.owner_decl).getFullyQualifiedName(mod);
    }

    pub fn srcLoc(self: Union, mod: *Module) SrcLoc {
        const owner_decl = mod.declPtr(self.owner_decl);
        return .{
            .file_scope = owner_decl.getFileScope(),
            .parent_decl_node = owner_decl.src_node,
            .lazy = LazySrcLoc.nodeOffset(self.node_offset),
        };
    }

    pub fn fieldSrcLoc(u: Union, mod: *Module, query: FieldSrcQuery) SrcLoc {
        @setCold(true);
        const owner_decl = mod.declPtr(u.owner_decl);
        const file = owner_decl.getFileScope();
        const tree = file.getTree(mod.gpa) catch |err| {
            // In this case we emit a warning + a less precise source location.
            log.warn("unable to load {s}: {s}", .{
                file.sub_file_path, @errorName(err),
            });
            return u.srcLoc(mod);
        };
        const node = owner_decl.relativeToNodeIndex(u.node_offset);
        const node_tags = tree.nodes.items(.tag);
        switch (node_tags[node]) {
            .container_decl,
            .container_decl_trailing,
            => return queryFieldSrc(tree.*, query, file, tree.containerDecl(node)),
            .container_decl_two, .container_decl_two_trailing => {
                var buffer: [2]Ast.Node.Index = undefined;
                return queryFieldSrc(tree.*, query, file, tree.containerDeclTwo(&buffer, node));
            },
            .container_decl_arg,
            .container_decl_arg_trailing,
            => return queryFieldSrc(tree.*, query, file, tree.containerDeclArg(node)),
            else => unreachable,
        }
    }

    pub fn haveFieldTypes(u: Union) bool {
        return switch (u.status) {
            .none,
            .field_types_wip,
            => false,
            .have_field_types,
            .layout_wip,
            .have_layout,
            .fully_resolved_wip,
            .fully_resolved,
            => true,
        };
    }

    pub fn hasAllZeroBitFieldTypes(u: Union) bool {
        assert(u.haveFieldTypes());
        for (u.fields.values()) |field| {
            if (field.ty.hasRuntimeBits()) return false;
        }
        return true;
    }

    pub fn mostAlignedField(u: Union, target: Target) u32 {
        assert(u.haveFieldTypes());
        var most_alignment: u32 = 0;
        var most_index: usize = undefined;
        for (u.fields.values()) |field, i| {
            if (!field.ty.hasRuntimeBits()) continue;

            const field_align = field.normalAlignment(target);
            if (field_align > most_alignment) {
                most_alignment = field_align;
                most_index = i;
            }
        }
        return @intCast(u32, most_index);
    }

    /// Returns 0 if the union is represented with 0 bits at runtime.
    pub fn abiAlignment(u: Union, target: Target, have_tag: bool) u32 {
        var max_align: u32 = 0;
        if (have_tag) max_align = u.tag_ty.abiAlignment(target);
        for (u.fields.values()) |field| {
            if (!field.ty.hasRuntimeBits()) continue;

            const field_align = field.normalAlignment(target);
            max_align = @maximum(max_align, field_align);
        }
        return max_align;
    }

    pub fn abiSize(u: Union, target: Target, have_tag: bool) u64 {
        return u.getLayout(target, have_tag).abi_size;
    }

    pub const Layout = struct {
        abi_size: u64,
        abi_align: u32,
        most_aligned_field: u32,
        most_aligned_field_size: u64,
        biggest_field: u32,
        payload_size: u64,
        payload_align: u32,
        tag_align: u32,
        tag_size: u64,
        padding: u32,
    };

    pub fn haveLayout(u: Union) bool {
        return switch (u.status) {
            .none,
            .field_types_wip,
            .have_field_types,
            .layout_wip,
            => false,
            .have_layout,
            .fully_resolved_wip,
            .fully_resolved,
            => true,
        };
    }

    pub fn getLayout(u: Union, target: Target, have_tag: bool) Layout {
        assert(u.haveLayout());
        var most_aligned_field: u32 = undefined;
        var most_aligned_field_size: u64 = undefined;
        var biggest_field: u32 = undefined;
        var payload_size: u64 = 0;
        var payload_align: u32 = 0;
        const fields = u.fields.values();
        for (fields) |field, i| {
            if (!field.ty.hasRuntimeBitsIgnoreComptime()) continue;

            const field_align = a: {
                if (field.abi_align == 0) {
                    break :a field.ty.abiAlignment(target);
                } else {
                    break :a field.abi_align;
                }
            };
            const field_size = field.ty.abiSize(target);
            if (field_size > payload_size) {
                payload_size = field_size;
                biggest_field = @intCast(u32, i);
            }
            if (field_align > payload_align) {
                payload_align = field_align;
                most_aligned_field = @intCast(u32, i);
                most_aligned_field_size = field_size;
            }
        }
        payload_align = @maximum(payload_align, 1);
        if (!have_tag or fields.len <= 1) return .{
            .abi_size = std.mem.alignForwardGeneric(u64, payload_size, payload_align),
            .abi_align = payload_align,
            .most_aligned_field = most_aligned_field,
            .most_aligned_field_size = most_aligned_field_size,
            .biggest_field = biggest_field,
            .payload_size = payload_size,
            .payload_align = payload_align,
            .tag_align = 0,
            .tag_size = 0,
            .padding = 0,
        };
        // Put the tag before or after the payload depending on which one's
        // alignment is greater.
        const tag_size = u.tag_ty.abiSize(target);
        const tag_align = @maximum(1, u.tag_ty.abiAlignment(target));
        var size: u64 = 0;
        var padding: u32 = undefined;
        if (tag_align >= payload_align) {
            // {Tag, Payload}
            size += tag_size;
            size = std.mem.alignForwardGeneric(u64, size, payload_align);
            size += payload_size;
            const prev_size = size;
            size = std.mem.alignForwardGeneric(u64, size, tag_align);
            padding = @intCast(u32, size - prev_size);
        } else {
            // {Payload, Tag}
            size += payload_size;
            size = std.mem.alignForwardGeneric(u64, size, tag_align);
            size += tag_size;
            const prev_size = size;
            size = std.mem.alignForwardGeneric(u64, size, payload_align);
            padding = @intCast(u32, size - prev_size);
        }
        return .{
            .abi_size = size,
            .abi_align = @maximum(tag_align, payload_align),
            .most_aligned_field = most_aligned_field,
            .most_aligned_field_size = most_aligned_field_size,
            .biggest_field = biggest_field,
            .payload_size = payload_size,
            .payload_align = payload_align,
            .tag_align = tag_align,
            .tag_size = tag_size,
            .padding = padding,
        };
    }
};

pub const Opaque = struct {
    /// The Decl that corresponds to the opaque itself.
    owner_decl: Decl.Index,
    /// Offset from `owner_decl`, points to the opaque decl AST node.
    node_offset: i32,
    /// Represents the declarations inside this opaque.
    namespace: Namespace,

    pub fn srcLoc(self: Opaque, mod: *Module) SrcLoc {
        const owner_decl = mod.declPtr(self.owner_decl);
        return .{
            .file_scope = owner_decl.getFileScope(),
            .parent_decl_node = owner_decl.src_node,
            .lazy = LazySrcLoc.nodeOffset(self.node_offset),
        };
    }

    pub fn getFullyQualifiedName(s: *Opaque, mod: *Module) ![:0]u8 {
        return mod.declPtr(s.owner_decl).getFullyQualifiedName(mod);
    }
};

/// Some extern function struct memory is owned by the Decl's TypedValue.Managed
/// arena allocator.
pub const ExternFn = struct {
    /// The Decl that corresponds to the function itself.
    owner_decl: Decl.Index,
    /// Library name if specified.
    /// For example `extern "c" fn write(...) usize` would have 'c' as library name.
    /// Allocated with Module's allocator; outlives the ZIR code.
    lib_name: ?[*:0]const u8,

    pub fn deinit(extern_fn: *ExternFn, gpa: Allocator) void {
        if (extern_fn.lib_name) |lib_name| {
            gpa.free(mem.sliceTo(lib_name, 0));
        }
    }
};

/// Some Fn struct memory is owned by the Decl's TypedValue.Managed arena allocator.
/// Extern functions do not have this data structure; they are represented by `ExternFn`
/// instead.
pub const Fn = struct {
    /// The Decl that corresponds to the function itself.
    owner_decl: Decl.Index,
    /// The ZIR instruction that is a function instruction. Use this to find
    /// the body. We store this rather than the body directly so that when ZIR
    /// is regenerated on update(), we can map this to the new corresponding
    /// ZIR instruction.
    zir_body_inst: Zir.Inst.Index,
    /// If this is not null, this function is a generic function instantiation, and
    /// there is a `TypedValue` here for each parameter of the function.
    /// Non-comptime parameters are marked with a `generic_poison` for the value.
    /// Non-anytype parameters are marked with a `generic_poison` for the type.
    /// These never have .generic_poison for the Type
    /// because the Type is needed to pass to `Type.eql` and for inserting comptime arguments
    /// into the inst_map when analyzing the body of a generic function instantiation.
    /// Instead, the is_anytype knowledge is communicated via `anytype_args`.
    comptime_args: ?[*]TypedValue,
    /// When comptime_args is null, this is undefined. Otherwise, this flags each
    /// parameter and tells whether it is anytype.
    /// TODO apply the same enhancement for param_names below to this field.
    anytype_args: [*]bool,

    /// Prefer to use `getParamName` to access this because of the future improvement
    /// we want to do mentioned in the TODO below.
    /// Stored in gpa.
    /// TODO: change param ZIR instructions to be embedded inside the function
    /// ZIR instruction instead of before it, so that `zir_body_inst` can be used to
    /// determine param names rather than redundantly storing them here.
    param_names: []const [:0]const u8,

    /// Precomputed hash for monomorphed_funcs.
    /// This is important because it may be accessed when resizing monomorphed_funcs
    /// while this Fn has already been added to the set, but does not have the
    /// owner_decl, comptime_args, or other fields populated yet.
    hash: u64,

    /// Relative to owner Decl.
    lbrace_line: u32,
    /// Relative to owner Decl.
    rbrace_line: u32,
    lbrace_column: u16,
    rbrace_column: u16,

    /// When a generic function is instantiated, this value is inherited from the
    /// active Sema context. Importantly, this value is also updated when an existing
    /// generic function instantiation is found and called.
    branch_quota: u32,
    state: Analysis,
    is_cold: bool = false,
    is_noinline: bool = false,
    calls_or_awaits_errorable_fn: bool = false,

    /// Any inferred error sets that this function owns, both its own inferred error set and
    /// inferred error sets of any inline/comptime functions called. Not to be confused
    /// with inferred error sets of generic instantiations of this function, which are
    /// *not* tracked here - they are tracked in the new `Fn` object created for the
    /// instantiations.
    inferred_error_sets: InferredErrorSetList = .{},

    pub const Analysis = enum {
        queued,
        /// This function intentionally only has ZIR generated because it is marked
        /// inline, which means no runtime version of the function will be generated.
        inline_only,
        in_progress,
        /// There will be a corresponding ErrorMsg in Module.failed_decls
        sema_failure,
        /// This Fn might be OK but it depends on another Decl which did not
        /// successfully complete semantic analysis.
        dependency_failure,
        success,
    };

    /// This struct is used to keep track of any dependencies related to functions instances
    /// that return inferred error sets. Note that a function may be associated to
    /// multiple different error sets, for example an inferred error set which
    /// this function returns, but also any inferred error sets of called inline
    /// or comptime functions.
    pub const InferredErrorSet = struct {
        /// The function from which this error set originates.
        func: *Fn,

        /// All currently known errors that this error set contains. This includes
        /// direct additions via `return error.Foo;`, and possibly also errors that
        /// are returned from any dependent functions. When the inferred error set is
        /// fully resolved, this map contains all the errors that the function might return.
        errors: ErrorSet.NameMap = .{},

        /// Other inferred error sets which this inferred error set should include.
        inferred_error_sets: std.AutoHashMapUnmanaged(*InferredErrorSet, void) = .{},

        /// Whether the function returned anyerror. This is true if either of
        /// the dependent functions returns anyerror.
        is_anyerror: bool = false,

        /// Whether this error set is already fully resolved. If true, resolving
        /// can skip resolving any dependents of this inferred error set.
        is_resolved: bool = false,

        pub fn addErrorSet(self: *InferredErrorSet, gpa: Allocator, err_set_ty: Type) !void {
            switch (err_set_ty.tag()) {
                .error_set => {
                    const names = err_set_ty.castTag(.error_set).?.data.names.keys();
                    for (names) |name| {
                        try self.errors.put(gpa, name, {});
                    }
                },
                .error_set_single => {
                    const name = err_set_ty.castTag(.error_set_single).?.data;
                    try self.errors.put(gpa, name, {});
                },
                .error_set_inferred => {
                    const ies = err_set_ty.castTag(.error_set_inferred).?.data;
                    try self.inferred_error_sets.put(gpa, ies, {});
                },
                .error_set_merged => {
                    const names = err_set_ty.castTag(.error_set_merged).?.data.keys();
                    for (names) |name| {
                        try self.errors.put(gpa, name, {});
                    }
                },
                .anyerror => {
                    self.is_anyerror = true;
                },
                else => unreachable,
            }
        }
    };

    pub const InferredErrorSetList = std.SinglyLinkedList(InferredErrorSet);
    pub const InferredErrorSetListNode = InferredErrorSetList.Node;

    pub fn deinit(func: *Fn, gpa: Allocator) void {
        var it = func.inferred_error_sets.first;
        while (it) |node| {
            const next = node.next;
            node.data.errors.deinit(gpa);
            node.data.inferred_error_sets.deinit(gpa);
            gpa.destroy(node);
            it = next;
        }

        for (func.param_names) |param_name| {
            gpa.free(param_name);
        }
        gpa.free(func.param_names);
    }

    pub fn getParamName(func: Fn, index: u32) [:0]const u8 {
        // TODO rework ZIR of parameters so that this function looks up
        // param names in ZIR instead of redundantly saving them into Fn.
        // const zir = func.owner_decl.getFileScope().zir;
        return func.param_names[index];
    }

    pub fn hasInferredErrorSet(func: Fn, mod: *Module) bool {
        const owner_decl = mod.declPtr(func.owner_decl);
        const zir = owner_decl.getFileScope().zir;
        const zir_tags = zir.instructions.items(.tag);
        switch (zir_tags[func.zir_body_inst]) {
            .func => return false,
            .func_inferred => return true,
            .func_fancy => {
                const inst_data = zir.instructions.items(.data)[func.zir_body_inst].pl_node;
                const extra = zir.extraData(Zir.Inst.FuncFancy, inst_data.payload_index);
                return extra.data.bits.is_inferred_error;
            },
            else => unreachable,
        }
    }
};

pub const Var = struct {
    /// if is_extern == true this is undefined
    init: Value,
    owner_decl: Decl.Index,

    /// Library name if specified.
    /// For example `extern "c" var stderrp = ...` would have 'c' as library name.
    /// Allocated with Module's allocator; outlives the ZIR code.
    lib_name: ?[*:0]const u8,

    is_extern: bool,
    is_mutable: bool,
    is_threadlocal: bool,
    is_weak_linkage: bool,

    pub fn deinit(variable: *Var, gpa: Allocator) void {
        if (variable.lib_name) |lib_name| {
            gpa.free(mem.sliceTo(lib_name, 0));
        }
    }
};

pub const DeclAdapter = struct {
    mod: *Module,

    pub fn hash(self: @This(), s: []const u8) u32 {
        _ = self;
        return @truncate(u32, std.hash.Wyhash.hash(0, s));
    }

    pub fn eql(self: @This(), a: []const u8, b_decl_index: Decl.Index, b_index: usize) bool {
        _ = b_index;
        const b_decl = self.mod.declPtr(b_decl_index);
        return mem.eql(u8, a, mem.sliceTo(b_decl.name, 0));
    }
};

/// The container that structs, enums, unions, and opaques have.
pub const Namespace = struct {
    parent: ?*Namespace,
    file_scope: *File,
    /// Will be a struct, enum, union, or opaque.
    ty: Type,
    /// Direct children of the namespace. Used during an update to detect
    /// which decls have been added/removed from source.
    /// Declaration order is preserved via entry order.
    /// Key memory is owned by `decl.name`.
    /// Anonymous decls are not stored here; they are kept in `anon_decls` instead.
    decls: std.ArrayHashMapUnmanaged(Decl.Index, void, DeclContext, true) = .{},

    anon_decls: std.AutoArrayHashMapUnmanaged(Decl.Index, void) = .{},

    /// Key is usingnamespace Decl itself. To find the namespace being included,
    /// the Decl Value has to be resolved as a Type which has a Namespace.
    /// Value is whether the usingnamespace decl is marked `pub`.
    usingnamespace_set: std.AutoHashMapUnmanaged(Decl.Index, bool) = .{},

    const DeclContext = struct {
        module: *Module,

        pub fn hash(ctx: @This(), decl_index: Decl.Index) u32 {
            const decl = ctx.module.declPtr(decl_index);
            return @truncate(u32, std.hash.Wyhash.hash(0, mem.sliceTo(decl.name, 0)));
        }

        pub fn eql(ctx: @This(), a_decl_index: Decl.Index, b_decl_index: Decl.Index, b_index: usize) bool {
            _ = b_index;
            const a_decl = ctx.module.declPtr(a_decl_index);
            const b_decl = ctx.module.declPtr(b_decl_index);
            const a_name = mem.sliceTo(a_decl.name, 0);
            const b_name = mem.sliceTo(b_decl.name, 0);
            return mem.eql(u8, a_name, b_name);
        }
    };

    pub fn deinit(ns: *Namespace, mod: *Module) void {
        ns.destroyDecls(mod);
        ns.* = undefined;
    }

    pub fn destroyDecls(ns: *Namespace, mod: *Module) void {
        const gpa = mod.gpa;

        log.debug("destroyDecls {*}", .{ns});

        var decls = ns.decls;
        ns.decls = .{};

        var anon_decls = ns.anon_decls;
        ns.anon_decls = .{};

        for (decls.keys()) |decl_index| {
            mod.destroyDecl(decl_index);
        }
        decls.deinit(gpa);

        for (anon_decls.keys()) |key| {
            mod.destroyDecl(key);
        }
        anon_decls.deinit(gpa);
        ns.usingnamespace_set.deinit(gpa);
    }

    pub fn deleteAllDecls(
        ns: *Namespace,
        mod: *Module,
        outdated_decls: ?*std.AutoArrayHashMap(Decl.Index, void),
    ) !void {
        const gpa = mod.gpa;

        log.debug("deleteAllDecls {*}", .{ns});

        var decls = ns.decls;
        ns.decls = .{};

        var anon_decls = ns.anon_decls;
        ns.anon_decls = .{};

        // TODO rework this code to not panic on OOM.
        // (might want to coordinate with the clearDecl function)

        for (decls.keys()) |child_decl| {
            mod.clearDecl(child_decl, outdated_decls) catch @panic("out of memory");
            mod.destroyDecl(child_decl);
        }
        decls.deinit(gpa);

        for (anon_decls.keys()) |child_decl| {
            mod.clearDecl(child_decl, outdated_decls) catch @panic("out of memory");
            mod.destroyDecl(child_decl);
        }
        anon_decls.deinit(gpa);

        ns.usingnamespace_set.deinit(gpa);
    }

    // This renders e.g. "std.fs.Dir.OpenOptions"
    pub fn renderFullyQualifiedName(
        ns: Namespace,
        mod: *Module,
        name: []const u8,
        writer: anytype,
    ) @TypeOf(writer).Error!void {
        if (ns.parent) |parent| {
            const decl_index = ns.getDeclIndex();
            const decl = mod.declPtr(decl_index);
            try parent.renderFullyQualifiedName(mod, mem.sliceTo(decl.name, 0), writer);
        } else {
            try ns.file_scope.renderFullyQualifiedName(writer);
        }
        if (name.len != 0) {
            try writer.writeAll(".");
            try writer.writeAll(name);
        }
    }

    /// This renders e.g. "std/fs.zig:Dir.OpenOptions"
    pub fn renderFullyQualifiedDebugName(
        ns: Namespace,
        mod: *Module,
        name: []const u8,
        writer: anytype,
    ) @TypeOf(writer).Error!void {
        var separator_char: u8 = '.';
        if (ns.parent) |parent| {
            const decl_index = ns.getDeclIndex();
            const decl = mod.declPtr(decl_index);
            try parent.renderFullyQualifiedDebugName(mod, mem.sliceTo(decl.name, 0), writer);
        } else {
            try ns.file_scope.renderFullyQualifiedDebugName(writer);
            separator_char = ':';
        }
        if (name.len != 0) {
            try writer.writeByte(separator_char);
            try writer.writeAll(name);
        }
    }

    pub fn getDeclIndex(ns: Namespace) Decl.Index {
        return ns.ty.getOwnerDecl();
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
    /// Package that this file is a part of, managed externally.
    pkg: *Package,

    /// Used by change detection algorithm, after astgen, contains the
    /// set of decls that existed in the previous ZIR but not in the new one.
    deleted_decls: std.ArrayListUnmanaged(Decl.Index) = .{},
    /// Used by change detection algorithm, after astgen, contains the
    /// set of decls that existed both in the previous ZIR and in the new one,
    /// but their source code has been modified.
    outdated_decls: std.ArrayListUnmanaged(Decl.Index) = .{},

    /// The most recent successful ZIR for this file, with no errors.
    /// This is only populated when a previously successful ZIR
    /// newly introduces compile errors during an update. When ZIR is
    /// successful, this field is unloaded.
    prev_zir: ?*Zir = null,

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

        const root_dir_path = file.pkg.root_src_directory.path orelse ".";
        log.debug("File.getSource, not cached. pkgdir={s} sub_file_path={s}", .{
            root_dir_path, file.sub_file_path,
        });

        // Keep track of inode, file size, mtime, hash so we can detect which files
        // have been modified when an incremental update is requested.
        var f = try file.pkg.root_src_directory.handle.openFile(file.sub_file_path, .{});
        defer f.close();

        const stat = try f.stat();

        if (stat.size > std.math.maxInt(u32))
            return error.FileTooBig;

        const source = try gpa.allocSentinel(u8, @intCast(usize, stat.size), 0);
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
        file.tree = try std.zig.parse(gpa, source.bytes);
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

    pub fn fullyQualifiedNameZ(file: File, gpa: Allocator) ![:0]u8 {
        var buf = std.ArrayList(u8).init(gpa);
        defer buf.deinit();
        try file.renderFullyQualifiedName(buf.writer());
        return buf.toOwnedSliceSentinel(0);
    }

    /// Returns the full path to this file relative to its package.
    pub fn fullPath(file: File, ally: Allocator) ![]u8 {
        return file.pkg.root_src_directory.join(ally, &[_][]const u8{file.sub_file_path});
    }

    /// Returns the full path to this file relative to its package.
    pub fn fullPathZ(file: File, ally: Allocator) ![:0]u8 {
        return file.pkg.root_src_directory.joinZ(ally, &[_][]const u8{file.sub_file_path});
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
};

/// Represents the contents of a file loaded with `@embedFile`.
pub const EmbedFile = struct {
    /// Relative to the owning package's root_src_dir.
    /// Memory is stored in gpa, owned by EmbedFile.
    sub_file_path: []const u8,
    bytes: [:0]const u8,
    stat: Cache.File.Stat,
    /// Package that this file is a part of, managed externally.
    pkg: *Package,
    /// The Decl that was created from the `@embedFile` to own this resource.
    /// This is how zig knows what other Decl objects to invalidate if the file
    /// changes on disk.
    owner_decl: Decl.Index,

    fn destroy(embed_file: *EmbedFile, mod: *Module) void {
        const gpa = mod.gpa;
        gpa.free(embed_file.sub_file_path);
        gpa.free(embed_file.bytes);
        gpa.destroy(embed_file);
    }
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

    pub fn create(
        gpa: Allocator,
        src_loc: SrcLoc,
        comptime format: []const u8,
        args: anytype,
    ) !*ErrorMsg {
        const err_msg = try gpa.create(ErrorMsg);
        errdefer gpa.destroy(err_msg);
        err_msg.* = try init(gpa, src_loc, format, args);
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

    pub fn declRelativeToNodeIndex(src_loc: SrcLoc, offset: i32) Ast.TokenIndex {
        return @bitCast(Ast.Node.Index, offset + @bitCast(i32, src_loc.parent_decl_node));
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
                const end = start + @intCast(u32, tree.tokenSlice(tok_index).len);
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
                const end = start + @intCast(u32, tree.tokenSlice(tok_index).len);
                return Span{ .start = start, .end = end, .main = start };
            },
            .token_offset => |tok_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const tok_index = src_loc.declSrcToken() + tok_off;
                const start = tree.tokens.items(.start)[tok_index];
                const end = start + @intCast(u32, tree.tokenSlice(tok_index).len);
                return Span{ .start = start, .end = end, .main = start };
            },
            .node_offset => |traced_off| {
                const node_off = traced_off.x;
                const tree = try src_loc.file_scope.getTree(gpa);
                const node = src_loc.declRelativeToNodeIndex(node_off);
                assert(src_loc.file_scope.tree_loaded);
                return nodeToSpan(tree, node);
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
                    .global_var_decl => tree.globalVarDecl(node),
                    .local_var_decl => tree.localVarDecl(node),
                    .simple_var_decl => tree.simpleVarDecl(node),
                    .aligned_var_decl => tree.alignedVarDecl(node),
                    else => unreachable,
                };
                if (full.ast.type_node != 0) {
                    return nodeToSpan(tree, full.ast.type_node);
                }
                const tok_index = full.ast.mut_token + 1; // the name token
                const start = tree.tokens.items(.start)[tok_index];
                const end = start + @intCast(u32, tree.tokenSlice(tok_index).len);
                return Span{ .start = start, .end = end, .main = start };
            },
            .node_offset_builtin_call_arg0 => |n| return src_loc.byteOffsetBuiltinCallArg(gpa, n, 0),
            .node_offset_builtin_call_arg1 => |n| return src_loc.byteOffsetBuiltinCallArg(gpa, n, 1),
            .node_offset_builtin_call_arg2 => |n| return src_loc.byteOffsetBuiltinCallArg(gpa, n, 2),
            .node_offset_builtin_call_arg3 => |n| return src_loc.byteOffsetBuiltinCallArg(gpa, n, 3),
            .node_offset_builtin_call_arg4 => |n| return src_loc.byteOffsetBuiltinCallArg(gpa, n, 4),
            .node_offset_builtin_call_arg5 => |n| return src_loc.byteOffsetBuiltinCallArg(gpa, n, 5),
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
                const node_tags = tree.nodes.items(.tag);
                const node = src_loc.declRelativeToNodeIndex(node_off);
                const full = switch (node_tags[node]) {
                    .slice_open => tree.sliceOpen(node),
                    .slice => tree.slice(node),
                    .slice_sentinel => tree.sliceSentinel(node),
                    else => unreachable,
                };
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
                const node_tags = tree.nodes.items(.tag);
                const node = src_loc.declRelativeToNodeIndex(node_off);
                var params: [1]Ast.Node.Index = undefined;
                const full = switch (node_tags[node]) {
                    .call_one,
                    .call_one_comma,
                    .async_call_one,
                    .async_call_one_comma,
                    => tree.callOne(&params, node),

                    .call,
                    .call_comma,
                    .async_call,
                    .async_call_comma,
                    => tree.callFull(node),

                    else => unreachable,
                };
                return nodeToSpan(tree, full.ast.fn_expr);
            },
            .node_offset_field_name => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const node_datas = tree.nodes.items(.data);
                const node_tags = tree.nodes.items(.tag);
                const node = src_loc.declRelativeToNodeIndex(node_off);
                const tok_index = switch (node_tags[node]) {
                    .field_access => node_datas[node].rhs,
                    else => tree.firstToken(node) - 2,
                };
                const start = tree.tokens.items(.start)[tok_index];
                const end = start + @intCast(u32, tree.tokenSlice(tok_index).len);
                return Span{ .start = start, .end = end, .main = start };
            },
            .node_offset_deref_ptr => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const node = src_loc.declRelativeToNodeIndex(node_off);
                return nodeToSpan(tree, node);
            },
            .node_offset_asm_source => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const node_tags = tree.nodes.items(.tag);
                const node = src_loc.declRelativeToNodeIndex(node_off);
                const full = switch (node_tags[node]) {
                    .asm_simple => tree.asmSimple(node),
                    .@"asm" => tree.asmFull(node),
                    else => unreachable,
                };
                return nodeToSpan(tree, full.ast.template);
            },
            .node_offset_asm_ret_ty => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const node_tags = tree.nodes.items(.tag);
                const node = src_loc.declRelativeToNodeIndex(node_off);
                const full = switch (node_tags[node]) {
                    .asm_simple => tree.asmSimple(node),
                    .@"asm" => tree.asmFull(node),
                    else => unreachable,
                };
                const asm_output = full.outputs[0];
                const node_datas = tree.nodes.items(.data);
                return nodeToSpan(tree, node_datas[asm_output].lhs);
            },

            .node_offset_for_cond, .node_offset_if_cond => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const node = src_loc.declRelativeToNodeIndex(node_off);
                const node_tags = tree.nodes.items(.tag);
                const src_node = switch (node_tags[node]) {
                    .if_simple => tree.ifSimple(node).ast.cond_expr,
                    .@"if" => tree.ifFull(node).ast.cond_expr,
                    .while_simple => tree.whileSimple(node).ast.cond_expr,
                    .while_cont => tree.whileCont(node).ast.cond_expr,
                    .@"while" => tree.whileFull(node).ast.cond_expr,
                    .for_simple => tree.forSimple(node).ast.cond_expr,
                    .@"for" => tree.forFull(node).ast.cond_expr,
                    else => unreachable,
                };
                return nodeToSpan(tree, src_node);
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
                    const case = switch (node_tags[case_node]) {
                        .switch_case_one => tree.switchCaseOne(case_node),
                        .switch_case => tree.switchCase(case_node),
                        else => unreachable,
                    };
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
                    const case = switch (node_tags[case_node]) {
                        .switch_case_one => tree.switchCaseOne(case_node),
                        .switch_case => tree.switchCase(case_node),
                        else => unreachable,
                    };
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

            .node_offset_fn_type_cc => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const node_datas = tree.nodes.items(.data);
                const node_tags = tree.nodes.items(.tag);
                const node = src_loc.declRelativeToNodeIndex(node_off);
                var params: [1]Ast.Node.Index = undefined;
                const full = switch (node_tags[node]) {
                    .fn_proto_simple => tree.fnProtoSimple(&params, node),
                    .fn_proto_multi => tree.fnProtoMulti(node),
                    .fn_proto_one => tree.fnProtoOne(&params, node),
                    .fn_proto => tree.fnProto(node),
                    .fn_decl => switch (node_tags[node_datas[node].lhs]) {
                        .fn_proto_simple => tree.fnProtoSimple(&params, node_datas[node].lhs),
                        .fn_proto_multi => tree.fnProtoMulti(node_datas[node].lhs),
                        .fn_proto_one => tree.fnProtoOne(&params, node_datas[node].lhs),
                        .fn_proto => tree.fnProto(node_datas[node].lhs),
                        else => unreachable,
                    },
                    else => unreachable,
                };
                return nodeToSpan(tree, full.ast.callconv_expr);
            },

            .node_offset_fn_type_ret_ty => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const node_tags = tree.nodes.items(.tag);
                const node = src_loc.declRelativeToNodeIndex(node_off);
                var params: [1]Ast.Node.Index = undefined;
                const full = switch (node_tags[node]) {
                    .fn_proto_simple => tree.fnProtoSimple(&params, node),
                    .fn_proto_multi => tree.fnProtoMulti(node),
                    .fn_proto_one => tree.fnProtoOne(&params, node),
                    .fn_proto => tree.fnProto(node),
                    else => unreachable,
                };
                return nodeToSpan(tree, full.ast.return_type);
            },

            .node_offset_anyframe_type => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const node_datas = tree.nodes.items(.data);
                const parent_node = src_loc.declRelativeToNodeIndex(node_off);
                return nodeToSpan(tree, node_datas[parent_node].rhs);
            },

            .node_offset_lib_name => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const node_datas = tree.nodes.items(.data);
                const node_tags = tree.nodes.items(.tag);
                const parent_node = src_loc.declRelativeToNodeIndex(node_off);
                var params: [1]Ast.Node.Index = undefined;
                const full = switch (node_tags[parent_node]) {
                    .fn_proto_simple => tree.fnProtoSimple(&params, parent_node),
                    .fn_proto_multi => tree.fnProtoMulti(parent_node),
                    .fn_proto_one => tree.fnProtoOne(&params, parent_node),
                    .fn_proto => tree.fnProto(parent_node),
                    .fn_decl => blk: {
                        const fn_proto = node_datas[parent_node].lhs;
                        break :blk switch (node_tags[fn_proto]) {
                            .fn_proto_simple => tree.fnProtoSimple(&params, fn_proto),
                            .fn_proto_multi => tree.fnProtoMulti(fn_proto),
                            .fn_proto_one => tree.fnProtoOne(&params, fn_proto),
                            .fn_proto => tree.fnProto(fn_proto),
                            else => unreachable,
                        };
                    },
                    else => unreachable,
                };
                const tok_index = full.lib_name.?;
                const start = tree.tokens.items(.start)[tok_index];
                const end = start + @intCast(u32, tree.tokenSlice(tok_index).len);
                return Span{ .start = start, .end = end, .main = start };
            },

            .node_offset_array_type_len => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const node_tags = tree.nodes.items(.tag);
                const parent_node = src_loc.declRelativeToNodeIndex(node_off);

                const full: Ast.full.ArrayType = switch (node_tags[parent_node]) {
                    .array_type => tree.arrayType(parent_node),
                    .array_type_sentinel => tree.arrayTypeSentinel(parent_node),
                    else => unreachable,
                };
                return nodeToSpan(tree, full.ast.elem_count);
            },
            .node_offset_array_type_sentinel => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const node_tags = tree.nodes.items(.tag);
                const parent_node = src_loc.declRelativeToNodeIndex(node_off);

                const full: Ast.full.ArrayType = switch (node_tags[parent_node]) {
                    .array_type => tree.arrayType(parent_node),
                    .array_type_sentinel => tree.arrayTypeSentinel(parent_node),
                    else => unreachable,
                };
                return nodeToSpan(tree, full.ast.sentinel);
            },
            .node_offset_array_type_elem => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const node_tags = tree.nodes.items(.tag);
                const parent_node = src_loc.declRelativeToNodeIndex(node_off);

                const full: Ast.full.ArrayType = switch (node_tags[parent_node]) {
                    .array_type => tree.arrayType(parent_node),
                    .array_type_sentinel => tree.arrayTypeSentinel(parent_node),
                    else => unreachable,
                };
                return nodeToSpan(tree, full.ast.elem_type);
            },
            .node_offset_un_op => |node_off| {
                const tree = try src_loc.file_scope.getTree(gpa);
                const node_datas = tree.nodes.items(.data);
                const node = src_loc.declRelativeToNodeIndex(node_off);

                return nodeToSpan(tree, node_datas[node].lhs);
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
        const end_off = token_starts[end_tok] + @intCast(u32, tree.tokenSlice(end_tok).len);
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
    /// The source location points to the beginning of a struct initializer.
    /// The Decl is determined contextually.
    node_offset_initializer: i32,
    /// The source location points to a variable declaration type expression,
    /// found by taking this AST node index offset from the containing
    /// Decl AST node, which points to a variable declaration AST node. Next, navigate
    /// to the type expression.
    /// The Decl is determined contextually.
    node_offset_var_decl_ty: i32,
    /// The source location points to a for loop condition expression,
    /// found by taking this AST node index offset from the containing
    /// Decl AST node, which points to a for loop AST node. Next, navigate
    /// to the condition expression.
    /// The Decl is determined contextually.
    node_offset_for_cond: i32,
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
    ///  * the operand ("b" node) of a field initialization expression (`.a = b`)
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
    pub fn toSrcLoc(lazy: LazySrcLoc, decl: *Decl) SrcLoc {
        return switch (lazy) {
            .unneeded,
            .entire_file,
            .byte_abs,
            .token_abs,
            .node_abs,
            => .{
                .file_scope = decl.getFileScope(),
                .parent_decl_node = 0,
                .lazy = lazy,
            },

            .byte_offset,
            .token_offset,
            .node_offset,
            .node_offset_initializer,
            .node_offset_var_decl_ty,
            .node_offset_for_cond,
            .node_offset_builtin_call_arg0,
            .node_offset_builtin_call_arg1,
            .node_offset_builtin_call_arg2,
            .node_offset_builtin_call_arg3,
            .node_offset_builtin_call_arg4,
            .node_offset_builtin_call_arg5,
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
            .node_offset_fn_type_cc,
            .node_offset_fn_type_ret_ty,
            .node_offset_anyframe_type,
            .node_offset_lib_name,
            .node_offset_array_type_len,
            .node_offset_array_type_sentinel,
            .node_offset_array_type_elem,
            .node_offset_un_op,
            => .{
                .file_scope = decl.getFileScope(),
                .parent_decl_node = decl.src_node,
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

pub fn deinit(mod: *Module) void {
    const gpa = mod.gpa;

    for (mod.import_table.keys()) |key| {
        gpa.free(key);
    }
    for (mod.import_table.values()) |value| {
        value.destroy(mod);
    }
    mod.import_table.deinit(gpa);

    {
        var it = mod.embed_table.iterator();
        while (it.next()) |entry| {
            gpa.free(entry.key_ptr.*);
            entry.value_ptr.*.destroy(mod);
        }
        mod.embed_table.deinit(gpa);
    }

    mod.deletion_set.deinit(gpa);

    // The callsite of `Compilation.create` owns the `main_pkg`, however
    // Module owns the builtin and std packages that it adds.
    if (mod.main_pkg.table.fetchRemove("builtin")) |kv| {
        gpa.free(kv.key);
        kv.value.destroy(gpa);
    }
    if (mod.main_pkg.table.fetchRemove("std")) |kv| {
        gpa.free(kv.key);
        kv.value.destroy(gpa);
    }
    if (mod.main_pkg.table.fetchRemove("root")) |kv| {
        gpa.free(kv.key);
    }
    if (mod.root_pkg != mod.main_pkg) {
        mod.root_pkg.destroy(gpa);
    }

    mod.compile_log_text.deinit(gpa);

    mod.zig_cache_artifact_directory.handle.close();
    mod.local_zir_cache.handle.close();
    mod.global_zir_cache.handle.close();

    for (mod.failed_decls.values()) |value| {
        value.destroy(gpa);
    }
    mod.failed_decls.deinit(gpa);

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

    mod.compile_log_decls.deinit(gpa);

    for (mod.decl_exports.values()) |export_list| {
        gpa.free(export_list);
    }
    mod.decl_exports.deinit(gpa);

    for (mod.export_owners.values()) |value| {
        freeExportList(gpa, value);
    }
    mod.export_owners.deinit(gpa);

    {
        var it = mod.global_error_set.keyIterator();
        while (it.next()) |key| {
            gpa.free(key.*);
        }
        mod.global_error_set.deinit(gpa);
    }

    mod.error_name_list.deinit(gpa);
    mod.test_functions.deinit(gpa);
    mod.align_stack_fns.deinit(gpa);
    mod.monomorphed_funcs.deinit(gpa);

    {
        var it = mod.memoized_calls.iterator();
        while (it.next()) |entry| {
            gpa.free(entry.key_ptr.args);
            entry.value_ptr.arena.promote(gpa).deinit();
        }
        mod.memoized_calls.deinit(gpa);
    }

    mod.decls_free_list.deinit(gpa);
    mod.allocated_decls.deinit(gpa);
    mod.global_assembly.deinit(gpa);

    mod.string_literal_table.deinit(gpa);
    mod.string_literal_bytes.deinit(gpa);
}

pub fn destroyDecl(mod: *Module, decl_index: Decl.Index) void {
    const gpa = mod.gpa;
    {
        const decl = mod.declPtr(decl_index);
        log.debug("destroy {*} ({s})", .{ decl, decl.name });
        _ = mod.test_functions.swapRemove(decl_index);
        if (decl.deletion_flag) {
            assert(mod.deletion_set.swapRemove(decl_index));
        }
        if (mod.global_assembly.fetchRemove(decl_index)) |kv| {
            gpa.free(kv.value);
        }
        if (decl.has_tv) {
            if (decl.getInnerNamespace()) |namespace| {
                namespace.destroyDecls(mod);
            }
            decl.clearValues(mod);
        }
        decl.dependants.deinit(gpa);
        decl.dependencies.deinit(gpa);
        decl.clearName(gpa);
        decl.* = undefined;
    }
    mod.decls_free_list.append(gpa, decl_index) catch {
        // In order to keep `destroyDecl` a non-fallible function, we ignore memory
        // allocation failures here, instead leaking the Decl until garbage collection.
    };
    if (mod.emit_h) |mod_emit_h| {
        const decl_emit_h = mod_emit_h.declPtr(decl_index);
        decl_emit_h.fwd_decl.deinit(gpa);
        decl_emit_h.* = undefined;
    }
}

pub fn declPtr(mod: *Module, decl_index: Decl.Index) *Decl {
    return mod.allocated_decls.at(@enumToInt(decl_index));
}

/// Returns true if and only if the Decl is the top level struct associated with a File.
pub fn declIsRoot(mod: *Module, decl_index: Decl.Index) bool {
    const decl = mod.declPtr(decl_index);
    if (decl.src_namespace.parent != null)
        return false;
    return decl_index == decl.src_namespace.getDeclIndex();
}

fn freeExportList(gpa: Allocator, export_list: []*Export) void {
    for (export_list) |exp| {
        gpa.free(exp.options.name);
        if (exp.options.section) |s| gpa.free(s);
        gpa.destroy(exp);
    }
    gpa.free(export_list);
}

const data_has_safety_tag = @sizeOf(Zir.Inst.Data) != 8;
// TODO This is taking advantage of matching stage1 debug union layout.
// We need a better language feature for initializing a union with
// a runtime known tag.
const Stage1DataLayout = extern struct {
    data: [8]u8 align(@alignOf(Zir.Inst.Data)),
    safety_tag: u8,
};
comptime {
    if (data_has_safety_tag) {
        assert(@sizeOf(Stage1DataLayout) == @sizeOf(Zir.Inst.Data));
    }
}

pub fn astGenFile(mod: *Module, file: *File) !void {
    const tracy = trace(@src());
    defer tracy.end();

    const comp = mod.comp;
    const gpa = mod.gpa;

    // In any case we need to examine the stat of the file to determine the course of action.
    var source_file = try file.pkg.root_src_directory.handle.openFile(file.sub_file_path, .{});
    defer source_file.close();

    const stat = try source_file.stat();

    const want_local_cache = file.pkg == mod.main_pkg;
    const digest = hash: {
        var path_hash: Cache.HashHelper = .{};
        path_hash.addBytes(build_options.version);
        if (!want_local_cache) {
            path_hash.addOptionalBytes(file.pkg.root_src_directory.path);
        }
        path_hash.addBytes(file.sub_file_path);
        break :hash path_hash.final();
    };
    const cache_directory = if (want_local_cache) mod.local_zir_cache else mod.global_zir_cache;
    const zir_dir = cache_directory.handle;

    var cache_file: ?std.fs.File = null;
    defer if (cache_file) |f| f.close();

    // Determine whether we need to reload the file from disk and redo parsing and AstGen.
    switch (file.status) {
        .never_loaded, .retryable_failure => cached: {
            // First, load the cached ZIR code, if any.
            log.debug("AstGen checking cache: {s} (local={}, digest={s})", .{
                file.sub_file_path, want_local_cache, &digest,
            });

            // We ask for a lock in order to coordinate with other zig processes.
            // If another process is already working on this file, we will get the cached
            // version. Likewise if we're working on AstGen and another process asks for
            // the cached file, they'll get it.
            cache_file = zir_dir.openFile(&digest, .{ .lock = .Shared }) catch |err| switch (err) {
                error.PathAlreadyExists => unreachable, // opening for reading
                error.NoSpaceLeft => unreachable, // opening for reading
                error.NotDir => unreachable, // no dir components
                error.InvalidUtf8 => unreachable, // it's a hex encoded name
                error.BadPathName => unreachable, // it's a hex encoded name
                error.NameTooLong => unreachable, // it's a fixed size name
                error.PipeBusy => unreachable, // it's not a pipe
                error.WouldBlock => unreachable, // not asking for non-blocking I/O

                error.SymLinkLoop,
                error.FileNotFound,
                error.Unexpected,
                => break :cached,

                else => |e| return e, // Retryable errors are handled at callsite.
            };

            // First we read the header to determine the lengths of arrays.
            const header = cache_file.?.reader().readStruct(Zir.Header) catch |err| switch (err) {
                // This can happen if Zig bails out of this function between creating
                // the cached file and writing it.
                error.EndOfStream => break :cached,
                else => |e| return e,
            };
            const unchanged_metadata =
                stat.size == header.stat_size and
                stat.mtime == header.stat_mtime and
                stat.inode == header.stat_inode;

            if (!unchanged_metadata) {
                log.debug("AstGen cache stale: {s}", .{file.sub_file_path});
                break :cached;
            }
            log.debug("AstGen cache hit: {s} instructions_len={d}", .{
                file.sub_file_path, header.instructions_len,
            });

            var instructions: std.MultiArrayList(Zir.Inst) = .{};
            defer instructions.deinit(gpa);

            try instructions.setCapacity(gpa, header.instructions_len);
            instructions.len = header.instructions_len;

            var zir: Zir = .{
                .instructions = instructions.toOwnedSlice(),
                .string_bytes = &.{},
                .extra = &.{},
            };
            var keep_zir = false;
            defer if (!keep_zir) zir.deinit(gpa);

            zir.string_bytes = try gpa.alloc(u8, header.string_bytes_len);
            zir.extra = try gpa.alloc(u32, header.extra_len);

            const safety_buffer = if (data_has_safety_tag)
                try gpa.alloc([8]u8, header.instructions_len)
            else
                undefined;
            defer if (data_has_safety_tag) gpa.free(safety_buffer);

            const data_ptr = if (data_has_safety_tag)
                @ptrCast([*]u8, safety_buffer.ptr)
            else
                @ptrCast([*]u8, zir.instructions.items(.data).ptr);

            var iovecs = [_]std.os.iovec{
                .{
                    .iov_base = @ptrCast([*]u8, zir.instructions.items(.tag).ptr),
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
                    .iov_base = @ptrCast([*]u8, zir.extra.ptr),
                    .iov_len = header.extra_len * 4,
                },
            };
            const amt_read = try cache_file.?.readvAll(&iovecs);
            const amt_expected = zir.instructions.len * 9 +
                zir.string_bytes.len +
                zir.extra.len * 4;
            if (amt_read != amt_expected) {
                log.warn("unexpected EOF reading cached ZIR for {s}", .{file.sub_file_path});
                break :cached;
            }
            if (data_has_safety_tag) {
                const tags = zir.instructions.items(.tag);
                for (zir.instructions.items(.data)) |*data, i| {
                    const union_tag = Zir.Inst.Tag.data_tags[@enumToInt(tags[i])];
                    const as_struct = @ptrCast(*Stage1DataLayout, data);
                    as_struct.* = .{
                        .safety_tag = @enumToInt(union_tag),
                        .data = safety_buffer[i],
                    };
                }
            }

            keep_zir = true;
            file.zir = zir;
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
        },
        .parse_failure, .astgen_failure, .success_zir => {
            const unchanged_metadata =
                stat.size == file.stat.size and
                stat.mtime == file.stat.mtime and
                stat.inode == file.stat.inode;

            if (unchanged_metadata) {
                log.debug("unmodified metadata of file: {s}", .{file.sub_file_path});
                return;
            }

            log.debug("metadata changed: {s}", .{file.sub_file_path});
        },
    }
    if (cache_file) |f| {
        f.close();
        cache_file = null;
    }
    cache_file = zir_dir.createFile(&digest, .{ .lock = .Exclusive }) catch |err| switch (err) {
        error.NotDir => unreachable, // no dir components
        error.InvalidUtf8 => unreachable, // it's a hex encoded name
        error.BadPathName => unreachable, // it's a hex encoded name
        error.NameTooLong => unreachable, // it's a fixed size name
        error.PipeBusy => unreachable, // it's not a pipe
        error.WouldBlock => unreachable, // not asking for non-blocking I/O
        error.FileNotFound => unreachable, // no dir components

        else => |e| {
            const pkg_path = file.pkg.root_src_directory.path orelse ".";
            const cache_path = cache_directory.path orelse ".";
            log.warn("unable to save cached ZIR code for {s}/{s} to {s}/{s}: {s}", .{
                pkg_path, file.sub_file_path, cache_path, &digest, @errorName(e),
            });
            return;
        },
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

    const source = try gpa.allocSentinel(u8, @intCast(usize, stat.size), 0);
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

    file.tree = try std.zig.parse(gpa, source);
    defer if (!file.tree_loaded) file.tree.deinit(gpa);

    if (file.tree.errors.len != 0) {
        const parse_err = file.tree.errors[0];

        var msg = std.ArrayList(u8).init(gpa);
        defer msg.deinit();

        const token_starts = file.tree.tokens.items(.start);
        const token_tags = file.tree.tokens.items(.tag);

        const extra_offset = file.tree.errorOffset(parse_err);
        try file.tree.renderError(parse_err, msg.writer());
        const err_msg = try gpa.create(ErrorMsg);
        err_msg.* = .{
            .src_loc = .{
                .file_scope = file,
                .parent_decl_node = 0,
                .lazy = if (extra_offset == 0) .{
                    .token_abs = parse_err.token,
                } else .{
                    .byte_abs = token_starts[parse_err.token] + extra_offset,
                },
            },
            .msg = msg.toOwnedSlice(),
        };
        if (token_tags[parse_err.token + @boolToInt(parse_err.token_is_prev)] == .invalid) {
            const bad_off = @intCast(u32, file.tree.tokenSlice(parse_err.token + @boolToInt(parse_err.token_is_prev)).len);
            const byte_abs = token_starts[parse_err.token + @boolToInt(parse_err.token_is_prev)] + bad_off;
            try mod.errNoteNonLazy(.{
                .file_scope = file,
                .parent_decl_node = 0,
                .lazy = .{ .byte_abs = byte_abs },
            }, err_msg, "invalid byte: '{'}'", .{std.zig.fmtEscapes(source[byte_abs..][0..1])});
        }

        for (file.tree.errors[1..]) |note| {
            if (!note.is_note) break;

            try file.tree.renderError(note, msg.writer());
            err_msg.notes = try mod.gpa.realloc(err_msg.notes, err_msg.notes.len + 1);
            err_msg.notes[err_msg.notes.len - 1] = .{
                .src_loc = .{
                    .file_scope = file,
                    .parent_decl_node = 0,
                    .lazy = .{ .token_abs = note.token },
                },
                .msg = msg.toOwnedSlice(),
            };
        }

        {
            comp.mutex.lock();
            defer comp.mutex.unlock();
            try mod.failed_files.putNoClobber(gpa, file, err_msg);
        }
        file.status = .parse_failure;
        return error.AnalysisFail;
    }
    file.tree_loaded = true;

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
            @ptrCast([*]const u8, safety_buffer.ptr)
    else
        @ptrCast([*]const u8, file.zir.instructions.items(.data).ptr);
    if (data_has_safety_tag) {
        // The `Data` union has a safety tag but in the file format we store it without.
        for (file.zir.instructions.items(.data)) |*data, i| {
            const as_struct = @ptrCast(*const Stage1DataLayout, data);
            safety_buffer[i] = as_struct.data;
        }
    }

    const header: Zir.Header = .{
        .instructions_len = @intCast(u32, file.zir.instructions.len),
        .string_bytes_len = @intCast(u32, file.zir.string_bytes.len),
        .extra_len = @intCast(u32, file.zir.extra.len),

        .stat_size = stat.size,
        .stat_inode = stat.inode,
        .stat_mtime = stat.mtime,
    };
    var iovecs = [_]std.os.iovec_const{
        .{
            .iov_base = @ptrCast([*]const u8, &header),
            .iov_len = @sizeOf(Zir.Header),
        },
        .{
            .iov_base = @ptrCast([*]const u8, file.zir.instructions.items(.tag).ptr),
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
            .iov_base = @ptrCast([*]const u8, file.zir.extra.ptr),
            .iov_len = file.zir.extra.len * 4,
        },
    };
    cache_file.?.writevAll(&iovecs) catch |err| {
        const pkg_path = file.pkg.root_src_directory.path orelse ".";
        const cache_path = cache_directory.path orelse ".";
        log.warn("unable to write cached ZIR code for {s}/{s} to {s}/{s}: {s}", .{
            pkg_path, file.sub_file_path, cache_path, &digest, @errorName(err),
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

/// Patch ups:
/// * Struct.zir_index
/// * Decl.zir_index
/// * Fn.zir_body_inst
/// * Decl.zir_decl_index
fn updateZirRefs(mod: *Module, file: *File, old_zir: Zir) !void {
    const gpa = mod.gpa;
    const new_zir = file.zir;

    // Maps from old ZIR to new ZIR, struct_decl, enum_decl, etc. Any instruction which
    // creates a namespace, gets mapped from old to new here.
    var inst_map: std.AutoHashMapUnmanaged(Zir.Inst.Index, Zir.Inst.Index) = .{};
    defer inst_map.deinit(gpa);
    // Maps from old ZIR to new ZIR, the extra data index for the sub-decl item.
    // e.g. the thing that Decl.zir_decl_index points to.
    var extra_map: std.AutoHashMapUnmanaged(u32, u32) = .{};
    defer extra_map.deinit(gpa);

    try mapOldZirToNew(gpa, old_zir, new_zir, &inst_map, &extra_map);

    // Walk the Decl graph, updating ZIR indexes, strings, and populating
    // the deleted and outdated lists.

    var decl_stack: std.ArrayListUnmanaged(Decl.Index) = .{};
    defer decl_stack.deinit(gpa);

    const root_decl = file.root_decl.unwrap().?;
    try decl_stack.append(gpa, root_decl);

    file.deleted_decls.clearRetainingCapacity();
    file.outdated_decls.clearRetainingCapacity();

    // The root decl is always outdated; otherwise we would not have had
    // to re-generate ZIR for the File.
    try file.outdated_decls.append(gpa, root_decl);

    while (decl_stack.popOrNull()) |decl_index| {
        const decl = mod.declPtr(decl_index);
        // Anonymous decls and the root decl have this set to 0. We still need
        // to walk them but we do not need to modify this value.
        // Anonymous decls should not be marked outdated. They will be re-generated
        // if their owner decl is marked outdated.
        if (decl.zir_decl_index != 0) {
            const old_zir_decl_index = decl.zir_decl_index;
            const new_zir_decl_index = extra_map.get(old_zir_decl_index) orelse {
                log.debug("updateZirRefs {s}: delete {*} ({s})", .{
                    file.sub_file_path, decl, decl.name,
                });
                try file.deleted_decls.append(gpa, decl_index);
                continue;
            };
            const old_hash = decl.contentsHashZir(old_zir);
            decl.zir_decl_index = new_zir_decl_index;
            const new_hash = decl.contentsHashZir(new_zir);
            if (!std.zig.srcHashEql(old_hash, new_hash)) {
                log.debug("updateZirRefs {s}: outdated {*} ({s}) {d} => {d}", .{
                    file.sub_file_path, decl, decl.name, old_zir_decl_index, new_zir_decl_index,
                });
                try file.outdated_decls.append(gpa, decl_index);
            } else {
                log.debug("updateZirRefs {s}: unchanged {*} ({s}) {d} => {d}", .{
                    file.sub_file_path, decl, decl.name, old_zir_decl_index, new_zir_decl_index,
                });
            }
        }

        if (!decl.owns_tv) continue;

        if (decl.getStruct()) |struct_obj| {
            struct_obj.zir_index = inst_map.get(struct_obj.zir_index) orelse {
                try file.deleted_decls.append(gpa, decl_index);
                continue;
            };
        }

        if (decl.getUnion()) |union_obj| {
            union_obj.zir_index = inst_map.get(union_obj.zir_index) orelse {
                try file.deleted_decls.append(gpa, decl_index);
                continue;
            };
        }

        if (decl.getFunction()) |func| {
            func.zir_body_inst = inst_map.get(func.zir_body_inst) orelse {
                try file.deleted_decls.append(gpa, decl_index);
                continue;
            };
        }

        if (decl.getInnerNamespace()) |namespace| {
            for (namespace.decls.keys()) |sub_decl| {
                try decl_stack.append(gpa, sub_decl);
            }
            for (namespace.anon_decls.keys()) |sub_decl| {
                try decl_stack.append(gpa, sub_decl);
            }
        }
    }
}

pub fn populateBuiltinFile(mod: *Module) !void {
    const tracy = trace(@src());
    defer tracy.end();

    const comp = mod.comp;
    const pkg_and_file = blk: {
        comp.mutex.lock();
        defer comp.mutex.unlock();

        const builtin_pkg = mod.main_pkg.table.get("builtin").?;
        const result = try mod.importPkg(builtin_pkg);
        break :blk .{
            .file = result.file,
            .pkg = builtin_pkg,
        };
    };
    const file = pkg_and_file.file;
    const builtin_pkg = pkg_and_file.pkg;
    const gpa = mod.gpa;
    file.source = try comp.generateBuiltinZigSource(gpa);
    file.source_loaded = true;

    if (builtin_pkg.root_src_directory.handle.statFile(builtin_pkg.root_src_path)) |stat| {
        if (stat.size != file.source.len) {
            const full_path = try builtin_pkg.root_src_directory.join(gpa, &.{
                builtin_pkg.root_src_path,
            });
            defer gpa.free(full_path);

            log.warn(
                "the cached file '{s}' had the wrong size. Expected {d}, found {d}. " ++
                    "Overwriting with correct file contents now",
                .{ full_path, file.source.len, stat.size },
            );

            try writeBuiltinFile(file, builtin_pkg);
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

        error.FileNotFound => try writeBuiltinFile(file, builtin_pkg),

        else => |e| return e,
    }

    file.tree = try std.zig.parse(gpa, file.source);
    file.tree_loaded = true;
    assert(file.tree.errors.len == 0); // builtin.zig must parse

    file.zir = try AstGen.generate(gpa, file.tree);
    file.zir_loaded = true;
    file.status = .success_zir;
}

pub fn writeBuiltinFile(file: *File, builtin_pkg: *Package) !void {
    var af = try builtin_pkg.root_src_directory.handle.atomicFile(builtin_pkg.root_src_path, .{});
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
    extra_map: *std.AutoHashMapUnmanaged(u32, u32),
) Allocator.Error!void {
    // Contain ZIR indexes of declaration instructions.
    const MatchedZirDecl = struct {
        old_inst: Zir.Inst.Index,
        new_inst: Zir.Inst.Index,
    };
    var match_stack: std.ArrayListUnmanaged(MatchedZirDecl) = .{};
    defer match_stack.deinit(gpa);

    // Main struct inst is always the same
    try match_stack.append(gpa, .{
        .old_inst = Zir.main_struct_inst,
        .new_inst = Zir.main_struct_inst,
    });

    var old_decls = std.ArrayList(Zir.Inst.Index).init(gpa);
    defer old_decls.deinit();
    var new_decls = std.ArrayList(Zir.Inst.Index).init(gpa);
    defer new_decls.deinit();

    while (match_stack.popOrNull()) |match_item| {
        try inst_map.put(gpa, match_item.old_inst, match_item.new_inst);

        // Maps name to extra index of decl sub item.
        var decl_map: std.StringHashMapUnmanaged(u32) = .{};
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
        .codegen_failure,
        .dependency_failure,
        .codegen_failure_retryable,
        => return error.AnalysisFail,

        .complete => return,

        .outdated => blk: {
            log.debug("re-analyzing {*} ({s})", .{ decl, decl.name });

            // The exports this Decl performs will be re-discovered, so we remove them here
            // prior to re-analysis.
            mod.deleteDeclExports(decl_index);
            // Dependencies will be re-discovered, so we remove them here prior to re-analysis.
            for (decl.dependencies.keys()) |dep_index| {
                const dep = mod.declPtr(dep_index);
                dep.removeDependant(decl_index);
                if (dep.dependants.count() == 0 and !dep.deletion_flag) {
                    log.debug("insert {*} ({s}) dependant {*} ({s}) into deletion set", .{
                        decl, decl.name, dep, dep.name,
                    });
                    try mod.markDeclForDeletion(dep_index);
                }
            }
            decl.dependencies.clearRetainingCapacity();

            break :blk true;
        },

        .unreferenced => false,
    };

    var decl_prog_node = mod.sema_prog_node.start(mem.sliceTo(decl.name, 0), 0);
    decl_prog_node.activate();
    defer decl_prog_node.end();

    const type_changed = mod.semaDecl(decl_index) catch |err| switch (err) {
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
                decl.srcLoc(),
                "unable to analyze: {s}",
                .{@errorName(e)},
            ));
            return error.AnalysisFail;
        },
    };

    if (subsequent_analysis) {
        // We may need to chase the dependants and re-analyze them.
        // However, if the decl is a function, and the type is the same, we do not need to.
        if (type_changed or decl.ty.zigTypeTag() != .Fn) {
            for (decl.dependants.keys()) |dep_index| {
                const dep = mod.declPtr(dep_index);
                switch (dep.analysis) {
                    .unreferenced => unreachable,
                    .in_progress => continue, // already doing analysis, ok
                    .outdated => continue, // already queued for update

                    .file_failure,
                    .dependency_failure,
                    .sema_failure,
                    .sema_failure_retryable,
                    .codegen_failure,
                    .codegen_failure_retryable,
                    .complete,
                    => if (dep.generation != mod.generation) {
                        try mod.markOutdatedDecl(dep_index);
                    },
                }
            }
        }
    }
}

pub fn ensureFuncBodyAnalyzed(mod: *Module, func: *Fn) SemaError!void {
    const tracy = trace(@src());
    defer tracy.end();

    const decl_index = func.owner_decl;
    const decl = mod.declPtr(decl_index);

    switch (decl.analysis) {
        .unreferenced => unreachable,
        .in_progress => unreachable,
        .outdated => unreachable,

        .file_failure,
        .sema_failure,
        .codegen_failure,
        .dependency_failure,
        .sema_failure_retryable,
        => return error.AnalysisFail,

        .complete, .codegen_failure_retryable => {
            switch (func.state) {
                .sema_failure, .dependency_failure => return error.AnalysisFail,
                .queued => {},
                .in_progress => unreachable,
                .inline_only => unreachable, // don't queue work for this
                .success => return,
            }

            const gpa = mod.gpa;

            var tmp_arena = std.heap.ArenaAllocator.init(gpa);
            defer tmp_arena.deinit();
            const sema_arena = tmp_arena.allocator();

            var air = mod.analyzeFnBody(func, sema_arena) catch |err| switch (err) {
                error.AnalysisFail => {
                    if (func.state == .in_progress) {
                        // If this decl caused the compile error, the analysis field would
                        // be changed to indicate it was this Decl's fault. Because this
                        // did not happen, we infer here that it was a dependency failure.
                        func.state = .dependency_failure;
                    }
                    return error.AnalysisFail;
                },
                error.OutOfMemory => return error.OutOfMemory,
            };
            defer air.deinit(gpa);

            if (mod.comp.bin_file.options.emit == null) return;

            log.debug("analyze liveness of {s}", .{decl.name});
            var liveness = try Liveness.analyze(gpa, air);
            defer liveness.deinit(gpa);

            if (builtin.mode == .Debug and mod.comp.verbose_air) {
                const fqn = try decl.getFullyQualifiedName(mod);
                defer mod.gpa.free(fqn);

                std.debug.print("# Begin Function AIR: {s}:\n", .{fqn});
                @import("print_air.zig").dump(mod, air, liveness);
                std.debug.print("# End Function AIR: {s}\n\n", .{fqn});
            }

            mod.comp.bin_file.updateFunc(mod, func, air, liveness) catch |err| switch (err) {
                error.OutOfMemory => return error.OutOfMemory,
                error.AnalysisFail => {
                    decl.analysis = .codegen_failure;
                    return;
                },
                else => {
                    try mod.failed_decls.ensureUnusedCapacity(gpa, 1);
                    mod.failed_decls.putAssumeCapacityNoClobber(decl_index, try Module.ErrorMsg.create(
                        gpa,
                        decl.srcLoc(),
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

pub fn updateEmbedFile(mod: *Module, embed_file: *EmbedFile) SemaError!void {
    const tracy = trace(@src());
    defer tracy.end();

    // TODO we can potentially relax this if we store some more information along
    // with decl dependency edges
    const owner_decl = mod.declPtr(embed_file.owner_decl);
    for (owner_decl.dependants.keys()) |dep_index| {
        const dep = mod.declPtr(dep_index);
        switch (dep.analysis) {
            .unreferenced => unreachable,
            .in_progress => continue, // already doing analysis, ok
            .outdated => continue, // already queued for update

            .file_failure,
            .dependency_failure,
            .sema_failure,
            .sema_failure_retryable,
            .codegen_failure,
            .codegen_failure_retryable,
            .complete,
            => if (dep.generation != mod.generation) {
                try mod.markOutdatedDecl(dep_index);
            },
        }
    }
}

pub fn semaPkg(mod: *Module, pkg: *Package) !void {
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
    var new_decl_arena = std.heap.ArenaAllocator.init(gpa);
    errdefer new_decl_arena.deinit();
    const new_decl_arena_allocator = new_decl_arena.allocator();

    const struct_obj = try new_decl_arena_allocator.create(Module.Struct);
    const struct_ty = try Type.Tag.@"struct".create(new_decl_arena_allocator, struct_obj);
    const struct_val = try Value.Tag.ty.create(new_decl_arena_allocator, struct_ty);
    const ty_ty = comptime Type.initTag(.type);
    struct_obj.* = .{
        .owner_decl = undefined, // set below
        .fields = .{},
        .node_offset = 0, // it's the struct for the root file
        .zir_index = undefined, // set below
        .layout = .Auto,
        .status = .none,
        .known_non_opv = undefined,
        .namespace = .{
            .parent = null,
            .ty = struct_ty,
            .file_scope = file,
        },
    };
    const new_decl_index = try mod.allocateNewDecl(&struct_obj.namespace, 0, null);
    const new_decl = mod.declPtr(new_decl_index);
    file.root_decl = new_decl_index.toOptional();
    struct_obj.owner_decl = new_decl_index;
    new_decl.name = try file.fullyQualifiedNameZ(gpa);
    new_decl.src_line = 0;
    new_decl.is_pub = true;
    new_decl.is_exported = false;
    new_decl.has_align = false;
    new_decl.has_linksection_or_addrspace = false;
    new_decl.ty = ty_ty;
    new_decl.val = struct_val;
    new_decl.has_tv = true;
    new_decl.owns_tv = true;
    new_decl.alive = true; // This Decl corresponds to a File and is therefore always alive.
    new_decl.analysis = .in_progress;
    new_decl.generation = mod.generation;

    if (file.status == .success_zir) {
        assert(file.zir_loaded);
        const main_struct_inst = Zir.main_struct_inst;
        struct_obj.zir_index = main_struct_inst;

        var sema_arena = std.heap.ArenaAllocator.init(gpa);
        defer sema_arena.deinit();
        const sema_arena_allocator = sema_arena.allocator();

        var sema: Sema = .{
            .mod = mod,
            .gpa = gpa,
            .arena = sema_arena_allocator,
            .perm_arena = new_decl_arena_allocator,
            .code = file.zir,
            .owner_decl = new_decl,
            .owner_decl_index = new_decl_index,
            .func = null,
            .fn_ret_ty = Type.void,
            .owner_func = null,
        };
        defer sema.deinit();

        var wip_captures = try WipCaptureScope.init(gpa, new_decl_arena_allocator, null);
        defer wip_captures.deinit();

        var block_scope: Sema.Block = .{
            .parent = null,
            .sema = &sema,
            .src_decl = new_decl_index,
            .namespace = &struct_obj.namespace,
            .wip_capture_scope = wip_captures.scope,
            .instructions = .{},
            .inlining = null,
            .is_comptime = true,
        };
        defer block_scope.instructions.deinit(gpa);

        if (sema.analyzeStructDecl(new_decl, main_struct_inst, struct_obj)) |_| {
            try wip_captures.finalize();
            new_decl.analysis = .complete;
        } else |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            error.AnalysisFail => {},
        }

        if (mod.comp.whole_cache_manifest) |man| {
            const source = file.getSource(gpa) catch |err| {
                try reportRetryableFileError(mod, file, "unable to load source: {s}", .{@errorName(err)});
                return error.AnalysisFail;
            };
            const resolved_path = try file.pkg.root_src_directory.join(gpa, &.{
                file.sub_file_path,
            });
            errdefer gpa.free(resolved_path);

            try man.addFilePostContents(resolved_path, source.bytes, source.stat);
        }
    } else {
        new_decl.analysis = .file_failure;
    }

    try new_decl.finalizeNewArena(&new_decl_arena);
}

/// Returns `true` if the Decl type changed.
/// Returns `true` if this is the first time analyzing the Decl.
/// Returns `false` otherwise.
fn semaDecl(mod: *Module, decl_index: Decl.Index) !bool {
    const tracy = trace(@src());
    defer tracy.end();

    const decl = mod.declPtr(decl_index);

    if (decl.getFileScope().status != .success_zir) {
        return error.AnalysisFail;
    }

    const gpa = mod.gpa;
    const zir = decl.getFileScope().zir;
    const zir_datas = zir.instructions.items(.data);

    decl.analysis = .in_progress;

    // We need the memory for the Type to go into the arena for the Decl
    var decl_arena = std.heap.ArenaAllocator.init(gpa);
    errdefer decl_arena.deinit();
    const decl_arena_allocator = decl_arena.allocator();

    var analysis_arena = std.heap.ArenaAllocator.init(gpa);
    defer analysis_arena.deinit();
    const analysis_arena_allocator = analysis_arena.allocator();

    var sema: Sema = .{
        .mod = mod,
        .gpa = gpa,
        .arena = analysis_arena_allocator,
        .perm_arena = decl_arena_allocator,
        .code = zir,
        .owner_decl = decl,
        .owner_decl_index = decl_index,
        .func = null,
        .fn_ret_ty = Type.void,
        .owner_func = null,
    };
    defer sema.deinit();

    if (mod.declIsRoot(decl_index)) {
        log.debug("semaDecl root {*} ({s})", .{ decl, decl.name });
        const main_struct_inst = Zir.main_struct_inst;
        const struct_obj = decl.getStruct().?;
        // This might not have gotten set in `semaFile` if the first time had
        // a ZIR failure, so we set it here in case.
        struct_obj.zir_index = main_struct_inst;
        try sema.analyzeStructDecl(decl, main_struct_inst, struct_obj);
        decl.analysis = .complete;
        decl.generation = mod.generation;
        return false;
    }
    log.debug("semaDecl {*} ({s})", .{ decl, decl.name });

    var wip_captures = try WipCaptureScope.init(gpa, decl_arena_allocator, decl.src_scope);
    defer wip_captures.deinit();

    var block_scope: Sema.Block = .{
        .parent = null,
        .sema = &sema,
        .src_decl = decl_index,
        .namespace = decl.src_namespace,
        .wip_capture_scope = wip_captures.scope,
        .instructions = .{},
        .inlining = null,
        .is_comptime = true,
    };
    defer {
        block_scope.instructions.deinit(gpa);
        block_scope.params.deinit(gpa);
    }

    const zir_block_index = decl.zirBlockIndex();
    const inst_data = zir_datas[zir_block_index].pl_node;
    const extra = zir.extraData(Zir.Inst.Block, inst_data.payload_index);
    const body = zir.extra[extra.end..][0..extra.data.body_len];
    const result_ref = (try sema.analyzeBodyBreak(&block_scope, body)).?.operand;
    try wip_captures.finalize();
    const src = LazySrcLoc.nodeOffset(0);
    const decl_tv = try sema.resolveInstValue(&block_scope, src, result_ref);
    const decl_align: u32 = blk: {
        const align_ref = decl.zirAlignRef();
        if (align_ref == .none) break :blk 0;
        break :blk try sema.resolveAlign(&block_scope, src, align_ref);
    };
    const decl_linksection: ?[*:0]const u8 = blk: {
        const linksection_ref = decl.zirLinksectionRef();
        if (linksection_ref == .none) break :blk null;
        const bytes = try sema.resolveConstString(&block_scope, src, linksection_ref);
        break :blk (try decl_arena_allocator.dupeZ(u8, bytes)).ptr;
    };
    const target = sema.mod.getTarget();
    const address_space = blk: {
        const addrspace_ctx: Sema.AddressSpaceContext = switch (decl_tv.val.tag()) {
            .function, .extern_fn => .function,
            .variable => .variable,
            else => .constant,
        };

        break :blk switch (decl.zirAddrspaceRef()) {
            .none => switch (addrspace_ctx) {
                .function => target_util.defaultAddressSpace(target, .function),
                .variable => target_util.defaultAddressSpace(target, .global_mutable),
                .constant => target_util.defaultAddressSpace(target, .global_constant),
                else => unreachable,
            },
            else => |addrspace_ref| try sema.analyzeAddrspace(&block_scope, src, addrspace_ref, addrspace_ctx),
        };
    };

    // Note this resolves the type of the Decl, not the value; if this Decl
    // is a struct, for example, this resolves `type` (which needs no resolution),
    // not the struct itself.
    try sema.resolveTypeLayout(&block_scope, src, decl_tv.ty);

    const decl_arena_state = try decl_arena_allocator.create(std.heap.ArenaAllocator.State);

    if (decl.is_usingnamespace) {
        if (!decl_tv.ty.eql(Type.type, mod)) {
            return sema.fail(&block_scope, src, "expected type, found {}", .{
                decl_tv.ty.fmt(mod),
            });
        }
        var buffer: Value.ToTypeBuffer = undefined;
        const ty = try decl_tv.val.toType(&buffer).copy(decl_arena_allocator);
        if (ty.getNamespace() == null) {
            return sema.fail(&block_scope, src, "type {} has no namespace", .{ty.fmt(mod)});
        }

        decl.ty = Type.type;
        decl.val = try Value.Tag.ty.create(decl_arena_allocator, ty);
        decl.@"align" = 0;
        decl.@"linksection" = null;
        decl.has_tv = true;
        decl.owns_tv = false;
        decl_arena_state.* = decl_arena.state;
        decl.value_arena = decl_arena_state;
        decl.analysis = .complete;
        decl.generation = mod.generation;

        return true;
    }

    if (decl_tv.val.castTag(.function)) |fn_payload| {
        const func = fn_payload.data;
        const owns_tv = func.owner_decl == decl_index;
        if (owns_tv) {
            var prev_type_has_bits = false;
            var prev_is_inline = false;
            var type_changed = true;

            if (decl.has_tv) {
                prev_type_has_bits = decl.ty.isFnOrHasRuntimeBits();
                type_changed = !decl.ty.eql(decl_tv.ty, mod);
                if (decl.getFunction()) |prev_func| {
                    prev_is_inline = prev_func.state == .inline_only;
                }
                decl.clearValues(mod);
            }

            decl.ty = try decl_tv.ty.copy(decl_arena_allocator);
            decl.val = try decl_tv.val.copy(decl_arena_allocator);
            decl.@"align" = decl_align;
            decl.@"linksection" = decl_linksection;
            decl.@"addrspace" = address_space;
            decl.has_tv = true;
            decl.owns_tv = owns_tv;
            decl_arena_state.* = decl_arena.state;
            decl.value_arena = decl_arena_state;
            decl.analysis = .complete;
            decl.generation = mod.generation;

            const has_runtime_bits = try sema.fnHasRuntimeBits(&block_scope, src, decl.ty);

            if (has_runtime_bits) {
                // We don't fully codegen the decl until later, but we do need to reserve a global
                // offset table index for it. This allows us to codegen decls out of dependency
                // order, increasing how many computations can be done in parallel.
                try mod.comp.bin_file.allocateDeclIndexes(decl_index);
                try mod.comp.work_queue.writeItem(.{ .codegen_func = func });
                if (type_changed and mod.emit_h != null) {
                    try mod.comp.work_queue.writeItem(.{ .emit_h_decl = decl_index });
                }
            } else if (!prev_is_inline and prev_type_has_bits) {
                mod.comp.bin_file.freeDecl(decl_index);
            }

            const is_inline = decl.ty.fnCallingConvention() == .Inline;
            if (decl.is_exported) {
                const export_src = src; // TODO make this point at `export` token
                if (is_inline) {
                    return sema.fail(&block_scope, export_src, "export of inline function", .{});
                }
                // The scope needs to have the decl in it.
                const options: std.builtin.ExportOptions = .{ .name = mem.sliceTo(decl.name, 0) };
                try sema.analyzeExport(&block_scope, export_src, options, decl_index);
            }
            return type_changed or is_inline != prev_is_inline;
        }
    }
    var type_changed = true;
    if (decl.has_tv) {
        type_changed = !decl.ty.eql(decl_tv.ty, mod);
        decl.clearValues(mod);
    }

    decl.owns_tv = false;
    var queue_linker_work = false;
    var is_extern = false;
    switch (decl_tv.val.tag()) {
        .variable => {
            const variable = decl_tv.val.castTag(.variable).?.data;
            if (variable.owner_decl == decl_index) {
                decl.owns_tv = true;
                queue_linker_work = true;

                const copied_init = try variable.init.copy(decl_arena_allocator);
                variable.init = copied_init;
            }
        },
        .extern_fn => {
            const extern_fn = decl_tv.val.castTag(.extern_fn).?.data;
            if (extern_fn.owner_decl == decl_index) {
                decl.owns_tv = true;
                queue_linker_work = true;
                is_extern = true;
            }
        },

        .generic_poison => unreachable,
        .unreachable_value => unreachable,

        .function => {},

        else => {
            log.debug("send global const to linker: {*} ({s})", .{ decl, decl.name });
            queue_linker_work = true;
        },
    }

    decl.ty = try decl_tv.ty.copy(decl_arena_allocator);
    decl.val = try decl_tv.val.copy(decl_arena_allocator);
    decl.@"align" = decl_align;
    decl.@"linksection" = decl_linksection;
    decl.@"addrspace" = address_space;
    decl.has_tv = true;
    decl_arena_state.* = decl_arena.state;
    decl.value_arena = decl_arena_state;
    decl.analysis = .complete;
    decl.generation = mod.generation;

    const has_runtime_bits = is_extern or
        (queue_linker_work and try sema.typeHasRuntimeBits(&block_scope, src, decl.ty));

    if (has_runtime_bits) {
        log.debug("queue linker work for {*} ({s})", .{ decl, decl.name });

        // Needed for codegen_decl which will call updateDecl and then the
        // codegen backend wants full access to the Decl Type.
        try sema.resolveTypeFully(&block_scope, src, decl.ty);

        try mod.comp.bin_file.allocateDeclIndexes(decl_index);
        try mod.comp.work_queue.writeItem(.{ .codegen_decl = decl_index });

        if (type_changed and mod.emit_h != null) {
            try mod.comp.work_queue.writeItem(.{ .emit_h_decl = decl_index });
        }
    }

    if (decl.is_exported) {
        const export_src = src; // TODO point to the export token
        // The scope needs to have the decl in it.
        const options: std.builtin.ExportOptions = .{ .name = mem.sliceTo(decl.name, 0) };
        try sema.analyzeExport(&block_scope, export_src, options, decl_index);
    }

    return type_changed;
}

/// Returns the depender's index of the dependee.
pub fn declareDeclDependency(mod: *Module, depender_index: Decl.Index, dependee_index: Decl.Index) !void {
    if (depender_index == dependee_index) return;

    const depender = mod.declPtr(depender_index);
    const dependee = mod.declPtr(dependee_index);

    log.debug("{*} ({s}) depends on {*} ({s})", .{
        depender, depender.name, dependee, dependee.name,
    });

    try depender.dependencies.ensureUnusedCapacity(mod.gpa, 1);
    try dependee.dependants.ensureUnusedCapacity(mod.gpa, 1);

    if (dependee.deletion_flag) {
        dependee.deletion_flag = false;
        assert(mod.deletion_set.swapRemove(dependee_index));
    }

    dependee.dependants.putAssumeCapacity(depender_index, {});
    depender.dependencies.putAssumeCapacity(dependee_index, {});
}

pub const ImportFileResult = struct {
    file: *File,
    is_new: bool,
};

pub fn importPkg(mod: *Module, pkg: *Package) !ImportFileResult {
    const gpa = mod.gpa;

    // The resolved path is used as the key in the import table, to detect if
    // an import refers to the same as another, despite different relative paths
    // or differently mapped package names.
    const resolved_path = try std.fs.path.resolve(gpa, &[_][]const u8{
        pkg.root_src_directory.path orelse ".", pkg.root_src_path,
    });
    var keep_resolved_path = false;
    defer if (!keep_resolved_path) gpa.free(resolved_path);

    const gop = try mod.import_table.getOrPut(gpa, resolved_path);
    errdefer _ = mod.import_table.pop();
    if (gop.found_existing) return ImportFileResult{
        .file = gop.value_ptr.*,
        .is_new = false,
    };

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
        .pkg = pkg,
        .root_decl = .none,
    };
    return ImportFileResult{
        .file = new_file,
        .is_new = true,
    };
}

pub fn importFile(
    mod: *Module,
    cur_file: *File,
    import_string: []const u8,
) !ImportFileResult {
    if (cur_file.pkg.table.get(import_string)) |pkg| {
        return mod.importPkg(pkg);
    }
    if (!mem.endsWith(u8, import_string, ".zig")) {
        return error.PackageNotFound;
    }
    const gpa = mod.gpa;

    // The resolved path is used as the key in the import table, to detect if
    // an import refers to the same as another, despite different relative paths
    // or differently mapped package names.
    const cur_pkg_dir_path = cur_file.pkg.root_src_directory.path orelse ".";
    const resolved_path = try std.fs.path.resolve(gpa, &[_][]const u8{
        cur_pkg_dir_path, cur_file.sub_file_path, "..", import_string,
    });
    var keep_resolved_path = false;
    defer if (!keep_resolved_path) gpa.free(resolved_path);

    const gop = try mod.import_table.getOrPut(gpa, resolved_path);
    errdefer _ = mod.import_table.pop();
    if (gop.found_existing) return ImportFileResult{
        .file = gop.value_ptr.*,
        .is_new = false,
    };

    const new_file = try gpa.create(File);
    errdefer gpa.destroy(new_file);

    const resolved_root_path = try std.fs.path.resolve(gpa, &[_][]const u8{cur_pkg_dir_path});
    defer gpa.free(resolved_root_path);

    if (!mem.startsWith(u8, resolved_path, resolved_root_path)) {
        return error.ImportOutsidePkgPath;
    }
    // +1 for the directory separator here.
    const sub_file_path = try gpa.dupe(u8, resolved_path[resolved_root_path.len + 1 ..]);
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
        .pkg = cur_file.pkg,
        .root_decl = .none,
    };
    return ImportFileResult{
        .file = new_file,
        .is_new = true,
    };
}

pub fn embedFile(mod: *Module, cur_file: *File, rel_file_path: []const u8) !*EmbedFile {
    const gpa = mod.gpa;

    // The resolved path is used as the key in the table, to detect if
    // a file refers to the same as another, despite different relative paths.
    const cur_pkg_dir_path = cur_file.pkg.root_src_directory.path orelse ".";
    const resolved_path = try std.fs.path.resolve(gpa, &[_][]const u8{
        cur_pkg_dir_path, cur_file.sub_file_path, "..", rel_file_path,
    });
    var keep_resolved_path = false;
    defer if (!keep_resolved_path) gpa.free(resolved_path);

    const gop = try mod.embed_table.getOrPut(gpa, resolved_path);
    errdefer assert(mod.embed_table.remove(resolved_path));
    if (gop.found_existing) return gop.value_ptr.*;

    const new_file = try gpa.create(EmbedFile);
    errdefer gpa.destroy(new_file);

    const resolved_root_path = try std.fs.path.resolve(gpa, &[_][]const u8{cur_pkg_dir_path});
    defer gpa.free(resolved_root_path);

    if (!mem.startsWith(u8, resolved_path, resolved_root_path)) {
        return error.ImportOutsidePkgPath;
    }
    // +1 for the directory separator here.
    const sub_file_path = try gpa.dupe(u8, resolved_path[resolved_root_path.len + 1 ..]);
    errdefer gpa.free(sub_file_path);

    var file = try cur_file.pkg.root_src_directory.handle.openFile(sub_file_path, .{});
    defer file.close();

    const actual_stat = try file.stat();
    const stat: Cache.File.Stat = .{
        .size = actual_stat.size,
        .inode = actual_stat.inode,
        .mtime = actual_stat.mtime,
    };
    const size_usize = std.math.cast(usize, actual_stat.size) orelse return error.Overflow;
    const bytes = try file.readToEndAllocOptions(gpa, std.math.maxInt(u32), size_usize, 1, 0);
    errdefer gpa.free(bytes);

    log.debug("new embedFile. resolved_root_path={s}, resolved_path={s}, sub_file_path={s}, rel_file_path={s}", .{
        resolved_root_path, resolved_path, sub_file_path, rel_file_path,
    });

    if (mod.comp.whole_cache_manifest) |man| {
        const copied_resolved_path = try gpa.dupe(u8, resolved_path);
        errdefer gpa.free(copied_resolved_path);
        try man.addFilePostContents(copied_resolved_path, bytes, stat);
    }

    keep_resolved_path = true; // It's now owned by embed_table.
    gop.value_ptr.* = new_file;
    new_file.* = .{
        .sub_file_path = sub_file_path,
        .bytes = bytes,
        .stat = stat,
        .pkg = cur_file.pkg,
        .owner_decl = undefined, // Set by Sema immediately after this function returns.
    };
    return new_file;
}

pub fn detectEmbedFileUpdate(mod: *Module, embed_file: *EmbedFile) !void {
    var file = try embed_file.pkg.root_src_directory.handle.openFile(embed_file.sub_file_path, .{});
    defer file.close();

    const stat = try file.stat();

    const unchanged_metadata =
        stat.size == embed_file.stat.size and
        stat.mtime == embed_file.stat.mtime and
        stat.inode == embed_file.stat.inode;

    if (unchanged_metadata) return;

    const gpa = mod.gpa;
    const size_usize = std.math.cast(usize, stat.size) orelse return error.Overflow;
    const bytes = try file.readToEndAllocOptions(gpa, std.math.maxInt(u32), size_usize, 1, 0);
    gpa.free(embed_file.bytes);
    embed_file.bytes = bytes;
    embed_file.stat = .{
        .size = stat.size,
        .mtime = stat.mtime,
        .inode = stat.inode,
    };

    mod.comp.mutex.lock();
    defer mod.comp.mutex.unlock();
    try mod.comp.work_queue.writeItem(.{ .update_embed_file = embed_file });
}

pub fn scanNamespace(
    mod: *Module,
    namespace: *Namespace,
    extra_start: usize,
    decls_len: u32,
    parent_decl: *Decl,
) SemaError!usize {
    const tracy = trace(@src());
    defer tracy.end();

    const gpa = mod.gpa;
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
        .namespace = namespace,
        .parent_decl = parent_decl,
    };
    while (decl_i < decls_len) : (decl_i += 1) {
        if (decl_i % 8 == 0) {
            cur_bit_bag = zir.extra[bit_bag_index];
            bit_bag_index += 1;
        }
        const flags = @truncate(u4, cur_bit_bag);
        cur_bit_bag >>= 4;

        const decl_sub_index = extra_index;
        extra_index += 8; // src_hash(4) + line(1) + name(1) + value(1) + doc_comment(1)
        extra_index += @truncate(u1, flags >> 2); // Align
        extra_index += @as(u2, @truncate(u1, flags >> 3)) * 2; // Link section or address space, consists of 2 Refs

        try scanDecl(&scan_decl_iter, decl_sub_index, flags);
    }
    return extra_index;
}

const ScanDeclIter = struct {
    module: *Module,
    namespace: *Namespace,
    parent_decl: *Decl,
    usingnamespace_index: usize = 0,
    comptime_index: usize = 0,
    unnamed_test_index: usize = 0,
};

fn scanDecl(iter: *ScanDeclIter, decl_sub_index: usize, flags: u4) SemaError!void {
    const tracy = trace(@src());
    defer tracy.end();

    const mod = iter.module;
    const namespace = iter.namespace;
    const gpa = mod.gpa;
    const zir = namespace.file_scope.zir;

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
    const decl_name: [:0]const u8 = switch (decl_name_index) {
        0 => name: {
            if (export_bit) {
                const i = iter.usingnamespace_index;
                iter.usingnamespace_index += 1;
                break :name try std.fmt.allocPrintZ(gpa, "usingnamespace_{d}", .{i});
            } else {
                const i = iter.comptime_index;
                iter.comptime_index += 1;
                break :name try std.fmt.allocPrintZ(gpa, "comptime_{d}", .{i});
            }
        },
        1 => name: {
            const i = iter.unnamed_test_index;
            iter.unnamed_test_index += 1;
            break :name try std.fmt.allocPrintZ(gpa, "test_{d}", .{i});
        },
        2 => name: {
            is_named_test = true;
            const test_name = zir.nullTerminatedString(decl_doccomment_index);
            break :name try std.fmt.allocPrintZ(gpa, "decltest.{s}", .{test_name});
        },
        else => name: {
            const raw_name = zir.nullTerminatedString(decl_name_index);
            if (raw_name.len == 0) {
                is_named_test = true;
                const test_name = zir.nullTerminatedString(decl_name_index + 1);
                break :name try std.fmt.allocPrintZ(gpa, "test.{s}", .{test_name});
            } else {
                break :name try gpa.dupeZ(u8, raw_name);
            }
        },
    };
    const is_exported = export_bit and decl_name_index != 0;
    const is_usingnamespace = export_bit and decl_name_index == 0;
    if (is_usingnamespace) try namespace.usingnamespace_set.ensureUnusedCapacity(gpa, 1);

    // We create a Decl for it regardless of analysis status.
    const gop = try namespace.decls.getOrPutContextAdapted(
        gpa,
        @as([]const u8, mem.sliceTo(decl_name, 0)),
        DeclAdapter{ .mod = mod },
        Namespace.DeclContext{ .module = mod },
    );
    const comp = mod.comp;
    if (!gop.found_existing) {
        const new_decl_index = try mod.allocateNewDecl(namespace, decl_node, iter.parent_decl.src_scope);
        const new_decl = mod.declPtr(new_decl_index);
        new_decl.name = decl_name;
        if (is_usingnamespace) {
            namespace.usingnamespace_set.putAssumeCapacity(new_decl_index, is_pub);
        }
        log.debug("scan new {*} ({s}) into {*}", .{ new_decl, decl_name, namespace });
        new_decl.src_line = line;
        gop.key_ptr.* = new_decl_index;
        // Exported decls, comptime decls, usingnamespace decls, and
        // test decls if in test mode, get analyzed.
        const decl_pkg = namespace.file_scope.pkg;
        const want_analysis = is_exported or switch (decl_name_index) {
            0 => true, // comptime or usingnamespace decl
            1 => blk: {
                // test decl with no name. Skip the part where we check against
                // the test name filter.
                if (!comp.bin_file.options.is_test) break :blk false;
                if (decl_pkg != mod.main_pkg) {
                    if (!mod.main_pkg_in_std) break :blk false;
                    const std_pkg = mod.main_pkg.table.get("std").?;
                    if (std_pkg != decl_pkg) break :blk false;
                }
                try mod.test_functions.put(gpa, new_decl_index, {});
                break :blk true;
            },
            else => blk: {
                if (!is_named_test) break :blk false;
                if (!comp.bin_file.options.is_test) break :blk false;
                if (decl_pkg != mod.main_pkg) {
                    if (!mod.main_pkg_in_std) break :blk false;
                    const std_pkg = mod.main_pkg.table.get("std").?;
                    if (std_pkg != decl_pkg) break :blk false;
                }
                if (comp.test_filter) |test_filter| {
                    if (mem.indexOf(u8, decl_name, test_filter) == null) {
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
        new_decl.is_usingnamespace = is_usingnamespace;
        new_decl.has_align = has_align;
        new_decl.has_linksection_or_addrspace = has_linksection_or_addrspace;
        new_decl.zir_decl_index = @intCast(u32, decl_sub_index);
        new_decl.alive = true; // This Decl corresponds to an AST node and therefore always alive.
        return;
    }
    gpa.free(decl_name);
    const decl_index = gop.key_ptr.*;
    const decl = mod.declPtr(decl_index);
    log.debug("scan existing {*} ({s}) of {*}", .{ decl, decl.name, namespace });
    // Update the AST node of the decl; even if its contents are unchanged, it may
    // have been re-ordered.
    decl.src_node = decl_node;
    decl.src_line = line;

    decl.is_pub = is_pub;
    decl.is_exported = is_exported;
    decl.is_usingnamespace = is_usingnamespace;
    decl.has_align = has_align;
    decl.has_linksection_or_addrspace = has_linksection_or_addrspace;
    decl.zir_decl_index = @intCast(u32, decl_sub_index);
    if (decl.getFunction()) |_| {
        switch (comp.bin_file.tag) {
            .coff => {
                // TODO Implement for COFF
            },
            .elf => if (decl.fn_link.elf.len != 0) {
                // TODO Look into detecting when this would be unnecessary by storing enough state
                // in `Decl` to notice that the line number did not change.
                comp.work_queue.writeItemAssumeCapacity(.{ .update_line_number = decl_index });
            },
            .macho => if (decl.fn_link.macho.len != 0) {
                // TODO Look into detecting when this would be unnecessary by storing enough state
                // in `Decl` to notice that the line number did not change.
                comp.work_queue.writeItemAssumeCapacity(.{ .update_line_number = decl_index });
            },
            .plan9 => {
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
    log.debug("clearing {*} ({s})", .{ decl, decl.name });

    const gpa = mod.gpa;
    try mod.deletion_set.ensureUnusedCapacity(gpa, decl.dependencies.count());

    if (outdated_decls) |map| {
        _ = map.swapRemove(decl_index);
        try map.ensureUnusedCapacity(decl.dependants.count());
    }

    // Remove itself from its dependencies.
    for (decl.dependencies.keys()) |dep_index| {
        const dep = mod.declPtr(dep_index);
        dep.removeDependant(decl_index);
        if (dep.dependants.count() == 0 and !dep.deletion_flag) {
            log.debug("insert {*} ({s}) dependant {*} ({s}) into deletion set", .{
                decl, decl.name, dep, dep.name,
            });
            // We don't recursively perform a deletion here, because during the update,
            // another reference to it may turn up.
            dep.deletion_flag = true;
            mod.deletion_set.putAssumeCapacity(dep_index, {});
        }
    }
    decl.dependencies.clearRetainingCapacity();

    // Anything that depends on this deleted decl needs to be re-analyzed.
    for (decl.dependants.keys()) |dep_index| {
        const dep = mod.declPtr(dep_index);
        dep.removeDependency(decl_index);
        if (outdated_decls) |map| {
            map.putAssumeCapacity(dep_index, {});
        }
    }
    decl.dependants.clearRetainingCapacity();

    if (mod.failed_decls.fetchSwapRemove(decl_index)) |kv| {
        kv.value.destroy(gpa);
    }
    if (mod.emit_h) |emit_h| {
        if (emit_h.failed_decls.fetchSwapRemove(decl_index)) |kv| {
            kv.value.destroy(gpa);
        }
        assert(emit_h.decl_table.swapRemove(decl_index));
    }
    _ = mod.compile_log_decls.swapRemove(decl_index);
    mod.deleteDeclExports(decl_index);

    if (decl.has_tv) {
        if (decl.ty.isFnOrHasRuntimeBits()) {
            mod.comp.bin_file.freeDecl(decl_index);

            // TODO instead of a union, put this memory trailing Decl objects,
            // and allow it to be variably sized.
            decl.link = switch (mod.comp.bin_file.tag) {
                .coff => .{ .coff = link.File.Coff.TextBlock.empty },
                .elf => .{ .elf = link.File.Elf.TextBlock.empty },
                .macho => .{ .macho = link.File.MachO.TextBlock.empty },
                .plan9 => .{ .plan9 = link.File.Plan9.DeclBlock.empty },
                .c => .{ .c = {} },
                .wasm => .{ .wasm = link.File.Wasm.DeclBlock.empty },
                .spirv => .{ .spirv = {} },
                .nvptx => .{ .nvptx = {} },
            };
            decl.fn_link = switch (mod.comp.bin_file.tag) {
                .coff => .{ .coff = {} },
                .elf => .{ .elf = link.File.Dwarf.SrcFn.empty },
                .macho => .{ .macho = link.File.Dwarf.SrcFn.empty },
                .plan9 => .{ .plan9 = {} },
                .c => .{ .c = {} },
                .wasm => .{ .wasm = link.File.Wasm.FnData.empty },
                .spirv => .{ .spirv = .{} },
                .nvptx => .{ .nvptx = {} },
            };
        }
        if (decl.getInnerNamespace()) |namespace| {
            try namespace.deleteAllDecls(mod, outdated_decls);
        }
        decl.clearValues(mod);
    }

    if (decl.deletion_flag) {
        decl.deletion_flag = false;
        assert(mod.deletion_set.swapRemove(decl_index));
    }

    decl.analysis = .unreferenced;
}

/// This function is exclusively called for anonymous decls.
pub fn deleteUnusedDecl(mod: *Module, decl_index: Decl.Index) void {
    const decl = mod.declPtr(decl_index);
    log.debug("deleteUnusedDecl {d} ({s})", .{ decl_index, decl.name });

    // TODO: remove `allocateDeclIndexes` and make the API that the linker backends
    // are required to notice the first time `updateDecl` happens and keep track
    // of it themselves. However they can rely on getting a `freeDecl` call if any
    // `updateDecl` or `updateFunc` calls happen. This will allow us to avoid any call
    // into the linker backend here, since the linker backend will never have been told
    // about the Decl in the first place.
    // Until then, we did call `allocateDeclIndexes` on this anonymous Decl and so we
    // must call `freeDecl` in the linker backend now.
    switch (mod.comp.bin_file.tag) {
        .c => {}, // this linker backend has already migrated to the new API
        else => if (decl.has_tv) {
            if (decl.ty.isFnOrHasRuntimeBits()) {
                mod.comp.bin_file.freeDecl(decl_index);
            }
        },
    }

    assert(!mod.declIsRoot(decl_index));
    assert(decl.src_namespace.anon_decls.swapRemove(decl_index));

    const dependants = decl.dependants.keys();
    for (dependants) |dep| {
        mod.declPtr(dep).removeDependency(decl_index);
    }

    for (decl.dependencies.keys()) |dep| {
        mod.declPtr(dep).removeDependant(decl_index);
    }
    mod.destroyDecl(decl_index);
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
    const decl = mod.declPtr(decl_index);
    log.debug("abortAnonDecl {*} ({s})", .{ decl, decl.name });

    assert(!mod.declIsRoot(decl_index));
    assert(decl.src_namespace.anon_decls.swapRemove(decl_index));

    // An aborted decl must not have dependants -- they must have
    // been aborted first and removed from this list.
    assert(decl.dependants.count() == 0);

    for (decl.dependencies.keys()) |dep_index| {
        const dep = mod.declPtr(dep_index);
        dep.removeDependant(decl_index);
    }

    mod.destroyDecl(decl_index);
}

/// Delete all the Export objects that are caused by this Decl. Re-analysis of
/// this Decl will cause them to be re-created (or not).
fn deleteDeclExports(mod: *Module, decl_index: Decl.Index) void {
    const kv = mod.export_owners.fetchSwapRemove(decl_index) orelse return;

    for (kv.value) |exp| {
        if (mod.decl_exports.getPtr(exp.exported_decl)) |value_ptr| {
            // Remove exports with owner_decl matching the regenerating decl.
            const list = value_ptr.*;
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
            value_ptr.* = mod.gpa.shrink(list, new_len);
            if (new_len == 0) {
                assert(mod.decl_exports.swapRemove(exp.exported_decl));
            }
        }
        if (mod.comp.bin_file.cast(link.File.Elf)) |elf| {
            elf.deleteExport(exp.link.elf);
        }
        if (mod.comp.bin_file.cast(link.File.MachO)) |macho| {
            macho.deleteExport(exp.link.macho);
        }
        if (mod.comp.bin_file.cast(link.File.Wasm)) |wasm| {
            wasm.deleteExport(exp.link.wasm);
        }
        if (mod.failed_exports.fetchSwapRemove(exp)) |failed_kv| {
            failed_kv.value.destroy(mod.gpa);
        }
        mod.gpa.free(exp.options.name);
        mod.gpa.destroy(exp);
    }
    mod.gpa.free(kv.value);
}

pub fn analyzeFnBody(mod: *Module, func: *Fn, arena: Allocator) SemaError!Air {
    const tracy = trace(@src());
    defer tracy.end();

    const gpa = mod.gpa;
    const decl_index = func.owner_decl;
    const decl = mod.declPtr(decl_index);

    // Use the Decl's arena for captured values.
    var decl_arena = decl.value_arena.?.promote(gpa);
    defer decl.value_arena.?.* = decl_arena.state;
    const decl_arena_allocator = decl_arena.allocator();

    var sema: Sema = .{
        .mod = mod,
        .gpa = gpa,
        .arena = arena,
        .perm_arena = decl_arena_allocator,
        .code = decl.getFileScope().zir,
        .owner_decl = decl,
        .owner_decl_index = decl_index,
        .func = func,
        .fn_ret_ty = decl.ty.fnReturnType(),
        .owner_func = func,
        .branch_quota = @maximum(func.branch_quota, Sema.default_branch_quota),
    };
    defer sema.deinit();

    // reset in case calls to errorable functions are removed.
    func.calls_or_awaits_errorable_fn = false;

    // First few indexes of extra are reserved and set at the end.
    const reserved_count = @typeInfo(Air.ExtraIndex).Enum.fields.len;
    try sema.air_extra.ensureTotalCapacity(gpa, reserved_count);
    sema.air_extra.items.len += reserved_count;

    var wip_captures = try WipCaptureScope.init(gpa, decl_arena_allocator, decl.src_scope);
    defer wip_captures.deinit();

    var inner_block: Sema.Block = .{
        .parent = null,
        .sema = &sema,
        .src_decl = decl_index,
        .namespace = decl.src_namespace,
        .wip_capture_scope = wip_captures.scope,
        .instructions = .{},
        .inlining = null,
        .is_comptime = false,
    };
    defer inner_block.instructions.deinit(gpa);

    const fn_info = sema.code.getFnInfo(func.zir_body_inst);
    const zir_tags = sema.code.instructions.items(.tag);

    // Here we are performing "runtime semantic analysis" for a function body, which means
    // we must map the parameter ZIR instructions to `arg` AIR instructions.
    // AIR requires the `arg` parameters to be the first N instructions.
    // This could be a generic function instantiation, however, in which case we need to
    // map the comptime parameters to constant values and only emit arg AIR instructions
    // for the runtime ones.
    const fn_ty = decl.ty;
    const fn_ty_info = fn_ty.fnInfo();
    const runtime_params_len = @intCast(u32, fn_ty_info.param_types.len);
    try inner_block.instructions.ensureTotalCapacityPrecise(gpa, runtime_params_len);
    try sema.air_instructions.ensureUnusedCapacity(gpa, fn_info.total_params_len * 2); // * 2 for the `addType`
    try sema.inst_map.ensureUnusedCapacity(gpa, fn_info.total_params_len);

    var runtime_param_index: usize = 0;
    var total_param_index: usize = 0;
    for (fn_info.param_body) |inst| {
        const param: struct { name: u32, src: LazySrcLoc } = switch (zir_tags[inst]) {
            .param, .param_comptime => blk: {
                const pl_tok = sema.code.instructions.items(.data)[inst].pl_tok;
                const extra = sema.code.extraData(Zir.Inst.Param, pl_tok.payload_index).data;
                break :blk .{ .name = extra.name, .src = pl_tok.src() };
            },

            .param_anytype, .param_anytype_comptime => blk: {
                const str_tok = sema.code.instructions.items(.data)[inst].str_tok;
                break :blk .{ .name = str_tok.start, .src = str_tok.src() };
            },

            else => continue,
        };

        const param_ty = if (func.comptime_args) |comptime_args| t: {
            const arg_tv = comptime_args[total_param_index];

            const arg_val = if (arg_tv.val.tag() != .generic_poison)
                arg_tv.val
            else if (arg_tv.ty.onePossibleValue()) |opv|
                opv
            else
                break :t arg_tv.ty;

            const arg = try sema.addConstant(arg_tv.ty, arg_val);
            sema.inst_map.putAssumeCapacityNoClobber(inst, arg);
            total_param_index += 1;
            continue;
        } else fn_ty_info.param_types[runtime_param_index];

        const opt_opv = sema.typeHasOnePossibleValue(&inner_block, param.src, param_ty) catch |err| switch (err) {
            error.NeededSourceLocation => unreachable,
            error.GenericPoison => unreachable,
            error.ComptimeReturn => unreachable,
            error.ComptimeBreak => unreachable,
            else => |e| return e,
        };
        if (opt_opv) |opv| {
            const arg = try sema.addConstant(param_ty, opv);
            sema.inst_map.putAssumeCapacityNoClobber(inst, arg);
            total_param_index += 1;
            runtime_param_index += 1;
            continue;
        }
        const arg_index = @intCast(u32, sema.air_instructions.len);
        inner_block.instructions.appendAssumeCapacity(arg_index);
        sema.air_instructions.appendAssumeCapacity(.{
            .tag = .arg,
            .data = .{ .ty = param_ty },
        });
        sema.inst_map.putAssumeCapacityNoClobber(inst, Air.indexToRef(arg_index));
        total_param_index += 1;
        runtime_param_index += 1;
    }

    func.state = .in_progress;
    log.debug("set {s} to in_progress", .{decl.name});

    const last_arg_index = inner_block.instructions.items.len;

    sema.analyzeBody(&inner_block, fn_info.body) catch |err| switch (err) {
        // TODO make these unreachable instead of @panic
        error.NeededSourceLocation => @panic("zig compiler bug: NeededSourceLocation"),
        error.GenericPoison => @panic("zig compiler bug: GenericPoison"),
        error.ComptimeReturn => @panic("zig compiler bug: ComptimeReturn"),
        else => |e| return e,
    };

    // If we don't get an error return trace from a caller, create our own.
    if (func.calls_or_awaits_errorable_fn and
        mod.comp.bin_file.options.error_return_tracing and
        !sema.fn_ret_ty.isError())
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

    try wip_captures.finalize();

    // Copy the block into place and mark that as the main block.
    try sema.air_extra.ensureUnusedCapacity(gpa, @typeInfo(Air.Block).Struct.fields.len +
        inner_block.instructions.items.len);
    const main_block_index = sema.addExtraAssumeCapacity(Air.Block{
        .body_len = @intCast(u32, inner_block.instructions.items.len),
    });
    sema.air_extra.appendSliceAssumeCapacity(inner_block.instructions.items);
    sema.air_extra.items[@enumToInt(Air.ExtraIndex.main_block)] = main_block_index;

    func.state = .success;
    log.debug("set {s} to success", .{decl.name});

    // Finally we must resolve the return type and parameter types so that backends
    // have full access to type information.
    // Crucially, this happens *after* we set the function state to success above,
    // so that dependencies on the function body will now be satisfied rather than
    // result in circular dependency errors.
    const src = LazySrcLoc.nodeOffset(0);
    sema.resolveFnTypes(&inner_block, src, fn_ty_info) catch |err| switch (err) {
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
    for (sema.types_to_resolve.items) |inst_ref| {
        const ty = sema.getTmpAir().getRefType(inst_ref);
        sema.resolveTypeFully(&inner_block, src, ty) catch |err| switch (err) {
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

    return Air{
        .instructions = sema.air_instructions.toOwnedSlice(),
        .extra = sema.air_extra.toOwnedSlice(gpa),
        .values = sema.air_values.toOwnedSlice(gpa),
    };
}

fn markOutdatedDecl(mod: *Module, decl_index: Decl.Index) !void {
    const decl = mod.declPtr(decl_index);
    log.debug("mark outdated {*} ({s})", .{ decl, decl.name });
    try mod.comp.work_queue.writeItem(.{ .analyze_decl = decl_index });
    if (mod.failed_decls.fetchSwapRemove(decl_index)) |kv| {
        kv.value.destroy(mod.gpa);
    }
    if (decl.has_tv and decl.owns_tv) {
        if (decl.val.castTag(.function)) |payload| {
            const func = payload.data;
            _ = mod.align_stack_fns.remove(func);
        }
    }
    if (mod.emit_h) |emit_h| {
        if (emit_h.failed_decls.fetchSwapRemove(decl_index)) |kv| {
            kv.value.destroy(mod.gpa);
        }
    }
    _ = mod.compile_log_decls.swapRemove(decl_index);
    decl.analysis = .outdated;
}

pub fn allocateNewDecl(
    mod: *Module,
    namespace: *Namespace,
    src_node: Ast.Node.Index,
    src_scope: ?*CaptureScope,
) !Decl.Index {
    const decl_and_index: struct {
        new_decl: *Decl,
        decl_index: Decl.Index,
    } = if (mod.decls_free_list.popOrNull()) |decl_index| d: {
        break :d .{
            .new_decl = mod.declPtr(decl_index),
            .decl_index = decl_index,
        };
    } else d: {
        const decl = try mod.allocated_decls.addOne(mod.gpa);
        errdefer mod.allocated_decls.shrinkRetainingCapacity(mod.allocated_decls.len - 1);
        if (mod.emit_h) |mod_emit_h| {
            const decl_emit_h = try mod_emit_h.allocated_emit_h.addOne(mod.gpa);
            decl_emit_h.* = .{};
        }
        break :d .{
            .new_decl = decl,
            .decl_index = @intToEnum(Decl.Index, mod.allocated_decls.len - 1),
        };
    };

    decl_and_index.new_decl.* = .{
        .name = undefined,
        .src_namespace = namespace,
        .src_node = src_node,
        .src_line = undefined,
        .has_tv = false,
        .owns_tv = false,
        .ty = undefined,
        .val = undefined,
        .@"align" = undefined,
        .@"linksection" = undefined,
        .@"addrspace" = .generic,
        .analysis = .unreferenced,
        .deletion_flag = false,
        .zir_decl_index = 0,
        .src_scope = src_scope,
        .link = switch (mod.comp.bin_file.tag) {
            .coff => .{ .coff = link.File.Coff.TextBlock.empty },
            .elf => .{ .elf = link.File.Elf.TextBlock.empty },
            .macho => .{ .macho = link.File.MachO.TextBlock.empty },
            .plan9 => .{ .plan9 = link.File.Plan9.DeclBlock.empty },
            .c => .{ .c = {} },
            .wasm => .{ .wasm = link.File.Wasm.DeclBlock.empty },
            .spirv => .{ .spirv = {} },
            .nvptx => .{ .nvptx = {} },
        },
        .fn_link = switch (mod.comp.bin_file.tag) {
            .coff => .{ .coff = {} },
            .elf => .{ .elf = link.File.Dwarf.SrcFn.empty },
            .macho => .{ .macho = link.File.Dwarf.SrcFn.empty },
            .plan9 => .{ .plan9 = {} },
            .c => .{ .c = {} },
            .wasm => .{ .wasm = link.File.Wasm.FnData.empty },
            .spirv => .{ .spirv = .{} },
            .nvptx => .{ .nvptx = {} },
        },
        .generation = 0,
        .is_pub = false,
        .is_exported = false,
        .has_linksection_or_addrspace = false,
        .has_align = false,
        .alive = false,
        .is_usingnamespace = false,
    };

    return decl_and_index.decl_index;
}

/// Get error value for error tag `name`.
pub fn getErrorValue(mod: *Module, name: []const u8) !std.StringHashMapUnmanaged(ErrorInt).KV {
    const gop = try mod.global_error_set.getOrPut(mod.gpa, name);
    if (gop.found_existing) {
        return std.StringHashMapUnmanaged(ErrorInt).KV{
            .key = gop.key_ptr.*,
            .value = gop.value_ptr.*,
        };
    }

    errdefer assert(mod.global_error_set.remove(name));
    try mod.error_name_list.ensureUnusedCapacity(mod.gpa, 1);
    gop.key_ptr.* = try mod.gpa.dupe(u8, name);
    gop.value_ptr.* = @intCast(ErrorInt, mod.error_name_list.items.len);
    mod.error_name_list.appendAssumeCapacity(gop.key_ptr.*);
    return std.StringHashMapUnmanaged(ErrorInt).KV{
        .key = gop.key_ptr.*,
        .value = gop.value_ptr.*,
    };
}

pub fn createAnonymousDecl(mod: *Module, block: *Sema.Block, typed_value: TypedValue) !Decl.Index {
    const src_decl = mod.declPtr(block.src_decl);
    return mod.createAnonymousDeclFromDecl(src_decl, block.namespace, block.wip_capture_scope, typed_value);
}

pub fn createAnonymousDeclFromDecl(
    mod: *Module,
    src_decl: *Decl,
    namespace: *Namespace,
    src_scope: ?*CaptureScope,
    tv: TypedValue,
) !Decl.Index {
    const new_decl_index = try mod.allocateNewDecl(namespace, src_decl.src_node, src_scope);
    errdefer mod.destroyDecl(new_decl_index);
    const name = try std.fmt.allocPrintZ(mod.gpa, "{s}__anon_{d}", .{
        src_decl.name, @enumToInt(new_decl_index),
    });
    try mod.initNewAnonDecl(new_decl_index, src_decl.src_line, namespace, tv, name);
    return new_decl_index;
}

/// Takes ownership of `name` even if it returns an error.
pub fn initNewAnonDecl(
    mod: *Module,
    new_decl_index: Decl.Index,
    src_line: u32,
    namespace: *Namespace,
    typed_value: TypedValue,
    name: [:0]u8,
) !void {
    errdefer mod.gpa.free(name);

    const new_decl = mod.declPtr(new_decl_index);

    new_decl.name = name;
    new_decl.src_line = src_line;
    new_decl.ty = typed_value.ty;
    new_decl.val = typed_value.val;
    new_decl.@"align" = 0;
    new_decl.@"linksection" = null;
    new_decl.has_tv = true;
    new_decl.analysis = .complete;
    new_decl.generation = mod.generation;

    try namespace.anon_decls.putNoClobber(mod.gpa, new_decl_index, {});

    // The Decl starts off with alive=false and the codegen backend will set alive=true
    // if the Decl is referenced by an instruction or another constant. Otherwise,
    // the Decl will be garbage collected by the `codegen_decl` task instead of sent
    // to the linker.
    if (typed_value.ty.isFnOrHasRuntimeBits()) {
        try mod.comp.bin_file.allocateDeclIndexes(new_decl_index);
        try mod.comp.anon_work_queue.writeItem(.{ .codegen_decl = new_decl_index });
    }
}

pub fn makeIntType(arena: Allocator, signedness: std.builtin.Signedness, bits: u16) !Type {
    const int_payload = try arena.create(Type.Payload.Bits);
    int_payload.* = .{
        .base = .{
            .tag = switch (signedness) {
                .signed => .int_signed,
                .unsigned => .int_unsigned,
            },
        },
        .data = bits,
    };
    return Type.initPayload(&int_payload.base);
}

pub fn errNoteNonLazy(
    mod: *Module,
    src_loc: SrcLoc,
    parent: *ErrorMsg,
    comptime format: []const u8,
    args: anytype,
) error{OutOfMemory}!void {
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

pub fn optimizeMode(mod: Module) std.builtin.Mode {
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
    scalar: u32,
    multi: Multi,
    range: Multi,

    pub const Multi = struct {
        prong: u32,
        item: u32,
    };

    pub const RangeExpand = enum { none, first, last };

    /// This function is intended to be called only when it is certain that we need
    /// the LazySrcLoc in order to emit a compile error.
    pub fn resolve(
        prong_src: SwitchProngSrc,
        gpa: Allocator,
        decl: *Decl,
        switch_node_offset: i32,
        range_expand: RangeExpand,
    ) LazySrcLoc {
        @setCold(true);
        const tree = decl.getFileScope().getTree(gpa) catch |err| {
            // In this case we emit a warning + a less precise source location.
            log.warn("unable to load {s}: {s}", .{
                decl.getFileScope().sub_file_path, @errorName(err),
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
        for (case_nodes) |case_node| {
            const case = switch (node_tags[case_node]) {
                .switch_case_one => tree.switchCaseOne(case_node),
                .switch_case => tree.switchCase(case_node),
                else => unreachable,
            };
            if (case.ast.values.len == 0)
                continue;
            if (case.ast.values.len == 1 and
                node_tags[case.ast.values[0]] == .identifier and
                mem.eql(u8, tree.tokenSlice(main_tokens[case.ast.values[0]]), "_"))
            {
                continue;
            }
            const is_multi = case.ast.values.len != 1 or
                node_tags[case.ast.values[0]] == .switch_range;

            switch (prong_src) {
                .scalar => |i| if (!is_multi and i == scalar_i) return LazySrcLoc.nodeOffset(
                    decl.nodeIndexToRelative(case.ast.values[0]),
                ),
                .multi => |s| if (is_multi and s.prong == multi_i) {
                    var item_i: u32 = 0;
                    for (case.ast.values) |item_node| {
                        if (node_tags[item_node] == .switch_range) continue;

                        if (item_i == s.item) return LazySrcLoc.nodeOffset(
                            decl.nodeIndexToRelative(item_node),
                        );
                        item_i += 1;
                    } else unreachable;
                },
                .range => |s| if (is_multi and s.prong == multi_i) {
                    var range_i: u32 = 0;
                    for (case.ast.values) |range| {
                        if (node_tags[range] != .switch_range) continue;

                        if (range_i == s.item) switch (range_expand) {
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
                    } else unreachable;
                },
            }
            if (is_multi) {
                multi_i += 1;
            } else {
                scalar_i += 1;
            }
        } else unreachable;
    }
};

pub const PeerTypeCandidateSrc = union(enum) {
    /// Do not print out error notes for candidate sources
    none: void,
    /// When we want to know the the src of candidate i, look up at
    /// index i in this slice
    override: []LazySrcLoc,
    /// resolvePeerTypes originates from a @TypeOf(...) call
    typeof_builtin_call_node_offset: i32,

    pub fn resolve(
        self: PeerTypeCandidateSrc,
        gpa: Allocator,
        decl: *Decl,
        candidate_i: usize,
    ) ?LazySrcLoc {
        @setCold(true);

        switch (self) {
            .none => {
                return null;
            },
            .override => |candidate_srcs| {
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

                const tree = decl.getFileScope().getTree(gpa) catch |err| {
                    // In this case we emit a warning + a less precise source location.
                    log.warn("unable to load {s}: {s}", .{
                        decl.getFileScope().sub_file_path, @errorName(err),
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
    range: enum { name, type, value, alignment },
};

fn queryFieldSrc(
    tree: Ast,
    query: FieldSrcQuery,
    file_scope: *File,
    container_decl: Ast.full.ContainerDecl,
) SrcLoc {
    const node_tags = tree.nodes.items(.tag);
    var field_index: usize = 0;
    for (container_decl.ast.members) |member_node| {
        const field = switch (node_tags[member_node]) {
            .container_field_init => tree.containerFieldInit(member_node),
            .container_field_align => tree.containerFieldAlign(member_node),
            .container_field => tree.containerField(member_node),
            else => continue,
        };
        if (field_index == query.index) {
            return switch (query.range) {
                .name => .{
                    .file_scope = file_scope,
                    .parent_decl_node = 0,
                    .lazy = .{ .token_abs = field.ast.name_token },
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
            log.debug("deleted from source: {*} ({s})", .{ decl, decl.name });

            // Remove from the namespace it resides in, preserving declaration order.
            assert(decl.zir_decl_index != 0);
            _ = decl.src_namespace.decls.orderedRemoveAdapted(@as([]const u8, mem.sliceTo(decl.name, 0)), DeclAdapter{ .mod = mod });

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
    const gpa = mod.gpa;
    // Map symbol names to `Export` for name collision detection.
    var symbol_exports: std.StringArrayHashMapUnmanaged(*Export) = .{};
    defer symbol_exports.deinit(gpa);

    var it = mod.decl_exports.iterator();
    while (it.next()) |entry| {
        const exported_decl = entry.key_ptr.*;
        const exports = entry.value_ptr.*;
        for (exports) |new_export| {
            const gop = try symbol_exports.getOrPut(gpa, new_export.options.name);
            if (gop.found_existing) {
                new_export.status = .failed_retryable;
                try mod.failed_exports.ensureUnusedCapacity(gpa, 1);
                const src_loc = new_export.getSrcLoc(mod);
                const msg = try ErrorMsg.create(gpa, src_loc, "exported symbol collision: {s}", .{
                    new_export.options.name,
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
        mod.comp.bin_file.updateDeclExports(mod, exported_decl, exports) catch |err| switch (err) {
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
}

pub fn populateTestFunctions(mod: *Module) !void {
    const gpa = mod.gpa;
    const builtin_pkg = mod.main_pkg.table.get("builtin").?;
    const builtin_file = (mod.importPkg(builtin_pkg) catch unreachable).file;
    const root_decl = mod.declPtr(builtin_file.root_decl.unwrap().?);
    const builtin_namespace = root_decl.src_namespace;
    const decl_index = builtin_namespace.decls.getKeyAdapted(@as([]const u8, "test_functions"), DeclAdapter{ .mod = mod }).?;
    const decl = mod.declPtr(decl_index);
    var buf: Type.SlicePtrFieldTypeBuffer = undefined;
    const tmp_test_fn_ty = decl.ty.slicePtrFieldType(&buf).elemType();

    const array_decl_index = d: {
        // Add mod.test_functions to an array decl then make the test_functions
        // decl reference it as a slice.
        var new_decl_arena = std.heap.ArenaAllocator.init(gpa);
        errdefer new_decl_arena.deinit();
        const arena = new_decl_arena.allocator();

        const test_fn_vals = try arena.alloc(Value, mod.test_functions.count());
        const array_decl_index = try mod.createAnonymousDeclFromDecl(decl, decl.src_namespace, null, .{
            .ty = try Type.Tag.array.create(arena, .{
                .len = test_fn_vals.len,
                .elem_type = try tmp_test_fn_ty.copy(arena),
            }),
            .val = try Value.Tag.aggregate.create(arena, test_fn_vals),
        });
        const array_decl = mod.declPtr(array_decl_index);

        // Add a dependency on each test name and function pointer.
        try array_decl.dependencies.ensureUnusedCapacity(gpa, test_fn_vals.len * 2);

        for (mod.test_functions.keys()) |test_decl_index, i| {
            const test_decl = mod.declPtr(test_decl_index);
            const test_name_slice = mem.sliceTo(test_decl.name, 0);
            const test_name_decl_index = n: {
                var name_decl_arena = std.heap.ArenaAllocator.init(gpa);
                errdefer name_decl_arena.deinit();
                const bytes = try name_decl_arena.allocator().dupe(u8, test_name_slice);
                const test_name_decl_index = try mod.createAnonymousDeclFromDecl(array_decl, array_decl.src_namespace, null, .{
                    .ty = try Type.Tag.array_u8.create(name_decl_arena.allocator(), bytes.len),
                    .val = try Value.Tag.bytes.create(name_decl_arena.allocator(), bytes),
                });
                try mod.declPtr(test_name_decl_index).finalizeNewArena(&name_decl_arena);
                break :n test_name_decl_index;
            };
            array_decl.dependencies.putAssumeCapacityNoClobber(test_decl_index, {});
            array_decl.dependencies.putAssumeCapacityNoClobber(test_name_decl_index, {});
            try mod.linkerUpdateDecl(test_name_decl_index);

            const field_vals = try arena.create([3]Value);
            field_vals.* = .{
                try Value.Tag.slice.create(arena, .{
                    .ptr = try Value.Tag.decl_ref.create(arena, test_name_decl_index),
                    .len = try Value.Tag.int_u64.create(arena, test_name_slice.len),
                }), // name
                try Value.Tag.decl_ref.create(arena, test_decl_index), // func
                Value.initTag(.null_value), // async_frame_size
            };
            test_fn_vals[i] = try Value.Tag.aggregate.create(arena, field_vals);
        }

        try array_decl.finalizeNewArena(&new_decl_arena);
        break :d array_decl_index;
    };
    try mod.linkerUpdateDecl(array_decl_index);

    {
        var new_decl_arena = std.heap.ArenaAllocator.init(gpa);
        errdefer new_decl_arena.deinit();
        const arena = new_decl_arena.allocator();

        // This copy accesses the old Decl Type/Value so it must be done before `clearValues`.
        const new_ty = try Type.Tag.const_slice.create(arena, try tmp_test_fn_ty.copy(arena));
        const new_val = try Value.Tag.slice.create(arena, .{
            .ptr = try Value.Tag.decl_ref.create(arena, array_decl_index),
            .len = try Value.Tag.int_u64.create(arena, mod.test_functions.count()),
        });

        // Since we are replacing the Decl's value we must perform cleanup on the
        // previous value.
        decl.clearValues(mod);
        decl.ty = new_ty;
        decl.val = new_val;
        decl.has_tv = true;

        try decl.finalizeNewArena(&new_decl_arena);
    }
    try mod.linkerUpdateDecl(decl_index);
}

pub fn linkerUpdateDecl(mod: *Module, decl_index: Decl.Index) !void {
    const comp = mod.comp;

    if (comp.bin_file.options.emit == null) return;

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
                decl.srcLoc(),
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

pub fn markReferencedDeclsAlive(mod: *Module, val: Value) void {
    switch (val.tag()) {
        .decl_ref_mut => return mod.markDeclIndexAlive(val.castTag(.decl_ref_mut).?.data.decl_index),
        .extern_fn => return mod.markDeclIndexAlive(val.castTag(.extern_fn).?.data.owner_decl),
        .function => return mod.markDeclIndexAlive(val.castTag(.function).?.data.owner_decl),
        .variable => return mod.markDeclIndexAlive(val.castTag(.variable).?.data.owner_decl),
        .decl_ref => return mod.markDeclIndexAlive(val.cast(Value.Payload.Decl).?.data),

        .repeated,
        .eu_payload,
        .opt_payload,
        .empty_array_sentinel,
        => return mod.markReferencedDeclsAlive(val.cast(Value.Payload.SubValue).?.data),

        .eu_payload_ptr,
        .opt_payload_ptr,
        => return mod.markReferencedDeclsAlive(val.cast(Value.Payload.PayloadPtr).?.data.container_ptr),

        .slice => {
            const slice = val.cast(Value.Payload.Slice).?.data;
            mod.markReferencedDeclsAlive(slice.ptr);
            mod.markReferencedDeclsAlive(slice.len);
        },

        .elem_ptr => {
            const elem_ptr = val.cast(Value.Payload.ElemPtr).?.data;
            return mod.markReferencedDeclsAlive(elem_ptr.array_ptr);
        },
        .field_ptr => {
            const field_ptr = val.cast(Value.Payload.FieldPtr).?.data;
            return mod.markReferencedDeclsAlive(field_ptr.container_ptr);
        },
        .aggregate => {
            for (val.castTag(.aggregate).?.data) |field_val| {
                mod.markReferencedDeclsAlive(field_val);
            }
        },
        .@"union" => {
            const data = val.cast(Value.Payload.Union).?.data;
            mod.markReferencedDeclsAlive(data.tag);
            mod.markReferencedDeclsAlive(data.val);
        },

        else => {},
    }
}

pub fn markDeclAlive(mod: *Module, decl: *Decl) void {
    if (decl.alive) return;
    decl.alive = true;

    // This is the first time we are marking this Decl alive. We must
    // therefore recurse into its value and mark any Decl it references
    // as also alive, so that any Decl referenced does not get garbage collected.
    mod.markReferencedDeclsAlive(decl.val);
}

fn markDeclIndexAlive(mod: *Module, decl_index: Decl.Index) void {
    return mod.markDeclAlive(mod.declPtr(decl_index));
}

pub fn addGlobalAssembly(mod: *Module, decl_index: Decl.Index, source: []const u8) !void {
    try mod.global_assembly.ensureUnusedCapacity(mod.gpa, 1);

    const duped_source = try mod.gpa.dupe(u8, source);
    errdefer mod.gpa.free(duped_source);

    mod.global_assembly.putAssumeCapacityNoClobber(decl_index, duped_source);
}
