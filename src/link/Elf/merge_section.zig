pub const MergeSection = struct {
    name_offset: u32 = 0,
    type: u32 = 0,
    flags: u64 = 0,
    output_section_index: u32 = 0,
    bytes: std.ArrayListUnmanaged(u8) = .{},
    table: std.HashMapUnmanaged(
        String,
        MergeSubsection.Index,
        IndexContext,
        std.hash_map.default_max_load_percentage,
    ) = .{},
    subsections: std.ArrayListUnmanaged(MergeSubsection.Index) = .{},

    pub fn deinit(msec: *MergeSection, allocator: Allocator) void {
        msec.bytes.deinit(allocator);
        msec.table.deinit(allocator);
        msec.subsections.deinit(allocator);
    }

    pub fn name(msec: MergeSection, elf_file: *Elf) [:0]const u8 {
        return elf_file.strings.getAssumeExists(msec.name_offset);
    }

    pub fn address(msec: MergeSection, elf_file: *Elf) i64 {
        const shdr = elf_file.shdrs.items[msec.output_section_index];
        return @intCast(shdr.sh_addr);
    }

    const InsertResult = struct {
        found_existing: bool,
        key: String,
        sub: *MergeSubsection.Index,
    };

    pub fn insert(msec: *MergeSection, allocator: Allocator, string: []const u8) !InsertResult {
        const gop = try msec.table.getOrPutContextAdapted(
            allocator,
            string,
            IndexAdapter{ .bytes = msec.bytes.items },
            IndexContext{ .bytes = msec.bytes.items },
        );
        if (!gop.found_existing) {
            const index: u32 = @intCast(msec.bytes.items.len);
            try msec.bytes.appendSlice(allocator, string);
            gop.key_ptr.* = .{ .pos = index, .len = @intCast(string.len) };
        }
        return .{ .found_existing = gop.found_existing, .key = gop.key_ptr.*, .sub = gop.value_ptr };
    }

    pub fn insertZ(msec: *MergeSection, allocator: Allocator, string: []const u8) !InsertResult {
        const with_null = try allocator.alloc(u8, string.len + 1);
        defer allocator.free(with_null);
        @memcpy(with_null[0..string.len], string);
        with_null[string.len] = 0;
        return msec.insert(allocator, with_null);
    }

    /// Finalizes the merge section and clears hash table.
    /// Sorts all owned subsections.
    pub fn finalize(msec: *MergeSection, elf_file: *Elf) !void {
        const gpa = elf_file.base.comp.gpa;
        try msec.subsections.ensureTotalCapacityPrecise(gpa, msec.table.count());

        var it = msec.table.iterator();
        while (it.next()) |entry| {
            const msub = elf_file.mergeSubsection(entry.value_ptr.*);
            if (!msub.alive) continue;
            msec.subsections.appendAssumeCapacity(entry.value_ptr.*);
        }
        msec.table.clearAndFree(gpa);

        const sortFn = struct {
            pub fn sortFn(ctx: *Elf, lhs: MergeSubsection.Index, rhs: MergeSubsection.Index) bool {
                const lhs_msub = ctx.mergeSubsection(lhs);
                const rhs_msub = ctx.mergeSubsection(rhs);
                if (lhs_msub.alignment.compareStrict(.eq, rhs_msub.alignment)) {
                    if (lhs_msub.size == rhs_msub.size) {
                        return mem.order(u8, lhs_msub.getString(ctx), rhs_msub.getString(ctx)) == .lt;
                    }
                    return lhs_msub.size < rhs_msub.size;
                }
                return lhs_msub.alignment.compareStrict(.lt, rhs_msub.alignment);
            }
        }.sortFn;

        std.mem.sort(MergeSubsection.Index, msec.subsections.items, elf_file, sortFn);
    }

    pub const IndexContext = struct {
        bytes: []const u8,

        pub fn eql(_: @This(), a: String, b: String) bool {
            return a.pos == b.pos;
        }

        pub fn hash(ctx: @This(), key: String) u64 {
            const str = ctx.bytes[key.pos..][0..key.len];
            return std.hash_map.hashString(str);
        }
    };

    pub const IndexAdapter = struct {
        bytes: []const u8,

        pub fn eql(ctx: @This(), a: []const u8, b: String) bool {
            const str = ctx.bytes[b.pos..][0..b.len];
            return mem.eql(u8, a, str);
        }

        pub fn hash(_: @This(), adapted_key: []const u8) u64 {
            return std.hash_map.hashString(adapted_key);
        }
    };

    pub fn format(
        msec: MergeSection,
        comptime unused_fmt_string: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = msec;
        _ = unused_fmt_string;
        _ = options;
        _ = writer;
        @compileError("do not format MergeSection directly");
    }

    pub fn fmt(msec: MergeSection, elf_file: *Elf) std.fmt.Formatter(format2) {
        return .{ .data = .{
            .msec = msec,
            .elf_file = elf_file,
        } };
    }

    const FormatContext = struct {
        msec: MergeSection,
        elf_file: *Elf,
    };

    pub fn format2(
        ctx: FormatContext,
        comptime unused_fmt_string: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = options;
        _ = unused_fmt_string;
        const msec = ctx.msec;
        const elf_file = ctx.elf_file;
        try writer.print("{s} : @{x} : type({x}) : flags({x})\n", .{
            msec.name(elf_file),
            msec.address(elf_file),
            msec.type,
            msec.flags,
        });
        for (msec.subsections.items) |index| {
            try writer.print("   {}\n", .{elf_file.mergeSubsection(index).fmt(elf_file)});
        }
    }

    pub const Index = u32;
};

