const builtin = @import("builtin");
const std = @import("std");
const mem = std.mem;
const fs = std.fs;
const elf = std.elf;
const Allocator = std.mem.Allocator;
const File = std.fs.File;
const assert = std.debug.assert;

const fatal = std.zig.fatal;
const Server = std.zig.Server;

pub fn main() !void {
    var arena_instance = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena_instance.deinit();
    const arena = arena_instance.allocator();

    var general_purpose_allocator: std.heap.GeneralPurposeAllocator(.{}) = .{};
    const gpa = general_purpose_allocator.allocator();

    const args = try std.process.argsAlloc(arena);
    return cmdObjCopy(gpa, arena, args[1..]);
}

fn cmdObjCopy(
    gpa: Allocator,
    arena: Allocator,
    args: []const []const u8,
) !void {
    var i: usize = 0;
    var opt_out_fmt: ?std.Target.ObjectFormat = null;
    var opt_input: ?[]const u8 = null;
    var opt_output: ?[]const u8 = null;
    var opt_extract: ?[]const u8 = null;
    var opt_add_debuglink: ?[]const u8 = null;
    var only_section: ?[]const u8 = null;
    var pad_to: ?u64 = null;
    var strip_all: bool = false;
    var strip_debug: bool = false;
    var only_keep_debug: bool = false;
    var compress_debug_sections: bool = false;
    var listen = false;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (!mem.startsWith(u8, arg, "-")) {
            if (opt_input == null) {
                opt_input = arg;
            } else if (opt_output == null) {
                opt_output = arg;
            } else {
                fatal("unexpected positional argument: '{s}'", .{arg});
            }
        } else if (mem.eql(u8, arg, "-h") or mem.eql(u8, arg, "--help")) {
            return std.io.getStdOut().writeAll(usage);
        } else if (mem.eql(u8, arg, "-O") or mem.eql(u8, arg, "--output-target")) {
            i += 1;
            if (i >= args.len) fatal("expected another argument after '{s}'", .{arg});
            const next_arg = args[i];
            if (mem.eql(u8, next_arg, "binary")) {
                opt_out_fmt = .raw;
            } else {
                opt_out_fmt = std.meta.stringToEnum(std.Target.ObjectFormat, next_arg) orelse
                    fatal("invalid output format: '{s}'", .{next_arg});
            }
        } else if (mem.startsWith(u8, arg, "--output-target=")) {
            const next_arg = arg["--output-target=".len..];
            if (mem.eql(u8, next_arg, "binary")) {
                opt_out_fmt = .raw;
            } else {
                opt_out_fmt = std.meta.stringToEnum(std.Target.ObjectFormat, next_arg) orelse
                    fatal("invalid output format: '{s}'", .{next_arg});
            }
        } else if (mem.eql(u8, arg, "-j") or mem.eql(u8, arg, "--only-section")) {
            i += 1;
            if (i >= args.len) fatal("expected another argument after '{s}'", .{arg});
            only_section = args[i];
        } else if (mem.eql(u8, arg, "--listen=-")) {
            listen = true;
        } else if (mem.startsWith(u8, arg, "--only-section=")) {
            only_section = arg["--only-section=".len..];
        } else if (mem.eql(u8, arg, "--pad-to")) {
            i += 1;
            if (i >= args.len) fatal("expected another argument after '{s}'", .{arg});
            pad_to = std.fmt.parseInt(u64, args[i], 0) catch |err| {
                fatal("unable to parse: '{s}': {s}", .{ args[i], @errorName(err) });
            };
        } else if (mem.eql(u8, arg, "-g") or mem.eql(u8, arg, "--strip-debug")) {
            strip_debug = true;
        } else if (mem.eql(u8, arg, "-S") or mem.eql(u8, arg, "--strip-all")) {
            strip_all = true;
        } else if (mem.eql(u8, arg, "--only-keep-debug")) {
            only_keep_debug = true;
        } else if (mem.eql(u8, arg, "--compress-debug-sections")) {
            compress_debug_sections = true;
        } else if (mem.startsWith(u8, arg, "--add-gnu-debuglink=")) {
            opt_add_debuglink = arg["--add-gnu-debuglink=".len..];
        } else if (mem.eql(u8, arg, "--add-gnu-debuglink")) {
            i += 1;
            if (i >= args.len) fatal("expected another argument after '{s}'", .{arg});
            opt_add_debuglink = args[i];
        } else if (mem.startsWith(u8, arg, "--extract-to=")) {
            opt_extract = arg["--extract-to=".len..];
        } else if (mem.eql(u8, arg, "--extract-to")) {
            i += 1;
            if (i >= args.len) fatal("expected another argument after '{s}'", .{arg});
            opt_extract = args[i];
        } else {
            fatal("unrecognized argument: '{s}'", .{arg});
        }
    }
    const input = opt_input orelse fatal("expected input parameter", .{});
    const output = opt_output orelse fatal("expected output parameter", .{});

    var in_file = fs.cwd().openFile(input, .{}) catch |err|
        fatal("unable to open '{s}': {s}", .{ input, @errorName(err) });
    defer in_file.close();

    const elf_hdr = std.elf.Header.read(in_file) catch |err| switch (err) {
        error.InvalidElfMagic => fatal("not an ELF file: '{s}'", .{input}),
        else => fatal("unable to read '{s}': {s}", .{ input, @errorName(err) }),
    };

    const in_ofmt = .elf;

    const out_fmt: std.Target.ObjectFormat = opt_out_fmt orelse ofmt: {
        if (mem.endsWith(u8, output, ".hex") or std.mem.endsWith(u8, output, ".ihex")) {
            break :ofmt .hex;
        } else if (mem.endsWith(u8, output, ".bin")) {
            break :ofmt .raw;
        } else if (mem.endsWith(u8, output, ".elf")) {
            break :ofmt .elf;
        } else {
            break :ofmt in_ofmt;
        }
    };

    const mode = mode: {
        if (out_fmt != .elf or only_keep_debug)
            break :mode fs.File.default_mode;
        if (in_file.stat()) |stat|
            break :mode stat.mode
        else |_|
            break :mode fs.File.default_mode;
    };
    var out_file = try fs.cwd().createFile(output, .{ .mode = mode });
    defer out_file.close();

    switch (out_fmt) {
        .hex, .raw => {
            if (strip_debug or strip_all or only_keep_debug)
                fatal("zig objcopy: ELF to RAW or HEX copying does not support --strip", .{});
            if (opt_extract != null)
                fatal("zig objcopy: ELF to RAW or HEX copying does not support --extract-to", .{});

            try emitElf(arena, in_file, out_file, elf_hdr, .{
                .ofmt = out_fmt,
                .only_section = only_section,
                .pad_to = pad_to,
            });
        },
        .elf => {
            if (elf_hdr.endian != builtin.target.cpu.arch.endian())
                fatal("zig objcopy: ELF to ELF copying only supports native endian", .{});
            if (elf_hdr.phoff == 0) // no program header
                fatal("zig objcopy: ELF to ELF copying only supports programs", .{});
            if (only_section) |_|
                fatal("zig objcopy: ELF to ELF copying does not support --only-section", .{});
            if (pad_to) |_|
                fatal("zig objcopy: ELF to ELF copying does not support --pad-to", .{});

            try stripElf(arena, in_file, out_file, elf_hdr, .{
                .strip_debug = strip_debug,
                .strip_all = strip_all,
                .only_keep_debug = only_keep_debug,
                .add_debuglink = opt_add_debuglink,
                .extract_to = opt_extract,
                .compress_debug = compress_debug_sections,
            });
            return std.process.cleanExit();
        },
        else => fatal("unsupported output object format: {s}", .{@tagName(out_fmt)}),
    }

    if (listen) {
        var server = try Server.init(.{
            .gpa = gpa,
            .in = std.io.getStdIn(),
            .out = std.io.getStdOut(),
            .zig_version = builtin.zig_version_string,
        });
        defer server.deinit();

        var seen_update = false;
        while (true) {
            const hdr = try server.receiveMessage();
            switch (hdr.tag) {
                .exit => {
                    return std.process.cleanExit();
                },
                .update => {
                    if (seen_update) {
                        std.debug.print("zig objcopy only supports 1 update for now\n", .{});
                        std.process.exit(1);
                    }
                    seen_update = true;

                    try server.serveEmitBinPath(output, .{
                        .flags = .{ .cache_hit = false },
                    });
                },
                else => {
                    std.debug.print("unsupported message: {s}", .{@tagName(hdr.tag)});
                    std.process.exit(1);
                },
            }
        }
    }
    return std.process.cleanExit();
}

