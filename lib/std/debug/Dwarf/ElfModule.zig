//! A thin wrapper around `Dwarf` which handles loading debug information from an ELF file. Load the
//! info with `load`, then directly access the `dwarf` field before finally `deinit`ing.

dwarf: Dwarf,

/// The memory-mapped ELF file, which is referenced by `dwarf`. This field is here only so that
/// this memory can be unmapped by `ElfModule.deinit`.
mapped_file: []align(std.heap.page_size_min) const u8,
/// Sometimes, debug info is stored separately to the main ELF file. In that case, `mapped_file`
/// is the mapped ELF binary, and `mapped_debug_file` is the mapped debug info file. Both must
/// be unmapped by `ElfModule.deinit`.
mapped_debug_file: ?[]align(std.heap.page_size_min) const u8,

pub fn deinit(em: *ElfModule, allocator: Allocator) void {
    em.dwarf.deinit(allocator);
    std.posix.munmap(em.mapped_file);
    if (em.mapped_debug_file) |m| std.posix.munmap(m);
}

pub const LoadError = error{
    InvalidDebugInfo,
    MissingDebugInfo,
    InvalidElfMagic,
    InvalidElfVersion,
    InvalidElfEndian,
    /// TODO: implement this and then remove this error code
    UnimplementedDwarfForeignEndian,
    /// The debug info may be valid but this implementation uses memory
    /// mapping which limits things to usize. If the target debug info is
    /// 64-bit and host is 32-bit, there may be debug info that is not
    /// supportable using this method.
    Overflow,

    PermissionDenied,
    LockedMemoryLimitExceeded,
    MemoryMappingNotSupported,
} || Allocator.Error || std.fs.File.OpenError || Dwarf.OpenError;

