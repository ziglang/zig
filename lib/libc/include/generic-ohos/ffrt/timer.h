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
 * @since 12
 */

 /**
 * @file timer.h
 * @kit FunctionFlowRuntimeKit
 *
 * @brief Declares the timer interfaces in C.
 *
 * @syscap SystemCapability.Resourceschedule.Ffrt.Core
 * @since 12
 * @version 1.0
 */
#ifndef FFRT_API_C_TIMER_H
#define FFRT_API_C_TIMER_H
#include <stdbool.h>

#include "type_def.h"

/**
 * @brief Start a timer on ffrt worker
 *
 * @param qos Indicates qos of the worker that runs timer.
 * @param timeout Indicates the number of milliseconds that specifies timeout.
 * @param data Indicates user data used in cb.
 * @param cb Indicates user cb which will be executed when timeout.
 * @param repeat Indicates whether to repeat this timer.
 * @return Returns a timer handle.
 * @since 12
 * @version 1.0
 */
FFRT_C_API ffrt_timer_t ffrt_timer_start(ffrt_qos_t qos, uint64_t timeout, void* data, ffrt_timer_cb cb, bool repeat);

/**
 * @brief Stop a target timer on ffrt worker
 *
 * @param qos Indicates qos of the worker that runs timer.
 * @param handle Indicates the target timer handle.
 * @return Returns 0 if success;
           returns -1 otherwise.
 * @since 12
 * @version 1.0
 */
FFRT_C_API int ffrt_timer_stop(ffrt_qos_t qos, ffrt_timer_t handle);
#endif