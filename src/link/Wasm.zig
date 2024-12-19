//! The overall strategy here is to load all the object file data into memory
//! as inputs are parsed. During `prelink`, as much linking as possible is
//! performed without any knowledge of functions and globals provided by the
//! Zcu. If there is no Zcu, effectively all linking is done in `prelink`.
//!
//! `updateFunc`, `updateNav`, `updateExports`, and `deleteExport` are handled
//! by merely tracking references to the relevant functions and globals. All
//! the linking logic between objects and Zcu happens in `flush`. Many
//! components of the final output are computed on-the-fly at this time rather
//! than being precomputed and stored separately.

const Wasm = @This();
const Archive = @import("Wasm/Archive.zig");
const Object = @import("Wasm/Object.zig");
const Flush = @import("Wasm/Flush.zig");

const builtin = @import("builtin");
const native_endian = builtin.cpu.arch.endian();

const build_options = @import("build_options");

const std = @import("std");
const Allocator = std.mem.Allocator;
const Cache = std.Build.Cache;
const Path = Cache.Path;
const assert = std.debug.assert;
const fs = std.fs;
const leb = std.leb;
const log = std.log.scoped(.link);
const mem = std.mem;

const Air = @import("../Air.zig");
const Mir = @import("../arch/wasm/Mir.zig");
const CodeGen = @import("../arch/wasm/CodeGen.zig");
const abi = @import("../arch/wasm/abi.zig");
const Compilation = @import("../Compilation.zig");
const Dwarf = @import("Dwarf.zig");
const InternPool = @import("../InternPool.zig");
const Liveness = @import("../Liveness.zig");
const LlvmObject = @import("../codegen/llvm.zig").Object;
const Zcu = @import("../Zcu.zig");
const codegen = @import("../codegen.zig");
const dev = @import("../dev.zig");
const link = @import("../link.zig");
const lldMain = @import("../main.zig").lldMain;
const trace = @import("../tracy.zig").trace;
const wasi_libc = @import("../wasi_libc.zig");
const Value = @import("../Value.zig");
const ZcuType = @import("../Type.zig");

base: link.File,
/// Null-terminated strings, indexes have type String and string_table provides
/// lookup.
///
/// There are a couple of sites that add things here without adding
/// corresponding string_table entries. For such cases, when implementing
/// serialization/deserialization, they should be adjusted to prefix that data
/// with a null byte so that deserialization does not attempt to create
/// string_table entries for them. Alternately those sites could be moved to
/// use a different byte array for this purpose.
string_bytes: std.ArrayListUnmanaged(u8),
/// Sometimes we have logic that wants to borrow string bytes to store
/// arbitrary things in there. In this case it is not allowed to intern new
/// strings during this time. This safety lock is used to detect misuses.
string_bytes_lock: std.debug.SafetyLock = .{},
/// Omitted when serializing linker state.
string_table: String.Table,
/// Symbol name of the entry function to export
entry_name: OptionalString,
/// When true, will allow undefined symbols
import_symbols: bool,
/// Set of *global* symbol names to export to the host environment.
export_symbol_names: []const []const u8,
/// When defined, sets the start of the data section.
global_base: ?u64,
/// When defined, sets the initial memory size of the memory.
initial_memory: ?u64,
/// When defined, sets the maximum memory size of the memory.
max_memory: ?u64,
/// When true, will import the function table from the host environment.
import_table: bool,
/// When true, will export the function table to the host environment.
export_table: bool,
/// Output name of the file
name: []const u8,
/// If this is not null, an object file is created by LLVM and linked with LLD afterwards.
llvm_object: ?LlvmObject.Ptr = null,
/// List of relocatable files to be linked into the final binary.
objects: std.ArrayListUnmanaged(Object) = .{},

func_types: std.AutoArrayHashMapUnmanaged(FunctionType, void) = .empty,
/// Provides a mapping of both imports and provided functions to symbol name.
/// Local functions may be unnamed.
object_function_imports: std.AutoArrayHashMapUnmanaged(String, FunctionImport) = .empty,
/// All functions for all objects.
object_functions: std.ArrayListUnmanaged(Function) = .empty,

/// Provides a mapping of both imports and provided globals to symbol name.
/// Local globals may be unnamed.
object_global_imports: std.AutoArrayHashMapUnmanaged(String, GlobalImport) = .empty,
/// All globals for all objects.
object_globals: std.ArrayListUnmanaged(Global) = .empty,

/// All table imports for all objects.
object_table_imports: std.AutoArrayHashMapUnmanaged(String, TableImport) = .empty,
/// All parsed table sections for all objects.
object_tables: std.ArrayListUnmanaged(Table) = .empty,

/// All memory imports for all objects.
object_memory_imports: std.ArrayListUnmanaged(MemoryImport) = .empty,
/// All parsed memory sections for all objects.
object_memories: std.ArrayListUnmanaged(std.wasm.Memory) = .empty,

/// All relocations from all objects concatenated. `relocs_start` marks the end
/// point of object relocations and start point of Zcu relocations.
object_relocations: std.MultiArrayList(ObjectRelocation) = .empty,

/// List of initialization functions. These must be called in order of priority
/// by the (synthetic) __wasm_call_ctors function.
object_init_funcs: std.ArrayListUnmanaged(InitFunc) = .empty,

/// Non-synthetic section that can essentially be mem-cpy'd into place after performing relocations.
object_data_segments: std.ArrayListUnmanaged(DataSegment) = .empty,
/// Non-synthetic section that can essentially be mem-cpy'd into place after performing relocations.
object_custom_segments: std.AutoArrayHashMapUnmanaged(ObjectSectionIndex, CustomSegment) = .empty,

/// All comdat information for all objects.
object_comdats: std.ArrayListUnmanaged(Comdat) = .empty,
/// A table that maps the relocations to be performed where the key represents
/// the section (across all objects) that the slice of relocations applies to.
object_relocations_table: std.AutoArrayHashMapUnmanaged(ObjectSectionIndex, ObjectRelocation.Slice) = .empty,
/// Incremented across all objects in order to enable calculation of `ObjectSectionIndex` values.
object_total_sections: u32 = 0,
/// All comdat symbols from all objects concatenated.
object_comdat_symbols: std.MultiArrayList(Comdat.Symbol) = .empty,

/// Relocations to be emitted into an object file. Remains empty when not
/// emitting an object file.
out_relocs: std.MultiArrayList(OutReloc) = .empty,
/// List of locations within `string_bytes` that must be patched with the virtual
/// memory address of a Uav during `flush`.
/// When emitting an object file, `out_relocs` is used instead.
uav_fixups: std.ArrayListUnmanaged(UavFixup) = .empty,
/// List of locations within `string_bytes` that must be patched with the virtual
/// memory address of a Nav during `flush`.
/// When emitting an object file, `out_relocs` is used instead.
nav_fixups: std.ArrayListUnmanaged(NavFixup) = .empty,
/// Symbols to be emitted into an object file. Remains empty when not emitting
/// an object file.
symbol_table: std.AutoArrayHashMapUnmanaged(String, void) = .empty,

/// When importing objects from the host environment, a name must be supplied.
/// LLVM uses "env" by default when none is given.
/// This value is passed to object files since wasm tooling conventions provides
/// no way to specify the module name in the symbol table.
object_host_name: OptionalString,

/// Memory section
memories: std.wasm.Memory = .{ .limits = .{
    .min = 0,
    .max = undefined,
    .flags = .{ .has_max = false, .is_shared = false },
} },

/// `--verbose-link` output.
/// Initialized on creation, appended to as inputs are added, printed during `flush`.
/// String data is allocated into Compilation arena.
dump_argv_list: std.ArrayListUnmanaged([]const u8),

preloaded_strings: PreloadedStrings,

/// This field is used when emitting an object; `navs_exe` used otherwise.
navs_obj: std.AutoArrayHashMapUnmanaged(InternPool.Nav.Index, ZcuDataObj) = .empty,
/// This field is unused when emitting an object; `navs_exe` used otherwise.
navs_exe: std.AutoArrayHashMapUnmanaged(InternPool.Nav.Index, ZcuDataExe) = .empty,
/// Tracks all InternPool values referenced by codegen. Needed for outputting
/// the data segment. This one does not track ref count because object files
/// require using max LEB encoding for these references anyway.
uavs_obj: std.AutoArrayHashMapUnmanaged(InternPool.Index, ZcuDataObj) = .empty,
/// Tracks ref count to optimize LEB encodings for UAV references.
uavs_exe: std.AutoArrayHashMapUnmanaged(InternPool.Index, ZcuDataExe) = .empty,
zcu_funcs: std.AutoArrayHashMapUnmanaged(InternPool.Index, ZcuFunc) = .empty,
nav_exports: std.AutoArrayHashMapUnmanaged(NavExport, Zcu.Export.Index) = .empty,
uav_exports: std.AutoArrayHashMapUnmanaged(UavExport, Zcu.Export.Index) = .empty,
imports: std.AutoArrayHashMapUnmanaged(InternPool.Nav.Index, void) = .empty,

dwarf: ?Dwarf = null,
debug_sections: DebugSections = .{},

flush_buffer: Flush = .{},

/// Empty until `prelink`. There it is populated based on object files.
/// Next, it is copied into `Flush.missing_exports` just before `flush`
/// and that data is used during `flush`.
missing_exports: std.AutoArrayHashMapUnmanaged(String, void) = .empty,
entry_resolution: FunctionImport.Resolution = .unresolved,

/// Empty when outputting an object.
function_exports: std.ArrayListUnmanaged(FunctionExport) = .empty,
/// Tracks the value at the end of prelink.
function_exports_len: u32 = 0,
global_exports: std.ArrayListUnmanaged(GlobalExport) = .empty,
/// Tracks the value at the end of prelink.
global_exports_len: u32 = 0,

/// Ordered list of non-import functions that will appear in the final binary.
/// Empty until prelink.
functions: std.AutoArrayHashMapUnmanaged(FunctionImport.Resolution, void) = .empty,
/// Tracks the value at the end of prelink, at which point `functions`
/// contains only object file functions, and nothing from the Zcu yet.
functions_end_prelink: u32 = 0,
/// At the end of prelink, this is populated with needed functions from
/// objects.
///
/// During the Zcu phase, entries are not deleted from this table
/// because doing so would be irreversible when a `deleteExport` call is
/// handled. However, entries are added during the Zcu phase when extern
/// functions are passed to `updateNav`.
///
/// `flush` gets a copy of this table, and then Zcu exports are applied to
/// remove elements from the table, and the remainder are either undefined
/// symbol errors, or import section entries depending on the output mode.
function_imports: std.AutoArrayHashMapUnmanaged(String, FunctionImportId) = .empty,

/// Ordered list of non-import globals that will appear in the final binary.
/// Empty until prelink.
globals: std.AutoArrayHashMapUnmanaged(GlobalImport.Resolution, void) = .empty,
/// Tracks the value at the end of prelink, at which point `globals`
/// contains only object file globals, and nothing from the Zcu yet.
globals_end_prelink: u32 = 0,
global_imports: std.AutoArrayHashMapUnmanaged(String, GlobalImportId) = .empty,

/// Ordered list of non-import tables that will appear in the final binary.
/// Empty until prelink.
tables: std.AutoArrayHashMapUnmanaged(TableImport.Resolution, void) = .empty,
table_imports: std.AutoArrayHashMapUnmanaged(String, TableImport.Index) = .empty,

/// Ordered list of data segments that will appear in the final binary.
/// When sorted, to-be-merged segments will be made adjacent.
/// Values are offset relative to segment start.
data_segments: std.AutoArrayHashMapUnmanaged(Wasm.DataSegment.Id, void) = .empty,

error_name_table_ref_count: u32 = 0,

/// Set to true if any `GLOBAL_INDEX` relocation is encountered with
/// `SymbolFlags.tls` set to true. This is for objects only; final
/// value must be this OR'd with the same logic for zig functions
/// (set to true if any threadlocal global is used).
any_tls_relocs: bool = false,

/// All MIR instructions for all Zcu functions.
mir_instructions: std.MultiArrayList(Mir.Inst) = .{},
/// Corresponds to `mir_instructions`.
mir_extra: std.ArrayListUnmanaged(u32) = .empty,
/// All local types for all Zcu functions.
all_zcu_locals: std.ArrayListUnmanaged(u8) = .empty,

params_scratch: std.ArrayListUnmanaged(std.wasm.Valtype) = .empty,
returns_scratch: std.ArrayListUnmanaged(std.wasm.Valtype) = .empty,

pub const UavFixup = extern struct {
    ip_index: InternPool.Index,
    /// Index into `string_bytes`.
    offset: u32,
};

pub const NavFixup = extern struct {
    nav_index: InternPool.Nav.Index,
    /// Index into `string_bytes`.
    offset: u32,
};

/// Index into `objects`.
pub const ObjectIndex = enum(u32) {
    _,

    pub fn ptr(index: ObjectIndex, wasm: *const Wasm) *Object {
        return &wasm.objects.items[@intFromEnum(index)];
    }
};

/// Index into `Wasm.functions`.
pub const FunctionIndex = enum(u32) {
    _,

    pub fn ptr(index: FunctionIndex, wasm: *const Wasm) *FunctionImport.Resolution {
        return &wasm.functions.keys()[@intFromEnum(index)];
    }

    pub fn fromIpNav(wasm: *const Wasm, nav_index: InternPool.Nav.Index) ?FunctionIndex {
        return fromResolution(wasm, .fromIpNav(wasm, nav_index));
    }

    pub fn fromTagNameType(wasm: *const Wasm, tag_type: InternPool.Index) ?FunctionIndex {
        const zcu_func: ZcuFunc.Index = @enumFromInt(wasm.zcu_funcs.getIndex(tag_type) orelse return null);
        return fromResolution(wasm, .pack(wasm, .{ .zcu_func = zcu_func }));
    }

    pub fn fromSymbolName(wasm: *const Wasm, name: String) ?FunctionIndex {
        const import = wasm.object_function_imports.getPtr(name) orelse return null;
        return fromResolution(wasm, import.resolution);
    }

    pub fn fromResolution(wasm: *const Wasm, resolution: FunctionImport.Resolution) ?FunctionIndex {
        const i = wasm.functions.getIndex(resolution) orelse return null;
        return @enumFromInt(i);
    }
};

pub const FunctionExport = extern struct {
    name: String,
    function_index: FunctionIndex,
};

pub const GlobalExport = extern struct {
    name: String,
    global_index: GlobalIndex,
};

/// 0. Index into `Flush.function_imports`
/// 1. Index into `functions`.
///
/// Note that function_imports indexes are subject to swap removals during
/// `flush`.
pub const OutputFunctionIndex = enum(u32) {
    _,

    pub fn fromFunctionIndex(wasm: *const Wasm, index: FunctionIndex) OutputFunctionIndex {
        return @enumFromInt(wasm.function_imports.entries.len + @intFromEnum(index));
    }

    pub fn fromIpNav(wasm: *const Wasm, nav_index: InternPool.Nav.Index) OutputFunctionIndex {
        const zcu = wasm.base.comp.zcu.?;
        const ip = &zcu.intern_pool;
        const nav = ip.getNav(nav_index);
        if (nav.toExtern(ip)) |ext| {
            const name = wasm.getExistingString(ext.name.toSlice(ip)).?;
            if (wasm.function_imports.getIndex(name)) |i| return @enumFromInt(i);
            return fromFunctionIndex(wasm, FunctionIndex.fromSymbolName(wasm, name).?);
        } else {
            return fromFunctionIndex(wasm, FunctionIndex.fromIpNav(wasm, nav_index).?);
        }
    }

    pub fn fromTagNameType(wasm: *const Wasm, tag_type: InternPool.Index) OutputFunctionIndex {
        return fromFunctionIndex(wasm, FunctionIndex.fromTagNameType(wasm, tag_type).?);
    }

    pub fn fromSymbolName(wasm: *const Wasm, name: String) OutputFunctionIndex {
        return fromFunctionIndex(wasm, FunctionIndex.fromSymbolName(wasm, name).?);
    }
};

/// Index into `Wasm.globals`.
pub const GlobalIndex = enum(u32) {
    _,

    /// This is only accurate when there is a Zcu.
    pub const stack_pointer: GlobalIndex = @enumFromInt(0);

    /// Same as `stack_pointer` but with a safety assertion.
    pub fn stackPointer(wasm: *const Wasm) Global.Index {
        const comp = wasm.base.comp;
        assert(comp.zcu != null);
        return .stack_pointer;
    }

    pub fn ptr(index: GlobalIndex, f: *const Flush) *Wasm.GlobalImport.Resolution {
        return &f.globals.items[@intFromEnum(index)];
    }

    pub fn fromIpNav(wasm: *const Wasm, nav_index: InternPool.Nav.Index) ?GlobalIndex {
        const i = wasm.globals.getIndex(.fromIpNav(wasm, nav_index)) orelse return null;
        return @enumFromInt(i);
    }
};

