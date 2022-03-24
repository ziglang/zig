const MenuEffect = enum {};
fn func(effect: MenuEffect) void { _ = effect; }
export fn entry() void {
    func(MenuEffect.ThisDoesNotExist);
}

// using invalid types in function call raises an error
//
// tmp.zig:1:20: error: enum declarations must have at least one tag
