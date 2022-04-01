from os import listdir
import glob, os.path, py, re

this_dir = os.path.realpath(os.path.dirname(__file__))
pypy_dir = os.path.realpath(os.path.join(this_dir, '..', '..'))

from pypy.tool.getdocstrings import quote, triplequotes
from pypy.tool.getdocstrings import mk_std_filelist

class TestDocStringInserter:
    def setup_method(self, method):
        self.fd1 = file(this_dir+'/fordocstrings1', 'r')
 
    def teardown_method(self, method):
        self.fd1.close()

    def test_mkfilelist(self):
        l = mk_std_filelist()
        l.sort()
        type_files = os.path.join(pypy_dir, "objspace/std/*type.py")
        not_wanted = ["typetype.py"]
        check = []
        for path in glob.glob(type_files):
            module = os.path.split(path)[1]
            if module not in not_wanted:
                check.append(module)
        check.sort()
        assert l == check

    def test_gottestfile(self):
        s = self.fd1.read()       # whole file as string

        s1 = 'from pypy.objspace.std.stdtypedef import *\n\n\n# ____________________________________________________________\n\nbasestring_typedef = StdTypeDef("basestring",\n    )\n'
        
        assert s == s1


    def test_compile_typedef(self):
        match = 'basestring'
        s = self.fd1.read()
        
        typedef = re.compile(r"(?P<whitespace>\s*)"
                            + r"(?P<typeassign>" + match
                            + "_typedef = StdTypeDef+\s*\(\s*"
                            + quote + match +  quote + ",)",
                            re.DOTALL
                             )
        
        tdsearch = typedef.search(s).group('typeassign')
        assert tdsearch
                 
        
        
        

        
