FROM centos
RUN yum update -y
RUN yum install -y zsh wget epel-release
RUN yum install -y ansible openssh-clients perl perl-Net-OpenSSH perl-IO-Pty-Easy
RUN curl https://bootstrap.pypa.io/get-pip.py | python&& \
    pip install aliyuncli && pip install aliyun-python-sdk-ecs && pip install aliyun-python-sdk-rds && pip install aliyun-python-sdk-slb && pip install aliyun-python-sdk-oss
RUN echo -e "source aliyun_zsh_complete.sh\ncomplete -C \`which aliyun_completer\` aliyuncli" > /root/.zshrc
RUN wget https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux64 -O /usr/local/bin/jq && chmod +x /usr/local/bin/jq
RUN mkdir /root/.ssh && chmod 700 /root/.ssh && echo -e 'Host *\n\tUser ansible\n\tStrictHostKeyChecking no' > /root/.ssh/config
COPY ssh-key* /root/
ARG KEY_ID
ARG KEY_SECRET
ENV KEY_ID=$KEY_ID
ENV KEY_SECRET=$KEY_SECRET
RUN echo -e "$KEY_ID\n$KEY_SECRET\ncn-hongkong\njson\n" | aliyuncli configure > /dev/null
