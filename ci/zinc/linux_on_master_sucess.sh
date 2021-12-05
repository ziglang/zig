#!/bin/sh

. ./ci/zinc/linux_base.sh

VERSION=$(cat $WORKSPACE/env.version)

# Avoid leaking oauth token.
set +x

cd $WORKSPACE
./ci/srht/on_master_success "$VERSION" "$SRHT_OAUTH_TOKEN"

# Explicit exit helps show last command duration.
exit
