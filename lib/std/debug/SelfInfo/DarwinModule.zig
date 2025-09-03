/// The runtime address where __TEXT is loaded.
text_base: usize,
load_offset: usize,
name: []const u8,

pub fn key(m: *const DarwinModule) usize {
    return m.text_base;
}

/// No cache needed, because `_dyld_get_image_header` etc are already fast.
pub const LookupCache = void;
pub fn lookup(cache: *LookupCache, gpa: Allocator, address: usize) Error!DarwinModule {
    _ = cache;
    _ = gpa;
    const image_count = std.c._dyld_image_count();
    for (0..image_count) |image_idx| {
        const header = std.c._dyld_get_image_header(@intCast(image_idx)) orelse continue;
        const text_base = @intFromPtr(header);
        if (address < text_base) continue;
        const load_offset = std.c._dyld_get_image_vmaddr_slide(@intCast(image_idx));

        // Find the __TEXT segment
        var it: macho.LoadCommandIterator = .{
            .ncmds = header.ncmds,
            .buffer = @as([*]u8, @ptrCast(header))[@sizeOf(macho.mach_header_64)..][0..header.sizeofcmds],
        };
        const text_segment_cmd = while (it.next()) |load_cmd| {
            if (load_cmd.cmd() != .SEGMENT_64) continue;
            const segment_cmd = load_cmd.cast(macho.segment_command_64).?;
            if (!mem.eql(u8, segment_cmd.segName(), "__TEXT")) continue;
            break segment_cmd;
        } else continue;

        const seg_start = load_offset + text_segment_cmd.vmaddr;
        assert(seg_start == text_base);
        const seg_end = seg_start + text_segment_cmd.vmsize;
        if (address < seg_start or address >= seg_end) continue;

        // We've found the matching __TEXT segment. This is the image we need.
        return .{
            .text_base = text_base,
            .load_offset = load_offset,
            .name = mem.span(std.c._dyld_get_image_name(@intCast(image_idx))),
        };
    }
    return error.MissingDebugInfo;
}
fn loadUnwindInfo(module: *const DarwinModule) DebugInfo.Unwind {
    const header: *std.macho.mach_header = @ptrFromInt(module.text_base);

    var it: macho.LoadCommandIterator = .{
        .ncmds = header.ncmds,
        .buffer = @as([*]u8, @ptrCast(header))[@sizeOf(macho.mach_header_64)..][0..header.sizeofcmds],
    };
    const sections = while (it.next()) |load_cmd| {
        if (load_cmd.cmd() != .SEGMENT_64) continue;
        const segment_cmd = load_cmd.cast(macho.segment_command_64).?;
        if (!mem.eql(u8, segment_cmd.segName(), "__TEXT")) continue;
        break load_cmd.getSections();
    } else unreachable;

    var unwind_info: ?[]const u8 = null;
    var eh_frame: ?[]const u8 = null;
    for (sections) |sect| {
        if (mem.eql(u8, sect.sectName(), "__unwind_info")) {
            const sect_ptr: [*]u8 = @ptrFromInt(@as(usize, @intCast(module.load_offset + sect.addr)));
            unwind_info = sect_ptr[0..@intCast(sect.size)];
        } else if (mem.eql(u8, sect.sectName(), "__eh_frame")) {
            const sect_ptr: [*]u8 = @ptrFromInt(@as(usize, @intCast(module.load_offset + sect.addr)));
            eh_frame = sect_ptr[0..@intCast(sect.size)];
        }
    }
    return .{
        .unwind_info = unwind_info,
        .eh_frame = eh_frame,
    };
}
fn loadFullInfo(module: *const DarwinModule, gpa: Allocator) !DebugInfo.Full {
    const mapped_mem = try mapDebugInfoFile(module.name);
    errdefer posix.munmap(mapped_mem);

    const hdr: *const macho.mach_header_64 = @ptrCast(@alignCast(mapped_mem.ptr));
    if (hdr.magic != macho.MH_MAGIC_64)
        return error.InvalidDebugInfo;

    const symtab: macho.symtab_command = symtab: {
        var it: macho.LoadCommandIterator = .{
            .ncmds = hdr.ncmds,
            .buffer = mapped_mem[@sizeOf(macho.mach_header_64)..][0..hdr.sizeofcmds],
        };
        while (it.next()) |cmd| switch (cmd.cmd()) {
            .SYMTAB => break :symtab cmd.cast(macho.symtab_command) orelse return error.InvalidDebugInfo,
            else => {},
        };
        return error.MissingDebugInfo;
    };

    const syms_ptr: [*]align(1) const macho.nlist_64 = @ptrCast(mapped_mem[symtab.symoff..]);
    const syms = syms_ptr[0..symtab.nsyms];
    const strings = mapped_mem[symtab.stroff..][0 .. symtab.strsize - 1 :0];

    var symbols: std.ArrayList(MachoSymbol) = try .initCapacity(gpa, syms.len);
    defer symbols.deinit(gpa);

    var ofile: u32 = undefined;
    var last_sym: MachoSymbol = undefined;
    var state: enum {
        init,
        oso_open,
        oso_close,
        bnsym,
        fun_strx,
        fun_size,
        ensym,
    } = .init;

    for (syms) |*sym| {
        if (sym.n_type.bits.is_stab == 0) continue;

        // TODO handle globals N_GSYM, and statics N_STSYM
        switch (sym.n_type.stab) {
            .oso => switch (state) {
                .init, .oso_close => {
                    state = .oso_open;
                    ofile = sym.n_strx;
                },
                else => return error.InvalidDebugInfo,
            },
            .bnsym => switch (state) {
                .oso_open, .ensym => {
                    state = .bnsym;
                    last_sym = .{
                        .strx = 0,
                        .addr = sym.n_value,
                        .size = 0,
                        .ofile = ofile,
                    };
                },
                else => return error.InvalidDebugInfo,
            },
            .fun => switch (state) {
                .bnsym => {
                    state = .fun_strx;
                    last_sym.strx = sym.n_strx;
                },
                .fun_strx => {
                    state = .fun_size;
                    last_sym.size = @intCast(sym.n_value);
                },
                else => return error.InvalidDebugInfo,
            },
            .ensym => switch (state) {
                .fun_size => {
                    state = .ensym;
                    symbols.appendAssumeCapacity(last_sym);
                },
                else => return error.InvalidDebugInfo,
            },
            .so => switch (state) {
                .init, .oso_close => {},
                .oso_open, .ensym => {
                    state = .oso_close;
                },
                else => return error.InvalidDebugInfo,
            },
            else => {},
        }
    }

    switch (state) {
        .init => return error.MissingDebugInfo,
        .oso_close => {},
        else => return error.InvalidDebugInfo,
    }

    const symbols_slice = try symbols.toOwnedSlice(gpa);
    errdefer gpa.free(symbols_slice);

    // Even though lld emits symbols in ascending order, this debug code
    // should work for programs linked in any valid way.
    // This sort is so that we can binary search later.
    mem.sort(MachoSymbol, symbols_slice, {}, MachoSymbol.addressLessThan);

    return .{
        .mapped_memory = mapped_mem,
        .symbols = symbols_slice,
        .strings = strings,
        .ofiles = .empty,
    };
}
pub fn getSymbolAtAddress(module: *const DarwinModule, gpa: Allocator, di: *DebugInfo, address: usize) Error!std.debug.Symbol {
    if (di.full == null) di.full = module.loadFullInfo(gpa) catch |err| switch (err) {
        error.InvalidDebugInfo, error.MissingDebugInfo, error.OutOfMemory, error.Unexpected => |e| return e,
        else => return error.ReadFailed,
    };
    const full = &di.full.?;

    const vaddr = address - module.load_offset;
    const symbol = MachoSymbol.find(full.symbols, vaddr) orelse return .{
        .name = null,
        .compile_unit_name = null,
        .source_location = null,
    };

    // offset of `address` from start of `symbol`
    const address_symbol_offset = vaddr - symbol.addr;

    // Take the symbol name from the N_FUN STAB entry, we're going to
    // use it if we fail to find the DWARF infos
    const stab_symbol = mem.sliceTo(full.strings[symbol.strx..], 0);

    // If any information is missing, we can at least return this from now on.
    const sym_only_result: std.debug.Symbol = .{
        .name = stab_symbol,
        .compile_unit_name = null,
        .source_location = null,
    };

    const o_file: *DebugInfo.OFile = of: {
        const gop = try full.ofiles.getOrPut(gpa, symbol.ofile);
        if (!gop.found_existing) {
            const o_file_path = mem.sliceTo(full.strings[symbol.ofile..], 0);
            gop.value_ptr.* = DebugInfo.loadOFile(gpa, o_file_path) catch {
                _ = full.ofiles.pop().?;
                return sym_only_result;
            };
        }
        break :of gop.value_ptr;
    };

    const symbol_index = o_file.symbols_by_name.getKeyAdapted(
        @as([]const u8, stab_symbol),
        @as(DebugInfo.OFile.SymbolAdapter, .{ .strtab = o_file.strtab, .symtab = o_file.symtab }),
    ) orelse return sym_only_result;
    const symbol_ofile_vaddr = o_file.symtab[symbol_index].n_value;

    const compile_unit = o_file.dwarf.findCompileUnit(native_endian, symbol_ofile_vaddr) catch return sym_only_result;

    return .{
        .name = o_file.dwarf.getSymbolName(symbol_ofile_vaddr) orelse stab_symbol,
        .compile_unit_name = compile_unit.die.getAttrString(
            &o_file.dwarf,
            native_endian,
            std.dwarf.AT.name,
            o_file.dwarf.section(.debug_str),
            compile_unit,
        ) catch |err| switch (err) {
            error.MissingDebugInfo, error.InvalidDebugInfo => null,
        },
        .source_location = o_file.dwarf.getLineNumberInfo(
            gpa,
            native_endian,
            compile_unit,
            symbol_ofile_vaddr + address_symbol_offset,
        ) catch null,
    };
}
/// Unwind a frame using MachO compact unwind info (from __unwind_info).
/// If the compact encoding can't encode a way to unwind a frame, it will
/// defer unwinding to DWARF, in which case `.eh_frame` will be used if available.
pub fn unwindFrame(module: *const DarwinModule, gpa: Allocator, di: *DebugInfo, context: *UnwindContext) Error!usize {
    return unwindFrameInner(module, gpa, di, context) catch |err| switch (err) {
        error.InvalidDebugInfo,
        error.MissingDebugInfo,
        error.UnsupportedDebugInfo,
        error.ReadFailed,
        error.OutOfMemory,
        error.Unexpected,
        => |e| return e,
        error.UnimplementedArch,
        error.UnimplementedOs,
        error.ThreadContextNotSupported,
        => return error.UnsupportedDebugInfo,
        error.InvalidRegister,
        error.RegisterContextRequired,
        error.IncompatibleRegisterSize,
        => return error.InvalidDebugInfo,
    };
}
fn unwindFrameInner(module: *const DarwinModule, gpa: Allocator, di: *DebugInfo, context: *UnwindContext) !usize {
    _ = gpa;
    if (di.unwind == null) di.unwind = module.loadUnwindInfo();
    const unwind = &di.unwind.?;

    const unwind_info = unwind.unwind_info orelse return error.MissingDebugInfo;
    if (unwind_info.len < @sizeOf(macho.unwind_info_section_header)) return error.InvalidDebugInfo;
    const header: *align(1) const macho.unwind_info_section_header = @ptrCast(unwind_info);

    const index_byte_count = header.indexCount * @sizeOf(macho.unwind_info_section_header_index_entry);
    if (unwind_info.len < header.indexSectionOffset + index_byte_count) return error.InvalidDebugInfo;
    const indices: []align(1) const macho.unwind_info_section_header_index_entry = @ptrCast(unwind_info[header.indexSectionOffset..][0..index_byte_count]);
    if (indices.len == 0) return error.MissingDebugInfo;

    // offset of the PC into the `__TEXT` segment
    const pc_text_offset = context.pc - module.text_base;

    const start_offset: u32, const first_level_offset: u32 = index: {
        var left: usize = 0;
        var len: usize = indices.len;
        while (len > 1) {
            const mid = left + len / 2;
            if (pc_text_offset < indices[mid].functionOffset) {
                len /= 2;
            } else {
                left = mid;
                len -= len / 2;
            }
        }
        break :index .{ indices[left].secondLevelPagesSectionOffset, indices[left].functionOffset };
    };
    // An offset of 0 is a sentinel indicating a range does not have unwind info.
    if (start_offset == 0) return error.MissingDebugInfo;

    const common_encodings_byte_count = header.commonEncodingsArrayCount * @sizeOf(macho.compact_unwind_encoding_t);
    if (unwind_info.len < header.commonEncodingsArraySectionOffset + common_encodings_byte_count) return error.InvalidDebugInfo;
    const common_encodings: []align(1) const macho.compact_unwind_encoding_t = @ptrCast(
        unwind_info[header.commonEncodingsArraySectionOffset..][0..common_encodings_byte_count],
    );

    if (unwind_info.len < start_offset + @sizeOf(macho.UNWIND_SECOND_LEVEL)) return error.InvalidDebugInfo;
    const kind: *align(1) const macho.UNWIND_SECOND_LEVEL = @ptrCast(unwind_info[start_offset..]);

    const entry: struct {
        function_offset: usize,
        raw_encoding: u32,
    } = switch (kind.*) {
        .REGULAR => entry: {
            if (unwind_info.len < start_offset + @sizeOf(macho.unwind_info_regular_second_level_page_header)) return error.InvalidDebugInfo;
            const page_header: *align(1) const macho.unwind_info_regular_second_level_page_header = @ptrCast(unwind_info[start_offset..]);

            const entries_byte_count = page_header.entryCount * @sizeOf(macho.unwind_info_regular_second_level_entry);
            if (unwind_info.len < start_offset + entries_byte_count) return error.InvalidDebugInfo;
            const entries: []align(1) const macho.unwind_info_regular_second_level_entry = @ptrCast(
                unwind_info[start_offset + page_header.entryPageOffset ..][0..entries_byte_count],
            );
            if (entries.len == 0) return error.InvalidDebugInfo;

            var left: usize = 0;
            var len: usize = entries.len;
            while (len > 1) {
                const mid = left + len / 2;
                if (pc_text_offset < entries[mid].functionOffset) {
                    len /= 2;
                } else {
                    left = mid;
                    len -= len / 2;
                }
            }
            break :entry .{
                .function_offset = entries[left].functionOffset,
                .raw_encoding = entries[left].encoding,
            };
        },
        .COMPRESSED => entry: {
            if (unwind_info.len < start_offset + @sizeOf(macho.unwind_info_compressed_second_level_page_header)) return error.InvalidDebugInfo;
            const page_header: *align(1) const macho.unwind_info_compressed_second_level_page_header = @ptrCast(unwind_info[start_offset..]);

            const entries_byte_count = page_header.entryCount * @sizeOf(macho.UnwindInfoCompressedEntry);
            if (unwind_info.len < start_offset + entries_byte_count) return error.InvalidDebugInfo;
            const entries: []align(1) const macho.UnwindInfoCompressedEntry = @ptrCast(
                unwind_info[start_offset + page_header.entryPageOffset ..][0..entries_byte_count],
            );
            if (entries.len == 0) return error.InvalidDebugInfo;

            var left: usize = 0;
            var len: usize = entries.len;
            while (len > 1) {
                const mid = left + len / 2;
                if (pc_text_offset < first_level_offset + entries[mid].funcOffset) {
                    len /= 2;
                } else {
                    left = mid;
                    len -= len / 2;
                }
            }
            const entry = entries[left];

            const function_offset = first_level_offset + entry.funcOffset;
            if (entry.encodingIndex < common_encodings.len) {
                break :entry .{
                    .function_offset = function_offset,
                    .raw_encoding = common_encodings[entry.encodingIndex],
                };
            }

            const local_index = entry.encodingIndex - common_encodings.len;
            const local_encodings_byte_count = page_header.encodingsCount * @sizeOf(macho.compact_unwind_encoding_t);
            if (unwind_info.len < start_offset + page_header.encodingsPageOffset + local_encodings_byte_count) return error.InvalidDebugInfo;
            const local_encodings: []align(1) const macho.compact_unwind_encoding_t = @ptrCast(
                unwind_info[start_offset + page_header.encodingsPageOffset ..][0..local_encodings_byte_count],
            );
            if (local_index >= local_encodings.len) return error.InvalidDebugInfo;
            break :entry .{
                .function_offset = function_offset,
                .raw_encoding = local_encodings[local_index],
            };
        },
        else => return error.InvalidDebugInfo,
    };

    if (entry.raw_encoding == 0) return error.MissingDebugInfo;
    const reg_context: Dwarf.abi.RegisterContext = .{ .eh_frame = false, .is_macho = true };

    const encoding: macho.CompactUnwindEncoding = @bitCast(entry.raw_encoding);
    const new_ip = switch (builtin.cpu.arch) {
        .x86_64 => switch (encoding.mode.x86_64) {
            .OLD => return error.UnsupportedDebugInfo,
            .RBP_FRAME => ip: {
                const frame = encoding.value.x86_64.frame;

                const fp = (try regValueNative(context.thread_context, fpRegNum(reg_context), reg_context)).*;
                const new_sp = fp + 2 * @sizeOf(usize);

                const ip_ptr = fp + @sizeOf(usize);
                const new_ip = @as(*const usize, @ptrFromInt(ip_ptr)).*;
                const new_fp = @as(*const usize, @ptrFromInt(fp)).*;

                (try regValueNative(context.thread_context, fpRegNum(reg_context), reg_context)).* = new_fp;
                (try regValueNative(context.thread_context, spRegNum(reg_context), reg_context)).* = new_sp;
                (try regValueNative(context.thread_context, ip_reg_num, reg_context)).* = new_ip;

                const regs: [5]u3 = .{
                    frame.reg0,
                    frame.reg1,
                    frame.reg2,
                    frame.reg3,
                    frame.reg4,
                };
                for (regs, 0..) |reg, i| {
                    if (reg == 0) continue;
                    const addr = fp - frame.frame_offset * @sizeOf(usize) + i * @sizeOf(usize);
                    const reg_number = try Dwarf.compactUnwindToDwarfRegNumber(reg);
                    (try regValueNative(context.thread_context, reg_number, reg_context)).* = @as(*const usize, @ptrFromInt(addr)).*;
                }

                break :ip new_ip;
            },
            .STACK_IMMD,
            .STACK_IND,
            => ip: {
                const frameless = encoding.value.x86_64.frameless;

                const sp = (try regValueNative(context.thread_context, spRegNum(reg_context), reg_context)).*;
                const stack_size: usize = stack_size: {
                    if (encoding.mode.x86_64 == .STACK_IMMD) {
                        break :stack_size @as(usize, frameless.stack.direct.stack_size) * @sizeOf(usize);
                    }
                    // In .STACK_IND, the stack size is inferred from the subq instruction at the beginning of the function.
                    const sub_offset_addr =
                        module.text_base +
                        entry.function_offset +
                        frameless.stack.indirect.sub_offset;
                    // `sub_offset_addr` points to the offset of the literal within the instruction
                    const sub_operand = @as(*align(1) const u32, @ptrFromInt(sub_offset_addr)).*;
                    break :stack_size sub_operand + @sizeOf(usize) * @as(usize, frameless.stack.indirect.stack_adjust);
                };

                // Decode the Lehmer-coded sequence of registers.
                // For a description of the encoding see lib/libc/include/any-macos.13-any/mach-o/compact_unwind_encoding.h

                // Decode the variable-based permutation number into its digits. Each digit represents
                // an index into the list of register numbers that weren't yet used in the sequence at
                // the time the digit was added.
                const reg_count = frameless.stack_reg_count;
                const ip_ptr = ip_ptr: {
                    var digits: [6]u3 = undefined;
                    var accumulator: usize = frameless.stack_reg_permutation;
                    var base: usize = 2;
                    for (0..reg_count) |i| {
                        const div = accumulator / base;
                        digits[digits.len - 1 - i] = @intCast(accumulator - base * div);
                        accumulator = div;
                        base += 1;
                    }

                    var registers: [6]u3 = undefined;
                    var used_indices: [6]bool = @splat(false);
                    for (digits[digits.len - reg_count ..], 0..) |target_unused_index, i| {
                        var unused_count: u8 = 0;
                        const unused_index = for (used_indices, 0..) |used, index| {
                            if (!used) {
                                if (target_unused_index == unused_count) break index;
                                unused_count += 1;
                            }
                        } else unreachable;
                        registers[i] = @intCast(unused_index + 1);
                        used_indices[unused_index] = true;
                    }

                    var reg_addr = sp + stack_size - @sizeOf(usize) * @as(usize, reg_count + 1);
                    for (0..reg_count) |i| {
                        const reg_number = try Dwarf.compactUnwindToDwarfRegNumber(registers[i]);
                        (try regValueNative(context.thread_context, reg_number, reg_context)).* = @as(*const usize, @ptrFromInt(reg_addr)).*;
                        reg_addr += @sizeOf(usize);
                    }

                    break :ip_ptr reg_addr;
                };

                const new_ip = @as(*const usize, @ptrFromInt(ip_ptr)).*;
                const new_sp = ip_ptr + @sizeOf(usize);

                (try regValueNative(context.thread_context, spRegNum(reg_context), reg_context)).* = new_sp;
                (try regValueNative(context.thread_context, ip_reg_num, reg_context)).* = new_ip;

                break :ip new_ip;
            },
            .DWARF => {
                const eh_frame = unwind.eh_frame orelse return error.MissingDebugInfo;
                const eh_frame_vaddr = @intFromPtr(eh_frame.ptr) - module.load_offset;
                return context.unwindFrameDwarf(
                    &.initSection(.eh_frame, eh_frame_vaddr, eh_frame),
                    module.load_offset,
                    @intCast(encoding.value.x86_64.dwarf),
                );
            },
        },
        .aarch64, .aarch64_be => switch (encoding.mode.arm64) {
            .OLD => return error.UnsupportedDebugInfo,
            .FRAMELESS => ip: {
                const sp = (try regValueNative(context.thread_context, spRegNum(reg_context), reg_context)).*;
                const new_sp = sp + encoding.value.arm64.frameless.stack_size * 16;
                const new_ip = (try regValueNative(context.thread_context, 30, reg_context)).*;
                (try regValueNative(context.thread_context, spRegNum(reg_context), reg_context)).* = new_sp;
                break :ip new_ip;
            },
            .DWARF => {
                const eh_frame = unwind.eh_frame orelse return error.MissingDebugInfo;
                const eh_frame_vaddr = @intFromPtr(eh_frame.ptr) - module.load_offset;
                return context.unwindFrameDwarf(
                    &.initSection(.eh_frame, eh_frame_vaddr, eh_frame),
                    module.load_offset,
                    @intCast(encoding.value.x86_64.dwarf),
                );
            },
            .FRAME => ip: {
                const frame = encoding.value.arm64.frame;

                const fp = (try regValueNative(context.thread_context, fpRegNum(reg_context), reg_context)).*;
                const ip_ptr = fp + @sizeOf(usize);

                var reg_addr = fp - @sizeOf(usize);
                inline for (@typeInfo(@TypeOf(frame.x_reg_pairs)).@"struct".fields, 0..) |field, i| {
                    if (@field(frame.x_reg_pairs, field.name) != 0) {
                        (try regValueNative(context.thread_context, 19 + i, reg_context)).* = @as(*const usize, @ptrFromInt(reg_addr)).*;
                        reg_addr += @sizeOf(usize);
                        (try regValueNative(context.thread_context, 20 + i, reg_context)).* = @as(*const usize, @ptrFromInt(reg_addr)).*;
                        reg_addr += @sizeOf(usize);
                    }
                }

                inline for (@typeInfo(@TypeOf(frame.d_reg_pairs)).@"struct".fields, 0..) |field, i| {
                    if (@field(frame.d_reg_pairs, field.name) != 0) {
                        // Only the lower half of the 128-bit V registers are restored during unwinding
                        {
                            const dest: *align(1) usize = @ptrCast(try regBytes(context.thread_context, 64 + 8 + i, context.reg_context));
                            dest.* = @as(*const usize, @ptrFromInt(reg_addr)).*;
                        }
                        reg_addr += @sizeOf(usize);
                        {
                            const dest: *align(1) usize = @ptrCast(try regBytes(context.thread_context, 64 + 9 + i, context.reg_context));
                            dest.* = @as(*const usize, @ptrFromInt(reg_addr)).*;
                        }
                        reg_addr += @sizeOf(usize);
                    }
                }

                const new_ip = @as(*const usize, @ptrFromInt(ip_ptr)).*;
                const new_fp = @as(*const usize, @ptrFromInt(fp)).*;

                (try regValueNative(context.thread_context, fpRegNum(reg_context), reg_context)).* = new_fp;
                (try regValueNative(context.thread_context, ip_reg_num, reg_context)).* = new_ip;

                break :ip new_ip;
            },
        },
        else => comptime unreachable, // unimplemented
    };

    context.pc = UnwindContext.stripInstructionPtrAuthCode(new_ip);
    if (context.pc > 0) context.pc -= 1;
    return new_ip;
}
pub const DebugInfo = struct {
    unwind: ?Unwind,
    // MLUGG TODO: awful field name
    full: ?Full,

    pub const init: DebugInfo = .{
        .unwind = null,
        .full = null,
    };

    pub fn deinit(di: *DebugInfo, gpa: Allocator) void {
        if (di.full) |*full| {
            for (full.ofiles.values()) |*ofile| {
                ofile.dwarf.deinit(gpa);
                ofile.symbols_by_name.deinit(gpa);
            }
            full.ofiles.deinit(gpa);
            gpa.free(full.symbols);
            posix.munmap(full.mapped_memory);
        }
    }

    const Unwind = struct {
        // Backed by the in-memory sections mapped by the loader
        unwind_info: ?[]const u8,
        eh_frame: ?[]const u8,
    };

    const Full = struct {
        mapped_memory: []align(std.heap.page_size_min) const u8,
        symbols: []const MachoSymbol,
        strings: [:0]const u8,
        /// Key is index into `strings` of the file path.
        ofiles: std.AutoArrayHashMapUnmanaged(u32, OFile),
    };

    const OFile = struct {
        dwarf: Dwarf,
        strtab: [:0]const u8,
        symtab: []align(1) const macho.nlist_64,
        /// All named symbols in `symtab`. Stored `u32` key is the index into `symtab`. Accessed
        /// through `SymbolAdapter`, so that the symbol name is used as the logical key.
        symbols_by_name: std.ArrayHashMapUnmanaged(u32, void, void, true),

        const SymbolAdapter = struct {
            strtab: [:0]const u8,
            symtab: []align(1) const macho.nlist_64,
            pub fn hash(ctx: SymbolAdapter, sym_name: []const u8) u32 {
                _ = ctx;
                return @truncate(std.hash.Wyhash.hash(0, sym_name));
            }
            pub fn eql(ctx: SymbolAdapter, a_sym_name: []const u8, b_sym_index: u32, b_index: usize) bool {
                _ = b_index;
                const b_sym = ctx.symtab[b_sym_index];
                const b_sym_name = std.mem.sliceTo(ctx.strtab[b_sym.n_strx..], 0);
                return mem.eql(u8, a_sym_name, b_sym_name);
            }
        };
    };

    fn loadOFile(gpa: Allocator, o_file_path: []const u8) !OFile {
        const mapped_mem = try mapDebugInfoFile(o_file_path);
        errdefer posix.munmap(mapped_mem);

        if (mapped_mem.len < @sizeOf(macho.mach_header_64)) return error.InvalidDebugInfo;
        const hdr: *const macho.mach_header_64 = @ptrCast(@alignCast(mapped_mem.ptr));
        if (hdr.magic != std.macho.MH_MAGIC_64) return error.InvalidDebugInfo;

        const seg_cmd: macho.LoadCommandIterator.LoadCommand, const symtab_cmd: macho.symtab_command = cmds: {
            var seg_cmd: ?macho.LoadCommandIterator.LoadCommand = null;
            var symtab_cmd: ?macho.symtab_command = null;
            var it: macho.LoadCommandIterator = .{
                .ncmds = hdr.ncmds,
                .buffer = mapped_mem[@sizeOf(macho.mach_header_64)..][0..hdr.sizeofcmds],
            };
            while (it.next()) |cmd| switch (cmd.cmd()) {
                .SEGMENT_64 => seg_cmd = cmd,
                .SYMTAB => symtab_cmd = cmd.cast(macho.symtab_command) orelse return error.InvalidDebugInfo,
                else => {},
            };
            break :cmds .{
                seg_cmd orelse return error.MissingDebugInfo,
                symtab_cmd orelse return error.MissingDebugInfo,
            };
        };

        if (mapped_mem.len < symtab_cmd.stroff + symtab_cmd.strsize) return error.InvalidDebugInfo;
        if (mapped_mem[symtab_cmd.stroff + symtab_cmd.strsize - 1] != 0) return error.InvalidDebugInfo;
        const strtab = mapped_mem[symtab_cmd.stroff..][0 .. symtab_cmd.strsize - 1 :0];

        const n_sym_bytes = symtab_cmd.nsyms * @sizeOf(macho.nlist_64);
        if (mapped_mem.len < symtab_cmd.symoff + n_sym_bytes) return error.InvalidDebugInfo;
        const symtab: []align(1) const macho.nlist_64 = @ptrCast(mapped_mem[symtab_cmd.symoff..][0..n_sym_bytes]);

        // TODO handle tentative (common) symbols
        var symbols_by_name: std.ArrayHashMapUnmanaged(u32, void, void, true) = .empty;
        defer symbols_by_name.deinit(gpa);
        try symbols_by_name.ensureUnusedCapacity(gpa, @intCast(symtab.len));
        for (symtab, 0..) |sym, sym_index| {
            if (sym.n_strx == 0) continue;
            switch (sym.n_type.bits.type) {
                .undf => continue, // includes tentative symbols
                .abs => continue,
                else => {},
            }
            const sym_name = mem.sliceTo(strtab[sym.n_strx..], 0);
            const gop = symbols_by_name.getOrPutAssumeCapacityAdapted(
                @as([]const u8, sym_name),
                @as(DebugInfo.OFile.SymbolAdapter, .{ .strtab = strtab, .symtab = symtab }),
            );
            if (gop.found_existing) return error.InvalidDebugInfo;
            gop.key_ptr.* = @intCast(sym_index);
        }

        var sections: Dwarf.SectionArray = @splat(null);
        for (seg_cmd.getSections()) |sect| {
            if (!std.mem.eql(u8, "__DWARF", sect.segName())) continue;

            const section_index: usize = inline for (@typeInfo(Dwarf.Section.Id).@"enum".fields, 0..) |section, i| {
                if (mem.eql(u8, "__" ++ section.name, sect.sectName())) break i;
            } else continue;

            if (mapped_mem.len < sect.offset + sect.size) return error.InvalidDebugInfo;
            const section_bytes = mapped_mem[sect.offset..][0..sect.size];
            sections[section_index] = .{
                .data = section_bytes,
                .owned = false,
            };
        }

        const missing_debug_info =
            sections[@intFromEnum(Dwarf.Section.Id.debug_info)] == null or
            sections[@intFromEnum(Dwarf.Section.Id.debug_abbrev)] == null or
            sections[@intFromEnum(Dwarf.Section.Id.debug_str)] == null or
            sections[@intFromEnum(Dwarf.Section.Id.debug_line)] == null;
        if (missing_debug_info) return error.MissingDebugInfo;

        var dwarf: Dwarf = .{ .sections = sections };
        errdefer dwarf.deinit(gpa);
        try dwarf.open(gpa, native_endian);

        return .{
            .dwarf = dwarf,
            .strtab = strtab,
            .symtab = symtab,
            .symbols_by_name = symbols_by_name.move(),
        };
    }
};