/// The first N indexes correspond to input objects (`objects`) array.
/// After that, the indexes correspond to the `source_locations` array,
/// representing a location in a Zig source file that can be pinpointed
/// precisely via AST node and token.
pub const SourceLocation = enum(u32) {
    /// From the Zig compilation unit but no precise source location.
    zig_object_nofile = std.math.maxInt(u32) - 1,
    none = std.math.maxInt(u32),
    _,

    /// Index into `source_locations`.
    pub const Index = enum(u32) {
        _,
    };

    pub const Unpacked = union(enum) {
        none,
        zig_object_nofile,
        object_index: ObjectIndex,
        source_location_index: Index,
    };

    pub fn pack(unpacked: Unpacked, wasm: *const Wasm) SourceLocation {
        _ = wasm;
        return switch (unpacked) {
            .zig_object_nofile => .zig_object_nofile,
            .none => .none,
            .object_index => |object_index| @enumFromInt(@intFromEnum(object_index)),
            .source_location_index => @panic("TODO"),
        };
    }

    pub fn unpack(sl: SourceLocation, wasm: *const Wasm) Unpacked {
        return switch (sl) {
            .zig_object_nofile => .zig_object_nofile,
            .none => .none,
            _ => {
                const i = @intFromEnum(sl);
                if (i < wasm.objects.items.len) return .{ .object_index = @enumFromInt(i) };
                const sl_index = i - wasm.objects.items.len;
                _ = sl_index;
                @panic("TODO");
            },
        };
    }

    pub fn fromObject(object_index: ObjectIndex, wasm: *const Wasm) SourceLocation {
        return pack(.{ .object_index = object_index }, wasm);
    }

    pub fn addError(sl: SourceLocation, wasm: *Wasm, comptime f: []const u8, args: anytype) void {
        const diags = &wasm.base.comp.link_diags;
        switch (sl.unpack(wasm)) {
            .none => unreachable,
            .zig_object_nofile => diags.addError("zig compilation unit: " ++ f, args),
            .object_index => |i| diags.addError("{}: " ++ f, .{i.ptr(wasm).path} ++ args),
            .source_location_index => @panic("TODO"),
        }
    }
};

/// The lower bits of this ABI-match the flags here:
/// https://github.com/WebAssembly/tool-conventions/blob/df8d737539eb8a8f446ba5eab9dc670c40dfb81e/Linking.md#symbol-table-subsection
/// The upper bits are used for nefarious purposes.
pub const SymbolFlags = packed struct(u32) {
    binding: Binding = .strong,
    /// Indicating that this is a hidden symbol. Hidden symbols are not to be
    /// exported when performing the final link, but may be linked to other
    /// modules.
    visibility_hidden: bool = false,
    padding0: u1 = 0,
    /// For non-data symbols, this must match whether the symbol is an import
    /// or is defined; for data symbols, determines whether a segment is
    /// specified.
    undefined: bool = false,
    /// The symbol is intended to be exported from the wasm module to the host
    /// environment. This differs from the visibility flags in that it affects
    /// static linking.
    exported: bool = false,
    /// The symbol uses an explicit symbol name, rather than reusing the name
    /// from a wasm import. This allows it to remap imports from foreign
    /// WebAssembly modules into local symbols with different names.
    explicit_name: bool = false,
    /// The symbol is intended to be included in the linker output, regardless
    /// of whether it is used by the program. Same meaning as `retain`.
    no_strip: bool = false,
    /// The symbol resides in thread local storage.
    tls: bool = false,
    /// The symbol represents an absolute address. This means its offset is
    /// relative to the start of the wasm memory as opposed to being relative
    /// to a data segment.
    absolute: bool = false,

    // Above here matches the tooling conventions ABI.

    padding1: u5 = 0,
    /// Zig-specific. Dead things are allowed to be garbage collected.
    alive: bool = false,
    /// Zig-specific. Segments only. Signals that the segment contains only
    /// null terminated strings allowing the linker to perform merging.
    strings: bool = false,
    /// Zig-specific. This symbol comes from an object that must be included in
    /// the final link.
    must_link: bool = false,
    /// Zig-specific. Data segments only.
    is_passive: bool = false,
    /// Zig-specific. Data segments only.
    alignment: Alignment = .none,
    /// Zig-specific. Globals only.
    global_type: GlobalType4 = .zero,
    /// Zig-specific. Tables only.
    limits_has_max: bool = false,
    /// Zig-specific. Tables only.
    limits_is_shared: bool = false,
    /// Zig-specific. Tables only.
    ref_type: RefType1 = .funcref,

    pub const Binding = enum(u2) {
        strong = 0,
        /// Indicating that this is a weak symbol. When linking multiple modules
        /// defining the same symbol, all weak definitions are discarded if any
        /// strong definitions exist; then if multiple weak definitions exist all
        /// but one (unspecified) are discarded; and finally it is an error if more
        /// than one definition remains.
        weak = 1,
        /// Indicating that this is a local symbol. Local symbols are not to be
        /// exported, or linked to other modules/sections. The names of all
        /// non-local symbols must be unique, but the names of local symbols
        /// are not considered for uniqueness. A local function or global
        /// symbol cannot reference an import.
        local = 2,
    };

    pub fn initZigSpecific(flags: *SymbolFlags, must_link: bool, no_strip: bool) void {
        flags.no_strip = no_strip;
        flags.alive = false;
        flags.strings = false;
        flags.must_link = must_link;
        flags.is_passive = false;
        flags.alignment = .none;
        flags.global_type = .zero;
        flags.limits_has_max = false;
        flags.limits_is_shared = false;
        flags.ref_type = .funcref;
    }

    pub fn isIncluded(flags: SymbolFlags, is_dynamic: bool) bool {
        return flags.exported or
            (is_dynamic and !flags.visibility_hidden) or
            (flags.no_strip and flags.must_link);
    }

    pub fn isExported(flags: SymbolFlags, is_dynamic: bool) bool {
        if (flags.undefined or flags.binding == .local) return false;
        if (is_dynamic and !flags.visibility_hidden) return true;
        return flags.exported;
    }

    /// Returns the name as how it will be output into the final object
    /// file or binary. When `merge` is true, this will return the
    /// short name. i.e. ".rodata". When false, it returns the entire name instead.
    pub fn outputName(flags: SymbolFlags, name: []const u8, merge: bool) []const u8 {
        if (flags.tls) return ".tdata";
        if (!merge) return name;
        if (mem.startsWith(u8, name, ".rodata.")) return ".rodata";
        if (mem.startsWith(u8, name, ".text.")) return ".text";
        if (mem.startsWith(u8, name, ".data.")) return ".data";
        if (mem.startsWith(u8, name, ".bss.")) return ".bss";
        return name;
    }

    /// Masks off the Zig-specific stuff.
    pub fn toAbiInteger(flags: SymbolFlags) u32 {
        var copy = flags;
        copy.initZigSpecific(false, false);
        return @bitCast(copy);
    }
};

pub const GlobalType4 = packed struct(u4) {
    valtype: Valtype3,
    mutable: bool,

    pub const zero: GlobalType4 = @bitCast(@as(u4, 0));

    pub fn to(gt: GlobalType4) Global.Type {
        return .{
            .valtype = gt.valtype.to(),
            .mutable = gt.mutable,
        };
    }
};

pub const Valtype3 = enum(u3) {
    i32,
    i64,
    f32,
    f64,
    v128,

    pub fn from(v: std.wasm.Valtype) Valtype3 {
        return switch (v) {
            .i32 => .i32,
            .i64 => .i64,
            .f32 => .f32,
            .f64 => .f64,
            .v128 => .v128,
        };
    }

    pub fn to(v: Valtype3) std.wasm.Valtype {
        return switch (v) {
            .i32 => .i32,
            .i64 => .i64,
            .f32 => .f32,
            .f64 => .f64,
            .v128 => .v128,
        };
    }
};

/// Index into `Wasm.navs_obj`.
pub const NavsObjIndex = enum(u32) {
    _,

    pub fn key(i: @This(), wasm: *const Wasm) *InternPool.Nav.Index {
        return &wasm.navs_obj.keys()[@intFromEnum(i)];
    }

    pub fn value(i: @This(), wasm: *const Wasm) *ZcuDataObj {
        return &wasm.navs_obj.values()[@intFromEnum(i)];
    }

    pub fn name(i: @This(), wasm: *const Wasm) [:0]const u8 {
        const zcu = wasm.base.comp.zcu.?;
        const ip = &zcu.intern_pool;
        const nav = ip.getNav(i.key(wasm).*);
        return nav.fqn.toSlice(ip);
    }
};

/// Index into `Wasm.navs_exe`.
pub const NavsExeIndex = enum(u32) {
    _,

    pub fn key(i: @This(), wasm: *const Wasm) *InternPool.Nav.Index {
        return &wasm.navs_exe.keys()[@intFromEnum(i)];
    }

    pub fn value(i: @This(), wasm: *const Wasm) *ZcuDataExe {
        return &wasm.navs_exe.values()[@intFromEnum(i)];
    }

    pub fn name(i: @This(), wasm: *const Wasm) [:0]const u8 {
        const zcu = wasm.base.comp.zcu.?;
        const ip = &zcu.intern_pool;
        const nav = ip.getNav(i.key(wasm).*);
        return nav.fqn.toSlice(ip);
    }
};

/// Index into `Wasm.uavs_obj`.
pub const UavsObjIndex = enum(u32) {
    _,

    pub fn key(i: @This(), wasm: *const Wasm) *InternPool.Index {
        return &wasm.uavs_obj.keys()[@intFromEnum(i)];
    }

    pub fn value(i: @This(), wasm: *const Wasm) *ZcuDataObj {
        return &wasm.uavs_obj.values()[@intFromEnum(i)];
    }
};

/// Index into `Wasm.uavs_exe`.
pub const UavsExeIndex = enum(u32) {
    _,

    pub fn key(i: @This(), wasm: *const Wasm) *InternPool.Index {
        return &wasm.uavs_exe.keys()[@intFromEnum(i)];
    }

    pub fn value(i: @This(), wasm: *const Wasm) *ZcuDataExe {
        return &wasm.uavs_exe.values()[@intFromEnum(i)];
    }
};

/// Used when emitting a relocatable object.
pub const ZcuDataObj = extern struct {
    code: DataSegment.Payload,
    relocs: OutReloc.Slice,
};

/// Used when not emitting a relocatable object.
pub const ZcuDataExe = extern struct {
    code: DataSegment.Payload,
    /// Tracks how many references there are for the purposes of sorting data segments.
    count: u32,
};

pub const ZcuFunc = extern struct {
    function: CodeGen.Function,

    /// Index into `Wasm.zcu_funcs`.
    /// Note that swapRemove is sometimes performed on `zcu_funcs`.
    pub const Index = enum(u32) {
        _,

        pub fn key(i: @This(), wasm: *const Wasm) *InternPool.Index {
            return &wasm.zcu_funcs.keys()[@intFromEnum(i)];
        }

        pub fn value(i: @This(), wasm: *const Wasm) *ZcuFunc {
            return &wasm.zcu_funcs.values()[@intFromEnum(i)];
        }

        pub fn name(i: @This(), wasm: *const Wasm) [:0]const u8 {
            const zcu = wasm.base.comp.zcu.?;
            const ip = &zcu.intern_pool;
            const func = ip.toFunc(i.key(wasm).*);
            const nav = ip.getNav(func.owner_nav);
            return nav.fqn.toSlice(ip);
        }

        pub fn typeIndex(i: @This(), wasm: *Wasm) ?FunctionType.Index {
            const comp = wasm.base.comp;
            const zcu = comp.zcu.?;
            const target = &comp.root_mod.resolved_target.result;
            const ip = &zcu.intern_pool;
            const func = ip.toFunc(i.key(wasm).*);
            const fn_ty = zcu.navValue(func.owner_nav).typeOf(zcu);
            const fn_info = zcu.typeToFunc(fn_ty).?;
            return wasm.getExistingFunctionType(fn_info.cc, fn_info.param_types.get(ip), .fromInterned(fn_info.return_type), target);
        }
    };
};

pub const NavExport = extern struct {
    name: String,
    nav_index: InternPool.Nav.Index,
};

pub const UavExport = extern struct {
    name: String,
    uav_index: InternPool.Index,
};

const DebugSections = struct {
    abbrev: DebugSection = .{},
    info: DebugSection = .{},
    line: DebugSection = .{},
    loc: DebugSection = .{},
    pubnames: DebugSection = .{},
    pubtypes: DebugSection = .{},
    ranges: DebugSection = .{},
    str: DebugSection = .{},
};

const DebugSection = struct {};

pub const FunctionImport = extern struct {
    flags: SymbolFlags,
    module_name: OptionalString,
    source_location: SourceLocation,
    resolution: Resolution,
    type: FunctionType.Index,

    /// Represents a synthetic function, a function from an object, or a
    /// function from the Zcu.
    pub const Resolution = enum(u32) {
        unresolved,
        __wasm_apply_global_tls_relocs,
        __wasm_call_ctors,
        __wasm_init_memory,
        __wasm_init_tls,
        __zig_error_names,
        // Next, index into `object_functions`.
        // Next, index into `zcu_funcs`.
        _,

        const first_object_function = @intFromEnum(Resolution.__zig_error_names) + 1;

        pub const Unpacked = union(enum) {
            unresolved,
            __wasm_apply_global_tls_relocs,
            __wasm_call_ctors,
            __wasm_init_memory,
            __wasm_init_tls,
            __zig_error_names,
            object_function: ObjectFunctionIndex,
            zcu_func: ZcuFunc.Index,
        };

        pub fn unpack(r: Resolution, wasm: *const Wasm) Unpacked {
            return switch (r) {
                .unresolved => .unresolved,
                .__wasm_apply_global_tls_relocs => .__wasm_apply_global_tls_relocs,
                .__wasm_call_ctors => .__wasm_call_ctors,
                .__wasm_init_memory => .__wasm_init_memory,
                .__wasm_init_tls => .__wasm_init_tls,
                .__zig_error_names => .__zig_error_names,
                _ => {
                    const object_function_index = @intFromEnum(r) - first_object_function;

                    const zcu_func_index = if (object_function_index < wasm.object_functions.items.len)
                        return .{ .object_function = @enumFromInt(object_function_index) }
                    else
                        object_function_index - wasm.object_functions.items.len;

                    return .{ .zcu_func = @enumFromInt(zcu_func_index) };
                },
            };
        }

        pub fn pack(wasm: *const Wasm, unpacked: Unpacked) Resolution {
            return switch (unpacked) {
                .unresolved => .unresolved,
                .__wasm_apply_global_tls_relocs => .__wasm_apply_global_tls_relocs,
                .__wasm_call_ctors => .__wasm_call_ctors,
                .__wasm_init_memory => .__wasm_init_memory,
                .__wasm_init_tls => .__wasm_init_tls,
                .__zig_error_names => .__zig_error_names,
                .object_function => |i| @enumFromInt(first_object_function + @intFromEnum(i)),
                .zcu_func => |i| @enumFromInt(first_object_function + wasm.object_functions.items.len + @intFromEnum(i)),
            };
        }

        pub fn fromIpNav(wasm: *const Wasm, nav_index: InternPool.Nav.Index) Resolution {
            const zcu = wasm.base.comp.zcu.?;
            const ip = &zcu.intern_pool;
            const nav = ip.getNav(nav_index);
            //log.debug("Resolution.fromIpNav {}({})", .{ nav.fqn.fmt(ip), nav_index });
            return pack(wasm, .{
                .zcu_func = @enumFromInt(wasm.zcu_funcs.getIndex(nav.status.resolved.val).?),
            });
        }

        pub fn isNavOrUnresolved(r: Resolution, wasm: *const Wasm) bool {
            return switch (r.unpack(wasm)) {
                .unresolved, .zcu_func => true,
                else => false,
            };
        }

        pub fn typeIndex(r: Resolution, wasm: *Wasm) FunctionType.Index {
            return switch (unpack(r, wasm)) {
                .unresolved => unreachable,
                .__wasm_apply_global_tls_relocs => @panic("TODO"),
                .__wasm_call_ctors => @panic("TODO"),
                .__wasm_init_memory => @panic("TODO"),
                .__wasm_init_tls => @panic("TODO"),
                .__zig_error_names => @panic("TODO"),
                .object_function => |i| i.ptr(wasm).type_index,
                .zcu_func => |i| i.typeIndex(wasm).?,
            };
        }

        pub fn name(r: Resolution, wasm: *const Wasm) ?[]const u8 {
            return switch (unpack(r, wasm)) {
                .unresolved => unreachable,
                .__wasm_apply_global_tls_relocs => @tagName(Unpacked.__wasm_apply_global_tls_relocs),
                .__wasm_call_ctors => @tagName(Unpacked.__wasm_call_ctors),
                .__wasm_init_memory => @tagName(Unpacked.__wasm_init_memory),
                .__wasm_init_tls => @tagName(Unpacked.__wasm_init_tls),
                .__zig_error_names => @tagName(Unpacked.__zig_error_names),
                .object_function => |i| i.ptr(wasm).name.slice(wasm),
                .zcu_func => |i| i.name(wasm),
            };
        }
    };

    /// Index into `object_function_imports`.
    pub const Index = enum(u32) {
        _,

        pub fn key(index: Index, wasm: *const Wasm) *String {
            return &wasm.object_function_imports.keys()[@intFromEnum(index)];
        }

        pub fn value(index: Index, wasm: *const Wasm) *FunctionImport {
            return &wasm.object_function_imports.values()[@intFromEnum(index)];
        }

        pub fn name(index: Index, wasm: *const Wasm) String {
            return index.key(wasm).*;
        }

        pub fn moduleName(index: Index, wasm: *const Wasm) OptionalString {
            return index.value(wasm).module_name;
        }

        pub fn functionType(index: Index, wasm: *const Wasm) FunctionType.Index {
            return value(index, wasm).type;
        }
    };
};

