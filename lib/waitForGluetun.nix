{ lib }:
# Creates an init container that waits for gluetun to be ready
# Parameters:
#   gluetunService: The service name for gluetun (e.g., "gluetun.gluetun")
gluetunService: [
  {
    name = "wait-for-gluetun";
    image = "curlimages/curl:latest";
    command = ["sh"];
    args = [
      "-c"
      ''
        echo "Waiting for gluetun VPN connection..."
        until curl -sf http://${gluetunService}:8000/v1/openvpn/status | grep -q '"status":"running"'; do
          echo "VPN not connected yet, waiting..."
          sleep 5
        done
        echo "VPN connection established!"
        echo "Waiting for proxy to be ready..."
        # Wait additional time for proxy to fully initialize after VPN connects
        sleep 15
        # Try to verify proxy is accepting connections by attempting a simple proxy request
        for i in $(seq 1 6); do
          # Try to connect through the proxy - if it accepts the connection, proxy is working
          if curl -sf --connect-timeout 5 --max-time 10 \
             --proxy http://${gluetunService}:8888 \
             --proxy-connect-timeout 5 \
             http://www.google.com > /dev/null 2>&1; then
            echo "Gluetun proxy is ready and working!"
            exit 0
          fi
          echo "Proxy not ready yet (attempt $i/6), waiting..."
          sleep 5
        done
        echo "Warning: Could not verify proxy connectivity, but continuing anyway..."
      ''
    ];
  }
]
