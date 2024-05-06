#!/bin/bash -e

source ${0%/*}/setup.sh

exec "$DSS_DATADIR"/bin/dss run
