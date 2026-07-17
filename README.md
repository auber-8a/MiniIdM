# MiniIdM
# Clúster de Autenticación de Alta Disponibilidad: LDAP, Kerberos y HAProxy

Este repositorio contiene la implementación y el análisis de resiliencia de un **Sistema de Autenticación y Directorio de Alta Disponibilidad (HA)** distribuido, diseñado para el entorno de red de la Facultad de Ingeniería de Sistemas (**FIS - EPN**).

La arquitectura mitiga los Puntos Únicos de Fallo (SPOF) duplicando tanto la base de datos de usuarios (OpenLDAP) como el servidor de autenticación (Kerberos KDC), administrados bajo un balanceador de carga de Capa 4 (HAProxy) con soporte de conmutación por error (*Failover*).

---

## 📐 Arquitectura del Sistema

El clúster está compuesto por tres componentes principales distribuidos en nodos dentro del segmento de red local:

*   **Front-End / Balanceador de Carga (`ldap.fis.epn.edu.ec` - `192.168.50.30`):** Corre HAProxy en el puerto `3890`, distribuyendo las solicitudes de manera equitativa entre los backends activos.
*   **Nodo Primario (`ldap1.fis.epn.ec` - `192.168.50.10`):** Aloja el servidor primario OpenLDAP (`slapd` en el puerto `3389`) y el KDC Maestro de Kerberos (`FIS.EPN.EC`).
*   **Nodo Secundario (`ldap2.fis.epn.ec` - `192.168.50.20`):** Aloja el servidor secundario de OpenLDAP y el KDC Esclavo de Kerberos, sincronizados para la tolerancia a fallos.

---

## 🚀 Guía de Uso y Administración rápida

El repositorio incluye un `Makefile` para agilizar la gestión de la infraestructura local:

### 1. Verificar el estado de los servicios locales
```bash
make status
