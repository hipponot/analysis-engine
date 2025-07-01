
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
  repository = "https://airflow.apache.org/charts"
  chart      = "airflow"
  namespace  = kubernetes_namespace.airflow.metadata[0].name
  version    = "1.11.0" # Use a recent stable version

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
  version    = "2.12.0" # Use a recent stable version

  depends_on = [
    helm_release.airflow
  ]
}
