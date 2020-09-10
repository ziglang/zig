const std = @import("std");
const mem = std.mem;
const Allocator = std.mem.Allocator;
const ArrayListUnmanaged = std.ArrayListUnmanaged;
const Value = @import("value.zig").Value;
const Type = @import("type.zig").Type;
const TypedValue = @import("TypedValue.zig");
const assert = std.debug.assert;
const log = std.log.scoped(.module);
const BigIntConst = std.math.big.int.Const;
const BigIntMutable = std.math.big.int.Mutable;
const Target = std.Target;
const target_util = @import("target.zig");
const Package = @import("Package.zig");
const link = @import("link.zig");
const ir = @import("ir.zig");
const zir = @import("zir.zig");
const Module = @This();
const Inst = ir.Inst;
const Body = ir.Body;
const ast = std.zig.ast;
const trace = @import("tracy.zig").trace;
const liveness = @import("liveness.zig");
const astgen = @import("astgen.zig");
const zir_sema = @import("zir_sema.zig");
const build_options = @import("build_options");
const LibCInstallation = @import("libc_installation.zig").LibCInstallation;

/// General-purpose allocator. Used for both temporary and long-term storage.
gpa: *Allocator,
/// Arena-allocated memory used during initialization. Should be untouched until deinit.
arena_state: std.heap.ArenaAllocator.State,
/// Pointer to externally managed resource. `null` if there is no zig file being compiled.
root_pkg: ?*Package,
/// Module owns this resource.
/// The `Scope` is either a `Scope.ZIRModule` or `Scope.File`.
root_scope: *Scope,
bin_file: *link.File,
/// It's rare for a decl to be exported, so we save memory by having a sparse map of
/// Decl pointers to details about them being exported.
/// The Export memory is owned by the `export_owners` table; the slice itself is owned by this table.
decl_exports: std.AutoArrayHashMapUnmanaged(*Decl, []*Export) = .{},
/// We track which export is associated with the given symbol name for quick
/// detection of symbol collisions.
symbol_exports: std.StringArrayHashMapUnmanaged(*Export) = .{},
/// This models the Decls that perform exports, so that `decl_exports` can be updated when a Decl
/// is modified. Note that the key of this table is not the Decl being exported, but the Decl that
/// is performing the export of another Decl.
/// This table owns the Export memory.
export_owners: std.AutoArrayHashMapUnmanaged(*Decl, []*Export) = .{},
/// Maps fully qualified namespaced names to the Decl struct for them.
decl_table: std.ArrayHashMapUnmanaged(Scope.NameHash, *Decl, Scope.name_hash_hash, Scope.name_hash_eql, false) = .{},

c_object_table: std.AutoArrayHashMapUnmanaged(*CObject, void) = .{},

link_error_flags: link.File.ErrorFlags = .{},

work_queue: std.fifo.LinearFifo(WorkItem, .Dynamic),

/// We optimize memory usage for a compilation with no compile errors by storing the
/// error messages and mapping outside of `Decl`.
/// The ErrorMsg memory is owned by the decl, using Module's general purpose allocator.
/// Note that a Decl can succeed but the Fn it represents can fail. In this case,
/// a Decl can have a failed_decls entry but have analysis status of success.
failed_decls: std.AutoArrayHashMapUnmanaged(*Decl, *ErrorMsg) = .{},
/// Using a map here for consistency with the other fields here.
/// The ErrorMsg memory is owned by the `Scope`, using Module's general purpose allocator.
failed_files: std.AutoArrayHashMapUnmanaged(*Scope, *ErrorMsg) = .{},
/// Using a map here for consistency with the other fields here.
/// The ErrorMsg memory is owned by the `Export`, using Module's general purpose allocator.
failed_exports: std.AutoArrayHashMapUnmanaged(*Export, *ErrorMsg) = .{},
/// The ErrorMsg memory is owned by the `CObject`, using Module's general purpose allocator.
failed_c_objects: std.AutoArrayHashMapUnmanaged(*CObject, *ErrorMsg) = .{},

/// Incrementing integer used to compare against the corresponding Decl
/// field to determine whether a Decl's status applies to an ongoing update, or a
/// previous analysis.
generation: u32 = 0,

next_anon_name_index: usize = 0,

/// Candidates for deletion. After a semantic analysis update completes, this list
/// contains Decls that need to be deleted if they end up having no references to them.
deletion_set: std.ArrayListUnmanaged(*Decl) = .{},

keep_source_files_loaded: bool,
use_clang: bool,
sanitize_c: bool,
/// When this is `true` it means invoking clang as a sub-process is expected to inherit
/// stdin, stdout, stderr, and if it returns non success, to forward the exit code.
/// Otherwise we attempt to parse the error messages and expose them via the Module API.
/// This is `true` for `zig cc`, `zig c++`, and `zig translate-c`.
clang_passthrough_mode: bool,

/// Error tags and their values, tag names are duped with mod.gpa.
global_error_set: std.StringHashMapUnmanaged(u16) = .{},

c_source_files: []const []const u8,
clang_argv: []const []const u8,
cache: std.cache_hash.CacheHash,
/// Path to own executable for invoking `zig clang`.
self_exe_path: ?[]const u8,
zig_lib_dir: []const u8,
zig_cache_dir_path: []const u8,
libc_include_dir_list: []const []const u8,
rand: *std.rand.Random,

/// Populated when we build libc++.a. A WorkItem to build this is placed in the queue
/// and resolved before calling linker.flush().
libcxx_static_lib: ?[]const u8 = null,
/// Populated when we build libc++abi.a. A WorkItem to build this is placed in the queue
/// and resolved before calling linker.flush().
libcxxabi_static_lib: ?[]const u8 = null,
/// Populated when we build libunwind.a. A WorkItem to build this is placed in the queue
/// and resolved before calling linker.flush().
libunwind_static_lib: ?[]const u8 = null,
/// Populated when we build c.a. A WorkItem to build this is placed in the queue
/// and resolved before calling linker.flush().
libc_static_lib: ?[]const u8 = null,

pub const InnerError = error{ OutOfMemory, AnalysisFail };

const WorkItem = union(enum) {
    /// Write the machine code for a Decl to the output file.
    codegen_decl: *Decl,
    /// The Decl needs to be analyzed and possibly export itself.
    /// It may have already be analyzed, or it may have been determined
    /// to be outdated; in this case perform semantic analysis again.
    analyze_decl: *Decl,
    /// The source file containing the Decl has been updated, and so the
    /// Decl may need its line number information updated in the debug info.
    update_line_number: *Decl,
    /// Invoke the Clang compiler to create an object file, which gets linked
    /// with the Module.
    c_object: *CObject,
};

pub const Export = struct {
    options: std.builtin.ExportOptions,
    /// Byte offset into the file that contains the export directive.
    src: usize,
    /// Represents the position of the export, if any, in the output file.
    link: link.File.Elf.Export,
    /// The Decl that performs the export. Note that this is *not* the Decl being exported.
    owner_decl: *Decl,
    /// The Decl being exported. Note this is *not* the Decl performing the export.
    exported_decl: *Decl,
    status: enum {
        in_progress,
        failed,
        /// Indicates that the failure was due to a temporary issue, such as an I/O error
        /// when writing to the output file. Retrying the export may succeed.
        failed_retryable,
        complete,
    },
};

