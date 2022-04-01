import sys
import os
import re
import json

import pytest
from pypy import pypydir
import pypy.interpreter.function
from pypy.tool.pytest import app_rewrite
from pypy.interpreter.error import OperationError
from pypy.interpreter.module import Module
from pypy.tool.pytest import objspace
from pypy.tool.pytest import appsupport
from pypy.tool.pytest.astrewriter.ast_rewrite import rewrite_asserts_ast


class AppTestModule(pytest.Module):
    def __init__(self, path, parent, rewrite_asserts=False):
        super(AppTestModule, self).__init__(path, parent)
        self.rewrite_asserts = rewrite_asserts

    def collect(self):
        _, source = app_rewrite._prepare_source(self.fspath)
        spaceconfig = extract_spaceconfig_from_source(source)
        space = objspace.gettestobjspace(**spaceconfig)
        w_rootdir = space.newtext(
            os.path.join(pypydir, 'tool', 'pytest', 'ast-rewriter'))
        w_source = space.newtext(source)
        fname = str(self.fspath)
        w_name = space.newtext(str(self.fspath.purebasename))
        w_fname = space.newtext(fname)
        if self.rewrite_asserts:
            # actually a w_code, but works fine with space.exec_
            source = space._cached_compile(
                fname, source, "exec", 0, False,
                ast_transform=rewrite_asserts_ast)
        w_mod = create_module(space, w_name, fname, source)
        mod_dict = w_mod.getdict(space).unwrap(space)
        items = []
        for name, w_obj in mod_dict.items():
            if not name.startswith('test_'):
                continue
            if not isinstance(w_obj, pypy.interpreter.function.Function):
                continue
            items.append(AppTestFunction(name, self, w_obj))
        items.sort(key=lambda item: item.reportinfo()[:2])
        return items

    def setup(self):
        pass

def create_module(space, w_name, filename, source):
    w_mod = Module(space, w_name)
    w_dict = w_mod.getdict(space)
    space.setitem(w_dict, space.newtext('__file__'), space.newtext(filename))
    space.exec_(source, w_dict, w_dict, filename=filename)
    return w_mod

def extract_spaceconfig_from_source(source):
    '''
    spaceconfig is defined in a comment where it can be any valid json dictionary object
    '''
    for line in source.split('\n'):
        match = re.search('#\s*spaceconfig\s*=\s*(\{.+\})\s*', line)
        if match:
            return json.loads(match.group(1))
    return {}

class AppError(Exception):

    def __init__(self, excinfo):
        self.excinfo = excinfo


class AppTestFunction(pytest.Item):

    def __init__(self, name, parent, w_obj):
        super(AppTestFunction, self).__init__(name, parent)
        self.w_obj = w_obj

    def runtest(self):
        target = self.w_obj
        space = target.space
        self.check_run(space, target)
        self.execute_appex(space, target)

    def repr_failure(self, excinfo):
        if excinfo.errisinstance(AppError):
            excinfo = excinfo.value.excinfo
        return super(AppTestFunction, self).repr_failure(excinfo)

    def check_run(self, space, w_func):
        space.appexec([w_func], """(func):
            if hasattr(func, 'skipif'):
                marker = func.skipif
                arg = marker.args[0]
                if isinstance(arg, str):
                    raise ValueError("str argument to skipif isn't supported")
                else:
                    if arg:
                        import pytest
                        reason = marker.kwargs.get('reason', "Skipping.")
                        pytest.skip(reason)
            """)

    def execute_appex(self, space, w_func):
        space.getexecutioncontext().set_sys_exc_info(None)
        sig = w_func.code._signature
        if sig.varargname or sig.kwargname or sig.num_kwonlyargnames():
            raise ValueError(
                'Test functions may not use *args, **kwargs or '
                'keyword-only args')
        args_w = self.get_fixtures(space, sig.argnames)
        try:
            space.call_function(w_func, *args_w)
        except OperationError as e:
            if self.config.option.raise_operr:
                raise
            tb = sys.exc_info()[2]
            if e.match(space, space.w_KeyboardInterrupt):
                raise KeyboardInterrupt, KeyboardInterrupt(), tb
            appexcinfo = appsupport.AppExceptionInfo(space, e)
            if appexcinfo.traceback:
                raise AppError, AppError(appexcinfo), tb
            raise

    def reportinfo(self):
        """Must return a triple (fspath, lineno, test_name)"""
        lineno = self.w_obj.code.co_firstlineno
        return self.parent.fspath, lineno, self.w_obj.name

    def get_fixtures(self, space, fixtures):
        if not fixtures:
            return []
        import imp
        fixtures_mod = imp.load_source(
            'fixtures', str(self.parent.fspath.new(basename='fixtures.py')))
        result = []
        for name in fixtures:
            arg = getattr(fixtures_mod, name)(space, self.parent.config)
            result.append(arg)
        return result
