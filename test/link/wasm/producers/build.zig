const std = @import("std");
const builtin = @import("builtin");
const Builder = std.build.Builder;

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();

    const test_step = b.step("test", "Test");
    test_step.dependOn(b.getInstallStep());

    const lib = b.addSharedLibrary("lib", "lib.zig", .unversioned);
    lib.setBuildMode(mode);
    lib.setTarget(.{ .cpu_arch = .wasm32, .os_tag = .freestanding });
    lib.use_llvm = false;
    lib.use_stage1 = false;
    lib.use_lld = false;
    lib.strip = false;
    lib.install();

    const zig_version = builtin.zig_version;
    var version_buf: [100]u8 = undefined;
    const version_fmt = std.fmt.bufPrint(&version_buf, "version {}", .{zig_version}) catch unreachable;

    const check_lib = lib.checkObject(.wasm);
    check_lib.checkStart("name producers");
    check_lib.checkNext("fields 2");
    check_lib.checkNext("field_name language");
    check_lib.checkNext("values 1");
    check_lib.checkNext("value_name Zig");
    check_lib.checkNext(version_fmt);
    check_lib.checkNext("field_name processed-by");
    check_lib.checkNext("values 1");
    check_lib.checkNext("value_name Zig");
    check_lib.checkNext(version_fmt);

    test_step.dependOn(&check_lib.step);
}
