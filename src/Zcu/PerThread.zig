//! This type provides a wrapper around a `*Zcu` for uses which require a thread `Id`.
//! Any operation which mutates `InternPool` state lives here rather than on `Zcu`.

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
const dev = @import("../dev.zig");
const InternPool = @import("../InternPool.zig");
const AnalUnit = InternPool.AnalUnit;
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

zcu: *Zcu,

/// Dense, per-thread unique index.
tid: Id,

pub const IdBacking = u7;
pub const Id = if (InternPool.single_threaded) enum { main } else enum(IdBacking) { main, _ };

pub fn activate(zcu: *Zcu, tid: Id) Zcu.PerThread {
    zcu.intern_pool.activate();
    return .{ .zcu = zcu, .tid = tid };
}

pub fn deactivate(pt: Zcu.PerThread) void {
    pt.zcu.intern_pool.deactivate();
}

fn deinitFile(pt: Zcu.PerThread, file_index: Zcu.File.Index) void {
    const zcu = pt.zcu;
    const gpa = zcu.gpa;
    const file = zcu.fileByIndex(file_index);
    const is_builtin = file.mod.isBuiltin();
    log.debug("deinit File {s}", .{file.sub_file_path});
    if (is_builtin) {
        file.unloadTree(gpa);
        file.unloadZir(gpa);
    } else {
        gpa.free(file.sub_file_path);
        file.unload(gpa);
    }
    file.references.deinit(gpa);
    if (file.prev_zir) |prev_zir| {
        prev_zir.deinit(gpa);
        gpa.destroy(prev_zir);
    }
    file.* = undefined;
}

pub fn destroyFile(pt: Zcu.PerThread, file_index: Zcu.File.Index) void {
    const gpa = pt.zcu.gpa;
    const file = pt.zcu.fileByIndex(file_index);
    const is_builtin = file.mod.isBuiltin();
    pt.deinitFile(file_index);
    if (!is_builtin) gpa.destroy(file);
}

