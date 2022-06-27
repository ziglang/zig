export fn a() void {
    if (false) {
        lol_this_doesnt_exist = nonsense;
    }
}

// error
// backend=stage2
// target=native
//
// :3:9: error: use of undeclared identifier 'lol_this_doesnt_exist'
