#!/bin/bash
set -e

echo "Ожидание файла с swarm-токеном"
while [ ! -f /vagrant/swarm_token.txt ]; do
    sleep 1;
done
docker swarm join --token $(cat /vagrant/swarm_token.txt) 192.168.56.10