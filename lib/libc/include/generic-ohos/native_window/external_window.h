/*
 * Copyright (c) 2021-2022 Huawei Device Co., Ltd.
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

#ifndef NDK_INCLUDE_EXTERNAL_NATIVE_WINDOW_H_
#define NDK_INCLUDE_EXTERNAL_NATIVE_WINDOW_H_

/**
 * @addtogroup NativeWindow
 * @{
 *
 * @brief Provides the native window capability for connection to the EGL.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeWindow
 * @since 8
 * @version 1.0
 */

/**
 * @file external_window.h
 *
 * @brief Defines the functions for obtaining and using a native window.
 *
 * @library libnative_window.so
 * @since 8
 * @version 1.0
 */

#include <stdint.h>
#include "buffer_handle.h"
#include "../native_buffer/buffer_common.h"

#ifdef __cplusplus
extern "C" {
#endif
typedef struct OH_NativeBuffer OH_NativeBuffer;

/**
 * @brief Defines the ipc parcel.
 *
 * @since 12
 * @version 1.0
 */
typedef struct OHIPCParcel OHIPCParcel;

/**
 * @brief native window.
 * @since 8
 */
struct NativeWindow;

/**
 * @brief native window buffer.
 * @since 8
 */
struct NativeWindowBuffer;

/**
 * @brief define the new type name OHNativeWindow for struct NativeWindow.
 * @since 8
 */
typedef struct NativeWindow OHNativeWindow;

/**
 * @brief define the new type name OHNativeWindowBuffer for struct NativeWindowBuffer.
 * @since 8
 */
typedef struct NativeWindowBuffer OHNativeWindowBuffer;

/**
 * @brief indicates a dirty region where content is updated.
 * @since 8
 */
typedef struct Region {
    /** if rects is nullptr, fill the Buffer dirty size by default */
    struct Rect {
        int32_t x;
        int32_t y;
        uint32_t w;
        uint32_t h;
    } *rects;
    /** if rectNumber is 0, fill the Buffer dirty size by default */
    int32_t rectNumber;
}Region;


/**
 * @brief Indicates the operation code in the function OH_NativeWindow_NativeWindowHandleOpt.
 * @since 8
 */
typedef enum NativeWindowOperation {
    /**
     * set native window buffer geometry,
     * variable parameter in function is
     * [in] int32_t height, [in] int32_t width
     */
    SET_BUFFER_GEOMETRY,
    /**
     * get native window buffer geometry,
     * variable parameter in function is
     * [out] int32_t *height, [out] int32_t *width
     */
    GET_BUFFER_GEOMETRY,
    /**
     * get native window buffer format,
     * variable parameter in function is
     * [out] int32_t *format
     */
    GET_FORMAT,
    /**
     * set native window buffer format,
     * variable parameter in function is
     * [in] int32_t format
     */
    SET_FORMAT,
    /**
     * get native window buffer usage,
     * variable parameter in function is
     * [out] int32_t *usage.
     */
    GET_USAGE,
    /**
     * set native window buffer usage,
     * variable parameter in function is
     * [in] int32_t usage.
     */
    SET_USAGE,
    /**
     * set native window buffer stride,
     * variable parameter in function is
     * [in] int32_t stride.
     */
    SET_STRIDE,
    /**
     * get native window buffer stride,
     * variable parameter in function is
     * [out] int32_t *stride.
     */
    GET_STRIDE,
    /**
     * set native window buffer swap interval,
     * variable parameter in function is
     * [in] int32_t interval.
     */
    SET_SWAP_INTERVAL,
    /**
     * get native window buffer swap interval,
     * variable parameter in function is
     * [out] int32_t *interval.
     */
    GET_SWAP_INTERVAL,
    /**
     * set native window buffer timeout,
     * variable parameter in function is
     * [in] int32_t timeout.
     */
    SET_TIMEOUT,
    /**
     * get native window buffer timeout,
     * variable parameter in function is
     * [out] int32_t *timeout.
     */
    GET_TIMEOUT,
    /**
     * set native window buffer colorGamut,
     * variable parameter in function is
     * [in] int32_t colorGamut.
     */
    SET_COLOR_GAMUT,
    /**
     * get native window buffer colorGamut,
     * variable parameter in function is
     * [out int32_t *colorGamut].
     */
    GET_COLOR_GAMUT,
    /**
     * set native window buffer transform,
     * variable parameter in function is
     * [in] int32_t transform.
     */
    SET_TRANSFORM,
    /**
     * get native window buffer transform,
     * variable parameter in function is
     * [out] int32_t *transform.
     */
    GET_TRANSFORM,
    /**
     * set native window buffer uiTimestamp,
     * variable parameter in function is
     * [in] uint64_t uiTimestamp.
     */
    SET_UI_TIMESTAMP,
    /**
     * get native window bufferqueue size,
     * variable parameter in function is
     * [out] int32_t *size.
     * @since 12
     */
    GET_BUFFERQUEUE_SIZE,
    /**
     * set surface source type,
     * variable parameter in function is
     * [in] int32_t sourceType.
     * @since 12
     */
    SET_SOURCE_TYPE,
    /**
     * get surface source type,
     * variable parameter in function is
     * [out] int32_t *sourceType.
     * @since 12
     */
    GET_SOURCE_TYPE,
    /**
     * set app framework type,
     * variable parameter in function is
     * [in] char* frameworkType. maximum length is 64 bytes, otherwise the setting fails.
     * @since 12
     */
    SET_APP_FRAMEWORK_TYPE,
    /**
     * get app framework type,
     * variable parameter in function is
     * [out] char** frameworkType.
     * @since 12
     */
    GET_APP_FRAMEWORK_TYPE,
    /**
     * set hdr white point brightness,
     * variable parameter in function is
     * [in] float brightness. the value range is 0.0f to 1.0f.
     * @since 12
     */
    SET_HDR_WHITE_POINT_BRIGHTNESS,
    /**
     * set sdr white point brightness,
     * variable parameter in function is
     * [in] float brightness. the value range is 0.0f to 1.0f.
     * @since 12
     */
    SET_SDR_WHITE_POINT_BRIGHTNESS,
} NativeWindowOperation;

/**
 * @brief Indicates Scaling Mode.
 * @since 9
 * @deprecated(since = "10")
 */
typedef enum {
    /**
     * the window content is not updated until a buffer of
     * the window size is received
     */
    OH_SCALING_MODE_FREEZE = 0,
    /**
     * the buffer is scaled in two dimensions to match the window size
     */
    OH_SCALING_MODE_SCALE_TO_WINDOW,
    /**
     * the buffer is uniformly scaled so that the smaller size of
     * the buffer matches the window size
     */
    OH_SCALING_MODE_SCALE_CROP,
    /**
     * the window is clipped to the size of the buffer's clipping rectangle
     * pixels outside the clipping rectangle are considered fully transparent.
     */
    OH_SCALING_MODE_NO_SCALE_CROP,
} OHScalingMode;

/**
 * @brief Indicates Scaling Mode.
 * @since 12
 */
typedef enum {
    /**
     * the window content is not updated until a buffer of
     * the window size is received
     */
    OH_SCALING_MODE_FREEZE_V2 = 0,
    /**
     * the buffer is scaled in two dimensions to match the window size
     */
    OH_SCALING_MODE_SCALE_TO_WINDOW_V2,
    /**
     * the buffer is uniformly scaled so that the smaller size of
     * the buffer matches the window size
     */
    OH_SCALING_MODE_SCALE_CROP_V2,
    /**
     * the window is clipped to the size of the buffer's clipping rectangle
     * pixels outside the clipping rectangle are considered fully transparent.
     */
    OH_SCALING_MODE_NO_SCALE_CROP_V2,
    /**
     * Adapt to the buffer and scale proportionally to the buffer size. Prioritize displaying all buffer content.
     * If the size is not the same as the window size, fill the unfilled area of the window with a background color.
     */
    OH_SCALING_MODE_SCALE_FIT_V2,
} OHScalingModeV2;

/**
 * @brief Enumerates the HDR metadata keys.
 * @since 9
 * @deprecated(since = "10")
 */
typedef enum {
    OH_METAKEY_RED_PRIMARY_X = 0,
    OH_METAKEY_RED_PRIMARY_Y = 1,
    OH_METAKEY_GREEN_PRIMARY_X = 2,
    OH_METAKEY_GREEN_PRIMARY_Y = 3,
    OH_METAKEY_BLUE_PRIMARY_X = 4,
    OH_METAKEY_BLUE_PRIMARY_Y = 5,
    OH_METAKEY_WHITE_PRIMARY_X = 6,
    OH_METAKEY_WHITE_PRIMARY_Y = 7,
    OH_METAKEY_MAX_LUMINANCE = 8,
    OH_METAKEY_MIN_LUMINANCE = 9,
    OH_METAKEY_MAX_CONTENT_LIGHT_LEVEL = 10,
    OH_METAKEY_MAX_FRAME_AVERAGE_LIGHT_LEVEL = 11,
    OH_METAKEY_HDR10_PLUS = 12,
    OH_METAKEY_HDR_VIVID = 13,
} OHHDRMetadataKey;

/**
 * @brief Defines the HDR metadata.
 * @since 9
 * @deprecated(since = "10")
 */
typedef struct {
    OHHDRMetadataKey key;
    float value;
} OHHDRMetaData;

/**
 * @brief Defines the ExtData Handle
 * @since 9
 * @deprecated(since = "10")
 */
typedef struct OHExtDataHandle {
    /**< Handle fd, -1 if not supported */
    int32_t fd;
    /**< the number of reserved integer value */
    uint32_t reserveInts;
    /**< the reserved data */
    int32_t reserve[0];
} OHExtDataHandle;

/**
 * @brief Indicates the source type of surface.
 * @since 12
 */
typedef enum {
    /*
     * the default source type of surface.
     */
    OH_SURFACE_SOURCE_DEFAULT = 0,
    /*
     * the surface is created by ui.
     */
    OH_SURFACE_SOURCE_UI,
    /*
     * the surface is created by game.
     */
    OH_SURFACE_SOURCE_GAME,
    /*
     * the surface is created by camera.
     */
    OH_SURFACE_SOURCE_CAMERA,
    /*
     * the surface is created by video.
     */
    OH_SURFACE_SOURCE_VIDEO,
} OHSurfaceSource;

/**
 * @brief Creates a <b>OHNativeWindow</b> instance. A new <b>OHNativeWindow</b> instance is created each time this function is called.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeWindow
 * @param pSurface Indicates the pointer to a <b>ProduceSurface</b>. The type is a pointer to <b>sptr<OHOS::Surface></b>.
 * @return Returns the pointer to the <b>OHNativeWindow</b> instance created.
 * @since 8
 * @version 1.0
 * @deprecated since 12
 */
OHNativeWindow* OH_NativeWindow_CreateNativeWindow(void* pSurface);

/**
 * @brief Decreases the reference count of a <b>OHNativeWindow</b> instance by 1, and when the reference count reaches 0, destroys the instance.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeWindow
 * @param window Indicates the pointer to a <b>OHNativeWindow</b> instance.
 * @since 8
 * @version 1.0
 */
void OH_NativeWindow_DestroyNativeWindow(OHNativeWindow* window);

/**
 * @brief Creates a <b>OHNativeWindowBuffer</b> instance. A new <b>OHNativeWindowBuffer</b> instance is created each time this function is called.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeWindow
 * @param pSurfaceBuffer Indicates the pointer to a produce buffer. The type is <b>sptr<OHOS::SurfaceBuffer></b>.
 * @return Returns the pointer to the <b>OHNativeWindowBuffer</b> instance created.
 * @since 8
 * @version 1.0
 * @deprecated since 12
 * @useinstead OH_NativeWindow_CreateNativeWindowBufferFromNativeBuffer
 */
OHNativeWindowBuffer* OH_NativeWindow_CreateNativeWindowBufferFromSurfaceBuffer(void* pSurfaceBuffer);

/**
 * @brief Creates a <b>OHNativeWindowBuffer</b> instance.
 A new <b>OHNativeWindowBuffer</b> instance is created each time this function is called.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeWindow
 * @param nativeBuffer Indicates the pointer to a native buffer. The type is <b>OH_NativeBuffer*</b>.
 * @return Returns the pointer to the <b>OHNativeWindowBuffer</b> instance created.
 * @since 11
 * @version 1.0
 */
OHNativeWindowBuffer* OH_NativeWindow_CreateNativeWindowBufferFromNativeBuffer(OH_NativeBuffer* nativeBuffer);

/**
 * @brief Decreases the reference count of a <b>OHNativeWindowBuffer</b> instance by 1 and, when the reference count reaches 0, destroys the instance.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeWindow
 * @param buffer Indicates the pointer to a <b>OHNativeWindowBuffer</b> instance.
 * @since 8
 * @version 1.0
 */
void OH_NativeWindow_DestroyNativeWindowBuffer(OHNativeWindowBuffer* buffer);

/**
 * @brief Requests a <b>OHNativeWindowBuffer</b> through a <b>OHNativeWindow</b> instance for content production.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeWindow
 * @param window Indicates the pointer to a <b>OHNativeWindow</b> instance.
 * @param buffer Indicates the double pointer to a <b>OHNativeWindowBuffer</b> instance.
 * @param fenceFd Indicates the pointer to a file descriptor handle.
 * @return Returns an error code, 0 is success, otherwise, failed.
 * @since 8
 * @version 1.0
 */
int32_t OH_NativeWindow_NativeWindowRequestBuffer(OHNativeWindow *window,
    OHNativeWindowBuffer **buffer, int *fenceFd);

/**
 * @brief Flushes the <b>OHNativeWindowBuffer</b> filled with the content to the buffer queue through a <b>OHNativeWindow</b> instance for content consumption.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeWindow
 * @param window Indicates the pointer to a <b>OHNativeWindow</b> instance.
 * @param buffer Indicates the pointer to a <b>OHNativeWindowBuffer</b> instance.
 * @param fenceFd Indicates a file descriptor handle, which is used for timing synchronization.
 * @param region Indicates a dirty region where content is updated.
 * @return Returns an error code, 0 is success, otherwise, failed.
 * @since 8
 * @version 1.0
 */
int32_t OH_NativeWindow_NativeWindowFlushBuffer(OHNativeWindow *window, OHNativeWindowBuffer *buffer,
    int fenceFd, Region region);

/**
 * @brief Get the last flushed <b>OHNativeWindowBuffer</b> from a <b>OHNativeWindow</b> instance.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeWindow
 * @param window Indicates the pointer to a <b>OHNativeWindow</b> instance.
 * @param buffer Indicates the pointer to a <b>OHNativeWindowBuffer</b> pointer.
 * @param fenceFd Indicates the pointer to a file descriptor handle.
 * @param matrix Indicates the retrieved 4*4 transform matrix.
 * @return Returns an error code, 0 is success, otherwise, failed.
 * @since 11
 * @version 1.0
 * @deprecated since 12
 * @useinstead OH_NativeWindow_GetLastFlushedBufferV2
 */
int32_t OH_NativeWindow_GetLastFlushedBuffer(OHNativeWindow *window, OHNativeWindowBuffer **buffer,
    int *fenceFd, float matrix[16]);

 /**
 * @brief Returns the <b>OHNativeWindowBuffer</b> to the buffer queue through a <b>OHNativeWindow</b> instance, without filling in any content. The <b>OHNativeWindowBuffer</b> can be used for another request.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeWindow
 * @param window Indicates the pointer to a <b>OHNativeWindow</b> instance.
 * @param buffer Indicates the pointer to a <b>OHNativeWindowBuffer</b> instance.
 * @return Returns an error code, 0 is success, otherwise, failed.
 * @since 8
 * @version 1.0
 */
int32_t OH_NativeWindow_NativeWindowAbortBuffer(OHNativeWindow *window, OHNativeWindowBuffer *buffer);

/**
 * @brief Sets or obtains the attributes of a native window, including the width, height, and content format.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeWindow
 * @param window Indicates the pointer to a <b>OHNativeWindow</b> instance.
 * @param code Indicates the operation code, pointer to <b>NativeWindowOperation</b>.
 * @param ... variable parameter, must correspond to code one-to-one.
 * @return Returns an error code, 0 is success, otherwise, failed.
 * @since 8
 * @version 1.0
 */
int32_t OH_NativeWindow_NativeWindowHandleOpt(OHNativeWindow *window, int code, ...);

/**
 * @brief Obtains the pointer to a <b>BufferHandle</b> of a <b>OHNativeWindowBuffer</b> instance.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeWindow
 * @param buffer Indicates the pointer to a <b>OHNativeWindowBuffer</b> instance.
 * @return Returns the pointer to the <b>BufferHandle</b> instance obtained.
 * @since 8
 * @version 1.0
 */
BufferHandle *OH_NativeWindow_GetBufferHandleFromNative(OHNativeWindowBuffer *buffer);

/**
 * @brief Adds the reference count of a native object.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeWindow
 * @param obj Indicates the pointer to a <b>OHNativeWindow</b> or <b>OHNativeWindowBuffer</b> instance.
 * @return Returns an error code, 0 is success, otherwise, failed.
 * @since 8
 * @version 1.0
 */
int32_t OH_NativeWindow_NativeObjectReference(void *obj);

/**
 * @brief Decreases the reference count of a native object and, when the reference count reaches 0, destroys this object.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeWindow
 * @param obj Indicates the pointer to a <b>OHNativeWindow</b> or <b>OHNativeWindowBuffer</b> instance.
 * @return Returns an error code, 0 is success, otherwise, failed.
 * @since 8
 * @version 1.0
 */
int32_t OH_NativeWindow_NativeObjectUnreference(void *obj);

/**
 * @brief Obtains the magic ID of a native object.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeWindow
 * @param obj Indicates the pointer to a <b>OHNativeWindow</b> or <b>OHNativeWindowBuffer</b> instance.
 * @return Returns the magic ID, which is unique for each native object.
 * @since 8
 * @version 1.0
 */
int32_t OH_NativeWindow_GetNativeObjectMagic(void *obj);

/**
 * @brief Sets scalingMode of a native window.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeWindow
 * @param window Indicates the pointer to a <b>OHNativeWindow</b> instance.
 * @param sequence Indicates the sequence to a produce buffer.
 * @param scalingMode Indicates the enum value to <b>OHScalingMode</b>
 * @return Returns an error code, 0 is success, otherwise, failed.
 * @since 9
 * @version 1.0
 * @deprecated(since = "10")
 */
int32_t OH_NativeWindow_NativeWindowSetScalingMode(OHNativeWindow *window, uint32_t sequence,
                                                   OHScalingMode scalingMode);

/**
 * @brief Sets metaData of a native window.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeWindow
 * @param window Indicates the pointer to a <b>OHNativeWindow</b> instance.
 * @param sequence Indicates the sequence to a produce buffer.
 * @param size Indicates the size of a <b>OHHDRMetaData</b> vector.
 * @param metaDate Indicates the pointer to a <b>OHHDRMetaData</b> vector.
 * @return Returns an error code, 0 is success, otherwise, failed.
 * @since 9
 * @version 1.0
 * @deprecated(since = "10")
 */
int32_t OH_NativeWindow_NativeWindowSetMetaData(OHNativeWindow *window, uint32_t sequence, int32_t size,
                                                const OHHDRMetaData *metaData);

/**
 * @brief Sets metaDataSet of a native window.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeWindow
 * @param window Indicates the pointer to a <b>OHNativeWindow</b> instance.
 * @param sequence Indicates the sequence to a produce buffer.
 * @param key Indicates the enum value to <b>OHHDRMetadataKey</b>
 * @param size Indicates the size of a uint8_t vector.
 * @param metaDate Indicates the pointer to a uint8_t vector.
 * @return Returns an error code, 0 is success, otherwise, failed.
 * @since 9
 * @version 1.0
 * @deprecated(since = "10")
 */
int32_t OH_NativeWindow_NativeWindowSetMetaDataSet(OHNativeWindow *window, uint32_t sequence, OHHDRMetadataKey key,
                                                   int32_t size, const uint8_t *metaData);

/**
 * @brief Sets tunnel handle of a native window.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeWindow
 * @param window Indicates the pointer to a <b>OHNativeWindow</b> instance.
 * @param handle Indicates the pointer to a <b>OHExtDataHandle</b>.
 * @return Returns an error code, 0 is success, otherwise, failed.
 * @since 9
 * @version 1.0
 * @deprecated(since = "10")
 */
int32_t OH_NativeWindow_NativeWindowSetTunnelHandle(OHNativeWindow *window, const OHExtDataHandle *handle);

/**
 * @brief Attach a buffer to an <b>OHNativeWindow</b> instance.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeWindow
 * @param window Indicates the pointer to an <b>OHNativeWindow</b> instance.
 * @param buffer Indicates the pointer to a <b>OHNativeWindowBuffer</b> instance.
 * @return Returns an error code, 0 is success, otherwise, failed.
 * @since 12
 * @version 1.0
 */
int32_t OH_NativeWindow_NativeWindowAttachBuffer(OHNativeWindow *window, OHNativeWindowBuffer *buffer);

/**
 * @brief Detach a buffer from an <b>OHNativeWindow</b> instance.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeWindow
 * @param window Indicates the pointer to an <b>OHNativeWindow</b> instance.
 * @param buffer Indicates the pointer to a <b>OHNativeWindowBuffer</b> instance.
 * @return Returns an error code, 0 is success, otherwise, failed.
 * @since 12
 * @version 1.0
 */
int32_t OH_NativeWindow_NativeWindowDetachBuffer(OHNativeWindow *window, OHNativeWindowBuffer *buffer);

/**
 * @brief Get surfaceId from native window.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeWindow
 * @param window Indicates the pointer to an <b>OHNativeWindow</b> instance.
 * @param surfaceId Indicates the pointer to a surfaceId.
 * @return Returns an error code, 0 is success, otherwise, failed.
 * @since 12
 * @version 1.0
 */
int32_t OH_NativeWindow_GetSurfaceId(OHNativeWindow *window, uint64_t *surfaceId);

/**
 * @brief Creates an <b>OHNativeWindow</b> instance.\n
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeWindow
 * @param surfaceId Indicates the surfaceId to a surface.
 * @param window indicates the pointer to an <b>OHNativeWindow</b> instance.
 * @return Returns an error code, 0 is Success, otherwise, failed.
 * @since 12
 * @version 1.0
 */
int32_t OH_NativeWindow_CreateNativeWindowFromSurfaceId(uint64_t surfaceId, OHNativeWindow **window);

/**
 * @brief Set native window buffer hold.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeWindow
 * @param window Indicates the pointer to an <b>OHNativeWindow</b> instance.
 * @since 12
 * @version 1.0
 */
void OH_NativeWindow_SetBufferHold(OHNativeWindow *window);

/**
 * @brief Write an OHNativeWindow to an OHIPCParcel.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeWindow
 * @param window Indicates the pointer to an <b>OHNativeWindow</b> instance.
 * @param parcel Indicates the pointer to an <b>OHIPCParcel</b> instance.
 * @return 0 - Success.
 *     40001000 - parcel is NULL or window is NULL.
 * @since 12
 * @version 1.0
 */
int32_t OH_NativeWindow_WriteToParcel(OHNativeWindow *window, OHIPCParcel *parcel);

/**
 * @brief Read an OHNativeWindow from an OHIPCParcel.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeWindow
 * @param parcel Indicates the pointer to an <b>OHIPCParcel</b> instance.
 * @param window Indicates the pointer to an <b>OHNativeWindow</b> instance.
 * @return 0 - Success.
 *     40001000 - parcel is NULL or parcel does not contain the window.
 * @since 12
 * @version 1.0
 */
int32_t OH_NativeWindow_ReadFromParcel(OHIPCParcel *parcel, OHNativeWindow **window);

/**
 * @brief Get the last flushed <b>OHNativeWindowBuffer</b> from an <b>OHNativeWindow</b> instance.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeWindow
 * @param window Indicates the pointer to an <b>OHNativeWindow</b> instance.
 * @param buffer Indicates the pointer to an <b>OHNativeWindowBuffer</b> pointer.
 * @param fenceFd Indicates the pointer to a file descriptor handle.
 * @param matrix Indicates the retrieved 4*4 transform matrix.
 * @return 0 - Success.
 *     40001000 - window is NULL or buffer is NULL or fenceFd is NULL.
 *     41207000 - buffer state is wrong.
 * @since 12
 * @version 1.0
 */

int32_t OH_NativeWindow_GetLastFlushedBufferV2(OHNativeWindow *window, OHNativeWindowBuffer **buffer,
    int *fenceFd, float matrix[16]);

/**
 * @brief Set the color space of the native window.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeWindow
 * @param window Indicates the pointer to a <b>OHNativeWindow</b> instance.
 * @param colorSpace Indicates the color space of native window, see <b>OH_NativeBuffer_ColorSpace</b>.
 * @return {@link NATIVE_ERROR_OK} 0 - Success.
 *     {@link NATIVE_ERROR_INVALID_ARGUMENTS} 40001000 - window is NULL.
 *     {@link NATIVE_ERROR_BUFFER_STATE_INVALID} 41207000 - Incorrect colorSpace state.
 * @since 12
 * @version 1.0
 */
int32_t OH_NativeWindow_SetColorSpace(OHNativeWindow *window, OH_NativeBuffer_ColorSpace colorSpace);

/**
 * @brief Sets scalingMode of a native window.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeWindow
 * @param window indicates the pointer to an <b>OHNativeWindow</b> instance.
 * @param scalingMode Indicates the enum value to <b>OHScalingModeV2</b>
 * @return Returns an error code, 0 is Success, otherwise, failed.
 * @since 12
 * @version 1.0
 */
int32_t OH_NativeWindow_NativeWindowSetScalingModeV2(OHNativeWindow *window, OHScalingModeV2 scalingMode);

/**
 * @brief Get the color space of the native window.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeWindow
 * @param window Indicates the pointer to a <b>OHNativeWindow</b> instance.
 * @param colorSpace Indicates the color space of native window, see <b>OH_NativeBuffer_ColorSpace</b>.
 * @return {@link NATIVE_ERROR_OK} 0 - Success.
 *     {@link NATIVE_ERROR_INVALID_ARGUMENTS} 40001000 - window is NULL.
 *     {@link NATIVE_ERROR_BUFFER_STATE_INVALID} 41207000 - Incorrect colorSpace state.
 * @since 12
 * @version 1.0
 */
int32_t OH_NativeWindow_GetColorSpace(OHNativeWindow *window, OH_NativeBuffer_ColorSpace *colorSpace);

/**
 * @brief Set the metadata type of the native window.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeWindow
 * @param window Indicates the pointer to a <b>OHNativeWindow</b> instance.
 * @param metadataKey Indicates the metadata type of native window, see <b>OH_NativeBuffer_MetadataKey</b>.
 * @param size Indicates the size of a uint8_t vector.
 * @param metadata Indicates the pointer to a uint8_t vector.
 * @return {@link NATIVE_ERROR_OK} 0 - Success.
 *     {@link NATIVE_ERROR_INVALID_ARGUMENTS} 40001000 - window or metadata is NULL.
 *     {@link NATIVE_ERROR_BUFFER_STATE_INVALID} 41207000 - Incorrect metadata state.
 *     {@link NATIVE_ERROR_UNSUPPORTED} 50102000 - Unsupported metadata key.
 * @since 12
 * @version 1.0
 */
int32_t OH_NativeWindow_SetMetadataValue(OHNativeWindow *window, OH_NativeBuffer_MetadataKey metadataKey,
    int32_t size, uint8_t *metadata);

/**
 * @brief Set the metadata type of the native window.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeWindow
 * @param window Indicates the pointer to a <b>OHNativeWindow</b> instance.
 * @param metadataKey Indicates the metadata type of native window, see <b>OH_NativeBuffer_MetadataKey</b>.
 * @param size Indicates the size of a uint8_t vector.
 * @param metadata Indicates the pointer to a uint8_t vector.
 * @return {@link NATIVE_ERROR_OK} 0 - Success.
 *     {@link NATIVE_ERROR_INVALID_ARGUMENTS} 40001000 - window, metadata, or size is NULL.
 *     {@link NATIVE_ERROR_BUFFER_STATE_INVALID} 41207000 - Incorrect metadata state.
 *     {@link NATIVE_ERROR_UNSUPPORTED} 50102000 - Unsupported metadata key.
 * @since 12
 * @version 1.0
 */
int32_t OH_NativeWindow_GetMetadataValue(OHNativeWindow *window, OH_NativeBuffer_MetadataKey metadataKey,
    int32_t *size, uint8_t **metadata);
#ifdef __cplusplus
}
#endif

/** @} */
#endif