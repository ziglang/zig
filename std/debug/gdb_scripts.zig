const builtin = @import("builtin");

pub const is_enabled = builtin.object_format == .elf and !builtin.strip_debug_info;

pub fn load_python_script(comptime unique_qualified_name: []const u8, comptime program_text: []const u8) void {
    if (!is_enabled) return;

    const symbol_name = "__debug_script_" ++ unique_qualified_name;
    const SECTION_SCRIPT_ID_PYTHON_TEXT = "\x04";
    const section_content = SECTION_SCRIPT_ID_PYTHON_TEXT ++ unique_qualified_name ++ ".py\n" ++ program_text ++ "\x00";
    _ = struct {
        extern const storage linksection(".debug_gdb_scripts") = section_content;
        comptime {
            @export(symbol_name, storage, .Strong);
        }
    };
}

comptime {
    if (is_enabled) {
        // Stop the linker from garbage collecting the unused debug info.
        asm (
            \\.pushsection ".debug_gdb_scripts", "MS",@progbits,1
            \\.popsection
        );
    }
}
