test "deprecated code path" {
    compute(.greedy, false, 42);
}

const Strategy = enum { greedy, expensive, fast };
fn compute(comptime strat: Strategy, comptime foo: bool, bar: usize) void {
    switch (strat) {
        .greedy => {
            // This combination turned out to be ineffective.
            if (!foo) @deprecated(); // use fast strategy when foo is false
            runGreedy(foo, bar);
        },
        .expensive => runExpensive(foo, bar),
        .fast => runFast(foo, bar),
    }
}

extern fn runGreedy(foo: bool, bar: usize) void;
extern fn runExpensive(foo: bool, bar: usize) void;
extern fn runFast(foo: bool, bar: usize) void;

// test_error=deprecated
