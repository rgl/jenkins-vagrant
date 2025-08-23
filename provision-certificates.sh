#!/bin/bash
set -euxo pipefail

domain="$(hostname --fqdn)"

ca_file_name='jenkins-ca'
ca_common_name='Jenkins CA'

# copy from host.
if [ -d "/vagrant/tmp/$ca_file_name" ]; then
    rsync \
        --archive \
        --no-owner \
        --no-group \
        --delete \
        "/vagrant/tmp/$ca_file_name/" \
        /etc/ssl/private
fi

# go into the CA data directory.
cd /etc/ssl/private

# create the CA.
if [ ! -f "$ca_file_name-crt.pem" ]; then
    openssl genrsa \
        -out "$ca_file_name-key.pem" \
        2048 \
        2>/dev/null
    chmod 400 "$ca_file_name-key.pem"
    openssl req -new \
        -sha256 \
        -subj "/CN=$ca_common_name" \
        -key "$ca_file_name-key.pem" \
        -out "$ca_file_name-csr.pem"
    openssl x509 -req -sha256 \
        -signkey "$ca_file_name-key.pem" \
        -extensions a \
        -extfile <(echo "[a]
            basicConstraints=critical,CA:TRUE,pathlen:0
            keyUsage=critical,digitalSignature,keyCertSign,cRLSign
            ") \
        -days 365 \
        -in  "$ca_file_name-csr.pem" \
        -out "$ca_file_name-crt.pem"
    openssl x509 \
        -in "$ca_file_name-crt.pem" \
        -outform der \
        -out "$ca_file_name-crt.der"
    # dump the certificate contents (for logging purposes).
    #openssl x509 -noout -text -in "$ca_file_name-crt.pem"
fi

# trust the CA.
if [ ! -f "/usr/local/share/ca-certificates/$ca_file_name.crt" ]; then
    install "$ca_file_name-crt.pem" "/usr/local/share/ca-certificates/$ca_file_name.crt"
    update-ca-certificates -v
fi

# create the server certificates.
function create-server-certificate {
    local domain="$1"
    if [ -f "$domain-crt.pem" ]; then
        return
    fi
    openssl genrsa \
        -out "$domain-key.pem" \
        2048 \
        2>/dev/null
    chmod 400 "$domain-key.pem"
    openssl req -new \
        -sha256 \
        -subj "/CN=$domain" \
        -key "$domain-key.pem" \
        -out "$domain-csr.pem"
    openssl x509 -req -sha256 \
        -CA "$ca_file_name-crt.pem" \
        -CAkey "$ca_file_name-key.pem" \
        -CAcreateserial \
        -extensions a \
        -extfile <(echo "[a]
            subjectAltName=DNS:$domain
            extendedKeyUsage=critical,serverAuth
            ") \
        -days 365 \
        -in  "$domain-csr.pem" \
        -out "$domain-crt.pem"
    openssl pkcs12 -export \
        -keyex \
        -inkey "$domain-key.pem" \
        -in "$domain-crt.pem" \
        -certfile "$domain-crt.pem" \
        -passout pass: \
        -out "$domain-key.p12"
    # dump the certificate contents (for logging purposes).
    #openssl x509 -noout -text -in "$domain-crt.pem"
    #openssl pkcs12 -info -nodes -passin pass: -in "$domain-key.p12"
}
create-server-certificate "$domain"
create-server-certificate "ubuntu.$domain"
create-server-certificate "windows.$domain"
create-server-certificate "macos.$domain"

# create the client certificates.
function create-client-certificate {
    local name="$1"
    if [ -f "$name-crt.pem" ]; then
        return
    fi
    openssl genrsa \
        -out "$name-key.pem" \
        2048 \
        2>/dev/null
    chmod 400 "$name-key.pem"
    openssl req -new \
        -sha256 \
        -subj "/CN=$name" \
        -key "$name-key.pem" \
        -out "$name-csr.pem"
    openssl x509 -req -sha256 \
        -CA "$ca_file_name-crt.pem" \
        -CAkey "$ca_file_name-key.pem" \
        -CAcreateserial \
        -extensions a \
        -extfile <(echo "[a]
            extendedKeyUsage=critical,clientAuth
            ") \
        -days 365 \
        -in  "$name-csr.pem" \
        -out "$name-crt.pem"
    openssl pkcs12 -export \
        -keyex \
        -inkey "$name-key.pem" \
        -in "$name-crt.pem" \
        -certfile "$name-crt.pem" \
        -passout pass: \
        -out "$name-key.p12"
    # dump the certificate contents (for logging purposes).
    #openssl x509 -noout -text -in "$name-crt.pem"
    #openssl pkcs12 -info -nodes -passin pass: -in "$name-key.p12"
}
create-client-certificate jenkins

# copy to host.
mkdir -p "/vagrant/tmp/$ca_file_name"
rsync \
    --archive \
    --no-owner \
    --no-group \
    --delete \
    /etc/ssl/private/ \
    "/vagrant/tmp/$ca_file_name"
