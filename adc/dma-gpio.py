import time
from dma_gpio_simulator import GPIO, dma_simulator

# Configurazione dei pin
CS_PIN = 8
CLOCK_PIN = 11
MOSI_PIN = 10
MISO_PIN = 9

GPIO.setmode(GPIO.BCM)

def read_adc(channel):
    if channel > 7 or channel < 0:
        return -1

    GPIO.output(CS_PIN, 1)  # Assicurati che CS sia alto all'inizio
    GPIO.output(CS_PIN, 0)  # Attiva CS

    commandout = channel
    commandout |= 0x18  # Start bit + single-ended bit
    commandout <<= 3    # Abbiamo bisogno di inviare 5 bit

    for i in range(5):
        if (commandout & 0x80):
            GPIO.output(MOSI_PIN, 1)
        else:
            GPIO.output(MOSI_PIN, 0)
        commandout <<= 1
        GPIO.output(CLOCK_PIN, 1)
        GPIO.output(CLOCK_PIN, 0)

    adcout = 0
    for i in range(12):
        GPIO.output(CLOCK_PIN, 1)
        GPIO.output(CLOCK_PIN, 0)
        adcout <<= 1
        if (GPIO.input(MISO_PIN)):
            adcout |= 0x1

    GPIO.output(CS_PIN, 1)  # Disattiva CS
    
    adcout >>= 1  # Il primo bit è 'null', quindi lo scartiamo
    return adcout

try:
    while True:
        for channel in range(3):  # Leggi i primi 3 canali
            value = read_adc(channel)
            print(f"Canale {channel}, Valore ADC: {value}")
        time.sleep(0.5)  # Attendi mezzo secondo tra le letture

except KeyboardInterrupt:
    print("Simulazione terminata.")
    dma_simulator.stop_dma_simulation()