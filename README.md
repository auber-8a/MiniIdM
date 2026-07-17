# MiniIdM: Infraestructura de Identidad Segura para la FIS

Este repositorio contiene el diseño, la implementación y las pruebas de resiliencia de **MiniIdM**, un sistema de gestión de identidades e infraestructura de autenticación distribuida en **Alta Disponibilidad (HA)**. Diseñado específicamente para los requerimientos de la Facultad de Ingeniería de Sistemas (**FIS - EPN**), el proyecto elimina los puntos únicos de fallo (SPOF) duplicando tanto el servicio de directorio (OpenLDAP) como el de autenticación (Kerberos KDC), bajo un balanceador de carga de Capa 4 (HAProxy).

---

## 📐 1. Arquitectura del Sistema

La topología de red real implementada (adaptada para entornos virtuales y WSL2) distribuye las cargas en tres instancias lógicas dentro del segmento de red local:

```text
                     [ CLIENTE / ADMINISTRADOR ]
                                  │
                       Petición LDAP (Puerto 3890)
                                  ▼
                ┌───────────────────────────────────┐
                │     HAProxy (Balanceador de Carga) │ (192.168.50.30)
                └─────────────────┬─────────────────┘
                                  │ (Balanceo Round-Robin / Activo-Pasivo)
                 ┌────────────────┴────────────────┐
                 ▼                                 ▼
   ┌───────────────────────────┐     ┌───────────────────────────┐
   │    Nodo 1: Principal      │     │     Nodo 2: Secundario    │
   ├───────────────────────────┤     ├───────────────────────────┤
   │ IP: 192.168.50.10         │     │ IP: 192.168.50.20         │
   │                           │     │                           │
   │ ──► OpenLDAP (Port 3389)  │     │ ──► OpenLDAP (Port 3389)  │
   │ ──► Kerberos KDC Maestro  │     │ ──► Kerberos KDC Esclavo  │
   └───────────────────────────┘     └───────────────────────────┘

```

* **Front-End / Balanceador de Carga (`ldap.fis.epn.edu.ec` - `192.168.50.30`):** Corre el servicio **HAProxy** escuchando en el puerto alternativo **`3890`** para redirigir el tráfico hacia los backends disponibles.
* **Nodo Primario (`ldap1.fis.epn.ec` - `192.168.50.10`):** Aloja el servidor OpenLDAP de producción (`slapd` en el puerto **`3389`**) y el KDC Maestro de Kerberos (`FIS.EPN.EC`).
* **Nodo Secundario (`ldap2.fis.epn.ec` - `192.168.50.20`):** Aloja la réplica de OpenLDAP (puerto **`3389`**) y el KDC Secundario/Esclavo de Kerberos para conmutación por error instantánea (*failover*).

---


## 🗂️ 1.2. Estructura del Directorio (DIT)

El Directory Information Tree (DIT) de **MiniIdM** ha sido diseñado bajo un enfoque de **Control de Acceso Basado en Roles (RBAC)** para segmentar las identidades de la FIS:

```text
dc=fis,dc=epn,dc=ec (Raíz del DIT)
├── ou=estudiantes
│   ├── ou=pregrado
│   │   └── uid=aochoa (Aubertin Ochoa)
│   └── ou=posgrado
│       └── uid=jperez (Juan Perez)
├── ou=profesores
│   └── uid=emafla (Enrique Mafla)
└── ou=administrativos
    ├── ou=decanato
    │   └── uid=rnavarrete (Rosa Navarrete)
    ├── ou=infraestructura_redes
    │   └── uid=mortega (Mario Ortega)
    ├── ou=finanzas
    │   └── uid=lsuarez (Luis Suarez)
    └── ou=talento_humano
        └── uid=dmontuano (David Montuano)
```

## 🛠️ 2. Guía de Uso y Administración Rápida

Para facilitar la evaluación, control y auditoría de la plataforma en tiempo real, la raíz del repositorio incluye un `Makefile` con comandos automatizados:

### A) Inspección del Estado de los Servicios

Muestra la salud de los tres demonios del nodo local sin interrumpir la terminal:

```bash
make status

```

### B) Reinicio General de la Infraestructura

Aplica de forma ordenada un reinicio a todos los servicios de identidad en caso de cambios de configuración:

```bash
make restart-services

```

