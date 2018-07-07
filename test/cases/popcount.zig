const assert = @import("std").debug.assert;

test "@popCount" {
    comptime testPopCount();
    testPopCount();
}

fn testPopCount() void {
    {
        var x: u32 = 0xaa;
        assert(@popCount(x) == 4);
    }
    {
        var x: u32 = 0xaaaaaaaa;
        assert(@popCount(x) == 16);
    }
    {
        var x: i16 = -1;
        assert(@popCount(x) == 16);
    }
    comptime {
        assert(@popCount(0b11111111000110001100010000100001000011000011100101010001) == 24);
    }
}
