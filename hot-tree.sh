#!/usr/bin/env bash
echo "tree.dot" | entr -cr -s 'dot -T png -O tree.dot && feh -Z. tree.dot.png'

