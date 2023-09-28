// -*- C++ -*-
//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___ERRC
#define _LIBCPP___ERRC

/*
    system_error synopsis

namespace std
{

enum class errc
{
    address_family_not_supported,       // EAFNOSUPPORT
    address_in_use,                     // EADDRINUSE
    address_not_available,              // EADDRNOTAVAIL
    already_connected,                  // EISCONN
    argument_list_too_long,             // E2BIG
    argument_out_of_domain,             // EDOM
    bad_address,                        // EFAULT
    bad_file_descriptor,                // EBADF
    bad_message,                        // EBADMSG
    broken_pipe,                        // EPIPE
    connection_aborted,                 // ECONNABORTED
    connection_already_in_progress,     // EALREADY
    connection_refused,                 // ECONNREFUSED
    connection_reset,                   // ECONNRESET
    cross_device_link,                  // EXDEV
    destination_address_required,       // EDESTADDRREQ
    device_or_resource_busy,            // EBUSY
    directory_not_empty,                // ENOTEMPTY
    executable_format_error,            // ENOEXEC
    file_exists,                        // EEXIST
    file_too_large,                     // EFBIG
    filename_too_long,                  // ENAMETOOLONG
    function_not_supported,             // ENOSYS
    host_unreachable,                   // EHOSTUNREACH
    identifier_removed,                 // EIDRM
    illegal_byte_sequence,              // EILSEQ
    inappropriate_io_control_operation, // ENOTTY
    interrupted,                        // EINTR
    invalid_argument,                   // EINVAL
    invalid_seek,                       // ESPIPE
    io_error,                           // EIO
    is_a_directory,                     // EISDIR
    message_size,                       // EMSGSIZE
    network_down,                       // ENETDOWN
    network_reset,                      // ENETRESET
    network_unreachable,                // ENETUNREACH
    no_buffer_space,                    // ENOBUFS
    no_child_process,                   // ECHILD
    no_link,                            // ENOLINK
    no_lock_available,                  // ENOLCK
    no_message_available,               // ENODATA
    no_message,                         // ENOMSG
    no_protocol_option,                 // ENOPROTOOPT
    no_space_on_device,                 // ENOSPC
    no_stream_resources,                // ENOSR
    no_such_device_or_address,          // ENXIO
    no_such_device,                     // ENODEV
    no_such_file_or_directory,          // ENOENT
    no_such_process,                    // ESRCH
    not_a_directory,                    // ENOTDIR
    not_a_socket,                       // ENOTSOCK
    not_a_stream,                       // ENOSTR
    not_connected,                      // ENOTCONN
    not_enough_memory,                  // ENOMEM
    not_supported,                      // ENOTSUP
    operation_canceled,                 // ECANCELED
    operation_in_progress,              // EINPROGRESS
    operation_not_permitted,            // EPERM
    operation_not_supported,            // EOPNOTSUPP
    operation_would_block,              // EWOULDBLOCK
    owner_dead,                         // EOWNERDEAD
    permission_denied,                  // EACCES
    protocol_error,                     // EPROTO
    protocol_not_supported,             // EPROTONOSUPPORT
    read_only_file_system,              // EROFS
    resource_deadlock_would_occur,      // EDEADLK
    resource_unavailable_try_again,     // EAGAIN
    result_out_of_range,                // ERANGE
    state_not_recoverable,              // ENOTRECOVERABLE
    stream_timeout,                     // ETIME
    text_file_busy,                     // ETXTBSY
    timed_out,                          // ETIMEDOUT
    too_many_files_open_in_system,      // ENFILE
    too_many_files_open,                // EMFILE
    too_many_links,                     // EMLINK
    too_many_symbolic_link_levels,      // ELOOP
    value_too_large,                    // EOVERFLOW
    wrong_protocol_type                 // EPROTOTYPE
};

*/

#include <__config>
#include <cerrno>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

// Some error codes are not present on all platforms, so we provide equivalents
// for them:

