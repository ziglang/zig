#ifndef	_mach_port_user_
#define	_mach_port_user_

/* Module mach_port */

#include <string.h>
#include <mach/ndr.h>
#include <mach/boolean.h>
#include <mach/kern_return.h>
#include <mach/notify.h>
#include <mach/mach_types.h>
#include <mach/message.h>
#include <mach/mig_errors.h>
#include <mach/port.h>
	
/* BEGIN MIG_STRNCPY_ZEROFILL CODE */

#if defined(__has_include)
#if __has_include(<mach/mig_strncpy_zerofill_support.h>)
#ifndef USING_MIG_STRNCPY_ZEROFILL
#define USING_MIG_STRNCPY_ZEROFILL
#endif
#ifndef __MIG_STRNCPY_ZEROFILL_FORWARD_TYPE_DECLS__
#define __MIG_STRNCPY_ZEROFILL_FORWARD_TYPE_DECLS__
#ifdef __cplusplus
extern "C" {
#endif
#ifndef __MIG_STRNCPY_ZEROFILL_FORWARD_TYPE_DECLS_CSTRING_ATTR
#define __MIG_STRNCPY_ZEROFILL_FORWARD_TYPE_DECLS_CSTRING_COUNTEDBY_ATTR(C) __unsafe_indexable
#endif
	extern int mig_strncpy_zerofill(char * dest, const char * src, int len) __attribute__((weak_import));
#ifdef __cplusplus
}
#endif
#endif /* __MIG_STRNCPY_ZEROFILL_FORWARD_TYPE_DECLS__ */
#endif /* __has_include(<mach/mig_strncpy_zerofill_support.h>) */
#endif /* __has_include */
	
/* END MIG_STRNCPY_ZEROFILL CODE */


#ifdef AUTOTEST
#ifndef FUNCTION_PTR_T
#define FUNCTION_PTR_T
typedef void (*function_ptr_t)(mach_port_t, char *, mach_msg_type_number_t);
typedef struct {
        char            * name;
        function_ptr_t  function;
} function_table_entry;
typedef function_table_entry   *function_table_t;
#endif /* FUNCTION_PTR_T */
#endif /* AUTOTEST */

#ifndef	mach_port_MSG_COUNT
#define	mach_port_MSG_COUNT	43
#endif	/* mach_port_MSG_COUNT */

#include <Availability.h>
#include <mach/std_types.h>
#include <mach/mig.h>
#include <mach/mig.h>
#include <mach/mach_types.h>
#include <mach_debug/mach_debug_types.h>

#ifdef __BeforeMigUserHeader
__BeforeMigUserHeader
#endif /* __BeforeMigUserHeader */

#include <sys/cdefs.h>
__BEGIN_DECLS


/* Routine mach_port_names */
#ifdef	mig_external
mig_external
#else
extern
#endif	/* mig_external */
kern_return_t mach_port_names
(
	ipc_space_t task,
	mach_port_name_array_t *names,
	mach_msg_type_number_t *namesCnt,
	mach_port_type_array_t *types,
	mach_msg_type_number_t *typesCnt
);

/* Routine mach_port_type */
#ifdef	mig_external
mig_external
#else
extern
#endif	/* mig_external */
kern_return_t mach_port_type
(
	ipc_space_t task,
	mach_port_name_t name,
	mach_port_type_t *ptype
);

/* Routine mach_port_rename */
#ifdef	mig_external
mig_external
#else
extern
#endif	/* mig_external */
kern_return_t mach_port_rename
(
	ipc_space_t task,
	mach_port_name_t old_name,
	mach_port_name_t new_name
);

/* Routine mach_port_allocate_name */
#ifdef	mig_external
mig_external
#else
extern
#endif	/* mig_external */
__TVOS_PROHIBITED __WATCHOS_PROHIBITED
kern_return_t mach_port_allocate_name
(
	ipc_space_t task,
	mach_port_right_t right,
	mach_port_name_t name
);

/* Routine mach_port_allocate */
#ifdef	mig_external
mig_external
#else
extern
#endif	/* mig_external */
kern_return_t mach_port_allocate
(
	ipc_space_t task,
	mach_port_right_t right,
	mach_port_name_t *name
);

/* Routine mach_port_destroy */
#ifdef	mig_external
mig_external
#else
extern
#endif	/* mig_external */
__API_DEPRECATED("Inherently unsafe API: instead manage rights with "
    "mach_port_destruct(), mach_port_deallocate() or mach_port_mod_refs()",
    macos(10.0, 12.0), ios(2.0, 15.0), tvos(9.0, 15.0), watchos(2.0, 8.0))
kern_return_t mach_port_destroy
(
	ipc_space_t task,
	mach_port_name_t name
);

/* Routine mach_port_deallocate */
#ifdef	mig_external
mig_external
#else
extern
#endif	/* mig_external */
kern_return_t mach_port_deallocate
(
	ipc_space_t task,
	mach_port_name_t name
);

