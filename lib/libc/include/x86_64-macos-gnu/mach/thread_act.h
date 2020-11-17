#ifndef	_thread_act_user_
#define	_thread_act_user_

/* Module thread_act */

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

#ifndef	thread_act_MSG_COUNT
#define	thread_act_MSG_COUNT	28
#endif	/* thread_act_MSG_COUNT */

#include <mach/std_types.h>
#include <mach/mig.h>
#include <mach/mig.h>
#include <mach/mach_types.h>

#ifdef __BeforeMigUserHeader
__BeforeMigUserHeader
#endif /* __BeforeMigUserHeader */

#include <sys/cdefs.h>
__BEGIN_DECLS


/* Routine thread_terminate */
#ifdef	mig_external
mig_external
#else
extern
#endif	/* mig_external */
__WATCHOS_PROHIBITED
__TVOS_PROHIBITED
kern_return_t thread_terminate
(
	thread_act_t target_act
);

/* Routine act_get_state */
#ifdef	mig_external
mig_external
#else
extern
#endif	/* mig_external */
__WATCHOS_PROHIBITED
__TVOS_PROHIBITED
kern_return_t act_get_state
(
	thread_act_t target_act,
	int flavor,
	thread_state_t old_state,
	mach_msg_type_number_t *old_stateCnt
);

/* Routine act_set_state */
#ifdef	mig_external
mig_external
#else
extern
#endif	/* mig_external */
__WATCHOS_PROHIBITED
__TVOS_PROHIBITED
kern_return_t act_set_state
(
	thread_act_t target_act,
	int flavor,
	thread_state_t new_state,
	mach_msg_type_number_t new_stateCnt
);

/* Routine thread_get_state */
#ifdef	mig_external
mig_external
#else
extern
#endif	/* mig_external */
__WATCHOS_PROHIBITED
kern_return_t thread_get_state
(
	thread_act_t target_act,
	thread_state_flavor_t flavor,
	thread_state_t old_state,
	mach_msg_type_number_t *old_stateCnt
);

/* Routine thread_set_state */
#ifdef	mig_external
mig_external
#else
extern
#endif	/* mig_external */
__WATCHOS_PROHIBITED
kern_return_t thread_set_state
(
	thread_act_t target_act,
	thread_state_flavor_t flavor,
	thread_state_t new_state,
	mach_msg_type_number_t new_stateCnt
);

/* Routine thread_suspend */
#ifdef	mig_external
mig_external
#else
extern
#endif	/* mig_external */
__WATCHOS_PROHIBITED
kern_return_t thread_suspend
(
	thread_act_t target_act
);

/* Routine thread_resume */
#ifdef	mig_external
mig_external
#else
extern
#endif	/* mig_external */
__WATCHOS_PROHIBITED
kern_return_t thread_resume
(
	thread_act_t target_act
);

/* Routine thread_abort */
#ifdef	mig_external
mig_external
#else
extern
#endif	/* mig_external */
__WATCHOS_PROHIBITED
kern_return_t thread_abort
(
	thread_act_t target_act
);

/* Routine thread_abort_safely */
#ifdef	mig_external
mig_external
#else
extern
#endif	/* mig_external */
__WATCHOS_PROHIBITED
kern_return_t thread_abort_safely
(
	thread_act_t target_act
);

/* Routine thread_depress_abort */
#ifdef	mig_external
mig_external
#else
extern
#endif	/* mig_external */
__WATCHOS_PROHIBITED
__TVOS_PROHIBITED
kern_return_t thread_depress_abort
(
	thread_act_t thread
);

/* Routine thread_get_special_port */
#ifdef	mig_external
mig_external
#else
extern
#endif	/* mig_external */
__WATCHOS_PROHIBITED
__TVOS_PROHIBITED
kern_return_t thread_get_special_port
(
	thread_act_t thr_act,
	int which_port,
	mach_port_t *special_port
);

