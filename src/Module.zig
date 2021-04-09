//! Compilation of all Zig source code is represented by one `Module`.
//! Each `Compilation` has exactly one or zero `Module`, depending on whether
//! there is or is not any zig source code, respectively.

const std = @import("std");
const mem = std.mem;
const Allocator = std.mem.Allocator;
const ArrayListUnmanaged = std.ArrayListUnmanaged;
const assert = std.debug.assert;
const log = std.log.scoped(.module);
const BigIntConst = std.math.big.int.Const;
const BigIntMutable = std.math.big.int.Mutable;
const Target = std.Target;
const ast = std.zig.ast;

const Module = @This();
const Compilation = @import("Compilation.zig");
const Value = @import("value.zig").Value;
const Type = @import("type.zig").Type;
const TypedValue = @import("TypedValue.zig");
const Package = @import("Package.zig");
const link = @import("link.zig");
const ir = @import("ir.zig");
const zir = @import("zir.zig");
const trace = @import("tracy.zig").trace;
const AstGen = @import("AstGen.zig");
const Sema = @import("Sema.zig");
const target_util = @import("target.zig");

/// General-purpose allocator. Used for both temporary and long-term storage.
gpa: *Allocator,
comp: *Compilation,

/// Where our incremental compilation metadata serialization will go.
zig_cache_artifact_directory: Compilation.Directory,
/// Pointer to externally managed resource. `null` if there is no zig file being compiled.
root_pkg: *Package,
/// Module owns this resource.
root_scope: *Scope.File,
/// It's rare for a decl to be exported, so we save memory by having a sparse map of
/// Decl pointers to details about them being exported.
/// The Export memory is owned by the `export_owners` table; the slice itself is owned by this table.
/// The slice is guaranteed to not be empty.
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
/// We optimize memory usage for a compilation with no compile errors by storing the
/// error messages and mapping outside of `Decl`.
/// The ErrorMsg memory is owned by the decl, using Module's general purpose allocator.
/// Note that a Decl can succeed but the Fn it represents can fail. In this case,
/// a Decl can have a failed_decls entry but have analysis status of success.
failed_decls: std.AutoArrayHashMapUnmanaged(*Decl, *ErrorMsg) = .{},
/// When emit_h is non-null, each Decl gets one more compile error slot for
/// emit-h failing for that Decl. This table is also how we tell if a Decl has
/// failed emit-h or succeeded.
emit_h_failed_decls: std.AutoArrayHashMapUnmanaged(*Decl, *ErrorMsg) = .{},
/// Keep track of one `@compileLog` callsite per owner Decl.
compile_log_decls: std.AutoArrayHashMapUnmanaged(*Decl, SrcLoc) = .{},
/// Using a map here for consistency with the other fields here.
/// The ErrorMsg memory is owned by the `Scope.File`, using Module's general purpose allocator.
failed_files: std.AutoArrayHashMapUnmanaged(*Scope.File, *ErrorMsg) = .{},
/// Using a map here for consistency with the other fields here.
/// The ErrorMsg memory is owned by the `Export`, using Module's general purpose allocator.
failed_exports: std.AutoArrayHashMapUnmanaged(*Export, *ErrorMsg) = .{},

next_anon_name_index: usize = 0,

/// Candidates for deletion. After a semantic analysis update completes, this list
/// contains Decls that need to be deleted if they end up having no references to them.
deletion_set: std.AutoArrayHashMapUnmanaged(*Decl, void) = .{},

/// Error tags and their values, tag names are duped with mod.gpa.
/// Corresponds with `error_name_list`.
global_error_set: std.StringHashMapUnmanaged(ErrorInt) = .{},

/// ErrorInt -> []const u8 for fast lookups for @intToError at comptime
/// Corresponds with `global_error_set`.
error_name_list: ArrayListUnmanaged([]const u8) = .{},

/// Keys are fully qualified paths
import_table: std.StringArrayHashMapUnmanaged(*Scope.File) = .{},

/// Incrementing integer used to compare against the corresponding Decl
/// field to determine whether a Decl's status applies to an ongoing update, or a
/// previous analysis.
generation: u32 = 0,

/// When populated it means there was an error opening/reading the root source file.
failed_root_src_file: ?anyerror = null,

stage1_flags: packed struct {
    have_winmain: bool = false,
    have_wwinmain: bool = false,
    have_winmain_crt_startup: bool = false,
    have_wwinmain_crt_startup: bool = false,
    have_dllmain_crt_startup: bool = false,
    have_c_main: bool = false,
    reserved: u2 = 0,
} = .{},

emit_h: ?Compilation.EmitLoc,

compile_log_text: ArrayListUnmanaged(u8) = .{},

pub const ErrorInt = u32;

