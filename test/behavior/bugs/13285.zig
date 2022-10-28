const Crasher = struct {
    lets_crash: u64 = 0,
};

test {
    var a: Crasher = undefined;
    var crasher_ptr = &a;
    var crasher_local = crasher_ptr.*;
    const crasher_local_ptr = &crasher_local;
    crasher_local_ptr.lets_crash = 1;
}
