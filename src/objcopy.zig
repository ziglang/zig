const std = @import("std");
const mem = std.mem;
const fs = std.fs;
const elf = std.elf;
const Allocator = std.mem.Allocator;
const File = std.fs.File;
const main = @import("main.zig");
const fatal = main.fatal;
const cleanExit = main.cleanExit;

pub fn cmdObjCopy(
    gpa: Allocator,
    arena: Allocator,
    args: []const []const u8,
) !void {
    _ = gpa;
    var i: usize = 0;
    var opt_out_fmt: ?std.Target.ObjectFormat = null;
    var opt_input: ?[]const u8 = null;
    var opt_output: ?[]const u8 = null;
    var only_section: ?[]const u8 = null;
    var pad_to: ?u64 = null;
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
        } else if (mem.startsWith(u8, arg, "--only-section=")) {
            only_section = arg["--output-target=".len..];
        } else if (mem.eql(u8, arg, "--pad-to")) {
            i += 1;
            if (i >= args.len) fatal("expected another argument after '{s}'", .{arg});
            pad_to = std.fmt.parseInt(u64, args[i], 0) catch |err| {
                fatal("unable to parse: '{s}': {s}", .{ args[i], @errorName(err) });
            };
        } else {
            fatal("unrecognized argument: '{s}'", .{arg});
        }
    }
    const input = opt_input orelse fatal("expected input parameter", .{});
    const output = opt_output orelse fatal("expected output parameter", .{});

    var in_file = fs.cwd().openFile(input, .{}) catch |err|
        fatal("unable to open '{s}': {s}", .{ input, @errorName(err) });
    defer in_file.close();

    var out_file = try fs.cwd().createFile(output, .{});
    defer out_file.close();

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

    switch (out_fmt) {
        .hex, .raw, .elf => {
            try emitElf(arena, in_file, out_file, elf_hdr, .{
                .ofmt = out_fmt,
                .only_section = only_section,
                .pad_to = pad_to,
            });
            return cleanExit();
        },
        else => fatal("unsupported output object format: {s}", .{@tagName(out_fmt)}),
    }
}

const usage =
    \\Usage: zig objcopy [options] input output
    \\
    \\Options:
    \\  -h, --help                Print this help and exit
    \\  --output-target=<value>   Format of the output file
    \\  -O <value>                Alias for --output-target
    \\  --only-section=<section>  Remove all but <section>
    \\  -j <value>                Alias for --only-section
    \\  --pad-to <addr>           Pad the last section up to address <addr>
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
            for (binary_elf_output.sections.items) |section| {
                if (section.segment) |segment| {
                    try hex_writer.writeSegment(segment, in_file);
                }
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

            const buffer = try allocator.alloc(u8, @intCast(usize, shstrtab_shdr.sh_size));
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
                newSection.fileSize = @intCast(usize, section.sh_size);
                newSection.segment = null;

                newSection.name = if (self.shstrtab) |shstrtab|
                    std.mem.span(@ptrCast([*:0]const u8, &shstrtab[section.sh_name]))
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
                newSegment.fileSize = @intCast(usize, phdr.p_filesz);
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

        std.sort.sort(*BinaryElfSegment, self.segments.items, {}, segmentSortCompare);

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

        std.sort.sort(*BinaryElfSection, self.sections.items, {}, sectionSortCompare);

        return self;
    }

    fn sectionWithinSegment(section: *BinaryElfSection, segment: elf.Elf64_Phdr) bool {
        return segment.p_offset <= section.elfOffset and (segment.p_offset + segment.p_filesz) >= (section.elfOffset + section.fileSize);
    }

    fn sectionValidForOutput(shdr: anytype) bool {
        return shdr.sh_size > 0 and shdr.sh_type != elf.SHT_NOBITS and
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
        const msb = @truncate(u8, address >> 8);
        const lsb = @truncate(u8, address);
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
                .address = @intCast(u16, address % 0x10000),
                .payload = .{ .Data = data },
            };
        }

        fn Address(address: u32) Record {
            std.debug.assert(address > 0xFFFF);
            const segment = @intCast(u16, address / 0x10000);
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

            var sum: u8 = @intCast(u8, payload_bytes.len);
            const parts = addressParts(self.address);
            sum +%= parts[0];
            sum +%= parts[1];
            sum +%= @enumToInt(self.payload);
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
            std.debug.assert(payload_bytes.len <= MAX_PAYLOAD_LEN);

            const line = try std.fmt.bufPrint(&outbuf, ":{0X:0>2}{1X:0>4}{2X:0>2}{3s}{4X:0>2}" ++ linesep, .{
                @intCast(u8, payload_bytes.len),
                self.address,
                @enumToInt(self.payload),
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
            const row_address = @intCast(u32, segment.physicalAddress + bytes_read);

            const remaining = segment.fileSize - bytes_read;
            const to_read = @intCast(usize, @min(remaining, MAX_PAYLOAD_LEN));
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
        self.prev_addr = @intCast(u32, record.address + data.len);
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
