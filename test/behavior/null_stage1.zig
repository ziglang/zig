const expect = @import("std").testing.expect;

test "if var maybe pointer" {
    try expect(shouldBeAPlus1(Particle{
        .a = 14,
        .b = 1,
        .c = 1,
        .d = 1,
    }) == 15);
}
fn shouldBeAPlus1(p: Particle) u64 {
    var maybe_particle: ?Particle = p;
    if (maybe_particle) |*particle| {
        particle.a += 1;
    }
    if (maybe_particle) |particle| {
        return particle.a;
    }
    return 0;
}
const Particle = struct {
    a: u64,
    b: u64,
    c: u64,
    d: u64,
};

test "optional types" {
    comptime {
        const opt_type_struct = StructWithOptionalType{ .t = u8 };
        try expect(opt_type_struct.t != null and opt_type_struct.t.? == u8);
    }
}

const StructWithOptionalType = struct {
    t: ?type,
};
