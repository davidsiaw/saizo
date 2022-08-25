FROM julia

RUN mkdir -p /install
ADD install.jl /install/install.jl
ADD test.jl /install/test.jl

RUN julia /install/install.jl

RUN echo "Running julia test script" && julia install/test.jl

RUN apt-get update -q && \
    apt-get install -qy procps curl ca-certificates gnupg2 build-essential --no-install-recommends && apt-get clean

SHELL [ "/bin/bash", "-l", "-c" ]

RUN gpg2 --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB
RUN curl -sSL https://get.rvm.io | bash -s stable
RUN rvm get head && rvm reload
RUN source /etc/profile.d/rvm.sh && rvm install 3.1

RUN ruby -v
RUN ln -s `which ruby` /bin/ruby

RUN mkdir -p /app

WORKDIR /app
ADD stretcher.rb /app/stretcher.rb
ADD entrypoint.rb /app/entrypoint.rb
ADD entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT [ "/entrypoint.sh" ]
CMD [ ]