pub const Function = extern struct {
    flags: SymbolFlags,
    /// `none` if this function has no symbol describing it.
    name: OptionalString,
    type_index: FunctionType.Index,
    code: Code,
    /// The offset within the section where the data starts.
    offset: u32,
    section_index: ObjectSectionIndex,
    source_location: SourceLocation,

    pub const Code = DataSegment.Payload;
};

pub const GlobalImport = extern struct {
    flags: SymbolFlags,
    module_name: OptionalString,
    source_location: SourceLocation,
    resolution: Resolution,

    /// Represents a synthetic global, a global from an object, or a global
    /// from the Zcu.
    pub const Resolution = enum(u32) {
        unresolved,
        __heap_base,
        __heap_end,
        __stack_pointer,
        __tls_align,
        __tls_base,
        __tls_size,
        __zig_error_name_table,
        // Next, index into `object_globals`.
        // Next, index into `navs_obj` or `navs_exe` depending on whether emitting an object.
        _,

        const first_object_global = @intFromEnum(Resolution.__zig_error_name_table) + 1;

        pub const Unpacked = union(enum) {
            unresolved,
            __heap_base,
            __heap_end,
            __stack_pointer,
            __tls_align,
            __tls_base,
            __tls_size,
            __zig_error_name_table,
            object_global: ObjectGlobalIndex,
            nav_exe: NavsExeIndex,
            nav_obj: NavsObjIndex,
        };

        pub fn unpack(r: Resolution, wasm: *const Wasm) Unpacked {
            return switch (r) {
                .unresolved => .unresolved,
                .__heap_base => .__heap_base,
                .__heap_end => .__heap_end,
                .__stack_pointer => .__stack_pointer,
                .__tls_align => .__tls_align,
                .__tls_base => .__tls_base,
                .__tls_size => .__tls_size,
                .__zig_error_name_table => .__zig_error_name_table,
                _ => {
                    const i: u32 = @intFromEnum(r);
                    const object_global_index = i - first_object_global;
                    if (object_global_index < wasm.object_globals.items.len)
                        return .{ .object_global = @enumFromInt(object_global_index) };
                    const comp = wasm.base.comp;
                    const is_obj = comp.config.output_mode == .Obj;
                    const nav_index = object_global_index - wasm.object_globals.items.len;
                    return if (is_obj) .{
                        .nav_obj = @enumFromInt(nav_index),
                    } else .{
                        .nav_exe = @enumFromInt(nav_index),
                    };
                },
            };
        }

        pub fn pack(wasm: *const Wasm, unpacked: Unpacked) Resolution {
            return switch (unpacked) {
                .unresolved => .unresolved,
                .__heap_base => .__heap_base,
                .__heap_end => .__heap_end,
                .__stack_pointer => .__stack_pointer,
                .__tls_align => .__tls_align,
                .__tls_base => .__tls_base,
                .__tls_size => .__tls_size,
                .__zig_error_name_table => .__zig_error_name_table,
                .object_global => |i| @enumFromInt(first_object_global + @intFromEnum(i)),
                .nav_obj => |i| @enumFromInt(first_object_global + wasm.object_globals.items.len + @intFromEnum(i)),
                .nav_exe => |i| @enumFromInt(first_object_global + wasm.object_globals.items.len + @intFromEnum(i)),
            };
        }

        pub fn fromIpNav(wasm: *const Wasm, ip_nav: InternPool.Nav.Index) Resolution {
            const comp = wasm.base.comp;
            const is_obj = comp.config.output_mode == .Obj;
            return pack(wasm, if (is_obj) .{
                .nav_obj = @enumFromInt(wasm.navs_obj.getIndex(ip_nav).?),
            } else .{
                .nav_exe = @enumFromInt(wasm.navs_exe.getIndex(ip_nav).?),
            });
        }

        pub fn name(r: Resolution, wasm: *const Wasm) ?[]const u8 {
            return switch (unpack(r, wasm)) {
                .unresolved => unreachable,
                .__heap_base => @tagName(Unpacked.__heap_base),
                .__heap_end => @tagName(Unpacked.__heap_end),
                .__stack_pointer => @tagName(Unpacked.__stack_pointer),
                .__tls_align => @tagName(Unpacked.__tls_align),
                .__tls_base => @tagName(Unpacked.__tls_base),
                .__tls_size => @tagName(Unpacked.__tls_size),
                .__zig_error_name_table => @tagName(Unpacked.__zig_error_name_table),
                .object_global => |i| i.name(wasm).slice(wasm),
                .nav_obj => |i| i.name(wasm),
                .nav_exe => |i| i.name(wasm),
            };
        }
    };

    /// Index into `Wasm.object_global_imports`.
    pub const Index = enum(u32) {
        _,

        pub fn key(index: Index, wasm: *const Wasm) *String {
            return &wasm.object_global_imports.keys()[@intFromEnum(index)];
        }

        pub fn value(index: Index, wasm: *const Wasm) *GlobalImport {
            return &wasm.object_global_imports.values()[@intFromEnum(index)];
        }

        pub fn name(index: Index, wasm: *const Wasm) String {
            return index.key(wasm).*;
        }

        pub fn moduleName(index: Index, wasm: *const Wasm) OptionalString {
            return index.value(wasm).module_name;
        }

        pub fn globalType(index: Index, wasm: *const Wasm) Global.Type {
            return value(index, wasm).flags.global_type.to();
        }
    };
};

pub const Global = extern struct {
    /// `none` if this function has no symbol describing it.
    name: OptionalString,
    flags: SymbolFlags,
    expr: Expr,

    pub const Type = struct {
        valtype: std.wasm.Valtype,
        mutable: bool,
    };
};

pub const RefType1 = enum(u1) {
    funcref,
    externref,

    pub fn from(rt: std.wasm.RefType) RefType1 {
        return switch (rt) {
            .funcref => .funcref,
            .externref => .externref,
        };
    }

    pub fn to(rt: RefType1) std.wasm.RefType {
        return switch (rt) {
            .funcref => .funcref,
            .externref => .externref,
        };
    }
};

pub const TableImport = extern struct {
    flags: SymbolFlags,
    module_name: String,
    source_location: SourceLocation,
    resolution: Resolution,
    limits_min: u32,
    limits_max: u32,

    /// Represents a synthetic table, or a table from an object.
    pub const Resolution = enum(u32) {
        unresolved,
        __indirect_function_table,
        // Next, index into `object_tables`.
        _,

        const first_object_table = @intFromEnum(Resolution.__indirect_function_table) + 1;

        pub const Unpacked = union(enum) {
            unresolved,
            __indirect_function_table,
            object_table: ObjectTableIndex,
        };

        pub fn unpack(r: Resolution) Unpacked {
            return switch (r) {
                .unresolved => .unresolved,
                .__indirect_function_table => .__indirect_function_table,
                _ => .{ .object_table = @enumFromInt(@intFromEnum(r) - first_object_table) },
            };
        }

        pub fn refType(r: Resolution, wasm: *const Wasm) std.wasm.RefType {
            return switch (unpack(r)) {
                .unresolved => unreachable,
                .__indirect_function_table => @panic("TODO"),
                .object_table => |i| i.ptr(wasm).flags.ref_type.to(),
            };
        }

        pub fn limits(r: Resolution, wasm: *const Wasm) std.wasm.Limits {
            return switch (unpack(r)) {
                .unresolved => unreachable,
                .__indirect_function_table => @panic("TODO"),
                .object_table => |i| i.ptr(wasm).limits(),
            };
        }
    };

    /// Index into `object_table_imports`.
    pub const Index = enum(u32) {
        _,

        pub fn key(index: Index, wasm: *const Wasm) *String {
            return &wasm.object_table_imports.keys()[@intFromEnum(index)];
        }

        pub fn value(index: Index, wasm: *const Wasm) *TableImport {
            return &wasm.object_table_imports.values()[@intFromEnum(index)];
        }

        pub fn name(index: Index, wasm: *const Wasm) String {
            return index.key(wasm).*;
        }

        pub fn moduleName(index: Index, wasm: *const Wasm) OptionalString {
            return index.value(wasm).module_name;
        }
    };

    pub fn limits(ti: *const TableImport) std.wasm.Limits {
        return .{
            .flags = .{
                .has_max = ti.flags.limits_has_max,
                .is_shared = ti.flags.limits_is_shared,
            },
            .min = ti.limits_min,
            .max = ti.limits_max,
        };
    }
};

pub const Table = extern struct {
    module_name: OptionalString,
    name: OptionalString,
    flags: SymbolFlags,
    limits_min: u32,
    limits_max: u32,

    pub fn limits(t: *const Table) std.wasm.Limits {
        return .{
            .flags = .{
                .has_max = t.flags.limits_has_max,
                .is_shared = t.flags.limits_is_shared,
            },
            .min = t.limits_min,
            .max = t.limits_max,
        };
    }
};

/// Uniquely identifies a section across all objects. By subtracting
/// `Object.local_section_index_base` from this one, the Object section index
/// is obtained.
pub const ObjectSectionIndex = enum(u32) {
    _,
};

/// Index into `object_tables`.
pub const ObjectTableIndex = enum(u32) {
    _,

    pub fn ptr(index: ObjectTableIndex, wasm: *const Wasm) *Table {
        return &wasm.object_tables.items[@intFromEnum(index)];
    }
};

/// Index into `Wasm.object_globals`.
pub const ObjectGlobalIndex = enum(u32) {
    _,

    pub fn ptr(index: ObjectGlobalIndex, wasm: *const Wasm) *Global {
        return &wasm.object_globals.items[@intFromEnum(index)];
    }

    pub fn name(index: ObjectGlobalIndex, wasm: *const Wasm) OptionalString {
        return index.ptr(wasm).name;
    }
};

/// Index into `Wasm.object_memories`.
pub const ObjectMemoryIndex = enum(u32) {
    _,

    pub fn ptr(index: ObjectMemoryIndex, wasm: *const Wasm) *std.wasm.Memory {
        return &wasm.object_memories.items[@intFromEnum(index)];
    }
};

/// Index into `Wasm.object_functions`.
pub const ObjectFunctionIndex = enum(u32) {
    _,

    pub fn ptr(index: ObjectFunctionIndex, wasm: *const Wasm) *Function {
        return &wasm.object_functions.items[@intFromEnum(index)];
    }

    pub fn toOptional(i: ObjectFunctionIndex) OptionalObjectFunctionIndex {
        const result: OptionalObjectFunctionIndex = @enumFromInt(@intFromEnum(i));
        assert(result != .none);
        return result;
    }
};

/// Index into `object_functions`, or null.
pub const OptionalObjectFunctionIndex = enum(u32) {
    none = std.math.maxInt(u32),
    _,

    pub fn unwrap(i: OptionalObjectFunctionIndex) ?ObjectFunctionIndex {
        if (i == .none) return null;
        return @enumFromInt(@intFromEnum(i));
    }
};

