#!/bin/sh
printf '\033c\033]0;%s\a' Skalm
base_path="$(dirname "$(realpath "$0")")"
"$base_path/SkalmServer.x86_64" "$@"
