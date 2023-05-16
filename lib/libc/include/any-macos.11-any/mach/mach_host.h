#ifndef	_mach_host_user_
#define	_mach_host_user_

/* Module mach_host */

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

#ifndef	mach_host_MSG_COUNT
#define	mach_host_MSG_COUNT	35
#endif	/* mach_host_MSG_COUNT */

#include <mach/std_types.h>
#include <mach/mig.h>
#include <mach/mig.h>
#include <mach/mach_types.h>
#include <mach/mach_types.h>
#include <mach_debug/mach_debug_types.h>
#include <mach/mach_init.h>

#ifdef __BeforeMigUserHeader
__BeforeMigUserHeader
#endif /* __BeforeMigUserHeader */

#include <sys/cdefs.h>
__BEGIN_DECLS


/* Routine host_info */
#ifdef	mig_external
mig_external
#else
extern
#endif	/* mig_external */
__WATCHOS_PROHIBITED
__TVOS_PROHIBITED
kern_return_t host_info
(
	host_t host,
	host_flavor_t flavor,
	host_info_t host_info_out,
	mach_msg_type_number_t *host_info_outCnt
);

/* Routine host_kernel_version */
#ifdef	mig_external
mig_external
#else
extern
#endif	/* mig_external */
kern_return_t host_kernel_version
(
	host_t host,
	kernel_version_t kernel_version
);

/* Routine _host_page_size */
#ifdef	mig_external
mig_external
#else
extern
#endif	/* mig_external */
kern_return_t _host_page_size
(
	host_t host,
	vm_size_t *out_page_size
);

/* Routine mach_memory_object_memory_entry */
#ifdef	mig_external
mig_external
#else
extern
#endif	/* mig_external */
kern_return_t mach_memory_object_memory_entry
(
	host_t host,
	boolean_t internal,
	vm_size_t size,
	vm_prot_t permission,
	memory_object_t pager,
	mach_port_t *entry_handle
);

/* Routine host_processor_info */
#ifdef	mig_external
mig_external
#else
extern
#endif	/* mig_external */
kern_return_t host_processor_info
(
	host_t host,
	processor_flavor_t flavor,
	natural_t *out_processor_count,
	processor_info_array_t *out_processor_info,
	mach_msg_type_number_t *out_processor_infoCnt
);

/* Routine host_get_io_master */
#ifdef	mig_external
mig_external
#else
extern
#endif	/* mig_external */
kern_return_t host_get_io_master
(
	host_t host,
	io_master_t *io_master
);

/* Routine host_get_clock_service */
#ifdef	mig_external
mig_external
#else
extern
#endif	/* mig_external */
kern_return_t host_get_clock_service
(
	host_t host,
	clock_id_t clock_id,
	clock_serv_t *clock_serv
);

/* Routine kmod_get_info */
#ifdef	mig_external
mig_external
#else
extern
#endif	/* mig_external */
kern_return_t kmod_get_info
(
	host_t host,
	kmod_args_t *modules,
	mach_msg_type_number_t *modulesCnt
);

/* Routine host_virtual_physical_table_info */
#ifdef	mig_external
mig_external
#else
extern
#endif	/* mig_external */
kern_return_t host_virtual_physical_table_info
(
	host_t host,
	hash_info_bucket_array_t *info,
	mach_msg_type_number_t *infoCnt
);

/* Routine processor_set_default */
#ifdef	mig_external
mig_external
#else
extern
#endif	/* mig_external */
kern_return_t processor_set_default
(
	host_t host,
	processor_set_name_t *default_set
);

/* Routine processor_set_create */
#ifdef	mig_external
mig_external
#else
extern
#endif	/* mig_external */
kern_return_t processor_set_create
(
	host_t host,
	processor_set_t *new_set,
	processor_set_name_t *new_name
);

/* Routine mach_memory_object_memory_entry_64 */
#ifdef	mig_external
mig_external
#else
extern
#endif	/* mig_external */
kern_return_t mach_memory_object_memory_entry_64
(
	host_t host,
	boolean_t internal,
	memory_object_size_t size,
	vm_prot_t permission,
	memory_object_t pager,
	mach_port_t *entry_handle
);

