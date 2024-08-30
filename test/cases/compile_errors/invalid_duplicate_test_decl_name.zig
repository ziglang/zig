test "thingy" {}
test "thingy" {}

// error
// backend=stage2
// target=native
// is_test=true
//
// :1:6: error: duplicate test name 'thingy'
// :2:6: note: duplicate test here
// :1:1: note: struct declared here
