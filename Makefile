# ==============================================================================
# Makefile - Proyecto de Sistemas Distribuidos IIB (FIS - EPN)
# Automatización de servicios, pruebas de failover y diagnóstico de Alta Disponibilidad.
# ==============================================================================

# Variables de configuración del entorno
LDAP_URI       = ldap://ldap.fis.epn.edu.ec:3890
LDAP_BASE      = dc=fis,dc=epn,dc=ec
LDAP_LOCAL_URI = ldap://127.0.0.1:3389

# Colores para mejorar el diagnóstico en la terminal
OK_COLOR   = \033[1;32m[ OK ]\033[0m
FAIL_COLOR = \033[1;31m[ FALLO ]\033[0m
INFO_COLOR = \033[1;36m[INFO]\033[0m

.PHONY: help status restart-services test-active test-dns test-failover clean-logs

help:
	@echo "======================================================================"
	@echo "        Comandos de Administración de Infraestructura (HA)"
	@echo "======================================================================"
	@echo "  make status           - Verifica el estado de slapd, Kerberos y HAProxy"
	@echo "  make restart-services - Reinicia los demonios locales de forma segura"
	@echo "  make test-active      - Prueba de consulta LDAP directa al puerto local (3389)"
	@echo "  make test-dns         - Prueba de resolución de DNS mediante el balanceador (3890)"
	@echo "  make test-failover    - Ejecuta el bucle infinito de monitoreo de caídas (1s sleep)"
	@echo "  make clean-logs       - Limpia archivos temporales y dumps del directorio"
	@echo "======================================================================"

status:
	@echo "=== [1/3] Estado de OpenLDAP ==="
	-sudo systemctl status slapd --no-pager
	@echo "\n=== [2/3] Estado de Kerberos (KDC) ==="
	-sudo systemctl status krb5-kdc --no-pager
	@echo "\n=== [3/3] Estado de HAProxy ==="
	-sudo systemctl status haproxy --no-pager

restart-services:
	@echo "$(INFO_COLOR) Reiniciando servicios detectados en este nodo..."
	@sudo systemctl restart slapd && echo "  -> OpenLDAP: $(OK_COLOR)"
	@-systemctl list-unit-files | grep -q krb5-kdc && sudo systemctl restart krb5-kdc && echo "  -> Kerberos: $(OK_COLOR)" || true
	@-systemctl list-unit-files | grep -q haproxy && sudo systemctl restart haproxy && echo "  -> HAProxy:  $(OK_COLOR)" || true
	@echo "¡Proceso de reinicio completado!"

test-active:
	@echo "$(INFO_COLOR) Consultando el namingContexts directo al LDAP local (Puerto 3389)..."
	ldapsearch -x -H $(LDAP_LOCAL_URI) -s base -b "" namingContexts

test-dns:
	@echo "$(INFO_COLOR) Consultando el namingContexts a través del Balanceador HAProxy (Puerto 3890)..."
	ldapsearch -x -H $(LDAP_URI) -s base -b "" namingContexts

test-failover:
	@echo "$(INFO_COLOR) Iniciando ráfaga continua de consultas hacia el balanceador..."
	@echo "$(INFO_COLOR) Abre otra terminal y apaga un nodo para verificar el RTO."
	@echo "Presiona [CTRL+C] para detener el experimento."
	@echo "----------------------------------------------------------------------"
	@i=1; \
	while true; do \
		if ldapsearch -x -H $(LDAP_URI) -b "$(LDAP_BASE)" > /dev/null 2>&1; then \
			echo -e "[$$(date +%T)] Consulta $$i: $(OK_COLOR)"; \
		else \
			echo -e "[$$(date +%T)] Consulta $$i: $(FAIL_COLOR)"; \
		fi \
		i=$$((i+1)); \
		sleep 1; \
	done

clean-logs:
	@echo "Limpiando logs, dumps y temporales..."
	rm -f *.log *.dump *.tmp
