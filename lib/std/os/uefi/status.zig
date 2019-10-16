const high_bit = 1 << @typeInfo(usize).Int.bits - 1;

/// The operation completed successfully.
pub const success: usize = 0;

/// The image failed to load.
pub const load_error: usize = high_bit | 1;
/// A parameter was incorrect.
pub const invalid_parameter: usize = high_bit | 2;
/// The operation is not supported.
pub const unsupported: usize = high_bit | 3;
/// The buffer was not the proper size for the request.
pub const bad_buffer_size: usize = high_bit | 4;
/// The buffer is not large enough to hold the requested data. The required buffer size is returned in the appropriate parameter when this error occurs.
pub const buffer_too_small: usize = high_bit | 5;
/// There is no data pending upon return.
pub const not_ready: usize = high_bit | 6;
/// The physical device reported an error while attempting the operation.
pub const device_error: usize = high_bit | 7;
/// The device cannot be written to.
pub const write_protected: usize = high_bit | 8;
/// A resource has run out.
pub const out_of_resources: usize = high_bit | 9;
/// An inconstancy was detected on the file system causing the operating to fail.
pub const volume_corrupted: usize = high_bit | 10;
/// There is no more space on the file system.
pub const volume_full: usize = high_bit | 11;
/// The device does not contain any medium to perform the operation.
pub const no_media: usize = high_bit | 12;
/// The medium in the device has changed since the last access.
pub const media_changed: usize = high_bit | 13;
/// The item was not found.
pub const not_found: usize = high_bit | 14;
/// Access was denied.
pub const access_denied: usize = high_bit | 15;
/// The server was not found or did not respond to the request.
pub const no_response: usize = high_bit | 16;
/// A mapping to a device does not exist.
pub const no_mapping: usize = high_bit | 17;
/// The timeout time expired.
pub const timeout: usize = high_bit | 18;
/// The protocol has not been started.
pub const not_started: usize = high_bit | 19;
/// The protocol has already been started.
pub const already_started: usize = high_bit | 20;
/// The operation was aborted.
pub const aborted: usize = high_bit | 21;
/// An ICMP error occurred during the network operation.
pub const icmp_error: usize = high_bit | 22;
/// A TFTP error occurred during the network operation.
pub const tftp_error: usize = high_bit | 23;
/// A protocol error occurred during the network operation.
pub const protocol_error: usize = high_bit | 24;
/// The function encountered an internal version that was incompatible with a version requested by the caller.
pub const incompatible_version: usize = high_bit | 25;
/// The function was not performed due to a security violation.
pub const security_violation: usize = high_bit | 26;
/// A CRC error was detected.
pub const crc_error: usize = high_bit | 27;
/// Beginning or end of media was reached
pub const end_of_media: usize = high_bit | 28;
/// The end of the file was reached.
pub const end_of_file: usize = high_bit | 31;
/// The language specified was invalid.
pub const invalid_language: usize = high_bit | 32;
/// The security status of the data is unknown or compromised and the data must be updated or replaced to restore a valid security status.
pub const compromised_data: usize = high_bit | 33;
/// There is an address conflict address allocation
pub const ip_address_conflict: usize = high_bit | 34;
/// A HTTP error occurred during the network operation.
pub const http_error: usize = high_bit | 35;

/// The string contained one or more characters that the device could not render and were skipped.
pub const warn_unknown_glyph: usize = 1;
/// The handle was closed, but the file was not deleted.
pub const warn_delete_failure: usize = 2;
/// The handle was closed, but the data to the file was not flushed properly.
pub const warn_write_failure: usize = 3;
/// The resulting buffer was too small, and the data was truncated to the buffer size.
pub const warn_buffer_too_small: usize = 4;
/// The data has not been updated within the timeframe set by localpolicy for this type of data.
pub const warn_stale_data: usize = 5;
/// The resulting buffer contains UEFI-compliant file system.
pub const warn_file_system: usize = 6;
/// The operation will be processed across a system reset.
pub const warn_reset_required: usize = 7;
