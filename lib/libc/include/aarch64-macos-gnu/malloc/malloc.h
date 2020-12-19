/*
 * Copyright (c) 1999 Apple Computer, Inc. All rights reserved.
 *
 * @APPLE_LICENSE_HEADER_START@
 * 
 * This file contains Original Code and/or Modifications of Original Code
 * as defined in and that are subject to the Apple Public Source License
 * Version 2.0 (the 'License'). You may not use this file except in
 * compliance with the License. Please obtain a copy of the License at
 * http://www.opensource.apple.com/apsl/ and read it before using this
 * file.
 * 
 * The Original Code and all software distributed under the License are
 * distributed on an 'AS IS' basis, WITHOUT WARRANTY OF ANY KIND, EITHER
 * EXPRESS OR IMPLIED, AND APPLE HEREBY DISCLAIMS ALL SUCH WARRANTIES,
 * INCLUDING WITHOUT LIMITATION, ANY WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE, QUIET ENJOYMENT OR NON-INFRINGEMENT.
 * Please see the License for the specific language governing rights and
 * limitations under the License.
 * 
 * @APPLE_LICENSE_HEADER_END@
 */

#ifndef _MALLOC_MALLOC_H_
#define _MALLOC_MALLOC_H_

#include <stddef.h>
#include <mach/mach_types.h>
#include <sys/cdefs.h>
#include <Availability.h>

#if __has_feature(ptrauth_calls)
#include <ptrauth.h>

