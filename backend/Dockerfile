# Python Image use karein
FROM python:3.9

# Work Directory set karein
WORKDIR /code

# Requirements copy karein
COPY ./requirements.txt /code/requirements.txt

# 👇 OCR aur PDF tools install kiye (Zaroori hai)
RUN apt-get update && apt-get install -y \
    tesseract-ocr \
    poppler-utils \
    && rm -rf /var/lib/apt/lists/*

# Libraries install karein
RUN pip install --no-cache-dir --upgrade -r /code/requirements.txt

# User permissions setup (Hugging Face ke liye zaroori)
RUN useradd -m -u 1000 user
USER user
ENV HOME=/home/user \
    PATH=/home/user/.local/bin:$PATH

# Baki code copy karein
COPY --chown=user . /code

# Server Start Command (Updated for main.py)
# 👇 Yahan change kiya hai: 'app:app' ki jagah 'main:app'
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "7860"]