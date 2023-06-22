/* SPDX-License-Identifier: GPL-2.0-only WITH Linux-syscall-note */
/*
 * Copyright (C) 2020-2023 Intel Corporation
 */

#ifndef __UAPI_IVPU_DRM_H__
#define __UAPI_IVPU_DRM_H__

#include "drm.h"

#if defined(__cplusplus)
extern "C" {
#endif

#define DRM_IVPU_DRIVER_MAJOR 1
#define DRM_IVPU_DRIVER_MINOR 0

#define DRM_IVPU_GET_PARAM		  0x00
#define DRM_IVPU_SET_PARAM		  0x01
#define DRM_IVPU_BO_CREATE		  0x02
#define DRM_IVPU_BO_INFO		  0x03
#define DRM_IVPU_SUBMIT			  0x05
#define DRM_IVPU_BO_WAIT		  0x06

#define DRM_IOCTL_IVPU_GET_PARAM                                               \
	DRM_IOWR(DRM_COMMAND_BASE + DRM_IVPU_GET_PARAM, struct drm_ivpu_param)

#define DRM_IOCTL_IVPU_SET_PARAM                                               \
	DRM_IOW(DRM_COMMAND_BASE + DRM_IVPU_SET_PARAM, struct drm_ivpu_param)

#define DRM_IOCTL_IVPU_BO_CREATE                                               \
	DRM_IOWR(DRM_COMMAND_BASE + DRM_IVPU_BO_CREATE, struct drm_ivpu_bo_create)

#define DRM_IOCTL_IVPU_BO_INFO                                                 \
	DRM_IOWR(DRM_COMMAND_BASE + DRM_IVPU_BO_INFO, struct drm_ivpu_bo_info)

#define DRM_IOCTL_IVPU_SUBMIT                                                  \
	DRM_IOW(DRM_COMMAND_BASE + DRM_IVPU_SUBMIT, struct drm_ivpu_submit)

#define DRM_IOCTL_IVPU_BO_WAIT                                                 \
	DRM_IOWR(DRM_COMMAND_BASE + DRM_IVPU_BO_WAIT, struct drm_ivpu_bo_wait)

/**
 * DOC: contexts
 *
 * VPU contexts have private virtual address space, job queues and priority.
 * Each context is identified by an unique ID. Context is created on open().
 */

#define DRM_IVPU_PARAM_DEVICE_ID	    0
#define DRM_IVPU_PARAM_DEVICE_REVISION	    1
#define DRM_IVPU_PARAM_PLATFORM_TYPE	    2
#define DRM_IVPU_PARAM_CORE_CLOCK_RATE	    3
#define DRM_IVPU_PARAM_NUM_CONTEXTS	    4
#define DRM_IVPU_PARAM_CONTEXT_BASE_ADDRESS 5
#define DRM_IVPU_PARAM_CONTEXT_PRIORITY	    6
#define DRM_IVPU_PARAM_CONTEXT_ID	    7
#define DRM_IVPU_PARAM_FW_API_VERSION	    8
#define DRM_IVPU_PARAM_ENGINE_HEARTBEAT	    9
#define DRM_IVPU_PARAM_UNIQUE_INFERENCE_ID  10
#define DRM_IVPU_PARAM_TILE_CONFIG	    11
#define DRM_IVPU_PARAM_SKU		    12

#define DRM_IVPU_PLATFORM_TYPE_SILICON	    0

#define DRM_IVPU_CONTEXT_PRIORITY_IDLE	    0
#define DRM_IVPU_CONTEXT_PRIORITY_NORMAL    1
#define DRM_IVPU_CONTEXT_PRIORITY_FOCUS	    2
#define DRM_IVPU_CONTEXT_PRIORITY_REALTIME  3

/**
 * struct drm_ivpu_param - Get/Set VPU parameters
 */
struct drm_ivpu_param {
	/**
	 * @param:
	 *
	 * Supported params:
	 *
	 * %DRM_IVPU_PARAM_DEVICE_ID:
	 * PCI Device ID of the VPU device (read-only)
	 *
	 * %DRM_IVPU_PARAM_DEVICE_REVISION:
	 * VPU device revision (read-only)
	 *
	 * %DRM_IVPU_PARAM_PLATFORM_TYPE:
	 * Returns %DRM_IVPU_PLATFORM_TYPE_SILICON on real hardware or device specific
	 * platform type when executing on a simulator or emulator (read-only)
	 *
	 * %DRM_IVPU_PARAM_CORE_CLOCK_RATE:
	 * Current PLL frequency (read-only)
	 *
	 * %DRM_IVPU_PARAM_NUM_CONTEXTS:
	 * Maximum number of simultaneously existing contexts (read-only)
	 *
	 * %DRM_IVPU_PARAM_CONTEXT_BASE_ADDRESS:
	 * Lowest VPU virtual address available in the current context (read-only)
	 *
	 * %DRM_IVPU_PARAM_CONTEXT_PRIORITY:
	 * Value of current context scheduling priority (read-write).
	 * See DRM_IVPU_CONTEXT_PRIORITY_* for possible values.
	 *
	 * %DRM_IVPU_PARAM_CONTEXT_ID:
	 * Current context ID, always greater than 0 (read-only)
	 *
	 * %DRM_IVPU_PARAM_FW_API_VERSION:
	 * Firmware API version array (read-only)
	 *
	 * %DRM_IVPU_PARAM_ENGINE_HEARTBEAT:
	 * Heartbeat value from an engine (read-only).
	 * Engine ID (i.e. DRM_IVPU_ENGINE_COMPUTE) is given via index.
	 *
	 * %DRM_IVPU_PARAM_UNIQUE_INFERENCE_ID:
	 * Device-unique inference ID (read-only)
	 *
	 * %DRM_IVPU_PARAM_TILE_CONFIG:
	 * VPU tile configuration  (read-only)
	 *
	 * %DRM_IVPU_PARAM_SKU:
	 * VPU SKU ID (read-only)
	 *
	 */
	__u32 param;

	/** @index: Index for params that have multiple instances */
	__u32 index;

	/** @value: Param value */
	__u64 value;
};

#define DRM_IVPU_BO_HIGH_MEM   0x00000001
#define DRM_IVPU_BO_MAPPABLE   0x00000002

#define DRM_IVPU_BO_CACHED     0x00000000
#define DRM_IVPU_BO_UNCACHED   0x00010000
#define DRM_IVPU_BO_WC	       0x00020000
#define DRM_IVPU_BO_CACHE_MASK 0x00030000

#define DRM_IVPU_BO_FLAGS \
	(DRM_IVPU_BO_HIGH_MEM | \
	 DRM_IVPU_BO_MAPPABLE | \
	 DRM_IVPU_BO_CACHE_MASK)

/**
 * struct drm_ivpu_bo_create - Create BO backed by SHMEM
 *
 * Create GEM buffer object allocated in SHMEM memory.
 */
struct drm_ivpu_bo_create {
	/** @size: The size in bytes of the allocated memory */
	__u64 size;

	/**
	 * @flags:
	 *
	 * Supported flags:
	 *
	 * %DRM_IVPU_BO_HIGH_MEM:
	 *
	 * Allocate VPU address from >4GB range.
	 * Buffer object with vpu address >4GB can be always accessed by the
	 * VPU DMA engine, but some HW generation may not be able to access
	 * this memory from then firmware running on the VPU management processor.
	 * Suitable for input, output and some scratch buffers.
	 *
	 * %DRM_IVPU_BO_MAPPABLE:
	 *
	 * Buffer object can be mapped using mmap().
	 *
	 * %DRM_IVPU_BO_CACHED:
	 *
	 * Allocated BO will be cached on host side (WB) and snooped on the VPU side.
	 * This is the default caching mode.
	 *
	 * %DRM_IVPU_BO_UNCACHED:
	 *
	 * Allocated BO will not be cached on host side nor snooped on the VPU side.
	 *
	 * %DRM_IVPU_BO_WC:
	 *
	 * Allocated BO will use write combining buffer for writes but reads will be
	 * uncached.
	 */
	__u32 flags;

	/** @handle: Returned GEM object handle */
	__u32 handle;

	/** @vpu_addr: Returned VPU virtual address */
	__u64 vpu_addr;
};

/**
 * struct drm_ivpu_bo_info - Query buffer object info
 */
struct drm_ivpu_bo_info {
	/** @handle: Handle of the queried BO */
	__u32 handle;

	/** @flags: Returned flags used to create the BO */
	__u32 flags;

	/** @vpu_addr: Returned VPU virtual address */
	__u64 vpu_addr;

	/**
	 * @mmap_offset:
	 *
	 * Returned offset to be used in mmap(). 0 in case the BO is not mappable.
	 */
	__u64 mmap_offset;

	/** @size: Returned GEM object size, aligned to PAGE_SIZE */
	__u64 size;
};

/* drm_ivpu_submit engines */
#define DRM_IVPU_ENGINE_COMPUTE 0
#define DRM_IVPU_ENGINE_COPY    1

/**
 * struct drm_ivpu_submit - Submit commands to the VPU
 *
 * Execute a single command buffer on a given VPU engine.
 * Handles to all referenced buffer objects have to be provided in @buffers_ptr.
 *
 * User space may wait on job completion using %DRM_IVPU_BO_WAIT ioctl.
 */
struct drm_ivpu_submit {
	/**
	 * @buffers_ptr:
	 *
	 * A pointer to an u32 array of GEM handles of the BOs required for this job.
	 * The number of elements in the array must be equal to the value given by @buffer_count.
	 *
	 * The first BO is the command buffer. The rest of array has to contain all
	 * BOs referenced from the command buffer.
	 */
	__u64 buffers_ptr;

	/** @buffer_count: Number of elements in the @buffers_ptr */
	__u32 buffer_count;

	/**
	 * @engine: Select the engine this job should be executed on
	 *
	 * %DRM_IVPU_ENGINE_COMPUTE:
	 *
	 * Performs Deep Learning Neural Compute Inference Operations
	 *
	 * %DRM_IVPU_ENGINE_COPY:
	 *
	 * Performs memory copy operations to/from system memory allocated for VPU
	 */
	__u32 engine;

	/** @flags: Reserved for future use - must be zero */
	__u32 flags;

	/**
	 * @commands_offset:
	 *
	 * Offset inside the first buffer in @buffers_ptr containing commands
	 * to be executed. The offset has to be 8-byte aligned.
	 */
	__u32 commands_offset;
};

/* drm_ivpu_bo_wait job status codes */
#define DRM_IVPU_JOB_STATUS_SUCCESS 0

/**
 * struct drm_ivpu_bo_wait - Wait for BO to become inactive
 *
 * Blocks until a given buffer object becomes inactive.
 * With @timeout_ms set to 0 returns immediately.
 */
struct drm_ivpu_bo_wait {
	/** @handle: Handle to the buffer object to be waited on */
	__u32 handle;

	/** @flags: Reserved for future use - must be zero */
	__u32 flags;

	/** @timeout_ns: Absolute timeout in nanoseconds (may be zero) */
	__s64 timeout_ns;

	/**
	 * @job_status:
	 *
	 * Job status code which is updated after the job is completed.
	 * &DRM_IVPU_JOB_STATUS_SUCCESS or device specific error otherwise.
	 * Valid only if @handle points to a command buffer.
	 */
	__u32 job_status;

	/** @pad: Padding - must be zero */
	__u32 pad;
};

#if defined(__cplusplus)
}
#endif

#endif /* __UAPI_IVPU_DRM_H__ */