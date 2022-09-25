#!/bin/bash
# 
# Configure and run Docker:
#
#     https://docs.docker.com/engine/admin/
#
# Docker daemon to override the default service structure
# Docker.service.d file under /etc/systemd/system/
# Creating the override.conf drop-in file.
# One of the certificates created by running this file
# set the server keys on the service side by turning on TLS security
# we need to specify.
#
#     $ pwd
#     /etc/systemd/system/docker.service.d
#     $ vim override.conf
#     [Service]
#     ExecStart=
#     ExecStart=/usr/bin/dockerd -D -H unix:///var/run/docker.sock --tlsverify  --tlscert=~/.docker/server-cert.pem --tlscacert=~/.docker/ca.pem --tlskey=~/.docker/server-key.pem -H tcp://0.0.0.0:2376
#
#
# There are 2 ways to gain secure access to Docker daemon with TLS enabled
# 
# 1. Using the necessary options on the Docker client:
#
#     $ docker                       \
#         --tlsverify                \
#         --tlscacert=ca.pem         \
#         --tlscert=cert.pem         \
#         --tlskey=key.pem           \
#         -H localhost:2376 info
#
# 2. Using DOCKER environment variables:
#
# export DOCKER_TLS_VERIFY="1"
# export DOCKER_HOST="tcp://0.0.0.0:2376"
# export DOCKER_CERT_PATH="/home/fardiansyah/.docker"

set -eu

#set -x ; debugging

cd ~
echo "you are now in $PWD"

if [ ! -d ".docker/" ] 
then
    echo "Directory ./docker/ does not exist"
    echo "Creating the directory"
    mkdir .docker
fi

cd .docker/
echo "type in your certificate password (characters are not echoed)"
read -p '>' -s PASSWORD

echo "Type in the server name you’ll use to connect to the Docker server"
read -p '>' SERVER

# 256bit AES (Advanced Encryption Standard) is the encryption cipher which is used for generating certificate authority (CA) with 2048-bit security.
openssl genrsa -aes256 -passout pass:$PASSWORD -out ca-key.pem 2048 

# Sign the the previously created CA key with your password and address for a period of one year.
# i.e. generating a self-signed certificate for CA
# X.509 is a standard that defines the format of public key certificates, with fixed size 256-bit (32-byte) hash
openssl req -new -x509 -days 365 -key ca-key.pem -passin pass:$PASSWORD -sha256 -out ca.pem -subj "/C=TR/ST=./L=./O=./CN=$SERVER"

# Generating a server key with 2048-bit security
openssl genrsa -out server-key.pem 2048

# Generating a certificate signing request (CSR) for the the server key with the name of your host.
openssl req -new -key server-key.pem -subj "/CN=$SERVER"  -out server.csr

# Sign the key with your password for a period of one year
# i.e. generating a self-signed certificate for the key
openssl x509 -req -days 365 -in server.csr -CA ca.pem -CAkey ca-key.pem -passin "pass:$PASSWORD" -CAcreateserial -out server-cert.pem

# For client authentication, create a client key and certificate signing request
# Generate a client key with 2048-bit security
openssl genrsa -out key.pem 2048
# Process the key as a client key.
openssl req -subj '/CN=client' -new -key key.pem -out client.csr

# To make the key suitable for client authentication, create an extensions config file:
sh -c 'echo "extendedKeyUsage = clientAuth" > extfile.cnf'

# Sign the (public) key with your password for a period of one year
openssl x509 -req -days 365 -in client.csr -CA ca.pem -CAkey ca-key.pem -passin "pass:$PASSWORD" -CAcreateserial -out cert.pem -extfile extfile.cnf

echo "Removing unnecessary files i.e. client.csr extfile.cnf server.csr"
rm ca.srl client.csr extfile.cnf server.csr

echo "Changing the permissions to readonly by root for the server files."
# To make them only readable by you: 
chmod 0400 ca-key.pem key.pem server-key.pem

echo "Changing the permissions of the client files to read-only by everyone"
# Certificates can be world-readable, but you might want to remove write access to prevent accidental damage
# these are all x509 certificates aka public key certificates
# X.509 certificates are used in many Internet protocols, including TLS/SSL, which is the basis for HTTPS.
chmod 0444 ca.pem server-cert.pem cert.pem
