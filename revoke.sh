#!/bin/bash

# Check sudo access
if ! echo "${2}" | sudo -S pwd > /dev/null 2>&1; then
    echo "Error: Incorrect password or insufficient sudo permissions."
    exit 1
fi

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

# Check if the client key exists or not
client_key_path="pki/private/${1}.key"

if ! [ -f "$client_key_path" ]; then
    echo "Error: Key for ${1} doesn't exist."
    exit 1
fi

# Generate certificate
echo -e "Revoking client certificate on CA server... "
ssh -T "${CA_USERNAME}"@"${CA_IP}" "cd /home/"${CA_USERNAME}"/easy-rsa && echo -en 'yes\n' | ./easyrsa revoke ${1}" > /dev/null 2>&1

echo -e "Generating new CRL on CA server... "
ssh -T "${CA_USERNAME}"@"${CA_IP}" "cd /home/"${CA_USERNAME}"/easy-rsa && ./easyrsa gen-crl" > /dev/null 2>&1

echo -e "Removing revoked client certificate on CA server... "
ssh -T "${CA_USERNAME}"@"${CA_IP}" "cd /home/"${CA_USERNAME}"/easy-rsa && rm pki/issued/${1}.crt" > /dev/null 2>&1

echo -e "Copying new CRL to local machine... "
scp -T "${CA_USERNAME}"@"${CA_IP}":/home/"${CA_USERNAME}"/easy-rsa/pki/crl.pem /tmp > /dev/null 2>&1

# Refresh server
echo -e "Updating CRL on OpenVPN server... "
echo "${2}" | sudo -S cp -f /tmp/crl.pem /etc/openvpn/server/

echo -e "Restarting OpenVPN server... "
echo "${2}" | sudo -S systemctl restart openvpn-server@server.service

# Delete private & request file
echo -e "Deleting client key and request files... "
rm pki/private/${1}.key
rm pki/reqs/${1}.req
rm ~/client-configs/keys/${1}.key
rm ~/client-configs/keys/${1}.crt
rm ~/client-configs/files/${1}.ovpn
rm ~/dashboard/public/${1}.ovpn
