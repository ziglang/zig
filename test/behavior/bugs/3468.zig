// zig fmt: off
test "pointer deref next to assignment" {
    var a:i32=2;
    var b=&a;
    b.*=3;
}
