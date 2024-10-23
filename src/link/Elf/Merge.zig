pub const Section = struct {
    value: u64 = 0,
    size: u64 = 0,
    alignment: Atom.Alignment = .@"1",
    entsize: u32 = 0,
    name_offset: u32 = 0,
    type: u32 = 0,
    flags: u64 = 0,
    output_section_index: u32 = 0,
    bytes: std.ArrayListUnmanaged(u8) = .empty,
    table: std.HashMapUnmanaged(
        String,
        Subsection.Index,
        IndexContext,
        std.hash_map.default_max_load_percentage,
    ) = .{},
    subsections: std.ArrayListUnmanaged(Subsection) = .empty,
    finalized_subsections: std.ArrayListUnmanaged(Subsection.Index) = .empty,

    pub fn deinit(msec: *Section, allocator: Allocator) void {
        msec.bytes.deinit(allocator);
        msec.table.deinit(allocator);
        msec.subsections.deinit(allocator);
        msec.finalized_subsections.deinit(allocator);
    }

    pub fn name(msec: Section, elf_file: *Elf) [:0]const u8 {
        return elf_file.getShString(msec.name_offset);
    }

    pub fn address(msec: Section, elf_file: *Elf) i64 {
        const shdr = elf_file.sections.items(.shdr)[msec.output_section_index];
        return @intCast(shdr.sh_addr + msec.value);
    }

    const InsertResult = struct {
        found_existing: bool,
        key: String,
        sub: *Subsection.Index,
    };

    pub fn insert(msec: *Section, allocator: Allocator, string: []const u8) !InsertResult {
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

    pub fn insertZ(msec: *Section, allocator: Allocator, string: []const u8) !InsertResult {
        const with_null = try allocator.alloc(u8, string.len + 1);
        defer allocator.free(with_null);
        @memcpy(with_null[0..string.len], string);
        with_null[string.len] = 0;
        return msec.insert(allocator, with_null);
    }

    /// Finalizes the merge section and clears hash table.
    /// Sorts all owned subsections.
    pub fn finalize(msec: *Section, allocator: Allocator) !void {
        try msec.finalized_subsections.ensureTotalCapacityPrecise(allocator, msec.subsections.items.len);

        var it = msec.table.iterator();
        while (it.next()) |entry| {
            const msub = msec.mergeSubsection(entry.value_ptr.*);
            if (!msub.alive) continue;
            msec.finalized_subsections.appendAssumeCapacity(entry.value_ptr.*);
        }
        msec.table.clearAndFree(allocator);

        const sortFn = struct {
            pub fn sortFn(ctx: *Section, lhs: Subsection.Index, rhs: Subsection.Index) bool {
                const lhs_msub = ctx.mergeSubsection(lhs);
                const rhs_msub = ctx.mergeSubsection(rhs);
                if (lhs_msub.alignment.compareStrict(.eq, rhs_msub.alignment)) {
                    if (lhs_msub.size == rhs_msub.size) {
                        const lhs_string = ctx.bytes.items[lhs_msub.string_index..][0..lhs_msub.size];
                        const rhs_string = ctx.bytes.items[rhs_msub.string_index..][0..rhs_msub.size];
                        return mem.order(u8, lhs_string, rhs_string) == .lt;
                    }
                    return lhs_msub.size < rhs_msub.size;
                }
                return lhs_msub.alignment.compareStrict(.lt, rhs_msub.alignment);
            }
        }.sortFn;

        std.mem.sort(Subsection.Index, msec.finalized_subsections.items, msec, sortFn);
    }

    pub fn updateSize(msec: *Section) void {
        // TODO a 'stale' flag would be better here perhaps?
        msec.size = 0;
        msec.alignment = .@"1";
        msec.entsize = 0;
        for (msec.finalized_subsections.items) |msub_index| {
            const msub = msec.mergeSubsection(msub_index);
            assert(msub.alive);
            const offset = msub.alignment.forward(msec.size);
            const padding = offset - msec.size;
            msub.value = @intCast(offset);
            msec.size += padding + msub.size;
            msec.alignment = msec.alignment.max(msub.alignment);
            msec.entsize = if (msec.entsize == 0) msub.entsize else @min(msec.entsize, msub.entsize);
        }
    }

    pub fn initOutputSection(msec: *Section, elf_file: *Elf) !void {
        msec.output_section_index = elf_file.sectionByName(msec.name(elf_file)) orelse try elf_file.addSection(.{
            .name = msec.name_offset,
            .type = msec.type,
            .flags = msec.flags,
        });
    }

    pub fn addMergeSubsection(msec: *Section, allocator: Allocator) !Subsection.Index {
        const index: Subsection.Index = @intCast(msec.subsections.items.len);
        const msub = try msec.subsections.addOne(allocator);
        msub.* = .{};
        return index;
    }

    pub fn mergeSubsection(msec: *Section, index: Subsection.Index) *Subsection {
        assert(index < msec.subsections.items.len);
        return &msec.subsections.items[index];
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
        msec: Section,
        comptime unused_fmt_string: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = msec;
        _ = unused_fmt_string;
        _ = options;
        _ = writer;
        @compileError("do not format directly");
    }

    pub fn fmt(msec: Section, elf_file: *Elf) std.fmt.Formatter(format2) {
        return .{ .data = .{
            .msec = msec,
            .elf_file = elf_file,
        } };
    }

    const FormatContext = struct {
        msec: Section,
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
        try writer.print("{s} : @{x} : size({x}) : align({x}) : entsize({x}) : type({x}) : flags({x})\n", .{
            msec.name(elf_file),
            msec.address(elf_file),
            msec.size,
            msec.alignment.toByteUnits() orelse 0,
            msec.entsize,
            msec.type,
            msec.flags,
        });
        for (msec.subsections.items) |msub| {
            try writer.print("   {}\n", .{msub.fmt(elf_file)});
        }
    }

    pub const Index = u32;
};

pub const Subsection = struct {
    value: i64 = 0,
    merge_section_index: Section.Index = 0,
    string_index: u32 = 0,
    size: u32 = 0,
    alignment: Atom.Alignment = .@"1",
    entsize: u32 = 0,
    alive: bool = false,

    pub fn address(msub: Subsection, elf_file: *Elf) i64 {
        return msub.mergeSection(elf_file).address(elf_file) + msub.value;
    }

    pub fn mergeSection(msub: Subsection, elf_file: *Elf) *Section {
        return elf_file.mergeSection(msub.merge_section_index);
    }

    pub fn getString(msub: Subsection, elf_file: *Elf) []const u8 {
        const msec = msub.mergeSection(elf_file);
        return msec.bytes.items[msub.string_index..][0..msub.size];
    }

    pub fn format(
        msub: Subsection,
        comptime unused_fmt_string: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = msub;
        _ = unused_fmt_string;
        _ = options;
        _ = writer;
        @compileError("do not format directly");
    }

    pub fn fmt(msub: Subsection, elf_file: *Elf) std.fmt.Formatter(format2) {
        return .{ .data = .{
            .msub = msub,
            .elf_file = elf_file,
        } };
    }

    const FormatContext = struct {
        msub: Subsection,
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

pub const InputSection = struct {
    merge_section_index: Section.Index = 0,
    atom_index: Atom.Index = 0,
    offsets: std.ArrayListUnmanaged(u32) = .empty,
    subsections: std.ArrayListUnmanaged(Subsection.Index) = .empty,
    bytes: std.ArrayListUnmanaged(u8) = .empty,
    strings: std.ArrayListUnmanaged(String) = .empty,

    pub fn deinit(imsec: *InputSection, allocator: Allocator) void {
        imsec.offsets.deinit(allocator);
        imsec.subsections.deinit(allocator);
        imsec.bytes.deinit(allocator);
        imsec.strings.deinit(allocator);
    }

    pub fn clearAndFree(imsec: *InputSection, allocator: Allocator) void {
        imsec.bytes.clearAndFree(allocator);
        // TODO: imsec.strings.clearAndFree(allocator);
    }

    const FindSubsectionResult = struct {
        msub_index: Subsection.Index,
        offset: u32,
    };

    pub fn findSubsection(imsec: InputSection, offset: u32) ?FindSubsectionResult {
        // TODO: binary search
        for (imsec.offsets.items, 0..) |off, index| {
            if (offset < off) return .{
                .msub_index = imsec.subsections.items[index - 1],
                .offset = offset - imsec.offsets.items[index - 1],
            };
        }
        const last = imsec.offsets.items.len - 1;
        const last_off = imsec.offsets.items[last];
        const last_len = imsec.strings.items[last].len;
        if (offset < last_off + last_len) return .{
            .msub_index = imsec.subsections.items[last],
            .offset = offset - last_off,
        };
        return null;
    }

    pub fn insert(imsec: *InputSection, allocator: Allocator, string: []const u8) !void {
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
const Merge = @This();
