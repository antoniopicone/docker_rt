#!/bin/sh

# Raspberry Pi Setup Script
# Compatible with Raspberry Pi models 3, 4, and 5
# This script allows you to update the OS, disable unnecessary services,
# disable GUI, disable power management, install Docker, install a real-time kernel,
# and tune the system for real-time performance.


wait_for_keypress() {
    echo -n "Press any key to return to the menu..."
    # Save current terminal settings
    old_stty_settings=$(stty -g)
    # Set terminal to raw mode, disable echo
    stty raw -echo
    # Read one character
    dd bs=1 count=1 >/dev/null 2>&1
    # Restore terminal settings
    stty "$old_stty_settings"
    echo
    main_menu
}


spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\\'
    tput civis
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\\b\\b\\b\\b\\b\\b"
    done
    printf "    \\b\\b\\b\\b"
    tput cnorm
}



# Function to check Raspberry Pi model
check_rpi_model() {
    MODEL=$(tr -d '\0' < /proc/device-tree/model)
    case "$MODEL" in
        *"Raspberry Pi 3"*)
            RPI_MODEL=3
            ;;
        *"Raspberry Pi 4"*)
            RPI_MODEL=4
            ;;
        *"Raspberry Pi 5"*)
            RPI_MODEL=5
            ;;
        *)
            echo "Unsupported Raspberry Pi model."
            exit 1
            ;;
    esac
}

# Function to check if a service is disabled
is_service_disabled() {
    if systemctl is-enabled "$1" 2>/dev/null | grep -q "disabled"; then
        return 0
    else
        return 1
    fi
}