/* Routine thread_set_special_port */
#ifdef	mig_external
mig_external
#else
extern
#endif	/* mig_external */
__WATCHOS_PROHIBITED
__TVOS_PROHIBITED
kern_return_t thread_set_special_port
(
	thread_act_t thr_act,
	int which_port,
	mach_port_t special_port
);

/* Routine thread_info */
#ifdef	mig_external
mig_external
#else
extern
#endif	/* mig_external */
kern_return_t thread_info
(
	thread_inspect_t target_act,
	thread_flavor_t flavor,
	thread_info_t thread_info_out,
	mach_msg_type_number_t *thread_info_outCnt
);

/* Routine thread_set_exception_ports */
#ifdef	mig_external
mig_external
#else
extern
#endif	/* mig_external */
__WATCHOS_PROHIBITED
__TVOS_PROHIBITED
kern_return_t thread_set_exception_ports
(
	thread_act_t thread,
	exception_mask_t exception_mask,
	mach_port_t new_port,
	exception_behavior_t behavior,
	thread_state_flavor_t new_flavor
);

/* Routine thread_get_exception_ports */
#ifdef	mig_external
mig_external
#else
extern
#endif	/* mig_external */
__WATCHOS_PROHIBITED
__TVOS_PROHIBITED
kern_return_t thread_get_exception_ports
(
	thread_inspect_t thread,
	exception_mask_t exception_mask,
	exception_mask_array_t masks,
	mach_msg_type_number_t *masksCnt,
	exception_handler_array_t old_handlers,
	exception_behavior_array_t old_behaviors,
	exception_flavor_array_t old_flavors
);

/* Routine thread_swap_exception_ports */
#ifdef	mig_external
mig_external
#else
extern
#endif	/* mig_external */
__WATCHOS_PROHIBITED
__TVOS_PROHIBITED
kern_return_t thread_swap_exception_ports
(
	thread_act_t thread,
	exception_mask_t exception_mask,
	mach_port_t new_port,
	exception_behavior_t behavior,
	thread_state_flavor_t new_flavor,
	exception_mask_array_t masks,
	mach_msg_type_number_t *masksCnt,
	exception_handler_array_t old_handlers,
	exception_behavior_array_t old_behaviors,
	exception_flavor_array_t old_flavors
);

/* Routine thread_policy */
#ifdef	mig_external
mig_external
#else
extern
#endif	/* mig_external */
kern_return_t thread_policy
(
	thread_act_t thr_act,
	policy_t policy,
	policy_base_t base,
	mach_msg_type_number_t baseCnt,
	boolean_t set_limit
);

/* Routine thread_policy_set */
#ifdef	mig_external
mig_external
#else
extern
#endif	/* mig_external */
kern_return_t thread_policy_set
(
	thread_act_t thread,
	thread_policy_flavor_t flavor,
	thread_policy_t policy_info,
	mach_msg_type_number_t policy_infoCnt
);

/* Routine thread_policy_get */
#ifdef	mig_external
mig_external
#else
extern
#endif	/* mig_external */
kern_return_t thread_policy_get
(
	thread_inspect_t thread,
	thread_policy_flavor_t flavor,
	thread_policy_t policy_info,
	mach_msg_type_number_t *policy_infoCnt,
	boolean_t *get_default
);

/* Routine thread_sample */
#ifdef	mig_external
mig_external
#else
extern
#endif	/* mig_external */
kern_return_t thread_sample
(
	thread_act_t thread,
	mach_port_t reply
);

/* Routine etap_trace_thread */
#ifdef	mig_external
mig_external
#else
extern
#endif	/* mig_external */
kern_return_t etap_trace_thread
(
	thread_act_t target_act,
	boolean_t trace_status
);

/* Routine thread_assign */
#ifdef	mig_external
mig_external
#else
extern
#endif	/* mig_external */
kern_return_t thread_assign
(
	thread_act_t thread,
	processor_set_t new_set
);

