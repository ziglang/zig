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
}