pub fn astGenFile(
    pt: Zcu.PerThread,
    file: *Zcu.File,
    path_digest: Cache.BinDigest,
) !void {
    dev.check(.ast_gen);
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
            error.NoDevice => unreachable, // it's not a pipe
            error.WouldBlock => unreachable, // not asking for non-blocking I/O
            error.FileNotFound => {
                // There are no dir components, so the only possibility should
                // be that the directory behind the handle has been deleted,
                // however we have observed on macOS two processes racing to do
                // openat() with O_CREAT manifest in ENOENT.
                //
                // As a workaround, we retry with exclusive=true which
                // disambiguates by returning EEXIST, indicating original
                // failure was a race, or ENOENT, indicating deletion of the
                // directory of our open handle.
                if (builtin.os.tag != .macos) {
                    std.process.fatal("cache directory '{}' unexpectedly removed during compiler execution", .{
                        cache_directory,
                    });
                }
                break zir_dir.createFile(&hex_digest, .{
                    .read = true,
                    .truncate = false,
                    .lock = lock,
                    .exclusive = true,
                }) catch |excl_err| switch (excl_err) {
                    error.PathAlreadyExists => continue,
                    error.FileNotFound => {
                        std.process.fatal("cache directory '{}' unexpectedly removed during compiler execution", .{
                            cache_directory,
                        });
                    },
                    else => |e| return e,
                };
            },

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
            file.prev_status = file.status;
            file.status = .success_zir;
            log.debug("AstGen cached success: {s}", .{file.sub_file_path});

            if (file.zir.hasCompileErrors()) {
                comp.mutex.lock();
                defer comp.mutex.unlock();
                try zcu.failed_files.putNoClobber(gpa, file, null);
            }
            if (file.zir.loweringFailed()) {
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

    // Previous ZIR is kept for two reasons:
    //
    // 1. In case an update to the file causes a Parse or AstGen failure, we
    //    need to compare two successful ZIR files in order to proceed with an
    //    incremental update. This avoids needlessly tossing out semantic
    //    analysis work when an error is temporarily introduced.
    //
    // 2. In order to detect updates, we need to iterate over the intern pool
    //    values while comparing old ZIR to new ZIR. This is better done in a
    //    single-threaded context, so we need to keep both versions around
    //    until that point in the pipeline. Previous ZIR data is freed after
    //    that.
    if (file.zir_loaded and !file.zir.loweringFailed()) {
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
    file.prev_status = file.status;
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
        comp.mutex.lock();
        defer comp.mutex.unlock();
        try zcu.failed_files.putNoClobber(gpa, file, null);
    }
    if (file.zir.loweringFailed()) {
        file.status = .astgen_failure;
        return error.AnalysisFail;
    }
}

const UpdatedFile = struct {
    file: *Zcu.File,
    inst_map: std.AutoHashMapUnmanaged(Zir.Inst.Index, Zir.Inst.Index),
};

fn cleanupUpdatedFiles(gpa: Allocator, updated_files: *std.AutoArrayHashMapUnmanaged(Zcu.File.Index, UpdatedFile)) void {
    for (updated_files.values()) |*elem| elem.inst_map.deinit(gpa);
    updated_files.deinit(gpa);
}

pub fn updateZirRefs(pt: Zcu.PerThread) Allocator.Error!void {
    assert(pt.tid == .main);
    const zcu = pt.zcu;
    const ip = &zcu.intern_pool;
    const gpa = zcu.gpa;

    // We need to visit every updated File for every TrackedInst in InternPool.
    var updated_files: std.AutoArrayHashMapUnmanaged(Zcu.File.Index, UpdatedFile) = .empty;
    defer cleanupUpdatedFiles(gpa, &updated_files);
    for (zcu.import_table.values()) |file_index| {
        const file = zcu.fileByIndex(file_index);
        if (file.prev_status != file.status and file.prev_status != .never_loaded) {
            try zcu.markDependeeOutdated(.not_marked_po, .{ .file = file_index });
        }
        const old_zir = file.prev_zir orelse continue;
        const new_zir = file.zir;
        const gop = try updated_files.getOrPut(gpa, file_index);
        assert(!gop.found_existing);
        gop.value_ptr.* = .{
            .file = file,
            .inst_map = .{},
        };
        if (!new_zir.loweringFailed()) {
            try Zcu.mapOldZirToNew(gpa, old_zir.*, file.zir, &gop.value_ptr.inst_map);
        }
    }

    if (updated_files.count() == 0)
        return;

    for (ip.locals, 0..) |*local, tid| {
        const tracked_insts_list = local.getMutableTrackedInsts(gpa);
        for (tracked_insts_list.viewAllowEmpty().items(.@"0"), 0..) |*tracked_inst, tracked_inst_unwrapped_index| {
            const file_index = tracked_inst.file;
            const updated_file = updated_files.get(file_index) orelse continue;

            const file = updated_file.file;

            const old_inst = tracked_inst.inst.unwrap() orelse continue; // we can't continue tracking lost insts
            const tracked_inst_index = (InternPool.TrackedInst.Index.Unwrapped{
                .tid = @enumFromInt(tid),
                .index = @intCast(tracked_inst_unwrapped_index),
            }).wrap(ip);
            const new_inst = updated_file.inst_map.get(old_inst) orelse {
                // Tracking failed for this instruction.
                // This may be due to changes in the ZIR, or AstGen might have failed due to a very broken file.
                // Either way, invalidate associated `src_hash` deps.
                log.debug("tracking failed for %{d}{s}", .{
                    old_inst,
                    if (file.zir.loweringFailed()) " due to AstGen failure" else "",
                });
                tracked_inst.inst = .lost;
                try zcu.markDependeeOutdated(.not_marked_po, .{ .src_hash = tracked_inst_index });
                continue;
            };
            tracked_inst.inst = InternPool.TrackedInst.MaybeLost.ZirIndex.wrap(new_inst);

            const old_zir = file.prev_zir.?.*;
            const new_zir = file.zir;
            const old_tag = old_zir.instructions.items(.tag);
            const old_data = old_zir.instructions.items(.data);

            if (old_zir.getAssociatedSrcHash(old_inst)) |old_hash| hash_changed: {
                if (new_zir.getAssociatedSrcHash(new_inst)) |new_hash| {
                    if (std.zig.srcHashEql(old_hash, new_hash)) {
                        break :hash_changed;
                    }
                    log.debug("hash for (%{d} -> %{d}) changed: {} -> {}", .{
                        old_inst,
                        new_inst,
                        std.fmt.fmtSliceHexLower(&old_hash),
                        std.fmt.fmtSliceHexLower(&new_hash),
                    });
                }
                // The source hash associated with this instruction changed - invalidate relevant dependencies.
                try zcu.markDependeeOutdated(.not_marked_po, .{ .src_hash = tracked_inst_index });
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

            var old_names: std.AutoArrayHashMapUnmanaged(InternPool.NullTerminatedString, void) = .empty;
            defer old_names.deinit(zcu.gpa);
            {
                var it = old_zir.declIterator(old_inst);
                while (it.next()) |decl_inst| {
                    const name_zir = old_zir.getDeclaration(decl_inst).name;
                    if (name_zir == .empty) continue;
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
                var it = new_zir.declIterator(new_inst);
                while (it.next()) |decl_inst| {
                    const name_zir = new_zir.getDeclaration(decl_inst).name;
                    if (name_zir == .empty) continue;
                    const name_ip = try zcu.intern_pool.getOrPutString(
                        zcu.gpa,
                        pt.tid,
                        new_zir.nullTerminatedString(name_zir),
                        .no_embedded_nulls,
                    );
                    if (old_names.swapRemove(name_ip)) continue;
                    // Name added
                    any_change = true;
                    try zcu.markDependeeOutdated(.not_marked_po, .{ .namespace_name = .{
                        .namespace = tracked_inst_index,
                        .name = name_ip,
                    } });
                }
            }
            // The only elements remaining in `old_names` now are any names which were removed.
            for (old_names.keys()) |name_ip| {
                any_change = true;
                try zcu.markDependeeOutdated(.not_marked_po, .{ .namespace_name = .{
                    .namespace = tracked_inst_index,
                    .name = name_ip,
                } });
            }

            if (any_change) {
                try zcu.markDependeeOutdated(.not_marked_po, .{ .namespace = tracked_inst_index });
            }
        }
    }

    try ip.rehashTrackedInsts(gpa, pt.tid);

    for (updated_files.keys(), updated_files.values()) |file_index, updated_file| {
        const file = updated_file.file;
        if (file.zir.loweringFailed()) {
            // Keep `prev_zir` around: it's the last usable ZIR.
            // Don't update the namespace, as we have no new data to update *to*.
        } else {
            const prev_zir = file.prev_zir.?;
            file.prev_zir = null;
            prev_zir.deinit(gpa);
            gpa.destroy(prev_zir);

            // For every file which has changed, re-scan the namespace of the file's root struct type.
            // These types are special-cased because they don't have an enclosing declaration which will
            // be re-analyzed (causing the struct's namespace to be re-scanned). It's fine to do this
            // now because this work is fast (no actual Sema work is happening, we're just updating the
            // namespace contents). We must do this after updating ZIR refs above, since `scanNamespace`
            // will track some instructions.
            try pt.updateFileNamespace(file_index);
        }
    }
}

/// Ensures that `zcu.fileRootType` on this `file_index` gives an up-to-date answer.
/// Returns `error.AnalysisFail` if the file has an error.
pub fn ensureFileAnalyzed(pt: Zcu.PerThread, file_index: Zcu.File.Index) Zcu.SemaError!void {
    const file_root_type = pt.zcu.fileRootType(file_index);
    if (file_root_type != .none) {
        _ = try pt.ensureTypeUpToDate(file_root_type);
    } else {
        return pt.semaFile(file_index);
    }
}

/// Ensures that the state of the given `ComptimeUnit` is fully up-to-date, performing re-analysis
/// if necessary. Returns `error.AnalysisFail` if an analysis error is encountered; the caller is
/// free to ignore this, since the error is already registered.
pub fn ensureComptimeUnitUpToDate(pt: Zcu.PerThread, cu_id: InternPool.ComptimeUnit.Id) Zcu.SemaError!void {
    const tracy = trace(@src());
    defer tracy.end();

    const zcu = pt.zcu;
    const gpa = zcu.gpa;

    const anal_unit: AnalUnit = .wrap(.{ .@"comptime" = cu_id });

    log.debug("ensureComptimeUnitUpToDate {}", .{zcu.fmtAnalUnit(anal_unit)});

    assert(!zcu.analysis_in_progress.contains(anal_unit));

    // Determine whether or not this `ComptimeUnit` is outdated. For this kind of `AnalUnit`, that's
    // the only indicator as to whether or not analysis is required; when a `ComptimeUnit` is first
    // created, it's marked as outdated.
    //
    // Note that if the unit is PO, we pessimistically assume that it *does* require re-analysis, to
    // ensure that the unit is definitely up-to-date when this function returns. This mechanism could
    // result in over-analysis if analysis occurs in a poor order; we do our best to avoid this by
    // carefully choosing which units to re-analyze. See `Zcu.findOutdatedToAnalyze`.

    const was_outdated = zcu.outdated.swapRemove(anal_unit) or
        zcu.potentially_outdated.swapRemove(anal_unit);

    if (was_outdated) {
        _ = zcu.outdated_ready.swapRemove(anal_unit);
        // `was_outdated` can be true in the initial update for comptime units, so this isn't a `dev.check`.
        if (dev.env.supports(.incremental)) {
            zcu.deleteUnitExports(anal_unit);
            zcu.deleteUnitReferences(anal_unit);
            if (zcu.failed_analysis.fetchSwapRemove(anal_unit)) |kv| {
                kv.value.destroy(gpa);
            }
            _ = zcu.transitive_failed_analysis.swapRemove(anal_unit);
        }
    } else {
        // We can trust the current information about this unit.
        if (zcu.failed_analysis.contains(anal_unit)) return error.AnalysisFail;
        if (zcu.transitive_failed_analysis.contains(anal_unit)) return error.AnalysisFail;
        return;
    }

    const unit_prog_node = zcu.sema_prog_node.start("comptime", 0);
    defer unit_prog_node.end();

    return pt.analyzeComptimeUnit(cu_id) catch |err| switch (err) {
        error.AnalysisFail => {
            if (!zcu.failed_analysis.contains(anal_unit)) {
                // If this unit caused the error, it would have an entry in `failed_analysis`.
                // Since it does not, this must be a transitive failure.
                try zcu.transitive_failed_analysis.put(gpa, anal_unit, {});
                log.debug("mark transitive analysis failure for {}", .{zcu.fmtAnalUnit(anal_unit)});
            }
            return error.AnalysisFail;
        },
        error.OutOfMemory => {
            // TODO: it's unclear how to gracefully handle this.
            // To report the error cleanly, we need to add a message to `failed_analysis` and a
            // corresponding entry to `retryable_failures`; but either of these things is quite
            // likely to OOM at this point.
            // If that happens, what do we do? Perhaps we could have a special field on `Zcu`
            // for reporting OOM errors without allocating.
            return error.OutOfMemory;
        },
        error.GenericPoison => unreachable,
        error.ComptimeReturn => unreachable,
        error.ComptimeBreak => unreachable,
    };
}

/// Re-analyzes a `ComptimeUnit`. The unit has already been determined to be out-of-date, and old
/// side effects (exports/references/etc) have been dropped. If semantic analysis fails, this
/// function will return `error.AnalysisFail`, and it is the caller's reponsibility to add an entry
/// to `transitive_failed_analysis` if necessary.
fn analyzeComptimeUnit(pt: Zcu.PerThread, cu_id: InternPool.ComptimeUnit.Id) Zcu.CompileError!void {
    const zcu = pt.zcu;
    const gpa = zcu.gpa;
    const ip = &zcu.intern_pool;

    const anal_unit: AnalUnit = .wrap(.{ .@"comptime" = cu_id });
    const comptime_unit = ip.getComptimeUnit(cu_id);

    log.debug("analyzeComptimeUnit {}", .{zcu.fmtAnalUnit(anal_unit)});

    const inst_resolved = comptime_unit.zir_index.resolveFull(ip) orelse return error.AnalysisFail;
    const file = zcu.fileByIndex(inst_resolved.file);
    // TODO: stop the compiler ever reaching Sema if there are failed files. That way, this check is
    // unnecessary, and we can move the below `removeDependenciesForDepender` call up with its friends
    // in `ensureComptimeUnitUpToDate`.
    if (file.status != .success_zir) return error.AnalysisFail;
    const zir = file.zir;

    // We are about to re-analyze this unit; drop its depenndencies.
    zcu.intern_pool.removeDependenciesForDepender(gpa, anal_unit);

    try zcu.analysis_in_progress.put(gpa, anal_unit, {});
    defer assert(zcu.analysis_in_progress.swapRemove(anal_unit));

    var analysis_arena: std.heap.ArenaAllocator = .init(gpa);
    defer analysis_arena.deinit();

    var comptime_err_ret_trace: std.ArrayList(Zcu.LazySrcLoc) = .init(gpa);
    defer comptime_err_ret_trace.deinit();

    var sema: Sema = .{
        .pt = pt,
        .gpa = gpa,
        .arena = analysis_arena.allocator(),
        .code = zir,
        .owner = anal_unit,
        .func_index = .none,
        .func_is_naked = false,
        .fn_ret_ty = .void,
        .fn_ret_ty_ies = null,
        .comptime_err_ret_trace = &comptime_err_ret_trace,
    };
    defer sema.deinit();

    // The comptime unit declares on the source of the corresponding `comptime` declaration.
    try sema.declareDependency(.{ .src_hash = comptime_unit.zir_index });

    var block: Sema.Block = .{
        .parent = null,
        .sema = &sema,
        .namespace = comptime_unit.namespace,
        .instructions = .{},
        .inlining = null,
        .is_comptime = true,
        .src_base_inst = comptime_unit.zir_index,
        .type_name_ctx = try ip.getOrPutStringFmt(gpa, pt.tid, "{}.comptime", .{
            Type.fromInterned(zcu.namespacePtr(comptime_unit.namespace).owner_type).containerTypeName(ip).fmt(ip),
        }, .no_embedded_nulls),
    };
    defer block.instructions.deinit(gpa);

    const zir_decl = zir.getDeclaration(inst_resolved.inst);
    assert(zir_decl.kind == .@"comptime");
    assert(zir_decl.type_body == null);
    assert(zir_decl.align_body == null);
    assert(zir_decl.linksection_body == null);
    assert(zir_decl.addrspace_body == null);
    const value_body = zir_decl.value_body.?;

    const result_ref = try sema.resolveInlineBody(&block, value_body, inst_resolved.inst);
    assert(result_ref == .void_value); // AstGen should always uphold this

    // Nothing else to do -- for a comptime decl, all we care about are the side effects.
    // Just make sure to `flushExports`.
    try sema.flushExports();
}

/// Ensures that the resolved value of the given `Nav` is fully up-to-date, performing re-analysis
/// if necessary. Returns `error.AnalysisFail` if an analysis error is encountered; the caller is
/// free to ignore this, since the error is already registered.
pub fn ensureNavValUpToDate(pt: Zcu.PerThread, nav_id: InternPool.Nav.Index) Zcu.SemaError!void {
    const tracy = trace(@src());
    defer tracy.end();

    // TODO: document this elsewhere mlugg!
    // For my own benefit, here's how a namespace update for a normal (non-file-root) type works:
    // `const S = struct { ... };`
    // We are adding or removing a declaration within this `struct`.
    // * `S` registers a dependency on `.{ .src_hash = (declaration of S) }`
    // * Any change to the `struct` body -- including changing a declaration -- invalidates this
    // * `S` is re-analyzed, but notes:
    //   * there is an existing struct instance (at this `TrackedInst` with these captures)
    //   * the struct's resolution is up-to-date (because nothing about the fields changed)
    // * so, it uses the same `struct`
    // * but this doesn't stop it from updating the namespace!
    //   * we basically do `scanDecls`, updating the namespace as needed
    // * so everyone lived happily ever after

    const zcu = pt.zcu;
    const gpa = zcu.gpa;
    const ip = &zcu.intern_pool;

    const anal_unit: AnalUnit = .wrap(.{ .nav_val = nav_id });
    const nav = ip.getNav(nav_id);

    log.debug("ensureNavUpToDate {}", .{zcu.fmtAnalUnit(anal_unit)});

    // Determine whether or not this `Nav`'s value is outdated. This also includes checking if the
    // status is `.unresolved`, which indicates that the value is outdated because it has *never*
    // been analyzed so far.
    //
    // Note that if the unit is PO, we pessimistically assume that it *does* require re-analysis, to
    // ensure that the unit is definitely up-to-date when this function returns. This mechanism could
    // result in over-analysis if analysis occurs in a poor order; we do our best to avoid this by
    // carefully choosing which units to re-analyze. See `Zcu.findOutdatedToAnalyze`.

    const was_outdated = zcu.outdated.swapRemove(anal_unit) or
        zcu.potentially_outdated.swapRemove(anal_unit);

    const prev_failed = zcu.failed_analysis.contains(anal_unit) or
        zcu.transitive_failed_analysis.contains(anal_unit);

    if (was_outdated) {
        dev.check(.incremental);
        _ = zcu.outdated_ready.swapRemove(anal_unit);
        zcu.deleteUnitExports(anal_unit);
        zcu.deleteUnitReferences(anal_unit);
        if (zcu.failed_analysis.fetchSwapRemove(anal_unit)) |kv| {
            kv.value.destroy(gpa);
        }
        _ = zcu.transitive_failed_analysis.swapRemove(anal_unit);
    } else {
        // We can trust the current information about this unit.
        if (prev_failed) return error.AnalysisFail;
        if (nav.status == .resolved) return;
    }

    const unit_prog_node = zcu.sema_prog_node.start(nav.fqn.toSlice(ip), 0);
    defer unit_prog_node.end();

    const sema_result: SemaNavResult, const new_failed: bool = if (pt.analyzeNavVal(nav_id)) |result| res: {
        break :res .{
            .{
                // If the unit has gone from failed to success, we still need to invalidate the dependencies.
                .invalidate_nav_val = result.invalidate_nav_val or prev_failed,
                .invalidate_nav_ref = result.invalidate_nav_ref or prev_failed,
            },
            false,
        };
    } else |err| switch (err) {
        error.AnalysisFail => res: {
            if (!zcu.failed_analysis.contains(anal_unit)) {
                // If this unit caused the error, it would have an entry in `failed_analysis`.
                // Since it does not, this must be a transitive failure.
                try zcu.transitive_failed_analysis.put(gpa, anal_unit, {});
                log.debug("mark transitive analysis failure for {}", .{zcu.fmtAnalUnit(anal_unit)});
            }
            break :res .{ .{
                .invalidate_nav_val = !prev_failed,
                .invalidate_nav_ref = !prev_failed,
            }, true };
        },
        error.OutOfMemory => {
            // TODO: it's unclear how to gracefully handle this.
            // To report the error cleanly, we need to add a message to `failed_analysis` and a
            // corresponding entry to `retryable_failures`; but either of these things is quite
            // likely to OOM at this point.
            // If that happens, what do we do? Perhaps we could have a special field on `Zcu`
            // for reporting OOM errors without allocating.
            return error.OutOfMemory;
        },
        error.GenericPoison => unreachable,
        error.ComptimeReturn => unreachable,
        error.ComptimeBreak => unreachable,
    };

    if (was_outdated) {
        // TODO: we do not yet have separate dependencies for Nav values vs types.
        const invalidate = sema_result.invalidate_nav_val or sema_result.invalidate_nav_ref;
        const dependee: InternPool.Dependee = .{ .nav_val = nav_id };
        if (invalidate) {
            // This dependency was marked as PO, meaning dependees were waiting
            // on its analysis result, and it has turned out to be outdated.
            // Update dependees accordingly.
            try zcu.markDependeeOutdated(.marked_po, dependee);
        } else {
            // This dependency was previously PO, but turned out to be up-to-date.
            // We do not need to queue successive analysis.
            try zcu.markPoDependeeUpToDate(dependee);
        }
    }

    if (new_failed) return error.AnalysisFail;
}

const SemaNavResult = packed struct {
    /// Whether the value of a `decl_val` of the corresponding Nav changed.
    invalidate_nav_val: bool,
    /// Whether the type of a `decl_ref` of the corresponding Nav changed.
    invalidate_nav_ref: bool,
};

fn analyzeNavVal(pt: Zcu.PerThread, nav_id: InternPool.Nav.Index) Zcu.CompileError!SemaNavResult {
    const zcu = pt.zcu;
    const gpa = zcu.gpa;
    const ip = &zcu.intern_pool;

    const anal_unit: AnalUnit = .wrap(.{ .nav_val = nav_id });
    const old_nav = ip.getNav(nav_id);

    log.debug("analyzeNavVal {}", .{zcu.fmtAnalUnit(anal_unit)});

    const inst_resolved = old_nav.analysis.?.zir_index.resolveFull(ip) orelse return error.AnalysisFail;
    const file = zcu.fileByIndex(inst_resolved.file);
    // TODO: stop the compiler ever reaching Sema if there are failed files. That way, this check is
    // unnecessary, and we can move the below `removeDependenciesForDepender` call up with its friends
    // in `ensureComptimeUnitUpToDate`.
    if (file.status != .success_zir) return error.AnalysisFail;
    const zir = file.zir;

    // We are about to re-analyze this unit; drop its depenndencies.
    zcu.intern_pool.removeDependenciesForDepender(gpa, anal_unit);

    try zcu.analysis_in_progress.put(gpa, anal_unit, {});
    errdefer _ = zcu.analysis_in_progress.swapRemove(anal_unit);

    var analysis_arena: std.heap.ArenaAllocator = .init(gpa);
    defer analysis_arena.deinit();

    var comptime_err_ret_trace: std.ArrayList(Zcu.LazySrcLoc) = .init(gpa);
    defer comptime_err_ret_trace.deinit();

    var sema: Sema = .{
        .pt = pt,
        .gpa = gpa,
        .arena = analysis_arena.allocator(),
        .code = zir,
        .owner = anal_unit,
        .func_index = .none,
        .func_is_naked = false,
        .fn_ret_ty = .void,
        .fn_ret_ty_ies = null,
        .comptime_err_ret_trace = &comptime_err_ret_trace,
    };
    defer sema.deinit();

    // The comptime unit declares on the source of the corresponding declaration.
    try sema.declareDependency(.{ .src_hash = old_nav.analysis.?.zir_index });

    var block: Sema.Block = .{
        .parent = null,
        .sema = &sema,
        .namespace = old_nav.analysis.?.namespace,
        .instructions = .{},
        .inlining = null,
        .is_comptime = true,
        .src_base_inst = old_nav.analysis.?.zir_index,
        .type_name_ctx = old_nav.fqn,
    };
    defer block.instructions.deinit(gpa);

    const zir_decl = zir.getDeclaration(inst_resolved.inst);

    assert(old_nav.is_usingnamespace == (zir_decl.kind == .@"usingnamespace"));

    const align_src = block.src(.{ .node_offset_var_decl_align = 0 });
    const section_src = block.src(.{ .node_offset_var_decl_section = 0 });
    const addrspace_src = block.src(.{ .node_offset_var_decl_addrspace = 0 });
    const ty_src = block.src(.{ .node_offset_var_decl_ty = 0 });
    const init_src = block.src(.{ .node_offset_var_decl_init = 0 });

    // First, we must resolve the declaration's type. To do this, we analyze the type body if available,
    // or otherwise, we analyze the value body, populating `early_val` in the process.

    const nav_ty: Type, const early_val: ?Value = if (zir_decl.type_body) |type_body| ty: {
        // We evaluate only the type now; no need for the value yet.
        const uncoerced_type_ref = try sema.resolveInlineBody(&block, type_body, inst_resolved.inst);
        const type_ref = try sema.coerce(&block, .type, uncoerced_type_ref, ty_src);
        break :ty .{ .fromInterned(type_ref.toInterned().?), null };
    } else ty: {
        // We don't have a type body, so we need to evaluate the value immediately.
        const value_body = zir_decl.value_body.?;
        const result_ref = try sema.resolveInlineBody(&block, value_body, inst_resolved.inst);
        const val = try sema.resolveFinalDeclValue(&block, init_src, result_ref);
        break :ty .{ val.typeOf(zcu), val };
    };

    switch (zir_decl.kind) {
        .@"comptime" => unreachable, // this is not a Nav
        .unnamed_test, .@"test", .decltest => assert(nav_ty.zigTypeTag(zcu) == .@"fn"),
        .@"usingnamespace" => {},
        .@"const" => {},
        .@"var" => try sema.validateVarType(
            &block,
            if (zir_decl.type_body != null) ty_src else init_src,
            nav_ty,
            zir_decl.linkage == .@"extern",
        ),
    }

    // Now that we know the type, we can evaluate the alignment, linksection, and addrspace, to determine
    // the full pointer type of this declaration.

    const alignment: InternPool.Alignment = a: {
        const align_body = zir_decl.align_body orelse break :a .none;
        const align_ref = try sema.resolveInlineBody(&block, align_body, inst_resolved.inst);
        break :a try sema.analyzeAsAlign(&block, align_src, align_ref);
    };

    const @"linksection": InternPool.OptionalNullTerminatedString = ls: {
        const linksection_body = zir_decl.linksection_body orelse break :ls .none;
        const linksection_ref = try sema.resolveInlineBody(&block, linksection_body, inst_resolved.inst);
        const bytes = try sema.toConstString(&block, section_src, linksection_ref, .{
            .needed_comptime_reason = "linksection must be comptime-known",
        });
        if (std.mem.indexOfScalar(u8, bytes, 0) != null) {
            return sema.fail(&block, section_src, "linksection cannot contain null bytes", .{});
        } else if (bytes.len == 0) {
            return sema.fail(&block, section_src, "linksection cannot be empty", .{});
        }
        break :ls try ip.getOrPutStringOpt(gpa, pt.tid, bytes, .no_embedded_nulls);
    };

    const @"addrspace": std.builtin.AddressSpace = as: {
        const addrspace_ctx: Sema.AddressSpaceContext = switch (zir_decl.kind) {
            .@"var" => .variable,
            else => switch (nav_ty.zigTypeTag(zcu)) {
                .@"fn" => .function,
                else => .constant,
            },
        };
        const target = zcu.getTarget();
        const addrspace_body = zir_decl.addrspace_body orelse break :as switch (addrspace_ctx) {
            .function => target_util.defaultAddressSpace(target, .function),
            .variable => target_util.defaultAddressSpace(target, .global_mutable),
            .constant => target_util.defaultAddressSpace(target, .global_constant),
            else => unreachable,
        };
        const addrspace_ref = try sema.resolveInlineBody(&block, addrspace_body, inst_resolved.inst);
        break :as try sema.analyzeAsAddressSpace(&block, addrspace_src, addrspace_ref, addrspace_ctx);
    };

    // Lastly, we must evaluate the value if we have not already done so. Note, however, that extern declarations
    // don't have an associated value body.

    const final_val: ?Value = early_val orelse if (zir_decl.value_body) |value_body| val: {
        // Put the resolved type into `inst_map` to be used as the result type of the init.
        try sema.inst_map.ensureSpaceForInstructions(gpa, &.{inst_resolved.inst});
        sema.inst_map.putAssumeCapacity(inst_resolved.inst, Air.internedToRef(nav_ty.toIntern()));
        const uncoerced_result_ref = try sema.resolveInlineBody(&block, value_body, inst_resolved.inst);
        assert(sema.inst_map.remove(inst_resolved.inst));

        const result_ref = try sema.coerce(&block, nav_ty, uncoerced_result_ref, init_src);
        break :val try sema.resolveFinalDeclValue(&block, init_src, result_ref);
    } else null;

    const nav_val: Value = switch (zir_decl.linkage) {
        .normal, .@"export" => switch (zir_decl.kind) {
            .@"var" => .fromInterned(try pt.intern(.{ .variable = .{
                .ty = nav_ty.toIntern(),
                .init = final_val.?.toIntern(),
                .owner_nav = nav_id,
                .is_threadlocal = zir_decl.is_threadlocal,
                .is_weak_linkage = false,
            } })),
            else => final_val.?,
        },
        .@"extern" => val: {
            assert(final_val == null); // extern decls do not have a value body
            const lib_name: ?[]const u8 = if (zir_decl.lib_name != .empty) l: {
                break :l zir.nullTerminatedString(zir_decl.lib_name);
            } else null;
            if (lib_name) |l| {
                const lib_name_src = block.src(.{ .node_offset_lib_name = 0 });
                try sema.handleExternLibName(&block, lib_name_src, l);
            }
            break :val .fromInterned(try pt.getExtern(.{
                .name = old_nav.name,
                .ty = nav_ty.toIntern(),
                .lib_name = try ip.getOrPutStringOpt(gpa, pt.tid, lib_name, .no_embedded_nulls),
                .is_const = zir_decl.kind == .@"const",
                .is_threadlocal = zir_decl.is_threadlocal,
                .is_weak_linkage = false,
                .is_dll_import = false,
                .alignment = alignment,
                .@"addrspace" = @"addrspace",
                .zir_index = old_nav.analysis.?.zir_index, // `declaration` instruction
                .owner_nav = undefined, // ignored by `getExtern`
            }));
        },
    };

    switch (nav_val.toIntern()) {
        .generic_poison => unreachable, // assertion failure
        .unreachable_value => unreachable, // assertion failure
        else => {},
    }

    // This resolves the type of the resolved value, not that value itself. If `nav_val` is a struct type,
    // this resolves the type `type` (which needs no resolution), not the struct itself.
    try nav_ty.resolveLayout(pt);

    // TODO: this is jank. If #20663 is rejected, let's think about how to better model `usingnamespace`.
    if (zir_decl.kind == .@"usingnamespace") {
        if (nav_ty.toIntern() != .type_type) {
            return sema.fail(&block, ty_src, "expected type, found {}", .{nav_ty.fmt(pt)});
        }
        if (nav_val.toType().getNamespace(zcu) == .none) {
            return sema.fail(&block, ty_src, "type {} has no namespace", .{nav_val.toType().fmt(pt)});
        }
        ip.resolveNavValue(nav_id, .{
            .val = nav_val.toIntern(),
            .alignment = .none,
            .@"linksection" = .none,
            .@"addrspace" = .generic,
        });
        // TODO: usingnamespace cannot participate in incremental compilation
        assert(zcu.analysis_in_progress.swapRemove(anal_unit));
        return .{
            .invalidate_nav_val = true,
            .invalidate_nav_ref = true,
        };
    }

    const queue_linker_work, const is_owned_fn = switch (ip.indexToKey(nav_val.toIntern())) {
        .func => |f| .{ true, f.owner_nav == nav_id }, // note that this lets function aliases reach codegen
        .variable => |v| .{ v.owner_nav == nav_id, false },
        .@"extern" => |e| .{
            false,
            Type.fromInterned(e.ty).zigTypeTag(zcu) == .@"fn" and zir_decl.linkage == .@"extern",
        },
        else => .{ true, false },
    };

    if (is_owned_fn) {
        // linksection etc are legal, except some targets do not support function alignment.
        if (zir_decl.align_body != null and !target_util.supportsFunctionAlignment(zcu.getTarget())) {
            return sema.fail(&block, align_src, "target does not support function alignment", .{});
        }
    } else if (try nav_ty.comptimeOnlySema(pt)) {
        // alignment, linksection, addrspace annotations are not allowed for comptime-only types.
        const reason: []const u8 = switch (ip.indexToKey(nav_val.toIntern())) {
            .func => "function alias", // slightly clearer message, since you *can* specify these on function *declarations*
            else => "comptime-only type",
        };
        if (zir_decl.align_body != null) {
            return sema.fail(&block, align_src, "cannot specify alignment of {s}", .{reason});
        }
        if (zir_decl.linksection_body != null) {
            return sema.fail(&block, section_src, "cannot specify linksection of {s}", .{reason});
        }
        if (zir_decl.addrspace_body != null) {
            return sema.fail(&block, addrspace_src, "cannot specify addrspace of {s}", .{reason});
        }
    }

    ip.resolveNavValue(nav_id, .{
        .val = nav_val.toIntern(),
        .alignment = alignment,
        .@"linksection" = @"linksection",
        .@"addrspace" = @"addrspace",
    });

    // Mark the unit as completed before evaluating the export!
    assert(zcu.analysis_in_progress.swapRemove(anal_unit));

    if (zir_decl.linkage == .@"export") {
        const export_src = block.src(.{ .token_offset = @intFromBool(zir_decl.is_pub) });
        const name_slice = zir.nullTerminatedString(zir_decl.name);
        const name_ip = try ip.getOrPutString(gpa, pt.tid, name_slice, .no_embedded_nulls);
        try sema.analyzeExport(&block, export_src, .{ .name = name_ip }, nav_id);
    }

    try sema.flushExports();

    queue_codegen: {
        if (!queue_linker_work) break :queue_codegen;

        if (!try nav_ty.hasRuntimeBitsSema(pt)) {
            if (zcu.comp.config.use_llvm) break :queue_codegen;
            if (file.mod.strip) break :queue_codegen;
        }

        // This job depends on any resolve_type_fully jobs queued up before it.
        try zcu.comp.queueJob(.{ .codegen_nav = nav_id });
    }

    switch (old_nav.status) {
        .unresolved => return .{
            .invalidate_nav_val = true,
            .invalidate_nav_ref = true,
        },
        .resolved => |old| {
            const new = ip.getNav(nav_id).status.resolved;
            return .{
                .invalidate_nav_val = new.val != old.val,
                .invalidate_nav_ref = ip.typeOf(new.val) != ip.typeOf(old.val) or
                    new.alignment != old.alignment or
                    new.@"linksection" != old.@"linksection" or
                    new.@"addrspace" != old.@"addrspace",
            };
        },
    }
}

pub fn ensureFuncBodyUpToDate(pt: Zcu.PerThread, maybe_coerced_func_index: InternPool.Index) Zcu.SemaError!void {
    dev.check(.sema);

    const tracy = trace(@src());
    defer tracy.end();

    const zcu = pt.zcu;
    const gpa = zcu.gpa;
    const ip = &zcu.intern_pool;

    // We only care about the uncoerced function.
    const func_index = ip.unwrapCoercedFunc(maybe_coerced_func_index);
    const anal_unit: AnalUnit = .wrap(.{ .func = func_index });

    log.debug("ensureFuncBodyUpToDate {}", .{zcu.fmtAnalUnit(anal_unit)});

    const func = zcu.funcInfo(maybe_coerced_func_index);

    const was_outdated = zcu.outdated.swapRemove(anal_unit) or
        zcu.potentially_outdated.swapRemove(anal_unit);

    const prev_failed = zcu.failed_analysis.contains(anal_unit) or zcu.transitive_failed_analysis.contains(anal_unit);

    if (was_outdated) {
        dev.check(.incremental);
        _ = zcu.outdated_ready.swapRemove(anal_unit);
        zcu.deleteUnitExports(anal_unit);
        zcu.deleteUnitReferences(anal_unit);
        if (zcu.failed_analysis.fetchSwapRemove(anal_unit)) |kv| {
            kv.value.destroy(gpa);
        }
        _ = zcu.transitive_failed_analysis.swapRemove(anal_unit);
    } else {
        // We can trust the current information about this function.
        if (prev_failed) {
            return error.AnalysisFail;
        }
        switch (func.analysisUnordered(ip).state) {
            .unreferenced => {}, // this is the first reference
            .queued => {}, // we're waiting on first-time analysis
            .analyzed => return, // up-to-date
        }
    }

    const func_prog_node = zcu.sema_prog_node.start(ip.getNav(func.owner_nav).fqn.toSlice(ip), 0);
    defer func_prog_node.end();

    const ies_outdated, const new_failed = if (pt.analyzeFuncBody(func_index)) |result|
        .{ prev_failed or result.ies_outdated, false }
    else |err| switch (err) {
        error.AnalysisFail => res: {
            if (!zcu.failed_analysis.contains(anal_unit)) {
                // If this function caused the error, it would have an entry in `failed_analysis`.
                // Since it does not, this must be a transitive failure.
                try zcu.transitive_failed_analysis.put(gpa, anal_unit, {});
                log.debug("mark transitive analysis failure for {}", .{zcu.fmtAnalUnit(anal_unit)});
            }
            // We consider the IES to be outdated if the function previously succeeded analysis; in this case,
            // we need to re-analyze dependants to ensure they hit a transitive error here, rather than reporting
            // a different error later (which may now be invalid).
            break :res .{ !prev_failed, true };
        },
        error.OutOfMemory => {
            // TODO: it's unclear how to gracefully handle this.
            // To report the error cleanly, we need to add a message to `failed_analysis` and a
            // corresponding entry to `retryable_failures`; but either of these things is quite
            // likely to OOM at this point.
            // If that happens, what do we do? Perhaps we could have a special field on `Zcu`
            // for reporting OOM errors without allocating.
            return error.OutOfMemory;
        },
    };

    if (was_outdated) {
        if (ies_outdated) {
            try zcu.markDependeeOutdated(.marked_po, .{ .interned = func_index });
        } else {
            try zcu.markPoDependeeUpToDate(.{ .interned = func_index });
        }
    }

    if (new_failed) return error.AnalysisFail;
}

fn analyzeFuncBody(
    pt: Zcu.PerThread,
    func_index: InternPool.Index,
) Zcu.SemaError!struct { ies_outdated: bool } {
    const zcu = pt.zcu;
    const gpa = zcu.gpa;
    const ip = &zcu.intern_pool;

    const func = zcu.funcInfo(func_index);
    const anal_unit = AnalUnit.wrap(.{ .func = func_index });

    // Make sure that this function is still owned by the same `Nav`. Otherwise, analyzing
    // it would be a waste of time in the best case, and could cause codegen to give bogus
    // results in the worst case.

    if (func.generic_owner == .none) {
        // Among another things, this ensures that the function's `zir_body_inst` is correct.
        try pt.ensureNavValUpToDate(func.owner_nav);
        if (ip.getNav(func.owner_nav).status.resolved.val != func_index) {
            // This function is no longer referenced! There's no point in re-analyzing it.
            // Just mark a transitive failure and move on.
            return error.AnalysisFail;
        }
    } else {
        const go_nav = zcu.funcInfo(func.generic_owner).owner_nav;
        // Among another things, this ensures that the function's `zir_body_inst` is correct.
        try pt.ensureNavValUpToDate(go_nav);
        if (ip.getNav(go_nav).status.resolved.val != func.generic_owner) {
            // The generic owner is no longer referenced, so this function is also unreferenced.
            // There's no point in re-analyzing it. Just mark a transitive failure and move on.
            return error.AnalysisFail;
        }
    }

    // We'll want to remember what the IES used to be before the update for
    // dependency invalidation purposes.
    const old_resolved_ies = if (func.analysisUnordered(ip).inferred_error_set)
        func.resolvedErrorSetUnordered(ip)
    else
        .none;

    log.debug("analyze and generate fn body {}", .{zcu.fmtAnalUnit(anal_unit)});

    var air = try pt.analyzeFnBodyInner(func_index);
    errdefer air.deinit(gpa);

    const ies_outdated = !func.analysisUnordered(ip).inferred_error_set or
        func.resolvedErrorSetUnordered(ip) != old_resolved_ies;

    const comp = zcu.comp;

    const dump_air = build_options.enable_debug_extensions and comp.verbose_air;
    const dump_llvm_ir = build_options.enable_debug_extensions and (comp.verbose_llvm_ir != null or comp.verbose_llvm_bc != null);

    if (comp.bin_file == null and zcu.llvm_object == null and !dump_air and !dump_llvm_ir) {
        air.deinit(gpa);
        return .{ .ies_outdated = ies_outdated };
    }

    // This job depends on any resolve_type_fully jobs queued up before it.
    try comp.queueJob(.{ .codegen_func = .{
        .func = func_index,
        .air = air,
    } });

    return .{ .ies_outdated = ies_outdated };
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
    const nav_index = func.owner_nav;
    const nav = ip.getNav(nav_index);

    var liveness = try Liveness.analyze(gpa, air, ip);
    defer liveness.deinit(gpa);

    if (build_options.enable_debug_extensions and comp.verbose_air) {
        std.debug.print("# Begin Function AIR: {}:\n", .{nav.fqn.fmt(ip)});
        @import("../print_air.zig").dump(pt, air, liveness);
        std.debug.print("# End Function AIR: {}\n\n", .{nav.fqn.fmt(ip)});
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
                try zcu.failed_codegen.putNoClobber(gpa, nav_index, try Zcu.ErrorMsg.create(
                    gpa,
                    zcu.navSrcLoc(nav_index),
                    "invalid liveness: {s}",
                    .{@errorName(err)},
                ));
                return;
            },
        };
    }

    const codegen_prog_node = zcu.codegen_prog_node.start(nav.fqn.toSlice(ip), 0);
    defer codegen_prog_node.end();

    if (!air.typesFullyResolved(zcu)) {
        // A type we depend on failed to resolve. This is a transitive failure.
        // Correcting this failure will involve changing a type this function
        // depends on, hence triggering re-analysis of this function, so this
        // interacts correctly with incremental compilation.
        // TODO: do we need to mark this failure anywhere? I don't think so, since compilation
        // will fail due to the type error anyway.
    } else if (comp.bin_file) |lf| {
        lf.updateFunc(pt, func_index, air, liveness) catch |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            error.AnalysisFail => {
                assert(zcu.failed_codegen.contains(nav_index));
            },
            else => {
                try zcu.failed_codegen.putNoClobber(gpa, nav_index, try Zcu.ErrorMsg.create(
                    gpa,
                    zcu.navSrcLoc(nav_index),
                    "unable to codegen: {s}",
                    .{@errorName(err)},
                ));
                try zcu.retryable_failures.append(zcu.gpa, AnalUnit.wrap(.{ .func = func_index }));
            },
        };
    } else if (zcu.llvm_object) |llvm_object| {
        llvm_object.updateFunc(pt, func_index, air, liveness) catch |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
        };
    }
}

