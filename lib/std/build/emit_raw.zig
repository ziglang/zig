const std = @import("std");

const Allocator = std.mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;
const ArrayList = std.ArrayList;
const Builder = std.build.Builder;
const File = std.fs.File;
const InstallDir = std.build.InstallDir;
const LibExeObjStep = std.build.LibExeObjStep;
const Step = std.build.Step;
const elf = std.elf;
const fs = std.fs;
const io = std.io;
const sort = std.sort;
const warn = std.debug.warn;

const BinOutStream = io.OutStream(anyerror);
const BinSeekStream = io.SeekableStream(anyerror, anyerror);
const ElfSeekStream = io.SeekableStream(anyerror, anyerror);
const ElfInStream = io.InStream(anyerror);

const BinaryElfSection = struct {
    elfOffset: u64,
    binaryOffset: u64,
    fileSize: usize,
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
    segments: ArrayList(*BinaryElfSegment),
    sections: ArrayList(*BinaryElfSection),

    const Self = @This();

    pub fn init(allocator: *Allocator) Self {
        return Self{
            .segments = ArrayList(*BinaryElfSegment).init(allocator),
            .sections = ArrayList(*BinaryElfSection).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.sections.deinit();
        self.segments.deinit();
    }

    pub fn parseElf(self: *Self, elfFile: elf.Elf) !void {
        const allocator = self.segments.allocator;

        for (elfFile.section_headers) |section, i| {
            if (sectionValidForOutput(section)) {
                const newSection = try allocator.create(BinaryElfSection);

                newSection.binaryOffset = 0;
                newSection.elfOffset = section.sh_offset;
                newSection.fileSize = @intCast(usize, section.sh_size);
                newSection.segment = null;

                try self.sections.append(newSection);
            }
        }

        for (elfFile.program_headers) |programHeader, i| {
            if (programHeader.p_type == elf.PT_LOAD) {
                const newSegment = try allocator.create(BinaryElfSegment);

                newSegment.physicalAddress = if (programHeader.p_paddr != 0) programHeader.p_paddr else programHeader.p_vaddr;
                newSegment.virtualAddress = programHeader.p_vaddr;
                newSegment.fileSize = @intCast(usize, programHeader.p_filesz);
                newSegment.elfOffset = programHeader.p_offset;
                newSegment.binaryOffset = 0;
                newSegment.firstSection = null;

                for (self.sections.toSlice()) |section| {
                    if (sectionWithinSegment(section, programHeader)) {
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

                try self.segments.append(newSegment);
            }
        }

        sort.sort(*BinaryElfSegment, self.segments.toSlice(), segmentSortCompare);

        if (self.segments.len > 0) {
            const firstSegment = self.segments.at(0);
            if (firstSegment.firstSection) |firstSection| {
                const diff = firstSection.elfOffset - firstSegment.elfOffset;

                firstSegment.elfOffset += diff;
                firstSegment.fileSize += diff;
                firstSegment.physicalAddress += diff;

                const basePhysicalAddress = firstSegment.physicalAddress;

                for (self.segments.toSlice()) |segment| {
                    segment.binaryOffset = segment.physicalAddress - basePhysicalAddress;
                }
            }
        }

        for (self.sections.toSlice()) |section| {
            if (section.segment) |segment| {
                section.binaryOffset = segment.binaryOffset + (section.elfOffset - segment.elfOffset);
            }
        }

        sort.sort(*BinaryElfSection, self.sections.toSlice(), sectionSortCompare);
    }

    fn sectionWithinSegment(section: *BinaryElfSection, segment: elf.ProgramHeader) bool {
        return segment.p_offset <= section.elfOffset and (segment.p_offset + segment.p_filesz) >= (section.elfOffset + section.fileSize);
    }

    fn sectionValidForOutput(section: elf.SectionHeader) bool {
        return section.sh_size > 0 and section.sh_type != elf.SHT_NOBITS and ((section.sh_flags & elf.SHF_ALLOC) == elf.SHF_ALLOC);
    }

    fn segmentSortCompare(left: *BinaryElfSegment, right: *BinaryElfSegment) bool {
        if (left.physicalAddress < right.physicalAddress) {
            return true;
        }
        if (left.physicalAddress > right.physicalAddress) {
            return false;
        }
        return false;
    }

    fn sectionSortCompare(left: *BinaryElfSection, right: *BinaryElfSection) bool {
        return left.binaryOffset < right.binaryOffset;
    }
};

const WriteContext = struct {
    inStream: *ElfInStream,
    inSeekStream: *ElfSeekStream,
    outStream: *BinOutStream,
    outSeekStream: *BinSeekStream,
};

fn writeBinaryElfSection(allocator: *Allocator, context: WriteContext, section: *BinaryElfSection) !void {
    var readBuffer = try allocator.alloc(u8, section.fileSize);
    defer allocator.free(readBuffer);

    try context.inSeekStream.seekTo(section.elfOffset);
    _ = try context.inStream.read(readBuffer);

    try context.outSeekStream.seekTo(section.binaryOffset);
    try context.outStream.write(readBuffer);
}

fn emit_raw(allocator: *Allocator, elf_path: []const u8, raw_path: []const u8) !void {
    var arenaAlloc = ArenaAllocator.init(allocator);
    errdefer arenaAlloc.deinit();
    var arena_allocator = &arenaAlloc.allocator;

    const currentDir = fs.cwd();

    var file = try currentDir.openFile(elf_path, File.OpenFlags{});
    defer file.close();

    var fileInStream = file.inStream();
    var fileSeekStream = file.seekableStream();

    var elfFile = try elf.Elf.openStream(allocator, @ptrCast(*ElfSeekStream, &fileSeekStream.stream), @ptrCast(*ElfInStream, &fileInStream.stream));
    defer elfFile.close();

    var outFile = try currentDir.createFile(raw_path, File.CreateFlags{});
    defer outFile.close();

    var outFileOutStream = outFile.outStream();
    var outFileSeekStream = outFile.seekableStream();

    const writeContext = WriteContext{
        .inStream = @ptrCast(*ElfInStream, &fileInStream.stream),
        .inSeekStream = @ptrCast(*ElfSeekStream, &fileSeekStream.stream),
        .outStream = @ptrCast(*BinOutStream, &outFileOutStream.stream),
        .outSeekStream = @ptrCast(*BinSeekStream, &outFileSeekStream.stream),
    };

    var binaryElfOutput = BinaryElfOutput.init(arena_allocator);
    defer binaryElfOutput.deinit();

    try binaryElfOutput.parseElf(elfFile);

    for (binaryElfOutput.sections.toSlice()) |section| {
        try writeBinaryElfSection(allocator, writeContext, section);
    }
}

pub const InstallRawStep = struct {
    step: Step,
    builder: *Builder,
    artifact: *LibExeObjStep,
    dest_dir: InstallDir,
    dest_filename: [] const u8,

    const Self = @This();

    pub fn create(builder: *Builder, artifact: *LibExeObjStep, dest_filename: [] const u8) *Self {
        const self = builder.allocator.create(Self) catch unreachable;
        self.* = Self{
            .step = Step.init(builder.fmt("install raw binary {}", .{artifact.step.name}), builder.allocator, make),
            .builder = builder,
            .artifact = artifact,
            .dest_dir = switch (artifact.kind) {
                .Obj => unreachable,
                .Test => unreachable,
                .Exe => .Bin,
                .Lib => unreachable,
            },
            .dest_filename = dest_filename,
        };
        self.step.dependOn(&artifact.step);

        builder.pushInstalledFile(self.dest_dir, dest_filename);
        return self;
    }

    fn make(step: *Step) !void {
        const self = @fieldParentPtr(Self, "step", step);
        const builder = self.builder;

        if (self.artifact.target.getObjectFormat() != .elf) {
            warn("InstallRawStep only works with ELF format.\n", .{});
            return error.InvalidObjectFormat;
        }

        const full_src_path = self.artifact.getOutputPath();
        const full_dest_path = builder.getInstallPath(self.dest_dir, self.dest_filename);

        fs.makePath(builder.allocator, builder.getInstallPath(self.dest_dir, "")) catch unreachable;
        try emit_raw(builder.allocator, full_src_path, full_dest_path);
    }
};