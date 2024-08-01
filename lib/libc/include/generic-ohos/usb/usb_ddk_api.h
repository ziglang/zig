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
#ifndef USB_DDK_API_H
#define USB_DDK_API_H

/**
 * @addtogroup UsbDdk
 * @{
 *
 * @brief Provides USB DDK APIs to open and close USB interfaces, perform non-isochronous and isochronous\n
 * data transfer over USB pipes, and implement control transfer and interrupt transfer, etc.
 *
 * @kit DriverDevelopmentKit
 * @syscap SystemCapability.Driver.USB.Extension
 * @since 10
 * @version 1.0
 */

/**
 * @file usb_ddk_api.h
 *
 * @brief Declares the USB DDK APIs used by the USB host to access USB devices.
 *
 * @since 10
 * @version 1.0
 */

#include <stdint.h>

#include "ddk_types.h"
#include "usb_ddk_types.h"

#ifdef __cplusplus
extern "C" {
#endif /* __cplusplus */

/**
 * @brief Initializes the DDK.
 *
 * @permission ohos.permission.ACCESS_DDK_USB
 * @return {@link USB_DDK_SUCCESS} the operation is successful.
 *         {@link USB_DDK_FAILED} permission check failed or connect usb ddk service failed or internal error failed.
 * @since 10
 * @version 1.0
 */
int32_t OH_Usb_Init(void);

/**
 * @brief Releases the DDK.
 *
 * @permission ohos.permission.ACCESS_DDK_USB
 * @since 10
 * @version 1.0
 */
void OH_Usb_Release(void);

/**
 * @brief Obtains the USB device descriptor.
 *
 * @permission ohos.permission.ACCESS_DDK_USB
 * @param deviceId ID of the device whose descriptor is to be obtained.
 * @param desc Standard device descriptor defined in the USB protocol.
 * @return {@link USB_DDK_SUCCESS} the operation is successful.
 *         {@link USB_DDK_FAILED} permission check failed or internal error failed.
 *         {@link USB_DDK_INVALID_OPERATION} connect usb ddk service failed.
 *         {@link USB_DDK_INVALID_PARAMETER} desc is null.
 * @since 10
 * @version 1.0
 */
int32_t OH_Usb_GetDeviceDescriptor(uint64_t deviceId, struct UsbDeviceDescriptor *desc);

/**
 * @brief Obtains the configuration descriptor. To avoid memory leakage, use <b>OH_Usb_FreeConfigDescriptor</b>\n
 * to release a descriptor after use.
 *
 * @permission ohos.permission.ACCESS_DDK_USB
 * @param deviceId ID of the device whose configuration descriptor is to be obtained.
 * @param configIndex Configuration index, which corresponds to <b>bConfigurationValue</b> in the USB protocol.
 * @param config Configuration descriptor, which includes the standard configuration descriptor defined in the\n
 * USB protocol and the associated interface descriptor and endpoint descriptor.
 * @return {@link USB_DDK_SUCCESS} the operation is successful.
 *         {@link USB_DDK_FAILED} permission check failed or internal error failed.
 *         {@link USB_DDK_INVALID_OPERATION} connect usb ddk service failed.
 *         {@link USB_DDK_INVALID_PARAMETER} config is null.
 * @since 10
 * @version 1.0
 */
int32_t OH_Usb_GetConfigDescriptor(
    uint64_t deviceId, uint8_t configIndex, struct UsbDdkConfigDescriptor ** const config);

/**
 * @brief Releases the configuration descriptor. To avoid memory leakage, use <b>OH_Usb_FreeConfigDescriptor</b>\n
 * to release a descriptor after use.
 *
 * @permission ohos.permission.ACCESS_DDK_USB
 * @param config Configuration descriptor obtained by calling <b>OH_Usb_GetConfigDescriptor</b>.
 * @since 10
 * @version 1.0
 */
void OH_Usb_FreeConfigDescriptor(struct UsbDdkConfigDescriptor * const config);

/**
 * @brief Claims a USB interface.
 *
 * @permission ohos.permission.ACCESS_DDK_USB
 * @param deviceId ID of the device to be operated.
 * @param interfaceIndex Interface index, which corresponds to <b>bInterfaceNumber</b> in the USB protocol.
 * @param interfaceHandle Interface operation handle. After the interface is claimed successfully, a value will be\n
 * assigned to this parameter.
 * @return {@link USB_DDK_SUCCESS} the operation is successful.
 *         {@link USB_DDK_FAILED} permission check failed or internal error failed.
 *         {@link USB_DDK_INVALID_OPERATION} connect usb ddk service failed.
 *         {@link USB_DDK_INVALID_PARAMETER} interfaceHandle is null.
 * @since 10
 * @version 1.0
 */
int32_t OH_Usb_ClaimInterface(uint64_t deviceId, uint8_t interfaceIndex, uint64_t *interfaceHandle);

/**
 * @brief Releases a USB interface.
 *
 * @permission ohos.permission.ACCESS_DDK_USB
 * @param interfaceHandle Interface operation handle.
 * @return {@link USB_DDK_SUCCESS} the operation is successful.
 *         {@link USB_DDK_FAILED} permission check failed or internal error failed.
 *         {@link USB_DDK_INVALID_OPERATION} connect usb ddk service failed.
 * @since 10
 * @version 1.0
 */
int32_t OH_Usb_ReleaseInterface(uint64_t interfaceHandle);

/**
 * @brief Activates the alternate setting of the USB interface.
 *
 * @permission ohos.permission.ACCESS_DDK_USB
 * @param interfaceHandle Interface operation handle.
 * @param settingIndex Index of the alternate setting, which corresponds to <b>bAlternateSetting</b>\n
 * in the USB protocol.
 * @return {@link USB_DDK_SUCCESS} the operation is successful.
 *         {@link USB_DDK_FAILED} permission check failed or internal error failed.
 *         {@link USB_DDK_INVALID_OPERATION} connect usb ddk service failed.
 * @since 10
 * @version 1.0
 */
int32_t OH_Usb_SelectInterfaceSetting(uint64_t interfaceHandle, uint8_t settingIndex);

/**
 * @brief Obtains the activated alternate setting of the USB interface.
 *
 * @permission ohos.permission.ACCESS_DDK_USB
 * @param interfaceHandle Interface operation handle.
 * @param settingIndex Index of the alternate setting, which corresponds to <b>bAlternateSetting</b>\n
 * in the USB protocol.
 * @return {@link USB_DDK_SUCCESS} the operation is successful.
 *         {@link USB_DDK_FAILED} permission check failed or internal error failed.
 *         {@link USB_DDK_INVALID_OPERATION} connect usb ddk service failed.
 *         {@link USB_DDK_INVALID_PARAMETER} settingIndex is null.
 * @since 10
 * @version 1.0
 */
int32_t OH_Usb_GetCurrentInterfaceSetting(uint64_t interfaceHandle, uint8_t *settingIndex);

/**
 * @brief Sends a control read transfer request. This API works in a synchronous manner.
 *
 * @permission ohos.permission.ACCESS_DDK_USB
 * @param interfaceHandle Interface operation handle.
 * @param setup Request data, which corresponds to <b>Setup Data</b> in the USB protocol.
 * @param timeout Timeout duration, in milliseconds.
 * @param data Data to be transferred.
 * @param dataLen Data length. The return value indicates the length of the actually read data.
 * @return {@link USB_DDK_SUCCESS} the operation is successful.
 *         {@link USB_DDK_FAILED} permission check failed or internal error failed.
 *         {@link USB_DDK_INVALID_OPERATION} connect usb ddk service failed.
 *         {@link USB_DDK_INVALID_PARAMETER} setup is null or data is null or dataLen is null or dataLen is less than\n
 *         size of the read data.
 *         {@link USB_DDK_MEMORY_ERROR} the memory of read data copies failed.
 * @since 10
 * @version 1.0
 */
int32_t OH_Usb_SendControlReadRequest(uint64_t interfaceHandle, const struct UsbControlRequestSetup *setup,
    uint32_t timeout, uint8_t *data, uint32_t *dataLen);

/**
 * @brief Sends a control write transfer request. This API works in a synchronous manner.
 *
 * @permission ohos.permission.ACCESS_DDK_USB
 * @param interfaceHandle Interface operation handle.
 * @param setup Request data, which corresponds to <b>Setup Data</b> in the USB protocol.
 * @param timeout Timeout duration, in milliseconds.
 * @param data Data to be transferred.
 * @param dataLen Data length.
 * @return {@link USB_DDK_SUCCESS} the operation is successful.
 *         {@link USB_DDK_FAILED} permission check failed or internal error failed.
 *         {@link USB_DDK_INVALID_OPERATION} connect usb ddk service failed.
 *         {@link USB_DDK_INVALID_PARAMETER} setup is null or data is null.
 * @since 10
 * @version 1.0
 */
int32_t OH_Usb_SendControlWriteRequest(uint64_t interfaceHandle, const struct UsbControlRequestSetup *setup,
    uint32_t timeout, const uint8_t *data, uint32_t dataLen);

/**
 * @brief Sends a pipe request. This API works in a synchronous manner. This API applies to interrupt transfer\n
 * and bulk transfer.
 *
 * @permission ohos.permission.ACCESS_DDK_USB
 * @param pipe Pipe used to transfer data.
 * @param devMmap Device memory map, which can be obtained by calling <b>OH_Usb_CreateDeviceMemMap</b>.
 * @return {@link USB_DDK_SUCCESS} the operation is successful.
 *         {@link USB_DDK_FAILED} permission check failed or internal error failed.
 *         {@link USB_DDK_INVALID_OPERATION} connect usb ddk service failed.
 *         {@link USB_DDK_INVALID_PARAMETER} pipe is null or devMmap is null or address of devMmap is null.
 * @since 10
 * @version 1.0
 */
int32_t OH_Usb_SendPipeRequest(const struct UsbRequestPipe *pipe, UsbDeviceMemMap *devMmap);

/**
 * @brief Sends a pipe request. This API works in a synchronous manner. This API applies to interrupt transfer\n
 * and bulk transfer.
 *
 * @permission ohos.permission.ACCESS_DDK_USB
 * @param pipe Pipe used to transfer data.
 * @param ashmem Shared memory, which can be obtained by calling <b>OH_DDK_CreateAshmem</b>.
 * @return {@link USB_DDK_SUCCESS} the operation is successful.
 *         {@link USB_DDK_FAILED} permission check failed or internal error failed.
 *         {@link USB_DDK_INVALID_OPERATION} connect usb ddk service failed.
 *         {@link USB_DDK_INVALID_PARAMETER} pipe is null or ashmem is null or address of ashmem is null.
 * @since 12
 */
int32_t OH_Usb_SendPipeRequestWithAshmem(const struct UsbRequestPipe *pipe, DDK_Ashmem *ashmem);

/**
 * @brief Creates a buffer. To avoid resource leakage, destroy a buffer by calling\n
 * <b>OH_Usb_DestroyDeviceMemMap</b> after use.
 *
 * @permission ohos.permission.ACCESS_DDK_USB
 * @param deviceId ID of the device for which the buffer is to be created.
 * @param size Buffer size.
 * @param devMmap Data memory map, through which the created buffer is returned to the caller.
 * @return {@link USB_DDK_SUCCESS} the operation is successful.
 *         {@link USB_DDK_FAILED} permission check failed or internal error failed.
 *         {@link USB_DDK_INVALID_PARAMETER} devMmap is null.
 *         {@link USB_DDK_MEMORY_ERROR} mmap failed or alloc memory of devMmap failed.
 * @since 10
 * @version 1.0
 */
int32_t OH_Usb_CreateDeviceMemMap(uint64_t deviceId, size_t size, UsbDeviceMemMap **devMmap);

/**
 * @brief Destroys a buffer. To avoid resource leakage, destroy a buffer in time after use.
 *
 * @permission ohos.permission.ACCESS_DDK_USB
 * @param devMmap Device memory map created by calling <b>OH_Usb_CreateDeviceMemMap</b>.
 * @since 10
 * @version 1.0
 */
void OH_Usb_DestroyDeviceMemMap(UsbDeviceMemMap *devMmap);
/** @} */
#ifdef __cplusplus
}
#endif /* __cplusplus */

#endif // USB_DDK_API_H