pub const Export = struct {
    options: std.builtin.ExportOptions,
    src: LazySrcLoc,
    /// Represents the position of the export, if any, in the output file.
    link: link.File.Export,
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

/// When Module emit_h field is non-null, each Decl is allocated via this struct, so that
/// there can be EmitH state attached to each Decl.
pub const DeclPlusEmitH = struct {
    decl: Decl,
    emit_h: EmitH,
};

pub const Decl = struct {
    /// This name is relative to the containing namespace of the decl. It uses
    /// null-termination to save bytes, since there can be a lot of decls in a
    /// compilation. The null byte is not allowed in symbol names, because
    /// executable file formats use null-terminated strings for symbol names.
    /// All Decls have names, even values that are not bound to a zig namespace.
    /// This is necessary for mapping them to an address in the output file.
    /// Memory owned by this decl, using Module's allocator.
    name: [*:0]const u8,
    /// The direct parent container of the Decl.
    /// Reference to externally owned memory.
    container: *Scope.Container,

    /// An integer that can be checked against the corresponding incrementing
    /// generation field of Module. This is used to determine whether `complete` status
    /// represents pre- or post- re-analysis.
    generation: u32,
    /// The AST Node index or ZIR Inst index that contains this declaration.
    /// Must be recomputed when the corresponding source file is modified.
    src_node: ast.Node.Index,

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
    /// This flag is set when this Decl is added to `Module.deletion_set`, and cleared
    /// when removed.
    deletion_flag: bool,
    /// Whether the corresponding AST decl has a `pub` keyword.
    is_pub: bool,

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

    pub fn destroy(decl: *Decl, module: *Module) void {
        const gpa = module.gpa;
        gpa.free(mem.spanZ(decl.name));
        if (decl.typedValueManaged()) |tvm| {
            if (tvm.typed_value.val.castTag(.function)) |payload| {
                const func = payload.data;
                func.deinit(gpa);
            }
            tvm.deinit(gpa);
        }
        decl.dependants.deinit(gpa);
        decl.dependencies.deinit(gpa);
        if (module.emit_h != null) {
            const decl_plus_emit_h = @fieldParentPtr(DeclPlusEmitH, "decl", decl);
            decl_plus_emit_h.emit_h.fwd_decl.deinit(gpa);
            gpa.destroy(decl_plus_emit_h);
        } else {
            gpa.destroy(decl);
        }
    }

    pub fn relativeToNodeIndex(decl: Decl, offset: i32) ast.Node.Index {
        return @bitCast(ast.Node.Index, offset + @bitCast(i32, decl.src_node));
    }

    pub fn nodeIndexToRelative(decl: Decl, node_index: ast.Node.Index) i32 {
        return @bitCast(i32, node_index) - @bitCast(i32, decl.src_node);
    }

    pub fn tokSrcLoc(decl: Decl, token_index: ast.TokenIndex) LazySrcLoc {
        return .{ .token_offset = token_index - decl.srcToken() };
    }

    pub fn nodeSrcLoc(decl: Decl, node_index: ast.Node.Index) LazySrcLoc {
        return .{ .node_offset = decl.nodeIndexToRelative(node_index) };
    }

    pub fn srcLoc(decl: *Decl) SrcLoc {
        return .{
            .container = .{ .decl = decl },
            .lazy = .{ .node_offset = 0 },
        };
    }

    pub fn srcToken(decl: Decl) u32 {
        const tree = &decl.container.file_scope.tree;
        return tree.firstToken(decl.src_node);
    }

    pub fn srcByteOffset(decl: Decl) u32 {
        const tree = &decl.container.file_scope.tree;
        return tree.tokens.items(.start)[decl.srcToken()];
    }

    pub fn fullyQualifiedNameHash(decl: Decl) Scope.NameHash {
        return decl.container.fullyQualifiedNameHash(mem.spanZ(decl.name));
    }

    pub fn renderFullyQualifiedName(decl: Decl, writer: anytype) !void {
        const unqualified_name = mem.spanZ(decl.name);
        return decl.container.renderFullyQualifiedName(unqualified_name, writer);
    }

    pub fn getFullyQualifiedName(decl: Decl, gpa: *Allocator) ![]u8 {
        var buffer = std.ArrayList(u8).init(gpa);
        defer buffer.deinit();
        try decl.renderFullyQualifiedName(buffer.writer());
        return buffer.toOwnedSlice();
    }

    pub fn typedValue(decl: *Decl) error{AnalysisFail}!TypedValue {
        const tvm = decl.typedValueManaged() orelse return error.AnalysisFail;
        return tvm.typed_value;
    }

    pub fn value(decl: *Decl) error{AnalysisFail}!Value {
        return (try decl.typedValue()).val;
    }

    pub fn dump(decl: *Decl) void {
        const loc = std.zig.findLineColumn(decl.scope.source.bytes, decl.src);
        std.debug.print("{s}:{d}:{d} name={s} status={s}", .{
            decl.scope.sub_file_path,
            loc.line + 1,
            loc.column + 1,
            mem.spanZ(decl.name),
            @tagName(decl.analysis),
        });
        if (decl.typedValueManaged()) |tvm| {
            std.debug.print(" ty={} val={}", .{ tvm.typed_value.ty, tvm.typed_value.val });
        }
        std.debug.print("\n", .{});
    }

    pub fn typedValueManaged(decl: *Decl) ?*TypedValue.Managed {
        switch (decl.typed_value) {
            .most_recent => |*x| return x,
            .never_succeeded => return null,
        }
    }

    pub fn getFileScope(decl: Decl) *Scope.File {
        return decl.container.file_scope;
    }

    pub fn getEmitH(decl: *Decl, module: *Module) *EmitH {
        assert(module.emit_h != null);
        const decl_plus_emit_h = @fieldParentPtr(DeclPlusEmitH, "decl", decl);
        return &decl_plus_emit_h.emit_h;
    }

    fn removeDependant(decl: *Decl, other: *Decl) void {
        decl.dependants.removeAssertDiscard(other);
    }

    fn removeDependency(decl: *Decl, other: *Decl) void {
        decl.dependencies.removeAssertDiscard(other);
    }
};

/// This state is attached to every Decl when Module emit_h is non-null.
pub const EmitH = struct {
    fwd_decl: ArrayListUnmanaged(u8) = .{},
};

/// Represents the data that an explicit error set syntax provides.
pub const ErrorSet = struct {
    owner_decl: *Decl,
    /// Offset from Decl node index, points to the error set AST node.
    node_offset: i32,
    names_len: u32,
    /// The string bytes are stored in the owner Decl arena.
    /// They are in the same order they appear in the AST.
    names_ptr: [*]const []const u8,

    pub fn srcLoc(self: ErrorSet) SrcLoc {
        return .{
            .container = .{ .decl = self.owner_decl },
            .lazy = .{ .node_offset = self.node_offset },
        };
    }
};

/// Represents the data that a struct declaration provides.
pub const Struct = struct {
    owner_decl: *Decl,
    /// Set of field names in declaration order.
    fields: std.StringArrayHashMapUnmanaged(Field),
    /// Represents the declarations inside this struct.
    container: Scope.Container,

    /// Offset from `owner_decl`, points to the struct AST node.
    node_offset: i32,

    pub const Field = struct {
        ty: Type,
        abi_align: Value,
        /// Uses `unreachable_value` to indicate no default.
        default_val: Value,
    };

    pub fn getFullyQualifiedName(s: *Struct, gpa: *Allocator) ![]u8 {
        return s.owner_decl.getFullyQualifiedName(gpa);
    }

    pub fn srcLoc(s: Struct) SrcLoc {
        return .{
            .container = .{ .decl = s.owner_decl },
            .lazy = .{ .node_offset = s.node_offset },
        };
    }
};

/// Represents the data that an enum declaration provides, when the fields
/// are auto-numbered, and there are no declarations. The integer tag type
/// is inferred to be the smallest power of two unsigned int that fits
/// the number of fields.
pub const EnumSimple = struct {
    owner_decl: *Decl,
    /// Set of field names in declaration order.
    fields: std.StringArrayHashMapUnmanaged(void),
    /// Offset from `owner_decl`, points to the enum decl AST node.
    node_offset: i32,

    pub fn srcLoc(self: EnumSimple) SrcLoc {
        return .{
            .container = .{ .decl = self.owner_decl },
            .lazy = .{ .node_offset = self.node_offset },
        };
    }
};

/// Represents the data that an enum declaration provides, when there is
/// at least one tag value explicitly specified, or at least one declaration.
pub const EnumFull = struct {
    owner_decl: *Decl,
    /// An integer type which is used for the numerical value of the enum.
    /// Whether zig chooses this type or the user specifies it, it is stored here.
    tag_ty: Type,
    /// Set of field names in declaration order.
    fields: std.StringArrayHashMapUnmanaged(void),
    /// Maps integer tag value to field index.
    /// Entries are in declaration order, same as `fields`.
    /// If this hash map is empty, it means the enum tags are auto-numbered.
    values: ValueMap,
    /// Represents the declarations inside this struct.
    container: Scope.Container,
    /// Offset from `owner_decl`, points to the enum decl AST node.
    node_offset: i32,

    pub const ValueMap = std.ArrayHashMapUnmanaged(Value, void, Value.hash_u32, Value.eql, false);

    pub fn srcLoc(self: EnumFull) SrcLoc {
        return .{
            .container = .{ .decl = self.owner_decl },
            .lazy = .{ .node_offset = self.node_offset },
        };
    }
};

/// Some Fn struct memory is owned by the Decl's TypedValue.Managed arena allocator.
/// Extern functions do not have this data structure; they are represented by
/// the `Decl` only, with a `Value` tag of `extern_fn`.
pub const Fn = struct {
    owner_decl: *Decl,
    /// Contains un-analyzed ZIR instructions generated from Zig source AST.
    /// Even after we finish analysis, the ZIR is kept in memory, so that
    /// comptime and inline function calls can happen.
    /// Parameter names are stored here so that they may be referenced for debug info,
    /// without having source code bytes loaded into memory.
    /// The number of parameters is determined by referring to the type.
    /// The first N elements of `extra` are indexes into `string_bytes` to
    /// a null-terminated string.
    /// This memory is managed with gpa, must be freed when the function is freed.
    zir: zir.Code,
    /// undefined unless analysis state is `success`.
    body: ir.Body,
    state: Analysis,

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

    /// For debugging purposes.
    pub fn dump(func: *Fn, mod: Module) void {
        ir.dumpFn(mod, func);
    }

    pub fn deinit(func: *Fn, gpa: *Allocator) void {
        func.zir.deinit(gpa);
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

    /// Returns the arena Allocator associated with the Decl of the Scope.
    pub fn arena(scope: *Scope) *Allocator {
        switch (scope.tag) {
            .block => return scope.cast(Block).?.sema.arena,
            .gen_zir => return scope.cast(GenZir).?.astgen.arena,
            .local_val => return scope.cast(LocalVal).?.gen_zir.astgen.arena,
            .local_ptr => return scope.cast(LocalPtr).?.gen_zir.astgen.arena,
            .file => unreachable,
            .container => unreachable,
            .decl_ref => unreachable,
        }
    }

    pub fn ownerDecl(scope: *Scope) ?*Decl {
        return switch (scope.tag) {
            .block => scope.cast(Block).?.sema.owner_decl,
            .gen_zir => scope.cast(GenZir).?.astgen.decl,
            .local_val => scope.cast(LocalVal).?.gen_zir.astgen.decl,
            .local_ptr => scope.cast(LocalPtr).?.gen_zir.astgen.decl,
            .file => null,
            .container => null,
            .decl_ref => scope.cast(DeclRef).?.decl,
        };
    }

    pub fn srcDecl(scope: *Scope) ?*Decl {
        return switch (scope.tag) {
            .block => scope.cast(Block).?.src_decl,
            .gen_zir => scope.cast(GenZir).?.astgen.decl,
            .local_val => scope.cast(LocalVal).?.gen_zir.astgen.decl,
            .local_ptr => scope.cast(LocalPtr).?.gen_zir.astgen.decl,
            .file => null,
            .container => null,
            .decl_ref => scope.cast(DeclRef).?.decl,
        };
    }

    /// Asserts the scope has a parent which is a Container and returns it.
    pub fn namespace(scope: *Scope) *Container {
        switch (scope.tag) {
            .block => return scope.cast(Block).?.sema.owner_decl.container,
            .gen_zir => return scope.cast(GenZir).?.astgen.decl.container,
            .local_val => return scope.cast(LocalVal).?.gen_zir.astgen.decl.container,
            .local_ptr => return scope.cast(LocalPtr).?.gen_zir.astgen.decl.container,
            .file => return &scope.cast(File).?.root_container,
            .container => return scope.cast(Container).?,
            .decl_ref => return scope.cast(DeclRef).?.decl.container,
        }
    }

    /// Must generate unique bytes with no collisions with other decls.
    /// The point of hashing here is only to limit the number of bytes of
    /// the unique identifier to a fixed size (16 bytes).
    pub fn fullyQualifiedNameHash(scope: *Scope, name: []const u8) NameHash {
        switch (scope.tag) {
            .block => unreachable,
            .gen_zir => unreachable,
            .local_val => unreachable,
            .local_ptr => unreachable,
            .file => unreachable,
            .container => return scope.cast(Container).?.fullyQualifiedNameHash(name),
            .decl_ref => unreachable,
        }
    }

    /// Asserts the scope is a child of a File and has an AST tree and returns the tree.
    pub fn tree(scope: *Scope) *const ast.Tree {
        switch (scope.tag) {
            .file => return &scope.cast(File).?.tree,
            .block => return &scope.cast(Block).?.src_decl.container.file_scope.tree,
            .gen_zir => return scope.cast(GenZir).?.tree(),
            .local_val => return &scope.cast(LocalVal).?.gen_zir.astgen.decl.container.file_scope.tree,
            .local_ptr => return &scope.cast(LocalPtr).?.gen_zir.astgen.decl.container.file_scope.tree,
            .container => return &scope.cast(Container).?.file_scope.tree,
            .decl_ref => return &scope.cast(DeclRef).?.decl.container.file_scope.tree,
        }
    }

    /// Asserts the scope is a child of a `GenZir` and returns it.
    pub fn getGenZir(scope: *Scope) *GenZir {
        return switch (scope.tag) {
            .block => unreachable,
            .gen_zir => scope.cast(GenZir).?,
            .local_val => return scope.cast(LocalVal).?.gen_zir,
            .local_ptr => return scope.cast(LocalPtr).?.gen_zir,
            .file => unreachable,
            .container => unreachable,
            .decl_ref => unreachable,
        };
    }

    /// Asserts the scope has a parent which is a Container or File and
    /// returns the sub_file_path field.
    pub fn subFilePath(base: *Scope) []const u8 {
        switch (base.tag) {
            .container => return @fieldParentPtr(Container, "base", base).file_scope.sub_file_path,
            .file => return @fieldParentPtr(File, "base", base).sub_file_path,
            .block => unreachable,
            .gen_zir => unreachable,
            .local_val => unreachable,
            .local_ptr => unreachable,
            .decl_ref => unreachable,
        }
    }

    pub fn getSource(base: *Scope, module: *Module) ![:0]const u8 {
        switch (base.tag) {
            .container => return @fieldParentPtr(Container, "base", base).file_scope.getSource(module),
            .file => return @fieldParentPtr(File, "base", base).getSource(module),
            .gen_zir => unreachable,
            .local_val => unreachable,
            .local_ptr => unreachable,
            .block => unreachable,
            .decl_ref => unreachable,
        }
    }

    /// When called from inside a Block Scope, chases the src_decl, not the owner_decl.
    pub fn getFileScope(base: *Scope) *Scope.File {
        var cur = base;
        while (true) {
            cur = switch (cur.tag) {
                .container => return @fieldParentPtr(Container, "base", cur).file_scope,
                .file => return @fieldParentPtr(File, "base", cur),
                .gen_zir => @fieldParentPtr(GenZir, "base", cur).parent,
                .local_val => @fieldParentPtr(LocalVal, "base", cur).parent,
                .local_ptr => @fieldParentPtr(LocalPtr, "base", cur).parent,
                .block => return @fieldParentPtr(Block, "base", cur).src_decl.container.file_scope,
                .decl_ref => return @fieldParentPtr(DeclRef, "base", cur).decl.container.file_scope,
            };
        }
    }

    fn name_hash_hash(x: NameHash) u32 {
        return @truncate(u32, @bitCast(u128, x));
    }

    fn name_hash_eql(a: NameHash, b: NameHash) bool {
        return @bitCast(u128, a) == @bitCast(u128, b);
    }

    pub const Tag = enum {
        /// .zig source code.
        file,
        /// struct, enum or union, every .file contains one of these.
        container,
        block,
        gen_zir,
        local_val,
        local_ptr,
        /// Used for simple error reporting. Only contains a reference to a
        /// `Decl` for use with `srcDecl` and `ownerDecl`.
        /// Has no parents or children.
        decl_ref,
    };

    pub const Container = struct {
        pub const base_tag: Tag = .container;
        base: Scope = Scope{ .tag = base_tag },

        file_scope: *Scope.File,
        parent_name_hash: NameHash,

        /// Direct children of the file.
        decls: std.AutoArrayHashMapUnmanaged(*Decl, void) = .{},
        ty: Type,

        pub fn deinit(cont: *Container, gpa: *Allocator) void {
            cont.decls.deinit(gpa);
            // TODO either Container of File should have an arena for sub_file_path and ty
            gpa.destroy(cont.ty.castTag(.empty_struct).?);
            gpa.free(cont.file_scope.sub_file_path);
            cont.* = undefined;
        }

        pub fn removeDecl(cont: *Container, child: *Decl) void {
            _ = cont.decls.swapRemove(child);
        }

        pub fn fullyQualifiedNameHash(cont: *Container, name: []const u8) NameHash {
            return std.zig.hashName(cont.parent_name_hash, ".", name);
        }

        pub fn renderFullyQualifiedName(cont: Container, name: []const u8, writer: anytype) !void {
            // TODO this should render e.g. "std.fs.Dir.OpenOptions"
            return writer.writeAll(name);
        }
    };

    pub const File = struct {
        pub const base_tag: Tag = .file;
        base: Scope = Scope{ .tag = base_tag },
        status: enum {
            never_loaded,
            unloaded_success,
            unloaded_parse_failure,
            loaded_success,
        },

        /// Relative to the owning package's root_src_dir.
        /// Reference to external memory, not owned by File.
        sub_file_path: []const u8,
        source: union(enum) {
            unloaded: void,
            bytes: [:0]const u8,
        },
        /// Whether this is populated or not depends on `status`.
        tree: ast.Tree,
        /// Package that this file is a part of, managed externally.
        pkg: *Package,

        root_container: Container,

        pub fn unload(file: *File, gpa: *Allocator) void {
            switch (file.status) {
                .unloaded_parse_failure,
                .never_loaded,
                .unloaded_success,
                => {
                    file.status = .unloaded_success;
                },

                .loaded_success => {
                    file.tree.deinit(gpa);
                    file.status = .unloaded_success;
                },
            }
            switch (file.source) {
                .bytes => |bytes| {
                    gpa.free(bytes);
                    file.source = .{ .unloaded = {} };
                },
                .unloaded => {},
            }
        }

        pub fn deinit(file: *File, gpa: *Allocator) void {
            file.root_container.deinit(gpa);
            file.unload(gpa);
            file.* = undefined;
        }

        pub fn destroy(file: *File, gpa: *Allocator) void {
            file.deinit(gpa);
            gpa.destroy(file);
        }

        pub fn dumpSrc(file: *File, src: LazySrcLoc) void {
            const loc = std.zig.findLineColumn(file.source.bytes, src);
            std.debug.print("{s}:{d}:{d}\n", .{ file.sub_file_path, loc.line + 1, loc.column + 1 });
        }

        pub fn getSource(file: *File, module: *Module) ![:0]const u8 {
            switch (file.source) {
                .unloaded => {
                    const source = try file.pkg.root_src_directory.handle.readFileAllocOptions(
                        module.gpa,
                        file.sub_file_path,
                        std.math.maxInt(u32),
                        null,
                        1,
                        0,
                    );
                    file.source = .{ .bytes = source };
                    return source;
                },
                .bytes => |bytes| return bytes,
            }
        }
    };

    /// This is the context needed to semantically analyze ZIR instructions and
    /// produce TZIR instructions.
    /// This is a temporary structure stored on the stack; references to it are valid only
    /// during semantic analysis of the block.
    pub const Block = struct {
        pub const base_tag: Tag = .block;

        base: Scope = Scope{ .tag = base_tag },
        parent: ?*Block,
        /// Shared among all child blocks.
        sema: *Sema,
        /// This Decl is the Decl according to the Zig source code corresponding to this Block.
        /// This can vary during inline or comptime function calls. See `Sema.owner_decl`
        /// for the one that will be the same for all Block instances.
        src_decl: *Decl,
        instructions: ArrayListUnmanaged(*ir.Inst),
        label: ?Label = null,
        inlining: ?*Inlining,
        is_comptime: bool,

        /// This `Block` maps a block ZIR instruction to the corresponding
        /// TZIR instruction for break instruction analysis.
        pub const Label = struct {
            zir_block: zir.Inst.Index,
            merges: Merges,
        };

        /// This `Block` indicates that an inline function call is happening
        /// and return instructions should be analyzed as a break instruction
        /// to this TZIR block instruction.
        /// It is shared among all the blocks in an inline or comptime called
        /// function.
        pub const Inlining = struct {
            merges: Merges,
        };

        pub const Merges = struct {
            block_inst: *ir.Inst.Block,
            /// Separate array list from break_inst_list so that it can be passed directly
            /// to resolvePeerTypes.
            results: ArrayListUnmanaged(*ir.Inst),
            /// Keeps track of the break instructions so that the operand can be replaced
            /// if we need to add type coercion at the end of block analysis.
            /// Same indexes, capacity, length as `results`.
            br_list: ArrayListUnmanaged(*ir.Inst.Br),
        };

        /// For debugging purposes.
        pub fn dump(block: *Block, mod: Module) void {
            zir.dumpBlock(mod, block);
        }

        pub fn makeSubBlock(parent: *Block) Block {
            return .{
                .parent = parent,
                .sema = parent.sema,
                .src_decl = parent.src_decl,
                .instructions = .{},
                .label = null,
                .inlining = parent.inlining,
                .is_comptime = parent.is_comptime,
            };
        }

        pub fn wantSafety(block: *const Block) bool {
            // TODO take into account scope's safety overrides
            return switch (block.sema.mod.optimizeMode()) {
                .Debug => true,
                .ReleaseSafe => true,
                .ReleaseFast => false,
                .ReleaseSmall => false,
            };
        }

        pub fn getFileScope(block: *Block) *Scope.File {
            return block.src_decl.container.file_scope;
        }

        pub fn addNoOp(
            block: *Scope.Block,
            src: LazySrcLoc,
            ty: Type,
            comptime tag: ir.Inst.Tag,
        ) !*ir.Inst {
            const inst = try block.sema.arena.create(tag.Type());
            inst.* = .{
                .base = .{
                    .tag = tag,
                    .ty = ty,
                    .src = src,
                },
            };
            try block.instructions.append(block.sema.gpa, &inst.base);
            return &inst.base;
        }

        pub fn addUnOp(
            block: *Scope.Block,
            src: LazySrcLoc,
            ty: Type,
            tag: ir.Inst.Tag,
            operand: *ir.Inst,
        ) !*ir.Inst {
            const inst = try block.sema.arena.create(ir.Inst.UnOp);
            inst.* = .{
                .base = .{
                    .tag = tag,
                    .ty = ty,
                    .src = src,
                },
                .operand = operand,
            };
            try block.instructions.append(block.sema.gpa, &inst.base);
            return &inst.base;
        }

        pub fn addBinOp(
            block: *Scope.Block,
            src: LazySrcLoc,
            ty: Type,
            tag: ir.Inst.Tag,
            lhs: *ir.Inst,
            rhs: *ir.Inst,
        ) !*ir.Inst {
            const inst = try block.sema.arena.create(ir.Inst.BinOp);
            inst.* = .{
                .base = .{
                    .tag = tag,
                    .ty = ty,
                    .src = src,
                },
                .lhs = lhs,
                .rhs = rhs,
            };
            try block.instructions.append(block.sema.gpa, &inst.base);
            return &inst.base;
        }

        pub fn addBr(
            scope_block: *Scope.Block,
            src: LazySrcLoc,
            target_block: *ir.Inst.Block,
            operand: *ir.Inst,
        ) !*ir.Inst.Br {
            const inst = try scope_block.sema.arena.create(ir.Inst.Br);
            inst.* = .{
                .base = .{
                    .tag = .br,
                    .ty = Type.initTag(.noreturn),
                    .src = src,
                },
                .operand = operand,
                .block = target_block,
            };
            try scope_block.instructions.append(scope_block.sema.gpa, &inst.base);
            return inst;
        }

        pub fn addCondBr(
            block: *Scope.Block,
            src: LazySrcLoc,
            condition: *ir.Inst,
            then_body: ir.Body,
            else_body: ir.Body,
        ) !*ir.Inst {
            const inst = try block.sema.arena.create(ir.Inst.CondBr);
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
            try block.instructions.append(block.sema.gpa, &inst.base);
            return &inst.base;
        }

        pub fn addCall(
            block: *Scope.Block,
            src: LazySrcLoc,
            ty: Type,
            func: *ir.Inst,
            args: []const *ir.Inst,
        ) !*ir.Inst {
            const inst = try block.sema.arena.create(ir.Inst.Call);
            inst.* = .{
                .base = .{
                    .tag = .call,
                    .ty = ty,
                    .src = src,
                },
                .func = func,
                .args = args,
            };
            try block.instructions.append(block.sema.gpa, &inst.base);
            return &inst.base;
        }

        pub fn addSwitchBr(
            block: *Scope.Block,
            src: LazySrcLoc,
            operand: *ir.Inst,
            cases: []ir.Inst.SwitchBr.Case,
            else_body: ir.Body,
        ) !*ir.Inst {
            const inst = try block.sema.arena.create(ir.Inst.SwitchBr);
            inst.* = .{
                .base = .{
                    .tag = .switchbr,
                    .ty = Type.initTag(.noreturn),
                    .src = src,
                },
                .target = operand,
                .cases = cases,
                .else_body = else_body,
            };
            try block.instructions.append(block.sema.gpa, &inst.base);
            return &inst.base;
        }

        pub fn addDbgStmt(block: *Scope.Block, src: LazySrcLoc, abs_byte_off: u32) !*ir.Inst {
            const inst = try block.sema.arena.create(ir.Inst.DbgStmt);
            inst.* = .{
                .base = .{
                    .tag = .dbg_stmt,
                    .ty = Type.initTag(.void),
                    .src = src,
                },
                .byte_offset = abs_byte_off,
            };
            try block.instructions.append(block.sema.gpa, &inst.base);
            return &inst.base;
        }

        pub fn addStructFieldPtr(
            block: *Scope.Block,
            src: LazySrcLoc,
            ty: Type,
            struct_ptr: *ir.Inst,
            field_index: u32,
        ) !*ir.Inst {
            const inst = try block.sema.arena.create(ir.Inst.StructFieldPtr);
            inst.* = .{
                .base = .{
                    .tag = .struct_field_ptr,
                    .ty = ty,
                    .src = src,
                },
                .struct_ptr = struct_ptr,
                .field_index = field_index,
            };
            try block.instructions.append(block.sema.gpa, &inst.base);
            return &inst.base;
        }
    };

    /// This is a temporary structure; references to it are valid only
    /// while constructing a `zir.Code`.
    pub const GenZir = struct {
        pub const base_tag: Tag = .gen_zir;
        base: Scope = Scope{ .tag = base_tag },
        force_comptime: bool,
        /// Parents can be: `GenZir`, `File`
        parent: *Scope,
        /// All `GenZir` scopes for the same ZIR share this.
        astgen: *AstGen,
        /// Keeps track of the list of instructions in this scope only. Indexes
        /// to instructions in `astgen`.
        instructions: ArrayListUnmanaged(zir.Inst.Index) = .{},
        label: ?Label = null,
        break_block: zir.Inst.Index = 0,
        continue_block: zir.Inst.Index = 0,
        /// Only valid when setBreakResultLoc is called.
        break_result_loc: AstGen.ResultLoc = undefined,
        /// When a block has a pointer result location, here it is.
        rl_ptr: zir.Inst.Ref = .none,
        /// When a block has a type result location, here it is.
        rl_ty_inst: zir.Inst.Ref = .none,
        /// Keeps track of how many branches of a block did not actually
        /// consume the result location. astgen uses this to figure out
        /// whether to rely on break instructions or writing to the result
        /// pointer for the result instruction.
        rvalue_rl_count: usize = 0,
        /// Keeps track of how many break instructions there are. When astgen is finished
        /// with a block, it can check this against rvalue_rl_count to find out whether
        /// the break instructions should be downgraded to break_void.
        break_count: usize = 0,
        /// Tracks `break :foo bar` instructions so they can possibly be elided later if
        /// the labeled block ends up not needing a result location pointer.
        labeled_breaks: ArrayListUnmanaged(zir.Inst.Index) = .{},
        /// Tracks `store_to_block_ptr` instructions that correspond to break instructions
        /// so they can possibly be elided later if the labeled block ends up not needing
        /// a result location pointer.
        labeled_store_to_block_ptr_list: ArrayListUnmanaged(zir.Inst.Index) = .{},

        pub const Label = struct {
            token: ast.TokenIndex,
            block_inst: zir.Inst.Index,
            used: bool = false,
        };

        /// Only valid to call on the top of the `GenZir` stack. Completes the
        /// `AstGen` into a `zir.Code`. Leaves the `AstGen` in an
        /// initialized, but empty, state.
        pub fn finish(gz: *GenZir) !zir.Code {
            const gpa = gz.astgen.mod.gpa;
            try gz.setBlockBody(0);
            return zir.Code{
                .instructions = gz.astgen.instructions.toOwnedSlice(),
                .string_bytes = gz.astgen.string_bytes.toOwnedSlice(gpa),
                .extra = gz.astgen.extra.toOwnedSlice(gpa),
            };
        }

        pub fn tokSrcLoc(gz: GenZir, token_index: ast.TokenIndex) LazySrcLoc {
            return gz.astgen.decl.tokSrcLoc(token_index);
        }

        pub fn nodeSrcLoc(gz: GenZir, node_index: ast.Node.Index) LazySrcLoc {
            return gz.astgen.decl.nodeSrcLoc(node_index);
        }

        pub fn tree(gz: *const GenZir) *const ast.Tree {
            return &gz.astgen.decl.container.file_scope.tree;
        }

        pub fn setBreakResultLoc(gz: *GenZir, parent_rl: AstGen.ResultLoc) void {
            // Depending on whether the result location is a pointer or value, different
            // ZIR needs to be generated. In the former case we rely on storing to the
            // pointer to communicate the result, and use breakvoid; in the latter case
            // the block break instructions will have the result values.
            // One more complication: when the result location is a pointer, we detect
            // the scenario where the result location is not consumed. In this case
            // we emit ZIR for the block break instructions to have the result values,
            // and then rvalue() on that to pass the value to the result location.
            switch (parent_rl) {
                .ty => |ty_inst| {
                    gz.rl_ty_inst = ty_inst;
                    gz.break_result_loc = parent_rl;
                },
                .none_or_ref => {
                    gz.break_result_loc = .ref;
                },
                .discard, .none, .ptr, .ref => {
                    gz.break_result_loc = parent_rl;
                },

                .inferred_ptr => |ptr| {
                    gz.rl_ptr = ptr;
                    gz.break_result_loc = .{ .block_ptr = gz };
                },

                .block_ptr => |parent_block_scope| {
                    gz.rl_ty_inst = parent_block_scope.rl_ty_inst;
                    gz.rl_ptr = parent_block_scope.rl_ptr;
                    gz.break_result_loc = .{ .block_ptr = gz };
                },
            }
        }

        pub fn setBoolBrBody(gz: GenZir, inst: zir.Inst.Index) !void {
            const gpa = gz.astgen.mod.gpa;
            try gz.astgen.extra.ensureCapacity(gpa, gz.astgen.extra.items.len +
                @typeInfo(zir.Inst.Block).Struct.fields.len + gz.instructions.items.len);
            const zir_datas = gz.astgen.instructions.items(.data);
            zir_datas[inst].bool_br.payload_index = gz.astgen.addExtraAssumeCapacity(
                zir.Inst.Block{ .body_len = @intCast(u32, gz.instructions.items.len) },
            );
            gz.astgen.extra.appendSliceAssumeCapacity(gz.instructions.items);
        }

        pub fn setBlockBody(gz: GenZir, inst: zir.Inst.Index) !void {
            const gpa = gz.astgen.mod.gpa;
            try gz.astgen.extra.ensureCapacity(gpa, gz.astgen.extra.items.len +
                @typeInfo(zir.Inst.Block).Struct.fields.len + gz.instructions.items.len);
            const zir_datas = gz.astgen.instructions.items(.data);
            zir_datas[inst].pl_node.payload_index = gz.astgen.addExtraAssumeCapacity(
                zir.Inst.Block{ .body_len = @intCast(u32, gz.instructions.items.len) },
            );
            gz.astgen.extra.appendSliceAssumeCapacity(gz.instructions.items);
        }

        pub fn identAsString(gz: *GenZir, ident_token: ast.TokenIndex) !u32 {
            const astgen = gz.astgen;
            const gpa = astgen.mod.gpa;
            const string_bytes = &astgen.string_bytes;
            const str_index = @intCast(u32, string_bytes.items.len);
            try astgen.mod.appendIdentStr(&gz.base, ident_token, string_bytes);
            try string_bytes.append(gpa, 0);
            return str_index;
        }

        pub fn addFnTypeCc(gz: *GenZir, tag: zir.Inst.Tag, args: struct {
            src_node: ast.Node.Index,
            param_types: []const zir.Inst.Ref,
            ret_ty: zir.Inst.Ref,
            cc: zir.Inst.Ref,
        }) !zir.Inst.Ref {
            assert(args.src_node != 0);
            assert(args.ret_ty != .none);
            assert(args.cc != .none);
            const gpa = gz.astgen.mod.gpa;
            try gz.instructions.ensureCapacity(gpa, gz.instructions.items.len + 1);
            try gz.astgen.instructions.ensureCapacity(gpa, gz.astgen.instructions.len + 1);
            try gz.astgen.extra.ensureCapacity(gpa, gz.astgen.extra.items.len +
                @typeInfo(zir.Inst.FnTypeCc).Struct.fields.len + args.param_types.len);

            const payload_index = gz.astgen.addExtraAssumeCapacity(zir.Inst.FnTypeCc{
                .return_type = args.ret_ty,
                .cc = args.cc,
                .param_types_len = @intCast(u32, args.param_types.len),
            });
            gz.astgen.appendRefsAssumeCapacity(args.param_types);

            const new_index = @intCast(zir.Inst.Index, gz.astgen.instructions.len);
            gz.astgen.instructions.appendAssumeCapacity(.{
                .tag = tag,
                .data = .{ .pl_node = .{
                    .src_node = gz.astgen.decl.nodeIndexToRelative(args.src_node),
                    .payload_index = payload_index,
                } },
            });
            gz.instructions.appendAssumeCapacity(new_index);
            return gz.astgen.indexToRef(new_index);
        }

        pub fn addFnType(gz: *GenZir, tag: zir.Inst.Tag, args: struct {
            src_node: ast.Node.Index,
            ret_ty: zir.Inst.Ref,
            param_types: []const zir.Inst.Ref,
        }) !zir.Inst.Ref {
            assert(args.src_node != 0);
            assert(args.ret_ty != .none);
            const gpa = gz.astgen.mod.gpa;
            try gz.instructions.ensureCapacity(gpa, gz.instructions.items.len + 1);
            try gz.astgen.instructions.ensureCapacity(gpa, gz.astgen.instructions.len + 1);
            try gz.astgen.extra.ensureCapacity(gpa, gz.astgen.extra.items.len +
                @typeInfo(zir.Inst.FnType).Struct.fields.len + args.param_types.len);

            const payload_index = gz.astgen.addExtraAssumeCapacity(zir.Inst.FnType{
                .return_type = args.ret_ty,
                .param_types_len = @intCast(u32, args.param_types.len),
            });
            gz.astgen.appendRefsAssumeCapacity(args.param_types);

            const new_index = @intCast(zir.Inst.Index, gz.astgen.instructions.len);
            gz.astgen.instructions.appendAssumeCapacity(.{
                .tag = tag,
                .data = .{ .pl_node = .{
                    .src_node = gz.astgen.decl.nodeIndexToRelative(args.src_node),
                    .payload_index = payload_index,
                } },
            });
            gz.instructions.appendAssumeCapacity(new_index);
            return gz.astgen.indexToRef(new_index);
        }

        pub fn addCall(
            gz: *GenZir,
            tag: zir.Inst.Tag,
            callee: zir.Inst.Ref,
            args: []const zir.Inst.Ref,
            /// Absolute node index. This function does the conversion to offset from Decl.
            src_node: ast.Node.Index,
        ) !zir.Inst.Ref {
            assert(callee != .none);
            assert(src_node != 0);
            const gpa = gz.astgen.mod.gpa;
            try gz.instructions.ensureCapacity(gpa, gz.instructions.items.len + 1);
            try gz.astgen.instructions.ensureCapacity(gpa, gz.astgen.instructions.len + 1);
            try gz.astgen.extra.ensureCapacity(gpa, gz.astgen.extra.items.len +
                @typeInfo(zir.Inst.Call).Struct.fields.len + args.len);

            const payload_index = gz.astgen.addExtraAssumeCapacity(zir.Inst.Call{
                .callee = callee,
                .args_len = @intCast(u32, args.len),
            });
            gz.astgen.appendRefsAssumeCapacity(args);

            const new_index = @intCast(zir.Inst.Index, gz.astgen.instructions.len);
            gz.astgen.instructions.appendAssumeCapacity(.{
                .tag = tag,
                .data = .{ .pl_node = .{
                    .src_node = gz.astgen.decl.nodeIndexToRelative(src_node),
                    .payload_index = payload_index,
                } },
            });
            gz.instructions.appendAssumeCapacity(new_index);
            return gz.astgen.indexToRef(new_index);
        }

        /// Note that this returns a `zir.Inst.Index` not a ref.
        /// Leaves the `payload_index` field undefined.
        pub fn addBoolBr(
            gz: *GenZir,
            tag: zir.Inst.Tag,
            lhs: zir.Inst.Ref,
        ) !zir.Inst.Index {
            assert(lhs != .none);
            const gpa = gz.astgen.mod.gpa;
            try gz.instructions.ensureCapacity(gpa, gz.instructions.items.len + 1);
            try gz.astgen.instructions.ensureCapacity(gpa, gz.astgen.instructions.len + 1);

            const new_index = @intCast(zir.Inst.Index, gz.astgen.instructions.len);
            gz.astgen.instructions.appendAssumeCapacity(.{
                .tag = tag,
                .data = .{ .bool_br = .{
                    .lhs = lhs,
                    .payload_index = undefined,
                } },
            });
            gz.instructions.appendAssumeCapacity(new_index);
            return new_index;
        }

        pub fn addInt(gz: *GenZir, integer: u64) !zir.Inst.Ref {
            return gz.add(.{
                .tag = .int,
                .data = .{ .int = integer },
            });
        }

        pub fn addFloat(gz: *GenZir, number: f32, src_node: ast.Node.Index) !zir.Inst.Ref {
            return gz.add(.{
                .tag = .float,
                .data = .{ .float = .{
                    .src_node = gz.astgen.decl.nodeIndexToRelative(src_node),
                    .number = number,
                } },
            });
        }

        pub fn addUnNode(
            gz: *GenZir,
            tag: zir.Inst.Tag,
            operand: zir.Inst.Ref,
            /// Absolute node index. This function does the conversion to offset from Decl.
            src_node: ast.Node.Index,
        ) !zir.Inst.Ref {
            assert(operand != .none);
            return gz.add(.{
                .tag = tag,
                .data = .{ .un_node = .{
                    .operand = operand,
                    .src_node = gz.astgen.decl.nodeIndexToRelative(src_node),
                } },
            });
        }

        pub fn addPlNode(
            gz: *GenZir,
            tag: zir.Inst.Tag,
            /// Absolute node index. This function does the conversion to offset from Decl.
            src_node: ast.Node.Index,
            extra: anytype,
        ) !zir.Inst.Ref {
            const gpa = gz.astgen.mod.gpa;
            try gz.instructions.ensureCapacity(gpa, gz.instructions.items.len + 1);
            try gz.astgen.instructions.ensureCapacity(gpa, gz.astgen.instructions.len + 1);

            const payload_index = try gz.astgen.addExtra(extra);
            const new_index = @intCast(zir.Inst.Index, gz.astgen.instructions.len);
            gz.astgen.instructions.appendAssumeCapacity(.{
                .tag = tag,
                .data = .{ .pl_node = .{
                    .src_node = gz.astgen.decl.nodeIndexToRelative(src_node),
                    .payload_index = payload_index,
                } },
            });
            gz.instructions.appendAssumeCapacity(new_index);
            return gz.astgen.indexToRef(new_index);
        }

        pub fn addArrayTypeSentinel(
            gz: *GenZir,
            len: zir.Inst.Ref,
            sentinel: zir.Inst.Ref,
            elem_type: zir.Inst.Ref,
        ) !zir.Inst.Ref {
            const gpa = gz.astgen.mod.gpa;
            try gz.instructions.ensureCapacity(gpa, gz.instructions.items.len + 1);
            try gz.astgen.instructions.ensureCapacity(gpa, gz.astgen.instructions.len + 1);

            const payload_index = try gz.astgen.addExtra(zir.Inst.ArrayTypeSentinel{
                .sentinel = sentinel,
                .elem_type = elem_type,
            });
            const new_index = @intCast(zir.Inst.Index, gz.astgen.instructions.len);
            gz.astgen.instructions.appendAssumeCapacity(.{
                .tag = .array_type_sentinel,
                .data = .{ .array_type_sentinel = .{
                    .len = len,
                    .payload_index = payload_index,
                } },
            });
            gz.instructions.appendAssumeCapacity(new_index);
            return gz.astgen.indexToRef(new_index);
        }

        pub fn addUnTok(
            gz: *GenZir,
            tag: zir.Inst.Tag,
            operand: zir.Inst.Ref,
            /// Absolute token index. This function does the conversion to Decl offset.
            abs_tok_index: ast.TokenIndex,
        ) !zir.Inst.Ref {
            assert(operand != .none);
            return gz.add(.{
                .tag = tag,
                .data = .{ .un_tok = .{
                    .operand = operand,
                    .src_tok = abs_tok_index - gz.astgen.decl.srcToken(),
                } },
            });
        }

        pub fn addStrTok(
            gz: *GenZir,
            tag: zir.Inst.Tag,
            str_index: u32,
            /// Absolute token index. This function does the conversion to Decl offset.
            abs_tok_index: ast.TokenIndex,
        ) !zir.Inst.Ref {
            return gz.add(.{
                .tag = tag,
                .data = .{ .str_tok = .{
                    .start = str_index,
                    .src_tok = abs_tok_index - gz.astgen.decl.srcToken(),
                } },
            });
        }

        pub fn addBreak(
            gz: *GenZir,
            tag: zir.Inst.Tag,
            break_block: zir.Inst.Index,
            operand: zir.Inst.Ref,
        ) !zir.Inst.Index {
            return gz.addAsIndex(.{
                .tag = tag,
                .data = .{ .@"break" = .{
                    .block_inst = break_block,
                    .operand = operand,
                } },
            });
        }

        pub fn addBin(
            gz: *GenZir,
            tag: zir.Inst.Tag,
            lhs: zir.Inst.Ref,
            rhs: zir.Inst.Ref,
        ) !zir.Inst.Ref {
            assert(lhs != .none);
            assert(rhs != .none);
            return gz.add(.{
                .tag = tag,
                .data = .{ .bin = .{
                    .lhs = lhs,
                    .rhs = rhs,
                } },
            });
        }

        pub fn addDecl(
            gz: *GenZir,
            tag: zir.Inst.Tag,
            decl_index: u32,
            src_node: ast.Node.Index,
        ) !zir.Inst.Ref {
            return gz.add(.{
                .tag = tag,
                .data = .{ .pl_node = .{
                    .src_node = gz.astgen.decl.nodeIndexToRelative(src_node),
                    .payload_index = decl_index,
                } },
            });
        }

        pub fn addNode(
            gz: *GenZir,
            tag: zir.Inst.Tag,
            /// Absolute node index. This function does the conversion to offset from Decl.
            src_node: ast.Node.Index,
        ) !zir.Inst.Ref {
            return gz.add(.{
                .tag = tag,
                .data = .{ .node = gz.astgen.decl.nodeIndexToRelative(src_node) },
            });
        }

        /// Asserts that `str` is 8 or fewer bytes.
        pub fn addSmallStr(
            gz: *GenZir,
            tag: zir.Inst.Tag,
            str: []const u8,
        ) !zir.Inst.Ref {
            var buf: [9]u8 = undefined;
            mem.copy(u8, &buf, str);
            buf[str.len] = 0;

            return gz.add(.{
                .tag = tag,
                .data = .{ .small_str = .{ .bytes = buf[0..8].* } },
            });
        }

        /// Note that this returns a `zir.Inst.Index` not a ref.
        /// Does *not* append the block instruction to the scope.
        /// Leaves the `payload_index` field undefined.
        pub fn addBlock(gz: *GenZir, tag: zir.Inst.Tag, node: ast.Node.Index) !zir.Inst.Index {
            const new_index = @intCast(zir.Inst.Index, gz.astgen.instructions.len);
            const gpa = gz.astgen.mod.gpa;
            try gz.astgen.instructions.append(gpa, .{
                .tag = tag,
                .data = .{ .pl_node = .{
                    .src_node = gz.astgen.decl.nodeIndexToRelative(node),
                    .payload_index = undefined,
                } },
            });
            return new_index;
        }

        /// Note that this returns a `zir.Inst.Index` not a ref.
        /// Leaves the `payload_index` field undefined.
        pub fn addCondBr(gz: *GenZir, tag: zir.Inst.Tag, node: ast.Node.Index) !zir.Inst.Index {
            const gpa = gz.astgen.mod.gpa;
            try gz.instructions.ensureCapacity(gpa, gz.instructions.items.len + 1);
            const new_index = @intCast(zir.Inst.Index, gz.astgen.instructions.len);
            try gz.astgen.instructions.append(gpa, .{
                .tag = tag,
                .data = .{ .pl_node = .{
                    .src_node = gz.astgen.decl.nodeIndexToRelative(node),
                    .payload_index = undefined,
                } },
            });
            gz.instructions.appendAssumeCapacity(new_index);
            return new_index;
        }

        pub fn add(gz: *GenZir, inst: zir.Inst) !zir.Inst.Ref {
            return gz.astgen.indexToRef(try gz.addAsIndex(inst));
        }

        pub fn addAsIndex(gz: *GenZir, inst: zir.Inst) !zir.Inst.Index {
            const gpa = gz.astgen.mod.gpa;
            try gz.instructions.ensureCapacity(gpa, gz.instructions.items.len + 1);
            try gz.astgen.instructions.ensureCapacity(gpa, gz.astgen.instructions.len + 1);

            const new_index = @intCast(zir.Inst.Index, gz.astgen.instructions.len);
            gz.astgen.instructions.appendAssumeCapacity(inst);
            gz.instructions.appendAssumeCapacity(new_index);
            return new_index;
        }
    };

    /// This is always a `const` local and importantly the `inst` is a value type, not a pointer.
    /// This structure lives as long as the AST generation of the Block
    /// node that contains the variable.
    pub const LocalVal = struct {
        pub const base_tag: Tag = .local_val;
        base: Scope = Scope{ .tag = base_tag },
        /// Parents can be: `LocalVal`, `LocalPtr`, `GenZir`.
        parent: *Scope,
        gen_zir: *GenZir,
        name: []const u8,
        inst: zir.Inst.Ref,
        /// Source location of the corresponding variable declaration.
        src: LazySrcLoc,
    };

    /// This could be a `const` or `var` local. It has a pointer instead of a value.
    /// This structure lives as long as the AST generation of the Block
    /// node that contains the variable.
    pub const LocalPtr = struct {
        pub const base_tag: Tag = .local_ptr;
        base: Scope = Scope{ .tag = base_tag },
        /// Parents can be: `LocalVal`, `LocalPtr`, `GenZir`.
        parent: *Scope,
        gen_zir: *GenZir,
        name: []const u8,
        ptr: zir.Inst.Ref,
        /// Source location of the corresponding variable declaration.
        src: LazySrcLoc,
    };

    pub const DeclRef = struct {
        pub const base_tag: Tag = .decl_ref;
        base: Scope = Scope{ .tag = base_tag },
        decl: *Decl,
    };
};

/// This struct holds data necessary to construct API-facing `AllErrors.Message`.
/// Its memory is managed with the general purpose allocator so that they
/// can be created and destroyed in response to incremental updates.
/// In some cases, the Scope.File could have been inferred from where the ErrorMsg
/// is stored. For example, if it is stored in Module.failed_decls, then the Scope.File
/// would be determined by the Decl Scope. However, the data structure contains the field
/// anyway so that `ErrorMsg` can be reused for error notes, which may be in a different
/// file than the parent error message. It also simplifies processing of error messages.
pub const ErrorMsg = struct {
    src_loc: SrcLoc,
    msg: []const u8,
    notes: []ErrorMsg = &.{},

    pub fn create(
        gpa: *Allocator,
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
    pub fn destroy(err_msg: *ErrorMsg, gpa: *Allocator) void {
        err_msg.deinit(gpa);
        gpa.destroy(err_msg);
    }

    pub fn init(
        gpa: *Allocator,
        src_loc: SrcLoc,
        comptime format: []const u8,
        args: anytype,
    ) !ErrorMsg {
        return ErrorMsg{
            .src_loc = src_loc,
            .msg = try std.fmt.allocPrint(gpa, format, args),
        };
    }

    pub fn deinit(err_msg: *ErrorMsg, gpa: *Allocator) void {
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
    /// The active field is determined by tag of `lazy`.
    container: union {
        /// The containing `Decl` according to the source code.
        decl: *Decl,
        file_scope: *Scope.File,
    },
    /// Relative to `decl`.
    lazy: LazySrcLoc,

    pub fn fileScope(src_loc: SrcLoc) *Scope.File {
        return switch (src_loc.lazy) {
            .unneeded => unreachable,

            .byte_abs,
            .token_abs,
            .node_abs,
            => src_loc.container.file_scope,

            .byte_offset,
            .token_offset,
            .node_offset,
            .node_offset_back2tok,
            .node_offset_var_decl_ty,
            .node_offset_for_cond,
            .node_offset_builtin_call_arg0,
            .node_offset_builtin_call_arg1,
            .node_offset_array_access_index,
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
            => src_loc.container.decl.container.file_scope,
        };
    }

    pub fn byteOffset(src_loc: SrcLoc) !u32 {
        switch (src_loc.lazy) {
            .unneeded => unreachable,

            .byte_abs => |byte_index| return byte_index,

            .token_abs => |tok_index| {
                const tree = src_loc.container.file_scope.base.tree();
                const token_starts = tree.tokens.items(.start);
                return token_starts[tok_index];
            },
            .node_abs => |node| {
                const tree = src_loc.container.file_scope.base.tree();
                const token_starts = tree.tokens.items(.start);
                const tok_index = tree.firstToken(node);
                return token_starts[tok_index];
            },
            .byte_offset => |byte_off| {
                const decl = src_loc.container.decl;
                return decl.srcByteOffset() + byte_off;
            },
            .token_offset => |tok_off| {
                const decl = src_loc.container.decl;
                const tok_index = decl.srcToken() + tok_off;
                const tree = decl.container.file_scope.base.tree();
                const token_starts = tree.tokens.items(.start);
                return token_starts[tok_index];
            },
            .node_offset, .node_offset_bin_op => |node_off| {
                const decl = src_loc.container.decl;
                const node = decl.relativeToNodeIndex(node_off);
                const tree = decl.container.file_scope.base.tree();
                const main_tokens = tree.nodes.items(.main_token);
                const tok_index = main_tokens[node];
                const token_starts = tree.tokens.items(.start);
                return token_starts[tok_index];
            },
            .node_offset_back2tok => |node_off| {
                const decl = src_loc.container.decl;
                const node = decl.relativeToNodeIndex(node_off);
                const tree = decl.container.file_scope.base.tree();
                const tok_index = tree.firstToken(node) - 2;
                const token_starts = tree.tokens.items(.start);
                return token_starts[tok_index];
            },
            .node_offset_var_decl_ty => |node_off| {
                const decl = src_loc.container.decl;
                const node = decl.relativeToNodeIndex(node_off);
                const tree = decl.container.file_scope.base.tree();
                const node_tags = tree.nodes.items(.tag);
                const full = switch (node_tags[node]) {
                    .global_var_decl => tree.globalVarDecl(node),
                    .local_var_decl => tree.localVarDecl(node),
                    .simple_var_decl => tree.simpleVarDecl(node),
                    .aligned_var_decl => tree.alignedVarDecl(node),
                    else => unreachable,
                };
                const tok_index = if (full.ast.type_node != 0) blk: {
                    const main_tokens = tree.nodes.items(.main_token);
                    break :blk main_tokens[full.ast.type_node];
                } else blk: {
                    break :blk full.ast.mut_token + 1; // the name token
                };
                const token_starts = tree.tokens.items(.start);
                return token_starts[tok_index];
            },
            .node_offset_builtin_call_arg0 => |node_off| {
                const decl = src_loc.container.decl;
                const tree = decl.container.file_scope.base.tree();
                const node_datas = tree.nodes.items(.data);
                const node_tags = tree.nodes.items(.tag);
                const node = decl.relativeToNodeIndex(node_off);
                const param = switch (node_tags[node]) {
                    .builtin_call_two, .builtin_call_two_comma => node_datas[node].lhs,
                    .builtin_call, .builtin_call_comma => tree.extra_data[node_datas[node].lhs],
                    else => unreachable,
                };
                const main_tokens = tree.nodes.items(.main_token);
                const tok_index = main_tokens[param];
                const token_starts = tree.tokens.items(.start);
                return token_starts[tok_index];
            },
            .node_offset_builtin_call_arg1 => |node_off| {
                const decl = src_loc.container.decl;
                const tree = decl.container.file_scope.base.tree();
                const node_datas = tree.nodes.items(.data);
                const node_tags = tree.nodes.items(.tag);
                const node = decl.relativeToNodeIndex(node_off);
                const param = switch (node_tags[node]) {
                    .builtin_call_two, .builtin_call_two_comma => node_datas[node].rhs,
                    .builtin_call, .builtin_call_comma => tree.extra_data[node_datas[node].lhs + 1],
                    else => unreachable,
                };
                const main_tokens = tree.nodes.items(.main_token);
                const tok_index = main_tokens[param];
                const token_starts = tree.tokens.items(.start);
                return token_starts[tok_index];
            },
            .node_offset_array_access_index => |node_off| {
                const decl = src_loc.container.decl;
                const tree = decl.container.file_scope.base.tree();
                const node_datas = tree.nodes.items(.data);
                const node_tags = tree.nodes.items(.tag);
                const node = decl.relativeToNodeIndex(node_off);
                const main_tokens = tree.nodes.items(.main_token);
                const tok_index = main_tokens[node_datas[node].rhs];
                const token_starts = tree.tokens.items(.start);
                return token_starts[tok_index];
            },
            .node_offset_slice_sentinel => |node_off| {
                const decl = src_loc.container.decl;
                const tree = decl.container.file_scope.base.tree();
                const node_datas = tree.nodes.items(.data);
                const node_tags = tree.nodes.items(.tag);
                const node = decl.relativeToNodeIndex(node_off);
                const full = switch (node_tags[node]) {
                    .slice_open => tree.sliceOpen(node),
                    .slice => tree.slice(node),
                    .slice_sentinel => tree.sliceSentinel(node),
                    else => unreachable,
                };
                const main_tokens = tree.nodes.items(.main_token);
                const tok_index = main_tokens[full.ast.sentinel];
                const token_starts = tree.tokens.items(.start);
                return token_starts[tok_index];
            },
            .node_offset_call_func => |node_off| {
                const decl = src_loc.container.decl;
                const tree = decl.container.file_scope.base.tree();
                const node_datas = tree.nodes.items(.data);
                const node_tags = tree.nodes.items(.tag);
                const node = decl.relativeToNodeIndex(node_off);
                var params: [1]ast.Node.Index = undefined;
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
                const main_tokens = tree.nodes.items(.main_token);
                const tok_index = main_tokens[full.ast.fn_expr];
                const token_starts = tree.tokens.items(.start);
                return token_starts[tok_index];
            },
            .node_offset_field_name => |node_off| {
                const decl = src_loc.container.decl;
                const tree = decl.container.file_scope.base.tree();
                const node_datas = tree.nodes.items(.data);
                const node_tags = tree.nodes.items(.tag);
                const node = decl.relativeToNodeIndex(node_off);
                const tok_index = switch (node_tags[node]) {
                    .field_access => node_datas[node].rhs,
                    else => tree.firstToken(node) - 2,
                };
                const token_starts = tree.tokens.items(.start);
                return token_starts[tok_index];
            },
            .node_offset_deref_ptr => |node_off| {
                const decl = src_loc.container.decl;
                const tree = decl.container.file_scope.base.tree();
                const node_datas = tree.nodes.items(.data);
                const node_tags = tree.nodes.items(.tag);
                const node = decl.relativeToNodeIndex(node_off);
                const tok_index = node_datas[node].lhs;
                const token_starts = tree.tokens.items(.start);
                return token_starts[tok_index];
            },
            .node_offset_asm_source => |node_off| {
                const decl = src_loc.container.decl;
                const tree = decl.container.file_scope.base.tree();
                const node_datas = tree.nodes.items(.data);
                const node_tags = tree.nodes.items(.tag);
                const node = decl.relativeToNodeIndex(node_off);
                const full = switch (node_tags[node]) {
                    .asm_simple => tree.asmSimple(node),
                    .@"asm" => tree.asmFull(node),
                    else => unreachable,
                };
                const main_tokens = tree.nodes.items(.main_token);
                const tok_index = main_tokens[full.ast.template];
                const token_starts = tree.tokens.items(.start);
                return token_starts[tok_index];
            },
            .node_offset_asm_ret_ty => |node_off| {
                const decl = src_loc.container.decl;
                const tree = decl.container.file_scope.base.tree();
                const node_datas = tree.nodes.items(.data);
                const node_tags = tree.nodes.items(.tag);
                const node = decl.relativeToNodeIndex(node_off);
                const full = switch (node_tags[node]) {
                    .asm_simple => tree.asmSimple(node),
                    .@"asm" => tree.asmFull(node),
                    else => unreachable,
                };
                const main_tokens = tree.nodes.items(.main_token);
                const tok_index = main_tokens[full.outputs[0]];
                const token_starts = tree.tokens.items(.start);
                return token_starts[tok_index];
            },

            .node_offset_for_cond, .node_offset_if_cond => |node_off| {
                const decl = src_loc.container.decl;
                const node = decl.relativeToNodeIndex(node_off);
                const tree = decl.container.file_scope.base.tree();
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
                const main_tokens = tree.nodes.items(.main_token);
                const tok_index = main_tokens[src_node];
                const token_starts = tree.tokens.items(.start);
                return token_starts[tok_index];
            },
            .node_offset_bin_lhs => |node_off| {
                const decl = src_loc.container.decl;
                const node = decl.relativeToNodeIndex(node_off);
                const tree = decl.container.file_scope.base.tree();
                const node_datas = tree.nodes.items(.data);
                const src_node = node_datas[node].lhs;
                const main_tokens = tree.nodes.items(.main_token);
                const tok_index = main_tokens[src_node];
                const token_starts = tree.tokens.items(.start);
                return token_starts[tok_index];
            },
            .node_offset_bin_rhs => |node_off| {
                const decl = src_loc.container.decl;
                const node = decl.relativeToNodeIndex(node_off);
                const tree = decl.container.file_scope.base.tree();
                const node_datas = tree.nodes.items(.data);
                const src_node = node_datas[node].rhs;
                const main_tokens = tree.nodes.items(.main_token);
                const tok_index = main_tokens[src_node];
                const token_starts = tree.tokens.items(.start);
                return token_starts[tok_index];
            },

            .node_offset_switch_operand => |node_off| {
                const decl = src_loc.container.decl;
                const node = decl.relativeToNodeIndex(node_off);
                const tree = decl.container.file_scope.base.tree();
                const node_datas = tree.nodes.items(.data);
                const src_node = node_datas[node].lhs;
                const main_tokens = tree.nodes.items(.main_token);
                const tok_index = main_tokens[src_node];
                const token_starts = tree.tokens.items(.start);
                return token_starts[tok_index];
            },

            .node_offset_switch_special_prong => |node_off| {
                const decl = src_loc.container.decl;
                const switch_node = decl.relativeToNodeIndex(node_off);
                const tree = decl.container.file_scope.base.tree();
                const node_datas = tree.nodes.items(.data);
                const node_tags = tree.nodes.items(.tag);
                const main_tokens = tree.nodes.items(.main_token);
                const extra = tree.extraData(node_datas[switch_node].rhs, ast.Node.SubRange);
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

                    const tok_index = main_tokens[case_node];
                    const token_starts = tree.tokens.items(.start);
                    return token_starts[tok_index];
                } else unreachable;
            },

            .node_offset_switch_range => |node_off| {
                const decl = src_loc.container.decl;
                const switch_node = decl.relativeToNodeIndex(node_off);
                const tree = decl.container.file_scope.base.tree();
                const node_datas = tree.nodes.items(.data);
                const node_tags = tree.nodes.items(.tag);
                const main_tokens = tree.nodes.items(.main_token);
                const extra = tree.extraData(node_datas[switch_node].rhs, ast.Node.SubRange);
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
                            const tok_index = main_tokens[item_node];
                            const token_starts = tree.tokens.items(.start);
                            return token_starts[tok_index];
                        }
                    }
                } else unreachable;
            },

            .node_offset_fn_type_cc => |node_off| {
                const decl = src_loc.container.decl;
                const tree = decl.container.file_scope.base.tree();
                const node_datas = tree.nodes.items(.data);
                const node_tags = tree.nodes.items(.tag);
                const node = decl.relativeToNodeIndex(node_off);
                var params: [1]ast.Node.Index = undefined;
                const full = switch (node_tags[node]) {
                    .fn_proto_simple => tree.fnProtoSimple(&params, node),
                    .fn_proto_multi => tree.fnProtoMulti(node),
                    .fn_proto_one => tree.fnProtoOne(&params, node),
                    .fn_proto => tree.fnProto(node),
                    else => unreachable,
                };
                const main_tokens = tree.nodes.items(.main_token);
                const tok_index = main_tokens[full.ast.callconv_expr];
                const token_starts = tree.tokens.items(.start);
                return token_starts[tok_index];
            },

            .node_offset_fn_type_ret_ty => |node_off| {
                const decl = src_loc.container.decl;
                const tree = decl.container.file_scope.base.tree();
                const node_datas = tree.nodes.items(.data);
                const node_tags = tree.nodes.items(.tag);
                const node = decl.relativeToNodeIndex(node_off);
                var params: [1]ast.Node.Index = undefined;
                const full = switch (node_tags[node]) {
                    .fn_proto_simple => tree.fnProtoSimple(&params, node),
                    .fn_proto_multi => tree.fnProtoMulti(node),
                    .fn_proto_one => tree.fnProtoOne(&params, node),
                    .fn_proto => tree.fnProto(node),
                    else => unreachable,
                };
                const main_tokens = tree.nodes.items(.main_token);
                const tok_index = main_tokens[full.ast.return_type];
                const token_starts = tree.tokens.items(.start);
                return token_starts[tok_index];
            },
        }
    }
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
    node_offset: i32,
    /// The source location points to two tokens left of the first token of an AST node,
    /// which is this value offset from its containing Decl node AST index.
    /// The Decl is determined contextually.
    node_offset_back2tok: i32,
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
    /// The source location points to the index expression of an array access
    /// expression, found by taking this AST node index offset from the containing
    /// Decl AST node, which points to an array access AST node. Next, navigate
    /// to the index expression.
    /// The Decl is determined contextually.
    node_offset_array_access_index: i32,
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
    /// which points to a binary expression AST node. Next, nagivate to the LHS.
    /// The Decl is determined contextually.
    node_offset_bin_lhs: i32,
    /// The source location points to the RHS of a binary expression, found
    /// by taking this AST node index offset from the containing Decl AST node,
    /// which points to a binary expression AST node. Next, nagivate to the RHS.
    /// The Decl is determined contextually.
    node_offset_bin_rhs: i32,
    /// The source location points to the operand of a switch expression, found
    /// by taking this AST node index offset from the containing Decl AST node,
    /// which points to a switch expression AST node. Next, nagivate to the operand.
    /// The Decl is determined contextually.
    node_offset_switch_operand: i32,
    /// The source location points to the else/`_` prong of a switch expression, found
    /// by taking this AST node index offset from the containing Decl AST node,
    /// which points to a switch expression AST node. Next, nagivate to the else/`_` prong.
    /// The Decl is determined contextually.
    node_offset_switch_special_prong: i32,
    /// The source location points to all the ranges of a switch expression, found
    /// by taking this AST node index offset from the containing Decl AST node,
    /// which points to a switch expression AST node. Next, nagivate to any of the
    /// range nodes. The error applies to all of them.
    /// The Decl is determined contextually.
    node_offset_switch_range: i32,
    /// The source location points to the calling convention of a function type
    /// expression, found by taking this AST node index offset from the containing
    /// Decl AST node, which points to a function type AST node. Next, nagivate to
    /// the calling convention node.
    /// The Decl is determined contextually.
    node_offset_fn_type_cc: i32,
    /// The source location points to the return type of a function type
    /// expression, found by taking this AST node index offset from the containing
    /// Decl AST node, which points to a function type AST node. Next, nagivate to
    /// the return type node.
    /// The Decl is determined contextually.
    node_offset_fn_type_ret_ty: i32,

    /// Upgrade to a `SrcLoc` based on the `Decl` or file in the provided scope.
    pub fn toSrcLoc(lazy: LazySrcLoc, scope: *Scope) SrcLoc {
        return switch (lazy) {
            .unneeded,
            .byte_abs,
            .token_abs,
            .node_abs,
            => .{
                .container = .{ .file_scope = scope.getFileScope() },
                .lazy = lazy,
            },

            .byte_offset,
            .token_offset,
            .node_offset,
            .node_offset_back2tok,
            .node_offset_var_decl_ty,
            .node_offset_for_cond,
            .node_offset_builtin_call_arg0,
            .node_offset_builtin_call_arg1,
            .node_offset_array_access_index,
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
            => .{
                .container = .{ .decl = scope.srcDecl().? },
                .lazy = lazy,
            },
        };
    }

    /// Upgrade to a `SrcLoc` based on the `Decl` provided.
    pub fn toSrcLocWithDecl(lazy: LazySrcLoc, decl: *Decl) SrcLoc {
        return switch (lazy) {
            .unneeded,
            .byte_abs,
            .token_abs,
            .node_abs,
            => .{
                .container = .{ .file_scope = decl.getFileScope() },
                .lazy = lazy,
            },

            .byte_offset,
            .token_offset,
            .node_offset,
            .node_offset_back2tok,
            .node_offset_var_decl_ty,
            .node_offset_for_cond,
            .node_offset_builtin_call_arg0,
            .node_offset_builtin_call_arg1,
            .node_offset_array_access_index,
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
            => .{
                .container = .{ .decl = decl },
                .lazy = lazy,
            },
        };
    }
};

