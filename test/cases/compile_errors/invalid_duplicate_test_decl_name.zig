test "thingy" {}
test "thingy" {}

// error
// backend=stage2
// target=native
// is_test=1
//
// :1:6: error: found test declaration with duplicate name: test.thingy
// :2:6: note: other test here
