/*
 * Copyright (c) 2024 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#ifndef _TEE_DYNAMIC_SRV_H_
#define _TEE_DYNAMIC_SRV_H_

/**
 * @addtogroup TeeTrusted
 * @{
 *
 * @brief TEE(Trusted Excution Environment) API.
 * Provides security capability APIs such as trusted storage, encryption and decryption,
 * and trusted time for trusted application development.
 *
 * @since 12
 */

/**
 * @file tee_dynamic_srv.h
 *
 * @brief Provides APIs related to dynamic service development.
 *
 * @library NA
 * @kit TEE Kit
 * @syscap SystemCapability.Tee.TeeClient
 * @since 12
 * @version 1.0
 */

#include <pthread.h>
#include "tee_service_public.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Defines thread initialization information of the dynamic service.
 *
 * @since 12
 */
struct srv_thread_init_info {
    void *(*func)(void *arg);
    /** The maximum number of parallel threads. */
    uint32_t max_thread;
    int32_t shadow;
    /** The stack size of the thread. */
    uint32_t stack_size;
    /** The timeout period for thread (in seconds).*/
    uint32_t time_out_sec;
};

typedef void (*srv_dispatch_fn_t)(tee_service_ipc_msg *msg,
    uint32_t sndr, tee_service_ipc_msg_rsp *rsp);

struct srv_dispatch_t {
    uint32_t cmd;
    srv_dispatch_fn_t fn;
};

/**
 * @brief Get UUID by sender.
 *
 * @param sender [IN] Indicates the sender's task Id.
 * @param uuid [OUT] Indicates the universally unique identifier.
 *
 * @return Returns {@code TEE_SUCCESS} if the operation is successful.
 *         Returns {@code TEE_ERROR_BAD_PARAMETERS} if the input parameter is incorrect,
 * or the file name is longer than 64 bytes.
 *         Returns {@code TEE_ERROR_ITEM_NOT_FOUND} if failed to find the corresponding UUID by sender.
 *         Returns {@code TEE_ERROR_GENERIC} if failed to obtain the UUID.
 *
 * @since 12
 * @version 1.0
 */
TEE_Result tee_srv_get_uuid_by_sender(uint32_t sender, TEE_UUID *uuid);

/**
 * @brief Releasing the object mapping of a specified address area.
 *
 * @param va_addr [IN] Indicates the address of the memory area to be released.
 * @param size [IN] Indicates the size of the released memory area.
 *
 * @since 12
 * @version 1.0
 */
void tee_srv_unmap_from_task(uint32_t va_addr, uint32_t size);

/**
 * @brief Create a new mapping in the virtual address space of the calling process.
 *
 * @param in_task_id [IN] Indicates the task Id.
 * @param va_addr [IN] Indicates the address of the memory area to be mapped.
 * @param size [IN] Indicates the size of the memory area to be mapped.
 * @param virt_addr [OUT] Indicates the new mapping vitural address.
 *
 * @return Returns <b>0</b> if the operation is successful.
 * @return Returns <b>-1</b> if the operation is failed.
 *
 * @since 12
 * @version 1.0
 */
int tee_srv_map_from_task(uint32_t in_task_id, uint32_t va_addr, uint32_t size, uint32_t *virt_addr);

/**
 * @brief Dispatch task by task name.
  *
 * @param task_name [IN] Indicates the task name.
 * @param dispatch [IN] Indicates the dispatch information.
 * @param n_dispatch [IN] Indicates the dispatch number.
 * @param cur_thread [IN] Indicates the current thread information.
 *
 * @since 12
 * @version 1.0
 */
void tee_srv_cs_server_loop(const char *task_name, const struct srv_dispatch_t *dispatch,
    uint32_t n_dispatch, struct srv_thread_init_info *cur_thread);
#ifdef __cplusplus
}
#endif
/** @} */
#endif