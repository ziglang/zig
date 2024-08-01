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

#ifndef _SYS_SOCKET_H
#error "Never include this file directly; instead, include <sys/socket.h>"
#endif

#include "fortify.h"

#ifdef __cplusplus
extern "C" {
#endif

ssize_t __sendto_chk(int, const void*, size_t, size_t, int, const struct sockaddr*,
    socklen_t);
ssize_t __recvfrom_chk(int, void*, size_t, size_t, int, struct sockaddr*,
    socklen_t*);
ssize_t __send_chk(int, const void*, size_t, size_t, int);
ssize_t __recv_chk(int, void*, size_t, size_t, int);


#ifdef __FORTIFY_COMPILATION
__DIAGNOSE_FORTIFY_INLINE
ssize_t recvfrom(int fd, void* const buf __DIAGNOSE_PASS_OBJECT_SIZE0, size_t len, int flags,
    struct sockaddr* src_addr, socklen_t* addr_len)
__DIAGNOSE_OVERLOAD
__DIAGNOSE_ERROR_IF(__DIAGNOSE_UNEVALUATED_LT(__DIAGNOSE_BOS0(buf), len),
    "'recvfrom' " CALLED_WITH_SIZE_BIGGER_BUFFER)
{
#ifdef __FORTIFY_RUNTIME
    size_t bos = __DIAGNOSE_BOS0(buf);

    if (!__DIAGNOSE_BOS_TRIVIALLY_GE(bos, len)) {
        return __recvfrom_chk(fd, buf, len, bos, flags, src_addr, addr_len);
    }
#endif
    return __DIAGNOSE_CALL_BYPASSING_FORTIFY(recvfrom)(fd, buf, len, flags, src_addr, addr_len);
}

__DIAGNOSE_FORTIFY_INLINE
ssize_t sendto(int fd, const void* const buf __DIAGNOSE_PASS_OBJECT_SIZE0, size_t len, int flags,
    const struct sockaddr* dest_addr, socklen_t addr_len)
__DIAGNOSE_OVERLOAD
__DIAGNOSE_ERROR_IF(__DIAGNOSE_UNEVALUATED_LT(__DIAGNOSE_BOS0(buf), len),
    "'sendto' " CALLED_WITH_SIZE_BIGGER_BUFFER)
{
#ifdef __FORTIFY_RUNTIME
    size_t bos = __DIAGNOSE_BOS0(buf);

    if (!__DIAGNOSE_BOS_TRIVIALLY_GE(bos, len)) {
        return __sendto_chk(fd, buf, len, bos, flags, dest_addr, addr_len);
    }
#endif
    return __DIAGNOSE_CALL_BYPASSING_FORTIFY(sendto)(fd, buf, len, flags, dest_addr, addr_len);
}

__DIAGNOSE_FORTIFY_INLINE
ssize_t recv(int socket, void* const buf __DIAGNOSE_PASS_OBJECT_SIZE0, size_t len, int flags)
__DIAGNOSE_OVERLOAD
__DIAGNOSE_ERROR_IF(__DIAGNOSE_UNEVALUATED_LT(__DIAGNOSE_BOS0(buf), len),
    "'recv' " CALLED_WITH_SIZE_BIGGER_BUFFER)
{
#ifdef __FORTIFY_RUNTIME
    size_t bos = __DIAGNOSE_BOS0(buf);

    if (!__DIAGNOSE_BOS_TRIVIALLY_GE(bos, len)) {
        return __recv_chk(socket, buf, len, bos, flags);
    }
#endif
    return __DIAGNOSE_CALL_BYPASSING_FORTIFY(recv)(socket, buf, len, flags);
}

__DIAGNOSE_FORTIFY_INLINE
ssize_t send(int socket, const void* const buf __DIAGNOSE_PASS_OBJECT_SIZE0, size_t len, int flags)
__DIAGNOSE_OVERLOAD
__DIAGNOSE_ERROR_IF(__DIAGNOSE_UNEVALUATED_LT(__DIAGNOSE_BOS0(buf), len),
    "'send' " CALLED_WITH_SIZE_BIGGER_BUFFER)
{
#ifdef __FORTIFY_RUNTIME
    size_t bos = __DIAGNOSE_BOS0(buf);

    if (!__DIAGNOSE_BOS_TRIVIALLY_GE(bos, len)) {
        return __send_chk(socket, buf, len, bos, flags);
    }
#endif
    return __DIAGNOSE_CALL_BYPASSING_FORTIFY(send)(socket, buf, len, flags);
}
#endif

#ifdef __cplusplus
}
#endif