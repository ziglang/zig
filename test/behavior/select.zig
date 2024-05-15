const std = @import("std");
const builtin = @import("builtin");
const mem = std.mem;
const expect = std.testing.expect;

test "@select vectors" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    try comptime selectVectors();
    try selectVectors();
}

fn selectVectors() !void {
    var a = @Vector(4, bool){ true, false, true, false };
    var b = @Vector(4, i32){ -1, 4, 999, -31 };
    var c = @Vector(4, i32){ -5, 1, 0, 1234 };
    _ = .{ &a, &b, &c };
    const abc = @select(i32, a, b, c);
    try expect(abc[0] == -1);
    try expect(abc[1] == 1);
    try expect(abc[2] == 999);
    try expect(abc[3] == 1234);

    var x = @Vector(4, bool){ false, false, false, true };
    var y = @Vector(4, f32){ 0.001, 33.4, 836, -3381.233 };
    var z = @Vector(4, f32){ 0.0, 312.1, -145.9, 9993.55 };
    _ = .{ &x, &y, &z };
    const xyz = @select(f32, x, y, z);
    try expect(mem.eql(f32, &@as([4]f32, xyz), &[4]f32{ 0.0, 312.1, -145.9, -3381.233 }));
}

test "@select arrays" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64 and
        !comptime std.Target.x86.featureSetHas(builtin.cpu.features, .avx2)) return error.SkipZigTest;

    try comptime selectArrays();
    try selectArrays();
}

fn selectArrays() !void {
    var a = [4]bool{ false, true, false, true };
    var b = [4]usize{ 0, 1, 2, 3 };
    var c = [4]usize{ 4, 5, 6, 7 };
    _ = .{ &a, &b, &c };
    const abc = @select(usize, a, b, c);
    try expect(abc[0] == 4);
    try expect(abc[1] == 1);
    try expect(abc[2] == 6);
    try expect(abc[3] == 3);

    var x = [4]bool{ false, false, false, true };
    var y = [4]f32{ 0.001, 33.4, 836, -3381.233 };
    var z = [4]f32{ 0.0, 312.1, -145.9, 9993.55 };
    _ = .{ &x, &y, &z };
    const xyz = @select(f32, x, y, z);
    try expect(mem.eql(f32, &@as([4]f32, xyz), &[4]f32{ 0.0, 312.1, -145.9, -3381.233 }));
}
