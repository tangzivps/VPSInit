#!/bin/bash

# 字体颜色配置
Green="\033[32m"
Red="\033[31m"
Yellow="\033[33m"
Blue="\033[36m"
Font="\033[0m"
GreenBG="\033[42;37m"
RedBG="\033[41;37m"
OK="${Green}[OK]${Font}"
ERROR="${Red}[ERROR]${Font}"

function print_ok() {
  echo -e "${OK} ${Blue} $1 ${Font}"
}

function print_error() {
  echo -e "${ERROR} ${RedBG} $1 ${Font}"
}

function judge() {
  if [[ 0 -eq $? ]]; then
    print_ok "$1 完成！"
    sleep 1
  else
    print_error "$1 失败！！"
    exit 1
  fi
}

function is_root() {
  if [[ 0 == "$UID" ]]; then
    print_ok "当前用户是 root 用户，开始安装流程"
  else
    print_error "当前用户不是 root 用户，请切换到 root 用户后重新执行脚本"
    exit 1
  fi
}

function system_check() {
  source '/etc/os-release'

  if [[ "${ID}" == "debian" && ${VERSION_ID} -ge 9 ]]; then
    print_ok "当前系统为 Debian ${VERSION}"
  elif [[ "${ID}" == "ubuntu" && $(echo "${VERSION_ID}" | cut -d '.' -f1) -ge 18 ]]; then
    print_ok "当前系统为 Ubuntu ${VERSION_ID} ${UBUNTU_CODENAME}"
  else
    print_error "当前系统为 ${ID} ${VERSION_ID} 不在支持的系统列表内"
    exit 1
  fi
}

function download_initrd() {
  print_ok "开始自动重装Debian，版本：$vDEB 构架：$VER"
  wget -qO '/boot/initrd.gz' "https://deb.debian.org/debian/dists/$vDEB/main/installer-$VER/current/images/netboot/debian-installer/$VER/initrd.gz"
  judge "下载initrd.gz"
  wget -qO '/boot/linux' "https://deb.debian.org/debian/dists/$vDEB/main/installer-$VER/current/images/netboot/debian-installer/$VER/linux"
  judge "下载linux"
}

function download_authorized_keys() {
  wget -qO '/boot/authorized_keys' "https://raw.githubusercontent.com/tangzivps/VPSInit/main/id_rsa.pub"
  judge "下载公钥"
}

function get_network() {
  DEFAULTNET="$(ip route show |grep -o 'default via [0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.*' |head -n1 |sed 's/proto.*\|onlink.*//g' |awk '{print $NF}')"
  [ -n "$DEFAULTNET" ] && IPSUB="$(ip addr |grep ''${DEFAULTNET}'' |grep 'global' |grep 'brd' |head -n1 |grep -o '[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}/[0-9]\{1,2\}')"
  #local_ip=$(curl -4 ip.sb)
  IPv4="$(echo -n "$IPSUB" |cut -d'/' -f1)"
  NETSUB="$(echo -n "$IPSUB" |grep -o '/[0-9]\{1,2\}')"
  GATE="$(ip route show |grep -o 'default via [0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}' |head -n1 |grep -o '[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}')"
  [ -n "$NETSUB" ] && MASK="$(echo -n '128.0.0.0/1,192.0.0.0/2,224.0.0.0/3,240.0.0.0/4,248.0.0.0/5,252.0.0.0/6,254.0.0.0/7,255.0.0.0/8,255.128.0.0/9,255.192.0.0/10,255.224.0.0/11,255.240.0.0/12,255.248.0.0/13,255.252.0.0/14,255.254.0.0/15,255.255.0.0/16,255.255.128.0/17,255.255.192.0/18,255.255.224.0/19,255.255.240.0/20,255.255.248.0/21,255.255.252.0/22,255.255.254.0/23,255.255.255.0/24,255.255.255.128/25,255.255.255.192/26,255.255.255.224/27,255.255.255.240/28,255.255.255.248/29,255.255.255.252/30,255.255.255.254/31,255.255.255.255/32' |grep -o '[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}'${NETSUB}'' |cut -d'/' -f1)"
  [ -n "$GATE" ] && [ -n "$MASK" ] && [ -n "$IPv4" ]
  judge "网络参数获取"
  echo -e "I  P：$IPv4"
  echo -e "掩码：$MASK"
  echo -e "网关：$GATE"
}