pub const InnerError = error{ OutOfMemory, AnalysisFail };

pub fn deinit(mod: *Module) void {
    const gpa = mod.gpa;

    // The callsite of `Compilation.create` owns the `root_pkg`, however
    // Module owns the builtin and std packages that it adds.
    if (mod.root_pkg.table.remove("builtin")) |entry| {
        gpa.free(entry.key);
        entry.value.destroy(gpa);
    }
    if (mod.root_pkg.table.remove("std")) |entry| {
        gpa.free(entry.key);
        entry.value.destroy(gpa);
    }
    if (mod.root_pkg.table.remove("root")) |entry| {
        gpa.free(entry.key);
    }

    mod.compile_log_text.deinit(gpa);

    mod.zig_cache_artifact_directory.handle.close();

    mod.deletion_set.deinit(gpa);

    for (mod.decl_table.items()) |entry| {
        entry.value.destroy(mod);
    }
    mod.decl_table.deinit(gpa);

    for (mod.failed_decls.items()) |entry| {
        entry.value.destroy(gpa);
    }
    mod.failed_decls.deinit(gpa);

    for (mod.emit_h_failed_decls.items()) |entry| {
        entry.value.destroy(gpa);
    }
    mod.emit_h_failed_decls.deinit(gpa);

    for (mod.failed_files.items()) |entry| {
        entry.value.destroy(gpa);
    }
    mod.failed_files.deinit(gpa);

    for (mod.failed_exports.items()) |entry| {
        entry.value.destroy(gpa);
    }
    mod.failed_exports.deinit(gpa);

    mod.compile_log_decls.deinit(gpa);

    for (mod.decl_exports.items()) |entry| {
        const export_list = entry.value;
        gpa.free(export_list);
    }
    mod.decl_exports.deinit(gpa);

    for (mod.export_owners.items()) |entry| {
        freeExportList(gpa, entry.value);
    }
    mod.export_owners.deinit(gpa);

    mod.symbol_exports.deinit(gpa);
    mod.root_scope.destroy(gpa);

    var it = mod.global_error_set.iterator();
    while (it.next()) |entry| {
        gpa.free(entry.key);
    }
    mod.global_error_set.deinit(gpa);

    mod.error_name_list.deinit(gpa);

    for (mod.import_table.items()) |entry| {
        entry.value.destroy(gpa);
    }
    mod.import_table.deinit(gpa);
}

