const expect = @import("std").testing.expect;

test "@satAdd, @satSub" {
    comptime testSaturating();
    testSaturating();
}

fn testSaturating() void {
    {
        var x: u16 = 0xfffe;
        expect(@satAdd(u16, x, 100) == 0xffff);
    }
    {
        var x: u32 = 0xfffffffa;
        expect(@satAdd(u32, x, 1677) == 0xffffffff);
    }
    {
        var x: u64 = 0x021;
        expect(@satSub(u64, x, 5000) == 0);
    }
    {
        var x: i8 = -50;
        expect(@satSub(i8, x, 127) == -128);
    }
    {
        const mem = @import("std").mem;
        var v: @Vector(4, i32) = [4]i32{ 2147483647, -2, 30, 40 };
        var x: @Vector(4, i32) = [4]i32{ 1, 2147483647, 3, 4 };
        expect(mem.eql(i32, ([4]i32)(@satSub(@typeOf(v), v, x)), [4]i32{ 2147483646, -2147483648, 27, 36 }));
    }
}