pub const Decl = struct {
    /// This name is relative to the containing namespace of the decl. It uses a null-termination
    /// to save bytes, since there can be a lot of decls in a compilation. The null byte is not allowed
    /// in symbol names, because executable file formats use null-terminated strings for symbol names.
    /// All Decls have names, even values that are not bound to a zig namespace. This is necessary for
    /// mapping them to an address in the output file.
    /// Memory owned by this decl, using Module's allocator.
    name: [*:0]const u8,
    /// The direct parent container of the Decl. This is either a `Scope.Container` or `Scope.ZIRModule`.
    /// Reference to externally owned memory.
    scope: *Scope,
    /// The AST Node decl index or ZIR Inst index that contains this declaration.
    /// Must be recomputed when the corresponding source file is modified.
    src_index: usize,
    /// The most recent value of the Decl after a successful semantic analysis.
    typed_value: union(enum) {
        never_succeeded: void,
        most_recent: TypedValue.Managed,
    },
    /// Represents the "shallow" analysis status. For example, for decls that are functions,
    /// the function type is analyzed with this set to `in_progress`, however, the semantic
    /// analysis of the function body is performed with this value set to `success`. Functions
    /// have their own analysis status field.
    analysis: enum {
        /// This Decl corresponds to an AST Node that has not been referenced yet, and therefore
        /// because of Zig's lazy declaration analysis, it will remain unanalyzed until referenced.
        unreferenced,
        /// Semantic analysis for this Decl is running right now. This state detects dependency loops.
        in_progress,
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
    /// This flag is set when this Decl is added to a check_for_deletion set, and cleared
    /// when removed.
    deletion_flag: bool,
    /// Whether the corresponding AST decl has a `pub` keyword.
    is_pub: bool,

    /// An integer that can be checked against the corresponding incrementing
    /// generation field of Module. This is used to determine whether `complete` status
    /// represents pre- or post- re-analysis.
    generation: u32,

    /// Represents the position of the code in the output file.
    /// This is populated regardless of semantic analysis and code generation.
    link: link.File.LinkBlock,

    /// Represents the function in the linked output file, if the `Decl` is a function.
    /// This is stored here and not in `Fn` because `Decl` survives across updates but
    /// `Fn` does not.
    /// TODO Look into making `Fn` a longer lived structure and moving this field there
    /// to save on memory usage.
    fn_link: link.File.LinkFn,

    contents_hash: std.zig.SrcHash,

    /// The shallow set of other decls whose typed_value could possibly change if this Decl's
    /// typed_value is modified.
    dependants: DepsTable = .{},
    /// The shallow set of other decls whose typed_value changing indicates that this Decl's
    /// typed_value may need to be regenerated.
    dependencies: DepsTable = .{},

    /// The reason this is not `std.AutoArrayHashMapUnmanaged` is a workaround for
    /// stage1 compiler giving me: `error: struct 'Module.Decl' depends on itself`
    pub const DepsTable = std.ArrayHashMapUnmanaged(*Decl, void, std.array_hash_map.getAutoHashFn(*Decl), std.array_hash_map.getAutoEqlFn(*Decl), false);

    pub fn destroy(self: *Decl, gpa: *Allocator) void {
        gpa.free(mem.spanZ(self.name));
        if (self.typedValueManaged()) |tvm| {
            tvm.deinit(gpa);
        }
        self.dependants.deinit(gpa);
        self.dependencies.deinit(gpa);
        gpa.destroy(self);
    }

    pub fn src(self: Decl) usize {
        switch (self.scope.tag) {
            .container => {
                const container = @fieldParentPtr(Scope.Container, "base", self.scope);
                const tree = container.file_scope.contents.tree;
                // TODO Container should have it's own decls()
                const decl_node = tree.root_node.decls()[self.src_index];
                return tree.token_locs[decl_node.firstToken()].start;
            },
            .zir_module => {
                const zir_module = @fieldParentPtr(Scope.ZIRModule, "base", self.scope);
                const module = zir_module.contents.module;
                const src_decl = module.decls[self.src_index];
                return src_decl.inst.src;
            },
            .none => unreachable,
            .file, .block => unreachable,
            .gen_zir => unreachable,
            .local_val => unreachable,
            .local_ptr => unreachable,
            .decl => unreachable,
        }
    }

    pub fn fullyQualifiedNameHash(self: Decl) Scope.NameHash {
        return self.scope.fullyQualifiedNameHash(mem.spanZ(self.name));
    }

    pub fn typedValue(self: *Decl) error{AnalysisFail}!TypedValue {
        const tvm = self.typedValueManaged() orelse return error.AnalysisFail;
        return tvm.typed_value;
    }

    pub fn value(self: *Decl) error{AnalysisFail}!Value {
        return (try self.typedValue()).val;
    }

    pub fn dump(self: *Decl) void {
        const loc = std.zig.findLineColumn(self.scope.source.bytes, self.src);
        std.debug.print("{}:{}:{} name={} status={}", .{
            self.scope.sub_file_path,
            loc.line + 1,
            loc.column + 1,
            mem.spanZ(self.name),
            @tagName(self.analysis),
        });
        if (self.typedValueManaged()) |tvm| {
            std.debug.print(" ty={} val={}", .{ tvm.typed_value.ty, tvm.typed_value.val });
        }
        std.debug.print("\n", .{});
    }

    pub fn typedValueManaged(self: *Decl) ?*TypedValue.Managed {
        switch (self.typed_value) {
            .most_recent => |*x| return x,
            .never_succeeded => return null,
        }
    }

    fn removeDependant(self: *Decl, other: *Decl) void {
        self.dependants.removeAssertDiscard(other);
    }

    fn removeDependency(self: *Decl, other: *Decl) void {
        self.dependencies.removeAssertDiscard(other);
    }
};

pub const CObject = struct {
    /// Relative to cwd. Owned by arena.
    src_path: []const u8,
    /// Owned by arena.
    extra_flags: []const []const u8,
    arena: std.heap.ArenaAllocator.State,
    status: union(enum) {
        new,
        /// This is the output object path. Owned by gpa.
        success: []u8,
        /// There will be a corresponding ErrorMsg in Module.failed_c_objects.
        /// This is the C source file contents (used for printing error messages). Owned by gpa.
        failure: []u8,
    },

    pub fn destroy(self: *CObject, gpa: *Allocator) void {
        switch (self.status) {
            .new => {},
            .failure, .success => |data| gpa.free(data),
        }
        self.arena.promote(gpa).deinit();
    }
};

/// Fn struct memory is owned by the Decl's TypedValue.Managed arena allocator.
pub const Fn = struct {
    /// This memory owned by the Decl's TypedValue.Managed arena allocator.
    analysis: union(enum) {
        queued: *ZIR,
        in_progress,
        /// There will be a corresponding ErrorMsg in Module.failed_decls
        sema_failure,
        /// This Fn might be OK but it depends on another Decl which did not successfully complete
        /// semantic analysis.
        dependency_failure,
        success: Body,
    },
    owner_decl: *Decl,

    /// This memory is temporary and points to stack memory for the duration
    /// of Fn analysis.
    pub const Analysis = struct {
        inner_block: Scope.Block,
    };

    /// Contains un-analyzed ZIR instructions generated from Zig source AST.
    pub const ZIR = struct {
        body: zir.Module.Body,
        arena: std.heap.ArenaAllocator.State,
    };

    /// For debugging purposes.
    pub fn dump(self: *Fn, mod: Module) void {
        std.debug.print("Module.Function(name={}) ", .{self.owner_decl.name});
        switch (self.analysis) {
            .queued => {
                std.debug.print("queued\n", .{});
            },
            .in_progress => {
                std.debug.print("in_progress\n", .{});
            },
            else => {
                std.debug.print("\n", .{});
                zir.dumpFn(mod, self);
            },
        }
    }
};

pub const Var = struct {
    /// if is_extern == true this is undefined
    init: Value,
    owner_decl: *Decl,

    is_extern: bool,
    is_mutable: bool,
    is_threadlocal: bool,
};

pub const Scope = struct {
    tag: Tag,

    pub const NameHash = [16]u8;

    pub fn cast(base: *Scope, comptime T: type) ?*T {
        if (base.tag != T.base_tag)
            return null;

        return @fieldParentPtr(T, "base", base);
    }

    /// Asserts the scope has a parent which is a DeclAnalysis and
    /// returns the arena Allocator.
    pub fn arena(self: *Scope) *Allocator {
        switch (self.tag) {
            .block => return self.cast(Block).?.arena,
            .decl => return &self.cast(DeclAnalysis).?.arena.allocator,
            .gen_zir => return self.cast(GenZIR).?.arena,
            .local_val => return self.cast(LocalVal).?.gen_zir.arena,
            .local_ptr => return self.cast(LocalPtr).?.gen_zir.arena,
            .zir_module => return &self.cast(ZIRModule).?.contents.module.arena.allocator,
            .file => unreachable,
            .container => unreachable,
            .none => unreachable,
        }
    }

    /// If the scope has a parent which is a `DeclAnalysis`,
    /// returns the `Decl`, otherwise returns `null`.
    pub fn decl(self: *Scope) ?*Decl {
        return switch (self.tag) {
            .block => self.cast(Block).?.decl,
            .gen_zir => self.cast(GenZIR).?.decl,
            .local_val => self.cast(LocalVal).?.gen_zir.decl,
            .local_ptr => self.cast(LocalPtr).?.gen_zir.decl,
            .decl => self.cast(DeclAnalysis).?.decl,
            .zir_module => null,
            .file => null,
            .container => null,
            .none => unreachable,
        };
    }

    /// Asserts the scope has a parent which is a ZIRModule or Container and
    /// returns it.
    pub fn namespace(self: *Scope) *Scope {
        switch (self.tag) {
            .block => return self.cast(Block).?.decl.scope,
            .gen_zir => return self.cast(GenZIR).?.decl.scope,
            .local_val => return self.cast(LocalVal).?.gen_zir.decl.scope,
            .local_ptr => return self.cast(LocalPtr).?.gen_zir.decl.scope,
            .decl => return self.cast(DeclAnalysis).?.decl.scope,
            .file => return &self.cast(File).?.root_container.base,
            .zir_module, .container => return self,
            .none => unreachable,
        }
    }

    /// Must generate unique bytes with no collisions with other decls.
    /// The point of hashing here is only to limit the number of bytes of
    /// the unique identifier to a fixed size (16 bytes).
    pub fn fullyQualifiedNameHash(self: *Scope, name: []const u8) NameHash {
        switch (self.tag) {
            .block => unreachable,
            .gen_zir => unreachable,
            .local_val => unreachable,
            .local_ptr => unreachable,
            .decl => unreachable,
            .file => unreachable,
            .zir_module => return self.cast(ZIRModule).?.fullyQualifiedNameHash(name),
            .container => return self.cast(Container).?.fullyQualifiedNameHash(name),
            .none => unreachable,
        }
    }

    /// Asserts the scope is a child of a File and has an AST tree and returns the tree.
    pub fn tree(self: *Scope) *ast.Tree {
        switch (self.tag) {
            .file => return self.cast(File).?.contents.tree,
            .zir_module => unreachable,
            .none => unreachable,
            .decl => return self.cast(DeclAnalysis).?.decl.scope.cast(Container).?.file_scope.contents.tree,
            .block => return self.cast(Block).?.decl.scope.cast(Container).?.file_scope.contents.tree,
            .gen_zir => return self.cast(GenZIR).?.decl.scope.cast(Container).?.file_scope.contents.tree,
            .local_val => return self.cast(LocalVal).?.gen_zir.decl.scope.cast(Container).?.file_scope.contents.tree,
            .local_ptr => return self.cast(LocalPtr).?.gen_zir.decl.scope.cast(Container).?.file_scope.contents.tree,
            .container => return self.cast(Container).?.file_scope.contents.tree,
        }
    }

    /// Asserts the scope is a child of a `GenZIR` and returns it.
    pub fn getGenZIR(self: *Scope) *GenZIR {
        return switch (self.tag) {
            .block => unreachable,
            .gen_zir => self.cast(GenZIR).?,
            .local_val => return self.cast(LocalVal).?.gen_zir,
            .local_ptr => return self.cast(LocalPtr).?.gen_zir,
            .decl => unreachable,
            .zir_module => unreachable,
            .file => unreachable,
            .container => unreachable,
            .none => unreachable,
        };
    }

    /// Asserts the scope has a parent which is a ZIRModule, Contaienr or File and
    /// returns the sub_file_path field.
    pub fn subFilePath(base: *Scope) []const u8 {
        switch (base.tag) {
            .container => return @fieldParentPtr(Container, "base", base).file_scope.sub_file_path,
            .file => return @fieldParentPtr(File, "base", base).sub_file_path,
            .zir_module => return @fieldParentPtr(ZIRModule, "base", base).sub_file_path,
            .none => unreachable,
            .block => unreachable,
            .gen_zir => unreachable,
            .local_val => unreachable,
            .local_ptr => unreachable,
            .decl => unreachable,
        }
    }

    pub fn unload(base: *Scope, gpa: *Allocator) void {
        switch (base.tag) {
            .file => return @fieldParentPtr(File, "base", base).unload(gpa),
            .zir_module => return @fieldParentPtr(ZIRModule, "base", base).unload(gpa),
            .none => {},
            .block => unreachable,
            .gen_zir => unreachable,
            .local_val => unreachable,
            .local_ptr => unreachable,
            .decl => unreachable,
            .container => unreachable,
        }
    }

    pub fn getSource(base: *Scope, module: *Module) ![:0]const u8 {
        switch (base.tag) {
            .container => return @fieldParentPtr(Container, "base", base).file_scope.getSource(module),
            .file => return @fieldParentPtr(File, "base", base).getSource(module),
            .zir_module => return @fieldParentPtr(ZIRModule, "base", base).getSource(module),
            .none => unreachable,
            .gen_zir => unreachable,
            .local_val => unreachable,
            .local_ptr => unreachable,
            .block => unreachable,
            .decl => unreachable,
        }
    }

    /// Asserts the scope is a namespace Scope and removes the Decl from the namespace.
    pub fn removeDecl(base: *Scope, child: *Decl) void {
        switch (base.tag) {
            .container => return @fieldParentPtr(Container, "base", base).removeDecl(child),
            .zir_module => return @fieldParentPtr(ZIRModule, "base", base).removeDecl(child),
            .none => unreachable,
            .file => unreachable,
            .block => unreachable,
            .gen_zir => unreachable,
            .local_val => unreachable,
            .local_ptr => unreachable,
            .decl => unreachable,
        }
    }

    /// Asserts the scope is a File or ZIRModule and deinitializes it, then deallocates it.
    pub fn destroy(base: *Scope, gpa: *Allocator) void {
        switch (base.tag) {
            .file => {
                const scope_file = @fieldParentPtr(File, "base", base);
                scope_file.deinit(gpa);
                gpa.destroy(scope_file);
            },
            .zir_module => {
                const scope_zir_module = @fieldParentPtr(ZIRModule, "base", base);
                scope_zir_module.deinit(gpa);
                gpa.destroy(scope_zir_module);
            },
            .none => {
                const scope_none = @fieldParentPtr(None, "base", base);
                gpa.destroy(scope_none);
            },
            .block => unreachable,
            .gen_zir => unreachable,
            .local_val => unreachable,
            .local_ptr => unreachable,
            .decl => unreachable,
            .container => unreachable,
        }
    }

    fn name_hash_hash(x: NameHash) u32 {
        return @truncate(u32, @bitCast(u128, x));
    }

    fn name_hash_eql(a: NameHash, b: NameHash) bool {
        return @bitCast(u128, a) == @bitCast(u128, b);
    }

    pub const Tag = enum {
        /// .zir source code.
        zir_module,
        /// .zig source code.
        file,
        /// There is no .zig or .zir source code being compiled in this Module.
        none,
        /// struct, enum or union, every .file contains one of these.
        container,
        block,
        decl,
        gen_zir,
        local_val,
        local_ptr,
    };

    pub const Container = struct {
        pub const base_tag: Tag = .container;
        base: Scope = Scope{ .tag = base_tag },

        file_scope: *Scope.File,

        /// Direct children of the file.
        decls: std.AutoArrayHashMapUnmanaged(*Decl, void),

        // TODO implement container types and put this in a status union
        // ty: Type

        pub fn deinit(self: *Container, gpa: *Allocator) void {
            self.decls.deinit(gpa);
            self.* = undefined;
        }

        pub fn removeDecl(self: *Container, child: *Decl) void {
            _ = self.decls.remove(child);
        }

        pub fn fullyQualifiedNameHash(self: *Container, name: []const u8) NameHash {
            // TODO container scope qualified names.
            return std.zig.hashSrc(name);
        }
    };

    pub const File = struct {
        pub const base_tag: Tag = .file;
        base: Scope = Scope{ .tag = base_tag },

        /// Relative to the owning package's root_src_dir.
        /// Reference to external memory, not owned by File.
        sub_file_path: []const u8,
        source: union(enum) {
            unloaded: void,
            bytes: [:0]const u8,
        },
        contents: union {
            not_available: void,
            tree: *ast.Tree,
        },
        status: enum {
            never_loaded,
            unloaded_success,
            unloaded_parse_failure,
            loaded_success,
        },

        root_container: Container,

        pub fn unload(self: *File, gpa: *Allocator) void {
            switch (self.status) {
                .never_loaded,
                .unloaded_parse_failure,
                .unloaded_success,
                => {},

                .loaded_success => {
                    self.contents.tree.deinit();
                    self.status = .unloaded_success;
                },
            }
            switch (self.source) {
                .bytes => |bytes| {
                    gpa.free(bytes);
                    self.source = .{ .unloaded = {} };
                },
                .unloaded => {},
            }
        }

        pub fn deinit(self: *File, gpa: *Allocator) void {
            self.root_container.deinit(gpa);
            self.unload(gpa);
            self.* = undefined;
        }

        pub fn dumpSrc(self: *File, src: usize) void {
            const loc = std.zig.findLineColumn(self.source.bytes, src);
            std.debug.print("{}:{}:{}\n", .{ self.sub_file_path, loc.line + 1, loc.column + 1 });
        }

        pub fn getSource(self: *File, module: *Module) ![:0]const u8 {
            switch (self.source) {
                .unloaded => {
                    const source = try module.root_pkg.?.root_src_dir.readFileAllocOptions(
                        module.gpa,
                        self.sub_file_path,
                        std.math.maxInt(u32),
                        null,
                        1,
                        0,
                    );
                    self.source = .{ .bytes = source };
                    return source;
                },
                .bytes => |bytes| return bytes,
            }
        }
    };

    /// For when there is no top level scope because there are no .zig files being compiled.
    pub const None = struct {
        pub const base_tag: Tag = .none;
        base: Scope = Scope{ .tag = base_tag },
    };

    pub const ZIRModule = struct {
        pub const base_tag: Tag = .zir_module;
        base: Scope = Scope{ .tag = base_tag },
        /// Relative to the owning package's root_src_dir.
        /// Reference to external memory, not owned by ZIRModule.
        sub_file_path: []const u8,
        source: union(enum) {
            unloaded: void,
            bytes: [:0]const u8,
        },
        contents: union {
            not_available: void,
            module: *zir.Module,
        },
        status: enum {
            never_loaded,
            unloaded_success,
            unloaded_parse_failure,
            unloaded_sema_failure,

            loaded_sema_failure,
            loaded_success,
        },

        /// Even though .zir files only have 1 module, this set is still needed
        /// because of anonymous Decls, which can exist in the global set, but
        /// not this one.
        decls: ArrayListUnmanaged(*Decl),

        pub fn unload(self: *ZIRModule, gpa: *Allocator) void {
            switch (self.status) {
                .never_loaded,
                .unloaded_parse_failure,
                .unloaded_sema_failure,
                .unloaded_success,
                => {},

                .loaded_success => {
                    self.contents.module.deinit(gpa);
                    gpa.destroy(self.contents.module);
                    self.contents = .{ .not_available = {} };
                    self.status = .unloaded_success;
                },
                .loaded_sema_failure => {
                    self.contents.module.deinit(gpa);
                    gpa.destroy(self.contents.module);
                    self.contents = .{ .not_available = {} };
                    self.status = .unloaded_sema_failure;
                },
            }
            switch (self.source) {
                .bytes => |bytes| {
                    gpa.free(bytes);
                    self.source = .{ .unloaded = {} };
                },
                .unloaded => {},
            }
        }

        pub fn deinit(self: *ZIRModule, gpa: *Allocator) void {
            self.decls.deinit(gpa);
            self.unload(gpa);
            self.* = undefined;
        }

        pub fn removeDecl(self: *ZIRModule, child: *Decl) void {
            for (self.decls.items) |item, i| {
                if (item == child) {
                    _ = self.decls.swapRemove(i);
                    return;
                }
            }
        }

        pub fn dumpSrc(self: *ZIRModule, src: usize) void {
            const loc = std.zig.findLineColumn(self.source.bytes, src);
            std.debug.print("{}:{}:{}\n", .{ self.sub_file_path, loc.line + 1, loc.column + 1 });
        }

        pub fn getSource(self: *ZIRModule, module: *Module) ![:0]const u8 {
            switch (self.source) {
                .unloaded => {
                    const source = try module.root_pkg.?.root_src_dir.readFileAllocOptions(
                        module.gpa,
                        self.sub_file_path,
                        std.math.maxInt(u32),
                        null,
                        1,
                        0,
                    );
                    self.source = .{ .bytes = source };
                    return source;
                },
                .bytes => |bytes| return bytes,
            }
        }

        pub fn fullyQualifiedNameHash(self: *ZIRModule, name: []const u8) NameHash {
            // ZIR modules only have 1 file with all decls global in the same namespace.
            return std.zig.hashSrc(name);
        }
    };

    /// This is a temporary structure, references to it are valid only
    /// during semantic analysis of the block.
    pub const Block = struct {
        pub const base_tag: Tag = .block;
        base: Scope = Scope{ .tag = base_tag },
        parent: ?*Block,
        func: ?*Fn,
        decl: *Decl,
        instructions: ArrayListUnmanaged(*Inst),
        /// Points to the arena allocator of DeclAnalysis
        arena: *Allocator,
        label: ?Label = null,
        is_comptime: bool,

        pub const Label = struct {
            zir_block: *zir.Inst.Block,
            results: ArrayListUnmanaged(*Inst),
            block_inst: *Inst.Block,
        };
    };

    /// This is a temporary structure, references to it are valid only
    /// during semantic analysis of the decl.
    pub const DeclAnalysis = struct {
        pub const base_tag: Tag = .decl;
        base: Scope = Scope{ .tag = base_tag },
        decl: *Decl,
        arena: std.heap.ArenaAllocator,
    };

    /// This is a temporary structure, references to it are valid only
    /// during semantic analysis of the decl.
    pub const GenZIR = struct {
        pub const base_tag: Tag = .gen_zir;
        base: Scope = Scope{ .tag = base_tag },
        /// Parents can be: `GenZIR`, `ZIRModule`, `File`
        parent: *Scope,
        decl: *Decl,
        arena: *Allocator,
        /// The first N instructions in a function body ZIR are arg instructions.
        instructions: std.ArrayListUnmanaged(*zir.Inst) = .{},
        label: ?Label = null,

        pub const Label = struct {
            token: ast.TokenIndex,
            block_inst: *zir.Inst.Block,
            result_loc: astgen.ResultLoc,
        };
    };

    /// This is always a `const` local and importantly the `inst` is a value type, not a pointer.
    /// This structure lives as long as the AST generation of the Block
    /// node that contains the variable.
    pub const LocalVal = struct {
        pub const base_tag: Tag = .local_val;
        base: Scope = Scope{ .tag = base_tag },
        /// Parents can be: `LocalVal`, `LocalPtr`, `GenZIR`.
        parent: *Scope,
        gen_zir: *GenZIR,
        name: []const u8,
        inst: *zir.Inst,
    };

    /// This could be a `const` or `var` local. It has a pointer instead of a value.
    /// This structure lives as long as the AST generation of the Block
    /// node that contains the variable.
    pub const LocalPtr = struct {
        pub const base_tag: Tag = .local_ptr;
        base: Scope = Scope{ .tag = base_tag },
        /// Parents can be: `LocalVal`, `LocalPtr`, `GenZIR`.
        parent: *Scope,
        gen_zir: *GenZIR,
        name: []const u8,
        ptr: *zir.Inst,
    };
};

pub const AllErrors = struct {
    arena: std.heap.ArenaAllocator.State,
    list: []const Message,

    pub const Message = struct {
        src_path: []const u8,
        line: usize,
        column: usize,
        byte_offset: usize,
        msg: []const u8,
    };

    pub fn deinit(self: *AllErrors, gpa: *Allocator) void {
        self.arena.promote(gpa).deinit();
    }

    fn add(
        arena: *std.heap.ArenaAllocator,
        errors: *std.ArrayList(Message),
        sub_file_path: []const u8,
        source: []const u8,
        simple_err_msg: ErrorMsg,
    ) !void {
        const loc = std.zig.findLineColumn(source, simple_err_msg.byte_offset);
        try errors.append(.{
            .src_path = try arena.allocator.dupe(u8, sub_file_path),
            .msg = try arena.allocator.dupe(u8, simple_err_msg.msg),
            .byte_offset = simple_err_msg.byte_offset,
            .line = loc.line,
            .column = loc.column,
        });
    }
};

pub const InitOptions = struct {
    zig_lib_dir: []const u8,
    target: Target,
    root_name: []const u8,
    root_pkg: ?*Package,
    output_mode: std.builtin.OutputMode,
    rand: *std.rand.Random,
    dynamic_linker: ?[]const u8 = null,
    bin_file_dir_path: ?[]const u8 = null,
    bin_file_dir: ?std.fs.Dir = null,
    bin_file_path: []const u8,
    emit_h: ?[]const u8 = null,
    link_mode: ?std.builtin.LinkMode = null,
    object_format: ?std.builtin.ObjectFormat = null,
    optimize_mode: std.builtin.Mode = .Debug,
    keep_source_files_loaded: bool = false,
    clang_argv: []const []const u8 = &[0][]const u8{},
    lld_argv: []const []const u8 = &[0][]const u8{},
    lib_dirs: []const []const u8 = &[0][]const u8{},
    rpath_list: []const []const u8 = &[0][]const u8{},
    c_source_files: []const []const u8 = &[0][]const u8{},
    link_objects: []const []const u8 = &[0][]const u8{},
    framework_dirs: []const []const u8 = &[0][]const u8{},
    frameworks: []const []const u8 = &[0][]const u8{},
    system_libs: []const []const u8 = &[0][]const u8{},
    link_libc: bool = false,
    link_libcpp: bool = false,
    want_pic: ?bool = null,
    want_sanitize_c: ?bool = null,
    use_llvm: ?bool = null,
    use_lld: ?bool = null,
    use_clang: ?bool = null,
    rdynamic: bool = false,
    strip: bool = false,
    is_native_os: bool,
    link_eh_frame_hdr: bool = false,
    linker_script: ?[]const u8 = null,
    version_script: ?[]const u8 = null,
    override_soname: ?[]const u8 = null,
    linker_gc_sections: ?bool = null,
    function_sections: ?bool = null,
    linker_allow_shlib_undefined: ?bool = null,
    linker_bind_global_refs_locally: ?bool = null,
    disable_c_depfile: bool = false,
    linker_z_nodelete: bool = false,
    linker_z_defs: bool = false,
    clang_passthrough_mode: bool = false,
    stack_size_override: ?u64 = null,
    self_exe_path: ?[]const u8 = null,
    version: std.builtin.Version = .{ .major = 0, .minor = 0, .patch = 0 },
    libc_installation: ?*const LibCInstallation = null,
};

pub fn create(gpa: *Allocator, options: InitOptions) !*Module {
    const mod: *Module = mod: {
        // For allocations that have the same lifetime as Module. This arena is used only during this
        // initialization and then is freed in deinit().
        var arena_allocator = std.heap.ArenaAllocator.init(gpa);
        errdefer arena_allocator.deinit();
        const arena = &arena_allocator.allocator;

        // We put the `Module` itself in the arena. Freeing the arena will free the module.
        // It's initialized later after we prepare the initialization options.
        const mod = try arena.create(Module);
        const root_name = try arena.dupe(u8, options.root_name);

        const ofmt = options.object_format orelse options.target.getObjectFormat();

        // Make a decision on whether to use LLD or our own linker.
        const use_lld = if (options.use_lld) |explicit| explicit else blk: {
            if (!build_options.have_llvm)
                break :blk false;

            if (ofmt == .c)
                break :blk false;

            // Our linker can't handle objects or most advanced options yet.
            if (options.link_objects.len != 0 or
                options.c_source_files.len != 0 or
                options.frameworks.len != 0 or
                options.system_libs.len != 0 or
                options.link_libc or options.link_libcpp or
                options.link_eh_frame_hdr or
                options.linker_script != null or options.version_script != null)
            {
                break :blk true;
            }
            break :blk false;
        };

        // Make a decision on whether to use LLVM or our own backend.
        const use_llvm = if (options.use_llvm) |explicit| explicit else blk: {
            // We would want to prefer LLVM for release builds when it is available, however
            // we don't have an LLVM backend yet :)
            // We would also want to prefer LLVM for architectures that we don't have self-hosted support for too.
            break :blk false;
        };

        const must_dynamic_link = dl: {
            if (target_util.cannotDynamicLink(options.target))
                break :dl false;
            if (target_util.osRequiresLibC(options.target))
                break :dl true;
            if (options.link_libc and options.target.isGnuLibC())
                break :dl true;
            if (options.system_libs.len != 0)
                break :dl true;

            break :dl false;
        };
        const default_link_mode: std.builtin.LinkMode = if (must_dynamic_link) .Dynamic else .Static;
        const link_mode: std.builtin.LinkMode = if (options.link_mode) |lm| blk: {
            if (lm == .Static and must_dynamic_link) {
                return error.UnableToStaticLink;
            }
            break :blk lm;
        } else default_link_mode;

        const libc_dirs = try detectLibCIncludeDirs(
            arena,
            options.zig_lib_dir,
            options.target,
            options.is_native_os,
            options.link_libc,
            options.libc_installation,
        );

        const bin_file = try link.File.openPath(gpa, .{
            .dir = options.bin_file_dir orelse std.fs.cwd(),
            .dir_path = options.bin_file_dir_path,
            .sub_path = options.bin_file_path,
            .root_name = root_name,
            .root_pkg = options.root_pkg,
            .target = options.target,
            .dynamic_linker = options.dynamic_linker,
            .output_mode = options.output_mode,
            .link_mode = link_mode,
            .object_format = ofmt,
            .optimize_mode = options.optimize_mode,
            .use_lld = use_lld,
            .use_llvm = use_llvm,
            .link_libc = options.link_libc,
            .link_libcpp = options.link_libcpp,
            .objects = options.link_objects,
            .frameworks = options.frameworks,
            .framework_dirs = options.framework_dirs,
            .system_libs = options.system_libs,
            .lib_dirs = options.lib_dirs,
            .rpath_list = options.rpath_list,
            .strip = options.strip,
            .is_native_os = options.is_native_os,
            .function_sections = options.function_sections orelse false,
            .allow_shlib_undefined = options.linker_allow_shlib_undefined,
            .bind_global_refs_locally = options.linker_bind_global_refs_locally orelse false,
            .z_nodelete = options.linker_z_nodelete,
            .z_defs = options.linker_z_defs,
            .stack_size_override = options.stack_size_override,
            .linker_script = options.linker_script,
            .version_script = options.version_script,
            .gc_sections = options.linker_gc_sections,
            .eh_frame_hdr = options.link_eh_frame_hdr,
            .rdynamic = options.rdynamic,
            .extra_lld_args = options.lld_argv,
            .override_soname = options.override_soname,
            .version = options.version,
            .libc_installation = libc_dirs.libc_installation,
        });
        errdefer bin_file.destroy();

        // We arena-allocate the root scope so there is no free needed.
        const root_scope = blk: {
            if (options.root_pkg) |root_pkg| {
                if (mem.endsWith(u8, root_pkg.root_src_path, ".zig")) {
                    const root_scope = try gpa.create(Scope.File);
                    root_scope.* = .{
                        .sub_file_path = root_pkg.root_src_path,
                        .source = .{ .unloaded = {} },
                        .contents = .{ .not_available = {} },
                        .status = .never_loaded,
                        .root_container = .{
                            .file_scope = root_scope,
                            .decls = .{},
                        },
                    };
                    break :blk &root_scope.base;
                } else if (mem.endsWith(u8, root_pkg.root_src_path, ".zir")) {
                    const root_scope = try gpa.create(Scope.ZIRModule);
                    root_scope.* = .{
                        .sub_file_path = root_pkg.root_src_path,
                        .source = .{ .unloaded = {} },
                        .contents = .{ .not_available = {} },
                        .status = .never_loaded,
                        .decls = .{},
                    };
                    break :blk &root_scope.base;
                } else {
                    unreachable;
                }
            } else {
                const root_scope = try gpa.create(Scope.None);
                root_scope.* = .{};
                break :blk &root_scope.base;
            }
        };

        // We put everything into the cache hash except for the root source file, because we want to
        // find the same binary and incrementally update it even if the file contents changed.
        // TODO Look into storing this information in memory rather than on disk and solving
        // serialization/deserialization of *all* incremental compilation state in a more generic way.
        const cache_parent_dir = if (options.root_pkg) |root_pkg| root_pkg.root_src_dir else std.fs.cwd();
        var cache_dir = try cache_parent_dir.makeOpenPath("zig-cache", .{});
        defer cache_dir.close();

        try cache_dir.makePath("tmp");
        try cache_dir.makePath("o");
        // We need this string because of sending paths to clang as a child process.
        const zig_cache_dir_path = if (options.root_pkg) |root_pkg|
            try std.fmt.allocPrint(arena, "{}" ++ std.fs.path.sep_str ++ "zig-cache", .{root_pkg.root_src_dir_path})
        else
            "zig-cache";

        var cache = try std.cache_hash.CacheHash.init(gpa, cache_dir, "h");
        errdefer cache.release();

        // Now we will prepare hash state initializations to avoid redundantly computing hashes.
        // First we add common things between things that apply to zig source and all c source files.
        cache.addBytes(build_options.version);
        cache.add(options.optimize_mode);
        cache.add(options.target.cpu.arch);
        cache.addBytes(options.target.cpu.model.name);
        cache.add(options.target.cpu.features.ints);
        cache.add(options.target.os.tag);
        switch (options.target.os.tag) {
            .linux => {
                cache.add(options.target.os.version_range.linux.range.min);
                cache.add(options.target.os.version_range.linux.range.max);
                cache.add(options.target.os.version_range.linux.glibc);
            },
            .windows => {
                cache.add(options.target.os.version_range.windows.min);
                cache.add(options.target.os.version_range.windows.max);
            },
            .freebsd,
            .macosx,
            .ios,
            .tvos,
            .watchos,
            .netbsd,
            .openbsd,
            .dragonfly,
            => {
                cache.add(options.target.os.version_range.semver.min);
                cache.add(options.target.os.version_range.semver.max);
            },
            else => {},
        }
        cache.add(options.target.abi);
        cache.add(ofmt);
        // TODO PIC (see detect_pic from codegen.cpp)
        cache.add(bin_file.options.link_mode);
        cache.add(options.strip);

        // Make a decision on whether to use Clang for translate-c and compiling C files.
        const use_clang = if (options.use_clang) |explicit| explicit else blk: {
            if (build_options.have_llvm) {
                // Can't use it if we don't have it!
                break :blk false;
            }
            // It's not planned to do our own translate-c or C compilation.
            break :blk true;
        };

        const sanitize_c: bool = options.want_sanitize_c orelse switch (options.optimize_mode) {
            .Debug, .ReleaseSafe => true,
            .ReleaseSmall, .ReleaseFast => false,
        };

        mod.* = .{
            .gpa = gpa,
            .arena_state = arena_allocator.state,
            .zig_lib_dir = options.zig_lib_dir,
            .zig_cache_dir_path = zig_cache_dir_path,
            .root_pkg = options.root_pkg,
            .root_scope = root_scope,
            .bin_file = bin_file,
            .work_queue = std.fifo.LinearFifo(WorkItem, .Dynamic).init(gpa),
            .keep_source_files_loaded = options.keep_source_files_loaded,
            .use_clang = use_clang,
            .clang_argv = options.clang_argv,
            .c_source_files = options.c_source_files,
            .cache = cache,
            .self_exe_path = options.self_exe_path,
            .libc_include_dir_list = libc_dirs.libc_include_dir_list,
            .sanitize_c = sanitize_c,
            .rand = options.rand,
            .clang_passthrough_mode = options.clang_passthrough_mode,
        };
        break :mod mod;
    };
    errdefer mod.destroy();

    // Add a `CObject` for each `c_source_files`.
    try mod.c_object_table.ensureCapacity(gpa, options.c_source_files.len);
    for (options.c_source_files) |c_source_file| {
        var local_arena = std.heap.ArenaAllocator.init(gpa);
        errdefer local_arena.deinit();

        const c_object = try local_arena.allocator.create(CObject);
        const src_path = try local_arena.allocator.dupe(u8, c_source_file);

        c_object.* = .{
            .status = .{ .new = {} },
            .src_path = src_path,
            .extra_flags = &[0][]const u8{},
            .arena = local_arena.state,
        };
        mod.c_object_table.putAssumeCapacityNoClobber(c_object, {});
    }

    return mod;
}

pub fn destroy(self: *Module) void {
    self.bin_file.destroy();
    const gpa = self.gpa;
    self.deletion_set.deinit(gpa);
    self.work_queue.deinit();

    for (self.decl_table.items()) |entry| {
        entry.value.destroy(gpa);
    }
    self.decl_table.deinit(gpa);

    for (self.c_object_table.items()) |entry| {
        entry.key.destroy(gpa);
    }
    self.c_object_table.deinit(gpa);

    for (self.failed_decls.items()) |entry| {
        entry.value.destroy(gpa);
    }
    self.failed_decls.deinit(gpa);

    for (self.failed_c_objects.items()) |entry| {
        entry.value.destroy(gpa);
    }
    self.failed_c_objects.deinit(gpa);

    for (self.failed_files.items()) |entry| {
        entry.value.destroy(gpa);
    }
    self.failed_files.deinit(gpa);

    for (self.failed_exports.items()) |entry| {
        entry.value.destroy(gpa);
    }
    self.failed_exports.deinit(gpa);

    for (self.decl_exports.items()) |entry| {
        const export_list = entry.value;
        gpa.free(export_list);
    }
    self.decl_exports.deinit(gpa);

    for (self.export_owners.items()) |entry| {
        freeExportList(gpa, entry.value);
    }
    self.export_owners.deinit(gpa);

    self.symbol_exports.deinit(gpa);
    self.root_scope.destroy(gpa);

    var it = self.global_error_set.iterator();
    while (it.next()) |entry| {
        gpa.free(entry.key);
    }
    self.global_error_set.deinit(gpa);
    self.cache.release();

    // This destroys `self`.
    self.arena_state.promote(gpa).deinit();
}

fn freeExportList(gpa: *Allocator, export_list: []*Export) void {
    for (export_list) |exp| {
        gpa.free(exp.options.name);
        gpa.destroy(exp);
    }
    gpa.free(export_list);
}

pub fn getTarget(self: Module) Target {
    return self.bin_file.options.target;
}

pub fn optimizeMode(self: Module) std.builtin.Mode {
    return self.bin_file.options.optimize_mode;
}

/// Detect changes to source files, perform semantic analysis, and update the output files.
pub fn update(self: *Module) !void {
    const tracy = trace(@src());
    defer tracy.end();

    self.generation += 1;

    // For compiling C objects, we rely on the cache hash system to avoid duplicating work.
    // TODO Look into caching this data in memory to improve performance.
    // Add a WorkItem for each C object.
    try self.work_queue.ensureUnusedCapacity(self.c_object_table.items().len);
    for (self.c_object_table.items()) |entry| {
        self.work_queue.writeItemAssumeCapacity(.{ .c_object = entry.key });
    }

    // TODO Detect which source files changed.
    // Until then we simulate a full cache miss. Source files could have been loaded for any reason;
    // to force a refresh we unload now.
    if (self.root_scope.cast(Scope.File)) |zig_file| {
        zig_file.unload(self.gpa);
        self.analyzeContainer(&zig_file.root_container) catch |err| switch (err) {
            error.AnalysisFail => {
                assert(self.totalErrorCount() != 0);
            },
            else => |e| return e,
        };
    } else if (self.root_scope.cast(Scope.ZIRModule)) |zir_module| {
        zir_module.unload(self.gpa);
        self.analyzeRootZIRModule(zir_module) catch |err| switch (err) {
            error.AnalysisFail => {
                assert(self.totalErrorCount() != 0);
            },
            else => |e| return e,
        };
    }

    try self.performAllTheWork();

    // Process the deletion set.
    while (self.deletion_set.popOrNull()) |decl| {
        if (decl.dependants.items().len != 0) {
            decl.deletion_flag = false;
            continue;
        }
        try self.deleteDecl(decl);
    }

    // This is needed before reading the error flags.
    try self.bin_file.flush(self);

    self.link_error_flags = self.bin_file.errorFlags();

    // If there are any errors, we anticipate the source files being loaded
    // to report error messages. Otherwise we unload all source files to save memory.
    if (self.totalErrorCount() == 0 and !self.keep_source_files_loaded) {
        self.root_scope.unload(self.gpa);
    }
}

/// Having the file open for writing is problematic as far as executing the
/// binary is concerned. This will remove the write flag, or close the file,
/// or whatever is needed so that it can be executed.
/// After this, one must call` makeFileWritable` before calling `update`.
pub fn makeBinFileExecutable(self: *Module) !void {
    return self.bin_file.makeExecutable();
}

pub fn makeBinFileWritable(self: *Module) !void {
    return self.bin_file.makeWritable();
}

pub fn totalErrorCount(self: *Module) usize {
    const total = self.failed_decls.items().len +
        self.failed_c_objects.items().len +
        self.failed_files.items().len +
        self.failed_exports.items().len;
    return if (total == 0) @boolToInt(self.link_error_flags.no_entry_point_found) else total;
}

pub fn getAllErrorsAlloc(self: *Module) !AllErrors {
    var arena = std.heap.ArenaAllocator.init(self.gpa);
    errdefer arena.deinit();

    var errors = std.ArrayList(AllErrors.Message).init(self.gpa);
    defer errors.deinit();

    for (self.failed_c_objects.items()) |entry| {
        const c_object = entry.key;
        const err_msg = entry.value;
        const source = c_object.status.failure;
        try AllErrors.add(&arena, &errors, c_object.src_path, source, err_msg.*);
    }
    for (self.failed_files.items()) |entry| {
        const scope = entry.key;
        const err_msg = entry.value;
        const source = try scope.getSource(self);
        try AllErrors.add(&arena, &errors, scope.subFilePath(), source, err_msg.*);
    }
    for (self.failed_decls.items()) |entry| {
        const decl = entry.key;
        const err_msg = entry.value;
        const source = try decl.scope.getSource(self);
        try AllErrors.add(&arena, &errors, decl.scope.subFilePath(), source, err_msg.*);
    }
    for (self.failed_exports.items()) |entry| {
        const decl = entry.key.owner_decl;
        const err_msg = entry.value;
        const source = try decl.scope.getSource(self);
        try AllErrors.add(&arena, &errors, decl.scope.subFilePath(), source, err_msg.*);
    }

    if (errors.items.len == 0 and self.link_error_flags.no_entry_point_found) {
        const global_err_src_path = blk: {
            if (self.root_pkg) |root_pkg| break :blk root_pkg.root_src_path;
            if (self.c_source_files.len != 0) break :blk self.c_source_files[0];
            if (self.bin_file.options.objects.len != 0) break :blk self.bin_file.options.objects[0];
            break :blk "(no file)";
        };
        try errors.append(.{
            .src_path = global_err_src_path,
            .line = 0,
            .column = 0,
            .byte_offset = 0,
            .msg = try std.fmt.allocPrint(&arena.allocator, "no entry point found", .{}),
        });
    }

    assert(errors.items.len == self.totalErrorCount());

    return AllErrors{
        .list = try arena.allocator.dupe(AllErrors.Message, errors.items),
        .arena = arena.state,
    };
}

pub fn performAllTheWork(self: *Module) error{OutOfMemory}!void {
    while (self.work_queue.readItem()) |work_item| switch (work_item) {
        .codegen_decl => |decl| switch (decl.analysis) {
            .unreferenced => unreachable,
            .in_progress => unreachable,
            .outdated => unreachable,

            .sema_failure,
            .codegen_failure,
            .dependency_failure,
            .sema_failure_retryable,
            => continue,

            .complete, .codegen_failure_retryable => {
                if (decl.typed_value.most_recent.typed_value.val.cast(Value.Payload.Function)) |payload| {
                    switch (payload.func.analysis) {
                        .queued => self.analyzeFnBody(decl, payload.func) catch |err| switch (err) {
                            error.AnalysisFail => {
                                assert(payload.func.analysis != .in_progress);
                                continue;
                            },
                            error.OutOfMemory => return error.OutOfMemory,
                        },
                        .in_progress => unreachable,
                        .sema_failure, .dependency_failure => continue,
                        .success => {},
                    }
                    // Here we tack on additional allocations to the Decl's arena. The allocations are
                    // lifetime annotations in the ZIR.
                    var decl_arena = decl.typed_value.most_recent.arena.?.promote(self.gpa);
                    defer decl.typed_value.most_recent.arena.?.* = decl_arena.state;
                    log.debug("analyze liveness of {}\n", .{decl.name});
                    try liveness.analyze(self.gpa, &decl_arena.allocator, payload.func.analysis.success);
                }

                assert(decl.typed_value.most_recent.typed_value.ty.hasCodeGenBits());

                self.bin_file.updateDecl(self, decl) catch |err| switch (err) {
                    error.OutOfMemory => return error.OutOfMemory,
                    error.AnalysisFail => {
                        decl.analysis = .dependency_failure;
                    },
                    else => {
                        try self.failed_decls.ensureCapacity(self.gpa, self.failed_decls.items().len + 1);
                        self.failed_decls.putAssumeCapacityNoClobber(decl, try ErrorMsg.create(
                            self.gpa,
                            decl.src(),
                            "unable to codegen: {}",
                            .{@errorName(err)},
                        ));
                        decl.analysis = .codegen_failure_retryable;
                    },
                };
            },
        },
        .analyze_decl => |decl| {
            self.ensureDeclAnalyzed(decl) catch |err| switch (err) {
                error.OutOfMemory => return error.OutOfMemory,
                error.AnalysisFail => continue,
            };
        },
        .update_line_number => |decl| {
            self.bin_file.updateDeclLineNumber(self, decl) catch |err| {
                try self.failed_decls.ensureCapacity(self.gpa, self.failed_decls.items().len + 1);
                self.failed_decls.putAssumeCapacityNoClobber(decl, try ErrorMsg.create(
                    self.gpa,
                    decl.src(),
                    "unable to update line number: {}",
                    .{@errorName(err)},
                ));
                decl.analysis = .codegen_failure_retryable;
            };
        },
        .c_object => |c_object| {
            // Free the previous attempt.
            switch (c_object.status) {
                .new => {},
                .success => |o_file_path| {
                    self.gpa.free(o_file_path);
                    c_object.status = .{ .new = {} };
                },
                .failure => |source| {
                    self.failed_c_objects.removeAssertDiscard(c_object);
                    self.gpa.free(source);

                    c_object.status = .{ .new = {} };
                },
            }
            self.buildCObject(c_object) catch |err| switch (err) {
                error.AnalysisFail => continue,
                else => {
                    try self.failed_c_objects.ensureCapacity(self.gpa, self.failed_c_objects.items().len + 1);
                    self.failed_c_objects.putAssumeCapacityNoClobber(c_object, try ErrorMsg.create(
                        self.gpa,
                        0,
                        "unable to build C object: {}",
                        .{@errorName(err)},
                    ));
                    c_object.status = .{ .failure = "" };
                },
            };
        },
    };
}

fn buildCObject(mod: *Module, c_object: *CObject) !void {
    const tracy = trace(@src());
    defer tracy.end();

    if (!build_options.have_llvm) {
        return mod.failCObj(c_object, "clang not available: compiler not built with LLVM extensions enabled", .{});
    }
    const self_exe_path = mod.self_exe_path orelse
        return mod.failCObj(c_object, "clang compilation disabled", .{});

    var arena_allocator = std.heap.ArenaAllocator.init(mod.gpa);
    defer arena_allocator.deinit();
    const arena = &arena_allocator.allocator;

    var argv = std.ArrayList([]const u8).init(mod.gpa);
    defer argv.deinit();

    const c_source_basename = std.fs.path.basename(c_object.src_path);
    // Special case when doing build-obj for just one C file. When there are more than one object
    // file and building an object we need to link them together, but with just one it should go
    // directly to the output file.
    const direct_o = mod.c_source_files.len == 1 and mod.root_pkg == null and
        mod.bin_file.options.output_mode == .Obj and mod.bin_file.options.objects.len == 0;
    const o_basename_noext = if (direct_o)
        mod.bin_file.options.root_name
    else
        mem.split(c_source_basename, ".").next().?;
    const o_basename = try std.fmt.allocPrint(arena, "{}{}", .{ o_basename_noext, mod.getTarget().oFileExt() });

    // We can't know the digest until we do the C compiler invocation, so we need a temporary filename.
    const out_obj_path = try mod.tmpFilePath(arena, o_basename);

    try argv.appendSlice(&[_][]const u8{ self_exe_path, "clang", "-c" });

    const ext = classifyFileExt(c_object.src_path);
    // TODO capture the .d file and deal with caching stuff
    try mod.addCCArgs(arena, &argv, ext, false, null);

    try argv.append("-o");
    try argv.append(out_obj_path);

    try argv.append(c_object.src_path);
    try argv.appendSlice(c_object.extra_flags);

    //for (argv.items) |arg| {
    //    std.debug.print("{} ", .{arg});
    //}

    const child = try std.ChildProcess.init(argv.items, arena);
    defer child.deinit();

    if (mod.clang_passthrough_mode) {
        child.stdin_behavior = .Inherit;
        child.stdout_behavior = .Inherit;
        child.stderr_behavior = .Inherit;

        const term = child.spawnAndWait() catch |err| {
            return mod.failCObj(c_object, "unable to spawn {}: {}", .{ argv.items[0], @errorName(err) });
        };
        switch (term) {
            .Exited => |code| {
                if (code != 0) {
                    // TODO make std.process.exit and std.ChildProcess exit code have the same type
                    // and forward it here. Currently it is u32 vs u8.
                    std.process.exit(1);
                }
            },
            else => std.process.exit(1),
        }
    } else {
        child.stdin_behavior = .Ignore;
        child.stdout_behavior = .Pipe;
        child.stderr_behavior = .Pipe;

        try child.spawn();

        const stdout_reader = child.stdout.?.reader();
        const stderr_reader = child.stderr.?.reader();

        // TODO Need to poll to read these streams to prevent a deadlock (or rely on evented I/O).
        const stdout = try stdout_reader.readAllAlloc(arena, std.math.maxInt(u32));
        const stderr = try stderr_reader.readAllAlloc(arena, 10 * 1024 * 1024);

        const term = child.wait() catch |err| {
            return mod.failCObj(c_object, "unable to spawn {}: {}", .{ argv.items[0], @errorName(err) });
        };

        switch (term) {
            .Exited => |code| {
                if (code != 0) {
                    // TODO parse clang stderr and turn it into an error message
                    // and then call failCObjWithOwnedErrorMsg
                    std.log.err("clang failed with stderr: {}", .{stderr});
                    return mod.failCObj(c_object, "clang exited with code {}", .{code});
                }
            },
            else => {
                std.log.err("clang terminated with stderr: {}", .{stderr});
                return mod.failCObj(c_object, "clang terminated unexpectedly", .{});
            },
        }
    }

    // TODO handle .d files

    // TODO rename into place
    std.debug.print("TODO rename {} into cache dir\n", .{out_obj_path});

    // TODO use the cache file name instead of tmp file name
    const success_file_path = try mod.gpa.dupe(u8, out_obj_path);
    c_object.status = .{ .success = success_file_path };
}

fn tmpFilePath(mod: *Module, arena: *Allocator, suffix: []const u8) error{OutOfMemory}![]const u8 {
    const s = std.fs.path.sep_str;
    return std.fmt.allocPrint(
        arena,
        "{}" ++ s ++ "tmp" ++ s ++ "{x}-{}",
        .{ mod.zig_cache_dir_path, mod.rand.int(u64), suffix },
    );
}

/// Add common C compiler args between translate-c and C object compilation.
fn addCCArgs(
    mod: *Module,
    arena: *Allocator,
    argv: *std.ArrayList([]const u8),
    ext: FileExt,
    translate_c: bool,
    out_dep_path: ?[]const u8,
) !void {
    const target = mod.getTarget();

    if (translate_c) {
        try argv.appendSlice(&[_][]const u8{ "-x", "c" });
    }

    if (ext == .cpp) {
        try argv.append("-nostdinc++");
    }
    try argv.appendSlice(&[_][]const u8{
        "-nostdinc",
        "-fno-spell-checking",
    });

    // We don't ever put `-fcolor-diagnostics` or `-fno-color-diagnostics` because in passthrough mode
    // we want Clang to infer it, and in normal mode we always want it off, which will be true since
    // clang will detect stderr as a pipe rather than a terminal.
    if (!mod.clang_passthrough_mode) {
        // Make stderr more easily parseable.
        try argv.append("-fno-caret-diagnostics");
    }

    if (mod.bin_file.options.function_sections) {
        try argv.append("-ffunction-sections");
    }

    try argv.ensureCapacity(argv.items.len + mod.bin_file.options.framework_dirs.len * 2);
    for (mod.bin_file.options.framework_dirs) |framework_dir| {
        argv.appendAssumeCapacity("-iframework");
        argv.appendAssumeCapacity(framework_dir);
    }

    if (mod.bin_file.options.link_libcpp) {
        const libcxx_include_path = try std.fs.path.join(arena, &[_][]const u8{
            mod.zig_lib_dir, "libcxx", "include",
        });
        const libcxxabi_include_path = try std.fs.path.join(arena, &[_][]const u8{
            mod.zig_lib_dir, "libcxxabi", "include",
        });

        try argv.append("-isystem");
        try argv.append(libcxx_include_path);

        try argv.append("-isystem");
        try argv.append(libcxxabi_include_path);

        if (target.abi.isMusl()) {
            try argv.append("-D_LIBCPP_HAS_MUSL_LIBC");
        }
        try argv.append("-D_LIBCPP_DISABLE_VISIBILITY_ANNOTATIONS");
        try argv.append("-D_LIBCXXABI_DISABLE_VISIBILITY_ANNOTATIONS");
    }

    const llvm_triple = try @import("codegen/llvm.zig").targetTriple(arena, target);
    try argv.appendSlice(&[_][]const u8{ "-target", llvm_triple });

    switch (ext) {
        .c, .cpp, .h => {
            // According to Rich Felker libc headers are supposed to go before C language headers.
            // However as noted by @dimenus, appending libc headers before c_headers breaks intrinsics
            // and other compiler specific items.
            const c_headers_dir = try std.fs.path.join(arena, &[_][]const u8{ mod.zig_lib_dir, "include" });
            try argv.append("-isystem");
            try argv.append(c_headers_dir);

            for (mod.libc_include_dir_list) |include_dir| {
                try argv.append("-isystem");
                try argv.append(include_dir);
            }

            if (target.cpu.model.llvm_name) |llvm_name| {
                try argv.appendSlice(&[_][]const u8{
                    "-Xclang", "-target-cpu", "-Xclang", llvm_name,
                });
            }
            // TODO CLI args for target features
            //if (g->zig_target->llvm_cpu_features != nullptr) {
            //    // https://github.com/ziglang/zig/issues/5017
            //    SplitIterator it = memSplit(str(g->zig_target->llvm_cpu_features), str(","));
            //    Optional<Slice<uint8_t>> flag = SplitIterator_next(&it);
            //    while (flag.is_some) {
            //        try argv.append("-Xclang");
            //        try argv.append("-target-feature");
            //        try argv.append("-Xclang");
            //        try argv.append(buf_ptr(buf_create_from_slice(flag.value)));
            //        flag = SplitIterator_next(&it);
            //    }
            //}
            if (translate_c) {
                // This gives us access to preprocessing entities, presumably at the cost of performance.
                try argv.append("-Xclang");
                try argv.append("-detailed-preprocessing-record");
            }
            if (out_dep_path) |p| {
                try argv.append("-MD");
                try argv.append("-MV");
                try argv.append("-MF");
                try argv.append(p);
            }
        },
        .so, .assembly, .ll, .bc, .unknown => {},
    }
    // TODO CLI args for cpu features when compiling assembly
    //for (size_t i = 0; i < g->zig_target->llvm_cpu_features_asm_len; i += 1) {
    //    try argv.append(g->zig_target->llvm_cpu_features_asm_ptr[i]);
    //}

    if (target.os.tag == .freestanding) {
        try argv.append("-ffreestanding");
    }

    // windows.h has files such as pshpack1.h which do #pragma packing, triggering a clang warning.
    // So for this target, we disable this warning.
    if (target.os.tag == .windows and target.abi.isGnu()) {
        try argv.append("-Wno-pragma-pack");
    }

    if (!mod.bin_file.options.strip) {
        try argv.append("-g");
    }

    if (mod.haveFramePointer()) {
        try argv.append("-fno-omit-frame-pointer");
    } else {
        try argv.append("-fomit-frame-pointer");
    }

    if (mod.sanitize_c) {
        try argv.append("-fsanitize=undefined");
        try argv.append("-fsanitize-trap=undefined");
    }

    switch (mod.bin_file.options.optimize_mode) {
        .Debug => {
            // windows c runtime requires -D_DEBUG if using debug libraries
            try argv.append("-D_DEBUG");
            try argv.append("-Og");

            if (mod.bin_file.options.link_libc) {
                try argv.append("-fstack-protector-strong");
                try argv.append("--param");
                try argv.append("ssp-buffer-size=4");
            } else {
                try argv.append("-fno-stack-protector");
            }
        },
        .ReleaseSafe => {
            // See the comment in the BuildModeFastRelease case for why we pass -O2 rather
            // than -O3 here.
            try argv.append("-O2");
            if (mod.bin_file.options.link_libc) {
                try argv.append("-D_FORTIFY_SOURCE=2");
                try argv.append("-fstack-protector-strong");
                try argv.append("--param");
                try argv.append("ssp-buffer-size=4");
            } else {
                try argv.append("-fno-stack-protector");
            }
        },
        .ReleaseFast => {
            try argv.append("-DNDEBUG");
            // Here we pass -O2 rather than -O3 because, although we do the equivalent of
            // -O3 in Zig code, the justification for the difference here is that Zig
            // has better detection and prevention of undefined behavior, so -O3 is safer for
            // Zig code than it is for C code. Also, C programmers are used to their code
            // running in -O2 and thus the -O3 path has been tested less.
            try argv.append("-O2");
            try argv.append("-fno-stack-protector");
        },
        .ReleaseSmall => {
            try argv.append("-DNDEBUG");
            try argv.append("-Os");
            try argv.append("-fno-stack-protector");
        },
    }

    // TODO add CLI args for PIC
    //if (target_supports_fpic(g->zig_target) and g->have_pic) {
    //    try argv.append("-fPIC");
    //}

    try argv.appendSlice(mod.clang_argv);
}

pub fn ensureDeclAnalyzed(self: *Module, decl: *Decl) InnerError!void {
    const tracy = trace(@src());
    defer tracy.end();

    const subsequent_analysis = switch (decl.analysis) {
        .in_progress => unreachable,

        .sema_failure,
        .sema_failure_retryable,
        .codegen_failure,
        .dependency_failure,
        .codegen_failure_retryable,
        => return error.AnalysisFail,

        .complete => return,

        .outdated => blk: {
            log.debug("re-analyzing {}\n", .{decl.name});

            // The exports this Decl performs will be re-discovered, so we remove them here
            // prior to re-analysis.
            self.deleteDeclExports(decl);
            // Dependencies will be re-discovered, so we remove them here prior to re-analysis.
            for (decl.dependencies.items()) |entry| {
                const dep = entry.key;
                dep.removeDependant(decl);
                if (dep.dependants.items().len == 0 and !dep.deletion_flag) {
                    // We don't perform a deletion here, because this Decl or another one
                    // may end up referencing it before the update is complete.
                    dep.deletion_flag = true;
                    try self.deletion_set.append(self.gpa, dep);
                }
            }
            decl.dependencies.clearRetainingCapacity();

            break :blk true;
        },

        .unreferenced => false,
    };

    const type_changed = if (self.root_scope.cast(Scope.ZIRModule)) |zir_module|
        try zir_sema.analyzeZirDecl(self, decl, zir_module.contents.module.decls[decl.src_index])
    else
        self.astGenAndAnalyzeDecl(decl) catch |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            error.AnalysisFail => return error.AnalysisFail,
            else => {
                try self.failed_decls.ensureCapacity(self.gpa, self.failed_decls.items().len + 1);
                self.failed_decls.putAssumeCapacityNoClobber(decl, try ErrorMsg.create(
                    self.gpa,
                    decl.src(),
                    "unable to analyze: {}",
                    .{@errorName(err)},
                ));
                decl.analysis = .sema_failure_retryable;
                return error.AnalysisFail;
            },
        };

    if (subsequent_analysis) {
        // We may need to chase the dependants and re-analyze them.
        // However, if the decl is a function, and the type is the same, we do not need to.
        if (type_changed or decl.typed_value.most_recent.typed_value.val.tag() != .function) {
            for (decl.dependants.items()) |entry| {
                const dep = entry.key;
                switch (dep.analysis) {
                    .unreferenced => unreachable,
                    .in_progress => unreachable,
                    .outdated => continue, // already queued for update

                    .dependency_failure,
                    .sema_failure,
                    .sema_failure_retryable,
                    .codegen_failure,
                    .codegen_failure_retryable,
                    .complete,
                    => if (dep.generation != self.generation) {
                        try self.markOutdatedDecl(dep);
                    },
                }
            }
        }
    }
}

