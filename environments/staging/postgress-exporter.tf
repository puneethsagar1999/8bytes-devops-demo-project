resource "helm_release" "postgres_exporter" {
  name       = "postgres-exporter"
  namespace  = "staging"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "prometheus-postgres-exporter"
  version    = "8.2.0"

  values = [
    yamlencode({
      config = {
        datasource = {
          host     = split(":", module.rds.endpoint)[0]
          port     = "5432"
          user     = "appadmin"
          database = "appdb"
          sslmode  = "require"
          passwordSecret = {
            name = "db-credentials"
            key  = "DB_PASSWORD"
          }
        }
      }
      serviceMonitor = {
        enabled = true
      }
    })
  ]
}