## Deploying a "Hello World!" Application using ECS and Fargate ##
This README documents the process step by step to deploy and application in a Amazon ECS Cluster, reproducing 
the environment of a customer with an existing cluster that desires to integrate. the DataDog agent in his application.

## 1. Context:
It is assumed the customer already has a ECS cluster and application running in a service/task.

## 2. Application:
This repository contains an application that is a simple "Hello World!" without any DataDog configuration preloaded.
This app.py file defines a simple Flask web application. It exposes three basic endpoints:

   * `/`: Returns a "Hello, World!" message.
   * `/work`: Simulates a task that takes 2 seconds to complete.
   * `/error`: Intentionally triggers a division-by-zero error for demonstration purposes.

  The application runs on 0.0.0.0:8080.
  
ecs-deploy-apm/<br>
├───app-only/<br>
│   ├───app.py<br>
│   ├───Dockerfile<br>
│   └───requirements.txt<br>

### 2.1 Application running in Cluster:
Here is the code of the application running by itself without any DataDog configuration added yet.
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

### 2.2 Requirements:
The file requirements.txt contains just what is necessary to run the application:
```
Flask
gunicorn
```

### 2.3 Docker file for the application without DataDog agent details.
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
6.- **Task execution roles**: Choose an existing role of create new one
7.- **Size of the task**: Assign CPU and Memory (ej. 0.5 vCPU, 1GB).
8.- In **Container definitions**, click on **Add Container**:
    * **Container Name**: 'app-only'.
    * **Image**: "Image of the application".
    * **Port mappings**: ej: 8080 or the port of your application.
    * Click on **Add** and the in **Create**


### 3.2 Create a new Service

1. Go to Cluster previously created
2. In **services** tab click in **Create**
3. **Launch Type**: **Fargate**
4. **Definition task**: Select the definition of the task previously created
5. **Name of the service**: 'ecs-only-app' (or similar)
6. **Number of desired task**: 1 (or desired)
7. **Networks**:
   * Select the VPC and subnets.
   * Ensure that **Auto-assign public IP** is set to `ENABLED` if you want tasks to have public (ephemeral) IPs.
   * Configure the **Security group** to allow incoming traffic on your application's port (e.g., 8080 or 8081).
8. Review and click in **Create Services**.

###IIntegrating Datadog with a Python App on AWS Fargate/ECS###

This section outlines how to integrate Datadog with a Python Flask application deployed to AWS ECS Fargate using
  Terraform. The setup uses a sidecar pattern, where the Datadog Agent runs in a separate container alongside the
  application container within the same ECS task.

# DataDog in you application #

### Manual Guide: Datadog Integration with a Python Application on AWS Fargate/ECS

  This document details the manual steps to integrate Datadog with a Python application deployed on AWS ECS Fargate.
  The configuration uses a sidecar pattern, where the Datadog Agent runs in a separate container alongside the
  application container within the same ECS task.

  ### Architecture Overview

   - Application Container: Runs the Python application. It is instrumented with ddtrace to send data to the Datadog
     Agent.
   - Datadog Agent Container: Runs as a sidecar. It receives data from the app container on localhost and forwards it
     to Datadog's public API.
   - ECS Task Definition: Defines both the application and Datadog Agent containers so they can communicate over the
     local task network.
   - IAM Roles: Provide the necessary permissions for ECS to retrieve secrets (like the Datadog API key).

  ### Prerequisites

   1. An active AWS account and familiarity with the AWS Management Console.
   2. A Datadog account and your Datadog API key.
   3. Docker installed on your local machine.
   4. AWS CLI installed and configured.

  ---

  ### Step 1: Instrument the Python Application

  First, prepare your application to send traces.

  1.1. Add ddtrace Dependency

  Ensure the ddtrace library is in your requirements.txt file.

  `requirements.txt:
   1 Flask 
   2 gunicorn
   3 ddtrace`

 #### 1.2. Update the Dockerfile

  Modify your Dockerfile to use ddtrace-run, which automatically instruments the application. Set DD_AGENT_HOST to
  127.0.0.1 so the application sends traces to the sidecar agent over the shared task network.
```
`Dockerfile`:
# Use an official Python runtime as a parent image
FROM python:3.9-slim

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app.py .

EXPOSE 8080

# Set DD_AGENT_HOST to localhost for the sidecar agent
ENV DD_AGENT_HOST=127.0.0.1
ENV DD_LOGS_INJECTION=true
ENV DD_SERVICE=ecs-demo-app
ENV DD_ENV=development

# Run the application, instrumented by ddtrace-run
CMD ["ddtrace-run", "gunicorn", "--bind", "0.0.0.0:8080", "app:app"]
```
  ---

  ### Step 2: Build and Push Docker Image to ECR

   1. Create an ECR Repository:
      Open your terminal and run the following command, replacing <YOUR_AWS_REGION> with your AWS region:
   1     aws ecr create-repository --repository-name ecs-demo-app --region <YOUR_AWS_REGION>

   2. Log in to ECR:
      Run this command to authenticate your Docker client with ECR. Replace <YOUR_AWS_REGION> and
  <YOUR_AWS_ACCOUNT_ID> with your details:

   1     aws ecr get-login-password --region <YOUR_AWS_REGION> | docker login --username AWS --password-stdin
     <YOUR_AWS_ACCOUNT_ID>.dkr.ecr.<YOUR_AWS_REGION>.amazonaws.com

   3. Build, Tag, and Push the Image:
      From your application directory (where the Dockerfile is located):