const MachoSymbol = struct {
    strx: u32,
    addr: u64,
    size: u32,
    ofile: u32,
    fn addressLessThan(context: void, lhs: MachoSymbol, rhs: MachoSymbol) bool {
        _ = context;
        return lhs.addr < rhs.addr;
    }
    /// Assumes that `symbols` is sorted in order of ascending `addr`.
    fn find(symbols: []const MachoSymbol, address: usize) ?*const MachoSymbol {
        if (symbols.len == 0) return null; // no potential match
        if (address < symbols[0].addr) return null; // address is before the lowest-address symbol
        var left: usize = 0;
        var len: usize = symbols.len;
        while (len > 1) {
            const mid = left + len / 2;
            if (address < symbols[mid].addr) {
                len /= 2;
            } else {
                left = mid;
                len -= len / 2;
            }
        }
        return &symbols[left];
    }

    test find {
        const symbols: []const MachoSymbol = &.{
            .{ .addr = 100, .strx = undefined, .size = undefined, .ofile = undefined },
            .{ .addr = 200, .strx = undefined, .size = undefined, .ofile = undefined },
            .{ .addr = 300, .strx = undefined, .size = undefined, .ofile = undefined },
        };

        try testing.expectEqual(null, find(symbols, 0));
        try testing.expectEqual(null, find(symbols, 99));
        try testing.expectEqual(&symbols[0], find(symbols, 100).?);
        try testing.expectEqual(&symbols[0], find(symbols, 150).?);
        try testing.expectEqual(&symbols[0], find(symbols, 199).?);

        try testing.expectEqual(&symbols[1], find(symbols, 200).?);
        try testing.expectEqual(&symbols[1], find(symbols, 250).?);
        try testing.expectEqual(&symbols[1], find(symbols, 299).?);

        try testing.expectEqual(&symbols[2], find(symbols, 300).?);
        try testing.expectEqual(&symbols[2], find(symbols, 301).?);
        try testing.expectEqual(&symbols[2], find(symbols, 5000).?);
    }
};
test {
    _ = MachoSymbol;
}

