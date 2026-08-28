#!/bin/bash

# Focused regression checks for machine-specific getVar processing limits.

set -o errexit
set -o nounset
set -o pipefail

TEST_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
CORE_DIR=$(cd -- "$TEST_DIR/../../scripts/core" && pwd)
TEST_TMP=$(mktemp -d)

trap 'rm -rf -- "$TEST_TMP"' EXIT

DEBUGLEVEL=0
# shellcheck source=../scripts/core/fun_colMsg.sh
source "$CORE_DIR/fun_colMsg.sh"
# shellcheck source=../scripts/core/fun_machineProfile.sh
source "$CORE_DIR/fun_machineProfile.sh"

assert_profile() {
	local hostname=$1
	local expected_comp=$2
	local expected_min=$3
	local expected_max=$4
	local expected_order=$5

	setMachineProfile "$hostname" 2> "$TEST_TMP/stderr"

	[[ $COMP == "$expected_comp" ]]
	[[ $minsize == "$expected_min" ]]
	[[ $maxsize == "$expected_max" ]]
	[[ $ORDER == "$expected_order" ]]
}

# Exact, case-insensitive, and fully qualified forms must select Monster.
assert_profile Monster monster 100000000 250000000000 size
assert_profile MONSTER monster 100000000 250000000000 size
assert_profile Monster.example.org monster 100000000 250000000000 size
[[ ! -s $TEST_TMP/stderr ]]

# Preserve the established profiles and the historical COMP alias.
assert_profile beast beast 100000000 250000000000 size
assert_profile PWE-T630-TEFOR-2 beast 1000000000 250000000000 size
assert_profile celph-gif celph-gif 1000000 6000000000 size
assert_profile tefor-gif tefor-gif 1000000 20000000000 age
assert_profile celph-lyon celph-lyon 1000000 6000000000 size

# Unknown hosts use the conservative default and make that fallback visible.
assert_profile new-worker new-worker 1000000 4000000000 age
grep -Fq "No processing profile is configured for host 'new-worker'" \
	"$TEST_TMP/stderr"

printf 'PASS: machine profile checks completed.\n'
