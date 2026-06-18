# Tienda Perritos — Despliegue AWS EKS + GitHub Actions

Aplicación de 3 servicios (Frontend Nginx, Backend Node.js, MySQL) desplegada en Amazon EKS con pipeline CI/CD via GitHub Actions.

> **IMPORTANTE — AWS Academy borra todo al cerrar el lab.**
> Cada sesión debes recrear el cluster EKS, el node group y actualizar los secrets de GitHub.
> Sigue esta guía de principio a fin cada vez que inicies el lab.

---

## Datos fijos de tu infraestructura

| Dato | Valor |
|------|-------|
| Account ID | `528853233991` |
| Región | `us-east-1` |
| Cluster EKS | `tienda-perritos` |
| Namespace K8s | `tienda` |
| ECR Registry | `528853233991.dkr.ecr.us-east-1.amazonaws.com` |
| VPC | `vpc-07b79e673fd807ded` |
| LabRole ARN | `arn:aws:iam::528853233991:role/LabRole` |

---

## Guía completa — Ejecutar cada sesión desde cero

### PASO 1 — Iniciar el lab y obtener credenciales

1. Entra a **AWS Academy Learner Lab**
2. Clic en **Start Lab** — espera que el círculo quede **verde**
3. Clic en **AWS** para abrir la consola AWS
4. Clic en **AWS Details** → **Show** (junto a AWS CLI)
5. Copia los 3 valores (los necesitas en el Paso 5):
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`
   - `AWS_SESSION_TOKEN`

---

### PASO 2 — Abrir CloudShell

Desde la consola AWS, clic en el ícono de terminal **`>_`** en la barra superior derecha.

Espera que CloudShell cargue y verás el prompt `~ $`.

---

### PASO 3 — Crear repositorios ECR

Los repos ECR **a veces persisten** entre sesiones. Este script los crea si no existen y los omite si ya están:

```bash
curl -s https://raw.githubusercontent.com/MGcarva/Devops/main/scripts/1-variables.sh | bash
```

Deberías ver:
```
Account : 528853233991
LabRole : arn:aws:iam::528853233991:role/LabRole
SG      : sg-094feca72414e1c29
```

Si los repos ECR fueron eliminados, créalos manualmente:
```bash
aws ecr create-repository --repository-name tienda-frontend --region us-east-1
aws ecr create-repository --repository-name tienda-backend  --region us-east-1
aws ecr create-repository --repository-name tienda-db       --region us-east-1
```

---

### PASO 4 — Crear el cluster EKS

```bash
curl -s https://raw.githubusercontent.com/MGcarva/Devops/main/scripts/2-crear-cluster.sh | bash
```

- Cuando aparezca el JSON con `"status": "CREATING"`, presiona **`q`** para salir del paginador
- El script quedará esperando con el mensaje: `Esperando que el cluster quede ACTIVE (~15 min)...`
- **No cierres CloudShell**, espera hasta ver:

```
============================================
 CLUSTER LISTO - Ahora ejecuta el script 3
============================================
```

---

### PASO 5 — Crear el Node Group

Ejecuta este comando **inmediatamente después** de que el Paso 4 diga CLUSTER LISTO:

```bash
curl -s https://raw.githubusercontent.com/MGcarva/Devops/main/scripts/3-crear-nodegroup.sh | bash
```

- Presiona **`q`** si aparece el paginador JSON
- Espera hasta ver:

```
============================================
 TODO LISTO
