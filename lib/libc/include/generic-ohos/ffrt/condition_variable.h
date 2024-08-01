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
 * @file condition_variable.h
 * @kit FunctionFlowRuntimeKit
 *
 * @brief Declares the condition variable interfaces in C.
 *
 * @syscap SystemCapability.Resourceschedule.Ffrt.Core
 * @since 10
 * @version 1.0
 */
#ifndef FFRT_API_C_CONDITION_VARIABLE_H
#define FFRT_API_C_CONDITION_VARIABLE_H
#include <time.h>
#include "type_def.h"

/**
 * @brief Initializes a condition variable.
 *
 * @param cond Indicates a pointer to the condition variable.
 * @param attr Indicates a pointer to the condition variable attribute.
 * @return Returns <b>ffrt_thrd_success</b> if the condition variable is initialized;
           returns <b>ffrt_thrd_error</b> otherwise.
 * @syscap SystemCapability.Resourceschedule.Ffrt.Core
 * @since 10
 * @version 1.0
 */
FFRT_C_API int ffrt_cond_init(ffrt_cond_t* cond, const ffrt_condattr_t* attr);

/**
 * @brief Unblocks at least one of the threads that are blocked on a condition variable.
 *
 * @param cond Indicates a pointer to the condition variable.
 * @return Returns <b>ffrt_thrd_success</b> if the thread is unblocked;
           returns <b>ffrt_thrd_error</b> otherwise.
 * @syscap SystemCapability.Resourceschedule.Ffrt.Core
 * @since 10
 * @version 1.0
 */
FFRT_C_API int ffrt_cond_signal(ffrt_cond_t* cond);

/**
 * @brief Unblocks all threads currently blocked on a condition variable.
 *
 * @param cond Indicates a pointer to the condition variable.
 * @return Returns <b>ffrt_thrd_success</b> if the threads are unblocked;
           returns <b>ffrt_thrd_error</b> otherwise.
 * @syscap SystemCapability.Resourceschedule.Ffrt.Core
 * @since 10
 * @version 1.0
 */
FFRT_C_API int ffrt_cond_broadcast(ffrt_cond_t* cond);

/**
 * @brief Blocks the calling thread.
 *
 * @param cond Indicates a pointer to the condition variable.
 * @param mutex Indicates a pointer to the mutex.
 * @return Returns <b>ffrt_thrd_success</b> if the thread is unblocked after being blocked;
           returns <b>ffrt_thrd_error</b> otherwise.
 * @syscap SystemCapability.Resourceschedule.Ffrt.Core
 * @since 10
 * @version 1.0
 */
FFRT_C_API int ffrt_cond_wait(ffrt_cond_t* cond, ffrt_mutex_t* mutex);

/**
 * @brief Blocks the calling thread for a given duration.
 *
 * @param cond Indicates a pointer to the condition variable.
 * @param mutex Indicates a pointer to the mutex.
 * @param time_point Indicates the maximum duration that the thread is blocked.
 * If <b>ffrt_cond_signal</b> or <b>ffrt_cond_broadcast</b> is not called to unblock the thread
 * when the maximum duration reaches, the thread is automatically unblocked.
 * @return Returns <b>ffrt_thrd_success</b> if the thread is unblocked after being blocked;
           returns <b>ffrt_thrd_timedout</b> if the maximum duration reaches;
           returns <b>ffrt_thrd_error</b> if the blocking fails.
 * @since 10
 * @version 1.0
 */
FFRT_C_API int ffrt_cond_timedwait(ffrt_cond_t* cond, ffrt_mutex_t* mutex, const struct timespec* time_point);

/**
 * @brief Destroys a condition variable.
 *
 * @param cond Indicates a pointer to the condition variable.
 * @return Returns <b>ffrt_thrd_success</b> if the condition variable is destroyed;
           returns <b>ffrt_thrd_error</b> otherwise.
 * @since 10
 * @version 1.0
 */
FFRT_C_API int ffrt_cond_destroy(ffrt_cond_t* cond);
#endif