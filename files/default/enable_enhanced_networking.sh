#!/bin/bash
set -e

dkms_version=$1
kernel_version=$2
bucket_name=$3

if dkms status -m ixgbevf -v $dkms_version -k $kernel_version | grep installed > /dev/null; then
  echo "already installed ixgbevf driver $dkms_version for kernel $kernel_version"
  exit 0;
fi

rm -Rf /root/build_tmp/
mkdir -p /root/build_tmp
cd /root/build_tmp

aws s3 cp s3://$bucket_name/ixgbevf-$dkms_version.tar.gz .
tar zxf ixgbevf-$dkms_version.tar.gz

rm -Rf /usr/src/ixgbevf-$dkms_version
mv ixgbevf-$dkms_version /usr/src/
cd /usr/src/ixgbevf-$dkms_version

(
cat <<EOF
PACKAGE_NAME="ixgbevf"
PACKAGE_VERSION="$dkms_version"
CLEAN="cd src/; make clean"
BUILT_MODULE_LOCATION[0]="src/"
BUILT_MODULE_NAME[0]="ixgbevf"
DEST_MODULE_LOCATION[0]="/updates"
DEST_MODULE_NAME[0]="ixgbevf"
AUTOINSTALL="yes"
EOF
) > /usr/src/ixgbevf-$dkms_version/dkms.conf

# $kernelver is a variable set internally by the dkms build process
# append it separately because the bash heredoc would try to interpolate it
echo 'MAKE="cd src/; make BUILD_KERNEL=${kernelver}"' >> /usr/src/ixgbevf-$dkms_version/dkms.conf

# dkms will sometimes return non-zero exit, but we want to proceed anyway
set +e

# necessary if there was a previously failed build
dkms remove -m ixgbevf/$dkms_version --all | logger -t dkms || true

dkms add -m ixgbevf -v $dkms_version | logger -t dkms
dkms build -m ixgbevf -v $dkms_version -k $kernel_version | logger -t dkms
dkms install -m ixgbevf -v $dkms_version -k $kernel_version | logger -t dkms
dkms autoinstall -m ixgbevf -v $dkms_version | logger -t dkms
update-initramfs -c -k all

