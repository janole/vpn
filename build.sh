#!/bin/sh

VERSION=$(git describe --tags).$(git rev-list HEAD --count) docker buildx bake