/* Routine mach_port_get_refs */
#ifdef	mig_external
mig_external
#else
extern
#endif	/* mig_external */
kern_return_t mach_port_get_refs
(
	ipc_space_t task,
	mach_port_name_t name,
	mach_port_right_t right,
	mach_port_urefs_t *refs
);

/* Routine mach_port_mod_refs */
#ifdef	mig_external
mig_external
#else
extern
#endif	/* mig_external */
kern_return_t mach_port_mod_refs
(
	ipc_space_t task,
	mach_port_name_t name,
	mach_port_right_t right,
	mach_port_delta_t delta
);

/* Routine mach_port_peek */
#ifdef	mig_external
mig_external
#else
extern
#endif	/* mig_external */
kern_return_t mach_port_peek
(
	ipc_space_t task,
	mach_port_name_t name,
	mach_msg_trailer_type_t trailer_type,
	mach_port_seqno_t *request_seqnop,
	mach_msg_size_t *msg_sizep,
	mach_msg_id_t *msg_idp,
	mach_msg_trailer_info_t trailer_infop,
	mach_msg_type_number_t *trailer_infopCnt
);

/* Routine mach_port_set_mscount */
#ifdef	mig_external
mig_external
#else
extern
#endif	/* mig_external */
kern_return_t mach_port_set_mscount
(
	ipc_space_t task,
	mach_port_name_t name,
	mach_port_mscount_t mscount
);

/* Routine mach_port_get_set_status */
#ifdef	mig_external
mig_external
#else
extern
#endif	/* mig_external */
kern_return_t mach_port_get_set_status
(
	ipc_space_read_t task,
	mach_port_name_t name,
	mach_port_name_array_t *members,
	mach_msg_type_number_t *membersCnt
);

/* Routine mach_port_move_member */
#ifdef	mig_external
mig_external
#else
extern
#endif	/* mig_external */
kern_return_t mach_port_move_member
(
	ipc_space_t task,
	mach_port_name_t member,
	mach_port_name_t after
);

/* Routine mach_port_request_notification */
#ifdef	mig_external
mig_external
#else
extern
#endif	/* mig_external */
kern_return_t mach_port_request_notification
(
	ipc_space_t task,
	mach_port_name_t name,
	mach_msg_id_t msgid,
	mach_port_mscount_t sync,
	mach_port_t notify,
	mach_msg_type_name_t notifyPoly,
	mach_port_t *previous
);

/* Routine mach_port_insert_right */
#ifdef	mig_external
mig_external
#else
extern
#endif	/* mig_external */
kern_return_t mach_port_insert_right
(
	ipc_space_t task,
	mach_port_name_t name,
	mach_port_t poly,
	mach_msg_type_name_t polyPoly
);

/* Routine mach_port_extract_right */
#ifdef	mig_external
mig_external
#else
extern
#endif	/* mig_external */
kern_return_t mach_port_extract_right
(
	ipc_space_t task,
	mach_port_name_t name,
	mach_msg_type_name_t msgt_name,
	mach_port_t *poly,
	mach_msg_type_name_t *polyPoly
);

/* Routine mach_port_set_seqno */
#ifdef	mig_external
mig_external
#else
extern
#endif	/* mig_external */
kern_return_t mach_port_set_seqno
(
	ipc_space_t task,
	mach_port_name_t name,
	mach_port_seqno_t seqno
);

/* Routine mach_port_get_attributes */
#ifdef	mig_external
mig_external
#else
extern
#endif	/* mig_external */
kern_return_t mach_port_get_attributes
(
	ipc_space_read_t task,
	mach_port_name_t name,
	mach_port_flavor_t flavor,
	mach_port_info_t port_info_out,
	mach_msg_type_number_t *port_info_outCnt
);

/* Routine mach_port_set_attributes */
#ifdef	mig_external
mig_external
#else
extern
#endif	/* mig_external */
kern_return_t mach_port_set_attributes
(
	ipc_space_t task,
	mach_port_name_t name,
	mach_port_flavor_t flavor,
	mach_port_info_t port_info,
	mach_msg_type_number_t port_infoCnt
);

/* Routine mach_port_allocate_qos */
#ifdef	mig_external
mig_external
#else
extern
#endif	/* mig_external */
kern_return_t mach_port_allocate_qos
(
	ipc_space_t task,
	mach_port_right_t right,
	mach_port_qos_t *qos,
	mach_port_name_t *name
);

/* Routine mach_port_allocate_full */
#ifdef	mig_external
mig_external
#else
extern
#endif	/* mig_external */
kern_return_t mach_port_allocate_full
(
	ipc_space_t task,
	mach_port_right_t right,
	mach_port_t proto,
	mach_port_qos_t *qos,
	mach_port_name_t *name
);

/* Routine task_set_port_space */
#ifdef	mig_external
mig_external
#else
extern
#endif	/* mig_external */
__TVOS_PROHIBITED __WATCHOS_PROHIBITED
kern_return_t task_set_port_space
(
	ipc_space_t task,
	int table_entries
);

