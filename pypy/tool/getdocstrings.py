import re
from os import listdir
from sys import stdin, stdout, stderr
from pypy import pypydir

where = pypydir + '/objspace/std/'
quote = '(' + "'" + '|' + '"' + ')'
triplequotes = '(' + "'''" + '|' + '"""' + ')'
# Note: this will produce erroneous result if you nest triple quotes
# in your docstring.

def mk_std_filelist():
    ''' go to pypy/objs/std and get all the *type.py files, except for
        typetype.py which has to be patched by hand.'''
    filelist = []
    filenames = listdir(where)
    for f in filenames:
        if f.endswith('type.py'):
            if f != 'typetype.py':
                filelist.append(f)
    return filelist


def compile_doc():
    return re.compile(r"__doc__\s+=\s+" + triplequotes +
                      r"(?P<docstring>.*)"+ triplequotes ,
                      re.DOTALL
                      )

def compile_typedef(typ):
    return re.compile(r"(?P<whitespace>\s+)"
                      + r"(?P<typeassign>" + typ
                      + "_typedef = StdTypeDef+\s*\(\s*"
                      + quote + typ +  quote + ",).*"
                      + r"(?P<indent>^\s+)"
                      + r"(?P<newassign>__new__\s*=\s*newmethod)",
                      re.DOTALL | re.MULTILINE)

def get_pypydoc(sourcefile):
    doc = compile_doc()

    try: # if this works we already have a docstring
        pypydoc = doc.search(sourcefile).group('docstring')

    except AttributeError: # No pypy docstring
        return None

    return pypydoc

def get_cpydoc(typ):
    # relies on being run by CPython.
    try:
        cpydoc = eval(typ + '.__doc__')

    except NameError: # No CPython docstring
        cpydoc = None
    return cpydoc

def add_docstring(typ, sourcefile):
    pypydoc = get_pypydoc(sourcefile)
    cpydoc = get_cpydoc(typ)

    if pypydoc:
        stderr.write('%s:  already has a pypy docstring\n' % typ)
        return None
    elif not cpydoc:
        stderr.write('%s:  does not have a cpython docstring\n' % typ)
        return None
    else:
        docstring="__doc__ = '''" + cpydoc + "''',"

        typedef = compile_typedef(typ)
        newsearch = typedef.search(sourcefile)
        if not newsearch:
            stderr.write('%s:  has a cpython docstring, but no __new__, to determine where to put it.\n' % typ)
            return None
        else:
            return re.sub(newsearch.group('indent') +
                          newsearch.group('newassign'),
                          newsearch.group('indent') +
                          docstring + '\n' +
                          newsearch.group('indent') +
                          newsearch.group('newassign'),
                          sourcefile)

if __name__ == '__main__':

    filenames = mk_std_filelist()

    for f in filenames:
        inf = file(where + f).read()
        outs = add_docstring(f[:-7], inf)
        if outs is not None:
            outf = file(where + f, 'w')
            outf.write(outs)
