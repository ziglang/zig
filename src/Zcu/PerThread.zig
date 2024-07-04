zcu: *Zcu,

/// Dense, per-thread unique index.
tid: Id,

pub const Id = if (builtin.single_threaded) enum { main } else enum(usize) { main, _ };

pub fn astGenFile(
    pt: Zcu.PerThread,
    file: *Zcu.File,
    /// This parameter is provided separately from `file` because it is not
    /// safe to access `import_table` without a lock, and this index is needed
    /// in the call to `updateZirRefs`.
    file_index: Zcu.File.Index,
    path_digest: Cache.BinDigest,
    opt_root_decl: Zcu.Decl.OptionalIndex,
) !void {
    assert(!file.mod.isBuiltin());

    const tracy = trace(@src());
    defer tracy.end();

    const zcu = pt.zcu;
    const comp = zcu.comp;
    const gpa = zcu.gpa;

    // In any case we need to examine the stat of the file to determine the course of action.
    var source_file = try file.mod.root.openFile(file.sub_file_path, .{});
    defer source_file.close();

    const stat = try source_file.stat();

    const want_local_cache = file.mod == zcu.main_mod;
    const hex_digest = Cache.binToHex(path_digest);
    const cache_directory = if (want_local_cache) zcu.local_zir_cache else zcu.global_zir_cache;
    const zir_dir = cache_directory.handle;

    // Determine whether we need to reload the file from disk and redo parsing and AstGen.
    var lock: std.fs.File.Lock = switch (file.status) {
        .never_loaded, .retryable_failure => lock: {
            // First, load the cached ZIR code, if any.
            log.debug("AstGen checking cache: {s} (local={}, digest={s})", .{
                file.sub_file_path, want_local_cache, &hex_digest,
            });

            break :lock .shared;
        },
        .parse_failure, .astgen_failure, .success_zir => lock: {
            const unchanged_metadata =
                stat.size == file.stat.size and
                stat.mtime == file.stat.mtime and
                stat.inode == file.stat.inode;

            if (unchanged_metadata) {
                log.debug("unmodified metadata of file: {s}", .{file.sub_file_path});
                return;
            }

            log.debug("metadata changed: {s}", .{file.sub_file_path});

            break :lock .exclusive;
        },
    };

    // We ask for a lock in order to coordinate with other zig processes.
    // If another process is already working on this file, we will get the cached
    // version. Likewise if we're working on AstGen and another process asks for
    // the cached file, they'll get it.
    const cache_file = while (true) {
        break zir_dir.createFile(&hex_digest, .{
            .read = true,
            .truncate = false,
            .lock = lock,
        }) catch |err| switch (err) {
            error.NotDir => unreachable, // no dir components
            error.InvalidUtf8 => unreachable, // it's a hex encoded name
            error.InvalidWtf8 => unreachable, // it's a hex encoded name
            error.BadPathName => unreachable, // it's a hex encoded name
            error.NameTooLong => unreachable, // it's a fixed size name
            error.PipeBusy => unreachable, // it's not a pipe
            error.WouldBlock => unreachable, // not asking for non-blocking I/O
            // There are no dir components, so you would think that this was
            // unreachable, however we have observed on macOS two processes racing
            // to do openat() with O_CREAT manifest in ENOENT.
            error.FileNotFound => continue,

            else => |e| return e, // Retryable errors are handled at callsite.
        };
    };
    defer cache_file.close();

    while (true) {
        update: {
            // First we read the header to determine the lengths of arrays.
            const header = cache_file.reader().readStruct(Zir.Header) catch |err| switch (err) {
                // This can happen if Zig bails out of this function between creating
                // the cached file and writing it.
                error.EndOfStream => break :update,
                else => |e| return e,
            };
            const unchanged_metadata =
                stat.size == header.stat_size and
                stat.mtime == header.stat_mtime and
                stat.inode == header.stat_inode;

            if (!unchanged_metadata) {
                log.debug("AstGen cache stale: {s}", .{file.sub_file_path});
                break :update;
            }
            log.debug("AstGen cache hit: {s} instructions_len={d}", .{
                file.sub_file_path, header.instructions_len,
            });

            file.zir = Zcu.loadZirCacheBody(gpa, header, cache_file) catch |err| switch (err) {
                error.UnexpectedFileSize => {
                    log.warn("unexpected EOF reading cached ZIR for {s}", .{file.sub_file_path});
                    break :update;
                },
                else => |e| return e,
            };
            file.zir_loaded = true;
            file.stat = .{
                .size = header.stat_size,
                .inode = header.stat_inode,
                .mtime = header.stat_mtime,
            };
            file.status = .success_zir;
            log.debug("AstGen cached success: {s}", .{file.sub_file_path});

            // TODO don't report compile errors until Sema @importFile
            if (file.zir.hasCompileErrors()) {
                {
                    comp.mutex.lock();
                    defer comp.mutex.unlock();
                    try zcu.failed_files.putNoClobber(gpa, file, null);
                }
                file.status = .astgen_failure;
                return error.AnalysisFail;
            }
            return;
        }

        // If we already have the exclusive lock then it is our job to update.
        if (builtin.os.tag == .wasi or lock == .exclusive) break;
        // Otherwise, unlock to give someone a chance to get the exclusive lock
        // and then upgrade to an exclusive lock.
        cache_file.unlock();
        lock = .exclusive;
        try cache_file.lock(lock);
    }

    // The cache is definitely stale so delete the contents to avoid an underwrite later.
    cache_file.setEndPos(0) catch |err| switch (err) {
        error.FileTooBig => unreachable, // 0 is not too big

        else => |e| return e,
    };

    pt.lockAndClearFileCompileError(file);

    // If the previous ZIR does not have compile errors, keep it around
    // in case parsing or new ZIR fails. In case of successful ZIR update
    // at the end of this function we will free it.
    // We keep the previous ZIR loaded so that we can use it
    // for the update next time it does not have any compile errors. This avoids
    // needlessly tossing out semantic analysis work when an error is
    // temporarily introduced.
    if (file.zir_loaded and !file.zir.hasCompileErrors()) {
        assert(file.prev_zir == null);
        const prev_zir_ptr = try gpa.create(Zir);
        file.prev_zir = prev_zir_ptr;
        prev_zir_ptr.* = file.zir;
        file.zir = undefined;
        file.zir_loaded = false;
    }
    file.unload(gpa);

    if (stat.size > std.math.maxInt(u32))
        return error.FileTooBig;

    const source = try gpa.allocSentinel(u8, @as(usize, @intCast(stat.size)), 0);
    defer if (!file.source_loaded) gpa.free(source);
    const amt = try source_file.readAll(source);
    if (amt != stat.size)
        return error.UnexpectedEndOfFile;

    file.stat = .{
        .size = stat.size,
        .inode = stat.inode,
        .mtime = stat.mtime,
    };
    file.source = source;
    file.source_loaded = true;

    file.tree = try Ast.parse(gpa, source, .zig);
    file.tree_loaded = true;

    // Any potential AST errors are converted to ZIR errors here.
    file.zir = try AstGen.generate(gpa, file.tree);
    file.zir_loaded = true;
    file.status = .success_zir;
    log.debug("AstGen fresh success: {s}", .{file.sub_file_path});

    const safety_buffer = if (Zcu.data_has_safety_tag)
        try gpa.alloc([8]u8, file.zir.instructions.len)
    else
        undefined;
    defer if (Zcu.data_has_safety_tag) gpa.free(safety_buffer);
    const data_ptr = if (Zcu.data_has_safety_tag)
        if (file.zir.instructions.len == 0)
            @as([*]const u8, undefined)
        else
            @as([*]const u8, @ptrCast(safety_buffer.ptr))
    else
        @as([*]const u8, @ptrCast(file.zir.instructions.items(.data).ptr));
    if (Zcu.data_has_safety_tag) {
        // The `Data` union has a safety tag but in the file format we store it without.
        for (file.zir.instructions.items(.data), 0..) |*data, i| {
            const as_struct: *const Zcu.HackDataLayout = @ptrCast(data);
            safety_buffer[i] = as_struct.data;
        }
    }

    const header: Zir.Header = .{
        .instructions_len = @as(u32, @intCast(file.zir.instructions.len)),
        .string_bytes_len = @as(u32, @intCast(file.zir.string_bytes.len)),
        .extra_len = @as(u32, @intCast(file.zir.extra.len)),

        .stat_size = stat.size,
        .stat_inode = stat.inode,
        .stat_mtime = stat.mtime,
    };
    var iovecs = [_]std.posix.iovec_const{
        .{
            .base = @as([*]const u8, @ptrCast(&header)),
            .len = @sizeOf(Zir.Header),
        },
        .{
            .base = @as([*]const u8, @ptrCast(file.zir.instructions.items(.tag).ptr)),
            .len = file.zir.instructions.len,
        },
        .{
            .base = data_ptr,
            .len = file.zir.instructions.len * 8,
        },
        .{
            .base = file.zir.string_bytes.ptr,
            .len = file.zir.string_bytes.len,
        },
        .{
            .base = @as([*]const u8, @ptrCast(file.zir.extra.ptr)),
            .len = file.zir.extra.len * 4,
        },
    };
    cache_file.writevAll(&iovecs) catch |err| {
        log.warn("unable to write cached ZIR code for {}{s} to {}{s}: {s}", .{
            file.mod.root, file.sub_file_path, cache_directory, &hex_digest, @errorName(err),
        });
    };

    if (file.zir.hasCompileErrors()) {
        {
            comp.mutex.lock();
            defer comp.mutex.unlock();
            try zcu.failed_files.putNoClobber(gpa, file, null);
        }
        file.status = .astgen_failure;
        return error.AnalysisFail;
    }

    if (file.prev_zir) |prev_zir| {
        try pt.updateZirRefs(file, file_index, prev_zir.*);
        // No need to keep previous ZIR.
        prev_zir.deinit(gpa);
        gpa.destroy(prev_zir);
        file.prev_zir = null;
    }

    if (opt_root_decl.unwrap()) |root_decl| {
        // The root of this file must be re-analyzed, since the file has changed.
        comp.mutex.lock();
        defer comp.mutex.unlock();

        log.debug("outdated root Decl: {}", .{root_decl});
        try zcu.outdated_file_root.put(gpa, root_decl, {});
    }
}

/// This is called from the AstGen thread pool, so must acquire
/// the Compilation mutex when acting on shared state.
fn updateZirRefs(pt: Zcu.PerThread, file: *Zcu.File, file_index: Zcu.File.Index, old_zir: Zir) !void {
    const zcu = pt.zcu;
    const gpa = zcu.gpa;
    const new_zir = file.zir;

    var inst_map: std.AutoHashMapUnmanaged(Zir.Inst.Index, Zir.Inst.Index) = .{};
    defer inst_map.deinit(gpa);

    try Zcu.mapOldZirToNew(gpa, old_zir, new_zir, &inst_map);

    const old_tag = old_zir.instructions.items(.tag);
    const old_data = old_zir.instructions.items(.data);

    // TODO: this should be done after all AstGen workers complete, to avoid
    // iterating over this full set for every updated file.
    for (zcu.intern_pool.tracked_insts.keys(), 0..) |*ti, idx_raw| {
        const ti_idx: InternPool.TrackedInst.Index = @enumFromInt(idx_raw);
        if (ti.file != file_index) continue;
        const old_inst = ti.inst;
        ti.inst = inst_map.get(ti.inst) orelse {
            // Tracking failed for this instruction. Invalidate associated `src_hash` deps.
            zcu.comp.mutex.lock();
            defer zcu.comp.mutex.unlock();
            log.debug("tracking failed for %{d}", .{old_inst});
            try zcu.markDependeeOutdated(.{ .src_hash = ti_idx });
            continue;
        };

        if (old_zir.getAssociatedSrcHash(old_inst)) |old_hash| hash_changed: {
            if (new_zir.getAssociatedSrcHash(ti.inst)) |new_hash| {
                if (std.zig.srcHashEql(old_hash, new_hash)) {
                    break :hash_changed;
                }
                log.debug("hash for (%{d} -> %{d}) changed: {} -> {}", .{
                    old_inst,
                    ti.inst,
                    std.fmt.fmtSliceHexLower(&old_hash),
                    std.fmt.fmtSliceHexLower(&new_hash),
                });
            }
            // The source hash associated with this instruction changed - invalidate relevant dependencies.
            zcu.comp.mutex.lock();
            defer zcu.comp.mutex.unlock();
            try zcu.markDependeeOutdated(.{ .src_hash = ti_idx });
        }

        // If this is a `struct_decl` etc, we must invalidate any outdated namespace dependencies.
        const has_namespace = switch (old_tag[@intFromEnum(old_inst)]) {
            .extended => switch (old_data[@intFromEnum(old_inst)].extended.opcode) {
                .struct_decl, .union_decl, .opaque_decl, .enum_decl => true,
                else => false,
            },
            else => false,
        };
        if (!has_namespace) continue;

        var old_names: std.AutoArrayHashMapUnmanaged(InternPool.NullTerminatedString, void) = .{};
        defer old_names.deinit(zcu.gpa);
        {
            var it = old_zir.declIterator(old_inst);
            while (it.next()) |decl_inst| {
                const decl_name = old_zir.getDeclaration(decl_inst)[0].name;
                switch (decl_name) {
                    .@"comptime", .@"usingnamespace", .unnamed_test, .decltest => continue,
                    _ => if (decl_name.isNamedTest(old_zir)) continue,
                }
                const name_zir = decl_name.toString(old_zir).?;
                const name_ip = try zcu.intern_pool.getOrPutString(
                    zcu.gpa,
                    pt.tid,
                    old_zir.nullTerminatedString(name_zir),
                    .no_embedded_nulls,
                );
                try old_names.put(zcu.gpa, name_ip, {});
            }
        }
        var any_change = false;
        {
            var it = new_zir.declIterator(ti.inst);
            while (it.next()) |decl_inst| {
                const decl_name = old_zir.getDeclaration(decl_inst)[0].name;
                switch (decl_name) {
                    .@"comptime", .@"usingnamespace", .unnamed_test, .decltest => continue,
                    _ => if (decl_name.isNamedTest(old_zir)) continue,
                }
                const name_zir = decl_name.toString(old_zir).?;
                const name_ip = try zcu.intern_pool.getOrPutString(
                    zcu.gpa,
                    pt.tid,
                    old_zir.nullTerminatedString(name_zir),
                    .no_embedded_nulls,
                );
                if (!old_names.swapRemove(name_ip)) continue;
                // Name added
                any_change = true;
                zcu.comp.mutex.lock();
                defer zcu.comp.mutex.unlock();
                try zcu.markDependeeOutdated(.{ .namespace_name = .{
                    .namespace = ti_idx,
                    .name = name_ip,
                } });
            }
        }
        // The only elements remaining in `old_names` now are any names which were removed.
        for (old_names.keys()) |name_ip| {
            any_change = true;
            zcu.comp.mutex.lock();
            defer zcu.comp.mutex.unlock();
            try zcu.markDependeeOutdated(.{ .namespace_name = .{
                .namespace = ti_idx,
                .name = name_ip,
            } });
        }

        if (any_change) {
            zcu.comp.mutex.lock();
            defer zcu.comp.mutex.unlock();
            try zcu.markDependeeOutdated(.{ .namespace = ti_idx });
        }
    }
}

