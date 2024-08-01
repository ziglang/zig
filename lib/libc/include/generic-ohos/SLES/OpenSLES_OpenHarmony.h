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

#ifndef OPENSLES_OPENHARMONY_H
#define OPENSLES_OPENHARMONY_H

#ifdef __cplusplus
extern "C" {
#endif

#include "OpenSLES.h"
#include "OpenSLES_Platform.h"

/*---------------------------------------------------------------------------*/
/* OH Buffer Queue Interface                                                    */
/*---------------------------------------------------------------------------*/

extern const SLInterfaceID SL_IID_OH_BUFFERQUEUE;

struct SLOHBufferQueueItf_;
typedef const struct SLOHBufferQueueItf_ * const * SLOHBufferQueueItf;

typedef void (SLAPIENTRY *SlOHBufferQueueCallback)(
    SLOHBufferQueueItf caller,
    void *pContext,
    SLuint32 size
);

/** OH Buffer queue state **/

typedef struct SLOHBufferQueueState_ {
    SLuint32    count;
    SLuint32    index;
} SLOHBufferQueueState;


struct SLOHBufferQueueItf_ {
    SLresult (*Enqueue) (
        SLOHBufferQueueItf self,
        const void *buffer,
        SLuint32 size
    );
    SLresult (*Clear) (
        SLOHBufferQueueItf self
    );
    SLresult (*GetState) (
        SLOHBufferQueueItf self,
        SLOHBufferQueueState *state
    );
    SLresult (*GetBuffer) (
        SLOHBufferQueueItf self,
        SLuint8** buffer,
        SLuint32* size
    );
    SLresult (*RegisterCallback) (
        SLOHBufferQueueItf self,
        SlOHBufferQueueCallback callback,
        void* pContext
    );
};

#ifdef __cplusplus
} /* extern "C" */
#endif

#endif /* OPENSLES_OPENHARMONY_H */