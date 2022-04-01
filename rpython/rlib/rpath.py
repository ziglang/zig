"""
Minimal (and limited) RPython version of some functions contained in os.path.
"""

import os, stat
from rpython.rlib import rposix
from rpython.rlib.signature import signature
from rpython.rlib.rstring import assert_str0
from rpython.annotator.model import s_Str0


# ____________________________________________________________
#
# Generic implementations in RPython for both POSIX and NT
#

def risdir(s):
    """Return true if the pathname refers to an existing directory."""
    try:
        st = os.stat(s)
    except OSError:
        return False
    return stat.S_ISDIR(st.st_mode)


# ____________________________________________________________
#
# POSIX-only implementations
#

def _posix_risabs(s):
    """Test whether a path is absolute"""
    return s.startswith('/')

@signature(s_Str0, returns=s_Str0)
def _posix_rnormpath(path):
    """Normalize path, eliminating double slashes, etc."""
    slash, dot = '/', '.'
    assert_str0(dot)
    if path == '':
        return dot
    initial_slashes = path.startswith('/')
    # POSIX allows one or two initial slashes, but treats three or more
    # as single slash.
    if (initial_slashes and
        path.startswith('//') and not path.startswith('///')):
        initial_slashes = 2
    comps = path.split('/')
    new_comps = []
    for comp in comps:
        if comp == '' or comp == '.':
            continue
        if (comp != '..' or (not initial_slashes and not new_comps) or
             (new_comps and new_comps[-1] == '..')):
            new_comps.append(comp)
        elif new_comps:
            new_comps.pop()
    comps = new_comps
    path = slash.join(comps)
    if initial_slashes:
        path = slash*initial_slashes + path
    assert_str0(path)
    return path or dot

@signature(s_Str0, returns=s_Str0)
def _posix_rabspath(path):
    """Return an absolute, **non-normalized** path.
      **This version does not let exceptions propagate.**"""
    try:
        if not _posix_risabs(path):
            cwd = os.getcwd()
            path = _posix_rjoin(cwd, path)
        assert path is not None
        return _posix_rnormpath(path)
    except OSError:
        return path

def _posix_rjoin(a, b):
    """Join two pathname components, inserting '/' as needed.
    If the second component is an absolute path, the first one
    will be discarded.  An empty last part will result in a path that
    ends with a separator."""
    path = a
    if b.startswith('/'):
        path = b
    elif path == '' or path.endswith('/'):
        path +=  b
    else:
        path += '/' + b
    return path


# ____________________________________________________________
#
# NT-only implementations
#

def _nt_risabs(s):
    """Test whether a path is absolute"""
    s = _nt_rsplitdrive(s)[1]
    return s.startswith('/') or s.startswith('\\')

def _nt_rnormpath(path):
    """Normalize path, eliminating double slashes, etc."""
    backslash, dot = '\\', '.'
    if path.startswith(('\\\\.\\', '\\\\?\\')):
        # in the case of paths with these prefixes:
        # \\.\ -> device names
        # \\?\ -> literal paths
        # do not do any normalization, but return the path unchanged
        return path
    path = path.replace("/", "\\")
    prefix, path = _nt_rsplitdrive(path)
    # We need to be careful here. If the prefix is empty, and the path starts
    # with a backslash, it could either be an absolute path on the current
    # drive (\dir1\dir2\file) or a UNC filename (\\server\mount\dir1\file). It
    # is therefore imperative NOT to collapse multiple backslashes blindly in
    # that case.
    # The code below preserves multiple backslashes when there is no drive
    # letter. This means that the invalid filename \\\a\b is preserved
    # unchanged, where a\\\b is normalised to a\b. It's not clear that there
    # is any better behaviour for such edge cases.
    if prefix == '':
        # No drive letter - preserve initial backslashes
        while path.startswith("\\"):
            prefix = prefix + backslash
            path = path[1:]
    else:
        # We have a drive letter - collapse initial backslashes
        if path.startswith("\\"):
            prefix = prefix + backslash
            path = path.lstrip("\\")
    comps = path.split("\\")
    i = 0
    while i < len(comps):
        if comps[i] in ('.', ''):
            del comps[i]
        elif comps[i] == '..':
            if i > 0 and comps[i-1] != '..':
                del comps[i-1:i+1]
                i -= 1
            elif i == 0 and prefix.endswith("\\"):
                del comps[i]
            else:
                i += 1
        else:
            i += 1
    # If the path is now empty, substitute '.'
    if not prefix and not comps:
        comps.append(dot)
    return prefix + backslash.join(comps)

@signature(s_Str0, returns=s_Str0)
def _nt_rabspath(path):
    try:
        if path == '':
            path = os.getcwd()
        return rposix.getfullpathname(path)
    except OSError:
        return path

def _nt_rsplitdrive(p):
    """Split a pathname into drive/UNC sharepoint and relative path
    specifiers.
    Returns a 2-tuple (drive_or_unc, path); either part may be empty.
    """
    if len(p) > 1:
        normp = p.replace(altsep, sep)
        if normp.startswith('\\\\') and not normp.startswith('\\\\\\'):
            # is a UNC path:
            # vvvvvvvvvvvvvvvvvvvv drive letter or UNC path
            # \\machine\mountpoint\directory\etc\...
            #           directory ^^^^^^^^^^^^^^^
            index = normp.find('\\', 2)
            if index < 0:
                return '', p
            index2 = normp.find('\\', index + 1)
            # a UNC path can't have two slashes in a row
            # (after the initial two)
            if index2 == index + 1:
                return '', p
            if index2 < 0:
                index2 = len(p)
            return p[:index2], p[index2:]
        if normp[1] == ':':
            return p[:2], p[2:]
    return '', p

def _nt_rjoin(path, p):
    """Join two or more pathname components, inserting "\\" as needed."""
    result_drive, result_path = _nt_rsplitdrive(path)
    p_drive, p_path = _nt_rsplitdrive(p)
    p_is_rel = True
    if p_path and p_path[0] in '\\/':
        # Second path is absolute
        if p_drive or not result_drive:
            result_drive = p_drive
        result_path = p_path
        p_is_rel = False
    elif p_drive and p_drive != result_drive:
        if p_drive.lower() != result_drive.lower():
            # Different drives => ignore the first path entirely
            result_drive = p_drive
            result_path = p_path
            p_is_rel = False
        else:
            # Same drive in different case
            result_drive = p_drive
    if p_is_rel:
        # Second path is relative to the first
        if result_path and result_path[-1] not in '\\/':
            result_path = result_path + '\\'
        result_path = result_path + p_path
    ## add separator between UNC and non-absolute path
    if (result_path and result_path[0] not in '\\/' and
        result_drive and result_drive[-1] != ':'):
        return result_drive + '\\' + result_path
    return result_drive + result_path


# ____________________________________________________________


if os.name == 'posix':
    sep = altsep = '/'
    risabs      = _posix_risabs
    rnormpath   = _posix_rnormpath
    rabspath    = _posix_rabspath
    rjoin       = _posix_rjoin
elif os.name == 'nt':
    sep, altsep = '\\', '/'
    risabs      = _nt_risabs
    rnormpath   = _nt_rnormpath
    rabspath    = _nt_rabspath
    rsplitdrive = _nt_rsplitdrive
    rjoin       = _nt_rjoin
else:
    raise ImportError('Unsupported os: %s' % os.name)
