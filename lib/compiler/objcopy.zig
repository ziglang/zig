const builtin = @import("builtin");
const std = @import("std");
const mem = std.mem;
const fs = std.fs;
const elf = std.elf;
const Allocator = std.mem.Allocator;
const File = std.fs.File;
const assert = std.debug.assert;

const fatal = std.process.fatal;
const Server = std.zig.Server;

var stdin_buffer: [1024]u8 = undefined;
var stdout_buffer: [1024]u8 = undefined;

var input_buffer: [1024]u8 = undefined;
var output_buffer: [1024]u8 = undefined;

pub fn main() !void {
    var arena_instance = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena_instance.deinit();
    const arena = arena_instance.allocator();

    var general_purpose_allocator: std.heap.GeneralPurposeAllocator(.{}) = .init;
    const gpa = general_purpose_allocator.allocator();

    const args = try std.process.argsAlloc(arena);
    return cmdObjCopy(gpa, arena, args[1..]);
}

fn cmdObjCopy(gpa: Allocator, arena: Allocator, args: []const []const u8) !void {
    _ = gpa;
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
    var add_section: ?AddSection = null;
    var set_section_alignment: ?SetSectionAlignment = null;
    var set_section_flags: ?SetSectionFlags = null;
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
            return std.fs.File.stdout().writeAll(usage);
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
        } else if (mem.eql(u8, arg, "--set-section-alignment")) {
            i += 1;
            if (i >= args.len) fatal("expected section name and alignment arguments after '{s}'", .{arg});

            if (splitOption(args[i])) |split| {
                const alignment = std.fmt.parseInt(u32, split.second, 10) catch |err| {
                    fatal("unable to parse alignment number: '{s}': {s}", .{ split.second, @errorName(err) });
                };
                if (!std.math.isPowerOfTwo(alignment)) fatal("alignment must be a power of two", .{});
                set_section_alignment = .{ .section_name = split.first, .alignment = alignment };
            } else {
                fatal("unrecognized argument: '{s}', expecting <name>=<alignment>", .{args[i]});
            }
        } else if (mem.eql(u8, arg, "--set-section-flags")) {
            i += 1;
            if (i >= args.len) fatal("expected section name and filename arguments after '{s}'", .{arg});

            if (splitOption(args[i])) |split| {
                set_section_flags = .{ .section_name = split.first, .flags = parseSectionFlags(split.second) };
            } else {
                fatal("unrecognized argument: '{s}', expecting <name>=<flags>", .{args[i]});
            }
        } else if (mem.eql(u8, arg, "--add-section")) {
            i += 1;
            if (i >= args.len) fatal("expected section name and filename arguments after '{s}'", .{arg});

            if (splitOption(args[i])) |split| {
                add_section = .{ .section_name = split.first, .file_path = split.second };
            } else {
                fatal("unrecognized argument: '{s}', expecting <name>=<file>", .{args[i]});
            }
        } else {
            fatal("unrecognized argument: '{s}'", .{arg});
        }
    }
    const input = opt_input orelse fatal("expected input parameter", .{});
    const output = opt_output orelse fatal("expected output parameter", .{});

    const input_file = fs.cwd().openFile(input, .{}) catch |err| fatal("failed to open {s}: {t}", .{ input, err });
    defer input_file.close();

    const stat = input_file.stat() catch |err| fatal("failed to stat {s}: {t}", .{ input, err });

    var in: File.Reader = .initSize(input_file, &input_buffer, stat.size);

    const elf_hdr = std.elf.Header.read(&in.interface) catch |err| switch (err) {
        error.ReadFailed => fatal("unable to read {s}: {t}", .{ input, in.err.? }),
        else => |e| fatal("invalid elf file: {t}", .{e}),
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

    const mode = if (out_fmt != .elf or only_keep_debug) fs.File.default_mode else stat.mode;

    var output_file = try fs.cwd().createFile(output, .{ .mode = mode });
    defer output_file.close();

    var out = output_file.writer(&output_buffer);

    switch (out_fmt) {
        .hex, .raw => {
            if (strip_debug or strip_all or only_keep_debug)
                fatal("zig objcopy: ELF to RAW or HEX copying does not support --strip", .{});
            if (opt_extract != null)
                fatal("zig objcopy: ELF to RAW or HEX copying does not support --extract-to", .{});
            if (add_section != null)
                fatal("zig objcopy: ELF to RAW or HEX copying does not support --add-section", .{});
            if (set_section_alignment != null)
                fatal("zig objcopy: ELF to RAW or HEX copying does not support --set_section_alignment", .{});
            if (set_section_flags != null)
                fatal("zig objcopy: ELF to RAW or HEX copying does not support --set_section_flags", .{});

            try emitElf(arena, &in, &out, elf_hdr, .{
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

            fatal("unimplemented", .{});
        },
        else => fatal("unsupported output object format: {s}", .{@tagName(out_fmt)}),
    }

    try out.end();

    if (listen) {
        var stdin_reader = fs.File.stdin().reader(&stdin_buffer);
        var stdout_writer = fs.File.stdout().writer(&stdout_buffer);
        var server = try Server.init(.{
            .in = &stdin_reader.interface,
            .out = &stdout_writer.interface,
            .zig_version = builtin.zig_version_string,
        });

        var seen_update = false;
        while (true) {
            const hdr = try server.receiveMessage();
            switch (hdr.tag) {
                .exit => {
                    return std.process.cleanExit();
                },
                .update => {
                    if (seen_update) fatal("zig objcopy only supports 1 update for now", .{});
                    seen_update = true;

                    // The build system already knows what the output is at this point, we
                    // only need to communicate that the process has finished.
                    // Use the empty error bundle to indicate that the update is done.
                    try server.serveErrorBundle(std.zig.ErrorBundle.empty);
                },
                else => fatal("unsupported message: {s}", .{@tagName(hdr.tag)}),
            }
        }
    }
    return std.process.cleanExit();
}

const usage =
    \\Usage: zig objcopy [options] input output
    \\
    \\Options:
    \\  -h, --help                              Print this help and exit
    \\  --output-target=<value>                 Format of the output file
    \\  -O <value>                              Alias for --output-target
    \\  --only-section=<section>                Remove all but <section>
    \\  -j <value>                              Alias for --only-section
    \\  --pad-to <addr>                         Pad the last section up to address <addr>
    \\  --strip-debug, -g                       Remove all debug sections from the output.
    \\  --strip-all, -S                         Remove all debug sections and symbol table from the output.
    \\  --only-keep-debug                       Strip a file, removing contents of any sections that would not be stripped by --strip-debug and leaving the debugging sections intact.
    \\  --add-gnu-debuglink=<file>              Creates a .gnu_debuglink section which contains a reference to <file> and adds it to the output file.
    \\  --extract-to <file>                     Extract the removed sections into <file>, and add a .gnu-debuglink section.
    \\  --compress-debug-sections               Compress DWARF debug sections with zlib
    \\  --set-section-alignment <name>=<align>  Set alignment of section <name> to <align> bytes. Must be a power of two.
    \\  --set-section-flags <name>=<file>       Set flags of section <name> to <flags> represented as a comma separated set of flags.
    \\  --add-section <name>=<file>             Add file content from <file> with the a new section named <name>.
    \\
;

pub const EmitRawElfOptions = struct {
    ofmt: std.Target.ObjectFormat,
    only_section: ?[]const u8 = null,
    pad_to: ?u64 = null,
    add_section: ?AddSection = null,
    set_section_alignment: ?SetSectionAlignment = null,
    set_section_flags: ?SetSectionFlags = null,
};

const AddSection = struct {
    section_name: []const u8,
    file_path: []const u8,
};

const SetSectionAlignment = struct {
    section_name: []const u8,
    alignment: u32,
};

const SetSectionFlags = struct {
    section_name: []const u8,
    flags: SectionFlags,
};

fn emitElf(
    arena: Allocator,
    in: *File.Reader,
    out: *File.Writer,
    elf_hdr: elf.Header,
    options: EmitRawElfOptions,
) !void {
    var binary_elf_output = try BinaryElfOutput.parse(arena, in, elf_hdr);
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

                    try writeBinaryElfSection(in, out, section);
                    try padFile(out, options.pad_to);
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
                try out.seekTo(section.binaryOffset);
                try writeBinaryElfSection(in, out, section);
            }
            try padFile(out, options.pad_to);
        },
        .hex => {
            if (binary_elf_output.segments.items.len == 0) return;
            if (!containsValidAddressRange(binary_elf_output.segments.items)) {
                return error.InvalidHexfileAddressRange;
            }

            var hex_writer = HexWriter{ .out = out };
            for (binary_elf_output.segments.items) |segment| {
                try hex_writer.writeSegment(segment, in);
            }
            if (options.pad_to) |_| {
                // Padding to a size in hex files isn't applicable
                return error.InvalidArgument;
            }
            try hex_writer.writeEof();
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

    pub fn parse(allocator: Allocator, in: *File.Reader, elf_hdr: elf.Header) !Self {
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

            var section_headers = elf_hdr.iterateSectionHeaders(in);

            var section_counter: usize = 0;
            while (section_counter < elf_hdr.shstrndx) : (section_counter += 1) {
                _ = (try section_headers.next()).?;
            }

            const shstrtab_shdr = (try section_headers.next()).?;

            try in.seekTo(shstrtab_shdr.sh_offset);
            break :blk try in.interface.readAlloc(allocator, shstrtab_shdr.sh_size);
        };

        errdefer if (self.shstrtab) |shstrtab| allocator.free(shstrtab);

        var section_headers = elf_hdr.iterateSectionHeaders(in);
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

        var program_headers = elf_hdr.iterateProgramHeaders(in);
        while (try program_headers.next()) |phdr| {
            if (phdr.p_type == elf.PT_LOAD) {
                const newSegment = try allocator.create(BinaryElfSegment);

                newSegment.physicalAddress = phdr.p_paddr;
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

fn writeBinaryElfSection(in: *File.Reader, out: *File.Writer, section: *BinaryElfSection) !void {
    try in.seekTo(section.elfOffset);
    _ = try out.interface.sendFileAll(in, .limited(section.fileSize));
}

const HexWriter = struct {
    prev_addr: ?u32 = null,
    out: *File.Writer,

    /// Max data bytes per line of output
    const max_payload_len: u8 = 16;

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

        fn write(self: Record, out: *File.Writer) !void {
            const linesep = "\r\n";
            // colon, (length, address, type, payload, checksum) as hex, CRLF
            const BUFSIZE = 1 + (1 + 2 + 1 + max_payload_len + 1) * 2 + linesep.len;
            var outbuf: [BUFSIZE]u8 = undefined;
            const payload_bytes = self.getPayloadBytes();
            assert(payload_bytes.len <= max_payload_len);

            const line = try std.fmt.bufPrint(&outbuf, ":{0X:0>2}{1X:0>4}{2X:0>2}{3X}{4X:0>2}" ++ linesep, .{
                @as(u8, @intCast(payload_bytes.len)),
                self.address,
                @intFromEnum(self.payload),
                payload_bytes,
                self.checksum(),
            });
            try out.interface.writeAll(line);
        }
    };

    pub fn writeSegment(self: *HexWriter, segment: *const BinaryElfSegment, in: *File.Reader) !void {
        var buf: [max_payload_len]u8 = undefined;
        var bytes_read: usize = 0;
        while (bytes_read < segment.fileSize) {
            const row_address: u32 = @intCast(segment.physicalAddress + bytes_read);

            const remaining = segment.fileSize - bytes_read;
            const dest = buf[0..@min(remaining, max_payload_len)];
            try in.seekTo(segment.elfOffset + bytes_read);
            try in.interface.readSliceAll(dest);
            try self.writeDataRow(row_address, dest);

            bytes_read += dest.len;
        }
    }

    fn writeDataRow(self: *HexWriter, address: u32, data: []const u8) !void {
        const record = Record.Data(address, data);
        if (address > 0xFFFF and (self.prev_addr == null or record.address != self.prev_addr.?)) {
            try Record.Address(address).write(self.out);
        }
        try record.write(self.out);
        self.prev_addr = @intCast(record.address + data.len);
    }

    fn writeEof(self: HexWriter) !void {
        try Record.EOF().write(self.out);
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

fn padFile(out: *File.Writer, opt_size: ?u64) !void {
    const size = opt_size orelse return;
    try out.file.setEndPos(size);
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

const SectionFlags = packed struct {
    alloc: bool = false,
    contents: bool = false,
    load: bool = false,
    noload: bool = false,
    readonly: bool = false,
    code: bool = false,
    data: bool = false,
    rom: bool = false,
    exclude: bool = false,
    shared: bool = false,
    debug: bool = false,
    large: bool = false,
    merge: bool = false,
    strings: bool = false,
};

fn parseSectionFlags(comma_separated_flags: []const u8) SectionFlags {
    const P = struct {
        fn parse(flags: *SectionFlags, string: []const u8) void {
            if (string.len == 0) return;

            if (std.mem.eql(u8, string, "alloc")) {
                flags.alloc = true;
            } else if (std.mem.eql(u8, string, "contents")) {
                flags.contents = true;
            } else if (std.mem.eql(u8, string, "load")) {
                flags.load = true;
            } else if (std.mem.eql(u8, string, "noload")) {
                flags.noload = true;
            } else if (std.mem.eql(u8, string, "readonly")) {
                flags.readonly = true;
            } else if (std.mem.eql(u8, string, "code")) {
                flags.code = true;
            } else if (std.mem.eql(u8, string, "data")) {
                flags.data = true;
            } else if (std.mem.eql(u8, string, "rom")) {
                flags.rom = true;
            } else if (std.mem.eql(u8, string, "exclude")) {
                flags.exclude = true;
            } else if (std.mem.eql(u8, string, "shared")) {
                flags.shared = true;
            } else if (std.mem.eql(u8, string, "debug")) {
                flags.debug = true;
            } else if (std.mem.eql(u8, string, "large")) {
                flags.large = true;
            } else if (std.mem.eql(u8, string, "merge")) {
                flags.merge = true;
            } else if (std.mem.eql(u8, string, "strings")) {
                flags.strings = true;
            } else {
                std.log.warn("Skipping unrecognized section flag '{s}'", .{string});
            }
        }
    };

    var flags = SectionFlags{};
    var offset: usize = 0;
    for (comma_separated_flags, 0..) |c, i| {
        if (c == ',') {
            defer offset = i + 1;
            const string = comma_separated_flags[offset..i];
            P.parse(&flags, string);
        }
    }
    P.parse(&flags, comma_separated_flags[offset..]);
    return flags;
}

test "Parse section flags" {
    const F = SectionFlags;
    try std.testing.expectEqual(F{}, parseSectionFlags(""));
    try std.testing.expectEqual(F{}, parseSectionFlags(","));
    try std.testing.expectEqual(F{}, parseSectionFlags("abc"));
    try std.testing.expectEqual(F{ .alloc = true }, parseSectionFlags("alloc"));
    try std.testing.expectEqual(F{ .data = true }, parseSectionFlags("data,"));
    try std.testing.expectEqual(F{ .alloc = true, .code = true }, parseSectionFlags("alloc,code"));
    try std.testing.expectEqual(F{ .alloc = true, .code = true }, parseSectionFlags("alloc,code,not_supported"));
}

const SplitResult = struct { first: []const u8, second: []const u8 };

fn splitOption(option: []const u8) ?SplitResult {
    const separator = '=';
    if (option.len < 3) return null; // minimum "a=b"
    for (1..option.len - 1) |i| {
        if (option[i] == separator) return .{
            .first = option[0..i],
            .second = option[i + 1 ..],
        };
    }
    return null;
}

test "Split option" {
    {
        const split = splitOption(".abc=123");
        try std.testing.expect(split != null);
        try std.testing.expectEqualStrings(".abc", split.?.first);
        try std.testing.expectEqualStrings("123", split.?.second);
    }

    try std.testing.expectEqual(null, splitOption(""));
    try std.testing.expectEqual(null, splitOption("=abc"));
    try std.testing.expectEqual(null, splitOption("abc="));
    try std.testing.expectEqual(null, splitOption("abc"));
}
