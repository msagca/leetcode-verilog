#!/usr/bin/bash

UPDATE=false
while getopts u FLAG; do
	case "$FLAG" in
	u) UPDATE=true ;;
	*) ;;
	esac
done

# prerequisites
if command -v apt &>/dev/null; then
	sudo apt -y install \
		bison \
		build-essential \
		clang \
		flex \
		gawk \
		git \
		graphviz \
		libboost-system-dev \
		libboost-python-dev \
		libboost-filesystem-dev \
		libffi-dev \
		libreadline-dev \
		pkg-config \
		python3 \
		tcl-dev \
		xdot \
		zlib1g-dev
fi

clone_cd() {
	REPO_NAME=$(basename "$1")
	REPO_PATH="$HOME/$REPO_NAME"
	git -C "$REPO_PATH" reset --hard 2>/dev/null &&
		git -C "$REPO_PATH" pull 2>/dev/null ||
		git clone --depth 1 "$1" "$REPO_PATH"
	cd "$REPO_PATH" || echo -1
}

FAILED_TO_INSTALL=()

# yosys
if ! command -v yosys &>/dev/null || $UPDATE; then
	clone_cd 'https://github.com/YosysHQ/yosys' &&
		make config-gcc &&
		make -j "$(nproc)" &&
		sudo make install ||
		FAILED_TO_INSTALL+=("yosys")
fi

# symbiyosys
if ! command -v sby &>/dev/null || $UPDATE; then
	clone_cd 'https://github.com/YosysHQ/sby' &&
		sudo make install ||
		FAILED_TO_INSTALL+=("symbiyosys")
fi

# boolector
if ! command -v boolector &>/dev/null || $UPDATE; then
	clone_cd 'https://github.com/boolector/boolector' &&
		./contrib/setup-btor2tools.sh &&
		./contrib/setup-lingeling.sh &&
		./configure.sh &&
		make -C build -j "$(nproc)" &&
		sudo cp build/bin/{boolector,btor*} /usr/local/bin/ &&
		sudo cp deps/btor2tools/bin/btorsim /usr/local/bin/ ||
		FAILED_TO_INSTALL+=("boolector")
fi

# yices
if ! command -v yices &>/dev/null || $UPDATE; then
	clone_cd 'https://github.com/SRI-CSL/yices2' &&
		autoconf &&
		./configure &&
		make -j "$(nproc)" &&
		sudo make install ||
		FAILED_TO_INSTALL+=("yices")
fi

for TOOL_NAME in "${FAILED_TO_INSTALL[@]}"; do
	echo "Failed to install $TOOL_NAME."
done
