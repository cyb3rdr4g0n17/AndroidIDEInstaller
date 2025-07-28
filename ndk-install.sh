#!/bin/bash

# Fixed Script to install NDK into AndroidIDE
# Author MrIkso (Modified to fix download issues)

install_dir=$HOME
sdk_dir=$install_dir/android-sdk
cmake_dir=$sdk_dir/cmake
ndk_base_dir=$sdk_dir/ndk

ndk_dir=""
ndk_ver=""
ndk_ver_name=""
ndk_file_name=""
ndk_installed=false
cmake_installed=false
is_lzhiyong_ndk=false
is_musl_ndk=false

# Function to download with retry and resume capability
download_with_retry() {
    local url=$1
    local filename=$2
    local max_attempts=5
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        echo "Download attempt $attempt/$max_attempts for $filename..."
        
        # Use wget with resume capability and timeout
        if wget "$url" -O "$filename" --continue --timeout=30 --tries=3 --no-verbose --show-progress; then
            # Verify the download completed successfully
            if [ -f "$filename" ] && [ -s "$filename" ]; then
                echo "Download completed successfully: $filename"
                return 0
            else
                echo "Download failed: file is empty or doesn't exist"
                rm -f "$filename"
            fi
        else
            echo "Download failed for $filename (attempt $attempt)"
            rm -f "$filename"
        fi
        
        attempt=$((attempt + 1))
        if [ $attempt -le $max_attempts ]; then
            echo "Waiting 10 seconds before retry..."
            sleep 10
        fi
    done
    
    echo "Failed to download $filename after $max_attempts attempts"
    return 1
}

# Function to verify file integrity
verify_file() {
    local filename=$1
    local filetype=$2
    
    if [ ! -f "$filename" ]; then
        echo "Error: $filename does not exist"
        return 1
    fi
    
    if [ ! -s "$filename" ]; then
        echo "Error: $filename is empty"
        return 1
    fi
    
    # Test if it's a valid archive
    if [ "$filetype" = "zip" ]; then
        if ! unzip -t "$filename" >/dev/null 2>&1; then
            echo "Error: $filename is not a valid zip file"
            return 1
        fi
    elif [ "$filetype" = "tar.xz" ]; then
        if ! tar -tf "$filename" >/dev/null 2>&1; then
            echo "Error: $filename is not a valid tar.xz file"
            return 1
        fi
    fi
    
    echo "File verification passed: $filename"
    return 0
}

run_install_cmake() {
    download_cmake 3.10.2
    download_cmake 3.18.1
    download_cmake 3.22.1
    download_cmake 3.25.1
}

download_cmake() {
    # download cmake
    cmake_version=$1
    cmake_file="cmake-${cmake_version}-android-aarch64.zip"
    cmake_url="https://github.com/MrIkso/AndroidIDE-NDK/releases/download/cmake/${cmake_file}"
    
    echo "Downloading cmake-$cmake_version..."
    
    if download_with_retry "$cmake_url" "$cmake_file"; then
        if verify_file "$cmake_file" "zip"; then
            installing_cmake "$cmake_version"
        else
            echo "Failed to verify cmake file: $cmake_file"
            rm -f "$cmake_file"
        fi
    else
        echo "Failed to download cmake-$cmake_version"
    fi
}

download_ndk() {
    local filename=$1
    local url=$2
    
    echo "Downloading NDK $filename..."
    
    if download_with_retry "$url" "$filename"; then
        if [[ $filename == *.tar.xz ]]; then
            verify_file "$filename" "tar.xz"
        else
            verify_file "$filename" "zip"
        fi
    else
        echo "Failed to download NDK: $filename"
        return 1
    fi
}

fix_ndk() {
    # create missing link
    if [ -d "$ndk_dir" ]; then
        echo "Creating missing links..."
        cd "$ndk_dir"/toolchains/llvm/prebuilt || exit
        ln -sf linux-aarch64 linux-x86_64
        cd "$ndk_dir"/prebuilt || exit
        ln -sf linux-aarch64 linux-x86_64
        cd "$install_dir" || exit

        # patching cmake config
        echo "Patching cmake configs..."
        sed -i 's/if(CMAKE_HOST_SYSTEM_NAME STREQUAL Linux)/if(CMAKE_HOST_SYSTEM_NAME STREQUAL Android)\nset(ANDROID_HOST_TAG linux-aarch64)\nelseif(CMAKE_HOST_SYSTEM_NAME STREQUAL Linux)/g' "$ndk_dir"/build/cmake/android-legacy.toolchain.cmake
        sed -i 's/if(CMAKE_HOST_SYSTEM_NAME STREQUAL Linux)/if(CMAKE_HOST_SYSTEM_NAME STREQUAL Android)\nset(ANDROID_HOST_TAG linux-aarch64)\nelseif(CMAKE_HOST_SYSTEM_NAME STREQUAL Linux)/g' "$ndk_dir"/build/cmake/android.toolchain.cmake
        ndk_installed=true
    else
        echo "NDK does not exist."
        return 1
    fi
}

