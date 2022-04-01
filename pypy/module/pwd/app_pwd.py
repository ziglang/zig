from _structseq import structseqtype, structseqfield

class struct_passwd(metaclass=structseqtype):
    """
    pwd.struct_passwd: Results from getpw*() routines.

    This object may be accessed either as a tuple of
      (pw_name,pw_passwd,pw_uid,pw_gid,pw_gecos,pw_dir,pw_shell)
    or via the object attributes as named in the above tuple.
    """
    name = "pwd.struct_passwd"

    pw_name   = structseqfield(0, "user name")
    pw_passwd = structseqfield(1, "password")
    pw_uid    = structseqfield(2, "user id")
    pw_gid    = structseqfield(3, "group id")
    pw_gecos  = structseqfield(4, "real name")
    pw_dir    = structseqfield(5, "home directory")
    pw_shell  = structseqfield(6, "shell program")
