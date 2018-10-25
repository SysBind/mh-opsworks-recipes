# Cookbook Name:: mh-opsworks-recipes
# Recipe:: exec-dist-upgrade

::Chef::Resource::RubyBlock.send(:include, MhOpsworksRecipes::RecipeHelpers)
::Chef::Recipe.send(:include, MhOpsworksRecipes::RecipeHelpers)

bucket_name = get_shared_asset_bucket_name
dkms_version = node.fetch(:ixgbevf_version, "2.16.4")
new_kernel_version = ""

# force a logrotate of the apt history.log to we can detect new kernel package
execute 'rotate apt history log' do
  command 'logrotate --force /etc/logrotate.d/apt'
end

execute "dist upgrade" do
  environment 'DEBIAN_FRONTEND' => 'noninteractive'
  command %Q|apt-get -y dist-upgrade|
  retries 5
  retry_delay 15
  timeout 180
end

ruby_block 'check for new kernel version' do
  block do
    new_kernel_version = execute_command(%Q(grep '^Install' /var/log/apt/history.log | grep 'linux-image-[[:digit:]][^:]*' -o  | awk -F'-' '{ print $3"-"$4"-"$5 }')).chomp
    Chef::Log.info "Got new kernel: #{new_kernel_version}"
  end
end

execute 'dkms setup for ixgbevf driver and new kernel' do
  command %Q|/usr/local/bin/enable_enhanced_networking.sh "#{dkms_version}" "#{new_kernel_version}" "#{bucket_name}"|
  not_if { new_kernel_version.empty? }
end

include_recipe "mh-opsworks-recipes::clean-up-package-cache"