# Function to check if Docker is installed
is_docker_installed() {
    if command -v docker >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Function to check if real-time kernel is installed
is_rt_kernel_installed() {
    if uname -r | grep -q "PREEMPT_RT"; then
        return 1
    else
        return 0
    fi
}

# Function to check if system is tuned for real-time
is_system_tuned() {
    if grep -q "force_turbo=1" /boot/firmware/config.txt; then
        return 0
    else
        return 1
    fi
}

# Update OS
update_os() {
    echo -n "Updating OS... "
    (
        set -e  # Exit immediately if a command exits with a non-zero status
        apt-get update >/dev/null 2>&1 || { echo "apt-get update failed." >&2; exit 1; }
        dpkg --configure -a >/dev/null 2>&1 || { echo "dpkg --configure -a failed." >&2; exit 1; }
        apt-get upgrade -y >/dev/null 2>&1 || { echo "apt-get upgrade failed." >&2; exit 1; }
        apt-get install -y git wget zip unzip fdisk curl xz-utils bash vim raspi-utils cpufrequtils >/dev/null 2>&1 || { echo "apt-get install failed." >&2; exit 1; }
    ) 2>/tmp/update_os_error.log &
    pid=$!
    spinner $pid
    wait $pid
    exit_status=$?
    if [ $exit_status -ne 0 ]; then
        printf "\b✗\n"
        error_message=$(cat /tmp/update_os_error.log)
        echo "Error: $error_message"
    else
        printf "\\e[32m✔\\e[0m\\n"
        echo "OS updated."
    fi

    wait_for_keypress
}

# Disable Unnecessary Services
disable_services() {
    echo -n "Disabling unnecessary services... "
    (
        systemctl disable bluetooth >/dev/null 2>&1
        # systemctl disable avahi-daemon >/dev/null 2>&1
        systemctl disable irqbalance >/dev/null 2>&1
        systemctl disable cups >/dev/null 2>&1
        systemctl disable ModemManager >/dev/null 2>&1
        systemctl disable triggerhappy >/dev/null 2>&1
    ) &
    pid=$!
    spinner $pid
    wait $pid
    printf "\\e[32m✔\\e[0m\\n"
    echo "Unnecessary services disabled."
}

# Enable Unnecessary Services
enable_services() {
    echo -n "Enabling unnecessary services... "
    (
        systemctl enable bluetooth >/dev/null 2>&1
        # systemctl enable avahi-daemon >/dev/null 2>&1
        systemctl enable irqbalance >/dev/null 2>&1
        systemctl enable cups >/dev/null 2>&1
        systemctl enable ModemManager >/dev/null 2>&1
        systemctl enable triggerhappy >/dev/null 2>&1
    ) &
    pid=$!
    spinner $pid
    wait $pid
    printf "\\e[32m✔\\e[0m\\n"
    echo "Unnecessary services enabled."
}

# Disable GUI
disable_gui() {
    echo -n "Disabling GUI... "
    (
        systemctl set-default multi-user.target >/dev/null 2>&1
    ) &
    pid=$!
    spinner $pid
    wait $pid
    printf "\\e[32m✔\\e[0m\\n"
    echo "GUI disabled."
}

# Enable GUI
enable_gui() {
    echo -n "Enabling GUI... "
    (
        systemctl set-default graphical.target >/dev/null 2>&1
    ) &
    pid=$!
    spinner $pid
    wait $pid
    printf "\\e[32m✔\\e[0m\\n"
    echo "GUI enabled."
}

# Disable Power Management
disable_power_management() {
    echo -n "Disabling power management... "
    (
        systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target >/dev/null 2>&1
    ) &
    pid=$!
    spinner $pid
    wait $pid
    printf "\\e[32m✔\\e[0m\\n"
    echo "Power management disabled."
}

# Enable Power Management
enable_power_management() {
    echo -n "Enabling power management... "
    (
        systemctl unmask sleep.target suspend.target hibernate.target hybrid-sleep.target >/dev/null 2>&1
    ) &
    pid=$!
    spinner $pid
    wait $pid
    printf "\\e[32m✔\\e[0m\\n"
    echo "Power management enabled."
}

# Install Docker
install_docker() {
    echo -n "Installing Docker... "
    (
        apt-get update >/dev/null 2>&1
        apt-get install -y ca-certificates curl >/dev/null 2>&1
        install -m 0755 -d /etc/apt/keyrings >/dev/null 2>&1
        curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc >/dev/null 2>&1
        chmod a+r /etc/apt/keyrings/docker.asc >/dev/null 2>&1

        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
$(. /etc/os-release && echo "$VERSION_CODENAME") stable" > /etc/apt/sources.list.d/docker.list
        apt-get update >/dev/null 2>&1

        apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin >/dev/null 2>&1

        systemctl enable docker >/dev/null 2>&1

        usermod -aG docker "$SUDO_USER" >/dev/null 2>&1
    ) &
    pid=$!
    spinner $pid
    wait $pid
    printf "\\e[32m✔\\e[0m\\n"
    echo "Docker installed."
}

# Uninstall Docker
uninstall_docker() {
    echo -n "Uninstalling Docker... "
    (
        apt-get purge -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin >/dev/null 2>&1
        apt-get autoremove -y >/dev/null 2>&1
        rm -rf /var/lib/docker >/dev/null 2>&1
        rm -rf /etc/apt/keyrings/docker.asc >/dev/null 2>&1
        rm -rf /etc/apt/sources.list.d/docker.list >/dev/null 2>&1
    ) &
    pid=$!
    spinner $pid
    wait $pid
    printf "\\e[32m✔\\e[0m\\n"
    echo "Docker uninstalled."
}


# Restore Default Kernel
restore_default_kernel() {
    echo -n "Restoring default kernel... "
    # Steps to restore the default kernel
     # File paths
    CMDLINE_FILE="/boot/firmware/cmdline.txt"
    CONFIG_FILE="/boot/firmware/config.txt"
    
    # Rimuovi i parametri specifici da cmdline.txt
    if [ -f "$CMDLINE_FILE" ]; then
        echo "Checking $CMDLINE_FILE for unwanted parameters..."
        sed -i 's/processor.max_cstate=0//g' "$CMDLINE_FILE"
        sed -i 's/intel_idle.max_cstate=0//g' "$CMDLINE_FILE"
        sed -i 's/idle=pol//g' "$CMDLINE_FILE"
        sed -i 's/  */ /g' "$CMDLINE_FILE"  # Rimuovi eventuali spazi multipli
        echo "Unwanted parameters removed from $CMDLINE_FILE if they existed."
    else
        echo "$CMDLINE_FILE does not exist."
    fi
    
    # Rimuovi la riga con "kernel=Image66_rt.img" da config.txt
    if [ -f "$CONFIG_FILE" ]; then
        echo "Checking $CONFIG_FILE for the kernel image line..."
        sed -i '/^kernel=Image66_rt.img/d' "$CONFIG_FILE"
        echo "kernel=Image66_rt.img removed from $CONFIG_FILE if it existed."
    else
        echo "$CONFIG_FILE does not exist."
    fi


    printf "\\e[32m✔\\e[0m\\n"
    echo "Default kernel restored, please restart your system to take changes have effect."
}

# Tune System for Real-Time
tune_system() {
    echo -n "Tuning system for real-time performance... "
    (
        addgroup realtime >/dev/null 2>&1
        usermod -a -G realtime "$SUDO_USER" >/dev/null 2>&1

        cat << EOF > /etc/security/limits.conf
@realtime soft rtprio 99
@realtime soft priority 99
@realtime soft memlock 102400
@realtime hard rtprio 99
@realtime hard priority 99
@realtime hard memlock 102400
EOF

        echo "force_turbo=1" >> /boot/firmware/config.txt
        echo "arm_freq=1500" >> /boot/firmware/config.txt
        echo "arm_freq_min=1500" >> /boot/firmware/config.txt

        sed -i 's/rootwait/rootwait rcu_nocb_poll rcu_nocbs=2,3 nohz=on nohz_full=2,3 kthread_cpus=0,1 irqaffinity=0,1 isolcpus=managed_irq,domain,2,3/' /boot/firmware/cmdline.txt

        echo 'GOVERNOR="performance"' > /etc/default/cpufrequtils
        systemctl disable ondemand >/dev/null 2>&1
        systemctl enable cpufrequtils >/dev/null 2>&1
    ) &
    pid=$!
    spinner $pid
    wait $pid
    printf "\\e[32m✔\\e[0m\\n"
    echo "System tuned for real-time performance, please restart your system to take changes have effect."
}

# Restore System Settings
restore_system_tuning() {
    echo -n "Restoring system settings... "
    (
        delgroup realtime >/dev/null 2>&1
        sed -i '/@realtime/d' /etc/security/limits.conf >/dev/null 2>&1

        sed -i '/force_turbo=1/d' /boot/firmware/config.txt
        sed -i '/arm_freq=1500/d' /boot/firmware/config.txt
        sed -i '/arm_freq_min=1500/d' /boot/firmware/config.txt

        sed -i 's/ rcu_nocb_poll rcu_nocbs=2,3 nohz=on nohz_full=2,3 kthread_cpus=0,1 irqaffinity=0,1 isolcpus=managed_irq,domain,2,3//' /boot/firmware/cmdline.txt

        rm /etc/default/cpufrequtils >/dev/null 2>&1
        systemctl enable ondemand >/dev/null 2>&1
        systemctl disable cpufrequtils >/dev/null 2>&1
    ) &
    pid=$!
    spinner $pid
    wait $pid
    printf "\\e[32m✔\\e[0m\\n"
    echo "System settings restored, please restart your system to take changes have effect."
}



# Funzione per ottenere tutte le release disponibili con la descrizione della commit
get_all_releases() {
    echo "Fetching available releases and their commit descriptions from GitHub..."
    echo "Available releases:"
    API_URL="https://api.github.com/repos/antoniopicone/docker_rt/releases"

    # Scarica le release da GitHub usando curl
    RELEASES_JSON=$(curl -s "$API_URL")

    # Estrai i tag delle release e i relativi body dal JSON
    # tag_name è riportato come "tag_name": "valore", quindi filtriamo usando grep e sed
    TAG_NAMES=$(echo "$RELEASES_JSON" | grep '"tag_name":' | sed -E 's/.*"tag_name": "(.*)",/\1/' | sed 's/^ *//;s/ *$//')
    BODIES=$(echo "$RELEASES_JSON" | grep '"body":' | sed -E 's/.*"body": "(.*)",/\1/' | sed 's/\\r\\n/ /g' | sed 's/^ *"body"://g' | sed 's/^ *//;s/ *$//' | sed 's/"//g')

    # Controlla se sono state trovate release
    if [ -z "$TAG_NAMES" ]; then
    echo "No releases available :(. Exiting."
    exit 1
    fi

    # Mostra l'elenco delle release all'utente
    i=1
    # Utilizziamo un ciclo while con echo "in sequenza" per evitare problemi di IFS con pipe
    while IFS= read -r tag; do
        # Estrae l'i-esimo body
        body=$(echo "$BODIES" | sed -n "${i}p" | sed 's/^ *//;s/ *$//')
        echo "$i) Release $tag ( $body )"
        i=$((i+1))
    done << EOF
    $TAG_NAMES
EOF

    # Aggiungi un'opzione per la selezione del kernel locale
    echo "$i) Provide a local path to linux66_rt.tar.gz"

    # Chiedi all'utente di scegliere una release
    read -p "Select an option:  " choice

    # Verifica che l'input dell'utente sia un numero valido
    if ! [ "$choice" -ge 1 ] 2>/dev/null || [ "$choice" -gt $i ]; then
    echo "Option not available."
    exit 1
    fi

    # Se l'utente sceglie l'opzione per il file kernel locale
    if [ "$choice" -eq "$i" ]; then
    select_local_file
    fi

    # Seleziona la release corrispondente se non è stata scelta l'opzione del kernel locale
    i=1
    echo "$TAG_NAMES" | while IFS= read -r tag; do
    if [ "$i" -eq "$choice" ]; then
        body=$(echo "$BODIES" | sed -n "${i}p")
        RELEASE_URL=$tag
        download_and_install_kernel
        # Qui puoi aggiungere il codice per installare la release scelta
        break
    fi
    i=$((i+1))
    done

    # echo "$i) Provide a local path to linux66_rt.tar.gz"
    # echo ""
    # read -p "Select a release or provide the path (enter number): " selection

    # if [ "$selection" -eq "$i" ]; then
    #     select_local_file
    # else
    #     selected_release=${RELEASE_TAGS[$((selection - 1))]}
    #     if [[ -z "$selected_release" ]]; then
    #         echo "Invalid selection."
    #         exit 1
    #     fi
    #     RELEASE_URL=$selected_release
    #     echo "Selected release: $RELEASE_URL"
    #     download_and_install_kernel
    # fi
}


# Funzione per verificare il file locale
select_local_file() {
    while true; do
        read -p "Enter the local path to linux66_rt.tar.gz: " local_path
        if [ -f "$local_path" ]; then
            FILE_PATH="$local_path"
            extract_kernel_from_local_file
            break
        else
            echo "File not found at the specified path."
            echo "1) Try again"
            echo "2) Return to menu"
            read -p "Choose an option: " retry_option
            case $retry_option in
                1) continue ;;
                2) main_menu ;;
                *) echo "Invalid option, returning to menu."; menu ;;
            esac
        fi
    done
}

