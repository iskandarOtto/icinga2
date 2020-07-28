#!/bin/bash
set -exo pipefail

. .drone/setup.sh

cd /tmp
git clone https://git.icinga.com/packaging/rpm-icinga2.git
cd rpm-icinga2

ln -vs /drone/src/ccache .
icinga-build-package
ccache -s