const usage =
    \\Usage: zig objcopy [options] input output
    \\
    \\Options:
    \\  -h, --help                  Print this help and exit
    \\  --output-target=<value>     Format of the output file
    \\  -O <value>                  Alias for --output-target
    \\  --only-section=<section>    Remove all but <section>
    \\  -j <value>                  Alias for --only-section
    \\  --pad-to <addr>             Pad the last section up to address <addr>
    \\  --strip-debug, -g           Remove all debug sections from the output.
    \\  --strip-all, -S             Remove all debug sections and symbol table from the output.
    \\  --only-keep-debug           Strip a file, removing contents of any sections that would not be stripped by --strip-debug and leaving the debugging sections intact.
    \\  --add-gnu-debuglink=<file>  Creates a .gnu_debuglink section which contains a reference to <file> and adds it to the output file.
    \\  --extract-to <file>         Extract the removed sections into <file>, and add a .gnu-debuglink section.
    \\  --compress-debug-sections   Compress DWARF debug sections with zlib
    \\
;

pub const EmitRawElfOptions = struct {
    ofmt: std.Target.ObjectFormat,
    only_section: ?[]const u8 = null,
    pad_to: ?u64 = null,
};

fn emitElf(
    arena: Allocator,
    in_file: File,
    out_file: File,
    elf_hdr: elf.Header,
    options: EmitRawElfOptions,
) !void {
    var binary_elf_output = try BinaryElfOutput.parse(arena, in_file, elf_hdr);
    defer binary_elf_output.deinit();

    if (options.ofmt == .elf) {
        fatal("zig objcopy: ELF to ELF copying is not implemented yet", .{});
    }

    if (options.only_section) |target_name| {
        switch (options.ofmt) {
            .hex => fatal("zig objcopy: hex format with sections is not implemented yet", .{}),
            .raw => {
                for (binary_elf_output.sections.items) |section| {
                    if (section.name) |curr_name| {
                        if (!std.mem.eql(u8, curr_name, target_name))
                            continue;
                    } else {
                        continue;
                    }

                    try writeBinaryElfSection(in_file, out_file, section);
                    try padFile(out_file, options.pad_to);
                    return;
                }
            },
            else => unreachable,
        }

        return error.SectionNotFound;
    }

    switch (options.ofmt) {
        .raw => {
            for (binary_elf_output.sections.items) |section| {
                try out_file.seekTo(section.binaryOffset);
                try writeBinaryElfSection(in_file, out_file, section);
            }
            try padFile(out_file, options.pad_to);
        },
        .hex => {
            if (binary_elf_output.segments.items.len == 0) return;
            if (!containsValidAddressRange(binary_elf_output.segments.items)) {
                return error.InvalidHexfileAddressRange;
            }

            var hex_writer = HexWriter{ .out_file = out_file };
            for (binary_elf_output.segments.items) |segment| {
                try hex_writer.writeSegment(segment, in_file);
            }
            if (options.pad_to) |_| {
                // Padding to a size in hex files isn't applicable
                return error.InvalidArgument;
            }
            try hex_writer.writeEOF();
        },
        else => unreachable,
    }
}

const BinaryElfSection = struct {
    elfOffset: u64,
    binaryOffset: u64,
    fileSize: usize,
    name: ?[]const u8,
    segment: ?*BinaryElfSegment,
};

const BinaryElfSegment = struct {
    physicalAddress: u64,
    virtualAddress: u64,
    elfOffset: u64,
    binaryOffset: u64,
    fileSize: u64,
    firstSection: ?*BinaryElfSection,
};

