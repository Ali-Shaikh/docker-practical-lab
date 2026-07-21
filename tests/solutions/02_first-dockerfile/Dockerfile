FROM python:3.14-slim

LABEL cloudsprocket.lab=docker

WORKDIR /app
COPY app.py .

ENV PORT=8211
ENV DATA_DIR=/data

RUN mkdir -p /data

EXPOSE 8211
CMD ["python", "app.py"]
