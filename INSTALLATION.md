# Installation alternatives

To compile and install any of the [kernel modules for our Pi-based boards and modules](https://github.com/orgs/sfera-labs/repositories?q=kernel-module), follow these steps. Follow the product README for any hardware-specific setup.

## Install from source

Install the build tools and headers for the running kernel:

    sudo apt update
    sudo apt install git device-tree-compiler dkms linux-headers-$(uname -r)

Clone the product's kernel-module repository, replacing `REPO` with the repository name linked from its README:

    git clone --depth 1 https://github.com/sfera-labs/REPO.git
    
    cd REPO

### DKMS

DKMS automatically rebuilds the module when new kernel versions are installed:

    sudo dkms add .
    sudo dkms build -m "$(cat MODULE_NAME)" -v "$(cat VERSION)"
    sudo dkms install -m "$(cat MODULE_NAME)" -v "$(cat VERSION)"

### Static installation

To install without DKMS for the running kernel only:

    sudo make install-static KVER="$(uname -r)"

Static installation does not rebuild the module after kernel upgrades.
