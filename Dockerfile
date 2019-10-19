FROM python:3.7
# dev
ENV APP_DIR=/usr/src/app
ENV FLASK_APP=${APP_DIR}/autoapp.py
ENV FLASK_DEBUG=1

LABEL description="Python with flask example app"
WORKDIR ${APP_DIR}
COPY . .
RUN pip install Flask uwsgi
RUN pip install -r requirements/dev.txt
RUN flask db init && flask db migrate && flask db upgrade
EXPOSE 5000
CMD [ "uwsgi", "--http", "0.0.0.0:5000", "--module", "autoapp:app" ]
