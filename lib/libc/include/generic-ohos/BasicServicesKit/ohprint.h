/*
 * Copyright (C) 2024 Huawei Device Co., Ltd.
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

/**
 * @addtogroup OH_Print
 * @{
 *
 * @brief Provides the definition of the C interface for the print module.
 *
 * @syscap SystemCapability.Print.PrintFramework
 * @since 12
 * @version 1.0
 */

/**
 * @file ohprint.h
 *
 * @brief Declares the APIs to discover and connect printers, print files from a printer,
 *        query the list of the added printers and the printer information within it, and so on.
 *
 * @library libohprint.so
 * @kit BasicServicesKit
 * @syscap SystemCapability.Print.PrintFramework
 * @since 12
 * @version 1.0
 */

#ifndef OH_PRINT_H
#define OH_PRINT_H

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Defines error codes.
 *
 * @since 12
 * @version 1.0
 */
typedef enum {
    /** @error The operation is successful. */
    PRINT_ERROR_NONE = 0,
    /** @error Permission verification failed. */
    PRINT_ERROR_NO_PERMISSION = 201,
    /** @error Invalid parameter. */
    PRINT_ERROR_INVALID_PARAMETER = 401,
    /** @error General internal error. */
    PRINT_ERROR_GENERIC_FAILURE = 24300001,
    /** @error RPC communication error. */
    PRINT_ERROR_RPC_FAILURE = 24300002,
    /** @error Server error. */
    PRINT_ERROR_SERVER_FAILURE = 24300003,
    /** @error Invalid extension. */
    PRINT_ERROR_INVALID_EXTENSION = 24300004,
    /** @error Invalid printer. */
    PRINT_ERROR_INVALID_PRINTER = 24300005,
    /** @error Invalid print job. */
    PRINT_ERROR_INVALID_PRINT_JOB = 24300006,
    /** @error Failed to read or write files. */
    PRINT_ERROR_FILE_IO = 24300007,
    /** @error Unknown error. */
    PRINT_ERROR_UNKNOWN = 24300255,
} Print_ErrorCode;

/**
 * @brief Indicates printer states.
 *
 * @since 12
 */
typedef enum {
    /** Printer idle. */
    PRINTER_IDLE,
    /** Printer busy. */
    PRINTER_BUSY,
    /** Printer not available. */
    PRINTER_UNAVAILABLE,
} Print_PrinterState;

/**
 * @brief Indicate printer discovery events.
 *
 * @since 12
 */
typedef enum {
    /** Printer discovered. */
    PRINTER_DISCOVERED = 0,
    /** Printer lost. */
    PRINTER_LOST = 1,
    /** Printer connecting. */
    PRINTER_CONNECTING = 2,
    /** Printer connected. */
    PRINTER_CONNECTED = 3,
} Print_DiscoveryEvent;

/**
 * @brief Indicate printer change events.
 *
 * @since 12
 */
typedef enum {
    /** Printer added. */
    PRINTER_ADDED = 0,
    /** Printer deleted. */
    PRINTER_DELETED = 1,
    /** Printer state changed. */
    PRINTER_STATE_CHANGED = 2,
    /** Printer info changed. */
    PRINTER_INFO_CHANGED = 3,
} Print_PrinterEvent;

/**
 * @brief Indicates string list.
 *
 * @since 12
 */
typedef struct {
    /** Number of string. */
    uint32_t count;
    /** String pointer array. */
    char **list;
} Print_StringList;

/**
 * @brief Indicates printer property.
 *
 * @since 12
 */
typedef struct {
    /** Property keyword. */
    char *key;
    /** Property value. */
    char *value;
} Print_Property;

/**
 * @brief List of printer properties.
 *
 * @since 12
 */
typedef struct {
    /** Number of properties. */
    uint32_t count;
    /** Property pointer array. */
    Print_Property *list;
} Print_PropertyList;

/**
 * @brief Indicates print resolution in dpi unit.
 *
 * @since 12
 */