### C) Verificación de Conectividad Directa (Puerto Local 3389)

Realiza un `ldapsearch` rápido apuntando de forma directa a la instancia de OpenLDAP en ejecución local:

```bash
make test-active

```

---

## 🧪 3. Cómo Probar el Balanceo de Carga y Failover

Sigue este protocolo de tres pasos para demostrar el comportamiento distribuido ante fallos durante la defensa del proyecto:

### Paso 1: Comprobar Resolución de Nombres (Balanceador Puerto 3890)

Verifica que el cliente pueda realizar consultas utilizando la URL oficial que apunta a HAProxy:

```bash
make test-dns

```

### Paso 2: Iniciar la Ráfaga de Consultas Continua

Inicia un envío continuo de consultas cada segundo en tu terminal para registrar la estabilidad del clúster:

```bash
make test-failover

```

*Se observará una salida regular y limpia:*

```text
 Consulta 1: [ OK ]
 Consulta 2: [ OK ]
...

```

### Paso 3: Simular Crash del Servidor Primario

Mientras la ráfaga anterior se ejecuta, simula una caída catastrófica deteniendo el servicio en el **Nodo Primario (`ldap1` / `192.168.50.10`)**:

```bash
sudo systemctl stop slapd

```

### Paso 4: Comportamiento Esperado

En la pantalla del cliente, la secuencia de consultas **no se detendrá**. HAProxy detectará de manera pasiva el estado inactivo (*DOWN*) de `ldap1` y redirigirá de manera transparente todo el tráfico subsecuente hacia `ldap2.fis.epn.ec`. El cliente experimentará una latencia de redirección menor a un segundo en la transición.

---

## 📊 4. Experimentos de Inyección de Fallos e Indicadores (KPIs)

Durante el análisis experimental de la infraestructura distribuida, se inyectaron fallos críticos para registrar los tiempos de recuperación (*Recovery Time Objective - RTO*) y el impacto en los servicios:

| Experimento de Inyección de Fallo | ¿Disponibilidad Continua? | Tiempo de Recuperación (RTO) | Tasa de Éxito de Consultas (KPI) | Comportamiento Observado |
| --- | --- | --- | --- | --- |
| **Crash del servidor (`kill -9`)** | Sí | `~1.2` segundos | **`90%`** | HAProxy cerró la conexión TCP interrumpida abruptamente y reasignó el tráfico de inmediato. |
| **Partición de red (`iptables DROP`)** | Sí | `~5.4` segundos | **`80%`** | El balanceador retuvo la consulta activa hasta que se alcanzó el *timeout* TCP configurado antes de conmutar al Nodo 2. |
| **Expiración de TLS (Fecha futura)** | No (Conexión Segura) | N/A | **`0%`** | El cliente rechazó proactivamente la conexión debido a un certificado no confiable (`peer certificate is expired`), validando la directiva de seguridad. |
| **Fallo del KDC de Kerberos** | Sí | `~18.8` segundos | **`100%`** | El cliente conmutó de manera automática al KDC Secundario listado en su archivo `krb5.conf` tras expirar el timeout del primero. |

---

## 📈 5. Telemetría y Monitoreo

La plataforma cuenta con un sistema de observabilidad centralizado utilizando **Prometheus** y **Grafana**:

* **Métricas del Sistema Operativo:** Tiempos de CPU, consumo de memoria RAM física y virtual, y carga de sockets de red mediante `prometheus-node-exporter` (puerto `9100`).
* **Tráfico y Rendimiento de LDAP:** Monitorización de conexiones TCP en caliente e hilos activos sobre el puerto de escucha `3389` para estimar la tasa de consultas por segundo (*Throughput*) durante los ataques controlados e inyecciones de fallo.

---

## ⚡ 6. Guía de Instalación Rápida

Para levantar la infraestructura de **MiniIdM**, ejecuta los siguientes bloques de comandos en cada servidor correspondiente de tu clúster.

### A) En el Balanceador (`192.168.50.30`)

Instala y configura HAProxy para escuchar en el puerto `3890` y balancear hacia los puertos `3389` de tus dos nodos:

