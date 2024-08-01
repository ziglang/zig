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

#ifndef _POLL_H
#error "Never include this file directly; instead, include <poll.h>"
#endif

#include <signal.h>
#include "fortify.h"

#ifdef __cplusplus
extern "C" {
#endif

int __poll_chk(struct pollfd*, nfds_t, int, size_t);
#ifdef _GNU_SOURCE
int __ppoll_chk(struct pollfd*, nfds_t, const struct timespec*, const sigset_t*, size_t);
#endif

#ifdef __FORTIFY_COMPILATION
__DIAGNOSE_FORTIFY_INLINE
int poll(struct pollfd* const fds __DIAGNOSE_PASS_OBJECT_SIZE, nfds_t fd_amount, int timeout)
__DIAGNOSE_OVERLOAD
__DIAGNOSE_ERROR_IF(__DIAGNOSE_UNEVALUATED_LT(__DIAGNOSE_BOS(fds), sizeof(*fds) * fd_amount),
    "in call to 'poll', " FD_COUNT_LARGE_GIVEN_BUFFER)
{
#ifdef __FORTIFY_RUNTIME
    size_t bos_fds = __DIAGNOSE_BOS(fds);

    if (!__DIAGNOSE_BOS_FD_COUNT_TRIVIALLY_SAFE(bos_fds, fds, fd_amount)) {
        return __poll_chk(fds, fd_amount, timeout, bos_fds);
    }
#endif
    return __DIAGNOSE_CALL_BYPASSING_FORTIFY(poll)(fds, fd_amount, timeout);
}

#ifdef _GNU_SOURCE
__DIAGNOSE_FORTIFY_INLINE
int ppoll(struct pollfd* const fds __DIAGNOSE_PASS_OBJECT_SIZE, nfds_t fd_amount,
    const struct timespec* timeout, const sigset_t* mask)
__DIAGNOSE_OVERLOAD
__DIAGNOSE_ERROR_IF(__DIAGNOSE_UNEVALUATED_LT(__DIAGNOSE_BOS(fds), sizeof(*fds) * fd_amount),
    "in call to 'ppoll', " FD_COUNT_LARGE_GIVEN_BUFFER)
{
#ifdef __FORTIFY_RUNTIME
    size_t bos_fds = __DIAGNOSE_BOS(fds);

    if (!__DIAGNOSE_BOS_FD_COUNT_TRIVIALLY_SAFE(bos_fds, fds, fd_amount)) {
        return __ppoll_chk(fds, fd_amount, timeout, mask, bos_fds);
    }
#endif
    return __DIAGNOSE_CALL_BYPASSING_FORTIFY(ppoll)(fds, fd_amount, timeout, mask);
}
#endif

#endif

#ifdef __cplusplus
}
#endif