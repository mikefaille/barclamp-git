define :pfs_and_install_deps, :action => :create do

  comp_name = params[:name]
  install_path = params[:path] || "/opt/#{comp_name}"
  ref = params[:reference] || "master"
  package("git")
  package("python-setuptools")
  package("python-pip")

  gitserver = search(:node, "roles:git").first
  git install_path do
    repository "git@#{gitserver[:fqdn]}:#{comp_name}/#{comp_name}.git"
    reference ref
    action :sync
  end
  unless node[comp_name][:pfs_deps].nil?
    node[comp_name][:pfs_deps].each do |pkg|
      if pkg.include? "pip://"
        pkg = pkg.delete("pip://")
        execute "pip_install_#{pkg}" do
          command "pip install #{pkg}"
        end
      else
         pkg_version = pkg.split("==").last
         package pkg do
           version pkg_version
         end
      end
    end
  end
  execute "setup_#{comp_name}" do
    cwd install_path
    command "python setup.py develop"
    creates "#{install_path}/#{comp_name}.egg-info"
  end
end
