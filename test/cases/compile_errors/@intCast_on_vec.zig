export fn entry() void {
    const a = @Vector(4, u32){ 1, 1, 1, 1 };
    _ = @as(u32, @intCast(a));
}

// TODO: change target in the manifest to "native" probably after this is fixed:
//       https://github.com/ziglang/zig/issues/13782

// error
// backend=stage2
// target=x86_64-linux
//
// :3:27: error: expected type 'u32', found '@Vector(4, u32)'
