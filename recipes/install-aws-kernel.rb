# Cookbook Name:: oc-opsworks-recipes
# Recipe:: install-aws-kernel
# This recipe is intended only for ami building

::Chef::Recipe.send(:include, MhOpsworksRecipes::RecipeHelpers)
include_recipe "oc-opsworks-recipes::update-package-repo"

bucket_name = get_shared_asset_bucket_name
ena_version = node.fetch(:ena_version, "1.6.0")

install_package('linux-aws')
kernel_version = execute_command(%Q(dpkg -l | grep 'linux-image[0-9\.\-]\+-aws' -o | awk -F'-' '{ print $3"-"$4"-"$5 }'))

execute 'dkms setup for ena driver and new kernel' do
  command %Q|/usr/local/bin/enable_enhanced_networking.sh "#{ena_version}" "#{kernel_version}" "#{bucket_name}"|
end

include_recipe "oc-opsworks-recipes::clean-up-package-cache"

node.default[:reboot][:auto_reboot] = 1
include_recipe "reboot"