/* Routine thread_assign_default */
#ifdef	mig_external
mig_external
#else
extern
#endif	/* mig_external */
kern_return_t thread_assign_default
(
	thread_act_t thread
);

/* Routine thread_get_assignment */
#ifdef	mig_external
mig_external
#else
extern
#endif	/* mig_external */
kern_return_t thread_get_assignment
(
	thread_act_t thread,
	processor_set_name_t *assigned_set
);

/* Routine thread_set_policy */
#ifdef	mig_external
mig_external
#else
extern
#endif	/* mig_external */
kern_return_t thread_set_policy
(
	thread_act_t thr_act,
	processor_set_t pset,
	policy_t policy,
	policy_base_t base,
	mach_msg_type_number_t baseCnt,
	policy_limit_t limit,
	mach_msg_type_number_t limitCnt
);

/* Routine thread_get_mach_voucher */
#ifdef	mig_external
mig_external
#else
extern
#endif	/* mig_external */
__WATCHOS_PROHIBITED
__TVOS_PROHIBITED
kern_return_t thread_get_mach_voucher
(
	thread_act_t thr_act,
	mach_voucher_selector_t which,
	ipc_voucher_t *voucher
);

/* Routine thread_set_mach_voucher */
#ifdef	mig_external
mig_external
#else
extern
#endif	/* mig_external */
__WATCHOS_PROHIBITED
__TVOS_PROHIBITED
kern_return_t thread_set_mach_voucher
(
	thread_act_t thr_act,
	ipc_voucher_t voucher
);

/* Routine thread_swap_mach_voucher */
#ifdef	mig_external
mig_external
#else
extern
#endif	/* mig_external */
__WATCHOS_PROHIBITED
__TVOS_PROHIBITED
kern_return_t thread_swap_mach_voucher
(
	thread_act_t thr_act,
	ipc_voucher_t new_voucher,
	ipc_voucher_t *old_voucher
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

#ifndef __Request__thread_act_subsystem__defined
#define __Request__thread_act_subsystem__defined

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
	} __Request__thread_terminate_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
		NDR_record_t NDR;
		int flavor;
		mach_msg_type_number_t old_stateCnt;
	} __Request__act_get_state_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
		NDR_record_t NDR;
		int flavor;
		mach_msg_type_number_t new_stateCnt;
		natural_t new_state[614];
	} __Request__act_set_state_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
		NDR_record_t NDR;
		thread_state_flavor_t flavor;
		mach_msg_type_number_t old_stateCnt;
	} __Request__thread_get_state_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
		NDR_record_t NDR;
		thread_state_flavor_t flavor;
		mach_msg_type_number_t new_stateCnt;
		natural_t new_state[614];
	} __Request__thread_set_state_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
	} __Request__thread_suspend_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
	} __Request__thread_resume_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
	} __Request__thread_abort_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
	} __Request__thread_abort_safely_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
	} __Request__thread_depress_abort_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
		NDR_record_t NDR;
		int which_port;
	} __Request__thread_get_special_port_t __attribute__((unused));
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
		mach_msg_port_descriptor_t special_port;
		/* end of the kernel processed data */
		NDR_record_t NDR;
		int which_port;
	} __Request__thread_set_special_port_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
		NDR_record_t NDR;
		thread_flavor_t flavor;
		mach_msg_type_number_t thread_info_outCnt;
	} __Request__thread_info_t __attribute__((unused));
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
		mach_msg_port_descriptor_t new_port;
		/* end of the kernel processed data */
		NDR_record_t NDR;
		exception_mask_t exception_mask;
		exception_behavior_t behavior;
		thread_state_flavor_t new_flavor;
	} __Request__thread_set_exception_ports_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
		NDR_record_t NDR;
		exception_mask_t exception_mask;
	} __Request__thread_get_exception_ports_t __attribute__((unused));
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
		mach_msg_port_descriptor_t new_port;
		/* end of the kernel processed data */
		NDR_record_t NDR;
		exception_mask_t exception_mask;
		exception_behavior_t behavior;
		thread_state_flavor_t new_flavor;
	} __Request__thread_swap_exception_ports_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
		NDR_record_t NDR;
		policy_t policy;
		mach_msg_type_number_t baseCnt;
		integer_t base[5];
		boolean_t set_limit;
	} __Request__thread_policy_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
		NDR_record_t NDR;
		thread_policy_flavor_t flavor;
		mach_msg_type_number_t policy_infoCnt;
		integer_t policy_info[16];
	} __Request__thread_policy_set_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
		NDR_record_t NDR;
		thread_policy_flavor_t flavor;
		mach_msg_type_number_t policy_infoCnt;
		boolean_t get_default;
	} __Request__thread_policy_get_t __attribute__((unused));
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
		mach_msg_port_descriptor_t reply;
		/* end of the kernel processed data */
	} __Request__thread_sample_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
		NDR_record_t NDR;
		boolean_t trace_status;
	} __Request__etap_trace_thread_t __attribute__((unused));
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
		mach_msg_port_descriptor_t new_set;
		/* end of the kernel processed data */
	} __Request__thread_assign_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
	} __Request__thread_assign_default_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
	} __Request__thread_get_assignment_t __attribute__((unused));
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
		mach_msg_port_descriptor_t pset;
		/* end of the kernel processed data */
		NDR_record_t NDR;
		policy_t policy;
		mach_msg_type_number_t baseCnt;
		integer_t base[5];
		mach_msg_type_number_t limitCnt;
		integer_t limit[1];
	} __Request__thread_set_policy_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
		NDR_record_t NDR;
		mach_voucher_selector_t which;
	} __Request__thread_get_mach_voucher_t __attribute__((unused));
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
		mach_msg_port_descriptor_t voucher;
		/* end of the kernel processed data */
	} __Request__thread_set_mach_voucher_t __attribute__((unused));
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
		mach_msg_port_descriptor_t new_voucher;
		mach_msg_port_descriptor_t old_voucher;
		/* end of the kernel processed data */
	} __Request__thread_swap_mach_voucher_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif
#endif /* !__Request__thread_act_subsystem__defined */

/* union of all requests */

#ifndef __RequestUnion__thread_act_subsystem__defined
#define __RequestUnion__thread_act_subsystem__defined
union __RequestUnion__thread_act_subsystem {
	__Request__thread_terminate_t Request_thread_terminate;
	__Request__act_get_state_t Request_act_get_state;
	__Request__act_set_state_t Request_act_set_state;
	__Request__thread_get_state_t Request_thread_get_state;
	__Request__thread_set_state_t Request_thread_set_state;
	__Request__thread_suspend_t Request_thread_suspend;
	__Request__thread_resume_t Request_thread_resume;
	__Request__thread_abort_t Request_thread_abort;
	__Request__thread_abort_safely_t Request_thread_abort_safely;
	__Request__thread_depress_abort_t Request_thread_depress_abort;
	__Request__thread_get_special_port_t Request_thread_get_special_port;
	__Request__thread_set_special_port_t Request_thread_set_special_port;
	__Request__thread_info_t Request_thread_info;
	__Request__thread_set_exception_ports_t Request_thread_set_exception_ports;
	__Request__thread_get_exception_ports_t Request_thread_get_exception_ports;
	__Request__thread_swap_exception_ports_t Request_thread_swap_exception_ports;
	__Request__thread_policy_t Request_thread_policy;
	__Request__thread_policy_set_t Request_thread_policy_set;
	__Request__thread_policy_get_t Request_thread_policy_get;
	__Request__thread_sample_t Request_thread_sample;
	__Request__etap_trace_thread_t Request_etap_trace_thread;
	__Request__thread_assign_t Request_thread_assign;
	__Request__thread_assign_default_t Request_thread_assign_default;
	__Request__thread_get_assignment_t Request_thread_get_assignment;
	__Request__thread_set_policy_t Request_thread_set_policy;
	__Request__thread_get_mach_voucher_t Request_thread_get_mach_voucher;
	__Request__thread_set_mach_voucher_t Request_thread_set_mach_voucher;
	__Request__thread_swap_mach_voucher_t Request_thread_swap_mach_voucher;
};
#endif /* !__RequestUnion__thread_act_subsystem__defined */
/* typedefs for all replies */

