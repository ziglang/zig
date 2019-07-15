/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#ifndef SAL_HXX
#define SAL_HXX

#ifdef __GNUC__
#  define __inner_checkReturn __attribute__((warn_unused_result))
#elif defined(_MSC_VER)
#  define __inner_checkReturn __declspec("SAL_checkReturn")
#else
#  define __inner_checkReturn
#endif

#define __checkReturn __inner_checkReturn

/* Pointer parameters */
#define _In_
#define _Out_
#define _Inout_
#define _In_z_
#define _Inout_z_
#define _In_reads_(s)
#define _In_reads_bytes_(s)
#define _In_reads_z_(s)
#define _In_reads_or_z_(s)
#define _Out_writes_(s)
#define _Out_writes_bytes_(s)
#define _Out_writes_z_(s)
#define _Inout_updates_(s)
#define _Inout_updates_bytes_(s)
#define _Inout_updates_z_(s)
#define _Out_writes_to_(s,c)
#define _Out_writes_bytes_to_(s, c)
#define _Out_writes_all_(s)
#define _Out_writes_bytes_all_(s)
#define _Inout_updates_to_(s, c)
#define _Inout_updates_bytes_to_(s, c)
#define _Inout_updates_all_(s)
#define _Inout_updates_bytes_all_(s)
#define _In_reads_to_ptr_(p)
#define _In_reads_to_ptr_z_(p)
#define _Out_writes_to_ptr_(p)
#define _Out_writes_to_ptr_z(p)

/* Optional pointer parameters */
#define __in_opt
#define __out_opt
#define __inout_opt
#define _In_opt_
#define _Out_opt_
#define _Inout_opt_
#define _In_opt_z_
#define _Inout_opt_z_
#define _In_reads_opt_(s)
#define _In_reads_bytes_opt_(s)
#define _In_reads_opt_z_(s)

#define _Out_writes_opt_(s)
#define _Out_writes_opt_z_(s)
#define _Inout_updates_opt_(s)
#define _Inout_updates_bytes_opt_(s)
#define _Inout_updates_opt_z_(s)
#define _Out_writes_to_opt_(s, c)
#define _Out_writes_bytes_to_opt_(s, c)
#define _Out_writes_all_opt_(s)
#define _Out_writes_bytes_all_opt_(s)

#define _Inout_updates_to_opt_(s, c)
#define _Inout_updates_bytes_to_opt_(s, c)
#define _Inout_updates_all_opt_(s)
#define _Inout_updates_bytes_all_opt_(s)
#define _In_reads_to_ptr_opt_(p)
#define _In_reads_to_ptr_opt_z_(p)
#define _Out_writes_to_ptr_opt_(p)
#define _Out_writes_to_ptr_opt_z_(p)

/* Output pointer parameters */
#define _Outptr_
#define _Outptr_opt_
#define _Outptr_result_maybenull_
#define _Outptr_opt_result_maybenull_
#define _Outptr_result_z_
#define _Outptr_opt_result_z_
#define _Outptr_result_maybenull_z_
#define _Outptr_opt_result_maybenull_z_
#define _COM_Outptr_
#define _COM_Outptr_opt_
#define _COM_Outptr_result_maybenull_
#define _COM_Outptr_opt_result_maybenull_
#define _Outptr_result_buffer_(s)
#define _Outptr_result_bytebuffer_(s)
#define _Outptr_opt_result_buffer_(s)
#define _Outptr_opt_result_bytebuffer_(s)
#define _Outptr_result_buffer_to_(s, c)
#define _Outptr_result_bytebuffer_to_(s, c)
#define _Outptr_result_bytebuffer_maybenull_(s)
#define _Outptr_opt_result_buffer_to_(s, c)
#define _Outptr_opt_result_bytebuffer_to_(s, c)
#define _Result_nullonfailure_
#define _Result_zeroonfailure_
#define _Outptr_result_nullonfailure_
#define _Outptr_opt_result_nullonfailure_
#define _Outref_result_nullonfailure_

