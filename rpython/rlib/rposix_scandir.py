from rpython.rlib import rposix, rwin32
from rpython.rlib.objectmodel import specialize
from rpython.rtyper.lltypesystem import lltype, rffi
from rpython.rlib.rarithmetic import intmask


if not rwin32.WIN32:
    @specialize.argtype(0)
    def opendir(path, lgt):
        # path will always be ascii utf8, so ignore lgt
        path = rposix._as_bytes0(path)
        return opendir_bytes(path)

    def opendir_bytes(path):
        dirp = rposix.c_opendir(path)
        if not dirp:
            raise OSError(rposix.get_saved_errno(), "opendir failed")
        return dirp

    def closedir(dirp):
        rposix.c_closedir(dirp)

    NULL_DIRP = lltype.nullptr(rposix.DIRP.TO)

    def nextentry(dirp):
        """Read the next entry and returns an opaque object.
        Use the methods has_xxx() and get_xxx() to read from that
        opaque object.  The opaque object is valid until the next
        time nextentry() or closedir() is called.  This may raise
        OSError, or return a NULL pointer when exhausted.  Note
        that this doesn't filter out the "." and ".." entries.
        """
        direntp = rposix.c_readdir(dirp)
        if direntp:
            error = rposix.get_saved_errno()
            if error:
                raise OSError(error, "readdir failed")
        return direntp

    def get_name_bytes(direntp):
        namep = rffi.cast(rffi.CCHARP, direntp.c_d_name)
        return rffi.charp2str(namep)

    DT_UNKNOWN = rposix.dirent_config.get('DT_UNKNOWN', 0)
    DT_REG = rposix.dirent_config.get('DT_REG', 255)
    DT_DIR = rposix.dirent_config.get('DT_DIR', 255)
    DT_LNK = rposix.dirent_config.get('DT_LNK', 255)

    def get_known_type(direntp):
        if rposix.HAVE_D_TYPE:
            return rffi.getintfield(direntp, 'c_d_type')
        return DT_UNKNOWN

    def get_inode(direntp):
        return rffi.getintfield(direntp, 'c_d_ino')

else:
    # ----- Win32 version -----
    import stat
    from rpython.rlib._os_support import unicode_traits, string_traits
    from rpython.rlib.rwin32file import make_win32_traits
    from rpython.rlib import rposix_stat

    win32traits = make_win32_traits(unicode_traits)


    SCANDIRP = lltype.Ptr(lltype.Struct('SCANDIRP',
        ('filedata', win32traits.WIN32_FIND_DATA),
        ('hFindFile', rwin32.HANDLE),
        ('first_time', lltype.Bool),
        ))
    NULL_DIRP = lltype.nullptr(SCANDIRP.TO)


    # must only be called with utf-8, codepoints!
    def opendir(path, lgt):
        if lgt == 0:
            path = '.'
        if path[-1] not in ('\\', '/', ':'):
            mask = path + '\\*.*'
            lgt += 4
        else:
            mask = path + '*.*'
            lgt += 3
        dirp = lltype.malloc(SCANDIRP.TO, flavor='raw')
        with rffi.scoped_utf82wcharp(mask, lgt) as src_buf:
            hFindFile = win32traits.FindFirstFile(src_buf, dirp.filedata)
        if hFindFile == rwin32.INVALID_HANDLE_VALUE:
            error = rwin32.GetLastError_saved()
            lltype.free(dirp, flavor='raw')
            raise WindowsError(error,  "FindFirstFileW failed")
        dirp.hFindFile = hFindFile
        dirp.first_time = True
        return dirp

    def closedir(dirp):
        if dirp.hFindFile != rwin32.INVALID_HANDLE_VALUE:
            win32traits.FindClose(dirp.hFindFile)
        lltype.free(dirp, flavor='raw')

    def nextentry(dirp):
        """Read the next entry and returns an opaque object.
        Use the methods has_xxx() and get_xxx() to read from that
        opaque object.  The opaque object is valid until the next
        time nextentry() or closedir() is called.  This may raise
        WindowsError, or return NULL when exhausted.  Note
        that this doesn't filter out the "." and ".." entries.
        """
        if dirp.first_time:
            dirp.first_time = False
        else:
            if not win32traits.FindNextFile(dirp.hFindFile, dirp.filedata):
                # error or no more files
                error = rwin32.GetLastError_saved()
                if error == win32traits.ERROR_NO_MORE_FILES:
                    return lltype.nullptr(win32traits.WIN32_FIND_DATA)
                raise WindowsError(error,  "FindNextFileW failed")
        return dirp.filedata

    def get_name_unicode(filedata):
        return unicode_traits.charp2str(rffi.cast(unicode_traits.CCHARP,
                                                  filedata.c_cFileName))

    def get_name_bytes(filedata):
        wcharp = rffi.cast(unicode_traits.CCHARP, filedata.c_cFileName)
        utf8, i = rffi.wcharp2utf8(wcharp)
        return utf8

    def get_known_type(filedata):
        attr = filedata.c_dwFileAttributes
        st_mode = rposix_stat.win32_attributes_to_mode(win32traits, attr)
        return stat.S_IFMT(st_mode)

    def get_inode(filedata):
        return None
