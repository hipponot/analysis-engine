resource "kubernetes_namespace" "airflow" {
  metadata {
    name = "airflow"
  }

  depends_on = [
    module.eks
  ]
}

resource "helm_release" "airflow" {
  name       = "airflow"
  repository = "https://airflow.apache.org"
  chart      = "airflow"
  namespace  = kubernetes_namespace.airflow.metadata[0].name
  version    = "1.17.0" # Updated to latest stable version

  values = [
    file("${path.module}/airflow-values.yaml")
  ]

  depends_on = [
    kubernetes_namespace.airflow,
    module.eks
  ]
}

resource "helm_release" "keda" {
  name       = "keda"
  repository = "https://kedacore.github.io/charts"
  chart      = "keda"
  namespace  = kubernetes_namespace.airflow.metadata[0].name # Deploy KEDA in the same namespace as Airflow for simplicity
  version    = "2.17.2" # Updated to latest stable version

  depends_on = [
    helm_release.airflow
  ]
}

# TODO: Add KEDA ScaledObject after KEDA is installed
# KEDA ScaledObject for GPU workloads - scales from 0
# resource "kubernetes_manifest" "gpu_scaledobject" {
#   manifest = {
#     apiVersion = "keda.sh/v1alpha1"
#     kind       = "ScaledObject"
#     metadata = {
#       name      = "airflow-gpu-worker-scaler"
#       namespace = kubernetes_namespace.airflow.metadata[0].name
#     }
#     spec = {
#       scaleTargetRef = {
#         apiVersion = "apps/v1"
#         kind       = "Deployment"
#         name       = "airflow-worker"
#       }
#       minReplicaCount = 0
#       maxReplicaCount = 5
#       triggers = [{
#         type = "prometheus"
#         metadata = {
#           serverAddress = "http://prometheus:9090"
#           metricName    = "airflow_queue_depth"
#           threshold     = "1"
#           query         = "airflow_task_duration{queue=\"gpu\"}"
#         }
#       }]
#     }
#   }
#   
#   depends_on = [
#     helm_release.keda
#   ]
# }
