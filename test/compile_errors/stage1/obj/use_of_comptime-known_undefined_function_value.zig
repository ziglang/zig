const Cmd = struct {
    exec: fn () void,
};
export fn entry() void {
    const command = Cmd{ .exec = undefined };
    command.exec();
}

// use of comptime-known undefined function value
//
// tmp.zig:6:12: error: use of undefined value here causes undefined behavior
