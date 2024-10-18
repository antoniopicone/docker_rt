from adc_simulator import read_adc
import time

sampling_rate = 20000  # Hz
sampling_interval = 1 / sampling_rate

try:
    while True:
        start_time = time.time()
        value = read_adc(0)  # Leggi dal canale 0 (simulato)
        print(f"ADC Value: {value}")
        
        # Aspetta fino al prossimo intervallo di campionamento
        time.sleep(max(0, sampling_interval - (time.time() - start_time)))

except KeyboardInterrupt:
    print("Simulazione terminata.")