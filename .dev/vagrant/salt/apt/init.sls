apt-pkgs:
  pkg.latest:
    - pkgs:
      - daemontools
      - git-core
      - openjdk-8-jre-headless
      - tmux
      - vim

# JAVA_HOME
/home/vagrant/.bashrc:
  file.append:
    - text: export JAVA_HOME="/usr/lib/jvm/java-8-openjdk-amd64"