/// https://github.com/ziglang/zig/issues/14307
pub fn semaPkg(pt: Zcu.PerThread, pkg: *Module) !void {
    dev.check(.sema);
    const import_file_result = try pt.importPkg(pkg);
    const root_type = pt.zcu.fileRootType(import_file_result.file_index);
    if (root_type == .none) {
        return pt.semaFile(import_file_result.file_index);
    }
}

fn createFileRootStruct(
    pt: Zcu.PerThread,
    file_index: Zcu.File.Index,
    namespace_index: Zcu.Namespace.Index,
    replace_existing: bool,
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
    var extra_index: usize = extended.operand + @typeInfo(Zir.Inst.StructDecl).@"struct".fields.len;
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

    const tracked_inst = try ip.trackZir(gpa, pt.tid, .{
        .file = file_index,
        .inst = .main_struct_inst,
    });
    const wip_ty = switch (try ip.getStructType(gpa, pt.tid, .{
        .layout = .auto,
        .fields_len = fields_len,
        .known_non_opv = small.known_non_opv,
        .requires_comptime = if (small.known_comptime_only) .yes else .unknown,
        .any_comptime_fields = small.any_comptime_fields,
        .any_default_inits = small.any_default_inits,
        .inits_resolved = false,
        .any_aligned_fields = small.any_aligned_fields,
        .key = .{ .declared = .{
            .zir_index = tracked_inst,
            .captures = &.{},
        } },
    }, replace_existing)) {
        .existing => unreachable, // we wouldn't be analysing the file root if this type existed
        .wip => |wip| wip,
    };
    errdefer wip_ty.cancel(ip, pt.tid);

    wip_ty.setName(ip, try file.internFullyQualifiedName(pt));
    ip.namespacePtr(namespace_index).owner_type = wip_ty.index;

    if (zcu.comp.incremental) {
        try ip.addDependency(
            gpa,
            .wrap(.{ .type = wip_ty.index }),
            .{ .src_hash = tracked_inst },
        );
    }

    try pt.scanNamespace(namespace_index, decls);
    try zcu.comp.queueJob(.{ .resolve_type_fully = wip_ty.index });
    codegen_type: {
        if (zcu.comp.config.use_llvm) break :codegen_type;
        if (file.mod.strip) break :codegen_type;
        // This job depends on any resolve_type_fully jobs queued up before it.
        try zcu.comp.queueJob(.{ .codegen_type = wip_ty.index });
    }
    zcu.setFileRootType(file_index, wip_ty.index);
    return wip_ty.finish(ip, namespace_index);
}

