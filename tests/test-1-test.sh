#!/usr/bin/env roundup
#
#/ usage:  rerun stubbs:test -m chart-mate -p test [--answers <>]
#

# Helpers
# -------
[[ -f ./functions.sh ]] && . ./functions.sh

# The Plan
# --------
describe "test"

# ------------------------------
# Replace this test. 
it_fails_without_a_real_test() {
    exit 1
}
# ------------------------------

