const assertOrPanic = @import("std").debug.assertOrPanic;

test "@popCount" {
    comptime testPopCount();
    testPopCount();
}

fn testPopCount() void {
    {
        var x: u32 = 0xaa;
        assertOrPanic(@popCount(x) == 4);
    }
    {
        var x: u32 = 0xaaaaaaaa;
        assertOrPanic(@popCount(x) == 16);
    }
    {
        var x: i16 = -1;
        assertOrPanic(@popCount(x) == 16);
    }
    comptime {
        assertOrPanic(@popCount(0b11111111000110001100010000100001000011000011100101010001) == 24);
    }
}

