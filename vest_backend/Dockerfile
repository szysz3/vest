FROM python:3.12-slim

WORKDIR /app

RUN apt-get update -qq && apt-get install -y -qq sqlite3 && rm -rf /var/lib/apt/lists/*

RUN python -m venv /app/venv
ENV PATH="/app/venv/bin:$PATH"

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY parsers/ ./parsers/
COPY templates/ ./templates/
COPY config.json .
COPY app.py .

EXPOSE 8000

CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8000"]