# Funzione per scaricare e installare il kernel real-time
download_and_install_kernel() {
    
    FILE_PATH="./linux66_rt.tar.gz"
    if [ "$RPI_MODEL" = "4" ]; then
        echo "Downloading $RELEASE_URL file for Raspberry Pi 4..."
        wget -q -O $FILE_PATH https://github.com/antoniopicone/docker_rt/releases/download/$RELEASE_URL/linux66_rt_bcm2711_defconfig.tar.gz
    elif [ "$RPI_MODEL" = "5" ]; then
        echo "Downloading $RELEASE_URL file for Raspberry Pi 5..."
        wget -q -O $FILE_PATH https://github.com/antoniopicone/docker_rt/releases/download/$RELEASE_URL/linux66_rt_bcm2712_defconfig.tar.gz
    else
        echo "Unsupported Raspberry Pi model: $RPI_MODEL"
        exit 1
    fi
    pid=$!
    spinner $pid
    wait $pid
    exit_status=$?
    if [ $exit_status -ne 0 ]; then
        printf "Error downloading kernel from GitHub.\b✗\n"
        
    else
        printf "Kernel downloaded.\\e[32m✔\\e[0m\\n"
         
    fi
   extract_kernel_from_local_file
}

# Funzione per installare il kernel da file locale
extract_kernel_from_local_file() {
    echo "Extracting kernel and toolchain (will take some time, take a coffee :)..."
    tar -xzf "$FILE_PATH" -C ./
    pid=$!
    spinner $pid
    wait $pid
    exit_status=$?
    if [ $exit_status -ne 0 ]; then
        printf "Error extracting kernel toolchain.\b✗\n"
         
    else
        printf "Kernel toolchain extracted.\\e[32m✔\\e[0m\\n"
        
    fi
    install_rt_kernel
}