pub const DataSegment = extern struct {
    /// `none` if no symbol describes it.
    name: OptionalString,
    flags: SymbolFlags,
    payload: Payload,
    /// From the data segment start to the first byte of payload.
    segment_offset: u32,
    section_index: ObjectSectionIndex,

    pub const Category = enum {
        /// Thread-local variables.
        tls,
        /// Data that is not zero initialized and not threadlocal.
        data,
        /// Zero-initialized. Does not require corresponding bytes in the
        /// output file.
        zero,
    };

    pub const Payload = extern struct {
        off: Off,
        /// The size in bytes of the data representing the segment within the section.
        len: u32,

        pub const Off = enum(u32) {
            /// The payload is all zeroes (bss section).
            none = std.math.maxInt(u32),
            /// Points into string_bytes. No corresponding string_table entry.
            _,

            pub fn unwrap(off: Off) ?u32 {
                return if (off == .none) null else @intFromEnum(off);
            }
        };

        pub fn slice(p: DataSegment.Payload, wasm: *const Wasm) []const u8 {
            return wasm.string_bytes.items[p.off.unwrap().?..][0..p.len];
        }
    };

    pub const Id = enum(u32) {
        __zig_error_name_table,
        /// First, an `ObjectDataSegmentIndex`.
        /// Next, index into `uavs_obj` or `uavs_exe` depending on whether emitting an object.
        /// Next, index into `navs_obj` or `navs_exe` depending on whether emitting an object.
        _,

        const first_object = @intFromEnum(Id.__zig_error_name_table) + 1;

        pub const Unpacked = union(enum) {
            __zig_error_name_table,
            object: ObjectDataSegmentIndex,
            uav_exe: UavsExeIndex,
            uav_obj: UavsObjIndex,
            nav_exe: NavsExeIndex,
            nav_obj: NavsObjIndex,
        };

        pub fn pack(wasm: *const Wasm, unpacked: Unpacked) Id {
            return switch (unpacked) {
                .__zig_error_name_table => .__zig_error_name_table,
                .object => |i| @enumFromInt(first_object + @intFromEnum(i)),
                inline .uav_exe, .uav_obj => |i| @enumFromInt(first_object + wasm.object_data_segments.items.len + @intFromEnum(i)),
                .nav_exe => |i| @enumFromInt(first_object + wasm.object_data_segments.items.len + wasm.uavs_exe.entries.len + @intFromEnum(i)),
                .nav_obj => |i| @enumFromInt(first_object + wasm.object_data_segments.items.len + wasm.uavs_obj.entries.len + @intFromEnum(i)),
            };
        }

        pub fn unpack(id: Id, wasm: *const Wasm) Unpacked {
            return switch (id) {
                .__zig_error_name_table => .__zig_error_name_table,
                _ => {
                    const object_index = @intFromEnum(id) - first_object;

                    const uav_index = if (object_index < wasm.object_data_segments.items.len)
                        return .{ .object = @enumFromInt(object_index) }
                    else
                        object_index - wasm.object_data_segments.items.len;

                    const comp = wasm.base.comp;
                    const is_obj = comp.config.output_mode == .Obj;
                    if (is_obj) {
                        const nav_index = if (uav_index < wasm.uavs_obj.entries.len)
                            return .{ .uav_obj = @enumFromInt(uav_index) }
                        else
                            uav_index - wasm.uavs_obj.entries.len;

                        return .{ .nav_obj = @enumFromInt(nav_index) };
                    } else {
                        const nav_index = if (uav_index < wasm.uavs_exe.entries.len)
                            return .{ .uav_exe = @enumFromInt(uav_index) }
                        else
                            uav_index - wasm.uavs_exe.entries.len;

                        return .{ .nav_exe = @enumFromInt(nav_index) };
                    }
                },
            };
        }

        pub fn category(id: Id, wasm: *const Wasm) Category {
            return switch (unpack(id, wasm)) {
                .__zig_error_name_table => .data,
                .object => |i| {
                    const ptr = i.ptr(wasm);
                    if (ptr.flags.tls) return .tls;
                    if (wasm.isBss(ptr.name)) return .zero;
                    return .data;
                },
                inline .uav_exe, .uav_obj => |i| if (i.value(wasm).code.off == .none) .zero else .data,
                inline .nav_exe, .nav_obj => |i| {
                    const zcu = wasm.base.comp.zcu.?;
                    const ip = &zcu.intern_pool;
                    const nav = ip.getNav(i.key(wasm).*);
                    if (nav.isThreadLocal(ip)) return .tls;
                    const code = i.value(wasm).code;
                    return if (code.off == .none) .zero else .data;
                },
            };
        }

        pub fn isTls(id: Id, wasm: *const Wasm) bool {
            return switch (unpack(id, wasm)) {
                .__zig_error_name_table => false,
                .object => |i| i.ptr(wasm).flags.tls,
                .uav_exe, .uav_obj => false,
                inline .nav_exe, .nav_obj => |i| {
                    const zcu = wasm.base.comp.zcu.?;
                    const ip = &zcu.intern_pool;
                    const nav = ip.getNav(i.key(wasm).*);
                    return nav.isThreadLocal(ip);
                },
            };
        }

        pub fn isBss(id: Id, wasm: *const Wasm) bool {
            return id.category(wasm) == .zero;
        }

        pub fn name(id: Id, wasm: *const Wasm) []const u8 {
            return switch (unpack(id, wasm)) {
                .__zig_error_name_table, .uav_exe, .uav_obj => ".data",
                .object => |i| i.ptr(wasm).name.unwrap().?.slice(wasm),
                inline .nav_exe, .nav_obj => |i| {
                    const zcu = wasm.base.comp.zcu.?;
                    const ip = &zcu.intern_pool;
                    const nav = ip.getNav(i.key(wasm).*);
                    return nav.status.resolved.@"linksection".toSlice(ip) orelse ".data";
                },
            };
        }

        pub fn alignment(id: Id, wasm: *const Wasm) Alignment {
            return switch (unpack(id, wasm)) {
                .__zig_error_name_table => wasm.pointerAlignment(),
                .object => |i| i.ptr(wasm).flags.alignment,
                inline .uav_exe, .uav_obj => |i| {
                    const zcu = wasm.base.comp.zcu.?;
                    const ip = &zcu.intern_pool;
                    const ip_index = i.key(wasm).*;
                    const ty: ZcuType = .fromInterned(ip.typeOf(ip_index));
                    const result = ty.abiAlignment(zcu);
                    assert(result != .none);
                    return result;
                },
                inline .nav_exe, .nav_obj => |i| {
                    const zcu = wasm.base.comp.zcu.?;
                    const ip = &zcu.intern_pool;
                    const nav = ip.getNav(i.key(wasm).*);
                    const explicit = nav.status.resolved.alignment;
                    if (explicit != .none) return explicit;
                    const ty: ZcuType = .fromInterned(nav.typeOf(ip));
                    const result = ty.abiAlignment(zcu);
                    assert(result != .none);
                    return result;
                },
            };
        }

        pub fn refCount(id: Id, wasm: *const Wasm) u32 {
            return switch (unpack(id, wasm)) {
                .__zig_error_name_table => wasm.error_name_table_ref_count,
                .object, .uav_obj, .nav_obj => 0,
                inline .uav_exe, .nav_exe => |i| i.value(wasm).count,
            };
        }

        pub fn isPassive(id: Id, wasm: *const Wasm) bool {
            if (wasm.base.comp.config.import_memory and !id.isBss(wasm)) return true;
            return switch (unpack(id, wasm)) {
                .__zig_error_name_table => false,
                .object => |i| i.ptr(wasm).flags.is_passive,
                .uav_exe, .uav_obj, .nav_exe, .nav_obj => false,
            };
        }

        pub fn isEmpty(id: Id, wasm: *const Wasm) bool {
            return switch (unpack(id, wasm)) {
                .__zig_error_name_table => false,
                .object => |i| i.ptr(wasm).payload.off == .none,
                inline .uav_exe, .uav_obj, .nav_exe, .nav_obj => |i| i.value(wasm).code.off == .none,
            };
        }

        pub fn size(id: Id, wasm: *const Wasm) u32 {
            return switch (unpack(id, wasm)) {
                .__zig_error_name_table => {
                    const comp = wasm.base.comp;
                    const zcu = comp.zcu.?;
                    const errors_len = 1 + zcu.intern_pool.global_error_set.getNamesFromMainThread().len;
                    const elem_size = ZcuType.slice_const_u8_sentinel_0.abiSize(zcu);
                    return @intCast(errors_len * elem_size);
                },
                .object => |i| i.ptr(wasm).payload.len,
                inline .uav_exe, .uav_obj, .nav_exe, .nav_obj => |i| i.value(wasm).code.len,
            };
        }
    };
};

/// Index into `Wasm.object_data_segments`.
pub const ObjectDataSegmentIndex = enum(u32) {
    _,

    pub fn ptr(i: ObjectDataSegmentIndex, wasm: *const Wasm) *DataSegment {
        return &wasm.object_data_segments.items[@intFromEnum(i)];
    }
};

/// Index into `Wasm.uavs`.
pub const UavIndex = enum(u32) {
    _,
};

pub const CustomSegment = extern struct {
    payload: Payload,
    flags: SymbolFlags,
    section_name: String,

    pub const Payload = DataSegment.Payload;
};

/// An index into string_bytes where a wasm expression is found.
pub const Expr = enum(u32) {
    _,

    pub const end = @intFromEnum(std.wasm.Opcode.end);

    pub fn slice(index: Expr, wasm: *const Wasm) [:end]const u8 {
        const start_slice = wasm.string_bytes.items[@intFromEnum(index)..];
        const end_pos = Object.exprEndPos(start_slice, 0) catch |err| switch (err) {
            error.InvalidInitOpcode => unreachable,
        };
        return start_slice[0..end_pos :end];
    }
};

pub const FunctionType = extern struct {
    params: ValtypeList,
    returns: ValtypeList,

    /// Index into func_types
    pub const Index = enum(u32) {
        _,

        pub fn ptr(i: FunctionType.Index, wasm: *const Wasm) *FunctionType {
            return &wasm.func_types.keys()[@intFromEnum(i)];
        }
    };

    pub const format = @compileError("can't format without *Wasm reference");

    pub fn eql(a: FunctionType, b: FunctionType) bool {
        return a.params == b.params and a.returns == b.returns;
    }
};

/// Represents a function entry, holding the index to its type
pub const Func = extern struct {
    type_index: FunctionType.Index,
};

/// Type reflection is used on the field names to autopopulate each field
/// during initialization.
const PreloadedStrings = struct {
    __heap_base: String,
    __heap_end: String,
    __indirect_function_table: String,
    __linear_memory: String,
    __stack_pointer: String,
    __tls_align: String,
    __tls_base: String,
    __tls_size: String,
    __wasm_apply_global_tls_relocs: String,
    __wasm_call_ctors: String,
    __wasm_init_memory: String,
    __wasm_init_memory_flag: String,
    __wasm_init_tls: String,
    __zig_error_name_table: String,
    __zig_error_names: String,
    __zig_errors_len: String,
    _initialize: String,
    _start: String,
    memory: String,
};

/// Index into string_bytes
pub const String = enum(u32) {
    _,

    const Table = std.HashMapUnmanaged(String, void, TableContext, std.hash_map.default_max_load_percentage);

    const TableContext = struct {
        bytes: []const u8,

        pub fn eql(_: @This(), a: String, b: String) bool {
            return a == b;
        }

        pub fn hash(ctx: @This(), key: String) u64 {
            return std.hash_map.hashString(mem.sliceTo(ctx.bytes[@intFromEnum(key)..], 0));
        }
    };

    const TableIndexAdapter = struct {
        bytes: []const u8,

        pub fn eql(ctx: @This(), a: []const u8, b: String) bool {
            return mem.eql(u8, a, mem.sliceTo(ctx.bytes[@intFromEnum(b)..], 0));
        }

        pub fn hash(_: @This(), adapted_key: []const u8) u64 {
            assert(mem.indexOfScalar(u8, adapted_key, 0) == null);
            return std.hash_map.hashString(adapted_key);
        }
    };

    pub fn slice(index: String, wasm: *const Wasm) [:0]const u8 {
        const start_slice = wasm.string_bytes.items[@intFromEnum(index)..];
        return start_slice[0..mem.indexOfScalar(u8, start_slice, 0).? :0];
    }

    pub fn toOptional(i: String) OptionalString {
        const result: OptionalString = @enumFromInt(@intFromEnum(i));
        assert(result != .none);
        return result;
    }
};

pub const OptionalString = enum(u32) {
    none = std.math.maxInt(u32),
    _,

    pub fn unwrap(i: OptionalString) ?String {
        if (i == .none) return null;
        return @enumFromInt(@intFromEnum(i));
    }

    pub fn slice(index: OptionalString, wasm: *const Wasm) ?[:0]const u8 {
        return (index.unwrap() orelse return null).slice(wasm);
    }
};

/// Stored identically to `String`. The bytes are reinterpreted as
/// `std.wasm.Valtype` elements.
pub const ValtypeList = enum(u32) {
    _,

    pub fn fromString(s: String) ValtypeList {
        return @enumFromInt(@intFromEnum(s));
    }

    pub fn slice(index: ValtypeList, wasm: *const Wasm) []const std.wasm.Valtype {
        return @ptrCast(String.slice(@enumFromInt(@intFromEnum(index)), wasm));
    }
};

/// Index into `Wasm.imports`.
pub const ZcuImportIndex = enum(u32) {
    _,

    pub fn ptr(index: ZcuImportIndex, wasm: *const Wasm) *InternPool.Nav.Index {
        return &wasm.imports.keys()[@intFromEnum(index)];
    }

    pub fn name(index: ZcuImportIndex, wasm: *const Wasm) String {
        const zcu = wasm.base.comp.zcu.?;
        const ip = &zcu.intern_pool;
        const nav_index = index.ptr(wasm).*;
        const nav = ip.getNav(nav_index);
        const ext = switch (ip.indexToKey(nav.status.resolved.val)) {
            .@"extern" => |*ext| ext,
            else => unreachable,
        };
        const name_slice = ext.name.toSlice(ip);
        return wasm.getExistingString(name_slice).?;
    }

    pub fn moduleName(index: ZcuImportIndex, wasm: *const Wasm) OptionalString {
        const zcu = wasm.base.comp.zcu.?;
        const ip = &zcu.intern_pool;
        const nav_index = index.ptr(wasm).*;
        const nav = ip.getNav(nav_index);
        const ext = switch (ip.indexToKey(nav.status.resolved.val)) {
            .@"extern" => |*ext| ext,
            else => unreachable,
        };
        const lib_name = ext.lib_name.toSlice(ip) orelse return .none;
        return wasm.getExistingString(lib_name).?.toOptional();
    }

    pub fn functionType(index: ZcuImportIndex, wasm: *Wasm) FunctionType.Index {
        const comp = wasm.base.comp;
        const target = &comp.root_mod.resolved_target.result;
        const zcu = comp.zcu.?;
        const ip = &zcu.intern_pool;
        const nav_index = index.ptr(wasm).*;
        const nav = ip.getNav(nav_index);
        const ext = switch (ip.indexToKey(nav.status.resolved.val)) {
            .@"extern" => |*ext| ext,
            else => unreachable,
        };
        const fn_info = zcu.typeToFunc(.fromInterned(ext.ty)).?;
        return getExistingFunctionType(wasm, fn_info.cc, fn_info.param_types.get(ip), .fromInterned(fn_info.return_type), target).?;
    }

    pub fn globalType(index: ZcuImportIndex, wasm: *const Wasm) Global.Type {
        _ = index;
        _ = wasm;
        unreachable; // Zig has no way to create Wasm globals yet.
    }
};

/// 0. Index into `Wasm.object_function_imports`.
/// 1. Index into `Wasm.imports`.
pub const FunctionImportId = enum(u32) {
    _,

    pub const Unpacked = union(enum) {
        object_function_import: FunctionImport.Index,
        zcu_import: ZcuImportIndex,
    };

    pub fn pack(unpacked: Unpacked, wasm: *const Wasm) FunctionImportId {
        return switch (unpacked) {
            .object_function_import => |i| @enumFromInt(@intFromEnum(i)),
            .zcu_import => |i| @enumFromInt(@intFromEnum(i) - wasm.object_function_imports.entries.len),
        };
    }

    pub fn unpack(id: FunctionImportId, wasm: *const Wasm) Unpacked {
        const i = @intFromEnum(id);
        if (i < wasm.object_function_imports.entries.len) return .{ .object_function_import = @enumFromInt(i) };
        const zcu_import_i = i - wasm.object_function_imports.entries.len;
        return .{ .zcu_import = @enumFromInt(zcu_import_i) };
    }

    pub fn fromObject(function_import_index: FunctionImport.Index, wasm: *const Wasm) FunctionImportId {
        return pack(.{ .object_function_import = function_import_index }, wasm);
    }

    pub fn fromZcuImport(zcu_import: ZcuImportIndex, wasm: *const Wasm) FunctionImportId {
        return pack(.{ .zcu_import = zcu_import }, wasm);
    }

    /// This function is allowed O(N) lookup because it is only called during
    /// diagnostic generation.
    pub fn sourceLocation(id: FunctionImportId, wasm: *const Wasm) SourceLocation {
        switch (id.unpack(wasm)) {
            .object_function_import => |obj_func_index| {
                // TODO binary search
                for (wasm.objects.items, 0..) |o, i| {
                    if (o.function_imports.off <= @intFromEnum(obj_func_index) and
                        o.function_imports.off + o.function_imports.len > @intFromEnum(obj_func_index))
                    {
                        return .pack(.{ .object_index = @enumFromInt(i) }, wasm);
                    }
                } else unreachable;
            },
            .zcu_import => return .zig_object_nofile, // TODO give a better source location
        }
    }

    pub fn name(id: FunctionImportId, wasm: *const Wasm) String {
        return switch (unpack(id, wasm)) {
            inline .object_function_import, .zcu_import => |i| i.name(wasm),
        };
    }

    pub fn moduleName(id: FunctionImportId, wasm: *const Wasm) OptionalString {
        return switch (unpack(id, wasm)) {
            inline .object_function_import, .zcu_import => |i| i.moduleName(wasm),
        };
    }

    pub fn functionType(id: FunctionImportId, wasm: *Wasm) FunctionType.Index {
        return switch (unpack(id, wasm)) {
            inline .object_function_import, .zcu_import => |i| i.functionType(wasm),
        };
    }

    /// Asserts not emitting an object, and `Wasm.import_symbols` is false.
    pub fn undefinedAllowed(id: FunctionImportId, wasm: *const Wasm) bool {
        assert(!wasm.import_symbols);
        assert(wasm.base.comp.config.output_mode != .Obj);
        return switch (unpack(id, wasm)) {
            .object_function_import => |i| {
                const import = i.value(wasm);
                return import.flags.binding == .strong and import.module_name != .none;
            },
            .zcu_import => |i| {
                const zcu = wasm.base.comp.zcu.?;
                const ip = &zcu.intern_pool;
                const ext = ip.getNav(i.ptr(wasm).*).toExtern(ip).?;
                return !ext.is_weak_linkage and ext.lib_name != .none;
            },
        };
    }
};

/// 0. Index into `object_global_imports`.
/// 1. Index into `imports`.
pub const GlobalImportId = enum(u32) {
    _,

    pub const Unpacked = union(enum) {
        object_global_import: GlobalImport.Index,
        zcu_import: ZcuImportIndex,
    };

    pub fn pack(unpacked: Unpacked, wasm: *const Wasm) GlobalImportId {
        return switch (unpacked) {
            .object_global_import => |i| @enumFromInt(@intFromEnum(i)),
            .zcu_import => |i| @enumFromInt(@intFromEnum(i) - wasm.object_global_imports.entries.len),
        };
    }

    pub fn unpack(id: GlobalImportId, wasm: *const Wasm) Unpacked {
        const i = @intFromEnum(id);
        if (i < wasm.object_global_imports.entries.len) return .{ .object_global_import = @enumFromInt(i) };
        const zcu_import_i = i - wasm.object_global_imports.entries.len;
        return .{ .zcu_import = @enumFromInt(zcu_import_i) };
    }

    pub fn fromObject(object_global_import: GlobalImport.Index, wasm: *const Wasm) GlobalImportId {
        return pack(.{ .object_global_import = object_global_import }, wasm);
    }

    /// This function is allowed O(N) lookup because it is only called during
    /// diagnostic generation.
    pub fn sourceLocation(id: GlobalImportId, wasm: *const Wasm) SourceLocation {
        switch (id.unpack(wasm)) {
            .object_global_import => |obj_global_index| {
                // TODO binary search
                for (wasm.objects.items, 0..) |o, i| {
                    if (o.global_imports.off <= @intFromEnum(obj_global_index) and
                        o.global_imports.off + o.global_imports.len > @intFromEnum(obj_global_index))
                    {
                        return .pack(.{ .object_index = @enumFromInt(i) }, wasm);
                    }
                } else unreachable;
            },
            .zcu_import => return .zig_object_nofile, // TODO give a better source location
        }
    }

    pub fn name(id: GlobalImportId, wasm: *const Wasm) String {
        return switch (unpack(id, wasm)) {
            inline .object_global_import, .zcu_import => |i| i.name(wasm),
        };
    }

    pub fn moduleName(id: GlobalImportId, wasm: *const Wasm) OptionalString {
        return switch (unpack(id, wasm)) {
            inline .object_global_import, .zcu_import => |i| i.moduleName(wasm),
        };
    }

    pub fn globalType(id: GlobalImportId, wasm: *Wasm) Global.Type {
        return switch (unpack(id, wasm)) {
            inline .object_global_import, .zcu_import => |i| i.globalType(wasm),
        };
    }
};

