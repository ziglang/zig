/*
 * Copyright (c) 2022 Huawei Device Co., Ltd.
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

#ifndef _INFO_FATAL_MESSAGE_H
#define _INFO_FATAL_MESSAGE_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct fatal_msg {
    size_t size;
    char msg[0];
} fatal_msg_t;

/**
  * @brief Set up fatal message
  * @param msg The fatal message
  */
void set_fatal_message(const char *msg);

/**
  * @brief Get the set fatal message
  * @return Address of fatal message
  */
fatal_msg_t *get_fatal_message(void);

#ifdef __cplusplus
}
#endif

#endif // _INFO_FATAL_MESSAGE_H