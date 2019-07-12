/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef EXCHFORM_H
#define EXCHFORM_H

#define EXCHIVERB_OPEN 0
#define EXCHIVERB_RESERVED_COMPOSE 100
#define EXCHIVERB_RESERVED_OPEN 101
#define EXCHIVERB_REPLYTOSENDER 102
#define EXCHIVERB_REPLYTOALL 103
#define EXCHIVERB_FORWARD 104
#define EXCHIVERB_PRINT 105
#define EXCHIVERB_SAVEAS 106
#define EXCHIVERB_RESERVED_DELIVERY 107
#define EXCHIVERB_REPLYTOFOLDER 108

#define DEFINE_EXCHFORMGUID(name,b) DEFINE_GUID(name,0x00020D00 | (b),0,0,0xC0,0,0,0,0,0,0,0x46)

#ifndef NOEXCHFORMGUIDS
DEFINE_EXCHFORMGUID(PS_EXCHFORM,0x0C);
#endif

#define psOpMap PS_EXCHFORM
#define ulKindOpMap MNID_ID
#define lidOpMap 1
#define ptOpMap PT_STRING8

#define ichOpMapReservedCompose 0
#define ichOpMapOpen 1
#define ichOpMapReplyToSender 2
#define ichOpMapReplyToAll 3
#define ichOpMapForward 4
#define ichOpMapPrint 5
#define ichOpMapSaveAs 6
#define ichOpMapReservedDelivery 7
#define ichOpMapReplyToFolder 8

#define chOpMapByClient '0'
#define chOpMapByForm '1'
#define chOpMapDisable '2'
#endif
