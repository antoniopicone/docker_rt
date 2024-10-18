import spidev
import time

spi = spidev.SpiDev()
spi.open(0, 0)
spi.max_speed_hz = 1000000

def read_adc(channel):
    if channel > 7 or channel < 0:
        return -1
    r = spi.xfer2([1, (8 + channel) << 4, 0])
    data = ((r[1] & 3) << 8) + r[2]
    return data

def convert_to_voltage(adc_value):
    return (adc_value * 3.3) / 1023

try:
    while True:
        for channel in range(8):  # Leggi tutti gli 8 canali
            adc_value = read_adc(channel)
            voltage = convert_to_voltage(adc_value)
            print(f"Canale {channel}: ADC = {adc_value}, Tensione = {voltage:.2f}V")
        print("-" * 40)
        time.sleep(1)

except KeyboardInterrupt:
    print("\nLettura interrotta dall'utente")
finally:
    spi.close()
    print("Connessione SPI chiusa")