/// Re-scan the namespace of a file's root struct type on an incremental update.
/// The file must have successfully populated ZIR.
/// If the file's root struct type is not populated (the file is unreferenced), nothing is done.
/// This is called by `updateZirRefs` for all updated files before the main work loop.
/// This function does not perform any semantic analysis.
fn updateFileNamespace(pt: Zcu.PerThread, file_index: Zcu.File.Index) Allocator.Error!void {
    const zcu = pt.zcu;

    const file = zcu.fileByIndex(file_index);
    assert(file.status == .success_zir);
    const file_root_type = zcu.fileRootType(file_index);
    if (file_root_type == .none) return;

    log.debug("updateFileNamespace mod={s} sub_file_path={s}", .{
        file.mod.fully_qualified_name,
        file.sub_file_path,
    });

    const namespace_index = Type.fromInterned(file_root_type).getNamespaceIndex(zcu);
    const decls = decls: {
        const extended = file.zir.instructions.items(.data)[@intFromEnum(Zir.Inst.Index.main_struct_inst)].extended;
        const small: Zir.Inst.StructDecl.Small = @bitCast(extended.small);

        var extra_index: usize = extended.operand + @typeInfo(Zir.Inst.StructDecl).@"struct".fields.len;
        extra_index += @intFromBool(small.has_fields_len);
        const decls_len = if (small.has_decls_len) blk: {
            const decls_len = file.zir.extra[extra_index];
            extra_index += 1;
            break :blk decls_len;
        } else 0;
        break :decls file.zir.bodySlice(extra_index, decls_len);
    };
    try pt.scanNamespace(namespace_index, decls);
    zcu.namespacePtr(namespace_index).generation = zcu.generation;
}

fn semaFile(pt: Zcu.PerThread, file_index: Zcu.File.Index) Zcu.SemaError!void {
    const tracy = trace(@src());
    defer tracy.end();

    const zcu = pt.zcu;
    const gpa = zcu.gpa;
    const file = zcu.fileByIndex(file_index);
    assert(zcu.fileRootType(file_index) == .none);

    if (file.status != .success_zir) {
        return error.AnalysisFail;
    }
    assert(file.zir_loaded);

    const new_namespace_index = try pt.createNamespace(.{
        .parent = .none,
        .owner_type = undefined, // set in `createFileRootStruct`
        .file_scope = file_index,
        .generation = zcu.generation,
    });
    const struct_ty = try pt.createFileRootStruct(file_index, new_namespace_index, false);
    errdefer zcu.intern_pool.remove(pt.tid, struct_ty);

    switch (zcu.comp.cache_use) {
        .whole => |whole| if (whole.cache_manifest) |man| {
            const source = file.getSource(gpa) catch |err| {
                try pt.reportRetryableFileError(file_index, "unable to load source: {s}", .{@errorName(err)});
                return error.AnalysisFail;
            };

            const resolved_path = std.fs.path.resolve(gpa, &.{
                file.mod.root.root_dir.path orelse ".",
                file.mod.root.sub_path,
                file.sub_file_path,
            }) catch |err| {
                try pt.reportRetryableFileError(file_index, "unable to resolve path: {s}", .{@errorName(err)});
                return error.AnalysisFail;
            };
            errdefer gpa.free(resolved_path);

            whole.cache_manifest_mutex.lock();
            defer whole.cache_manifest_mutex.unlock();
            man.addFilePostContents(resolved_path, source.bytes, source.stat) catch |err| switch (err) {
                error.OutOfMemory => |e| return e,
                else => {
                    try pt.reportRetryableFileError(file_index, "unable to update cache: {s}", .{@errorName(err)});
                    return error.AnalysisFail;
                },
            };
        },
        .incremental => {},
    }
}

pub fn importPkg(pt: Zcu.PerThread, mod: *Module) !Zcu.ImportFileResult {
    const zcu = pt.zcu;
    const gpa = zcu.gpa;

    // The resolved path is used as the key in the import table, to detect if
    // an import refers to the same as another, despite different relative paths
    // or differently mapped package names.
    const resolved_path = try std.fs.path.resolve(gpa, &.{
        mod.root.root_dir.path orelse ".",
        mod.root.sub_path,
        mod.root_src_path,
    });
    var keep_resolved_path = false;
    defer if (!keep_resolved_path) gpa.free(resolved_path);

    const gop = try zcu.import_table.getOrPut(gpa, resolved_path);
    errdefer _ = zcu.import_table.pop();
    if (gop.found_existing) {
        const file_index = gop.value_ptr.*;
        const file = zcu.fileByIndex(file_index);
        try file.addReference(zcu, .{ .root = mod });
        return .{
            .file = file,
            .file_index = file_index,
            .is_new = false,
            .is_pkg = true,
        };
    }

    const ip = &zcu.intern_pool;
    if (mod.builtin_file) |builtin_file| {
        const path_digest = Zcu.computePathDigest(zcu, mod, builtin_file.sub_file_path);
        const file_index = try ip.createFile(gpa, pt.tid, .{
            .bin_digest = path_digest,
            .file = builtin_file,
            .root_type = .none,
        });
        keep_resolved_path = true; // It's now owned by import_table.
        gop.value_ptr.* = file_index;
        try builtin_file.addReference(zcu, .{ .root = mod });
        return .{
            .file = builtin_file,
            .file_index = file_index,
            .is_new = false,
            .is_pkg = true,
        };
    }

    const sub_file_path = try gpa.dupe(u8, mod.root_src_path);
    errdefer gpa.free(sub_file_path);

    const comp = zcu.comp;
    if (comp.file_system_inputs) |fsi|
        try comp.appendFileSystemInput(fsi, mod.root, sub_file_path);

    const new_file = try gpa.create(Zcu.File);
    errdefer gpa.destroy(new_file);

    const path_digest = zcu.computePathDigest(mod, sub_file_path);
    const new_file_index = try ip.createFile(gpa, pt.tid, .{
        .bin_digest = path_digest,
        .file = new_file,
        .root_type = .none,
    });
    keep_resolved_path = true; // It's now owned by import_table.
    gop.value_ptr.* = new_file_index;
    new_file.* = .{
        .sub_file_path = sub_file_path,
        .source = undefined,
        .source_loaded = false,
        .tree_loaded = false,
        .zir_loaded = false,
        .stat = undefined,
        .tree = undefined,
        .zir = undefined,
        .status = .never_loaded,
        .prev_status = .never_loaded,
        .mod = mod,
    };

    try new_file.addReference(zcu, .{ .root = mod });
    return .{
        .file = new_file,
        .file_index = new_file_index,
        .is_new = true,
        .is_pkg = true,
    };
}

