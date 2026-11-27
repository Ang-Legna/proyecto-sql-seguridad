# Arquitectura de Seguridad, Cumplimiento, Rendimiento y Gobernanza en Bases de Datos SQL

![SQL Server 2022](https://img.shields.io/badge/Engine-SQL%20Server%202022-CC2927?style=for-the-badge&logo=microsoftsqlserver&logoColor=white)
![Docker](https://img.shields.io/badge/Environment-Docker%20Container-2496ED?style=for-the-badge&logo=docker&logoColor=white)
![Status](https://img.shields.io/badge/ESTADO-TODOS_LOS_M%C3%93DULOS_COMPLETADOS-2ea44f?style=for-the-badge)
![Academic Level](https://img.shields.io/badge/Nivel-Maestr%C3%ADa%20UTP-102A43?style=for-the-badge)

---

## Información Académica

* **Institución:** Universidad Tecnológica de Panamá (UTP) 
* **Facultad:** Facultad de Ingeniería de Sistemas Computacionales (Dirección de Investigación y Postgrado)
* **Programa:** Materias de Maestría — Opción a Trabajo de Graduación
* **Asignatura:** Base de Datos
* **Docente / Facilitadora:** Prof. Maylin Cherigo
* **Fecha:** Noviembre de 2026

### Integrantes del Grupo de Investigación y Desarrollo

| N° | Sustentante 
 **Caballero, Angela** | Coordinación de Repositorio, Seguridad y Documentación |


---

## Descripción General del Proyecto

Este repositorio consolida el diseño, implementación práctica y validación experimental de una arquitectura integral de gestión, protección, rendimiento y gobernanza sobre **Microsoft SQL Server 2022**. 

Para garantizar reproducibilidad total, independencia de restricciones de suscripción en la nube y trazabilidad forense bajo estándares profesionales de ingeniería, toda la infraestructura se ha desplegado sobre un entorno contenerizado local (**Docker Engine**), integrado con control de versiones en **GitHub** y políticas declarativas para APIs e Inteligencia Artificial (**Data API Builder** y **Model Context Protocol**).

---

## Arquitectura del Entorno de Laboratorio

* **Motor de Base de Datos:** Microsoft SQL Server 2022 Developer/Enterprise (Contenedor Linux `sql-lab`, puerto TCP `1433`).
* **IDE y Herramientas:** Visual Studio Code (extensión oficial `mssql`), Git CLI, Data API Builder (DAB).
* **Bases de Datos de Laboratorio:**
  * `LabSeguridad`: Implementación granular por unidad temática.
  * `LabEjercicio01`: Laboratorio integrador de controles combinados.

---

## Estructura del Repositorio

proyecto-sql-seguridad/
├── modulo-01/
│   └── scripts/                    # Scripts T-SQL de seguridad, cifrado, DDM, RLS, RBAC, auditoría e IA/MCP
├── modulo-02/
│   └── scripts/                    # Scripts T-SQL de optimización de consultas, índices y planes de ejecución
├── modulo-03/
│   └── scripts/                    # Scripts T-SQL de alta disponibilidad, respaldos y recuperación (RPO/RTO)
├── modulo-04/
│   └── scripts/                    # Automatización, Database DevOps y flujos CI/CD
├── data-api-builder/
│   ├── dab-config.json             # Políticas de autorización y seguridad para endpoints REST y GraphQL
│   └── mcp-config.json             # Gobernanza y aislamiento para agentes IA vía Model Context Protocol
├── ci-cd/                          # Pipelines y scripts de validación automatizada de esquemas
├── evidencias-pdf/                 # Informes ejecutivos con portada institucional UTP y capturas verificadas
└── README.md                       # Documentación técnica principal del proyecto


