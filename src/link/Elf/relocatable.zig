pub fn flushStaticLib(elf_file: *Elf, comp: *Compilation, module_obj_path: ?[]const u8) link.File.FlushError!void {
    const gpa = comp.gpa;

    var positionals = std.ArrayList(Compilation.LinkObject).init(gpa);
    defer positionals.deinit();

    try positionals.ensureUnusedCapacity(comp.objects.len);
    positionals.appendSliceAssumeCapacity(comp.objects);

    for (comp.c_object_table.keys()) |key| {
        try positionals.append(.{ .path = key.status.success.object_path });
    }

    if (module_obj_path) |path| try positionals.append(.{ .path = path });

    if (comp.include_compiler_rt) {
        try positionals.append(.{ .path = comp.compiler_rt_obj.?.full_object_path });
    }

    for (positionals.items) |obj| {
        parsePositionalStaticLib(elf_file, obj.path) catch |err| switch (err) {
            error.MalformedObject,
            error.MalformedArchive,
            error.InvalidMachineType,
            error.MismatchedEflags,
            => continue, // already reported
            error.UnknownFileType => try elf_file.reportParseError(obj.path, "unknown file type for an object file", .{}),
            else => |e| try elf_file.reportParseError(
                obj.path,
                "unexpected error: parsing input file failed with error {s}",
                .{@errorName(e)},
            ),
        };
    }

    if (elf_file.base.hasErrors()) return error.FlushFailure;

    // First, we flush relocatable object file generated with our backends.
    if (elf_file.zigObjectPtr()) |zig_object| {
        try zig_object.resolveSymbols(elf_file);
        elf_file.markEhFrameAtomsDead();
        try elf_file.addCommentString();
        try elf_file.finalizeMergeSections();
        zig_object.claimUnresolvedRelocatable(elf_file);

        try initSections(elf_file);
        try elf_file.sortShdrs();
        try zig_object.addAtomsToRelaSections(elf_file);
        try elf_file.updateMergeSectionSizes();
        try updateSectionSizes(elf_file);

        try allocateAllocSections(elf_file);
        try elf_file.allocateNonAllocSections();

        if (build_options.enable_logging) {
            state_log.debug("{}", .{elf_file.dumpState()});
        }

        try elf_file.writeMergeSections();
        try writeSyntheticSections(elf_file);
        try elf_file.writeShdrTable();
        try elf_file.writeElfHeader();

        // TODO we can avoid reading in the file contents we just wrote if we give the linker
        // ability to write directly to a buffer.
        try zig_object.readFileContents(elf_file);
    }

    var files = std.ArrayList(File.Index).init(gpa);
    defer files.deinit();
    try files.ensureTotalCapacityPrecise(elf_file.objects.items.len + 1);
    if (elf_file.zigObjectPtr()) |zig_object| files.appendAssumeCapacity(zig_object.index);
    for (elf_file.objects.items) |index| files.appendAssumeCapacity(index);

    // Update ar symtab from parsed objects
    var ar_symtab: Archive.ArSymtab = .{};
    defer ar_symtab.deinit(gpa);

    for (files.items) |index| {
        try elf_file.file(index).?.updateArSymtab(&ar_symtab, elf_file);
    }

    ar_symtab.sort();

    // Save object paths in filenames strtab.
    var ar_strtab: Archive.ArStrtab = .{};
    defer ar_strtab.deinit(gpa);

    for (files.items) |index| {
        const file_ptr = elf_file.file(index).?;
        try file_ptr.updateArStrtab(gpa, &ar_strtab);
        try file_ptr.updateArSize(elf_file);
    }

    // Update file offsets of contributing objects.
    const total_size: usize = blk: {
        var pos: usize = elf.ARMAG.len;
        pos += @sizeOf(elf.ar_hdr) + ar_symtab.size(.p64);

        if (ar_strtab.size() > 0) {
            pos = mem.alignForward(usize, pos, 2);
            pos += @sizeOf(elf.ar_hdr) + ar_strtab.size();
        }

        for (files.items) |index| {
            const file_ptr = elf_file.file(index).?;
            const state = switch (file_ptr) {
                .zig_object => |x| &x.output_ar_state,
                .object => |x| &x.output_ar_state,
                else => unreachable,
            };
            pos = mem.alignForward(usize, pos, 2);
            state.file_off = pos;
            pos += @sizeOf(elf.ar_hdr) + (math.cast(usize, state.size) orelse return error.Overflow);
        }

        break :blk pos;
    };

    if (build_options.enable_logging) {
        state_log.debug("ar_symtab\n{}\n", .{ar_symtab.fmt(elf_file)});
        state_log.debug("ar_strtab\n{}\n", .{ar_strtab});
    }

    var buffer = std.ArrayList(u8).init(gpa);
    defer buffer.deinit();
    try buffer.ensureTotalCapacityPrecise(total_size);

    // Write magic
    try buffer.writer().writeAll(elf.ARMAG);

    // Write symtab
    try ar_symtab.write(.p64, elf_file, buffer.writer());

    // Write strtab
    if (ar_strtab.size() > 0) {
        if (!mem.isAligned(buffer.items.len, 2)) try buffer.writer().writeByte(0);
        try ar_strtab.write(buffer.writer());
    }

    // Write object files
    for (files.items) |index| {
        if (!mem.isAligned(buffer.items.len, 2)) try buffer.writer().writeByte(0);
        try elf_file.file(index).?.writeAr(elf_file, buffer.writer());
    }

    assert(buffer.items.len == total_size);

    try elf_file.base.file.?.setEndPos(total_size);
    try elf_file.base.file.?.pwriteAll(buffer.items, 0);

    if (elf_file.base.hasErrors()) return error.FlushFailure;
}