typedef struct {
    uint32_t horizontalDpi;
    uint32_t verticalDpi;
} Print_Resolution;

/**
 * @brief Indicates printing margin
 *
 * @since 12
 */
typedef struct {
    /** Left margin. */
    uint32_t leftMargin;
    /** Top margin. */
    uint32_t topMargin;
    /** Right margin. */
    uint32_t rightMargin;
    /** Bottom margin. */
    uint32_t bottomMargin;
} Print_Margin;

/**
 * @brief Indicates paper size info.
 *
 * @since 12
 */
typedef struct {
    /** Paper id. */
    char *id;
    /** Paper name. */
    char *name;
    /** Paper width. */
    uint32_t width;
    /** Paper height. */
    uint32_t height;
} Print_PageSize;

/**
 * @brief Indicates DuplexMode
 *
 * @since 12
 */
typedef enum {
    /** One sided duplex mode. */
    DUPLEX_MODE_ONE_SIDED = 0,
    /** Long edge two sided duplex mode. */
    DUPLEX_MODE_TWO_SIDED_LONG_EDGE = 1,
    /** Short edge two sided duplex mode. */
    DUPLEX_MODE_TWO_SIDED_SHORT_EDGE = 2,
} Print_DuplexMode;

/**
 * @brief Indicates ColorMode
 *
 * @since 12
 */
typedef enum {
    /** Monochrome mode. */
    COLOR_MODE_MONOCHROME = 0,
    /** Color mode. */
    COLOR_MODE_COLOR = 1,
    /** Auto mode. */
    COLOR_MODE_AUTO = 2,
} Print_ColorMode;

/**
 * @brief Indicates OrientationMode
 *
 * @since 12
 */
typedef enum {
    /** Portrait mode. */
    ORIENTATION_MODE_PORTRAIT = 0,
    /** Landscape mode. */
    ORIENTATION_MODE_LANDSCAPE = 1,
    /** Reverse landscape mode. */
    ORIENTATION_MODE_REVERSE_LANDSCAPE = 2,
    /** Reverse portrait mode. */
    ORIENTATION_MODE_REVERSE_PORTRAIT = 3,
    /** Not specified. */
    ORIENTATION_MODE_NONE = 4,
} Print_OrientationMode;

/**
 * @brief Indicates printing qulity
 *
 * @since 12
 */
typedef enum {
    /** Draft quality mode */
    PRINT_QUALITY_DRAFT = 3,
    /** Normal quality mode */
    PRINT_QUALITY_NORMAL = 4,
    /** High quality mode */
    PRINT_QUALITY_HIGH = 5
} Print_Quality;

/**
 * @brief Indicates the MIME media type of the document.
 *
 * @since 12
 */
typedef enum {
    /** MIME: application/octet-stream. */
    DOCUMENT_FORMAT_AUTO,
    /** MIME: image/jpeg. */
    DOCUMENT_FORMAT_JPEG,
    /** MIME: application/pdf. */
    DOCUMENT_FORMAT_PDF,
    /** MIME: application/postscript. */
    DOCUMENT_FORMAT_POSTSCRIPT,
    /** MIME: text/plain. */
    DOCUMENT_FORMAT_TEXT,
} Print_DocumentFormat;

/**
 * @brief Indicates printer capabilities.
 *
 * @since 12
 */
