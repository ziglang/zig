extern "c" fn exit(u8) void;
export fn entry() void {
    exit(0);
}

// error
// target=native-linux
//
// :1:8: error: dependency on libc must be explicitly specified in the build command