/* Routine mach_port_get_srights */
#ifdef	mig_external
mig_external
#else
extern
#endif	/* mig_external */
kern_return_t mach_port_get_srights
(
	ipc_space_t task,
	mach_port_name_t name,
	mach_port_rights_t *srights
);

/* Routine mach_port_space_info */
#ifdef	mig_external
mig_external
#else
extern
#endif	/* mig_external */
kern_return_t mach_port_space_info
(
	ipc_space_read_t space,
	ipc_info_space_t *space_info,
	ipc_info_name_array_t *table_info,
	mach_msg_type_number_t *table_infoCnt,
	ipc_info_tree_name_array_t *tree_info,
	mach_msg_type_number_t *tree_infoCnt
);

/* Routine mach_port_dnrequest_info */
#ifdef	mig_external
mig_external
#else
extern
#endif	/* mig_external */
kern_return_t mach_port_dnrequest_info
(
	ipc_space_t task,
	mach_port_name_t name,
	unsigned *dnr_total,
	unsigned *dnr_used
);

/* Routine mach_port_kernel_object */
#ifdef	mig_external
mig_external
#else
extern
#endif	/* mig_external */
kern_return_t mach_port_kernel_object
(
	ipc_space_read_t task,
	mach_port_name_t name,
	unsigned *object_type,
	unsigned *object_addr
);

/* Routine mach_port_insert_member */
#ifdef	mig_external
mig_external
#else
extern
#endif	/* mig_external */
kern_return_t mach_port_insert_member
(
	ipc_space_t task,
	mach_port_name_t name,
	mach_port_name_t pset
);

/* Routine mach_port_extract_member */
#ifdef	mig_external
mig_external
#else
extern
#endif	/* mig_external */
kern_return_t mach_port_extract_member
(
	ipc_space_t task,
	mach_port_name_t name,
	mach_port_name_t pset
);

/* Routine mach_port_get_context */
#ifdef	mig_external
mig_external
#else
extern
#endif	/* mig_external */
kern_return_t mach_port_get_context
(
	ipc_space_read_t task,
	mach_port_name_t name,
	mach_port_context_t *context
);

/* Routine mach_port_set_context */
#ifdef	mig_external
mig_external
#else
extern
#endif	/* mig_external */
kern_return_t mach_port_set_context
(
	ipc_space_t task,
	mach_port_name_t name,
	mach_port_context_t context
);

/* Routine mach_port_kobject */
#ifdef	mig_external
mig_external
#else
extern
#endif	/* mig_external */
kern_return_t mach_port_kobject
(
	ipc_space_read_t task,
	mach_port_name_t name,
	natural_t *object_type,
	mach_vm_address_t *object_addr
);

/* Routine mach_port_construct */
#ifdef	mig_external
mig_external
#else
extern
#endif	/* mig_external */
kern_return_t mach_port_construct
(
	ipc_space_t task,
	mach_port_options_ptr_t options,
	mach_port_context_t context,
	mach_port_name_t *name
);

/* Routine mach_port_destruct */
#ifdef	mig_external
mig_external
#else
extern
#endif	/* mig_external */
kern_return_t mach_port_destruct
(
	ipc_space_t task,
	mach_port_name_t name,
	mach_port_delta_t srdelta,
	mach_port_context_t guard
);

/* Routine mach_port_guard */
#ifdef	mig_external
mig_external
#else
extern
#endif	/* mig_external */
kern_return_t mach_port_guard
(
	ipc_space_t task,
	mach_port_name_t name,
	mach_port_context_t guard,
	boolean_t strict
);

/* Routine mach_port_unguard */
#ifdef	mig_external
mig_external
#else
extern
#endif	/* mig_external */
kern_return_t mach_port_unguard
(
	ipc_space_t task,
	mach_port_name_t name,
	mach_port_context_t guard
);

/* Routine mach_port_space_basic_info */
#ifdef	mig_external
mig_external
#else
extern
#endif	/* mig_external */
kern_return_t mach_port_space_basic_info
(
	ipc_space_inspect_t task,
	ipc_info_space_basic_t *basic_info
);

/* Routine mach_port_guard_with_flags */
#ifdef	mig_external
mig_external
#else
extern
#endif	/* mig_external */
kern_return_t mach_port_guard_with_flags
(
	ipc_space_t task,
	mach_port_name_t name,
	mach_port_context_t guard,
	uint64_t flags
);

/* Routine mach_port_swap_guard */
#ifdef	mig_external
mig_external
#else
extern
#endif	/* mig_external */
kern_return_t mach_port_swap_guard
(
	ipc_space_t task,
	mach_port_name_t name,
	mach_port_context_t old_guard,
	mach_port_context_t new_guard
);

/* Routine mach_port_kobject_description */
#ifdef	mig_external
mig_external
#else
extern
#endif	/* mig_external */
kern_return_t mach_port_kobject_description
(
	ipc_space_read_t task,
	mach_port_name_t name,
	natural_t *object_type,
	mach_vm_address_t *object_addr,
	kobject_description_t description
);

