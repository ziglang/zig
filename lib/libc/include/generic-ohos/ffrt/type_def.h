/*
 * Copyright (c) 2023 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/**
 * @addtogroup Ffrt
 * @{
 *
 * @brief ffrt provides APIs.
 *
 *
 * @syscap SystemCapability.Resourceschedule.Ffrt.Core
 *
 * @since 10
 */

 /**
 * @file type_def.h
 *
 * @brief Declares common types.
 *
 * @syscap SystemCapability.Resourceschedule.Ffrt.Core
 * @since 10
 * @version 1.0
 */
#ifndef FFRT_API_C_TYPE_DEF_H
#define FFRT_API_C_TYPE_DEF_H
#include <stdint.h>
#include <errno.h>

#ifdef __cplusplus
#define FFRT_C_API  extern "C"
#else
#define FFRT_C_API
#endif

/**
 * @brief Enumerates the task priority types.
 *
 */
typedef enum {
    /** should be distributed at once if possible, handle time equals to send time, prior to high level */
    ffrt_queue_priority_immediate,
    /** high priority, sorted by handle time, prior to low level. */
    ffrt_queue_priority_high,
    /** low priority, sorted by handle time, prior to idle level. */
    ffrt_queue_priority_low,
    /** lowest priority, sorted by handle time, only distribute when there is no other level inside queue. */
    ffrt_queue_priority_idle,
} ffrt_queue_priority_t;

/**
 * @brief Enumerates the task QoS types.
 *
 */
typedef enum {
    /** Inheritance. */
    ffrt_qos_inherit = -1,
    /** Background task. */
    ffrt_qos_background,
    /** Real-time tool. */
    ffrt_qos_utility,
    /** Default type. */
    ffrt_qos_default,
    /** User initiated. */
    ffrt_qos_user_initiated,
} ffrt_qos_default_t;
typedef int ffrt_qos_t;

typedef void(*ffrt_function_t)(void*);

/**
 * @brief Defines a task executor.
 *
 */
typedef struct {
    /** Function used to execute a task. */
    ffrt_function_t exec;
    /** Function used to destroy a task. */
    ffrt_function_t destroy;
    /** Need to be set to 0. */
    uint64_t reserve[2];
} ffrt_function_header_t;

/**
 * @brief Defines the storage size of multiple types of structs.
 *
 */
typedef enum {
    /** Task attribute storage size. */
    ffrt_task_attr_storage_size = 128,
    /** Task executor storage size. */
    ffrt_auto_managed_function_storage_size = 64 + sizeof(ffrt_function_header_t),
    /* Mutex storage size. */
    ffrt_mutex_storage_size = 64,
    /** Condition variable storage size. */
    ffrt_cond_storage_size = 64,
    /** Queue storage size. */
    ffrt_queue_attr_storage_size = 128,
} ffrt_storage_size_t;

/**
 * @brief Enumerates the task types.
 *
 */
typedef enum {
    /** General task. */
    ffrt_function_kind_general,
    /** Queue task. */
    ffrt_function_kind_queue,
} ffrt_function_kind_t;

/**
 * @brief dependency type.
 *
 */
typedef enum {
    /** Data dependency type. */
    ffrt_dependence_data,
    /** Task dependency type. */
    ffrt_dependence_task,
} ffrt_dependence_type_t;

/**
 * @brief dependency data structure.
 *
 */
typedef struct {
    /** Dependency type. */
    ffrt_dependence_type_t type;
    /** Dependency pointer. */
    const void* ptr;
} ffrt_dependence_t;

/**
 * @brief Defines the dependency struct.
 *
 */
typedef struct {
    /** Number of dependencies. */
    uint32_t len;
    /** Dependent data. */
    const ffrt_dependence_t* items;
} ffrt_deps_t;

typedef struct {
    uint32_t storage[(ffrt_task_attr_storage_size + sizeof(uint32_t) - 1) / sizeof(uint32_t)];
} ffrt_task_attr_t;

typedef struct {
    uint32_t storage[(ffrt_queue_attr_storage_size + sizeof(uint32_t) - 1) / sizeof(uint32_t)];
} ffrt_queue_attr_t;

typedef void* ffrt_task_handle_t;

typedef enum {
    ffrt_error = -1,
    ffrt_success = 0,
    ffrt_error_nomem = ENOMEM,
    ffrt_error_timedout = ETIMEDOUT,
    ffrt_error_busy = EBUSY,
    ffrt_error_inval = EINVAL
} ffrt_error_t;

typedef struct {
    long storage;
} ffrt_condattr_t;

typedef struct {
    long storage;
} ffrt_mutexattr_t;

typedef struct {
    uint32_t storage[(ffrt_mutex_storage_size + sizeof(uint32_t) - 1) / sizeof(uint32_t)];
} ffrt_mutex_t;

typedef struct {
    uint32_t storage[(ffrt_cond_storage_size + sizeof(uint32_t) - 1) / sizeof(uint32_t)];
} ffrt_cond_t;

typedef void (*ffrt_poller_cb)(void* data, uint32_t event);

typedef void (*ffrt_timer_cb)(void* data);

typedef int ffrt_timer_t;


#ifdef __cplusplus
namespace ffrt {
enum qos_default {
    qos_inherit = ffrt_qos_inherit,
    qos_background = ffrt_qos_background,
    qos_utility = ffrt_qos_utility,
    qos_default = ffrt_qos_default,
    qos_user_initiated = ffrt_qos_user_initiated,
};
using qos = int;

}
#endif
#endif