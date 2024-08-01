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

#ifndef TASK_TUI_GP_API_H
#define TASK_TUI_GP_API_H

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
 * @file tee_tui_gp_api.h
 *
 * @brief Provides APIs for operating big integers.
 *
 * @library NA
 * @kit TEE Kit
 * @syscap SystemCapability.Tee.TeeClient
 * @since 12
 * @version 1.0
 */

#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>
#include <tee_defines.h>

#ifdef __cplusplus
extern "C" {
#endif

#define TEE_TUI_NUMBER_BUTTON_TYPES 0x00000006
#define TEE_STORAGE_PRIVATE         0x00000001
#define DEFAULT_MAX_ENTRY_FIELDS    3

#define TUI_EXIT                    8

/**
 * @brief Enumerates the modes supported when displaying characters within an input entry field.
 *
 * @since 12
 */
typedef enum {
    /** Never visible, displayed as '*'. */
    TEE_TUI_HIDDEN_MODE = 0,
    /** Always visible. */
    TEE_TUI_CLEAR_MODE,
    /** Visible then hidden. */
    TEE_TUI_TEMPORARY_CLEAR_MODE
} TEE_TUIEntryFieldMode;

/**
 * @brief Enumerates the input types supported of the TUI entry field.
 *
 * @since 12
 */
typedef enum {
    /** When the field accepts only digits as inputs. */
    TEE_TUI_NUMERICAL = 0,
    /** When the field accepts characters and digits as inputs. */
    TEE_TUI_ALPHANUMERICAL,
} TEE_TUIEntryFieldType;

/**
 * @brief Enumerates the TUI screen orientation.
 * @attention Currently {@code TEE_TUI_LANDSCAPE} is not supported.
 *
 * @since 12
 */
typedef enum {
    /** Displayed as a portrait, i.e. vertically. */
    TEE_TUI_PORTRAIT = 0,
    /** Displayed as a landscape, i.e. horizontally. */
    TEE_TUI_LANDSCAPE,
} TEE_TUIScreenOrientation;

/**
 * @brief Enumerates the types of the button.
 *
 * @since 12
 */
typedef enum {
    /** Used to delete the previous input digit. */
    TEE_TUI_CORRECTION = 0,
    /** Exits the interface. */
    TEE_TUI_OK,
    /** Cancels the operation and exits the interface. */
    TEE_TUI_CANCEL,
    /** Used to trigger PIN verifcation and exit the interface.*/
    TEE_TUI_VALIDATE,
    /** Exit the current interface and ask the TA to display the previous interface. */
    TEE_TUI_PREVIOUS,
    /** Exit the current interface and ask the TA to display the next interface. */
    TEE_TUI_NEXT,
} TEE_TUIButtonType;

/**
 * @brief Enumerates source of the uesd image.
 *
 * @since 12
 */
typedef enum {
    /** No picture provided in the input. */
    TEE_TUI_NO_SOURCE = 0,
    /** The picture provided as a memory pointer. */
    TEE_TUI_REF_SOURCE,
    /** The picture provided by an object in the secure storage. */
    TEE_TUI_OBJECT_SOURCE,
    /** The picture provided as a file. */
    TEE_TUI_FILE_SOURCE = 0x8001
} TEE_TUIImageSource;

/**
 * @brief Represents the image in PNG format.
 *
 * @since 12
 */
typedef struct {
    TEE_TUIImageSource source;
    struct {
        void *image;
        size_t imageLength;
    } ref;
    struct {
        uint32_t storageID;
        void *objectID;
        size_t objectIDLen;
    } object;
    /** Represents the number of pixels of the width of the image. */
    uint32_t width;
    /** Represents the number of pixels of the height of the image. */
    uint32_t height;
} TEE_TUIImage;

/**
 * @brief Enumerates the GP color index.
 *
 * @since 12
 */
enum gp_color_idx {
    /** Red color index. */
    RED_IDX       = 0,
    /** Green color index. */
    GREEN_IDX      = 1,
    /** Blue color index. */
    BLUE_IDX      = 2,
    /** RGB color index. */
    RGB_COLOR_IDX = 3,
};

/**
 * @brief Represents the label for TA branding/message, generally on the top of screen.
 *
 * @since 12
 */
typedef struct {
    /** It's the string to put in the label area, which can be NULL. */
    char *text;
    /** X-coordinate of the upper left corner of the text information. */
    uint32_t textXOffset;
    /** Y-coordinate of the upper left corner of the text information. */
    uint32_t textYOffset;
    /** RGB color used for displaying the text information. */
    uint8_t textColor[RGB_COLOR_IDX];
    /** The image is placed in the label area. */
    TEE_TUIImage image;
    /** X-coordinate of the upper left corner of the image to be displayed. */
    uint32_t imageXOffset;
    /** Y-coordinate of the upper left corner of the image to be displayed. */
    uint32_t imageYOffset;
} TEE_TUIScreenLabel;

/**
 * @brief Represents the content displayed on a button.
 *
 * @since 12
 */
typedef struct {
    /** It's the string to associate with the button, which can be NULL. */
    char *text;
    /** The image to associate with the button. */
    TEE_TUIImage image;
} TEE_TUIButton;

/**
 * @brief Represents the configuration about the TUI screen.
 *
 * @since 12
 */
typedef struct {
    /** The requested screen orientation. */
    TEE_TUIScreenOrientation screenOrientation;
    /** The specifies label of the screen.*/
    TEE_TUIScreenLabel label;
    /** Customizes the buttons compared to the default. */
    TEE_TUIButton *buttons[TEE_TUI_NUMBER_BUTTON_TYPES];
    /** Specifes which buttons to be displayed. */
    bool requestedButtons[TEE_TUI_NUMBER_BUTTON_TYPES];
} TEE_TUIScreenConfiguration;

/**
 * @brief Represents the information about a TUI screen button.
 * @attention The {@code buttonTextCustom} and {@code buttonImageCustom} cannot be set to true at the same time.
 *
 * @since 12
 */
typedef struct {
    /** Defaut label value of the button text. If the value is NULL means the parameter is unavailable. */
    const char *buttonText;
    /** The pixel width of the button.
     * If the text or image on the button cannot be customized, the value is <b>0</b>.
     */
    uint32_t buttonWidth;
    /** The pixel height of the button.
     * If the text or image on the button cannot be customized, the value is <b>0</b>.
     */
    uint32_t buttonHeight;
    /** If the text on the button cannot be customized, the value is true. */
    bool buttonTextCustom;
    /** If the image on the button cannot be customized, the value is true. */
    bool buttonImageCustom;
} TEE_TUIScreenButtonInfo;

/**
 * @brief Represents the information displayed on the TUI.
 *
 * @since 12
 */
typedef struct {
    /** Available grayscale. */
    uint32_t grayscaleBitsDepth;
    /** Available red depth level. */
    uint32_t redBitsDepth;
    /** Available green depth level. */
    uint32_t greenBitsDepth;
    /** Available blue depth level. */
    uint32_t blueBitsDepth;
    /** Indicates the number of pixels per inch in the width direction. */
    uint32_t widthInch;
    /** Indicates the number of pixels per inch in the height direction. */
    uint32_t heightInch;
    /** Indicates the maximum number of entries that can be displayed on the TUI. */
    uint32_t maxEntryFields;
    /** Indicates the pixel width of the input region label. */
    uint32_t entryFieldLabelWidth;
    /** Indicates the pixel height of the input region label. */
    uint32_t entryFieldLabelHeight;
    /** Indicates the maximum number of characters that can be entered in the entry field. */
    uint32_t maxEntryFieldLength;
    /** RGB value of the default label canvas. */
    uint8_t labelColor[RGB_COLOR_IDX];
    /** Indicates the pixel width of the label canvas. */
    uint32_t labelWidth;
    /** Indicates the pixel height of the label canvas. */
    uint32_t labelHeight;
    /** Indicates the information of the buttons on the interface. */
    TEE_TUIScreenButtonInfo buttonInfo[TEE_TUI_NUMBER_BUTTON_TYPES];
} TEE_TUIScreenInfo;

/**
 * @brief Represents the information in an entry field that requires user input.
 *
 * @since 12
 */
typedef struct {
    /** Indicates the label of the entry field. */
    char *label;
    /** Indicates the mode used to display characters. */
    TEE_TUIEntryFieldMode mode;
    /** Indicates the type of the characters can be entered in the entry field. */
    TEE_TUIEntryFieldType type;
    /** The minimum number of characters to be entered. */
    uint32_t minExpectedLength;
    /** The maximum number of characters to be entered. */
    uint32_t maxExpectedLength;
    /** Contains the content entered by user. */
    char *buffer;
    /** Indicates the length of the buffer. */
    size_t bufferLength;
} TEE_TUIEntryField;

/**
 * @brief Initializing the TUI resources.
 *
 * @return Returns {@code TEE_SUCCESS} if the operation is successful.
 *         Returns {@code TEE_ERROR_BAD_PARAMETERS} if input parameter is incorrect.
 *         Returns {@code TEE_ERROR_NOT_SUPPORTED} if the device is not support TUI.
 *         Returns {@code TEE_ERROR_BUSY} if the TUI resources cannot be reserved.
 *         Returns {@code TEE_ERROR_OUT_OF_MEMORY} if the system ran out of the resources.
 *
 * @since 12
 * @version 1.0
 */
TEE_Result TEE_TUIInitSession(void);


/**
 * @brief Releases TUI resources previously acquired.
 *
 * @return Returns {@code TEE_SUCCESS} if the operation is successful.
 *         Returns {@code TEE_ERROR_BAD_STATE} if the current TA is not within a TUI session initially
 * started by a successful call to {@code TEE_TUIInitSession}.
 *         Returns {@code TEE_ERROR_BUSY} if the TUI resources currently are in use.
 *
 * @since 12
 * @version 1.0
 */
TEE_Result TEE_TUICloseSession(void);

/**
 * @brief Allows a TA to check whether a given text can be rendered by the current implementation and
 * retrieves information about the size and width that is needed to render it.
 *
 * @param text Indicates the string to be checked.
 * @param width Indicates the width in pixels needed to render the text.
 * @param height Indicates the height in pixels needed to render the text.
 * @param last_index Indicates the last character that has been checked
 *
 * @return Returns {@code TEE_SUCCESS} if the operation is successful.
 *         Returns {@code TEE_ERROR_NOT_SUPPORTED} if at least one of the characters present
 * in the text string cannot be rendered.
 *
 * @since 12
 * @version 1.0
 */
TEE_Result TEE_TUICheckTextFormat(const char *text, uint32_t *width, uint32_t *height, uint32_t *last_index);

/**
 * @brief Retrieves information about the screen depending on its orientation and
 * the number of required entry fields.
 *
 * @param screenOrientation Defines for which orientation screen information is requested.
 * @param nbEntryFields Indicates the number of the requested entry fields.
 * @param screenInfo Indicates the information on the requested screen for a given orientation.
 *
 * @return Returns {@code TEE_SUCCESS} if the operation is successful.
 *         Returns {@code TEE_ERROR_NOT_SUPPORTED} if the number of entry fields is not supported.
 *
 * @since 12
 * @version 1.0
 */
TEE_Result TEE_TUIGetScreenInfo(TEE_TUIScreenOrientation screenOrientation,
                                uint32_t nbEntryFields,
                                TEE_TUIScreenInfo *screenInfo);
/**
 * @brief Display a TUI screen.
 *
 * @param screenConfiguration Indicates the configuration of the labels and optional buttons on the display interface.
 * @param closeTUISession If the value is true, the TUI session will automatically closed when exiting the function.
 * @param entryFields Indicates the information of entry field.
 * @param entryFieldCount Indicates the count of the entry fields.
 * @param selectedButton Indicates which button has been selected by the user to exit the TUI screen.
 *
 * @return Returns {@code TEE_SUCCESS} if the operation is successful.
 *         Returns {@code TEE_ERROR_OUT_OF_MEMORY} if the system ran out of the resources.
 *         Returns {@code TEE_ERROR_ITEM_NOT_FOUND} if at least one image provided by the TA refers to a storage
 * denoted by a storageID which dose not exist or if the corresponding object identifier cannot be found in the storage.
 *         Returns {@code TEE_ERROR_ACCESS_CONFLICT} if at least one image provided by the TA refers to a data
 * object in the trusted storage and an access right conflict was detected while opening the object.
 *         Returns {@code TEE_ERROR_BAD_FORMAT} if at least one input image is not compliant with PNG format.
 *         Returns {@code TEE_ERROR_BAD_STATE} if the current TA is not within a TUI session
 * initially started by a successful call to {@code TEE_TUIInitSession}.
 *         Returns {@code TEE_ERROR_BUSY} if the TUI resources are currently in use, i.e. a TUI screen is displayed.
 *         Returns {@code TEE_ERROR_CANCEL} if the operation has been cancelled while a TUI screen is currently
 * displayed.
 *         Returns {@code TEE_ERROR_EXTERNAL_CANCEL} if the operation has been cancelled by an external event which
 * occurred in the REE while a TUI screen is currently displayed.
 *
 * @since 12
 * @version 1.0
 */
TEE_Result TEE_TUIDisplayScreen(TEE_TUIScreenConfiguration *screenConfiguration,
                                bool closeTUISession,
                                TEE_TUIEntryField *entryFields,
                                uint32_t entryFieldCount,
                                TEE_TUIButtonType *selectedButton);

/**
 * @brief Fringerprint identification port.
 *
 * @return Returns {@code TEE_SUCCESS} if the operation is successful.
 *         Returns {@code TEE_ERROR_NOT_SUPPORTED} if the device is not support TUI.
 *
 * @since 12
 * @version 1.0
 */
TEE_Result TEE_TUINotify_fp(void);

/**
 * @brief Set the Chinese character encoding. The system supports UTF-8 by default.
 *
 * @param type Indicates the encoding type. The value 1 indicates GBK. Other values are not supported.
 *
 * @return Returns {@code TEE_SUCCESS} if the operation is successful.
 *         Returns {@code TEE_ERROR_NOT_SUPPORTED} if the device is not support this function.
 *         Returns {@code TEE_ERROR_BAD_PARAMETERS} if input parameter is incorrect.
 *
 * @since 12
 * @version 1.0
 */
TEE_Result TEE_TUISetInfo(int32_t type);

/**
 * @brief Send message to TUI.
 *
 * @param type Indicates the messages send to the TUI. Only support {@code TUI_EXIT}.
 *
 * @return Returns {@code TEE_SUCCESS} if the operation is successful.
 *         Returns {@code TEE_ERROR_BAD_PARAMETERS} if input parameter is incorrect.
 *
 * @since 12
 * @version 1.0
 */
TEE_Result TEE_TUISendEvent(int32_t type);

/**
 * @brief Setting the TUI background image.
 *
 * @param label Configure the background image information in the label variable.
 * The image must be a PNG image in array format.
 * @param len   Indicates the label size.
 *
 * @return Returns {@code TEE_SUCCESS} if the operation is successful.
 *         Returns {@code TEE_ERROR_GENERIC} if input parameter is incorrect.
 *         Returns {@code TEE_ERROR_ACCESS_DENIED} if the permission verification failed.
 *
 * @since 12
 * @version 1.0
 */
TEE_Result TEE_TUISetLabel(TEE_TUIScreenLabel *label, uint32_t len);
#ifdef __cplusplus
}
#endif
/** @} */
#endif