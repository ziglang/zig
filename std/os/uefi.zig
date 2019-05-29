// TODO this is where the extern declarations go. For example, see
// inc/efilib.h in gnu-efi-code

const builtin = @import("builtin");

pub const is_the_target = builtin.os == .uefi;