/// Called from a worker thread during AstGen.
/// Also called from Sema during semantic analysis.
pub fn importFile(
    pt: Zcu.PerThread,
    cur_file: *Zcu.File,
    import_string: []const u8,
) !Zcu.ImportFileResult {
    const zcu = pt.zcu;
    const mod = cur_file.mod;

    if (std.mem.eql(u8, import_string, "std")) {
        return pt.importPkg(zcu.std_mod);
    }
    if (std.mem.eql(u8, import_string, "root")) {
        return pt.importPkg(zcu.root_mod);
    }
    if (mod.deps.get(import_string)) |pkg| {
        return pt.importPkg(pkg);
    }
    if (!std.mem.endsWith(u8, import_string, ".zig")) {
        return error.ModuleNotFound;
    }
    const gpa = zcu.gpa;

    // The resolved path is used as the key in the import table, to detect if
    // an import refers to the same as another, despite different relative paths
    // or differently mapped package names.
    const resolved_path = try std.fs.path.resolve(gpa, &.{
        mod.root.root_dir.path orelse ".",
        mod.root.sub_path,
        cur_file.sub_file_path,
        "..",
        import_string,
    });

    var keep_resolved_path = false;
    defer if (!keep_resolved_path) gpa.free(resolved_path);

    const gop = try zcu.import_table.getOrPut(gpa, resolved_path);
    errdefer _ = zcu.import_table.pop();
    if (gop.found_existing) {
        const file_index = gop.value_ptr.*;
        return .{
            .file = zcu.fileByIndex(file_index),
            .file_index = file_index,
            .is_new = false,
            .is_pkg = false,
        };
    }

    const ip = &zcu.intern_pool;

    const new_file = try gpa.create(Zcu.File);
    errdefer gpa.destroy(new_file);

    const resolved_root_path = try std.fs.path.resolve(gpa, &.{
        mod.root.root_dir.path orelse ".",
        mod.root.sub_path,
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
    errdefer gpa.free(sub_file_path);

    log.debug("new importFile. resolved_root_path={s}, resolved_path={s}, sub_file_path={s}, import_string={s}", .{
        resolved_root_path, resolved_path, sub_file_path, import_string,
    });

    const comp = zcu.comp;
    if (comp.file_system_inputs) |fsi|
        try comp.appendFileSystemInput(fsi, mod.root, sub_file_path);

    const path_digest = zcu.computePathDigest(mod, sub_file_path);
    const new_file_index = try ip.createFile(gpa, pt.tid, .{
        .bin_digest = path_digest,
        .file = new_file,
        .root_type = .none,
    });
    keep_resolved_path = true; // It's now owned by import_table.
    gop.value_ptr.* = new_file_index;
    new_file.* = .{
        .sub_file_path = sub_file_path,
        .source = undefined,
        .source_loaded = false,
        .tree_loaded = false,
        .zir_loaded = false,
        .stat = undefined,
        .tree = undefined,
        .zir = undefined,
        .status = .never_loaded,
        .prev_status = .never_loaded,
        .mod = mod,
    };

    return .{
        .file = new_file,
        .file_index = new_file_index,
        .is_new = true,
        .is_pkg = false,
    };
}

pub fn embedFile(
    pt: Zcu.PerThread,
    cur_file: *Zcu.File,
    import_string: []const u8,
    src_loc: Zcu.LazySrcLoc,
) !InternPool.Index {
    const zcu = pt.zcu;
    const gpa = zcu.gpa;

    if (cur_file.mod.deps.get(import_string)) |pkg| {
        const resolved_path = try std.fs.path.resolve(gpa, &.{
            pkg.root.root_dir.path orelse ".",
            pkg.root.sub_path,
            pkg.root_src_path,
        });
        var keep_resolved_path = false;
        defer if (!keep_resolved_path) gpa.free(resolved_path);

        const gop = try zcu.embed_table.getOrPut(gpa, resolved_path);
        errdefer {
            assert(std.mem.eql(u8, zcu.embed_table.pop().key, resolved_path));
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

    const gop = try zcu.embed_table.getOrPut(gpa, resolved_path);
    errdefer {
        assert(std.mem.eql(u8, zcu.embed_table.pop().key, resolved_path));
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

/// https://github.com/ziglang/zig/issues/14307
fn newEmbedFile(
    pt: Zcu.PerThread,
    pkg: *Module,
    sub_file_path: []const u8,
    resolved_path: []const u8,
    result: **Zcu.EmbedFile,
    src_loc: Zcu.LazySrcLoc,
) !InternPool.Index {
    const zcu = pt.zcu;
    const gpa = zcu.gpa;
    const ip = &zcu.intern_pool;

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

    const comp = zcu.comp;
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
        .base_addr = .{ .uav = .{
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
) Allocator.Error!void {
    const tracy = trace(@src());
    defer tracy.end();

    const zcu = pt.zcu;
    const ip = &zcu.intern_pool;
    const gpa = zcu.gpa;
    const namespace = zcu.namespacePtr(namespace_index);

    // For incremental updates, `scanDecl` wants to look up existing decls by their ZIR index rather
    // than their name. We'll build an efficient mapping now, then discard the current `decls`.
    // We map to the `AnalUnit`, since not every declaration has a `Nav`.
    var existing_by_inst: std.AutoHashMapUnmanaged(InternPool.TrackedInst.Index, InternPool.AnalUnit) = .empty;
    defer existing_by_inst.deinit(gpa);

    try existing_by_inst.ensureTotalCapacity(gpa, @intCast(
        namespace.pub_decls.count() + namespace.priv_decls.count() +
            namespace.pub_usingnamespace.items.len + namespace.priv_usingnamespace.items.len +
            namespace.comptime_decls.items.len +
            namespace.test_decls.items.len,
    ));

    for (namespace.pub_decls.keys()) |nav| {
        const zir_index = ip.getNav(nav).analysis.?.zir_index;
        existing_by_inst.putAssumeCapacityNoClobber(zir_index, .wrap(.{ .nav_val = nav }));
    }
    for (namespace.priv_decls.keys()) |nav| {
        const zir_index = ip.getNav(nav).analysis.?.zir_index;
        existing_by_inst.putAssumeCapacityNoClobber(zir_index, .wrap(.{ .nav_val = nav }));
    }
    for (namespace.pub_usingnamespace.items) |nav| {
        const zir_index = ip.getNav(nav).analysis.?.zir_index;
        existing_by_inst.putAssumeCapacityNoClobber(zir_index, .wrap(.{ .nav_val = nav }));
    }
    for (namespace.priv_usingnamespace.items) |nav| {
        const zir_index = ip.getNav(nav).analysis.?.zir_index;
        existing_by_inst.putAssumeCapacityNoClobber(zir_index, .wrap(.{ .nav_val = nav }));
    }
    for (namespace.comptime_decls.items) |cu| {
        const zir_index = ip.getComptimeUnit(cu).zir_index;
        existing_by_inst.putAssumeCapacityNoClobber(zir_index, .wrap(.{ .@"comptime" = cu }));
    }
    for (namespace.test_decls.items) |nav| {
        const zir_index = ip.getNav(nav).analysis.?.zir_index;
        existing_by_inst.putAssumeCapacityNoClobber(zir_index, .wrap(.{ .nav_val = nav }));
        // This test will be re-added to `test_functions` later on if it's still alive. Remove it for now.
        _ = zcu.test_functions.swapRemove(nav);
    }

    var seen_decls: std.AutoHashMapUnmanaged(InternPool.NullTerminatedString, void) = .empty;
    defer seen_decls.deinit(gpa);

    namespace.pub_decls.clearRetainingCapacity();
    namespace.priv_decls.clearRetainingCapacity();
    namespace.pub_usingnamespace.clearRetainingCapacity();
    namespace.priv_usingnamespace.clearRetainingCapacity();
    namespace.comptime_decls.clearRetainingCapacity();
    namespace.test_decls.clearRetainingCapacity();

    var scan_decl_iter: ScanDeclIter = .{
        .pt = pt,
        .namespace_index = namespace_index,
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
}

const ScanDeclIter = struct {
    pt: Zcu.PerThread,
    namespace_index: Zcu.Namespace.Index,
    seen_decls: *std.AutoHashMapUnmanaged(InternPool.NullTerminatedString, void),
    existing_by_inst: *const std.AutoHashMapUnmanaged(InternPool.TrackedInst.Index, InternPool.AnalUnit),
    /// Decl scanning is run in two passes, so that we can detect when a generated
    /// name would clash with an explicit name and use a different one.
    pass: enum { named, unnamed },
    usingnamespace_index: usize = 0,
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
        const comp = zcu.comp;
        const namespace_index = iter.namespace_index;
        const namespace = zcu.namespacePtr(namespace_index);
        const gpa = zcu.gpa;
        const file = namespace.fileScope(zcu);
        const zir = file.zir;
        const ip = &zcu.intern_pool;

        const decl = zir.getDeclaration(decl_inst);

        const maybe_name: InternPool.OptionalNullTerminatedString = switch (decl.kind) {
            .@"comptime" => name: {
                if (iter.pass != .unnamed) return;
                break :name .none;
            },
            .@"usingnamespace" => name: {
                if (iter.pass != .unnamed) return;
                const i = iter.usingnamespace_index;
                iter.usingnamespace_index += 1;
                break :name (try iter.avoidNameConflict("usingnamespace_{d}", .{i})).toOptional();
            },
            .unnamed_test => name: {
                if (iter.pass != .unnamed) return;
                const i = iter.unnamed_test_index;
                iter.unnamed_test_index += 1;
                break :name (try iter.avoidNameConflict("test_{d}", .{i})).toOptional();
            },
            .@"test", .decltest => |kind| name: {
                // We consider these to be unnamed since the decl name can be adjusted to avoid conflicts if necessary.
                if (iter.pass != .unnamed) return;
                const prefix = @tagName(kind);
                break :name (try iter.avoidNameConflict("{s}.{s}", .{ prefix, zir.nullTerminatedString(decl.name) })).toOptional();
            },
            .@"const", .@"var" => name: {
                if (iter.pass != .named) return;
                const name = try ip.getOrPutString(
                    gpa,
                    pt.tid,
                    zir.nullTerminatedString(decl.name),
                    .no_embedded_nulls,
                );
                try iter.seen_decls.putNoClobber(gpa, name, {});
                break :name name.toOptional();
            },
        };

        const tracked_inst = try ip.trackZir(gpa, pt.tid, .{
            .file = namespace.file_scope,
            .inst = decl_inst,
        });

        const existing_unit = iter.existing_by_inst.get(tracked_inst);

        const unit, const want_analysis = switch (decl.kind) {
            .@"comptime" => unit: {
                const cu = if (existing_unit) |eu|
                    eu.unwrap().@"comptime"
                else
                    try ip.createComptimeUnit(gpa, pt.tid, tracked_inst, namespace_index);

                const unit: AnalUnit = .wrap(.{ .@"comptime" = cu });

                try namespace.comptime_decls.append(gpa, cu);

                if (existing_unit == null) {
                    // For a `comptime` declaration, whether to analyze is based solely on whether the unit
                    // is outdated. So, add this fresh one to `outdated` and `outdated_ready`.
                    try zcu.outdated.ensureUnusedCapacity(gpa, 1);
                    try zcu.outdated_ready.ensureUnusedCapacity(gpa, 1);
                    zcu.outdated.putAssumeCapacityNoClobber(unit, 0);
                    zcu.outdated_ready.putAssumeCapacityNoClobber(unit, {});
                }

                break :unit .{ unit, true };
            },
            else => unit: {
                const name = maybe_name.unwrap().?;
                const fqn = try namespace.internFullyQualifiedName(ip, gpa, pt.tid, name);
                const nav = if (existing_unit) |eu|
                    eu.unwrap().nav_val
                else
                    try ip.createDeclNav(gpa, pt.tid, name, fqn, tracked_inst, namespace_index, decl.kind == .@"usingnamespace");

                const unit: AnalUnit = .wrap(.{ .nav_val = nav });

                assert(ip.getNav(nav).name == name);
                assert(ip.getNav(nav).fqn == fqn);

                const want_analysis = switch (decl.kind) {
                    .@"comptime" => unreachable,
                    .@"usingnamespace" => a: {
                        if (comp.incremental) {
                            @panic("'usingnamespace' is not supported by incremental compilation");
                        }
                        if (decl.is_pub) {
                            try namespace.pub_usingnamespace.append(gpa, nav);
                        } else {
                            try namespace.priv_usingnamespace.append(gpa, nav);
                        }
                        break :a true;
                    },
                    .unnamed_test, .@"test", .decltest => a: {
                        const is_named = decl.kind != .unnamed_test;
                        try namespace.test_decls.append(gpa, nav);
                        // TODO: incremental compilation!
                        // * remove from `test_functions` if no longer matching filter
                        // * add to `test_functions` if newly passing filter
                        // This logic is unaware of incremental: we'll end up with duplicates.
                        // Perhaps we should add all test indiscriminately and filter at the end of the update.
                        if (!comp.config.is_test) break :a false;
                        if (file.mod != zcu.main_mod) break :a false;
                        if (is_named and comp.test_filters.len > 0) {
                            const fqn_slice = fqn.toSlice(ip);
                            for (comp.test_filters) |test_filter| {
                                if (std.mem.indexOf(u8, fqn_slice, test_filter) != null) break;
                            } else break :a false;
                        }
                        try zcu.test_functions.put(gpa, nav, {});
                        break :a true;
                    },
                    .@"const", .@"var" => a: {
                        if (decl.is_pub) {
                            try namespace.pub_decls.putContext(gpa, nav, {}, .{ .zcu = zcu });
                        } else {
                            try namespace.priv_decls.putContext(gpa, nav, {}, .{ .zcu = zcu });
                        }
                        break :a false;
                    },
                };
                break :unit .{ unit, want_analysis };
            },
        };

        if (existing_unit == null and (want_analysis or decl.linkage == .@"export")) {
            log.debug(
                "scanDecl queue analyze_comptime_unit file='{s}' unit={}",
                .{ namespace.fileScope(zcu).sub_file_path, zcu.fmtAnalUnit(unit) },
            );
            try comp.queueJob(.{ .analyze_comptime_unit = unit });
        }

        // TODO: we used to do line number updates here, but this is an inappropriate place for this logic to live.
    }
};

fn analyzeFnBodyInner(pt: Zcu.PerThread, func_index: InternPool.Index) Zcu.SemaError!Air {
    const tracy = trace(@src());
    defer tracy.end();

    const zcu = pt.zcu;
    const gpa = zcu.gpa;
    const ip = &zcu.intern_pool;

    const anal_unit = AnalUnit.wrap(.{ .func = func_index });
    const func = zcu.funcInfo(func_index);
    const inst_info = func.zir_body_inst.resolveFull(ip) orelse return error.AnalysisFail;
    const file = zcu.fileByIndex(inst_info.file);
    const zir = file.zir;

    try zcu.analysis_in_progress.put(gpa, anal_unit, {});
    errdefer _ = zcu.analysis_in_progress.swapRemove(anal_unit);

    func.setAnalysisState(ip, .analyzed);
    if (func.analysisUnordered(ip).inferred_error_set) {
        func.setResolvedErrorSet(ip, .none);
    }

    // This is the `Nau` corresponding to the `declaration` instruction which the function or its generic owner originates from.
    const decl_nav = ip.getNav(if (func.generic_owner == .none)
        func.owner_nav
    else
        zcu.funcInfo(func.generic_owner).owner_nav);

    const func_nav = ip.getNav(func.owner_nav);

    zcu.intern_pool.removeDependenciesForDepender(gpa, anal_unit);

    var analysis_arena = std.heap.ArenaAllocator.init(gpa);
    defer analysis_arena.deinit();

    var comptime_err_ret_trace = std.ArrayList(Zcu.LazySrcLoc).init(gpa);
    defer comptime_err_ret_trace.deinit();

    // In the case of a generic function instance, this is the type of the
    // instance, which has comptime parameters elided. In other words, it is
    // the runtime-known parameters only, not to be confused with the
    // generic_owner function type, which potentially has more parameters,
    // including comptime parameters.
    const fn_ty = Type.fromInterned(func.ty);
    const fn_ty_info = zcu.typeToFunc(fn_ty).?;

    var sema: Sema = .{
        .pt = pt,
        .gpa = gpa,
        .arena = analysis_arena.allocator(),
        .code = zir,
        .owner = anal_unit,
        .func_index = func_index,
        .func_is_naked = fn_ty_info.cc == .naked,
        .fn_ret_ty = Type.fromInterned(fn_ty_info.return_type),
        .fn_ret_ty_ies = null,
        .branch_quota = @max(func.branchQuotaUnordered(ip), Sema.default_branch_quota),
        .comptime_err_ret_trace = &comptime_err_ret_trace,
    };
    defer sema.deinit();

    // Every runtime function has a dependency on the source of the Decl it originates from.
    // It also depends on the value of its owner Decl.
    try sema.declareDependency(.{ .src_hash = decl_nav.analysis.?.zir_index });
    try sema.declareDependency(.{ .nav_val = func.owner_nav });

    if (func.analysisUnordered(ip).inferred_error_set) {
        const ies = try analysis_arena.allocator().create(Sema.InferredErrorSet);
        ies.* = .{ .func = func_index };
        sema.fn_ret_ty_ies = ies;
    }

    // reset in case calls to errorable functions are removed.
    func.setCallsOrAwaitsErrorableFn(ip, false);

    // First few indexes of extra are reserved and set at the end.
    const reserved_count = @typeInfo(Air.ExtraIndex).@"enum".fields.len;
    try sema.air_extra.ensureTotalCapacity(gpa, reserved_count);
    sema.air_extra.items.len += reserved_count;

    var inner_block: Sema.Block = .{
        .parent = null,
        .sema = &sema,
        .namespace = decl_nav.analysis.?.namespace,
        .instructions = .{},
        .inlining = null,
        .is_comptime = false,
        .src_base_inst = decl_nav.analysis.?.zir_index,
        .type_name_ctx = func_nav.fqn,
    };
    defer inner_block.instructions.deinit(gpa);

    const fn_info = sema.code.getFnInfo(func.zirBodyInstUnordered(ip).resolve(ip) orelse return error.AnalysisFail);

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
    for (fn_info.param_body[0..src_params_len]) |inst| {
        const gop = sema.inst_map.getOrPutAssumeCapacity(inst);
        if (gop.found_existing) continue; // provided above by comptime arg

        const param_inst_info = sema.code.instructions.get(@intFromEnum(inst));
        const param_name: Zir.NullTerminatedString = switch (param_inst_info.tag) {
            .param_anytype => param_inst_info.data.str_tok.start,
            .param => sema.code.extraData(Zir.Inst.Param, param_inst_info.data.pl_tok.payload_index).data.name,
            else => unreachable,
        };

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
                .name = if (inner_block.ownerModule().strip)
                    .none
                else
                    try sema.appendAirString(sema.code.nullTerminatedString(param_name)),
            } },
        });
    }

    const last_arg_index = inner_block.instructions.items.len;

    // Save the error trace as our first action in the function.
    // If this is unnecessary after all, Liveness will clean it up for us.
    const error_return_trace_index = try sema.analyzeSaveErrRetIndex(&inner_block);
    sema.error_return_trace_index_on_fn_entry = error_return_trace_index;
    inner_block.error_return_trace_index = error_return_trace_index;

    sema.analyzeFnBody(&inner_block, fn_info.body) catch |err| switch (err) {
        error.GenericPoison => unreachable,
        error.ComptimeReturn => unreachable,
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

    func.setBranchHint(ip, sema.branch_hint orelse .none);

    // If we don't get an error return trace from a caller, create our own.
    if (func.analysisUnordered(ip).calls_or_awaits_errorable_fn and
        zcu.comp.config.any_error_tracing and
        !sema.fn_ret_ty.isError(zcu))
    {
        sema.setupErrorReturnTrace(&inner_block, last_arg_index) catch |err| switch (err) {
            error.GenericPoison => unreachable,
            error.ComptimeReturn => unreachable,
            error.ComptimeBreak => unreachable,
            else => |e| return e,
        };
    }

    // Copy the block into place and mark that as the main block.
    try sema.air_extra.ensureUnusedCapacity(gpa, @typeInfo(Air.Block).@"struct".fields.len +
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
            else => |e| return e,
        };
        assert(ies.resolved != .none);
        func.setResolvedErrorSet(ip, ies.resolved);
    }

    assert(zcu.analysis_in_progress.swapRemove(anal_unit));

    // Finally we must resolve the return type and parameter types so that backends
    // have full access to type information.
    // Crucially, this happens *after* we set the function state to success above,
    // so that dependencies on the function body will now be satisfied rather than
    // result in circular dependency errors.
    // TODO: this can go away once we fix backends having to resolve `StackTrace`.
    // The codegen timing guarantees that the parameter types will be populated.
    sema.resolveFnTypes(fn_ty) catch |err| switch (err) {
        error.GenericPoison => unreachable,
        error.ComptimeReturn => unreachable,
        error.ComptimeBreak => unreachable,
        else => |e| return e,
    };

    try sema.flushExports();

    return .{
        .instructions = sema.air_instructions.toOwnedSlice(),
        .extra = try sema.air_extra.toOwnedSlice(gpa),
    };
}

pub fn createNamespace(pt: Zcu.PerThread, initialization: Zcu.Namespace) !Zcu.Namespace.Index {
    return pt.zcu.intern_pool.createNamespace(pt.zcu.gpa, pt.tid, initialization);
}

pub fn destroyNamespace(pt: Zcu.PerThread, namespace_index: Zcu.Namespace.Index) void {
    return pt.zcu.intern_pool.destroyNamespace(pt.tid, namespace_index);
}

pub fn getErrorValue(
    pt: Zcu.PerThread,
    name: InternPool.NullTerminatedString,
) Allocator.Error!Zcu.ErrorInt {
    return pt.zcu.intern_pool.getErrorValue(pt.zcu.gpa, pt.tid, name);
}

pub fn getErrorValueFromSlice(pt: Zcu.PerThread, name: []const u8) Allocator.Error!Zcu.ErrorInt {
    return pt.getErrorValue(try pt.zcu.intern_pool.getOrPutString(pt.zcu.gpa, name));
}

/// Removes any entry from `Zcu.failed_files` associated with `file`. Acquires `Compilation.mutex` as needed.
/// `file.zir` must be unchanged from the last update, as it is used to determine if there is such an entry.
fn lockAndClearFileCompileError(pt: Zcu.PerThread, file: *Zcu.File) void {
    if (!file.zir_loaded or !file.zir.hasCompileErrors()) return;
    pt.zcu.comp.mutex.lock();
    defer pt.zcu.comp.mutex.unlock();
    if (pt.zcu.failed_files.fetchSwapRemove(file)) |kv| {
        if (kv.value) |msg| msg.destroy(pt.zcu.gpa); // Delete previous error message.
    }
}

/// Called from `Compilation.update`, after everything is done, just before
/// reporting compile errors. In this function we emit exported symbol collision
/// errors and communicate exported symbols to the linker backend.
pub fn processExports(pt: Zcu.PerThread) !void {
    const zcu = pt.zcu;
    const gpa = zcu.gpa;

    // First, construct a mapping of every exported value and Nav to the indices of all its different exports.
    var nav_exports: std.AutoArrayHashMapUnmanaged(InternPool.Nav.Index, std.ArrayListUnmanaged(u32)) = .empty;
    var uav_exports: std.AutoArrayHashMapUnmanaged(InternPool.Index, std.ArrayListUnmanaged(u32)) = .empty;
    defer {
        for (nav_exports.values()) |*exports| {
            exports.deinit(gpa);
        }
        nav_exports.deinit(gpa);
        for (uav_exports.values()) |*exports| {
            exports.deinit(gpa);
        }
        uav_exports.deinit(gpa);
    }

    // We note as a heuristic:
    // * It is rare to export a value.
    // * It is rare for one Nav to be exported multiple times.
    // So, this ensureTotalCapacity serves as a reasonable (albeit very approximate) optimization.
    try nav_exports.ensureTotalCapacity(gpa, zcu.single_exports.count() + zcu.multi_exports.count());

    for (zcu.single_exports.values()) |export_idx| {
        const exp = zcu.all_exports.items[export_idx];
        const value_ptr, const found_existing = switch (exp.exported) {
            .nav => |nav| gop: {
                const gop = try nav_exports.getOrPut(gpa, nav);
                break :gop .{ gop.value_ptr, gop.found_existing };
            },
            .uav => |uav| gop: {
                const gop = try uav_exports.getOrPut(gpa, uav);
                break :gop .{ gop.value_ptr, gop.found_existing };
            },
        };
        if (!found_existing) value_ptr.* = .{};
        try value_ptr.append(gpa, export_idx);
    }

    for (zcu.multi_exports.values()) |info| {
        for (zcu.all_exports.items[info.index..][0..info.len], info.index..) |exp, export_idx| {
            const value_ptr, const found_existing = switch (exp.exported) {
                .nav => |nav| gop: {
                    const gop = try nav_exports.getOrPut(gpa, nav);
                    break :gop .{ gop.value_ptr, gop.found_existing };
                },
                .uav => |uav| gop: {
                    const gop = try uav_exports.getOrPut(gpa, uav);
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

    for (nav_exports.keys(), nav_exports.values()) |exported_nav, exports_list| {
        const exported: Zcu.Exported = .{ .nav = exported_nav };
        try pt.processExportsInner(&symbol_exports, exported, exports_list.items);
    }

    for (uav_exports.keys(), uav_exports.values()) |exported_uav, exports_list| {
        const exported: Zcu.Exported = .{ .uav = exported_uav };
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
    const ip = &zcu.intern_pool;

    for (export_indices) |export_idx| {
        const new_export = &zcu.all_exports.items[export_idx];
        const gop = try symbol_exports.getOrPut(gpa, new_export.opts.name);
        if (gop.found_existing) {
            new_export.status = .failed_retryable;
            try zcu.failed_exports.ensureUnusedCapacity(gpa, 1);
            const msg = try Zcu.ErrorMsg.create(gpa, new_export.src, "exported symbol collision: {}", .{
                new_export.opts.name.fmt(ip),
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

    switch (exported) {
        .nav => |nav_index| if (failed: {
            const nav = ip.getNav(nav_index);
            if (zcu.failed_codegen.contains(nav_index)) break :failed true;
            if (nav.analysis != null) {
                const unit: AnalUnit = .wrap(.{ .nav_val = nav_index });
                if (zcu.failed_analysis.contains(unit)) break :failed true;
                if (zcu.transitive_failed_analysis.contains(unit)) break :failed true;
            }
            const val = switch (nav.status) {
                .unresolved => break :failed true,
                .resolved => |r| Value.fromInterned(r.val),
            };
            // If the value is a function, we also need to check if that function succeeded analysis.
            if (val.typeOf(zcu).zigTypeTag(zcu) == .@"fn") {
                const func_unit = AnalUnit.wrap(.{ .func = val.toIntern() });
                if (zcu.failed_analysis.contains(func_unit)) break :failed true;
                if (zcu.transitive_failed_analysis.contains(func_unit)) break :failed true;
            }
            break :failed false;
        }) {
            // This `Decl` is failed, so was never sent to codegen.
            // TODO: we should probably tell the backend to delete any old exports of this `Decl`?
            return;
        },
        .uav => {},
    }

    if (zcu.comp.bin_file) |lf| {
        try zcu.handleUpdateExports(export_indices, lf.updateExports(pt, exported, export_indices));
    } else if (zcu.llvm_object) |llvm_object| {
        try zcu.handleUpdateExports(export_indices, llvm_object.updateExports(pt, exported, export_indices));
    }
}

pub fn populateTestFunctions(
    pt: Zcu.PerThread,
    main_progress_node: std.Progress.Node,
) Allocator.Error!void {
    const zcu = pt.zcu;
    const gpa = zcu.gpa;
    const ip = &zcu.intern_pool;
    const builtin_mod = zcu.root_mod.getBuiltinDependency();
    const builtin_file_index = (pt.importPkg(builtin_mod) catch unreachable).file_index;
    pt.ensureFileAnalyzed(builtin_file_index) catch |err| switch (err) {
        error.AnalysisFail => unreachable, // builtin module is generated so cannot be corrupt
        error.OutOfMemory => |e| return e,
    };
    const builtin_root_type = Type.fromInterned(zcu.fileRootType(builtin_file_index));
    const builtin_namespace = builtin_root_type.getNamespace(zcu).unwrap().?;
    const nav_index = zcu.namespacePtr(builtin_namespace).pub_decls.getKeyAdapted(
        try ip.getOrPutString(gpa, pt.tid, "test_functions", .no_embedded_nulls),
        Zcu.Namespace.NameAdapter{ .zcu = zcu },
    ).?;
    {
        // We have to call `ensureNavValUpToDate` here in case `builtin.test_functions`
        // was not referenced by start code.
        zcu.sema_prog_node = main_progress_node.start("Semantic Analysis", 0);
        defer {
            zcu.sema_prog_node.end();
            zcu.sema_prog_node = std.Progress.Node.none;
        }
        pt.ensureNavValUpToDate(nav_index) catch |err| switch (err) {
            error.AnalysisFail => return,
            error.OutOfMemory => return error.OutOfMemory,
        };
    }

    const test_fns_val = zcu.navValue(nav_index);
    const test_fn_ty = test_fns_val.typeOf(zcu).slicePtrFieldType(zcu).childType(zcu);

    const array_anon_decl: InternPool.Key.Ptr.BaseAddr.Uav = array: {
        // Add zcu.test_functions to an array decl then make the test_functions
        // decl reference it as a slice.
        const test_fn_vals = try gpa.alloc(InternPool.Index, zcu.test_functions.count());
        defer gpa.free(test_fn_vals);

        for (test_fn_vals, zcu.test_functions.keys()) |*test_fn_val, test_nav_index| {
            const test_nav = ip.getNav(test_nav_index);

            {
                // The test declaration might have failed; if that's the case, just return, as we'll
                // be emitting a compile error anyway.
                const anal_unit: AnalUnit = .wrap(.{ .nav_val = test_nav_index });
                if (zcu.failed_analysis.contains(anal_unit) or
                    zcu.transitive_failed_analysis.contains(anal_unit))
                {
                    return;
                }
            }

            const test_nav_name = test_nav.fqn;
            const test_nav_name_len = test_nav_name.length(ip);
            const test_name_anon_decl: InternPool.Key.Ptr.BaseAddr.Uav = n: {
                const test_name_ty = try pt.arrayType(.{
                    .len = test_nav_name_len,
                    .child = .u8_type,
                });
                const test_name_val = try pt.intern(.{ .aggregate = .{
                    .ty = test_name_ty.toIntern(),
                    .storage = .{ .bytes = test_nav_name.toString() },
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
                        .base_addr = .{ .uav = test_name_anon_decl },
                        .byte_offset = 0,
                    } }),
                    .len = try pt.intern(.{ .int = .{
                        .ty = .usize_type,
                        .storage = .{ .u64 = test_nav_name_len },
                    } }),
                } }),
                // func
                try pt.intern(.{ .ptr = .{
                    .ty = (try pt.navPtrType(test_nav_index)).toIntern(),
                    .base_addr = .{ .nav = test_nav_index },
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
        const new_init = try pt.intern(.{ .slice = .{
            .ty = new_ty.toIntern(),
            .ptr = try pt.intern(.{ .ptr = .{
                .ty = new_ty.slicePtrFieldType(zcu).toIntern(),
                .base_addr = .{ .uav = array_anon_decl },
                .byte_offset = 0,
            } }),
            .len = (try pt.intValue(Type.usize, zcu.test_functions.count())).toIntern(),
        } });
        ip.mutateVarInit(test_fns_val.toIntern(), new_init);
    }
    {
        zcu.codegen_prog_node = main_progress_node.start("Code Generation", 0);
        defer {
            zcu.codegen_prog_node.end();
            zcu.codegen_prog_node = std.Progress.Node.none;
        }

        try pt.linkerUpdateNav(nav_index);
    }
}

pub fn linkerUpdateNav(pt: Zcu.PerThread, nav_index: InternPool.Nav.Index) error{OutOfMemory}!void {
    const zcu = pt.zcu;
    const comp = zcu.comp;
    const ip = &zcu.intern_pool;

    const nav = zcu.intern_pool.getNav(nav_index);
    const codegen_prog_node = zcu.codegen_prog_node.start(nav.fqn.toSlice(ip), 0);
    defer codegen_prog_node.end();

    if (!Air.valFullyResolved(zcu.navValue(nav_index), zcu)) {
        // The value of this nav failed to resolve. This is a transitive failure.
        // TODO: do we need to mark this failure anywhere? I don't think so, since compilation
        // will fail due to the type error anyway.
    } else if (comp.bin_file) |lf| {
        lf.updateNav(pt, nav_index) catch |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            error.AnalysisFail => {
                assert(zcu.failed_codegen.contains(nav_index));
            },
            else => {
                const gpa = zcu.gpa;
                try zcu.failed_codegen.ensureUnusedCapacity(gpa, 1);
                zcu.failed_codegen.putAssumeCapacityNoClobber(nav_index, try Zcu.ErrorMsg.create(
                    gpa,
                    zcu.navSrcLoc(nav_index),
                    "unable to codegen: {s}",
                    .{@errorName(err)},
                ));
                if (nav.analysis != null) {
                    try zcu.retryable_failures.append(zcu.gpa, .wrap(.{ .nav_val = nav_index }));
                } else {
                    // TODO: we don't have a way to indicate that this failure is retryable!
                    // Since these are really rare, we could as a cop-out retry the whole build next update.
                    // But perhaps we can do better...
                    @panic("TODO: retryable failure codegenning non-declaration Nav");
                }
            },
        };
    } else if (zcu.llvm_object) |llvm_object| {
        llvm_object.updateNav(pt, nav_index) catch |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
        };
    }
}

pub fn linkerUpdateContainerType(pt: Zcu.PerThread, ty: InternPool.Index) !void {
    const zcu = pt.zcu;
    const comp = zcu.comp;
    const ip = &zcu.intern_pool;

    const codegen_prog_node = zcu.codegen_prog_node.start(Type.fromInterned(ty).containerTypeName(ip).toSlice(ip), 0);
    defer codegen_prog_node.end();

    if (!Air.typeFullyResolved(Type.fromInterned(ty), zcu)) {
        // This type failed to resolve. This is a transitive failure.
        // TODO: do we need to mark this failure anywhere? I don't think so, since compilation
        // will fail due to the type error anyway.
    } else if (comp.bin_file) |lf| {
        lf.updateContainerType(pt, ty) catch |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            else => |e| log.err("codegen type failed: {s}", .{@errorName(e)}),
        };
    }
}

pub fn reportRetryableAstGenError(
    pt: Zcu.PerThread,
    src: Zcu.AstGenSrc,
    file_index: Zcu.File.Index,
    err: anyerror,
) error{OutOfMemory}!void {
    const zcu = pt.zcu;
    const gpa = zcu.gpa;
    const ip = &zcu.intern_pool;

    const file = zcu.fileByIndex(file_index);
    file.status = .retryable_failure;

    const src_loc: Zcu.LazySrcLoc = switch (src) {
        .root => .{
            .base_node_inst = try ip.trackZir(gpa, pt.tid, .{
                .file = file_index,
                .inst = .main_struct_inst,
            }),
            .offset = .entire_file,
        },
        .import => |info| .{
            .base_node_inst = try ip.trackZir(gpa, pt.tid, .{
                .file = info.importing_file,
                .inst = .main_struct_inst,
            }),
            .offset = .{ .token_abs = info.import_tok },
        },
    };

    const err_msg = try Zcu.ErrorMsg.create(gpa, src_loc, "unable to load '{}/{s}': {s}", .{
        file.mod.root, file.sub_file_path, @errorName(err),
    });
    errdefer err_msg.destroy(gpa);

    {
        zcu.comp.mutex.lock();
        defer zcu.comp.mutex.unlock();
        try zcu.failed_files.putNoClobber(gpa, file, err_msg);
    }
}

pub fn reportRetryableFileError(
    pt: Zcu.PerThread,
    file_index: Zcu.File.Index,
    comptime format: []const u8,
    args: anytype,
) error{OutOfMemory}!void {
    const zcu = pt.zcu;
    const gpa = zcu.gpa;
    const ip = &zcu.intern_pool;

    const file = zcu.fileByIndex(file_index);
    file.status = .retryable_failure;

    const err_msg = try Zcu.ErrorMsg.create(
        gpa,
        .{
            .base_node_inst = try ip.trackZir(gpa, pt.tid, .{
                .file = file_index,
                .inst = .main_struct_inst,
            }),
            .offset = .entire_file,
        },
        format,
        args,
    );
    errdefer err_msg.destroy(gpa);

    zcu.comp.mutex.lock();
    defer zcu.comp.mutex.unlock();

    const gop = try zcu.failed_files.getOrPut(gpa, file);
    if (gop.found_existing) {
        if (gop.value_ptr.*) |old_err_msg| {
            old_err_msg.destroy(gpa);
        }
    }
    gop.value_ptr.* = err_msg;
}

/// Shortcut for calling `intern_pool.get`.
pub fn intern(pt: Zcu.PerThread, key: InternPool.Key) Allocator.Error!InternPool.Index {
    return pt.zcu.intern_pool.get(pt.zcu.gpa, pt.tid, key);
}

/// Shortcut for calling `intern_pool.getUnion`.
pub fn internUnion(pt: Zcu.PerThread, un: InternPool.Key.Union) Allocator.Error!InternPool.Index {
    return pt.zcu.intern_pool.getUnion(pt.zcu.gpa, pt.tid, un);
}

/// Essentially a shortcut for calling `intern_pool.getCoerced`.
/// However, this function also allows coercing `extern`s. The `InternPool` function can't do
/// this because it requires potentially pushing to the job queue.
pub fn getCoerced(pt: Zcu.PerThread, val: Value, new_ty: Type) Allocator.Error!Value {
    const ip = &pt.zcu.intern_pool;
    switch (ip.indexToKey(val.toIntern())) {
        .@"extern" => |e| {
            const coerced = try pt.getExtern(.{
                .name = e.name,
                .ty = new_ty.toIntern(),
                .lib_name = e.lib_name,
                .is_const = e.is_const,
                .is_threadlocal = e.is_threadlocal,
                .is_weak_linkage = e.is_weak_linkage,
                .is_dll_import = e.is_dll_import,
                .alignment = e.alignment,
                .@"addrspace" = e.@"addrspace",
                .zir_index = e.zir_index,
                .owner_nav = undefined, // ignored by `getExtern`.
            });
            return Value.fromInterned(coerced);
        },
        else => {},
    }
    return Value.fromInterned(try ip.getCoerced(pt.zcu.gpa, pt.tid, val.toIntern(), new_ty.toIntern()));
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
        info.flags.alignment == Type.fromInterned(info.child).abiAlignment(pt.zcu))
    {
        canon_info.flags.alignment = .none;
    }

    switch (info.flags.vector_index) {
        // Canonicalize host_size. If it matches the bit size of the pointee type,
        // we change it to 0 here. If this causes an assertion trip, the pointee type
        // needs to be resolved before calling this ptr() function.
        .none => if (info.packed_offset.host_size != 0) {
            const elem_bit_size = Type.fromInterned(info.child).bitSize(pt.zcu);
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
        _ = try Type.fromInterned(info.child).abiAlignmentSema(pt);
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
    const zcu = pt.zcu;
    assert(ty.zigTypeTag(zcu) == .pointer and !ty.isSlice(zcu));
    assert(x != 0 or ty.isAllowzeroPtr(zcu));
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
        assert(tag == .@"enum");
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
    const zcu = pt.zcu;
    return Value.fromInterned(try zcu.intern_pool.getUnion(zcu.gpa, pt.tid, .{
        .ty = union_ty.toIntern(),
        .tag = tag.toIntern(),
        .val = val.toIntern(),
    }));
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
    const zcu = pt.zcu;
    assert(!min.isUndef(zcu));
    assert(!max.isUndef(zcu));

    if (std.debug.runtime_safety) {
        assert(Value.order(min, max, zcu).compare(.lte));
    }

    const sign = min.orderAgainstZero(zcu) == .lt;

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
    const zcu = pt.zcu;
    assert(!val.isUndef(zcu));

    const key = zcu.intern_pool.indexToKey(val.toIntern());
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
            return Type.smallestUnsignedBits(Type.fromInterned(lazy_ty).abiAlignment(pt.zcu).toByteUnits() orelse 0) + @intFromBool(sign);
        },
        .lazy_size => |lazy_ty| {
            return Type.smallestUnsignedBits(Type.fromInterned(lazy_ty).abiSize(pt.zcu)) + @intFromBool(sign);
        },
    }
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
    const zcu = pt.zcu;
    const ip = &zcu.intern_pool;
    assert(struct_type.layout == .@"packed");
    assert(struct_type.haveLayout(ip));
    var bit_sum: u64 = 0;
    for (0..struct_type.field_types.len) |i| {
        if (i == field_index) {
            return @intCast(bit_sum);
        }
        const field_ty = Type.fromInterned(struct_type.field_types.get(ip)[i]);
        bit_sum += field_ty.bitSize(zcu);
    }
    unreachable; // index out of bounds
}

pub fn getBuiltinNav(pt: Zcu.PerThread, name: []const u8) Allocator.Error!InternPool.Nav.Index {
    const zcu = pt.zcu;
    const gpa = zcu.gpa;
    const ip = &zcu.intern_pool;
    const std_file_imported = pt.importPkg(zcu.std_mod) catch @panic("failed to import lib/std.zig");
    const std_type = Type.fromInterned(zcu.fileRootType(std_file_imported.file_index));
    const std_namespace = zcu.namespacePtr(std_type.getNamespace(zcu).unwrap().?);
    const builtin_str = try ip.getOrPutString(gpa, pt.tid, "builtin", .no_embedded_nulls);
    const builtin_nav = std_namespace.pub_decls.getKeyAdapted(builtin_str, Zcu.Namespace.NameAdapter{ .zcu = zcu }) orelse
        @panic("lib/std.zig is corrupt and missing 'builtin'");
    pt.ensureNavValUpToDate(builtin_nav) catch @panic("std.builtin is corrupt");
    const builtin_type = Type.fromInterned(ip.getNav(builtin_nav).status.resolved.val);
    const builtin_namespace = zcu.namespacePtr(builtin_type.getNamespace(zcu).unwrap() orelse @panic("std.builtin is corrupt"));
    const name_str = try ip.getOrPutString(gpa, pt.tid, name, .no_embedded_nulls);
    return builtin_namespace.pub_decls.getKeyAdapted(name_str, Zcu.Namespace.NameAdapter{ .zcu = zcu }) orelse @panic("lib/std/builtin.zig is corrupt");
}

pub fn navPtrType(pt: Zcu.PerThread, nav_index: InternPool.Nav.Index) Allocator.Error!Type {
    const zcu = pt.zcu;
    const ip = &zcu.intern_pool;
    const r = ip.getNav(nav_index).status.resolved;
    const ty = Value.fromInterned(r.val).typeOf(zcu);
    return pt.ptrType(.{
        .child = ty.toIntern(),
        .flags = .{
            .alignment = if (r.alignment == ty.abiAlignment(zcu))
                .none
            else
                r.alignment,
            .address_space = r.@"addrspace",
            .is_const = switch (ip.indexToKey(r.val)) {
                .variable => false,
                .@"extern" => |e| e.is_const,
                else => true,
            },
        },
    });
}

/// Intern an `.@"extern"`, creating a corresponding owner `Nav` if necessary.
/// If necessary, the new `Nav` is queued for codegen.
/// `key.owner_nav` is ignored and may be `undefined`.
pub fn getExtern(pt: Zcu.PerThread, key: InternPool.Key.Extern) Allocator.Error!InternPool.Index {
    const result = try pt.zcu.intern_pool.getExtern(pt.zcu.gpa, pt.tid, key);
    if (result.new_nav.unwrap()) |nav| {
        // This job depends on any resolve_type_fully jobs queued up before it.
        try pt.zcu.comp.queueJob(.{ .codegen_nav = nav });
    }
    return result.index;
}

// TODO: this shouldn't need a `PerThread`! Fix the signature of `Type.abiAlignment`.
pub fn navAlignment(pt: Zcu.PerThread, nav_index: InternPool.Nav.Index) InternPool.Alignment {
    const zcu = pt.zcu;
    const r = zcu.intern_pool.getNav(nav_index).status.resolved;
    if (r.alignment != .none) return r.alignment;
    return Value.fromInterned(r.val).typeOf(zcu).abiAlignment(zcu);
}

/// Given a container type requiring resolution, ensures that it is up-to-date.
/// If not, the type is recreated at a new `InternPool.Index`.
/// The new index is returned. This is the same as the old index if the fields were up-to-date.
pub fn ensureTypeUpToDate(pt: Zcu.PerThread, ty: InternPool.Index) Zcu.SemaError!InternPool.Index {
    const zcu = pt.zcu;
    const gpa = zcu.gpa;
    const ip = &zcu.intern_pool;

    const anal_unit: AnalUnit = .wrap(.{ .type = ty });
    const outdated = zcu.outdated.swapRemove(anal_unit) or
        zcu.potentially_outdated.swapRemove(anal_unit);

    if (!outdated) return ty;

    // We will recreate the type at a new `InternPool.Index`.

    _ = zcu.outdated_ready.swapRemove(anal_unit);
    try zcu.markDependeeOutdated(.marked_po, .{ .interned = ty });

    // Delete old state which is no longer in use. Technically, this is not necessary: these exports,
    // references, etc, will be ignored because the type itself is unreferenced. However, it allows
    // reusing the memory which is currently being used to track this state.
    zcu.deleteUnitExports(anal_unit);
    zcu.deleteUnitReferences(anal_unit);
    if (zcu.failed_analysis.fetchSwapRemove(anal_unit)) |kv| {
        kv.value.destroy(gpa);
    }
    _ = zcu.transitive_failed_analysis.swapRemove(anal_unit);
    zcu.intern_pool.removeDependenciesForDepender(gpa, anal_unit);

    switch (ip.indexToKey(ty)) {
        .struct_type => |key| return pt.recreateStructType(ty, key),
        .union_type => |key| return pt.recreateUnionType(ty, key),
        .enum_type => |key| return pt.recreateEnumType(ty, key),
        else => unreachable,
    }
}

fn recreateStructType(
    pt: Zcu.PerThread,
    old_ty: InternPool.Index,
    full_key: InternPool.Key.NamespaceType,
) Zcu.SemaError!InternPool.Index {
    const zcu = pt.zcu;
    const gpa = zcu.gpa;
    const ip = &zcu.intern_pool;

    const key = switch (full_key) {
        .reified => unreachable, // never outdated
        .generated_tag => unreachable, // not a struct
        .declared => |d| d,
    };

    const inst_info = key.zir_index.resolveFull(ip) orelse return error.AnalysisFail;
    const file = zcu.fileByIndex(inst_info.file);
    if (file.status != .success_zir) return error.AnalysisFail;
    const zir = file.zir;

    assert(zir.instructions.items(.tag)[@intFromEnum(inst_info.inst)] == .extended);
    const extended = zir.instructions.items(.data)[@intFromEnum(inst_info.inst)].extended;
    assert(extended.opcode == .struct_decl);
    const small: Zir.Inst.StructDecl.Small = @bitCast(extended.small);
    const extra = zir.extraData(Zir.Inst.StructDecl, extended.operand);
    var extra_index = extra.end;

    const captures_len = if (small.has_captures_len) blk: {
        const captures_len = zir.extra[extra_index];
        extra_index += 1;
        break :blk captures_len;
    } else 0;
    const fields_len = if (small.has_fields_len) blk: {
        const fields_len = zir.extra[extra_index];
        extra_index += 1;
        break :blk fields_len;
    } else 0;

    if (captures_len != key.captures.owned.len) return error.AnalysisFail;

    const struct_obj = ip.loadStructType(old_ty);

    const wip_ty = switch (try ip.getStructType(gpa, pt.tid, .{
        .layout = small.layout,
        .fields_len = fields_len,
        .known_non_opv = small.known_non_opv,
        .requires_comptime = if (small.known_comptime_only) .yes else .unknown,
        .any_comptime_fields = small.any_comptime_fields,
        .any_default_inits = small.any_default_inits,
        .inits_resolved = false,
        .any_aligned_fields = small.any_aligned_fields,
        .key = .{ .declared_owned_captures = .{
            .zir_index = key.zir_index,
            .captures = key.captures.owned,
        } },
    }, true)) {
        .wip => |wip| wip,
        .existing => unreachable, // we passed `replace_existing`
    };
    errdefer wip_ty.cancel(ip, pt.tid);

    wip_ty.setName(ip, struct_obj.name);
    try ip.addDependency(
        gpa,
        .wrap(.{ .type = wip_ty.index }),
        .{ .src_hash = key.zir_index },
    );
    zcu.namespacePtr(struct_obj.namespace).owner_type = wip_ty.index;
    // No need to re-scan the namespace -- `zirStructDecl` will ultimately do that if the type is still alive.
    try zcu.comp.queueJob(.{ .resolve_type_fully = wip_ty.index });

    const new_ty = wip_ty.finish(ip, struct_obj.namespace);
    if (inst_info.inst == .main_struct_inst) {
        // This is the root type of a file! Update the reference.
        zcu.setFileRootType(inst_info.file, new_ty);
    }
    return new_ty;
}

fn recreateUnionType(
    pt: Zcu.PerThread,
    old_ty: InternPool.Index,
    full_key: InternPool.Key.NamespaceType,
) Zcu.SemaError!InternPool.Index {
    const zcu = pt.zcu;
    const gpa = zcu.gpa;
    const ip = &zcu.intern_pool;

    const key = switch (full_key) {
        .reified => unreachable, // never outdated
        .generated_tag => unreachable, // not a union
        .declared => |d| d,
    };

    const inst_info = key.zir_index.resolveFull(ip) orelse return error.AnalysisFail;
    const file = zcu.fileByIndex(inst_info.file);
    if (file.status != .success_zir) return error.AnalysisFail;
    const zir = file.zir;

    assert(zir.instructions.items(.tag)[@intFromEnum(inst_info.inst)] == .extended);
    const extended = zir.instructions.items(.data)[@intFromEnum(inst_info.inst)].extended;
    assert(extended.opcode == .union_decl);
    const small: Zir.Inst.UnionDecl.Small = @bitCast(extended.small);
    const extra = zir.extraData(Zir.Inst.UnionDecl, extended.operand);
    var extra_index = extra.end;

    extra_index += @intFromBool(small.has_tag_type);
    const captures_len = if (small.has_captures_len) blk: {
        const captures_len = zir.extra[extra_index];
        extra_index += 1;
        break :blk captures_len;
    } else 0;
    extra_index += @intFromBool(small.has_body_len);
    const fields_len = if (small.has_fields_len) blk: {
        const fields_len = zir.extra[extra_index];
        extra_index += 1;
        break :blk fields_len;
    } else 0;

    if (captures_len != key.captures.owned.len) return error.AnalysisFail;

    const union_obj = ip.loadUnionType(old_ty);

    const namespace_index = union_obj.namespace;

    const wip_ty = switch (try ip.getUnionType(gpa, pt.tid, .{
        .flags = .{
            .layout = small.layout,
            .status = .none,
            .runtime_tag = if (small.has_tag_type or small.auto_enum_tag)
                .tagged
            else if (small.layout != .auto)
                .none
            else switch (true) { // TODO
                true => .safety,
                false => .none,
            },
            .any_aligned_fields = small.any_aligned_fields,
            .requires_comptime = .unknown,
            .assumed_runtime_bits = false,
            .assumed_pointer_aligned = false,
            .alignment = .none,
        },
        .fields_len = fields_len,
        .enum_tag_ty = .none, // set later
        .field_types = &.{}, // set later
        .field_aligns = &.{}, // set later
        .key = .{ .declared_owned_captures = .{
            .zir_index = key.zir_index,
            .captures = key.captures.owned,
        } },
    }, true)) {
        .wip => |wip| wip,
        .existing => unreachable, // we passed `replace_existing`
    };
    errdefer wip_ty.cancel(ip, pt.tid);

    wip_ty.setName(ip, union_obj.name);
    try ip.addDependency(
        gpa,
        .wrap(.{ .type = wip_ty.index }),
        .{ .src_hash = key.zir_index },
    );
    zcu.namespacePtr(namespace_index).owner_type = wip_ty.index;
    // No need to re-scan the namespace -- `zirUnionDecl` will ultimately do that if the type is still alive.
    try zcu.comp.queueJob(.{ .resolve_type_fully = wip_ty.index });
    return wip_ty.finish(ip, namespace_index);
}

fn recreateEnumType(
    pt: Zcu.PerThread,
    old_ty: InternPool.Index,
    full_key: InternPool.Key.NamespaceType,
) Zcu.SemaError!InternPool.Index {
    const zcu = pt.zcu;
    const gpa = zcu.gpa;
    const ip = &zcu.intern_pool;

    const key = switch (full_key) {
        .reified, .generated_tag => unreachable, // never outdated
        .declared => |d| d,
    };

    const inst_info = key.zir_index.resolveFull(ip) orelse return error.AnalysisFail;
    const file = zcu.fileByIndex(inst_info.file);
    if (file.status != .success_zir) return error.AnalysisFail;
    const zir = file.zir;

    assert(zir.instructions.items(.tag)[@intFromEnum(inst_info.inst)] == .extended);
    const extended = zir.instructions.items(.data)[@intFromEnum(inst_info.inst)].extended;
    assert(extended.opcode == .enum_decl);
    const small: Zir.Inst.EnumDecl.Small = @bitCast(extended.small);
    const extra = zir.extraData(Zir.Inst.EnumDecl, extended.operand);
    var extra_index = extra.end;

    const tag_type_ref = if (small.has_tag_type) blk: {
        const tag_type_ref: Zir.Inst.Ref = @enumFromInt(zir.extra[extra_index]);
        extra_index += 1;
        break :blk tag_type_ref;
    } else .none;

    const captures_len = if (small.has_captures_len) blk: {
        const captures_len = zir.extra[extra_index];
        extra_index += 1;
        break :blk captures_len;
    } else 0;

    const body_len = if (small.has_body_len) blk: {
        const body_len = zir.extra[extra_index];
        extra_index += 1;
        break :blk body_len;
    } else 0;

    const fields_len = if (small.has_fields_len) blk: {
        const fields_len = zir.extra[extra_index];
        extra_index += 1;
        break :blk fields_len;
    } else 0;

    const decls_len = if (small.has_decls_len) blk: {
        const decls_len = zir.extra[extra_index];
        extra_index += 1;
        break :blk decls_len;
    } else 0;

    if (captures_len != key.captures.owned.len) return error.AnalysisFail;

    extra_index += captures_len;
    extra_index += decls_len;

    const body = zir.bodySlice(extra_index, body_len);
    extra_index += body.len;

    const bit_bags_count = std.math.divCeil(usize, fields_len, 32) catch unreachable;
    const body_end = extra_index;
    extra_index += bit_bags_count;

    const any_values = for (zir.extra[body_end..][0..bit_bags_count]) |bag| {
        if (bag != 0) break true;
    } else false;

    const enum_obj = ip.loadEnumType(old_ty);

    const namespace_index = enum_obj.namespace;

    const wip_ty = switch (try ip.getEnumType(gpa, pt.tid, .{
        .has_values = any_values,
        .tag_mode = if (small.nonexhaustive)
            .nonexhaustive
        else if (tag_type_ref == .none)
            .auto
        else
            .explicit,
        .fields_len = fields_len,
        .key = .{ .declared_owned_captures = .{
            .zir_index = key.zir_index,
            .captures = key.captures.owned,
        } },
    }, true)) {
        .wip => |wip| wip,
        .existing => unreachable, // we passed `replace_existing`
    };
    var done = true;
    errdefer if (!done) wip_ty.cancel(ip, pt.tid);

    wip_ty.setName(ip, enum_obj.name);

    zcu.namespacePtr(namespace_index).owner_type = wip_ty.index;
    // No need to re-scan the namespace -- `zirEnumDecl` will ultimately do that if the type is still alive.

    wip_ty.prepare(ip, namespace_index);
    done = true;

    Sema.resolveDeclaredEnum(
        pt,
        wip_ty,
        inst_info.inst,
        key.zir_index,
        namespace_index,
        enum_obj.name,
        small,
        body,
        tag_type_ref,
        any_values,
        fields_len,
        zir,
        body_end,
    ) catch |err| switch (err) {
        error.GenericPoison => unreachable,
        error.ComptimeBreak => unreachable,
        error.ComptimeReturn => unreachable,
        error.AnalysisFail, error.OutOfMemory => |e| return e,
    };

    return wip_ty.index;
}

/// Given a namespace, re-scan its declarations from the type definition if they have not
/// yet been re-scanned on this update.
/// If the type declaration instruction has been lost, returns `error.AnalysisFail`.
/// This will effectively short-circuit the caller, which will be semantic analysis of a
/// guaranteed-unreferenced `AnalUnit`, to trigger a transitive analysis error.
pub fn ensureNamespaceUpToDate(pt: Zcu.PerThread, namespace_index: Zcu.Namespace.Index) Zcu.SemaError!void {
    const zcu = pt.zcu;
    const ip = &zcu.intern_pool;
    const namespace = zcu.namespacePtr(namespace_index);

    if (namespace.generation == zcu.generation) return;

    const Container = enum { @"struct", @"union", @"enum", @"opaque" };
    const container: Container, const full_key = switch (ip.indexToKey(namespace.owner_type)) {
        .struct_type => |k| .{ .@"struct", k },
        .union_type => |k| .{ .@"union", k },
        .enum_type => |k| .{ .@"enum", k },
        .opaque_type => |k| .{ .@"opaque", k },
        else => unreachable, // namespaces are owned by a container type
    };

    const key = switch (full_key) {
        .reified, .generated_tag => {
            // Namespace always empty, so up-to-date.
            namespace.generation = zcu.generation;
            return;
        },
        .declared => |d| d,
    };

    // Namespace outdated -- re-scan the type if necessary.

    const inst_info = key.zir_index.resolveFull(ip) orelse return error.AnalysisFail;
    const file = zcu.fileByIndex(inst_info.file);
    if (file.status != .success_zir) return error.AnalysisFail;
    const zir = file.zir;

    assert(zir.instructions.items(.tag)[@intFromEnum(inst_info.inst)] == .extended);
    const extended = zir.instructions.items(.data)[@intFromEnum(inst_info.inst)].extended;

    const decls = switch (container) {
        .@"struct" => decls: {
            assert(extended.opcode == .struct_decl);
            const small: Zir.Inst.StructDecl.Small = @bitCast(extended.small);
            const extra = zir.extraData(Zir.Inst.StructDecl, extended.operand);
            var extra_index = extra.end;
            const captures_len = if (small.has_captures_len) blk: {
                const captures_len = zir.extra[extra_index];
                extra_index += 1;
                break :blk captures_len;
            } else 0;
            extra_index += @intFromBool(small.has_fields_len);
            const decls_len = if (small.has_decls_len) blk: {
                const decls_len = zir.extra[extra_index];
                extra_index += 1;
                break :blk decls_len;
            } else 0;
            extra_index += captures_len;
            if (small.has_backing_int) {
                const backing_int_body_len = zir.extra[extra_index];
                extra_index += 1; // backing_int_body_len
                if (backing_int_body_len == 0) {
                    extra_index += 1; // backing_int_ref
                } else {
                    extra_index += backing_int_body_len; // backing_int_body_inst
                }
            }
            break :decls zir.bodySlice(extra_index, decls_len);
        },
        .@"union" => decls: {
            assert(extended.opcode == .union_decl);
            const small: Zir.Inst.UnionDecl.Small = @bitCast(extended.small);
            const extra = zir.extraData(Zir.Inst.UnionDecl, extended.operand);
            var extra_index = extra.end;
            extra_index += @intFromBool(small.has_tag_type);
            const captures_len = if (small.has_captures_len) blk: {
                const captures_len = zir.extra[extra_index];
                extra_index += 1;
                break :blk captures_len;
            } else 0;
            extra_index += @intFromBool(small.has_body_len);
            extra_index += @intFromBool(small.has_fields_len);
            const decls_len = if (small.has_decls_len) blk: {
                const decls_len = zir.extra[extra_index];
                extra_index += 1;
                break :blk decls_len;
            } else 0;
            extra_index += captures_len;
            break :decls zir.bodySlice(extra_index, decls_len);
        },
        .@"enum" => decls: {
            assert(extended.opcode == .enum_decl);
            const small: Zir.Inst.EnumDecl.Small = @bitCast(extended.small);
            const extra = zir.extraData(Zir.Inst.EnumDecl, extended.operand);
            var extra_index = extra.end;
            extra_index += @intFromBool(small.has_tag_type);
            const captures_len = if (small.has_captures_len) blk: {
                const captures_len = zir.extra[extra_index];
                extra_index += 1;
                break :blk captures_len;
            } else 0;
            extra_index += @intFromBool(small.has_body_len);
            extra_index += @intFromBool(small.has_fields_len);
            const decls_len = if (small.has_decls_len) blk: {
                const decls_len = zir.extra[extra_index];
                extra_index += 1;
                break :blk decls_len;
            } else 0;
            extra_index += captures_len;
            break :decls zir.bodySlice(extra_index, decls_len);
        },
        .@"opaque" => decls: {
            assert(extended.opcode == .opaque_decl);
            const small: Zir.Inst.OpaqueDecl.Small = @bitCast(extended.small);
            const extra = zir.extraData(Zir.Inst.OpaqueDecl, extended.operand);
            var extra_index = extra.end;
            const captures_len = if (small.has_captures_len) blk: {
                const captures_len = zir.extra[extra_index];
                extra_index += 1;
                break :blk captures_len;
            } else 0;
            const decls_len = if (small.has_decls_len) blk: {
                const decls_len = zir.extra[extra_index];
                extra_index += 1;
                break :blk decls_len;
            } else 0;
            extra_index += captures_len;
            break :decls zir.bodySlice(extra_index, decls_len);
        },
    };

    try pt.scanNamespace(namespace_index, decls);
    namespace.generation = zcu.generation;
}

pub fn refValue(pt: Zcu.PerThread, val: InternPool.Index) Zcu.SemaError!InternPool.Index {
    const ptr_ty = (try pt.ptrTypeSema(.{
        .child = pt.zcu.intern_pool.typeOf(val),
        .flags = .{
            .alignment = .none,
            .is_const = true,
            .address_space = .generic,
        },
    })).toIntern();
    return pt.intern(.{ .ptr = .{
        .ty = ptr_ty,
        .base_addr = .{ .uav = .{
            .val = val,
            .orig_ty = ptr_ty,
        } },
        .byte_offset = 0,
    } });
}
