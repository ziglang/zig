extern "c" fn exit(u8) void;
export fn entry() void {
    exit(0);
}

// error
// backend=stage1
// target=native-linux
// is_test=1
//
// tmp.zig:3:5: error: dependency on libc must be explicitly specified in the build command
