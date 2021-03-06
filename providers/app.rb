#
# Author:: David A. Golden
# Cookbook Name:: perlbrew
# Provider:: carton_app
#
# Copyright:: 2012, David A. Golden <dagolden@cpan.org>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'chef/mixin/shell_out'
require 'chef/mixin/language'
include Chef::Mixin::ShellOut

action :install do

	Chef::Log.info 'Carton action :install ...'

  app_perlbrew       = new_resource.perlbrew
  app_deploy_dir     = new_resource.deploy_dir
  app_user           = new_resource.user
  app_group          = new_resource.group

  # ensure we have perl + carton for requested perlbrew version
  carton_perlbrew = app_perlbrew || raise
  carton_lib = "#{carton_perlbrew}@carton"

  app_local          = "local-#{app_perlbrew}"
  app_env            = new_resource.environment.merge({
    'PERLBREW_ROOT'     => node['perlbrew']['perlbrew_root'],
    'PERLBREW_HOME'     => node['perlbrew']['perlbrew_root'],
    'PERL_CARTON_PATH'  => app_local
  })

	# Install perl if not already
	perlbrew_perl carton_perlbrew
	perlbrew_lib  carton_lib

	Chef::Log.info 'Installing carton ...'
	perlbrew_run "cpanm Carton" do
		perlbrew carton_lib
	end

	Chef::Log.info 'Installing dependencies with carton ...'
	perlbrew_run "carton install" do
		perlbrew carton_lib
		environment app_env
		cwd app_deploy_dir
		if ::File.exists?("#{app_deploy_dir}/cpanfile.snapshot")
			command "carton install --deployment"
		else
			command "carton install"
		end
	end

end

=begin

action :enable do
  # XXX should probably fail if no carton.lock is found in cwd

  app_perlbrew       = new_resource.perlbrew
  app_user           = new_resource.user
  app_group          = new_resource.group
  app_cwd            = new_resource.cwd
  app_command        = "carton exec -I lib -- #{new_resource.command}"

  # hash carton.lock to ensure library dir is unique to a lock file
  lock_hash = `sha1sum #{app_cwd}/carton.lock`[0..7]

  app_local          = "local-#{app_perlbrew}-#{lock_hash}"
  app_env            = new_resource.environment.merge({
    'PERLBREW_ROOT'     => node['perlbrew']['perlbrew_root'],
    'PERLBREW_HOME'     => node['perlbrew']['perlbrew_root'],
    'PERL_CARTON_PATH'  => app_local
  })

  # ensure we have perl + carton for requested perlbrew version
  carton_perlbrew = app_perlbrew || node['carton']['perlbrew']
  carton_lib = "#{carton_perlbrew}@carton"

  # If local directory for current carton.lock exists, skip
  # carton install
  updated = false
  unless ::File.exists?("#{app_cwd}/#{app_local}")
    perlbrew_perl carton_perlbrew
    perlbrew_lib carton_lib

    perlbrew_run "cpanm Carton" do
      perlbrew carton_lib
    end

    perlbrew_run "carton install hello-world" do
      perlbrew carton_lib
      environment app_env
      cwd app_cwd
      command "carton install"
    end
    updated = true
  end

  # XXX should be idempotent
  r = runit_service new_resource.name do
    action :enable
    directory "/etc/sv/#{new_resource.name}"
    template "carton-app"
    cookbook "carton"
    variables(
      :perlbrew_root  => node['perlbrew']['perlbrew_root'],
      :perlbrew => carton_lib,
      :user     => app_user,
      :group    => app_group,
      :command  => app_command,
      :cwd      => app_cwd
    )
    env app_env
    log true
  end
  new_resource.updated_by_last_action(updated || r.updated_by_last_action?)
end
=end

