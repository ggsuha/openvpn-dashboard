#!/bin/bash

# Remove "> /dev/null 2>&1" if you need to check the output

read_env() {
  local filePath=".env"

  if [ ! -f "$filePath" ]; then
    echo "missing ${filePath}"
    exit 1
  fi

  # Read the file line by line
  while read -r LINE; do
    # Remove leading and trailing whitespaces, and carriage return
    CLEANED_LINE=$(echo "$LINE" | awk '{$1=$1};1' | tr -d '\r' | tr -d '"')

    if [[ $CLEANED_LINE != '#'* ]] && [[ $CLEANED_LINE == *'='* ]]; then
      export "$CLEANED_LINE"
    fi
  done < "$filePath"
}

read_env

# Navigate to the EasyRSA directory
cd ~/easy-rsa || exit

# Check if the client key already exists
client_key_path="pki/private/${1}.key"

if [ -f "$client_key_path" ]; then
    echo "Error: Key for ${1} already exists."
    exit 1
fi

echo -e "Generating client key and request... "
echo -en "\n" | ./easyrsa gen-req "${1}" nopass > /dev/null 2>&1

# Copy the client key to the client-configs/keys directory
echo -e "Copying client key to client-configs/keys directory... "
cp "$client_key_path" ~/client-configs/keys/

# Transfer the client request to CA server
echo -e "Transferring client request to CA server... "
scp -T "pki/reqs/${1}.req" "${CA_USERNAME}"@"${CA_IP}":/tmp > /dev/null 2>&1

# Generate certificate
echo -e "Generating client certificate on CA server... "
ssh -T "${CA_USERNAME}"@"${CA_IP}" "cd /home/"${CA_USERNAME}"/easy-rsa && ./easyrsa import-req /tmp/${1}.req ${1}"  > /dev/null 2>&1
ssh -T "${CA_USERNAME}"@"${CA_IP}" "cd /home/"${CA_USERNAME}"/easy-rsa && echo -en 'yes\n' |  ./easyrsa sign-req client ${1}"  > /dev/null 2>&1
scp -T "${CA_USERNAME}"@"${CA_IP}":/home/"${CA_USERNAME}"/easy-rsa/pki/issued/"${1}".crt /tmp  > /dev/null 2>&1

# Copy client certificate to keys directory
echo -e "Copying client certificate to client-configs/keys directory... "
cp "/tmp/${1}.crt" ~/client-configs/keys/

# Generate ovpn file
echo -e "Generating OpenVPN configuration file... "
cd ~/client-configs || exit
./make_config.sh "${1}"

# Copy ovpn to web server
cp ~/client-configs/files/"${1}.ovpn" ~/dashboard/public/

# Show url for download the ovpn file
echo -e Download ovpn file at "${HOST}/${1}.ovpn"
