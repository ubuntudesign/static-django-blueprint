FROM python:3

# Pip requirements files
ADD requirements /requirements

# Install pip requirements
RUN pip install -r /requirements/dev.txt

ADD . /app
WORKDIR /app

CMD ["python", "manage.py", "runserver", "0.0.0.0:5000"]
