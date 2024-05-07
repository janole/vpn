#!/bin/sh

echo "$(git describe --abbrev=0 --tags).$(git rev-list HEAD --count)"
