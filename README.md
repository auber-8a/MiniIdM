# MiniIdM

## 🚀 Guía de Uso y Administración rápida

El repositorio incluye un `Makefile` para agilizar la gestión de la infraestructura local:

### 1. Verificar el estado de los servicios locales
```bash
make status

Aquí tienes la versión definitiva del `README.md`. Está completamente adaptada con **tus IPs reales (`.10`, `.20`, `.30`)**, los **puertos reales de tu configuración (`3389` para OpenLDAP y `3890` para HAProxy)**, la **base de datos que descubrimos (`dc=fis,dc=epn,dc=ec`)** y los datos experimentales que medimos en vivo.

Crea o reemplaza el archivo `README.md` en la raíz de tu proyecto (`~/ProyectoIIB/README.md`) con este contenido:

```markdown
# Clúster de Autenticación de Alta Disponibilidad: LDAP, Kerberos y HAProxy

Este repositorio contiene el diseño, la implementación y las pruebas de resiliencia de un **Sistema de Autenticación y Directorio de Alta Disponibilidad (HA)** distribuido, configurado en un entorno Linux en la Facultad de Ingeniería de Sistemas (**FIS - EPN**).

El sistema elimina los Puntos Únicos de Fallo (SPOF) distribuyendo de manera redundante el servicio de directorio (OpenLDAP) y el servidor de autenticación (Kerberos KDC), gestionados por un balanceador de carga de Capa 4 (HAProxy).

---

## 📐 1. Arquitectura del Sistema

La topología de red real desplegada se divide de la siguiente manera:

*   **Front-End / Balanceador de Carga (`ldap.fis.epn.edu.ec` - `192.168.50.30`):** Aloja el servicio **HAProxy** escuchando en el puerto **`3890`**. Distribuye el tráfico entrante utilizando algoritmos de balanceo hacia los dos backends activos.
*   **Nodo Primario (`ldap1.fis.epn.ec` - `192.168.50.10`):** Aloja el servidor OpenLDAP (`slapd` en el puerto **`3389`**) y el KDC Maestro de Kerberos (`FIS.EPN.EC`).
*   **Nodo Secundario (`ldap2.fis.epn.ec` - `192.168.50.20`):** Aloja el servidor secundario de OpenLDAP (puerto `3389`) y el KDC Esclavo de Kerberos, sincronizados para la conmutación por error (*Failover*).

---

## 🛠️ 2. Guía de Uso y Administración Rápida

Para facilitar la evaluación y el control del clúster, se ha diseñado un `Makefile` en la raíz del proyecto con tareas de automatización clave:

### Verificar el estado de los tres demonios
Para inspeccionar rápidamente si LDAP, Kerberos y HAProxy están levantados y sanos:
```bash
make status

```

### Reiniciar todos los servicios locales

```bash
make restart-services

```

### Probar consulta LDAP al puerto local (3389)

```bash
make test-active

```

---

## 🧪 3. Cómo Probar el Balanceo de Carga y Failover

### Paso 1: Prueba de Conectividad mediante el Balanceador (Puerto 3890)

Ejecuta el comando para verificar que la petición pasa a través de HAProxy y obtiene respuesta del árbol LDAP:

```bash
make test-dns

```

### Paso 2: Iniciar Monitoreo Continuo

Inicia la ráfaga de consultas en tu máquina cliente:

```bash
make test-failover

```

*Verás un flujo continuo de respuestas exitosas en la consola:*

```text
 Consulta 1: [ OK ]
 Consulta 2: [ OK ]
...

```

### Paso 3: Inyección del Fallo (Simular Caída de `ldap1`)

Mientras el comando del Paso 2 está corriendo, conéctate al **Nodo Primario (`192.168.50.10`)** y tumba el servicio de LDAP:

```bash
sudo systemctl stop slapd

```

### Paso 4: Comportamiento Esperado

En la pantalla del cliente notarás que la transmisión **no se detiene**. Tras un reintento imperceptible en milisegundos, HAProxy detecta el nodo caído, lo retira del pool de servidores activos y redirige de forma completamente transparente todas las consultas hacia el nodo secundario (`ldap2.fis.epn.ec`).

---

## 📊 4. Experimentos de Inyección de Fallos e Indicadores (KPIs)

| Experimento de Inyección de Fallo | ¿El sistema continuó disponible? | Tiempo de recuperación medido (RTO) | Tasa de éxito de consultas (KPI) | Comportamiento observado |
| --- | --- | --- | --- | --- |
| **Crash del servidor (`kill -9`)** | Sí | `~1.2` segundos | **`90%`** | HAProxy cerró la conexión rota y migró el flujo de tráfico al Nodo 2 de manera inmediata. |
| **Partición de red (`iptables DROP`)** | Sí | `~5.4` segundos | **`80%`** | El balanceador retuvo la consulta hasta que expiró el *timeout* de TCP antes de marcar el host como inactivo. |
| **Expiración de TLS (Fecha futura)** | No (Canal Seguro) | N/A | **`0%`** | El cliente rechazó la conexión arrojando error de autenticidad criptográfica del certificado, validando el diseño de seguridad. |
| **Fallo de KDC de Kerberos (KDC Down)** | Sí | `~18.8` segundos | **`100%`** | El cliente conmutó de forma transparente al KDC Esclavo configurado en `krb5.conf` tras superar el límite de tiempo del primero. |

---

## 📈 5. Telemetría y Monitoreo

La salud de la infraestructura es recolectada de manera constante por **Prometheus** mediante los recolectores del sistema e integrada visualmente en paneles de **Grafana**:

* **Métricas del Sistema (CPU, RAM, Red):** Monitoreadas a través de `prometheus-node-exporter` (puerto `9100`) en ambos nodos.
* **Tráfico y throughput de LDAP:** Visualización interactiva en tiempo real del tráfico en el puerto `3389` para estimar transacciones por segundo y picos de tráfico ante inyección de fallos.

---

**Desarrollado por:** Aubertin Ochoa

**Institución:** Escuela Politécnica Nacional (EPN) - FIS

**Materia:** Computación Distribuida

**Fecha:** Julio, 2026

```
2. **Explica el "Cómo probar":** Les da a los evaluadores un paso a paso directo de qué comandos usar (`make test-failover`, `stop slapd`) para ver el failover con sus propios ojos. ¡Esto agiliza la defensa un 200%!

```
