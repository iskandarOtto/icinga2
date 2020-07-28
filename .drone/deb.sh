#!/bin/bash
set -exo pipefail

. .drone/setup.sh

cd /tmp
git clone https://git.icinga.com/packaging/deb-icinga2.git
cd deb-icinga2

ln -vs /drone/src/ccache .
icinga-build-deb-source
icinga-build-deb-binary
ccache -s
