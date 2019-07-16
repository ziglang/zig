const expect = @import("std").testing.expect;

test "vector access elements - load" {
    {
        var a: @Vector(4, i32) = [_]i32{ 1, 2, 3, undefined };
        expect(a[2] == 3);
        expect(a[1] == i32(2));
        expect(3 == a[2]);
    }

    comptime {
        comptime var a: @Vector(4, i32) = [_]i32{ 1, 2, 3, undefined };
        expect(a[0] == 1);
        expect(a[1] == i32(2));
        expect(3 == a[2]);
    }
}


test "vector access elements - store" {
    {
        var a: @Vector(4, i32) = [_]i32{ 1, 5, 3, undefined };
        a[2] = 1;
        expect(a[1] == 5);
        expect(a[2] == i32(1));
        a[3] = -364;
        expect(-364 == a[3]);
    }

    comptime {
        comptime var a: @Vector(4, i32) = [_]i32{ 1, 2, 3, undefined };
        a[2] = 5;
        expect(a[2] == i32(5));
        a[3] = -364;
        expect(-364 == a[3]);
    }
}