/// Like `ensureDeclAnalyzed`, but the Decl is a file's root Decl.
pub fn ensureFileAnalyzed(pt: Zcu.PerThread, file_index: Zcu.File.Index) Zcu.SemaError!void {
    if (pt.zcu.fileRootDecl(file_index).unwrap()) |existing_root| {
        return pt.ensureDeclAnalyzed(existing_root);
    } else {
        return pt.semaFile(file_index);
    }
}

/// This ensures that the Decl will have an up-to-date Type and Value populated.
/// However the resolution status of the Type may not be fully resolved.
/// For example an inferred error set is not resolved until after `analyzeFnBody`.
/// is called.
pub fn ensureDeclAnalyzed(pt: Zcu.PerThread, decl_index: Zcu.Decl.Index) Zcu.SemaError!void {
    const tracy = trace(@src());
    defer tracy.end();

    const mod = pt.zcu;
    const ip = &mod.intern_pool;
    const decl = mod.declPtr(decl_index);

    log.debug("ensureDeclAnalyzed '{d}' (name '{}')", .{
        @intFromEnum(decl_index),
        decl.name.fmt(ip),
    });

    // Determine whether or not this Decl is outdated, i.e. requires re-analysis
    // even if `complete`. If a Decl is PO, we pessismistically assume that it
    // *does* require re-analysis, to ensure that the Decl is definitely
    // up-to-date when this function returns.

    // If analysis occurs in a poor order, this could result in over-analysis.
    // We do our best to avoid this by the other dependency logic in this file
    // which tries to limit re-analysis to Decls whose previously listed
    // dependencies are all up-to-date.

    const decl_as_depender = InternPool.AnalUnit.wrap(.{ .decl = decl_index });
    const decl_was_outdated = mod.outdated.swapRemove(decl_as_depender) or
        mod.potentially_outdated.swapRemove(decl_as_depender);

    if (decl_was_outdated) {
        _ = mod.outdated_ready.swapRemove(decl_as_depender);
    }

    const was_outdated = mod.outdated_file_root.swapRemove(decl_index) or decl_was_outdated;

    switch (decl.analysis) {
        .in_progress => unreachable,

        .file_failure => return error.AnalysisFail,

        .sema_failure,
        .dependency_failure,
        .codegen_failure,
        => if (!was_outdated) return error.AnalysisFail,

        .complete => if (!was_outdated) return,

        .unreferenced => {},
    }

    if (was_outdated) {
        // The exports this Decl performs will be re-discovered, so we remove them here
        // prior to re-analysis.
        if (build_options.only_c) unreachable;
        mod.deleteUnitExports(decl_as_depender);
        mod.deleteUnitReferences(decl_as_depender);
    }

    const sema_result: Zcu.SemaDeclResult = blk: {
        if (decl.zir_decl_index == .none and !mod.declIsRoot(decl_index)) {
            // Anonymous decl. We don't semantically analyze these.
            break :blk .{
                .invalidate_decl_val = false,
                .invalidate_decl_ref = false,
            };
        }

        if (mod.declIsRoot(decl_index)) {
            const changed = try pt.semaFileUpdate(decl.getFileScopeIndex(mod), decl_was_outdated);
            break :blk .{
                .invalidate_decl_val = changed,
                .invalidate_decl_ref = changed,
            };
        }

        const decl_prog_node = mod.sema_prog_node.start((try decl.fullyQualifiedName(pt)).toSlice(ip), 0);
        defer decl_prog_node.end();

        break :blk pt.semaDecl(decl_index) catch |err| switch (err) {
            error.AnalysisFail => {
                if (decl.analysis == .in_progress) {
                    // If this decl caused the compile error, the analysis field would
                    // be changed to indicate it was this Decl's fault. Because this
                    // did not happen, we infer here that it was a dependency failure.
                    decl.analysis = .dependency_failure;
                }
                return error.AnalysisFail;
            },
            error.GenericPoison => unreachable,
            else => |e| {
                decl.analysis = .sema_failure;
                try mod.failed_analysis.ensureUnusedCapacity(mod.gpa, 1);
                try mod.retryable_failures.append(mod.gpa, InternPool.AnalUnit.wrap(.{ .decl = decl_index }));
                mod.failed_analysis.putAssumeCapacityNoClobber(InternPool.AnalUnit.wrap(.{ .decl = decl_index }), try Zcu.ErrorMsg.create(
                    mod.gpa,
                    decl.navSrcLoc(mod),
                    "unable to analyze: {s}",
                    .{@errorName(e)},
                ));
                return error.AnalysisFail;
            },
        };
    };

    // TODO: we do not yet have separate dependencies for decl values vs types.
    if (decl_was_outdated) {
        if (sema_result.invalidate_decl_val or sema_result.invalidate_decl_ref) {
            log.debug("Decl tv invalidated ('{d}')", .{@intFromEnum(decl_index)});
            // This dependency was marked as PO, meaning dependees were waiting
            // on its analysis result, and it has turned out to be outdated.
            // Update dependees accordingly.
            try mod.markDependeeOutdated(.{ .decl_val = decl_index });
        } else {
            log.debug("Decl tv up-to-date ('{d}')", .{@intFromEnum(decl_index)});
            // This dependency was previously PO, but turned out to be up-to-date.
            // We do not need to queue successive analysis.
            try mod.markPoDependeeUpToDate(.{ .decl_val = decl_index });
        }
    }
}

pub fn ensureFuncBodyAnalyzed(pt: Zcu.PerThread, maybe_coerced_func_index: InternPool.Index) Zcu.SemaError!void {
    const tracy = trace(@src());
    defer tracy.end();

    const zcu = pt.zcu;
    const gpa = zcu.gpa;
    const ip = &zcu.intern_pool;

    // We only care about the uncoerced function.
    // We need to do this for the "orphaned function" check below to be valid.
    const func_index = ip.unwrapCoercedFunc(maybe_coerced_func_index);

    const func = zcu.funcInfo(maybe_coerced_func_index);
    const decl_index = func.owner_decl;
    const decl = zcu.declPtr(decl_index);

    log.debug("ensureFuncBodyAnalyzed '{d}' (instance of '{}')", .{
        @intFromEnum(func_index),
        decl.name.fmt(ip),
    });

    // First, our owner decl must be up-to-date. This will always be the case
    // during the first update, but may not on successive updates if we happen
    // to get analyzed before our parent decl.
    try pt.ensureDeclAnalyzed(decl_index);

    // On an update, it's possible this function changed such that our owner
    // decl now refers to a different function, making this one orphaned. If
    // that's the case, we should remove this function from the binary.
    if (decl.val.ip_index != func_index) {
        try zcu.markDependeeOutdated(.{ .func_ies = func_index });
        ip.removeDependenciesForDepender(gpa, InternPool.AnalUnit.wrap(.{ .func = func_index }));
        ip.remove(func_index);
        @panic("TODO: remove orphaned function from binary");
    }

    // We'll want to remember what the IES used to be before the update for
    // dependency invalidation purposes.
    const old_resolved_ies = if (func.analysis(ip).inferred_error_set)
        func.resolvedErrorSet(ip).*
    else
        .none;

    switch (decl.analysis) {
        .unreferenced => unreachable,
        .in_progress => unreachable,

        .codegen_failure => unreachable, // functions do not perform constant value generation

        .file_failure,
        .sema_failure,
        .dependency_failure,
        => return error.AnalysisFail,

        .complete => {},
    }

    const func_as_depender = InternPool.AnalUnit.wrap(.{ .func = func_index });
    const was_outdated = zcu.outdated.swapRemove(func_as_depender) or
        zcu.potentially_outdated.swapRemove(func_as_depender);

    if (was_outdated) {
        if (build_options.only_c) unreachable;
        _ = zcu.outdated_ready.swapRemove(func_as_depender);
        zcu.deleteUnitExports(func_as_depender);
        zcu.deleteUnitReferences(func_as_depender);
    }

    switch (func.analysis(ip).state) {
        .success => if (!was_outdated) return,
        .sema_failure,
        .dependency_failure,
        .codegen_failure,
        => if (!was_outdated) return error.AnalysisFail,
        .none, .queued => {},
        .in_progress => unreachable,
        .inline_only => unreachable, // don't queue work for this
    }

    log.debug("analyze and generate fn body '{d}'; reason='{s}'", .{
        @intFromEnum(func_index),
        if (was_outdated) "outdated" else "never analyzed",
    });

    var tmp_arena = std.heap.ArenaAllocator.init(gpa);
    defer tmp_arena.deinit();
    const sema_arena = tmp_arena.allocator();

    var air = pt.analyzeFnBody(func_index, sema_arena) catch |err| switch (err) {
        error.AnalysisFail => {
            if (func.analysis(ip).state == .in_progress) {
                // If this decl caused the compile error, the analysis field would
                // be changed to indicate it was this Decl's fault. Because this
                // did not happen, we infer here that it was a dependency failure.
                func.analysis(ip).state = .dependency_failure;
            }
            return error.AnalysisFail;
        },
        error.OutOfMemory => return error.OutOfMemory,
    };
    errdefer air.deinit(gpa);

    const invalidate_ies_deps = i: {
        if (!was_outdated) break :i false;
        if (!func.analysis(ip).inferred_error_set) break :i true;
        const new_resolved_ies = func.resolvedErrorSet(ip).*;
        break :i new_resolved_ies != old_resolved_ies;
    };
    if (invalidate_ies_deps) {
        log.debug("func IES invalidated ('{d}')", .{@intFromEnum(func_index)});
        try zcu.markDependeeOutdated(.{ .func_ies = func_index });
    } else if (was_outdated) {
        log.debug("func IES up-to-date ('{d}')", .{@intFromEnum(func_index)});
        try zcu.markPoDependeeUpToDate(.{ .func_ies = func_index });
    }

    const comp = zcu.comp;

    const dump_air = build_options.enable_debug_extensions and comp.verbose_air;
    const dump_llvm_ir = build_options.enable_debug_extensions and (comp.verbose_llvm_ir != null or comp.verbose_llvm_bc != null);

    if (comp.bin_file == null and zcu.llvm_object == null and !dump_air and !dump_llvm_ir) {
        air.deinit(gpa);
        return;
    }

    try comp.work_queue.writeItem(.{ .codegen_func = .{
        .func = func_index,
        .air = air,
    } });
}

/// Takes ownership of `air`, even on error.
/// If any types referenced by `air` are unresolved, marks the codegen as failed.
pub fn linkerUpdateFunc(pt: Zcu.PerThread, func_index: InternPool.Index, air: Air) Allocator.Error!void {
    const zcu = pt.zcu;
    const gpa = zcu.gpa;
    const ip = &zcu.intern_pool;
    const comp = zcu.comp;

    defer {
        var air_mut = air;
        air_mut.deinit(gpa);
    }

    const func = zcu.funcInfo(func_index);
    const decl_index = func.owner_decl;
    const decl = zcu.declPtr(decl_index);

    var liveness = try Liveness.analyze(gpa, air, ip);
    defer liveness.deinit(gpa);

    if (build_options.enable_debug_extensions and comp.verbose_air) {
        const fqn = try decl.fullyQualifiedName(pt);
        std.debug.print("# Begin Function AIR: {}:\n", .{fqn.fmt(ip)});
        @import("../print_air.zig").dump(pt, air, liveness);
        std.debug.print("# End Function AIR: {}\n\n", .{fqn.fmt(ip)});
    }

    if (std.debug.runtime_safety) {
        var verify: Liveness.Verify = .{
            .gpa = gpa,
            .air = air,
            .liveness = liveness,
            .intern_pool = ip,
        };
        defer verify.deinit();

        verify.verify() catch |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            else => {
                try zcu.failed_analysis.ensureUnusedCapacity(gpa, 1);
                zcu.failed_analysis.putAssumeCapacityNoClobber(
                    InternPool.AnalUnit.wrap(.{ .func = func_index }),
                    try Zcu.ErrorMsg.create(
                        gpa,
                        decl.navSrcLoc(zcu),
                        "invalid liveness: {s}",
                        .{@errorName(err)},
                    ),
                );
                func.analysis(ip).state = .codegen_failure;
                return;
            },
        };
    }

    const codegen_prog_node = zcu.codegen_prog_node.start((try decl.fullyQualifiedName(pt)).toSlice(ip), 0);
    defer codegen_prog_node.end();

    if (!air.typesFullyResolved(zcu)) {
        // A type we depend on failed to resolve. This is a transitive failure.
        // Correcting this failure will involve changing a type this function
        // depends on, hence triggering re-analysis of this function, so this
        // interacts correctly with incremental compilation.
        func.analysis(ip).state = .codegen_failure;
    } else if (comp.bin_file) |lf| {
        lf.updateFunc(pt, func_index, air, liveness) catch |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            error.AnalysisFail => {
                func.analysis(ip).state = .codegen_failure;
            },
            else => {
                try zcu.failed_analysis.ensureUnusedCapacity(gpa, 1);
                zcu.failed_analysis.putAssumeCapacityNoClobber(InternPool.AnalUnit.wrap(.{ .func = func_index }), try Zcu.ErrorMsg.create(
                    gpa,
                    decl.navSrcLoc(zcu),
                    "unable to codegen: {s}",
                    .{@errorName(err)},
                ));
                func.analysis(ip).state = .codegen_failure;
                try zcu.retryable_failures.append(zcu.gpa, InternPool.AnalUnit.wrap(.{ .func = func_index }));
            },
        };
    } else if (zcu.llvm_object) |llvm_object| {
        if (build_options.only_c) unreachable;
        llvm_object.updateFunc(pt, func_index, air, liveness) catch |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
        };
    }
}

