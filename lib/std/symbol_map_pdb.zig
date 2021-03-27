const std = @import("std.zig");
const builtin = std.builtin;
const assert = std.debug.assert;
const SymbolInfo = std.debug.SymbolMap.SymbolInfo;
const LineInfo = std.debug.SymbolMap.LineInfo;
const debug_info = std.debug_info;
const BaseError = debug_info.BaseError;
const mem = std.mem;
const math = std.math;
const fs = std.fs;
const File = std.fs.File;
const pdb = std.pdb;
const coff = std.coff;
const windows = std.os.windows;
const ArrayList = std.ArrayList;

const SymbolMapState = debug_info.SymbolMapStateFromModuleInfo(Module);
pub const init = SymbolMapState.init;

const Module = struct {
    const Self = @This();

    base_address: usize,
    pdb: pdb.Pdb,
    coff: *coff.Coff,
    sect_contribs: []pdb.SectionContribEntry,
    modules: []PDBModule,

    const PDBModule = struct {
        mod_info: pdb.ModInfo,
        module_name: []u8,
        obj_file_name: []u8,

        populated: bool,
        symbols: []u8,
        subsect_info: []u8,
        checksum_offset: ?usize,
    };

    pub fn lookup(allocator: *mem.Allocator, address_map: *SymbolMapState.AddressMap, address: usize) !*Self {
        if (builtin.os.tag != .windows) {
            // TODO: implement uefi case
            return BaseError.UnsupportedOperatingSystem;
        }

        return lookupModuleWin32(allocator, address_map, address);
    }

    fn lookupModuleWin32(allocator: *mem.Allocator, address_map: *SymbolMapState.AddressMap, address: usize) !*Self {
        const process_handle = windows.kernel32.GetCurrentProcess();

        // Find how many modules are actually loaded
        var dummy: windows.HMODULE = undefined;
        var bytes_needed: windows.DWORD = undefined;
        if (windows.kernel32.K32EnumProcessModules(
            process_handle,
            @ptrCast([*]windows.HMODULE, &dummy),
            0,
            &bytes_needed,
        ) == 0)
            return BaseError.MissingDebugInfo;

        const needed_modules = bytes_needed / @sizeOf(windows.HMODULE);

        // Fetch the complete module list
        var modules = try allocator.alloc(windows.HMODULE, needed_modules);
        defer allocator.free(modules);
        if (windows.kernel32.K32EnumProcessModules(
            process_handle,
            modules.ptr,
            try math.cast(windows.DWORD, modules.len * @sizeOf(windows.HMODULE)),
            &bytes_needed,
        ) == 0)
            return BaseError.MissingDebugInfo;

        // There's an unavoidable TOCTOU problem here, the module list may have
        // changed between the two EnumProcessModules call.
        // Pick the smallest amount of elements to avoid processing garbage.
        const needed_modules_after = bytes_needed / @sizeOf(windows.HMODULE);
        const loaded_modules = math.min(needed_modules, needed_modules_after);

        for (modules[0..loaded_modules]) |module| {
            var info: windows.MODULEINFO = undefined;
            if (windows.kernel32.K32GetModuleInformation(
                process_handle,
                module,
                &info,
                @sizeOf(@TypeOf(info)),
            ) == 0)
                return BaseError.MissingDebugInfo;

            const seg_start = @ptrToInt(info.lpBaseOfDll);
            const seg_end = seg_start + info.SizeOfImage;

            if (address >= seg_start and address < seg_end) {
                if (address_map.get(seg_start)) |obj_di| {
                    return obj_di;
                }

                var name_buffer: [windows.PATH_MAX_WIDE + 4:0]u16 = undefined;
                // openFileAbsoluteW requires the prefix to be present
                mem.copy(u16, name_buffer[0..4], &[_]u16{ '\\', '?', '?', '\\' });
                const len = windows.kernel32.K32GetModuleFileNameExW(
                    process_handle,
                    module,
                    @ptrCast(windows.LPWSTR, &name_buffer[4]),
                    windows.PATH_MAX_WIDE,
                );
                assert(len > 0);

                const obj_di = try allocator.create(Self);
                errdefer allocator.destroy(obj_di);

                const coff_file = fs.openFileAbsoluteW(name_buffer[0 .. len + 4 :0], .{}) catch |err| switch (err) {
                    error.FileNotFound => return BaseError.MissingDebugInfo,
                    else => return err,
                };
                obj_di.* = try readCoffDebugInfo(allocator, coff_file);
                obj_di.base_address = seg_start;

                try address_map.putNoClobber(seg_start, obj_di);

                return obj_di;
            }
        }

        return BaseError.MissingDebugInfo;
    }

    /// This takes ownership of coff_file: users of this function should not close
    /// it themselves, even on error.
    /// TODO resources https://github.com/ziglang/zig/issues/4353
    /// TODO it's weird to take ownership even on error, rework this code.
    fn readCoffDebugInfo(allocator: *mem.Allocator, coff_file: File) !Self {
        nosuspend {
            errdefer coff_file.close();

            const coff_obj = try allocator.create(coff.Coff);
            coff_obj.* = coff.Coff.init(allocator, coff_file);

            var di = Self{
                .base_address = undefined,
                .coff = coff_obj,
                .pdb = undefined,
                .sect_contribs = undefined,
                .modules = undefined,
            };

            try di.coff.loadHeader();

            var path_buf: [windows.MAX_PATH]u8 = undefined;
            const len = try di.coff.getPdbPath(path_buf[0..]);
            const raw_path = path_buf[0..len];

            const path = try fs.path.resolve(allocator, &[_][]const u8{raw_path});

            try di.pdb.openFile(di.coff, path);

            var pdb_stream = di.pdb.getStream(pdb.StreamType.Pdb) orelse return BaseError.InvalidDebugInfo;
            const version = try pdb_stream.reader().readIntLittle(u32);
            const signature = try pdb_stream.reader().readIntLittle(u32);
            const age = try pdb_stream.reader().readIntLittle(u32);
            var guid: [16]u8 = undefined;
            try pdb_stream.reader().readNoEof(&guid);
            if (version != 20000404) // VC70, only value observed by LLVM team
                return error.UnknownPDBVersion;
            if (!mem.eql(u8, &di.coff.guid, &guid) or di.coff.age != age)
                return error.PDBMismatch;
            // We validated the executable and pdb match.

            const string_table_index = str_tab_index: {
                const name_bytes_len = try pdb_stream.reader().readIntLittle(u32);
                const name_bytes = try allocator.alloc(u8, name_bytes_len);
                try pdb_stream.reader().readNoEof(name_bytes);

                const HashTableHeader = packed struct {
                    Size: u32,
                    Capacity: u32,

                    fn maxLoad(cap: u32) u32 {
                        return cap * 2 / 3 + 1;
                    }
                };
                const hash_tbl_hdr = try pdb_stream.reader().readStruct(HashTableHeader);
                if (hash_tbl_hdr.Capacity == 0)
                    return BaseError.InvalidDebugInfo;

                if (hash_tbl_hdr.Size > HashTableHeader.maxLoad(hash_tbl_hdr.Capacity))
                    return BaseError.InvalidDebugInfo;

                const present = try readSparseBitVector(&pdb_stream.reader(), allocator);
                if (present.len != hash_tbl_hdr.Size)
                    return BaseError.InvalidDebugInfo;
                const deleted = try readSparseBitVector(&pdb_stream.reader(), allocator);

                const Bucket = struct {
                    first: u32,
                    second: u32,
                };
                const bucket_list = try allocator.alloc(Bucket, present.len);
                for (present) |_| {
                    const name_offset = try pdb_stream.reader().readIntLittle(u32);
                    const name_index = try pdb_stream.reader().readIntLittle(u32);
                    const name = mem.spanZ(std.meta.assumeSentinel(name_bytes.ptr + name_offset, 0));
                    if (mem.eql(u8, name, "/names")) {
                        break :str_tab_index name_index;
                    }
                }
                return BaseError.MissingDebugInfo;
            };

            di.pdb.string_table = di.pdb.getStreamById(string_table_index) orelse return BaseError.MissingDebugInfo;
            di.pdb.dbi = di.pdb.getStream(pdb.StreamType.Dbi) orelse return BaseError.MissingDebugInfo;

            const dbi = di.pdb.dbi;

            // Dbi Header
            const dbi_stream_header = try dbi.reader().readStruct(pdb.DbiStreamHeader);
            if (dbi_stream_header.VersionHeader != 19990903) // V70, only value observed by LLVM team
                return error.UnknownPDBVersion;
            if (dbi_stream_header.Age != age)
                return error.UnmatchingPDB;

            const mod_info_size = dbi_stream_header.ModInfoSize;
            const section_contrib_size = dbi_stream_header.SectionContributionSize;

            var modules = ArrayList(PDBModule).init(allocator);

            // Module Info Substream
            var mod_info_offset: usize = 0;
            while (mod_info_offset != mod_info_size) {
                const mod_info = try dbi.reader().readStruct(pdb.ModInfo);
                var this_record_len: usize = @sizeOf(pdb.ModInfo);

                const module_name = try dbi.readNullTermString(allocator);
                this_record_len += module_name.len + 1;

                const obj_file_name = try dbi.readNullTermString(allocator);
                this_record_len += obj_file_name.len + 1;

                if (this_record_len % 4 != 0) {
                    const round_to_next_4 = (this_record_len | 0x3) + 1;
                    const march_forward_bytes = round_to_next_4 - this_record_len;
                    try dbi.seekBy(@intCast(isize, march_forward_bytes));
                    this_record_len += march_forward_bytes;
                }

                try modules.append(.{
                    .mod_info = mod_info,
                    .module_name = module_name,
                    .obj_file_name = obj_file_name,

                    .populated = false,
                    .symbols = undefined,
                    .subsect_info = undefined,
                    .checksum_offset = null,
                });

                mod_info_offset += this_record_len;
                if (mod_info_offset > mod_info_size)
                    return BaseError.InvalidDebugInfo;
            }

            di.modules = modules.toOwnedSlice();

            // Section Contribution Substream
            var sect_contribs = ArrayList(pdb.SectionContribEntry).init(allocator);
            var sect_cont_offset: usize = 0;
            if (section_contrib_size != 0) {
                const ver = @intToEnum(pdb.SectionContrSubstreamVersion, try dbi.reader().readIntLittle(u32));
                if (ver != pdb.SectionContrSubstreamVersion.Ver60)
                    return BaseError.InvalidDebugInfo;
                sect_cont_offset += @sizeOf(u32);
            }
            while (sect_cont_offset != section_contrib_size) {
                const entry = try sect_contribs.addOne();
                entry.* = try dbi.reader().readStruct(pdb.SectionContribEntry);
                sect_cont_offset += @sizeOf(pdb.SectionContribEntry);

                if (sect_cont_offset > section_contrib_size)
                    return BaseError.InvalidDebugInfo;
            }

            di.sect_contribs = sect_contribs.toOwnedSlice();

            return di;
        }
    }

    fn readSparseBitVector(reader: anytype, allocator: *mem.Allocator) ![]usize {
        const num_words = try reader.readIntLittle(u32);
        var word_i: usize = 0;
        var list = ArrayList(usize).init(allocator);
        while (word_i != num_words) : (word_i += 1) {
            const word = try reader.readIntLittle(u32);
            var bit_i: u5 = 0;
            while (true) : (bit_i += 1) {
                if (word & (@as(u32, 1) << bit_i) != 0) {
                    try list.append(word_i * 32 + bit_i);
                }
                if (bit_i == math.maxInt(u5)) break;
            }
        }
        return list.toOwnedSlice();
    }

    pub fn addressToSymbol(self: *Self, address: usize) !SymbolInfo {
        // Translate the VA into an address into this object
        const relocated_address = address - self.base_address;

        var coff_section: *coff.Section = undefined;
        const mod_index = for (self.sect_contribs) |sect_contrib| {
            if (sect_contrib.Section > self.coff.sections.items.len) continue;
            // Remember that SectionContribEntry.Section is 1-based.
            coff_section = &self.coff.sections.items[sect_contrib.Section - 1];

            const vaddr_start = coff_section.header.virtual_address + sect_contrib.Offset;
            const vaddr_end = vaddr_start + sect_contrib.Size;
            if (relocated_address >= vaddr_start and relocated_address < vaddr_end) {
                break sect_contrib.ModuleIndex;
            }
        } else {
            // we have no information to add to the address
            return SymbolInfo{};
        };

        const allocator = self.coff.allocator;

        const mod = &self.modules[mod_index];
        try populateModule(self, allocator, mod);
        const obj_basename = fs.path.basename(mod.obj_file_name);

        var symbol_i: usize = 0;
        const symbol_name = if (!mod.populated) "???" else while (symbol_i != mod.symbols.len) {
            const prefix = @ptrCast(*pdb.RecordPrefix, &mod.symbols[symbol_i]);
            if (prefix.RecordLen < 2)
                return BaseError.InvalidDebugInfo;
            switch (prefix.RecordKind) {
                .S_LPROC32, .S_GPROC32 => {
                    const proc_sym = @ptrCast(*pdb.ProcSym, &mod.symbols[symbol_i + @sizeOf(pdb.RecordPrefix)]);
                    const vaddr_start = coff_section.header.virtual_address + proc_sym.CodeOffset;
                    const vaddr_end = vaddr_start + proc_sym.CodeSize;
                    if (relocated_address >= vaddr_start and relocated_address < vaddr_end) {
                        break mem.spanZ(@ptrCast([*:0]u8, proc_sym) + @sizeOf(pdb.ProcSym));
                    }
                },
                else => {},
            }
            symbol_i += prefix.RecordLen + @sizeOf(u16);
            if (symbol_i > mod.symbols.len)
                return BaseError.InvalidDebugInfo;
        } else "???";

        const subsect_info = mod.subsect_info;

        var sect_offset: usize = 0;
        var skip_len: usize = undefined;
        const opt_line_info = subsections: {
            const checksum_offset = mod.checksum_offset orelse break :subsections null;
            while (sect_offset != subsect_info.len) : (sect_offset += skip_len) {
                const subsect_hdr = @ptrCast(*pdb.DebugSubsectionHeader, &subsect_info[sect_offset]);
                skip_len = subsect_hdr.Length;
                sect_offset += @sizeOf(pdb.DebugSubsectionHeader);

                switch (subsect_hdr.Kind) {
                    .Lines => {
                        var line_index = sect_offset;

                        const line_hdr = @ptrCast(*pdb.LineFragmentHeader, &subsect_info[line_index]);
                        if (line_hdr.RelocSegment == 0)
                            return BaseError.MissingDebugInfo;
                        line_index += @sizeOf(pdb.LineFragmentHeader);
                        const frag_vaddr_start = coff_section.header.virtual_address + line_hdr.RelocOffset;
                        const frag_vaddr_end = frag_vaddr_start + line_hdr.CodeSize;

                        if (relocated_address >= frag_vaddr_start and relocated_address < frag_vaddr_end) {
                            // There is an unknown number of LineBlockFragmentHeaders (and their accompanying line and column records)
                            // from now on. We will iterate through them, and eventually find a LineInfo that we're interested in,
                            // breaking out to :subsections. If not, we will make sure to not read anything outside of this subsection.
                            const subsection_end_index = sect_offset + subsect_hdr.Length;

                            while (line_index < subsection_end_index) {
                                const block_hdr = @ptrCast(*pdb.LineBlockFragmentHeader, &subsect_info[line_index]);
                                line_index += @sizeOf(pdb.LineBlockFragmentHeader);
                                const start_line_index = line_index;

                                const has_column = line_hdr.Flags.LF_HaveColumns;

                                // All line entries are stored inside their line block by ascending start address.
                                // Heuristic: we want to find the last line entry
                                // that has a vaddr_start <= relocated_address.
                                // This is done with a simple linear search.
                                var line_i: u32 = 0;
                                while (line_i < block_hdr.NumLines) : (line_i += 1) {
                                    const line_num_entry = @ptrCast(*pdb.LineNumberEntry, &subsect_info[line_index]);
                                    line_index += @sizeOf(pdb.LineNumberEntry);

                                    const vaddr_start = frag_vaddr_start + line_num_entry.Offset;
                                    if (relocated_address < vaddr_start) {
                                        break;
                                    }
                                }

                                // line_i == 0 would mean that no matching LineNumberEntry was found.
                                if (line_i > 0) {
                                    const subsect_index = checksum_offset + block_hdr.NameIndex;
                                    const chksum_hdr = @ptrCast(*pdb.FileChecksumEntryHeader, &mod.subsect_info[subsect_index]);
                                    const strtab_offset = @sizeOf(pdb.PDBStringTableHeader) + chksum_hdr.FileNameOffset;
                                    try self.pdb.string_table.seekTo(strtab_offset);
                                    const source_file_name = try self.pdb.string_table.readNullTermString(allocator);

                                    const line_entry_idx = line_i - 1;

                                    const column = if (has_column) blk: {
                                        const start_col_index = start_line_index + @sizeOf(pdb.LineNumberEntry) * block_hdr.NumLines;
                                        const col_index = start_col_index + @sizeOf(pdb.ColumnNumberEntry) * line_entry_idx;
                                        const col_num_entry = @ptrCast(*pdb.ColumnNumberEntry, &subsect_info[col_index]);
                                        break :blk col_num_entry.StartColumn;
                                    } else 0;

                                    const found_line_index = start_line_index + line_entry_idx * @sizeOf(pdb.LineNumberEntry);
                                    const line_num_entry = @ptrCast(*pdb.LineNumberEntry, &subsect_info[found_line_index]);
                                    const flags = @ptrCast(*pdb.LineNumberEntry.Flags, &line_num_entry.Flags);

                                    break :subsections LineInfo{
                                        .allocator = allocator,
                                        .file_name = source_file_name,
                                        .line = flags.Start,
                                        .column = column,
                                    };
                                }
                            }

                            // Checking that we are not reading garbage after the (possibly) multiple block fragments.
                            if (line_index != subsection_end_index) {
                                return BaseError.InvalidDebugInfo;
                            }
                        }
                    },
                    else => {},
                }

                if (sect_offset > subsect_info.len)
                    return BaseError.InvalidDebugInfo;
            } else {
                break :subsections null;
            }
        };

        return SymbolInfo{
            .symbol_name = symbol_name,
            .compile_unit_name = obj_basename,
            .line_info = opt_line_info,
        };
    }

    /// TODO resources https://github.com/ziglang/zig/issues/4353
    fn populateModule(di: *Self, allocator: *mem.Allocator, mod: *PDBModule) !void {
        if (mod.populated)
            return;
        // At most one can be non-zero.
        if (mod.mod_info.C11ByteSize != 0 and mod.mod_info.C13ByteSize != 0)
            return BaseError.InvalidDebugInfo;

        if (mod.mod_info.C13ByteSize == 0)
            return;

        const modi = di.pdb.getStreamById(mod.mod_info.ModuleSymStream) orelse return BaseError.MissingDebugInfo;

        const signature = try modi.reader().readIntLittle(u32);
        if (signature != 4)
            return BaseError.InvalidDebugInfo;

        mod.symbols = try allocator.alloc(u8, mod.mod_info.SymByteSize - 4);
        try modi.reader().readNoEof(mod.symbols);

        mod.subsect_info = try allocator.alloc(u8, mod.mod_info.C13ByteSize);
        try modi.reader().readNoEof(mod.subsect_info);

        var sect_offset: usize = 0;
        var skip_len: usize = undefined;
        while (sect_offset != mod.subsect_info.len) : (sect_offset += skip_len) {
            const subsect_hdr = @ptrCast(*pdb.DebugSubsectionHeader, &mod.subsect_info[sect_offset]);
            skip_len = subsect_hdr.Length;
            sect_offset += @sizeOf(pdb.DebugSubsectionHeader);

            switch (subsect_hdr.Kind) {
                .FileChecksums => {
                    mod.checksum_offset = sect_offset;
                    break;
                },
                else => {},
            }

            if (sect_offset > mod.subsect_info.len)
                return BaseError.InvalidDebugInfo;
        }

        mod.populated = true;
    }
};
