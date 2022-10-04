FROM ubuntu:focal
RUN apt update && apt install openssh-server sudo -y
RUN apt install iputils-ping sudo -y
# Start SSH service
RUN service ssh start
# Expose docker port 22
EXPOSE 22 18069 8069 1234
CMD ["/usr/sbin/sshd","-D"]