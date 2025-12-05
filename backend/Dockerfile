# Python Image use karein
FROM python:3.9

# Work Directory set karein
WORKDIR /app

# Requirements copy karein
COPY requirements.txt .

# Libraries install karein
RUN pip install --no-cache-dir -r requirements.txt

# Permissions set karein (Hugging Face ke liye zaroori)
RUN useradd -m -u 1000 user
USER user
ENV HOME=/home/user \
	PATH=/home/user/.local/bin:$PATH

# Baki code copy karein
COPY --chown=user . .

# Server Start Command
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "7860"]