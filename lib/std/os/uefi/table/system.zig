const bits = @import("../bits.zig");
const table = @import("../table.zig");
const protocol = @import("../protocol.zig");

/// The EFI System Table contains pointers to the runtime and boot services tables.
///
/// As the system_table may grow with new UEFI versions, it is important to check hdr.header_size.
pub const System = extern struct {
    hdr: table.Header,

    /// A null-terminated string that identifies the vendor that produces the system firmware of the platform.
    firmware_vendor: [*:0]u16,

    /// A vendor specific value that identifies the revision of the system firmware for the platform.
    firmware_revision: u32,

    /// The handle for the active console input device. The handle must support the `SimpleTextInput` and
    /// `SimpleTextInputEx` protocols, even if there is no active console.
    ///
    /// Only null after Boot Services have been exited.
    console_in_handle: ?bits.Handle,

    /// A pointer to the `SimpleTextInput` protocol interface that is associated with `console_in_handle`.
    ///
    /// Only null after Boot Services have been exited.
    con_in: ?*const protocol.SimpleTextInput,

    /// The handle for the active console output device. The handle must support the `SimpleTextOutput` protocol,
    /// even if there is no active console.
    ///
    /// Only null after Boot Services have been exited.
    console_out_handle: ?bits.Handle,

    /// A pointer to the `SimpleTextOutput` protocol interface that is associated with `console_out_handle`.
    ///
    /// Only null after Boot Services have been exited.
    con_out: ?*const protocol.SimpleTextOutput,

    /// The handle for the active console output device. The handle must support the `SimpleTextOutput` protocol,
    /// even if there is no active console.
    ///
    /// Only null after Boot Services have been exited.
    standard_error_handle: ?bits.Handle,

    /// A pointer to the `SimpleTextOutput` protocol interface that is associated with `standard_error_handle`.
    ///
    /// Only null after Boot Services have been exited.
    std_err: ?*const protocol.SimpleTextOutput,

    /// A pointer to the EFI Runtime Services Table.
    runtime_services: *const table.RuntimeServices,

    /// A pointer to the EFI Boot Services Table.
    ///
    /// Only null after Boot Services have been exited.
    boot_services: ?*const table.BootServices,

    /// The number of system configuration tables in the buffer configuration_table.
    number_of_table_entries: usize,

    /// A pointer to the system configuration tables.
    configuration_table: [*]table.Configuration,

    pub const signature: u64 = 0x5453595320494249;
};
