#! /bin/bash

# Edit these appropriately before running this script
pmaj=3  # python main version: 2 or 3
pmin=9  # python minor version
maj=7
min=3
rev=8
# rc=rc2  # comment this line for actual release

function maybe_exit {
    if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
        # script is being run, not "sourced" (as in "source repackage.sh")
        # so exit
        exit 1
    fi
}

case $pmaj in
    "2") exe=pypy;;
    "3") exe=pypy3;;
    *) echo invalid pmaj=$pmaj; maybe_exit
esac

branchname=release-pypy$pmaj.$pmin-v$maj.x # ==OR== release-v$maj.x  # ==OR== release-v$maj.$min.x
# tagname=release-pypy$pmaj.$pmin-v$maj.$min.$rev  # ==OR== release-$maj.$min
tagname=release-pypy$pmaj.$pmin-v$maj.$min.${rev}$rc  # ==OR== release-$maj.$min

echo checking hg log -r $branchname
hg log -r $branchname || maybe_exit
echo checking hg log -r $tagname
hg log -r $tagname || maybe_exit
hgrev=`hg id -r $tagname -i`

rel=pypy$pmaj.$pmin-v$maj.$min.${rev}$rc

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # script is being run, not "sourced" (as in "source repackage.sh")

    # The script should be run in an empty in the pypy tree, i.e. pypy/tmp
    if [ "`ls . | wc -l`" != "0" ]
    then
        echo this script must be run in an empty directory
        exit 1
    fi
fi

if [ -v rc ]
then
    wanted="\"$maj.$min.$rev${rc/rc/-candidate}\""
else
    wanted="\"$maj.$min.$rev\""
fi

function repackage_builds {
    # Download latest builds from the buildmaster, rename the top
    # level directory, and repackage ready to be uploaded 
    for plat in linux linux64 osx64 s390x aarch64 # linux-armhf-raspbian linux-armel
      do
        echo downloading package for $plat
        if wget -q --show-progress http://buildbot.pypy.org/nightly/$branchname/pypy-c-jit-latest-$plat.tar.bz2
        then
            echo $plat downloaded 
        else
            echo $plat no download available
            continue
        fi
        hgcheck=`tar -tf pypy-c-jit-latest-$plat.tar.bz2 |head -n1 | cut -d- -f5`
        if [ "$hgcheck" != "$hgrev" ]
        then
            echo xxxxxxxxxxxxxxxxxxxxxx
            echo $plat hg tag mismatch, expected $hgrev, got $hgcheck
            echo xxxxxxxxxxxxxxxxxxxxxx
            rm pypy-c-jit-latest-$plat.tar.bz2
            continue
        fi
        tar -xf pypy-c-jit-latest-$plat.tar.bz2
        rm pypy-c-jit-latest-$plat.tar.bz2

        # Check that this is the correct version
        if [ "$pmin" == "7" ] # python2.7, 3.7
        then
            actual_ver=$(grep PYPY_VERSION pypy-c-jit-*-$plat/include/patchlevel.h |cut -f3 -d' ')
        else
            actual_ver=$(grep PYPY_VERSION pypy-c-jit-*-$plat/include/pypy$pmaj.$pmin/patchlevel.h |cut -f3 -d' ')
        fi
        if [ $actual_ver != $wanted ]
        then
            echo xxxxxxxxxxxxxxxxxxxxxx
            echo version mismatch, expected $wanted, got $actual_ver for $plat
            echo xxxxxxxxxxxxxxxxxxxxxx
            exit -1
            rm -rf pypy-c-jit-*-$plat
            continue
        fi

        # Move the files into the correct directory and create the tarball
        plat_final=$plat
        if [ $plat = linux ]; then
            plat_final=linux32
        fi
        mv pypy-c-jit-*-$plat $rel-$plat_final
        echo packaging $plat_final
        tar --owner=root --group=root --numeric-owner -cjf $rel-$plat_final.tar.bz2 $rel-$plat_final
        rm -rf $rel-$plat_final
      done
    # end of "for" loop
    for plat in win64 # win32
      do
        if wget -q --show-progress http://buildbot.pypy.org/nightly/$branchname/pypy-c-jit-latest-$plat.zip
        then
            echo $plat downloaded 
        else
            echo $plat no download available
            continue
        fi
        unzip -q pypy-c-jit-latest-$plat.zip
        rm pypy-c-jit-latest-$plat.zip
        actual_ver=$(grep PYPY_VERSION pypy-c-jit-*-$plat/include/patchlevel.h |cut -f3 -d' ')
        if [ $actual_ver != $wanted ]
        then
            echo xxxxxxxxxxxxxxxxxxxxxx
            echo version mismatch, expected $wanted, got $actual_ver for $plat
            echo xxxxxxxxxxxxxxxxxxxxxx
            rm -rf pypy-c-jit-*-$plat
            continue
        fi
        mv pypy-c-jit-*-$plat $rel-$plat
        zip -rq $rel-$plat.zip $rel-$plat
        rm -rf $rel-$plat
      done
    # end of "for" loop
}

function repackage_source {
    # Requires a valid $tagname
    hg archive -r $tagname $rel-src.tar.bz2
    hg archive -r $tagname $rel-src.zip
}

function print_sha256 {
    # Print out the md5, sha1, sha256
    #md5sum *.bz2 *.zip
    #sha1sum *.bz2 *.zip
    sha256sum *.bz2 *.zip
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # script is being run, not "sourced" (as in "source repackage.sh")
    # so run the functions
    repackage_builds
    repackage_source
    print_sha256
fi
# Now upload all the bz2 and zip
