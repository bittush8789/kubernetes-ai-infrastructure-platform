FROM python:3.10-slim

WORKDIR /workspace

# Install system dependencies for psycopg2 and other packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libpq-dev \
    curl \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY ./app ./app

# Expose port for FastAPI server
EXPOSE 8000

ENV PYTHONUNBUFFERED=1
ENV MOCK_K8S=true

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
