FROM 2byrds/keri:1.1.7

WORKDIR /usr/local/var

RUN mkdir sigpy-vlei
COPY . /usr/local/var/sigpy-vlei
RUN ls -la /usr/local/var/sigpy-vlei
WORKDIR /usr/local/var/sigpy-vlei/

# RUN apk add linux-headers
RUN pip install -r requirements.txt

# WORKDIR /usr/local/var/sigpy-vlei/scripts
# RUN source env.sh
# RUN ./issue-ecr.sh