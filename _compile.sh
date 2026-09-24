#!/bin/sh
# Project: Tiko Editor
# File: _compile.sh
# Purpose: Build the native FreeBASIC application on Unix-like systems.
# Responsibilities: locate the repository and compile src/tiko.bas with omaGUI.
# This script intentionally does not package the legacy Windows application.

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd) || exit 1
cd "$script_dir" || exit 1
mkdir -p bin || exit 1
fbc -i src/omaGUI-main src/tiko.bas -x bin/tiko
result=$?

# end of _compile.sh
exit "$result"
