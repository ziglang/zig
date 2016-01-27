import "syscall.zig";
import "std.zig";

pub fn malloc(bytes: isize) -> ?&u8 {
    if (bytes > 4096) {
        %%stderr.printf("TODO alloc sizes > 4096B\n");
        return null;
    }

    const result = mmap(0, 4096, MMAP_PROT_READ|MMAP_PROT_WRITE, MMAP_MAP_ANON|MMAP_MAP_SHARED, -1, 0);

    if (result == -1) {
        return null;
    }

    (&u8)(result)
}

pub fn free(ptr: &u8) {
    munmap(isize(ptr), 4096);
}