fix_ndk_musl() {
    # create missing link
    if [ -d "$ndk_dir" ]; then
        echo "Creating missing links..."
        cd "$ndk_dir"/toolchains/llvm/prebuilt || exit
        ln -sf linux-arm64 linux-aarch64
        cd "$ndk_dir"/prebuilt || exit
        ln -sf linux-arm64 linux-aarch64
        cd "$ndk_dir"/shader-tools || exit
        ln -sf linux-arm64 linux-aarch64
        ndk_installed=true
    else
        echo "NDK does not exist."
        return 1
    fi
}

installing_cmake() {
    cmake_version=$1
    cmake_file="cmake-${cmake_version}-android-aarch64.zip"
    
    # unzip cmake
    if [ -f "$cmake_file" ]; then
        echo "Unziping cmake..."
        if unzip -qq "$cmake_file" -d "$cmake_dir"; then
            rm "$cmake_file"
            # set executable permission for cmake
            chmod -R +x "$cmake_dir"/"$cmake_version"/bin
            cmake_installed=true
            echo "CMake $cmake_version installed successfully"
        else
            echo "Failed to extract cmake file: $cmake_file"
            rm -f "$cmake_file"
        fi
    else
        echo "$cmake_file does not exist."
    fi
}

# Main script starts here
echo "NDK Installer for AndroidIDE"
echo "============================="
echo ""

# Check if running on aarch64
if [ "$(uname -m)" != "aarch64" ]; then
    echo "Warning: This script is designed for aarch64 architecture"
    echo "Current architecture: $(uname -m)"
    read -p "Do you want to continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Exiting..."
        exit 1
    fi
fi

echo "Select which NDK version you need to install:"
echo ""

select item in r17c r18b r19c r20b r21e r22b r23b r24 r26b r27b r27c r28b r29-beta1 Quit; do
    case $item in
        "r17c")
            ndk_ver="17.2.4988734"
            ndk_ver_name="r17c"
            break
            ;;
        "r18b")
            ndk_ver="18.1.5063045"
            ndk_ver_name="r18b"
            break
            ;;
        "r19c")
            ndk_ver="19.2.5345600"
            ndk_ver_name="r19c"
            break
            ;;
        "r20b")
            ndk_ver="20.1.5948944"
            ndk_ver_name="r20b"
            break
            ;;
        "r21e")
            ndk_ver="21.4.7075529"
            ndk_ver_name="r21e"
            break
            ;;
        "r22b")
            ndk_ver="22.1.7171670"
            ndk_ver_name="r22b"
            break
            ;;
        "r23b")
            ndk_ver="23.2.8568313"
            ndk_ver_name="r23b"
            break
            ;;
        "r24")
            ndk_ver="24.0.8215888"
            ndk_ver_name="r24"
            break
            ;;
        "r26b")
            ndk_ver="26.1.10909125"
            ndk_ver_name="r26b"
            is_lzhiyong_ndk=true
            break
            ;;
        "r27b")
            ndk_ver="27.1.12297006"
            ndk_ver_name="r27b"
            is_lzhiyong_ndk=true
            break
            ;;
        "r27c")
            ndk_ver="27.2.12479018"
            ndk_ver_name="r27c"
            is_musl_ndk=true
            break
            ;;
        "r28b")
            ndk_ver="28.1.13356709"
            ndk_ver_name="r28b"
            is_musl_ndk=true
            break
            ;;
        "r29-beta1")
            ndk_ver="29.0.13113456"
            ndk_ver_name="r29-beta1"
            is_musl_ndk=true
            break
            ;;
        "Quit")
            echo "Exiting..."
            exit 0
            ;;
        *)
            echo "Invalid selection, please try again"
            ;;
    esac
done

