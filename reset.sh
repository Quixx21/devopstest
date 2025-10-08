#!/bin/bash
set -e

echo

if kind get clusters | grep -q "devops-test"; then
  echo "Deleting Kind cluster"
  kind delete cluster --name devops-test
else
  echo "no cluster found"
fi

echo "cleaning docker"
docker image rm -f quixx21/devops-test:latest 2>/dev/null || true
docker system prune -f

echo "Removing old containers"
docker container prune -f

echo " Cleaning Docker networks..."
docker network prune -f

echo "Stopping all running containers..."
docker stop $(docker ps -q) 2>/dev/null || true
docker rm $(docker ps -aq) 2>/dev/null || true