/* Routine mach_port_is_connection_for_service */
#ifdef	mig_external
mig_external
#else
extern
#endif	/* mig_external */
kern_return_t mach_port_is_connection_for_service
(
	ipc_space_t task,
	mach_port_name_t connection_port,
	mach_port_name_t service_port,
	uint64_t *filter_policy_id
);

/* Routine mach_port_get_service_port_info */
#ifdef	mig_external
mig_external
#else
extern
#endif	/* mig_external */
kern_return_t mach_port_get_service_port_info
(
	ipc_space_read_t task,
	mach_port_name_t name,
	mach_service_port_info_data_t *sp_info_out
);

/* Routine mach_port_assert_attributes */
#ifdef	mig_external
mig_external
#else
extern
#endif	/* mig_external */
kern_return_t mach_port_assert_attributes
(
	ipc_space_t task,
	mach_port_name_t name,
	mach_port_flavor_t flavor,
	mach_port_info_t info,
	mach_msg_type_number_t infoCnt
);

__END_DECLS

/********************** Caution **************************/
/* The following data types should be used to calculate  */
/* maximum message sizes only. The actual message may be */
/* smaller, and the position of the arguments within the */
/* message layout may vary from what is presented here.  */
/* For example, if any of the arguments are variable-    */
/* sized, and less than the maximum is sent, the data    */
/* will be packed tight in the actual message to reduce  */
/* the presence of holes.                                */
/********************** Caution **************************/

/* typedefs for all requests */

#ifndef __Request__mach_port_subsystem__defined
#define __Request__mach_port_subsystem__defined

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
	} __Request__mach_port_names_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
		NDR_record_t NDR;
		mach_port_name_t name;
	} __Request__mach_port_type_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
		NDR_record_t NDR;
		mach_port_name_t old_name;
		mach_port_name_t new_name;
	} __Request__mach_port_rename_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
		NDR_record_t NDR;
		mach_port_right_t right;
		mach_port_name_t name;
	} __Request__mach_port_allocate_name_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
		NDR_record_t NDR;
		mach_port_right_t right;
	} __Request__mach_port_allocate_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
		NDR_record_t NDR;
		mach_port_name_t name;
	} __Request__mach_port_destroy_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
		NDR_record_t NDR;
		mach_port_name_t name;
	} __Request__mach_port_deallocate_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
		NDR_record_t NDR;
		mach_port_name_t name;
		mach_port_right_t right;
	} __Request__mach_port_get_refs_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
		NDR_record_t NDR;
		mach_port_name_t name;
		mach_port_right_t right;
		mach_port_delta_t delta;
	} __Request__mach_port_mod_refs_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
		NDR_record_t NDR;
		mach_port_name_t name;
		mach_msg_trailer_type_t trailer_type;
		mach_port_seqno_t request_seqnop;
		mach_msg_type_number_t trailer_infopCnt;
	} __Request__mach_port_peek_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
		NDR_record_t NDR;
		mach_port_name_t name;
		mach_port_mscount_t mscount;
	} __Request__mach_port_set_mscount_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
		NDR_record_t NDR;
		mach_port_name_t name;
	} __Request__mach_port_get_set_status_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
		NDR_record_t NDR;
		mach_port_name_t member;
		mach_port_name_t after;
	} __Request__mach_port_move_member_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
		/* start of the kernel processed data */
		mach_msg_body_t msgh_body;
		mach_msg_port_descriptor_t notify;
		/* end of the kernel processed data */
		NDR_record_t NDR;
		mach_port_name_t name;
		mach_msg_id_t msgid;
		mach_port_mscount_t sync;
	} __Request__mach_port_request_notification_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
		/* start of the kernel processed data */
		mach_msg_body_t msgh_body;
		mach_msg_port_descriptor_t poly;
		/* end of the kernel processed data */
		NDR_record_t NDR;
		mach_port_name_t name;
	} __Request__mach_port_insert_right_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
		NDR_record_t NDR;
		mach_port_name_t name;
		mach_msg_type_name_t msgt_name;
	} __Request__mach_port_extract_right_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
		NDR_record_t NDR;
		mach_port_name_t name;
		mach_port_seqno_t seqno;
	} __Request__mach_port_set_seqno_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
		NDR_record_t NDR;
		mach_port_name_t name;
		mach_port_flavor_t flavor;
		mach_msg_type_number_t port_info_outCnt;
	} __Request__mach_port_get_attributes_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
		NDR_record_t NDR;
		mach_port_name_t name;
		mach_port_flavor_t flavor;
		mach_msg_type_number_t port_infoCnt;
		integer_t port_info[17];
	} __Request__mach_port_set_attributes_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
		NDR_record_t NDR;
		mach_port_right_t right;
		mach_port_qos_t qos;
	} __Request__mach_port_allocate_qos_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
		/* start of the kernel processed data */
		mach_msg_body_t msgh_body;
		mach_msg_port_descriptor_t proto;
		/* end of the kernel processed data */
		NDR_record_t NDR;
		mach_port_right_t right;
		mach_port_qos_t qos;
		mach_port_name_t name;
	} __Request__mach_port_allocate_full_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
		NDR_record_t NDR;
		int table_entries;
	} __Request__task_set_port_space_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
		NDR_record_t NDR;
		mach_port_name_t name;
	} __Request__mach_port_get_srights_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
	} __Request__mach_port_space_info_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
		NDR_record_t NDR;
		mach_port_name_t name;
	} __Request__mach_port_dnrequest_info_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
		NDR_record_t NDR;
		mach_port_name_t name;
	} __Request__mach_port_kernel_object_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
		NDR_record_t NDR;
		mach_port_name_t name;
		mach_port_name_t pset;
	} __Request__mach_port_insert_member_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
		NDR_record_t NDR;
		mach_port_name_t name;
		mach_port_name_t pset;
	} __Request__mach_port_extract_member_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
		NDR_record_t NDR;
		mach_port_name_t name;
	} __Request__mach_port_get_context_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
		NDR_record_t NDR;
		mach_port_name_t name;
		mach_port_context_t context;
	} __Request__mach_port_set_context_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
		NDR_record_t NDR;
		mach_port_name_t name;
	} __Request__mach_port_kobject_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
		/* start of the kernel processed data */
		mach_msg_body_t msgh_body;
		mach_msg_ool_descriptor_t options;
		/* end of the kernel processed data */
		NDR_record_t NDR;
		mach_port_context_t context;
	} __Request__mach_port_construct_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
		NDR_record_t NDR;
		mach_port_name_t name;
		mach_port_delta_t srdelta;
		mach_port_context_t guard;
	} __Request__mach_port_destruct_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
		NDR_record_t NDR;
		mach_port_name_t name;
		mach_port_context_t guard;
		boolean_t strict;
	} __Request__mach_port_guard_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
		NDR_record_t NDR;
		mach_port_name_t name;
		mach_port_context_t guard;
	} __Request__mach_port_unguard_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
	} __Request__mach_port_space_basic_info_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
		NDR_record_t NDR;
		mach_port_name_t name;
		mach_port_context_t guard;
		uint64_t flags;
	} __Request__mach_port_guard_with_flags_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
		NDR_record_t NDR;
		mach_port_name_t name;
		mach_port_context_t old_guard;
		mach_port_context_t new_guard;
	} __Request__mach_port_swap_guard_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
		NDR_record_t NDR;
		mach_port_name_t name;
	} __Request__mach_port_kobject_description_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
		NDR_record_t NDR;
		mach_port_name_t connection_port;
		mach_port_name_t service_port;
	} __Request__mach_port_is_connection_for_service_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
		NDR_record_t NDR;
		mach_port_name_t name;
	} __Request__mach_port_get_service_port_info_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
		NDR_record_t NDR;
		mach_port_name_t name;
		mach_port_flavor_t flavor;
		mach_msg_type_number_t infoCnt;
		integer_t info[17];
	} __Request__mach_port_assert_attributes_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif
#endif /* !__Request__mach_port_subsystem__defined */

/* union of all requests */

#ifndef __RequestUnion__mach_port_subsystem__defined
#define __RequestUnion__mach_port_subsystem__defined
union __RequestUnion__mach_port_subsystem {
	__Request__mach_port_names_t Request_mach_port_names;
	__Request__mach_port_type_t Request_mach_port_type;
	__Request__mach_port_rename_t Request_mach_port_rename;
	__Request__mach_port_allocate_name_t Request_mach_port_allocate_name;
	__Request__mach_port_allocate_t Request_mach_port_allocate;
	__Request__mach_port_destroy_t Request_mach_port_destroy;
	__Request__mach_port_deallocate_t Request_mach_port_deallocate;
	__Request__mach_port_get_refs_t Request_mach_port_get_refs;
	__Request__mach_port_mod_refs_t Request_mach_port_mod_refs;
	__Request__mach_port_peek_t Request_mach_port_peek;
	__Request__mach_port_set_mscount_t Request_mach_port_set_mscount;
	__Request__mach_port_get_set_status_t Request_mach_port_get_set_status;
	__Request__mach_port_move_member_t Request_mach_port_move_member;
	__Request__mach_port_request_notification_t Request_mach_port_request_notification;
	__Request__mach_port_insert_right_t Request_mach_port_insert_right;
	__Request__mach_port_extract_right_t Request_mach_port_extract_right;
	__Request__mach_port_set_seqno_t Request_mach_port_set_seqno;
	__Request__mach_port_get_attributes_t Request_mach_port_get_attributes;
	__Request__mach_port_set_attributes_t Request_mach_port_set_attributes;
	__Request__mach_port_allocate_qos_t Request_mach_port_allocate_qos;
	__Request__mach_port_allocate_full_t Request_mach_port_allocate_full;
	__Request__task_set_port_space_t Request_task_set_port_space;
	__Request__mach_port_get_srights_t Request_mach_port_get_srights;
	__Request__mach_port_space_info_t Request_mach_port_space_info;
	__Request__mach_port_dnrequest_info_t Request_mach_port_dnrequest_info;
	__Request__mach_port_kernel_object_t Request_mach_port_kernel_object;
	__Request__mach_port_insert_member_t Request_mach_port_insert_member;
	__Request__mach_port_extract_member_t Request_mach_port_extract_member;
	__Request__mach_port_get_context_t Request_mach_port_get_context;
	__Request__mach_port_set_context_t Request_mach_port_set_context;
	__Request__mach_port_kobject_t Request_mach_port_kobject;
	__Request__mach_port_construct_t Request_mach_port_construct;
	__Request__mach_port_destruct_t Request_mach_port_destruct;
	__Request__mach_port_guard_t Request_mach_port_guard;
	__Request__mach_port_unguard_t Request_mach_port_unguard;
	__Request__mach_port_space_basic_info_t Request_mach_port_space_basic_info;
	__Request__mach_port_guard_with_flags_t Request_mach_port_guard_with_flags;
	__Request__mach_port_swap_guard_t Request_mach_port_swap_guard;
	__Request__mach_port_kobject_description_t Request_mach_port_kobject_description;
	__Request__mach_port_is_connection_for_service_t Request_mach_port_is_connection_for_service;
	__Request__mach_port_get_service_port_info_t Request_mach_port_get_service_port_info;
	__Request__mach_port_assert_attributes_t Request_mach_port_assert_attributes;
};
#endif /* !__RequestUnion__mach_port_subsystem__defined */
/* typedefs for all replies */

