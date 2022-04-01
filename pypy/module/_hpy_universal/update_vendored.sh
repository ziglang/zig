#!/bin/bash

RED='\033[0;31m'
YELLOW='\033[0;33;01m'
RESET='\033[0m' # No Color

set -e

# <argument parsing>
FORCE_VERSION=false
POSITIONAL=()
while [[ $# -gt 0 ]]
do
    key="$1"
    case $key in
        -f|--force-version)
            FORCE_VERSION=true
            shift # past argument
            ;;
        *)    # unknown option
            POSITIONAL+=("$1") # save it in an array for later
            shift # past argument
            ;;
    esac
done

if [ "${#POSITIONAL[@]}" -ne 1 ]; then
    echo "Usage: $0 [-f|--force-version] /path/to/hpy"
    exit 1
fi

HPY="${POSITIONAL[0]}"
# cd to pypy/module/_hpy_universal/ so we can use relative paths
cd $(dirname $0)
BASEDIR=$(cd ../../..; pwd)
# </argument parsing>

# ~~~ helper functions ~~~

indent() {
   sed 's/^/  /'
}

check_dirty() {
    if [[ $(git -C "$HPY" diff --stat) != '' ]]; then
        echo "WARNING! The source hpy repo is dirty"
        echo
    fi
}

check_version_status() {
    # we want to make sure that all possible sources git revision and/or
    # reported version match. In particular:
    #
    #  - hpy.devel.version.__git_revision__ should match the revision reported by git
    #  - hpy.devel.version.__version__ should match hpy.dist-info/METADATA

    pushd "$HPY/hpy/devel" > /dev/null
    sha_py=$(python -c 'import version;print(version.__git_revision__)')
    ver_py=$(python -c 'import version;print(version.__version__)')
    popd > /dev/null

    sha_git=$(git -C "$HPY" rev-parse --short HEAD)
    ver_dist=$(grep '^Version:' "$HPY/hpy.dist-info/METADATA" | cut -d ' ' -f 2)

    if [ "$sha_git -- $ver_dist" != "$sha_py -- $ver_py" ] 
    then
        if [ "$FORCE_VERSION" = true ]
        then
            admonition="${YELLOW}WARNING${RESET}"
        else
            admonition="${RED}ERROR${RESET}"
        fi

        echo -e "${admonition} hpy/devel/version.py and/or hpy.dist-info is outdated:"
        echo
        echo "  revision reported by git describe: $sha_git"
        echo "  revision in hpy/devel/version.py:  $sha_py"
        echo
        echo "  version in hpy.dist-info/METADATA: $ver_dist"
        echo "  version in hpy/devel/version.py:   $ver_py"
        echo

        if [ "$FORCE_VERSION" != true ]
        then
            echo "Please run setup.py dist_info in the hpy repo"
            exit 1
        fi
    fi
}

myrsync() {
    rsync --exclude '*~' --exclude '*.pyc' --exclude __pycache__ "$@" 
}

apply_patches() {
    # see also patches/README for more info

    fixmes=`ls patches/*FIXME*.patch | wc -l`
    if [ $fixmes -gt 0 ]
    then
        echo -e "${RED}REMINDER: there are ${fixmes} patches marked as FIXME${RESET}:"
        ls -1 patches/*FIXME*.patch | indent
    fi

    pushd ${BASEDIR} > /dev/null
    for FILE in pypy/module/_hpy_universal/patches/*.patch
    do
        patch -p1 < $FILE
        if [ $? -ne 0 ]
        then
            popd > /dev/null
            echo "${FILE}: patch failed, stopping here"
            echo "See patches/README for more details"
            exit 1
        fi
    done
    popd > /dev/null
    echo
}

# ~~~ main code ~~~

check_dirty
check_version_status

myrsync -a --delete ${HPY}/hpy/devel/ _vendored/hpy/devel/
myrsync -a --delete ${HPY}/hpy/debug/src/ _vendored/hpy/debug/src/
myrsync -a --delete ${HPY}/test/* ${BASEDIR}/extra_tests/hpy_tests/_vendored/
rsync -a --delete ${HPY}/hpy/debug/*.py ${BASEDIR}/lib_pypy/hpy/debug/
myrsync -a --delete ${HPY}/hpy/devel/ ${BASEDIR}/lib_pypy/hpy/devel/
myrsync -a --delete ${HPY}/hpy.dist-info ${BASEDIR}/lib_pypy/
apply_patches

echo -e "${YELLOW}GIT status${RESET} of $HPY"
git -C "$HPY" --no-pager log --oneline -n 1
git -C "$HPY" --no-pager diff --stat
echo
echo -e "${YELLOW}HG status${RESET} of pypy"
hg status
echo
echo -en "${YELLOW}HPy version${RESET}"
cat _vendored/hpy/devel/version.py
