# Usa un'immagine base di Python 3
FROM python:3.9-slim

# Imposta la directory di lavoro all'interno del container
WORKDIR /usr/src/app

# Copia il file requirements.txt nella directory di lavoro
COPY requirements.txt .

# Installa le dipendenze presenti nel file requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

RUN addgroup --group rtgroup --gid 2000 

RUN adduser --disabled-password --home /usr/src/app --gecos '' \    
    --uid 1000 \
    --gid 2000 \
    "rtuser" 

RUN chown -R rtuser:rtgroup  /usr/src/app /tmp

USER rtuser:rtgroup

# Copia lo script Python nella directory di lavoro
COPY script.py .

# Comando di default per eseguire lo script Python
CMD ["python", "./script.py"]