fn astGenAndAnalyzeDecl(self: *Module, decl: *Decl) !bool {
    const tracy = trace(@src());
    defer tracy.end();

    const container_scope = decl.scope.cast(Scope.Container).?;
    const tree = try self.getAstTree(container_scope);
    const ast_node = tree.root_node.decls()[decl.src_index];
    switch (ast_node.tag) {
        .FnProto => {
            const fn_proto = @fieldParentPtr(ast.Node.FnProto, "base", ast_node);

            decl.analysis = .in_progress;

            // This arena allocator's memory is discarded at the end of this function. It is used
            // to determine the type of the function, and hence the type of the decl, which is needed
            // to complete the Decl analysis.
            var fn_type_scope_arena = std.heap.ArenaAllocator.init(self.gpa);
            defer fn_type_scope_arena.deinit();
            var fn_type_scope: Scope.GenZIR = .{
                .decl = decl,
                .arena = &fn_type_scope_arena.allocator,
                .parent = decl.scope,
            };
            defer fn_type_scope.instructions.deinit(self.gpa);

            decl.is_pub = fn_proto.getVisibToken() != null;
            const body_node = fn_proto.getBodyNode() orelse
                return self.failTok(&fn_type_scope.base, fn_proto.fn_token, "TODO implement extern functions", .{});

            const param_decls = fn_proto.params();
            const param_types = try fn_type_scope.arena.alloc(*zir.Inst, param_decls.len);

            const fn_src = tree.token_locs[fn_proto.fn_token].start;
            const type_type = try astgen.addZIRInstConst(self, &fn_type_scope.base, fn_src, .{
                .ty = Type.initTag(.type),
                .val = Value.initTag(.type_type),
            });
            const type_type_rl: astgen.ResultLoc = .{ .ty = type_type };
            for (param_decls) |param_decl, i| {
                const param_type_node = switch (param_decl.param_type) {
                    .any_type => |node| return self.failNode(&fn_type_scope.base, node, "TODO implement anytype parameter", .{}),
                    .type_expr => |node| node,
                };
                param_types[i] = try astgen.expr(self, &fn_type_scope.base, type_type_rl, param_type_node);
            }
            if (fn_proto.getVarArgsToken()) |var_args_token| {
                return self.failTok(&fn_type_scope.base, var_args_token, "TODO implement var args", .{});
            }
            if (fn_proto.getLibName()) |lib_name| {
                return self.failNode(&fn_type_scope.base, lib_name, "TODO implement function library name", .{});
            }
            if (fn_proto.getAlignExpr()) |align_expr| {
                return self.failNode(&fn_type_scope.base, align_expr, "TODO implement function align expression", .{});
            }
            if (fn_proto.getSectionExpr()) |sect_expr| {
                return self.failNode(&fn_type_scope.base, sect_expr, "TODO implement function section expression", .{});
            }
            if (fn_proto.getCallconvExpr()) |callconv_expr| {
                return self.failNode(
                    &fn_type_scope.base,
                    callconv_expr,
                    "TODO implement function calling convention expression",
                    .{},
                );
            }
            const return_type_expr = switch (fn_proto.return_type) {
                .Explicit => |node| node,
                .InferErrorSet => |node| return self.failNode(&fn_type_scope.base, node, "TODO implement inferred error sets", .{}),
                .Invalid => |tok| return self.failTok(&fn_type_scope.base, tok, "unable to parse return type", .{}),
            };

            const return_type_inst = try astgen.expr(self, &fn_type_scope.base, type_type_rl, return_type_expr);
            const fn_type_inst = try astgen.addZIRInst(self, &fn_type_scope.base, fn_src, zir.Inst.FnType, .{
                .return_type = return_type_inst,
                .param_types = param_types,
            }, .{});

            // We need the memory for the Type to go into the arena for the Decl
            var decl_arena = std.heap.ArenaAllocator.init(self.gpa);
            errdefer decl_arena.deinit();
            const decl_arena_state = try decl_arena.allocator.create(std.heap.ArenaAllocator.State);

            var block_scope: Scope.Block = .{
                .parent = null,
                .func = null,
                .decl = decl,
                .instructions = .{},
                .arena = &decl_arena.allocator,
                .is_comptime = false,
            };
            defer block_scope.instructions.deinit(self.gpa);

            const fn_type = try zir_sema.analyzeBodyValueAsType(self, &block_scope, fn_type_inst, .{
                .instructions = fn_type_scope.instructions.items,
            });
            const new_func = try decl_arena.allocator.create(Fn);
            const fn_payload = try decl_arena.allocator.create(Value.Payload.Function);

            const fn_zir = blk: {
                // This scope's arena memory is discarded after the ZIR generation
                // pass completes, and semantic analysis of it completes.
                var gen_scope_arena = std.heap.ArenaAllocator.init(self.gpa);
                errdefer gen_scope_arena.deinit();
                var gen_scope: Scope.GenZIR = .{
                    .decl = decl,
                    .arena = &gen_scope_arena.allocator,
                    .parent = decl.scope,
                };
                defer gen_scope.instructions.deinit(self.gpa);

                // We need an instruction for each parameter, and they must be first in the body.
                try gen_scope.instructions.resize(self.gpa, fn_proto.params_len);
                var params_scope = &gen_scope.base;
                for (fn_proto.params()) |param, i| {
                    const name_token = param.name_token.?;
                    const src = tree.token_locs[name_token].start;
                    const param_name = tree.tokenSlice(name_token); // TODO: call identifierTokenString
                    const arg = try gen_scope_arena.allocator.create(zir.Inst.Arg);
                    arg.* = .{
                        .base = .{
                            .tag = .arg,
                            .src = src,
                        },
                        .positionals = .{
                            .name = param_name,
                        },
                        .kw_args = .{},
                    };
                    gen_scope.instructions.items[i] = &arg.base;
                    const sub_scope = try gen_scope_arena.allocator.create(Scope.LocalVal);
                    sub_scope.* = .{
                        .parent = params_scope,
                        .gen_zir = &gen_scope,
                        .name = param_name,
                        .inst = &arg.base,
                    };
                    params_scope = &sub_scope.base;
                }

                const body_block = body_node.cast(ast.Node.Block).?;

                try astgen.blockExpr(self, params_scope, body_block);

                if (gen_scope.instructions.items.len == 0 or
                    !gen_scope.instructions.items[gen_scope.instructions.items.len - 1].tag.isNoReturn())
                {
                    const src = tree.token_locs[body_block.rbrace].start;
                    _ = try astgen.addZIRNoOp(self, &gen_scope.base, src, .returnvoid);
                }

                const fn_zir = try gen_scope_arena.allocator.create(Fn.ZIR);
                fn_zir.* = .{
                    .body = .{
                        .instructions = try gen_scope.arena.dupe(*zir.Inst, gen_scope.instructions.items),
                    },
                    .arena = gen_scope_arena.state,
                };
                break :blk fn_zir;
            };

            new_func.* = .{
                .analysis = .{ .queued = fn_zir },
                .owner_decl = decl,
            };
            fn_payload.* = .{ .func = new_func };

            var prev_type_has_bits = false;
            var type_changed = true;

            if (decl.typedValueManaged()) |tvm| {
                prev_type_has_bits = tvm.typed_value.ty.hasCodeGenBits();
                type_changed = !tvm.typed_value.ty.eql(fn_type);

                tvm.deinit(self.gpa);
            }

            decl_arena_state.* = decl_arena.state;
            decl.typed_value = .{
                .most_recent = .{
                    .typed_value = .{
                        .ty = fn_type,
                        .val = Value.initPayload(&fn_payload.base),
                    },
                    .arena = decl_arena_state,
                },
            };
            decl.analysis = .complete;
            decl.generation = self.generation;

            if (fn_type.hasCodeGenBits()) {
                // We don't fully codegen the decl until later, but we do need to reserve a global
                // offset table index for it. This allows us to codegen decls out of dependency order,
                // increasing how many computations can be done in parallel.
                try self.bin_file.allocateDeclIndexes(decl);
                try self.work_queue.writeItem(.{ .codegen_decl = decl });
            } else if (prev_type_has_bits) {
                self.bin_file.freeDecl(decl);
            }

            if (fn_proto.getExternExportInlineToken()) |maybe_export_token| {
                if (tree.token_ids[maybe_export_token] == .Keyword_export) {
                    const export_src = tree.token_locs[maybe_export_token].start;
                    const name_loc = tree.token_locs[fn_proto.getNameToken().?];
                    const name = tree.tokenSliceLoc(name_loc);
                    // The scope needs to have the decl in it.
                    try self.analyzeExport(&block_scope.base, export_src, name, decl);
                }
            }
            return type_changed;
        },
        .VarDecl => {
            const var_decl = @fieldParentPtr(ast.Node.VarDecl, "base", ast_node);

            decl.analysis = .in_progress;

            // We need the memory for the Type to go into the arena for the Decl
            var decl_arena = std.heap.ArenaAllocator.init(self.gpa);
            errdefer decl_arena.deinit();
            const decl_arena_state = try decl_arena.allocator.create(std.heap.ArenaAllocator.State);

            var block_scope: Scope.Block = .{
                .parent = null,
                .func = null,
                .decl = decl,
                .instructions = .{},
                .arena = &decl_arena.allocator,
                .is_comptime = true,
            };
            defer block_scope.instructions.deinit(self.gpa);

            decl.is_pub = var_decl.getVisibToken() != null;
            const is_extern = blk: {
                const maybe_extern_token = var_decl.getExternExportToken() orelse
                    break :blk false;
                if (tree.token_ids[maybe_extern_token] != .Keyword_extern) break :blk false;
                if (var_decl.getInitNode()) |some| {
                    return self.failNode(&block_scope.base, some, "extern variables have no initializers", .{});
                }
                break :blk true;
            };
            if (var_decl.getLibName()) |lib_name| {
                assert(is_extern);
                return self.failNode(&block_scope.base, lib_name, "TODO implement function library name", .{});
            }
            const is_mutable = tree.token_ids[var_decl.mut_token] == .Keyword_var;
            const is_threadlocal = if (var_decl.getThreadLocalToken()) |some| blk: {
                if (!is_mutable) {
                    return self.failTok(&block_scope.base, some, "threadlocal variable cannot be constant", .{});
                }
                break :blk true;
            } else false;
            assert(var_decl.getComptimeToken() == null);
            if (var_decl.getAlignNode()) |align_expr| {
                return self.failNode(&block_scope.base, align_expr, "TODO implement function align expression", .{});
            }
            if (var_decl.getSectionNode()) |sect_expr| {
                return self.failNode(&block_scope.base, sect_expr, "TODO implement function section expression", .{});
            }

            const var_info: struct { ty: Type, val: ?Value } = if (var_decl.getInitNode()) |init_node| vi: {
                var gen_scope_arena = std.heap.ArenaAllocator.init(self.gpa);
                defer gen_scope_arena.deinit();
                var gen_scope: Scope.GenZIR = .{
                    .decl = decl,
                    .arena = &gen_scope_arena.allocator,
                    .parent = decl.scope,
                };
                defer gen_scope.instructions.deinit(self.gpa);

                const init_result_loc: astgen.ResultLoc = if (var_decl.getTypeNode()) |type_node| rl: {
                    const src = tree.token_locs[type_node.firstToken()].start;
                    const type_type = try astgen.addZIRInstConst(self, &gen_scope.base, src, .{
                        .ty = Type.initTag(.type),
                        .val = Value.initTag(.type_type),
                    });
                    const var_type = try astgen.expr(self, &gen_scope.base, .{ .ty = type_type }, type_node);
                    break :rl .{ .ty = var_type };
                } else .none;

                const src = tree.token_locs[init_node.firstToken()].start;
                const init_inst = try astgen.expr(self, &gen_scope.base, init_result_loc, init_node);

                var inner_block: Scope.Block = .{
                    .parent = null,
                    .func = null,
                    .decl = decl,
                    .instructions = .{},
                    .arena = &gen_scope_arena.allocator,
                    .is_comptime = true,
                };
                defer inner_block.instructions.deinit(self.gpa);
                try zir_sema.analyzeBody(self, &inner_block.base, .{ .instructions = gen_scope.instructions.items });

                // The result location guarantees the type coercion.
                const analyzed_init_inst = init_inst.analyzed_inst.?;
                // The is_comptime in the Scope.Block guarantees the result is comptime-known.
                const val = analyzed_init_inst.value().?;

                const ty = try analyzed_init_inst.ty.copy(block_scope.arena);
                break :vi .{
                    .ty = ty,
                    .val = try val.copy(block_scope.arena),
                };
            } else if (!is_extern) {
                return self.failTok(&block_scope.base, var_decl.firstToken(), "variables must be initialized", .{});
            } else if (var_decl.getTypeNode()) |type_node| vi: {
                // Temporary arena for the zir instructions.
                var type_scope_arena = std.heap.ArenaAllocator.init(self.gpa);
                defer type_scope_arena.deinit();
                var type_scope: Scope.GenZIR = .{
                    .decl = decl,
                    .arena = &type_scope_arena.allocator,
                    .parent = decl.scope,
                };
                defer type_scope.instructions.deinit(self.gpa);

                const src = tree.token_locs[type_node.firstToken()].start;
                const type_type = try astgen.addZIRInstConst(self, &type_scope.base, src, .{
                    .ty = Type.initTag(.type),
                    .val = Value.initTag(.type_type),
                });
                const var_type = try astgen.expr(self, &type_scope.base, .{ .ty = type_type }, type_node);
                const ty = try zir_sema.analyzeBodyValueAsType(self, &block_scope, var_type, .{
                    .instructions = type_scope.instructions.items,
                });
                break :vi .{
                    .ty = ty,
                    .val = null,
                };
            } else {
                return self.failTok(&block_scope.base, var_decl.firstToken(), "unable to infer variable type", .{});
            };

            if (is_mutable and !var_info.ty.isValidVarType(is_extern)) {
                return self.failTok(&block_scope.base, var_decl.firstToken(), "variable of type '{}' must be const", .{var_info.ty});
            }

            var type_changed = true;
            if (decl.typedValueManaged()) |tvm| {
                type_changed = !tvm.typed_value.ty.eql(var_info.ty);

                tvm.deinit(self.gpa);
            }

            const new_variable = try decl_arena.allocator.create(Var);
            const var_payload = try decl_arena.allocator.create(Value.Payload.Variable);
            new_variable.* = .{
                .owner_decl = decl,
                .init = var_info.val orelse undefined,
                .is_extern = is_extern,
                .is_mutable = is_mutable,
                .is_threadlocal = is_threadlocal,
            };
            var_payload.* = .{ .variable = new_variable };

            decl_arena_state.* = decl_arena.state;
            decl.typed_value = .{
                .most_recent = .{
                    .typed_value = .{
                        .ty = var_info.ty,
                        .val = Value.initPayload(&var_payload.base),
                    },
                    .arena = decl_arena_state,
                },
            };
            decl.analysis = .complete;
            decl.generation = self.generation;

            if (var_decl.getExternExportToken()) |maybe_export_token| {
                if (tree.token_ids[maybe_export_token] == .Keyword_export) {
                    const export_src = tree.token_locs[maybe_export_token].start;
                    const name_loc = tree.token_locs[var_decl.name_token];
                    const name = tree.tokenSliceLoc(name_loc);
                    // The scope needs to have the decl in it.
                    try self.analyzeExport(&block_scope.base, export_src, name, decl);
                }
            }
            return type_changed;
        },
        .Comptime => {
            const comptime_decl = @fieldParentPtr(ast.Node.Comptime, "base", ast_node);

            decl.analysis = .in_progress;

            // A comptime decl does not store any value so we can just deinit this arena after analysis is done.
            var analysis_arena = std.heap.ArenaAllocator.init(self.gpa);
            defer analysis_arena.deinit();
            var gen_scope: Scope.GenZIR = .{
                .decl = decl,
                .arena = &analysis_arena.allocator,
                .parent = decl.scope,
            };
            defer gen_scope.instructions.deinit(self.gpa);

            _ = try astgen.comptimeExpr(self, &gen_scope.base, .none, comptime_decl.expr);

            var block_scope: Scope.Block = .{
                .parent = null,
                .func = null,
                .decl = decl,
                .instructions = .{},
                .arena = &analysis_arena.allocator,
                .is_comptime = true,
            };
            defer block_scope.instructions.deinit(self.gpa);

            _ = try zir_sema.analyzeBody(self, &block_scope.base, .{
                .instructions = gen_scope.instructions.items,
            });

            decl.analysis = .complete;
            decl.generation = self.generation;
            return true;
        },
        .Use => @panic("TODO usingnamespace decl"),
        else => unreachable,
    }
}

