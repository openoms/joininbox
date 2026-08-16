#!/usr/bin/env bats

@test "release preparation locks credentials and resets first-boot state" {
  run bash "$BATS_TEST_DIRNAME/test-prepare-release.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"all assertions passed"* ]]
}