fn freeExportList(gpa: *Allocator, export_list: []*Export) void {
    for (export_list) |exp| {
        gpa.free(exp.options.name);
        gpa.destroy(exp);
    }
    gpa.free(export_list);
}

pub fn ensureDeclAnalyzed(mod: *Module, decl: *Decl) InnerError!void {
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
            log.debug("re-analyzing {s}", .{decl.name});

            // The exports this Decl performs will be re-discovered, so we remove them here
            // prior to re-analysis.
            mod.deleteDeclExports(decl);
            // Dependencies will be re-discovered, so we remove them here prior to re-analysis.
            for (decl.dependencies.items()) |entry| {
                const dep = entry.key;
                dep.removeDependant(decl);
                if (dep.dependants.items().len == 0 and !dep.deletion_flag) {
                    // We don't perform a deletion here, because this Decl or another one
                    // may end up referencing it before the update is complete.
                    dep.deletion_flag = true;
                    try mod.deletion_set.put(mod.gpa, dep, {});
                }
            }
            decl.dependencies.clearRetainingCapacity();

            break :blk true;
        },

        .unreferenced => false,
    };

    const type_changed = mod.astgenAndSemaDecl(decl) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        error.AnalysisFail => return error.AnalysisFail,
        else => {
            decl.analysis = .sema_failure_retryable;
            try mod.failed_decls.ensureCapacity(mod.gpa, mod.failed_decls.items().len + 1);
            mod.failed_decls.putAssumeCapacityNoClobber(decl, try ErrorMsg.create(
                mod.gpa,
                decl.srcLoc(),
                "unable to analyze: {s}",
                .{@errorName(err)},
            ));
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
                    => if (dep.generation != mod.generation) {
                        try mod.markOutdatedDecl(dep);
                    },
                }
            }
        }
    }
}

