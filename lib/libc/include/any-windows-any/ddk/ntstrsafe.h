/*
 * PROJECT:         ReactOS Kernel
 * LICENSE:         This file is in the public domain.
 * FILE:            include/ddk/ntstrsafe.h
 * PURPOSE:         Safe String Library for NT Code (Native/Kernel)
 * PROGRAMMERS:     Alex Ionescu (alex.ionescu@reactos.org)
 */

/* INCLUDES ******************************************************************/

#ifndef _NTSTRSAFE_H_INCLUDED_
#define _NTSTRSAFE_H_INCLUDED_

//
// Dependencies
//
#include <stdio.h>
#include <string.h>
#include <stdarg.h>

//
// Maximum limits: allow overriding the maximum
//
#ifndef NTSTRSAFE_MAX_CCH
#define NTSTRSAFE_MAX_CCH       2147483647
#endif
#define NTSTRSAFE_MAX_LENGTH    (NTSTRSAFE_MAX_CCH - 1)

//
// Typedefs
//
typedef ULONG DWORD;

/* PRIVATE FUNCTIONS *********************************************************/

static __inline
NTSTATUS
NTAPI
RtlStringLengthWorkerA(IN LPCSTR String,
                       IN SIZE_T MaxLength,
                       OUT PSIZE_T ReturnLength OPTIONAL)
{
    NTSTATUS Status = STATUS_SUCCESS;
    SIZE_T LocalMax = MaxLength;

    while (MaxLength && (*String != ANSI_NULL))
    {
        String++;
        MaxLength--;
    }

    if (!MaxLength) Status = STATUS_INVALID_PARAMETER;

    if (ReturnLength)
    {
        if (NT_SUCCESS(Status))
        {
            *ReturnLength = LocalMax - MaxLength;
        }
        else
        {
            *ReturnLength = 0;
        }
    }

    return Status;
}

static __inline
NTSTATUS
NTAPI
RtlStringValidateDestA(IN LPSTR Destination,
                       IN SIZE_T Length,
                       OUT PSIZE_T ReturnLength OPTIONAL,
                       IN SIZE_T MaxLength)
{
    NTSTATUS Status = STATUS_SUCCESS;

    if (!(Length) || (Length > MaxLength)) Status = STATUS_INVALID_PARAMETER;

    if (ReturnLength)
    {
        if (NT_SUCCESS(Status))
        {
            Status = RtlStringLengthWorkerA(Destination,
                                            Length,
                                            ReturnLength);
        }
        else
        {
            *ReturnLength = 0;
        }
    }

    return Status;
}

static __inline
NTSTATUS
NTAPI
RtlStringExValidateDestA(IN OUT LPSTR *Destination,
                         IN OUT PSIZE_T DestinationLength,
                         OUT PSIZE_T ReturnLength OPTIONAL,
                         IN SIZE_T MaxLength,
                         IN DWORD Flags)
{
    ASSERTMSG("We don't support Extended Flags yet!\n", Flags == 0);
    return RtlStringValidateDestA(*Destination,
                                  *DestinationLength,
                                  ReturnLength,
                                  MaxLength);
}

static __inline
NTSTATUS
NTAPI
RtlStringExValidateSrcA(IN OUT LPCSTR *Source OPTIONAL,
                        IN OUT PSIZE_T ReturnLength OPTIONAL,
                        IN SIZE_T MaxLength,
                        IN DWORD Flags)
{
    NTSTATUS Status = STATUS_SUCCESS;
    ASSERTMSG("We don't support Extended Flags yet!\n", Flags == 0);

    if ((ReturnLength) && (*ReturnLength >= MaxLength))
    {
        Status = STATUS_INVALID_PARAMETER;
    }

    return Status;
}

static __inline
NTSTATUS
NTAPI
RtlStringVPrintfWorkerA(OUT LPSTR Destination,
                        IN SIZE_T Length,
                        OUT PSIZE_T NewLength OPTIONAL,
                        IN LPCSTR Format,
                        IN va_list argList)
{
    NTSTATUS Status = STATUS_SUCCESS;
    LONG Return;
    SIZE_T MaxLength, LocalNewLength = 0;

    MaxLength = Length - 1;

    Return = _vsnprintf(Destination, MaxLength, Format, argList);
    if ((Return < 0) || ((SIZE_T)Return > MaxLength))
    {
        Destination += MaxLength;
        *Destination = ANSI_NULL;

        LocalNewLength = MaxLength;

        Status = STATUS_BUFFER_OVERFLOW;
    }
    else if ((SIZE_T)Return == MaxLength)
    {
        Destination += MaxLength;
        *Destination = ANSI_NULL;

        LocalNewLength = MaxLength;
    }
    else
    {
        LocalNewLength = Return;
    }

    if (NewLength) *NewLength = LocalNewLength;
    return Status;
}

