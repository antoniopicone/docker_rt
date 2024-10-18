import RPi.GPIO as GPIO
import time

class MCP3008Reader:
    def __init__(self):
        self.SPICS = 8
        self.SPIMISO = 9
        self.SPIMOSI = 10
        self.SPICLK = 11

        GPIO.setmode(GPIO.BCM)
        GPIO.setup(self.SPICS, GPIO.OUT)
        GPIO.setup(self.SPIMISO, GPIO.IN)
        GPIO.setup(self.SPIMOSI, GPIO.OUT)
        GPIO.setup(self.SPICLK, GPIO.OUT)

        GPIO.output(self.SPICS, GPIO.HIGH)
        GPIO.output(self.SPICLK, GPIO.LOW)

    def read_adc(self, channel, debug=False):
        if channel > 7 or channel < 0:
            return -1

        GPIO.output(self.SPICS, GPIO.LOW)

        command = 0b11000000 | (channel << 3)
        self._send_bits(command, 8)

        self._clock_tick()

        adcvalue = 0
        for _ in range(10):
            adcvalue <<= 1
            if GPIO.input(self.SPIMISO):
                adcvalue |= 0x1
            self._clock_tick()

        GPIO.output(self.SPICS, GPIO.HIGH)

        return adcvalue

    def _send_bits(self, data, num_bits):
        for _ in range(num_bits):
            GPIO.output(self.SPIMOSI, data & 0x80)
            data <<= 1
            self._clock_tick()

    def _clock_tick(self):
        GPIO.output(self.SPICLK, GPIO.HIGH)
        GPIO.output(self.SPICLK, GPIO.LOW)

    def test_max_frequency(self, duration=5, channel=0):
        print(f"Testing maximum frequency for {duration} second(s)...")
        start_time = time.time()
        count = 0
        while time.time() - start_time < duration:
            self.read_adc(channel)
            count += 1
        
        elapsed_time = time.time() - start_time
        frequency = count / elapsed_time
        return frequency

    def measure_throughput(self, duration=10, channel=0):
        print(f"Measuring throughput for {duration} seconds...")
        start_time = time.time()
        count = 0
        while time.time() - start_time < duration:
            self.read_adc(channel)
            count += 1
        
        elapsed_time = time.time() - start_time
        throughput = count / elapsed_time
        return throughput

    def cleanup(self):
        GPIO.cleanup()

if __name__ == "__main__":
    try:
        reader = MCP3008Reader()

        # Test massima frequenza
        max_freq = reader.test_max_frequency()
        print(f"Maximum frequency: {max_freq:.2f} Hz")

        # Misura throughput
        throughput = reader.measure_throughput()
        print(f"Throughput: {throughput:.2f} readings/second")

        # Letture normali
        print("\nNormal readings:")
        for _ in range(5):  # Facciamo 5 set di letture
            for channel in range(8):
                value = reader.read_adc(channel)
                voltage = (value / 1023.0) * 3.3  # Assumendo riferimento a 3.3V
                print(f"Channel {channel}: ADC = {value}, Voltage = {voltage:.3f}V")
            print("-" * 40)
            time.sleep(1)

    except KeyboardInterrupt:
        print("\nReading interrupted by user")
    finally:
        reader.cleanup()
        print("GPIO cleaned up")