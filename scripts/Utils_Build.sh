#!/usr/bin/env bash
set -eE

# (C) Sergey Tyurin  2021-10-19 10:00:00

# Disclaimer
##################################################################################################################
# You running this script/function means you will not blame the author(s)
# if this breaks your stuff. This script/function is provided AS IS without warranty of any kind. 
# Author(s) disclaim all implied warranties including, without limitation, 
# any implied warranties of merchantability or of fitness for a particular purpose. 
# The entire risk arising out of the use or performance of the sample scripts and documentation remains with you.
# In no event shall author(s) be held liable for any damages whatsoever 
# (including, without limitation, damages for loss of business profits, business interruption, 
# loss of business information, or other pecuniary loss) arising out of the use of or inability 
# to use the script or documentation. Neither this script/function, 
# nor any part of it other than those parts that are explicitly copied from others, 
# may be republished without author(s) express written permission. 
# Author(s) retain the right to alter this disclaimer at any time.
##################################################################################################################

BUILD_STRT_TIME=$(date +%s)

SCRIPT_DIR=`cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P`
# source "${SCRIPT_DIR}/env.sh"
export NODE_TOP_DIR=$(cd "${SCRIPT_DIR}/../" && pwd -P)
echo
echo "################################### Node binaries build script #####################################"
echo "+++INFO: $(basename "$0") BEGIN $(date +%s) / $(date)"

TON_SRC_DIR="${NODE_TOP_DIR}/cnode"
TON_BUILD_DIR="${TON_SRC_DIR}/build"
UTILS_DIR="${TON_BUILD_DIR}/utils"
CNODE_GIT_REPO="https://github.com/Everscale-Network/Everscale-Node.git"
CNODE_GIT_COMMIT="mainnet"

TONOS_CLI_SRC_DIR="${NODE_TOP_DIR}/tonos-cli"
TONOS_CLI_GIT_REPO="https://github.com/tonlabs/tonos-cli.git"
TONOS_CLI_GIT_COMMIT="master"

NODE_BIN_DIR="$HOME/bin"
[[ ! -d $NODE_BIN_DIR ]] && mkdir -p $NODE_BIN_DIR

RUST_VERSION="1.56.1"

#=====================================================
# Packages set for different OSes
PKGS_FreeBSD="mc libtool perl5 automake llvm-devel gmake git jq wget gawk base64 gflags ccache cmake curl gperf openssl ninja lzlib vim sysinfo logrotate gsl p7zip zstd pkgconf python google-perftools"
PKGS_CentOS="curl jq wget bc vim libtool logrotate openssl-devel clang llvm-devel ccache cmake ninja-build gperf gawk gflags snappy snappy-devel zlib zlib-devel bzip2 bzip2-devel lz4-devel libmicrohttpd-devel readline-devel p7zip libzstd-devel gperftools gperftools-devel"
PKGS_Ubuntu="git mc curl build-essential libssl-dev automake libtool clang llvm-dev jq vim cmake ninja-build ccache gawk gperf texlive-science doxygen-latex libgflags-dev libmicrohttpd-dev libreadline-dev libz-dev pkg-config zlib1g-dev p7zip bc libzstd-dev libgoogle-perftools-dev"

PKG_MNGR_FreeBSD="sudo pkg"
PKG_MNGR_CentOS="sudo dnf"
PKG_MNGR_Ubuntu="sudo apt"
FEXEC_FLG="-executable"

#=====================================================
# Detect OS and set packages
OS_SYSTEM=`uname -s`
if [[ "$OS_SYSTEM" == "Linux" ]];then
    OS_SYSTEM="$(hostnamectl |grep 'Operating System'|awk '{print $3}')"

elif [[ ! "$OS_SYSTEM" == "FreeBSD" ]];then
    echo
    echo "###-ERROR: Unknown or unsupported OS. Can't continue."
    echo
    exit 1
fi

#=====================================================
# Set packages set & manager according to OS
case "$OS_SYSTEM" in
    FreeBSD)
        export ZSTD_LIB_DIR=/usr/local/lib
        PKGs_SET=$PKGS_FreeBSD
        PKG_MNGR=$PKG_MNGR_FreeBSD
        $PKG_MNGR delete -y rust boost-all|cat
        $PKG_MNGR update -f
        $PKG_MNGR upgrade -y
        FEXEC_FLG="-perm +111"
        sudo wget https://github.com/mikefarah/yq/releases/download/v4.13.3/yq_freebsd_amd64 -O /usr/local/bin/yq && sudo chmod +x /usr/local/bin/yq
        #	libmicrohttpd \ 
        #   does not build with libmicrohttpd-0.9.71
        #   build & install libmicrohttpd-0.9.70
        mkdir -p $HOME/src
        cd $HOME/src
        # sudo pkg remove -y libmicrohttpd | cat
        fetch https://ftp.gnu.org/gnu/libmicrohttpd/libmicrohttpd-0.9.70.tar.gz
        tar xf libmicrohttpd-0.9.70.tar.gz
        cd libmicrohttpd-0.9.70
        ./configure && make && sudo make install
        ;;

    CentOS)
        export ZSTD_LIB_DIR=/usr/lib64
        PKGs_SET=$PKGS_CentOS
        PKG_MNGR=$PKG_MNGR_CentOS
        $PKG_MNGR -y update --allowerasing
        $PKG_MNGR group install -y "Development Tools"
        $PKG_MNGR config-manager --set-enabled powertools 
        $PKG_MNGR --enablerepo=extras install -y epel-release
        sudo wget https://github.com/mikefarah/yq/releases/download/v4.13.3/yq_linux_amd64 -O /usr/bin/yq && sudo chmod +x /usr/bin/yq
        ;;

    Oracle)
        export ZSTD_LIB_DIR=/usr/lib64
        PKGs_SET=$PKGS_CentOS
        PKG_MNGR=$PKG_MNGR_CentOS
        $PKG_MNGR -y update --allowerasing
        $PKG_MNGR group install -y "Development Tools"
        $PKG_MNGR config-manager --set-enabled ol8_codeready_builder
        $PKG_MNGR install -y oracle-epel-release-el8
        sudo wget https://github.com/mikefarah/yq/releases/download/v4.13.3/yq_linux_amd64 -O /usr/bin/yq && sudo chmod +x /usr/bin/yq
        ;;

    Ubuntu)
        export ZSTD_LIB_DIR=/usr/lib/x86_64-linux-gnu
        PKGs_SET=$PKGS_Ubuntu
        PKG_MNGR=$PKG_MNGR_Ubuntu
        $PKG_MNGR install -y software-properties-common
        sudo add-apt-repository -y ppa:ubuntu-toolchain-r/ppa
        sudo wget https://github.com/mikefarah/yq/releases/download/v4.13.3/yq_linux_amd64 -O /usr/bin/yq && sudo chmod +x /usr/bin/yq
        ;;

    *)
        echo
        echo "###-ERROR: Unknown or unsupported OS. Can't continue."
        echo
        exit 1
        ;;