/// https://github.com/ziglang/zig/issues/14307
pub fn semaPkg(pt: Zcu.PerThread, pkg: *Module) !void {
    const import_file_result = try pt.zcu.importPkg(pkg);
    const root_decl_index = pt.zcu.fileRootDecl(import_file_result.file_index);
    if (root_decl_index == .none) {
        return pt.semaFile(import_file_result.file_index);
    }
}

fn getFileRootStruct(
    pt: Zcu.PerThread,
    decl_index: Zcu.Decl.Index,
    namespace_index: Zcu.Namespace.Index,
    file_index: Zcu.File.Index,
) Allocator.Error!InternPool.Index {
    const zcu = pt.zcu;
    const gpa = zcu.gpa;
    const ip = &zcu.intern_pool;
    const file = zcu.fileByIndex(file_index);
    const extended = file.zir.instructions.items(.data)[@intFromEnum(Zir.Inst.Index.main_struct_inst)].extended;
    assert(extended.opcode == .struct_decl);
    const small: Zir.Inst.StructDecl.Small = @bitCast(extended.small);
    assert(!small.has_captures_len);
    assert(!small.has_backing_int);
    assert(small.layout == .auto);
    var extra_index: usize = extended.operand + @typeInfo(Zir.Inst.StructDecl).Struct.fields.len;
    const fields_len = if (small.has_fields_len) blk: {
        const fields_len = file.zir.extra[extra_index];
        extra_index += 1;
        break :blk fields_len;
    } else 0;
    const decls_len = if (small.has_decls_len) blk: {
        const decls_len = file.zir.extra[extra_index];
        extra_index += 1;
        break :blk decls_len;
    } else 0;
    const decls = file.zir.bodySlice(extra_index, decls_len);
    extra_index += decls_len;

    const tracked_inst = try ip.trackZir(gpa, file_index, .main_struct_inst);
    const wip_ty = switch (try ip.getStructType(gpa, pt.tid, .{
        .layout = .auto,
        .fields_len = fields_len,
        .known_non_opv = small.known_non_opv,
        .requires_comptime = if (small.known_comptime_only) .yes else .unknown,
        .is_tuple = small.is_tuple,
        .any_comptime_fields = small.any_comptime_fields,
        .any_default_inits = small.any_default_inits,
        .inits_resolved = false,
        .any_aligned_fields = small.any_aligned_fields,
        .has_namespace = true,
        .key = .{ .declared = .{
            .zir_index = tracked_inst,
            .captures = &.{},
        } },
    })) {
        .existing => unreachable, // we wouldn't be analysing the file root if this type existed
        .wip => |wip| wip,
    };
    errdefer wip_ty.cancel(ip);

    if (zcu.comp.debug_incremental) {
        try ip.addDependency(
            gpa,
            InternPool.AnalUnit.wrap(.{ .decl = decl_index }),
            .{ .src_hash = tracked_inst },
        );
    }

    const decl = zcu.declPtr(decl_index);
    decl.val = Value.fromInterned(wip_ty.index);
    decl.has_tv = true;
    decl.owns_tv = true;
    decl.analysis = .complete;

    try pt.scanNamespace(namespace_index, decls, decl);
    try zcu.comp.work_queue.writeItem(.{ .resolve_type_fully = wip_ty.index });
    return wip_ty.finish(ip, decl_index, namespace_index.toOptional());
}

/// Re-analyze the root Decl of a file on an incremental update.
/// If `type_outdated`, the struct type itself is considered outdated and is
/// reconstructed at a new InternPool index. Otherwise, the namespace is just
/// re-analyzed. Returns whether the decl's tyval was invalidated.
fn semaFileUpdate(pt: Zcu.PerThread, file_index: Zcu.File.Index, type_outdated: bool) Zcu.SemaError!bool {
    const zcu = pt.zcu;
    const ip = &zcu.intern_pool;
    const file = zcu.fileByIndex(file_index);
    const decl = zcu.declPtr(zcu.fileRootDecl(file_index).unwrap().?);

    log.debug("semaFileUpdate mod={s} sub_file_path={s} type_outdated={}", .{
        file.mod.fully_qualified_name,
        file.sub_file_path,
        type_outdated,
    });

    if (file.status != .success_zir) {
        if (decl.analysis == .file_failure) {
            return false;
        } else {
            decl.analysis = .file_failure;
            return true;
        }
    }

    if (decl.analysis == .file_failure) {
        // No struct type currently exists. Create one!
        const root_decl = zcu.fileRootDecl(file_index);
        _ = try pt.getFileRootStruct(root_decl.unwrap().?, decl.src_namespace, file_index);
        return true;
    }

    assert(decl.has_tv);
    assert(decl.owns_tv);

    if (type_outdated) {
        // Invalidate the existing type, reusing the decl and namespace.
        const file_root_decl = zcu.fileRootDecl(file_index).unwrap().?;
        ip.removeDependenciesForDepender(zcu.gpa, InternPool.AnalUnit.wrap(.{
            .decl = file_root_decl,
        }));
        ip.remove(decl.val.toIntern());
        decl.val = undefined;
        _ = try pt.getFileRootStruct(file_root_decl, decl.src_namespace, file_index);
        return true;
    }

    // Only the struct's namespace is outdated.
    // Preserve the type - just scan the namespace again.

    const extended = file.zir.instructions.items(.data)[@intFromEnum(Zir.Inst.Index.main_struct_inst)].extended;
    const small: Zir.Inst.StructDecl.Small = @bitCast(extended.small);

    var extra_index: usize = extended.operand + @typeInfo(Zir.Inst.StructDecl).Struct.fields.len;
    extra_index += @intFromBool(small.has_fields_len);
    const decls_len = if (small.has_decls_len) blk: {
        const decls_len = file.zir.extra[extra_index];
        extra_index += 1;
        break :blk decls_len;
    } else 0;
    const decls = file.zir.bodySlice(extra_index, decls_len);

    if (!type_outdated) {
        try pt.scanNamespace(decl.src_namespace, decls, decl);
    }

    return false;
}

/// Regardless of the file status, will create a `Decl` if none exists so that we can track
/// dependencies and re-analyze when the file becomes outdated.
fn semaFile(pt: Zcu.PerThread, file_index: Zcu.File.Index) Zcu.SemaError!void {
    const tracy = trace(@src());
    defer tracy.end();

    const zcu = pt.zcu;
    const gpa = zcu.gpa;
    const file = zcu.fileByIndex(file_index);
    assert(zcu.fileRootDecl(file_index) == .none);
    log.debug("semaFile zcu={s} sub_file_path={s}", .{
        file.mod.fully_qualified_name, file.sub_file_path,
    });

    // Because these three things each reference each other, `undefined`
    // placeholders are used before being set after the struct type gains an
    // InternPool index.
    const new_namespace_index = try zcu.createNamespace(.{
        .parent = .none,
        .decl_index = undefined,
        .file_scope = file_index,
    });
    errdefer zcu.destroyNamespace(new_namespace_index);

    const new_decl_index = try zcu.allocateNewDecl(new_namespace_index);
    const new_decl = zcu.declPtr(new_decl_index);
    errdefer @panic("TODO error handling");

    zcu.setFileRootDecl(file_index, new_decl_index.toOptional());
    zcu.namespacePtr(new_namespace_index).decl_index = new_decl_index;

    new_decl.name = try file.fullyQualifiedName(pt);
    new_decl.name_fully_qualified = true;
    new_decl.is_pub = true;
    new_decl.is_exported = false;
    new_decl.alignment = .none;
    new_decl.@"linksection" = .none;
    new_decl.analysis = .in_progress;

    if (file.status != .success_zir) {
        new_decl.analysis = .file_failure;
        return;
    }
    assert(file.zir_loaded);

    const struct_ty = try pt.getFileRootStruct(new_decl_index, new_namespace_index, file_index);
    errdefer zcu.intern_pool.remove(struct_ty);

    switch (zcu.comp.cache_use) {
        .whole => |whole| if (whole.cache_manifest) |man| {
            const source = file.getSource(gpa) catch |err| {
                try Zcu.reportRetryableFileError(zcu, file_index, "unable to load source: {s}", .{@errorName(err)});
                return error.AnalysisFail;
            };

            const resolved_path = std.fs.path.resolve(gpa, &.{
                file.mod.root.root_dir.path orelse ".",
                file.mod.root.sub_path,
                file.sub_file_path,
            }) catch |err| {
                try Zcu.reportRetryableFileError(zcu, file_index, "unable to resolve path: {s}", .{@errorName(err)});
                return error.AnalysisFail;
            };
            errdefer gpa.free(resolved_path);

            whole.cache_manifest_mutex.lock();
            defer whole.cache_manifest_mutex.unlock();
            try man.addFilePostContents(resolved_path, source.bytes, source.stat);
        },
        .incremental => {},
    }
}