echo ""
echo "Selected NDK version: $ndk_ver_name ($ndk_ver)"
echo "Warning! This NDK is only for aarch64 architecture"
echo ""

# Change to install directory
cd "$install_dir" || {
    echo "Error: Cannot access install directory: $install_dir"
    exit 1
}

# Set up directories and file names
ndk_dir="$ndk_base_dir/$ndk_ver"
if [[ $is_musl_ndk == true ]]; then
    ndk_file_name="android-ndk-$ndk_ver_name-aarch64-linux-musl.tar.xz"
else
    ndk_file_name="android-ndk-$ndk_ver_name-aarch64.zip"
fi

# Clean up existing installations
echo "Cleaning up existing installations..."

if [ -d "$ndk_dir" ]; then
    echo "Removing existing NDK $ndk_ver..."
    rm -rf "$ndk_dir"
fi

# Clean up existing cmake versions
for cmake_ver in "3.10.1" "3.18.1" "3.22.1" "3.23.1" "3.25.1"; do
    if [ -d "$cmake_dir/$cmake_ver" ]; then
        echo "Removing existing cmake $cmake_ver..."
        rm -rf "$cmake_dir/$cmake_ver"
    fi
done

# Download NDK
echo ""
echo "Starting NDK download..."

if [[ $is_musl_ndk == true ]]; then
    ndk_url="https://github.com/HomuHomu833/android-ndk-custom/releases/download/$ndk_ver_name/$ndk_file_name"
elif [[ $is_lzhiyong_ndk == true ]]; then
    ndk_url="https://github.com/MrIkso/AndroidIDE-NDK/releases/download/ndk/$ndk_file_name"
else
    ndk_url="https://github.com/jzinferno2/termux-ndk/releases/download/v1/$ndk_file_name"
fi

if download_ndk "$ndk_file_name" "$ndk_url"; then
    echo ""
    echo "Extracting NDK $ndk_ver_name..."
    
    if [[ $is_musl_ndk == true ]]; then
        if tar --no-same-owner -xf "$ndk_file_name" --warning=no-unknown-keyword; then
            echo "NDK extracted successfully"
        else
            echo "Failed to extract NDK"
            exit 1
        fi
    else
        if unzip -qq "$ndk_file_name"; then
            echo "NDK extracted successfully"
        else
            echo "Failed to extract NDK"
            exit 1
        fi
    fi
    
    # Clean up downloaded file
    rm -f "$ndk_file_name"

    # Move NDK to proper location
    echo "Moving NDK to Android SDK directory..."
    
    if [ ! -d "$ndk_base_dir" ]; then
        echo "Creating NDK base directory..."
        mkdir -p "$ndk_base_dir"
    fi
    
    if [ -d "android-ndk-$ndk_ver_name" ]; then
        mv "android-ndk-$ndk_ver_name" "$ndk_dir"
        echo "NDK moved successfully"
        
        # Apply fixes based on NDK type
        if [[ $is_musl_ndk == true ]]; then
            fix_ndk_musl
        elif [[ $is_lzhiyong_ndk == false ]]; then
            fix_ndk
        else
            ndk_installed=true
        fi
    else
        echo "Error: Extracted NDK directory not found"
        exit 1
    fi
else
    echo "Failed to download NDK"
    exit 1
fi

# Install CMake
echo ""
echo "Installing CMake versions..."

if [ ! -d "$cmake_dir" ]; then
    mkdir -p "$cmake_dir"
fi

cd "$cmake_dir" || {
    echo "Error: Cannot access cmake directory"
    exit 1
}

run_install_cmake

# Final status check
echo ""
echo "Installation Summary:"
echo "===================="

if [[ $ndk_installed == true ]]; then
    echo "✓ NDK $ndk_ver_name installed successfully"
else
    echo "✗ NDK installation failed"
fi

if [[ $cmake_installed == true ]]; then
    echo "✓ CMake installed successfully"
else
    echo "✗ CMake installation failed"
fi

echo ""

if [[ $ndk_installed == true && $cmake_installed == true ]]; then
    echo "🎉 Installation completed successfully!"
    echo "Please restart AndroidIDE to use the new NDK."
elif [[ $ndk_installed == true ]]; then
    echo "⚠️  NDK installed but CMake installation had issues."
    echo "You may need to install CMake manually or retry the script."
else
    echo "❌ Installation failed!"
    echo "Please check the error messages above and try again."
    exit 1
fi