/// Returns `true` if the Decl type changed.
/// Returns `true` if this is the first time analyzing the Decl.
/// Returns `false` otherwise.
fn astgenAndSemaDecl(mod: *Module, decl: *Decl) !bool {
    const tracy = trace(@src());
    defer tracy.end();

    const tree = try mod.getAstTree(decl.container.file_scope);
    const node_tags = tree.nodes.items(.tag);
    const node_datas = tree.nodes.items(.data);
    const decl_node = decl.src_node;
    switch (node_tags[decl_node]) {
        .fn_decl => {
            const fn_proto = node_datas[decl_node].lhs;
            const body = node_datas[decl_node].rhs;
            switch (node_tags[fn_proto]) {
                .fn_proto_simple => {
                    var params: [1]ast.Node.Index = undefined;
                    return mod.astgenAndSemaFn(decl, tree.*, body, tree.fnProtoSimple(&params, fn_proto));
                },
                .fn_proto_multi => return mod.astgenAndSemaFn(decl, tree.*, body, tree.fnProtoMulti(fn_proto)),
                .fn_proto_one => {
                    var params: [1]ast.Node.Index = undefined;
                    return mod.astgenAndSemaFn(decl, tree.*, body, tree.fnProtoOne(&params, fn_proto));
                },
                .fn_proto => return mod.astgenAndSemaFn(decl, tree.*, body, tree.fnProto(fn_proto)),
                else => unreachable,
            }
        },
        .fn_proto_simple => {
            var params: [1]ast.Node.Index = undefined;
            return mod.astgenAndSemaFn(decl, tree.*, 0, tree.fnProtoSimple(&params, decl_node));
        },
        .fn_proto_multi => return mod.astgenAndSemaFn(decl, tree.*, 0, tree.fnProtoMulti(decl_node)),
        .fn_proto_one => {
            var params: [1]ast.Node.Index = undefined;
            return mod.astgenAndSemaFn(decl, tree.*, 0, tree.fnProtoOne(&params, decl_node));
        },
        .fn_proto => return mod.astgenAndSemaFn(decl, tree.*, 0, tree.fnProto(decl_node)),

        .global_var_decl => return mod.astgenAndSemaVarDecl(decl, tree.*, tree.globalVarDecl(decl_node)),
        .local_var_decl => return mod.astgenAndSemaVarDecl(decl, tree.*, tree.localVarDecl(decl_node)),
        .simple_var_decl => return mod.astgenAndSemaVarDecl(decl, tree.*, tree.simpleVarDecl(decl_node)),
        .aligned_var_decl => return mod.astgenAndSemaVarDecl(decl, tree.*, tree.alignedVarDecl(decl_node)),

        .@"comptime" => {
            decl.analysis = .in_progress;

            // A comptime decl does not store any value so we can just deinit this arena after analysis is done.
            var analysis_arena = std.heap.ArenaAllocator.init(mod.gpa);
            defer analysis_arena.deinit();

            var code: zir.Code = blk: {
                var astgen = try AstGen.init(mod, decl, &analysis_arena.allocator);
                defer astgen.deinit();

                var gen_scope: Scope.GenZir = .{
                    .force_comptime = true,
                    .parent = &decl.container.base,
                    .astgen = &astgen,
                };
                defer gen_scope.instructions.deinit(mod.gpa);

                const block_expr = node_datas[decl_node].lhs;
                _ = try AstGen.comptimeExpr(&gen_scope, &gen_scope.base, .none, block_expr);
                _ = try gen_scope.addBreak(.break_inline, 0, .void_value);

                const code = try gen_scope.finish();
                if (std.builtin.mode == .Debug and mod.comp.verbose_ir) {
                    code.dump(mod.gpa, "comptime_block", &gen_scope.base, 0) catch {};
                }
                break :blk code;
            };
            defer code.deinit(mod.gpa);

            var sema: Sema = .{
                .mod = mod,
                .gpa = mod.gpa,
                .arena = &analysis_arena.allocator,
                .code = code,
                .inst_map = try analysis_arena.allocator.alloc(*ir.Inst, code.instructions.len),
                .owner_decl = decl,
                .func = null,
                .owner_func = null,
                .param_inst_list = &.{},
            };
            var block_scope: Scope.Block = .{
                .parent = null,
                .sema = &sema,
                .src_decl = decl,
                .instructions = .{},
                .inlining = null,
                .is_comptime = true,
            };
            defer block_scope.instructions.deinit(mod.gpa);

            _ = try sema.root(&block_scope);

            decl.analysis = .complete;
            decl.generation = mod.generation;
            return true;
        },
        .@"usingnamespace" => @panic("TODO usingnamespace decl"),
        else => unreachable,
    }
}

