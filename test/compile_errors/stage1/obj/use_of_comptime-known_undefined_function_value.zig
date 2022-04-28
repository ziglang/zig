const Cmd = struct {
    exec: fn () void,
};
export fn entry() void {
    const command = Cmd{ .exec = undefined };
    command.exec();
}

// error
// backend=stage1
// target=native
//
// tmp.zig:6:12: error: use of undefined value here causes undefined behavior