#设置启动项，此项暂时未改
function set_grub() {
  [ -f /boot/grub/grub.cfg ] && GRUBOLD='0' && GRUBDIR='/boot/grub' && GRUBFILE='grub.cfg'
  [ -z $GRUBDIR ] && [ -f /boot/grub2/grub.cfg ] && GRUBOLD='0' && GRUBDIR='/boot/grub2' && GRUBFILE='grub.cfg'
  [ -z $GRUBDIR ] && [ -f /boot/grub/grub.conf ] && GRUBOLD='1' && GRUBDIR='/boot/grub' && GRUBFILE='grub.conf'
  [ -z $GRUBDIR -o -z $GRUBFILE ] && echo "${Error} ${RedBG} 没有找到 grub 目录 ${Font}" && exit 1
  [ ! -f $GRUBDIR/$GRUBFILE ] && echo "Error! Not Found $GRUBFILE. " && exit 1

  [ ! -f $GRUBDIR/$GRUBFILE.old ] && [ -f $GRUBDIR/$GRUBFILE.bak ] && mv -f $GRUBDIR/$GRUBFILE.bak $GRUBDIR/$GRUBFILE.old
  mv -f $GRUBDIR/$GRUBFILE $GRUBDIR/$GRUBFILE.bak
  [ -f $GRUBDIR/$GRUBFILE.old ] && cat $GRUBDIR/$GRUBFILE.old >$GRUBDIR/$GRUBFILE || cat $GRUBDIR/$GRUBFILE.bak >$GRUBDIR/$GRUBFILE
  [ "$GRUBOLD" == '0' ] && {
    CFG0="$(awk '/menuentry /{print NR}' $GRUBDIR/$GRUBFILE|head -n 1)"
    CFG2="$(awk '/menuentry /{print NR}' $GRUBDIR/$GRUBFILE|head -n 2 |tail -n 1)"
    CFG1=""
    for CFGtmp in `awk '/}/{print NR}' $GRUBDIR/$GRUBFILE`
    do
      [ $CFGtmp -gt "$CFG0" -a $CFGtmp -lt "$CFG2" ] && CFG1="$CFGtmp";
    done
    [ -z "$CFG1" ] && {
      echo -ne "${Error} ${RedBG} 读取$GRUBFILE错误 ${Font}"
      exit 1
    }
    sed -n "$CFG0,$CFG1"p $GRUBDIR/$GRUBFILE >/tmp/grub.new
    [ -f /tmp/grub.new ] && [ "$(grep -c '{' /tmp/grub.new)" -eq "$(grep -c '}' /tmp/grub.new)" ] || {
      echo -ne "${Error} ${RedBG} $GRUBFILE配置错误 ${Font}"
      exit 1
    }

    sed -i "/menuentry.*/c\menuentry\ \'Install OS \[$vDEB\ $VER\]\'\ --class debian\ --class\ gnu-linux\ --class\ gnu\ --class\ os\ \{" /tmp/grub.new
    [ "$(grep -c '{' /tmp/grub.new)" -eq "$(grep -c '}' /tmp/grub.new)" ] || {
      echo -ne "${Error} ${RedBG} $GRUBFILE添加启动项错误 ${Font}"
      exit 1
    }
    sed -i "/echo.*Loading/d" /tmp/grub.new
  }
  [ "$GRUBOLD" == '1' ] && {
    CFG0="$(awk '/title /{print NR}' $GRUBDIR/$GRUBFILE|head -n 1)"
    CFG1="$(awk '/title /{print NR}' $GRUBDIR/$GRUBFILE|head -n 2 |tail -n 1)"
    [ -n $CFG0 ] && [ -z $CFG1 -o $CFG1 == $CFG0 ] && sed -n "$CFG0,$"p $GRUBDIR/$GRUBFILE >/tmp/grub.new
    [ -n $CFG0 ] && [ -z $CFG1 -o $CFG1 != $CFG0 ] && sed -n "$CFG0,$CFG1"p $GRUBDIR/$GRUBFILE >/tmp/grub.new
    [ ! -f /tmp/grub.new ] && echo -ne "${Error} ${RedBG} $GRUBFILE添加启动项错误 ${Font}" && exit 1
    sed -i "/title.*/c\title\ \'Install OS \[$vDEB\ $VER\]\'" /tmp/grub.new
    sed -i '/^#/d' /tmp/grub.new
  }
  [ -n "$(grep 'initrd.*/' /tmp/grub.new |awk '{print $2}' |tail -n 1 |grep '^/boot/')" ] && Type='InBoot' || Type='NoBoot'

  LinuxKernel="$(grep 'linux.*/' /tmp/grub.new |awk '{print $1}' |head -n 1)"
  [ -z $LinuxKernel ] && LinuxKernel="$(grep 'kernel.*/' /tmp/grub.new |awk '{print $1}' |head -n 1)"
  LinuxIMG="$(grep 'initrd.*/' /tmp/grub.new |awk '{print $1}' |tail -n 1)"

  [ "$Type" == 'InBoot' ] && {
    sed -i "/$LinuxKernel.*\//c\\\t$LinuxKernel\\t\/boot\/linux auto=true hostname=debian domain= -- quiet" /tmp/grub.new
    sed -i "/$LinuxIMG.*\//c\\\t$LinuxIMG\\t\/boot\/initrd.gz" /tmp/grub.new
  }

  [ "$Type" == 'NoBoot' ] && {
    sed -i "/$LinuxKernel.*\//c\\\t$LinuxKernel\\t\/linux auto=true hostname=debian domain= -- quiet" /tmp/grub.new
    sed -i "/$LinuxIMG.*\//c\\\t$LinuxIMG\\t\/initrd.gz" /tmp/grub.new
  }

  sed -i '$a\\n' /tmp/grub.new
  [ -f /etc/network/interfaces -o -d /etc/sysconfig/network-scripts ] && {
    sed -i ''${CFG0}'i\\n' $GRUBDIR/$GRUBFILE
    sed -i ''${CFG0}'r /tmp/grub.new' $GRUBDIR/$GRUBFILE
    [ -f  $GRUBDIR/grubenv ] && sed -i 's/saved_entry/#saved_entry/g' $GRUBDIR/grubenv
  }
  chown root:root $GRUBDIR/$GRUBFILE
  chmod 444 $GRUBDIR/$GRUBFILE
  print_ok "启动项设置成功！"
}