pub fn flushObject(elf_file: *Elf, comp: *Compilation, module_obj_path: ?[]const u8) link.File.FlushError!void {
    const gpa = elf_file.base.comp.gpa;

    var positionals = std.ArrayList(Compilation.LinkObject).init(gpa);
    defer positionals.deinit();
    try positionals.ensureUnusedCapacity(comp.objects.len);
    positionals.appendSliceAssumeCapacity(comp.objects);

    // This is a set of object files emitted by clang in a single `build-exe` invocation.
    // For instance, the implicit `a.o` as compiled by `zig build-exe a.c` will end up
    // in this set.
    for (comp.c_object_table.keys()) |key| {
        try positionals.append(.{ .path = key.status.success.object_path });
    }

    if (module_obj_path) |path| try positionals.append(.{ .path = path });

    for (positionals.items) |obj| {
        elf_file.parsePositional(obj.path, obj.must_link) catch |err| switch (err) {
            error.MalformedObject,
            error.MalformedArchive,
            error.InvalidMachineType,
            error.MismatchedEflags,
            => continue, // already reported
            else => |e| try elf_file.reportParseError(
                obj.path,
                "unexpected error: parsing input file failed with error {s}",
                .{@errorName(e)},
            ),
        };
    }

    if (elf_file.base.hasErrors()) return error.FlushFailure;

    // Now, we are ready to resolve the symbols across all input files.
    // We will first resolve the files in the ZigObject, next in the parsed
    // input Object files.
    try elf_file.resolveSymbols();
    elf_file.markEhFrameAtomsDead();
    try elf_file.resolveMergeSections();
    try elf_file.addCommentString();
    try elf_file.finalizeMergeSections();
    claimUnresolved(elf_file);

    try initSections(elf_file);
    try elf_file.sortShdrs();
    if (elf_file.zigObjectPtr()) |zig_object| {
        try zig_object.addAtomsToRelaSections(elf_file);
    }
    for (elf_file.objects.items) |index| {
        const object = elf_file.file(index).?.object;
        try object.addAtomsToRelaSections(elf_file);
    }
    try elf_file.updateMergeSectionSizes();
    try updateSectionSizes(elf_file);

    try allocateAllocSections(elf_file);
    try elf_file.allocateNonAllocSections();

    if (build_options.enable_logging) {
        state_log.debug("{}", .{elf_file.dumpState()});
    }

    try writeAtoms(elf_file);
    try elf_file.writeMergeSections();
    try writeSyntheticSections(elf_file);
    try elf_file.writeShdrTable();
    try elf_file.writeElfHeader();

    if (elf_file.base.hasErrors()) return error.FlushFailure;
}

fn parsePositionalStaticLib(elf_file: *Elf, path: []const u8) Elf.ParseError!void {
    if (try Object.isObject(path)) {
        try parseObjectStaticLib(elf_file, path);
    } else if (try Archive.isArchive(path)) {
        try parseArchiveStaticLib(elf_file, path);
    } else return error.UnknownFileType;
    // TODO: should we check for LD script?
    // Actually, should we even unpack an archive?
}

fn parseObjectStaticLib(elf_file: *Elf, path: []const u8) Elf.ParseError!void {
    const gpa = elf_file.base.comp.gpa;
    const handle = try std.fs.cwd().openFile(path, .{});
    const fh = try elf_file.addFileHandle(handle);

    const index = @as(File.Index, @intCast(try elf_file.files.addOne(gpa)));
    elf_file.files.set(index, .{ .object = .{
        .path = try gpa.dupe(u8, path),
        .file_handle = fh,
        .index = index,
    } });
    try elf_file.objects.append(gpa, index);

    const object = elf_file.file(index).?.object;
    try object.parseAr(elf_file);
}

