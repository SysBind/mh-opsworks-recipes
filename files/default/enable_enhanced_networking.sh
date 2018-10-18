#!/bin/bash
set -e

running_kernel=$(uname -r)
dkms_version=$1
bucket_name=$2
kernel_version=${3-$running_kernel}

if dkms status -m ixgbevf -v $dkms_version -k $kernel_version | grep installed > /dev/null; then
  echo "already installed ixgbevf $dkms_version for kernel $kernel_version"
  exit 0;
fi

rm -Rf /root/build_tmp/
mkdir -p /root/build_tmp
cd /root/build_tmp

aws s3 cp s3://$bucket_name/ixgbevf-$dkms_version.tar.gz .
tar zxf ixgbevf-$dkms_version.tar.gz

# this shouldn't be needed except in some odd development scenario
rm -Rf /usr/src/ixgbevf-$dkms_version

mv ixgbevf-$dkms_version /usr/src/
cd /usr/src/ixgbevf-$dkms_version

# ABS check in the ixgbevf module is incompatible with the some (e.g., AWS) kernel versioning schemes
sudo sed -i '/#if UTS_UBUNTU_RELEASE_ABI > 255/c\/*#if UTS_UBUNTU_RELEASE_ABI > 255' /usr/src/ixgbevf-${dkms_version}/src/kcompat.h

echo 'PACKAGE_NAME="ixgbevf"' > /usr/src/"ixgbevf-${dkms_version}"/dkms.conf
echo "PACKAGE_VERSION=\"${dkms_version}\"" >> /usr/src/"ixgbevf-${dkms_version}"/dkms.conf
echo '
CLEAN="cd src/; make clean"
MAKE="cd src/; make BUILD_KERNEL=${kernelver}"
BUILT_MODULE_LOCATION[0]="src/"
BUILT_MODULE_NAME[0]="ixgbevf"
DEST_MODULE_LOCATION[0]="/updates"
DEST_MODULE_NAME[0]="ixgbevf"
AUTOINSTALL="yes"
' >> /usr/src/"ixgbevf-${dkms_version}"/dkms.conf &&

dkms remove ixgbevf -v $dkms_version --all 2>/dev/null || true
dkms add -m ixgbevf -v $dkms_version
dkms build -m ixgbevf -v $dkms_version -k $kernel_version
dkms install -m ixgbevf -v $dkms_version -k $kernel_version
dkms autoinstall -m ixgbevf
update-initramfs -c -k all