const BinaryElfOutput = struct {
    segments: std.ArrayListUnmanaged(*BinaryElfSegment),
    sections: std.ArrayListUnmanaged(*BinaryElfSection),
    allocator: Allocator,
    shstrtab: ?[]const u8,

    const Self = @This();

    pub fn deinit(self: *Self) void {
        if (self.shstrtab) |shstrtab|
            self.allocator.free(shstrtab);
        self.sections.deinit(self.allocator);
        self.segments.deinit(self.allocator);
    }

    pub fn parse(allocator: Allocator, elf_file: File, elf_hdr: elf.Header) !Self {
        var self: Self = .{
            .segments = .{},
            .sections = .{},
            .allocator = allocator,
            .shstrtab = null,
        };
        errdefer self.sections.deinit(allocator);
        errdefer self.segments.deinit(allocator);

        self.shstrtab = blk: {
            if (elf_hdr.shstrndx >= elf_hdr.shnum) break :blk null;

            var section_headers = elf_hdr.section_header_iterator(&elf_file);

            var section_counter: usize = 0;
            while (section_counter < elf_hdr.shstrndx) : (section_counter += 1) {
                _ = (try section_headers.next()).?;
            }

            const shstrtab_shdr = (try section_headers.next()).?;

            const buffer = try allocator.alloc(u8, @intCast(shstrtab_shdr.sh_size));
            errdefer allocator.free(buffer);

            const num_read = try elf_file.preadAll(buffer, shstrtab_shdr.sh_offset);
            if (num_read != buffer.len) return error.EndOfStream;

            break :blk buffer;
        };

        errdefer if (self.shstrtab) |shstrtab| allocator.free(shstrtab);

        var section_headers = elf_hdr.section_header_iterator(&elf_file);
        while (try section_headers.next()) |section| {
            if (sectionValidForOutput(section)) {
                const newSection = try allocator.create(BinaryElfSection);

                newSection.binaryOffset = 0;
                newSection.elfOffset = section.sh_offset;
                newSection.fileSize = @intCast(section.sh_size);
                newSection.segment = null;

                newSection.name = if (self.shstrtab) |shstrtab|
                    std.mem.span(@as([*:0]const u8, @ptrCast(&shstrtab[section.sh_name])))
                else
                    null;

                try self.sections.append(allocator, newSection);
            }
        }

        var program_headers = elf_hdr.program_header_iterator(&elf_file);
        while (try program_headers.next()) |phdr| {
            if (phdr.p_type == elf.PT_LOAD) {
                const newSegment = try allocator.create(BinaryElfSegment);

                newSegment.physicalAddress = if (phdr.p_paddr != 0) phdr.p_paddr else phdr.p_vaddr;
                newSegment.virtualAddress = phdr.p_vaddr;
                newSegment.fileSize = @intCast(phdr.p_filesz);
                newSegment.elfOffset = phdr.p_offset;
                newSegment.binaryOffset = 0;
                newSegment.firstSection = null;

                for (self.sections.items) |section| {
                    if (sectionWithinSegment(section, phdr)) {
                        if (section.segment) |sectionSegment| {
                            if (sectionSegment.elfOffset > newSegment.elfOffset) {
                                section.segment = newSegment;
                            }
                        } else {
                            section.segment = newSegment;
                        }

                        if (newSegment.firstSection == null) {
                            newSegment.firstSection = section;
                        }
                    }
                }

                try self.segments.append(allocator, newSegment);
            }
        }

        mem.sort(*BinaryElfSegment, self.segments.items, {}, segmentSortCompare);

        for (self.segments.items, 0..) |firstSegment, i| {
            if (firstSegment.firstSection) |firstSection| {
                const diff = firstSection.elfOffset - firstSegment.elfOffset;

                firstSegment.elfOffset += diff;
                firstSegment.fileSize += diff;
                firstSegment.physicalAddress += diff;

                const basePhysicalAddress = firstSegment.physicalAddress;

                for (self.segments.items[i + 1 ..]) |segment| {
                    segment.binaryOffset = segment.physicalAddress - basePhysicalAddress;
                }
                break;
            }
        }

        for (self.sections.items) |section| {
            if (section.segment) |segment| {
                section.binaryOffset = segment.binaryOffset + (section.elfOffset - segment.elfOffset);
            }
        }

        mem.sort(*BinaryElfSection, self.sections.items, {}, sectionSortCompare);

        return self;
    }

    fn sectionWithinSegment(section: *BinaryElfSection, segment: elf.Elf64_Phdr) bool {
        return segment.p_offset <= section.elfOffset and (segment.p_offset + segment.p_filesz) >= (section.elfOffset + section.fileSize);
    }

    fn sectionValidForOutput(shdr: anytype) bool {
        return shdr.sh_type != elf.SHT_NOBITS and
            ((shdr.sh_flags & elf.SHF_ALLOC) == elf.SHF_ALLOC);
    }

    fn segmentSortCompare(context: void, left: *BinaryElfSegment, right: *BinaryElfSegment) bool {
        _ = context;
        if (left.physicalAddress < right.physicalAddress) {
            return true;
        }
        if (left.physicalAddress > right.physicalAddress) {
            return false;
        }
        return false;
    }

    fn sectionSortCompare(context: void, left: *BinaryElfSection, right: *BinaryElfSection) bool {
        _ = context;
        return left.binaryOffset < right.binaryOffset;
    }
};

fn writeBinaryElfSection(elf_file: File, out_file: File, section: *BinaryElfSection) !void {
    try out_file.writeFileAll(elf_file, .{
        .in_offset = section.elfOffset,
        .in_len = section.fileSize,
    });
}

