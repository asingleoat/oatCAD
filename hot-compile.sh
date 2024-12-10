#!/usr/bin/env bash
ls src/* build.zig build.zig.zon | entr -c -r zig build --summary all