fn declareDeclDependency(self: *Module, depender: *Decl, dependee: *Decl) !void {
    try depender.dependencies.ensureCapacity(self.gpa, depender.dependencies.items().len + 1);
    try dependee.dependants.ensureCapacity(self.gpa, dependee.dependants.items().len + 1);

    depender.dependencies.putAssumeCapacity(dependee, {});
    dependee.dependants.putAssumeCapacity(depender, {});
}

fn getSrcModule(self: *Module, root_scope: *Scope.ZIRModule) !*zir.Module {
    switch (root_scope.status) {
        .never_loaded, .unloaded_success => {
            try self.failed_files.ensureCapacity(self.gpa, self.failed_files.items().len + 1);

            const source = try root_scope.getSource(self);

            var keep_zir_module = false;
            const zir_module = try self.gpa.create(zir.Module);
            defer if (!keep_zir_module) self.gpa.destroy(zir_module);

            zir_module.* = try zir.parse(self.gpa, source);
            defer if (!keep_zir_module) zir_module.deinit(self.gpa);

            if (zir_module.error_msg) |src_err_msg| {
                self.failed_files.putAssumeCapacityNoClobber(
                    &root_scope.base,
                    try ErrorMsg.create(self.gpa, src_err_msg.byte_offset, "{}", .{src_err_msg.msg}),
                );
                root_scope.status = .unloaded_parse_failure;
                return error.AnalysisFail;
            }

            root_scope.status = .loaded_success;
            root_scope.contents = .{ .module = zir_module };
            keep_zir_module = true;

            return zir_module;
        },

        .unloaded_parse_failure,
        .unloaded_sema_failure,
        => return error.AnalysisFail,

        .loaded_success, .loaded_sema_failure => return root_scope.contents.module,
    }
}

