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

#ifndef FOUNDATION_ACE_NAPI_INTERFACES_KITS_NAPI_COMMON_H
#define FOUNDATION_ACE_NAPI_INTERFACES_KITS_NAPI_COMMON_H

typedef enum {
    napi_qos_background = 0,
    napi_qos_utility = 1,
    napi_qos_default = 2,
    napi_qos_user_initiated = 3,
} napi_qos_t;

/**
 * @brief Indicates the running mode of the native event loop in an asynchronous native thread.
 *
 * @since 12
 */
typedef enum {
    /**
     * In this mode, the current asynchronous thread will be blocked and events of native event loop will
     * be processed.
     */
    napi_event_mode_default = 0,

    /**
     * In this mode, the current asynchronous thread will not be blocked. If there are events in the event loop,
     * only one event will be processed and then the event loop will stop. If there are no events in the loop,
     * the event loop will stop immediately.
     */
    napi_event_mode_nowait = 1,
} napi_event_mode;

/**
 * @brief Indicates the priority of a task dispatched from native thread to ArkTS thread.
 *
 * @since 12
 */
typedef enum {
    /**
     * The immediate priority tasks should be promptly processed whenever feasible.
     */
    napi_priority_immediate = 0,
    /**
     * The high priority tasks, as sorted by their handle time, should be prioritized over tasks with low priority.
     */
    napi_priority_high = 1,
    /**
     * The low priority tasks, as sorted by their handle time, should be processed before idle priority tasks.
     */
    napi_priority_low = 2,
    /**
     * The idle priority tasks should be processed immediately only if there are no other priority tasks.
     */
    napi_priority_idle = 3,
} napi_task_priority;

#endif /* FOUNDATION_ACE_NAPI_INTERFACES_KITS_NAPI_NATIVE_API_H */