/* Routine host_statistics */
#ifdef	mig_external
mig_external
#else
extern
#endif	/* mig_external */
kern_return_t host_statistics
(
	host_t host_priv,
	host_flavor_t flavor,
	host_info_t host_info_out,
	mach_msg_type_number_t *host_info_outCnt
);

/* Routine host_request_notification */
#ifdef	mig_external
mig_external
#else
extern
#endif	/* mig_external */
__WATCHOS_PROHIBITED
__TVOS_PROHIBITED
kern_return_t host_request_notification
(
	host_t host,
	host_flavor_t notify_type,
	mach_port_t notify_port
);

/* Routine host_lockgroup_info */
#ifdef	mig_external
mig_external
#else
extern
#endif	/* mig_external */
kern_return_t host_lockgroup_info
(
	host_t host,
	lockgroup_info_array_t *lockgroup_info,
	mach_msg_type_number_t *lockgroup_infoCnt
);

/* Routine host_statistics64 */
#ifdef	mig_external
mig_external
#else
extern
#endif	/* mig_external */
kern_return_t host_statistics64
(
	host_t host_priv,
	host_flavor_t flavor,
	host_info64_t host_info64_out,
	mach_msg_type_number_t *host_info64_outCnt
);

/* Routine mach_zone_info */
#ifdef	mig_external
mig_external
#else
extern
#endif	/* mig_external */
kern_return_t mach_zone_info
(
	host_priv_t host,
	mach_zone_name_array_t *names,
	mach_msg_type_number_t *namesCnt,
	mach_zone_info_array_t *info,
	mach_msg_type_number_t *infoCnt
);

/* Routine host_create_mach_voucher */
#ifdef	mig_external
mig_external
#else
extern
#endif	/* mig_external */
__WATCHOS_PROHIBITED
__TVOS_PROHIBITED
kern_return_t host_create_mach_voucher
(
	host_t host,
	mach_voucher_attr_raw_recipe_array_t recipes,
	mach_msg_type_number_t recipesCnt,
	ipc_voucher_t *voucher
);

/* Routine host_register_mach_voucher_attr_manager */
#ifdef	mig_external
mig_external
#else
extern
#endif	/* mig_external */
__WATCHOS_PROHIBITED
__TVOS_PROHIBITED
kern_return_t host_register_mach_voucher_attr_manager
(
	host_t host,
	mach_voucher_attr_manager_t attr_manager,
	mach_voucher_attr_value_handle_t default_value,
	mach_voucher_attr_key_t *new_key,
	ipc_voucher_attr_control_t *new_attr_control
);

/* Routine host_register_well_known_mach_voucher_attr_manager */
#ifdef	mig_external
mig_external
#else
extern
#endif	/* mig_external */
__WATCHOS_PROHIBITED
__TVOS_PROHIBITED
kern_return_t host_register_well_known_mach_voucher_attr_manager
(
	host_t host,
	mach_voucher_attr_manager_t attr_manager,
	mach_voucher_attr_value_handle_t default_value,
	mach_voucher_attr_key_t key,
	ipc_voucher_attr_control_t *new_attr_control
);

/* Routine host_set_atm_diagnostic_flag */
#ifdef	mig_external
mig_external
#else
extern
#endif	/* mig_external */
__WATCHOS_PROHIBITED
__TVOS_PROHIBITED
kern_return_t host_set_atm_diagnostic_flag
(
	host_t host,
	uint32_t diagnostic_flag
);

/* Routine host_get_atm_diagnostic_flag */
#ifdef	mig_external
mig_external
#else
extern
#endif	/* mig_external */
__WATCHOS_PROHIBITED
__TVOS_PROHIBITED
kern_return_t host_get_atm_diagnostic_flag
(
	host_t host,
	uint32_t *diagnostic_flag
);

