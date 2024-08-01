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
 * @file task.h
 * @kit FunctionFlowRuntimeKit
 *
 * @brief Declares the task interfaces in C.
 *
 * @syscap SystemCapability.Resourceschedule.Ffrt.Core
 * @since 10
 * @version 1.0
 */
#ifndef FFRT_API_C_TASK_H
#define FFRT_API_C_TASK_H
#include <stdint.h>
#include "type_def.h"

/**
 * @brief Initializes a task attribute.
 *
 * @param attr Indicates a pointer to the task attribute.
 * @return Returns <b>0</b> if the task attribute is initialized;
           returns <b>-1</b> otherwise.
 * @since 10
 * @version 1.0
 */
FFRT_C_API int ffrt_task_attr_init(ffrt_task_attr_t* attr);

/**
 * @brief Sets a task name.
 *
 * @param attr Indicates a pointer to the task attribute.
 * @param name Indicates a pointer to the task name.
 * @since 10
 * @version 1.0
 */
FFRT_C_API void ffrt_task_attr_set_name(ffrt_task_attr_t* attr, const char* name);

/**
 * @brief Obtains a task name.
 *
 * @param attr Indicates a pointer to the task attribute.
 * @return Returns a non-null pointer to the task name if the name is obtained;
           returns a null pointer otherwise.
 * @since 10
 * @version 1.0
 */
FFRT_C_API const char* ffrt_task_attr_get_name(const ffrt_task_attr_t* attr);

/**
 * @brief Destroys a task attribute.
 *
 * @param attr Indicates a pointer to the task attribute.
 * @since 10
 * @version 1.0
 */
FFRT_C_API void ffrt_task_attr_destroy(ffrt_task_attr_t* attr);

/**
 * @brief Sets the QoS for a task attribute.
 *
 * @param attr Indicates a pointer to the task attribute.
 * @param qos Indicates the QoS.
 * @since 10
 * @version 1.0
 */
FFRT_C_API void ffrt_task_attr_set_qos(ffrt_task_attr_t* attr, ffrt_qos_t qos);

/**
 * @brief Obtains the QoS of a task attribute.
 *
 * @param attr Indicates a pointer to the task attribute.
 * @return Returns the QoS, which is <b>ffrt_qos_default</b> by default.
 * @since 10
 * @version 1.0
 */
FFRT_C_API ffrt_qos_t ffrt_task_attr_get_qos(const ffrt_task_attr_t* attr);

/**
 * @brief Sets the task delay time.
 *
 * @param attr Indicates a pointer to the task attribute.
 * @param delay_us Indicates the delay time, in microseconds.
 * @since 10
 * @version 1.0
 */
FFRT_C_API void ffrt_task_attr_set_delay(ffrt_task_attr_t* attr, uint64_t delay_us);

/**
 * @brief Obtains the task delay time.
 *
 * @param attr Indicates a pointer to the task attribute.
 * @return Returns the delay time.
 * @since 10
 * @version 1.0
 */
FFRT_C_API uint64_t ffrt_task_attr_get_delay(const ffrt_task_attr_t* attr);

/**
 * @brief Sets the task priority.
 *
 * @param attr Indicates a pointer to the task attribute.
 * @param priority Indicates the execute priority of concurrent queue task.
 * @since 12
 * @version 1.0
 */
FFRT_C_API void ffrt_task_attr_set_queue_priority(ffrt_task_attr_t* attr, ffrt_queue_priority_t priority);

/**
 * @brief Obtains the task priority.
 *
 * @param attr Indicates a pointer to the task attribute.
 * @return Returns the priority of concurrent queue task.
 * @since 12
 * @version 1.0
 */
FFRT_C_API ffrt_queue_priority_t ffrt_task_attr_get_queue_priority(const ffrt_task_attr_t* attr);

/**
 * @brief Updates the QoS of this task.
 *
 * @param qos Indicates the new QoS.
 * @return Returns <b>0</b> if the QoS is updated;
           returns <b>-1</b> otherwise.
 * @since 10
 * @version 1.0
 */
FFRT_C_API int ffrt_this_task_update_qos(ffrt_qos_t qos);

/**
 * @brief Obtains the qos of this task.
 *
 * @return Returns the task qos.
 * @since 12
 * @version 1.0
 */
FFRT_C_API ffrt_qos_t ffrt_this_task_get_qos();

/**
 * @brief Obtains the ID of this task.
 *
 * @return Returns the task ID.
 * @since 10
 * @version 1.0
 */
FFRT_C_API uint64_t ffrt_this_task_get_id(void);

/**
 * @brief Applies for memory for the function execution structure.
 *
 * @param kind Indicates the type of the function execution structure, which can be common or queue.
 * @return Returns a non-null pointer if the memory is allocated;
           returns a null pointer otherwise.
 * @since 10
 * @version 1.0
 */
FFRT_C_API void *ffrt_alloc_auto_managed_function_storage_base(ffrt_function_kind_t kind);

/**
 * @brief Submits a task.
 *
 * @param f Indicates a pointer to the task executor.
 * @param in_deps Indicates a pointer to the input dependencies.
 * @param out_deps Indicates a pointer to the output dependencies.
 * @param attr Indicates a pointer to the task attribute.
 * @since 10
 * @version 1.0
 */
FFRT_C_API void ffrt_submit_base(ffrt_function_header_t* f, const ffrt_deps_t* in_deps, const ffrt_deps_t* out_deps,
    const ffrt_task_attr_t* attr);

/**
 * @brief Submits a task, and obtains a task handle.
 *
 * @param f Indicates a pointer to the task executor.
 * @param in_deps Indicates a pointer to the input dependencies.
 * @param out_deps Indicates a pointer to the output dependencies.
 * @param attr Indicates a pointer to the task attribute.
 * @return Returns a non-null task handle if the task is submitted;
           returns a null pointer otherwise.
 * @since 10
 * @version 1.0
 */
FFRT_C_API ffrt_task_handle_t ffrt_submit_h_base(ffrt_function_header_t* f, const ffrt_deps_t* in_deps,
    const ffrt_deps_t* out_deps, const ffrt_task_attr_t* attr);

/**
 * @brief Destroys a task handle.
 *
 * @param handle Indicates a task handle.
 * @since 10
 * @version 1.0
 */
FFRT_C_API void ffrt_task_handle_destroy(ffrt_task_handle_t handle);

/**
 * @brief Waits until the dependent tasks are complete.
 *
 * @param deps Indicates a pointer to the dependent tasks.
 * @since 10
 * @version 1.0
 */
FFRT_C_API void ffrt_wait_deps(const ffrt_deps_t* deps);

/**
 * @brief Waits until all submitted tasks are complete.
 *
 * @since 10
 * @version 1.0
 */
FFRT_C_API void ffrt_wait(void);

#endif