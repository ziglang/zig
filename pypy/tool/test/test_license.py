import py, datetime

def test_license():
    lic = (py.path.local(__file__).dirpath().dirpath()
                                  .dirpath().dirpath().join('LICENSE'))
    text = lic.read()
    COPYRIGHT_HOLDERS="PyPy Copyright holders 2003-"
    assert COPYRIGHT_HOLDERS in text
    pos = text.find(COPYRIGHT_HOLDERS)
    year2 = text[pos+len(COPYRIGHT_HOLDERS):pos+len(COPYRIGHT_HOLDERS)+5]
    copyright_year = int(year2)
    cur_year = datetime.date.today().year
    assert copyright_year == cur_year