fn astgenAndSemaFn(
    mod: *Module,
    decl: *Decl,
    tree: ast.Tree,
    body_node: ast.Node.Index,
    fn_proto: ast.full.FnProto,
) !bool {
    const tracy = trace(@src());
    defer tracy.end();

    decl.analysis = .in_progress;

    const token_tags = tree.tokens.items(.tag);

    // This arena allocator's memory is discarded at the end of this function. It is used
    // to determine the type of the function, and hence the type of the decl, which is needed
    // to complete the Decl analysis.
    var fn_type_scope_arena = std.heap.ArenaAllocator.init(mod.gpa);
    defer fn_type_scope_arena.deinit();

    var fn_type_astgen = try AstGen.init(mod, decl, &fn_type_scope_arena.allocator);
    defer fn_type_astgen.deinit();

    var fn_type_scope: Scope.GenZir = .{
        .force_comptime = true,
        .parent = &decl.container.base,
        .astgen = &fn_type_astgen,
    };
    defer fn_type_scope.instructions.deinit(mod.gpa);

    decl.is_pub = fn_proto.visib_token != null;

    // The AST params array does not contain anytype and ... parameters.
    // We must iterate to count how many param types to allocate.
    const param_count = blk: {
        var count: usize = 0;
        var it = fn_proto.iterate(tree);
        while (it.next()) |param| {
            if (param.anytype_ellipsis3) |some| if (token_tags[some] == .ellipsis3) break;
            count += 1;
        }
        break :blk count;
    };
    const param_types = try fn_type_scope_arena.allocator.alloc(zir.Inst.Ref, param_count);

    var is_var_args = false;
    {
        var param_type_i: usize = 0;
        var it = fn_proto.iterate(tree);
        while (it.next()) |param| : (param_type_i += 1) {
            if (param.anytype_ellipsis3) |token| {
                switch (token_tags[token]) {
                    .keyword_anytype => return mod.failTok(
                        &fn_type_scope.base,
                        token,
                        "TODO implement anytype parameter",
                        .{},
                    ),
                    .ellipsis3 => {
                        is_var_args = true;
                        break;
                    },
                    else => unreachable,
                }
            }
            const param_type_node = param.type_expr;
            assert(param_type_node != 0);
            param_types[param_type_i] =
                try AstGen.expr(&fn_type_scope, &fn_type_scope.base, .{ .ty = .type_type }, param_type_node);
        }
        assert(param_type_i == param_count);
    }
    if (fn_proto.lib_name) |lib_name_token| blk: {
        // TODO call std.zig.parseStringLiteral
        const lib_name_str = mem.trim(u8, tree.tokenSlice(lib_name_token), "\"");
        log.debug("extern fn symbol expected in lib '{s}'", .{lib_name_str});
        const target = mod.comp.getTarget();
        if (target_util.is_libc_lib_name(target, lib_name_str)) {
            if (!mod.comp.bin_file.options.link_libc) {
                return mod.failTok(
                    &fn_type_scope.base,
                    lib_name_token,
                    "dependency on libc must be explicitly specified in the build command",
                    .{},
                );
            }
            break :blk;
        }
        if (target_util.is_libcpp_lib_name(target, lib_name_str)) {
            if (!mod.comp.bin_file.options.link_libcpp) {
                return mod.failTok(
                    &fn_type_scope.base,
                    lib_name_token,
                    "dependency on libc++ must be explicitly specified in the build command",
                    .{},
                );
            }
            break :blk;
        }
        if (!target.isWasm() and !mod.comp.bin_file.options.pic) {
            return mod.failTok(
                &fn_type_scope.base,
                lib_name_token,
                "dependency on dynamic library '{s}' requires enabling Position Independent Code. Fixed by `-l{s}` or `-fPIC`.",
                .{ lib_name_str, lib_name_str },
            );
        }
        mod.comp.stage1AddLinkLib(lib_name_str) catch |err| {
            return mod.failTok(
                &fn_type_scope.base,
                lib_name_token,
                "unable to add link lib '{s}': {s}",
                .{ lib_name_str, @errorName(err) },
            );
        };
    }
    if (fn_proto.ast.align_expr != 0) {
        return mod.failNode(
            &fn_type_scope.base,
            fn_proto.ast.align_expr,
            "TODO implement function align expression",
            .{},
        );
    }
    if (fn_proto.ast.section_expr != 0) {
        return mod.failNode(
            &fn_type_scope.base,
            fn_proto.ast.section_expr,
            "TODO implement function section expression",
            .{},
        );
    }

    const maybe_bang = tree.firstToken(fn_proto.ast.return_type) - 1;
    if (token_tags[maybe_bang] == .bang) {
        return mod.failTok(&fn_type_scope.base, maybe_bang, "TODO implement inferred error sets", .{});
    }
    const return_type_inst = try AstGen.expr(
        &fn_type_scope,
        &fn_type_scope.base,
        .{ .ty = .type_type },
        fn_proto.ast.return_type,
    );

    const is_extern = if (fn_proto.extern_export_token) |maybe_export_token|
        token_tags[maybe_export_token] == .keyword_extern
    else
        false;

    const cc: zir.Inst.Ref = if (fn_proto.ast.callconv_expr != 0)
        // TODO instead of enum literal type, this needs to be the
        // std.builtin.CallingConvention enum. We need to implement importing other files
        // and enums in order to fix this.
        try AstGen.comptimeExpr(
            &fn_type_scope,
            &fn_type_scope.base,
            .{ .ty = .enum_literal_type },
            fn_proto.ast.callconv_expr,
        )
    else if (is_extern) // note: https://github.com/ziglang/zig/issues/5269
        try fn_type_scope.addSmallStr(.enum_literal_small, "C")
    else
        .none;

    const fn_type_inst: zir.Inst.Ref = if (cc != .none) fn_type: {
        const tag: zir.Inst.Tag = if (is_var_args) .fn_type_cc_var_args else .fn_type_cc;
        break :fn_type try fn_type_scope.addFnTypeCc(tag, .{
            .src_node = fn_proto.ast.proto_node,
            .ret_ty = return_type_inst,
            .param_types = param_types,
            .cc = cc,
        });
    } else fn_type: {
        const tag: zir.Inst.Tag = if (is_var_args) .fn_type_var_args else .fn_type;
        break :fn_type try fn_type_scope.addFnType(tag, .{
            .src_node = fn_proto.ast.proto_node,
            .ret_ty = return_type_inst,
            .param_types = param_types,
        });
    };
    _ = try fn_type_scope.addBreak(.break_inline, 0, fn_type_inst);

    // We need the memory for the Type to go into the arena for the Decl
    var decl_arena = std.heap.ArenaAllocator.init(mod.gpa);
    errdefer decl_arena.deinit();
    const decl_arena_state = try decl_arena.allocator.create(std.heap.ArenaAllocator.State);

    var fn_type_code = try fn_type_scope.finish();
    defer fn_type_code.deinit(mod.gpa);
    if (std.builtin.mode == .Debug and mod.comp.verbose_ir) {
        fn_type_code.dump(mod.gpa, "fn_type", &fn_type_scope.base, 0) catch {};
    }

    var fn_type_sema: Sema = .{
        .mod = mod,
        .gpa = mod.gpa,
        .arena = &decl_arena.allocator,
        .code = fn_type_code,
        .inst_map = try fn_type_scope_arena.allocator.alloc(*ir.Inst, fn_type_code.instructions.len),
        .owner_decl = decl,
        .func = null,
        .owner_func = null,
        .param_inst_list = &.{},
    };
    var block_scope: Scope.Block = .{
        .parent = null,
        .sema = &fn_type_sema,
        .src_decl = decl,
        .instructions = .{},
        .inlining = null,
        .is_comptime = true,
    };
    defer block_scope.instructions.deinit(mod.gpa);

    const fn_type = try fn_type_sema.rootAsType(&block_scope);
    if (body_node == 0) {
        if (!is_extern) {
            return mod.failNode(&block_scope.base, fn_proto.ast.fn_token, "non-extern function has no body", .{});
        }

        // Extern function.
        var type_changed = true;
        if (decl.typedValueManaged()) |tvm| {
            type_changed = !tvm.typed_value.ty.eql(fn_type);

            tvm.deinit(mod.gpa);
        }
        const fn_val = try Value.Tag.extern_fn.create(&decl_arena.allocator, decl);

        decl_arena_state.* = decl_arena.state;
        decl.typed_value = .{
            .most_recent = .{
                .typed_value = .{ .ty = fn_type, .val = fn_val },
                .arena = decl_arena_state,
            },
        };
        decl.analysis = .complete;
        decl.generation = mod.generation;

        try mod.comp.bin_file.allocateDeclIndexes(decl);
        try mod.comp.work_queue.writeItem(.{ .codegen_decl = decl });

        if (type_changed and mod.emit_h != null) {
            try mod.comp.work_queue.writeItem(.{ .emit_h_decl = decl });
        }

        return type_changed;
    }

    if (fn_type.fnIsVarArgs()) {
        return mod.failNode(&block_scope.base, fn_proto.ast.fn_token, "non-extern function is variadic", .{});
    }

    const new_func = try decl_arena.allocator.create(Fn);
    const fn_payload = try decl_arena.allocator.create(Value.Payload.Function);

    const fn_zir: zir.Code = blk: {
        // We put the ZIR inside the Decl arena.
        var astgen = try AstGen.init(mod, decl, &decl_arena.allocator);
        astgen.ref_start_index = @intCast(u32, zir.Inst.Ref.typed_value_map.len + param_count);
        defer astgen.deinit();

        var gen_scope: Scope.GenZir = .{
            .force_comptime = false,
            .parent = &decl.container.base,
            .astgen = &astgen,
        };
        defer gen_scope.instructions.deinit(mod.gpa);

        // Iterate over the parameters. We put the param names as the first N
        // items inside `extra` so that debug info later can refer to the parameter names
        // even while the respective source code is unloaded.
        try astgen.extra.ensureCapacity(mod.gpa, param_count);

        var params_scope = &gen_scope.base;
        var i: usize = 0;
        var it = fn_proto.iterate(tree);
        while (it.next()) |param| : (i += 1) {
            const name_token = param.name_token.?;
            const param_name = try mod.identifierTokenString(&gen_scope.base, name_token);
            const sub_scope = try decl_arena.allocator.create(Scope.LocalVal);
            sub_scope.* = .{
                .parent = params_scope,
                .gen_zir = &gen_scope,
                .name = param_name,
                // Implicit const list first, then implicit arg list.
                .inst = @intToEnum(zir.Inst.Ref, @intCast(u32, zir.Inst.Ref.typed_value_map.len + i)),
                .src = decl.tokSrcLoc(name_token),
            };
            params_scope = &sub_scope.base;

            // Additionally put the param name into `string_bytes` and reference it with
            // `extra` so that we have access to the data in codegen, for debug info.
            const str_index = @intCast(u32, astgen.string_bytes.items.len);
            astgen.extra.appendAssumeCapacity(str_index);
            const used_bytes = astgen.string_bytes.items.len;
            try astgen.string_bytes.ensureCapacity(mod.gpa, used_bytes + param_name.len + 1);
            astgen.string_bytes.appendSliceAssumeCapacity(param_name);
            astgen.string_bytes.appendAssumeCapacity(0);
        }

        _ = try AstGen.expr(&gen_scope, params_scope, .none, body_node);

        if (gen_scope.instructions.items.len == 0 or
            !astgen.instructions.items(.tag)[gen_scope.instructions.items.len - 1]
            .isNoReturn())
        {
            // astgen uses result location semantics to coerce return operands.
            // Since we are adding the return instruction here, we must handle the coercion.
            // We do this by using the `ret_coerce` instruction.
            _ = try gen_scope.addUnTok(.ret_coerce, .void_value, tree.lastToken(body_node));
        }

        const code = try gen_scope.finish();
        if (std.builtin.mode == .Debug and mod.comp.verbose_ir) {
            code.dump(mod.gpa, "fn_body", &gen_scope.base, param_count) catch {};
        }

        break :blk code;
    };

    const is_inline = fn_type.fnCallingConvention() == .Inline;
    const anal_state: Fn.Analysis = if (is_inline) .inline_only else .queued;

    new_func.* = .{
        .state = anal_state,
        .zir = fn_zir,
        .body = undefined,
        .owner_decl = decl,
    };
    fn_payload.* = .{
        .base = .{ .tag = .function },
        .data = new_func,
    };

    var prev_type_has_bits = false;
    var prev_is_inline = false;
    var type_changed = true;

    if (decl.typedValueManaged()) |tvm| {
        prev_type_has_bits = tvm.typed_value.ty.hasCodeGenBits();
        type_changed = !tvm.typed_value.ty.eql(fn_type);
        if (tvm.typed_value.val.castTag(.function)) |payload| {
            const prev_func = payload.data;
            prev_is_inline = prev_func.state == .inline_only;
            prev_func.deinit(mod.gpa);
        }

        tvm.deinit(mod.gpa);
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
    decl.generation = mod.generation;

    if (!is_inline and fn_type.hasCodeGenBits()) {
        // We don't fully codegen the decl until later, but we do need to reserve a global
        // offset table index for it. This allows us to codegen decls out of dependency order,
        // increasing how many computations can be done in parallel.
        try mod.comp.bin_file.allocateDeclIndexes(decl);
        try mod.comp.work_queue.writeItem(.{ .codegen_decl = decl });
        if (type_changed and mod.emit_h != null) {
            try mod.comp.work_queue.writeItem(.{ .emit_h_decl = decl });
        }
    } else if (!prev_is_inline and prev_type_has_bits) {
        mod.comp.bin_file.freeDecl(decl);
    }

    if (fn_proto.extern_export_token) |maybe_export_token| {
        if (token_tags[maybe_export_token] == .keyword_export) {
            if (is_inline) {
                return mod.failTok(
                    &block_scope.base,
                    maybe_export_token,
                    "export of inline function",
                    .{},
                );
            }
            const export_src = decl.tokSrcLoc(maybe_export_token);
            const name = tree.tokenSlice(fn_proto.name_token.?); // TODO identifierTokenString
            // The scope needs to have the decl in it.
            try mod.analyzeExport(&block_scope.base, export_src, name, decl);
        }
    }
    return type_changed or is_inline != prev_is_inline;
}

fn astgenAndSemaVarDecl(
    mod: *Module,
    decl: *Decl,
    tree: ast.Tree,
    var_decl: ast.full.VarDecl,
) !bool {
    const tracy = trace(@src());
    defer tracy.end();

    decl.analysis = .in_progress;
    decl.is_pub = var_decl.visib_token != null;

    const token_tags = tree.tokens.items(.tag);

    // We need the memory for the Type to go into the arena for the Decl
    var decl_arena = std.heap.ArenaAllocator.init(mod.gpa);
    errdefer decl_arena.deinit();
    const decl_arena_state = try decl_arena.allocator.create(std.heap.ArenaAllocator.State);

    // Used for simple error reporting.
    var decl_scope: Scope.DeclRef = .{ .decl = decl };

    const is_extern = blk: {
        const maybe_extern_token = var_decl.extern_export_token orelse break :blk false;
        break :blk token_tags[maybe_extern_token] == .keyword_extern;
    };

    if (var_decl.lib_name) |lib_name| {
        assert(is_extern);
        return mod.failTok(&decl_scope.base, lib_name, "TODO implement function library name", .{});
    }
    const is_mutable = token_tags[var_decl.ast.mut_token] == .keyword_var;
    const is_threadlocal = if (var_decl.threadlocal_token) |some| blk: {
        if (!is_mutable) {
            return mod.failTok(&decl_scope.base, some, "threadlocal variable cannot be constant", .{});
        }
        break :blk true;
    } else false;
    assert(var_decl.comptime_token == null);
    if (var_decl.ast.align_node != 0) {
        return mod.failNode(
            &decl_scope.base,
            var_decl.ast.align_node,
            "TODO implement function align expression",
            .{},
        );
    }
    if (var_decl.ast.section_node != 0) {
        return mod.failNode(
            &decl_scope.base,
            var_decl.ast.section_node,
            "TODO implement function section expression",
            .{},
        );
    }

    const var_info: struct { ty: Type, val: ?Value } = if (var_decl.ast.init_node != 0) vi: {
        if (is_extern) {
            return mod.failNode(
                &decl_scope.base,
                var_decl.ast.init_node,
                "extern variables have no initializers",
                .{},
            );
        }

        var gen_scope_arena = std.heap.ArenaAllocator.init(mod.gpa);
        defer gen_scope_arena.deinit();

        var astgen = try AstGen.init(mod, decl, &gen_scope_arena.allocator);
        defer astgen.deinit();

        var gen_scope: Scope.GenZir = .{
            .force_comptime = true,
            .parent = &decl.container.base,
            .astgen = &astgen,
        };
        defer gen_scope.instructions.deinit(mod.gpa);

        const init_result_loc: AstGen.ResultLoc = if (var_decl.ast.type_node != 0) .{
            .ty = try AstGen.expr(&gen_scope, &gen_scope.base, .{ .ty = .type_type }, var_decl.ast.type_node),
        } else .none;

        const init_inst = try AstGen.comptimeExpr(
            &gen_scope,
            &gen_scope.base,
            init_result_loc,
            var_decl.ast.init_node,
        );
        _ = try gen_scope.addBreak(.break_inline, 0, init_inst);
        var code = try gen_scope.finish();
        defer code.deinit(mod.gpa);
        if (std.builtin.mode == .Debug and mod.comp.verbose_ir) {
            code.dump(mod.gpa, "var_init", &gen_scope.base, 0) catch {};
        }

        var sema: Sema = .{
            .mod = mod,
            .gpa = mod.gpa,
            .arena = &gen_scope_arena.allocator,
            .code = code,
            .inst_map = try gen_scope_arena.allocator.alloc(*ir.Inst, code.instructions.len),
            .owner_decl = decl,
            .func = null,
            .owner_func = null,
            .param_inst_list = &.{},
        };
        var block_scope: Scope.Block = .{
            .parent = null,
            .sema = &sema,
            .src_decl = decl,
            .instructions = .{},
            .inlining = null,
            .is_comptime = true,
        };
        defer block_scope.instructions.deinit(mod.gpa);

        const init_inst_zir_ref = try sema.rootAsRef(&block_scope);
        // The result location guarantees the type coercion.
        const analyzed_init_inst = try sema.resolveInst(init_inst_zir_ref);
        // The is_comptime in the Scope.Block guarantees the result is comptime-known.
        const val = analyzed_init_inst.value().?;

        break :vi .{
            .ty = try analyzed_init_inst.ty.copy(&decl_arena.allocator),
            .val = try val.copy(&decl_arena.allocator),
        };
    } else if (!is_extern) {
        return mod.failTok(
            &decl_scope.base,
            var_decl.ast.mut_token,
            "variables must be initialized",
            .{},
        );
    } else if (var_decl.ast.type_node != 0) vi: {
        var type_scope_arena = std.heap.ArenaAllocator.init(mod.gpa);
        defer type_scope_arena.deinit();

        var astgen = try AstGen.init(mod, decl, &type_scope_arena.allocator);
        defer astgen.deinit();

        var type_scope: Scope.GenZir = .{
            .force_comptime = true,
            .parent = &decl.container.base,
            .astgen = &astgen,
        };
        defer type_scope.instructions.deinit(mod.gpa);

        const var_type = try AstGen.typeExpr(&type_scope, &type_scope.base, var_decl.ast.type_node);
        _ = try type_scope.addBreak(.break_inline, 0, var_type);

        var code = try type_scope.finish();
        defer code.deinit(mod.gpa);
        if (std.builtin.mode == .Debug and mod.comp.verbose_ir) {
            code.dump(mod.gpa, "var_type", &type_scope.base, 0) catch {};
        }

        var sema: Sema = .{
            .mod = mod,
            .gpa = mod.gpa,
            .arena = &type_scope_arena.allocator,
            .code = code,
            .inst_map = try type_scope_arena.allocator.alloc(*ir.Inst, code.instructions.len),
            .owner_decl = decl,
            .func = null,
            .owner_func = null,
            .param_inst_list = &.{},
        };
        var block_scope: Scope.Block = .{
            .parent = null,
            .sema = &sema,
            .src_decl = decl,
            .instructions = .{},
            .inlining = null,
            .is_comptime = true,
        };
        defer block_scope.instructions.deinit(mod.gpa);

        const ty = try sema.rootAsType(&block_scope);

        break :vi .{
            .ty = try ty.copy(&decl_arena.allocator),
            .val = null,
        };
    } else {
        return mod.failTok(
            &decl_scope.base,
            var_decl.ast.mut_token,
            "unable to infer variable type",
            .{},
        );
    };

    if (is_mutable and !var_info.ty.isValidVarType(is_extern)) {
        return mod.failTok(
            &decl_scope.base,
            var_decl.ast.mut_token,
            "variable of type '{}' must be const",
            .{var_info.ty},
        );
    }

    var type_changed = true;
    if (decl.typedValueManaged()) |tvm| {
        type_changed = !tvm.typed_value.ty.eql(var_info.ty);

        tvm.deinit(mod.gpa);
    }

    const new_variable = try decl_arena.allocator.create(Var);
    new_variable.* = .{
        .owner_decl = decl,
        .init = var_info.val orelse undefined,
        .is_extern = is_extern,
        .is_mutable = is_mutable,
        .is_threadlocal = is_threadlocal,
    };
    const var_val = try Value.Tag.variable.create(&decl_arena.allocator, new_variable);

    decl_arena_state.* = decl_arena.state;
    decl.typed_value = .{
        .most_recent = .{
            .typed_value = .{
                .ty = var_info.ty,
                .val = var_val,
            },
            .arena = decl_arena_state,
        },
    };
    decl.analysis = .complete;
    decl.generation = mod.generation;

    if (var_decl.extern_export_token) |maybe_export_token| {
        if (token_tags[maybe_export_token] == .keyword_export) {
            const export_src = decl.tokSrcLoc(maybe_export_token);
            const name_token = var_decl.ast.mut_token + 1;
            const name = tree.tokenSlice(name_token); // TODO identifierTokenString
            // The scope needs to have the decl in it.
            try mod.analyzeExport(&decl_scope.base, export_src, name, decl);
        }
    }
    return type_changed;
}

/// Returns the depender's index of the dependee.
pub fn declareDeclDependency(mod: *Module, depender: *Decl, dependee: *Decl) !u32 {
    try depender.dependencies.ensureCapacity(mod.gpa, depender.dependencies.count() + 1);
    try dependee.dependants.ensureCapacity(mod.gpa, dependee.dependants.count() + 1);

    if (dependee.deletion_flag) {
        dependee.deletion_flag = false;
        mod.deletion_set.removeAssertDiscard(dependee);
    }

    dependee.dependants.putAssumeCapacity(depender, {});
    const gop = depender.dependencies.getOrPutAssumeCapacity(dependee);
    return @intCast(u32, gop.index);
}

pub fn getAstTree(mod: *Module, root_scope: *Scope.File) !*const ast.Tree {
    const tracy = trace(@src());
    defer tracy.end();

    switch (root_scope.status) {
        .never_loaded, .unloaded_success => {
            try mod.failed_files.ensureCapacity(mod.gpa, mod.failed_files.items().len + 1);

            const source = try root_scope.getSource(mod);

            var keep_tree = false;
            root_scope.tree = try std.zig.parse(mod.gpa, source);
            defer if (!keep_tree) root_scope.tree.deinit(mod.gpa);

            const tree = &root_scope.tree;

            if (tree.errors.len != 0) {
                const parse_err = tree.errors[0];

                var msg = std.ArrayList(u8).init(mod.gpa);
                defer msg.deinit();

                const token_starts = tree.tokens.items(.start);

                try tree.renderError(parse_err, msg.writer());
                const err_msg = try mod.gpa.create(ErrorMsg);
                err_msg.* = .{
                    .src_loc = .{
                        .container = .{ .file_scope = root_scope },
                        .lazy = .{ .byte_abs = token_starts[parse_err.token] },
                    },
                    .msg = msg.toOwnedSlice(),
                };

                mod.failed_files.putAssumeCapacityNoClobber(root_scope, err_msg);
                root_scope.status = .unloaded_parse_failure;
                return error.AnalysisFail;
            }

            root_scope.status = .loaded_success;
            keep_tree = true;

            return tree;
        },

        .unloaded_parse_failure => return error.AnalysisFail,

        .loaded_success => return &root_scope.tree,
    }
}

pub fn analyzeContainer(mod: *Module, container_scope: *Scope.Container) !void {
    const tracy = trace(@src());
    defer tracy.end();

    // We may be analyzing it for the first time, or this may be
    // an incremental update. This code handles both cases.
    const tree = try mod.getAstTree(container_scope.file_scope);
    const node_tags = tree.nodes.items(.tag);
    const node_datas = tree.nodes.items(.data);
    const decls = tree.rootDecls();

    try mod.comp.work_queue.ensureUnusedCapacity(decls.len);
    try container_scope.decls.ensureCapacity(mod.gpa, decls.len);

    // Keep track of the decls that we expect to see in this file so that
    // we know which ones have been deleted.
    var deleted_decls = std.AutoArrayHashMap(*Decl, void).init(mod.gpa);
    defer deleted_decls.deinit();
    try deleted_decls.ensureCapacity(container_scope.decls.items().len);
    for (container_scope.decls.items()) |entry| {
        deleted_decls.putAssumeCapacityNoClobber(entry.key, {});
    }

    // Keep track of decls that are invalidated from the update. Ultimately,
    // the goal is to queue up `analyze_decl` tasks in the work queue for
    // the outdated decls, but we cannot queue up the tasks until after
    // we find out which ones have been deleted, otherwise there would be
    // deleted Decl pointers in the work queue.
    var outdated_decls = std.AutoArrayHashMap(*Decl, void).init(mod.gpa);
    defer outdated_decls.deinit();

    for (decls) |decl_node| switch (node_tags[decl_node]) {
        .fn_decl => {
            const fn_proto = node_datas[decl_node].lhs;
            const body = node_datas[decl_node].rhs;
            switch (node_tags[fn_proto]) {
                .fn_proto_simple => {
                    var params: [1]ast.Node.Index = undefined;
                    try mod.semaContainerFn(
                        container_scope,
                        &deleted_decls,
                        &outdated_decls,
                        decl_node,
                        tree.*,
                        body,
                        tree.fnProtoSimple(&params, fn_proto),
                    );
                },
                .fn_proto_multi => try mod.semaContainerFn(
                    container_scope,
                    &deleted_decls,
                    &outdated_decls,
                    decl_node,
                    tree.*,
                    body,
                    tree.fnProtoMulti(fn_proto),
                ),
                .fn_proto_one => {
                    var params: [1]ast.Node.Index = undefined;
                    try mod.semaContainerFn(
                        container_scope,
                        &deleted_decls,
                        &outdated_decls,
                        decl_node,
                        tree.*,
                        body,
                        tree.fnProtoOne(&params, fn_proto),
                    );
                },
                .fn_proto => try mod.semaContainerFn(
                    container_scope,
                    &deleted_decls,
                    &outdated_decls,
                    decl_node,
                    tree.*,
                    body,
                    tree.fnProto(fn_proto),
                ),
                else => unreachable,
            }
        },
        .fn_proto_simple => {
            var params: [1]ast.Node.Index = undefined;
            try mod.semaContainerFn(
                container_scope,
                &deleted_decls,
                &outdated_decls,
                decl_node,
                tree.*,
                0,
                tree.fnProtoSimple(&params, decl_node),
            );
        },
        .fn_proto_multi => try mod.semaContainerFn(
            container_scope,
            &deleted_decls,
            &outdated_decls,
            decl_node,
            tree.*,
            0,
            tree.fnProtoMulti(decl_node),
        ),
        .fn_proto_one => {
            var params: [1]ast.Node.Index = undefined;
            try mod.semaContainerFn(
                container_scope,
                &deleted_decls,
                &outdated_decls,
                decl_node,
                tree.*,
                0,
                tree.fnProtoOne(&params, decl_node),
            );
        },
        .fn_proto => try mod.semaContainerFn(
            container_scope,
            &deleted_decls,
            &outdated_decls,
            decl_node,
            tree.*,
            0,
            tree.fnProto(decl_node),
        ),

        .global_var_decl => try mod.semaContainerVar(
            container_scope,
            &deleted_decls,
            &outdated_decls,
            decl_node,
            tree.*,
            tree.globalVarDecl(decl_node),
        ),
        .local_var_decl => try mod.semaContainerVar(
            container_scope,
            &deleted_decls,
            &outdated_decls,
            decl_node,
            tree.*,
            tree.localVarDecl(decl_node),
        ),
        .simple_var_decl => try mod.semaContainerVar(
            container_scope,
            &deleted_decls,
            &outdated_decls,
            decl_node,
            tree.*,
            tree.simpleVarDecl(decl_node),
        ),
        .aligned_var_decl => try mod.semaContainerVar(
            container_scope,
            &deleted_decls,
            &outdated_decls,
            decl_node,
            tree.*,
            tree.alignedVarDecl(decl_node),
        ),

        .@"comptime" => {
            const name_index = mod.getNextAnonNameIndex();
            const name = try std.fmt.allocPrint(mod.gpa, "__comptime_{d}", .{name_index});
            defer mod.gpa.free(name);

            const name_hash = container_scope.fullyQualifiedNameHash(name);
            const contents_hash = std.zig.hashSrc(tree.getNodeSource(decl_node));

            const new_decl = try mod.createNewDecl(&container_scope.base, name, decl_node, name_hash, contents_hash);
            container_scope.decls.putAssumeCapacity(new_decl, {});
            mod.comp.work_queue.writeItemAssumeCapacity(.{ .analyze_decl = new_decl });
        },

        // Container fields are handled in AstGen.
        .container_field_init,
        .container_field_align,
        .container_field,
        => continue,

        .test_decl => {
            if (mod.comp.bin_file.options.is_test) {
                log.err("TODO: analyze test decl", .{});
            }
        },
        .@"usingnamespace" => {
            log.err("TODO: analyze usingnamespace decl", .{});
        },
        else => unreachable,
    };
    // Handle explicitly deleted decls from the source code. This is one of two
    // places that Decl deletions happen. The other is in `Compilation`, after
    // `performAllTheWork`, where we iterate over `Module.deletion_set` and
    // delete Decls which are no longer referenced.
    // If a Decl is explicitly deleted from source, and also no longer referenced,
    // it may be both in this `deleted_decls` set, as well as in the
    // `Module.deletion_set`. To avoid deleting it twice, we remove it from the
    // deletion set at this time.
    for (deleted_decls.items()) |entry| {
        const decl = entry.key;
        log.debug("'{s}' deleted from source", .{decl.name});
        if (decl.deletion_flag) {
            log.debug("'{s}' redundantly in deletion set; removing", .{decl.name});
            mod.deletion_set.removeAssertDiscard(decl);
        }
        try mod.deleteDecl(decl, &outdated_decls);
    }
    // Finally we can queue up re-analysis tasks after we have processed
    // the deleted decls.
    for (outdated_decls.items()) |entry| {
        try mod.markOutdatedDecl(entry.key);
    }
}

fn semaContainerFn(
    mod: *Module,
    container_scope: *Scope.Container,
    deleted_decls: *std.AutoArrayHashMap(*Decl, void),
    outdated_decls: *std.AutoArrayHashMap(*Decl, void),
    decl_node: ast.Node.Index,
    tree: ast.Tree,
    body_node: ast.Node.Index,
    fn_proto: ast.full.FnProto,
) !void {
    const tracy = trace(@src());
    defer tracy.end();

    // We will create a Decl for it regardless of analysis status.
    const name_token = fn_proto.name_token orelse {
        // This problem will go away with #1717.
        @panic("TODO missing function name");
    };
    const name = tree.tokenSlice(name_token); // TODO use identifierTokenString
    const name_hash = container_scope.fullyQualifiedNameHash(name);
    const contents_hash = std.zig.hashSrc(tree.getNodeSource(decl_node));
    if (mod.decl_table.get(name_hash)) |decl| {
        // Update the AST Node index of the decl, even if its contents are unchanged, it may
        // have been re-ordered.
        const prev_src_node = decl.src_node;
        decl.src_node = decl_node;
        if (deleted_decls.swapRemove(decl) == null) {
            decl.analysis = .sema_failure;
            const msg = try ErrorMsg.create(mod.gpa, .{
                .container = .{ .file_scope = container_scope.file_scope },
                .lazy = .{ .token_abs = name_token },
            }, "redefinition of '{s}'", .{decl.name});
            errdefer msg.destroy(mod.gpa);
            const other_src_loc: SrcLoc = .{
                .container = .{ .file_scope = decl.container.file_scope },
                .lazy = .{ .node_abs = prev_src_node },
            };
            try mod.errNoteNonLazy(other_src_loc, msg, "previous definition here", .{});
            try mod.failed_decls.putNoClobber(mod.gpa, decl, msg);
        } else {
            if (!srcHashEql(decl.contents_hash, contents_hash)) {
                try outdated_decls.put(decl, {});
                decl.contents_hash = contents_hash;
            } else switch (mod.comp.bin_file.tag) {
                .coff => {
                    // TODO Implement for COFF
                },
                .elf => if (decl.fn_link.elf.len != 0) {
                    // TODO Look into detecting when this would be unnecessary by storing enough state
                    // in `Decl` to notice that the line number did not change.
                    mod.comp.work_queue.writeItemAssumeCapacity(.{ .update_line_number = decl });
                },
                .macho => if (decl.fn_link.macho.len != 0) {
                    // TODO Look into detecting when this would be unnecessary by storing enough state
                    // in `Decl` to notice that the line number did not change.
                    mod.comp.work_queue.writeItemAssumeCapacity(.{ .update_line_number = decl });
                },
                .c, .wasm, .spirv => {},
            }
        }
    } else {
        const new_decl = try mod.createNewDecl(&container_scope.base, name, decl_node, name_hash, contents_hash);
        container_scope.decls.putAssumeCapacity(new_decl, {});
        if (fn_proto.extern_export_token) |maybe_export_token| {
            const token_tags = tree.tokens.items(.tag);
            if (token_tags[maybe_export_token] == .keyword_export) {
                mod.comp.work_queue.writeItemAssumeCapacity(.{ .analyze_decl = new_decl });
            }
        }
        new_decl.is_pub = fn_proto.visib_token != null;
    }
}

fn semaContainerVar(
    mod: *Module,
    container_scope: *Scope.Container,
    deleted_decls: *std.AutoArrayHashMap(*Decl, void),
    outdated_decls: *std.AutoArrayHashMap(*Decl, void),
    decl_node: ast.Node.Index,
    tree: ast.Tree,
    var_decl: ast.full.VarDecl,
) !void {
    const tracy = trace(@src());
    defer tracy.end();

    const name_token = var_decl.ast.mut_token + 1;
    const name = tree.tokenSlice(name_token); // TODO identifierTokenString
    const name_hash = container_scope.fullyQualifiedNameHash(name);
    const contents_hash = std.zig.hashSrc(tree.getNodeSource(decl_node));
    if (mod.decl_table.get(name_hash)) |decl| {
        // Update the AST Node index of the decl, even if its contents are unchanged, it may
        // have been re-ordered.
        const prev_src_node = decl.src_node;
        decl.src_node = decl_node;
        if (deleted_decls.swapRemove(decl) == null) {
            decl.analysis = .sema_failure;
            const msg = try ErrorMsg.create(mod.gpa, .{
                .container = .{ .file_scope = container_scope.file_scope },
                .lazy = .{ .token_abs = name_token },
            }, "redefinition of '{s}'", .{decl.name});
            errdefer msg.destroy(mod.gpa);
            const other_src_loc: SrcLoc = .{
                .container = .{ .file_scope = decl.container.file_scope },
                .lazy = .{ .node_abs = prev_src_node },
            };
            try mod.errNoteNonLazy(other_src_loc, msg, "previous definition here", .{});
            try mod.failed_decls.putNoClobber(mod.gpa, decl, msg);
        } else if (!srcHashEql(decl.contents_hash, contents_hash)) {
            try outdated_decls.put(decl, {});
            decl.contents_hash = contents_hash;
        }
    } else {
        const new_decl = try mod.createNewDecl(&container_scope.base, name, decl_node, name_hash, contents_hash);
        container_scope.decls.putAssumeCapacity(new_decl, {});
        if (var_decl.extern_export_token) |maybe_export_token| {
            const token_tags = tree.tokens.items(.tag);
            if (token_tags[maybe_export_token] == .keyword_export) {
                mod.comp.work_queue.writeItemAssumeCapacity(.{ .analyze_decl = new_decl });
            }
        }
        new_decl.is_pub = var_decl.visib_token != null;
    }
}

pub fn deleteDecl(
    mod: *Module,
    decl: *Decl,
    outdated_decls: ?*std.AutoArrayHashMap(*Decl, void),
) !void {
    const tracy = trace(@src());
    defer tracy.end();

    log.debug("deleting decl '{s}'", .{decl.name});

    if (outdated_decls) |map| {
        _ = map.swapRemove(decl);
        try map.ensureCapacity(map.count() + decl.dependants.count());
    }
    try mod.deletion_set.ensureCapacity(mod.gpa, mod.deletion_set.count() +
        decl.dependencies.count());

    // Remove from the namespace it resides in. In the case of an anonymous Decl it will
    // not be present in the set, and this does nothing.
    decl.container.removeDecl(decl);

    const name_hash = decl.fullyQualifiedNameHash();
    mod.decl_table.removeAssertDiscard(name_hash);
    // Remove itself from its dependencies, because we are about to destroy the decl pointer.
    for (decl.dependencies.items()) |entry| {
        const dep = entry.key;
        dep.removeDependant(decl);
        if (dep.dependants.items().len == 0 and !dep.deletion_flag) {
            // We don't recursively perform a deletion here, because during the update,
            // another reference to it may turn up.
            dep.deletion_flag = true;
            mod.deletion_set.putAssumeCapacity(dep, {});
        }
    }
    // Anything that depends on this deleted decl needs to be re-analyzed.
    for (decl.dependants.items()) |entry| {
        const dep = entry.key;
        dep.removeDependency(decl);
        if (outdated_decls) |map| {
            map.putAssumeCapacity(dep, {});
        } else if (std.debug.runtime_safety) {
            // If `outdated_decls` is `null`, it means we're being called from
            // `Compilation` after `performAllTheWork` and we cannot queue up any
            // more work. `dep` must necessarily be another Decl that is no longer
            // being referenced, and will be in the `deletion_set`. Otherwise,
            // something has gone wrong.
            assert(mod.deletion_set.contains(dep));
        }
    }
    if (mod.failed_decls.swapRemove(decl)) |entry| {
        entry.value.destroy(mod.gpa);
    }
    if (mod.emit_h_failed_decls.swapRemove(decl)) |entry| {
        entry.value.destroy(mod.gpa);
    }
    _ = mod.compile_log_decls.swapRemove(decl);
    mod.deleteDeclExports(decl);
    mod.comp.bin_file.freeDecl(decl);

    decl.destroy(mod);
}

/// Delete all the Export objects that are caused by this Decl. Re-analysis of
/// this Decl will cause them to be re-created (or not).
fn deleteDeclExports(mod: *Module, decl: *Decl) void {
    const kv = mod.export_owners.swapRemove(decl) orelse return;

    for (kv.value) |exp| {
        if (mod.decl_exports.getEntry(exp.exported_decl)) |decl_exports_kv| {
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
            decl_exports_kv.value = mod.gpa.shrink(list, new_len);
            if (new_len == 0) {
                mod.decl_exports.removeAssertDiscard(exp.exported_decl);
            }
        }
        if (mod.comp.bin_file.cast(link.File.Elf)) |elf| {
            elf.deleteExport(exp.link.elf);
        }
        if (mod.comp.bin_file.cast(link.File.MachO)) |macho| {
            macho.deleteExport(exp.link.macho);
        }
        if (mod.failed_exports.swapRemove(exp)) |entry| {
            entry.value.destroy(mod.gpa);
        }
        _ = mod.symbol_exports.swapRemove(exp.options.name);
        mod.gpa.free(exp.options.name);
        mod.gpa.destroy(exp);
    }
    mod.gpa.free(kv.value);
}

pub fn analyzeFnBody(mod: *Module, decl: *Decl, func: *Fn) !void {
    const tracy = trace(@src());
    defer tracy.end();

    // Use the Decl's arena for function memory.
    var arena = decl.typed_value.most_recent.arena.?.promote(mod.gpa);
    defer decl.typed_value.most_recent.arena.?.* = arena.state;

    const fn_ty = decl.typed_value.most_recent.typed_value.ty;
    const param_inst_list = try mod.gpa.alloc(*ir.Inst, fn_ty.fnParamLen());
    defer mod.gpa.free(param_inst_list);

    for (param_inst_list) |*param_inst, param_index| {
        const param_type = fn_ty.fnParamType(param_index);
        const name = func.zir.nullTerminatedString(func.zir.extra[param_index]);
        const arg_inst = try arena.allocator.create(ir.Inst.Arg);
        arg_inst.* = .{
            .base = .{
                .tag = .arg,
                .ty = param_type,
                .src = .unneeded,
            },
            .name = name,
        };
        param_inst.* = &arg_inst.base;
    }

    var sema: Sema = .{
        .mod = mod,
        .gpa = mod.gpa,
        .arena = &arena.allocator,
        .code = func.zir,
        .inst_map = try mod.gpa.alloc(*ir.Inst, func.zir.instructions.len),
        .owner_decl = decl,
        .func = func,
        .owner_func = func,
        .param_inst_list = param_inst_list,
    };
    defer mod.gpa.free(sema.inst_map);

    var inner_block: Scope.Block = .{
        .parent = null,
        .sema = &sema,
        .src_decl = decl,
        .instructions = .{},
        .inlining = null,
        .is_comptime = false,
    };
    defer inner_block.instructions.deinit(mod.gpa);

    // TZIR currently requires the arg parameters to be the first N instructions
    try inner_block.instructions.appendSlice(mod.gpa, param_inst_list);

    func.state = .in_progress;
    log.debug("set {s} to in_progress", .{decl.name});

    _ = try sema.root(&inner_block);

    const instructions = try arena.allocator.dupe(*ir.Inst, inner_block.instructions.items);
    func.state = .success;
    func.body = .{ .instructions = instructions };
    log.debug("set {s} to success", .{decl.name});
}

fn markOutdatedDecl(mod: *Module, decl: *Decl) !void {
    log.debug("mark {s} outdated", .{decl.name});
    try mod.comp.work_queue.writeItem(.{ .analyze_decl = decl });
    if (mod.failed_decls.swapRemove(decl)) |entry| {
        entry.value.destroy(mod.gpa);
    }
    if (mod.emit_h_failed_decls.swapRemove(decl)) |entry| {
        entry.value.destroy(mod.gpa);
    }
    _ = mod.compile_log_decls.swapRemove(decl);
    decl.analysis = .outdated;
}

fn allocateNewDecl(
    mod: *Module,
    scope: *Scope,
    src_node: ast.Node.Index,
    contents_hash: std.zig.SrcHash,
) !*Decl {
    // If we have emit-h then we must allocate a bigger structure to store the emit-h state.
    const new_decl: *Decl = if (mod.emit_h != null) blk: {
        const parent_struct = try mod.gpa.create(DeclPlusEmitH);
        parent_struct.* = .{
            .emit_h = .{},
            .decl = undefined,
        };
        break :blk &parent_struct.decl;
    } else try mod.gpa.create(Decl);

    new_decl.* = .{
        .name = "",
        .container = scope.namespace(),
        .src_node = src_node,
        .typed_value = .{ .never_succeeded = {} },
        .analysis = .unreferenced,
        .deletion_flag = false,
        .contents_hash = contents_hash,
        .link = switch (mod.comp.bin_file.tag) {
            .coff => .{ .coff = link.File.Coff.TextBlock.empty },
            .elf => .{ .elf = link.File.Elf.TextBlock.empty },
            .macho => .{ .macho = link.File.MachO.TextBlock.empty },
            .c => .{ .c = link.File.C.DeclBlock.empty },
            .wasm => .{ .wasm = link.File.Wasm.DeclBlock.empty },
            .spirv => .{ .spirv = {} },
        },
        .fn_link = switch (mod.comp.bin_file.tag) {
            .coff => .{ .coff = {} },
            .elf => .{ .elf = link.File.Elf.SrcFn.empty },
            .macho => .{ .macho = link.File.MachO.SrcFn.empty },
            .c => .{ .c = link.File.C.FnBlock.empty },
            .wasm => .{ .wasm = link.File.Wasm.FnData.empty },
            .spirv => .{ .spirv = .{} },
        },
        .generation = 0,
        .is_pub = false,
    };
    return new_decl;
}

fn createNewDecl(
    mod: *Module,
    scope: *Scope,
    decl_name: []const u8,
    src_node: ast.Node.Index,
    name_hash: Scope.NameHash,
    contents_hash: std.zig.SrcHash,
) !*Decl {
    try mod.decl_table.ensureCapacity(mod.gpa, mod.decl_table.items().len + 1);
    const new_decl = try mod.allocateNewDecl(scope, src_node, contents_hash);
    errdefer mod.gpa.destroy(new_decl);
    new_decl.name = try mem.dupeZ(mod.gpa, u8, decl_name);
    mod.decl_table.putAssumeCapacityNoClobber(name_hash, new_decl);
    return new_decl;
}

/// Get error value for error tag `name`.
pub fn getErrorValue(mod: *Module, name: []const u8) !std.StringHashMapUnmanaged(ErrorInt).Entry {
    const gop = try mod.global_error_set.getOrPut(mod.gpa, name);
    if (gop.found_existing)
        return gop.entry.*;

    errdefer mod.global_error_set.removeAssertDiscard(name);
    try mod.error_name_list.ensureCapacity(mod.gpa, mod.error_name_list.items.len + 1);
    gop.entry.key = try mod.gpa.dupe(u8, name);
    gop.entry.value = @intCast(ErrorInt, mod.error_name_list.items.len);
    mod.error_name_list.appendAssumeCapacity(gop.entry.key);
    return gop.entry.*;
}

pub fn analyzeExport(
    mod: *Module,
    scope: *Scope,
    src: LazySrcLoc,
    borrowed_symbol_name: []const u8,
    exported_decl: *Decl,
) !void {
    try mod.ensureDeclAnalyzed(exported_decl);
    const typed_value = exported_decl.typed_value.most_recent.typed_value;
    switch (typed_value.ty.zigTypeTag()) {
        .Fn => {},
        else => return mod.fail(scope, src, "unable to export type '{}'", .{typed_value.ty}),
    }

    try mod.decl_exports.ensureCapacity(mod.gpa, mod.decl_exports.items().len + 1);
    try mod.export_owners.ensureCapacity(mod.gpa, mod.export_owners.items().len + 1);

    const new_export = try mod.gpa.create(Export);
    errdefer mod.gpa.destroy(new_export);

    const symbol_name = try mod.gpa.dupe(u8, borrowed_symbol_name);
    errdefer mod.gpa.free(symbol_name);

    const owner_decl = scope.ownerDecl().?;

    new_export.* = .{
        .options = .{ .name = symbol_name },
        .src = src,
        .link = switch (mod.comp.bin_file.tag) {
            .coff => .{ .coff = {} },
            .elf => .{ .elf = link.File.Elf.Export{} },
            .macho => .{ .macho = link.File.MachO.Export{} },
            .c => .{ .c = {} },
            .wasm => .{ .wasm = {} },
            .spirv => .{ .spirv = {} },
        },
        .owner_decl = owner_decl,
        .exported_decl = exported_decl,
        .status = .in_progress,
    };

    // Add to export_owners table.
    const eo_gop = mod.export_owners.getOrPutAssumeCapacity(owner_decl);
    if (!eo_gop.found_existing) {
        eo_gop.entry.value = &[0]*Export{};
    }
    eo_gop.entry.value = try mod.gpa.realloc(eo_gop.entry.value, eo_gop.entry.value.len + 1);
    eo_gop.entry.value[eo_gop.entry.value.len - 1] = new_export;
    errdefer eo_gop.entry.value = mod.gpa.shrink(eo_gop.entry.value, eo_gop.entry.value.len - 1);

    // Add to exported_decl table.
    const de_gop = mod.decl_exports.getOrPutAssumeCapacity(exported_decl);
    if (!de_gop.found_existing) {
        de_gop.entry.value = &[0]*Export{};
    }
    de_gop.entry.value = try mod.gpa.realloc(de_gop.entry.value, de_gop.entry.value.len + 1);
    de_gop.entry.value[de_gop.entry.value.len - 1] = new_export;
    errdefer de_gop.entry.value = mod.gpa.shrink(de_gop.entry.value, de_gop.entry.value.len - 1);

    if (mod.symbol_exports.get(symbol_name)) |other_export| {
        new_export.status = .failed_retryable;
        try mod.failed_exports.ensureCapacity(mod.gpa, mod.failed_exports.items().len + 1);
        const msg = try mod.errMsg(
            scope,
            src,
            "exported symbol collision: {s}",
            .{symbol_name},
        );
        errdefer msg.destroy(mod.gpa);
        try mod.errNote(
            &other_export.owner_decl.container.base,
            other_export.src,
            msg,
            "other symbol here",
            .{},
        );
        mod.failed_exports.putAssumeCapacityNoClobber(new_export, msg);
        new_export.status = .failed;
        return;
    }

    try mod.symbol_exports.putNoClobber(mod.gpa, symbol_name, new_export);
    mod.comp.bin_file.updateDeclExports(mod, exported_decl, de_gop.entry.value) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => {
            new_export.status = .failed_retryable;
            try mod.failed_exports.ensureCapacity(mod.gpa, mod.failed_exports.items().len + 1);
            const msg = try mod.errMsg(scope, src, "unable to export: {s}", .{@errorName(err)});
            mod.failed_exports.putAssumeCapacityNoClobber(new_export, msg);
        },
    };
}
pub fn constInst(mod: *Module, arena: *Allocator, src: LazySrcLoc, typed_value: TypedValue) !*ir.Inst {
    const const_inst = try arena.create(ir.Inst.Constant);
    const_inst.* = .{
        .base = .{
            .tag = ir.Inst.Constant.base_tag,
            .ty = typed_value.ty,
            .src = src,
        },
        .val = typed_value.val,
    };
    return &const_inst.base;
}

