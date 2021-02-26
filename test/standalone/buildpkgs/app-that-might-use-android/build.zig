const std = @import("std");
const Builder = std.build.Builder;
const buildpkgs = @import("buildpkgs");

pub fn build(b: *Builder) !void {
    if (b.option(bool, "android", "build for android") orelse false) {
        if (comptime buildpkgs.has("androidbuild")) {
            std.log.info("we have and need the 'androidbuild' package", .{});
            const androidbuild = @import("androidbuild");
            const options = androidbuild.getApkOptions(b);
            try androidbuild.makeApk(b, options);
        } else {
            std.log.err("missing package 'androidbuild'", .{});
            return error.MissingPackage;
        }
    } else {
        std.log.info("android not enabled, 'androidbuild' package not needed", .{});
    }
}
