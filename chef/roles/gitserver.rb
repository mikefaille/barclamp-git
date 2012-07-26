name "gitserver"
description "Gitserver Role - does git repos hosting via ssh"
run_list(
        "recipe[gitserver::install]",
        "recipe[gitserver::config]"
)
default_attributes()
override_attributes()
