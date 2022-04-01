"""Functionality shared between bytes/bytearray/unicode"""

from rpython.rlib import jit
from rpython.rlib.objectmodel import specialize, newlist_hint
from rpython.rlib.rarithmetic import ovfcheck
from rpython.rlib.rstring import (
    find, rfind, count, endswith, replace, rsplit, split, startswith)
from pypy.interpreter.error import OperationError, oefmt
from pypy.interpreter.gateway import WrappedDefault, unwrap_spec
from pypy.interpreter.unicodehelper import str_decode_utf8
from pypy.objspace.std.sliceobject import W_SliceObject, unwrap_start_stop


class StringMethods(object):
    def _sliced(self, space, s, start, stop, orig_obj):
        assert start >= 0
        assert stop >= 0
        #if start == 0 and stop == len(s) and space.is_w(space.type(orig_obj),
        #                                                space.w_bytes):
        #    return orig_obj
        return self._new(s[start:stop])

    def _convert_idx_params(self, space, w_start, w_end):
        value = self._val(space)
        lenself = len(value)
        start, end = unwrap_start_stop(space, lenself, w_start, w_end)
        # the None means "no offset"; see bytearrayobject.py
        return (value, start, end, None)

    @staticmethod
    def descr_maketrans(space, w_type, w_from, w_to):
        """B.maketrans(frm, to) -> translation table

        Return a translation table (a bytes object of length 256) suitable
        for use in the bytes or bytearray translate method where each byte
        in frm is mapped to the byte at the same position in to.
        The bytes objects frm and to must be of the same length.
        """
        from pypy.objspace.std.bytesobject import makebytesdata_w

        base_table = [chr(i) for i in range(256)]
        list_from = makebytesdata_w(space, w_from)
        list_to = makebytesdata_w(space, w_to)

        if len(list_from) != len(list_to):
            raise oefmt(space.w_ValueError,
                        "maketrans arguments must have same length")

        for i in range(len(list_from)):
            pos_from = ord(list_from[i])
            char_to = list_to[i]
            base_table[pos_from] = char_to

        return space.newbytes(''.join(base_table))

    def _multi_chr(self, c):
        return c

    @staticmethod
    def _single_char(space, w_sub):
        try:
            char = space.int_w(w_sub)
        except OperationError as e:
            if e.match(space, space.w_OverflowError):
                char = 256 # arbitrary value which will trigger the ValueError
                # condition below
            else:
                raise
        if not 0 <= char < 256:
            raise oefmt(space.w_ValueError,
                        "byte must be in range(0, 256)")
        return chr(char)

    def descr_len(self, space):
        return space.newint(self._len())

    def descr_iter(self, space):
        from pypy.objspace.std.iterobject import W_StringIterObject
        return W_StringIterObject(self, self._iter_getitem_result)

    def descr_contains(self, space, w_sub):
        value, start, end, _ = self._convert_idx_params(space, None, None)
        other = self._op_val(space, w_sub, allow_char=True)
        if self._use_rstr_ops(space, w_sub):
            res = value.find(other, start, end)
        else:
            res = find(value, other, start, end)
        return space.newbool(res >= 0)

    def descr_add(self, space, w_other):
        if self._use_rstr_ops(space, w_other):
            try:
                other = self._op_val(space, w_other)
            except OperationError as e:
                if e.match(space, space.w_TypeError):
                    return space.w_NotImplemented
                raise
            return self._new(self._val(space) + other)

        # Bytearray overrides this method, CPython doesn't support contacting
        # buffers and strs, and unicodes are always handled above
        return space.w_NotImplemented

    def descr_mul(self, space, w_times):
        try:
            times = space.getindex_w(w_times, space.w_OverflowError)
        except OperationError as e:
            if e.match(space, space.w_TypeError):
                return space.w_NotImplemented
            raise
        if times <= 0:
            return self._empty()
        if self._len() == 1:
            return self._new(self._multi_chr(self._val(space)[0]) * times)
        return self._new(self._val(space) * times)

    descr_rmul = descr_mul

    _KIND1 = "string"
    _KIND2 = "string"

    def descr_getitem(self, space, w_index):
        if isinstance(w_index, W_SliceObject):
            selfvalue = self._val(space)
            length = len(selfvalue)
            start, stop, step, sl = w_index.indices4(space, length)
            if sl == 0:
                return self._empty()
            elif step == 1:
                assert start >= 0 and stop >= 0
                return self._sliced(space, selfvalue, start, stop, self)
            else:
                ret = _descr_getslice_slowpath(selfvalue, start, step, sl)
                return self._new_from_list(ret)

        index = space.getindex_w(w_index, space.w_IndexError, self._KIND1)
        return self._getitem_result(space, index)

    def _getitem_result(self, space, index):
        # Returns the result of 'self[index]', where index is an unwrapped int.
        # Used by descr_getitem() and by descr_iter().
        selfvalue = self._val(space)
        try:
            character = selfvalue[index]
        except IndexError:
            raise oefmt(space.w_IndexError, self._KIND1 + " index out of range")
        from pypy.objspace.std.bytesobject import W_BytesObject
        if isinstance(self, W_BytesObject):
            return space.newint(ord(character))
        return self._new(character)

    def descr_capitalize(self, space):
        value = self._val(space)
        if len(value) == 0:
            return self._empty()

        builder = self._builder(len(value))
        builder.append(self._upper(value[0]))
        for i in range(1, len(value)):
            builder.append(self._lower_in_str(value, i))
        return self._new(builder.build())

    @unwrap_spec(width=int, w_fillchar=WrappedDefault(' '))
    def descr_center(self, space, width, w_fillchar):
        value = self._val(space)
        fillchar = self._op_val(space, w_fillchar)
        if len(fillchar) != 1:
            raise oefmt(space.w_TypeError,
                        "center() argument 2 must be a single character")

        d = width - len(value)
        if d > 0:
            offset = d//2 + (d & width & 1)
            fillchar = self._multi_chr(fillchar[0])
            centered = offset * fillchar + value + (d - offset) * fillchar
        else:
            centered = value

        return self._new(centered)

    def descr_count(self, space, w_sub, w_start=None, w_end=None):
        value, start, end, _ = self._convert_idx_params(space, w_start, w_end)

        sub = self._op_val(space, w_sub, allow_char=True)
        if self._use_rstr_ops(space, w_sub):
            return space.newint(value.count(sub, start, end))
        else:
            res = count(value, sub, start, end)
            assert res >= 0
        return space.newint(res)

    def descr_decode(self, space, w_encoding=None, w_errors=None):
        from pypy.objspace.std.unicodeobject import (
            get_encoding_and_errors, decode_object)
        encoding, errors = get_encoding_and_errors(space, w_encoding, w_errors)
        if encoding is None:
            encoding = 'utf8'
        if encoding == 'utf8' or encoding == 'utf-8':
            # fast path - do not call into app-level codecs.py
            from pypy.module._codecs.interp_codecs import CodecState
            state = space.fromcache(CodecState)
            eh = state.decode_error_handler
            s = space.charbuf_w(self)
            ret, lgt, pos = str_decode_utf8(s, errors, True, eh)
            return space.newtext(ret, lgt)
        return decode_object(space, self, encoding, errors)

    @unwrap_spec(tabsize=int)
    def descr_expandtabs(self, space, tabsize=8):
        value = self._val(space)
        if not value:
            return self._empty()

        if self._use_rstr_ops(space, self):
            splitted = value.split(self._chr('\t'))
        else:
            splitted = split(value, self._chr('\t'))

        try:
            if tabsize > 0:
                ovfcheck(len(splitted) * tabsize)
        except OverflowError:
            raise oefmt(space.w_OverflowError, "new string is too long")
        expanded = oldtoken = splitted.pop(0)

        for token in splitted:
            expanded += self._multi_chr(self._chr(' ')) * self._tabindent(oldtoken,
                                                         tabsize) + token
            oldtoken = token

        return self._new(expanded)

    def _tabindent(self, token, tabsize):
        """calculates distance behind the token to the next tabstop"""

        if tabsize <= 0:
            return 0
        distance = tabsize
        if token:
            distance = 0
            offset = len(token)

            while 1:
                if token[offset-1] == "\n" or token[offset-1] == "\r":
                    break
                distance += 1
                offset -= 1
                if offset == 0:
                    break

            # the same like distance = len(token) - (offset + 1)
            distance = (tabsize - distance) % tabsize
            if distance == 0:
                distance = tabsize

        return distance

    def descr_find(self, space, w_sub, w_start=None, w_end=None):
        value, start, end, ofs = self._convert_idx_params(space, w_start, w_end)

        sub = self._op_val(space, w_sub, allow_char=True)
        if self._use_rstr_ops(space, w_sub):
            res = value.find(sub, start, end)
        else:
            res = find(value, sub, start, end)
        if ofs is not None and res >= 0:
            res -= ofs
        return space.newint(res)

    def descr_rfind(self, space, w_sub, w_start=None, w_end=None):
        value, start, end, ofs = self._convert_idx_params(space, w_start, w_end)

        sub = self._op_val(space, w_sub, allow_char=True)
        if self._use_rstr_ops(space, w_sub):
            res = value.rfind(sub, start, end)
        else:
            res = rfind(value, sub, start, end)
        if ofs is not None and res >= 0:
            res -= ofs
        return space.newint(res)

    def descr_index(self, space, w_sub, w_start=None, w_end=None):
        value, start, end, ofs = self._convert_idx_params(space, w_start, w_end)

        sub = self._op_val(space, w_sub, allow_char=True)
        if self._use_rstr_ops(space, w_sub):
            res = value.find(sub, start, end)
        else:
            res = find(value, sub, start, end)

        if res < 0:
            raise oefmt(space.w_ValueError,
                        "substring not found in " + self._KIND2 + ".index")
        if ofs is not None:
            res -= ofs
        return space.newint(res)

    def descr_rindex(self, space, w_sub, w_start=None, w_end=None):
        value, start, end, ofs = self._convert_idx_params(space, w_start, w_end)

        sub = self._op_val(space, w_sub, allow_char=True)
        if self._use_rstr_ops(space, w_sub):
            res = value.rfind(sub, start, end)
        else:
            res = rfind(value, sub, start, end)

        if res < 0:
            raise oefmt(space.w_ValueError,
                        "substring not found in " + self._KIND2 + ".rindex")
        if ofs is not None:
            res -= ofs
        return space.newint(res)

    @specialize.arg(2)
    def _is_generic(self, space, func_name):
        func = getattr(self, func_name)
        v = self._val(space)
        if len(v) == 0:
            return space.w_False
        if len(v) == 1:
            c = v[0]
            return space.newbool(func(c))
        else:
            return self._is_generic_loop(space, v, func_name)

    @specialize.arg(3)
    def _is_generic_loop(self, space, v, func_name):
        func = getattr(self, func_name)
        for idx in range(len(v)):
            if not func(v[idx]):
                return space.w_False
        return space.w_True

    def descr_isalnum(self, space):
        return self._is_generic(space, '_isalnum')

    def descr_isalpha(self, space):
        return self._is_generic(space, '_isalpha')

    def descr_isdigit(self, space):
        return self._is_generic(space, '_isdigit')

    # this is only for bytes and bytesarray: unicodeobject overrides it
    def _descr_islower_slowpath(self, space, v):
        cased = False
        for idx in range(len(v)):
            if self._isupper(v[idx]):
                return False
            elif not cased and self._islower(v[idx]):
                cased = True
        return cased

    def descr_islower(self, space):
        v = self._val(space)
        if len(v) == 1:
            c = v[0]
            return space.newbool(self._islower(c))
        cased = self._descr_islower_slowpath(space, v)
        return space.newbool(cased)

    def descr_isspace(self, space):
        return self._is_generic(space, '_isspace')

    def descr_istitle(self, space):
        input = self._val(space)
        cased = False
        previous_is_cased = False

        for pos in range(0, len(input)):
            ch = input[pos]
            if self._istitle(ch):
                if previous_is_cased:
                    return space.w_False
                previous_is_cased = True
                cased = True
            elif self._islower(ch):
                if not previous_is_cased:
                    return space.w_False
                cased = True
            else:
                previous_is_cased = False

        return space.newbool(cased)

    # this is only for bytes and bytesarray: unicodeobject overrides it
    def _descr_isupper_slowpath(self, space, v):
        cased = False
        for idx in range(len(v)):
            if self._islower(v[idx]):
                return False
            elif not cased and self._isupper(v[idx]):
                cased = True
        return cased

    def descr_isupper(self, space):
        v = self._val(space)
        if len(v) == 1:
            c = v[0]
            return space.newbool(self._isupper(c))
        cased = self._descr_isupper_slowpath(space, v)
        return space.newbool(cased)

    def descr_join(self, space, w_list):
        list_w = space.listview(w_list)
        size = len(list_w)

        if size == 0:
            return self._empty()

        if size == 1:
            w_s = list_w[0]
            # only one item, return it if it's not a subclass of str
            if self._join_return_one(space, w_s):
                return w_s

        return self._str_join_many_items(space, list_w, size)

    @jit.look_inside_iff(lambda self, space, list_w, size:
                         jit.loop_unrolling_heuristic(list_w, size))
    def _str_join_many_items(self, space, list_w, size):
        value = self._val(space)

        prealloc_size = len(value) * (size - 1)
        unwrapped = newlist_hint(size)
        for i in range(size):
            w_s = list_w[i]
            try:
                next_string = self._op_val(space, w_s)
            except OperationError as e:
                if not e.match(space, space.w_TypeError):
                    raise
                raise oefmt(space.w_TypeError,
                            "sequence item %d: expected %s, %T found",
                            i, self._generic_name(), w_s)
            # XXX Maybe the extra copy here is okay? It was basically going to
            #     happen anyway, what with being placed into the builder
            unwrapped.append(next_string)
            prealloc_size += len(unwrapped[i])

        sb = self._builder(prealloc_size)
        for i in range(size):
            if value and i != 0:
                sb.append(value)
            sb.append(unwrapped[i])
        return self._new(sb.build())

    @unwrap_spec(width=int, w_fillchar=WrappedDefault(' '))
    def descr_ljust(self, space, width, w_fillchar):
        value = self._val(space)
        fillchar = self._op_val(space, w_fillchar)
        if len(fillchar) != 1:
            raise oefmt(space.w_TypeError,
                        "ljust() argument 2 must be a single character")
        d = width - len(value)
        if d > 0:
            fillchar = self._multi_chr(fillchar[0])
            value = value + fillchar * d

        return self._new(value)

    @unwrap_spec(width=int, w_fillchar=WrappedDefault(' '))
    def descr_rjust(self, space, width, w_fillchar):
        value = self._val(space)
        fillchar = self._op_val(space, w_fillchar)
        if len(fillchar) != 1:
            raise oefmt(space.w_TypeError,
                        "rjust() argument 2 must be a single character")
        d = width - len(value)
        if d > 0:
            fillchar = self._multi_chr(fillchar[0])
            value = d * fillchar + value

        return self._new(value)

    def descr_lower(self, space):
        value = self._val(space)
        builder = self._builder(len(value))
        for i in range(len(value)):
            builder.append(self._lower_in_str(value, i))
        return self._new(builder.build())

    def _lower_in_str(self, value, i):
        # overridden in unicodeobject.py
        return self._lower(value[i])

    # This is not used for W_UnicodeObject.
    def descr_partition(self, space, w_sub):
        from pypy.objspace.std.bytearrayobject import W_BytearrayObject
        value = self._val(space)

        if self._use_rstr_ops(space, w_sub):
            sub = self._op_val(space, w_sub)
            sublen = len(sub)
            if sublen == 0:
                raise oefmt(space.w_ValueError, "empty separator")

            pos = value.find(sub)
        else:
            sub = space.readbuf_w(w_sub)
            sublen = sub.getlength()
            if sublen == 0:
                raise oefmt(space.w_ValueError, "empty separator")

            pos = find(value, sub, 0, len(value))
            if pos != -1 and isinstance(self, W_BytearrayObject):
                w_sub = self._new_from_buffer(sub)

        if pos == -1:
            if isinstance(self, W_BytearrayObject):
                self = self._new(value)
            return space.newtuple([self, self._empty(), self._empty()])
        else:
            return space.newtuple(
                [self._sliced(space, value, 0, pos, self), w_sub,
                 self._sliced(space, value, pos + sublen, len(value), self)])

    def descr_rpartition(self, space, w_sub):
        from pypy.objspace.std.bytearrayobject import W_BytearrayObject
        value = self._val(space)

        if self._use_rstr_ops(space, w_sub):
            sub = self._op_val(space, w_sub)
            sublen = len(sub)
            if sublen == 0:
                raise oefmt(space.w_ValueError, "empty separator")

            pos = value.rfind(sub)
        else:
            sub = space.readbuf_w(w_sub)
            sublen = sub.getlength()
            if sublen == 0:
                raise oefmt(space.w_ValueError, "empty separator")

            pos = rfind(value, sub, 0, len(value))
            if pos != -1 and isinstance(self, W_BytearrayObject):
                w_sub = self._new_from_buffer(sub)

        if pos == -1:
            if isinstance(self, W_BytearrayObject):
                self = self._new(value)
            return space.newtuple([self._empty(), self._empty(), self])
        else:
            return space.newtuple(
                [self._sliced(space, value, 0, pos, self), w_sub,
                 self._sliced(space, value, pos + sublen, len(value), self)])

    @unwrap_spec(count=int)
    def descr_replace(self, space, w_old, w_new, count=-1):
        input = self._val(space)

        sub = self._op_val(space, w_old)
        by = self._op_val(space, w_new)
        try:
            res = replace(input, sub, by, count)
        except OverflowError:
            raise oefmt(space.w_OverflowError, "replace string is too long")

        return self._new(res)

    @unwrap_spec(maxsplit=int)
    def descr_split(self, space, w_sep=None, maxsplit=-1):
        res = []
        value = self._val(space)
        if space.is_none(w_sep):
            res = split(value, maxsplit=maxsplit)
            return self._newlist_unwrapped(space, res)

        by = self._op_val(space, w_sep)
        if len(by) == 0:
            raise oefmt(space.w_ValueError, "empty separator")
        res = split(value, by, maxsplit)

        return self._newlist_unwrapped(space, res)

    @unwrap_spec(maxsplit=int)
    def descr_rsplit(self, space, w_sep=None, maxsplit=-1):
        res = []
        value = self._val(space)
        if space.is_none(w_sep):
            res = rsplit(value, maxsplit=maxsplit)
            return self._newlist_unwrapped(space, res)

        by = self._op_val(space, w_sep)
        if len(by) == 0:
            raise oefmt(space.w_ValueError, "empty separator")
        res = rsplit(value, by, maxsplit)

        return self._newlist_unwrapped(space, res)

    @unwrap_spec(keepends=int)
    def descr_splitlines(self, space, keepends=False):
        value = self._val(space)
        length = len(value)
        strs = []
        pos = 0
        while pos < length:
            sol = pos
            while pos < length and not self._islinebreak(value[pos]):
                pos += 1
            eol = pos
            pos += 1
            # read CRLF as one line break
            if pos < length and value[eol] == '\r' and value[pos] == '\n':
                pos += 1
            if keepends:
                eol = pos
            strs.append(value[sol:eol])
        if pos < length:
            # XXX is this code reachable?
            strs.append(value[pos:length])
        return self._newlist_unwrapped(space, strs)

    def _generic_name(self):
        return "bytes"

    # This is overridden in unicodeobject, _startswith_tuple is not.
    def descr_startswith(self, space, w_prefix, w_start=None, w_end=None):
        value, start, end, _ = self._convert_idx_params(space, w_start, w_end)
        if space.isinstance_w(w_prefix, space.w_tuple):
            return self._startswith_tuple(space, value, w_prefix, start, end)
        try:
            res = self._startswith(space, value, w_prefix, start, end)
        except OperationError as e:
            if not e.match(space, space.w_TypeError):
                raise
            wanted = self._generic_name()
            raise oefmt(space.w_TypeError,
                        "startswith first arg must be %s or a tuple of %s, "
                        "not %T", wanted, wanted, w_prefix)
        return space.newbool(res)

    def _startswith_tuple(self, space, value, w_prefix, start, end):
        for w_prefix in space.fixedview(w_prefix):
            if self._startswith(space, value, w_prefix, start, end):
                return space.w_True
        return space.w_False

    # This is overridden in unicodeobject, _startswith_tuple is not.
    def _startswith(self, space, value, w_prefix, start, end):
        prefix = self._op_val(space, w_prefix)
        if start > len(value):
            return False
        return startswith(value, prefix, start, end)

    # This is overridden in unicodeobject, _endswith_tuple is not.
    def descr_endswith(self, space, w_suffix, w_start=None, w_end=None):
        value, start, end, _ = self._convert_idx_params(space, w_start, w_end)
        if space.isinstance_w(w_suffix, space.w_tuple):
            return self._endswith_tuple(space, value, w_suffix, start, end)
        try:
            res = self._endswith(space, value, w_suffix, start, end)
        except OperationError as e:
            if not e.match(space, space.w_TypeError):
                raise
            wanted = self._generic_name()
            raise oefmt(space.w_TypeError,
                        "endswith first arg must be %s or a tuple of %s, not "
                        "%T", wanted, wanted, w_suffix)
        return space.newbool(res)

    def _endswith_tuple(self, space, value, w_suffix, start, end):
        for w_suffix in space.fixedview(w_suffix):
            if self._endswith(space, value, w_suffix, start, end):
                return space.w_True
        return space.w_False

    # This is overridden in unicodeobject, but _endswith_tuple is not.
    def _endswith(self, space, value, w_prefix, start, end):
        prefix = self._op_val(space, w_prefix)
        if start > len(value):
            return False
        return endswith(value, prefix, start, end)

    def _strip(self, space, w_chars, left, right, name='strip'):
        "internal function called by str_xstrip methods"
        value = self._val(space)
        chars = self._op_val(space, w_chars)

        lpos = 0
        rpos = len(value)

        if left:
            while lpos < rpos and value[lpos] in chars:
                lpos += 1

        if right:
            while rpos > lpos and value[rpos - 1] in chars:
                rpos -= 1

        assert rpos >= lpos    # annotator hint, don't remove
        return self._sliced(space, value, lpos, rpos, self)

    def _strip_none(self, space, left, right):
        "internal function called by str_xstrip methods"
        value = self._val(space)

        lpos = 0
        rpos = len(value)

        if left:
            while lpos < rpos and self._isspace(value[lpos]):
                lpos += 1

        if right:
            while rpos > lpos and self._isspace(value[rpos - 1]):
                rpos -= 1

        assert rpos >= lpos    # annotator hint, don't remove
        return self._sliced(space, value, lpos, rpos, self)

    def descr_strip(self, space, w_chars=None):
        if space.is_none(w_chars):
            return self._strip_none(space, left=1, right=1)
        return self._strip(space, w_chars, left=1, right=1, name='strip')

    def descr_lstrip(self, space, w_chars=None):
        if space.is_none(w_chars):
            return self._strip_none(space, left=1, right=0)
        return self._strip(space, w_chars, left=1, right=0, name='lstrip')

    def descr_rstrip(self, space, w_chars=None):
        if space.is_none(w_chars):
            return self._strip_none(space, left=0, right=1)
        return self._strip(space, w_chars, left=0, right=1, name='rstrip')

    def descr_swapcase(self, space):
        selfvalue = self._val(space)
        builder = self._builder(len(selfvalue))
        for i in range(len(selfvalue)):
            ch = selfvalue[i]
            if self._isupper(ch):
                builder.append(self._lower_in_str(selfvalue, i))
            elif self._islower(ch):
                builder.append(self._upper(ch))
            else:
                builder.append(ch)
        return self._new(builder.build())

    def descr_title(self, space):
        selfval = self._val(space)
        if len(selfval) == 0:
            return self
        return self._new(self.title(selfval))

    @jit.elidable
    def title(self, value):
        builder = self._builder(len(value))
        previous_is_cased = False
        for i in range(len(value)):
            ch = value[i]
            if not previous_is_cased:
                builder.append(self._title(ch))
            else:
                builder.append(self._lower_in_str(value, i))
            previous_is_cased = self._iscased(ch)
        return builder.build()

    DEFAULT_NOOP_TABLE = ''.join([chr(i) for i in range(256)])

    # for bytes and bytearray, overridden by unicode
    @unwrap_spec(w_delete=WrappedDefault(''))
    def descr_translate(self, space, w_table, w_delete):
        if space.is_w(w_table, space.w_None):
            table = self.DEFAULT_NOOP_TABLE
        else:
            table = self._op_val(space, w_table)
            if len(table) != 256:
                raise oefmt(space.w_ValueError,
                            "translation table must be 256 characters long")

        string = self._val(space)
        deletechars = self._op_val(space, w_delete)
        if len(deletechars) == 0:
            buf = self._builder(len(string))
            for char in string:
                buf.append(table[ord(char)])
        else:
            # XXX Why not preallocate here too?
            buf = self._builder()
            deletion_table = [False] * 256
            for i in range(len(deletechars)):
                deletion_table[ord(deletechars[i])] = True
            for char in string:
                if not deletion_table[ord(char)]:
                    buf.append(table[ord(char)])
        return self._new(buf.build())

    def descr_upper(self, space):
        value = self._val(space)
        builder = self._builder(len(value))
        for i in range(len(value)):
            builder.append(self._upper(value[i]))
        return self._new(builder.build())

    @unwrap_spec(width=int)
    def descr_zfill(self, space, width):
        selfval = self._val(space)
        if len(selfval) == 0:
            return self._new(self._multi_chr(self._chr('0')) * width)
        num_zeros = width - len(selfval)
        if num_zeros <= 0:
            # cannot return self, in case it is a subclass of str
            return self._new(selfval)

        builder = self._builder(width)
        if len(selfval) > 0 and (selfval[0] == '+' or selfval[0] == '-'):
            # copy sign to first position
            builder.append(selfval[0])
            start = 1
        else:
            start = 0
        builder.append_multiple_char(self._chr('0'), num_zeros)
        builder.append_slice(selfval, start, len(selfval))
        return self._new(builder.build())

    def descr_getnewargs(self, space):
        return space.newtuple([self._new(self._val(space))])

    def descr_removeprefix(self, space, w_prefix):
        prefix = self._op_val(space, w_prefix)
        selfval = self._val(space)
        if startswith(selfval, prefix):
            return self._new(selfval[len(prefix):])
        return self._new(selfval)

    def descr_removesuffix(self, space, w_suffix):
        suffix = self._op_val(space, w_suffix)
        selfval = self._val(space)
        if suffix and endswith(selfval, suffix):
            end = len(selfval) - len(suffix)
            assert end >= 0
            return self._new(selfval[:end])
        return self._new(selfval)

# ____________________________________________________________
# helpers for slow paths, moved out because they contain loops

@specialize.argtype(0)
def _descr_getslice_slowpath(selfvalue, start, step, sl):
    return [selfvalue[start + i*step] for i in range(sl)]
