//! WriteFileStep is primarily used to create a directory in an appropriate
//! location inside the local cache which has a set of files that have either
//! been generated during the build, or are copied from the source package.
//!
//! However, this step has an additional capability of writing data to paths
//! relative to the package root, effectively mutating the package's source
//! files. Be careful with the latter functionality; it should not be used
//! during the normal build process, but as a utility run by a developer with
//! intention to update source files, which will then be committed to version
//! control.

step: Step,
builder: *std.Build,
/// The elements here are pointers because we need stable pointers for the
/// GeneratedFile field.
files: std.ArrayListUnmanaged(*File),
output_source_files: std.ArrayListUnmanaged(OutputSourceFile),

pub const base_id = .write_file;

pub const File = struct {
    generated_file: std.Build.GeneratedFile,
    sub_path: []const u8,
    contents: Contents,
};

pub const OutputSourceFile = struct {
    contents: Contents,
    sub_path: []const u8,
};

pub const Contents = union(enum) {
    bytes: []const u8,
    copy: std.Build.FileSource,
};

pub fn init(builder: *std.Build) WriteFileStep {
    return .{
        .builder = builder,
        .step = Step.init(.write_file, "writefile", builder.allocator, make),
        .files = .{},
        .output_source_files = .{},
    };
}

pub fn add(wf: *WriteFileStep, sub_path: []const u8, bytes: []const u8) void {
    const gpa = wf.builder.allocator;
    const file = gpa.create(File) catch @panic("OOM");
    file.* = .{
        .generated_file = .{ .step = &wf.step },
        .sub_path = wf.builder.dupePath(sub_path),
        .contents = .{ .bytes = wf.builder.dupe(bytes) },
    };
    wf.files.append(gpa, file) catch @panic("OOM");
}

/// Place the file into the generated directory within the local cache,
/// along with all the rest of the files added to this step. The parameter
/// here is the destination path relative to the local cache directory
/// associated with this WriteFileStep. It may be a basename, or it may
/// include sub-directories, in which case this step will ensure the
/// required sub-path exists.
/// This is the option expected to be used most commonly with `addCopyFile`.
pub fn addCopyFile(wf: *WriteFileStep, source: std.Build.FileSource, sub_path: []const u8) void {
    const gpa = wf.builder.allocator;
    const file = gpa.create(File) catch @panic("OOM");
    file.* = .{
        .generated_file = .{ .step = &wf.step },
        .sub_path = wf.builder.dupePath(sub_path),
        .contents = .{ .copy = source },
    };
    wf.files.append(gpa, file) catch @panic("OOM");
}

/// A path relative to the package root.
/// Be careful with this because it updates source files. This should not be
/// used as part of the normal build process, but as a utility occasionally
/// run by a developer with intent to modify source files and then commit
/// those changes to version control.
/// A file added this way is not available with `getFileSource`.
pub fn addCopyFileToSource(wf: *WriteFileStep, source: std.Build.FileSource, sub_path: []const u8) void {
    wf.output_source_files.append(wf.builder.allocator, .{
        .contents = .{ .copy = source },
        .sub_path = sub_path,
    }) catch @panic("OOM");
}

/// Gets a file source for the given sub_path. If the file does not exist, returns `null`.
pub fn getFileSource(wf: *WriteFileStep, sub_path: []const u8) ?std.Build.FileSource {
    for (wf.files.items) |file| {
        if (std.mem.eql(u8, file.sub_path, sub_path)) {
            return .{ .generated = &file.generated_file };
        }
    }
    return null;
}

