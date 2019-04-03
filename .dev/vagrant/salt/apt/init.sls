apt-pkgs:
  pkg.latest:
    - pkgs:
      - daemontools
      - git
      - openjdk-11-jre-headless
      - tmux
      - vim

# JAVA_HOME
/home/vagrant/.bashrc:
  file.append:
    - text: export JAVA_HOME="/usr/lib/jvm/java-11-openjdk-amd64"
