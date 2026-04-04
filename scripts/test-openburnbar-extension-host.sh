#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"

npm --prefix "$repo_root/extensions/openburnbar" run test:extension-host
