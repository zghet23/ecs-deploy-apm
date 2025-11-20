import os
import time
from flask import Flask
from ddtrace import tracer

app = Flask(__name__)

@app.route('/')
def index():
    return 'Hello, World! This is the main endpoint.'

@app.route('/work')
def do_work():
    with tracer.trace(name="work.span", service="ecs-demo-app") as span:
        span.set_tag('work.level', 'heavy')
        time.sleep(2)
        return 'Work complete after 2 seconds.'

@app.route('/error')
def trigger_error():
    try:
        1 / 0
    except Exception as e:
        # The ddtrace-run auto-instrumentation will capture this exception automatically.
        # You can add custom tags if needed.
        return "An intentional error was triggered!", 500

if __name__ == "__main__":
    app.run(host='0.0.0.0', port=8080)
