#!/bin/bash

# Define paths
BASE_PATH=$(pwd)
BUILD_PATH="$BASE_PATH/build"
INSTALL_PATH="$BASE_PATH/install"
RELEASES_PATH="$BASE_PATH/releases"

# Define version
VERSION="v1.10.2-lts"

# Ensure the releases directory exists
mkdir -p "$RELEASES_PATH"

package_and_move() {
    # Loop through the binary files
    for binary in "$BUILD_PATH"/1panel-${VERSION}-linux-*; do
        # Extract the architecture part from the binary filename
        arch=$(basename "$binary" | cut -d'-' -f5)
        
        # Define the final archive name based on version and architecture
        final_archive_name="1panel-${VERSION}-linux-${arch}.tar.gz"
        
        # Copy the binary to the install directory and rename it as '1panel'
        cp "$binary" "$INSTALL_PATH/1panel"
        
        # Pack the '1panel' binary and all other files in INSTALL_PATH into a tar.gz archive
        (cd "$INSTALL_PATH" && tar -czvf "$RELEASES_PATH/$final_archive_name" *)

        # Clean up by removing the temporary binary in the install directory
        rm "$INSTALL_PATH/1panel"

        # Optionally, you might want to perform other actions after packaging
    done

    echo "Packaging and moving binaries completed."
}

# Call the function
package_and_move
