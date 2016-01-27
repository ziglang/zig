const SYS_read      = 0;
const SYS_write     = 1;
const SYS_mmap      = 9;
const SYS_munmap    = 11;
const SYS_exit      = 60;
const SYS_getrandom = 318;

// mmap constants
pub const MMAP_PROT_NONE =  0;
pub const MMAP_PROT_READ =  1;
pub const MMAP_PROT_WRITE = 2;
pub const MMAP_PROT_EXEC =  4;

pub const MMAP_MAP_FILE =    0;
pub const MMAP_MAP_SHARED =  1;
pub const MMAP_MAP_PRIVATE = 2;
pub const MMAP_MAP_FIXED =   16;
pub const MMAP_MAP_ANON =    32;

fn syscall1(number: isize, arg1: isize) -> isize {
    asm volatile ("syscall"
        : [ret] "={rax}" (-> isize)
        : [number] "{rax}" (number), [arg1] "{rdi}" (arg1)
        : "rcx", "r11")
}

fn syscall3(number: isize, arg1: isize, arg2: isize, arg3: isize) -> isize {
    asm volatile ("syscall"
        : [ret] "={rax}" (-> isize)
        : [number] "{rax}" (number), [arg1] "{rdi}" (arg1), [arg2] "{rsi}" (arg2), [arg3] "{rdx}" (arg3)
        : "rcx", "r11")
}

fn syscall2(number: isize, arg1: isize, arg2: isize) -> isize {
    asm volatile ("syscall"
        : [ret] "={rax}" (-> isize)
        : [number] "{rax}" (number), [arg1] "{rdi}" (arg1), [arg2] "{rsi}" (arg2)
        : "rcx", "r11")
}

fn syscall6(number: isize, arg1: isize, arg2: isize, arg3: isize, arg4: isize, arg5: isize, arg6: isize) -> isize {
    asm volatile ("syscall"
        : [ret] "={rax}" (-> isize)
        : [number] "{rax}" (number), [arg1] "{rdi}" (arg1), [arg2] "{rsi}" (arg2), [arg3] "{rdx}" (arg3), [arg4] "{r10}" (arg4), [arg5] "{r8}" (arg5), [arg6] "{r9}" (arg6)
        : "rcx", "r11")
}

pub fn mmap(address: isize, length: isize, prot: isize, flags: isize, fd: isize, offset: isize) -> isize {
    syscall6(SYS_mmap, address, length, prot, flags, fd, offset)
}

pub fn munmap(address: isize, length: isize) -> isize {
    syscall2(SYS_munmap, address, length)
}

pub fn read(fd: isize, buf: &u8, count: isize) -> isize {
    syscall3(SYS_read, isize(fd), isize(buf), count)
}

pub fn write(fd: isize, buf: &const u8, count: isize) -> isize {
    syscall3(SYS_write, isize(fd), isize(buf), count)
}

pub fn exit(status: i32) -> unreachable {
    syscall1(SYS_exit, isize(status));
    unreachable{}
}

pub fn getrandom(buf: &u8, count: isize, flags: u32) -> isize {
    syscall3(SYS_getrandom, isize(buf), count, isize(flags))
}
