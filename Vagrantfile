Vagrant.configure('2') do |config|
  # Choose base box
  config.vm.box = 'bento/ubuntu-16.04'

  config.vm.provider 'virtualbox' do |vb|
    # Prevent clock skew when host goes to sleep while VM is running
    vb.customize ['guestproperty', 'set', :id, '/VirtualBox/GuestAdd/VBoxService/--timesync-set-threshold', 10_000]

    vb.cpus = 2
    vb.memory = 2048
  end

  # Defaults
  config.vm.provision :salt do |salt|
    salt.masterless = true
    salt.minion_config = '.dev/vagrant/minion'

    # Pillars
    salt.pillar({
      'ruby' => {
        'version' => '2.3.3',
      }
    })

    salt.run_highstate = true
  end
end