static __inline
NTSTATUS
NTAPI
RtlStringCopyWorkerA(OUT LPSTR Destination,
                     IN SIZE_T Length,
                     OUT PSIZE_T NewLength OPTIONAL,
                     IN LPCSTR Source,
                     IN SIZE_T CopyLength)
{
    NTSTATUS Status = STATUS_SUCCESS;
    SIZE_T LocalNewLength = 0;

    while ((Length) && (CopyLength) && (*Source != ANSI_NULL))
    {
        *Destination++ = *Source++;
        Length--;
        CopyLength--;

        LocalNewLength++;
    }

    if (!Length)
    {
        Destination--;
        LocalNewLength--;

        Status = STATUS_BUFFER_OVERFLOW;
    }

    *Destination = ANSI_NULL;

    if (NewLength) *NewLength = LocalNewLength;
    return Status;
}

/* PUBLIC FUNCTIONS **********************************************************/

static __inline
NTSTATUS
NTAPI
RtlStringCchCopyA(IN LPSTR Destination,
                  IN SIZE_T cchDest,
                  IN LPCSTR pszSrc)
{
    ASSERTMSG("RtlStringCchCopyA is UNIMPLEMENTED!\n", FALSE);
    return STATUS_NOT_IMPLEMENTED;
}

static __inline
NTSTATUS
RtlStringCbPrintfA(OUT LPSTR Destination,
                   IN SIZE_T Length,
                   IN LPCSTR Format,
                   ...)
{
    NTSTATUS Status;
    SIZE_T CharLength = Length / sizeof(CHAR);
    va_list argList;

    Status = RtlStringValidateDestA(Destination,
                                    CharLength,
                                    NULL,
                                    NTSTRSAFE_MAX_CCH);
    if (NT_SUCCESS(Status))
    {
        va_start(argList, Format);
        Status = RtlStringVPrintfWorkerA(Destination,
                                         CharLength,
                                         NULL,
                                         Format,
                                         argList);
        va_end(argList);
    }

    return Status;
}

static __inline
NTSTATUS
RtlStringCbPrintfExA(OUT LPSTR Destination,
                     IN SIZE_T Length,
                     OUT LPSTR *DestinationEnd OPTIONAL,
                     OUT PSIZE_T RemainingSize OPTIONAL,
                     IN DWORD Flags,
                     IN LPCSTR Format,
                     ...)
{
    NTSTATUS Status;
    SIZE_T CharLength = Length / sizeof(CHAR), Remaining, LocalNewLength = 0;
    PCHAR LocalDestinationEnd;
    va_list argList;
    ASSERTMSG("We don't support Extended Flags yet!\n", Flags == 0);

    Status = RtlStringExValidateDestA(&Destination,
                                      &CharLength,
                                      NULL,
                                      NTSTRSAFE_MAX_CCH,
                                      Flags);
    if (NT_SUCCESS(Status))
    {
        LocalDestinationEnd = Destination;
        Remaining = CharLength;

        Status = RtlStringExValidateSrcA(&Format,
                                         NULL,
                                         NTSTRSAFE_MAX_CCH,
                                         Flags);
        if (NT_SUCCESS(Status))
        {
            if (!Length)
            {
                if (*Format != ANSI_NULL)
                {
                    if (!Destination)
                    {
                        Status = STATUS_INVALID_PARAMETER;
                    }
                    else
                    {
                        Status = STATUS_BUFFER_OVERFLOW;
                    }
                }
            }
            else
            {
                va_start(argList, Format);
                Status = RtlStringVPrintfWorkerA(Destination,
                                                 CharLength,
                                                 &LocalNewLength,
                                                 Format,
                                                 argList);
                va_end(argList);

                LocalDestinationEnd = Destination + LocalNewLength;
                Remaining = CharLength - LocalNewLength;
            }
        }
        else
        {
            if (Length) *Destination = ANSI_NULL;
        }

        if ((NT_SUCCESS(Status)) || (Status == STATUS_BUFFER_OVERFLOW))
        {
            if (DestinationEnd) *DestinationEnd = LocalDestinationEnd;

            if (RemainingSize)
            {
                *RemainingSize = (Remaining * sizeof(CHAR)) +
                                 (Length % sizeof(CHAR));
            }
        }
    }

    return Status;
}