typedef struct {
    /** Array of supported color mode. */
    Print_ColorMode *supportedColorModes;
    /** Number of supported color mode. */
    uint32_t supportedColorModesCount;
    /** Array of supported duplex printing modes. */
    Print_DuplexMode *supportedDuplexModes;
    /** Number of supported duplex printing mode. */
    uint32_t supportedDuplexModesCount;
    /** Array of supported print paper sizes. */
    Print_PageSize *supportedPageSizes;
    /** Number of supported print paper sizes. */
    uint32_t supportedPageSizesCount;
    /** Supported print media types in json string array format. */
    char *supportedMediaTypes;
    /** Array of supported print qulities. */
    Print_Quality *supportedQualities;
    /** Number of supported print qulities. */
    uint32_t supportedQualitiesCount;
    /** Supported paper sources in json string array format. */
    char *supportedPaperSources;
    /** Supported copies. */
    uint32_t supportedCopies;
    /** Array of supported printer resolutions. */
    Print_Resolution *supportedResolutions;
    /** Number of supported printer resolutions. */
    uint32_t supportedResolutionsCount;
    /** Array of supported orientation. */
    Print_OrientationMode *supportedOrientations;
    /** Number of supported orientation. */
    uint32_t supportedOrientationsCount;
    /** Advanced capability in json format. */
    char *advancedCapability;
} Print_PrinterCapability;

/**
 * @brief Indicates current properties
 *
 * @since 12
 */
typedef struct {
    /** Default color mode. */
    Print_ColorMode defaultColorMode;
    /** Default duplex mode. */
    Print_DuplexMode defaultDuplexMode;
    /** Default media type. */
    char *defaultMediaType;
    /** Default page size id. */
    char *defaultPageSizeId;
    /** Default margin. */
    Print_Margin defaultMargin;
    /** Default paper source. */
    char *defaultPaperSource;
    /** Default print quality */
    Print_Quality defaultPrintQuality;
    /** Default copies. */
    uint32_t defaultCopies;
    /** Default printer resolution. */
    Print_Resolution defaultResolution;
    /** Default orientation. */
    Print_OrientationMode defaultOrientation;
    /** Other default values in json format. */
    char *otherDefaultValues;
} Print_DefaultValue;

/**
 * @brief Indicates printer information.
 *
 * @since 12
 */
typedef struct {
    /** Printer state. */
    Print_PrinterState printerState;
    /** Printer capabilities. */
    Print_PrinterCapability capability;
    /** Printer current properties. */
    Print_DefaultValue defaultValue;
    /** Default printer. */
    bool isDefaultPrinter;
    /** Printer id. */
    char *printerId;
    /** Printer name. */
    char *printerName;
    /** Printer description. */
    char *description;
    /** Printer location. */
    char *location;
    /** Printer make and model information. */
    char *makeAndModel;
    /** Printer Uri. */
    char *printerUri;
    /** Detail information in json format. */
    char *detailInfo;
} Print_PrinterInfo;

/**
 * @brief Indicates PrintJob Structure.
 *
 * @since 12
 */
typedef struct {
    /** Job name. */
    char *jobName;
    /** Array of file descriptors to print. */
    uint32_t *fdList;
    /** Number of file descriptors to print. */
    uint32_t fdListCount;
    /** Printer id. */
    char *printerId;
    /** Number of copies printed. */
    uint32_t copyNumber;
    /** Paper source. */
    char *paperSource;
    /** Media type. */
    char *mediaType;
    /** Paper size id. */
    char *pageSizeId;
    /** Color mode. */
    Print_ColorMode colorMode;
    /** Duplex source. */
    Print_DuplexMode duplexMode;
    /** Print resolution in dpi. */
    Print_Resolution resolution;
    /** Print margin. */
    Print_Margin printMargin;
    /** Borderless. */
    bool borderless;
    /** Orientation mode. */
    Print_OrientationMode orientationMode;
    /** Print quality. */
    Print_Quality printQuality;
    /** Document format. */
    Print_DocumentFormat documentFormat;
    /** Advanced options in json format. */
    char *advancedOptions;
} Print_PrintJob;

/**
 * @brief Printer discovery callback.
 *
 * @param event The printer discovery event during printer discovery.
 * @param printerInfo The printer infomation at the time of the discovery event.
 * @since 12
 */
typedef void (*Print_PrinterDiscoveryCallback)(Print_DiscoveryEvent event, const Print_PrinterInfo *printerInfo);

