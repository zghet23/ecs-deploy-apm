#Deploy of an application "Hello World!", using ECS and Fargate#
This README documents the process step by step to deploy and application in a Amazon ECS Cluster, reproducing 
the environment of a customer with a existing cluster that desire integrate the DataDog agent in his application.

## 1. Context:
Its assume customer already have a ECS cluster and application running in a service/task.

## 2. Application:
This repository contains an application that bring a simple "Hello World!" without any DataDog configuration preloaded.
ecs-deploy-apm/
├───app-only/
│   ├───app.py
│   ├───Dockerfile
│   └───requirements.txt

## 2.1 Application running in Cluster:
Here is the code of the application running by himself without any DataDog configuration added yet.
Application running alone:
```
 import os
 import time
 from flask import Flask
 
 app = Flask(__name__)
 
 @app.route('/')
 def index():
     return 'Hello, World! This is the main endpoint.'
 
 @app.route('/work')
 def do_work():
     time.sleep(2)
     return 'Work complete after 2 seconds.'
 
 @app.route('/error')
 def trigger_error():
     try:
         1 / 0
     except Exception as e:
         return "An intentional error was triggered!", 500
 
 if __name__ == "__main__":
     app.run(host='0.0.0.0', port=8080)
```

# 2.2 Requirements:
The file requirements.txt contains just the necesary to run the application:
```
Flask
gunicorn
```

# 2.3 Docker file for the application without DataDog agent details.
**`app-only/Dockerfile` (Ejemplo):**

```dockerfile
# Usa una imagen base oficial de Python
FROM python:3.9-slim

# Establece el directorio de trabajo en el contenedor
WORKDIR /app

# Copia el archivo de dependencias
COPY requirements.txt .

# Instala los paquetes necesarios
RUN pip install --no-cache-dir -r requirements.txt

# Copia el código de la aplicación
COPY app.py .

# Expone el puerto (por defecto 8080, se puede cambiar)
EXPOSE 8080

# Ejecuta la aplicación con Gunicorn
CMD ["gunicorn", "--bind", "0.0.0.0:8080", "app:app"]
```

## 3 Deploy in ECS (Manual steps in AWS Console)

### 3.1 Create a new Task Definition
1.- Open the Amazon ECS console.
2.- Click in **Tesk Definitions**.
3.- Click on **Create new Task Definition**.
4.- **Name of the task definition**.
5.- **Compatibility of the launch**: Choose **AWS Fargate**
6.- **Execution role of th tasks**: Choose an existing role of create new one
7.- **Size of the task**: Assign CPU and Memory (ej. 0.5 vCPU, 1GB).
8.- In **Container defitions**, click on **Add Container**:
    * **Container Nanme**: 'app-only'.
    * **Image**: "Image of the application".
    * **Port mappings**: ej: 8080 or the port of your application.
    * Click on **Add** and the in **Create**


### 3.2 Create a new Service

1. Go to Cluster previously created
2. In **services** tab click in **Create**
3. **Type of launchment**: **Fargate**
4. **Definition task**: Select the definition of the task previously created
5. **Name of the service**: 'ecs-only-app' (or similar)
6. **Number of desired task**: 1 (or desired)
7. **Networks**:
   * Select the VPC and subnets.
   * Ensure that **Auto-assign public IP** is set to `ENABLED` if you want tasks to have public (ephemeral) IPs.
   * Configure the **Security group** to allow incoming traffic on your application's port (e.g., 8080 or 8081).
8. Review and click in **Create Services**.

