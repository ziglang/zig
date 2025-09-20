//! This type provides a wrapper around a `*Zcu` for uses which require a thread `Id`.
//! Any operation which mutates `InternPool` state lives here rather than on `Zcu`.

const Air = @import("../Air.zig");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const Ast = std.zig.Ast;
const AstGen = std.zig.AstGen;
const BigIntConst = std.math.big.int.Const;
const BigIntMutable = std.math.big.int.Mutable;
const Builtin = @import("../Builtin.zig");
const build_options = @import("build_options");
const builtin = @import("builtin");
const Cache = std.Build.Cache;
const dev = @import("../dev.zig");
const InternPool = @import("../InternPool.zig");
const AnalUnit = InternPool.AnalUnit;
const introspect = @import("../introspect.zig");
const log = std.log.scoped(.zcu);
const Module = @import("../Package.zig").Module;
const Sema = @import("../Sema.zig");
const std = @import("std");
const mem = std.mem;
const target_util = @import("../target.zig");
const trace = @import("../tracy.zig").trace;
const Type = @import("../Type.zig");
const Value = @import("../Value.zig");
const Zcu = @import("../Zcu.zig");
const Compilation = @import("../Compilation.zig");
const codegen = @import("../codegen.zig");
const Zir = std.zig.Zir;
const Zoir = std.zig.Zoir;
const ZonGen = std.zig.ZonGen;

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
    log.debug("deinit File {f}", .{file.path.fmt(zcu.comp)});
    file.path.deinit(gpa);
    file.unload(gpa);
    if (file.prev_zir) |prev_zir| {
        prev_zir.deinit(gpa);
        gpa.destroy(prev_zir);
    }
    file.* = undefined;
}

pub fn destroyFile(pt: Zcu.PerThread, file_index: Zcu.File.Index) void {
    const gpa = pt.zcu.gpa;
    const file = pt.zcu.fileByIndex(file_index);
    pt.deinitFile(file_index);
    gpa.destroy(file);
}