fn getAstTree(self: *Module, container_scope: *Scope.Container) !*ast.Tree {
    const tracy = trace(@src());
    defer tracy.end();

    const root_scope = container_scope.file_scope;

    switch (root_scope.status) {
        .never_loaded, .unloaded_success => {
            try self.failed_files.ensureCapacity(self.gpa, self.failed_files.items().len + 1);

            const source = try root_scope.getSource(self);

            var keep_tree = false;
            const tree = try std.zig.parse(self.gpa, source);
            defer if (!keep_tree) tree.deinit();

            if (tree.errors.len != 0) {
                const parse_err = tree.errors[0];

                var msg = std.ArrayList(u8).init(self.gpa);
                defer msg.deinit();

                try parse_err.render(tree.token_ids, msg.outStream());
                const err_msg = try self.gpa.create(ErrorMsg);
                err_msg.* = .{
                    .msg = msg.toOwnedSlice(),
                    .byte_offset = tree.token_locs[parse_err.loc()].start,
                };

                self.failed_files.putAssumeCapacityNoClobber(&root_scope.base, err_msg);
                root_scope.status = .unloaded_parse_failure;
                return error.AnalysisFail;
            }

            root_scope.status = .loaded_success;
            root_scope.contents = .{ .tree = tree };
            keep_tree = true;

            return tree;
        },

        .unloaded_parse_failure => return error.AnalysisFail,

        .loaded_success => return root_scope.contents.tree,
    }
}

fn analyzeContainer(self: *Module, container_scope: *Scope.Container) !void {
    const tracy = trace(@src());
    defer tracy.end();

    // We may be analyzing it for the first time, or this may be
    // an incremental update. This code handles both cases.
    const tree = try self.getAstTree(container_scope);
    const decls = tree.root_node.decls();

    try self.work_queue.ensureUnusedCapacity(decls.len);
    try container_scope.decls.ensureCapacity(self.gpa, decls.len);

    // Keep track of the decls that we expect to see in this file so that
    // we know which ones have been deleted.
    var deleted_decls = std.AutoArrayHashMap(*Decl, void).init(self.gpa);
    defer deleted_decls.deinit();
    try deleted_decls.ensureCapacity(container_scope.decls.items().len);
    for (container_scope.decls.items()) |entry| {
        deleted_decls.putAssumeCapacityNoClobber(entry.key, {});
    }

    for (decls) |src_decl, decl_i| {
        if (src_decl.cast(ast.Node.FnProto)) |fn_proto| {
            // We will create a Decl for it regardless of analysis status.
            const name_tok = fn_proto.getNameToken() orelse {
                @panic("TODO missing function name");
            };

            const name_loc = tree.token_locs[name_tok];
            const name = tree.tokenSliceLoc(name_loc);
            const name_hash = container_scope.fullyQualifiedNameHash(name);
            const contents_hash = std.zig.hashSrc(tree.getNodeSource(src_decl));
            if (self.decl_table.get(name_hash)) |decl| {
                // Update the AST Node index of the decl, even if its contents are unchanged, it may
                // have been re-ordered.
                decl.src_index = decl_i;
                if (deleted_decls.remove(decl) == null) {
                    decl.analysis = .sema_failure;
                    const err_msg = try ErrorMsg.create(self.gpa, tree.token_locs[name_tok].start, "redefinition of '{}'", .{decl.name});
                    errdefer err_msg.destroy(self.gpa);
                    try self.failed_decls.putNoClobber(self.gpa, decl, err_msg);
                } else {
                    if (!srcHashEql(decl.contents_hash, contents_hash)) {
                        try self.markOutdatedDecl(decl);
                        decl.contents_hash = contents_hash;
                    } else switch (self.bin_file.tag) {
                        .coff => {
                            // TODO Implement for COFF
                        },
                        .elf => if (decl.fn_link.elf.len != 0) {
                            // TODO Look into detecting when this would be unnecessary by storing enough state
                            // in `Decl` to notice that the line number did not change.
                            self.work_queue.writeItemAssumeCapacity(.{ .update_line_number = decl });
                        },
                        .macho => {
                            // TODO Implement for MachO
                        },
                        .c, .wasm => {},
                    }
                }
            } else {
                const new_decl = try self.createNewDecl(&container_scope.base, name, decl_i, name_hash, contents_hash);
                container_scope.decls.putAssumeCapacity(new_decl, {});
                if (fn_proto.getExternExportInlineToken()) |maybe_export_token| {
                    if (tree.token_ids[maybe_export_token] == .Keyword_export) {
                        self.work_queue.writeItemAssumeCapacity(.{ .analyze_decl = new_decl });
                    }
                }
            }
        } else if (src_decl.castTag(.VarDecl)) |var_decl| {
            const name_loc = tree.token_locs[var_decl.name_token];
            const name = tree.tokenSliceLoc(name_loc);
            const name_hash = container_scope.fullyQualifiedNameHash(name);
            const contents_hash = std.zig.hashSrc(tree.getNodeSource(src_decl));
            if (self.decl_table.get(name_hash)) |decl| {
                // Update the AST Node index of the decl, even if its contents are unchanged, it may
                // have been re-ordered.
                decl.src_index = decl_i;
                if (deleted_decls.remove(decl) == null) {
                    decl.analysis = .sema_failure;
                    const err_msg = try ErrorMsg.create(self.gpa, name_loc.start, "redefinition of '{}'", .{decl.name});
                    errdefer err_msg.destroy(self.gpa);
                    try self.failed_decls.putNoClobber(self.gpa, decl, err_msg);
                } else if (!srcHashEql(decl.contents_hash, contents_hash)) {
                    try self.markOutdatedDecl(decl);
                    decl.contents_hash = contents_hash;
                }
            } else {
                const new_decl = try self.createNewDecl(&container_scope.base, name, decl_i, name_hash, contents_hash);
                container_scope.decls.putAssumeCapacity(new_decl, {});
                if (var_decl.getExternExportToken()) |maybe_export_token| {
                    if (tree.token_ids[maybe_export_token] == .Keyword_export) {
                        self.work_queue.writeItemAssumeCapacity(.{ .analyze_decl = new_decl });
                    }
                }
            }
        } else if (src_decl.castTag(.Comptime)) |comptime_node| {
            const name_index = self.getNextAnonNameIndex();
            const name = try std.fmt.allocPrint(self.gpa, "__comptime_{}", .{name_index});
            defer self.gpa.free(name);

            const name_hash = container_scope.fullyQualifiedNameHash(name);
            const contents_hash = std.zig.hashSrc(tree.getNodeSource(src_decl));

            const new_decl = try self.createNewDecl(&container_scope.base, name, decl_i, name_hash, contents_hash);
            container_scope.decls.putAssumeCapacity(new_decl, {});
            self.work_queue.writeItemAssumeCapacity(.{ .analyze_decl = new_decl });
        } else if (src_decl.castTag(.ContainerField)) |container_field| {
            log.err("TODO: analyze container field", .{});
        } else if (src_decl.castTag(.TestDecl)) |test_decl| {
            log.err("TODO: analyze test decl", .{});
        } else if (src_decl.castTag(.Use)) |use_decl| {
            log.err("TODO: analyze usingnamespace decl", .{});
        } else {
            unreachable;
        }
    }
    // Handle explicitly deleted decls from the source code. Not to be confused
    // with when we delete decls because they are no longer referenced.
    for (deleted_decls.items()) |entry| {
        log.debug("noticed '{}' deleted from source\n", .{entry.key.name});
        try self.deleteDecl(entry.key);
    }
}

fn analyzeRootZIRModule(self: *Module, root_scope: *Scope.ZIRModule) !void {
    // We may be analyzing it for the first time, or this may be
    // an incremental update. This code handles both cases.
    const src_module = try self.getSrcModule(root_scope);

    try self.work_queue.ensureUnusedCapacity(src_module.decls.len);
    try root_scope.decls.ensureCapacity(self.gpa, src_module.decls.len);

    var exports_to_resolve = std.ArrayList(*zir.Decl).init(self.gpa);
    defer exports_to_resolve.deinit();

    // Keep track of the decls that we expect to see in this file so that
    // we know which ones have been deleted.
    var deleted_decls = std.AutoArrayHashMap(*Decl, void).init(self.gpa);
    defer deleted_decls.deinit();
    try deleted_decls.ensureCapacity(self.decl_table.items().len);
    for (self.decl_table.items()) |entry| {
        deleted_decls.putAssumeCapacityNoClobber(entry.value, {});
    }

    for (src_module.decls) |src_decl, decl_i| {
        const name_hash = root_scope.fullyQualifiedNameHash(src_decl.name);
        if (self.decl_table.get(name_hash)) |decl| {
            deleted_decls.removeAssertDiscard(decl);
            if (!srcHashEql(src_decl.contents_hash, decl.contents_hash)) {
                try self.markOutdatedDecl(decl);
                decl.contents_hash = src_decl.contents_hash;
            }
        } else {
            const new_decl = try self.createNewDecl(
                &root_scope.base,
                src_decl.name,
                decl_i,
                name_hash,
                src_decl.contents_hash,
            );
            root_scope.decls.appendAssumeCapacity(new_decl);
            if (src_decl.inst.cast(zir.Inst.Export)) |export_inst| {
                try exports_to_resolve.append(src_decl);
            }
        }
    }
    for (exports_to_resolve.items) |export_decl| {
        _ = try zir_sema.resolveZirDecl(self, &root_scope.base, export_decl);
    }
    // Handle explicitly deleted decls from the source code. Not to be confused
    // with when we delete decls because they are no longer referenced.
    for (deleted_decls.items()) |entry| {
        log.debug("noticed '{}' deleted from source\n", .{entry.key.name});
        try self.deleteDecl(entry.key);
    }
}

fn deleteDecl(self: *Module, decl: *Decl) !void {
    try self.deletion_set.ensureCapacity(self.gpa, self.deletion_set.items.len + decl.dependencies.items().len);

    // Remove from the namespace it resides in. In the case of an anonymous Decl it will
    // not be present in the set, and this does nothing.
    decl.scope.removeDecl(decl);

    log.debug("deleting decl '{}'\n", .{decl.name});
    const name_hash = decl.fullyQualifiedNameHash();
    self.decl_table.removeAssertDiscard(name_hash);
    // Remove itself from its dependencies, because we are about to destroy the decl pointer.
    for (decl.dependencies.items()) |entry| {
        const dep = entry.key;
        dep.removeDependant(decl);
        if (dep.dependants.items().len == 0 and !dep.deletion_flag) {
            // We don't recursively perform a deletion here, because during the update,
            // another reference to it may turn up.
            dep.deletion_flag = true;
            self.deletion_set.appendAssumeCapacity(dep);
        }
    }
    // Anything that depends on this deleted decl certainly needs to be re-analyzed.
    for (decl.dependants.items()) |entry| {
        const dep = entry.key;
        dep.removeDependency(decl);
        if (dep.analysis != .outdated) {
            // TODO Move this failure possibility to the top of the function.
            try self.markOutdatedDecl(dep);
        }
    }
    if (self.failed_decls.remove(decl)) |entry| {
        entry.value.destroy(self.gpa);
    }
    self.deleteDeclExports(decl);
    self.bin_file.freeDecl(decl);
    decl.destroy(self.gpa);
}

/// Delete all the Export objects that are caused by this Decl. Re-analysis of
/// this Decl will cause them to be re-created (or not).
fn deleteDeclExports(self: *Module, decl: *Decl) void {
    const kv = self.export_owners.remove(decl) orelse return;

    for (kv.value) |exp| {
        if (self.decl_exports.getEntry(exp.exported_decl)) |decl_exports_kv| {
            // Remove exports with owner_decl matching the regenerating decl.
            const list = decl_exports_kv.value;
            var i: usize = 0;
            var new_len = list.len;
            while (i < new_len) {
                if (list[i].owner_decl == decl) {
                    mem.copyBackwards(*Export, list[i..], list[i + 1 .. new_len]);
                    new_len -= 1;
                } else {
                    i += 1;
                }
            }
            decl_exports_kv.value = self.gpa.shrink(list, new_len);
            if (new_len == 0) {
                self.decl_exports.removeAssertDiscard(exp.exported_decl);
            }
        }
        if (self.bin_file.cast(link.File.Elf)) |elf| {
            elf.deleteExport(exp.link);
        }
        if (self.failed_exports.remove(exp)) |entry| {
            entry.value.destroy(self.gpa);
        }
        _ = self.symbol_exports.remove(exp.options.name);
        self.gpa.free(exp.options.name);
        self.gpa.destroy(exp);
    }
    self.gpa.free(kv.value);
}

fn analyzeFnBody(self: *Module, decl: *Decl, func: *Fn) !void {
    const tracy = trace(@src());
    defer tracy.end();

    // Use the Decl's arena for function memory.
    var arena = decl.typed_value.most_recent.arena.?.promote(self.gpa);
    defer decl.typed_value.most_recent.arena.?.* = arena.state;
    var inner_block: Scope.Block = .{
        .parent = null,
        .func = func,
        .decl = decl,
        .instructions = .{},
        .arena = &arena.allocator,
        .is_comptime = false,
    };
    defer inner_block.instructions.deinit(self.gpa);

    const fn_zir = func.analysis.queued;
    defer fn_zir.arena.promote(self.gpa).deinit();
    func.analysis = .{ .in_progress = {} };
    log.debug("set {} to in_progress\n", .{decl.name});

    try zir_sema.analyzeBody(self, &inner_block.base, fn_zir.body);

    const instructions = try arena.allocator.dupe(*Inst, inner_block.instructions.items);
    func.analysis = .{ .success = .{ .instructions = instructions } };
    log.debug("set {} to success\n", .{decl.name});
}

fn markOutdatedDecl(self: *Module, decl: *Decl) !void {
    log.debug("mark {} outdated\n", .{decl.name});
    try self.work_queue.writeItem(.{ .analyze_decl = decl });
    if (self.failed_decls.remove(decl)) |entry| {
        entry.value.destroy(self.gpa);
    }
    decl.analysis = .outdated;
}

fn allocateNewDecl(
    self: *Module,
    scope: *Scope,
    src_index: usize,
    contents_hash: std.zig.SrcHash,
) !*Decl {
    const new_decl = try self.gpa.create(Decl);
    new_decl.* = .{
        .name = "",
        .scope = scope.namespace(),
        .src_index = src_index,
        .typed_value = .{ .never_succeeded = {} },
        .analysis = .unreferenced,
        .deletion_flag = false,
        .contents_hash = contents_hash,
        .link = switch (self.bin_file.tag) {
            .coff => .{ .coff = link.File.Coff.TextBlock.empty },
            .elf => .{ .elf = link.File.Elf.TextBlock.empty },
            .macho => .{ .macho = link.File.MachO.TextBlock.empty },
            .c => .{ .c = {} },
            .wasm => .{ .wasm = {} },
        },
        .fn_link = switch (self.bin_file.tag) {
            .coff => .{ .coff = {} },
            .elf => .{ .elf = link.File.Elf.SrcFn.empty },
            .macho => .{ .macho = link.File.MachO.SrcFn.empty },
            .c => .{ .c = {} },
            .wasm => .{ .wasm = null },
        },
        .generation = 0,
        .is_pub = false,
    };
    return new_decl;
}

fn createNewDecl(
    self: *Module,
    scope: *Scope,
    decl_name: []const u8,
    src_index: usize,
    name_hash: Scope.NameHash,
    contents_hash: std.zig.SrcHash,
) !*Decl {
    try self.decl_table.ensureCapacity(self.gpa, self.decl_table.items().len + 1);
    const new_decl = try self.allocateNewDecl(scope, src_index, contents_hash);
    errdefer self.gpa.destroy(new_decl);
    new_decl.name = try mem.dupeZ(self.gpa, u8, decl_name);
    self.decl_table.putAssumeCapacityNoClobber(name_hash, new_decl);
    return new_decl;
}

