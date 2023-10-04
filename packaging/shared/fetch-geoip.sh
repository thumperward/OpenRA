#! /bin/bash
# Download the IP2Location country database for use by the game server
set -euo pipefail

cd "$(dirname "$0")"

# Database does not exist or is older than 30 days.
if [ -z "$(find . -path ../../res/IP2LOCATION-LITE-DB1.IPV6.BIN.ZIP -mtime -30 -print)" ]; then
	rm -f ../../res/IP2LOCATION-LITE-DB1.IPV6.BIN.ZIP || :
	echo "Downloading IP2Location GeoIP database."
	if command -v curl >/dev/null 2>&1; then
		curl -s -L -o ../../res/IP2LOCATION-LITE-DB1.IPV6.BIN.ZIP https://github.com/OpenRA/GeoIP-Database/releases/download/monthly/IP2LOCATION-LITE-DB1.IPV6.BIN.ZIP || echo "Warning: Download failed"
	else
		wget -cq -O ../../res/IP2LOCATION-LITE-DB1.IPV6.BIN.ZIP https://github.com/OpenRA/GeoIP-Database/releases/download/monthly/IP2LOCATION-LITE-DB1.IPV6.BIN.ZIP || echo "Warning: Download failed"
	fi
fi