```
    # Build the image
    docker build -t ecs-demo-app .
    # Tag the image for ECR
    docker tag ecs-demo-app:latest <YOUR_AWS_ACCOUNT_ID>.dkr.ecr.<YOUR_AWS_REGION>.amazonaws.com/ecs-demo-app:latest
    # Push the image to ECR
    docker push <YOUR_AWS_ACCOUNT_ID>.dkr.ecr.<YOUR_AWS_REGION>.amazonaws.com/ecs-demo-app:latest
    Note: Save the full image URI (e.g., 123456789012.dkr.ecr.us-east-1.amazonaws.com/ecs-demo-app:latest) for a later step.
```
  ---

  ### Step 3: Store Datadog API Key in Secrets Manager

   1. Navigate to AWS Secrets Manager in the AWS Console.
   2. Click Store a new secret.
   3. Select Other type of secret.
   4. In the Key/value pairs section, enter DD_API_KEY as the key and paste your Datadog API key as the value.
   5. Click Next.
   6. Give the secret a name (e.g., ecs-demo/datadog-api-key) and a description.
   7. Click Next and then Store.
   8. After creation, click on the secret and copy its ARN. You will need it later.

  ---

  ### Step 4: Create an ECS Task Definition

  This defines the app and agent containers that will run together.

   1. Navigate to Amazon ECS in the AWS Console.
   2. Go to Task Definitions and click Create new task definition.
   3. Task Definition Configuration:
       - Task definition family: ecs-demo-app-task
       - Launch type: AWS Fargate
       - Operating system/Architecture: Linux/X86_64
       - Task size: CPU: .5 vCPU, Memory: 1 GB (or as needed).
       - Task execution role: Select the existing ecsTaskExecutionRole. We will add a policy to this role in the next
         step.

   #### 4. Container Configuration:
       - This is where you define the two containers.

      <details>
      <summary><b>Container 1: datadog-agent (Add this first)</b></summary>

       - Name: datadog-agent
       - Image: public.ecr.aws/datadog/agent:latest
       - Essential container: Yes
       - Port mappings: 8126 with protocol UDP.
       - Environment variables:
           - DD_SITE: datadoghq.com (or your Datadog site, e.g., eu.datadoghq.com)
           - DD_ECS_FARGATE: true
       - Secrets:
           - Click Add secret.
           - Name: DD_API_KEY
           - ValueFrom: Paste the ARN of the secret you created in Step 3.
       - Health check:
           - Command: agent,health
      </details>

      <details>
      <summary><b>Container 2: app</b></summary>

       - Name: app
       - Image: Paste the ECR image URI from Step 2.
       - Essential container: Yes
       - Port mappings: 8080 with protocol TCP.
       - Environment variables:
           - DD_AGENT_HOST: 127.0.0.1
           - DD_LOGS_INJECTION: true
           - DD_SERVICE: ecs-demo-app
           - DD_ENV: development
       - Startup dependency:
           - Under Container dependencies, choose the datadog-agent container and set the condition to HEALTHY. This
             ensures the agent starts before your app.
      </details>

   ### 5. Click Create to finish creating the task definition.

  ---

  #### Step 5: Add Permissions to the Task Execution Role

   1. Navigate to IAM in the AWS Console.
   2. Go to Policies and click Create policy.
   3. Select the JSON tab and paste the following policy. Replace the resource ARN with the ARN of your secret.
```
  {
       "Version": "2012-10-17",
       "Statement": [
           {
               "Effect": "Allow",
               "Action": "secretsmanager:GetSecretValue",
               "Resource": "<PASTE_YOUR_SECRET_ARN_HERE>"
           }
       ]
  }
```
   4. Click Next, give the policy a name (e.g., ECSTaskExecutionSecretsManagerRead), and click Create policy.
   5. Go to Roles, find your ecsTaskExecutionRole, click on it, and under the Permissions tab, click Add permissions ->
      Attach policies.
   6. Search for the policy you just created (ECSTaskExecutionSecretsManagerRead) and attach it.

  ---

  ### Step 6: Create and Run the ECS Service

   1. Navigate back to ECS -> Task Definitions.
   2. Select the task definition you created and from the Actions menu, choose Deploy -> Create Service.
   3. Configuration:
       - Cluster: Choose an existing cluster or create a new one.
       - Service name: ecs-demo-app-service
       - Desired tasks: 1
   4. Networking:
       - Select your VPC and at least one subnet.
       - For Security group, create a new one or use an existing one that allows inbound TCP traffic on port 8080 from
         0.0.0.0/0 (or a more restrictive source).
       - Ensure Public IP is turned ON if you want to access the service from the internet.
   5. Click Create to launch the service.

  ---

  ### Step 7: Verify in Datadog

  Once the service is running, generate some traffic to the public IP of your task. Within a few minutes, you should
  see traces, logs, and metrics appearing in your Datadog account under the ecs-demo-app service.
