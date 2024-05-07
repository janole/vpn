#!/bin/sh

VERSION="$(./version.sh)" docker buildx bake