/// Index into `Wasm.symbol_table`.
pub const SymbolTableIndex = enum(u32) {
    _,

    pub fn key(i: @This(), wasm: *const Wasm) *String {
        return &wasm.symbol_table.keys()[@intFromEnum(i)];
    }
};

pub const OutReloc = struct {
    tag: ObjectRelocation.Tag,
    offset: u32,
    pointee: Pointee,
    addend: i32,

    pub const Pointee = union {
        symbol_index: SymbolTableIndex,
        type_index: FunctionType.Index,
    };

    pub const Slice = extern struct {
        /// Index into `out_relocs`.
        off: u32,
        len: u32,

        pub fn slice(s: Slice, wasm: *const Wasm) []OutReloc {
            return wasm.relocations.items[s.off..][0..s.len];
        }
    };
};

pub const ObjectRelocation = struct {
    tag: Tag,
    /// Offset of the value to rewrite relative to the relevant section's contents.
    /// When `offset` is zero, its position is immediately after the id and size of the section.
    offset: u32,
    pointee: Pointee,
    /// Populated only for `MEMORY_ADDR_*`, `FUNCTION_OFFSET_I32` and `SECTION_OFFSET_I32`.
    addend: i32,

    pub const Pointee = union {
        symbol_name: String,
        type_index: FunctionType.Index,
        section: ObjectSectionIndex,
    };

    pub const Slice = extern struct {
        /// Index into `relocations`.
        off: u32,
        len: u32,

        pub fn slice(s: Slice, wasm: *const Wasm) []ObjectRelocation {
            return wasm.relocations.items[s.off..][0..s.len];
        }
    };

    pub const Tag = enum(u8) {
        /// Uses `symbol_name`.
        FUNCTION_INDEX_LEB = 0,
        /// Uses `table_index`.
        TABLE_INDEX_SLEB = 1,
        /// Uses `table_index`.
        TABLE_INDEX_I32 = 2,
        MEMORY_ADDR_LEB = 3,
        MEMORY_ADDR_SLEB = 4,
        MEMORY_ADDR_I32 = 5,
        /// Uses `type_index`.
        TYPE_INDEX_LEB = 6,
        /// Uses `symbol_name`.
        GLOBAL_INDEX_LEB = 7,
        FUNCTION_OFFSET_I32 = 8,
        SECTION_OFFSET_I32 = 9,
        TAG_INDEX_LEB = 10,
        MEMORY_ADDR_REL_SLEB = 11,
        TABLE_INDEX_REL_SLEB = 12,
        /// Uses `symbol_name`.
        GLOBAL_INDEX_I32 = 13,
        MEMORY_ADDR_LEB64 = 14,
        MEMORY_ADDR_SLEB64 = 15,
        MEMORY_ADDR_I64 = 16,
        MEMORY_ADDR_REL_SLEB64 = 17,
        /// Uses `table_index`.
        TABLE_INDEX_SLEB64 = 18,
        /// Uses `table_index`.
        TABLE_INDEX_I64 = 19,
        TABLE_NUMBER_LEB = 20,
        MEMORY_ADDR_TLS_SLEB = 21,
        FUNCTION_OFFSET_I64 = 22,
        MEMORY_ADDR_LOCREL_I32 = 23,
        TABLE_INDEX_REL_SLEB64 = 24,
        MEMORY_ADDR_TLS_SLEB64 = 25,
        /// Uses `symbol_name`.
        FUNCTION_INDEX_I32 = 26,

        // Above here, the tags correspond to symbol table ABI described in
        // https://github.com/WebAssembly/tool-conventions/blob/main/Linking.md
        // Below, the tags are compiler-internal.
    };
};

pub const MemoryImport = extern struct {
    module_name: String,
    name: String,
    limits_min: u32,
    limits_max: u32,
    limits_has_max: bool,
    limits_is_shared: bool,
    padding: [2]u8 = .{ 0, 0 },

    pub fn limits(mi: *const MemoryImport) std.wasm.Limits {
        return .{
            .flags = .{
                .has_max = mi.limits_has_max,
                .is_shared = mi.limits_is_shared,
            },
            .min = mi.limits_min,
            .max = mi.limits_max,
        };
    }
};

pub const Alignment = InternPool.Alignment;

pub const InitFunc = extern struct {
    priority: u32,
    function_index: ObjectFunctionIndex,

    pub fn lessThan(ctx: void, lhs: InitFunc, rhs: InitFunc) bool {
        _ = ctx;
        if (lhs.priority == rhs.priority) {
            return @intFromEnum(lhs.function_index) < @intFromEnum(rhs.function_index);
        } else {
            return lhs.priority < rhs.priority;
        }
    }
};

pub const Comdat = struct {
    name: String,
    /// Must be zero, no flags are currently defined by the tool-convention.
    flags: u32,
    symbols: Comdat.Symbol.Slice,

    pub const Symbol = struct {
        kind: Comdat.Symbol.Type,
        /// Index of the data segment/function/global/event/table within a WASM module.
        /// The object must not be an import.
        index: u32,

        pub const Slice = struct {
            /// Index into Wasm object_comdat_symbols
            off: u32,
            len: u32,
        };

        pub const Type = enum(u8) {
            data = 0,
            function = 1,
            global = 2,
            event = 3,
            table = 4,
            section = 5,
        };
    };
};

/// Stored as a u8 so it can reuse the string table mechanism.
pub const Feature = packed struct(u8) {
    prefix: Prefix,
    /// Type of the feature, must be unique in the sequence of features.
    tag: Tag,

    /// Stored identically to `String`. The bytes are reinterpreted as `Feature`
    /// elements. Elements must be sorted before string-interning.
    pub const Set = enum(u32) {
        _,

        pub fn fromString(s: String) Set {
            return @enumFromInt(@intFromEnum(s));
        }
    };

    /// Unlike `std.Target.wasm.Feature` this also contains linker-features such as shared-mem.
    /// Additionally the name uses convention matching the wasm binary format.
    pub const Tag = enum(u6) {
        atomics,
        @"bulk-memory",
        @"exception-handling",
        @"extended-const",
        @"half-precision",
        multimemory,
        multivalue,
        @"mutable-globals",
        @"nontrapping-fptoint",
        @"reference-types",
        @"relaxed-simd",
        @"sign-ext",
        simd128,
        @"tail-call",
        @"shared-mem",

        pub fn fromCpuFeature(feature: std.Target.wasm.Feature) Tag {
            return @enumFromInt(@intFromEnum(feature));
        }

        pub const format = @compileError("use @tagName instead");
    };

    /// Provides information about the usage of the feature.
    pub const Prefix = enum(u2) {
        /// Reserved so that a 0-byte Feature is invalid and therefore can be a sentinel.
        invalid,
        /// '0x2b': Object uses this feature, and the link fails if feature is
        /// not in the allowed set.
        @"+",
        /// '0x2d': Object does not use this feature, and the link fails if
        /// this feature is in the allowed set.
        @"-",
        /// '0x3d': Object uses this feature, and the link fails if this
        /// feature is not in the allowed set, or if any object does not use
        /// this feature.
        @"=",
    };

    pub fn format(feature: Feature, comptime fmt: []const u8, opt: std.fmt.FormatOptions, writer: anytype) !void {
        _ = opt;
        _ = fmt;
        try writer.print("{s} {s}", .{ @tagName(feature.prefix), @tagName(feature.tag) });
    }

    pub fn lessThan(_: void, a: Feature, b: Feature) bool {
        assert(a != b);
        const a_int: u8 = @bitCast(a);
        const b_int: u8 = @bitCast(b);
        return a_int < b_int;
    }
};

pub fn open(
    arena: Allocator,
    comp: *Compilation,
    emit: Path,
    options: link.File.OpenOptions,
) !*Wasm {
    // TODO: restore saved linker state, don't truncate the file, and
    // participate in incremental compilation.
    return createEmpty(arena, comp, emit, options);
}

pub fn createEmpty(
    arena: Allocator,
    comp: *Compilation,
    emit: Path,
    options: link.File.OpenOptions,
) !*Wasm {
    const target = comp.root_mod.resolved_target.result;
    assert(target.ofmt == .wasm);

    const use_lld = build_options.have_llvm and comp.config.use_lld;
    const use_llvm = comp.config.use_llvm;
    const output_mode = comp.config.output_mode;
    const wasi_exec_model = comp.config.wasi_exec_model;

    // If using LLD to link, this code should produce an object file so that it
    // can be passed to LLD.
    // If using LLVM to generate the object file for the zig compilation unit,
    // we need a place to put the object file so that it can be subsequently
    // handled.
    const zcu_object_sub_path = if (!use_lld and !use_llvm)
        null
    else
        try std.fmt.allocPrint(arena, "{s}.o", .{emit.sub_path});

    const wasm = try arena.create(Wasm);
    wasm.* = .{
        .base = .{
            .tag = .wasm,
            .comp = comp,
            .emit = emit,
            .zcu_object_sub_path = zcu_object_sub_path,
            // Garbage collection is so crucial to WebAssembly that we design
            // the linker around the assumption that it will be on in the vast
            // majority of cases, and therefore express "no garbage collection"
            // in terms of setting the no_strip and must_link flags on all
            // symbols.
            .gc_sections = options.gc_sections orelse (output_mode != .Obj),
            .print_gc_sections = options.print_gc_sections,
            .stack_size = options.stack_size orelse switch (target.os.tag) {
                .freestanding => 1 * 1024 * 1024, // 1 MiB
                else => 16 * 1024 * 1024, // 16 MiB
            },
            .allow_shlib_undefined = options.allow_shlib_undefined orelse false,
            .file = null,
            .disable_lld_caching = options.disable_lld_caching,
            .build_id = options.build_id,
        },
        .name = undefined,
        .string_table = .empty,
        .string_bytes = .empty,
        .import_table = options.import_table,
        .export_table = options.export_table,
        .import_symbols = options.import_symbols,
        .export_symbol_names = options.export_symbol_names,
        .global_base = options.global_base,
        .initial_memory = options.initial_memory,
        .max_memory = options.max_memory,

        .entry_name = undefined,
        .dump_argv_list = .empty,
        .object_host_name = .none,
        .preloaded_strings = undefined,
    };
    if (use_llvm and comp.config.have_zcu) {
        wasm.llvm_object = try LlvmObject.create(arena, comp);
    }
    errdefer wasm.base.destroy();

    if (options.object_host_name) |name| wasm.object_host_name = (try wasm.internString(name)).toOptional();

    inline for (@typeInfo(PreloadedStrings).@"struct".fields) |field| {
        @field(wasm.preloaded_strings, field.name) = try wasm.internString(field.name);
    }

    wasm.entry_name = switch (options.entry) {
        .disabled => .none,
        .default => if (output_mode != .Exe) .none else defaultEntrySymbolName(&wasm.preloaded_strings, wasi_exec_model).toOptional(),
        .enabled => defaultEntrySymbolName(&wasm.preloaded_strings, wasi_exec_model).toOptional(),
        .named => |name| (try wasm.internString(name)).toOptional(),
    };

    if (use_lld and (use_llvm or !comp.config.have_zcu)) {
        // LLVM emits the object file (if any); LLD links it into the final product.
        return wasm;
    }

    // What path should this Wasm linker code output to?
    // If using LLD to link, this code should produce an object file so that it
    // can be passed to LLD.
    const sub_path = if (use_lld) zcu_object_sub_path.? else emit.sub_path;

    wasm.base.file = try emit.root_dir.handle.createFile(sub_path, .{
        .truncate = true,
        .read = true,
        .mode = if (fs.has_executable_bit)
            if (target.os.tag == .wasi and output_mode == .Exe)
                fs.File.default_mode | 0b001_000_000
            else
                fs.File.default_mode
        else
            0,
    });
    wasm.name = sub_path;

    return wasm;
}

fn openParseObjectReportingFailure(wasm: *Wasm, path: Path) void {
    const diags = &wasm.base.comp.link_diags;
    const obj = link.openObject(path, false, false) catch |err| {
        switch (diags.failParse(path, "failed to open object: {s}", .{@errorName(err)})) {
            error.LinkFailure => return,
        }
    };
    wasm.parseObject(obj) catch |err| {
        switch (diags.failParse(path, "failed to parse object: {s}", .{@errorName(err)})) {
            error.LinkFailure => return,
        }
    };
}

fn parseObject(wasm: *Wasm, obj: link.Input.Object) !void {
    const gpa = wasm.base.comp.gpa;
    const gc_sections = wasm.base.gc_sections;

    defer obj.file.close();

    try wasm.objects.ensureUnusedCapacity(gpa, 1);
    const stat = try obj.file.stat();
    const size = std.math.cast(usize, stat.size) orelse return error.FileTooBig;

    const file_contents = try gpa.alloc(u8, size);
    defer gpa.free(file_contents);

    const n = try obj.file.preadAll(file_contents, 0);
    if (n != file_contents.len) return error.UnexpectedEndOfFile;

    var ss: Object.ScratchSpace = .{};
    defer ss.deinit(gpa);

    const object = try Object.parse(wasm, file_contents, obj.path, null, wasm.object_host_name, &ss, obj.must_link, gc_sections);
    wasm.objects.appendAssumeCapacity(object);
}

fn parseArchive(wasm: *Wasm, obj: link.Input.Object) !void {
    const gpa = wasm.base.comp.gpa;
    const gc_sections = wasm.base.gc_sections;

    defer obj.file.close();

    const stat = try obj.file.stat();
    const size = std.math.cast(usize, stat.size) orelse return error.FileTooBig;

    const file_contents = try gpa.alloc(u8, size);
    defer gpa.free(file_contents);

    const n = try obj.file.preadAll(file_contents, 0);
    if (n != file_contents.len) return error.UnexpectedEndOfFile;

    var archive = try Archive.parse(gpa, file_contents);
    defer archive.deinit(gpa);

    // In this case we must force link all embedded object files within the archive
    // We loop over all symbols, and then group them by offset as the offset
    // notates where the object file starts.
    var offsets = std.AutoArrayHashMap(u32, void).init(gpa);
    defer offsets.deinit();
    for (archive.toc.values()) |symbol_offsets| {
        for (symbol_offsets.items) |sym_offset| {
            try offsets.put(sym_offset, {});
        }
    }

    var ss: Object.ScratchSpace = .{};
    defer ss.deinit(gpa);

    try wasm.objects.ensureUnusedCapacity(gpa, offsets.count());
    for (offsets.keys()) |file_offset| {
        const contents = file_contents[file_offset..];
        const object = try archive.parseObject(wasm, contents, obj.path, wasm.object_host_name, &ss, obj.must_link, gc_sections);
        wasm.objects.appendAssumeCapacity(object);
    }
}

