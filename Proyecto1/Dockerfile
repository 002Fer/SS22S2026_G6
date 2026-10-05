FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY src ./src
COPY sql ./sql
COPY data/csv ./data/csv
COPY data/quality ./data/quality

ENTRYPOINT ["python", "-m", "src.main"]
CMD ["run-all"]