fn make(step: *Step) !void {
    const wf = @fieldParentPtr(WriteFileStep, "step", step);

    // Writing to source files is kind of an extra capability of this
    // WriteFileStep - arguably it should be a different step. But anyway here
    // it is, it happens unconditionally and does not interact with the other
    // files here.
    for (wf.output_source_files.items) |output_source_file| {
        const basename = fs.path.basename(output_source_file.sub_path);
        if (fs.path.dirname(output_source_file.sub_path)) |dirname| {
            var dir = try wf.builder.build_root.handle.makeOpenPath(dirname, .{});
            defer dir.close();
            try writeFile(wf, dir, output_source_file.contents, basename);
        } else {
            try writeFile(wf, wf.builder.build_root.handle, output_source_file.contents, basename);
        }
    }

    // The cache is used here not really as a way to speed things up - because writing
    // the data to a file would probably be very fast - but as a way to find a canonical
    // location to put build artifacts.

    // If, for example, a hard-coded path was used as the location to put WriteFileStep
    // files, then two WriteFileSteps executing in parallel might clobber each other.

    var man = wf.builder.cache.obtain();
    defer man.deinit();

    // Random bytes to make WriteFileStep unique. Refresh this with
    // new random bytes when WriteFileStep implementation is modified
    // in a non-backwards-compatible way.
    man.hash.add(@as(u32, 0xd767ee59));

    for (wf.files.items) |file| {
        man.hash.addBytes(file.sub_path);
        switch (file.contents) {
            .bytes => |bytes| {
                man.hash.addBytes(bytes);
            },
            .copy => |file_source| {
                _ = try man.addFile(file_source.getPath(wf.builder), null);
            },
        }
    }

    if (man.hit() catch |err| failWithCacheError(man, err)) {
        // Cache hit, skip writing file data.
        const digest = man.final();
        for (wf.files.items) |file| {
            file.generated_file.path = try wf.builder.cache_root.join(
                wf.builder.allocator,
                &.{ "o", &digest, file.sub_path },
            );
        }
        return;
    }

    const digest = man.final();
    const cache_path = "o" ++ fs.path.sep_str ++ digest;

    var cache_dir = wf.builder.cache_root.handle.makeOpenPath(cache_path, .{}) catch |err| {
        std.debug.print("unable to make path {s}: {s}\n", .{ cache_path, @errorName(err) });
        return err;
    };
    defer cache_dir.close();

    for (wf.files.items) |file| {
        const basename = fs.path.basename(file.sub_path);
        if (fs.path.dirname(file.sub_path)) |dirname| {
            var dir = try wf.builder.cache_root.handle.makeOpenPath(dirname, .{});
            defer dir.close();
            try writeFile(wf, dir, file.contents, basename);
        } else {
            try writeFile(wf, cache_dir, file.contents, basename);
        }

        file.generated_file.path = try wf.builder.cache_root.join(
            wf.builder.allocator,
            &.{ cache_path, file.sub_path },
        );
    }

    try man.writeManifest();
}

fn writeFile(wf: *WriteFileStep, dir: fs.Dir, contents: Contents, basename: []const u8) !void {
    // TODO after landing concurrency PR, improve error reporting here
    switch (contents) {
        .bytes => |bytes| return dir.writeFile(basename, bytes),
        .copy => |file_source| {
            const source_path = file_source.getPath(wf.builder);
            const prev_status = try fs.Dir.updateFile(fs.cwd(), source_path, dir, basename, .{});
            _ = prev_status; // TODO logging (affected by open PR regarding concurrency)
        },
    }
}

/// TODO consolidate this with the same function in RunStep?
/// Also properly deal with concurrency (see open PR)
fn failWithCacheError(man: std.Build.Cache.Manifest, err: anyerror) noreturn {
    const i = man.failed_file_index orelse failWithSimpleError(err);
    const pp = man.files.items[i].prefixed_path orelse failWithSimpleError(err);
    const prefix = man.cache.prefixes()[pp.prefix].path orelse "";
    std.debug.print("{s}: {s}/{s}\n", .{ @errorName(err), prefix, pp.sub_path });
    std.process.exit(1);
}

fn failWithSimpleError(err: anyerror) noreturn {
    std.debug.print("{s}\n", .{@errorName(err)});
    std.process.exit(1);
}

const std = @import("../std.zig");
const Step = std.Build.Step;
const fs = std.fs;
const ArrayList = std.ArrayList;

const WriteFileStep = @This();
