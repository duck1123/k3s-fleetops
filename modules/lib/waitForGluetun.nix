{ ... }:
{
  flake.lib.waitForGluetun =
    { ... }:
    # Creates an init container that waits for gluetun to be ready
    # Parameters:
    #   gluetunService: The service name for gluetun (e.g., "gluetun.gluetun")
    gluetunService: [
      {
        name = "wait-for-gluetun";
        image = "curlimages/curl:latest";
        command = [ "sh" ];
        args = [
          "-c"
          ''
            echo "Waiting for gluetun VPN connection..."
            until curl -sf http://${gluetunService}:8000/v1/openvpn/status | grep -q '"status":"running"'; do
              sleep 5
            done
            echo "VPN connection established"
            # Wait for proxy to initialize
            sleep 10
            # Simple proxy connectivity test
            if curl -sf --connect-timeout 5 --max-time 10 \
               --proxy http://${gluetunService}:8888 \
               --proxy-connect-timeout 5 \
               "http://1.1.1.1" > /dev/null 2>&1; then
              echo "Proxy ready"
              exit 0
            fi
            # If test fails, continue anyway - applications will retry
            echo "Proxy test failed, continuing anyway"
            exit 0
          ''
        ];
      }
    ];

}
