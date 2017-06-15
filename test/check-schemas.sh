#!/bin/bash

set -eu

cd "$(dirname "${BASH_SOURCE[0]}")"
cd ../content/draft01

command -v jv >/dev/null || go get -u github.com/santhosh-tekuri/jsonschema/cmd/jv

for file in $(ls schemas); do
	jv "schemas/${file}" "examples/${file}"
done
