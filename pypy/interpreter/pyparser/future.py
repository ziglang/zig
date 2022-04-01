from pypy.tool import stdlib___future__ as future

class FutureFlags(object):

    def __init__(self, version):
        compiler_flags = 0
        self.compiler_features = {}
        self.mandatory_flags = 0
        for fname in future.all_feature_names:
            feature = getattr(future, fname)
            if version >= feature.getOptionalRelease():
                flag = feature.compiler_flag
                compiler_flags |= flag
                self.compiler_features[fname] = flag
            if version >= feature.getMandatoryRelease():
                self.mandatory_flags |= feature.compiler_flag
        self.allowed_flags = compiler_flags

    def get_flag_names(self, space, flags):
        flag_names = []
        for name, value in self.compiler_features.items():
            if flags & value:
                flag_names.append(name)
        return flag_names

    def get_compiler_feature(self, name):
        return self.compiler_features.get(name, 0)

futureFlags_2_4 = FutureFlags((2, 4, 4, 'final', 0))
futureFlags_2_5 = FutureFlags((2, 5, 0, 'final', 0))
futureFlags_2_7 = FutureFlags((2, 7, 0, 'final', 0))
futureFlags_3_2 = FutureFlags((3, 2, 0, 'final', 0))
futureFlags_3_5 = FutureFlags((3, 5, 0, 'final', 0))
futureFlags_3_7 = FutureFlags((3, 7, 0, 'final', 0))
futureFlags_3_8 = FutureFlags((3, 8, 0, 'final', 0))
futureFlags_3_9 = FutureFlags((3, 9, 0, 'final', 0))


class TokenIterator:
    def __init__(self, tokens):
        self.tokens = tokens
        self.index = 0
        self.next()

    def next(self):
        index = self.index
        self.index = index + 1
        self.tok = self.tokens[index]

    def skip(self, n):
        if self.tok.token_type == n:
            self.next()
            return True
        else:
            return False

    def skip_name(self, name):
        from pypy.interpreter.pyparser import pygram
        if self.tok.token_type == pygram.tokens.NAME and self.tok.value == name:
            self.next()
            return True
        else:
            return False

    def next_feature_name(self):
        from pypy.interpreter.pyparser import pygram
        if self.tok.token_type == pygram.tokens.NAME:
            name = self.tok.value
            self.next()
            if self.skip_name("as"):
                self.skip(pygram.tokens.NAME)
            return name
        else:
            return ''

    def skip_newlines(self):
        from pypy.interpreter.pyparser import pygram
        while self.skip(pygram.tokens.NEWLINE):
            pass


def add_future_flags(future_flags, tokens):
    from pypy.interpreter.pyparser import pygram
    it = TokenIterator(tokens)
    result = 0
    last_position = (0, 0)
    #
    # The only things that can precede a future statement are another
    # future statement and a doc string (only one).  This is a very
    # permissive parsing of the given list of tokens; it relies on
    # the real parsing done afterwards to give errors.
    it.skip_newlines()
    it.skip_name("r") or it.skip_name("u") or it.skip_name("ru")
    if it.skip(pygram.tokens.STRING):
        it.skip_newlines()

    while (it.skip_name("from") and
           it.skip_name("__future__") and
           it.skip_name("import")):
        it.skip(pygram.tokens.LPAR)    # optionally
        # return in 'last_position' any line-column pair that points
        # somewhere inside the last __future__ import statement
        # (at the start would be fine too, but it's easier to grab a
        # random position inside)
        last_position = (it.tok.lineno, it.tok.column)
        result |= future_flags.get_compiler_feature(it.next_feature_name())
        while it.skip(pygram.tokens.COMMA):
            result |= future_flags.get_compiler_feature(it.next_feature_name())
        it.skip(pygram.tokens.RPAR)    # optionally
        it.skip(pygram.tokens.SEMI)    # optionally
        it.skip_newlines()

    # remove the flags that were specified but are anyway mandatory
    result &= ~future_flags.mandatory_flags

    return result, last_position