fn semaDecl(pt: Zcu.PerThread, decl_index: Zcu.Decl.Index) !Zcu.SemaDeclResult {
    const tracy = trace(@src());
    defer tracy.end();

    const zcu = pt.zcu;
    const decl = zcu.declPtr(decl_index);
    const ip = &zcu.intern_pool;

    if (decl.getFileScope(zcu).status != .success_zir) {
        return error.AnalysisFail;
    }

    assert(!zcu.declIsRoot(decl_index));

    if (decl.zir_decl_index == .none and decl.owns_tv) {
        // We are re-analyzing an anonymous owner Decl (for a function or a namespace type).
        return zcu.semaAnonOwnerDecl(decl_index);
    }

    log.debug("semaDecl '{d}'", .{@intFromEnum(decl_index)});
    log.debug("decl name '{}'", .{(try decl.fullyQualifiedName(pt)).fmt(ip)});
    defer blk: {
        log.debug("finish decl name '{}'", .{(decl.fullyQualifiedName(pt) catch break :blk).fmt(ip)});
    }

    const old_has_tv = decl.has_tv;
    // The following values are ignored if `!old_has_tv`
    const old_ty = if (old_has_tv) decl.typeOf(zcu) else undefined;
    const old_val = decl.val;
    const old_align = decl.alignment;
    const old_linksection = decl.@"linksection";
    const old_addrspace = decl.@"addrspace";
    const old_is_inline = if (decl.getOwnedFunction(zcu)) |prev_func|
        prev_func.analysis(ip).state == .inline_only
    else
        false;

    const decl_inst = decl.zir_decl_index.unwrap().?.resolve(ip);

    const gpa = zcu.gpa;
    const zir = decl.getFileScope(zcu).zir;

    const builtin_type_target_index: InternPool.Index = ip_index: {
        const std_mod = zcu.std_mod;
        if (decl.getFileScope(zcu).mod != std_mod) break :ip_index .none;
        // We're in the std module.
        const std_file_imported = try zcu.importPkg(std_mod);
        const std_file_root_decl_index = zcu.fileRootDecl(std_file_imported.file_index);
        const std_decl = zcu.declPtr(std_file_root_decl_index.unwrap().?);
        const std_namespace = std_decl.getInnerNamespace(zcu).?;
        const builtin_str = try ip.getOrPutString(gpa, pt.tid, "builtin", .no_embedded_nulls);
        const builtin_decl = zcu.declPtr(std_namespace.decls.getKeyAdapted(builtin_str, Zcu.DeclAdapter{ .zcu = zcu }) orelse break :ip_index .none);
        const builtin_namespace = builtin_decl.getInnerNamespaceIndex(zcu).unwrap() orelse break :ip_index .none;
        if (decl.src_namespace != builtin_namespace) break :ip_index .none;
        // We're in builtin.zig. This could be a builtin we need to add to a specific InternPool index.
        for ([_][]const u8{
            "AtomicOrder",
            "AtomicRmwOp",
            "CallingConvention",
            "AddressSpace",
            "FloatMode",
            "ReduceOp",
            "CallModifier",
            "PrefetchOptions",
            "ExportOptions",
            "ExternOptions",
            "Type",
        }, [_]InternPool.Index{
            .atomic_order_type,
            .atomic_rmw_op_type,
            .calling_convention_type,
            .address_space_type,
            .float_mode_type,
            .reduce_op_type,
            .call_modifier_type,
            .prefetch_options_type,
            .export_options_type,
            .extern_options_type,
            .type_info_type,
        }) |type_name, type_ip| {
            if (decl.name.eqlSlice(type_name, ip)) break :ip_index type_ip;
        }
        break :ip_index .none;
    };

    zcu.intern_pool.removeDependenciesForDepender(gpa, InternPool.AnalUnit.wrap(.{ .decl = decl_index }));

    decl.analysis = .in_progress;

    var analysis_arena = std.heap.ArenaAllocator.init(gpa);
    defer analysis_arena.deinit();

    var comptime_err_ret_trace = std.ArrayList(Zcu.LazySrcLoc).init(gpa);
    defer comptime_err_ret_trace.deinit();

    var sema: Sema = .{
        .pt = pt,
        .gpa = gpa,
        .arena = analysis_arena.allocator(),
        .code = zir,
        .owner_decl = decl,
        .owner_decl_index = decl_index,
        .func_index = .none,
        .func_is_naked = false,
        .fn_ret_ty = Type.void,
        .fn_ret_ty_ies = null,
        .owner_func_index = .none,
        .comptime_err_ret_trace = &comptime_err_ret_trace,
        .builtin_type_target_index = builtin_type_target_index,
    };
    defer sema.deinit();

    // Every Decl (other than file root Decls, which do not have a ZIR index) has a dependency on its own source.
    try sema.declareDependency(.{ .src_hash = try ip.trackZir(
        gpa,
        decl.getFileScopeIndex(zcu),
        decl_inst,
    ) });

    var block_scope: Sema.Block = .{
        .parent = null,
        .sema = &sema,
        .namespace = decl.src_namespace,
        .instructions = .{},
        .inlining = null,
        .is_comptime = true,
        .src_base_inst = decl.zir_decl_index.unwrap().?,
        .type_name_ctx = decl.name,
    };
    defer block_scope.instructions.deinit(gpa);

    const decl_bodies = decl.zirBodies(zcu);

    const result_ref = try sema.resolveInlineBody(&block_scope, decl_bodies.value_body, decl_inst);
    // We'll do some other bits with the Sema. Clear the type target index just
    // in case they analyze any type.
    sema.builtin_type_target_index = .none;
    const align_src = block_scope.src(.{ .node_offset_var_decl_align = 0 });
    const section_src = block_scope.src(.{ .node_offset_var_decl_section = 0 });
    const address_space_src = block_scope.src(.{ .node_offset_var_decl_addrspace = 0 });
    const ty_src = block_scope.src(.{ .node_offset_var_decl_ty = 0 });
    const init_src = block_scope.src(.{ .node_offset_var_decl_init = 0 });
    const decl_val = try sema.resolveFinalDeclValue(&block_scope, init_src, result_ref);
    const decl_ty = decl_val.typeOf(zcu);

    // Note this resolves the type of the Decl, not the value; if this Decl
    // is a struct, for example, this resolves `type` (which needs no resolution),
    // not the struct itself.
    try decl_ty.resolveLayout(pt);

    if (decl.kind == .@"usingnamespace") {
        if (!decl_ty.eql(Type.type, zcu)) {
            return sema.fail(&block_scope, ty_src, "expected type, found {}", .{decl_ty.fmt(pt)});
        }
        const ty = decl_val.toType();
        if (ty.getNamespace(zcu) == null) {
            return sema.fail(&block_scope, ty_src, "type {} has no namespace", .{ty.fmt(pt)});
        }

        decl.val = ty.toValue();
        decl.alignment = .none;
        decl.@"linksection" = .none;
        decl.has_tv = true;
        decl.owns_tv = false;
        decl.analysis = .complete;

        // TODO: usingnamespace cannot currently participate in incremental compilation
        return .{
            .invalidate_decl_val = true,
            .invalidate_decl_ref = true,
        };
    }

    var queue_linker_work = true;
    var is_func = false;
    var is_inline = false;
    switch (decl_val.toIntern()) {
        .generic_poison => unreachable,
        .unreachable_value => unreachable,
        else => switch (ip.indexToKey(decl_val.toIntern())) {
            .variable => |variable| {
                decl.owns_tv = variable.decl == decl_index;
                queue_linker_work = decl.owns_tv;
            },

            .extern_func => |extern_func| {
                decl.owns_tv = extern_func.decl == decl_index;
                queue_linker_work = decl.owns_tv;
                is_func = decl.owns_tv;
            },

            .func => |func| {
                decl.owns_tv = func.owner_decl == decl_index;
                queue_linker_work = false;
                is_inline = decl.owns_tv and decl_ty.fnCallingConvention(zcu) == .Inline;
                is_func = decl.owns_tv;
            },

            else => {},
        },
    }

    decl.val = decl_val;
    // Function linksection, align, and addrspace were already set by Sema
    if (!is_func) {
        decl.alignment = blk: {
            const align_body = decl_bodies.align_body orelse break :blk .none;
            const align_ref = try sema.resolveInlineBody(&block_scope, align_body, decl_inst);
            break :blk try sema.analyzeAsAlign(&block_scope, align_src, align_ref);
        };
        decl.@"linksection" = blk: {
            const linksection_body = decl_bodies.linksection_body orelse break :blk .none;
            const linksection_ref = try sema.resolveInlineBody(&block_scope, linksection_body, decl_inst);
            const bytes = try sema.toConstString(&block_scope, section_src, linksection_ref, .{
                .needed_comptime_reason = "linksection must be comptime-known",
            });
            if (std.mem.indexOfScalar(u8, bytes, 0) != null) {
                return sema.fail(&block_scope, section_src, "linksection cannot contain null bytes", .{});
            } else if (bytes.len == 0) {
                return sema.fail(&block_scope, section_src, "linksection cannot be empty", .{});
            }
            break :blk try ip.getOrPutStringOpt(gpa, pt.tid, bytes, .no_embedded_nulls);
        };
        decl.@"addrspace" = blk: {
            const addrspace_ctx: Sema.AddressSpaceContext = switch (ip.indexToKey(decl_val.toIntern())) {
                .variable => .variable,
                .extern_func, .func => .function,
                else => .constant,
            };

            const target = zcu.getTarget();

            const addrspace_body = decl_bodies.addrspace_body orelse break :blk switch (addrspace_ctx) {
                .function => target_util.defaultAddressSpace(target, .function),
                .variable => target_util.defaultAddressSpace(target, .global_mutable),
                .constant => target_util.defaultAddressSpace(target, .global_constant),
                else => unreachable,
            };
            const addrspace_ref = try sema.resolveInlineBody(&block_scope, addrspace_body, decl_inst);
            break :blk try sema.analyzeAsAddressSpace(&block_scope, address_space_src, addrspace_ref, addrspace_ctx);
        };
    }
    decl.has_tv = true;
    decl.analysis = .complete;

    const result: Zcu.SemaDeclResult = if (old_has_tv) .{
        .invalidate_decl_val = !decl_ty.eql(old_ty, zcu) or
            !decl.val.eql(old_val, decl_ty, zcu) or
            is_inline != old_is_inline,
        .invalidate_decl_ref = !decl_ty.eql(old_ty, zcu) or
            decl.alignment != old_align or
            decl.@"linksection" != old_linksection or
            decl.@"addrspace" != old_addrspace or
            is_inline != old_is_inline,
    } else .{
        .invalidate_decl_val = true,
        .invalidate_decl_ref = true,
    };

    const has_runtime_bits = queue_linker_work and (is_func or try sema.typeHasRuntimeBits(decl_ty));
    if (has_runtime_bits) {
        // Needed for codegen_decl which will call updateDecl and then the
        // codegen backend wants full access to the Decl Type.
        try decl_ty.resolveFully(pt);

        try zcu.comp.work_queue.writeItem(.{ .codegen_decl = decl_index });

        if (result.invalidate_decl_ref and zcu.emit_h != null) {
            try zcu.comp.work_queue.writeItem(.{ .emit_h_decl = decl_index });
        }
    }

    if (decl.is_exported) {
        const export_src = block_scope.src(.{ .token_offset = @intFromBool(decl.is_pub) });
        if (is_inline) return sema.fail(&block_scope, export_src, "export of inline function", .{});
        // The scope needs to have the decl in it.
        try sema.analyzeExport(&block_scope, export_src, .{ .name = decl.name }, decl_index);
    }

    try sema.flushExports();

    return result;
}

pub fn embedFile(
    pt: Zcu.PerThread,
    cur_file: *Zcu.File,
    import_string: []const u8,
    src_loc: Zcu.LazySrcLoc,
) !InternPool.Index {
    const mod = pt.zcu;
    const gpa = mod.gpa;

    if (cur_file.mod.deps.get(import_string)) |pkg| {
        const resolved_path = try std.fs.path.resolve(gpa, &.{
            pkg.root.root_dir.path orelse ".",
            pkg.root.sub_path,
            pkg.root_src_path,
        });
        var keep_resolved_path = false;
        defer if (!keep_resolved_path) gpa.free(resolved_path);

        const gop = try mod.embed_table.getOrPut(gpa, resolved_path);
        errdefer {
            assert(std.mem.eql(u8, mod.embed_table.pop().key, resolved_path));
            keep_resolved_path = false;
        }
        if (gop.found_existing) return gop.value_ptr.*.val;
        keep_resolved_path = true;

        const sub_file_path = try gpa.dupe(u8, pkg.root_src_path);
        errdefer gpa.free(sub_file_path);

        return pt.newEmbedFile(pkg, sub_file_path, resolved_path, gop.value_ptr, src_loc);
    }

    // The resolved path is used as the key in the table, to detect if a file
    // refers to the same as another, despite different relative paths.
    const resolved_path = try std.fs.path.resolve(gpa, &.{
        cur_file.mod.root.root_dir.path orelse ".",
        cur_file.mod.root.sub_path,
        cur_file.sub_file_path,
        "..",
        import_string,
    });

    var keep_resolved_path = false;
    defer if (!keep_resolved_path) gpa.free(resolved_path);

    const gop = try mod.embed_table.getOrPut(gpa, resolved_path);
    errdefer {
        assert(std.mem.eql(u8, mod.embed_table.pop().key, resolved_path));
        keep_resolved_path = false;
    }
    if (gop.found_existing) return gop.value_ptr.*.val;
    keep_resolved_path = true;

    const resolved_root_path = try std.fs.path.resolve(gpa, &.{
        cur_file.mod.root.root_dir.path orelse ".",
        cur_file.mod.root.sub_path,
    });
    defer gpa.free(resolved_root_path);

    const sub_file_path = p: {
        const relative = try std.fs.path.relative(gpa, resolved_root_path, resolved_path);
        errdefer gpa.free(relative);

        if (!isUpDir(relative) and !std.fs.path.isAbsolute(relative)) {
            break :p relative;
        }
        return error.ImportOutsideModulePath;
    };
    defer gpa.free(sub_file_path);

    return pt.newEmbedFile(cur_file.mod, sub_file_path, resolved_path, gop.value_ptr, src_loc);
}

/// Finalize the creation of an anon decl.
pub fn finalizeAnonDecl(pt: Zcu.PerThread, decl_index: Zcu.Decl.Index) Allocator.Error!void {
    if (pt.zcu.declPtr(decl_index).typeOf(pt.zcu).isFnOrHasRuntimeBits(pt)) {
        try pt.zcu.comp.work_queue.writeItem(.{ .codegen_decl = decl_index });
    }
}

/// https://github.com/ziglang/zig/issues/14307
fn newEmbedFile(
    pt: Zcu.PerThread,
    pkg: *Module,
    sub_file_path: []const u8,
    resolved_path: []const u8,
    result: **Zcu.EmbedFile,
    src_loc: Zcu.LazySrcLoc,
) !InternPool.Index {
    const mod = pt.zcu;
    const gpa = mod.gpa;
    const ip = &mod.intern_pool;

    const new_file = try gpa.create(Zcu.EmbedFile);
    errdefer gpa.destroy(new_file);

    var file = try pkg.root.openFile(sub_file_path, .{});
    defer file.close();

    const actual_stat = try file.stat();
    const stat: Cache.File.Stat = .{
        .size = actual_stat.size,
        .inode = actual_stat.inode,
        .mtime = actual_stat.mtime,
    };
    const size = std.math.cast(usize, actual_stat.size) orelse return error.Overflow;

    const strings = ip.getLocal(pt.tid).getMutableStrings(gpa);
    const bytes = try strings.addManyAsSlice(try std.math.add(usize, size, 1));
    const actual_read = try file.readAll(bytes[0][0..size]);
    if (actual_read != size) return error.UnexpectedEndOfFile;
    bytes[0][size] = 0;

    const comp = mod.comp;
    switch (comp.cache_use) {
        .whole => |whole| if (whole.cache_manifest) |man| {
            const copied_resolved_path = try gpa.dupe(u8, resolved_path);
            errdefer gpa.free(copied_resolved_path);
            whole.cache_manifest_mutex.lock();
            defer whole.cache_manifest_mutex.unlock();
            try man.addFilePostContents(copied_resolved_path, bytes[0][0..size], stat);
        },
        .incremental => {},
    }

    const array_ty = try pt.intern(.{ .array_type = .{
        .len = size,
        .sentinel = .zero_u8,
        .child = .u8_type,
    } });
    const array_val = try pt.intern(.{ .aggregate = .{
        .ty = array_ty,
        .storage = .{ .bytes = try ip.getOrPutTrailingString(gpa, pt.tid, @intCast(bytes[0].len), .maybe_embedded_nulls) },
    } });

    const ptr_ty = (try pt.ptrType(.{
        .child = array_ty,
        .flags = .{
            .alignment = .none,
            .is_const = true,
            .address_space = .generic,
        },
    })).toIntern();
    const ptr_val = try pt.intern(.{ .ptr = .{
        .ty = ptr_ty,
        .base_addr = .{ .anon_decl = .{
            .val = array_val,
            .orig_ty = ptr_ty,
        } },
        .byte_offset = 0,
    } });

    result.* = new_file;
    new_file.* = .{
        .sub_file_path = try ip.getOrPutString(gpa, pt.tid, sub_file_path, .no_embedded_nulls),
        .owner = pkg,
        .stat = stat,
        .val = ptr_val,
        .src_loc = src_loc,
    };
    return ptr_val;
}

pub fn scanNamespace(
    pt: Zcu.PerThread,
    namespace_index: Zcu.Namespace.Index,
    decls: []const Zir.Inst.Index,
    parent_decl: *Zcu.Decl,
) Allocator.Error!void {
    const tracy = trace(@src());
    defer tracy.end();

    const zcu = pt.zcu;
    const gpa = zcu.gpa;
    const namespace = zcu.namespacePtr(namespace_index);

    // For incremental updates, `scanDecl` wants to look up existing decls by their ZIR index rather
    // than their name. We'll build an efficient mapping now, then discard the current `decls`.
    var existing_by_inst: std.AutoHashMapUnmanaged(InternPool.TrackedInst.Index, Zcu.Decl.Index) = .{};
    defer existing_by_inst.deinit(gpa);

    try existing_by_inst.ensureTotalCapacity(gpa, @intCast(namespace.decls.count()));

    for (namespace.decls.keys()) |decl_index| {
        const decl = zcu.declPtr(decl_index);
        existing_by_inst.putAssumeCapacityNoClobber(decl.zir_decl_index.unwrap().?, decl_index);
    }

    var seen_decls: std.AutoHashMapUnmanaged(InternPool.NullTerminatedString, void) = .{};
    defer seen_decls.deinit(gpa);

    try zcu.comp.work_queue.ensureUnusedCapacity(decls.len);

    namespace.decls.clearRetainingCapacity();
    try namespace.decls.ensureTotalCapacity(gpa, decls.len);

    namespace.usingnamespace_set.clearRetainingCapacity();

    var scan_decl_iter: ScanDeclIter = .{
        .pt = pt,
        .namespace_index = namespace_index,
        .parent_decl = parent_decl,
        .seen_decls = &seen_decls,
        .existing_by_inst = &existing_by_inst,
        .pass = .named,
    };
    for (decls) |decl_inst| {
        try scan_decl_iter.scanDecl(decl_inst);
    }
    scan_decl_iter.pass = .unnamed;
    for (decls) |decl_inst| {
        try scan_decl_iter.scanDecl(decl_inst);
    }

    if (seen_decls.count() != namespace.decls.count()) {
        // Do a pass over the namespace contents and remove any decls from the last update
        // which were removed in this one.
        var i: usize = 0;
        while (i < namespace.decls.count()) {
            const decl_index = namespace.decls.keys()[i];
            const decl = zcu.declPtr(decl_index);
            if (!seen_decls.contains(decl.name)) {
                // We must preserve namespace ordering for @typeInfo.
                namespace.decls.orderedRemoveAt(i);
                i -= 1;
            }
        }
    }
}

