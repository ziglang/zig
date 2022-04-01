from _pytest.tmpdir import TempdirFactory

def tempfile(space, config):
        tmpdir = TempdirFactory(config).getbasetemp()
        return space.newtext(str(tmpdir / 'tempfile1'))
