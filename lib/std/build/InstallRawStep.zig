// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
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

    pub fn deinit(self: *Self) void {
        self.sections.deinit();
        self.segments.deinit();
    }

    pub fn parse(allocator: *Allocator, elf_file: File) !Self {
        var self: Self = .{
            .segments = ArrayList(*BinaryElfSegment).init(allocator),
            .sections = ArrayList(*BinaryElfSection).init(allocator),
        };
        const elf_hdr = try std.elf.Header.read(&elf_file);

        var section_headers = elf_hdr.section_header_iterator(&elf_file);
        while (try section_headers.next()) |section| {
            if (sectionValidForOutput(section)) {
                const newSection = try allocator.create(BinaryElfSection);

                newSection.binaryOffset = 0;
                newSection.elfOffset = section.sh_offset;
                newSection.fileSize = @intCast(usize, section.sh_size);
                newSection.segment = null;

                try self.sections.append(newSection);
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

                try self.segments.append(newSegment);
            }
        }

        sort.sort(*BinaryElfSegment, self.segments.items, {}, segmentSortCompare);

        if (self.segments.items.len > 0) {
            const firstSegment = self.segments.items[0];
            if (firstSegment.firstSection) |firstSection| {
                const diff = firstSection.elfOffset - firstSegment.elfOffset;

                firstSegment.elfOffset += diff;
                firstSegment.fileSize += diff;
                firstSegment.physicalAddress += diff;

                const basePhysicalAddress = firstSegment.physicalAddress;

                for (self.segments.items) |segment| {
                    segment.binaryOffset = segment.physicalAddress - basePhysicalAddress;
                }
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
    try out_file.seekTo(section.binaryOffset);

    try out_file.writeFileAll(elf_file, .{
        .in_offset = section.elfOffset,
        .in_len = section.fileSize,
    });
}

fn emitRaw(allocator: *Allocator, elf_path: []const u8, raw_path: []const u8) !void {
    var elf_file = try fs.cwd().openFile(elf_path, .{});
    defer elf_file.close();

    var out_file = try fs.cwd().createFile(raw_path, .{});
    defer out_file.close();

    var binary_elf_output = try BinaryElfOutput.parse(allocator, elf_file);
    defer binary_elf_output.deinit();

    for (binary_elf_output.sections.items) |section| {
        try writeBinaryElfSection(elf_file, out_file, section);
    }
}

const InstallRawStep = @This();

pub const base_id = .install_raw;

step: Step,
builder: *Builder,
artifact: *LibExeObjStep,
dest_dir: InstallDir,
dest_filename: []const u8,

pub fn create(builder: *Builder, artifact: *LibExeObjStep, dest_filename: []const u8) *InstallRawStep {
    const self = builder.allocator.create(InstallRawStep) catch unreachable;
    self.* = InstallRawStep{
        .step = Step.init(.install_raw, builder.fmt("install raw binary {s}", .{artifact.step.name}), builder.allocator, make),
        .builder = builder,
        .artifact = artifact,
        .dest_dir = switch (artifact.kind) {
            .obj => unreachable,
            .@"test" => unreachable,
            .exe => .bin,
            .lib => unreachable,
        },
        .dest_filename = dest_filename,
    };
    self.step.dependOn(&artifact.step);

    builder.pushInstalledFile(self.dest_dir, dest_filename);
    return self;
}

fn make(step: *Step) !void {
    const self = @fieldParentPtr(InstallRawStep, "step", step);
    const builder = self.builder;

    if (self.artifact.target.getObjectFormat() != .elf) {
        warn("InstallRawStep only works with ELF format.\n", .{});
        return error.InvalidObjectFormat;
    }

    const full_src_path = self.artifact.getOutputSource().getPath(builder);
    const full_dest_path = builder.getInstallPath(self.dest_dir, self.dest_filename);

    fs.cwd().makePath(builder.getInstallPath(self.dest_dir, "")) catch unreachable;
    try emitRaw(builder.allocator, full_src_path, full_dest_path);
}

test {
    std.testing.refAllDecls(InstallRawStep);
}
