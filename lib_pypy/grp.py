
""" This module provides ctypes version of cpython's grp module
"""

import os
from _pwdgrp_cffi import ffi, lib
import _structseq
import _thread
_lock = _thread.allocate_lock()

try: from __pypy__ import builtinify
except ImportError: builtinify = lambda f: f


class struct_group(metaclass=_structseq.structseqtype):
    name = "grp.struct_group"

    gr_name   = _structseq.structseqfield(0)
    gr_passwd = _structseq.structseqfield(1)
    gr_gid    = _structseq.structseqfield(2)
    gr_mem    = _structseq.structseqfield(3)


def _group_from_gstruct(res):
    i = 0
    members = []
    while res.gr_mem[i]:
        members.append(os.fsdecode(ffi.string(res.gr_mem[i])))
        i += 1
    return struct_group([
        os.fsdecode(ffi.string(res.gr_name)),
        os.fsdecode(ffi.string(res.gr_passwd)),
        res.gr_gid,
        members])

@builtinify
def getgrgid(gid):
    with _lock:
        try:
            res = lib.getgrgid(gid)
        except TypeError:
            gid = int(gid)
            res = lib.getgrgid(gid)
            import warnings
            warnings.warn("group id must be int", DeprecationWarning)
        if not res:
            # XXX maybe check error eventually
            raise KeyError(gid)
        return _group_from_gstruct(res)

@builtinify
def getgrnam(name):
    if not isinstance(name, str):
        raise TypeError("expected string")
    name_b = os.fsencode(name)
    if b'\0' in name_b:
        raise ValueError("embedded null byte")
    with _lock:
        res = lib.getgrnam(name_b)
        if not res:
            raise KeyError("getgrnam(): name not found: %s" % name)
        return _group_from_gstruct(res)

@builtinify
def getgrall():
    lst = []
    with _lock:
        lib.setgrent()
        while 1:
            p = lib.getgrent()
            if not p:
                break
            lst.append(_group_from_gstruct(p))
        lib.endgrent()
    return lst

__all__ = ('struct_group', 'getgrgid', 'getgrnam', 'getgrall')

if __name__ == "__main__":
    from os import getgid
    gid = getgid()
    pw = getgrgid(gid)
    print("gid %s: %s" % (pw.gr_gid, pw))
    name = pw.gr_name
    print("name %r: %s" % (name, getgrnam(name)))
    print("All:")
    for pw in getgrall():
        print(pw)
