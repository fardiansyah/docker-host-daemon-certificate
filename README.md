# Secure Docker API over TCP with TLS Certificate

On this doc, you will set up TLS when exposing the Docker API over TCP so Docker Engine and your clients can verify each others' identity.

# Creating Your Certificate Authority

Begin by creating a Certificate Authority (CA) for your TLS configuration. You’ll use this CA to sign your certificates; the server will refuse to communicate with clients that present a certificate from a different CA.

Use OpenSSL to generate private and public CA keys on the machine hosting your Docker server:


**Generate the private key**
```
openssl genrsa -aes256 -out ca-private.pem 4096
```

**Generate a public key from the private key**
```
openssl req -new -x509 -days 365 -key ca-private.pem -sha256 -out ca-public.pem 
```

# Generating a Server Key and Certificate Signing Request

Next create a server key and a certificate signing request:

**Generate the server key**
```
openssl genrsa -out server-key.pem 4096
```

**Generate a certificate signing request**
```
openssl req -subj "/CN=example.com" -sha256 -new -key server-key.pm -out request.csr
```

# Setting Up Certificate Extensions

Using this CSR would permit connections to the server via its FQDN. You need to specify certificate extensions if you want to add another domain or use an IP address. Create an extensions file with subjectAltName and extendedKeyUsage fields to set this up:

```
echo subjectAltName = DNS:sub.example.com,IP:10.10.10.20,IP:127.0.0.1 >> extfile.cnf
echo extendedKeyUsage = serverAuth >> extfile.cnf
```

# Generating a Signed Certificate

Now you’re ready to combine all the components and generate a signed certificate:
```
openssl x509 -req -days 365 -sha256 \
    -in request.csr \
    -CA ca-public.pem \
    -CAkey ca-private.pem \
    -CAcreateserial \
    -extfile extfile.cnf \
    -out certificate.pem
```

This certificate is set to expire after a year. You can adjust the -days flag to obtain a useful lifetime for your requirements. You should arrange to generate a replacement certificate before this one expires.

# Generating a Client Certificate

Next you should generate another certificate for your Docker clients to use. This must be signed by the same CA as the server certificate. Use an extensions file with extendedKeyUsage = clientAuth to prepare this certificate for use in a client scenario.

**Generate a client key**
```
openssl genrsa -out client-key.pem 4096
```

**Create a certificate signing request**
```
openssl req -subj '/CN=client' -new -key client-key.pem -out client-request.csr
```
**Complete the signing**
```
echo extendedKeyUsage = clientAuth >> extfile-client.cnf
```
```
openssl x509 -req -days 365 -sha256 \
     -in client-request.csr \ 
     -CA ca-public.pem \
     -CAkey ca-private.pem \
     -CAcreateserial \
     -extfile extfile-client.cnf \
     -out client-certificate.pem
```

# Preparing to Configure Docker

Copy your ca-public.pem, certificate.pem, and server-key.pem files into a new directory ready to reference in your Docker config. Afterwards, copy the ca-public.pem, client-certificate.pem, and client-key.pem files to the machine which you’ll connect from.

# Configuring the Docker Daemon

Now you can start the Docker daemon with TLS flags referencing your generated certificate and keys. The --tlscacert, --tlscert, and --tlskey parameters specify paths to the respective OpenSSL resources generated above.

To overwrite docker service daemon, create a new file /etc/systemd/system/docker.service.d/docker.conf with the following contents, to remove the -H argument that is used when starting the daemon by default.

```
[Service]
ExecStart=
ExecStart=/usr/bin/dockerd -H unix:///var/run/docker.sock -H tcp://0.0.0.0:2376 --tlsverify --tlscacert=ca-public.pem --tlscert=certificate.pem --tlskey=server-key.pem
```

# Configuring the Docker Client

```
docker context create \
  --docker "host=tcp://<vm-ip>:2376,ca=ca-public,cert=client-certificate.pem,key=client-key.pem" \
  <context-name>
```

# Testing Configuration

if you have multiple docker context on your client, make sure to select context you created above
```
docker context use <context-name>
```

check connected docker host:
```
docker info
```