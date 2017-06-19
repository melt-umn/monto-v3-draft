#!/bin/bash

set -eu

function testDir() {
	cd "$(dirname "${BASH_SOURCE[0]}")/../content/$1"
	for file in *.json; do
		echo "Checking ${file}..."
		jv "${file}" "examples/${file}"
	done
}

command -v jv >/dev/null || go get -u github.com/santhosh-tekuri/jsonschema/cmd/jv

testDir draft01/messages
testDir draft01/products