const ScanDeclIter = struct {
    pt: Zcu.PerThread,
    namespace_index: Zcu.Namespace.Index,
    parent_decl: *Zcu.Decl,
    seen_decls: *std.AutoHashMapUnmanaged(InternPool.NullTerminatedString, void),
    existing_by_inst: *const std.AutoHashMapUnmanaged(InternPool.TrackedInst.Index, Zcu.Decl.Index),
    /// Decl scanning is run in two passes, so that we can detect when a generated
    /// name would clash with an explicit name and use a different one.
    pass: enum { named, unnamed },
    usingnamespace_index: usize = 0,
    comptime_index: usize = 0,
    unnamed_test_index: usize = 0,

    fn avoidNameConflict(iter: *ScanDeclIter, comptime fmt: []const u8, args: anytype) !InternPool.NullTerminatedString {
        const pt = iter.pt;
        const gpa = pt.zcu.gpa;
        const ip = &pt.zcu.intern_pool;
        var name = try ip.getOrPutStringFmt(gpa, pt.tid, fmt, args, .no_embedded_nulls);
        var gop = try iter.seen_decls.getOrPut(gpa, name);
        var next_suffix: u32 = 0;
        while (gop.found_existing) {
            name = try ip.getOrPutStringFmt(gpa, pt.tid, "{}_{d}", .{ name.fmt(ip), next_suffix }, .no_embedded_nulls);
            gop = try iter.seen_decls.getOrPut(gpa, name);
            next_suffix += 1;
        }
        return name;
    }

    fn scanDecl(iter: *ScanDeclIter, decl_inst: Zir.Inst.Index) Allocator.Error!void {
        const tracy = trace(@src());
        defer tracy.end();

        const pt = iter.pt;
        const zcu = pt.zcu;
        const namespace_index = iter.namespace_index;
        const namespace = zcu.namespacePtr(namespace_index);
        const gpa = zcu.gpa;
        const zir = namespace.fileScope(zcu).zir;
        const ip = &zcu.intern_pool;

        const inst_data = zir.instructions.items(.data)[@intFromEnum(decl_inst)].declaration;
        const extra = zir.extraData(Zir.Inst.Declaration, inst_data.payload_index);
        const declaration = extra.data;

        // Every Decl needs a name.
        const decl_name: InternPool.NullTerminatedString, const kind: Zcu.Decl.Kind, const is_named_test: bool = switch (declaration.name) {
            .@"comptime" => info: {
                if (iter.pass != .unnamed) return;
                const i = iter.comptime_index;
                iter.comptime_index += 1;
                break :info .{
                    try iter.avoidNameConflict("comptime_{d}", .{i}),
                    .@"comptime",
                    false,
                };
            },
            .@"usingnamespace" => info: {
                // TODO: this isn't right! These should be considered unnamed. Name conflicts can happen here.
                // The problem is, we need to preserve the decl ordering for `@typeInfo`.
                // I'm not bothering to fix this now, since some upcoming changes will change this code significantly anyway.
                if (iter.pass != .named) return;
                const i = iter.usingnamespace_index;
                iter.usingnamespace_index += 1;
                break :info .{
                    try iter.avoidNameConflict("usingnamespace_{d}", .{i}),
                    .@"usingnamespace",
                    false,
                };
            },
            .unnamed_test => info: {
                if (iter.pass != .unnamed) return;
                const i = iter.unnamed_test_index;
                iter.unnamed_test_index += 1;
                break :info .{
                    try iter.avoidNameConflict("test_{d}", .{i}),
                    .@"test",
                    false,
                };
            },
            .decltest => info: {
                // We consider these to be unnamed since the decl name can be adjusted to avoid conflicts if necessary.
                if (iter.pass != .unnamed) return;
                assert(declaration.flags.has_doc_comment);
                const name = zir.nullTerminatedString(@enumFromInt(zir.extra[extra.end]));
                break :info .{
                    try iter.avoidNameConflict("decltest.{s}", .{name}),
                    .@"test",
                    true,
                };
            },
            _ => if (declaration.name.isNamedTest(zir)) info: {
                // We consider these to be unnamed since the decl name can be adjusted to avoid conflicts if necessary.
                if (iter.pass != .unnamed) return;
                break :info .{
                    try iter.avoidNameConflict("test.{s}", .{zir.nullTerminatedString(declaration.name.toString(zir).?)}),
                    .@"test",
                    true,
                };
            } else info: {
                if (iter.pass != .named) return;
                const name = try ip.getOrPutString(
                    gpa,
                    pt.tid,
                    zir.nullTerminatedString(declaration.name.toString(zir).?),
                    .no_embedded_nulls,
                );
                try iter.seen_decls.putNoClobber(gpa, name, {});
                break :info .{
                    name,
                    .named,
                    false,
                };
            },
        };

        switch (kind) {
            .@"usingnamespace" => try namespace.usingnamespace_set.ensureUnusedCapacity(gpa, 1),
            .@"test" => try zcu.test_functions.ensureUnusedCapacity(gpa, 1),
            else => {},
        }

        const parent_file_scope_index = iter.parent_decl.getFileScopeIndex(zcu);
        const tracked_inst = try ip.trackZir(gpa, parent_file_scope_index, decl_inst);

        // We create a Decl for it regardless of analysis status.

        const prev_exported, const decl_index = if (iter.existing_by_inst.get(tracked_inst)) |decl_index| decl_index: {
            // We need only update this existing Decl.
            const decl = zcu.declPtr(decl_index);
            const was_exported = decl.is_exported;
            assert(decl.kind == kind); // ZIR tracking should preserve this
            decl.name = decl_name;
            decl.is_pub = declaration.flags.is_pub;
            decl.is_exported = declaration.flags.is_export;
            break :decl_index .{ was_exported, decl_index };
        } else decl_index: {
            // Create and set up a new Decl.
            const new_decl_index = try zcu.allocateNewDecl(namespace_index);
            const new_decl = zcu.declPtr(new_decl_index);
            new_decl.kind = kind;
            new_decl.name = decl_name;
            new_decl.is_pub = declaration.flags.is_pub;
            new_decl.is_exported = declaration.flags.is_export;
            new_decl.zir_decl_index = tracked_inst.toOptional();
            break :decl_index .{ false, new_decl_index };
        };

        const decl = zcu.declPtr(decl_index);

        namespace.decls.putAssumeCapacityNoClobberContext(decl_index, {}, .{ .zcu = zcu });

        const comp = zcu.comp;
        const decl_mod = namespace.fileScope(zcu).mod;
        const want_analysis = declaration.flags.is_export or switch (kind) {
            .anon => unreachable,
            .@"comptime" => true,
            .@"usingnamespace" => a: {
                namespace.usingnamespace_set.putAssumeCapacityNoClobber(decl_index, declaration.flags.is_pub);
                break :a true;
            },
            .named => false,
            .@"test" => a: {
                if (!comp.config.is_test) break :a false;
                if (decl_mod != zcu.main_mod) break :a false;
                if (is_named_test and comp.test_filters.len > 0) {
                    const decl_fqn = try namespace.fullyQualifiedName(pt, decl_name);
                    const decl_fqn_slice = decl_fqn.toSlice(ip);
                    for (comp.test_filters) |test_filter| {
                        if (std.mem.indexOf(u8, decl_fqn_slice, test_filter)) |_| break;
                    } else break :a false;
                }
                zcu.test_functions.putAssumeCapacity(decl_index, {}); // may clobber on incremental update
                break :a true;
            },
        };

        if (want_analysis) {
            // We will not queue analysis if the decl has been analyzed on a previous update and
            // `is_export` is unchanged. In this case, the incremental update mechanism will handle
            // re-analysis for us if necessary.
            if (prev_exported != declaration.flags.is_export or decl.analysis == .unreferenced) {
                log.debug("scanDecl queue analyze_decl file='{s}' decl_name='{}' decl_index={d}", .{
                    namespace.fileScope(zcu).sub_file_path, decl_name.fmt(ip), decl_index,
                });
                comp.work_queue.writeItemAssumeCapacity(.{ .analyze_decl = decl_index });
            }
        }

        if (decl.getOwnedFunction(zcu) != null) {
            // TODO this logic is insufficient; namespaces we don't re-scan may still require
            // updated line numbers. Look into this!
            // TODO Look into detecting when this would be unnecessary by storing enough state
            // in `Decl` to notice that the line number did not change.
            comp.work_queue.writeItemAssumeCapacity(.{ .update_line_number = decl_index });
        }
    }
};

