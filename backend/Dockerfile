# Etapa de “builder” usando la misma imagen de Lambda Python 3.9
FROM public.ecr.aws/lambda/python:3.10 AS builder

WORKDIR /var/task

# 0) Instala zip (Amazon Linux 2 usa yum)
RUN yum install -y zip

# 1) Copia el requirements y crea el deploy
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt -t .

# 2) Copia tu código (y cualquier otro .py o carpeta necesaria)
COPY main.py .
# si tienes más módulos, por ejemplo carpetas, añádelas:
# COPY src/ ./src/

# 3) Empaqueta todo en function.zip
RUN zip -r function.zip .

# Etapa final: solo metemos el ZIP
FROM scratch
COPY --from=builder /var/task/function.zip /function.zip
