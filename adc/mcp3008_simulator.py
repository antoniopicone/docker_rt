import RPi.GPIO as GPIO
import time
import threading
import random

class MCP3008Simulator:
    def __init__(self):
        self.SPICS = 8
        self.SPIMISO = 9
        self.SPIMOSI = 10
        self.SPICLK = 11

        self.channel_values = [0] * 8
        self.running = False

        GPIO.setmode(GPIO.BCM)
        GPIO.setup(self.SPICS, GPIO.IN, pull_up_down=GPIO.PUD_UP)
        GPIO.setup(self.SPIMISO, GPIO.OUT)
        GPIO.setup(self.SPIMOSI, GPIO.IN)
        GPIO.setup(self.SPICLK, GPIO.IN)

        print(f"Configurazione iniziale CS nel simulatore: {GPIO.input(self.SPICS)}")

    def start(self):
        self.running = True
        self.update_thread = threading.Thread(target=self._update_values)
        self.spi_thread = threading.Thread(target=self._handle_spi)
        self.update_thread.start()
        self.spi_thread.start()
        print("Simulatore MCP3008 avviato")

    def stop(self):
        self.running = False
        self.update_thread.join()
        self.spi_thread.join()
        GPIO.cleanup()
        print("Simulatore MCP3008 fermato")

    def _update_values(self):
        while self.running:
            for i in range(8):
                self.channel_values[i] = random.randint(0, 1023)
            time.sleep(0.01)  # Aggiorna i valori ogni 100ms

    def _handle_spi(self):
        cs_low_count = 0
        while self.running:
            cs_state = GPIO.input(self.SPICS)
            print(f"Stato CS: {'LOW' if cs_state == GPIO.LOW else 'HIGH'}")
            if cs_state == GPIO.LOW:
                cs_low_count += 1
                print(f"CS basso rilevato (conteggio: {cs_low_count})")
                try:
                    self._process_spi_request()
                except Exception as e:
                    print(f"Errore durante l'elaborazione della richiesta SPI: {e}")
            time.sleep(0.001)  # Controlla ogni 1ms

    def _process_spi_request(self):
        command = 0
        for _ in range(8):
            if GPIO.input(self.SPICLK) == GPIO.HIGH:
                command = (command << 1) | GPIO.input(self.SPIMOSI)
                while GPIO.input(self.SPICLK) == GPIO.HIGH:
                    pass
            while GPIO.input(self.SPICLK) == GPIO.LOW:
                pass

        channel = (command >> 4) & 0x07
        value = self.channel_values[channel]
        print(f"Lettura richiesta per il canale {channel}, valore: {value}")

        # Invia il valore bit per bit
        for i in range(12):
            bit = (value >> (11 - i)) & 1
            GPIO.output(self.SPIMISO, bit)
            print(f"Bit inviato: {bit}")
            while GPIO.input(self.SPICLK) == GPIO.LOW:
                pass
            while GPIO.input(self.SPICLK) == GPIO.HIGH:
                pass

        print(f"Valore {value} inviato per il canale {channel}")

    def print_status(self):
        print("Stato attuale dei canali:")
        for i, value in enumerate(self.channel_values):
            print(f"Canale {i}: {value}")

if __name__ == "__main__":
    try:
        simulator = MCP3008Simulator()
        simulator.start()
        print("Simulatore MCP3008 in esecuzione. Premi CTRL+C per terminare.")
        while True:
            simulator.print_status()
            time.sleep(5)
    except KeyboardInterrupt:
        print("\nTerminazione del simulatore...")
    finally:
        simulator.stop()
        print("Simulatore terminato.")