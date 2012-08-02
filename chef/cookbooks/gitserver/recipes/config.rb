#
# Cookbook Name:: gitserver
# Recipe:: config
#
# Copyright 2011, Dell, Inc.
# Copyright 2012, Dell, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

git_username = "git"
home_dir = "/home/#{git_username}"
dst_dir = "/tmp"

user git_username do
  comment "Git user"
  home home_dir
  shell "/usr/bin/git-shell"
end

directory home_dir do
  owner git_username
  group git_username
end

directory "#{home_dir}/.ssh" do
  owner git_username
  group git_username
end

ssh_keys = []

all_nodes = search(:node, "*:*")
all_nodes.each do |a_node|
  ssh_keys << a_node.normal[:crowbar][:ssh][:root_pub_key]
end

template "#{home_dir}/.ssh/authorized_keys" do
  source "authorized_keys.erb"
  owner git_username
  variables :key_list => ssh_keys
end

node[:repo_data] = {}
node[:repos].each do |bc,repos_arr|
  node[:repo_data][bc] = []
  repos = []
  repos_arr.each {|repo| repos << repo.split("\n")}
  repos.flatten.each do |repo|
    repo_url, repo_name = repo.split
    node[:repo_data][bc] << { repo_name => repo_url}
  end
end

provisioner = search(:node, "roles:provisioner-server").first
proxy_addr = provisioner[:fqdn]
proxy_port = provisioner[:provisioner][:web_port]

node[:repo_data].each do |bc, repos|
  repos.each do |repo|
    repo.each do |repo_name, repo_url|
      file_url = "http://#{proxy_addr}:#{proxy_port}/git_repos/#{bc}/#{repo_name}.tar.bz2"
      file_path = "#{dst_dir}/#{bc}/#{repo_name}.tar.bz2"
      repo_dir = "#{home_dir}/#{bc}/#{repo_name}.git"
      directory "#{dst_dir}/#{bc}" do
        owner git_username
      end
      remote_file file_url do
        source file_url
        path file_path
        owner git_username
        action :create_if_missing
      end
      directory "#{home_dir}/#{bc}" do
        owner git_username
        group git_username
      end
      execute "untar_#{repo_name}.tar.bz2" do
       cwd "#{home_dir}/#{bc}"
       user git_username
       command "tar xf #{file_path}"
       creates repo_dir 
      end
      execute "git_fetch_#{repo_url}" do
        command "git fetch origin"
        cwd repo_dir
        user git_username
        only_if do
          require 'ping'
          if repo_url.include?('@')
            repo_host = repo_url.split('@')[1].split(':').first
          else
            repo_host = repo_url.split('/')[2]
          end
          begin
            Ping.pingecho repo_host, 5
          rescue Exception => msg
            false
          end
        end
      end
    end
  end
end