/* Routine mach_memory_info */
#ifdef	mig_external
mig_external
#else
extern
#endif	/* mig_external */
kern_return_t mach_memory_info
(
	host_priv_t host,
	mach_zone_name_array_t *names,
	mach_msg_type_number_t *namesCnt,
	mach_zone_info_array_t *info,
	mach_msg_type_number_t *infoCnt,
	mach_memory_info_array_t *memory_info,
	mach_msg_type_number_t *memory_infoCnt
);

/* Routine host_set_multiuser_config_flags */
#ifdef	mig_external
mig_external
#else
extern
#endif	/* mig_external */
kern_return_t host_set_multiuser_config_flags
(
	host_priv_t host_priv,
	uint32_t multiuser_flags
);

/* Routine host_get_multiuser_config_flags */
#ifdef	mig_external
mig_external
#else
extern
#endif	/* mig_external */
kern_return_t host_get_multiuser_config_flags
(
	host_t host,
	uint32_t *multiuser_flags
);

/* Routine host_check_multiuser_mode */
#ifdef	mig_external
mig_external
#else
extern
#endif	/* mig_external */
kern_return_t host_check_multiuser_mode
(
	host_t host,
	uint32_t *multiuser_mode
);

/* Routine mach_zone_info_for_zone */
#ifdef	mig_external
mig_external
#else
extern
#endif	/* mig_external */
kern_return_t mach_zone_info_for_zone
(
	host_priv_t host,
	mach_zone_name_t name,
	mach_zone_info_t *info
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

#ifndef __Request__mach_host_subsystem__defined
#define __Request__mach_host_subsystem__defined

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
		NDR_record_t NDR;
		host_flavor_t flavor;
		mach_msg_type_number_t host_info_outCnt;
	} __Request__host_info_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
	} __Request__host_kernel_version_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
	} __Request___host_page_size_t __attribute__((unused));
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
		mach_msg_port_descriptor_t pager;
		/* end of the kernel processed data */
		NDR_record_t NDR;
		boolean_t internal;
		vm_size_t size;
		vm_prot_t permission;
	} __Request__mach_memory_object_memory_entry_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
		NDR_record_t NDR;
		processor_flavor_t flavor;
	} __Request__host_processor_info_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
	} __Request__host_get_io_master_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
		NDR_record_t NDR;
		clock_id_t clock_id;
	} __Request__host_get_clock_service_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
	} __Request__kmod_get_info_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
	} __Request__host_virtual_physical_table_info_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
	} __Request__processor_set_default_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
	} __Request__processor_set_create_t __attribute__((unused));
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
		mach_msg_port_descriptor_t pager;
		/* end of the kernel processed data */
		NDR_record_t NDR;
		boolean_t internal;
		memory_object_size_t size;
		vm_prot_t permission;
	} __Request__mach_memory_object_memory_entry_64_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
		NDR_record_t NDR;
		host_flavor_t flavor;
		mach_msg_type_number_t host_info_outCnt;
	} __Request__host_statistics_t __attribute__((unused));
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
		mach_msg_port_descriptor_t notify_port;
		/* end of the kernel processed data */
		NDR_record_t NDR;
		host_flavor_t notify_type;
	} __Request__host_request_notification_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
	} __Request__host_lockgroup_info_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
		NDR_record_t NDR;
		host_flavor_t flavor;
		mach_msg_type_number_t host_info64_outCnt;
	} __Request__host_statistics64_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
	} __Request__mach_zone_info_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
		NDR_record_t NDR;
		mach_msg_type_number_t recipesCnt;
		uint8_t recipes[5120];
	} __Request__host_create_mach_voucher_t __attribute__((unused));
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
		mach_msg_port_descriptor_t attr_manager;
		/* end of the kernel processed data */
		NDR_record_t NDR;
		mach_voucher_attr_value_handle_t default_value;
	} __Request__host_register_mach_voucher_attr_manager_t __attribute__((unused));
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
		mach_msg_port_descriptor_t attr_manager;
		/* end of the kernel processed data */
		NDR_record_t NDR;
		mach_voucher_attr_value_handle_t default_value;
		mach_voucher_attr_key_t key;
	} __Request__host_register_well_known_mach_voucher_attr_manager_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
		NDR_record_t NDR;
		uint32_t diagnostic_flag;
	} __Request__host_set_atm_diagnostic_flag_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
	} __Request__host_get_atm_diagnostic_flag_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
	} __Request__mach_memory_info_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
		NDR_record_t NDR;
		uint32_t multiuser_flags;
	} __Request__host_set_multiuser_config_flags_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
	} __Request__host_get_multiuser_config_flags_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
	} __Request__host_check_multiuser_mode_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
		NDR_record_t NDR;
		mach_zone_name_t name;
	} __Request__mach_zone_info_for_zone_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif
