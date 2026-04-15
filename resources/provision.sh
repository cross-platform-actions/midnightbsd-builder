#!/bin/sh

set -exu

setup_path() {
  PATH="/sbin:/usr/sbin:/usr/local/sbin:/usr/local/bin:$PATH"
  export PATH
}

install_extra_packages() {
  mport index

  for pkg in bash curl rsync sudo; do
    mport install "$pkg" || true # for some reason this always fails with exit code 1
    command -v "$pkg" # verify package was installed
  done
}

create_secondary_user() {
  pw useradd "$SECONDARY_USER" -m -s /bin/sh -G wheel -w none
}

setup_sudo() {
  mkdir -p /usr/local/etc/sudoers.d
  cat <<EOF > "/usr/local/etc/sudoers.d/$SECONDARY_USER"
Defaults:$SECONDARY_USER !requiretty
$SECONDARY_USER ALL=(ALL) NOPASSWD: ALL
EOF

  chmod 440 "/usr/local/etc/sudoers.d/$SECONDARY_USER"
}

configure_boot_flags() {
  cat <<EOF >> /boot/loader.conf
autoboot_delay="-1"
console="comconsole"
EOF
}

configure_sendmail() {
  sysrc sendmail_enable=NO
  sysrc sendmail_submit_enable=NO
  sysrc sendmail_outbound_enable=NO
  sysrc sendmail_msp_queue_enable=NO
}

set_hostname() {
  sysrc hostname='runnervmg1sw1.local'
}

setup_path
install_extra_packages
create_secondary_user
setup_sudo
configure_boot_flags
configure_sendmail
set_hostname
