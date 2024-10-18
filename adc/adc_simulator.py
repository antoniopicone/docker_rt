import numpy as np
import time

class ADCSimulator:
    def __init__(self, fundamental_freq=50, sampling_rate=2000, resolution=10):
        self.fundamental_freq = fundamental_freq
        self.sampling_rate = sampling_rate
        self.resolution = resolution
        self.max_value = 2**resolution - 1
        self.time = 0

    def generate_sample(self):
        t = self.time
        # Genera le tre fasi
        phase_a = np.sin(2 * np.pi * self.fundamental_freq * t)
        phase_b = np.sin(2 * np.pi * self.fundamental_freq * t - 2*np.pi/3)
        phase_c = np.sin(2 * np.pi * self.fundamental_freq * t + 2*np.pi/3)
        
        # Aggiungi le armoniche (2a e 3a)
        phase_a += 0.1 * np.sin(4 * np.pi * self.fundamental_freq * t)
        phase_a += 0.05 * np.sin(6 * np.pi * self.fundamental_freq * t)
        
        # Scala e converte in intero a 10 bit
        adc_value = int((phase_a + 1) * self.max_value / 2)
        
        # Assicura che il valore sia nel range corretto
        adc_value = max(0, min(adc_value, self.max_value))
        
        self.time += 1 / self.sampling_rate
        return adc_value

    def read_adc(self, channel):
        # Simula un ritardo di lettura
        time.sleep(1 / self.sampling_rate)
        return self.generate_sample()

# Esempio di utilizzo
adc_sim = ADCSimulator()

def read_adc(channel):
    return adc_sim.read_adc(channel)
