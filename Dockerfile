FROM python:3.7
# env
ENV APP_DIR=/usr/src/app
ENV FLASK_APP=${APP_DIR}/autoapp.py

LABEL description="Python with flask example app"
WORKDIR ${APP_DIR}
COPY . .
RUN pip install -r requirements/prod.txt
EXPOSE 5000
CMD [ "uwsgi", "--http", "0.0.0.0:5000", "--module", "autoapp:app" ]
