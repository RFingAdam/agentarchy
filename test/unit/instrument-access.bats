#!/usr/bin/env bats
#
# Hardware access, which is the concrete reason this distribution is worth running for bench work.
#
# An MCP server that opens /dev/ttyUSB0 is correct code and fails on a stock Arch install: nothing
# grants the device, and every setup guide written on Debian says to join "dialout", a group Arch
# does not have. Following those instructions here does nothing at all.

setup() {
  SRC="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  export PATH="$SRC/bin:$PATH"
  RULES="$SRC/default/udev/oal-instruments.rules"
  STEP="$SRC/install/hardware/instrument-access.sh"
}

@test "the rules grant through uaccess and uucp, never dialout" {
  # uaccess covers the person at the keyboard; uucp covers an ssh or headless session, which is how
  # an unattended agent reaches a bench. dialout would be a no-op on Arch.
  # Rule lines only. The header explains the Debian difference and names dialout to do so, and a
  # grep over the whole file matches that prose -- the fourth time a check here has failed on its
  # own explanation.
  grep -q 'TAG+="uaccess"' "$RULES"
  grep -q 'GROUP="uucp"' "$RULES"
  ! grep -E '^[^#]*dialout' "$RULES" | grep -q .
}

@test "every rule line grants both mechanisms" {
  # A line with uaccess and no group works at the desk and fails over ssh; a line with a group and no
  # uaccess needs a logout to take effect. Half a rule is the kind that gets diagnosed for an hour.
  local line
  while IFS= read -r line; do
    [[ $line =~ ^(SUBSYSTEM|KERNEL) ]] || continue
    [[ $line == *'TAG+="uaccess"'* ]] || { echo "no uaccess: $line"; return 1; }
    [[ $line == *'GROUP="uucp"'* ]] || { echo "no uucp group: $line"; return 1; }
  done <"$RULES"
}

@test "the serial bridges an engineer actually plugs in are covered" {
  # FTDI, CP210x, CH340, Espressif, Nordic. Vendor IDs, so a new part number needs no edit here.
  local id
  for id in 0403 10c4 1a86 303a 1915; do
    grep -q "idVendor}==\"$id\"" "$RULES" || { echo "no rule for vendor $id"; return 1; }
  done
}

@test "USBTMC is matched by class, not by vendor" {
  # Scopes, VNAs and signal generators speak this. Matching the class covers instruments nobody
  # thought to list, which is the failure mode a vendor table has.
  grep -q 'bInterfaceClass}=="fe"' "$RULES"
  grep -q 'usbtmc' "$RULES"
}

@test "the install step records the group for the deferred path as well as granting it" {
  # A deferred-provisioning install creates the user at first boot, long after this runs, so the
  # group has to be written down as well as applied. Same shape as input-group.sh.
  grep -q 'provisioning' "$STEP"
  grep -q 'usermod -aG uucp' "$STEP"
}

@test "the doctor understands both distributions" {
  # python is python3 on Arch and may not exist as "python" on Debian. Reporting it missing on a
  # machine that has python3 is the same distro-shaped mistake this command exists to catch.
  grep -q '"${cmd}3"' "$SRC/bin/oal-mcp-doctor"
  grep -q 'dialout' "$SRC/bin/oal-mcp-doctor"
}

@test "the doctor reports rather than fails" {
  # It runs on a machine that is by definition not working properly. Exiting non-zero would make it
  # the thing that breaks someone's shell pipeline while they debug.
  run oal-mcp-doctor
  [ "$status" -eq 0 ]
  [[ $output == *"runtimes an MCP server needs"* ]]
}