/* Output reference parameters */
#define _Outref_
#define _Outref_result_maybenull_
#define _Outref_result_buffer_(s)
#define _Outref_result_bytebuffer_(s)
#define _Outref_result_buffer_to_(s, c)
#define _Outref_result_bytebuffer_to_(s, c)
#define _Outref_result_buffer_all_(s)
#define _Outref_result_bytebuffer_all_(s)
#define _Outref_result_buffer_maybenull_(s)
#define _Outref_result_bytebuffer_maybenull_(s)
#define _Outref_result_buffer_to_maybenull_(s, c)
#define _Outref_result_bytebuffer_to_maybenull_(s, c)
#define _Outref_result_buffer_all_maybenull_(s)
#define _Outref_result_bytebuffer_all_maybenull_(s)

/* Return values */
#define _Ret_z_
#define _Ret_writes_(s)
#define _Ret_writes_bytes_(s)
#define _Ret_writes_z_(s)
#define _Ret_writes_bytes_to_(s, c)
#define _Ret_writes_maybenull_(s)
#define _Ret_writes_to_maybenull_(s, c)
#define _Ret_writes_maybenull_z_(s)
#define _Ret_maybenull_
#define _Ret_maybenull_z_
#define _Ret_null_
#define _Ret_notnull_
#define _Ret_writes_bytes_to_(s, c)
#define _Ret_writes_bytes_maybenull_(s)
#define _Ret_writes_bytes_to_maybenull_(s, c)

/* Other common annotations */
#define _In_range_(low, hi)
#define _Out_range_(low, hi)
#define _Ret_range_(low, hi)
#define _Deref_in_range_(low, hi)
#define _Deref_out_range_(low, hi)
#define _Deref_inout_range_(low, hi)
#define _Pre_equal_to_(expr)
#define _Post_equal_to_(expr)
#define _Struct_size_bytes_(size)

/* Function annotations */
#define _Called_from_function_class_(name)
#define _Check_return_ __checkReturn
#define _Function_class_(name)
#define _Raises_SEH_exception_
#define _Maybe_raises_SEH_exception_
#define _Must_inspect_result_
#define _Use_decl_annotations_

/* Success/failure annotations */
#define _Always_(anno_list)
#define _On_failure_(anno_list)
#define _Return_type_success_(expr)
#define _Success_(expr)

#define _Reserved_
#define _Const_

/* Buffer properties */
#define _Readable_bytes_(s)
#define _Readable_elements_(s)
#define _Writable_bytes_(s)
#define _Writable_elements_(s)
#define _Null_terminated_
#define _NullNull_terminated_
#define _Pre_readable_size_(s)
#define _Pre_writable_size_(s)
#define _Pre_readable_byte_size_(s)
#define _Pre_writable_byte_size_(s)
#define _Post_readable_size_(s)
#define _Post_writable_size_(s)
#define _Post_readable_byte_size_(s)
#define _Post_writable_byte_size_(s)

/* Field properties */
#define _Field_size_(s)
#define _Field_size_full_(s)
#define _Field_size_full_opt_(s)
#define _Field_size_opt_(s)
#define _Field_size_part_(s, c)
#define _Field_size_part_opt_(s, c)
#define _Field_size_bytes_(size)
#define _Field_size_bytes_full_(size)
#define _Field_size_bytes_full_opt_(s)
#define _Field_size_bytes_opt_(s)
#define _Field_size_bytes_part_(s, c)
#define _Field_size_bytes_part_opt_(s, c)
#define _Field_z_
#define _Field_range_(min, max)

/* Structural annotations */
#define _At_(e, a)
#define _At_buffer_(e, i, c, a)
#define _Group_(a)
#define _When_(e, a)

/* printf/scanf annotations */
#define _Printf_format_string_
#define _Scanf_format_string_
#define _Scanf_s_format_string_
#define _Format_string_impl_(kind,where)
#define _Printf_format_string_params_(x)
#define _Scanf_format_string_params_(x)
#define _Scanf_s_format_string_params_(x)

/* Analysis */
#define _Analysis_assume_(expr)
#define _Analysis_assume_nullterminated_(expr)

/* FIXME: __in macro conflicts with argument names in libstdc++. For this reason,
 * we disable it for C++. This should be fixed in libstdc++ so we can uncomment
 * it in fixed version here. */
#if !defined(__cplusplus) || !defined(__GNUC__)
#define __in
#define __out
#endif

#define __in_bcount(size)
#define __in_ecount(size)

#define __out_bcount(size)
#define __out_bcount_part(size, length)
#define __out_ecount(size)

#define __inout

#define __deref_out_ecount(size)

#endif