pub fn analyzeFnBody(pt: Zcu.PerThread, func_index: InternPool.Index, arena: Allocator) Zcu.SemaError!Air {
    const tracy = trace(@src());
    defer tracy.end();

    const mod = pt.zcu;
    const gpa = mod.gpa;
    const ip = &mod.intern_pool;
    const func = mod.funcInfo(func_index);
    const decl_index = func.owner_decl;
    const decl = mod.declPtr(decl_index);

    log.debug("func name '{}'", .{(try decl.fullyQualifiedName(pt)).fmt(ip)});
    defer blk: {
        log.debug("finish func name '{}'", .{(decl.fullyQualifiedName(pt) catch break :blk).fmt(ip)});
    }

    const decl_prog_node = mod.sema_prog_node.start((try decl.fullyQualifiedName(pt)).toSlice(ip), 0);
    defer decl_prog_node.end();

    mod.intern_pool.removeDependenciesForDepender(gpa, InternPool.AnalUnit.wrap(.{ .func = func_index }));

    var comptime_err_ret_trace = std.ArrayList(Zcu.LazySrcLoc).init(gpa);
    defer comptime_err_ret_trace.deinit();

    // In the case of a generic function instance, this is the type of the
    // instance, which has comptime parameters elided. In other words, it is
    // the runtime-known parameters only, not to be confused with the
    // generic_owner function type, which potentially has more parameters,
    // including comptime parameters.
    const fn_ty = decl.typeOf(mod);
    const fn_ty_info = mod.typeToFunc(fn_ty).?;

    var sema: Sema = .{
        .pt = pt,
        .gpa = gpa,
        .arena = arena,
        .code = decl.getFileScope(mod).zir,
        .owner_decl = decl,
        .owner_decl_index = decl_index,
        .func_index = func_index,
        .func_is_naked = fn_ty_info.cc == .Naked,
        .fn_ret_ty = Type.fromInterned(fn_ty_info.return_type),
        .fn_ret_ty_ies = null,
        .owner_func_index = func_index,
        .branch_quota = @max(func.branchQuota(ip).*, Sema.default_branch_quota),
        .comptime_err_ret_trace = &comptime_err_ret_trace,
    };
    defer sema.deinit();

    // Every runtime function has a dependency on the source of the Decl it originates from.
    // It also depends on the value of its owner Decl.
    try sema.declareDependency(.{ .src_hash = decl.zir_decl_index.unwrap().? });
    try sema.declareDependency(.{ .decl_val = decl_index });

    if (func.analysis(ip).inferred_error_set) {
        const ies = try arena.create(Sema.InferredErrorSet);
        ies.* = .{ .func = func_index };
        sema.fn_ret_ty_ies = ies;
    }

    // reset in case calls to errorable functions are removed.
    func.analysis(ip).calls_or_awaits_errorable_fn = false;

    // First few indexes of extra are reserved and set at the end.
    const reserved_count = @typeInfo(Air.ExtraIndex).Enum.fields.len;
    try sema.air_extra.ensureTotalCapacity(gpa, reserved_count);
    sema.air_extra.items.len += reserved_count;

    var inner_block: Sema.Block = .{
        .parent = null,
        .sema = &sema,
        .namespace = decl.src_namespace,
        .instructions = .{},
        .inlining = null,
        .is_comptime = false,
        .src_base_inst = inst: {
            const owner_info = if (func.generic_owner == .none)
                func
            else
                mod.funcInfo(func.generic_owner);
            const orig_decl = mod.declPtr(owner_info.owner_decl);
            break :inst orig_decl.zir_decl_index.unwrap().?;
        },
        .type_name_ctx = decl.name,
    };
    defer inner_block.instructions.deinit(gpa);

    const fn_info = sema.code.getFnInfo(func.zirBodyInst(ip).resolve(ip));

    // Here we are performing "runtime semantic analysis" for a function body, which means
    // we must map the parameter ZIR instructions to `arg` AIR instructions.
    // AIR requires the `arg` parameters to be the first N instructions.
    // This could be a generic function instantiation, however, in which case we need to
    // map the comptime parameters to constant values and only emit arg AIR instructions
    // for the runtime ones.
    const runtime_params_len = fn_ty_info.param_types.len;
    try inner_block.instructions.ensureTotalCapacityPrecise(gpa, runtime_params_len);
    try sema.air_instructions.ensureUnusedCapacity(gpa, fn_info.total_params_len);
    try sema.inst_map.ensureSpaceForInstructions(gpa, fn_info.param_body);

    // In the case of a generic function instance, pre-populate all the comptime args.
    if (func.comptime_args.len != 0) {
        for (
            fn_info.param_body[0..func.comptime_args.len],
            func.comptime_args.get(ip),
        ) |inst, comptime_arg| {
            if (comptime_arg == .none) continue;
            sema.inst_map.putAssumeCapacityNoClobber(inst, Air.internedToRef(comptime_arg));
        }
    }

    const src_params_len = if (func.comptime_args.len != 0)
        func.comptime_args.len
    else
        runtime_params_len;

    var runtime_param_index: usize = 0;
    for (fn_info.param_body[0..src_params_len], 0..) |inst, src_param_index| {
        const gop = sema.inst_map.getOrPutAssumeCapacity(inst);
        if (gop.found_existing) continue; // provided above by comptime arg

        const param_ty = fn_ty_info.param_types.get(ip)[runtime_param_index];
        runtime_param_index += 1;

        const opt_opv = sema.typeHasOnePossibleValue(Type.fromInterned(param_ty)) catch |err| switch (err) {
            error.GenericPoison => unreachable,
            error.ComptimeReturn => unreachable,
            error.ComptimeBreak => unreachable,
            else => |e| return e,
        };
        if (opt_opv) |opv| {
            gop.value_ptr.* = Air.internedToRef(opv.toIntern());
            continue;
        }
        const arg_index: Air.Inst.Index = @enumFromInt(sema.air_instructions.len);
        gop.value_ptr.* = arg_index.toRef();
        inner_block.instructions.appendAssumeCapacity(arg_index);
        sema.air_instructions.appendAssumeCapacity(.{
            .tag = .arg,
            .data = .{ .arg = .{
                .ty = Air.internedToRef(param_ty),
                .src_index = @intCast(src_param_index),
            } },
        });
    }

    func.analysis(ip).state = .in_progress;

    const last_arg_index = inner_block.instructions.items.len;

    // Save the error trace as our first action in the function.
    // If this is unnecessary after all, Liveness will clean it up for us.
    const error_return_trace_index = try sema.analyzeSaveErrRetIndex(&inner_block);
    sema.error_return_trace_index_on_fn_entry = error_return_trace_index;
    inner_block.error_return_trace_index = error_return_trace_index;

    sema.analyzeFnBody(&inner_block, fn_info.body) catch |err| switch (err) {
        // TODO make these unreachable instead of @panic
        error.GenericPoison => @panic("zig compiler bug: GenericPoison"),
        error.ComptimeReturn => @panic("zig compiler bug: ComptimeReturn"),
        else => |e| return e,
    };

    for (sema.unresolved_inferred_allocs.keys()) |ptr_inst| {
        // The lack of a resolve_inferred_alloc means that this instruction
        // is unused so it just has to be a no-op.
        sema.air_instructions.set(@intFromEnum(ptr_inst), .{
            .tag = .alloc,
            .data = .{ .ty = Type.single_const_pointer_to_comptime_int },
        });
    }

    // If we don't get an error return trace from a caller, create our own.
    if (func.analysis(ip).calls_or_awaits_errorable_fn and
        mod.comp.config.any_error_tracing and
        !sema.fn_ret_ty.isError(mod))
    {
        sema.setupErrorReturnTrace(&inner_block, last_arg_index) catch |err| switch (err) {
            // TODO make these unreachable instead of @panic
            error.GenericPoison => @panic("zig compiler bug: GenericPoison"),
            error.ComptimeReturn => @panic("zig compiler bug: ComptimeReturn"),
            error.ComptimeBreak => @panic("zig compiler bug: ComptimeBreak"),
            else => |e| return e,
        };
    }

    // Copy the block into place and mark that as the main block.
    try sema.air_extra.ensureUnusedCapacity(gpa, @typeInfo(Air.Block).Struct.fields.len +
        inner_block.instructions.items.len);
    const main_block_index = sema.addExtraAssumeCapacity(Air.Block{
        .body_len = @intCast(inner_block.instructions.items.len),
    });
    sema.air_extra.appendSliceAssumeCapacity(@ptrCast(inner_block.instructions.items));
    sema.air_extra.items[@intFromEnum(Air.ExtraIndex.main_block)] = main_block_index;

    // Resolving inferred error sets is done *before* setting the function
    // state to success, so that "unable to resolve inferred error set" errors
    // can be emitted here.
    if (sema.fn_ret_ty_ies) |ies| {
        sema.resolveInferredErrorSetPtr(&inner_block, .{
            .base_node_inst = inner_block.src_base_inst,
            .offset = Zcu.LazySrcLoc.Offset.nodeOffset(0),
        }, ies) catch |err| switch (err) {
            error.GenericPoison => unreachable,
            error.ComptimeReturn => unreachable,
            error.ComptimeBreak => unreachable,
            error.AnalysisFail => {
                // In this case our function depends on a type that had a compile error.
                // We should not try to lower this function.
                decl.analysis = .dependency_failure;
                return error.AnalysisFail;
            },
            else => |e| return e,
        };
        assert(ies.resolved != .none);
        ip.funcIesResolved(func_index).* = ies.resolved;
    }

    func.analysis(ip).state = .success;

    // Finally we must resolve the return type and parameter types so that backends
    // have full access to type information.
    // Crucially, this happens *after* we set the function state to success above,
    // so that dependencies on the function body will now be satisfied rather than
    // result in circular dependency errors.
    sema.resolveFnTypes(fn_ty) catch |err| switch (err) {
        error.GenericPoison => unreachable,
        error.ComptimeReturn => unreachable,
        error.ComptimeBreak => unreachable,
        error.AnalysisFail => {
            // In this case our function depends on a type that had a compile error.
            // We should not try to lower this function.
            decl.analysis = .dependency_failure;
            return error.AnalysisFail;
        },
        else => |e| return e,
    };

    try sema.flushExports();

    return .{
        .instructions = sema.air_instructions.toOwnedSlice(),
        .extra = try sema.air_extra.toOwnedSlice(gpa),
    };
}

fn lockAndClearFileCompileError(pt: Zcu.PerThread, file: *Zcu.File) void {
    switch (file.status) {
        .success_zir, .retryable_failure => {},
        .never_loaded, .parse_failure, .astgen_failure => {
            pt.zcu.comp.mutex.lock();
            defer pt.zcu.comp.mutex.unlock();
            if (pt.zcu.failed_files.fetchSwapRemove(file)) |kv| {
                if (kv.value) |msg| msg.destroy(pt.zcu.gpa); // Delete previous error message.
            }
        },
    }
}

/// Called from `Compilation.update`, after everything is done, just before
/// reporting compile errors. In this function we emit exported symbol collision
/// errors and communicate exported symbols to the linker backend.
pub fn processExports(pt: Zcu.PerThread) !void {
    const zcu = pt.zcu;
    const gpa = zcu.gpa;

    // First, construct a mapping of every exported value and Decl to the indices of all its different exports.
    var decl_exports: std.AutoArrayHashMapUnmanaged(Zcu.Decl.Index, std.ArrayListUnmanaged(u32)) = .{};
    var value_exports: std.AutoArrayHashMapUnmanaged(InternPool.Index, std.ArrayListUnmanaged(u32)) = .{};
    defer {
        for (decl_exports.values()) |*exports| {
            exports.deinit(gpa);
        }
        decl_exports.deinit(gpa);
        for (value_exports.values()) |*exports| {
            exports.deinit(gpa);
        }
        value_exports.deinit(gpa);
    }

    // We note as a heuristic:
    // * It is rare to export a value.
    // * It is rare for one Decl to be exported multiple times.
    // So, this ensureTotalCapacity serves as a reasonable (albeit very approximate) optimization.
    try decl_exports.ensureTotalCapacity(gpa, zcu.single_exports.count() + zcu.multi_exports.count());

    for (zcu.single_exports.values()) |export_idx| {
        const exp = zcu.all_exports.items[export_idx];
        const value_ptr, const found_existing = switch (exp.exported) {
            .decl_index => |i| gop: {
                const gop = try decl_exports.getOrPut(gpa, i);
                break :gop .{ gop.value_ptr, gop.found_existing };
            },
            .value => |i| gop: {
                const gop = try value_exports.getOrPut(gpa, i);
                break :gop .{ gop.value_ptr, gop.found_existing };
            },
        };
        if (!found_existing) value_ptr.* = .{};
        try value_ptr.append(gpa, export_idx);
    }

    for (zcu.multi_exports.values()) |info| {
        for (zcu.all_exports.items[info.index..][0..info.len], info.index..) |exp, export_idx| {
            const value_ptr, const found_existing = switch (exp.exported) {
                .decl_index => |i| gop: {
                    const gop = try decl_exports.getOrPut(gpa, i);
                    break :gop .{ gop.value_ptr, gop.found_existing };
                },
                .value => |i| gop: {
                    const gop = try value_exports.getOrPut(gpa, i);
                    break :gop .{ gop.value_ptr, gop.found_existing };
                },
            };
            if (!found_existing) value_ptr.* = .{};
            try value_ptr.append(gpa, @intCast(export_idx));
        }
    }

    // Map symbol names to `Export` for name collision detection.
    var symbol_exports: SymbolExports = .{};
    defer symbol_exports.deinit(gpa);

    for (decl_exports.keys(), decl_exports.values()) |exported_decl, exports_list| {
        const exported: Zcu.Exported = .{ .decl_index = exported_decl };
        try pt.processExportsInner(&symbol_exports, exported, exports_list.items);
    }

    for (value_exports.keys(), value_exports.values()) |exported_value, exports_list| {
        const exported: Zcu.Exported = .{ .value = exported_value };
        try pt.processExportsInner(&symbol_exports, exported, exports_list.items);
    }
}

const SymbolExports = std.AutoArrayHashMapUnmanaged(InternPool.NullTerminatedString, u32);

fn processExportsInner(
    pt: Zcu.PerThread,
    symbol_exports: *SymbolExports,
    exported: Zcu.Exported,
    export_indices: []const u32,
) error{OutOfMemory}!void {
    const zcu = pt.zcu;
    const gpa = zcu.gpa;

    for (export_indices) |export_idx| {
        const new_export = &zcu.all_exports.items[export_idx];
        const gop = try symbol_exports.getOrPut(gpa, new_export.opts.name);
        if (gop.found_existing) {
            new_export.status = .failed_retryable;
            try zcu.failed_exports.ensureUnusedCapacity(gpa, 1);
            const msg = try Zcu.ErrorMsg.create(gpa, new_export.src, "exported symbol collision: {}", .{
                new_export.opts.name.fmt(&zcu.intern_pool),
            });
            errdefer msg.destroy(gpa);
            const other_export = zcu.all_exports.items[gop.value_ptr.*];
            try zcu.errNote(other_export.src, msg, "other symbol here", .{});
            zcu.failed_exports.putAssumeCapacityNoClobber(export_idx, msg);
            new_export.status = .failed;
        } else {
            gop.value_ptr.* = export_idx;
        }
    }
    if (zcu.comp.bin_file) |lf| {
        try zcu.handleUpdateExports(export_indices, lf.updateExports(pt, exported, export_indices));
    } else if (zcu.llvm_object) |llvm_object| {
        if (build_options.only_c) unreachable;
        try zcu.handleUpdateExports(export_indices, llvm_object.updateExports(pt, exported, export_indices));
    }
}

pub fn populateTestFunctions(
    pt: Zcu.PerThread,
    main_progress_node: std.Progress.Node,
) !void {
    const zcu = pt.zcu;
    const gpa = zcu.gpa;
    const ip = &zcu.intern_pool;
    const builtin_mod = zcu.root_mod.getBuiltinDependency();
    const builtin_file_index = (zcu.importPkg(builtin_mod) catch unreachable).file_index;
    const root_decl_index = zcu.fileRootDecl(builtin_file_index);
    const root_decl = zcu.declPtr(root_decl_index.unwrap().?);
    const builtin_namespace = zcu.namespacePtr(root_decl.src_namespace);
    const test_functions_str = try ip.getOrPutString(gpa, pt.tid, "test_functions", .no_embedded_nulls);
    const decl_index = builtin_namespace.decls.getKeyAdapted(
        test_functions_str,
        Zcu.DeclAdapter{ .zcu = zcu },
    ).?;
    {
        // We have to call `ensureDeclAnalyzed` here in case `builtin.test_functions`
        // was not referenced by start code.
        zcu.sema_prog_node = main_progress_node.start("Semantic Analysis", 0);
        defer {
            zcu.sema_prog_node.end();
            zcu.sema_prog_node = undefined;
        }
        try pt.ensureDeclAnalyzed(decl_index);
    }

    const decl = zcu.declPtr(decl_index);
    const test_fn_ty = decl.typeOf(zcu).slicePtrFieldType(zcu).childType(zcu);

    const array_anon_decl: InternPool.Key.Ptr.BaseAddr.AnonDecl = array: {
        // Add zcu.test_functions to an array decl then make the test_functions
        // decl reference it as a slice.
        const test_fn_vals = try gpa.alloc(InternPool.Index, zcu.test_functions.count());
        defer gpa.free(test_fn_vals);

        for (test_fn_vals, zcu.test_functions.keys()) |*test_fn_val, test_decl_index| {
            const test_decl = zcu.declPtr(test_decl_index);
            const test_decl_name = try test_decl.fullyQualifiedName(pt);
            const test_decl_name_len = test_decl_name.length(ip);
            const test_name_anon_decl: InternPool.Key.Ptr.BaseAddr.AnonDecl = n: {
                const test_name_ty = try pt.arrayType(.{
                    .len = test_decl_name_len,
                    .child = .u8_type,
                });
                const test_name_val = try pt.intern(.{ .aggregate = .{
                    .ty = test_name_ty.toIntern(),
                    .storage = .{ .bytes = test_decl_name.toString() },
                } });
                break :n .{
                    .orig_ty = (try pt.singleConstPtrType(test_name_ty)).toIntern(),
                    .val = test_name_val,
                };
            };

            const test_fn_fields = .{
                // name
                try pt.intern(.{ .slice = .{
                    .ty = .slice_const_u8_type,
                    .ptr = try pt.intern(.{ .ptr = .{
                        .ty = .manyptr_const_u8_type,
                        .base_addr = .{ .anon_decl = test_name_anon_decl },
                        .byte_offset = 0,
                    } }),
                    .len = try pt.intern(.{ .int = .{
                        .ty = .usize_type,
                        .storage = .{ .u64 = test_decl_name_len },
                    } }),
                } }),
                // func
                try pt.intern(.{ .ptr = .{
                    .ty = try pt.intern(.{ .ptr_type = .{
                        .child = test_decl.typeOf(zcu).toIntern(),
                        .flags = .{
                            .is_const = true,
                        },
                    } }),
                    .base_addr = .{ .decl = test_decl_index },
                    .byte_offset = 0,
                } }),
            };
            test_fn_val.* = try pt.intern(.{ .aggregate = .{
                .ty = test_fn_ty.toIntern(),
                .storage = .{ .elems = &test_fn_fields },
            } });
        }

        const array_ty = try pt.arrayType(.{
            .len = test_fn_vals.len,
            .child = test_fn_ty.toIntern(),
            .sentinel = .none,
        });
        const array_val = try pt.intern(.{ .aggregate = .{
            .ty = array_ty.toIntern(),
            .storage = .{ .elems = test_fn_vals },
        } });
        break :array .{
            .orig_ty = (try pt.singleConstPtrType(array_ty)).toIntern(),
            .val = array_val,
        };
    };

    {
        const new_ty = try pt.ptrType(.{
            .child = test_fn_ty.toIntern(),
            .flags = .{
                .is_const = true,
                .size = .Slice,
            },
        });
        const new_val = decl.val;
        const new_init = try pt.intern(.{ .slice = .{
            .ty = new_ty.toIntern(),
            .ptr = try pt.intern(.{ .ptr = .{
                .ty = new_ty.slicePtrFieldType(zcu).toIntern(),
                .base_addr = .{ .anon_decl = array_anon_decl },
                .byte_offset = 0,
            } }),
            .len = (try pt.intValue(Type.usize, zcu.test_functions.count())).toIntern(),
        } });
        ip.mutateVarInit(decl.val.toIntern(), new_init);

        // Since we are replacing the Decl's value we must perform cleanup on the
        // previous value.
        decl.val = new_val;
        decl.has_tv = true;
    }
    {
        zcu.codegen_prog_node = main_progress_node.start("Code Generation", 0);
        defer {
            zcu.codegen_prog_node.end();
            zcu.codegen_prog_node = undefined;
        }

        try pt.linkerUpdateDecl(decl_index);
    }
}