fn parseArchiveStaticLib(elf_file: *Elf, path: []const u8) Elf.ParseError!void {
    const gpa = elf_file.base.comp.gpa;
    const handle = try std.fs.cwd().openFile(path, .{});
    const fh = try elf_file.addFileHandle(handle);

    var archive = Archive{};
    defer archive.deinit(gpa);
    try archive.parse(elf_file, path, fh);

    const objects = try archive.objects.toOwnedSlice(gpa);
    defer gpa.free(objects);

    for (objects) |extracted| {
        const index = @as(File.Index, @intCast(try elf_file.files.addOne(gpa)));
        elf_file.files.set(index, .{ .object = extracted });
        const object = &elf_file.files.items(.data)[index].object;
        object.index = index;
        try object.parseAr(elf_file);
        try elf_file.objects.append(gpa, index);
    }
}

fn claimUnresolved(elf_file: *Elf) void {
    if (elf_file.zigObjectPtr()) |zig_object| {
        zig_object.claimUnresolvedRelocatable(elf_file);
    }
    for (elf_file.objects.items) |index| {
        elf_file.file(index).?.object.claimUnresolvedRelocatable(elf_file);
    }
}

fn initSections(elf_file: *Elf) !void {
    if (elf_file.zigObjectPtr()) |zo| {
        try zo.initRelaSections(elf_file);
    }
    for (elf_file.objects.items) |index| {
        const object = elf_file.file(index).?.object;
        try object.initOutputSections(elf_file);
        try object.initRelaSections(elf_file);
    }

    for (elf_file.merge_sections.items) |*msec| {
        if (msec.finalized_subsections.items.len == 0) continue;
        try msec.initOutputSection(elf_file);
    }

    const needs_eh_frame = blk: {
        if (elf_file.zigObjectPtr()) |zo|
            if (zo.eh_frame_index != null) break :blk true;
        break :blk for (elf_file.objects.items) |index| {
            if (elf_file.file(index).?.object.cies.items.len > 0) break true;
        } else false;
    };
    if (needs_eh_frame) {
        if (elf_file.eh_frame_section_index == null) {
            elf_file.eh_frame_section_index = elf_file.sectionByName(".eh_frame") orelse
                try elf_file.addSection(.{
                .name = try elf_file.insertShString(".eh_frame"),
                .type = if (elf_file.getTarget().cpu.arch == .x86_64)
                    elf.SHT_X86_64_UNWIND
                else
                    elf.SHT_PROGBITS,
                .flags = elf.SHF_ALLOC,
                .addralign = elf_file.ptrWidthBytes(),
                .offset = std.math.maxInt(u64),
            });
        }
        elf_file.eh_frame_rela_section_index = elf_file.sectionByName(".rela.eh_frame") orelse
            try elf_file.addRelaShdr(
            try elf_file.insertShString(".rela.eh_frame"),
            elf_file.eh_frame_section_index.?,
        );
    }

    try initComdatGroups(elf_file);
    try elf_file.initSymtab();
    try elf_file.initShStrtab();
}

fn initComdatGroups(elf_file: *Elf) !void {
    const gpa = elf_file.base.comp.gpa;

    for (elf_file.objects.items) |index| {
        const object = elf_file.file(index).?.object;
        for (object.comdat_groups.items, 0..) |cg, cg_index| {
            if (!cg.alive) continue;
            const cg_sec = try elf_file.comdat_group_sections.addOne(gpa);
            cg_sec.* = .{
                .shndx = try elf_file.addSection(.{
                    .name = try elf_file.insertShString(".group"),
                    .type = elf.SHT_GROUP,
                    .entsize = @sizeOf(u32),
                    .addralign = @alignOf(u32),
                    .offset = std.math.maxInt(u64),
                }),
                .cg_ref = .{ .index = @intCast(cg_index), .file = index },
            };
        }
    }
}

