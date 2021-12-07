const std = @import("std");

const Allocator = std.mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;
const ArrayListUnmanaged = std.ArrayListUnmanaged;
const Builder = std.build.Builder;
const File = std.fs.File;
const InstallDir = std.build.InstallDir;
const LibExeObjStep = std.build.LibExeObjStep;
const Step = std.build.Step;
const elf = std.elf;
const fs = std.fs;
const io = std.io;
const sort = std.sort;

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
    fileSize: usize,
    firstSection: ?*BinaryElfSection,
};

const BinaryElfOutput = struct {
    segments: ArrayListUnmanaged(*BinaryElfSegment),
    sections: ArrayListUnmanaged(*BinaryElfSection),
    allocator: Allocator,
    shstrtab: ?[]const u8,

    const Self = @This();

    pub fn deinit(self: *Self) void {
        if (self.shstrtab) |shstrtab|
            self.allocator.free(shstrtab);
        self.sections.deinit(self.allocator);
        self.segments.deinit(self.allocator);
    }

    pub fn parse(allocator: Allocator, elf_file: File) !Self {
        var self: Self = .{
            .segments = .{},
            .sections = .{},
            .allocator = allocator,
            .shstrtab = null,
        };
        errdefer self.sections.deinit(allocator);
        errdefer self.segments.deinit(allocator);

        const elf_hdr = try std.elf.Header.read(&elf_file);

        self.shstrtab = blk: {
            if (elf_hdr.shstrndx >= elf_hdr.shnum) break :blk null;

            var section_headers = elf_hdr.section_header_iterator(&elf_file);

            var section_counter: usize = 0;
            while (section_counter < elf_hdr.shstrndx) : (section_counter += 1) {
                _ = (try section_headers.next()).?;
            }

            const shstrtab_shdr = (try section_headers.next()).?;

            const buffer = try allocator.alloc(u8, shstrtab_shdr.sh_size);
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

        sort.sort(*BinaryElfSegment, self.segments.items, {}, segmentSortCompare);

        for (self.segments.items) |firstSegment, i| {
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

        sort.sort(*BinaryElfSection, self.sections.items, {}, sectionSortCompare);

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

        fn getPayloadBytes(self: Record) []const u8 {
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
            const to_read = @minimum(remaining, MAX_PAYLOAD_LEN);
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

fn padFile(f: fs.File, size: ?usize) !void {
    if (size) |pad_size| {
        const current_size = try f.getEndPos();
        if (current_size < pad_size) {
            try f.seekTo(pad_size - 1);
            try f.writer().writeByte(0);
        }
        if (current_size > pad_size) {
            return error.FileTooLarge; // Maybe this shouldn't be an error?
        }
    }
}

fn emitRaw(allocator: Allocator, elf_path: []const u8, raw_path: []const u8, options: CreateOptions) !void {
    var elf_file = try fs.cwd().openFile(elf_path, .{});
    defer elf_file.close();

    var out_file = try fs.cwd().createFile(raw_path, .{});
    defer out_file.close();

    var binary_elf_output = try BinaryElfOutput.parse(allocator, elf_file);
    defer binary_elf_output.deinit();

    const effective_format = options.format orelse detectFormat(raw_path);

    if (options.only_section_name) |target_name| {
        switch (effective_format) {
            // Hex format can only write segments/phdrs, sections not supported yet
            .hex => return error.NotYetImplemented,
            .bin => {
                for (binary_elf_output.sections.items) |section| {
                    if (section.name) |curr_name| {
                        if (!std.mem.eql(u8, curr_name, target_name))
                            continue;
                    } else {
                        continue;
                    }

                    try writeBinaryElfSection(elf_file, out_file, section);
                    try padFile(out_file, options.pad_to_size);
                    return;
                }
            },
        }

        return error.SectionNotFound;
    }

    switch (effective_format) {
        .bin => {
            for (binary_elf_output.sections.items) |section| {
                try out_file.seekTo(section.binaryOffset);
                try writeBinaryElfSection(elf_file, out_file, section);
            }
            try padFile(out_file, options.pad_to_size);
        },
        .hex => {
            if (binary_elf_output.segments.items.len == 0) return;
            if (!containsValidAddressRange(binary_elf_output.segments.items)) {
                return error.InvalidHexfileAddressRange;
            }

            var hex_writer = HexWriter{ .out_file = out_file };
            for (binary_elf_output.sections.items) |section| {
                if (section.segment) |segment| {
                    try hex_writer.writeSegment(segment, elf_file);
                }
            }
            if (options.pad_to_size) |_| {
                // Padding to a size in hex files isn't applicable
                return error.InvalidArgument;
            }
            try hex_writer.writeEOF();
        },
    }
}

const InstallRawStep = @This();

pub const base_id = .install_raw;

pub const RawFormat = enum {
    bin,
    hex,
};

step: Step,
builder: *Builder,
artifact: *LibExeObjStep,
dest_dir: InstallDir,
dest_filename: []const u8,
options: CreateOptions,
output_file: std.build.GeneratedFile,

fn detectFormat(filename: []const u8) RawFormat {
    if (std.mem.endsWith(u8, filename, ".hex") or std.mem.endsWith(u8, filename, ".ihex")) {
        return .hex;
    }
    return .bin;
}

pub const CreateOptions = struct {
    format: ?RawFormat = null,
    dest_dir: ?InstallDir = null,
    only_section_name: ?[]const u8 = null,
    pad_to_size: ?usize = null,
};

pub fn create(builder: *Builder, artifact: *LibExeObjStep, dest_filename: []const u8, options: CreateOptions) *InstallRawStep {
    const self = builder.allocator.create(InstallRawStep) catch unreachable;
    self.* = InstallRawStep{
        .step = Step.init(.install_raw, builder.fmt("install raw binary {s}", .{artifact.step.name}), builder.allocator, make),
        .builder = builder,
        .artifact = artifact,
        .dest_dir = if (options.dest_dir) |d| d else switch (artifact.kind) {
            .obj => unreachable,
            .@"test" => unreachable,
            .exe, .test_exe => .bin,
            .lib => unreachable,
        },
        .dest_filename = dest_filename,
        .options = options,
        .output_file = std.build.GeneratedFile{ .step = &self.step },
    };
    self.step.dependOn(&artifact.step);

    builder.pushInstalledFile(self.dest_dir, dest_filename);
    return self;
}

pub fn getOutputSource(self: *const InstallRawStep) std.build.FileSource {
    return std.build.FileSource{ .generated = &self.output_file };
}

fn make(step: *Step) !void {
    const self = @fieldParentPtr(InstallRawStep, "step", step);
    const builder = self.builder;

    if (self.artifact.target.getObjectFormat() != .elf) {
        std.debug.print("InstallRawStep only works with ELF format.\n", .{});
        return error.InvalidObjectFormat;
    }

    const full_src_path = self.artifact.getOutputSource().getPath(builder);
    const full_dest_path = builder.getInstallPath(self.dest_dir, self.dest_filename);

    fs.cwd().makePath(builder.getInstallPath(self.dest_dir, "")) catch unreachable;
    try emitRaw(builder.allocator, full_src_path, full_dest_path, self.options);
    self.output_file.path = full_dest_path;
}

test {
    std.testing.refAllDecls(InstallRawStep);
}

test "Detect format from filename" {
    try std.testing.expectEqual(RawFormat.hex, detectFormat("foo.hex"));
    try std.testing.expectEqual(RawFormat.hex, detectFormat("foo.ihex"));
    try std.testing.expectEqual(RawFormat.bin, detectFormat("foo.bin"));
    try std.testing.expectEqual(RawFormat.bin, detectFormat("foo.bar"));
    try std.testing.expectEqual(RawFormat.bin, detectFormat("a"));
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