```bash
# 1. Instalar HAProxy
sudo apt update && sudo apt install haproxy -y

# 2. Configurar el balanceo de carga (Asegúrate de agregar esto al final de /etc/haproxy/haproxy.cfg)
# listen ldap_cluster
#     bind *:3890
#     mode tcp
#     balance roundrobin
#     server ldap1 192.168.50.10:3389 check
#     server ldap2 192.168.50.20:3389 check

# 3. Reiniciar el servicio
sudo systemctl restart haproxy

```

### B) En los Nodos LDAP (`192.168.50.10` y `192.168.50.20`)

Instala OpenLDAP y configura el demonio para escuchar en tu puerto personalizado:

```bash
# 1. Instalar OpenLDAP
sudo apt update && sudo apt install slapd ldap-utils -y

# 2. Cambiar puerto de escucha a 3389 (Editar /etc/default/slapd)
# SLAPD_SERVICES="ldap://127.0.0.1:3389/ ldap://192.168.50.10:3389/ ldapi:///"

# 3. Levantar el servicio
sudo systemctl restart slapd

```

---

## 👥 7. Diccionario de Usuarios de Prueba (DIT Completo)

> ⚠️ **Nota de Seguridad Académica:** Por simplicidad en la evaluación y calibración de las pruebas de estrés de este proyecto de Computación Distribuida, **todas las cuentas listadas a continuación comparten la misma contraseña:**
> 🔑 **Contraseña Global:** `password`

A continuación, se detalla el DN (*Distinguished Name*) exacto de cada usuario según la jerarquía establecida en tu árbol de directorios para realizar pruebas de autenticación rápidas mediante `ldapsearch` o `kinit`:

### 🎓 Rama Estudiantes (`ou=estudiantes,dc=fis,dc=epn,dc=ec`)

* **Aubertin Ochoa (Pregrado)**
* **DN:** `uid=aochoa,ou=pregrado,ou=estudiantes,dc=fis,dc=epn,dc=ec`
* **Principal Kerberos:** `aochoa@FIS.EPN.EC`


* **Juan Pérez (Posgrado)**
* **DN:** `uid=jperez,ou=posgrado,ou=estudiantes,dc=fis,dc=epn,dc=ec`
* **Principal Kerberos:** `jperez@FIS.EPN.EC`



---

### 👨‍🏫 Rama Profesores (`ou=profesores,dc=fis,dc=epn,dc=ec`)

* **Enrique Mafla**
* **DN:** `uid=emafla,ou=profesores,dc=fis,dc=epn,dc=ec`
* **Principal Kerberos:** `emafla@FIS.EPN.EC`



---

### 💼 Rama Administrativos (`ou=administrativos,dc=fis,dc=epn,dc=ec`)

* **Rosa Navarrete (Decanato)**
* **DN:** `uid=rnavarrete,ou=decanato,ou=administrativos,dc=fis,dc=epn,dc=ec`
* **Principal Kerberos:** `rnavarrete@FIS.EPN.EC`


* **Mario Ortega (Infraestructura de Redes)**
* **DN:** `uid=mortega,ou=infraestructura_redes,ou=administrativos,dc=fis,dc=epn,dc=ec`
* **Principal Kerberos:** `mortega@FIS.EPN.EC`


* **Luis Suárez (Finanzas)**
* **DN:** `uid=lsuarez,ou=finanzas,ou=administrativos,dc=fis,dc=epn,dc=ec`
* **Principal Kerberos:** `lsuarez@FIS.EPN.EC`


* **David Montuano (Talento Humano)**
* **DN:** `uid=dmontuano,ou=talento_humano,ou=administrativos,dc=fis,dc=epn,dc=ec`
* **Principal Kerberos:** `dmontuano@FIS.EPN.EC`



---

### 🧪 Comando Rápido para verificar la autenticación de cualquier usuario:

Para probar la autenticación simple contra el balanceador de cualquiera de estos usuarios, puedes ejecutar este comando directamente (reemplazando por el DN que quieras testear):

```bash
ldapsearch -x -H ldap://ldap.fis.epn.edu.ec:3890 -D "uid=aochoa,ou=pregrado,ou=estudiantes,dc=fis,dc=epn,dc=ec" -w "password" -b "dc=fis,dc=epn,dc=ec"

```


**Desarrollado por:** Aubertin Ochoa

**Correo Institucional:** aubertin.ochoa@epn.ec

**Institución:** Escuela Politécnica Nacional (EPN)

**Materia:** Computación Distribuida

**Fecha:** Julio, 2026



```
