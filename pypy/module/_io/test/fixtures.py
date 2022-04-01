from _pytest.tmpdir import TempdirFactory

def tempfile(space, config):
    tmpdir = TempdirFactory(config).getbasetemp()
    tempfile = (tmpdir / 'tempfile').ensure()
    return space.newtext(str(tempfile))
