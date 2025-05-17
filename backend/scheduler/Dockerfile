# Usa la imagen base de AWS Lambda Python 3.10
FROM public.ecr.aws/lambda/python:3.10 AS builder

# Necesitamos zip
RUN yum install -y zip

WORKDIR /var/task

# 1) Instala las dependencias dentro de /var/task
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt -t .

# 2) Copia tu código
COPY scheduler.py .

# 3) Empaqueta TODO en un solo function.zip
#    No hace falta que exista 'deploy/' en el host; lo creamos aquí
RUN mkdir -p deploy \
 && zip -r deploy/scheduler.zip . \
    -x "**/.venv/**" "**/__pycache__/**" "**/deploy/**"

# Etapa final: extraemos sólo el ZIP (imagen vacía)
FROM scratch
COPY --from=builder /var/task/deploy/scheduler.zip /scheduler.zip