/// Get error value for error tag `name`.
pub fn getErrorValue(self: *Module, name: []const u8) !std.StringHashMapUnmanaged(u16).Entry {
    const gop = try self.global_error_set.getOrPut(self.gpa, name);
    if (gop.found_existing)
        return gop.entry.*;
    errdefer self.global_error_set.removeAssertDiscard(name);

    gop.entry.key = try self.gpa.dupe(u8, name);
    gop.entry.value = @intCast(u16, self.global_error_set.count() - 1);
    return gop.entry.*;
}

pub fn requireFunctionBlock(self: *Module, scope: *Scope, src: usize) !*Scope.Block {
    return scope.cast(Scope.Block) orelse
        return self.fail(scope, src, "instruction illegal outside function body", .{});
}

pub fn requireRuntimeBlock(self: *Module, scope: *Scope, src: usize) !*Scope.Block {
    const block = try self.requireFunctionBlock(scope, src);
    if (block.is_comptime) {
        return self.fail(scope, src, "unable to resolve comptime value", .{});
    }
    return block;
}

pub fn resolveConstValue(self: *Module, scope: *Scope, base: *Inst) !Value {
    return (try self.resolveDefinedValue(scope, base)) orelse
        return self.fail(scope, base.src, "unable to resolve comptime value", .{});
}

pub fn resolveDefinedValue(self: *Module, scope: *Scope, base: *Inst) !?Value {
    if (base.value()) |val| {
        if (val.isUndef()) {
            return self.fail(scope, base.src, "use of undefined value here causes undefined behavior", .{});
        }
        return val;
    }
    return null;
}

pub fn analyzeExport(self: *Module, scope: *Scope, src: usize, borrowed_symbol_name: []const u8, exported_decl: *Decl) !void {
    try self.ensureDeclAnalyzed(exported_decl);
    const typed_value = exported_decl.typed_value.most_recent.typed_value;
    switch (typed_value.ty.zigTypeTag()) {
        .Fn => {},
        else => return self.fail(scope, src, "unable to export type '{}'", .{typed_value.ty}),
    }

    try self.decl_exports.ensureCapacity(self.gpa, self.decl_exports.items().len + 1);
    try self.export_owners.ensureCapacity(self.gpa, self.export_owners.items().len + 1);

    const new_export = try self.gpa.create(Export);
    errdefer self.gpa.destroy(new_export);

    const symbol_name = try self.gpa.dupe(u8, borrowed_symbol_name);
    errdefer self.gpa.free(symbol_name);

    const owner_decl = scope.decl().?;

    new_export.* = .{
        .options = .{ .name = symbol_name },
        .src = src,
        .link = .{},
        .owner_decl = owner_decl,
        .exported_decl = exported_decl,
        .status = .in_progress,
    };

    // Add to export_owners table.
    const eo_gop = self.export_owners.getOrPutAssumeCapacity(owner_decl);
    if (!eo_gop.found_existing) {
        eo_gop.entry.value = &[0]*Export{};
    }
    eo_gop.entry.value = try self.gpa.realloc(eo_gop.entry.value, eo_gop.entry.value.len + 1);
    eo_gop.entry.value[eo_gop.entry.value.len - 1] = new_export;
    errdefer eo_gop.entry.value = self.gpa.shrink(eo_gop.entry.value, eo_gop.entry.value.len - 1);

    // Add to exported_decl table.
    const de_gop = self.decl_exports.getOrPutAssumeCapacity(exported_decl);
    if (!de_gop.found_existing) {
        de_gop.entry.value = &[0]*Export{};
    }
    de_gop.entry.value = try self.gpa.realloc(de_gop.entry.value, de_gop.entry.value.len + 1);
    de_gop.entry.value[de_gop.entry.value.len - 1] = new_export;
    errdefer de_gop.entry.value = self.gpa.shrink(de_gop.entry.value, de_gop.entry.value.len - 1);

    if (self.symbol_exports.get(symbol_name)) |_| {
        try self.failed_exports.ensureCapacity(self.gpa, self.failed_exports.items().len + 1);
        self.failed_exports.putAssumeCapacityNoClobber(new_export, try ErrorMsg.create(
            self.gpa,
            src,
            "exported symbol collision: {}",
            .{symbol_name},
        ));
        // TODO: add a note
        new_export.status = .failed;
        return;
    }

    try self.symbol_exports.putNoClobber(self.gpa, symbol_name, new_export);
    self.bin_file.updateDeclExports(self, exported_decl, de_gop.entry.value) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => {
            try self.failed_exports.ensureCapacity(self.gpa, self.failed_exports.items().len + 1);
            self.failed_exports.putAssumeCapacityNoClobber(new_export, try ErrorMsg.create(
                self.gpa,
                src,
                "unable to export: {}",
                .{@errorName(err)},
            ));
            new_export.status = .failed_retryable;
        },
    };
}

pub fn addNoOp(
    self: *Module,
    block: *Scope.Block,
    src: usize,
    ty: Type,
    comptime tag: Inst.Tag,
) !*Inst {
    const inst = try block.arena.create(tag.Type());
    inst.* = .{
        .base = .{
            .tag = tag,
            .ty = ty,
            .src = src,
        },
    };
    try block.instructions.append(self.gpa, &inst.base);
    return &inst.base;
}

pub fn addUnOp(
    self: *Module,
    block: *Scope.Block,
    src: usize,
    ty: Type,
    tag: Inst.Tag,
    operand: *Inst,
) !*Inst {
    const inst = try block.arena.create(Inst.UnOp);
    inst.* = .{
        .base = .{
            .tag = tag,
            .ty = ty,
            .src = src,
        },
        .operand = operand,
    };
    try block.instructions.append(self.gpa, &inst.base);
    return &inst.base;
}

pub fn addBinOp(
    self: *Module,
    block: *Scope.Block,
    src: usize,
    ty: Type,
    tag: Inst.Tag,
    lhs: *Inst,
    rhs: *Inst,
) !*Inst {
    const inst = try block.arena.create(Inst.BinOp);
    inst.* = .{
        .base = .{
            .tag = tag,
            .ty = ty,
            .src = src,
        },
        .lhs = lhs,
        .rhs = rhs,
    };
    try block.instructions.append(self.gpa, &inst.base);
    return &inst.base;
}

pub fn addArg(self: *Module, block: *Scope.Block, src: usize, ty: Type, name: [*:0]const u8) !*Inst {
    const inst = try block.arena.create(Inst.Arg);
    inst.* = .{
        .base = .{
            .tag = .arg,
            .ty = ty,
            .src = src,
        },
        .name = name,
    };
    try block.instructions.append(self.gpa, &inst.base);
    return &inst.base;
}

pub fn addBr(
    self: *Module,
    scope_block: *Scope.Block,
    src: usize,
    target_block: *Inst.Block,
    operand: *Inst,
) !*Inst {
    const inst = try scope_block.arena.create(Inst.Br);
    inst.* = .{
        .base = .{
            .tag = .br,
            .ty = Type.initTag(.noreturn),
            .src = src,
        },
        .operand = operand,
        .block = target_block,
    };
    try scope_block.instructions.append(self.gpa, &inst.base);
    return &inst.base;
}

pub fn addCondBr(
    self: *Module,
    block: *Scope.Block,
    src: usize,
    condition: *Inst,
    then_body: ir.Body,
    else_body: ir.Body,
) !*Inst {
    const inst = try block.arena.create(Inst.CondBr);
    inst.* = .{
        .base = .{
            .tag = .condbr,
            .ty = Type.initTag(.noreturn),
            .src = src,
        },
        .condition = condition,
        .then_body = then_body,
        .else_body = else_body,
    };
    try block.instructions.append(self.gpa, &inst.base);
    return &inst.base;
}

pub fn addCall(
    self: *Module,
    block: *Scope.Block,
    src: usize,
    ty: Type,
    func: *Inst,
    args: []const *Inst,
) !*Inst {
    const inst = try block.arena.create(Inst.Call);
    inst.* = .{
        .base = .{
            .tag = .call,
            .ty = ty,
            .src = src,
        },
        .func = func,
        .args = args,
    };
    try block.instructions.append(self.gpa, &inst.base);
    return &inst.base;
}

pub fn constInst(self: *Module, scope: *Scope, src: usize, typed_value: TypedValue) !*Inst {
    const const_inst = try scope.arena().create(Inst.Constant);
    const_inst.* = .{
        .base = .{
            .tag = Inst.Constant.base_tag,
            .ty = typed_value.ty,
            .src = src,
        },
        .val = typed_value.val,
    };
    return &const_inst.base;
}

pub fn constType(self: *Module, scope: *Scope, src: usize, ty: Type) !*Inst {
    return self.constInst(scope, src, .{
        .ty = Type.initTag(.type),
        .val = try ty.toValue(scope.arena()),
    });
}

pub fn constVoid(self: *Module, scope: *Scope, src: usize) !*Inst {
    return self.constInst(scope, src, .{
        .ty = Type.initTag(.void),
        .val = Value.initTag(.void_value),
    });
}

pub fn constNoReturn(self: *Module, scope: *Scope, src: usize) !*Inst {
    return self.constInst(scope, src, .{
        .ty = Type.initTag(.noreturn),
        .val = Value.initTag(.unreachable_value),
    });
}

pub fn constUndef(self: *Module, scope: *Scope, src: usize, ty: Type) !*Inst {
    return self.constInst(scope, src, .{
        .ty = ty,
        .val = Value.initTag(.undef),
    });
}

pub fn constBool(self: *Module, scope: *Scope, src: usize, v: bool) !*Inst {
    return self.constInst(scope, src, .{
        .ty = Type.initTag(.bool),
        .val = ([2]Value{ Value.initTag(.bool_false), Value.initTag(.bool_true) })[@boolToInt(v)],
    });
}

pub fn constIntUnsigned(self: *Module, scope: *Scope, src: usize, ty: Type, int: u64) !*Inst {
    const int_payload = try scope.arena().create(Value.Payload.Int_u64);
    int_payload.* = .{ .int = int };

    return self.constInst(scope, src, .{
        .ty = ty,
        .val = Value.initPayload(&int_payload.base),
    });
}

pub fn constIntSigned(self: *Module, scope: *Scope, src: usize, ty: Type, int: i64) !*Inst {
    const int_payload = try scope.arena().create(Value.Payload.Int_i64);
    int_payload.* = .{ .int = int };

    return self.constInst(scope, src, .{
        .ty = ty,
        .val = Value.initPayload(&int_payload.base),
    });
}

pub fn constIntBig(self: *Module, scope: *Scope, src: usize, ty: Type, big_int: BigIntConst) !*Inst {
    const val_payload = if (big_int.positive) blk: {
        if (big_int.to(u64)) |x| {
            return self.constIntUnsigned(scope, src, ty, x);
        } else |err| switch (err) {
            error.NegativeIntoUnsigned => unreachable,
            error.TargetTooSmall => {}, // handled below
        }
        const big_int_payload = try scope.arena().create(Value.Payload.IntBigPositive);
        big_int_payload.* = .{ .limbs = big_int.limbs };
        break :blk &big_int_payload.base;
    } else blk: {
        if (big_int.to(i64)) |x| {
            return self.constIntSigned(scope, src, ty, x);
        } else |err| switch (err) {
            error.NegativeIntoUnsigned => unreachable,
            error.TargetTooSmall => {}, // handled below
        }
        const big_int_payload = try scope.arena().create(Value.Payload.IntBigNegative);
        big_int_payload.* = .{ .limbs = big_int.limbs };
        break :blk &big_int_payload.base;
    };

    return self.constInst(scope, src, .{
        .ty = ty,
        .val = Value.initPayload(val_payload),
    });
}

pub fn createAnonymousDecl(
    self: *Module,
    scope: *Scope,
    decl_arena: *std.heap.ArenaAllocator,
    typed_value: TypedValue,
) !*Decl {
    const name_index = self.getNextAnonNameIndex();
    const scope_decl = scope.decl().?;
    const name = try std.fmt.allocPrint(self.gpa, "{}__anon_{}", .{ scope_decl.name, name_index });
    defer self.gpa.free(name);
    const name_hash = scope.namespace().fullyQualifiedNameHash(name);
    const src_hash: std.zig.SrcHash = undefined;
    const new_decl = try self.createNewDecl(scope, name, scope_decl.src_index, name_hash, src_hash);
    const decl_arena_state = try decl_arena.allocator.create(std.heap.ArenaAllocator.State);

    decl_arena_state.* = decl_arena.state;
    new_decl.typed_value = .{
        .most_recent = .{
            .typed_value = typed_value,
            .arena = decl_arena_state,
        },
    };
    new_decl.analysis = .complete;
    new_decl.generation = self.generation;

    // TODO: This generates the Decl into the machine code file if it is of a type that is non-zero size.
    // We should be able to further improve the compiler to not omit Decls which are only referenced at
    // compile-time and not runtime.
    if (typed_value.ty.hasCodeGenBits()) {
        try self.bin_file.allocateDeclIndexes(new_decl);
        try self.work_queue.writeItem(.{ .codegen_decl = new_decl });
    }

    return new_decl;
}

fn getNextAnonNameIndex(self: *Module) usize {
    return @atomicRmw(usize, &self.next_anon_name_index, .Add, 1, .Monotonic);
}

pub fn lookupDeclName(self: *Module, scope: *Scope, ident_name: []const u8) ?*Decl {
    const namespace = scope.namespace();
    const name_hash = namespace.fullyQualifiedNameHash(ident_name);
    return self.decl_table.get(name_hash);
}

pub fn analyzeDeclRef(self: *Module, scope: *Scope, src: usize, decl: *Decl) InnerError!*Inst {
    const scope_decl = scope.decl().?;
    try self.declareDeclDependency(scope_decl, decl);
    self.ensureDeclAnalyzed(decl) catch |err| {
        if (scope.cast(Scope.Block)) |block| {
            if (block.func) |func| {
                func.analysis = .dependency_failure;
            } else {
                block.decl.analysis = .dependency_failure;
            }
        } else {
            scope_decl.analysis = .dependency_failure;
        }
        return err;
    };

    const decl_tv = try decl.typedValue();
    if (decl_tv.val.tag() == .variable) {
        return self.analyzeVarRef(scope, src, decl_tv);
    }
    const ty = try self.simplePtrType(scope, src, decl_tv.ty, false, .One);
    const val_payload = try scope.arena().create(Value.Payload.DeclRef);
    val_payload.* = .{ .decl = decl };

    return self.constInst(scope, src, .{
        .ty = ty,
        .val = Value.initPayload(&val_payload.base),
    });
}

fn analyzeVarRef(self: *Module, scope: *Scope, src: usize, tv: TypedValue) InnerError!*Inst {
    const variable = tv.val.cast(Value.Payload.Variable).?.variable;

    const ty = try self.simplePtrType(scope, src, tv.ty, variable.is_mutable, .One);
    if (!variable.is_mutable and !variable.is_extern) {
        const val_payload = try scope.arena().create(Value.Payload.RefVal);
        val_payload.* = .{ .val = variable.init };
        return self.constInst(scope, src, .{
            .ty = ty,
            .val = Value.initPayload(&val_payload.base),
        });
    }

    const b = try self.requireRuntimeBlock(scope, src);
    const inst = try b.arena.create(Inst.VarPtr);
    inst.* = .{
        .base = .{
            .tag = .varptr,
            .ty = ty,
            .src = src,
        },
        .variable = variable,
    };
    try b.instructions.append(self.gpa, &inst.base);
    return &inst.base;
}

pub fn analyzeDeref(self: *Module, scope: *Scope, src: usize, ptr: *Inst, ptr_src: usize) InnerError!*Inst {
    const elem_ty = switch (ptr.ty.zigTypeTag()) {
        .Pointer => ptr.ty.elemType(),
        else => return self.fail(scope, ptr_src, "expected pointer, found '{}'", .{ptr.ty}),
    };
    if (ptr.value()) |val| {
        return self.constInst(scope, src, .{
            .ty = elem_ty,
            .val = try val.pointerDeref(scope.arena()),
        });
    }

    const b = try self.requireRuntimeBlock(scope, src);
    return self.addUnOp(b, src, elem_ty, .load, ptr);
}

pub fn analyzeDeclRefByName(self: *Module, scope: *Scope, src: usize, decl_name: []const u8) InnerError!*Inst {
    const decl = self.lookupDeclName(scope, decl_name) orelse
        return self.fail(scope, src, "decl '{}' not found", .{decl_name});
    return self.analyzeDeclRef(scope, src, decl);
}

pub fn wantSafety(self: *Module, scope: *Scope) bool {
    // TODO take into account scope's safety overrides
    return switch (self.optimizeMode()) {
        .Debug => true,
        .ReleaseSafe => true,
        .ReleaseFast => false,
        .ReleaseSmall => false,
    };
}

pub fn analyzeIsNull(
    self: *Module,
    scope: *Scope,
    src: usize,
    operand: *Inst,
    invert_logic: bool,
) InnerError!*Inst {
    if (operand.value()) |opt_val| {
        const is_null = opt_val.isNull();
        const bool_value = if (invert_logic) !is_null else is_null;
        return self.constBool(scope, src, bool_value);
    }
    const b = try self.requireRuntimeBlock(scope, src);
    const inst_tag: Inst.Tag = if (invert_logic) .isnonnull else .isnull;
    return self.addUnOp(b, src, Type.initTag(.bool), inst_tag, operand);
}

pub fn analyzeIsErr(self: *Module, scope: *Scope, src: usize, operand: *Inst) InnerError!*Inst {
    return self.fail(scope, src, "TODO implement analysis of iserr", .{});
}

pub fn analyzeSlice(self: *Module, scope: *Scope, src: usize, array_ptr: *Inst, start: *Inst, end_opt: ?*Inst, sentinel_opt: ?*Inst) InnerError!*Inst {
    const ptr_child = switch (array_ptr.ty.zigTypeTag()) {
        .Pointer => array_ptr.ty.elemType(),
        else => return self.fail(scope, src, "expected pointer, found '{}'", .{array_ptr.ty}),
    };

    var array_type = ptr_child;
    const elem_type = switch (ptr_child.zigTypeTag()) {
        .Array => ptr_child.elemType(),
        .Pointer => blk: {
            if (ptr_child.isSinglePointer()) {
                if (ptr_child.elemType().zigTypeTag() == .Array) {
                    array_type = ptr_child.elemType();
                    break :blk ptr_child.elemType().elemType();
                }

                return self.fail(scope, src, "slice of single-item pointer", .{});
            }
            break :blk ptr_child.elemType();
        },
        else => return self.fail(scope, src, "slice of non-array type '{}'", .{ptr_child}),
    };

    const slice_sentinel = if (sentinel_opt) |sentinel| blk: {
        const casted = try self.coerce(scope, elem_type, sentinel);
        break :blk try self.resolveConstValue(scope, casted);
    } else null;

    var return_ptr_size: std.builtin.TypeInfo.Pointer.Size = .Slice;
    var return_elem_type = elem_type;
    if (end_opt) |end| {
        if (end.value()) |end_val| {
            if (start.value()) |start_val| {
                const start_u64 = start_val.toUnsignedInt();
                const end_u64 = end_val.toUnsignedInt();
                if (start_u64 > end_u64) {
                    return self.fail(scope, src, "out of bounds slice", .{});
                }

                const len = end_u64 - start_u64;
                const array_sentinel = if (array_type.zigTypeTag() == .Array and end_u64 == array_type.arrayLen())
                    array_type.sentinel()
                else
                    slice_sentinel;
                return_elem_type = try self.arrayType(scope, len, array_sentinel, elem_type);
                return_ptr_size = .One;
            }
        }
    }
    const return_type = try self.ptrType(
        scope,
        src,
        return_elem_type,
        if (end_opt == null) slice_sentinel else null,
        0, // TODO alignment
        0,
        0,
        !ptr_child.isConstPtr(),
        ptr_child.isAllowzeroPtr(),
        ptr_child.isVolatilePtr(),
        return_ptr_size,
    );

    return self.fail(scope, src, "TODO implement analysis of slice", .{});
}

