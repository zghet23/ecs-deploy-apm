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
Application running alone:
'''
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
'''
