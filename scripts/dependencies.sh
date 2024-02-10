#!/bin/bash

echo "Installing ocb..."
mkdir -p ~/.local/bin
curl -L -o ~/.local/bin/ocb "https://github.com/open-telemetry/opentelemetry-collector/releases/download/cmd%2Fbuilder%2Fv0.94.1/ocb_0.94.1_linux_amd64"
chmod 755 ~/.local/bin/ocb