pub fn constType(mod: *Module, arena: *Allocator, src: LazySrcLoc, ty: Type) !*ir.Inst {
    return mod.constInst(arena, src, .{
        .ty = Type.initTag(.type),
        .val = try ty.toValue(arena),
    });
}

pub fn constVoid(mod: *Module, arena: *Allocator, src: LazySrcLoc) !*ir.Inst {
    return mod.constInst(arena, src, .{
        .ty = Type.initTag(.void),
        .val = Value.initTag(.void_value),
    });
}

pub fn constNoReturn(mod: *Module, arena: *Allocator, src: LazySrcLoc) !*ir.Inst {
    return mod.constInst(arena, src, .{
        .ty = Type.initTag(.noreturn),
        .val = Value.initTag(.unreachable_value),
    });
}

pub fn constUndef(mod: *Module, arena: *Allocator, src: LazySrcLoc, ty: Type) !*ir.Inst {
    return mod.constInst(arena, src, .{
        .ty = ty,
        .val = Value.initTag(.undef),
    });
}

pub fn constBool(mod: *Module, arena: *Allocator, src: LazySrcLoc, v: bool) !*ir.Inst {
    return mod.constInst(arena, src, .{
        .ty = Type.initTag(.bool),
        .val = ([2]Value{ Value.initTag(.bool_false), Value.initTag(.bool_true) })[@boolToInt(v)],
    });
}

pub fn constIntUnsigned(mod: *Module, arena: *Allocator, src: LazySrcLoc, ty: Type, int: u64) !*ir.Inst {
    return mod.constInst(arena, src, .{
        .ty = ty,
        .val = try Value.Tag.int_u64.create(arena, int),
    });
}

pub fn constIntSigned(mod: *Module, arena: *Allocator, src: LazySrcLoc, ty: Type, int: i64) !*ir.Inst {
    return mod.constInst(arena, src, .{
        .ty = ty,
        .val = try Value.Tag.int_i64.create(arena, int),
    });
}

pub fn constIntBig(mod: *Module, arena: *Allocator, src: LazySrcLoc, ty: Type, big_int: BigIntConst) !*ir.Inst {
    if (big_int.positive) {
        if (big_int.to(u64)) |x| {
            return mod.constIntUnsigned(arena, src, ty, x);
        } else |err| switch (err) {
            error.NegativeIntoUnsigned => unreachable,
            error.TargetTooSmall => {}, // handled below
        }
        return mod.constInst(arena, src, .{
            .ty = ty,
            .val = try Value.Tag.int_big_positive.create(arena, big_int.limbs),
        });
    } else {
        if (big_int.to(i64)) |x| {
            return mod.constIntSigned(arena, src, ty, x);
        } else |err| switch (err) {
            error.NegativeIntoUnsigned => unreachable,
            error.TargetTooSmall => {}, // handled below
        }
        return mod.constInst(arena, src, .{
            .ty = ty,
            .val = try Value.Tag.int_big_negative.create(arena, big_int.limbs),
        });
    }
}

pub fn createAnonymousDecl(
    mod: *Module,
    scope: *Scope,
    decl_arena: *std.heap.ArenaAllocator,
    typed_value: TypedValue,
) !*Decl {
    const name_index = mod.getNextAnonNameIndex();
    const scope_decl = scope.ownerDecl().?;
    const name = try std.fmt.allocPrint(mod.gpa, "{s}__anon_{d}", .{ scope_decl.name, name_index });
    defer mod.gpa.free(name);
    const name_hash = scope.namespace().fullyQualifiedNameHash(name);
    const src_hash: std.zig.SrcHash = undefined;
    const new_decl = try mod.createNewDecl(scope, name, scope_decl.src_node, name_hash, src_hash);
    const decl_arena_state = try decl_arena.allocator.create(std.heap.ArenaAllocator.State);

    decl_arena_state.* = decl_arena.state;
    new_decl.typed_value = .{
        .most_recent = .{
            .typed_value = typed_value,
            .arena = decl_arena_state,
        },
    };
    new_decl.analysis = .complete;
    new_decl.generation = mod.generation;

    // TODO: This generates the Decl into the machine code file if it is of a
    // type that is non-zero size. We should be able to further improve the
    // compiler to omit Decls which are only referenced at compile-time and not runtime.
    if (typed_value.ty.hasCodeGenBits()) {
        try mod.comp.bin_file.allocateDeclIndexes(new_decl);
        try mod.comp.work_queue.writeItem(.{ .codegen_decl = new_decl });
    }

    return new_decl;
}

pub fn createContainerDecl(
    mod: *Module,
    scope: *Scope,
    base_token: std.zig.ast.TokenIndex,
    decl_arena: *std.heap.ArenaAllocator,
    typed_value: TypedValue,
) !*Decl {
    const scope_decl = scope.ownerDecl().?;
    const name = try mod.getAnonTypeName(scope, base_token);
    defer mod.gpa.free(name);
    const name_hash = scope.namespace().fullyQualifiedNameHash(name);
    const src_hash: std.zig.SrcHash = undefined;
    const new_decl = try mod.createNewDecl(scope, name, scope_decl.src_node, name_hash, src_hash);
    const decl_arena_state = try decl_arena.allocator.create(std.heap.ArenaAllocator.State);

    decl_arena_state.* = decl_arena.state;
    new_decl.typed_value = .{
        .most_recent = .{
            .typed_value = typed_value,
            .arena = decl_arena_state,
        },
    };
    new_decl.analysis = .complete;
    new_decl.generation = mod.generation;

    return new_decl;
}

fn getAnonTypeName(mod: *Module, scope: *Scope, base_token: std.zig.ast.TokenIndex) ![]u8 {
    // TODO add namespaces, generic function signatrues
    const tree = scope.tree();
    const token_tags = tree.tokens.items(.tag);
    const base_name = switch (token_tags[base_token]) {
        .keyword_struct => "struct",
        .keyword_enum => "enum",
        .keyword_union => "union",
        .keyword_opaque => "opaque",
        else => unreachable,
    };
    const loc = tree.tokenLocation(0, base_token);
    return std.fmt.allocPrint(mod.gpa, "{s}:{d}:{d}", .{ base_name, loc.line, loc.column });
}