static __inline
NTSTATUS
NTAPI
RtlStringCbCopyExA(OUT LPSTR Destination,
                   IN SIZE_T Length,
                   IN LPCSTR Source,
                   OUT LPSTR *DestinationEnd OPTIONAL,
                   OUT PSIZE_T RemainingSize OPTIONAL,
                   IN DWORD Flags)
{
    NTSTATUS Status;
    SIZE_T CharLength = Length / sizeof(CHAR), Copied = 0, Remaining;
    PCHAR LocalDestinationEnd;
    ASSERTMSG("We don't support Extended Flags yet!\n", Flags == 0);

    Status = RtlStringExValidateDestA(&Destination,
                                      &Length,
                                      NULL,
                                      NTSTRSAFE_MAX_CCH,
                                      Flags);
    if (NT_SUCCESS(Status))
    {
        LocalDestinationEnd = Destination;
        Remaining = CharLength;

        Status = RtlStringExValidateSrcA(&Source,
                                         NULL,
                                         NTSTRSAFE_MAX_CCH,
                                         Flags);
        if (NT_SUCCESS(Status))
        {
            if (!CharLength)
            {
                if (*Source != ANSI_NULL)
                {
                    if (!Destination)
                    {
                        Status = STATUS_INVALID_PARAMETER;
                    }
                    else
                    {
                        Status = STATUS_BUFFER_OVERFLOW;
                    }
                }
            }
            else
            {
                Status = RtlStringCopyWorkerA(Destination,
                                              CharLength,
                                              &Copied,
                                              Source,
                                              NTSTRSAFE_MAX_LENGTH);

                LocalDestinationEnd = Destination + Copied;
                Remaining = CharLength - Copied;
            }
        }
        else
        {
            if (CharLength) *Destination = ANSI_NULL;
        }

        if ((NT_SUCCESS(Status)) || (Status == STATUS_BUFFER_OVERFLOW))
        {
            if (DestinationEnd) *DestinationEnd = LocalDestinationEnd;

            if (RemainingSize)
            {
                *RemainingSize = (Remaining * sizeof(CHAR)) +
                                 (Length % sizeof(CHAR));
            }
        }
    }

    return Status;
}

static __inline
NTSTATUS
RtlStringCbPrintfW(
    LPWSTR pszDest,
    IN size_t cbDest,
    IN LPCWSTR pszFormat,
    ...)
{
    ASSERTMSG("RtlStringCbPrintfW is UNIMPLEMENTED!\n", FALSE);
    return STATUS_NOT_IMPLEMENTED;
}

static __inline
NTSTATUS
NTAPI
RtlStringCbCatExA(IN OUT LPSTR Destination,
                  IN SIZE_T Length,
                  IN LPCSTR Source,
                  OUT LPSTR *DestinationEnd OPTIONAL,
                  OUT PSIZE_T RemainingSize OPTIONAL,
                  IN DWORD Flags)
{
    NTSTATUS Status;
    SIZE_T CharLength = Length / sizeof(CHAR);
    SIZE_T DestinationLength, Remaining, Copied = 0;
    PCHAR LocalDestinationEnd;
    ASSERTMSG("We don't support Extended Flags yet!\n", Flags == 0);

    Status = RtlStringExValidateDestA(&Destination,
                                      &CharLength,
                                      &DestinationLength,
                                      NTSTRSAFE_MAX_CCH,
                                      Flags);
    if (NT_SUCCESS(Status))
    {
        LocalDestinationEnd = Destination + DestinationLength;
        Remaining = CharLength - DestinationLength;

        Status = RtlStringExValidateSrcA(&Source,
                                         NULL,
                                         NTSTRSAFE_MAX_CCH,
                                         Flags);
        if (NT_SUCCESS(Status))
        {
            if (Remaining <= 1)
            {
                if (*Source != ANSI_NULL)
                {
                    if (!Destination)
                    {
                        Status = STATUS_INVALID_PARAMETER;
                    }
                    else
                    {
                        Status = STATUS_BUFFER_OVERFLOW;
                    }
                }
            }
            else
            {
                Status = RtlStringCopyWorkerA(LocalDestinationEnd,
                                              Remaining,
                                              &Copied,
                                              Source,
                                              NTSTRSAFE_MAX_LENGTH);

                LocalDestinationEnd = LocalDestinationEnd + Copied;
                Remaining = Remaining - Copied;
            }
        }

        if ((NT_SUCCESS(Status)) || (Status == STATUS_BUFFER_OVERFLOW))
        {
            if (DestinationEnd) *DestinationEnd = LocalDestinationEnd;

            if (RemainingSize)
            {
                *RemainingSize = (Remaining * sizeof(CHAR)) +
                                 (Length % sizeof(CHAR));
            }
        }
    }

    return Status;
}

static __inline
NTSTATUS
NTAPI
RtlStringCbCopyA(OUT LPSTR Destination,
                 IN SIZE_T Length,
                 IN LPCSTR Source)
{
    NTSTATUS Status;
    SIZE_T CharLength = Length / sizeof(CHAR);

    Status = RtlStringValidateDestA(Destination,
                                    CharLength,
                                    NULL,
                                    NTSTRSAFE_MAX_CCH);
    if (NT_SUCCESS(Status))
    {
        Status = RtlStringCopyWorkerA(Destination,
                                      CharLength,
                                      NULL,
                                      Source,
                                      NTSTRSAFE_MAX_LENGTH);
    }

    return Status;
}

#endif /* _NTSTRSAFE_H_INCLUDED_ */

