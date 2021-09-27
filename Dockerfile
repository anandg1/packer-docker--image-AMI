FROM alpine:3.8
RUN mkdir /var/flask/
WORKDIR /var/flask/
COPY . .
RUN apk update && apk add python3
RUN  pip3 install  -r requirements.txt
EXPOSE  5000
CMD [ "python3" , "app.py" ]
