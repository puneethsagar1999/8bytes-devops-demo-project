resource "helm_release" "loki" {
  name             = "loki"
  namespace        = "logging"
  create_namespace = true
  repository       = "https://grafana.github.io/helm-charts"
  chart            = "loki-stack"
  version          = "2.10.2"
  timeout          = 600

  set {
    name  = "grafana.enabled"
    value = "false"
  }

  set {
    name  = "promtail.enabled"
    value = "true"
  }

  set {
    name  = "loki.persistence.enabled"
    value = "false"
  }
}