FROM python:3.14-slim

LABEL cloudsprocket.lab=docker

WORKDIR /app
COPY app.py .

ENV PORT=8211
ENV DATA_DIR=/data

RUN mkdir -p /data

EXPOSE 8211
HEALTHCHECK --interval=5s --timeout=3s --start-period=5s --retries=5 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8211/health', timeout=2)"

CMD ["python", "app.py"]