/**
 * @brief Printer change callback.
 *
 * @param event The printer change event while the printer service is running.
 * @param printerInfo The printer infomation at the time of the change event.
 * @since 12
 */
typedef void (*Print_PrinterChangeCallback)(Print_PrinterEvent event, const Print_PrinterInfo *printerInfo);

/**
 * @brief This API checks and pulls up the print service, initializes the print client,
 *        and establishes a connection to the print service.
 *
 * @permission {@code ohos.permission.PRINT}
 * @return Returns {@link Print_ErrorCode#PRINT_ERROR_NONE} if the execution is successful.
 *         {@link PRINT_ERROR_NO_PERMISSION} The permission {@code ohos.permission.PRINT} is needed.
 *         {@link PRINT_ERROR_RPC_FAILURE} Unable to connect to the print service.
 *         {@link PRINT_ERROR_SERVER_FAILURE} The cups service cannot be started.
 * @syscap SystemCapability.Print.PrintFramework
 * @since 12
 */
Print_ErrorCode OH_Print_Init();

/**
 * @brief This API closes the connection from the print service, dissolves the previous callback,
 *        and releases the print client resources.
 *
 * @return Returns {@link Print_ErrorCode#PRINT_ERROR_NONE} if the execution is successful.
 *         Currently no other error codes will be returned.
 * @syscap SystemCapability.Print.PrintFramework
 * @since 12
 */
Print_ErrorCode OH_Print_Release();

/**
 * @brief This API starts discovering printers.
 *
 * @permission {@code ohos.permission.PRINT}
 * @param callback The {@link Print_PrinterDiscoveryCallback} of printer discovery event.
 * @return Returns {@link Print_ErrorCode#PRINT_ERROR_NONE} if the execution is successful.
 *         {@link PRINT_ERROR_NO_PERMISSION} The permission {@code ohos.permission.PRINT} is needed.
 *         {@link PRINT_ERROR_RPC_FAILURE} Unable to connect to the print service ability.
 *         {@link PRINT_ERROR_SERVER_FAILURE} Failed to query print extension list from BMS.
 *         {@link PRINT_ERROR_INVALID_EXTENSION} No available print extensions found.
 * @syscap SystemCapability.Print.PrintFramework
 * @since 12
 */
Print_ErrorCode OH_Print_StartPrinterDiscovery(Print_PrinterDiscoveryCallback callback);

/**
 * @brief This API stops discovering printers.
 *
 * @permission {@code ohos.permission.PRINT}
 * @return Returns {@link Print_ErrorCode#PRINT_ERROR_NONE} if the execution is successful.
 *         {@link PRINT_ERROR_NO_PERMISSION} The permission {@code ohos.permission.PRINT} is needed.
 *         {@link PRINT_ERROR_RPC_FAILURE} Unable to connect to the print service.
 * @syscap SystemCapability.Print.PrintFramework
 * @since 12
 */
Print_ErrorCode OH_Print_StopPrinterDiscovery();

/**
 * @brief This API connects to the printer using the printer id.
 *
 * @permission {@code ohos.permission.PRINT}
 * @param printerId The id of the printer to be connected.
 * @return Returns {@link Print_ErrorCode#PRINT_ERROR_NONE} if the execution is successful.
 *         {@link PRINT_ERROR_NO_PERMISSION} The permission {@code ohos.permission.PRINT} is needed.
 *         {@link PRINT_ERROR_RPC_FAILURE} Unable to connect to the print service.
 *         {@link PRINT_ERROR_INVALID_PRINTER} The printer should be in the list of discovered printers.
 *         {@link PRINT_ERROR_SERVER_FAILURE} Unable to find an extension responsible for the printer.
 * @syscap SystemCapability.Print.PrintFramework
 * @since 12
 */
Print_ErrorCode OH_Print_ConnectPrinter(const char *printerId);