pub fn deinit(wasm: *Wasm) void {
    const gpa = wasm.base.comp.gpa;
    if (wasm.llvm_object) |llvm_object| llvm_object.deinit();

    wasm.navs_exe.deinit(gpa);
    wasm.navs_obj.deinit(gpa);
    wasm.uavs_exe.deinit(gpa);
    wasm.uavs_obj.deinit(gpa);
    wasm.zcu_funcs.deinit(gpa);
    wasm.nav_exports.deinit(gpa);
    wasm.uav_exports.deinit(gpa);
    wasm.imports.deinit(gpa);

    wasm.flush_buffer.deinit(gpa);

    wasm.mir_instructions.deinit(gpa);
    wasm.mir_extra.deinit(gpa);
    wasm.all_zcu_locals.deinit(gpa);

    if (wasm.dwarf) |*dwarf| dwarf.deinit();

    wasm.object_function_imports.deinit(gpa);
    wasm.object_functions.deinit(gpa);
    wasm.object_global_imports.deinit(gpa);
    wasm.object_globals.deinit(gpa);
    wasm.object_table_imports.deinit(gpa);
    wasm.object_tables.deinit(gpa);
    wasm.object_memory_imports.deinit(gpa);
    wasm.object_memories.deinit(gpa);
    wasm.object_relocations.deinit(gpa);
    wasm.object_data_segments.deinit(gpa);
    wasm.object_custom_segments.deinit(gpa);
    wasm.object_init_funcs.deinit(gpa);
    wasm.object_comdats.deinit(gpa);
    wasm.object_relocations_table.deinit(gpa);
    wasm.object_comdat_symbols.deinit(gpa);
    wasm.objects.deinit(gpa);

    wasm.func_types.deinit(gpa);
    wasm.function_exports.deinit(gpa);
    wasm.function_imports.deinit(gpa);
    wasm.functions.deinit(gpa);
    wasm.globals.deinit(gpa);
    wasm.global_exports.deinit(gpa);
    wasm.global_imports.deinit(gpa);
    wasm.table_imports.deinit(gpa);
    wasm.data_segments.deinit(gpa);
    wasm.symbol_table.deinit(gpa);
    wasm.out_relocs.deinit(gpa);
    wasm.uav_fixups.deinit(gpa);
    wasm.nav_fixups.deinit(gpa);

    wasm.string_bytes.deinit(gpa);
    wasm.string_table.deinit(gpa);
    wasm.dump_argv_list.deinit(gpa);

    wasm.params_scratch.deinit(gpa);
    wasm.returns_scratch.deinit(gpa);

    wasm.missing_exports.deinit(gpa);
}

pub fn updateFunc(wasm: *Wasm, pt: Zcu.PerThread, func_index: InternPool.Index, air: Air, liveness: Liveness) !void {
    if (build_options.skip_non_native and builtin.object_format != .wasm) {
        @panic("Attempted to compile for object format that was disabled by build configuration");
    }
    if (wasm.llvm_object) |llvm_object| return llvm_object.updateFunc(pt, func_index, air, liveness);

    dev.check(.wasm_backend);

    const gpa = pt.zcu.gpa;
    try wasm.functions.ensureUnusedCapacity(gpa, 1);
    try wasm.zcu_funcs.ensureUnusedCapacity(gpa, 1);

    // This converts AIR to MIR but does not yet lower to wasm code.
    // That lowering happens during `flush`, after garbage collection, which
    // can affect function and global indexes, which affects the LEB integer
    // encoding, which affects the output binary size.
    wasm.zcu_funcs.putAssumeCapacity(func_index, .{
        .function = try CodeGen.function(wasm, pt, func_index, air, liveness),
    });
    wasm.functions.putAssumeCapacity(.pack(wasm, .{ .zcu_func = @enumFromInt(wasm.zcu_funcs.entries.len - 1) }), {});
}

// Generate code for the "Nav", storing it in memory to be later written to
// the file on flush().
pub fn updateNav(wasm: *Wasm, pt: Zcu.PerThread, nav_index: InternPool.Nav.Index) !void {
    if (build_options.skip_non_native and builtin.object_format != .wasm) {
        @panic("Attempted to compile for object format that was disabled by build configuration");
    }
    if (wasm.llvm_object) |llvm_object| return llvm_object.updateNav(pt, nav_index);
    const zcu = pt.zcu;
    const ip = &zcu.intern_pool;
    const nav = ip.getNav(nav_index);
    const comp = wasm.base.comp;
    const gpa = comp.gpa;
    const is_obj = comp.config.output_mode == .Obj;

    const nav_init = switch (ip.indexToKey(nav.status.resolved.val)) {
        .func => return, // global const which is a function alias
        .@"extern" => |ext| {
            if (is_obj) {
                assert(!wasm.navs_obj.contains(nav_index));
            } else {
                assert(!wasm.navs_exe.contains(nav_index));
            }
            const name = try wasm.internString(ext.name.toSlice(ip));
            if (ext.lib_name.toSlice(ip)) |ext_name| _ = try wasm.internString(ext_name);
            try wasm.imports.ensureUnusedCapacity(gpa, 1);
            if (ip.isFunctionType(nav.typeOf(ip))) {
                try wasm.function_imports.ensureUnusedCapacity(gpa, 1);
                const zcu_import = wasm.addZcuImportReserved(ext.owner_nav);
                wasm.function_imports.putAssumeCapacity(name, .fromZcuImport(zcu_import, wasm));
            } else {
                @panic("TODO extern data");
            }
            return;
        },
        .variable => |variable| variable.init,
        else => nav.status.resolved.val,
    };
    assert(!wasm.imports.contains(nav_index));

    if (nav_init != .none and !Value.fromInterned(nav_init).typeOf(zcu).hasRuntimeBits(zcu)) {
        if (is_obj) {
            assert(!wasm.navs_obj.contains(nav_index));
        } else {
            assert(!wasm.navs_exe.contains(nav_index));
        }
        return;
    }

    const zcu_data = try lowerZcuData(wasm, pt, nav_init);

    try wasm.data_segments.ensureUnusedCapacity(gpa, 1);

    if (is_obj) {
        const gop = try wasm.navs_obj.getOrPut(gpa, nav_index);
        gop.value_ptr.* = zcu_data;
        wasm.data_segments.putAssumeCapacity(.pack(wasm, .{ .nav_obj = @enumFromInt(gop.index) }), {});
    }

    assert(zcu_data.relocs.len == 0);

    const gop = try wasm.navs_exe.getOrPut(gpa, nav_index);
    gop.value_ptr.* = .{
        .code = zcu_data.code,
        .count = 0,
    };
    wasm.data_segments.putAssumeCapacity(.pack(wasm, .{ .nav_exe = @enumFromInt(gop.index) }), {});
}

pub fn updateLineNumber(wasm: *Wasm, pt: Zcu.PerThread, ti_id: InternPool.TrackedInst.Index) !void {
    if (wasm.dwarf) |*dw| {
        try dw.updateLineNumber(pt.zcu, ti_id);
    }
}

pub fn deleteExport(
    wasm: *Wasm,
    exported: Zcu.Exported,
    name: InternPool.NullTerminatedString,
) void {
    if (wasm.llvm_object != null) return;

    const zcu = wasm.base.comp.zcu.?;
    const ip = &zcu.intern_pool;
    const name_slice = name.toSlice(ip);
    const export_name = wasm.getExistingString(name_slice).?;
    switch (exported) {
        .nav => |nav_index| {
            log.debug("deleteExport '{s}' nav={d}", .{ name_slice, @intFromEnum(nav_index) });
            assert(wasm.nav_exports.swapRemove(.{ .nav_index = nav_index, .name = export_name }));
        },
        .uav => |uav_index| assert(wasm.uav_exports.swapRemove(.{ .uav_index = uav_index, .name = export_name })),
    }
}

pub fn updateExports(
    wasm: *Wasm,
    pt: Zcu.PerThread,
    exported: Zcu.Exported,
    export_indices: []const Zcu.Export.Index,
) !void {
    if (build_options.skip_non_native and builtin.object_format != .wasm) {
        @panic("Attempted to compile for object format that was disabled by build configuration");
    }
    if (wasm.llvm_object) |llvm_object| return llvm_object.updateExports(pt, exported, export_indices);

    const zcu = pt.zcu;
    const gpa = zcu.gpa;
    const ip = &zcu.intern_pool;
    for (export_indices) |export_idx| {
        const exp = export_idx.ptr(zcu);
        const name_slice = exp.opts.name.toSlice(ip);
        const name = try wasm.internString(name_slice);
        switch (exported) {
            .nav => |nav_index| {
                log.debug("updateExports '{s}' nav={d}", .{ name_slice, @intFromEnum(nav_index) });
                try wasm.nav_exports.put(gpa, .{ .nav_index = nav_index, .name = name }, export_idx);
            },
            .uav => |uav_index| try wasm.uav_exports.put(gpa, .{ .uav_index = uav_index, .name = name }, export_idx),
        }
    }
}

pub fn loadInput(wasm: *Wasm, input: link.Input) !void {
    const comp = wasm.base.comp;
    const gpa = comp.gpa;

    if (comp.verbose_link) {
        comp.mutex.lock(); // protect comp.arena
        defer comp.mutex.unlock();

        const argv = &wasm.dump_argv_list;
        switch (input) {
            .res => unreachable,
            .dso_exact => unreachable,
            .dso => unreachable,
            .object, .archive => |obj| try argv.append(gpa, try obj.path.toString(comp.arena)),
        }
    }

    switch (input) {
        .res => unreachable,
        .dso_exact => unreachable,
        .dso => unreachable,
        .object => |obj| try parseObject(wasm, obj),
        .archive => |obj| try parseArchive(wasm, obj),
    }
}

pub fn flush(wasm: *Wasm, arena: Allocator, tid: Zcu.PerThread.Id, prog_node: std.Progress.Node) link.File.FlushError!void {
    const comp = wasm.base.comp;
    const use_lld = build_options.have_llvm and comp.config.use_lld;
    const diags = &comp.link_diags;

    if (use_lld) {
        return wasm.linkWithLLD(arena, tid, prog_node) catch |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            error.LinkFailure => return error.LinkFailure,
            else => |e| return diags.fail("failed to link with LLD: {s}", .{@errorName(e)}),
        };
    }
    return wasm.flushModule(arena, tid, prog_node);
}

pub fn prelink(wasm: *Wasm, prog_node: std.Progress.Node) link.File.FlushError!void {
    const tracy = trace(@src());
    defer tracy.end();

    const sub_prog_node = prog_node.start("Wasm Prelink", 0);
    defer sub_prog_node.end();

    const comp = wasm.base.comp;
    const gpa = comp.gpa;
    const rdynamic = comp.config.rdynamic;

    assert(wasm.missing_exports.entries.len == 0);
    for (wasm.export_symbol_names) |exp_name| {
        const exp_name_interned = try wasm.internString(exp_name);
        if (wasm.object_function_imports.getPtr(exp_name_interned)) |import| {
            if (import.resolution != .unresolved) {
                import.flags.exported = true;
                continue;
            }
        }
        if (wasm.object_global_imports.getPtr(exp_name_interned)) |import| {
            if (import.resolution != .unresolved) {
                import.flags.exported = true;
                continue;
            }
        }
        if (wasm.object_table_imports.getPtr(exp_name_interned)) |import| {
            if (import.resolution != .unresolved) {
                import.flags.exported = true;
                continue;
            }
        }
        try wasm.missing_exports.put(gpa, exp_name_interned, {});
    }

    if (wasm.entry_name.unwrap()) |entry_name| {
        if (wasm.object_function_imports.getPtr(entry_name)) |import| {
            if (import.resolution != .unresolved) {
                import.flags.exported = true;
                wasm.entry_resolution = import.resolution;
            }
        }
    }

    if (comp.zcu != null) {
        // Zig always depends on a stack pointer global.
        try wasm.globals.put(gpa, .__stack_pointer, {});
        assert(wasm.globals.entries.len - 1 == @intFromEnum(GlobalIndex.stack_pointer));
    }

    // These loops do both recursive marking of alive symbols well as checking for undefined symbols.
    // At the end, output functions and globals will be populated.
    for (wasm.object_function_imports.keys(), wasm.object_function_imports.values(), 0..) |name, *import, i| {
        if (import.flags.isIncluded(rdynamic)) {
            try markFunction(wasm, name, import, @enumFromInt(i));
        }
    }
    wasm.functions_end_prelink = @intCast(wasm.functions.entries.len);
    wasm.function_exports_len = @intCast(wasm.function_exports.items.len);

    for (wasm.object_global_imports.keys(), wasm.object_global_imports.values(), 0..) |name, *import, i| {
        if (import.flags.isIncluded(rdynamic)) {
            try markGlobal(wasm, name, import, @enumFromInt(i));
        }
    }
    wasm.globals_end_prelink = @intCast(wasm.globals.entries.len);
    wasm.global_exports_len = @intCast(wasm.global_exports.items.len);

    for (wasm.object_table_imports.keys(), wasm.object_table_imports.values(), 0..) |name, *import, i| {
        if (import.flags.isIncluded(rdynamic)) {
            try markTable(wasm, name, import, @enumFromInt(i));
        }
    }
}

/// Recursively mark alive everything referenced by the function.
fn markFunction(
    wasm: *Wasm,
    name: String,
    import: *FunctionImport,
    func_index: FunctionImport.Index,
) Allocator.Error!void {
    if (import.flags.alive) return;
    import.flags.alive = true;

    const comp = wasm.base.comp;
    const gpa = comp.gpa;
    const rdynamic = comp.config.rdynamic;
    const is_obj = comp.config.output_mode == .Obj;

    try wasm.functions.ensureUnusedCapacity(gpa, 1);

    if (import.resolution == .unresolved) {
        if (name == wasm.preloaded_strings.__wasm_init_memory) {
            import.resolution = .__wasm_init_memory;
            wasm.functions.putAssumeCapacity(.__wasm_init_memory, {});
        } else if (name == wasm.preloaded_strings.__wasm_apply_global_tls_relocs) {
            import.resolution = .__wasm_apply_global_tls_relocs;
            wasm.functions.putAssumeCapacity(.__wasm_apply_global_tls_relocs, {});
        } else if (name == wasm.preloaded_strings.__wasm_call_ctors) {
            import.resolution = .__wasm_call_ctors;
            wasm.functions.putAssumeCapacity(.__wasm_call_ctors, {});
        } else if (name == wasm.preloaded_strings.__wasm_init_tls) {
            import.resolution = .__wasm_init_tls;
            wasm.functions.putAssumeCapacity(.__wasm_init_tls, {});
        } else {
            try wasm.function_imports.put(gpa, name, .fromObject(func_index, wasm));
        }
    } else {
        const gop = wasm.functions.getOrPutAssumeCapacity(import.resolution);

        if (!is_obj and import.flags.isExported(rdynamic)) try wasm.function_exports.append(gpa, .{
            .name = name,
            .function_index = @enumFromInt(gop.index),
        });

        for (try wasm.functionResolutionRelocSlice(import.resolution)) |reloc|
            try wasm.markReloc(reloc);
    }
}

/// Recursively mark alive everything referenced by the global.
fn markGlobal(
    wasm: *Wasm,
    name: String,
    import: *GlobalImport,
    global_index: GlobalImport.Index,
) !void {
    if (import.flags.alive) return;
    import.flags.alive = true;

    const comp = wasm.base.comp;
    const gpa = comp.gpa;
    const rdynamic = comp.config.rdynamic;
    const is_obj = comp.config.output_mode == .Obj;

    try wasm.globals.ensureUnusedCapacity(gpa, 1);

    if (import.resolution == .unresolved) {
        if (name == wasm.preloaded_strings.__heap_base) {
            import.resolution = .__heap_base;
            wasm.globals.putAssumeCapacity(.__heap_base, {});
        } else if (name == wasm.preloaded_strings.__heap_end) {
            import.resolution = .__heap_end;
            wasm.globals.putAssumeCapacity(.__heap_end, {});
        } else if (name == wasm.preloaded_strings.__stack_pointer) {
            import.resolution = .__stack_pointer;
            wasm.globals.putAssumeCapacity(.__stack_pointer, {});
        } else if (name == wasm.preloaded_strings.__tls_align) {
            import.resolution = .__tls_align;
            wasm.globals.putAssumeCapacity(.__tls_align, {});
        } else if (name == wasm.preloaded_strings.__tls_base) {
            import.resolution = .__tls_base;
            wasm.globals.putAssumeCapacity(.__tls_base, {});
        } else if (name == wasm.preloaded_strings.__tls_size) {
            import.resolution = .__tls_size;
            wasm.globals.putAssumeCapacity(.__tls_size, {});
        } else {
            try wasm.global_imports.put(gpa, name, .fromObject(global_index, wasm));
        }
    } else {
        const gop = wasm.globals.getOrPutAssumeCapacity(import.resolution);

        if (!is_obj and import.flags.isExported(rdynamic)) try wasm.global_exports.append(gpa, .{
            .name = name,
            .global_index = @enumFromInt(gop.index),
        });

        for (try wasm.globalResolutionRelocSlice(import.resolution)) |reloc|
            try wasm.markReloc(reloc);
    }
}

fn markTable(
    wasm: *Wasm,
    name: String,
    import: *TableImport,
    table_index: TableImport.Index,
) !void {
    if (import.flags.alive) return;
    import.flags.alive = true;

    const comp = wasm.base.comp;
    const gpa = comp.gpa;

    try wasm.tables.ensureUnusedCapacity(gpa, 1);

    if (import.resolution == .unresolved) {
        if (name == wasm.preloaded_strings.__indirect_function_table) {
            import.resolution = .__indirect_function_table;
            wasm.tables.putAssumeCapacity(.__indirect_function_table, {});
        } else {
            try wasm.table_imports.put(gpa, name, table_index);
        }
    } else {
        wasm.tables.putAssumeCapacity(import.resolution, {});
        // Tables have no relocations.
    }
}

