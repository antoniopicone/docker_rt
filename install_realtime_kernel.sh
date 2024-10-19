#!/bin/sh

LINUX_KERNEL_VERSION=6.6
LINUX_KERNEL_RT_PATCH=patch-6.6.30-rt30
LINUX_KERNEL_BRANCH=stable_20240529
HW_SPECIFIC_CONFIG=bcm2711_defconfig # Raspberry Pi 4B

# Global variables for process management
cmd_pid=""
spinner_pid=""

clear

echo "
    ____             ____  _                   __    _                 
   / __ \___  ____ _/ / /_(_)___ ___  ___     / /   (_)___  __  ___  __
  / /_/ / _ \/ __  / / __/ / __  __ \/ _ \   / /   / / __ \/ / / / |/_/
 / _, _/  __/ /_/ / / /_/ / / / / / /  __/  / /___/ / / / / /_/ />  <  
/_/ |_|\___/\__,_/_/\__/_/_/ /_/ /_/\___/  /_____/_/_/ /_/\__,_/_/|_|
 
                                                      on Raspberry Pi
"

# Improved signal handling
cleanup_int() {
    echo ""
    if [ -n "$spinner_pid" ]; then
        kill "$spinner_pid" 2>/dev/null
    fi
    if [ -n "$cmd_pid" ]; then
        kill -TERM "$cmd_pid" 2>/dev/null
        wait "$cmd_pid" 2>/dev/null
    fi
    tput cnorm  # Restore cursor
    tput rc
    exit 1
}

# Set up trap for various signals
trap cleanup_int INT TERM QUIT

init() {

    if [ "$(id -u)" -ne 0 ]; then
        echo "This script must be executed with sudo, exiting :("
        exit 1
    fi

    check_rpi_version

}


check_rpi_version() {
    
    MODEL=$(cat /proc/cpuinfo | grep "Model" | awk '{print $5}')
    if [ "$MODEL" = "4" ] || [ "$MODEL" = "5" ]; then
        echo  "Raspberry Pi $MODEL detected.\n"
    else
        echo "Unsupported device, exiting :(\n"
        exit 1
    fi

}



spinner() {
    local pid=$1
    local delay=0.1
    local symbols="⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏"  
    local colornum=3 # 3=yellow
    local reset=$(tput sgr0)
    local description=$2
    
    while kill -0 $pid 2>/dev/null; do
        tput civis
        for c in $symbols; do
            color=$(tput setaf ${colornum})
            tput sc
            printf "${color}${c}${reset} ${description}"
            tput rc
            sleep .1
            if ! kill -0 "$pid" 2>/dev/null; then
                break
            fi  
        done
        tput el
    done
    tput cnorm
    tput rc
}

run_with_spinner() {
    local func=$1
    local description="$2"
    
    # Run the function in background and capture its PID
    $func > /dev/null 2>&1 &
    cmd_pid=$!
    
    # Run spinner in background
    spinner $cmd_pid "$description" &
    spinner_pid=$!
    
    # Wait for the command to finish
    wait $cmd_pid
    local exit_status=$?
    
    # Kill the spinner
    kill $spinner_pid 2>/dev/null
    wait $spinner_pid 2>/dev/null
    
    if [ $exit_status -eq 0 ]; then
        printf "\033[32m✔\033[0m %s\n" "$description"
    else
        printf "\033[31m✖\033[0m %s\n" "$description"
        echo "Error occurred during: $description"
        exit 1
    fi
}


update_os() {
    apt-get update
    dpkg --configure -a
    apt-get upgrade -y
    apt-get install -y git wget zip unzip fdisk curl xz-utils bash vim raspi-utils cpufrequtils
}



# Disable gui
disable_gui() {
    systemctl set-default multi-user.target
}

# Disable power management
disable_power_mgmt() {
    systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target
    echo "IdleAction=ignore" >> /etc/systemd/logind.conf

}

# Disable unnecessary services
disable_unnecessary_services() {
    systemctl disable bluetooth
    systemctl disable avahi-daemon
    systemctl disable irqbalance
    systemctl disable cups
    systemctl disable ModemManage
    systemctl disable triggerhappy
    #systemctl disable wpa_supplicant
}

# Funzione per installare Docker
install_docker() {
    # Add Docker's official GPG key:
    apt-get update
    apt-get install -y ca-certificates curl
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc

    # Add the repository to Apt sources:
    echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt-get update

    # Aggiorna e installa Docker
    apt update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    # Abilita Docker al boot
    systemctl enable docker
    
    # Post installation script
    usermod -aG docker $SUDO_USER
}