/**
 * @brief This API starts initiating a print job.
 *
 * @permission {@code ohos.permission.PRINT}
 * @param printJob A pointer to a {@link Print_PrintJob} instance that specifies the information for the print job.
 * @return Returns {@link Print_ErrorCode#PRINT_ERROR_NONE} if the execution is successful.
 *         {@link PRINT_ERROR_NO_PERMISSION} The permission {@code ohos.permission.PRINT} is needed.
 *         {@link PRINT_ERROR_RPC_FAILURE} Unable to connect to the print service.
 *         {@link PRINT_ERROR_INVALID_PRINTER} The printer should be in the list of connected printers.
 *         {@link PRINT_ERROR_SERVER_FAILURE} Unable to create print job in the print service.
 *         {@link PRINT_ERROR_INVALID_PRINT_JOB} Unable to find the job int the job queue.
 * @syscap SystemCapability.Print.PrintFramework
 * @since 12
 */
Print_ErrorCode OH_Print_StartPrintJob(const Print_PrintJob *printJob);

/**
 * @brief This API registers the callback for printer changes.
 *
 * @permission {@code ohos.permission.PRINT}
 * @param callback The {@link Print_PrinterChangeCallback} to be registered.
 * @return Returns {@link Print_ErrorCode#PRINT_ERROR_NONE} if the execution is successful.
 *         {@link PRINT_ERROR_NO_PERMISSION} The permission {@code ohos.permission.PRINT} is needed.
 *         {@link PRINT_ERROR_RPC_FAILURE} Unable to connect to the print service ability.
 * @syscap SystemCapability.Print.PrintFramework
 * @since 12
 */
Print_ErrorCode OH_Print_RegisterPrinterChangeListener(Print_PrinterChangeCallback callback);

/**
 * @brief This API unregisters the callback for printer changes.
 *
 * @permission {@code ohos.permission.PRINT}
 * @syscap SystemCapability.Print.PrintFramework
 * @since 12
 */
void OH_Print_UnregisterPrinterChangeListener();

/**
 * @brief This API queries for a list of added printers.
 *
 * @permission {@code ohos.permission.PRINT}
 * @param printerIdList A pointer to a {@link Print_StringList} instance to store the queried printer id list.
 * @return Returns {@link Print_ErrorCode#PRINT_ERROR_NONE} if the execution is successful.
 *         {@link PRINT_ERROR_NO_PERMISSION} The permission {@code ohos.permission.PRINT} is needed.
 *         {@link PRINT_ERROR_INVALID_PARAMETER} printerIdList is NULL.
 *         {@link PRINT_ERROR_INVALID_PRINTER} Unable to query any connected printers.
 *         {@link PRINT_ERROR_GENERIC_FAILURE} Unable to copy the printer id list.
 * @syscap SystemCapability.Print.PrintFramework
 * @since 12
 */
Print_ErrorCode OH_Print_QueryPrinterList(Print_StringList *printerIdList);

/**
 * @brief This API frees up the printer list memory for the query.
 *
 * @param printerIdList The queried printer id list to be released.
 * @syscap SystemCapability.Print.PrintFramework
 * @since 12
 */
void OH_Print_ReleasePrinterList(Print_StringList *printerIdList);

/**
 * @brief This API queries printer information based on the printer id.
 *
 * @permission {@code ohos.permission.PRINT}
 * @param printerId The id of the printer to be queried.
 * @param printerInfo A pointer to a {@link Print_PrinterInfo} pointer to store the printer infomation.
 * @return Returns {@link Print_ErrorCode#PRINT_ERROR_NONE} if the execution is successful.
 *         {@link PRINT_ERROR_NO_PERMISSION} The permission {@code ohos.permission.PRINT} is needed.
 *         {@link PRINT_ERROR_RPC_FAILURE} Unable to connect to the print service.
 *         {@link PRINT_ERROR_INVALID_PARAMETER} printerId is NULL or printerInfo is NULL.
 *         {@link PRINT_ERROR_INVALID_PRINTER} Unable to find the printer in the connected printer list.
 * @syscap SystemCapability.Print.PrintFramework
 * @since 12
 */
