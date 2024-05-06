$0 == "-----BEGIN CERTIFICATE-----" { idx = idx + 1; ofn = "cert-" idx ".pem" }
{ print $0 > ofn }
