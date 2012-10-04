#!/usr/bin/env ruby
require 'yaml'

debug = true #if ENV['DEBUG']

repo_data = {}

attr_file = "#{ENV['CROWBAR_DIR']}/barclamps/git/chef/cookbooks/git/attributes/default.rb"

Dir.glob("#{ENV['CROWBAR_DIR']}/barclamps/*/crowbar.yml").each do |yml|
  data = YAML.load_file(yml)
  next if data["git"].nil?
  bc_name = yml.split('barclamps/').last.split('/').first
  repo_data[bc_name] = []
  data["git"].each do |repo|
    repo_name, origin, branches = repo.split(' ', 3)
    repo_data[bc_name] << { repo_name => origin }
  end
end

p repo_data.inspect if debug
# populate git cookbook attributes
File.open(attr_file, 'w') {|f| f.write("default[:repo_data] = #{repo_data.inspect}") }

repo_data.each do |bc_name, repos|
  repos.each do |repo|
   repo.each do |repo_name, origin|
     repos_path = "#{ENV['BC_CACHE']}/files/git_repos/#{bc_name}"
     system "mkdir -p #{repos_path}"
     if File.exists? "#{repos_path}/#{repo_name}.tar.bz2"
       # it seems that pre-cloned repo is already existing
       p "updating repo #{repo_name} from #{origin}" if debug
       system "cd #{repos_path} && tar xf #{repo_name}.tar.bz2"
       p "fetching origin #{origin}" if debug 
       system "cd #{repos_path}/#{repo_name}.git && git fetch origin"
     else
       p "cloning #{origin} to #{repo_name}.git" if debug
       system "git clone --mirror #{origin} #{repos_path}/#{repo_name}.git"
     end
     p "packing #{repo_name}.git to #{repo_name}.tar.bz2" if debug
     system "cd #{repos_path} && tar cjf #{repo_name}.tar.bz2 #{repo_name}.git/"
     p "cleaning #{repo_name}.git" if debug
     system "rm -fr #{repos_path}/#{repo_name}.git"
   end
  end
end

p "git repos staging is complete now" if debug
