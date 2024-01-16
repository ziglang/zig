const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) void {
    const step = b.step("test", "Run standalone test cases");
    b.default_step = step;

    const enable_ios_sdk = b.option(bool, "enable-ios-sdk", "Run tests requiring presence of iOS SDK and frameworks") orelse false;
    const enable_macos_sdk = b.option(bool, "enable-macos-sdk", "Run tests requiring presence of macOS SDK and frameworks") orelse enable_ios_sdk;
    const enable_symlinks_windows = b.option(bool, "enable-symlinks-windows", "Run tests requiring presence of symlinks on Windows") orelse false;

    const omit_symlinks = builtin.os.tag == .windows and !enable_symlinks_windows;

    add_dep_steps: for (b.available_deps) |available_dep| {
        const dep_name, const dep_hash = available_dep;

        const all_pkgs = @import("root").dependencies.packages;
        inline for (@typeInfo(all_pkgs).Struct.decls) |decl| {
            const pkg_hash = decl.name;
            if (std.mem.eql(u8, dep_hash, pkg_hash)) {
                const pkg = @field(all_pkgs, pkg_hash);
                if (!@hasDecl(pkg, "build_zig")) {
                    std.debug.print("standalone test case '{s}' is missing a 'build.zig' file\n", .{dep_name});
                    std.process.exit(1);
                }
                const requires_ios_sdk = @hasDecl(pkg.build_zig, "requires_ios_sdk") and
                    pkg.build_zig.requires_ios_sdk;
                const requires_macos_sdk = @hasDecl(pkg.build_zig, "requires_macos_sdk") and
                    pkg.build_zig.requires_macos_sdk;
                const requires_symlinks = @hasDecl(pkg.build_zig, "requires_symlinks") and
                    pkg.build_zig.requires_symlinks;
                if ((requires_symlinks and omit_symlinks) or
                    (requires_macos_sdk and !enable_macos_sdk) or
                    (requires_ios_sdk and !enable_ios_sdk))
                {
                    continue :add_dep_steps;
                }
                break;
            }
        } else unreachable;

        const dep = b.dependency(dep_name, .{});
        const dep_step = dep.builder.default_step;
        dep_step.name = b.fmt("standalone_test_cases.{s}", .{dep_name});
        step.dependOn(dep_step);
    }
}
