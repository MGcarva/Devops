# Tienda Perritos — Despliegue AWS EKS + GitHub Actions

Aplicación de 3 servicios (Frontend Nginx, Backend Node.js, MySQL) desplegada en Amazon EKS con pipeline CI/CD via GitHub Actions.

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

---

## Guía completa para cada nueva sesión de AWS Academy

> Las credenciales del Learner Lab **expiran cada vez que apagas el lab**.
> Cada vez que vuelvas debes repetir los pasos 1 y 6.
> Los pasos 2–5 solo se hacen una vez (la infraestructura persiste mientras no borres los recursos).

---

### PASO 1 — Iniciar el lab y obtener credenciales

1. Entra a **AWS Academy Learner Lab**
2. Clic en **Start Lab** — espera que el círculo quede **verde**
3. Clic en **AWS Details** → **Show** (junto a AWS CLI)
4. Copia los 3 valores:
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`
   - `AWS_SESSION_TOKEN`

---

### PASO 2 — Verificar que el cluster EKS existe

Abre **CloudShell** (ícono `>_` en la barra superior de la consola AWS) y ejecuta:

```bash
curl -s https://raw.githubusercontent.com/MGcarva/Devops/main/scripts/1-variables.sh | bash
```

Luego verifica el cluster:

```bash
aws eks describe-cluster --name tienda-perritos --region us-east-1 --query "cluster.status" --output text
```

- Si responde `ACTIVE` → el cluster ya existe, salta al **Paso 6**
- Si responde `No cluster found` → el cluster fue eliminado, ejecuta los pasos 3, 4 y 5

---

### PASO 3 — Recrear el cluster EKS (solo si fue eliminado)

En CloudShell:

```bash
curl -s https://raw.githubusercontent.com/MGcarva/Devops/main/scripts/2-crear-cluster.sh | bash
```

> Tarda aproximadamente **15 minutos**. No cierres CloudShell.
> Cuando termine imprime: `CLUSTER LISTO - Ahora ejecuta el script 3`

---

### PASO 4 — Recrear el Node Group (solo si fue eliminado)

Ejecuta este script **después** de que el Paso 3 diga CLUSTER LISTO:

```bash
curl -s https://raw.githubusercontent.com/MGcarva/Devops/main/scripts/3-crear-nodegroup.sh | bash
```

> Tarda aproximadamente **5 minutos**.
> Cuando termine imprime: `TODO LISTO`

---

### PASO 5 — Verificar ECR (solo si fue eliminado)

Los repositorios ECR normalmente persisten. Para verificar:

```bash
aws ecr describe-repositories --region us-east-1 --query "repositories[*].repositoryName" --output table
```

Si no aparecen `tienda-frontend`, `tienda-backend`, `tienda-db`, créalos:

```bash
aws ecr create-repository --repository-name tienda-frontend --region us-east-1
aws ecr create-repository --repository-name tienda-backend  --region us-east-1
aws ecr create-repository --repository-name tienda-db       --region us-east-1
```

---

### PASO 6 — Actualizar secrets en GitHub y disparar el pipeline

> Este paso se repite **cada sesión** porque las credenciales AWS Academy expiran.

#### 6.1 — Actualizar los secrets en GitHub

Ve a: **github.com/MGcarva/Devops → Settings → Secrets and variables → Actions**

Actualiza (o crea si es la primera vez) estos 6 secrets:

| Secret | Valor |
|--------|-------|
| `AWS_ACCESS_KEY_ID` | Del botón AWS Details del lab |
| `AWS_SECRET_ACCESS_KEY` | Del botón AWS Details del lab |
| `AWS_SESSION_TOKEN` | Del botón AWS Details del lab |
| `AWS_REGION` | `us-east-1` |
| `EKS_CLUSTER_NAME` | `tienda-perritos` |
| `EKS_NAMESPACE` | `tienda` |

#### 6.2 — Disparar el pipeline

Desde tu computador, en la carpeta del proyecto:

```bash
cd "C:\Users\ghonc\Downloads\3.6.3 APP tienda-perritos-EKS_GITHUB"
git commit --allow-empty -m "trigger: activar pipeline"
git push
```

El pipeline se activa automáticamente con cada push a `main`.

#### 6.3 — Monitorear el pipeline

Ve a: **github.com/MGcarva/Devops → Actions**

Verás el pipeline ejecutando estos pasos en orden:
1. Checkout código
2. Configurar credenciales AWS
3. Login a ECR
4. Build & push Frontend → ECR
5. Build & push Backend → ECR
6. Build & push DB → ECR
7. Instalar kubectl
8. Configurar kubeconfig para EKS
9. Aplicar manifests (namespace, DB, servicios)
10. Desplegar Backend en EKS
11. Desplegar Frontend en EKS
12. Aplicar HPA
13. Ver pods y servicios finales

> El pipeline completo tarda aproximadamente **5–10 minutos**.

#### 6.4 — Obtener la URL pública

Cuando el pipeline termine, en CloudShell:

```bash
aws eks update-kubeconfig --region us-east-1 --name tienda-perritos
kubectl get svc -n tienda
```

La columna `EXTERNAL-IP` del servicio `tienda-frontend` es la URL pública de la aplicación.
Puede tardar 2–3 minutos en propagarse después del despliegue.

---

## Arquitectura del proyecto

```
┌─────────────────────────────────────────────┐
│              GitHub Actions                  │
│  push a main → build → push ECR → deploy    │
└─────────────────┬───────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────┐
│           Amazon ECR                         │
│  tienda-frontend | tienda-backend | tienda-db│
└─────────────────┬───────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────┐
│           Amazon EKS (tienda-perritos)       │
│  Namespace: tienda                           │
│                                              │
│  [Frontend :80] → [Backend :3001] → [MySQL]  │
│       (x2 pods)       (x2 pods)    (x1 pod)  │
└─────────────────────────────────────────────┘
```

## Estructura de archivos

```
.
├── .github/workflows/
│   └── deploy-eks.yml        # Pipeline CI/CD completo
├── frontend/                 # Nginx + HTML/JS
├── backend/                  # Node.js Express API
├── db/                       # MySQL con init.sql
├── k8s/                      # Manifests Kubernetes
│   ├── namespace.yaml
│   ├── mysql-secret.yaml     # Password: admin123 (base64)
│   ├── mysql-deployment.yaml
│   ├── mysql-service.yaml
│   ├── backend-deployment.yaml
│   ├── backend-service.yaml
│   ├── backend-hpa.yaml
│   ├── frontend-deployment.yaml
│   ├── frontend-service.yaml
│   └── frontend-hpa.yaml
└── scripts/                  # Scripts de setup AWS
    ├── 1-variables.sh        # Verificar variables del lab
    ├── 2-crear-cluster.sh    # Crear cluster EKS
    └── 3-crear-nodegroup.sh  # Crear node group
```

---

## Resolución de problemas comunes

### El pipeline falla en "Configurar kubeconfig para EKS"
Las credenciales AWS expiraron. Actualiza los 3 secrets de AWS en GitHub (Paso 6.1).

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
