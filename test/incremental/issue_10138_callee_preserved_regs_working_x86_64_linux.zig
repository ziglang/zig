pub fn main() void {
    const fd = open();
    _ = write(fd, "a", 1);
    _ = close(fd);
}

fn open() usize {
    return 42;
}

fn write(fd: usize, a: [*]const u8, len: usize) usize {
    return syscall4(.WRITE, fd, @ptrToInt(a), len);
}

fn syscall4(n: enum { WRITE }, a: usize, b: usize, c: usize) usize {
    _ = n;
    _ = a;
    _ = b;
    _ = c;
    return 23;
}

fn close(fd: usize) usize {
    if (fd != 42)
        unreachable;
    return 0;
}

// run
// target=x86_64-linux
//
