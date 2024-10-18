import numpy as np
import threading
import time
from multiprocessing import shared_memory

class DMAGPIOSimulator:
    def __init__(self, num_pins=28):
        self.num_pins = num_pins
        self.shm = shared_memory.SharedMemory(create=True, size=num_pins)
        self.gpio_array = np.ndarray((num_pins,), dtype=np.uint8, buffer=self.shm.buf)
        self.gpio_array.fill(0)
        self.adc_simulator = ADCSimulator()
        self.running = False
        self.dma_thread = None

    def start_dma_simulation(self):
        self.running = True
        self.dma_thread = threading.Thread(target=self._dma_simulation)
        self.dma_thread.start()

    def stop_dma_simulation(self):
        self.running = False
        if self.dma_thread:
            self.dma_thread.join()
        self.shm.close()
        self.shm.unlink()

    def _dma_simulation(self):
        while self.running:
            # Simula il trasferimento DMA aggiornando i valori GPIO
            cs = self.gpio_array[8]
            sclk = self.gpio_array[11]
            mosi = self.gpio_array[10]
            
            if cs == 0 and sclk == 1:  # CS attivo basso, SCLK alto
                # Simula la lettura dell'ADC
                channel = (mosi & 0x07)
                adc_value = self.adc_simulator.read_adc(channel)
                
                # Aggiorna MISO con il valore dell'ADC
                self.gpio_array[9] = adc_value & 0xFF
            
            time.sleep(0.000001)  # Simula il tempo di trasferimento DMA

    def set_pin(self, pin, value):
        if 0 <= pin < self.num_pins:
            self.gpio_array[pin] = value
        else:
            raise ValueError(f"Pin {pin} non valido")

    def get_pin(self, pin):
        if 0 <= pin < self.num_pins:
            return self.gpio_array[pin]
        else:
            raise ValueError(f"Pin {pin} non valido")

class ADCSimulator:
    def __init__(self, fundamental_freq=50, sampling_rate=2000, resolution=10):
        self.fundamental_freq = fundamental_freq
        self.sampling_rate = sampling_rate
        self.resolution = resolution
        self.max_value = 2**resolution - 1
        self.time = 0

    def read_adc(self, channel):
        t = self.time
        # Genera le tre fasi
        phases = [
            (np.sin(2 * np.pi * self.fundamental_freq * t) + 1) / 2,
            (np.sin(2 * np.pi * self.fundamental_freq * t - 2*np.pi/3) + 1) / 2,
            (np.sin(2 * np.pi * self.fundamental_freq * t + 2*np.pi/3) + 1) / 2
        ]
        
        # Aggiungi le armoniche (2a e 3a) alla fase selezionata
        selected_phase = phases[channel % 3]
        selected_phase += 0.1 * np.sin(4 * np.pi * self.fundamental_freq * t)
        selected_phase += 0.05 * np.sin(6 * np.pi * self.fundamental_freq * t)
        
        # Scala e converte in intero a 10 bit
        adc_value = int(selected_phase * self.max_value)
        
        # Assicura che il valore sia nel range corretto
        adc_value = max(0, min(adc_value, self.max_value))
        
        self.time += 1 / self.sampling_rate
        return adc_value

# Simulazione della libreria RPi.GPIO
class GPIO:
    BCM = "BCM"
    OUT = "OUT"
    IN = "IN"
    
    @staticmethod
    def setmode(mode):
        print(f"GPIO mode set to {mode}")
    
    @staticmethod
    def setup(pin, mode):
        # Non fa nulla nella simulazione DMA
        pass
    
    @staticmethod
    def output(pin, value):
        dma_simulator.set_pin(pin, value)
    
    @staticmethod
    def input(pin):
        return dma_simulator.get_pin(pin)

dma_simulator = DMAGPIOSimulator()
dma_simulator.start_dma_simulation()
