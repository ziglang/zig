const std = @import("std");
const Builder = std.build.Builder;

pub fn build(b: *Builder) void {
    const test_step = b.step("test", "Test");
    test_step.dependOn(b.getInstallStep());

    const lib = b.addSharedLibrary("lib", "lib.zig", .unversioned);
    lib.setBuildMode(.ReleaseSafe); // to make the output deterministic in address positions
    lib.setTarget(.{ .cpu_arch = .wasm32, .os_tag = .freestanding });
    lib.use_lld = false;
    lib.export_symbol_names = &.{ "foo", "bar" };
    lib.global_base = 0; // put data section at address 0 to make data symbols easier to parse

    const check_lib = lib.checkObject(.wasm);

    check_lib.checkStart("Section global");
    check_lib.checkNext("entries 3");
    check_lib.checkNext("type i32"); // stack pointer so skip other fields
    check_lib.checkNext("type i32");
    check_lib.checkNext("mutable false");
    check_lib.checkNext("i32.const {foo_address}");
    check_lib.checkNext("type i32");
    check_lib.checkNext("mutable false");
    check_lib.checkNext("i32.const {bar_address}");
    check_lib.checkComputeCompare("foo_address", .{ .op = .eq, .value = .{ .literal = 0 } });
    check_lib.checkComputeCompare("bar_address", .{ .op = .eq, .value = .{ .literal = 4 } });

    check_lib.checkStart("Section export");
    check_lib.checkNext("entries 3");
    check_lib.checkNext("name foo");
    check_lib.checkNext("kind global");
    check_lib.checkNext("index 1");
    check_lib.checkNext("name bar");
    check_lib.checkNext("kind global");
    check_lib.checkNext("index 2");

    test_step.dependOn(&check_lib.step);
}