fn updateSectionSizes(elf_file: *Elf) !void {
    const slice = elf_file.sections.slice();
    for (slice.items(.atom_list_2)) |*atom_list| {
        if (atom_list.atoms.items.len == 0) continue;
        atom_list.updateSize(elf_file);
        try atom_list.allocate(elf_file);
    }

    for (slice.items(.shdr), 0..) |*shdr, shndx| {
        const atom_list = slice.items(.atom_list)[shndx];
        if (shdr.sh_type != elf.SHT_RELA) continue;
        if (@as(u32, @intCast(shndx)) == elf_file.eh_frame_section_index) continue;
        for (atom_list.items) |ref| {
            const atom_ptr = elf_file.atom(ref) orelse continue;
            if (!atom_ptr.alive) continue;
            const relocs = atom_ptr.relocs(elf_file);
            shdr.sh_size += shdr.sh_entsize * relocs.len;
        }

        if (shdr.sh_size == 0) shdr.sh_offset = 0;
    }

    if (elf_file.eh_frame_section_index) |index| {
        slice.items(.shdr)[index].sh_size = try eh_frame.calcEhFrameSize(elf_file);
    }
    if (elf_file.eh_frame_rela_section_index) |index| {
        const shdr = &slice.items(.shdr)[index];
        shdr.sh_size = eh_frame.calcEhFrameRelocs(elf_file) * shdr.sh_entsize;
    }

    try elf_file.updateSymtabSize();
    updateComdatGroupsSizes(elf_file);
    elf_file.updateShStrtabSize();
}

fn updateComdatGroupsSizes(elf_file: *Elf) void {
    for (elf_file.comdat_group_sections.items) |cg| {
        const shdr = &elf_file.sections.items(.shdr)[cg.shndx];
        shdr.sh_size = cg.size(elf_file);
        shdr.sh_link = elf_file.symtab_section_index.?;

        const sym = cg.symbol(elf_file);
        shdr.sh_info = sym.outputSymtabIndex(elf_file) orelse sym.outputShndx(elf_file).?;
    }
}

/// Allocates alloc sections when merging relocatable objects files together.
fn allocateAllocSections(elf_file: *Elf) !void {
    for (elf_file.sections.items(.shdr), 0..) |*shdr, shndx| {
        if (shdr.sh_type == elf.SHT_NULL) continue;
        if (shdr.sh_flags & elf.SHF_ALLOC == 0) continue;
        if (shdr.sh_type == elf.SHT_NOBITS) {
            shdr.sh_offset = 0;
            continue;
        }
        const needed_size = shdr.sh_size;
        if (needed_size > elf_file.allocatedSize(shdr.sh_offset)) {
            shdr.sh_size = 0;
            const new_offset = try elf_file.findFreeSpace(needed_size, shdr.sh_addralign);

            if (elf_file.zigObjectPtr()) |zo| blk: {
                const existing_size = for ([_]?Symbol.Index{
                    zo.text_index,
                    zo.rodata_index,
                    zo.data_relro_index,
                    zo.data_index,
                    zo.tdata_index,
                    zo.eh_frame_index,
                }) |maybe_sym_index| {
                    const sect_sym_index = maybe_sym_index orelse continue;
                    const sect_atom_ptr = zo.symbol(sect_sym_index).atom(elf_file).?;
                    if (sect_atom_ptr.output_section_index == shndx) break sect_atom_ptr.size;
                } else break :blk;
                log.debug("moving {s} from 0x{x} to 0x{x}", .{
                    elf_file.getShString(shdr.sh_name),
                    shdr.sh_offset,
                    new_offset,
                });
                const amt = try elf_file.base.file.?.copyRangeAll(
                    shdr.sh_offset,
                    elf_file.base.file.?,
                    new_offset,
                    existing_size,
                );
                if (amt != existing_size) return error.InputOutput;
            }

            shdr.sh_offset = new_offset;
            shdr.sh_size = needed_size;
        }
    }
}

fn writeAtoms(elf_file: *Elf) !void {
    const gpa = elf_file.base.comp.gpa;

    var buffer = std.ArrayList(u8).init(gpa);
    defer buffer.deinit();

    const slice = elf_file.sections.slice();
    for (slice.items(.shdr), slice.items(.atom_list_2)) |shdr, atom_list| {
        if (shdr.sh_type == elf.SHT_NOBITS) continue;
        if (atom_list.atoms.items.len == 0) continue;
        try atom_list.writeRelocatable(&buffer, elf_file);
    }
}

