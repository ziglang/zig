/*
 * gdiplusinit.h
 *
 * GDI+ Initialization
 *
 * This file is part of the w32api package.
 *
 * Contributors:
 *   Created by Markus Koenig <markus@stber-koenig.de>
 *
 * THIS SOFTWARE IS NOT COPYRIGHTED
 *
 * This source code is offered for use in the public domain. You may
 * use, modify or distribute it freely.
 *
 * This code is distributed in the hope that it will be useful but
 * WITHOUT ANY WARRANTY. ALL WARRANTIES, EXPRESS OR IMPLIED ARE HEREBY
 * DISCLAIMED. This includes but is not limited to warranties of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 */

#ifndef __GDIPLUS_INIT_H
#define __GDIPLUS_INIT_H
#if __GNUC__ >=3
#pragma GCC system_header
#endif

typedef struct GdiplusStartupInput {
	UINT32 GdiplusVersion;
	DebugEventProc DebugEventCallback;
	BOOL SuppressBackgroundThread;
	BOOL SuppressExternalCodecs;

	#ifdef __cplusplus
	GdiplusStartupInput(DebugEventProc debugEventCallback = NULL,
	                    BOOL suppressBackgroundThread = FALSE,
	                    BOOL suppressExternalCodecs = FALSE):
		GdiplusVersion(1),
		DebugEventCallback(debugEventCallback),
		SuppressBackgroundThread(suppressBackgroundThread),
		SuppressExternalCodecs(suppressExternalCodecs) {}
	#endif /* __cplusplus */
} GdiplusStartupInput;

typedef GpStatus (WINGDIPAPI *NotificationHookProc)(ULONG_PTR *token);
typedef VOID (WINGDIPAPI *NotificationUnhookProc)(ULONG_PTR token);

typedef struct GdiplusStartupOutput {
	NotificationHookProc NotificationHook;
	NotificationUnhookProc NotificationUnhook;

	#ifdef __cplusplus
	GdiplusStartupOutput():
		NotificationHook(NULL),
		NotificationUnhook(NULL) {}
	#endif /* __cplusplus */
} GdiplusStartupOutput;

#ifdef __cplusplus
extern "C" {
#endif

GpStatus WINGDIPAPI GdiplusStartup(ULONG_PTR*,GDIPCONST GdiplusStartupInput*,GdiplusStartupOutput*);
VOID WINGDIPAPI GdiplusShutdown(ULONG_PTR);
GpStatus WINGDIPAPI GdiplusNotificationHook(ULONG_PTR*);
VOID WINGDIPAPI GdiplusNotificationUnhook(ULONG_PTR);

#ifdef __cplusplus
}  /* extern "C" */
#endif


#endif /* __GDIPLUS_INIT_H */
