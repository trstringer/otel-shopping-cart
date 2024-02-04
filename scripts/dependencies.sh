#!/bin/bash

echo "Installing ocb..."
mkdir -p /home/runner/.local/bin
curl -L -o /home/runner/.local/bin/ocb "https://github.com/open-telemetry/opentelemetry-collector/releases/download/cmd%2Fbuilder%2Fv0.93.0/ocb_0.93.0_linux_amd64"
echo "Running which..."
which ocb
# which ocb