/// Ensures that `file` has up-to-date ZIR. If not, loads the ZIR cache or runs
/// AstGen as needed. Also updates `file.status`. Does not assume that `file.mod`
/// is populated. Does not return `error.AnalysisFail` on AstGen failures.
pub fn updateFile(
    pt: Zcu.PerThread,
    file_index: Zcu.File.Index,
    file: *Zcu.File,
) !void {
    dev.check(.ast_gen);

    const tracy = trace(@src());
    defer tracy.end();

    const zcu = pt.zcu;
    const comp = zcu.comp;
    const gpa = zcu.gpa;

    // In any case we need to examine the stat of the file to determine the course of action.
    var source_file = f: {
        const dir, const sub_path = file.path.openInfo(comp.dirs);
        break :f try dir.openFile(sub_path, .{});
    };
    defer source_file.close();

    const stat = try source_file.stat();

    const want_local_cache = switch (file.path.root) {
        .none, .local_cache => true,
        .global_cache, .zig_lib => false,
    };

    const hex_digest: Cache.HexDigest = d: {
        var h: Cache.HashHelper = .{};
        // As well as the file path, we also include the compiler version in case of backwards-incompatible ZIR changes.
        file.path.addToHasher(&h.hasher);
        h.addBytes(build_options.version);
        h.add(builtin.zig_backend);
        break :d h.final();
    };

    const cache_directory = if (want_local_cache) zcu.local_zir_cache else zcu.global_zir_cache;
    const zir_dir = cache_directory.handle;

    // Determine whether we need to reload the file from disk and redo parsing and AstGen.
    var lock: std.fs.File.Lock = switch (file.status) {
        .never_loaded, .retryable_failure => lock: {
            // First, load the cached ZIR code, if any.
            log.debug("AstGen checking cache: {f} (local={}, digest={s})", .{
                file.path.fmt(comp), want_local_cache, &hex_digest,
            });

            break :lock .shared;
        },
        .astgen_failure, .success => lock: {
            const unchanged_metadata =
                stat.size == file.stat.size and
                stat.mtime == file.stat.mtime and
                stat.inode == file.stat.inode;

            if (unchanged_metadata) {
                log.debug("unmodified metadata of file: {f}", .{file.path.fmt(comp)});
                return;
            }

            log.debug("metadata changed: {f}", .{file.path.fmt(comp)});

            break :lock .exclusive;
        },
    };

    // The old compile error, if any, is no longer relevant.
    pt.lockAndClearFileCompileError(file_index, file);

    // If `zir` is not null, and `prev_zir` is null, then `TrackedInst`s are associated with `zir`.
    // We need to keep it around!
    // As an optimization, also check `loweringFailed`; if true, but `prev_zir == null`, then this
    // file has never passed AstGen, so we actually need not cache the old ZIR.
    if (file.zir != null and file.prev_zir == null and !file.zir.?.loweringFailed()) {
        assert(file.prev_zir == null);
        const prev_zir_ptr = try gpa.create(Zir);
        file.prev_zir = prev_zir_ptr;
        prev_zir_ptr.* = file.zir.?;
        file.zir = null;
    }

    // If ZOIR is changing, then we need to invalidate dependencies on it
    if (file.zoir != null) file.zoir_invalidated = true;

    // We're going to re-load everything, so unload source, AST, ZIR, ZOIR.
    file.unload(gpa);

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
                    std.process.fatal("cache directory '{f}' unexpectedly removed during compiler execution", .{
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
                        std.process.fatal("cache directory '{f}' unexpectedly removed during compiler execution", .{
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

    // Under `--time-report`, ignore cache hits; do the work anyway for those juicy numbers.
    const ignore_hit = comp.time_report != null;

    const need_update = while (true) {
        const result = switch (file.getMode()) {
            inline else => |mode| try loadZirZoirCache(zcu, cache_file, stat, file, mode),
        };
        switch (result) {
            .success => if (!ignore_hit) {
                log.debug("AstGen cached success: {f}", .{file.path.fmt(comp)});
                break false;
            },
            .invalid => {},
            .truncated => log.warn("unexpected EOF reading cached ZIR for {f}", .{file.path.fmt(comp)}),
            .stale => log.debug("AstGen cache stale: {f}", .{file.path.fmt(comp)}),
        }

        // If we already have the exclusive lock then it is our job to update.
        if (builtin.os.tag == .wasi or lock == .exclusive) break true;
        // Otherwise, unlock to give someone a chance to get the exclusive lock
        // and then upgrade to an exclusive lock.
        cache_file.unlock();
        lock = .exclusive;
        try cache_file.lock(lock);
    };

    if (need_update) {
        // The cache is definitely stale so delete the contents to avoid an underwrite later.
        cache_file.setEndPos(0) catch |err| switch (err) {
            error.FileTooBig => unreachable, // 0 is not too big
            else => |e| return e,
        };
        try cache_file.seekTo(0);

        if (stat.size > std.math.maxInt(u32))
            return error.FileTooBig;

        const source = try gpa.allocSentinel(u8, @intCast(stat.size), 0);
        defer if (file.source == null) gpa.free(source);
        var source_fr = source_file.reader(&.{});
        source_fr.size = stat.size;
        source_fr.interface.readSliceAll(source) catch |err| switch (err) {
            error.ReadFailed => return source_fr.err.?,
            error.EndOfStream => return error.UnexpectedEndOfFile,
        };

        file.source = source;

        var timer = comp.startTimer();
        // Any potential AST errors are converted to ZIR errors when we run AstGen/ZonGen.
        file.tree = try Ast.parse(gpa, source, file.getMode());
        if (timer.finish()) |ns_parse| {
            comp.mutex.lock();
            defer comp.mutex.unlock();
            comp.time_report.?.stats.cpu_ns_parse += ns_parse;
        }

        timer = comp.startTimer();
        switch (file.getMode()) {
            .zig => {
                file.zir = try AstGen.generate(gpa, file.tree.?);
                Zcu.saveZirCache(gpa, cache_file, stat, file.zir.?) catch |err| switch (err) {
                    error.OutOfMemory => |e| return e,
                    else => log.warn("unable to write cached ZIR code for {f} to {f}{s}: {s}", .{
                        file.path.fmt(comp), cache_directory, &hex_digest, @errorName(err),
                    }),
                };
            },
            .zon => {
                file.zoir = try ZonGen.generate(gpa, file.tree.?, .{});
                Zcu.saveZoirCache(cache_file, stat, file.zoir.?) catch |err| {
                    log.warn("unable to write cached ZOIR code for {f} to {f}{s}: {s}", .{
                        file.path.fmt(comp), cache_directory, &hex_digest, @errorName(err),
                    });
                };
            },
        }
        if (timer.finish()) |ns_astgen| {
            comp.mutex.lock();
            defer comp.mutex.unlock();
            comp.time_report.?.stats.cpu_ns_astgen += ns_astgen;
        }

        log.debug("AstGen fresh success: {f}", .{file.path.fmt(comp)});
    }

    file.stat = .{
        .size = stat.size,
        .inode = stat.inode,
        .mtime = stat.mtime,
    };

    // Now, `zir` or `zoir` is definitely populated and up-to-date.
    // Mark file successes/failures as needed.

    switch (file.getMode()) {
        .zig => {
            if (file.zir.?.hasCompileErrors()) {
                comp.mutex.lock();
                defer comp.mutex.unlock();
                try zcu.failed_files.putNoClobber(gpa, file_index, null);
            }
            if (file.zir.?.loweringFailed()) {
                file.status = .astgen_failure;
            } else {
                file.status = .success;
            }
        },
        .zon => {
            if (file.zoir.?.hasCompileErrors()) {
                file.status = .astgen_failure;
                comp.mutex.lock();
                defer comp.mutex.unlock();
                try zcu.failed_files.putNoClobber(gpa, file_index, null);
            } else {
                file.status = .success;
            }
        },
    }

    switch (file.status) {
        .never_loaded => unreachable,
        .retryable_failure => unreachable,
        .astgen_failure, .success => {},
    }
}

fn loadZirZoirCache(
    zcu: *Zcu,
    cache_file: std.fs.File,
    stat: std.fs.File.Stat,
    file: *Zcu.File,
    comptime mode: Ast.Mode,
) !enum { success, invalid, truncated, stale } {
    assert(file.getMode() == mode);

    const gpa = zcu.gpa;

    const Header = switch (mode) {
        .zig => Zir.Header,
        .zon => Zoir.Header,
    };

    var buffer: [2000]u8 = undefined;
    var cache_fr = cache_file.reader(&buffer);
    cache_fr.size = stat.size;
    const cache_br = &cache_fr.interface;

    // First we read the header to determine the lengths of arrays.
    const header = (cache_br.takeStructPointer(Header) catch |err| switch (err) {
        error.ReadFailed => return cache_fr.err.?,
        // This can happen if Zig bails out of this function between creating
        // the cached file and writing it.
        error.EndOfStream => return .invalid,
        else => |e| return e,
    }).*;

    const unchanged_metadata =
        stat.size == header.stat_size and
        stat.mtime == header.stat_mtime and
        stat.inode == header.stat_inode;

    if (!unchanged_metadata) {
        return .stale;
    }

    switch (mode) {
        .zig => file.zir = Zcu.loadZirCacheBody(gpa, header, cache_br) catch |err| switch (err) {
            error.ReadFailed => return cache_fr.err.?,
            error.EndOfStream => return .truncated,
            else => |e| return e,
        },
        .zon => file.zoir = Zcu.loadZoirCacheBody(gpa, header, cache_br) catch |err| switch (err) {
            error.ReadFailed => return cache_fr.err.?,
            error.EndOfStream => return .truncated,
            else => |e| return e,
        },
    }

    return .success;
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
    const comp = zcu.comp;
    const ip = &zcu.intern_pool;
    const gpa = zcu.gpa;

    // We need to visit every updated File for every TrackedInst in InternPool.
    // This only includes Zig files; ZON files are omitted.
    var updated_files: std.AutoArrayHashMapUnmanaged(Zcu.File.Index, UpdatedFile) = .empty;
    defer cleanupUpdatedFiles(gpa, &updated_files);

    for (zcu.import_table.keys()) |file_index| {
        if (!zcu.alive_files.contains(file_index)) continue;
        const file = zcu.fileByIndex(file_index);
        assert(file.status == .success);
        if (file.module_changed) {
            try updated_files.putNoClobber(gpa, file_index, .{
                .file = file,
                // We intentionally don't map any instructions here; that's the point, the whole file is outdated!
                .inst_map = .{},
            });
            continue;
        }
        switch (file.getMode()) {
            .zig => {}, // logic below
            .zon => {
                if (file.zoir_invalidated) {
                    try zcu.markDependeeOutdated(.not_marked_po, .{ .zon_file = file_index });
                    file.zoir_invalidated = false;
                }
                continue;
            },
        }
        const old_zir = file.prev_zir orelse continue;
        const new_zir = file.zir.?;
        const gop = try updated_files.getOrPut(gpa, file_index);
        assert(!gop.found_existing);
        gop.value_ptr.* = .{
            .file = file,
            .inst_map = .{},
        };
        try Zcu.mapOldZirToNew(gpa, old_zir.*, new_zir, &gop.value_ptr.inst_map);
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
                // Tracking failed for this instruction due to changes in the ZIR.
                // Invalidate associated `src_hash` deps.
                log.debug("tracking failed for %{d}", .{old_inst});
                tracked_inst.inst = .lost;
                try zcu.markDependeeOutdated(.not_marked_po, .{ .src_hash = tracked_inst_index });
                continue;
            };
            tracked_inst.inst = InternPool.TrackedInst.MaybeLost.ZirIndex.wrap(new_inst);

            const old_zir = file.prev_zir.?.*;
            const new_zir = file.zir.?;
            const old_tag = old_zir.instructions.items(.tag)[@intFromEnum(old_inst)];
            const old_data = old_zir.instructions.items(.data)[@intFromEnum(old_inst)];

            switch (old_tag) {
                .declaration => {
                    const old_line = old_zir.getDeclaration(old_inst).src_line;
                    const new_line = new_zir.getDeclaration(new_inst).src_line;
                    if (old_line != new_line) {
                        try comp.queueJob(.{ .update_line_number = tracked_inst_index });
                    }
                },
                else => {},
            }

            if (old_zir.getAssociatedSrcHash(old_inst)) |old_hash| hash_changed: {
                if (new_zir.getAssociatedSrcHash(new_inst)) |new_hash| {
                    if (std.zig.srcHashEql(old_hash, new_hash)) {
                        break :hash_changed;
                    }
                    log.debug("hash for (%{d} -> %{d}) changed: {x} -> {x}", .{
                        old_inst, new_inst, &old_hash, &new_hash,
                    });
                }
                // The source hash associated with this instruction changed - invalidate relevant dependencies.
                try zcu.markDependeeOutdated(.not_marked_po, .{ .src_hash = tracked_inst_index });
            }

            // If this is a `struct_decl` etc, we must invalidate any outdated namespace dependencies.
            const has_namespace = switch (old_tag) {
                .extended => switch (old_data.extended.opcode) {
                    .struct_decl, .union_decl, .opaque_decl, .enum_decl => true,
                    else => false,
                },
                else => false,
            };
            if (!has_namespace) continue;

            // Value is whether the declaration is `pub`.
            var old_names: std.AutoArrayHashMapUnmanaged(InternPool.NullTerminatedString, bool) = .empty;
            defer old_names.deinit(zcu.gpa);
            {
                var it = old_zir.declIterator(old_inst);
                while (it.next()) |decl_inst| {
                    const old_decl = old_zir.getDeclaration(decl_inst);
                    if (old_decl.name == .empty) continue;
                    const name_ip = try zcu.intern_pool.getOrPutString(
                        zcu.gpa,
                        pt.tid,
                        old_zir.nullTerminatedString(old_decl.name),
                        .no_embedded_nulls,
                    );
                    try old_names.put(zcu.gpa, name_ip, old_decl.is_pub);
                }
            }
            var any_change = false;
            {
                var it = new_zir.declIterator(new_inst);
                while (it.next()) |decl_inst| {
                    const new_decl = new_zir.getDeclaration(decl_inst);
                    if (new_decl.name == .empty) continue;
                    const name_ip = try zcu.intern_pool.getOrPutString(
                        zcu.gpa,
                        pt.tid,
                        new_zir.nullTerminatedString(new_decl.name),
                        .no_embedded_nulls,
                    );
                    if (old_names.fetchSwapRemove(name_ip)) |kv| {
                        if (kv.value == new_decl.is_pub) continue;
                    }
                    // Name added, or changed whether it's pub
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

        if (file.prev_zir) |prev_zir| {
            prev_zir.deinit(gpa);
            gpa.destroy(prev_zir);
            file.prev_zir = null;
        }
        file.module_changed = false;

        // For every file which has changed, re-scan the namespace of the file's root struct type.
        // These types are special-cased because they don't have an enclosing declaration which will
        // be re-analyzed (causing the struct's namespace to be re-scanned). It's fine to do this
        // now because this work is fast (no actual Sema work is happening, we're just updating the
        // namespace contents). We must do this after updating ZIR refs above, since `scanNamespace`
        // will track some instructions.
        try pt.updateFileNamespace(file_index);
    }
}

/// Ensures that `zcu.fileRootType` on this `file_index` gives an up-to-date answer.
/// Returns `error.AnalysisFail` if the file has an error.
pub fn ensureFileAnalyzed(pt: Zcu.PerThread, file_index: Zcu.File.Index) Zcu.SemaError!void {
    const file_root_type = pt.zcu.fileRootType(file_index);
    if (file_root_type != .none) {
        if (pt.ensureTypeUpToDate(file_root_type)) |_| {
            return;
        } else |err| switch (err) {
            error.AnalysisFail => {
                // The file's root `struct_decl` has, at some point, been lost, because the file failed AstGen.
                // Clear `file_root_type`, and try the `semaFile` call below, in case the instruction has since
                // been discovered under a new `TrackedInst.Index`.
                pt.zcu.setFileRootType(file_index, .none);
            },
            else => |e| return e,
        }
    }
    return pt.semaFile(file_index);
}

/// Ensures that all memoized state on `Zcu` is up-to-date, performing re-analysis if necessary.
/// Returns `error.AnalysisFail` if an analysis error is encountered; the caller is free to ignore
/// this, since the error is already registered, but it must not use the value of memoized fields.
pub fn ensureMemoizedStateUpToDate(pt: Zcu.PerThread, stage: InternPool.MemoizedStateStage) Zcu.SemaError!void {
    const tracy = trace(@src());
    defer tracy.end();

    const zcu = pt.zcu;
    const gpa = zcu.gpa;

    const unit: AnalUnit = .wrap(.{ .memoized_state = stage });

    log.debug("ensureMemoizedStateUpToDate", .{});

    assert(!zcu.analysis_in_progress.contains(unit));

    const was_outdated = zcu.outdated.swapRemove(unit) or zcu.potentially_outdated.swapRemove(unit);
    const prev_failed = zcu.failed_analysis.contains(unit) or zcu.transitive_failed_analysis.contains(unit);

    if (was_outdated) {
        dev.check(.incremental);
        _ = zcu.outdated_ready.swapRemove(unit);
        // No need for `deleteUnitExports` because we never export anything.
        zcu.deleteUnitReferences(unit);
        zcu.deleteUnitCompileLogs(unit);
        if (zcu.failed_analysis.fetchSwapRemove(unit)) |kv| {
            kv.value.destroy(gpa);
        }
        _ = zcu.transitive_failed_analysis.swapRemove(unit);
    } else {
        if (prev_failed) return error.AnalysisFail;
        // We use an arbitrary element to check if the state has been resolved yet.
        const to_check: Zcu.BuiltinDecl = switch (stage) {
            .main => .Type,
            .panic => .panic,
            .va_list => .VaList,
            .assembly => .assembly,
        };
        if (zcu.builtin_decl_values.get(to_check) != .none) return;
    }

    if (zcu.comp.debugIncremental()) {
        const info = try zcu.incremental_debug_state.getUnitInfo(gpa, unit);
        info.last_update_gen = zcu.generation;
        info.deps.clearRetainingCapacity();
    }

    const any_changed: bool, const new_failed: bool = if (pt.analyzeMemoizedState(stage)) |any_changed|
        .{ any_changed or prev_failed, false }
    else |err| switch (err) {
        error.AnalysisFail => res: {
            if (!zcu.failed_analysis.contains(unit)) {
                // If this unit caused the error, it would have an entry in `failed_analysis`.
                // Since it does not, this must be a transitive failure.
                try zcu.transitive_failed_analysis.put(gpa, unit, {});
                log.debug("mark transitive analysis failure for {f}", .{zcu.fmtAnalUnit(unit)});
            }
            break :res .{ !prev_failed, true };
        },
        error.OutOfMemory => {
            // TODO: same as for `ensureComptimeUnitUpToDate` etc
            return error.OutOfMemory;
        },
        error.ComptimeReturn => unreachable,
        error.ComptimeBreak => unreachable,
    };

    if (was_outdated) {
        const dependee: InternPool.Dependee = .{ .memoized_state = stage };
        if (any_changed) {
            try zcu.markDependeeOutdated(.marked_po, dependee);
        } else {
            try zcu.markPoDependeeUpToDate(dependee);
        }
    }

    if (new_failed) return error.AnalysisFail;
}

fn analyzeMemoizedState(pt: Zcu.PerThread, stage: InternPool.MemoizedStateStage) Zcu.CompileError!bool {
    const zcu = pt.zcu;
    const ip = &zcu.intern_pool;
    const gpa = zcu.gpa;

    const unit: AnalUnit = .wrap(.{ .memoized_state = stage });

    try zcu.analysis_in_progress.putNoClobber(gpa, unit, {});
    defer assert(zcu.analysis_in_progress.swapRemove(unit));

    // Before we begin, collect:
    // * The type `std`, and its namespace
    // * The type `std.builtin`, and its namespace
    // * A semi-reasonable source location
    const std_file_index = zcu.module_roots.get(zcu.std_mod).?.unwrap().?;
    try pt.ensureFileAnalyzed(std_file_index);
    const std_type: Type = .fromInterned(zcu.fileRootType(std_file_index));
    const std_namespace = std_type.getNamespaceIndex(zcu);
    try pt.ensureNamespaceUpToDate(std_namespace);
    const builtin_str = try ip.getOrPutString(gpa, pt.tid, "builtin", .no_embedded_nulls);
    const builtin_nav = zcu.namespacePtr(std_namespace).pub_decls.getKeyAdapted(builtin_str, Zcu.Namespace.NameAdapter{ .zcu = zcu }) orelse
        @panic("lib/std.zig is corrupt and missing 'builtin'");
    try pt.ensureNavValUpToDate(builtin_nav);
    const builtin_type: Type = .fromInterned(ip.getNav(builtin_nav).status.fully_resolved.val);
    const builtin_namespace = builtin_type.getNamespaceIndex(zcu);
    try pt.ensureNamespaceUpToDate(builtin_namespace);
    const src: Zcu.LazySrcLoc = .{
        .base_node_inst = builtin_type.typeDeclInst(zcu).?,
        .offset = .{ .byte_abs = 0 },
    };

    var analysis_arena: std.heap.ArenaAllocator = .init(gpa);
    defer analysis_arena.deinit();

    var comptime_err_ret_trace: std.array_list.Managed(Zcu.LazySrcLoc) = .init(gpa);
    defer comptime_err_ret_trace.deinit();

    var sema: Sema = .{
        .pt = pt,
        .gpa = gpa,
        .arena = analysis_arena.allocator(),
        .code = .{ .instructions = .empty, .string_bytes = &.{}, .extra = &.{} },
        .owner = unit,
        .func_index = .none,
        .func_is_naked = false,
        .fn_ret_ty = .void,
        .fn_ret_ty_ies = null,
        .comptime_err_ret_trace = &comptime_err_ret_trace,
    };
    defer sema.deinit();

    var block: Sema.Block = .{
        .parent = null,
        .sema = &sema,
        .namespace = std_namespace,
        .instructions = .{},
        .inlining = null,
        .comptime_reason = .{ .reason = .{
            .src = src,
            .r = .{ .simple = .type },
        } },
        .src_base_inst = src.base_node_inst,
        .type_name_ctx = .empty,
    };
    defer block.instructions.deinit(gpa);

    return sema.analyzeMemoizedState(&block, src, builtin_namespace, stage);
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

    log.debug("ensureComptimeUnitUpToDate {f}", .{zcu.fmtAnalUnit(anal_unit)});

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
            zcu.deleteUnitCompileLogs(anal_unit);
            if (zcu.failed_analysis.fetchSwapRemove(anal_unit)) |kv| {
                kv.value.destroy(gpa);
            }
            _ = zcu.transitive_failed_analysis.swapRemove(anal_unit);
            zcu.intern_pool.removeDependenciesForDepender(gpa, anal_unit);
        }
    } else {
        // We can trust the current information about this unit.
        if (zcu.failed_analysis.contains(anal_unit)) return error.AnalysisFail;
        if (zcu.transitive_failed_analysis.contains(anal_unit)) return error.AnalysisFail;
        return;
    }

    if (zcu.comp.debugIncremental()) {
        const info = try zcu.incremental_debug_state.getUnitInfo(gpa, anal_unit);
        info.last_update_gen = zcu.generation;
        info.deps.clearRetainingCapacity();
    }

    const unit_tracking = zcu.trackUnitSema(
        "comptime",
        zcu.intern_pool.getComptimeUnit(cu_id).zir_index,
    );
    defer unit_tracking.end(zcu);

    return pt.analyzeComptimeUnit(cu_id) catch |err| switch (err) {
        error.AnalysisFail => {
            if (!zcu.failed_analysis.contains(anal_unit)) {
                // If this unit caused the error, it would have an entry in `failed_analysis`.
                // Since it does not, this must be a transitive failure.
                try zcu.transitive_failed_analysis.put(gpa, anal_unit, {});
                log.debug("mark transitive analysis failure for {f}", .{zcu.fmtAnalUnit(anal_unit)});
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

    log.debug("analyzeComptimeUnit {f}", .{zcu.fmtAnalUnit(anal_unit)});

    const inst_resolved = comptime_unit.zir_index.resolveFull(ip) orelse return error.AnalysisFail;
    const file = zcu.fileByIndex(inst_resolved.file);
    const zir = file.zir.?;

    try zcu.analysis_in_progress.putNoClobber(gpa, anal_unit, {});
    defer assert(zcu.analysis_in_progress.swapRemove(anal_unit));

    var analysis_arena: std.heap.ArenaAllocator = .init(gpa);
    defer analysis_arena.deinit();

    var comptime_err_ret_trace: std.array_list.Managed(Zcu.LazySrcLoc) = .init(gpa);
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
        .comptime_reason = .{ .reason = .{
            .src = .{
                .base_node_inst = comptime_unit.zir_index,
                .offset = .{ .token_offset = .zero },
            },
            .r = .{ .simple = .comptime_keyword },
        } },
        .src_base_inst = comptime_unit.zir_index,
        .type_name_ctx = try ip.getOrPutStringFmt(gpa, pt.tid, "{f}.comptime", .{
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

    _ = zcu.nav_val_analysis_queued.swapRemove(nav_id);

    const anal_unit: AnalUnit = .wrap(.{ .nav_val = nav_id });
    const nav = ip.getNav(nav_id);

    log.debug("ensureNavValUpToDate {f}", .{zcu.fmtAnalUnit(anal_unit)});

    assert(!zcu.analysis_in_progress.contains(anal_unit));

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
        zcu.deleteUnitCompileLogs(anal_unit);
        if (zcu.failed_analysis.fetchSwapRemove(anal_unit)) |kv| {
            kv.value.destroy(gpa);
        }
        _ = zcu.transitive_failed_analysis.swapRemove(anal_unit);
        ip.removeDependenciesForDepender(gpa, anal_unit);
    } else {
        // We can trust the current information about this unit.
        if (prev_failed) return error.AnalysisFail;
        switch (nav.status) {
            .unresolved, .type_resolved => {},
            .fully_resolved => return,
        }
    }

    if (zcu.comp.debugIncremental()) {
        const info = try zcu.incremental_debug_state.getUnitInfo(gpa, anal_unit);
        info.last_update_gen = zcu.generation;
        info.deps.clearRetainingCapacity();
    }

    const unit_tracking = zcu.trackUnitSema(nav.fqn.toSlice(ip), nav.srcInst(ip));
    defer unit_tracking.end(zcu);

    const invalidate_value: bool, const new_failed: bool = if (pt.analyzeNavVal(nav_id)) |result| res: {
        break :res .{
            // If the unit has gone from failed to success, we still need to invalidate the dependencies.
            result.val_changed or prev_failed,
            false,
        };
    } else |err| switch (err) {
        error.AnalysisFail => res: {
            if (!zcu.failed_analysis.contains(anal_unit)) {
                // If this unit caused the error, it would have an entry in `failed_analysis`.
                // Since it does not, this must be a transitive failure.
                try zcu.transitive_failed_analysis.put(gpa, anal_unit, {});
                log.debug("mark transitive analysis failure for {f}", .{zcu.fmtAnalUnit(anal_unit)});
            }
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
        error.ComptimeReturn => unreachable,
        error.ComptimeBreak => unreachable,
    };

    if (was_outdated) {
        const dependee: InternPool.Dependee = .{ .nav_val = nav_id };
        if (invalidate_value) {
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

    // If there isn't a type annotation, then we have also just resolved the type. That means the
    // the type is up-to-date, so it won't have the chance to mark its own dependency on the value;
    // we must do that ourselves.
    type_deps_on_val: {
        const inst_resolved = nav.analysis.?.zir_index.resolveFull(ip) orelse break :type_deps_on_val;
        const file = zcu.fileByIndex(inst_resolved.file);
        const zir_decl = file.zir.?.getDeclaration(inst_resolved.inst);
        if (zir_decl.type_body != null) break :type_deps_on_val;
        // The type does indeed depend on the value. We are responsible for populating all state of
        // the `nav_ty`, including exports, references, errors, and dependencies.
        const ty_unit: AnalUnit = .wrap(.{ .nav_ty = nav_id });
        const ty_was_outdated = zcu.outdated.swapRemove(ty_unit) or
            zcu.potentially_outdated.swapRemove(ty_unit);
        if (ty_was_outdated) {
            _ = zcu.outdated_ready.swapRemove(ty_unit);
            zcu.deleteUnitExports(ty_unit);
            zcu.deleteUnitReferences(ty_unit);
            zcu.deleteUnitCompileLogs(ty_unit);
            if (zcu.failed_analysis.fetchSwapRemove(ty_unit)) |kv| {
                kv.value.destroy(gpa);
            }
            _ = zcu.transitive_failed_analysis.swapRemove(ty_unit);
            ip.removeDependenciesForDepender(gpa, ty_unit);
        }
        try pt.addDependency(ty_unit, .{ .nav_val = nav_id });
        if (new_failed) try zcu.transitive_failed_analysis.put(gpa, ty_unit, {});
        if (ty_was_outdated) try zcu.markDependeeOutdated(.marked_po, .{ .nav_ty = nav_id });
    }

    if (new_failed) return error.AnalysisFail;
}

fn analyzeNavVal(pt: Zcu.PerThread, nav_id: InternPool.Nav.Index) Zcu.CompileError!struct { val_changed: bool } {
    const zcu = pt.zcu;
    const gpa = zcu.gpa;
    const ip = &zcu.intern_pool;

    const anal_unit: AnalUnit = .wrap(.{ .nav_val = nav_id });
    const old_nav = ip.getNav(nav_id);

    log.debug("analyzeNavVal {f}", .{zcu.fmtAnalUnit(anal_unit)});

    const inst_resolved = old_nav.analysis.?.zir_index.resolveFull(ip) orelse return error.AnalysisFail;
    const file = zcu.fileByIndex(inst_resolved.file);
    const zir = file.zir.?;
    const zir_decl = zir.getDeclaration(inst_resolved.inst);

    try zcu.analysis_in_progress.putNoClobber(gpa, anal_unit, {});
    errdefer _ = zcu.analysis_in_progress.swapRemove(anal_unit);

    // If there's no type body, we are also resolving the type here.
    if (zir_decl.type_body == null) {
        try zcu.analysis_in_progress.putNoClobber(gpa, .wrap(.{ .nav_ty = nav_id }), {});
    }
    errdefer if (zir_decl.type_body == null) {
        _ = zcu.analysis_in_progress.swapRemove(.wrap(.{ .nav_ty = nav_id }));
    };

    var analysis_arena: std.heap.ArenaAllocator = .init(gpa);
    defer analysis_arena.deinit();

    var comptime_err_ret_trace: std.array_list.Managed(Zcu.LazySrcLoc) = .init(gpa);
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

    // Every `Nav` declares a dependency on the source of the corresponding declaration.
    try sema.declareDependency(.{ .src_hash = old_nav.analysis.?.zir_index });

    // In theory, we would also add a reference to the corresponding `nav_val` unit here: there are
    // always references in both directions between a `nav_val` and `nav_ty`. However, to save memory,
    // these references are known implicitly. See logic in `Zcu.resolveReferences`.

    var block: Sema.Block = .{
        .parent = null,
        .sema = &sema,
        .namespace = old_nav.analysis.?.namespace,
        .instructions = .{},
        .inlining = null,
        .comptime_reason = undefined, // set below
        .src_base_inst = old_nav.analysis.?.zir_index,
        .type_name_ctx = old_nav.fqn,
    };
    defer block.instructions.deinit(gpa);

    const ty_src = block.src(.{ .node_offset_var_decl_ty = .zero });
    const init_src = block.src(.{ .node_offset_var_decl_init = .zero });
    const align_src = block.src(.{ .node_offset_var_decl_align = .zero });
    const section_src = block.src(.{ .node_offset_var_decl_section = .zero });
    const addrspace_src = block.src(.{ .node_offset_var_decl_addrspace = .zero });

    block.comptime_reason = .{ .reason = .{
        .src = init_src,
        .r = .{ .simple = .container_var_init },
    } };

    const maybe_ty: ?Type = if (zir_decl.type_body != null) ty: {
        // Since we have a type body, the type is resolved separately!
        // Of course, we need to make sure we depend on it properly.
        try sema.declareDependency(.{ .nav_ty = nav_id });
        try pt.ensureNavTypeUpToDate(nav_id);
        break :ty .fromInterned(ip.getNav(nav_id).typeOf(ip));
    } else null;

    const final_val: ?Value = if (zir_decl.value_body) |value_body| val: {
        if (maybe_ty) |ty| {
            // Put the resolved type into `inst_map` to be used as the result type of the init.
            try sema.inst_map.ensureSpaceForInstructions(gpa, &.{inst_resolved.inst});
            sema.inst_map.putAssumeCapacity(inst_resolved.inst, Air.internedToRef(ty.toIntern()));
            const uncoerced_result_ref = try sema.resolveInlineBody(&block, value_body, inst_resolved.inst);
            assert(sema.inst_map.remove(inst_resolved.inst));

            const result_ref = try sema.coerce(&block, ty, uncoerced_result_ref, init_src);
            break :val try sema.resolveFinalDeclValue(&block, init_src, result_ref);
        } else {
            // Just analyze the value; we have no type to offer.
            const result_ref = try sema.resolveInlineBody(&block, value_body, inst_resolved.inst);
            break :val try sema.resolveFinalDeclValue(&block, init_src, result_ref);
        }
    } else null;

    const nav_ty: Type = maybe_ty orelse final_val.?.typeOf(zcu);

    // First, we must resolve the declaration's type. To do this, we analyze the type body if available,
    // or otherwise, we analyze the value body, populating `early_val` in the process.

    const is_const = is_const: switch (zir_decl.kind) {
        .@"comptime" => unreachable, // this is not a Nav
        .unnamed_test, .@"test", .decltest => {
            assert(nav_ty.zigTypeTag(zcu) == .@"fn");
            break :is_const true;
        },
        .@"const" => true,
        .@"var" => {
            try sema.validateVarType(
                &block,
                if (zir_decl.type_body != null) ty_src else init_src,
                nav_ty,
                zir_decl.linkage == .@"extern",
            );
            break :is_const false;
        },
    };

    // Now that we know the type, we can evaluate the alignment, linksection, and addrspace, to determine
    // the full pointer type of this declaration.

    const modifiers: Sema.NavPtrModifiers = if (zir_decl.type_body != null) m: {
        // `analyzeNavType` (from the `ensureNavTypeUpToDate` call above) has already populated this data into
        // the `Nav`. Load the new one, and pull the modifiers out.
        switch (ip.getNav(nav_id).status) {
            .unresolved => unreachable, // `analyzeNavType` will never leave us in this state
            inline .type_resolved, .fully_resolved => |r| break :m .{
                .alignment = r.alignment,
                .@"linksection" = r.@"linksection",
                .@"addrspace" = r.@"addrspace",
            },
        }
    } else m: {
        // `analyzeNavType` is essentially a stub which calls us. We are responsible for resolving this data.
        break :m try sema.resolveNavPtrModifiers(&block, zir_decl, inst_resolved.inst, nav_ty);
    };

    // Lastly, we must figure out the actual interned value to store to the `Nav`.
    // This isn't necessarily the same as `final_val`!

    const nav_val: Value = switch (zir_decl.linkage) {
        .normal, .@"export" => switch (zir_decl.kind) {
            .@"var" => .fromInterned(try pt.intern(.{ .variable = .{
                .ty = nav_ty.toIntern(),
                .init = final_val.?.toIntern(),
                .owner_nav = nav_id,
                .is_threadlocal = zir_decl.is_threadlocal,
            } })),
            else => final_val.?,
        },
        .@"extern" => val: {
            assert(final_val == null); // extern decls do not have a value body
            const lib_name: ?[]const u8 = if (zir_decl.lib_name != .empty) l: {
                break :l zir.nullTerminatedString(zir_decl.lib_name);
            } else null;
            if (lib_name) |l| {
                const lib_name_src = block.src(.{ .node_offset_lib_name = .zero });
                try sema.handleExternLibName(&block, lib_name_src, l);
            }
            break :val .fromInterned(try pt.getExtern(.{
                .name = old_nav.name,
                .ty = nav_ty.toIntern(),
                .lib_name = try ip.getOrPutStringOpt(gpa, pt.tid, lib_name, .no_embedded_nulls),
                .is_threadlocal = zir_decl.is_threadlocal,
                .linkage = .strong,
                .visibility = .default,
                .is_dll_import = false,
                .relocation = .any,
                .is_const = is_const,
                .alignment = modifiers.alignment,
                .@"addrspace" = modifiers.@"addrspace",
                .zir_index = old_nav.analysis.?.zir_index, // `declaration` instruction
                .owner_nav = undefined, // ignored by `getExtern`
                .source = .syntax,
            }));
        },
    };

    switch (nav_val.toIntern()) {
        .unreachable_value => unreachable, // assertion failure
        else => {},
    }

    // This resolves the type of the resolved value, not that value itself. If `nav_val` is a struct type,
    // this resolves the type `type` (which needs no resolution), not the struct itself.
    try nav_ty.resolveLayout(pt);

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
        .is_const = is_const,
        .alignment = modifiers.alignment,
        .@"linksection" = modifiers.@"linksection",
        .@"addrspace" = modifiers.@"addrspace",
    });

    // Mark the unit as completed before evaluating the export!
    assert(zcu.analysis_in_progress.swapRemove(anal_unit));
    if (zir_decl.type_body == null) {
        assert(zcu.analysis_in_progress.swapRemove(.wrap(.{ .nav_ty = nav_id })));
    }

    if (zir_decl.linkage == .@"export") {
        const export_src = block.src(.{ .token_offset = @enumFromInt(@intFromBool(zir_decl.is_pub)) });
        const name_slice = zir.nullTerminatedString(zir_decl.name);
        const name_ip = try ip.getOrPutString(gpa, pt.tid, name_slice, .no_embedded_nulls);
        try sema.analyzeExport(&block, export_src, .{ .name = name_ip }, nav_id);
    }

    try sema.flushExports();

    queue_codegen: {
        if (!queue_linker_work) break :queue_codegen;

        if (!try nav_ty.hasRuntimeBitsSema(pt)) {
            if (zcu.comp.config.use_llvm) break :queue_codegen;
            if (file.mod.?.strip) break :queue_codegen;
        }

        // This job depends on any resolve_type_fully jobs queued up before it.
        zcu.comp.link_prog_node.increaseEstimatedTotalItems(1);
        try zcu.comp.queueJob(.{ .link_nav = nav_id });
    }

    switch (old_nav.status) {
        .unresolved, .type_resolved => return .{ .val_changed = true },
        .fully_resolved => |old| return .{ .val_changed = old.val != nav_val.toIntern() },
    }
}

pub fn ensureNavTypeUpToDate(pt: Zcu.PerThread, nav_id: InternPool.Nav.Index) Zcu.SemaError!void {
    const tracy = trace(@src());
    defer tracy.end();

    const zcu = pt.zcu;
    const gpa = zcu.gpa;
    const ip = &zcu.intern_pool;

    const anal_unit: AnalUnit = .wrap(.{ .nav_ty = nav_id });
    const nav = ip.getNav(nav_id);

    log.debug("ensureNavTypeUpToDate {f}", .{zcu.fmtAnalUnit(anal_unit)});

    assert(!zcu.analysis_in_progress.contains(anal_unit));

    const type_resolved_by_value: bool = from_val: {
        const analysis = nav.analysis orelse break :from_val false;
        const inst_resolved = analysis.zir_index.resolveFull(ip) orelse break :from_val false;
        const file = zcu.fileByIndex(inst_resolved.file);
        const zir_decl = file.zir.?.getDeclaration(inst_resolved.inst);
        break :from_val zir_decl.type_body == null;
    };
    if (type_resolved_by_value) {
        // Logic at the end of `ensureNavValUpToDate` is directly responsible for populating our state.
        return pt.ensureNavValUpToDate(nav_id);
    }

    // Determine whether or not this `Nav`'s type is outdated. This also includes checking if the
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
        zcu.deleteUnitCompileLogs(anal_unit);
        if (zcu.failed_analysis.fetchSwapRemove(anal_unit)) |kv| {
            kv.value.destroy(gpa);
        }
        _ = zcu.transitive_failed_analysis.swapRemove(anal_unit);
        ip.removeDependenciesForDepender(gpa, anal_unit);
    } else {
        // We can trust the current information about this unit.
        if (prev_failed) return error.AnalysisFail;
        switch (nav.status) {
            .unresolved => {},
            .type_resolved, .fully_resolved => return,
        }
    }

    if (zcu.comp.debugIncremental()) {
        const info = try zcu.incremental_debug_state.getUnitInfo(gpa, anal_unit);
        info.last_update_gen = zcu.generation;
        info.deps.clearRetainingCapacity();
    }

    const unit_tracking = zcu.trackUnitSema(nav.fqn.toSlice(ip), nav.srcInst(ip));
    defer unit_tracking.end(zcu);

    const invalidate_type: bool, const new_failed: bool = if (pt.analyzeNavType(nav_id)) |result| res: {
        break :res .{
            // If the unit has gone from failed to success, we still need to invalidate the dependencies.
            result.type_changed or prev_failed,
            false,
        };
    } else |err| switch (err) {
        error.AnalysisFail => res: {
            if (!zcu.failed_analysis.contains(anal_unit)) {
                // If this unit caused the error, it would have an entry in `failed_analysis`.
                // Since it does not, this must be a transitive failure.
                try zcu.transitive_failed_analysis.put(gpa, anal_unit, {});
                log.debug("mark transitive analysis failure for {f}", .{zcu.fmtAnalUnit(anal_unit)});
            }
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
        error.ComptimeReturn => unreachable,
        error.ComptimeBreak => unreachable,
    };

    if (was_outdated) {
        const dependee: InternPool.Dependee = .{ .nav_ty = nav_id };
        if (invalidate_type) {
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

fn analyzeNavType(pt: Zcu.PerThread, nav_id: InternPool.Nav.Index) Zcu.CompileError!struct { type_changed: bool } {
    const zcu = pt.zcu;
    const gpa = zcu.gpa;
    const ip = &zcu.intern_pool;

    const anal_unit: AnalUnit = .wrap(.{ .nav_ty = nav_id });
    const old_nav = ip.getNav(nav_id);

    log.debug("analyzeNavType {f}", .{zcu.fmtAnalUnit(anal_unit)});

    const inst_resolved = old_nav.analysis.?.zir_index.resolveFull(ip) orelse return error.AnalysisFail;
    const file = zcu.fileByIndex(inst_resolved.file);
    const zir = file.zir.?;

    try zcu.analysis_in_progress.putNoClobber(gpa, anal_unit, {});
    defer assert(zcu.analysis_in_progress.swapRemove(anal_unit));

    const zir_decl = zir.getDeclaration(inst_resolved.inst);
    const type_body = zir_decl.type_body.?;

    var analysis_arena: std.heap.ArenaAllocator = .init(gpa);
    defer analysis_arena.deinit();

    var comptime_err_ret_trace: std.array_list.Managed(Zcu.LazySrcLoc) = .init(gpa);
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

    // Every `Nav` declares a dependency on the source of the corresponding declaration.
    try sema.declareDependency(.{ .src_hash = old_nav.analysis.?.zir_index });

    // In theory, we would also add a reference to the corresponding `nav_val` unit here: there are
    // always references in both directions between a `nav_val` and `nav_ty`. However, to save memory,
    // these references are known implicitly. See logic in `Zcu.resolveReferences`.

    var block: Sema.Block = .{
        .parent = null,
        .sema = &sema,
        .namespace = old_nav.analysis.?.namespace,
        .instructions = .{},
        .inlining = null,
        .comptime_reason = undefined, // set below
        .src_base_inst = old_nav.analysis.?.zir_index,
        .type_name_ctx = old_nav.fqn,
    };
    defer block.instructions.deinit(gpa);

    const ty_src = block.src(.{ .node_offset_var_decl_ty = .zero });

    block.comptime_reason = .{ .reason = .{
        .src = ty_src,
        .r = .{ .simple = .type },
    } };

    const resolved_ty: Type = ty: {
        const uncoerced_type_ref = try sema.resolveInlineBody(&block, type_body, inst_resolved.inst);
        const type_ref = try sema.coerce(&block, .type, uncoerced_type_ref, ty_src);
        break :ty .fromInterned(type_ref.toInterned().?);
    };

    try resolved_ty.resolveLayout(pt);

    // In the case where the type is specified, this function is also responsible for resolving
    // the pointer modifiers, i.e. alignment, linksection, addrspace.
    const modifiers = try sema.resolveNavPtrModifiers(&block, zir_decl, inst_resolved.inst, resolved_ty);

    const is_const = switch (zir_decl.kind) {
        .@"comptime" => unreachable,
        .unnamed_test, .@"test", .decltest, .@"const" => true,
        .@"var" => false,
    };

    const is_extern_decl = zir_decl.linkage == .@"extern";

    // Now for the question of the day: are the type and modifiers the same as before?
    // If they are, then we should actually keep the `Nav` as `fully_resolved` if it currently is.
    // That's because `analyzeNavVal` will later want to look at the resolved value to figure out
    // whether it's changed: if we threw that data away now, it would have to assume that the value
    // had changed, potentially spinning off loads of unnecessary re-analysis!
    const changed = switch (old_nav.status) {
        .unresolved => true,
        .type_resolved => |r| r.type != resolved_ty.toIntern() or
            r.alignment != modifiers.alignment or
            r.@"linksection" != modifiers.@"linksection" or
            r.@"addrspace" != modifiers.@"addrspace" or
            r.is_const != is_const or
            r.is_extern_decl != is_extern_decl,
        .fully_resolved => |r| ip.typeOf(r.val) != resolved_ty.toIntern() or
            r.alignment != modifiers.alignment or
            r.@"linksection" != modifiers.@"linksection" or
            r.@"addrspace" != modifiers.@"addrspace" or
            r.is_const != is_const or
            (old_nav.getExtern(ip) != null) != is_extern_decl,
    };

    if (!changed) return .{ .type_changed = false };

    ip.resolveNavType(nav_id, .{
        .type = resolved_ty.toIntern(),
        .is_const = is_const,
        .alignment = modifiers.alignment,
        .@"linksection" = modifiers.@"linksection",
        .@"addrspace" = modifiers.@"addrspace",
        .is_threadlocal = zir_decl.is_threadlocal,
        .is_extern_decl = is_extern_decl,
    });

    return .{ .type_changed = true };
}

pub fn ensureFuncBodyUpToDate(pt: Zcu.PerThread, func_index: InternPool.Index) Zcu.SemaError!void {
    dev.check(.sema);

    const tracy = trace(@src());
    defer tracy.end();

    const zcu = pt.zcu;
    const gpa = zcu.gpa;
    const ip = &zcu.intern_pool;

    _ = zcu.func_body_analysis_queued.swapRemove(func_index);

    const anal_unit: AnalUnit = .wrap(.{ .func = func_index });

    log.debug("ensureFuncBodyUpToDate {f}", .{zcu.fmtAnalUnit(anal_unit)});

    assert(!zcu.analysis_in_progress.contains(anal_unit));

    const func = zcu.funcInfo(func_index);

    assert(func.ty == func.uncoerced_ty); // analyze the body of the original function, not a coerced one

    const was_outdated = zcu.outdated.swapRemove(anal_unit) or
        zcu.potentially_outdated.swapRemove(anal_unit);

    const prev_failed = zcu.failed_analysis.contains(anal_unit) or zcu.transitive_failed_analysis.contains(anal_unit);

    if (was_outdated) {
        dev.check(.incremental);
        _ = zcu.outdated_ready.swapRemove(anal_unit);
        zcu.deleteUnitExports(anal_unit);
        zcu.deleteUnitReferences(anal_unit);
        zcu.deleteUnitCompileLogs(anal_unit);
        if (zcu.failed_analysis.fetchSwapRemove(anal_unit)) |kv| {
            kv.value.destroy(gpa);
        }
        _ = zcu.transitive_failed_analysis.swapRemove(anal_unit);
    } else {
        // We can trust the current information about this function.
        if (prev_failed) {
            return error.AnalysisFail;
        }
        if (func.analysisUnordered(ip).is_analyzed) return;
    }

    if (zcu.comp.debugIncremental()) {
        const info = try zcu.incremental_debug_state.getUnitInfo(gpa, anal_unit);
        info.last_update_gen = zcu.generation;
        info.deps.clearRetainingCapacity();
    }

    const owner_nav = ip.getNav(func.owner_nav);
    const unit_tracking = zcu.trackUnitSema(
        owner_nav.fqn.toSlice(ip),
        owner_nav.srcInst(ip),
    );
    defer unit_tracking.end(zcu);

    const ies_outdated, const new_failed = if (pt.analyzeFuncBody(func_index)) |result|
        .{ prev_failed or result.ies_outdated, false }
    else |err| switch (err) {
        error.AnalysisFail => res: {
            if (!zcu.failed_analysis.contains(anal_unit)) {
                // If this function caused the error, it would have an entry in `failed_analysis`.
                // Since it does not, this must be a transitive failure.
                try zcu.transitive_failed_analysis.put(gpa, anal_unit, {});
                log.debug("mark transitive analysis failure for {f}", .{zcu.fmtAnalUnit(anal_unit)});
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
        if (ip.getNav(func.owner_nav).status.fully_resolved.val != func_index) {
            // This function is no longer referenced! There's no point in re-analyzing it.
            // Just mark a transitive failure and move on.
            return error.AnalysisFail;
        }
    } else {
        const go_nav = zcu.funcInfo(func.generic_owner).owner_nav;
        // Among another things, this ensures that the function's `zir_body_inst` is correct.
        try pt.ensureNavValUpToDate(go_nav);
        if (ip.getNav(go_nav).status.fully_resolved.val != func.generic_owner) {
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

    log.debug("analyze and generate fn body {f}", .{zcu.fmtAnalUnit(anal_unit)});

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
    zcu.codegen_prog_node.increaseEstimatedTotalItems(1);
    comp.link_prog_node.increaseEstimatedTotalItems(1);
    try comp.queueJob(.{ .codegen_func = .{
        .func = func_index,
        .air = air,
    } });

    return .{ .ies_outdated = ies_outdated };
}

pub fn semaMod(pt: Zcu.PerThread, mod: *Module) !void {
    dev.check(.sema);
    const file_index = pt.zcu.module_roots.get(mod).?.unwrap().?;
    const root_type = pt.zcu.fileRootType(file_index);
    if (root_type == .none) {
        return pt.semaFile(file_index);
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
    const extended = file.zir.?.instructions.items(.data)[@intFromEnum(Zir.Inst.Index.main_struct_inst)].extended;
    assert(extended.opcode == .struct_decl);
    const small: Zir.Inst.StructDecl.Small = @bitCast(extended.small);
    assert(!small.has_captures_len);
    assert(!small.has_backing_int);
    assert(small.layout == .auto);
    var extra_index: usize = extended.operand + @typeInfo(Zir.Inst.StructDecl).@"struct".fields.len;
    const fields_len = if (small.has_fields_len) blk: {
        const fields_len = file.zir.?.extra[extra_index];
        extra_index += 1;
        break :blk fields_len;
    } else 0;
    const decls_len = if (small.has_decls_len) blk: {
        const decls_len = file.zir.?.extra[extra_index];
        extra_index += 1;
        break :blk decls_len;
    } else 0;
    const decls = file.zir.?.bodySlice(extra_index, decls_len);
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

    wip_ty.setName(ip, try file.internFullyQualifiedName(pt), .none);
    ip.namespacePtr(namespace_index).owner_type = wip_ty.index;

    if (zcu.comp.incremental) {
        try pt.addDependency(.wrap(.{ .type = wip_ty.index }), .{ .src_hash = tracked_inst });
    }

    try pt.scanNamespace(namespace_index, decls);
    try zcu.comp.queueJob(.{ .resolve_type_fully = wip_ty.index });
    codegen_type: {
        if (file.mod.?.strip) break :codegen_type;
        // This job depends on any resolve_type_fully jobs queued up before it.
        zcu.comp.link_prog_node.increaseEstimatedTotalItems(1);
        try zcu.comp.queueJob(.{ .link_type = wip_ty.index });
    }
    zcu.setFileRootType(file_index, wip_ty.index);
    if (zcu.comp.debugIncremental()) try zcu.incremental_debug_state.newType(zcu, wip_ty.index);
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
    const file_root_type = zcu.fileRootType(file_index);
    if (file_root_type == .none) return;

    log.debug("updateFileNamespace mod={s} sub_file_path={s}", .{
        file.mod.?.fully_qualified_name,
        file.sub_file_path,
    });

    const namespace_index = Type.fromInterned(file_root_type).getNamespaceIndex(zcu);
    const decls = decls: {
        const extended = file.zir.?.instructions.items(.data)[@intFromEnum(Zir.Inst.Index.main_struct_inst)].extended;
        const small: Zir.Inst.StructDecl.Small = @bitCast(extended.small);

        var extra_index: usize = extended.operand + @typeInfo(Zir.Inst.StructDecl).@"struct".fields.len;
        extra_index += @intFromBool(small.has_fields_len);
        const decls_len = if (small.has_decls_len) blk: {
            const decls_len = file.zir.?.extra[extra_index];
            extra_index += 1;
            break :blk decls_len;
        } else 0;
        break :decls file.zir.?.bodySlice(extra_index, decls_len);
    };
    try pt.scanNamespace(namespace_index, decls);
    zcu.namespacePtr(namespace_index).generation = zcu.generation;
}

fn semaFile(pt: Zcu.PerThread, file_index: Zcu.File.Index) Zcu.SemaError!void {
    const tracy = trace(@src());
    defer tracy.end();

    const zcu = pt.zcu;
    const file = zcu.fileByIndex(file_index);
    assert(file.getMode() == .zig);
    assert(zcu.fileRootType(file_index) == .none);

    assert(file.zir != null);

    const new_namespace_index = try pt.createNamespace(.{
        .parent = .none,
        .owner_type = undefined, // set in `createFileRootStruct`
        .file_scope = file_index,
        .generation = zcu.generation,
    });
    const struct_ty = try pt.createFileRootStruct(file_index, new_namespace_index, false);
    errdefer zcu.intern_pool.remove(pt.tid, struct_ty);

    if (zcu.comp.time_report) |*tr| {
        tr.stats.n_imported_files += 1;
    }
}

/// Called by AstGen worker threads when an import is seen. If `new_file` is returned, the caller is
/// then responsible for queueing a new AstGen job for the new file.
/// Assumes that `comp.mutex` is NOT locked. It will be locked by this function where necessary.
pub fn discoverImport(
    pt: Zcu.PerThread,
    importer_path: Compilation.Path,
    import_string: []const u8,
) Allocator.Error!union(enum) {
    module,
    existing_file: Zcu.File.Index,
    new_file: struct {
        index: Zcu.File.Index,
        file: *Zcu.File,
    },
} {
    const zcu = pt.zcu;
    const gpa = zcu.gpa;

    if (!mem.endsWith(u8, import_string, ".zig") and !mem.endsWith(u8, import_string, ".zon")) {
        return .module;
    }

    const new_path = try importer_path.upJoin(gpa, zcu.comp.dirs, import_string);
    errdefer new_path.deinit(gpa);

    // We're about to do a GOP on `import_table`, so we need the mutex.
    zcu.comp.mutex.lock();
    defer zcu.comp.mutex.unlock();

    const gop = try zcu.import_table.getOrPutAdapted(gpa, new_path, Zcu.ImportTableAdapter{ .zcu = zcu });
    errdefer _ = zcu.import_table.pop();
    if (gop.found_existing) {
        new_path.deinit(gpa); // we didn't need it for `File.path`
        return .{ .existing_file = gop.key_ptr.* };
    }

    zcu.import_table.lockPointers();
    defer zcu.import_table.unlockPointers();

    const new_file = try gpa.create(Zcu.File);
    errdefer gpa.destroy(new_file);

    const new_file_index = try zcu.intern_pool.createFile(gpa, pt.tid, .{
        .bin_digest = new_path.digest(),
        .file = new_file,
        .root_type = .none,
    });
    errdefer comptime unreachable; // because we don't remove the file from the internpool

    gop.key_ptr.* = new_file_index;
    new_file.* = .{
        .status = .never_loaded,
        .path = new_path,
        .stat = undefined,
        .is_builtin = false,
        .source = null,
        .tree = null,
        .zir = null,
        .zoir = null,
        .mod = null,
        .sub_file_path = undefined,
        .module_changed = false,
        .prev_zir = null,
        .zoir_invalidated = false,
    };

    return .{ .new_file = .{
        .index = new_file_index,
        .file = new_file,
    } };
}

pub fn doImport(
    pt: Zcu.PerThread,
    /// This file must have its `mod` populated.
    importer: *Zcu.File,
    import_string: []const u8,
) error{
    OutOfMemory,
    ModuleNotFound,
    IllegalZigImport,
}!struct {
    file: Zcu.File.Index,
    module_root: ?*Module,
} {
    const zcu = pt.zcu;
    const gpa = zcu.gpa;
    const imported_mod: ?*Module = m: {
        if (mem.eql(u8, import_string, "std")) break :m zcu.std_mod;
        if (mem.eql(u8, import_string, "root")) break :m zcu.root_mod;
        if (mem.eql(u8, import_string, "builtin")) {
            const opts = importer.mod.?.getBuiltinOptions(zcu.comp.config);
            break :m zcu.builtin_modules.get(opts.hash()).?;
        }
        break :m importer.mod.?.deps.get(import_string);
    };
    if (imported_mod) |mod| {
        if (zcu.module_roots.get(mod).?.unwrap()) |file_index| {
            return .{
                .file = file_index,
                .module_root = mod,
            };
        }
    }
    if (!std.mem.endsWith(u8, import_string, ".zig") and
        !std.mem.endsWith(u8, import_string, ".zon"))
    {
        return error.ModuleNotFound;
    }
    const path = try importer.path.upJoin(gpa, zcu.comp.dirs, import_string);
    defer path.deinit(gpa);
    if (try path.isIllegalZigImport(gpa, zcu.comp.dirs)) {
        return error.IllegalZigImport;
    }
    return .{
        .file = zcu.import_table.getKeyAdapted(path, Zcu.ImportTableAdapter{ .zcu = zcu }).?,
        .module_root = null,
    };
}
/// This is called once during `Compilation.create` and never again. "builtin" modules don't yet
/// exist, so are not added to `module_roots` here. They must be added when they are created.
pub fn populateModuleRootTable(pt: Zcu.PerThread) error{
    OutOfMemory,
    /// One of the specified modules had its root source file at an illegal path.
    IllegalZigImport,
}!void {
    const zcu = pt.zcu;
    const gpa = zcu.gpa;

    // We'll initially add [mod, undefined] pairs, and when we reach the pair while
    // iterating, rewrite the undefined value.
    const roots = &zcu.module_roots;
    roots.clearRetainingCapacity();

    // Start with:
    // * `std_mod`, which is the main root of analysis
    // * `root_mod`, which is `@import("root")`
    // * `main_mod`, which is a special analysis root in tests (and otherwise equal to `root_mod`)
    // All other modules will be found by traversing their dependency tables.
    try roots.ensureTotalCapacity(gpa, 3);
    roots.putAssumeCapacity(zcu.std_mod, undefined);
    roots.putAssumeCapacity(zcu.root_mod, undefined);
    roots.putAssumeCapacity(zcu.main_mod, undefined);
    var i: usize = 0;
    while (i < roots.count()) {
        const mod = roots.keys()[i];
        try roots.ensureUnusedCapacity(gpa, mod.deps.count());
        for (mod.deps.values()) |dep| {
            const gop = roots.getOrPutAssumeCapacity(dep);
            _ = gop; // we want to leave the value undefined if it was added
        }

        const root_file_out = &roots.values()[i];
        roots.lockPointers();
        defer roots.unlockPointers();

        i += 1;

        if (Zcu.File.modeFromPath(mod.root_src_path) == null) {
            root_file_out.* = .none;
            continue;
        }

        const path = try mod.root.join(gpa, zcu.comp.dirs, mod.root_src_path);
        errdefer path.deinit(gpa);

        if (try path.isIllegalZigImport(gpa, zcu.comp.dirs)) {
            return error.IllegalZigImport;
        }

        const gop = try zcu.import_table.getOrPutAdapted(gpa, path, Zcu.ImportTableAdapter{ .zcu = zcu });
        errdefer _ = zcu.import_table.pop();

        if (gop.found_existing) {
            path.deinit(gpa);
            root_file_out.* = gop.key_ptr.*.toOptional();
            continue;
        }

        zcu.import_table.lockPointers();
        defer zcu.import_table.unlockPointers();

        const new_file = try gpa.create(Zcu.File);
        errdefer gpa.destroy(new_file);

        const new_file_index = try zcu.intern_pool.createFile(gpa, pt.tid, .{
            .bin_digest = path.digest(),
            .file = new_file,
            .root_type = .none,
        });
        errdefer comptime unreachable; // because we don't remove the file from the internpool

        gop.key_ptr.* = new_file_index;
        root_file_out.* = new_file_index.toOptional();
        new_file.* = .{
            .status = .never_loaded,
            .path = path,
            .stat = undefined,
            .is_builtin = false,
            .source = null,
            .tree = null,
            .zir = null,
            .zoir = null,
            .mod = null,
            .sub_file_path = undefined,
            .module_changed = false,
            .prev_zir = null,
            .zoir_invalidated = false,
        };
    }
}

/// Clears and re-populates `pt.zcu.alive_files`, and determines the module identity of every alive
/// file. If a file's module changes, its `module_changed` flag is set for `updateZirRefs` to see.
/// Also clears and re-populates `failed_imports` and `multi_module_err` based on the set of alive
/// files.
///
/// Live files are also added as file system inputs if necessary.
///
/// Returns whether there is any live file which is failed. Howewver, this function does *not*
/// modify `pt.zcu.skip_analysis_this_update`.
///
/// If an error is returned, `pt.zcu.alive_files` might contain undefined values.
pub fn computeAliveFiles(pt: Zcu.PerThread) Allocator.Error!bool {
    const zcu = pt.zcu;
    const comp = zcu.comp;
    const gpa = zcu.gpa;

    var any_fatal_files = false;
    zcu.multi_module_err = null;
    zcu.failed_imports.clearRetainingCapacity();
    zcu.alive_files.clearRetainingCapacity();

    // This function will iterate the keys of `alive_files`, adding new entries as it discovers
    // imports. Once a file is in `alive_files`, it has its `mod` field up-to-date. If conflicting
    // imports are discovered for a file, we will set `multi_module_err`. Crucially, this traversal
    // is single-threaded, and depends only on the order of the imports map from AstGen, which makes
    // its behavior (in terms of which multi module errors are discovered) entirely consistent in a
    // multi-threaded environment (where things like file indices could differ between compiler runs).

    // The roots of our file liveness analysis will be the analysis roots.
    const analysis_roots = zcu.analysisRoots();
    try zcu.alive_files.ensureTotalCapacity(gpa, analysis_roots.len);
    for (analysis_roots) |mod| {
        const file_index = zcu.module_roots.get(mod).?.unwrap() orelse continue;
        const file = zcu.fileByIndex(file_index);

        file.mod = mod;
        file.sub_file_path = mod.root_src_path;

        zcu.alive_files.putAssumeCapacityNoClobber(file_index, .{ .analysis_root = mod });
    }

    var live_check_idx: usize = 0;
    while (live_check_idx < zcu.alive_files.count()) {
        const file_idx = zcu.alive_files.keys()[live_check_idx];
        const file = zcu.fileByIndex(file_idx);
        live_check_idx += 1;

        switch (file.status) {
            .never_loaded => unreachable, // everything reachable is loaded by the AstGen workers
            .retryable_failure, .astgen_failure => any_fatal_files = true,
            .success => {},
        }

        try comp.appendFileSystemInput(file.path);

        switch (file.getMode()) {
            .zig => {}, // continue to logic below
            .zon => continue, // ZON can't import anything
        }

        if (file.status != .success) continue; // ZIR not valid if there was a file failure

        const zir = file.zir.?;
        const imports_index = zir.extra[@intFromEnum(Zir.ExtraIndex.imports)];
        if (imports_index == 0) continue; // this Zig file has no imports
        const extra = zir.extraData(Zir.Inst.Imports, imports_index);
        var extra_index = extra.end;
        try zcu.alive_files.ensureUnusedCapacity(gpa, extra.data.imports_len);
        for (0..extra.data.imports_len) |_| {
            const item = zir.extraData(Zir.Inst.Imports.Item, extra_index);
            extra_index = item.end;
            const import_path = zir.nullTerminatedString(item.data.name);

            if (std.mem.eql(u8, import_path, "builtin")) {
                // We've not necessarily generated builtin modules yet, so `doImport` could fail. Instead,
                // create the module here. Then, since we know that `builtin.zig` doesn't have an error and
                // has no imports other than 'std', we can just continue onto the next import.
                try pt.updateBuiltinModule(file.mod.?.getBuiltinOptions(comp.config));
                continue;
            }

            const res = pt.doImport(file, import_path) catch |err| switch (err) {
                error.OutOfMemory => |e| return e,
                error.ModuleNotFound => {
                    // It'd be nice if this were a file-level error, but allowing this turns out to
                    // be quite important in practice, e.g. for optional dependencies whose import
                    // is behind a comptime condition. So, the error here happens in `Sema` instead.
                    continue;
                },
                error.IllegalZigImport => {
                    try zcu.failed_imports.append(gpa, .{
                        .file_index = file_idx,
                        .import_string = item.data.name,
                        .import_token = item.data.token,
                        .kind = .illegal_zig_import,
                    });
                    continue;
                },
            };

            // If the import was not of a module, we propagate our own module.
            const imported_mod = res.module_root orelse file.mod.?;
            const imported_file = zcu.fileByIndex(res.file);

            const imported_ref: Zcu.File.Reference = .{ .import = .{
                .importer = file_idx,
                .tok = item.data.token,
                .module = res.module_root,
            } };

            const gop = zcu.alive_files.getOrPutAssumeCapacity(res.file);
            if (gop.found_existing) {
                // This means `imported_file.mod` is already populated. If it doesn't match
                // `imported_mod`, then this file exists in multiple modules.
                if (imported_file.mod.? != imported_mod) {
                    // We only report the first multi-module error we see. Thanks to this traversal
                    // being deterministic, this doesn't raise consistency issues. Moreover, it's a
                    // useful behavior; we know that this error can be reached *without* realising
                    // that any other files are multi-module, so it's probably approximately where
                    // the problem "begins". Any compilation with a multi-module file is likely to
                    // have a huge number of them by transitive imports, so just reporting this one
                    // hopefully keeps the error focused.
                    zcu.multi_module_err = .{
                        .file = file_idx,
                        .modules = .{ imported_file.mod.?, imported_mod },
                        .refs = .{ gop.value_ptr.*, imported_ref },
                    };
                    // If we discover a multi-module error, it's the only error which matters, and we
                    // can't discern any useful information about the file's own imports; so just do
                    // an early exit now we've populated `zcu.multi_module_err`.
                    return any_fatal_files;
                }
                continue;
            }
            // We're the first thing we've found referencing `res.file`.
            gop.value_ptr.* = imported_ref;
            if (imported_file.mod) |m| {
                if (m == imported_mod) {
                    // Great, the module and sub path are already populated correctly.
                    continue;
                }
            }
            // We need to set the file's module, meaning we also need to compute its sub path.
            // This string is externally managed and has a lifetime at least equal to the
            // lifetime of `imported_file`. `null` means the file is outside its module root.
            switch (imported_file.path.isNested(imported_mod.root)) {
                .yes => |sub_path| {
                    if (imported_file.mod != null) {
                        // There was a module from a previous update; instruct `updateZirRefs` to
                        // invalidate everything.
                        imported_file.module_changed = true;
                    }
                    imported_file.mod = imported_mod;
                    imported_file.sub_file_path = sub_path;
                },
                .different_roots, .no => {
                    try zcu.failed_imports.append(gpa, .{
                        .file_index = file_idx,
                        .import_string = item.data.name,
                        .import_token = item.data.token,
                        .kind = .file_outside_module_root,
                    });
                    _ = zcu.alive_files.pop(); // we failed to populate `mod`/`sub_file_path`
                },
            }
        }
    }

    return any_fatal_files;
}

/// Ensures that the `@import("builtin")` module corresponding to `opts` is available in
/// `builtin_modules`, and that its file is populated. Also ensures the file on disk is
/// up-to-date, setting a misc failure if updating it fails.
/// Asserts that the imported `builtin.zig` has no ZIR errors, and that it has only one
/// import, which is 'std'.
pub fn updateBuiltinModule(pt: Zcu.PerThread, opts: Builtin) Allocator.Error!void {
    const zcu = pt.zcu;
    const comp = zcu.comp;
    const gpa = zcu.gpa;

    const gop = try zcu.builtin_modules.getOrPut(gpa, opts.hash());
    if (gop.found_existing) return; // the `File` is up-to-date
    errdefer _ = zcu.builtin_modules.pop();

    const mod: *Module = try .createBuiltin(comp.arena, opts, comp.dirs);
    assert(std.mem.eql(u8, &mod.getBuiltinOptions(comp.config).hash(), gop.key_ptr)); // builtin is its own builtin

    const path = try mod.root.join(gpa, comp.dirs, "builtin.zig");
    errdefer path.deinit(gpa);

    const file_gop = try zcu.import_table.getOrPutAdapted(gpa, path, Zcu.ImportTableAdapter{ .zcu = zcu });
    // `Compilation.Path.isIllegalZigImport` checks guard file creation, so
    // there isn't an `import_table` entry for this path yet.
    assert(!file_gop.found_existing);
    errdefer _ = zcu.import_table.pop();

    try zcu.module_roots.ensureUnusedCapacity(gpa, 1);

    const file = try gpa.create(Zcu.File);
    errdefer gpa.destroy(file);

    file.* = .{
        .status = .never_loaded,
        .stat = undefined,
        .path = path,
        .is_builtin = true,
        .source = null,
        .tree = null,
        .zir = null,
        .zoir = null,
        .mod = mod,
        .sub_file_path = "builtin.zig",
        .module_changed = false,
        .prev_zir = null,
        .zoir_invalidated = false,
    };

    const file_index = try zcu.intern_pool.createFile(gpa, pt.tid, .{
        .bin_digest = path.digest(),
        .file = file,
        .root_type = .none,
    });

    gop.value_ptr.* = mod;
    file_gop.key_ptr.* = file_index;
    zcu.module_roots.putAssumeCapacityNoClobber(mod, file_index.toOptional());
    try opts.populateFile(gpa, file);

    assert(file.status == .success);
    assert(!file.zir.?.hasCompileErrors());
    {
        // Check that it has only one import, which is 'std'.
        const imports_idx = file.zir.?.extra[@intFromEnum(Zir.ExtraIndex.imports)];
        assert(imports_idx != 0); // there is an import
        const extra = file.zir.?.extraData(Zir.Inst.Imports, imports_idx);
        assert(extra.data.imports_len == 1); // there is exactly one import
        const item = file.zir.?.extraData(Zir.Inst.Imports.Item, extra.end);
        const import_path = file.zir.?.nullTerminatedString(item.data.name);
        assert(mem.eql(u8, import_path, "std")); // the single import is of 'std'
    }

    Builtin.updateFileOnDisk(file, comp) catch |err| comp.setMiscFailure(
        .write_builtin_zig,
        "unable to write '{f}': {s}",
        .{ file.path.fmt(comp), @errorName(err) },
    );
}

pub fn embedFile(
    pt: Zcu.PerThread,
    cur_file: *Zcu.File,
    import_string: []const u8,
) error{
    OutOfMemory,
    ImportOutsideModulePath,
    CurrentWorkingDirectoryUnlinked,
}!Zcu.EmbedFile.Index {
    const zcu = pt.zcu;
    const gpa = zcu.gpa;

    const opt_mod: ?*Module = m: {
        if (mem.eql(u8, import_string, "std")) break :m zcu.std_mod;
        if (mem.eql(u8, import_string, "root")) break :m zcu.root_mod;
        if (mem.eql(u8, import_string, "builtin")) {
            const opts = cur_file.mod.?.getBuiltinOptions(zcu.comp.config);
            break :m zcu.builtin_modules.get(opts.hash()).?;
        }
        break :m cur_file.mod.?.deps.get(import_string);
    };
    if (opt_mod) |mod| {
        const path = try mod.root.join(gpa, zcu.comp.dirs, mod.root_src_path);
        errdefer path.deinit(gpa);

        const gop = try zcu.embed_table.getOrPutAdapted(gpa, path, Zcu.EmbedTableAdapter{});
        if (gop.found_existing) {
            path.deinit(gpa); // we're not using this key
            return @enumFromInt(gop.index);
        }
        errdefer _ = zcu.embed_table.pop();
        gop.key_ptr.* = try pt.newEmbedFile(path);
        return @enumFromInt(gop.index);
    }

    const embed_file: *Zcu.EmbedFile, const embed_file_idx: Zcu.EmbedFile.Index = ef: {
        const path = try cur_file.path.upJoin(gpa, zcu.comp.dirs, import_string);
        errdefer path.deinit(gpa);
        const gop = try zcu.embed_table.getOrPutAdapted(gpa, path, Zcu.EmbedTableAdapter{});
        if (gop.found_existing) {
            path.deinit(gpa); // we're not using this key
            break :ef .{ gop.key_ptr.*, @enumFromInt(gop.index) };
        } else {
            errdefer _ = zcu.embed_table.pop();
            gop.key_ptr.* = try pt.newEmbedFile(path);
            break :ef .{ gop.key_ptr.*, @enumFromInt(gop.index) };
        }
    };

    switch (embed_file.path.isNested(cur_file.mod.?.root)) {
        .yes => {},
        .different_roots, .no => return error.ImportOutsideModulePath,
    }

    return embed_file_idx;
}

pub fn updateEmbedFile(
    pt: Zcu.PerThread,
    ef: *Zcu.EmbedFile,
    /// If not `null`, the interned file data is stored here, if it was loaded.
    /// `newEmbedFile` uses this to add the file to the `whole` cache manifest.
    ip_str_out: ?*?InternPool.String,
) Allocator.Error!void {
    pt.updateEmbedFileInner(ef, ip_str_out) catch |err| switch (err) {
        error.OutOfMemory => |e| return e,
        else => |e| {
            ef.val = .none;
            ef.err = e;
            ef.stat = undefined;
        },
    };
}

fn updateEmbedFileInner(
    pt: Zcu.PerThread,
    ef: *Zcu.EmbedFile,
    ip_str_out: ?*?InternPool.String,
) !void {
    const tid = pt.tid;
    const zcu = pt.zcu;
    const gpa = zcu.gpa;
    const ip = &zcu.intern_pool;

    var file = f: {
        const dir, const sub_path = ef.path.openInfo(zcu.comp.dirs);
        break :f try dir.openFile(sub_path, .{});
    };
    defer file.close();

    const stat: Cache.File.Stat = .fromFs(try file.stat());

    if (ef.val != .none) {
        const old_stat = ef.stat;
        const unchanged_metadata =
            stat.size == old_stat.size and
            stat.mtime == old_stat.mtime and
            stat.inode == old_stat.inode;
        if (unchanged_metadata) return;
    }

    const size = std.math.cast(usize, stat.size) orelse return error.FileTooBig;
    const size_plus_one = std.math.add(usize, size, 1) catch return error.FileTooBig;

    // The loaded bytes of the file, including a sentinel 0 byte.
    const ip_str: InternPool.String = str: {
        const strings = ip.getLocal(tid).getMutableStrings(gpa);
        const old_len = strings.mutate.len;
        errdefer strings.shrinkRetainingCapacity(old_len);
        const bytes = (try strings.addManyAsSlice(size_plus_one))[0];
        var fr = file.reader(&.{});
        fr.size = stat.size;
        fr.interface.readSliceAll(bytes[0..size]) catch |err| switch (err) {
            error.ReadFailed => return fr.err.?,
            error.EndOfStream => return error.UnexpectedEof,
        };
        bytes[size] = 0;
        break :str try ip.getOrPutTrailingString(gpa, tid, @intCast(bytes.len), .maybe_embedded_nulls);
    };
    if (ip_str_out) |p| p.* = ip_str;

    const array_ty = try pt.arrayType(.{
        .len = size,
        .sentinel = .zero_u8,
        .child = .u8_type,
    });
    const ptr_ty = try pt.singleConstPtrType(array_ty);

    const array_val = try pt.intern(.{ .aggregate = .{
        .ty = array_ty.toIntern(),
        .storage = .{ .bytes = ip_str },
    } });
    const ptr_val = try pt.intern(.{ .ptr = .{
        .ty = ptr_ty.toIntern(),
        .base_addr = .{ .uav = .{
            .val = array_val,
            .orig_ty = ptr_ty.toIntern(),
        } },
        .byte_offset = 0,
    } });

    ef.val = ptr_val;
    ef.err = null;
    ef.stat = stat;
}

/// Assumes that `path` is allocated into `gpa`. Takes ownership of `path` on success.
fn newEmbedFile(
    pt: Zcu.PerThread,
    path: Compilation.Path,
) !*Zcu.EmbedFile {
    const zcu = pt.zcu;
    const comp = zcu.comp;
    const gpa = zcu.gpa;
    const ip = &zcu.intern_pool;

    const new_file = try gpa.create(Zcu.EmbedFile);
    errdefer gpa.destroy(new_file);

    new_file.* = .{
        .path = path,
        .val = .none,
        .err = null,
        .stat = undefined,
    };

    var opt_ip_str: ?InternPool.String = null;
    try pt.updateEmbedFile(new_file, &opt_ip_str);

    try comp.appendFileSystemInput(path);

    // Add the file contents to the `whole` cache manifest if necessary.
    cache: {
        const whole = switch (zcu.comp.cache_use) {
            .whole => |whole| whole,
            .incremental, .none => break :cache,
        };
        const man = whole.cache_manifest orelse break :cache;
        const ip_str = opt_ip_str orelse break :cache; // this will be a compile error

        const array_len = Value.fromInterned(new_file.val).typeOf(zcu).childType(zcu).arrayLen(zcu);
        const contents = ip_str.toSlice(array_len, ip);

        const path_str = try path.toAbsolute(comp.dirs, gpa);
        defer gpa.free(path_str);

        whole.cache_manifest_mutex.lock();
        defer whole.cache_manifest_mutex.unlock();

        man.addFilePostContents(path_str, contents, new_file.stat) catch |err| switch (err) {
            error.Unexpected => unreachable,
            else => |e| return e,
        };
    }

    return new_file;
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

    const tracked_unit = zcu.trackUnitSema(
        Type.fromInterned(namespace.owner_type).containerTypeName(ip).toSlice(ip),
        null,
    );
    defer tracked_unit.end(zcu);

    // For incremental updates, `scanDecl` wants to look up existing decls by their ZIR index rather
    // than their name. We'll build an efficient mapping now, then discard the current `decls`.
    // We map to the `AnalUnit`, since not every declaration has a `Nav`.
    var existing_by_inst: std.AutoHashMapUnmanaged(InternPool.TrackedInst.Index, InternPool.AnalUnit) = .empty;
    defer existing_by_inst.deinit(gpa);

    try existing_by_inst.ensureTotalCapacity(gpa, @intCast(
        namespace.pub_decls.count() + namespace.priv_decls.count() +
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
    unnamed_test_index: usize = 0,

    fn avoidNameConflict(iter: *ScanDeclIter, comptime fmt: []const u8, args: anytype) !InternPool.NullTerminatedString {
        const pt = iter.pt;
        const gpa = pt.zcu.gpa;
        const ip = &pt.zcu.intern_pool;
        var name = try ip.getOrPutStringFmt(gpa, pt.tid, fmt, args, .no_embedded_nulls);
        var gop = try iter.seen_decls.getOrPut(gpa, name);
        var next_suffix: u32 = 0;
        while (gop.found_existing) {
            name = try ip.getOrPutStringFmt(gpa, pt.tid, "{f}_{d}", .{ name.fmt(ip), next_suffix }, .no_embedded_nulls);
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
        const zir = file.zir.?;
        const ip = &zcu.intern_pool;

        const decl = zir.getDeclaration(decl_inst);

        const maybe_name: InternPool.OptionalNullTerminatedString = switch (decl.kind) {
            .@"comptime" => name: {
                if (iter.pass != .unnamed) return;
                break :name .none;
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
                const nav = if (existing_unit) |eu| eu.unwrap().nav_val else nav: {
                    const nav = try ip.createDeclNav(gpa, pt.tid, name, fqn, tracked_inst, namespace_index);
                    if (zcu.comp.debugIncremental()) try zcu.incremental_debug_state.newNav(zcu, nav);
                    break :nav nav;
                };

                const unit: AnalUnit = .wrap(.{ .nav_val = nav });

                assert(ip.getNav(nav).name == name);
                assert(ip.getNav(nav).fqn == fqn);

                const want_analysis = switch (decl.kind) {
                    .@"comptime" => unreachable,
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
                "scanDecl queue analyze_comptime_unit file='{s}' unit={f}",
                .{ namespace.fileScope(zcu).sub_file_path, zcu.fmtAnalUnit(unit) },
            );
            try comp.queueJob(.{ .analyze_comptime_unit = unit });
        }
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
    const zir = file.zir.?;

    try zcu.analysis_in_progress.putNoClobber(gpa, anal_unit, {});
    errdefer _ = zcu.analysis_in_progress.swapRemove(anal_unit);

    func.setAnalyzed(ip);
    if (func.analysisUnordered(ip).inferred_error_set) {
        func.setResolvedErrorSet(ip, .none);
    }

    if (zcu.comp.time_report) |*tr| {
        if (func.generic_owner != .none) {
            tr.stats.n_generic_instances += 1;
        }
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

    var comptime_err_ret_trace = std.array_list.Managed(Zcu.LazySrcLoc).init(gpa);
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
    ip.funcSetHasErrorTrace(func_index, fn_ty_info.cc == .auto);

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
        .comptime_reason = null,
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
    for (fn_info.param_body[0..src_params_len], 0..) |inst, zir_param_index| {
        const gop = sema.inst_map.getOrPutAssumeCapacity(inst);
        if (gop.found_existing) continue; // provided above by comptime arg

        const param_ty = fn_ty_info.param_types.get(ip)[runtime_param_index];
        runtime_param_index += 1;

        const opt_opv = sema.typeHasOnePossibleValue(Type.fromInterned(param_ty)) catch |err| switch (err) {
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
                .zir_param_index = @intCast(zir_param_index),
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
        error.ComptimeReturn => unreachable,
        else => |e| return e,
    };

    for (sema.unresolved_inferred_allocs.keys()) |ptr_inst| {
        // The lack of a resolve_inferred_alloc means that this instruction
        // is unused so it just has to be a no-op.
        sema.air_instructions.set(@intFromEnum(ptr_inst), .{
            .tag = .alloc,
            .data = .{ .ty = .ptr_const_comptime_int },
        });
    }

    func.setBranchHint(ip, sema.branch_hint orelse .none);

    if (zcu.comp.config.any_error_tracing and func.analysisUnordered(ip).has_error_trace and fn_ty_info.cc != .auto) {
        // We're using an error trace, but didn't start out with one from the caller.
        // We'll have to create it at the start of the function.
        sema.setupErrorReturnTrace(&inner_block, last_arg_index) catch |err| switch (err) {
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
            .offset = Zcu.LazySrcLoc.Offset.nodeOffset(.zero),
        }, ies) catch |err| switch (err) {
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
    sema.resolveFnTypes(fn_ty, inner_block.nodeOffset(.zero)) catch |err| switch (err) {
        error.ComptimeReturn => unreachable,
        error.ComptimeBreak => unreachable,
        else => |e| return e,
    };

    try sema.flushExports();

    defer {
        sema.air_instructions = .empty;
        sema.air_extra = .empty;
    }
    return .{
        .instructions = sema.air_instructions.slice(),
        .extra = sema.air_extra,
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
fn lockAndClearFileCompileError(pt: Zcu.PerThread, file_index: Zcu.File.Index, file: *Zcu.File) void {
    const maybe_has_error = switch (file.status) {
        .never_loaded => false,
        .retryable_failure => true,
        .astgen_failure => true,
        .success => switch (file.getMode()) {
            .zig => has_error: {
                const zir = file.zir orelse break :has_error false;
                break :has_error zir.hasCompileErrors();
            },
            .zon => has_error: {
                const zoir = file.zoir orelse break :has_error false;
                break :has_error zoir.hasCompileErrors();
            },
        },
    };

    // If runtime safety is on, let's quickly lock the mutex and check anyway.
    if (!maybe_has_error and !std.debug.runtime_safety) {
        return;
    }

    pt.zcu.comp.mutex.lock();
    defer pt.zcu.comp.mutex.unlock();
    if (pt.zcu.failed_files.fetchSwapRemove(file_index)) |kv| {
        assert(maybe_has_error); // the runtime safety case above
        if (kv.value) |msg| pt.zcu.gpa.free(msg); // delete previous error message
    }
}

/// Called from `Compilation.update`, after everything is done, just before
/// reporting compile errors. In this function we emit exported symbol collision
/// errors and communicate exported symbols to the linker backend.
pub fn processExports(pt: Zcu.PerThread) !void {
    const zcu = pt.zcu;
    const gpa = zcu.gpa;

    if (zcu.single_exports.count() == 0 and zcu.multi_exports.count() == 0) {
        // We can avoid a call to `resolveReferences` in this case.
        return;
    }

    // First, construct a mapping of every exported value and Nav to the indices of all its different exports.
    var nav_exports: std.AutoArrayHashMapUnmanaged(InternPool.Nav.Index, std.ArrayListUnmanaged(Zcu.Export.Index)) = .empty;
    var uav_exports: std.AutoArrayHashMapUnmanaged(InternPool.Index, std.ArrayListUnmanaged(Zcu.Export.Index)) = .empty;
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

    const unit_references = try zcu.resolveReferences();

    for (zcu.single_exports.keys(), zcu.single_exports.values()) |exporter, export_idx| {
        const exp = export_idx.ptr(zcu);
        if (!unit_references.contains(exporter)) {
            // This export might already have been sent to the linker on a previous update, in which case we need to delete it.
            // The linker export API should be modified to eliminate this call. #23616
            if (zcu.comp.bin_file) |lf| {
                if (zcu.llvm_object == null) {
                    lf.deleteExport(exp.exported, exp.opts.name);
                }
            }
            continue;
        }
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

    for (zcu.multi_exports.keys(), zcu.multi_exports.values()) |exporter, info| {
        const exports = zcu.all_exports.items[info.index..][0..info.len];
        if (!unit_references.contains(exporter)) {
            // This export might already have been sent to the linker on a previous update, in which case we need to delete it.
            // The linker export API should be modified to eliminate this loop. #23616
            if (zcu.comp.bin_file) |lf| {
                if (zcu.llvm_object == null) {
                    for (exports) |exp| {
                        lf.deleteExport(exp.exported, exp.opts.name);
                    }
                }
            }
            continue;
        }
        for (exports, info.index..) |exp, export_idx| {
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
            try value_ptr.append(gpa, @enumFromInt(export_idx));
        }
    }

    // If there are compile errors, we won't call `updateExports`. Not only would it be redundant
    // work, but the linker may not have seen an exported `Nav` due to a compile error, so linker
    // implementations would have to handle that case. This early return avoids that.
    const skip_linker_work = zcu.comp.anyErrors();

    // Map symbol names to `Export` for name collision detection.
    var symbol_exports: SymbolExports = .{};
    defer symbol_exports.deinit(gpa);

    for (nav_exports.keys(), nav_exports.values()) |exported_nav, exports_list| {
        const exported: Zcu.Exported = .{ .nav = exported_nav };
        try pt.processExportsInner(&symbol_exports, exported, exports_list.items, skip_linker_work);
    }

    for (uav_exports.keys(), uav_exports.values()) |exported_uav, exports_list| {
        const exported: Zcu.Exported = .{ .uav = exported_uav };
        try pt.processExportsInner(&symbol_exports, exported, exports_list.items, skip_linker_work);
    }
}

const SymbolExports = std.AutoArrayHashMapUnmanaged(InternPool.NullTerminatedString, Zcu.Export.Index);

fn processExportsInner(
    pt: Zcu.PerThread,
    symbol_exports: *SymbolExports,
    exported: Zcu.Exported,
    export_indices: []const Zcu.Export.Index,
    skip_linker_work: bool,
) error{OutOfMemory}!void {
    const zcu = pt.zcu;
    const gpa = zcu.gpa;
    const ip = &zcu.intern_pool;

    for (export_indices) |export_idx| {
        const new_export = export_idx.ptr(zcu);
        const gop = try symbol_exports.getOrPut(gpa, new_export.opts.name);
        if (gop.found_existing) {
            new_export.status = .failed_retryable;
            try zcu.failed_exports.ensureUnusedCapacity(gpa, 1);
            const msg = try Zcu.ErrorMsg.create(gpa, new_export.src, "exported symbol collision: {f}", .{
                new_export.opts.name.fmt(ip),
            });
            errdefer msg.destroy(gpa);
            const other_export = gop.value_ptr.ptr(zcu);
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
                .unresolved, .type_resolved => break :failed true,
                .fully_resolved => |r| Value.fromInterned(r.val),
            };
            // If the value is a function, we also need to check if that function succeeded analysis.
            if (val.typeOf(zcu).zigTypeTag(zcu) == .@"fn") {
                const func_unit = AnalUnit.wrap(.{ .func = val.toIntern() });
                if (zcu.failed_analysis.contains(func_unit)) break :failed true;
                if (zcu.transitive_failed_analysis.contains(func_unit)) break :failed true;
            }
            break :failed false;
        }) {
            // This `Nav` is failed, so was never sent to codegen. There should be a compile error.
            assert(skip_linker_work);
        },
        .uav => {},
    }

    if (skip_linker_work) return;

    if (zcu.llvm_object) |llvm_object| {
        try zcu.handleUpdateExports(export_indices, llvm_object.updateExports(pt, exported, export_indices));
    } else if (zcu.comp.bin_file) |lf| {
        try zcu.handleUpdateExports(export_indices, lf.updateExports(pt, exported, export_indices));
    }
}

pub fn populateTestFunctions(pt: Zcu.PerThread) Allocator.Error!void {
    const zcu = pt.zcu;
    const gpa = zcu.gpa;
    const ip = &zcu.intern_pool;

    // Our job is to correctly set the value of the `test_functions` declaration if it has been
    // analyzed and sent to codegen, It usually will have been, because the test runner will
    // reference it, and `std.builtin` shouldn't have type errors. However, if it hasn't been
    // analyzed, we will just terminate early, since clearly the test runner hasn't referenced
    // `test_functions` so there's no point populating it. More to the the point, we potentially
    // *can't* populate it without doing some type resolution, and... let's try to leave Sema in
    // the past here.

    const builtin_mod = zcu.builtin_modules.get(zcu.root_mod.getBuiltinOptions(zcu.comp.config).hash()).?;
    const builtin_file_index = zcu.module_roots.get(builtin_mod).?.unwrap().?;
    const builtin_root_type = zcu.fileRootType(builtin_file_index);
    if (builtin_root_type == .none) return; // `@import("builtin")` never analyzed
    const builtin_namespace = Type.fromInterned(builtin_root_type).getNamespace(zcu).unwrap().?;
    // We know that the namespace has a `test_functions`...
    const nav_index = zcu.namespacePtr(builtin_namespace).pub_decls.getKeyAdapted(
        try ip.getOrPutString(gpa, pt.tid, "test_functions", .no_embedded_nulls),
        Zcu.Namespace.NameAdapter{ .zcu = zcu },
    ).?;
    // ...but it might not be populated, so let's check that!
    if (zcu.failed_analysis.contains(.wrap(.{ .nav_val = nav_index })) or
        zcu.transitive_failed_analysis.contains(.wrap(.{ .nav_val = nav_index })) or
        ip.getNav(nav_index).status != .fully_resolved)
    {
        // The value of `builtin.test_functions` was either never referenced, or failed analysis.
        // Either way, we don't need to do anything.
        return;
    }

    // Okay, `builtin.test_functions` is (potentially) referenced and valid. Our job now is to swap
    // its placeholder `&.{}` value for the actual list of all test functions.

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
            test_fn_val.* = (try pt.aggregateValue(test_fn_ty, &test_fn_fields)).toIntern();
        }

        const array_ty = try pt.arrayType(.{
            .len = test_fn_vals.len,
            .child = test_fn_ty.toIntern(),
            .sentinel = .none,
        });
        break :array .{
            .orig_ty = (try pt.singleConstPtrType(array_ty)).toIntern(),
            .val = (try pt.aggregateValue(array_ty, test_fn_vals)).toIntern(),
        };
    };

    {
        const new_ty = try pt.ptrType(.{
            .child = test_fn_ty.toIntern(),
            .flags = .{
                .is_const = true,
                .size = .slice,
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
    // The linker thread is not running, so we actually need to dispatch this task directly.
    @import("../link.zig").linkTestFunctionsNav(pt, nav_index);
}

/// Stores an error in `pt.zcu.failed_files` for this file, and sets the file
/// status to `retryable_failure`.
pub fn reportRetryableFileError(
    pt: Zcu.PerThread,
    file_index: Zcu.File.Index,
    comptime format: []const u8,
    args: anytype,
) error{OutOfMemory}!void {
    const zcu = pt.zcu;
    const gpa = zcu.gpa;

    const file = zcu.fileByIndex(file_index);

    file.status = .retryable_failure;

    const msg = try std.fmt.allocPrint(gpa, format, args);
    errdefer gpa.free(msg);

    const old_msg: ?[]u8 = old_msg: {
        zcu.comp.mutex.lock();
        defer zcu.comp.mutex.unlock();

        const gop = try zcu.failed_files.getOrPut(gpa, file_index);
        const old: ?[]u8 = if (gop.found_existing) old: {
            break :old gop.value_ptr.*;
        } else null;
        gop.value_ptr.* = msg;

        break :old_msg old;
    };
    if (old_msg) |m| gpa.free(m);
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
                .linkage = e.linkage,
                .visibility = e.visibility,
                .is_dll_import = e.is_dll_import,
                .relocation = e.relocation,
                .alignment = e.alignment,
                .@"addrspace" = e.@"addrspace",
                .zir_index = e.zir_index,
                .owner_nav = undefined, // ignored by `getExtern`.
                .source = e.source,
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

    if (info.flags.size == .c) canon_info.flags.is_allowzero = true;

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
            .size = .many,
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

pub fn aggregateValue(pt: Zcu.PerThread, ty: Type, elems: []const InternPool.Index) Allocator.Error!Value {
    for (elems) |elem| {
        if (!Value.fromInterned(elem).isUndef(pt.zcu)) break;
    } else if (elems.len > 0) {
        return pt.undefValue(ty); // all-undef
    }
    return .fromInterned(try pt.intern(.{ .aggregate = .{
        .ty = ty.toIntern(),
        .storage = .{ .elems = elems },
    } }));
}

/// Asserts that `ty` is either an array or a vector.
pub fn aggregateSplatValue(pt: Zcu.PerThread, ty: Type, repeated_elem: Value) Allocator.Error!Value {
    switch (ty.zigTypeTag(pt.zcu)) {
        .array, .vector => {},
        else => unreachable,
    }
    if (repeated_elem.isUndef(pt.zcu)) return pt.undefValue(ty);
    return .fromInterned(try pt.intern(.{ .aggregate = .{
        .ty = ty.toIntern(),
        .storage = .{ .repeated_elem = repeated_elem.toIntern() },
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

/// `ty` is an integer or a vector of integers.
pub fn overflowArithmeticTupleType(pt: Zcu.PerThread, ty: Type) !Type {
    const zcu = pt.zcu;
    const ip = &zcu.intern_pool;
    const ov_ty: Type = if (ty.zigTypeTag(zcu) == .vector) try pt.vectorType(.{
        .len = ty.vectorLen(zcu),
        .child = .u1_type,
    }) else .u1;
    const tuple_ty = try ip.getTupleType(zcu.gpa, pt.tid, .{
        .types = &.{ ty.toIntern(), ov_ty.toIntern() },
        .values = &.{ .none, .none },
    });
    return .fromInterned(tuple_ty);
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

pub fn navPtrType(pt: Zcu.PerThread, nav_id: InternPool.Nav.Index) Allocator.Error!Type {
    const zcu = pt.zcu;
    const ip = &zcu.intern_pool;
    const ty, const alignment, const @"addrspace", const is_const = switch (ip.getNav(nav_id).status) {
        .unresolved => unreachable,
        .type_resolved => |r| .{ r.type, r.alignment, r.@"addrspace", r.is_const },
        .fully_resolved => |r| .{ ip.typeOf(r.val), r.alignment, r.@"addrspace", r.is_const },
    };
    return pt.ptrType(.{
        .child = ty,
        .flags = .{
            .alignment = if (alignment == Type.fromInterned(ty).abiAlignment(zcu))
                .none
            else
                alignment,
            .address_space = @"addrspace",
            .is_const = is_const,
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
        pt.zcu.comp.link_prog_node.increaseEstimatedTotalItems(1);
        try pt.zcu.comp.queueJob(.{ .link_nav = nav });
        if (pt.zcu.comp.debugIncremental()) try pt.zcu.incremental_debug_state.newNav(pt.zcu, nav);
    }
    return result.index;
}

// TODO: this shouldn't need a `PerThread`! Fix the signature of `Type.abiAlignment`.
pub fn navAlignment(pt: Zcu.PerThread, nav_index: InternPool.Nav.Index) InternPool.Alignment {
    const zcu = pt.zcu;
    const ty: Type, const alignment = switch (zcu.intern_pool.getNav(nav_index).status) {
        .unresolved => unreachable,
        .type_resolved => |r| .{ .fromInterned(r.type), r.alignment },
        .fully_resolved => |r| .{ Value.fromInterned(r.val).typeOf(zcu), r.alignment },
    };
    if (alignment != .none) return alignment;
    return ty.abiAlignment(zcu);
}

/// `ty` is a container type requiring resolution (struct, union, or enum).
/// If `ty` is outdated, it is recreated at a new `InternPool.Index`, which is returned.
/// If the type cannot be recreated because it has been lost, `error.AnalysisFail` is returned.
/// If `ty` is not outdated, that same `InternPool.Index` is returned.
/// If `ty` has already been replaced by this function, the new index will not be returned again.
/// Also, if `ty` is an enum, this function will resolve the new type if needed, and the call site
/// is responsible for checking `[transitive_]failed_analysis` to detect resolution failures.
pub fn ensureTypeUpToDate(pt: Zcu.PerThread, ty: InternPool.Index) Zcu.SemaError!InternPool.Index {
    const zcu = pt.zcu;
    const gpa = zcu.gpa;
    const ip = &zcu.intern_pool;

    const anal_unit: AnalUnit = .wrap(.{ .type = ty });
    const outdated = zcu.outdated.swapRemove(anal_unit) or
        zcu.potentially_outdated.swapRemove(anal_unit);

    if (outdated) {
        _ = zcu.outdated_ready.swapRemove(anal_unit);
        try zcu.markDependeeOutdated(.marked_po, .{ .interned = ty });
    }

    const ty_key = switch (ip.indexToKey(ty)) {
        .struct_type, .union_type, .enum_type => |key| key,
        else => unreachable,
    };
    const declared_ty_key = switch (ty_key) {
        .reified => unreachable, // never outdated
        .generated_tag => unreachable, // never outdated
        .declared => |d| d,
    };

    if (declared_ty_key.zir_index.resolve(ip) == null) {
        // The instruction has been lost -- this type is dead.
        return error.AnalysisFail;
    }

    if (!outdated) return ty;

    // We will recreate the type at a new `InternPool.Index`.

    // Delete old state which is no longer in use. Technically, this is not necessary: these exports,
    // references, etc, will be ignored because the type itself is unreferenced. However, it allows
    // reusing the memory which is currently being used to track this state.
    zcu.deleteUnitExports(anal_unit);
    zcu.deleteUnitReferences(anal_unit);
    zcu.deleteUnitCompileLogs(anal_unit);
    if (zcu.failed_analysis.fetchSwapRemove(anal_unit)) |kv| {
        kv.value.destroy(gpa);
    }
    _ = zcu.transitive_failed_analysis.swapRemove(anal_unit);
    zcu.intern_pool.removeDependenciesForDepender(gpa, anal_unit);

    if (zcu.comp.debugIncremental()) {
        const info = try zcu.incremental_debug_state.getUnitInfo(gpa, anal_unit);
        info.last_update_gen = zcu.generation;
        info.deps.clearRetainingCapacity();
    }

    switch (ip.indexToKey(ty)) {
        .struct_type => return pt.recreateStructType(ty, declared_ty_key),
        .union_type => return pt.recreateUnionType(ty, declared_ty_key),
        .enum_type => return pt.recreateEnumType(ty, declared_ty_key),
        else => unreachable,
    }
}

fn recreateStructType(
    pt: Zcu.PerThread,
    old_ty: InternPool.Index,
    key: InternPool.Key.NamespaceType.Declared,
) Allocator.Error!InternPool.Index {
    const zcu = pt.zcu;
    const gpa = zcu.gpa;
    const ip = &zcu.intern_pool;

    const inst_info = key.zir_index.resolveFull(ip).?;
    const file = zcu.fileByIndex(inst_info.file);
    const zir = file.zir.?;

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

    assert(captures_len == key.captures.owned.len); // synchronises with logic in `Zcu.mapOldZirToNew`

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

    wip_ty.setName(ip, struct_obj.name, struct_obj.name_nav);
    try pt.addDependency(.wrap(.{ .type = wip_ty.index }), .{ .src_hash = key.zir_index });
    zcu.namespacePtr(struct_obj.namespace).owner_type = wip_ty.index;
    // No need to re-scan the namespace -- `zirStructDecl` will ultimately do that if the type is still alive.
    try zcu.comp.queueJob(.{ .resolve_type_fully = wip_ty.index });

    codegen_type: {
        if (file.mod.?.strip) break :codegen_type;
        // This job depends on any resolve_type_fully jobs queued up before it.
        zcu.comp.link_prog_node.increaseEstimatedTotalItems(1);
        try zcu.comp.queueJob(.{ .link_type = wip_ty.index });
    }

    if (zcu.comp.debugIncremental()) try zcu.incremental_debug_state.newType(zcu, wip_ty.index);
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
    key: InternPool.Key.NamespaceType.Declared,
) Allocator.Error!InternPool.Index {
    const zcu = pt.zcu;
    const gpa = zcu.gpa;
    const ip = &zcu.intern_pool;

    const inst_info = key.zir_index.resolveFull(ip).?;
    const file = zcu.fileByIndex(inst_info.file);
    const zir = file.zir.?;

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

    assert(captures_len == key.captures.owned.len); // synchronises with logic in `Zcu.mapOldZirToNew`

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

    wip_ty.setName(ip, union_obj.name, union_obj.name_nav);
    try pt.addDependency(.wrap(.{ .type = wip_ty.index }), .{ .src_hash = key.zir_index });
    zcu.namespacePtr(namespace_index).owner_type = wip_ty.index;
    // No need to re-scan the namespace -- `zirUnionDecl` will ultimately do that if the type is still alive.
    try zcu.comp.queueJob(.{ .resolve_type_fully = wip_ty.index });

    codegen_type: {
        if (file.mod.?.strip) break :codegen_type;
        // This job depends on any resolve_type_fully jobs queued up before it.
        zcu.comp.link_prog_node.increaseEstimatedTotalItems(1);
        try zcu.comp.queueJob(.{ .link_type = wip_ty.index });
    }

    if (zcu.comp.debugIncremental()) try zcu.incremental_debug_state.newType(zcu, wip_ty.index);
    return wip_ty.finish(ip, namespace_index);
}

/// This *does* call `Sema.resolveDeclaredEnum`, but errors from it are not propagated.
/// Call sites are resposible for checking `[transitive_]failed_analysis` after `ensureTypeUpToDate`
/// returns in order to detect resolution failures.
fn recreateEnumType(
    pt: Zcu.PerThread,
    old_ty: InternPool.Index,
    key: InternPool.Key.NamespaceType.Declared,
) Allocator.Error!InternPool.Index {
    const zcu = pt.zcu;
    const gpa = zcu.gpa;
    const ip = &zcu.intern_pool;

    const inst_info = key.zir_index.resolveFull(ip).?;
    const file = zcu.fileByIndex(inst_info.file);
    const zir = file.zir.?;

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

    assert(captures_len == key.captures.owned.len); // synchronises with logic in `Zcu.mapOldZirToNew`

    extra_index += captures_len * 2;
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

    wip_ty.setName(ip, enum_obj.name, enum_obj.name_nav);

    zcu.namespacePtr(namespace_index).owner_type = wip_ty.index;
    // No need to re-scan the namespace -- `zirEnumDecl` will ultimately do that if the type is still alive.

    if (zcu.comp.debugIncremental()) try zcu.incremental_debug_state.newType(zcu, wip_ty.index);
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
        error.OutOfMemory => |e| return e,
        error.AnalysisFail => {}, // call sites are responsible for checking `[transitive_]failed_analysis` to detect this
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
    const zir = file.zir.?;

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
            extra_index += captures_len * 2;
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
            extra_index += captures_len * 2;
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
            extra_index += captures_len * 2;
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
            extra_index += captures_len * 2;
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

pub fn addDependency(pt: Zcu.PerThread, unit: AnalUnit, dependee: InternPool.Dependee) Allocator.Error!void {
    const zcu = pt.zcu;
    const gpa = zcu.gpa;
    try zcu.intern_pool.addDependency(gpa, unit, dependee);
    if (zcu.comp.debugIncremental()) {
        const info = try zcu.incremental_debug_state.getUnitInfo(gpa, unit);
        try info.deps.append(gpa, dependee);
    }
}

/// Performs code generation, which comes after `Sema` but before `link` in the pipeline.
/// This part of the pipeline is self-contained/"pure", so can be run in parallel with most
/// other code. This function is currently run either on the main thread, or on a separate
/// codegen thread, depending on whether the backend supports `Zcu.Feature.separate_thread`.
pub fn runCodegen(pt: Zcu.PerThread, func_index: InternPool.Index, air: *Air, out: *@import("../link.zig").ZcuTask.LinkFunc.SharedMir) void {
    const zcu = pt.zcu;

    var timer = zcu.comp.startTimer();

    const success: bool = if (runCodegenInner(pt, func_index, air)) |mir| success: {
        out.value = mir;
        break :success true;
    } else |err| success: {
        switch (err) {
            error.OutOfMemory => zcu.comp.setAllocFailure(),
            error.CodegenFail => zcu.assertCodegenFailed(zcu.funcInfo(func_index).owner_nav),
            error.NoLinkFile => assert(zcu.comp.bin_file == null),
            error.BackendDoesNotProduceMir => switch (target_util.zigBackend(
                &zcu.root_mod.resolved_target.result,
                zcu.comp.config.use_llvm,
            )) {
                else => unreachable, // assertion failure
                .stage2_spirv,
                .stage2_llvm,
                => {},
            },
        }
        break :success false;
    };

    if (timer.finish()) |ns_codegen| report_time: {
        const ip = &zcu.intern_pool;
        const nav = ip.indexToKey(func_index).func.owner_nav;
        const zir_decl = ip.getNav(nav).srcInst(ip);
        zcu.comp.mutex.lock();
        defer zcu.comp.mutex.unlock();
        const tr = &zcu.comp.time_report.?;
        tr.stats.cpu_ns_codegen += ns_codegen;
        const gop = tr.decl_codegen_ns.getOrPut(zcu.gpa, zir_decl) catch |err| switch (err) {
            error.OutOfMemory => {
                zcu.comp.setAllocFailure();
                break :report_time;
            },
        };
        if (!gop.found_existing) gop.value_ptr.* = 0;
        gop.value_ptr.* += ns_codegen;
    }

    // release `out.value` with this store; synchronizes with acquire loads in `link`
    out.status.store(if (success) .ready else .failed, .release);
    zcu.comp.link_task_queue.mirReady(zcu.comp, func_index, out);
    if (zcu.pending_codegen_jobs.rmw(.Sub, 1, .monotonic) == 1) {
        // Decremented to 0, so all done.
        zcu.codegen_prog_node.end();
        zcu.codegen_prog_node = .none;
    }
}
fn runCodegenInner(pt: Zcu.PerThread, func_index: InternPool.Index, air: *Air) error{
    OutOfMemory,
    CodegenFail,
    NoLinkFile,
    BackendDoesNotProduceMir,
}!codegen.AnyMir {
    const zcu = pt.zcu;
    const gpa = zcu.gpa;
    const ip = &zcu.intern_pool;
    const comp = zcu.comp;

    const nav = zcu.funcInfo(func_index).owner_nav;
    const fqn = ip.getNav(nav).fqn;

    const codegen_prog_node = zcu.codegen_prog_node.start(fqn.toSlice(ip), 0);
    defer codegen_prog_node.end();

    if (codegen.legalizeFeatures(pt, nav)) |features| {
        try air.legalize(pt, features);
    }

    var liveness: ?Air.Liveness = if (codegen.wantsLiveness(pt, nav))
        try .analyze(zcu, air.*, ip)
    else
        null;
    defer if (liveness) |*l| l.deinit(gpa);

    if (build_options.enable_debug_extensions and comp.verbose_air) {
        const stderr = std.debug.lockStderrWriter(&.{});
        defer std.debug.unlockStderrWriter();
        stderr.print("# Begin Function AIR: {f}:\n", .{fqn.fmt(ip)}) catch {};
        air.write(stderr, pt, liveness);
        stderr.print("# End Function AIR: {f}\n\n", .{fqn.fmt(ip)}) catch {};
    }

    if (std.debug.runtime_safety) verify_liveness: {
        var verify: Air.Liveness.Verify = .{
            .gpa = gpa,
            .zcu = zcu,
            .air = air.*,
            .liveness = liveness orelse break :verify_liveness,
            .intern_pool = ip,
        };
        defer verify.deinit();

        verify.verify() catch |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            else => return zcu.codegenFail(nav, "invalid liveness: {s}", .{@errorName(err)}),
        };
    }

    // The LLVM backend is special, because we only need to do codegen. There is no equivalent to the
    // "emit" step because LLVM does not support incremental linking. Our linker (LLD or self-hosted)
    // will just see the ZCU object file which LLVM ultimately emits.
    if (zcu.llvm_object) |llvm_object| {
        assert(pt.tid == .main); // LLVM has a lot of shared state
        try llvm_object.updateFunc(pt, func_index, air, &liveness);
        return error.BackendDoesNotProduceMir;
    }

    const lf = comp.bin_file orelse return error.NoLinkFile;

    // Just like LLVM, the SPIR-V backend can't multi-threaded due to SPIR-V design limitations.
    if (lf.cast(.spirv)) |spirv_file| {
        assert(pt.tid == .main); // SPIR-V has a lot of shared state
        spirv_file.updateFunc(pt, func_index, air, &liveness) catch |err| {
            switch (err) {
                error.OutOfMemory => comp.link_diags.setAllocFailure(),
            }
            return error.CodegenFail;
        };
        return error.BackendDoesNotProduceMir;
    }

    return codegen.generateFunction(lf, pt, zcu.navSrcLoc(nav), func_index, air, &liveness) catch |err| switch (err) {
        error.OutOfMemory,
        error.CodegenFail,
        => |e| return e,
        error.Overflow,
        error.RelocationNotByteAligned,
        => return zcu.codegenFail(nav, "unable to codegen: {s}", .{@errorName(err)}),
    };
}
