const std = @import("std");
const Builder = std.build.Builder;

pub const Options = struct {
    fastcompress: bool,
};

pub fn getApkOptions(b: *Builder) Options {
    return .{
        .fastcompress = b.option(bool, "fastcompress", "enable fast compression") orelse false,
    };
}

pub fn makeApk(b: *Builder, options: Options) !void {
    // let's imagine android as an optional
    if (options.fastcompress) {
        if (comptime std.builtin.hasPkg("fastcompressor")) {
            const fastcompressor = @import("fastcompressor");
            fastcompressor.doTheThing();
        } else {
            std.log.err("-Dfastcompress requires the 'fastcompressor' package", .{});
            return error.MissingPackage;
        }
    }

    // ...code here to create an android apk...
}
