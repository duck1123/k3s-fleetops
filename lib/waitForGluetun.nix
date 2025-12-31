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
        # Try to verify proxy is accepting connections and working
        MAX_ATTEMPTS=15
        for i in $(seq 1 $MAX_ATTEMPTS); do
          # Test proxy by making an actual request through it
          # Try multiple test URLs in case one is blocked
          for TEST_URL in "http://1.1.1.1" "http://8.8.8.8" "http://www.google.com"; do
            if curl -sf --connect-timeout 5 --max-time 10 \
               --proxy http://${gluetunService}:8888 \
               --proxy-connect-timeout 5 \
               "$TEST_URL" > /dev/null 2>&1; then
              echo "Gluetun proxy is ready and working! (tested with $TEST_URL)"
              exit 0
            fi
          done

          echo "Proxy not ready yet (attempt $i/$MAX_ATTEMPTS), waiting..."
          sleep 5
        done

        # If we get here, check VPN status one more time
        echo "Proxy test timed out after $MAX_ATTEMPTS attempts"
        echo "VPN status:"
        curl -sf http://${gluetunService}:8000/v1/openvpn/status || echo "Could not get VPN status"
        echo ""
        echo "Attempting final proxy test with longer timeout..."
        # Final attempt with longer timeout
        if curl -sf --connect-timeout 15 --max-time 20 \
           --proxy http://${gluetunService}:8888 \
           --proxy-connect-timeout 15 \
           "http://1.1.1.1" > /dev/null 2>&1; then
          echo "Gluetun proxy is ready!"
          exit 0
        fi

        echo ""
        echo "WARNING: Could not verify proxy connectivity after all attempts."
        echo "The proxy may still be initializing or there may be a network issue."
        echo "Continuing anyway - applications will retry connections if needed."
        exit 0
      ''
    ];
  }
]
