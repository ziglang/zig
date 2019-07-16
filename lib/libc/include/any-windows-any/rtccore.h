/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef __REQUIRED_RPCNDR_H_VERSION__
#define __REQUIRED_RPCNDR_H_VERSION__ 475
#endif

#include "rpc.h"
#include "rpcndr.h"

#ifndef __RPCNDR_H_VERSION__
#error This stub requires an updated version of <rpcndr.h>
#endif

#ifndef COM_NO_WINDOWS_H
#include "windows.h"
#include "ole2.h"
#endif

#ifndef __rtccore_h__
#define __rtccore_h__

#ifndef __IRTCClient_FWD_DEFINED__
#define __IRTCClient_FWD_DEFINED__
typedef struct IRTCClient IRTCClient;
#endif

#ifndef __IRTCClient2_FWD_DEFINED__
#define __IRTCClient2_FWD_DEFINED__
typedef struct IRTCClient2 IRTCClient2;
#endif

#ifndef __IRTCClientPresence_FWD_DEFINED__
#define __IRTCClientPresence_FWD_DEFINED__
typedef struct IRTCClientPresence IRTCClientPresence;
#endif

#ifndef __IRTCClientPresence2_FWD_DEFINED__
#define __IRTCClientPresence2_FWD_DEFINED__
typedef struct IRTCClientPresence2 IRTCClientPresence2;
#endif

#ifndef __IRTCClientProvisioning_FWD_DEFINED__
#define __IRTCClientProvisioning_FWD_DEFINED__
typedef struct IRTCClientProvisioning IRTCClientProvisioning;
#endif

#ifndef __IRTCClientProvisioning2_FWD_DEFINED__
#define __IRTCClientProvisioning2_FWD_DEFINED__
typedef struct IRTCClientProvisioning2 IRTCClientProvisioning2;
#endif

#ifndef __IRTCProfile_FWD_DEFINED__
#define __IRTCProfile_FWD_DEFINED__
typedef struct IRTCProfile IRTCProfile;
#endif

#ifndef __IRTCProfile2_FWD_DEFINED__
#define __IRTCProfile2_FWD_DEFINED__
typedef struct IRTCProfile2 IRTCProfile2;
#endif

#ifndef __IRTCSession_FWD_DEFINED__
#define __IRTCSession_FWD_DEFINED__
typedef struct IRTCSession IRTCSession;
#endif

#ifndef __IRTCSession2_FWD_DEFINED__
#define __IRTCSession2_FWD_DEFINED__
typedef struct IRTCSession2 IRTCSession2;
#endif

#ifndef __IRTCSessionCallControl_FWD_DEFINED__
#define __IRTCSessionCallControl_FWD_DEFINED__
typedef struct IRTCSessionCallControl IRTCSessionCallControl;
#endif

#ifndef __IRTCParticipant_FWD_DEFINED__
#define __IRTCParticipant_FWD_DEFINED__
typedef struct IRTCParticipant IRTCParticipant;
#endif

#ifndef __IRTCRoamingEvent_FWD_DEFINED__
#define __IRTCRoamingEvent_FWD_DEFINED__
typedef struct IRTCRoamingEvent IRTCRoamingEvent;
#endif

#ifndef __IRTCProfileEvent_FWD_DEFINED__
#define __IRTCProfileEvent_FWD_DEFINED__
typedef struct IRTCProfileEvent IRTCProfileEvent;
#endif

#ifndef __IRTCProfileEvent2_FWD_DEFINED__
#define __IRTCProfileEvent2_FWD_DEFINED__
typedef struct IRTCProfileEvent2 IRTCProfileEvent2;
#endif

#ifndef __IRTCClientEvent_FWD_DEFINED__
#define __IRTCClientEvent_FWD_DEFINED__
typedef struct IRTCClientEvent IRTCClientEvent;
#endif

#ifndef __IRTCRegistrationStateChangeEvent_FWD_DEFINED__
#define __IRTCRegistrationStateChangeEvent_FWD_DEFINED__
typedef struct IRTCRegistrationStateChangeEvent IRTCRegistrationStateChangeEvent;
#endif

#ifndef __IRTCSessionStateChangeEvent_FWD_DEFINED__
#define __IRTCSessionStateChangeEvent_FWD_DEFINED__
typedef struct IRTCSessionStateChangeEvent IRTCSessionStateChangeEvent;
#endif

#ifndef __IRTCSessionStateChangeEvent2_FWD_DEFINED__
#define __IRTCSessionStateChangeEvent2_FWD_DEFINED__
typedef struct IRTCSessionStateChangeEvent2 IRTCSessionStateChangeEvent2;
#endif

#ifndef __IRTCSessionOperationCompleteEvent_FWD_DEFINED__
#define __IRTCSessionOperationCompleteEvent_FWD_DEFINED__
typedef struct IRTCSessionOperationCompleteEvent IRTCSessionOperationCompleteEvent;
#endif

#ifndef __IRTCSessionOperationCompleteEvent2_FWD_DEFINED__
#define __IRTCSessionOperationCompleteEvent2_FWD_DEFINED__
typedef struct IRTCSessionOperationCompleteEvent2 IRTCSessionOperationCompleteEvent2;
#endif

#ifndef __IRTCParticipantStateChangeEvent_FWD_DEFINED__
#define __IRTCParticipantStateChangeEvent_FWD_DEFINED__
typedef struct IRTCParticipantStateChangeEvent IRTCParticipantStateChangeEvent;
#endif

#ifndef __IRTCMediaEvent_FWD_DEFINED__
#define __IRTCMediaEvent_FWD_DEFINED__
typedef struct IRTCMediaEvent IRTCMediaEvent;
#endif

#ifndef __IRTCIntensityEvent_FWD_DEFINED__
#define __IRTCIntensityEvent_FWD_DEFINED__
typedef struct IRTCIntensityEvent IRTCIntensityEvent;
#endif

#ifndef __IRTCMessagingEvent_FWD_DEFINED__
#define __IRTCMessagingEvent_FWD_DEFINED__
typedef struct IRTCMessagingEvent IRTCMessagingEvent;
#endif

#ifndef __IRTCBuddyEvent_FWD_DEFINED__
#define __IRTCBuddyEvent_FWD_DEFINED__
typedef struct IRTCBuddyEvent IRTCBuddyEvent;
#endif

#ifndef __IRTCBuddyEvent2_FWD_DEFINED__
#define __IRTCBuddyEvent2_FWD_DEFINED__
typedef struct IRTCBuddyEvent2 IRTCBuddyEvent2;
#endif

#ifndef __IRTCWatcherEvent_FWD_DEFINED__
#define __IRTCWatcherEvent_FWD_DEFINED__
typedef struct IRTCWatcherEvent IRTCWatcherEvent;
#endif

#ifndef __IRTCWatcherEvent2_FWD_DEFINED__
#define __IRTCWatcherEvent2_FWD_DEFINED__
typedef struct IRTCWatcherEvent2 IRTCWatcherEvent2;
#endif

#ifndef __IRTCBuddyGroupEvent_FWD_DEFINED__
#define __IRTCBuddyGroupEvent_FWD_DEFINED__
typedef struct IRTCBuddyGroupEvent IRTCBuddyGroupEvent;
#endif

#ifndef __IRTCInfoEvent_FWD_DEFINED__
#define __IRTCInfoEvent_FWD_DEFINED__
typedef struct IRTCInfoEvent IRTCInfoEvent;
#endif

#ifndef __IRTCMediaRequestEvent_FWD_DEFINED__
#define __IRTCMediaRequestEvent_FWD_DEFINED__
typedef struct IRTCMediaRequestEvent IRTCMediaRequestEvent;
#endif

#ifndef __IRTCReInviteEvent_FWD_DEFINED__
#define __IRTCReInviteEvent_FWD_DEFINED__
typedef struct IRTCReInviteEvent IRTCReInviteEvent;
#endif

#ifndef __IRTCPresencePropertyEvent_FWD_DEFINED__
#define __IRTCPresencePropertyEvent_FWD_DEFINED__
typedef struct IRTCPresencePropertyEvent IRTCPresencePropertyEvent;
#endif

#ifndef __IRTCPresenceDataEvent_FWD_DEFINED__
#define __IRTCPresenceDataEvent_FWD_DEFINED__
typedef struct IRTCPresenceDataEvent IRTCPresenceDataEvent;
#endif

#ifndef __IRTCPresenceStatusEvent_FWD_DEFINED__
#define __IRTCPresenceStatusEvent_FWD_DEFINED__
typedef struct IRTCPresenceStatusEvent IRTCPresenceStatusEvent;
#endif

#ifndef __IRTCCollection_FWD_DEFINED__
#define __IRTCCollection_FWD_DEFINED__
typedef struct IRTCCollection IRTCCollection;
#endif

#ifndef __IRTCEnumParticipants_FWD_DEFINED__
#define __IRTCEnumParticipants_FWD_DEFINED__
typedef struct IRTCEnumParticipants IRTCEnumParticipants;
#endif

#ifndef __IRTCEnumProfiles_FWD_DEFINED__
#define __IRTCEnumProfiles_FWD_DEFINED__
typedef struct IRTCEnumProfiles IRTCEnumProfiles;
#endif

#ifndef __IRTCEnumBuddies_FWD_DEFINED__
#define __IRTCEnumBuddies_FWD_DEFINED__
typedef struct IRTCEnumBuddies IRTCEnumBuddies;
#endif

#ifndef __IRTCEnumWatchers_FWD_DEFINED__
#define __IRTCEnumWatchers_FWD_DEFINED__
typedef struct IRTCEnumWatchers IRTCEnumWatchers;
#endif

#ifndef __IRTCEnumGroups_FWD_DEFINED__
#define __IRTCEnumGroups_FWD_DEFINED__
typedef struct IRTCEnumGroups IRTCEnumGroups;
#endif

#ifndef __IRTCPresenceContact_FWD_DEFINED__
#define __IRTCPresenceContact_FWD_DEFINED__
typedef struct IRTCPresenceContact IRTCPresenceContact;
#endif

#ifndef __IRTCBuddy_FWD_DEFINED__
#define __IRTCBuddy_FWD_DEFINED__
typedef struct IRTCBuddy IRTCBuddy;
#endif

#ifndef __IRTCBuddy2_FWD_DEFINED__
#define __IRTCBuddy2_FWD_DEFINED__
typedef struct IRTCBuddy2 IRTCBuddy2;
#endif

#ifndef __IRTCWatcher_FWD_DEFINED__
#define __IRTCWatcher_FWD_DEFINED__
typedef struct IRTCWatcher IRTCWatcher;
#endif

#ifndef __IRTCWatcher2_FWD_DEFINED__
#define __IRTCWatcher2_FWD_DEFINED__
typedef struct IRTCWatcher2 IRTCWatcher2;
#endif

#ifndef __IRTCBuddyGroup_FWD_DEFINED__
#define __IRTCBuddyGroup_FWD_DEFINED__
typedef struct IRTCBuddyGroup IRTCBuddyGroup;
#endif

#ifndef __IRTCEventNotification_FWD_DEFINED__
#define __IRTCEventNotification_FWD_DEFINED__
typedef struct IRTCEventNotification IRTCEventNotification;
#endif

#ifndef __IRTCDispatchEventNotification_FWD_DEFINED__
#define __IRTCDispatchEventNotification_FWD_DEFINED__
typedef struct IRTCDispatchEventNotification IRTCDispatchEventNotification;
#endif

#ifndef __IRTCPortManager_FWD_DEFINED__
#define __IRTCPortManager_FWD_DEFINED__
typedef struct IRTCPortManager IRTCPortManager;
#endif

#ifndef __IRTCSessionPortManagement_FWD_DEFINED__
#define __IRTCSessionPortManagement_FWD_DEFINED__
typedef struct IRTCSessionPortManagement IRTCSessionPortManagement;
#endif

#ifndef __IRTCClientPortManagement_FWD_DEFINED__
#define __IRTCClientPortManagement_FWD_DEFINED__
typedef struct IRTCClientPortManagement IRTCClientPortManagement;
#endif

#ifndef __IRTCUserSearch_FWD_DEFINED__
#define __IRTCUserSearch_FWD_DEFINED__
typedef struct IRTCUserSearch IRTCUserSearch;
#endif

#ifndef __IRTCUserSearchQuery_FWD_DEFINED__
#define __IRTCUserSearchQuery_FWD_DEFINED__
typedef struct IRTCUserSearchQuery IRTCUserSearchQuery;
#endif

#ifndef __IRTCUserSearchResult_FWD_DEFINED__
#define __IRTCUserSearchResult_FWD_DEFINED__
typedef struct IRTCUserSearchResult IRTCUserSearchResult;
#endif

#ifndef __IRTCEnumUserSearchResults_FWD_DEFINED__
#define __IRTCEnumUserSearchResults_FWD_DEFINED__
typedef struct IRTCEnumUserSearchResults IRTCEnumUserSearchResults;
#endif

#ifndef __IRTCUserSearchResultsEvent_FWD_DEFINED__
#define __IRTCUserSearchResultsEvent_FWD_DEFINED__
typedef struct IRTCUserSearchResultsEvent IRTCUserSearchResultsEvent;
#endif

#ifndef __IRTCSessionReferStatusEvent_FWD_DEFINED__
#define __IRTCSessionReferStatusEvent_FWD_DEFINED__
typedef struct IRTCSessionReferStatusEvent IRTCSessionReferStatusEvent;
#endif

#ifndef __IRTCSessionReferredEvent_FWD_DEFINED__
#define __IRTCSessionReferredEvent_FWD_DEFINED__
typedef struct IRTCSessionReferredEvent IRTCSessionReferredEvent;
#endif

#ifndef __IRTCSessionDescriptionManager_FWD_DEFINED__
#define __IRTCSessionDescriptionManager_FWD_DEFINED__
typedef struct IRTCSessionDescriptionManager IRTCSessionDescriptionManager;
#endif

#ifndef __IRTCEnumPresenceDevices_FWD_DEFINED__
#define __IRTCEnumPresenceDevices_FWD_DEFINED__
typedef struct IRTCEnumPresenceDevices IRTCEnumPresenceDevices;
#endif

#ifndef __IRTCPresenceDevice_FWD_DEFINED__
#define __IRTCPresenceDevice_FWD_DEFINED__
typedef struct IRTCPresenceDevice IRTCPresenceDevice;
#endif

#ifndef __IRTCProfile_FWD_DEFINED__
#define __IRTCProfile_FWD_DEFINED__
typedef struct IRTCProfile IRTCProfile;
#endif

#ifndef __IRTCProfile2_FWD_DEFINED__
#define __IRTCProfile2_FWD_DEFINED__
typedef struct IRTCProfile2 IRTCProfile2;
#endif

#ifndef __IRTCEnumProfiles_FWD_DEFINED__
#define __IRTCEnumProfiles_FWD_DEFINED__
typedef struct IRTCEnumProfiles IRTCEnumProfiles;
#endif

#ifndef __IRTCSession_FWD_DEFINED__
#define __IRTCSession_FWD_DEFINED__
typedef struct IRTCSession IRTCSession;
#endif

#ifndef __IRTCSession2_FWD_DEFINED__
#define __IRTCSession2_FWD_DEFINED__
typedef struct IRTCSession2 IRTCSession2;
#endif

#ifndef __IRTCSessionCallControl_FWD_DEFINED__
#define __IRTCSessionCallControl_FWD_DEFINED__
typedef struct IRTCSessionCallControl IRTCSessionCallControl;
#endif

#ifndef __IRTCParticipant_FWD_DEFINED__
#define __IRTCParticipant_FWD_DEFINED__
typedef struct IRTCParticipant IRTCParticipant;
#endif

#ifndef __IRTCEnumParticipants_FWD_DEFINED__
#define __IRTCEnumParticipants_FWD_DEFINED__
typedef struct IRTCEnumParticipants IRTCEnumParticipants;
#endif

#ifndef __IRTCCollection_FWD_DEFINED__
#define __IRTCCollection_FWD_DEFINED__
typedef struct IRTCCollection IRTCCollection;
#endif

#ifndef __IRTCPresenceContact_FWD_DEFINED__
#define __IRTCPresenceContact_FWD_DEFINED__
typedef struct IRTCPresenceContact IRTCPresenceContact;
#endif

#ifndef __IRTCBuddy_FWD_DEFINED__
#define __IRTCBuddy_FWD_DEFINED__
typedef struct IRTCBuddy IRTCBuddy;
#endif

#ifndef __IRTCBuddy2_FWD_DEFINED__
#define __IRTCBuddy2_FWD_DEFINED__
typedef struct IRTCBuddy2 IRTCBuddy2;
#endif

#ifndef __IRTCEnumBuddies_FWD_DEFINED__
#define __IRTCEnumBuddies_FWD_DEFINED__
typedef struct IRTCEnumBuddies IRTCEnumBuddies;
#endif

#ifndef __IRTCWatcher_FWD_DEFINED__
#define __IRTCWatcher_FWD_DEFINED__
typedef struct IRTCWatcher IRTCWatcher;
#endif

#ifndef __IRTCWatcher2_FWD_DEFINED__
#define __IRTCWatcher2_FWD_DEFINED__
typedef struct IRTCWatcher2 IRTCWatcher2;
#endif

#ifndef __IRTCEnumWatchers_FWD_DEFINED__
#define __IRTCEnumWatchers_FWD_DEFINED__
typedef struct IRTCEnumWatchers IRTCEnumWatchers;
#endif

#ifndef __IRTCBuddyGroup_FWD_DEFINED__
#define __IRTCBuddyGroup_FWD_DEFINED__
typedef struct IRTCBuddyGroup IRTCBuddyGroup;
#endif

#ifndef __IRTCEnumGroups_FWD_DEFINED__
#define __IRTCEnumGroups_FWD_DEFINED__
typedef struct IRTCEnumGroups IRTCEnumGroups;
#endif

#ifndef __IRTCUserSearchQuery_FWD_DEFINED__
#define __IRTCUserSearchQuery_FWD_DEFINED__
typedef struct IRTCUserSearchQuery IRTCUserSearchQuery;
#endif

#ifndef __IRTCUserSearchResult_FWD_DEFINED__
#define __IRTCUserSearchResult_FWD_DEFINED__
typedef struct IRTCUserSearchResult IRTCUserSearchResult;
#endif

#ifndef __IRTCEnumUserSearchResults_FWD_DEFINED__
#define __IRTCEnumUserSearchResults_FWD_DEFINED__
typedef struct IRTCEnumUserSearchResults IRTCEnumUserSearchResults;
#endif

#ifndef __IRTCEventNotification_FWD_DEFINED__
#define __IRTCEventNotification_FWD_DEFINED__
typedef struct IRTCEventNotification IRTCEventNotification;
#endif

#ifndef __IRTCClientEvent_FWD_DEFINED__
#define __IRTCClientEvent_FWD_DEFINED__
typedef struct IRTCClientEvent IRTCClientEvent;
#endif

#ifndef __IRTCRegistrationStateChangeEvent_FWD_DEFINED__
#define __IRTCRegistrationStateChangeEvent_FWD_DEFINED__
typedef struct IRTCRegistrationStateChangeEvent IRTCRegistrationStateChangeEvent;
#endif

#ifndef __IRTCSessionStateChangeEvent_FWD_DEFINED__
#define __IRTCSessionStateChangeEvent_FWD_DEFINED__
typedef struct IRTCSessionStateChangeEvent IRTCSessionStateChangeEvent;
#endif

#ifndef __IRTCSessionStateChangeEvent2_FWD_DEFINED__
#define __IRTCSessionStateChangeEvent2_FWD_DEFINED__
typedef struct IRTCSessionStateChangeEvent2 IRTCSessionStateChangeEvent2;
#endif

#ifndef __IRTCSessionOperationCompleteEvent_FWD_DEFINED__
#define __IRTCSessionOperationCompleteEvent_FWD_DEFINED__
typedef struct IRTCSessionOperationCompleteEvent IRTCSessionOperationCompleteEvent;
#endif

#ifndef __IRTCSessionOperationCompleteEvent2_FWD_DEFINED__
#define __IRTCSessionOperationCompleteEvent2_FWD_DEFINED__
typedef struct IRTCSessionOperationCompleteEvent2 IRTCSessionOperationCompleteEvent2;
#endif

#ifndef __IRTCParticipantStateChangeEvent_FWD_DEFINED__
#define __IRTCParticipantStateChangeEvent_FWD_DEFINED__
typedef struct IRTCParticipantStateChangeEvent IRTCParticipantStateChangeEvent;
#endif

#ifndef __IRTCMediaEvent_FWD_DEFINED__
#define __IRTCMediaEvent_FWD_DEFINED__
typedef struct IRTCMediaEvent IRTCMediaEvent;
#endif

#ifndef __IRTCIntensityEvent_FWD_DEFINED__
#define __IRTCIntensityEvent_FWD_DEFINED__
typedef struct IRTCIntensityEvent IRTCIntensityEvent;
#endif

#ifndef __IRTCMessagingEvent_FWD_DEFINED__
#define __IRTCMessagingEvent_FWD_DEFINED__
typedef struct IRTCMessagingEvent IRTCMessagingEvent;
#endif

#ifndef __IRTCBuddyEvent_FWD_DEFINED__
#define __IRTCBuddyEvent_FWD_DEFINED__
typedef struct IRTCBuddyEvent IRTCBuddyEvent;
#endif

#ifndef __IRTCBuddyEvent2_FWD_DEFINED__
#define __IRTCBuddyEvent2_FWD_DEFINED__
typedef struct IRTCBuddyEvent2 IRTCBuddyEvent2;
#endif

#ifndef __IRTCWatcherEvent_FWD_DEFINED__
#define __IRTCWatcherEvent_FWD_DEFINED__
typedef struct IRTCWatcherEvent IRTCWatcherEvent;
#endif

#ifndef __IRTCPortManager_FWD_DEFINED__
#define __IRTCPortManager_FWD_DEFINED__
typedef struct IRTCPortManager IRTCPortManager;
#endif

#ifndef __IRTCSessionPortManagement_FWD_DEFINED__
#define __IRTCSessionPortManagement_FWD_DEFINED__
typedef struct IRTCSessionPortManagement IRTCSessionPortManagement;
#endif

#ifndef __IRTCClientPortManagement_FWD_DEFINED__
#define __IRTCClientPortManagement_FWD_DEFINED__
typedef struct IRTCClientPortManagement IRTCClientPortManagement;
#endif

#ifndef __IRTCWatcherEvent2_FWD_DEFINED__
#define __IRTCWatcherEvent2_FWD_DEFINED__
typedef struct IRTCWatcherEvent2 IRTCWatcherEvent2;
#endif

#ifndef __IRTCBuddyGroupEvent_FWD_DEFINED__
#define __IRTCBuddyGroupEvent_FWD_DEFINED__
typedef struct IRTCBuddyGroupEvent IRTCBuddyGroupEvent;
#endif

#ifndef __IRTCProfileEvent_FWD_DEFINED__
#define __IRTCProfileEvent_FWD_DEFINED__
typedef struct IRTCProfileEvent IRTCProfileEvent;
#endif

#ifndef __IRTCProfileEvent2_FWD_DEFINED__
#define __IRTCProfileEvent2_FWD_DEFINED__
typedef struct IRTCProfileEvent2 IRTCProfileEvent2;
#endif

#ifndef __IRTCUserSearchResultsEvent_FWD_DEFINED__
#define __IRTCUserSearchResultsEvent_FWD_DEFINED__
typedef struct IRTCUserSearchResultsEvent IRTCUserSearchResultsEvent;
#endif

#ifndef __IRTCInfoEvent_FWD_DEFINED__
#define __IRTCInfoEvent_FWD_DEFINED__
typedef struct IRTCInfoEvent IRTCInfoEvent;
#endif

#ifndef __IRTCRoamingEvent_FWD_DEFINED__
#define __IRTCRoamingEvent_FWD_DEFINED__
typedef struct IRTCRoamingEvent IRTCRoamingEvent;
#endif

#ifndef __IRTCMediaRequestEvent_FWD_DEFINED__
#define __IRTCMediaRequestEvent_FWD_DEFINED__
typedef struct IRTCMediaRequestEvent IRTCMediaRequestEvent;
#endif

#ifndef __IRTCReInviteEvent_FWD_DEFINED__
#define __IRTCReInviteEvent_FWD_DEFINED__
typedef struct IRTCReInviteEvent IRTCReInviteEvent;
#endif

#ifndef __IRTCPresencePropertyEvent_FWD_DEFINED__
#define __IRTCPresencePropertyEvent_FWD_DEFINED__
typedef struct IRTCPresencePropertyEvent IRTCPresencePropertyEvent;
#endif

#ifndef __IRTCPresenceDataEvent_FWD_DEFINED__
#define __IRTCPresenceDataEvent_FWD_DEFINED__
typedef struct IRTCPresenceDataEvent IRTCPresenceDataEvent;
#endif

#ifndef __IRTCPresenceStatusEvent_FWD_DEFINED__
#define __IRTCPresenceStatusEvent_FWD_DEFINED__
typedef struct IRTCPresenceStatusEvent IRTCPresenceStatusEvent;
#endif

#ifndef __IRTCSessionReferStatusEvent_FWD_DEFINED__
#define __IRTCSessionReferStatusEvent_FWD_DEFINED__
typedef struct IRTCSessionReferStatusEvent IRTCSessionReferStatusEvent;
#endif

#ifndef __IRTCSessionReferredEvent_FWD_DEFINED__
#define __IRTCSessionReferredEvent_FWD_DEFINED__
typedef struct IRTCSessionReferredEvent IRTCSessionReferredEvent;
#endif

#ifndef __IRTCSessionDescriptionManager_FWD_DEFINED__
#define __IRTCSessionDescriptionManager_FWD_DEFINED__
typedef struct IRTCSessionDescriptionManager IRTCSessionDescriptionManager;
#endif

#ifndef __IRTCEnumPresenceDevices_FWD_DEFINED__
#define __IRTCEnumPresenceDevices_FWD_DEFINED__
typedef struct IRTCEnumPresenceDevices IRTCEnumPresenceDevices;
#endif

#ifndef __IRTCPresenceDevice_FWD_DEFINED__
#define __IRTCPresenceDevice_FWD_DEFINED__
typedef struct IRTCPresenceDevice IRTCPresenceDevice;
#endif

#ifndef __IRTCDispatchEventNotification_FWD_DEFINED__
#define __IRTCDispatchEventNotification_FWD_DEFINED__
typedef struct IRTCDispatchEventNotification IRTCDispatchEventNotification;
#endif

#ifndef __RTCClient_FWD_DEFINED__
#define __RTCClient_FWD_DEFINED__
#ifdef __cplusplus
typedef class RTCClient RTCClient;
#else
typedef struct RTCClient RTCClient;
#endif
#endif

#include "oaidl.h"
#include "ocidl.h"
#include "control.h"
#ifdef __cplusplus
extern "C" {
#endif

#ifndef __MIDL_user_allocate_free_DEFINED__
#define __MIDL_user_allocate_free_DEFINED__
  void *__RPC_API MIDL_user_allocate(size_t);
  void __RPC_API MIDL_user_free(void *);
#endif

  typedef enum RTC_AUDIO_DEVICE {
    RTCAD_SPEAKER = 0,RTCAD_MICROPHONE = RTCAD_SPEAKER + 1
  } RTC_AUDIO_DEVICE;

  typedef enum RTC_VIDEO_DEVICE {
    RTCVD_RECEIVE = 0,RTCVD_PREVIEW = RTCVD_RECEIVE + 1
  } RTC_VIDEO_DEVICE;

  typedef enum RTC_EVENT {
    RTCE_CLIENT = 0,
    RTCE_REGISTRATION_STATE_CHANGE,RTCE_SESSION_STATE_CHANGE,RTCE_SESSION_OPERATION_COMPLETE,
    RTCE_PARTICIPANT_STATE_CHANGE,RTCE_MEDIA,RTCE_INTENSITY,RTCE_MESSAGING,RTCE_BUDDY,
    RTCE_WATCHER,RTCE_PROFILE,RTCE_USERSEARCH,RTCE_INFO,RTCE_GROUP,RTCE_MEDIA_REQUEST,
    RTCE_ROAMING,RTCE_PRESENCE_PROPERTY,RTCE_PRESENCE_DATA,
    RTCE_PRESENCE_STATUS,RTCE_SESSION_REFER_STATUS,RTCE_SESSION_REFERRED,RTCE_REINVITE
  } RTC_EVENT;

  typedef enum RTC_LISTEN_MODE {
    RTCLM_NONE = 0,
    RTCLM_DYNAMIC,RTCLM_BOTH
  } RTC_LISTEN_MODE;

  typedef enum RTC_CLIENT_EVENT_TYPE {
    RTCCET_VOLUME_CHANGE = 0,
    RTCCET_DEVICE_CHANGE,RTCCET_NETWORK_QUALITY_CHANGE,RTCCET_ASYNC_CLEANUP_DONE
  } RTC_CLIENT_EVENT_TYPE;

  typedef enum RTC_BUDDY_EVENT_TYPE {
    RTCBET_BUDDY_ADD = 0,
    RTCBET_BUDDY_REMOVE,RTCBET_BUDDY_UPDATE,RTCBET_BUDDY_STATE_CHANGE,
    RTCBET_BUDDY_ROAMED,RTCBET_BUDDY_SUBSCRIBED
  } RTC_BUDDY_EVENT_TYPE;

  typedef enum RTC_WATCHER_EVENT_TYPE {
    RTCWET_WATCHER_ADD = 0,
    RTCWET_WATCHER_REMOVE,RTCWET_WATCHER_UPDATE,RTCWET_WATCHER_OFFERING,
    RTCWET_WATCHER_ROAMED
  } RTC_WATCHER_EVENT_TYPE;

  typedef enum RTC_GROUP_EVENT_TYPE {
    RTCGET_GROUP_ADD = 0,
    RTCGET_GROUP_REMOVE,RTCGET_GROUP_UPDATE,RTCGET_GROUP_BUDDY_ADD,
    RTCGET_GROUP_BUDDY_REMOVE,RTCGET_GROUP_ROAMED
  } RTC_GROUP_EVENT_TYPE;

  typedef enum RTC_TERMINATE_REASON {
    RTCTR_NORMAL = 0,
    RTCTR_DND,RTCTR_BUSY,RTCTR_REJECT,RTCTR_TIMEOUT,RTCTR_SHUTDOWN,
    RTCTR_INSUFFICIENT_SECURITY_LEVEL,RTCTR_NOT_SUPPORTED
  } RTC_TERMINATE_REASON;

  typedef enum RTC_REGISTRATION_STATE {
    RTCRS_NOT_REGISTERED = 0,
    RTCRS_REGISTERING,RTCRS_REGISTERED,RTCRS_REJECTED,RTCRS_UNREGISTERING,RTCRS_ERROR,
    RTCRS_LOGGED_OFF,RTCRS_LOCAL_PA_LOGGED_OFF,RTCRS_REMOTE_PA_LOGGED_OFF
  } RTC_REGISTRATION_STATE;

  typedef enum RTC_SESSION_STATE {
    RTCSS_IDLE = 0,
    RTCSS_INCOMING,RTCSS_ANSWERING,RTCSS_INPROGRESS,RTCSS_CONNECTED,RTCSS_DISCONNECTED,
    RTCSS_HOLD,RTCSS_REFER
  } RTC_SESSION_STATE;

  typedef enum RTC_PARTICIPANT_STATE {
    RTCPS_IDLE = 0,
    RTCPS_PENDING,RTCPS_INCOMING,RTCPS_ANSWERING,RTCPS_INPROGRESS,RTCPS_ALERTING,
    RTCPS_CONNECTED,RTCPS_DISCONNECTING,RTCPS_DISCONNECTED
  } RTC_PARTICIPANT_STATE;

  typedef enum RTC_WATCHER_STATE {
    RTCWS_UNKNOWN = 0,
    RTCWS_OFFERING,RTCWS_ALLOWED,RTCWS_BLOCKED,RTCWS_DENIED,RTCWS_PROMPT
  } RTC_WATCHER_STATE;

  typedef enum RTC_ACE_SCOPE {
    RTCAS_SCOPE_USER = 0,
    RTCAS_SCOPE_DOMAIN,RTCAS_SCOPE_ALL
  } RTC_ACE_SCOPE;

  typedef enum RTC_OFFER_WATCHER_MODE {
    RTCOWM_OFFER_WATCHER_EVENT = 0,RTCOWM_AUTOMATICALLY_ADD_WATCHER = RTCOWM_OFFER_WATCHER_EVENT + 1
  } RTC_OFFER_WATCHER_MODE;

  typedef enum RTC_WATCHER_MATCH_MODE {
    RTCWMM_EXACT_MATCH = 0,RTCWMM_BEST_ACE_MATCH = RTCWMM_EXACT_MATCH + 1
  } RTC_WATCHER_MATCH_MODE;

  typedef enum RTC_PRIVACY_MODE {
    RTCPM_BLOCK_LIST_EXCLUDED = 0,RTCPM_ALLOW_LIST_ONLY = RTCPM_BLOCK_LIST_EXCLUDED + 1
  } RTC_PRIVACY_MODE;

  typedef enum RTC_SESSION_TYPE {
    RTCST_PC_TO_PC = 0,
    RTCST_PC_TO_PHONE,RTCST_PHONE_TO_PHONE,RTCST_IM,RTCST_MULTIPARTY_IM,RTCST_APPLICATION
  } RTC_SESSION_TYPE;

  typedef enum RTC_PRESENCE_STATUS {
    RTCXS_PRESENCE_OFFLINE = 0,
    RTCXS_PRESENCE_ONLINE,RTCXS_PRESENCE_AWAY,RTCXS_PRESENCE_IDLE,RTCXS_PRESENCE_BUSY,
    RTCXS_PRESENCE_BE_RIGHT_BACK,RTCXS_PRESENCE_ON_THE_PHONE,RTCXS_PRESENCE_OUT_TO_LUNCH
  } RTC_PRESENCE_STATUS;

  typedef enum RTC_BUDDY_SUBSCRIPTION_TYPE {
    RTCBT_SUBSCRIBED = 0,
    RTCBT_ALWAYS_OFFLINE,RTCBT_ALWAYS_ONLINE,RTCBT_POLL
  } RTC_BUDDY_SUBSCRIPTION_TYPE;

  typedef enum RTC_MEDIA_EVENT_TYPE {
    RTCMET_STOPPED = 0,
    RTCMET_STARTED,RTCMET_FAILED
  } RTC_MEDIA_EVENT_TYPE;

  typedef enum RTC_MEDIA_EVENT_REASON {
    RTCMER_NORMAL = 0,
    RTCMER_HOLD,RTCMER_TIMEOUT,RTCMER_BAD_DEVICE,RTCMER_NO_PORT,RTCMER_PORT_MAPPING_FAILED,
    RTCMER_REMOTE_REQUEST
  } RTC_MEDIA_EVENT_REASON;

  typedef enum RTC_MESSAGING_EVENT_TYPE {
    RTCMSET_MESSAGE = 0,RTCMSET_STATUS = RTCMSET_MESSAGE + 1
  } RTC_MESSAGING_EVENT_TYPE;

  typedef enum RTC_MESSAGING_USER_STATUS {
    RTCMUS_IDLE = 0,
    RTCMUS_TYPING
  } RTC_MESSAGING_USER_STATUS;

  typedef enum RTC_DTMF {
    RTC_DTMF_0 = 0,
    RTC_DTMF_1,RTC_DTMF_2,RTC_DTMF_3,RTC_DTMF_4,RTC_DTMF_5,RTC_DTMF_6,RTC_DTMF_7,RTC_DTMF_8,RTC_DTMF_9,
    RTC_DTMF_STAR,RTC_DTMF_POUND,RTC_DTMF_A,RTC_DTMF_B,RTC_DTMF_C,RTC_DTMF_D,RTC_DTMF_FLASH
  } RTC_DTMF;

  typedef enum RTC_PROVIDER_URI {
    RTCPU_URIHOMEPAGE = 0,
    RTCPU_URIHELPDESK,RTCPU_URIPERSONALACCOUNT,RTCPU_URIDISPLAYDURINGCALL,
    RTCPU_URIDISPLAYDURINGIDLE
  } RTC_PROVIDER_URI;

  typedef enum RTC_RING_TYPE {
    RTCRT_PHONE = 0,
    RTCRT_MESSAGE,RTCRT_RINGBACK
  } RTC_RING_TYPE;

  typedef enum RTC_T120_APPLET {
    RTCTA_WHITEBOARD = 0,
    RTCTA_APPSHARING
  } RTC_T120_APPLET;

  typedef enum RTC_PORT_TYPE {
    RTCPT_AUDIO_RTP = 0,
    RTCPT_AUDIO_RTCP,RTCPT_VIDEO_RTP,RTCPT_VIDEO_RTCP,RTCPT_SIP
  } RTC_PORT_TYPE;

  typedef enum RTC_USER_SEARCH_COLUMN {
    RTCUSC_URI = 0,
    RTCUSC_DISPLAYNAME,RTCUSC_TITLE,RTCUSC_OFFICE,RTCUSC_PHONE,RTCUSC_COMPANY,RTCUSC_CITY,
    RTCUSC_STATE,RTCUSC_COUNTRY,RTCUSC_EMAIL
  } RTC_USER_SEARCH_COLUMN;

  typedef enum RTC_USER_SEARCH_PREFERENCE {
    RTCUSP_MAX_MATCHES = 0,
    RTCUSP_TIME_LIMIT
  } RTC_USER_SEARCH_PREFERENCE;

  typedef enum RTC_ROAMING_EVENT_TYPE {
    RTCRET_BUDDY_ROAMING = 0,
    RTCRET_WATCHER_ROAMING,RTCRET_PRESENCE_ROAMING,RTCRET_PROFILE_ROAMING,
    RTCRET_WPENDING_ROAMING
  } RTC_ROAMING_EVENT_TYPE;

  typedef enum RTC_PROFILE_EVENT_TYPE {
    RTCPFET_PROFILE_GET = 0,
    RTCPFET_PROFILE_UPDATE
  } RTC_PROFILE_EVENT_TYPE;

  typedef enum RTC_ANSWER_MODE {
    RTCAM_OFFER_SESSION_EVENT = 0,
    RTCAM_AUTOMATICALLY_ACCEPT,RTCAM_AUTOMATICALLY_REJECT,RTCAM_NOT_SUPPORTED
  } RTC_ANSWER_MODE;

  typedef enum RTC_SESSION_REFER_STATUS {
    RTCSRS_REFERRING = 0,
    RTCSRS_ACCEPTED,RTCSRS_ERROR,RTCSRS_REJECTED,RTCSRS_DROPPED,RTCSRS_DONE
  } RTC_SESSION_REFER_STATUS;

  typedef enum RTC_PRESENCE_PROPERTY {
    RTCPP_PHONENUMBER = 0,
    RTCPP_DISPLAYNAME,RTCPP_EMAIL,RTCPP_DEVICE_NAME,RTCPP_MULTIPLE
  } RTC_PRESENCE_PROPERTY;

  typedef enum RTC_SECURITY_TYPE {
    RTCSECT_AUDIO_VIDEO_MEDIA_ENCRYPTION = 0,
    RTCSECT_T120_MEDIA_ENCRYPTION
  } RTC_SECURITY_TYPE;

  typedef enum RTC_SECURITY_LEVEL {
    RTCSECL_UNSUPPORTED = 1,
    RTCSECL_SUPPORTED,RTCSECL_REQUIRED
  } RTC_SECURITY_LEVEL;

  typedef enum RTC_REINVITE_STATE {
    RTCRIN_INCOMING = 0,
    RTCRIN_SUCCEEDED,RTCRIN_FAIL
  } RTC_REINVITE_STATE;

#define RTCCS_FORCE_PROFILE 0x00000001
#define RTCCS_FAIL_ON_REDIRECT 0x00000002
#define RTCMT_AUDIO_SEND 0x00000001
#define RTCMT_AUDIO_RECEIVE 0x00000002
#define RTCMT_VIDEO_SEND 0x00000004
#define RTCMT_VIDEO_RECEIVE 0x00000008
#define RTCMT_T120_SENDRECV 0x00000010
#define RTCMT_ALL_RTP (RTCMT_AUDIO_SEND | RTCMT_AUDIO_RECEIVE | RTCMT_VIDEO_SEND | RTCMT_VIDEO_RECEIVE)
#define RTCMT_ALL (RTCMT_ALL_RTP | RTCMT_T120_SENDRECV)
#define RTCSI_PC_TO_PC 0x00000001
#define RTCSI_PC_TO_PHONE 0x00000002
#define RTCSI_PHONE_TO_PHONE 0x00000004
#define RTCSI_IM 0x00000008
#define RTCSI_MULTIPARTY_IM 0x00000010
#define RTCSI_APPLICATION 0x00000020
#define RTCTR_UDP 0x00000001
#define RTCTR_TCP 0x00000002
#define RTCTR_TLS 0x00000004
#define RTCAU_BASIC 0x00000001
#define RTCAU_DIGEST 0x00000002
#define RTCAU_NTLM 0x00000004
#define RTCAU_KERBEROS 0x00000008
#define RTCAU_USE_LOGON_CRED 0x00010000
#define RTCRF_REGISTER_INVITE_SESSIONS 0x00000001
#define RTCRF_REGISTER_MESSAGE_SESSIONS 0x00000002
#define RTCRF_REGISTER_PRESENCE 0x00000004
#define RTCRF_REGISTER_NOTIFY 0x00000008
#define RTCRF_REGISTER_ALL 0x0000000F
#define RTCRMF_BUDDY_ROAMING 0x00000001
#define RTCRMF_WATCHER_ROAMING 0x00000002
#define RTCRMF_PRESENCE_ROAMING 0x00000004
#define RTCRMF_PROFILE_ROAMING 0x00000008
#define RTCRMF_ALL_ROAMING 0x0000000F
#define RTCEF_CLIENT 0x00000001
#define RTCEF_REGISTRATION_STATE_CHANGE 0x00000002
#define RTCEF_SESSION_STATE_CHANGE 0x00000004
#define RTCEF_SESSION_OPERATION_COMPLETE 0x00000008
#define RTCEF_PARTICIPANT_STATE_CHANGE 0x00000010
#define RTCEF_MEDIA 0x00000020
#define RTCEF_INTENSITY 0x00000040
#define RTCEF_MESSAGING 0x00000080
#define RTCEF_BUDDY 0x00000100
#define RTCEF_WATCHER 0x00000200
#define RTCEF_PROFILE 0x00000400
#define RTCEF_USERSEARCH 0x00000800
#define RTCEF_INFO 0x00001000
#define RTCEF_GROUP 0x00002000
#define RTCEF_MEDIA_REQUEST 0x00004000
#define RTCEF_ROAMING 0x00010000
#define RTCEF_PRESENCE_PROPERTY 0x00020000
#define RTCEF_BUDDY2 0x00040000
#define RTCEF_WATCHER2 0x00080000
#define RTCEF_SESSION_REFER_STATUS 0x00100000
#define RTCEF_SESSION_REFERRED 0x00200000
#define RTCEF_REINVITE 0x00400000
#define RTCEF_PRESENCE_DATA 0x00800000
#define RTCEF_PRESENCE_STATUS 0x01000000
#define RTCEF_ALL 0x01FFFFFF
#define RTCIF_DISABLE_MEDIA 0x00000001
#define RTCIF_DISABLE_UPNP 0x00000002
#define RTCIF_ENABLE_SERVER_CLASS 0x00000004
#define RTCIF_DISABLE_STRICT_DNS 0x00000008

  extern RPC_IF_HANDLE __MIDL_itf_rtccore_0000_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_rtccore_0000_v0_0_s_ifspec;

#ifndef __IRTCClient_INTERFACE_DEFINED__
#define __IRTCClient_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IRTCClient;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IRTCClient : public IUnknown {
  public:
    virtual HRESULT WINAPI Initialize(void) = 0;
    virtual HRESULT WINAPI Shutdown(void) = 0;
    virtual HRESULT WINAPI PrepareForShutdown(void) = 0;
    virtual HRESULT WINAPI put_EventFilter(__LONG32 lFilter) = 0;
    virtual HRESULT WINAPI get_EventFilter(__LONG32 *plFilter) = 0;
    virtual HRESULT WINAPI SetPreferredMediaTypes(__LONG32 lMediaTypes,VARIANT_BOOL fPersistent) = 0;
    virtual HRESULT WINAPI get_PreferredMediaTypes(__LONG32 *plMediaTypes) = 0;
    virtual HRESULT WINAPI get_MediaCapabilities(__LONG32 *plMediaTypes) = 0;
    virtual HRESULT WINAPI CreateSession(RTC_SESSION_TYPE enType,BSTR bstrLocalPhoneURI,IRTCProfile *pProfile,__LONG32 lFlags,IRTCSession **ppSession) = 0;
    virtual HRESULT WINAPI put_ListenForIncomingSessions(RTC_LISTEN_MODE enListen) = 0;
    virtual HRESULT WINAPI get_ListenForIncomingSessions(RTC_LISTEN_MODE *penListen) = 0;
    virtual HRESULT WINAPI get_NetworkAddresses(VARIANT_BOOL fTCP,VARIANT_BOOL fExternal,VARIANT *pvAddresses) = 0;
    virtual HRESULT WINAPI put_Volume(RTC_AUDIO_DEVICE enDevice,__LONG32 lVolume) = 0;
    virtual HRESULT WINAPI get_Volume(RTC_AUDIO_DEVICE enDevice,__LONG32 *plVolume) = 0;
    virtual HRESULT WINAPI put_AudioMuted(RTC_AUDIO_DEVICE enDevice,VARIANT_BOOL fMuted) = 0;
    virtual HRESULT WINAPI get_AudioMuted(RTC_AUDIO_DEVICE enDevice,VARIANT_BOOL *pfMuted) = 0;
    virtual HRESULT WINAPI get_IVideoWindow(RTC_VIDEO_DEVICE enDevice,IVideoWindow **ppIVideoWindow) = 0;
    virtual HRESULT WINAPI put_PreferredAudioDevice(RTC_AUDIO_DEVICE enDevice,BSTR bstrDeviceName) = 0;
    virtual HRESULT WINAPI get_PreferredAudioDevice(RTC_AUDIO_DEVICE enDevice,BSTR *pbstrDeviceName) = 0;
    virtual HRESULT WINAPI put_PreferredVolume(RTC_AUDIO_DEVICE enDevice,__LONG32 lVolume) = 0;
    virtual HRESULT WINAPI get_PreferredVolume(RTC_AUDIO_DEVICE enDevice,__LONG32 *plVolume) = 0;
    virtual HRESULT WINAPI put_PreferredAEC(VARIANT_BOOL bEnable) = 0;
    virtual HRESULT WINAPI get_PreferredAEC(VARIANT_BOOL *pbEnabled) = 0;
    virtual HRESULT WINAPI put_PreferredVideoDevice(BSTR bstrDeviceName) = 0;
    virtual HRESULT WINAPI get_PreferredVideoDevice(BSTR *pbstrDeviceName) = 0;
    virtual HRESULT WINAPI get_ActiveMedia(__LONG32 *plMediaType) = 0;
    virtual HRESULT WINAPI put_MaxBitrate(__LONG32 lMaxBitrate) = 0;
    virtual HRESULT WINAPI get_MaxBitrate(__LONG32 *plMaxBitrate) = 0;
    virtual HRESULT WINAPI put_TemporalSpatialTradeOff(__LONG32 lValue) = 0;
    virtual HRESULT WINAPI get_TemporalSpatialTradeOff(__LONG32 *plValue) = 0;
    virtual HRESULT WINAPI get_NetworkQuality(__LONG32 *plNetworkQuality) = 0;
    virtual HRESULT WINAPI StartT120Applet(RTC_T120_APPLET enApplet) = 0;
    virtual HRESULT WINAPI StopT120Applets(void) = 0;
    virtual HRESULT WINAPI get_IsT120AppletRunning(RTC_T120_APPLET enApplet,VARIANT_BOOL *pfRunning) = 0;
    virtual HRESULT WINAPI get_LocalUserURI(BSTR *pbstrUserURI) = 0;
    virtual HRESULT WINAPI put_LocalUserURI(BSTR bstrUserURI) = 0;
    virtual HRESULT WINAPI get_LocalUserName(BSTR *pbstrUserName) = 0;
    virtual HRESULT WINAPI put_LocalUserName(BSTR bstrUserName) = 0;
    virtual HRESULT WINAPI PlayRing(RTC_RING_TYPE enType,VARIANT_BOOL bPlay) = 0;
    virtual HRESULT WINAPI SendDTMF(RTC_DTMF enDTMF) = 0;
    virtual HRESULT WINAPI InvokeTuningWizard(OAHWND hwndParent) = 0;
    virtual HRESULT WINAPI get_IsTuned(VARIANT_BOOL *pfTuned) = 0;
  };
#else
  typedef struct IRTCClientVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IRTCClient *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IRTCClient *This);
      ULONG (WINAPI *Release)(IRTCClient *This);
      HRESULT (WINAPI *Initialize)(IRTCClient *This);
      HRESULT (WINAPI *Shutdown)(IRTCClient *This);
      HRESULT (WINAPI *PrepareForShutdown)(IRTCClient *This);
      HRESULT (WINAPI *put_EventFilter)(IRTCClient *This,__LONG32 lFilter);
      HRESULT (WINAPI *get_EventFilter)(IRTCClient *This,__LONG32 *plFilter);
      HRESULT (WINAPI *SetPreferredMediaTypes)(IRTCClient *This,__LONG32 lMediaTypes,VARIANT_BOOL fPersistent);
      HRESULT (WINAPI *get_PreferredMediaTypes)(IRTCClient *This,__LONG32 *plMediaTypes);
      HRESULT (WINAPI *get_MediaCapabilities)(IRTCClient *This,__LONG32 *plMediaTypes);
      HRESULT (WINAPI *CreateSession)(IRTCClient *This,RTC_SESSION_TYPE enType,BSTR bstrLocalPhoneURI,IRTCProfile *pProfile,__LONG32 lFlags,IRTCSession **ppSession);
      HRESULT (WINAPI *put_ListenForIncomingSessions)(IRTCClient *This,RTC_LISTEN_MODE enListen);
      HRESULT (WINAPI *get_ListenForIncomingSessions)(IRTCClient *This,RTC_LISTEN_MODE *penListen);
      HRESULT (WINAPI *get_NetworkAddresses)(IRTCClient *This,VARIANT_BOOL fTCP,VARIANT_BOOL fExternal,VARIANT *pvAddresses);
      HRESULT (WINAPI *put_Volume)(IRTCClient *This,RTC_AUDIO_DEVICE enDevice,__LONG32 lVolume);
      HRESULT (WINAPI *get_Volume)(IRTCClient *This,RTC_AUDIO_DEVICE enDevice,__LONG32 *plVolume);
      HRESULT (WINAPI *put_AudioMuted)(IRTCClient *This,RTC_AUDIO_DEVICE enDevice,VARIANT_BOOL fMuted);
      HRESULT (WINAPI *get_AudioMuted)(IRTCClient *This,RTC_AUDIO_DEVICE enDevice,VARIANT_BOOL *pfMuted);
      HRESULT (WINAPI *get_IVideoWindow)(IRTCClient *This,RTC_VIDEO_DEVICE enDevice,IVideoWindow **ppIVideoWindow);
      HRESULT (WINAPI *put_PreferredAudioDevice)(IRTCClient *This,RTC_AUDIO_DEVICE enDevice,BSTR bstrDeviceName);
      HRESULT (WINAPI *get_PreferredAudioDevice)(IRTCClient *This,RTC_AUDIO_DEVICE enDevice,BSTR *pbstrDeviceName);
      HRESULT (WINAPI *put_PreferredVolume)(IRTCClient *This,RTC_AUDIO_DEVICE enDevice,__LONG32 lVolume);
      HRESULT (WINAPI *get_PreferredVolume)(IRTCClient *This,RTC_AUDIO_DEVICE enDevice,__LONG32 *plVolume);
      HRESULT (WINAPI *put_PreferredAEC)(IRTCClient *This,VARIANT_BOOL bEnable);
      HRESULT (WINAPI *get_PreferredAEC)(IRTCClient *This,VARIANT_BOOL *pbEnabled);
      HRESULT (WINAPI *put_PreferredVideoDevice)(IRTCClient *This,BSTR bstrDeviceName);
      HRESULT (WINAPI *get_PreferredVideoDevice)(IRTCClient *This,BSTR *pbstrDeviceName);
      HRESULT (WINAPI *get_ActiveMedia)(IRTCClient *This,__LONG32 *plMediaType);
      HRESULT (WINAPI *put_MaxBitrate)(IRTCClient *This,__LONG32 lMaxBitrate);
      HRESULT (WINAPI *get_MaxBitrate)(IRTCClient *This,__LONG32 *plMaxBitrate);
      HRESULT (WINAPI *put_TemporalSpatialTradeOff)(IRTCClient *This,__LONG32 lValue);
      HRESULT (WINAPI *get_TemporalSpatialTradeOff)(IRTCClient *This,__LONG32 *plValue);
      HRESULT (WINAPI *get_NetworkQuality)(IRTCClient *This,__LONG32 *plNetworkQuality);
      HRESULT (WINAPI *StartT120Applet)(IRTCClient *This,RTC_T120_APPLET enApplet);
      HRESULT (WINAPI *StopT120Applets)(IRTCClient *This);
      HRESULT (WINAPI *get_IsT120AppletRunning)(IRTCClient *This,RTC_T120_APPLET enApplet,VARIANT_BOOL *pfRunning);
      HRESULT (WINAPI *get_LocalUserURI)(IRTCClient *This,BSTR *pbstrUserURI);
      HRESULT (WINAPI *put_LocalUserURI)(IRTCClient *This,BSTR bstrUserURI);
      HRESULT (WINAPI *get_LocalUserName)(IRTCClient *This,BSTR *pbstrUserName);
      HRESULT (WINAPI *put_LocalUserName)(IRTCClient *This,BSTR bstrUserName);
      HRESULT (WINAPI *PlayRing)(IRTCClient *This,RTC_RING_TYPE enType,VARIANT_BOOL bPlay);
      HRESULT (WINAPI *SendDTMF)(IRTCClient *This,RTC_DTMF enDTMF);
      HRESULT (WINAPI *InvokeTuningWizard)(IRTCClient *This,OAHWND hwndParent);
      HRESULT (WINAPI *get_IsTuned)(IRTCClient *This,VARIANT_BOOL *pfTuned);
    END_INTERFACE
  } IRTCClientVtbl;
  struct IRTCClient {
    CONST_VTBL struct IRTCClientVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IRTCClient_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IRTCClient_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IRTCClient_Release(This) (This)->lpVtbl->Release(This)
#define IRTCClient_Initialize(This) (This)->lpVtbl->Initialize(This)
#define IRTCClient_Shutdown(This) (This)->lpVtbl->Shutdown(This)
#define IRTCClient_PrepareForShutdown(This) (This)->lpVtbl->PrepareForShutdown(This)
#define IRTCClient_put_EventFilter(This,lFilter) (This)->lpVtbl->put_EventFilter(This,lFilter)
#define IRTCClient_get_EventFilter(This,plFilter) (This)->lpVtbl->get_EventFilter(This,plFilter)
#define IRTCClient_SetPreferredMediaTypes(This,lMediaTypes,fPersistent) (This)->lpVtbl->SetPreferredMediaTypes(This,lMediaTypes,fPersistent)
#define IRTCClient_get_PreferredMediaTypes(This,plMediaTypes) (This)->lpVtbl->get_PreferredMediaTypes(This,plMediaTypes)
#define IRTCClient_get_MediaCapabilities(This,plMediaTypes) (This)->lpVtbl->get_MediaCapabilities(This,plMediaTypes)
#define IRTCClient_CreateSession(This,enType,bstrLocalPhoneURI,pProfile,lFlags,ppSession) (This)->lpVtbl->CreateSession(This,enType,bstrLocalPhoneURI,pProfile,lFlags,ppSession)
#define IRTCClient_put_ListenForIncomingSessions(This,enListen) (This)->lpVtbl->put_ListenForIncomingSessions(This,enListen)
#define IRTCClient_get_ListenForIncomingSessions(This,penListen) (This)->lpVtbl->get_ListenForIncomingSessions(This,penListen)
#define IRTCClient_get_NetworkAddresses(This,fTCP,fExternal,pvAddresses) (This)->lpVtbl->get_NetworkAddresses(This,fTCP,fExternal,pvAddresses)
#define IRTCClient_put_Volume(This,enDevice,lVolume) (This)->lpVtbl->put_Volume(This,enDevice,lVolume)
#define IRTCClient_get_Volume(This,enDevice,plVolume) (This)->lpVtbl->get_Volume(This,enDevice,plVolume)
#define IRTCClient_put_AudioMuted(This,enDevice,fMuted) (This)->lpVtbl->put_AudioMuted(This,enDevice,fMuted)
#define IRTCClient_get_AudioMuted(This,enDevice,pfMuted) (This)->lpVtbl->get_AudioMuted(This,enDevice,pfMuted)
#define IRTCClient_get_IVideoWindow(This,enDevice,ppIVideoWindow) (This)->lpVtbl->get_IVideoWindow(This,enDevice,ppIVideoWindow)
#define IRTCClient_put_PreferredAudioDevice(This,enDevice,bstrDeviceName) (This)->lpVtbl->put_PreferredAudioDevice(This,enDevice,bstrDeviceName)
#define IRTCClient_get_PreferredAudioDevice(This,enDevice,pbstrDeviceName) (This)->lpVtbl->get_PreferredAudioDevice(This,enDevice,pbstrDeviceName)
#define IRTCClient_put_PreferredVolume(This,enDevice,lVolume) (This)->lpVtbl->put_PreferredVolume(This,enDevice,lVolume)
#define IRTCClient_get_PreferredVolume(This,enDevice,plVolume) (This)->lpVtbl->get_PreferredVolume(This,enDevice,plVolume)
#define IRTCClient_put_PreferredAEC(This,bEnable) (This)->lpVtbl->put_PreferredAEC(This,bEnable)
#define IRTCClient_get_PreferredAEC(This,pbEnabled) (This)->lpVtbl->get_PreferredAEC(This,pbEnabled)
#define IRTCClient_put_PreferredVideoDevice(This,bstrDeviceName) (This)->lpVtbl->put_PreferredVideoDevice(This,bstrDeviceName)
#define IRTCClient_get_PreferredVideoDevice(This,pbstrDeviceName) (This)->lpVtbl->get_PreferredVideoDevice(This,pbstrDeviceName)
#define IRTCClient_get_ActiveMedia(This,plMediaType) (This)->lpVtbl->get_ActiveMedia(This,plMediaType)
#define IRTCClient_put_MaxBitrate(This,lMaxBitrate) (This)->lpVtbl->put_MaxBitrate(This,lMaxBitrate)
#define IRTCClient_get_MaxBitrate(This,plMaxBitrate) (This)->lpVtbl->get_MaxBitrate(This,plMaxBitrate)
#define IRTCClient_put_TemporalSpatialTradeOff(This,lValue) (This)->lpVtbl->put_TemporalSpatialTradeOff(This,lValue)
#define IRTCClient_get_TemporalSpatialTradeOff(This,plValue) (This)->lpVtbl->get_TemporalSpatialTradeOff(This,plValue)
#define IRTCClient_get_NetworkQuality(This,plNetworkQuality) (This)->lpVtbl->get_NetworkQuality(This,plNetworkQuality)
#define IRTCClient_StartT120Applet(This,enApplet) (This)->lpVtbl->StartT120Applet(This,enApplet)
#define IRTCClient_StopT120Applets(This) (This)->lpVtbl->StopT120Applets(This)
#define IRTCClient_get_IsT120AppletRunning(This,enApplet,pfRunning) (This)->lpVtbl->get_IsT120AppletRunning(This,enApplet,pfRunning)
#define IRTCClient_get_LocalUserURI(This,pbstrUserURI) (This)->lpVtbl->get_LocalUserURI(This,pbstrUserURI)
#define IRTCClient_put_LocalUserURI(This,bstrUserURI) (This)->lpVtbl->put_LocalUserURI(This,bstrUserURI)
#define IRTCClient_get_LocalUserName(This,pbstrUserName) (This)->lpVtbl->get_LocalUserName(This,pbstrUserName)
#define IRTCClient_put_LocalUserName(This,bstrUserName) (This)->lpVtbl->put_LocalUserName(This,bstrUserName)
#define IRTCClient_PlayRing(This,enType,bPlay) (This)->lpVtbl->PlayRing(This,enType,bPlay)
#define IRTCClient_SendDTMF(This,enDTMF) (This)->lpVtbl->SendDTMF(This,enDTMF)
#define IRTCClient_InvokeTuningWizard(This,hwndParent) (This)->lpVtbl->InvokeTuningWizard(This,hwndParent)
#define IRTCClient_get_IsTuned(This,pfTuned) (This)->lpVtbl->get_IsTuned(This,pfTuned)
#endif
#endif
  HRESULT WINAPI IRTCClient_Initialize_Proxy(IRTCClient *This);
  void __RPC_STUB IRTCClient_Initialize_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCClient_Shutdown_Proxy(IRTCClient *This);
  void __RPC_STUB IRTCClient_Shutdown_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCClient_PrepareForShutdown_Proxy(IRTCClient *This);
  void __RPC_STUB IRTCClient_PrepareForShutdown_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCClient_put_EventFilter_Proxy(IRTCClient *This,__LONG32 lFilter);
  void __RPC_STUB IRTCClient_put_EventFilter_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCClient_get_EventFilter_Proxy(IRTCClient *This,__LONG32 *plFilter);
  void __RPC_STUB IRTCClient_get_EventFilter_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCClient_SetPreferredMediaTypes_Proxy(IRTCClient *This,__LONG32 lMediaTypes,VARIANT_BOOL fPersistent);
  void __RPC_STUB IRTCClient_SetPreferredMediaTypes_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCClient_get_PreferredMediaTypes_Proxy(IRTCClient *This,__LONG32 *plMediaTypes);
  void __RPC_STUB IRTCClient_get_PreferredMediaTypes_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCClient_get_MediaCapabilities_Proxy(IRTCClient *This,__LONG32 *plMediaTypes);
  void __RPC_STUB IRTCClient_get_MediaCapabilities_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCClient_CreateSession_Proxy(IRTCClient *This,RTC_SESSION_TYPE enType,BSTR bstrLocalPhoneURI,IRTCProfile *pProfile,__LONG32 lFlags,IRTCSession **ppSession);
  void __RPC_STUB IRTCClient_CreateSession_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCClient_put_ListenForIncomingSessions_Proxy(IRTCClient *This,RTC_LISTEN_MODE enListen);
  void __RPC_STUB IRTCClient_put_ListenForIncomingSessions_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCClient_get_ListenForIncomingSessions_Proxy(IRTCClient *This,RTC_LISTEN_MODE *penListen);
  void __RPC_STUB IRTCClient_get_ListenForIncomingSessions_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCClient_get_NetworkAddresses_Proxy(IRTCClient *This,VARIANT_BOOL fTCP,VARIANT_BOOL fExternal,VARIANT *pvAddresses);
  void __RPC_STUB IRTCClient_get_NetworkAddresses_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCClient_put_Volume_Proxy(IRTCClient *This,RTC_AUDIO_DEVICE enDevice,__LONG32 lVolume);
  void __RPC_STUB IRTCClient_put_Volume_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCClient_get_Volume_Proxy(IRTCClient *This,RTC_AUDIO_DEVICE enDevice,__LONG32 *plVolume);
  void __RPC_STUB IRTCClient_get_Volume_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCClient_put_AudioMuted_Proxy(IRTCClient *This,RTC_AUDIO_DEVICE enDevice,VARIANT_BOOL fMuted);
  void __RPC_STUB IRTCClient_put_AudioMuted_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCClient_get_AudioMuted_Proxy(IRTCClient *This,RTC_AUDIO_DEVICE enDevice,VARIANT_BOOL *pfMuted);
  void __RPC_STUB IRTCClient_get_AudioMuted_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCClient_get_IVideoWindow_Proxy(IRTCClient *This,RTC_VIDEO_DEVICE enDevice,IVideoWindow **ppIVideoWindow);
  void __RPC_STUB IRTCClient_get_IVideoWindow_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCClient_put_PreferredAudioDevice_Proxy(IRTCClient *This,RTC_AUDIO_DEVICE enDevice,BSTR bstrDeviceName);
  void __RPC_STUB IRTCClient_put_PreferredAudioDevice_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCClient_get_PreferredAudioDevice_Proxy(IRTCClient *This,RTC_AUDIO_DEVICE enDevice,BSTR *pbstrDeviceName);
  void __RPC_STUB IRTCClient_get_PreferredAudioDevice_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCClient_put_PreferredVolume_Proxy(IRTCClient *This,RTC_AUDIO_DEVICE enDevice,__LONG32 lVolume);
  void __RPC_STUB IRTCClient_put_PreferredVolume_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCClient_get_PreferredVolume_Proxy(IRTCClient *This,RTC_AUDIO_DEVICE enDevice,__LONG32 *plVolume);
  void __RPC_STUB IRTCClient_get_PreferredVolume_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCClient_put_PreferredAEC_Proxy(IRTCClient *This,VARIANT_BOOL bEnable);
  void __RPC_STUB IRTCClient_put_PreferredAEC_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCClient_get_PreferredAEC_Proxy(IRTCClient *This,VARIANT_BOOL *pbEnabled);
  void __RPC_STUB IRTCClient_get_PreferredAEC_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCClient_put_PreferredVideoDevice_Proxy(IRTCClient *This,BSTR bstrDeviceName);
  void __RPC_STUB IRTCClient_put_PreferredVideoDevice_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCClient_get_PreferredVideoDevice_Proxy(IRTCClient *This,BSTR *pbstrDeviceName);
  void __RPC_STUB IRTCClient_get_PreferredVideoDevice_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCClient_get_ActiveMedia_Proxy(IRTCClient *This,__LONG32 *plMediaType);
  void __RPC_STUB IRTCClient_get_ActiveMedia_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCClient_put_MaxBitrate_Proxy(IRTCClient *This,__LONG32 lMaxBitrate);
  void __RPC_STUB IRTCClient_put_MaxBitrate_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCClient_get_MaxBitrate_Proxy(IRTCClient *This,__LONG32 *plMaxBitrate);
  void __RPC_STUB IRTCClient_get_MaxBitrate_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCClient_put_TemporalSpatialTradeOff_Proxy(IRTCClient *This,__LONG32 lValue);
  void __RPC_STUB IRTCClient_put_TemporalSpatialTradeOff_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCClient_get_TemporalSpatialTradeOff_Proxy(IRTCClient *This,__LONG32 *plValue);
  void __RPC_STUB IRTCClient_get_TemporalSpatialTradeOff_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCClient_get_NetworkQuality_Proxy(IRTCClient *This,__LONG32 *plNetworkQuality);
  void __RPC_STUB IRTCClient_get_NetworkQuality_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCClient_StartT120Applet_Proxy(IRTCClient *This,RTC_T120_APPLET enApplet);
  void __RPC_STUB IRTCClient_StartT120Applet_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCClient_StopT120Applets_Proxy(IRTCClient *This);
  void __RPC_STUB IRTCClient_StopT120Applets_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCClient_get_IsT120AppletRunning_Proxy(IRTCClient *This,RTC_T120_APPLET enApplet,VARIANT_BOOL *pfRunning);
  void __RPC_STUB IRTCClient_get_IsT120AppletRunning_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCClient_get_LocalUserURI_Proxy(IRTCClient *This,BSTR *pbstrUserURI);
  void __RPC_STUB IRTCClient_get_LocalUserURI_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCClient_put_LocalUserURI_Proxy(IRTCClient *This,BSTR bstrUserURI);
  void __RPC_STUB IRTCClient_put_LocalUserURI_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCClient_get_LocalUserName_Proxy(IRTCClient *This,BSTR *pbstrUserName);
  void __RPC_STUB IRTCClient_get_LocalUserName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCClient_put_LocalUserName_Proxy(IRTCClient *This,BSTR bstrUserName);
  void __RPC_STUB IRTCClient_put_LocalUserName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCClient_PlayRing_Proxy(IRTCClient *This,RTC_RING_TYPE enType,VARIANT_BOOL bPlay);
  void __RPC_STUB IRTCClient_PlayRing_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCClient_SendDTMF_Proxy(IRTCClient *This,RTC_DTMF enDTMF);
  void __RPC_STUB IRTCClient_SendDTMF_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCClient_InvokeTuningWizard_Proxy(IRTCClient *This,OAHWND hwndParent);
  void __RPC_STUB IRTCClient_InvokeTuningWizard_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCClient_get_IsTuned_Proxy(IRTCClient *This,VARIANT_BOOL *pfTuned);
  void __RPC_STUB IRTCClient_get_IsTuned_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IRTCClient2_INTERFACE_DEFINED__
#define __IRTCClient2_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IRTCClient2;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IRTCClient2 : public IRTCClient {
  public:
    virtual HRESULT WINAPI put_AnswerMode(RTC_SESSION_TYPE enType,RTC_ANSWER_MODE enMode) = 0;
    virtual HRESULT WINAPI get_AnswerMode(RTC_SESSION_TYPE enType,RTC_ANSWER_MODE *penMode) = 0;
    virtual HRESULT WINAPI InvokeTuningWizardEx(OAHWND hwndParent,VARIANT_BOOL fAllowAudio,VARIANT_BOOL fAllowVideo) = 0;
    virtual HRESULT WINAPI get_Version(__LONG32 *plVersion) = 0;
    virtual HRESULT WINAPI put_ClientName(BSTR bstrClientName) = 0;
    virtual HRESULT WINAPI put_ClientCurVer(BSTR bstrClientCurVer) = 0;
    virtual HRESULT WINAPI InitializeEx(__LONG32 lFlags) = 0;
    virtual HRESULT WINAPI CreateSessionWithDescription(BSTR bstrContentType,BSTR bstrSessionDescription,IRTCProfile *pProfile,__LONG32 lFlags,IRTCSession2 **ppSession2) = 0;
    virtual HRESULT WINAPI SetSessionDescriptionManager(IRTCSessionDescriptionManager *pSessionDescriptionManager) = 0;
    virtual HRESULT WINAPI put_PreferredSecurityLevel(RTC_SECURITY_TYPE enSecurityType,RTC_SECURITY_LEVEL enSecurityLevel) = 0;
    virtual HRESULT WINAPI get_PreferredSecurityLevel(RTC_SECURITY_TYPE enSecurityType,RTC_SECURITY_LEVEL *penSecurityLevel) = 0;
    virtual HRESULT WINAPI put_AllowedPorts(__LONG32 lTransport,RTC_LISTEN_MODE enListenMode) = 0;
    virtual HRESULT WINAPI get_AllowedPorts(__LONG32 lTransport,RTC_LISTEN_MODE *penListenMode) = 0;
  };
#else
  typedef struct IRTCClient2Vtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IRTCClient2 *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IRTCClient2 *This);
      ULONG (WINAPI *Release)(IRTCClient2 *This);
      HRESULT (WINAPI *Initialize)(IRTCClient2 *This);
      HRESULT (WINAPI *Shutdown)(IRTCClient2 *This);
      HRESULT (WINAPI *PrepareForShutdown)(IRTCClient2 *This);
      HRESULT (WINAPI *put_EventFilter)(IRTCClient2 *This,__LONG32 lFilter);
      HRESULT (WINAPI *get_EventFilter)(IRTCClient2 *This,__LONG32 *plFilter);
      HRESULT (WINAPI *SetPreferredMediaTypes)(IRTCClient2 *This,__LONG32 lMediaTypes,VARIANT_BOOL fPersistent);
      HRESULT (WINAPI *get_PreferredMediaTypes)(IRTCClient2 *This,__LONG32 *plMediaTypes);
      HRESULT (WINAPI *get_MediaCapabilities)(IRTCClient2 *This,__LONG32 *plMediaTypes);
      HRESULT (WINAPI *CreateSession)(IRTCClient2 *This,RTC_SESSION_TYPE enType,BSTR bstrLocalPhoneURI,IRTCProfile *pProfile,__LONG32 lFlags,IRTCSession **ppSession);
      HRESULT (WINAPI *put_ListenForIncomingSessions)(IRTCClient2 *This,RTC_LISTEN_MODE enListen);
      HRESULT (WINAPI *get_ListenForIncomingSessions)(IRTCClient2 *This,RTC_LISTEN_MODE *penListen);
      HRESULT (WINAPI *get_NetworkAddresses)(IRTCClient2 *This,VARIANT_BOOL fTCP,VARIANT_BOOL fExternal,VARIANT *pvAddresses);
      HRESULT (WINAPI *put_Volume)(IRTCClient2 *This,RTC_AUDIO_DEVICE enDevice,__LONG32 lVolume);
      HRESULT (WINAPI *get_Volume)(IRTCClient2 *This,RTC_AUDIO_DEVICE enDevice,__LONG32 *plVolume);
      HRESULT (WINAPI *put_AudioMuted)(IRTCClient2 *This,RTC_AUDIO_DEVICE enDevice,VARIANT_BOOL fMuted);
      HRESULT (WINAPI *get_AudioMuted)(IRTCClient2 *This,RTC_AUDIO_DEVICE enDevice,VARIANT_BOOL *pfMuted);
      HRESULT (WINAPI *get_IVideoWindow)(IRTCClient2 *This,RTC_VIDEO_DEVICE enDevice,IVideoWindow **ppIVideoWindow);
      HRESULT (WINAPI *put_PreferredAudioDevice)(IRTCClient2 *This,RTC_AUDIO_DEVICE enDevice,BSTR bstrDeviceName);
      HRESULT (WINAPI *get_PreferredAudioDevice)(IRTCClient2 *This,RTC_AUDIO_DEVICE enDevice,BSTR *pbstrDeviceName);
      HRESULT (WINAPI *put_PreferredVolume)(IRTCClient2 *This,RTC_AUDIO_DEVICE enDevice,__LONG32 lVolume);
      HRESULT (WINAPI *get_PreferredVolume)(IRTCClient2 *This,RTC_AUDIO_DEVICE enDevice,__LONG32 *plVolume);
      HRESULT (WINAPI *put_PreferredAEC)(IRTCClient2 *This,VARIANT_BOOL bEnable);
      HRESULT (WINAPI *get_PreferredAEC)(IRTCClient2 *This,VARIANT_BOOL *pbEnabled);
      HRESULT (WINAPI *put_PreferredVideoDevice)(IRTCClient2 *This,BSTR bstrDeviceName);
      HRESULT (WINAPI *get_PreferredVideoDevice)(IRTCClient2 *This,BSTR *pbstrDeviceName);
      HRESULT (WINAPI *get_ActiveMedia)(IRTCClient2 *This,__LONG32 *plMediaType);
      HRESULT (WINAPI *put_MaxBitrate)(IRTCClient2 *This,__LONG32 lMaxBitrate);
      HRESULT (WINAPI *get_MaxBitrate)(IRTCClient2 *This,__LONG32 *plMaxBitrate);
      HRESULT (WINAPI *put_TemporalSpatialTradeOff)(IRTCClient2 *This,__LONG32 lValue);
      HRESULT (WINAPI *get_TemporalSpatialTradeOff)(IRTCClient2 *This,__LONG32 *plValue);
      HRESULT (WINAPI *get_NetworkQuality)(IRTCClient2 *This,__LONG32 *plNetworkQuality);
      HRESULT (WINAPI *StartT120Applet)(IRTCClient2 *This,RTC_T120_APPLET enApplet);
      HRESULT (WINAPI *StopT120Applets)(IRTCClient2 *This);
      HRESULT (WINAPI *get_IsT120AppletRunning)(IRTCClient2 *This,RTC_T120_APPLET enApplet,VARIANT_BOOL *pfRunning);
      HRESULT (WINAPI *get_LocalUserURI)(IRTCClient2 *This,BSTR *pbstrUserURI);
      HRESULT (WINAPI *put_LocalUserURI)(IRTCClient2 *This,BSTR bstrUserURI);
      HRESULT (WINAPI *get_LocalUserName)(IRTCClient2 *This,BSTR *pbstrUserName);
      HRESULT (WINAPI *put_LocalUserName)(IRTCClient2 *This,BSTR bstrUserName);
      HRESULT (WINAPI *PlayRing)(IRTCClient2 *This,RTC_RING_TYPE enType,VARIANT_BOOL bPlay);
      HRESULT (WINAPI *SendDTMF)(IRTCClient2 *This,RTC_DTMF enDTMF);
      HRESULT (WINAPI *InvokeTuningWizard)(IRTCClient2 *This,OAHWND hwndParent);
      HRESULT (WINAPI *get_IsTuned)(IRTCClient2 *This,VARIANT_BOOL *pfTuned);
      HRESULT (WINAPI *put_AnswerMode)(IRTCClient2 *This,RTC_SESSION_TYPE enType,RTC_ANSWER_MODE enMode);
      HRESULT (WINAPI *get_AnswerMode)(IRTCClient2 *This,RTC_SESSION_TYPE enType,RTC_ANSWER_MODE *penMode);
      HRESULT (WINAPI *InvokeTuningWizardEx)(IRTCClient2 *This,OAHWND hwndParent,VARIANT_BOOL fAllowAudio,VARIANT_BOOL fAllowVideo);
      HRESULT (WINAPI *get_Version)(IRTCClient2 *This,__LONG32 *plVersion);
      HRESULT (WINAPI *put_ClientName)(IRTCClient2 *This,BSTR bstrClientName);
      HRESULT (WINAPI *put_ClientCurVer)(IRTCClient2 *This,BSTR bstrClientCurVer);
      HRESULT (WINAPI *InitializeEx)(IRTCClient2 *This,__LONG32 lFlags);
      HRESULT (WINAPI *CreateSessionWithDescription)(IRTCClient2 *This,BSTR bstrContentType,BSTR bstrSessionDescription,IRTCProfile *pProfile,__LONG32 lFlags,IRTCSession2 **ppSession2);
      HRESULT (WINAPI *SetSessionDescriptionManager)(IRTCClient2 *This,IRTCSessionDescriptionManager *pSessionDescriptionManager);
      HRESULT (WINAPI *put_PreferredSecurityLevel)(IRTCClient2 *This,RTC_SECURITY_TYPE enSecurityType,RTC_SECURITY_LEVEL enSecurityLevel);
      HRESULT (WINAPI *get_PreferredSecurityLevel)(IRTCClient2 *This,RTC_SECURITY_TYPE enSecurityType,RTC_SECURITY_LEVEL *penSecurityLevel);
      HRESULT (WINAPI *put_AllowedPorts)(IRTCClient2 *This,__LONG32 lTransport,RTC_LISTEN_MODE enListenMode);
      HRESULT (WINAPI *get_AllowedPorts)(IRTCClient2 *This,__LONG32 lTransport,RTC_LISTEN_MODE *penListenMode);
    END_INTERFACE
  } IRTCClient2Vtbl;
  struct IRTCClient2 {
    CONST_VTBL struct IRTCClient2Vtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IRTCClient2_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IRTCClient2_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IRTCClient2_Release(This) (This)->lpVtbl->Release(This)
#define IRTCClient2_Initialize(This) (This)->lpVtbl->Initialize(This)
#define IRTCClient2_Shutdown(This) (This)->lpVtbl->Shutdown(This)
#define IRTCClient2_PrepareForShutdown(This) (This)->lpVtbl->PrepareForShutdown(This)
#define IRTCClient2_put_EventFilter(This,lFilter) (This)->lpVtbl->put_EventFilter(This,lFilter)
#define IRTCClient2_get_EventFilter(This,plFilter) (This)->lpVtbl->get_EventFilter(This,plFilter)
#define IRTCClient2_SetPreferredMediaTypes(This,lMediaTypes,fPersistent) (This)->lpVtbl->SetPreferredMediaTypes(This,lMediaTypes,fPersistent)
#define IRTCClient2_get_PreferredMediaTypes(This,plMediaTypes) (This)->lpVtbl->get_PreferredMediaTypes(This,plMediaTypes)
#define IRTCClient2_get_MediaCapabilities(This,plMediaTypes) (This)->lpVtbl->get_MediaCapabilities(This,plMediaTypes)
#define IRTCClient2_CreateSession(This,enType,bstrLocalPhoneURI,pProfile,lFlags,ppSession) (This)->lpVtbl->CreateSession(This,enType,bstrLocalPhoneURI,pProfile,lFlags,ppSession)
#define IRTCClient2_put_ListenForIncomingSessions(This,enListen) (This)->lpVtbl->put_ListenForIncomingSessions(This,enListen)
#define IRTCClient2_get_ListenForIncomingSessions(This,penListen) (This)->lpVtbl->get_ListenForIncomingSessions(This,penListen)
#define IRTCClient2_get_NetworkAddresses(This,fTCP,fExternal,pvAddresses) (This)->lpVtbl->get_NetworkAddresses(This,fTCP,fExternal,pvAddresses)
#define IRTCClient2_put_Volume(This,enDevice,lVolume) (This)->lpVtbl->put_Volume(This,enDevice,lVolume)
#define IRTCClient2_get_Volume(This,enDevice,plVolume) (This)->lpVtbl->get_Volume(This,enDevice,plVolume)
#define IRTCClient2_put_AudioMuted(This,enDevice,fMuted) (This)->lpVtbl->put_AudioMuted(This,enDevice,fMuted)
#define IRTCClient2_get_AudioMuted(This,enDevice,pfMuted) (This)->lpVtbl->get_AudioMuted(This,enDevice,pfMuted)
#define IRTCClient2_get_IVideoWindow(This,enDevice,ppIVideoWindow) (This)->lpVtbl->get_IVideoWindow(This,enDevice,ppIVideoWindow)
#define IRTCClient2_put_PreferredAudioDevice(This,enDevice,bstrDeviceName) (This)->lpVtbl->put_PreferredAudioDevice(This,enDevice,bstrDeviceName)
#define IRTCClient2_get_PreferredAudioDevice(This,enDevice,pbstrDeviceName) (This)->lpVtbl->get_PreferredAudioDevice(This,enDevice,pbstrDeviceName)
#define IRTCClient2_put_PreferredVolume(This,enDevice,lVolume) (This)->lpVtbl->put_PreferredVolume(This,enDevice,lVolume)
#define IRTCClient2_get_PreferredVolume(This,enDevice,plVolume) (This)->lpVtbl->get_PreferredVolume(This,enDevice,plVolume)
#define IRTCClient2_put_PreferredAEC(This,bEnable) (This)->lpVtbl->put_PreferredAEC(This,bEnable)
#define IRTCClient2_get_PreferredAEC(This,pbEnabled) (This)->lpVtbl->get_PreferredAEC(This,pbEnabled)
#define IRTCClient2_put_PreferredVideoDevice(This,bstrDeviceName) (This)->lpVtbl->put_PreferredVideoDevice(This,bstrDeviceName)
#define IRTCClient2_get_PreferredVideoDevice(This,pbstrDeviceName) (This)->lpVtbl->get_PreferredVideoDevice(This,pbstrDeviceName)
#define IRTCClient2_get_ActiveMedia(This,plMediaType) (This)->lpVtbl->get_ActiveMedia(This,plMediaType)
#define IRTCClient2_put_MaxBitrate(This,lMaxBitrate) (This)->lpVtbl->put_MaxBitrate(This,lMaxBitrate)
#define IRTCClient2_get_MaxBitrate(This,plMaxBitrate) (This)->lpVtbl->get_MaxBitrate(This,plMaxBitrate)
#define IRTCClient2_put_TemporalSpatialTradeOff(This,lValue) (This)->lpVtbl->put_TemporalSpatialTradeOff(This,lValue)
#define IRTCClient2_get_TemporalSpatialTradeOff(This,plValue) (This)->lpVtbl->get_TemporalSpatialTradeOff(This,plValue)
#define IRTCClient2_get_NetworkQuality(This,plNetworkQuality) (This)->lpVtbl->get_NetworkQuality(This,plNetworkQuality)
#define IRTCClient2_StartT120Applet(This,enApplet) (This)->lpVtbl->StartT120Applet(This,enApplet)
#define IRTCClient2_StopT120Applets(This) (This)->lpVtbl->StopT120Applets(This)
#define IRTCClient2_get_IsT120AppletRunning(This,enApplet,pfRunning) (This)->lpVtbl->get_IsT120AppletRunning(This,enApplet,pfRunning)
#define IRTCClient2_get_LocalUserURI(This,pbstrUserURI) (This)->lpVtbl->get_LocalUserURI(This,pbstrUserURI)
#define IRTCClient2_put_LocalUserURI(This,bstrUserURI) (This)->lpVtbl->put_LocalUserURI(This,bstrUserURI)
#define IRTCClient2_get_LocalUserName(This,pbstrUserName) (This)->lpVtbl->get_LocalUserName(This,pbstrUserName)
#define IRTCClient2_put_LocalUserName(This,bstrUserName) (This)->lpVtbl->put_LocalUserName(This,bstrUserName)
#define IRTCClient2_PlayRing(This,enType,bPlay) (This)->lpVtbl->PlayRing(This,enType,bPlay)
#define IRTCClient2_SendDTMF(This,enDTMF) (This)->lpVtbl->SendDTMF(This,enDTMF)
#define IRTCClient2_InvokeTuningWizard(This,hwndParent) (This)->lpVtbl->InvokeTuningWizard(This,hwndParent)
#define IRTCClient2_get_IsTuned(This,pfTuned) (This)->lpVtbl->get_IsTuned(This,pfTuned)
#define IRTCClient2_put_AnswerMode(This,enType,enMode) (This)->lpVtbl->put_AnswerMode(This,enType,enMode)
#define IRTCClient2_get_AnswerMode(This,enType,penMode) (This)->lpVtbl->get_AnswerMode(This,enType,penMode)
#define IRTCClient2_InvokeTuningWizardEx(This,hwndParent,fAllowAudio,fAllowVideo) (This)->lpVtbl->InvokeTuningWizardEx(This,hwndParent,fAllowAudio,fAllowVideo)
#define IRTCClient2_get_Version(This,plVersion) (This)->lpVtbl->get_Version(This,plVersion)
#define IRTCClient2_put_ClientName(This,bstrClientName) (This)->lpVtbl->put_ClientName(This,bstrClientName)
#define IRTCClient2_put_ClientCurVer(This,bstrClientCurVer) (This)->lpVtbl->put_ClientCurVer(This,bstrClientCurVer)
#define IRTCClient2_InitializeEx(This,lFlags) (This)->lpVtbl->InitializeEx(This,lFlags)
#define IRTCClient2_CreateSessionWithDescription(This,bstrContentType,bstrSessionDescription,pProfile,lFlags,ppSession2) (This)->lpVtbl->CreateSessionWithDescription(This,bstrContentType,bstrSessionDescription,pProfile,lFlags,ppSession2)
#define IRTCClient2_SetSessionDescriptionManager(This,pSessionDescriptionManager) (This)->lpVtbl->SetSessionDescriptionManager(This,pSessionDescriptionManager)
#define IRTCClient2_put_PreferredSecurityLevel(This,enSecurityType,enSecurityLevel) (This)->lpVtbl->put_PreferredSecurityLevel(This,enSecurityType,enSecurityLevel)
#define IRTCClient2_get_PreferredSecurityLevel(This,enSecurityType,penSecurityLevel) (This)->lpVtbl->get_PreferredSecurityLevel(This,enSecurityType,penSecurityLevel)
#define IRTCClient2_put_AllowedPorts(This,lTransport,enListenMode) (This)->lpVtbl->put_AllowedPorts(This,lTransport,enListenMode)
#define IRTCClient2_get_AllowedPorts(This,lTransport,penListenMode) (This)->lpVtbl->get_AllowedPorts(This,lTransport,penListenMode)
#endif
#endif
  HRESULT WINAPI IRTCClient2_put_AnswerMode_Proxy(IRTCClient2 *This,RTC_SESSION_TYPE enType,RTC_ANSWER_MODE enMode);
  void __RPC_STUB IRTCClient2_put_AnswerMode_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCClient2_get_AnswerMode_Proxy(IRTCClient2 *This,RTC_SESSION_TYPE enType,RTC_ANSWER_MODE *penMode);
  void __RPC_STUB IRTCClient2_get_AnswerMode_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCClient2_InvokeTuningWizardEx_Proxy(IRTCClient2 *This,OAHWND hwndParent,VARIANT_BOOL fAllowAudio,VARIANT_BOOL fAllowVideo);
  void __RPC_STUB IRTCClient2_InvokeTuningWizardEx_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCClient2_get_Version_Proxy(IRTCClient2 *This,__LONG32 *plVersion);
  void __RPC_STUB IRTCClient2_get_Version_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCClient2_put_ClientName_Proxy(IRTCClient2 *This,BSTR bstrClientName);
  void __RPC_STUB IRTCClient2_put_ClientName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCClient2_put_ClientCurVer_Proxy(IRTCClient2 *This,BSTR bstrClientCurVer);
  void __RPC_STUB IRTCClient2_put_ClientCurVer_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCClient2_InitializeEx_Proxy(IRTCClient2 *This,__LONG32 lFlags);
  void __RPC_STUB IRTCClient2_InitializeEx_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCClient2_CreateSessionWithDescription_Proxy(IRTCClient2 *This,BSTR bstrContentType,BSTR bstrSessionDescription,IRTCProfile *pProfile,__LONG32 lFlags,IRTCSession2 **ppSession2);
  void __RPC_STUB IRTCClient2_CreateSessionWithDescription_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCClient2_SetSessionDescriptionManager_Proxy(IRTCClient2 *This,IRTCSessionDescriptionManager *pSessionDescriptionManager);
  void __RPC_STUB IRTCClient2_SetSessionDescriptionManager_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCClient2_put_PreferredSecurityLevel_Proxy(IRTCClient2 *This,RTC_SECURITY_TYPE enSecurityType,RTC_SECURITY_LEVEL enSecurityLevel);
  void __RPC_STUB IRTCClient2_put_PreferredSecurityLevel_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCClient2_get_PreferredSecurityLevel_Proxy(IRTCClient2 *This,RTC_SECURITY_TYPE enSecurityType,RTC_SECURITY_LEVEL *penSecurityLevel);
  void __RPC_STUB IRTCClient2_get_PreferredSecurityLevel_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCClient2_put_AllowedPorts_Proxy(IRTCClient2 *This,__LONG32 lTransport,RTC_LISTEN_MODE enListenMode);
  void __RPC_STUB IRTCClient2_put_AllowedPorts_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCClient2_get_AllowedPorts_Proxy(IRTCClient2 *This,__LONG32 lTransport,RTC_LISTEN_MODE *penListenMode);
  void __RPC_STUB IRTCClient2_get_AllowedPorts_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IRTCClientPresence_INTERFACE_DEFINED__
#define __IRTCClientPresence_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IRTCClientPresence;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IRTCClientPresence : public IUnknown {
  public:
    virtual HRESULT WINAPI EnablePresence(VARIANT_BOOL fUseStorage,VARIANT varStorage) = 0;
    virtual HRESULT WINAPI Export(VARIANT varStorage) = 0;
    virtual HRESULT WINAPI Import(VARIANT varStorage,VARIANT_BOOL fReplaceAll) = 0;
    virtual HRESULT WINAPI EnumerateBuddies(IRTCEnumBuddies **ppEnum) = 0;
    virtual HRESULT WINAPI get_Buddies(IRTCCollection **ppCollection) = 0;
    virtual HRESULT WINAPI get_Buddy(BSTR bstrPresentityURI,IRTCBuddy **ppBuddy) = 0;
    virtual HRESULT WINAPI AddBuddy(BSTR bstrPresentityURI,BSTR bstrUserName,BSTR bstrData,VARIANT_BOOL fPersistent,IRTCProfile *pProfile,__LONG32 lFlags,IRTCBuddy **ppBuddy) = 0;
    virtual HRESULT WINAPI RemoveBuddy(IRTCBuddy *pBuddy) = 0;
    virtual HRESULT WINAPI EnumerateWatchers(IRTCEnumWatchers **ppEnum) = 0;
    virtual HRESULT WINAPI get_Watchers(IRTCCollection **ppCollection) = 0;
    virtual HRESULT WINAPI get_Watcher(BSTR bstrPresentityURI,IRTCWatcher **ppWatcher) = 0;
    virtual HRESULT WINAPI AddWatcher(BSTR bstrPresentityURI,BSTR bstrUserName,BSTR bstrData,VARIANT_BOOL fBlocked,VARIANT_BOOL fPersistent,IRTCWatcher **ppWatcher) = 0;
    virtual HRESULT WINAPI RemoveWatcher(IRTCWatcher *pWatcher) = 0;
    virtual HRESULT WINAPI SetLocalPresenceInfo(RTC_PRESENCE_STATUS enStatus,BSTR bstrNotes) = 0;
    virtual HRESULT WINAPI get_OfferWatcherMode(RTC_OFFER_WATCHER_MODE *penMode) = 0;
    virtual HRESULT WINAPI put_OfferWatcherMode(RTC_OFFER_WATCHER_MODE enMode) = 0;
    virtual HRESULT WINAPI get_PrivacyMode(RTC_PRIVACY_MODE *penMode) = 0;
    virtual HRESULT WINAPI put_PrivacyMode(RTC_PRIVACY_MODE enMode) = 0;
  };
#else
  typedef struct IRTCClientPresenceVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IRTCClientPresence *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IRTCClientPresence *This);
      ULONG (WINAPI *Release)(IRTCClientPresence *This);
      HRESULT (WINAPI *EnablePresence)(IRTCClientPresence *This,VARIANT_BOOL fUseStorage,VARIANT varStorage);
      HRESULT (WINAPI *Export)(IRTCClientPresence *This,VARIANT varStorage);
      HRESULT (WINAPI *Import)(IRTCClientPresence *This,VARIANT varStorage,VARIANT_BOOL fReplaceAll);
      HRESULT (WINAPI *EnumerateBuddies)(IRTCClientPresence *This,IRTCEnumBuddies **ppEnum);
      HRESULT (WINAPI *get_Buddies)(IRTCClientPresence *This,IRTCCollection **ppCollection);
      HRESULT (WINAPI *get_Buddy)(IRTCClientPresence *This,BSTR bstrPresentityURI,IRTCBuddy **ppBuddy);
      HRESULT (WINAPI *AddBuddy)(IRTCClientPresence *This,BSTR bstrPresentityURI,BSTR bstrUserName,BSTR bstrData,VARIANT_BOOL fPersistent,IRTCProfile *pProfile,__LONG32 lFlags,IRTCBuddy **ppBuddy);
      HRESULT (WINAPI *RemoveBuddy)(IRTCClientPresence *This,IRTCBuddy *pBuddy);
      HRESULT (WINAPI *EnumerateWatchers)(IRTCClientPresence *This,IRTCEnumWatchers **ppEnum);
      HRESULT (WINAPI *get_Watchers)(IRTCClientPresence *This,IRTCCollection **ppCollection);
      HRESULT (WINAPI *get_Watcher)(IRTCClientPresence *This,BSTR bstrPresentityURI,IRTCWatcher **ppWatcher);
      HRESULT (WINAPI *AddWatcher)(IRTCClientPresence *This,BSTR bstrPresentityURI,BSTR bstrUserName,BSTR bstrData,VARIANT_BOOL fBlocked,VARIANT_BOOL fPersistent,IRTCWatcher **ppWatcher);
      HRESULT (WINAPI *RemoveWatcher)(IRTCClientPresence *This,IRTCWatcher *pWatcher);
      HRESULT (WINAPI *SetLocalPresenceInfo)(IRTCClientPresence *This,RTC_PRESENCE_STATUS enStatus,BSTR bstrNotes);
      HRESULT (WINAPI *get_OfferWatcherMode)(IRTCClientPresence *This,RTC_OFFER_WATCHER_MODE *penMode);
      HRESULT (WINAPI *put_OfferWatcherMode)(IRTCClientPresence *This,RTC_OFFER_WATCHER_MODE enMode);
      HRESULT (WINAPI *get_PrivacyMode)(IRTCClientPresence *This,RTC_PRIVACY_MODE *penMode);
      HRESULT (WINAPI *put_PrivacyMode)(IRTCClientPresence *This,RTC_PRIVACY_MODE enMode);
    END_INTERFACE
  } IRTCClientPresenceVtbl;
  struct IRTCClientPresence {
    CONST_VTBL struct IRTCClientPresenceVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IRTCClientPresence_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IRTCClientPresence_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IRTCClientPresence_Release(This) (This)->lpVtbl->Release(This)
#define IRTCClientPresence_EnablePresence(This,fUseStorage,varStorage) (This)->lpVtbl->EnablePresence(This,fUseStorage,varStorage)
#define IRTCClientPresence_Export(This,varStorage) (This)->lpVtbl->Export(This,varStorage)
#define IRTCClientPresence_Import(This,varStorage,fReplaceAll) (This)->lpVtbl->Import(This,varStorage,fReplaceAll)
#define IRTCClientPresence_EnumerateBuddies(This,ppEnum) (This)->lpVtbl->EnumerateBuddies(This,ppEnum)
#define IRTCClientPresence_get_Buddies(This,ppCollection) (This)->lpVtbl->get_Buddies(This,ppCollection)
#define IRTCClientPresence_get_Buddy(This,bstrPresentityURI,ppBuddy) (This)->lpVtbl->get_Buddy(This,bstrPresentityURI,ppBuddy)
#define IRTCClientPresence_AddBuddy(This,bstrPresentityURI,bstrUserName,bstrData,fPersistent,pProfile,lFlags,ppBuddy) (This)->lpVtbl->AddBuddy(This,bstrPresentityURI,bstrUserName,bstrData,fPersistent,pProfile,lFlags,ppBuddy)
#define IRTCClientPresence_RemoveBuddy(This,pBuddy) (This)->lpVtbl->RemoveBuddy(This,pBuddy)
#define IRTCClientPresence_EnumerateWatchers(This,ppEnum) (This)->lpVtbl->EnumerateWatchers(This,ppEnum)
#define IRTCClientPresence_get_Watchers(This,ppCollection) (This)->lpVtbl->get_Watchers(This,ppCollection)
#define IRTCClientPresence_get_Watcher(This,bstrPresentityURI,ppWatcher) (This)->lpVtbl->get_Watcher(This,bstrPresentityURI,ppWatcher)
#define IRTCClientPresence_AddWatcher(This,bstrPresentityURI,bstrUserName,bstrData,fBlocked,fPersistent,ppWatcher) (This)->lpVtbl->AddWatcher(This,bstrPresentityURI,bstrUserName,bstrData,fBlocked,fPersistent,ppWatcher)
#define IRTCClientPresence_RemoveWatcher(This,pWatcher) (This)->lpVtbl->RemoveWatcher(This,pWatcher)
#define IRTCClientPresence_SetLocalPresenceInfo(This,enStatus,bstrNotes) (This)->lpVtbl->SetLocalPresenceInfo(This,enStatus,bstrNotes)
#define IRTCClientPresence_get_OfferWatcherMode(This,penMode) (This)->lpVtbl->get_OfferWatcherMode(This,penMode)
#define IRTCClientPresence_put_OfferWatcherMode(This,enMode) (This)->lpVtbl->put_OfferWatcherMode(This,enMode)
#define IRTCClientPresence_get_PrivacyMode(This,penMode) (This)->lpVtbl->get_PrivacyMode(This,penMode)
#define IRTCClientPresence_put_PrivacyMode(This,enMode) (This)->lpVtbl->put_PrivacyMode(This,enMode)
#endif
#endif
  HRESULT WINAPI IRTCClientPresence_EnablePresence_Proxy(IRTCClientPresence *This,VARIANT_BOOL fUseStorage,VARIANT varStorage);
  void __RPC_STUB IRTCClientPresence_EnablePresence_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCClientPresence_Export_Proxy(IRTCClientPresence *This,VARIANT varStorage);
  void __RPC_STUB IRTCClientPresence_Export_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCClientPresence_Import_Proxy(IRTCClientPresence *This,VARIANT varStorage,VARIANT_BOOL fReplaceAll);
  void __RPC_STUB IRTCClientPresence_Import_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCClientPresence_EnumerateBuddies_Proxy(IRTCClientPresence *This,IRTCEnumBuddies **ppEnum);
  void __RPC_STUB IRTCClientPresence_EnumerateBuddies_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCClientPresence_get_Buddies_Proxy(IRTCClientPresence *This,IRTCCollection **ppCollection);
  void __RPC_STUB IRTCClientPresence_get_Buddies_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCClientPresence_get_Buddy_Proxy(IRTCClientPresence *This,BSTR bstrPresentityURI,IRTCBuddy **ppBuddy);
  void __RPC_STUB IRTCClientPresence_get_Buddy_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCClientPresence_AddBuddy_Proxy(IRTCClientPresence *This,BSTR bstrPresentityURI,BSTR bstrUserName,BSTR bstrData,VARIANT_BOOL fPersistent,IRTCProfile *pProfile,__LONG32 lFlags,IRTCBuddy **ppBuddy);
  void __RPC_STUB IRTCClientPresence_AddBuddy_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCClientPresence_RemoveBuddy_Proxy(IRTCClientPresence *This,IRTCBuddy *pBuddy);
  void __RPC_STUB IRTCClientPresence_RemoveBuddy_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCClientPresence_EnumerateWatchers_Proxy(IRTCClientPresence *This,IRTCEnumWatchers **ppEnum);
  void __RPC_STUB IRTCClientPresence_EnumerateWatchers_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCClientPresence_get_Watchers_Proxy(IRTCClientPresence *This,IRTCCollection **ppCollection);
  void __RPC_STUB IRTCClientPresence_get_Watchers_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCClientPresence_get_Watcher_Proxy(IRTCClientPresence *This,BSTR bstrPresentityURI,IRTCWatcher **ppWatcher);
  void __RPC_STUB IRTCClientPresence_get_Watcher_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCClientPresence_AddWatcher_Proxy(IRTCClientPresence *This,BSTR bstrPresentityURI,BSTR bstrUserName,BSTR bstrData,VARIANT_BOOL fBlocked,VARIANT_BOOL fPersistent,IRTCWatcher **ppWatcher);
  void __RPC_STUB IRTCClientPresence_AddWatcher_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCClientPresence_RemoveWatcher_Proxy(IRTCClientPresence *This,IRTCWatcher *pWatcher);
  void __RPC_STUB IRTCClientPresence_RemoveWatcher_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCClientPresence_SetLocalPresenceInfo_Proxy(IRTCClientPresence *This,RTC_PRESENCE_STATUS enStatus,BSTR bstrNotes);
  void __RPC_STUB IRTCClientPresence_SetLocalPresenceInfo_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCClientPresence_get_OfferWatcherMode_Proxy(IRTCClientPresence *This,RTC_OFFER_WATCHER_MODE *penMode);
  void __RPC_STUB IRTCClientPresence_get_OfferWatcherMode_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCClientPresence_put_OfferWatcherMode_Proxy(IRTCClientPresence *This,RTC_OFFER_WATCHER_MODE enMode);
  void __RPC_STUB IRTCClientPresence_put_OfferWatcherMode_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCClientPresence_get_PrivacyMode_Proxy(IRTCClientPresence *This,RTC_PRIVACY_MODE *penMode);
  void __RPC_STUB IRTCClientPresence_get_PrivacyMode_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCClientPresence_put_PrivacyMode_Proxy(IRTCClientPresence *This,RTC_PRIVACY_MODE enMode);
  void __RPC_STUB IRTCClientPresence_put_PrivacyMode_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IRTCClientPresence2_INTERFACE_DEFINED__
#define __IRTCClientPresence2_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IRTCClientPresence2;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IRTCClientPresence2 : public IRTCClientPresence {
  public:
    virtual HRESULT WINAPI EnablePresenceEx(IRTCProfile *pProfile,VARIANT varStorage,__LONG32 lFlags) = 0;
    virtual HRESULT WINAPI DisablePresence(void) = 0;
    virtual HRESULT WINAPI AddGroup(BSTR bstrGroupName,BSTR bstrData,IRTCProfile *pProfile,__LONG32 lFlags,IRTCBuddyGroup **ppGroup) = 0;
    virtual HRESULT WINAPI RemoveGroup(IRTCBuddyGroup *pGroup) = 0;
    virtual HRESULT WINAPI EnumerateGroups(IRTCEnumGroups **ppEnum) = 0;
    virtual HRESULT WINAPI get_Groups(IRTCCollection **ppCollection) = 0;
    virtual HRESULT WINAPI get_Group(BSTR bstrGroupName,IRTCBuddyGroup **ppGroup) = 0;
    virtual HRESULT WINAPI AddWatcherEx(BSTR bstrPresentityURI,BSTR bstrUserName,BSTR bstrData,RTC_WATCHER_STATE enState,VARIANT_BOOL fPersistent,RTC_ACE_SCOPE enScope,IRTCProfile *pProfile,__LONG32 lFlags,IRTCWatcher2 **ppWatcher) = 0;
    virtual HRESULT WINAPI get_WatcherEx(RTC_WATCHER_MATCH_MODE enMode,BSTR bstrPresentityURI,IRTCWatcher2 **ppWatcher) = 0;
    virtual HRESULT WINAPI put_PresenceProperty(RTC_PRESENCE_PROPERTY enProperty,BSTR bstrProperty) = 0;
    virtual HRESULT WINAPI get_PresenceProperty(RTC_PRESENCE_PROPERTY enProperty,BSTR *pbstrProperty) = 0;
    virtual HRESULT WINAPI SetPresenceData(BSTR bstrNamespace,BSTR bstrData) = 0;
    virtual HRESULT WINAPI GetPresenceData(BSTR *pbstrNamespace,BSTR *pbstrData) = 0;
    virtual HRESULT WINAPI GetLocalPresenceInfo(RTC_PRESENCE_STATUS *penStatus,BSTR *pbstrNotes) = 0;
    virtual HRESULT WINAPI AddBuddyEx(BSTR bstrPresentityURI,BSTR bstrUserName,BSTR bstrData,VARIANT_BOOL fPersistent,RTC_BUDDY_SUBSCRIPTION_TYPE enSubscriptionType,IRTCProfile *pProfile,__LONG32 lFlags,IRTCBuddy2 **ppBuddy) = 0;
  };
#else
  typedef struct IRTCClientPresence2Vtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IRTCClientPresence2 *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IRTCClientPresence2 *This);
      ULONG (WINAPI *Release)(IRTCClientPresence2 *This);
      HRESULT (WINAPI *EnablePresence)(IRTCClientPresence2 *This,VARIANT_BOOL fUseStorage,VARIANT varStorage);
      HRESULT (WINAPI *Export)(IRTCClientPresence2 *This,VARIANT varStorage);
      HRESULT (WINAPI *Import)(IRTCClientPresence2 *This,VARIANT varStorage,VARIANT_BOOL fReplaceAll);
      HRESULT (WINAPI *EnumerateBuddies)(IRTCClientPresence2 *This,IRTCEnumBuddies **ppEnum);
      HRESULT (WINAPI *get_Buddies)(IRTCClientPresence2 *This,IRTCCollection **ppCollection);
      HRESULT (WINAPI *get_Buddy)(IRTCClientPresence2 *This,BSTR bstrPresentityURI,IRTCBuddy **ppBuddy);
      HRESULT (WINAPI *AddBuddy)(IRTCClientPresence2 *This,BSTR bstrPresentityURI,BSTR bstrUserName,BSTR bstrData,VARIANT_BOOL fPersistent,IRTCProfile *pProfile,__LONG32 lFlags,IRTCBuddy **ppBuddy);
      HRESULT (WINAPI *RemoveBuddy)(IRTCClientPresence2 *This,IRTCBuddy *pBuddy);
      HRESULT (WINAPI *EnumerateWatchers)(IRTCClientPresence2 *This,IRTCEnumWatchers **ppEnum);
      HRESULT (WINAPI *get_Watchers)(IRTCClientPresence2 *This,IRTCCollection **ppCollection);
      HRESULT (WINAPI *get_Watcher)(IRTCClientPresence2 *This,BSTR bstrPresentityURI,IRTCWatcher **ppWatcher);
      HRESULT (WINAPI *AddWatcher)(IRTCClientPresence2 *This,BSTR bstrPresentityURI,BSTR bstrUserName,BSTR bstrData,VARIANT_BOOL fBlocked,VARIANT_BOOL fPersistent,IRTCWatcher **ppWatcher);
      HRESULT (WINAPI *RemoveWatcher)(IRTCClientPresence2 *This,IRTCWatcher *pWatcher);
      HRESULT (WINAPI *SetLocalPresenceInfo)(IRTCClientPresence2 *This,RTC_PRESENCE_STATUS enStatus,BSTR bstrNotes);
      HRESULT (WINAPI *get_OfferWatcherMode)(IRTCClientPresence2 *This,RTC_OFFER_WATCHER_MODE *penMode);
      HRESULT (WINAPI *put_OfferWatcherMode)(IRTCClientPresence2 *This,RTC_OFFER_WATCHER_MODE enMode);
      HRESULT (WINAPI *get_PrivacyMode)(IRTCClientPresence2 *This,RTC_PRIVACY_MODE *penMode);
      HRESULT (WINAPI *put_PrivacyMode)(IRTCClientPresence2 *This,RTC_PRIVACY_MODE enMode);
      HRESULT (WINAPI *EnablePresenceEx)(IRTCClientPresence2 *This,IRTCProfile *pProfile,VARIANT varStorage,__LONG32 lFlags);
      HRESULT (WINAPI *DisablePresence)(IRTCClientPresence2 *This);
      HRESULT (WINAPI *AddGroup)(IRTCClientPresence2 *This,BSTR bstrGroupName,BSTR bstrData,IRTCProfile *pProfile,__LONG32 lFlags,IRTCBuddyGroup **ppGroup);
      HRESULT (WINAPI *RemoveGroup)(IRTCClientPresence2 *This,IRTCBuddyGroup *pGroup);
      HRESULT (WINAPI *EnumerateGroups)(IRTCClientPresence2 *This,IRTCEnumGroups **ppEnum);
      HRESULT (WINAPI *get_Groups)(IRTCClientPresence2 *This,IRTCCollection **ppCollection);
      HRESULT (WINAPI *get_Group)(IRTCClientPresence2 *This,BSTR bstrGroupName,IRTCBuddyGroup **ppGroup);
      HRESULT (WINAPI *AddWatcherEx)(IRTCClientPresence2 *This,BSTR bstrPresentityURI,BSTR bstrUserName,BSTR bstrData,RTC_WATCHER_STATE enState,VARIANT_BOOL fPersistent,RTC_ACE_SCOPE enScope,IRTCProfile *pProfile,__LONG32 lFlags,IRTCWatcher2 **ppWatcher);
      HRESULT (WINAPI *get_WatcherEx)(IRTCClientPresence2 *This,RTC_WATCHER_MATCH_MODE enMode,BSTR bstrPresentityURI,IRTCWatcher2 **ppWatcher);
      HRESULT (WINAPI *put_PresenceProperty)(IRTCClientPresence2 *This,RTC_PRESENCE_PROPERTY enProperty,BSTR bstrProperty);
      HRESULT (WINAPI *get_PresenceProperty)(IRTCClientPresence2 *This,RTC_PRESENCE_PROPERTY enProperty,BSTR *pbstrProperty);
      HRESULT (WINAPI *SetPresenceData)(IRTCClientPresence2 *This,BSTR bstrNamespace,BSTR bstrData);
      HRESULT (WINAPI *GetPresenceData)(IRTCClientPresence2 *This,BSTR *pbstrNamespace,BSTR *pbstrData);
      HRESULT (WINAPI *GetLocalPresenceInfo)(IRTCClientPresence2 *This,RTC_PRESENCE_STATUS *penStatus,BSTR *pbstrNotes);
      HRESULT (WINAPI *AddBuddyEx)(IRTCClientPresence2 *This,BSTR bstrPresentityURI,BSTR bstrUserName,BSTR bstrData,VARIANT_BOOL fPersistent,RTC_BUDDY_SUBSCRIPTION_TYPE enSubscriptionType,IRTCProfile *pProfile,__LONG32 lFlags,IRTCBuddy2 **ppBuddy);
    END_INTERFACE
  } IRTCClientPresence2Vtbl;
  struct IRTCClientPresence2 {
    CONST_VTBL struct IRTCClientPresence2Vtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IRTCClientPresence2_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IRTCClientPresence2_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IRTCClientPresence2_Release(This) (This)->lpVtbl->Release(This)
#define IRTCClientPresence2_EnablePresence(This,fUseStorage,varStorage) (This)->lpVtbl->EnablePresence(This,fUseStorage,varStorage)
#define IRTCClientPresence2_Export(This,varStorage) (This)->lpVtbl->Export(This,varStorage)
#define IRTCClientPresence2_Import(This,varStorage,fReplaceAll) (This)->lpVtbl->Import(This,varStorage,fReplaceAll)
#define IRTCClientPresence2_EnumerateBuddies(This,ppEnum) (This)->lpVtbl->EnumerateBuddies(This,ppEnum)
#define IRTCClientPresence2_get_Buddies(This,ppCollection) (This)->lpVtbl->get_Buddies(This,ppCollection)
#define IRTCClientPresence2_get_Buddy(This,bstrPresentityURI,ppBuddy) (This)->lpVtbl->get_Buddy(This,bstrPresentityURI,ppBuddy)
#define IRTCClientPresence2_AddBuddy(This,bstrPresentityURI,bstrUserName,bstrData,fPersistent,pProfile,lFlags,ppBuddy) (This)->lpVtbl->AddBuddy(This,bstrPresentityURI,bstrUserName,bstrData,fPersistent,pProfile,lFlags,ppBuddy)
#define IRTCClientPresence2_RemoveBuddy(This,pBuddy) (This)->lpVtbl->RemoveBuddy(This,pBuddy)
#define IRTCClientPresence2_EnumerateWatchers(This,ppEnum) (This)->lpVtbl->EnumerateWatchers(This,ppEnum)
#define IRTCClientPresence2_get_Watchers(This,ppCollection) (This)->lpVtbl->get_Watchers(This,ppCollection)
#define IRTCClientPresence2_get_Watcher(This,bstrPresentityURI,ppWatcher) (This)->lpVtbl->get_Watcher(This,bstrPresentityURI,ppWatcher)
#define IRTCClientPresence2_AddWatcher(This,bstrPresentityURI,bstrUserName,bstrData,fBlocked,fPersistent,ppWatcher) (This)->lpVtbl->AddWatcher(This,bstrPresentityURI,bstrUserName,bstrData,fBlocked,fPersistent,ppWatcher)
#define IRTCClientPresence2_RemoveWatcher(This,pWatcher) (This)->lpVtbl->RemoveWatcher(This,pWatcher)
#define IRTCClientPresence2_SetLocalPresenceInfo(This,enStatus,bstrNotes) (This)->lpVtbl->SetLocalPresenceInfo(This,enStatus,bstrNotes)
#define IRTCClientPresence2_get_OfferWatcherMode(This,penMode) (This)->lpVtbl->get_OfferWatcherMode(This,penMode)
#define IRTCClientPresence2_put_OfferWatcherMode(This,enMode) (This)->lpVtbl->put_OfferWatcherMode(This,enMode)
#define IRTCClientPresence2_get_PrivacyMode(This,penMode) (This)->lpVtbl->get_PrivacyMode(This,penMode)
#define IRTCClientPresence2_put_PrivacyMode(This,enMode) (This)->lpVtbl->put_PrivacyMode(This,enMode)
#define IRTCClientPresence2_EnablePresenceEx(This,pProfile,varStorage,lFlags) (This)->lpVtbl->EnablePresenceEx(This,pProfile,varStorage,lFlags)
#define IRTCClientPresence2_DisablePresence(This) (This)->lpVtbl->DisablePresence(This)
#define IRTCClientPresence2_AddGroup(This,bstrGroupName,bstrData,pProfile,lFlags,ppGroup) (This)->lpVtbl->AddGroup(This,bstrGroupName,bstrData,pProfile,lFlags,ppGroup)
#define IRTCClientPresence2_RemoveGroup(This,pGroup) (This)->lpVtbl->RemoveGroup(This,pGroup)
#define IRTCClientPresence2_EnumerateGroups(This,ppEnum) (This)->lpVtbl->EnumerateGroups(This,ppEnum)
#define IRTCClientPresence2_get_Groups(This,ppCollection) (This)->lpVtbl->get_Groups(This,ppCollection)
#define IRTCClientPresence2_get_Group(This,bstrGroupName,ppGroup) (This)->lpVtbl->get_Group(This,bstrGroupName,ppGroup)
#define IRTCClientPresence2_AddWatcherEx(This,bstrPresentityURI,bstrUserName,bstrData,enState,fPersistent,enScope,pProfile,lFlags,ppWatcher) (This)->lpVtbl->AddWatcherEx(This,bstrPresentityURI,bstrUserName,bstrData,enState,fPersistent,enScope,pProfile,lFlags,ppWatcher)
#define IRTCClientPresence2_get_WatcherEx(This,enMode,bstrPresentityURI,ppWatcher) (This)->lpVtbl->get_WatcherEx(This,enMode,bstrPresentityURI,ppWatcher)
#define IRTCClientPresence2_put_PresenceProperty(This,enProperty,bstrProperty) (This)->lpVtbl->put_PresenceProperty(This,enProperty,bstrProperty)
#define IRTCClientPresence2_get_PresenceProperty(This,enProperty,pbstrProperty) (This)->lpVtbl->get_PresenceProperty(This,enProperty,pbstrProperty)
#define IRTCClientPresence2_SetPresenceData(This,bstrNamespace,bstrData) (This)->lpVtbl->SetPresenceData(This,bstrNamespace,bstrData)
#define IRTCClientPresence2_GetPresenceData(This,pbstrNamespace,pbstrData) (This)->lpVtbl->GetPresenceData(This,pbstrNamespace,pbstrData)
#define IRTCClientPresence2_GetLocalPresenceInfo(This,penStatus,pbstrNotes) (This)->lpVtbl->GetLocalPresenceInfo(This,penStatus,pbstrNotes)
#define IRTCClientPresence2_AddBuddyEx(This,bstrPresentityURI,bstrUserName,bstrData,fPersistent,enSubscriptionType,pProfile,lFlags,ppBuddy) (This)->lpVtbl->AddBuddyEx(This,bstrPresentityURI,bstrUserName,bstrData,fPersistent,enSubscriptionType,pProfile,lFlags,ppBuddy)
#endif
#endif
  HRESULT WINAPI IRTCClientPresence2_EnablePresenceEx_Proxy(IRTCClientPresence2 *This,IRTCProfile *pProfile,VARIANT varStorage,__LONG32 lFlags);
  void __RPC_STUB IRTCClientPresence2_EnablePresenceEx_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCClientPresence2_DisablePresence_Proxy(IRTCClientPresence2 *This);
  void __RPC_STUB IRTCClientPresence2_DisablePresence_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCClientPresence2_AddGroup_Proxy(IRTCClientPresence2 *This,BSTR bstrGroupName,BSTR bstrData,IRTCProfile *pProfile,__LONG32 lFlags,IRTCBuddyGroup **ppGroup);
  void __RPC_STUB IRTCClientPresence2_AddGroup_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCClientPresence2_RemoveGroup_Proxy(IRTCClientPresence2 *This,IRTCBuddyGroup *pGroup);
  void __RPC_STUB IRTCClientPresence2_RemoveGroup_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCClientPresence2_EnumerateGroups_Proxy(IRTCClientPresence2 *This,IRTCEnumGroups **ppEnum);
  void __RPC_STUB IRTCClientPresence2_EnumerateGroups_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCClientPresence2_get_Groups_Proxy(IRTCClientPresence2 *This,IRTCCollection **ppCollection);
  void __RPC_STUB IRTCClientPresence2_get_Groups_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCClientPresence2_get_Group_Proxy(IRTCClientPresence2 *This,BSTR bstrGroupName,IRTCBuddyGroup **ppGroup);
  void __RPC_STUB IRTCClientPresence2_get_Group_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCClientPresence2_AddWatcherEx_Proxy(IRTCClientPresence2 *This,BSTR bstrPresentityURI,BSTR bstrUserName,BSTR bstrData,RTC_WATCHER_STATE enState,VARIANT_BOOL fPersistent,RTC_ACE_SCOPE enScope,IRTCProfile *pProfile,__LONG32 lFlags,IRTCWatcher2 **ppWatcher);
  void __RPC_STUB IRTCClientPresence2_AddWatcherEx_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCClientPresence2_get_WatcherEx_Proxy(IRTCClientPresence2 *This,RTC_WATCHER_MATCH_MODE enMode,BSTR bstrPresentityURI,IRTCWatcher2 **ppWatcher);
  void __RPC_STUB IRTCClientPresence2_get_WatcherEx_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCClientPresence2_put_PresenceProperty_Proxy(IRTCClientPresence2 *This,RTC_PRESENCE_PROPERTY enProperty,BSTR bstrProperty);
  void __RPC_STUB IRTCClientPresence2_put_PresenceProperty_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCClientPresence2_get_PresenceProperty_Proxy(IRTCClientPresence2 *This,RTC_PRESENCE_PROPERTY enProperty,BSTR *pbstrProperty);
  void __RPC_STUB IRTCClientPresence2_get_PresenceProperty_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCClientPresence2_SetPresenceData_Proxy(IRTCClientPresence2 *This,BSTR bstrNamespace,BSTR bstrData);
  void __RPC_STUB IRTCClientPresence2_SetPresenceData_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCClientPresence2_GetPresenceData_Proxy(IRTCClientPresence2 *This,BSTR *pbstrNamespace,BSTR *pbstrData);
  void __RPC_STUB IRTCClientPresence2_GetPresenceData_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCClientPresence2_GetLocalPresenceInfo_Proxy(IRTCClientPresence2 *This,RTC_PRESENCE_STATUS *penStatus,BSTR *pbstrNotes);
  void __RPC_STUB IRTCClientPresence2_GetLocalPresenceInfo_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCClientPresence2_AddBuddyEx_Proxy(IRTCClientPresence2 *This,BSTR bstrPresentityURI,BSTR bstrUserName,BSTR bstrData,VARIANT_BOOL fPersistent,RTC_BUDDY_SUBSCRIPTION_TYPE enSubscriptionType,IRTCProfile *pProfile,__LONG32 lFlags,IRTCBuddy2 **ppBuddy);
  void __RPC_STUB IRTCClientPresence2_AddBuddyEx_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IRTCClientProvisioning_INTERFACE_DEFINED__
#define __IRTCClientProvisioning_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IRTCClientProvisioning;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IRTCClientProvisioning : public IUnknown {
  public:
    virtual HRESULT WINAPI CreateProfile(BSTR bstrProfileXML,IRTCProfile **ppProfile) = 0;
    virtual HRESULT WINAPI EnableProfile(IRTCProfile *pProfile,__LONG32 lRegisterFlags) = 0;
    virtual HRESULT WINAPI DisableProfile(IRTCProfile *pProfile) = 0;
    virtual HRESULT WINAPI EnumerateProfiles(IRTCEnumProfiles **ppEnum) = 0;
    virtual HRESULT WINAPI get_Profiles(IRTCCollection **ppCollection) = 0;
    virtual HRESULT WINAPI GetProfile(BSTR bstrUserAccount,BSTR bstrUserPassword,BSTR bstrUserURI,BSTR bstrServer,__LONG32 lTransport,LONG_PTR lCookie) = 0;
    virtual HRESULT WINAPI get_SessionCapabilities(__LONG32 *plSupportedSessions) = 0;
  };
#else
  typedef struct IRTCClientProvisioningVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IRTCClientProvisioning *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IRTCClientProvisioning *This);
      ULONG (WINAPI *Release)(IRTCClientProvisioning *This);
      HRESULT (WINAPI *CreateProfile)(IRTCClientProvisioning *This,BSTR bstrProfileXML,IRTCProfile **ppProfile);
      HRESULT (WINAPI *EnableProfile)(IRTCClientProvisioning *This,IRTCProfile *pProfile,__LONG32 lRegisterFlags);
      HRESULT (WINAPI *DisableProfile)(IRTCClientProvisioning *This,IRTCProfile *pProfile);
      HRESULT (WINAPI *EnumerateProfiles)(IRTCClientProvisioning *This,IRTCEnumProfiles **ppEnum);
      HRESULT (WINAPI *get_Profiles)(IRTCClientProvisioning *This,IRTCCollection **ppCollection);
      HRESULT (WINAPI *GetProfile)(IRTCClientProvisioning *This,BSTR bstrUserAccount,BSTR bstrUserPassword,BSTR bstrUserURI,BSTR bstrServer,__LONG32 lTransport,LONG_PTR lCookie);
      HRESULT (WINAPI *get_SessionCapabilities)(IRTCClientProvisioning *This,__LONG32 *plSupportedSessions);
    END_INTERFACE
  } IRTCClientProvisioningVtbl;
  struct IRTCClientProvisioning {
    CONST_VTBL struct IRTCClientProvisioningVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IRTCClientProvisioning_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IRTCClientProvisioning_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IRTCClientProvisioning_Release(This) (This)->lpVtbl->Release(This)
#define IRTCClientProvisioning_CreateProfile(This,bstrProfileXML,ppProfile) (This)->lpVtbl->CreateProfile(This,bstrProfileXML,ppProfile)
#define IRTCClientProvisioning_EnableProfile(This,pProfile,lRegisterFlags) (This)->lpVtbl->EnableProfile(This,pProfile,lRegisterFlags)
#define IRTCClientProvisioning_DisableProfile(This,pProfile) (This)->lpVtbl->DisableProfile(This,pProfile)
#define IRTCClientProvisioning_EnumerateProfiles(This,ppEnum) (This)->lpVtbl->EnumerateProfiles(This,ppEnum)
#define IRTCClientProvisioning_get_Profiles(This,ppCollection) (This)->lpVtbl->get_Profiles(This,ppCollection)
#define IRTCClientProvisioning_GetProfile(This,bstrUserAccount,bstrUserPassword,bstrUserURI,bstrServer,lTransport,lCookie) (This)->lpVtbl->GetProfile(This,bstrUserAccount,bstrUserPassword,bstrUserURI,bstrServer,lTransport,lCookie)
#define IRTCClientProvisioning_get_SessionCapabilities(This,plSupportedSessions) (This)->lpVtbl->get_SessionCapabilities(This,plSupportedSessions)
#endif
#endif
  HRESULT WINAPI IRTCClientProvisioning_CreateProfile_Proxy(IRTCClientProvisioning *This,BSTR bstrProfileXML,IRTCProfile **ppProfile);
  void __RPC_STUB IRTCClientProvisioning_CreateProfile_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCClientProvisioning_EnableProfile_Proxy(IRTCClientProvisioning *This,IRTCProfile *pProfile,__LONG32 lRegisterFlags);
  void __RPC_STUB IRTCClientProvisioning_EnableProfile_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCClientProvisioning_DisableProfile_Proxy(IRTCClientProvisioning *This,IRTCProfile *pProfile);
  void __RPC_STUB IRTCClientProvisioning_DisableProfile_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCClientProvisioning_EnumerateProfiles_Proxy(IRTCClientProvisioning *This,IRTCEnumProfiles **ppEnum);
  void __RPC_STUB IRTCClientProvisioning_EnumerateProfiles_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCClientProvisioning_get_Profiles_Proxy(IRTCClientProvisioning *This,IRTCCollection **ppCollection);
  void __RPC_STUB IRTCClientProvisioning_get_Profiles_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCClientProvisioning_GetProfile_Proxy(IRTCClientProvisioning *This,BSTR bstrUserAccount,BSTR bstrUserPassword,BSTR bstrUserURI,BSTR bstrServer,__LONG32 lTransport,LONG_PTR lCookie);
  void __RPC_STUB IRTCClientProvisioning_GetProfile_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCClientProvisioning_get_SessionCapabilities_Proxy(IRTCClientProvisioning *This,__LONG32 *plSupportedSessions);
  void __RPC_STUB IRTCClientProvisioning_get_SessionCapabilities_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IRTCClientProvisioning2_INTERFACE_DEFINED__
#define __IRTCClientProvisioning2_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IRTCClientProvisioning2;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IRTCClientProvisioning2 : public IRTCClientProvisioning {
  public:
    virtual HRESULT WINAPI EnableProfileEx(IRTCProfile *pProfile,__LONG32 lRegisterFlags,__LONG32 lRoamingFlags) = 0;
  };
#else
  typedef struct IRTCClientProvisioning2Vtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IRTCClientProvisioning2 *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IRTCClientProvisioning2 *This);
      ULONG (WINAPI *Release)(IRTCClientProvisioning2 *This);
      HRESULT (WINAPI *CreateProfile)(IRTCClientProvisioning2 *This,BSTR bstrProfileXML,IRTCProfile **ppProfile);
      HRESULT (WINAPI *EnableProfile)(IRTCClientProvisioning2 *This,IRTCProfile *pProfile,__LONG32 lRegisterFlags);
      HRESULT (WINAPI *DisableProfile)(IRTCClientProvisioning2 *This,IRTCProfile *pProfile);
      HRESULT (WINAPI *EnumerateProfiles)(IRTCClientProvisioning2 *This,IRTCEnumProfiles **ppEnum);
      HRESULT (WINAPI *get_Profiles)(IRTCClientProvisioning2 *This,IRTCCollection **ppCollection);
      HRESULT (WINAPI *GetProfile)(IRTCClientProvisioning2 *This,BSTR bstrUserAccount,BSTR bstrUserPassword,BSTR bstrUserURI,BSTR bstrServer,__LONG32 lTransport,LONG_PTR lCookie);
      HRESULT (WINAPI *get_SessionCapabilities)(IRTCClientProvisioning2 *This,__LONG32 *plSupportedSessions);
      HRESULT (WINAPI *EnableProfileEx)(IRTCClientProvisioning2 *This,IRTCProfile *pProfile,__LONG32 lRegisterFlags,__LONG32 lRoamingFlags);
    END_INTERFACE
  } IRTCClientProvisioning2Vtbl;
  struct IRTCClientProvisioning2 {
    CONST_VTBL struct IRTCClientProvisioning2Vtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IRTCClientProvisioning2_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IRTCClientProvisioning2_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IRTCClientProvisioning2_Release(This) (This)->lpVtbl->Release(This)
#define IRTCClientProvisioning2_CreateProfile(This,bstrProfileXML,ppProfile) (This)->lpVtbl->CreateProfile(This,bstrProfileXML,ppProfile)
#define IRTCClientProvisioning2_EnableProfile(This,pProfile,lRegisterFlags) (This)->lpVtbl->EnableProfile(This,pProfile,lRegisterFlags)
#define IRTCClientProvisioning2_DisableProfile(This,pProfile) (This)->lpVtbl->DisableProfile(This,pProfile)
#define IRTCClientProvisioning2_EnumerateProfiles(This,ppEnum) (This)->lpVtbl->EnumerateProfiles(This,ppEnum)
#define IRTCClientProvisioning2_get_Profiles(This,ppCollection) (This)->lpVtbl->get_Profiles(This,ppCollection)
#define IRTCClientProvisioning2_GetProfile(This,bstrUserAccount,bstrUserPassword,bstrUserURI,bstrServer,lTransport,lCookie) (This)->lpVtbl->GetProfile(This,bstrUserAccount,bstrUserPassword,bstrUserURI,bstrServer,lTransport,lCookie)
#define IRTCClientProvisioning2_get_SessionCapabilities(This,plSupportedSessions) (This)->lpVtbl->get_SessionCapabilities(This,plSupportedSessions)
#define IRTCClientProvisioning2_EnableProfileEx(This,pProfile,lRegisterFlags,lRoamingFlags) (This)->lpVtbl->EnableProfileEx(This,pProfile,lRegisterFlags,lRoamingFlags)
#endif
#endif
  HRESULT WINAPI IRTCClientProvisioning2_EnableProfileEx_Proxy(IRTCClientProvisioning2 *This,IRTCProfile *pProfile,__LONG32 lRegisterFlags,__LONG32 lRoamingFlags);
  void __RPC_STUB IRTCClientProvisioning2_EnableProfileEx_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IRTCProfile_INTERFACE_DEFINED__
#define __IRTCProfile_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IRTCProfile;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IRTCProfile : public IUnknown {
  public:
    virtual HRESULT WINAPI get_Key(BSTR *pbstrKey) = 0;
    virtual HRESULT WINAPI get_Name(BSTR *pbstrName) = 0;
    virtual HRESULT WINAPI get_XML(BSTR *pbstrXML) = 0;
    virtual HRESULT WINAPI get_ProviderName(BSTR *pbstrName) = 0;
    virtual HRESULT WINAPI get_ProviderURI(RTC_PROVIDER_URI enURI,BSTR *pbstrURI) = 0;
    virtual HRESULT WINAPI get_ProviderData(BSTR *pbstrData) = 0;
    virtual HRESULT WINAPI get_ClientName(BSTR *pbstrName) = 0;
    virtual HRESULT WINAPI get_ClientBanner(VARIANT_BOOL *pfBanner) = 0;
    virtual HRESULT WINAPI get_ClientMinVer(BSTR *pbstrMinVer) = 0;
    virtual HRESULT WINAPI get_ClientCurVer(BSTR *pbstrCurVer) = 0;
    virtual HRESULT WINAPI get_ClientUpdateURI(BSTR *pbstrUpdateURI) = 0;
    virtual HRESULT WINAPI get_ClientData(BSTR *pbstrData) = 0;
    virtual HRESULT WINAPI get_UserURI(BSTR *pbstrUserURI) = 0;
    virtual HRESULT WINAPI get_UserName(BSTR *pbstrUserName) = 0;
    virtual HRESULT WINAPI get_UserAccount(BSTR *pbstrUserAccount) = 0;
    virtual HRESULT WINAPI SetCredentials(BSTR bstrUserURI,BSTR bstrUserAccount,BSTR bstrPassword) = 0;
    virtual HRESULT WINAPI get_SessionCapabilities(__LONG32 *plSupportedSessions) = 0;
    virtual HRESULT WINAPI get_State(RTC_REGISTRATION_STATE *penState) = 0;
  };
#else
  typedef struct IRTCProfileVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IRTCProfile *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IRTCProfile *This);
      ULONG (WINAPI *Release)(IRTCProfile *This);
      HRESULT (WINAPI *get_Key)(IRTCProfile *This,BSTR *pbstrKey);
      HRESULT (WINAPI *get_Name)(IRTCProfile *This,BSTR *pbstrName);
      HRESULT (WINAPI *get_XML)(IRTCProfile *This,BSTR *pbstrXML);
      HRESULT (WINAPI *get_ProviderName)(IRTCProfile *This,BSTR *pbstrName);
      HRESULT (WINAPI *get_ProviderURI)(IRTCProfile *This,RTC_PROVIDER_URI enURI,BSTR *pbstrURI);
      HRESULT (WINAPI *get_ProviderData)(IRTCProfile *This,BSTR *pbstrData);
      HRESULT (WINAPI *get_ClientName)(IRTCProfile *This,BSTR *pbstrName);
      HRESULT (WINAPI *get_ClientBanner)(IRTCProfile *This,VARIANT_BOOL *pfBanner);
      HRESULT (WINAPI *get_ClientMinVer)(IRTCProfile *This,BSTR *pbstrMinVer);
      HRESULT (WINAPI *get_ClientCurVer)(IRTCProfile *This,BSTR *pbstrCurVer);
      HRESULT (WINAPI *get_ClientUpdateURI)(IRTCProfile *This,BSTR *pbstrUpdateURI);
      HRESULT (WINAPI *get_ClientData)(IRTCProfile *This,BSTR *pbstrData);
      HRESULT (WINAPI *get_UserURI)(IRTCProfile *This,BSTR *pbstrUserURI);
      HRESULT (WINAPI *get_UserName)(IRTCProfile *This,BSTR *pbstrUserName);
      HRESULT (WINAPI *get_UserAccount)(IRTCProfile *This,BSTR *pbstrUserAccount);
      HRESULT (WINAPI *SetCredentials)(IRTCProfile *This,BSTR bstrUserURI,BSTR bstrUserAccount,BSTR bstrPassword);
      HRESULT (WINAPI *get_SessionCapabilities)(IRTCProfile *This,__LONG32 *plSupportedSessions);
      HRESULT (WINAPI *get_State)(IRTCProfile *This,RTC_REGISTRATION_STATE *penState);
    END_INTERFACE
  } IRTCProfileVtbl;
  struct IRTCProfile {
    CONST_VTBL struct IRTCProfileVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IRTCProfile_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IRTCProfile_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IRTCProfile_Release(This) (This)->lpVtbl->Release(This)
#define IRTCProfile_get_Key(This,pbstrKey) (This)->lpVtbl->get_Key(This,pbstrKey)
#define IRTCProfile_get_Name(This,pbstrName) (This)->lpVtbl->get_Name(This,pbstrName)
#define IRTCProfile_get_XML(This,pbstrXML) (This)->lpVtbl->get_XML(This,pbstrXML)
#define IRTCProfile_get_ProviderName(This,pbstrName) (This)->lpVtbl->get_ProviderName(This,pbstrName)
#define IRTCProfile_get_ProviderURI(This,enURI,pbstrURI) (This)->lpVtbl->get_ProviderURI(This,enURI,pbstrURI)
#define IRTCProfile_get_ProviderData(This,pbstrData) (This)->lpVtbl->get_ProviderData(This,pbstrData)
#define IRTCProfile_get_ClientName(This,pbstrName) (This)->lpVtbl->get_ClientName(This,pbstrName)
#define IRTCProfile_get_ClientBanner(This,pfBanner) (This)->lpVtbl->get_ClientBanner(This,pfBanner)
#define IRTCProfile_get_ClientMinVer(This,pbstrMinVer) (This)->lpVtbl->get_ClientMinVer(This,pbstrMinVer)
#define IRTCProfile_get_ClientCurVer(This,pbstrCurVer) (This)->lpVtbl->get_ClientCurVer(This,pbstrCurVer)
#define IRTCProfile_get_ClientUpdateURI(This,pbstrUpdateURI) (This)->lpVtbl->get_ClientUpdateURI(This,pbstrUpdateURI)
#define IRTCProfile_get_ClientData(This,pbstrData) (This)->lpVtbl->get_ClientData(This,pbstrData)
#define IRTCProfile_get_UserURI(This,pbstrUserURI) (This)->lpVtbl->get_UserURI(This,pbstrUserURI)
#define IRTCProfile_get_UserName(This,pbstrUserName) (This)->lpVtbl->get_UserName(This,pbstrUserName)
#define IRTCProfile_get_UserAccount(This,pbstrUserAccount) (This)->lpVtbl->get_UserAccount(This,pbstrUserAccount)
#define IRTCProfile_SetCredentials(This,bstrUserURI,bstrUserAccount,bstrPassword) (This)->lpVtbl->SetCredentials(This,bstrUserURI,bstrUserAccount,bstrPassword)
#define IRTCProfile_get_SessionCapabilities(This,plSupportedSessions) (This)->lpVtbl->get_SessionCapabilities(This,plSupportedSessions)
#define IRTCProfile_get_State(This,penState) (This)->lpVtbl->get_State(This,penState)
#endif
#endif
  HRESULT WINAPI IRTCProfile_get_Key_Proxy(IRTCProfile *This,BSTR *pbstrKey);
  void __RPC_STUB IRTCProfile_get_Key_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCProfile_get_Name_Proxy(IRTCProfile *This,BSTR *pbstrName);
  void __RPC_STUB IRTCProfile_get_Name_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCProfile_get_XML_Proxy(IRTCProfile *This,BSTR *pbstrXML);
  void __RPC_STUB IRTCProfile_get_XML_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCProfile_get_ProviderName_Proxy(IRTCProfile *This,BSTR *pbstrName);
  void __RPC_STUB IRTCProfile_get_ProviderName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCProfile_get_ProviderURI_Proxy(IRTCProfile *This,RTC_PROVIDER_URI enURI,BSTR *pbstrURI);
  void __RPC_STUB IRTCProfile_get_ProviderURI_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCProfile_get_ProviderData_Proxy(IRTCProfile *This,BSTR *pbstrData);
  void __RPC_STUB IRTCProfile_get_ProviderData_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCProfile_get_ClientName_Proxy(IRTCProfile *This,BSTR *pbstrName);
  void __RPC_STUB IRTCProfile_get_ClientName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCProfile_get_ClientBanner_Proxy(IRTCProfile *This,VARIANT_BOOL *pfBanner);
  void __RPC_STUB IRTCProfile_get_ClientBanner_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCProfile_get_ClientMinVer_Proxy(IRTCProfile *This,BSTR *pbstrMinVer);
  void __RPC_STUB IRTCProfile_get_ClientMinVer_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCProfile_get_ClientCurVer_Proxy(IRTCProfile *This,BSTR *pbstrCurVer);
  void __RPC_STUB IRTCProfile_get_ClientCurVer_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCProfile_get_ClientUpdateURI_Proxy(IRTCProfile *This,BSTR *pbstrUpdateURI);
  void __RPC_STUB IRTCProfile_get_ClientUpdateURI_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCProfile_get_ClientData_Proxy(IRTCProfile *This,BSTR *pbstrData);
  void __RPC_STUB IRTCProfile_get_ClientData_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCProfile_get_UserURI_Proxy(IRTCProfile *This,BSTR *pbstrUserURI);
  void __RPC_STUB IRTCProfile_get_UserURI_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCProfile_get_UserName_Proxy(IRTCProfile *This,BSTR *pbstrUserName);
  void __RPC_STUB IRTCProfile_get_UserName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCProfile_get_UserAccount_Proxy(IRTCProfile *This,BSTR *pbstrUserAccount);
  void __RPC_STUB IRTCProfile_get_UserAccount_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCProfile_SetCredentials_Proxy(IRTCProfile *This,BSTR bstrUserURI,BSTR bstrUserAccount,BSTR bstrPassword);
  void __RPC_STUB IRTCProfile_SetCredentials_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCProfile_get_SessionCapabilities_Proxy(IRTCProfile *This,__LONG32 *plSupportedSessions);
  void __RPC_STUB IRTCProfile_get_SessionCapabilities_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCProfile_get_State_Proxy(IRTCProfile *This,RTC_REGISTRATION_STATE *penState);
  void __RPC_STUB IRTCProfile_get_State_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IRTCProfile2_INTERFACE_DEFINED__
#define __IRTCProfile2_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IRTCProfile2;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IRTCProfile2 : public IRTCProfile {
  public:
    virtual HRESULT WINAPI get_Realm(BSTR *pbstrRealm) = 0;
    virtual HRESULT WINAPI put_Realm(BSTR bstrRealm) = 0;
    virtual HRESULT WINAPI get_AllowedAuth(__LONG32 *plAllowedAuth) = 0;
    virtual HRESULT WINAPI put_AllowedAuth(__LONG32 lAllowedAuth) = 0;
  };
#else
  typedef struct IRTCProfile2Vtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IRTCProfile2 *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IRTCProfile2 *This);
      ULONG (WINAPI *Release)(IRTCProfile2 *This);
      HRESULT (WINAPI *get_Key)(IRTCProfile2 *This,BSTR *pbstrKey);
      HRESULT (WINAPI *get_Name)(IRTCProfile2 *This,BSTR *pbstrName);
      HRESULT (WINAPI *get_XML)(IRTCProfile2 *This,BSTR *pbstrXML);
      HRESULT (WINAPI *get_ProviderName)(IRTCProfile2 *This,BSTR *pbstrName);
      HRESULT (WINAPI *get_ProviderURI)(IRTCProfile2 *This,RTC_PROVIDER_URI enURI,BSTR *pbstrURI);
      HRESULT (WINAPI *get_ProviderData)(IRTCProfile2 *This,BSTR *pbstrData);
      HRESULT (WINAPI *get_ClientName)(IRTCProfile2 *This,BSTR *pbstrName);
      HRESULT (WINAPI *get_ClientBanner)(IRTCProfile2 *This,VARIANT_BOOL *pfBanner);
      HRESULT (WINAPI *get_ClientMinVer)(IRTCProfile2 *This,BSTR *pbstrMinVer);
      HRESULT (WINAPI *get_ClientCurVer)(IRTCProfile2 *This,BSTR *pbstrCurVer);
      HRESULT (WINAPI *get_ClientUpdateURI)(IRTCProfile2 *This,BSTR *pbstrUpdateURI);
      HRESULT (WINAPI *get_ClientData)(IRTCProfile2 *This,BSTR *pbstrData);
      HRESULT (WINAPI *get_UserURI)(IRTCProfile2 *This,BSTR *pbstrUserURI);
      HRESULT (WINAPI *get_UserName)(IRTCProfile2 *This,BSTR *pbstrUserName);
      HRESULT (WINAPI *get_UserAccount)(IRTCProfile2 *This,BSTR *pbstrUserAccount);
      HRESULT (WINAPI *SetCredentials)(IRTCProfile2 *This,BSTR bstrUserURI,BSTR bstrUserAccount,BSTR bstrPassword);
      HRESULT (WINAPI *get_SessionCapabilities)(IRTCProfile2 *This,__LONG32 *plSupportedSessions);
      HRESULT (WINAPI *get_State)(IRTCProfile2 *This,RTC_REGISTRATION_STATE *penState);
      HRESULT (WINAPI *get_Realm)(IRTCProfile2 *This,BSTR *pbstrRealm);
      HRESULT (WINAPI *put_Realm)(IRTCProfile2 *This,BSTR bstrRealm);
      HRESULT (WINAPI *get_AllowedAuth)(IRTCProfile2 *This,__LONG32 *plAllowedAuth);
      HRESULT (WINAPI *put_AllowedAuth)(IRTCProfile2 *This,__LONG32 lAllowedAuth);
    END_INTERFACE
  } IRTCProfile2Vtbl;
  struct IRTCProfile2 {
    CONST_VTBL struct IRTCProfile2Vtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IRTCProfile2_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IRTCProfile2_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IRTCProfile2_Release(This) (This)->lpVtbl->Release(This)
#define IRTCProfile2_get_Key(This,pbstrKey) (This)->lpVtbl->get_Key(This,pbstrKey)
#define IRTCProfile2_get_Name(This,pbstrName) (This)->lpVtbl->get_Name(This,pbstrName)
#define IRTCProfile2_get_XML(This,pbstrXML) (This)->lpVtbl->get_XML(This,pbstrXML)
#define IRTCProfile2_get_ProviderName(This,pbstrName) (This)->lpVtbl->get_ProviderName(This,pbstrName)
#define IRTCProfile2_get_ProviderURI(This,enURI,pbstrURI) (This)->lpVtbl->get_ProviderURI(This,enURI,pbstrURI)
#define IRTCProfile2_get_ProviderData(This,pbstrData) (This)->lpVtbl->get_ProviderData(This,pbstrData)
#define IRTCProfile2_get_ClientName(This,pbstrName) (This)->lpVtbl->get_ClientName(This,pbstrName)
#define IRTCProfile2_get_ClientBanner(This,pfBanner) (This)->lpVtbl->get_ClientBanner(This,pfBanner)
#define IRTCProfile2_get_ClientMinVer(This,pbstrMinVer) (This)->lpVtbl->get_ClientMinVer(This,pbstrMinVer)
#define IRTCProfile2_get_ClientCurVer(This,pbstrCurVer) (This)->lpVtbl->get_ClientCurVer(This,pbstrCurVer)
#define IRTCProfile2_get_ClientUpdateURI(This,pbstrUpdateURI) (This)->lpVtbl->get_ClientUpdateURI(This,pbstrUpdateURI)
#define IRTCProfile2_get_ClientData(This,pbstrData) (This)->lpVtbl->get_ClientData(This,pbstrData)
#define IRTCProfile2_get_UserURI(This,pbstrUserURI) (This)->lpVtbl->get_UserURI(This,pbstrUserURI)
#define IRTCProfile2_get_UserName(This,pbstrUserName) (This)->lpVtbl->get_UserName(This,pbstrUserName)
#define IRTCProfile2_get_UserAccount(This,pbstrUserAccount) (This)->lpVtbl->get_UserAccount(This,pbstrUserAccount)
#define IRTCProfile2_SetCredentials(This,bstrUserURI,bstrUserAccount,bstrPassword) (This)->lpVtbl->SetCredentials(This,bstrUserURI,bstrUserAccount,bstrPassword)
#define IRTCProfile2_get_SessionCapabilities(This,plSupportedSessions) (This)->lpVtbl->get_SessionCapabilities(This,plSupportedSessions)
#define IRTCProfile2_get_State(This,penState) (This)->lpVtbl->get_State(This,penState)
#define IRTCProfile2_get_Realm(This,pbstrRealm) (This)->lpVtbl->get_Realm(This,pbstrRealm)
#define IRTCProfile2_put_Realm(This,bstrRealm) (This)->lpVtbl->put_Realm(This,bstrRealm)
#define IRTCProfile2_get_AllowedAuth(This,plAllowedAuth) (This)->lpVtbl->get_AllowedAuth(This,plAllowedAuth)
#define IRTCProfile2_put_AllowedAuth(This,lAllowedAuth) (This)->lpVtbl->put_AllowedAuth(This,lAllowedAuth)
#endif
#endif
  HRESULT WINAPI IRTCProfile2_get_Realm_Proxy(IRTCProfile2 *This,BSTR *pbstrRealm);
  void __RPC_STUB IRTCProfile2_get_Realm_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCProfile2_put_Realm_Proxy(IRTCProfile2 *This,BSTR bstrRealm);
  void __RPC_STUB IRTCProfile2_put_Realm_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCProfile2_get_AllowedAuth_Proxy(IRTCProfile2 *This,__LONG32 *plAllowedAuth);
  void __RPC_STUB IRTCProfile2_get_AllowedAuth_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCProfile2_put_AllowedAuth_Proxy(IRTCProfile2 *This,__LONG32 lAllowedAuth);
  void __RPC_STUB IRTCProfile2_put_AllowedAuth_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IRTCSession_INTERFACE_DEFINED__
#define __IRTCSession_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IRTCSession;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IRTCSession : public IUnknown {
  public:
    virtual HRESULT WINAPI get_Client(IRTCClient **ppClient) = 0;
    virtual HRESULT WINAPI get_State(RTC_SESSION_STATE *penState) = 0;
    virtual HRESULT WINAPI get_Type(RTC_SESSION_TYPE *penType) = 0;
    virtual HRESULT WINAPI get_Profile(IRTCProfile **ppProfile) = 0;
    virtual HRESULT WINAPI get_Participants(IRTCCollection **ppCollection) = 0;
    virtual HRESULT WINAPI Answer(void) = 0;
    virtual HRESULT WINAPI Terminate(RTC_TERMINATE_REASON enReason) = 0;
    virtual HRESULT WINAPI Redirect(RTC_SESSION_TYPE enType,BSTR bstrLocalPhoneURI,IRTCProfile *pProfile,__LONG32 lFlags) = 0;
    virtual HRESULT WINAPI AddParticipant(BSTR bstrAddress,BSTR bstrName,IRTCParticipant **ppParticipant) = 0;
    virtual HRESULT WINAPI RemoveParticipant(IRTCParticipant *pParticipant) = 0;
    virtual HRESULT WINAPI EnumerateParticipants(IRTCEnumParticipants **ppEnum) = 0;
    virtual HRESULT WINAPI get_CanAddParticipants(VARIANT_BOOL *pfCanAdd) = 0;
    virtual HRESULT WINAPI get_RedirectedUserURI(BSTR *pbstrUserURI) = 0;
    virtual HRESULT WINAPI get_RedirectedUserName(BSTR *pbstrUserName) = 0;
    virtual HRESULT WINAPI NextRedirectedUser(void) = 0;
    virtual HRESULT WINAPI SendMessage(BSTR bstrMessageHeader,BSTR bstrMessage,LONG_PTR lCookie) = 0;
    virtual HRESULT WINAPI SendMessageStatus(RTC_MESSAGING_USER_STATUS enUserStatus,LONG_PTR lCookie) = 0;
    virtual HRESULT WINAPI AddStream(__LONG32 lMediaType,LONG_PTR lCookie) = 0;
    virtual HRESULT WINAPI RemoveStream(__LONG32 lMediaType,LONG_PTR lCookie) = 0;
    virtual HRESULT WINAPI put_EncryptionKey(__LONG32 lMediaType,BSTR EncryptionKey) = 0;
  };
#else
  typedef struct IRTCSessionVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IRTCSession *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IRTCSession *This);
      ULONG (WINAPI *Release)(IRTCSession *This);
      HRESULT (WINAPI *get_Client)(IRTCSession *This,IRTCClient **ppClient);
      HRESULT (WINAPI *get_State)(IRTCSession *This,RTC_SESSION_STATE *penState);
      HRESULT (WINAPI *get_Type)(IRTCSession *This,RTC_SESSION_TYPE *penType);
      HRESULT (WINAPI *get_Profile)(IRTCSession *This,IRTCProfile **ppProfile);
      HRESULT (WINAPI *get_Participants)(IRTCSession *This,IRTCCollection **ppCollection);
      HRESULT (WINAPI *Answer)(IRTCSession *This);
      HRESULT (WINAPI *Terminate)(IRTCSession *This,RTC_TERMINATE_REASON enReason);
      HRESULT (WINAPI *Redirect)(IRTCSession *This,RTC_SESSION_TYPE enType,BSTR bstrLocalPhoneURI,IRTCProfile *pProfile,__LONG32 lFlags);
      HRESULT (WINAPI *AddParticipant)(IRTCSession *This,BSTR bstrAddress,BSTR bstrName,IRTCParticipant **ppParticipant);
      HRESULT (WINAPI *RemoveParticipant)(IRTCSession *This,IRTCParticipant *pParticipant);
      HRESULT (WINAPI *EnumerateParticipants)(IRTCSession *This,IRTCEnumParticipants **ppEnum);
      HRESULT (WINAPI *get_CanAddParticipants)(IRTCSession *This,VARIANT_BOOL *pfCanAdd);
      HRESULT (WINAPI *get_RedirectedUserURI)(IRTCSession *This,BSTR *pbstrUserURI);
      HRESULT (WINAPI *get_RedirectedUserName)(IRTCSession *This,BSTR *pbstrUserName);
      HRESULT (WINAPI *NextRedirectedUser)(IRTCSession *This);
      HRESULT (WINAPI *SendMessage)(IRTCSession *This,BSTR bstrMessageHeader,BSTR bstrMessage,LONG_PTR lCookie);
      HRESULT (WINAPI *SendMessageStatus)(IRTCSession *This,RTC_MESSAGING_USER_STATUS enUserStatus,LONG_PTR lCookie);
      HRESULT (WINAPI *AddStream)(IRTCSession *This,__LONG32 lMediaType,LONG_PTR lCookie);
      HRESULT (WINAPI *RemoveStream)(IRTCSession *This,__LONG32 lMediaType,LONG_PTR lCookie);
      HRESULT (WINAPI *put_EncryptionKey)(IRTCSession *This,__LONG32 lMediaType,BSTR EncryptionKey);
    END_INTERFACE
  } IRTCSessionVtbl;
  struct IRTCSession {
    CONST_VTBL struct IRTCSessionVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IRTCSession_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IRTCSession_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IRTCSession_Release(This) (This)->lpVtbl->Release(This)
#define IRTCSession_get_Client(This,ppClient) (This)->lpVtbl->get_Client(This,ppClient)
#define IRTCSession_get_State(This,penState) (This)->lpVtbl->get_State(This,penState)
#define IRTCSession_get_Type(This,penType) (This)->lpVtbl->get_Type(This,penType)
#define IRTCSession_get_Profile(This,ppProfile) (This)->lpVtbl->get_Profile(This,ppProfile)
#define IRTCSession_get_Participants(This,ppCollection) (This)->lpVtbl->get_Participants(This,ppCollection)
#define IRTCSession_Answer(This) (This)->lpVtbl->Answer(This)
#define IRTCSession_Terminate(This,enReason) (This)->lpVtbl->Terminate(This,enReason)
#define IRTCSession_Redirect(This,enType,bstrLocalPhoneURI,pProfile,lFlags) (This)->lpVtbl->Redirect(This,enType,bstrLocalPhoneURI,pProfile,lFlags)
#define IRTCSession_AddParticipant(This,bstrAddress,bstrName,ppParticipant) (This)->lpVtbl->AddParticipant(This,bstrAddress,bstrName,ppParticipant)
#define IRTCSession_RemoveParticipant(This,pParticipant) (This)->lpVtbl->RemoveParticipant(This,pParticipant)
#define IRTCSession_EnumerateParticipants(This,ppEnum) (This)->lpVtbl->EnumerateParticipants(This,ppEnum)
#define IRTCSession_get_CanAddParticipants(This,pfCanAdd) (This)->lpVtbl->get_CanAddParticipants(This,pfCanAdd)
#define IRTCSession_get_RedirectedUserURI(This,pbstrUserURI) (This)->lpVtbl->get_RedirectedUserURI(This,pbstrUserURI)
#define IRTCSession_get_RedirectedUserName(This,pbstrUserName) (This)->lpVtbl->get_RedirectedUserName(This,pbstrUserName)
#define IRTCSession_NextRedirectedUser(This) (This)->lpVtbl->NextRedirectedUser(This)
#define IRTCSession_SendMessage(This,bstrMessageHeader,bstrMessage,lCookie) (This)->lpVtbl->SendMessage(This,bstrMessageHeader,bstrMessage,lCookie)
#define IRTCSession_SendMessageStatus(This,enUserStatus,lCookie) (This)->lpVtbl->SendMessageStatus(This,enUserStatus,lCookie)
#define IRTCSession_AddStream(This,lMediaType,lCookie) (This)->lpVtbl->AddStream(This,lMediaType,lCookie)
#define IRTCSession_RemoveStream(This,lMediaType,lCookie) (This)->lpVtbl->RemoveStream(This,lMediaType,lCookie)
#define IRTCSession_put_EncryptionKey(This,lMediaType,EncryptionKey) (This)->lpVtbl->put_EncryptionKey(This,lMediaType,EncryptionKey)
#endif
#endif
  HRESULT WINAPI IRTCSession_get_Client_Proxy(IRTCSession *This,IRTCClient **ppClient);
  void __RPC_STUB IRTCSession_get_Client_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCSession_get_State_Proxy(IRTCSession *This,RTC_SESSION_STATE *penState);
  void __RPC_STUB IRTCSession_get_State_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCSession_get_Type_Proxy(IRTCSession *This,RTC_SESSION_TYPE *penType);
  void __RPC_STUB IRTCSession_get_Type_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCSession_get_Profile_Proxy(IRTCSession *This,IRTCProfile **ppProfile);
  void __RPC_STUB IRTCSession_get_Profile_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCSession_get_Participants_Proxy(IRTCSession *This,IRTCCollection **ppCollection);
  void __RPC_STUB IRTCSession_get_Participants_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCSession_Answer_Proxy(IRTCSession *This);
  void __RPC_STUB IRTCSession_Answer_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCSession_Terminate_Proxy(IRTCSession *This,RTC_TERMINATE_REASON enReason);
  void __RPC_STUB IRTCSession_Terminate_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCSession_Redirect_Proxy(IRTCSession *This,RTC_SESSION_TYPE enType,BSTR bstrLocalPhoneURI,IRTCProfile *pProfile,__LONG32 lFlags);
  void __RPC_STUB IRTCSession_Redirect_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCSession_AddParticipant_Proxy(IRTCSession *This,BSTR bstrAddress,BSTR bstrName,IRTCParticipant **ppParticipant);
  void __RPC_STUB IRTCSession_AddParticipant_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCSession_RemoveParticipant_Proxy(IRTCSession *This,IRTCParticipant *pParticipant);
  void __RPC_STUB IRTCSession_RemoveParticipant_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCSession_EnumerateParticipants_Proxy(IRTCSession *This,IRTCEnumParticipants **ppEnum);
  void __RPC_STUB IRTCSession_EnumerateParticipants_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCSession_get_CanAddParticipants_Proxy(IRTCSession *This,VARIANT_BOOL *pfCanAdd);
  void __RPC_STUB IRTCSession_get_CanAddParticipants_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCSession_get_RedirectedUserURI_Proxy(IRTCSession *This,BSTR *pbstrUserURI);
  void __RPC_STUB IRTCSession_get_RedirectedUserURI_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCSession_get_RedirectedUserName_Proxy(IRTCSession *This,BSTR *pbstrUserName);
  void __RPC_STUB IRTCSession_get_RedirectedUserName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCSession_NextRedirectedUser_Proxy(IRTCSession *This);
  void __RPC_STUB IRTCSession_NextRedirectedUser_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCSession_SendMessage_Proxy(IRTCSession *This,BSTR bstrMessageHeader,BSTR bstrMessage,LONG_PTR lCookie);
  void __RPC_STUB IRTCSession_SendMessage_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCSession_SendMessageStatus_Proxy(IRTCSession *This,RTC_MESSAGING_USER_STATUS enUserStatus,LONG_PTR lCookie);
  void __RPC_STUB IRTCSession_SendMessageStatus_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCSession_AddStream_Proxy(IRTCSession *This,__LONG32 lMediaType,LONG_PTR lCookie);
  void __RPC_STUB IRTCSession_AddStream_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCSession_RemoveStream_Proxy(IRTCSession *This,__LONG32 lMediaType,LONG_PTR lCookie);
  void __RPC_STUB IRTCSession_RemoveStream_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCSession_put_EncryptionKey_Proxy(IRTCSession *This,__LONG32 lMediaType,BSTR EncryptionKey);
  void __RPC_STUB IRTCSession_put_EncryptionKey_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IRTCSession2_INTERFACE_DEFINED__
#define __IRTCSession2_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IRTCSession2;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IRTCSession2 : public IRTCSession {
  public:
    virtual HRESULT WINAPI SendInfo(BSTR bstrInfoHeader,BSTR bstrInfo,LONG_PTR lCookie) = 0;
    virtual HRESULT WINAPI put_PreferredSecurityLevel(RTC_SECURITY_TYPE enSecurityType,RTC_SECURITY_LEVEL enSecurityLevel) = 0;
    virtual HRESULT WINAPI get_PreferredSecurityLevel(RTC_SECURITY_TYPE enSecurityType,RTC_SECURITY_LEVEL *penSecurityLevel) = 0;
    virtual HRESULT WINAPI IsSecurityEnabled(RTC_SECURITY_TYPE enSecurityType,VARIANT_BOOL *pfSecurityEnabled) = 0;
    virtual HRESULT WINAPI AnswerWithSessionDescription(BSTR bstrContentType,BSTR bstrSessionDescription) = 0;
    virtual HRESULT WINAPI ReInviteWithSessionDescription(BSTR bstrContentType,BSTR bstrSessionDescription,LONG_PTR lCookie) = 0;
  };
#else
  typedef struct IRTCSession2Vtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IRTCSession2 *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IRTCSession2 *This);
      ULONG (WINAPI *Release)(IRTCSession2 *This);
      HRESULT (WINAPI *get_Client)(IRTCSession2 *This,IRTCClient **ppClient);
      HRESULT (WINAPI *get_State)(IRTCSession2 *This,RTC_SESSION_STATE *penState);
      HRESULT (WINAPI *get_Type)(IRTCSession2 *This,RTC_SESSION_TYPE *penType);
      HRESULT (WINAPI *get_Profile)(IRTCSession2 *This,IRTCProfile **ppProfile);
      HRESULT (WINAPI *get_Participants)(IRTCSession2 *This,IRTCCollection **ppCollection);
      HRESULT (WINAPI *Answer)(IRTCSession2 *This);
      HRESULT (WINAPI *Terminate)(IRTCSession2 *This,RTC_TERMINATE_REASON enReason);
      HRESULT (WINAPI *Redirect)(IRTCSession2 *This,RTC_SESSION_TYPE enType,BSTR bstrLocalPhoneURI,IRTCProfile *pProfile,__LONG32 lFlags);
      HRESULT (WINAPI *AddParticipant)(IRTCSession2 *This,BSTR bstrAddress,BSTR bstrName,IRTCParticipant **ppParticipant);
      HRESULT (WINAPI *RemoveParticipant)(IRTCSession2 *This,IRTCParticipant *pParticipant);
      HRESULT (WINAPI *EnumerateParticipants)(IRTCSession2 *This,IRTCEnumParticipants **ppEnum);
      HRESULT (WINAPI *get_CanAddParticipants)(IRTCSession2 *This,VARIANT_BOOL *pfCanAdd);
      HRESULT (WINAPI *get_RedirectedUserURI)(IRTCSession2 *This,BSTR *pbstrUserURI);
      HRESULT (WINAPI *get_RedirectedUserName)(IRTCSession2 *This,BSTR *pbstrUserName);
      HRESULT (WINAPI *NextRedirectedUser)(IRTCSession2 *This);
      HRESULT (WINAPI *SendMessage)(IRTCSession2 *This,BSTR bstrMessageHeader,BSTR bstrMessage,LONG_PTR lCookie);
      HRESULT (WINAPI *SendMessageStatus)(IRTCSession2 *This,RTC_MESSAGING_USER_STATUS enUserStatus,LONG_PTR lCookie);
      HRESULT (WINAPI *AddStream)(IRTCSession2 *This,__LONG32 lMediaType,LONG_PTR lCookie);
      HRESULT (WINAPI *RemoveStream)(IRTCSession2 *This,__LONG32 lMediaType,LONG_PTR lCookie);
      HRESULT (WINAPI *put_EncryptionKey)(IRTCSession2 *This,__LONG32 lMediaType,BSTR EncryptionKey);
      HRESULT (WINAPI *SendInfo)(IRTCSession2 *This,BSTR bstrInfoHeader,BSTR bstrInfo,LONG_PTR lCookie);
      HRESULT (WINAPI *put_PreferredSecurityLevel)(IRTCSession2 *This,RTC_SECURITY_TYPE enSecurityType,RTC_SECURITY_LEVEL enSecurityLevel);
      HRESULT (WINAPI *get_PreferredSecurityLevel)(IRTCSession2 *This,RTC_SECURITY_TYPE enSecurityType,RTC_SECURITY_LEVEL *penSecurityLevel);
      HRESULT (WINAPI *IsSecurityEnabled)(IRTCSession2 *This,RTC_SECURITY_TYPE enSecurityType,VARIANT_BOOL *pfSecurityEnabled);
      HRESULT (WINAPI *AnswerWithSessionDescription)(IRTCSession2 *This,BSTR bstrContentType,BSTR bstrSessionDescription);
      HRESULT (WINAPI *ReInviteWithSessionDescription)(IRTCSession2 *This,BSTR bstrContentType,BSTR bstrSessionDescription,LONG_PTR lCookie);
    END_INTERFACE
  } IRTCSession2Vtbl;
  struct IRTCSession2 {
    CONST_VTBL struct IRTCSession2Vtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IRTCSession2_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IRTCSession2_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IRTCSession2_Release(This) (This)->lpVtbl->Release(This)
#define IRTCSession2_get_Client(This,ppClient) (This)->lpVtbl->get_Client(This,ppClient)
#define IRTCSession2_get_State(This,penState) (This)->lpVtbl->get_State(This,penState)
#define IRTCSession2_get_Type(This,penType) (This)->lpVtbl->get_Type(This,penType)
#define IRTCSession2_get_Profile(This,ppProfile) (This)->lpVtbl->get_Profile(This,ppProfile)
#define IRTCSession2_get_Participants(This,ppCollection) (This)->lpVtbl->get_Participants(This,ppCollection)
#define IRTCSession2_Answer(This) (This)->lpVtbl->Answer(This)
#define IRTCSession2_Terminate(This,enReason) (This)->lpVtbl->Terminate(This,enReason)
#define IRTCSession2_Redirect(This,enType,bstrLocalPhoneURI,pProfile,lFlags) (This)->lpVtbl->Redirect(This,enType,bstrLocalPhoneURI,pProfile,lFlags)
#define IRTCSession2_AddParticipant(This,bstrAddress,bstrName,ppParticipant) (This)->lpVtbl->AddParticipant(This,bstrAddress,bstrName,ppParticipant)
#define IRTCSession2_RemoveParticipant(This,pParticipant) (This)->lpVtbl->RemoveParticipant(This,pParticipant)
#define IRTCSession2_EnumerateParticipants(This,ppEnum) (This)->lpVtbl->EnumerateParticipants(This,ppEnum)
#define IRTCSession2_get_CanAddParticipants(This,pfCanAdd) (This)->lpVtbl->get_CanAddParticipants(This,pfCanAdd)
#define IRTCSession2_get_RedirectedUserURI(This,pbstrUserURI) (This)->lpVtbl->get_RedirectedUserURI(This,pbstrUserURI)
#define IRTCSession2_get_RedirectedUserName(This,pbstrUserName) (This)->lpVtbl->get_RedirectedUserName(This,pbstrUserName)
#define IRTCSession2_NextRedirectedUser(This) (This)->lpVtbl->NextRedirectedUser(This)
#define IRTCSession2_SendMessage(This,bstrMessageHeader,bstrMessage,lCookie) (This)->lpVtbl->SendMessage(This,bstrMessageHeader,bstrMessage,lCookie)
#define IRTCSession2_SendMessageStatus(This,enUserStatus,lCookie) (This)->lpVtbl->SendMessageStatus(This,enUserStatus,lCookie)
#define IRTCSession2_AddStream(This,lMediaType,lCookie) (This)->lpVtbl->AddStream(This,lMediaType,lCookie)
#define IRTCSession2_RemoveStream(This,lMediaType,lCookie) (This)->lpVtbl->RemoveStream(This,lMediaType,lCookie)
#define IRTCSession2_put_EncryptionKey(This,lMediaType,EncryptionKey) (This)->lpVtbl->put_EncryptionKey(This,lMediaType,EncryptionKey)
#define IRTCSession2_SendInfo(This,bstrInfoHeader,bstrInfo,lCookie) (This)->lpVtbl->SendInfo(This,bstrInfoHeader,bstrInfo,lCookie)
#define IRTCSession2_put_PreferredSecurityLevel(This,enSecurityType,enSecurityLevel) (This)->lpVtbl->put_PreferredSecurityLevel(This,enSecurityType,enSecurityLevel)
#define IRTCSession2_get_PreferredSecurityLevel(This,enSecurityType,penSecurityLevel) (This)->lpVtbl->get_PreferredSecurityLevel(This,enSecurityType,penSecurityLevel)
#define IRTCSession2_IsSecurityEnabled(This,enSecurityType,pfSecurityEnabled) (This)->lpVtbl->IsSecurityEnabled(This,enSecurityType,pfSecurityEnabled)
#define IRTCSession2_AnswerWithSessionDescription(This,bstrContentType,bstrSessionDescription) (This)->lpVtbl->AnswerWithSessionDescription(This,bstrContentType,bstrSessionDescription)
#define IRTCSession2_ReInviteWithSessionDescription(This,bstrContentType,bstrSessionDescription,lCookie) (This)->lpVtbl->ReInviteWithSessionDescription(This,bstrContentType,bstrSessionDescription,lCookie)
#endif
#endif
  HRESULT WINAPI IRTCSession2_SendInfo_Proxy(IRTCSession2 *This,BSTR bstrInfoHeader,BSTR bstrInfo,LONG_PTR lCookie);
  void __RPC_STUB IRTCSession2_SendInfo_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCSession2_put_PreferredSecurityLevel_Proxy(IRTCSession2 *This,RTC_SECURITY_TYPE enSecurityType,RTC_SECURITY_LEVEL enSecurityLevel);
  void __RPC_STUB IRTCSession2_put_PreferredSecurityLevel_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCSession2_get_PreferredSecurityLevel_Proxy(IRTCSession2 *This,RTC_SECURITY_TYPE enSecurityType,RTC_SECURITY_LEVEL *penSecurityLevel);
  void __RPC_STUB IRTCSession2_get_PreferredSecurityLevel_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCSession2_IsSecurityEnabled_Proxy(IRTCSession2 *This,RTC_SECURITY_TYPE enSecurityType,VARIANT_BOOL *pfSecurityEnabled);
  void __RPC_STUB IRTCSession2_IsSecurityEnabled_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCSession2_AnswerWithSessionDescription_Proxy(IRTCSession2 *This,BSTR bstrContentType,BSTR bstrSessionDescription);
  void __RPC_STUB IRTCSession2_AnswerWithSessionDescription_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCSession2_ReInviteWithSessionDescription_Proxy(IRTCSession2 *This,BSTR bstrContentType,BSTR bstrSessionDescription,LONG_PTR lCookie);
  void __RPC_STUB IRTCSession2_ReInviteWithSessionDescription_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IRTCSessionCallControl_INTERFACE_DEFINED__
#define __IRTCSessionCallControl_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IRTCSessionCallControl;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IRTCSessionCallControl : public IUnknown {
  public:
    virtual HRESULT WINAPI Hold(LONG_PTR lCookie) = 0;
    virtual HRESULT WINAPI UnHold(LONG_PTR lCookie) = 0;
    virtual HRESULT WINAPI Forward(BSTR bstrForwardToURI) = 0;
    virtual HRESULT WINAPI Refer(BSTR bstrReferToURI,BSTR bstrReferCookie) = 0;
    virtual HRESULT WINAPI put_ReferredByURI(BSTR bstrReferredByURI) = 0;
    virtual HRESULT WINAPI get_ReferredByURI(BSTR *pbstrReferredByURI) = 0;
    virtual HRESULT WINAPI put_ReferCookie(BSTR bstrReferCookie) = 0;
    virtual HRESULT WINAPI get_ReferCookie(BSTR *pbstrReferCookie) = 0;
    virtual HRESULT WINAPI get_IsReferred(VARIANT_BOOL *pfIsReferred) = 0;
  };
#else
  typedef struct IRTCSessionCallControlVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IRTCSessionCallControl *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IRTCSessionCallControl *This);
      ULONG (WINAPI *Release)(IRTCSessionCallControl *This);
      HRESULT (WINAPI *Hold)(IRTCSessionCallControl *This,LONG_PTR lCookie);
      HRESULT (WINAPI *UnHold)(IRTCSessionCallControl *This,LONG_PTR lCookie);
      HRESULT (WINAPI *Forward)(IRTCSessionCallControl *This,BSTR bstrForwardToURI);
      HRESULT (WINAPI *Refer)(IRTCSessionCallControl *This,BSTR bstrReferToURI,BSTR bstrReferCookie);
      HRESULT (WINAPI *put_ReferredByURI)(IRTCSessionCallControl *This,BSTR bstrReferredByURI);
      HRESULT (WINAPI *get_ReferredByURI)(IRTCSessionCallControl *This,BSTR *pbstrReferredByURI);
      HRESULT (WINAPI *put_ReferCookie)(IRTCSessionCallControl *This,BSTR bstrReferCookie);
      HRESULT (WINAPI *get_ReferCookie)(IRTCSessionCallControl *This,BSTR *pbstrReferCookie);
      HRESULT (WINAPI *get_IsReferred)(IRTCSessionCallControl *This,VARIANT_BOOL *pfIsReferred);
    END_INTERFACE
  } IRTCSessionCallControlVtbl;
  struct IRTCSessionCallControl {
    CONST_VTBL struct IRTCSessionCallControlVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IRTCSessionCallControl_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IRTCSessionCallControl_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IRTCSessionCallControl_Release(This) (This)->lpVtbl->Release(This)
#define IRTCSessionCallControl_Hold(This,lCookie) (This)->lpVtbl->Hold(This,lCookie)
#define IRTCSessionCallControl_UnHold(This,lCookie) (This)->lpVtbl->UnHold(This,lCookie)
#define IRTCSessionCallControl_Forward(This,bstrForwardToURI) (This)->lpVtbl->Forward(This,bstrForwardToURI)
#define IRTCSessionCallControl_Refer(This,bstrReferToURI,bstrReferCookie) (This)->lpVtbl->Refer(This,bstrReferToURI,bstrReferCookie)
#define IRTCSessionCallControl_put_ReferredByURI(This,bstrReferredByURI) (This)->lpVtbl->put_ReferredByURI(This,bstrReferredByURI)
#define IRTCSessionCallControl_get_ReferredByURI(This,pbstrReferredByURI) (This)->lpVtbl->get_ReferredByURI(This,pbstrReferredByURI)
#define IRTCSessionCallControl_put_ReferCookie(This,bstrReferCookie) (This)->lpVtbl->put_ReferCookie(This,bstrReferCookie)
#define IRTCSessionCallControl_get_ReferCookie(This,pbstrReferCookie) (This)->lpVtbl->get_ReferCookie(This,pbstrReferCookie)
#define IRTCSessionCallControl_get_IsReferred(This,pfIsReferred) (This)->lpVtbl->get_IsReferred(This,pfIsReferred)
#endif
#endif
  HRESULT WINAPI IRTCSessionCallControl_Hold_Proxy(IRTCSessionCallControl *This,LONG_PTR lCookie);
  void __RPC_STUB IRTCSessionCallControl_Hold_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCSessionCallControl_UnHold_Proxy(IRTCSessionCallControl *This,LONG_PTR lCookie);
  void __RPC_STUB IRTCSessionCallControl_UnHold_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCSessionCallControl_Forward_Proxy(IRTCSessionCallControl *This,BSTR bstrForwardToURI);
  void __RPC_STUB IRTCSessionCallControl_Forward_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCSessionCallControl_Refer_Proxy(IRTCSessionCallControl *This,BSTR bstrReferToURI,BSTR bstrReferCookie);
  void __RPC_STUB IRTCSessionCallControl_Refer_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCSessionCallControl_put_ReferredByURI_Proxy(IRTCSessionCallControl *This,BSTR bstrReferredByURI);
  void __RPC_STUB IRTCSessionCallControl_put_ReferredByURI_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCSessionCallControl_get_ReferredByURI_Proxy(IRTCSessionCallControl *This,BSTR *pbstrReferredByURI);
  void __RPC_STUB IRTCSessionCallControl_get_ReferredByURI_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCSessionCallControl_put_ReferCookie_Proxy(IRTCSessionCallControl *This,BSTR bstrReferCookie);
  void __RPC_STUB IRTCSessionCallControl_put_ReferCookie_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCSessionCallControl_get_ReferCookie_Proxy(IRTCSessionCallControl *This,BSTR *pbstrReferCookie);
  void __RPC_STUB IRTCSessionCallControl_get_ReferCookie_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCSessionCallControl_get_IsReferred_Proxy(IRTCSessionCallControl *This,VARIANT_BOOL *pfIsReferred);
  void __RPC_STUB IRTCSessionCallControl_get_IsReferred_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IRTCParticipant_INTERFACE_DEFINED__
#define __IRTCParticipant_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IRTCParticipant;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IRTCParticipant : public IUnknown {
  public:
    virtual HRESULT WINAPI get_UserURI(BSTR *pbstrUserURI) = 0;
    virtual HRESULT WINAPI get_Name(BSTR *pbstrName) = 0;
    virtual HRESULT WINAPI get_Removable(VARIANT_BOOL *pfRemovable) = 0;
    virtual HRESULT WINAPI get_State(RTC_PARTICIPANT_STATE *penState) = 0;
    virtual HRESULT WINAPI get_Session(IRTCSession **ppSession) = 0;
  };
#else
  typedef struct IRTCParticipantVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IRTCParticipant *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IRTCParticipant *This);
      ULONG (WINAPI *Release)(IRTCParticipant *This);
      HRESULT (WINAPI *get_UserURI)(IRTCParticipant *This,BSTR *pbstrUserURI);
      HRESULT (WINAPI *get_Name)(IRTCParticipant *This,BSTR *pbstrName);
      HRESULT (WINAPI *get_Removable)(IRTCParticipant *This,VARIANT_BOOL *pfRemovable);
      HRESULT (WINAPI *get_State)(IRTCParticipant *This,RTC_PARTICIPANT_STATE *penState);
      HRESULT (WINAPI *get_Session)(IRTCParticipant *This,IRTCSession **ppSession);
    END_INTERFACE
  } IRTCParticipantVtbl;
  struct IRTCParticipant {
    CONST_VTBL struct IRTCParticipantVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IRTCParticipant_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IRTCParticipant_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IRTCParticipant_Release(This) (This)->lpVtbl->Release(This)
#define IRTCParticipant_get_UserURI(This,pbstrUserURI) (This)->lpVtbl->get_UserURI(This,pbstrUserURI)
#define IRTCParticipant_get_Name(This,pbstrName) (This)->lpVtbl->get_Name(This,pbstrName)
#define IRTCParticipant_get_Removable(This,pfRemovable) (This)->lpVtbl->get_Removable(This,pfRemovable)
#define IRTCParticipant_get_State(This,penState) (This)->lpVtbl->get_State(This,penState)
#define IRTCParticipant_get_Session(This,ppSession) (This)->lpVtbl->get_Session(This,ppSession)
#endif
#endif
  HRESULT WINAPI IRTCParticipant_get_UserURI_Proxy(IRTCParticipant *This,BSTR *pbstrUserURI);
  void __RPC_STUB IRTCParticipant_get_UserURI_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCParticipant_get_Name_Proxy(IRTCParticipant *This,BSTR *pbstrName);
  void __RPC_STUB IRTCParticipant_get_Name_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCParticipant_get_Removable_Proxy(IRTCParticipant *This,VARIANT_BOOL *pfRemovable);
  void __RPC_STUB IRTCParticipant_get_Removable_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCParticipant_get_State_Proxy(IRTCParticipant *This,RTC_PARTICIPANT_STATE *penState);
  void __RPC_STUB IRTCParticipant_get_State_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCParticipant_get_Session_Proxy(IRTCParticipant *This,IRTCSession **ppSession);
  void __RPC_STUB IRTCParticipant_get_Session_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif
#ifndef __IRTCRoamingEvent_INTERFACE_DEFINED__
#define __IRTCRoamingEvent_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IRTCRoamingEvent;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IRTCRoamingEvent : public IDispatch {
  public:
    virtual HRESULT WINAPI get_EventType(RTC_ROAMING_EVENT_TYPE *pEventType) = 0;
    virtual HRESULT WINAPI get_Profile(IRTCProfile2 **ppProfile) = 0;
    virtual HRESULT WINAPI get_StatusCode(__LONG32 *plStatusCode) = 0;
    virtual HRESULT WINAPI get_StatusText(BSTR *pbstrStatusText) = 0;
  };
#else
  typedef struct IRTCRoamingEventVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IRTCRoamingEvent *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IRTCRoamingEvent *This);
      ULONG (WINAPI *Release)(IRTCRoamingEvent *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IRTCRoamingEvent *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IRTCRoamingEvent *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IRTCRoamingEvent *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IRTCRoamingEvent *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_EventType)(IRTCRoamingEvent *This,RTC_ROAMING_EVENT_TYPE *pEventType);
      HRESULT (WINAPI *get_Profile)(IRTCRoamingEvent *This,IRTCProfile2 **ppProfile);
      HRESULT (WINAPI *get_StatusCode)(IRTCRoamingEvent *This,__LONG32 *plStatusCode);
      HRESULT (WINAPI *get_StatusText)(IRTCRoamingEvent *This,BSTR *pbstrStatusText);
    END_INTERFACE
  } IRTCRoamingEventVtbl;
  struct IRTCRoamingEvent {
    CONST_VTBL struct IRTCRoamingEventVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IRTCRoamingEvent_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IRTCRoamingEvent_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IRTCRoamingEvent_Release(This) (This)->lpVtbl->Release(This)
#define IRTCRoamingEvent_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IRTCRoamingEvent_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IRTCRoamingEvent_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IRTCRoamingEvent_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IRTCRoamingEvent_get_EventType(This,pEventType) (This)->lpVtbl->get_EventType(This,pEventType)
#define IRTCRoamingEvent_get_Profile(This,ppProfile) (This)->lpVtbl->get_Profile(This,ppProfile)
#define IRTCRoamingEvent_get_StatusCode(This,plStatusCode) (This)->lpVtbl->get_StatusCode(This,plStatusCode)
#define IRTCRoamingEvent_get_StatusText(This,pbstrStatusText) (This)->lpVtbl->get_StatusText(This,pbstrStatusText)
#endif
#endif
  HRESULT WINAPI IRTCRoamingEvent_get_EventType_Proxy(IRTCRoamingEvent *This,RTC_ROAMING_EVENT_TYPE *pEventType);
  void __RPC_STUB IRTCRoamingEvent_get_EventType_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCRoamingEvent_get_Profile_Proxy(IRTCRoamingEvent *This,IRTCProfile2 **ppProfile);
  void __RPC_STUB IRTCRoamingEvent_get_Profile_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCRoamingEvent_get_StatusCode_Proxy(IRTCRoamingEvent *This,__LONG32 *plStatusCode);
  void __RPC_STUB IRTCRoamingEvent_get_StatusCode_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCRoamingEvent_get_StatusText_Proxy(IRTCRoamingEvent *This,BSTR *pbstrStatusText);
  void __RPC_STUB IRTCRoamingEvent_get_StatusText_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IRTCProfileEvent_INTERFACE_DEFINED__
#define __IRTCProfileEvent_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IRTCProfileEvent;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IRTCProfileEvent : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Profile(IRTCProfile **ppProfile) = 0;
    virtual HRESULT WINAPI get_Cookie(LONG_PTR *plCookie) = 0;
    virtual HRESULT WINAPI get_StatusCode(__LONG32 *plStatusCode) = 0;
  };
#else
  typedef struct IRTCProfileEventVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IRTCProfileEvent *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IRTCProfileEvent *This);
      ULONG (WINAPI *Release)(IRTCProfileEvent *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IRTCProfileEvent *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IRTCProfileEvent *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IRTCProfileEvent *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IRTCProfileEvent *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Profile)(IRTCProfileEvent *This,IRTCProfile **ppProfile);
      HRESULT (WINAPI *get_Cookie)(IRTCProfileEvent *This,LONG_PTR *plCookie);
      HRESULT (WINAPI *get_StatusCode)(IRTCProfileEvent *This,__LONG32 *plStatusCode);
    END_INTERFACE
  } IRTCProfileEventVtbl;
  struct IRTCProfileEvent {
    CONST_VTBL struct IRTCProfileEventVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IRTCProfileEvent_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IRTCProfileEvent_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IRTCProfileEvent_Release(This) (This)->lpVtbl->Release(This)
#define IRTCProfileEvent_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IRTCProfileEvent_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IRTCProfileEvent_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IRTCProfileEvent_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IRTCProfileEvent_get_Profile(This,ppProfile) (This)->lpVtbl->get_Profile(This,ppProfile)
#define IRTCProfileEvent_get_Cookie(This,plCookie) (This)->lpVtbl->get_Cookie(This,plCookie)
#define IRTCProfileEvent_get_StatusCode(This,plStatusCode) (This)->lpVtbl->get_StatusCode(This,plStatusCode)
#endif
#endif
  HRESULT WINAPI IRTCProfileEvent_get_Profile_Proxy(IRTCProfileEvent *This,IRTCProfile **ppProfile);
  void __RPC_STUB IRTCProfileEvent_get_Profile_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCProfileEvent_get_Cookie_Proxy(IRTCProfileEvent *This,LONG_PTR *plCookie);
  void __RPC_STUB IRTCProfileEvent_get_Cookie_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCProfileEvent_get_StatusCode_Proxy(IRTCProfileEvent *This,__LONG32 *plStatusCode);
  void __RPC_STUB IRTCProfileEvent_get_StatusCode_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IRTCProfileEvent2_INTERFACE_DEFINED__
#define __IRTCProfileEvent2_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IRTCProfileEvent2;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IRTCProfileEvent2 : public IRTCProfileEvent {
  public:
    virtual HRESULT WINAPI get_EventType(RTC_PROFILE_EVENT_TYPE *pEventType) = 0;
  };
#else
  typedef struct IRTCProfileEvent2Vtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IRTCProfileEvent2 *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IRTCProfileEvent2 *This);
      ULONG (WINAPI *Release)(IRTCProfileEvent2 *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IRTCProfileEvent2 *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IRTCProfileEvent2 *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IRTCProfileEvent2 *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IRTCProfileEvent2 *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Profile)(IRTCProfileEvent2 *This,IRTCProfile **ppProfile);
      HRESULT (WINAPI *get_Cookie)(IRTCProfileEvent2 *This,LONG_PTR *plCookie);
      HRESULT (WINAPI *get_StatusCode)(IRTCProfileEvent2 *This,__LONG32 *plStatusCode);
      HRESULT (WINAPI *get_EventType)(IRTCProfileEvent2 *This,RTC_PROFILE_EVENT_TYPE *pEventType);
    END_INTERFACE
  } IRTCProfileEvent2Vtbl;
  struct IRTCProfileEvent2 {
    CONST_VTBL struct IRTCProfileEvent2Vtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IRTCProfileEvent2_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IRTCProfileEvent2_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IRTCProfileEvent2_Release(This) (This)->lpVtbl->Release(This)
#define IRTCProfileEvent2_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IRTCProfileEvent2_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IRTCProfileEvent2_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IRTCProfileEvent2_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IRTCProfileEvent2_get_Profile(This,ppProfile) (This)->lpVtbl->get_Profile(This,ppProfile)
#define IRTCProfileEvent2_get_Cookie(This,plCookie) (This)->lpVtbl->get_Cookie(This,plCookie)
#define IRTCProfileEvent2_get_StatusCode(This,plStatusCode) (This)->lpVtbl->get_StatusCode(This,plStatusCode)
#define IRTCProfileEvent2_get_EventType(This,pEventType) (This)->lpVtbl->get_EventType(This,pEventType)
#endif
#endif
  HRESULT WINAPI IRTCProfileEvent2_get_EventType_Proxy(IRTCProfileEvent2 *This,RTC_PROFILE_EVENT_TYPE *pEventType);
  void __RPC_STUB IRTCProfileEvent2_get_EventType_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IRTCClientEvent_INTERFACE_DEFINED__
#define __IRTCClientEvent_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IRTCClientEvent;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IRTCClientEvent : public IDispatch {
  public:
    virtual HRESULT WINAPI get_EventType(RTC_CLIENT_EVENT_TYPE *penEventType) = 0;
    virtual HRESULT WINAPI get_Client(IRTCClient **ppClient) = 0;
  };
#else
  typedef struct IRTCClientEventVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IRTCClientEvent *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IRTCClientEvent *This);
      ULONG (WINAPI *Release)(IRTCClientEvent *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IRTCClientEvent *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IRTCClientEvent *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IRTCClientEvent *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IRTCClientEvent *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_EventType)(IRTCClientEvent *This,RTC_CLIENT_EVENT_TYPE *penEventType);
      HRESULT (WINAPI *get_Client)(IRTCClientEvent *This,IRTCClient **ppClient);
    END_INTERFACE
  } IRTCClientEventVtbl;
  struct IRTCClientEvent {
    CONST_VTBL struct IRTCClientEventVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IRTCClientEvent_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IRTCClientEvent_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IRTCClientEvent_Release(This) (This)->lpVtbl->Release(This)
#define IRTCClientEvent_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IRTCClientEvent_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IRTCClientEvent_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IRTCClientEvent_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IRTCClientEvent_get_EventType(This,penEventType) (This)->lpVtbl->get_EventType(This,penEventType)
#define IRTCClientEvent_get_Client(This,ppClient) (This)->lpVtbl->get_Client(This,ppClient)
#endif
#endif
  HRESULT WINAPI IRTCClientEvent_get_EventType_Proxy(IRTCClientEvent *This,RTC_CLIENT_EVENT_TYPE *penEventType);
  void __RPC_STUB IRTCClientEvent_get_EventType_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCClientEvent_get_Client_Proxy(IRTCClientEvent *This,IRTCClient **ppClient);
  void __RPC_STUB IRTCClientEvent_get_Client_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IRTCRegistrationStateChangeEvent_INTERFACE_DEFINED__
#define __IRTCRegistrationStateChangeEvent_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IRTCRegistrationStateChangeEvent;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IRTCRegistrationStateChangeEvent : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Profile(IRTCProfile **ppProfile) = 0;
    virtual HRESULT WINAPI get_State(RTC_REGISTRATION_STATE *penState) = 0;
    virtual HRESULT WINAPI get_StatusCode(__LONG32 *plStatusCode) = 0;
    virtual HRESULT WINAPI get_StatusText(BSTR *pbstrStatusText) = 0;
  };
#else
  typedef struct IRTCRegistrationStateChangeEventVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IRTCRegistrationStateChangeEvent *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IRTCRegistrationStateChangeEvent *This);
      ULONG (WINAPI *Release)(IRTCRegistrationStateChangeEvent *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IRTCRegistrationStateChangeEvent *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IRTCRegistrationStateChangeEvent *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IRTCRegistrationStateChangeEvent *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IRTCRegistrationStateChangeEvent *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Profile)(IRTCRegistrationStateChangeEvent *This,IRTCProfile **ppProfile);
      HRESULT (WINAPI *get_State)(IRTCRegistrationStateChangeEvent *This,RTC_REGISTRATION_STATE *penState);
      HRESULT (WINAPI *get_StatusCode)(IRTCRegistrationStateChangeEvent *This,__LONG32 *plStatusCode);
      HRESULT (WINAPI *get_StatusText)(IRTCRegistrationStateChangeEvent *This,BSTR *pbstrStatusText);
    END_INTERFACE
  } IRTCRegistrationStateChangeEventVtbl;
  struct IRTCRegistrationStateChangeEvent {
    CONST_VTBL struct IRTCRegistrationStateChangeEventVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IRTCRegistrationStateChangeEvent_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IRTCRegistrationStateChangeEvent_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IRTCRegistrationStateChangeEvent_Release(This) (This)->lpVtbl->Release(This)
#define IRTCRegistrationStateChangeEvent_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IRTCRegistrationStateChangeEvent_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IRTCRegistrationStateChangeEvent_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IRTCRegistrationStateChangeEvent_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IRTCRegistrationStateChangeEvent_get_Profile(This,ppProfile) (This)->lpVtbl->get_Profile(This,ppProfile)
#define IRTCRegistrationStateChangeEvent_get_State(This,penState) (This)->lpVtbl->get_State(This,penState)
#define IRTCRegistrationStateChangeEvent_get_StatusCode(This,plStatusCode) (This)->lpVtbl->get_StatusCode(This,plStatusCode)
#define IRTCRegistrationStateChangeEvent_get_StatusText(This,pbstrStatusText) (This)->lpVtbl->get_StatusText(This,pbstrStatusText)
#endif
#endif
  HRESULT WINAPI IRTCRegistrationStateChangeEvent_get_Profile_Proxy(IRTCRegistrationStateChangeEvent *This,IRTCProfile **ppProfile);
  void __RPC_STUB IRTCRegistrationStateChangeEvent_get_Profile_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCRegistrationStateChangeEvent_get_State_Proxy(IRTCRegistrationStateChangeEvent *This,RTC_REGISTRATION_STATE *penState);
  void __RPC_STUB IRTCRegistrationStateChangeEvent_get_State_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCRegistrationStateChangeEvent_get_StatusCode_Proxy(IRTCRegistrationStateChangeEvent *This,__LONG32 *plStatusCode);
  void __RPC_STUB IRTCRegistrationStateChangeEvent_get_StatusCode_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCRegistrationStateChangeEvent_get_StatusText_Proxy(IRTCRegistrationStateChangeEvent *This,BSTR *pbstrStatusText);
  void __RPC_STUB IRTCRegistrationStateChangeEvent_get_StatusText_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IRTCSessionStateChangeEvent_INTERFACE_DEFINED__
#define __IRTCSessionStateChangeEvent_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IRTCSessionStateChangeEvent;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IRTCSessionStateChangeEvent : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Session(IRTCSession **ppSession) = 0;
    virtual HRESULT WINAPI get_State(RTC_SESSION_STATE *penState) = 0;
    virtual HRESULT WINAPI get_StatusCode(__LONG32 *plStatusCode) = 0;
    virtual HRESULT WINAPI get_StatusText(BSTR *pbstrStatusText) = 0;
  };
#else
  typedef struct IRTCSessionStateChangeEventVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IRTCSessionStateChangeEvent *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IRTCSessionStateChangeEvent *This);
      ULONG (WINAPI *Release)(IRTCSessionStateChangeEvent *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IRTCSessionStateChangeEvent *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IRTCSessionStateChangeEvent *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IRTCSessionStateChangeEvent *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IRTCSessionStateChangeEvent *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Session)(IRTCSessionStateChangeEvent *This,IRTCSession **ppSession);
      HRESULT (WINAPI *get_State)(IRTCSessionStateChangeEvent *This,RTC_SESSION_STATE *penState);
      HRESULT (WINAPI *get_StatusCode)(IRTCSessionStateChangeEvent *This,__LONG32 *plStatusCode);
      HRESULT (WINAPI *get_StatusText)(IRTCSessionStateChangeEvent *This,BSTR *pbstrStatusText);
    END_INTERFACE
  } IRTCSessionStateChangeEventVtbl;
  struct IRTCSessionStateChangeEvent {
    CONST_VTBL struct IRTCSessionStateChangeEventVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IRTCSessionStateChangeEvent_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IRTCSessionStateChangeEvent_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IRTCSessionStateChangeEvent_Release(This) (This)->lpVtbl->Release(This)
#define IRTCSessionStateChangeEvent_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IRTCSessionStateChangeEvent_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IRTCSessionStateChangeEvent_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IRTCSessionStateChangeEvent_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IRTCSessionStateChangeEvent_get_Session(This,ppSession) (This)->lpVtbl->get_Session(This,ppSession)
#define IRTCSessionStateChangeEvent_get_State(This,penState) (This)->lpVtbl->get_State(This,penState)
#define IRTCSessionStateChangeEvent_get_StatusCode(This,plStatusCode) (This)->lpVtbl->get_StatusCode(This,plStatusCode)
#define IRTCSessionStateChangeEvent_get_StatusText(This,pbstrStatusText) (This)->lpVtbl->get_StatusText(This,pbstrStatusText)
#endif
#endif
  HRESULT WINAPI IRTCSessionStateChangeEvent_get_Session_Proxy(IRTCSessionStateChangeEvent *This,IRTCSession **ppSession);
  void __RPC_STUB IRTCSessionStateChangeEvent_get_Session_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCSessionStateChangeEvent_get_State_Proxy(IRTCSessionStateChangeEvent *This,RTC_SESSION_STATE *penState);
  void __RPC_STUB IRTCSessionStateChangeEvent_get_State_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCSessionStateChangeEvent_get_StatusCode_Proxy(IRTCSessionStateChangeEvent *This,__LONG32 *plStatusCode);
  void __RPC_STUB IRTCSessionStateChangeEvent_get_StatusCode_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCSessionStateChangeEvent_get_StatusText_Proxy(IRTCSessionStateChangeEvent *This,BSTR *pbstrStatusText);
  void __RPC_STUB IRTCSessionStateChangeEvent_get_StatusText_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IRTCSessionStateChangeEvent2_INTERFACE_DEFINED__
#define __IRTCSessionStateChangeEvent2_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IRTCSessionStateChangeEvent2;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IRTCSessionStateChangeEvent2 : public IRTCSessionStateChangeEvent {
  public:
    virtual HRESULT WINAPI get_MediaTypes(__LONG32 *pMediaTypes) = 0;
    virtual HRESULT WINAPI get_RemotePreferredSecurityLevel(RTC_SECURITY_TYPE enSecurityType,RTC_SECURITY_LEVEL *penSecurityLevel) = 0;
    virtual HRESULT WINAPI get_IsForked(VARIANT_BOOL *pfIsForked) = 0;
    virtual HRESULT WINAPI GetRemoteSessionDescription(BSTR *pbstrContentType,BSTR *pbstrSessionDescription) = 0;
  };
#else
  typedef struct IRTCSessionStateChangeEvent2Vtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IRTCSessionStateChangeEvent2 *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IRTCSessionStateChangeEvent2 *This);
      ULONG (WINAPI *Release)(IRTCSessionStateChangeEvent2 *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IRTCSessionStateChangeEvent2 *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IRTCSessionStateChangeEvent2 *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IRTCSessionStateChangeEvent2 *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IRTCSessionStateChangeEvent2 *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Session)(IRTCSessionStateChangeEvent2 *This,IRTCSession **ppSession);
      HRESULT (WINAPI *get_State)(IRTCSessionStateChangeEvent2 *This,RTC_SESSION_STATE *penState);
      HRESULT (WINAPI *get_StatusCode)(IRTCSessionStateChangeEvent2 *This,__LONG32 *plStatusCode);
      HRESULT (WINAPI *get_StatusText)(IRTCSessionStateChangeEvent2 *This,BSTR *pbstrStatusText);
      HRESULT (WINAPI *get_MediaTypes)(IRTCSessionStateChangeEvent2 *This,__LONG32 *pMediaTypes);
      HRESULT (WINAPI *get_RemotePreferredSecurityLevel)(IRTCSessionStateChangeEvent2 *This,RTC_SECURITY_TYPE enSecurityType,RTC_SECURITY_LEVEL *penSecurityLevel);
      HRESULT (WINAPI *get_IsForked)(IRTCSessionStateChangeEvent2 *This,VARIANT_BOOL *pfIsForked);
      HRESULT (WINAPI *GetRemoteSessionDescription)(IRTCSessionStateChangeEvent2 *This,BSTR *pbstrContentType,BSTR *pbstrSessionDescription);
    END_INTERFACE
  } IRTCSessionStateChangeEvent2Vtbl;
  struct IRTCSessionStateChangeEvent2 {
    CONST_VTBL struct IRTCSessionStateChangeEvent2Vtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IRTCSessionStateChangeEvent2_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IRTCSessionStateChangeEvent2_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IRTCSessionStateChangeEvent2_Release(This) (This)->lpVtbl->Release(This)
#define IRTCSessionStateChangeEvent2_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IRTCSessionStateChangeEvent2_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IRTCSessionStateChangeEvent2_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IRTCSessionStateChangeEvent2_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IRTCSessionStateChangeEvent2_get_Session(This,ppSession) (This)->lpVtbl->get_Session(This,ppSession)
#define IRTCSessionStateChangeEvent2_get_State(This,penState) (This)->lpVtbl->get_State(This,penState)
#define IRTCSessionStateChangeEvent2_get_StatusCode(This,plStatusCode) (This)->lpVtbl->get_StatusCode(This,plStatusCode)
#define IRTCSessionStateChangeEvent2_get_StatusText(This,pbstrStatusText) (This)->lpVtbl->get_StatusText(This,pbstrStatusText)
#define IRTCSessionStateChangeEvent2_get_MediaTypes(This,pMediaTypes) (This)->lpVtbl->get_MediaTypes(This,pMediaTypes)
#define IRTCSessionStateChangeEvent2_get_RemotePreferredSecurityLevel(This,enSecurityType,penSecurityLevel) (This)->lpVtbl->get_RemotePreferredSecurityLevel(This,enSecurityType,penSecurityLevel)
#define IRTCSessionStateChangeEvent2_get_IsForked(This,pfIsForked) (This)->lpVtbl->get_IsForked(This,pfIsForked)
#define IRTCSessionStateChangeEvent2_GetRemoteSessionDescription(This,pbstrContentType,pbstrSessionDescription) (This)->lpVtbl->GetRemoteSessionDescription(This,pbstrContentType,pbstrSessionDescription)
#endif
#endif
  HRESULT WINAPI IRTCSessionStateChangeEvent2_get_MediaTypes_Proxy(IRTCSessionStateChangeEvent2 *This,__LONG32 *pMediaTypes);
  void __RPC_STUB IRTCSessionStateChangeEvent2_get_MediaTypes_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCSessionStateChangeEvent2_get_RemotePreferredSecurityLevel_Proxy(IRTCSessionStateChangeEvent2 *This,RTC_SECURITY_TYPE enSecurityType,RTC_SECURITY_LEVEL *penSecurityLevel);
  void __RPC_STUB IRTCSessionStateChangeEvent2_get_RemotePreferredSecurityLevel_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCSessionStateChangeEvent2_get_IsForked_Proxy(IRTCSessionStateChangeEvent2 *This,VARIANT_BOOL *pfIsForked);
  void __RPC_STUB IRTCSessionStateChangeEvent2_get_IsForked_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCSessionStateChangeEvent2_GetRemoteSessionDescription_Proxy(IRTCSessionStateChangeEvent2 *This,BSTR *pbstrContentType,BSTR *pbstrSessionDescription);
  void __RPC_STUB IRTCSessionStateChangeEvent2_GetRemoteSessionDescription_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IRTCSessionOperationCompleteEvent_INTERFACE_DEFINED__
#define __IRTCSessionOperationCompleteEvent_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IRTCSessionOperationCompleteEvent;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IRTCSessionOperationCompleteEvent : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Session(IRTCSession **ppSession) = 0;
    virtual HRESULT WINAPI get_Cookie(LONG_PTR *plCookie) = 0;
    virtual HRESULT WINAPI get_StatusCode(__LONG32 *plStatusCode) = 0;
    virtual HRESULT WINAPI get_StatusText(BSTR *pbstrStatusText) = 0;
  };
#else
  typedef struct IRTCSessionOperationCompleteEventVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IRTCSessionOperationCompleteEvent *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IRTCSessionOperationCompleteEvent *This);
      ULONG (WINAPI *Release)(IRTCSessionOperationCompleteEvent *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IRTCSessionOperationCompleteEvent *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IRTCSessionOperationCompleteEvent *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IRTCSessionOperationCompleteEvent *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IRTCSessionOperationCompleteEvent *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Session)(IRTCSessionOperationCompleteEvent *This,IRTCSession **ppSession);
      HRESULT (WINAPI *get_Cookie)(IRTCSessionOperationCompleteEvent *This,LONG_PTR *plCookie);
      HRESULT (WINAPI *get_StatusCode)(IRTCSessionOperationCompleteEvent *This,__LONG32 *plStatusCode);
      HRESULT (WINAPI *get_StatusText)(IRTCSessionOperationCompleteEvent *This,BSTR *pbstrStatusText);
    END_INTERFACE
  } IRTCSessionOperationCompleteEventVtbl;
  struct IRTCSessionOperationCompleteEvent {
    CONST_VTBL struct IRTCSessionOperationCompleteEventVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IRTCSessionOperationCompleteEvent_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IRTCSessionOperationCompleteEvent_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IRTCSessionOperationCompleteEvent_Release(This) (This)->lpVtbl->Release(This)
#define IRTCSessionOperationCompleteEvent_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IRTCSessionOperationCompleteEvent_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IRTCSessionOperationCompleteEvent_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IRTCSessionOperationCompleteEvent_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IRTCSessionOperationCompleteEvent_get_Session(This,ppSession) (This)->lpVtbl->get_Session(This,ppSession)
#define IRTCSessionOperationCompleteEvent_get_Cookie(This,plCookie) (This)->lpVtbl->get_Cookie(This,plCookie)
#define IRTCSessionOperationCompleteEvent_get_StatusCode(This,plStatusCode) (This)->lpVtbl->get_StatusCode(This,plStatusCode)
#define IRTCSessionOperationCompleteEvent_get_StatusText(This,pbstrStatusText) (This)->lpVtbl->get_StatusText(This,pbstrStatusText)
#endif
#endif
  HRESULT WINAPI IRTCSessionOperationCompleteEvent_get_Session_Proxy(IRTCSessionOperationCompleteEvent *This,IRTCSession **ppSession);
  void __RPC_STUB IRTCSessionOperationCompleteEvent_get_Session_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCSessionOperationCompleteEvent_get_Cookie_Proxy(IRTCSessionOperationCompleteEvent *This,LONG_PTR *plCookie);
  void __RPC_STUB IRTCSessionOperationCompleteEvent_get_Cookie_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCSessionOperationCompleteEvent_get_StatusCode_Proxy(IRTCSessionOperationCompleteEvent *This,__LONG32 *plStatusCode);
  void __RPC_STUB IRTCSessionOperationCompleteEvent_get_StatusCode_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCSessionOperationCompleteEvent_get_StatusText_Proxy(IRTCSessionOperationCompleteEvent *This,BSTR *pbstrStatusText);
  void __RPC_STUB IRTCSessionOperationCompleteEvent_get_StatusText_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IRTCSessionOperationCompleteEvent2_INTERFACE_DEFINED__
#define __IRTCSessionOperationCompleteEvent2_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IRTCSessionOperationCompleteEvent2;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IRTCSessionOperationCompleteEvent2 : public IRTCSessionOperationCompleteEvent {
  public:
    virtual HRESULT WINAPI get_Participant(IRTCParticipant **ppParticipant) = 0;
    virtual HRESULT WINAPI GetRemoteSessionDescription(BSTR *pbstrContentType,BSTR *pbstrSessionDescription) = 0;
  };
#else
  typedef struct IRTCSessionOperationCompleteEvent2Vtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IRTCSessionOperationCompleteEvent2 *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IRTCSessionOperationCompleteEvent2 *This);
      ULONG (WINAPI *Release)(IRTCSessionOperationCompleteEvent2 *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IRTCSessionOperationCompleteEvent2 *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IRTCSessionOperationCompleteEvent2 *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IRTCSessionOperationCompleteEvent2 *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IRTCSessionOperationCompleteEvent2 *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Session)(IRTCSessionOperationCompleteEvent2 *This,IRTCSession **ppSession);
      HRESULT (WINAPI *get_Cookie)(IRTCSessionOperationCompleteEvent2 *This,LONG_PTR *plCookie);
      HRESULT (WINAPI *get_StatusCode)(IRTCSessionOperationCompleteEvent2 *This,__LONG32 *plStatusCode);
      HRESULT (WINAPI *get_StatusText)(IRTCSessionOperationCompleteEvent2 *This,BSTR *pbstrStatusText);
      HRESULT (WINAPI *get_Participant)(IRTCSessionOperationCompleteEvent2 *This,IRTCParticipant **ppParticipant);
      HRESULT (WINAPI *GetRemoteSessionDescription)(IRTCSessionOperationCompleteEvent2 *This,BSTR *pbstrContentType,BSTR *pbstrSessionDescription);
    END_INTERFACE
  } IRTCSessionOperationCompleteEvent2Vtbl;
  struct IRTCSessionOperationCompleteEvent2 {
    CONST_VTBL struct IRTCSessionOperationCompleteEvent2Vtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IRTCSessionOperationCompleteEvent2_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IRTCSessionOperationCompleteEvent2_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IRTCSessionOperationCompleteEvent2_Release(This) (This)->lpVtbl->Release(This)
#define IRTCSessionOperationCompleteEvent2_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IRTCSessionOperationCompleteEvent2_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IRTCSessionOperationCompleteEvent2_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IRTCSessionOperationCompleteEvent2_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IRTCSessionOperationCompleteEvent2_get_Session(This,ppSession) (This)->lpVtbl->get_Session(This,ppSession)
#define IRTCSessionOperationCompleteEvent2_get_Cookie(This,plCookie) (This)->lpVtbl->get_Cookie(This,plCookie)
#define IRTCSessionOperationCompleteEvent2_get_StatusCode(This,plStatusCode) (This)->lpVtbl->get_StatusCode(This,plStatusCode)
#define IRTCSessionOperationCompleteEvent2_get_StatusText(This,pbstrStatusText) (This)->lpVtbl->get_StatusText(This,pbstrStatusText)
#define IRTCSessionOperationCompleteEvent2_get_Participant(This,ppParticipant) (This)->lpVtbl->get_Participant(This,ppParticipant)
#define IRTCSessionOperationCompleteEvent2_GetRemoteSessionDescription(This,pbstrContentType,pbstrSessionDescription) (This)->lpVtbl->GetRemoteSessionDescription(This,pbstrContentType,pbstrSessionDescription)
#endif
#endif
  HRESULT WINAPI IRTCSessionOperationCompleteEvent2_get_Participant_Proxy(IRTCSessionOperationCompleteEvent2 *This,IRTCParticipant **ppParticipant);
  void __RPC_STUB IRTCSessionOperationCompleteEvent2_get_Participant_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCSessionOperationCompleteEvent2_GetRemoteSessionDescription_Proxy(IRTCSessionOperationCompleteEvent2 *This,BSTR *pbstrContentType,BSTR *pbstrSessionDescription);
  void __RPC_STUB IRTCSessionOperationCompleteEvent2_GetRemoteSessionDescription_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IRTCParticipantStateChangeEvent_INTERFACE_DEFINED__
#define __IRTCParticipantStateChangeEvent_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IRTCParticipantStateChangeEvent;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IRTCParticipantStateChangeEvent : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Participant(IRTCParticipant **ppParticipant) = 0;
    virtual HRESULT WINAPI get_State(RTC_PARTICIPANT_STATE *penState) = 0;
    virtual HRESULT WINAPI get_StatusCode(__LONG32 *plStatusCode) = 0;
  };
#else
  typedef struct IRTCParticipantStateChangeEventVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IRTCParticipantStateChangeEvent *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IRTCParticipantStateChangeEvent *This);
      ULONG (WINAPI *Release)(IRTCParticipantStateChangeEvent *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IRTCParticipantStateChangeEvent *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IRTCParticipantStateChangeEvent *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IRTCParticipantStateChangeEvent *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IRTCParticipantStateChangeEvent *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Participant)(IRTCParticipantStateChangeEvent *This,IRTCParticipant **ppParticipant);
      HRESULT (WINAPI *get_State)(IRTCParticipantStateChangeEvent *This,RTC_PARTICIPANT_STATE *penState);
      HRESULT (WINAPI *get_StatusCode)(IRTCParticipantStateChangeEvent *This,__LONG32 *plStatusCode);
    END_INTERFACE
  } IRTCParticipantStateChangeEventVtbl;
  struct IRTCParticipantStateChangeEvent {
    CONST_VTBL struct IRTCParticipantStateChangeEventVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IRTCParticipantStateChangeEvent_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IRTCParticipantStateChangeEvent_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IRTCParticipantStateChangeEvent_Release(This) (This)->lpVtbl->Release(This)
#define IRTCParticipantStateChangeEvent_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IRTCParticipantStateChangeEvent_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IRTCParticipantStateChangeEvent_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IRTCParticipantStateChangeEvent_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IRTCParticipantStateChangeEvent_get_Participant(This,ppParticipant) (This)->lpVtbl->get_Participant(This,ppParticipant)
#define IRTCParticipantStateChangeEvent_get_State(This,penState) (This)->lpVtbl->get_State(This,penState)
#define IRTCParticipantStateChangeEvent_get_StatusCode(This,plStatusCode) (This)->lpVtbl->get_StatusCode(This,plStatusCode)
#endif
#endif
  HRESULT WINAPI IRTCParticipantStateChangeEvent_get_Participant_Proxy(IRTCParticipantStateChangeEvent *This,IRTCParticipant **ppParticipant);
  void __RPC_STUB IRTCParticipantStateChangeEvent_get_Participant_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCParticipantStateChangeEvent_get_State_Proxy(IRTCParticipantStateChangeEvent *This,RTC_PARTICIPANT_STATE *penState);
  void __RPC_STUB IRTCParticipantStateChangeEvent_get_State_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCParticipantStateChangeEvent_get_StatusCode_Proxy(IRTCParticipantStateChangeEvent *This,__LONG32 *plStatusCode);
  void __RPC_STUB IRTCParticipantStateChangeEvent_get_StatusCode_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IRTCMediaEvent_INTERFACE_DEFINED__
#define __IRTCMediaEvent_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IRTCMediaEvent;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IRTCMediaEvent : public IDispatch {
  public:
    virtual HRESULT WINAPI get_MediaType(__LONG32 *pMediaType) = 0;
    virtual HRESULT WINAPI get_EventType(RTC_MEDIA_EVENT_TYPE *penEventType) = 0;
    virtual HRESULT WINAPI get_EventReason(RTC_MEDIA_EVENT_REASON *penEventReason) = 0;
  };
#else
  typedef struct IRTCMediaEventVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IRTCMediaEvent *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IRTCMediaEvent *This);
      ULONG (WINAPI *Release)(IRTCMediaEvent *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IRTCMediaEvent *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IRTCMediaEvent *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IRTCMediaEvent *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IRTCMediaEvent *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_MediaType)(IRTCMediaEvent *This,__LONG32 *pMediaType);
      HRESULT (WINAPI *get_EventType)(IRTCMediaEvent *This,RTC_MEDIA_EVENT_TYPE *penEventType);
      HRESULT (WINAPI *get_EventReason)(IRTCMediaEvent *This,RTC_MEDIA_EVENT_REASON *penEventReason);
    END_INTERFACE
  } IRTCMediaEventVtbl;
  struct IRTCMediaEvent {
    CONST_VTBL struct IRTCMediaEventVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IRTCMediaEvent_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IRTCMediaEvent_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IRTCMediaEvent_Release(This) (This)->lpVtbl->Release(This)
#define IRTCMediaEvent_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IRTCMediaEvent_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IRTCMediaEvent_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IRTCMediaEvent_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IRTCMediaEvent_get_MediaType(This,pMediaType) (This)->lpVtbl->get_MediaType(This,pMediaType)
#define IRTCMediaEvent_get_EventType(This,penEventType) (This)->lpVtbl->get_EventType(This,penEventType)
#define IRTCMediaEvent_get_EventReason(This,penEventReason) (This)->lpVtbl->get_EventReason(This,penEventReason)
#endif
#endif
  HRESULT WINAPI IRTCMediaEvent_get_MediaType_Proxy(IRTCMediaEvent *This,__LONG32 *pMediaType);
  void __RPC_STUB IRTCMediaEvent_get_MediaType_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCMediaEvent_get_EventType_Proxy(IRTCMediaEvent *This,RTC_MEDIA_EVENT_TYPE *penEventType);
  void __RPC_STUB IRTCMediaEvent_get_EventType_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCMediaEvent_get_EventReason_Proxy(IRTCMediaEvent *This,RTC_MEDIA_EVENT_REASON *penEventReason);
  void __RPC_STUB IRTCMediaEvent_get_EventReason_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IRTCIntensityEvent_INTERFACE_DEFINED__
#define __IRTCIntensityEvent_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IRTCIntensityEvent;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IRTCIntensityEvent : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Level(__LONG32 *plLevel) = 0;
    virtual HRESULT WINAPI get_Min(__LONG32 *plMin) = 0;
    virtual HRESULT WINAPI get_Max(__LONG32 *plMax) = 0;
    virtual HRESULT WINAPI get_Direction(RTC_AUDIO_DEVICE *penDirection) = 0;
  };
#else
  typedef struct IRTCIntensityEventVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IRTCIntensityEvent *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IRTCIntensityEvent *This);
      ULONG (WINAPI *Release)(IRTCIntensityEvent *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IRTCIntensityEvent *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IRTCIntensityEvent *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IRTCIntensityEvent *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IRTCIntensityEvent *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Level)(IRTCIntensityEvent *This,__LONG32 *plLevel);
      HRESULT (WINAPI *get_Min)(IRTCIntensityEvent *This,__LONG32 *plMin);
      HRESULT (WINAPI *get_Max)(IRTCIntensityEvent *This,__LONG32 *plMax);
      HRESULT (WINAPI *get_Direction)(IRTCIntensityEvent *This,RTC_AUDIO_DEVICE *penDirection);
    END_INTERFACE
  } IRTCIntensityEventVtbl;
  struct IRTCIntensityEvent {
    CONST_VTBL struct IRTCIntensityEventVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IRTCIntensityEvent_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IRTCIntensityEvent_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IRTCIntensityEvent_Release(This) (This)->lpVtbl->Release(This)
#define IRTCIntensityEvent_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IRTCIntensityEvent_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IRTCIntensityEvent_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IRTCIntensityEvent_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IRTCIntensityEvent_get_Level(This,plLevel) (This)->lpVtbl->get_Level(This,plLevel)
#define IRTCIntensityEvent_get_Min(This,plMin) (This)->lpVtbl->get_Min(This,plMin)
#define IRTCIntensityEvent_get_Max(This,plMax) (This)->lpVtbl->get_Max(This,plMax)
#define IRTCIntensityEvent_get_Direction(This,penDirection) (This)->lpVtbl->get_Direction(This,penDirection)
#endif
#endif
  HRESULT WINAPI IRTCIntensityEvent_get_Level_Proxy(IRTCIntensityEvent *This,__LONG32 *plLevel);
  void __RPC_STUB IRTCIntensityEvent_get_Level_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCIntensityEvent_get_Min_Proxy(IRTCIntensityEvent *This,__LONG32 *plMin);
  void __RPC_STUB IRTCIntensityEvent_get_Min_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCIntensityEvent_get_Max_Proxy(IRTCIntensityEvent *This,__LONG32 *plMax);
  void __RPC_STUB IRTCIntensityEvent_get_Max_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCIntensityEvent_get_Direction_Proxy(IRTCIntensityEvent *This,RTC_AUDIO_DEVICE *penDirection);
  void __RPC_STUB IRTCIntensityEvent_get_Direction_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IRTCMessagingEvent_INTERFACE_DEFINED__
#define __IRTCMessagingEvent_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IRTCMessagingEvent;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IRTCMessagingEvent : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Session(IRTCSession **ppSession) = 0;
    virtual HRESULT WINAPI get_Participant(IRTCParticipant **ppParticipant) = 0;
    virtual HRESULT WINAPI get_EventType(RTC_MESSAGING_EVENT_TYPE *penEventType) = 0;
    virtual HRESULT WINAPI get_Message(BSTR *pbstrMessage) = 0;
    virtual HRESULT WINAPI get_MessageHeader(BSTR *pbstrMessageHeader) = 0;
    virtual HRESULT WINAPI get_UserStatus(RTC_MESSAGING_USER_STATUS *penUserStatus) = 0;
  };
#else
  typedef struct IRTCMessagingEventVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IRTCMessagingEvent *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IRTCMessagingEvent *This);
      ULONG (WINAPI *Release)(IRTCMessagingEvent *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IRTCMessagingEvent *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IRTCMessagingEvent *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IRTCMessagingEvent *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IRTCMessagingEvent *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Session)(IRTCMessagingEvent *This,IRTCSession **ppSession);
      HRESULT (WINAPI *get_Participant)(IRTCMessagingEvent *This,IRTCParticipant **ppParticipant);
      HRESULT (WINAPI *get_EventType)(IRTCMessagingEvent *This,RTC_MESSAGING_EVENT_TYPE *penEventType);
      HRESULT (WINAPI *get_Message)(IRTCMessagingEvent *This,BSTR *pbstrMessage);
      HRESULT (WINAPI *get_MessageHeader)(IRTCMessagingEvent *This,BSTR *pbstrMessageHeader);
      HRESULT (WINAPI *get_UserStatus)(IRTCMessagingEvent *This,RTC_MESSAGING_USER_STATUS *penUserStatus);
    END_INTERFACE
  } IRTCMessagingEventVtbl;
  struct IRTCMessagingEvent {
    CONST_VTBL struct IRTCMessagingEventVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IRTCMessagingEvent_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IRTCMessagingEvent_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IRTCMessagingEvent_Release(This) (This)->lpVtbl->Release(This)
#define IRTCMessagingEvent_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IRTCMessagingEvent_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IRTCMessagingEvent_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IRTCMessagingEvent_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IRTCMessagingEvent_get_Session(This,ppSession) (This)->lpVtbl->get_Session(This,ppSession)
#define IRTCMessagingEvent_get_Participant(This,ppParticipant) (This)->lpVtbl->get_Participant(This,ppParticipant)
#define IRTCMessagingEvent_get_EventType(This,penEventType) (This)->lpVtbl->get_EventType(This,penEventType)
#define IRTCMessagingEvent_get_Message(This,pbstrMessage) (This)->lpVtbl->get_Message(This,pbstrMessage)
#define IRTCMessagingEvent_get_MessageHeader(This,pbstrMessageHeader) (This)->lpVtbl->get_MessageHeader(This,pbstrMessageHeader)
#define IRTCMessagingEvent_get_UserStatus(This,penUserStatus) (This)->lpVtbl->get_UserStatus(This,penUserStatus)
#endif
#endif
  HRESULT WINAPI IRTCMessagingEvent_get_Session_Proxy(IRTCMessagingEvent *This,IRTCSession **ppSession);
  void __RPC_STUB IRTCMessagingEvent_get_Session_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCMessagingEvent_get_Participant_Proxy(IRTCMessagingEvent *This,IRTCParticipant **ppParticipant);
  void __RPC_STUB IRTCMessagingEvent_get_Participant_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCMessagingEvent_get_EventType_Proxy(IRTCMessagingEvent *This,RTC_MESSAGING_EVENT_TYPE *penEventType);
  void __RPC_STUB IRTCMessagingEvent_get_EventType_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCMessagingEvent_get_Message_Proxy(IRTCMessagingEvent *This,BSTR *pbstrMessage);
  void __RPC_STUB IRTCMessagingEvent_get_Message_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCMessagingEvent_get_MessageHeader_Proxy(IRTCMessagingEvent *This,BSTR *pbstrMessageHeader);
  void __RPC_STUB IRTCMessagingEvent_get_MessageHeader_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCMessagingEvent_get_UserStatus_Proxy(IRTCMessagingEvent *This,RTC_MESSAGING_USER_STATUS *penUserStatus);
  void __RPC_STUB IRTCMessagingEvent_get_UserStatus_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IRTCBuddyEvent_INTERFACE_DEFINED__
#define __IRTCBuddyEvent_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IRTCBuddyEvent;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IRTCBuddyEvent : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Buddy(IRTCBuddy **ppBuddy) = 0;
  };
#else
  typedef struct IRTCBuddyEventVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IRTCBuddyEvent *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IRTCBuddyEvent *This);
      ULONG (WINAPI *Release)(IRTCBuddyEvent *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IRTCBuddyEvent *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IRTCBuddyEvent *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IRTCBuddyEvent *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IRTCBuddyEvent *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Buddy)(IRTCBuddyEvent *This,IRTCBuddy **ppBuddy);
    END_INTERFACE
  } IRTCBuddyEventVtbl;
  struct IRTCBuddyEvent {
    CONST_VTBL struct IRTCBuddyEventVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IRTCBuddyEvent_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IRTCBuddyEvent_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IRTCBuddyEvent_Release(This) (This)->lpVtbl->Release(This)
#define IRTCBuddyEvent_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IRTCBuddyEvent_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IRTCBuddyEvent_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IRTCBuddyEvent_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IRTCBuddyEvent_get_Buddy(This,ppBuddy) (This)->lpVtbl->get_Buddy(This,ppBuddy)
#endif
#endif
  HRESULT WINAPI IRTCBuddyEvent_get_Buddy_Proxy(IRTCBuddyEvent *This,IRTCBuddy **ppBuddy);
  void __RPC_STUB IRTCBuddyEvent_get_Buddy_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IRTCBuddyEvent2_INTERFACE_DEFINED__
#define __IRTCBuddyEvent2_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IRTCBuddyEvent2;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IRTCBuddyEvent2 : public IRTCBuddyEvent {
  public:
    virtual HRESULT WINAPI get_EventType(RTC_BUDDY_EVENT_TYPE *pEventType) = 0;
    virtual HRESULT WINAPI get_StatusCode(__LONG32 *plStatusCode) = 0;
    virtual HRESULT WINAPI get_StatusText(BSTR *pbstrStatusText) = 0;
  };
#else
  typedef struct IRTCBuddyEvent2Vtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IRTCBuddyEvent2 *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IRTCBuddyEvent2 *This);
      ULONG (WINAPI *Release)(IRTCBuddyEvent2 *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IRTCBuddyEvent2 *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IRTCBuddyEvent2 *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IRTCBuddyEvent2 *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IRTCBuddyEvent2 *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Buddy)(IRTCBuddyEvent2 *This,IRTCBuddy **ppBuddy);
      HRESULT (WINAPI *get_EventType)(IRTCBuddyEvent2 *This,RTC_BUDDY_EVENT_TYPE *pEventType);
      HRESULT (WINAPI *get_StatusCode)(IRTCBuddyEvent2 *This,__LONG32 *plStatusCode);
      HRESULT (WINAPI *get_StatusText)(IRTCBuddyEvent2 *This,BSTR *pbstrStatusText);
    END_INTERFACE
  } IRTCBuddyEvent2Vtbl;
  struct IRTCBuddyEvent2 {
    CONST_VTBL struct IRTCBuddyEvent2Vtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IRTCBuddyEvent2_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IRTCBuddyEvent2_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IRTCBuddyEvent2_Release(This) (This)->lpVtbl->Release(This)
#define IRTCBuddyEvent2_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IRTCBuddyEvent2_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IRTCBuddyEvent2_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IRTCBuddyEvent2_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IRTCBuddyEvent2_get_Buddy(This,ppBuddy) (This)->lpVtbl->get_Buddy(This,ppBuddy)
#define IRTCBuddyEvent2_get_EventType(This,pEventType) (This)->lpVtbl->get_EventType(This,pEventType)
#define IRTCBuddyEvent2_get_StatusCode(This,plStatusCode) (This)->lpVtbl->get_StatusCode(This,plStatusCode)
#define IRTCBuddyEvent2_get_StatusText(This,pbstrStatusText) (This)->lpVtbl->get_StatusText(This,pbstrStatusText)
#endif
#endif
  HRESULT WINAPI IRTCBuddyEvent2_get_EventType_Proxy(IRTCBuddyEvent2 *This,RTC_BUDDY_EVENT_TYPE *pEventType);
  void __RPC_STUB IRTCBuddyEvent2_get_EventType_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCBuddyEvent2_get_StatusCode_Proxy(IRTCBuddyEvent2 *This,__LONG32 *plStatusCode);
  void __RPC_STUB IRTCBuddyEvent2_get_StatusCode_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCBuddyEvent2_get_StatusText_Proxy(IRTCBuddyEvent2 *This,BSTR *pbstrStatusText);
  void __RPC_STUB IRTCBuddyEvent2_get_StatusText_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IRTCWatcherEvent_INTERFACE_DEFINED__
#define __IRTCWatcherEvent_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IRTCWatcherEvent;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IRTCWatcherEvent : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Watcher(IRTCWatcher **ppWatcher) = 0;
  };
#else
  typedef struct IRTCWatcherEventVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IRTCWatcherEvent *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IRTCWatcherEvent *This);
      ULONG (WINAPI *Release)(IRTCWatcherEvent *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IRTCWatcherEvent *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IRTCWatcherEvent *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IRTCWatcherEvent *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IRTCWatcherEvent *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Watcher)(IRTCWatcherEvent *This,IRTCWatcher **ppWatcher);
    END_INTERFACE
  } IRTCWatcherEventVtbl;
  struct IRTCWatcherEvent {
    CONST_VTBL struct IRTCWatcherEventVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IRTCWatcherEvent_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IRTCWatcherEvent_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IRTCWatcherEvent_Release(This) (This)->lpVtbl->Release(This)
#define IRTCWatcherEvent_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IRTCWatcherEvent_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IRTCWatcherEvent_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IRTCWatcherEvent_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IRTCWatcherEvent_get_Watcher(This,ppWatcher) (This)->lpVtbl->get_Watcher(This,ppWatcher)
#endif
#endif
  HRESULT WINAPI IRTCWatcherEvent_get_Watcher_Proxy(IRTCWatcherEvent *This,IRTCWatcher **ppWatcher);
  void __RPC_STUB IRTCWatcherEvent_get_Watcher_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IRTCWatcherEvent2_INTERFACE_DEFINED__
#define __IRTCWatcherEvent2_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IRTCWatcherEvent2;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IRTCWatcherEvent2 : public IRTCWatcherEvent {
  public:
    virtual HRESULT WINAPI get_EventType(RTC_WATCHER_EVENT_TYPE *pEventType) = 0;
    virtual HRESULT WINAPI get_StatusCode(__LONG32 *plStatusCode) = 0;
  };
#else
  typedef struct IRTCWatcherEvent2Vtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IRTCWatcherEvent2 *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IRTCWatcherEvent2 *This);
      ULONG (WINAPI *Release)(IRTCWatcherEvent2 *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IRTCWatcherEvent2 *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IRTCWatcherEvent2 *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IRTCWatcherEvent2 *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IRTCWatcherEvent2 *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Watcher)(IRTCWatcherEvent2 *This,IRTCWatcher **ppWatcher);
      HRESULT (WINAPI *get_EventType)(IRTCWatcherEvent2 *This,RTC_WATCHER_EVENT_TYPE *pEventType);
      HRESULT (WINAPI *get_StatusCode)(IRTCWatcherEvent2 *This,__LONG32 *plStatusCode);
    END_INTERFACE
  } IRTCWatcherEvent2Vtbl;
  struct IRTCWatcherEvent2 {
    CONST_VTBL struct IRTCWatcherEvent2Vtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IRTCWatcherEvent2_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IRTCWatcherEvent2_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IRTCWatcherEvent2_Release(This) (This)->lpVtbl->Release(This)
#define IRTCWatcherEvent2_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IRTCWatcherEvent2_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IRTCWatcherEvent2_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IRTCWatcherEvent2_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IRTCWatcherEvent2_get_Watcher(This,ppWatcher) (This)->lpVtbl->get_Watcher(This,ppWatcher)
#define IRTCWatcherEvent2_get_EventType(This,pEventType) (This)->lpVtbl->get_EventType(This,pEventType)
#define IRTCWatcherEvent2_get_StatusCode(This,plStatusCode) (This)->lpVtbl->get_StatusCode(This,plStatusCode)
#endif
#endif
  HRESULT WINAPI IRTCWatcherEvent2_get_EventType_Proxy(IRTCWatcherEvent2 *This,RTC_WATCHER_EVENT_TYPE *pEventType);
  void __RPC_STUB IRTCWatcherEvent2_get_EventType_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCWatcherEvent2_get_StatusCode_Proxy(IRTCWatcherEvent2 *This,__LONG32 *plStatusCode);
  void __RPC_STUB IRTCWatcherEvent2_get_StatusCode_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IRTCBuddyGroupEvent_INTERFACE_DEFINED__
#define __IRTCBuddyGroupEvent_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IRTCBuddyGroupEvent;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IRTCBuddyGroupEvent : public IDispatch {
  public:
    virtual HRESULT WINAPI get_EventType(RTC_GROUP_EVENT_TYPE *pEventType) = 0;
    virtual HRESULT WINAPI get_Group(IRTCBuddyGroup **ppGroup) = 0;
    virtual HRESULT WINAPI get_Buddy(IRTCBuddy2 **ppBuddy) = 0;
    virtual HRESULT WINAPI get_StatusCode(__LONG32 *plStatusCode) = 0;
  };
#else
  typedef struct IRTCBuddyGroupEventVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IRTCBuddyGroupEvent *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IRTCBuddyGroupEvent *This);
      ULONG (WINAPI *Release)(IRTCBuddyGroupEvent *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IRTCBuddyGroupEvent *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IRTCBuddyGroupEvent *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IRTCBuddyGroupEvent *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IRTCBuddyGroupEvent *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_EventType)(IRTCBuddyGroupEvent *This,RTC_GROUP_EVENT_TYPE *pEventType);
      HRESULT (WINAPI *get_Group)(IRTCBuddyGroupEvent *This,IRTCBuddyGroup **ppGroup);
      HRESULT (WINAPI *get_Buddy)(IRTCBuddyGroupEvent *This,IRTCBuddy2 **ppBuddy);
      HRESULT (WINAPI *get_StatusCode)(IRTCBuddyGroupEvent *This,__LONG32 *plStatusCode);
    END_INTERFACE
  } IRTCBuddyGroupEventVtbl;
  struct IRTCBuddyGroupEvent {
    CONST_VTBL struct IRTCBuddyGroupEventVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IRTCBuddyGroupEvent_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IRTCBuddyGroupEvent_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IRTCBuddyGroupEvent_Release(This) (This)->lpVtbl->Release(This)
#define IRTCBuddyGroupEvent_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IRTCBuddyGroupEvent_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IRTCBuddyGroupEvent_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IRTCBuddyGroupEvent_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IRTCBuddyGroupEvent_get_EventType(This,pEventType) (This)->lpVtbl->get_EventType(This,pEventType)
#define IRTCBuddyGroupEvent_get_Group(This,ppGroup) (This)->lpVtbl->get_Group(This,ppGroup)
#define IRTCBuddyGroupEvent_get_Buddy(This,ppBuddy) (This)->lpVtbl->get_Buddy(This,ppBuddy)
#define IRTCBuddyGroupEvent_get_StatusCode(This,plStatusCode) (This)->lpVtbl->get_StatusCode(This,plStatusCode)
#endif
#endif
  HRESULT WINAPI IRTCBuddyGroupEvent_get_EventType_Proxy(IRTCBuddyGroupEvent *This,RTC_GROUP_EVENT_TYPE *pEventType);
  void __RPC_STUB IRTCBuddyGroupEvent_get_EventType_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCBuddyGroupEvent_get_Group_Proxy(IRTCBuddyGroupEvent *This,IRTCBuddyGroup **ppGroup);
  void __RPC_STUB IRTCBuddyGroupEvent_get_Group_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCBuddyGroupEvent_get_Buddy_Proxy(IRTCBuddyGroupEvent *This,IRTCBuddy2 **ppBuddy);
  void __RPC_STUB IRTCBuddyGroupEvent_get_Buddy_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCBuddyGroupEvent_get_StatusCode_Proxy(IRTCBuddyGroupEvent *This,__LONG32 *plStatusCode);
  void __RPC_STUB IRTCBuddyGroupEvent_get_StatusCode_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IRTCInfoEvent_INTERFACE_DEFINED__
#define __IRTCInfoEvent_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IRTCInfoEvent;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IRTCInfoEvent : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Session(IRTCSession2 **ppSession) = 0;
    virtual HRESULT WINAPI get_Participant(IRTCParticipant **ppParticipant) = 0;
    virtual HRESULT WINAPI get_Info(BSTR *pbstrInfo) = 0;
    virtual HRESULT WINAPI get_InfoHeader(BSTR *pbstrInfoHeader) = 0;
  };
#else
  typedef struct IRTCInfoEventVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IRTCInfoEvent *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IRTCInfoEvent *This);
      ULONG (WINAPI *Release)(IRTCInfoEvent *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IRTCInfoEvent *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IRTCInfoEvent *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IRTCInfoEvent *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IRTCInfoEvent *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Session)(IRTCInfoEvent *This,IRTCSession2 **ppSession);
      HRESULT (WINAPI *get_Participant)(IRTCInfoEvent *This,IRTCParticipant **ppParticipant);
      HRESULT (WINAPI *get_Info)(IRTCInfoEvent *This,BSTR *pbstrInfo);
      HRESULT (WINAPI *get_InfoHeader)(IRTCInfoEvent *This,BSTR *pbstrInfoHeader);
    END_INTERFACE
  } IRTCInfoEventVtbl;
  struct IRTCInfoEvent {
    CONST_VTBL struct IRTCInfoEventVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IRTCInfoEvent_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IRTCInfoEvent_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IRTCInfoEvent_Release(This) (This)->lpVtbl->Release(This)
#define IRTCInfoEvent_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IRTCInfoEvent_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IRTCInfoEvent_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IRTCInfoEvent_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IRTCInfoEvent_get_Session(This,ppSession) (This)->lpVtbl->get_Session(This,ppSession)
#define IRTCInfoEvent_get_Participant(This,ppParticipant) (This)->lpVtbl->get_Participant(This,ppParticipant)
#define IRTCInfoEvent_get_Info(This,pbstrInfo) (This)->lpVtbl->get_Info(This,pbstrInfo)
#define IRTCInfoEvent_get_InfoHeader(This,pbstrInfoHeader) (This)->lpVtbl->get_InfoHeader(This,pbstrInfoHeader)
#endif
#endif
  HRESULT WINAPI IRTCInfoEvent_get_Session_Proxy(IRTCInfoEvent *This,IRTCSession2 **ppSession);
  void __RPC_STUB IRTCInfoEvent_get_Session_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCInfoEvent_get_Participant_Proxy(IRTCInfoEvent *This,IRTCParticipant **ppParticipant);
  void __RPC_STUB IRTCInfoEvent_get_Participant_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCInfoEvent_get_Info_Proxy(IRTCInfoEvent *This,BSTR *pbstrInfo);
  void __RPC_STUB IRTCInfoEvent_get_Info_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCInfoEvent_get_InfoHeader_Proxy(IRTCInfoEvent *This,BSTR *pbstrInfoHeader);
  void __RPC_STUB IRTCInfoEvent_get_InfoHeader_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IRTCMediaRequestEvent_INTERFACE_DEFINED__
#define __IRTCMediaRequestEvent_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IRTCMediaRequestEvent;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IRTCMediaRequestEvent : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Session(IRTCSession2 **ppSession) = 0;
    virtual HRESULT WINAPI get_ProposedMedia(__LONG32 *plMediaTypes) = 0;
    virtual HRESULT WINAPI get_CurrentMedia(__LONG32 *plMediaTypes) = 0;
    virtual HRESULT WINAPI Accept(__LONG32 lMediaTypes) = 0;
    virtual HRESULT WINAPI get_RemotePreferredSecurityLevel(RTC_SECURITY_TYPE enSecurityType,RTC_SECURITY_LEVEL *penSecurityLevel) = 0;
    virtual HRESULT WINAPI Reject(void) = 0;
    virtual HRESULT WINAPI get_State(RTC_REINVITE_STATE *pState) = 0;
  };
#else
  typedef struct IRTCMediaRequestEventVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IRTCMediaRequestEvent *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IRTCMediaRequestEvent *This);
      ULONG (WINAPI *Release)(IRTCMediaRequestEvent *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IRTCMediaRequestEvent *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IRTCMediaRequestEvent *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IRTCMediaRequestEvent *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IRTCMediaRequestEvent *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Session)(IRTCMediaRequestEvent *This,IRTCSession2 **ppSession);
      HRESULT (WINAPI *get_ProposedMedia)(IRTCMediaRequestEvent *This,__LONG32 *plMediaTypes);
      HRESULT (WINAPI *get_CurrentMedia)(IRTCMediaRequestEvent *This,__LONG32 *plMediaTypes);
      HRESULT (WINAPI *Accept)(IRTCMediaRequestEvent *This,__LONG32 lMediaTypes);
      HRESULT (WINAPI *get_RemotePreferredSecurityLevel)(IRTCMediaRequestEvent *This,RTC_SECURITY_TYPE enSecurityType,RTC_SECURITY_LEVEL *penSecurityLevel);
      HRESULT (WINAPI *Reject)(IRTCMediaRequestEvent *This);
      HRESULT (WINAPI *get_State)(IRTCMediaRequestEvent *This,RTC_REINVITE_STATE *pState);
    END_INTERFACE
  } IRTCMediaRequestEventVtbl;
  struct IRTCMediaRequestEvent {
    CONST_VTBL struct IRTCMediaRequestEventVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IRTCMediaRequestEvent_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IRTCMediaRequestEvent_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IRTCMediaRequestEvent_Release(This) (This)->lpVtbl->Release(This)
#define IRTCMediaRequestEvent_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IRTCMediaRequestEvent_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IRTCMediaRequestEvent_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IRTCMediaRequestEvent_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IRTCMediaRequestEvent_get_Session(This,ppSession) (This)->lpVtbl->get_Session(This,ppSession)
#define IRTCMediaRequestEvent_get_ProposedMedia(This,plMediaTypes) (This)->lpVtbl->get_ProposedMedia(This,plMediaTypes)
#define IRTCMediaRequestEvent_get_CurrentMedia(This,plMediaTypes) (This)->lpVtbl->get_CurrentMedia(This,plMediaTypes)
#define IRTCMediaRequestEvent_Accept(This,lMediaTypes) (This)->lpVtbl->Accept(This,lMediaTypes)
#define IRTCMediaRequestEvent_get_RemotePreferredSecurityLevel(This,enSecurityType,penSecurityLevel) (This)->lpVtbl->get_RemotePreferredSecurityLevel(This,enSecurityType,penSecurityLevel)
#define IRTCMediaRequestEvent_Reject(This) (This)->lpVtbl->Reject(This)
#define IRTCMediaRequestEvent_get_State(This,pState) (This)->lpVtbl->get_State(This,pState)
#endif
#endif
  HRESULT WINAPI IRTCMediaRequestEvent_get_Session_Proxy(IRTCMediaRequestEvent *This,IRTCSession2 **ppSession);
  void __RPC_STUB IRTCMediaRequestEvent_get_Session_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCMediaRequestEvent_get_ProposedMedia_Proxy(IRTCMediaRequestEvent *This,__LONG32 *plMediaTypes);
  void __RPC_STUB IRTCMediaRequestEvent_get_ProposedMedia_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCMediaRequestEvent_get_CurrentMedia_Proxy(IRTCMediaRequestEvent *This,__LONG32 *plMediaTypes);
  void __RPC_STUB IRTCMediaRequestEvent_get_CurrentMedia_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCMediaRequestEvent_Accept_Proxy(IRTCMediaRequestEvent *This,__LONG32 lMediaTypes);
  void __RPC_STUB IRTCMediaRequestEvent_Accept_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCMediaRequestEvent_get_RemotePreferredSecurityLevel_Proxy(IRTCMediaRequestEvent *This,RTC_SECURITY_TYPE enSecurityType,RTC_SECURITY_LEVEL *penSecurityLevel);
  void __RPC_STUB IRTCMediaRequestEvent_get_RemotePreferredSecurityLevel_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCMediaRequestEvent_Reject_Proxy(IRTCMediaRequestEvent *This);
  void __RPC_STUB IRTCMediaRequestEvent_Reject_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCMediaRequestEvent_get_State_Proxy(IRTCMediaRequestEvent *This,RTC_REINVITE_STATE *pState);
  void __RPC_STUB IRTCMediaRequestEvent_get_State_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IRTCReInviteEvent_INTERFACE_DEFINED__
#define __IRTCReInviteEvent_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IRTCReInviteEvent;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IRTCReInviteEvent : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Session(IRTCSession2 **ppSession2) = 0;
    virtual HRESULT WINAPI Accept(BSTR bstrContentType,BSTR bstrSessionDescription) = 0;
    virtual HRESULT WINAPI Reject(void) = 0;
    virtual HRESULT WINAPI get_State(RTC_REINVITE_STATE *pState) = 0;
    virtual HRESULT WINAPI GetRemoteSessionDescription(BSTR *pbstrContentType,BSTR *pbstrSessionDescription) = 0;
  };
#else
  typedef struct IRTCReInviteEventVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IRTCReInviteEvent *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IRTCReInviteEvent *This);
      ULONG (WINAPI *Release)(IRTCReInviteEvent *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IRTCReInviteEvent *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IRTCReInviteEvent *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IRTCReInviteEvent *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IRTCReInviteEvent *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Session)(IRTCReInviteEvent *This,IRTCSession2 **ppSession2);
      HRESULT (WINAPI *Accept)(IRTCReInviteEvent *This,BSTR bstrContentType,BSTR bstrSessionDescription);
      HRESULT (WINAPI *Reject)(IRTCReInviteEvent *This);
      HRESULT (WINAPI *get_State)(IRTCReInviteEvent *This,RTC_REINVITE_STATE *pState);
      HRESULT (WINAPI *GetRemoteSessionDescription)(IRTCReInviteEvent *This,BSTR *pbstrContentType,BSTR *pbstrSessionDescription);
    END_INTERFACE
  } IRTCReInviteEventVtbl;
  struct IRTCReInviteEvent {
    CONST_VTBL struct IRTCReInviteEventVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IRTCReInviteEvent_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IRTCReInviteEvent_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IRTCReInviteEvent_Release(This) (This)->lpVtbl->Release(This)
#define IRTCReInviteEvent_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IRTCReInviteEvent_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IRTCReInviteEvent_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IRTCReInviteEvent_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IRTCReInviteEvent_get_Session(This,ppSession2) (This)->lpVtbl->get_Session(This,ppSession2)
#define IRTCReInviteEvent_Accept(This,bstrContentType,bstrSessionDescription) (This)->lpVtbl->Accept(This,bstrContentType,bstrSessionDescription)
#define IRTCReInviteEvent_Reject(This) (This)->lpVtbl->Reject(This)
#define IRTCReInviteEvent_get_State(This,pState) (This)->lpVtbl->get_State(This,pState)
#define IRTCReInviteEvent_GetRemoteSessionDescription(This,pbstrContentType,pbstrSessionDescription) (This)->lpVtbl->GetRemoteSessionDescription(This,pbstrContentType,pbstrSessionDescription)
#endif
#endif
  HRESULT WINAPI IRTCReInviteEvent_get_Session_Proxy(IRTCReInviteEvent *This,IRTCSession2 **ppSession2);
  void __RPC_STUB IRTCReInviteEvent_get_Session_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCReInviteEvent_Accept_Proxy(IRTCReInviteEvent *This,BSTR bstrContentType,BSTR bstrSessionDescription);
  void __RPC_STUB IRTCReInviteEvent_Accept_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCReInviteEvent_Reject_Proxy(IRTCReInviteEvent *This);
  void __RPC_STUB IRTCReInviteEvent_Reject_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCReInviteEvent_get_State_Proxy(IRTCReInviteEvent *This,RTC_REINVITE_STATE *pState);
  void __RPC_STUB IRTCReInviteEvent_get_State_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCReInviteEvent_GetRemoteSessionDescription_Proxy(IRTCReInviteEvent *This,BSTR *pbstrContentType,BSTR *pbstrSessionDescription);
  void __RPC_STUB IRTCReInviteEvent_GetRemoteSessionDescription_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IRTCPresencePropertyEvent_INTERFACE_DEFINED__
#define __IRTCPresencePropertyEvent_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IRTCPresencePropertyEvent;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IRTCPresencePropertyEvent : public IDispatch {
  public:
    virtual HRESULT WINAPI get_StatusCode(__LONG32 *plStatusCode) = 0;
    virtual HRESULT WINAPI get_StatusText(BSTR *pbstrStatusText) = 0;
    virtual HRESULT WINAPI get_PresenceProperty(RTC_PRESENCE_PROPERTY *penPresProp) = 0;
    virtual HRESULT WINAPI get_Value(BSTR *pbstrValue) = 0;
  };
#else
  typedef struct IRTCPresencePropertyEventVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IRTCPresencePropertyEvent *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IRTCPresencePropertyEvent *This);
      ULONG (WINAPI *Release)(IRTCPresencePropertyEvent *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IRTCPresencePropertyEvent *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IRTCPresencePropertyEvent *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IRTCPresencePropertyEvent *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IRTCPresencePropertyEvent *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_StatusCode)(IRTCPresencePropertyEvent *This,__LONG32 *plStatusCode);
      HRESULT (WINAPI *get_StatusText)(IRTCPresencePropertyEvent *This,BSTR *pbstrStatusText);
      HRESULT (WINAPI *get_PresenceProperty)(IRTCPresencePropertyEvent *This,RTC_PRESENCE_PROPERTY *penPresProp);
      HRESULT (WINAPI *get_Value)(IRTCPresencePropertyEvent *This,BSTR *pbstrValue);
    END_INTERFACE
  } IRTCPresencePropertyEventVtbl;
  struct IRTCPresencePropertyEvent {
    CONST_VTBL struct IRTCPresencePropertyEventVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IRTCPresencePropertyEvent_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IRTCPresencePropertyEvent_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IRTCPresencePropertyEvent_Release(This) (This)->lpVtbl->Release(This)
#define IRTCPresencePropertyEvent_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IRTCPresencePropertyEvent_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IRTCPresencePropertyEvent_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IRTCPresencePropertyEvent_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IRTCPresencePropertyEvent_get_StatusCode(This,plStatusCode) (This)->lpVtbl->get_StatusCode(This,plStatusCode)
#define IRTCPresencePropertyEvent_get_StatusText(This,pbstrStatusText) (This)->lpVtbl->get_StatusText(This,pbstrStatusText)
#define IRTCPresencePropertyEvent_get_PresenceProperty(This,penPresProp) (This)->lpVtbl->get_PresenceProperty(This,penPresProp)
#define IRTCPresencePropertyEvent_get_Value(This,pbstrValue) (This)->lpVtbl->get_Value(This,pbstrValue)
#endif
#endif
  HRESULT WINAPI IRTCPresencePropertyEvent_get_StatusCode_Proxy(IRTCPresencePropertyEvent *This,__LONG32 *plStatusCode);
  void __RPC_STUB IRTCPresencePropertyEvent_get_StatusCode_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCPresencePropertyEvent_get_StatusText_Proxy(IRTCPresencePropertyEvent *This,BSTR *pbstrStatusText);
  void __RPC_STUB IRTCPresencePropertyEvent_get_StatusText_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCPresencePropertyEvent_get_PresenceProperty_Proxy(IRTCPresencePropertyEvent *This,RTC_PRESENCE_PROPERTY *penPresProp);
  void __RPC_STUB IRTCPresencePropertyEvent_get_PresenceProperty_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCPresencePropertyEvent_get_Value_Proxy(IRTCPresencePropertyEvent *This,BSTR *pbstrValue);
  void __RPC_STUB IRTCPresencePropertyEvent_get_Value_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IRTCPresenceDataEvent_INTERFACE_DEFINED__
#define __IRTCPresenceDataEvent_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IRTCPresenceDataEvent;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IRTCPresenceDataEvent : public IDispatch {
  public:
    virtual HRESULT WINAPI get_StatusCode(__LONG32 *plStatusCode) = 0;
    virtual HRESULT WINAPI get_StatusText(BSTR *pbstrStatusText) = 0;
    virtual HRESULT WINAPI GetPresenceData(BSTR *pbstrNamespace,BSTR *pbstrData) = 0;
  };
#else
  typedef struct IRTCPresenceDataEventVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IRTCPresenceDataEvent *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IRTCPresenceDataEvent *This);
      ULONG (WINAPI *Release)(IRTCPresenceDataEvent *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IRTCPresenceDataEvent *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IRTCPresenceDataEvent *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IRTCPresenceDataEvent *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IRTCPresenceDataEvent *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_StatusCode)(IRTCPresenceDataEvent *This,__LONG32 *plStatusCode);
      HRESULT (WINAPI *get_StatusText)(IRTCPresenceDataEvent *This,BSTR *pbstrStatusText);
      HRESULT (WINAPI *GetPresenceData)(IRTCPresenceDataEvent *This,BSTR *pbstrNamespace,BSTR *pbstrData);
    END_INTERFACE
  } IRTCPresenceDataEventVtbl;
  struct IRTCPresenceDataEvent {
    CONST_VTBL struct IRTCPresenceDataEventVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IRTCPresenceDataEvent_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IRTCPresenceDataEvent_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IRTCPresenceDataEvent_Release(This) (This)->lpVtbl->Release(This)
#define IRTCPresenceDataEvent_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IRTCPresenceDataEvent_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IRTCPresenceDataEvent_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IRTCPresenceDataEvent_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IRTCPresenceDataEvent_get_StatusCode(This,plStatusCode) (This)->lpVtbl->get_StatusCode(This,plStatusCode)
#define IRTCPresenceDataEvent_get_StatusText(This,pbstrStatusText) (This)->lpVtbl->get_StatusText(This,pbstrStatusText)
#define IRTCPresenceDataEvent_GetPresenceData(This,pbstrNamespace,pbstrData) (This)->lpVtbl->GetPresenceData(This,pbstrNamespace,pbstrData)
#endif
#endif
  HRESULT WINAPI IRTCPresenceDataEvent_get_StatusCode_Proxy(IRTCPresenceDataEvent *This,__LONG32 *plStatusCode);
  void __RPC_STUB IRTCPresenceDataEvent_get_StatusCode_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCPresenceDataEvent_get_StatusText_Proxy(IRTCPresenceDataEvent *This,BSTR *pbstrStatusText);
  void __RPC_STUB IRTCPresenceDataEvent_get_StatusText_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCPresenceDataEvent_GetPresenceData_Proxy(IRTCPresenceDataEvent *This,BSTR *pbstrNamespace,BSTR *pbstrData);
  void __RPC_STUB IRTCPresenceDataEvent_GetPresenceData_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IRTCPresenceStatusEvent_INTERFACE_DEFINED__
#define __IRTCPresenceStatusEvent_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IRTCPresenceStatusEvent;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IRTCPresenceStatusEvent : public IDispatch {
  public:
    virtual HRESULT WINAPI get_StatusCode(__LONG32 *plStatusCode) = 0;
    virtual HRESULT WINAPI get_StatusText(BSTR *pbstrStatusText) = 0;
    virtual HRESULT WINAPI GetLocalPresenceInfo(RTC_PRESENCE_STATUS *penStatus,BSTR *pbstrNotes) = 0;
  };
#else
  typedef struct IRTCPresenceStatusEventVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IRTCPresenceStatusEvent *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IRTCPresenceStatusEvent *This);
      ULONG (WINAPI *Release)(IRTCPresenceStatusEvent *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IRTCPresenceStatusEvent *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IRTCPresenceStatusEvent *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IRTCPresenceStatusEvent *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IRTCPresenceStatusEvent *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_StatusCode)(IRTCPresenceStatusEvent *This,__LONG32 *plStatusCode);
      HRESULT (WINAPI *get_StatusText)(IRTCPresenceStatusEvent *This,BSTR *pbstrStatusText);
      HRESULT (WINAPI *GetLocalPresenceInfo)(IRTCPresenceStatusEvent *This,RTC_PRESENCE_STATUS *penStatus,BSTR *pbstrNotes);
    END_INTERFACE
  } IRTCPresenceStatusEventVtbl;
  struct IRTCPresenceStatusEvent {
    CONST_VTBL struct IRTCPresenceStatusEventVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IRTCPresenceStatusEvent_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IRTCPresenceStatusEvent_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IRTCPresenceStatusEvent_Release(This) (This)->lpVtbl->Release(This)
#define IRTCPresenceStatusEvent_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IRTCPresenceStatusEvent_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IRTCPresenceStatusEvent_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IRTCPresenceStatusEvent_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IRTCPresenceStatusEvent_get_StatusCode(This,plStatusCode) (This)->lpVtbl->get_StatusCode(This,plStatusCode)
#define IRTCPresenceStatusEvent_get_StatusText(This,pbstrStatusText) (This)->lpVtbl->get_StatusText(This,pbstrStatusText)
#define IRTCPresenceStatusEvent_GetLocalPresenceInfo(This,penStatus,pbstrNotes) (This)->lpVtbl->GetLocalPresenceInfo(This,penStatus,pbstrNotes)
#endif
#endif
  HRESULT WINAPI IRTCPresenceStatusEvent_get_StatusCode_Proxy(IRTCPresenceStatusEvent *This,__LONG32 *plStatusCode);
  void __RPC_STUB IRTCPresenceStatusEvent_get_StatusCode_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCPresenceStatusEvent_get_StatusText_Proxy(IRTCPresenceStatusEvent *This,BSTR *pbstrStatusText);
  void __RPC_STUB IRTCPresenceStatusEvent_get_StatusText_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCPresenceStatusEvent_GetLocalPresenceInfo_Proxy(IRTCPresenceStatusEvent *This,RTC_PRESENCE_STATUS *penStatus,BSTR *pbstrNotes);
  void __RPC_STUB IRTCPresenceStatusEvent_GetLocalPresenceInfo_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IRTCCollection_INTERFACE_DEFINED__
#define __IRTCCollection_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IRTCCollection;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IRTCCollection : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Count(__LONG32 *lCount) = 0;
    virtual HRESULT WINAPI get_Item(__LONG32 Index,VARIANT *pVariant) = 0;
    virtual HRESULT WINAPI get__NewEnum(IUnknown **ppNewEnum) = 0;
  };
#else
  typedef struct IRTCCollectionVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IRTCCollection *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IRTCCollection *This);
      ULONG (WINAPI *Release)(IRTCCollection *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IRTCCollection *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IRTCCollection *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IRTCCollection *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IRTCCollection *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Count)(IRTCCollection *This,__LONG32 *lCount);
      HRESULT (WINAPI *get_Item)(IRTCCollection *This,__LONG32 Index,VARIANT *pVariant);
      HRESULT (WINAPI *get__NewEnum)(IRTCCollection *This,IUnknown **ppNewEnum);
    END_INTERFACE
  } IRTCCollectionVtbl;
  struct IRTCCollection {
    CONST_VTBL struct IRTCCollectionVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IRTCCollection_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IRTCCollection_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IRTCCollection_Release(This) (This)->lpVtbl->Release(This)
#define IRTCCollection_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IRTCCollection_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IRTCCollection_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IRTCCollection_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IRTCCollection_get_Count(This,lCount) (This)->lpVtbl->get_Count(This,lCount)
#define IRTCCollection_get_Item(This,Index,pVariant) (This)->lpVtbl->get_Item(This,Index,pVariant)
#define IRTCCollection_get__NewEnum(This,ppNewEnum) (This)->lpVtbl->get__NewEnum(This,ppNewEnum)
#endif
#endif
  HRESULT WINAPI IRTCCollection_get_Count_Proxy(IRTCCollection *This,__LONG32 *lCount);
  void __RPC_STUB IRTCCollection_get_Count_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCCollection_get_Item_Proxy(IRTCCollection *This,__LONG32 Index,VARIANT *pVariant);
  void __RPC_STUB IRTCCollection_get_Item_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCCollection_get__NewEnum_Proxy(IRTCCollection *This,IUnknown **ppNewEnum);
  void __RPC_STUB IRTCCollection_get__NewEnum_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IRTCEnumParticipants_INTERFACE_DEFINED__
#define __IRTCEnumParticipants_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IRTCEnumParticipants;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IRTCEnumParticipants : public IUnknown {
  public:
    virtual HRESULT WINAPI Next(ULONG celt,IRTCParticipant **ppElements,ULONG *pceltFetched) = 0;
    virtual HRESULT WINAPI Reset(void) = 0;
    virtual HRESULT WINAPI Skip(ULONG celt) = 0;
    virtual HRESULT WINAPI Clone(IRTCEnumParticipants **ppEnum) = 0;
  };
#else
  typedef struct IRTCEnumParticipantsVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IRTCEnumParticipants *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IRTCEnumParticipants *This);
      ULONG (WINAPI *Release)(IRTCEnumParticipants *This);
      HRESULT (WINAPI *Next)(IRTCEnumParticipants *This,ULONG celt,IRTCParticipant **ppElements,ULONG *pceltFetched);
      HRESULT (WINAPI *Reset)(IRTCEnumParticipants *This);
      HRESULT (WINAPI *Skip)(IRTCEnumParticipants *This,ULONG celt);
      HRESULT (WINAPI *Clone)(IRTCEnumParticipants *This,IRTCEnumParticipants **ppEnum);
    END_INTERFACE
  } IRTCEnumParticipantsVtbl;
  struct IRTCEnumParticipants {
    CONST_VTBL struct IRTCEnumParticipantsVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IRTCEnumParticipants_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IRTCEnumParticipants_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IRTCEnumParticipants_Release(This) (This)->lpVtbl->Release(This)
#define IRTCEnumParticipants_Next(This,celt,ppElements,pceltFetched) (This)->lpVtbl->Next(This,celt,ppElements,pceltFetched)
#define IRTCEnumParticipants_Reset(This) (This)->lpVtbl->Reset(This)
#define IRTCEnumParticipants_Skip(This,celt) (This)->lpVtbl->Skip(This,celt)
#define IRTCEnumParticipants_Clone(This,ppEnum) (This)->lpVtbl->Clone(This,ppEnum)
#endif
#endif
  HRESULT WINAPI IRTCEnumParticipants_Next_Proxy(IRTCEnumParticipants *This,ULONG celt,IRTCParticipant **ppElements,ULONG *pceltFetched);
  void __RPC_STUB IRTCEnumParticipants_Next_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCEnumParticipants_Reset_Proxy(IRTCEnumParticipants *This);
  void __RPC_STUB IRTCEnumParticipants_Reset_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCEnumParticipants_Skip_Proxy(IRTCEnumParticipants *This,ULONG celt);
  void __RPC_STUB IRTCEnumParticipants_Skip_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCEnumParticipants_Clone_Proxy(IRTCEnumParticipants *This,IRTCEnumParticipants **ppEnum);
  void __RPC_STUB IRTCEnumParticipants_Clone_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IRTCEnumProfiles_INTERFACE_DEFINED__
#define __IRTCEnumProfiles_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IRTCEnumProfiles;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IRTCEnumProfiles : public IUnknown {
  public:
    virtual HRESULT WINAPI Next(ULONG celt,IRTCProfile **ppElements,ULONG *pceltFetched) = 0;
    virtual HRESULT WINAPI Reset(void) = 0;
    virtual HRESULT WINAPI Skip(ULONG celt) = 0;
    virtual HRESULT WINAPI Clone(IRTCEnumProfiles **ppEnum) = 0;
  };
#else
  typedef struct IRTCEnumProfilesVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IRTCEnumProfiles *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IRTCEnumProfiles *This);
      ULONG (WINAPI *Release)(IRTCEnumProfiles *This);
      HRESULT (WINAPI *Next)(IRTCEnumProfiles *This,ULONG celt,IRTCProfile **ppElements,ULONG *pceltFetched);
      HRESULT (WINAPI *Reset)(IRTCEnumProfiles *This);
      HRESULT (WINAPI *Skip)(IRTCEnumProfiles *This,ULONG celt);
      HRESULT (WINAPI *Clone)(IRTCEnumProfiles *This,IRTCEnumProfiles **ppEnum);
    END_INTERFACE
  } IRTCEnumProfilesVtbl;
  struct IRTCEnumProfiles {
    CONST_VTBL struct IRTCEnumProfilesVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IRTCEnumProfiles_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IRTCEnumProfiles_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IRTCEnumProfiles_Release(This) (This)->lpVtbl->Release(This)
#define IRTCEnumProfiles_Next(This,celt,ppElements,pceltFetched) (This)->lpVtbl->Next(This,celt,ppElements,pceltFetched)
#define IRTCEnumProfiles_Reset(This) (This)->lpVtbl->Reset(This)
#define IRTCEnumProfiles_Skip(This,celt) (This)->lpVtbl->Skip(This,celt)
#define IRTCEnumProfiles_Clone(This,ppEnum) (This)->lpVtbl->Clone(This,ppEnum)
#endif
#endif
  HRESULT WINAPI IRTCEnumProfiles_Next_Proxy(IRTCEnumProfiles *This,ULONG celt,IRTCProfile **ppElements,ULONG *pceltFetched);
  void __RPC_STUB IRTCEnumProfiles_Next_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCEnumProfiles_Reset_Proxy(IRTCEnumProfiles *This);
  void __RPC_STUB IRTCEnumProfiles_Reset_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCEnumProfiles_Skip_Proxy(IRTCEnumProfiles *This,ULONG celt);
  void __RPC_STUB IRTCEnumProfiles_Skip_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCEnumProfiles_Clone_Proxy(IRTCEnumProfiles *This,IRTCEnumProfiles **ppEnum);
  void __RPC_STUB IRTCEnumProfiles_Clone_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IRTCEnumBuddies_INTERFACE_DEFINED__
#define __IRTCEnumBuddies_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IRTCEnumBuddies;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IRTCEnumBuddies : public IUnknown {
  public:
    virtual HRESULT WINAPI Next(ULONG celt,IRTCBuddy **ppElements,ULONG *pceltFetched) = 0;
    virtual HRESULT WINAPI Reset(void) = 0;
    virtual HRESULT WINAPI Skip(ULONG celt) = 0;
    virtual HRESULT WINAPI Clone(IRTCEnumBuddies **ppEnum) = 0;
  };
#else
  typedef struct IRTCEnumBuddiesVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IRTCEnumBuddies *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IRTCEnumBuddies *This);
      ULONG (WINAPI *Release)(IRTCEnumBuddies *This);
      HRESULT (WINAPI *Next)(IRTCEnumBuddies *This,ULONG celt,IRTCBuddy **ppElements,ULONG *pceltFetched);
      HRESULT (WINAPI *Reset)(IRTCEnumBuddies *This);
      HRESULT (WINAPI *Skip)(IRTCEnumBuddies *This,ULONG celt);
      HRESULT (WINAPI *Clone)(IRTCEnumBuddies *This,IRTCEnumBuddies **ppEnum);
    END_INTERFACE
  } IRTCEnumBuddiesVtbl;
  struct IRTCEnumBuddies {
    CONST_VTBL struct IRTCEnumBuddiesVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IRTCEnumBuddies_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IRTCEnumBuddies_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IRTCEnumBuddies_Release(This) (This)->lpVtbl->Release(This)
#define IRTCEnumBuddies_Next(This,celt,ppElements,pceltFetched) (This)->lpVtbl->Next(This,celt,ppElements,pceltFetched)
#define IRTCEnumBuddies_Reset(This) (This)->lpVtbl->Reset(This)
#define IRTCEnumBuddies_Skip(This,celt) (This)->lpVtbl->Skip(This,celt)
#define IRTCEnumBuddies_Clone(This,ppEnum) (This)->lpVtbl->Clone(This,ppEnum)
#endif
#endif
  HRESULT WINAPI IRTCEnumBuddies_Next_Proxy(IRTCEnumBuddies *This,ULONG celt,IRTCBuddy **ppElements,ULONG *pceltFetched);
  void __RPC_STUB IRTCEnumBuddies_Next_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCEnumBuddies_Reset_Proxy(IRTCEnumBuddies *This);
  void __RPC_STUB IRTCEnumBuddies_Reset_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCEnumBuddies_Skip_Proxy(IRTCEnumBuddies *This,ULONG celt);
  void __RPC_STUB IRTCEnumBuddies_Skip_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCEnumBuddies_Clone_Proxy(IRTCEnumBuddies *This,IRTCEnumBuddies **ppEnum);
  void __RPC_STUB IRTCEnumBuddies_Clone_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IRTCEnumWatchers_INTERFACE_DEFINED__
#define __IRTCEnumWatchers_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IRTCEnumWatchers;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IRTCEnumWatchers : public IUnknown {
  public:
    virtual HRESULT WINAPI Next(ULONG celt,IRTCWatcher **ppElements,ULONG *pceltFetched) = 0;
    virtual HRESULT WINAPI Reset(void) = 0;
    virtual HRESULT WINAPI Skip(ULONG celt) = 0;
    virtual HRESULT WINAPI Clone(IRTCEnumWatchers **ppEnum) = 0;
  };
#else
  typedef struct IRTCEnumWatchersVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IRTCEnumWatchers *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IRTCEnumWatchers *This);
      ULONG (WINAPI *Release)(IRTCEnumWatchers *This);
      HRESULT (WINAPI *Next)(IRTCEnumWatchers *This,ULONG celt,IRTCWatcher **ppElements,ULONG *pceltFetched);
      HRESULT (WINAPI *Reset)(IRTCEnumWatchers *This);
      HRESULT (WINAPI *Skip)(IRTCEnumWatchers *This,ULONG celt);
      HRESULT (WINAPI *Clone)(IRTCEnumWatchers *This,IRTCEnumWatchers **ppEnum);
    END_INTERFACE
  } IRTCEnumWatchersVtbl;
  struct IRTCEnumWatchers {
    CONST_VTBL struct IRTCEnumWatchersVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IRTCEnumWatchers_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IRTCEnumWatchers_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IRTCEnumWatchers_Release(This) (This)->lpVtbl->Release(This)
#define IRTCEnumWatchers_Next(This,celt,ppElements,pceltFetched) (This)->lpVtbl->Next(This,celt,ppElements,pceltFetched)
#define IRTCEnumWatchers_Reset(This) (This)->lpVtbl->Reset(This)
#define IRTCEnumWatchers_Skip(This,celt) (This)->lpVtbl->Skip(This,celt)
#define IRTCEnumWatchers_Clone(This,ppEnum) (This)->lpVtbl->Clone(This,ppEnum)
#endif
#endif
  HRESULT WINAPI IRTCEnumWatchers_Next_Proxy(IRTCEnumWatchers *This,ULONG celt,IRTCWatcher **ppElements,ULONG *pceltFetched);
  void __RPC_STUB IRTCEnumWatchers_Next_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCEnumWatchers_Reset_Proxy(IRTCEnumWatchers *This);
  void __RPC_STUB IRTCEnumWatchers_Reset_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCEnumWatchers_Skip_Proxy(IRTCEnumWatchers *This,ULONG celt);
  void __RPC_STUB IRTCEnumWatchers_Skip_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCEnumWatchers_Clone_Proxy(IRTCEnumWatchers *This,IRTCEnumWatchers **ppEnum);
  void __RPC_STUB IRTCEnumWatchers_Clone_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IRTCEnumGroups_INTERFACE_DEFINED__
#define __IRTCEnumGroups_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IRTCEnumGroups;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IRTCEnumGroups : public IUnknown {
  public:
    virtual HRESULT WINAPI Next(ULONG celt,IRTCBuddyGroup **ppElements,ULONG *pceltFetched) = 0;
    virtual HRESULT WINAPI Reset(void) = 0;
    virtual HRESULT WINAPI Skip(ULONG celt) = 0;
    virtual HRESULT WINAPI Clone(IRTCEnumGroups **ppEnum) = 0;
  };
#else
  typedef struct IRTCEnumGroupsVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IRTCEnumGroups *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IRTCEnumGroups *This);
      ULONG (WINAPI *Release)(IRTCEnumGroups *This);
      HRESULT (WINAPI *Next)(IRTCEnumGroups *This,ULONG celt,IRTCBuddyGroup **ppElements,ULONG *pceltFetched);
      HRESULT (WINAPI *Reset)(IRTCEnumGroups *This);
      HRESULT (WINAPI *Skip)(IRTCEnumGroups *This,ULONG celt);
      HRESULT (WINAPI *Clone)(IRTCEnumGroups *This,IRTCEnumGroups **ppEnum);
    END_INTERFACE
  } IRTCEnumGroupsVtbl;
  struct IRTCEnumGroups {
    CONST_VTBL struct IRTCEnumGroupsVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IRTCEnumGroups_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IRTCEnumGroups_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IRTCEnumGroups_Release(This) (This)->lpVtbl->Release(This)
#define IRTCEnumGroups_Next(This,celt,ppElements,pceltFetched) (This)->lpVtbl->Next(This,celt,ppElements,pceltFetched)
#define IRTCEnumGroups_Reset(This) (This)->lpVtbl->Reset(This)
#define IRTCEnumGroups_Skip(This,celt) (This)->lpVtbl->Skip(This,celt)
#define IRTCEnumGroups_Clone(This,ppEnum) (This)->lpVtbl->Clone(This,ppEnum)
#endif
#endif
  HRESULT WINAPI IRTCEnumGroups_Next_Proxy(IRTCEnumGroups *This,ULONG celt,IRTCBuddyGroup **ppElements,ULONG *pceltFetched);
  void __RPC_STUB IRTCEnumGroups_Next_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCEnumGroups_Reset_Proxy(IRTCEnumGroups *This);
  void __RPC_STUB IRTCEnumGroups_Reset_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCEnumGroups_Skip_Proxy(IRTCEnumGroups *This,ULONG celt);
  void __RPC_STUB IRTCEnumGroups_Skip_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCEnumGroups_Clone_Proxy(IRTCEnumGroups *This,IRTCEnumGroups **ppEnum);
  void __RPC_STUB IRTCEnumGroups_Clone_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif
#ifndef __IRTCPresenceContact_INTERFACE_DEFINED__
#define __IRTCPresenceContact_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IRTCPresenceContact;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IRTCPresenceContact : public IUnknown {
  public:
    virtual HRESULT WINAPI get_PresentityURI(BSTR *pbstrPresentityURI) = 0;
    virtual HRESULT WINAPI put_PresentityURI(BSTR bstrPresentityURI) = 0;
    virtual HRESULT WINAPI get_Name(BSTR *pbstrName) = 0;
    virtual HRESULT WINAPI put_Name(BSTR bstrName) = 0;
    virtual HRESULT WINAPI get_Data(BSTR *pbstrData) = 0;
    virtual HRESULT WINAPI put_Data(BSTR bstrData) = 0;
    virtual HRESULT WINAPI get_Persistent(VARIANT_BOOL *pfPersistent) = 0;
    virtual HRESULT WINAPI put_Persistent(VARIANT_BOOL fPersistent) = 0;
  };
#else
  typedef struct IRTCPresenceContactVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IRTCPresenceContact *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IRTCPresenceContact *This);
      ULONG (WINAPI *Release)(IRTCPresenceContact *This);
      HRESULT (WINAPI *get_PresentityURI)(IRTCPresenceContact *This,BSTR *pbstrPresentityURI);
      HRESULT (WINAPI *put_PresentityURI)(IRTCPresenceContact *This,BSTR bstrPresentityURI);
      HRESULT (WINAPI *get_Name)(IRTCPresenceContact *This,BSTR *pbstrName);
      HRESULT (WINAPI *put_Name)(IRTCPresenceContact *This,BSTR bstrName);
      HRESULT (WINAPI *get_Data)(IRTCPresenceContact *This,BSTR *pbstrData);
      HRESULT (WINAPI *put_Data)(IRTCPresenceContact *This,BSTR bstrData);
      HRESULT (WINAPI *get_Persistent)(IRTCPresenceContact *This,VARIANT_BOOL *pfPersistent);
      HRESULT (WINAPI *put_Persistent)(IRTCPresenceContact *This,VARIANT_BOOL fPersistent);
    END_INTERFACE
  } IRTCPresenceContactVtbl;
  struct IRTCPresenceContact {
    CONST_VTBL struct IRTCPresenceContactVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IRTCPresenceContact_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IRTCPresenceContact_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IRTCPresenceContact_Release(This) (This)->lpVtbl->Release(This)
#define IRTCPresenceContact_get_PresentityURI(This,pbstrPresentityURI) (This)->lpVtbl->get_PresentityURI(This,pbstrPresentityURI)
#define IRTCPresenceContact_put_PresentityURI(This,bstrPresentityURI) (This)->lpVtbl->put_PresentityURI(This,bstrPresentityURI)
#define IRTCPresenceContact_get_Name(This,pbstrName) (This)->lpVtbl->get_Name(This,pbstrName)
#define IRTCPresenceContact_put_Name(This,bstrName) (This)->lpVtbl->put_Name(This,bstrName)
#define IRTCPresenceContact_get_Data(This,pbstrData) (This)->lpVtbl->get_Data(This,pbstrData)
#define IRTCPresenceContact_put_Data(This,bstrData) (This)->lpVtbl->put_Data(This,bstrData)
#define IRTCPresenceContact_get_Persistent(This,pfPersistent) (This)->lpVtbl->get_Persistent(This,pfPersistent)
#define IRTCPresenceContact_put_Persistent(This,fPersistent) (This)->lpVtbl->put_Persistent(This,fPersistent)
#endif
#endif
  HRESULT WINAPI IRTCPresenceContact_get_PresentityURI_Proxy(IRTCPresenceContact *This,BSTR *pbstrPresentityURI);
  void __RPC_STUB IRTCPresenceContact_get_PresentityURI_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCPresenceContact_put_PresentityURI_Proxy(IRTCPresenceContact *This,BSTR bstrPresentityURI);
  void __RPC_STUB IRTCPresenceContact_put_PresentityURI_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCPresenceContact_get_Name_Proxy(IRTCPresenceContact *This,BSTR *pbstrName);
  void __RPC_STUB IRTCPresenceContact_get_Name_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCPresenceContact_put_Name_Proxy(IRTCPresenceContact *This,BSTR bstrName);
  void __RPC_STUB IRTCPresenceContact_put_Name_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCPresenceContact_get_Data_Proxy(IRTCPresenceContact *This,BSTR *pbstrData);
  void __RPC_STUB IRTCPresenceContact_get_Data_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCPresenceContact_put_Data_Proxy(IRTCPresenceContact *This,BSTR bstrData);
  void __RPC_STUB IRTCPresenceContact_put_Data_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCPresenceContact_get_Persistent_Proxy(IRTCPresenceContact *This,VARIANT_BOOL *pfPersistent);
  void __RPC_STUB IRTCPresenceContact_get_Persistent_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCPresenceContact_put_Persistent_Proxy(IRTCPresenceContact *This,VARIANT_BOOL fPersistent);
  void __RPC_STUB IRTCPresenceContact_put_Persistent_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IRTCBuddy_INTERFACE_DEFINED__
#define __IRTCBuddy_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IRTCBuddy;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IRTCBuddy : public IRTCPresenceContact {
  public:
    virtual HRESULT WINAPI get_Status(RTC_PRESENCE_STATUS *penStatus) = 0;
    virtual HRESULT WINAPI get_Notes(BSTR *pbstrNotes) = 0;
  };
#else
  typedef struct IRTCBuddyVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IRTCBuddy *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IRTCBuddy *This);
      ULONG (WINAPI *Release)(IRTCBuddy *This);
      HRESULT (WINAPI *get_PresentityURI)(IRTCBuddy *This,BSTR *pbstrPresentityURI);
      HRESULT (WINAPI *put_PresentityURI)(IRTCBuddy *This,BSTR bstrPresentityURI);
      HRESULT (WINAPI *get_Name)(IRTCBuddy *This,BSTR *pbstrName);
      HRESULT (WINAPI *put_Name)(IRTCBuddy *This,BSTR bstrName);
      HRESULT (WINAPI *get_Data)(IRTCBuddy *This,BSTR *pbstrData);
      HRESULT (WINAPI *put_Data)(IRTCBuddy *This,BSTR bstrData);
      HRESULT (WINAPI *get_Persistent)(IRTCBuddy *This,VARIANT_BOOL *pfPersistent);
      HRESULT (WINAPI *put_Persistent)(IRTCBuddy *This,VARIANT_BOOL fPersistent);
      HRESULT (WINAPI *get_Status)(IRTCBuddy *This,RTC_PRESENCE_STATUS *penStatus);
      HRESULT (WINAPI *get_Notes)(IRTCBuddy *This,BSTR *pbstrNotes);
    END_INTERFACE
  } IRTCBuddyVtbl;
  struct IRTCBuddy {
    CONST_VTBL struct IRTCBuddyVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IRTCBuddy_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IRTCBuddy_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IRTCBuddy_Release(This) (This)->lpVtbl->Release(This)
#define IRTCBuddy_get_PresentityURI(This,pbstrPresentityURI) (This)->lpVtbl->get_PresentityURI(This,pbstrPresentityURI)
#define IRTCBuddy_put_PresentityURI(This,bstrPresentityURI) (This)->lpVtbl->put_PresentityURI(This,bstrPresentityURI)
#define IRTCBuddy_get_Name(This,pbstrName) (This)->lpVtbl->get_Name(This,pbstrName)
#define IRTCBuddy_put_Name(This,bstrName) (This)->lpVtbl->put_Name(This,bstrName)
#define IRTCBuddy_get_Data(This,pbstrData) (This)->lpVtbl->get_Data(This,pbstrData)
#define IRTCBuddy_put_Data(This,bstrData) (This)->lpVtbl->put_Data(This,bstrData)
#define IRTCBuddy_get_Persistent(This,pfPersistent) (This)->lpVtbl->get_Persistent(This,pfPersistent)
#define IRTCBuddy_put_Persistent(This,fPersistent) (This)->lpVtbl->put_Persistent(This,fPersistent)
#define IRTCBuddy_get_Status(This,penStatus) (This)->lpVtbl->get_Status(This,penStatus)
#define IRTCBuddy_get_Notes(This,pbstrNotes) (This)->lpVtbl->get_Notes(This,pbstrNotes)
#endif
#endif
  HRESULT WINAPI IRTCBuddy_get_Status_Proxy(IRTCBuddy *This,RTC_PRESENCE_STATUS *penStatus);
  void __RPC_STUB IRTCBuddy_get_Status_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCBuddy_get_Notes_Proxy(IRTCBuddy *This,BSTR *pbstrNotes);
  void __RPC_STUB IRTCBuddy_get_Notes_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IRTCBuddy2_INTERFACE_DEFINED__
#define __IRTCBuddy2_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IRTCBuddy2;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IRTCBuddy2 : public IRTCBuddy {
  public:
    virtual HRESULT WINAPI get_Profile(IRTCProfile2 **ppProfile) = 0;
    virtual HRESULT WINAPI Refresh(void) = 0;
    virtual HRESULT WINAPI EnumerateGroups(IRTCEnumGroups **ppEnum) = 0;
    virtual HRESULT WINAPI get_Groups(IRTCCollection **ppCollection) = 0;
    virtual HRESULT WINAPI get_PresenceProperty(RTC_PRESENCE_PROPERTY enProperty,BSTR *pbstrProperty) = 0;
    virtual HRESULT WINAPI EnumeratePresenceDevices(IRTCEnumPresenceDevices **ppEnumDevices) = 0;
    virtual HRESULT WINAPI get_PresenceDevices(IRTCCollection **ppDevicesCollection) = 0;
    virtual HRESULT WINAPI get_SubscriptionType(RTC_BUDDY_SUBSCRIPTION_TYPE *penSubscriptionType) = 0;
  };
#else
  typedef struct IRTCBuddy2Vtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IRTCBuddy2 *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IRTCBuddy2 *This);
      ULONG (WINAPI *Release)(IRTCBuddy2 *This);
      HRESULT (WINAPI *get_PresentityURI)(IRTCBuddy2 *This,BSTR *pbstrPresentityURI);
      HRESULT (WINAPI *put_PresentityURI)(IRTCBuddy2 *This,BSTR bstrPresentityURI);
      HRESULT (WINAPI *get_Name)(IRTCBuddy2 *This,BSTR *pbstrName);
      HRESULT (WINAPI *put_Name)(IRTCBuddy2 *This,BSTR bstrName);
      HRESULT (WINAPI *get_Data)(IRTCBuddy2 *This,BSTR *pbstrData);
      HRESULT (WINAPI *put_Data)(IRTCBuddy2 *This,BSTR bstrData);
      HRESULT (WINAPI *get_Persistent)(IRTCBuddy2 *This,VARIANT_BOOL *pfPersistent);
      HRESULT (WINAPI *put_Persistent)(IRTCBuddy2 *This,VARIANT_BOOL fPersistent);
      HRESULT (WINAPI *get_Status)(IRTCBuddy2 *This,RTC_PRESENCE_STATUS *penStatus);
      HRESULT (WINAPI *get_Notes)(IRTCBuddy2 *This,BSTR *pbstrNotes);
      HRESULT (WINAPI *get_Profile)(IRTCBuddy2 *This,IRTCProfile2 **ppProfile);
      HRESULT (WINAPI *Refresh)(IRTCBuddy2 *This);
      HRESULT (WINAPI *EnumerateGroups)(IRTCBuddy2 *This,IRTCEnumGroups **ppEnum);
      HRESULT (WINAPI *get_Groups)(IRTCBuddy2 *This,IRTCCollection **ppCollection);
      HRESULT (WINAPI *get_PresenceProperty)(IRTCBuddy2 *This,RTC_PRESENCE_PROPERTY enProperty,BSTR *pbstrProperty);
      HRESULT (WINAPI *EnumeratePresenceDevices)(IRTCBuddy2 *This,IRTCEnumPresenceDevices **ppEnumDevices);
      HRESULT (WINAPI *get_PresenceDevices)(IRTCBuddy2 *This,IRTCCollection **ppDevicesCollection);
      HRESULT (WINAPI *get_SubscriptionType)(IRTCBuddy2 *This,RTC_BUDDY_SUBSCRIPTION_TYPE *penSubscriptionType);
    END_INTERFACE
  } IRTCBuddy2Vtbl;
  struct IRTCBuddy2 {
    CONST_VTBL struct IRTCBuddy2Vtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IRTCBuddy2_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IRTCBuddy2_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IRTCBuddy2_Release(This) (This)->lpVtbl->Release(This)
#define IRTCBuddy2_get_PresentityURI(This,pbstrPresentityURI) (This)->lpVtbl->get_PresentityURI(This,pbstrPresentityURI)
#define IRTCBuddy2_put_PresentityURI(This,bstrPresentityURI) (This)->lpVtbl->put_PresentityURI(This,bstrPresentityURI)
#define IRTCBuddy2_get_Name(This,pbstrName) (This)->lpVtbl->get_Name(This,pbstrName)
#define IRTCBuddy2_put_Name(This,bstrName) (This)->lpVtbl->put_Name(This,bstrName)
#define IRTCBuddy2_get_Data(This,pbstrData) (This)->lpVtbl->get_Data(This,pbstrData)
#define IRTCBuddy2_put_Data(This,bstrData) (This)->lpVtbl->put_Data(This,bstrData)
#define IRTCBuddy2_get_Persistent(This,pfPersistent) (This)->lpVtbl->get_Persistent(This,pfPersistent)
#define IRTCBuddy2_put_Persistent(This,fPersistent) (This)->lpVtbl->put_Persistent(This,fPersistent)
#define IRTCBuddy2_get_Status(This,penStatus) (This)->lpVtbl->get_Status(This,penStatus)
#define IRTCBuddy2_get_Notes(This,pbstrNotes) (This)->lpVtbl->get_Notes(This,pbstrNotes)
#define IRTCBuddy2_get_Profile(This,ppProfile) (This)->lpVtbl->get_Profile(This,ppProfile)
#define IRTCBuddy2_Refresh(This) (This)->lpVtbl->Refresh(This)
#define IRTCBuddy2_EnumerateGroups(This,ppEnum) (This)->lpVtbl->EnumerateGroups(This,ppEnum)
#define IRTCBuddy2_get_Groups(This,ppCollection) (This)->lpVtbl->get_Groups(This,ppCollection)
#define IRTCBuddy2_get_PresenceProperty(This,enProperty,pbstrProperty) (This)->lpVtbl->get_PresenceProperty(This,enProperty,pbstrProperty)
#define IRTCBuddy2_EnumeratePresenceDevices(This,ppEnumDevices) (This)->lpVtbl->EnumeratePresenceDevices(This,ppEnumDevices)
#define IRTCBuddy2_get_PresenceDevices(This,ppDevicesCollection) (This)->lpVtbl->get_PresenceDevices(This,ppDevicesCollection)
#define IRTCBuddy2_get_SubscriptionType(This,penSubscriptionType) (This)->lpVtbl->get_SubscriptionType(This,penSubscriptionType)
#endif
#endif
  HRESULT WINAPI IRTCBuddy2_get_Profile_Proxy(IRTCBuddy2 *This,IRTCProfile2 **ppProfile);
  void __RPC_STUB IRTCBuddy2_get_Profile_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCBuddy2_Refresh_Proxy(IRTCBuddy2 *This);
  void __RPC_STUB IRTCBuddy2_Refresh_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCBuddy2_EnumerateGroups_Proxy(IRTCBuddy2 *This,IRTCEnumGroups **ppEnum);
  void __RPC_STUB IRTCBuddy2_EnumerateGroups_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCBuddy2_get_Groups_Proxy(IRTCBuddy2 *This,IRTCCollection **ppCollection);
  void __RPC_STUB IRTCBuddy2_get_Groups_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCBuddy2_get_PresenceProperty_Proxy(IRTCBuddy2 *This,RTC_PRESENCE_PROPERTY enProperty,BSTR *pbstrProperty);
  void __RPC_STUB IRTCBuddy2_get_PresenceProperty_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCBuddy2_EnumeratePresenceDevices_Proxy(IRTCBuddy2 *This,IRTCEnumPresenceDevices **ppEnumDevices);
  void __RPC_STUB IRTCBuddy2_EnumeratePresenceDevices_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCBuddy2_get_PresenceDevices_Proxy(IRTCBuddy2 *This,IRTCCollection **ppDevicesCollection);
  void __RPC_STUB IRTCBuddy2_get_PresenceDevices_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCBuddy2_get_SubscriptionType_Proxy(IRTCBuddy2 *This,RTC_BUDDY_SUBSCRIPTION_TYPE *penSubscriptionType);
  void __RPC_STUB IRTCBuddy2_get_SubscriptionType_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IRTCWatcher_INTERFACE_DEFINED__
#define __IRTCWatcher_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IRTCWatcher;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IRTCWatcher : public IRTCPresenceContact {
  public:
    virtual HRESULT WINAPI get_State(RTC_WATCHER_STATE *penState) = 0;
    virtual HRESULT WINAPI put_State(RTC_WATCHER_STATE enState) = 0;
  };
#else
  typedef struct IRTCWatcherVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IRTCWatcher *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IRTCWatcher *This);
      ULONG (WINAPI *Release)(IRTCWatcher *This);
      HRESULT (WINAPI *get_PresentityURI)(IRTCWatcher *This,BSTR *pbstrPresentityURI);
      HRESULT (WINAPI *put_PresentityURI)(IRTCWatcher *This,BSTR bstrPresentityURI);
      HRESULT (WINAPI *get_Name)(IRTCWatcher *This,BSTR *pbstrName);
      HRESULT (WINAPI *put_Name)(IRTCWatcher *This,BSTR bstrName);
      HRESULT (WINAPI *get_Data)(IRTCWatcher *This,BSTR *pbstrData);
      HRESULT (WINAPI *put_Data)(IRTCWatcher *This,BSTR bstrData);
      HRESULT (WINAPI *get_Persistent)(IRTCWatcher *This,VARIANT_BOOL *pfPersistent);
      HRESULT (WINAPI *put_Persistent)(IRTCWatcher *This,VARIANT_BOOL fPersistent);
      HRESULT (WINAPI *get_State)(IRTCWatcher *This,RTC_WATCHER_STATE *penState);
      HRESULT (WINAPI *put_State)(IRTCWatcher *This,RTC_WATCHER_STATE enState);
    END_INTERFACE
  } IRTCWatcherVtbl;
  struct IRTCWatcher {
    CONST_VTBL struct IRTCWatcherVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IRTCWatcher_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IRTCWatcher_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IRTCWatcher_Release(This) (This)->lpVtbl->Release(This)
#define IRTCWatcher_get_PresentityURI(This,pbstrPresentityURI) (This)->lpVtbl->get_PresentityURI(This,pbstrPresentityURI)
#define IRTCWatcher_put_PresentityURI(This,bstrPresentityURI) (This)->lpVtbl->put_PresentityURI(This,bstrPresentityURI)
#define IRTCWatcher_get_Name(This,pbstrName) (This)->lpVtbl->get_Name(This,pbstrName)
#define IRTCWatcher_put_Name(This,bstrName) (This)->lpVtbl->put_Name(This,bstrName)
#define IRTCWatcher_get_Data(This,pbstrData) (This)->lpVtbl->get_Data(This,pbstrData)
#define IRTCWatcher_put_Data(This,bstrData) (This)->lpVtbl->put_Data(This,bstrData)
#define IRTCWatcher_get_Persistent(This,pfPersistent) (This)->lpVtbl->get_Persistent(This,pfPersistent)
#define IRTCWatcher_put_Persistent(This,fPersistent) (This)->lpVtbl->put_Persistent(This,fPersistent)
#define IRTCWatcher_get_State(This,penState) (This)->lpVtbl->get_State(This,penState)
#define IRTCWatcher_put_State(This,enState) (This)->lpVtbl->put_State(This,enState)
#endif
#endif
  HRESULT WINAPI IRTCWatcher_get_State_Proxy(IRTCWatcher *This,RTC_WATCHER_STATE *penState);
  void __RPC_STUB IRTCWatcher_get_State_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCWatcher_put_State_Proxy(IRTCWatcher *This,RTC_WATCHER_STATE enState);
  void __RPC_STUB IRTCWatcher_put_State_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IRTCWatcher2_INTERFACE_DEFINED__
#define __IRTCWatcher2_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IRTCWatcher2;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IRTCWatcher2 : public IRTCWatcher {
  public:
    virtual HRESULT WINAPI get_Profile(IRTCProfile2 **ppProfile) = 0;
    virtual HRESULT WINAPI get_Scope(RTC_ACE_SCOPE *penScope) = 0;
  };
#else
  typedef struct IRTCWatcher2Vtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IRTCWatcher2 *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IRTCWatcher2 *This);
      ULONG (WINAPI *Release)(IRTCWatcher2 *This);
      HRESULT (WINAPI *get_PresentityURI)(IRTCWatcher2 *This,BSTR *pbstrPresentityURI);
      HRESULT (WINAPI *put_PresentityURI)(IRTCWatcher2 *This,BSTR bstrPresentityURI);
      HRESULT (WINAPI *get_Name)(IRTCWatcher2 *This,BSTR *pbstrName);
      HRESULT (WINAPI *put_Name)(IRTCWatcher2 *This,BSTR bstrName);
      HRESULT (WINAPI *get_Data)(IRTCWatcher2 *This,BSTR *pbstrData);
      HRESULT (WINAPI *put_Data)(IRTCWatcher2 *This,BSTR bstrData);
      HRESULT (WINAPI *get_Persistent)(IRTCWatcher2 *This,VARIANT_BOOL *pfPersistent);
      HRESULT (WINAPI *put_Persistent)(IRTCWatcher2 *This,VARIANT_BOOL fPersistent);
      HRESULT (WINAPI *get_State)(IRTCWatcher2 *This,RTC_WATCHER_STATE *penState);
      HRESULT (WINAPI *put_State)(IRTCWatcher2 *This,RTC_WATCHER_STATE enState);
      HRESULT (WINAPI *get_Profile)(IRTCWatcher2 *This,IRTCProfile2 **ppProfile);
      HRESULT (WINAPI *get_Scope)(IRTCWatcher2 *This,RTC_ACE_SCOPE *penScope);
    END_INTERFACE
  } IRTCWatcher2Vtbl;
  struct IRTCWatcher2 {
    CONST_VTBL struct IRTCWatcher2Vtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IRTCWatcher2_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IRTCWatcher2_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IRTCWatcher2_Release(This) (This)->lpVtbl->Release(This)
#define IRTCWatcher2_get_PresentityURI(This,pbstrPresentityURI) (This)->lpVtbl->get_PresentityURI(This,pbstrPresentityURI)
#define IRTCWatcher2_put_PresentityURI(This,bstrPresentityURI) (This)->lpVtbl->put_PresentityURI(This,bstrPresentityURI)
#define IRTCWatcher2_get_Name(This,pbstrName) (This)->lpVtbl->get_Name(This,pbstrName)
#define IRTCWatcher2_put_Name(This,bstrName) (This)->lpVtbl->put_Name(This,bstrName)
#define IRTCWatcher2_get_Data(This,pbstrData) (This)->lpVtbl->get_Data(This,pbstrData)
#define IRTCWatcher2_put_Data(This,bstrData) (This)->lpVtbl->put_Data(This,bstrData)
#define IRTCWatcher2_get_Persistent(This,pfPersistent) (This)->lpVtbl->get_Persistent(This,pfPersistent)
#define IRTCWatcher2_put_Persistent(This,fPersistent) (This)->lpVtbl->put_Persistent(This,fPersistent)
#define IRTCWatcher2_get_State(This,penState) (This)->lpVtbl->get_State(This,penState)
#define IRTCWatcher2_put_State(This,enState) (This)->lpVtbl->put_State(This,enState)
#define IRTCWatcher2_get_Profile(This,ppProfile) (This)->lpVtbl->get_Profile(This,ppProfile)
#define IRTCWatcher2_get_Scope(This,penScope) (This)->lpVtbl->get_Scope(This,penScope)
#endif
#endif
  HRESULT WINAPI IRTCWatcher2_get_Profile_Proxy(IRTCWatcher2 *This,IRTCProfile2 **ppProfile);
  void __RPC_STUB IRTCWatcher2_get_Profile_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCWatcher2_get_Scope_Proxy(IRTCWatcher2 *This,RTC_ACE_SCOPE *penScope);
  void __RPC_STUB IRTCWatcher2_get_Scope_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IRTCBuddyGroup_INTERFACE_DEFINED__
#define __IRTCBuddyGroup_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IRTCBuddyGroup;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IRTCBuddyGroup : public IUnknown {
  public:
    virtual HRESULT WINAPI get_Name(BSTR *pbstrGroupName) = 0;
    virtual HRESULT WINAPI put_Name(BSTR bstrGroupName) = 0;
    virtual HRESULT WINAPI AddBuddy(IRTCBuddy *pBuddy) = 0;
    virtual HRESULT WINAPI RemoveBuddy(IRTCBuddy *pBuddy) = 0;
    virtual HRESULT WINAPI EnumerateBuddies(IRTCEnumBuddies **ppEnum) = 0;
    virtual HRESULT WINAPI get_Buddies(IRTCCollection **ppCollection) = 0;
    virtual HRESULT WINAPI get_Data(BSTR *pbstrData) = 0;
    virtual HRESULT WINAPI put_Data(BSTR bstrData) = 0;
    virtual HRESULT WINAPI get_Profile(IRTCProfile2 **ppProfile) = 0;
  };
#else
  typedef struct IRTCBuddyGroupVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IRTCBuddyGroup *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IRTCBuddyGroup *This);
      ULONG (WINAPI *Release)(IRTCBuddyGroup *This);
      HRESULT (WINAPI *get_Name)(IRTCBuddyGroup *This,BSTR *pbstrGroupName);
      HRESULT (WINAPI *put_Name)(IRTCBuddyGroup *This,BSTR bstrGroupName);
      HRESULT (WINAPI *AddBuddy)(IRTCBuddyGroup *This,IRTCBuddy *pBuddy);
      HRESULT (WINAPI *RemoveBuddy)(IRTCBuddyGroup *This,IRTCBuddy *pBuddy);
      HRESULT (WINAPI *EnumerateBuddies)(IRTCBuddyGroup *This,IRTCEnumBuddies **ppEnum);
      HRESULT (WINAPI *get_Buddies)(IRTCBuddyGroup *This,IRTCCollection **ppCollection);
      HRESULT (WINAPI *get_Data)(IRTCBuddyGroup *This,BSTR *pbstrData);
      HRESULT (WINAPI *put_Data)(IRTCBuddyGroup *This,BSTR bstrData);
      HRESULT (WINAPI *get_Profile)(IRTCBuddyGroup *This,IRTCProfile2 **ppProfile);
    END_INTERFACE
  } IRTCBuddyGroupVtbl;
  struct IRTCBuddyGroup {
    CONST_VTBL struct IRTCBuddyGroupVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IRTCBuddyGroup_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IRTCBuddyGroup_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IRTCBuddyGroup_Release(This) (This)->lpVtbl->Release(This)
#define IRTCBuddyGroup_get_Name(This,pbstrGroupName) (This)->lpVtbl->get_Name(This,pbstrGroupName)
#define IRTCBuddyGroup_put_Name(This,bstrGroupName) (This)->lpVtbl->put_Name(This,bstrGroupName)
#define IRTCBuddyGroup_AddBuddy(This,pBuddy) (This)->lpVtbl->AddBuddy(This,pBuddy)
#define IRTCBuddyGroup_RemoveBuddy(This,pBuddy) (This)->lpVtbl->RemoveBuddy(This,pBuddy)
#define IRTCBuddyGroup_EnumerateBuddies(This,ppEnum) (This)->lpVtbl->EnumerateBuddies(This,ppEnum)
#define IRTCBuddyGroup_get_Buddies(This,ppCollection) (This)->lpVtbl->get_Buddies(This,ppCollection)
#define IRTCBuddyGroup_get_Data(This,pbstrData) (This)->lpVtbl->get_Data(This,pbstrData)
#define IRTCBuddyGroup_put_Data(This,bstrData) (This)->lpVtbl->put_Data(This,bstrData)
#define IRTCBuddyGroup_get_Profile(This,ppProfile) (This)->lpVtbl->get_Profile(This,ppProfile)
#endif
#endif
  HRESULT WINAPI IRTCBuddyGroup_get_Name_Proxy(IRTCBuddyGroup *This,BSTR *pbstrGroupName);
  void __RPC_STUB IRTCBuddyGroup_get_Name_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCBuddyGroup_put_Name_Proxy(IRTCBuddyGroup *This,BSTR bstrGroupName);
  void __RPC_STUB IRTCBuddyGroup_put_Name_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCBuddyGroup_AddBuddy_Proxy(IRTCBuddyGroup *This,IRTCBuddy *pBuddy);
  void __RPC_STUB IRTCBuddyGroup_AddBuddy_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCBuddyGroup_RemoveBuddy_Proxy(IRTCBuddyGroup *This,IRTCBuddy *pBuddy);
  void __RPC_STUB IRTCBuddyGroup_RemoveBuddy_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCBuddyGroup_EnumerateBuddies_Proxy(IRTCBuddyGroup *This,IRTCEnumBuddies **ppEnum);
  void __RPC_STUB IRTCBuddyGroup_EnumerateBuddies_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCBuddyGroup_get_Buddies_Proxy(IRTCBuddyGroup *This,IRTCCollection **ppCollection);
  void __RPC_STUB IRTCBuddyGroup_get_Buddies_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCBuddyGroup_get_Data_Proxy(IRTCBuddyGroup *This,BSTR *pbstrData);
  void __RPC_STUB IRTCBuddyGroup_get_Data_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCBuddyGroup_put_Data_Proxy(IRTCBuddyGroup *This,BSTR bstrData);
  void __RPC_STUB IRTCBuddyGroup_put_Data_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCBuddyGroup_get_Profile_Proxy(IRTCBuddyGroup *This,IRTCProfile2 **ppProfile);
  void __RPC_STUB IRTCBuddyGroup_get_Profile_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IRTCEventNotification_INTERFACE_DEFINED__
#define __IRTCEventNotification_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IRTCEventNotification;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IRTCEventNotification : public IUnknown {
  public:
    virtual HRESULT WINAPI Event(RTC_EVENT RTCEvent,IDispatch *pEvent) = 0;
  };
#else
  typedef struct IRTCEventNotificationVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IRTCEventNotification *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IRTCEventNotification *This);
      ULONG (WINAPI *Release)(IRTCEventNotification *This);
      HRESULT (WINAPI *Event)(IRTCEventNotification *This,RTC_EVENT RTCEvent,IDispatch *pEvent);
    END_INTERFACE
  } IRTCEventNotificationVtbl;
  struct IRTCEventNotification {
    CONST_VTBL struct IRTCEventNotificationVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IRTCEventNotification_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IRTCEventNotification_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IRTCEventNotification_Release(This) (This)->lpVtbl->Release(This)
#define IRTCEventNotification_Event(This,RTCEvent,pEvent) (This)->lpVtbl->Event(This,RTCEvent,pEvent)
#endif
#endif
  HRESULT WINAPI IRTCEventNotification_Event_Proxy(IRTCEventNotification *This,RTC_EVENT RTCEvent,IDispatch *pEvent);
  void __RPC_STUB IRTCEventNotification_Event_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IRTCPortManager_INTERFACE_DEFINED__
#define __IRTCPortManager_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IRTCPortManager;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IRTCPortManager : public IUnknown {
  public:
    virtual HRESULT WINAPI GetMapping(BSTR bstrRemoteAddress,RTC_PORT_TYPE enPortType,BSTR *pbstrInternalLocalAddress,__LONG32 *plInternalLocalPort,BSTR *pbstrExternalLocalAddress,__LONG32 *plExternalLocalPort) = 0;
    virtual HRESULT WINAPI UpdateRemoteAddress(BSTR bstrRemoteAddress,BSTR bstrInternalLocalAddress,__LONG32 lInternalLocalPort,BSTR bstrExternalLocalAddress,__LONG32 lExternalLocalPort) = 0;
    virtual HRESULT WINAPI ReleaseMapping(BSTR bstrInternalLocalAddress,__LONG32 lInternalLocalPort,BSTR bstrExternalLocalAddress,__LONG32 lExternalLocalAddress) = 0;
  };
#else
  typedef struct IRTCPortManagerVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IRTCPortManager *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IRTCPortManager *This);
      ULONG (WINAPI *Release)(IRTCPortManager *This);
      HRESULT (WINAPI *GetMapping)(IRTCPortManager *This,BSTR bstrRemoteAddress,RTC_PORT_TYPE enPortType,BSTR *pbstrInternalLocalAddress,__LONG32 *plInternalLocalPort,BSTR *pbstrExternalLocalAddress,__LONG32 *plExternalLocalPort);
      HRESULT (WINAPI *UpdateRemoteAddress)(IRTCPortManager *This,BSTR bstrRemoteAddress,BSTR bstrInternalLocalAddress,__LONG32 lInternalLocalPort,BSTR bstrExternalLocalAddress,__LONG32 lExternalLocalPort);
      HRESULT (WINAPI *ReleaseMapping)(IRTCPortManager *This,BSTR bstrInternalLocalAddress,__LONG32 lInternalLocalPort,BSTR bstrExternalLocalAddress,__LONG32 lExternalLocalAddress);
    END_INTERFACE
  } IRTCPortManagerVtbl;
  struct IRTCPortManager {
    CONST_VTBL struct IRTCPortManagerVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IRTCPortManager_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IRTCPortManager_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IRTCPortManager_Release(This) (This)->lpVtbl->Release(This)
#define IRTCPortManager_GetMapping(This,bstrRemoteAddress,enPortType,pbstrInternalLocalAddress,plInternalLocalPort,pbstrExternalLocalAddress,plExternalLocalPort) (This)->lpVtbl->GetMapping(This,bstrRemoteAddress,enPortType,pbstrInternalLocalAddress,plInternalLocalPort,pbstrExternalLocalAddress,plExternalLocalPort)
#define IRTCPortManager_UpdateRemoteAddress(This,bstrRemoteAddress,bstrInternalLocalAddress,lInternalLocalPort,bstrExternalLocalAddress,lExternalLocalPort) (This)->lpVtbl->UpdateRemoteAddress(This,bstrRemoteAddress,bstrInternalLocalAddress,lInternalLocalPort,bstrExternalLocalAddress,lExternalLocalPort)
#define IRTCPortManager_ReleaseMapping(This,bstrInternalLocalAddress,lInternalLocalPort,bstrExternalLocalAddress,lExternalLocalAddress) (This)->lpVtbl->ReleaseMapping(This,bstrInternalLocalAddress,lInternalLocalPort,bstrExternalLocalAddress,lExternalLocalAddress)
#endif
#endif
  HRESULT WINAPI IRTCPortManager_GetMapping_Proxy(IRTCPortManager *This,BSTR bstrRemoteAddress,RTC_PORT_TYPE enPortType,BSTR *pbstrInternalLocalAddress,__LONG32 *plInternalLocalPort,BSTR *pbstrExternalLocalAddress,__LONG32 *plExternalLocalPort);
  void __RPC_STUB IRTCPortManager_GetMapping_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCPortManager_UpdateRemoteAddress_Proxy(IRTCPortManager *This,BSTR bstrRemoteAddress,BSTR bstrInternalLocalAddress,__LONG32 lInternalLocalPort,BSTR bstrExternalLocalAddress,__LONG32 lExternalLocalPort);
  void __RPC_STUB IRTCPortManager_UpdateRemoteAddress_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCPortManager_ReleaseMapping_Proxy(IRTCPortManager *This,BSTR bstrInternalLocalAddress,__LONG32 lInternalLocalPort,BSTR bstrExternalLocalAddress,__LONG32 lExternalLocalAddress);
  void __RPC_STUB IRTCPortManager_ReleaseMapping_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IRTCSessionPortManagement_INTERFACE_DEFINED__
#define __IRTCSessionPortManagement_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IRTCSessionPortManagement;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IRTCSessionPortManagement : public IUnknown {
  public:
    virtual HRESULT WINAPI SetPortManager(IRTCPortManager *pPortManager) = 0;
  };
#else
  typedef struct IRTCSessionPortManagementVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IRTCSessionPortManagement *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IRTCSessionPortManagement *This);
      ULONG (WINAPI *Release)(IRTCSessionPortManagement *This);
      HRESULT (WINAPI *SetPortManager)(IRTCSessionPortManagement *This,IRTCPortManager *pPortManager);
    END_INTERFACE
  } IRTCSessionPortManagementVtbl;
  struct IRTCSessionPortManagement {
    CONST_VTBL struct IRTCSessionPortManagementVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IRTCSessionPortManagement_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IRTCSessionPortManagement_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IRTCSessionPortManagement_Release(This) (This)->lpVtbl->Release(This)
#define IRTCSessionPortManagement_SetPortManager(This,pPortManager) (This)->lpVtbl->SetPortManager(This,pPortManager)
#endif
#endif
  HRESULT WINAPI IRTCSessionPortManagement_SetPortManager_Proxy(IRTCSessionPortManagement *This,IRTCPortManager *pPortManager);
  void __RPC_STUB IRTCSessionPortManagement_SetPortManager_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IRTCClientPortManagement_INTERFACE_DEFINED__
#define __IRTCClientPortManagement_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IRTCClientPortManagement;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IRTCClientPortManagement : public IUnknown {
  public:
    virtual HRESULT WINAPI StartListenAddressAndPort(BSTR bstrInternalLocalAddress,__LONG32 lInternalLocalPort) = 0;
    virtual HRESULT WINAPI StopListenAddressAndPort(BSTR bstrInternalLocalAddress,__LONG32 lInternalLocalPort) = 0;
    virtual HRESULT WINAPI GetPortRange(RTC_PORT_TYPE enPortType,__LONG32 *plMinValue,__LONG32 *plMaxValue) = 0;
  };
#else
  typedef struct IRTCClientPortManagementVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IRTCClientPortManagement *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IRTCClientPortManagement *This);
      ULONG (WINAPI *Release)(IRTCClientPortManagement *This);
      HRESULT (WINAPI *StartListenAddressAndPort)(IRTCClientPortManagement *This,BSTR bstrInternalLocalAddress,__LONG32 lInternalLocalPort);
      HRESULT (WINAPI *StopListenAddressAndPort)(IRTCClientPortManagement *This,BSTR bstrInternalLocalAddress,__LONG32 lInternalLocalPort);
      HRESULT (WINAPI *GetPortRange)(IRTCClientPortManagement *This,RTC_PORT_TYPE enPortType,__LONG32 *plMinValue,__LONG32 *plMaxValue);
    END_INTERFACE
  } IRTCClientPortManagementVtbl;
  struct IRTCClientPortManagement {
    CONST_VTBL struct IRTCClientPortManagementVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IRTCClientPortManagement_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IRTCClientPortManagement_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IRTCClientPortManagement_Release(This) (This)->lpVtbl->Release(This)
#define IRTCClientPortManagement_StartListenAddressAndPort(This,bstrInternalLocalAddress,lInternalLocalPort) (This)->lpVtbl->StartListenAddressAndPort(This,bstrInternalLocalAddress,lInternalLocalPort)
#define IRTCClientPortManagement_StopListenAddressAndPort(This,bstrInternalLocalAddress,lInternalLocalPort) (This)->lpVtbl->StopListenAddressAndPort(This,bstrInternalLocalAddress,lInternalLocalPort)
#define IRTCClientPortManagement_GetPortRange(This,enPortType,plMinValue,plMaxValue) (This)->lpVtbl->GetPortRange(This,enPortType,plMinValue,plMaxValue)
#endif
#endif
  HRESULT WINAPI IRTCClientPortManagement_StartListenAddressAndPort_Proxy(IRTCClientPortManagement *This,BSTR bstrInternalLocalAddress,__LONG32 lInternalLocalPort);
  void __RPC_STUB IRTCClientPortManagement_StartListenAddressAndPort_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCClientPortManagement_StopListenAddressAndPort_Proxy(IRTCClientPortManagement *This,BSTR bstrInternalLocalAddress,__LONG32 lInternalLocalPort);
  void __RPC_STUB IRTCClientPortManagement_StopListenAddressAndPort_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCClientPortManagement_GetPortRange_Proxy(IRTCClientPortManagement *This,RTC_PORT_TYPE enPortType,__LONG32 *plMinValue,__LONG32 *plMaxValue);
  void __RPC_STUB IRTCClientPortManagement_GetPortRange_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IRTCUserSearch_INTERFACE_DEFINED__
#define __IRTCUserSearch_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IRTCUserSearch;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IRTCUserSearch : public IUnknown {
  public:
    virtual HRESULT WINAPI CreateQuery(IRTCUserSearchQuery **ppQuery) = 0;
    virtual HRESULT WINAPI ExecuteSearch(IRTCUserSearchQuery *pQuery,IRTCProfile *pProfile,LONG_PTR lCookie) = 0;
  };
#else
  typedef struct IRTCUserSearchVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IRTCUserSearch *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IRTCUserSearch *This);
      ULONG (WINAPI *Release)(IRTCUserSearch *This);
      HRESULT (WINAPI *CreateQuery)(IRTCUserSearch *This,IRTCUserSearchQuery **ppQuery);
      HRESULT (WINAPI *ExecuteSearch)(IRTCUserSearch *This,IRTCUserSearchQuery *pQuery,IRTCProfile *pProfile,LONG_PTR lCookie);
    END_INTERFACE
  } IRTCUserSearchVtbl;
  struct IRTCUserSearch {
    CONST_VTBL struct IRTCUserSearchVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IRTCUserSearch_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IRTCUserSearch_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IRTCUserSearch_Release(This) (This)->lpVtbl->Release(This)
#define IRTCUserSearch_CreateQuery(This,ppQuery) (This)->lpVtbl->CreateQuery(This,ppQuery)
#define IRTCUserSearch_ExecuteSearch(This,pQuery,pProfile,lCookie) (This)->lpVtbl->ExecuteSearch(This,pQuery,pProfile,lCookie)
#endif
#endif
  HRESULT WINAPI IRTCUserSearch_CreateQuery_Proxy(IRTCUserSearch *This,IRTCUserSearchQuery **ppQuery);
  void __RPC_STUB IRTCUserSearch_CreateQuery_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCUserSearch_ExecuteSearch_Proxy(IRTCUserSearch *This,IRTCUserSearchQuery *pQuery,IRTCProfile *pProfile,LONG_PTR lCookie);
  void __RPC_STUB IRTCUserSearch_ExecuteSearch_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IRTCUserSearchQuery_INTERFACE_DEFINED__
#define __IRTCUserSearchQuery_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IRTCUserSearchQuery;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IRTCUserSearchQuery : public IUnknown {
  public:
    virtual HRESULT WINAPI put_SearchTerm(BSTR bstrName,BSTR bstrValue) = 0;
    virtual HRESULT WINAPI get_SearchTerm(BSTR bstrName,BSTR *pbstrValue) = 0;
    virtual HRESULT WINAPI get_SearchTerms(BSTR *pbstrNames) = 0;
    virtual HRESULT WINAPI put_SearchPreference(RTC_USER_SEARCH_PREFERENCE enPreference,__LONG32 lValue) = 0;
    virtual HRESULT WINAPI get_SearchPreference(RTC_USER_SEARCH_PREFERENCE enPreference,__LONG32 *plValue) = 0;
    virtual HRESULT WINAPI put_SearchDomain(BSTR bstrDomain) = 0;
    virtual HRESULT WINAPI get_SearchDomain(BSTR *pbstrDomain) = 0;
  };
#else
  typedef struct IRTCUserSearchQueryVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IRTCUserSearchQuery *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IRTCUserSearchQuery *This);
      ULONG (WINAPI *Release)(IRTCUserSearchQuery *This);
      HRESULT (WINAPI *put_SearchTerm)(IRTCUserSearchQuery *This,BSTR bstrName,BSTR bstrValue);
      HRESULT (WINAPI *get_SearchTerm)(IRTCUserSearchQuery *This,BSTR bstrName,BSTR *pbstrValue);
      HRESULT (WINAPI *get_SearchTerms)(IRTCUserSearchQuery *This,BSTR *pbstrNames);
      HRESULT (WINAPI *put_SearchPreference)(IRTCUserSearchQuery *This,RTC_USER_SEARCH_PREFERENCE enPreference,__LONG32 lValue);
      HRESULT (WINAPI *get_SearchPreference)(IRTCUserSearchQuery *This,RTC_USER_SEARCH_PREFERENCE enPreference,__LONG32 *plValue);
      HRESULT (WINAPI *put_SearchDomain)(IRTCUserSearchQuery *This,BSTR bstrDomain);
      HRESULT (WINAPI *get_SearchDomain)(IRTCUserSearchQuery *This,BSTR *pbstrDomain);
    END_INTERFACE
  } IRTCUserSearchQueryVtbl;
  struct IRTCUserSearchQuery {
    CONST_VTBL struct IRTCUserSearchQueryVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IRTCUserSearchQuery_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IRTCUserSearchQuery_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IRTCUserSearchQuery_Release(This) (This)->lpVtbl->Release(This)
#define IRTCUserSearchQuery_put_SearchTerm(This,bstrName,bstrValue) (This)->lpVtbl->put_SearchTerm(This,bstrName,bstrValue)
#define IRTCUserSearchQuery_get_SearchTerm(This,bstrName,pbstrValue) (This)->lpVtbl->get_SearchTerm(This,bstrName,pbstrValue)
#define IRTCUserSearchQuery_get_SearchTerms(This,pbstrNames) (This)->lpVtbl->get_SearchTerms(This,pbstrNames)
#define IRTCUserSearchQuery_put_SearchPreference(This,enPreference,lValue) (This)->lpVtbl->put_SearchPreference(This,enPreference,lValue)
#define IRTCUserSearchQuery_get_SearchPreference(This,enPreference,plValue) (This)->lpVtbl->get_SearchPreference(This,enPreference,plValue)
#define IRTCUserSearchQuery_put_SearchDomain(This,bstrDomain) (This)->lpVtbl->put_SearchDomain(This,bstrDomain)
#define IRTCUserSearchQuery_get_SearchDomain(This,pbstrDomain) (This)->lpVtbl->get_SearchDomain(This,pbstrDomain)
#endif
#endif
  HRESULT WINAPI IRTCUserSearchQuery_put_SearchTerm_Proxy(IRTCUserSearchQuery *This,BSTR bstrName,BSTR bstrValue);
  void __RPC_STUB IRTCUserSearchQuery_put_SearchTerm_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCUserSearchQuery_get_SearchTerm_Proxy(IRTCUserSearchQuery *This,BSTR bstrName,BSTR *pbstrValue);
  void __RPC_STUB IRTCUserSearchQuery_get_SearchTerm_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCUserSearchQuery_get_SearchTerms_Proxy(IRTCUserSearchQuery *This,BSTR *pbstrNames);
  void __RPC_STUB IRTCUserSearchQuery_get_SearchTerms_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCUserSearchQuery_put_SearchPreference_Proxy(IRTCUserSearchQuery *This,RTC_USER_SEARCH_PREFERENCE enPreference,__LONG32 lValue);
  void __RPC_STUB IRTCUserSearchQuery_put_SearchPreference_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCUserSearchQuery_get_SearchPreference_Proxy(IRTCUserSearchQuery *This,RTC_USER_SEARCH_PREFERENCE enPreference,__LONG32 *plValue);
  void __RPC_STUB IRTCUserSearchQuery_get_SearchPreference_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCUserSearchQuery_put_SearchDomain_Proxy(IRTCUserSearchQuery *This,BSTR bstrDomain);
  void __RPC_STUB IRTCUserSearchQuery_put_SearchDomain_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCUserSearchQuery_get_SearchDomain_Proxy(IRTCUserSearchQuery *This,BSTR *pbstrDomain);
  void __RPC_STUB IRTCUserSearchQuery_get_SearchDomain_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IRTCUserSearchResult_INTERFACE_DEFINED__
#define __IRTCUserSearchResult_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IRTCUserSearchResult;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IRTCUserSearchResult : public IUnknown {
  public:
    virtual HRESULT WINAPI get_Value(RTC_USER_SEARCH_COLUMN enColumn,BSTR *pbstrValue) = 0;
  };
#else
  typedef struct IRTCUserSearchResultVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IRTCUserSearchResult *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IRTCUserSearchResult *This);
      ULONG (WINAPI *Release)(IRTCUserSearchResult *This);
      HRESULT (WINAPI *get_Value)(IRTCUserSearchResult *This,RTC_USER_SEARCH_COLUMN enColumn,BSTR *pbstrValue);
    END_INTERFACE
  } IRTCUserSearchResultVtbl;
  struct IRTCUserSearchResult {
    CONST_VTBL struct IRTCUserSearchResultVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IRTCUserSearchResult_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IRTCUserSearchResult_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IRTCUserSearchResult_Release(This) (This)->lpVtbl->Release(This)
#define IRTCUserSearchResult_get_Value(This,enColumn,pbstrValue) (This)->lpVtbl->get_Value(This,enColumn,pbstrValue)
#endif
#endif
  HRESULT WINAPI IRTCUserSearchResult_get_Value_Proxy(IRTCUserSearchResult *This,RTC_USER_SEARCH_COLUMN enColumn,BSTR *pbstrValue);
  void __RPC_STUB IRTCUserSearchResult_get_Value_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IRTCEnumUserSearchResults_INTERFACE_DEFINED__
#define __IRTCEnumUserSearchResults_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IRTCEnumUserSearchResults;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IRTCEnumUserSearchResults : public IUnknown {
  public:
    virtual HRESULT WINAPI Next(ULONG celt,IRTCUserSearchResult **ppElements,ULONG *pceltFetched) = 0;
    virtual HRESULT WINAPI Reset(void) = 0;
    virtual HRESULT WINAPI Skip(ULONG celt) = 0;
    virtual HRESULT WINAPI Clone(IRTCEnumUserSearchResults **ppEnum) = 0;
  };
#else
  typedef struct IRTCEnumUserSearchResultsVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IRTCEnumUserSearchResults *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IRTCEnumUserSearchResults *This);
      ULONG (WINAPI *Release)(IRTCEnumUserSearchResults *This);
      HRESULT (WINAPI *Next)(IRTCEnumUserSearchResults *This,ULONG celt,IRTCUserSearchResult **ppElements,ULONG *pceltFetched);
      HRESULT (WINAPI *Reset)(IRTCEnumUserSearchResults *This);
      HRESULT (WINAPI *Skip)(IRTCEnumUserSearchResults *This,ULONG celt);
      HRESULT (WINAPI *Clone)(IRTCEnumUserSearchResults *This,IRTCEnumUserSearchResults **ppEnum);
    END_INTERFACE
  } IRTCEnumUserSearchResultsVtbl;
  struct IRTCEnumUserSearchResults {
    CONST_VTBL struct IRTCEnumUserSearchResultsVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IRTCEnumUserSearchResults_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IRTCEnumUserSearchResults_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IRTCEnumUserSearchResults_Release(This) (This)->lpVtbl->Release(This)
#define IRTCEnumUserSearchResults_Next(This,celt,ppElements,pceltFetched) (This)->lpVtbl->Next(This,celt,ppElements,pceltFetched)
#define IRTCEnumUserSearchResults_Reset(This) (This)->lpVtbl->Reset(This)
#define IRTCEnumUserSearchResults_Skip(This,celt) (This)->lpVtbl->Skip(This,celt)
#define IRTCEnumUserSearchResults_Clone(This,ppEnum) (This)->lpVtbl->Clone(This,ppEnum)
#endif
#endif
  HRESULT WINAPI IRTCEnumUserSearchResults_Next_Proxy(IRTCEnumUserSearchResults *This,ULONG celt,IRTCUserSearchResult **ppElements,ULONG *pceltFetched);
  void __RPC_STUB IRTCEnumUserSearchResults_Next_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCEnumUserSearchResults_Reset_Proxy(IRTCEnumUserSearchResults *This);
  void __RPC_STUB IRTCEnumUserSearchResults_Reset_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCEnumUserSearchResults_Skip_Proxy(IRTCEnumUserSearchResults *This,ULONG celt);
  void __RPC_STUB IRTCEnumUserSearchResults_Skip_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCEnumUserSearchResults_Clone_Proxy(IRTCEnumUserSearchResults *This,IRTCEnumUserSearchResults **ppEnum);
  void __RPC_STUB IRTCEnumUserSearchResults_Clone_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IRTCUserSearchResultsEvent_INTERFACE_DEFINED__
#define __IRTCUserSearchResultsEvent_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IRTCUserSearchResultsEvent;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IRTCUserSearchResultsEvent : public IDispatch {
  public:
    virtual HRESULT WINAPI EnumerateResults(IRTCEnumUserSearchResults **ppEnum) = 0;
    virtual HRESULT WINAPI get_Results(IRTCCollection **ppCollection) = 0;
    virtual HRESULT WINAPI get_Profile(IRTCProfile2 **ppProfile) = 0;
    virtual HRESULT WINAPI get_Query(IRTCUserSearchQuery **ppQuery) = 0;
    virtual HRESULT WINAPI get_Cookie(LONG_PTR *plCookie) = 0;
    virtual HRESULT WINAPI get_StatusCode(__LONG32 *plStatusCode) = 0;
    virtual HRESULT WINAPI get_MoreAvailable(VARIANT_BOOL *pfMoreAvailable) = 0;
  };
#else
  typedef struct IRTCUserSearchResultsEventVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IRTCUserSearchResultsEvent *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IRTCUserSearchResultsEvent *This);
      ULONG (WINAPI *Release)(IRTCUserSearchResultsEvent *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IRTCUserSearchResultsEvent *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IRTCUserSearchResultsEvent *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IRTCUserSearchResultsEvent *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IRTCUserSearchResultsEvent *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *EnumerateResults)(IRTCUserSearchResultsEvent *This,IRTCEnumUserSearchResults **ppEnum);
      HRESULT (WINAPI *get_Results)(IRTCUserSearchResultsEvent *This,IRTCCollection **ppCollection);
      HRESULT (WINAPI *get_Profile)(IRTCUserSearchResultsEvent *This,IRTCProfile2 **ppProfile);
      HRESULT (WINAPI *get_Query)(IRTCUserSearchResultsEvent *This,IRTCUserSearchQuery **ppQuery);
      HRESULT (WINAPI *get_Cookie)(IRTCUserSearchResultsEvent *This,LONG_PTR *plCookie);
      HRESULT (WINAPI *get_StatusCode)(IRTCUserSearchResultsEvent *This,__LONG32 *plStatusCode);
      HRESULT (WINAPI *get_MoreAvailable)(IRTCUserSearchResultsEvent *This,VARIANT_BOOL *pfMoreAvailable);
    END_INTERFACE
  } IRTCUserSearchResultsEventVtbl;
  struct IRTCUserSearchResultsEvent {
    CONST_VTBL struct IRTCUserSearchResultsEventVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IRTCUserSearchResultsEvent_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IRTCUserSearchResultsEvent_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IRTCUserSearchResultsEvent_Release(This) (This)->lpVtbl->Release(This)
#define IRTCUserSearchResultsEvent_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IRTCUserSearchResultsEvent_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IRTCUserSearchResultsEvent_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IRTCUserSearchResultsEvent_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IRTCUserSearchResultsEvent_EnumerateResults(This,ppEnum) (This)->lpVtbl->EnumerateResults(This,ppEnum)
#define IRTCUserSearchResultsEvent_get_Results(This,ppCollection) (This)->lpVtbl->get_Results(This,ppCollection)
#define IRTCUserSearchResultsEvent_get_Profile(This,ppProfile) (This)->lpVtbl->get_Profile(This,ppProfile)
#define IRTCUserSearchResultsEvent_get_Query(This,ppQuery) (This)->lpVtbl->get_Query(This,ppQuery)
#define IRTCUserSearchResultsEvent_get_Cookie(This,plCookie) (This)->lpVtbl->get_Cookie(This,plCookie)
#define IRTCUserSearchResultsEvent_get_StatusCode(This,plStatusCode) (This)->lpVtbl->get_StatusCode(This,plStatusCode)
#define IRTCUserSearchResultsEvent_get_MoreAvailable(This,pfMoreAvailable) (This)->lpVtbl->get_MoreAvailable(This,pfMoreAvailable)
#endif
#endif
  HRESULT WINAPI IRTCUserSearchResultsEvent_EnumerateResults_Proxy(IRTCUserSearchResultsEvent *This,IRTCEnumUserSearchResults **ppEnum);
  void __RPC_STUB IRTCUserSearchResultsEvent_EnumerateResults_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCUserSearchResultsEvent_get_Results_Proxy(IRTCUserSearchResultsEvent *This,IRTCCollection **ppCollection);
  void __RPC_STUB IRTCUserSearchResultsEvent_get_Results_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCUserSearchResultsEvent_get_Profile_Proxy(IRTCUserSearchResultsEvent *This,IRTCProfile2 **ppProfile);
  void __RPC_STUB IRTCUserSearchResultsEvent_get_Profile_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCUserSearchResultsEvent_get_Query_Proxy(IRTCUserSearchResultsEvent *This,IRTCUserSearchQuery **ppQuery);
  void __RPC_STUB IRTCUserSearchResultsEvent_get_Query_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCUserSearchResultsEvent_get_Cookie_Proxy(IRTCUserSearchResultsEvent *This,LONG_PTR *plCookie);
  void __RPC_STUB IRTCUserSearchResultsEvent_get_Cookie_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCUserSearchResultsEvent_get_StatusCode_Proxy(IRTCUserSearchResultsEvent *This,__LONG32 *plStatusCode);
  void __RPC_STUB IRTCUserSearchResultsEvent_get_StatusCode_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCUserSearchResultsEvent_get_MoreAvailable_Proxy(IRTCUserSearchResultsEvent *This,VARIANT_BOOL *pfMoreAvailable);
  void __RPC_STUB IRTCUserSearchResultsEvent_get_MoreAvailable_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IRTCSessionReferStatusEvent_INTERFACE_DEFINED__
#define __IRTCSessionReferStatusEvent_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IRTCSessionReferStatusEvent;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IRTCSessionReferStatusEvent : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Session(IRTCSession2 **ppSession) = 0;
    virtual HRESULT WINAPI get_ReferStatus(RTC_SESSION_REFER_STATUS *penReferStatus) = 0;
    virtual HRESULT WINAPI get_StatusCode(__LONG32 *plStatusCode) = 0;
    virtual HRESULT WINAPI get_StatusText(BSTR *pbstrStatusText) = 0;
  };
#else
  typedef struct IRTCSessionReferStatusEventVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IRTCSessionReferStatusEvent *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IRTCSessionReferStatusEvent *This);
      ULONG (WINAPI *Release)(IRTCSessionReferStatusEvent *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IRTCSessionReferStatusEvent *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IRTCSessionReferStatusEvent *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IRTCSessionReferStatusEvent *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IRTCSessionReferStatusEvent *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Session)(IRTCSessionReferStatusEvent *This,IRTCSession2 **ppSession);
      HRESULT (WINAPI *get_ReferStatus)(IRTCSessionReferStatusEvent *This,RTC_SESSION_REFER_STATUS *penReferStatus);
      HRESULT (WINAPI *get_StatusCode)(IRTCSessionReferStatusEvent *This,__LONG32 *plStatusCode);
      HRESULT (WINAPI *get_StatusText)(IRTCSessionReferStatusEvent *This,BSTR *pbstrStatusText);
    END_INTERFACE
  } IRTCSessionReferStatusEventVtbl;
  struct IRTCSessionReferStatusEvent {
    CONST_VTBL struct IRTCSessionReferStatusEventVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IRTCSessionReferStatusEvent_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IRTCSessionReferStatusEvent_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IRTCSessionReferStatusEvent_Release(This) (This)->lpVtbl->Release(This)
#define IRTCSessionReferStatusEvent_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IRTCSessionReferStatusEvent_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IRTCSessionReferStatusEvent_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IRTCSessionReferStatusEvent_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IRTCSessionReferStatusEvent_get_Session(This,ppSession) (This)->lpVtbl->get_Session(This,ppSession)
#define IRTCSessionReferStatusEvent_get_ReferStatus(This,penReferStatus) (This)->lpVtbl->get_ReferStatus(This,penReferStatus)
#define IRTCSessionReferStatusEvent_get_StatusCode(This,plStatusCode) (This)->lpVtbl->get_StatusCode(This,plStatusCode)
#define IRTCSessionReferStatusEvent_get_StatusText(This,pbstrStatusText) (This)->lpVtbl->get_StatusText(This,pbstrStatusText)
#endif
#endif
  HRESULT WINAPI IRTCSessionReferStatusEvent_get_Session_Proxy(IRTCSessionReferStatusEvent *This,IRTCSession2 **ppSession);
  void __RPC_STUB IRTCSessionReferStatusEvent_get_Session_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCSessionReferStatusEvent_get_ReferStatus_Proxy(IRTCSessionReferStatusEvent *This,RTC_SESSION_REFER_STATUS *penReferStatus);
  void __RPC_STUB IRTCSessionReferStatusEvent_get_ReferStatus_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCSessionReferStatusEvent_get_StatusCode_Proxy(IRTCSessionReferStatusEvent *This,__LONG32 *plStatusCode);
  void __RPC_STUB IRTCSessionReferStatusEvent_get_StatusCode_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCSessionReferStatusEvent_get_StatusText_Proxy(IRTCSessionReferStatusEvent *This,BSTR *pbstrStatusText);
  void __RPC_STUB IRTCSessionReferStatusEvent_get_StatusText_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IRTCSessionReferredEvent_INTERFACE_DEFINED__
#define __IRTCSessionReferredEvent_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IRTCSessionReferredEvent;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IRTCSessionReferredEvent : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Session(IRTCSession2 **ppSession) = 0;
    virtual HRESULT WINAPI get_ReferredByURI(BSTR *pbstrReferredByURI) = 0;
    virtual HRESULT WINAPI get_ReferToURI(BSTR *pbstrReferoURI) = 0;
    virtual HRESULT WINAPI get_ReferCookie(BSTR *pbstrReferCookie) = 0;
    virtual HRESULT WINAPI Accept(void) = 0;
    virtual HRESULT WINAPI Reject(void) = 0;
    virtual HRESULT WINAPI SetReferredSessionState(RTC_SESSION_STATE enState) = 0;
  };
#else
  typedef struct IRTCSessionReferredEventVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IRTCSessionReferredEvent *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IRTCSessionReferredEvent *This);
      ULONG (WINAPI *Release)(IRTCSessionReferredEvent *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IRTCSessionReferredEvent *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IRTCSessionReferredEvent *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IRTCSessionReferredEvent *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IRTCSessionReferredEvent *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Session)(IRTCSessionReferredEvent *This,IRTCSession2 **ppSession);
      HRESULT (WINAPI *get_ReferredByURI)(IRTCSessionReferredEvent *This,BSTR *pbstrReferredByURI);
      HRESULT (WINAPI *get_ReferToURI)(IRTCSessionReferredEvent *This,BSTR *pbstrReferoURI);
      HRESULT (WINAPI *get_ReferCookie)(IRTCSessionReferredEvent *This,BSTR *pbstrReferCookie);
      HRESULT (WINAPI *Accept)(IRTCSessionReferredEvent *This);
      HRESULT (WINAPI *Reject)(IRTCSessionReferredEvent *This);
      HRESULT (WINAPI *SetReferredSessionState)(IRTCSessionReferredEvent *This,RTC_SESSION_STATE enState);
    END_INTERFACE
  } IRTCSessionReferredEventVtbl;
  struct IRTCSessionReferredEvent {
    CONST_VTBL struct IRTCSessionReferredEventVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IRTCSessionReferredEvent_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IRTCSessionReferredEvent_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IRTCSessionReferredEvent_Release(This) (This)->lpVtbl->Release(This)
#define IRTCSessionReferredEvent_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IRTCSessionReferredEvent_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IRTCSessionReferredEvent_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IRTCSessionReferredEvent_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IRTCSessionReferredEvent_get_Session(This,ppSession) (This)->lpVtbl->get_Session(This,ppSession)
#define IRTCSessionReferredEvent_get_ReferredByURI(This,pbstrReferredByURI) (This)->lpVtbl->get_ReferredByURI(This,pbstrReferredByURI)
#define IRTCSessionReferredEvent_get_ReferToURI(This,pbstrReferoURI) (This)->lpVtbl->get_ReferToURI(This,pbstrReferoURI)
#define IRTCSessionReferredEvent_get_ReferCookie(This,pbstrReferCookie) (This)->lpVtbl->get_ReferCookie(This,pbstrReferCookie)
#define IRTCSessionReferredEvent_Accept(This) (This)->lpVtbl->Accept(This)
#define IRTCSessionReferredEvent_Reject(This) (This)->lpVtbl->Reject(This)
#define IRTCSessionReferredEvent_SetReferredSessionState(This,enState) (This)->lpVtbl->SetReferredSessionState(This,enState)
#endif
#endif
  HRESULT WINAPI IRTCSessionReferredEvent_get_Session_Proxy(IRTCSessionReferredEvent *This,IRTCSession2 **ppSession);
  void __RPC_STUB IRTCSessionReferredEvent_get_Session_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCSessionReferredEvent_get_ReferredByURI_Proxy(IRTCSessionReferredEvent *This,BSTR *pbstrReferredByURI);
  void __RPC_STUB IRTCSessionReferredEvent_get_ReferredByURI_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCSessionReferredEvent_get_ReferToURI_Proxy(IRTCSessionReferredEvent *This,BSTR *pbstrReferoURI);
  void __RPC_STUB IRTCSessionReferredEvent_get_ReferToURI_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCSessionReferredEvent_get_ReferCookie_Proxy(IRTCSessionReferredEvent *This,BSTR *pbstrReferCookie);
  void __RPC_STUB IRTCSessionReferredEvent_get_ReferCookie_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCSessionReferredEvent_Accept_Proxy(IRTCSessionReferredEvent *This);
  void __RPC_STUB IRTCSessionReferredEvent_Accept_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCSessionReferredEvent_Reject_Proxy(IRTCSessionReferredEvent *This);
  void __RPC_STUB IRTCSessionReferredEvent_Reject_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCSessionReferredEvent_SetReferredSessionState_Proxy(IRTCSessionReferredEvent *This,RTC_SESSION_STATE enState);
  void __RPC_STUB IRTCSessionReferredEvent_SetReferredSessionState_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IRTCSessionDescriptionManager_INTERFACE_DEFINED__
#define __IRTCSessionDescriptionManager_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IRTCSessionDescriptionManager;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IRTCSessionDescriptionManager : public IUnknown {
  public:
    virtual HRESULT WINAPI EvaluateSessionDescription(BSTR bstrContentType,BSTR bstrSessionDescription,VARIANT_BOOL *pfApplicationSession) = 0;
  };
#else
  typedef struct IRTCSessionDescriptionManagerVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IRTCSessionDescriptionManager *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IRTCSessionDescriptionManager *This);
      ULONG (WINAPI *Release)(IRTCSessionDescriptionManager *This);
      HRESULT (WINAPI *EvaluateSessionDescription)(IRTCSessionDescriptionManager *This,BSTR bstrContentType,BSTR bstrSessionDescription,VARIANT_BOOL *pfApplicationSession);
    END_INTERFACE
  } IRTCSessionDescriptionManagerVtbl;
  struct IRTCSessionDescriptionManager {
    CONST_VTBL struct IRTCSessionDescriptionManagerVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IRTCSessionDescriptionManager_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IRTCSessionDescriptionManager_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IRTCSessionDescriptionManager_Release(This) (This)->lpVtbl->Release(This)
#define IRTCSessionDescriptionManager_EvaluateSessionDescription(This,bstrContentType,bstrSessionDescription,pfApplicationSession) (This)->lpVtbl->EvaluateSessionDescription(This,bstrContentType,bstrSessionDescription,pfApplicationSession)
#endif
#endif
  HRESULT WINAPI IRTCSessionDescriptionManager_EvaluateSessionDescription_Proxy(IRTCSessionDescriptionManager *This,BSTR bstrContentType,BSTR bstrSessionDescription,VARIANT_BOOL *pfApplicationSession);
  void __RPC_STUB IRTCSessionDescriptionManager_EvaluateSessionDescription_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IRTCEnumPresenceDevices_INTERFACE_DEFINED__
#define __IRTCEnumPresenceDevices_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IRTCEnumPresenceDevices;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IRTCEnumPresenceDevices : public IUnknown {
  public:
    virtual HRESULT WINAPI Next(ULONG celt,IRTCPresenceDevice **ppElements,ULONG *pceltFetched) = 0;
    virtual HRESULT WINAPI Reset(void) = 0;
    virtual HRESULT WINAPI Skip(ULONG celt) = 0;
    virtual HRESULT WINAPI Clone(IRTCEnumPresenceDevices **ppEnum) = 0;
  };
#else
  typedef struct IRTCEnumPresenceDevicesVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IRTCEnumPresenceDevices *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IRTCEnumPresenceDevices *This);
      ULONG (WINAPI *Release)(IRTCEnumPresenceDevices *This);
      HRESULT (WINAPI *Next)(IRTCEnumPresenceDevices *This,ULONG celt,IRTCPresenceDevice **ppElements,ULONG *pceltFetched);
      HRESULT (WINAPI *Reset)(IRTCEnumPresenceDevices *This);
      HRESULT (WINAPI *Skip)(IRTCEnumPresenceDevices *This,ULONG celt);
      HRESULT (WINAPI *Clone)(IRTCEnumPresenceDevices *This,IRTCEnumPresenceDevices **ppEnum);
    END_INTERFACE
  } IRTCEnumPresenceDevicesVtbl;
  struct IRTCEnumPresenceDevices {
    CONST_VTBL struct IRTCEnumPresenceDevicesVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IRTCEnumPresenceDevices_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IRTCEnumPresenceDevices_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IRTCEnumPresenceDevices_Release(This) (This)->lpVtbl->Release(This)
#define IRTCEnumPresenceDevices_Next(This,celt,ppElements,pceltFetched) (This)->lpVtbl->Next(This,celt,ppElements,pceltFetched)
#define IRTCEnumPresenceDevices_Reset(This) (This)->lpVtbl->Reset(This)
#define IRTCEnumPresenceDevices_Skip(This,celt) (This)->lpVtbl->Skip(This,celt)
#define IRTCEnumPresenceDevices_Clone(This,ppEnum) (This)->lpVtbl->Clone(This,ppEnum)
#endif
#endif
  HRESULT WINAPI IRTCEnumPresenceDevices_Next_Proxy(IRTCEnumPresenceDevices *This,ULONG celt,IRTCPresenceDevice **ppElements,ULONG *pceltFetched);
  void __RPC_STUB IRTCEnumPresenceDevices_Next_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCEnumPresenceDevices_Reset_Proxy(IRTCEnumPresenceDevices *This);
  void __RPC_STUB IRTCEnumPresenceDevices_Reset_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCEnumPresenceDevices_Skip_Proxy(IRTCEnumPresenceDevices *This,ULONG celt);
  void __RPC_STUB IRTCEnumPresenceDevices_Skip_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCEnumPresenceDevices_Clone_Proxy(IRTCEnumPresenceDevices *This,IRTCEnumPresenceDevices **ppEnum);
  void __RPC_STUB IRTCEnumPresenceDevices_Clone_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IRTCPresenceDevice_INTERFACE_DEFINED__
#define __IRTCPresenceDevice_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IRTCPresenceDevice;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IRTCPresenceDevice : public IUnknown {
  public:
    virtual HRESULT WINAPI get_Status(RTC_PRESENCE_STATUS *penStatus) = 0;
    virtual HRESULT WINAPI get_Notes(BSTR *pbstrNotes) = 0;
    virtual HRESULT WINAPI get_PresenceProperty(RTC_PRESENCE_PROPERTY enProperty,BSTR *pbstrProperty) = 0;
    virtual HRESULT WINAPI GetPresenceData(BSTR *pbstrNamespace,BSTR *pbstrData) = 0;
  };
#else
  typedef struct IRTCPresenceDeviceVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IRTCPresenceDevice *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IRTCPresenceDevice *This);
      ULONG (WINAPI *Release)(IRTCPresenceDevice *This);
      HRESULT (WINAPI *get_Status)(IRTCPresenceDevice *This,RTC_PRESENCE_STATUS *penStatus);
      HRESULT (WINAPI *get_Notes)(IRTCPresenceDevice *This,BSTR *pbstrNotes);
      HRESULT (WINAPI *get_PresenceProperty)(IRTCPresenceDevice *This,RTC_PRESENCE_PROPERTY enProperty,BSTR *pbstrProperty);
      HRESULT (WINAPI *GetPresenceData)(IRTCPresenceDevice *This,BSTR *pbstrNamespace,BSTR *pbstrData);
    END_INTERFACE
  } IRTCPresenceDeviceVtbl;
  struct IRTCPresenceDevice {
    CONST_VTBL struct IRTCPresenceDeviceVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IRTCPresenceDevice_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IRTCPresenceDevice_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IRTCPresenceDevice_Release(This) (This)->lpVtbl->Release(This)
#define IRTCPresenceDevice_get_Status(This,penStatus) (This)->lpVtbl->get_Status(This,penStatus)
#define IRTCPresenceDevice_get_Notes(This,pbstrNotes) (This)->lpVtbl->get_Notes(This,pbstrNotes)
#define IRTCPresenceDevice_get_PresenceProperty(This,enProperty,pbstrProperty) (This)->lpVtbl->get_PresenceProperty(This,enProperty,pbstrProperty)
#define IRTCPresenceDevice_GetPresenceData(This,pbstrNamespace,pbstrData) (This)->lpVtbl->GetPresenceData(This,pbstrNamespace,pbstrData)
#endif
#endif
  HRESULT WINAPI IRTCPresenceDevice_get_Status_Proxy(IRTCPresenceDevice *This,RTC_PRESENCE_STATUS *penStatus);
  void __RPC_STUB IRTCPresenceDevice_get_Status_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCPresenceDevice_get_Notes_Proxy(IRTCPresenceDevice *This,BSTR *pbstrNotes);
  void __RPC_STUB IRTCPresenceDevice_get_Notes_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCPresenceDevice_get_PresenceProperty_Proxy(IRTCPresenceDevice *This,RTC_PRESENCE_PROPERTY enProperty,BSTR *pbstrProperty);
  void __RPC_STUB IRTCPresenceDevice_get_PresenceProperty_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTCPresenceDevice_GetPresenceData_Proxy(IRTCPresenceDevice *This,BSTR *pbstrNamespace,BSTR *pbstrData);
  void __RPC_STUB IRTCPresenceDevice_GetPresenceData_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __RTCCORELib_LIBRARY_DEFINED__
#define __RTCCORELib_LIBRARY_DEFINED__
  EXTERN_C const IID LIBID_RTCCORELib;
#ifndef __IRTCDispatchEventNotification_DISPINTERFACE_DEFINED__
#define __IRTCDispatchEventNotification_DISPINTERFACE_DEFINED__
  EXTERN_C const IID DIID_IRTCDispatchEventNotification;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IRTCDispatchEventNotification : public IDispatch {
  };
#else
  typedef struct IRTCDispatchEventNotificationVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IRTCDispatchEventNotification *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IRTCDispatchEventNotification *This);
      ULONG (WINAPI *Release)(IRTCDispatchEventNotification *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IRTCDispatchEventNotification *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IRTCDispatchEventNotification *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IRTCDispatchEventNotification *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IRTCDispatchEventNotification *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
    END_INTERFACE
  } IRTCDispatchEventNotificationVtbl;
  struct IRTCDispatchEventNotification {
    CONST_VTBL struct IRTCDispatchEventNotificationVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IRTCDispatchEventNotification_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IRTCDispatchEventNotification_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IRTCDispatchEventNotification_Release(This) (This)->lpVtbl->Release(This)
#define IRTCDispatchEventNotification_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IRTCDispatchEventNotification_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IRTCDispatchEventNotification_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IRTCDispatchEventNotification_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#endif
#endif
#endif

  EXTERN_C const CLSID CLSID_RTCClient;
#ifdef __cplusplus
  class RTCClient;
#endif
#endif

  ULONG __RPC_API BSTR_UserSize(ULONG *,ULONG,BSTR *);
  unsigned char *__RPC_API BSTR_UserMarshal(ULONG *,unsigned char *,BSTR *);
  unsigned char *__RPC_API BSTR_UserUnmarshal(ULONG *,unsigned char *,BSTR *);
  void __RPC_API BSTR_UserFree(ULONG *,BSTR *);
  ULONG __RPC_API VARIANT_UserSize(ULONG *,ULONG,VARIANT *);
  unsigned char *__RPC_API VARIANT_UserMarshal(ULONG *,unsigned char *,VARIANT *);
  unsigned char *__RPC_API VARIANT_UserUnmarshal(ULONG *,unsigned char *,VARIANT *);
  void __RPC_API VARIANT_UserFree(ULONG *,VARIANT *);

#ifdef __cplusplus
}
#endif
#endif