#endif /* !__Request__mach_host_subsystem__defined */

/* union of all requests */

#ifndef __RequestUnion__mach_host_subsystem__defined
#define __RequestUnion__mach_host_subsystem__defined
union __RequestUnion__mach_host_subsystem {
	__Request__host_info_t Request_host_info;
	__Request__host_kernel_version_t Request_host_kernel_version;
	__Request___host_page_size_t Request__host_page_size;
	__Request__mach_memory_object_memory_entry_t Request_mach_memory_object_memory_entry;
	__Request__host_processor_info_t Request_host_processor_info;
	__Request__host_get_io_master_t Request_host_get_io_master;
	__Request__host_get_clock_service_t Request_host_get_clock_service;
	__Request__kmod_get_info_t Request_kmod_get_info;
	__Request__host_virtual_physical_table_info_t Request_host_virtual_physical_table_info;
	__Request__processor_set_default_t Request_processor_set_default;
	__Request__processor_set_create_t Request_processor_set_create;
	__Request__mach_memory_object_memory_entry_64_t Request_mach_memory_object_memory_entry_64;
	__Request__host_statistics_t Request_host_statistics;
	__Request__host_request_notification_t Request_host_request_notification;
	__Request__host_lockgroup_info_t Request_host_lockgroup_info;
	__Request__host_statistics64_t Request_host_statistics64;
	__Request__mach_zone_info_t Request_mach_zone_info;
	__Request__host_create_mach_voucher_t Request_host_create_mach_voucher;
	__Request__host_register_mach_voucher_attr_manager_t Request_host_register_mach_voucher_attr_manager;
	__Request__host_register_well_known_mach_voucher_attr_manager_t Request_host_register_well_known_mach_voucher_attr_manager;
	__Request__host_set_atm_diagnostic_flag_t Request_host_set_atm_diagnostic_flag;
	__Request__host_get_atm_diagnostic_flag_t Request_host_get_atm_diagnostic_flag;
	__Request__mach_memory_info_t Request_mach_memory_info;
	__Request__host_set_multiuser_config_flags_t Request_host_set_multiuser_config_flags;
	__Request__host_get_multiuser_config_flags_t Request_host_get_multiuser_config_flags;
	__Request__host_check_multiuser_mode_t Request_host_check_multiuser_mode;
	__Request__mach_zone_info_for_zone_t Request_mach_zone_info_for_zone;
};
#endif /* !__RequestUnion__mach_host_subsystem__defined */
/* typedefs for all replies */

