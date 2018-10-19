#!/bin/bash
set -e

ena_version=$1
kernel_version=$2
bucket_name=$3

if dkms status -m amzn-drivers -v $ena_version -k $kernel_version | grep installed > /dev/null; then
  echo "already installed ena driver $ena_version for kernel $kernel_version"
  exit 0;
fi

cd /root
rm -Rf /usr/src/amzn-drivers-$ena_version ./amzn-drivers
git clone https://github.com/amzn/amzn-drivers.git
cp -ap amzn-drivers /usr/src/amzn-drivers-$ena_version
cd /usr/src/amzn-drivers-$ena_version
git checkout ena_linux_$ena_version

(
cat << EOF
PACKAGE_NAME="ena"
PACKAGE_VERSION="$ena_version"
CLEAN="make -C kernel/linux/ena clean"
BUILT_MODULE_NAME[0]="ena"
BUILT_MODULE_LOCATION="kernel/linux/ena"
DEST_MODULE_LOCATION[0]="/updates"
DEST_MODULE_NAME[0]="ena"
AUTOINSTALL="yes"
EOF
) > /usr/src/amzn-drivers-$ena_version/dkms.conf

# $kernelver is a variable set internally by the dkms build process
# append it separately because the bash heredoc would try to interpolate it
echo 'MAKE="make -C kernel/linux/ena/ BUILD_KERNEL=${kernelver}"' >> /usr/src/amzn-drivers-$ena_version/dkms.conf

# necessary if there was a previously failed build
dkms remove -m amzn-drivers/$ena_version --all -q || true

dkms add -m amzn-drivers -v $ena_version
dkms build -m amzn-drivers -v $ena_version -k $kernel_version
dkms install -m amzn-drivers -v $ena_version -k $kernel_version
dkms autoinstall -m amzn-drivers
update-initramfs -c -k all
