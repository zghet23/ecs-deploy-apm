# Use an official Python runtime as a parent image
FROM python:3.9-slim

# Set the working directory in the container
WORKDIR /app

# Copy the dependencies file to the working directory
COPY requirements.txt .

# Install any needed packages specified in requirements.txt
# Using --no-cache-dir to reduce image size
RUN pip install --no-cache-dir -r requirements.txt

# Copy the application code to the working directory
COPY app.py .

# Make port 8080 available to the world outside this container
EXPOSE 8080

# Define environment variables for Datadog APM
# The DD_AGENT_HOST will be the name of the Datadog Agent sidecar container
ENV DD_AGENT_HOST=datadog-agent
ENV DD_LOGS_INJECTION=true
ENV DD_SERVICE=ecs-demo-app
ENV DD_ENV=development
ENV DD_VERSION=1.0

# Run the application with Gunicorn, automatically instrumented by ddtrace-run
CMD ["ddtrace-run", "gunicorn", "--bind", "0.0.0.0:8080", "app:app"]