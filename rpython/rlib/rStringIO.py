from rpython.rlib.rstring import StringBuilder
from rpython.rlib.objectmodel import we_are_translated

AT_END = -1


class RStringIO(object):
    """RPython-level StringIO object.
    The fastest path through this code is for the case of a bunch of write()
    followed by getvalue().
    """
    def __init__(self):
        self.init()

    def init(self):
        # The real content is the join of the following data:
        #  * the list of characters self.__bigbuffer;
        #  * each of the strings in self.__strings.
        #
        self.__closed = False
        self.__strings = None
        self.__bigbuffer = None
        self.__pos = AT_END

    def close(self):
        self.__closed = True
        self.__strings = None
        self.__bigbuffer = None
        self.__pos = AT_END

    def is_closed(self):
        return self.__closed

    def __copy_into_bigbuffer(self):
        """Copy all the data into the list of characters self.__bigbuffer."""
        if self.__bigbuffer is None:
            self.__bigbuffer = []
        if self.__strings is not None:
            self.__bigbuffer += self.__strings.build()
            self.__strings = None

    def getvalue(self):
        """If self.__strings contains more than 1 string, join all the
        strings together.  Return the final single string."""
        if self.__bigbuffer is not None:
            self.__copy_into_bigbuffer()
            return ''.join(self.__bigbuffer)
        if self.__strings is not None:
            return self.__strings.build()
        return ''

    def getsize(self):
        result = 0
        if self.__bigbuffer is not None:
            result += len(self.__bigbuffer)
        if self.__strings is not None:
            result += self.__strings.getlength()
        return result

    def write(self, buffer):
        # Idea: for the common case of a sequence of write() followed
        # by only getvalue(), self.__bigbuffer remains empty.  It is only
        # used to handle the more complicated cases.
        if self.__pos == AT_END:
            self.__fast_write(buffer)
        else:
            self.__slow_write(buffer)

    def __fast_write(self, buffer):
        if self.__strings is None:
            self.__strings = StringBuilder()
        self.__strings.append(buffer)

    def __slow_write(self, buffer):
        assert buffer is not None # help annotator
        p = self.__pos
        assert p >= 0
        endp = p + len(buffer)
        if self.__bigbuffer is not None and len(self.__bigbuffer) >= endp:
            # semi-fast path: the write is entirely inside self.__bigbuffer
            for i in range(len(buffer)):
                self.__bigbuffer[p + i] = buffer[i]
        else:
            # slow path: collect all data into self.__bigbuffer and
            # handle the various cases
            self.__copy_into_bigbuffer()
            fitting = len(self.__bigbuffer) - p
            if fitting > 0:
                # the write starts before the end of the data
                fitting = min(len(buffer), fitting)
                for i in range(fitting):
                    self.__bigbuffer[p + i] = buffer[i]
                if len(buffer) > fitting:
                    # the write extends beyond the end of the data
                    self.__bigbuffer += buffer[fitting:]
                    endp = AT_END
            else:
                # the write starts at or beyond the end of the data
                self.__bigbuffer += '\x00' * (-fitting) + buffer
                endp = AT_END
        self.__pos = endp

    def seek(self, position, mode=0):
        if mode == 0:
            if position == self.getsize():
                self.__pos = AT_END
                return
        elif mode == 1:
            if self.__pos == AT_END:
                self.__pos = self.getsize()
            position += self.__pos
        elif mode == 2:
            if position == 0:
                self.__pos = AT_END
                return
            position += self.getsize()
        if position < 0:
            position = 0
        self.__pos = position

    def tell(self):
        if self.__pos == AT_END:
            result = self.getsize()
        else:
            result = self.__pos
        assert result >= 0
        return result

    def read(self, size=-1):
        p = self.__pos
        if p == 0 and size < 0:
            self.__pos = AT_END
            return self.getvalue()     # reading everything
        if p == AT_END or size == 0:
            return ''
        assert p >= 0
        self.__copy_into_bigbuffer()
        mysize = len(self.__bigbuffer)
        count = mysize - p
        if size >= 0:
            count = min(size, count)
        if count <= 0:
            return ''
        if p == 0 and count == mysize:
            self.__pos = AT_END
            return ''.join(self.__bigbuffer)
        else:
            self.__pos = p + count
            return ''.join(self.__bigbuffer[p:p+count])

    def readline(self, size=-1):
        p = self.__pos
        if p == AT_END or size == 0:
            return ''
        assert p >= 0
        self.__copy_into_bigbuffer()
        end = len(self.__bigbuffer)
        count = end - p
        if size >= 0 and size < count:
            end = p + size
        if count <= 0:
            return ''
        i = p
        while i < end:
            finished = self.__bigbuffer[i] == '\n'
            i += 1
            if finished:
                break
        self.__pos = i
        if not we_are_translated():
            # assert that we read within the bounds!
            bl = len(self.__bigbuffer)
            assert p <= bl
            assert i <= bl
        return ''.join(self.__bigbuffer[p:i])

    def truncate(self, size):
        """Warning, this gets us slightly strange behavior from the
        point of view of a traditional Unix file, but consistent with
        Python 2.7's cStringIO module: it will not enlarge the file,
        and it will always seek to the (new) end of the file."""
        assert size >= 0
        if size == 0:
            self.__bigbuffer = None
            self.__strings = None
        else:
            if self.__bigbuffer is None or size > len(self.__bigbuffer):
                self.__copy_into_bigbuffer()
            else:
                # we can drop all extra strings
                if self.__strings is not None:
                    self.__strings = None
            if size < len(self.__bigbuffer):
                del self.__bigbuffer[size:]
            if len(self.__bigbuffer) == 0:
                self.__bigbuffer = None
        # it always has the effect of seeking at the new end
        self.__pos = AT_END
