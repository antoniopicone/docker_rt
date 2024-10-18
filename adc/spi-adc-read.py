import time
from spi_adc_simulator import spidev

spi = spidev.SpiDev()
spi.open(0, 0)
spi.max_speed_hz = 1000000  # Imposta la velocità SPI

def read_adc(channel):
    if channel > 7 or channel < 0:
        raise ValueError("Il canale deve essere tra 0 e 7")
    r = spi.xfer2([1, (8 + channel) << 4, 0])
    adc_value = ((r[1] & 3) << 8) + r[2]
    return adc_value

sampling_rate = 6000  # Hz
sampling_interval = 1 / sampling_rate

try:
    while True:
        start_time = time.time()
        for channel in range(3):  # Leggi i primi 3 canali per le 3 fasi
            value = read_adc(channel)
            #print(f"Canale {channel}, Valore ADC: {value}")
        
        # Aspetta fino al prossimo intervallo di campionamento
        time.sleep(max(0, sampling_interval - (time.time() - start_time)))

except KeyboardInterrupt:
    print("Simulazione terminata.")