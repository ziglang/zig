const std = @import("std");
const mem = std.mem;
const Allocator = std.mem.Allocator;
const ArrayListUnmanaged = std.ArrayListUnmanaged;
const Value = @import("value.zig").Value;
const Type = @import("type.zig").Type;
const TypedValue = @import("TypedValue.zig");
const assert = std.debug.assert;
const log = std.log;
const BigIntConst = std.math.big.int.Const;
const BigIntMutable = std.math.big.int.Mutable;
const Target = std.Target;
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

/// General-purpose allocator. Used for both temporary and long-term storage.
gpa: *Allocator,
/// Pointer to externally managed resource.
root_pkg: *Package,
/// Module owns this resource.
/// The `Scope` is either a `Scope.ZIRModule` or `Scope.File`.
root_scope: *Scope,
bin_file: *link.File,
bin_file_dir: std.fs.Dir,
bin_file_path: []const u8,
/// It's rare for a decl to be exported, so we save memory by having a sparse map of
/// Decl pointers to details about them being exported.
/// The Export memory is owned by the `export_owners` table; the slice itself is owned by this table.
decl_exports: std.AutoHashMapUnmanaged(*Decl, []*Export) = .{},
/// We track which export is associated with the given symbol name for quick
/// detection of symbol collisions.
symbol_exports: std.StringHashMapUnmanaged(*Export) = .{},
/// This models the Decls that perform exports, so that `decl_exports` can be updated when a Decl
/// is modified. Note that the key of this table is not the Decl being exported, but the Decl that
/// is performing the export of another Decl.
/// This table owns the Export memory.
export_owners: std.AutoHashMapUnmanaged(*Decl, []*Export) = .{},
/// Maps fully qualified namespaced names to the Decl struct for them.
decl_table: std.HashMapUnmanaged(Scope.NameHash, *Decl, Scope.name_hash_hash, Scope.name_hash_eql, false) = .{},

link_error_flags: link.File.ErrorFlags = .{},

work_queue: std.fifo.LinearFifo(WorkItem, .Dynamic),

/// We optimize memory usage for a compilation with no compile errors by storing the
/// error messages and mapping outside of `Decl`.
/// The ErrorMsg memory is owned by the decl, using Module's allocator.
/// Note that a Decl can succeed but the Fn it represents can fail. In this case,
/// a Decl can have a failed_decls entry but have analysis status of success.
failed_decls: std.AutoHashMapUnmanaged(*Decl, *ErrorMsg) = .{},
/// Using a map here for consistency with the other fields here.
/// The ErrorMsg memory is owned by the `Scope`, using Module's allocator.
failed_files: std.AutoHashMapUnmanaged(*Scope, *ErrorMsg) = .{},
/// Using a map here for consistency with the other fields here.
/// The ErrorMsg memory is owned by the `Export`, using Module's allocator.
failed_exports: std.AutoHashMapUnmanaged(*Export, *ErrorMsg) = .{},

/// Incrementing integer used to compare against the corresponding Decl
/// field to determine whether a Decl's status applies to an ongoing update, or a
/// previous analysis.
generation: u32 = 0,

next_anon_name_index: usize = 0,

/// Candidates for deletion. After a semantic analysis update completes, this list
/// contains Decls that need to be deleted if they end up having no references to them.
deletion_set: std.ArrayListUnmanaged(*Decl) = .{},