fn globalResolutionRelocSlice(wasm: *Wasm, resolution: GlobalImport.Resolution) ![]const ObjectRelocation {
    assert(resolution != .unresolved);
    _ = wasm;
    @panic("TODO");
}

fn functionResolutionRelocSlice(wasm: *Wasm, resolution: FunctionImport.Resolution) ![]const ObjectRelocation {
    assert(resolution != .unresolved);
    _ = wasm;
    @panic("TODO");
}

fn markReloc(wasm: *Wasm, reloc: ObjectRelocation) !void {
    _ = wasm;
    _ = reloc;
    @panic("TODO");
}

pub fn flushModule(
    wasm: *Wasm,
    arena: Allocator,
    tid: Zcu.PerThread.Id,
    prog_node: std.Progress.Node,
) link.File.FlushError!void {
    // The goal is to never use this because it's only needed if we need to
    // write to InternPool, but flushModule is too late to be writing to the
    // InternPool.
    _ = tid;
    const comp = wasm.base.comp;
    const use_lld = build_options.have_llvm and comp.config.use_lld;
    const diags = &comp.link_diags;
    const gpa = comp.gpa;

    if (wasm.llvm_object) |llvm_object| {
        try wasm.base.emitLlvmObject(arena, llvm_object, prog_node);
        if (use_lld) return;
    }

    if (comp.verbose_link) Compilation.dump_argv(wasm.dump_argv_list.items);

    if (wasm.base.zcu_object_sub_path) |path| {
        const module_obj_path: Path = .{
            .root_dir = wasm.base.emit.root_dir,
            .sub_path = if (fs.path.dirname(wasm.base.emit.sub_path)) |dirname|
                try fs.path.join(arena, &.{ dirname, path })
            else
                path,
        };
        openParseObjectReportingFailure(wasm, module_obj_path);
        try prelink(wasm, prog_node);
    }

    const tracy = trace(@src());
    defer tracy.end();

    const sub_prog_node = prog_node.start("Wasm Flush", 0);
    defer sub_prog_node.end();

    const functions_end_zcu: u32 = @intCast(wasm.functions.entries.len);
    defer wasm.functions.shrinkRetainingCapacity(functions_end_zcu);

    const globals_end_zcu: u32 = @intCast(wasm.globals.entries.len);
    defer wasm.globals.shrinkRetainingCapacity(globals_end_zcu);

    const data_segments_end_zcu: u32 = @intCast(wasm.data_segments.entries.len);
    defer wasm.data_segments.shrinkRetainingCapacity(data_segments_end_zcu);

    wasm.flush_buffer.clear();
    try wasm.flush_buffer.missing_exports.reinit(gpa, wasm.missing_exports.keys(), &.{});
    try wasm.flush_buffer.data_segments.reinit(gpa, wasm.data_segments.keys(), &.{});
    try wasm.flush_buffer.function_imports.reinit(gpa, wasm.function_imports.keys(), wasm.function_imports.values());
    try wasm.flush_buffer.global_imports.reinit(gpa, wasm.global_imports.keys(), wasm.global_imports.values());

    return wasm.flush_buffer.finish(wasm) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        error.LinkFailure => return error.LinkFailure,
        else => |e| return diags.fail("failed to flush wasm: {s}", .{@errorName(e)}),
    };
}

fn linkWithLLD(wasm: *Wasm, arena: Allocator, tid: Zcu.PerThread.Id, prog_node: std.Progress.Node) !void {
    dev.check(.lld_linker);

    const tracy = trace(@src());
    defer tracy.end();

    const comp = wasm.base.comp;
    const diags = &comp.link_diags;
    const shared_memory = comp.config.shared_memory;
    const export_memory = comp.config.export_memory;
    const import_memory = comp.config.import_memory;
    const target = comp.root_mod.resolved_target.result;

    const gpa = comp.gpa;

    const directory = wasm.base.emit.root_dir; // Just an alias to make it shorter to type.
    const full_out_path = try directory.join(arena, &[_][]const u8{wasm.base.emit.sub_path});

    // If there is no Zig code to compile, then we should skip flushing the output file because it
    // will not be part of the linker line anyway.
    const module_obj_path: ?[]const u8 = if (comp.zcu != null) blk: {
        try wasm.flushModule(arena, tid, prog_node);

        if (fs.path.dirname(full_out_path)) |dirname| {
            break :blk try fs.path.join(arena, &.{ dirname, wasm.base.zcu_object_sub_path.? });
        } else {
            break :blk wasm.base.zcu_object_sub_path.?;
        }
    } else null;

    const sub_prog_node = prog_node.start("LLD Link", 0);
    defer sub_prog_node.end();

    const is_obj = comp.config.output_mode == .Obj;
    const compiler_rt_path: ?Path = blk: {
        if (comp.compiler_rt_lib) |lib| break :blk lib.full_object_path;
        if (comp.compiler_rt_obj) |obj| break :blk obj.full_object_path;
        break :blk null;
    };

    const id_symlink_basename = "lld.id";

    var man: Cache.Manifest = undefined;
    defer if (!wasm.base.disable_lld_caching) man.deinit();

    var digest: [Cache.hex_digest_len]u8 = undefined;

    if (!wasm.base.disable_lld_caching) {
        man = comp.cache_parent.obtain();

        // We are about to obtain this lock, so here we give other processes a chance first.
        wasm.base.releaseLock();

        comptime assert(Compilation.link_hash_implementation_version == 14);

        try link.hashInputs(&man, comp.link_inputs);
        for (comp.c_object_table.keys()) |key| {
            _ = try man.addFilePath(key.status.success.object_path, null);
        }
        try man.addOptionalFile(module_obj_path);
        try man.addOptionalFilePath(compiler_rt_path);
        man.hash.addOptionalBytes(wasm.entry_name.slice(wasm));
        man.hash.add(wasm.base.stack_size);
        man.hash.add(wasm.base.build_id);
        man.hash.add(import_memory);
        man.hash.add(export_memory);
        man.hash.add(wasm.import_table);
        man.hash.add(wasm.export_table);
        man.hash.addOptional(wasm.initial_memory);
        man.hash.addOptional(wasm.max_memory);
        man.hash.add(shared_memory);
        man.hash.addOptional(wasm.global_base);
        man.hash.addListOfBytes(wasm.export_symbol_names);
        // strip does not need to go into the linker hash because it is part of the hash namespace

        // We don't actually care whether it's a cache hit or miss; we just need the digest and the lock.
        _ = try man.hit();
        digest = man.final();

        var prev_digest_buf: [digest.len]u8 = undefined;
        const prev_digest: []u8 = Cache.readSmallFile(
            directory.handle,
            id_symlink_basename,
            &prev_digest_buf,
        ) catch |err| blk: {
            log.debug("WASM LLD new_digest={s} error: {s}", .{ std.fmt.fmtSliceHexLower(&digest), @errorName(err) });
            // Handle this as a cache miss.
            break :blk prev_digest_buf[0..0];
        };
        if (mem.eql(u8, prev_digest, &digest)) {
            log.debug("WASM LLD digest={s} match - skipping invocation", .{std.fmt.fmtSliceHexLower(&digest)});
            // Hot diggity dog! The output binary is already there.
            wasm.base.lock = man.toOwnedLock();
            return;
        }
        log.debug("WASM LLD prev_digest={s} new_digest={s}", .{ std.fmt.fmtSliceHexLower(prev_digest), std.fmt.fmtSliceHexLower(&digest) });

        // We are about to change the output file to be different, so we invalidate the build hash now.
        directory.handle.deleteFile(id_symlink_basename) catch |err| switch (err) {
            error.FileNotFound => {},
            else => |e| return e,
        };
    }

    if (is_obj) {
        // LLD's WASM driver does not support the equivalent of `-r` so we do a simple file copy
        // here. TODO: think carefully about how we can avoid this redundant operation when doing
        // build-obj. See also the corresponding TODO in linkAsArchive.
        const the_object_path = blk: {
            if (link.firstObjectInput(comp.link_inputs)) |obj| break :blk obj.path;

            if (comp.c_object_table.count() != 0)
                break :blk comp.c_object_table.keys()[0].status.success.object_path;

            if (module_obj_path) |p|
                break :blk Path.initCwd(p);

            // TODO I think this is unreachable. Audit this situation when solving the above TODO
            // regarding eliding redundant object -> object transformations.
            return error.NoObjectsToLink;
        };
        try fs.Dir.copyFile(
            the_object_path.root_dir.handle,
            the_object_path.sub_path,
            directory.handle,
            wasm.base.emit.sub_path,
            .{},
        );
    } else {
        // Create an LLD command line and invoke it.
        var argv = std.ArrayList([]const u8).init(gpa);
        defer argv.deinit();
        // We will invoke ourselves as a child process to gain access to LLD.
        // This is necessary because LLD does not behave properly as a library -
        // it calls exit() and does not reset all global data between invocations.
        const linker_command = "wasm-ld";
        try argv.appendSlice(&[_][]const u8{ comp.self_exe_path.?, linker_command });
        try argv.append("--error-limit=0");

        if (comp.config.lto != .none) {
            switch (comp.root_mod.optimize_mode) {
                .Debug => {},
                .ReleaseSmall => try argv.append("-O2"),
                .ReleaseFast, .ReleaseSafe => try argv.append("-O3"),
            }
        }

        if (import_memory) {
            try argv.append("--import-memory");
        }

        if (export_memory) {
            try argv.append("--export-memory");
        }

        if (wasm.import_table) {
            assert(!wasm.export_table);
            try argv.append("--import-table");
        }

        if (wasm.export_table) {
            assert(!wasm.import_table);
            try argv.append("--export-table");
        }

        // For wasm-ld we only need to specify '--no-gc-sections' when the user explicitly
        // specified it as garbage collection is enabled by default.
        if (!wasm.base.gc_sections) {
            try argv.append("--no-gc-sections");
        }

        if (comp.config.debug_format == .strip) {
            try argv.append("-s");
        }

        if (wasm.initial_memory) |initial_memory| {
            const arg = try std.fmt.allocPrint(arena, "--initial-memory={d}", .{initial_memory});
            try argv.append(arg);
        }

        if (wasm.max_memory) |max_memory| {
            const arg = try std.fmt.allocPrint(arena, "--max-memory={d}", .{max_memory});
            try argv.append(arg);
        }

        if (shared_memory) {
            try argv.append("--shared-memory");
        }

        if (wasm.global_base) |global_base| {
            const arg = try std.fmt.allocPrint(arena, "--global-base={d}", .{global_base});
            try argv.append(arg);
        } else {
            // We prepend it by default, so when a stack overflow happens the runtime will trap correctly,
            // rather than silently overwrite all global declarations. See https://github.com/ziglang/zig/issues/4496
            //
            // The user can overwrite this behavior by setting the global-base
            try argv.append("--stack-first");
        }

        // Users are allowed to specify which symbols they want to export to the wasm host.
        for (wasm.export_symbol_names) |symbol_name| {
            const arg = try std.fmt.allocPrint(arena, "--export={s}", .{symbol_name});
            try argv.append(arg);
        }

        if (comp.config.rdynamic) {
            try argv.append("--export-dynamic");
        }

        if (wasm.entry_name.slice(wasm)) |entry_name| {
            try argv.appendSlice(&.{ "--entry", entry_name });
        } else {
            try argv.append("--no-entry");
        }

        try argv.appendSlice(&.{
            "-z",
            try std.fmt.allocPrint(arena, "stack-size={d}", .{wasm.base.stack_size}),
        });

        if (wasm.import_symbols) {
            try argv.append("--allow-undefined");
        }

        if (comp.config.output_mode == .Lib and comp.config.link_mode == .dynamic) {
            try argv.append("--shared");
        }
        if (comp.config.pie) {
            try argv.append("--pie");
        }

        // XXX - TODO: add when wasm-ld supports --build-id.
        // if (wasm.base.build_id) {
        //     try argv.append("--build-id=tree");
        // }

        try argv.appendSlice(&.{ "-o", full_out_path });

        if (target.cpu.arch == .wasm64) {
            try argv.append("-mwasm64");
        }

        if (target.os.tag == .wasi) {
            const is_exe_or_dyn_lib = comp.config.output_mode == .Exe or
                (comp.config.output_mode == .Lib and comp.config.link_mode == .dynamic);
            if (is_exe_or_dyn_lib) {
                for (comp.wasi_emulated_libs) |crt_file| {
                    try argv.append(try comp.crtFileAsString(
                        arena,
                        wasi_libc.emulatedLibCRFileLibName(crt_file),
                    ));
                }

                if (comp.config.link_libc) {
                    try argv.append(try comp.crtFileAsString(
                        arena,
                        wasi_libc.execModelCrtFileFullName(comp.config.wasi_exec_model),
                    ));
                    try argv.append(try comp.crtFileAsString(arena, "libc.a"));
                }

                if (comp.config.link_libcpp) {
                    try argv.append(try comp.libcxx_static_lib.?.full_object_path.toString(arena));
                    try argv.append(try comp.libcxxabi_static_lib.?.full_object_path.toString(arena));
                }
            }
        }

        // Positional arguments to the linker such as object files.
        var whole_archive = false;
        for (comp.link_inputs) |link_input| switch (link_input) {
            .object, .archive => |obj| {
                if (obj.must_link and !whole_archive) {
                    try argv.append("-whole-archive");
                    whole_archive = true;
                } else if (!obj.must_link and whole_archive) {
                    try argv.append("-no-whole-archive");
                    whole_archive = false;
                }
                try argv.append(try obj.path.toString(arena));
            },
            .dso => |dso| {
                try argv.append(try dso.path.toString(arena));
            },
            .dso_exact => unreachable,
            .res => unreachable,
        };
        if (whole_archive) {
            try argv.append("-no-whole-archive");
            whole_archive = false;
        }

        for (comp.c_object_table.keys()) |key| {
            try argv.append(try key.status.success.object_path.toString(arena));
        }
        if (module_obj_path) |p| {
            try argv.append(p);
        }

        if (comp.libc_static_lib) |crt_file| {
            try argv.append(try crt_file.full_object_path.toString(arena));
        }

        if (compiler_rt_path) |p| {
            try argv.append(try p.toString(arena));
        }

        if (comp.verbose_link) {
            // Skip over our own name so that the LLD linker name is the first argv item.
            Compilation.dump_argv(argv.items[1..]);
        }

        if (std.process.can_spawn) {
            // If possible, we run LLD as a child process because it does not always
            // behave properly as a library, unfortunately.
            // https://github.com/ziglang/zig/issues/3825
            var child = std.process.Child.init(argv.items, arena);
            if (comp.clang_passthrough_mode) {
                child.stdin_behavior = .Inherit;
                child.stdout_behavior = .Inherit;
                child.stderr_behavior = .Inherit;

                const term = child.spawnAndWait() catch |err| {
                    log.err("failed to spawn (passthrough mode) LLD {s}: {s}", .{ argv.items[0], @errorName(err) });
                    return error.UnableToSpawnWasm;
                };
                switch (term) {
                    .Exited => |code| {
                        if (code != 0) {
                            std.process.exit(code);
                        }
                    },
                    else => std.process.abort(),
                }
            } else {
                child.stdin_behavior = .Ignore;
                child.stdout_behavior = .Ignore;
                child.stderr_behavior = .Pipe;

                try child.spawn();

                const stderr = try child.stderr.?.reader().readAllAlloc(arena, std.math.maxInt(usize));

                const term = child.wait() catch |err| {
                    log.err("failed to spawn LLD {s}: {s}", .{ argv.items[0], @errorName(err) });
                    return error.UnableToSpawnWasm;
                };

                switch (term) {
                    .Exited => |code| {
                        if (code != 0) {
                            diags.lockAndParseLldStderr(linker_command, stderr);
                            return error.LinkFailure;
                        }
                    },
                    else => {
                        return diags.fail("{s} terminated with stderr:\n{s}", .{ argv.items[0], stderr });
                    },
                }

                if (stderr.len != 0) {
                    log.warn("unexpected LLD stderr:\n{s}", .{stderr});
                }
            }
        } else {
            const exit_code = try lldMain(arena, argv.items, false);
            if (exit_code != 0) {
                if (comp.clang_passthrough_mode) {
                    std.process.exit(exit_code);
                } else {
                    return diags.fail("{s} returned exit code {d}:\n{s}", .{ argv.items[0], exit_code });
                }
            }
        }

        // Give +x to the .wasm file if it is an executable and the OS is WASI.
        // Some systems may be configured to execute such binaries directly. Even if that
        // is not the case, it means we will get "exec format error" when trying to run
        // it, and then can react to that in the same way as trying to run an ELF file
        // from a foreign CPU architecture.
        if (fs.has_executable_bit and target.os.tag == .wasi and
            comp.config.output_mode == .Exe)
        {
            // TODO: what's our strategy for reporting linker errors from this function?
            // report a nice error here with the file path if it fails instead of
            // just returning the error code.
            // chmod does not interact with umask, so we use a conservative -rwxr--r-- here.
            std.posix.fchmodat(fs.cwd().fd, full_out_path, 0o744, 0) catch |err| switch (err) {
                error.OperationNotSupported => unreachable, // Not a symlink.
                else => |e| return e,
            };
        }
    }

    if (!wasm.base.disable_lld_caching) {
        // Update the file with the digest. If it fails we can continue; it only
        // means that the next invocation will have an unnecessary cache miss.
        Cache.writeSmallFile(directory.handle, id_symlink_basename, &digest) catch |err| {
            log.warn("failed to save linking hash digest symlink: {s}", .{@errorName(err)});
        };
        // Again failure here only means an unnecessary cache miss.
        man.writeManifest() catch |err| {
            log.warn("failed to write cache manifest when linking: {s}", .{@errorName(err)});
        };
        // We hang on to this lock so that the output file path can be used without
        // other processes clobbering it.
        wasm.base.lock = man.toOwnedLock();
    }
}

