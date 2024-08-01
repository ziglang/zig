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

#ifndef USB_DDK_TYPES_H
#define USB_DDK_TYPES_H
/**
 * @addtogroup UsbDdk
 * @{
 *
 * @brief Provides USB DDK types and declares the macros, enumerated variables, and\n
 * data structures required by the USB DDK APIs.
 *
 * @syscap SystemCapability.Driver.USB.Extension
 * @since 10
 * @version 1.0
 */

/**
 * @file usb_ddk_types.h
 *
 * @brief Provides the enumerated variables, structures, and macros used in USB DDK APIs.
 *
 * @since 10
 * @version 1.0
 */

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif /* __cplusplus */
/**
 * @brief Setup data for control transfer. It corresponds to <b>Setup Data</b> in the USB protocol.
 *
 * @since 10
 * @version 1.0
 */
typedef struct UsbControlRequestSetup {
    /** Request type. */
    uint8_t bmRequestType;
    /** Request command. */
    uint8_t bRequest;
    /** Its meaning varies according to the request. */
    uint16_t wValue;
    /** It is usually used to transfer the index or offset.\n
     * Its meaning varies according to the request.
     */
    uint16_t wIndex;
    /** Data length. If data is transferred,\n
     * this field indicates the number of transferred bytes.
     */
    uint16_t wLength;
} __attribute__((aligned(8))) UsbControlRequestSetup;

/**
 * @brief Standard device descriptor, corresponding to <b>Standard Device Descriptor</b> in the USB protocol.
 *
 * @since 10
 * @version 1.0
 */
typedef struct UsbDeviceDescriptor {
    /** Size of the descriptor, in bytes. */
    uint8_t bLength;
    /** Descriptor type. */
    uint8_t bDescriptorType;
    /** USB protocol release number. */
    uint16_t bcdUSB;
    /** Device class code allocated by the USB-IF. */
    uint8_t bDeviceClass;
    /** Device subclass code allocated by USB-IF. The value is limited by that of bDeviceClass. */
    uint8_t bDeviceSubClass;
    /** Protocol code allocated by USB-IF. The value is limited by that of bDeviceClass and bDeviceSubClass. */
    uint8_t bDeviceProtocol;
    /** Maximum packet size of endpoint 0. Only values 8, 16, 32, and 64 are valid. */
    uint8_t bMaxPacketSize0;
    /** Vendor ID allocated by USB-IF. */
    uint16_t idVendor;
    /** Product ID allocated by the vendor. */
    uint16_t idProduct;
    /** Device release number. */
    uint16_t bcdDevice;
    /** Index of the string descriptor that describes the vendor. */
    uint8_t iManufacturer;
    /** Index of the string descriptor that describes the product. */
    uint8_t iProduct;
    /** Index of the string descriptor that describes the device SN. */
    uint8_t iSerialNumber;
    /** Configuration quantity. */
    uint8_t bNumConfigurations;
} __attribute__((aligned(8))) UsbDeviceDescriptor;

/**
 * @brief Standard configuration descriptor, corresponding to <b>Standard Configuration Descriptor</b>\n
 * in the USB protocol.
 *
 * @since 10
 * @version 1.0
 */
typedef struct UsbConfigDescriptor {
    /** Size of the descriptor, in bytes. */
    uint8_t bLength;
    /** Descriptor type. */
    uint8_t bDescriptorType;
    /** Total length of the configuration descriptor, including the configuration, interface, endpoint,\n
     * and class- or vendor-specific descriptors.
     */
    uint16_t wTotalLength;
    /** Number of interfaces supported by the configuration. */
    uint8_t bNumInterfaces;
    /** Configuration index, which is used to select the configuration. */
    uint8_t bConfigurationValue;
    /** Index of the string descriptor that describes the configuration. */
    uint8_t iConfiguration;
    /** Configuration attributes, including the power mode and remote wakeup. */
    uint8_t bmAttributes;
    /** Maximum power consumption of the bus-powered USB device, in 2 mA. */
    uint8_t bMaxPower;
} __attribute__((packed)) UsbConfigDescriptor;

/**
 * @brief Standard interface descriptor, corresponding to <b>Standard Interface Descriptor</b>
 * in the USB protocol.
 *
 * @since 10
 * @version 1.0
 */
typedef struct UsbInterfaceDescriptor {
    /** Size of the descriptor, in bytes. */
    uint8_t bLength;
    /** Descriptor type. */
    uint8_t bDescriptorType;
    /** Interface number. */
    uint8_t bInterfaceNumber;
    /** Value used to select the alternate setting of the interface. */
    uint8_t bAlternateSetting;
    /** Number of endpoints (excluding endpoint 0) used by the interface. */
    uint8_t bNumEndpoints;
    /** Interface class code allocated by the USB-IF. */
    uint8_t bInterfaceClass;
    /** Interface subclass code allocated by USB-IF. The value is limited by that of bInterfaceClass. */
    uint8_t bInterfaceSubClass;
    /** Protocol code allocated by USB-IF. The value is limited by that of bInterfaceClass and bInterfaceSubClass. */
    uint8_t bInterfaceProtocol;
    /** Index of the string descriptor that describes the interface. */
    uint8_t iInterface;
} __attribute__((packed)) UsbInterfaceDescriptor;

