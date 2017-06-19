#!/bin/bash

set -eu

cd "$(dirname "${BASH_SOURCE[0]}")"
cd ..

command -v htmltest >/dev/null || go get -u github.com/wjdp/htmltest

if [[ ! -d public ]]; then
	cd ..
	command -v hugo >/dev/null || go get -u github.com/gohugoio/hugo
	hugo
	cd test
fi

htmltest public
