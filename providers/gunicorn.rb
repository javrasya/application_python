#
# Author:: Noah Kantrowitz <noah@opscode.com>
# Cookbook Name:: application_python
# Provider:: gunicorn
#
# Copyright:: 2011, Opscode, Inc <legal@opscode.com>
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

require 'tmpdir'

include Chef::DSL::IncludeRecipe

action :before_compile do

  include_recipe "supervisor"

  #install_packages

  django_resource = new_resource.application.sub_resources.select{|res| res.type == :django}.first
  gunicorn_install "gunicorn-#{new_resource.application.name}" do
    virtualenv django_resource ? django_resource.virtualenv : new_resource.virtualenv
  end

  if !new_resource.restart_command
    r = new_resource
    new_resource.restart_command do
      run_context.resource_collection.find(:supervisor_service => r.application.name).run_action(:restart)
    end
  end

  raise "You must specify an application module to load" unless new_resource.app_module

end

action :before_deploy do


end

action :before_migrate do
  #install_requirements
end

action :before_symlink do
end

action :before_restart do
end

action :after_restart do
end

protected

def install_packages
  new_resource.packages.each do |name, ver|
    python_pip name do
      version ver if ver && ver.length > 0
      virtualenv new_resource.virtualenv
      action :install
    end
  end
end

def install_requirements
  if new_resource.requirements.nil?
    # look for requirements.txt files in common locations
    [
      ::File.join(new_resource.release_path, "requirements", "#{node.chef_environment}.txt"),
      ::File.join(new_resource.release_path, "requirements.txt")
    ].each do |path|
      if ::File.exists?(path)
        new_resource.requirements path
        break
      end
    end
  end
  if new_resource.requirements
    Chef::Log.info("Installing using requirements file: #{new_resource.requirements}")
    # TODO normalise with python/providers/pip.rb 's pip_cmd
    if new_resource.virtualenv.nil?
      pip_cmd = 'pip'
    else
      pip_cmd = ::File.join(new_resource.virtualenv, 'bin', 'pip')
    end
    execute "#{pip_cmd} install --src=#{Dir.tmpdir} -r #{new_resource.requirements}" do
      cwd new_resource.release_path
    end
  else
    Chef::Log.debug("No requirements file found")
  end
end
