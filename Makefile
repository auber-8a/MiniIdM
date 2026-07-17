# ==============================================================================
# Makefile - Proyecto de Sistemas Distribuidos IIB (FIS - EPN)
# Automatización de servicios, pruebas de failover y diagnóstico de Alta Disponibilidad.
# ==============================================================================

# Variables de configuración del entorno
LDAP_URI       = ldap://ldap.fis.epn.edu.ec:3890
LDAP_BASE      = dc=fis,dc=epn,dc=ec
LDAP_LOCAL_URI = ldap://127.0.0.1:3389

.PHONY: help status restart-services test-active test-dns test-failover clean-logs

help:
	@echo "======================================================================"
	@echo "       Comandos de Administración de Infraestructura (HA)"
	@echo "======================================================================"
	@echo "  make status             - Verifica el estado de slapd, Kerberos y HAProxy"
	@echo "  make restart-services   - Reinicia los demonios locales"
	@echo "  make test-active        - Prueba de consulta LDAP directa al puerto local (3389)"
	@echo "  make test-dns           - Prueba de resolución de DNS mediante el balanceador (3890)"
	@echo "  make test-failover      - Ejecuta el bucle de inyección de fallos (10 queries/1s)"
	@echo "  make clean-logs         - Limpia archivos temporales y dumps del directorio"
	@echo "======================================================================"

status:
	@echo "=== [1/3] Estado de OpenLDAP ==="
	-sudo systemctl status slapd --no-pager
	@echo "\n=== [2/3] Estado de Kerberos (KDC) ==="
	-sudo systemctl status krb5-kdc --no-pager
	@echo "\n=== [3/3] Estado de HAProxy ==="
	-sudo systemctl status haproxy --no-pager

restart-services:
	@echo "Reiniciando servicios del nodo local..."
	sudo systemctl restart slapd
	sudo systemctl restart krb5-kdc
	sudo systemctl restart haproxy
	@echo "¡Servicios reiniciados!"

test-active:
	@echo "Consultando el namingContexts directo al LDAP local (Puerto 3389)..."
	ldapsearch -x -H $(LDAP_LOCAL_URI) -s base -b "" namingContexts

test-dns:
	@echo "Consultando el namingContexts a través del Balanceador HAProxy (Puerto 3890)..."
	ldapsearch -x -H $(LDAP_URI) -s base -b "" namingContexts

test-failover:
	@echo "Iniciando bucle de inyección de fallos continuo (10 iteraciones, 1s sleep)..."
	@for i in $$(seq 1 10); do \
		time ldapsearch -x -H $(LDAP_URI) -b "$(LDAP_BASE)" > /dev/null && \
		echo "[$$(date +%T)] Consulta $$i: [ OK ]" || \
		echo "[$$(date +%T)] Consulta $$i: [ FALLO ]"; \
		sleep 1; \
	done

clean-logs:
	@echo "Limpiando logs, dumps y temporales..."
	rm -f *.log *.dump *.tmp