#ifndef __Reply__mach_host_subsystem__defined
#define __Reply__mach_host_subsystem__defined

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
	typedef struct {
		mach_msg_header_t Head;
		NDR_record_t NDR;
		kern_return_t RetCode;
		mach_msg_type_number_t host_info_outCnt;
		integer_t host_info_out[68];
	} __Reply__host_info_t __attribute__((unused));
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
		mach_msg_type_number_t kernel_versionOffset; /* MiG doesn't use it */
		mach_msg_type_number_t kernel_versionCnt;
		char kernel_version[512];
	} __Reply__host_kernel_version_t __attribute__((unused));
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
		vm_size_t out_page_size;
	} __Reply___host_page_size_t __attribute__((unused));
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
		mach_msg_port_descriptor_t entry_handle;
		/* end of the kernel processed data */
	} __Reply__mach_memory_object_memory_entry_t __attribute__((unused));
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
		mach_msg_ool_descriptor_t out_processor_info;
		/* end of the kernel processed data */
		NDR_record_t NDR;
		natural_t out_processor_count;
		mach_msg_type_number_t out_processor_infoCnt;
	} __Reply__host_processor_info_t __attribute__((unused));
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
		mach_msg_port_descriptor_t io_master;
		/* end of the kernel processed data */
	} __Reply__host_get_io_master_t __attribute__((unused));
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
		mach_msg_port_descriptor_t clock_serv;
		/* end of the kernel processed data */
	} __Reply__host_get_clock_service_t __attribute__((unused));
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
		mach_msg_ool_descriptor_t modules;
		/* end of the kernel processed data */
		NDR_record_t NDR;
		mach_msg_type_number_t modulesCnt;
	} __Reply__kmod_get_info_t __attribute__((unused));
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
		mach_msg_ool_descriptor_t info;
		/* end of the kernel processed data */
		NDR_record_t NDR;
		mach_msg_type_number_t infoCnt;
	} __Reply__host_virtual_physical_table_info_t __attribute__((unused));
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
		mach_msg_port_descriptor_t default_set;
		/* end of the kernel processed data */
	} __Reply__processor_set_default_t __attribute__((unused));
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
		mach_msg_port_descriptor_t new_name;
		/* end of the kernel processed data */
	} __Reply__processor_set_create_t __attribute__((unused));
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
		mach_msg_port_descriptor_t entry_handle;
		/* end of the kernel processed data */
	} __Reply__mach_memory_object_memory_entry_64_t __attribute__((unused));
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
		mach_msg_type_number_t host_info_outCnt;
		integer_t host_info_out[68];
	} __Reply__host_statistics_t __attribute__((unused));
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
	} __Reply__host_request_notification_t __attribute__((unused));
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
		mach_msg_ool_descriptor_t lockgroup_info;
		/* end of the kernel processed data */
		NDR_record_t NDR;
		mach_msg_type_number_t lockgroup_infoCnt;
	} __Reply__host_lockgroup_info_t __attribute__((unused));
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
		mach_msg_type_number_t host_info64_outCnt;
		integer_t host_info64_out[256];
	} __Reply__host_statistics64_t __attribute__((unused));
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
		mach_msg_ool_descriptor_t names;
		mach_msg_ool_descriptor_t info;
		/* end of the kernel processed data */
		NDR_record_t NDR;
		mach_msg_type_number_t namesCnt;
		mach_msg_type_number_t infoCnt;
	} __Reply__mach_zone_info_t __attribute__((unused));
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
	} __Reply__host_create_mach_voucher_t __attribute__((unused));
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
		mach_msg_port_descriptor_t new_attr_control;
		/* end of the kernel processed data */
		NDR_record_t NDR;
		mach_voucher_attr_key_t new_key;
	} __Reply__host_register_mach_voucher_attr_manager_t __attribute__((unused));
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
		mach_msg_port_descriptor_t new_attr_control;
		/* end of the kernel processed data */
	} __Reply__host_register_well_known_mach_voucher_attr_manager_t __attribute__((unused));
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
	} __Reply__host_set_atm_diagnostic_flag_t __attribute__((unused));
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
		uint32_t diagnostic_flag;
	} __Reply__host_get_atm_diagnostic_flag_t __attribute__((unused));
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
		mach_msg_ool_descriptor_t names;
		mach_msg_ool_descriptor_t info;
		mach_msg_ool_descriptor_t memory_info;
		/* end of the kernel processed data */
		NDR_record_t NDR;
		mach_msg_type_number_t namesCnt;
		mach_msg_type_number_t infoCnt;
		mach_msg_type_number_t memory_infoCnt;
	} __Reply__mach_memory_info_t __attribute__((unused));
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
	} __Reply__host_set_multiuser_config_flags_t __attribute__((unused));
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
		uint32_t multiuser_flags;
	} __Reply__host_get_multiuser_config_flags_t __attribute__((unused));
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
		uint32_t multiuser_mode;
	} __Reply__host_check_multiuser_mode_t __attribute__((unused));
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
		mach_zone_info_t info;
	} __Reply__mach_zone_info_for_zone_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif
#endif /* !__Reply__mach_host_subsystem__defined */

/* union of all replies */

