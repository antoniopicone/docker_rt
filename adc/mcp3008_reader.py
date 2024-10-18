import RPi.GPIO as GPIO
import time

class MCP3008Reader:
    def __init__(self):
        self.SPICS = 8
        self.SPIMISO = 9
        self.SPIMOSI = 10
        self.SPICLK = 11

        GPIO.setmode(GPIO.BCM)
        GPIO.setup(self.SPICS, GPIO.OUT, initial=GPIO.HIGH)
        GPIO.setup(self.SPIMISO, GPIO.IN)
        GPIO.setup(self.SPIMOSI, GPIO.OUT)
        GPIO.setup(self.SPICLK, GPIO.OUT)

        print(f"Configurazione iniziale CS: {GPIO.input(self.SPICS)}")

    def measure_throughput(self, duration=10, channel=0):
        start_time = time.time()
        count = 0
        while time.time() - start_time < duration:
            self.read_adc(channel)
            count += 1
        
        elapsed_time = time.time() - start_time
        throughput = count / elapsed_time
        return throughput
    
    def read_adc(self, channel, debug=False):
        if channel > 7 or channel < 0:
            return -1

        print(f"Stato CS prima della lettura: {GPIO.input(self.SPICS)}")
        GPIO.output(self.SPICS, GPIO.LOW)
        print(f"Stato CS dopo l'attivazione: {GPIO.input(self.SPICS)}")

        command = 0b11000000 | (channel << 3)
        self._send_bits(command, 8, debug)

        # Leggi un bit nullo
        self._clock_tick()

        adcvalue = 0
        for i in range(10):
            adcvalue <<= 1
            if GPIO.input(self.SPIMISO):
                adcvalue |= 0x1
            self._clock_tick()

            if debug:
                print(f"Bit {i}: {adcvalue & 0x1}")

        GPIO.output(self.SPICS, GPIO.HIGH)
        print(f"Stato CS dopo la disattivazione: {GPIO.input(self.SPICS)}")

        if debug:
            print(f"Valore ADC letto: {adcvalue}")

        return adcvalue

    def _send_bits(self, data, num_bits, debug=False):
        for i in range(num_bits):
            bit = (data & 0x80) >> 7
            GPIO.output(self.SPIMOSI, bit)
            if debug:
                print(f"Inviato bit {i}: {bit}")
            data <<= 1
            self._clock_tick()

    def _clock_tick(self):
        GPIO.output(self.SPICLK, GPIO.HIGH)
        time.sleep(0.00001)  # 10 µs delay
        GPIO.output(self.SPICLK, GPIO.LOW)
        time.sleep(0.00001)  # 10 µs delay

    def check_miso_state(self):
        high_count = 0
        low_count = 0
        for _ in range(100):
            if GPIO.input(self.SPIMISO):
                high_count += 1
            else:
                low_count += 1
            time.sleep(0.001)
        print(f"MISO stato: Alto {high_count}%, Basso {low_count}%")

    def cleanup(self):
        GPIO.cleanup()

def convert_to_voltage(adc_value):
    return (adc_value * 3.3) / 1023

if __name__ == "__main__":
    try:
        reader = MCP3008Reader()
        print("Controllo dello stato iniziale del pin MISO:")
        throughput = reader.measure_throughput(duration=10)
        print(f"Throughput: {throughput:.2f} letture/secondo")
        reader.check_miso_state()
        
        # while True:
        #     for channel in range(8):
        #         adc_value = reader.read_adc(channel, debug=(channel == 0))  # Debug solo per il canale 0
        #         voltage = convert_to_voltage(adc_value)
        #         print(f"Canale {channel}: ADC = {adc_value}, Tensione = {voltage:.3f}V")
        #     print("-" * 40)
        #     time.sleep(0.1)
    except KeyboardInterrupt:
        print("\nLettura interrotta dall'utente")
    finally:
        reader.cleanup()
        print("GPIO puliti")