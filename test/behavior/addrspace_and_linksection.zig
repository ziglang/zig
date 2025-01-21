const builtin = @import("builtin");

/// Elements are const_linksection, var_linksection, fn_linksection
const linksections: ?[3][]const u8 = switch (builtin.target.ofmt) {
    .elf => .{ ".rodata", ".data", ".text" },
    .coff => .{ ".rdata", ".data", ".text" },
    .macho => .{ "__TEXT,__const", "__DATA,__data", "__TEXT,__text" },
    else => null,
};
const const_linksection = linksections.?[0];
const var_linksection = linksections.?[1];
const fn_linksection = linksections.?[2];

test "addrspace on container-level const" {
    const S = struct {
        const a: u32 addrspace(.generic) = 123;
        fn check(ptr: anytype) !void {
            if (ptr.* != 123) return error.TestFailed;
        }
    };
    try S.check(&S.a);
    try comptime S.check(&S.a);
}

test "linksection on container-level const" {
    if (linksections == null) return;
    const S = struct {
        const a: u32 linksection(const_linksection) = 123;
        fn check(ptr: anytype) !void {
            if (ptr.* != 123) return error.TestFailed;
        }
    };
    try S.check(&S.a);
    try comptime S.check(&S.a);
}

test "addrspace and linksection on container-level const" {
    if (linksections == null) return;
    const S = struct {
        const a: u32 addrspace(.generic) linksection(const_linksection) = 123;
        fn check(ptr: anytype) !void {
            if (ptr.* != 123) return error.TestFailed;
        }
    };
    try S.check(&S.a);
    try comptime S.check(&S.a);
}

test "addrspace on container-level var" {
    const S = struct {
        var a: u32 addrspace(.generic) = 123;
        fn check(ptr: anytype) !void {
            if (ptr.* != 123) return error.TestFailed;
        }
    };
    try S.check(&S.a);
}

test "linksection on container-level var" {
    if (linksections == null) return;
    const S = struct {
        var a: u32 linksection(var_linksection) = 123;
        fn check(ptr: anytype) !void {
            if (ptr.* != 123) return error.TestFailed;
        }
    };
    try S.check(&S.a);
}

test "addrspace and linksection on container-level var" {
    if (linksections == null) return;
    const S = struct {
        var a: u32 addrspace(.generic) linksection(var_linksection) = 123;
        fn check(ptr: anytype) !void {
            if (ptr.* != 123) return error.TestFailed;
        }
    };
    try S.check(&S.a);
}

test "addrspace on fn" {
    const S = struct {
        fn f() addrspace(.generic) u32 {
            return 123;
        }
        fn check(fnPtr: anytype) !void {
            if (fnPtr() != 123) return error.TestFailed;
        }
    };
    try S.check(&S.f);
    try comptime S.check(&S.f);
}

test "linksection on fn" {
    if (linksections == null) return;
    const S = struct {
        fn f() linksection(fn_linksection) u32 {
            return 123;
        }
        fn check(fnPtr: anytype) !void {
            if (fnPtr() != 123) return error.TestFailed;
        }
    };
    try S.check(&S.f);
    try comptime S.check(&S.f);
}

test "addrspace and linksection on fn" {
    if (linksections == null) return;
    const S = struct {
        fn f() addrspace(.generic) linksection(fn_linksection) u32 {
            return 123;
        }
        fn check(fnPtr: anytype) !void {
            if (fnPtr() != 123) return error.TestFailed;
        }
    };
    try S.check(&S.f);
    try comptime S.check(&S.f);
}
