const expect = @import("std").testing.expect;

test "@popCount" {
    comptime testPopCount();
    testPopCount();
}

fn testPopCount() void {
    {
        var x: u32 = 0xaa;
        expect(@popCount(x) == 4);
    }
    {
        var x: u32 = 0xaaaaaaaa;
        expect(@popCount(x) == 16);
    }
    {
        var x: i16 = -1;
        expect(@popCount(x) == 16);
    }
    comptime {
        expect(@popCount(0b11111111000110001100010000100001000011000011100101010001) == 24);
    }
}