function generate_preseed(){
preseed_conf=${BootTmp}/preseed.cfg
cat >${preseed_conf}<<EOF
d-i debian-installer/locale string en_US
d-i console-setup/layoutcode string us
d-i keyboard-configuration/xkb-keymap string us

d-i netcfg/choose_interface select auto
d-i netcfg/disable_autoconfig boolean true
d-i netcfg/dhcp_failed note
d-i netcfg/dhcp_options select Configure network manually
d-i netcfg/get_ipaddress string $IPv4
d-i netcfg/get_netmask string $MASK
d-i netcfg/get_gateway string $GATE
d-i netcfg/get_nameservers string 1.1.1.1
d-i netcfg/no_default_route boolean true
d-i netcfg/confirm_static boolean true

d-i hw-detect/load_firmware boolean true

d-i mirror/country string manual
d-i mirror/http/hostname string deb.debian.org
d-i mirror/http/directory string /debian
d-i mirror/http/proxy string
d-i base-installer/kernel/image string linux-image-cloud-$VER

d-i apt-setup/services-select multiselect

d-i passwd/root-login boolean true
d-i passwd/root-password-crypted password !!
d-i passwd/make-user boolean false

d-i clock-setup/utc boolean true
d-i time/zone string US/Eastern
d-i clock-setup/ntp boolean true

d-i partman/early_command string \
debconf-set partman-auto/disk "\$(list-devices disk |head -n1)"; \
debconf-set grub-installer/bootdev string "\$(list-devices disk |head -n1)"; \
umount /media || true;
d-i partman/mount_style select uuid
d-i partman-auto/init_automatically_partition select Guided - use entire disk
d-i partman-auto/choose_recipe select All files in one partition (recommended for new users)
d-i partman-auto/method string regular
d-i partman-lvm/device_remove_lvm boolean true
d-i partman-md/device_remove_md boolean true
d-i partman-auto/choose_recipe select atomic
d-i partman-partitioning/confirm_write_new_label boolean true
d-i partman/choose_partition select finish
d-i partman-lvm/confirm boolean true
d-i partman-lvm/confirm_nooverwrite boolean true
d-i partman/confirm boolean true
d-i partman/confirm_nooverwrite boolean true

tasksel tasksel/first multiselect minimal
d-i pkgsel/include string openssh-server wget curl python zsh docker.io
d-i pkgsel/upgrade select safe-upgrade
d-i pkgsel/update-policy select unattended-upgrades

popularity-contest popularity-contest/participate boolean false
d-i grub-installer/only_debian boolean true
d-i grub-installer/bootdev string default
d-i grub-installer/force-efi-extra-removable boolean true
d-i finish-install/reboot_in_progress note
d-i debian-installer/exit/reboot boolean true

d-i preseed/late_command string	\
mkdir -p /target/root/.ssh; \
cp authorized_keys /target/root/.ssh/authorized_keys; \
sed -ri 's/^#?Port.*/Port 16322/g' /target/etc/ssh/sshd_config; \
sed -ri 's/^#?PermitRootLogin.*/PermitRootLogin yes/g' /target/etc/ssh/sshd_config; \
sed -ri 's/^#?PubkeyAuthentication.*/PubkeyAuthentication yes/g' /target/etc/ssh/sshd_config; \
sed -ri 's/^#?PasswordAuthentication.*/PasswordAuthentication no/g' /target/etc/ssh/sshd_config; \
echo 'net.core.default_qdisc=cake' >> /target/etc/sysctl.conf; \
echo 'net.ipv4.tcp_congestion_control=bbr' >> /target/etc/sysctl.conf; \
wget -O /target/root/.zshrc 'https://raw.githubusercontent.com/skywind3000/vim/master/etc/prezto.zsh'; \
in-target chsh -s /bin/zsh;
EOF
sed -i 's/debconf-set\ grub-installer\/bootdev.*\"\;//g' ${preseed_conf}
sed -i '/user-setup\/allow-password-weak/d' ${preseed_conf}
sed -i '/user-setup\/encrypt-home/d' ${preseed_conf}
sed -i '/pkgsel\/update-policy/d' ${preseed_conf}
sed -i 's/umount\ \/media.*\;//g' ${preseed_conf}
}

