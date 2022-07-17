#ifndef	_host_security_user_
#define	_host_security_user_

/* Module host_security */

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
	extern int mig_strncpy_zerofill(char *dest, const char *src, int len) __attribute__((weak_import));
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
        char            *name;
        function_ptr_t  function;
} function_table_entry;
typedef function_table_entry   *function_table_t;
#endif /* FUNCTION_PTR_T */
#endif /* AUTOTEST */

#ifndef	host_security_MSG_COUNT
#define	host_security_MSG_COUNT	2
#endif	/* host_security_MSG_COUNT */

#include <Availability.h>
#include <mach/std_types.h>
#include <mach/mig.h>
#include <mach/mig.h>
#include <mach/mach_types.h>

#ifdef __BeforeMigUserHeader
__BeforeMigUserHeader
#endif /* __BeforeMigUserHeader */

#include <sys/cdefs.h>
__BEGIN_DECLS


/* Routine host_security_create_task_token */
#ifdef	mig_external
mig_external
#else
extern
#endif	/* mig_external */
kern_return_t host_security_create_task_token
(
	host_security_t host_security,
	task_t parent_task,
	security_token_t sec_token,
	audit_token_t audit_token,
	host_t host,
	ledger_array_t ledgers,
	mach_msg_type_number_t ledgersCnt,
	boolean_t inherit_memory,
	task_t *child_task
);

/* Routine host_security_set_task_token */
#ifdef	mig_external
mig_external
#else
extern
#endif	/* mig_external */
kern_return_t host_security_set_task_token
(
	host_security_t host_security,
	task_t target_task,
	security_token_t sec_token,
	audit_token_t audit_token,
	host_t host
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

#ifndef __Request__host_security_subsystem__defined
#define __Request__host_security_subsystem__defined

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
		/* start of the kernel processed data */
		mach_msg_body_t msgh_body;
		mach_msg_port_descriptor_t parent_task;
		mach_msg_port_descriptor_t host;
		mach_msg_ool_ports_descriptor_t ledgers;
		/* end of the kernel processed data */
		NDR_record_t NDR;
		security_token_t sec_token;
		audit_token_t audit_token;
		mach_msg_type_number_t ledgersCnt;
		boolean_t inherit_memory;
	} __Request__host_security_create_task_token_t __attribute__((unused));
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
		mach_msg_port_descriptor_t target_task;
		mach_msg_port_descriptor_t host;
		/* end of the kernel processed data */
		NDR_record_t NDR;
		security_token_t sec_token;
		audit_token_t audit_token;
	} __Request__host_security_set_task_token_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif
#endif /* !__Request__host_security_subsystem__defined */

/* union of all requests */

#ifndef __RequestUnion__host_security_subsystem__defined
#define __RequestUnion__host_security_subsystem__defined
union __RequestUnion__host_security_subsystem {
	__Request__host_security_create_task_token_t Request_host_security_create_task_token;
	__Request__host_security_set_task_token_t Request_host_security_set_task_token;
};
#endif /* !__RequestUnion__host_security_subsystem__defined */
/* typedefs for all replies */

#ifndef __Reply__host_security_subsystem__defined
#define __Reply__host_security_subsystem__defined

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
		/* start of the kernel processed data */
		mach_msg_body_t msgh_body;
		mach_msg_port_descriptor_t child_task;
		/* end of the kernel processed data */
	} __Reply__host_security_create_task_token_t __attribute__((unused));
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
	} __Reply__host_security_set_task_token_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif
#endif /* !__Reply__host_security_subsystem__defined */

/* union of all replies */

#ifndef __ReplyUnion__host_security_subsystem__defined
#define __ReplyUnion__host_security_subsystem__defined
union __ReplyUnion__host_security_subsystem {
	__Reply__host_security_create_task_token_t Reply_host_security_create_task_token;
	__Reply__host_security_set_task_token_t Reply_host_security_set_task_token;
};
#endif /* !__RequestUnion__host_security_subsystem__defined */

#ifndef subsystem_to_name_map_host_security
#define subsystem_to_name_map_host_security \
    { "host_security_create_task_token", 600 },\
    { "host_security_set_task_token", 601 }
#endif

#ifdef __AfterMigUserHeader
__AfterMigUserHeader
#endif /* __AfterMigUserHeader */

#endif	 /* _host_security_user_ */