/// Asserts that lhs and rhs types are both numeric.
pub fn cmpNumeric(
    self: *Module,
    scope: *Scope,
    src: usize,
    lhs: *Inst,
    rhs: *Inst,
    op: std.math.CompareOperator,
) !*Inst {
    assert(lhs.ty.isNumeric());
    assert(rhs.ty.isNumeric());

    const lhs_ty_tag = lhs.ty.zigTypeTag();
    const rhs_ty_tag = rhs.ty.zigTypeTag();

    if (lhs_ty_tag == .Vector and rhs_ty_tag == .Vector) {
        if (lhs.ty.arrayLen() != rhs.ty.arrayLen()) {
            return self.fail(scope, src, "vector length mismatch: {} and {}", .{
                lhs.ty.arrayLen(),
                rhs.ty.arrayLen(),
            });
        }
        return self.fail(scope, src, "TODO implement support for vectors in cmpNumeric", .{});
    } else if (lhs_ty_tag == .Vector or rhs_ty_tag == .Vector) {
        return self.fail(scope, src, "mixed scalar and vector operands to comparison operator: '{}' and '{}'", .{
            lhs.ty,
            rhs.ty,
        });
    }

    if (lhs.value()) |lhs_val| {
        if (rhs.value()) |rhs_val| {
            return self.constBool(scope, src, Value.compare(lhs_val, op, rhs_val));
        }
    }

    // TODO handle comparisons against lazy zero values
    // Some values can be compared against zero without being runtime known or without forcing
    // a full resolution of their value, for example `@sizeOf(@Frame(function))` is known to
    // always be nonzero, and we benefit from not forcing the full evaluation and stack frame layout
    // of this function if we don't need to.

    // It must be a runtime comparison.
    const b = try self.requireRuntimeBlock(scope, src);
    // For floats, emit a float comparison instruction.
    const lhs_is_float = switch (lhs_ty_tag) {
        .Float, .ComptimeFloat => true,
        else => false,
    };
    const rhs_is_float = switch (rhs_ty_tag) {
        .Float, .ComptimeFloat => true,
        else => false,
    };
    if (lhs_is_float and rhs_is_float) {
        // Implicit cast the smaller one to the larger one.
        const dest_type = x: {
            if (lhs_ty_tag == .ComptimeFloat) {
                break :x rhs.ty;
            } else if (rhs_ty_tag == .ComptimeFloat) {
                break :x lhs.ty;
            }
            if (lhs.ty.floatBits(self.getTarget()) >= rhs.ty.floatBits(self.getTarget())) {
                break :x lhs.ty;
            } else {
                break :x rhs.ty;
            }
        };
        const casted_lhs = try self.coerce(scope, dest_type, lhs);
        const casted_rhs = try self.coerce(scope, dest_type, rhs);
        return self.addBinOp(b, src, dest_type, Inst.Tag.fromCmpOp(op), casted_lhs, casted_rhs);
    }
    // For mixed unsigned integer sizes, implicit cast both operands to the larger integer.
    // For mixed signed and unsigned integers, implicit cast both operands to a signed
    // integer with + 1 bit.
    // For mixed floats and integers, extract the integer part from the float, cast that to
    // a signed integer with mantissa bits + 1, and if there was any non-integral part of the float,
    // add/subtract 1.
    const lhs_is_signed = if (lhs.value()) |lhs_val|
        lhs_val.compareWithZero(.lt)
    else
        (lhs.ty.isFloat() or lhs.ty.isSignedInt());
    const rhs_is_signed = if (rhs.value()) |rhs_val|
        rhs_val.compareWithZero(.lt)
    else
        (rhs.ty.isFloat() or rhs.ty.isSignedInt());
    const dest_int_is_signed = lhs_is_signed or rhs_is_signed;

    var dest_float_type: ?Type = null;

    var lhs_bits: usize = undefined;
    if (lhs.value()) |lhs_val| {
        if (lhs_val.isUndef())
            return self.constUndef(scope, src, Type.initTag(.bool));
        const is_unsigned = if (lhs_is_float) x: {
            var bigint_space: Value.BigIntSpace = undefined;
            var bigint = try lhs_val.toBigInt(&bigint_space).toManaged(self.gpa);
            defer bigint.deinit();
            const zcmp = lhs_val.orderAgainstZero();
            if (lhs_val.floatHasFraction()) {
                switch (op) {
                    .eq => return self.constBool(scope, src, false),
                    .neq => return self.constBool(scope, src, true),
                    else => {},
                }
                if (zcmp == .lt) {
                    try bigint.addScalar(bigint.toConst(), -1);
                } else {
                    try bigint.addScalar(bigint.toConst(), 1);
                }
            }
            lhs_bits = bigint.toConst().bitCountTwosComp();
            break :x (zcmp != .lt);
        } else x: {
            lhs_bits = lhs_val.intBitCountTwosComp();
            break :x (lhs_val.orderAgainstZero() != .lt);
        };
        lhs_bits += @boolToInt(is_unsigned and dest_int_is_signed);
    } else if (lhs_is_float) {
        dest_float_type = lhs.ty;
    } else {
        const int_info = lhs.ty.intInfo(self.getTarget());
        lhs_bits = int_info.bits + @boolToInt(!int_info.signed and dest_int_is_signed);
    }

    var rhs_bits: usize = undefined;
    if (rhs.value()) |rhs_val| {
        if (rhs_val.isUndef())
            return self.constUndef(scope, src, Type.initTag(.bool));
        const is_unsigned = if (rhs_is_float) x: {
            var bigint_space: Value.BigIntSpace = undefined;
            var bigint = try rhs_val.toBigInt(&bigint_space).toManaged(self.gpa);
            defer bigint.deinit();
            const zcmp = rhs_val.orderAgainstZero();
            if (rhs_val.floatHasFraction()) {
                switch (op) {
                    .eq => return self.constBool(scope, src, false),
                    .neq => return self.constBool(scope, src, true),
                    else => {},
                }
                if (zcmp == .lt) {
                    try bigint.addScalar(bigint.toConst(), -1);
                } else {
                    try bigint.addScalar(bigint.toConst(), 1);
                }
            }
            rhs_bits = bigint.toConst().bitCountTwosComp();
            break :x (zcmp != .lt);
        } else x: {
            rhs_bits = rhs_val.intBitCountTwosComp();
            break :x (rhs_val.orderAgainstZero() != .lt);
        };
        rhs_bits += @boolToInt(is_unsigned and dest_int_is_signed);
    } else if (rhs_is_float) {
        dest_float_type = rhs.ty;
    } else {
        const int_info = rhs.ty.intInfo(self.getTarget());
        rhs_bits = int_info.bits + @boolToInt(!int_info.signed and dest_int_is_signed);
    }

    const dest_type = if (dest_float_type) |ft| ft else blk: {
        const max_bits = std.math.max(lhs_bits, rhs_bits);
        const casted_bits = std.math.cast(u16, max_bits) catch |err| switch (err) {
            error.Overflow => return self.fail(scope, src, "{} exceeds maximum integer bit count", .{max_bits}),
        };
        break :blk try self.makeIntType(scope, dest_int_is_signed, casted_bits);
    };
    const casted_lhs = try self.coerce(scope, dest_type, lhs);
    const casted_rhs = try self.coerce(scope, dest_type, rhs);

    return self.addBinOp(b, src, Type.initTag(.bool), Inst.Tag.fromCmpOp(op), casted_lhs, casted_rhs);
}

fn wrapOptional(self: *Module, scope: *Scope, dest_type: Type, inst: *Inst) !*Inst {
    if (inst.value()) |val| {
        return self.constInst(scope, inst.src, .{ .ty = dest_type, .val = val });
    }

    const b = try self.requireRuntimeBlock(scope, inst.src);
    return self.addUnOp(b, inst.src, dest_type, .wrap_optional, inst);
}

fn makeIntType(self: *Module, scope: *Scope, signed: bool, bits: u16) !Type {
    if (signed) {
        const int_payload = try scope.arena().create(Type.Payload.IntSigned);
        int_payload.* = .{ .bits = bits };
        return Type.initPayload(&int_payload.base);
    } else {
        const int_payload = try scope.arena().create(Type.Payload.IntUnsigned);
        int_payload.* = .{ .bits = bits };
        return Type.initPayload(&int_payload.base);
    }
}

pub fn resolvePeerTypes(self: *Module, scope: *Scope, instructions: []*Inst) !Type {
    if (instructions.len == 0)
        return Type.initTag(.noreturn);

    if (instructions.len == 1)
        return instructions[0].ty;

    var prev_inst = instructions[0];
    for (instructions[1..]) |next_inst| {
        if (next_inst.ty.eql(prev_inst.ty))
            continue;
        if (next_inst.ty.zigTypeTag() == .NoReturn)
            continue;
        if (prev_inst.ty.zigTypeTag() == .NoReturn) {
            prev_inst = next_inst;
            continue;
        }
        if (next_inst.ty.zigTypeTag() == .Undefined)
            continue;
        if (prev_inst.ty.zigTypeTag() == .Undefined) {
            prev_inst = next_inst;
            continue;
        }
        if (prev_inst.ty.isInt() and
            next_inst.ty.isInt() and
            prev_inst.ty.isSignedInt() == next_inst.ty.isSignedInt())
        {
            if (prev_inst.ty.intInfo(self.getTarget()).bits < next_inst.ty.intInfo(self.getTarget()).bits) {
                prev_inst = next_inst;
            }
            continue;
        }
        if (prev_inst.ty.isFloat() and next_inst.ty.isFloat()) {
            if (prev_inst.ty.floatBits(self.getTarget()) < next_inst.ty.floatBits(self.getTarget())) {
                prev_inst = next_inst;
            }
            continue;
        }

        // TODO error notes pointing out each type
        return self.fail(scope, next_inst.src, "incompatible types: '{}' and '{}'", .{ prev_inst.ty, next_inst.ty });
    }

    return prev_inst.ty;
}

pub fn coerce(self: *Module, scope: *Scope, dest_type: Type, inst: *Inst) !*Inst {
    // If the types are the same, we can return the operand.
    if (dest_type.eql(inst.ty))
        return inst;

    const in_memory_result = coerceInMemoryAllowed(dest_type, inst.ty);
    if (in_memory_result == .ok) {
        return self.bitcast(scope, dest_type, inst);
    }

    // undefined to anything
    if (inst.value()) |val| {
        if (val.isUndef() or inst.ty.zigTypeTag() == .Undefined) {
            return self.constInst(scope, inst.src, .{ .ty = dest_type, .val = val });
        }
    }
    assert(inst.ty.zigTypeTag() != .Undefined);

    // null to ?T
    if (dest_type.zigTypeTag() == .Optional and inst.ty.zigTypeTag() == .Null) {
        return self.constInst(scope, inst.src, .{ .ty = dest_type, .val = Value.initTag(.null_value) });
    }

    // T to ?T
    if (dest_type.zigTypeTag() == .Optional) {
        var buf: Type.Payload.PointerSimple = undefined;
        const child_type = dest_type.optionalChild(&buf);
        if (child_type.eql(inst.ty)) {
            return self.wrapOptional(scope, dest_type, inst);
        } else if (try self.coerceNum(scope, child_type, inst)) |some| {
            return self.wrapOptional(scope, dest_type, some);
        }
    }

    // *[N]T to []T
    if (inst.ty.isSinglePointer() and dest_type.isSlice() and
        (!inst.ty.isConstPtr() or dest_type.isConstPtr()))
    {
        const array_type = inst.ty.elemType();
        const dst_elem_type = dest_type.elemType();
        if (array_type.zigTypeTag() == .Array and
            coerceInMemoryAllowed(dst_elem_type, array_type.elemType()) == .ok)
        {
            return self.coerceArrayPtrToSlice(scope, dest_type, inst);
        }
    }

    // comptime known number to other number
    if (try self.coerceNum(scope, dest_type, inst)) |some|
        return some;

    // integer widening
    if (inst.ty.zigTypeTag() == .Int and dest_type.zigTypeTag() == .Int) {
        assert(inst.value() == null); // handled above

        const src_info = inst.ty.intInfo(self.getTarget());
        const dst_info = dest_type.intInfo(self.getTarget());
        if ((src_info.signed == dst_info.signed and dst_info.bits >= src_info.bits) or
        // small enough unsigned ints can get casted to large enough signed ints
            (src_info.signed and !dst_info.signed and dst_info.bits > src_info.bits))
        {
            const b = try self.requireRuntimeBlock(scope, inst.src);
            return self.addUnOp(b, inst.src, dest_type, .intcast, inst);
        }
    }

    // float widening
    if (inst.ty.zigTypeTag() == .Float and dest_type.zigTypeTag() == .Float) {
        assert(inst.value() == null); // handled above

        const src_bits = inst.ty.floatBits(self.getTarget());
        const dst_bits = dest_type.floatBits(self.getTarget());
        if (dst_bits >= src_bits) {
            const b = try self.requireRuntimeBlock(scope, inst.src);
            return self.addUnOp(b, inst.src, dest_type, .floatcast, inst);
        }
    }

    return self.fail(scope, inst.src, "expected {}, found {}", .{ dest_type, inst.ty });
}

pub fn coerceNum(self: *Module, scope: *Scope, dest_type: Type, inst: *Inst) !?*Inst {
    const val = inst.value() orelse return null;
    const src_zig_tag = inst.ty.zigTypeTag();
    const dst_zig_tag = dest_type.zigTypeTag();

    if (dst_zig_tag == .ComptimeInt or dst_zig_tag == .Int) {
        if (src_zig_tag == .Float or src_zig_tag == .ComptimeFloat) {
            if (val.floatHasFraction()) {
                return self.fail(scope, inst.src, "fractional component prevents float value {} from being casted to type '{}'", .{ val, inst.ty });
            }
            return self.fail(scope, inst.src, "TODO float to int", .{});
        } else if (src_zig_tag == .Int or src_zig_tag == .ComptimeInt) {
            if (!val.intFitsInType(dest_type, self.getTarget())) {
                return self.fail(scope, inst.src, "type {} cannot represent integer value {}", .{ inst.ty, val });
            }
            return self.constInst(scope, inst.src, .{ .ty = dest_type, .val = val });
        }
    } else if (dst_zig_tag == .ComptimeFloat or dst_zig_tag == .Float) {
        if (src_zig_tag == .Float or src_zig_tag == .ComptimeFloat) {
            const res = val.floatCast(scope.arena(), dest_type, self.getTarget()) catch |err| switch (err) {
                error.Overflow => return self.fail(
                    scope,
                    inst.src,
                    "cast of value {} to type '{}' loses information",
                    .{ val, dest_type },
                ),
                error.OutOfMemory => return error.OutOfMemory,
            };
            return self.constInst(scope, inst.src, .{ .ty = dest_type, .val = res });
        } else if (src_zig_tag == .Int or src_zig_tag == .ComptimeInt) {
            return self.fail(scope, inst.src, "TODO int to float", .{});
        }
    }
    return null;
}

pub fn storePtr(self: *Module, scope: *Scope, src: usize, ptr: *Inst, uncasted_value: *Inst) !*Inst {
    if (ptr.ty.isConstPtr())
        return self.fail(scope, src, "cannot assign to constant", .{});

    const elem_ty = ptr.ty.elemType();
    const value = try self.coerce(scope, elem_ty, uncasted_value);
    if (elem_ty.onePossibleValue() != null)
        return self.constVoid(scope, src);

    // TODO handle comptime pointer writes
    // TODO handle if the element type requires comptime

    const b = try self.requireRuntimeBlock(scope, src);
    return self.addBinOp(b, src, Type.initTag(.void), .store, ptr, value);
}

pub fn bitcast(self: *Module, scope: *Scope, dest_type: Type, inst: *Inst) !*Inst {
    if (inst.value()) |val| {
        // Keep the comptime Value representation; take the new type.
        return self.constInst(scope, inst.src, .{ .ty = dest_type, .val = val });
    }
    // TODO validate the type size and other compile errors
    const b = try self.requireRuntimeBlock(scope, inst.src);
    return self.addUnOp(b, inst.src, dest_type, .bitcast, inst);
}

fn coerceArrayPtrToSlice(self: *Module, scope: *Scope, dest_type: Type, inst: *Inst) !*Inst {
    if (inst.value()) |val| {
        // The comptime Value representation is compatible with both types.
        return self.constInst(scope, inst.src, .{ .ty = dest_type, .val = val });
    }
    return self.fail(scope, inst.src, "TODO implement coerceArrayPtrToSlice runtime instruction", .{});
}

fn failCObj(mod: *Module, c_object: *CObject, comptime format: []const u8, args: anytype) InnerError {
    @setCold(true);
    const err_msg = try ErrorMsg.create(mod.gpa, 0, "unable to build C object: " ++ format, args);
    return mod.failCObjWithOwnedErrorMsg(c_object, err_msg);
}

fn failCObjWithOwnedErrorMsg(mod: *Module, c_object: *CObject, err_msg: *ErrorMsg) InnerError {
    {
        errdefer err_msg.destroy(mod.gpa);
        try mod.failed_c_objects.ensureCapacity(mod.gpa, mod.failed_c_objects.items().len + 1);
    }
    mod.failed_c_objects.putAssumeCapacityNoClobber(c_object, err_msg);
    c_object.status = .{ .failure = "" };
    return error.AnalysisFail;
}

pub fn fail(self: *Module, scope: *Scope, src: usize, comptime format: []const u8, args: anytype) InnerError {
    @setCold(true);
    const err_msg = try ErrorMsg.create(self.gpa, src, format, args);
    return self.failWithOwnedErrorMsg(scope, src, err_msg);
}

pub fn failTok(
    self: *Module,
    scope: *Scope,
    token_index: ast.TokenIndex,
    comptime format: []const u8,
    args: anytype,
) InnerError {
    @setCold(true);
    const src = scope.tree().token_locs[token_index].start;
    return self.fail(scope, src, format, args);
}

pub fn failNode(
    self: *Module,
    scope: *Scope,
    ast_node: *ast.Node,
    comptime format: []const u8,
    args: anytype,
) InnerError {
    @setCold(true);
    const src = scope.tree().token_locs[ast_node.firstToken()].start;
    return self.fail(scope, src, format, args);
}

fn failWithOwnedErrorMsg(self: *Module, scope: *Scope, src: usize, err_msg: *ErrorMsg) InnerError {
    {
        errdefer err_msg.destroy(self.gpa);
        try self.failed_decls.ensureCapacity(self.gpa, self.failed_decls.items().len + 1);
        try self.failed_files.ensureCapacity(self.gpa, self.failed_files.items().len + 1);
    }
    switch (scope.tag) {
        .decl => {
            const decl = scope.cast(Scope.DeclAnalysis).?.decl;
            decl.analysis = .sema_failure;
            decl.generation = self.generation;
            self.failed_decls.putAssumeCapacityNoClobber(decl, err_msg);
        },
        .block => {
            const block = scope.cast(Scope.Block).?;
            if (block.func) |func| {
                func.analysis = .sema_failure;
            } else {
                block.decl.analysis = .sema_failure;
                block.decl.generation = self.generation;
            }
            self.failed_decls.putAssumeCapacityNoClobber(block.decl, err_msg);
        },
        .gen_zir => {
            const gen_zir = scope.cast(Scope.GenZIR).?;
            gen_zir.decl.analysis = .sema_failure;
            gen_zir.decl.generation = self.generation;
            self.failed_decls.putAssumeCapacityNoClobber(gen_zir.decl, err_msg);
        },
        .local_val => {
            const gen_zir = scope.cast(Scope.LocalVal).?.gen_zir;
            gen_zir.decl.analysis = .sema_failure;
            gen_zir.decl.generation = self.generation;
            self.failed_decls.putAssumeCapacityNoClobber(gen_zir.decl, err_msg);
        },
        .local_ptr => {
            const gen_zir = scope.cast(Scope.LocalPtr).?.gen_zir;
            gen_zir.decl.analysis = .sema_failure;
            gen_zir.decl.generation = self.generation;
            self.failed_decls.putAssumeCapacityNoClobber(gen_zir.decl, err_msg);
        },
        .zir_module => {
            const zir_module = scope.cast(Scope.ZIRModule).?;
            zir_module.status = .loaded_sema_failure;
            self.failed_files.putAssumeCapacityNoClobber(scope, err_msg);
        },
        .none => unreachable,
        .file => unreachable,
        .container => unreachable,
    }
    return error.AnalysisFail;
}

const InMemoryCoercionResult = enum {
    ok,
    no_match,
};

fn coerceInMemoryAllowed(dest_type: Type, src_type: Type) InMemoryCoercionResult {
    if (dest_type.eql(src_type))
        return .ok;

    // TODO: implement more of this function

    return .no_match;
}

pub const ErrorMsg = struct {
    byte_offset: usize,
    msg: []const u8,

    pub fn create(gpa: *Allocator, byte_offset: usize, comptime format: []const u8, args: anytype) !*ErrorMsg {
        const self = try gpa.create(ErrorMsg);
        errdefer gpa.destroy(self);
        self.* = try init(gpa, byte_offset, format, args);
        return self;
    }

    /// Assumes the ErrorMsg struct and msg were both allocated with allocator.
    pub fn destroy(self: *ErrorMsg, gpa: *Allocator) void {
        self.deinit(gpa);
        gpa.destroy(self);
    }

    pub fn init(gpa: *Allocator, byte_offset: usize, comptime format: []const u8, args: anytype) !ErrorMsg {
        return ErrorMsg{
            .byte_offset = byte_offset,
            .msg = try std.fmt.allocPrint(gpa, format, args),
        };
    }

    pub fn deinit(self: *ErrorMsg, gpa: *Allocator) void {
        gpa.free(self.msg);
        self.* = undefined;
    }
};