#重新压制镜像文件
function remake_initrd() {
  [ -d ${BootTmp} ] && rm -rf ${BootTmp}
  mkdir -p ${BootTmp}
  cp /boot/authorized_keys ${BootTmp}/authorized_keys;
  cd ${BootTmp}
  gzip -d < ../initrd.gz | cpio --extract --verbose --make-directories --no-absolute-filenames >>/dev/null 2>&1
  judge "解压initrd文件至新目录"
  generate_preseed
  judge "生成preseed文件"
  find . | cpio -H newc --create --quiet | gzip -1 > ../initrd.gz
  judge "压制新initrd文件"
  rm -rf ${BootTmp}
}

#变量
BootTmp='/boot/tmp'
vDEB='stable'
VER='amd64'

while [ $# -gt 0 ]; do
    case $1 in
        --test)
            vDEB='testing'
            ;;
        --arm)
            VER='arm64'
            ;;
        *)
            print_error "未知选项: \"$1\"，仅支持参数--test、--arm，分别为使用测试版本、arm内核"
            exit 1
    esac
    shift
done

is_root
system_check
download_initrd
download_authorized_keys
get_network
set_grub
remake_initrd

print_ok "所有准备工作完成，系统将在3秒后重启！"
sleep 3 && reboot >/dev/null 2>&1