enable_ethernet_over_usbc() {

    sed -i 's/rootwait/rootwait modules-load=dwc2,g_ether/' /boot/firmware/cmdline.txt
    sh -c 'echo "dtoverlay=dwc2,dr_mode=peripheral" >> /boot/firmware/config.txt'
    sh -c 'echo "libcomposite" >> /etc/modules'
    sh -c 'echo "denyinterfaces usb0" >> /etc/dhcpcd.conf'

    # Install dnsmasq
    apt-get update
    apt-get install -y dnsmasq
    apt-get clean

    tee /etc/dnsmasq.d/usb > /dev/null << EOF
interface=usb0
dhcp-range=10.55.0.2,10.55.0.6,255.255.255.248,1h
dhcp-option=3
leasefile-ro
EOF

    
    tee /etc/network/interfaces.d/usb0 > /dev/null << EOF
auto usb0
allow-hotplug usb0
iface usb0 inet static
address 10.55.0.1
netmask 255.255.255.248    
EOF
    
    tee /root/usb.sh > /dev/null << EOF
#!/bin/bash
cd /sys/kernel/config/usb_gadget/
mkdir -p pi4
cd pi4
echo 0x1d6b > idVendor # Linux Foundation
echo 0x0104 > idProduct # Multifunction Composite Gadget
echo 0x0100 > bcdDevice # v1.0.0
echo 0x0200 > bcdUSB # USB2
echo 0xEF > bDeviceClass
echo 0x02 > bDeviceSubClass
echo 0x01 > bDeviceProtocol
mkdir -p strings/0x409
echo "fedcba9876543211" > strings/0x409/serialnumber
echo "Antonio Picone" > strings/0x409/manufacturer
echo "Raspberry PI USB Device" > strings/0x409/product
mkdir -p configs/c.1/strings/0x409
echo "Config 1: ECM network" > configs/c.1/strings/0x409/configuration
echo 250 > configs/c.1/MaxPower
# Add functions here
# see gadget configurations below
# End functions
mkdir -p functions/ecm.usb0
HOST="00:dc:c8:f7:75:14" # "HostPC"
SELF="00:dd:dc:eb:6d:a1" # "BadUSB"
echo $HOST > functions/ecm.usb0/host_addr
echo $SELF > functions/ecm.usb0/dev_addr
ln -s functions/ecm.usb0 configs/c.1/
udevadm settle -t 5 || :
ls /sys/class/udc > UDC
ifup usb0
service dnsmasq restart
EOF
    chmod +x /root/usb.sh
    sed -i 's|exit 0|/root/usb.sh\nexit 0|' /etc/rc.local

}


request_reboot() {
    echo ""
    echo "All done."
    echo "Please reboot the system and enjoy your realtime kernel!"
    
}

cleanup() {

    apt-get -y clean
    
}

get_latest_release_url() {
    echo "Fetching latest release URL from GitHub..."

    # Ottieni la versione della release tramite l'API GitHub
    RELEASE_VER=$(curl -s https://api.github.com/repos/antoniopicone/docker_rt/releases/latest | grep "tag_name" | cut -d '"' -f 4)

    if [[ -z "$RELEASE_VER" ]]; then
        echo "Error: Could not fetch release URL."
        exit 1
    fi

    CONFIG_MODEL="bcm2711"
    # Controlla se il modello è Raspberry Pi 4 o 5 e scarica il file corretto
    if [ "$MODEL" = "5" ]; then
        CONFIG_MODEL="bcm2712"  
    fi

    KERNEL_URL="https://github.com/antoniopicone/docker_rt/releases/download/$RELEASE_VER/linux66_rt_${CONFIG_MODEL}_defconfig.tar.gz"
    
}

install_rt_kernel() {

    get_latest_release_url
    
    wget -O linux66_rt.tar.gz $KERNEL_URL
    
    readonly KERNEL_SETUP_DIR=$(pwd)

    tar xzf linux66_rt.tar.gz 

    cd linux

    make -j$(nproc) modules_install

    cp ./arch/arm64/boot/Image /boot/firmware/Image66_rt_$RELEASE_VER.img
    cp ./arch/arm64/boot/dts/broadcom/*.dtb /boot/firmware/
    cp ./arch/arm64/boot/dts/overlays/*.dtb* /boot/firmware/overlays/
    cp ./arch/arm64/boot/dts/overlays/README /boot/firmware/overlays/
    echo "kernel=Image66_rt_$RELEASE_VER.img" >> /boot/firmware/config.txt
 
}

tune_system_for_realtime() {

    # Create cpu device for realtime containers
    mkdir -p /dev/cpu
    mknod /dev/cpu/0 b 5 1

    addgroup realtime
    usermod -a -G realtime $SUDO_USER
    tee /etc/security/limits.conf > /dev/null << EOF 
@realtime soft rtprio 99
@realtime soft priority 99
@realtime soft memlock 102400
@realtime hard rtprio 99
@realtime hard priority 99
@realtime hard memlock 102400
EOF

    echo "consoleblank=0" >> /boot/firmware/config.txt
    echo "force_turbo=1" >> /boot/firmware/config.txt
    echo "arm_freq=1500" >> /boot/firmware/config.txt
    echo "arm_freq_min=1500" >> /boot/firmware/config.txt
    sed -i '1s/^/isolcpus=2,3 nohz_full=2,3 rcu_nocbs=2,3 /' /boot/firmware/cmdline.txt

    echo " processor.max_cstate=0 intel_idle.max_cstate=0 idle=poll rcu_nocb_poll nohz=on kthread_cpus=0,1 irqaffinity=0,1 iomem=relaxed" >> /boot/firmware/cmdline.txt
    echo 'GOVERNOR="performance"' | sudo tee /etc/default/cpufrequtils
    systemctl disable ondemand
    systemctl enable cpufrequtils

}


init
run_with_spinner update_os "Updating OS"
run_with_spinner disable_unnecessary_services "Disabling unnecessary services"
run_with_spinner disable_gui "Disabling GUI"
run_with_spinner disable_power_mgmt "Disabling power management"
run_with_spinner install_docker "Installing Docker"
run_with_spinner enable_ethernet_over_usbc "Enabling Ethernet over USB-C"
run_with_spinner install_rt_kernel "Installing latest real time kernel (will take some minutes)"
run_with_spinner tune_system_for_realtime "Tuning system for realtime"
run_with_spinner cleanup "Cleaning up the system"
request_reboot