fn getNextAnonNameIndex(mod: *Module) usize {
    return @atomicRmw(usize, &mod.next_anon_name_index, .Add, 1, .Monotonic);
}

pub fn lookupDeclName(mod: *Module, scope: *Scope, ident_name: []const u8) ?*Decl {
    const namespace = scope.namespace();
    const name_hash = namespace.fullyQualifiedNameHash(ident_name);
    return mod.decl_table.get(name_hash);
}

pub fn makeIntType(arena: *Allocator, signedness: std.builtin.Signedness, bits: u16) !Type {
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

/// We don't return a pointer to the new error note because the pointer
/// becomes invalid when you add another one.
pub fn errNote(
    mod: *Module,
    scope: *Scope,
    src: LazySrcLoc,
    parent: *ErrorMsg,
    comptime format: []const u8,
    args: anytype,
) error{OutOfMemory}!void {
    return mod.errNoteNonLazy(src.toSrcLoc(scope), parent, format, args);
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

pub fn errMsg(
    mod: *Module,
    scope: *Scope,
    src: LazySrcLoc,
    comptime format: []const u8,
    args: anytype,
) error{OutOfMemory}!*ErrorMsg {
    return ErrorMsg.create(mod.gpa, src.toSrcLoc(scope), format, args);
}

pub fn fail(
    mod: *Module,
    scope: *Scope,
    src: LazySrcLoc,
    comptime format: []const u8,
    args: anytype,
) InnerError {
    const err_msg = try mod.errMsg(scope, src, format, args);
    return mod.failWithOwnedErrorMsg(scope, err_msg);
}

/// Same as `fail`, except given an absolute byte offset, and the function sets up the `LazySrcLoc`
/// for pointing at it relatively by subtracting from the containing `Decl`.
pub fn failOff(
    mod: *Module,
    scope: *Scope,
    byte_offset: u32,
    comptime format: []const u8,
    args: anytype,
) InnerError {
    const decl_byte_offset = scope.srcDecl().?.srcByteOffset();
    const src: LazySrcLoc = .{ .byte_offset = byte_offset - decl_byte_offset };
    return mod.fail(scope, src, format, args);
}

/// Same as `fail`, except given a token index, and the function sets up the `LazySrcLoc`
/// for pointing at it relatively by subtracting from the containing `Decl`.
pub fn failTok(
    mod: *Module,
    scope: *Scope,
    token_index: ast.TokenIndex,
    comptime format: []const u8,
    args: anytype,
) InnerError {
    const src = scope.srcDecl().?.tokSrcLoc(token_index);
    return mod.fail(scope, src, format, args);
}

/// Same as `fail`, except given an AST node index, and the function sets up the `LazySrcLoc`
/// for pointing at it relatively by subtracting from the containing `Decl`.
pub fn failNode(
    mod: *Module,
    scope: *Scope,
    node_index: ast.Node.Index,
    comptime format: []const u8,
    args: anytype,
) InnerError {
    const src = scope.srcDecl().?.nodeSrcLoc(node_index);
    return mod.fail(scope, src, format, args);
}

pub fn failWithOwnedErrorMsg(mod: *Module, scope: *Scope, err_msg: *ErrorMsg) InnerError {
    @setCold(true);
    {
        errdefer err_msg.destroy(mod.gpa);
        try mod.failed_decls.ensureCapacity(mod.gpa, mod.failed_decls.items().len + 1);
        try mod.failed_files.ensureCapacity(mod.gpa, mod.failed_files.items().len + 1);
    }
    switch (scope.tag) {
        .block => {
            const block = scope.cast(Scope.Block).?;
            if (block.sema.owner_func) |func| {
                func.state = .sema_failure;
            } else {
                block.sema.owner_decl.analysis = .sema_failure;
                block.sema.owner_decl.generation = mod.generation;
            }
            mod.failed_decls.putAssumeCapacityNoClobber(block.sema.owner_decl, err_msg);
        },
        .gen_zir => {
            const gen_zir = scope.cast(Scope.GenZir).?;
            gen_zir.astgen.decl.analysis = .sema_failure;
            gen_zir.astgen.decl.generation = mod.generation;
            mod.failed_decls.putAssumeCapacityNoClobber(gen_zir.astgen.decl, err_msg);
        },
        .local_val => {
            const gen_zir = scope.cast(Scope.LocalVal).?.gen_zir;
            gen_zir.astgen.decl.analysis = .sema_failure;
            gen_zir.astgen.decl.generation = mod.generation;
            mod.failed_decls.putAssumeCapacityNoClobber(gen_zir.astgen.decl, err_msg);
        },
        .local_ptr => {
            const gen_zir = scope.cast(Scope.LocalPtr).?.gen_zir;
            gen_zir.astgen.decl.analysis = .sema_failure;
            gen_zir.astgen.decl.generation = mod.generation;
            mod.failed_decls.putAssumeCapacityNoClobber(gen_zir.astgen.decl, err_msg);
        },
        .file => unreachable,
        .container => unreachable,
        .decl_ref => {
            const decl_ref = scope.cast(Scope.DeclRef).?;
            decl_ref.decl.analysis = .sema_failure;
            decl_ref.decl.generation = mod.generation;
            mod.failed_decls.putAssumeCapacityNoClobber(decl_ref.decl, err_msg);
        },
    }
    return error.AnalysisFail;
}

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

    if (result_bigint.positive) {
        return Value.Tag.int_big_positive.create(allocator, result_limbs);
    } else {
        return Value.Tag.int_big_negative.create(allocator, result_limbs);
    }
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

    if (result_bigint.positive) {
        return Value.Tag.int_big_positive.create(allocator, result_limbs);
    } else {
        return Value.Tag.int_big_negative.create(allocator, result_limbs);
    }
}

pub fn intMul(allocator: *Allocator, lhs: Value, rhs: Value) !Value {
    // TODO is this a performance issue? maybe we should try the operation without
    // resorting to BigInt first.
    var lhs_space: Value.BigIntSpace = undefined;
    var rhs_space: Value.BigIntSpace = undefined;
    const lhs_bigint = lhs.toBigInt(&lhs_space);
    const rhs_bigint = rhs.toBigInt(&rhs_space);
    const limbs = try allocator.alloc(
        std.math.big.Limb,
        lhs_bigint.limbs.len + rhs_bigint.limbs.len + 1,
    );
    var result_bigint = BigIntMutable{ .limbs = limbs, .positive = undefined, .len = undefined };
    var limbs_buffer = try allocator.alloc(
        std.math.big.Limb,
        std.math.big.int.calcMulLimbsBufferLen(lhs_bigint.limbs.len, rhs_bigint.limbs.len, 1),
    );
    defer allocator.free(limbs_buffer);
    result_bigint.mul(lhs_bigint, rhs_bigint, limbs_buffer, allocator);
    const result_limbs = result_bigint.limbs[0..result_bigint.len];

    if (result_bigint.positive) {
        return Value.Tag.int_big_positive.create(allocator, result_limbs);
    } else {
        return Value.Tag.int_big_negative.create(allocator, result_limbs);
    }
}

pub fn floatAdd(
    arena: *Allocator,
    float_type: Type,
    src: LazySrcLoc,
    lhs: Value,
    rhs: Value,
) !Value {
    switch (float_type.tag()) {
        .f16 => {
            @panic("TODO add __trunctfhf2 to compiler-rt");
            //const lhs_val = lhs.toFloat(f16);
            //const rhs_val = rhs.toFloat(f16);
            //return Value.Tag.float_16.create(arena, lhs_val + rhs_val);
        },
        .f32 => {
            const lhs_val = lhs.toFloat(f32);
            const rhs_val = rhs.toFloat(f32);
            return Value.Tag.float_32.create(arena, lhs_val + rhs_val);
        },
        .f64 => {
            const lhs_val = lhs.toFloat(f64);
            const rhs_val = rhs.toFloat(f64);
            return Value.Tag.float_64.create(arena, lhs_val + rhs_val);
        },
        .f128, .comptime_float, .c_longdouble => {
            const lhs_val = lhs.toFloat(f128);
            const rhs_val = rhs.toFloat(f128);
            return Value.Tag.float_128.create(arena, lhs_val + rhs_val);
        },
        else => unreachable,
    }
}

pub fn floatSub(
    arena: *Allocator,
    float_type: Type,
    src: LazySrcLoc,
    lhs: Value,
    rhs: Value,
) !Value {
    switch (float_type.tag()) {
        .f16 => {
            @panic("TODO add __trunctfhf2 to compiler-rt");
            //const lhs_val = lhs.toFloat(f16);
            //const rhs_val = rhs.toFloat(f16);
            //return Value.Tag.float_16.create(arena, lhs_val - rhs_val);
        },
        .f32 => {
            const lhs_val = lhs.toFloat(f32);
            const rhs_val = rhs.toFloat(f32);
            return Value.Tag.float_32.create(arena, lhs_val - rhs_val);
        },
        .f64 => {
            const lhs_val = lhs.toFloat(f64);
            const rhs_val = rhs.toFloat(f64);
            return Value.Tag.float_64.create(arena, lhs_val - rhs_val);
        },
        .f128, .comptime_float, .c_longdouble => {
            const lhs_val = lhs.toFloat(f128);
            const rhs_val = rhs.toFloat(f128);
            return Value.Tag.float_128.create(arena, lhs_val - rhs_val);
        },
        else => unreachable,
    }
}

pub fn floatMul(
    arena: *Allocator,
    float_type: Type,
    src: LazySrcLoc,
    lhs: Value,
    rhs: Value,
) !Value {
    switch (float_type.tag()) {
        .f16 => {
            @panic("TODO add __trunctfhf2 to compiler-rt");
            //const lhs_val = lhs.toFloat(f16);
            //const rhs_val = rhs.toFloat(f16);
            //return Value.Tag.float_16.create(arena, lhs_val * rhs_val);
        },
        .f32 => {
            const lhs_val = lhs.toFloat(f32);
            const rhs_val = rhs.toFloat(f32);
            return Value.Tag.float_32.create(arena, lhs_val * rhs_val);
        },
        .f64 => {
            const lhs_val = lhs.toFloat(f64);
            const rhs_val = rhs.toFloat(f64);
            return Value.Tag.float_64.create(arena, lhs_val * rhs_val);
        },
        .f128, .comptime_float, .c_longdouble => {
            const lhs_val = lhs.toFloat(f128);
            const rhs_val = rhs.toFloat(f128);
            return Value.Tag.float_128.create(arena, lhs_val * rhs_val);
        },
        else => unreachable,
    }
}

pub fn simplePtrType(
    mod: *Module,
    arena: *Allocator,
    elem_ty: Type,
    mutable: bool,
    size: std.builtin.TypeInfo.Pointer.Size,
) Allocator.Error!Type {
    if (!mutable and size == .Slice and elem_ty.eql(Type.initTag(.u8))) {
        return Type.initTag(.const_slice_u8);
    }
    // TODO stage1 type inference bug
    const T = Type.Tag;

    const type_payload = try arena.create(Type.Payload.ElemType);
    type_payload.* = .{
        .base = .{
            .tag = switch (size) {
                .One => if (mutable) T.single_mut_pointer else T.single_const_pointer,
                .Many => if (mutable) T.many_mut_pointer else T.many_const_pointer,
                .C => if (mutable) T.c_mut_pointer else T.c_const_pointer,
                .Slice => if (mutable) T.mut_slice else T.const_slice,
            },
        },
        .data = elem_ty,
    };
    return Type.initPayload(&type_payload.base);
}

pub fn ptrType(
    mod: *Module,
    arena: *Allocator,
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
    return Type.Tag.pointer.create(arena, .{
        .pointee_type = elem_ty,
        .sentinel = sentinel,
        .@"align" = @"align",
        .bit_offset = bit_offset,
        .host_size = host_size,
        .@"allowzero" = @"allowzero",
        .mutable = mutable,
        .@"volatile" = @"volatile",
        .size = size,
    });
}

pub fn optionalType(mod: *Module, arena: *Allocator, child_type: Type) Allocator.Error!Type {
    switch (child_type.tag()) {
        .single_const_pointer => return Type.Tag.optional_single_const_pointer.create(
            arena,
            child_type.elemType(),
        ),
        .single_mut_pointer => return Type.Tag.optional_single_mut_pointer.create(
            arena,
            child_type.elemType(),
        ),
        else => return Type.Tag.optional.create(arena, child_type),
    }
}

pub fn arrayType(
    mod: *Module,
    arena: *Allocator,
    len: u64,
    sentinel: ?Value,
    elem_type: Type,
) Allocator.Error!Type {
    if (elem_type.eql(Type.initTag(.u8))) {
        if (sentinel) |some| {
            if (some.eql(Value.initTag(.zero))) {
                return Type.Tag.array_u8_sentinel_0.create(arena, len);
            }
        } else {
            return Type.Tag.array_u8.create(arena, len);
        }
    }

    if (sentinel) |some| {
        return Type.Tag.array_sentinel.create(arena, .{
            .len = len,
            .sentinel = some,
            .elem_type = elem_type,
        });
    }

    return Type.Tag.array.create(arena, .{
        .len = len,
        .elem_type = elem_type,
    });
}

pub fn errorUnionType(
    mod: *Module,
    arena: *Allocator,
    error_set: Type,
    payload: Type,
) Allocator.Error!Type {
    assert(error_set.zigTypeTag() == .ErrorSet);
    if (error_set.eql(Type.initTag(.anyerror)) and payload.eql(Type.initTag(.void))) {
        return Type.initTag(.anyerror_void_error_union);
    }

    return Type.Tag.error_union.create(arena, .{
        .error_set = error_set,
        .payload = payload,
    });
}

pub fn dumpInst(mod: *Module, scope: *Scope, inst: *ir.Inst) void {
    const zir_module = scope.namespace();
    const source = zir_module.getSource(mod) catch @panic("dumpInst failed to get source");
    const loc = std.zig.findLineColumn(source, inst.src);
    if (inst.tag == .constant) {
        std.debug.print("constant ty={} val={} src={s}:{d}:{d}\n", .{
            inst.ty,
            inst.castTag(.constant).?.val,
            zir_module.subFilePath(),
            loc.line + 1,
            loc.column + 1,
        });
    } else if (inst.deaths == 0) {
        std.debug.print("{s} ty={} src={s}:{d}:{d}\n", .{
            @tagName(inst.tag),
            inst.ty,
            zir_module.subFilePath(),
            loc.line + 1,
            loc.column + 1,
        });
    } else {
        std.debug.print("{s} ty={} deaths={b} src={s}:{d}:{d}\n", .{
            @tagName(inst.tag),
            inst.ty,
            inst.deaths,
            zir_module.subFilePath(),
            loc.line + 1,
            loc.column + 1,
        });
    }
}

pub fn getTarget(mod: Module) Target {
    return mod.comp.bin_file.options.target;
}

pub fn optimizeMode(mod: Module) std.builtin.Mode {
    return mod.comp.bin_file.options.optimize_mode;
}

/// Given an identifier token, obtain the string for it.
/// If the token uses @"" syntax, parses as a string, reports errors if applicable,
/// and allocates the result within `scope.arena()`.
/// Otherwise, returns a reference to the source code bytes directly.
/// See also `appendIdentStr` and `parseStrLit`.
pub fn identifierTokenString(mod: *Module, scope: *Scope, token: ast.TokenIndex) InnerError![]const u8 {
    const tree = scope.tree();
    const token_tags = tree.tokens.items(.tag);
    assert(token_tags[token] == .identifier);
    const ident_name = tree.tokenSlice(token);
    if (!mem.startsWith(u8, ident_name, "@")) {
        return ident_name;
    }
    var buf: ArrayListUnmanaged(u8) = .{};
    defer buf.deinit(mod.gpa);
    try parseStrLit(mod, scope, token, &buf, ident_name, 1);
    const duped = try scope.arena().dupe(u8, buf.items);
    return duped;
}

/// `scope` is only used for error reporting.
/// The string is stored in `arena` regardless of whether it uses @"" syntax.
pub fn identifierTokenStringTreeArena(
    mod: *Module,
    scope: *Scope,
    token: ast.TokenIndex,
    tree: *const ast.Tree,
    arena: *Allocator,
) InnerError![]u8 {
    const token_tags = tree.tokens.items(.tag);
    assert(token_tags[token] == .identifier);
    const ident_name = tree.tokenSlice(token);
    if (!mem.startsWith(u8, ident_name, "@")) {
        return arena.dupe(u8, ident_name);
    }
    var buf: ArrayListUnmanaged(u8) = .{};
    defer buf.deinit(mod.gpa);
    try parseStrLit(mod, scope, token, &buf, ident_name, 1);
    return arena.dupe(u8, buf.items);
}

/// Given an identifier token, obtain the string for it (possibly parsing as a string
/// literal if it is @"" syntax), and append the string to `buf`.
/// See also `identifierTokenString` and `parseStrLit`.
pub fn appendIdentStr(
    mod: *Module,
    scope: *Scope,
    token: ast.TokenIndex,
    buf: *ArrayListUnmanaged(u8),
) InnerError!void {
    const tree = scope.tree();
    const token_tags = tree.tokens.items(.tag);
    assert(token_tags[token] == .identifier);
    const ident_name = tree.tokenSlice(token);
    if (!mem.startsWith(u8, ident_name, "@")) {
        return buf.appendSlice(mod.gpa, ident_name);
    } else {
        return mod.parseStrLit(scope, token, buf, ident_name, 1);
    }
}

/// Appends the result to `buf`.
pub fn parseStrLit(
    mod: *Module,
    scope: *Scope,
    token: ast.TokenIndex,
    buf: *ArrayListUnmanaged(u8),
    bytes: []const u8,
    offset: u32,
) InnerError!void {
    const tree = scope.tree();
    const token_starts = tree.tokens.items(.start);
    const raw_string = bytes[offset..];
    var buf_managed = buf.toManaged(mod.gpa);
    const result = std.zig.string_literal.parseAppend(&buf_managed, raw_string);
    buf.* = buf_managed.toUnmanaged();
    switch (try result) {
        .success => return,
        .invalid_character => |bad_index| {
            return mod.failOff(
                scope,
                token_starts[token] + offset + @intCast(u32, bad_index),
                "invalid string literal character: '{c}'",
                .{raw_string[bad_index]},
            );
        },
        .expected_hex_digits => |bad_index| {
            return mod.failOff(
                scope,
                token_starts[token] + offset + @intCast(u32, bad_index),
                "expected hex digits after '\\x'",
                .{},
            );
        },
        .invalid_hex_escape => |bad_index| {
            return mod.failOff(
                scope,
                token_starts[token] + offset + @intCast(u32, bad_index),
                "invalid hex digit: '{c}'",
                .{raw_string[bad_index]},
            );
        },
        .invalid_unicode_escape => |bad_index| {
            return mod.failOff(
                scope,
                token_starts[token] + offset + @intCast(u32, bad_index),
                "invalid unicode digit: '{c}'",
                .{raw_string[bad_index]},
            );
        },
        .missing_matching_rbrace => |bad_index| {
            return mod.failOff(
                scope,
                token_starts[token] + offset + @intCast(u32, bad_index),
                "missing matching '}}' character",
                .{},
            );
        },
        .expected_unicode_digits => |bad_index| {
            return mod.failOff(
                scope,
                token_starts[token] + offset + @intCast(u32, bad_index),
                "expected unicode digits after '\\u'",
                .{},
            );
        },
    }
}

pub fn unloadFile(mod: *Module, file_scope: *Scope.File) void {
    if (file_scope.status == .unloaded_parse_failure) {
        mod.failed_files.swapRemove(file_scope).?.value.destroy(mod.gpa);
    }
    file_scope.unload(mod.gpa);
}