const HexWriter = struct {
    prev_addr: ?u32 = null,
    out_file: File,

    /// Max data bytes per line of output
    const MAX_PAYLOAD_LEN: u8 = 16;

    fn addressParts(address: u16) [2]u8 {
        const msb: u8 = @truncate(address >> 8);
        const lsb: u8 = @truncate(address);
        return [2]u8{ msb, lsb };
    }

    const Record = struct {
        const Type = enum(u8) {
            Data = 0,
            EOF = 1,
            ExtendedSegmentAddress = 2,
            ExtendedLinearAddress = 4,
        };

        address: u16,
        payload: union(Type) {
            Data: []const u8,
            EOF: void,
            ExtendedSegmentAddress: [2]u8,
            ExtendedLinearAddress: [2]u8,
        },

        fn EOF() Record {
            return Record{
                .address = 0,
                .payload = .EOF,
            };
        }

        fn Data(address: u32, data: []const u8) Record {
            return Record{
                .address = @intCast(address % 0x10000),
                .payload = .{ .Data = data },
            };
        }

        fn Address(address: u32) Record {
            assert(address > 0xFFFF);
            const segment: u16 = @intCast(address / 0x10000);
            if (address > 0xFFFFF) {
                return Record{
                    .address = 0,
                    .payload = .{ .ExtendedLinearAddress = addressParts(segment) },
                };
            } else {
                return Record{
                    .address = 0,
                    .payload = .{ .ExtendedSegmentAddress = addressParts(segment << 12) },
                };
            }
        }

        fn getPayloadBytes(self: *const Record) []const u8 {
            return switch (self.payload) {
                .Data => |d| d,
                .EOF => @as([]const u8, &.{}),
                .ExtendedSegmentAddress, .ExtendedLinearAddress => |*seg| seg,
            };
        }

        fn checksum(self: Record) u8 {
            const payload_bytes = self.getPayloadBytes();

            var sum: u8 = @intCast(payload_bytes.len);
            const parts = addressParts(self.address);
            sum +%= parts[0];
            sum +%= parts[1];
            sum +%= @intFromEnum(self.payload);
            for (payload_bytes) |byte| {
                sum +%= byte;
            }
            return (sum ^ 0xFF) +% 1;
        }

        fn write(self: Record, file: File) File.WriteError!void {
            const linesep = "\r\n";
            // colon, (length, address, type, payload, checksum) as hex, CRLF
            const BUFSIZE = 1 + (1 + 2 + 1 + MAX_PAYLOAD_LEN + 1) * 2 + linesep.len;
            var outbuf: [BUFSIZE]u8 = undefined;
            const payload_bytes = self.getPayloadBytes();
            assert(payload_bytes.len <= MAX_PAYLOAD_LEN);

            const line = try std.fmt.bufPrint(&outbuf, ":{0X:0>2}{1X:0>4}{2X:0>2}{3s}{4X:0>2}" ++ linesep, .{
                @as(u8, @intCast(payload_bytes.len)),
                self.address,
                @intFromEnum(self.payload),
                std.fmt.fmtSliceHexUpper(payload_bytes),
                self.checksum(),
            });
            try file.writeAll(line);
        }
    };

    pub fn writeSegment(self: *HexWriter, segment: *const BinaryElfSegment, elf_file: File) !void {
        var buf: [MAX_PAYLOAD_LEN]u8 = undefined;
        var bytes_read: usize = 0;
        while (bytes_read < segment.fileSize) {
            const row_address: u32 = @intCast(segment.physicalAddress + bytes_read);

            const remaining = segment.fileSize - bytes_read;
            const to_read: usize = @intCast(@min(remaining, MAX_PAYLOAD_LEN));
            const did_read = try elf_file.preadAll(buf[0..to_read], segment.elfOffset + bytes_read);
            if (did_read < to_read) return error.UnexpectedEOF;

            try self.writeDataRow(row_address, buf[0..did_read]);

            bytes_read += did_read;
        }
    }

    fn writeDataRow(self: *HexWriter, address: u32, data: []const u8) File.WriteError!void {
        const record = Record.Data(address, data);
        if (address > 0xFFFF and (self.prev_addr == null or record.address != self.prev_addr.?)) {
            try Record.Address(address).write(self.out_file);
        }
        try record.write(self.out_file);
        self.prev_addr = @intCast(record.address + data.len);
    }

    fn writeEOF(self: HexWriter) File.WriteError!void {
        try Record.EOF().write(self.out_file);
    }
};

fn containsValidAddressRange(segments: []*BinaryElfSegment) bool {
    const max_address = std.math.maxInt(u32);
    for (segments) |segment| {
        if (segment.fileSize > max_address or
            segment.physicalAddress > max_address - segment.fileSize) return false;
    }
    return true;
}

fn padFile(f: File, opt_size: ?u64) !void {
    const size = opt_size orelse return;
    try f.setEndPos(size);
}

test "HexWriter.Record.Address has correct payload and checksum" {
    const record = HexWriter.Record.Address(0x0800_0000);
    const payload = record.getPayloadBytes();
    const sum = record.checksum();
    try std.testing.expect(sum == 0xF2);
    try std.testing.expect(payload.len == 2);
    try std.testing.expect(payload[0] == 8);
    try std.testing.expect(payload[1] == 0);
}

test "containsValidAddressRange" {
    var segment = BinaryElfSegment{
        .physicalAddress = 0,
        .virtualAddress = 0,
        .elfOffset = 0,
        .binaryOffset = 0,
        .fileSize = 0,
        .firstSection = null,
    };
    var buf: [1]*BinaryElfSegment = .{&segment};

    // segment too big
    segment.fileSize = std.math.maxInt(u32) + 1;
    try std.testing.expect(!containsValidAddressRange(&buf));

    // start address too big
    segment.physicalAddress = std.math.maxInt(u32) + 1;
    segment.fileSize = 2;
    try std.testing.expect(!containsValidAddressRange(&buf));

    // max address too big
    segment.physicalAddress = std.math.maxInt(u32) - 1;
    segment.fileSize = 2;
    try std.testing.expect(!containsValidAddressRange(&buf));

    // is ok
    segment.physicalAddress = std.math.maxInt(u32) - 1;
    segment.fileSize = 1;
    try std.testing.expect(containsValidAddressRange(&buf));
}

// -------------
// ELF to ELF stripping

const StripElfOptions = struct {
    extract_to: ?[]const u8 = null,
    add_debuglink: ?[]const u8 = null,
    strip_all: bool = false,
    strip_debug: bool = false,
    only_keep_debug: bool = false,
    compress_debug: bool = false,
};

fn stripElf(
    allocator: Allocator,
    in_file: File,
    out_file: File,
    elf_hdr: elf.Header,
    options: StripElfOptions,
) !void {
    const Filter = ElfFileHelper.Filter;
    const DebugLink = ElfFileHelper.DebugLink;

    const filter: Filter = filter: {
        if (options.only_keep_debug) break :filter .debug;
        if (options.strip_all) break :filter .program;
        if (options.strip_debug) break :filter .program_and_symbols;
        break :filter .all;
    };

    const filter_complement: ?Filter = blk: {
        if (options.extract_to) |_| {
            break :blk switch (filter) {
                .program => .debug_and_symbols,
                .debug => .program_and_symbols,
                .program_and_symbols => .debug,
                .debug_and_symbols => .program,
                .all => fatal("zig objcopy: nothing to extract", .{}),
            };
        } else {
            break :blk null;
        }
    };
    const debuglink_path = path: {
        if (options.add_debuglink) |path| break :path path;
        if (options.extract_to) |path| break :path path;
        break :path null;
    };

    switch (elf_hdr.is_64) {
        inline else => |is_64| {
            var elf_file = try ElfFile(is_64).parse(allocator, in_file, elf_hdr);
            defer elf_file.deinit();

            if (filter_complement) |flt| {
                // write the .dbg file and close it, so it can be read back to compute the debuglink checksum.
                const path = options.extract_to.?;
                const dbg_file = std.fs.cwd().createFile(path, .{}) catch |err| {
                    fatal("zig objcopy: unable to create '{s}': {s}", .{ path, @errorName(err) });
                };
                defer dbg_file.close();

                try elf_file.emit(allocator, dbg_file, in_file, .{ .section_filter = flt, .compress_debug = options.compress_debug });
            }

            const debuglink: ?DebugLink = if (debuglink_path) |path| ElfFileHelper.createDebugLink(path) else null;
            try elf_file.emit(allocator, out_file, in_file, .{ .section_filter = filter, .debuglink = debuglink, .compress_debug = options.compress_debug });
        },
    }
}

