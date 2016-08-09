FROM erlang:slim
MAINTAINER Samuel Bernard <samuel.bernard@gmail.com>

ENV LANG=C.UTF-8

ADD nxredirect /bin/nxredirect

EXPOSE 53053
CMD ["/bin/nxredirect"]
