#!/bin/bash
clear

# Funzione per verificare il modello di Raspberry Pi
check_rpi_version() {
    # Sopprime eventuali errori e cattura il modello
    MODEL=$(cat /proc/cpuinfo 2>/dev/null | grep "Model" | awk '{print $5}')
    
    # Se il modello non viene rilevato o non è supportato, esce con un messaggio di errore
    if [ -z "$MODEL" ]; then
        echo "Error: Unable to detect Raspberry Pi model or unsupported model. Exiting :("
        #exit 1
    elif [ "$MODEL" = "4" ]; then
        echo "Raspberry Pi 4"
    elif [ "$MODEL" = "5" ]; then
        echo "Raspberry Pi 5"
    else
        echo "Error: Unsupported Raspberry Pi model: $MODEL. Exiting :("
        #exit 1
    fi
}



echo "
    ____             ____  _                   __    _                 
   / __ \___  ____ _/ / /_(_)___ ___  ___     / /   (_)___  __  ___  __
  / /_/ / _ \/ __  / / __/ / __  __ \/ _ \   / /   / / __ \/ / / / |/_/
 / _, _/  __/ /_/ / / /_/ / / / / / /  __/  / /___/ / / / / /_/ />  <  
/_/ |_|\___/\__,_/_/\__/_/_/ /_/ /_/\___/  /_____/_/_/ /_/\__,_/_/|_|                               
                                                      on Raspberry Pi
"

check_rpi_version



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
    echo "Scelta non valida."
    exit 1
    fi

    # Se l'utente sceglie l'opzione per il file kernel locale
    if [ "$choice" -eq "$i" ]; then
    read -p "Inserisci il percorso completo del file kernel: " kernel_path
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
            install_kernel_from_local_file
            break
        else
            echo "File not found at the specified path."
            echo "1) Try again"
            echo "2) Return to menu"
            read -p "Choose an option: " retry_option
            case $retry_option in
                1) continue ;;
                2) menu ;;
                *) echo "Invalid option, returning to menu."; menu ;;
            esac
        fi
    done
}

# Funzione per scaricare e installare il kernel real-time
download_and_install_kernel() {
    
    if [ "$MODEL" = "4" ]; then
        echo "Downloading $RELEASE_URL file for Raspberry Pi 4..."
        wget -q -O linux66_rt.tar.gz https://github.com/antoniopicone/docker_rt/releases/download/$RELEASE_URL/linux66_rt_bcm2711_defconfig.tar.gz
    elif [ "$MODEL" = "5" ]; then
        echo "Downloading $RELEASE_URL file for Raspberry Pi 5..."
        wget -q -O linux66_rt.tar.gz https://github.com/antoniopicone/docker_rt/releases/download/$RELEASE_URL/linux66_rt_bcm2712_defconfig.tar.gz
    else
        echo "Unsupported Raspberry Pi model: $MODEL"
        exit 1
    fi

    tar -xzf linux66_rt.tar.gz -C ./
    install_rt_kernel
}

# Funzione per installare il kernel da file locale
install_kernel_from_local_file() {
    tar -xzf "$FILE_PATH" -C ./
    install_rt_kernel
}


# Funzione per installare il kernel RT
install_rt_kernel() {

    readonly KERNEL_SETUP_DIR=$(pwd)

    if [[ -n "$FILE_PATH" ]]; then
        tar -xzf "$FILE_PATH" -C ./
    else
        tar -xzf linux66_rt.tar.gz -C ./
    fi

    cd linux

    make -j$(nproc) modules_install

    cp -rf ./arch/arm64/boot/Image /boot/firmware/Image66_rt.img
    cp -rf ./arch/arm64/boot/dts/broadcom/*.dtb /boot/firmware/
    cp -rf ./arch/arm64/boot/dts/overlays/*.dtb* /boot/firmware/overlays/
    cp -rf ./arch/arm64/boot/dts/overlays/README /boot/firmware/overlays/
    #echo "kernel=Image66_rt.img" >> /boot/firmware/config.txt
    if grep -q "^kernel=[^ ]\+" /boot/firmware/config.txt; then
        # Se la stringa "kernel=" seguita da una parola esiste, la sostituisci con "kernel=image66_rt.img"
        sed -i 's/^kernel=[^ ]\+/kernel=image66_rt.img/' /boot/firmware/config.txt
    else
        # Se la stringa non esiste, la aggiungi alla fine del file
        echo "kernel=Image66_rt.img" >> /boot/firmware/config.txt
    fi

    # Create cpu device for realtime containers
    mkdir -p /dev/cpu
    mknod /dev/cpu/0 b 5 1

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
}



# Menu principale
menu() {
    echo ""
    echo "Please select an option (default is 11):"
    echo "1) Update OS"
    echo "2) Disable unnecessary services"
    echo "3) Disable GUI"
    echo "4) Disable power management"
    echo "5) Install Docker"
    echo "6) Download and Install Linux RT kernel"
    echo "7) Tune system for realtime"
    echo "8) Enable Ethernet over USB-C"
    echo "9) Clean up the system"
    echo "10) Execute all steps"
    echo "11) Exit"
    echo ""
    read -p "Enter your choice [1-11]: " choice

    choice=${choice:-10}

    case $choice in
        1) run_with_spinner update_os "Updating OS"; menu ;;
        2) run_with_spinner disable_unnecessary_services "Disabling unnecessary services"; menu ;;
        3) run_with_spinner disable_gui "Disabling GUI"; menu ;;
        4) run_with_spinner disable_power_mgmt "Disabling power management"; menu ;;
        5) run_with_spinner install_docker "Installing Docker"; menu ;;
        6) get_all_releases; menu ;;
        7) run_with_spinner tune_system_for_realtime "Tuning system for realtime"; menu ;;
        8) run_with_spinner enable_ethernet_over_usbc "Enabling Ethernet over USB-C"; menu ;;
        9) run_with_spinner cleanup "Cleaning up the system"; menu ;;
        10) 
            run_with_spinner update_os "Updating OS"
            run_with_spinner disable_unnecessary_services "Disabling unnecessary services"
            run_with_spinner disable_gui "Disabling GUI"
            run_with_spinner disable_power_mgmt "Disabling power management"
            run_with_spinner install_docker "Installing Docker"
            get_all_releases
            run_with_spinner tune_system_for_realtime "Tuning system for realtime"
            run_with_spinner enable_ethernet_over_usbc "Enabling Ethernet over USB-C"
            run_with_spinner cleanup "Cleaning up the system"
            request_reboot
            ;;
        11) echo "Exiting..."; exit 0 ;;
        *) echo "Invalid option, please try again."; menu ;;
    esac
}

# Avvia il menu
menu
            ;;
        11) echo "Exiting..."; exit 0 ;;
        *) echo "Invalid option, please try again."; menu ;;
    esac
}

# Avvia il menu
menu