fn defaultEntrySymbolName(
    preloaded_strings: *const PreloadedStrings,
    wasi_exec_model: std.builtin.WasiExecModel,
) String {
    return switch (wasi_exec_model) {
        .reactor => preloaded_strings._initialize,
        .command => preloaded_strings._start,
    };
}

pub fn internString(wasm: *Wasm, bytes: []const u8) Allocator.Error!String {
    assert(mem.indexOfScalar(u8, bytes, 0) == null);
    wasm.string_bytes_lock.lock();
    defer wasm.string_bytes_lock.unlock();
    const gpa = wasm.base.comp.gpa;
    const gop = try wasm.string_table.getOrPutContextAdapted(
        gpa,
        @as([]const u8, bytes),
        @as(String.TableIndexAdapter, .{ .bytes = wasm.string_bytes.items }),
        @as(String.TableContext, .{ .bytes = wasm.string_bytes.items }),
    );
    if (gop.found_existing) return gop.key_ptr.*;

    try wasm.string_bytes.ensureUnusedCapacity(gpa, bytes.len + 1);
    const new_off: String = @enumFromInt(wasm.string_bytes.items.len);

    wasm.string_bytes.appendSliceAssumeCapacity(bytes);
    wasm.string_bytes.appendAssumeCapacity(0);

    gop.key_ptr.* = new_off;

    return new_off;
}

// TODO implement instead by appending to string_bytes
pub fn internStringFmt(wasm: *Wasm, comptime format: []const u8, args: anytype) Allocator.Error!String {
    var buffer: [32]u8 = undefined;
    const slice = std.fmt.bufPrint(&buffer, format, args) catch unreachable;
    return internString(wasm, slice);
}

pub fn getExistingString(wasm: *const Wasm, bytes: []const u8) ?String {
    assert(mem.indexOfScalar(u8, bytes, 0) == null);
    return wasm.string_table.getKeyAdapted(bytes, @as(String.TableIndexAdapter, .{
        .bytes = wasm.string_bytes.items,
    }));
}

pub fn internValtypeList(wasm: *Wasm, valtype_list: []const std.wasm.Valtype) Allocator.Error!ValtypeList {
    return .fromString(try internString(wasm, @ptrCast(valtype_list)));
}

pub fn getExistingValtypeList(wasm: *Wasm, valtype_list: []const std.wasm.Valtype) ?ValtypeList {
    return .fromString(getExistingString(wasm, @ptrCast(valtype_list)) orelse return null);
}

pub fn addFuncType(wasm: *Wasm, ft: FunctionType) Allocator.Error!FunctionType.Index {
    const gpa = wasm.base.comp.gpa;
    const gop = try wasm.func_types.getOrPut(gpa, ft);
    return @enumFromInt(gop.index);
}

pub fn getExistingFuncType(wasm: *const Wasm, ft: FunctionType) ?FunctionType.Index {
    const index = wasm.func_types.getIndex(ft) orelse return null;
    return @enumFromInt(index);
}

pub fn internFunctionType(
    wasm: *Wasm,
    cc: std.builtin.CallingConvention,
    params: []const InternPool.Index,
    return_type: ZcuType,
    target: *const std.Target,
) Allocator.Error!FunctionType.Index {
    try convertZcuFnType(wasm.base.comp, cc, params, return_type, target, &wasm.params_scratch, &wasm.returns_scratch);
    return wasm.addFuncType(.{
        .params = try wasm.internValtypeList(wasm.params_scratch.items),
        .returns = try wasm.internValtypeList(wasm.returns_scratch.items),
    });
}

pub fn getExistingFunctionType(
    wasm: *Wasm,
    cc: std.builtin.CallingConvention,
    params: []const InternPool.Index,
    return_type: ZcuType,
    target: *const std.Target,
) ?FunctionType.Index {
    convertZcuFnType(wasm.base.comp, cc, params, return_type, target, &wasm.params_scratch, &wasm.returns_scratch) catch |err| switch (err) {
        error.OutOfMemory => return null,
    };
    return wasm.getExistingFuncType(.{
        .params = wasm.getExistingValtypeList(wasm.params_scratch.items) orelse return null,
        .returns = wasm.getExistingValtypeList(wasm.returns_scratch.items) orelse return null,
    });
}

pub fn addExpr(wasm: *Wasm, bytes: []const u8) Allocator.Error!Expr {
    const gpa = wasm.base.comp.gpa;
    // We can't use string table deduplication here since these expressions can
    // have null bytes in them however it may be interesting to explore since
    // it is likely for globals to share initialization values. Then again
    // there may not be very many globals in total.
    try wasm.string_bytes.appendSlice(gpa, bytes);
    return @enumFromInt(wasm.string_bytes.items.len - bytes.len);
}

pub fn addRelocatableDataPayload(wasm: *Wasm, bytes: []const u8) Allocator.Error!DataSegment.Payload {
    const gpa = wasm.base.comp.gpa;
    try wasm.string_bytes.appendSlice(gpa, bytes);
    return .{
        .off = @enumFromInt(wasm.string_bytes.items.len - bytes.len),
        .len = @intCast(bytes.len),
    };
}

pub fn uavSymbolIndex(wasm: *Wasm, ip_index: InternPool.Index) Allocator.Error!SymbolTableIndex {
    const comp = wasm.base.comp;
    assert(comp.config.output_mode == .Obj);
    const gpa = comp.gpa;
    const name = try wasm.internStringFmt("__anon_{d}", .{@intFromEnum(ip_index)});
    const gop = try wasm.symbol_table.getOrPut(gpa, name);
    gop.value_ptr.* = {};
    return @enumFromInt(gop.index);
}

pub fn navSymbolIndex(wasm: *Wasm, nav_index: InternPool.Nav.Index) Allocator.Error!SymbolTableIndex {
    const comp = wasm.base.comp;
    assert(comp.config.output_mode == .Obj);
    const zcu = comp.zcu.?;
    const ip = &zcu.intern_pool;
    const gpa = comp.gpa;
    const nav = ip.getNav(nav_index);
    const name = try wasm.internString(nav.fqn.toSlice(ip));
    const gop = try wasm.symbol_table.getOrPut(gpa, name);
    gop.value_ptr.* = {};
    return @enumFromInt(gop.index);
}

pub fn errorNameTableSymbolIndex(wasm: *Wasm) Allocator.Error!SymbolTableIndex {
    const comp = wasm.base.comp;
    assert(comp.config.output_mode == .Obj);
    const gpa = comp.gpa;
    const gop = try wasm.symbol_table.getOrPut(gpa, wasm.preloaded_strings.__zig_error_name_table);
    gop.value_ptr.* = {};
    return @enumFromInt(gop.index);
}

pub fn stackPointerSymbolIndex(wasm: *Wasm) Allocator.Error!SymbolTableIndex {
    const comp = wasm.base.comp;
    assert(comp.config.output_mode == .Obj);
    const gpa = comp.gpa;
    const gop = try wasm.symbol_table.getOrPut(gpa, wasm.preloaded_strings.__stack_pointer);
    gop.value_ptr.* = {};
    return @enumFromInt(gop.index);
}

pub fn tagNameSymbolIndex(wasm: *Wasm, ip_index: InternPool.Index) Allocator.Error!SymbolTableIndex {
    const comp = wasm.base.comp;
    assert(comp.config.output_mode == .Obj);
    const gpa = comp.gpa;
    const name = try wasm.internStringFmt("__zig_tag_name_{d}", .{@intFromEnum(ip_index)});
    const gop = try wasm.symbol_table.getOrPut(gpa, name);
    gop.value_ptr.* = {};
    return @enumFromInt(gop.index);
}

pub fn symbolNameIndex(wasm: *Wasm, name: String) Allocator.Error!SymbolTableIndex {
    const comp = wasm.base.comp;
    assert(comp.config.output_mode == .Obj);
    const gpa = comp.gpa;
    const gop = try wasm.symbol_table.getOrPut(gpa, name);
    gop.value_ptr.* = {};
    return @enumFromInt(gop.index);
}

pub fn refUavObj(wasm: *Wasm, pt: Zcu.PerThread, ip_index: InternPool.Index) !UavsObjIndex {
    const comp = wasm.base.comp;
    const gpa = comp.gpa;
    assert(comp.config.output_mode == .Obj);
    const gop = try wasm.uavs_obj.getOrPut(gpa, ip_index);
    if (!gop.found_existing) gop.value_ptr.* = try lowerZcuData(wasm, pt, ip_index);
    const uav_index: UavsObjIndex = @enumFromInt(gop.index);
    try wasm.data_segments.put(gpa, .pack(wasm, .{ .uav_obj = uav_index }), {});
    return uav_index;
}

pub fn refUavExe(wasm: *Wasm, pt: Zcu.PerThread, ip_index: InternPool.Index) !UavsExeIndex {
    const comp = wasm.base.comp;
    const gpa = comp.gpa;
    assert(comp.config.output_mode != .Obj);
    const gop = try wasm.uavs_exe.getOrPut(gpa, ip_index);
    if (gop.found_existing) {
        gop.value_ptr.count += 1;
    } else {
        const zcu_data = try lowerZcuData(wasm, pt, ip_index);
        gop.value_ptr.* = .{
            .code = zcu_data.code,
            .count = 1,
        };
    }
    const uav_index: UavsExeIndex = @enumFromInt(gop.index);
    try wasm.data_segments.put(gpa, .pack(wasm, .{ .uav_exe = uav_index }), {});
    return uav_index;
}

/// Asserts it is called after `Flush.data_segments` is fully populated and sorted.
pub fn uavAddr(wasm: *Wasm, uav_index: UavsExeIndex) u32 {
    assert(wasm.flush_buffer.memory_layout_finished);
    const comp = wasm.base.comp;
    assert(comp.config.output_mode != .Obj);
    const ds_id: DataSegment.Id = .pack(wasm, .{ .uav_exe = uav_index });
    return wasm.flush_buffer.data_segments.get(ds_id).?;
}

/// Asserts it is called after `Flush.data_segments` is fully populated and sorted.
pub fn navAddr(wasm: *Wasm, nav_index: InternPool.Nav.Index) u32 {
    assert(wasm.flush_buffer.memory_layout_finished);
    const comp = wasm.base.comp;
    assert(comp.config.output_mode != .Obj);
    const ds_id: DataSegment.Id = .pack(wasm, .{ .nav_exe = @enumFromInt(wasm.navs_exe.getIndex(nav_index).?) });
    return wasm.flush_buffer.data_segments.get(ds_id).?;
}

/// Asserts it is called after `Flush.data_segments` is fully populated and sorted.
pub fn errorNameTableAddr(wasm: *Wasm) u32 {
    assert(wasm.flush_buffer.memory_layout_finished);
    const comp = wasm.base.comp;
    assert(comp.config.output_mode != .Obj);
    return wasm.flush_buffer.data_segments.get(.__zig_error_name_table).?;
}

fn convertZcuFnType(
    comp: *Compilation,
    cc: std.builtin.CallingConvention,
    params: []const InternPool.Index,
    return_type: ZcuType,
    target: *const std.Target,
    params_buffer: *std.ArrayListUnmanaged(std.wasm.Valtype),
    returns_buffer: *std.ArrayListUnmanaged(std.wasm.Valtype),
) Allocator.Error!void {
    params_buffer.clearRetainingCapacity();
    returns_buffer.clearRetainingCapacity();

    const gpa = comp.gpa;
    const zcu = comp.zcu.?;

    if (CodeGen.firstParamSRet(cc, return_type, zcu, target)) {
        try params_buffer.append(gpa, .i32); // memory address is always a 32-bit handle
    } else if (return_type.hasRuntimeBitsIgnoreComptime(zcu)) {
        if (cc == .wasm_watc) {
            const res_classes = abi.classifyType(return_type, zcu);
            assert(res_classes[0] == .direct and res_classes[1] == .none);
            const scalar_type = abi.scalarType(return_type, zcu);
            try returns_buffer.append(gpa, CodeGen.typeToValtype(scalar_type, zcu, target));
        } else {
            try returns_buffer.append(gpa, CodeGen.typeToValtype(return_type, zcu, target));
        }
    } else if (return_type.isError(zcu)) {
        try returns_buffer.append(gpa, .i32);
    }

    // param types
    for (params) |param_type_ip| {
        const param_type = ZcuType.fromInterned(param_type_ip);
        if (!param_type.hasRuntimeBitsIgnoreComptime(zcu)) continue;

        switch (cc) {
            .wasm_watc => {
                const param_classes = abi.classifyType(param_type, zcu);
                if (param_classes[1] == .none) {
                    if (param_classes[0] == .direct) {
                        const scalar_type = abi.scalarType(param_type, zcu);
                        try params_buffer.append(gpa, CodeGen.typeToValtype(scalar_type, zcu, target));
                    } else {
                        try params_buffer.append(gpa, CodeGen.typeToValtype(param_type, zcu, target));
                    }
                } else {
                    // i128/f128
                    try params_buffer.append(gpa, .i64);
                    try params_buffer.append(gpa, .i64);
                }
            },
            else => try params_buffer.append(gpa, CodeGen.typeToValtype(param_type, zcu, target)),
        }
    }
}

pub fn isBss(wasm: *const Wasm, optional_name: OptionalString) bool {
    const s = optional_name.slice(wasm) orelse return false;
    return mem.eql(u8, s, ".bss") or mem.startsWith(u8, s, ".bss.");
}

fn lowerZcuData(wasm: *Wasm, pt: Zcu.PerThread, ip_index: InternPool.Index) !ZcuDataObj {
    const code_start: u32 = @intCast(wasm.string_bytes.items.len);
    const relocs_start: u32 = @intCast(wasm.out_relocs.len);
    wasm.string_bytes_lock.lock();

    try codegen.generateSymbol(&wasm.base, pt, .unneeded, .fromInterned(ip_index), &wasm.string_bytes, .none);

    const code_len: u32 = @intCast(wasm.string_bytes.items.len - code_start);
    const relocs_len: u32 = @intCast(wasm.out_relocs.len - relocs_start);
    wasm.string_bytes_lock.unlock();

    const naive_code: DataSegment.Payload = .{
        .off = @enumFromInt(code_start),
        .len = code_len,
    };

    // Only nonzero init values need to take up space in the output.
    const all_zeroes = std.mem.allEqual(u8, naive_code.slice(wasm), 0);
    const code: DataSegment.Payload = if (!all_zeroes) naive_code else c: {
        wasm.string_bytes.shrinkRetainingCapacity(code_start);
        // Indicate empty by making off and len the same value, however, still
        // transmit the data size by using the size as that value.
        break :c .{
            .off = .none,
            .len = naive_code.len,
        };
    };

    return .{
        .code = code,
        .relocs = .{
            .off = relocs_start,
            .len = relocs_len,
        },
    };
}

fn pointerAlignment(wasm: *const Wasm) Alignment {
    const target = &wasm.base.comp.root_mod.resolved_target.result;
    return switch (target.cpu.arch) {
        .wasm32 => .@"4",
        .wasm64 => .@"8",
        else => unreachable,
    };
}

fn addZcuImportReserved(wasm: *Wasm, nav_index: InternPool.Nav.Index) ZcuImportIndex {
    const gop = wasm.imports.getOrPutAssumeCapacity(nav_index);
    gop.value_ptr.* = {};
    return @enumFromInt(gop.index);
}