// Zone function pointer, type-diversified but not address-diversified (because
// the zone can be copied). Process-independent because the zone structure may
// be in the shared library cache.
#define MALLOC_ZONE_FN_PTR(fn) __ptrauth(ptrauth_key_process_independent_code, \
		FALSE, ptrauth_string_discriminator("malloc_zone_fn." #fn)) fn

// Introspection function pointer, address- and type-diversified.
// Process-independent because the malloc_introspection_t structure that contains
// these pointers may be in the shared library cache.
#define MALLOC_INTROSPECT_FN_PTR(fn) __ptrauth(ptrauth_key_process_independent_code, \
		TRUE, ptrauth_string_discriminator("malloc_introspect_fn." #fn)) fn

// Pointer to the introspection pointer table, type-diversified but not
// address-diversified (because the zone can be copied).
// Process-independent because the table pointer may be in the shared library cache.
#define MALLOC_INTROSPECT_TBL_PTR(ptr) __ptrauth(ptrauth_key_process_independent_data,\
		FALSE, ptrauth_string_discriminator("malloc_introspect_tbl")) ptr

#endif	// __has_feature(ptrauth_calls)

#ifndef MALLOC_ZONE_FN_PTR
#define MALLOC_ZONE_FN_PTR(fn) fn
#define MALLOC_INTROSPECT_FN_PTR(fn) fn
#define MALLOC_INTROSPECT_TBL_PTR(ptr) ptr
#endif // MALLOC_ZONE_FN_PTR

__BEGIN_DECLS
/*********	Type definitions	************/

typedef struct _malloc_zone_t {
    /* Only zone implementors should depend on the layout of this structure;
    Regular callers should use the access functions below */
    void	*reserved1;	/* RESERVED FOR CFAllocator DO NOT USE */
    void	*reserved2;	/* RESERVED FOR CFAllocator DO NOT USE */
    size_t 	(* MALLOC_ZONE_FN_PTR(size))(struct _malloc_zone_t *zone, const void *ptr); /* returns the size of a block or 0 if not in this zone; must be fast, especially for negative answers */
    void 	*(* MALLOC_ZONE_FN_PTR(malloc))(struct _malloc_zone_t *zone, size_t size);
    void 	*(* MALLOC_ZONE_FN_PTR(calloc))(struct _malloc_zone_t *zone, size_t num_items, size_t size); /* same as malloc, but block returned is set to zero */
    void 	*(* MALLOC_ZONE_FN_PTR(valloc))(struct _malloc_zone_t *zone, size_t size); /* same as malloc, but block returned is set to zero and is guaranteed to be page aligned */
    void 	(* MALLOC_ZONE_FN_PTR(free))(struct _malloc_zone_t *zone, void *ptr);
    void 	*(* MALLOC_ZONE_FN_PTR(realloc))(struct _malloc_zone_t *zone, void *ptr, size_t size);
    void 	(* MALLOC_ZONE_FN_PTR(destroy))(struct _malloc_zone_t *zone); /* zone is destroyed and all memory reclaimed */
    const char	*zone_name;

    /* Optional batch callbacks; these may be NULL */
    unsigned	(* MALLOC_ZONE_FN_PTR(batch_malloc))(struct _malloc_zone_t *zone, size_t size, void **results, unsigned num_requested); /* given a size, returns pointers capable of holding that size; returns the number of pointers allocated (maybe 0 or less than num_requested) */
    void	(* MALLOC_ZONE_FN_PTR(batch_free))(struct _malloc_zone_t *zone, void **to_be_freed, unsigned num_to_be_freed); /* frees all the pointers in to_be_freed; note that to_be_freed may be overwritten during the process */

    struct malloc_introspection_t	* MALLOC_INTROSPECT_TBL_PTR(introspect);
    unsigned	version;
    	
    /* aligned memory allocation. The callback may be NULL. Present in version >= 5. */
    void *(* MALLOC_ZONE_FN_PTR(memalign))(struct _malloc_zone_t *zone, size_t alignment, size_t size);
    
    /* free a pointer known to be in zone and known to have the given size. The callback may be NULL. Present in version >= 6.*/
    void (* MALLOC_ZONE_FN_PTR(free_definite_size))(struct _malloc_zone_t *zone, void *ptr, size_t size);

    /* Empty out caches in the face of memory pressure. The callback may be NULL. Present in version >= 8. */
    size_t 	(* MALLOC_ZONE_FN_PTR(pressure_relief))(struct _malloc_zone_t *zone, size_t goal);

	/*
	 * Checks whether an address might belong to the zone. May be NULL. Present in version >= 10.
	 * False positives are allowed (e.g. the pointer was freed, or it's in zone space that has
	 * not yet been allocated. False negatives are not allowed.
	 */
    boolean_t (* MALLOC_ZONE_FN_PTR(claimed_address))(struct _malloc_zone_t *zone, void *ptr);
} malloc_zone_t;

/*********	Creation and destruction	************/

extern malloc_zone_t *malloc_default_zone(void);
    /* The initial zone */

extern malloc_zone_t *malloc_create_zone(vm_size_t start_size, unsigned flags);
    /* Creates a new zone with default behavior and registers it */

extern void malloc_destroy_zone(malloc_zone_t *zone);
    /* Destroys zone and everything it allocated */

/*********	Block creation and manipulation	************/

extern void *malloc_zone_malloc(malloc_zone_t *zone, size_t size) __alloc_size(2);
    /* Allocates a new pointer of size size; zone must be non-NULL */

extern void *malloc_zone_calloc(malloc_zone_t *zone, size_t num_items, size_t size) __alloc_size(2,3);
    /* Allocates a new pointer of size num_items * size; block is cleared; zone must be non-NULL */

extern void *malloc_zone_valloc(malloc_zone_t *zone, size_t size) __alloc_size(2);
    /* Allocates a new pointer of size size; zone must be non-NULL; Pointer is guaranteed to be page-aligned and block is cleared */

extern void malloc_zone_free(malloc_zone_t *zone, void *ptr);
    /* Frees pointer in zone; zone must be non-NULL */

extern void *malloc_zone_realloc(malloc_zone_t *zone, void *ptr, size_t size) __alloc_size(3);
    /* Enlarges block if necessary; zone must be non-NULL */

extern malloc_zone_t *malloc_zone_from_ptr(const void *ptr);
    /* Returns the zone for a pointer, or NULL if not in any zone.
    The ptr must have been returned from a malloc or realloc call. */

extern size_t malloc_size(const void *ptr);
    /* Returns size of given ptr */

extern size_t malloc_good_size(size_t size);
    /* Returns number of bytes greater than or equal to size that can be allocated without padding */

extern void *malloc_zone_memalign(malloc_zone_t *zone, size_t alignment, size_t size) __alloc_size(3) __OSX_AVAILABLE_STARTING(__MAC_10_6, __IPHONE_3_0);
    /* 
     * Allocates a new pointer of size size whose address is an exact multiple of alignment.
     * alignment must be a power of two and at least as large as sizeof(void *).
     * zone must be non-NULL.
     */

/*********	Batch methods	************/

extern unsigned malloc_zone_batch_malloc(malloc_zone_t *zone, size_t size, void **results, unsigned num_requested);
    /* Allocates num blocks of the same size; Returns the number truly allocated (may be 0) */

extern void malloc_zone_batch_free(malloc_zone_t *zone, void **to_be_freed, unsigned num);
    /* frees all the pointers in to_be_freed; note that to_be_freed may be overwritten during the process; This function will always free even if the zone has no batch callback */

/*********	Functions for libcache	************/

extern malloc_zone_t *malloc_default_purgeable_zone(void) __OSX_AVAILABLE_STARTING(__MAC_10_6, __IPHONE_3_0);
    /* Returns a pointer to the default purgeable_zone. */

extern void malloc_make_purgeable(void *ptr) __OSX_AVAILABLE_STARTING(__MAC_10_6, __IPHONE_3_0);
    /* Make an allocation from the purgeable zone purgeable if possible.  */

extern int malloc_make_nonpurgeable(void *ptr) __OSX_AVAILABLE_STARTING(__MAC_10_6, __IPHONE_3_0);
    /* Makes an allocation from the purgeable zone nonpurgeable.
     * Returns zero if the contents were not purged since the last
     * call to malloc_make_purgeable, else returns non-zero. */

/*********	Functions for zone implementors	************/

extern void malloc_zone_register(malloc_zone_t *zone);
    /* Registers a custom malloc zone; Should typically be called after a 
     * malloc_zone_t has been filled in with custom methods by a client.  See
     * malloc_create_zone for creating additional malloc zones with the
     * default allocation and free behavior. */

extern void malloc_zone_unregister(malloc_zone_t *zone);
    /* De-registers a zone
    Should typically be called before calling the zone destruction routine */

extern void malloc_set_zone_name(malloc_zone_t *zone, const char *name);
    /* Sets the name of a zone */

extern const char *malloc_get_zone_name(malloc_zone_t *zone);
    /* Returns the name of a zone */

size_t malloc_zone_pressure_relief(malloc_zone_t *zone, size_t goal) __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_4_3);
    /* malloc_zone_pressure_relief() advises the malloc subsystem that the process is under memory pressure and 
     * that the subsystem should make its best effort towards releasing (i.e. munmap()-ing) "goal" bytes from "zone". 
     * If "goal" is passed as zero, the malloc subsystem will attempt to achieve maximal pressure relief in "zone". 
     * If "zone" is passed as NULL, all zones are examined for pressure relief opportunities. 
     * malloc_zone_pressure_relief() returns the number of bytes released. 
     */

