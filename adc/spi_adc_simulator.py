import numpy as np
import time

class SPIDevSimulator:
    def __init__(self):
        self.adc_simulator = ADCSimulator()
    
    def open(self, bus, device):
        print(f"SPI bus {bus}, device {device} opened (simulated)")
    
    def xfer2(self, data):
        # Simula il comportamento dell'MCP3008
        if len(data) != 3:
            raise ValueError("Expected 3 bytes for MCP3008 communication")
        
        start_bit = data[0] & 0x01
        single_ended = (data[1] & 0x80) >> 7
        channel = (data[1] & 0x70) >> 4
        
        if start_bit != 1 or single_ended != 1:
            raise ValueError("Invalid configuration bits")
        
        adc_value = self.adc_simulator.read_adc(channel)
        
        # Formato di risposta MCP3008: [0, MSB, LSB]
        return [0, (adc_value >> 8) & 0xFF, adc_value & 0xFF]
    
    def max_speed_hz(self, speed):
        print(f"SPI speed set to {speed} Hz (simulated)")

class ADCSimulator:
    def __init__(self, fundamental_freq=50, sampling_rate=6000, resolution=10):
        self.fundamental_freq = fundamental_freq
        self.sampling_rate = sampling_rate
        self.resolution = resolution
        self.max_value = 2**resolution - 1
        self.time = 0

    def read_adc(self, channel):
        t = self.time
        # Genera le tre fasi
        phases = [
            np.sin(2 * np.pi * self.fundamental_freq * t),
            np.sin(2 * np.pi * self.fundamental_freq * t - 2*np.pi/3),
            np.sin(2 * np.pi * self.fundamental_freq * t + 2*np.pi/3)
        ]
        
        # Aggiungi le armoniche (2a e 3a) alla fase selezionata
        selected_phase = phases[channel % 3]
        selected_phase += 0.1 * np.sin(4 * np.pi * self.fundamental_freq * t)
        selected_phase += 0.05 * np.sin(6 * np.pi * self.fundamental_freq * t)
        
        # Scala e converte in intero a 10 bit
        adc_value = int((selected_phase + 1) * self.max_value / 2)
        
        # Assicura che il valore sia nel range corretto
        adc_value = max(0, min(adc_value, self.max_value))
        
        self.time += 1 / self.sampling_rate
        return adc_value

# Sostituzione del modulo spidev con il nostro simulatore
class spidev:
    SpiDev = SPIDevSimulator
