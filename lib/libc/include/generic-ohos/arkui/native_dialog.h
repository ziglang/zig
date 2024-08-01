/*
 * Copyright (c) 2024 Huawei Device Co., Ltd.
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

#ifndef ARKUI_NATIVE_DIALOG_H
#define ARKUI_NATIVE_DIALOG_H

#include "native_type.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
* @brief Enumerates the actions for triggering closure of the dialog box.
*
* @since 12
*/
typedef enum {
    /** Touching the system-defined Back button or pressing the Esc key. */
    DIALOG_DISMISS_BACK_PRESS = 0,
    /** Touching the mask. */
    DIALOG_DISMISS_TOUCH_OUTSIDE,
} ArkUI_DismissReason;

/**
* @brief Invoked when the dialog box is closed.
*
* @since 12
*/
typedef bool (*ArkUI_OnWillDismissEvent)(int32_t reason);

/**
 * @brief Provides the custom dialog box APIs for the native side.
 *
 * @version 1
 * @since 12
 */
typedef struct {
    /**
    * @brief Creates a custom dialog box and returns the pointer to the created dialog box.
    *
    * @note This method must be called before the <b>show</b> method.
    * @return Returns the pointer to the created custom dialog box; returns a null pointer if the creation fails.
    */
    ArkUI_NativeDialogHandle (*create)();
    /**
    * @brief Destroys a custom dialog box.
    *
    * @param handle Indicates the pointer to the custom dialog box controller.
    */
    void (*dispose)(ArkUI_NativeDialogHandle handle);
    /**
    * @brief Attaches the content of a custom dialog box.
    *
    * @note This method must be called before the <b>show</b> method.
    * @param handle Indicates the pointer to the custom dialog box controller.
    * @param content Indicates the pointer to the root node of the custom dialog box content.
    * @return Returns the error code.
    *         Returns {@link ARKUI_ERROR_CODE_NO_ERROR} if the operation is successful.
    *         Returns {@link ARKUI_ERROR_CODE_PARAM_INVALID} if a parameter error occurs.
    */
    int32_t (*setContent)(ArkUI_NativeDialogHandle handle, ArkUI_NodeHandle content);
    /**
    * @brief Detaches the content of a custom dialog box.
    *
    * @note This method must be called before the <b>show</b> method.
    * @param handle Indicates the pointer to the custom dialog box controller.
    * @return Returns the error code.
    *         Returns {@link ARKUI_ERROR_CODE_NO_ERROR} if the operation is successful.
    *         Returns {@link ARKUI_ERROR_CODE_PARAM_INVALID} if a parameter error occurs.
    */
    int32_t (*removeContent)(ArkUI_NativeDialogHandle handle);
    /**
    * @brief Sets the alignment mode for a custom dialog box.
    *
    * @note This method must be called before the <b>show</b> method.
    * @param handle Indicates the pointer to the custom dialog box controller.
    * @param alignment Indicates the alignment mode. The parameter type is {@link ArkUI_Alignment}.
    * @param offsetX Indicates the horizontal offset of the custom dialog box. The value is a floating point number.
    * @param offsetY Indicates the vertical offset of the custom dialog box. The value is a floating point number.
    * @return Returns the error code.
    *         Returns {@link ARKUI_ERROR_CODE_NO_ERROR} if the operation is successful.
    *         Returns {@link ARKUI_ERROR_CODE_PARAM_INVALID} if a parameter error occurs.
    */
    int32_t (*setContentAlignment)(ArkUI_NativeDialogHandle handle, int32_t alignment, float offsetX, float offsetY);
    /**
    * @brief Resets the alignment mode of a custom dialog box to its default settings.
    *
    * @note This method must be called before the <b>show</b> method.
    * @param handle Indicates the pointer to the custom dialog box controller.
    * @return Returns the error code.
    *         Returns {@link ARKUI_ERROR_CODE_NO_ERROR} if the operation is successful.
    *         Returns {@link ARKUI_ERROR_CODE_PARAM_INVALID} if a parameter error occurs.
    */
    int32_t (*resetContentAlignment)(ArkUI_NativeDialogHandle handle);
    /**
    * @brief Sets the modal mode for a custom dialog box.
    *
    * @note This method must be called before the <b>show</b> method.
    * @param handle Indicates the pointer to the custom dialog box controller.
    * @param isModal Specifies whether the custom dialog box is a modal, which has a mask applied. The value
    * <b>true</b> means that the custom dialog box is a modal, and <b>false</b> means the opposite.
    * @return Returns the error code.
    *         Returns {@link ARKUI_ERROR_CODE_NO_ERROR} if the operation is successful.
    *         Returns {@link ARKUI_ERROR_CODE_PARAM_INVALID} if a parameter error occurs.
    */
    int32_t (*setModalMode)(ArkUI_NativeDialogHandle handle, bool isModal);
    /**
    * @brief Specifies whether to allow users to touch the mask to dismiss the custom dialog box.
    *
    * @note This method must be called before the <b>show</b> method.
    * @param handle Indicates the pointer to the custom dialog box controller.
    * @param autoCancel Specifies whether to allow users to touch the mask to dismiss the dialog box.
    * The value <b>true</b> means to allow users to do so, and <b>false</b> means the opposite.
    * @return Returns the error code.
    *         Returns {@link ARKUI_ERROR_CODE_NO_ERROR} if the operation is successful.
    *         Returns {@link ARKUI_ERROR_CODE_PARAM_INVALID} if a parameter error occurs.
    */
    int32_t (*setAutoCancel)(ArkUI_NativeDialogHandle handle, bool autoCancel);
    /**
    * @brief Sets the mask for a custom dialog box.
    *
    * @note This method must be called before the <b>show</b> method.
    * @param handle Indicates the pointer to the custom dialog box controller.
    * @param maskColor Indicates the mask color, in 0xARGB format.
    * @param maskRect Indicates the pointer to the mask area. Events outside the mask area are transparently
    * transmitted, and events within the mask area are not. The parameter type is {@link ArkUI_Rect}.
    * @return Returns the error code.
    *         Returns {@link ARKUI_ERROR_CODE_NO_ERROR} if the operation is successful.
    *         Returns {@link ARKUI_ERROR_CODE_PARAM_INVALID} if a parameter error occurs.
    */
    int32_t (*setMask)(ArkUI_NativeDialogHandle handle, uint32_t maskColor, const ArkUI_Rect* maskRect);
    /**
    * @brief Sets the background color for a custom dialog box.
    *
    * @note This method must be called before the <b>show</b> method.
    * @param handle Indicates the pointer to the custom dialog box controller.
    * @param backgroundColor Indicates the background color of the custom dialog box, in 0xARGB format.
    * @return Returns the error code.
    *         Returns {@link ARKUI_ERROR_CODE_NO_ERROR} if the operation is successful.
    *         Returns {@link ARKUI_ERROR_CODE_PARAM_INVALID} if a parameter error occurs.
    */
    int32_t (*setBackgroundColor)(ArkUI_NativeDialogHandle handle, uint32_t backgroundColor);
    /**
    * @brief Sets the background corner radius for a custom dialog box.
    *
    * @note This method must be called before the <b>show</b> method.
    * @param handle Indicates the pointer to the custom dialog box controller.
    * @param topLeft Indicates the radius of the upper left corner of the custom dialog box background.
    * @param topRight Indicates the radius of the upper right corner of the custom dialog box background.
    * @param bottomLeft Indicates the radius of the lower left corner of the custom dialog box background.
    * @param bottomRight Indicates the radius of the lower right corner of the custom dialog box background.
    * @return Returns the error code.
    *         Returns {@link ARKUI_ERROR_CODE_NO_ERROR} if the operation is successful.
    *         Returns {@link ARKUI_ERROR_CODE_PARAM_INVALID} if a parameter error occurs.
    */
    int32_t (*setCornerRadius)(ArkUI_NativeDialogHandle handle, float topLeft, float topRight,
        float bottomLeft, float bottomRight);
    /**
    * @brief Sets the number of grid columns occupied by a custom dialog box.
    *
    * @note This method must be called before the <b>show</b> method.
    * @param handle Indicates the pointer to the custom dialog box controller.
    * @param gridCount Indicates the number of grid columns occupied by the dialog box. The default value is subject to
    * the window size, and the maximum value is the maximum number of columns supported by the system.
    * @return Returns the error code.
    *         Returns {@link ARKUI_ERROR_CODE_NO_ERROR} if the operation is successful.
    *         Returns {@link ARKUI_ERROR_CODE_PARAM_INVALID} if a parameter error occurs.
    */
    int32_t (*setGridColumnCount)(ArkUI_NativeDialogHandle handle, int32_t gridCount);
    /**
    * @brief Specifies whether to use a custom style for the custom dialog box.
    *
    * @note This method must be called before the <b>show</b> method.
    * @param handle Indicates the pointer to the custom dialog box controller.
    * @param enableCustomStyle Specifies whether to use a custom style for the dialog box.
    * <b>true</b>: The dialog box automatically adapts its width to the child components; the rounded corner is 0;
    * the background color is transparent.
    * <b>false</b>: The dialog box automatically adapts its width to the grid system and its height to the child
    * components; the rounded corner is 24 vp.
    * @return Returns the error code.
    *         Returns {@link ARKUI_ERROR_CODE_NO_ERROR} if the operation is successful.
    *         Returns {@link ARKUI_ERROR_CODE_PARAM_INVALID} if a parameter error occurs.
    */
    int32_t (*enableCustomStyle)(ArkUI_NativeDialogHandle handle, bool enableCustomStyle);
    /**
    * @brief Specifies whether to use a custom animation for a custom dialog box.
    *
    * @note This method must be called before the <b>show</b> method.
    * @param handle Indicates the pointer to the custom dialog box controller.
    * @param enableCustomAnimation Specifies whether to use a custom animation. The value <b>true</b> means to use a
    * custom animation, and <b>false</b> means to use the default animation.
    * @return Returns the error code.
    *         Returns {@link ARKUI_ERROR_CODE_NO_ERROR} if the operation is successful.
    *         Returns {@link ARKUI_ERROR_CODE_PARAM_INVALID} if a parameter error occurs.
    */
    int32_t (*enableCustomAnimation)(ArkUI_NativeDialogHandle handle, bool enableCustomAnimation);
    /**
    * @brief Registers a callback for a custom dialog box so that the user can decide whether to close the dialog box
    * after they touch the Back button or press the Esc key.
    *
    * @note This method must be called before the <b>show</b> method.
    * @param handle Indicates the pointer to the custom dialog box controller.
    * @param eventHandler Indicates the callback to register. The parameter type is {@link ArkUI_OnWillDismissEvent}.
    * @return Returns the error code.
    *         Returns {@link ARKUI_ERROR_CODE_NO_ERROR} if the operation is successful.
    *         Returns {@link ARKUI_ERROR_CODE_PARAM_INVALID} if a parameter error occurs.
    */
    int32_t (*registerOnWillDismiss)(ArkUI_NativeDialogHandle handle, ArkUI_OnWillDismissEvent eventHandler);
    /**
    * @brief Shows a custom dialog box.
    *
    * @param handle Indicates the pointer to the custom dialog box controller.
    * @param showInSubWindow Specifies whether to show the dialog box in a sub-window.
    * @return Returns the error code.
    *         Returns {@link ARKUI_ERROR_CODE_NO_ERROR} if the operation is successful.
    *         Returns {@link ARKUI_ERROR_CODE_PARAM_INVALID} if a parameter error occurs.
    */
    int32_t (*show)(ArkUI_NativeDialogHandle handle, bool showInSubWindow);
    /**
    * @brief Closes a custom dialog box. If the dialog box has been closed, this API does not take effect.
    *
    * @param handle Indicates the pointer to the custom dialog box controller.
    * @return Returns the error code.
    *         Returns {@link ARKUI_ERROR_CODE_NO_ERROR} if the operation is successful.
    *         Returns {@link ARKUI_ERROR_CODE_PARAM_INVALID} if a parameter error occurs.
    */
    int32_t (*close)(ArkUI_NativeDialogHandle handle);
} ArkUI_NativeDialogAPI_1;

#ifdef __cplusplus
};
#endif

#endif // ARKUI_NATIVE_DIALOG_H