fn fpRegNum(reg_context: Dwarf.abi.RegisterContext) u8 {
    return Dwarf.abi.fpRegNum(builtin.target.cpu.arch, reg_context);
}
fn spRegNum(reg_context: Dwarf.abi.RegisterContext) u8 {
    return Dwarf.abi.spRegNum(builtin.target.cpu.arch, reg_context);
}
const ip_reg_num = Dwarf.abi.ipRegNum(builtin.target.cpu.arch).?;

/// Uses `mmap` to map the file at `path` into memory.
fn mapDebugInfoFile(path: []const u8) ![]align(std.heap.page_size_min) const u8 {
    const file = std.fs.cwd().openFile(path, .{}) catch |err| switch (err) {
        error.FileNotFound => return error.MissingDebugInfo,
        else => return error.ReadFailed,
    };
    defer file.close();

    const file_len = std.math.cast(usize, try file.getEndPos()) orelse return error.InvalidDebugInfo;

    return posix.mmap(
        null,
        file_len,
        posix.PROT.READ,
        .{ .TYPE = .SHARED },
        file.handle,
        0,
    );
}

const DarwinModule = @This();

const std = @import("../../std.zig");
const Allocator = std.mem.Allocator;
const Dwarf = std.debug.Dwarf;
const assert = std.debug.assert;
const macho = std.macho;
const mem = std.mem;
const posix = std.posix;
const testing = std.testing;
const UnwindContext = std.debug.SelfInfo.UnwindContext;
const Error = std.debug.SelfInfo.Error;
const regBytes = Dwarf.abi.regBytes;
const regValueNative = Dwarf.abi.regValueNative;

const builtin = @import("builtin");
const native_endian = builtin.target.cpu.arch.endian();
