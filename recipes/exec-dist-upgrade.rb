# Cookbook Name:: oc-opsworks-recipes
# Recipe:: exec-dist-upgrade

::Chef::Resource::RubyBlock.send(:include, MhOpsworksRecipes::RecipeHelpers)
::Chef::Recipe.send(:include, MhOpsworksRecipes::RecipeHelpers)

bucket_name = get_shared_asset_bucket_name
ena_version = node.fetch(:ena_version, "1.6.0")
new_kernel_version = ""

ruby_block 'perform apt-get dist-upgrade' do
  block do
    # force a logrotate of the apt history.log to we can detect new kernel package
    execute_command('logrotate --force /etc/logrotate.d/apt')
    execute_command('apt-get -y dist-upgrade')
    new_kernel_version = execute_command(%Q(grep '^Install' history.log | grep 'linux-image-[[:digit:]][^:]*' -o  | awk -F'-' '{ print $3"-"$4"-"$5 }'))
  end
end

execute 'dkms setup for ena driver and new kernel' do
  command %Q|/usr/local/bin/enable_enhanced_networking.sh "#{ena_version}" "#{new_kernel_version}" "#{bucket_name}"|
  not_if { new_kernel_version.empty? }
end

include_recipe "oc-opsworks-recipes::clean-up-package-cache"

# reboot if we got a new kernel
node.default[:reboot][:auto_reboot] = new_kernel_version.empty? && 0 || 1
include_recipe "reboot"