Print_ErrorCode OH_Print_QueryPrinterInfo(const char *printerId, Print_PrinterInfo **printerInfo);

/**
 * @brief This API frees up the printer infomation memory for the query.
 *
 * @param printerInfo The pointer of the queried printer infomation to be released.
 * @syscap SystemCapability.Print.PrintFramework
 * @since 12
 */
void OH_Print_ReleasePrinterInfo(Print_PrinterInfo *printerInfo);

/**
 * @brief This API launches the system's printer management window.
 *
 * @return Returns {@link Print_ErrorCode#PRINT_ERROR_NONE} if the execution is successful.
 *         {@link PRINT_ERROR_GENERIC_FAILURE} Unable to launch the printer manager window.
 * @syscap SystemCapability.Print.PrintFramework
 * @since 12
 */
Print_ErrorCode OH_Print_LaunchPrinterManager();

/**
 * @brief This API queries the corresponding printer property values based on the list of property keywords.
 *
 * @permission {@code ohos.permission.PRINT}
 * @param printerId The id of the printer to be queried.
 * @param propertyKeyList The list of property keywords to be queried
 * @param propertyList The list of printer property values queried.
 * @return Returns {@link Print_ErrorCode#PRINT_ERROR_NONE} if the execution is successful.
 *         {@link PRINT_ERROR_NO_PERMISSION} The permission {@code ohos.permission.PRINT} is needed.
 *         {@link PRINT_ERROR_INVALID_PARAMETER} One of the params is NULL or the keyword list is empty.
 *         {@link PRINT_ERROR_INVALID_PRINTER} The printer properties for the specified printer could not be found.
 *         {@link PRINT_ERROR_GENERIC_FAILURE} Unable to copy the printer properties.
 * @syscap SystemCapability.Print.PrintFramework
 * @since 12
 */
Print_ErrorCode OH_Print_QueryPrinterProperties(const char *printerId, const Print_StringList *propertyKeyList,
    Print_PropertyList *propertyList);

/**
 * @brief This API frees up the property list memory for the query.
 *
 * @param propertyList The pointer of the queried printer property values to be released.
 * @syscap SystemCapability.Print.PrintFramework
 * @since 12
 */
void OH_Print_ReleasePrinterProperties(Print_PropertyList *propertyList);

/**
 * @brief This API sets printer properties based on a list of property key-value pairs.
 *
 * @permission {@code ohos.permission.PRINT}
 * @param printerId The id of the printer to be set.
 * @param propertyList The list of printer property values to be set.
 * @return Returns {@link Print_ErrorCode#PRINT_ERROR_NONE} if the execution is successful.
 *         {@link PRINT_ERROR_NO_PERMISSION} The permission {@code ohos.permission.PRINT} is needed.
 *         {@link PRINT_ERROR_RPC_FAILURE} Unable to connect to the print service.
 * @syscap SystemCapability.Print.PrintFramework
 * @since 12
 */
Print_ErrorCode OH_Print_UpdatePrinterProperties(const char *printerId, const Print_PropertyList *propertyList);

/**
 * @brief This API restores printer properties to default settings based on the list of property keywords.
 *
 * @permission {@code ohos.permission.PRINT}
 * @param printerId The id of the printer to be restored.
 * @param propertyKeyList The list of property keywords to be restored.
 * @return Returns {@link Print_ErrorCode#PRINT_ERROR_NONE} if the execution is successful.
 *         {@link PRINT_ERROR_NO_PERMISSION} The permission {@code ohos.permission.PRINT} is needed.
 *         {@link PRINT_ERROR_RPC_FAILURE} Unable to connect to the print service.
 * @syscap SystemCapability.Print.PrintFramework
 * @since 12
 */
Print_ErrorCode OH_Print_RestorePrinterProperties(const char *printerId, const Print_StringList *propertyKeyList);

#ifdef __cplusplus
}
#endif

#endif // OH_PRINT_H
/** @} */