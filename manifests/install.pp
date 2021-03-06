# == Class consul::install
#
# Installs consul based on the parameters from init
#
class consul::install {

  if $::consul::data_dir {
    file { $::consul::data_dir:
      ensure => 'directory',
      owner  => $::consul::user,
      group  => $::consul::group,
      mode   => '0755',
    }
  }

  case $::consul::install_method {
    'url': {
      $install_prefix = pick($::consul::config_hash[data_dir], '/opt/consul')
      $install_path = pick($::consul::archive_path, "${install_prefix}/archives")

      # only notify if we are installing a new version (work around for switching to archive module)
      if getvar('::consul_version') != $::consul::version {
        $do_notify_service = $::consul::notify_service
      } else {
        $do_notify_service = undef
      }

      file { [
        $install_path,
        "${install_path}/consul-${consul::version}"]:
        ensure => directory,
        owner  => 'root',
        group  => 0, # 0 instead of root because OS X uses "wheel".
        mode   => '0555';
      } -> exec { "curl $::consul::real_download_url | gunzip - > ${install_path}/consul-${consul::version}/consul":
        creates => "${install_path}/consul-${consul::version}/consul",
        path    => ['/usr/bin', '/bin',],
      } -> file { "${install_path}/consul-${consul::version}/consul":
          owner => 'root',
          group => 0, # 0 instead of root because OS X uses "wheel".
          mode  => '0555';
        "${consul::bin_dir}/consul":
          ensure => link,
          notify => $do_notify_service,
          target => "${install_path}/consul-${consul::version}/consul";
      }

      if ($::consul::ui_dir and $::consul::data_dir) {

        # The 'dist' dir was removed from the web_ui archive in Consul version 0.6.0
        if (versioncmp($::consul::version, '0.6.0') < 0) {
          $archive_creates = "${install_path}/consul-${consul::version}_web_ui/dist"
          $ui_symlink_target = $archive_creates
        } else {
          $archive_creates = "${install_path}/consul-${consul::version}_web_ui/index.html"
          $ui_symlink_target = "${install_path}/consul-${consul::version}_web_ui"
        }

        file { "${install_path}/consul-${consul::version}_web_ui":
          ensure => directory,
        }
        -> exec { "curl $::consul::real_ui_download_url -o /tmp/consul_web.zip && unzip /tmp/consul_web.zip -d ${install_path}/consul-${consul::version}_web_ui":
          creates => $archive_creates,
          path    => ['/usr/bin', '/bin',],
        } -> file { $::consul::ui_dir:
          ensure => 'symlink',
          target => $ui_symlink_target,
        }
      }
    }
    'package': {
      package { $::consul::package_name:
        ensure => $::consul::package_ensure,
        notify => $::consul::notify_service
      }

      if $::consul::ui_dir {
        package { $::consul::ui_package_name:
          ensure  => $::consul::ui_package_ensure,
          require => Package[$::consul::package_name],
          notify  => $::consul::notify_service
        }
      }

      if $::consul::manage_user {
        User[$::consul::user] -> Package[$::consul::package_name]
      }

      if $::consul::data_dir {
        Package[$::consul::package_name] -> File[$::consul::data_dir]
      }
    }
    'none': {}
    default: {
      fail("The provided install method ${consul::install_method} is invalid")
    }
  }

  if $::consul::manage_user {
    user { $::consul::user:
      ensure => 'present',
      system => true,
      groups => $::consul::extra_groups,
    }

    if $::consul::manage_group {
      Group[$::consul::group] -> User[$::consul::user]
    }
  }
  if $::consul::manage_group {
    group { $::consul::group:
      ensure => 'present',
      system => true,
    }
  }
}