esac

#=====================================================
# Install packages
echo
echo '################################################'
echo "---INFO: Install packages ... "
$PKG_MNGR install -y $PKGs_SET

#=====================================================
# Install or upgrade RUST
echo
echo '################################################'
echo "---INFO: Install RUST ${RUST_VERSION}"
cd $HOME
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- --default-toolchain ${RUST_VERSION} -y
# curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs -o $HOME/rust_install.sh
# sh $HOME/rust_install.sh -y --default-toolchain ${RUST_VERSION}
# curl https://sh.rustup.rs -sSf | sh -s -- --default-toolchain ${RUST_VERSION} -y

source $HOME/.cargo/env
cargo install cargo-binutils
#=====================================================
# Build C++ node
echo
echo '################################################'
echo "---INFO: Build C++ node ..."
cd $SCRIPT_DIR
[[ -d ${TON_SRC_DIR} ]] && rm -rf "${TON_SRC_DIR}"
echo "---INFO: clone ${CNODE_GIT_REPO} (${CNODE_GIT_COMMIT})..."
git clone "${CNODE_GIT_REPO}" "${TON_SRC_DIR}"
cd "${TON_SRC_DIR}" 
git checkout "${CNODE_GIT_COMMIT}"
git submodule init && git submodule update --recursive
git submodule foreach 'git submodule init'
git submodule foreach 'git submodule update  --recursive'
echo "---INFO: clone ${CNODE_GIT_REPO} (${CNODE_GIT_COMMIT})... DONE"
echo
echo "---INFO: build a node..."
mkdir -p "${TON_BUILD_DIR}" && cd "${TON_BUILD_DIR}"
cmake .. -G "Ninja" -DCMAKE_BUILD_TYPE=Release -DPORTABLE=ON
ninja
echo "---INFO: build a node... DONE"
echo

cp -f $TON_BUILD_DIR/lite-client/lite-client $NODE_BIN_DIR/
cp -f $TON_BUILD_DIR/validator-engine/validator-engine $NODE_BIN_DIR/
cp -f $TON_BUILD_DIR/validator-engine-console/validator-engine-console $NODE_BIN_DIR/
#=====================================================
echo "---INFO: build utils (convert_address)..."
cd "${NODE_TOP_DIR}/utils/convert_address"
cargo update
cargo build --release
cp -f "${NODE_TOP_DIR}/utils/convert_address/target/release/convert_address" "$NODE_BIN_DIR/"
echo "---INFO: build utils (convert_address)... DONE"

#=====================================================
# Build tonos-cli
echo
echo '################################################'
echo "---INFO: build tonos-cli ... "
[[ -d ${TONOS_CLI_SRC_DIR} ]] && rm -rf "${TONOS_CLI_SRC_DIR}"
git clone --recurse-submodules "${TONOS_CLI_GIT_REPO}" "${TONOS_CLI_SRC_DIR}"
cd "${TONOS_CLI_SRC_DIR}"
git checkout "${TONOS_CLI_GIT_COMMIT}"
cargo update
cargo build --release
# cp $NODE_BIN_DIR/tonos-cli $NODE_BIN_DIR/tonos-cli_${BackUP_Time}|cat
cp -f "${TONOS_CLI_SRC_DIR}/target/release/tonos-cli" "$NODE_BIN_DIR/"
echo "---INFO: build tonos-cli ... DONE"

#=====================================================
# download global config
echo
echo '################################################'
echo "---INFO: download global config ... "

curl https://newton-blockchain.github.io/global.config.json -o ${NODE_TOP_DIR}/configs/global.config.json

echo 
echo '################################################'
BUILD_END_TIME=$(date +%s)
Build_mins=$(( (BUILD_END_TIME - BUILD_STRT_TIME)/60 ))
Build_secs=$(( (BUILD_END_TIME - BUILD_STRT_TIME)%60 ))
echo
echo "+++INFO: $(basename "$0") on $HOSTNAME FINISHED $(date +%s) / $(date)"
echo "All builds took $Build_mins min $Build_secs secs"
echo "================================================================================================"

exit 0
