const std = @import("std");
const Builder = std.build.Builder;
const buildpkgs = @import("buildpkgs");

pub const Options = struct {
    fastcompress: bool,
};

pub fn getApkOptions(b: *Builder) Options {
    return .{
        .fastcompress = b.option(bool, "fastcompress", "enable fast compression") orelse false,
    };
}

pub fn makeApk(b: *Builder, options: Options) !void {
    // android has its own optional dependency
    if (options.fastcompress) {
        if (comptime buildpkgs.has("fastcompressor")) {
            const fastcompressor = @import("fastcompressor");
            std.log.info("we have and need the 'fastcompressor' package", .{});
            fastcompressor.doTheThing();
        } else {
            std.log.err("-Dfastcompress requires the 'fastcompressor' package", .{});
            return error.MissingPackage;
        }
    }

    // ...code here to create an android apk...
}