/// Owned by Module.
root_name: []u8,
keep_source_files_loaded: bool,

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
    /// The direct parent container of the Decl. This is either a `Scope.File` or `Scope.ZIRModule`.
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

    /// The reason this is not `std.AutoHashMapUnmanaged` is a workaround for
    /// stage1 compiler giving me: `error: struct 'Module.Decl' depends on itself`
    pub const DepsTable = std.HashMapUnmanaged(*Decl, void, std.hash_map.getAutoHashFn(*Decl), std.hash_map.getAutoEqlFn(*Decl), false);

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
            .file => {
                const file = @fieldParentPtr(Scope.File, "base", self.scope);
                const tree = file.contents.tree;
                const decl_node = tree.root_node.decls()[self.src_index];
                return tree.token_locs[decl_node.firstToken()].start;
            },
            .zir_module => {
                const zir_module = @fieldParentPtr(Scope.ZIRModule, "base", self.scope);
                const module = zir_module.contents.module;
                const src_decl = module.decls[self.src_index];
                return src_decl.inst.src;
            },
            .block => unreachable,
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
        }
    }

    /// If the scope has a parent which is a `DeclAnalysis`,
    /// returns the `Decl`, otherwise returns `null`.
    pub fn decl(self: *Scope) ?*Decl {
        return switch (self.tag) {
            .block => self.cast(Block).?.decl,
            .gen_zir => self.cast(GenZIR).?.decl,
            .local_val => return self.cast(LocalVal).?.gen_zir.decl,
            .local_ptr => return self.cast(LocalPtr).?.gen_zir.decl,
            .decl => self.cast(DeclAnalysis).?.decl,
            .zir_module => null,
            .file => null,
        };
    }

    /// Asserts the scope has a parent which is a ZIRModule or File and
    /// returns it.
    pub fn namespace(self: *Scope) *Scope {
        switch (self.tag) {
            .block => return self.cast(Block).?.decl.scope,
            .gen_zir => return self.cast(GenZIR).?.decl.scope,
            .local_val => return self.cast(LocalVal).?.gen_zir.decl.scope,
            .local_ptr => return self.cast(LocalPtr).?.gen_zir.decl.scope,
            .decl => return self.cast(DeclAnalysis).?.decl.scope,
            .zir_module, .file => return self,
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
            .zir_module => return self.cast(ZIRModule).?.fullyQualifiedNameHash(name),
            .file => return self.cast(File).?.fullyQualifiedNameHash(name),
        }
    }

    /// Asserts the scope is a child of a File and has an AST tree and returns the tree.
    pub fn tree(self: *Scope) *ast.Tree {
        switch (self.tag) {
            .file => return self.cast(File).?.contents.tree,
            .zir_module => unreachable,
            .decl => return self.cast(DeclAnalysis).?.decl.scope.cast(File).?.contents.tree,
            .block => return self.cast(Block).?.decl.scope.cast(File).?.contents.tree,
            .gen_zir => return self.cast(GenZIR).?.decl.scope.cast(File).?.contents.tree,
            .local_val => return self.cast(LocalVal).?.gen_zir.decl.scope.cast(File).?.contents.tree,
            .local_ptr => return self.cast(LocalPtr).?.gen_zir.decl.scope.cast(File).?.contents.tree,
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
        };
    }

    /// Asserts the scope has a parent which is a ZIRModule or File and
    /// returns the sub_file_path field.
    pub fn subFilePath(base: *Scope) []const u8 {
        switch (base.tag) {
            .file => return @fieldParentPtr(File, "base", base).sub_file_path,
            .zir_module => return @fieldParentPtr(ZIRModule, "base", base).sub_file_path,
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
            .block => unreachable,
            .gen_zir => unreachable,
            .local_val => unreachable,
            .local_ptr => unreachable,
            .decl => unreachable,
        }
    }

    pub fn getSource(base: *Scope, module: *Module) ![:0]const u8 {
        switch (base.tag) {
            .file => return @fieldParentPtr(File, "base", base).getSource(module),
            .zir_module => return @fieldParentPtr(ZIRModule, "base", base).getSource(module),
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
            .file => return @fieldParentPtr(File, "base", base).removeDecl(child),
            .zir_module => return @fieldParentPtr(ZIRModule, "base", base).removeDecl(child),
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
            .block => unreachable,
            .gen_zir => unreachable,
            .local_val => unreachable,
            .local_ptr => unreachable,
            .decl => unreachable,
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
        block,
        decl,
        gen_zir,
        local_val,
        local_ptr,
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

        /// Direct children of the file.
        decls: ArrayListUnmanaged(*Decl),

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
            self.decls.deinit(gpa);
            self.unload(gpa);
            self.* = undefined;
        }

        pub fn removeDecl(self: *File, child: *Decl) void {
            for (self.decls.items) |item, i| {
                if (item == child) {
                    _ = self.decls.swapRemove(i);
                    return;
                }
            }
        }

        pub fn dumpSrc(self: *File, src: usize) void {
            const loc = std.zig.findLineColumn(self.source.bytes, src);
            std.debug.print("{}:{}:{}\n", .{ self.sub_file_path, loc.line + 1, loc.column + 1 });
        }

        pub fn getSource(self: *File, module: *Module) ![:0]const u8 {
            switch (self.source) {
                .unloaded => {
                    const source = try module.root_pkg.root_src_dir.readFileAllocOptions(
                        module.gpa,
                        self.sub_file_path,
                        std.math.maxInt(u32),
                        1,
                        0,
                    );
                    self.source = .{ .bytes = source };
                    return source;
                },
                .bytes => |bytes| return bytes,
            }
        }

        pub fn fullyQualifiedNameHash(self: *File, name: []const u8) NameHash {
            // We don't have struct scopes yet so this is currently just a simple name hash.
            return std.zig.hashSrc(name);
        }
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
                    const source = try module.root_pkg.root_src_dir.readFileAllocOptions(
                        module.gpa,
                        self.sub_file_path,
                        std.math.maxInt(u32),
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
    target: std.Target,
    root_name: []const u8,
    root_pkg: *Package,
    output_mode: std.builtin.OutputMode,
    bin_file_dir: ?std.fs.Dir = null,
    bin_file_path: []const u8,
    link_mode: ?std.builtin.LinkMode = null,
    object_format: ?std.builtin.ObjectFormat = null,
    optimize_mode: std.builtin.Mode = .Debug,
    keep_source_files_loaded: bool = false,
};

pub fn init(gpa: *Allocator, options: InitOptions) !Module {
    const root_name = try gpa.dupe(u8, options.root_name);
    errdefer gpa.free(root_name);

    const bin_file_dir = options.bin_file_dir orelse std.fs.cwd();
    const bin_file = try link.File.openPath(gpa, bin_file_dir, options.bin_file_path, .{
        .root_name = root_name,
        .root_pkg = options.root_pkg,
        .target = options.target,
        .output_mode = options.output_mode,
        .link_mode = options.link_mode orelse .Static,
        .object_format = options.object_format orelse options.target.getObjectFormat(),
        .optimize_mode = options.optimize_mode,
    });
    errdefer bin_file.destroy();

    const root_scope = blk: {
        if (mem.endsWith(u8, options.root_pkg.root_src_path, ".zig")) {
            const root_scope = try gpa.create(Scope.File);
            root_scope.* = .{
                .sub_file_path = options.root_pkg.root_src_path,
                .source = .{ .unloaded = {} },
                .contents = .{ .not_available = {} },
                .status = .never_loaded,
                .decls = .{},
            };
            break :blk &root_scope.base;
        } else if (mem.endsWith(u8, options.root_pkg.root_src_path, ".zir")) {
            const root_scope = try gpa.create(Scope.ZIRModule);
            root_scope.* = .{
                .sub_file_path = options.root_pkg.root_src_path,
                .source = .{ .unloaded = {} },
                .contents = .{ .not_available = {} },
                .status = .never_loaded,
                .decls = .{},
            };
            break :blk &root_scope.base;
        } else {
            unreachable;
        }
    };

    return Module{
        .gpa = gpa,
        .root_name = root_name,
        .root_pkg = options.root_pkg,
        .root_scope = root_scope,
        .bin_file_dir = bin_file_dir,
        .bin_file_path = options.bin_file_path,
        .bin_file = bin_file,
        .work_queue = std.fifo.LinearFifo(WorkItem, .Dynamic).init(gpa),
        .keep_source_files_loaded = options.keep_source_files_loaded,
    };
}

pub fn deinit(self: *Module) void {
    self.bin_file.destroy();
    const gpa = self.gpa;
    self.gpa.free(self.root_name);
    self.deletion_set.deinit(gpa);
    self.work_queue.deinit();

    for (self.decl_table.items()) |entry| {
        entry.value.destroy(gpa);
    }
    self.decl_table.deinit(gpa);

    for (self.failed_decls.items()) |entry| {
        entry.value.destroy(gpa);
    }
    self.failed_decls.deinit(gpa);

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
    self.* = undefined;
}

fn freeExportList(gpa: *Allocator, export_list: []*Export) void {
    for (export_list) |exp| {
        gpa.free(exp.options.name);
        gpa.destroy(exp);
    }
    gpa.free(export_list);
}

pub fn target(self: Module) std.Target {
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

    // TODO Use the cache hash file system to detect which source files changed.
    // Until then we simulate a full cache miss. Source files could have been loaded for any reason;
    // to force a refresh we unload now.
    if (self.root_scope.cast(Scope.File)) |zig_file| {
        zig_file.unload(self.gpa);
        self.analyzeRootSrcFile(zig_file) catch |err| switch (err) {
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
    try self.bin_file.flush();

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
    return self.bin_file.makeWritable(self.bin_file_dir, self.bin_file_path);
}

pub fn totalErrorCount(self: *Module) usize {
    const total = self.failed_decls.items().len +
        self.failed_files.items().len +
        self.failed_exports.items().len;
    return if (total == 0) @boolToInt(self.link_error_flags.no_entry_point_found) else total;
}

pub fn getAllErrorsAlloc(self: *Module) !AllErrors {
    var arena = std.heap.ArenaAllocator.init(self.gpa);
    errdefer arena.deinit();

    var errors = std.ArrayList(AllErrors.Message).init(self.gpa);
    defer errors.deinit();

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
        try errors.append(.{
            .src_path = self.root_pkg.root_src_path,
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
                    std.log.debug(.module, "analyze liveness of {}\n", .{decl.name});
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
    };
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
            log.debug(.module, "re-analyzing {}\n", .{decl.name});

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

    const file_scope = decl.scope.cast(Scope.File).?;
    const tree = try self.getAstTree(file_scope);
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

            const body_node = fn_proto.getTrailer("body_node") orelse
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
            if (fn_proto.getTrailer("var_args_token")) |var_args_token| {
                return self.failTok(&fn_type_scope.base, var_args_token, "TODO implement var args", .{});
            }
            if (fn_proto.getTrailer("lib_name")) |lib_name| {
                return self.failNode(&fn_type_scope.base, lib_name, "TODO implement function library name", .{});
            }
            if (fn_proto.getTrailer("align_expr")) |align_expr| {
                return self.failNode(&fn_type_scope.base, align_expr, "TODO implement function align expression", .{});
            }
            if (fn_proto.getTrailer("section_expr")) |sect_expr| {
                return self.failNode(&fn_type_scope.base, sect_expr, "TODO implement function section expression", .{});
            }
            if (fn_proto.getTrailer("callconv_expr")) |callconv_expr| {
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
            _ = try astgen.addZIRUnOp(self, &fn_type_scope.base, fn_src, .@"return", fn_type_inst);

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
            };
            defer block_scope.instructions.deinit(self.gpa);

            const fn_type = try zir_sema.analyzeBodyValueAsType(self, &block_scope, .{
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

            if (fn_proto.getTrailer("extern_export_inline_token")) |maybe_export_token| {
                if (tree.token_ids[maybe_export_token] == .Keyword_export) {
                    const export_src = tree.token_locs[maybe_export_token].start;
                    const name_loc = tree.token_locs[fn_proto.getTrailer("name_token").?];
                    const name = tree.tokenSliceLoc(name_loc);
                    // The scope needs to have the decl in it.
                    try self.analyzeExport(&block_scope.base, export_src, name, decl);
                }
            }
            return type_changed;
        },
        .VarDecl => @panic("TODO var decl"),
        .Comptime => @panic("TODO comptime decl"),
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

fn getAstTree(self: *Module, root_scope: *Scope.File) !*ast.Tree {
    const tracy = trace(@src());
    defer tracy.end();

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

fn analyzeRootSrcFile(self: *Module, root_scope: *Scope.File) !void {
    const tracy = trace(@src());
    defer tracy.end();

    // We may be analyzing it for the first time, or this may be
    // an incremental update. This code handles both cases.
    const tree = try self.getAstTree(root_scope);
    const decls = tree.root_node.decls();

    try self.work_queue.ensureUnusedCapacity(decls.len);
    try root_scope.decls.ensureCapacity(self.gpa, decls.len);

    // Keep track of the decls that we expect to see in this file so that
    // we know which ones have been deleted.
    var deleted_decls = std.AutoHashMap(*Decl, void).init(self.gpa);
    defer deleted_decls.deinit();
    try deleted_decls.ensureCapacity(root_scope.decls.items.len);
    for (root_scope.decls.items) |file_decl| {
        deleted_decls.putAssumeCapacityNoClobber(file_decl, {});
    }

    for (decls) |src_decl, decl_i| {
        if (src_decl.cast(ast.Node.FnProto)) |fn_proto| {
            // We will create a Decl for it regardless of analysis status.
            const name_tok = fn_proto.getTrailer("name_token") orelse {
                @panic("TODO missing function name");
            };

            const name_loc = tree.token_locs[name_tok];
            const name = tree.tokenSliceLoc(name_loc);
            const name_hash = root_scope.fullyQualifiedNameHash(name);
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
                        .elf => if (decl.fn_link.elf.len != 0) {
                            // TODO Look into detecting when this would be unnecessary by storing enough state
                            // in `Decl` to notice that the line number did not change.
                            self.work_queue.writeItemAssumeCapacity(.{ .update_line_number = decl });
                        },
                        .c => {},
                    }
                }
            } else {
                const new_decl = try self.createNewDecl(&root_scope.base, name, decl_i, name_hash, contents_hash);
                root_scope.decls.appendAssumeCapacity(new_decl);
                if (fn_proto.getTrailer("extern_export_inline_token")) |maybe_export_token| {
                    if (tree.token_ids[maybe_export_token] == .Keyword_export) {
                        self.work_queue.writeItemAssumeCapacity(.{ .analyze_decl = new_decl });
                    }
                }
            }
        }
        // TODO also look for global variable declarations
        // TODO also look for comptime blocks and exported globals
    }
    // Handle explicitly deleted decls from the source code. Not to be confused
    // with when we delete decls because they are no longer referenced.
    for (deleted_decls.items()) |entry| {
        log.debug(.module, "noticed '{}' deleted from source\n", .{entry.key.name});
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
    var deleted_decls = std.AutoHashMap(*Decl, void).init(self.gpa);
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
        log.debug(.module, "noticed '{}' deleted from source\n", .{entry.key.name});
        try self.deleteDecl(entry.key);
    }
}

fn deleteDecl(self: *Module, decl: *Decl) !void {
    try self.deletion_set.ensureCapacity(self.gpa, self.deletion_set.items.len + decl.dependencies.items().len);

    // Remove from the namespace it resides in. In the case of an anonymous Decl it will
    // not be present in the set, and this does nothing.
    decl.scope.removeDecl(decl);

    log.debug(.module, "deleting decl '{}'\n", .{decl.name});
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
    };
    defer inner_block.instructions.deinit(self.gpa);

    const fn_zir = func.analysis.queued;
    defer fn_zir.arena.promote(self.gpa).deinit();
    func.analysis = .{ .in_progress = {} };
    log.debug(.module, "set {} to in_progress\n", .{decl.name});

    try zir_sema.analyzeBody(self, &inner_block.base, fn_zir.body);

    const instructions = try arena.allocator.dupe(*Inst, inner_block.instructions.items);
    func.analysis = .{ .success = .{ .instructions = instructions } };
    log.debug(.module, "set {} to success\n", .{decl.name});
}

fn markOutdatedDecl(self: *Module, decl: *Decl) !void {
    log.debug(.module, "mark {} outdated\n", .{decl.name});
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
            .elf => .{ .elf = link.File.Elf.TextBlock.empty },
            .c => .{ .c = {} },
        },
        .fn_link = switch (self.bin_file.tag) {
            .elf => .{ .elf = link.File.Elf.SrcFn.empty },
            .c => .{ .c = {} },
        },
        .generation = 0,
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

/// TODO split this into `requireRuntimeBlock` and `requireFunctionBlock` and audit callsites.
pub fn requireRuntimeBlock(self: *Module, scope: *Scope, src: usize) !*Scope.Block {
    return scope.cast(Scope.Block) orelse
        return self.fail(scope, src, "instruction illegal outside function body", .{});
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
    const ty_payload = try scope.arena().create(Type.Payload.SingleConstPointer);
    ty_payload.* = .{ .pointee_type = decl_tv.ty };
    const val_payload = try scope.arena().create(Value.Payload.DeclRef);
    val_payload.* = .{ .decl = decl };

    return self.constInst(scope, src, .{
        .ty = Type.initPayload(&ty_payload.base),
        .val = Value.initPayload(&val_payload.base),
    });
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
    return self.fail(scope, src, "TODO implement analysis of isnull and isnotnull", .{});
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
            if (lhs.ty.floatBits(self.target()) >= rhs.ty.floatBits(self.target())) {
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
        const int_info = lhs.ty.intInfo(self.target());
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
        const int_info = rhs.ty.intInfo(self.target());
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
        if (prev_inst.ty.isInt() and
            next_inst.ty.isInt() and
            prev_inst.ty.isSignedInt() == next_inst.ty.isSignedInt())
        {
            if (prev_inst.ty.intInfo(self.target()).bits < next_inst.ty.intInfo(self.target()).bits) {
                prev_inst = next_inst;
            }
            continue;
        }
        if (prev_inst.ty.isFloat() and next_inst.ty.isFloat()) {
            if (prev_inst.ty.floatBits(self.target()) < next_inst.ty.floatBits(self.target())) {
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
        const child_type = dest_type.elemType();
        if (inst.value()) |val| {
            if (child_type.eql(inst.ty)) {
                return self.constInst(scope, inst.src, .{ .ty = dest_type, .val = val });
            }
            return self.fail(scope, inst.src, "TODO optional wrap {} to {}", .{ val, dest_type });
        } else if (child_type.eql(inst.ty)) {
            return self.fail(scope, inst.src, "TODO optional wrap {}", .{dest_type});
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
    if (inst.value()) |val| {
        const src_zig_tag = inst.ty.zigTypeTag();
        const dst_zig_tag = dest_type.zigTypeTag();

        if (dst_zig_tag == .ComptimeInt or dst_zig_tag == .Int) {
            if (src_zig_tag == .Float or src_zig_tag == .ComptimeFloat) {
                if (val.floatHasFraction()) {
                    return self.fail(scope, inst.src, "fractional component prevents float value {} from being casted to type '{}'", .{ val, inst.ty });
                }
                return self.fail(scope, inst.src, "TODO float to int", .{});
            } else if (src_zig_tag == .Int or src_zig_tag == .ComptimeInt) {
                if (!val.intFitsInType(dest_type, self.target())) {
                    return self.fail(scope, inst.src, "type {} cannot represent integer value {}", .{ inst.ty, val });
                }
                return self.constInst(scope, inst.src, .{ .ty = dest_type, .val = val });
            }
        } else if (dst_zig_tag == .ComptimeFloat or dst_zig_tag == .Float) {
            if (src_zig_tag == .Float or src_zig_tag == .ComptimeFloat) {
                const res = val.floatCast(scope.arena(), dest_type, self.target()) catch |err| switch (err) {
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
    }

    // integer widening
    if (inst.ty.zigTypeTag() == .Int and dest_type.zigTypeTag() == .Int) {
        assert(inst.value() == null); // handled above

        const src_info = inst.ty.intInfo(self.target());
        const dst_info = dest_type.intInfo(self.target());
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

        const src_bits = inst.ty.floatBits(self.target());
        const dst_bits = dest_type.floatBits(self.target());
        if (dst_bits >= src_bits) {
            const b = try self.requireRuntimeBlock(scope, inst.src);
            return self.addUnOp(b, inst.src, dest_type, .floatcast, inst);
        }
    }

    return self.fail(scope, inst.src, "expected {}, found {}", .{ dest_type, inst.ty });
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
        .file => unreachable,
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
        else => float_type.floatBits(self.target()),
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
        else => float_type.floatBits(self.target()),
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

pub fn singleMutPtrType(self: *Module, scope: *Scope, src: usize, elem_ty: Type) error{OutOfMemory}!Type {
    const type_payload = try scope.arena().create(Type.Payload.SingleMutPointer);
    type_payload.* = .{ .pointee_type = elem_ty };
    return Type.initPayload(&type_payload.base);
}

pub fn singleConstPtrType(self: *Module, scope: *Scope, src: usize, elem_ty: Type) error{OutOfMemory}!Type {
    const type_payload = try scope.arena().create(Type.Payload.SingleConstPointer);
    type_payload.* = .{ .pointee_type = elem_ty };
    return Type.initPayload(&type_payload.base);
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