typedef struct {
    vm_address_t	address;
    vm_size_t		size;
} vm_range_t;

typedef struct malloc_statistics_t {
    unsigned	blocks_in_use;
    size_t	size_in_use;
    size_t	max_size_in_use;	/* high water mark of touched memory */
    size_t	size_allocated;		/* reserved in memory */
} malloc_statistics_t;

typedef kern_return_t memory_reader_t(task_t remote_task, vm_address_t remote_address, vm_size_t size, void **local_memory);
    /* given a task, "reads" the memory at the given address and size
local_memory: set to a contiguous chunk of memory; validity of local_memory is assumed to be limited (until next call) */

#define MALLOC_PTR_IN_USE_RANGE_TYPE	1	/* for allocated pointers */
#define MALLOC_PTR_REGION_RANGE_TYPE	2	/* for region containing pointers */
#define MALLOC_ADMIN_REGION_RANGE_TYPE	4	/* for region used internally */
#define MALLOC_ZONE_SPECIFIC_FLAGS	0xff00	/* bits reserved for zone-specific purposes */

typedef void vm_range_recorder_t(task_t, void *, unsigned type, vm_range_t *, unsigned);
    /* given a task and context, "records" the specified addresses */

/* Print function for the print_task() operation. */
typedef void print_task_printer_t(const char *fmt, ...) __printflike(1,2);

