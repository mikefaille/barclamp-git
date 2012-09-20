define :pfs_and_install_deps, :action => :create do

  comp_name = params[:name]
  install_path = params[:path] || "/opt/#{comp_name}"
  ref = params[:reference] || node[@cookbook_name][:git_refspec] 
  package("git")
  package("python-setuptools")
  package("python-pip")
  if node[@cookbook_name][:use_gitbarclamp]
    gitserver = search(:node, "roles:git").first
    git_url = "git@#{gitserver[:fqdn]}:#{@cookbook_name}/#{comp_name}.git"
  else
    git_url = node[@cookbook_name][:gitrepo]
  end
  git install_path do
    repository git_url 
    reference ref
    action :sync
  end
  execute "cleanup_pip_reqs_for_#{comp_name}" do
    command "echo > #{install_path}/tools/pip-requires"
    only_if {File.exists? "#{install_path}/tools/pip-requires"}
  end
  unless params[:without_setup]
    comp_name = "horizon" if comp_name == "nova_dashboard"
    execute "setup_#{comp_name}" do
      cwd install_path
      command "python setup.py develop"
      creates "#{install_path}/#{comp_name}.egg-info"
    end
  end
  if node[comp_name]
    unless node[comp_name][:pfs_deps].nil?
      node[comp_name][:pfs_deps].each do |pkg|
        if pkg.include? "pip://"
          pkg = pkg.split('//').last
          execute "pip_install_#{pkg}" do
            command "pip install '#{pkg}'"
          end
        else
           pkg_version = pkg.split("==").last
           package pkg do
             version pkg_version if pkg_version != pkg
           end
        end
      end
    end
  end
end