#ifndef __Reply__mach_port_subsystem__defined
#define __Reply__mach_port_subsystem__defined

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
		/* start of the kernel processed data */
		mach_msg_body_t msgh_body;
		mach_msg_ool_descriptor_t names;
		mach_msg_ool_descriptor_t types;
		/* end of the kernel processed data */
		NDR_record_t NDR;
		mach_msg_type_number_t namesCnt;
		mach_msg_type_number_t typesCnt;
	} __Reply__mach_port_names_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
		NDR_record_t NDR;
		kern_return_t RetCode;
		mach_port_type_t ptype;
	} __Reply__mach_port_type_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
		NDR_record_t NDR;
		kern_return_t RetCode;
	} __Reply__mach_port_rename_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
		NDR_record_t NDR;
		kern_return_t RetCode;
	} __Reply__mach_port_allocate_name_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
		NDR_record_t NDR;
		kern_return_t RetCode;
		mach_port_name_t name;
	} __Reply__mach_port_allocate_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
		NDR_record_t NDR;
		kern_return_t RetCode;
	} __Reply__mach_port_destroy_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
		NDR_record_t NDR;
		kern_return_t RetCode;
	} __Reply__mach_port_deallocate_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
		NDR_record_t NDR;
		kern_return_t RetCode;
		mach_port_urefs_t refs;
	} __Reply__mach_port_get_refs_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
		NDR_record_t NDR;
		kern_return_t RetCode;
	} __Reply__mach_port_mod_refs_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
		NDR_record_t NDR;
		kern_return_t RetCode;
		mach_port_seqno_t request_seqnop;
		mach_msg_size_t msg_sizep;
		mach_msg_id_t msg_idp;
		mach_msg_type_number_t trailer_infopCnt;
		char trailer_infop[68];
	} __Reply__mach_port_peek_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
		NDR_record_t NDR;
		kern_return_t RetCode;
	} __Reply__mach_port_set_mscount_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
		/* start of the kernel processed data */
		mach_msg_body_t msgh_body;
		mach_msg_ool_descriptor_t members;
		/* end of the kernel processed data */
		NDR_record_t NDR;
		mach_msg_type_number_t membersCnt;
	} __Reply__mach_port_get_set_status_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
		NDR_record_t NDR;
		kern_return_t RetCode;
	} __Reply__mach_port_move_member_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
		/* start of the kernel processed data */
		mach_msg_body_t msgh_body;
		mach_msg_port_descriptor_t previous;
		/* end of the kernel processed data */
	} __Reply__mach_port_request_notification_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
		NDR_record_t NDR;
		kern_return_t RetCode;
	} __Reply__mach_port_insert_right_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
		/* start of the kernel processed data */
		mach_msg_body_t msgh_body;
		mach_msg_port_descriptor_t poly;
		/* end of the kernel processed data */
	} __Reply__mach_port_extract_right_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
		NDR_record_t NDR;
		kern_return_t RetCode;
	} __Reply__mach_port_set_seqno_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
		NDR_record_t NDR;
		kern_return_t RetCode;
		mach_msg_type_number_t port_info_outCnt;
		integer_t port_info_out[17];
	} __Reply__mach_port_get_attributes_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
		NDR_record_t NDR;
		kern_return_t RetCode;
	} __Reply__mach_port_set_attributes_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
		NDR_record_t NDR;
		kern_return_t RetCode;
		mach_port_qos_t qos;
		mach_port_name_t name;
	} __Reply__mach_port_allocate_qos_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
		NDR_record_t NDR;
		kern_return_t RetCode;
		mach_port_qos_t qos;
		mach_port_name_t name;
	} __Reply__mach_port_allocate_full_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
		NDR_record_t NDR;
		kern_return_t RetCode;
	} __Reply__task_set_port_space_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
		NDR_record_t NDR;
		kern_return_t RetCode;
		mach_port_rights_t srights;
	} __Reply__mach_port_get_srights_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
		/* start of the kernel processed data */
		mach_msg_body_t msgh_body;
		mach_msg_ool_descriptor_t table_info;
		mach_msg_ool_descriptor_t tree_info;
		/* end of the kernel processed data */
		NDR_record_t NDR;
		ipc_info_space_t space_info;
		mach_msg_type_number_t table_infoCnt;
		mach_msg_type_number_t tree_infoCnt;
	} __Reply__mach_port_space_info_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
		NDR_record_t NDR;
		kern_return_t RetCode;
		unsigned dnr_total;
		unsigned dnr_used;
	} __Reply__mach_port_dnrequest_info_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
		NDR_record_t NDR;
		kern_return_t RetCode;
		unsigned object_type;
		unsigned object_addr;
	} __Reply__mach_port_kernel_object_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
		NDR_record_t NDR;
		kern_return_t RetCode;
	} __Reply__mach_port_insert_member_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
		NDR_record_t NDR;
		kern_return_t RetCode;
	} __Reply__mach_port_extract_member_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
		NDR_record_t NDR;
		kern_return_t RetCode;
		mach_port_context_t context;
	} __Reply__mach_port_get_context_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
		NDR_record_t NDR;
		kern_return_t RetCode;
	} __Reply__mach_port_set_context_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
		NDR_record_t NDR;
		kern_return_t RetCode;
		natural_t object_type;
		mach_vm_address_t object_addr;
	} __Reply__mach_port_kobject_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
		NDR_record_t NDR;
		kern_return_t RetCode;
		mach_port_name_t name;
	} __Reply__mach_port_construct_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
		NDR_record_t NDR;
		kern_return_t RetCode;
	} __Reply__mach_port_destruct_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
		NDR_record_t NDR;
		kern_return_t RetCode;
	} __Reply__mach_port_guard_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
		NDR_record_t NDR;
		kern_return_t RetCode;
	} __Reply__mach_port_unguard_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
		NDR_record_t NDR;
		kern_return_t RetCode;
		ipc_info_space_basic_t basic_info;
	} __Reply__mach_port_space_basic_info_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
		NDR_record_t NDR;
		kern_return_t RetCode;
	} __Reply__mach_port_guard_with_flags_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
		NDR_record_t NDR;
		kern_return_t RetCode;
	} __Reply__mach_port_swap_guard_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
		NDR_record_t NDR;
		kern_return_t RetCode;
		natural_t object_type;
		mach_vm_address_t object_addr;
		mach_msg_type_number_t descriptionOffset; /* MiG doesn't use it */
		mach_msg_type_number_t descriptionCnt;
		char description[512];
	} __Reply__mach_port_kobject_description_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
		NDR_record_t NDR;
		kern_return_t RetCode;
		uint64_t filter_policy_id;
	} __Reply__mach_port_is_connection_for_service_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
		NDR_record_t NDR;
		kern_return_t RetCode;
		mach_service_port_info_data_t sp_info_out;
	} __Reply__mach_port_get_service_port_info_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
		NDR_record_t NDR;
		kern_return_t RetCode;
	} __Reply__mach_port_assert_attributes_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif
#endif /* !__Reply__mach_port_subsystem__defined */

/* union of all replies */

#ifndef __ReplyUnion__mach_port_subsystem__defined
#define __ReplyUnion__mach_port_subsystem__defined
union __ReplyUnion__mach_port_subsystem {
	__Reply__mach_port_names_t Reply_mach_port_names;
	__Reply__mach_port_type_t Reply_mach_port_type;
	__Reply__mach_port_rename_t Reply_mach_port_rename;
	__Reply__mach_port_allocate_name_t Reply_mach_port_allocate_name;
	__Reply__mach_port_allocate_t Reply_mach_port_allocate;
	__Reply__mach_port_destroy_t Reply_mach_port_destroy;
	__Reply__mach_port_deallocate_t Reply_mach_port_deallocate;
	__Reply__mach_port_get_refs_t Reply_mach_port_get_refs;
	__Reply__mach_port_mod_refs_t Reply_mach_port_mod_refs;
	__Reply__mach_port_peek_t Reply_mach_port_peek;
	__Reply__mach_port_set_mscount_t Reply_mach_port_set_mscount;
	__Reply__mach_port_get_set_status_t Reply_mach_port_get_set_status;
	__Reply__mach_port_move_member_t Reply_mach_port_move_member;
	__Reply__mach_port_request_notification_t Reply_mach_port_request_notification;
	__Reply__mach_port_insert_right_t Reply_mach_port_insert_right;
	__Reply__mach_port_extract_right_t Reply_mach_port_extract_right;
	__Reply__mach_port_set_seqno_t Reply_mach_port_set_seqno;
	__Reply__mach_port_get_attributes_t Reply_mach_port_get_attributes;
	__Reply__mach_port_set_attributes_t Reply_mach_port_set_attributes;
	__Reply__mach_port_allocate_qos_t Reply_mach_port_allocate_qos;
	__Reply__mach_port_allocate_full_t Reply_mach_port_allocate_full;
	__Reply__task_set_port_space_t Reply_task_set_port_space;
	__Reply__mach_port_get_srights_t Reply_mach_port_get_srights;
	__Reply__mach_port_space_info_t Reply_mach_port_space_info;
	__Reply__mach_port_dnrequest_info_t Reply_mach_port_dnrequest_info;
	__Reply__mach_port_kernel_object_t Reply_mach_port_kernel_object;
	__Reply__mach_port_insert_member_t Reply_mach_port_insert_member;
	__Reply__mach_port_extract_member_t Reply_mach_port_extract_member;
	__Reply__mach_port_get_context_t Reply_mach_port_get_context;
	__Reply__mach_port_set_context_t Reply_mach_port_set_context;
	__Reply__mach_port_kobject_t Reply_mach_port_kobject;
	__Reply__mach_port_construct_t Reply_mach_port_construct;
	__Reply__mach_port_destruct_t Reply_mach_port_destruct;
	__Reply__mach_port_guard_t Reply_mach_port_guard;
	__Reply__mach_port_unguard_t Reply_mach_port_unguard;
	__Reply__mach_port_space_basic_info_t Reply_mach_port_space_basic_info;
	__Reply__mach_port_guard_with_flags_t Reply_mach_port_guard_with_flags;
	__Reply__mach_port_swap_guard_t Reply_mach_port_swap_guard;
	__Reply__mach_port_kobject_description_t Reply_mach_port_kobject_description;
	__Reply__mach_port_is_connection_for_service_t Reply_mach_port_is_connection_for_service;
	__Reply__mach_port_get_service_port_info_t Reply_mach_port_get_service_port_info;
	__Reply__mach_port_assert_attributes_t Reply_mach_port_assert_attributes;
};
#endif /* !__RequestUnion__mach_port_subsystem__defined */