// note: this is "a minimal effort implementation"
//  It doesn't support all possibile elf files: some sections type may need fixups, the program header may need fix up, ...
//  It was written for a specific use case (strip debug info to a sperate file, for linux 64-bits executables built with `zig` or `zig c++` )
// It moves and reoders the sections as little as possible to avoid having to do fixups.
// TODO: support non-native endianess

fn ElfFile(comptime is_64: bool) type {
    const Elf_Ehdr = if (is_64) elf.Elf64_Ehdr else elf.Elf32_Ehdr;
    const Elf_Phdr = if (is_64) elf.Elf64_Phdr else elf.Elf32_Phdr;
    const Elf_Shdr = if (is_64) elf.Elf64_Shdr else elf.Elf32_Shdr;
    const Elf_Chdr = if (is_64) elf.Elf64_Chdr else elf.Elf32_Chdr;
    const Elf_Sym = if (is_64) elf.Elf64_Sym else elf.Elf32_Sym;
    const Elf_Verdef = if (is_64) elf.Elf64_Verdef else elf.Elf32_Verdef;
    const Elf_OffSize = if (is_64) elf.Elf64_Off else elf.Elf32_Off;

    return struct {
        raw_elf_header: Elf_Ehdr,
        program_segments: []const Elf_Phdr,
        sections: []const Section,
        arena: std.heap.ArenaAllocator,

        const SectionCategory = ElfFileHelper.SectionCategory;
        const section_memory_align = @alignOf(Elf_Sym); // most restrictive of what we may load in memory
        const Section = struct {
            section: Elf_Shdr,
            name: []const u8 = "",
            segment: ?*const Elf_Phdr = null, // if the section is used by a program segment (there can be more than one)
            payload: ?[]align(section_memory_align) const u8 = null, // if we need the data in memory
            category: SectionCategory = .none, // should the section be kept in the exe or stripped to the debug database, or both.
        };

        const Self = @This();

        pub fn parse(gpa: Allocator, in_file: File, header: elf.Header) !Self {
            var arena = std.heap.ArenaAllocator.init(gpa);
            errdefer arena.deinit();
            const allocator = arena.allocator();

            var raw_header: Elf_Ehdr = undefined;
            {
                const bytes_read = try in_file.preadAll(std.mem.asBytes(&raw_header), 0);
                if (bytes_read < @sizeOf(Elf_Ehdr))
                    return error.TRUNCATED_ELF;
            }

            // program header: list of segments
            const program_segments = blk: {
                if (@sizeOf(Elf_Phdr) != header.phentsize)
                    fatal("zig objcopy: unsuported ELF file, unexpected phentsize ({d})", .{header.phentsize});

                const program_header = try allocator.alloc(Elf_Phdr, header.phnum);
                const bytes_read = try in_file.preadAll(std.mem.sliceAsBytes(program_header), header.phoff);
                if (bytes_read < @sizeOf(Elf_Phdr) * header.phnum)
                    return error.TRUNCATED_ELF;
                break :blk program_header;
            };

            // section header
            const sections = blk: {
                if (@sizeOf(Elf_Shdr) != header.shentsize)
                    fatal("zig objcopy: unsuported ELF file, unexpected shentsize ({d})", .{header.shentsize});

                const section_header = try allocator.alloc(Section, header.shnum);

                const raw_section_header = try allocator.alloc(Elf_Shdr, header.shnum);
                defer allocator.free(raw_section_header);
                const bytes_read = try in_file.preadAll(std.mem.sliceAsBytes(raw_section_header), header.shoff);
                if (bytes_read < @sizeOf(Elf_Phdr) * header.shnum)
                    return error.TRUNCATED_ELF;

                for (section_header, raw_section_header) |*section, hdr| {
                    section.* = .{ .section = hdr };
                }
                break :blk section_header;
            };

            // load data to memory for some sections:
            //   string tables for access
            //   sections than need modifications when other sections move.
            for (sections, 0..) |*section, idx| {
                const need_data = switch (section.section.sh_type) {
                    elf.DT_VERSYM => true,
                    elf.SHT_SYMTAB, elf.SHT_DYNSYM => true,
                    else => false,
                };
                const need_strings = (idx == header.shstrndx);

                if (need_data or need_strings) {
                    const buffer = try allocator.alignedAlloc(u8, section_memory_align, @intCast(section.section.sh_size));
                    const bytes_read = try in_file.preadAll(buffer, section.section.sh_offset);
                    if (bytes_read != section.section.sh_size) return error.TRUNCATED_ELF;
                    section.payload = buffer;
                }
            }

            // fill-in sections info:
            //    resolve the name
            //    find if a program segment uses the section
            //    categorize sections usage (used by program segments, debug datadase, common metadata, symbol table)
            for (sections) |*section| {
                section.segment = for (program_segments) |*seg| {
                    if (sectionWithinSegment(section.section, seg.*)) break seg;
                } else null;

                if (section.section.sh_name != 0 and header.shstrndx != elf.SHN_UNDEF)
                    section.name = std.mem.span(@as([*:0]const u8, @ptrCast(&sections[header.shstrndx].payload.?[section.section.sh_name])));

                const category_from_program: SectionCategory = if (section.segment != null) .exe else .debug;
                section.category = switch (section.section.sh_type) {
                    elf.SHT_NOTE => .common,
                    elf.SHT_SYMTAB => .symbols, // "strip all" vs "strip only debug"
                    elf.SHT_DYNSYM => .exe,
                    elf.SHT_PROGBITS => cat: {
                        if (std.mem.eql(u8, section.name, ".comment")) break :cat .exe;
                        if (std.mem.eql(u8, section.name, ".gnu_debuglink")) break :cat .none;
                        break :cat category_from_program;
                    },
                    elf.SHT_LOPROC...elf.SHT_HIPROC => .common, // don't strip unknown sections
                    elf.SHT_LOUSER...elf.SHT_HIUSER => .common, // don't strip unknown sections
                    else => category_from_program,
                };
            }

            sections[0].category = .common; // mandatory null section
            if (header.shstrndx != elf.SHN_UNDEF)
                sections[header.shstrndx].category = .common; // string table for the headers

            // recursively propagate section categories to their linked sections, so that they are kept together
            var dirty: u1 = 1;
            while (dirty != 0) {
                dirty = 0;

                for (sections) |*section| {
                    if (section.section.sh_link != elf.SHN_UNDEF)
                        dirty |= ElfFileHelper.propagateCategory(&sections[section.section.sh_link].category, section.category);
                    if ((section.section.sh_flags & elf.SHF_INFO_LINK) != 0 and section.section.sh_info != elf.SHN_UNDEF)
                        dirty |= ElfFileHelper.propagateCategory(&sections[section.section.sh_info].category, section.category);
                }
            }

            return Self{
                .arena = arena,
                .raw_elf_header = raw_header,
                .program_segments = program_segments,
                .sections = sections,
            };
        }

        pub fn deinit(self: *Self) void {
            self.arena.deinit();
        }

        const Filter = ElfFileHelper.Filter;
        const DebugLink = ElfFileHelper.DebugLink;
        const EmitElfOptions = struct {
            section_filter: Filter = .all,
            debuglink: ?DebugLink = null,
            compress_debug: bool = false,
        };
        fn emit(self: *const Self, gpa: Allocator, out_file: File, in_file: File, options: EmitElfOptions) !void {
            var arena = std.heap.ArenaAllocator.init(gpa);
            defer arena.deinit();
            const allocator = arena.allocator();

            // when emitting the stripped exe:
            //   - unused sections are removed
            // when emitting the debug file:
            //   - all sections are kept, but some are emptied and their types is changed to SHT_NOBITS
            // the program header is kept unchanged. (`strip` does update it, but `eu-strip` does not, and it still works)

            const Update = struct {
                action: ElfFileHelper.Action,

                // remap the indexs after omitting the filtered sections
                remap_idx: u16,

                // optionally overrides the payload from the source file
                payload: ?[]align(section_memory_align) const u8 = null,
                section: ?Elf_Shdr = null,
            };
            const sections_update = try allocator.alloc(Update, self.sections.len);
            const new_shnum = blk: {
                var next_idx: u16 = 0;
                for (self.sections, sections_update) |section, *update| {
                    const action = ElfFileHelper.selectAction(section.category, options.section_filter);
                    const remap_idx = idx: {
                        if (action == .strip) break :idx elf.SHN_UNDEF;
                        next_idx += 1;
                        break :idx next_idx - 1;
                    };
                    update.* = Update{ .action = action, .remap_idx = remap_idx };
                }

                if (options.debuglink != null)
                    next_idx += 1;

                break :blk next_idx;
            };

            // add a ".gnu_debuglink" to the string table if needed
            const debuglink_name: u32 = blk: {
                if (options.debuglink == null) break :blk elf.SHN_UNDEF;
                if (self.raw_elf_header.e_shstrndx == elf.SHN_UNDEF)
                    fatal("zig objcopy: no strtab, cannot add the debuglink section", .{}); // TODO add the section if needed?

                const strtab = &self.sections[self.raw_elf_header.e_shstrndx];
                const update = &sections_update[self.raw_elf_header.e_shstrndx];

                const name: []const u8 = ".gnu_debuglink";
                const new_offset: u32 = @intCast(strtab.payload.?.len);
                const buf = try allocator.alignedAlloc(u8, section_memory_align, new_offset + name.len + 1);
                @memcpy(buf[0..new_offset], strtab.payload.?);
                @memcpy(buf[new_offset..][0..name.len], name);
                buf[new_offset + name.len] = 0;

                assert(update.action == .keep);
                update.payload = buf;

                break :blk new_offset;
            };

            // maybe compress .debug sections
            if (options.compress_debug) {
                for (self.sections[1..], sections_update[1..]) |section, *update| {
                    if (update.action != .keep) continue;
                    if (!std.mem.startsWith(u8, section.name, ".debug_")) continue;
                    if ((section.section.sh_flags & elf.SHF_COMPRESSED) != 0) continue; // already compressed

                    const chdr = Elf_Chdr{
                        .ch_type = elf.COMPRESS.ZLIB,
                        .ch_size = section.section.sh_size,
                        .ch_addralign = section.section.sh_addralign,
                    };

                    const compressed_payload = try ElfFileHelper.tryCompressSection(allocator, in_file, section.section.sh_offset, section.section.sh_size, std.mem.asBytes(&chdr));
                    if (compressed_payload) |payload| {
                        update.payload = payload;
                        update.section = section.section;
                        update.section.?.sh_addralign = @alignOf(Elf_Chdr);
                        update.section.?.sh_size = @intCast(payload.len);
                        update.section.?.sh_flags |= elf.SHF_COMPRESSED;
                    }
                }
            }

            var cmdbuf = std.ArrayList(ElfFileHelper.WriteCmd).init(allocator);
            defer cmdbuf.deinit();
            try cmdbuf.ensureUnusedCapacity(3 + new_shnum);
            var eof_offset: Elf_OffSize = 0; // track the end of the data written so far.

            // build the updated headers
            // nb: updated_elf_header will be updated before the actual write
            var updated_elf_header = self.raw_elf_header;
            if (updated_elf_header.e_shstrndx != elf.SHN_UNDEF)
                updated_elf_header.e_shstrndx = sections_update[updated_elf_header.e_shstrndx].remap_idx;
            cmdbuf.appendAssumeCapacity(.{ .write_data = .{ .data = std.mem.asBytes(&updated_elf_header), .out_offset = 0 } });
            eof_offset = @sizeOf(Elf_Ehdr);

            // program header as-is.
            // nb: for only-debug files, removing it appears to work, but is invalid by ELF specifcation.
            {
                assert(updated_elf_header.e_phoff == @sizeOf(Elf_Ehdr));
                const data = std.mem.sliceAsBytes(self.program_segments);
                assert(data.len == @as(usize, updated_elf_header.e_phentsize) * updated_elf_header.e_phnum);
                cmdbuf.appendAssumeCapacity(.{ .write_data = .{ .data = data, .out_offset = updated_elf_header.e_phoff } });
                eof_offset = updated_elf_header.e_phoff + @as(Elf_OffSize, @intCast(data.len));
            }

            // update sections and queue payload writes
            const updated_section_header = blk: {
                const dest_sections = try allocator.alloc(Elf_Shdr, new_shnum);

                {
                    // the ELF format doesn't specify the order for all sections.
                    // this code only supports when they are in increasing file order.
                    var offset: u64 = eof_offset;
                    for (self.sections[1..]) |section| {
                        if (section.section.sh_type == elf.SHT_NOBITS)
                            continue;
                        if (section.section.sh_offset < offset) {
                            fatal("zig objcopy: unsuported ELF file", .{});
                        }
                        offset = section.section.sh_offset;
                    }
                }

                dest_sections[0] = self.sections[0].section;

                var dest_section_idx: u32 = 1;
                for (self.sections[1..], sections_update[1..]) |section, update| {
                    if (update.action == .strip) continue;
                    assert(update.remap_idx == dest_section_idx);

                    const src = if (update.section) |*s| s else &section.section;
                    const dest = &dest_sections[dest_section_idx];
                    const payload = if (update.payload) |data| data else section.payload;
                    dest_section_idx += 1;

                    dest.* = src.*;

                    if (src.sh_link != elf.SHN_UNDEF)
                        dest.sh_link = sections_update[src.sh_link].remap_idx;
                    if ((src.sh_flags & elf.SHF_INFO_LINK) != 0 and src.sh_info != elf.SHN_UNDEF)
                        dest.sh_info = sections_update[src.sh_info].remap_idx;

                    if (payload) |data|
                        dest.sh_size = @intCast(data.len);

                    const addralign = if (src.sh_addralign == 0 or dest.sh_type == elf.SHT_NOBITS) 1 else src.sh_addralign;
                    dest.sh_offset = std.mem.alignForward(Elf_OffSize, eof_offset, addralign);
                    if (src.sh_offset != dest.sh_offset and section.segment != null and update.action != .empty and dest.sh_type != elf.SHT_NOTE and dest.sh_type != elf.SHT_NOBITS) {
                        if (src.sh_offset > dest.sh_offset) {
                            dest.sh_offset = src.sh_offset; // add padding to avoid modifing the program segments
                        } else {
                            fatal("zig objcopy: cannot adjust program segments", .{});
                        }
                    }
                    assert(dest.sh_addr % addralign == dest.sh_offset % addralign);

                    if (update.action == .empty)
                        dest.sh_type = elf.SHT_NOBITS;

                    if (dest.sh_type != elf.SHT_NOBITS) {
                        if (payload) |src_data| {
                            // update sections payload and write
                            const dest_data = switch (src.sh_type) {
                                elf.DT_VERSYM => dst_data: {
                                    const data = try allocator.alignedAlloc(u8, section_memory_align, src_data.len);
                                    @memcpy(data, src_data);

                                    const defs = @as([*]Elf_Verdef, @ptrCast(data))[0 .. @as(usize, @intCast(src.sh_size)) / @sizeOf(Elf_Verdef)];
                                    for (defs) |*def| {
                                        if (def.vd_ndx != elf.SHN_UNDEF)
                                            def.vd_ndx = sections_update[src.sh_info].remap_idx;
                                    }

                                    break :dst_data data;
                                },
                                elf.SHT_SYMTAB, elf.SHT_DYNSYM => dst_data: {
                                    const data = try allocator.alignedAlloc(u8, section_memory_align, src_data.len);
                                    @memcpy(data, src_data);

                                    const syms = @as([*]Elf_Sym, @ptrCast(data))[0 .. @as(usize, @intCast(src.sh_size)) / @sizeOf(Elf_Sym)];
                                    for (syms) |*sym| {
                                        if (sym.st_shndx != elf.SHN_UNDEF and sym.st_shndx < elf.SHN_LORESERVE)
                                            sym.st_shndx = sections_update[sym.st_shndx].remap_idx;
                                    }

                                    break :dst_data data;
                                },
                                else => src_data,
                            };

                            assert(dest_data.len == dest.sh_size);
                            cmdbuf.appendAssumeCapacity(.{ .write_data = .{ .data = dest_data, .out_offset = dest.sh_offset } });
                            eof_offset = dest.sh_offset + dest.sh_size;
                        } else {
                            // direct contents copy
                            cmdbuf.appendAssumeCapacity(.{ .copy_range = .{ .in_offset = src.sh_offset, .len = dest.sh_size, .out_offset = dest.sh_offset } });
                            eof_offset = dest.sh_offset + dest.sh_size;
                        }
                    } else {
                        // account for alignment padding even in empty sections to keep logical section order
                        eof_offset = dest.sh_offset;
                    }
                }

                // add a ".gnu_debuglink" section
                if (options.debuglink) |link| {
                    const payload = payload: {
                        const crc_offset = std.mem.alignForward(usize, link.name.len + 1, 4);
                        const buf = try allocator.alignedAlloc(u8, 4, crc_offset + 4);
                        @memcpy(buf[0..link.name.len], link.name);
                        @memset(buf[link.name.len..crc_offset], 0);
                        @memcpy(buf[crc_offset..], std.mem.asBytes(&link.crc32));
                        break :payload buf;
                    };

                    dest_sections[dest_section_idx] = Elf_Shdr{
                        .sh_name = debuglink_name,
                        .sh_type = elf.SHT_PROGBITS,
                        .sh_flags = 0,
                        .sh_addr = 0,
                        .sh_offset = eof_offset,
                        .sh_size = @intCast(payload.len),
                        .sh_link = elf.SHN_UNDEF,
                        .sh_info = elf.SHN_UNDEF,
                        .sh_addralign = 4,
                        .sh_entsize = 0,
                    };
                    dest_section_idx += 1;

                    cmdbuf.appendAssumeCapacity(.{ .write_data = .{ .data = payload, .out_offset = eof_offset } });
                    eof_offset += @as(Elf_OffSize, @intCast(payload.len));
                }

                assert(dest_section_idx == new_shnum);
                break :blk dest_sections;
            };

            // write the section header at the tail
            {
                const offset = std.mem.alignForward(Elf_OffSize, eof_offset, @alignOf(Elf_Shdr));

                const data = std.mem.sliceAsBytes(updated_section_header);
                assert(data.len == @as(usize, updated_elf_header.e_shentsize) * new_shnum);
                updated_elf_header.e_shoff = offset;
                updated_elf_header.e_shnum = new_shnum;

                cmdbuf.appendAssumeCapacity(.{ .write_data = .{ .data = data, .out_offset = updated_elf_header.e_shoff } });
            }

            try ElfFileHelper.write(allocator, out_file, in_file, cmdbuf.items);
        }

        fn sectionWithinSegment(section: Elf_Shdr, segment: Elf_Phdr) bool {
            const file_size = if (section.sh_type == elf.SHT_NOBITS) 0 else section.sh_size;
            return segment.p_offset <= section.sh_offset and (segment.p_offset + segment.p_filesz) >= (section.sh_offset + file_size);
        }
    };
}