pub fn linkerUpdateDecl(pt: Zcu.PerThread, decl_index: Zcu.Decl.Index) !void {
    const zcu = pt.zcu;
    const comp = zcu.comp;

    const decl = zcu.declPtr(decl_index);

    const codegen_prog_node = zcu.codegen_prog_node.start((try decl.fullyQualifiedName(pt)).toSlice(&zcu.intern_pool), 0);
    defer codegen_prog_node.end();

    if (comp.bin_file) |lf| {
        lf.updateDecl(pt, decl_index) catch |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            error.AnalysisFail => {
                decl.analysis = .codegen_failure;
            },
            else => {
                const gpa = zcu.gpa;
                try zcu.failed_analysis.ensureUnusedCapacity(gpa, 1);
                zcu.failed_analysis.putAssumeCapacityNoClobber(InternPool.AnalUnit.wrap(.{ .decl = decl_index }), try Zcu.ErrorMsg.create(
                    gpa,
                    decl.navSrcLoc(zcu),
                    "unable to codegen: {s}",
                    .{@errorName(err)},
                ));
                decl.analysis = .codegen_failure;
                try zcu.retryable_failures.append(zcu.gpa, InternPool.AnalUnit.wrap(.{ .decl = decl_index }));
            },
        };
    } else if (zcu.llvm_object) |llvm_object| {
        if (build_options.only_c) unreachable;
        llvm_object.updateDecl(pt, decl_index) catch |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
        };
    }
}

/// Shortcut for calling `intern_pool.get`.
pub fn intern(pt: Zcu.PerThread, key: InternPool.Key) Allocator.Error!InternPool.Index {
    return pt.zcu.intern_pool.get(pt.zcu.gpa, pt.tid, key);
}

/// Shortcut for calling `intern_pool.getCoerced`.
pub fn getCoerced(pt: Zcu.PerThread, val: Value, new_ty: Type) Allocator.Error!Value {
    return Value.fromInterned(try pt.zcu.intern_pool.getCoerced(pt.zcu.gpa, pt.tid, val.toIntern(), new_ty.toIntern()));
}

pub fn intType(pt: Zcu.PerThread, signedness: std.builtin.Signedness, bits: u16) Allocator.Error!Type {
    return Type.fromInterned(try pt.intern(.{ .int_type = .{
        .signedness = signedness,
        .bits = bits,
    } }));
}

pub fn errorIntType(pt: Zcu.PerThread) std.mem.Allocator.Error!Type {
    return pt.intType(.unsigned, pt.zcu.errorSetBits());
}

pub fn arrayType(pt: Zcu.PerThread, info: InternPool.Key.ArrayType) Allocator.Error!Type {
    return Type.fromInterned(try pt.intern(.{ .array_type = info }));
}

pub fn vectorType(pt: Zcu.PerThread, info: InternPool.Key.VectorType) Allocator.Error!Type {
    return Type.fromInterned(try pt.intern(.{ .vector_type = info }));
}

pub fn optionalType(pt: Zcu.PerThread, child_type: InternPool.Index) Allocator.Error!Type {
    return Type.fromInterned(try pt.intern(.{ .opt_type = child_type }));
}

pub fn ptrType(pt: Zcu.PerThread, info: InternPool.Key.PtrType) Allocator.Error!Type {
    var canon_info = info;

    if (info.flags.size == .C) canon_info.flags.is_allowzero = true;

    // Canonicalize non-zero alignment. If it matches the ABI alignment of the pointee
    // type, we change it to 0 here. If this causes an assertion trip because the
    // pointee type needs to be resolved more, that needs to be done before calling
    // this ptr() function.
    if (info.flags.alignment != .none and
        info.flags.alignment == Type.fromInterned(info.child).abiAlignment(pt))
    {
        canon_info.flags.alignment = .none;
    }

    switch (info.flags.vector_index) {
        // Canonicalize host_size. If it matches the bit size of the pointee type,
        // we change it to 0 here. If this causes an assertion trip, the pointee type
        // needs to be resolved before calling this ptr() function.
        .none => if (info.packed_offset.host_size != 0) {
            const elem_bit_size = Type.fromInterned(info.child).bitSize(pt);
            assert(info.packed_offset.bit_offset + elem_bit_size <= info.packed_offset.host_size * 8);
            if (info.packed_offset.host_size * 8 == elem_bit_size) {
                canon_info.packed_offset.host_size = 0;
            }
        },
        .runtime => {},
        _ => assert(@intFromEnum(info.flags.vector_index) < info.packed_offset.host_size),
    }

    return Type.fromInterned(try pt.intern(.{ .ptr_type = canon_info }));
}

/// Like `ptrType`, but if `info` specifies an `alignment`, first ensures the pointer
/// child type's alignment is resolved so that an invalid alignment is not used.
/// In general, prefer this function during semantic analysis.
pub fn ptrTypeSema(pt: Zcu.PerThread, info: InternPool.Key.PtrType) Zcu.SemaError!Type {
    if (info.flags.alignment != .none) {
        _ = try Type.fromInterned(info.child).abiAlignmentAdvanced(pt, .sema);
    }
    return pt.ptrType(info);
}

pub fn singleMutPtrType(pt: Zcu.PerThread, child_type: Type) Allocator.Error!Type {
    return pt.ptrType(.{ .child = child_type.toIntern() });
}

pub fn singleConstPtrType(pt: Zcu.PerThread, child_type: Type) Allocator.Error!Type {
    return pt.ptrType(.{
        .child = child_type.toIntern(),
        .flags = .{
            .is_const = true,
        },
    });
}

pub fn manyConstPtrType(pt: Zcu.PerThread, child_type: Type) Allocator.Error!Type {
    return pt.ptrType(.{
        .child = child_type.toIntern(),
        .flags = .{
            .size = .Many,
            .is_const = true,
        },
    });
}

pub fn adjustPtrTypeChild(pt: Zcu.PerThread, ptr_ty: Type, new_child: Type) Allocator.Error!Type {
    var info = ptr_ty.ptrInfo(pt.zcu);
    info.child = new_child.toIntern();
    return pt.ptrType(info);
}

pub fn funcType(pt: Zcu.PerThread, key: InternPool.GetFuncTypeKey) Allocator.Error!Type {
    return Type.fromInterned(try pt.zcu.intern_pool.getFuncType(pt.zcu.gpa, pt.tid, key));
}

/// Use this for `anyframe->T` only.
/// For `anyframe`, use the `InternPool.Index.anyframe` tag directly.
pub fn anyframeType(pt: Zcu.PerThread, payload_ty: Type) Allocator.Error!Type {
    return Type.fromInterned(try pt.intern(.{ .anyframe_type = payload_ty.toIntern() }));
}

pub fn errorUnionType(pt: Zcu.PerThread, error_set_ty: Type, payload_ty: Type) Allocator.Error!Type {
    return Type.fromInterned(try pt.intern(.{ .error_union_type = .{
        .error_set_type = error_set_ty.toIntern(),
        .payload_type = payload_ty.toIntern(),
    } }));
}

pub fn singleErrorSetType(pt: Zcu.PerThread, name: InternPool.NullTerminatedString) Allocator.Error!Type {
    const names: *const [1]InternPool.NullTerminatedString = &name;
    return Type.fromInterned(try pt.zcu.intern_pool.getErrorSetType(pt.zcu.gpa, pt.tid, names));
}

/// Sorts `names` in place.
pub fn errorSetFromUnsortedNames(
    pt: Zcu.PerThread,
    names: []InternPool.NullTerminatedString,
) Allocator.Error!Type {
    std.mem.sort(
        InternPool.NullTerminatedString,
        names,
        {},
        InternPool.NullTerminatedString.indexLessThan,
    );
    const new_ty = try pt.zcu.intern_pool.getErrorSetType(pt.zcu.gpa, pt.tid, names);
    return Type.fromInterned(new_ty);
}

/// Supports only pointers, not pointer-like optionals.
pub fn ptrIntValue(pt: Zcu.PerThread, ty: Type, x: u64) Allocator.Error!Value {
    const mod = pt.zcu;
    assert(ty.zigTypeTag(mod) == .Pointer and !ty.isSlice(mod));
    assert(x != 0 or ty.isAllowzeroPtr(mod));
    return Value.fromInterned(try pt.intern(.{ .ptr = .{
        .ty = ty.toIntern(),
        .base_addr = .int,
        .byte_offset = x,
    } }));
}

/// Creates an enum tag value based on the integer tag value.
pub fn enumValue(pt: Zcu.PerThread, ty: Type, tag_int: InternPool.Index) Allocator.Error!Value {
    if (std.debug.runtime_safety) {
        const tag = ty.zigTypeTag(pt.zcu);
        assert(tag == .Enum);
    }
    return Value.fromInterned(try pt.intern(.{ .enum_tag = .{
        .ty = ty.toIntern(),
        .int = tag_int,
    } }));
}

/// Creates an enum tag value based on the field index according to source code
/// declaration order.
pub fn enumValueFieldIndex(pt: Zcu.PerThread, ty: Type, field_index: u32) Allocator.Error!Value {
    const ip = &pt.zcu.intern_pool;
    const enum_type = ip.loadEnumType(ty.toIntern());

    if (enum_type.values.len == 0) {
        // Auto-numbered fields.
        return Value.fromInterned(try pt.intern(.{ .enum_tag = .{
            .ty = ty.toIntern(),
            .int = try pt.intern(.{ .int = .{
                .ty = enum_type.tag_ty,
                .storage = .{ .u64 = field_index },
            } }),
        } }));
    }

    return Value.fromInterned(try pt.intern(.{ .enum_tag = .{
        .ty = ty.toIntern(),
        .int = enum_type.values.get(ip)[field_index],
    } }));
}

pub fn undefValue(pt: Zcu.PerThread, ty: Type) Allocator.Error!Value {
    return Value.fromInterned(try pt.intern(.{ .undef = ty.toIntern() }));
}

pub fn undefRef(pt: Zcu.PerThread, ty: Type) Allocator.Error!Air.Inst.Ref {
    return Air.internedToRef((try pt.undefValue(ty)).toIntern());
}

pub fn intValue(pt: Zcu.PerThread, ty: Type, x: anytype) Allocator.Error!Value {
    if (std.math.cast(u64, x)) |casted| return pt.intValue_u64(ty, casted);
    if (std.math.cast(i64, x)) |casted| return pt.intValue_i64(ty, casted);
    var limbs_buffer: [4]usize = undefined;
    var big_int = BigIntMutable.init(&limbs_buffer, x);
    return pt.intValue_big(ty, big_int.toConst());
}

pub fn intRef(pt: Zcu.PerThread, ty: Type, x: anytype) Allocator.Error!Air.Inst.Ref {
    return Air.internedToRef((try pt.intValue(ty, x)).toIntern());
}

pub fn intValue_big(pt: Zcu.PerThread, ty: Type, x: BigIntConst) Allocator.Error!Value {
    return Value.fromInterned(try pt.intern(.{ .int = .{
        .ty = ty.toIntern(),
        .storage = .{ .big_int = x },
    } }));
}

pub fn intValue_u64(pt: Zcu.PerThread, ty: Type, x: u64) Allocator.Error!Value {
    return Value.fromInterned(try pt.intern(.{ .int = .{
        .ty = ty.toIntern(),
        .storage = .{ .u64 = x },
    } }));
}

pub fn intValue_i64(pt: Zcu.PerThread, ty: Type, x: i64) Allocator.Error!Value {
    return Value.fromInterned(try pt.intern(.{ .int = .{
        .ty = ty.toIntern(),
        .storage = .{ .i64 = x },
    } }));
}

pub fn unionValue(pt: Zcu.PerThread, union_ty: Type, tag: Value, val: Value) Allocator.Error!Value {
    return Value.fromInterned(try pt.intern(.{ .un = .{
        .ty = union_ty.toIntern(),
        .tag = tag.toIntern(),
        .val = val.toIntern(),
    } }));
}