#ifndef subsystem_to_name_map_mach_port
#define subsystem_to_name_map_mach_port \
    { "mach_port_names", 3200 },\
    { "mach_port_type", 3201 },\
    { "mach_port_rename", 3202 },\
    { "mach_port_allocate_name", 3203 },\
    { "mach_port_allocate", 3204 },\
    { "mach_port_destroy", 3205 },\
    { "mach_port_deallocate", 3206 },\
    { "mach_port_get_refs", 3207 },\
    { "mach_port_mod_refs", 3208 },\
    { "mach_port_peek", 3209 },\
    { "mach_port_set_mscount", 3210 },\
    { "mach_port_get_set_status", 3211 },\
    { "mach_port_move_member", 3212 },\
    { "mach_port_request_notification", 3213 },\
    { "mach_port_insert_right", 3214 },\
    { "mach_port_extract_right", 3215 },\
    { "mach_port_set_seqno", 3216 },\
    { "mach_port_get_attributes", 3217 },\
    { "mach_port_set_attributes", 3218 },\
    { "mach_port_allocate_qos", 3219 },\
    { "mach_port_allocate_full", 3220 },\
    { "task_set_port_space", 3221 },\
    { "mach_port_get_srights", 3222 },\
    { "mach_port_space_info", 3223 },\
    { "mach_port_dnrequest_info", 3224 },\
    { "mach_port_kernel_object", 3225 },\
    { "mach_port_insert_member", 3226 },\
    { "mach_port_extract_member", 3227 },\
    { "mach_port_get_context", 3228 },\
    { "mach_port_set_context", 3229 },\
    { "mach_port_kobject", 3230 },\
    { "mach_port_construct", 3231 },\
    { "mach_port_destruct", 3232 },\
    { "mach_port_guard", 3233 },\
    { "mach_port_unguard", 3234 },\
    { "mach_port_space_basic_info", 3235 },\
    { "mach_port_guard_with_flags", 3237 },\
    { "mach_port_swap_guard", 3238 },\
    { "mach_port_kobject_description", 3239 },\
    { "mach_port_is_connection_for_service", 3240 },\
    { "mach_port_get_service_port_info", 3241 },\
    { "mach_port_assert_attributes", 3242 }
#endif

#ifdef __AfterMigUserHeader
__AfterMigUserHeader
#endif /* __AfterMigUserHeader */

#endif	 /* _mach_port_user_ */