const ElfFileHelper = struct {
    const DebugLink = struct { name: []const u8, crc32: u32 };
    const Filter = enum { all, program, debug, program_and_symbols, debug_and_symbols };

    const SectionCategory = enum { common, exe, debug, symbols, none };
    fn propagateCategory(cur: *SectionCategory, new: SectionCategory) u1 {
        const cat: SectionCategory = switch (cur.*) {
            .none => new,
            .common => .common,
            .debug => switch (new) {
                .none, .debug => .debug,
                else => new,
            },
            .exe => switch (new) {
                .common => .common,
                .none, .debug, .exe => .exe,
                .symbols => .exe,
            },
            .symbols => switch (new) {
                .none, .common, .debug, .exe => unreachable,
                .symbols => .symbols,
            },
        };

        if (cur.* != cat) {
            cur.* = cat;
            return 1;
        } else {
            return 0;
        }
    }

    const Action = enum { keep, strip, empty };
    fn selectAction(category: SectionCategory, filter: Filter) Action {
        if (category == .none) return .strip;
        return switch (filter) {
            .all => switch (category) {
                .none => .strip,
                else => .keep,
            },
            .program => switch (category) {
                .common, .exe => .keep,
                else => .strip,
            },
            .program_and_symbols => switch (category) {
                .common, .exe, .symbols => .keep,
                else => .strip,
            },
            .debug => switch (category) {
                .exe, .symbols => .empty,
                .none => .strip,
                else => .keep,
            },
            .debug_and_symbols => switch (category) {
                .exe => .empty,
                .none => .strip,
                else => .keep,
            },
        };
    }

    const WriteCmd = union(enum) {
        copy_range: struct { in_offset: u64, len: u64, out_offset: u64 },
        write_data: struct { data: []const u8, out_offset: u64 },
    };
    fn write(allocator: Allocator, out_file: File, in_file: File, cmds: []const WriteCmd) !void {
        // consolidate holes between writes:
        //   by coping original padding data from in_file (by fusing contiguous ranges)
        //   by writing zeroes otherwise
        const zeroes = [1]u8{0} ** 4096;
        var consolidated = std.ArrayList(WriteCmd).init(allocator);
        defer consolidated.deinit();
        try consolidated.ensureUnusedCapacity(cmds.len * 2);
        var offset: u64 = 0;
        var fused_cmd: ?WriteCmd = null;
        for (cmds) |cmd| {
            switch (cmd) {
                .write_data => |data| {
                    assert(data.out_offset >= offset);
                    if (fused_cmd) |prev| {
                        consolidated.appendAssumeCapacity(prev);
                        fused_cmd = null;
                    }
                    if (data.out_offset > offset) {
                        consolidated.appendAssumeCapacity(.{ .write_data = .{ .data = zeroes[0..@intCast(data.out_offset - offset)], .out_offset = offset } });
                    }
                    consolidated.appendAssumeCapacity(cmd);
                    offset = data.out_offset + data.data.len;
                },
                .copy_range => |range| {
                    assert(range.out_offset >= offset);
                    if (fused_cmd) |prev| {
                        if (range.in_offset >= prev.copy_range.in_offset + prev.copy_range.len and (range.out_offset - prev.copy_range.out_offset == range.in_offset - prev.copy_range.in_offset)) {
                            fused_cmd = .{ .copy_range = .{
                                .in_offset = prev.copy_range.in_offset,
                                .out_offset = prev.copy_range.out_offset,
                                .len = (range.out_offset + range.len) - prev.copy_range.out_offset,
                            } };
                        } else {
                            consolidated.appendAssumeCapacity(prev);
                            if (range.out_offset > offset) {
                                consolidated.appendAssumeCapacity(.{ .write_data = .{ .data = zeroes[0..@intCast(range.out_offset - offset)], .out_offset = offset } });
                            }
                            fused_cmd = cmd;
                        }
                    } else {
                        fused_cmd = cmd;
                    }
                    offset = range.out_offset + range.len;
                },
            }
        }
        if (fused_cmd) |cmd| {
            consolidated.appendAssumeCapacity(cmd);
        }

        // write the output file
        for (consolidated.items) |cmd| {
            switch (cmd) {
                .write_data => |data| {
                    var iovec = [_]std.posix.iovec_const{.{ .iov_base = data.data.ptr, .iov_len = data.data.len }};
                    try out_file.pwritevAll(&iovec, data.out_offset);
                },
                .copy_range => |range| {
                    const copied_bytes = try in_file.copyRangeAll(range.in_offset, out_file, range.out_offset, range.len);
                    if (copied_bytes < range.len) return error.TRUNCATED_ELF;
                },
            }
        }
    }

    fn tryCompressSection(allocator: Allocator, in_file: File, offset: u64, size: u64, prefix: []const u8) !?[]align(8) const u8 {
        if (size < prefix.len) return null;

        try in_file.seekTo(offset);
        var section_reader = std.io.limitedReader(in_file.reader(), size);

        // allocate as large as decompressed data. if the compression doesn't fit, keep the data uncompressed.
        const compressed_data = try allocator.alignedAlloc(u8, 8, @intCast(size));
        var compressed_stream = std.io.fixedBufferStream(compressed_data);

        try compressed_stream.writer().writeAll(prefix);

        {
            var compressor = try std.compress.zlib.compressor(compressed_stream.writer(), .{});

            var buf: [8000]u8 = undefined;
            while (true) {
                const bytes_read = try section_reader.read(&buf);
                if (bytes_read == 0) break;
                const bytes_written = compressor.write(buf[0..bytes_read]) catch |err| switch (err) {
                    error.NoSpaceLeft => {
                        allocator.free(compressed_data);
                        return null;
                    },
                    else => return err,
                };
                std.debug.assert(bytes_written == bytes_read);
            }
            compressor.finish() catch |err| switch (err) {
                error.NoSpaceLeft => {
                    allocator.free(compressed_data);
                    return null;
                },
                else => return err,
            };
        }

        const compressed_len: usize = @intCast(compressed_stream.getPos() catch unreachable);
        const data = allocator.realloc(compressed_data, compressed_len) catch compressed_data;
        return data[0..compressed_len];
    }

    fn createDebugLink(path: []const u8) DebugLink {
        const file = std.fs.cwd().openFile(path, .{}) catch |err| {
            fatal("zig objcopy: could not open `{s}`: {s}\n", .{ path, @errorName(err) });
        };
        defer file.close();

        const crc = ElfFileHelper.computeFileCrc(file) catch |err| {
            fatal("zig objcopy: could not read `{s}`: {s}\n", .{ path, @errorName(err) });
        };
        return .{
            .name = std.fs.path.basename(path),
            .crc32 = crc,
        };
    }

    fn computeFileCrc(file: File) !u32 {
        var buf: [8000]u8 = undefined;

        try file.seekTo(0);
        var hasher = std.hash.Crc32.init();
        while (true) {
            const bytes_read = try file.read(&buf);
            if (bytes_read == 0) break;
            hasher.update(buf[0..bytes_read]);
        }
        return hasher.final();
    }
};
