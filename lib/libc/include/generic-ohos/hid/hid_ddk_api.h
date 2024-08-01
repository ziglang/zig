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
#ifndef HID_DDK_API_H
#define HID_DDK_API_H

/**
 * @addtogroup HidDdk
 * @{
 *
 * @brief Provides HID DDK interfaces, including creating a device, sending an event, and destroying a device.
 *
 * @syscap SystemCapability.Driver.HID.Extension
 * @since 11
 * @version 1.0
 */

/**
 * @file hid_ddk_api.h
 *
 * @brief Declares the HID DDK interfaces for the host to access an input device.
 *
 * File to include: <hid/hid_ddk_api.h>
 * @since 11
 * @version 1.0
 */

#include <stdint.h>
#include "hid_ddk_types.h"

#ifdef __cplusplus
extern "C" {
#endif /* __cplusplus */

/**
  * @brief Creates a device.
 *
 * @permission ohos.permission.ACCESS_DDK_HID
 * @param hidDevice Pointer to the basic information required for creating a device, including the device name,
 * vendor ID, and product ID.
 * @param hidEventProperties Pointer to the events of the device to be observed, including the event type and
 * properties of the key event, absolute coordinate event, and relative coordinate event.
 * @return device ID (a non-negative number), if the operation is successful;
 *         {@link HID_DDK_NO_PERM} permission check failed.
 *         {@link HID_DDK_INVALID_OPERATION} connect hid ddk service failed.
 *         {@link HID_DDK_INVALID_PARAMETER} parameter check failed. Possible causes: 1.hidDevice is null;\n
 *         2.hidEventProperties is null; 3.properties length exceeds 7; 4.hidEventTypes length exceeds 5;\n
 *         5.hidKeys length exceeds 100; 6.hidAbs length exceeds 26; 7.hidRelBits length exceeds 13;\n
 *         8.hidMiscellaneous length exceeds 6.
 *         {@link HID_DDK_FAILURE} the number of device reaches the maximum 200.
 * @since 11
 * @version 1.0
 */
int32_t OH_Hid_CreateDevice(Hid_Device *hidDevice, Hid_EventProperties *hidEventProperties);

/**
 * @brief Sends an event list to a device.
 *
 * @permission ohos.permission.ACCESS_DDK_HID
 * @param deviceId ID of the device, to which the event list is sent.
 * @param items List of events to sent. The event information includes the event type (<b>Hid_EventType</b>),
 * event code (<b>Hid_SynEvent</b> for a synchronization event code, <b>Hid_KeyCode</b> for a key code,
 * <b>Hid_AbsAxes</b> for an absolute coordinate code, <b>Hid_RelAxes</b> for a relative coordinate event,
 * and <b>Hid_MscEvent</b> for other input event code), and value input by the device.
 * @param length Length of the event list (number of events sent at a time).
 * @return {@link HID_DDK_SUCCESS} operation successful.
 *         {@link HID_DDK_NO_PERM} permission check failed.
 *         {@link HID_DDK_INVALID_OPERATION} connect hid ddk service failed or the caller is not the creator of device.
 *         {@link HID_DDK_INVALID_PARAMETER} parameter check failed. Possible causes: 1.deviceId is less than 0;\n
 *         2.length exceeds 7; 3.items is null.
 *         {@link HID_DDK_NULL_PTR} the inject of device is null.
 *         {@link HID_DDK_FAILURE} the device does not exit.
 * @since 11
 * @version 1.0
 */
int32_t OH_Hid_EmitEvent(int32_t deviceId, const Hid_EmitItem items[], uint16_t length);

/**
 * @brief Destroys a device.
 *
 * @permission ohos.permission.ACCESS_DDK_HID
 * @param deviceId ID of the device to destroy.
 * @return {@link HID_DDK_SUCCESS} operation successful.
 *         {@link HID_DDK_NO_PERM} permission check failed.
 *         {@link HID_DDK_INVALID_OPERATION} connect hid ddk service failed or the caller is not the creator of device.
 *         {@link HID_DDK_FAILURE} the device does not exit.
 * @since 11
 * @version 1.0
 */
int32_t OH_Hid_DestroyDevice(int32_t deviceId);

#ifdef __cplusplus
}
#endif /* __cplusplus */

#endif // HID_DDK_API_H