{ lib }:
# Creates an init container that waits for gluetun to be ready
# Parameters:
#   gluetunService: The service name for gluetun (e.g., "gluetun.gluetun")
# Note: If gluetun control server requires authentication, the init containers
# may need access to the secret. For now, this assumes no auth or that the
# endpoint is accessible from within the cluster.
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
        MAX_ATTEMPTS=12
        for i in $(seq 1 $MAX_ATTEMPTS); do
          # Test if proxy actually works by making a request through it
          # Try multiple test URLs in case one is blocked
          PROXY_WORKING=false
          for TEST_URL in "http://www.google.com" "http://1.1.1.1" "http://8.8.8.8"; do
            if curl -sf --connect-timeout 5 --max-time 10 \
               --proxy http://${gluetunService}:8888 \
               --proxy-connect-timeout 5 \
               "$TEST_URL" > /dev/null 2>&1; then
              echo "Gluetun proxy is ready and working! (tested with $TEST_URL)"
              exit 0
            fi
          done
          
          # If proxy requests failed, check if port is at least accessible
          # Use a simple TCP connection test
          if timeout 2 bash -c "exec 3<>/dev/tcp/${gluetunService}/8888" 2>/dev/null; then
            exec 3<&-
            exec 3>&-
            echo "Proxy port is accessible but proxy requests failing (attempt $i/$MAX_ATTEMPTS), retrying..."
          else
            echo "Proxy port not accessible yet (attempt $i/$MAX_ATTEMPTS), waiting..."
          fi
          sleep 5
        done
        echo "ERROR: Gluetun proxy is not available after $MAX_ATTEMPTS attempts!"
        echo "VPN status:"
        curl -sf http://${gluetunService}:8000/v1/openvpn/status || echo "Could not get VPN status"
        echo "Testing proxy connectivity:"
        echo "  - Proxy port is accessible (connection established)"
        echo "  - But proxy requests are failing"
        echo "  - This may indicate the proxy is not fully initialized or there's a network issue"
        exit 1
      ''
    ];
  }
]
