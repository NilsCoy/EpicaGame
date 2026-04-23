#!/bin/sh
printf '\033c\033]0;%s\a' Epica
base_path="$(dirname "$(realpath "$0")")"
"$base_path/EpicaServer.x86_64" "$@"
