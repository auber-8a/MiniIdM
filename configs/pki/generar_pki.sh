sudo mkdir -p /etc/ssl/fis-pki
cd /etc/ssl/fis-pki

# 1. Crear la CA Raíz Institucional
sudo openssl ecparam -name prime256v1 -genkey -noout -out ca.key
sudo openssl req -new -x509 -sha256 -key ca.key -extensions v3_ca -days 365 \
  -subj "/C=EC/O=EPN/OU=FIS/CN=CA-Raiz-FIS" -out ca.crt

# 2. Crear los Certificados para el Servidor LDAP
sudo openssl ecparam -name prime256v1 -genkey -noout -out ldap.key
sudo openssl req -new -key ldap.key -subj "/C=EC/O=EPN/OU=FIS/CN=ldap.fis.epn.edu.ec" -out ldap.csr
sudo openssl x509 -req -in ldap.csr -CA ca.crt -CAkey ca.key -CAcreateserial -days 365 -sha256 -out ldap.crt

# 3. Asignar la propiedad de las llaves al usuario del sistema openldap
sudo chown -R openldap:openldap /etc/ssl/fis-pki/