/// Reads debug info from an ELF file given its path.
///
/// If the required sections aren't present but a reference to external debug
/// info is, then this this function will recurse to attempt to load the debug
/// sections from an external file.
pub fn load(
    gpa: Allocator,
    elf_file_path: Path,
    build_id: ?[]const u8,
    expected_crc: ?u32,
    parent_sections: ?*Dwarf.SectionArray,
    parent_mapped_mem: ?[]align(std.heap.page_size_min) const u8,
) LoadError!ElfModule {
    const mapped_mem: []align(std.heap.page_size_min) const u8 = mapped: {
        const elf_file = try elf_file_path.root_dir.handle.openFile(elf_file_path.sub_path, .{});
        defer elf_file.close();

        const file_len = std.math.cast(
            usize,
            elf_file.getEndPos() catch return Dwarf.bad(),
        ) orelse return error.Overflow;

        break :mapped std.posix.mmap(
            null,
            file_len,
            std.posix.PROT.READ,
            .{ .TYPE = .SHARED },
            elf_file.handle,
            0,
        ) catch |err| switch (err) {
            error.MappingAlreadyExists => unreachable,
            else => |e| return e,
        };
    };
    errdefer std.posix.munmap(mapped_mem);

    if (expected_crc) |crc| if (crc != std.hash.crc.Crc32.hash(mapped_mem)) return error.InvalidDebugInfo;

    const hdr: *const elf.Ehdr = @ptrCast(&mapped_mem[0]);
    if (!mem.eql(u8, hdr.e_ident[0..4], elf.MAGIC)) return error.InvalidElfMagic;
    if (hdr.e_ident[elf.EI_VERSION] != 1) return error.InvalidElfVersion;

    const endian: std.builtin.Endian = switch (hdr.e_ident[elf.EI_DATA]) {
        elf.ELFDATA2LSB => .little,
        elf.ELFDATA2MSB => .big,
        else => return error.InvalidElfEndian,
    };
    if (endian != native_endian) return error.UnimplementedDwarfForeignEndian;

    const shoff = hdr.e_shoff;
    const str_section_off = std.math.cast(
        usize,
        shoff + @as(u64, hdr.e_shentsize) * @as(u64, hdr.e_shstrndx),
    ) orelse return error.Overflow;
    const str_shdr: *const elf.Shdr = @ptrCast(@alignCast(mapped_mem[str_section_off..]));
    const header_strings = mapped_mem[str_shdr.sh_offset..][0..str_shdr.sh_size];
    const shdrs = @as(
        [*]const elf.Shdr,
        @ptrCast(@alignCast(&mapped_mem[shoff])),
    )[0..hdr.e_shnum];

    var sections: Dwarf.SectionArray = @splat(null);

    // Combine section list. This takes ownership over any owned sections from the parent scope.
    if (parent_sections) |ps| {
        for (ps, &sections) |*parent, *section_elem| {
            if (parent.*) |*p| {
                section_elem.* = p.*;
                p.owned = false;
            }
        }
    }
    errdefer for (sections) |opt_section| if (opt_section) |s| if (s.owned) gpa.free(s.data);

    var separate_debug_filename: ?[]const u8 = null;
    var separate_debug_crc: ?u32 = null;

    for (shdrs) |*shdr| {
        if (shdr.sh_type == elf.SHT_NULL or shdr.sh_type == elf.SHT_NOBITS) continue;
        const name = mem.sliceTo(header_strings[shdr.sh_name..], 0);

        if (mem.eql(u8, name, ".gnu_debuglink")) {
            if (mapped_mem.len < shdr.sh_offset + shdr.sh_size) return error.InvalidDebugInfo;
            const gnu_debuglink = mapped_mem[@intCast(shdr.sh_offset)..][0..@intCast(shdr.sh_size)];
            const debug_filename = mem.sliceTo(@as([*:0]const u8, @ptrCast(gnu_debuglink.ptr)), 0);
            const crc_offset = mem.alignForward(usize, debug_filename.len + 1, 4);
            const crc_bytes = gnu_debuglink[crc_offset..][0..4];
            separate_debug_crc = mem.readInt(u32, crc_bytes, endian);
            separate_debug_filename = debug_filename;
            continue;
        }

        var section_index: ?usize = null;
        inline for (@typeInfo(Dwarf.Section.Id).@"enum".fields, 0..) |sect, i| {
            if (mem.eql(u8, "." ++ sect.name, name)) section_index = i;
        }
        if (section_index == null) continue;
        if (sections[section_index.?] != null) continue;

        if (mapped_mem.len < shdr.sh_offset + shdr.sh_size) return error.InvalidDebugInfo;
        const section_bytes = mapped_mem[@intCast(shdr.sh_offset)..][0..@intCast(shdr.sh_size)];
        sections[section_index.?] = if ((shdr.sh_flags & elf.SHF_COMPRESSED) > 0) blk: {
            var section_reader: Reader = .fixed(section_bytes);
            const chdr = section_reader.takeStruct(elf.Chdr, endian) catch continue;
            if (chdr.ch_type != .ZLIB) continue;

            var decompress: std.compress.flate.Decompress = .init(&section_reader, .zlib, &.{});
            var decompressed_section: ArrayList(u8) = .empty;
            defer decompressed_section.deinit(gpa);
            decompress.reader.appendRemainingUnlimited(gpa, &decompressed_section) catch {
                Dwarf.invalidDebugInfoDetected();
                continue;
            };
            if (chdr.ch_size != decompressed_section.items.len) {
                Dwarf.invalidDebugInfoDetected();
                continue;
            }
            break :blk .{
                .data = try decompressed_section.toOwnedSlice(gpa),
                .virtual_address = shdr.sh_addr,
                .owned = true,
            };
        } else .{
            .data = section_bytes,
            .virtual_address = shdr.sh_addr,
            .owned = false,
        };
    }

    const missing_debug_info =
        sections[@intFromEnum(Dwarf.Section.Id.debug_info)] == null or
        sections[@intFromEnum(Dwarf.Section.Id.debug_abbrev)] == null or
        sections[@intFromEnum(Dwarf.Section.Id.debug_str)] == null or
        sections[@intFromEnum(Dwarf.Section.Id.debug_line)] == null;

    // Attempt to load debug info from an external file
    // See: https://sourceware.org/gdb/onlinedocs/gdb/Separate-Debug-Files.html
    if (missing_debug_info) {
        // Only allow one level of debug info nesting
        if (parent_mapped_mem) |_| {
            return error.MissingDebugInfo;
        }

        // $XDG_CACHE_HOME/debuginfod_client/<buildid>/debuginfo
        // This only opportunisticly tries to load from the debuginfod cache, but doesn't try to populate it.
        // One can manually run `debuginfod-find debuginfo PATH` to download the symbols
        debuginfod: {
            const id = build_id orelse break :debuginfod;
            switch (builtin.os.tag) {
                .wasi, .windows => break :debuginfod,
                else => {},
            }
            const id_dir_path: []u8 = p: {
                if (std.posix.getenv("DEBUGINFOD_CACHE_PATH")) |path| {
                    break :p try std.fmt.allocPrint(gpa, "{s}/{x}", .{ path, id });
                }
                if (std.posix.getenv("XDG_CACHE_HOME")) |cache_path| {
                    if (cache_path.len > 0) {
                        break :p try std.fmt.allocPrint(gpa, "{s}/debuginfod_client/{x}", .{ cache_path, id });
                    }
                }
                if (std.posix.getenv("HOME")) |home_path| {
                    break :p try std.fmt.allocPrint(gpa, "{s}/.cache/debuginfod_client/{x}", .{ home_path, id });
                }
                break :debuginfod;
            };
            defer gpa.free(id_dir_path);
            if (!std.fs.path.isAbsolute(id_dir_path)) break :debuginfod;

            var id_dir = std.fs.openDirAbsolute(id_dir_path, .{}) catch break :debuginfod;
            defer id_dir.close();

            return load(gpa, .{
                .root_dir = .{ .path = id_dir_path, .handle = id_dir },
                .sub_path = "debuginfo",
            }, null, separate_debug_crc, &sections, mapped_mem) catch break :debuginfod;
        }

        const global_debug_directories = [_][]const u8{
            "/usr/lib/debug",
        };

        // <global debug directory>/.build-id/<2-character id prefix>/<id remainder>.debug
        if (build_id) |id| blk: {
            if (id.len < 3) break :blk;

            // Either md5 (16 bytes) or sha1 (20 bytes) are used here in practice
            const extension = ".debug";
            var id_prefix_buf: [2]u8 = undefined;
            var filename_buf: [38 + extension.len]u8 = undefined;

            _ = std.fmt.bufPrint(&id_prefix_buf, "{x}", .{id[0..1]}) catch unreachable;
            const filename = std.fmt.bufPrint(&filename_buf, "{x}" ++ extension, .{id[1..]}) catch break :blk;

            for (global_debug_directories) |global_directory| {
                const path: Path = .{
                    .root_dir = .cwd(),
                    .sub_path = try std.fs.path.join(gpa, &.{
                        global_directory, ".build-id", &id_prefix_buf, filename,
                    }),
                };
                defer gpa.free(path.sub_path);

                return load(gpa, path, null, separate_debug_crc, &sections, mapped_mem) catch continue;
            }
        }

        // use the path from .gnu_debuglink, in the same search order as gdb
        separate: {
            const separate_filename = separate_debug_filename orelse break :separate;
            if (mem.eql(u8, std.fs.path.basename(elf_file_path.sub_path), separate_filename))
                return error.MissingDebugInfo;

            exe_dir: {
                const exe_dir_path = try std.fs.path.resolve(gpa, &.{
                    elf_file_path.root_dir.path orelse ".",
                    std.fs.path.dirname(elf_file_path.sub_path) orelse ".",
                });
                defer gpa.free(exe_dir_path);
                var exe_dir = std.fs.openDirAbsolute(exe_dir_path, .{}) catch break :exe_dir;
                defer exe_dir.close();

                // <exe_dir>/<gnu_debuglink>
                if (load(
                    gpa,
                    .{
                        .root_dir = .{ .path = exe_dir_path, .handle = exe_dir },
                        .sub_path = separate_filename,
                    },
                    null,
                    separate_debug_crc,
                    &sections,
                    mapped_mem,
                )) |em| {
                    return em;
                } else |_| {}

                // <exe_dir>/.debug/<gnu_debuglink>
                const path: Path = .{
                    .root_dir = .{ .path = exe_dir_path, .handle = exe_dir },
                    .sub_path = try std.fs.path.join(gpa, &.{ ".debug", separate_filename }),
                };
                defer gpa.free(path.sub_path);

                if (load(gpa, path, null, separate_debug_crc, &sections, mapped_mem)) |em| {
                    return em;
                } else |_| {}
            }

            var cwd_buf: [std.fs.max_path_bytes]u8 = undefined;
            const cwd_path = std.posix.realpath(".", &cwd_buf) catch break :separate;

            // <global debug directory>/<absolute folder of current binary>/<gnu_debuglink>
            for (global_debug_directories) |global_directory| {
                const path: Path = .{
                    .root_dir = .cwd(),
                    .sub_path = try std.fs.path.join(gpa, &.{ global_directory, cwd_path, separate_filename }),
                };
                defer gpa.free(path.sub_path);
                if (load(gpa, path, null, separate_debug_crc, &sections, mapped_mem)) |em| {
                    return em;
                } else |_| {}
            }
        }

        return error.MissingDebugInfo;
    }

    var dwarf: Dwarf = .{ .sections = sections };
    try dwarf.open(gpa, endian);
    return .{
        .mapped_file = parent_mapped_mem orelse mapped_mem,
        .mapped_debug_file = if (parent_mapped_mem != null) mapped_mem else null,
        .dwarf = dwarf,
    };
}

const std = @import("../../std.zig");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const Dwarf = std.debug.Dwarf;
const Path = std.Build.Cache.Path;
const Reader = std.Io.Reader;
const mem = std.mem;
const elf = std.elf;

const builtin = @import("builtin");
const native_endian = builtin.cpu.arch.endian();

const ElfModule = @This();
