#!/bin/sh

echo "$(git describe --abbrev=0 --tags | awk -F. '{ print $1 "." $2 }').$(git rev-list HEAD --count)"
