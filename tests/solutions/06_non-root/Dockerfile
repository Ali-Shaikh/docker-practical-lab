FROM python:3.14-slim

LABEL cloudsprocket.lab=docker

WORKDIR /app
COPY app.py .

ENV PORT=8211
ENV DATA_DIR=/data

RUN groupadd --gid 10001 app \
  && useradd --uid 10001 --gid app --shell /usr/sbin/nologin --create-home app \
  && mkdir -p /data \
  && chown -R app:app /data /app

USER 10001:10001

EXPOSE 8211
CMD ["python", "app.py"]
