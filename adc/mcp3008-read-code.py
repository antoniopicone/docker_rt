import spidev
import time

# Configurazione SPI
spi = spidev.SpiDev()
spi.open(0, 0)  # Bus 0, Device 0
spi.max_speed_hz = 1000000  # 1MHz

sampling_rate = 20000  # Hz
sampling_interval = 1 / sampling_rate


def read_adc(channel):
    if channel > 7 or channel < 0:
        return -1
    
    # Costruisci il comando per l'MCP3008
    # Primo byte: Start bit (1) + Single-ended (1) + Channel number (3 bits)
    # Secondo byte: Don't care
    # Terzo byte: Don't care
    r = spi.xfer2([1, (8 + channel) << 4, 0])
    
    # Elabora la risposta
    # Il primo bit della risposta è sempre 0
    # I successivi 10 bit sono il valore ADC
    data = ((r[1] & 3) << 8) + r[2]
    return data

def convert_to_voltage(adc_value):
    # Assumendo che VREF sia 3.3V e la risoluzione sia 10 bit
    return (adc_value * 3.3) / 1023

try:
    while True:

        start_time = time.time()

        for channel in range(3):  # Leggi i primi 3 canali
            adc_value = read_adc(channel)
            voltage = convert_to_voltage(adc_value)
            print(f"Canale {channel}: ADC = {adc_value}, Tensione = {voltage:.2f}V")

        # Aspetta fino al prossimo intervallo di campionamento
        time.sleep(max(0, sampling_interval - (time.time() - start_time)))

except KeyboardInterrupt:
    print("\nLettura interrotta dall'utente")
finally:
    spi.close()
    print("Connessione SPI chiusa")