/// This function casts the float representation down to the representation of the type, potentially
/// losing data if the representation wasn't correct.
pub fn floatValue(pt: Zcu.PerThread, ty: Type, x: anytype) Allocator.Error!Value {
    const storage: InternPool.Key.Float.Storage = switch (ty.floatBits(pt.zcu.getTarget())) {
        16 => .{ .f16 = @as(f16, @floatCast(x)) },
        32 => .{ .f32 = @as(f32, @floatCast(x)) },
        64 => .{ .f64 = @as(f64, @floatCast(x)) },
        80 => .{ .f80 = @as(f80, @floatCast(x)) },
        128 => .{ .f128 = @as(f128, @floatCast(x)) },
        else => unreachable,
    };
    return Value.fromInterned(try pt.intern(.{ .float = .{
        .ty = ty.toIntern(),
        .storage = storage,
    } }));
}

pub fn nullValue(pt: Zcu.PerThread, opt_ty: Type) Allocator.Error!Value {
    assert(pt.zcu.intern_pool.isOptionalType(opt_ty.toIntern()));
    return Value.fromInterned(try pt.intern(.{ .opt = .{
        .ty = opt_ty.toIntern(),
        .val = .none,
    } }));
}

pub fn smallestUnsignedInt(pt: Zcu.PerThread, max: u64) Allocator.Error!Type {
    return pt.intType(.unsigned, Type.smallestUnsignedBits(max));
}

/// Returns the smallest possible integer type containing both `min` and
/// `max`. Asserts that neither value is undef.
/// TODO: if #3806 is implemented, this becomes trivial
pub fn intFittingRange(pt: Zcu.PerThread, min: Value, max: Value) !Type {
    const mod = pt.zcu;
    assert(!min.isUndef(mod));
    assert(!max.isUndef(mod));

    if (std.debug.runtime_safety) {
        assert(Value.order(min, max, pt).compare(.lte));
    }

    const sign = min.orderAgainstZero(pt) == .lt;

    const min_val_bits = pt.intBitsForValue(min, sign);
    const max_val_bits = pt.intBitsForValue(max, sign);

    return pt.intType(
        if (sign) .signed else .unsigned,
        @max(min_val_bits, max_val_bits),
    );
}

/// Given a value representing an integer, returns the number of bits necessary to represent
/// this value in an integer. If `sign` is true, returns the number of bits necessary in a
/// twos-complement integer; otherwise in an unsigned integer.
/// Asserts that `val` is not undef. If `val` is negative, asserts that `sign` is true.
pub fn intBitsForValue(pt: Zcu.PerThread, val: Value, sign: bool) u16 {
    const mod = pt.zcu;
    assert(!val.isUndef(mod));

    const key = mod.intern_pool.indexToKey(val.toIntern());
    switch (key.int.storage) {
        .i64 => |x| {
            if (std.math.cast(u64, x)) |casted| return Type.smallestUnsignedBits(casted) + @intFromBool(sign);
            assert(sign);
            // Protect against overflow in the following negation.
            if (x == std.math.minInt(i64)) return 64;
            return Type.smallestUnsignedBits(@as(u64, @intCast(-(x + 1)))) + 1;
        },
        .u64 => |x| {
            return Type.smallestUnsignedBits(x) + @intFromBool(sign);
        },
        .big_int => |big| {
            if (big.positive) return @as(u16, @intCast(big.bitCountAbs() + @intFromBool(sign)));

            // Zero is still a possibility, in which case unsigned is fine
            if (big.eqlZero()) return 0;

            return @as(u16, @intCast(big.bitCountTwosComp()));
        },
        .lazy_align => |lazy_ty| {
            return Type.smallestUnsignedBits(Type.fromInterned(lazy_ty).abiAlignment(pt).toByteUnits() orelse 0) + @intFromBool(sign);
        },
        .lazy_size => |lazy_ty| {
            return Type.smallestUnsignedBits(Type.fromInterned(lazy_ty).abiSize(pt)) + @intFromBool(sign);
        },
    }
}

pub fn getUnionLayout(pt: Zcu.PerThread, loaded_union: InternPool.LoadedUnionType) Zcu.UnionLayout {
    const mod = pt.zcu;
    const ip = &mod.intern_pool;
    assert(loaded_union.haveLayout(ip));
    var most_aligned_field: u32 = undefined;
    var most_aligned_field_size: u64 = undefined;
    var biggest_field: u32 = undefined;
    var payload_size: u64 = 0;
    var payload_align: InternPool.Alignment = .@"1";
    for (loaded_union.field_types.get(ip), 0..) |field_ty, field_index| {
        if (!Type.fromInterned(field_ty).hasRuntimeBitsIgnoreComptime(pt)) continue;

        const explicit_align = loaded_union.fieldAlign(ip, field_index);
        const field_align = if (explicit_align != .none)
            explicit_align
        else
            Type.fromInterned(field_ty).abiAlignment(pt);
        const field_size = Type.fromInterned(field_ty).abiSize(pt);
        if (field_size > payload_size) {
            payload_size = field_size;
            biggest_field = @intCast(field_index);
        }
        if (field_align.compare(.gte, payload_align)) {
            payload_align = field_align;
            most_aligned_field = @intCast(field_index);
            most_aligned_field_size = field_size;
        }
    }
    const have_tag = loaded_union.flagsPtr(ip).runtime_tag.hasTag();
    if (!have_tag or !Type.fromInterned(loaded_union.enum_tag_ty).hasRuntimeBits(pt)) {
        return .{
            .abi_size = payload_align.forward(payload_size),
            .abi_align = payload_align,
            .most_aligned_field = most_aligned_field,
            .most_aligned_field_size = most_aligned_field_size,
            .biggest_field = biggest_field,
            .payload_size = payload_size,
            .payload_align = payload_align,
            .tag_align = .none,
            .tag_size = 0,
            .padding = 0,
        };
    }

    const tag_size = Type.fromInterned(loaded_union.enum_tag_ty).abiSize(pt);
    const tag_align = Type.fromInterned(loaded_union.enum_tag_ty).abiAlignment(pt).max(.@"1");
    return .{
        .abi_size = loaded_union.size(ip).*,
        .abi_align = tag_align.max(payload_align),
        .most_aligned_field = most_aligned_field,
        .most_aligned_field_size = most_aligned_field_size,
        .biggest_field = biggest_field,
        .payload_size = payload_size,
        .payload_align = payload_align,
        .tag_align = tag_align,
        .tag_size = tag_size,
        .padding = loaded_union.padding(ip).*,
    };
}

pub fn unionAbiSize(mod: *Module, loaded_union: InternPool.LoadedUnionType) u64 {
    return mod.getUnionLayout(loaded_union).abi_size;
}

/// Returns 0 if the union is represented with 0 bits at runtime.
pub fn unionAbiAlignment(pt: Zcu.PerThread, loaded_union: InternPool.LoadedUnionType) InternPool.Alignment {
    const mod = pt.zcu;
    const ip = &mod.intern_pool;
    const have_tag = loaded_union.flagsPtr(ip).runtime_tag.hasTag();
    var max_align: InternPool.Alignment = .none;
    if (have_tag) max_align = Type.fromInterned(loaded_union.enum_tag_ty).abiAlignment(pt);
    for (loaded_union.field_types.get(ip), 0..) |field_ty, field_index| {
        if (!Type.fromInterned(field_ty).hasRuntimeBits(pt)) continue;

        const field_align = mod.unionFieldNormalAlignment(loaded_union, @intCast(field_index));
        max_align = max_align.max(field_align);
    }
    return max_align;
}

/// Returns the field alignment of a non-packed union. Asserts the layout is not packed.
pub fn unionFieldNormalAlignment(
    pt: Zcu.PerThread,
    loaded_union: InternPool.LoadedUnionType,
    field_index: u32,
) InternPool.Alignment {
    return pt.unionFieldNormalAlignmentAdvanced(loaded_union, field_index, .normal) catch unreachable;
}

/// Returns the field alignment of a non-packed union. Asserts the layout is not packed.
/// If `strat` is `.sema`, may perform type resolution.
pub fn unionFieldNormalAlignmentAdvanced(
    pt: Zcu.PerThread,
    loaded_union: InternPool.LoadedUnionType,
    field_index: u32,
    strat: Type.ResolveStrat,
) Zcu.SemaError!InternPool.Alignment {
    const ip = &pt.zcu.intern_pool;
    assert(loaded_union.flagsPtr(ip).layout != .@"packed");
    const field_align = loaded_union.fieldAlign(ip, field_index);
    if (field_align != .none) return field_align;
    const field_ty = Type.fromInterned(loaded_union.field_types.get(ip)[field_index]);
    if (field_ty.isNoReturn(pt.zcu)) return .none;
    return (try field_ty.abiAlignmentAdvanced(pt, strat.toLazy())).scalar;
}

/// Returns the field alignment of a non-packed struct. Asserts the layout is not packed.
pub fn structFieldAlignment(
    pt: Zcu.PerThread,
    explicit_alignment: InternPool.Alignment,
    field_ty: Type,
    layout: std.builtin.Type.ContainerLayout,
) InternPool.Alignment {
    return pt.structFieldAlignmentAdvanced(explicit_alignment, field_ty, layout, .normal) catch unreachable;
}

/// Returns the field alignment of a non-packed struct. Asserts the layout is not packed.
/// If `strat` is `.sema`, may perform type resolution.
pub fn structFieldAlignmentAdvanced(
    pt: Zcu.PerThread,
    explicit_alignment: InternPool.Alignment,
    field_ty: Type,
    layout: std.builtin.Type.ContainerLayout,
    strat: Type.ResolveStrat,
) Zcu.SemaError!InternPool.Alignment {
    assert(layout != .@"packed");
    if (explicit_alignment != .none) return explicit_alignment;
    const ty_abi_align = (try field_ty.abiAlignmentAdvanced(pt, strat.toLazy())).scalar;
    switch (layout) {
        .@"packed" => unreachable,
        .auto => if (pt.zcu.getTarget().ofmt != .c) return ty_abi_align,
        .@"extern" => {},
    }
    // extern
    if (field_ty.isAbiInt(pt.zcu) and field_ty.intInfo(pt.zcu).bits >= 128) {
        return ty_abi_align.maxStrict(.@"16");
    }
    return ty_abi_align;
}

/// https://github.com/ziglang/zig/issues/17178 explored storing these bit offsets
/// into the packed struct InternPool data rather than computing this on the
/// fly, however it was found to perform worse when measured on real world
/// projects.
pub fn structPackedFieldBitOffset(
    pt: Zcu.PerThread,
    struct_type: InternPool.LoadedStructType,
    field_index: u32,
) u16 {
    const mod = pt.zcu;
    const ip = &mod.intern_pool;
    assert(struct_type.layout == .@"packed");
    assert(struct_type.haveLayout(ip));
    var bit_sum: u64 = 0;
    for (0..struct_type.field_types.len) |i| {
        if (i == field_index) {
            return @intCast(bit_sum);
        }
        const field_ty = Type.fromInterned(struct_type.field_types.get(ip)[i]);
        bit_sum += field_ty.bitSize(pt);
    }
    unreachable; // index out of bounds
}

pub fn getBuiltin(pt: Zcu.PerThread, name: []const u8) Allocator.Error!Air.Inst.Ref {
    const decl_index = try pt.getBuiltinDecl(name);
    pt.ensureDeclAnalyzed(decl_index) catch @panic("std.builtin is corrupt");
    return Air.internedToRef(pt.zcu.declPtr(decl_index).val.toIntern());
}

pub fn getBuiltinDecl(pt: Zcu.PerThread, name: []const u8) Allocator.Error!InternPool.DeclIndex {
    const zcu = pt.zcu;
    const gpa = zcu.gpa;
    const ip = &zcu.intern_pool;
    const std_file_imported = zcu.importPkg(zcu.std_mod) catch @panic("failed to import lib/std.zig");
    const std_file_root_decl = zcu.fileRootDecl(std_file_imported.file_index).unwrap().?;
    const std_namespace = zcu.declPtr(std_file_root_decl).getOwnedInnerNamespace(zcu).?;
    const builtin_str = try ip.getOrPutString(gpa, pt.tid, "builtin", .no_embedded_nulls);
    const builtin_decl = std_namespace.decls.getKeyAdapted(builtin_str, Zcu.DeclAdapter{ .zcu = zcu }) orelse @panic("lib/std.zig is corrupt and missing 'builtin'");
    pt.ensureDeclAnalyzed(builtin_decl) catch @panic("std.builtin is corrupt");
    const builtin_namespace = zcu.declPtr(builtin_decl).getInnerNamespace(zcu) orelse @panic("std.builtin is corrupt");
    const name_str = try ip.getOrPutString(gpa, pt.tid, name, .no_embedded_nulls);
    return builtin_namespace.decls.getKeyAdapted(name_str, Zcu.DeclAdapter{ .zcu = zcu }) orelse @panic("lib/std/builtin.zig is corrupt");
}

pub fn getBuiltinType(pt: Zcu.PerThread, name: []const u8) Allocator.Error!Type {
    const ty_inst = try pt.getBuiltin(name);
    const ty = Type.fromInterned(ty_inst.toInterned() orelse @panic("std.builtin is corrupt"));
    ty.resolveFully(pt) catch @panic("std.builtin is corrupt");
    return ty;
}

const Air = @import("../Air.zig");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const Ast = std.zig.Ast;
const AstGen = std.zig.AstGen;
const BigIntConst = std.math.big.int.Const;
const BigIntMutable = std.math.big.int.Mutable;
const build_options = @import("build_options");
const builtin = @import("builtin");
const Cache = std.Build.Cache;
const InternPool = @import("../InternPool.zig");
const isUpDir = @import("../introspect.zig").isUpDir;
const Liveness = @import("../Liveness.zig");
const log = std.log.scoped(.zcu);
const Module = @import("../Package.zig").Module;
const Sema = @import("../Sema.zig");
const std = @import("std");
const target_util = @import("../target.zig");
const trace = @import("../tracy.zig").trace;
const Type = @import("../Type.zig");
const Value = @import("../Value.zig");
const Zcu = @import("../Zcu.zig");
const Zir = std.zig.Zir;
