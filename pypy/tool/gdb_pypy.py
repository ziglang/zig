"""
Some convenience macros for gdb.  If you have pypy in your path, you can simply do:

(gdb) python import pypy.tool.gdb_pypy

Or, alternatively:

(gdb) python exec(open('/path/to/gdb_pypy.py').read())
"""

import re
import sys
import os.path

try:
    # when running inside gdb
    from gdb import Command
except ImportError:
    # whenn running outside gdb: mock class for testing
    class Command(object):
        def __init__(self, name, command_class):
            pass

MAX_DISPLAY_LENGTH = 100 # maximum number of characters displayed in rpy_string

def find_field_with_suffix(val, suffix):
    """
    Return ``val[field]``, where ``field`` is the only one whose name ends
    with ``suffix``.  If there is no such field, or more than one, raise KeyError.
    """
    names = []
    for field in val.type.fields():
        if field.name.endswith(suffix):
            names.append(field.name)
    #
    if len(names) == 1:
        return val[names[0]]
    elif len(names) == 0:
        raise KeyError("cannot find field *%s" % suffix)
    else:
        raise KeyError("too many matching fields: %s" % ', '.join(names))

def lookup(val, suffix):
    """
    Lookup a field which ends with ``suffix`` following the rpython struct
    inheritance hierarchy (i.e., looking both at ``val`` and
    ``val['*_super']``, recursively.
    """
    try:
        return find_field_with_suffix(val, suffix)
    except KeyError:
        baseobj = find_field_with_suffix(val, '_super')
        return lookup(baseobj, suffix)


class RPyType(Command):
    """
    Prints the RPython type of the expression.
    E.g.:

    (gdb) rpy_type l_v123
    GcStruct pypy.foo.Bar { super, inst_xxx, inst_yyy }
    """

    prog2typeids = {}

    def __init__(self, gdb=None):
        # dependency injection, for tests
        if gdb is None:
            import gdb
        self.gdb = gdb
        Command.__init__(self, "rpy_type", self.gdb.COMMAND_NONE)

    def invoke(self, arg, from_tty):
        # some magic code to automatically reload the python file while developing
        try:
            from pypy.tool import gdb_pypy
            try:
                reload(gdb_pypy)
            except:
                import imp
                imp.reload(gdb_pypy)
            gdb_pypy.RPyType.prog2typeids = self.prog2typeids # persist the cache
            self.__class__ = gdb_pypy.RPyType
            result = self.do_invoke(arg, from_tty)
            if not isinstance(result, str):
                result = result.decode('latin-1')
            print(result)
        except:
            import traceback
            traceback.print_exc()

    def do_invoke(self, arg, from_tty):
        try:
            offset = int(arg)
        except ValueError:
            obj = self.gdb.parse_and_eval(arg)
            if obj.type.code == self.gdb.TYPE_CODE_PTR:
                obj = obj.dereference()
            hdr = lookup(obj, '_gcheader')
            tid = hdr['h_tid']
            if tid == -42:      # forwarded?
                return 'Forwarded'
            if sys.maxsize < 2**32:
                offset = tid & 0xFFFF     # 32bit
            else:
                offset = tid & 0xFFFFFFFF # 64bit
            offset = int(offset) # convert from gdb.Value to python int

        typeids = self.get_typeids()
        if offset in typeids:
            return typeids[offset]
        else:
            return 'Cannot find the type with offset 0x%x' % offset

    def get_typeids(self):
        try:
            progspace = self.gdb.current_progspace()
        except AttributeError:
            progspace = None
        try:
            return self.prog2typeids[progspace]
        except KeyError:
            typeids = self.load_typeids(progspace)
            self.prog2typeids[progspace] = typeids
            return typeids

    def load_typeids(self, progspace=None):
        """
        Returns a mapping offset --> description
        """
        import tempfile
        import zlib
        vname = 'pypy_g_rpython_memory_gctypelayout_GCData.gcd_inst_typeids_z'
        length = int(self.gdb.parse_and_eval('*(long*)%s' % vname))
        vstart = '(char*)(((long*)%s)+1)' % vname
        fname = tempfile.mktemp()
        try:
            self.gdb.execute('dump binary memory %s %s %s+%d' %
                             (fname, vstart, vstart, length))
            with open(fname, 'rb') as fobj:
                data = fobj.read()
            return TypeIdsMap(zlib.decompress(data).splitlines(True), self.gdb)
        finally:
            os.remove(fname)


