export fn a() void {
    if (false) {
        lol_this_doesnt_exist = nonsense;
    }
}

// undeclared identifier in unanalyzed branch
//
// tmp.zig:3:9: error: use of undeclared identifier 'lol_this_doesnt_exist'
