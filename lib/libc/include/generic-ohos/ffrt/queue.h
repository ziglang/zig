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
 * @file queue.h
 *
 * @brief Declares the queue interfaces in C.
 *
 * @syscap SystemCapability.Resourceschedule.Ffrt.Core
 * @since 10
 * @version 1.0
 */
#ifndef FFRT_API_C_QUEUE_H
#define FFRT_API_C_QUEUE_H

#include "type_def.h"

typedef enum {
    ffrt_queue_serial,
    ffrt_queue_concurrent,
    ffrt_queue_max
} ffrt_queue_type_t;

typedef void* ffrt_queue_t;

/**
 * @brief Initializes the queue attribute.
 *
 * @param attr Indicates a pointer to the queue attribute.
 * @return Returns <b>0</b> if the queue attribute is initialized;
           returns <b>-1</b> otherwise.
 * @since 10
 * @version 1.0
 */
FFRT_C_API int ffrt_queue_attr_init(ffrt_queue_attr_t* attr);

/**
 * @brief Destroys a queue attribute.
 *
 * @param attr Indicates a pointer to the queue attribute.
 * @since 10
 * @version 1.0
 */
FFRT_C_API void ffrt_queue_attr_destroy(ffrt_queue_attr_t* attr);

/**
 * @brief Sets the QoS for a queue attribute.
 *
 * @param attr Indicates a pointer to the queue attribute.
 * @param attr Indicates the QoS.
 * @since 10
 * @version 1.0
 */
FFRT_C_API void ffrt_queue_attr_set_qos(ffrt_queue_attr_t* attr, ffrt_qos_t qos);

/**
 * @brief Obtains the QoS of a queue attribute.
 *
 * @param attr Indicates a pointer to the queue attribute.
 * @return Returns the QoS.
 * @since 10
 * @version 1.0
 */
FFRT_C_API ffrt_qos_t ffrt_queue_attr_get_qos(const ffrt_queue_attr_t* attr);

/**
 * @brief Set the serial queue task execution timeout.
 *
 * @param attr Serial Queue Property Pointer.
 * @param timeout_us Serial queue task execution timeout.
 * @since 10
 * @version 1.0
 */
FFRT_C_API void ffrt_queue_attr_set_timeout(ffrt_queue_attr_t* attr, uint64_t timeout_us);

/**
 * @brief Get the serial queue task execution timeout.
 *
 * @param attr Serial Queue Property Pointer.
 * @return Returns the serial queue task execution timeout.
 * @since 10
 * @version 1.0
 */
FFRT_C_API uint64_t ffrt_queue_attr_get_timeout(const ffrt_queue_attr_t* attr);

/**
 * @brief Set the serial queue timeout callback function.
 *
 * @param attr Serial Queue Property Pointer.
 * @param f Serial queue timeout callback function.
 * @since 10
 * @version 1.0
 */
FFRT_C_API void ffrt_queue_attr_set_callback(ffrt_queue_attr_t* attr, ffrt_function_header_t* f);

/**
 * @brief Get the serial queue task timeout callback function.
 *
 * @param attr Serial Queue Property Pointer.
 * @return Returns the serial queue task timeout callback function.
 * @since 10
 * @version 1.0
 */
FFRT_C_API ffrt_function_header_t* ffrt_queue_attr_get_callback(const ffrt_queue_attr_t* attr);

/**
 * @brief Set the queue max concurrency.
 *
 * @param attr Queue Property Pointer.
 * @param max_concurrency queue max_concurrency.
 * @since 12
 * @version 1.0
 */
FFRT_C_API void ffrt_queue_attr_set_max_concurrency(ffrt_queue_attr_t* attr, const int max_concurrency);

/**
 * @brief Get the queue max concurrency.
 *
 * @param attr Queue Property Pointer.
 * @return Returns the queue max concurrency.
 * @since 12
 * @version 1.0
 */
FFRT_C_API int ffrt_queue_attr_get_max_concurrency(const ffrt_queue_attr_t* attr);

/**
 * @brief Creates a queue.
 *
 * @param type Indicates the queue type.
 * @param name Indicates a pointer to the queue name.
 * @param attr Indicates a pointer to the queue attribute.
 * @return Returns a non-null queue handle if the queue is created;
           returns a null pointer otherwise.
 * @since 10
 * @version 1.0
 */
FFRT_C_API ffrt_queue_t ffrt_queue_create(ffrt_queue_type_t type, const char* name, const ffrt_queue_attr_t* attr);

/**
 * @brief Destroys a queue.
 *
 * @param queue Indicates a queue handle.
 * @since 10
 * @version 1.0
 */
FFRT_C_API void ffrt_queue_destroy(ffrt_queue_t queue);

/**
 * @brief Submits a task to a queue.
 *
 * @param queue Indicates a queue handle.
 * @param f Indicates a pointer to the task executor.
 * @param attr Indicates a pointer to the task attribute.
 * @since 10
 * @version 1.0
 */
FFRT_C_API void ffrt_queue_submit(ffrt_queue_t queue, ffrt_function_header_t* f, const ffrt_task_attr_t* attr);

/**
 * @brief Submits a task to the queue, and obtains a task handle.
 *
 * @param queue Indicates a queue handle.
 * @param f Indicates a pointer to the task executor.
 * @param attr Indicates a pointer to the task attribute.
 * @return Returns a non-null task handle if the task is submitted;
           returns a null pointer otherwise.
 * @since 10
 * @version 1.0
 */
FFRT_C_API ffrt_task_handle_t ffrt_queue_submit_h(
    ffrt_queue_t queue, ffrt_function_header_t* f, const ffrt_task_attr_t* attr);

/**
 * @brief Waits until a task in the queue is complete.
 *
 * @param handle Indicates a task handle.
 * @since 10
 * @version 1.0
 */
FFRT_C_API void ffrt_queue_wait(ffrt_task_handle_t handle);

/**
 * @brief Cancels a task in the queue.
 *
 * @param handle Indicates a task handle.
 * @return Returns <b>0</b> if the task is canceled;
           returns <b>-1</b> otherwise.
 * @since 10
 * @version 1.0
 */
FFRT_C_API int ffrt_queue_cancel(ffrt_task_handle_t handle);

/**
 * @brief Get application main thread queue.
 *
 * @return Returns application main thread queue.
 * @since 12
 * @version 1.0
 */
FFRT_C_API ffrt_queue_t ffrt_get_main_queue();

/**
 * @brief Get application worker(ArkTs) thread queue.
 *
 * @return Returns application worker(ArkTs) thread queue.
 * @since 12
 * @version 1.0
 */
FFRT_C_API ffrt_queue_t ffrt_get_current_queue();

#endif // FFRT_API_C_QUEUE_H