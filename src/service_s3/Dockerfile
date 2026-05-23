FROM python:latest

WORKDIR /app

COPY . /app

RUN pip install -r requirements.txt

EXPOSE 5001

#Start flask app
ENTRYPOINT ["python"]
CMD ["app.py"]