class TypeIdsMap(object):
    def __init__(self, lines, gdb):
        self.lines = lines
        self.gdb = gdb
        self.line2offset = {0: 0}
        self.offset2descr = {0: "(null typeid)"}

    def __getitem__(self, key):
        value = self.get(key)
        if value is None:
            raise KeyError(key)
        return value

    def __contains__(self, key):
        return self.get(key) is not None

    def _fetchline(self, linenum):
        if linenum in self.line2offset:
            return self.line2offset[linenum]
        line = self.lines[linenum]
        member, descr = [x.strip() for x in line.split(None, 1)]
        if sys.maxsize < 2**32:
            TIDT = "int*"
        else:
            TIDT = "char*"
        expr = ("((%s)(&pypy_g_typeinfo.%s)) - (%s)&pypy_g_typeinfo"
                   % (TIDT, member.decode("latin-1"), TIDT))
        offset = int(self.gdb.parse_and_eval(expr))
        self.line2offset[linenum] = offset
        self.offset2descr[offset] = descr
        #print '%r -> %r -> %r' % (linenum, offset, descr)
        return offset

    def get(self, offset, default=None):
        # binary search through the lines, asking gdb to parse stuff lazily
        if offset in self.offset2descr:
            return self.offset2descr[offset]
        if not (0 < offset < sys.maxsize):
            return None
        linerange = (0, len(self.lines))
        while linerange[0] < linerange[1]:
            linemiddle = (linerange[0] + linerange[1]) >> 1
            offsetmiddle = self._fetchline(linemiddle)
            if offsetmiddle == offset:
                return self.offset2descr[offset]
            elif offsetmiddle < offset:
                linerange = (linemiddle + 1, linerange[1])
            else:
                linerange = (linerange[0], linemiddle)
        return None


def is_ptr(type, gdb):
    if gdb is None:
        import gdb # so we can pass a fake one from the tests
    return type.code == gdb.TYPE_CODE_PTR


class RPyStringPrinter(object):
    """
    Pretty printer for rpython strings.

    Note that this pretty prints *pointers* to strings: this way you can do "p
    val" and see the nice string, and "p *val" to see the underyling struct
    fields
    """

    def __init__(self, val):
        self.val = val

    @classmethod
    def lookup(cls, val, gdb=None):
        t = val.type
        if is_ptr(t, gdb) and t.target().tag == 'pypy_rpy_string0':
            return cls(val)
        return None

    def to_string(self):
        chars = self.val['rs_chars']
        length = int(chars['length'])
        items = chars['items']
        res = []
        for i in range(min(length, MAX_DISPLAY_LENGTH)):
            c = items[i]
            try:
                res.append(chr(c))
            except ValueError:
                # it's a gdb.Value so it has "121 'y'" as repr
                try:
                    res.append(chr(int(str(c).split(" ")[0])))
                except ValueError:
                    # meh?
                    res.append(repr(c))
        if length > MAX_DISPLAY_LENGTH:
            res.append('...')
        string = ''.join(res)
        return 'r' + repr(string)


class RPyListPrinter(object):
    """
    Pretty printer for rpython lists

    Note that this pretty prints *pointers* to lists: this way you can do "p
    val" and see the nice repr, and "p *val" to see the underyling struct
    fields
    """

    recursive = False

    def __init__(self, val):
        self.val = val

    @classmethod
    def lookup(cls, val, gdb=None):
        t = val.type
        if (is_ptr(t, gdb) and t.target().tag is not None and
            re.match(r'pypy_(list|array)\d*', t.target().tag)):
            return cls(val)
        return None

    def to_string(self):
        t = self.val.type
        if t.target().tag.startswith(r'pypy_array'):
            if not self.val:
                return 'r(null_array)'
            length = int(self.val['length'])
            items = self.val['items']
            allocstr = ''
        else:
            if not self.val:
                return 'r(null_list)'
            length = int(self.val['l_length'])
            array = self.val['l_items']
            allocated = int(array['length'])
            items = array['items']
            allocstr = ', alloc=%d' % allocated
        if RPyListPrinter.recursive:
            str_items = '...'
        else:
            RPyListPrinter.recursive = True
            try:
                itemlist = []
                for i in range(min(length, MAX_DISPLAY_LENGTH)):
                    item = items[i]
                    itemlist.append(str(item))    # may recurse here
                if length > MAX_DISPLAY_LENGTH:
                    itemlist.append("...")
                str_items = ', '.join(itemlist)
            finally:
                RPyListPrinter.recursive = False
        return 'r[%s] (len=%d%s)' % (str_items, length, allocstr)


try:
    import gdb
    RPyType() # side effects
    gdb.pretty_printers = [
        RPyStringPrinter.lookup,
        RPyListPrinter.lookup
        ] + gdb.pretty_printers
except ImportError:
    pass
