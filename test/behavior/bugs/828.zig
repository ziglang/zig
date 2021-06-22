const CountBy = struct {
    a: usize,

    const One = CountBy{ .a = 1 };

    pub fn counter(self: *const CountBy) Counter {
        _ = self;
        return Counter{ .i = 0 };
    }
};

const Counter = struct {
    i: usize,

    pub fn count(self: *Counter) bool {
        self.i += 1;
        return self.i <= 10;
    }
};

fn constCount(comptime cb: *const CountBy, comptime unused: u32) void {
    _ = unused;
    comptime {
        var cnt = cb.counter();
        if (cnt.i != 0) @compileError("Counter instance reused!");
        while (cnt.count()) {}
    }
}

test "comptime struct return should not return the same instance" {
    //the first parameter must be passed by reference to trigger the bug
    //a second parameter is required to trigger the bug
    const ValA = constCount(&CountBy.One, 12);
    const ValB = constCount(&CountBy.One, 15);
    if (false) {
        ValA;
        ValB;
    }
}
