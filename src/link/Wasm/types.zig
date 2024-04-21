//! This file contains all constants and related to wasm's object format.

const std = @import("std");

pub const Relocation = struct {
    /// Represents the type of the `Relocation`
    relocation_type: RelocationType,
    /// Offset of the value to rewrite relative to the relevant section's contents.
    /// When `offset` is zero, its position is immediately after the id and size of the section.
    offset: u32,
    /// The index of the symbol used.
    /// When the type is `R_WASM_TYPE_INDEX_LEB`, it represents the index of the type.
    index: u32,
    /// Addend to add to the address.
    /// This field is only non-zero for `R_WASM_MEMORY_ADDR_*`, `R_WASM_FUNCTION_OFFSET_I32` and `R_WASM_SECTION_OFFSET_I32`.
    addend: i32 = 0,

    /// All possible relocation types currently existing.
    /// This enum is exhaustive as the spec is WIP and new types
    /// can be added which means that a generated binary will be invalid,
    /// so instead we will show an error in such cases.
    pub const RelocationType = enum(u8) {
        R_WASM_FUNCTION_INDEX_LEB = 0,
        R_WASM_TABLE_INDEX_SLEB = 1,
        R_WASM_TABLE_INDEX_I32 = 2,
        R_WASM_MEMORY_ADDR_LEB = 3,
        R_WASM_MEMORY_ADDR_SLEB = 4,
        R_WASM_MEMORY_ADDR_I32 = 5,
        R_WASM_TYPE_INDEX_LEB = 6,
        R_WASM_GLOBAL_INDEX_LEB = 7,
        R_WASM_FUNCTION_OFFSET_I32 = 8,
        R_WASM_SECTION_OFFSET_I32 = 9,
        R_WASM_EVENT_INDEX_LEB = 10,
        R_WASM_GLOBAL_INDEX_I32 = 13,
        R_WASM_MEMORY_ADDR_LEB64 = 14,
        R_WASM_MEMORY_ADDR_SLEB64 = 15,
        R_WASM_MEMORY_ADDR_I64 = 16,
        R_WASM_TABLE_INDEX_SLEB64 = 18,
        R_WASM_TABLE_INDEX_I64 = 19,
        R_WASM_TABLE_NUMBER_LEB = 20,
        R_WASM_MEMORY_ADDR_TLS_SLEB = 21,
        R_WASM_MEMORY_ADDR_TLS_SLEB64 = 25,

        /// Returns true for relocation types where the `addend` field is present.
        pub fn addendIsPresent(self: RelocationType) bool {
            return switch (self) {
                .R_WASM_MEMORY_ADDR_LEB,
                .R_WASM_MEMORY_ADDR_SLEB,
                .R_WASM_MEMORY_ADDR_I32,
                .R_WASM_MEMORY_ADDR_LEB64,
                .R_WASM_MEMORY_ADDR_SLEB64,
                .R_WASM_MEMORY_ADDR_I64,
                .R_WASM_MEMORY_ADDR_TLS_SLEB,
                .R_WASM_MEMORY_ADDR_TLS_SLEB64,
                .R_WASM_FUNCTION_OFFSET_I32,
                .R_WASM_SECTION_OFFSET_I32,
                => true,
                else => false,
            };
        }
    };

    /// Verifies the relocation type of a given `Relocation` and returns
    /// true when the relocation references a function call or address to a function.
    pub fn isFunction(self: Relocation) bool {
        return switch (self.relocation_type) {
            .R_WASM_FUNCTION_INDEX_LEB,
            .R_WASM_TABLE_INDEX_SLEB,
            => true,
            else => false,
        };
    }

    pub fn format(self: Relocation, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;
        try writer.print("{s} offset=0x{x:0>6} symbol={d}", .{
            @tagName(self.relocation_type),
            self.offset,
            self.index,
        });
    }
};

/// Unlike the `Import` object defined by the wasm spec, and existing
/// in the std.wasm namespace, this construct saves the 'module name' and 'name'
/// of the import using offsets into a string table, rather than the slices itself.
/// This saves us (potentially) 24 bytes per import on 64bit machines.
pub const Import = struct {
    module_name: u32,
    name: u32,
    kind: std.wasm.Import.Kind,
};

/// Unlike the `Export` object defined by the wasm spec, and existing
/// in the std.wasm namespace, this construct saves the 'name'
/// of the export using offsets into a string table, rather than the slice itself.
/// This saves us (potentially) 12 bytes per export on 64bit machines.
pub const Export = struct {
    name: u32,
    index: u32,
    kind: std.wasm.ExternalKind,
};

pub const SubsectionType = enum(u8) {
    WASM_SEGMENT_INFO = 5,
    WASM_INIT_FUNCS = 6,
    WASM_COMDAT_INFO = 7,
    WASM_SYMBOL_TABLE = 8,
};

pub const Alignment = @import("../../InternPool.zig").Alignment;

