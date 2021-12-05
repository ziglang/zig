#!/bin/sh

. ./ci/zinc/linux_base.sh

VERSION=$($RELEASE_STAGING/zig version)

# Avoid leaking oauth token.
set +x

cd $WORKSPACE
./ci/srht/on_master_success "$VERSION" "$SRHT_OAUTH_TOKEN"

# Explicit exit helps show last command duration.
exit