# Funzione per installare il kernel RT
install_rt_kernel() {

    cd linux

    echo "Installing modules in library..."
    make -j$(nproc) modules_install  2>/dev/null

    echo "Copying files in correct places..."
    cp -rf ./arch/arm64/boot/Image /boot/firmware/Image66_rt.img
    cp -rf ./arch/arm64/boot/dts/broadcom/*.dtb /boot/firmware/
    cp -rf ./arch/arm64/boot/dts/overlays/*.dtb* /boot/firmware/overlays/
    cp -rf ./arch/arm64/boot/dts/overlays/README /boot/firmware/overlays/
    #echo "kernel=Image66_rt.img" >> /boot/firmware/config.txt
    echo "Setting nel kernel in config file..."

    if grep -q "^kernel=[^ ]\+" /boot/firmware/config.txt; then
        # Se la stringa "kernel=" seguita da una parola esiste, la sostituisci con "kernel=image66_rt.img"
        sed -i 's/^kernel=[^ ]\+/kernel=Image66_rt.img/' /boot/firmware/config.txt
    else
        # Se la stringa non esiste, la aggiungi alla fine del file
        echo "kernel=Image66_rt.img" >> /boot/firmware/config.txt
    fi

    # Create cpu device for realtime containers
    echo "Checking (or creating) CPU device..."
    
    if [ ! -d "/dev/cpu" ]; then
        echo "Creating /dev/cpu/0..."
        mkdir -p /dev/cpu
        mknod /dev/cpu/0 b 5 1
    else
        echo "/dev/cpu already exists, skipping creation."
    fi
    

    echo "Setting rt parameters in cmdline file..."

    # Set C0 to avoid idle on CPUs
    # Definisci i parametri da cercare
    PARAMS="processor.max_cstate=0 intel_idle.max_cstate=0 idle=pol"

    # Verifica se i parametri esistono già nel file cmdline.txt dopo "rootwait"
    if grep -q "rootwait.*$PARAMS" /boot/firmware/cmdline.txt; then
        echo "I parametri sono già presenti nel file cmdline.txt"
    else
        # Se i parametri non esistono, aggiungili dopo "rootwait"
        sed -i 's/\(rootwait\)/\1 '"$PARAMS"'/' /boot/firmware/cmdline.txt
        echo "I parametri sono stati aggiunti a cmdline.txt"
    fi
    pid=$!
    spinner $pid
    wait $pid
    exit_status=$?
    if [ $exit_status -ne 0 ]; then
        printf "Error installing kernel.\b✗\n"
         
    else
        printf "Kernel installed.\\e[32m✔\\e[0m\\n"
         
    fi
    echo "Please restart your system to take changes have effect."
}


enable_ethernet_over_usbc() {

    echo "Configuring ethernet of USB C..." 
    (
    sed -i 's/rootwait/rootwait modules-load=dwc2,g_ether/' /boot/firmware/cmdline.txt
    sh -c 'echo "dtoverlay=dwc2,dr_mode=peripheral" >> /boot/firmware/config.txt'
    sh -c 'echo "libcomposite" >> /etc/modules'
    sh -c 'echo "denyinterfaces usb0" >> /etc/dhcpcd.conf'

    # Install dnsmasq
    apt-get update >/dev/null 2>&1
    apt-get install -y dnsmasq >/dev/null 2>&1
    apt-get clean >/dev/null 2>&1

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
    ) &
    pid=$!
    spinner $pid
    wait $pid
    printf "\\e[32m✔\\e[0m\\n System configured for ethernet over USB C."
}



# Main Menu
main_menu() {

    clear

echo "
    ____             ____  _                   __    _                 
   / __ \___  ____ _/ / /_(_)___ ___  ___     / /   (_)___  __  ___  __
  / /_/ / _ \/ __  / / __/ / __  __ \/ _ \   / /   / / __ \/ / / / |/_/
 / _, _/  __/ /_/ / / /_/ / / / / / /  __/  / /___/ / / / / /_/ />  <  
/_/ |_|\___/\__,_/_/\__/_/_/ /_/ /_/\___/  /_____/_/_/ /_/\__,_/_/|_|
 
                                                      on Raspberry Pi
"


    while true; do
        echo "Raspberry Pi Setup Script"
        echo "Model: Raspberry Pi $RPI_MODEL"
        echo
        echo "Please select an option:"
        echo "1) Update OS"
        if is_service_disabled "bluetooth"; then
            echo "2) Restore Unnecessary Services"
        else
            echo "2) Disable Unnecessary Services"
        fi
        DEFAULT_TARGET=$(systemctl get-default)
        if [ "$DEFAULT_TARGET" = "multi-user.target" ]; then
            echo "3) Enable GUI"
        else
            echo "3) Disable GUI"
        fi
        if systemctl is-enabled sleep.target >/dev/null 2>&1; then
            echo "4) Disable Power Management"
        else
            echo "4) Enable Power Management"
        fi
        if is_docker_installed; then
            echo "5) Uninstall Docker"
        else
            echo "5) Install Docker"
        fi
        if is_rt_kernel_installed; then
            echo "6) Restore Default Kernel"
        else
            echo "6) Install Real-Time Kernel"
        fi
        if is_system_tuned; then
            echo "7) Restore System Settings tuned for Real-Time"
        else
            echo "7) Tune System for Real-Time"
        fi
        echo "8) Configure ethernet over USB C"
        echo "9) Execute All Actions"
        echo "10) Exit"
        echo
        echo -n "Enter your choice [9]: "
        read -r CHOICE
        CHOICE=${CHOICE:-9}
        case $CHOICE in
            1)
                update_os
                
                ;;
            2)
                if is_service_disabled "bluetooth"; then
                    enable_services
                else
                    disable_services
                fi
                
                ;;
            3)
                DEFAULT_TARGET=$(systemctl get-default)
                if [ "$DEFAULT_TARGET" = "multi-user.target" ]; then
                    enable_gui
                else
                    disable_gui
                fi
                
                ;;
            4)
                if systemctl is-enabled sleep.target >/dev/null 2>&1; then
                    disable_power_management
                else
                    enable_power_management
                fi
                
                ;;
            5)
                if is_docker_installed; then
                    uninstall_docker
                else
                    install_docker
                fi
                
                ;;
            6)
                if is_rt_kernel_installed; then
                    restore_default_kernel
                else
                    get_all_releases
                fi
                
                ;;
            7)
                if is_system_tuned; then
                    restore_system_tuning
                else
                    tune_system
                fi
                
                ;;
            8)
                enable_ethernet_over_usbc
                
                ;;
            9)
                echo "Executing all actions..."
                update_os
                disable_services
                disable_gui
                disable_power_management
                install_docker
                get_all_releases
                tune_system
                
                ;;
            10)
                exit 0
                ;;
            *)
                echo "Invalid choice. Please try again."
                ;;
        esac
        # Chiama wait_for_keypress se l'utente non ha scelto di uscire o inserito un'opzione non valida
        if [ "$CHOICE" != "10" ] && [ -z "$INVALID_CHOICE" ]; then
            wait_for_keypress
        fi
        echo
    done
}

# Check for root privileges
if [ "$(id -u)" -ne 0 ]; then
    echo "Please run this script with sudo or as root."
    exit 1
fi

# Get the sudo user
if [ -z "$SUDO_USER" ]; then
    echo "This script must be run using sudo."
    exit 1
fi

check_rpi_model
main_menu