fn writeSyntheticSections(elf_file: *Elf) !void {
    const gpa = elf_file.base.comp.gpa;
    const slice = elf_file.sections.slice();

    for (slice.items(.shdr), slice.items(.atom_list), 0..) |shdr, atom_list, shndx| {
        if (shdr.sh_type != elf.SHT_RELA) continue;
        if (atom_list.items.len == 0) continue;
        if (@as(u32, @intCast(shndx)) == elf_file.eh_frame_section_index) continue;

        const num_relocs = math.cast(usize, @divExact(shdr.sh_size, shdr.sh_entsize)) orelse
            return error.Overflow;
        var relocs = try std.ArrayList(elf.Elf64_Rela).initCapacity(gpa, num_relocs);
        defer relocs.deinit();

        for (atom_list.items) |ref| {
            const atom_ptr = elf_file.atom(ref) orelse continue;
            if (!atom_ptr.alive) continue;
            try atom_ptr.writeRelocs(elf_file, &relocs);
        }
        assert(relocs.items.len == num_relocs);

        const SortRelocs = struct {
            pub fn lessThan(ctx: void, lhs: elf.Elf64_Rela, rhs: elf.Elf64_Rela) bool {
                _ = ctx;
                return lhs.r_offset < rhs.r_offset;
            }
        };

        mem.sort(elf.Elf64_Rela, relocs.items, {}, SortRelocs.lessThan);

        log.debug("writing {s} from 0x{x} to 0x{x}", .{
            elf_file.getShString(shdr.sh_name),
            shdr.sh_offset,
            shdr.sh_offset + shdr.sh_size,
        });

        try elf_file.base.file.?.pwriteAll(mem.sliceAsBytes(relocs.items), shdr.sh_offset);
    }

    if (elf_file.eh_frame_section_index) |shndx| {
        const existing_size = existing_size: {
            const zo = elf_file.zigObjectPtr() orelse break :existing_size 0;
            const sym = zo.symbol(zo.eh_frame_index orelse break :existing_size 0);
            break :existing_size sym.atom(elf_file).?.size;
        };
        const shdr = slice.items(.shdr)[shndx];
        const sh_size = math.cast(usize, shdr.sh_size) orelse return error.Overflow;
        var buffer = try std.ArrayList(u8).initCapacity(gpa, @intCast(sh_size - existing_size));
        defer buffer.deinit();
        try eh_frame.writeEhFrameRelocatable(elf_file, buffer.writer());
        log.debug("writing .eh_frame from 0x{x} to 0x{x}", .{
            shdr.sh_offset + existing_size,
            shdr.sh_offset + sh_size,
        });
        assert(buffer.items.len == sh_size - existing_size);
        try elf_file.base.file.?.pwriteAll(buffer.items, shdr.sh_offset + existing_size);
    }
    if (elf_file.eh_frame_rela_section_index) |shndx| {
        const shdr = slice.items(.shdr)[shndx];
        const sh_size = math.cast(usize, shdr.sh_size) orelse return error.Overflow;
        var buffer = try std.ArrayList(u8).initCapacity(gpa, sh_size);
        defer buffer.deinit();
        try eh_frame.writeEhFrameRelocs(elf_file, buffer.writer());
        assert(buffer.items.len == sh_size);
        log.debug("writing .rela.eh_frame from 0x{x} to 0x{x}", .{
            shdr.sh_offset,
            shdr.sh_offset + shdr.sh_size,
        });
        try elf_file.base.file.?.pwriteAll(buffer.items, shdr.sh_offset);
    }

    try writeComdatGroups(elf_file);
    try elf_file.writeSymtab();
    try elf_file.writeShStrtab();
}

fn writeComdatGroups(elf_file: *Elf) !void {
    const gpa = elf_file.base.comp.gpa;
    for (elf_file.comdat_group_sections.items) |cgs| {
        const shdr = elf_file.sections.items(.shdr)[cgs.shndx];
        const sh_size = math.cast(usize, shdr.sh_size) orelse return error.Overflow;
        var buffer = try std.ArrayList(u8).initCapacity(gpa, sh_size);
        defer buffer.deinit();
        try cgs.write(elf_file, buffer.writer());
        assert(buffer.items.len == sh_size);
        log.debug("writing COMDAT group from 0x{x} to 0x{x}", .{
            shdr.sh_offset,
            shdr.sh_offset + shdr.sh_size,
        });
        try elf_file.base.file.?.pwriteAll(buffer.items, shdr.sh_offset);
    }
}

const assert = std.debug.assert;
const build_options = @import("build_options");
const eh_frame = @import("eh_frame.zig");
const elf = std.elf;
const link = @import("../../link.zig");
const log = std.log.scoped(.link);
const math = std.math;
const mem = std.mem;
const state_log = std.log.scoped(.link_state);
const std = @import("std");

const Archive = @import("Archive.zig");
const Compilation = @import("../../Compilation.zig");
const Elf = @import("../Elf.zig");
const File = @import("file.zig").File;
const Object = @import("Object.zig");
const Symbol = @import("Symbol.zig");
