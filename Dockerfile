FROM vastai/a1111:v1.10.1-cuda-12.1-pytorch-2.5.1

COPY on_start.sh /on_start.sh
RUN chmod +x /on_start.sh

ENTRYPOINT ["/bin/bash", "/on_start.sh"]