pub const MergeSubsection = struct {
    value: i64 = 0,
    merge_section_index: MergeSection.Index = 0,
    string_index: u32 = 0,
    size: u32 = 0,
    alignment: Atom.Alignment = .@"1",
    entsize: u32 = 0,
    alive: bool = false,

    pub fn address(msub: MergeSubsection, elf_file: *Elf) i64 {
        return msub.mergeSection(elf_file).address(elf_file) + msub.value;
    }

    pub fn mergeSection(msub: MergeSubsection, elf_file: *Elf) *MergeSection {
        return elf_file.mergeSection(msub.merge_section_index);
    }

    pub fn getString(msub: MergeSubsection, elf_file: *Elf) []const u8 {
        const msec = msub.mergeSection(elf_file);
        return msec.bytes.items[msub.string_index..][0..msub.size];
    }

    pub fn format(
        msub: MergeSubsection,
        comptime unused_fmt_string: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = msub;
        _ = unused_fmt_string;
        _ = options;
        _ = writer;
        @compileError("do not format MergeSubsection directly");
    }

    pub fn fmt(msub: MergeSubsection, elf_file: *Elf) std.fmt.Formatter(format2) {
        return .{ .data = .{
            .msub = msub,
            .elf_file = elf_file,
        } };
    }

    const FormatContext = struct {
        msub: MergeSubsection,
        elf_file: *Elf,
    };

    pub fn format2(
        ctx: FormatContext,
        comptime unused_fmt_string: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = options;
        _ = unused_fmt_string;
        const msub = ctx.msub;
        const elf_file = ctx.elf_file;
        try writer.print("@{x} : align({x}) : size({x})", .{
            msub.address(elf_file),
            msub.alignment,
            msub.size,
        });
        if (!msub.alive) try writer.writeAll(" : [*]");
    }

    pub const Index = u32;
};

pub const InputMergeSection = struct {
    merge_section_index: MergeSection.Index = 0,
    atom_index: Atom.Index = 0,
    offsets: std.ArrayListUnmanaged(u32) = .{},
    subsections: std.ArrayListUnmanaged(MergeSubsection.Index) = .{},
    bytes: std.ArrayListUnmanaged(u8) = .{},
    strings: std.ArrayListUnmanaged(String) = .{},

    pub fn deinit(imsec: *InputMergeSection, allocator: Allocator) void {
        imsec.offsets.deinit(allocator);
        imsec.subsections.deinit(allocator);
        imsec.bytes.deinit(allocator);
        imsec.strings.deinit(allocator);
    }

    pub fn clearAndFree(imsec: *InputMergeSection, allocator: Allocator) void {
        imsec.bytes.clearAndFree(allocator);
        // TODO: imsec.strings.clearAndFree(allocator);
    }

    pub fn findSubsection(imsec: InputMergeSection, offset: u32) ?struct { MergeSubsection.Index, u32 } {
        // TODO: binary search
        for (imsec.offsets.items, 0..) |off, index| {
            if (offset < off) return .{
                imsec.subsections.items[index - 1],
                offset - imsec.offsets.items[index - 1],
            };
        }
        const last = imsec.offsets.items.len - 1;
        const last_off = imsec.offsets.items[last];
        const last_len = imsec.strings.items[last].len;
        if (offset < last_off + last_len) return .{ imsec.subsections.items[last], offset - last_off };
        return null;
    }

    pub fn insert(imsec: *InputMergeSection, allocator: Allocator, string: []const u8) !void {
        const index: u32 = @intCast(imsec.bytes.items.len);
        try imsec.bytes.appendSlice(allocator, string);
        try imsec.strings.append(allocator, .{ .pos = index, .len = @intCast(string.len) });
    }

    pub const Index = u32;
};

const String = struct { pos: u32, len: u32 };

const assert = std.debug.assert;
const mem = std.mem;
const std = @import("std");

const Allocator = mem.Allocator;
const Atom = @import("Atom.zig");
const Elf = @import("../Elf.zig");
