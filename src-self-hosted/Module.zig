const std = @import("std");
const mem = std.mem;
const Allocator = std.mem.Allocator;
const ArrayListUnmanaged = std.ArrayListUnmanaged;
const Value = @import("value.zig").Value;
const Type = @import("type.zig").Type;
const TypedValue = @import("TypedValue.zig");
const assert = std.debug.assert;
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

optimize_mode: std.builtin.Mode,
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

keep_source_files_loaded: bool,

pub const InnerError = error{ OutOfMemory, AnalysisFail };

const WorkItem = union(enum) {
    /// Write the machine code for a Decl to the output file.
    codegen_decl: *Decl,
    /// The Decl needs to be analyzed and possibly export itself.
    /// It may have already be analyzed, or it may have been determined
    /// to be outdated; in this case perform semantic analysis again.
    analyze_decl: *Decl,
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
    link: link.File.Elf.TextBlock = link.File.Elf.TextBlock.empty,

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
            .local_var => unreachable,
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
        std.debug.warn("{}:{}:{} name={} status={}", .{
            self.scope.sub_file_path,
            loc.line + 1,
            loc.column + 1,
            mem.spanZ(self.name),
            @tagName(self.analysis),
        });
        if (self.typedValueManaged()) |tvm| {
            std.debug.warn(" ty={} val={}", .{ tvm.typed_value.ty, tvm.typed_value.val });
        }
        std.debug.warn("\n", .{});
    }

    fn typedValueManaged(self: *Decl) ?*TypedValue.Managed {
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
            .local_var => return self.cast(LocalVar).?.gen_zir.arena,
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
            .local_var => return self.cast(LocalVar).?.gen_zir.decl,
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
            .local_var => return self.cast(LocalVar).?.gen_zir.decl.scope,
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
            .local_var => unreachable,
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
            .local_var => return self.cast(LocalVar).?.gen_zir.decl.scope.cast(File).?.contents.tree,
        }
    }

    /// Asserts the scope is a child of a `GenZIR` and returns it.
    pub fn getGenZIR(self: *Scope) *GenZIR {
        return switch (self.tag) {
            .block => unreachable,
            .gen_zir => self.cast(GenZIR).?,
            .local_var => return self.cast(LocalVar).?.gen_zir,
            .decl => unreachable,
            .zir_module => unreachable,
            .file => unreachable,
        };
    }

    pub fn dumpInst(self: *Scope, inst: *Inst) void {
        const zir_module = self.namespace();
        const loc = std.zig.findLineColumn(zir_module.source.bytes, inst.src);
        std.debug.warn("{}:{}:{}: {}: ty={}\n", .{
            zir_module.sub_file_path,
            loc.line + 1,
            loc.column + 1,
            @tagName(inst.tag),
            inst.ty,
        });
    }

    /// Asserts the scope has a parent which is a ZIRModule or File and
    /// returns the sub_file_path field.
    pub fn subFilePath(base: *Scope) []const u8 {
        switch (base.tag) {
            .file => return @fieldParentPtr(File, "base", base).sub_file_path,
            .zir_module => return @fieldParentPtr(ZIRModule, "base", base).sub_file_path,
            .block => unreachable,
            .gen_zir => unreachable,
            .local_var => unreachable,
            .decl => unreachable,
        }
    }

    pub fn unload(base: *Scope, gpa: *Allocator) void {
        switch (base.tag) {
            .file => return @fieldParentPtr(File, "base", base).unload(gpa),
            .zir_module => return @fieldParentPtr(ZIRModule, "base", base).unload(gpa),
            .block => unreachable,
            .gen_zir => unreachable,
            .local_var => unreachable,
            .decl => unreachable,
        }
    }

    pub fn getSource(base: *Scope, module: *Module) ![:0]const u8 {
        switch (base.tag) {
            .file => return @fieldParentPtr(File, "base", base).getSource(module),
            .zir_module => return @fieldParentPtr(ZIRModule, "base", base).getSource(module),
            .gen_zir => unreachable,
            .local_var => unreachable,
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
            .local_var => unreachable,
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
            .local_var => unreachable,
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
        local_var,
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
            std.debug.warn("{}:{}:{}\n", .{ self.sub_file_path, loc.line + 1, loc.column + 1 });
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
            std.debug.warn("{}:{}:{}\n", .{ self.sub_file_path, loc.line + 1, loc.column + 1 });
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
    };

    /// This structure lives as long as the AST generation of the Block
    /// node that contains the variable.
    pub const LocalVar = struct {
        pub const base_tag: Tag = .local_var;
        base: Scope = Scope{ .tag = base_tag },
        /// Parents can be: `LocalVar`, `GenZIR`.
        parent: *Scope,
        gen_zir: *GenZIR,
        name: []const u8,
        inst: *zir.Inst,
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
    const bin_file_dir = options.bin_file_dir orelse std.fs.cwd();
    const bin_file = try link.openBinFilePath(gpa, bin_file_dir, options.bin_file_path, .{
        .target = options.target,
        .output_mode = options.output_mode,
        .link_mode = options.link_mode orelse .Static,
        .object_format = options.object_format orelse options.target.getObjectFormat(),
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
        .root_pkg = options.root_pkg,
        .root_scope = root_scope,
        .bin_file_dir = bin_file_dir,
        .bin_file_path = options.bin_file_path,
        .bin_file = bin_file,
        .optimize_mode = options.optimize_mode,
        .work_queue = std.fifo.LinearFifo(WorkItem, .Dynamic).init(gpa),
        .keep_source_files_loaded = options.keep_source_files_loaded,
    };
}

pub fn deinit(self: *Module) void {
    self.bin_file.destroy();
    const gpa = self.gpa;
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
        gpa.destroy(exp);
    }
    gpa.free(export_list);
}

pub fn target(self: Module) std.Target {
    return self.bin_file.options().target;
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

    if (self.totalErrorCount() == 0) {
        // This is needed before reading the error flags.
        try self.bin_file.flush();
    }

    self.link_error_flags = self.bin_file.errorFlags();
    std.log.debug(.module, "link_error_flags: {}\n", .{self.link_error_flags});

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
                    error.CGenFailure => {
                        // Error is handled by CBE, don't try adding it again
                    },
                    else => {
                        try self.failed_decls.ensureCapacity(self.gpa, self.failed_decls.items().len + 1);
                        const result = self.failed_decls.getOrPutAssumeCapacity(decl);
                        if (result.found_existing) {
                            std.debug.panic("Internal error: attempted to override error '{}' with 'unable to codegen: {}'", .{ result.entry.value.msg, @errorName(err) });
                        } else {
                            result.entry.value = try ErrorMsg.create(
                                self.gpa,
                                decl.src(),
                                "unable to codegen: {}",
                                .{@errorName(err)},
                            );
                        }
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
    };
}

fn ensureDeclAnalyzed(self: *Module, decl: *Decl) InnerError!void {
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

        .complete, .outdated => blk: {
            if (decl.generation == self.generation) {
                assert(decl.analysis == .complete);
                return;
            }
            //std.debug.warn("re-analyzing {}\n", .{decl.name});

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
        try self.analyzeZirDecl(decl, zir_module.contents.module.decls[decl.src_index])
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
            for (param_decls) |param_decl, i| {
                const param_type_node = switch (param_decl.param_type) {
                    .any_type => |node| return self.failNode(&fn_type_scope.base, node, "TODO implement anytype parameter", .{}),
                    .type_expr => |node| node,
                };
                param_types[i] = try astgen.expr(self, &fn_type_scope.base, param_type_node);
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

            const return_type_inst = try astgen.expr(self, &fn_type_scope.base, return_type_expr);
            const fn_src = tree.token_locs[fn_proto.fn_token].start;
            const fn_type_inst = try self.addZIRInst(&fn_type_scope.base, fn_src, zir.Inst.FnType, .{
                .return_type = return_type_inst,
                .param_types = param_types,
            }, .{});
            _ = try self.addZIRUnOp(&fn_type_scope.base, fn_src, .@"return", fn_type_inst);

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

            const fn_type = try self.analyzeBodyValueAsType(&block_scope, .{
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
                    const param_name = tree.tokenSlice(name_token);
                    const arg = try gen_scope_arena.allocator.create(zir.Inst.NoOp);
                    arg.* = .{
                        .base = .{
                            .tag = .arg,
                            .src = src,
                        },
                        .positionals = .{},
                        .kw_args = .{},
                    };
                    gen_scope.instructions.items[i] = &arg.base;
                    const sub_scope = try gen_scope_arena.allocator.create(Scope.LocalVar);
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

                if (!fn_type.fnReturnType().isNoReturn() and (gen_scope.instructions.items.len == 0 or
                    !gen_scope.instructions.items[gen_scope.instructions.items.len - 1].tag.isNoReturn()))
                {
                    const src = tree.token_locs[body_block.rbrace].start;
                    _ = try self.addZIRNoOp(&gen_scope.base, src, .returnvoid);
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

fn analyzeBodyValueAsType(self: *Module, block_scope: *Scope.Block, body: zir.Module.Body) !Type {
    try self.analyzeBody(&block_scope.base, body);
    for (block_scope.instructions.items) |inst| {
        if (inst.castTag(.ret)) |ret| {
            const val = try self.resolveConstValue(&block_scope.base, ret.operand);
            return val.toType();
        } else {
            return self.fail(&block_scope.base, inst.src, "unable to resolve comptime value", .{});
        }
    }
    unreachable;
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
        //std.debug.warn("noticed '{}' deleted from source\n", .{entry.key.name});
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
            //std.debug.warn("'{}' contents: '{}'\n", .{ src_decl.name, src_decl.contents });
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
        _ = try self.resolveZirDecl(&root_scope.base, export_decl);
    }
    // Handle explicitly deleted decls from the source code. Not to be confused
    // with when we delete decls because they are no longer referenced.
    for (deleted_decls.items()) |entry| {
        //std.debug.warn("noticed '{}' deleted from source\n", .{entry.key.name});
        try self.deleteDecl(entry.key);
    }
}

fn deleteDecl(self: *Module, decl: *Decl) !void {
    try self.deletion_set.ensureCapacity(self.gpa, self.deletion_set.items.len + decl.dependencies.items().len);

    // Remove from the namespace it resides in. In the case of an anonymous Decl it will
    // not be present in the set, and this does nothing.
    decl.scope.removeDecl(decl);

    //std.debug.warn("deleting decl '{}'\n", .{decl.name});
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
    //std.debug.warn("set {} to in_progress\n", .{decl.name});

    try self.analyzeBody(&inner_block.base, fn_zir.body);

    const instructions = try arena.allocator.dupe(*Inst, inner_block.instructions.items);
    func.analysis = .{ .success = .{ .instructions = instructions } };
    //std.debug.warn("set {} to success\n", .{decl.name});
}

fn markOutdatedDecl(self: *Module, decl: *Decl) !void {
    //std.debug.warn("mark {} outdated\n", .{decl.name});
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
        .link = link.File.Elf.TextBlock.empty,
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

fn analyzeZirDecl(self: *Module, decl: *Decl, src_decl: *zir.Decl) InnerError!bool {
    var decl_scope: Scope.DeclAnalysis = .{
        .decl = decl,
        .arena = std.heap.ArenaAllocator.init(self.gpa),
    };
    errdefer decl_scope.arena.deinit();

    decl.analysis = .in_progress;

    const typed_value = try self.analyzeConstInst(&decl_scope.base, src_decl.inst);
    const arena_state = try decl_scope.arena.allocator.create(std.heap.ArenaAllocator.State);

    var prev_type_has_bits = false;
    var type_changed = true;

    if (decl.typedValueManaged()) |tvm| {
        prev_type_has_bits = tvm.typed_value.ty.hasCodeGenBits();
        type_changed = !tvm.typed_value.ty.eql(typed_value.ty);

        tvm.deinit(self.gpa);
    }

    arena_state.* = decl_scope.arena.state;
    decl.typed_value = .{
        .most_recent = .{
            .typed_value = typed_value,
            .arena = arena_state,
        },
    };
    decl.analysis = .complete;
    decl.generation = self.generation;
    if (typed_value.ty.hasCodeGenBits()) {
        // We don't fully codegen the decl until later, but we do need to reserve a global
        // offset table index for it. This allows us to codegen decls out of dependency order,
        // increasing how many computations can be done in parallel.
        try self.bin_file.allocateDeclIndexes(decl);
        try self.work_queue.writeItem(.{ .codegen_decl = decl });
    } else if (prev_type_has_bits) {
        self.bin_file.freeDecl(decl);
    }

    return type_changed;
}

fn resolveZirDecl(self: *Module, scope: *Scope, src_decl: *zir.Decl) InnerError!*Decl {
    const zir_module = self.root_scope.cast(Scope.ZIRModule).?;
    const entry = zir_module.contents.module.findDecl(src_decl.name).?;
    return self.resolveZirDeclHavingIndex(scope, src_decl, entry.index);
}

fn resolveZirDeclHavingIndex(self: *Module, scope: *Scope, src_decl: *zir.Decl, src_index: usize) InnerError!*Decl {
    const name_hash = scope.namespace().fullyQualifiedNameHash(src_decl.name);
    const decl = self.decl_table.get(name_hash).?;
    decl.src_index = src_index;
    try self.ensureDeclAnalyzed(decl);
    return decl;
}

/// Declares a dependency on the decl.
fn resolveCompleteZirDecl(self: *Module, scope: *Scope, src_decl: *zir.Decl) InnerError!*Decl {
    const decl = try self.resolveZirDecl(scope, src_decl);
    switch (decl.analysis) {
        .unreferenced => unreachable,
        .in_progress => unreachable,
        .outdated => unreachable,

        .dependency_failure,
        .sema_failure,
        .sema_failure_retryable,
        .codegen_failure,
        .codegen_failure_retryable,
        => return error.AnalysisFail,

        .complete => {},
    }
    return decl;
}

/// TODO Look into removing this function. The body is only needed for .zir files, not .zig files.
fn resolveInst(self: *Module, scope: *Scope, old_inst: *zir.Inst) InnerError!*Inst {
    if (old_inst.analyzed_inst) |inst| return inst;

    // If this assert trips, the instruction that was referenced did not get properly
    // analyzed before it was referenced.
    const zir_module = scope.namespace().cast(Scope.ZIRModule).?;
    const entry = if (old_inst.cast(zir.Inst.DeclVal)) |declval| blk: {
        const decl_name = declval.positionals.name;
        const entry = zir_module.contents.module.findDecl(decl_name) orelse
            return self.fail(scope, old_inst.src, "decl '{}' not found", .{decl_name});
        break :blk entry;
    } else blk: {
        // If this assert trips, the instruction that was referenced did not get
        // properly analyzed by a previous instruction analysis before it was
        // referenced by the current one.
        break :blk zir_module.contents.module.findInstDecl(old_inst).?;
    };
    const decl = try self.resolveCompleteZirDecl(scope, entry.decl);
    const decl_ref = try self.analyzeDeclRef(scope, old_inst.src, decl);
    // Note: it would be tempting here to store the result into old_inst.analyzed_inst field,
    // but this would prevent the analyzeDeclRef from happening, which is needed to properly
    // detect Decl dependencies and dependency failures on updates.
    return self.analyzeDeref(scope, old_inst.src, decl_ref, old_inst.src);
}

fn requireRuntimeBlock(self: *Module, scope: *Scope, src: usize) !*Scope.Block {
    return scope.cast(Scope.Block) orelse
        return self.fail(scope, src, "instruction illegal outside function body", .{});
}

fn resolveInstConst(self: *Module, scope: *Scope, old_inst: *zir.Inst) InnerError!TypedValue {
    const new_inst = try self.resolveInst(scope, old_inst);
    const val = try self.resolveConstValue(scope, new_inst);
    return TypedValue{
        .ty = new_inst.ty,
        .val = val,
    };
}

fn resolveConstValue(self: *Module, scope: *Scope, base: *Inst) !Value {
    return (try self.resolveDefinedValue(scope, base)) orelse
        return self.fail(scope, base.src, "unable to resolve comptime value", .{});
}

fn resolveDefinedValue(self: *Module, scope: *Scope, base: *Inst) !?Value {
    if (base.value()) |val| {
        if (val.isUndef()) {
            return self.fail(scope, base.src, "use of undefined value here causes undefined behavior", .{});
        }
        return val;
    }
    return null;
}

fn resolveConstString(self: *Module, scope: *Scope, old_inst: *zir.Inst) ![]u8 {
    const new_inst = try self.resolveInst(scope, old_inst);
    const wanted_type = Type.initTag(.const_slice_u8);
    const coerced_inst = try self.coerce(scope, wanted_type, new_inst);
    const val = try self.resolveConstValue(scope, coerced_inst);
    return val.toAllocatedBytes(scope.arena());
}

fn resolveType(self: *Module, scope: *Scope, old_inst: *zir.Inst) !Type {
    const new_inst = try self.resolveInst(scope, old_inst);
    const wanted_type = Type.initTag(.@"type");
    const coerced_inst = try self.coerce(scope, wanted_type, new_inst);
    const val = try self.resolveConstValue(scope, coerced_inst);
    return val.toType();
}

fn analyzeExport(self: *Module, scope: *Scope, src: usize, symbol_name: []const u8, exported_decl: *Decl) !void {
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
    const eo_gop = self.export_owners.getOrPut(self.gpa, owner_decl) catch unreachable;
    if (!eo_gop.found_existing) {
        eo_gop.entry.value = &[0]*Export{};
    }
    eo_gop.entry.value = try self.gpa.realloc(eo_gop.entry.value, eo_gop.entry.value.len + 1);
    eo_gop.entry.value[eo_gop.entry.value.len - 1] = new_export;
    errdefer eo_gop.entry.value = self.gpa.shrink(eo_gop.entry.value, eo_gop.entry.value.len - 1);

    // Add to exported_decl table.
    const de_gop = self.decl_exports.getOrPut(self.gpa, exported_decl) catch unreachable;
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

fn addNoOp(
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

fn addUnOp(
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

fn addBinOp(
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

fn addBr(
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

fn addCondBr(
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

fn addCall(
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

pub fn addZIRInstSpecial(
    self: *Module,
    scope: *Scope,
    src: usize,
    comptime T: type,
    positionals: std.meta.fieldInfo(T, "positionals").field_type,
    kw_args: std.meta.fieldInfo(T, "kw_args").field_type,
) !*T {
    const gen_zir = scope.getGenZIR();
    try gen_zir.instructions.ensureCapacity(self.gpa, gen_zir.instructions.items.len + 1);
    const inst = try gen_zir.arena.create(T);
    inst.* = .{
        .base = .{
            .tag = T.base_tag,
            .src = src,
        },
        .positionals = positionals,
        .kw_args = kw_args,
    };
    gen_zir.instructions.appendAssumeCapacity(&inst.base);
    return inst;
}

pub fn addZIRNoOp(
    self: *Module,
    scope: *Scope,
    src: usize,
    tag: zir.Inst.Tag,
) !*zir.Inst {
    const gen_zir = scope.getGenZIR();
    try gen_zir.instructions.ensureCapacity(self.gpa, gen_zir.instructions.items.len + 1);
    const inst = try gen_zir.arena.create(zir.Inst.NoOp);
    inst.* = .{
        .base = .{
            .tag = tag,
            .src = src,
        },
        .positionals = .{},
        .kw_args = .{},
    };
    gen_zir.instructions.appendAssumeCapacity(&inst.base);
    return &inst.base;
}

pub fn addZIRUnOp(
    self: *Module,
    scope: *Scope,
    src: usize,
    tag: zir.Inst.Tag,
    operand: *zir.Inst,
) !*zir.Inst {
    const gen_zir = scope.getGenZIR();
    try gen_zir.instructions.ensureCapacity(self.gpa, gen_zir.instructions.items.len + 1);
    const inst = try gen_zir.arena.create(zir.Inst.UnOp);
    inst.* = .{
        .base = .{
            .tag = tag,
            .src = src,
        },
        .positionals = .{
            .operand = operand,
        },
        .kw_args = .{},
    };
    gen_zir.instructions.appendAssumeCapacity(&inst.base);
    return &inst.base;
}

pub fn addZIRBinOp(
    self: *Module,
    scope: *Scope,
    src: usize,
    tag: zir.Inst.Tag,
    lhs: *zir.Inst,
    rhs: *zir.Inst,
) !*zir.Inst {
    const gen_zir = scope.getGenZIR();
    try gen_zir.instructions.ensureCapacity(self.gpa, gen_zir.instructions.items.len + 1);
    const inst = try gen_zir.arena.create(zir.Inst.BinOp);
    inst.* = .{
        .base = .{
            .tag = tag,
            .src = src,
        },
        .positionals = .{
            .lhs = lhs,
            .rhs = rhs,
        },
        .kw_args = .{},
    };
    gen_zir.instructions.appendAssumeCapacity(&inst.base);
    return &inst.base;
}

pub fn addZIRInst(
    self: *Module,
    scope: *Scope,
    src: usize,
    comptime T: type,
    positionals: std.meta.fieldInfo(T, "positionals").field_type,
    kw_args: std.meta.fieldInfo(T, "kw_args").field_type,
) !*zir.Inst {
    const inst_special = try self.addZIRInstSpecial(scope, src, T, positionals, kw_args);
    return &inst_special.base;
}

/// TODO The existence of this function is a workaround for a bug in stage1.
pub fn addZIRInstConst(self: *Module, scope: *Scope, src: usize, typed_value: TypedValue) !*zir.Inst {
    const P = std.meta.fieldInfo(zir.Inst.Const, "positionals").field_type;
    return self.addZIRInst(scope, src, zir.Inst.Const, P{ .typed_value = typed_value }, .{});
}

/// TODO The existence of this function is a workaround for a bug in stage1.
pub fn addZIRInstBlock(self: *Module, scope: *Scope, src: usize, body: zir.Module.Body) !*zir.Inst.Block {
    const P = std.meta.fieldInfo(zir.Inst.Block, "positionals").field_type;
    return self.addZIRInstSpecial(scope, src, zir.Inst.Block, P{ .body = body }, .{});
}

fn addNewInst(self: *Module, block: *Scope.Block, src: usize, ty: Type, comptime T: type) !*T {
    const inst = try block.arena.create(T);
    inst.* = .{
        .base = .{
            .tag = T.base_tag,
            .ty = ty,
            .src = src,
        },
    };
    try block.instructions.append(self.gpa, &inst.base);
    return inst;
}

fn constInst(self: *Module, scope: *Scope, src: usize, typed_value: TypedValue) !*Inst {
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

fn constType(self: *Module, scope: *Scope, src: usize, ty: Type) !*Inst {
    return self.constInst(scope, src, .{
        .ty = Type.initTag(.type),
        .val = try ty.toValue(scope.arena()),
    });
}

fn constVoid(self: *Module, scope: *Scope, src: usize) !*Inst {
    return self.constInst(scope, src, .{
        .ty = Type.initTag(.void),
        .val = Value.initTag(.the_one_possible_value),
    });
}

fn constNoReturn(self: *Module, scope: *Scope, src: usize) !*Inst {
    return self.constInst(scope, src, .{
        .ty = Type.initTag(.noreturn),
        .val = Value.initTag(.the_one_possible_value),
    });
}

fn constUndef(self: *Module, scope: *Scope, src: usize, ty: Type) !*Inst {
    return self.constInst(scope, src, .{
        .ty = ty,
        .val = Value.initTag(.undef),
    });
}

fn constBool(self: *Module, scope: *Scope, src: usize, v: bool) !*Inst {
    return self.constInst(scope, src, .{
        .ty = Type.initTag(.bool),
        .val = ([2]Value{ Value.initTag(.bool_false), Value.initTag(.bool_true) })[@boolToInt(v)],
    });
}

fn constIntUnsigned(self: *Module, scope: *Scope, src: usize, ty: Type, int: u64) !*Inst {
    const int_payload = try scope.arena().create(Value.Payload.Int_u64);
    int_payload.* = .{ .int = int };

    return self.constInst(scope, src, .{
        .ty = ty,
        .val = Value.initPayload(&int_payload.base),
    });
}

fn constIntSigned(self: *Module, scope: *Scope, src: usize, ty: Type, int: i64) !*Inst {
    const int_payload = try scope.arena().create(Value.Payload.Int_i64);
    int_payload.* = .{ .int = int };

    return self.constInst(scope, src, .{
        .ty = ty,
        .val = Value.initPayload(&int_payload.base),
    });
}

fn constIntBig(self: *Module, scope: *Scope, src: usize, ty: Type, big_int: BigIntConst) !*Inst {
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

fn analyzeConstInst(self: *Module, scope: *Scope, old_inst: *zir.Inst) InnerError!TypedValue {
    const new_inst = try self.analyzeInst(scope, old_inst);
    return TypedValue{
        .ty = new_inst.ty,
        .val = try self.resolveConstValue(scope, new_inst),
    };
}

fn analyzeInstConst(self: *Module, scope: *Scope, const_inst: *zir.Inst.Const) InnerError!*Inst {
    // Move the TypedValue from old memory to new memory. This allows freeing the ZIR instructions
    // after analysis.
    const typed_value_copy = try const_inst.positionals.typed_value.copy(scope.arena());
    return self.constInst(scope, const_inst.base.src, typed_value_copy);
}

fn analyzeInst(self: *Module, scope: *Scope, old_inst: *zir.Inst) InnerError!*Inst {
    switch (old_inst.tag) {
        .arg => return self.analyzeInstArg(scope, old_inst.castTag(.arg).?),
        .block => return self.analyzeInstBlock(scope, old_inst.castTag(.block).?),
        .@"break" => return self.analyzeInstBreak(scope, old_inst.castTag(.@"break").?),
        .breakpoint => return self.analyzeInstBreakpoint(scope, old_inst.castTag(.breakpoint).?),
        .breakvoid => return self.analyzeInstBreakVoid(scope, old_inst.castTag(.breakvoid).?),
        .call => return self.analyzeInstCall(scope, old_inst.castTag(.call).?),
        .compileerror => return self.analyzeInstCompileError(scope, old_inst.castTag(.compileerror).?),
        .@"const" => return self.analyzeInstConst(scope, old_inst.castTag(.@"const").?),
        .declref => return self.analyzeInstDeclRef(scope, old_inst.castTag(.declref).?),
        .declref_str => return self.analyzeInstDeclRefStr(scope, old_inst.castTag(.declref_str).?),
        .declval => return self.analyzeInstDeclVal(scope, old_inst.castTag(.declval).?),
        .declval_in_module => return self.analyzeInstDeclValInModule(scope, old_inst.castTag(.declval_in_module).?),
        .str => return self.analyzeInstStr(scope, old_inst.castTag(.str).?),
        .int => {
            const big_int = old_inst.castTag(.int).?.positionals.int;
            return self.constIntBig(scope, old_inst.src, Type.initTag(.comptime_int), big_int);
        },
        .inttype => return self.analyzeInstIntType(scope, old_inst.castTag(.inttype).?),
        .ptrtoint => return self.analyzeInstPtrToInt(scope, old_inst.castTag(.ptrtoint).?),
        .fieldptr => return self.analyzeInstFieldPtr(scope, old_inst.castTag(.fieldptr).?),
        .deref => return self.analyzeInstDeref(scope, old_inst.castTag(.deref).?),
        .as => return self.analyzeInstAs(scope, old_inst.castTag(.as).?),
        .@"asm" => return self.analyzeInstAsm(scope, old_inst.castTag(.@"asm").?),
        .@"unreachable" => return self.analyzeInstUnreachable(scope, old_inst.castTag(.@"unreachable").?),
        .@"return" => return self.analyzeInstRet(scope, old_inst.castTag(.@"return").?),
        .returnvoid => return self.analyzeInstRetVoid(scope, old_inst.castTag(.returnvoid).?),
        .@"fn" => return self.analyzeInstFn(scope, old_inst.castTag(.@"fn").?),
        .@"export" => return self.analyzeInstExport(scope, old_inst.castTag(.@"export").?),
        .primitive => return self.analyzeInstPrimitive(scope, old_inst.castTag(.primitive).?),
        .fntype => return self.analyzeInstFnType(scope, old_inst.castTag(.fntype).?),
        .intcast => return self.analyzeInstIntCast(scope, old_inst.castTag(.intcast).?),
        .bitcast => return self.analyzeInstBitCast(scope, old_inst.castTag(.bitcast).?),
        .floatcast => return self.analyzeInstFloatCast(scope, old_inst.castTag(.floatcast).?),
        .elemptr => return self.analyzeInstElemPtr(scope, old_inst.castTag(.elemptr).?),
        .add => return self.analyzeInstAdd(scope, old_inst.castTag(.add).?),
        .sub => return self.analyzeInstSub(scope, old_inst.castTag(.sub).?),
        .cmp_lt => return self.analyzeInstCmp(scope, old_inst.castTag(.cmp_lt).?, .lt),
        .cmp_lte => return self.analyzeInstCmp(scope, old_inst.castTag(.cmp_lte).?, .lte),
        .cmp_eq => return self.analyzeInstCmp(scope, old_inst.castTag(.cmp_eq).?, .eq),
        .cmp_gte => return self.analyzeInstCmp(scope, old_inst.castTag(.cmp_gte).?, .gte),
        .cmp_gt => return self.analyzeInstCmp(scope, old_inst.castTag(.cmp_gt).?, .gt),
        .cmp_neq => return self.analyzeInstCmp(scope, old_inst.castTag(.cmp_neq).?, .neq),
        .condbr => return self.analyzeInstCondBr(scope, old_inst.castTag(.condbr).?),
        .isnull => return self.analyzeInstIsNonNull(scope, old_inst.castTag(.isnull).?, true),
        .isnonnull => return self.analyzeInstIsNonNull(scope, old_inst.castTag(.isnonnull).?, false),
        .boolnot => return self.analyzeInstBoolNot(scope, old_inst.castTag(.boolnot).?),
    }
}

fn analyzeInstStr(self: *Module, scope: *Scope, str_inst: *zir.Inst.Str) InnerError!*Inst {
    // The bytes references memory inside the ZIR module, which can get deallocated
    // after semantic analysis is complete. We need the memory to be in the new anonymous Decl's arena.
    var new_decl_arena = std.heap.ArenaAllocator.init(self.gpa);
    const arena_bytes = try new_decl_arena.allocator.dupe(u8, str_inst.positionals.bytes);

    const ty_payload = try scope.arena().create(Type.Payload.Array_u8_Sentinel0);
    ty_payload.* = .{ .len = arena_bytes.len };

    const bytes_payload = try scope.arena().create(Value.Payload.Bytes);
    bytes_payload.* = .{ .data = arena_bytes };

    const new_decl = try self.createAnonymousDecl(scope, &new_decl_arena, .{
        .ty = Type.initPayload(&ty_payload.base),
        .val = Value.initPayload(&bytes_payload.base),
    });
    return self.analyzeDeclRef(scope, str_inst.base.src, new_decl);
}

fn createAnonymousDecl(
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

fn analyzeInstExport(self: *Module, scope: *Scope, export_inst: *zir.Inst.Export) InnerError!*Inst {
    const symbol_name = try self.resolveConstString(scope, export_inst.positionals.symbol_name);
    const exported_decl = self.lookupDeclName(scope, export_inst.positionals.decl_name) orelse
        return self.fail(scope, export_inst.base.src, "decl '{}' not found", .{export_inst.positionals.decl_name});
    try self.analyzeExport(scope, export_inst.base.src, symbol_name, exported_decl);
    return self.constVoid(scope, export_inst.base.src);
}

fn analyzeInstCompileError(self: *Module, scope: *Scope, inst: *zir.Inst.CompileError) InnerError!*Inst {
    return self.fail(scope, inst.base.src, "{}", .{inst.positionals.msg});
}

fn analyzeInstArg(self: *Module, scope: *Scope, inst: *zir.Inst.NoOp) InnerError!*Inst {
    const b = try self.requireRuntimeBlock(scope, inst.base.src);
    const fn_ty = b.func.?.owner_decl.typed_value.most_recent.typed_value.ty;
    const param_index = b.instructions.items.len;
    const param_count = fn_ty.fnParamLen();
    if (param_index >= param_count) {
        return self.fail(scope, inst.base.src, "parameter index {} outside list of length {}", .{
            param_index,
            param_count,
        });
    }
    const param_type = fn_ty.fnParamType(param_index);
    return self.addNoOp(b, inst.base.src, param_type, .arg);
}

fn analyzeInstBlock(self: *Module, scope: *Scope, inst: *zir.Inst.Block) InnerError!*Inst {
    const parent_block = scope.cast(Scope.Block).?;

    // Reserve space for a Block instruction so that generated Break instructions can
    // point to it, even if it doesn't end up getting used because the code ends up being
    // comptime evaluated.
    const block_inst = try parent_block.arena.create(Inst.Block);
    block_inst.* = .{
        .base = .{
            .tag = Inst.Block.base_tag,
            .ty = undefined, // Set after analysis.
            .src = inst.base.src,
        },
        .body = undefined,
    };

    var child_block: Scope.Block = .{
        .parent = parent_block,
        .func = parent_block.func,
        .decl = parent_block.decl,
        .instructions = .{},
        .arena = parent_block.arena,
        // TODO @as here is working around a miscompilation compiler bug :(
        .label = @as(?Scope.Block.Label, Scope.Block.Label{
            .zir_block = inst,
            .results = .{},
            .block_inst = block_inst,
        }),
    };
    const label = &child_block.label.?;

    defer child_block.instructions.deinit(self.gpa);
    defer label.results.deinit(self.gpa);

    try self.analyzeBody(&child_block.base, inst.positionals.body);

    // Blocks must terminate with noreturn instruction.
    assert(child_block.instructions.items.len != 0);
    assert(child_block.instructions.items[child_block.instructions.items.len - 1].ty.isNoReturn());

    // Need to set the type and emit the Block instruction. This allows machine code generation
    // to emit a jump instruction to after the block when it encounters the break.
    try parent_block.instructions.append(self.gpa, &block_inst.base);
    block_inst.base.ty = try self.resolvePeerTypes(scope, label.results.items);
    block_inst.body = .{ .instructions = try parent_block.arena.dupe(*Inst, child_block.instructions.items) };
    return &block_inst.base;
}

fn analyzeInstBreakpoint(self: *Module, scope: *Scope, inst: *zir.Inst.NoOp) InnerError!*Inst {
    const b = try self.requireRuntimeBlock(scope, inst.base.src);
    return self.addNoOp(b, inst.base.src, Type.initTag(.void), .breakpoint);
}

fn analyzeInstBreak(self: *Module, scope: *Scope, inst: *zir.Inst.Break) InnerError!*Inst {
    const operand = try self.resolveInst(scope, inst.positionals.operand);
    const block = inst.positionals.block;
    return self.analyzeBreak(scope, inst.base.src, block, operand);
}

fn analyzeInstBreakVoid(self: *Module, scope: *Scope, inst: *zir.Inst.BreakVoid) InnerError!*Inst {
    const block = inst.positionals.block;
    const void_inst = try self.constVoid(scope, inst.base.src);
    return self.analyzeBreak(scope, inst.base.src, block, void_inst);
}

fn analyzeBreak(
    self: *Module,
    scope: *Scope,
    src: usize,
    zir_block: *zir.Inst.Block,
    operand: *Inst,
) InnerError!*Inst {
    var opt_block = scope.cast(Scope.Block);
    while (opt_block) |block| {
        if (block.label) |*label| {
            if (label.zir_block == zir_block) {
                try label.results.append(self.gpa, operand);
                const b = try self.requireRuntimeBlock(scope, src);
                return self.addBr(b, src, label.block_inst, operand);
            }
        }
        opt_block = block.parent;
    } else unreachable;
}

fn analyzeInstDeclRefStr(self: *Module, scope: *Scope, inst: *zir.Inst.DeclRefStr) InnerError!*Inst {
    const decl_name = try self.resolveConstString(scope, inst.positionals.name);
    return self.analyzeDeclRefByName(scope, inst.base.src, decl_name);
}

fn analyzeInstDeclRef(self: *Module, scope: *Scope, inst: *zir.Inst.DeclRef) InnerError!*Inst {
    return self.analyzeDeclRefByName(scope, inst.base.src, inst.positionals.name);
}

fn analyzeDeclVal(self: *Module, scope: *Scope, inst: *zir.Inst.DeclVal) InnerError!*Decl {
    const decl_name = inst.positionals.name;
    const zir_module = scope.namespace().cast(Scope.ZIRModule).?;
    const src_decl = zir_module.contents.module.findDecl(decl_name) orelse
        return self.fail(scope, inst.base.src, "use of undeclared identifier '{}'", .{decl_name});

    const decl = try self.resolveCompleteZirDecl(scope, src_decl.decl);

    return decl;
}

fn analyzeInstDeclVal(self: *Module, scope: *Scope, inst: *zir.Inst.DeclVal) InnerError!*Inst {
    const decl = try self.analyzeDeclVal(scope, inst);
    const ptr = try self.analyzeDeclRef(scope, inst.base.src, decl);
    return self.analyzeDeref(scope, inst.base.src, ptr, inst.base.src);
}

fn analyzeInstDeclValInModule(self: *Module, scope: *Scope, inst: *zir.Inst.DeclValInModule) InnerError!*Inst {
    const decl = inst.positionals.decl;
    const ptr = try self.analyzeDeclRef(scope, inst.base.src, decl);
    return self.analyzeDeref(scope, inst.base.src, ptr, inst.base.src);
}

fn analyzeDeclRef(self: *Module, scope: *Scope, src: usize, decl: *Decl) InnerError!*Inst {
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

fn analyzeDeclRefByName(self: *Module, scope: *Scope, src: usize, decl_name: []const u8) InnerError!*Inst {
    const decl = self.lookupDeclName(scope, decl_name) orelse
        return self.fail(scope, src, "decl '{}' not found", .{decl_name});
    return self.analyzeDeclRef(scope, src, decl);
}

fn analyzeInstCall(self: *Module, scope: *Scope, inst: *zir.Inst.Call) InnerError!*Inst {
    const func = try self.resolveInst(scope, inst.positionals.func);
    if (func.ty.zigTypeTag() != .Fn)
        return self.fail(scope, inst.positionals.func.src, "type '{}' not a function", .{func.ty});

    const cc = func.ty.fnCallingConvention();
    if (cc == .Naked) {
        // TODO add error note: declared here
        return self.fail(
            scope,
            inst.positionals.func.src,
            "unable to call function with naked calling convention",
            .{},
        );
    }
    const call_params_len = inst.positionals.args.len;
    const fn_params_len = func.ty.fnParamLen();
    if (func.ty.fnIsVarArgs()) {
        if (call_params_len < fn_params_len) {
            // TODO add error note: declared here
            return self.fail(
                scope,
                inst.positionals.func.src,
                "expected at least {} arguments, found {}",
                .{ fn_params_len, call_params_len },
            );
        }
        return self.fail(scope, inst.base.src, "TODO implement support for calling var args functions", .{});
    } else if (fn_params_len != call_params_len) {
        // TODO add error note: declared here
        return self.fail(
            scope,
            inst.positionals.func.src,
            "expected {} arguments, found {}",
            .{ fn_params_len, call_params_len },
        );
    }

    if (inst.kw_args.modifier == .compile_time) {
        return self.fail(scope, inst.base.src, "TODO implement comptime function calls", .{});
    }
    if (inst.kw_args.modifier != .auto) {
        return self.fail(scope, inst.base.src, "TODO implement call with modifier {}", .{inst.kw_args.modifier});
    }

    // TODO handle function calls of generic functions

    const fn_param_types = try self.gpa.alloc(Type, fn_params_len);
    defer self.gpa.free(fn_param_types);
    func.ty.fnParamTypes(fn_param_types);

    const casted_args = try scope.arena().alloc(*Inst, fn_params_len);
    for (inst.positionals.args) |src_arg, i| {
        const uncasted_arg = try self.resolveInst(scope, src_arg);
        casted_args[i] = try self.coerce(scope, fn_param_types[i], uncasted_arg);
    }

    const b = try self.requireRuntimeBlock(scope, inst.base.src);
    return self.addCall(b, inst.base.src, Type.initTag(.void), func, casted_args);
}

fn analyzeInstFn(self: *Module, scope: *Scope, fn_inst: *zir.Inst.Fn) InnerError!*Inst {
    const fn_type = try self.resolveType(scope, fn_inst.positionals.fn_type);
    const fn_zir = blk: {
        var fn_arena = std.heap.ArenaAllocator.init(self.gpa);
        errdefer fn_arena.deinit();

        const fn_zir = try scope.arena().create(Fn.ZIR);
        fn_zir.* = .{
            .body = .{
                .instructions = fn_inst.positionals.body.instructions,
            },
            .arena = fn_arena.state,
        };
        break :blk fn_zir;
    };
    const new_func = try scope.arena().create(Fn);
    new_func.* = .{
        .analysis = .{ .queued = fn_zir },
        .owner_decl = scope.decl().?,
    };
    const fn_payload = try scope.arena().create(Value.Payload.Function);
    fn_payload.* = .{ .func = new_func };
    return self.constInst(scope, fn_inst.base.src, .{
        .ty = fn_type,
        .val = Value.initPayload(&fn_payload.base),
    });
}

fn analyzeInstIntType(self: *Module, scope: *Scope, inttype: *zir.Inst.IntType) InnerError!*Inst {
    return self.fail(scope, inttype.base.src, "TODO implement inttype", .{});
}

fn analyzeInstFnType(self: *Module, scope: *Scope, fntype: *zir.Inst.FnType) InnerError!*Inst {
    const return_type = try self.resolveType(scope, fntype.positionals.return_type);

    // Hot path for some common function types.
    if (fntype.positionals.param_types.len == 0) {
        if (return_type.zigTypeTag() == .NoReturn and fntype.kw_args.cc == .Unspecified) {
            return self.constType(scope, fntype.base.src, Type.initTag(.fn_noreturn_no_args));
        }

        if (return_type.zigTypeTag() == .Void and fntype.kw_args.cc == .Unspecified) {
            return self.constType(scope, fntype.base.src, Type.initTag(.fn_void_no_args));
        }

        if (return_type.zigTypeTag() == .NoReturn and fntype.kw_args.cc == .Naked) {
            return self.constType(scope, fntype.base.src, Type.initTag(.fn_naked_noreturn_no_args));
        }

        if (return_type.zigTypeTag() == .Void and fntype.kw_args.cc == .C) {
            return self.constType(scope, fntype.base.src, Type.initTag(.fn_ccc_void_no_args));
        }
    }

    const arena = scope.arena();
    const param_types = try arena.alloc(Type, fntype.positionals.param_types.len);
    for (fntype.positionals.param_types) |param_type, i| {
        param_types[i] = try self.resolveType(scope, param_type);
    }

    const payload = try arena.create(Type.Payload.Function);
    payload.* = .{
        .cc = fntype.kw_args.cc,
        .return_type = return_type,
        .param_types = param_types,
    };
    return self.constType(scope, fntype.base.src, Type.initPayload(&payload.base));
}

fn analyzeInstPrimitive(self: *Module, scope: *Scope, primitive: *zir.Inst.Primitive) InnerError!*Inst {
    return self.constInst(scope, primitive.base.src, primitive.positionals.tag.toTypedValue());
}

fn analyzeInstAs(self: *Module, scope: *Scope, as: *zir.Inst.As) InnerError!*Inst {
    const dest_type = try self.resolveType(scope, as.positionals.dest_type);
    const new_inst = try self.resolveInst(scope, as.positionals.value);
    return self.coerce(scope, dest_type, new_inst);
}

fn analyzeInstPtrToInt(self: *Module, scope: *Scope, ptrtoint: *zir.Inst.PtrToInt) InnerError!*Inst {
    const ptr = try self.resolveInst(scope, ptrtoint.positionals.operand);
    if (ptr.ty.zigTypeTag() != .Pointer) {
        return self.fail(scope, ptrtoint.positionals.operand.src, "expected pointer, found '{}'", .{ptr.ty});
    }
    // TODO handle known-pointer-address
    const b = try self.requireRuntimeBlock(scope, ptrtoint.base.src);
    const ty = Type.initTag(.usize);
    return self.addUnOp(b, ptrtoint.base.src, ty, .ptrtoint, ptr);
}

fn analyzeInstFieldPtr(self: *Module, scope: *Scope, fieldptr: *zir.Inst.FieldPtr) InnerError!*Inst {
    const object_ptr = try self.resolveInst(scope, fieldptr.positionals.object_ptr);
    const field_name = try self.resolveConstString(scope, fieldptr.positionals.field_name);

    const elem_ty = switch (object_ptr.ty.zigTypeTag()) {
        .Pointer => object_ptr.ty.elemType(),
        else => return self.fail(scope, fieldptr.positionals.object_ptr.src, "expected pointer, found '{}'", .{object_ptr.ty}),
    };
    switch (elem_ty.zigTypeTag()) {
        .Array => {
            if (mem.eql(u8, field_name, "len")) {
                const len_payload = try scope.arena().create(Value.Payload.Int_u64);
                len_payload.* = .{ .int = elem_ty.arrayLen() };

                const ref_payload = try scope.arena().create(Value.Payload.RefVal);
                ref_payload.* = .{ .val = Value.initPayload(&len_payload.base) };

                return self.constInst(scope, fieldptr.base.src, .{
                    .ty = Type.initTag(.single_const_pointer_to_comptime_int),
                    .val = Value.initPayload(&ref_payload.base),
                });
            } else {
                return self.fail(
                    scope,
                    fieldptr.positionals.field_name.src,
                    "no member named '{}' in '{}'",
                    .{ field_name, elem_ty },
                );
            }
        },
        else => return self.fail(scope, fieldptr.base.src, "type '{}' does not support field access", .{elem_ty}),
    }
}

fn analyzeInstIntCast(self: *Module, scope: *Scope, inst: *zir.Inst.IntCast) InnerError!*Inst {
    const dest_type = try self.resolveType(scope, inst.positionals.dest_type);
    const operand = try self.resolveInst(scope, inst.positionals.operand);

    const dest_is_comptime_int = switch (dest_type.zigTypeTag()) {
        .ComptimeInt => true,
        .Int => false,
        else => return self.fail(
            scope,
            inst.positionals.dest_type.src,
            "expected integer type, found '{}'",
            .{
                dest_type,
            },
        ),
    };

    switch (operand.ty.zigTypeTag()) {
        .ComptimeInt, .Int => {},
        else => return self.fail(
            scope,
            inst.positionals.operand.src,
            "expected integer type, found '{}'",
            .{operand.ty},
        ),
    }

    if (operand.value() != null) {
        return self.coerce(scope, dest_type, operand);
    } else if (dest_is_comptime_int) {
        return self.fail(scope, inst.base.src, "unable to cast runtime value to 'comptime_int'", .{});
    }

    return self.fail(scope, inst.base.src, "TODO implement analyze widen or shorten int", .{});
}

fn analyzeInstBitCast(self: *Module, scope: *Scope, inst: *zir.Inst.BitCast) InnerError!*Inst {
    const dest_type = try self.resolveType(scope, inst.positionals.dest_type);
    const operand = try self.resolveInst(scope, inst.positionals.operand);
    return self.bitcast(scope, dest_type, operand);
}

fn analyzeInstFloatCast(self: *Module, scope: *Scope, inst: *zir.Inst.FloatCast) InnerError!*Inst {
    const dest_type = try self.resolveType(scope, inst.positionals.dest_type);
    const operand = try self.resolveInst(scope, inst.positionals.operand);

    const dest_is_comptime_float = switch (dest_type.zigTypeTag()) {
        .ComptimeFloat => true,
        .Float => false,
        else => return self.fail(
            scope,
            inst.positionals.dest_type.src,
            "expected float type, found '{}'",
            .{
                dest_type,
            },
        ),
    };

    switch (operand.ty.zigTypeTag()) {
        .ComptimeFloat, .Float, .ComptimeInt => {},
        else => return self.fail(
            scope,
            inst.positionals.operand.src,
            "expected float type, found '{}'",
            .{operand.ty},
        ),
    }

    if (operand.value() != null) {
        return self.coerce(scope, dest_type, operand);
    } else if (dest_is_comptime_float) {
        return self.fail(scope, inst.base.src, "unable to cast runtime value to 'comptime_float'", .{});
    }

    return self.fail(scope, inst.base.src, "TODO implement analyze widen or shorten float", .{});
}

fn analyzeInstElemPtr(self: *Module, scope: *Scope, inst: *zir.Inst.ElemPtr) InnerError!*Inst {
    const array_ptr = try self.resolveInst(scope, inst.positionals.array_ptr);
    const uncasted_index = try self.resolveInst(scope, inst.positionals.index);
    const elem_index = try self.coerce(scope, Type.initTag(.usize), uncasted_index);

    if (array_ptr.ty.isSinglePointer() and array_ptr.ty.elemType().zigTypeTag() == .Array) {
        if (array_ptr.value()) |array_ptr_val| {
            if (elem_index.value()) |index_val| {
                // Both array pointer and index are compile-time known.
                const index_u64 = index_val.toUnsignedInt();
                // @intCast here because it would have been impossible to construct a value that
                // required a larger index.
                const elem_ptr = try array_ptr_val.elemPtr(scope.arena(), @intCast(usize, index_u64));

                const type_payload = try scope.arena().create(Type.Payload.SingleConstPointer);
                type_payload.* = .{ .pointee_type = array_ptr.ty.elemType().elemType() };

                return self.constInst(scope, inst.base.src, .{
                    .ty = Type.initPayload(&type_payload.base),
                    .val = elem_ptr,
                });
            }
        }
    }

    return self.fail(scope, inst.base.src, "TODO implement more analyze elemptr", .{});
}

fn analyzeInstSub(self: *Module, scope: *Scope, inst: *zir.Inst.BinOp) InnerError!*Inst {
    return self.fail(scope, inst.base.src, "TODO implement analysis of sub", .{});
}

fn analyzeInstAdd(self: *Module, scope: *Scope, inst: *zir.Inst.BinOp) InnerError!*Inst {
    const tracy = trace(@src());
    defer tracy.end();

    const lhs = try self.resolveInst(scope, inst.positionals.lhs);
    const rhs = try self.resolveInst(scope, inst.positionals.rhs);

    if ((lhs.ty.zigTypeTag() == .Int or lhs.ty.zigTypeTag() == .ComptimeInt) and
        (rhs.ty.zigTypeTag() == .Int or rhs.ty.zigTypeTag() == .ComptimeInt))
    {
        if (!lhs.ty.eql(rhs.ty)) {
            return self.fail(scope, inst.base.src, "TODO implement peer type resolution", .{});
        }

        if (lhs.value()) |lhs_val| {
            if (rhs.value()) |rhs_val| {
                // TODO is this a performance issue? maybe we should try the operation without
                // resorting to BigInt first.
                var lhs_space: Value.BigIntSpace = undefined;
                var rhs_space: Value.BigIntSpace = undefined;
                const lhs_bigint = lhs_val.toBigInt(&lhs_space);
                const rhs_bigint = rhs_val.toBigInt(&rhs_space);
                const limbs = try scope.arena().alloc(
                    std.math.big.Limb,
                    std.math.max(lhs_bigint.limbs.len, rhs_bigint.limbs.len) + 1,
                );
                var result_bigint = BigIntMutable{ .limbs = limbs, .positive = undefined, .len = undefined };
                result_bigint.add(lhs_bigint, rhs_bigint);
                const result_limbs = result_bigint.limbs[0..result_bigint.len];

                const val_payload = if (result_bigint.positive) blk: {
                    const val_payload = try scope.arena().create(Value.Payload.IntBigPositive);
                    val_payload.* = .{ .limbs = result_limbs };
                    break :blk &val_payload.base;
                } else blk: {
                    const val_payload = try scope.arena().create(Value.Payload.IntBigNegative);
                    val_payload.* = .{ .limbs = result_limbs };
                    break :blk &val_payload.base;
                };

                return self.constInst(scope, inst.base.src, .{
                    .ty = lhs.ty,
                    .val = Value.initPayload(val_payload),
                });
            }
        }

        const b = try self.requireRuntimeBlock(scope, inst.base.src);
        return self.addBinOp(b, inst.base.src, lhs.ty, .add, lhs, rhs);
    }
    return self.fail(scope, inst.base.src, "TODO analyze add for {} + {}", .{ lhs.ty.zigTypeTag(), rhs.ty.zigTypeTag() });
}

fn analyzeInstDeref(self: *Module, scope: *Scope, deref: *zir.Inst.UnOp) InnerError!*Inst {
    const ptr = try self.resolveInst(scope, deref.positionals.operand);
    return self.analyzeDeref(scope, deref.base.src, ptr, deref.positionals.operand.src);
}

fn analyzeDeref(self: *Module, scope: *Scope, src: usize, ptr: *Inst, ptr_src: usize) InnerError!*Inst {
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

    return self.fail(scope, src, "TODO implement runtime deref", .{});
}

fn analyzeInstAsm(self: *Module, scope: *Scope, assembly: *zir.Inst.Asm) InnerError!*Inst {
    const return_type = try self.resolveType(scope, assembly.positionals.return_type);
    const asm_source = try self.resolveConstString(scope, assembly.positionals.asm_source);
    const output = if (assembly.kw_args.output) |o| try self.resolveConstString(scope, o) else null;

    const inputs = try scope.arena().alloc([]const u8, assembly.kw_args.inputs.len);
    const clobbers = try scope.arena().alloc([]const u8, assembly.kw_args.clobbers.len);
    const args = try scope.arena().alloc(*Inst, assembly.kw_args.args.len);

    for (inputs) |*elem, i| {
        elem.* = try self.resolveConstString(scope, assembly.kw_args.inputs[i]);
    }
    for (clobbers) |*elem, i| {
        elem.* = try self.resolveConstString(scope, assembly.kw_args.clobbers[i]);
    }
    for (args) |*elem, i| {
        const arg = try self.resolveInst(scope, assembly.kw_args.args[i]);
        elem.* = try self.coerce(scope, Type.initTag(.usize), arg);
    }

    const b = try self.requireRuntimeBlock(scope, assembly.base.src);
    const inst = try b.arena.create(Inst.Assembly);
    inst.* = .{
        .base = .{
            .tag = .assembly,
            .ty = return_type,
            .src = assembly.base.src,
        },
        .asm_source = asm_source,
        .is_volatile = assembly.kw_args.@"volatile",
        .output = output,
        .inputs = inputs,
        .clobbers = clobbers,
        .args = args,
    };
    try b.instructions.append(self.gpa, &inst.base);
    return &inst.base;
}

fn analyzeInstCmp(
    self: *Module,
    scope: *Scope,
    inst: *zir.Inst.BinOp,
    op: std.math.CompareOperator,
) InnerError!*Inst {
    const lhs = try self.resolveInst(scope, inst.positionals.lhs);
    const rhs = try self.resolveInst(scope, inst.positionals.rhs);

    const is_equality_cmp = switch (op) {
        .eq, .neq => true,
        else => false,
    };
    const lhs_ty_tag = lhs.ty.zigTypeTag();
    const rhs_ty_tag = rhs.ty.zigTypeTag();
    if (is_equality_cmp and lhs_ty_tag == .Null and rhs_ty_tag == .Null) {
        // null == null, null != null
        return self.constBool(scope, inst.base.src, op == .eq);
    } else if (is_equality_cmp and
        ((lhs_ty_tag == .Null and rhs_ty_tag == .Optional) or
        rhs_ty_tag == .Null and lhs_ty_tag == .Optional))
    {
        // comparing null with optionals
        const opt_operand = if (lhs_ty_tag == .Optional) lhs else rhs;
        if (opt_operand.value()) |opt_val| {
            const is_null = opt_val.isNull();
            return self.constBool(scope, inst.base.src, if (op == .eq) is_null else !is_null);
        }
        const b = try self.requireRuntimeBlock(scope, inst.base.src);
        const inst_tag: Inst.Tag = switch (op) {
            .eq => .isnull,
            .neq => .isnonnull,
            else => unreachable,
        };
        return self.addUnOp(b, inst.base.src, Type.initTag(.bool), inst_tag, opt_operand);
    } else if (is_equality_cmp and
        ((lhs_ty_tag == .Null and rhs.ty.isCPtr()) or (rhs_ty_tag == .Null and lhs.ty.isCPtr())))
    {
        return self.fail(scope, inst.base.src, "TODO implement C pointer cmp", .{});
    } else if (lhs_ty_tag == .Null or rhs_ty_tag == .Null) {
        const non_null_type = if (lhs_ty_tag == .Null) rhs.ty else lhs.ty;
        return self.fail(scope, inst.base.src, "comparison of '{}' with null", .{non_null_type});
    } else if (is_equality_cmp and
        ((lhs_ty_tag == .EnumLiteral and rhs_ty_tag == .Union) or
        (rhs_ty_tag == .EnumLiteral and lhs_ty_tag == .Union)))
    {
        return self.fail(scope, inst.base.src, "TODO implement equality comparison between a union's tag value and an enum literal", .{});
    } else if (lhs_ty_tag == .ErrorSet and rhs_ty_tag == .ErrorSet) {
        if (!is_equality_cmp) {
            return self.fail(scope, inst.base.src, "{} operator not allowed for errors", .{@tagName(op)});
        }
        return self.fail(scope, inst.base.src, "TODO implement equality comparison between errors", .{});
    } else if (lhs.ty.isNumeric() and rhs.ty.isNumeric()) {
        // This operation allows any combination of integer and float types, regardless of the
        // signed-ness, comptime-ness, and bit-width. So peer type resolution is incorrect for
        // numeric types.
        return self.cmpNumeric(scope, inst.base.src, lhs, rhs, op);
    }
    return self.fail(scope, inst.base.src, "TODO implement more cmp analysis", .{});
}

fn analyzeInstBoolNot(self: *Module, scope: *Scope, inst: *zir.Inst.UnOp) InnerError!*Inst {
    const uncasted_operand = try self.resolveInst(scope, inst.positionals.operand);
    const bool_type = Type.initTag(.bool);
    const operand = try self.coerce(scope, bool_type, uncasted_operand);
    if (try self.resolveDefinedValue(scope, operand)) |val| {
        return self.constBool(scope, inst.base.src, !val.toBool());
    }
    const b = try self.requireRuntimeBlock(scope, inst.base.src);
    return self.addUnOp(b, inst.base.src, bool_type, .not, operand);
}

fn analyzeInstIsNonNull(self: *Module, scope: *Scope, inst: *zir.Inst.UnOp, invert_logic: bool) InnerError!*Inst {
    const operand = try self.resolveInst(scope, inst.positionals.operand);
    return self.analyzeIsNull(scope, inst.base.src, operand, invert_logic);
}

fn analyzeInstCondBr(self: *Module, scope: *Scope, inst: *zir.Inst.CondBr) InnerError!*Inst {
    const uncasted_cond = try self.resolveInst(scope, inst.positionals.condition);
    const cond = try self.coerce(scope, Type.initTag(.bool), uncasted_cond);

    if (try self.resolveDefinedValue(scope, cond)) |cond_val| {
        const body = if (cond_val.toBool()) &inst.positionals.then_body else &inst.positionals.else_body;
        try self.analyzeBody(scope, body.*);
        return self.constVoid(scope, inst.base.src);
    }

    const parent_block = try self.requireRuntimeBlock(scope, inst.base.src);

    var true_block: Scope.Block = .{
        .parent = parent_block,
        .func = parent_block.func,
        .decl = parent_block.decl,
        .instructions = .{},
        .arena = parent_block.arena,
    };
    defer true_block.instructions.deinit(self.gpa);
    try self.analyzeBody(&true_block.base, inst.positionals.then_body);

    var false_block: Scope.Block = .{
        .parent = parent_block,
        .func = parent_block.func,
        .decl = parent_block.decl,
        .instructions = .{},
        .arena = parent_block.arena,
    };
    defer false_block.instructions.deinit(self.gpa);
    try self.analyzeBody(&false_block.base, inst.positionals.else_body);

    const then_body: ir.Body = .{ .instructions = try scope.arena().dupe(*Inst, true_block.instructions.items) };
    const else_body: ir.Body = .{ .instructions = try scope.arena().dupe(*Inst, false_block.instructions.items) };
    return self.addCondBr(parent_block, inst.base.src, cond, then_body, else_body);
}

fn wantSafety(self: *Module, scope: *Scope) bool {
    return switch (self.optimize_mode) {
        .Debug => true,
        .ReleaseSafe => true,
        .ReleaseFast => false,
        .ReleaseSmall => false,
    };
}

fn analyzeInstUnreachable(self: *Module, scope: *Scope, unreach: *zir.Inst.NoOp) InnerError!*Inst {
    const b = try self.requireRuntimeBlock(scope, unreach.base.src);
    if (self.wantSafety(scope)) {
        // TODO Once we have a panic function to call, call it here instead of this.
        _ = try self.addNoOp(b, unreach.base.src, Type.initTag(.void), .breakpoint);
    }
    return self.addNoOp(b, unreach.base.src, Type.initTag(.noreturn), .unreach);
}

fn analyzeInstRet(self: *Module, scope: *Scope, inst: *zir.Inst.UnOp) InnerError!*Inst {
    const operand = try self.resolveInst(scope, inst.positionals.operand);
    const b = try self.requireRuntimeBlock(scope, inst.base.src);
    return self.addUnOp(b, inst.base.src, Type.initTag(.noreturn), .ret, operand);
}

fn analyzeInstRetVoid(self: *Module, scope: *Scope, inst: *zir.Inst.NoOp) InnerError!*Inst {
    const b = try self.requireRuntimeBlock(scope, inst.base.src);
    return self.addNoOp(b, inst.base.src, Type.initTag(.noreturn), .retvoid);
}

fn analyzeBody(self: *Module, scope: *Scope, body: zir.Module.Body) !void {
    for (body.instructions) |src_inst| {
        src_inst.analyzed_inst = try self.analyzeInst(scope, src_inst);
    }
}

fn analyzeIsNull(
    self: *Module,
    scope: *Scope,
    src: usize,
    operand: *Inst,
    invert_logic: bool,
) InnerError!*Inst {
    return self.fail(scope, src, "TODO implement analysis of isnull and isnotnull", .{});
}

/// Asserts that lhs and rhs types are both numeric.
fn cmpNumeric(
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

fn resolvePeerTypes(self: *Module, scope: *Scope, instructions: []*Inst) !Type {
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

        // TODO error notes pointing out each type
        return self.fail(scope, next_inst.src, "incompatible types: '{}' and '{}'", .{ prev_inst.ty, next_inst.ty });
    }

    return prev_inst.ty;
}

fn coerce(self: *Module, scope: *Scope, dest_type: Type, inst: *Inst) !*Inst {
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

    // *[N]T to []T
    if (inst.ty.isSinglePointer() and dest_type.isSlice() and
        (!inst.ty.pointerIsConst() or dest_type.pointerIsConst()))
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

    return self.fail(scope, inst.src, "TODO implement type coercion from {} to {}", .{ inst.ty, dest_type });
}

fn bitcast(self: *Module, scope: *Scope, dest_type: Type, inst: *Inst) !*Inst {
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
        .local_var => {
            const gen_zir = scope.cast(Scope.LocalVar).?.gen_zir;
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
