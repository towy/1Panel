#!/bin/bash
#Install Latest 1Panel Release from GitHub without checksum verification

# Define GitHub repo
GITHUB_REPO="towy/1Panel"

# Determine system architecture
architecture=$(uname -m)
case $architecture in
    x86_64)
        architecture="amd64"
        ;;
    arm64 | aarch64)
        architecture="arm64"
        ;;
    arm*)
        architecture="armv7"
        ;;
    ppc64le)
        architecture="ppc64le"
        ;;
    s390x)
        architecture="s390x"
        ;;
    *)
        echo "Unsupported system architecture. Please refer to the official documentation for a list of supported systems."
        exit 1
        ;;
esac

# Fetch the latest release from GitHub
VERSION=$(curl -s "https://api.github.com/repos/$GITHUB_REPO/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')

if [[ -z "$VERSION" ]]; then
    echo "Failed to fetch the latest version. Please try again later."
    exit 1
fi

# Construct the download URL
package_file_name="1panel-${VERSION}-linux-${architecture}.tar.gz"
package_download_url="https://github.com/$GITHUB_REPO/releases/download/${VERSION}/${package_file_name}"

echo "Starting to download 1Panel ${VERSION} version package"
echo "Download URL: ${package_download_url}"

# Download the package
curl -LO "${package_download_url}"

if [ ! -f "${package_file_name}" ]; then
    echo "Failed to download the package. Please try again later."
    exit 1
fi

# Extract and install
tar zxvf "${package_file_name}"
cd "1panel-${VERSION}-linux-${architecture}"

/bin/bash install.sh