/**
 * @brief Standard endpoint descriptor, corresponding to <b>Standard Endpoint Descriptor</b> in the USB protocol.
 *
 * @since 10
 * @version 1.0
 */
typedef struct UsbEndpointDescriptor {
    /** Size of the descriptor, in bytes. */
    uint8_t bLength;
    /** Descriptor type. */
    uint8_t bDescriptorType;
    /** Endpoint address, including the endpoint number and endpoint direction. */
    uint8_t bEndpointAddress;
    /** Endpoint attributes, including the transfer type, synchronization type, and usage type. */
    uint8_t bmAttributes;
    /** Maximum packet size supported by an endpoint. */
    uint16_t wMaxPacketSize;
    /** Interval for polling endpoints for data transfer. */
    uint8_t bInterval;
    /** Refresh rate for audio devices. */
    uint8_t bRefresh;
    /** Endpoint synchronization address for audio devices. */
    uint8_t bSynchAddress;
} __attribute__((packed)) UsbEndpointDescriptor;

/**
 * @brief Endpoint descriptor.
 *
 * @since 10
 * @version 1.0
 */
typedef struct UsbDdkEndpointDescriptor {
    /** Standard endpoint descriptor. */
    struct UsbEndpointDescriptor endpointDescriptor;
    /** Unresolved descriptor, including class- or vendor-specific descriptors. */
    const uint8_t *extra;
    /** Length of the unresolved descriptor. */
    uint32_t extraLength;
} UsbDdkEndpointDescriptor;

/**
 * @brief Interface descriptor.
 *
 * @since 10
 * @version 1.0
 */
typedef struct UsbDdkInterfaceDescriptor {
    /** Standard interface descriptor. */
    struct UsbInterfaceDescriptor interfaceDescriptor;
    /** Endpoint descriptor contained in the interface. */
    struct UsbDdkEndpointDescriptor *endPoint;
    /** Unresolved descriptor, including class- or vendor-specific descriptors. */
    const uint8_t *extra;
    /** Length of the unresolved descriptor. */
    uint32_t extraLength;
} UsbDdkInterfaceDescriptor;

/**
 * @brief USB interface.
 *
 * @since 10
 * @version 1.0
 */
typedef struct UsbDdkInterface {
    /** Number of alternate settings of the interface. */
    uint8_t numAltsetting;
    /** Alternate setting of the interface. */
    struct UsbDdkInterfaceDescriptor *altsetting;
} UsbDdkInterface;

/**
 * @brief Configuration descriptor.
 *
 * @since 10
 * @version 1.0
 */
typedef struct UsbDdkConfigDescriptor {
    /** Standard configuration descriptor. */
    struct UsbConfigDescriptor configDescriptor;
    /** Interfaces contained in the configuration. */
    struct UsbDdkInterface *interface;
    /** Unresolved descriptor, including class- or vendor-specific descriptors. */
    const uint8_t *extra;
    /** Length of the unresolved descriptor. */
    uint32_t extraLength;
} UsbDdkConfigDescriptor;

/**
 * @brief Request pipe.
 *
 * @since 10
 * @version 1.0
 */
typedef struct UsbRequestPipe {
    /** Interface operation handle. */
    uint64_t interfaceHandle;
    /** Timeout duration, in milliseconds. */
    uint32_t timeout;
    /** Endpoint address. */
    uint8_t endpoint;
} __attribute__((aligned(8))) UsbRequestPipe;

/**
 * @brief Device memory map created by calling <b>OH_Usb_CreateDeviceMemMap</b>.\n
 * A buffer using the device memory map can provide better performance.
 *
 * @since 10
 * @version 1.0
 */
typedef struct UsbDeviceMemMap {
    /** Buffer address. */
    uint8_t * const address;
    /** Buffer size. */
    const size_t size;
    /** Offset of the used buffer. The default value is 0, indicating that there is no offset\n
     * and the buffer starts from the specified address.
     */
    uint32_t offset;
    /** Length of the used buffer. By default, the value is equal to the size, indicating that\n
     * the entire buffer is used.
     */
    uint32_t bufferLength;
    /** Length of the transferred data. */
    uint32_t transferedLength;
} UsbDeviceMemMap;

/**
 * @brief Defines error codes for USB DDK.
 *
 * @since 10
 * @version 1.0
 */
typedef enum {
    /** @error The operation is successful. */
    USB_DDK_SUCCESS = 0,
    /** @error The operation failed. */
    USB_DDK_FAILED = -1,
    /** @error Invalid parameter. */
    USB_DDK_INVALID_PARAMETER = -2,
    /** @error Memory-related error, for example, insufficient memory, memory data copy failure,\n
     * or memory application failure.
     */
    USB_DDK_MEMORY_ERROR = -3,
    /** @error Invalid operation. */
    USB_DDK_INVALID_OPERATION = -4,
    /** @error Null pointer exception */
    USB_DDK_NULL_PTR = -5,
    /** @error Device busy. */
    USB_DDK_DEVICE_BUSY = -6,
    /** @error Transmission timeout. */
    USB_DDK_TIMEOUT = -7
} UsbDdkErrCode;
#ifdef __cplusplus
}
/** @} */
#endif /* __cplusplus */
#endif // USB_DDK_TYPES_H