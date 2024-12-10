#!/usr/bin/env bash
ls src/* | entr -c -r zig build --summary all
