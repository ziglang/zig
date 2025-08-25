/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef __MSPTHRD_H
#define __MSPTHRD_H

typedef enum {
  WORK_ITEM,STOP
} COMMAND;

typedef struct {
  COMMAND cmd;
  LPTHREAD_START_ROUTINE pfn;
  PVOID pContext;
  HANDLE hEvent;
} COMMAND_NODE;

typedef struct {
  LIST_ENTRY link;
  COMMAND_NODE node;
} COMMAND_QUEUE_ITEM;

typedef struct _NOTIF_LIST {
  CMSPAddress *addr;
  _NOTIF_LIST *next;
} NOTIF_LIST,*PNOTIF_LIST;

class CMSPThread {
public:
  CMSPThread() {
    InitializeListHead(&m_CommandQueue);
    m_hCommandEvent = NULL;
    m_hThread = NULL;
    m_NotifList = NULL;
    m_iStartCount = 0;
  }
  ~CMSPThread() { };
  HRESULT Start();
  HRESULT Stop();
  HRESULT Shutdown();
  HRESULT ThreadProc();
  static LRESULT CALLBACK NotifWndProc(HWND hwnd,UINT uMsg,WPARAM wParam,LPARAM lParam);
  HRESULT RegisterPnpNotification(CMSPAddress *pCMSPAddress);
  HRESULT UnregisterPnpNotification(CMSPAddress *pCMSPAddress);
  HRESULT QueueWorkItem(LPTHREAD_START_ROUTINE Function,PVOID Context,WINBOOL fSynchronous);
private:
  WINBOOL SignalThreadProc() { return SetEvent(m_hCommandEvent); }
  CMSPCritSection m_CountLock;
  CMSPCritSection m_QueueLock;
  int m_iStartCount;
  LIST_ENTRY m_CommandQueue;
  HANDLE m_hCommandEvent;
  HANDLE m_hThread;
  HDEVNOTIFY m_hDevNotifyVideo;
  HDEVNOTIFY m_hDevNotifyAudio;
  HWND m_hWndNotif;
  PNOTIF_LIST m_NotifList;
  CMSPCritSection m_NotifLock;
};

extern CMSPThread g_Thread;
#endif