//enum class errc
_LIBCPP_DECLARE_STRONG_ENUM(errc)
{
    address_family_not_supported        = EAFNOSUPPORT,
    address_in_use                      = EADDRINUSE,
    address_not_available               = EADDRNOTAVAIL,
    already_connected                   = EISCONN,
    argument_list_too_long              = E2BIG,
    argument_out_of_domain              = EDOM,
    bad_address                         = EFAULT,
    bad_file_descriptor                 = EBADF,
    bad_message                         = EBADMSG,
    broken_pipe                         = EPIPE,
    connection_aborted                  = ECONNABORTED,
    connection_already_in_progress      = EALREADY,
    connection_refused                  = ECONNREFUSED,
    connection_reset                    = ECONNRESET,
    cross_device_link                   = EXDEV,
    destination_address_required        = EDESTADDRREQ,
    device_or_resource_busy             = EBUSY,
    directory_not_empty                 = ENOTEMPTY,
    executable_format_error             = ENOEXEC,
    file_exists                         = EEXIST,
    file_too_large                      = EFBIG,
    filename_too_long                   = ENAMETOOLONG,
    function_not_supported              = ENOSYS,
    host_unreachable                    = EHOSTUNREACH,
    identifier_removed                  = EIDRM,
    illegal_byte_sequence               = EILSEQ,
    inappropriate_io_control_operation  = ENOTTY,
    interrupted                         = EINTR,
    invalid_argument                    = EINVAL,
    invalid_seek                        = ESPIPE,
    io_error                            = EIO,
    is_a_directory                      = EISDIR,
    message_size                        = EMSGSIZE,
    network_down                        = ENETDOWN,
    network_reset                       = ENETRESET,
    network_unreachable                 = ENETUNREACH,
    no_buffer_space                     = ENOBUFS,
    no_child_process                    = ECHILD,
    no_link                             = ENOLINK,
    no_lock_available                   = ENOLCK,
#ifdef ENODATA
    no_message_available                = ENODATA,
#else
    no_message_available                = ENOMSG,
#endif
    no_message                          = ENOMSG,
    no_protocol_option                  = ENOPROTOOPT,
    no_space_on_device                  = ENOSPC,
#ifdef ENOSR
    no_stream_resources                 = ENOSR,
#else
    no_stream_resources                 = ENOMEM,
#endif
    no_such_device_or_address           = ENXIO,
    no_such_device                      = ENODEV,
    no_such_file_or_directory           = ENOENT,
    no_such_process                     = ESRCH,
    not_a_directory                     = ENOTDIR,
    not_a_socket                        = ENOTSOCK,
#ifdef ENOSTR
    not_a_stream                        = ENOSTR,
#else
    not_a_stream                        = EINVAL,
#endif
    not_connected                       = ENOTCONN,
    not_enough_memory                   = ENOMEM,
    not_supported                       = ENOTSUP,
    operation_canceled                  = ECANCELED,
    operation_in_progress               = EINPROGRESS,
    operation_not_permitted             = EPERM,
    operation_not_supported             = EOPNOTSUPP,
    operation_would_block               = EWOULDBLOCK,
    owner_dead                          = EOWNERDEAD,
    permission_denied                   = EACCES,
    protocol_error                      = EPROTO,
    protocol_not_supported              = EPROTONOSUPPORT,
    read_only_file_system               = EROFS,
    resource_deadlock_would_occur       = EDEADLK,
    resource_unavailable_try_again      = EAGAIN,
    result_out_of_range                 = ERANGE,
    state_not_recoverable               = ENOTRECOVERABLE,
#ifdef ETIME
    stream_timeout                      = ETIME,
#else
    stream_timeout                      = ETIMEDOUT,
#endif
    text_file_busy                      = ETXTBSY,
    timed_out                           = ETIMEDOUT,
    too_many_files_open_in_system       = ENFILE,
    too_many_files_open                 = EMFILE,
    too_many_links                      = EMLINK,
    too_many_symbolic_link_levels       = ELOOP,
    value_too_large                     = EOVERFLOW,
    wrong_protocol_type                 = EPROTOTYPE
};
_LIBCPP_DECLARE_STRONG_ENUM_EPILOG(errc)

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___ERRC