#ifndef __Reply__thread_act_subsystem__defined
#define __Reply__thread_act_subsystem__defined

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
		NDR_record_t NDR;
		kern_return_t RetCode;
	} __Reply__thread_terminate_t __attribute__((unused));
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
		mach_msg_type_number_t old_stateCnt;
		natural_t old_state[614];
	} __Reply__act_get_state_t __attribute__((unused));
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
	} __Reply__act_set_state_t __attribute__((unused));
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
		mach_msg_type_number_t old_stateCnt;
		natural_t old_state[614];
	} __Reply__thread_get_state_t __attribute__((unused));
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
	} __Reply__thread_set_state_t __attribute__((unused));
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
	} __Reply__thread_suspend_t __attribute__((unused));
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
	} __Reply__thread_resume_t __attribute__((unused));
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
	} __Reply__thread_abort_t __attribute__((unused));
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
	} __Reply__thread_abort_safely_t __attribute__((unused));
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
	} __Reply__thread_depress_abort_t __attribute__((unused));
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
		mach_msg_port_descriptor_t special_port;
		/* end of the kernel processed data */
	} __Reply__thread_get_special_port_t __attribute__((unused));
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
	} __Reply__thread_set_special_port_t __attribute__((unused));
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
		mach_msg_type_number_t thread_info_outCnt;
		integer_t thread_info_out[32];
	} __Reply__thread_info_t __attribute__((unused));
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
	} __Reply__thread_set_exception_ports_t __attribute__((unused));
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
		mach_msg_port_descriptor_t old_handlers[32];
		/* end of the kernel processed data */
		NDR_record_t NDR;
		mach_msg_type_number_t masksCnt;
		exception_mask_t masks[32];
		exception_behavior_t old_behaviors[32];
		thread_state_flavor_t old_flavors[32];
	} __Reply__thread_get_exception_ports_t __attribute__((unused));
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
		mach_msg_port_descriptor_t old_handlers[32];
		/* end of the kernel processed data */
		NDR_record_t NDR;
		mach_msg_type_number_t masksCnt;
		exception_mask_t masks[32];
		exception_behavior_t old_behaviors[32];
		thread_state_flavor_t old_flavors[32];
	} __Reply__thread_swap_exception_ports_t __attribute__((unused));
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
	} __Reply__thread_policy_t __attribute__((unused));
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
	} __Reply__thread_policy_set_t __attribute__((unused));
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
		mach_msg_type_number_t policy_infoCnt;
		integer_t policy_info[16];
		boolean_t get_default;
	} __Reply__thread_policy_get_t __attribute__((unused));
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
	} __Reply__thread_sample_t __attribute__((unused));
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
	} __Reply__etap_trace_thread_t __attribute__((unused));
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
	} __Reply__thread_assign_t __attribute__((unused));
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
	} __Reply__thread_assign_default_t __attribute__((unused));
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
		mach_msg_port_descriptor_t assigned_set;
		/* end of the kernel processed data */
	} __Reply__thread_get_assignment_t __attribute__((unused));
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
	} __Reply__thread_set_policy_t __attribute__((unused));
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
		mach_msg_port_descriptor_t voucher;
		/* end of the kernel processed data */
	} __Reply__thread_get_mach_voucher_t __attribute__((unused));
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
	} __Reply__thread_set_mach_voucher_t __attribute__((unused));
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
		mach_msg_port_descriptor_t old_voucher;
		/* end of the kernel processed data */
	} __Reply__thread_swap_mach_voucher_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif
#endif /* !__Reply__thread_act_subsystem__defined */

/* union of all replies */

#ifndef __ReplyUnion__thread_act_subsystem__defined
#define __ReplyUnion__thread_act_subsystem__defined
union __ReplyUnion__thread_act_subsystem {
	__Reply__thread_terminate_t Reply_thread_terminate;
	__Reply__act_get_state_t Reply_act_get_state;
	__Reply__act_set_state_t Reply_act_set_state;
	__Reply__thread_get_state_t Reply_thread_get_state;
	__Reply__thread_set_state_t Reply_thread_set_state;
	__Reply__thread_suspend_t Reply_thread_suspend;
	__Reply__thread_resume_t Reply_thread_resume;
	__Reply__thread_abort_t Reply_thread_abort;
	__Reply__thread_abort_safely_t Reply_thread_abort_safely;
	__Reply__thread_depress_abort_t Reply_thread_depress_abort;
	__Reply__thread_get_special_port_t Reply_thread_get_special_port;
	__Reply__thread_set_special_port_t Reply_thread_set_special_port;
	__Reply__thread_info_t Reply_thread_info;
	__Reply__thread_set_exception_ports_t Reply_thread_set_exception_ports;
	__Reply__thread_get_exception_ports_t Reply_thread_get_exception_ports;
	__Reply__thread_swap_exception_ports_t Reply_thread_swap_exception_ports;
	__Reply__thread_policy_t Reply_thread_policy;
	__Reply__thread_policy_set_t Reply_thread_policy_set;
	__Reply__thread_policy_get_t Reply_thread_policy_get;
	__Reply__thread_sample_t Reply_thread_sample;
	__Reply__etap_trace_thread_t Reply_etap_trace_thread;
	__Reply__thread_assign_t Reply_thread_assign;
	__Reply__thread_assign_default_t Reply_thread_assign_default;
	__Reply__thread_get_assignment_t Reply_thread_get_assignment;
	__Reply__thread_set_policy_t Reply_thread_set_policy;
	__Reply__thread_get_mach_voucher_t Reply_thread_get_mach_voucher;
	__Reply__thread_set_mach_voucher_t Reply_thread_set_mach_voucher;
	__Reply__thread_swap_mach_voucher_t Reply_thread_swap_mach_voucher;
};
#endif /* !__RequestUnion__thread_act_subsystem__defined */

#ifndef subsystem_to_name_map_thread_act
#define subsystem_to_name_map_thread_act \
    { "thread_terminate", 3600 },\
    { "act_get_state", 3601 },\
    { "act_set_state", 3602 },\
    { "thread_get_state", 3603 },\
    { "thread_set_state", 3604 },\
    { "thread_suspend", 3605 },\
    { "thread_resume", 3606 },\
    { "thread_abort", 3607 },\
    { "thread_abort_safely", 3608 },\
    { "thread_depress_abort", 3609 },\
    { "thread_get_special_port", 3610 },\
    { "thread_set_special_port", 3611 },\
    { "thread_info", 3612 },\
    { "thread_set_exception_ports", 3613 },\
    { "thread_get_exception_ports", 3614 },\
    { "thread_swap_exception_ports", 3615 },\
    { "thread_policy", 3616 },\
    { "thread_policy_set", 3617 },\
    { "thread_policy_get", 3618 },\
    { "thread_sample", 3619 },\
    { "etap_trace_thread", 3620 },\
    { "thread_assign", 3621 },\
    { "thread_assign_default", 3622 },\
    { "thread_get_assignment", 3623 },\
    { "thread_set_policy", 3624 },\
    { "thread_get_mach_voucher", 3625 },\
    { "thread_set_mach_voucher", 3626 },\
    { "thread_swap_mach_voucher", 3627 }
#endif

#ifdef __AfterMigUserHeader
__AfterMigUserHeader
#endif /* __AfterMigUserHeader */

#endif	 /* _thread_act_user_ */