pub const Segment = struct {
    /// Segment's name, encoded as UTF-8 bytes.
    name: []const u8,
    /// The required alignment of the segment, encoded as a power of 2
    alignment: Alignment,
    /// Bitfield containing flags for a segment
    flags: u32,

    pub fn isTLS(segment: Segment) bool {
        return segment.flags & @intFromEnum(Flags.WASM_SEG_FLAG_TLS) != 0;
    }

    /// Returns the name as how it will be output into the final object
    /// file or binary. When `merge_segments` is true, this will return the
    /// short name. i.e. ".rodata". When false, it returns the entire name instead.
    pub fn outputName(segment: Segment, merge_segments: bool) []const u8 {
        if (segment.isTLS()) {
            return ".tdata";
        } else if (!merge_segments) {
            return segment.name;
        } else if (std.mem.startsWith(u8, segment.name, ".rodata.")) {
            return ".rodata";
        } else if (std.mem.startsWith(u8, segment.name, ".text.")) {
            return ".text";
        } else if (std.mem.startsWith(u8, segment.name, ".data.")) {
            return ".data";
        } else if (std.mem.startsWith(u8, segment.name, ".bss.")) {
            return ".bss";
        }
        return segment.name;
    }

    pub const Flags = enum(u32) {
        WASM_SEG_FLAG_STRINGS = 0x1,
        WASM_SEG_FLAG_TLS = 0x2,
    };
};

pub const InitFunc = struct {
    /// Priority of the init function
    priority: u32,
    /// The symbol index of init function (not the function index).
    symbol_index: u32,
};

pub const Comdat = struct {
    name: []const u8,
    /// Must be zero, no flags are currently defined by the tool-convention.
    flags: u32,
    symbols: []const ComdatSym,
};

pub const ComdatSym = struct {
    kind: Type,
    /// Index of the data segment/function/global/event/table within a WASM module.
    /// The object must not be an import.
    index: u32,

    pub const Type = enum(u8) {
        WASM_COMDAT_DATA = 0,
        WASM_COMDAT_FUNCTION = 1,
        WASM_COMDAT_GLOBAL = 2,
        WASM_COMDAT_EVENT = 3,
        WASM_COMDAT_TABLE = 4,
        WASM_COMDAT_SECTION = 5,
    };
};

pub const Feature = struct {
    /// Provides information about the usage of the feature.
    /// - '0x2b' (+): Object uses this feature, and the link fails if feature is not in the allowed set.
    /// - '0x2d' (-): Object does not use this feature, and the link fails if this feature is in the allowed set.
    /// - '0x3d' (=): Object uses this feature, and the link fails if this feature is not in the allowed set,
    /// or if any object does not use this feature.
    prefix: Prefix,
    /// Type of the feature, must be unique in the sequence of features.
    tag: Tag,

    /// Unlike `std.Target.wasm.Feature` this also contains linker-features such as shared-mem
    pub const Tag = enum {
        atomics,
        bulk_memory,
        exception_handling,
        extended_const,
        multivalue,
        mutable_globals,
        nontrapping_fptoint,
        reference_types,
        relaxed_simd,
        sign_ext,
        simd128,
        tail_call,
        shared_mem,

        /// From a given cpu feature, returns its linker feature
        pub fn fromCpuFeature(feature: std.Target.wasm.Feature) Tag {
            return @as(Tag, @enumFromInt(@intFromEnum(feature)));
        }

        pub fn format(tag: Tag, comptime fmt: []const u8, opt: std.fmt.FormatOptions, writer: anytype) !void {
            _ = fmt;
            _ = opt;
            try writer.writeAll(switch (tag) {
                .atomics => "atomics",
                .bulk_memory => "bulk-memory",
                .exception_handling => "exception-handling",
                .extended_const => "extended-const",
                .multivalue => "multivalue",
                .mutable_globals => "mutable-globals",
                .nontrapping_fptoint => "nontrapping-fptoint",
                .reference_types => "reference-types",
                .relaxed_simd => "relaxed-simd",
                .sign_ext => "sign-ext",
                .simd128 => "simd128",
                .tail_call => "tail-call",
                .shared_mem => "shared-mem",
            });
        }
    };

    pub const Prefix = enum(u8) {
        used = '+',
        disallowed = '-',
        required = '=',
    };

    pub fn format(feature: Feature, comptime fmt: []const u8, opt: std.fmt.FormatOptions, writer: anytype) !void {
        _ = opt;
        _ = fmt;
        try writer.print("{c} {}", .{ feature.prefix, feature.tag });
    }
};

pub const known_features = std.StaticStringMap(Feature.Tag).initComptime(.{
    .{ "atomics", .atomics },
    .{ "bulk-memory", .bulk_memory },
    .{ "exception-handling", .exception_handling },
    .{ "extended-const", .extended_const },
    .{ "multivalue", .multivalue },
    .{ "mutable-globals", .mutable_globals },
    .{ "nontrapping-fptoint", .nontrapping_fptoint },
    .{ "reference-types", .reference_types },
    .{ "relaxed-simd", .relaxed_simd },
    .{ "sign-ext", .sign_ext },
    .{ "simd128", .simd128 },
    .{ "tail-call", .tail_call },
    .{ "shared-mem", .shared_mem },
});
