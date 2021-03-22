# Enter IP Address of Vault Server
IP_ADDRESS = 192.168.254.128

#create localhost certificates
cd /etc/ssl/certs/
openssl req -x509 -out localhostcert.pem -keyout localhostkey.pem \
  -newkey rsa:2048 -nodes -sha256 \
  -subj '/CN=localhost' -extensions EXT -config <( \
   printf "[dn]\nCN=localhost\n[req]\ndistinguished_name = dn\n[EXT]\nsubjectAltName=DNS:localhost\nkeyUsage=digitalSignature\nextendedKeyUsage=serverAuth")

#Install and configure Consul for Vault backend
cd ~
mkdir Hashicorp
cd Hashicorp
wget https://releases.hashicorp.com/consul/1.7.3/consul_1.7.3_linux_amd64.zip
unzip consul_1.7.3_linux_amd64.zip
sudo mv consul /usr/bin/
cd /etc/systemd/system/
sudo vim consul.service << EOF
[Unit]
Description=Consul
Documentation=https://www.consul.io
[Service]
ExecStart=/usr/bin/consul agent -server -ui -data-dir=/tem/consul -bootstrap-expect=1 -node=vault -bind=$IP_ADDRESS -config-dir=/etc/consul.d/
ExecReload=/bin/kill -HUP $MAINPID
LimitNOFILE=65536
[Install]
WantedBy=multi-user.target
EOF
sudo mkdir /etc/consul.d
cd /etc/consul.d
sudo vim ui.json << EOF
{
  "addresses" : {local
    "http": "0.0.0.0"
  }
}
EOF
sudo systemctl daemon-reload
sudo systemctl start consul
sudo systemctl enable consul

# Install and configure vault
cd ~/Hashicorp
wget https://releases.hashicorp.com/vault/1.5.0/vault_1.5.0_linux_amd64.zip
unzip vault_1.5.0_linux_amd64.zip
sudo mv vault /usr/bin/
sudo mkdir /etc/vault/
cd /etc/vault/
sudo vim config.hcl << EOF
storage "consul" {
        address = "$IP_ADDRESS:8500"
        path = "vault/"
}
listener "tcp" {
        address = "0.0.0.0:443"
        tls_disable = 0
        tls_cert_file = "/etc/ssl/certs/localhostcert.pem"
        tls_key_file = "/etc/ssl/certs/localhostkey.pem"
}
ui = true
EOF
cd /etc/systemd/system/
sudo vim vault.service << EOF
[Unit]
Description=Vault
Documentation=https://www.vault.io

[Service]
ExecStart=/usr/bin/vault server -config=/etc/vault/config.hcl
ExecReload=/bin/kill -HUP $MAINPID
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
export VAULT_ADDR="https://localhost:443"
export VAULT_ADDR="https://localhost:443" >> ~/.bashrc
vault -autocomplete-install
complete -C /usr/bin/vault vault
sudo systemctl start vault
sudo systemcrl enable vault