============================================
```

---

### PASO 6 — Actualizar secrets en GitHub

Ve a: **github.com/MGcarva/Devops → Settings → Secrets and variables → Actions**

Para cada secret: clic en el lápiz (editar) e ingresa el nuevo valor.

| Secret | Valor | Dónde obtenerlo |
|--------|-------|-----------------|
| `AWS_ACCESS_KEY_ID` | El valor copiado en Paso 1 | AWS Details del lab |
| `AWS_SECRET_ACCESS_KEY` | El valor copiado en Paso 1 | AWS Details del lab |
| `AWS_SESSION_TOKEN` | El valor copiado en Paso 1 | AWS Details del lab |
| `AWS_REGION` | `us-east-1` | Fijo, no cambia |
| `EKS_CLUSTER_NAME` | `tienda-perritos` | Fijo, no cambia |
| `EKS_NAMESPACE` | `tienda` | Fijo, no cambia |

---

### PASO 7 — Disparar el pipeline

Desde tu computador, en la carpeta del proyecto (PowerShell o Git Bash):

```bash
cd "C:\Users\ghonc\Downloads\3.6.3 APP tienda-perritos-EKS_GITHUB"
git commit --allow-empty -m "trigger: activar pipeline"
git push
```

Monitorea el progreso en: **github.com/MGcarva/Devops → Actions**

El pipeline ejecuta estos pasos en orden:
1. Checkout código
2. Configurar credenciales AWS
3. Login a ECR
4. Build y push de los 3 contenedores a ECR
5. Configurar kubeconfig para EKS
6. Aplicar manifests de Kubernetes (namespace, DB, backend, frontend)
7. Actualizar imágenes en los deployments
8. Mostrar estado final de pods y servicios

> El pipeline completo tarda aproximadamente **5–10 minutos**.

---

### PASO 8 — Obtener la URL pública

Cuando el pipeline termine, en CloudShell ejecuta:

```bash
aws eks update-kubeconfig --region us-east-1 --name tienda-perritos
kubectl get svc -n tienda
```

Busca el servicio `tienda-frontend` y copia el valor de la columna `EXTERNAL-IP`.
Esa es la URL pública de la aplicación. Puede tardar 2–3 minutos en aparecer.

---

## Resumen de comandos CloudShell (copiar y pegar en orden)

```bash
# PASO 3 — Verificar variables y ECR
curl -s https://raw.githubusercontent.com/MGcarva/Devops/main/scripts/1-variables.sh | bash

# PASO 4 — Crear cluster EKS (~15 min, presiona q en el paginador)
curl -s https://raw.githubusercontent.com/MGcarva/Devops/main/scripts/2-crear-cluster.sh | bash

# PASO 5 — Crear node group (~5 min, solo después de ver CLUSTER LISTO)
curl -s https://raw.githubusercontent.com/MGcarva/Devops/main/scripts/3-crear-nodegroup.sh | bash

# PASO 8 — Ver URL pública (después del pipeline)
aws eks update-kubeconfig --region us-east-1 --name tienda-perritos
kubectl get svc -n tienda
```

---

## Arquitectura

```
GitHub push a main
        │
        ▼
GitHub Actions (deploy-eks.yml)
        │
        ├── Build imágenes Docker
        ├── Push a Amazon ECR
        │       ├── tienda-frontend
        │       ├── tienda-backend
        │       └── tienda-db
        │
        └── Deploy a Amazon EKS
                Namespace: tienda
                ├── tienda-frontend  :80   (2 pods, LoadBalancer público)
                ├── tienda-backend   :3001 (2 pods, ClusterIP interno)
                └── tienda-db        :3306 (1 pod,  ClusterIP interno)
```

---

## Estructura de archivos

```
.
├── .github/workflows/
│   └── deploy-eks.yml          # Pipeline CI/CD
├── frontend/                   # Nginx + HTML/JS
├── backend/                    # Node.js API (puerto 3001)
├── db/                         # MySQL + init.sql
├── k8s/                        # Manifests Kubernetes
│   ├── namespace.yaml
│   ├── mysql-secret.yaml       # Password BD: admin123
│   ├── mysql-deployment.yaml
│   ├── mysql-service.yaml
│   ├── backend-deployment.yaml
│   ├── backend-service.yaml
│   ├── backend-hpa.yaml
│   ├── frontend-deployment.yaml
│   ├── frontend-service.yaml
│   └── frontend-hpa.yaml
└── scripts/                    # Scripts de setup
    ├── 1-variables.sh          # Verifica Account ID y SG
    ├── 2-crear-cluster.sh      # Crea cluster EKS
    └── 3-crear-nodegroup.sh    # Crea node group con 2 nodos t3.medium
```

---

## Resolución de problemas

### Pipeline falla en "Configurar credenciales AWS"
Las credenciales expiraron. Actualiza los 3 secrets de AWS en GitHub (Paso 6).

### Pipeline falla en "Configurar kubeconfig para EKS"
El cluster no existe o las credenciales son incorrectas. Verifica que completaste los Pasos 4 y 6.

### Los pods quedan en CrashLoopBackOff
```bash
kubectl logs -n tienda deployment/tienda-backend
kubectl describe pod -n tienda -l app=tienda-backend
```

### No aparece EXTERNAL-IP después de 5 minutos
```bash
kubectl describe svc tienda-frontend -n tienda
```

### Ver estado general de todos los recursos
```bash
kubectl get all -n tienda
```
