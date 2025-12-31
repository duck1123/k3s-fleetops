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
        sleep 10
        # Try to verify proxy is accepting connections
        MAX_ATTEMPTS=12
        for i in $(seq 1 $MAX_ATTEMPTS); do
          # First check if proxy port is accessible using curl (works in curl image)
          if curl -sf --connect-timeout 3 --max-time 5 \
             --proxy http://${gluetunService}:8888 \
             --proxy-connect-timeout 3 \
             "http://1.1.1.1" > /dev/null 2>&1; then
            echo "Gluetun proxy is ready and working!"
            exit 0
          fi

          # If that fails, try a simpler test - just check if we can connect to the proxy port
          # Use curl to test TCP connectivity (curl can test without making HTTP request)
          if curl -sf --connect-timeout 2 --max-time 3 \
             "http://${gluetunService}:8888" > /dev/null 2>&1; then
            echo "Proxy port is accessible (attempt $i/$MAX_ATTEMPTS), but proxy requests may need more time..."
          else
            echo "Proxy port not accessible yet (attempt $i/$MAX_ATTEMPTS), waiting..."
          fi
          sleep 5
        done

        # If we get here, check VPN status one more time
        echo "Proxy test timed out after $MAX_ATTEMPTS attempts"
        echo "VPN status:"
        curl -sf http://${gluetunService}:8000/v1/openvpn/status || echo "Could not get VPN status"
        echo "Attempting final proxy test with longer timeout..."
        # Final attempt with longer timeout
        if curl -sf --connect-timeout 10 --max-time 15 \
           --proxy http://${gluetunService}:8888 \
           --proxy-connect-timeout 10 \
           "http://1.1.1.1" > /dev/null 2>&1; then
          echo "Gluetun proxy is ready!"
          exit 0
        fi

        echo "WARNING: Could not verify proxy connectivity, but continuing anyway..."
        echo "The proxy may still be initializing. Applications will retry if needed."
        exit 0
      ''
    ];
  }
]
