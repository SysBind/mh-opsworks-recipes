# Cookbook Name:: oc-opsworks-recipes
# Recipe:: install-aws-kernel

::Chef::Recipe.send(:include, MhOpsworksRecipes::RecipeHelpers)
include_recipe "oc-opsworks-recipes::update-package-repo"

bucket_name = get_shared_asset_bucket_name
dkms_version = node.fetch(:ixgbevf_version, "2.16.4")

install_package('linux-aws')
aws_kernel = execute_command(%Q(dpkg -l | grep 'linux-image[0-9\.\-]\+-aws' -o | awk -F'-' '{ print $3"-"$4"-aws" }'))

execute 'dkms setup for ixgbevf and new kernel' do
  command %Q|/usr/local/bin/enable_enhanced_networking.sh "#{dkms_version}" "#{bucket_name}" "#{aws_kernel}"|
end

include_recipe "oc-opsworks-recipes::clean-up-package-cache"

node.run_state[:reboot] = true