#ifndef __ReplyUnion__mach_host_subsystem__defined
#define __ReplyUnion__mach_host_subsystem__defined
union __ReplyUnion__mach_host_subsystem {
	__Reply__host_info_t Reply_host_info;
	__Reply__host_kernel_version_t Reply_host_kernel_version;
	__Reply___host_page_size_t Reply__host_page_size;
	__Reply__mach_memory_object_memory_entry_t Reply_mach_memory_object_memory_entry;
	__Reply__host_processor_info_t Reply_host_processor_info;
	__Reply__host_get_io_master_t Reply_host_get_io_master;
	__Reply__host_get_clock_service_t Reply_host_get_clock_service;
	__Reply__kmod_get_info_t Reply_kmod_get_info;
	__Reply__host_virtual_physical_table_info_t Reply_host_virtual_physical_table_info;
	__Reply__processor_set_default_t Reply_processor_set_default;
	__Reply__processor_set_create_t Reply_processor_set_create;
	__Reply__mach_memory_object_memory_entry_64_t Reply_mach_memory_object_memory_entry_64;
	__Reply__host_statistics_t Reply_host_statistics;
	__Reply__host_request_notification_t Reply_host_request_notification;
	__Reply__host_lockgroup_info_t Reply_host_lockgroup_info;
	__Reply__host_statistics64_t Reply_host_statistics64;
	__Reply__mach_zone_info_t Reply_mach_zone_info;
	__Reply__host_create_mach_voucher_t Reply_host_create_mach_voucher;
	__Reply__host_register_mach_voucher_attr_manager_t Reply_host_register_mach_voucher_attr_manager;
	__Reply__host_register_well_known_mach_voucher_attr_manager_t Reply_host_register_well_known_mach_voucher_attr_manager;
	__Reply__host_set_atm_diagnostic_flag_t Reply_host_set_atm_diagnostic_flag;
	__Reply__host_get_atm_diagnostic_flag_t Reply_host_get_atm_diagnostic_flag;
	__Reply__mach_memory_info_t Reply_mach_memory_info;
	__Reply__host_set_multiuser_config_flags_t Reply_host_set_multiuser_config_flags;
	__Reply__host_get_multiuser_config_flags_t Reply_host_get_multiuser_config_flags;
	__Reply__host_check_multiuser_mode_t Reply_host_check_multiuser_mode;
	__Reply__mach_zone_info_for_zone_t Reply_mach_zone_info_for_zone;
};
#endif /* !__RequestUnion__mach_host_subsystem__defined */

#ifndef subsystem_to_name_map_mach_host
#define subsystem_to_name_map_mach_host \
    { "host_info", 200 },\
    { "host_kernel_version", 201 },\
    { "_host_page_size", 202 },\
    { "mach_memory_object_memory_entry", 203 },\
    { "host_processor_info", 204 },\
    { "host_get_io_master", 205 },\
    { "host_get_clock_service", 206 },\
    { "kmod_get_info", 207 },\
    { "host_virtual_physical_table_info", 209 },\
    { "processor_set_default", 213 },\
    { "processor_set_create", 214 },\
    { "mach_memory_object_memory_entry_64", 215 },\
    { "host_statistics", 216 },\
    { "host_request_notification", 217 },\
    { "host_lockgroup_info", 218 },\
    { "host_statistics64", 219 },\
    { "mach_zone_info", 220 },\
    { "host_create_mach_voucher", 222 },\
    { "host_register_mach_voucher_attr_manager", 223 },\
    { "host_register_well_known_mach_voucher_attr_manager", 224 },\
    { "host_set_atm_diagnostic_flag", 225 },\
    { "host_get_atm_diagnostic_flag", 226 },\
    { "mach_memory_info", 227 },\
    { "host_set_multiuser_config_flags", 228 },\
    { "host_get_multiuser_config_flags", 229 },\
    { "host_check_multiuser_mode", 230 },\
    { "mach_zone_info_for_zone", 231 }
#endif

#ifdef __AfterMigUserHeader
__AfterMigUserHeader
#endif /* __AfterMigUserHeader */

#endif	 /* _mach_host_user_ */