fn srcHashEql(a: std.zig.SrcHash, b: std.zig.SrcHash) bool {
    return @bitCast(u128, a) == @bitCast(u128, b);
}

pub fn intAdd(allocator: *Allocator, lhs: Value, rhs: Value) !Value {
    // TODO is this a performance issue? maybe we should try the operation without
    // resorting to BigInt first.
    var lhs_space: Value.BigIntSpace = undefined;
    var rhs_space: Value.BigIntSpace = undefined;
    const lhs_bigint = lhs.toBigInt(&lhs_space);
    const rhs_bigint = rhs.toBigInt(&rhs_space);
    const limbs = try allocator.alloc(
        std.math.big.Limb,
        std.math.max(lhs_bigint.limbs.len, rhs_bigint.limbs.len) + 1,
    );
    var result_bigint = BigIntMutable{ .limbs = limbs, .positive = undefined, .len = undefined };
    result_bigint.add(lhs_bigint, rhs_bigint);
    const result_limbs = result_bigint.limbs[0..result_bigint.len];

    const val_payload = if (result_bigint.positive) blk: {
        const val_payload = try allocator.create(Value.Payload.IntBigPositive);
        val_payload.* = .{ .limbs = result_limbs };
        break :blk &val_payload.base;
    } else blk: {
        const val_payload = try allocator.create(Value.Payload.IntBigNegative);
        val_payload.* = .{ .limbs = result_limbs };
        break :blk &val_payload.base;
    };

    return Value.initPayload(val_payload);
}

pub fn intSub(allocator: *Allocator, lhs: Value, rhs: Value) !Value {
    // TODO is this a performance issue? maybe we should try the operation without
    // resorting to BigInt first.
    var lhs_space: Value.BigIntSpace = undefined;
    var rhs_space: Value.BigIntSpace = undefined;
    const lhs_bigint = lhs.toBigInt(&lhs_space);
    const rhs_bigint = rhs.toBigInt(&rhs_space);
    const limbs = try allocator.alloc(
        std.math.big.Limb,
        std.math.max(lhs_bigint.limbs.len, rhs_bigint.limbs.len) + 1,
    );
    var result_bigint = BigIntMutable{ .limbs = limbs, .positive = undefined, .len = undefined };
    result_bigint.sub(lhs_bigint, rhs_bigint);
    const result_limbs = result_bigint.limbs[0..result_bigint.len];

    const val_payload = if (result_bigint.positive) blk: {
        const val_payload = try allocator.create(Value.Payload.IntBigPositive);
        val_payload.* = .{ .limbs = result_limbs };
        break :blk &val_payload.base;
    } else blk: {
        const val_payload = try allocator.create(Value.Payload.IntBigNegative);
        val_payload.* = .{ .limbs = result_limbs };
        break :blk &val_payload.base;
    };

    return Value.initPayload(val_payload);
}

pub fn floatAdd(self: *Module, scope: *Scope, float_type: Type, src: usize, lhs: Value, rhs: Value) !Value {
    var bit_count = switch (float_type.tag()) {
        .comptime_float => 128,
        else => float_type.floatBits(self.getTarget()),
    };

    const allocator = scope.arena();
    const val_payload = switch (bit_count) {
        16 => {
            return self.fail(scope, src, "TODO Implement addition for soft floats", .{});
        },
        32 => blk: {
            const lhs_val = lhs.toFloat(f32);
            const rhs_val = rhs.toFloat(f32);
            const val_payload = try allocator.create(Value.Payload.Float_32);
            val_payload.* = .{ .val = lhs_val + rhs_val };
            break :blk &val_payload.base;
        },
        64 => blk: {
            const lhs_val = lhs.toFloat(f64);
            const rhs_val = rhs.toFloat(f64);
            const val_payload = try allocator.create(Value.Payload.Float_64);
            val_payload.* = .{ .val = lhs_val + rhs_val };
            break :blk &val_payload.base;
        },
        128 => {
            return self.fail(scope, src, "TODO Implement addition for big floats", .{});
        },
        else => unreachable,
    };

    return Value.initPayload(val_payload);
}

pub fn floatSub(self: *Module, scope: *Scope, float_type: Type, src: usize, lhs: Value, rhs: Value) !Value {
    var bit_count = switch (float_type.tag()) {
        .comptime_float => 128,
        else => float_type.floatBits(self.getTarget()),
    };

    const allocator = scope.arena();
    const val_payload = switch (bit_count) {
        16 => {
            return self.fail(scope, src, "TODO Implement substraction for soft floats", .{});
        },
        32 => blk: {
            const lhs_val = lhs.toFloat(f32);
            const rhs_val = rhs.toFloat(f32);
            const val_payload = try allocator.create(Value.Payload.Float_32);
            val_payload.* = .{ .val = lhs_val - rhs_val };
            break :blk &val_payload.base;
        },
        64 => blk: {
            const lhs_val = lhs.toFloat(f64);
            const rhs_val = rhs.toFloat(f64);
            const val_payload = try allocator.create(Value.Payload.Float_64);
            val_payload.* = .{ .val = lhs_val - rhs_val };
            break :blk &val_payload.base;
        },
        128 => {
            return self.fail(scope, src, "TODO Implement substraction for big floats", .{});
        },
        else => unreachable,
    };

    return Value.initPayload(val_payload);
}

pub fn simplePtrType(self: *Module, scope: *Scope, src: usize, elem_ty: Type, mutable: bool, size: std.builtin.TypeInfo.Pointer.Size) Allocator.Error!Type {
    if (!mutable and size == .Slice and elem_ty.eql(Type.initTag(.u8))) {
        return Type.initTag(.const_slice_u8);
    }
    // TODO stage1 type inference bug
    const T = Type.Tag;

    const type_payload = try scope.arena().create(Type.Payload.PointerSimple);
    type_payload.* = .{
        .base = .{
            .tag = switch (size) {
                .One => if (mutable) T.single_mut_pointer else T.single_const_pointer,
                .Many => if (mutable) T.many_mut_pointer else T.many_const_pointer,
                .C => if (mutable) T.c_mut_pointer else T.c_const_pointer,
                .Slice => if (mutable) T.mut_slice else T.const_slice,
            },
        },
        .pointee_type = elem_ty,
    };
    return Type.initPayload(&type_payload.base);
}

pub fn ptrType(
    self: *Module,
    scope: *Scope,
    src: usize,
    elem_ty: Type,
    sentinel: ?Value,
    @"align": u32,
    bit_offset: u16,
    host_size: u16,
    mutable: bool,
    @"allowzero": bool,
    @"volatile": bool,
    size: std.builtin.TypeInfo.Pointer.Size,
) Allocator.Error!Type {
    assert(host_size == 0 or bit_offset < host_size * 8);

    // TODO check if type can be represented by simplePtrType
    const type_payload = try scope.arena().create(Type.Payload.Pointer);
    type_payload.* = .{
        .pointee_type = elem_ty,
        .sentinel = sentinel,
        .@"align" = @"align",
        .bit_offset = bit_offset,
        .host_size = host_size,
        .@"allowzero" = @"allowzero",
        .mutable = mutable,
        .@"volatile" = @"volatile",
        .size = size,
    };
    return Type.initPayload(&type_payload.base);
}

pub fn optionalType(self: *Module, scope: *Scope, child_type: Type) Allocator.Error!Type {
    return Type.initPayload(switch (child_type.tag()) {
        .single_const_pointer => blk: {
            const payload = try scope.arena().create(Type.Payload.PointerSimple);
            payload.* = .{
                .base = .{ .tag = .optional_single_const_pointer },
                .pointee_type = child_type.elemType(),
            };
            break :blk &payload.base;
        },
        .single_mut_pointer => blk: {
            const payload = try scope.arena().create(Type.Payload.PointerSimple);
            payload.* = .{
                .base = .{ .tag = .optional_single_mut_pointer },
                .pointee_type = child_type.elemType(),
            };
            break :blk &payload.base;
        },
        else => blk: {
            const payload = try scope.arena().create(Type.Payload.Optional);
            payload.* = .{
                .child_type = child_type,
            };
            break :blk &payload.base;
        },
    });
}

pub fn arrayType(self: *Module, scope: *Scope, len: u64, sentinel: ?Value, elem_type: Type) Allocator.Error!Type {
    if (elem_type.eql(Type.initTag(.u8))) {
        if (sentinel) |some| {
            if (some.eql(Value.initTag(.zero))) {
                const payload = try scope.arena().create(Type.Payload.Array_u8_Sentinel0);
                payload.* = .{
                    .len = len,
                };
                return Type.initPayload(&payload.base);
            }
        } else {
            const payload = try scope.arena().create(Type.Payload.Array_u8);
            payload.* = .{
                .len = len,
            };
            return Type.initPayload(&payload.base);
        }
    }

    if (sentinel) |some| {
        const payload = try scope.arena().create(Type.Payload.ArraySentinel);
        payload.* = .{
            .len = len,
            .sentinel = some,
            .elem_type = elem_type,
        };
        return Type.initPayload(&payload.base);
    }

    const payload = try scope.arena().create(Type.Payload.Array);
    payload.* = .{
        .len = len,
        .elem_type = elem_type,
    };
    return Type.initPayload(&payload.base);
}

pub fn errorUnionType(self: *Module, scope: *Scope, error_set: Type, payload: Type) Allocator.Error!Type {
    assert(error_set.zigTypeTag() == .ErrorSet);
    if (error_set.eql(Type.initTag(.anyerror)) and payload.eql(Type.initTag(.void))) {
        return Type.initTag(.anyerror_void_error_union);
    }

    const result = try scope.arena().create(Type.Payload.ErrorUnion);
    result.* = .{
        .error_set = error_set,
        .payload = payload,
    };
    return Type.initPayload(&result.base);
}

pub fn anyframeType(self: *Module, scope: *Scope, return_type: Type) Allocator.Error!Type {
    const result = try scope.arena().create(Type.Payload.AnyFrame);
    result.* = .{
        .return_type = return_type,
    };
    return Type.initPayload(&result.base);
}

pub fn dumpInst(self: *Module, scope: *Scope, inst: *Inst) void {
    const zir_module = scope.namespace();
    const source = zir_module.getSource(self) catch @panic("dumpInst failed to get source");
    const loc = std.zig.findLineColumn(source, inst.src);
    if (inst.tag == .constant) {
        std.debug.print("constant ty={} val={} src={}:{}:{}\n", .{
            inst.ty,
            inst.castTag(.constant).?.val,
            zir_module.subFilePath(),
            loc.line + 1,
            loc.column + 1,
        });
    } else if (inst.deaths == 0) {
        std.debug.print("{} ty={} src={}:{}:{}\n", .{
            @tagName(inst.tag),
            inst.ty,
            zir_module.subFilePath(),
            loc.line + 1,
            loc.column + 1,
        });
    } else {
        std.debug.print("{} ty={} deaths={b} src={}:{}:{}\n", .{
            @tagName(inst.tag),
            inst.ty,
            inst.deaths,
            zir_module.subFilePath(),
            loc.line + 1,
            loc.column + 1,
        });
    }
}

pub const PanicId = enum {
    unreach,
    unwrap_null,
};

pub fn addSafetyCheck(mod: *Module, parent_block: *Scope.Block, ok: *Inst, panic_id: PanicId) !void {
    const block_inst = try parent_block.arena.create(Inst.Block);
    block_inst.* = .{
        .base = .{
            .tag = Inst.Block.base_tag,
            .ty = Type.initTag(.void),
            .src = ok.src,
        },
        .body = .{
            .instructions = try parent_block.arena.alloc(*Inst, 1), // Only need space for the condbr.
        },
    };

    const ok_body: ir.Body = .{
        .instructions = try parent_block.arena.alloc(*Inst, 1), // Only need space for the brvoid.
    };
    const brvoid = try parent_block.arena.create(Inst.BrVoid);
    brvoid.* = .{
        .base = .{
            .tag = .brvoid,
            .ty = Type.initTag(.noreturn),
            .src = ok.src,
        },
        .block = block_inst,
    };
    ok_body.instructions[0] = &brvoid.base;

    var fail_block: Scope.Block = .{
        .parent = parent_block,
        .func = parent_block.func,
        .decl = parent_block.decl,
        .instructions = .{},
        .arena = parent_block.arena,
        .is_comptime = parent_block.is_comptime,
    };
    defer fail_block.instructions.deinit(mod.gpa);

    _ = try mod.safetyPanic(&fail_block, ok.src, panic_id);

    const fail_body: ir.Body = .{ .instructions = try parent_block.arena.dupe(*Inst, fail_block.instructions.items) };

    const condbr = try parent_block.arena.create(Inst.CondBr);
    condbr.* = .{
        .base = .{
            .tag = .condbr,
            .ty = Type.initTag(.noreturn),
            .src = ok.src,
        },
        .condition = ok,
        .then_body = ok_body,
        .else_body = fail_body,
    };
    block_inst.body.instructions[0] = &condbr.base;

    try parent_block.instructions.append(mod.gpa, &block_inst.base);
}

pub fn safetyPanic(mod: *Module, block: *Scope.Block, src: usize, panic_id: PanicId) !*Inst {
    // TODO Once we have a panic function to call, call it here instead of breakpoint.
    _ = try mod.addNoOp(block, src, Type.initTag(.void), .breakpoint);
    return mod.addNoOp(block, src, Type.initTag(.noreturn), .unreach);
}

pub const FileExt = enum {
    c,
    cpp,
    h,
    ll,
    bc,
    assembly,
    so,
    unknown,
};

pub fn hasCExt(filename: []const u8) bool {
    return mem.endsWith(u8, filename, ".c");
}

pub fn hasCppExt(filename: []const u8) bool {
    return mem.endsWith(u8, filename, ".C") or
        mem.endsWith(u8, filename, ".cc") or
        mem.endsWith(u8, filename, ".cpp") or
        mem.endsWith(u8, filename, ".cxx");
}

pub fn hasAsmExt(filename: []const u8) bool {
    return mem.endsWith(u8, filename, ".s") or mem.endsWith(u8, filename, ".S");
}

pub fn classifyFileExt(filename: []const u8) FileExt {
    if (hasCExt(filename)) {
        return .c;
    } else if (hasCppExt(filename)) {
        return .cpp;
    } else if (mem.endsWith(u8, filename, ".ll")) {
        return .ll;
    } else if (mem.endsWith(u8, filename, ".bc")) {
        return .bc;
    } else if (hasAsmExt(filename)) {
        return .assembly;
    } else if (mem.endsWith(u8, filename, ".h")) {
        return .h;
    } else if (mem.endsWith(u8, filename, ".so")) {
        return .so;
    }
    // Look for .so.X, .so.X.Y, .so.X.Y.Z
    var it = mem.split(filename, ".");
    _ = it.next().?;
    var so_txt = it.next() orelse return .unknown;
    while (!mem.eql(u8, so_txt, "so")) {
        so_txt = it.next() orelse return .unknown;
    }
    const n1 = it.next() orelse return .unknown;
    const n2 = it.next();
    const n3 = it.next();

    _ = std.fmt.parseInt(u32, n1, 10) catch return .unknown;
    if (n2) |x| _ = std.fmt.parseInt(u32, x, 10) catch return .unknown;
    if (n3) |x| _ = std.fmt.parseInt(u32, x, 10) catch return .unknown;
    if (it.next() != null) return .unknown;

    return .so;
}

test "classifyFileExt" {
    std.testing.expectEqual(FileExt.cpp, classifyFileExt("foo.cc"));
    std.testing.expectEqual(FileExt.unknown, classifyFileExt("foo.nim"));
    std.testing.expectEqual(FileExt.so, classifyFileExt("foo.so"));
    std.testing.expectEqual(FileExt.so, classifyFileExt("foo.so.1"));
    std.testing.expectEqual(FileExt.so, classifyFileExt("foo.so.1.2"));
    std.testing.expectEqual(FileExt.so, classifyFileExt("foo.so.1.2.3"));
    std.testing.expectEqual(FileExt.unknown, classifyFileExt("foo.so.1.2.3~"));
}

fn haveFramePointer(mod: *Module) bool {
    return switch (mod.bin_file.options.optimize_mode) {
        .Debug, .ReleaseSafe => !mod.bin_file.options.strip,
        .ReleaseSmall, .ReleaseFast => false,
    };
}

const LibCDirs = struct {
    libc_include_dir_list: []const []const u8,
    libc_installation: ?*const LibCInstallation,
};

fn detectLibCIncludeDirs(
    arena: *Allocator,
    zig_lib_dir: []const u8,
    target: Target,
    is_native_os: bool,
    link_libc: bool,
    libc_installation: ?*const LibCInstallation,
) !LibCDirs {
    if (!link_libc) {
        return LibCDirs{
            .libc_include_dir_list = &[0][]u8{},
            .libc_installation = null,
        };
    }

    if (libc_installation) |lci| {
        return detectLibCFromLibCInstallation(arena, target, lci);
    }

    if (target_util.canBuildLibC(target)) {
        const generic_name = target_util.libCGenericName(target);
        // Some architectures are handled by the same set of headers.
        const arch_name = if (target.abi.isMusl()) target_util.archMuslName(target.cpu.arch) else @tagName(target.cpu.arch);
        const os_name = @tagName(target.os.tag);
        // Musl's headers are ABI-agnostic and so they all have the "musl" ABI name.
        const abi_name = if (target.abi.isMusl()) "musl" else @tagName(target.abi);
        const s = std.fs.path.sep_str;
        const arch_include_dir = try std.fmt.allocPrint(
            arena,
            "{}" ++ s ++ "libc" ++ s ++ "include" ++ s ++ "{}-{}-{}",
            .{ zig_lib_dir, arch_name, os_name, abi_name },
        );
        const generic_include_dir = try std.fmt.allocPrint(
            arena,
            "{}" ++ s ++ "libc" ++ s ++ "include" ++ s ++ "generic-{}",
            .{ zig_lib_dir, generic_name },
        );
        const arch_os_include_dir = try std.fmt.allocPrint(
            arena,
            "{}" ++ s ++ "libc" ++ s ++ "include" ++ s ++ "{}-{}-any",
            .{ zig_lib_dir, @tagName(target.cpu.arch), os_name },
        );
        const generic_os_include_dir = try std.fmt.allocPrint(
            arena,
            "{}" ++ s ++ "libc" ++ s ++ "include" ++ s ++ "any-{}-any",
            .{ zig_lib_dir, os_name },
        );

        const list = try arena.alloc([]const u8, 4);
        list[0] = arch_include_dir;
        list[1] = generic_include_dir;
        list[2] = arch_os_include_dir;
        list[3] = generic_os_include_dir;
        return LibCDirs{
            .libc_include_dir_list = list,
            .libc_installation = null,
        };
    }

    if (is_native_os) {
        const libc = try arena.create(LibCInstallation);
        libc.* = try LibCInstallation.findNative(.{ .allocator = arena });
        return detectLibCFromLibCInstallation(arena, target, libc);
    }

    return LibCDirs{
        .libc_include_dir_list = &[0][]u8{},
        .libc_installation = null,
    };
}

fn detectLibCFromLibCInstallation(arena: *Allocator, target: Target, lci: *const LibCInstallation) !LibCDirs {
    var list = std.ArrayList([]const u8).init(arena);
    try list.ensureCapacity(4);

    list.appendAssumeCapacity(lci.include_dir.?);

    const is_redundant = mem.eql(u8, lci.sys_include_dir.?, lci.include_dir.?);
    if (!is_redundant) list.appendAssumeCapacity(lci.sys_include_dir.?);

    if (target.os.tag == .windows) {
        if (std.fs.path.dirname(lci.include_dir.?)) |include_dir_parent| {
            const um_dir = try std.fs.path.join(arena, &[_][]const u8{ include_dir_parent, "um" });
            list.appendAssumeCapacity(um_dir);

            const shared_dir = try std.fs.path.join(arena, &[_][]const u8{ include_dir_parent, "shared" });
            list.appendAssumeCapacity(shared_dir);
        }
    }
    return LibCDirs{
        .libc_include_dir_list = list.items,
        .libc_installation = lci,
    };
}

pub fn get_libc_crt_file(mod: *Module, arena: *Allocator, basename: []const u8) ![]const u8 {
    // TODO port support for building crt files from stage1
    const lci = mod.bin_file.options.libc_installation orelse return error.LibCInstallationNotAvailable;
    const crt_dir_path = lci.crt_dir orelse return error.LibCInstallationMissingCRTDir;
    const full_path = try std.fs.path.join(arena, &[_][]const u8{ crt_dir_path, basename });
    return full_path;
}