typedef struct malloc_introspection_t {
	kern_return_t (* MALLOC_INTROSPECT_FN_PTR(enumerator))(task_t task, void *, unsigned type_mask, vm_address_t zone_address, memory_reader_t reader, vm_range_recorder_t recorder); /* enumerates all the malloc pointers in use */
	size_t	(* MALLOC_INTROSPECT_FN_PTR(good_size))(malloc_zone_t *zone, size_t size);
	boolean_t 	(* MALLOC_INTROSPECT_FN_PTR(check))(malloc_zone_t *zone); /* Consistency checker */
	void 	(* MALLOC_INTROSPECT_FN_PTR(print))(malloc_zone_t *zone, boolean_t verbose); /* Prints zone  */
	void	(* MALLOC_INTROSPECT_FN_PTR(log))(malloc_zone_t *zone, void *address); /* Enables logging of activity */
	void	(* MALLOC_INTROSPECT_FN_PTR(force_lock))(malloc_zone_t *zone); /* Forces locking zone */
	void	(* MALLOC_INTROSPECT_FN_PTR(force_unlock))(malloc_zone_t *zone); /* Forces unlocking zone */
	void	(* MALLOC_INTROSPECT_FN_PTR(statistics))(malloc_zone_t *zone, malloc_statistics_t *stats); /* Fills statistics */
	boolean_t   (* MALLOC_INTROSPECT_FN_PTR(zone_locked))(malloc_zone_t *zone); /* Are any zone locks held */

    /* Discharge checking. Present in version >= 7. */
	boolean_t	(* MALLOC_INTROSPECT_FN_PTR(enable_discharge_checking))(malloc_zone_t *zone);
	void	(* MALLOC_INTROSPECT_FN_PTR(disable_discharge_checking))(malloc_zone_t *zone);
	void	(* MALLOC_INTROSPECT_FN_PTR(discharge))(malloc_zone_t *zone, void *memory);
#ifdef __BLOCKS__
	void     (* MALLOC_INTROSPECT_FN_PTR(enumerate_discharged_pointers))(malloc_zone_t *zone, void (^report_discharged)(void *memory, void *info));
	#else
    void	*enumerate_unavailable_without_blocks;   
#endif /* __BLOCKS__ */
	void	(* MALLOC_INTROSPECT_FN_PTR(reinit_lock))(malloc_zone_t *zone); /* Reinitialize zone locks, called only from atfork_child handler. Present in version >= 9. */
	void	(* MALLOC_INTROSPECT_FN_PTR(print_task))(task_t task, unsigned level, vm_address_t zone_address, memory_reader_t reader, print_task_printer_t printer); /* debug print for another process. Present in version >= 11. */
	void (* MALLOC_INTROSPECT_FN_PTR(task_statistics))(task_t task, vm_address_t zone_address, memory_reader_t reader, malloc_statistics_t *stats); /* Present in version >= 12 */
} malloc_introspection_t;

// The value of "level" when passed to print_task() that corresponds to
// verbose passed to print()
#define MALLOC_VERBOSE_PRINT_LEVEL	2

extern void malloc_printf(const char *format, ...);
    /* Convenience for logging errors and warnings;
    No allocation is performed during execution of this function;
    Only understands usual %p %d %s formats, and %y that expresses a number of bytes (5b,10KB,1MB...)
    */

/*********	Functions for performance tools	************/

extern kern_return_t malloc_get_all_zones(task_t task, memory_reader_t reader, vm_address_t **addresses, unsigned *count);
    /* Fills addresses and count with the addresses of the zones in task;
    Note that the validity of the addresses returned correspond to the validity of the memory returned by reader */

/*********	Debug helpers	************/

extern void malloc_zone_print_ptr_info(void *ptr);
    /* print to stdout if this pointer is in the malloc heap, free status, and size */

extern boolean_t malloc_zone_check(malloc_zone_t *zone);
    /* Checks zone is well formed; if !zone, checks all zones */

extern void malloc_zone_print(malloc_zone_t *zone, boolean_t verbose);
    /* Prints summary on zone; if !zone, prints all zones */

extern void malloc_zone_statistics(malloc_zone_t *zone, malloc_statistics_t *stats);
    /* Fills statistics for zone; if !zone, sums up all zones */

extern void malloc_zone_log(malloc_zone_t *zone, void *address);
    /* Controls logging of all activity; if !zone, for all zones;
    If address==0 nothing is logged;
    If address==-1 all activity is logged;
    Else only the activity regarding address is logged */

struct mstats {
    size_t	bytes_total;
    size_t	chunks_used;
    size_t	bytes_used;
    size_t	chunks_free;
    size_t	bytes_free;
};

extern struct mstats mstats(void);

extern boolean_t malloc_zone_enable_discharge_checking(malloc_zone_t *zone) __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_4_3);
/* Increment the discharge checking enabled counter for a zone. Returns true if the zone supports checking, false if it does not. */

extern void malloc_zone_disable_discharge_checking(malloc_zone_t *zone) __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_4_3);
/* Decrement the discharge checking enabled counter for a zone. */

extern void malloc_zone_discharge(malloc_zone_t *zone, void *memory) __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_4_3);
/* Register memory that the programmer expects to be freed soon. 
   zone may be NULL in which case the zone is determined using malloc_zone_from_ptr(). 
   If discharge checking is off for the zone this function is a no-op. */
 
#ifdef __BLOCKS__
extern void malloc_zone_enumerate_discharged_pointers(malloc_zone_t *zone, void (^report_discharged)(void *memory, void *info)) __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_4_3);
/* Calls report_discharged for each block that was registered using malloc_zone_discharge() but has not yet been freed. 
   info is used to provide zone defined information about the memory block. 
   If zone is NULL then the enumeration covers all zones. */
#else
extern void malloc_zone_enumerate_discharged_pointers(malloc_zone_t *zone, void *) __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_4_3);
#endif /* __BLOCKS__ */

__END_DECLS

#endif /* _MALLOC_MALLOC_H_ */