{ charts, config, lib, ... }:
with lib;
mkArgoApp { inherit config lib; } {
  name = "authentik";

  chart = lib.helm.downloadHelmChart {
    repo = "https://charts.goauthentik.io/";
    chart = "authentik";
    version = "2024.10.4";
    chartHash = "sha256-wMEFXWJDI8pHqKN7jrQ4K8+s1c2kv6iN6QxiLPZ1Ytk=";
  };

  defaultValues = cfg: with cfg; {
    authentik.error_reporting.enabled = true;
    global.env = [
      {
        name = "AUTHENTIK_SECRET_KEY";
        valueFrom.secretKeyRef = {
          name = "authentik-secret-key";
          key = "authentik-secret-key";
        };
      }
      {
        name = "AUTHENTIK_POSTGRESQL__PASSWORD";
        valueFrom.secretKeyRef = {
          name = "authentik-postgres-auth";
          key = "password";
        };
      }
    ];
    postgresql = {
      enabled = true;
      auth.existingSecret = "authentik-postgres-auth";
    };

    redis.enabled = true;

    server.ingress = with ingress; {
      enabled = true;
      inherit ingressClassName;
      annotations = {
        "cert-manager.io/cluster-issuer" = clusterIssuer;
        "ingress.kubernetes.io/force-ssl-redirect" = "true";
        "ingress.kubernetes.io/proxy-body-size" = "0";
        "ingress.kubernetes.io/ssl-redirect" = "true";
      };
      hosts = [ domain ];
      tls = [{
        secretName = "authentik-tls";
        hosts = [ domain ];
      }];
      https = false;
    };
  };

  extraResources = cfg: with cfg; {
    middlewares.middlewares-authentik.spec.forwardAuth = {
      address = "http://authentik-server/outpost.goauthentik.io/auth/traefik";
      trustForwardHeader = true;
      authResponseHeaders = [
        "X-authentik-username"
        "X-authentik-groups"
        "X-authentik-email"
        "X-authentik-name"
        "X-authentik-uid"
        "X-authentik-jwt"
        "X-authentik-meta-jwks"
        "X-authentik-meta-outpost"
        "X-authentik-meta-provider"
        "X-authentik-meta-app"
        "X-authentik-meta-version"
      ];
    };

    sealedSecrets = {
      authentik-postgres-auth.spec = {
        encryptedData = {
          password =
            "AgBewXweGi4YptsO3nHQcsBE6826U2XLpNA25w55vmKUF1PkKc1b/Y6qJ9NxJ/ixw5qi8SOq6eQSAXfAFkTkCNkeVMYa6yIBhT78eWe7JbBAnS+xA5IF1NCgxlVJn4x57n7BNspnlFycaIvOo7+6WOUzuqgYevx03Dw48FFcUWqbO5m9RzW7xGNICqAfsK5BsxqfEZLqXeUYL/+n4rpiV7Z9dJu8YsE6u+bSzq6NenAj9pl8nj0CTOIAEgCPqt9NcQqyg0NS9aoinc6kn5aDl0/PpA283hRVGMmw3S8flc+If/Toeys7gdMmv00n5npHraKEF05F5SAAEbIM65jGHxYEbD9mn541rXGL7oL5BUtFMif1lSaIBhPGR0M1nmIGlAfaWMVXpgWGEBOOscvLFs4FvgLiNVSHWZtnSz3BXHwiUHETbZYY09LmjnaXfs1VEuHPssg2yIBJ5bRDkE5wIwrrJsqraFmvFGqfbOJdrsHqekoUTbY1h3vJsR1vL1EG30oi1c/kI++bjixzWq5Lyqv2tKZt6a0Xo70AzvS5cnsgxmOHE/6ETM00ywHnUYn+PVx23G9/pDbQWN3S4LfU1H6X7kXaQ07wyF6sBJZH2SoTSMk6K0I0qq5YWAg7Vl04WsKBkrVA8H3vZlcFxOXysxzEqtF9Ouqh6nMzdPZMYm5y8NrvbaZEkiLiMVgAV7EfSCu8CAfEnBDf5QktvK9X1qW0mRQToA==";
          postgres-password =
            "AgCpGUzCChbnGiuvrxgmN3RyFTTvtNwV+cq7/sCuO9MRvV3J0lZYf6lrpFSTzlG7pYNqaV4aiUfsg2V/OM8v66in6NlpL4AfXiZWso+BK+dsPeECIC1CWFzDF7muM1Y4k/1wSZuLF0nov5faR7XRhWyZjLO6Z0nU8/cMPdC8dPRBFUnnJtRqnwrvG6iAwatQMyJj3Z5bm1bkPFwCEKjlTOFHu59FeEP9vsatLcpkeT20AOai1qYZOR2Ujc1+q09rzWMNWHpTYTxOpfIJ/s4m06JJvmh9bsCxyMMzjpHfDSWiUZ5sm2YP/4mnIDCB3NW6JWNugJEj2hxsXumG/eeLuSEdLG1Y4ytfzPlVXZR4j2jO9+6Xe4CpyBU/jz/x2oererp8DIbHm0WHozrzA0MXsciEoR88omIq4OSSEuArqVbYz5AP+uf7EuWAvcbM3a2PtKEwDz2iJdazqForncIAQ0Kf2xVnT82v3vPZls57dusoVrklyad04IYckA+CQxWvY2wlSuZOMb3kfSCQ3OcgLSv8NsQP3X5BFdM22/t1/B0bGsR1K1NuU+zTu3iYALqH27zxJC3LC64sQu1CQi6XprkFKlCMzodJKrcenhRofioCUpctU1IhfjPaPgAGyrQDwUDpgV5sYF9huB4+vQG/pSwoZsfKOqlte1ScdS2Pe5QNG8h4Ch4r5UVQeAamUV4h01WNy+0mpMlC6GLwOMyCBbEcouSNVw==";
          replicationPasswordKey =
            "AgBxWNZdr/Y/j3fVPyuXxDFqDZzKKkXAtM1+XLoP7HxosF5IVTVqLiPQ9MGNNZcTztQmksXwleTc3qjKgs80chlf8tgho9eFgbxOkQaZZouyt2D3LbVITEt8qp4wO07tFgiFwp9xRAWW0sflmOVUV04NxysopROi9OM8cVuZgt+h1jMQQWC2sckBBqaZnhso1sBaK5hDGydrLL/w5TlwsGhTiN98/ZCsqcvyExch1ZOBthRDA6Xkq5xRU+3vitRpZ+wL9h0tsVDgsdh1CIyjDFriIiFlXaShGtwnTgUorKmbhLzuCQ7tqIkEl17DGIbAEJmsN0Ihzvmt8IYJCycCLg4HdxX8yv5xbqFfVV/wCfwYVxv6vrgayeutPo76/sRaz2QUx2SzgGGZ+ZsaL54V70kk3noEWyRKBizyS/jybsLntLvbd4ITiBW0ZatT2cfTw+sMcdp+Mc0vtrEVAQ2Sj0rs1NwiQc1/w0x+O6FBcQF26MzPaZ9J7t9I2mjuZEcPhF9PPs4SgEU8KRRo9Uhuh4PLWKYMTwubYQ1szVJJ7uOx89ucw1eGiqB9NocUBVgxnCO1grVE/nAjO85K34dWwaVSSg8WF23xgvL9FnKiabdGj/qVemVcXJk5T4+pRG8PBgqotUJXaYKOiz/hjIf90OJCB3S6s7bd+wJj9uXGG8fQ3olg1hYY/fkgl6B29rOWiMryA5CSbiqeRB8CnJhIbedzXjEZvw==";
        };

        template.metadata = {
          inherit namespace;
          name = "authentik-postgres-auth";
        };
      };
      authentik-secret-key.spec = {
        encryptedData = {
          authentik-secret-key =
            "AgBsNcUtKevE0I7tVvm90pGZ8f/dRv0G6AIgrOPMEcq/zGhrCnNb9LESdzCBagw2n3vVKlPkE+D9on+ZGD9KMUjosnzIcT38lcvwtMJY0b4sKPMcrJkxvz4Bc1EpMLdjrCu5iq1RjqePrUh73x45/qnePUcKJMEgP+D526trdBZNrfuMQFUr605hkN/g/T4pnjDlJoUyaiHgJw6dbKAp6pKj8oGM8deqI50Ys15dXoLsD/fQNpA+y4L+9b0ycs+SCY65YhPnMk8hH3Vje/UMaAxhsywycGD6KIpW0kQmIhYFWHvF2sU3TWLlwbW7Qc4ke8OFEhhek6v6B8sJMGy6ZzN3qz4UANwWcQFzZptIdt/pzKlGoE3RuKBMz2l4Nq0yF4sfolQzw3+Urnwr7P+iUtvUYFlQWDRY9+Z6wdm8AjVMroIksBwJM43+lkgvxz72Q3+gtgZR0FhOehQXlKssWmnikUkRp6YYfV336xHzt0PNYCk33qkQA9gr2wwhOq6AjFM6nfEuXRAl36nnqX/95P1OeDHqUyCi1N61tjr6xoWrNMVQPaz8Ss8qH3kcOXwzJ/ssliZpdBOa9TZIxoryXiiXIN82xQZckQVegsv/YKR4rtSw2DtNeuMxSjlQVK7fEzqj+w3blnmPWQsUnPxSLsaB953uHDJPM1KtFo0omGo1bMqKnJw1TdxikFi9V/3aMDVzTbiDxXpmQH9CXMh4gn8Ji3hW9w==";
        };
        template.metadata = {
          inherit namespace;
          name = "authentik-secret-key";
        };
      };
    };
  };
}
