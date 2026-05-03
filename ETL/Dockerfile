FROM python:3.11

WORKDIR /app

COPY . .

RUN pip install pandas sqlalchemy psycopg2-binary pymysql

CMD ["sh", "-c", "sleep 20 && python procesoETL.py"]